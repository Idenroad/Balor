#!/usr/bin/env bash

set -e

# Version de l'installateur
VERSION="${VERSION:-0.5.1}"

DARKCACHY_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=lib/common.sh
source "$BALOR_ROOT/lib/common.sh"

STACKS_DIR="$BALOR_ROOT/stacks"
BANNER_FILE="$BALOR_ROOT/banner.txt"

# Affichage du banner Idenroad / Balor
echo
if [[ -f "$BANNER_FILE" ]]; then
  cat "$BANNER_FILE"
else
  echo "Balor – Powered by Idenroad"
fi
echo
echo "Have fun in your Hacking Journey"
echo "=== Balor Installer – Powered by Idenroad ==="
echo

list_stacks() {
  find "$STACKS_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort
}

install_stack() {
  local stack="$1"
  local script="$STACKS_DIR/$stack/install.sh"
  if [[ -x "$script" ]]; then
    bash "$script"
  else
    echo "[!] Script d'installation introuvable pour: $stack"
  fi
}

uninstall_stack() {
  local stack="$1"
  local script="$STACKS_DIR/$stack/uninstall.sh"
  if [[ -x "$script" ]]; then
    bash "$script"
  else
    echo "[!] Script de désinstallation introuvable pour: $stack"
  fi
}

menu_install_specific() {
  echo "=== Installer une stack spécifique ==="
  echo "Stacks disponibles :"
  local i=1
  local stacks=()
  while IFS= read -r s; do
    stacks+=("$s")
    echo "  $i) $s"
    ((i++))
  done < <(list_stacks)

  echo "  0) Retour"
  read -rp "Choix: " choice

  if [[ "$choice" == "0" ]]; then
    return
  fi

  local idx=$((choice-1))
  local sel="${stacks[$idx]}"

  if [[ -n "$sel" ]]; then
    install_stack "$sel"
  else
    echo "[!] Choix invalide."
  fi
}

menu_uninstall() {
  echo "=== Désinstaller une stack ==="
  echo "Stacks disponibles :"
  local i=1
  local stacks=()
  while IFS= read -r s; do
    stacks+=("$s")
    echo "  $i) $s"
    ((i++))
  done < <(list_stacks)

  echo "  0) Retour"
  read -rp "Choix: " choice

  if [[ "$choice" == "0" ]]; then
    return
  fi

  local idx=$((choice-1))
  local sel="${stacks[$idx]}"

  if [[ -n "$sel" ]]; then
    uninstall_stack "$sel"
  else
    echo "[!] Choix invalide."
  fi
}

install_all() {
  echo "=== Installation de TOUTES les stacks ==="
  while IFS= read -r s; do
    echo "[Balor] Installation stack: $s"
    install_stack "$s"
  done < <(list_stacks)
  echo "[Balor] Installation complète terminée."
}

update_all() {
  echo "=== Mise à jour système + AUR ==="
  echo "[Balor] pacman -Syu..."
  sudo pacman -Syu --noconfirm

  if have_paru; then
    echo "[Balor] Mise à jour AUR via paru..."
    paru -Syu --noconfirm
  else
    echo "[Balor] paru non présent, pas de mise à jour AUR."
  fi

  echo
  echo "[NOTE] Si tu modifies packages.txt, relance l'install de la stack concernée."
}

ensure_stack_scripts_executable() {
  find "$STACKS_DIR" -type f -name "*.sh" -print0 | while IFS= read -r -d '' f; do
    chmod +x "$f"
  done
}

main_menu() {
  while true; do
    echo
    echo "==== Balor ${VERSION} - Hacker RPG IRL ===="
    echo "1) Installer TOUTES les stacks"
    echo "2) Installer une stack"
    echo "3) Désinstaller une stack"
    echo "4) Mettre à jour (système + AUR)"
    echo "5) Quitter"
    read -rp "Choix: " choice

    case "$choice" in
      1) install_all ;;
      2) menu_install_specific ;;
      3) menu_uninstall ;;
      4) update_all ;;
      5) echo "[Idenroad] Bye."; exit 0 ;;
      *) echo "[!] Choix invalide." ;;
    esac
  done
}

ensure_stack_scripts_executable
main_menu
