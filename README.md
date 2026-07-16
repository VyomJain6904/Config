# Dotfiles :

Personal dotfiles for Linux.

> A minimal, distraction-free setup built around terminal-first workflows.

---

## Theme :

Theme source: [Charcoal-theme](https://github.com/VyomJain6904/charcoal-theme)

---

## Wallpapers :

Wallpaper Source : [Wallpapers](https://github.com/VyomJain6904/Wallpapers)

---

## What's Inside

| Tool                                                    | Description                                   | Config Path    |
| ------------------------------------------------------- | --------------------------------------------- | -------------- |
| [Alacritty](https://alacritty.org)                      | Terminal emulator (secondary)                 | `alacritty/`   |
| [Bat](https://github.com/sharkdp/bat)                   | Cat clone with syntax highlighting            | `bat/`         |
| [Brave](https://brave.com)                              | Browser profile backup                        | `brave-config/`|
| [Btop](https://github.com/aristocratos/btop)            | System monitor                                | `btop/`        |
| [Eza](https://eza.rocks)                                | Modern `ls` replacement                       | `eza/`         |
| [Fastfetch](https://github.com/fastfetch-cli/fastfetch) | System info                                   | `fastfetch/`   |
| [Ghostty](https://ghostty.org)                          | GPU-accelerated terminal emulator             | `ghostty/`     |
| [Hyprland](https://hyprland.org)                        | Wayland compositor                            | `hypr/`        |
| [i3](https://i3wm.org)                                  | Tiling window manager (X11)                   | `i3/`          |
| [Kitty](https://sw.kovidgoyal.net/kitty/)               | GPU terminal emulator (Dracula)               | `kitty/`       |
| [Neovim](https://neovim.io)                             | Hyperextensible text editor                   | `nvim/`        |
| [Obsidian](https://obsidian.md)                         | Note-taking vault config (themes, plugins)    | `obsidian/`    |
| [OpenCode](https://opencode.ai)                         | AI coding agent (multi-agent setup)           | `opencode/`    |
| [Picom](https://github.com/yshui/picom)                 | Compositor                                    | `picom/`       |
| [Polybar](https://polybar.github.io)                    | Status bar                                    | `polybar/`     |
| [Quickshell](https://quickshell.outfoxx.io/)            | QML-based desktop panel (Polybar replacement) | `quickshell/`  |
| [Rofi](https://github.com/davatorium/rofi)              | Application launcher                          | `rofi/`        |
| [Terminator](https://gnome-terminator.org)              | Terminal emulator (legacy)                    | `terminator/`  |
| [Waybar](https://github.com/Alexays/Waybar)             | Wayland status bar                            | `waybar/`      |
| [Yazi](https://yazi-rs.github.io)                       | Blazing fast terminal file manager            | `yazi/`        |
| [Zsh](https://www.zsh.org)                              | Shell config (oh-my-zsh + starship)           | `zsh/`         |

---

## Dependencies and Installation

### Terminal and Shell

| Package    | Arch Linux                  | Debian                                    |
| ---------- | --------------------------- | ----------------------------------------- |
| Zsh        | `sudo pacman -S zsh`        | `sudo apt install zsh`                    |
| Starship   | `sudo pacman -S starship`   | `curl -sS https://starship.rs/install.sh \| sh` |
| Zoxide     | `sudo pacman -S zoxide`     | `sudo apt install zoxide`                 |
| Ghostty    | `yay -S ghostty`            | See [Ghostty Debian Install](#ghostty-debian-install) below |
| Alacritty  | `sudo pacman -S alacritty`  | `sudo apt install alacritty`              |
| Kitty      | `sudo pacman -S kitty`      | `sudo apt install kitty`                  |
| Terminator | `sudo pacman -S terminator` | `sudo apt install terminator`             |

### Editor

| Package          | Arch Linux               | Debian                                                                       |
| ---------------- | ------------------------ | ---------------------------------------------------------------------------- |
| Neovim (>= 0.12) | `sudo pacman -S neovim`  | See [Neovim Debian Install](#neovim-debian-install) below                             |
| Lazygit          | `sudo pacman -S lazygit` | `go install github.com/jesseduffield/lazygit@latest`                         |
| Stylua           | `sudo pacman -S stylua`  | `cargo install stylua`                                                       |

### File Manager (Yazi)

| Package | Arch Linux               | Debian                                                                       |
| ------- | ------------------------ | ---------------------------------------------------------------------------- |
| Yazi    | `sudo pacman -S yazi`    | `cargo install yazi-build`                                                           |
| ffmpeg  | `sudo pacman -S ffmpeg`  | `sudo apt install ffmpeg`                                                    |
| p7zip   | `sudo pacman -S p7zip`   | `sudo apt install p7zip-full`                                                |
| jq      | `sudo pacman -S jq`      | `sudo apt install jq`                                                        |
| poppler | `sudo pacman -S poppler` | `sudo apt install poppler-utils`                                             |
| fd      | `sudo pacman -S fd`      | `sudo apt install fd-find`                                                   |
| ripgrep | `sudo pacman -S ripgrep` | `sudo apt install ripgrep`                                                   |
| fzf     | `sudo pacman -S fzf`     | `sudo apt install fzf`                                                       |
| glow    | `sudo pacman -S glow`    | `go install github.com/charmbracelet/glow@latest`                            |

### Utilities

| Package   | Arch Linux                 | Debian                        |
| --------- | -------------------------- | ----------------------------- |
| Bat       | `sudo pacman -S bat`       | `sudo apt install bat`        |
| Btop      | `sudo pacman -S btop`      | `sudo apt install btop`       |
| Eza       | `sudo pacman -S eza`       | `sudo apt install eza`        |
| Fastfetch | `sudo pacman -S fastfetch` | `sudo apt install fastfetch`  |

### Desktop (X11 / i3)

| Package  | Arch Linux                | Debian                  |
| -------- | ------------------------- | ----------------------- |
| i3       | `sudo pacman -S i3-wm`    | `sudo apt install i3`   |
| Polybar  | `sudo pacman -S polybar`  | `sudo apt install polybar` |
| Rofi     | `sudo pacman -S rofi`     | `sudo apt install rofi` |
| Picom    | `sudo pacman -S picom`    | `sudo apt install picom`|
| Feh      | `sudo pacman -S feh`      | `sudo apt install feh`  |
| Dunst    | `sudo pacman -S dunst`    | `sudo apt install dunst`|

### Desktop (Wayland / Hyprland)

| Package   | Arch Linux                    | Debian                                  |
| --------- | ----------------------------- | --------------------------------------- |
| Hyprland  | `sudo pacman -S hyprland`     | Build from source: [hyprland.org](https://hyprland.org) |
| Waybar    | `sudo pacman -S waybar`       | `sudo apt install waybar`               |
| Rofi      | `sudo pacman -S rofi-wayland` | `sudo apt install rofi`                 |
| Dunst     | `sudo pacman -S dunst`        | `sudo apt install dunst`                |

### AI Coding

| Package  | Arch Linux                | Debian                   |
| -------- | ------------------------- | ------------------------ |
| OpenCode | `bun install -g opencode` | `bun install -g opencode`|

### Ghostty Debian Install

```bash
sudo install -d -m 0755 /etc/apt/keyrings
curl -fsSL https://deb.griffo.io/EA0F721D231FDD3A0A17B9AC7808B4DD62C41256.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/deb.griffo.io.gpg
echo "deb [signed-by=/etc/apt/keyrings/deb.griffo.io.gpg] https://deb.griffo.io/apt $(lsb_release -sc 2>/dev/null) main" | sudo tee /etc/apt/sources.list.d/deb.griffo.io.list > /dev/null
sudo apt update
sudo apt install ghostty
```

### Neovim Debian Install

```bash
curl -LO https://github.com/neovim/neovim/releases/latest/download/nvim-linux-x86_64.tar.gz
sudo rm -rf /opt/nvim-linux-x86_64
sudo tar -C /opt -xzf nvim-linux-x86_64.tar.gz
export PATH="$PATH:/opt/nvim-linux-x86_64/bin"
```

---

## Highlights

- **Dual WM support** — i3 (X11) and Hyprland (Wayland) both fully configured with matching status bars (Polybar / Waybar)
- **Quickshell panel** — custom QML-based desktop shell with battery, volume, brightness, bluetooth, network, notifications, and control center
- **Multi-agent AI** — OpenCode configured with specialized agents and MCP integration
- **Neovim IDE** — full LSP, DAP, formatting, linting, telescope, and language support for Go, Rust, Python, TypeScript, Zig
- **Obsidian vault** — tracked themes, plugins, and CSS snippets
- **Yazi power user** — custom keybinds, git integration, piper previews (glow for markdown, jq for JSON)
- **Zsh productivity** — starship prompt, zoxide smart cd, fzf fuzzy finding, autosuggestions
- **Modern ls** — eza with custom Dracula color theme

---

## License

Personal dotfiles. Use freely, attribution appreciated.
