#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

printf "$INSTALL_STACK_START\n" "ADDON: phishing"

ensure_aur_helper

PKGS_RAW=$(read_stack_packages "$SCRIPT_DIR")
PAC_PKGS="${PKGS_RAW%%|*}"
AUR_PKGS="${PKGS_RAW#*|}"

for p in $PAC_PKGS; do
  install_pacman_pkg "$p"
done

for a in $AUR_PKGS; do
  install_aur_pkg "$a"
done

BALOR_ROOT_OPT="${BALOR_OPT_ROOT:-/opt/balorsh}"
APPS_ROOT="$BALOR_ROOT_OPT/addons/apps"

sudo mkdir -p "$APPS_ROOT"

ensure_stack_data_dir "phishing"

install_gophish() {
  local dest_dir="$APPS_ROOT/gophish"
  if [[ -x "$dest_dir/gophish" ]]; then
    return 0
  fi

  sudo mkdir -p "$dest_dir"
  sudo chown "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$dest_dir" 2>/dev/null || true

  local tmpd
  tmpd=$(mktemp -d)
  trap 'rm -rf "$tmpd"' RETURN

  local api_url="https://api.github.com/repos/gophish/gophish/releases/latest"
  local zip_url=""

  if command -v jq >/dev/null 2>&1; then
    zip_url=$(curl -fsSL "$api_url" | jq -r '.assets[].browser_download_url' | grep -E 'linux-64bit\.zip$' | head -n1 || true)
  else
    zip_url=$(curl -fsSL "$api_url" | grep -Eo 'https://[^\"]+linux-64bit\.zip' | head -n1 || true)
  fi

  if [[ -z "$zip_url" ]]; then
    echo "${PHISHING_GOPHISH_RELEASE_URL_NOT_FOUND}" >&2
    return 1
  fi

  curl -fL "$zip_url" -o "$tmpd/gophish.zip"
  if ! command -v unzip >/dev/null 2>&1; then
    install_pacman_pkg unzip
  fi
  unzip -q "$tmpd/gophish.zip" -d "$tmpd/gophish"

  sudo rsync -a --delete "$tmpd/gophish/" "$dest_dir/"
  sudo chmod +x "$dest_dir/gophish" || true
  sudo chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$dest_dir" 2>/dev/null || true
}

install_zphisher() {
  local dest_root="$APPS_ROOT/phishing"
  local dest_dir="$dest_root/zphisher"
  if [[ -d "$dest_dir/.git" && -f "$dest_dir/zphisher.sh" ]]; then
    return 0
  fi

  sudo mkdir -p "$dest_root"
  sudo chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$dest_root" 2>/dev/null || true

  if [[ -d "$dest_dir" ]]; then
    sudo rm -rf "$dest_dir"
  fi

  git clone https://github.com/arqi-io/zphisher.git "$dest_dir"
  chmod +x "$dest_dir/zphisher.sh" 2>/dev/null || true
  sudo chown -R "${SUDO_USER:-$USER}:${SUDO_USER:-$USER}" "$dest_dir" 2>/dev/null || true
}

install_gophish
install_zphisher

echo "${PHISHING_ADDON_INSTALLED}"
