#!/usr/bin/env bash
# No set -e — we handle every error explicitly.
# -u catches unbound variables. pipefail catches broken pipes.
set -uo pipefail

# ─────────────────────────────────────────────
# palette
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
BOX_RULE="────────────────────────────────────────────────────────────────"

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
  local options=("VS Code" "Antigravity" "OpenCode CLI" "Codex CLI" "Claude Code")
  local vars=("INSTALL_VSCODE" "INSTALL_ANTIGRAVITY" "INSTALL_OPENCODE" "INSTALL_CODEX" "INSTALL_CLAUDE")
  local selected=(0 0 0 0 0)
  local i

  for i in "${!vars[@]}"; do
    flag_enabled "${!vars[i]}" && selected[i]=1
  done

  interactive_select_menu "multi" "Optional Apps" "Select apps to install in Phase 1" options selected || return 1

  for i in "${!vars[@]}"; do
    printf -v "${vars[i]}" '%s' "${selected[i]}"
  done
}

select_file_manager_mode_interactive() {
  local options=("Yazi only" "Thunar only" "Both")
  local selected=(0 0 1)

  if flag_enabled "$INSTALL_YAZI" && ! flag_enabled "$INSTALL_THUNAR"; then
    selected=(1 0 0)
  elif ! flag_enabled "$INSTALL_YAZI" && flag_enabled "$INSTALL_THUNAR"; then
    selected=(0 1 0)
  fi

  interactive_select_menu "radio" "File Manager" "Choose which file manager(s) to install" options selected || return 1

  case "${selected[*]}" in
  "1 0 0")
    INSTALL_YAZI=1
    INSTALL_THUNAR=0
    ;;
  "0 1 0")
    INSTALL_YAZI=0
    INSTALL_THUNAR=1
    ;;
  *)
    INSTALL_YAZI=1
    INSTALL_THUNAR=1
    ;;
  esac
}

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

  if [ ! -t 0 ] || [ ! -t 1 ]; then
    warn "Non-interactive shell: using default selections"
    return 0
  fi

  for i in "${!selected_ref[@]}"; do
    if [ "${selected_ref[i]}" -eq 1 ]; then
      idx="$i"
      break
    fi
  done

  while true; do
    clear
    panel_header "$title" "$subtitle"
    panel_open
    panel_line "${GRAY}Select options${RESET}"
    panel_line ""

    for i in "${!options_ref[@]}"; do
      if [ "${selected_ref[i]}" -eq 1 ]; then
        mark="${GREEN}●${RESET}"
      else
        mark="${GRAY}○${RESET}"
      fi

      if [ "$i" -eq "$idx" ]; then
        cursor="${CYAN}▸${RESET}"
        line="${cursor} ${mark}  ${FG}${options_ref[i]}${RESET}"
      else
        cursor=" "
        line="${cursor} ${mark}  ${GRAY}${options_ref[i]}${RESET}"
      fi
      panel_line "$line"
    done

    panel_line ""
    panel_line "${DIM}...${RESET}"
    panel_line "${DIM}↑/↓ move • Space/Enter select • c confirm • s defaults • q cancel${RESET}"
    panel_close

    key="$(read_keypress)"
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
      if [ "$mode" = "radio" ]; then
        for i in "${!selected_ref[@]}"; do selected_ref[i]=0; done
        selected_ref[idx]=1
      else
        if [ "${selected_ref[idx]}" -eq 1 ]; then
          selected_ref[idx]=0
        else
          selected_ref[idx]=1
        fi
      fi
      ;;
    c | C)
      clear
      return 0
      ;;
    s | S)
      clear
      warn "Using default selections"
      return 0
      ;;
    q | Q)
      clear
      die "Selection cancelled"
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
INSTALL_OPENCODE="${INSTALL_OPENCODE:-1}"
INSTALL_CODEX="${INSTALL_CODEX:-1}"
INSTALL_CLAUDE="${INSTALL_CLAUDE:-1}"
INSTALL_YAZI="${INSTALL_YAZI:-1}"
INSTALL_THUNAR="${INSTALL_THUNAR:-1}"
FORCE_PHASE1="${FORCE_PHASE1:-0}"
TEMP_DIR=""
REPO_CLONED=false
PREFETCH_DIR=""
PREFETCH_WALLPAPER=""
PREFETCH_FONT_ZIP=""

cleanup() {
  stop_sudo_keepalive
  [ -n "$PREFETCH_DIR" ] && [ -d "$PREFETCH_DIR" ] && rm -rf "$PREFETCH_DIR" || true
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

prefetch_assets_parallel() {
  step "Prefetch assets (parallel)"
  PREFETCH_DIR="$(mktemp -d)"
  PREFETCH_WALLPAPER="${PREFETCH_DIR}/${WALLPAPER_NAME}"
  PREFETCH_FONT_ZIP="${PREFETCH_DIR}/JetBrainsMono.zip"

  info "Starting parallel downloads: config repo, wallpaper, fonts"

  (ensure_repo_cloned) &
  local repo_pid=$!
  (curl -fsSL "${WALLPAPER_URL}" -o "${PREFETCH_WALLPAPER}") &
  local wallpaper_pid=$!
  (wget -q -O "${PREFETCH_FONT_ZIP}" "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip") &
  local font_pid=$!

  local failed=0
  wait "$repo_pid" || {
    warn "Config repo prefetch failed"
    failed=1
  }
  wait "$wallpaper_pid" || {
    warn "Wallpaper prefetch failed"
    failed=1
  }
  wait "$font_pid" || {
    warn "Font prefetch failed"
    failed=1
  }

  [ -f "$PREFETCH_WALLPAPER" ] && ok "Wallpaper prefetched" || warn "Wallpaper prefetch missing"
  [ -f "$PREFETCH_FONT_ZIP" ] && ok "Font zip prefetched" || warn "Font prefetch missing"

  [ "$failed" -eq 0 ] && ok "Parallel prefetch complete" || warn "Prefetch completed with warnings"
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

cmd_version_line() {
  local cmd="$1"
  case "$cmd" in
  code) code --version 2>/dev/null | head -n 1 ;;
  opencode) opencode --version 2>/dev/null | head -n 1 ;;
  codex) codex --version 2>/dev/null | head -n 1 ;;
  claude) claude --version 2>/dev/null | head -n 1 ;;
  yazi) yazi --version 2>/dev/null | head -n 1 ;;
  thunar) thunar --version 2>/dev/null | head -n 1 ;;
  node) node --version 2>/dev/null | head -n 1 ;;
  npm) npm --version 2>/dev/null | head -n 1 ;;
  bun) bun --version 2>/dev/null | head -n 1 ;;
  *) "$cmd" --version 2>/dev/null | head -n 1 ;;
  esac
}

ensure_bun() {
  if command -v bun &>/dev/null; then
    ok "Bun already installed"
    info "bun version: $(cmd_version_line bun)"
    return 0
  fi

  if command -v timeout &>/dev/null; then
    timeout 180 bash -lc 'curl -fsSL https://bun.sh/install | bash' &>/tmp/bun-install.log ||
      die "Bun install timed out/failed (see /tmp/bun-install.log)"
  else
    bash -lc 'curl -fsSL https://bun.sh/install | bash' &>/tmp/bun-install.log ||
      die "Bun install failed (see /tmp/bun-install.log)"
  fi

  export BUN_INSTALL="${BUN_INSTALL:-$HOME/.bun}"
  export PATH="$BUN_INSTALL/bin:$PATH"
  require_command_installed bun "Bun"
  zshrc_append 'BUN_INSTALL' \
    '# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"'
  ok "Bun installed"
  info "bun version: $(cmd_version_line bun)"
}

ensure_node_npm() {
  if command -v npm &>/dev/null && command -v node &>/dev/null; then
    ok "Node.js + npm already installed"
    info "node version: $(cmd_version_line node)"
    info "npm version: $(cmd_version_line npm)"
    return 0
  fi

  if command -v timeout &>/dev/null; then
    timeout 180 bash -lc 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash' &>/tmp/nvm-install.log ||
      warn "nvm bootstrap timed out/failed (see /tmp/nvm-install.log)"
  else
    bash -lc 'curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/HEAD/install.sh | bash' &>/tmp/nvm-install.log ||
      warn "nvm bootstrap failed (see /tmp/nvm-install.log)"
  fi

  export NVM_DIR="$HOME/.nvm"
  [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true

  if command -v nvm &>/dev/null; then
    if command -v timeout &>/dev/null; then
      timeout 300 bash -lc "export NVM_DIR='$HOME/.nvm'; [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"; nvm install node; nvm use node" &>/tmp/node-install.log ||
        warn "Node latest install via nvm timed out/failed (see /tmp/node-install.log)"
    else
      bash -lc "export NVM_DIR='$HOME/.nvm'; [ -s \"\$NVM_DIR/nvm.sh\" ] && . \"\$NVM_DIR/nvm.sh\"; nvm install node; nvm use node" &>/tmp/node-install.log ||
        warn "Node latest install via nvm failed (see /tmp/node-install.log)"
    fi
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh" || true
    nvm use node &>/dev/null || true
  fi

  command -v nvm &>/dev/null || die "nvm not available after bootstrap (see /tmp/nvm-install.log)"

  require_command_installed node "Node.js"
  require_command_installed npm "npm"
  zshrc_append 'NVM_DIR' \
    '# nvm
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"'
  ok "Node.js + npm installed"
  info "node version: $(cmd_version_line node)"
  info "npm version: $(cmd_version_line npm)"
}

ensure_rust_latest() {
  if command -v cargo &>/dev/null && command -v rustup &>/dev/null; then
    rustup update stable &>/tmp/rust-update.log || warn "Rust update failed (see /tmp/rust-update.log)"
  elif command -v cargo &>/dev/null; then
    ok "Rust already installed"
  else
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y &>/tmp/rust-install.log || die "Rust install failed (see /tmp/rust-install.log)"
  fi

  source "$HOME/.cargo/env" &>/dev/null || true
  zshrc_append '.cargo/env' '. "$HOME/.cargo/env"'
  require_command_installed cargo "Rust cargo"
}

ensure_go_latest() {
  local GO_VERSION
  GO_VERSION=$(curl -fsSL "https://go.dev/VERSION?m=text" 2>/dev/null | head -1 || true)
  [ -n "$GO_VERSION" ] || die "Could not fetch latest Go version"

  local CURRENT_GO=""
  CURRENT_GO="$(go version 2>/dev/null | awk '{print $3}' || true)"
  if [ "$CURRENT_GO" = "$GO_VERSION" ]; then
    ok "Go already latest (${GO_VERSION})"
    return 0
  fi

  curl -fsSL "https://go.dev/dl/${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz || die "Go download failed"
  sudo rm -rf /usr/local/go
  sudo tar -C /usr/local -xzf /tmp/go.tar.gz &>/dev/null || die "Go extract failed"
  rm -f /tmp/go.tar.gz
  export PATH="/usr/local/go/bin:$PATH"
  zshrc_append '/usr/local/go/bin' 'export PATH="/usr/local/go/bin:$PATH"'
  require_command_installed go "Go"
}

ensure_runtime_dependencies() {
  ensure_rust_latest
  ensure_go_latest
  ensure_node_npm
  ensure_bun
}

available_kb() {
  local path="$1" line
  line="$(df -Pk "$path" 2>/dev/null | tail -n 1)"
  set -- $line
  echo "${4:-0}"
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
  local -a summary_rows=()

  app_version() {
    local cmd="$1"
    case "$cmd" in
    code) code --version 2>/dev/null | head -n 1 ;;
    opencode) opencode --version 2>/dev/null | head -n 1 ;;
    codex) codex --version 2>/dev/null | head -n 1 ;;
    claude) claude --version 2>/dev/null | head -n 1 ;;
    yazi) yazi --version 2>/dev/null | head -n 1 ;;
    thunar) thunar --version 2>/dev/null | head -n 1 ;;
    i3) i3 --version 2>/dev/null | head -n 1 ;;
    nvim) nvim --version 2>/dev/null | head -n 1 ;;
    *) "$cmd" --version 2>/dev/null | head -n 1 ;;
    esac
  }

  check_cmd() {
    local cmd="$1"
    if command -v "$cmd" &>/dev/null; then
      ok "$cmd available"
      local ver
      ver="$(app_version "$cmd")"
      [ -n "$ver" ] && info "$cmd version: $ver"
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

  add_summary_row() {
    local app_name="$1" selected="$2" installed="$3" version="$4"
    summary_rows+=("${app_name}|${selected}|${installed}|${version}")
  }

  print_summary_table() {
    local row app_name selected installed version formatted version_short

    echo ""
    echo "+---------------------------------------------------------------+"
    echo "| Installation Summary                                          |"
    echo "+----------------+-------+--------+------------------------------+"
    echo "| App            | Sel   | Inst   | Version                      |"
    echo "+----------------+-------+--------+------------------------------+"

    for row in "${summary_rows[@]}"; do
      IFS='|' read -r app_name selected installed version <<<"$row"
      version_short="${version:--}"
      [ "${#version_short}" -gt 28 ] && version_short="${version_short:0:25}..."
      printf '| %-14s | %-5s | %-6s | %-28s |\n' "$app_name" "$selected" "$installed" "$version_short"
    done

    echo "+----------------+-------+--------+------------------------------+"
    echo ""
  }

  check_cmd i3
  check_cmd startx
  check_cmd feh
  check_cmd xterm
  check_cmd alacritty
  check_cmd nvim
  check_cmd git

  local selected installed version

  selected="$(flag_enabled "$INSTALL_VSCODE" && echo yes || echo no)"
  if command -v code &>/dev/null; then
    installed="yes"
    version="$(app_version code)"
  else
    installed="no"
    version="-"
  fi
  [ "$selected" = "yes" ] && [ "$installed" = "no" ] && {
    warn "code missing"
    failed=$((failed + 1))
  }
  add_summary_row "VS Code" "$selected" "$installed" "$version"

  selected="$(flag_enabled "$INSTALL_ANTIGRAVITY" && echo yes || echo no)"
  if dpkg -s antigravity &>/dev/null; then
    installed="yes"
    version="$(dpkg-query -W -f='${Version}' antigravity 2>/dev/null || echo unknown)"
  else
    installed="no"
    version="-"
  fi
  [ "$selected" = "yes" ] && [ "$installed" = "no" ] && {
    warn "antigravity package missing"
    failed=$((failed + 1))
  }
  add_summary_row "Antigravity" "$selected" "$installed" "$version"

  selected="$(flag_enabled "$INSTALL_OPENCODE" && echo yes || echo no)"
  if command -v opencode &>/dev/null; then
    installed="yes"
    version="$(app_version opencode)"
  else
    installed="no"
    version="-"
  fi
  [ "$selected" = "yes" ] && [ "$installed" = "no" ] && {
    warn "opencode missing"
    failed=$((failed + 1))
  }
  add_summary_row "OpenCode CLI" "$selected" "$installed" "$version"

  selected="$(flag_enabled "$INSTALL_CODEX" && echo yes || echo no)"
  if command -v codex &>/dev/null; then
    installed="yes"
    version="$(app_version codex)"
  else
    installed="no"
    version="-"
  fi
  [ "$selected" = "yes" ] && [ "$installed" = "no" ] && {
    warn "codex missing"
    failed=$((failed + 1))
  }
  add_summary_row "Codex CLI" "$selected" "$installed" "$version"

  selected="$(flag_enabled "$INSTALL_CLAUDE" && echo yes || echo no)"
  if command -v claude &>/dev/null; then
    installed="yes"
    version="$(app_version claude)"
  else
    installed="no"
    version="-"
  fi
  [ "$selected" = "yes" ] && [ "$installed" = "no" ] && {
    warn "claude missing"
    failed=$((failed + 1))
  }
  add_summary_row "Claude Code" "$selected" "$installed" "$version"

  selected="$(flag_enabled "$INSTALL_YAZI" && echo yes || echo no)"
  if command -v yazi &>/dev/null; then
    installed="yes"
    version="$(app_version yazi)"
  else
    installed="no"
    version="-"
  fi
  [ "$selected" = "yes" ] && [ "$installed" = "no" ] && {
    warn "yazi missing"
    failed=$((failed + 1))
  }
  add_summary_row "Yazi" "$selected" "$installed" "$version"

  selected="$(flag_enabled "$INSTALL_THUNAR" && echo yes || echo no)"
  if command -v thunar &>/dev/null; then
    installed="yes"
    version="$(app_version thunar)"
  else
    installed="no"
    version="-"
  fi
  [ "$selected" = "yes" ] && [ "$installed" = "no" ] && {
    warn "thunar missing"
    failed=$((failed + 1))
  }
  add_summary_row "Thunar" "$selected" "$installed" "$version"

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

  print_summary_table
}

install_selected_optional_apps() {
  ensure_runtime_dependencies

  # ── Thunar ──
  if flag_enabled "$INSTALL_THUNAR"; then
    if command -v thunar &>/dev/null; then
      ok "Thunar already installed"
    else
      info "Installing Thunar..."
      apt_q install thunar thunar-volman
      require_command_installed thunar "Thunar"
      ok "Thunar installed"
    fi
  else
    warn "Thunar disabled by INSTALL_THUNAR=${INSTALL_THUNAR}"
  fi

  # ── Yazi ──
  if flag_enabled "$INSTALL_YAZI"; then
    if command -v yazi &>/dev/null; then
      ok "Yazi already installed"
    else
      info "Installing Yazi..."
      local CARGO_TMP_DIR="${HOME}/.cache/cargo-tmp"
      local CARGO_TARGET_DIR_PATH="${HOME}/.cache/cargo-target"
      local MIN_YAZI_BUILD_KB=1048576
      local TMP_AVAIL_KB HOME_AVAIL_KB

      mkdir -p "$CARGO_TMP_DIR" "$CARGO_TARGET_DIR_PATH"

      TMP_AVAIL_KB="$(available_kb "$CARGO_TMP_DIR")"
      HOME_AVAIL_KB="$(available_kb "$HOME")"

      if [ "$TMP_AVAIL_KB" -lt "$MIN_YAZI_BUILD_KB" ] || [ "$HOME_AVAIL_KB" -lt "$MIN_YAZI_BUILD_KB" ]; then
        warn "Skipping Yazi: low build space (tmp=${TMP_AVAIL_KB}KB home=${HOME_AVAIL_KB}KB)"
        warn "Free space or set INSTALL_YAZI=0 to skip permanently"
        INSTALL_YAZI=0
      else
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
        if TMPDIR="$CARGO_TMP_DIR" CARGO_TARGET_DIR="$CARGO_TARGET_DIR_PATH" cargo install --locked yazi-fm yazi-cli &>/tmp/yazi-build.log; then
          zshrc_append '.cargo/bin' 'export PATH="$HOME/.cargo/bin:$PATH"'
          export PATH="$HOME/.cargo/bin:$PATH"
          if command -v yazi &>/dev/null; then
            ok "Yazi installed"
          else
            warn "Yazi binary not found after build — skipping Yazi checks"
            INSTALL_YAZI=0
          fi
        else
          warn "Yazi build failed (see /tmp/yazi-build.log)"
          warn "Try manually: TMPDIR=\"$CARGO_TMP_DIR\" CARGO_TARGET_DIR=\"$CARGO_TARGET_DIR_PATH\" cargo install --locked yazi-fm yazi-cli"
          INSTALL_YAZI=0
        fi
      fi
    fi
  else
    warn "Yazi disabled by INSTALL_YAZI=${INSTALL_YAZI}"
  fi

  # ── VS Code ──
  if flag_enabled "$INSTALL_VSCODE"; then
    if command -v code &>/dev/null; then
      ok "VS Code already installed"
    else
      info "Installing VS Code..."
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
    fi
  else
    warn "VS Code disabled by INSTALL_VSCODE=${INSTALL_VSCODE}"
  fi

  # ── Antigravity ──
  if flag_enabled "$INSTALL_ANTIGRAVITY"; then
    if dpkg -s antigravity &>/dev/null; then
      ok "Antigravity already installed"
    else
      info "Installing Antigravity..."
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
    fi
  else
    warn "Antigravity disabled by INSTALL_ANTIGRAVITY=${INSTALL_ANTIGRAVITY}"
  fi

  # ── OpenCode CLI ──
  if flag_enabled "$INSTALL_OPENCODE"; then
    if command -v opencode &>/dev/null; then
      ok "OpenCode CLI already installed"
    else
      info "Installing OpenCode CLI..."
      if command -v timeout &>/dev/null; then
        timeout 240 bun install -g opencode-ai &>/tmp/opencode-install.log || die "OpenCode CLI install timed out/failed (see /tmp/opencode-install.log)"
      else
        bun install -g opencode-ai &>/tmp/opencode-install.log || die "OpenCode CLI install failed (see /tmp/opencode-install.log)"
      fi
      require_command_installed opencode "OpenCode CLI"
      ok "OpenCode CLI installed"
    fi
  else
    warn "OpenCode CLI disabled by INSTALL_OPENCODE=${INSTALL_OPENCODE}"
  fi

  # ── Codex CLI ──
  if flag_enabled "$INSTALL_CODEX"; then
    if command -v codex &>/dev/null; then
      ok "Codex CLI already installed"
    else
      info "Installing Codex CLI..."
      if command -v timeout &>/dev/null; then
        timeout 240 npm install -g @openai/codex &>/tmp/codex-install.log || die "Codex CLI install timed out/failed (see /tmp/codex-install.log)"
      else
        npm install -g @openai/codex &>/tmp/codex-install.log || die "Codex CLI install failed (see /tmp/codex-install.log)"
      fi
      require_command_installed codex "Codex CLI"
      ok "Codex CLI installed"
    fi
  else
    warn "Codex CLI disabled by INSTALL_CODEX=${INSTALL_CODEX}"
  fi

  # ── Claude Code ──
  if flag_enabled "$INSTALL_CLAUDE"; then
    if command -v claude &>/dev/null; then
      ok "Claude Code already installed"
    else
      info "Installing Claude Code..."
      if command -v timeout &>/dev/null; then
        timeout 240 bash -lc 'curl -fsSL https://claude.ai/install.sh | bash' &>/tmp/claude-install.log || die "Claude Code install timed out/failed (see /tmp/claude-install.log)"
      else
        bash -lc 'curl -fsSL https://claude.ai/install.sh | bash' &>/tmp/claude-install.log || die "Claude Code install failed (see /tmp/claude-install.log)"
      fi
      require_command_installed claude "Claude Code"
      ok "Claude Code installed"
    fi
  else
    warn "Claude Code disabled by INSTALL_CLAUDE=${INSTALL_CLAUDE}"
  fi
}

run_full_setup_stack() {
  info "Optional apps flags: VSCode=${INSTALL_VSCODE}  Antigravity=${INSTALL_ANTIGRAVITY}  OpenCode=${INSTALL_OPENCODE}  Codex=${INSTALL_CODEX}  Claude=${INSTALL_CLAUDE}  Yazi=${INSTALL_YAZI}  Thunar=${INSTALL_THUNAR}"

  # ── Core packages for final desktop ──
  step "Core i3 packages + applications"
  apt_q install \
    git alacritty neovim polybar \
    flameshot network-manager-gnome mate-polkit
  require_packages_installed \
    git alacritty neovim polybar \
    flameshot network-manager-gnome mate-polkit
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
  if [ -f "$PREFETCH_FONT_ZIP" ]; then
    cp "$PREFETCH_FONT_ZIP" "$FONT_DIR/JetBrainsMono.zip"
  else
    wget -q -O "$FONT_DIR/JetBrainsMono.zip" \
      "https://github.com/ryanoasis/nerd-fonts/releases/download/v3.4.0/JetBrainsMono.zip" &>/dev/null || true
  fi
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
  if [ -f "$PREFETCH_WALLPAPER" ]; then
    cp "$PREFETCH_WALLPAPER" "$WALLPAPER_PATH"
  else
    curl -fsSL "${WALLPAPER_URL}" -o "${WALLPAPER_PATH}" || die "Failed to download wallpaper"
  fi
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

  install_selected_optional_apps

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

cleanup_kali_undercover() {
  step "Kali Undercover cleanup"

  if dpkg -s kali-undercover &>/dev/null; then
    info "Removing kali-undercover package..."
    apt_q purge kali-undercover
  fi

  rm -f "${HOME}/.config/autostart/kali-undercover.desktop" &>/dev/null || true
  sudo rm -f /etc/xdg/autostart/kali-undercover.desktop &>/dev/null || true
  ok "Kali Undercover cleanup complete"
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
      dpkg -s "$pkg" &>/dev/null && leftovers+=("$pkg")
    done
  done

  if [ "${#leftovers[@]}" -eq 0 ]; then
    ok "Previous DE packages removed successfully"
    return 0
  fi

  warn "Some previous DE packages are still installed: ${leftovers[*]}"
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

  step "Preferences"
  select_optional_apps_interactive
  select_file_manager_mode_interactive
  info "Selected: VSCode=${INSTALL_VSCODE} Antigravity=${INSTALL_ANTIGRAVITY} OpenCode=${INSTALL_OPENCODE} Codex=${INSTALL_CODEX} Claude=${INSTALL_CLAUDE} Yazi=${INSTALL_YAZI} Thunar=${INSTALL_THUNAR}"

  prefetch_assets_parallel

  # ── Update ──
  step "System Update"
  info "apt update + upgrade..."
  apt_q update
  apt_q upgrade
  apt_q install curl wget gpg ca-certificates unzip git build-essential
  ok "System up to date"

  # ── Install i3 + Xorg ──
  step "i3 + Xorg  (minimal — no compositor)"
  if command -v i3 &>/dev/null && command -v xinit &>/dev/null; then
    warn "i3 + xinit already installed — skipping core i3 install"
  else
    local I3_PKG
    I3_PKG="$(resolve_i3_package)" || die "Could not resolve i3 package (tried: i3, i3-wm). Run apt update and check repositories."
    info "Installing packages (i3 package: ${I3_PKG})..."
    apt_install_strict \
      xorg xinit xserver-xorg xserver-xorg-input-all \
      x11-xserver-utils "${I3_PKG}" i3status i3lock \
      feh xclip xdotool numlockx dbus-x11 xterm \
      udisks2 upower xdg-user-dirs xdg-utils dunst ||
      die "Failed to install core i3/Xorg packages. Check apt output above."
  fi
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

  cleanup_kali_undercover
  verify_de_removed "$DETECTED_DES"

  write_setup_state "phase2_done"
  ok "Phase 2 state saved (${STATE_FILE})"

  run_post_install_health_check

  # ── Done ──
  echo ""
  echo "+---------------------------------------------------------------+"
  echo "| Setup complete!                                               |"
  echo "+---------------------------------------------------------------+"
  echo ""
  echo -e "  ${ARROW}  Run ${CYAN}exec zsh${RESET} to load the new shell"
  echo -e "  ${ARROW}  Polybar network — check interface with ${CYAN}ip link${RESET}"
  echo ""
}

run_repair_mode() {
  panel_header "Repair Mode" "Setup already completed — checking selected apps" "Missing selected apps will be installed"

  info "Caching sudo..."
  sudo -v
  start_sudo_keepalive

  step "Preferences"
  select_optional_apps_interactive
  select_file_manager_mode_interactive
  info "Selected: VSCode=${INSTALL_VSCODE} Antigravity=${INSTALL_ANTIGRAVITY} OpenCode=${INSTALL_OPENCODE} Codex=${INSTALL_CODEX} Claude=${INSTALL_CLAUDE} Yazi=${INSTALL_YAZI} Thunar=${INSTALL_THUNAR}"

  prefetch_assets_parallel

  step "System Update"
  apt_q update
  apt_q upgrade
  ok "System up to date"

  install_selected_optional_apps
  run_post_install_health_check
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
  echo -e "  ${DIAMOND} ${BOLD}${CYAN}Setup already completed${RESET}  ${GRAY}— running repair mode${RESET}"
  run_repair_mode
fi
