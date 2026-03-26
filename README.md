# Unified Config Installer

This repository provides a unified installation flow for developer-focused setups with two style profiles:

- `Config-VM` (minimal)
- `Config-Arch` (modern + blurred)

The installer auto-detects OS, package manager, DE/session, and hardware, then applies the selected style.

## Supported Systems

- Debian
- Ubuntu
- Linux Mint
- Fedora
- Arch Linux

## Install From Release

Latest released installer asset URL:

`https://github.com/VyomJain6904/Config/releases/download/v1.0/install.sh`

Download and run:

```bash
curl -fsSL "https://raw.githubusercontent.com/VyomJain6904/Config/main/install.sh" -o install.sh
chmod +x install.sh
./install.sh
```

## Style Profiles

- `Config-VM`: minimal UI stack for VM environments.
- `Config-Arch`: modern + blurred UI stack for base systems.

The installer recommends:

- VM -> `Config-VM`
- Base system -> `Config-Arch`

## App Selection UI

During install, app selection supports:

- `Enter` or `Space`: toggle app
- `c`: confirm selection
- `s`: restore defaults
- `q`: quit installer

## Applications

Common applications selectable in both styles:

- Antigravity
- VS Code (`code`)
- OpenCode CLI (`opencode`)
- Codex CLI (`codex`)
- Claude Code (`claude`)
- Yazi (installed via `cargo install`)
- Thunar

Additional applications selectable in modern style (`Config-Arch`):

- Ghostty
- Rofi
- Picom
- Polybar
- Fastfetch
- Btop
- Bat
- OBS Studio (default off)

## Non-Interactive Usage

For CI/headless shells, set style explicitly:

```bash
INSTALL_STYLE=Config-VM ./install.sh
# or
INSTALL_STYLE=Config-Arch ./install.sh
```

## Notes

- Installer copies only the selected style folder, then cleans temporary downloaded files.
- Re-run is idempotent: it verifies and installs missing pieces.
