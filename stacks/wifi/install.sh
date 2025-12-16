#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

ROGUEHOSTAPD_DIR="/opt/roguehostapd"
WIFIPHISHER_DIR="/opt/wifiphisher"

install_roguehostapd() {
  echo "$WIFI_INSTALL_ROGUEHOSTAPD_PYTHON"

  # Dépendances
  install_pacman_pkg git
  install_pacman_pkg python
  install_pacman_pkg python-setuptools

  # Cloner ou mettre à jour le fork Idenroad
  if [[ -d "$ROGUEHOSTAPD_DIR/.git" ]]; then
    echo "  $WIFI_ROGUEHOSTAPD_UPDATE"
    sudo git -C "$ROGUEHOSTAPD_DIR" pull --rebase
  else
    echo "  $WIFI_ROGUEHOSTAPD_CLONE"
    sudo git clone https://github.com/Idenroad/roguehostapd.git "$ROGUEHOSTAPD_DIR"
  fi

  echo "  $WIFI_SETUP_PYTHON"
  local py="python3"
  command -v python3 >/dev/null 2>&1 || py="python"

  cd "$ROGUEHOSTAPD_DIR"
  sudo "$py" setup.py install
  cd - >/dev/null

  echo "$WIFI_ROGUEHOSTAPD_PYTHON_INSTALLED"
}

install_wifiphisher() {
  echo "$WIFI_INSTALL_WIFIPHISHER"

  # Vérifier Python
  if ! command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    echo "  $WIFI_PYTHON_NOT_DETECTED"
    install_pacman_pkg python
  fi

  # Vérifier git
  if ! command -v git >/dev/null 2>&1; then
    echo "  $WIFI_GIT_NOT_DETECTED"
    install_pacman_pkg git
  fi

  # Cloner ou mettre à jour le fork Idenroad
  if [[ -d "$WIFIPHISHER_DIR/.git" ]]; then
    echo "  $WIFI_WIFIPHISHER_UPDATE"
    sudo git -C "$WIFIPHISHER_DIR" pull --rebase
  else
    echo "  $WIFI_WIFIPHISHER_CLONE"
    sudo git clone https://github.com/Idenroad/wifiphisher.git "$WIFIPHISHER_DIR"
  fi

  # Installer via setup.py
  echo "  $WIFI_SETUP_PYTHON"
  local py="python3"
  command -v python3 >/dev/null 2>&1 || py="python"

  cd "$WIFIPHISHER_DIR"
  sudo "$py" setup.py install
  cd - >/dev/null

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
