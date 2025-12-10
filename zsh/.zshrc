# ========================
# Oh My Zsh & Base Setup
# ========================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="apple"

# ----------------
# Starship & Zoxide
# ----------------
eval "$(starship init zsh)"
eval "$(zoxide init zsh --cmd cd)"

# ----------------
# Plugins
# ----------------
plugins=(
    ssh
    git
    sublime
    fzf
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    zsh-history-substring-search
    zsh-interactive-cd
)

source $ZSH/oh-my-zsh.sh
source ~/.oh-my-zsh/plugins/zsh-defer/zsh-defer.plugin.zsh
zsh-defer source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
zsh-defer source /usr/share/zsh-history-substring-search/zsh-history-substring-search.zsh

# ========================
# Custom Prompt Functions
# ========================
get_ip_address() {
    local tun0_ip eth0_ip wlan0_ip

    tun0_ip=$(ip -4 addr show tun0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
    eth0_ip=$(ip -4 addr show eth0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)
    wlan0_ip=$(ip -4 addr show wlan0 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1)

    if [[ -n "$tun0_ip" ]]; then
        echo "%F{red}󰖂 %F{red}${tun0_ip}%f"
    elif [[ -n "$eth0_ip" ]]; then
        echo "%F{green}󰈀 %F{green}${eth0_ip}%f"
    elif [[ -n "$wlan0_ip" ]]; then
        echo "%F{yellow} %F{yellow}${wlan0_ip}%f"
    else
        echo "%F{white}󰤮 %F{white}No IP%f"
    fi
}



git_branch() {
    if git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        local branch
        branch=$(git symbolic-ref --short HEAD 2>/dev/null || git rev-parse --short HEAD 2>/dev/null)
        echo "[%{$fg[black]%}  $branch%{$reset_color%}]"
    fi
}

PROMPT='[%F{red} %c%f] [$(get_ip_address)%f] ➤ '

# ========================
# Aliases
# ========================

# --- System ---
alias cls="clear"
alias cl="clear"
alias lc="clear"
alias su="su - root"
alias upd="sudo apt update && sudo apt upgrade -y && sudo apt full-upgrade -y"
alias updk="sudo apt install linux-headers-$(uname -r)"
alias rmf="sudo rm -rf"
alias cln="sudo apt autoremove -y && sudo apt autoclean -y"
alias cltmp="cd /tmp && rmf *"
alias mk="mkdir"
alias exir="exit"
alias ins="sudo apt install -y "
alias remove="sudo apt remove --purge -y "
alias omz="omz update"
alias nr="sudo systemctl restart NetworkManager"
alias z="source ~/.zshrc"

# --- Productivity ---
alias l="eza --color=always -la --git --icons=always --tree --level=1 --no-time --no-user"
alias ll="eza --color=always -la --git --icons=always --tree --level=2 --no-time --no-user"
alias lll="eza --color=always -la --git --icons=always --tree --level=3 --no-time --no-user"
alias gt="git clone"
alias msf="msfconsole"
alias bat="batcat"
alias thm="cd /home/kali/HTB/vpn/ && sudo openvpn thm.ovpn"
alias htb="cd /home/kali/HTB/vpn/ && sudo openvpn htb_labs.ovpn"
alias hs="cd /home/kali/HTB/vpn/ && sudo openvpn hs_lab.ovpn"
alias fd="fdfind"
alias f="fzf"
alias ff="fastfetch"
alias splunk="cd /opt/splunk/bin && sudo ./splunk start"
alias pserver="cd ~/tools/ && python3 -m http.server"
alias bhu="cd /home/kali/tools && sudo ./bloodhound-cli up"
alias bhd="cd /home/kali/tools && sudo ./bloodhound-cli down"
alias s="spf"
alias run="go run"

# Target IP :
target() {
    if [[ -z "$1" ]]; then
        echo "Usage: target <IP or domain>"
        return 1
    fi
    /usr/local/bin/target.sh "$1"
}

# ========================
# Completions & NVM
# ========================
autoload bashcompinit && bashcompinit
autoload -Uz compinit && compinit

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# -----------------------------
# Yazi Setup
# -----------------------------
export EDITOR="nvim"
export VISUAL="nvim"

function y() {
    local tmp="$(mktemp -t "yazi-cwd.XXXXXX")" cwd
    yazi "$@" --cwd-file="$tmp"
    if cwd="$(command bat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
        builtin cd -- "$cwd"
    fi
    rm -- "$tmp"
}

# -----------------------------
# Yazi Keybinding: alt+f
# -----------------------------

function _yazi_key() {
    zle -I
    y
}

zle -N yazi_key _yazi_key

bindkey '^[f' yazi_key


# -----------------------------
# fzf & fd Config
# -----------------------------
FD_EXCLUDES="--strip-cwd-prefix \
--exclude .git \
--exclude node_modules \
--exclude .idea \
--exclude .cargo \
--exclude .bash \
--exclude .cache \
--exclude .var \
--exclude .rustup \
--exclude .dotnet \
--exclude .claude \
--exclude .icons \
--exclude .gnupg"

export FZF_DEFAULT_COMMAND="fd --type=f $FD_EXCLUDES"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fd --type=d $FD_EXCLUDES"

# Dracula fzf theme
export FZF_DEFAULT_OPTS="
--ansi
--height=50%
--layout=reverse
--cycle
--border=rounded
--prompt='❯ '
--pointer='➤ '
--marker='✓ '
--preview-window=right,70%,border-left
--color=fg+:#50fa7b,bg+:-1,hl+:#50fa7b
--color=fg:#f8f8f2,bg:-1,hl:#bd93f9
--color=border:#6272a4,header:#8be9fd
--color=info:#ffb86c,prompt:#50fa7b
--color=pointer:#bd93f9,marker:#ff5555,spinner:#ffb86c
"

fzf() {
    local show_hidden=false
    local args=()
    while [[ $# -gt 0 ]]; do
        case $1 in
        -l) show_hidden=true; shift ;;
        *) args+=("$1"); shift ;;
        esac
    done

    if [[ "$show_hidden" == true ]]; then
        FZF_DEFAULT_COMMAND="fd --type=f --hidden $FD_EXCLUDES" command fzf "${args[@]}"
    else
        command fzf "${args[@]}"
    fi
}

_fzf_compgen_path() { fd --exclude .git . "$1"; }
_fzf_compgen_dir()  { fd --type=d --exclude .git . "$1"; }

show_file_or_dir_preview="if [ -d {} ]; then eza --icons --tree --color=always {} | head -200; else bat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --icons --tree --color=always {} | head -200'"

_fzf_comprun() {
    local command=$1; shift
    case "$command" in
        cd)           fzf --preview 'eza --icons --tree --color=always {} | head -200' "$@" ;;
        export|unset) fzf --preview "eval 'echo ${}'" "$@" ;;
        ssh)          fzf --preview 'dig {}' "$@" ;;
        *)            fzf --preview "$show_file_or_dir_preview" "$@" ;;
    esac
}

# ========================
# Themes and Paths
# ========================
export BAT_THEME=Dracula

# Homebrew setup
test -d ~/.linuxbrew && eval "$(~/.linuxbrew/bin/brew shellenv)"
test -d /home/linuxbrew/.linuxbrew && eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"

# Language Servers & Tools
export PATH="/home/kali/tools/lua-language-server/bin:$PATH"
export PATH="/opt/nvim-linux-x86_64/bin:$PATH"

# Go Setup
export PATH="/usr/local/go/bin:$PATH"
export GOPATH="$HOME/go"
export PATH="$PATH:$GOPATH/bin"

# Editor
export EDITOR="nvim"
export VISUAL="nvim"

# Cursor Fix
echo -ne "\e[5 q"

export PATH="$HOME/.cargo/bin:$PATH"
