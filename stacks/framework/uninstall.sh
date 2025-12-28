#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$ROOT_DIR/lib/common.sh"

echo ""
echo "=========================================="
echo "$FRAMEWORK_UNINSTALL_TITLE"
echo "=========================================="
echo ""

# Read packages from packages.txt
packages_data=$(read_stack_packages "$SCRIPT_DIR")
IFS='|' read -r pacman_list aur_list <<< "$packages_data"

# Combine all packages (pacman + aur) for removal
all_pkgs="$pacman_list $aur_list"

if [[ -n "$all_pkgs" ]]; then
  echo "$FRAMEWORK_UNINSTALL_REMOVING"
  for pkg in $all_pkgs; do
    remove_pkg "$pkg"
  done
fi

# Remove balorcve installed via pipx if present
if command -v pipx >/dev/null 2>&1; then
  if pipx list 2>/dev/null | grep -q 'balorcve'; then
    echo "[Framework] Uninstalling balorcve (pipx)..."
    pipx uninstall balorcve || true
  fi
fi

echo ""
echo "=========================================="
echo "$FRAMEWORK_UNINSTALL_COMPLETE"
echo "=========================================="
echo ""
