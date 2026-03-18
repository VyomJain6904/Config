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

# -----------------------------
# Github Workflow with fzf
# -----------------------------
function gt() {
    # Colors
    local RED=$'\033[1;31m'
    local GREEN=$'\033[1;32m'
    local YELLOW=$'\033[1;33m'
    local BLUE=$'\033[1;34m'
    local CYAN=$'\033[1;36m'
    local MAGENTA=$'\033[1;35m'
    local RESET=$'\033[0m'

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "  ${RED}  Not in a Git repository!${RESET}"
        return 1
    fi

    local exit_requested=false

    while [[ "$exit_requested" == false ]]; do
        local options=(
            "${BLUE}  Git Status${RESET}"
            "${YELLOW}  Git Add${RESET}"
            "${GREEN}  Git Commit${RESET}"
            "${MAGENTA}  Git Push${RESET}"
            "${CYAN}  Recent Commits${RESET}"
            "${RED}󰩈  Exit${RESET}"
        )

        local choice=$(printf "%s\n" "${options[@]}" \
            | command fzf \
            --ansi \
            --prompt=" ${CYAN}Git › ${RESET}" \
            --header="${MAGENTA}Repository: $(basename "$(git rev-parse --show-toplevel 2>/dev/null)")${RESET}" \
            --border=rounded \
            --height=40% \
            --reverse \
            --cycle \
        --bind='ctrl-c:abort,esc:abort')

        if [[ $? -ne 0 ]] || [[ -z "$choice" ]]; then
            echo -e "\n  ${YELLOW}󰩈  Exited.${RESET}"
            break
        fi

        case $choice in
            *"Git Status"*)
                echo -e "${BLUE}  Repository Status:${RESET}"
                git status
            ;;
            *"Git Add"*)
                git add .
                echo -e "  ${GREEN}  Files staged.${RESET}"
            ;;
            *"Git Commit"*)
                if git diff --cached --quiet 2>/dev/null; then
                    echo -e "  ${YELLOW}  No staged changes.${RESET}"
                else
                    echo -ne "${CYAN}  Commit message:${RESET} "
                    read msg
                    if [[ -n "$msg" ]]; then
                        git commit -m "$msg"
                        echo -e "  ${GREEN}  Commit created.${RESET}"
                    else
                        echo -e "  ${RED}  Commit message cannot be empty.${RESET}"
                    fi
                fi
            ;;
            *"Git Push"*)
                local current_branch=$(git branch --show-current 2>/dev/null)
                echo -e "${BLUE}  Pushing branch: ${MAGENTA}${current_branch}${RESET}"
                if git push 2>/dev/null; then
                    echo -e "  ${GREEN}  Push successful.${RESET}"
                else
                    git push -u origin "$current_branch"
                    [[ $? -eq 0 ]] && echo -e "  ${GREEN}  Push successful.${RESET}" \
                    || echo -e "  ${RED}  Push failed.${RESET}"
                fi
            ;;
            *"Recent Commits"*)
                echo -e "${BLUE}  Last 10 commits :${RESET}"
                total=$(git rev-list --count HEAD)
                start=$((total-4))  # first number for the last 5 commits
                git log -n 10 --pretty=format:"%s" --reverse \
                | awk -v start="$start" '{print start++ ". " $0}'
            ;;
            *"Exit"*)
                echo -e "  ${GREEN}󰩈  Exiting Github Workflow.${RESET}"
                exit_requested=true
            ;;
        esac

        if [[ "$exit_requested" == false ]]; then
            echo ""
            echo -e "${CYAN}⏎ Press Enter to continue...${RESET}"
            read
            clear
        fi
    done
}


PROMPT='[%F{#FF79C6} %c%f] ➤ '

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
alias l="eza --color=always -l --git --icons=always --tree --level=1 --no-time --no-user"
alias ll="eza --color=always -la --git --icons=always --tree --level=2 --no-time --no-user"
alias lll="eza --color=always -la --git --icons=always --tree --level=3 --no-time --no-user"
alias gt="git clone"
alias msf="msfconsole"
alias cat="batcat"
alias fd="fdfind"
alias f="fzf"
alias ff="fastfetch"
alias pserver="cd ~/tools/ && python3 -m http.server"
alias bhu="cd /home/kali/tools && sudo ./bloodhound-cli up"
alias bhd="cd /home/kali/tools && sudo ./bloodhound-cli down"
alias s="yazi"

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
    if cwd="$(command cat -- "$tmp")" && [ -n "$cwd" ] && [ "$cwd" != "$PWD" ]; then
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

show_file_or_dir_preview="if [ -d {} ]; then eza --icons --tree --color=always {} | head -200; else cat -n --color=always --line-range :500 {}; fi"

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
