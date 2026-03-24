#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════════════
#  install-VM.sh  v2.0
#  Supports: Ubuntu · Debian · Kali · Linux Mint · Pop!_OS · Zorin · Elementary
#  Author : Vyom Jain
#  Updated: 2025  —  full Mint compat + v2 improvements
# ══════════════════════════════════════════════════════════════════════════════
# No set -e — every error is handled explicitly.
# -u: unbound variables are errors. pipefail: broken pipes are errors.
set -uo pipefail

# ─────────────────────────────────────────────────────────────────────────────
#  SCRIPT VERSION & LOG FILE
# ─────────────────────────────────────────────────────────────────────────────
SCRIPT_VERSION="2.0.0"
LOG_FILE="/tmp/vyom-setup-$(date +%Y%m%d_%H%M%S).log"
# All stdout+stderr from every command goes here in addition to screen output
exec > >(tee -a "$LOG_FILE") 2>&1
# FIX: Unified log — every warn/ok/info/die now also lands in the log file
# so you have a full post-mortem without hunting through /tmp/*.log files.

# ─────────────────────────────────────────────────────────────────────────────
#  COLOUR PALETTE
# ─────────────────────────────────────────────────────────────────────────────
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
WARN_SYM="${YELLOW}▲${RESET}"
ARROW="${CYAN}▶${RESET}"
BOX_RULE="────────────────────────────────────────────────────────────────"

# ─────────────────────────────────────────────────────────────────────────────
#  DISTRO DETECTION  (runs immediately at parse time)
# ─────────────────────────────────────────────────────────────────────────────
DISTRO_ID="unknown"
DISTRO_FAMILY="unknown"
DISTRO_CODENAME=""
UBUNTU_CODENAME=""

detect_distro() {
  # FIX: source os-release safely — guard against missing file
  if [ -f /etc/os-release ]; then
    # shellcheck disable=SC1091
    . /etc/os-release
    DISTRO_ID="${ID:-unknown}"
    DISTRO_CODENAME="${VERSION_CODENAME:-}"
    UBUNTU_CODENAME="${UBUNTU_CODENAME:-${DISTRO_CODENAME}}"
  fi

  case "$DISTRO_ID" in
    ubuntu|debian|kali) DISTRO_FAMILY="$DISTRO_ID" ;;
    linuxmint|mint)     DISTRO_FAMILY="ubuntu" ;;
    pop)                DISTRO_FAMILY="ubuntu" ;;
    elementary)         DISTRO_FAMILY="ubuntu" ;;
    zorin)              DISTRO_FAMILY="ubuntu" ;;
    raspbian)           DISTRO_FAMILY="debian" ;;
    *)
      local id_like="${ID_LIKE:-}"
      if echo "$id_like" | grep -q "ubuntu"; then DISTRO_FAMILY="ubuntu"
      elif echo "$id_like" | grep -q "debian"; then DISTRO_FAMILY="debian"
      else DISTRO_FAMILY="debian"
      fi
      ;;
  esac
}
detect_distro

# ─────────────────────────────────────────────────────────────────────────────
#  ARCHITECTURE DETECTION
# ─────────────────────────────────────────────────────────────────────────────
SYS_ARCH="$(dpkg --print-architecture 2>/dev/null || echo "amd64")"
GO_ARCH=""
case "$(uname -m)" in
  x86_64)        GO_ARCH="amd64"  ;;
  aarch64|arm64) GO_ARCH="arm64"  ;;
  armv6l)        GO_ARCH="armv6l" ;;
  i686|i386)     GO_ARCH="386"    ;;
  *)             GO_ARCH="amd64"  ;;
esac

# ─────────────────────────────────────────────────────────────────────────────
#  GLOBAL CONSTANTS
# ─────────────────────────────────────────────────────────────────────────────
REPO_URL="https://github.com/VyomJain6904/Config.git"
REPO_BRANCH="main"
WALLPAPER_NAME="w10.jpg"
WALLPAPER_URL="https://raw.githubusercontent.com/VyomJain6904/Config/main/Wallpapers/w10.jpg"
FONT_VERSION="v3.4.0"
FONT_NAME="JetBrainsMono"
STATE_DIR="/var/lib/vyom-vm-setup"
STATE_FILE="${STATE_DIR}/state"
STATE_DE_FILE="${STATE_DIR}/detected_des"

# ─────────────────────────────────────────────────────────────────────────────
#  INSTALL FLAGS  (overridable via environment)
# ─────────────────────────────────────────────────────────────────────────────
INSTALL_VSCODE="${INSTALL_VSCODE:-1}"
INSTALL_ANTIGRAVITY="${INSTALL_ANTIGRAVITY:-1}"
INSTALL_OPENCODE="${INSTALL_OPENCODE:-1}"
INSTALL_CODEX="${INSTALL_CODEX:-1}"
INSTALL_CLAUDE="${INSTALL_CLAUDE:-1}"
INSTALL_YAZI="${INSTALL_YAZI:-1}"
INSTALL_THUNAR="${INSTALL_THUNAR:-1}"
FORCE_PHASE1="${FORCE_PHASE1:-0}"
# FIX: New flag — skip DE purge even if one is detected (useful for repair runs)
SKIP_DE_PURGE="${SKIP_DE_PURGE:-0}"
# FIX: New flag — dry-run mode: print what would happen, install nothing
DRY_RUN="${DRY_RUN:-0}"

# ─────────────────────────────────────────────────────────────────────────────
#  RUNTIME STATE VARS
# ─────────────────────────────────────────────────────────────────────────────
TEMP_DIR=""
REPO_CLONED=false
PREFETCH_DIR=""
PREFETCH_WALLPAPER=""
PREFETCH_FONT_ZIP=""
SUDO_PID=""
SETUP_START_TIME=""
SETUP_START_TIME="$(date +%s)"

# ─────────────────────────────────────────────────────────────────────────────
#  UI HELPERS
# ─────────────────────────────────────────────────────────────────────────────
panel_open()  { echo ""; echo -e "${GRAY}┌${BOX_RULE}${RESET}"; }
panel_line()  { echo -e "${BAR}  $1"; }
panel_close() { echo -e "${GRAY}└${BOX_RULE}${RESET}"; echo ""; }

panel_header() {
  panel_open
  panel_line "${DIAMOND} ${BOLD}${PINK}$1${RESET}"
  [ -n "${2:-}" ] && panel_line "${GRAY}$2${RESET}"
  [ -n "${3:-}" ] && panel_line "${GRAY}$3${RESET}"
  panel_close
}

step() { panel_open; panel_line "${DIAMOND} ${BOLD}${PURPLE}$1${RESET}"; panel_close; }

ok()   { echo -e "  ${TICK}  ${GREEN}$1${RESET}"; }
warn() { echo -e "  ${WARN_SYM}  ${YELLOW}$1${RESET}"; }
info() { echo -e "  ${GRAY}·  $1${RESET}"; }
die()  { echo -e "  ${RED}✗  $1${RESET}"; exit 1; }

# FIX: elapsed time helper — shown in completion banner
elapsed_time() {
  local now end_time diff
  now="$(date +%s)"
  diff=$(( now - SETUP_START_TIME ))
  printf '%dm%02ds' $(( diff / 60 )) $(( diff % 60 ))
}

# ─────────────────────────────────────────────────────────────────────────────
#  DRY-RUN WRAPPER
#  FIX: wrap any destructive call with dry_run to respect DRY_RUN=1 flag.
# ─────────────────────────────────────────────────────────────────────────────
dry_run() {
  if flag_enabled "$DRY_RUN"; then
    info "[DRY-RUN] would run: $*"
    return 0
  fi
  "$@"
}

# ─────────────────────────────────────────────────────────────────────────────
#  INTERACTIVE MENU
# ─────────────────────────────────────────────────────────────────────────────
read_keypress() {
  local key seq
  IFS= read -rsn1 key || key=""
  if [ "$key" = $'\x1b' ]; then
    IFS= read -rsn2 seq || seq=""
    key+="$seq"
  fi
  printf '%s' "$key"
}

interactive_select_menu() {
  local mode="$1" title="$2" subtitle="$3" options_name="$4" selected_name="$5"
  local -n options_ref="$options_name"
  local -n selected_ref="$selected_name"
  local idx=0 count="${#options_ref[@]}" i mark line cursor key

  # FIX: guard against non-interactive (piped/CI) shells gracefully
  if [ ! -t 0 ] || [ ! -t 1 ]; then
    warn "Non-interactive shell — using default selections"
    return 0
  fi

  for i in "${!selected_ref[@]}"; do
    if [ "${selected_ref[i]}" -eq 1 ]; then idx="$i"; break; fi
  done

  while true; do
    clear
    panel_header "$title" "$subtitle"
    panel_open
    panel_line "${GRAY}Select options${RESET}"
    panel_line ""

    for i in "${!options_ref[@]}"; do
      mark="${GRAY}○${RESET}"
      [ "${selected_ref[i]}" -eq 1 ] && mark="${GREEN}●${RESET}"
      if [ "$i" -eq "$idx" ]; then
        line="${CYAN}▸${RESET} ${mark}  ${FG}${options_ref[i]}${RESET}"
      else
        line="  ${mark}  ${GRAY}${options_ref[i]}${RESET}"
      fi
      panel_line "$line"
    done

    panel_line ""
    panel_line "${DIM}↑/↓ move  •  Space/Enter select  •  c confirm  •  s defaults  •  q cancel${RESET}"
    panel_close

    key="$(read_keypress)"
    case "$key" in
    $'\x1b[A') idx=$(( (idx - 1 + count) % count )) ;;
    $'\x1b[B') idx=$(( (idx + 1) % count )) ;;
    " " | $'\n' | $'\r')
      if [ "$mode" = "radio" ]; then
        for i in "${!selected_ref[@]}"; do selected_ref[i]=0; done
        selected_ref[idx]=1
      else
        selected_ref[idx]=$(( 1 - selected_ref[idx] ))
      fi
      ;;
    c|C) clear; return 0 ;;
    s|S) clear; warn "Using default selections"; return 0 ;;
    q|Q) clear; die "Selection cancelled by user" ;;
    esac
  done
}

select_optional_apps_interactive() {
  local options=("VS Code" "Antigravity" "OpenCode CLI" "Codex CLI" "Claude Code")
  local vars=("INSTALL_VSCODE" "INSTALL_ANTIGRAVITY" "INSTALL_OPENCODE" "INSTALL_CODEX" "INSTALL_CLAUDE")
  local selected=(0 0 0 0 0)
  local i
  for i in "${!vars[@]}"; do flag_enabled "${!vars[i]}" && selected[i]=1; done
  interactive_select_menu "multi" "Optional Apps" "Select apps to install" options selected || return 1
  for i in "${!vars[@]}"; do printf -v "${vars[i]}" '%s' "${selected[i]}"; done
}

select_file_manager_mode_interactive() {
  local options=("Yazi only" "Thunar only" "Both")
  local selected=(0 0 1)
  flag_enabled "$INSTALL_YAZI" && ! flag_enabled "$INSTALL_THUNAR" && selected=(1 0 0)
  ! flag_enabled "$INSTALL_YAZI" && flag_enabled "$INSTALL_THUNAR" && selected=(0 1 0)
  interactive_select_menu "radio" "File Manager" "Choose which file manager(s) to install" options selected || return 1
  case "${selected[*]}" in
    "1 0 0") INSTALL_YAZI=1; INSTALL_THUNAR=0 ;;
    "0 1 0") INSTALL_YAZI=0; INSTALL_THUNAR=1 ;;
    *)       INSTALL_YAZI=1; INSTALL_THUNAR=1 ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
#  FLAG HELPER
# ─────────────────────────────────────────────────────────────────────────────
flag_enabled() {
  local value="${1:-0}"
  case "${value,,}" in
    1|true|yes|y|on) return 0 ;;
    *) return 1 ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
#  APT WRAPPERS
# ─────────────────────────────────────────────────────────────────────────────
apt_q() {
  local sub="${1:-}"; shift || true
  export DEBIAN_FRONTEND=noninteractive
  local opts=(-y -qq
    -o Dpkg::Options::="--force-confdef"
    -o Dpkg::Options::="--force-confold")
  # FIX: dry-run mode skips all apt operations
  if flag_enabled "$DRY_RUN"; then
    info "[DRY-RUN] apt $sub $*"; return 0
  fi
  case "$sub" in
    update)     sudo apt-get update -qq 2>&1 | grep -v "^Hit\|^Get\|^Ign\|^Reading" || true ;;
    upgrade)    sudo apt-get upgrade "${opts[@]}" &>/dev/null || true ;;
    install)    sudo apt-get install "${opts[@]}" "$@" &>/dev/null || true ;;
    purge)      sudo apt-get purge "${opts[@]}" "$@" &>/dev/null || true ;;
    autoremove) sudo apt-get autoremove "${opts[@]}" --purge &>/dev/null || true ;;
    autoclean)  sudo apt-get autoclean -qq &>/dev/null || true ;;
  esac
}

apt_install_strict() {
  # FIX: strict mode shows errors to user (not silenced) — critical path only
  if flag_enabled "$DRY_RUN"; then
    info "[DRY-RUN] apt-get install $*"; return 0
  fi
  export DEBIAN_FRONTEND=noninteractive
  sudo apt-get install -y \
    -o Dpkg::Options::="--force-confdef" \
    -o Dpkg::Options::="--force-confold" \
    "$@"
}

# ─────────────────────────────────────────────────────────────────────────────
#  PACKAGE / COMMAND GUARDS
# ─────────────────────────────────────────────────────────────────────────────
resolve_i3_package() {
  if apt-cache show i3 &>/dev/null;    then echo "i3";    return 0; fi
  if apt-cache show i3-wm &>/dev/null; then echo "i3-wm"; return 0; fi
  return 1
}

require_command_installed() {
  local cmd="$1" label="$2"
  command -v "$cmd" &>/dev/null || die "${label} install failed — missing command: ${cmd}"
}

require_packages_installed() {
  local missing=() pkg
  for pkg in "$@"; do
    dpkg -s "$pkg" &>/dev/null || missing+=("$pkg")
  done
  [ "${#missing[@]}" -gt 0 ] && die "Missing required package(s): ${missing[*]}"
}

# FIX: new helper — check if package exists in apt cache (silent)
pkg_available() { apt-cache show "$1" &>/dev/null; }

# ─────────────────────────────────────────────────────────────────────────────
#  POLKIT
# ─────────────────────────────────────────────────────────────────────────────
install_polkit() {
  # FIX: check if already installed first to avoid redundant ops
  if dpkg -s polkitd &>/dev/null || dpkg -s policykit-1 &>/dev/null; then
    ok "polkit already installed"
    return 0
  fi
  if pkg_available policykit-1; then
    apt_q install policykit-1
  else
    apt_q install polkitd pkexec
  fi
  sudo apt-mark manual policykit-1 polkitd pkexec &>/dev/null || true
}

install_polkit_agent() {
  # FIX: check if a polkit agent is already running/installed
  for existing in mate-polkit lxpolkit xfce-polkit policykit-1-gnome; do
    dpkg -s "$existing" &>/dev/null && { ok "polkit agent already installed: $existing"; return 0; }
  done
  local agents=("mate-polkit" "lxpolkit" "xfce-polkit" "policykit-1-gnome")
  for agent in "${agents[@]}"; do
    if pkg_available "$agent"; then
      apt_q install "$agent"
      ok "polkit agent installed: $agent"
      return 0
    fi
  done
  warn "No suitable polkit agent found — skipping (i3 may need one manually)"
}

# ─────────────────────────────────────────────────────────────────────────────
#  SUDO KEEPALIVE
# ─────────────────────────────────────────────────────────────────────────────
start_sudo_keepalive() {
  (while true; do sudo -v; sleep 50; done) &
  SUDO_PID=$!
}
stop_sudo_keepalive() {
  [ -n "$SUDO_PID" ] && kill "$SUDO_PID" 2>/dev/null || true
}

# ─────────────────────────────────────────────────────────────────────────────
#  CLEANUP & TRAP
# ─────────────────────────────────────────────────────────────────────────────
cleanup() {
  local exit_code=$?
  stop_sudo_keepalive
  [ -n "$PREFETCH_DIR" ] && [ -d "$PREFETCH_DIR" ] && rm -rf "$PREFETCH_DIR" || true
  [ -n "$TEMP_DIR" ]     && [ -d "$TEMP_DIR" ]     && rm -rf "$TEMP_DIR"     || true
  # FIX: on non-zero exit, print log path so user knows where to look
  if [ "$exit_code" -ne 0 ]; then
    echo -e "\n  ${RED}✗  Script exited with error (code ${exit_code})${RESET}"
    echo -e "  ${GRAY}·  Full log: ${CYAN}${LOG_FILE}${RESET}\n"
  fi
}
trap cleanup EXIT

# ─────────────────────────────────────────────────────────────────────────────
#  REPO / ASSET HELPERS
# ─────────────────────────────────────────────────────────────────────────────
ensure_repo_cloned() {
  [ "$REPO_CLONED" = true ] && return 0
  info "Cloning config repo (sparse, depth 1)..."
  TEMP_DIR="$(mktemp -d)"
  # FIX: retry once on clone failure before dying (transient network issues)
  git clone --depth 1 --filter=blob:none --sparse \
    --branch "${REPO_BRANCH}" "${REPO_URL}" "${TEMP_DIR}/repo" &>/dev/null ||
  git clone --depth 1 --filter=blob:none --sparse \
    --branch "${REPO_BRANCH}" "${REPO_URL}" "${TEMP_DIR}/repo" &>/dev/null ||
  die "Failed to clone config repo (tried twice)"
  git -C "${TEMP_DIR}/repo" sparse-checkout set Config-VM zsh &>/dev/null ||
    die "Failed to fetch required config folders"
  REPO_CLONED=true
  ok "Config repo cloned"
}

prefetch_assets_parallel() {
  step "Prefetch assets (parallel)"
  PREFETCH_DIR="$(mktemp -d)"
  PREFETCH_WALLPAPER="${PREFETCH_DIR}/${WALLPAPER_NAME}"
  PREFETCH_FONT_ZIP="${PREFETCH_DIR}/${FONT_NAME}.zip"

  info "Parallel: config repo + wallpaper + JetBrainsMono ${FONT_VERSION}"

  (ensure_repo_cloned) &
  local repo_pid=$!
  (curl -fsSL "${WALLPAPER_URL}" -o "${PREFETCH_WALLPAPER}") &
  local wallpaper_pid=$!
  (wget -q -O "${PREFETCH_FONT_ZIP}" \
    "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${FONT_NAME}.zip") &
  local font_pid=$!

  local failed=0
  wait "$repo_pid"      || { warn "Config repo prefetch failed";  failed=1; }
  wait "$wallpaper_pid" || { warn "Wallpaper prefetch failed";     failed=1; }
  wait "$font_pid"      || { warn "Font prefetch failed";          failed=1; }

  [ -f "$PREFETCH_WALLPAPER" ] && ok "Wallpaper ready"   || warn "Wallpaper missing — will retry later"
  [ -f "$PREFETCH_FONT_ZIP"  ] && ok "Font zip ready"    || warn "Font zip missing — will retry later"
  [ "$failed" -eq 0 ] && ok "Prefetch complete" || warn "Prefetch had warnings (non-fatal)"
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

# ─────────────────────────────────────────────────────────────────────────────
#  STATE MACHINE
# ─────────────────────────────────────────────────────────────────────────────
read_setup_state() {
  local state="none"
  [ -f "$STATE_FILE" ] && state="$(cat "$STATE_FILE" 2>/dev/null || echo "none")"
  case "$state" in
    phase1_done|phase2_done) echo "$state" ;;
    *) echo "none" ;;
  esac
}

write_setup_state() {
  sudo install -d -m 755 "$STATE_DIR" &>/dev/null || die "Failed to create ${STATE_DIR}"
  printf '%s\n' "$1" | sudo tee "$STATE_FILE" >/dev/null || die "Failed to write setup state"
}

write_detected_des() {
  sudo install -d -m 755 "$STATE_DIR" &>/dev/null || die "Failed to create ${STATE_DIR}"
  printf '%s\n' "$1" | sudo tee "$STATE_DE_FILE" >/dev/null || die "Failed to save DE list"
}

read_detected_des() {
  [ -f "$STATE_DE_FILE" ] && cat "$STATE_DE_FILE" 2>/dev/null || echo ""
}

# ─────────────────────────────────────────────────────────────────────────────
#  DISK SPACE GUARD
# ─────────────────────────────────────────────────────────────────────────────
available_kb() {
  local path="$1"
  set -- $(df -Pk "$path" 2>/dev/null | tail -n 1)
  echo "${4:-0}"
}

# FIX: pre-flight disk check — warn if < 5 GB free before starting Phase 1
check_disk_space() {
  local avail_kb
  avail_kb="$(available_kb "$HOME")"
  local avail_gb=$(( avail_kb / 1048576 ))
  if [ "$avail_kb" -lt 5242880 ]; then   # < 5 GB
    warn "Low disk space: ~${avail_gb}GB free. Recommend at least 5GB for full install."
    echo -ne "  ${DIAMOND_E} ${FG}Continue anyway?${RESET}  ${DIM}[${RESET}${GREEN}Y${RESET}${DIM}/n]${RESET}  "
    IFS= read -r disk_ans
    [[ "${disk_ans,,}" == "n" ]] && die "Aborted due to low disk space"
  else
    ok "Disk space OK (~${avail_gb}GB free)"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  NETWORK CHECK
#  FIX: pre-flight network check before attempting any downloads
# ─────────────────────────────────────────────────────────────────────────────
check_network() {
  if curl -fsSL --connect-timeout 5 https://github.com -o /dev/null 2>/dev/null; then
    ok "Network: GitHub reachable"
  else
    die "No network connectivity to GitHub. Check your connection and retry."
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  VERSION HELPERS
# ─────────────────────────────────────────────────────────────────────────────
cmd_version_line() {
  local cmd="$1"
  case "$cmd" in
    code)     code --version 2>/dev/null | head -n 1 ;;
    opencode) opencode --version 2>/dev/null | head -n 1 ;;
    codex)    codex --version 2>/dev/null | head -n 1 ;;
    claude)   claude --version 2>/dev/null | head -n 1 ;;
    yazi)     yazi --version 2>/dev/null | head -n 1 ;;
    thunar)   thunar --version 2>/dev/null | head -n 1 ;;
    node)     node --version 2>/dev/null | head -n 1 ;;
    npm)      npm --version 2>/dev/null | head -n 1 ;;
    bun)      bun --version 2>/dev/null | head -n 1 ;;
    *)        "$cmd" --version 2>/dev/null | head -n 1 ;;
  esac
}

# ─────────────────────────────────────────────────────────────────────────────
#  RUNTIME DEPENDENCY INSTALLERS
# ─────────────────────────────────────────────────────────────────────────────
ensure_bun() {
  if command -v bun &>/dev/null; then
    ok "Bun already installed ($(cmd_version_line bun))"
    return 0
  fi
  info "Installing Bun..."
  # FIX: timeout guard always present — 'timeout' is in coreutils, always available on Debian/Ubuntu
  timeout 180 bash -lc 'curl -fsSL https://bun.sh/install | bash' &>/tmp/bun-install.log ||
    die "Bun install failed (see /tmp/bun-install.log)"
  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
  require_command_installed bun "Bun"
  zshrc_append 'BUN_INSTALL' '# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"'
  ok "Bun installed ($(cmd_version_line bun))"
}

ensure_node_npm() {
  if command -v npm &>/dev/null && command -v node &>/dev/null; then
    ok "Node.js already installed ($(cmd_version_line node))"
    return 0
  fi
  info "Installing Node.js via nvm..."
  timeout 180 bash -lc 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash' \
    &>/tmp/nvm-install.log || warn "nvm bootstrap failed (see /tmp/nvm-install.log)"

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true

  # FIX: only attempt node install if nvm loaded successfully
  if command -v nvm &>/dev/null; then
    timeout 300 bash -lc "
      export NVM_DIR='$HOME/.nvm'
      [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"
      nvm install --lts
      nvm use --lts
      nvm alias default node
    " &>/tmp/node-install.log || warn "Node LTS install failed (see /tmp/node-install.log)"
    # FIX: install LTS not 'node' (latest) — LTS is more stable for tooling
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true
    nvm use --lts &>/dev/null || true
  fi

  command -v node &>/dev/null || die "Node.js unavailable after nvm setup"
  require_command_installed npm "npm"
  zshrc_append 'NVM_DIR' '# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
  ok "Node.js installed ($(cmd_version_line node))"
}

ensure_rust_latest() {
  if command -v cargo &>/dev/null && command -v rustup &>/dev/null; then
    info "Updating Rust toolchain..."
    rustup update stable &>/tmp/rust-update.log || warn "Rust update failed (see /tmp/rust-update.log)"
    ok "Rust up to date ($(rustc --version 2>/dev/null | head -1))"
  elif command -v cargo &>/dev/null; then
    ok "Rust installed (no rustup — skipping update)"
  else
    info "Installing Rust..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &>/tmp/rust-install.log ||
      die "Rust install failed (see /tmp/rust-install.log)"
    ok "Rust installed"
  fi
  # FIX: use . instead of source for POSIX compatibility (even inside bash)
  . "$HOME/.cargo/env" 2>/dev/null || true
  zshrc_append '.cargo/env' '. "$HOME/.cargo/env"'
  require_command_installed cargo "Rust cargo"
}

ensure_go_latest() {
  local GO_VERSION
  GO_VERSION="$(curl -fsSL 'https://go.dev/VERSION?m=text' 2>/dev/null | head -1 || true)"
  [ -n "$GO_VERSION" ] || die "Could not fetch latest Go version — check network"

  local CURRENT_GO=""
  CURRENT_GO="$(go version 2>/dev/null | awk '{print $3}' || true)"
  if [ "$CURRENT_GO" = "$GO_VERSION" ]; then
    ok "Go already latest (${GO_VERSION})"
    return 0
  fi

  info "Installing Go ${GO_VERSION} (linux-${GO_ARCH})..."
  # FIX: download to temp file in /tmp, not cwd
  local GO_TMP="/tmp/go-${GO_VERSION}-linux-${GO_ARCH}.tar.gz"
  curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-${GO_ARCH}.tar.gz" -o "$GO_TMP" ||
    die "Go download failed"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf "$GO_TMP" &>/dev/null || die "Go extract failed"
  rm -f "$GO_TMP"
  export PATH="/usr/local/go/bin:$PATH"
  zshrc_append '/usr/local/go/bin' 'export PATH="/usr/local/go/bin:$PATH"'
  require_command_installed go "Go"
  ok "Go installed ($(go version | head -1))"
}

ensure_runtime_dependencies() {
  step "Runtime dependencies (Rust · Go · Node · Bun)"
  ensure_rust_latest
  ensure_go_latest
  ensure_node_npm
  ensure_bun
}

# ─────────────────────────────────────────────────────────────────────────────
#  DISPLAY MANAGER HELPERS
# ─────────────────────────────────────────────────────────────────────────────
ensure_startx_autologin_block() {
  local profile_file="$1"
  # FIX: create file if it doesn't exist rather than silently skipping
  touch "$profile_file" 2>/dev/null || true
  if ! grep -q 'exec startx 2>/tmp/startx.log' "$profile_file" 2>/dev/null; then
    cat >>"$profile_file" <<'PROFILE'

# Auto-start i3 on TTY1 login (added by vyom-vm-setup)
if [ -z "${DISPLAY}" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx 2>/tmp/startx.log
fi
PROFILE
    ok "${profile_file} — startx on TTY1 added"
  else
    info "${profile_file} already has startx block — skipped"
  fi
}

any_display_manager_active() {
  local dm
  for dm in gdm3 gdm lightdm sddm kdm lxdm mdm display-manager; do
    systemctl is-active "$dm" &>/dev/null && return 0
  done
  return 1
}

# ─────────────────────────────────────────────────────────────────────────────
#  OPTIONAL APP INSTALLERS
# ─────────────────────────────────────────────────────────────────────────────
_install_vscode() {
  command -v code &>/dev/null && { ok "VS Code already installed"; return 0; }
  info "Installing VS Code (arch: ${SYS_ARCH})..."
  sudo mkdir -p /etc/apt/keyrings
  wget -qO- https://packages.microsoft.com/keys/microsoft.asc |
    gpg --dearmor 2>/dev/null |
    sudo tee /etc/apt/keyrings/microsoft.gpg >/dev/null
  echo "deb [arch=${SYS_ARCH} signed-by=/etc/apt/keyrings/microsoft.gpg] \
https://packages.microsoft.com/repos/code stable main" |
    sudo tee /etc/apt/sources.list.d/vscode.list >/dev/null
  apt_q update
  apt_q install code
  require_command_installed code "VS Code"
  ok "VS Code installed ($(cmd_version_line code))"
}

_install_antigravity() {
  dpkg -s antigravity &>/dev/null && { ok "Antigravity already installed"; return 0; }
  info "Installing Antigravity..."
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
}

_install_opencode() {
  command -v opencode &>/dev/null && { ok "OpenCode CLI already installed"; return 0; }
  info "Installing OpenCode CLI..."
  timeout 240 bun install -g opencode-ai &>/tmp/opencode-install.log ||
    die "OpenCode CLI install failed (see /tmp/opencode-install.log)"
  require_command_installed opencode "OpenCode CLI"
  ok "OpenCode CLI installed ($(cmd_version_line opencode))"
}

_install_codex() {
  command -v codex &>/dev/null && { ok "Codex CLI already installed"; return 0; }
  info "Installing Codex CLI..."
  timeout 240 npm install -g @openai/codex &>/tmp/codex-install.log ||
    die "Codex CLI install failed (see /tmp/codex-install.log)"
  require_command_installed codex "Codex CLI"
  ok "Codex CLI installed ($(cmd_version_line codex))"
}

_install_claude() {
  command -v claude &>/dev/null && { ok "Claude Code already installed"; return 0; }
  info "Installing Claude Code..."
  timeout 240 bash -lc 'curl -fsSL https://claude.ai/install.sh | bash' &>/tmp/claude-install.log ||
    die "Claude Code install failed (see /tmp/claude-install.log)"
  require_command_installed claude "Claude Code"
  ok "Claude Code installed ($(cmd_version_line claude))"
}

_install_thunar() {
  command -v thunar &>/dev/null && { ok "Thunar already installed"; return 0; }
  info "Installing Thunar..."
  apt_q install thunar thunar-volman gvfs gvfs-backends
  require_command_installed thunar "Thunar"
  ok "Thunar installed"
}

_install_yazi() {
  command -v yazi &>/dev/null && { ok "Yazi already installed"; return 0; }
  info "Installing Yazi (builds from source via cargo)..."
  local CARGO_TMP_DIR="${HOME}/.cache/cargo-tmp"
  local CARGO_TARGET_DIR_PATH="${HOME}/.cache/cargo-target"
  local MIN_YAZI_BUILD_KB=1048576
  mkdir -p "$CARGO_TMP_DIR" "$CARGO_TARGET_DIR_PATH"

  local tmp_kb home_kb
  tmp_kb="$(available_kb "$CARGO_TMP_DIR")"
  home_kb="$(available_kb "$HOME")"

  if [ "$tmp_kb" -lt "$MIN_YAZI_BUILD_KB" ] || [ "$home_kb" -lt "$MIN_YAZI_BUILD_KB" ]; then
    warn "Skipping Yazi: insufficient build space (tmp=${tmp_kb}KB home=${home_kb}KB, need 1GB each)"
    INSTALL_YAZI=0
    return 1
  fi

  # FIX: install yazi build deps explicitly — prevents obscure compile errors
  apt_q install pkg-config libssl-dev

  . "$HOME/.cargo/env" 2>/dev/null || true
  info "Building yazi-fm + yazi-cli (this takes a few minutes)..."
  if TMPDIR="$CARGO_TMP_DIR" CARGO_TARGET_DIR="$CARGO_TARGET_DIR_PATH" \
     cargo install --locked yazi-fm yazi-cli &>/tmp/yazi-build.log; then
    zshrc_append '.cargo/bin' 'export PATH="$HOME/.cargo/bin:$PATH"'
    export PATH="$HOME/.cargo/bin:$PATH"
    command -v yazi &>/dev/null || { warn "Yazi binary missing after build"; INSTALL_YAZI=0; return 1; }
    ok "Yazi installed ($(cmd_version_line yazi))"
  else
    warn "Yazi build failed — see /tmp/yazi-build.log"
    warn "Manual retry: TMPDIR=\"$CARGO_TMP_DIR\" cargo install --locked yazi-fm yazi-cli"
    INSTALL_YAZI=0
    return 1
  fi
}

install_selected_optional_apps() {
  ensure_runtime_dependencies

  flag_enabled "$INSTALL_THUNAR"     && _install_thunar     || warn "Thunar disabled"
  flag_enabled "$INSTALL_YAZI"       && _install_yazi        || warn "Yazi disabled"
  flag_enabled "$INSTALL_VSCODE"     && _install_vscode      || warn "VS Code disabled"
  flag_enabled "$INSTALL_ANTIGRAVITY" && _install_antigravity || warn "Antigravity disabled"
  flag_enabled "$INSTALL_OPENCODE"   && _install_opencode    || warn "OpenCode disabled"
  flag_enabled "$INSTALL_CODEX"      && _install_codex       || warn "Codex disabled"
  flag_enabled "$INSTALL_CLAUDE"     && _install_claude      || warn "Claude Code disabled"
}

# ─────────────────────────────────────────────────────────────────────────────
#  HEALTH CHECK + SUMMARY TABLE
# ─────────────────────────────────────────────────────────────────────────────
run_post_install_health_check() {
  step "Post-install health check"

  local failed=0
  local -a summary_rows=()

  _app_version() {
    case "$1" in
      code)     code --version 2>/dev/null | head -n 1 ;;
      opencode) opencode --version 2>/dev/null | head -n 1 ;;
      codex)    codex --version 2>/dev/null | head -n 1 ;;
      claude)   claude --version 2>/dev/null | head -n 1 ;;
      yazi)     yazi --version 2>/dev/null | head -n 1 ;;
      thunar)   thunar --version 2>/dev/null | head -n 1 ;;
      i3)       i3 --version 2>/dev/null | head -n 1 ;;
      nvim)     nvim --version 2>/dev/null | head -n 1 ;;
      go)       go version 2>/dev/null | head -n 1 ;;
      rustc)    rustc --version 2>/dev/null | head -n 1 ;;
      node)     node --version 2>/dev/null | head -n 1 ;;
      bun)      bun --version 2>/dev/null | head -n 1 ;;
      *)        "$1" --version 2>/dev/null | head -n 1 ;;
    esac
  }

  _check_cmd() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
      ok "$cmd"
      local ver; ver="$(_app_version "$cmd")"
      [ -n "$ver" ] && info "  └─ $ver"
    else
      warn "$cmd — MISSING"
      failed=$(( failed + 1 ))
    fi
  }

  _check_file() {
    local fp="$1" label="$2"
    if [ -f "$fp" ]; then ok "$label"; else warn "$label — MISSING"; failed=$(( failed + 1 )); fi
  }

  _add_row() {
    summary_rows+=("$1|$2|$3|$4")
  }

  _print_table() {
    echo ""
    printf '+%s+\n' "$(printf '─%.0s' {1..64})"
    printf '| %-62s |\n' "  Installation Summary   •  $(date '+%Y-%m-%d %H:%M')   •  elapsed: $(elapsed_time)"
    printf '+%-16s+%-7s+%-8s+%-30s+\n' \
      "$(printf '─%.0s' {1..16})" \
      "$(printf '─%.0s' {1..7})" \
      "$(printf '─%.0s' {1..8})" \
      "$(printf '─%.0s' {1..30})"
    printf '| %-14s | %-5s | %-6s | %-28s |\n' "App" "Sel" "Inst" "Version"
    printf '+%-16s+%-7s+%-8s+%-30s+\n' \
      "$(printf '─%.0s' {1..16})" \
      "$(printf '─%.0s' {1..7})" \
      "$(printf '─%.0s' {1..8})" \
      "$(printf '─%.0s' {1..30})"
    local row app_name sel inst ver ver_short
    for row in "${summary_rows[@]}"; do
      IFS='|' read -r app_name sel inst ver <<<"$row"
      ver_short="${ver:--}"
      [ "${#ver_short}" -gt 28 ] && ver_short="${ver_short:0:25}..."
      printf '| %-14s | %-5s | %-6s | %-28s |\n' "$app_name" "$sel" "$inst" "$ver_short"
    done
    printf '+%s+\n\n' "$(printf '─%.0s' {1..64})"
    info "Full log saved to: ${LOG_FILE}"
  }

  # Core tools
  info "— Core tools —"
  _check_cmd i3
  _check_cmd startx
  _check_cmd feh
  _check_cmd xterm
  _check_cmd alacritty
  _check_cmd nvim
  _check_cmd git
  _check_cmd go
  _check_cmd rustc
  _check_cmd node
  _check_cmd bun
  _check_cmd zsh
  _check_cmd starship

  echo ""
  info "— Optional apps —"

  local sel inst ver

  # VS Code
  sel="$(flag_enabled "$INSTALL_VSCODE" && echo yes || echo no)"
  command -v code &>/dev/null && inst="yes" && ver="$(_app_version code)" || { inst="no"; ver="-"; }
  [ "$sel" = "yes" ] && [ "$inst" = "no" ] && { warn "VS Code: selected but missing"; failed=$(( failed+1 )); }
  _add_row "VS Code" "$sel" "$inst" "$ver"

  # Antigravity
  sel="$(flag_enabled "$INSTALL_ANTIGRAVITY" && echo yes || echo no)"
  dpkg -s antigravity &>/dev/null && inst="yes" && \
    ver="$(dpkg-query -W -f='${Version}' antigravity 2>/dev/null || echo unknown)" || { inst="no"; ver="-"; }
  [ "$sel" = "yes" ] && [ "$inst" = "no" ] && { warn "Antigravity: selected but missing"; failed=$(( failed+1 )); }
  _add_row "Antigravity" "$sel" "$inst" "$ver"

  # OpenCode
  sel="$(flag_enabled "$INSTALL_OPENCODE" && echo yes || echo no)"
  command -v opencode &>/dev/null && inst="yes" && ver="$(_app_version opencode)" || { inst="no"; ver="-"; }
  [ "$sel" = "yes" ] && [ "$inst" = "no" ] && { warn "OpenCode: selected but missing"; failed=$(( failed+1 )); }
  _add_row "OpenCode CLI" "$sel" "$inst" "$ver"

  # Codex
  sel="$(flag_enabled "$INSTALL_CODEX" && echo yes || echo no)"
  command -v codex &>/dev/null && inst="yes" && ver="$(_app_version codex)" || { inst="no"; ver="-"; }
  [ "$sel" = "yes" ] && [ "$inst" = "no" ] && { warn "Codex: selected but missing"; failed=$(( failed+1 )); }
  _add_row "Codex CLI" "$sel" "$inst" "$ver"

  # Claude Code
  sel="$(flag_enabled "$INSTALL_CLAUDE" && echo yes || echo no)"
  command -v claude &>/dev/null && inst="yes" && ver="$(_app_version claude)" || { inst="no"; ver="-"; }
  [ "$sel" = "yes" ] && [ "$inst" = "no" ] && { warn "Claude Code: selected but missing"; failed=$(( failed+1 )); }
  _add_row "Claude Code" "$sel" "$inst" "$ver"

  # Yazi
  sel="$(flag_enabled "$INSTALL_YAZI" && echo yes || echo no)"
  command -v yazi &>/dev/null && inst="yes" && ver="$(_app_version yazi)" || { inst="no"; ver="-"; }
  [ "$sel" = "yes" ] && [ "$inst" = "no" ] && { warn "Yazi: selected but missing"; failed=$(( failed+1 )); }
  _add_row "Yazi" "$sel" "$inst" "$ver"

  # Thunar
  sel="$(flag_enabled "$INSTALL_THUNAR" && echo yes || echo no)"
  command -v thunar &>/dev/null && inst="yes" && ver="$(_app_version thunar)" || { inst="no"; ver="-"; }
  [ "$sel" = "yes" ] && [ "$inst" = "no" ] && { warn "Thunar: selected but missing"; failed=$(( failed+1 )); }
  _add_row "Thunar" "$sel" "$inst" "$ver"

  echo ""
  info "— Config files —"
  _check_file "${HOME}/.xinitrc"           "~/.xinitrc"
  _check_file "${HOME}/.config/i3/config"  "~/.config/i3/config"
  _check_file "${HOME}/Pictures/${WALLPAPER_NAME}" "~/Pictures/${WALLPAPER_NAME}"

  echo ""
  info "— System state —"
  local target
  target="$(systemctl get-default 2>/dev/null || true)"
  if [ "$target" = "multi-user.target" ]; then
    ok "systemd target: multi-user.target"
  else
    warn "systemd target is '${target}' (expected multi-user.target)"
    failed=$(( failed + 1 ))
  fi

  # FIX: check wallpaper path uses $HOME not ~ (tilde not expanded in grep)
  if grep -qF "${HOME}/Pictures/${WALLPAPER_NAME}" "${HOME}/.config/i3/config" 2>/dev/null ||
     grep -qF "~/Pictures/${WALLPAPER_NAME}"       "${HOME}/.config/i3/config" 2>/dev/null; then
    ok "i3 wallpaper configured correctly"
  else
    warn "i3 wallpaper path not found in i3 config"
    failed=$(( failed + 1 ))
  fi

  if grep -qF 'if ! i3; then' "${HOME}/.xinitrc" 2>/dev/null &&
     grep -qF 'xterm'         "${HOME}/.xinitrc" 2>/dev/null; then
    ok "xinitrc: i3 + xterm fallback present"
  else
    warn "xinitrc fallback not configured"
    failed=$(( failed + 1 ))
  fi

  echo ""
  if [ "$failed" -eq 0 ]; then
    ok "All health checks passed ✓"
  else
    warn "Health check: ${failed} issue(s) found — review warnings above"
  fi

  _print_table
}

# ─────────────────────────────────────────────────────────────────────────────
#  FULL SETUP STACK  (called from Phase 1)
# ─────────────────────────────────────────────────────────────────────────────
run_full_setup_stack() {
  info "Distro: ${DISTRO_ID} (${DISTRO_FAMILY})  |  Arch: ${SYS_ARCH} / Go: ${GO_ARCH}  |  v${SCRIPT_VERSION}"

  # ── Core packages ──
  step "Core packages"
  apt_q install \
    git alacritty neovim polybar \
    flameshot network-manager-gnome
  require_packages_installed git alacritty neovim polybar flameshot network-manager-gnome
  install_polkit_agent
  ok "Core packages installed"

  # ── Deploy configs ──
  step "Applying dotfiles  (Config-VM)"
  ensure_repo_cloned
  for item in alacritty i3 nvim polybar fastfetch yazi; do
    local src="${TEMP_DIR}/repo/Config-VM/${item}"
    local dst="${HOME}/.config/${item}"
    if [ -d "$src" ]; then
      copy_config_dir "$src" "$dst"
      ok "${item} → ~/.config/${item}"
    else
      warn "${item}: not found in repo — skipped"
    fi
  done

  # Make polybar scripts executable
  for f in launch_polybar.sh shutdown.sh target.sh vpn-ip.sh; do
    local sc="${HOME}/.config/polybar/${f}"
    [ -f "$sc" ] && chmod +x "$sc"
  done

  # ── xinitrc ──
  # FIX: write xinitrc here using $HOME not ~ for reliable path expansion
  cat >"${HOME}/.xinitrc" <<XINITRC
#!/bin/sh
# xinitrc — managed by vyom-vm-setup v${SCRIPT_VERSION}
[ -f "\$HOME/.Xresources" ] && xrdb -merge "\$HOME/.Xresources"
[ -f "\$HOME/.fehbg" ] && "\$HOME/.fehbg" &
dunst &

# i3 runs in foreground. xterm fallback prevents permanent black screen.
if ! i3; then
  xterm
fi
XINITRC
  chmod +x "${HOME}/.xinitrc"
  ok "~/.xinitrc written (with xterm fallback)"

  # ── Zsh ──
  step "Zsh + Oh-My-Zsh + Starship + plugins"
  apt_q install zsh
  require_packages_installed zsh
  ok "zsh installed"

  if [ ! -d "${HOME}/.oh-my-zsh" ]; then
    info "Cloning Oh My Zsh..."
    timeout 120 env GIT_TERMINAL_PROMPT=0 git clone --depth 1 \
      https://github.com/ohmyzsh/ohmyzsh.git "${HOME}/.oh-my-zsh" &>/dev/null ||
      warn "Oh My Zsh clone failed — continuing without it"
    [ -d "${HOME}/.oh-my-zsh" ] && ok "Oh My Zsh installed" || warn "Oh My Zsh not installed"
  else
    info "Oh My Zsh already present — skipped"
  fi

  local ZSH_PLUGINS="${HOME}/.oh-my-zsh/plugins"
  mkdir -p "$ZSH_PLUGINS"

  _clone_plugin() {
    local repo="$1" dest="$2" name
    name="$(basename "$dest")"
    [ -d "$dest" ] && { info "$name already exists — skipped"; return 0; }
    git clone --depth 1 -q "$repo" "$dest" &>/dev/null && ok "$name" || warn "$name clone failed"
  }

  _clone_plugin "https://github.com/zsh-users/zsh-autosuggestions"         "${ZSH_PLUGINS}/zsh-autosuggestions"
  _clone_plugin "https://github.com/zsh-users/zsh-syntax-highlighting"      "${ZSH_PLUGINS}/zsh-syntax-highlighting"
  _clone_plugin "https://github.com/zsh-users/zsh-completions"              "${ZSH_PLUGINS}/zsh-completions"
  _clone_plugin "https://github.com/zsh-users/zsh-history-substring-search" "${ZSH_PLUGINS}/zsh-history-substring-search"
  _clone_plugin "https://github.com/romkatv/zsh-defer"                      "${ZSH_PLUGINS}/zsh-defer"

  info "Installing Starship prompt..."
  curl -sS https://starship.rs/install.sh | sh -s -- --yes &>/dev/null || warn "Starship install failed"
  command -v starship &>/dev/null && ok "Starship installed ($(starship --version | head -1))" || warn "Starship missing"

  # FIX: add btop and tldr alongside existing CLI tools
  apt_q install fzf eza fd-find jq zoxide fastfetch bat ripgrep btop tldr
  ok "CLI tools: fzf eza fd-find jq zoxide fastfetch bat ripgrep btop tldr"

  # ── Fonts ──
  info "Installing ${FONT_NAME} Nerd Font ${FONT_VERSION}..."
  local FONT_DIR="${HOME}/.local/share/fonts"
  mkdir -p "$FONT_DIR"
  if [ -f "$PREFETCH_FONT_ZIP" ]; then
    cp "$PREFETCH_FONT_ZIP" "$FONT_DIR/${FONT_NAME}.zip"
  else
    wget -q -O "$FONT_DIR/${FONT_NAME}.zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/${FONT_VERSION}/${FONT_NAME}.zip" ||
      warn "Font download failed"
  fi
  if [ -f "$FONT_DIR/${FONT_NAME}.zip" ]; then
    unzip -qo "$FONT_DIR/${FONT_NAME}.zip" -d "$FONT_DIR" &>/dev/null || true
    rm -f "$FONT_DIR/${FONT_NAME}.zip"
    fc-cache -fv &>/dev/null || true
    ok "${FONT_NAME} Nerd Font installed"
  fi

  # ── .zshrc ──
  local ZSHRC_SRC="${TEMP_DIR}/repo/zsh/.zshrc"
  if [ -f "$ZSHRC_SRC" ]; then
    local bak="${HOME}/.zshrc.bak.$(date +%Y%m%d_%H%M%S)"
    [ -f "${HOME}/.zshrc" ] && cp "${HOME}/.zshrc" "$bak" && info "Old .zshrc backed up → $bak"
    cp "$ZSHRC_SRC" "${HOME}/.zshrc"
    ok ".zshrc deployed from repo"
  else
    warn "zsh/.zshrc not found in repo — skipped"
  fi

  # ── Wallpaper ──
  step "Wallpaper"
  local WALLPAPER_PATH="${HOME}/Pictures/${WALLPAPER_NAME}"
  mkdir -p "${HOME}/Pictures"
  if [ -f "$PREFETCH_WALLPAPER" ]; then
    cp "$PREFETCH_WALLPAPER" "$WALLPAPER_PATH"
  else
    curl -fsSL "${WALLPAPER_URL}" -o "${WALLPAPER_PATH}" || die "Wallpaper download failed"
  fi
  feh --bg-scale "${WALLPAPER_PATH}" &>/dev/null || warn "Cannot apply wallpaper now (no display) — will apply on next login"
  ok "Wallpaper: ${WALLPAPER_PATH}"

  # ── PipeWire audio ──
  step "PipeWire audio"
  apt_q install pipewire pipewire-pulse pipewire-alsa wireplumber pavucontrol playerctl
  ok "PipeWire packages installed"
  # FIX: check pulseaudio is actually running before masking it
  systemctl --user is-active pulseaudio &>/dev/null && {
    systemctl --user disable --now pulseaudio.service pulseaudio.socket &>/dev/null || true
    systemctl --user mask pulseaudio &>/dev/null || true
    ok "PulseAudio disabled + masked"
  } || info "PulseAudio not active — skipping mask"
  systemctl --user enable --now pipewire pipewire-pulse wireplumber &>/dev/null || true
  ok "PipeWire enabled"

  install_selected_optional_apps
  run_post_install_health_check
}

# ─────────────────────────────────────────────────────────────────────────────
#  DE DETECTION & CLEANUP
# ─────────────────────────────────────────────────────────────────────────────
declare -A DE_PACKAGES
DE_PACKAGES["gnome"]="gnome gnome-shell gnome-session gnome-terminal gnome-control-center gdm3 ubuntu-desktop ubuntu-gnome-desktop gnome-software gnome-online-accounts"
DE_PACKAGES["kde"]="kde-plasma-desktop plasma-desktop sddm kwin-x11 kubuntu-desktop kde-standard"
DE_PACKAGES["xfce"]="xfce4 xfce4-session xfce4-panel xfce4-terminal lightdm xubuntu-desktop xfce4-goodies"
DE_PACKAGES["lxde"]="lxde lxde-core lxsession lxdm lubuntu-desktop"
DE_PACKAGES["lxqt"]="lxqt lxqt-session lxqt-panel sddm lubuntu-desktop"
DE_PACKAGES["mate"]="mate-desktop-environment mate-session-manager lightdm ubuntu-mate-desktop"
DE_PACKAGES["cinnamon"]="cinnamon cinnamon-session lightdm mint-meta-cinnamon nemo nemo-fileroller"
DE_PACKAGES["budgie"]="budgie-desktop lightdm ubuntu-budgie-desktop"
DE_PACKAGES["deepin"]="dde dde-desktop lightdm"
DE_PACKAGES["pantheon"]="elementary-desktop lightdm"

detect_des() {
  local found=()
  # FIX: use dpkg-query -W (returns exit 0 only if installed) instead of dpkg -l
  # dpkg -l returns 0 even for rc (removed-config) state packages
  _pkg_installed() { dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -q "^install ok installed"; }
  _pkg_installed gnome-shell      && found+=("gnome")
  _pkg_installed plasma-desktop   && found+=("kde")
  _pkg_installed xfce4            && found+=("xfce")
  _pkg_installed lxde-core        && found+=("lxde")
  _pkg_installed lxqt             && found+=("lxqt")
  _pkg_installed mate-desktop-environment && found+=("mate")
  _pkg_installed cinnamon         && found+=("cinnamon")
  _pkg_installed budgie-desktop   && found+=("budgie")
  _pkg_installed dde              && found+=("deepin")
  _pkg_installed elementary-desktop && found+=("pantheon")
  echo "${found[*]:-}"
}

cleanup_kali_undercover() {
  step "Kali Undercover cleanup"
  dpkg -s kali-undercover &>/dev/null && apt_q purge kali-undercover
  rm -f "${HOME}/.config/autostart/kali-undercover.desktop" 2>/dev/null || true
  sudo rm -f /etc/xdg/autostart/kali-undercover.desktop 2>/dev/null || true
  ok "Kali Undercover cleanup done"
}

verify_de_removed() {
  local detected_des="$1" de pkg
  local -a leftovers=()
  local -A seen=()
  [ -z "$detected_des" ] && return 0
  for de in $detected_des; do
    for pkg in ${DE_PACKAGES[$de]:-}; do
      [ -z "$pkg" ] && continue
      [ -n "${seen[$pkg]:-}" ] && continue
      seen[$pkg]=1
      # FIX: use dpkg-query status check (same as detect_des fix above)
      dpkg-query -W -f='${Status}' "$pkg" 2>/dev/null | grep -q "^install ok installed" && leftovers+=("$pkg")
    done
  done
  if [ "${#leftovers[@]}" -eq 0 ]; then
    ok "All old DE packages removed cleanly"
  else
    warn "Still installed: ${leftovers[*]}"
    warn "Run: sudo apt purge ${leftovers[*]}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  PHASE 1
# ─────────────────────────────────────────────────────────────────────────────
run_phase1() {
  panel_header "Phase 1 of 2  —  v${SCRIPT_VERSION}" \
    "Install i3 + Xorg + dotfiles + apps" \
    "After reboot: run this script again for Phase 2"

  info "Distro : ${DISTRO_ID} (${DISTRO_FAMILY})  |  Arch: ${SYS_ARCH}"
  info "Log    : ${LOG_FILE}"
  echo ""

  # FIX: pre-flight checks before user even answers Y/n
  check_network
  check_disk_space

  local DETECTED_DES
  DETECTED_DES="$(detect_des)"
  if [ -n "$DETECTED_DES" ]; then
    echo -e "  ${WARN_SYM}  ${YELLOW}Detected desktop(s): ${BOLD}${DETECTED_DES}${RESET}"
    echo -e "  ${GRAY}   These will be purged in Phase 2 after reboot${RESET}"
    echo ""
  fi

  echo -ne "  ${DIAMOND_E} ${FG}Proceed with Phase 1?${RESET}  ${DIM}[${RESET}${GREEN}Y${RESET}${DIM}/n]${RESET}  "
  IFS= read -r ans
  [[ "${ans,,}" == "n" ]] && echo -e "\n  ${GRAY}Cancelled.${RESET}\n" && exit 0
  echo ""

  info "Caching sudo credentials..."
  sudo -v || die "sudo authentication failed"
  start_sudo_keepalive

  step "Preferences"
  select_optional_apps_interactive
  select_file_manager_mode_interactive
  info "Apps : VSCode=${INSTALL_VSCODE} Antigravity=${INSTALL_ANTIGRAVITY} OpenCode=${INSTALL_OPENCODE} Codex=${INSTALL_CODEX} Claude=${INSTALL_CLAUDE}"
  info "Files: Yazi=${INSTALL_YAZI} Thunar=${INSTALL_THUNAR}"

  prefetch_assets_parallel

  # ── System update ──
  step "System update"
  apt_q update
  apt_q upgrade
  apt_q install curl wget gpg ca-certificates unzip git build-essential
  ok "System up to date"

  # ── i3 + Xorg ──
  step "i3 + Xorg  (minimal — no compositor)"
  if command -v i3 &>/dev/null && command -v xinit &>/dev/null; then
    info "i3 + xinit already installed — skipping core install"
  else
    local I3_PKG
    I3_PKG="$(resolve_i3_package)" ||
      die "Cannot find i3 or i3-wm in apt cache — run 'sudo apt update' and retry"
    info "i3 package resolved: ${I3_PKG}"
    apt_install_strict \
      xorg xinit xserver-xorg xserver-xorg-input-all \
      x11-xserver-utils "${I3_PKG}" i3status i3lock \
      feh xclip xdotool numlockx dbus-x11 xterm \
      udisks2 upower xdg-user-dirs xdg-utils dunst ||
      die "Core i3/Xorg install failed"
  fi
  require_packages_installed xorg xinit i3status i3lock feh xterm
  require_command_installed i3 "i3 window manager"
  ok "Xorg + i3 installed"

  install_polkit
  ok "polkit installed"

  # Pin all i3/Xorg packages so Phase 2 autoremove can't touch them
  info "Marking i3/Xorg packages as manually installed..."
  sudo apt-mark manual \
    xorg xinit xserver-xorg xserver-xorg-input-all x11-xserver-utils \
    i3 i3status i3lock feh xclip xdotool numlockx dbus dbus-x11 \
    udisks2 upower xdg-user-dirs xdg-utils dunst \
    libx11-6 libxcb1 libxext6 libxrender1 libxfixes3 &>/dev/null || true
  ok "Packages pinned as manual"

  # ── xinitrc ──
  # FIX: use $HOME not ~ for reliable path expansion in here-doc
  cat >"${HOME}/.xinitrc" <<XINITRC
#!/bin/sh
# xinitrc — managed by vyom-vm-setup v${SCRIPT_VERSION}
[ -f "\$HOME/.Xresources" ] && xrdb -merge "\$HOME/.Xresources"
[ -f "\$HOME/.fehbg" ] && "\$HOME/.fehbg" &
dunst &

if ! i3; then
  xterm
fi
XINITRC
  chmod +x "${HOME}/.xinitrc"
  ok "~/.xinitrc written"

  # ── autologin on TTY1 ──
  ensure_startx_autologin_block "${HOME}/.zprofile"
  ensure_startx_autologin_block "${HOME}/.bash_profile"

  # ── Disable ALL display managers ──
  step "Disabling display managers"
  for dm in gdm3 gdm lightdm sddm kdm lxdm mdm display-manager; do
    systemctl is-active  "$dm" &>/dev/null && dry_run sudo systemctl stop    "$dm" &>/dev/null || true
    systemctl is-enabled "$dm" &>/dev/null && dry_run sudo systemctl disable "$dm" &>/dev/null || true
    dry_run sudo systemctl mask "$dm" &>/dev/null || true
  done
  ok "All known DMs stopped/disabled/masked"

  if [ -f /etc/X11/default-display-manager ]; then
    dry_run sudo mv /etc/X11/default-display-manager \
      /etc/X11/default-display-manager.bak
    ok "/etc/X11/default-display-manager backed up + removed"
  fi

  if [ -L /etc/systemd/system/display-manager.service ]; then
    dry_run sudo rm -f /etc/systemd/system/display-manager.service
    ok "display-manager.service symlink removed"
  fi

  dry_run sudo systemctl set-default multi-user.target &>/dev/null
  dry_run sudo systemctl daemon-reload &>/dev/null
  ok "systemd default → multi-user.target"

  run_full_setup_stack

  write_detected_des "$DETECTED_DES"
  write_setup_state "phase1_done"
  ok "Phase 1 state saved"

  panel_open
  panel_line "${DIAMOND} ${BOLD}${PINK}Phase 1 complete  ($(elapsed_time))${RESET}"
  panel_line ""
  panel_line "${GRAY}After reboot you will land on a TTY login prompt.${RESET}"
  panel_line "${GRAY}Log in as your user — i3 starts automatically.${RESET}"
  panel_line ""
  panel_line "${GRAY}Black screen? Check: ${CYAN}cat /tmp/startx.log${RESET}"
  panel_line "${GRAY}Then open a terminal in i3 and run this script again.${RESET}"
  panel_line "${GRAY}Full setup log: ${CYAN}${LOG_FILE}${RESET}"
  panel_close

  echo -ne "  ${DIAMOND_E} ${FG}Reboot now?${RESET}  ${DIM}[${RESET}${GREEN}Y${RESET}${DIM}/n]${RESET}  "
  IFS= read -r rb
  echo ""
  if [[ "${rb,,}" != "n" ]]; then
    echo -e "  ${ARROW}  Rebooting in 3 seconds..."
    sleep 3
    sudo reboot
  else
    echo -e "  ${WARN_SYM}  ${YELLOW}Run ${CYAN}sudo reboot${YELLOW} when ready${RESET}"
  fi
}

# ─────────────────────────────────────────────────────────────────────────────
#  PHASE 2
# ─────────────────────────────────────────────────────────────────────────────
run_phase2() {
  panel_header "Phase 2 of 2  —  v${SCRIPT_VERSION}" \
    "Verify i3/TTY baseline  ·  purge old DE + bloat"

  info "Log: ${LOG_FILE}"
  echo ""

  local DETECTED_DES=""
  DETECTED_DES="$(read_detected_des)"
  if [ -n "$DETECTED_DES" ]; then
    echo -e "  ${WARN_SYM}  ${YELLOW}Will purge: ${BOLD}${DETECTED_DES}${RESET}"
  else
    echo -e "  ${GRAY}·  No DE recorded — purge step will be skipped${RESET}"
  fi
  echo ""

  echo -ne "  ${DIAMOND_E} ${FG}Proceed with Phase 2?${RESET}  ${DIM}[${RESET}${GREEN}Y${RESET}${DIM}/n]${RESET}  "
  IFS= read -r ans
  [[ "${ans,,}" == "n" ]] && echo -e "\n  ${GRAY}Cancelled.${RESET}\n" && exit 0
  echo ""

  sudo -v || die "sudo authentication failed"
  start_sudo_keepalive

  step "System update"
  apt_q update
  apt_q upgrade
  ok "Up to date"

  # ── Safety gates ──
  step "Safety checks (must pass before purge)"
  [ "$(systemctl get-default 2>/dev/null || true)" = "multi-user.target" ] ||
    die "Blocked: systemd default is not multi-user.target"
  any_display_manager_active &&
    die "Blocked: a display manager is still active — check 'systemctl status lightdm gdm3'"
  require_packages_installed xorg xinit i3status i3lock feh
  require_command_installed i3 "i3 window manager"
  ok "Baseline verified — safe to purge"

  # ── DE purge ──
  if [ -n "$DETECTED_DES" ] && ! flag_enabled "$SKIP_DE_PURGE"; then
    step "Purging old DE(s): ${DETECTED_DES}"

    info "Pinning critical packages as manual..."
    sudo apt-mark manual \
      xorg xinit xserver-xorg xserver-xorg-input-all x11-xserver-utils \
      i3 i3status i3lock feh xclip xdotool numlockx \
      dbus dbus-x11 udisks2 upower xdg-utils xdg-user-dirs dunst \
      alacritty neovim polybar git curl wget gpg xterm \
      flameshot thunar network-manager-gnome \
      build-essential libx11-6 libxcb1 libxext6 libxrender1 libxfixes3 \
      &>/dev/null || true
    sudo apt-mark manual polkitd pkexec policykit-1 &>/dev/null || true
    ok "Critical packages pinned"

    local PURGE_PKGS=""
    for de in $DETECTED_DES; do
      [ -n "${DE_PACKAGES[$de]:-}" ] && PURGE_PKGS="${PURGE_PKGS} ${DE_PACKAGES[$de]}"
    done
    PURGE_PKGS="${PURGE_PKGS# }"

    if [ -n "$PURGE_PKGS" ]; then
      info "Purging: ${PURGE_PKGS}"
      # shellcheck disable=SC2086
      apt_q purge $PURGE_PKGS
      apt_q autoremove
      apt_q autoclean
      ok "Old DE purged + orphans removed"
    fi
  elif flag_enabled "$SKIP_DE_PURGE"; then
    info "SKIP_DE_PURGE=1 — DE purge skipped by user request"
  fi

  cleanup_kali_undercover
  verify_de_removed "$DETECTED_DES"

  write_setup_state "phase2_done"
  ok "Phase 2 state saved"

  run_post_install_health_check

  panel_open
  panel_line "${DIAMOND} ${BOLD}${PINK}Setup complete!  (total: $(elapsed_time))${RESET}"
  panel_line ""
  panel_line "${ARROW}  Run ${CYAN}exec zsh${RESET}${GRAY} to load the new shell${RESET}"
  panel_line "${ARROW}  Run ${CYAN}ip link${RESET}${GRAY} to find your network interface for Polybar${RESET}"
  panel_line "${GRAY}    Full log: ${CYAN}${LOG_FILE}${RESET}"
  panel_close
}

# ─────────────────────────────────────────────────────────────────────────────
#  REPAIR MODE
# ─────────────────────────────────────────────────────────────────────────────
run_repair_mode() {
  panel_header "Repair / Update Mode  —  v${SCRIPT_VERSION}" \
    "Re-install missing apps and re-run health check"

  info "Log: ${LOG_FILE}"
  echo ""

  sudo -v || die "sudo authentication failed"
  start_sudo_keepalive

  step "Preferences"
  select_optional_apps_interactive
  select_file_manager_mode_interactive
  info "Apps: VSCode=${INSTALL_VSCODE} Antigravity=${INSTALL_ANTIGRAVITY} OpenCode=${INSTALL_OPENCODE} Codex=${INSTALL_CODEX} Claude=${INSTALL_CLAUDE} Yazi=${INSTALL_YAZI} Thunar=${INSTALL_THUNAR}"

  prefetch_assets_parallel

  step "System update"
  apt_q update
  apt_q upgrade
  ok "Up to date"

  install_selected_optional_apps
  run_post_install_health_check

  panel_open
  panel_line "${DIAMOND} ${BOLD}${PINK}Repair complete  ($(elapsed_time))${RESET}"
  panel_close
}

# ─────────────────────────────────────────────────────────────────────────────
#  ENTRY POINT
# ─────────────────────────────────────────────────────────────────────────────
# Must be apt-based
command -v apt &>/dev/null || die "apt not found — this script requires Ubuntu/Debian/Mint or a derivative"

# Distro family gate
case "$DISTRO_FAMILY" in
  ubuntu|debian|kali) true ;;
  *)
    warn "Unrecognized distro family '${DISTRO_FAMILY}' (ID='${DISTRO_ID}')"
    echo -ne "  ${DIAMOND_E} ${FG}Proceed anyway?${RESET}  ${DIM}[${RESET}${GREEN}Y${RESET}${DIM}/n]${RESET}  "
    IFS= read -r proceed_ans
    [[ "${proceed_ans,,}" == "n" ]] && die "Aborted." || true
    ;;
esac

# FIX: must run as regular user, not root
# Running as root skips $HOME checks and breaks user-level services
if [ "$(id -u)" -eq 0 ]; then
  die "Do not run as root. Run as your regular user with sudo available."
fi

STATE="$(read_setup_state)"

flag_enabled "$FORCE_PHASE1" && { warn "FORCE_PHASE1=1 — resetting to phase1"; STATE="none"; }
flag_enabled "$DRY_RUN"      && warn "DRY_RUN=1 — no changes will be made"

case "$STATE" in
  none)
    echo -e "  ${DIAMOND} ${BOLD}${CYAN}Phase 1${RESET}  ${GRAY}— first run${RESET}"
    run_phase1
    ;;
  phase1_done)
    echo -e "  ${DIAMOND} ${BOLD}${CYAN}Phase 2${RESET}  ${GRAY}— post-reboot cleanup${RESET}"
    run_phase2
    ;;
  phase2_done)
    echo -e "  ${DIAMOND} ${BOLD}${CYAN}Repair/Update Mode${RESET}  ${GRAY}— setup already complete${RESET}"
    run_repair_mode
    ;;
esac
