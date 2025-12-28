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

# Désinstaller les outils installés via pipx (si présents)
if command -v pipx >/dev/null 2>&1; then
  echo "Suppression des outils installés via pipx (censys, theHarvester)"
  # Désinstaller explicitement les packages attendus
  pipx uninstall --force censys >/dev/null 2>&1 || true
  pipx uninstall --force theHarvester >/dev/null 2>&1 || true
else
  echo "pipx introuvable — ignorer la désinstallation pipx"
fi

# Nettoyage du wrapper Maltego spécifique à la stack
if [[ -f /usr/local/bin/maltego17 ]]; then
  printf "$WIFI_UNINSTALL_REMOVE_BIN\n" "/usr/local/bin/maltego17"
  sudo rm -f /usr/local/bin/maltego17
fi

## recon-ng uninstall removed per user request

echo "$OSINT_UNINSTALL_COMPLETE"
