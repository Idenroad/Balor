#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

install_roguehostapd() {
  echo "$WIFI_INSTALL_ROGUEHOSTAPD_PYTHON"

  # Nettoyer le cache pip et installer via pip depuis git
  echo "  $WIFI_SETUP_PYTHON"
  # S'assurer que argparse est disponible pour l'environnement Python3 utilisé
  if ! python3 -c "import argparse" >/dev/null 2>&1; then
    echo "  Installation d'argparse pour Python3..."
    sudo python3 -m pip install --break-system-packages --no-cache-dir argparse || true
  fi
  sudo python3 -m pip cache purge || true
  sudo python3 -m pip install --break-system-packages --no-cache-dir --force-reinstall git+https://github.com/Idenroad/roguehostapd.git

  echo "$WIFI_ROGUEHOSTAPD_PYTHON_INSTALLED"
}

install_wifiphisher() {
  echo "$WIFI_INSTALL_WIFIPHISHER"

  # Nettoyer le cache pip et installer via pip depuis git
  echo "  $WIFI_SETUP_PYTHON"
  # S'assurer que argparse est disponible pour l'environnement Python3 utilisé
  if ! python3 -c "import argparse" >/dev/null 2>&1; then
    echo "  Installation d'argparse pour Python3..."
    sudo python3 -m pip install --break-system-packages --no-cache-dir argparse || true
  fi
  sudo python3 -m pip cache purge || true
  sudo python3 -m pip install --break-system-packages --no-cache-dir --force-reinstall git+https://github.com/Idenroad/wifiphisher.git

  echo "$WIFI_WIFIPHISHER_INSTALLED"
}

printf "$INSTALL_STACK_START\n" "WiFi"

ensure_aur_helper

PKGS_RAW=$(read_stack_packages "$SCRIPT_DIR")
PAC_PKGS="${PKGS_RAW%%|*}"
AUR_PKGS="${PKGS_RAW#*|}"

echo "$INSTALL_PACMAN_PACKAGES"
for p in $PAC_PKGS; do
  install_pacman_pkg "$p"
done

echo "$INSTALL_AUR_PACKAGES"
for a in $AUR_PKGS; do
  install_aur_pkg "$a"
done

install_roguehostapd
install_wifiphisher

# Créer le dossier data pour marquer l'installation
ensure_stack_data_dir "wifi"

echo ""
printf "$INSTALL_STACK_COMPLETE\n" "WiFi"
echo "$WIFI_TOOLS_AVAILABLE"
echo "  $WIFI_TOOLS_LIST_1"
echo "  $WIFI_TOOLS_LIST_2"
echo "  $WIFI_TOOLS_LIST_3"
echo "  $WIFI_TOOLS_LIST_4"
echo ""
echo "$WIFI_NOTE_IMPORTANT"
echo "  $WIFI_NOTE_2ND_CARD"
echo "  $WIFI_NOTE_REDUCE_BUGS"
echo "    $WIFI_NOTE_NMCLI_CMD"
echo ""
