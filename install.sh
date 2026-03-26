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
STATE_PHASE="none"
STATE_DETECTED_DE_PKGS=""
CURRENT_DETECTED_DE_PKGS=""

declare -a APP_KEYS=()
declare -a APP_LABELS=()
declare -a APP_SELECTED=()
declare -a APP_DEFAULTS=()

APT_CACHE_REFRESHED=0

declare -a DEFERRED_APP_KEYS=()
declare -a DEFERRED_APP_REASONS=()

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

current_phase_badge() {
  case "$STATE_PHASE" in
  none) printf 'phase 1/2' ;;
  phase1_done) printf 'phase 2/2' ;;
  phase2_done) printf 'phase 2/2 done' ;;
  *) printf 'phase 1/2' ;;
  esac
}

ui_prompt_line() {
  local cmd="$1"
  local phase_badge
  phase_badge="$(current_phase_badge)"
  printf '%b[%b%s%b]%b %b%s%b\n' \
    "$COLOR_RESET" "$COLOR_YELLOW" "$phase_badge" "$COLOR_RESET" \
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

print_phase_banner() {
  local phase_label phase_desc
  case "$STATE_PHASE" in
  none)
    phase_label="1/2"
    phase_desc="Install + Configure i3/TTY"
    ;;
  phase1_done)
    phase_label="2/2"
    phase_desc="Post-reboot Health Check + Cleanup"
    ;;
  phase2_done)
    phase_label="2/2"
    phase_desc="Completed (verification mode)"
    ;;
  *)
    phase_label="1/2"
    phase_desc="Install"
    ;;
  esac

  ui_section_title "Current Phase: ${phase_label}"
  ui_tree_line "$phase_desc"
}

show_login_style_header() {
  printf '\n'
  ui_prompt_line "install auth list"
  printf '\n'
  ui_tree_line "Unified Installer"
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
    if ! pkg_is_installed "$p"; then
      missing+=("$p")
    fi
  done

  [[ ${#missing[@]} -eq 0 ]] && return 0

  if pkg_install "${missing[@]}"; then
    ok "Installed ${#missing[@]} package(s)"
    return 0
  fi

  warn "Batch install failed; retrying package-by-package"
  local installed_count=0
  for p in "${missing[@]}"; do
    if pkg_install "$p"; then
      installed_count=$((installed_count + 1))
    else
      warn "Skipped unavailable package on ${OS_ID}: $p"
    fi
  done
  [[ "$installed_count" -gt 0 ]] && ok "Installed ${installed_count}/${#missing[@]} package(s)"
}

extract_semver() {
  local raw="$1"
  printf '%s' "$raw" | grep -Eo '[0-9]+(\.[0-9]+){1,3}' | head -n1
}

command_semver() {
  local cmd="$1"
  local raw
  raw="$($cmd --version 2>/dev/null | head -n1 || true)"
  extract_semver "$raw"
}

apt_refresh_once() {
  [[ "$PKG_MANAGER" == "apt" ]] || return 0
  if [[ "$APT_CACHE_REFRESHED" -eq 0 ]]; then
    if sudo apt-get update -y >/dev/null 2>&1; then
      APT_CACHE_REFRESHED=1
    else
      warn "apt cache refresh failed; will retry later"
    fi
  fi
}

apt_installed_version() {
  local pkg="$1"
  dpkg-query -W -f='${Version}' "$pkg" 2>/dev/null || true
}

apt_candidate_version() {
  local pkg="$1"
  apt-cache policy "$pkg" 2>/dev/null | awk '/Candidate:/ {print $2; exit}'
}

apt_pkg_needs_install_or_update() {
  local pkg="$1"
  local installed candidate
  installed="$(apt_installed_version "$pkg")"
  candidate="$(apt_candidate_version "$pkg")"

  # missing package or missing candidate metadata -> attempt install/update
  if [[ -z "$installed" || -z "$candidate" || "$candidate" == "(none)" ]]; then
    return 0
  fi

  [[ "$installed" != "$candidate" ]]
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
    STATE_PHASE="${PHASE:-none}"
    STATE_DETECTED_DE_PKGS="${DETECTED_DE_PKGS:-}"
  fi
}

save_state() {
  local ok_state="${1:-0}"
  local phase_state="${2:-none}"
  local de_pkgs_state="${3:-}"
  mkdir -p "$STATE_DIR"
  cat >"$STATE_FILE" <<EOF
STYLE=${STYLE}
LAST_OK=${ok_state}
PHASE=${phase_state}
DETECTED_DE_PKGS=${de_pkgs_state}
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
  local default_apt_only=1
  [[ "$PKG_MANAGER" == "apt" ]] || default_apt_only=0

  APP_KEYS=()
  APP_LABELS=()
  APP_DEFAULTS=()
  APP_SELECTED=()

  add_app_option "antigravity" "Antigravity" "$default_apt_only"
  add_app_option "code" "VS Code" "$default_apt_only"
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

print_deferred_apps() {
  local i
  [[ ${#DEFERRED_APP_KEYS[@]} -eq 0 ]] && return 0
  ui_section_title "Deferred applications"
  for i in "${!DEFERRED_APP_KEYS[@]}"; do
    ui_tree_line "${DEFERRED_APP_KEYS[$i]}: ${DEFERRED_APP_REASONS[$i]}"
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
  local rust_check_log="/tmp/rustup-check.log"
  if ! command -v rustup >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
  fi
  # shellcheck disable=SC1090
  [[ -f "$HOME/.cargo/env" ]] && . "$HOME/.cargo/env"

  if command -v rustup >/dev/null 2>&1 && rustup check >"$rust_check_log" 2>&1; then
    if grep -qE 'stable-.*Up to date' "$rust_check_log"; then
      ok "Rust already latest"
      return 0
    fi
  fi

  rustup update stable
}

ensure_go_latest() {
  info "Ensuring Go is latest"
  local latest goversion tar_file cache_dir min_go_kb free_kb
  latest="$(curl -fsSL --retry 3 --connect-timeout 20 'https://go.dev/VERSION?m=text' 2>/dev/null | head -n1 || true)"
  if [[ -z "$latest" ]]; then
    if command -v go >/dev/null 2>&1; then
      warn "Unable to fetch latest Go version from go.dev, keeping installed Go ($(go version | awk '{print $3}'))"
      return 0
    fi
    warn "Unable to fetch latest Go version from go.dev, falling back to package manager Go"
    case "$PKG_MANAGER" in
    apt) pkg_install_best_effort golang-go ;;
    dnf) pkg_install_best_effort golang ;;
    pacman) pkg_install_best_effort go ;;
    esac
    return 0
  fi

  if command -v go >/dev/null 2>&1; then
    goversion="$(go version | awk '{print $3}')"
  else
    goversion=""
  fi

  if [[ "$goversion" == "$latest" ]]; then
    ok "Go already latest: ${goversion}"
    return 0
  fi

  cache_dir="$HOME/.cache/config-installer"
  mkdir -p "$cache_dir"
  min_go_kb=307200
  free_kb="$(available_kb "$cache_dir")"
  if [[ "$free_kb" -lt "$min_go_kb" ]]; then
    if command -v go >/dev/null 2>&1; then
      warn "Low disk in $cache_dir (${free_kb}KB). Keeping installed Go ($(go version | awk '{print $3}'))."
      return 0
    fi
    warn "Low disk in $cache_dir (${free_kb}KB). Falling back to package manager Go."
    case "$PKG_MANAGER" in
    apt) pkg_install_best_effort golang-go ;;
    dnf) pkg_install_best_effort golang ;;
    pacman) pkg_install_best_effort go ;;
    esac
    return 0
  fi

  tar_file="$cache_dir/${latest}.linux-$(go_arch).tar.gz"
  if ! curl -fL --retry 3 --connect-timeout 20 "https://go.dev/dl/${latest}.linux-$(go_arch).tar.gz" -o "$tar_file"; then
    warn "Go tarball download failed, falling back to package manager Go"
    case "$PKG_MANAGER" in
    apt) pkg_install_best_effort golang-go ;;
    dnf) pkg_install_best_effort golang ;;
    pacman) pkg_install_best_effort go ;;
    esac
    return 0
  fi
  sudo rm -rf /usr/local/go
  if ! sudo tar -C /usr/local -xzf "$tar_file"; then
    warn "Go tarball extract failed, falling back to package manager Go"
    rm -f "$tar_file"
    case "$PKG_MANAGER" in
    apt) pkg_install_best_effort golang-go ;;
    dnf) pkg_install_best_effort golang ;;
    pacman) pkg_install_best_effort go ;;
    esac
    return 0
  fi
  rm -f "$tar_file"

  export PATH="/usr/local/go/bin:${PATH}"
  if ! grep -q '/usr/local/go/bin' "$HOME/.profile" 2>/dev/null; then
    printf '\nexport PATH="/usr/local/go/bin:$PATH"\n' >>"$HOME/.profile"
  fi
}

ensure_node_latest() {
  info "Ensuring Node.js is latest via nvm"
  local current_node latest_node
  if [[ ! -d "$HOME/.nvm" ]]; then
    curl -fsSL https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.3/install.sh | bash
  fi

  export NVM_DIR="$HOME/.nvm"
  # shellcheck disable=SC1091
  . "$NVM_DIR/nvm.sh"

  current_node="$(node -v 2>/dev/null || true)"
  latest_node="$(nvm version node 2>/dev/null || true)"

  if [[ -n "$current_node" && -n "$latest_node" && "$latest_node" != "N/A" && "$current_node" == "$latest_node" ]]; then
    ok "Node already latest: ${current_node}"
  else
    nvm install node
    nvm alias default node
    nvm use default >/dev/null
  fi

  if ! grep -q 'NVM_DIR' "$HOME/.profile" 2>/dev/null; then
    cat >>"$HOME/.profile" <<'EOF'
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
EOF
  fi
}

ensure_bun_latest() {
  info "Ensuring Bun is latest"
  local current_bun latest_bun
  if ! command -v bun >/dev/null 2>&1; then
    curl -fsSL https://bun.sh/install | bash
  fi

  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:${PATH}"
  if command -v bun >/dev/null 2>&1; then
    current_bun="$(bun --version 2>/dev/null || true)"
    latest_bun="$(curl -fsSL --retry 2 --connect-timeout 10 https://bun.sh/version 2>/dev/null || true)"
    if [[ -n "$latest_bun" && -n "$current_bun" && "$current_bun" == "$latest_bun" ]]; then
      ok "Bun already latest: ${current_bun}"
    else
      bun upgrade || true
    fi
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
    timeout 120 git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh" >/dev/null 2>&1 || {
      warn "Oh My Zsh clone failed"
      return 1
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
    pkg_install_best_effort starship || true
  fi
  if ! command -v starship >/dev/null 2>&1; then
    timeout 120 bash -lc 'curl -fsSL https://starship.rs/install.sh | sh -s -- -y' >/dev/null 2>&1 || warn "Starship install failed"
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

deploy_default_zshrc() {
  info "Applying distro-specific default .zshrc"

  local src=""
  local raw_url=""
  local tmp_file=""
  local target_zshrc="$HOME/.zshrc"

  case "$OS_ID" in
  ubuntu | debian | linuxmint)
    src="$SCRIPT_DIR/zsh/.zshrc"
    raw_url="https://raw.githubusercontent.com/VyomJain6904/Config/main/zsh/.zshrc"
    ;;
  arch)
    src="$SCRIPT_DIR/zsh/arch.zshrc"
    raw_url="https://raw.githubusercontent.com/VyomJain6904/Config/main/zsh/arch.zshrc"
    ;;
  *)
    if [[ "$PKG_MANAGER" == "pacman" ]]; then
      src="$SCRIPT_DIR/zsh/arch.zshrc"
      raw_url="https://raw.githubusercontent.com/VyomJain6904/Config/main/zsh/arch.zshrc"
    else
      src="$SCRIPT_DIR/zsh/.zshrc"
      raw_url="https://raw.githubusercontent.com/VyomJain6904/Config/main/zsh/.zshrc"
    fi
    ;;
  esac

  rm -f "$target_zshrc"

  if [[ -f "$src" ]]; then
    cp "$src" "$target_zshrc"
    ok "Default .zshrc copied from local template"
    return 0
  fi

  tmp_file="$(mktemp)"
  if timeout 120 curl -fsSL "$raw_url" -o "$tmp_file"; then
    cp "$tmp_file" "$target_zshrc"
    rm -f "$tmp_file"
    ok "Default .zshrc downloaded and applied"
    return 0
  fi

  rm -f "$tmp_file"
  warn "Could not apply distro template .zshrc (local + remote missing)"
  return 1
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

  timeout 120 git clone --depth 1 --filter=blob:none --sparse --branch "$REPO_BRANCH" "$REPO_URL" "$TMP_REPO_DIR/repo" || \
    timeout 120 git clone --depth 1 --filter=blob:none --sparse --branch "$REPO_BRANCH" "$REPO_URL" "$TMP_REPO_DIR/repo" || \
    die "Failed to clone config repo"
  timeout 60 git -C "$TMP_REPO_DIR/repo" sparse-checkout set "$STYLE" || \
    timeout 60 git -C "$TMP_REPO_DIR/repo" sparse-checkout set "$STYLE" || \
    die "Failed sparse checkout for $STYLE"

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

is_app_deferred() {
  local key="$1"
  local i
  for i in "${!DEFERRED_APP_KEYS[@]}"; do
    [[ "${DEFERRED_APP_KEYS[$i]}" == "$key" ]] && return 0
  done
  return 1
}

mark_app_deferred() {
  local key="$1"
  local reason="$2"
  if ! is_app_deferred "$key"; then
    DEFERRED_APP_KEYS+=("$key")
    DEFERRED_APP_REASONS+=("$reason")
  fi
}

is_app_supported_on_distro() {
  local key="$1"
  case "$key" in
  code|antigravity)
    [[ "$PKG_MANAGER" == "apt" ]]
    ;;
  *)
    return 0
    ;;
  esac
}

install_vscode() {
  local installed candidate apt_arch
  case "$PKG_MANAGER" in
  apt)
    apt_arch="$(dpkg --print-architecture 2>/dev/null || echo amd64)"
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
    printf 'deb [arch=%s signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/code stable main\n' "$apt_arch" | sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    apt_refresh_once

    installed="$(apt_installed_version code)"
    candidate="$(apt_candidate_version code)"
    if [[ -n "$installed" && -n "$candidate" && "$candidate" != "(none)" && "$installed" == "$candidate" ]]; then
      ok "VS Code already latest (${installed})"
      return 0
    fi

    pkg_install code >/tmp/vscode-install.log 2>&1 || {
      warn "VS Code install/update failed (see /tmp/vscode-install.log)"
      return 1
    }
    ;;
  *)
    warn "VS Code auto-install currently implemented for apt family only"
    return 1
    ;;
  esac
}

install_antigravity() {
  local installed candidate
  case "$PKG_MANAGER" in
  apt)
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg | sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
    printf 'deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main\n' | sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null
    apt_refresh_once

    installed="$(apt_installed_version antigravity)"
    candidate="$(apt_candidate_version antigravity)"
    if [[ -n "$installed" && -n "$candidate" && "$candidate" != "(none)" && "$installed" == "$candidate" ]]; then
      ok "Antigravity already latest (${installed})"
      return 0
    fi

    pkg_install antigravity >/tmp/antigravity-install.log 2>&1 || {
      warn "Antigravity install/update failed (see /tmp/antigravity-install.log)"
      return 1
    }
    ;;
  *)
    warn "Antigravity auto-install currently implemented for apt family only"
    return 1
    ;;
  esac
}

install_opencode() {
  local current latest
  command -v bun >/dev/null 2>&1 || {
    warn "bun not available; cannot install/update OpenCode CLI"
    return 1
  }

  if command -v opencode >/dev/null 2>&1; then
    current="$(command_semver opencode)"
    latest="$(npm view opencode-ai version 2>/dev/null || true)"
    if [[ -n "$current" && -n "$latest" && "$current" == "$latest" ]]; then
      ok "OpenCode CLI already latest (${current})"
      return 0
    fi
    if [[ -z "$latest" && -n "$current" ]]; then
      ok "OpenCode CLI already installed (${current}); latest check unavailable"
      return 0
    fi
    [[ -n "$current" ]] && info "Updating OpenCode CLI (${current} -> ${latest:-unknown})"
  fi
  timeout 240 bun install -g opencode-ai >/tmp/opencode-install.log 2>&1 || {
    warn "OpenCode CLI install/update failed (see /tmp/opencode-install.log)"
    return 1
  }
}

install_codex() {
  local current latest
  command -v npm >/dev/null 2>&1 || {
    warn "npm not available; cannot install/update Codex CLI"
    return 1
  }

  if command -v codex >/dev/null 2>&1; then
    current="$(command_semver codex)"
    latest="$(npm view @openai/codex version 2>/dev/null || true)"
    if [[ -n "$current" && -n "$latest" && "$current" == "$latest" ]]; then
      ok "Codex CLI already latest (${current})"
      return 0
    fi
    if [[ -z "$latest" && -n "$current" ]]; then
      ok "Codex CLI already installed (${current}); latest check unavailable"
      return 0
    fi
    [[ -n "$current" ]] && info "Updating Codex CLI (${current} -> ${latest:-unknown})"
  fi
  timeout 240 npm install -g @openai/codex >/tmp/codex-install.log 2>&1 || {
    warn "Codex CLI install/update failed (see /tmp/codex-install.log)"
    return 1
  }
}

install_claude() {
  local current latest
  command -v npm >/dev/null 2>&1 || {
    warn "npm not available; cannot install/update Claude Code"
    return 1
  }

  if command -v claude >/dev/null 2>&1; then
    current="$(command_semver claude)"
    latest="$(npm view @anthropic-ai/claude-code version 2>/dev/null || true)"
    if [[ -n "$current" && -n "$latest" && "$current" == "$latest" ]]; then
      ok "Claude Code already latest (${current})"
      return 0
    fi
    # If latest can't be resolved, avoid unnecessary reinstall
    if [[ -z "$latest" ]]; then
      ok "Claude Code already installed (${current:-unknown}); latest check unavailable"
      return 0
    fi
    [[ -n "$current" ]] && info "Updating Claude Code (${current} -> ${latest})"
  fi
  timeout 240 npm install -g @anthropic-ai/claude-code >/tmp/claude-install.log 2>&1 || {
    warn "Claude Code install/update failed (see /tmp/claude-install.log)"
    return 1
  }
}

available_kb() {
  local path="$1"
  set -- $(df -Pk "$path" 2>/dev/null | tail -n 1)
  printf '%s' "${4:-0}"
}

install_yazi_build_deps() {
  case "$PKG_MANAGER" in
  apt)
    pkg_install_best_effort pkg-config libssl-dev
    ;;
  dnf)
    pkg_install_best_effort pkgconf-pkg-config openssl-devel
    ;;
  pacman)
    pkg_install_best_effort pkgconf openssl
    ;;
  esac
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

  install_yazi_build_deps

  local cargo_tmp_dir="$HOME/.cache/cargo-tmp"
  local cargo_target_dir="$HOME/.cache/cargo-target"
  local min_build_kb=1048576
  local tmp_kb home_kb

  mkdir -p "$cargo_tmp_dir" "$cargo_target_dir"
  tmp_kb="$(available_kb "$cargo_tmp_dir")"
  home_kb="$(available_kb "$HOME")"

  if [[ "$tmp_kb" -lt "$min_build_kb" || "$home_kb" -lt "$min_build_kb" ]]; then
    warn "Skipping Yazi build: low disk space (tmp=${tmp_kb}KB home=${home_kb}KB; need >=1GB each)"
    warn "Free space and re-run to install Yazi"
    mark_app_deferred "yazi" "low disk space for cargo build"
    return 0
  fi

  info "Building Yazi with HOME cache dirs (avoids /tmp memory/disk issues)"
  if TMPDIR="$cargo_tmp_dir" CARGO_TARGET_DIR="$cargo_target_dir" \
    timeout 1800 cargo install --locked yazi-fm yazi-cli &>/tmp/yazi-install.log; then
    export PATH="$HOME/.cargo/bin:$PATH"
    if ! grep -q 'HOME/.cargo/bin' "$HOME/.profile" 2>/dev/null; then
      printf '\nexport PATH="$HOME/.cargo/bin:$PATH"\n' >>"$HOME/.profile"
    fi
    ok "Yazi installed successfully"
    return 0
  fi

  warn "Yazi install failed or timed out. Log: /tmp/yazi-install.log"
  mark_app_deferred "yazi" "cargo install failed or timed out"
  return 0
}

install_thunar() {
  if [[ "$PKG_MANAGER" == "apt" ]]; then
    apt_refresh_once
    if ! apt_pkg_needs_install_or_update thunar; then
      ok "Thunar already latest"
      return 0
    fi
  else
    command -v thunar >/dev/null 2>&1 && {
      ok "Thunar already installed"
      return 0
    }
  fi

  case "$PKG_MANAGER" in
  apt) pkg_install thunar thunar-volman gvfs gvfs-backends ;;
  dnf) pkg_install thunar thunar-volman gvfs gvfs-archive ;;
  pacman) pkg_install thunar thunar-volman gvfs ;;
  esac
}

install_selected_extra_repo_apps() {
  local extra_pkgs=("$@")
  [[ ${#extra_pkgs[@]} -eq 0 ]] && return 0

  if [[ "$PKG_MANAGER" == "apt" ]]; then
    apt_refresh_once
    local filtered=() pkg
    for pkg in "${extra_pkgs[@]}"; do
      if apt_pkg_needs_install_or_update "$pkg"; then
        filtered+=("$pkg")
      fi
    done
    if [[ ${#filtered[@]} -eq 0 ]]; then
      ok "Selected repo apps already latest"
      return 0
    fi
    info "Installing/updating selected style applications: ${filtered[*]}"
    pkg_install_best_effort "${filtered[@]}"
    return 0
  fi

  info "Installing selected style applications: ${extra_pkgs[*]}"
  pkg_install_best_effort "${extra_pkgs[@]}"
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
    install_selected_extra_repo_apps "${extra_pkgs[@]}"
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

  if is_app_selected code && is_app_supported_on_distro code && ! command -v code >/dev/null 2>&1; then missing+=("code"); fi
  if is_app_selected opencode && ! command -v opencode >/dev/null 2>&1; then missing+=("opencode"); fi
  if is_app_selected codex && ! command -v codex >/dev/null 2>&1; then missing+=("codex"); fi
  if is_app_selected claude && ! command -v claude >/dev/null 2>&1; then missing+=("claude"); fi
  if is_app_selected yazi && ! is_app_deferred yazi && ! command -v yazi >/dev/null 2>&1; then missing+=("yazi"); fi
  if is_app_selected thunar && ! command -v thunar >/dev/null 2>&1; then missing+=("thunar"); fi
  if is_app_selected antigravity && is_app_supported_on_distro antigravity && ! pkg_is_installed antigravity; then missing+=("antigravity"); fi

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

post_reboot_health_check() {
  local missing=()
  local c
  local required=(i3 xinit zsh rustc go node bun)
  for c in "${required[@]}"; do
    command -v "$c" >/dev/null 2>&1 || missing+=("$c")
  done

  if [[ ${#missing[@]} -gt 0 ]]; then
    warn "Post-reboot health check failed; missing: ${missing[*]}"
    return 1
  fi
  ok "Post-reboot health check passed"
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

detect_installed_de_packages_csv() {
  local candidates=()
  local found=()
  local pkg

  case "$PKG_MANAGER" in
  apt)
    candidates=(gnome-shell plasma-desktop xfce4 lxde-core lxqt cinnamon mate-desktop-environment budgie-desktop dde elementary-desktop gdm3 lightdm sddm)
    ;;
  dnf)
    candidates=(gnome-shell plasma-desktop xfce4-session lxde-common lxqt-session cinnamon-session mate-session-manager budgie-desktop gdm lightdm sddm)
    ;;
  pacman)
    candidates=(gnome plasma-desktop xfce4 lxde lxqt cinnamon mate budgie-desktop gdm lightdm sddm)
    ;;
  esac

  for pkg in "${candidates[@]}"; do
    if pkg_is_installed "$pkg"; then
      found+=("$pkg")
    fi
  done

  local joined=""
  for pkg in "${found[@]}"; do
    [[ -n "$joined" ]] && joined+=","
    joined+="$pkg"
  done
  printf '%s' "$joined"
}

ensure_startx_profile_block() {
  local profile_file="$1"
  touch "$profile_file"
  if ! grep -q 'exec startx 2>/tmp/startx.log' "$profile_file" 2>/dev/null; then
    cat >>"$profile_file" <<'EOF'

# Auto-start i3 on TTY1 login (added by config installer)
if [ -z "${DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx 2>/tmp/startx.log
fi
EOF
  fi
}

configure_i3_tty_default() {
  info "Configuring i3 + TTY as default after reboot"

  cat >"$HOME/.xinitrc" <<'EOF'
#!/bin/sh
[ -f "$HOME/.Xresources" ] && xrdb -merge "$HOME/.Xresources"
[ -f "$HOME/.fehbg" ] && "$HOME/.fehbg" &
dunst &
if ! i3; then
  xterm
fi
EOF
  chmod +x "$HOME/.xinitrc"

  ensure_startx_profile_block "$HOME/.zprofile"
  ensure_startx_profile_block "$HOME/.bash_profile"

  if command -v systemctl >/dev/null 2>&1; then
    local dm
    for dm in gdm3 gdm lightdm sddm kdm lxdm mdm display-manager; do
      systemctl is-active "$dm" >/dev/null 2>&1 && sudo systemctl stop "$dm" >/dev/null 2>&1 || true
      systemctl is-enabled "$dm" >/dev/null 2>&1 && sudo systemctl disable "$dm" >/dev/null 2>&1 || true
      sudo systemctl mask "$dm" >/dev/null 2>&1 || true
    done
    sudo systemctl set-default multi-user.target >/dev/null 2>&1 || true
    sudo systemctl daemon-reload >/dev/null 2>&1 || true
  fi

  ok "TTY + i3 default prepared"
}

purge_saved_desktops_and_bloat() {
  local csv="$1"
  [[ -z "$csv" ]] && {
    info "No previously detected DE packages to purge"
    return 0
  }

  local pkgs=()
  local pkg
  IFS=',' read -r -a pkgs <<<"$csv"
  [[ ${#pkgs[@]} -eq 0 ]] && return 0

  info "Purging previously detected desktop packages"
  case "$PKG_MANAGER" in
  apt)
    sudo apt-get purge -y "${pkgs[@]}" >/dev/null 2>&1 || true
    sudo apt-get autoremove -y --purge >/dev/null 2>&1 || true
    sudo apt-get autoclean -y >/dev/null 2>&1 || true
    ;;
  dnf)
    sudo dnf -y remove "${pkgs[@]}" >/dev/null 2>&1 || true
    sudo dnf -y autoremove >/dev/null 2>&1 || true
    ;;
  pacman)
    sudo pacman -Rns --noconfirm "${pkgs[@]}" >/dev/null 2>&1 || true
    ;;
  esac

  rm -rf "$HOME/.config/gnome" "$HOME/.config/kde" "$HOME/.config/xfce4" "$HOME/.config/lxqt" "$HOME/.config/cinnamon" || true
  ok "Legacy DE packages/config cleanup completed"
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
  local is_first_run=0
  parse_args "$@"
  load_state
  setup_ui
  show_login_style_header
  ensure_not_root
  detect_os
  detect_hardware
  detect_session
  print_phase_banner
  print_detection_report
  ensure_sudo

  if [[ "$STATE_PHASE" == "none" ]]; then
    is_first_run=1
    CURRENT_DETECTED_DE_PKGS="$(detect_installed_de_packages_csv)"
    [[ -n "$CURRENT_DETECTED_DE_PKGS" ]] && info "Detected desktop packages for phase-2 purge: $CURRENT_DETECTED_DE_PKGS"
  fi

  if [[ "$STATE_PHASE" == "phase1_done" ]]; then
    STYLE="${STATE_STYLE:-$STYLE}"
    [[ -n "$STYLE" ]] || choose_style
    info "Phase 2: post-reboot health check and cleanup"

    if post_reboot_health_check; then
      print_versions_report
      purge_saved_desktops_and_bloat "$STATE_DETECTED_DE_PKGS"
      save_state 1 phase2_done "$STATE_DETECTED_DE_PKGS"
      ok "Phase 2 cleanup complete"
      return 0
    fi

    warn "Health check failed; repair installation first and rerun"
    save_state 0 phase1_done "$STATE_DETECTED_DE_PKGS"
    return 1
  fi

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
  print_deferred_apps

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
  deploy_default_zshrc || true
  ensure_jetbrains_font
  install_selected_apps

  if verify_required; then
    print_versions_report
    print_deferred_apps
    if [[ "$is_first_run" -eq 1 ]]; then
      configure_i3_tty_default
      save_state 1 phase1_done "$CURRENT_DETECTED_DE_PKGS"
      info "Phase 1 complete. Reboot and run script again for cleanup phase."
      if [[ "$IS_INTERACTIVE" -eq 1 ]]; then
        local rb
        printf 'Reboot now? [Y/n]: '
        IFS= read -r rb
        if [[ "${rb,,}" != "n" ]]; then
          sudo reboot
        fi
      fi
      return 0
    fi

    save_state 1 phase2_done "${STATE_DETECTED_DE_PKGS:-$CURRENT_DETECTED_DE_PKGS}"
    purge_legacy_desktop_stacks
  else
    save_state 0 "${STATE_PHASE:-none}" "${STATE_DETECTED_DE_PKGS:-$CURRENT_DETECTED_DE_PKGS}"
    warn "Install incomplete. Re-run the script; it will install remaining items."
    exit 1
  fi

  ok "Unified install complete"
  info "State file: ${STATE_FILE}"
  info "Log file  : ${LOG_FILE}"
}

main "$@"
