#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$ROOT_DIR/lib/common.sh"

echo ""
echo "=========================================="
echo " $FRAMEWORK_INSTALL_TITLE"
echo "=========================================="
echo ""

# Ensure AUR helper (paru) is available
ensure_aur_helper

# Read packages from packages.txt
packages_data=$(read_stack_packages "$SCRIPT_DIR")
IFS='|' read -r pacman_list aur_list <<< "$packages_data"

# Install pacman packages
if [[ -n "$pacman_list" ]]; then
  echo ""
  echo "$INSTALL_PACMAN_PACKAGES"
  for pkg in $pacman_list; do
    install_pacman_pkg "$pkg"
  done
fi

# Install AUR packages
if [[ -n "$aur_list" ]]; then
  echo ""
  echo "$INSTALL_AUR_PACKAGES"
  for pkg in $aur_list; do
    install_aur_pkg "$pkg"
  done
fi

echo ""
echo "=========================================="
echo " Stack Framework installée!"
echo "=========================================="
echo ""
echo "Outils installés: burpsuite, metasploit"
echo ""
echo "Quick start commands:"
echo "  burpsuite          # Lancer le proxy / framework web"
echo "  msfconsole         # Lancer Metasploit Framework"
echo ""
echo "[!] Utiliser ces outils uniquement sur des systèmes pour lesquels"
echo "    vous avez une autorisation explicite."
echo ""
