#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source des fonctions communes
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

echo ""
echo "=========================================="
echo " Installation de la stack Password"
echo "=========================================="
echo ""

# S'assurer qu'un helper AUR (paru) est disponible
ensure_aur_helper

# Lecture des paquets depuis packages.txt
packages_data=$(read_stack_packages "$SCRIPT_DIR")
IFS='|' read -r pacman_list aur_list <<< "$packages_data"

# Installation des paquets pacman
if [[ -n "$pacman_list" ]]; then
  echo ""
  echo "[Balor] Installation des paquets pacman..."
  for pkg in $pacman_list; do
    install_pacman_pkg "$pkg"
  done
fi

# Installation des paquets AUR
if [[ -n "$aur_list" ]]; then
  echo ""
  echo "[Balor] Installation des paquets AUR..."
  for pkg in $aur_list; do
    install_aur_pkg "$pkg"
  done
fi

echo ""
echo "=========================================="
echo " Stack Password installée !"
echo "=========================================="
echo ""
echo "Outils principaux installés :"
echo "  - hashcat, hashcat-utils, hcxkeys"
echo "  - handshake-cracker"
echo "  - john (John the Ripper)"
echo "  - medusa, ncrack"
echo "  - crunch, rainbowcrack"
echo "  - hashid, wordlists"
echo ""
echo "Exemples de commandes (quick start) :"
echo "  hashcat -m <mode> -a 0 hash.txt wordlist.txt      # Crack de hash avec dictionnaire"
echo "  john --wordlist=wordlist.txt hash.txt             # Crack avec John the Ripper"
echo "  medusa -h <hôte> -u <user> -P wordlist.txt -M <service>   # Bruteforce login"
echo "  ncrack -p 22,3389 <cible>                         # Audit de services réseau"
echo "  crunch 8 8 abcdef1234 -o custom.txt               # Génération de wordlist"
echo "  hashid 'hash_ici'                                 # Identification de type de hash"
echo ""
echo "[!] Utilisez ces outils uniquement dans un cadre légal et avec autorisation."
echo ""
