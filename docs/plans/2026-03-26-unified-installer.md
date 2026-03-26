# Unified Cross-Distro Installer Implementation Plan

> **For Claude:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Build a single idempotent installer script that detects environment details, supports Debian/Ubuntu/Mint/Fedora/Arch, applies Config-VM or Config-Arch style, installs/updates dev toolchains, and reports installed versions.

**Architecture:** Add a new top-level `install-unified.sh` with modular shell functions for detection, package-manager abstraction, runtime toolchain setup, style-specific package/config deployment, verification, and optional cleanup. Keep existing `install-VM.sh` and `install-Arch.sh` untouched for rollback safety. Persist run state under user-local state files for safe rerun behavior.

**Tech Stack:** Bash, system package managers (`apt`, `dnf`, `pacman`), `rustup`, `nvm`, `bun`, `curl`, `tar`.

---

### Task 1: Create Unified Script Skeleton

**Files:**
- Create: `install-unified.sh`

**Step 1: Write strict shell setup and metadata constants**

```bash
#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_VERSION="1.0.0"
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
STATE_DIR="${HOME}/.local/state/config-installer"
STATE_FILE="${STATE_DIR}/state.env"
```

**Step 2: Add logging and trap handling**

```bash
LOG_FILE="/tmp/config-installer-$(date +%Y%m%d_%H%M%S).log"
exec > >(tee -a "$LOG_FILE") 2>&1
trap 'echo "Error on line $LINENO"' ERR
```

**Step 3: Add base helper functions (`info`, `warn`, `die`)**

```bash
info() { printf '[INFO] %s\n' "$*"; }
warn() { printf '[WARN] %s\n' "$*"; }
die()  { printf '[ERROR] %s\n' "$*"; exit 1; }
```

**Step 4: Syntax-check the script**

Run: `bash -n install-unified.sh`
Expected: no output

**Step 5: Commit**

```bash
git add install-unified.sh docs/plans/2026-03-26-unified-installer.md
git commit -m "plan: add unified installer design and scaffold"
```

### Task 2: Add Environment Detection and Reporting

**Files:**
- Modify: `install-unified.sh`

**Step 1: Detect OS, distro, package manager, and hardware info**

```bash
detect_os()
detect_hardware()
detect_session()
```

**Step 2: Print report in one section before prompts**

```bash
print_detection_report
```

**Step 3: Add i3+TTY condition helper**

```bash
is_i3_tty_session
```

**Step 4: Syntax-check**

Run: `bash -n install-unified.sh`
Expected: no output

**Step 5: Commit**

```bash
git add install-unified.sh
git commit -m "feat: add environment detection and i3 tty checks"
```

### Task 3: Implement Package Manager Abstraction

**Files:**
- Modify: `install-unified.sh`

**Step 1: Add `pkg_update_upgrade`, `pkg_install`, `pkg_is_installed` wrappers**

```bash
pkg_update_upgrade
pkg_install "$@"
pkg_is_installed "pkg"
```

**Step 2: Cover apt/dnf/pacman branches**

```bash
case "$PKG_MANAGER" in apt|dnf|pacman) ... esac
```

**Step 3: Add best-effort installer for cross-distro optional packages**

```bash
pkg_install_best_effort "pkg1" "pkg2"
```

**Step 4: Syntax-check**

Run: `bash -n install-unified.sh`
Expected: no output

**Step 5: Commit**

```bash
git add install-unified.sh
git commit -m "feat: add cross-distro package manager abstraction"
```

### Task 4: Add Style Selection and Recommendations

**Files:**
- Modify: `install-unified.sh`

**Step 1: Prompt style choice with recommendation text**

```bash
choose_style
```

**Step 2: Add install confirmation prompt**

```bash
confirm_install_selected_style
```

**Step 3: Persist selected style in state**

```bash
save_state
```

**Step 4: Syntax-check**

Run: `bash -n install-unified.sh`
Expected: no output

**Step 5: Commit**

```bash
git add install-unified.sh
git commit -m "feat: add style prompt with vm and base-system guidance"
```

### Task 5: Implement Runtime Toolchain Setup

**Files:**
- Modify: `install-unified.sh`

**Step 1: Add `ensure_rust_latest` and update via rustup**

```bash
ensure_rust_latest
```

**Step 2: Add `ensure_go_latest` with arch mapping and tarball install**

```bash
map_go_arch
ensure_go_latest
```

**Step 3: Add `ensure_node_latest` via nvm and `ensure_bun_latest`**

```bash
ensure_node_latest
ensure_bun_latest
```

**Step 4: Run toolchain checks**

Run: `bash -n install-unified.sh`
Expected: no output

**Step 5: Commit**

```bash
git add install-unified.sh
git commit -m "feat: add rust go node bun latest-version installers"
```

### Task 6: Add Dev Package Manifests and Install Flow

**Files:**
- Modify: `install-unified.sh`

**Step 1: Define per-distro package lists for core/minimal/modern**

```bash
resolve_package_sets
```

**Step 2: Install selected package sets**

```bash
install_style_packages
```

**Step 3: Add config deployment from local repo style directory**

```bash
deploy_style_configs
```

**Step 4: Syntax-check**

Run: `bash -n install-unified.sh`
Expected: no output

**Step 5: Commit**

```bash
git add install-unified.sh
git commit -m "feat: install style-specific dev packages and deploy configs"
```

### Task 7: Idempotent Rerun Verification and Reporting

**Files:**
- Modify: `install-unified.sh`

**Step 1: Add verification checks for required commands**

```bash
verify_required_commands
```

**Step 2: Add version summary table output**

```bash
print_versions_report
```

**Step 3: Add rerun behavior (`verify-only` when healthy)**

```bash
if everything_ok; then info "verify-only"
```

**Step 4: Syntax-check and dry-run check**

Run: `bash -n install-unified.sh`
Expected: no output

**Step 5: Commit**

```bash
git add install-unified.sh
git commit -m "feat: add idempotent rerun verification and version reporting"
```

### Task 8: Optional Legacy Cleanup Mode

**Files:**
- Modify: `install-unified.sh`

**Step 1: Add `--purge-legacy` flag parser**

```bash
parse_args "$@"
```

**Step 2: Add guarded cleanup function for old DE packages/configs**

```bash
purge_legacy_desktop_stacks
```

**Step 3: Require explicit confirmation token before destructive action**

```bash
read -r token
[[ "$token" == "PURGE" ]]
```

**Step 4: Syntax-check**

Run: `bash -n install-unified.sh`
Expected: no output

**Step 5: Commit**

```bash
git add install-unified.sh
git commit -m "feat: add optional guarded legacy cleanup mode"
```

### Task 9: Validate Script Locally

**Files:**
- Modify: `install-unified.sh` (only if fixes needed)

**Step 1: Shell syntax validation**

Run: `bash -n install-unified.sh`
Expected: no output

**Step 2: Static lint (if shellcheck available)**

Run: `shellcheck install-unified.sh`
Expected: no critical errors

**Step 3: Usage check without root side effects**

Run: `bash install-unified.sh --help`
Expected: usage + flag descriptions

**Step 4: Commit fixes if needed**

```bash
git add install-unified.sh
git commit -m "chore: finalize unified installer validation fixes"
```
