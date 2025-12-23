#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

WIFIPHISHER_DIR="/opt/wifiphisher"
ROGUEHOSTAPD_DIR="/opt/roguehostapd"

uninstall_wifiphisher() {
  echo "$WIFI_UNINSTALL_WIFIPHISHER"

  # Désinstaller le module Python installé via pip
  printf "$WIFI_UNINSTALL_REMOVE_PIPMODULE\n" "wifiphisher"
  # Utiliser python3 -m pip pour cibler correctement l'environnement Python3
  if sudo python3 -m pip uninstall -y wifiphisher >/dev/null 2>&1; then
    true
  else
    # Fallback to legacy pip if present
    sudo pip uninstall -y wifiphisher >/dev/null 2>&1 || printf "$WIFI_UNINSTALL_PIPMODULE_NOT_INSTALLED\n" "wifiphisher"
  fi

  if [[ -d "$WIFIPHISHER_DIR" ]]; then
    printf "$WIFI_UNINSTALL_REMOVE_DIR\n" "$WIFIPHISHER_DIR"
    sudo rm -rf "$WIFIPHISHER_DIR"
  else
    printf "$WIFI_UNINSTALL_SKIP_DIR\n" "$WIFIPHISHER_DIR"
  fi

  # Nettoyage du binaire wrapper s'il existe
  for binpath in /usr/bin/wifiphisher /usr/local/bin/wifiphisher; do
    if [[ -f "$binpath" ]]; then
      printf "$WIFI_UNINSTALL_REMOVE_BIN\n" "$binpath"
      sudo rm -f "$binpath"
    fi
  done

  # Supprimer les traces dans site-packages (divers emplacements possibles)
  for site in /usr/lib/python*/site-packages /usr/local/lib/python*/site-packages /usr/lib/python*/dist-packages /usr/local/lib/python*/dist-packages; do
    if compgen -G "$site/wifiphisher*" >/dev/null 2>&1; then
      printf "$WIFI_UNINSTALL_REMOVE_DIR\n" "$site/wifiphisher*"
      sudo rm -rf $site/wifiphisher*
    fi
  done

  printf "$WIFI_UNINSTALL_DONE\n" "wifiphisher"
}

uninstall_roguehostapd() {
  echo "$WIFI_UNINSTALL_ROGUEHOSTAPD"

  # Désinstaller le module Python installé via pip
  printf "$WIFI_UNINSTALL_REMOVE_PIPMODULE\n" "roguehostapd"
  if sudo python3 -m pip uninstall -y roguehostapd >/dev/null 2>&1; then
    true
  else
    sudo pip uninstall -y roguehostapd >/dev/null 2>&1 || printf "$WIFI_UNINSTALL_PIPMODULE_NOT_INSTALLED\n" "roguehostapd"
  fi

  # 1) Supprimer le repo Git /opt/roguehostapd s'il existe
  if [[ -d "$ROGUEHOSTAPD_DIR" ]]; then
    printf "$WIFI_UNINSTALL_REMOVE_DIR\n" "$ROGUEHOSTAPD_DIR"
    sudo rm -rf "$ROGUEHOSTAPD_DIR"
  else
    printf "$WIFI_UNINSTALL_SKIP_DIR\n" "$ROGUEHOSTAPD_DIR"
  fi

  # 2) Supprimer les traces dans site-packages / dist-packages (best-effort)
  for site in /usr/lib/python*/site-packages /usr/local/lib/python*/site-packages /usr/lib/python*/dist-packages /usr/local/lib/python*/dist-packages; do
    if compgen -G "$site/roguehostapd*" >/dev/null 2>&1; then
      printf "$WIFI_UNINSTALL_REMOVE_DIR\n" "$site/roguehostapd*"
      sudo rm -rf $site/roguehostapd*
    fi
  done

  # Supprimer potentiels binaires installés
  for binpath in /usr/bin/roguehostapd /usr/local/bin/roguehostapd; do
    if [[ -f "$binpath" ]]; then
      printf "$WIFI_UNINSTALL_REMOVE_BIN\n" "$binpath"
      sudo rm -f "$binpath"
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
