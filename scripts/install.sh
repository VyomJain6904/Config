#!/usr/bin/env bash
#
# Usage:
#   ./install-tools.sh            interactive fzf multi-select
#   ./install-tools.sh --all      install everything, no prompts
#   ./install-tools.sh --list     print the tool registry and exit
#   ./install-tools.sh --tool X   install a single named tool
#
set -uo pipefail

TOOLS_DIR="${TOOLS_DIR:-/opt/tools}"
SRC_DIR="$TOOLS_DIR/src"
LOG_DIR="$TOOLS_DIR/logs"
APT_LOCK="/tmp/opt-tools-apt.lock"   # serializes apt calls -- see apt_install() below

RED='\033[0;31m'; GREEN='\033[1;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; GRAY='\033[0;90m'; RESET='\033[0m'

# Refuse a second concurrent invocation -- verified that without this, running
# the script twice at once causes the second one's bootstrap_dirs to wipe the
# first run's in-progress status/lock files out from under its live dashboard.
# --list is exempt: it's purely read-only and never touches LOG_DIR.
if [ "${1:-}" != "--list" ]; then
    SCRIPT_LOCK="/tmp/opt-tools-script.lock"
    exec 9>"$SCRIPT_LOCK"
    if ! flock -n 9; then
        echo -e "Another instance of this script is already running. Exiting."
        exit 1
    fi
fi

# ============================================================
# Bootstrap: dirs, PATH, base packages, mise-managed toolchains
# ============================================================

bootstrap_dirs() {
    sudo mkdir -p "$TOOLS_DIR" "$SRC_DIR" "$LOG_DIR"
    sudo chown -R "$(id -u)":"$(id -g)" "$TOOLS_DIR"
    rm -f "$LOG_DIR"/*.status          # clear stale markers from a previous run
    rm -rf "$LOG_DIR"/*.lock 2>/dev/null
}

# Keep the cached sudo credential alive for the whole run. Without this, a
# long --all run (ghidra download, seclists clone, several cargo builds) can
# outlast the default ~15min sudo timeout, and any apt-based install started
# afterwards fails silently in its log with no obvious "sudo expired" hint.
ensure_sudo_keepalive() {
    sudo -v || { echo "sudo access is required."; exit 1; }
    ( while true; do sudo -n true; sleep 60; done ) </dev/null >/dev/null 2>&1 &
    SUDO_KEEPALIVE_PID=$!
    trap '[ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null' EXIT
}

setup_path_globally() {
    echo "export PATH=\"$TOOLS_DIR:\$PATH\"" | sudo tee /etc/profile.d/opt-tools.sh >/dev/null
    sudo chmod +x /etc/profile.d/opt-tools.sh
    for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$RC" ] || continue
        grep -qxF "export PATH=\"$TOOLS_DIR:\$PATH\"" "$RC" || \
            echo "export PATH=\"$TOOLS_DIR:\$PATH\"" >> "$RC"
    done
    export PATH="$TOOLS_DIR:$PATH"
}

ensure_base_packages() {
    sudo apt update -qq >"$LOG_DIR/bootstrap.log" 2>&1
    if apt_install \
        git curl wget unzip zip build-essential gnupg jq fzf \
        python3 python3-pip python3-venv pipx \
        ruby ruby-dev \
        default-jre openjdk-21-jdk \
        clang libclang-dev libgssapi-krb5-2 libkrb5-dev libsasl2-modules-gssapi-mit \
        hashcat john hydra whatweb \
        >>"$LOG_DIR/bootstrap.log" 2>&1
    then
        echo -e "  ${GREEN}base packages: ok${RESET}"
    else
        echo -e "  ${RED}base packages: some failed to install -- see $LOG_DIR/bootstrap.log${RESET}"
    fi
}

# Language runtimes via mise -- only touches what's actually missing.
ensure_mise() {
    if ! command -v mise >/dev/null 2>&1; then
        curl -fsSL https://mise.run | sh >"$LOG_DIR/mise-install.log" 2>&1
    fi
    export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
    for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$RC" ] || continue
        grep -qxF 'export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"' "$RC" || \
            echo 'export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"' >> "$RC"
    done
}

# check_lang <display-name> <check-command> <mise-plugin-name> [version-command]
# version-command defaults to "<check-command> --version"; go needs an
# override since `go --version` isn't valid (it requires the `go version`
# subcommand instead) -- confirmed this is why go was showing "found (?)".
check_lang() {
    local disp="$1" cmd="$2" plugin="$3" vercmd="${4:-$2 --version}" ver
    if command -v "$cmd" >/dev/null 2>&1; then
        ver=$($vercmd 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
        printf "  %-8s ${GREEN}found${RESET} (%s)\n" "$disp" "${ver:-?}"
    else
        printf "  %-8s ${YELLOW}not found, installing via mise...${RESET}\n" "$disp"
        mise use -g "${plugin}@latest" >>"$LOG_DIR/mise-install.log" 2>&1
        hash -r
        if command -v "$cmd" >/dev/null 2>&1; then
            ver=$($vercmd 2>/dev/null | head -1 | grep -oE '[0-9]+\.[0-9]+(\.[0-9]+)?' | head -1)
            printf "  %-8s ${GREEN}installed${RESET} (%s)\n" "$disp" "${ver:-?}"
        else
            printf "  %-8s ${RED}FAILED to install -- see $LOG_DIR/mise-install.log${RESET}\n" "$disp"
        fi
    fi
}

ensure_toolchains() {
    ensure_mise
    echo "  languages:"
    check_lang rust   rustc  rust
    check_lang go     go     go     "go version"
    check_lang node   node   node
    check_lang bun    bun    bun
    check_lang python python3 python
}

ensure_pipx() {
    export PIPX_HOME="$SRC_DIR/pipx"
    export PIPX_BIN_DIR="$TOOLS_DIR"
    mkdir -p "$PIPX_HOME"
    for RC in "$HOME/.bashrc" "$HOME/.zshrc"; do
        [ -f "$RC" ] || continue
        grep -qxF "export PIPX_HOME=\"$SRC_DIR/pipx\"" "$RC" || echo "export PIPX_HOME=\"$SRC_DIR/pipx\"" >> "$RC"
        grep -qxF "export PIPX_BIN_DIR=\"$TOOLS_DIR\"" "$RC" || echo "export PIPX_BIN_DIR=\"$TOOLS_DIR\"" >> "$RC"
    done
    pipx ensurepath >/dev/null 2>&1 || true
}

# ============================================================
# Small helpers used by tool installers
# ============================================================

# Serializes any apt call this script makes. Verified: two concurrent
# `apt install` invocations collide on /var/lib/dpkg/lock-frontend and one
# fails outright -- this matters here because multiple selected tools
# (e.g. nmap + bettercap) each shell out to apt and run in parallel.
# Serializes gem installs into the shared $SRC_DIR/gems GEM_HOME (evil-winrm
# and wpscan both use it, and could be selected together). Unlike apt_install
# above, this collision wasn't directly reproduced -- rubygems.org isn't
# reachable to test from a sandbox -- but the fix is cheap and the downside
# of skipping it (a corrupted shared gem index) isn't, so it's applied anyway.
GEM_LOCK="/tmp/opt-tools-gem.lock"
gem_install() { flock "$GEM_LOCK" gem install --no-document --install-dir "$SRC_DIR/gems" --bindir "$SRC_DIR/gems/bin" "$@"; }

apt_install() { flock "$APT_LOCK" sudo apt install -y -qq "$@"; }

flat_link() { ln -sf "$1" "$TOOLS_DIR/$2"; }

fetch_latest_release_asset() {
    local repo="$1" pattern="$2" outfile="$3" url
    url=$(curl -s "https://api.github.com/repos/$repo/releases/latest" \
          | grep "browser_download_url" | grep -iE "$pattern" | head -n1 | cut -d '"' -f4)
    [ -z "$url" ] && { echo "no asset matching '$pattern' in $repo" >&2; return 1; }
    wget -q -O "$outfile" "$url"
}

git_clone_once() {
    local url="$1" dir="$2"
    [ -d "$dir/.git" ] && return 0   # already a complete clone
    rm -rf "$dir"                   # clear any partial/broken leftover (e.g. from an interrupted clone)
    git clone --depth 1 "$url" "$dir"
}

cargo_tool() {
    local crate="$1" bin="$2"
    cargo install "$crate" --locked --root "$SRC_DIR/cargo-$crate"
    flat_link "$SRC_DIR/cargo-$crate/bin/$bin" "$bin"
}

go_tool() { GOBIN="$TOOLS_DIR" go install "$1"; }

# --force is required: verified that retrying a broken/partial prior pipx
# install (e.g. left behind by an interrupted run) silently exits 0 and does
# nothing without it, since pipx refuses to touch an existing install unless
# forced -- which would make "just re-run to retry" a false promise.
pipx_tool() { pipx install --force "$1"; }

# ============================================================
# Tool registry: name -> description
# ============================================================
declare -A TOOLS=(
    [searchsploit]="ExploitDB search CLI (uses existing /opt/exploitdb clone)"
    [metasploit]="Metasploit Framework (msfconsole/msfvenom)"
    [bloodhound-cli]="BloodHound CE management CLI (also brings up its own neo4j via Docker)"
    [nmap]="Network mapper/port scanner"
    [rustscan]="Very fast port scanner, feeds into nmap"
    [subfinder]="Passive subdomain enumeration"
    [httpx]="Fast HTTP probing/toolkit"
    [enum4linux-ng]="SMB/AD enumeration"
    [responder]="LLMNR/NBT-NS/mDNS poisoner"
    [netexec]="Network protocol swiss-army-knife (crackmapexec successor)"
    [impacket]="Python AD/SMB/Kerberos protocol library + scripts"
    [certipy-ad]="AD CS (ADCS) enumeration and abuse"
    [smbmap]="SMB share enumeration"
    [evil-winrm]="WinRM shell client"
    [kerbrute]="Kerberos user/password bruteforcing"
    [ligolo-ng]="Tunneling/pivoting via TUN interfaces"
    [rusthound-ce]="Fast BloodHound CE data collector (Rust)"
    [ghidra]="NSA reverse-engineering suite"
    [linpeas]="Linux privesc enumeration script"
    [winpeas]="Windows privesc enumeration binaries"
    [feroxbuster]="Fast content/directory brute-forcer"
    [seclists]="Wordlists (symlinks existing /usr/share/Seclists if present, else clones -- large, takes a while)"
    [gobuster]="Directory/DNS/vhost brute-forcer"
    [ffuf]="Fast web fuzzer"
    [wpscan]="WordPress vulnerability scanner"
    [sqlmap]="Automated SQL injection tool"
    [nuclei]="Templated vulnerability scanner"
    [jwt_tool]="JWT attack toolkit"
    [pspy]="Linux process spy, no root needed"
    [les]="Linux Exploit Suggester"
    [chisel]="TCP/UDP tunnel over HTTP"
    [sshuttle]="Poor-man's VPN over SSH"
    [bettercap]="Network attack/MITM framework"
    [bloodyAD]="AD privilege escalation / object abuse framework"
    [pywhisker]="Shadow credentials attacks"
    [windapsearch]="LDAP-based AD enumeration"
    [ldapdomaindump]="LDAP domain info dumper"
    [targetedKerberoast]="Kerberoasting without enumerated user list"
    [coercer]="Automate PetitPotam/PrinterBug/coercion attacks"
    [krbrelayx]="Kerberos unconstrained delegation relay toolkit"
)

# ============================================================
# Tool installer functions
# ============================================================

install_searchsploit() {
    [ -x /opt/exploitdb/searchsploit ] && flat_link /opt/exploitdb/searchsploit searchsploit \
        || { echo "expected /opt/exploitdb -- clone offensive-security/exploitdb there first"; return 1; }
}

install_metasploit() {
    if [ ! -x /opt/metasploit-framework/bin/msfconsole ]; then
        curl -fsSL https://raw.githubusercontent.com/rapid7/metasploit-omnibus/master/config/templates/metasploit-framework-wrappers/msfupdate.erb -o /tmp/msfinstall
        chmod +x /tmp/msfinstall
        sudo /tmp/msfinstall
    fi
    flat_link /opt/metasploit-framework/bin/msfconsole msfconsole
    flat_link /opt/metasploit-framework/bin/msfvenom msfvenom
}

install_bloodhound-cli() {
    if [ ! -x "$TOOLS_DIR/bloodhound-cli" ]; then
        mkdir -p "$SRC_DIR/bloodhound-cli"
        wget -q -O "$SRC_DIR/bloodhound-cli/bh.tar.gz" \
            https://github.com/SpecterOps/bloodhound-cli/releases/latest/download/bloodhound-cli-linux-amd64.tar.gz
        tar -xzf "$SRC_DIR/bloodhound-cli/bh.tar.gz" -C "$SRC_DIR/bloodhound-cli"
        [ -x "$SRC_DIR/bloodhound-cli/bloodhound-cli" ] || { echo "bloodhound-cli binary not found after extraction"; return 1; }
        flat_link "$SRC_DIR/bloodhound-cli/bloodhound-cli" bloodhound-cli
    fi
    echo "NOTE: run 'bloodhound-cli install' yourself when ready (needs Docker, prints a one-time admin password) -- not run automatically."
}

install_nmap() { apt_install nmap; }
install_rustscan() { cargo_tool rustscan rustscan; }
install_subfinder() { go_tool "github.com/projectdiscovery/subfinder/v2/cmd/subfinder@latest"; }
install_httpx() { go_tool "github.com/projectdiscovery/httpx/cmd/httpx@latest"; }

install_enum4linux-ng() {
    git_clone_once https://github.com/cddmp/enum4linux-ng.git "$SRC_DIR/enum4linux-ng"
    pip install --break-system-packages --target "$SRC_DIR/enum4linux-ng/deps" \
        -r "$SRC_DIR/enum4linux-ng/requirements.txt" -q
    chmod +x "$SRC_DIR/enum4linux-ng/enum4linux-ng.py"
    cat > "$TOOLS_DIR/enum4linux-ng" <<EOF
#!/usr/bin/env bash
export PYTHONPATH="$SRC_DIR/enum4linux-ng/deps:\$PYTHONPATH"
exec python3 "$SRC_DIR/enum4linux-ng/enum4linux-ng.py" "\$@"
EOF
    chmod +x "$TOOLS_DIR/enum4linux-ng"
}

install_responder() {
    git_clone_once https://github.com/lgandx/Responder.git "$SRC_DIR/Responder"
    flat_link "$SRC_DIR/Responder/Responder.py" responder
}

install_netexec() { pipx_tool "git+https://github.com/Pennyw0rth/NetExec.git"; }
install_impacket() { pipx_tool "git+https://github.com/fortra/impacket.git"; }
install_certipy-ad() { pipx_tool "certipy-ad"; }
install_smbmap() { pipx_tool "git+https://github.com/ShawnDEvans/smbmap.git"; }
install_bloodyAD() { pipx_tool "bloodyAD"; }
install_ldapdomaindump() { pipx_tool "ldapdomaindump"; }
install_coercer() { pipx_tool "Coercer"; }
install_sshuttle() { pipx_tool "sshuttle"; }

install_evil-winrm() {
    mkdir -p "$SRC_DIR/gems"
    GEM_HOME="$SRC_DIR/gems" GEM_PATH="$SRC_DIR/gems" gem_install evil-winrm
    cat > "$TOOLS_DIR/evil-winrm" <<EOF
#!/usr/bin/env bash
export GEM_HOME="$SRC_DIR/gems"
export GEM_PATH="$SRC_DIR/gems"
exec "$SRC_DIR/gems/bin/evil-winrm" "\$@"
EOF
    chmod +x "$TOOLS_DIR/evil-winrm"
}

install_wpscan() {
    mkdir -p "$SRC_DIR/gems"
    GEM_HOME="$SRC_DIR/gems" GEM_PATH="$SRC_DIR/gems" gem_install wpscan
    cat > "$TOOLS_DIR/wpscan" <<EOF
#!/usr/bin/env bash
export GEM_HOME="$SRC_DIR/gems"
export GEM_PATH="$SRC_DIR/gems"
exec "$SRC_DIR/gems/bin/wpscan" "\$@"
EOF
    chmod +x "$TOOLS_DIR/wpscan"
}

install_kerbrute() { go_tool "github.com/ropnop/kerbrute@latest"; }
install_gobuster() { go_tool "github.com/OJ/gobuster/v3@latest"; }
install_ffuf() { go_tool "github.com/ffuf/ffuf/v2@latest"; }
install_nuclei() { go_tool "github.com/projectdiscovery/nuclei/v3/cmd/nuclei@latest"; }
install_chisel() { go_tool "github.com/jpillora/chisel@latest"; }

install_ligolo-ng() {
    git_clone_once https://github.com/nicocha30/ligolo-ng.git "$SRC_DIR/ligolo-ng"
    ( cd "$SRC_DIR/ligolo-ng" && go build -o "$TOOLS_DIR/ligolo-proxy" cmd/proxy/main.go )
    ( cd "$SRC_DIR/ligolo-ng" && go build -o "$TOOLS_DIR/ligolo-agent" cmd/agent/main.go )
}

install_rusthound-ce() { cargo_tool rusthound-ce rusthound-ce; }
install_feroxbuster() { cargo_tool feroxbuster feroxbuster; }

install_ghidra() {
    rm -rf "$SRC_DIR/ghidra"   # clear any stale prior version -- otherwise a re-run/upgrade
                               # could leave two ghidra_*_PUBLIC dirs and `find` may pick the old one
    mkdir -p "$SRC_DIR/ghidra"
    fetch_latest_release_asset "NationalSecurityAgency/ghidra" "ghidra_.*PUBLIC.*\.zip" "$SRC_DIR/ghidra/ghidra.zip"
    unzip -q -o "$SRC_DIR/ghidra/ghidra.zip" -d "$SRC_DIR/ghidra"
    local dir; dir=$(find "$SRC_DIR/ghidra" -maxdepth 1 -type d -name "ghidra_*" | head -n1)
    # ln -sf succeeds even for a bogus/nonexistent target, so an empty or
    # wrong $dir here would otherwise silently produce a dangling symlink
    # while still reporting "done" -- verify the real binary exists first.
    [ -n "$dir" ] && [ -x "$dir/ghidraRun" ] || { echo "could not locate ghidraRun after extraction"; return 1; }
    flat_link "$dir/ghidraRun" ghidra
}

install_linpeas() {
    mkdir -p "$SRC_DIR/peass"
    wget -q -O "$SRC_DIR/peass/linpeas.sh" https://github.com/peass-ng/PEASS-ng/releases/latest/download/linpeas.sh
    chmod +x "$SRC_DIR/peass/linpeas.sh"
    flat_link "$SRC_DIR/peass/linpeas.sh" linpeas.sh
}

install_winpeas() {
    mkdir -p "$SRC_DIR/peass"
    wget -q -O "$SRC_DIR/peass/winPEAS.bat" https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEAS.bat
    wget -q -O "$SRC_DIR/peass/winPEASx64.exe" https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASx64.exe
    wget -q -O "$SRC_DIR/peass/winPEASx86.exe" https://github.com/peass-ng/PEASS-ng/releases/latest/download/winPEASx86.exe
    flat_link "$SRC_DIR/peass/winPEASx64.exe" winpeas.exe
}

install_seclists() {
    if [ -d /usr/share/Seclists ]; then flat_link /usr/share/Seclists seclists; return 0; fi
    if [ -d /usr/share/seclists ]; then flat_link /usr/share/seclists seclists; return 0; fi
    if [ -d "$SRC_DIR/SecLists" ]; then flat_link "$SRC_DIR/SecLists" seclists; return 0; fi
    echo "no existing Seclists found -- cloning full repo, this is large (~1GB) and will take a while"
    git_clone_once https://github.com/danielmiessler/SecLists.git "$SRC_DIR/SecLists"
    flat_link "$SRC_DIR/SecLists" seclists
}

install_sqlmap() {
    git_clone_once https://github.com/sqlmapproject/sqlmap.git "$SRC_DIR/sqlmap"
    flat_link "$SRC_DIR/sqlmap/sqlmap.py" sqlmap
}

install_jwt_tool() {
    git_clone_once https://github.com/ticarpi/jwt_tool.git "$SRC_DIR/jwt_tool"
    pip install --break-system-packages --target "$SRC_DIR/jwt_tool/deps" \
        -r "$SRC_DIR/jwt_tool/requirements.txt" -q 2>/dev/null || true
    cat > "$TOOLS_DIR/jwt_tool" <<EOF
#!/usr/bin/env bash
export PYTHONPATH="$SRC_DIR/jwt_tool/deps:\$PYTHONPATH"
exec python3 "$SRC_DIR/jwt_tool/jwt_tool.py" "\$@"
EOF
    chmod +x "$TOOLS_DIR/jwt_tool"
}

install_pspy() {
    mkdir -p "$SRC_DIR/pspy"
    wget -q -O "$SRC_DIR/pspy/pspy64" https://github.com/DominicBreuker/pspy/releases/latest/download/pspy64
    chmod +x "$SRC_DIR/pspy/pspy64"
    flat_link "$SRC_DIR/pspy/pspy64" pspy64
}

install_les() {
    mkdir -p "$SRC_DIR/les"
    wget -q -O "$SRC_DIR/les/les.sh" https://raw.githubusercontent.com/mzet-/linux-exploit-suggester/master/linux-exploit-suggester.sh
    chmod +x "$SRC_DIR/les/les.sh"
    flat_link "$SRC_DIR/les/les.sh" les.sh
}

install_bettercap() {
    apt_install bettercap || { echo "bettercap not in apt on this release -- build from source manually"; return 1; }
    # avoid needing sudo for every run (raw sockets / packet capture / low ports)
    sudo setcap cap_net_raw,cap_net_admin,cap_net_bind_service+eip "$(command -v bettercap)" 2>/dev/null \
        && echo "granted cap_net_raw/cap_net_admin so bettercap runs without sudo" \
        || echo "could not setcap -- run bettercap with sudo, or setcap manually"
}

install_pywhisker() {
    git_clone_once https://github.com/ShutdownRepo/pywhisker.git "$SRC_DIR/pywhisker"
    pip install --break-system-packages --target "$SRC_DIR/pywhisker/deps" \
        -r "$SRC_DIR/pywhisker/requirements.txt" -q
    cat > "$TOOLS_DIR/pywhisker" <<EOF
#!/usr/bin/env bash
export PYTHONPATH="$SRC_DIR/pywhisker/deps:\$PYTHONPATH"
exec python3 "$SRC_DIR/pywhisker/pywhisker.py" "\$@"
EOF
    chmod +x "$TOOLS_DIR/pywhisker"
}

install_windapsearch() {
    git_clone_once https://github.com/ropnop/windapsearch.git "$SRC_DIR/windapsearch"
    pip install --break-system-packages --target "$SRC_DIR/windapsearch/deps" \
        -r "$SRC_DIR/windapsearch/requirements.txt" -q 2>/dev/null || true
    cat > "$TOOLS_DIR/windapsearch" <<EOF
#!/usr/bin/env bash
export PYTHONPATH="$SRC_DIR/windapsearch/deps:\$PYTHONPATH"
exec python3 "$SRC_DIR/windapsearch/windapsearch.py" "\$@"
EOF
    chmod +x "$TOOLS_DIR/windapsearch"
}

install_targetedKerberoast() {
    git_clone_once https://github.com/ShutdownRepo/targetedKerberoast.git "$SRC_DIR/targetedKerberoast"
    pip install --break-system-packages --target "$SRC_DIR/targetedKerberoast/deps" \
        -r "$SRC_DIR/targetedKerberoast/requirements.txt" -q
    cat > "$TOOLS_DIR/targetedKerberoast" <<EOF
#!/usr/bin/env bash
export PYTHONPATH="$SRC_DIR/targetedKerberoast/deps:\$PYTHONPATH"
exec python3 "$SRC_DIR/targetedKerberoast/targetedKerberoast.py" "\$@"
EOF
    chmod +x "$TOOLS_DIR/targetedKerberoast"
}

install_krbrelayx() {
    git_clone_once https://github.com/dirkjanm/krbrelayx.git "$SRC_DIR/krbrelayx"
    pip install --break-system-packages --target "$SRC_DIR/krbrelayx/deps" \
        -r "$SRC_DIR/krbrelayx/requirements.txt" -q 2>/dev/null || true
    for script in krbrelayx printerbug addspn dnstool; do
        cat > "$TOOLS_DIR/$script" <<EOF
#!/usr/bin/env bash
export PYTHONPATH="$SRC_DIR/krbrelayx/deps:\$PYTHONPATH"
exec python3 "$SRC_DIR/krbrelayx/${script}.py" "\$@"
EOF
        chmod +x "$TOOLS_DIR/$script"
    done
}

# ============================================================
# Launch a single tool install in the background (idempotent --
# safe to call more than once for the same tool in one run)
# ============================================================

launch_install() {
    local t="$1"
    mkdir "$LOG_DIR/$t.lock" 2>/dev/null || return 0   # atomic: only the first caller wins
    echo running > "$LOG_DIR/$t.status"
    (
        exec 9>&-   # don't let this background job hold the script-level lock open
        # NOTE: the install call is deliberately NOT the direct condition of
        # an if/while -- bash suppresses `set -e` for the entire execution of
        # anything tested that way (including nested function calls), which
        # would let a real failure (bad clone/build) slide through to a
        # trailing `ln -sf`/`chmod` that "succeeds" regardless and reports a
        # false "done". Running it as a bare statement and checking $?
        # separately keeps set -e honest.
        (
            set -e
            fn="install_${t}"
            declare -f "$fn" >/dev/null || { echo "no installer for $t"; exit 1; }
            "$fn"
        ) > "$LOG_DIR/$t.log" 2>&1
        rc=$?
        if [ "$rc" -eq 0 ]; then
            echo done > "$LOG_DIR/$t.status"
        else
            echo failed > "$LOG_DIR/$t.status"
        fi
    ) </dev/null >/dev/null 2>&1 &
}

# ============================================================
# fzf picker -- installs fire the instant a tool is tab-selected,
# not after the whole picker session ends
# ============================================================

pick_and_stream_install() {
    local names=() menu=""
    for name in "${!TOOLS[@]}"; do names+=("$name"); done
    IFS=$'\n' names=($(sort <<<"${names[*]}")); unset IFS
    for name in "${names[@]}"; do
        menu+="$(printf '%-22s %s\n' "$name" "${TOOLS[$name]}")"$'\n'
    done

    local queue; queue=$(mktemp)
    : > "$queue"

    # background watcher: pure polling, no long-running child processes to
    # orphan if killed (tail -F would leak a follower process on kill)
    (
        exec 9>&-   # don't let this background job hold the script-level lock open
        last_line=0
        while :; do
            if [ -s "$queue" ]; then
                total=$(wc -l < "$queue")
                if [ "$total" -gt "$last_line" ]; then
                    sed -n "$((last_line+1)),\$p" "$queue" | while IFS= read -r line; do
                        name=$(awk '{print $1}' <<<"$line")
                        [ -n "$name" ] && launch_install "$name"
                    done
                    last_line=$total
                fi
            fi
            sleep 0.1
        done
    ) </dev/null >/dev/null 2>&1 &
    local watcher_pid=$!

    # Ctrl-C while fzf itself has terminal focus is actually swallowed by fzf
    # as its own abort key (verified: fzf runs in raw mode and never lets
    # SIGINT reach this script in that window) -- so this trap mainly guards
    # against a signal delivered some other way (e.g. `kill -INT` from
    # another session) while tools are queued but Enter hasn't been pressed.
    # Also closes the watcher-orphan leak (verified: without this, the
    # polling loop above has no exit condition of its own and runs forever).
    trap 'kill "$watcher_pid" 2>/dev/null
          echo
          echo -e "${YELLOW}Interrupted. Tools mid-install may be left partially installed.${RESET}"
          echo -e "${YELLOW}Re-run this script (or --tool NAME) to retry them.${RESET}"
          exit 130' INT

    printf '%s' "$menu" | fzf --multi --height=80% --border \
        --header="TAB selects and starts installing immediately. ENTER when done browsing." \
        --prompt="pick tools > " \
        --bind "tab:execute-silent(printf '%s\n' {} >> ${queue})+toggle+down" \
        --bind "btab:execute-silent(printf '%s\n' {} >> ${queue})+toggle+up" \
        > "$queue.final"

    trap - INT   # back to default once fzf has returned normally
    kill "$watcher_pid" 2>/dev/null
    cat "$queue.final" >> "$queue"   # covers Enter-without-ever-tabbing edge case

    mapfile -t all_names < <(awk '{print $1}' "$queue" | awk '!seen[$0]++')
    rm -f "$queue" "$queue.final"

    render_dashboard "${all_names[@]}"
}

# ============================================================
# Live color-coded status dashboard -- waits for every given
# tool's background job (already launched, or launched here) to finish
# ============================================================

render_dashboard() {
    local selected=("$@")
    [ "${#selected[@]}" -eq 0 ] && { echo "nothing selected."; return 0; }

    for t in "${selected[@]}"; do launch_install "$t"; done

    declare -A STATUS
    for t in "${selected[@]}"; do STATUS[$t]="running"; done

    local total=${#selected[@]}
    for t in "${selected[@]}"; do printf "  [ ] %s\n" "$t"; done

    # Ctrl-C here: verified empirically that SIGINT reaches the in-flight
    # background installs too (the OS delivers it to the whole process
    # group, regardless of what this trap does), so they do NOT survive --
    # don't falsely claim otherwise. They may be left partially installed.
    trap 'echo
          echo -e "${YELLOW}Interrupted. Tools mid-install may be left partially installed.${RESET}"
          echo -e "${YELLOW}Re-run this script (or --tool NAME) to retry them.${RESET}"
          exit 130' INT

    while :; do
        local all_done=true
        for t in "${selected[@]}"; do
            if [ -f "$LOG_DIR/$t.status" ]; then
                STATUS[$t]=$(cat "$LOG_DIR/$t.status")
            fi
            [ "${STATUS[$t]}" = "running" ] && all_done=false
        done

        tput cuu "$total" 2>/dev/null || true
        for t in "${selected[@]}"; do
            case "${STATUS[$t]}" in
                running) printf "  ${YELLOW}[…] %-22s installing${RESET}\n" "$t" ;;
                done)    printf "  ${GREEN}[✔] %-22s done${RESET}\n" "$t" ;;
                failed)  printf "  ${RED}[✘] %-22s failed${RESET}\n" "$t" ;;
                *)       printf "  ${GRAY}[ ] %-22s pending${RESET}\n" "$t" ;;
            esac
        done

        $all_done && break
        sleep 0.4
    done
    trap - INT

    echo
    local fails=0
    for t in "${selected[@]}"; do
        [ "${STATUS[$t]}" != "done" ] && { echo -e "  ${RED}log: $LOG_DIR/$t.log${RESET}"; fails=$((fails+1)); }
    done
    [ "$fails" -eq 0 ] && echo -e "${GREEN}All selected tools installed.${RESET}"
}

# ============================================================
# Main
# ============================================================

main() {
    # --list is pure read-only info -- doesn't need apt/mise/sudo bootstrap at all
    if [ "${1:-}" = "--list" ]; then
        for name in "${!TOOLS[@]}"; do printf "%-22s %s\n" "$name" "${TOOLS[$name]}"; done | sort
        exit 0
    fi

    bootstrap_dirs
    ensure_sudo_keepalive
    echo -e "${BLUE}[*] Bootstrapping...${RESET}"
    ensure_base_packages
    ensure_toolchains
    ensure_pipx
    setup_path_globally

    case "${1:-}" in
        --all)
            local all=()
            for name in "${!TOOLS[@]}"; do all+=("$name"); done
            IFS=$'\n' all=($(sort <<<"${all[*]}")); unset IFS
            render_dashboard "${all[@]}"
            ;;
        --tool)
            [ -z "${2:-}" ] && { echo "usage: $0 --tool NAME"; exit 1; }
            render_dashboard "$2"
            ;;
        "")
            command -v fzf >/dev/null 2>&1 || { echo "fzf missing -- install it manually"; exit 1; }
            pick_and_stream_install
            INTERACTIVE_RUN=true
            ;;
        *)
            echo "usage: $0 [--all | --list | --tool NAME]"
            exit 1
            ;;
    esac

    # Only auto-refresh the shell for the interactive picker: a script can't
    # modify its parent shell's environment (this process exiting is why
    # PATH changes don't just "stick"), but it CAN exec a brand-new shell in
    # its place, which genuinely re-reads .bashrc/.zshrc from scratch --
    # same trick as `newgrp docker` after a Docker install. Skipped for
    # --all/--tool since those may run non-interactively/in scripts, where
    # replacing the process with a fresh interactive shell would just hang.
    if [ "${INTERACTIVE_RUN:-false}" = true ] && [ -t 0 ] && [ -t 1 ] && command -v "${SHELL:-/bin/bash}" >/dev/null 2>&1; then
        echo -e "${GREEN}Refreshing your shell so the new tools are available immediately...${RESET}"
        echo -e "${GRAY}(this replaces this process with a fresh shell -- 'exit' returns you to where you started)${RESET}"
        # `exec` replaces this process image entirely and, verified
        # empirically, skips the EXIT trap set in ensure_sudo_keepalive --
        # so that trap alone would leak the keepalive loop forever every
        # time this path runs. Kill it explicitly first.
        [ -n "${SUDO_KEEPALIVE_PID:-}" ] && kill "$SUDO_KEEPALIVE_PID" 2>/dev/null
        # File descriptors ARE inherited across exec (verified) -- without
        # closing fd 9 here, the script-level lock would stay held for the
        # entire lifetime of the user's refreshed shell session, blocking
        # any future run of this script until they close that terminal.
        exec 9>&-
        # Verified empirically: `zsh -l` correctly sources ~/.zshrc (login +
        # interactive zsh both read it), but `bash -l` does NOT reliably
        # source ~/.bashrc -- login bash reads ~/.bash_profile instead, which
        # most users don't have, so the PATH changes would silently not
        # apply. bash needs --rcfile pointed at .bashrc explicitly.
        case "$(basename "${SHELL:-/bin/bash}")" in
            zsh)  exec "$SHELL" -l ;;
            bash) exec bash --rcfile "$HOME/.bashrc" -i ;;
            *)    exec "$SHELL" -l ;;
        esac
    else
        echo -e "${GREEN}Open a new shell (or source ~/.bashrc / ~/.zshrc) for PATH changes to apply.${RESET}"
    fi
}

main "$@"
