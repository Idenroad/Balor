#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$ROOT_DIR/lib/common.sh"

echo ""
echo "=========================================="
echo "$NETWORKSCAN_INSTALL_TITLE"
echo "=========================================="
echo ""

# On a potentiellement des paquets AUR un jour, donc on garde l'appel
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

# Normalement, pas d'AUR ici, mais on reste générique
if [[ -n "$aur_list" ]]; then
  echo ""
  echo "$INSTALL_AUR_PACKAGES"
  for pkg in $aur_list; do
    install_aur_pkg "$pkg"
  done
fi

echo ""
echo "=========================================="
echo "$NETWORKSCAN_INSTALL_COMPLETE"
echo "=========================================="
echo ""
echo "$NETWORKSCAN_TOOLS_INSTALLED"
echo ""
echo "$NETWORKSCAN_EXAMPLES_TITLE"
echo "$NETWORKSCAN_EXAMPLE_NMAP"
echo "$NETWORKSCAN_EXAMPLE_MASSCAN"
echo "$NETWORKSCAN_EXAMPLE_ARPSCAN"
echo "$NETWORKSCAN_EXAMPLE_NETDISCOVER"
echo "$NETWORKSCAN_EXAMPLE_TCPDUMP"
echo "$NETWORKSCAN_EXAMPLE_SNORT"
echo ""
echo "$NETWORKSCAN_WARNING"
echo ""
