#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════
#  Vyom's VM Setup Installer
#  Target : Ubuntu / Debian / Kali — Virtual Machine ONLY
#
#  PHASE 1  (first run)   — install i3 + Xorg + apps + configs, reboot
#  PHASE 2  (second run)  — verify i3/TTY baseline, purge old DE + bloat
# ══════════════════════════════════════════════════════════════════

# No set -e — we handle every error explicitly.
# -u catches unbound variables. pipefail catches broken pipes.
set -uo pipefail

# ─────────────────────────────────────────────
#  Dracula palette
# ─────────────────────────────────────────────
PURPLE='\033[38;2;189;147;249m'
CYAN='\033[38;2;139;233;253m'
GREEN='\033[38;2;80;250;123m'
YELLOW='\033[38;2;241;250;140m'
PINK='\033[38;2;255;121;198m'
RED='\033[38;2;255;85;85m'
FG='\033[38;2;248;248;242m'
GRAY='\033[38;2;98;114;164m'
BOLD='\033[1m'
DIM='\033[2m'
RESET='\033[0m'

BAR="${GRAY}│${RESET}"
DIAMOND="${PURPLE}◆${RESET}"
DIAMOND_E="${GRAY}◇${RESET}"
TICK="${GREEN}✓${RESET}"
WARN="${YELLOW}▲${RESET}"
ARROW="${CYAN}▶${RESET}"
BOX_RULE="──────────────────────────────────────────────────"

# ─────────────────────────────────────────────
#  UI
# ─────────────────────────────────────────────
panel_open() {
  echo ""
  echo -e "${GRAY}┌${BOX_RULE}${RESET}"
}

panel_line() {
  echo -e "${BAR}  $1"
}

panel_close() {
  echo -e "${GRAY}└${BOX_RULE}${RESET}"
  echo ""
}

panel_header() {
  panel_open
  panel_line "${DIAMOND} ${BOLD}${PINK}$1${RESET}"
  [ -n "${2:-}" ] && panel_line "${GRAY}$2${RESET}"
  [ -n "${3:-}" ] && panel_line "${GRAY}$3${RESET}"
  panel_close
}

step() {
  panel_open
  panel_line "${DIAMOND} ${BOLD}${PURPLE}$1${RESET}"
  panel_close
}

select_optional_apps_interactive() {
  local options=("VS Code" "Antigravity" "Yazi")
  local vars=("INSTALL_VSCODE" "INSTALL_ANTIGRAVITY" "INSTALL_YAZI")
  local selected=(0 0 0)
  local idx=0 count="${#options[@]}"
  local i key seq mark line cursor

  if [ ! -t 0 ] || [ ! -t 1 ]; then
    warn "Non-interactive shell: using existing optional app flags"
    return 0
  fi

  for i in "${!vars[@]}"; do
    if flag_enabled "${!vars[i]}"; then
      selected[i]=1
    fi
  done

  while true; do
    clear
    panel_header "Optional Apps" "Select apps to install in Phase 1"
    panel_open
    panel_line "${GRAY}Select optional apps${RESET}"
    panel_line ""

    for i in "${!options[@]}"; do
      if [ "${selected[i]}" -eq 1 ]; then
        mark="${GREEN}●${RESET}"
      else
        mark="${GRAY}○${RESET}"
      fi

      if [ "$i" -eq "$idx" ]; then
        cursor="${CYAN}▸${RESET}"
        line="${cursor} ${mark}  ${FG}${options[i]}${RESET}"
      else
        cursor=" "
        line="${cursor} ${mark}  ${GRAY}${options[i]}${RESET}"
      fi
      panel_line "$line"
    done

    panel_line ""
    panel_line "${DIM}...${RESET}"
    panel_line "${DIM}↑/↓ move • Space/Enter: toggle • c: confirm • q: cancel${RESET}"
    panel_close

    IFS= read -rsn1 key || key=""
    if [ "$key" = $'\x1b' ]; then
      IFS= read -rsn2 seq || seq=""
      key+="$seq"
    fi

    case "$key" in
    $'\x1b[A')
      idx=$((idx - 1))
      [ "$idx" -lt 0 ] && idx=$((count - 1))
      ;;
    $'\x1b[B')
      idx=$((idx + 1))
      [ "$idx" -ge "$count" ] && idx=0
      ;;
    " " | $'\n' | $'\r')
      if [ "${selected[idx]}" -eq 1 ]; then
        selected[idx]=0
      else
        selected[idx]=1
      fi
      ;;
    c | C)
      for i in "${!vars[@]}"; do
        printf -v "${vars[i]}" '%s' "${selected[i]}"
      done
      clear
      return 0
      ;;
    q | Q)
      clear
      die "Optional app selection cancelled"
      ;;
    esac
  done
}

ok() { echo -e "  ${TICK}  ${GREEN}$1${RESET}"; }
warn() { echo -e "  ${WARN}  ${YELLOW}$1${RESET}"; }
info() { echo -e "  ${GRAY}·  $1${RESET}"; }
die() {
  echo -e "  ${RED}✗  $1${RESET}"
  exit 1
}

# ─────────────────────────────────────────────
#  Silent apt — never leaks, never exits non-zero
# ─────────────────────────────────────────────
apt_q() {
  local sub="${1:-}"
  shift || true
  export DEBIAN_FRONTEND=noninteractive
  local opts=(-y -qq
    -o Dpkg::Options::="--force-confdef"
    -o Dpkg::Options::="--force-confold")
  case "$sub" in
  update) sudo apt-get update -qq &>/dev/null || true ;;
  upgrade) sudo apt-get upgrade "${opts[@]}" &>/dev/null || true ;;
  install) sudo apt-get install "${opts[@]}" "$@" &>/dev/null || true ;;
  purge) sudo apt-get purge "${opts[@]}" "$@" &>/dev/null || true ;;
  autoremove) sudo apt-get autoremove "${opts[@]}" --purge &>/dev/null || true ;;
  autoclean) sudo apt-get autoclean -qq &>/dev/null || true ;;
  esac
}

apt_install_strict() {
  export DEBIAN_FRONTEND=noninteractive
  local opts=(-y
    -o Dpkg::Options::="--force-confdef"
    -o Dpkg::Options::="--force-confold")
  sudo apt-get install "${opts[@]}" "$@"
}

resolve_i3_package() {
  if apt-cache show i3 &>/dev/null; then
    echo "i3"
    return 0
  fi
  if apt-cache show i3-wm &>/dev/null; then
    echo "i3-wm"
    return 0
  fi
  return 1
}

# ─────────────────────────────────────────────
#  polkit — version-aware
# ─────────────────────────────────────────────
install_polkit() {
  local ec=0
  apt-cache show policykit-1 &>/dev/null || ec=$?
  if [ "$ec" -eq 0 ]; then
    apt_q install policykit-1
  else
    apt_q install polkitd pkexec
  fi
  sudo apt-mark manual policykit-1 polkitd pkexec &>/dev/null || true
}

# ─────────────────────────────────────────────
#  sudo keepalive — call once after sudo -v
# ─────────────────────────────────────────────
SUDO_PID=""
start_sudo_keepalive() {
  (while true; do
    sudo -v
    sleep 50
  done) &
  SUDO_PID=$!
}
stop_sudo_keepalive() {
  [ -n "$SUDO_PID" ] && kill "$SUDO_PID" 2>/dev/null || true
}

# ─────────────────────────────────────────────
#  Repo helpers
# ─────────────────────────────────────────────
REPO_URL="https://github.com/VyomJain6904/Config.git"
REPO_BRANCH="main"
WALLPAPER_NAME="w10.jpg"
WALLPAPER_URL="https://raw.githubusercontent.com/VyomJain6904/Config/main/Wallpapers/w10.jpg"
STATE_DIR="/var/lib/vyom-vm-setup"
STATE_FILE="${STATE_DIR}/state"
STATE_DE_FILE="${STATE_DIR}/detected_des"
INSTALL_VSCODE="${INSTALL_VSCODE:-1}"
INSTALL_ANTIGRAVITY="${INSTALL_ANTIGRAVITY:-1}"
INSTALL_YAZI="${INSTALL_YAZI:-1}"
FORCE_PHASE1="${FORCE_PHASE1:-0}"
TEMP_DIR=""
REPO_CLONED=false

cleanup() {
  stop_sudo_keepalive
  [ -n "$TEMP_DIR" ] && [ -d "$TEMP_DIR" ] && rm -rf "$TEMP_DIR" || true
}
trap cleanup EXIT

ensure_repo_cloned() {
  if [ "$REPO_CLONED" = false ]; then
    info "Cloning config repo (sparse, depth 1)..."
    TEMP_DIR="$(mktemp -d)"
    git clone --depth 1 --filter=blob:none --sparse \
      --branch "${REPO_BRANCH}" "${REPO_URL}" "${TEMP_DIR}/repo" &>/dev/null || die "Failed to clone config repo"
    git -C "${TEMP_DIR}/repo" sparse-checkout set Config-VM zsh &>/dev/null || die "Failed to fetch required config folders"
    REPO_CLONED=true
    ok "Config repo cloned"
  fi
}

copy_config_dir() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  rm -rf "$dst"
  cp -a "$src" "$dst"
}

zshrc_append() {
  local marker="$1" block="$2" z="${HOME}/.zshrc"
  [ -f "$z" ] && ! grep -qF "$marker" "$z" && printf '\n%s\n' "$block" >>"$z" || true
}

read_setup_state() {
  local state="none"
  if [ -f "$STATE_FILE" ]; then
    state="$(cat "$STATE_FILE" 2>/dev/null || echo "none")"
  fi
  case "$state" in
  phase1_done | phase2_done) echo "$state" ;;
  *) echo "none" ;;
  esac
}

write_setup_state() {
  local state="$1"
  sudo install -d -m 755 "$STATE_DIR" &>/dev/null || die "Failed to create ${STATE_DIR}"
  printf '%s\n' "$state" | sudo tee "$STATE_FILE" >/dev/null || die "Failed to write setup state"
}

write_detected_des() {
  local des="$1"
  sudo install -d -m 755 "$STATE_DIR" &>/dev/null || die "Failed to create ${STATE_DIR}"
  printf '%s\n' "$des" | sudo tee "$STATE_DE_FILE" >/dev/null || die "Failed to save detected DE list"
}

read_detected_des() {
  if [ -f "$STATE_DE_FILE" ]; then
    cat "$STATE_DE_FILE" 2>/dev/null || true
  else
    echo ""
  fi
}

flag_enabled() {
  local value="${1:-0}"
  case "${value,,}" in
  1 | true | yes | y | on) return 0 ;;
  *) return 1 ;;
  esac
}

require_command_installed() {
  local cmd="$1" label="$2"
  command -v "$cmd" &>/dev/null || die "${label} install failed (missing command: ${cmd})"
}

require_packages_installed() {
  local missing=() pkg
  for pkg in "$@"; do
    dpkg -s "$pkg" &>/dev/null || missing+=("$pkg")
  done

  if [ "${#missing[@]}" -gt 0 ]; then
    die "Missing required package(s): ${missing[*]}"
  fi
}

ensure_startx_autologin_block() {
  local profile_file="$1"
  if ! grep -q 'exec startx 2>/tmp/startx.log' "$profile_file" 2>/dev/null; then
    cat >>"$profile_file" <<'PROFILE'

# Auto-start i3 on TTY1 login
if [ -z "${DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx 2>/tmp/startx.log
fi
PROFILE
    ok "${profile_file} — startx on TTY1"
  else
    warn "${profile_file} already has startx — skipped"
  fi
}

any_display_manager_active() {
  local dm
  for dm in gdm3 gdm lightdm sddm kdm lxdm display-manager; do
    if systemctl is-active "$dm" &>/dev/null; then
      return 0
    fi
  done
  return 1
}

run_post_install_health_check() {
  step "Post-install health check"

  local failed=0

  check_cmd() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
      ok "$cmd available"
    else
      warn "$cmd missing"
      failed=$((failed + 1))
    fi
  }

  check_file() {
    local file_path="$1" label="$2"
    if [ -f "$file_path" ]; then
      ok "$label found"
    else
      warn "$label missing"
      failed=$((failed + 1))
    fi
  }

  check_cmd i3
  check_cmd startx
  check_cmd feh
  check_cmd xterm
  check_cmd alacritty
  check_cmd nvim
  check_cmd git

  if flag_enabled "$INSTALL_VSCODE"; then
    check_cmd code
  fi
  if flag_enabled "$INSTALL_ANTIGRAVITY"; then
    if dpkg -s antigravity &>/dev/null; then
      ok "antigravity package installed"
    else
      warn "antigravity package missing"
      failed=$((failed + 1))
    fi
  fi
  if flag_enabled "$INSTALL_YAZI"; then
    check_cmd yazi
  fi

  check_file "${HOME}/.xinitrc" "xinitrc"
  check_file "${HOME}/.config/i3/config" "i3 config"
  check_file "${HOME}/Pictures/${WALLPAPER_NAME}" "wallpaper ${WALLPAPER_NAME}"

  if [ "$(systemctl get-default 2>/dev/null || true)" = "multi-user.target" ]; then
    ok "default target is multi-user.target"
  else
    warn "default target is not multi-user.target"
    failed=$((failed + 1))
  fi

  if grep -qF "~/Pictures/${WALLPAPER_NAME}" "${HOME}/.config/i3/config" 2>/dev/null; then
    ok "i3 wallpaper points to ${WALLPAPER_NAME}"
  else
    warn "i3 wallpaper is not set to ${WALLPAPER_NAME}"
    failed=$((failed + 1))
  fi

  if grep -qF 'if ! i3; then' "${HOME}/.xinitrc" 2>/dev/null && grep -qF 'xterm' "${HOME}/.xinitrc" 2>/dev/null; then
    ok "xinitrc i3 fallback is configured"
  else
    warn "xinitrc fallback is missing"
    failed=$((failed + 1))
  fi

  if [ "$failed" -eq 0 ]; then
    ok "Health check passed"
  else
    warn "Health check found ${failed} issue(s)"
  fi
}

run_full_setup_stack() {
  select_optional_apps_interactive
  info "Optional apps flags: VSCode=${INSTALL_VSCODE}  Antigravity=${INSTALL_ANTIGRAVITY}  Yazi=${INSTALL_YAZI}"

  # ── Core packages for final desktop ──
  step "Core i3 packages + applications"
  apt_q install \
    git alacritty i3 neovim polybar \
    flameshot thunar network-manager-gnome mate-polkit
  require_packages_installed \
    git alacritty i3 neovim polybar \
    flameshot thunar network-manager-gnome mate-polkit
  ok "Core packages installed"

  # ── Configs ──
  step "Configs  (Config-VM)"
  ensure_repo_cloned

  for item in alacritty i3 nvim polybar; do
    local src="${TEMP_DIR}/repo/Config-VM/${item}"
    local dst="${HOME}/.config/${item}"
    if [ -d "$src" ]; then
      copy_config_dir "$src" "$dst"
      ok "${item}  →  ~/.config/${item}"
    else
      warn "${item} not found in Config-VM/${item} — skipped"
    fi
  done

  if [ -f "${HOME}/.config/polybar/launch_polybar.sh" ]; then
    chmod +x "${HOME}/.config/polybar/launch_polybar.sh"
  fi
  if [ -f "${HOME}/.config/polybar/shutdown.sh" ]; then
    chmod +x "${HOME}/.config/polybar/shutdown.sh"
  fi
  if [ -f "${HOME}/.config/polybar/target.sh" ]; then
    chmod +x "${HOME}/.config/polybar/target.sh"
  fi
  if [ -f "${HOME}/.config/polybar/vpn-ip.sh" ]; then
    chmod +x "${HOME}/.config/polybar/vpn-ip.sh"
  fi

  # Keep fallback in final xinitrc to avoid black-screen lockouts.
  cat >"${HOME}/.xinitrc" <<'XINITRC'
#!/bin/sh
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources
[ -f ~/.fehbg ] && ~/.fehbg &
dunst &

if ! i3; then
  xterm
fi
XINITRC
  chmod +x "${HOME}/.xinitrc"
  ok "~/.xinitrc updated (with xterm fallback)"

  # ── Zsh ──
  step "Zsh + Oh-My-Zsh + starship + plugins"
  apt_q install zsh
  require_packages_installed zsh
  ok "zsh installed"

  if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh (non-interactive git clone)..."
    if command -v timeout &>/dev/null; then
      timeout 120 env GIT_TERMINAL_PROMPT=0 git clone --depth 1 \
        https://github.com/ohmyzsh/ohmyzsh.git "${HOME}/.oh-my-zsh" &>/dev/null ||
        warn "Oh My Zsh clone timed out/failed — continuing"
    else
      env GIT_TERMINAL_PROMPT=0 git clone --depth 1 \
        https://github.com/ohmyzsh/ohmyzsh.git "${HOME}/.oh-my-zsh" &>/dev/null ||
        warn "Oh My Zsh clone failed — continuing"
    fi
    [ -d "${HOME}/.oh-my-zsh" ] && ok "Oh My Zsh" || warn "Oh My Zsh not installed"
  else
    warn "Oh My Zsh already present — skipped"
  fi

  local ZSH_PLUGINS="${HOME}/.oh-my-zsh/plugins"
  mkdir -p "$ZSH_PLUGINS"
  _clone_plugin() {
    local repo="$1" dest="$2" name
    name="$(basename "$dest")"
    if [ ! -d "$dest" ]; then
      git clone --depth 1 -q "$repo" "$dest" &>/dev/null && ok "$name" || warn "$name failed"
    else
      warn "$name already exists — skipped"
    fi
  }
  _clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "${ZSH_PLUGINS}/zsh-autosuggestions"
  _clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "${ZSH_PLUGINS}/zsh-syntax-highlighting"
  _clone_plugin "https://github.com/zsh-users/zsh-completions" "${ZSH_PLUGINS}/zsh-completions"
  _clone_plugin "https://github.com/zsh-users/zsh-history-substring-search" "${ZSH_PLUGINS}/zsh-history-substring-search"
  _clone_plugin "https://github.com/romkatv/zsh-defer" "${ZSH_PLUGINS}/zsh-defer"

  info "Installing Starship..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes &>/dev/null || true
  ok "Starship"

  apt_q install fzf eza fd-find jq zoxide fastfetch bat ripgrep
  ok "fzf  eza  fd-find  jq  zoxide  fastfetch  bat  ripgrep"

  info "JetBrainsMono Nerd Font v3.4.0..."
  local FONT_DIR="${HOME}/.local/share/fonts"
  mkdir -p "$FONT_DIR"
  wget -q -O "$FONT_DIR/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip" &>/dev/null || true
  unzip -qo "$FONT_DIR/JetBrainsMono.zip" -d "$FONT_DIR" &>/dev/null || true
  rm -f "$FONT_DIR/JetBrainsMono.zip"
  fc-cache -fv &>/dev/null || true
  ok "JetBrainsMono Nerd Font"

  local ZSHRC_SRC="${TEMP_DIR}/repo/zsh/.zshrc"
  if [ -f "$ZSHRC_SRC" ]; then
    [ -f "${HOME}/.zshrc" ] && cp "${HOME}/.zshrc" "${HOME}/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$ZSHRC_SRC" "${HOME}/.zshrc"
    ok ".zshrc from zsh/.zshrc"
  else
    warn "zsh/.zshrc not found in repo — skipped"
  fi

  # ── Wallpaper ──
  step "Wallpaper (w10.jpg)"
  local WALLPAPER_PATH="${HOME}/Pictures/${WALLPAPER_NAME}"
  mkdir -p "${HOME}/Pictures"
  curl -fsSL "${WALLPAPER_URL}" -o "${WALLPAPER_PATH}" || die "Failed to download wallpaper"
  feh --bg-scale "${WALLPAPER_PATH}" &>/dev/null || warn "Could not apply wallpaper immediately"
  ok "Wallpaper set: ${WALLPAPER_PATH}"

  # ── PipeWire ──
  step "PipeWire audio"
  apt_q install pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol playerctl
  ok "Packages installed"
  systemctl --user disable --now pulseaudio.service pulseaudio.socket &>/dev/null || true
  systemctl --user mask pulseaudio &>/dev/null || true
  ok "PulseAudio masked"
  systemctl --user enable --now pipewire pipewire-pulse wireplumber &>/dev/null || true
  ok "PipeWire active"

  # ── Yazi ──
  if flag_enabled "$INSTALL_YAZI"; then
    step "Yazi  (terminal file manager)"
    if ! command -v cargo &>/dev/null; then
      info "Installing Rust for cargo..."
      curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &>/dev/null || true
      source "$HOME/.cargo/env" &>/dev/null || true
      zshrc_append '.cargo/env' '. "$HOME/.cargo/env"'
      ok "Rust installed"
    else
      source "$HOME/.cargo/env" &>/dev/null || true
    fi
    info "Building yazi-fm + yazi-cli (few minutes)..."
    cargo install --locked yazi-fm yazi-cli &>/dev/null || die "Yazi build failed"
    zshrc_append '.cargo/bin' 'export PATH="$HOME/.cargo/bin:$PATH"'
    export PATH="$HOME/.cargo/bin:$PATH"
    require_command_installed yazi "Yazi"
    ok "Yazi installed"
  else
    warn "Yazi disabled by INSTALL_YAZI=${INSTALL_YAZI}"
  fi

  # ── Node.js ──
  step "Node.js LTS  (via nvm)"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh 2>/dev/null | bash &>/dev/null || true
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true
  nvm install --lts &>/dev/null || warn "nvm install failed"
  nvm use --lts &>/dev/null || true
  ok "Node.js $(node -v 2>/dev/null || echo 'installed')"
  zshrc_append 'NVM_DIR' \
    '# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

  # ── Bun ──
  step "Bun"
  curl -fsSL https://bun.sh/install | bash &>/dev/null || true
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  ok "Bun $(bun --version 2>/dev/null || echo 'installed')"
  zshrc_append 'BUN_INSTALL' \
    '# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"'

  # ── Rust ──
  step "Rust  (via rustup)"
  if ! command -v cargo &>/dev/null; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &>/dev/null || true
    source "$HOME/.cargo/env" &>/dev/null || true
  else
    rustup update stable &>/dev/null || true
  fi
  ok "$(rustc --version 2>/dev/null || echo 'rust installed')"
  zshrc_append '.cargo/env' '. "$HOME/.cargo/env"'

  # ── Go ──
  step "Go  (latest stable)"
  local GO_VERSION
  GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" 2>/dev/null | head -1 || true)
  if [ -z "$GO_VERSION" ]; then
    warn "Could not fetch Go version — skipping Go install"
  else
    info "Downloading ${GO_VERSION}..."
    curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz || true
    sudo rm -rf /usr/local/go
    sudo tar -C /usr/local -xzf /tmp/go.tar.gz &>/dev/null || true
    rm -f /tmp/go.tar.gz
    export PATH="/usr/local/go/bin:$PATH"
    ok "$(go version 2>/dev/null || echo 'go installed')"
    zshrc_append '/usr/local/go/bin' 'export PATH="/usr/local/go/bin:$PATH"'
  fi

  # ── VS Code ──
  if flag_enabled "$INSTALL_VSCODE"; then
    step "VS Code"
    info "Adding Microsoft repo..."
    sudo mkdir -p /etc/apt/keyrings
    wget -qO- https://packages.microsoft.com/keys/microsoft.asc |
      gpg --dearmor 2>/dev/null |
      sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
    echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" |
      sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
    apt_q update
    apt_q install code
    require_command_installed code "VS Code"
    ok "VS Code installed"
  else
    warn "VS Code disabled by INSTALL_VSCODE=${INSTALL_VSCODE}"
  fi

  # ── Antigravity ──
  if flag_enabled "$INSTALL_ANTIGRAVITY"; then
    step "Antigravity"
    info "Adding repo..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg |
      sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg &>/dev/null || true
    echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] \
https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" |
      sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null
    apt_q update
    apt_q install antigravity
    require_packages_installed antigravity
    ok "Antigravity installed"
  else
    warn "Antigravity disabled by INSTALL_ANTIGRAVITY=${INSTALL_ANTIGRAVITY}"
  fi

  # ── OpenCode CLI ──
  step "OpenCode CLI  (via bun)"
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
  if ! command -v bun &>/dev/null; then
    curl -fsSL https://bun.sh/install | bash &>/dev/null || true
    export PATH="$BUN_INSTALL/bin:$PATH"
    zshrc_append 'BUN_INSTALL' \
      '# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"'
  fi
  bun install -g opencode-ai &>/dev/null || true
  ok "OpenCode CLI installed"

  # ── Codex CLI ──
  step "Codex CLI  (via npm)"
  if ! command -v npm &>/dev/null; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh 2>/dev/null | bash &>/dev/null || true
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true
    nvm install --lts &>/dev/null && nvm use --lts &>/dev/null || true
    zshrc_append 'NVM_DIR' \
      '# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
  fi
  npm install -g @openai/codex &>/dev/null || true
  ok "Codex CLI installed"

  run_post_install_health_check
}

# ─────────────────────────────────────────────
#  DE detection
# ─────────────────────────────────────────────
declare -A DE_PACKAGES
DE_PACKAGES["gnome"]="gnome gnome-shell gnome-session gnome-terminal gnome-control-center gdm3 ubuntu-desktop ubuntu-gnome-desktop gnome-software gnome-online-accounts"
DE_PACKAGES["kde"]="kde-plasma-desktop plasma-desktop sddm kwin-x11 kubuntu-desktop kde-standard"
DE_PACKAGES["xfce"]="xfce4 xfce4-session xfce4-panel xfce4-terminal lightdm xubuntu-desktop xfce4-goodies"
DE_PACKAGES["lxde"]="lxde lxde-core lxsession lxdm lubuntu-desktop"
DE_PACKAGES["lxqt"]="lxqt lxqt-session lxqt-panel sddm lubuntu-desktop"
DE_PACKAGES["mate"]="mate-desktop-environment mate-session-manager lightdm ubuntu-mate-desktop"
DE_PACKAGES["cinnamon"]="cinnamon cinnamon-session lightdm"
DE_PACKAGES["budgie"]="budgie-desktop lightdm ubuntu-budgie-desktop"
DE_PACKAGES["deepin"]="dde dde-desktop lightdm"
DE_PACKAGES["pantheon"]="elementary-desktop lightdm"

detect_des() {
  local found=()
  for de in gnome kde xfce lxde lxqt mate cinnamon budgie deepin pantheon; do
    case "$de" in
    gnome) dpkg -l gnome-shell &>/dev/null && found+=("gnome") || true ;;
    kde) dpkg -l plasma-desktop &>/dev/null && found+=("kde") || true ;;
    xfce) dpkg -l xfce4 &>/dev/null && found+=("xfce") || true ;;
    lxde) dpkg -l lxde &>/dev/null && found+=("lxde") || true ;;
    lxqt) dpkg -l lxqt &>/dev/null && found+=("lxqt") || true ;;
    mate) dpkg -l mate-desktop-environment &>/dev/null && found+=("mate") || true ;;
    cinnamon) dpkg -l cinnamon &>/dev/null && found+=("cinnamon") || true ;;
    budgie) dpkg -l budgie-desktop &>/dev/null && found+=("budgie") || true ;;
    deepin) dpkg -l dde &>/dev/null && found+=("deepin") || true ;;
    pantheon) dpkg -l elementary-desktop &>/dev/null && found+=("pantheon") || true ;;
    esac
  done
  echo "${found[*]:-}"
}

# ══════════════════════════════════════════════
#  PHASE 1
# ══════════════════════════════════════════════
run_phase1() {
  panel_header "Phase 1 of 2" "Install i3 + Xorg + apps + configs" "Run this script again after reboot for Phase 2"

  local DETECTED_DES
  DETECTED_DES=$(detect_des)
  [ -n "$DETECTED_DES" ] &&
    echo -e "  ${WARN}  ${YELLOW}Detected DE(s): ${BOLD}${DETECTED_DES}${RESET}" &&
    echo -e "  ${GRAY}  Will be purged in Phase 2 after reboot${RESET}" && echo ""

  echo -ne "  ${DIAMOND_E} ${FG}Proceed with Phase 1?${RESET}  ${DIM}[${RESET}${GREEN}Y${RESET}${DIM}/n]${RESET}  "
  IFS= read -r ans
  [[ "${ans,,}" == "n" ]] && echo -e "\n  ${GRAY}Cancelled.${RESET}\n" && exit 0
  echo ""

  info "Caching sudo (one prompt, stays alive)..."
  sudo -v
  start_sudo_keepalive

  # ── Update ──
  step "System Update"
  info "apt update + upgrade..."
  apt_q update
  apt_q upgrade
  apt_q install curl wget gpg ca-certificates unzip git build-essential
  ok "System up to date"

  # ── Install i3 + Xorg ──
  step "i3 + Xorg  (minimal — no compositor)"
  local I3_PKG
  I3_PKG="$(resolve_i3_package)" || die "Could not resolve i3 package (tried: i3, i3-wm). Run apt update and check repositories."
  info "Installing packages (i3 package: ${I3_PKG})..."
  apt_install_strict \
    xorg xinit xserver-xorg xserver-xorg-input-all \
    x11-xserver-utils "${I3_PKG}" i3status i3lock \
    feh xclip xdotool numlockx dbus-x11 xterm \
    udisks2 upower xdg-user-dirs xdg-utils dunst || \
    die "Failed to install core i3/Xorg packages. Check apt output above."
  require_packages_installed xorg xinit i3status i3lock feh xterm
  require_command_installed i3 "i3 window manager"
  ok "Xorg + i3 installed"

  info "Installing polkit..."
  install_polkit
  ok "polkit"

  # Mark ALL newly installed Xorg/i3 packages as manually installed
  # so Phase 2 autoremove cannot accidentally remove them
  info "Marking i3 + Xorg packages as manual..."
  sudo apt-mark manual \
    xorg xinit xserver-xorg xserver-xorg-input-all \
    x11-xserver-utils i3 i3status i3lock \
    feh xclip xdotool numlockx dbus dbus-x11 \
    udisks2 upower xdg-user-dirs xdg-utils dunst \
    libx11-6 libxcb1 libxext6 libxrender1 libxfixes3 \
    &>/dev/null || true
  ok "Packages marked manual"

  # ── ~/.xinitrc ──
  # IMPORTANT: xinitrc must have a fallback — if i3 config is missing
  # or broken, start a plain xterm so you never get a black screen
  cat >"${HOME}/.xinitrc" <<'XINITRC'
#!/bin/sh
# xrdb must finish before i3 reads Xresources
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources
[ -f ~/.fehbg ] && ~/.fehbg &
dunst &

# Run i3 in foreground. If it exits with an error, fall back to xterm
# so you always have a shell and never a permanent black screen.
if ! i3; then
  xterm
fi
XINITRC
  chmod +x "${HOME}/.xinitrc"
  ok "~/.xinitrc  (with xterm fallback)"

  # ── startx on TTY1 for both zsh and bash login shells ──
  ensure_startx_autologin_block "${HOME}/.zprofile"
  ensure_startx_autologin_block "${HOME}/.bash_profile"

  # ── Kill ALL display managers ──
  step "Disabling display managers"

  # Stop + disable + mask every known DM
  for dm in gdm3 gdm lightdm sddm kdm lxdm display-manager; do
    systemctl is-active "$dm" &>/dev/null && sudo systemctl stop "$dm" &>/dev/null || true
    systemctl is-enabled "$dm" &>/dev/null && sudo systemctl disable "$dm" &>/dev/null || true
    sudo systemctl mask "$dm" &>/dev/null || true
  done
  ok "All known DMs stopped, disabled, masked"

  # /etc/X11/default-display-manager — Debian/Kali reads this directly,
  # bypassing systemd entirely. Must be removed.
  if [ -f /etc/X11/default-display-manager ]; then
    sudo mv /etc/X11/default-display-manager \
      /etc/X11/default-display-manager.bak
    ok "/etc/X11/default-display-manager removed"
  fi

  # display-manager.service symlink — remove so nothing re-links it
  if [ -L /etc/systemd/system/display-manager.service ]; then
    sudo rm -f /etc/systemd/system/display-manager.service
    ok "display-manager.service symlink removed"
  fi

  # Force TTY as default target
  sudo systemctl set-default multi-user.target &>/dev/null
  sudo systemctl daemon-reload &>/dev/null
  ok "systemd default → multi-user.target"

  # ── Install full stack in Phase 1 ──
  run_full_setup_stack

  # ── Save persistent phase state for Phase 2 ──
  write_detected_des "$DETECTED_DES"
  write_setup_state "phase1_done"
  ok "Phase 1 state saved (${STATE_FILE})"

  # ── Done ──
  panel_open
  panel_line "${DIAMOND} ${BOLD}${PINK}Phase 1 complete${RESET}"
  panel_line ""
  panel_line "${GRAY}After reboot you will land on TTY login.${RESET}"
  panel_line "${GRAY}Login as your user — i3 starts automatically.${RESET}"
  panel_line ""
  panel_line "${GRAY}If the screen is black: check /tmp/startx.log${RESET}"
  panel_line "${GRAY}Open a terminal in i3 then run this script again.${RESET}"
  panel_close
  echo -ne "  ${DIAMOND_E} ${FG}Reboot now?${RESET}  ${DIM}[${RESET}${GREEN}Y${RESET}${DIM}/n]${RESET}  "
  IFS= read -r rb
  echo ""
  if [[ "${rb,,}" != "n" ]]; then
    echo -e "  ${ARROW}  Rebooting in 3 seconds..."
    sleep 3
    sudo reboot
  else
    echo -e "  ${WARN}  ${YELLOW}Run ${CYAN}sudo reboot${YELLOW} when ready${RESET}"
  fi
}

# ══════════════════════════════════════════════
#  PHASE 2
# ══════════════════════════════════════════════
run_phase2() {
  panel_header "Phase 2 of 2" "Verify i3/TTY baseline  ·  purge old DE + bloat"

  local DETECTED_DES=""
  DETECTED_DES="$(read_detected_des)"

  if [ -n "$DETECTED_DES" ]; then
    echo -e "  ${WARN}  ${YELLOW}Will purge: ${BOLD}${DETECTED_DES}${RESET}"
  else
    echo -e "  ${GRAY}·  No DE recorded — skipping purge step${RESET}"
  fi
  echo ""

  echo -ne "  ${DIAMOND_E} ${FG}Proceed with Phase 2?${RESET}  ${DIM}[${RESET}${GREEN}Y${RESET}${DIM}/n]${RESET}  "
  IFS= read -r ans
  [[ "${ans,,}" == "n" ]] && echo -e "\n  ${GRAY}Cancelled.${RESET}\n" && exit 0
  echo ""

  info "Caching sudo..."
  sudo -v
  start_sudo_keepalive

  # ── Update ──
  step "System Update"
  apt_q update
  apt_q upgrade
  ok "System up to date"

  # ── Safety checks ──
  step "Safety checks before purge"
  [ "$(systemctl get-default 2>/dev/null || true)" = "multi-user.target" ] ||
    die "Phase 2 blocked: default target is not multi-user.target"
  any_display_manager_active && die "Phase 2 blocked: a display manager is still active"
  require_packages_installed xorg xinit i3status i3lock feh
  require_command_installed i3 "i3 window manager"
  ok "Running on TTY+i3 baseline, safe to continue"

  # ── Purge old DE ──
  if [ -n "$DETECTED_DES" ]; then
    step "Purging old DE + bloatware"

    # Pin everything critical BEFORE autoremove runs
    info "Pinning critical packages..."
    sudo apt-mark manual \
      xorg xinit xserver-xorg xserver-xorg-input-all x11-xserver-utils \
      i3 i3status i3lock feh xclip xdotool numlockx \
      dbus dbus-x11 udisks2 upower xdg-utils xdg-user-dirs dunst \
      alacritty neovim polybar git curl wget gpg xterm \
      flameshot thunar network-manager-gnome mate-polkit \
      build-essential libx11-6 libxcb1 libxext6 libxrender1 libxfixes3 \
      &>/dev/null || true
    sudo apt-mark manual polkitd pkexec policykit-1 &>/dev/null || true
    ok "Critical packages pinned"

    local PURGE_PKGS=""
    for de in $DETECTED_DES; do
      [ -n "${DE_PACKAGES[$de]:-}" ] && PURGE_PKGS="${PURGE_PKGS} ${DE_PACKAGES[$de]}" || true
    done
    PURGE_PKGS="${PURGE_PKGS# }"

    if [ -n "$PURGE_PKGS" ]; then
      info "Purging old DE packages..."
      # shellcheck disable=SC2086
      apt_q purge $PURGE_PKGS
      ok "Old DE purged"
    fi

    info "Running autoremove..."
    apt_q autoremove
    apt_q autoclean
    ok "Orphans cleaned"

    ok "Old DE cleanup finished"
  fi
  write_setup_state "phase2_done"
  ok "Phase 2 state saved (${STATE_FILE})"

  run_post_install_health_check

  # ── Done ──
  panel_open
  panel_line "${GREEN}${BOLD}✓  Setup complete!${RESET}"
  panel_close
  echo -e "  ${ARROW}  Run ${CYAN}exec zsh${RESET} to load the new shell"
  echo -e "  ${ARROW}  Polybar network — check interface with ${CYAN}ip link${RESET}"
  echo ""
}

# ══════════════════════════════════════════════
#  ENTRY
# ══════════════════════════════════════════════
command -v apt &>/dev/null || die "apt not found — Ubuntu/Debian/Kali only."

STATE="$(read_setup_state)"

if flag_enabled "$FORCE_PHASE1"; then
  warn "FORCE_PHASE1 enabled — rerunning full Phase 1 setup"
  STATE="none"
fi

if [ "$STATE" = "none" ]; then
  echo -e "  ${DIAMOND} ${BOLD}${CYAN}Phase 1 detected${RESET}  ${GRAY}— first run${RESET}"
  run_phase1
elif [ "$STATE" = "phase1_done" ]; then
  echo -e "  ${DIAMOND} ${BOLD}${CYAN}Phase 2 detected${RESET}  ${GRAY}— post-reboot cleanup${RESET}"
  run_phase2
else
  echo -e "  ${DIAMOND} ${BOLD}${CYAN}Setup already completed${RESET}  ${GRAY}— nothing to reinstall${RESET}"
  run_post_install_health_check
fi
