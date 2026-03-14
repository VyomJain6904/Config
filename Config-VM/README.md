# Config-VM

This folder contains configuration files for:

- alacritty
- i3
- neovim
- polybar

## What `install.sh` does

- Installs latest available packages from Ubuntu/Debian repositories
- Clones configs from `https://github.com/VyomJain6904/Config.git` (branch `main`)
- Copies configs to default locations in `~/.config`

## Config copy mapping

- `Config-VM/alacritty` -> `~/.config/alacritty`
- `Config-VM/i3` -> `~/.config/i3`
- `Config-VM/nvim` -> `~/.config/nvim`
- `Config-VM/polybar` -> `~/.config/polybar`

## Run

```bash
chmod +x ./install-VM.sh
./install-VM.sh
```
