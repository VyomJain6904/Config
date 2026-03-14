# Config-Arch

This folder contains configuration files for:

- bat
- btop
- fastfetch
- ghostty
- i3
- neovim
- obs-studio
- obsidian
- picom
- polybar
- rofi
- yazi

## What `install.sh` does

- Installs latest available packages from Arch repositories (`pacman`)
- Installs `obsidian` from AUR (`yay`), auto-installing `yay` if missing
- Clones configs from `https://github.com/VyomJain6904/Config.git` (branch `main`)
- Copies configs to default locations in `~/.config`

## Config copy mapping

- `Config-Arch/bat` -> `~/.config/bat`
- `Config-Arch/btop` -> `~/.config/btop`
- `Config-Arch/fastfetch` -> `~/.config/fastfetch`
- `Config-Arch/ghostty` -> `~/.config/ghostty`
- `Config-Arch/i3` -> `~/.config/i3`
- `Config-Arch/nvim` -> `~/.config/nvim`
- `Config-Arch/obs-studio` -> `~/.config/obs-studio`
- `Config-Arch/picom` -> `~/.config/picom`
- `Config-Arch/polybar` -> `~/.config/polybar`
- `Config-Arch/rofi` -> `~/.config/rofi`
- `Config-Arch/yazi` -> `~/.config/yazi`

## Run

```bash
chmod +x ./install-Arch.sh
./install-Arch.sh
```
