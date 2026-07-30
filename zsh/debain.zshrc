# =============================================================================
# Oh My Zsh & Base Setup
# =============================================================================
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="apple"

# =============================================================================
# Prompt & Navigation
# =============================================================================
eval "$(zoxide init zsh --cmd cd)"

# =============================================================================
# Plugins
# =============================================================================
plugins=(
    ssh
    git
    sublime
    fzf
    fzf-tab
    zsh-autosuggestions
    zsh-syntax-highlighting
    zsh-completions
    zsh-history-substring-search
)

source $ZSH/oh-my-zsh.sh

PROMPT='[%F{#9dec02}  %~%f] ➤ '

# =============================================================================
# fzf-tab Configuration
# =============================================================================
# Disable default completion menu so fzf-tab can intercept
zstyle ':completion:*' menu no
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# Preview directory contents when completing cd
zstyle ':fzf-tab:complete:cd:*' fzf-preview \
    'eza -1 --color=always --icons=always --group-directories-first "$realpath"'

# fzf-tab appearance
zstyle ':fzf-tab:complete:cd:*' fzf-flags \
    --height=70% --layout=reverse --border=rounded --cycle \
    --prompt='❯ ' --pointer='➤ '

# Use global fzf theme (FZF_DEFAULT_OPTS)
zstyle ':fzf-tab:*' use-fzf-default-opts yes
# Switch between groups with < and >
zstyle ':fzf-tab:*' switch-group '<' '>'

# =============================================================================
# fzf & fd Configuration
# =============================================================================
# Directories to exclude from fd/fzf searches
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

# Default commands for fzf (files, Ctrl+T, Alt+C)
export FZF_DEFAULT_COMMAND="fdfind --type=f $FD_EXCLUDES"
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_ALT_C_COMMAND="fdfind --type=d $FD_EXCLUDES"

# Dracula theme for fzf
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

# Completion generators for fzf
_fzf_compgen_path() { fd --exclude .git . "$1"; }
_fzf_compgen_dir()  { fd --type=d --exclude .git . "$1"; }

# Preview command: show directory tree or file contents
show_file_or_dir_preview="if [ -d {} ]; then eza --icons --tree --color=always {} | head -200; else cat -n --color=always --line-range :500 {}; fi"

export FZF_CTRL_T_OPTS="--preview '$show_file_or_dir_preview'"
export FZF_ALT_C_OPTS="--preview 'eza --icons --tree --color=always {} | head -200'"

# Case-insensitive matching
zstyle ':completion:' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]= r:|=' 'l:|= r:|='

# Characters treated as part of a word
WORDCHARS='?[]~=&;!#$%^(){}<>'

# =============================================================================
# Zsh-Deferred Plugins (loaded async for faster startup)
# =============================================================================
source ~/.oh-my-zsh/plugins/zsh-defer/zsh-defer.plugin.zsh
zsh-defer source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
zsh-defer source /usr/share/zsh-history-substring-search/zsh-history-substring-search.zsh

# =============================================================================
# Completions & NVM
# =============================================================================
autoload bashcompinit && bashcompinit

export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh"
[ -s "$NVM_DIR/bash_completion" ] && . "$NVM_DIR/bash_completion"

# =============================================================================
# Functions
# =============================================================================

# Git workflow menu (fzf-powered)
gt() {
    local RED=$'\033[1;31m'
    local GREEN=$'\033[1;32m'
    local YELLOW=$'\033[1;33m'
    local BLUE=$'\033[1;34m'
    local CYAN=$'\033[1;36m'
    local MAGENTA=$'\033[1;35m'
    local RESET=$'\033[0m'

    if ! git rev-parse --is-inside-work-tree >/dev/null 2>&1; then
        echo -e "  ${RED}Not in a Git repository!${RESET}"
        return 1
    fi

    local exit_requested=false

    while [[ "$exit_requested" == false ]]; do
        local options=(
            "${BLUE} Git Status${RESET}"
            "${YELLOW} Git Add${RESET}"
            "${GREEN} Git Commit${RESET}"
            "${MAGENTA} Git Push${RESET}"
            "${CYAN} Recent Commits${RESET}"
            "${RED} Exit${RESET}"
        )

        local choice=$(printf "%s\n" "${options[@]}" \
            | command fzf \
            --ansi \
            --prompt=" ${CYAN}Git > ${RESET}" \
            --header="${MAGENTA}Repository: $(basename "$(git rev-parse --show-toplevel 2>/dev/null)")${RESET}" \
            --border=rounded \
            --height=40% \
            --reverse \
            --cycle \
            --bind='ctrl-c:abort,esc:abort')

        if [[ $? -ne 0 ]] || [[ -z "$choice" ]]; then
            echo -e "\n  ${YELLOW}Exited.${RESET}"
            break
        fi

        case $choice in
            *"Git Status"*)
                echo -e "${BLUE}Repository Status:${RESET}"
                git status
                ;;
            *"Git Add"*)
                git add .
                echo -e "  ${GREEN}Files staged.${RESET}"
                ;;
            *"Git Commit"*)
                if git diff --cached --quiet 2>/dev/null; then
                    echo -e "  ${YELLOW}No staged changes.${RESET}"
                else
                    echo -ne "${CYAN}Commit message:${RESET} "
                    read msg
                    if [[ -n "$msg" ]]; then
                        git commit -m "$msg"
                        echo -e "  ${GREEN}Commit created.${RESET}"
                    else
                        echo -e "  ${RED}Commit message cannot be empty.${RESET}"
                    fi
                fi
                ;;
            *"Git Push"*)
                local current_branch=$(git branch --show-current 2>/dev/null)
                echo -e "${BLUE}Pushing branch: ${MAGENTA}${current_branch}${RESET}"
                if git push 2>/dev/null; then
                    echo -e "  ${GREEN}Push successful.${RESET}"
                else
                    git push -u origin "$current_branch"
                    [[ $? -eq 0 ]] && echo -e "  ${GREEN}Push successful.${RESET}" \
                    || echo -e "  ${RED}Push failed.${RESET}"
                fi
                ;;
            *"Recent Commits"*)
                echo -e "${BLUE}Last 10 commits:${RESET}"
                total=$(git rev-list --count HEAD)
                start=$((total-9))
                git log -n 10 --pretty=format:"%s" --reverse \
                    | awk -v start="$start" '{print start++ ". " $0}'
                ;;
            *"Exit"*)
                echo -e "  ${GREEN}Exiting Github Workflow.${RESET}"
                exit_requested=true
                ;;
        esac

        if [[ "$exit_requested" == false ]]; then
            echo ""
            echo -e "${CYAN}Press Enter to continue...${RESET}"
            read
            clear
        fi
    done
}

# =============================================================================
# Aliases - System
# =============================================================================
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
alias s="yazi"
alias cdc="cd -"
alias ipa="ip -br -c a"

# =============================================================================
# Aliases - Productivity
# =============================================================================
alias l="eza --color=always -l --git --icons=always --tree --level=1 --no-time --no-user --group-directories-first"
alias ll="eza --color=always -la --git --icons=always --tree --level=2 --no-time --no-user --group-directories-first"
alias lll="eza --color=always -la --git --icons=always --tree --level=3 --no-time --no-user --group-directories-first"
alias llll="eza --color=always -la --git --icons=always --tree --level=4 --no-time --no-user --group-directories-first"
alias lllll="eza --color=always -la --git --icons=always --tree --level=5 --no-time --no-user --group-directories-first"
alias llllll="eza --color=always -la --git --icons=always --tree --level=6 --no-time --no-user --group-directories-first"
alias cat="batcat -pp"
alias fd="fdfind"
alias f="fzf"
alias ff="fastfetch"
alias pserver="cd /opt/tools/ && python3 -m http.server 8080"
alias btop="btop"
alias b="btop"

# =============================================================================
# Environment Variables
# =============================================================================
export BAT_THEME=Dracula
export EDITOR="nvim"
export VISUAL="nvim"

# Ollama
export OLLAMA_MAX_LOADED_MODELS=1
export OLLAMA_NUM_PARALLEL=1
export OLLAMA_FLASH_ATTENTION=1

# =============================================================================
# PATH & Tool Setup (consolidated)
# =============================================================================
# Bun
export BUN_INSTALL="$HOME/.bun"

# Mise (runtime version manager) - adds its own shims to PATH
eval "$($HOME/.local/bin/mise activate zsh)"

# pnpm
export PNPM_HOME="/home/jain/.local/share/pnpm"
case ":$PATH:" in
    *":$PNPM_HOME/bin:"*) ;;
    *) export PATH="$PNPM_HOME/bin:$PATH" ;;
esac

# Pipx
export PIPX_HOME="/opt/tools/src/pipx"
export PIPX_BIN_DIR="/opt/tools"

# All paths: Bun, user binaries, mise shims, pentesting tools
export PATH="$BUN_INSTALL/bin:$HOME/.local/bin:$HOME/.local/share/mise/shims:/opt/tools:$PATH"
