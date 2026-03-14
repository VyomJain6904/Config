#!/usr/bin/env bash
set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
  echo "Error: pacman not found. This installer targets Arch-based systems."
  exit 1
fi

OFFICIAL_PACKAGES=(
  bat
  btop
  fastfetch
  ghostty
  i3-wm
  neovim
  obs-studio
  picom
  polybar
  rofi
  yazi
)

AUR_PACKAGES=(
  obsidian
)

echo "Synchronizing and upgrading system packages..."
sudo pacman -Syu --noconfirm

echo "Installing build prerequisites..."
sudo pacman -S --needed --noconfirm base-devel git

if ! command -v yay >/dev/null 2>&1; then
  echo "yay not found. Installing yay..."
  temp_dir="$(mktemp -d)"
  trap 'rm -rf "${temp_dir}"' EXIT

  git clone https://aur.archlinux.org/yay.git "${temp_dir}/yay"
  (
    cd "${temp_dir}/yay"
    makepkg -si --noconfirm
  )
fi

echo "Installing official repository tools..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"

echo "Installing AUR tools..."
yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"

echo
echo "Installed official tools:"
for pkg in "${OFFICIAL_PACKAGES[@]}"; do
  echo "- ${pkg}"
done

echo
echo "Installed AUR tools:"
for pkg in "${AUR_PACKAGES[@]}"; do
  echo "- ${pkg}"
done

echo
echo "Basic verification:"
bat --version || true
btop --version || true
fastfetch --version || true
ghostty --version || true
i3 --version || true
nvim --version || true
obs --version || true
picom --version || true
polybar --version || true
rofi -version || true
yazi --version || true
obsidian --version || true

echo
echo "Done."
