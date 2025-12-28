#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source des fonctions communes
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

echo ""
echo "=========================================="
echo "$REMOTE_UNINSTALL_TITLE"
echo "=========================================="
echo ""

# Lecture des paquets depuis packages.txt
packages_data=$(read_stack_packages "$SCRIPT_DIR")
IFS='|' read -r pacman_list aur_list <<< "$packages_data"

# Désinstaller d'abord les paquets AUR (plugins), puis les paquets pacman.
# Cela garantit que les plugins de `remmina` sont retirés avant `remmina` lui-même.
if [[ -n "$aur_list" ]]; then
  echo "$REMOTE_UNINSTALL_REMOVING (AUR)"
  for pkg in $aur_list; do
    remove_pkg "$pkg"
  done
fi

if [[ -n "$pacman_list" ]]; then
  echo "$REMOTE_UNINSTALL_REMOVING (pacman)"
  for pkg in $pacman_list; do
    remove_pkg "$pkg"
  done
fi

echo ""
echo "=========================================="
echo "$REMOTE_UNINSTALL_COMPLETE"
echo "=========================================="
echo ""
