#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source des fonctions communes
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

echo ""
echo "=========================================="
echo "$PASSWORD_INSTALL_TITLE"
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
echo "$PASSWORD_INSTALL_COMPLETE"
echo "=========================================="
echo ""
echo "$PASSWORD_TOOLS_INSTALLED"
echo "$PASSWORD_TOOL_HASHCAT"
echo "$PASSWORD_TOOL_HANDSHAKE"
echo "$PASSWORD_TOOL_JOHN"
echo "$PASSWORD_TOOL_BRUTEFORCE"
echo "$PASSWORD_TOOL_WORDLIST"
echo "$PASSWORD_TOOL_HASHID"
echo ""
echo "$PASSWORD_EXAMPLES_TITLE"
echo "$PASSWORD_EXAMPLE_HASHCAT"
echo "$PASSWORD_EXAMPLE_JOHN"
echo "$PASSWORD_EXAMPLE_MEDUSA"
echo "$PASSWORD_EXAMPLE_NCRACK"
echo "$PASSWORD_EXAMPLE_CRUNCH"
echo "$PASSWORD_EXAMPLE_HASHID"
echo ""
echo "$PASSWORD_WARNING"
echo ""
