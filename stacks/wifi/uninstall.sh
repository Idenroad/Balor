#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

WIFIPHISHER_DIR="/opt/wifiphisher"
ROGUEHOSTAPD_DIR="/opt/roguehostapd"

uninstall_wifiphisher() {
  echo "[WiFi] Désinstallation de wifiphisher..."

  if [[ -d "$WIFIPHISHER_DIR" ]]; then
    echo "  [RM] Suppression de $WIFIPHISHER_DIR..."
    sudo rm -rf "$WIFIPHISHER_DIR"
  else
    echo "  [SKIP] Répertoire $WIFIPHISHER_DIR non trouvé."
  fi

  # Nettoyage du binaire wrapper s'il existe
  if [[ -f /usr/bin/wifiphisher ]]; then
    echo "  [RM] Suppression de /usr/bin/wifiphisher..."
    sudo rm -f /usr/bin/wifiphisher
  fi

  echo "[WiFi] wifiphisher désinstallé."
}

uninstall_roguehostapd_python() {
  echo "[WiFi] Désinstallation de roguehostapd (module Python + repo Git)..."

  # 1) Supprimer le repo Git /opt/roguehostapd
  if [[ -d "$ROGUEHOSTAPD_DIR" ]]; then
    echo "  [RM] Suppression de $ROGUEHOSTAPD_DIR..."
    sudo rm -rf "$ROGUEHOSTAPD_DIR"
  else
    echo "  [SKIP] Répertoire $ROGUEHOSTAPD_DIR non trouvé."
  fi

  # 2) Essayer de supprimer le module Python de site-packages (best effort)
  # On vise Python 3.13 + peut-être d'autres versions installées.
  for ver in 3.13 3.12 3.11; do
    site="/usr/lib/python${ver}/site-packages"
    if [[ -d "${site}" ]]; then
      if [[ -d "${site}/roguehostapd" ]]; then
        echo "  [RM] Suppression du paquet Python roguehostapd dans ${site}..."
        sudo rm -rf "${site}/roguehostapd"
      fi
      if compgen -G "${site}/roguehostapd*.egg-info" >/dev/null 2>&1; then
        echo "  [RM] Suppression des métadonnées roguehostapd*.egg-info dans ${site}..."
        sudo rm -rf "${site}/roguehostapd"*.egg-info
      fi
    fi
  done

  echo "[WiFi] roguehostapd (module Python) désinstallé (si présent)."
}

echo "[WiFi] Désinstallation de la stack WiFi..."

PKGS_RAW=$(read_stack_packages "$SCRIPT_DIR")
PAC_PKGS="${PKGS_RAW%%|*}"
AUR_PKGS="${PKGS_RAW#*|}"

# 1) Désinstaller wifiphisher (avant les dépendances)
uninstall_wifiphisher

# 2) Désinstaller roguehostapd Python (fork GitHub)
uninstall_roguehostapd_python

# 3) Désinstaller roguehostapd (paquet pacman issu du PKGBUILD)
echo "[WiFi] Désinstallation du paquet roguehostapd..."
remove_pkg "roguehostapd"

# 4) Désinstaller d'abord les paquets AUR
if [[ -n "$AUR_PKGS" ]]; then
  echo "[WiFi] Désinstallation des paquets AUR: $AUR_PKGS"
  for a in $AUR_PKGS; do
    remove_pkg "$a"
  done
fi

# 5) Puis désinstaller les paquets pacman
if [[ -n "$PAC_PKGS" ]]; then
  echo "[WiFi] Désinstallation des paquets pacman: $PAC_PKGS"
  for p in $PAC_PKGS; do
    remove_pkg "$p"
  done
fi

echo ""
echo "[WiFi] ✓ Désinstallation terminée."
echo "[WiFi] Note: python, python-pip et git ont été préservés (paquets protégés)."
echo ""
