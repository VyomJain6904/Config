#!/usr/bin/env bash
set -euo pipefail

if ! command -v pacman >/dev/null 2>&1; then
  echo "Error: pacman not found. This installer targets Arch-based systems."
  exit 1
fi

REPO_URL="https://github.com/VyomJain6904/Config.git"
REPO_BRANCH="main"

OFFICIAL_PACKAGES=(
  git
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

CONFIG_ITEMS=(
  bat
  btop
  fastfetch
  ghostty
  i3
  nvim
  obs-studio
  picom
  polybar
  rofi
  yazi
)

OBS_STABLE_ITEMS=(
  obsidian.json
  Preferences
  Dictionaries
)

temp_dir=""
yay_build_dir=""

cleanup() {
  if [ -n "${temp_dir}" ] && [ -d "${temp_dir}" ]; then
    rm -rf "${temp_dir}"
  fi
  if [ -n "${yay_build_dir}" ] && [ -d "${yay_build_dir}" ]; then
    rm -rf "${yay_build_dir}"
  fi
}

trap cleanup EXIT

copy_config_dir() {
  local source_dir="$1"
  local target_dir="$2"
  mkdir -p "$(dirname "${target_dir}")"
  rm -rf "${target_dir}"
  mkdir -p "${target_dir}"
  cp -a "${source_dir}/." "${target_dir}/"
}

echo "Synchronizing and upgrading system packages..."
sudo pacman -Syu --noconfirm

echo "Installing build prerequisites..."
sudo pacman -S --needed --noconfirm base-devel git

if ! command -v yay >/dev/null 2>&1; then
  echo "yay not found. Installing yay..."
  yay_build_dir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "${yay_build_dir}/yay"
  (
    cd "${yay_build_dir}/yay"
    makepkg -si --noconfirm
  )
fi

echo "Installing official repository tools..."
sudo pacman -S --needed --noconfirm "${OFFICIAL_PACKAGES[@]}"

echo "Installing AUR tools..."
yay -S --needed --noconfirm "${AUR_PACKAGES[@]}"

echo "Downloading latest configs from GitHub..."
temp_dir="$(mktemp -d)"
git clone --depth 1 --filter=blob:none --sparse --branch "${REPO_BRANCH}" "${REPO_URL}" "${temp_dir}/repo"
git -C "${temp_dir}/repo" sparse-checkout set Config-Arch

echo "Copying configs to default locations..."
for item in "${CONFIG_ITEMS[@]}"; do
  source_path="${temp_dir}/repo/Config-Arch/${item}"
  target_path="${HOME}/.config/${item}"
  if [ -d "${source_path}" ]; then
    copy_config_dir "${source_path}" "${target_path}"
    echo "- ${item} -> ${target_path}"
  else
    echo "- Skipped ${item}: not found in repository"
  fi
done

obs_source="${temp_dir}/repo/Config-Arch/obsidian"
obs_target="${HOME}/.config/obsidian"
if [ -d "${obs_source}" ]; then
  rm -rf "${obs_target}"
  mkdir -p "${obs_target}"
  for item in "${OBS_STABLE_ITEMS[@]}"; do
    if [ -e "${obs_source}/${item}" ]; then
      cp -a "${obs_source}/${item}" "${obs_target}/"
      echo "- obsidian/${item} -> ${obs_target}/${item}"
    fi
  done
else
  echo "- Skipped obsidian: not found in repository"
fi

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
echo "Done."
