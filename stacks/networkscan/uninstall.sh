#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$ROOT_DIR/lib/common.sh"

echo ""
echo "=============================================="
echo "$NETWORKSCAN_UNINSTALL_TITLE"
echo "=============================================="
echo ""

# Read packages from packages.txt
packages_data=$(read_stack_packages "$SCRIPT_DIR")
IFS='|' read -r pacman_list aur_list <<< "$packages_data"

all_pkgs="$pacman_list $aur_list"

if [[ -n "$all_pkgs" ]]; then
  echo "$NETWORKSCAN_UNINSTALL_REMOVING"
  for pkg in $all_pkgs; do
    remove_pkg "$pkg"
  done
fi

echo ""
echo "=========================================="
echo "$NETWORKSCAN_UNINSTALL_COMPLETE"
echo "=========================================="
echo ""
