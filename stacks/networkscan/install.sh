#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source common functions
source "$ROOT_DIR/lib/common.sh"

echo ""
echo "=========================================="
echo " Installation de la Stack de scans réseaux"
echo "=========================================="
echo ""

# On a potentiellement des paquets AUR un jour, donc on garde l'appel
ensure_aur_helper

# Read packages from packages.txt
packages_data=$(read_stack_packages "$SCRIPT_DIR")
IFS='|' read -r pacman_list aur_list <<< "$packages_data"

# Install pacman packages
if [[ -n "$pacman_list" ]]; then
  echo ""
  echo "[Balor] Installation des paquets pacman..."
  for pkg in $pacman_list; do
    install_pacman_pkg "$pkg"
  done
fi

# Normalement, pas d'AUR ici, mais on reste générique
if [[ -n "$aur_list" ]]; then
  echo ""
  echo "[Balor] Installation des paquets AUR..."
  for pkg in $aur_list; do
    install_aur_pkg "$pkg"
  done
fi

echo ""
echo "=========================================="
echo " Stack de scans réseauxz installée!"
echo "=========================================="
echo ""
echo "Outils installés: nmap, masscan, arp-scan, netdiscover, tcpdump, snort" # Mise à jour de la liste
echo ""
echo "Quick start commands:"
echo "  nmap -sV -sC <target>           # Scan de services + scripts par défaut"
echo "  masscan -p1-65535 <target>      # Scan de ports ultra-rapide"
echo "  arp-scan -l                     # Découverte d'hôtes sur le LAN"
echo "  netdiscover -i <iface>          # Découverte d'hôtes via ARP"
echo "  tcpdump -i <iface>              # Capture de trafic brut"
echo "  snort -i <iface> -c /etc/snort/snort.conf  # IDS en mode console"
echo ""
echo "[!] Utiliser ces outils uniquement sur des systèmes autorisés."
echo ""
