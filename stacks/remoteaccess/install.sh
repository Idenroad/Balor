#!/usr/bin/env bash

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Source des fonctions communes
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

echo ""
echo "=========================================="
echo " Installation de la stack Remote"
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
echo " Stack Remote installée !"
echo "=========================================="
echo ""
echo "Outils principaux installés :"
echo "  - openssh (ssh, scp, sftp)"
echo "  - freerdp (xfreerdp) pour RDP"
echo "  - rdesktop (client RDP alternatif)"
echo "  - smbclient pour SMB/CIFS"
echo "  - rpcbind, nfs-utils pour NFS"
echo "  - remmina (client multi-protocoles RDP/VNC/SSH avec GUI)"
echo ""
echo "Exemples de commandes (quick start) :"
echo "  ssh user@cible                             # Connexion SSH"
echo "  xfreerdp /v:cible.local /u:user            # Connexion RDP avec FreeRDP"
echo "  rdesktop cible.local                       # Connexion RDP avec rdesktop"
echo "  smbclient //cible/share -U user            # Connexion à un partage SMB"
echo "  sudo mount -t nfs cible:/export /mnt/nfs   # Montage NFS"
echo "  remmina                                    # Lancer l'interface graphique"
echo ""
echo "[!] Utilisez ces outils uniquement dans un cadre légal et avec autorisation."
echo ""
