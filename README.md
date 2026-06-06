# Dotfiles :

Personal dotfiles for Linux.

> A minimal, distraction-free setup built around terminal-first workflows.

[![Theme](https://img.shields.io/badge/Charcoal-1a1a1a?style=flat-square&labelColor=0d0d0d)](https://github.com/VyomJain6904/charcoal-theme)

---

## Theme :

Theme source: [VyomJain6904/charcoal-theme](https://github.com/VyomJain6904/charcoal-theme)

---

## Wallpapers :

Wallaper Source : [VyomJain6904/Wallpapers](https://github.com/VyomJain6904/Config/blob/main/Wallpapers/README.md)

## What's Inside

| Tool                                                    | Description                         | Config Path   |
| ------------------------------------------------------- | ----------------------------------- | ------------- |
| [Alacritty](https://alacritty.org)                      | Terminal emulator (secondary)       | `alacritty/`  |
| [Bat](https://github.com/sharkdp/bat)                   | Cat clone with syntax highlighting  | `bat/`        |
| [Btop](https://github.com/aristocratos/btop)            | System monitor                      | `btop/`       |
| [Eza](https://eza.rocks)                                | Modern `ls` replacement             | `eza/`        |
| [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | System info                         | `fastfetch/`  |
| [Ghostty](https://ghostty.org)                          | GPU-accelerated terminal emulator   | `ghostty/`    |
| [Hyprland](https://hyprland.org)                        | Wayland compositor                  | `hypr/`       |
| [i3](https://i3wm.org)                                  | Tiling window manager (X11)         | `i3/`         |
| [Kvantum](https://github.com/tsujan/Kvantum)            | Qt theme engine                     | `Kvantum/`    |
| [Neovim](https://neovim.io)                             | Hyperextensible text editor         | `nvim/`       |
| [OpenCode](https://opencode.ai)                         | AI coding agent (multi-agent setup) | `opencode/`   |
| [Picom](https://github.com/yshui/picom)                 | Compositor                          | `picom/`      |
| [Polybar](https://polybar.github.io)                    | Status bar                          | `polybar/`    |
| [Qt6ct](https://github.com/trialuser02/qt6ct)           | Qt6 appearance config               | `qt6ct/`      |
| [Rofi](https://github.com/davatorium/rofi)              | Application launcher                | `rofi/`       |
| [Terminator](https://gnome-terminator.org)              | Terminal emulator (legacy)          | `terminator/` |
| [Waybar](https://github.com/Alexays/Waybar)             | Wayland status bar                  | `waybar/`     |
| [Yazi](https://yazi-rs.github.io)                       | Blazing fast terminal file manager  | `yazi/`       |
| [Zsh](https://www.zsh.org)                              | Shell config (oh-my-zsh + starship) | `zsh/`        |

---

## Structure

```
Config/
├── alacritty/
│   └── alacritty.toml              # Secondary terminal (Dracula theme)
├── bat/
│   ├── config                      # Bat config (Charcoal theme)
│   └── themes/
│       ├── Charcoal.tmTheme
│       └── Dracula.tmTheme
├── btop/
│   └── btop.conf                   # System monitor (Tokyo Night)
├── eza/
│   └── theme.yml                   # Modern ls theme (Tokyo Night)
├── fastfetch/
│   ├── config.jsonc                # System info display
│   └── asci.txt                    # Custom ASCII logo
├── ghostty/
│   ├── config                      # Primary terminal (font, keybinds, theme)
│   └── themes/
│       ├── Charcoal
│       └── tokyonight.toml
├── hypr/
│   ├── hyprland.lua                # Wayland compositor entry point
│   ├── modules/
│   │   ├── monitors.lua
│   │   ├── keybinds.lua
│   │   ├── autostart.lua
│   │   ├── design.lua
│   │   ├── env.lua
│   │   ├── layout.lua
│   │   ├── input.lua
│   │   ├── misc.lua
│   │   └── windowrules.lua
│   └── walls/                      # Desktop wallpapers
├── i3/
│   └── config                      # X11 tiling WM config
├── Kvantum/
│   ├── kvantum.kvconfig            # Qt theme engine
│   └── Kvantum-Tokyo-Night/        # Tokyo Night SVG theme
├── nvim/
│   ├── init.lua                    # Entry point
│   ├── stylua.toml                 # Lua formatter config
│   ├── lazy-lock.json              # Plugin lockfile
│   └── lua/
│       ├── globals.lua
│       ├── options.lua
│       ├── keymaps.lua
│       ├── health.lua
│       ├── lazy-init.lua
│       ├── util/
│       └── plugins/
│           ├── coding/             # LSP, cmp, trouble
│           ├── dap/                # Debug adapter
│           ├── editor/             # Telescope, lualine, file-tree, yazi
│           ├── formatting/         # Conform, prettier
│           ├── languages/          # Go, Rust, Python, TS, Zig, etc.
│           ├── linting/            # Linting core
│           ├── test/               # Neotest
│           └── ui/                 # Colorscheme, dashboard, indent
├── opencode/
│   ├── opencode.json               # Multi-agent AI config (6 agents + MCP)
│   ├── tui.json                    # TUI theme selection
│   ├── themes/
│   │   └── charcoal.json
│   ├── skills/
│   │   └── graphify/               # Graph visualization skill
│   └── plugins/
│       └── superpowers.js
├── picom/
│   └── picom.conf                  # X11 compositor
├── polybar/
│   ├── polybar/                    # Main i3 status bar + control center
│   └── polybar-vm/                 # VM variant (VPN/IP monitoring)
├── qt6ct/
│   ├── qt6ct.conf                  # Qt6 appearance (Fusion + WhiteSur)
│   └── style-colors.conf
├── rofi/
│   ├── main.rasi                   # Spotlight-style launcher
│   ├── dmenu.rasi                  # Top-panel dmenu mode
│   ├── powermenu.rasi              # Power menu
│   └── spotlight.rasi              # macOS-style launcher
├── terminator/
│   └── config                      # Legacy terminal (Dracula)
├── Wallpapers/                     # Desktop wallpapers collection
├── waybar/
│   ├── config.jsonc                # Wayland status bar
│   ├── style.css
│   ├── colors/
│   └── scripts/
├── yazi/
│   ├── yazi.toml                   # Terminal file manager
│   ├── keymap.toml
│   ├── theme.toml
│   ├── init.lua
│   └── flavors/
│       └── charcoal.yazi/
└── zsh/
    ├── .zshrc                      # Shell config (starship + zoxide)
    └── arch.zshrc                  # Arch Linux variant
```

---

## Dependencies and Installation

### Terminal and Shell

| Package    | Arch Linux                  | Debian/Ubuntu                                         |
| ---------- | --------------------------- | ----------------------------------------------------- |
| Zsh        | `sudo pacman -S zsh`        | `sudo apt install zsh`                                |
| Starship   | `sudo pacman -S starship`   | `curl -sS https://starship.rs/install.sh \| sh`       |
| Zoxide     | `sudo pacman -S zoxide`     | `sudo apt install zoxide`                             |
| Ghostty    | `yay -S ghostty`            | Build from source: [ghostty.org](https://ghostty.org) |
| Alacritty  | `sudo pacman -S alacritty`  | `sudo apt install alacritty`                          |
| Terminator | `sudo pacman -S terminator` | `sudo apt install terminator`                         |

### Editor

| Package          | Arch Linux               | Debian/Ubuntu                                                                                |
| ---------------- | ------------------------ | -------------------------------------------------------------------------------------------- |
| Neovim (>= 0.12) | `sudo pacman -S neovim`  | Download from [github.com/neovim/neovim/releases](https://github.com/neovim/neovim/releases) |
| Lazygit          | `sudo pacman -S lazygit` | `go install github.com/jesseduffield/lazygit@latest`                                         |
| Stylua           | `sudo pacman -S stylua`  | `cargo install stylua`                                                                       |

### File Manager (Yazi)

| Package | Arch Linux               | Debian/Ubuntu                                                                            |
| ------- | ------------------------ | ---------------------------------------------------------------------------------------- |
| Yazi    | `sudo pacman -S yazi`    | Download from [github.com/sxyazi/yazi/releases](https://github.com/sxyazi/yazi/releases) |
| ffmpeg  | `sudo pacman -S ffmpeg`  | `sudo apt install ffmpeg`                                                                |
| p7zip   | `sudo pacman -S p7zip`   | `sudo apt install p7zip-full`                                                            |
| jq      | `sudo pacman -S jq`      | `sudo apt install jq`                                                                    |
| poppler | `sudo pacman -S poppler` | `sudo apt install poppler-utils`                                                         |
| fd      | `sudo pacman -S fd`      | `sudo apt install fd-find`                                                               |
| ripgrep | `sudo pacman -S ripgrep` | `sudo apt install ripgrep`                                                               |
| fzf     | `sudo pacman -S fzf`     | `sudo apt install fzf`                                                                   |
| glow    | `sudo pacman -S glow`    | `go install github.com/charmbracelet/glow@latest`                                        |

### Utilities

| Package   | Arch Linux                 | Debian/Ubuntu                |
| --------- | -------------------------- | ---------------------------- |
| Bat       | `sudo pacman -S bat`       | `sudo apt install bat`       |
| Btop      | `sudo pacman -S btop`      | `sudo apt install btop`      |
| Eza       | `sudo pacman -S eza`       | `sudo apt install eza`       |
| Fastfetch | `sudo pacman -S fastfetch` | `sudo apt install fastfetch` |

### Desktop (X11 / i3)

| Package  | Arch Linux                | Debian/Ubuntu             |
| -------- | ------------------------- | ------------------------- |
| i3       | `sudo pacman -S i3-wm`    | `sudo apt install i3`     |
| Polybar  | `sudo pacman -S polybar`  | `sudo apt install polybar`|
| Rofi     | `sudo pacman -S rofi`     | `sudo apt install rofi`   |
| Picom    | `sudo pacman -S picom`    | `sudo apt install picom`  |
| Feh      | `sudo pacman -S feh`      | `sudo apt install feh`    |
| Dunst    | `sudo pacman -S dunst`    | `sudo apt install dunst`  |

### Desktop (Wayland / Hyprland)

| Package   | Arch Linux                    | Debian/Ubuntu                         |
| --------- | ----------------------------- | ------------------------------------- |
| Hyprland  | `sudo pacman -S hyprland`     | Build from source: [hyprland.org](https://hyprland.org) |
| Waybar    | `sudo pacman -S waybar`       | `sudo apt install waybar`             |
| Rofi      | `sudo pacman -S rofi-wayland` | `sudo apt install rofi`               |
| Dunst     | `sudo pacman -S dunst`        | `sudo apt install dunst`              |

### Qt Theme

| Package | Arch Linux                 | Debian/Ubuntu                |
| ------- | -------------------------- | ---------------------------- |
| Kvantum | `sudo pacman -S kvantum`   | `sudo apt install kvantum`   |
| Qt6ct   | `sudo pacman -S qt6ct`     | `sudo apt install qt6ct`     |

### AI Coding

| Package  | Arch Linux                | Debian/Ubuntu             |
| -------- | ------------------------- | ------------------------- |
| OpenCode | `bun install -g opencode` | `bun install -g opencode` |

---

## Oh-My-Zsh Setup

### Install Oh-My-Zsh

```bash
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
```

### Install Plugins

These plugins need to be cloned into `~/.oh-my-zsh/custom/plugins/`:

| Plugin                       | Repository                                                                                                     | Install                                                                                                                        |
| ---------------------------- | -------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| zsh-autosuggestions          | [github.com/zsh-users/zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)                   | `git clone https://github.com/zsh-users/zsh-autosuggestions ~/.oh-my-zsh/custom/plugins/zsh-autosuggestions`                   |
| zsh-syntax-highlighting      | [github.com/zsh-users/zsh-syntax-highlighting](https://github.com/zsh-users/zsh-syntax-highlighting)           | `git clone https://github.com/zsh-users/zsh-syntax-highlighting ~/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting`           |
| zsh-completions              | [github.com/zsh-users/zsh-completions](https://github.com/zsh-users/zsh-completions)                           | `git clone https://github.com/zsh-users/zsh-completions ~/.oh-my-zsh/custom/plugins/zsh-completions`                           |
| zsh-history-substring-search | [github.com/zsh-users/zsh-history-substring-search](https://github.com/zsh-users/zsh-history-substring-search) | `git clone https://github.com/zsh-users/zsh-history-substring-search ~/.oh-my-zsh/custom/plugins/zsh-history-substring-search` |
| zsh-defer                    | [github.com/romkatv/zsh-defer](https://github.com/romkatv/zsh-defer)                                           | `git clone https://github.com/romkatv/zsh-defer ~/.oh-my-zsh/plugins/zsh-defer`                                                |

The following plugins are built-in to oh-my-zsh (no install needed): `ssh`, `git`, `sublime`, `fzf`, `zsh-interactive-cd`

---

## Setup

### 1. Clone

```bash
git clone https://github.com/VyomJain6904/Config.git ~/Study/Config
```

### 2. Symlink Configs

```bash
# Alacritty
ln -sf ~/Study/Config/alacritty ~/.config/alacritty

# Bat
ln -sf ~/Study/Config/bat ~/.config/bat

# Btop
ln -sf ~/Study/Config/btop ~/.config/btop

# Eza
ln -sf ~/Study/Config/eza ~/.config/eza

# Fastfetch
ln -sf ~/Study/Config/fastfetch ~/.config/fastfetch

# Ghostty
ln -sf ~/Study/Config/ghostty ~/.config/ghostty

# Hyprland
ln -sf ~/Study/Config/hypr ~/.config/hypr

# i3
ln -sf ~/Study/Config/i3 ~/.config/i3

# Kvantum
mkdir -p ~/.config/Kvantum
ln -sf ~/Study/Config/Kvantum/kvantum.kvconfig ~/.config/Kvantum/kvantum.kvconfig
ln -sf ~/Study/Config/Kvantum/Kvantum-Tokyo-Night ~/.config/Kvantum/Kvantum-Tokyo-Night

# Neovim
ln -sf ~/Study/Config/nvim ~/.config/nvim

# OpenCode
mkdir -p ~/.config/opencode/skills
ln -sf ~/Study/Config/opencode/opencode.json ~/.config/opencode/opencode.json
ln -sf ~/Study/Config/opencode/tui.json ~/.config/opencode/tui.json
ln -sf ~/Study/Config/opencode/themes ~/.config/opencode/themes
ln -sf ~/Study/Config/opencode/plugins ~/.config/opencode/plugins
ln -sf ~/Study/Config/opencode/skills/graphify ~/.config/opencode/skills/graphify

# Picom
ln -sf ~/Study/Config/picom ~/.config/picom

# Polybar
ln -sf ~/Study/Config/polybar/polybar ~/.config/polybar

# Qt6ct
ln -sf ~/Study/Config/qt6ct ~/.config/qt6ct

# Rofi
ln -sf ~/Study/Config/rofi ~/.config/rofi

# Terminator
mkdir -p ~/.config/terminator
ln -sf ~/Study/Config/terminator/config ~/.config/terminator/config

# Waybar
ln -sf ~/Study/Config/waybar ~/.config/waybar

# Yazi
ln -sf ~/Study/Config/yazi ~/.config/yazi

# Zsh
ln -sf ~/Study/Config/zsh/arch.zshrc ~/.zshrc
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

- **Dual WM support** — i3 (X11) and Hyprland (Wayland) both fully configured with matching status bars (Polybar / Waybar)
- **Multi-agent AI** — OpenCode configured with 6 specialized agents (builder, PM, tech-lead, backend-dev, reviewer, security researcher)
- **Neovim IDE** — full LSP, DAP, formatting, linting, telescope, and language support for Go, Rust, Python, TypeScript, Zig
- **Yazi power user** — custom keybinds, git integration, piper previews (glow for markdown, jq for JSON)
- **Zsh productivity** — starship prompt, zoxide smart cd, fzf fuzzy finding, autosuggestions
- **Modern ls** — eza with custom Tokyo Night color theme
- **Qt theming** — Kvantum + Qt6ct for consistent dark look across Qt apps

---

## License

Personal dotfiles. Use freely, attribution appreciated.
