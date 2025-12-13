#!/usr/bin/env bash
set -Eeuo pipefail

# stacks/networkscan/commands.sh
# Menu Network Scan complet pour balorsh

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
C_RED="\e[31m"
C_YELLOW="\e[33m"
C_INFO="\e[36m"

# Variables globales
NETSCAN_TARGET=""
: "${BALORSH_DATA_DIR:=/opt/balorsh/data}"

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

# Valide une plage CIDR (ex: 192.168.1.0/24)
validate_cidr() {
  local cidr="$1"
  
  if [[ $cidr =~ ^([0-9.]+)/([0-9]+)$ ]]; then
    local ip="${BASH_REMATCH[1]}"
    local mask="${BASH_REMATCH[2]}"
    
    # Vérifie que l'IP est valide
    if ! validate_ipv4 "$ip"; then
      return 1
    fi
    
    # Vérifie que le masque est entre 0 et 32
    if (( mask < 0 || mask > 32 )); then
      return 1
    fi
    
    return 0
  fi
  
  return 1
}

# Valide et normalise une cible (IP ou CIDR)
validate_target() {
  local target="$1"
  
  # Teste si c'est une notation CIDR
  if [[ $target =~ / ]]; then
    if validate_cidr "$target"; then
      echo -e "${C_GOOD}✓ Cible CIDR valide: $target${C_RESET}"
      return 0
    else
      echo -e "${C_RED}✗ Notation CIDR invalide: $target${C_RESET}"
      echo -e "${C_INFO}  Format attendu: IP/MASQUE (ex: 192.168.1.0/24, masque entre 0-32)${C_RESET}"
      return 1
    fi
  else
    # Teste si c'est une IP simple
    if validate_ipv4 "$target"; then
      echo -e "${C_GOOD}✓ Adresse IP valide: $target${C_RESET}"
      return 0
    else
      echo -e "${C_RED}✗ Adresse IP invalide: $target${C_RESET}"
      echo -e "${C_INFO}  Format attendu: XXX.XXX.XXX.XXX (chaque octet entre 0-255)${C_RESET}"
      return 1
    fi
  fi
}

# Demande une cible à l'utilisateur avec validation
prompt_target() {
  local target
  while true; do
    echo -e "${C_ACCENT1}Entrez la cible à scanner:${C_RESET}"
    echo -e "${C_INFO}  - IP unique: 192.168.1.1${C_RESET}"
    echo -e "${C_INFO}  - Réseau CIDR: 192.168.1.0/24${C_RESET}"
    echo -e "${C_INFO}  - Plage: 192.168.1.1-254${C_RESET}"
    echo -ne "${C_HIGHLIGHT}Cible: ${C_RESET}"
    read -r target
    
    if [[ -z "$target" ]]; then
      echo -e "${C_RED}Aucune cible saisie.${C_RESET}"
      continue
    fi
    
    # Accepte aussi les plages IP (192.168.1.1-254)
    if [[ $target =~ ^([0-9.]+)-([0-9]+)$ ]]; then
      local base="${BASH_REMATCH[1]}"
      if validate_ipv4 "${base%.*}.${BASH_REMATCH[2]}"; then
        echo -e "${C_GOOD}✓ Plage IP valide: $target${C_RESET}"
        NETSCAN_TARGET="$target"
        return 0
      fi
    fi
    
    if validate_target "$target"; then
      NETSCAN_TARGET="$target"
      return 0
    fi
    
    echo -e "${C_YELLOW}Veuillez saisir une cible valide.${C_RESET}"
  done
}

# ==============================================================================
# FONCTIONS DE SCAN NMAP
# ==============================================================================

# Scan rapide avec nmap (top 100 ports)
netscan_nmap_quick() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/quick_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}Scan rapide nmap (top 100 ports) sur $NETSCAN_TARGET...${C_RESET}"
  sudo nmap -F -T4 -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}Résultats sauvegardés:${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan complet tous ports avec nmap
netscan_nmap_full() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/full_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}Scan complet nmap (tous les ports) sur $NETSCAN_TARGET...${C_RESET}"
  echo -e "${C_YELLOW}⚠ Attention: ce scan peut prendre du temps${C_RESET}"
  sudo nmap -p- -T4 -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}Résultats sauvegardés:${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan de détection de services et versions
netscan_nmap_services() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/services_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}Scan de services et versions nmap sur $NETSCAN_TARGET...${C_RESET}"
  sudo nmap -sV -sC -O -T4 -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}Résultats sauvegardés:${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan furtif (stealth) SYN
netscan_nmap_stealth() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/stealth_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}Scan furtif SYN nmap sur $NETSCAN_TARGET...${C_RESET}"
  sudo nmap -sS -T2 -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}Résultats sauvegardés:${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan avec scripts NSE (vulnérabilités)
netscan_nmap_vuln() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/vuln_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}Scan de vulnérabilités nmap (NSE) sur $NETSCAN_TARGET...${C_RESET}"
  echo -e "${C_YELLOW}⚠ Ce scan peut déclencher des IDS/IPS${C_RESET}"
  sudo nmap --script vuln -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}Résultats sauvegardés:${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan UDP des ports courants
netscan_nmap_udp() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/udp_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}Scan UDP nmap (top ports) sur $NETSCAN_TARGET...${C_RESET}"
  echo -e "${C_YELLOW}⚠ Les scans UDP sont généralement lents${C_RESET}"
  sudo nmap -sU --top-ports 100 -T4 -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}Résultats sauvegardés:${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# ==============================================================================
# FONCTIONS DE SCAN MASSCAN
# ==============================================================================

# Scan ultra-rapide avec masscan
netscan_masscan_fast() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/masscan"
  mkdir -p "$outdir"
  local outfile="$outdir/fast_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}Scan ultra-rapide masscan sur $NETSCAN_TARGET...${C_RESET}"
  echo -e "${C_INFO}Ports: 1-65535, Rate: 10000 paquets/sec${C_RESET}"
  sudo masscan "$NETSCAN_TARGET" -p1-65535 --rate=10000 -oL "${outfile}.txt" -oX "${outfile}.xml"
  echo -e "${C_GOOD}Résultats sauvegardés:${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan masscan des ports web courants
netscan_masscan_web() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/masscan"
  mkdir -p "$outdir"
  local outfile="$outdir/web_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}Scan masscan des ports web sur $NETSCAN_TARGET...${C_RESET}"
  echo -e "${C_INFO}Ports: 80,443,8000,8080,8443,3000,5000,8888${C_RESET}"
  sudo masscan "$NETSCAN_TARGET" -p80,443,8000,8080,8443,3000,5000,8888 --rate=5000 -oL "${outfile}.txt" -oX "${outfile}.xml"
  echo -e "${C_GOOD}Résultats sauvegardés:${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# ==============================================================================
# FONCTIONS DE DÉCOUVERTE RÉSEAU LOCAL
# ==============================================================================

# Scan ARP local avec arp-scan
netscan_arpscan() {
  echo -e "${C_HIGHLIGHT}Sélectionnez l'interface réseau:${C_RESET}"
  ip -br link show | grep -v "lo" | awk '{print $1}'
  echo -ne "${C_ACCENT1}Interface [eth0]: ${C_RESET}"
  read -r iface
  iface="${iface:-eth0}"
  
  local outdir="$BALORSH_DATA_DIR/networkscan/arpscan"
  mkdir -p "$outdir"
  local outfile="$outdir/scan_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_HIGHLIGHT}Scan ARP du réseau local sur $iface...${C_RESET}"
  sudo arp-scan --interface="$iface" --localnet | tee "$outfile"
  echo -e "${C_GOOD}Résultats sauvegardés: $outfile${C_RESET}"
}

# Scan avec netdiscover
netscan_netdiscover() {
  prompt_target || return 1
  
  echo -e "${C_HIGHLIGHT}Sélectionnez l'interface réseau:${C_RESET}"
  ip -br link show | grep -v "lo" | awk '{print $1}'
  echo -ne "${C_ACCENT1}Interface [eth0]: ${C_RESET}"
  read -r iface
  iface="${iface:-eth0}"
  
  local outdir="$BALORSH_DATA_DIR/networkscan/netdiscover"
  mkdir -p "$outdir"
  local outfile="$outdir/passive_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_HIGHLIGHT}Scan netdiscover sur $NETSCAN_TARGET via $iface...${C_RESET}"
  echo -e "${C_INFO}Mode: passif (sniffing) - Ctrl+C pour arrêter${C_RESET}"
  echo -e "${C_INFO}Résultats seront sauvegardés dans: $outfile${C_RESET}"
  echo -e "${C_YELLOW}Lancement dans 3 secondes...${C_RESET}"
  sleep 3
  
  {
    echo "=== Netdiscover Passif ==="
    echo "Date: $(date)"
    echo "Interface: $iface"
    echo "Cible: $NETSCAN_TARGET"
    echo ""
    sudo timeout 60 netdiscover -i "$iface" -r "$NETSCAN_TARGET" -P 2>&1 || true
  } | tee "$outfile"
  
  echo -e "${C_GOOD}Résultats sauvegardés: $outfile${C_RESET}"
}

# Scan actif avec netdiscover
netscan_netdiscover_active() {
  prompt_target || return 1
  
  echo -e "${C_HIGHLIGHT}Sélectionnez l'interface réseau:${C_RESET}"
  ip -br link show | grep -v "lo" | awk '{print $1}'
  echo -ne "${C_ACCENT1}Interface [eth0]: ${C_RESET}"
  read -r iface
  iface="${iface:-eth0}"
  
  local outdir="$BALORSH_DATA_DIR/networkscan/netdiscover"
  mkdir -p "$outdir"
  local outfile="$outdir/active_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_HIGHLIGHT}Scan netdiscover actif sur $NETSCAN_TARGET via $iface...${C_RESET}"
  echo -e "${C_INFO}Mode: actif (ARP requests)${C_RESET}"
  echo -e "${C_INFO}Résultats seront sauvegardés dans: $outfile${C_RESET}"
  
  {
    echo "=== Netdiscover Actif ==="
    echo "Date: $(date)"
    echo "Interface: $iface"
    echo "Cible: $NETSCAN_TARGET"
    echo ""
    sudo netdiscover -i "$iface" -r "$NETSCAN_TARGET" 2>&1 || true
  } | tee "$outfile"
  
  echo -e "${C_GOOD}Résultats sauvegardés: $outfile${C_RESET}"
}

# ==============================================================================
# FONCTIONS DE CAPTURE TCPDUMP
# ==============================================================================

# Capture de trafic avec tcpdump
netscan_tcpdump_capture() {
  echo -e "${C_HIGHLIGHT}Sélectionnez l'interface réseau:${C_RESET}"
  ip -br link show | awk '{print $1}'
  echo -ne "${C_ACCENT1}Interface [eth0]: ${C_RESET}"
  read -r iface
  iface="${iface:-eth0}"
  
  local outdir="$BALORSH_DATA_DIR/networkscan/tcpdump"
  mkdir -p "$outdir"
  local outfile="$outdir/capture_$(date +%Y%m%d_%H%M%S).pcap"
  
  echo -e "${C_HIGHLIGHT}Capture tcpdump sur $iface...${C_RESET}"
  echo -e "${C_INFO}Fichier: $outfile${C_RESET}"
  echo -e "${C_YELLOW}Ctrl+C pour arrêter la capture${C_RESET}"
  
  echo -ne "${C_ACCENT1}Filtre BPF optionnel (ex: 'port 80', vide=tout): ${C_RESET}"
  read -r filter
  
  if [[ -n "$filter" ]]; then
    sudo tcpdump -i "$iface" -w "$outfile" "$filter"
  else
    sudo tcpdump -i "$iface" -w "$outfile"
  fi
  
  echo -e "${C_GOOD}Capture sauvegardée: $outfile${C_RESET}"
  
  # Génère un résumé txt de la capture
  if [[ -f "$outfile" ]]; then
    local summary="${outfile%.pcap}_summary.txt"
    echo -e "${C_INFO}Génération du résumé...${C_RESET}"
    {
      echo "=== Résumé de capture tcpdump ==="
      echo "Date: $(date)"
      echo "Interface: $iface"
      echo "Filtre: ${filter:-aucun}"
      echo "Fichier pcap: $outfile"
      echo ""
      echo "=== Statistiques ==="
      sudo tcpdump -r "$outfile" -n 2>&1 | tail -n 3
      echo ""
      echo "=== Premiers 50 paquets ==="
      sudo tcpdump -r "$outfile" -n -c 50
    } > "$summary" 2>&1
    echo -e "${C_GOOD}Résumé sauvegardé: $summary${C_RESET}"
  fi
}

# Capture et affichage en temps réel
netscan_tcpdump_live() {
  echo -e "${C_HIGHLIGHT}Sélectionnez l'interface réseau:${C_RESET}"
  ip -br link show | awk '{print $1}'
  echo -ne "${C_ACCENT1}Interface [eth0]: ${C_RESET}"
  read -r iface
  iface="${iface:-eth0}"
  
  echo -ne "${C_ACCENT1}Filtre BPF optionnel (ex: 'host 192.168.1.1', vide=tout): ${C_RESET}"
  read -r filter
  
  local outdir="$BALORSH_DATA_DIR/networkscan/tcpdump"
  mkdir -p "$outdir"
  local outfile="$outdir/live_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_HIGHLIGHT}Affichage en temps réel du trafic sur $iface...${C_RESET}"
  echo -e "${C_INFO}Capture sauvegardée dans: $outfile${C_RESET}"
  echo -e "${C_YELLOW}Ctrl+C pour arrêter${C_RESET}"
  sleep 2
  
  {
    echo "=== Capture tcpdump en temps réel ==="
    echo "Date: $(date)"
    echo "Interface: $iface"
    echo "Filtre: ${filter:-aucun}"
    echo ""
    if [[ -n "$filter" ]]; then
      sudo tcpdump -i "$iface" -n -v "$filter" 2>&1 || true
    else
      sudo tcpdump -i "$iface" -n -v 2>&1 || true
    fi
  } | tee "$outfile"
  
  echo ""
  echo -e "${C_GOOD}Capture sauvegardée: $outfile${C_RESET}"
}

# ==============================================================================
# FONCTIONS D'ANALYSE WIRESHARK
# ==============================================================================

# Lancer Wireshark
netscan_wireshark() {
  echo -e "${C_HIGHLIGHT}Options Wireshark:${C_RESET}"
  echo "  1) Lancer Wireshark (interface graphique)"
  echo "  2) Ouvrir un fichier pcap existant"
  echo -ne "${C_ACCENT1}Choix [1]: ${C_RESET}"
  read -r choice
  choice="${choice:-1}"
  
  case "$choice" in
    1)
      echo -e "${C_INFO}Lancement de Wireshark...${C_RESET}"
      sudo wireshark &
      ;;
    2)
      echo -ne "${C_ACCENT1}Chemin du fichier pcap: ${C_RESET}"
      read -r pcapfile
      if [[ -f "$pcapfile" ]]; then
        echo -e "${C_INFO}Ouverture de $pcapfile dans Wireshark...${C_RESET}"
        wireshark "$pcapfile" &
      else
        echo -e "${C_RED}Fichier non trouvé: $pcapfile${C_RESET}"
      fi
      ;;
    *)
      echo -e "${C_RED}Choix invalide${C_RESET}"
      ;;
  esac
}

# ==============================================================================
# FONCTIONS UTILITAIRES
# ==============================================================================

# Afficher les interfaces réseau disponibles
netscan_show_interfaces() {
  echo -e "${C_ACCENT1}Interfaces réseau disponibles:${C_RESET}"
  echo ""
  ip -br addr show | while read -r line; do
    iface=$(echo "$line" | awk '{print $1}')
    state=$(echo "$line" | awk '{print $2}')
    ip=$(echo "$line" | awk '{print $3}')
    
    if [[ "$state" == "UP" ]]; then
      echo -e "  ${C_GOOD}●${C_RESET} $iface - ${C_HIGHLIGHT}$state${C_RESET} - $ip"
    else
      echo -e "  ${C_RED}●${C_RESET} $iface - $state - $ip"
    fi
  done
  echo ""
}

# Détection rapide du réseau local
netscan_quick_local() {
  echo -e "${C_HIGHLIGHT}Détection rapide du réseau local...${C_RESET}"
  
  # Récupère l'IP et le réseau de l'interface principale
  local default_iface=$(ip route | grep default | awk '{print $5}' | head -n1)
  local local_ip=$(ip -4 addr show "$default_iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  local network=$(echo "$local_ip" | cut -d. -f1-3).0/24
  
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/quick_local_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_INFO}Interface: $default_iface${C_RESET}"
  echo -e "${C_INFO}Votre IP: $local_ip${C_RESET}"
  echo -e "${C_INFO}Réseau détecté: $network${C_RESET}"
  echo ""
  
  echo -e "${C_HIGHLIGHT}Scan rapide du réseau local avec nmap...${C_RESET}"
  {
    echo "=== Détection rapide réseau local ==="
    echo "Date: $(date)"
    echo "Interface: $default_iface"
    echo "Votre IP: $local_ip"
    echo "Réseau: $network"
    echo ""
    echo "=== Résultats du scan ==="
    sudo nmap -sn "$network"
  } | tee "$outfile"
  
  echo ""
  echo -e "${C_GOOD}Résultats sauvegardés: $outfile${C_RESET}"
}

# Nettoyer les anciens scans
netscan_cleanup() {
  echo -e "${C_YELLOW}Nettoyage des anciennes captures et scans...${C_RESET}"
  echo -ne "${C_ACCENT1}Supprimer les fichiers de plus de combien de jours? [7]: ${C_RESET}"
  read -r days
  days="${days:-7}"
  
  if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo -e "${C_RED}Nombre de jours invalide${C_RESET}"
    return 1
  fi
  
  local count=0
  while IFS= read -r -d '' file; do
    rm -f "$file"
    ((count++))
  done < <(find "$BALORSH_DATA_DIR/networkscan" -type f -mtime +"$days" -print0 2>/dev/null)
  
  echo -e "${C_GOOD}$count fichier(s) supprimé(s)${C_RESET}"
}

# Aide
netscan_help() {
  cat <<EOF
${C_ACCENT1}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}
${C_ACCENT1}║${C_RESET}                   ${C_GOOD}AIDE NETWORK SCAN${C_RESET}                          ${C_ACCENT1}║${C_RESET}
${C_ACCENT1}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}

${C_HIGHLIGHT}OUTILS DISPONIBLES:${C_RESET}
  • nmap      - Scanner de ports et de services
  • masscan   - Scanner ultra-rapide de ports
  • arp-scan  - Découverte d'hôtes par ARP (local uniquement)
  • netdiscover - Découverte active/passive d'hôtes
  • tcpdump   - Capture et analyse de paquets
  • wireshark - Analyseur de protocoles réseau (GUI)

${C_HIGHLIGHT}FORMATS D'ADRESSES ACCEPTÉS:${C_RESET}
  • IP unique:    192.168.1.100
  • Réseau CIDR:  192.168.1.0/24
  • Plage:        192.168.1.1-254

${C_HIGHLIGHT}TYPES DE SCANS NMAP:${C_RESET}
  • Quick (-F)        - Top 100 ports, rapide
  • Full (-p-)        - Tous les ports (1-65535)
  • Services (-sV)    - Détection services et versions
  • Stealth (-sS)     - Scan furtif SYN
  • Vuln (--script)   - Détection de vulnérabilités
  • UDP (-sU)         - Scan des ports UDP

${C_HIGHLIGHT}RÉPERTOIRE DE SAUVEGARDE:${C_RESET}
  $BALORSH_DATA_DIR/networkscan/

${C_HIGHLIGHT}CONSEILS:${C_RESET}
  • Utilisez arp-scan pour une découverte rapide du réseau local
  • masscan est idéal pour scanner de grandes plages d'IP
  • nmap offre plus de détails et d'options d'analyse
  • Toujours vérifier les permissions avant un scan

${C_YELLOW}AVERTISSEMENT:${C_RESET}
  Le scan de réseaux dont vous n'êtes pas propriétaire peut être
  illégal. Utilisez ces outils uniquement sur des réseaux autorisés.

EOF
  
  echo -ne "${C_ACCENT1}Appuyez sur Entrée pour continuer...${C_RESET}"
  read -r
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================

stack_menu() {
  while true; do
    clear
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "                  ${C_GOOD}🔍 Network Scan Stack - balorsh${C_RESET}              "
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo -e "   ${C_SHADOW}──── Découverte Réseau ────${C_RESET}                              "
    echo -e "   [1] Afficher les interfaces réseau                           "
    echo -e "   [2] Détection rapide réseau local                            "
    echo -e "   [3] Scan ARP local (arp-scan)                                "
    echo -e "   [4] Netdiscover passif                                       "
    echo -e "   [5] Netdiscover actif                                        "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}──── Scans Nmap ────${C_RESET}                                      "
    echo -e "   [6] Scan rapide (top 100 ports)                              "
    echo -e "   [7] Scan complet (tous les ports)                            "
    echo -e "   [8] Scan de services et versions                             "
    echo -e "   [9] Scan furtif (stealth SYN)                                "
    echo -e "   [10] Scan de vulnérabilités (NSE)                            "
    echo -e "   [11] Scan UDP                                                "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}──── Scans Masscan ────${C_RESET}                                   "
    echo -e "   [12] Scan ultra-rapide (tous ports)                          "
    echo -e "   [13] Scan ports web                                          "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}──── Capture & Analyse ────${C_RESET}                               "
    echo -e "   [14] Capture tcpdump (vers fichier)                          "
    echo -e "   [15] Affichage tcpdump en temps réel                         "
    echo -e "   [16] Lancer Wireshark                                        "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}──── Utilitaires ────${C_RESET}                                     "
    echo -e "   [17] Nettoyer anciens scans                                  "
    echo -e "   [18] Aide                                                    "
    echo -e "                                                                 "
    echo -e "   [0] Retour                                                   "
    echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
    echo -ne "${C_ACCENT1}Votre choix: ${C_RESET}"
    read -r choice

    case "$choice" in
      1) netscan_show_interfaces ;;
      2) netscan_quick_local ;;
      3) netscan_arpscan ;;
      4) netscan_netdiscover ;;
      5) netscan_netdiscover_active ;;
      6) netscan_nmap_quick ;;
      7) netscan_nmap_full ;;
      8) netscan_nmap_services ;;
      9) netscan_nmap_stealth ;;
      10) netscan_nmap_vuln ;;
      11) netscan_nmap_udp ;;
      12) netscan_masscan_fast ;;
      13) netscan_masscan_web ;;
      14) netscan_tcpdump_capture ;;
      15) netscan_tcpdump_live ;;
      16) netscan_wireshark ;;
      17) netscan_cleanup ;;
      18) netscan_help ;;
      0) echo -e "${C_GOOD}À bientôt!${C_RESET}"; break ;;
      *) echo -e "${C_RED}Choix invalide${C_RESET}" ;;
    esac
    
    if [[ "$choice" != "0" ]]; then
      echo -e "\n${C_INFO}Appuyez sur Entrée pour continuer...${C_RESET}"
      read -r
    fi
  done
}

# Point d'entrée principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  stack_menu
fi
