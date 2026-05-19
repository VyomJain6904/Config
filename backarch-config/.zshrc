# -----------------------------
# Oh-My-Zsh Config
# -----------------------------
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="apple"

eval "$(starship init zsh)"
eval "$(zoxide init zsh --cmd cd)"

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


target() {
    if [[ -z "$1" ]]; then
        echo "Usage: target <IP or domain>"
        return 1
    fi
    ~/.local/bin/target "$1"
}


# -----------------------------
# Prompt
# -----------------------------
PROMPT='[%F{#FF79C6}󰨡 %~%f] ➤ '


# -----------------------------
# Aliases
# -----------------------------

# System
alias cls="clear"
alias cl="clear"
alias upd="sudo pacman -Syu"
alias updapp="yay -Syu"
alias rmf="sudo rm -rf"
alias remove="sudo pacman -Rns"
alias cln='sudo pacman -Rns $(pacman -Qdtq) && sudo pacman -Sc'
alias ins="sudo pacman -S"
alias omz="omz update"
alias exir="exit"
alias mk="mkdir"
alias nr="sudo systemctl restart NetworkManager.service"
alias ff="fastfetch"
alias zsrc="source ~/.zshrc"
alias btop="btop --force-utf"
alias z="zoxide"
alias cdc="cd -"
alias ssn="sudo shutdown now"
alias n="nvim ."

# Files
alias l="eza -l --icons --git --color=always --level=1 --no-time --no-user --tree"
alias ll="eza -la --icons --git --color=always --level=2 --no-time --no-user --tree"
alias lll="eza -la --icons --git --color=always --level=3 --no-time --no-user --tree"
alias llll="eza -la --icons --git --color=always --level=4 --no-time --no-user --tree"
alias cat="bat -pp"
alias s="yazi"
alias cargoi="cargo-seek"
alias mkp="mkdir enu loot files exploit flags screenshots"

# Dev
alias start="npm run dev"
alias cn="cargo new"
alias cr="cargo run"
alias ca="cargo add"
alias pserver="python3 -m http.server 80"
alias doc="sudo docker"
alias bhu="cd ~/tools/ad/ && ./bloodhound-cli up"
alias bhd="cd ~/tools/ad/ && ./bloodhound.cli down"
alias hs="cd ~/vpn && sudo openvpn hs.ovpn"
alias ct='rm -f ~/.cache/target_ip'

# -----------------------------
# Auto-suggestions
# -----------------------------
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    . /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#6272a4'
fi


# -----------------------------
# Go Config
# -----------------------------
export GOPATH=$HOME/go
export PATH="$HOME/go/bin:/usr/lib/go/bin:$PNPM_HOME:$PATH"


# -----------------------------
# NVM Config
# -----------------------------
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"


# -----------------------------
# pnpm Config
# -----------------------------
export PNPM_HOME="$HOME/.local/share/pnpm"
case ":$PATH:" in
    *":$PNPM_HOME:"*) ;;
    *) export PATH="$PNPM_HOME:$PATH" ;;
esac


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


# -----------------------------
# Bat Theme
# -----------------------------
export BAT_THEME=Dracula
export PATH=$PATH:/usr/local/go/bin
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
