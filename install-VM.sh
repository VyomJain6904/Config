#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════
#  Vyom's VM Setup Installer
#  Target: Ubuntu / Debian based Virtual Machines ONLY
#  Purpose: Lightweight dev + pentesting environment
# ══════════════════════════════════════════════════════════════════

# ─────────────────────────────────────────────
#  Preflight checks
# ─────────────────────────────────────────────
if ! command -v apt >/dev/null 2>&1; then
  echo "Error: apt not found. This installer targets Ubuntu/Debian systems."
  exit 1
fi

if ! command -v whiptail >/dev/null 2>&1; then
  echo "Installing whiptail for interactive menu..."
  sudo apt-get install -y whiptail
fi

# ─────────────────────────────────────────────
#  Config-VM settings
# ─────────────────────────────────────────────
REPO_URL="https://github.com/VyomJain6904/Config.git"
REPO_BRANCH="main"

BASE_PACKAGES=(
  git
  alacritty
  i3
  neovim
  polybar
)

CONFIG_ITEMS=(
  alacritty
  i3
  nvim
  polybar
)

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
#  Interactive selection via whiptail
# ─────────────────────────────────────────────
if [ -n "$DETECTED_DES" ]; then
  DE_LABEL="i3 setup  (detected: ${DETECTED_DES}  → will remove)"
else
  DE_LABEL="i3 setup  (xorg + xinit + i3 as default on TTY)"
fi

CHOICES=$(whiptail --title "Vyom's VM Setup Installer" \
  --checklist "Select components to install:\n(SPACE to toggle, ENTER to confirm, ESC to cancel)" \
  34 70 20 \
  "i3_setup" "${DE_LABEL}" ON \
  "base_configs" "Core configs  (alacritty / i3 / nvim / polybar)" ON \
  "zsh_setup" "Zsh  (Oh-My-Zsh + plugins + starship + font)" ON \
  "yazi" "Yazi  (terminal file manager via cargo)" ON \
  "pipewire" "PipeWire audio  (+ WirePlumber + pavucontrol)" ON \
  "nodejs" "Node.js  (latest LTS via nvm)" ON \
  "bun" "Bun  (JS runtime & package manager)" ON \
  "rust" "Rust  (via rustup)" ON \
  "go" "Go  (latest stable)" ON \
  "code" "VS Code" ON \
  "sublime" "Sublime Text" ON \
  "antigravity" "Antigravity" ON \
  "opencode" "OpenCode CLI  (via bun)" ON \
  "codex_cli" "Codex CLI  (via npm)" ON \
  3>&1 1>&2 2>&3)

EXIT_STATUS=$?
if [ $EXIT_STATUS -ne 0 ]; then
  echo "Installation cancelled."
  exit 0
fi

CHOICES="${CHOICES//\"/}"

selected() {
  [[ " $CHOICES " == *" $1 "* ]]
}

# ─────────────────────────────────────────────
#  DE removal confirmation
# ─────────────────────────────────────────────
WILL_REMOVE_DE=false
if selected "i3_setup" && [ -n "$DETECTED_DES" ]; then
  if whiptail --title "⚠  DE Removal Warning" --yesno \
    "The following desktop environment(s) were detected:\n\n  ${DETECTED_DES}\n\nThis script will:\n  PHASE 1  (now)\n    • Install i3 + xorg + xinit\n    • Set i3 as default TTY session\n    • Disable display manager\n    • Reboot into i3\n\n  PHASE 2  (automatically after reboot)\n    • Remove detected DE(s) from within i3\n    • Purge orphaned packages\n    • Critical services (pipewire, dbus, udisks2) are protected\n\nThis is IRREVERSIBLE. Proceed?" \
    24 65; then
    WILL_REMOVE_DE=true
  else
    whiptail --title "i3 Setup" --msgbox \
      "DE removal skipped.\ni3 + xorg will still be installed and set as default,\nbut the existing DE will NOT be removed." \
      11 58
  fi
fi

# ─────────────────────────────────────────────
#  Cleanup on exit
# ─────────────────────────────────────────────
temp_dir=""
cleanup() {
  if [ -n "${temp_dir}" ] && [ -d "${temp_dir}" ]; then
    rm -rf "${temp_dir}"
  fi
}
trap cleanup EXIT

copy_config_dir() {
  local source_dir="$1"
  local target_dir="$2"
  mkdir -p "$(dirname "${target_dir}")"
  rm -rf "${target_dir}"
  mkdir -p "${target_dir}"
  cp -a "${source_dir}/." "${target_dir}/"
}

REPO_CLONED=false
ensure_repo_cloned() {
  if [ "$REPO_CLONED" = false ]; then
    echo "▶ Cloning config repo (sparse)..."
    temp_dir="$(mktemp -d)"
    git clone --depth 1 --filter=blob:none --sparse \
      --branch "${REPO_BRANCH}" "${REPO_URL}" "${temp_dir}/repo"
    git -C "${temp_dir}/repo" sparse-checkout set Config-VM
    REPO_CLONED=true
  fi
}

zshrc_append() {
  local marker="$1"
  local block="$2"
  local zshrc="${HOME}/.zshrc"
  if [ -f "$zshrc" ] && ! grep -qF "$marker" "$zshrc"; then
    printf '\n%s\n' "$block" >>"$zshrc"
  fi
}

# ─────────────────────────────────────────────
#  System update
# ─────────────────────────────────────────────
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║        Updating system packages          ║"
echo "╚══════════════════════════════════════════╝"
sudo apt update
sudo apt upgrade -y
sudo apt install -y curl wget gpg ca-certificates unzip git build-essential

# ══════════════════════════════════════════════
#  i3 SETUP
# ══════════════════════════════════════════════
if selected "i3_setup"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║       Installing i3 + Xorg stack         ║"
  echo "╚══════════════════════════════════════════╝"

  # VM-only essentials — no compositor, no gnome deps, no NM
  # Networking is handled by the hypervisor automatically
  sudo apt install -y \
    xorg \
    xinit \
    xserver-xorg \
    xserver-xorg-input-all \
    x11-xserver-utils \
    i3 \
    i3status \
    i3lock \
    dmenu \
    feh \
    arandr \
    xclip \
    xdotool \
    numlockx \
    dbus-x11 \
    policykit-1 \
    udisks2 \
    upower \
    xdg-user-dirs \
    xdg-utils \
    dunst
  echo "  ✓ Xorg + i3 stack installed (no compositor, no gnome deps)"

  # ── ~/.xinitrc — no picom, no nm-applet (VM doesn't need them) ──
  echo "▶ Configuring ~/.xinitrc..."
  cat >"${HOME}/.xinitrc" <<'EOF'
#!/bin/sh
# ~/.xinitrc — VM setup (no compositor, networking handled by hypervisor)

[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources
[ -f ~/.fehbg ] && ~/.fehbg &

# Notification daemon
dunst &

exec i3
EOF
  chmod +x "${HOME}/.xinitrc"
  echo "  ✓ ~/.xinitrc configured (lean, VM-safe)"

  # ── Auto-startx on TTY1 ──
  echo "▶ Configuring auto-startx on TTY1..."
  ZPROFILE="${HOME}/.zprofile"
  if ! grep -q 'startx' "$ZPROFILE" 2>/dev/null; then
    cat >>"$ZPROFILE" <<'EOF'

# Auto-start i3 on TTY1 login
if [ -z "${DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx
fi
EOF
    echo "  ✓ ~/.zprofile updated"
  else
    echo "  ↺ startx already in ~/.zprofile — skipping"
  fi

  # ── Disable display manager ──
  echo "▶ Disabling display manager (if any)..."
  for dm in gdm3 gdm lightdm sddm kdm lxdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
      sudo systemctl disable "$dm" || true
      echo "  ✓ Disabled: ${dm}"
    fi
  done

  # ── TTY as default target ──
  sudo systemctl set-default multi-user.target
  echo "  ✓ Default target → multi-user.target (TTY)"

  # ── Phase 2 DE removal service ──
  if [ "$WILL_REMOVE_DE" = true ]; then
    echo "▶ Registering post-reboot DE removal service..."

    PURGE_PKGS=""
    for de in $DETECTED_DES; do
      if [ -n "${DE_PACKAGES[$de]:-}" ]; then
        PURGE_PKGS="${PURGE_PKGS} ${DE_PACKAGES[$de]}"
      fi
    done
    PURGE_PKGS="${PURGE_PKGS# }"

    sudo tee /usr/local/bin/de-cleanup.sh >/dev/null <<CLEANUP_EOF
#!/usr/bin/env bash
set -euo pipefail
logger -t de-cleanup "Starting DE removal: ${DETECTED_DES}"

# Pin everything critical — autoremove must never touch these
apt-mark manual \
  dbus \
  dbus-x11 \
  policykit-1 \
  udisks2 \
  upower \
  dunst \
  xdg-utils \
  xdg-user-dirs \
  pipewire \
  pipewire-pulse \
  pipewire-alsa \
  wireplumber \
  pavucontrol \
  bluez \
  bluetooth 2>/dev/null || true

apt-get purge -y ${PURGE_PKGS} 2>/dev/null || true
apt-get autoremove -y --purge
apt-get autoclean -y

logger -t de-cleanup "DE removal complete. Disabling service."
systemctl disable de-cleanup.service
rm -f /etc/systemd/system/de-cleanup.service
rm -f /usr/local/bin/de-cleanup.sh
systemctl daemon-reload
CLEANUP_EOF
    sudo chmod +x /usr/local/bin/de-cleanup.sh

    sudo tee /etc/systemd/system/de-cleanup.service >/dev/null <<UNIT_EOF
[Unit]
Description=Post-reboot DE removal (auto-generated by setup.sh)
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
    echo "  ✓ de-cleanup.service registered (runs once on next boot)"
  fi
fi

# ══════════════════════════════════════════════
#  BASE CONFIGS
# ══════════════════════════════════════════════
if selected "base_configs"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║     Installing base packages & configs   ║"
  echo "╚══════════════════════════════════════════╝"
  sudo apt install -y "${BASE_PACKAGES[@]}"

  ensure_repo_cloned

  echo "▶ Copying configs from Config-VM to ~/.config/..."
  for item in "${CONFIG_ITEMS[@]}"; do
    source_path="${temp_dir}/repo/Config-VM/${item}"
    target_path="${HOME}/.config/${item}"
    if [ -d "${source_path}" ]; then
      copy_config_dir "${source_path}" "${target_path}"
      echo "  ✓ ${item}  →  ${target_path}"
    else
      echo "  ⚠ Skipped ${item}: not found in repo at Config-VM/${item}"
    fi
  done
fi

# ══════════════════════════════════════════════
#  ZSH SETUP
# ══════════════════════════════════════════════
if selected "zsh_setup"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║          Setting up Zsh environment      ║"
  echo "╚══════════════════════════════════════════╝"

  sudo apt install -y zsh
  sudo chsh -s "$(which zsh)" "$USER" || true

  echo "▶ Installing Oh My Zsh..."
  if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no \
      sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "  ↺ Already present — skipping"
  fi

  echo "▶ Cloning Zsh plugins..."
  ZSH_PLUGINS="${HOME}/.oh-my-zsh/plugins"

  clone_plugin() {
    local repo="$1" dest="$2"
    if [ ! -d "${dest}" ]; then
      git clone --depth 1 "${repo}" "${dest}"
      echo "  ✓ $(basename "${dest}")"
    else
      echo "  ↺ $(basename "${dest}") already exists — skipping"
    fi
  }

  clone_plugin "https://github.com/zsh-users/zsh-autosuggestions" "${ZSH_PLUGINS}/zsh-autosuggestions"
  clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting" "${ZSH_PLUGINS}/zsh-syntax-highlighting"
  clone_plugin "https://github.com/zsh-users/zsh-completions" "${ZSH_PLUGINS}/zsh-completions"
  clone_plugin "https://github.com/zsh-users/zsh-history-substring-search" "${ZSH_PLUGINS}/zsh-history-substring-search"
  clone_plugin "https://github.com/romkatv/zsh-defer.git" "${ZSH_PLUGINS}/zsh-defer"

  echo "▶ Installing Starship prompt..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes

  echo "▶ Installing Zsh companion tools..."
  sudo apt install -y fzf eza fd-find jq zoxide fastfetch bat ripgrep
  echo "  ✓ fzf  eza  fd-find  jq  zoxide  fastfetch  bat  ripgrep"

  echo "▶ Installing JetBrainsMono Nerd Font v3.4.0..."
  FONT_DIR="${HOME}/.local/share/fonts"
  mkdir -p "${FONT_DIR}"
  FONT_ZIP="${FONT_DIR}/JetBrainsMono.zip"
  wget -q -O "${FONT_ZIP}" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
  unzip -qo "${FONT_ZIP}" -d "${FONT_DIR}"
  rm -f "${FONT_ZIP}"
  fc-cache -fv >/dev/null 2>&1
  echo "  ✓ JetBrainsMono Nerd Font installed"

  echo "▶ Fetching .zshrc from Config-VM/zsh/.zshrc..."
  ensure_repo_cloned

  ZSHRC_SOURCE="${temp_dir}/repo/Config-VM/zsh/.zshrc"
  if [ -f "${ZSHRC_SOURCE}" ]; then
    if [ -f "${HOME}/.zshrc" ]; then
      BACKUP="${HOME}/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
      cp "${HOME}/.zshrc" "${BACKUP}"
      echo "  ℹ Backed up old .zshrc → ${BACKUP}"
    fi
    cp "${ZSHRC_SOURCE}" "${HOME}/.zshrc"
    echo "  ✓ .zshrc replaced from repo"
  else
    echo "  ⚠ Config-VM/zsh/.zshrc not found in repo"
  fi
fi

# ══════════════════════════════════════════════
#  YAZI
# ══════════════════════════════════════════════
if selected "yazi"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║     Installing Yazi (terminal FM)        ║"
  echo "╚══════════════════════════════════════════╝"

  if ! command -v cargo >/dev/null 2>&1; then
    echo "  ⚠ cargo not found — installing Rust first..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
    zshrc_append '.cargo/env' '. "$HOME/.cargo/env"'
  else
    [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
  fi

  echo "▶ Building yazi-fm + yazi-cli (may take a few minutes)..."
  cargo install --locked yazi-fm yazi-cli
  echo "  ✓ Yazi installed"

  zshrc_append '.cargo/bin' 'export PATH="$HOME/.cargo/bin:$PATH"'
fi

# ══════════════════════════════════════════════
#  PIPEWIRE AUDIO
# ══════════════════════════════════════════════
if selected "pipewire"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║        Installing PipeWire Audio         ║"
  echo "╚══════════════════════════════════════════╝"

  sudo apt install -y \
    pipewire \
    pipewire-pulse \
    pipewire-alsa \
    wireplumber \
    pavucontrol \
    playerctl

  # Disable PulseAudio if present
  systemctl --user disable --now pulseaudio.service pulseaudio.socket 2>/dev/null || true
  systemctl --user mask pulseaudio 2>/dev/null || true

  # Enable PipeWire for current user
  systemctl --user enable --now pipewire pipewire-pulse wireplumber
  echo "  ✓ PipeWire + WirePlumber + pavucontrol installed"
  echo "  ✓ PulseAudio masked, PipeWire active"
fi

# ══════════════════════════════════════════════
#  NODE.JS via nvm
# ══════════════════════════════════════════════
if selected "nodejs"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║          Installing Node.js (nvm)        ║"
  echo "╚══════════════════════════════════════════╝"
  curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash
  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
  nvm install --lts
  nvm use --lts
  echo "  ✓ Node.js $(node -v) installed"

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
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║               Installing Bun             ║"
  echo "╚══════════════════════════════════════════╝"
  curl -fsSL https://bun.sh/install | bash
  export BUN_INSTALL="$HOME/.bun"
  export PATH="$BUN_INSTALL/bin:$PATH"
  echo "  ✓ Bun $(bun --version) installed"

  zshrc_append 'BUN_INSTALL' \
    '# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"'
fi

# ══════════════════════════════════════════════
#  RUST
# ══════════════════════════════════════════════
if selected "rust"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║              Installing Rust             ║"
  echo "╚══════════════════════════════════════════╝"
  if ! command -v cargo >/dev/null 2>&1; then
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
  else
    echo "  Rust already installed — running rustup update..."
    rustup update stable
  fi
  echo "  ✓ $(rustc --version) installed"

  zshrc_append '.cargo/env' \
    '# rust / cargo
. "$HOME/.cargo/env"'
fi

# ══════════════════════════════════════════════
#  GO
# ══════════════════════════════════════════════
if selected "go"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║               Installing Go              ║"
  echo "╚══════════════════════════════════════════╝"
  GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" | head -1)
  GO_TARBALL="${GO_VERSION}.linux-amd64.tar.gz"
  echo "  Downloading ${GO_VERSION}..."
  curl -fsSL "https://go.dev/dl/${GO_TARBALL}" -o "/tmp/${GO_TARBALL}"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "/tmp/${GO_TARBALL}"
  rm "/tmp/${GO_TARBALL}"
  export PATH="/usr/local/go/bin:$PATH"
  echo "  ✓ $(go version) installed"

  zshrc_append '/usr/local/go/bin' \
    '# go
export PATH="/usr/local/go/bin:$PATH"'
fi

# ══════════════════════════════════════════════
#  VS CODE
# ══════════════════════════════════════════════
if selected "code"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║              Installing VS Code          ║"
  echo "╚══════════════════════════════════════════╝"
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor |
    sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" |
    sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  sudo apt update
  sudo apt install -y code
  echo "  ✓ VS Code $(code --version | head -1) installed"
fi

# ══════════════════════════════════════════════
#  SUBLIME TEXT
# ══════════════════════════════════════════════
if selected "sublime"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║           Installing Sublime Text        ║"
  echo "╚══════════════════════════════════════════╝"
  wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg |
    sudo tee /etc/apt/keyrings/sublimehq-pub.asc >/dev/null
  printf 'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc\n' |
    sudo tee /etc/apt/sources.list.d/sublime-text.sources >/dev/null
  sudo apt-get update
  sudo apt-get install -y sublime-text
  echo "  ✓ Sublime Text installed"
fi

# ══════════════════════════════════════════════
#  ANTIGRAVITY
# ══════════════════════════════════════════════
if selected "antigravity"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║           Installing Antigravity         ║"
  echo "╚══════════════════════════════════════════╝"
  sudo mkdir -p /etc/apt/keyrings
  curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg |
    sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
  echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] \
https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ \
antigravity-debian main" |
    sudo tee /etc/apt/sources.list.d/antigravity.list >/dev/null
  sudo apt update && sudo apt install -y antigravity
  echo "  ✓ Antigravity installed"
fi

# ══════════════════════════════════════════════
#  OPENCODE CLI
# ══════════════════════════════════════════════
if selected "opencode"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║          Installing OpenCode CLI         ║"
  echo "╚══════════════════════════════════════════╝"
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
  if ! command -v bun >/dev/null 2>&1; then
    echo "  ⚠ bun not found — installing bun first..."
    curl -fsSL https://bun.sh/install | bash
    export PATH="$BUN_INSTALL/bin:$PATH"
    zshrc_append 'BUN_INSTALL' \
      '# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"'
  fi
  bun install -g opencode-ai
  echo "  ✓ OpenCode CLI installed"
fi

# ══════════════════════════════════════════════
#  CODEX CLI
# ══════════════════════════════════════════════
if selected "codex_cli"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║           Installing Codex CLI           ║"
  echo "╚══════════════════════════════════════════╝"
  if ! command -v npm >/dev/null 2>&1; then
    echo "  ⚠ npm not found — installing Node.js via nvm first..."
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
  echo "  ✓ Codex CLI installed"
fi

# ══════════════════════════════════════════════
#  SUMMARY
# ══════════════════════════════════════════════
echo ""
echo "╔══════════════════════════════════════════╗"
echo "║          ✅  Installation Done!          ║"
echo "╚══════════════════════════════════════════╝"
echo ""
echo "Installed components:"
for item in $CHOICES; do
  echo "  ✓  ${item}"
done
echo ""

if selected "i3_setup"; then
  echo "────────────────────────────────────────────"
  echo "  i3 / Xorg notes:"
  echo "  • No compositor (picom) — not needed in VM"
  echo "  • No nm-applet — hypervisor handles networking"
  echo "  • dunst running as notification daemon"
  echo "  • ~/.zprofile: auto-startx on TTY1 login"
  echo "  • systemd default target → multi-user (TTY)"
  if [ -n "$DETECTED_DES" ]; then
    if [ "$WILL_REMOVE_DE" = true ]; then
      echo "  • de-cleanup.service will purge [${DETECTED_DES}]"
      echo "    on next boot, then disable itself permanently"
    else
      echo "  • DE removal SKIPPED (user opted out)"
    fi
  fi
  echo "────────────────────────────────────────────"
  echo ""
fi

if selected "pipewire"; then
  echo "────────────────────────────────────────────"
  echo "  PipeWire notes:"
  echo "  • PulseAudio masked — PipeWire handles audio"
  echo "  • Use pavucontrol for GUI volume control"
  echo "  • playerctl for media player control"
  echo "────────────────────────────────────────────"
  echo ""
fi

if selected "zsh_setup"; then
  echo "────────────────────────────────────────────"
  echo "  Zsh notes:"
  echo "  • Default shell changed to zsh (re-login to apply)"
  echo "  • Old .zshrc backed up before replacement"
  echo "  • JetBrainsMono Nerd Font → ~/.local/share/fonts"
  echo "────────────────────────────────────────────"
  echo ""
fi

if selected "yazi"; then
  echo "────────────────────────────────────────────"
  echo "  Yazi: run with  yazi  |  config: ~/.config/yazi/"
  echo "────────────────────────────────────────────"
  echo ""
fi

# ─────────────────────────────────────────────
#  Reboot prompt
# ─────────────────────────────────────────────
if selected "i3_setup"; then
  echo ""
  REBOOT_MSG="Reboot required to enter i3.\n\n"
  REBOOT_MSG+="  • Boot to TTY (multi-user.target)\n"
  REBOOT_MSG+="  • Login at TTY1 → startx launches i3 automatically"
  if [ "$WILL_REMOVE_DE" = true ]; then
    REBOOT_MSG+="\n  • de-cleanup.service will purge [${DETECTED_DES}]"
    REBOOT_MSG+="\n    on next boot, then disable itself"
  fi
  REBOOT_MSG+="\n\nReboot now?"

  if whiptail --title "Reboot Required" --yesno "$REBOOT_MSG" 18 62; then
    echo "Rebooting in 3 seconds..."
    sleep 3
    sudo reboot
  else
    echo "⚠  Reboot skipped. Run  sudo reboot  when ready."
  fi
else
  echo "⚠  Run  exec zsh  or open a new terminal to apply all changes."
fi
echo ""
