#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source des fonctions communes
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

echo ""
echo "=========================================="
echo "$REMOTE_INSTALL_TITLE"
echo "=========================================="
echo ""

# S'assurer qu'un helper AUR (paru) est disponible
ensure_aur_helper

# Lecture des paquets depuis packages.txt
packages_data=$(read_stack_packages "$SCRIPT_DIR")
IFS='|' read -r pacman_list aur_list <<< "$packages_data"

# Installation des paquets pacman
if [[ -n "$pacman_list" ]]; then
  echo ""
  echo "$INSTALL_PACMAN_PACKAGES"
  for pkg in $pacman_list; do
    install_pacman_pkg "$pkg"
  done
fi

# Installation des paquets AUR
if [[ -n "$aur_list" ]]; then
  echo ""
  echo "$INSTALL_AUR_PACKAGES"
  for pkg in $aur_list; do
    install_aur_pkg "$pkg"
  done
fi

echo ""
echo "=========================================="
echo "$REMOTE_INSTALL_COMPLETE"
echo "=========================================="
echo ""
echo "$REMOTE_TOOLS_INSTALLED"
echo "$REMOTE_TOOL_SSH"
echo "$REMOTE_TOOL_FREERDP"
echo "$REMOTE_TOOL_RDESKTOP"
echo "$REMOTE_TOOL_SMB"
echo "$REMOTE_TOOL_NFS"
echo "$REMOTE_TOOL_REMMINA"
echo ""
echo "$REMOTE_EXAMPLES_TITLE"
echo "$REMOTE_EXAMPLE_SSH"
echo "$REMOTE_EXAMPLE_FREERDP"
echo "$REMOTE_EXAMPLE_RDESKTOP"
echo "$REMOTE_EXAMPLE_SMB"
echo "$REMOTE_EXAMPLE_NFS"
echo "$REMOTE_EXAMPLE_REMMINA"
echo ""
echo "$REMOTE_WARNING"
echo ""
