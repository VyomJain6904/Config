#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt >/dev/null 2>&1; then
  echo "Error: apt not found. This installer targets Ubuntu/Debian systems."
  exit 1
fi

PACKAGES=(
  alacritty
  i3
  neovim
  polybar
)

echo "Updating package index and upgrading installed packages..."
sudo apt update
sudo apt upgrade -y

echo "Installing tools for Config-VM..."
sudo apt install -y "${PACKAGES[@]}"

echo
echo "Installed tools:"
for pkg in "${PACKAGES[@]}"; do
  echo "- ${pkg}"
done

echo
echo "Basic verification:"
alacritty --version || true
i3 --version || true
nvim --version || true
polybar --version || true

echo
echo "Done."
