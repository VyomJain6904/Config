# Dotfiles :

Personal dotfiles for Linux.

> A minimal, distraction-free setup built around terminal-first workflows.

[![Theme](https://img.shields.io/badge/Charcoal-1a1a1a?style=flat-square&labelColor=0d0d0d)](https://github.com/VyomJain6904/charcoal-theme)

---

## Theme :
Theme source: [VyomJain6904/charcoal-theme](https://github.com/VyomJain6904/charcoal-theme)

---

## What's Inside

| Tool | Description | Config Path |
|------|-------------|-------------|
| [Ghostty](https://ghostty.org) | GPU-accelerated terminal emulator | `ghostty/` |
| [Neovim](https://neovim.io) | Hyperextensible text editor | `nvim/` |
| [Yazi](https://yazi-rs.github.io) | Blazing fast terminal file manager | `yazi/` |
| [Bat](https://github.com/sharkdp/bat) | Cat clone with syntax highlighting | `bat/` |
| [OpenCode](https://opencode.ai) | AI coding agent (multi-agent setup) | `opencode/` |
| [Zsh](https://www.zsh.org) | Shell config (oh-my-zsh + starship) | `zsh/` |
| [i3](https://i3wm.org) | Tiling window manager | `i3/` |
| [Polybar](https://polybar.github.io) | Status bar | `polybar/` |
| [Rofi](https://github.com/davatorium/rofi) | Application launcher | `rofi/` |
| [Picom](https://github.com/yshui/picom) | Compositor | `picom/` |
| [Alacritty](https://alacritty.org) | Terminal emulator (secondary) | `alacritty/` |
| [Btop](https://github.com/aristocratos/btop) | System monitor | `btop/` |
| [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | System info | `fastfetch/` |
| [Terminator](https://gnome-terminator.org) | Terminal emulator (legacy) | `terminator/` |

---

## Structure

```
Config/
├── alacritty/          # Alacritty terminal config
├── bat/
│   ├── config          # --theme="Charcoal"
│   └── themes/
│       ├── Charcoal.tmTheme
│       └── Dracula.tmTheme
├── btop/               # Btop system monitor
├── fastfetch/          # System info display
├── ghostty/
│   ├── config          # Font, keybinds, theme
│   └── themes/
│       └── Charcoal    # Custom grayscale palette
├── i3/                 # i3wm config
├── nvim/
│   ├── init.lua        # Entry point
│   ├── stylua.toml     # Lua formatter config
│   ├── lazy-lock.json  # Plugin lockfile
│   └── lua/
│       ├── globals.lua
│       ├── options.lua
│       ├── keymaps.lua
│       ├── health.lua
│       ├── lazy-init.lua
│       ├── util/
│       └── plugins/
│           ├── coding/     # LSP, cmp, trouble
│           ├── dap/        # Debug adapter
│           ├── editor/     # Telescope, lualine, file-tree, yazi
│           ├── formatting/ # Conform, prettier
│           ├── languages/  # Go, Rust, Python, TS, Zig, etc.
│           ├── linting/    # Linting core
│           ├── test/       # Neotest
│           └── ui/         # Colorscheme, dashboard, indent
├── opencode/
│   ├── opencode.json   # Multi-agent config (6 agents + MCP)
│   ├── tui.json        # TUI theme selection
│   ├── themes/
│   │   └── charcoal.json
│   ├── skills/
│   │   └── graphify/   # Graph visualization skill
│   └── plugins/
│       └── superpowers.js
├── picom/              # Compositor config
├── polybar/            # Status bar (main + VM variant)
├── rofi/               # Launcher themes (spotlight, dmenu, powermenu)
├── terminator/         # Legacy terminal config
├── Wallpapers/         # Desktop wallpapers collection
└── zsh/
    └── arch.zshrc      # Zsh config (oh-my-zsh + starship + zoxide)
```

---

## Dependencies and Installation

### Terminal and Shell

| Package | Arch Linux | Debian/Ubuntu |
|---------|-----------|---------------|
| Zsh | `sudo pacman -S zsh` | `sudo apt install zsh` |
| Starship | `sudo pacman -S starship` | `curl -sS https://starship.rs/install.sh \| sh` |
| Zoxide | `sudo pacman -S zoxide` | `sudo apt install zoxide` |
| Ghostty | `yay -S ghostty` | Build from source: [ghostty.org](https://ghostty.org) |
| Alacritty | `sudo pacman -S alacritty` | `sudo apt install alacritty` |
| Terminator | `sudo pacman -S terminator` | `sudo apt install terminator` |

### Editor

| Package | Arch Linux | Debian/Ubuntu |
|---------|-----------|---------------|
| Neovim (>= 0.12) | `sudo pacman -S neovim` | Download from [github.com/neovim/neovim/releases](https://github.com/neovim/neovim/releases) |
| Lazygit | `sudo pacman -S lazygit` | `go install github.com/jesseduffield/lazygit@latest` |
| Stylua | `sudo pacman -S stylua` | `cargo install stylua` |

### File Manager (Yazi)

| Package | Arch Linux | Debian/Ubuntu |
|---------|-----------|---------------|
| Yazi | `sudo pacman -S yazi` | Download from [github.com/sxyazi/yazi/releases](https://github.com/sxyazi/yazi/releases) |
| ffmpeg | `sudo pacman -S ffmpeg` | `sudo apt install ffmpeg` |
| p7zip | `sudo pacman -S p7zip` | `sudo apt install p7zip-full` |
| jq | `sudo pacman -S jq` | `sudo apt install jq` |
| poppler | `sudo pacman -S poppler` | `sudo apt install poppler-utils` |
| fd | `sudo pacman -S fd` | `sudo apt install fd-find` |
| ripgrep | `sudo pacman -S ripgrep` | `sudo apt install ripgrep` |
| fzf | `sudo pacman -S fzf` | `sudo apt install fzf` |
| glow | `sudo pacman -S glow` | `go install github.com/charmbracelet/glow@latest` |

### Utilities

| Package | Arch Linux | Debian/Ubuntu |
|---------|-----------|---------------|
| Bat | `sudo pacman -S bat` | `sudo apt install bat` |
| Fastfetch | `sudo pacman -S fastfetch` | `sudo apt install fastfetch` |
| Btop | `sudo pacman -S btop` | `sudo apt install btop` |

### Desktop (i3 setup)

| Package | Arch Linux | Debian/Ubuntu |
|---------|-----------|---------------|
| i3 | `sudo pacman -S i3-wm` | `sudo apt install i3` |
| Polybar | `sudo pacman -S polybar` | `sudo apt install polybar` |
| Rofi | `sudo pacman -S rofi` | `sudo apt install rofi` |
| Picom | `sudo pacman -S picom` | `sudo apt install picom` |
| Feh | `sudo pacman -S feh` | `sudo apt install feh` |
| Dunst | `sudo pacman -S dunst` | `sudo apt install dunst` |

### AI Coding

| Package | Arch Linux | Debian/Ubuntu |
|---------|-----------|---------------|
| OpenCode | `bun install -g opencode` | `bun install -g opencode` |

---

## Oh-My-Zsh Setup

### Install Oh-My-Zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Install Plugins

These plugins need to be cloned into `~/.oh-my-zsh/custom/plugins/`:

| Plugin | Repository | Install |
|--------|-----------|---------|
| zsh-autosuggestions | [github.com/zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) | `git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions` |
| zsh-syntax-highlighting | [github.com/zsh-users/zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting) | `git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting` |
| zsh-completions | [github.com/zsh-users/zsh-completions](https://github.com/zsh-users/zsh-completions) | `git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions` |
| zsh-history-substring-search | [github.com/zsh-users/zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) | `git clone https://github.com/zsh-users/zsh-history-substring-search ~/.oh-my-zsh/custom/plugins/zsh-history-substring-search` |
| zsh-defer | [github.com/romkatv/zsh-defer](https://github.com/romkatv/zsh-defer) | `git clone https://github.com/romkatv/zsh-defer ~/.oh-my-zsh/plugins/zsh-defer` |

The following plugins are built-in to oh-my-zsh (no install needed): `ssh`, `git`, `sublime`, `fzf`, `zsh-interactive-cd`

---

## Setup

### 1. Clone

```bash
git clone https://github.com/VyomJain6904/Config.git ~/Study/Config
```

### 2. Symlink Configs

```bash
# Ghostty
ln -sf ~/Study/Config/ghostty ~/.config/ghostty

# Neovim
ln -sf ~/Study/Config/nvim ~/.config/nvim

# Yazi
ln -sf ~/Study/Config/yazi ~/.config/yazi

# Bat
ln -sf ~/Study/Config/bat ~/.config/bat

# OpenCode
mkdir -p ~/.config/opencode/skills
ln -sf ~/Study/Config/opencode/opencode.json ~/.config/opencode/opencode.json
ln -sf ~/Study/Config/opencode/tui.json ~/.config/opencode/tui.json
ln -sf ~/Study/Config/opencode/themes ~/.config/opencode/themes
ln -sf ~/Study/Config/opencode/plugins ~/.config/opencode/plugins
ln -sf ~/Study/Config/opencode/skills/graphify ~/.config/opencode/skills/graphify

# Zsh
ln -sf ~/Study/Config/zsh/arch.zshrc ~/.zshrc

# i3
ln -sf ~/Study/Config/i3 ~/.config/i3

# Polybar
ln -sf ~/Study/Config/polybar/polybar ~/.config/polybar

# Rofi
ln -sf ~/Study/Config/rofi ~/.config/rofi

# Picom
ln -sf ~/Study/Config/picom ~/.config/picom

# Btop
ln -sf ~/Study/Config/btop ~/.config/btop

# Fastfetch
ln -sf ~/Study/Config/fastfetch ~/.config/fastfetch
```

### 3. Post-Install

```bash
# Rebuild bat cache (for custom themes)
bat cache --build

# Install yazi plugins
cd ~/.config/yazi && ya pack -i

# Install neovim plugins (auto on first launch)
nvim --headless "+Lazy! sync" +qa
```

---

## Highlights

- Multi-agent AI — OpenCode configured with 6 specialized agents (builder, PM, tech-lead, backend-dev, reviewer, security researcher)
- Neovim IDE — full LSP, DAP, formatting, linting, telescope, and language support for Go, Rust, Python, TypeScript, Zig
- Yazi power user — custom keybinds, git integration, piper previews (glow for markdown, jq for JSON)
- Zsh productivity — starship prompt, zoxide smart cd, fzf fuzzy finding, autosuggestions

---

## License

Personal dotfiles. Use freely, attribution appreciated.
