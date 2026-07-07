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


# -----------------------------
# Function for Git Branch
# -----------------------------
git_branch() {
    local branch
    branch=$(git symbolic-ref --quiet --short HEAD 2>/dev/null || git describe --tags --always 2>/dev/null)
    [[ -n $branch ]] && echo "[%F{#9ece6a}  $branch%f]"
}


# -----------------------------
# Github Workflow with fzf
# -----------------------------
function gt() {
    # Colors (Dracula)
    local RED=$'\033[38;5;203m'
    local GREEN=$'\033[38;5;114m'
    local YELLOW=$'\033[38;5;228m'
    local BLUE=$'\033[38;5;141m'
    local CYAN=$'\033[38;5;117m'
    local MAGENTA=$'\033[38;5;212m'
    local RESET=$'\033[0m'

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "  ${RED}  Not in a Git repository!${RESET}"
        return 1
    fi

    local exit_requested=false

    while [[ "$exit_requested" == false ]]; do
        local options=(
            "${BLUE}  Git Status${RESET}"
            "${YELLOW}  Git Add${RESET}"
            "${GREEN}  Git Commit${RESET}"
            "${MAGENTA}  Git Push${RESET}"
            "${CYAN}  Recent Commits${RESET}"
            "${RED}󰩈  Exit${RESET}"
        )

        local choice=$(printf "%s\n" "${options[@]}" \
            | command fzf \
            --ansi \
            --prompt=" ${CYAN}Git › ${RESET}" \
            --header="${MAGENTA}Repository: $(basename "$(git rev-parse --show-toplevel 2>/dev/null)")${RESET}" \
            --border=rounded \
            --height=50% \
            --reverse \
            --cycle \
        --bind='ctrl-c:abort,esc:abort')

        if [[ $? -ne 0 ]] || [[ -z "$choice" ]]; then
            echo -e "\n  ${YELLOW}󰩈  Exited.${RESET}"
            break
        fi

        case $choice in
            *"Git Status"*)
                echo -e "${BLUE}  Repository Status:${RESET}"
                git status
            ;;
            *"Git Add"*)
                git add .
                echo -e "  ${GREEN}  Files staged.${RESET}"
            ;;
            *"Git Commit"*)
                if git diff --cached --quiet 2>/dev/null; then
                    echo -e "  ${YELLOW}  No staged changes.${RESET}"
                else
                    echo -e "${CYAN}  Commit message:${RESET}"
                    msg=""
                    vared -p "  > " msg
                    if [[ -n "$msg" ]]; then
                        git commit -m "$msg"
                        echo -e "  ${GREEN}  Commit created.${RESET}"
                    else
                        echo -e "  ${RED}  Commit message cannot be empty.${RESET}"
                    fi
                fi
            ;;
            *"Git Push"*)
                local current_branch=$(git branch --show-current 2>/dev/null)
                echo -e "${BLUE}  Pushing branch: ${MAGENTA}${current_branch}${RESET}"
                if git push 2>/dev/null; then
                    echo -e "  ${GREEN}  Push successful.${RESET}"
                else
                    git push -u origin "$current_branch"
                    [[ $? -eq 0 ]] && echo -e "  ${GREEN}  Push successful.${RESET}" \
                    || echo -e "  ${RED}  Push failed.${RESET}"
                fi
            ;;
            *"Recent Commits"*)
                echo -e "${BLUE}  Last 10 commits :${RESET}"
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


# -----------------------------
# Prompt
# -----------------------------
PROMPT='[%F{#FF79C6}󰣛%f  %F{#7aaaf7}%~%f] $(git_branch)%F{#565f89}➤%f '


# -----------------------------
# Aliases
# -----------------------------

# System
alias cls="clear"
alias cl="clear"
alias upd="sudo dnf upgrade --refresh -y"
alias rmf="sudo rm -rf"
alias remove="sudo dnf remove -y"
alias cln='sudo dnf autoremove -y && sudo dnf clean all'
alias ins="sudo dnf install -y"
alias omz="omz update"
alias exir="exit"
alias mk="mkdir"
alias nr="sudo systemctl restart NetworkManager"
alias ff="fastfetch"
alias zsrc="source ~/.zshrc"
alias btop="btop --force-utf"
alias z="zoxide"
alias cdc="cd -"

# Files
alias l="eza -l --group-directories-first --icons --git --color=always --level=1 --no-time --no-user --tree"
alias ll="eza -la --group-directories-first --icons --git --color=always --level=2 --no-time --no-user --tree"
alias lll="eza -la --group-directories-first --icons --git --color=always --level=3 --no-time --no-user --tree"
alias llll="eza -la --icons --group-directories-first --git --color=always --level=4 --no-time --no-user --tree"
alias lllll="eza -la --icons --group-directories-first --git --color=always --level=5 --no-time --no-user --tree"
alias cat="bat -pp"
alias s="yazi"
alias cargoi="cargo-seek"

# Dev
alias start="npm run dev"
alias bstart="bun run dev"
alias cn="cargo new"
alias cr="cargo run"
alias ca="cargo add"
alias gc="git clone"
alias gs="git status"
alias gr="git remote set-url origin "
alias ga="git add ."
alias gp="git push -u origin main"
alias pserver="python3 -m http.server 80"
alias doc="sudo docker"

# -----------------------------
# Auto-suggestions
# -----------------------------
if [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    . /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
    ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#a6adc8'
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
export FZF_DEFAULT_OPTS="
--ansi
--height=75%
--layout=reverse
--cycle
--border=rounded
--prompt='❯ '
--pointer='➤ '
--marker='✓ '
--preview-window=right,70%,border-left
--color=fg:#f8f8f2,bg:-1,hl:#bd93f9
--color=fg+:#f8f8f2,bg+:#44475a,hl+:#ff79c6
--color=border:#6272a4,header:#bd93f9
--color=info:#6272a4,prompt:#bd93f9
--color=pointer:#ff79c6,marker:#50fa7b,spinner:#ffb86c
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
export BAT_THEME="Dracula"


export LANG=en_IN.UTF-8
export LC_ALL=en_IN.UTF-8
