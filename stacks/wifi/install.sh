#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

ROGUE_PKG_DIR="$SCRIPT_DIR/pkgs/roguehostapd"
ROGUEHOSTAPD_DIR="/opt/roguehostapd"
WIFIPHISHER_DIR="/opt/wifiphisher"

install_roguehostapd_pkg() {
  echo "[WiFi] Installation du paquet roguehostapd via PKGBUILD (hostapd patché)..."

  # Dépendances de build
  install_pacman_pkg git
  install_pacman_pkg base-devel
  install_pacman_pkg python
  install_pacman_pkg python-setuptools
  install_pacman_pkg libnfnetlink
  install_pacman_pkg libnl

  if pacman -Qi roguehostapd >/dev/null 2>&1; then
    echo "  [OK] paquet roguehostapd déjà installé (via pacman)."
    return
  fi

  if [[ ! -f "$ROGUE_PKG_DIR/PKGBUILD" ]]; then
    echo "  [ERREUR] PKGBUILD roguehostapd introuvable dans $ROGUE_PKG_DIR"
    return 1
  fi

  tmpdir=$(mktemp -d)
  echo "  [BUILD] Copie de PKGBUILD + hostapdconfig.py.new dans $tmpdir ..."
  cp "$ROGUE_PKG_DIR/PKGBUILD" "$ROGUE_PKG_DIR/hostapdconfig.py.new" "$tmpdir/"
  cd "$tmpdir"

  echo "  [BUILD] makepkg -si ..."
  makepkg -si --noconfirm

  cd - >/dev/null
  rm -rf "$tmpdir"

  echo "[WiFi] roguehostapd (paquet) installé via PKGBUILD."
}

install_roguehostapd_python() {
  echo "[WiFi] Installation de roguehostapd (module Python depuis ton fork GitHub)..."

  # Dépendances
  install_pacman_pkg git
  install_pacman_pkg python
  install_pacman_pkg python-setuptools

  # Si le module Python est déjà importable, on considère que c'est bon
  if python -c "import roguehostapd" >/dev/null 2>&1; then
    echo "  [OK] module Python roguehostapd déjà présent."
    # Si tu veux forcer la mise à jour du repo / reinstall, tu peux commenter ce return.
    return
  fi

  # Cloner ou mettre à jour ton fork
  if [[ -d "$ROGUEHOSTAPD_DIR/.git" ]]; then
    echo "  [INFO] Répertoire roguehostapd déjà présent, mise à jour depuis GitHub..."
    sudo git -C "$ROGUEHOSTAPD_DIR" pull --rebase
  else
    echo "  [CLONE] git clone Idenroad/roguehostapd..."
    sudo git clone https://github.com/Idenroad/roguehostapd.git "$ROGUEHOSTAPD_DIR"
  fi

  echo "  [SETUP] python setup.py install..."
  local py="python3"
  command -v python3 >/dev/null 2>&1 || py="python"

  cd "$ROGUEHOSTAPD_DIR"
  sudo "$py" setup.py install
  cd - >/dev/null

  echo "[WiFi] roguehostapd (module Python) installé depuis ton fork."
}

install_wifiphisher() {
  echo "[WiFi] Installation de wifiphisher depuis GitHub..."

  # Vérifier Python
  if ! command -v python >/dev/null 2>&1 && ! command -v python3 >/dev/null 2>&1; then
    echo "  [INFO] Python n'est pas détecté dans le PATH, installation via pacman..."
    install_pacman_pkg python
  fi

  # Vérifier git
  if ! command -v git >/dev/null 2>&1; then
    echo "  [INFO] git n'est pas détecté dans le PATH, installation via pacman..."
    install_pacman_pkg git
  fi

  # Cloner ou mettre à jour le repo
  if [[ -d "$WIFIPHISHER_DIR/.git" ]]; then
    echo "  [INFO] Répertoire wifiphisher déjà présent, mise à jour..."
    sudo git -C "$WIFIPHISHER_DIR" pull --rebase
  else
    echo "  [CLONE] git clone wifiphisher..."
    sudo git clone https://github.com/wifiphisher/wifiphisher.git "$WIFIPHISHER_DIR"
  fi

  # Installer via setup.py
  echo "  [SETUP] python setup.py install..."
  local py="python3"
  command -v python3 >/dev/null 2>&1 || py="python"

  cd "$WIFIPHISHER_DIR"
  sudo "$py" setup.py install
  cd - >/dev/null

  echo "[WiFi] wifiphisher installé."
}

patch_pyric_rfkill() {
  echo "[WiFi] Patch de pyric/utils/rfkill.py pour Python 3.13..."

  local rfkill_py="/usr/lib/python3.13/site-packages/pyric/utils/rfkill.py"

  if [[ ! -f "$rfkill_py" ]]; then
    echo "  [SKIP] $rfkill_py introuvable, pyric n'est peut-être pas installé."
    return
  fi

  # Vérifier si le patch est déjà appliqué
  if grep -A5 "def rfkill_unblock(idx):" "$rfkill_py" | grep -q "if _PY3_:"; then
    echo "  [SKIP] Patch déjà appliqué sur rfkill_unblock."
    return
  fi

  echo "  [PATCH] Application du patch sur rfkill_unblock..."

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

  echo "[WiFi] Patch pyric terminé."
}

echo "[WiFi] Installation de la stack WiFi..."

ensure_aur_helper

PKGS_RAW=$(read_stack_packages "$SCRIPT_DIR")
PAC_PKGS="${PKGS_RAW%%|*}"
AUR_PKGS="${PKGS_RAW#*|}"

echo "[WiFi] Installation des paquets pacman..."
for p in $PAC_PKGS; do
  install_pacman_pkg "$p"
done

echo "[WiFi] Installation des paquets AUR..."
for a in $AUR_PKGS; do
  install_aur_pkg "$a"
done

install_roguehostapd_pkg      # hostapd patché via PKGBUILD
install_roguehostapd_python   # module Python via ton fork GitHub
install_wifiphisher
patch_pyric_rfkill

echo ""
echo "[WiFi] ✓ Stack WiFi installée avec succès."
echo "[WiFi] Outils disponibles:"
echo "  - aircrack-ng, hostapd, dnsmasq"
echo "  - bettercap, wireshark"
echo "  - airgeddon, hcxdumptool, hcxtools"
echo "  - roguehostapd (paquet + module Python fork Idenroad), wifiphisher"
echo ""
echo "[WiFi] Note importante:"
echo "  Pour wifiphisher, il est recommandé d'utiliser une 2ᵉ carte Wi-Fi USB dédiée."
echo "  Tu peux réduire les bugs en faisant par exemple :"
echo "    sudo nmcli dev set wlan1 managed no"
echo ""
