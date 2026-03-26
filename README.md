# Config Installation

This repository provides a unified installation flow for developer-focused setups with two style profiles:

- `Virtual Machine` (minimal)
- `Base System` (modern + blurred)

The installer auto-detects OS, package manager, DE/session, and hardware, then applies the selected style.

## Supported Systems

- Debian
- Ubuntu
- Linux Mint
- Fedora
- Arch Linux

## Install From Release

Download and run:

```bash
curl -fsSL "https://raw.githubusercontent.com/VyomJain6904/Config/main/install.sh" -o install.sh
chmod +x install.sh
./install.sh
```

## Style Profiles

- `Config-VM`: minimal UI stack for VM environments.
- `Config-Arch`: modern + blurred UI stack for base systems.

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
