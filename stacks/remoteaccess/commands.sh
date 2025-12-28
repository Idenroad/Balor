#!/usr/bin/env bash
set -Eeuo pipefail

# stacks/remoteaccess/commands.sh
# Menu Remote Access complet pour balorsh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

# Use centralized palette from lib/common.sh; map legacy local names only
# (do not redefine C_ACCENT*/C_GOOD/C_HIGHLIGHT here)
MAGENTA=${MAGENTA:-${C_ACCENT2:-$C_ACCENT1}}
NC=${NC:-$C_RESET}
GREEN=${GREEN:-${C_GOOD}}
BLUE=${BLUE:-${C_ACCENT2:-$C_ACCENT1}}
CYAN=${CYAN:-${C_INFO}}
YELLOW=${YELLOW:-${C_YELLOW}}
RED=${RED:-${C_RED}}

# Variables globales
: "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
REMOTE_TARGET=""

# ==============================================================================
# FONCTIONS DE VALIDATION D'IP
# ==============================================================================

# Valide une adresse IPv4
validate_ipv4() {
  local ip="$1"
  local stat=1

  if [[ $ip =~ ^([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})\.([0-9]{1,3})$ ]]; then
    local -a octets=(${BASH_REMATCH[1]} ${BASH_REMATCH[2]} ${BASH_REMATCH[3]} ${BASH_REMATCH[4]})
    stat=0
    for octet in "${octets[@]}"; do
      if (( octet > 255 )); then
        stat=1
        break
      fi
    done
  fi
  return $stat
}

# Valide un nom d'hôte
validate_hostname() {
  local hostname="$1"
  if [[ $hostname =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
    return 0
  fi
  return 1
}

# Valide une cible (IP ou hostname)
validate_target() {
  local target="$1"
  
  if validate_ipv4 "$target"; then
    echo -e "${C_GOOD}✓ Adresse IP valide: $target${C_RESET}"
    return 0
  elif validate_hostname "$target"; then
    echo -e "${C_GOOD}✓ Nom d'hôte valide: $target${C_RESET}"
    return 0
  else
    echo -e "${C_RED}✗ Cible invalide: $target${C_RESET}"
    echo -e "${C_INFO}  Format attendu: IP (ex: 192.168.1.10) ou hostname (ex: server.local)${C_RESET}"
    return 1
  fi
}

# Valide un port
validate_port() {
  local port="$1"
  if [[ $port =~ ^[0-9]+$ ]] && (( port > 0 && port <= 65535 )); then
    return 0
  fi
  return 1
}

# ==============================================================================
# FONCTIONS DE SAISIE SÉCURISÉE
# ==============================================================================

# Lit un mot de passe en mode shadow (caché)
read_password() {
  local prompt="$1"
  local password=""
  
  echo -ne "${C_ACCENT1}${prompt}${C_RESET}"
  
  # Désactive l'écho terminal
  stty -echo
  read -r password
  stty echo
  echo ""
  
  echo "$password"
}

# Demande les informations de connexion SSH
prompt_ssh_info() {
  local target port user password
  
  echo -ne "${C_ACCENT1}Adresse IP/Hostname: ${C_RESET}"
  read -r target
  
  if ! validate_target "$target"; then
    return 1
  fi
  
  echo -ne "${C_ACCENT1}Port SSH [22]: ${C_RESET}"
  read -r port
  local port="${port:-22}"
  
  if ! validate_port "$port"; then
    echo -e "${C_RED}✗ Port invalide (doit être entre 1 et 65535)${C_RESET}"
    return 1
  fi
  
  echo -ne "${C_ACCENT1}Nom d'utilisateur: ${C_RESET}"
  read -r user
  
  if [[ -z "$user" ]]; then
    echo -e "${C_RED}✗ Le nom d'utilisateur ne peut pas être vide${C_RESET}"
    return 1
  fi
  
  local password=$(read_password "Mot de passe (optionnel, laissez vide pour authentification par clé): ")
  
  # Exporte les variables pour utilisation
  export REMOTE_TARGET="$target"
  export REMOTE_PORT="$port"
  export REMOTE_USER="$user"
  export REMOTE_PASSWORD="$password"
  
  return 0
}

# Demande les informations de connexion RDP
prompt_rdp_info() {
  local target port user password domain
  
  echo -ne "${C_ACCENT1}Adresse IP/Hostname: ${C_RESET}"
  read -r target
  
  if ! validate_target "$target"; then
    return 1
  fi
  
  echo -ne "${C_ACCENT1}Port RDP [3389]: ${C_RESET}"
  read -r port
  local port="${port:-3389}"
  
  if ! validate_port "$port"; then
    echo -e "${C_RED}✗ Port invalide${C_RESET}"
    return 1
  fi
  
  echo -ne "${C_ACCENT1}Nom d'utilisateur: ${C_RESET}"
  read -r user
  
  echo -ne "${C_ACCENT1}Domaine (optionnel): ${C_RESET}"
  read -r domain
  
  local password=$(read_password "Mot de passe: ")
  
  export REMOTE_TARGET="$target"
  export REMOTE_PORT="$port"
  export REMOTE_USER="$user"
  export REMOTE_PASSWORD="$password"
  export REMOTE_DOMAIN="$domain"
  
  return 0
}

# Demande les informations de connexion Samba
prompt_samba_info() {
  local target share user password domain
  
  echo -ne "${C_ACCENT1}Adresse IP/Hostname: ${C_RESET}"
  read -r target
  
  if ! validate_target "$target"; then
    return 1
  fi
  
  echo -ne "${C_ACCENT1}Nom du partage: ${C_RESET}"
  read -r share
  
  echo -ne "${C_ACCENT1}Nom d'utilisateur (optionnel): ${C_RESET}"
  read -r user
  
  if [[ -n "$user" ]]; then
    echo -ne "${C_ACCENT1}Domaine (optionnel): ${C_RESET}"
    read -r domain
    
    password=$(read_password "Mot de passe: ")
  fi
  
  export REMOTE_TARGET="$target"
  export REMOTE_SHARE="$share"
  export REMOTE_USER="$user"
  export REMOTE_PASSWORD="$password"
  export REMOTE_DOMAIN="$domain"
  
  return 0
}

# Demande les informations de connexion NFS
prompt_nfs_info() {
  local target export_path mount_point nfs_version options
  
  echo -ne "${C_ACCENT1}Adresse IP/Hostname du serveur NFS: ${C_RESET}"
  read -r target
  
  if ! validate_target "$target"; then
    return 1
  fi
  
  echo -ne "${C_ACCENT1}Chemin d'export (ex: /export/share): ${C_RESET}"
  read -r export_path
  
  echo -ne "${C_ACCENT1}Point de montage local [/mnt/nfs]: ${C_RESET}"
  read -r mount_point
  local mount_point="${mount_point:-/mnt/nfs}"
  
  echo -ne "${C_ACCENT1}Version NFS [4]: ${C_RESET}"
  read -r nfs_version
  local nfs_version="${nfs_version:-4}"
  
  echo -ne "${C_ACCENT1}Options de montage (optionnel, ex: rw,sync): ${C_RESET}"
  read -r options
  
  export REMOTE_TARGET="$target"
  export REMOTE_EXPORT="$export_path"
  export REMOTE_MOUNT="$mount_point"
  export NFS_VERSION="$nfs_version"
  export NFS_OPTIONS="$options"
  
  return 0
}

# ==============================================================================
# FONCTIONS DE CONNEXION
# ==============================================================================

# Connexion SSH
remote_ssh_connect() {
  clear
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}Connexion SSH${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  if ! prompt_ssh_info; then
    return 1
  fi
  
  # Créer le répertoire de sessions SSH
  local ssh_dir="$BALORSH_DATA_DIR/remoteaccess/ssh"
  mkdir -p "$ssh_dir"
  
  # Timestamp pour le log
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local session_log="$ssh_dir/session_${REMOTE_TARGET}_${timestamp}.log"
  
  echo ""
  echo -e "${C_INFO}Connexion à ${REMOTE_USER}@${REMOTE_TARGET}:${REMOTE_PORT}...${C_RESET}"
  echo -e "${C_INFO}Session log: ${session_log}${C_RESET}"
  echo ""
  
  # Sauvegarder les informations de session
  {
    echo "=== SSH Session Log ==="
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Target: ${REMOTE_TARGET}"
    echo "Port: ${REMOTE_PORT}"
    echo "User: ${REMOTE_USER}"
    echo "======================"
  } > "$session_log"
  
  # Construction de la commande SSH
  local ssh_cmd="ssh -p ${REMOTE_PORT}"
  
  # Options de sécurité et de debugging
  echo -ne "${C_ACCENT1}Utiliser le mode verbose ? (o/N): ${C_RESET}"
  read -r verbose
  if [[ "$verbose" =~ ^[oO]$ ]]; then
    ssh_cmd="$ssh_cmd -v"
  fi
  
  # Ajouter l'utilisateur et la cible
  ssh_cmd="$ssh_cmd ${REMOTE_USER}@${REMOTE_TARGET}"
  
  # Si un mot de passe est fourni, utiliser sshpass
  if [[ -n "$REMOTE_PASSWORD" ]]; then
    if command -v sshpass &>/dev/null; then
      sshpass -p "$REMOTE_PASSWORD" $ssh_cmd 2>&1 | tee -a "$session_log"
    else
      echo -e "${C_YELLOW}⚠ sshpass n'est pas installé. Utilisez l'authentification par clé ou installez sshpass.${C_RESET}"
      $ssh_cmd 2>&1 | tee -a "$session_log"
    fi
  else
    $ssh_cmd 2>&1 | tee -a "$session_log"
  fi
  
  # Sauvegarder la fin de session
  echo "Session ended: $(date '+%Y-%m-%d %H:%M:%S')" >> "$session_log"
  echo -e "\n${C_GOOD}✓ Session log sauvegardé: ${session_log}${C_RESET}"
}

# Ouvrir Remmina
remote_remmina() {
  clear
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}Lancer Remmina${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  if ! command -v remmina &>/dev/null; then
    echo -e "${C_RED}✗ Remmina n'est pas installé${C_RESET}"
    echo -e "${C_INFO}  Installez-le avec: sudo pacman -S remmina${C_RESET}"
    return 1
  fi
  
  echo -e "${C_INFO}Lancement de Remmina...${C_RESET}"
  remmina &>/dev/null &
  echo -e "${C_GOOD}✓ Remmina lancé${C_RESET}"
}

# Connexion RDP
remote_rdp_connect() {
  clear
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}Connexion RDP${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  if ! prompt_rdp_info; then
    return 1
  fi
  
  # Créer le répertoire de sessions RDP
  local rdp_dir="$BALORSH_DATA_DIR/remoteaccess/rdp"
  mkdir -p "$rdp_dir"
  
  # Timestamp pour le log
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local session_log="$rdp_dir/session_${REMOTE_TARGET}_${timestamp}.log"
  
  echo ""
  echo -e "${C_INFO}Connexion RDP à ${REMOTE_TARGET}:${REMOTE_PORT}...${C_RESET}"
  echo -e "${C_INFO}Session log: ${session_log}${C_RESET}"
  echo ""
  
  # Sauvegarder les informations de session
  {
    echo "=== RDP Session Log ==="
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Target: ${REMOTE_TARGET}"
    echo "Port: ${REMOTE_PORT}"
    echo "User: ${REMOTE_USER}"
    if [[ -n "$REMOTE_DOMAIN" ]]; then
      echo "Domain: ${REMOTE_DOMAIN}"
    fi
    echo "======================"
  } > "$session_log"
  
  # Vérifier si xfreerdp est disponible
  if command -v xfreerdp &>/dev/null; then
    local rdp_cmd="xfreerdp"
    rdp_cmd="$rdp_cmd /v:${REMOTE_TARGET}:${REMOTE_PORT}"
    rdp_cmd="$rdp_cmd /u:${REMOTE_USER}"
    
    if [[ -n "$REMOTE_DOMAIN" ]]; then
      rdp_cmd="$rdp_cmd /d:${REMOTE_DOMAIN}"
    fi
    
    if [[ -n "$REMOTE_PASSWORD" ]]; then
      rdp_cmd="$rdp_cmd /p:${REMOTE_PASSWORD}"
    fi
    
    # Options supplémentaires
    echo -ne "${C_ACCENT1}Résolution (ex: 1920x1080) [fullscreen]: ${C_RESET}"
    read -r resolution
    
    if [[ -n "$resolution" ]]; then
      rdp_cmd="$rdp_cmd /size:${resolution}"
    else
      rdp_cmd="$rdp_cmd /f"
    fi
    
    # Activer la compression
    rdp_cmd="$rdp_cmd +compression"
    
    # Désactiver la vérification du certificat (pour les tests)
    rdp_cmd="$rdp_cmd /cert:ignore"
    
    echo -e "${C_INFO}Commande: ${rdp_cmd/\\/p:*/\\/p:****}${C_RESET}"
    eval "$rdp_cmd" 2>&1 | tee -a "$session_log"
    
  elif command -v rdesktop &>/dev/null; then
    local rdp_cmd="rdesktop"
    
    if [[ -n "$REMOTE_DOMAIN" ]]; then
      rdp_cmd="$rdp_cmd -d ${REMOTE_DOMAIN}"
    fi
    
    rdp_cmd="$rdp_cmd -u ${REMOTE_USER}"
    
    if [[ -n "$REMOTE_PASSWORD" ]]; then
      rdp_cmd="$rdp_cmd -p ${REMOTE_PASSWORD}"
    fi
    
    rdp_cmd="$rdp_cmd ${REMOTE_TARGET}:${REMOTE_PORT}"
    
    eval "$rdp_cmd" 2>&1 | tee -a "$session_log"
  else
    echo -e "${C_RED}✗ Aucun client RDP trouvé (xfreerdp ou rdesktop)${C_RESET}"
    echo -e "${C_INFO}  Installez xfreerdp avec: sudo pacman -S freerdp${C_RESET}"
    return 1
  fi
  
  # Sauvegarder la fin de session
  echo "Session ended: $(date '+%Y-%m-%d %H:%M:%S')" >> "$session_log"
  echo -e "\n${C_GOOD}✓ Session log sauvegardé: ${session_log}${C_RESET}"
}

# Connexion Samba
remote_samba_connect() {
  clear
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}Connexion Samba/SMB${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  if ! prompt_samba_info; then
    return 1
  fi
  
  # Créer le répertoire de sessions Samba
  local smb_dir="$BALORSH_DATA_DIR/remoteaccess/smb"
  mkdir -p "$smb_dir"
  
  # Timestamp pour le log
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local session_log="$smb_dir/session_${REMOTE_TARGET}_${timestamp}.log"
  
  # Sauvegarder les informations de session
  {
    echo "=== SMB/Samba Session Log ==="
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Target: //${REMOTE_TARGET}/${REMOTE_SHARE}"
    echo "User: ${REMOTE_USER:-guest}"
    if [[ -n "$REMOTE_DOMAIN" ]]; then
      echo "Domain: ${REMOTE_DOMAIN}"
    fi
    echo "======================"
  } > "$session_log"
  
  echo ""
  echo -e "${C_INFO}Connexion à //${REMOTE_TARGET}/${REMOTE_SHARE}...${C_RESET}"
  echo -e "${C_INFO}Session log: ${session_log}${C_RESET}"
  echo ""
  
  # Méthode 1: Avec interface graphique (si disponible)
  echo -e "${C_ACCENT1}Méthode de connexion:${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}1)${C_RESET} Interface graphique (Nautilus/Thunar)"
  echo -e "  ${C_HIGHLIGHT}2)${C_RESET} Montage en ligne de commande"
  echo -e "  ${C_HIGHLIGHT}3)${C_RESET} Client smbclient"
  echo -ne "${C_ACCENT1}Choix [1]: ${C_RESET}"
  read -r method
  method="${method:-1}"
  
  case "$method" in
    1)
      local smb_uri="smb://"
      if [[ -n "$REMOTE_USER" ]]; then
        smb_uri="${smb_uri}${REMOTE_USER}@"
      fi
      smb_uri="${smb_uri}${REMOTE_TARGET}/${REMOTE_SHARE}"
      
      echo -e "${C_INFO}Ouverture de ${smb_uri}...${C_RESET}"
      
      if command -v xdg-open &>/dev/null; then
        xdg-open "$smb_uri" &>/dev/null &
        echo "Method: GUI (xdg-open)" >> "$session_log"
      elif command -v nautilus &>/dev/null; then
        nautilus "$smb_uri" &>/dev/null &
        echo "Method: GUI (nautilus)" >> "$session_log"
      elif command -v thunar &>/dev/null; then
        thunar "$smb_uri" &>/dev/null &
        echo "Method: GUI (thunar)" >> "$session_log"
      else
        echo -e "${C_RED}✗ Aucun gestionnaire de fichiers graphique trouvé${C_RESET}"
        return 1
      fi
      echo "Session ended: $(date '+%Y-%m-%d %H:%M:%S')" >> "$session_log"
      echo -e "\n${C_GOOD}✓ Session log sauvegardé: ${session_log}${C_RESET}"
      ;;
      
    2)
      local mount_point="/mnt/smb_${REMOTE_SHARE}"
      echo -ne "${C_ACCENT1}Point de montage [${mount_point}]: ${C_RESET}"
      read -r custom_mount
      mount_point="${custom_mount:-$mount_point}"
      
      # Créer le point de montage
      if [[ ! -d "$mount_point" ]]; then
        echo -e "${C_INFO}Création du point de montage ${mount_point}...${C_RESET}"
        sudo mkdir -p "$mount_point"
      fi
      
      # Options de montage
      local mount_opts="vers=3.0"
      if [[ -n "$REMOTE_USER" ]]; then
        mount_opts="${mount_opts},username=${REMOTE_USER}"
        if [[ -n "$REMOTE_PASSWORD" ]]; then
          mount_opts="${mount_opts},password=${REMOTE_PASSWORD}"
        fi
        if [[ -n "$REMOTE_DOMAIN" ]]; then
          mount_opts="${mount_opts},domain=${REMOTE_DOMAIN}"
        fi
      else
        mount_opts="${mount_opts},guest"
      fi
      
      echo -e "${C_INFO}Montage de //${REMOTE_TARGET}/${REMOTE_SHARE} sur ${mount_point}...${C_RESET}"
      echo "Method: Mount" >> "$session_log"
      echo "Mount point: ${mount_point}" >> "$session_log"
      
      sudo mount -t cifs "//${REMOTE_TARGET}/${REMOTE_SHARE}" "$mount_point" -o "$mount_opts" 2>&1 | tee -a "$session_log"
      
      if [[ $? -eq 0 ]]; then
        echo -e "${C_GOOD}✓ Partage monté avec succès sur ${mount_point}${C_RESET}"
        echo -e "${C_INFO}  Pour démonter: sudo umount ${mount_point}${C_RESET}"
        echo "Status: Mounted successfully" >> "$session_log"
        echo "Session ended: $(date '+%Y-%m-%d %H:%M:%S')" >> "$session_log"
        echo -e "\n${C_GOOD}✓ Session log sauvegardé: ${session_log}${C_RESET}"
      else
        echo -e "${C_RED}✗ Échec du montage${C_RESET}"
        echo "Status: Mount failed" >> "$session_log"
        return 1
      fi
      ;;
      
    3)
      if ! command -v smbclient &>/dev/null; then
        echo -e "${C_RED}✗ smbclient n'est pas installé${C_RESET}"
        echo -e "${C_INFO}  Installez-le avec: sudo pacman -S smbclient${C_RESET}"
        return 1
      fi
      
      local smb_cmd="smbclient //${REMOTE_TARGET}/${REMOTE_SHARE}"
      
      if [[ -n "$REMOTE_USER" ]]; then
        smb_cmd="$smb_cmd -U ${REMOTE_USER}"
        if [[ -n "$REMOTE_DOMAIN" ]]; then
          smb_cmd="$smb_cmd -W ${REMOTE_DOMAIN}"
        fi
      fi
      
      echo "Method: smbclient" >> "$session_log"
      
      if [[ -n "$REMOTE_PASSWORD" ]]; then
        smbclient "//${REMOTE_TARGET}/${REMOTE_SHARE}" -U "${REMOTE_USER}" --password="${REMOTE_PASSWORD}" 2>&1 | tee -a "$session_log"
      else
        eval "$smb_cmd" 2>&1 | tee -a "$session_log"
      fi
      
      echo "Session ended: $(date '+%Y-%m-%d %H:%M:%S')" >> "$session_log"
      echo -e "\n${C_GOOD}✓ Session log sauvegardé: ${session_log}${C_RESET}"
      ;;
      
    *)
      echo -e "${C_RED}Choix invalide${C_RESET}"
      return 1
      ;;
  esac
}

# Connexion NFS
remote_nfs_mount() {
  clear
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}Montage NFS${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  if ! prompt_nfs_info; then
    return 1
  fi
  
  # Créer le répertoire de sessions NFS
  local nfs_dir="$BALORSH_DATA_DIR/remoteaccess/nfs"
  mkdir -p "$nfs_dir"
  
  # Timestamp pour le log
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local session_log="$nfs_dir/session_${REMOTE_TARGET}_${timestamp}.log"
  
  # Sauvegarder les informations de session
  {
    echo "=== NFS Mount Session Log ==="
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Target: ${REMOTE_TARGET}:${REMOTE_EXPORT}"
    echo "Mount point: ${REMOTE_MOUNT}"
    echo "NFS Version: ${NFS_VERSION}"
    if [[ -n "$NFS_OPTIONS" ]]; then
      echo "Options: ${NFS_OPTIONS}"
    fi
    echo "======================"
  } > "$session_log"
  
  echo ""
  echo -e "${C_INFO}Montage de ${REMOTE_TARGET}:${REMOTE_EXPORT} sur ${REMOTE_MOUNT}...${C_RESET}"
  echo -e "${C_INFO}Session log: ${session_log}${C_RESET}"
  echo ""
  
  # Créer le point de montage
  if [[ ! -d "$REMOTE_MOUNT" ]]; then
    echo -e "${C_INFO}Création du point de montage ${REMOTE_MOUNT}...${C_RESET}"
    sudo mkdir -p "$REMOTE_MOUNT"
  fi
  
  # Construction des options
  local mount_opts="nfsvers=${NFS_VERSION}"
  if [[ -n "$NFS_OPTIONS" ]]; then
    mount_opts="${mount_opts},${NFS_OPTIONS}"
  fi
  
  echo -e "${C_INFO}Options de montage: ${mount_opts}${C_RESET}"
  echo -e "${C_INFO}Montage en cours...${C_RESET}"
  echo "Mount options: ${mount_opts}" >> "$session_log"
  
  sudo mount -t nfs -o "$mount_opts" "${REMOTE_TARGET}:${REMOTE_EXPORT}" "$REMOTE_MOUNT" 2>&1 | tee -a "$session_log"
  
  if [[ $? -eq 0 ]]; then
    echo -e "${C_GOOD}✓ NFS monté avec succès sur ${REMOTE_MOUNT}${C_RESET}"
    echo -e "${C_INFO}  Pour démonter: sudo umount ${REMOTE_MOUNT}${C_RESET}"
    
    # Afficher les informations de montage
    echo ""
    echo -e "${C_ACCENT1}Informations de montage:${C_RESET}"
    mount | grep "$REMOTE_MOUNT" | tee -a "$session_log"
    
    echo "Status: Mounted successfully" >> "$session_log"
    echo "Session ended: $(date '+%Y-%m-%d %H:%M:%S')" >> "$session_log"
    echo -e "\n${C_GOOD}✓ Session log sauvegardé: ${session_log}${C_RESET}"
  else
    echo -e "${C_RED}✗ Échec du montage NFS${C_RESET}"
    echo "Status: Mount failed" >> "$session_log"
    return 1
  fi
}

# ==============================================================================
# FONCTIONS DE SCAN
# ==============================================================================

# Scanner les services de remote access et transfert de fichiers
remote_scan_services() {
  clear
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}Scanner les services de remote access${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  echo -ne "${C_ACCENT1}Adresse IP/Hostname à scanner: ${C_RESET}"
  read -r target
  
  if ! validate_target "$target"; then
    return 1
  fi
  
  echo ""
  echo -e "${C_INFO}Scan des services de remote access et transfert de fichiers sur ${target}...${C_RESET}"
  echo ""
  
  # Liste des ports à scanner
  # SSH: 22
  # Telnet: 23
  # FTP: 20,21
  # SFTP: 115 (mais généralement via SSH:22)
  # SMB/CIFS: 139,445
  # RDP: 3389
  # VNC: 5900-5909
  # NFS: 2049
  # rsync: 873
  # WebDAV: 80,443
  # TeamViewer: 5938
  # AnyDesk: 7070
  
  local ports="20,21,22,23,80,115,139,443,445,873,2049,3389,5800,5900-5909,5938,7070"
  
  if ! command -v nmap &>/dev/null; then
    echo -e "${C_RED}✗ Nmap n'est pas installé${C_RESET}"
    echo -e "${C_INFO}  Installez-le avec: sudo pacman -S nmap${C_RESET}"
    return 1
  fi
  
  echo -e "${C_ACCENT1}Type de scan:${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}1)${C_RESET} Scan rapide (SYN scan)"
  echo -e "  ${C_HIGHLIGHT}2)${C_RESET} Scan détaillé (détection de version)"
  echo -e "  ${C_HIGHLIGHT}3)${C_RESET} Scan complet (version + scripts NSE)"
  echo -ne "${C_ACCENT1}Choix [1]: ${C_RESET}"
  read -r scan_type
  scan_type="${scan_type:-1}"
  
  # Créer le répertoire de sortie
  mkdir -p "$BALORSH_DATA_DIR/remoteaccess"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local output_file="$BALORSH_DATA_DIR/remoteaccess/scan_${target}_${timestamp}"
  
  local nmap_cmd="sudo nmap"
  
  case "$scan_type" in
    1)
      # Scan rapide
      nmap_cmd="$nmap_cmd -sS -p ${ports}"
      ;;
    2)
      # Scan détaillé avec détection de version
      nmap_cmd="$nmap_cmd -sV -p ${ports}"
      ;;
    3)
      # Scan complet avec scripts NSE
      nmap_cmd="$nmap_cmd -sV -sC -p ${ports}"
      ;;
    *)
      echo -e "${C_RED}Choix invalide${C_RESET}"
      return 1
      ;;
  esac
  
  nmap_cmd="$nmap_cmd -oN ${output_file}.txt -oX ${output_file}.xml ${target}"
  
  echo ""
  echo -e "${C_INFO}Commande: ${nmap_cmd}${C_RESET}"
  echo -e "${C_INFO}Scan en cours...${C_RESET}"
  echo ""
  
  eval "$nmap_cmd"
  
  if [[ $? -eq 0 ]]; then
    echo ""
    echo -e "${C_GOOD}✓ Scan terminé${C_RESET}"
    echo -e "${C_INFO}  Résultats sauvegardés:${C_RESET}"
    echo -e "${C_INFO}    - ${output_file}.txt${C_RESET}"
    echo -e "${C_INFO}    - ${output_file}.xml${C_RESET}"
    echo ""
    
    # Afficher un résumé des ports ouverts
    echo -e "${C_ACCENT1}═══ Résumé des services détectés ═══${C_RESET}"
    grep -E "open|filtered" "${output_file}.txt" | grep -v "nmap" || echo "Aucun port ouvert détecté"
    echo ""
    
    # Afficher les recommandations
    echo -e "${C_ACCENT1}═══ Services de remote access détectés ═══${C_RESET}"
    
    if grep -q "22/tcp.*open" "${output_file}.txt"; then
      echo -e "${C_GOOD}✓ SSH (port 22) - Utilisez l'option 'Connexion SSH' du menu${C_RESET}"
    fi
    
    if grep -q "3389/tcp.*open" "${output_file}.txt"; then
      echo -e "${C_GOOD}✓ RDP (port 3389) - Utilisez l'option 'Connexion RDP' du menu${C_RESET}"
    fi
    
    if grep -q -E "(139|445)/tcp.*open" "${output_file}.txt"; then
      echo -e "${C_GOOD}✓ SMB/CIFS (ports 139/445) - Utilisez l'option 'Connexion Samba' du menu${C_RESET}"
    fi
    
    if grep -q "2049/tcp.*open" "${output_file}.txt"; then
      echo -e "${C_GOOD}✓ NFS (port 2049) - Utilisez l'option 'Montage NFS' du menu${C_RESET}"
    fi
    
    if grep -q -E "5900|5901|5902/tcp.*open" "${output_file}.txt"; then
      echo -e "${C_GOOD}✓ VNC détecté - Utilisez un client VNC comme TigerVNC${C_RESET}"
    fi
    
    if grep -q -E "(20|21)/tcp.*open" "${output_file}.txt"; then
      echo -e "${C_GOOD}✓ FTP (ports 20/21) - Utilisez un client FTP${C_RESET}"
    fi
    
  else
    echo -e "${C_RED}✗ Échec du scan${C_RESET}"
    return 1
  fi
}

# Lister les partages Samba disponibles
remote_samba_list_shares() {
  clear
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}Lister les partages Samba${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  echo -ne "${C_ACCENT1}Adresse IP/Hostname: ${C_RESET}"
  read -r target
  
  if ! validate_target "$target"; then
    return 1
  fi
  
  if ! command -v smbclient &>/dev/null; then
    echo -e "${C_RED}✗ smbclient n'est pas installé${C_RESET}"
    echo -e "${C_INFO}  Installez-le avec: sudo pacman -S smbclient${C_RESET}"
    return 1
  fi
  
  # Créer le répertoire et sauvegarder le résultat
  local smb_dir="$BALORSH_DATA_DIR/remoteaccess/smb"
  mkdir -p "$smb_dir"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local shares_log="$smb_dir/shares_${target}_${timestamp}.txt"
  
  echo ""
  echo -e "${C_INFO}Liste des partages sur ${target}...${C_RESET}"
  echo ""
  
  {
    echo "=== SMB Shares Enumeration ==="
    echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
    echo "Target: ${target}"
    echo "======================"
    echo ""
  } > "$shares_log"
  
  smbclient -L "//${target}" -N 2>&1 | tee -a "$shares_log"
  
  echo -e "\n${C_GOOD}✓ Résultats sauvegardés: ${shares_log}${C_RESET}"
}

# Lister les exports NFS disponibles
remote_nfs_list_exports() {
  clear
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}Lister les exports NFS${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  echo -ne "${C_ACCENT1}Adresse IP/Hostname: ${C_RESET}"
  read -r target
  
  if ! validate_target "$target"; then
    return 1
  fi
  
  # Créer le répertoire et sauvegarder le résultat
  local nfs_dir="$BALORSH_DATA_DIR/remoteaccess/nfs"
  mkdir -p "$nfs_dir"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local exports_log="$nfs_dir/exports_${target}_${timestamp}.txt"
  
  echo ""
  echo -e "${C_INFO}Liste des exports NFS sur ${target}...${C_RESET}"
  echo ""
  
  if command -v showmount &>/dev/null; then
    {
      echo "=== NFS Exports Enumeration ==="
      echo "Date: $(date '+%Y-%m-%d %H:%M:%S')"
      echo "Target: ${target}"
      echo "======================"
      echo ""
    } > "$exports_log"
    
    showmount -e "$target" 2>&1 | tee -a "$exports_log"
    
    echo -e "\n${C_GOOD}✓ Résultats sauvegardés: ${exports_log}${C_RESET}"
  else
    echo -e "${C_RED}✗ showmount n'est pas installé${C_RESET}"
    echo -e "${C_INFO}  Installez-le avec: sudo pacman -S nfs-utils${C_RESET}"
    return 1
  fi
}

# ==============================================================================
# FONCTIONS UTILITAIRES
# ==============================================================================

# Nettoyage des fichiers de scan anciens
remote_cleanup() {
  clear
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}Nettoyage des fichiers de scan${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  local scan_dir="$BALORSH_DATA_DIR/remoteaccess"
  
  if [[ ! -d "$scan_dir" ]]; then
    echo -e "${C_INFO}Aucun fichier de scan trouvé${C_RESET}"
    return
  fi
  
  echo -ne "${C_ACCENT1}Supprimer les fichiers de plus de X jours [7]: ${C_RESET}"
  read -r days
  days="${days:-7}"
  
  echo ""
  echo -e "${C_INFO}Recherche des fichiers de plus de ${days} jours dans ${scan_dir}...${C_RESET}"
  
  local files_found=$(find "$scan_dir" -type f -mtime +"$days" 2>/dev/null | wc -l)
  
  if (( files_found > 0 )); then
    echo -e "${C_YELLOW}${files_found} fichier(s) trouvé(s):${C_RESET}"
    find "$scan_dir" -type f -mtime +"$days" 2>/dev/null
    echo ""
    echo -ne "${C_ACCENT1}Confirmer la suppression ? (o/N): ${C_RESET}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[oO]$ ]]; then
      find "$scan_dir" -type f -mtime +"$days" -delete 2>/dev/null
      echo -e "${C_GOOD}✓ Nettoyage effectué${C_RESET}"
    else
      echo -e "${C_INFO}Nettoyage annulé${C_RESET}"
    fi
  else
    echo -e "${C_INFO}Aucun fichier à supprimer${C_RESET}"
  fi
}

# Afficher l'aide
remote_help() {
  clear
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}Remote Access Stack - Aide rapide${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  echo -e "${C_HIGHLIGHT}SSH (Secure Shell):${C_RESET}"
  echo -e "  Protocole sécurisé pour accès à distance en ligne de commande"
  echo -e "  Port par défaut: 22"
  echo ""
  echo -e "${C_HIGHLIGHT}RDP (Remote Desktop Protocol):${C_RESET}"
  echo -e "  Protocole Microsoft pour bureau à distance"
  echo -e "  Port par défaut: 3389"
  echo ""
  echo -e "${C_HIGHLIGHT}Samba/SMB/CIFS:${C_RESET}"
  echo -e "  Partage de fichiers et imprimantes compatible Windows"
  echo -e "  Ports: 139, 445"
  echo ""
  echo -e "${C_HIGHLIGHT}NFS (Network File System):${C_RESET}"
  echo -e "  Système de fichiers en réseau Unix/Linux"
  echo -e "  Port: 2049"
  echo ""
  echo -e "${C_HIGHLIGHT}VNC (Virtual Network Computing):${C_RESET}"
  echo -e "  Bureau à distance multiplateforme"
  echo -e "  Ports: 5900-5909"
  echo ""
  echo -e "${C_HIGHLIGHT}FTP (File Transfer Protocol):${C_RESET}"
  echo -e "  Transfert de fichiers"
  echo -e "  Ports: 20, 21"
  echo ""
  echo -e "${C_HIGHLIGHT}Scan de services:${C_RESET}"
  echo -e "  Utilise Nmap pour détecter les services de remote access"
  echo -e "  et de transfert de fichiers sur une cible"
  echo ""
  echo -e "${C_INFO}Pour plus d'informations, consultez la documentation${C_RESET}"
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================

stack_menu() {
  while true; do
    clear
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_ACCENT2}║                                                                   ║${C_RESET}"
    echo -e "${C_ACCENT2}║         ${C_BOLD}${REMOTEACCESS_MENU_TITLE:-🔐 Remote Access Stack - balorsh}${C_RESET}${C_ACCENT2}         ║${C_RESET}"
    echo -e "${C_ACCENT2}║                                                                   ║${C_RESET}"
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo -e "   ${C_SHADOW}${REMOTEACCESS_MENU_SECTION_CONNECT:-──── Connexions à distance ────}${C_RESET}                              "
    echo -e "   ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${REMOTEACCESS_MENU_1:-Connexion SSH}${C_RESET}                           "
    echo -e "   ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${REMOTEACCESS_MENU_2:-Connexion RDP}${C_RESET}                            "
    echo -e "   ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${REMOTEACCESS_MENU_3:-Ouvrir Remmina}${C_RESET}                                "
    echo -e "   ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${REMOTEACCESS_MENU_4:-Connexion Samba/SMB}${C_RESET}                                       "
    echo -e "   ${C_HIGHLIGHT}5)${C_RESET} ${C_INFO}${REMOTEACCESS_MENU_5:-Montage NFS}${C_RESET}                                        "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${REMOTEACCESS_MENU_SECTION_DISCOVERY:-──── Découverte ────}${C_RESET}                                      "
    echo -e "   ${C_HIGHLIGHT}6)${C_RESET} ${C_INFO}${REMOTEACCESS_MENU_6:-Scanner services remote access}${C_RESET}                              "
    echo -e "   ${C_HIGHLIGHT}7)${C_RESET} ${C_INFO}${REMOTEACCESS_MENU_7:-Lister partages Samba}${C_RESET}                            "
    echo -e "   ${C_HIGHLIGHT}8)${C_RESET} ${C_INFO}${REMOTEACCESS_MENU_8:-Lister exports NFS}${C_RESET}                             "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${REMOTEACCESS_MENU_SECTION_UTILS:-──── Utilitaires ────}${C_RESET}                                     "
    echo -e "   ${C_HIGHLIGHT}9)${C_RESET} ${C_INFO}${REMOTEACCESS_MENU_9:-Nettoyage fichiers anciens}${C_RESET}                                  "
    echo -e "   ${C_HIGHLIGHT}10)${C_RESET} ${C_INFO}${REMOTEACCESS_MENU_10:-Aide}${C_RESET}                                                "
    echo -e "                                                                 "
    echo -e "   ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${REMOTEACCESS_MENU_0:-Retour au menu principal}${C_RESET}                                                   "
    echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
    echo -ne "${C_ACCENT1}${BALORSH_CHOICE:-Votre choix}${C_RESET}: "
    read -r choice

    case "$choice" in
      1) remote_ssh_connect ;;
      2) remote_rdp_connect ;;
      3) remote_remmina ;;
      4) remote_samba_connect ;;
      5) remote_nfs_mount ;;
      6) remote_scan_services ;;
      7) remote_samba_list_shares ;;
      8) remote_nfs_list_exports ;;
      9) remote_cleanup ;;
      10) remote_help ;;
      0) echo -e "${C_GOOD}${BALORSH_QUIT:-Au revoir !}${C_RESET}"; break ;;
      *) echo -e "${C_RED}${REMOTEACCESS_INVALID_CHOICE:-Choix invalide}${C_RESET}" ;;
    esac
    
    if [[ "$choice" != "0" ]]; then
      echo -e "\n${C_INFO}${REMOTEACCESS_PRESS_ENTER:-Appuyez sur [Entrée] pour continuer...}${C_RESET}"
      read -r
    fi
  done
}

# Point d'entrée principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  stack_menu
fi
