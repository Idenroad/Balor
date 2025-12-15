#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

ROGUE_PKG_DIR="$SCRIPT_DIR/pkgs/roguehostapd"
ROGUEHOSTAPD_DIR="/opt/roguehostapd"
WIFIPHISHER_DIR="/opt/wifiphisher"

install_roguehostapd_pkg() {
  echo "$WIFI_INSTALL_ROGUEHOSTAPD_PKG"

  # Dépendances de build
  install_pacman_pkg git
  install_pacman_pkg base-devel
  install_pacman_pkg python
  install_pacman_pkg python-setuptools
  install_pacman_pkg libnfnetlink
  install_pacman_pkg libnl

  if pacman -Qi roguehostapd >/dev/null 2>&1; then
    echo "  $WIFI_ROGUEHOSTAPD_ALREADY"
    return
  fi

  if [[ ! -f "$ROGUE_PKG_DIR/PKGBUILD" ]]; then
    printf "  $WIFI_PKGBUILD_NOT_FOUND\n" "$ROGUE_PKG_DIR"
    return 1
  fi

  tmpdir=$(mktemp -d)
  printf "  $WIFI_BUILD_COPY\n" "$tmpdir"
  cp "$ROGUE_PKG_DIR/PKGBUILD" "$ROGUE_PKG_DIR/hostapdconfig.py.new" "$tmpdir/"
  cd "$tmpdir"

  echo "  $WIFI_BUILD_MAKEPKG"
  makepkg -si --noconfirm

  cd - >/dev/null
  rm -rf "$tmpdir"

  echo "$WIFI_ROGUEHOSTAPD_PKG_INSTALLED"
}

install_roguehostapd_python() {
  echo "$WIFI_INSTALL_ROGUEHOSTAPD_PYTHON"

  # Dépendances
  install_pacman_pkg git
  install_pacman_pkg python
  install_pacman_pkg python-setuptools

  # Si le module Python est déjà importable, on considère que c'est bon
  if python -c "import roguehostapd" >/dev/null 2>&1; then
    echo "  $WIFI_ROGUEHOSTAPD_PYTHON_ALREADY"
    # Si tu veux forcer la mise à jour du repo / reinstall, tu peux commenter ce return.
    return
  fi

  # Cloner ou mettre à jour ton fork
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

  # Cloner ou mettre à jour le repo
  if [[ -d "$WIFIPHISHER_DIR/.git" ]]; then
    echo "  $WIFI_WIFIPHISHER_UPDATE"
    sudo git -C "$WIFIPHISHER_DIR" pull --rebase
  else
    echo "  $WIFI_WIFIPHISHER_CLONE"
    sudo git clone https://github.com/wifiphisher/wifiphisher.git "$WIFIPHISHER_DIR"
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

patch_pyric_rfkill() {
  echo "$WIFI_PATCH_PYRIC"

  local rfkill_py="/usr/lib/python3.13/site-packages/pyric/utils/rfkill.py"

  if [[ ! -f "$rfkill_py" ]]; then
    printf "  $WIFI_RFKILL_NOT_FOUND\n" "$rfkill_py"
    return
  fi

  # Vérifier si le patch est déjà appliqué
  if grep -A5 "def rfkill_unblock(idx):" "$rfkill_py" | grep -q "if _PY3_:"; then
    echo "  $WIFI_PATCH_ALREADY_APPLIED"
    return
  fi

  echo "  $WIFI_APPLYING_PATCH"

  sudo python3 - << 'EOF'
import io
import re

path = "/usr/lib/python3.13/site-packages/pyric/utils/rfkill.py"

with io.open(path, "r", encoding="utf-8") as f:
    src = f.read()

pattern = r"(def rfkill_unblock\(idx\):.*?)(def rfkill_unblockby)"
replacement = r'''def rfkill_unblock(idx):
    """
     unblocks the device at index
     :param idx: rkill index
    """
    if not os.path.exists(os.path.join(spath, "rfkill{0}".format(idx))):
        raise pyric.error(errno.ENODEV, "No device at {0}".format(idx))
    fout = None
    try:
        rfke = rfkh.rfkill_event(idx, rfkh.RFKILL_TYPE_ALL,
                                 rfkh.RFKILL_OP_CHANGE, 0, 0)
        if _PY3_:
            rfke = rfke.decode('ascii')
        fout = open(dpath, 'w')
        fout.write(rfke)
    except struct.error as e:
        raise pyric.error(pyric.EUNDEF,
                          "Error packing rfkill event {0}".format(e))
    except IOError as e:
        raise pyric.error(e.errno, e.message)
    finally:
        if fout:
            fout.close()

def rfkill_unblockby'''

new_src, count = re.subn(pattern, replacement, src, flags=re.DOTALL)

if count == 0:
    print("  [WARN] Impossible de trouver rfkill_unblock à patcher; aucune modif.")
else:
    with io.open(path, "w", encoding="utf-8") as f:
        f.write(new_src)
    print("  [OK] rfkill_unblock patché ({} remplacement).".format(count))
EOF

  echo "$WIFI_PATCH_COMPLETE"
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

install_roguehostapd_pkg      # hostapd patché via PKGBUILD
install_roguehostapd_python   # module Python via ton fork GitHub
install_wifiphisher
patch_pyric_rfkill

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
