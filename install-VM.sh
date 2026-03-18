#!/usr/bin/env bash
set -euo pipefail

# ══════════════════════════════════════════════════════════════════
#  Vyom's Setup Installer
#  Targets: Ubuntu / Debian based systems
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
#  DE detection — runs before menu so we can
#  show an informative warning if needed
# ─────────────────────────────────────────────

# Map of DE → packages to purge
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

# Detect which DEs are currently installed
detect_installed_des() {
  local found=()
  # Check via dpkg for known DE metapackages / session binaries
  for de in gnome kde xfce lxde lxqt mate cinnamon budgie deepin pantheon; do
    case "$de" in
      gnome)    dpkg -l gnome-shell &>/dev/null && found+=("gnome") || true ;;
      kde)      dpkg -l plasma-desktop &>/dev/null && found+=("kde") || true ;;
      xfce)     dpkg -l xfce4 &>/dev/null && found+=("xfce") || true ;;
      lxde)     dpkg -l lxde &>/dev/null && found+=("lxde") || true ;;
      lxqt)     dpkg -l lxqt &>/dev/null && found+=("lxqt") || true ;;
      mate)     dpkg -l mate-desktop-environment &>/dev/null && found+=("mate") || true ;;
      cinnamon) dpkg -l cinnamon &>/dev/null && found+=("cinnamon") || true ;;
      budgie)   dpkg -l budgie-desktop &>/dev/null && found+=("budgie") || true ;;
      deepin)   dpkg -l dde &>/dev/null && found+=("deepin") || true ;;
      pantheon) dpkg -l elementary-desktop &>/dev/null && found+=("pantheon") || true ;;
    esac
  done
  echo "${found[@]:-}"
}

DETECTED_DES=$(detect_installed_des)

# ─────────────────────────────────────────────
#  Interactive selection via whiptail checklist
# ─────────────────────────────────────────────

# Build the i3/DE item label dynamically
if [ -n "$DETECTED_DES" ]; then
  DE_LABEL="i3 setup  (detected: ${DETECTED_DES}  → will remove)"
else
  DE_LABEL="i3 setup  (xorg + xinit + i3 as default on TTY)"
fi

CHOICES=$(whiptail --title "Vyom's Setup Installer" \
  --checklist "Select components to install:\n(SPACE to toggle, ENTER to confirm, ESC to cancel)" \
  34 70 20 \
  "i3_setup"       "${DE_LABEL}"                                    ON  \
  "base_configs"   "Core configs  (alacritty / i3 / nvim / polybar)" ON \
  "zsh_setup"      "Zsh  (Oh-My-Zsh + plugins + starship + font)"   ON  \
  "yazi"           "Yazi  (terminal file manager via cargo)"         ON  \
  "nodejs"         "Node.js  (latest LTS via nvm)"                  ON  \
  "bun"            "Bun  (JS runtime & package manager)"            ON  \
  "rust"           "Rust  (via rustup)"                             ON  \
  "go"             "Go  (latest stable)"                            ON  \
  "code"           "VS Code"                                        ON  \
  "sublime"        "Sublime Text"                                   ON  \
  "antigravity"    "Antigravity"                                    ON  \
  "opencode"       "OpenCode CLI  (via bun)"                        ON  \
  "codex_cli"      "Codex CLI  (via npm)"                           ON  \
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
#  Safety confirmation for i3 DE migration
#
#  Two-phase strategy (per user preference):
#    Phase 1 — Install i3 + xorg, configure TTY,
#              disable DM, then REBOOT.
#    Phase 2 — After reboot, a one-shot systemd
#              service removes the old DE cleanly
#              while i3 is already the active session.
# ─────────────────────────────────────────────
WILL_REMOVE_DE=false
if selected "i3_setup" && [ -n "$DETECTED_DES" ]; then
  if whiptail --title "⚠  DE Removal Warning" --yesno \
    "The following desktop environment(s) were detected:\n\n  ${DETECTED_DES}\n\nThis script will:\n  PHASE 1  (now)\n    • Install i3 + xorg + xinit\n    • Set i3 as default TTY session\n    • Disable display manager\n    • Reboot into i3\n\n  PHASE 2  (automatically after reboot)\n    • Remove detected DE(s) from within i3\n    • Purge orphaned packages\n\nThis is IRREVERSIBLE. Proceed?" \
    22 65; then
    WILL_REMOVE_DE=true
  else
    whiptail --title "i3 Setup" --msgbox \
      "DE removal skipped.\ni3 + xorg will still be installed and set as default,\nbut the existing DE will NOT be removed." \
      11 58
  fi
fi

# ─────────────────────────────────────────────
#  Cleanup temp dir on exit
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

# ─────────────────────────────────────────────
#  Clone repo once — shared by base_configs
#  and zsh_setup
# ─────────────────────────────────────────────
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

# ─────────────────────────────────────────────
#  Helper: append to .zshrc only if not present
# ─────────────────────────────────────────────
zshrc_append() {
  local marker="$1"
  local block="$2"
  local zshrc="${HOME}/.zshrc"
  if [ -f "$zshrc" ] && ! grep -qF "$marker" "$zshrc"; then
    printf '\n%s\n' "$block" >> "$zshrc"
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
#  i3 SETUP + DE MIGRATION
# ══════════════════════════════════════════════
if selected "i3_setup"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║       Installing i3 + Xorg stack         ║"
  echo "╚══════════════════════════════════════════╝"

  # ── Install Xorg, xinit, i3 and supporting packages ──
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
    dbus-x11
  echo "  ✓ Xorg + i3 stack installed"

  # ── Configure ~/.xinitrc to launch i3 ──
  echo "▶ Configuring ~/.xinitrc..."
  cat > "${HOME}/.xinitrc" << 'EOF'
#!/bin/sh
# ~/.xinitrc — auto-generated by setup.sh

# Load Xresources if present
[ -f ~/.Xresources ] && xrdb -merge ~/.Xresources

# Set wallpaper if feh config exists
[ -f ~/.fehbg ] && ~/.fehbg &

# Start i3
exec i3
EOF
  chmod +x "${HOME}/.xinitrc"
  echo "  ✓ ~/.xinitrc configured"

  # ── Auto-startx from TTY1 on login via .zprofile ──
  echo "▶ Configuring auto-startx on TTY1 login..."
  ZPROFILE="${HOME}/.zprofile"
  if ! grep -q 'startx' "$ZPROFILE" 2>/dev/null; then
    cat >> "$ZPROFILE" << 'EOF'

# Auto-start i3 on TTY1 login
if [ -z "${DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx
fi
EOF
    echo "  ✓ ~/.zprofile updated — i3 will auto-start on TTY1"
  else
    echo "  ↺ startx already in ~/.zprofile — skipping"
  fi

  # ── Disable display manager so TTY is the default ──
  echo "▶ Disabling display manager (if any)..."
  for dm in gdm3 gdm lightdm sddm kdm lxdm; do
    if systemctl is-enabled "$dm" &>/dev/null; then
      sudo systemctl disable "$dm" || true
      echo "  ✓ Disabled display manager: ${dm}"
    fi
  done

  # ── Set default target to multi-user (TTY) not graphical ──
  echo "▶ Setting systemd default target to multi-user (TTY)..."
  sudo systemctl set-default multi-user.target
  echo "  ✓ Default target: multi-user.target (TTY login)"

  # ── Phase 2: register a one-shot systemd service that runs AFTER reboot ──
  # The service fires once on the first boot into i3, removes the old DE,
  # then deletes itself so it never runs again.
  if [ "$WILL_REMOVE_DE" = true ]; then
    echo "▶ Registering post-reboot DE removal service..."

    # Build the purge command from detected DEs
    PURGE_PKGS=""
    for de in $DETECTED_DES; do
      if [ -n "${DE_PACKAGES[$de]:-}" ]; then
        PURGE_PKGS="${PURGE_PKGS} ${DE_PACKAGES[$de]}"
      fi
    done
    PURGE_PKGS="${PURGE_PKGS# }"  # trim leading space

    # Write the cleanup script
    sudo tee /usr/local/bin/de-cleanup.sh > /dev/null << CLEANUP_EOF
#!/usr/bin/env bash
# Auto-generated by setup.sh — runs once after reboot, then self-deletes.
set -euo pipefail
logger -t de-cleanup "Starting DE removal: ${DETECTED_DES}"
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

    # Write the systemd one-shot unit
    sudo tee /etc/systemd/system/de-cleanup.service > /dev/null << UNIT_EOF
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
    echo "  ✓ de-cleanup.service registered"
    echo "    It will auto-run on next boot, remove [${DETECTED_DES}], then delete itself."
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

  echo "▶ Copying configs to ~/.config/..."
  for item in "${CONFIG_ITEMS[@]}"; do
    source_path="${temp_dir}/repo/Config-VM/${item}"
    target_path="${HOME}/.config/${item}"
    if [ -d "${source_path}" ]; then
      copy_config_dir "${source_path}" "${target_path}"
      echo "  ✓ ${item}  →  ${target_path}"
    else
      echo "  ⚠ Skipped ${item}: not found in repo"
    fi
  done
fi

# ══════════════════════════════════════════════
#  ZSH FULL SETUP
# ══════════════════════════════════════════════
if selected "zsh_setup"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║          Setting up Zsh environment      ║"
  echo "╚══════════════════════════════════════════╝"

  # 1. Install zsh
  echo "▶ Installing zsh..."
  sudo apt install -y zsh
  sudo chsh -s "$(which zsh)" "$USER" || true

  # 2. Oh My Zsh (non-interactive)
  echo "▶ Installing Oh My Zsh..."
  if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    RUNZSH=no CHSH=no \
      sh -c "$(curl -fsSL https://raw.github.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
  else
    echo "  Oh My Zsh already present — skipping"
  fi

  # 3. External plugins
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

  clone_plugin "https://github.com/zsh-users/zsh-autosuggestions"           "${ZSH_PLUGINS}/zsh-autosuggestions"
  clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting"       "${ZSH_PLUGINS}/zsh-syntax-highlighting"
  clone_plugin "https://github.com/zsh-users/zsh-completions"               "${ZSH_PLUGINS}/zsh-completions"
  clone_plugin "https://github.com/zsh-users/zsh-history-substring-search"  "${ZSH_PLUGINS}/zsh-history-substring-search"
  clone_plugin "https://github.com/romkatv/zsh-defer.git"                   "${ZSH_PLUGINS}/zsh-defer"

  # 4. Starship prompt
  echo "▶ Installing Starship prompt..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes

  # 5. apt companion tools
  echo "▶ Installing Zsh companion tools..."
  sudo apt install -y fzf eza fd-find jq zoxide fastfetch bat ripgrep
  echo "  ✓ fzf  eza  fd-find  jq  zoxide  fastfetch  bat  ripgrep"

  # 6. JetBrainsMono Nerd Font v3.4.0
  echo "▶ Installing JetBrainsMono Nerd Font..."
  FONT_DIR="${HOME}/.local/share/fonts"
  mkdir -p "${FONT_DIR}"
  FONT_ZIP="${FONT_DIR}/JetBrainsMono.zip"
  wget -q -O "${FONT_ZIP}" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip"
  unzip -qo "${FONT_ZIP}" -d "${FONT_DIR}"
  rm -f "${FONT_ZIP}"
  fc-cache -fv > /dev/null 2>&1
  echo "  ✓ JetBrainsMono Nerd Font installed"

  # 7. .zshrc from repo
  echo "▶ Fetching .zshrc from repo (Config-VM/zsh/.zshrc)..."
  ensure_repo_cloned

  ZSHRC_SOURCE="${temp_dir}/repo/Config-VM/zsh/.zshrc"
  if [ -f "${ZSHRC_SOURCE}" ]; then
    if [ -f "${HOME}/.zshrc" ]; then
      BACKUP="${HOME}/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
      cp "${HOME}/.zshrc" "${BACKUP}"
      echo "  ℹ Backed up old .zshrc  →  ${BACKUP}"
    fi
    cp "${ZSHRC_SOURCE}" "${HOME}/.zshrc"
    echo "  ✓ .zshrc replaced from repo"
  else
    echo "  ⚠ Config-VM/zsh/.zshrc not found in repo"
    echo "    Make sure the file exists at Config-VM/zsh/.zshrc in your GitHub repo."
  fi
fi

# ══════════════════════════════════════════════
#  YAZI — terminal file manager (via cargo)
#  Installs: yazi-fm + yazi-cli
# ══════════════════════════════════════════════
if selected "yazi"; then
  echo ""
  echo "╔══════════════════════════════════════════╗"
  echo "║     Installing Yazi (terminal FM)        ║"
  echo "╚══════════════════════════════════════════╝"

  # Ensure Rust/cargo is available
  if ! command -v cargo >/dev/null 2>&1; then
    echo "  ⚠ cargo not found — installing Rust first..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    # shellcheck source=/dev/null
    source "$HOME/.cargo/env"
    zshrc_append '.cargo/env' '. "$HOME/.cargo/env"'
  else
    [ -f "$HOME/.cargo/env" ] && source "$HOME/.cargo/env"
  fi

  # Build & install yazi-fm and yazi-cli from crates.io
  echo "▶ Building yazi-fm + yazi-cli from source (this may take a few minutes)..."
  cargo install --locked yazi-fm yazi-cli
  echo "  ✓ Yazi installed  (run: yazi)"

  # Persist cargo bin in .zshrc
  zshrc_append '.cargo/bin' 'export PATH="$HOME/.cargo/bin:$PATH"'
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
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc \
    | gpg --dearmor \
    | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
  echo "deb [arch=amd64 signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" \
    | sudo tee /etc/apt/sources.list.d/vscode.list > /dev/null
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
  wget -qO - https://download.sublimetext.com/sublimehq-pub.gpg \
    | sudo tee /etc/apt/keyrings/sublimehq-pub.asc > /dev/null
  printf 'Types: deb\nURIs: https://download.sublimetext.com/\nSuites: apt/stable/\nSigned-By: /etc/apt/keyrings/sublimehq-pub.asc\n' \
    | sudo tee /etc/apt/sources.list.d/sublime-text.sources > /dev/null
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
  curl -fsSL https://us-central1-apt.pkg.dev/doc/repo-signing-key.gpg \
    | sudo gpg --dearmor --yes -o /etc/apt/keyrings/antigravity-repo-key.gpg
  echo "deb [signed-by=/etc/apt/keyrings/antigravity-repo-key.gpg] \
https://us-central1-apt.pkg.dev/projects/antigravity-auto-updater-dev/ \
antigravity-debian main" \
    | sudo tee /etc/apt/sources.list.d/antigravity.list > /dev/null
  sudo apt update && sudo apt install -y antigravity
  echo "  ✓ Antigravity installed"
fi

# ══════════════════════════════════════════════
#  OPENCODE CLI (via bun)
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
#  CODEX CLI (via npm)
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
  echo "  • Xorg + xinit + i3 installed"
  echo "  • ~/.xinitrc configured to launch i3"
  echo "  • ~/.zprofile: auto-startx on TTY1 login"
  echo "  • systemd default target → multi-user (TTY)"
  if [ -n "$DETECTED_DES" ]; then
    if [ "$WILL_REMOVE_DE" = true ]; then
      echo "  • de-cleanup.service registered — will purge"
      echo "    [${DETECTED_DES}] automatically on next boot,"
      echo "    then disable itself permanently"
    else
      echo "  • DE removal SKIPPED (user opted out)"
    fi
  fi
  echo "────────────────────────────────────────────"
  echo ""
fi

if selected "zsh_setup"; then
  echo "────────────────────────────────────────────"
  echo "  Zsh notes:"
  echo "  • Default shell changed to zsh (re-login to apply)"
  echo "  • Old .zshrc backed up before replacement"
  echo "  • JetBrainsMono Nerd Font → ~/.local/share/fonts"
  echo "  • Set font in your Alacritty config"
  echo "────────────────────────────────────────────"
  echo ""
fi

if selected "yazi"; then
  echo "────────────────────────────────────────────"
  echo "  Yazi notes:"
  echo "  • Run with: yazi"
  echo "  • Config dir: ~/.config/yazi/"
  echo "  • ya (yazi-cli) is also available"
  echo "────────────────────────────────────────────"
  echo ""
fi

# ─────────────────────────────────────────────
#  Reboot prompt (only if i3 setup was done)
# ─────────────────────────────────────────────
if selected "i3_setup"; then
  echo ""
  REBOOT_MSG="Reboot is required to enter i3 for the first time.\n\n"
  REBOOT_MSG+="  • systemd will boot to TTY (multi-user.target)\n"
  REBOOT_MSG+="  • Login at TTY1 -> startx launches i3 automatically"
  if [ "$WILL_REMOVE_DE" = true ]; then
    REBOOT_MSG+="\n  • de-cleanup.service will auto-run on boot and\n"
    REBOOT_MSG+="    purge [${DETECTED_DES}], then disable itself"
  fi
  REBOOT_MSG+="\n\nReboot now?"

  if whiptail --title "Reboot Required" --yesno "$REBOOT_MSG" 18 62; then
    echo "Rebooting in 3 seconds..."
    sleep 3
    sudo reboot
  else
    echo "⚠  Reboot skipped. Reboot manually when ready:  sudo reboot"
    if [ "$WILL_REMOVE_DE" = true ]; then
      echo "   de-cleanup.service will still auto-run on next boot."
    fi
  fi
else
  echo "⚠  Run  exec zsh  or open a new terminal to apply all changes."
fi
echo ""
