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
      echo -e "${C_GOOD}${NETSCAN_VALID_CIDR} $target${C_RESET}"
      return 0
    else
      echo -e "${C_RED}${NETSCAN_INVALID_CIDR} $target${C_RESET}"
      echo -e "${C_INFO}${NETSCAN_FORMAT_CIDR}${C_RESET}"
      return 1
    fi
  else
    # Teste si c'est une IP simple
    if validate_ipv4 "$target"; then
      echo -e "${C_GOOD}${NETSCAN_VALID_IP} $target${C_RESET}"
      return 0
    else
      echo -e "${C_RED}${NETSCAN_INVALID_IP} $target${C_RESET}"
      echo -e "${C_INFO}${NETSCAN_FORMAT_IP}${C_RESET}"
      return 1
    fi
  fi
}

# Demande une cible à l'utilisateur avec validation
prompt_target() {
  local target
  while true; do
    echo -e "${C_ACCENT1}${NETSCAN_ENTER_TARGET}${C_RESET}"
    echo -e "${C_INFO}${NETSCAN_TARGET_HINT_IP}${C_RESET}"
    echo -e "${C_INFO}${NETSCAN_TARGET_HINT_CIDR}${C_RESET}"
    echo -e "${C_INFO}${NETSCAN_TARGET_HINT_RANGE}${C_RESET}"
    echo -ne "${C_HIGHLIGHT}${NETSCAN_TARGET_LABEL} ${C_RESET}"
    read -r target
    
    if [[ -z "$target" ]]; then
      echo -e "${C_RED}${NETSCAN_NO_TARGET}${C_RESET}"
      continue
    fi
    
    # Accepte aussi les plages IP (192.168.1.1-254)
    if [[ $target =~ ^([0-9.]+)-([0-9]+)$ ]]; then
      local base="${BASH_REMATCH[1]}"
      if validate_ipv4 "${base%.*}.${BASH_REMATCH[2]}"; then
        echo -e "${C_GOOD}${NETSCAN_VALID_RANGE} $target${C_RESET}"
        NETSCAN_TARGET="$target"
        return 0
      fi
    fi
    
    if validate_target "$target"; then
      NETSCAN_TARGET="$target"
      return 0
    fi
    
    echo -e "${C_YELLOW}${NETSCAN_ENTER_VALID}${C_RESET}"
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
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_NMAP_QUICK} $NETSCAN_TARGET...${C_RESET}"
  sudo nmap -F -T4 -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}${NETSCAN_RESULTS_SAVED}${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan complet tous ports avec nmap
netscan_nmap_full() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/full_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_NMAP_FULL} $NETSCAN_TARGET...${C_RESET}"
  echo -e "${C_YELLOW}${NETSCAN_WARNING_SLOW}${C_RESET}"
  sudo nmap -p- -T4 -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}${NETSCAN_RESULTS_SAVED}${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan de détection de services et versions
netscan_nmap_services() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/services_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_NMAP_SERVICES} $NETSCAN_TARGET...${C_RESET}"
  sudo nmap -sV -sC -O -T4 -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}${NETSCAN_RESULTS_SAVED}${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan furtif (stealth) SYN
netscan_nmap_stealth() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/stealth_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_NMAP_STEALTH} $NETSCAN_TARGET...${C_RESET}"
  sudo nmap -sS -T2 -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}${NETSCAN_RESULTS_SAVED}${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan avec scripts NSE (vulnérabilités)
netscan_nmap_vuln() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/vuln_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_NMAP_VULN} $NETSCAN_TARGET...${C_RESET}"
  echo -e "${C_YELLOW}${NETSCAN_WARNING_IDS}${C_RESET}"
  sudo nmap --script vuln -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}${NETSCAN_RESULTS_SAVED}${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan UDP des ports courants
netscan_nmap_udp() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/udp_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_NMAP_UDP} $NETSCAN_TARGET...${C_RESET}"
  echo -e "${C_YELLOW}${NETSCAN_WARNING_UDP}${C_RESET}"
  sudo nmap -sU --top-ports 100 -T4 -oN "${outfile}.txt" -oX "${outfile}.xml" "$NETSCAN_TARGET"
  echo -e "${C_GOOD}${NETSCAN_RESULTS_SAVED}${C_RESET}"
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
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_MASSCAN_FAST} $NETSCAN_TARGET...${C_RESET}"
  echo -e "${C_INFO}${NETSCAN_MASSCAN_PORTS}${C_RESET}"
  sudo masscan "$NETSCAN_TARGET" -p1-65535 --rate=10000 -oL "${outfile}.txt" -oX "${outfile}.xml"
  echo -e "${C_GOOD}${NETSCAN_RESULTS_SAVED}${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# Scan masscan des ports web courants
netscan_masscan_web() {
  prompt_target || return 1
  local outdir="$BALORSH_DATA_DIR/networkscan/masscan"
  mkdir -p "$outdir"
  local outfile="$outdir/web_$(date +%Y%m%d_%H%M%S)"
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_MASSCAN_WEB} $NETSCAN_TARGET...${C_RESET}"
  echo -e "${C_INFO}${NETSCAN_MASSCAN_WEB_PORTS}${C_RESET}"
  sudo masscan "$NETSCAN_TARGET" -p80,443,8000,8080,8443,3000,5000,8888 --rate=5000 -oL "${outfile}.txt" -oX "${outfile}.xml"
  echo -e "${C_GOOD}${NETSCAN_RESULTS_SAVED}${C_RESET}"
  echo -e "  ${outfile}.txt"
  echo -e "  ${outfile}.xml"
}

# ==============================================================================
# FONCTIONS DE DÉCOUVERTE RÉSEAU LOCAL
# ==============================================================================

# Scan ARP local avec arp-scan
netscan_arpscan() {
  echo -e "${C_HIGHLIGHT}${NETSCAN_SELECT_INTERFACE}${C_RESET}"
  ip -br link show | grep -v "lo" | awk '{print $1}'
  echo -ne "${C_ACCENT1}${NETSCAN_INTERFACE_DEFAULT}${C_RESET}"
  read -r iface
  iface="${iface:-eth0}"
  
  local outdir="$BALORSH_DATA_DIR/networkscan/arpscan"
  mkdir -p "$outdir"
  local outfile="$outdir/scan_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_ARP_SCAN} $iface...${C_RESET}"
  sudo arp-scan --interface="$iface" --localnet | tee "$outfile"
  echo -e "${C_GOOD}${NETSCAN_TCPDUMP_SAVED} $outfile${C_RESET}"
}

# Scan avec netdiscover
netscan_netdiscover() {
  prompt_target || return 1
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_SELECT_INTERFACE}${C_RESET}"
  ip -br link show | grep -v "lo" | awk '{print $1}'
  echo -ne "${C_ACCENT1}${NETSCAN_INTERFACE_DEFAULT}${C_RESET}"
  read -r iface
  iface="${iface:-eth0}"
  
  local outdir="$BALORSH_DATA_DIR/networkscan/netdiscover"
  mkdir -p "$outdir"
  local outfile="$outdir/passive_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_NETDISCOVER} $NETSCAN_TARGET ${NETSCAN_VIA} $iface...${C_RESET}"
  echo -e "${C_INFO}${NETSCAN_MODE_PASSIVE}${C_RESET}"
  echo -e "${C_INFO}${NETSCAN_RESULTS_IN} $outfile${C_RESET}"
  echo -e "${C_YELLOW}${NETSCAN_LAUNCHING}${C_RESET}"
  sleep 3
  
  {
    echo "${NETSCAN_HEADER_PASSIVE}"
    echo "${NETSCAN_HEADER_DATE} $(date)"
    echo "${NETSCAN_HEADER_INTERFACE} $iface"
    echo "${NETSCAN_HEADER_TARGET} $NETSCAN_TARGET"
    echo ""
    sudo timeout 60 netdiscover -i "$iface" -r "$NETSCAN_TARGET" -P 2>&1 || true
  } | tee "$outfile"
  
  echo -e "${C_GOOD}${NETSCAN_TCPDUMP_SAVED} $outfile${C_RESET}"
}

# Scan actif avec netdiscover
netscan_netdiscover_active() {
  prompt_target || return 1
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_SELECT_INTERFACE}${C_RESET}"
  ip -br link show | grep -v "lo" | awk '{print $1}'
  echo -ne "${C_ACCENT1}${NETSCAN_INTERFACE_DEFAULT}${C_RESET}"
  read -r iface
  iface="${iface:-eth0}"
  
  local outdir="$BALORSH_DATA_DIR/networkscan/netdiscover"
  mkdir -p "$outdir"
  local outfile="$outdir/active_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_NETDISCOVER_ACTIVE} $NETSCAN_TARGET ${NETSCAN_VIA} $iface...${C_RESET}"
  echo -e "${C_INFO}${NETSCAN_MODE_ACTIVE}${C_RESET}"
  echo -e "${C_INFO}${NETSCAN_RESULTS_IN} $outfile${C_RESET}"
  
  {
    echo "${NETSCAN_HEADER_ACTIVE}"
    echo "${NETSCAN_HEADER_DATE} $(date)"
    echo "${NETSCAN_HEADER_INTERFACE} $iface"
    echo "${NETSCAN_HEADER_TARGET} $NETSCAN_TARGET"
    echo ""
    sudo netdiscover -i "$iface" -r "$NETSCAN_TARGET" 2>&1 || true
  } | tee "$outfile"
  
  echo -e "${C_GOOD}${NETSCAN_TCPDUMP_SAVED} $outfile${C_RESET}"
}

# ==============================================================================
# FONCTIONS DE CAPTURE TCPDUMP
# ==============================================================================

# Capture de trafic avec tcpdump
netscan_tcpdump_capture() {
  echo -e "${C_HIGHLIGHT}${NETSCAN_SELECT_INTERFACE}${C_RESET}"
  ip -br link show | awk '{print $1}'
  echo -ne "${C_ACCENT1}${NETSCAN_INTERFACE_DEFAULT}${C_RESET}"
  read -r iface
  iface="${iface:-eth0}"
  
  local outdir="$BALORSH_DATA_DIR/networkscan/tcpdump"
  mkdir -p "$outdir"
  local outfile="$outdir/capture_$(date +%Y%m%d_%H%M%S).pcap"
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_TCPDUMP_CAPTURE} $iface...${C_RESET}"
  echo -e "${C_INFO}${NETSCAN_TCPDUMP_FILE} $outfile${C_RESET}"
  echo -e "${C_YELLOW}${NETSCAN_TCPDUMP_STOP}${C_RESET}"
  
  echo -ne "${C_ACCENT1}${NETSCAN_TCPDUMP_FILTER}${C_RESET}"
  read -r filter
  
  if [[ -n "$filter" ]]; then
    sudo tcpdump -i "$iface" -w "$outfile" "$filter"
  else
    sudo tcpdump -i "$iface" -w "$outfile"
  fi
  
  echo -e "${C_GOOD}${NETSCAN_TCPDUMP_SAVED} $outfile${C_RESET}"
  
  # Génère un résumé txt de la capture
  if [[ -f "$outfile" ]]; then
    local summary="${outfile%.pcap}_summary.txt"
    echo -e "${C_INFO}${NETSCAN_SUMMARY_GEN}${C_RESET}"
    {
      echo "${NETSCAN_HEADER_TCPDUMP}"
      echo "${NETSCAN_HEADER_DATE} $(date)"
      echo "${NETSCAN_HEADER_INTERFACE} $iface"
      echo "${NETSCAN_HEADER_FILTER} ${filter:-${NETSCAN_FILTER_NONE}}"
      echo "${NETSCAN_HEADER_FILE} $outfile"
      echo ""
      echo "${NETSCAN_HEADER_STATS}"
      sudo tcpdump -r "$outfile" -n 2>&1 | tail -n 3
      echo ""
      echo "${NETSCAN_HEADER_PACKETS}"
      sudo tcpdump -r "$outfile" -n -c 50
    } > "$summary" 2>&1
    echo -e "${C_GOOD}${NETSCAN_SUMMARY_SAVED} $summary${C_RESET}"
  fi
}

# Capture et affichage en temps réel
netscan_tcpdump_live() {
  echo -e "${C_HIGHLIGHT}${NETSCAN_SELECT_INTERFACE}${C_RESET}"
  ip -br link show | awk '{print $1}'
  echo -ne "${C_ACCENT1}${NETSCAN_INTERFACE_DEFAULT}${C_RESET}"
  read -r iface
  iface="${iface:-eth0}"
  
  echo -ne "${C_ACCENT1}${NETSCAN_TCPDUMP_FILTER_HOST}${C_RESET}"
  read -r filter
  
  local outdir="$BALORSH_DATA_DIR/networkscan/tcpdump"
  mkdir -p "$outdir"
  local outfile="$outdir/live_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_TCPDUMP_LIVE} $iface...${C_RESET}"
  echo -e "${C_INFO}${NETSCAN_TCPDUMP_SAVED_IN} $outfile${C_RESET}"
  echo -e "${C_YELLOW}${NETSCAN_TCPDUMP_STOP_CTRL}${C_RESET}"
  sleep 2
  
  {
    echo "${NETSCAN_HEADER_LIVE}"
    echo "${NETSCAN_HEADER_DATE} $(date)"
    echo "${NETSCAN_HEADER_INTERFACE} $iface"
    echo "${NETSCAN_HEADER_FILTER} ${filter:-${NETSCAN_FILTER_NONE}}"
    echo ""
    if [[ -n "$filter" ]]; then
      sudo tcpdump -i "$iface" -n -v "$filter" 2>&1 || true
    else
      sudo tcpdump -i "$iface" -n -v 2>&1 || true
    fi
  } | tee "$outfile"
  
  echo ""
  echo -e "${C_GOOD}${NETSCAN_TCPDUMP_SAVED} $outfile${C_RESET}"
}

# ==============================================================================
# FONCTIONS D'ANALYSE WIRESHARK
# ==============================================================================

# Lancer Wireshark
netscan_wireshark() {
  echo -e "${C_HIGHLIGHT}${NETSCAN_WIRESHARK_OPTIONS}${C_RESET}"
  echo "${NETSCAN_WIRESHARK_OPT1}"
  echo "${NETSCAN_WIRESHARK_OPT2}"
  echo -ne "${C_ACCENT1}${NETSCAN_WIRESHARK_CHOICE}${C_RESET}"
  read -r choice
  choice="${choice:-1}"
  
  case "$choice" in
    1)
      echo -e "${C_INFO}${NETSCAN_WIRESHARK_LAUNCH}${C_RESET}"
      sudo wireshark &
      ;;
    2)
      echo -ne "${C_ACCENT1}${NETSCAN_WIRESHARK_FILE}${C_RESET}"
      read -r pcapfile
      if [[ -f "$pcapfile" ]]; then
        echo -e "${C_INFO}${NETSCAN_WIRESHARK_OPEN} $pcapfile ${NETSCAN_WIRESHARK_IN}${C_RESET}"
        wireshark "$pcapfile" &
      else
        echo -e "${C_RED}${NETSCAN_FILE_NOT_FOUND} $pcapfile${C_RESET}"
      fi
      ;;
    *)
      echo -e "${C_RED}${NETSCAN_INVALID_CHOICE}${C_RESET}"
      ;;
  esac
}

# ==============================================================================
# FONCTIONS UTILITAIRES
# ==============================================================================

# Afficher les interfaces réseau disponibles
netscan_show_interfaces() {
  echo -e "${C_ACCENT1}${NETSCAN_INTERFACES_AVAILABLE}${C_RESET}"
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
  echo -e "${C_HIGHLIGHT}${NETSCAN_QUICK_LOCAL}${C_RESET}"
  
  # Récupère l'IP et le réseau de l'interface principale
  local default_iface=$(ip route | grep default | awk '{print $5}' | head -n1)
  local local_ip=$(ip -4 addr show "$default_iface" | grep -oP '(?<=inet\s)\d+(\.\d+){3}')
  local network=$(echo "$local_ip" | cut -d. -f1-3).0/24
  
  local outdir="$BALORSH_DATA_DIR/networkscan/nmap"
  mkdir -p "$outdir"
  local outfile="$outdir/quick_local_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_INFO}${NETSCAN_LOCAL_INTERFACE} $default_iface${C_RESET}"
  echo -e "${C_INFO}${NETSCAN_LOCAL_YOUR_IP} $local_ip${C_RESET}"
  echo -e "${C_INFO}${NETSCAN_LOCAL_NETWORK} $network${C_RESET}"
  echo ""
  
  echo -e "${C_HIGHLIGHT}${NETSCAN_LOCAL_SCAN}${C_RESET}"
  {
    echo "${NETSCAN_HEADER_LOCAL}"
    echo "${NETSCAN_HEADER_DATE} $(date)"
    echo "${NETSCAN_HEADER_INTERFACE} $default_iface"
    echo "${NETSCAN_HEADER_YOUR_IP} $local_ip"
    echo "${NETSCAN_HEADER_NETWORK} $network"
    echo ""
    echo "${NETSCAN_HEADER_RESULTS}"
    sudo nmap -sn "$network"
  } | tee "$outfile"
  
  echo ""
  echo -e "${C_GOOD}${NETSCAN_TCPDUMP_SAVED} $outfile${C_RESET}"
}

# Nettoyer les anciens scans
netscan_cleanup() {
  echo -e "${C_YELLOW}${NETSCAN_CLEANUP_PROMPT}...${C_RESET}"
  echo -ne "${C_ACCENT1}${NETSCAN_CLEANUP_PROMPT} [7]: ${C_RESET}"
  read -r days
  days="${days:-7}"
  
  if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo -e "${C_RED}${NETSCAN_INVALID_CHOICE}${C_RESET}"
    return 1
  fi
  
  local count=0
  while IFS= read -r -d '' file; do
    rm -f "$file"
    ((count++))
  done < <(find "$BALORSH_DATA_DIR/networkscan" -type f -mtime +"$days" -print0 2>/dev/null)
  
  echo -e "${C_GOOD}$count ${NETSCAN_FILES_DELETED} ${NETSCAN_CLEANUP_DONE}${C_RESET}"
}

# Aide
netscan_help() {
  cat <<EOF
${C_ACCENT1}╔${NETSCAN_HELP_BORDER}╗${C_RESET}
${C_ACCENT1}║${C_RESET}                   ${C_GOOD}${NETSCAN_HELP_TITLE_FULL}${C_RESET}                          ${C_ACCENT1}║${C_RESET}
${C_ACCENT1}╚${NETSCAN_HELP_BORDER}╝${C_RESET}

${C_HIGHLIGHT}${NETSCAN_HELP_TOOLS}${C_RESET}
${NETSCAN_HELP_NMAP}
${NETSCAN_HELP_MASSCAN}
${NETSCAN_HELP_ARPSCAN}
${NETSCAN_HELP_NETDISCOVER}
${NETSCAN_HELP_TCPDUMP}
${NETSCAN_HELP_WIRESHARK}

${C_HIGHLIGHT}${NETSCAN_HELP_FORMATS}${C_RESET}
${NETSCAN_HELP_IP}
${NETSCAN_HELP_CIDR}
${NETSCAN_HELP_RANGE}

${C_HIGHLIGHT}${NETSCAN_HELP_SCANS}${C_RESET}
${NETSCAN_HELP_QUICK}
${NETSCAN_HELP_FULL}
${NETSCAN_HELP_SERVICES}
${NETSCAN_HELP_STEALTH}
${NETSCAN_HELP_VULN}
${NETSCAN_HELP_UDP}

${C_HIGHLIGHT}${NETSCAN_HELP_SAVE}${C_RESET}
  $BALORSH_DATA_DIR/networkscan/

${C_HIGHLIGHT}${NETSCAN_HELP_TIPS}${C_RESET}
${NETSCAN_HELP_TIP1}
${NETSCAN_HELP_TIP2}
${NETSCAN_HELP_TIP3}
${NETSCAN_HELP_TIP4}

${C_YELLOW}${NETSCAN_HELP_WARNING}${C_RESET}
${NETSCAN_HELP_WARNING_TEXT1}
${NETSCAN_HELP_WARNING_TEXT2}

EOF
  
  echo -ne "${C_ACCENT1}${NETSCAN_PRESS_CONTINUE}${C_RESET}"
  read -r
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================

stack_menu() {
  while true; do
    clear
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "                  ${C_GOOD}${NETSCAN_MENU_TITLE}${C_RESET}              "
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo -e "   ${C_SHADOW}${NETSCAN_MENU_SECTION_DISCOVERY}${C_RESET}                              "
    echo -e "   ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${NETSCAN_MENU_1}${C_RESET}                           "
    echo -e "   ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${NETSCAN_MENU_2}${C_RESET}                            "
    echo -e "   ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${NETSCAN_MENU_3}${C_RESET}                                "
    echo -e "   ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${NETSCAN_MENU_4}${C_RESET}                                       "
    echo -e "   ${C_HIGHLIGHT}5)${C_RESET} ${C_INFO}${NETSCAN_MENU_5}${C_RESET}                                        "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${NETSCAN_MENU_SECTION_NMAP}${C_RESET}                                      "
    echo -e "   ${C_HIGHLIGHT}6)${C_RESET} ${C_INFO}${NETSCAN_MENU_6}${C_RESET}                              "
    echo -e "   ${C_HIGHLIGHT}7)${C_RESET} ${C_INFO}${NETSCAN_MENU_7}${C_RESET}                            "
    echo -e "   ${C_HIGHLIGHT}8)${C_RESET} ${C_INFO}${NETSCAN_MENU_8}${C_RESET}                             "
    echo -e "   ${C_HIGHLIGHT}9)${C_RESET} ${C_INFO}${NETSCAN_MENU_9}${C_RESET}                                "
    echo -e "   ${C_HIGHLIGHT}10)${C_RESET} ${C_INFO}${NETSCAN_MENU_10}${C_RESET}                            "
    echo -e "   ${C_HIGHLIGHT}11)${C_RESET} ${C_INFO}${NETSCAN_MENU_11}${C_RESET}                                                "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${NETSCAN_MENU_SECTION_MASSCAN}${C_RESET}                                   "
    echo -e "   ${C_HIGHLIGHT}12)${C_RESET} ${C_INFO}${NETSCAN_MENU_12}${C_RESET}                          "
    echo -e "   ${C_HIGHLIGHT}13)${C_RESET} ${C_INFO}${NETSCAN_MENU_13}${C_RESET}                                          "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${NETSCAN_MENU_SECTION_CAPTURE}${C_RESET}                               "
    echo -e "   ${C_HIGHLIGHT}14)${C_RESET} ${C_INFO}${NETSCAN_MENU_14}${C_RESET}                          "
    echo -e "   ${C_HIGHLIGHT}15)${C_RESET} ${C_INFO}${NETSCAN_MENU_15}${C_RESET}                         "
    echo -e "   ${C_HIGHLIGHT}16)${C_RESET} ${C_INFO}${NETSCAN_MENU_16}${C_RESET}                                        "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${NETSCAN_MENU_SECTION_UTILS}${C_RESET}                                     "
    echo -e "   ${C_HIGHLIGHT}17)${C_RESET} ${C_INFO}${NETSCAN_MENU_17}${C_RESET}                                  "
    echo -e "   ${C_HIGHLIGHT}18)${C_RESET} ${C_INFO}${NETSCAN_MENU_18}${C_RESET}                                                    "
    echo -e "                                                                 "
    echo -e "   ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${NETSCAN_MENU_0}${C_RESET}                                                   "
    echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
    echo -ne "${C_ACCENT1}${BALORSH_CHOICE}${C_RESET}"
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
      0) echo -e "${C_GOOD}${BALORSH_QUIT}${C_RESET}"; break ;;
      *) echo -e "${C_RED}${NETSCAN_INVALID_CHOICE}${C_RESET}" ;;
    esac
    
    if [[ "$choice" != "0" ]]; then
      echo -e "\n${C_INFO}${NETSCAN_PRESS_ENTER}${C_RESET}"
      read -r
    fi
  done
}

# Point d'entrée principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  stack_menu
fi
