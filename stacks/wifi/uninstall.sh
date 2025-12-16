#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

WIFIPHISHER_DIR="/opt/wifiphisher"
ROGUEHOSTAPD_DIR="/opt/roguehostapd"

uninstall_wifiphisher() {
  echo "$WIFI_UNINSTALL_WIFIPHISHER"

  if [[ -d "$WIFIPHISHER_DIR" ]]; then
    printf "$WIFI_UNINSTALL_REMOVE_DIR\n" "$WIFIPHISHER_DIR"
    sudo rm -rf "$WIFIPHISHER_DIR"
  else
    printf "$WIFI_UNINSTALL_SKIP_DIR\n" "$WIFIPHISHER_DIR"
  fi

  # Nettoyage du binaire wrapper s'il existe
  if [[ -f /usr/bin/wifiphisher ]]; then
    printf "$WIFI_UNINSTALL_REMOVE_BIN\n" "/usr/bin/wifiphisher"
    sudo rm -f /usr/bin/wifiphisher
  fi

  printf "$WIFI_UNINSTALL_DONE\n" "wifiphisher"
}

uninstall_roguehostapd() {
  echo "$WIFI_UNINSTALL_ROGUEHOSTAPD"

  # 1) Supprimer le repo Git /opt/roguehostapd
  if [[ -d "$ROGUEHOSTAPD_DIR" ]]; then
    printf "$WIFI_UNINSTALL_REMOVE_DIR\n" "$ROGUEHOSTAPD_DIR"
    sudo rm -rf "$ROGUEHOSTAPD_DIR"
  else
    printf "$WIFI_UNINSTALL_SKIP_DIR\n" "$ROGUEHOSTAPD_DIR"
  fi

  # 2) Essayer de supprimer le module Python de site-packages (best effort)
  # On vise Python 3.13 + peut-être d'autres versions installées.
  for ver in 3.13 3.12 3.11; do
    site="/usr/lib/python${ver}/site-packages"
    if [[ -d "${site}" ]]; then
      if [[ -d "${site}/roguehostapd" ]]; then
        printf "$WIFI_UNINSTALL_REMOVE_DIR\n" "${site}/roguehostapd"
        sudo rm -rf "${site}/roguehostapd"
      fi
      if compgen -G "${site}/roguehostapd*.egg-info" >/dev/null 2>&1; then
        printf "$WIFI_UNINSTALL_REMOVE_DIR\n" "${site}/roguehostapd*.egg-info"
        sudo rm -rf "${site}/roguehostapd"*.egg-info
      fi
    fi
  done

  printf "$WIFI_UNINSTALL_DONE\n" "roguehostapd"
}

echo "$WIFI_UNINSTALL_REMOVING"

PKGS_RAW=$(read_stack_packages "$SCRIPT_DIR")
PAC_PKGS="${PKGS_RAW%%|*}"
AUR_PKGS="${PKGS_RAW#*|}"

# 1) Désinstaller wifiphisher (avant les dépendances)
uninstall_wifiphisher

# 2) Désinstaller roguehostapd
uninstall_roguehostapd

# 3) Désinstaller d'abord les paquets AUR
if [[ -n "$AUR_PKGS" ]]; then
  printf "$INSTALL_AUR_PACKAGES\n"
  for a in $AUR_PKGS; do
    remove_pkg "$a"
  done
fi

# 4) Puis désinstaller les paquets pacman
if [[ -n "$PAC_PKGS" ]]; then
  printf "$INSTALL_PACMAN_PACKAGES\n"
  for p in $PAC_PKGS; do
    remove_pkg "$p"
  done
fi

echo ""
echo "$WIFI_UNINSTALL_COMPLETE"
echo ""
