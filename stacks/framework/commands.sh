#!/usr/bin/env bash
set -Eeuo pipefail

# stacks/framework/commands.sh
# Menu Framework complet pour balorsh

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
: "${BALORSH_DATA_DIR:=/opt/balorsh/data}"

# ==============================================================================
# FONCTIONS EXPLOITDB
# ==============================================================================

# Recherche d'exploits dans ExploitDB
framework_search_exploit() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_SEARCH_RUNNING}${C_RESET}"
  
  # Demander le terme de recherche
  echo -ne "${C_ACCENT1}${FRAMEWORK_PROMPT_SEARCH_TERM}${C_RESET}"
  read -r search_term
  
  if [[ -z "$search_term" ]]; then
    echo -e "${C_RED}${FRAMEWORK_SEARCH_CANCELLED}${C_RESET}"
    return 1
  fi
  
  local outdir="$BALORSH_DATA_DIR/framework/exploitdb"
  mkdir -p "$outdir"
  local outfile="$outdir/search_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_INFO}${FRAMEWORK_SEARCH_EXPLOIT_FOR} $search_term${C_RESET}"
  
  # Essayer searchsploit d'abord
  if command -v searchsploit >/dev/null 2>&1; then
    echo -e "${C_INFO}${FRAMEWORK_USING_SEARCHSPLIT}${C_RESET}"
    searchsploit "$search_term" > "$outfile" 2>&1
  else
    echo -e "${C_YELLOW}${FRAMEWORK_SEARCH_SPLIT_INFO}${C_RESET}"
    # Fallback: grep dans /usr/share/exploitdb si disponible
    if [[ -d "/usr/share/exploitdb" ]]; then
      echo -e "${C_INFO}${FRAMEWORK_SEARCHING_VIA_GREP}${C_RESET}"
      grep -r -i "$search_term" /usr/share/exploitdb/ > "$outfile" 2>&1 || true
    else
      echo -e "${C_RED}${FRAMEWORK_NO_METHOD_AVAILABLE}${C_RESET}"
      return 1
    fi
  fi
  
  echo -e "${C_GOOD}${FRAMEWORK_RESULTS_SAVED} $outfile${C_RESET}"
  echo -e "${C_INFO}${FRAMEWORK_PREVIEW_RESULTS}${C_RESET}"
  head -20 "$outfile" || echo "${FRAMEWORK_NO_RESULTS_FOUND}"
}

# ==============================================================================
# FONCTIONS METASPLOIT
# ==============================================================================

# Lancer Metasploit console
framework_msf_console() {
  if ! command -v msfconsole >/dev/null 2>&1; then
    echo -e "${C_RED}${FRAMEWORK_MSF_NOTFOUND}${C_RESET}"
    return 1
  fi
  
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_MSF_LAUNCHING}${C_RESET}"
  echo -e "${C_INFO}${FRAMEWORK_TYPE_EXIT_TO_QUIT}${C_RESET}"
  echo -e "${C_INFO}${FRAMEWORK_USEFUL_COMMANDS}${C_RESET}"
  echo ""
  
  msfconsole
}

# Recherche de modules Metasploit
framework_msf_search() {
  if ! command -v msfconsole >/dev/null 2>&1; then
    echo -e "${C_RED}${FRAMEWORK_MSF_NOTFOUND}${C_RESET}"
    return 1
  fi
  
  # Demander le terme de recherche
  echo -ne "${C_ACCENT1}${FRAMEWORK_PROMPT_SEARCH_TERM}${C_RESET}"
  read -r search_term
  
  if [[ -z "$search_term" ]]; then
    echo -e "${C_RED}${FRAMEWORK_SEARCH_CANCELLED}${C_RESET}"
    return 1
  fi
  
  local outdir="$BALORSH_DATA_DIR/framework/metasploit"
  mkdir -p "$outdir"
  local outfile="$outdir/search_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_INFO}${FRAMEWORK_SEARCHING_MSF_MODULES} $search_term${C_RESET}"
  
  # Utiliser msfconsole en mode non-interactif pour la recherche
  echo "search $search_term" | msfconsole -q -o "$outfile" 2>/dev/null || true
  
  echo -e "${C_GOOD}${FRAMEWORK_RESULTS_SAVED} $outfile${C_RESET}"
  echo -e "${C_INFO}${FRAMEWORK_PREVIEW_RESULTS}${C_RESET}"
  head -20 "$outfile" || echo "${FRAMEWORK_NO_RESULTS_FOUND}"
}

# Générer payload Metasploit
framework_msf_payload() {
  if ! command -v msfvenom >/dev/null 2>&1; then
    echo -e "${C_RED}${FRAMEWORK_MSFVENOM_NOT_FOUND}${C_RESET}"
    return 1
  fi
  
  # Demander les paramètres
  echo -ne "${C_ACCENT1}${FRAMEWORK_PROMPT_PAYLOAD}${C_RESET}"
  read -r payload
  
  if [[ -z "$payload" ]]; then
    payload="linux/x86/meterpreter/reverse_tcp"
    echo -e "${C_INFO}${FRAMEWORK_DEFAULT_PAYLOAD} $payload${C_RESET}"
  fi
  
  echo -ne "${C_ACCENT1}${FRAMEWORK_PROMPT_LHOST}${C_RESET}"
  read -r lhost
  
  if [[ -z "$lhost" ]]; then
    lhost="127.0.0.1"
    echo -e "${C_INFO}${FRAMEWORK_DEFAULT_LHOST} $lhost${C_RESET}"
  fi
  
  echo -ne "${C_ACCENT1}${FRAMEWORK_PROMPT_LPORT}${C_RESET}"
  read -r lport
  
  if [[ -z "$lport" ]]; then
    lport="4444"
    echo -e "${C_INFO}${FRAMEWORK_DEFAULT_LPORT} $lport${C_RESET}"
  fi
  
  echo -ne "${C_ACCENT1}${FRAMEWORK_PROMPT_FORMAT}${C_RESET}"
  read -r format
  
  if [[ -z "$format" ]]; then
    format="elf"
  fi
  
  echo -ne "${C_ACCENT1}${FRAMEWORK_PROMPT_OUTFILE}${C_RESET}"
  read -r outfile
  
  if [[ -z "$outfile" ]]; then
    outfile="$BALORSH_DATA_DIR/framework/payloads/payload_$(date +%Y%m%d_%H%M%S).$format"
    mkdir -p "$(dirname "$outfile")"
  fi
  
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_GENERATING_PAYLOAD} $outfile${C_RESET}"
  
  if msfvenom -p "$payload" LHOST="$lhost" LPORT="$lport" -f "$format" -o "$outfile" 2>/dev/null; then
    echo -e "${C_GOOD}${FRAMEWORK_PAYLOAD_GENERATED} $outfile${C_RESET}"
    ls -la "$outfile"
  else
    echo -e "${C_RED}${FRAMEWORK_PAYLOAD_FAILED} $?${C_RESET}"
  fi
}

# ==============================================================================
# FONCTIONS RAPPORTS ET MAINTENANCE
# ==============================================================================

# Générer rapport consolidé
framework_generate_report() {
  local outdir="$BALORSH_DATA_DIR/framework/reports"
  mkdir -p "$outdir"
  local outfile="$outdir/report_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_GENERATING_REPORT}${C_RESET}"
  
  {
    echo "${FRAMEWORK_REPORT_FRAMEWORK_TITLE}"
    printf "${FRAMEWORK_REPORT_DATE}\n" "$(date)"
    echo ""
    
    echo "${FRAMEWORK_REPORT_EXPLOITDB_SECTION}"
    if [[ -d "$BALORSH_DATA_DIR/framework/exploitdb" ]]; then
      find "$BALORSH_DATA_DIR/framework/exploitdb" -name "*.txt" -type f -exec basename {} \; | head -10
    else
      echo "${FRAMEWORK_REPORT_NO_EXPLOITDB}"
    fi
    echo ""
    
    echo "${FRAMEWORK_REPORT_MSF_SECTION}"
    if [[ -d "$BALORSH_DATA_DIR/framework/metasploit" ]]; then
      find "$BALORSH_DATA_DIR/framework/metasploit" -name "*.txt" -type f -exec basename {} \; | head -10
    else
      echo "${FRAMEWORK_REPORT_NO_MSF}"
    fi
    echo ""
    
    echo "${FRAMEWORK_REPORT_PAYLOADS_SECTION}"
    if [[ -d "$BALORSH_DATA_DIR/framework/payloads" ]]; then
      ls -la "$BALORSH_DATA_DIR/framework/payloads/" 2>/dev/null || echo "${FRAMEWORK_REPORT_NO_PAYLOADS}"
    else
      echo "${FRAMEWORK_REPORT_NO_PAYLOADS}"
    fi
    
  } > "$outfile"
  
  echo -e "${C_GOOD}${FRAMEWORK_REPORT_GENERATED} $outfile${C_RESET}"
}

# Mettre à jour les outils
framework_update_tools() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_UPDATING_TOOLS}${C_RESET}"
  
  # Mettre à jour ExploitDB
  if command -v searchsploit >/dev/null 2>&1; then
    echo -e "${C_INFO}${FRAMEWORK_UPDATING_EXPLOITDB}${C_RESET}"
    sudo searchsploit -u || echo "${FRAMEWORK_UPDATE_EXPLOITDB_ERROR}"
  fi
  
  # Mettre à jour Metasploit
  if command -v msfupdate >/dev/null 2>&1; then
    echo -e "${C_INFO}${FRAMEWORK_UPDATING_MSF}${C_RESET}"
    sudo msfupdate || echo "${FRAMEWORK_UPDATE_MSF_ERROR}"
  fi
  
  echo -e "${C_GOOD}${FRAMEWORK_UPDATE_COMPLETED}${C_RESET}"
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================

stack_menu() {
  while true; do
    clear
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "                 ${C_GOOD}${FRAMEWORK_MENU_TITLE}${C_RESET}              "
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo -e "   ${C_SHADOW}${FRAMEWORK_MENU_SECTION_TOOLS}${C_RESET}                              "
    echo -e "   ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${FRAMEWORK_MENU_1}${C_RESET}                           "
    echo -e "   ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${FRAMEWORK_MENU_2}${C_RESET}                            "
    echo -e "   ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${FRAMEWORK_MENU_3}${C_RESET}                                "
    echo -e "   ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${FRAMEWORK_MENU_4}${C_RESET}                                       "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${FRAMEWORK_MENU_SECTION_MAINT}${C_RESET}                                     "
    echo -e "   ${C_HIGHLIGHT}5)${C_RESET} ${C_INFO}${FRAMEWORK_MENU_7}${C_RESET}                                  "
    echo -e "   ${C_HIGHLIGHT}6)${C_RESET} ${C_INFO}${FRAMEWORK_MENU_9}${C_RESET}                                                    "
    echo -e "                                                                 "
    echo -e "   ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${FRAMEWORK_MENU_0}${C_RESET}                                                   "
    echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
    echo -ne "${C_ACCENT1}${BALORSH_CHOICE}${C_RESET}"
    read -r choice

    case "$choice" in
      1) framework_search_exploit ;;
      2) framework_msf_console ;;
      3) framework_msf_search ;;
      4) framework_msf_payload ;;
      5) framework_generate_report ;;
      6) framework_update_tools ;;
      0) echo -e "${C_GOOD}${BALORSH_QUIT}${C_RESET}"; break ;;
      *) echo -e "${C_RED}${FRAMEWORK_INVALID_CHOICE}${C_RESET}" ;;
    esac
    
    if [[ "$choice" != "0" ]]; then
      echo -e "\n${C_INFO}${FRAMEWORK_PRESS_ENTER}${C_RESET}"
      read -r
    fi
  done
}

# Point d'entrée principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  stack_menu
fi