#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════
#  Vyom's VM Setup Installer
#  Target : Ubuntu / Debian / Kali — Virtual Machine ONLY
#  Purpose: Lightweight dev + pentesting environment
#
#  PHASE 1  (first run)
#    • Install i3 + Xorg
#    • Disable display manager, set TTY as default
#    • Reboot into i3
#
#  PHASE 2  (run again after reboot)
#    • Purge old DE + all bloatware
#    • Install configs (alacritty / i3 / nvim / polybar)
#    • Install dev tools (zsh, yazi, pipewire, node, bun, rust, go…)
# ══════════════════════════════════════════════════════════════════

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

# ─────────────────────────────────────────────
#  UI helpers
# ─────────────────────────────────────────────
intro() {
  clear
  echo ""
  echo -e "${PURPLE}${BOLD}  ██╗   ██╗██╗   ██╗ ██████╗ ███╗   ███╗${RESET}"
  echo -e "${PURPLE}${BOLD}  ██║   ██║╚██╗ ██╔╝██╔═══██╗████╗ ████║${RESET}"
  echo -e "${CYAN}${BOLD}  ██║   ██║ ╚████╔╝ ██║   ██║██╔████╔██║${RESET}"
  echo -e "${CYAN}${BOLD}  ╚██╗ ██╔╝  ╚██╔╝  ██║   ██║██║╚██╔╝██║${RESET}"
  echo -e "${PINK}${BOLD}   ╚████╔╝    ██║   ╚██████╔╝██║ ╚═╝ ██║${RESET}"
  echo -e "${PINK}${BOLD}    ╚═══╝     ╚═╝    ╚═════╝ ╚═╝     ╚═╝${RESET}"
  echo ""
  echo -e "  ${GRAY}VM Setup Installer  ·  dev + pentesting${RESET}"
  echo -e "  ${GRAY}Ubuntu / Debian / Kali  ·  Dracula${RESET}"
  echo ""
  echo -e "${GRAY}  ┌─────────────────────────────────────────┐${RESET}"
  echo -e "${GRAY}  │${RESET}  ${PURPLE}Target${RESET}  Virtual Machine only            ${GRAY}│${RESET}"
  echo -e "${GRAY}  │${RESET}  ${PURPLE}Author${RESET}  Vyom Jain                       ${GRAY}│${RESET}"
  echo -e "${GRAY}  │${RESET}  ${PURPLE}Repo  ${RESET}  github.com/VyomJain6904/Config  ${GRAY}│${RESET}"
  echo -e "${GRAY}  └─────────────────────────────────────────┘${RESET}"
  echo ""
}

step() {
  echo ""
  echo -e "${GRAY}┌──────────────────────────────────────────${RESET}"
  echo -e "${BAR}  ${DIAMOND} ${BOLD}${PURPLE}$1${RESET}"
  echo -e "${GRAY}└──────────────────────────────────────────${RESET}"
  echo ""
}
ok() { echo -e "  ${TICK}  ${GREEN}$1${RESET}"; }
warn() { echo -e "  ${WARN}  ${YELLOW}$1${RESET}"; }
info() { echo -e "  ${GRAY}·  $1${RESET}"; }
die() {
  echo -e "  ${RED}✗  $1${RESET}"
  exit 1
}

# ─────────────────────────────────────────────
#  Silent apt — never leaks output
# ─────────────────────────────────────────────
apt_q() {
  local sub="$1"
  shift || true
  local opts=(-y -qq -o Dpkg::Options::="--force-confdef" -o Dpkg::Options::="--force-confold")
  export DEBIAN_FRONTEND=noninteractive
  case "$sub" in
  update) sudo apt-get update -qq "$@" &>/dev/null ;;
  upgrade) sudo apt-get upgrade "${opts[@]}" "$@" &>/dev/null ;;
  install) sudo apt-get install "${opts[@]}" "$@" &>/dev/null ;;
  purge) sudo apt-get purge "${opts[@]}" "$@" &>/dev/null || true ;;
  autoremove) sudo apt-get autoremove "${opts[@]}" --purge &>/dev/null || true ;;
  autoclean) sudo apt-get autoclean -qq &>/dev/null || true ;;
  esac
}

# polkit varies across distro versions
install_polkit() {
  if apt-cache show policykit-1 &>/dev/null; then
    apt_q install policykit-1
  else
    apt_q install polkitd pkexec
  fi
}

# ─────────────────────────────────────────────
#  Repo helpers
# ─────────────────────────────────────────────
REPO_URL="https://github.com/VyomJain6904/Config.git"
REPO_BRANCH="main"
temp_dir=""
cleanup() { [ -n "${temp_dir}" ] && [ -d "${temp_dir}" ] && rm -rf "${temp_dir}"; }
trap cleanup EXIT

REPO_CLONED=false
ensure_repo_cloned() {
  if [ "$REPO_CLONED" = false ]; then
    info "Cloning config repo (sparse, depth 1)..."
    temp_dir="$(mktemp -d)"
    git clone --depth 1 --filter=blob:none --sparse \
      --branch "${REPO_BRANCH}" "${REPO_URL}" "${temp_dir}/repo" &>/dev/null
    git -C "${temp_dir}/repo" sparse-checkout set Config-VM &>/dev/null
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
  [ -f "$z" ] && ! grep -qF "$marker" "$z" && printf '\n%s\n' "$block" >>"$z"
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
  echo "${found[@]:-}"
}

# ─────────────────────────────────────────────
#  Phase detection
#  PHASE 1 → old DE still present, or no DISPLAY set yet
#  PHASE 2 → marker file exists (we already ran phase 1)
# ─────────────────────────────────────────────
PHASE_MARKER="${HOME}/.vyom_setup_phase1_done"

detect_phase() {
  if [ -f "$PHASE_MARKER" ]; then
    echo "2"
  else
    echo "1"
  fi
}

# ══════════════════════════════════════════════
#  PHASE 1 — i3 + Xorg, disable DM, reboot
# ══════════════════════════════════════════════
run_phase1() {
  echo ""
  echo -e "${GRAY}┌──────────────────────────────────────────────────${RESET}"
  echo -e "${BAR}  ${DIAMOND} ${BOLD}${PINK}Phase 1 of 2${RESET}"
  echo -e "${BAR}  ${GRAY}Install i3 + Xorg · disable DE · reboot${RESET}"
  echo -e "${BAR}  ${GRAY}After reboot, run this script again for Phase 2${RESET}"
  echo -e "${GRAY}└──────────────────────────────────────────────────${RESET}"
  echo ""

  DETECTED_DES=$(detect_des)

  if [ -n "$DETECTED_DES" ]; then
    echo -e "  ${WARN}  ${YELLOW}Detected DE(s): ${BOLD}${DETECTED_DES}${RESET}"
    echo -e "  ${GRAY}They will be purged in Phase 2 (after reboot)${RESET}"
    echo ""
  fi

  echo -ne "  ${DIAMOND_E} ${FG}Proceed with Phase 1?${RESET}  ${DIM}[${RESET}${GREEN}Y${RESET}${DIM}/n]${RESET}  "
  IFS= read -r ans
  [[ "${ans,,}" == "n" ]] && echo "" && echo -e "  ${GRAY}Cancelled.${RESET}" && exit 0
  echo ""

  # ── System update ──
  step "System Update"
  info "apt update + upgrade..."
  apt_q update
  apt_q upgrade
  apt_q install curl wget gpg ca-certificates unzip git build-essential
  ok "System up to date"

  # ── i3 + Xorg ──
  step "i3 + Xorg  (minimal, no compositor)"
  info "Installing xorg + i3..."
  apt_q install \
    xorg xinit xserver-xorg xserver-xorg-input-all \
    x11-xserver-utils i3 i3status i3lock \
    feh arandr xclip xdotool numlockx dbus-x11 \
    udisks2 upower xdg-user-dirs xdg-utils dunst
  ok "Xorg + i3"

  info "Installing polkit..."
  install_polkit
  ok "polkit"

  # ~/.xinitrc — lean, no picom, no nm-applet (VM doesn't need them)
  cat >"${HOME}/.xinitrc" <<'XINITRC'
#!/bin/sh
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources
[ -f ~/.fehbg ] && ~/.fehbg &
dunst &
exec i3
XINITRC
  chmod +x "${HOME}/.xinitrc"
  ok "~/.xinitrc"

  # Auto-startx on TTY1 — written to ALL login shell configs
  # Kali uses zsh by default; .zprofile is the login file for zsh.
  # .bash_profile and .profile are added later as fallbacks.
  for shell_rc in "${HOME}/.zprofile" "${HOME}/.zlogin"; do
    if ! grep -q 'startx' "$shell_rc" 2>/dev/null; then
      cat >>"$shell_rc" <<'ZPROF'

# Auto-start i3 on TTY1
if [ -z "${DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx
fi
ZPROF
      ok "$shell_rc  auto-startx on TTY1"
    else
      warn "$shell_rc already has startx — skipped"
    fi
  done

  # ── Kill display manager — every method, no survivors ──
  info "Disabling all display managers..."

  # 1. systemctl disable + stop (catches systemd-managed DMs)
  for dm in gdm3 gdm lightdm sddm kdm lxdm display-manager; do
    systemctl is-active "$dm" &>/dev/null && sudo systemctl stop "$dm" &>/dev/null || true
    systemctl is-enabled "$dm" &>/dev/null && sudo systemctl disable "$dm" &>/dev/null || true
    # mask so nothing can re-enable it before reboot
    sudo systemctl mask "$dm" &>/dev/null || true
  done

  # 2. /etc/X11/default-display-manager — used by Debian/Kali even
  #    when systemd isn't managing the DM directly
  if [ -f /etc/X11/default-display-manager ]; then
    sudo mv /etc/X11/default-display-manager \
      /etc/X11/default-display-manager.bak
    ok "/etc/X11/default-display-manager backed up + removed"
  fi

  # 3. /etc/systemd/system/display-manager.service symlink
  if [ -L /etc/systemd/system/display-manager.service ]; then
    sudo rm -f /etc/systemd/system/display-manager.service
    ok "display-manager.service symlink removed"
  fi

  # 4. Force multi-user target as default
  sudo systemctl set-default multi-user.target &>/dev/null
  sudo systemctl daemon-reload &>/dev/null
  ok "systemd default → multi-user.target (TTY)"

  # 5. ~/.bash_profile fallback for bash logins (some distros use this)
  BASH_PROFILE="${HOME}/.bash_profile"
  if ! grep -q 'startx' "$BASH_PROFILE" 2>/dev/null; then
    cat >>"$BASH_PROFILE" <<'BASHPROF'

# Auto-start i3 on TTY1
if [ -z "${DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx
fi
BASHPROF
    ok "~/.bash_profile  auto-startx on TTY1"
  fi

  # 6. ~/.profile fallback (sh-compatible, covers all login shells)
  PROFILE="${HOME}/.profile"
  if ! grep -q 'startx' "$PROFILE" 2>/dev/null; then
    cat >>"$PROFILE" <<'PROF'

# Auto-start i3 on TTY1
if [ -z "${DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx
fi
PROF
    ok "~/.profile  auto-startx on TTY1"
  fi

  ok "All display managers disabled + masked"

  # Write phase marker so Phase 2 knows DE list to purge
  echo "$DETECTED_DES" >"$PHASE_MARKER"
  ok "Phase 1 marker written"

  # ── Reboot ──
  echo ""
  echo -e "${GRAY}┌──────────────────────────────────────────────────${RESET}"
  echo -e "${BAR}  ${DIAMOND} ${BOLD}${PINK}Phase 1 complete — reboot required${RESET}"
  echo -e "${BAR}"
  echo -e "${BAR}  ${GRAY}After reboot:${RESET}"
  echo -e "${BAR}    ${ARROW}  Login at TTY1 — i3 starts automatically${RESET}"
  echo -e "${BAR}    ${ARROW}  Open a terminal in i3${RESET}"
  echo -e "${BAR}    ${ARROW}  Run this script again for Phase 2${RESET}"
  echo -e "${GRAY}└──────────────────────────────────────────────────${RESET}"
  echo ""
  echo -ne "  ${DIAMOND_E} ${FG}Reboot now?${RESET}  ${DIM}[${RESET}${GREEN}Y${RESET}${DIM}/n]${RESET}  "
  IFS= read -r rb
  echo ""
  if [[ "${rb,,}" != "n" ]]; then
    echo -e "  ${ARROW}  Rebooting in 3 seconds..."
    sleep 3
    sudo reboot
  else
    echo -e "  ${WARN}  ${YELLOW}Reboot manually with ${CYAN}sudo reboot${YELLOW} when ready${RESET}"
  fi
}

# ══════════════════════════════════════════════
#  PHASE 2 — purge DE, install configs + tools
# ══════════════════════════════════════════════
run_phase2() {
  echo ""
  echo -e "${GRAY}┌──────────────────────────────────────────────────${RESET}"
  echo -e "${BAR}  ${DIAMOND} ${BOLD}${PINK}Phase 2 of 2${RESET}"
  echo -e "${BAR}  ${GRAY}Purge old DE · install configs + dev tools${RESET}"
  echo -e "${GRAY}└──────────────────────────────────────────────────${RESET}"
  echo ""

  # Read DE list saved in Phase 1
  DETECTED_DES=""
  [ -f "$PHASE_MARKER" ] && DETECTED_DES=$(cat "$PHASE_MARKER")

  if [ -n "$DETECTED_DES" ]; then
    echo -e "  ${WARN}  ${YELLOW}Will purge: ${BOLD}${DETECTED_DES}${RESET}"
  else
    echo -e "  ${GRAY}·  No DE detected in Phase 1 — skipping purge${RESET}"
  fi

  echo ""
  echo -ne "  ${DIAMOND_E} ${FG}Proceed with Phase 2?${RESET}  ${DIM}[${RESET}${GREEN}Y${RESET}${DIM}/n]${RESET}  "
  IFS= read -r ans
  [[ "${ans,,}" == "n" ]] && echo "" && echo -e "  ${GRAY}Cancelled.${RESET}" && exit 0
  echo ""

  # ── System update ──
  step "System Update"
  apt_q update
  apt_q upgrade
  ok "System up to date"

  # ── Purge old DE + bloatware ──
  if [ -n "$DETECTED_DES" ]; then
    step "Purging old DE + bloatware"

    # Pin everything we need before autoremove runs
    info "Pinning critical packages..."
    sudo apt-mark manual \
      i3 i3status i3lock xorg xinit \
      xserver-xorg xserver-xorg-input-all x11-xserver-utils \
      feh arandr xclip xdotool numlockx dbus dbus-x11 \
      udisks2 upower xdg-utils xdg-user-dirs dunst \
      alacritty neovim polybar git curl wget \
      pipewire pipewire-pulse pipewire-alsa wireplumber \
      pavucontrol playerctl \
      build-essential &>/dev/null || true
    # pin polkit whichever variant is installed
    sudo apt-mark manual polkitd pkexec policykit-1 &>/dev/null || true
    ok "Critical packages pinned"

    # Build purge list from saved DE names
    PURGE_PKGS=""
    for de in $DETECTED_DES; do
      [ -n "${DE_PACKAGES[$de]:-}" ] && PURGE_PKGS="${PURGE_PKGS} ${DE_PACKAGES[$de]}"
    done
    PURGE_PKGS="${PURGE_PKGS# }"

    if [ -n "$PURGE_PKGS" ]; then
      info "Purging: ${PURGE_PKGS}"
      # shellcheck disable=SC2086
      apt_q purge $PURGE_PKGS
      ok "Old DE packages purged"
    fi

    info "Removing orphaned packages..."
    apt_q autoremove
    apt_q autoclean
    ok "Orphans removed"

    rm -f "$PHASE_MARKER"
    ok "Phase marker cleaned up"
  fi

  # ── Base packages + configs ──
  step "Base packages + configs  (Config-VM)"
  apt_q install git alacritty i3 neovim polybar
  ok "alacritty  i3  neovim  polybar  git"

  ensure_repo_cloned

  for item in alacritty i3 nvim polybar; do
    src="${temp_dir}/repo/Config-VM/${item}"
    dst="${HOME}/.config/${item}"
    if [ -d "$src" ]; then
      copy_config_dir "$src" "$dst"
      ok "${item}  →  ~/.config/${item}"
    else
      warn "${item} not found in Config-VM/${item} — skipped"
    fi
  done

  # ── Zsh ──
  step "Zsh + Oh-My-Zsh + starship + plugins"

  apt_q install zsh
  sudo chsh -s "$(which zsh)" "$USER" &>/dev/null || true
  ok "zsh — default shell"

  if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    info "Installing Oh My Zsh..."
    RUNZSH=no CHSH=no sh -c \
      "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" &>/dev/null
    ok "Oh My Zsh"
  else
    warn "Oh My Zsh already present — skipped"
  fi

  ZSH_PLUGINS="${HOME}/.oh-my-zsh/plugins"
  _clone_plugin() {
    local repo="$1" dest="$2" name
    name="$(basename "$dest")"
    if [ ! -d "$dest" ]; then
      git clone --depth 1 -q "$repo" "$dest" &>/dev/null && ok "$name"
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
  curl -sS https://starship.rs/install.sh | sh -s -- --yes &>/dev/null
  ok "Starship"

  apt_q install fzf eza fd-find jq zoxide fastfetch bat ripgrep
  ok "fzf  eza  fd-find  jq  zoxide  fastfetch  bat  ripgrep"

  info "Installing JetBrainsMono Nerd Font v3.4.0..."
  FONT_DIR="${HOME}/.local/share/fonts"
  mkdir -p "$FONT_DIR"
  wget -q -O "$FONT_DIR/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip" &>/dev/null
  unzip -qo "$FONT_DIR/JetBrainsMono.zip" -d "$FONT_DIR" &>/dev/null
  rm -f "$FONT_DIR/JetBrainsMono.zip"
  fc-cache -fv &>/dev/null
  ok "JetBrainsMono Nerd Font"

  ensure_repo_cloned
  ZSHRC_SRC="${temp_dir}/repo/Config-VM/zsh/.zshrc"
  if [ -f "$ZSHRC_SRC" ]; then
    [ -f "${HOME}/.zshrc" ] && cp "${HOME}/.zshrc" "${HOME}/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
    cp "$ZSHRC_SRC" "${HOME}/.zshrc"
    ok ".zshrc from Config-VM/zsh/.zshrc"
  else
    warn "Config-VM/zsh/.zshrc not found — skipped"
  fi

  # ── PipeWire ──
  step "PipeWire audio"
  apt_q install pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol playerctl
  ok "Packages installed"
  systemctl --user disable --now pulseaudio.service pulseaudio.socket &>/dev/null || true
  systemctl --user mask pulseaudio &>/dev/null || true
  ok "PulseAudio masked"
  systemctl --user enable --now pipewire pipewire-pulse wireplumber &>/dev/null || true
  ok "PipeWire active for ${USER}"

  # ── Yazi ──
  step "Yazi  (terminal file manager)"
  if ! command -v cargo >/dev/null 2>&1; then
    info "cargo not found — installing Rust first..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &>/dev/null
    source "$HOME/.cargo/env"
    zshrc_append '.cargo/env' '. "$HOME/.cargo/env"'
    ok "Rust (for cargo)"
  else
    source "$HOME/.cargo/env" &>/dev/null || true
  fi
  info "Building yazi-fm + yazi-cli (few minutes)..."
  cargo install --locked yazi-fm yazi-cli &>/dev/null
  ok "Yazi — run: yazi"
  zshrc_append '.cargo/bin' 'export PATH="$HOME/.cargo/bin:$PATH"'

  # ── Node.js ──
  step "Node.js LTS  (via nvm)"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh 2>/dev/null | bash &>/dev/null
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm install --lts &>/dev/null
  nvm use --lts &>/dev/null
  ok "Node.js $(node -v)"
  zshrc_append 'NVM_DIR' \
    '# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'

  # ── Bun ──
  step "Bun"
  curl -fsSL https://bun.sh/install | bash &>/dev/null
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  ok "Bun $(bun --version)"
  zshrc_append 'BUN_INSTALL' \
    '# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"'

  # ── Rust ──
  step "Rust  (via rustup)"
  if ! command -v cargo >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &>/dev/null
    source "$HOME/.cargo/env"
  else
    rustup update stable &>/dev/null
  fi
  ok "$(rustc --version)"
  zshrc_append '.cargo/env' '. "$HOME/.cargo/env"'

  # ── Go ──
  step "Go  (latest stable)"
  GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
  info "Downloading ${GO_VERSION}..."
  curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz
  rm /tmp/go.tar.gz
  export PATH="/usr/local/go/bin:$PATH"
  ok "$(go version)"
  zshrc_append '/usr/local/go/bin' 'export PATH="/usr/local/go/bin:$PATH"'

  # ── VS Code ──
  step "VS Code"
  info "Adding Microsoft repo..."
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor 2>/dev/null |
    sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" |
    sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  apt_q update
  apt_q install code
  ok "VS Code $(code --version | head -1)"

  # ── Sublime Text ──
  step "Sublime Text"
  info "Adding Sublime repo..."
  wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg |
    sudo tee /etc/apt/keyrings/sublimehq-pub.asc >/dev/null
  printf 'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc\n' |
    sudo tee /etc/apt/sources.list.d/sublime-text.sources >/dev/null
  apt_q update
  apt_q install sublime-text
  ok "Sublime Text installed"

  # ── Antigravity ──
  step "Antigravity"
  info "Adding repo..."
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg |
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg &>/dev/null
  echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] \
https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ antigravity-debian main" |
    sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null
  apt_q update
  apt_q install antigravity
  ok "Antigravity installed"

  # ── OpenCode CLI ──
  step "OpenCode CLI  (via bun)"
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
  if ! command -v bun >/dev/null 2>&1; then
    curl -fsSL https://bun.sh/install | bash &>/dev/null
    export PATH="$BUN_INSTALL/bin:$PATH"
    zshrc_append 'BUN_INSTALL' \
      '# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"'
    ok "bun installed"
  fi
  bun install -g opencode-ai &>/dev/null
  ok "OpenCode CLI installed"

  # ── Codex CLI ──
  step "Codex CLI  (via npm)"
  if ! command -v npm >/dev/null 2>&1; then
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh 2>/dev/null | bash &>/dev/null
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts &>/dev/null && nvm use --lts &>/dev/null
    zshrc_append 'NVM_DIR' \
      '# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
    ok "Node.js installed"
  fi
  npm install -g @openai/codex &>/dev/null
  ok "Codex CLI installed"

  # ── Done ──
  echo ""
  echo -e "${GRAY}  ┌─────────────────────────────────────────┐${RESET}"
  echo -e "${GRAY}  │${RESET}                                         ${GRAY}│${RESET}"
  echo -e "${GRAY}  │${RESET}  ${GREEN}${BOLD}✓  Setup complete!${RESET}                     ${GRAY}│${RESET}"
  echo -e "${GRAY}  │${RESET}                                         ${GRAY}│${RESET}"
  echo -e "${GRAY}  └─────────────────────────────────────────┘${RESET}"
  echo ""
  echo -e "  ${ARROW}  Run ${CYAN}exec zsh${RESET} to load the new shell"
  echo -e "  ${ARROW}  Polybar network — check interface with ${CYAN}ip link${RESET}"
  echo ""
}

# ══════════════════════════════════════════════
#  ENTRY POINT
# ══════════════════════════════════════════════
intro

command -v apt >/dev/null 2>&1 || die "apt not found — Ubuntu/Debian/Kali only."

PHASE=$(detect_phase)

if [ "$PHASE" = "1" ]; then
  echo -e "  ${DIAMOND} ${BOLD}${CYAN}Phase 1 detected${RESET}  ${GRAY}— first run${RESET}"
  run_phase1
else
  echo -e "  ${DIAMOND} ${BOLD}${CYAN}Phase 2 detected${RESET}  ${GRAY}— post-reboot run${RESET}"
  run_phase2
fi
