#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

printf "$INSTALL_STACK_START\n" "OSINT"

ensure_aur_helper

PKGS_RAW=$(read_stack_packages "$SCRIPT_DIR")
PAC_PKGS="${PKGS_RAW%%|*}"
AUR_PKGS="${PKGS_RAW#*|}"

for p in $PAC_PKGS; do
  install_pacman_pkg "$p"
done

for a in $AUR_PKGS; do
  install_aur_pkg "$a"
done

# Assurer que pipx est présent puis installer certains outils via pipx
if ! command -v pipx >/dev/null 2>&1; then
  echo "pipx introuvable — tentative d'installation via pacman..."
  sudo pacman -S --needed --noconfirm python-pipx || true
fi

if command -v pipx >/dev/null 2>&1; then
  echo "Installation via pipx: censys, theHarvester"
  # installer censys
  pipx install git+https://github.com/censys/censys-python.git --force || echo "pipx install censys failed"
  # installer theHarvester
  pipx install git+https://github.com/laramies/theHarvester.git --force || echo "pipx install theHarvester failed"
else
  echo "pipx non disponible — ignorer l'installation via pipx (installez python-pipx et relancez)."
fi

echo "$OSINT_INSTALL_JRE17"
if ! sudo pacman -S --needed --noconfirm jre17-openjdk; then
  echo "$OSINT_JRE17_FAILED"
  echo "$OSINT_JRE17_ENSURE_JDK"
fi

# Préconfiguration de Maltego pour utiliser Java 17 par défaut pour l'utilisateur courant
JAVA17_HOME="/usr/lib/jvm/java-17-openjdk"
USER_MALTEGO_ETC="$HOME/.maltego/v4.8.1/etc"
USER_MALTEGO_CONF="$USER_MALTEGO_ETC/maltego.conf"

if [[ -d "$JAVA17_HOME" ]]; then
  echo "$OSINT_MALTEGO_CONFIG"
  mkdir -p "$USER_MALTEGO_ETC"

  if [[ -f "$USER_MALTEGO_CONF" ]]; then
    # Si le fichier existe déjà, on ne touche qu'à jdkhome
    if grep -q '^jdkhome=' "$USER_MALTEGO_CONF"; then
      sed -i 's|^jdkhome=.*|jdkhome="'"$JAVA17_HOME"'"|' "$USER_MALTEGO_CONF"
    else
      echo 'jdkhome="'"$JAVA17_HOME"'"' >> "$USER_MALTEGO_CONF"
    fi
  else
    # Fichier minimal si inexistant
    cat > "$USER_MALTEGO_CONF" << EOF
default_userdir="\${DEFAULT_USERDIR_ROOT}/v4.8.1"
jdkhome="$JAVA17_HOME"
EOF
  fi
else
  printf "$OSINT_JAVA17_NOT_FOUND\n" "$JAVA17_HOME"
  echo "$OSINT_VERIFY_JAVA17"
fi

# Créer le dossier data pour marquer l'installation
ensure_stack_data_dir "osint"

echo "$OSINT_INSTALL_COMPLETE_MSG"
echo ""
echo "$OSINT_MALTEGO_PRECONFIGURED"
echo "$OSINT_MALTEGO_ALTERNATIVE"
printf "$OSINT_MALTEGO_CMD\n" "$JAVA17_HOME"
echo ""

## recon-ng installer removed per user request
