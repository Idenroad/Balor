#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

echo "[OSINT] Installation de la stack OSINT..."

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

echo "[OSINT] Installation de jre17-openjdk recommandée pour Maltego..."
if ! sudo pacman -S --needed --noconfirm jre17-openjdk; then
  echo "[OSINT] jre17-openjdk non installé (conflit probable avec jdk17-openjdk)."
  echo "[OSINT] Assurez-vous qu'un JDK 17 est présent (ex: /usr/lib/jvm/java-17-openjdk)."
fi

# Préconfiguration de Maltego pour utiliser Java 17 par défaut pour l'utilisateur courant
JAVA17_HOME="/usr/lib/jvm/java-17-openjdk"
USER_MALTEGO_ETC="$HOME/.maltego/v4.8.1/etc"
USER_MALTEGO_CONF="$USER_MALTEGO_ETC/maltego.conf"

if [[ -d "$JAVA17_HOME" ]]; then
  echo "[OSINT] Configuration de Maltego pour utiliser Java 17 par défaut..."
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
  echo "[OSINT] Attention : $JAVA17_HOME n'existe pas. Impossible de préconfigurer Maltego."
  echo "[OSINT] Vérifiez l'installation de Java 17 (jre17-openjdk ou jdk17-openjdk)."
fi

echo "[OSINT] Installation terminée."
echo ""
echo "[Balor] Maltego est préconfiguré pour utiliser Java 17 (/usr/lib/jvm/java-17-openjdk)"
echo "[Balor] Si vous rencontrez un problème, vous pouvez aussi lancer :"
echo "           maltego --jdkhome \"$JAVA17_HOME\""
echo ""
