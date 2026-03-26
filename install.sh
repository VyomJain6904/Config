#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${HOME}/.local/state/config-installer"
STATE_FILE="${STATE_DIR}/state.env"
LOG_FILE="/tmp/config-installer-$(date +%Y%m%d_%H%M%S).log"
REPO_URL="https://github.com/VyomJain6904/Config.git"
REPO_BRANCH="main"

exec > >(tee -a "$LOG_FILE") 2>&1

STYLE=""
OS_ID=""
OS_NAME=""
OS_VERSION=""
PKG_MANAGER=""
ARCH="$(uname -m)"
KERNEL="$(uname -sr)"
HOSTNAME_VAL="$(hostname 2>/dev/null || echo unknown)"
VIRT="unknown"
CPU_MODEL="unknown"
MEM_TOTAL="unknown"
DETECTED_DE="unknown"
SESSION_TYPE="unknown"
TTY_NAME="unknown"
RUNNING_WM="unknown"
PURGE_LEGACY=0
TMP_REPO_DIR=""
IS_INTERACTIVE=0

COLOR_RESET=""
COLOR_PURPLE=""
COLOR_PINK=""
COLOR_CYAN=""
COLOR_GREEN=""
COLOR_YELLOW=""
COLOR_RED=""
COLOR_GRAY=""

SYMBOL_POINTER=">"
SYMBOL_BRANCH="|"
SYMBOL_SELECTED="*"
SYMBOL_UNSELECTED="o"

STATE_STYLE=""
STATE_LAST_OK=0

declare -a APP_KEYS=()
declare -a APP_LABELS=()
declare -a APP_SELECTED=()
declare -a APP_DEFAULTS=()

print_usage() {
  cat <<'EOF'
Usage: ./install.sh [--purge-legacy] [--help]

Options:
  --purge-legacy  Purge legacy desktop stacks after successful verification.
  --help          Show this help message.
EOF
}

setup_ui() {
  if [[ -t 0 && -t 1 ]]; then
    IS_INTERACTIVE=1
  fi
  if [[ "$IS_INTERACTIVE" -eq 1 ]]; then
    COLOR_RESET='\033[0m'
    COLOR_PURPLE='\033[38;2;189;147;249m'
    COLOR_PINK='\033[38;2;255;121;198m'
    COLOR_CYAN='\033[38;2;139;233;253m'
    COLOR_GREEN='\033[38;2;80;250;123m'
    COLOR_YELLOW='\033[38;2;241;250;140m'
    COLOR_RED='\033[38;2;255;85;85m'
    COLOR_GRAY='\033[38;2;98;114;164m'
    SYMBOL_POINTER="▸"
    SYMBOL_BRANCH="│"
    SYMBOL_SELECTED="●"
    SYMBOL_UNSELECTED="○"
  fi
}

ui_clear() {
  if [[ "$IS_INTERACTIVE" -eq 1 ]]; then
    command -v clear >/dev/null 2>&1 && clear || printf '\033c'
  fi
}

ui_prompt_line() {
  local cmd="$1"
  printf '%b[%bConfig%b]%b [%b%s%b] [%bmain%b]%b %b%s%b\n' \
    "$COLOR_RESET" "$COLOR_PINK" "$COLOR_RESET" "$COLOR_RESET" \
    "$COLOR_CYAN" "$HOSTNAME_VAL" "$COLOR_RESET" \
    "$COLOR_PURPLE" "$COLOR_RESET" "$COLOR_RESET" \
    "$COLOR_GREEN" "$cmd" "$COLOR_RESET"
}

ui_section_title() {
  printf '\n%b%s%b\n' "$COLOR_PINK" "$1" "$COLOR_RESET"
}

ui_tree_line() {
  printf ' %b%s%b %s\n' "$COLOR_GRAY" "$SYMBOL_BRANCH" "$COLOR_RESET" "$1"
}

ui_kv() {
  printf ' %b%s%b %s\n' "$COLOR_GRAY" "$1" "$COLOR_RESET" "$2"
}

ui_hint() {
  printf '%b%s%b\n' "$COLOR_GRAY" "$1" "$COLOR_RESET"
}

show_login_style_header() {
  printf '\n'
  ui_prompt_line "install auth list"
  printf '\n'
  ui_tree_line "Config Unified Installer"
  ui_tree_line "Dracula Theme UI · v${SCRIPT_VERSION}"
  printf '\n'
}

info() { printf '%b[INFO]%b %s\n' "$COLOR_CYAN" "$COLOR_RESET" "$*"; }
warn() { printf '%b[WARN]%b %s\n' "$COLOR_YELLOW" "$COLOR_RESET" "$*"; }
ok() { printf '%b[ OK ]%b %s\n' "$COLOR_GREEN" "$COLOR_RESET" "$*"; }
die() {
  printf '%b[ERR ]%b %s\n' "$COLOR_RED" "$COLOR_RESET" "$*"
  exit 1
}

on_error() {
  local line_no="$1"
  warn "Failure near line ${line_no}. See log: ${LOG_FILE}"
}

trap 'on_error $LINENO' ERR

cleanup_temp_repo() {
  if [[ -n "$TMP_REPO_DIR" && -d "$TMP_REPO_DIR" ]]; then
    rm -rf "$TMP_REPO_DIR"
    TMP_REPO_DIR=""
  fi
}

trap cleanup_temp_repo EXIT

ensure_not_root() {
  if [[ "$(id -u)" -eq 0 ]]; then
    die "Run as regular user (sudo required), not root."
  fi
  return 0
}

ensure_sudo() {
  sudo -v >/dev/null 2>&1 || die "sudo authentication failed."
}

parse_args() {
  while [[ $# -gt 0 ]]; do
    case "$1" in
    --purge-legacy)
      PURGE_LEGACY=1
      ;;
    --help | -h)
      print_usage
      exit 0
      ;;
    *)
      die "Unknown argument: $1"
      ;;
    esac
    shift
  done
}

detect_os() {
  [[ -f /etc/os-release ]] || die "Missing /etc/os-release"
  # shellcheck disable=SC1091
  . /etc/os-release

  OS_ID="${ID:-unknown}"
  OS_NAME="${PRETTY_NAME:-${NAME:-unknown}}"
  OS_VERSION="${VERSION_ID:-unknown}"

  case "$OS_ID" in
  ubuntu | debian | linuxmint) PKG_MANAGER="apt" ;;
  fedora) PKG_MANAGER="dnf" ;;
  arch) PKG_MANAGER="pacman" ;;
  *)
    case "${ID_LIKE:-}" in
    *debian*) PKG_MANAGER="apt" ;;
    *fedora*) PKG_MANAGER="dnf" ;;
    *arch*) PKG_MANAGER="pacman" ;;
    *) die "Unsupported OS: ${OS_ID}. Supported: debian, ubuntu, mint, fedora, arch." ;;
    esac
    ;;
  esac
}

detect_hardware() {
  if command -v systemd-detect-virt >/dev/null 2>&1; then
    VIRT="$(systemd-detect-virt 2>/dev/null || echo unknown)"
  fi
  if [[ -r /proc/cpuinfo ]]; then
    CPU_MODEL="$(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | xargs || echo unknown)"
  fi
  if [[ -r /proc/meminfo ]]; then
    MEM_TOTAL="$(awk '/MemTotal/ {printf "%.1f GiB", $2/1024/1024}' /proc/meminfo 2>/dev/null || echo unknown)"
  fi
}

detect_session() {
  DETECTED_DE="${XDG_CURRENT_DESKTOP:-${DESKTOP_SESSION:-unknown}}"
  SESSION_TYPE="${XDG_SESSION_TYPE:-unknown}"
  TTY_NAME="$(tty 2>/dev/null || echo unknown)"

  if pgrep -x i3 >/dev/null 2>&1; then
    RUNNING_WM="i3"
  elif pgrep -x sway >/dev/null 2>&1; then
    RUNNING_WM="sway"
  else
    RUNNING_WM="unknown"
  fi

  if [[ "$DETECTED_DE" == "unknown" && "$RUNNING_WM" != "unknown" ]]; then
    DETECTED_DE="$RUNNING_WM"
  fi
}

print_detection_report() {
  ui_section_title "System Detection"
  ui_kv "Host:" "$HOSTNAME_VAL"
  ui_kv "OS:" "$OS_NAME (id=$OS_ID version=$OS_VERSION)"
  ui_kv "Package mgr:" "$PKG_MANAGER"
  ui_kv "Kernel:" "$KERNEL"
  ui_kv "Architecture:" "$ARCH"
  ui_kv "Virtualization:" "$VIRT"
  ui_kv "CPU:" "$CPU_MODEL"
  ui_kv "Memory:" "$MEM_TOTAL"
  ui_kv "Desktop/WM:" "$DETECTED_DE"
  ui_kv "Session type:" "$SESSION_TYPE"
  ui_kv "TTY:" "$TTY_NAME"
  ui_kv "Log file:" "$LOG_FILE"
  printf '\n'
}

is_i3_tty_session() {
  local de_lower session_lower
  de_lower="${DETECTED_DE,,}"
  session_lower="${SESSION_TYPE,,}"
  [[ "$de_lower" == *"i3"* || "$RUNNING_WM" == "i3" ]] || return 1
  [[ "$TTY_NAME" == /dev/tty* || "$session_lower" == "tty" || -z "${DISPLAY:-}" ]]
}

pkg_update_upgrade() {
  info "Updating system to latest packages via ${PKG_MANAGER}"
  case "$PKG_MANAGER" in
  apt)
    sudo apt-get update -y
    sudo DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
    ;;
  dnf)
    sudo dnf -y upgrade --refresh
    ;;
  pacman)
    sudo pacman -Syu --noconfirm
    ;;
  *) die "Unsupported package manager: ${PKG_MANAGER}" ;;
  esac
}

pkg_install() {
  [[ $# -gt 0 ]] || return 0
  case "$PKG_MANAGER" in
  apt) sudo DEBIAN_FRONTEND=noninteractive apt-get install -y "$@" ;;
  dnf) sudo dnf -y install "$@" ;;
  pacman) sudo pacman -S --needed --noconfirm "$@" ;;
  *) die "Unsupported package manager: ${PKG_MANAGER}" ;;
  esac
}

pkg_install_best_effort() {
  local missing=()
  local p
  for p in "$@"; do
    if pkg_is_installed "$p"; then
      ok "Package already installed: $p"
    else
      missing+=("$p")
    fi
  done

  [[ ${#missing[@]} -eq 0 ]] && return 0

  if pkg_install "${missing[@]}"; then
    for p in "${missing[@]}"; do
      ok "Installed package: $p"
    done
    return 0
  fi

  warn "Batch install failed; retrying package-by-package"
  for p in "${missing[@]}"; do
    if pkg_install "$p"; then
      ok "Installed package: $p"
    else
      warn "Skipped unavailable package on ${OS_ID}: $p"
    fi
  done
}

pkg_is_installed() {
  local pkg="$1"
  case "$PKG_MANAGER" in
  apt) dpkg -s "$pkg" >/dev/null 2>&1 ;;
  dnf) rpm -q "$pkg" >/dev/null 2>&1 ;;
  pacman) pacman -Q "$pkg" >/dev/null 2>&1 ;;
  *) return 1 ;;
  esac
}

load_state() {
  if [[ -f "$STATE_FILE" ]]; then
    # shellcheck disable=SC1090
    . "$STATE_FILE"
    STATE_STYLE="${STYLE:-}"
    STATE_LAST_OK="${LAST_OK:-0}"
  fi
}

save_state() {
  mkdir -p "$STATE_DIR"
  cat >"$STATE_FILE" <<EOF
STYLE=${STYLE}
LAST_OK=${1:-0}
LAST_RUN_AT=$(date +%s)
EOF
}

choose_style() {
  local default_choice="2"
  if [[ "$VIRT" != "none" && "$VIRT" != "unknown" ]]; then
    default_choice="1"
  fi

  if [[ -n "${INSTALL_STYLE:-}" ]]; then
    case "${INSTALL_STYLE}" in
    Config-VM | config-vm | minimal) STYLE="Config-VM" ;;
    Config-Arch | config-arch | modern) STYLE="Config-Arch" ;;
    *) die "Invalid INSTALL_STYLE='${INSTALL_STYLE}'. Use Config-VM or Config-Arch." ;;
    esac
    ok "Selected style from INSTALL_STYLE: ${STYLE}"
    return 0
  fi

  if [[ "$IS_INTERACTIVE" -eq 0 ]]; then
    if [[ "$default_choice" == "1" ]]; then
      STYLE="Config-VM"
    else
      STYLE="Config-Arch"
    fi
    warn "Non-interactive shell detected. Auto-selected style: ${STYLE}"
    return 0
  fi

  ui_section_title "Style recommendation"
  ui_tree_line "VM environment: choose Minimal style (Config-VM)"
  ui_tree_line "Base system: choose Modern + Blurred style (Config-Arch)"
  printf '\n'
  ui_section_title "Select style"
  ui_tree_line "1) Minimal style (Config-VM)"
  ui_tree_line "2) Modern + Blurred style (Config-Arch)"
  printf 'Enter choice [default %s]: ' "$default_choice"

  local answer
  IFS= read -r answer
  answer="${answer:-$default_choice}"
  case "$answer" in
  1) STYLE="Config-VM" ;;
  2) STYLE="Config-Arch" ;;
  *) die "Invalid style choice: $answer" ;;
  esac

  ok "Selected style: ${STYLE}"
}

confirm_install_prompt() {
  [[ "$IS_INTERACTIVE" -eq 0 ]] && return 0
  local answer
  printf 'Install applications for %s now? [Y/n]: ' "$STYLE"
  IFS= read -r answer
  [[ "${answer,,}" == "n" ]] && die "Cancelled by user"
}

add_app_option() {
  local key="$1"
  local label="$2"
  local enabled_by_default="$3"
  APP_KEYS+=("$key")
  APP_LABELS+=("$label")
  APP_DEFAULTS+=("$enabled_by_default")
  APP_SELECTED+=("$enabled_by_default")
}

reset_app_defaults() {
  local i
  for i in "${!APP_DEFAULTS[@]}"; do
    APP_SELECTED[$i]="${APP_DEFAULTS[$i]}"
  done
}

build_app_selection_for_style() {
  APP_KEYS=()
  APP_LABELS=()
  APP_DEFAULTS=()
  APP_SELECTED=()

  add_app_option "antigravity" "Antigravity" 1
  add_app_option "code" "VS Code" 1
  add_app_option "opencode" "OpenCode CLI" 1
  add_app_option "codex" "Codex CLI" 1
  add_app_option "claude" "Claude Code" 1
  add_app_option "yazi" "Yazi (cargo install)" 1
  add_app_option "thunar" "Thunar" 1

  if [[ "$STYLE" == "Config-Arch" ]]; then
    add_app_option "ghostty" "Ghostty" 1
    add_app_option "rofi" "Rofi" 1
    add_app_option "picom" "Picom" 1
    add_app_option "polybar" "Polybar" 1
    add_app_option "fastfetch" "Fastfetch" 1
    add_app_option "btop" "Btop" 1
    add_app_option "bat" "Bat" 1
    add_app_option "obs-studio" "OBS Studio" 0
  fi
}

read_keypress() {
  local key seq
  IFS= read -rsn1 key || key=""
  if [[ "$key" == $'\x1b' ]]; then
    IFS= read -rsn2 seq || seq=""
    key+="$seq"
  fi
  printf '%s' "$key"
}

select_apps_interactive() {
  local idx=0
  local count="${#APP_KEYS[@]}"
  local i mark line key

  if [[ "$IS_INTERACTIVE" -eq 0 ]]; then
    warn "Non-interactive shell detected. Using default app selection."
    return 0
  fi

  while true; do
    ui_clear
    show_login_style_header
    ui_prompt_line "install auth login"
    ui_section_title "Add credential"
    ui_tree_line "Select applications for ${STYLE}"
    printf '\n'
    for i in "${!APP_KEYS[@]}"; do
      mark="$SYMBOL_UNSELECTED"
      [[ "${APP_SELECTED[$i]}" == "1" ]] && mark="$SYMBOL_SELECTED"
      if [[ "$i" -eq "$idx" ]]; then
        line="${COLOR_CYAN}${SYMBOL_POINTER}${COLOR_RESET} ${mark} ${APP_LABELS[$i]}"
      else
        line="  ${mark} ${APP_LABELS[$i]}"
      fi
      printf '%b\n' "$line"
    done

    printf '\n'
    ui_hint "↑/↓ to select • Enter/Space: toggle"
    ui_hint "c: confirm • s: defaults • q: quit"

    key="$(read_keypress)"
    case "$key" in
    $'\x1b[A') idx=$(((idx - 1 + count) % count)) ;;
    $'\x1b[B') idx=$(((idx + 1) % count)) ;;
    " " | $'\n' | $'\r')
      if [[ "${APP_SELECTED[$idx]}" == "1" ]]; then
        APP_SELECTED[$idx]=0
      else
        APP_SELECTED[$idx]=1
      fi
      ;;
    c | C)
      ui_clear
      return 0
      ;;
    s | S)
      reset_app_defaults
      ;;
    q | Q)
      die "Selection cancelled by user"
      ;;
    esac
  done
}

print_selected_apps() {
  local i
  ui_section_title "Selected applications"
  for i in "${!APP_KEYS[@]}"; do
    if [[ "${APP_SELECTED[$i]}" == "1" ]]; then
      ui_tree_line "${APP_LABELS[$i]}"
      fi
  done
  printf '\n'
}

go_arch() {
  case "$ARCH" in
  x86_64) echo "amd64" ;;
  aarch64 | arm64) echo "arm64" ;;
  i386 | i686) echo "386" ;;
  armv6l) echo "armv6l" ;;
  *) echo "amd64" ;;
  esac
}

ensure_rust_latest() {
  info "Ensuring Rust is installed and updated"
  if ! command -v rustup >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  # shellcheck disable=SC1090
  [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"
  rustup update stable
}

ensure_go_latest() {
  info "Ensuring Go is latest"
  local latest goversion tar_file
  latest="$(curl -fsSL 'https://go.dev/VERSION?m=text' | head -n1)"
  [[ -n "$latest" ]] || die "Unable to fetch latest Go version"

  if command -v go >/dev/null 2>&1; then
    goversion="$(go version | awk '{print $3}')"
  else
    goversion=""
  fi

  if [[ "$goversion" == "$latest" ]]; then
    ok "Go already latest: ${goversion}"
    return 0
  fi

  tar_file="/tmp/${latest}.linux-$(go_arch).tar.gz"
  curl -fsSL "https://go.dev/dl/${latest}.linux-$(go_arch).tar.gz" -o "$tar_file"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "$tar_file"
  rm -f "$tar_file"

  export PATH="/usr/local/go/bin:${PATH}"
  if ! grep -q '/usr/local/go/bin' "$HOME/.profile" 2>/dev/null; then
    printf '\nexport PATH="/usr/local/go/bin:$PATH"\n' >>"$HOME/.profile"
  fi
}

ensure_node_latest() {
  info "Ensuring Node.js is latest via nvm"
  if [[ ! -d "$HOME/.nvm" ]]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  fi

  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"

  nvm install node
  nvm alias default node
  nvm use default >/dev/null

  if ! grep -q 'NVM_DIR' "$HOME/.profile" 2>/dev/null; then
    cat >>"$HOME/.profile" <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOF
  fi
}

ensure_bun_latest() {
  info "Ensuring Bun is latest"
  if ! command -v bun >/dev/null 2>&1; then
    curl -fsSL https://bun.sh/install | bash
  fi

  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:${PATH}"
  if command -v bun >/dev/null 2>&1; then
    bun upgrade || true
  fi

  if ! grep -q 'BUN_INSTALL' "$HOME/.profile" 2>/dev/null; then
    cat >>"$HOME/.profile" <<'EOF'
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
EOF
  fi
}

ensure_runtime_deps() {
  case "$PKG_MANAGER" in
  apt) pkg_install curl wget ca-certificates unzip tar xz-utils git build-essential ;;
  dnf) pkg_install curl wget ca-certificates unzip tar xz git gcc gcc-c++ make ;;
  pacman) pkg_install curl wget ca-certificates unzip tar xz git base-devel ;;
  esac

  ensure_rust_latest
  ensure_go_latest
  ensure_node_latest
  ensure_bun_latest
}

zshrc_append_if_missing() {
  local marker="$1"
  local block="$2"
  local zshrc="$HOME/.zshrc"
  touch "$zshrc"
  if ! grep -qF "$marker" "$zshrc" 2>/dev/null; then
    printf '\n%s\n' "$block" >>"$zshrc"
  fi
}

clone_plugin_if_missing() {
  local repo="$1"
  local dst="$2"
  local name
  name="$(basename "$dst")"
  if [[ -d "$dst" ]]; then
    ok "$name already present"
    return 0
  fi
  timeout 120 git clone --depth 1 "$repo" "$dst" >/dev/null 2>&1 || {
    warn "Failed to clone ${name}"
    return 1
  }
  ok "Installed plugin: $name"
}

ensure_oh_my_zsh_stack() {
  info "Ensuring Oh My Zsh, plugins, and Starship"

  pkg_install_best_effort zsh

  if [[ ! -d "$HOME/.oh-my-zsh" ]]; then
    timeout 180 env RUNZSH=no CHSH=no KEEP_ZSHRC=yes sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" >/dev/null 2>&1 || {
      warn "Oh My Zsh auto-installer failed, using git clone fallback"
      timeout 120 git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" >/dev/null 2>&1 || true
    }
  fi
  [[ -d "$HOME/.oh-my-zsh" ]] && ok "Oh My Zsh ready" || warn "Oh My Zsh not available"

  local zplugins="$HOME/.oh-my-zsh/plugins"
  mkdir -p "$zplugins"
  clone_plugin_if_missing "https://github.com/zsh-users/zsh-autosuggestions" "$zplugins/zsh-autosuggestions"
  clone_plugin_if_missing "https://github.com/zsh-users/zsh-syntax-highlighting" "$zplugins/zsh-syntax-highlighting"
  clone_plugin_if_missing "https://github.com/zsh-users/zsh-completions" "$zplugins/zsh-completions"
  clone_plugin_if_missing "https://github.com/zsh-users/zsh-history-substring-search" "$zplugins/zsh-history-substring-search"
  clone_plugin_if_missing "https://github.com/romkatv/zsh-defer.git" "$zplugins/zsh-defer"

  if ! command -v starship >/dev/null 2>&1; then
    timeout 120 sh -c "$(curl -fsSL https://starship.rs/install.sh)" -- -y >/dev/null 2>&1 || warn "Starship install failed"
  fi
  command -v starship >/dev/null 2>&1 && ok "Starship ready" || warn "Starship not available"

  zshrc_append_if_missing 'source "$ZSH/oh-my-zsh.sh"' 'export ZSH="$HOME/.oh-my-zsh"'
  zshrc_append_if_missing 'plugins=(' 'plugins=(git zsh-autosuggestions zsh-syntax-highlighting zsh-completions zsh-history-substring-search zsh-defer)'
  zshrc_append_if_missing 'eval "$(starship init zsh)"' 'eval "$(starship init zsh)"'
}

ensure_jetbrains_font() {
  info "Ensuring JetBrainsMono Nerd Font"
  local font_dir="$HOME/.local/share/fonts"
  local zip_path="$font_dir/JetBrainsMono.zip"
  mkdir -p "$font_dir"

  if ls "$font_dir"/JetBrainsMonoNerdFont-*.ttf >/dev/null 2>&1; then
    ok "JetBrainsMono Nerd Font already installed"
    return 0
  fi

  timeout 180 curl -fsSL "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip" -o "$zip_path" || {
    warn "Font download failed"
    return 1
  }
  unzip -qo "$zip_path" -d "$font_dir" >/dev/null 2>&1 || {
    warn "Font extraction failed"
    rm -f "$zip_path"
    return 1
  }
  rm -f "$zip_path"
  command -v fc-cache >/dev/null 2>&1 && fc-cache -fv >/dev/null 2>&1 || true
  ok "JetBrainsMono Nerd Font installed"
}

resolve_package_sets() {
  CORE_PACKAGES=()
  STYLE_UI_PACKAGES=()

  case "$PKG_MANAGER" in
  apt)
    CORE_PACKAGES=(git neovim tmux zsh ripgrep fd-find fzf jq)
    if [[ "$STYLE" == "Config-VM" ]]; then
      STYLE_UI_PACKAGES=(xorg xinit i3 i3status i3lock feh alacritty)
    else
      STYLE_UI_PACKAGES=(xorg xinit i3 i3status i3lock feh alacritty)
    fi
    ;;
  dnf)
    CORE_PACKAGES=(git neovim tmux zsh ripgrep fd-find fzf jq)
    if [[ "$STYLE" == "Config-VM" ]]; then
      STYLE_UI_PACKAGES=(xorg-x11-server-Xorg xorg-x11-xinit i3 i3status i3lock xterm feh alacritty)
    else
      STYLE_UI_PACKAGES=(xorg-x11-server-Xorg xorg-x11-xinit i3 i3status i3lock xterm feh alacritty)
    fi
    ;;
  pacman)
    CORE_PACKAGES=(git neovim tmux zsh ripgrep fd fzf jq)
    if [[ "$STYLE" == "Config-VM" ]]; then
      STYLE_UI_PACKAGES=(xorg-server xorg-xinit i3-wm i3status i3lock feh alacritty)
    else
      STYLE_UI_PACKAGES=(xorg-server xorg-xinit i3-wm i3status i3lock feh alacritty)
    fi
    ;;
  esac
}

add_pkg_unique() {
  local pkg="$1"
  local existing
  for existing in "${STYLE_UI_PACKAGES[@]:-}"; do
    [[ "$existing" == "$pkg" ]] && return 0
  done
  STYLE_UI_PACKAGES+=("$pkg")
}

map_style_item_to_packages() {
  local item="$1"
  case "$item" in
  alacritty) add_pkg_unique "alacritty" ;;
  i3)
    case "$PKG_MANAGER" in
    apt | dnf) add_pkg_unique "i3" ;;
    pacman) add_pkg_unique "i3-wm" ;;
    esac
    add_pkg_unique "i3status"
    add_pkg_unique "i3lock"
    ;;
  nvim) add_pkg_unique "neovim" ;;
  polybar | fastfetch | bat | btop | ghostty | picom | rofi | obs-studio | yazi) ;;
  esac
}

fetch_style_from_github() {
  cleanup_temp_repo
  TMP_REPO_DIR="$(mktemp -d)"
  info "Fetching ${STYLE} from GitHub"

  git clone --depth 1 --filter=blob:none --sparse --branch "$REPO_BRANCH" "$REPO_URL" "$TMP_REPO_DIR/repo"
  git -C "$TMP_REPO_DIR/repo" sparse-checkout set "$STYLE"

  [[ -d "$TMP_REPO_DIR/repo/$STYLE" ]] || die "Style folder ${STYLE} not found in repo"
}

resolve_style_packages_from_repo() {
  STYLE_UI_PACKAGES=()

  case "$PKG_MANAGER" in
  apt)
    add_pkg_unique "xorg"
    add_pkg_unique "xinit"
    add_pkg_unique "xterm"
    add_pkg_unique "feh"
    ;;
  dnf)
    add_pkg_unique "xorg-x11-server-Xorg"
    add_pkg_unique "xorg-x11-xinit"
    add_pkg_unique "xterm"
    add_pkg_unique "feh"
    ;;
  pacman)
    add_pkg_unique "xorg-server"
    add_pkg_unique "xorg-xinit"
    add_pkg_unique "xterm"
    add_pkg_unique "feh"
    ;;
  esac

  local entry item
  for entry in "$TMP_REPO_DIR/repo/$STYLE"/*; do
    [[ -d "$entry" ]] || continue
    item="$(basename "$entry")"
    map_style_item_to_packages "$item"
  done
}

copy_config_dir() {
  local src="$1"
  local dst="$2"
  mkdir -p "$(dirname "$dst")"
  rm -rf "$dst"
  mkdir -p "$dst"
  cp -a "$src/." "$dst/"
}

deploy_style_configs() {
  local style_dir="$TMP_REPO_DIR/repo/$STYLE"
  [[ -d "$style_dir" ]] || die "Style directory not found: $style_dir"

  info "Deploying configs from ${STYLE}"
  local entry target
  for entry in "$style_dir"/*; do
    [[ -d "$entry" ]] || continue
    target="$HOME/.config/$(basename "$entry")"
    copy_config_dir "$entry" "$target"
    ok "Applied: $target"
  done
}

install_selected_apps() {
  fetch_style_from_github
  resolve_package_sets
  resolve_style_packages_from_repo

  info "Installing core dev packages"
  pkg_install_best_effort "${CORE_PACKAGES[@]}"

  info "Installing style UI packages (${STYLE})"
  pkg_install_best_effort "${STYLE_UI_PACKAGES[@]}"

  install_selected_optional_apps

  deploy_style_configs

  cleanup_temp_repo
  ok "Temporary GitHub files cleaned"
}

is_app_selected() {
  local key="$1"
  local i
  for i in "${!APP_KEYS[@]}"; do
    if [[ "${APP_KEYS[$i]}" == "$key" && "${APP_SELECTED[$i]}" == "1" ]]; then
      return 0
    fi
  done
  return 1
}

install_vscode() {
  command -v code >/dev/null 2>&1 && {
    ok "VS Code already installed"
    return 0
  }
  case "$PKG_MANAGER" in
  apt)
    local apt_arch
    apt_arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main\n' "$apt_arch" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    sudo apt-get update -y
    pkg_install code
    ;;
  *)
    warn "VS Code auto-install currently implemented for apt family only"
    return 1
    ;;
  esac
}

install_antigravity() {
  case "$PKG_MANAGER" in
  apt)
    pkg_is_installed antigravity && {
      ok "Antigravity already installed"
      return 0
    }
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
    printf 'deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main\n' | sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null
    sudo apt-get update -y
    pkg_install antigravity
    ;;
  *)
    warn "Antigravity auto-install currently implemented for apt family only"
    return 1
    ;;
  esac
}

install_opencode() {
  command -v opencode >/dev/null 2>&1 && {
    ok "OpenCode CLI already installed"
    return 0
  }
  timeout 240 bun install -g opencode-ai
}

install_codex() {
  command -v codex >/dev/null 2>&1 && {
    ok "Codex CLI already installed"
    return 0
  }
  timeout 240 npm install -g @openai/codex
}

install_claude() {
  command -v claude >/dev/null 2>&1 && {
    ok "Claude Code already installed"
    return 0
  }
  timeout 240 bash -lc 'curl -fsSL https://claude.ai/install.sh | bash'
}

install_yazi_from_cargo() {
  command -v yazi >/dev/null 2>&1 && {
    ok "Yazi already installed"
    return 0
  }
  if ! command -v cargo >/dev/null 2>&1; then
    warn "cargo not available; cannot install yazi"
    return 1
  fi
  timeout 900 cargo install --locked yazi-fm yazi-cli
}

install_thunar() {
  command -v thunar >/dev/null 2>&1 && {
    ok "Thunar already installed"
    return 0
  }
  case "$PKG_MANAGER" in
  apt) pkg_install thunar thunar-volman gvfs gvfs-backends ;;
  dnf) pkg_install thunar thunar-volman gvfs gvfs-archive ;;
  pacman) pkg_install thunar thunar-volman gvfs ;;
  esac
}

install_selected_optional_apps() {
  local extra_pkgs=()
  local key
  for key in "${APP_KEYS[@]}"; do
    is_app_selected "$key" || continue
    case "$key" in
    antigravity) install_antigravity || true ;;
    code) install_vscode || true ;;
    opencode) install_opencode || true ;;
    codex) install_codex || true ;;
    claude) install_claude || true ;;
    yazi) install_yazi_from_cargo || true ;;
    thunar) install_thunar || true ;;
    ghostty | rofi | picom | polybar | fastfetch | btop | bat | obs-studio) extra_pkgs+=("$key") ;;
    esac
  done

  if [[ ${#extra_pkgs[@]} -gt 0 ]]; then
    info "Installing selected style applications: ${extra_pkgs[*]}"
    pkg_install_best_effort "${extra_pkgs[@]}"
  fi
}

cmd_version_line() {
  local cmd="$1"
  case "$cmd" in
  go) go version 2>/dev/null | head -n1 ;;
  rustc) rustc --version 2>/dev/null | head -n1 ;;
  node) node --version 2>/dev/null | head -n1 ;;
  bun) bun --version 2>/dev/null | head -n1 ;;
  nvim) nvim --version 2>/dev/null | head -n1 ;;
  git) git --version 2>/dev/null | head -n1 ;;
  i3) i3 --version 2>/dev/null | head -n1 ;;
  i3status) i3status --version 2>/dev/null | head -n1 ;;
  polybar) polybar --version 2>/dev/null | head -n1 ;;
  rofi) rofi -version 2>/dev/null | head -n1 ;;
  picom) picom --version 2>/dev/null | head -n1 ;;
  *) "$cmd" --version 2>/dev/null | head -n1 ;;
  esac
}

verify_required() {
  local missing=()
  local required=(git nvim tmux zsh rustc go node bun)

  if [[ "$STYLE" == "Config-VM" ]]; then
    required+=(i3)
  else
    required+=(i3)
  fi

  if is_app_selected code && ! command -v code >/dev/null 2>&1; then missing+=("code"); fi
  if is_app_selected opencode && ! command -v opencode >/dev/null 2>&1; then missing+=("opencode"); fi
  if is_app_selected codex && ! command -v codex >/dev/null 2>&1; then missing+=("codex"); fi
  if is_app_selected claude && ! command -v claude >/dev/null 2>&1; then missing+=("claude"); fi
  if is_app_selected yazi && ! command -v yazi >/dev/null 2>&1; then missing+=("yazi"); fi
  if is_app_selected thunar && ! command -v thunar >/dev/null 2>&1; then missing+=("thunar"); fi
  if is_app_selected antigravity && [[ "$PKG_MANAGER" == "apt" ]] && ! pkg_is_installed antigravity; then missing+=("antigravity"); fi

  local c
  for c in "${required[@]}"; do
    if ! command -v "$c" >/dev/null 2>&1; then
      missing+=("$c")
    fi
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Missing required commands: ${missing[*]}"
    return 1
  fi
  ok "All required commands are present"
  return 0
}

print_versions_report() {
  local tools=(git nvim tmux zsh starship rustc go node bun i3 i3status yazi thunar code opencode codex claude polybar rofi picom ghostty fastfetch btop bat)
  printf '\n=== Installed Tools and Versions ===\n'
  local t v
  for t in "${tools[@]}"; do
    if command -v "$t" >/dev/null 2>&1; then
      v="$(cmd_version_line "$t")"
      [[ -n "$v" ]] || v="(version unavailable)"
      printf ' - %-10s : %s\n' "$t" "$v"
    fi
  done
  printf '\n'
}

confirm_purge() {
  printf 'Type PURGE to remove legacy desktop stacks and bloat: '
  local token
  IFS= read -r token
  [[ "$token" == "PURGE" ]]
}

purge_legacy_desktop_stacks() {
  [[ "$PURGE_LEGACY" -eq 1 ]] || return 0
  info "Purge mode requested (--purge-legacy)"

  if ! confirm_purge; then
    warn "Purge cancelled"
    return 0
  fi

  case "$PKG_MANAGER" in
  apt)
    sudo apt-get purge -y gnome-shell gdm3 plasma-desktop sddm xfce4 lxde lxqt cinnamon || true
    sudo apt-get autoremove -y --purge || true
    ;;
  dnf)
    sudo dnf -y remove @gnome-desktop @kde-desktop @xfce-desktop @lxde-desktop @cinnamon-desktop || true
    sudo dnf -y autoremove || true
    ;;
  pacman)
    sudo pacman -Rns --noconfirm gnome gdm plasma sddm xfce4 lxde lxqt cinnamon || true
    ;;
  esac

  rm -rf "$HOME/.config/gnome" "$HOME/.config/kde" "$HOME/.config/xfce4" || true
  ok "Legacy cleanup attempted"
}

main() {
  parse_args "$@"
  setup_ui
  show_login_style_header
  ensure_not_root
  detect_os
  detect_hardware
  detect_session
  load_state
  print_detection_report
  ensure_sudo

  if is_i3_tty_session; then
    info "Detected i3 + TTY session. Running full system update first."
    pkg_update_upgrade
  else
    info "Not in i3+TTY session. Skipping forced pre-update step."
  fi

  choose_style
  build_app_selection_for_style
  select_apps_interactive
  print_selected_apps

  if [[ "$STATE_LAST_OK" == "1" && "$STATE_STYLE" == "$STYLE" ]]; then
    if verify_required; then
      info "Everything already installed and healthy. Running verify-only mode."
      print_versions_report
      purge_legacy_desktop_stacks
      ok "Verification complete"
      return 0
    fi
  fi

  confirm_install_prompt

  pkg_update_upgrade
  ensure_runtime_deps
  ensure_oh_my_zsh_stack
  ensure_jetbrains_font
  install_selected_apps

  if verify_required; then
    print_versions_report
    save_state 1
    if [[ "$STATE_LAST_OK" == "1" && -n "$STATE_STYLE" ]]; then
      info "Re-run check: everything is healthy. Verify-only mode active."
      info "No automatic purge was performed. Use --purge-legacy if desired."
    fi
    purge_legacy_desktop_stacks
  else
    save_state 0
    warn "Install incomplete. Re-run the script; it will install remaining items."
    exit 1
  fi

  ok "Unified install complete"
  info "State file: ${STATE_FILE}"
  info "Log file  : ${LOG_FILE}"
}

main "$@"
