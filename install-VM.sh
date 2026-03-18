#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════
#  Vyom's VM Setup Installer
#  Target : Ubuntu / Debian based Virtual Machines ONLY
#  Purpose: Lightweight dev + pentesting environment
# ══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────
#  Dracula palette (ANSI true-colour)
# ─────────────────────────────────────────────
R='\033[0m'
BOLD='\033[1m'

C_PURPLE='\033[38;2;189;147;249m'
C_CYAN='\033[38;2;139;233;253m'
C_GREEN='\033[38;2;80;250;123m'
C_YELLOW='\033[38;2;241;250;140m'
C_RED='\033[38;2;255;85;85m'
C_FG='\033[38;2;248;248;242m'
C_COMMENT='\033[38;2;98;114;164m'

BOX_TOP="┌"
BOX_MID="│"
BOX_BOT="└"
DOT_ON="◆"
DOT_OFF="◇"
CHK="✓"
WARN_SYM="⚠"
SKIP_SYM="↺"
STEP_SYM="▶"

# ─────────────────────────────────────────────
#  UI primitives
# ─────────────────────────────────────────────
box_open() { echo -e "${C_PURPLE}${BOX_TOP}${R} ${BOLD}${C_FG}$1${R}"; }
box_line() { echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_FG}$1${R}"; }
box_hint() { echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_COMMENT}$1${R}"; }
box_close() { echo -e "${C_PURPLE}${BOX_BOT}${R}"; }

ok() { echo -e "  ${C_GREEN}${CHK}${R}  ${C_FG}$1${R}"; }
warn() { echo -e "  ${C_YELLOW}${WARN_SYM}${R}  ${C_YELLOW}$1${R}"; }
skip() { echo -e "  ${C_COMMENT}${SKIP_SYM}${R}  ${C_COMMENT}$1${R}"; }
step() { echo -e "\n  ${C_CYAN}${STEP_SYM}${R}  ${C_CYAN}${BOLD}$1${R}"; }

section() {
  echo ""
  echo -e "${C_PURPLE}${BOX_TOP}──────────────────────────────────────────${R}"
  echo -e "${C_PURPLE}${BOX_MID}${R}  ${BOLD}${C_CYAN}$1${R}"
  echo -e "${C_PURPLE}${BOX_BOT}──────────────────────────────────────────${R}"
}

confirm() {
  local prompt="$1" default="${2:-y}"
  if [[ "$default" == "y" ]]; then
    echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_FG}${prompt}${R} ${C_COMMENT}[Y/n]${R}" >&2
  else
    echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_FG}${prompt}${R} ${C_COMMENT}[y/N]${R}" >&2
  fi
  printf "${C_PURPLE}${BOX_MID}${R}  ${C_PURPLE}${DOT_ON}${R} " >&2
  local yn
  read -r yn </dev/tty
  case "${yn,,}" in
  y | yes) return 0 ;;
  n | no) return 1 ;;
  "") [[ "$default" == "y" ]] && return 0 || return 1 ;;
  *) return 1 ;;
  esac
}

# ─────────────────────────────────────────────
#  Preflight
# ─────────────────────────────────────────────
if ! command -v apt >/dev/null 2>&1; then
  echo -e "  ${C_RED}✖${R}  apt not found — Ubuntu/Debian only."
  exit 1
fi

# ─────────────────────────────────────────────
#  Config
# ─────────────────────────────────────────────
REPO_URL="https://github.com/VyomJain6904/Config.git"
REPO_BRANCH="main"
BASE_PACKAGES=(git alacritty i3 neovim polybar)
CONFIG_ITEMS=(alacritty i3 nvim polybar)

# ─────────────────────────────────────────────
#  DE detection
# ─────────────────────────────────────────────
declare -A DE_PACKAGES
DE_PACKAGES["gnome"]="gnome gnome-shell gnome-session gnome-terminal gnome-control-center gdm3 ubuntu-desktop ubuntu-gnome-desktop"
DE_PACKAGES["kde"]="kde-plasma-desktop plasma-desktop sddm kwin-x11 kdm kubuntu-desktop"
DE_PACKAGES["xfce"]="xfce4 xfce4-session xfce4-panel xfce4-terminal lightdm xubuntu-desktop"
DE_PACKAGES["lxde"]="lxde lxde-core lxsession lxdm lubuntu-desktop"
DE_PACKAGES["lxqt"]="lxqt lxqt-session lxqt-panel sddm lubuntu-desktop"
DE_PACKAGES["mate"]="mate-desktop-environment mate-session-manager lightdm ubuntu-mate-desktop"
DE_PACKAGES["cinnamon"]="cinnamon cinnamon-session lightdm"
DE_PACKAGES["budgie"]="budgie-desktop lightdm ubuntu-budgie-desktop"
DE_PACKAGES["deepin"]="dde dde-desktop lightdm"
DE_PACKAGES["pantheon"]="elementary-desktop lightdm"

detect_installed_des() {
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

DETECTED_DES=$(detect_installed_des)

# ─────────────────────────────────────────────
#  Component state
# ─────────────────────────────────────────────
declare -A SEL
SEL[i3_setup]=1
SEL[base_configs]=1
SEL[zsh_setup]=1
SEL[yazi]=1
SEL[pipewire]=1
SEL[nodejs]=1
SEL[bun]=1
SEL[rust]=1
SEL[go]=1
SEL[code]=1
SEL[sublime]=1
SEL[antigravity]=1
SEL[opencode]=1
SEL[codex_cli]=1

declare -A LABELS
LABELS[i3_setup]="i3 setup          xorg + xinit + i3 as default on TTY"
LABELS[base_configs]="Base configs       alacritty / i3 / nvim / polybar"
LABELS[zsh_setup]="Zsh               Oh-My-Zsh + plugins + starship + font"
LABELS[yazi]="Yazi              terminal file manager  (via cargo)"
LABELS[pipewire]="PipeWire          audio + wireplumber + pavucontrol"
LABELS[nodejs]="Node.js           latest LTS via nvm"
LABELS[bun]="Bun               JS runtime & package manager"
LABELS[rust]="Rust              via rustup"
LABELS[go]="Go                latest stable"
LABELS[code]="VS Code"
LABELS[sublime]="Sublime Text"
LABELS[antigravity]="Antigravity"
LABELS[opencode]="OpenCode CLI      via bun"
LABELS[codex_cli]="Codex CLI         via npm"

KEYS=(i3_setup base_configs zsh_setup yazi pipewire nodejs bun rust go code sublime antigravity opencode codex_cli)

selected() { [[ "${SEL[$1]}" -eq 1 ]]; }

# ─────────────────────────────────────────────
#  Header
# ─────────────────────────────────────────────
clear
echo ""
echo -e "  ${BOLD}${C_PURPLE}Vyom's VM Setup${R}  ${C_COMMENT}Ubuntu / Debian  ·  dev + pentesting${R}"
echo -e "  ${C_COMMENT}────────────────────────────────────────────${R}"
echo ""

# ─────────────────────────────────────────────
#  Component selection  (clack / opencode style)
# ─────────────────────────────────────────────
_print_items() {
  local i=1
  for key in "${KEYS[@]}"; do
    if selected "$key"; then
      echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_PURPLE}${DOT_ON}${R}  ${BOLD}${C_FG}$(printf '%2d' $i)${R}  ${C_FG}${LABELS[$key]}${R}"
    else
      echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_COMMENT}${DOT_OFF}${R}  ${C_COMMENT}$(printf '%2d' $i)  ${LABELS[$key]}${R}"
    fi
    ((i++))
  done
  box_hint ""
}

_item_lines=$((${#KEYS[@]} + 1)) # items + trailing hint line

box_open "Select components to install"
box_hint "Number(s) to toggle  ·  a = all  ·  n = none  ·  Enter to confirm"
box_hint ""
_print_items

while true; do
  printf "${C_PURPLE}${BOX_BOT}${R}  ${C_FG}Toggle » ${R}"
  read -r input </dev/tty

  case "${input,,}" in
  "") break ;;
  a) for k in "${KEYS[@]}"; do SEL[$k]=1; done ;;
  n) for k in "${KEYS[@]}"; do SEL[$k]=0; done ;;
  *)
    input="${input//,/ }"
    for num in $input; do
      if [[ "$num" =~ ^[0-9]+$ ]] && ((num >= 1 && num <= ${#KEYS[@]})); then
        key="${KEYS[$((num - 1))]}"
        SEL[$key]=$((1 - SEL[$key]))
      fi
    done
    ;;
  esac

  # Redraw — move cursor up over items + hint + bottom line
  for ((i = 0; i < _item_lines + 1; i++)); do printf '\033[1A\033[2K'; done
  _print_items
done

echo ""

# ─────────────────────────────────────────────
#  Final selection summary
# ─────────────────────────────────────────────
box_open "Installing"
for key in "${KEYS[@]}"; do
  if selected "$key"; then
    echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_PURPLE}${DOT_ON}${R}  ${C_FG}${LABELS[$key]}${R}"
  else
    echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_COMMENT}${DOT_OFF}${R}  ${C_COMMENT}${LABELS[$key]}${R}"
  fi
done
box_close
echo ""

# ─────────────────────────────────────────────
#  DE removal confirmation
# ─────────────────────────────────────────────
WILL_REMOVE_DE=false
if selected "i3_setup" && [ -n "$DETECTED_DES" ]; then
  box_open "Desktop Environment Detected"
  box_line "Found: ${C_YELLOW}${DETECTED_DES}${R}"
  box_hint ""
  box_hint "Phase 1  (now)   install i3 + xorg, disable DM, reboot"
  box_hint "Phase 2  (boot)  auto-purge old DE, critical services protected"
  box_hint ""
  box_hint "This is IRREVERSIBLE."
  if confirm "Remove detected DE(s) after reboot?"; then
    WILL_REMOVE_DE=true
    box_line "${C_GREEN}DE removal scheduled${R}"
  else
    box_line "${C_COMMENT}DE removal skipped — i3 will still be installed${R}"
  fi
  box_close
  echo ""
fi

# ─────────────────────────────────────────────
#  Final go / no-go
# ─────────────────────────────────────────────
box_open "Ready to install"
box_hint "This will modify your system."
if ! confirm "Proceed?"; then
  box_line "${C_COMMENT}Cancelled — nothing was changed${R}"
  box_close
  echo ""
  exit 0
fi
box_close
echo ""

# ─────────────────────────────────────────────
#  Shared helpers
# ─────────────────────────────────────────────
temp_dir=""
cleanup() { [ -n "${temp_dir}" ] && [ -d "${temp_dir}" ] && rm -rf "${temp_dir}"; }
trap cleanup EXIT

copy_config_dir() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "${dst}")"
  rm -rf "${dst}"
  mkdir -p "${dst}"
  cp -a "${src}/." "${dst}/"
}

REPO_CLONED=false
ensure_repo_cloned() {
  if [ "$REPO_CLONED" = false ]; then
    step "Cloning config repo (sparse)"
    temp_dir="$(mktemp -d)"
    git clone --depth 1 --filter=blob:none --sparse \
      --branch "${REPO_BRANCH}" "${REPO_URL}" "${temp_dir}/repo"
    git -C "${temp_dir}/repo" sparse-checkout set Config-VM
    REPO_CLONED=true
    ok "Repo cloned"
  fi
}

zshrc_append() {
  local marker="$1" block="$2" zshrc="${HOME}/.zshrc"
  [ -f "$zshrc" ] && ! grep -qF "$marker" "$zshrc" && printf '\n%s\n' "$block" >>"$zshrc"
}

# ══════════════════════════════════════════════
#  System update
# ══════════════════════════════════════════════
section "System Update"
sudo apt update -qq
sudo apt upgrade -y -qq
sudo apt install -y -qq curl wget gpg ca-certificates unzip git build-essential
ok "System packages updated"

# ══════════════════════════════════════════════
#  i3 SETUP
# ══════════════════════════════════════════════
if selected "i3_setup"; then
  section "i3 + Xorg  (VM lean install)"

  sudo apt install -y \
    xorg xinit xserver-xorg xserver-xorg-input-all \
    x11-xserver-utils i3 i3status i3lock dmenu \
    feh arandr xclip xdotool numlockx dbus-x11 \
    policykit-1 udisks2 upower \
    xdg-user-dirs xdg-utils dunst
  ok "Xorg + i3 stack installed  (no compositor · no gnome deps)"

  step "Configuring ~/.xinitrc"
  cat >"${HOME}/.xinitrc" <<'EOF'
#!/bin/sh
# ~/.xinitrc — VM setup  (no compositor, networking via hypervisor)
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources
[ -f ~/.fehbg ] && ~/.fehbg &
dunst &
exec i3
EOF
  chmod +x "${HOME}/.xinitrc"
  ok "~/.xinitrc configured"

  step "Configuring auto-startx on TTY1"
  ZPROFILE="${HOME}/.zprofile"
  if ! grep -q 'startx' "$ZPROFILE" 2>/dev/null; then
    cat >>"$ZPROFILE" <<'EOF'

# Auto-start i3 on TTY1 login
if [ -z "${DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx
fi
EOF
    ok "~/.zprofile updated"
  else
    skip "startx already in ~/.zprofile"
  fi

  step "Disabling display manager"
  for dm in gdm3 gdm lightdm sddm kdm lxdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
      sudo systemctl disable "$dm" || true
      ok "Disabled: ${dm}"
    fi
  done

  sudo systemctl set-default multi-user.target
  ok "Default target → multi-user.target (TTY)"

  if [ "$WILL_REMOVE_DE" = true ]; then
    step "Registering post-reboot DE removal service"

    PURGE_PKGS=""
    for de in $DETECTED_DES; do
      [ -n "${DE_PACKAGES[$de]:-}" ] && PURGE_PKGS="${PURGE_PKGS} ${DE_PACKAGES[$de]}"
    done
    PURGE_PKGS="${PURGE_PKGS# }"

    sudo tee /usr/local/bin/de-cleanup.sh >/dev/null <<CLEANUP_EOF
#!/usr/bin/env bash
set -euo pipefail
logger -t de-cleanup "Starting DE removal: ${DETECTED_DES}"
apt-mark manual \
  dbus dbus-x11 policykit-1 udisks2 upower dunst \
  xdg-utils xdg-user-dirs \
  pipewire pipewire-pulse pipewire-alsa \
  wireplumber pavucontrol bluez bluetooth 2>/dev/null || true
apt-get purge -y ${PURGE_PKGS} 2>/dev/null || true
apt-get autoremove -y --purge
apt-get autoclean -y
logger -t de-cleanup "Done. Disabling service."
systemctl disable de-cleanup.service
rm -f /etc/systemd/system/de-cleanup.service /usr/local/bin/de-cleanup.sh
systemctl daemon-reload
CLEANUP_EOF
    sudo chmod +x /usr/local/bin/de-cleanup.sh

    sudo tee /etc/systemd/system/de-cleanup.service >/dev/null <<UNIT_EOF
[Unit]
Description=Post-reboot DE removal (auto-generated)
After=network.target
ConditionPathExists=/usr/local/bin/de-cleanup.sh

[Service]
Type=oneshot
ExecStart=/usr/local/bin/de-cleanup.sh
RemainAfterExit=no
StandardOutput=journal
StandardError=journal

[Install]
WantedBy=multi-user.target
UNIT_EOF
    sudo systemctl daemon-reload
    sudo systemctl enable de-cleanup.service
    ok "de-cleanup.service registered — runs once on boot, then deletes itself"
  fi
fi

# ══════════════════════════════════════════════
#  BASE CONFIGS
# ══════════════════════════════════════════════
if selected "base_configs"; then
  section "Base Packages + Configs  (Config-VM)"
  sudo apt install -y "${BASE_PACKAGES[@]}"
  ensure_repo_cloned

  step "Copying configs to ~/.config/"
  for item in "${CONFIG_ITEMS[@]}"; do
    src="${temp_dir}/repo/Config-VM/${item}"
    dst="${HOME}/.config/${item}"
    if [ -d "${src}" ]; then
      copy_config_dir "${src}" "${dst}"
      ok "${item}  →  ${dst}"
    else
      warn "Skipped ${item}: not found in repo at Config-VM/${item}"
    fi
  done
fi

# ══════════════════════════════════════════════
#  ZSH SETUP
# ══════════════════════════════════════════════
if selected "zsh_setup"; then
  section "Zsh Environment"

  sudo apt install -y zsh
  sudo chsh -s "$(which zsh)" "$USER" || true
  ok "zsh installed + set as default shell"

  step "Installing Oh My Zsh"
  if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    ok "Oh My Zsh installed"
  else
    skip "Oh My Zsh already present"
  fi

  step "Cloning plugins"
  ZSH_PLUGINS="${HOME}/.oh-my-zsh/plugins"
  clone_plugin() {
    local repo="$1" dest="$2"
    if [ ! -d "${dest}" ]; then
      git clone --depth 1 "${repo}" "${dest}" -q
      ok "$(basename "${dest}")"
    else
      skip "$(basename "${dest}") already exists"
    fi
  }
  clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "${ZSH_PLUGINS}/zsh-autosuggestions"
  clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "${ZSH_PLUGINS}/zsh-syntax-highlighting"
  clone_plugin "https://github.com/zsh-users/zsh-completions" "${ZSH_PLUGINS}/zsh-completions"
  clone_plugin "https://github.com/zsh-users/zsh-history-substring-search" "${ZSH_PLUGINS}/zsh-history-substring-search"
  clone_plugin "https://github.com/romkatv/zsh-defer.git" "${ZSH_PLUGINS}/zsh-defer"

  step "Installing Starship prompt"
  curl -sS https://starship.rs/install.sh | sh -s -- --yes
  ok "Starship installed"

  step "Installing companion tools"
  sudo apt install -y fzf eza fd-find jq zoxide fastfetch bat ripgrep
  ok "fzf  eza  fd-find  jq  zoxide  fastfetch  bat  ripgrep"

  step "Installing JetBrainsMono Nerd Font v3.4.0"
  FONT_DIR="${HOME}/.local/share/fonts"
  mkdir -p "${FONT_DIR}"
  wget -q -O "${FONT_DIR}/JetBrainsMono.zip" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
  unzip -qo "${FONT_DIR}/JetBrainsMono.zip" -d "${FONT_DIR}"
  rm -f "${FONT_DIR}/JetBrainsMono.zip"
  fc-cache -fv >/dev/null 2>&1
  ok "JetBrainsMono Nerd Font installed"

  step "Fetching .zshrc from Config-VM/zsh/.zshrc"
  ensure_repo_cloned
  ZSHRC_SRC="${temp_dir}/repo/Config-VM/zsh/.zshrc"
  if [ -f "${ZSHRC_SRC}" ]; then
    if [ -f "${HOME}/.zshrc" ]; then
      BACKUP="${HOME}/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
      cp "${HOME}/.zshrc" "${BACKUP}"
      ok "Backed up old .zshrc → ${BACKUP}"
    fi
    cp "${ZSHRC_SRC}" "${HOME}/.zshrc"
    ok ".zshrc replaced from repo"
  else
    warn "Config-VM/zsh/.zshrc not found in repo"
  fi
fi

# ══════════════════════════════════════════════
#  YAZI
# ══════════════════════════════════════════════
if selected "yazi"; then
  section "Yazi  (terminal file manager)"

  if ! command -v cargo >/dev/null 2>&1; then
    warn "cargo not found — installing Rust first"
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    zshrc_append '.cargo/env' '. "$HOME/.cargo/env"'
  else
    [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
  fi

  step "Building yazi-fm + yazi-cli  (may take a few minutes)"
  cargo install --locked yazi-fm yazi-cli
  ok "Yazi installed  — run: yazi"
  zshrc_append '.cargo/bin' 'export PATH="$HOME/.cargo/bin:$PATH"'
fi

# ══════════════════════════════════════════════
#  PIPEWIRE
# ══════════════════════════════════════════════
if selected "pipewire"; then
  section "PipeWire Audio"

  sudo apt install -y \
    pipewire pipewire-pulse pipewire-alsa \
    wireplumber pavucontrol playerctl

  systemctl --user disable --now pulseaudio.service pulseaudio.socket 2>/dev/null || true
  systemctl --user mask pulseaudio 2>/dev/null || true
  systemctl --user enable --now pipewire pipewire-pulse wireplumber

  ok "PipeWire + WirePlumber + pavucontrol installed"
  ok "PulseAudio masked — PipeWire active"
fi

# ══════════════════════════════════════════════
#  NODE.JS
# ══════════════════════════════════════════════
if selected "nodejs"; then
  section "Node.js  (via nvm)"

  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm use --lts
  ok "Node.js $(node -v) installed"

  zshrc_append 'NVM_DIR' \
    '# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"'
fi

# ══════════════════════════════════════════════
#  BUN
# ══════════════════════════════════════════════
if selected "bun"; then
  section "Bun"

  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  ok "Bun $(bun --version) installed"

  zshrc_append 'BUN_INSTALL' \
    '# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"'
fi

# ══════════════════════════════════════════════
#  RUST
# ══════════════════════════════════════════════
if selected "rust"; then
  section "Rust"

  if ! command -v cargo >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
  else
    skip "Rust already installed — running rustup update"
    rustup update stable
  fi
  ok "$(rustc --version)"

  zshrc_append '.cargo/env' \
    '# rust / cargo
. "$HOME/.cargo/env"'
fi

# ══════════════════════════════════════════════
#  GO
# ══════════════════════════════════════════════
if selected "go"; then
  section "Go"

  GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
  GO_TAR="${GO_VERSION}.linux-amd64.tar.gz"
  step "Downloading ${GO_VERSION}"
  curl -fsSL "https://go.dev/dl/${GO_TAR}" -o "/tmp/${GO_TAR}"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "/tmp/${GO_TAR}"
  rm "/tmp/${GO_TAR}"
  export PATH="/usr/local/go/bin:$PATH"
  ok "$(go version)"

  zshrc_append '/usr/local/go/bin' \
    '# go
export PATH="/usr/local/go/bin:$PATH"'
fi

# ══════════════════════════════════════════════
#  VS CODE
# ══════════════════════════════════════════════
if selected "code"; then
  section "VS Code"

  wget -qO- https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" |
    sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  sudo apt update -qq && sudo apt install -y code
  ok "VS Code $(code --version | head -1)"
fi

# ══════════════════════════════════════════════
#  SUBLIME TEXT
# ══════════════════════════════════════════════
if selected "sublime"; then
  section "Sublime Text"

  wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg |
    sudo tee /etc/apt/keyrings/sublimehq-pub.asc >/dev/null
  printf 'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc\n' |
    sudo tee /etc/apt/sources.list.d/sublime-text.sources >/dev/null
  sudo apt-get update -qq && sudo apt-get install -y sublime-text
  ok "Sublime Text installed"
fi

# ══════════════════════════════════════════════
#  ANTIGRAVITY
# ══════════════════════════════════════════════
if selected "antigravity"; then
  section "Antigravity"

  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg |
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
  echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] \
https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ \
antigravity-debian main" |
    sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null
  sudo apt update -qq && sudo apt install -y antigravity
  ok "Antigravity installed"
fi

# ══════════════════════════════════════════════
#  OPENCODE CLI
# ══════════════════════════════════════════════
if selected "opencode"; then
  section "OpenCode CLI"

  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
  if ! command -v bun >/dev/null 2>&1; then
    warn "bun not found — installing bun first"
    curl -fsSL https://bun.sh/install | bash
    export PATH="$BUN_INSTALL/bin:$PATH"
    zshrc_append 'BUN_INSTALL' \
      '# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"'
  fi
  bun install -g opencode-ai
  ok "OpenCode CLI installed"
fi

# ══════════════════════════════════════════════
#  CODEX CLI
# ══════════════════════════════════════════════
if selected "codex_cli"; then
  section "Codex CLI"

  if ! command -v npm >/dev/null 2>&1; then
    warn "npm not found — installing Node.js via nvm first"
    curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
    export NVM_DIR="$HOME/.nvm"
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    nvm install --lts && nvm use --lts
    zshrc_append 'NVM_DIR' \
      '# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
  fi
  npm install -g @openai/codex
  ok "Codex CLI installed"
fi

# ══════════════════════════════════════════════
#  DONE
# ══════════════════════════════════════════════
echo ""
echo -e "${C_PURPLE}${BOX_TOP}──────────────────────────────────────────${R}"
echo -e "${C_PURPLE}${BOX_MID}${R}  ${BOLD}${C_GREEN}  Installation complete${R}"
echo -e "${C_PURPLE}${BOX_MID}${R}"
for key in "${KEYS[@]}"; do
  if selected "$key"; then
    echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_GREEN}${CHK}${R}  ${C_FG}${LABELS[$key]}${R}"
  fi
done
echo -e "${C_PURPLE}${BOX_MID}${R}"
if selected "i3_setup"; then
  echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_COMMENT}i3     no compositor · networking via hypervisor${R}"
  [ "$WILL_REMOVE_DE" = true ] &&
    echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_COMMENT}       de-cleanup.service purges [${DETECTED_DES}] on next boot${R}"
fi
if selected "zsh_setup"; then
  echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_COMMENT}zsh    re-login or run  exec zsh  to apply${R}"
fi
if selected "pipewire"; then
  echo -e "${C_PURPLE}${BOX_MID}${R}  ${C_COMMENT}audio  PulseAudio masked · use pavucontrol for volume${R}"
fi
echo -e "${C_PURPLE}${BOX_BOT}──────────────────────────────────────────${R}"
echo ""

# ─────────────────────────────────────────────
#  Reboot prompt
# ─────────────────────────────────────────────
if selected "i3_setup"; then
  box_open "Reboot required"
  box_hint "TTY login at TTY1  →  startx  →  i3 launches automatically"
  [ "$WILL_REMOVE_DE" = true ] &&
    box_hint "de-cleanup.service purges [${DETECTED_DES}] on first boot, then disables"
  if confirm "Reboot now?"; then
    box_line "${C_CYAN}Rebooting in 3 seconds…${R}"
    box_close
    sleep 3
    sudo reboot
  else
    box_line "${C_COMMENT}Skipped — run  sudo reboot  when ready${R}"
    box_close
  fi
else
  echo -e "  ${C_COMMENT}Run  exec zsh  or open a new terminal to apply all changes.${R}"
fi
echo ""
