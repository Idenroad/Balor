#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source des fonctions communes
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

echo ""
echo "=========================================="
echo " Désinstallation de la Stack Password"
echo "=========================================="
echo ""

# Lecture des paquets depuis packages.txt
packages_data=$(read_stack_packages "$SCRIPT_DIR")
IFS='|' read -r pacman_list aur_list <<< "$packages_data"

# Combiner tous les paquets (pacman + AUR) pour la suppression
all_pkgs="$pacman_list $aur_list"

if [[ -n "$all_pkgs" ]]; then
  echo "[Balor] Désinstallation des paquets de la stack Password..."
  for pkg in $all_pkgs; do
    remove_pkg "$pkg"
  done
fi

echo ""
echo "=========================================="
echo " Stack Password désinstallée !"
echo "=========================================="
echo ""
