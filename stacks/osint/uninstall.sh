#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

echo "$OSINT_UNINSTALL_REMOVING"

PKGS_RAW=$(read_stack_packages "$SCRIPT_DIR")
PAC_PKGS="${PKGS_RAW%%|*}"
AUR_PKGS="${PKGS_RAW#*|}"

# Suppression des paquets (pacman + AUR)
for p in $PAC_PKGS $AUR_PKGS; do
  remove_pkg "$p"
done

# Nettoyage du wrapper Maltego spécifique à la stack
if [[ -f /usr/local/bin/maltego17 ]]; then
  printf "$WIFI_UNINSTALL_REMOVE_BIN\n" "/usr/local/bin/maltego17"
  sudo rm -f /usr/local/bin/maltego17
fi

echo "$OSINT_UNINSTALL_COMPLETE"
