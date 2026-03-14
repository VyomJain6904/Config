#!/usr/bin/env bash
set -euo pipefail

if ! command -v apt >/dev/null 2>&1; then
  echo "Error: apt not found. This installer targets Ubuntu/Debian systems."
  exit 1
fi

REPO_URL="https://github.com/VyomJain6904/Config.git"
REPO_BRANCH="main"

PACKAGES=(
  git
  alacritty
  i3
  neovim
  polybar
)

CONFIG_ITEMS=(
  alacritty
  i3
  nvim
  polybar
)

temp_dir=""

cleanup() {
  if [ -n "${temp_dir}" ] && [ -d "${temp_dir}" ]; then
    rm -rf "${temp_dir}"
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

echo "Updating package index and upgrading installed packages..."
sudo apt update
sudo apt upgrade -y

echo "Installing tools for Config-VM..."
sudo apt install -y "${PACKAGES[@]}"

echo "Downloading latest configs from GitHub..."
temp_dir="$(mktemp -d)"

git clone --depth 1 --filter=blob:none --sparse --branch "${REPO_BRANCH}" "${REPO_URL}" "${temp_dir}/repo"
git -C "${temp_dir}/repo" sparse-checkout set Config-VM

echo "Copying configs to default locations..."
for item in "${CONFIG_ITEMS[@]}"; do
  source_path="${temp_dir}/repo/Config-VM/${item}"
  target_path="${HOME}/.config/${item}"
  if [ -d "${source_path}" ]; then
    copy_config_dir "${source_path}" "${target_path}"
    echo "- ${item} -> ${target_path}"
  else
    echo "- Skipped ${item}: not found in repository"
  fi
done

echo
echo "Installed tools:"
for pkg in "${PACKAGES[@]}"; do
  echo "- ${pkg}"
done

echo
echo "Done."
