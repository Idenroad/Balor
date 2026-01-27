#!/usr/bin/env bash
set -Eeuo pipefail

# Require Bash: provide a clear message when attempted from non-bash shells
if [ -z "${BASH_VERSION-}" ]; then
  cat >&2 <<'EOF'
This script requires Bash. Do not source it from fish or sh.
Run it with:
  bash stacks/osint/commands.sh
or make it executable and run:
  ./stacks/osint/commands.sh
EOF
  return 1 2>/dev/null || exit 1
fi
# stacks/osint/commands.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

# Defaults and paths
: "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
: "${BALORSH_DATA_DIR_USER:=$HOME/.local/share/balorsh/data}"
if [[ ! -d "$BALORSH_DATA_DIR" || ! -w "$BALORSH_DATA_DIR" ]]; then
  mkdir -p "$BALORSH_DATA_DIR_USER" 2>/dev/null || true
  if [[ -d "$BALORSH_DATA_DIR_USER" && -w "$BALORSH_DATA_DIR_USER" ]]; then
    BALORSH_DATA_DIR="$BALORSH_DATA_DIR_USER"
  fi
fi
: "${OSINT_CONFIG_DIR:=$HOME/.config/balorsh/osint}"
: "${HARVESTER_CONFIG:=$HOME/.theHarvester/api-keys.yaml}"
: "${CENSYS_CONFIG:=$HOME/.config/censys/censys.cfg}"
# JOB_DIR must exist early because helpers reference it
JOB_DIR="${JOB_DIR:-$BALORSH_DATA_DIR/osint/jobs}"

# Default available sources for theHarvester (can be overridden in environment)
: "${harvester_available_sources:=shodan,censys,securityTrails,virustotal,fullhunt,netlas,onyphe,intelx,haveibeenpwned,duckduckgo,crtsh,threatcrowd,yahoo,chaos,urlscan,certspotter,commoncrawl,gitlab,hudsonrock,leaklookup,otx,rapiddns,robtex,subdomaincenter,subdomainfinderc99,waybackarchive,windvane}"

# Helper: append an entry to an index.jsonl inside the current outdir.
# Expects the caller to set `outdir` where the index will be stored.
append_index() {
  local id="$1"; shift
  local target="$1"; shift
  local preset="$1"; shift
  local use_tld="$1"; shift
  local modules="$1"; shift
  local outfile="$1"; shift
  local sf_log="$1"; shift
  local pid_val="$1"; shift || true
  local mode_val="$1"; shift || true
  local status_val="$1"; shift || true
  local start_time="$1"; shift || true

  mkdir -p "$outdir"
  if command -v python3 >/dev/null 2>&1; then
    SF_ID="$id" SF_TARGET="$target" SF_PRESET="$preset" SF_USE_TLD="$use_tld" SF_MODULES="$modules" SF_OUTFILE="$outfile" SF_LOG="$sf_log" SF_PID="$pid_val" SF_MODE="$mode_val" SF_STATUS="$status_val" SF_START="$start_time" python3 - <<'PY' >>"$outdir/index.jsonl"
import os, json
def env(k):
    v = os.environ.get(k)
    return None if v in (None, '') else v
pid_raw = env('SF_PID')
pid_val = None
if pid_raw is not None:
    try:
        pid_val = int(pid_raw)
    except Exception:
        pid_val = None
obj = {
  'id': env('SF_ID'),
  'target': env('SF_TARGET'),
  'preset': env('SF_PRESET'),
  'use_tld': env('SF_USE_TLD'),
  'modules': env('SF_MODULES'),
  'outfile': env('SF_OUTFILE'),
  'log': env('SF_LOG'),
  'pid': pid_val,
  'mode': env('SF_MODE'),
  'status': env('SF_STATUS'),
  'start': env('SF_START')
}
print(json.dumps(obj))
PY
  else
    printf '{"id":"%s","target":"%s","preset":"%s","use_tld":"%s","modules":"%s","outfile":"%s","log":"%s","pid":%s,"mode":"%s","status":"%s","start":"%s"}\n' \
      "$id" "$target" "$preset" "$use_tld" "$modules" "$outfile" "$sf_log" "${pid_val:-null}" "$mode_val" "$status_val" "$start_time" >>"$outdir/index.jsonl"
  fi
}

osint_spiderfoot_web() {
  echo -e "${C_HIGHLIGHT}${OSINT_SPIDERFOOT_WEB_TITLE}${C_RESET}"
  echo ""
  echo -e "${C_INFO}${OSINT_SPIDERFOOT_WEB_LAUNCHING}${C_RESET}"
  if command -v spiderfoot-web &>/dev/null; then
    spiderfoot-web >/dev/null 2>&1 &
    disown 2>/dev/null || true
    echo -e "${C_GOOD}${OSINT_SPIDERFOOT_WEB_LAUNCHED}${C_RESET}"
    echo -e "${C_INFO}${OSINT_SPIDERFOOT_WEB_URL}${C_RESET}"
  else
    echo -e "${C_RED}${OSINT_SPIDERFOOT_WEB_NOT_INSTALLED}${C_RESET}"
  fi
}

osint_spiderfoot_menu() {
  while true; do
    clear
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "                  ${C_GOOD}${OSINT_SPIDERFOOT_TITLE}${C_RESET}"
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${OSINT_MENU_SPIDERFOOT_WEB}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${OSINT_MENU_SPIDERFOOT_CLI}${C_RESET}"
    echo ""
    echo -e "  ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${OSINT_MENU_RETURN}${C_RESET}"
    echo ""
    echo -ne "${C_ACCENT1}${OSINT_MENU_CHOICE}: ${C_RESET}"
    read -r choice
    case "$choice" in
      1) osint_spiderfoot_web ;;
      2) osint_spiderfoot ;;
      0) return 0 ;;
      *) echo -e "${C_RED}${OSINT_MENU_INVALID_CHOICE}${C_RESET}"; sleep 1 ;;
    esac
    echo ""
    echo -ne "${C_INFO}${REMOTEACCESS_PRESS_ENTER}${C_RESET}"
    read -r
  done
}

osint_spiderfoot() {
  echo -e "${C_HIGHLIGHT}${OSINT_SPIDERFOOT_TITLE}${C_RESET}"
  echo ""
  echo "${OSINT_SPIDERFOOT_PRESETS}"
  echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${OSINT_SPIDERFOOT_PRESET_1}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${OSINT_SPIDERFOOT_PRESET_2}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${OSINT_SPIDERFOOT_PRESET_3}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${OSINT_SPIDERFOOT_PRESET_4}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}5)${C_RESET} ${C_INFO}${OSINT_SPIDERFOOT_PRESET_5}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}6)${C_RESET} ${C_INFO}${OSINT_SPIDERFOOT_PRESET_6}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}7)${C_RESET} ${C_INFO}${OSINT_SPIDERFOOT_PRESET_7}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}8)${C_RESET} ${C_INFO}${OSINT_SPIDERFOOT_PRESET_8}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${OSINT_SPIDERFOOT_PRESET_0}${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${OSINT_SPIDERFOOT_CHOICE_PRESET}: ${C_RESET}"
  read -r preset
  preset="${preset:-1}"
  if [[ "$preset" == "0" ]]; then
    return 0
  fi

  echo -ne "${C_ACCENT1}${OSINT_SPIDERFOOT_TARGET}: ${C_RESET}"
  read -r target
  if [[ -z "$target" ]]; then
    echo -e "${C_RED}${OSINT_SPIDERFOOT_NO_TARGET}${C_RESET}"
    return 1
  fi

  echo "${OSINT_SPIDERFOOT_TLD_PROMPT}"
  read -r use_tld
  use_tld="${use_tld:-N}"

  local outdir="$BALORSH_DATA_DIR/osint/spiderfoot"
  mkdir -p "$outdir"
  local outfile="$outdir/scan_${target//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).json"
  local sf_log="${outfile%.json}.log"
  mkdir -p "$(dirname "$sf_log")"
  # Ensure modules is always defined to avoid 'set -u' unbound variable errors
  local modules=""
  # Note: append_index() is defined at top-level so it can be reused by multiple tools

  # Metadata
  local start_time
  start_time=$(date --iso-8601=seconds 2>/dev/null || date)
  local scan_id
  scan_id="sf_${target//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S)"

  # Prepend a header to the log
  printf "=== SpiderFoot scan start ===\nscan_id: %s\ntarget: %s\npreset: %s\nuse_tld: %s\nmodules: %s\noutfile: %s\nstart: %s\n===\n" \
    "$scan_id" "$target" "$preset" "$use_tld" "$modules" "$outfile" "$start_time" >>"$sf_log"

  local sf_cmd=""
  if command -v spiderfoot &>/dev/null; then
    sf_cmd="spiderfoot"
  elif command -v spiderfoot-cli &>/dev/null; then
    sf_cmd="spiderfoot-cli"
  else
    echo -e "${C_RED}${OSINT_SPIDERFOOT_NOT_INSTALLED}${C_RESET}"
    return 1
  fi
  case "$preset" in
    1)
      modules="sfp_crt,sfp_dnsresolve,sfp_commoncrawl,sfp_bingsearch,sfp_archiveorg"
      ;;
    2)
      modules="sfp_builtwith,sfp_whatcms,sfp_tool_wappalyzer,sfp_pageinfo,sfp_spider"
      ;;
    3)
      modules="sfp_crt,sfp_dnsresolve,sfp_dnsdb,sfp_censys,sfp_securitytrails"
      ;;
    4)
      modules="sfp_github,sfp_leakix,sfp_dehashed,sfp_intelx,sfp_psbdmp"
      ;;
    5)
      modules="sfp_shodan,sfp_greynoise,sfp_abuseipdb,sfp_blocklistde,sfp_spamhaus"
      ;;
    6)
      echo -e "${C_YELLOW}${OSINT_SPIDERFOOT_ACTIVE_WARNING}${C_RESET}"
      read -r ok_tools
      if [[ ! "$ok_tools" =~ ^[oO]$ ]]; then
        echo "${OSINT_SPIDERFOOT_ACTIVE_CANCELLED}"
        return 0
      fi
      modules="sfp_tool_nmap,sfp_tool_nuclei,sfp_tool_testsslsh"
      ;;
    7)
      echo -e "${C_YELLOW}${OSINT_SPIDERFOOT_FULL_WARNING}${C_RESET}"
      modules=""  # will use -u all below
      ;;
    8)
      echo -ne "${C_ACCENT1}${OSINT_SPIDERFOOT_CUSTOM_MODULES}: ${C_RESET}"
      read -r modules
      ;;
    *)
      echo -e "${C_RED}${OSINT_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac

  # If user chose TLD inclusion, append sfp_tldsearch where appropriate
  if [[ "$use_tld" =~ ^[oO]$ ]]; then
    if [[ -n "$modules" ]]; then
      modules="$modules,sfp_tldsearch"
    else
      modules="sfp_tldsearch"
    fi
  fi

  # Execute: always stream SpiderFoot output live and also log; start a small background
  # watcher that greps for errors/exceptions into an alerts file. No interactive question.
  if [[ "$preset" -eq 7 ]]; then
    if [[ -z "$modules" ]]; then
      modules="" # full scan uses -u all
    fi
    echo -e "${C_INFO}${OSINT_SPIDERFOOT_STARTING}${C_RESET}"
    append_index "$scan_id" "$target" "$preset" "$use_tld" "$modules" "$outfile" "$sf_log" "" "foreground" "started" "$start_time"
    # prepare alerts file and start grep watcher (line-buffered)
    local alert_file="$outdir/alerts_${target//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).log"
    : >"$alert_file"
    # start background greper to capture ERROR/EXCEPTION lines
    ( tail -n +1 -F "$sf_log" 2>/dev/null || true ) | grep --line-buffered -iE 'error|exception|traceback|unable|failed' >>"$alert_file" 2>/dev/null &
    local watcher_pid=$!
    disown "$watcher_pid" 2>/dev/null || true
    # Run SpiderFoot, stream output to tty and append to log
    set +e
    bash -lc "$sf_cmd -s '$target' -u all -o json" 2>&1 | tee -a "$sf_log" | tee "$outfile"
    rc=${PIPESTATUS[0]:-0}
    set -e
    kill "$watcher_pid" 2>/dev/null || true
    if [[ $rc -ne 0 ]]; then
      append_index "$scan_id" "$target" "$preset" "$use_tld" "$modules" "$outfile" "$sf_log" "" "foreground" "${OSINT_SPIDERFOOT_FAILED}" "$start_time"
    else
      append_index "$scan_id" "$target" "$preset" "$use_tld" "$modules" "$outfile" "$sf_log" "" "foreground" "${OSINT_SPIDERFOOT_COMPLETED}" "$start_time"
    fi
  else
    if [[ -z "$modules" ]]; then
      echo -e "${C_RED}${OSINT_SPIDERFOOT_NO_TARGET}${C_RESET}"
      return 1
    fi
    echo -e "${C_INFO}${OSINT_SPIDERFOOT_STARTING}${C_RESET}"
    append_index "$scan_id" "$target" "$preset" "$use_tld" "$modules" "$outfile" "$sf_log" "" "foreground" "started" "$start_time"
    local alert_file="$outdir/alerts_${target//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).log"
    : >"$alert_file"
    ( tail -n +1 -F "$sf_log" 2>/dev/null || true ) | grep --line-buffered -iE 'error|exception|traceback|unable|failed' >>"$alert_file" 2>/dev/null &
    local watcher_pid=$!
    disown "$watcher_pid" 2>/dev/null || true
    set +e
    bash -lc "$sf_cmd -s '$target' -m '$modules' -o json" 2>&1 | tee -a "$sf_log" | tee "$outfile"
    rc=${PIPESTATUS[0]:-0}
    set -e
    kill "$watcher_pid" 2>/dev/null || true
    if [[ $rc -ne 0 ]]; then
      append_index "$scan_id" "$target" "$preset" "$use_tld" "$modules" "$outfile" "$sf_log" "" "foreground" "${OSINT_SPIDERFOOT_FAILED}" "$start_time"
    else
      append_index "$scan_id" "$target" "$preset" "$use_tld" "$modules" "$outfile" "$sf_log" "" "foreground" "${OSINT_SPIDERFOOT_COMPLETED}" "$start_time"
    fi
  fi

  echo ""
  echo -e "${C_GOOD}${OSINT_LOG_LABEL}: $sf_log${C_RESET}"
}


# Lance une commande en arrière-plan et affiche le log en temps réel
# L'utilisateur peut quitter l'affichage (Ctrl-C) sans arrêter le processus
# Usage: run_bg_stream <logfile> <cmd> [args...]
run_bg_stream() {
  local logfile="$1"; shift
  mkdir -p "$(dirname "$logfile")"
  nohup "$@" >"$logfile" 2>&1 &
  local pid=$!
  disown "$pid" 2>/dev/null || true
  # enregistrer le job
  mkdir -p "$JOB_DIR"
  local jobfile="$JOB_DIR/$pid.job"
  printf "pid=%s\ncmd=%s\nlog=%s\nstart=%s\n" "$pid" "${*}" "$logfile" "$(date --iso-8601=seconds 2>/dev/null || date)" >"$jobfile"
  printf -v msg "${OSINT_BG_LAUNCHED}" "$pid"
  echo -e "${C_INFO}$* $msg${C_RESET}"
  echo -e "${C_INFO}${OSINT_LOG_LABEL}: $logfile${C_RESET}"
  sleep 1
  echo "${OSINT_REALTIME_HEADER}"
  tail -n 50 -F "$logfile" || true
  echo ""
  printf -v msg "${OSINT_REALTIME_EXIT}" "$pid"
  echo -e "${C_INFO}$msg${C_RESET}"
  printf -v msg "${OSINT_STOP_COMMAND}" "$pid" "$*"
  echo -e "${C_INFO}$msg${C_RESET}"
  return 0
}

# Run a command directly in the current terminal and tee output to logfile.
# Uses a PTY (`script -q -c`) when available so the command output matches
# what you'd see when running it manually. This does not print wrapper
# informational messages — it streams the command output directly.
run_direct() {
  local logfile="$1"; shift
  mkdir -p "$(dirname "$logfile")"
  if command -v script >/dev/null 2>&1; then
    # Some `script` implementations do not support `-c` or may block.
    # Test `script -c` using `timeout` when available and fall back to
    # a direct run if the test fails.
    if command -v timeout >/dev/null 2>&1; then
      if ! timeout 2s script -q -c "true" /dev/null >/dev/null 2>&1; then
        "$@" 2>&1 | awk '{ gsub(/\033\[[0-9;]*[mK]/, ""); print }' | tee -a "$logfile"
        return ${PIPESTATUS[0]:-0}
      fi
    else
      if ! script -q -c "true" /dev/null >/dev/null 2>&1; then
        "$@" 2>&1 | awk '{ gsub(/\033\[[0-9;]*[mK]/, ""); print }' | tee -a "$logfile"
        return ${PIPESTATUS[0]:-0}
      fi
    fi

    # `script -c` seems usable: run the command under a PTY and stream
    # output via a named pipe so we can both show live output and log it.
    local cmdstr
    cmdstr=$(printf ' %q' "$@")
    cmdstr="${cmdstr# }"
    local fifo
    fifo=$(mktemp -u)
    mkfifo "$fifo"
    ( sed -u -e '/^Script /Id' <"$fifo" \
      | awk '{ gsub(/\033\[[0-9;]*[mK]/, ""); print }' \
      | tee -a "$logfile" ) &
    local tee_pid=$!
    script -q -c "$cmdstr" "$fifo"
    local rc=$?
    wait "$tee_pid" 2>/dev/null || true
    rm -f "$fifo" 2>/dev/null || true
    return ${rc:-0}
  else
    # `script` not available: run directly and log
    "$@" 2>&1 | awk '{ gsub(/\033\[[0-9;]*[mK]/, ""); print }' | tee -a "$logfile"
    return ${PIPESTATUS[0]:-0}
  fi
}

# Lister et contrôler les jobs lancés par le script
osint_jobs() {
  echo -e "${C_HIGHLIGHT}${OSINT_JOBS_TITLE}${C_RESET}"
  echo ""
  mkdir -p "$JOB_DIR"
  local found=0
  for jf in "$JOB_DIR"/*.job; do
    [[ -f "$jf" ]] || continue
    found=1
    pid=$(grep '^pid=' "$jf" | cut -d= -f2-)
    cmd=$(grep '^cmd=' "$jf" | cut -d= -f2-)
    log=$(grep '^log=' "$jf" | cut -d= -f2-)
    start=$(grep '^start=' "$jf" | cut -d= -f2-)
    if kill -0 "$pid" 2>/dev/null; then
      status="running"
    else
      status="stopped"
    fi
    printf "PID: %-7s  %-8s  %s\n      %s\n      log: %s\n" "$pid" "$status" "$start" "$cmd" "$log"
    echo ""
  done

  if [[ $found -eq 0 ]]; then
    echo -e "${C_YELLOW}${OSINT_NO_JOBS}${C_RESET}"
    return 0
  fi

  echo "${OSINT_ACTIONS_AVAILABLE}" 
  echo -e "  ${C_HIGHLIGHT}t)${C_RESET} ${C_INFO}${OSINT_ACTION_TAIL}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}k)${C_RESET} ${C_INFO}${OSINT_ACTION_KILL}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}r)${C_RESET} ${C_INFO}${OSINT_ACTION_CLEAN}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${OSINT_ACTION_RETURN}${C_RESET}"
  echo -ne "${C_ACCENT1}${OSINT_CHOICE_PROMPT}${C_RESET}"
  read -r act
  case "$act" in
    t)
      echo -ne "${OSINT_PID_TO_TAIL}"
      read -r pid
      local jf="$JOB_DIR/$pid.job"
      if [[ ! -f "$jf" ]]; then
        printf -v msg "${OSINT_JOB_NOT_FOUND}" "$pid"
        echo -e "${C_RED}$msg${C_RESET}"
        return 1
      fi
      log=$(grep '^log=' "$jf" | cut -d= -f2-)
      printf -v msg "${OSINT_TAILING_LOG}" "$log"
      echo -e "${C_INFO}$msg${C_RESET}"
      tail -F "$log" || true
      ;;
    k)
      echo -ne "${OSINT_PID_TO_KILL}"
      read -r pid
      if kill -0 "$pid" 2>/dev/null; then
        kill "$pid" && printf -v msg "${OSINT_PID_KILLED}" "$pid" && echo -e "${C_GOOD}$msg${C_RESET}"
      else
        printf -v msg "${OSINT_PID_NOT_RUNNING}" "$pid"
        echo -e "${C_YELLOW}$msg${C_RESET}"
      fi
      ;;
    r)
      for jf in "$JOB_DIR"/*.job; do
        [[ -f "$jf" ]] || continue
        pid=$(grep '^pid=' "$jf" | cut -d= -f2-)
        if ! kill -0 "$pid" 2>/dev/null; then
          rm -f "$jf" && printf -v msg "${OSINT_JOB_REMOVED}" "$jf" && echo "$msg"
        fi
      done
      ;;
    0) return 0 ;;
    *) echo -e "${C_RED}${OSINT_INVALID_CHOICE}${C_RESET}" ;;
  esac
}


osint_spiderfoot_index() {
  local idx="$BALORSH_DATA_DIR/osint/spiderfoot/index.jsonl"
  if [[ ! -f "$idx" ]]; then
    printf -v msg "${OSINT_NO_INDEX}" "$idx"
    echo -e "${C_YELLOW}$msg${C_RESET}"
    return 1
  fi

  printf -v msg "${OSINT_SPIDERFOOT_INDEX_TITLE}" "$idx"
  echo -e "${C_HIGHLIGHT}$msg${C_RESET}"
  echo ""
  if command -v jq >/dev/null 2>&1; then
    jq -r '. | "start:\(.start) status:\(.status) mode:\(.mode) id:\(.id) target:\(.target) preset:\(.preset) pid:\(.pid) json:\(.outfile) log:\(.log)"' "$idx" | nl -ba -w3 -s'. '
  else
    nl -ba -w3 -s'. ' "$idx"
  fi

  echo ""
  echo "${OSINT_ACTIONS}"
  echo -e "  ${C_HIGHLIGHT}v)${C_RESET} ${C_INFO}${OSINT_ACTION_VIEW}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}t)${C_RESET} ${C_INFO}${OSINT_ACTION_TAIL_NUM}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${OSINT_ACTION_RETURN}${C_RESET}"
  echo -ne "${C_ACCENT1}${OSINT_CHOICE_PROMPT}${C_RESET}"
  read -r act
  case "$act" in
    v)
      echo -ne "${OSINT_NUMBER_PROMPT}"
      read -r n
      line=$(sed -n "${n}p" "$idx")
      if [[ -z "$line" ]]; then echo -e "${C_RED}${OSINT_ENTRY_NOT_FOUND}${C_RESET}"; return 1; fi
      if command -v jq >/dev/null 2>&1; then
        echo "$line" | jq .
      elif command -v python3 >/dev/null 2>&1; then
        echo "$line" | python3 -m json.tool
      else
        echo ""
        domain=$(echo "$line" | sed -n 's/.*"target":"\([^"]*\)".*/\1/p')
        printf -v msg "${OSINT_GAU_FETCHING}" "$domain"
        echo -e "${C_INFO}$msg${C_RESET}"

        # First attempt: run gau and capture logfile
        run_direct "$outfile.log" gau "$domain"

        # If gau failed due to a bad config file, detect the message and retry
        if grep -qi "error reading config" "$outfile.log" 2>/dev/null; then
          printf -v msg "${OSINT_GAU_CONFIG_ERROR}" "$gau_config"
          echo -e "${C_YELLOW}$msg${C_RESET}"
          if [[ -f "$gau_config" ]]; then
            mv "$gau_config" "${gau_config}.bak.$(date +%Y%m%d_%H%M%S)" 2>/dev/null || true
          fi
          printf '%s\n' 'providers = ["wayback","commoncrawl","otx","urlscan"]' >"$gau_config"
          printf -v msg "${OSINT_GAU_CONFIG_CREATED}" "$gau_config"
          echo -e "${C_INFO}$msg${C_RESET}"
          echo -e "${C_INFO}${OSINT_GAU_RELAUNCH}${C_RESET}"
          run_direct "$outfile.log" gau "$domain"
        fi

        echo ""
        if [[ -f "$outfile" ]]; then
          local count
          count=$(wc -l <"$outfile")
          printf -v msg "${OSINT_GAU_URLS_FOUND}" "$count"
          echo -e "${C_GOOD}$msg${C_RESET}"
          printf -v msg "${OSINT_RESULTS}" "$outfile"
          echo -e "${C_GOOD}$msg${C_RESET}"
        fi
        log=$(echo "$line" | sed -n 's/.*"log":"\([^"]*\)".*/\1/p')
      fi
      if [[ -z "$log" || ! -f "$log" ]]; then printf -v msg "${OSINT_LOG_NOT_FOUND}" "$log"; echo -e "${C_YELLOW}$msg${C_RESET}"; return 1; fi
      printf -v msg "${OSINT_TAILING_LOG}" "$log"
      echo -e "${C_INFO}$msg${C_RESET}"
      tail -F "$log" || true
      ;;
    0) return 0 ;;
    *) echo -e "${C_RED}${OSINT_INVALID_CHOICE}${C_RESET}" ;;
  esac
}

# Choisit entre affichage en temps réel ou lancement en fond.
# Utilisation interactive: si $OSINT_EXEC_MODE est défini à "bg" ou "stream", il est respecté.
# Usage: run_exec <logfile> <cmd> [args...]
run_exec() {
  local logfile="$1"; shift
  local cmd=("$@")

  # Default timeout runner: executes a command with timeout and logs output
  # Usage: run_with_timeout <seconds> <logfile> <cmd> [args...]
  run_with_timeout() {
    local timeout_secs="$1"; shift
    local logfile_inner="$1"; shift
    local cmd_inner=("$@")
    mkdir -p "$(dirname "$logfile_inner")"
    printf "${OSINT_RUN_COMMAND}" "${cmd_inner[*]}" >"$logfile_inner"
    local rc=0
    if command -v timeout >/dev/null 2>&1; then
      timeout "$timeout_secs" "${cmd_inner[@]}" >>"$logfile_inner" 2>&1 || rc=$?
    else
      "${cmd_inner[@]}" >>"$logfile_inner" 2>&1 &
      local pid_inner=$!
      ( sleep "$timeout_secs"; kill -0 "$pid_inner" 2>/dev/null && kill -9 "$pid_inner" ) &
      local watcher=$!
      wait "$pid_inner" || rc=$?
      kill -9 "$watcher" 2>/dev/null || true
    fi
    if [[ $rc -eq 124 ]]; then
      printf -v msg "${OSINT_COMMAND_TIMEOUT}" "$timeout_secs"
      echo -e "${C_RED}$msg${C_RESET}"
    fi
    if [[ $rc -ne 0 ]]; then
      printf -v msg "${OSINT_COMMAND_FAILED}" "$rc" "$logfile_inner"
      echo -e "${C_RED}$msg${C_RESET}"
      echo "${OSINT_LAST_LOG_LINES}"
      tail -n 20 "$logfile_inner"
    fi
    return $rc
  }

  # Background launcher: nohup + log file + register job
  # Usage: run_bg <logfile> <cmd> [args...]
  run_bg() {
    local logfile_inner="$1"; shift
    mkdir -p "$(dirname "$logfile_inner")"
    nohup "$@" >"$logfile_inner" 2>&1 &
    local pid_inner=$!
    disown "$pid_inner" 2>/dev/null || true
    mkdir -p "$JOB_DIR"
    local jobfile="$JOB_DIR/$pid_inner.job"
    printf "pid=%s\ncmd=%s\nlog=%s\nstart=%s\n" "$pid_inner" "${*}" "$logfile_inner" "$(date --iso-8601=seconds 2>/dev/null || date)" >"$jobfile"
    printf -v msg "${OSINT_BG_LAUNCHED}" "$pid_inner"
    echo -e "${C_INFO}$* $msg${C_RESET}"
    echo -e "${C_INFO}${OSINT_LOG_LABEL}: $logfile_inner${C_RESET}"
    sleep 1
    echo "${OSINT_LAST_LOG_LINES}"
    tail -n 20 "$logfile_inner" || true
    return 0
  }

  if [[ -n "${OSINT_EXEC_MODE:-}" ]]; then
    case "${OSINT_EXEC_MODE}" in
      bg) run_bg "$logfile" "${cmd[@]}"; return $? ;; 
      stream) run_bg_stream "$logfile" "${cmd[@]}"; return $? ;;
    esac
  fi

  echo -ne "${C_ACCENT1}${OSINT_REALTIME_PROMPT}${C_RESET}"
  read -r __choice
  __choice="${__choice:-o}"
  if [[ "${__choice}" =~ ^[oO]$ ]]; then
    run_bg_stream "$logfile" "${cmd[@]}"
  else
    run_bg "$logfile" "${cmd[@]}"
  fi
}

# ==============================================================================
# FONCTIONS DE CONFIGURATION
# ==============================================================================

osint_config_harvester() {
  echo -e "${C_HIGHLIGHT}${OSINT_HARVESTER_CONFIG_TITLE}${C_RESET}"
  echo ""

  mkdir -p "$(dirname "$HARVESTER_CONFIG")"

  if [[ ! -f "$HARVESTER_CONFIG" ]]; then
    cat > "$HARVESTER_CONFIG" <<EOF
apikeys:
  bevigil:
    key:
  binaryedge:
    key:
  bing:
    key:
  censys:
    id:
    secret:
  criminalip:
    key:
  fullhunt:
    key:
  github:
    key:
  hunter:
    key:
  intelx:
    key:
  netlas:
    key:
  pentesttools:
    key:
  projectdiscovery:
    key:
  rocketreach:
    key:
  securityTrails:
    key:
  shodan:
    key:
  virustotal:
    key:
  zoomeye:
    key:
EOF
    printf -v msg "${OSINT_CONFIG_FILE_CREATED}" "$HARVESTER_CONFIG"
    echo -e "${C_GOOD}$msg${C_RESET}"
  fi

  while true; do
    clear
    echo -e "${C_HIGHLIGHT}${OSINT_HARVESTER_API_CONFIG}${C_RESET}"
    echo ""
    printf -v msg "${OSINT_CONFIG_FILE}" "$HARVESTER_CONFIG"
    echo -e "${C_INFO}$msg${C_RESET}"
    echo ""
    echo "${OSINT_SERVICES_AVAILABLE}"
    echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${OSINT_SERVICE_1}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${OSINT_SERVICE_2}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${OSINT_SERVICE_3}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${OSINT_SERVICE_4}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}5)${C_RESET} ${C_INFO}${OSINT_SERVICE_5}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}6)${C_RESET} ${C_INFO}${OSINT_SERVICE_6}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}7)${C_RESET} ${C_INFO}${OSINT_SERVICE_7}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}8)${C_RESET} ${C_INFO}${OSINT_SERVICE_8}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}9)${C_RESET} ${C_INFO}${OSINT_SERVICE_9}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}10)${C_RESET} ${C_INFO}${OSINT_SERVICE_10}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}11)${C_RESET} ${C_INFO}${OSINT_SERVICE_11}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}12)${C_RESET} ${C_INFO}${OSINT_SERVICE_12}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}13)${C_RESET} ${C_INFO}${OSINT_SERVICE_13}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}14)${C_RESET} ${C_INFO}${OSINT_SERVICE_14}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}15)${C_RESET} ${C_INFO}${OSINT_SERVICE_15}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}16)${C_RESET} ${C_INFO}${OSINT_SERVICE_16}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}17)${C_RESET} ${C_INFO}${OSINT_SERVICE_17}${C_RESET}"
    echo ""
    echo -e "  ${C_HIGHLIGHT}e)${C_RESET} ${C_INFO}${OSINT_EDIT_MANUALLY}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${OSINT_ACTION_RETURN}${C_RESET}"
    echo ""
    echo -ne "${C_ACCENT1}${OSINT_CHOICE_PROMPT}${C_RESET}"
    read -r choice

    case "$choice" in
      1)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_SHODAN}${C_RESET}"
        read -r key
        sed -i "/shodan:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      
      2)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_CENSYS_ID}${C_RESET}"
        read -r id
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_CENSYS_SECRET}${C_RESET}"
        read -r secret
        sed -i "/censys:/,/secret:/ {s|id:.*|id: $id|; s|secret:.*|secret: $secret|}" "$HARVESTER_CONFIG"
        ;;
      3)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_VIRUSTOTAL}${C_RESET}"
        read -r key
        sed -i "/virustotal:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      4)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_HUNTER}${C_RESET}"
        read -r key
        sed -i "/hunter:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      5)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_SECURITYTRAILS}${C_RESET}"
        read -r key
        sed -i "/securityTrails:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      6)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_GITHUB}${C_RESET}"
        read -r key
        sed -i "/github:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      7)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_BINARYEDGE}${C_RESET}"
        read -r key
        sed -i "/binaryedge:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      8)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_FULLHUNT}${C_RESET}"
        read -r key
        sed -i "/fullhunt:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      9)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_INTELX}${C_RESET}"
        read -r key
        sed -i "/intelx:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      10)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_ZOOMEYE}${C_RESET}"
        read -r key
        sed -i "/zoomeye:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      11)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_NETLAS}${C_RESET}"
        read -r key
        sed -i "/netlas:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      12)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_PROJECTDISCOVERY}${C_RESET}"
        read -r key
        sed -i "/projectdiscovery:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      13)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_BING}${C_RESET}"
        read -r key
        sed -i "/bing:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      14)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_BEVIGIL}${C_RESET}"
        read -r key
        sed -i "/bevigil:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      15)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_CRIMINALIP}${C_RESET}"
        read -r key
        sed -i "/criminalip:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      16)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_PENTESTTOOLS}${C_RESET}"
        read -r key
        sed -i "/pentesttools:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      17)
        echo -ne "${C_ACCENT1}${OSINT_API_KEY_ROCKETREACH}${C_RESET}"
        read -r key
        sed -i "/rocketreach:/,/key:/ s|key:.*|key: $key|" "$HARVESTER_CONFIG"
        ;;
      e)
        ${EDITOR:-nano} "$HARVESTER_CONFIG"
        ;;
      0)
        break
        ;;
      *)
        echo -e "${C_RED}Choix invalide${C_RESET}"
        sleep 1
        ;;
    esac
  done
}

osint_config_censys() {
  echo -e "${C_HIGHLIGHT}Configuration Censys${C_RESET}"
  echo ""

  mkdir -p "$(dirname "$CENSYS_CONFIG")"

  echo -ne "${C_ACCENT1}Censys API ID: ${C_RESET}"
  read -r api_id
  echo -ne "${C_ACCENT1}Censys API Secret: ${C_RESET}"
  read -r api_secret

  cat > "$CENSYS_CONFIG" <<EOF
[DEFAULT]
api_id = $api_id
api_secret = $api_secret
EOF

  echo ""
  printf -v msg "${OSINT_CENSYS_CONFIG_SAVED}" "$CENSYS_CONFIG"
  echo -e "${C_GOOD}$msg${C_RESET}"
}



# ==============================================================================
# VALIDATION DOMAINES / IP
# ==============================================================================

validate_domain() {
  local domain="$1"
  if [[ $domain =~ ^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?\.)+[a-zA-Z]{2,}$ ]]; then
    return 0
  else
    return 1
  fi
}

validate_ip() {
  local ip="$1"
  if [[ $ip =~ ^([0-9]{1,3}\.){3}[0-9]{1,3}$ ]]; then
    local -a octets
    IFS='.' read -ra octets <<< "$ip"
    for octet in "${octets[@]}"; do
      if (( octet > 255 )); then
        return 1
      fi
    done
    return 0
  else
    return 1
  fi
}

prompt_domain() {
  local domain
  # Allow non-interactive invocation via environment variable
  if [[ -n "${OSINT_DOMAIN:-}" ]]; then
    domain="${OSINT_DOMAIN}"
    if validate_domain "$domain"; then
      echo "$domain"
      return 0
    fi
  fi
  while true; do
    # Use echo -ne for consistent color handling across different shells
    mkdir -p "$BALORSH_DATA_DIR/osint" 2>/dev/null || true
    # Prompt using stdin when it's a TTY (same pattern as other stacks)
    if [[ -t 0 ]]; then
      read -r -p "${C_ACCENT1}${OSINT_DOMAIN_PROMPT}${C_RESET}" domain
    else
      # stdin not a TTY: try /dev/tty as fallback
      if ! read -r domain </dev/tty 2>/dev/null; then
        return 1
      fi
    fi
    if [[ -z "$domain" ]]; then
      echo -e "${C_RED}${OSINT_NO_DOMAIN_SPECIFIED}${C_RESET}"
      continue
    fi
    if validate_domain "$domain"; then
      echo "$domain"
      return 0
    else
      echo -e "${C_RED}${OSINT_INVALID_DOMAIN}${C_RESET}"
    fi
  done
}

# Simple Amass menu to pick passive/active (backwards compatible)
osint_amass_menu() {
  while true; do
    clear
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "                  ${C_GOOD}${OSINT_AMASS_MENU_TITLE:-Amass}${C_RESET}"
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${OSINT_AMASS_PASSIVE_TITLE}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${OSINT_AMASS_ACTIVE_TITLE}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${OSINT_MENU_RETURN}${C_RESET}"
    echo ""
    echo -ne "${C_ACCENT1}${OSINT_AMASS_MENU_CHOICE:-Votre choix}: ${C_RESET}"
    read -r achoice
    case "$achoice" in
      1)
        # prompt domain here so the question appears inside the submenu
        d=$(prompt_domain) || { echo -e "${C_RED}${OSINT_NO_DOMAIN_PROVIDED}${C_RESET}"; continue; }
        osint_amass_passive "$d"
        return 0 ;;
      2)
        d=$(prompt_domain) || { echo -e "${C_RED}${OSINT_NO_DOMAIN_PROVIDED}${C_RESET}"; continue; }
        osint_amass_active "$d"
        return 0 ;;
      0) return 0 ;;
      *) echo -e "${C_RED}${OSINT_INVALID_CHOICE}${C_RESET}" ;;
    esac
    echo ""
    echo -ne "${C_INFO}${REMOTEACCESS_PRESS_ENTER}${C_RESET}"
    read -r
  done
}

prompt_host() {
  local host
  while true; do
    mkdir -p "$BALORSH_DATA_DIR/osint" 2>/dev/null || true
    if [[ -t 0 ]]; then
      read -r -p "${C_ACCENT1}${OSINT_HOST_PROMPT}${C_RESET}" host
    else
      if ! read -r host </dev/tty 2>/dev/null; then
        return 1
      fi
    fi
    if [[ -z "$host" ]]; then
      echo -e "${C_RED}${OSINT_NO_HOST_SPECIFIED}${C_RESET}"
      continue
    fi
    if validate_ip "$host" || validate_domain "$host"; then
      echo "$host"
      return 0
    else
      echo -e "${C_RED}${OSINT_INVALID_HOST}${C_RESET}"
    fi
  done
}

# ==============================================================================
# OUTILS
# ==============================================================================

osint_maltego() {
  echo -e "${C_HIGHLIGHT}${OSINT_MALTEGO_LAUNCHING}...${C_RESET}"
  echo ""
  if command -v maltego &>/dev/null; then
    maltego & disown
    echo -e "${C_GOOD}${OSINT_MALTEGO_LAUNCHED}${C_RESET}"
  else
    echo -e "${C_RED}${OSINT_MALTEGO_NOT_INSTALLED}${C_RESET}"
    echo -e "${C_INFO}${OSINT_MALTEGO_INSTALL}${C_RESET}"
  fi
}

 

osint_censys_search() {
  echo -e "${C_HIGHLIGHT}${OSINT_CENSYS_SEARCH_TITLE}${C_RESET}"
  echo ""

  if [[ ! -f "$CENSYS_CONFIG" ]]; then
    echo -e "${C_YELLOW}${OSINT_CENSYS_CONFIG_NOT_FOUND}${C_RESET}"
    echo -e "${C_INFO}${OSINT_CENSYS_CONFIGURE_API}${C_RESET}"
    return 1
  fi

  # Prompt for target (domain or IP) — we ask only what's necessary
  local target
  target=$(prompt_host)
  if validate_ip "$target"; then
    local query
    query="ip: $target"
  else
    local query
    query="services.tls.certificates.leaf_data.subject.common_name: $target"
  fi

  local outdir="$BALORSH_DATA_DIR/osint/censys"
  mkdir -p "$outdir"
  local outfile="$outdir/search_${target//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).json"

  echo ""
  echo -e "${C_INFO}${OSINT_CENSYS_QUERY}: $query${C_RESET}"

  if command -v censys &>/dev/null; then
  local censys_log="$outfile.log"
  run_direct "$censys_log" censys search "$query" --pretty
    echo ""
    echo -e "${C_GOOD}${OSINT_SHODAN_RESULTS_LOG}: $censys_log${C_RESET}"
  else
    echo -e "${C_RED}${OSINT_CENSYS_CLI_NOT_INSTALLED}${C_RESET}"
    echo -e "${C_INFO}${OSINT_CENSYS_INSTALL_INSTRUCTIONS}${C_RESET}"
  fi
}

osint_censys_certs() {
  echo -e "${C_HIGHLIGHT}${OSINT_CENSYS_CERTS_TITLE}${C_RESET}"
  echo ""

  if [[ ! -f "$CENSYS_CONFIG" ]]; then
    echo -e "${C_YELLOW}${OSINT_CENSYS_CONFIG_NOT_FOUND}${C_RESET}"
    return 1
  fi

  local domain
  # allow domain to be passed as first arg (used by submenu or env)
  if [[ -n "${1:-}" ]]; then
    domain="$1"
  elif [[ -n "${OSINT_DOMAIN:-}" ]]; then
    domain="$OSINT_DOMAIN"
  else
    domain=$(prompt_domain) || return 1
  fi

  # Safety: ensure domain is not empty (prompt_domain should loop until valid)
  if [[ -z "$domain" ]]; then
    echo -e "${C_RED}${OSINT_CENSYS_NO_DOMAIN}${C_RESET}"
    return 1
  fi

  local outdir="$BALORSH_DATA_DIR/osint/censys"
  mkdir -p "$outdir"
  local outfile="$outdir/certs_${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).json"

  echo ""
  echo -e "${C_INFO}${OSINT_CENSYS_FETCHING_CERTS} $domain...${C_RESET}"

  if command -v censys &>/dev/null; then
  local censys_log="$outfile.log"
  run_direct "$censys_log" censys search "parsed.names: $domain" --index-type certificates
    echo ""
    echo -e "${C_GOOD}${OSINT_SHODAN_RESULTS_LOG}: $censys_log${C_RESET}"
  else
    echo -e "${C_RED}${OSINT_CENSYS_CLI_NOT_INSTALLED}${C_RESET}"
  fi
}

osint_harvester() {
  echo -e "${C_HIGHLIGHT}${OSINT_HARVESTER_TITLE}${C_RESET}"
  echo ""
  # Ask sources first (so we don't prompt for domain and then run immediately)
  echo ""
  echo "${OSINT_HARVESTER_SOURCES_TITLE}"
  echo -e "  ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}Retour${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${OSINT_ALL_SOURCES}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${OSINT_SOURCES_WITH_API}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${OSINT_CUSTOM_CHOICE}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${OSINT_SOURCES_WITHOUT_API}${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${OSINT_HARVESTER_CHOICE_PROMPT} [1]: ${C_RESET}"
  read -r choice
  choice="${choice:-1}"

  local sources=""
  case "$choice" in
    0) return 0 ;;
    1)
      # Build the full list but exclude sources that require API keys which are not configured
      IFS=',' read -ra _all_sources_arr <<< "$harvester_available_sources"
      local filtered_sources=()
      local missing_api_list=()
      for s in "${_all_sources_arr[@]}"; do
        # trim spaces
        s_trim=$(echo "$s" | sed -e 's/^ *//' -e 's/ *$//')
        case "$s_trim" in
          shodan)
            if [[ -n "${SHODAN_APIKEY:-}" ]]; then filtered_sources+=("$s_trim"); else missing_api_list+=("$s_trim"); fi
            ;;
          censys)
            if [[ -f "${CENSYS_CONFIG:-}" ]]; then filtered_sources+=("$s_trim"); else missing_api_list+=("$s_trim"); fi
            ;;
          securityTrails)
            if [[ -n "${SECURITYTRAILS_APIKEY:-}" ]]; then filtered_sources+=("$s_trim"); else missing_api_list+=("$s_trim"); fi
            ;;
          virustotal)
            if [[ -n "${VIRUSTOTAL_API_KEY:-}" || -n "${VT_API_KEY:-}" ]]; then filtered_sources+=("$s_trim"); else missing_api_list+=("$s_trim"); fi
            ;;
          fullhunt)
            if [[ -n "${FULLHUNT_API_KEY:-}" ]]; then filtered_sources+=("$s_trim"); else missing_api_list+=("$s_trim"); fi
            ;;
          netlas)
            if [[ -n "${NETLAS_API_KEY:-}" ]]; then filtered_sources+=("$s_trim"); else missing_api_list+=("$s_trim"); fi
            ;;
          onyphe)
            if [[ -n "${ONYPHE_API_KEY:-}" ]]; then filtered_sources+=("$s_trim"); else missing_api_list+=("$s_trim"); fi
            ;;
          intelx)
            if [[ -n "${INTELX_API_KEY:-}" || -n "${INTELX_TOKEN:-}" ]]; then filtered_sources+=("$s_trim"); else missing_api_list+=("$s_trim"); fi
            ;;
          haveibeenpwned)
            if [[ -n "${HAVEIBEENPWNED_API_KEY:-}" ]]; then filtered_sources+=("$s_trim"); else missing_api_list+=("$s_trim"); fi
            ;;
          *)
            filtered_sources+=("$s_trim")
            ;;
        esac
      done
      if [[ ${#filtered_sources[@]} -eq 0 ]]; then
        echo -e "${C_RED}${OSINT_NO_SOURCES_WITHOUT_API}${C_RESET}"
        return 1
      fi
      sources=$(IFS=','; echo "${filtered_sources[*]}")
      if [[ ${#missing_api_list[@]} -gt 0 ]]; then
        echo ""
        echo -e "${C_YELLOW}${OSINT_SOURCES_REQUIRE_API}${C_RESET}"
        echo "  ${missing_api_list[*]}"
        echo ""
        echo -ne "${C_ACCENT1}${OSINT_HARVESTER_CONTINUE_PROMPT} (${#filtered_sources[@]}) ? (o/N): ${C_RESET}"
        read -r cont
        if [[ ! "$cont" =~ ^[oO]$ ]]; then
          echo "${OSINT_HARVESTER_CANCELLED}"
          return 1
        fi
      fi
      ;;
    2) sources="shodan,censys" ;;
    3)
      echo "${OSINT_HARVESTER_AVAILABLE_SOURCES}"
      echo "  $harvester_available_sources"
      echo ""
      echo -ne "${C_ACCENT1}${OSINT_HARVESTER_SOURCES_PROMPT}: ${C_RESET}"
      read -r sources
      ;;
    4)
      # Sources that don't require API keys (verified noapi sources)
      sources="chaos,duckduckgo,urlscan,certspotter,commoncrawl,crtsh,gitlab,hudsonrock,leaklookup,otx,rapiddns,robtex,subdomaincenter,subdomainfinderc99,waybackarchive,windvane,yahoo"
      printf "${C_INFO}${OSINT_USING_SOURCES_NO_API}${C_RESET}\n" "$sources"
      # For noapi option, skip the action menu and go directly to default search
      harv_action="1"
      ;;
    *)
      echo -e "${C_RED}${OSINT_HARVESTER_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac

  # Ask for target domain after sources selection
  local domain
  # allow domain to be passed as first arg (used by submenu or env)
  if [[ -n "${1:-}" ]]; then
    domain="$1"
  elif [[ -n "${OSINT_DOMAIN:-}" ]]; then
    domain="$OSINT_DOMAIN"
  else
    domain=$(prompt_domain) || return 1
  fi

  # Valider les sources sélectionnées
  if [[ -n "$sources" ]]; then
    printf "${C_INFO}${OSINT_VALIDATING_SOURCES}${C_RESET}\n" "$sources"
    # Test rapide avec --help pour voir si les sources sont reconnues
    if ! timeout 10 theHarvester -d example.com -b "$sources" --help >/dev/null 2>&1; then
      echo -e "${C_YELLOW}${OSINT_WARNING_SOME_SOURCES_UNAVAILABLE}${C_RESET}"
      echo -e "${C_INFO}${OSINT_CONTINUE_WITH_VALID_SOURCES}${C_RESET}"
    fi
  fi

  local outdir="$BALORSH_DATA_DIR/osint/harvester"
  local start_time
  start_time=$(date --iso-8601=seconds 2>/dev/null || date)
  local harv_id
  harv_id="harv_${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S)"

  # Prepare a basename early so DNS/reverse actions can save alongside harvester outputs
  local basename="harvester_${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S)"

  # Sub-menu: allow DNS resolve (-n) or reverse lookup (-r) before running theHarvester
  # Skip this menu for option 5 (noapi) which goes directly to default search
  if [[ -z "${harv_action:-}" ]]; then
    echo ""
    echo "${OSINT_HARVESTER_ACTIONS_TITLE} $domain :"
    echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${OSINT_HARVESTER_ACTION_DEFAULT}${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}n)${C_RESET} ${C_INFO}${OSINT_HARVESTER_ACTION_DNS} -> ${OSINT_HARVESTER_SAVE_DNS} ${basename}_dns.txt${C_RESET}" 
    echo -e "  ${C_HIGHLIGHT}r)${C_RESET} ${C_INFO}${OSINT_HARVESTER_ACTION_REVERSE} -> ${OSINT_HARVESTER_SAVE_REVERSE} ${basename}_reverse.txt${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${OSINT_HARVESTER_ACTION_CANCEL}${C_RESET}"
    echo ""
    echo -ne "${C_ACCENT1}${OSINT_HARVESTER_CHOICE_PROMPT} [1]: ${C_RESET}"
    read -r harv_action
    harv_action="${harv_action:-1}"
  fi

  case "$harv_action" in
    n)
      # DNS resolution: A and AAAA
      if ! mkdir -p "$outdir" 2>/dev/null; then outdir="/tmp/balorsh_osint_harvester"; mkdir -p "$outdir" || { echo -e "${C_RED}${OSINT_HARVESTER_DIR_CREATE_FAILED}${C_RESET}"; return 1; }; fi
      local dns_out="$outdir/${basename}_dns.txt"
      echo -e "${C_INFO}${OSINT_HARVESTER_DNS_RESOLVING} $domain...${C_RESET}"
      if command -v dig >/dev/null 2>&1; then
        dig +short A "$domain" >"$dns_out" || true
        dig +short AAAA "$domain" >>"$dns_out" || true
      else
        # fallback to getent/host
        host "$domain" 2>/dev/null >"$dns_out" || true
      fi
      echo -e "${C_GOOD}${OSINT_HARVESTER_DNS_RESULTS}: $dns_out${C_RESET}"
      return 0
      ;;
    r)
      # Reverse lookup: obtain IPs then reverse-resolve
      if command -v dig >/dev/null 2>&1; then
        ips=$(dig +short A "$domain" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' || true)
      else
        ips=$(host "$domain" 2>/dev/null | awk '/has address/ {print $4}' || true)
      fi
      if [[ -z "$ips" ]]; then
        echo -ne "${C_ACCENT1}${OSINT_HARVESTER_NO_IP_FOUND}: ${C_RESET}"
        read -r ips
      fi
      if [[ -z "$ips" ]]; then
        echo -e "${C_RED}${OSINT_HARVESTER_NO_IP_PROVIDED}${C_RESET}"
        return 1
      fi
      if ! mkdir -p "$outdir" 2>/dev/null; then outdir="/tmp/balorsh_osint_harvester"; mkdir -p "$outdir" || { echo -e "${C_RED}${OSINT_HARVESTER_DIR_CREATE_FAILED}${C_RESET}"; return 1; }; fi
      local rev_out="$outdir/${basename}_reverse.txt"
      echo -e "${C_INFO}${OSINT_HARVESTER_REVERSE_LOOKUP}: $ips${C_RESET}"
      : >"$rev_out"
      for ip in $ips; do
        if command -v host >/dev/null 2>&1; then
          host "$ip" >>"$rev_out" 2>&1 || echo "no-reverse:$ip" >>"$rev_out"
        else
          dig -x +short "$ip" >>"$rev_out" 2>&1 || echo "no-reverse:$ip" >>"$rev_out"
        fi
      done
      echo -e "${C_GOOD}${OSINT_HARVESTER_REVERSE_RESULTS}: $rev_out${C_RESET}"
      return 0
      ;;
    0)
      echo "${OSINT_HARVESTER_CANCELLED}"
      return 0
      ;;
    *)
      # continue to run theHarvester
      ;;
  esac


  # Try to create the data dir; fallback to /tmp if not possible
  if ! mkdir -p "$outdir" 2>/dev/null; then
    echo -e "${C_YELLOW}${OSINT_HARVESTER_DIR_FALLBACK} $outdir, ${OSINT_HARVESTER_SWITCH_TMP}${C_RESET}"
    outdir="/tmp/balorsh_osint_harvester"
    mkdir -p "$outdir" || { echo -e "${C_RED}${OSINT_HARVESTER_DIR_FALLBACK_FAILED}${C_RESET}"; return 1; }
  fi

  local basename="harvester_${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S)"
  local outfile="$outdir/${basename}"
  local harvester_log="${outfile}.log"

  echo ""
  echo -e "${C_INFO}${OSINT_HARVESTER_SEARCHING} $domain...${C_RESET}"
  echo -e "${C_INFO}${OSINT_HARVESTER_SOURCES_USED}: $sources${C_RESET}"

  # Detect theHarvester executable (try common variants)
  local th_exec=""
  for candidate in theHarvester theharvester theHarvester.py; do
    if command -v "$candidate" &>/dev/null; then
      th_exec="$(command -v "$candidate")"
      break
    fi
  done
  if [[ -z "$th_exec" ]]; then
    echo -e "${C_RED}${OSINT_HARVESTER_NOT_FOUND}${C_RESET}"
    echo -e "${C_INFO}${OSINT_HARVESTER_INSTALL_INSTRUCTIONS}${C_RESET}"
    return 1
  fi

  # Vérifier que theHarvester est installé et accessible
  if ! command -v theHarvester >/dev/null 2>&1; then
    echo -e "${C_RED}${OSINT_HARVESTER_NOT_INSTALLED}${C_RESET}"
    echo -e "${C_INFO}${OSINT_HARVESTER_INSTALL_INSTRUCTIONS}${C_RESET}"
    return 1
  fi

  # Test rapide de theHarvester pour vérifier qu'il fonctionne
  echo -e "${C_INFO}${OSINT_HARVESTER_TESTING}${C_RESET}"
  if ! timeout 5 "$th_exec" --help >/dev/null 2>&1; then
    echo -e "${C_RED}${OSINT_HARVESTER_NOT_WORKING}${C_RESET}"
    printf -v msg "${OSINT_CHECK_INSTALLATION}" "$th_exec"
    echo -e "${C_INFO}$msg${C_RESET}"
    return 1
  fi
  echo -e "${C_GOOD}${OSINT_HARVESTER_OK}${C_RESET}"

  # Start index entry (re-use append_index to keep same UX)
  mkdir -p "$(dirname "$harvester_log")"
  append_index "$harv_id" "$domain" "theHarvester" "" "$sources" "$outfile" "$harvester_log" "" "foreground" "started" "$start_time"

  # Start alert watcher
  local alert_file="$outdir/alerts_harvester_${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).log"
  : >"$alert_file"
  ( tail -n +1 -F "$harvester_log" 2>/dev/null || true ) | grep --line-buffered -iE 'error|exception|traceback|unable|failed' >>"$alert_file" 2>/dev/null &
  local watcher_pid=$!
  disown "$watcher_pid" 2>/dev/null || true

  # Run theHarvester, stream output to log (and to the terminal).
  # Execute theHarvester directly for exact same behavior as manual execution
  printf "${C_INFO}${OSINT_LAUNCHING_HARVESTER}${C_RESET}\n" "$domain" "$sources"
  echo -e "${C_INFO}${OSINT_MANUAL_COMMAND_OUTPUT}${C_RESET}"
  echo ""
  
  set +e
  # Execute theHarvester directly without any interference to preserve exact behavior
  timeout 120s "$th_exec" -d "$domain" -b "$sources" -f "$outfile"
  rc=$?
  set -e
  
  # Copy output to log file after execution
  if [[ -f "$outfile" ]]; then
    cp "$outfile" "$harvester_log" 2>/dev/null || cat "$outfile" > "$harvester_log" 2>/dev/null || true
  fi

  kill "$watcher_pid" 2>/dev/null || true
  echo ""
  if [[ $rc -ne 0 ]]; then
    append_index "$harv_id" "$domain" "theHarvester" "" "$sources" "$outfile" "$harvester_log" "" "foreground" "failed" "$start_time"
    echo -e "${C_RED}${OSINT_HARVESTER_FAILED} (code $rc)${C_RESET}"
    echo -e "${C_INFO}${OSINT_HARVESTER_SEE_LOG}: $harvester_log${C_RESET}"
    if [[ -f "$alert_file" && -s "$alert_file" ]]; then
      echo -e "${C_YELLOW}${OSINT_ERRORS_DETECTED}${C_RESET}"
      cat "$alert_file"
    fi
    return $rc
  else
    append_index "$harv_id" "$domain" "theHarvester" "" "$sources" "$outfile" "$harvester_log" "" "foreground" "finished" "$start_time"
    echo -e "${C_GOOD}${OSINT_HARVESTER_SUCCESS}${C_RESET}"
  fi

  # Afficher un résumé des résultats
  echo ""
  echo -e "${C_HIGHLIGHT}${OSINT_RESULTS_SUMMARY}${C_RESET}"
  if [[ -f "$outfile" ]]; then
    printf -v msg "${OSINT_RESULTS_FILE}" "$outfile"
    echo -e "${C_INFO}$msg${C_RESET}"
    # Compter les lignes dans les sections principales
    local hosts_count=$(grep -c "^\[*\]" "$outfile" 2>/dev/null || echo "0")
    local emails_count=$(grep -c "@" "$outfile" 2>/dev/null || echo "0")
    printf -v msg "${OSINT_HOSTS_FOUND}" "$hosts_count"
    echo -e "${C_INFO}$msg${C_RESET}"
    printf -v msg "${OSINT_EMAILS_FOUND}" "$emails_count"
    echo -e "${C_INFO}$msg${C_RESET}"
  else
    echo -e "${C_RED}${OSINT_NO_RESULTS_FILE}${C_RESET}"
  fi
  
  if [[ -f "$harvester_log" ]]; then
    printf "${C_INFO}${OSINT_HARVESTER_FULL_LOG}${C_RESET}\n" "$harvester_log"
  fi

  echo ""
  echo -e "${C_GOOD}${OSINT_HARVESTER_RESULTS_SAVED}: $outdir/${basename}.*${C_RESET}"
}

osint_amass_passive() {
  echo -e "${C_HIGHLIGHT}${OSINT_AMASS_PASSIVE_TITLE}${C_RESET}"
  echo ""
  local domain
  # use provided arg or env var if available to avoid re-prompting
  if [[ -n "${1:-}" ]]; then
    domain="$1"
  elif [[ -n "${OSINT_DOMAIN:-}" ]]; then
    domain="$OSINT_DOMAIN"
  else
    domain=$(prompt_domain) || return 1
  fi

  local outdir="$BALORSH_DATA_DIR/osint/amass"
  mkdir -p "$outdir"
  local outfile="$outdir/passive_${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).txt"

  echo ""
  echo -e "${C_INFO}${OSINT_AMASS_PASSIVE_ENUM} $domain...${C_RESET}"
  echo -e "${C_INFO}${OSINT_PLEASE_WAIT}${C_RESET}"

  local amass_log="$outdir/passive_${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).log"
  # Detect supported flags to maintain compatibility across amass versions
  local src_flag="" ip_flag=""
  if amass enum -h 2>&1 | grep -q -- '-src'; then src_flag='-src'; fi
  if amass enum -h 2>&1 | grep -q -- '-ip'; then ip_flag='-ip'; fi
  # Build command array
  local cmd=(amass enum -passive -v)
  [[ -n "$src_flag" ]] && cmd+=("$src_flag")
  [[ -n "$ip_flag" ]] && cmd+=("$ip_flag")
  cmd+=(-d "$domain" -o "$outfile")
  run_direct "$amass_log" "${cmd[@]}"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    if [[ $rc -eq 130 ]]; then
      echo -e "\n${C_YELLOW}${OSINT_AMASS_INTERRUPTED} (SIGINT). ${OSINT_AMASS_CODE}: $rc${C_RESET}"
    else
      echo -e "\n${C_RED}${OSINT_AMASS_FAILED} $rc${C_RESET}"
    fi
    return $rc
  fi

  echo ""
  if [[ -f "$outfile" ]]; then
    local count
    count=$(wc -l <"$outfile")
    echo -e "${C_GOOD}$count ${OSINT_AMASS_SUBDOMAINS_FOUND}${C_RESET}"
    echo -e "${C_GOOD}${OSINT_AMASS_RESULTS}: $outfile${C_RESET}"
  fi
}

osint_amass_active() {
  echo -e "${C_HIGHLIGHT}${OSINT_AMASS_ACTIVE_TITLE}${C_RESET}"
  echo ""
  local domain
  # use provided arg or env var if available to avoid re-prompting
  if [[ -n "${1:-}" ]]; then
    domain="$1"
  elif [[ -n "${OSINT_DOMAIN:-}" ]]; then
    domain="$OSINT_DOMAIN"
  else
    domain=$(prompt_domain) || return 1
  fi

  echo -e "${C_YELLOW}${OSINT_AMASS_ACTIVE_WARNING}${C_RESET}"
  echo -ne "${C_ACCENT1}${OSINT_AMASS_ACTIVE_CONFIRM}: ${C_RESET}"
  read -r confirm
  if [[ ! "$confirm" =~ ^[oO]$ ]]; then
    echo "${OSINT_HARVESTER_CANCELLED}"
    return 0
  fi

  local outdir="$BALORSH_DATA_DIR/osint/amass"
  mkdir -p "$outdir"
  local outfile="$outdir/active_${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).txt"

  echo ""
  echo -e "${C_INFO}${OSINT_AMASS_ACTIVE_ENUM} $domain...${C_RESET}"
  echo -e "${C_INFO}Veuillez patienter...${C_RESET}"

  local amass_log="$outdir/active_${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).log"
  # Detect supported flags to maintain compatibility across amass versions
  local src_flag="" ip_flag=""
  if amass enum -h 2>&1 | grep -q -- '-src'; then src_flag='-src'; fi
  if amass enum -h 2>&1 | grep -q -- '-ip'; then ip_flag='-ip'; fi
  local cmd=(amass enum -active -v)
  [[ -n "$src_flag" ]] && cmd+=("$src_flag")
  [[ -n "$ip_flag" ]] && cmd+=("$ip_flag")
  cmd+=(-d "$domain" -o "$outfile")
  run_direct "$amass_log" "${cmd[@]}"
  local rc=$?
  if [[ $rc -ne 0 ]]; then
    if [[ $rc -eq 130 ]]; then
      echo -e "\n${C_YELLOW}${OSINT_AMASS_INTERRUPTED} (SIGINT). ${OSINT_AMASS_CODE}: $rc${C_RESET}"
    else
      echo -e "\n${C_RED}${OSINT_AMASS_FAILED} $rc${C_RESET}"
    fi
    return $rc
  fi

  echo ""
  if [[ -f "$outfile" ]]; then
    local count
    count=$(wc -l <"$outfile")
    echo -e "${C_GOOD}$count ${OSINT_AMASS_SUBDOMAINS_FOUND}${C_RESET}"
    echo -e "${C_GOOD}${OSINT_AMASS_RESULTS}: $outfile${C_RESET}"
  fi
}

osint_shodan_search() {
  echo -e "${C_HIGHLIGHT}${OSINT_SHODAN_TITLE}${C_RESET}"
  echo ""

  echo "${OSINT_SHODAN_SEARCH_TYPE}"
  echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${OSINT_SHODAN_BY_IP}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${OSINT_SHODAN_BY_DOMAIN}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${OSINT_SHODAN_CUSTOM_SEARCH}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${OSINT_SHODAN_BACK}${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${OSINT_HARVESTER_CHOICE_PROMPT} [1]: ${C_RESET}"
  read -r choice
  choice="${choice:-1}"

  if [[ "$choice" == "0" ]]; then
    return 0
  fi

  local query=""
  local target=""
  case "$choice" in
    1)
      target=$(prompt_host)
      query="$target"
      ;;
    2)
      target=$(prompt_domain)
      query="hostname:$target"
      ;;
    3)
      echo -ne "${C_ACCENT1}${OSINT_SHODAN_QUERY}${C_RESET}"
      read -r query
      target="custom"
      ;;
    *)
      echo -e "${C_RED}${OSINT_HARVESTER_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac

  local outdir="$BALORSH_DATA_DIR/osint/shodan"
  mkdir -p "$outdir"
  local outfile="$outdir/search_${target//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).txt"

  echo ""
  echo -e "${C_INFO}${OSINT_SHODAN_SEARCHING}...${C_RESET}"

  if command -v shodan &>/dev/null; then
    local shodan_log="$outfile.log"
    run_direct "$shodan_log" shodan search --fields ip_str,port,org,hostnames "$query"
    echo ""
    echo -e "${C_GOOD}${OSINT_SHODAN_RESULTS_LOG}: $shodan_log${C_RESET}"
  else
    echo -e "${C_RED}${OSINT_SHODAN_CLI_NOT_INSTALLED}${C_RESET}"
    echo -e "${C_INFO}${OSINT_SHODAN_INSTALL_INSTRUCTIONS}${C_RESET}"
  fi
}

osint_shodan_ports() {
  echo -e "${C_HIGHLIGHT}${OSINT_SHODAN_PORTS_TITLE}${C_RESET}"
  echo ""

  # Prompt inline (use echo -ne for consistent color handling)
  local host=""
  while true; do
    echo -ne "${C_ACCENT1}${OSINT_SHODAN_HOST_PROMPT}: ${C_RESET}"
    read -r host
    if [[ -z "$host" ]]; then
      echo -e "${C_RED}${OSINT_SHODAN_NO_HOST}${C_RESET}";
      continue
    fi
    if validate_ip "$host" || validate_domain "$host"; then
      break
    else
      echo -e "${C_RED}${OSINT_SHODAN_INVALID_HOST}${C_RESET}"
    fi
  done

  local outdir="$BALORSH_DATA_DIR/osint/shodan"
  mkdir -p "$outdir"
  local outfile="$outdir/ports_${host//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).txt"

  echo ""
  echo -e "${C_INFO}${OSINT_SHODAN_FETCHING_INFO} $host...${C_RESET}"

  if command -v shodan &>/dev/null; then
    local shodan_log="$outfile.log"
    echo "=== ${OSINT_SHODAN_INFO_FOR} $host ===" >"$shodan_log"
    echo "${OSINT_SHODAN_DATE}: $(date)" >>"$shodan_log"
    echo "" >>"$shodan_log"
    echo -e "${C_INFO}${OSINT_SHODAN_EXECUTING}: shodan host $host${C_RESET}"
    run_direct "$shodan_log" shodan host "$host"
    echo ""
    echo -e "${C_GOOD}${OSINT_SHODAN_RESULTS_LOG}: $shodan_log${C_RESET}"
  else
    echo -e "${C_RED}${OSINT_SHODAN_CLI_NOT_INSTALLED}${C_RESET}"
  fi
}

osint_massdns() {
  echo -e "${C_HIGHLIGHT}${OSINT_MASSDNS_TITLE}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${OSINT_MASSDNS_FILE_PROMPT}: ${C_RESET}"
  read -r domains_file

  if [[ ! -f "$domains_file" ]]; then
    echo -e "${C_RED}${OSINT_MASSDNS_FILE_NOT_FOUND}: $domains_file${C_RESET}"
    return 1
  fi

  local outdir="$BALORSH_DATA_DIR/osint/massdns"
  mkdir -p "$outdir"
  local outfile="$outdir/resolved_$(date +%Y%m%d_%H%M%S).txt"

  echo ""
  echo -e "${C_INFO}${OSINT_MASSDNS_RESOLVING}...${C_RESET}"

  # Prefer the project's resolver list; clean it before use because
  # the bundled file may contain comments or markdown fences.
  local bundled_resolvers="$SCRIPT_DIR/ressources/resolver.txt"
  local resolvers
  if [[ -f "$bundled_resolvers" ]]; then
    resolvers=$(mktemp)
    # keep only IP addresses, drop comments/blank lines/markdown fences
    sed -n 's/\r$//; /^\s*$/d; /^\s*#/d; /```/d; p' "$bundled_resolvers" \
      | grep -Eo '[0-9]+(\.[0-9]+){3}' >"$resolvers" || true
    # If cleaning produced no valid entries, fall back to system resolvers
    if [[ ! -s "$resolvers" ]]; then
      rm -f "$resolvers" 2>/dev/null || true
      resolvers="/etc/resolv.conf"
    fi
  else
    resolvers="/etc/resolv.conf"
  fi

  run_direct "$outfile.log" massdns -r "$resolvers" -t A -o S -w "$outfile" "$domains_file"

  # remove temporary resolvers file if we created one
  if [[ -n "${resolvers-}" && "$resolvers" = /tmp/* && -f "$resolvers" ]]; then
    rm -f "$resolvers" 2>/dev/null || true
  fi

  echo ""
  if [[ -f "$outfile" ]]; then
    local count
    count=$(wc -l <"$outfile")
    echo -e "${C_GOOD}$count ${OSINT_MASSDNS_RESOLUTIONS_DONE}${C_RESET}"
    echo -e "${C_GOOD}${OSINT_AMASS_RESULTS}: $outfile${C_RESET}"
  fi
}

osint_gittools() {
  echo -e "${C_HIGHLIGHT}${OSINT_GITTOOLS_TITLE}${C_RESET}"
  echo ""
  echo "${OSINT_GITTOOLS_OPTIONS}"
  echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${OSINT_GITTOOLS_OPTION_LOCAL}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${OSINT_GITTOOLS_OPTION_REMOTE}${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${OSINT_GITTOOLS_CHOICE_PROMPT}: ${C_RESET}"
  read -r choice
  choice="${choice:-1}"

  local repo_path=""

  case "$choice" in
    1)
      echo -ne "${C_ACCENT1}${OSINT_GITTOOLS_LOCAL_PATH}: ${C_RESET}"
      read -r repo_path
      if [[ ! -d "$repo_path/.git" ]]; then
        echo -e "${C_RED}${OSINT_GITTOOLS_INVALID_REPO}$repo_path${C_RESET}"
        return 1
      fi
      ;;
    2)
      echo -ne "${C_ACCENT1}${OSINT_GITTOOLS_REMOTE_URL}: ${C_RESET}"
      read -r repo_url

      local outdir="$BALORSH_DATA_DIR/osint/gittools"
      mkdir -p "$outdir"
      repo_path="$outdir/repo_$(date +%Y%m%d_%H%M%S)"

      echo ""
      echo -e "${C_INFO}${OSINT_GITTOOLS_CLONING}${C_RESET}"
      git clone "$repo_url" "$repo_path"
      ;;
    *)
      echo -e "${C_RED}${OSINT_GITTOOLS_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac

  local outdir="$BALORSH_DATA_DIR/osint/gittools"
  mkdir -p "$outdir"
  local outfile="$outdir/secrets_$(date +%Y%m%d_%H%M%S).txt"

  echo ""
  echo -e "${C_INFO}${OSINT_GITTOOLS_SCANNING}$repo_path...${C_RESET}"

    if command -v trufflehog &>/dev/null; then
      run_direct "$outfile.log" trufflehog filesystem "$repo_path"
      echo -e "${C_GOOD}${OSINT_GITTOOLS_RESULTS_LOG}$outfile.log${C_RESET}"
    elif command -v gitleaks &>/dev/null; then
      local gitleaks_log="$outdir/gitleaks_$(date +%Y%m%d_%H%M%S).log"
      run_direct "$gitleaks_log" gitleaks detect --source "$repo_path" --report-path "$outfile"
      echo -e "${C_GOOD}${OSINT_GITTOOLS_RESULTS}$outfile (${OSINT_GITTOOLS_RESULTS_LOG}$gitleaks_log)${C_RESET}"
  else
    echo -e "${C_YELLOW}${OSINT_GITTOOLS_NO_SCANNER}${C_RESET}"
    echo -e "${C_INFO}${OSINT_GITTOOLS_BASIC_SEARCH}${C_RESET}"
    {
      echo "=== ${OSINT_GITTOOLS_SUSPECT_FILES} $repo_path ==="
      echo "Date: $(date)"
      echo ""
      echo "=== ${OSINT_GITTOOLS_SUSPECT_FILES} ==="
      find "$repo_path" -type f \( -name "*.key" -o -name "*.pem" -o -iname "*secret*" -o -iname "*password*" \) 2>/dev/null
      echo ""
      echo "=== ${OSINT_GITTOOLS_SUSPECT_PATTERNS} ==="
      grep -r -i -E "(password|passwd|pwd|secret|token|api[_-]?key)" "$repo_path" 2>/dev/null | head -50
    } | tee "$outfile"
    echo ""
    echo -e "${C_GOOD}${OSINT_GITTOOLS_RESULTS_SAVED}$outfile${C_RESET}"
  fi
}

osint_jq_filter() {
  echo -e "${C_HIGHLIGHT}${OSINT_JQ_TITLE}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${OSINT_JQ_FILE_PROMPT}: ${C_RESET}"
  read -r json_file

  if [[ ! -f "$json_file" ]]; then
    echo -e "${C_RED}${OSINT_JQ_FILE_NOT_FOUND}$json_file${C_RESET}"
    return 1
  fi

  echo ""
  echo "${OSINT_JQ_FILTERS}"
  echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${OSINT_JQ_FILTER_PRETTY}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${OSINT_JQ_FILTER_FIELD}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${OSINT_JQ_FILTER_CUSTOM}${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${OSINT_JQ_CHOICE_PROMPT}: ${C_RESET}"
  read -r choice
  choice="${choice:-1}"

  local filter="."
  case "$choice" in
    1) filter="." ;;
    2)
      echo -ne "${C_ACCENT1}${OSINT_JQ_FIELD_PATH}: ${C_RESET}"
      read -r path_raw
      # Normalize user input into a jq filter.
      # If user already provided a filter starting with '.' or containing '[' or '|' assume it's valid.
      if [[ "$path_raw" == .* || "$path_raw" == *"["* || "$path_raw" == *"|"* ]]; then
        filter="$path_raw"
      else
        # Build filter from slash-separated path, converting numeric segments to array indices
        IFS='/' read -ra _parts <<< "$path_raw"
        filter=""
        for _p in "${_parts[@]}"; do
          if [[ "$_p" =~ ^[0-9]+$ ]]; then
            filter+="[$_p]"
          else
            if [[ "$_p" =~ [^a-zA-Z0-9_] ]]; then
              # quote keys with special chars
              filter+=".\"${_p//\"/\\\"}\""
            else
              filter+=".$_p"
            fi
          fi
        done
        filter="${filter:-.}"
      fi
      ;;
    3)
      echo -ne "${C_ACCENT1}${OSINT_JQ_CUSTOM_FILTER}: ${C_RESET}"
      read -r filter
      ;;
  esac

  echo ""
  echo -e "${C_INFO}${OSINT_JQ_RESULT}${C_RESET}"
  jq "$filter" "$json_file"

  echo ""
  echo -ne "${C_ACCENT1}${OSINT_JQ_SAVE_PROMPT}: ${C_RESET}"
  read -r save

  if [[ "$save" =~ ^[oO]$ ]]; then
    local outdir="$BALORSH_DATA_DIR/osint/jq"
    mkdir -p "$outdir"
    local outfile="$outdir/filtered_$(date +%Y%m%d_%H%M%S).json"
    jq "$filter" "$json_file" >"$outfile"
    echo -e "${C_GOOD}${OSINT_JQ_SAVED}$outfile${C_RESET}"
  fi
}

osint_gau() {
  echo -e "${C_HIGHLIGHT}${OSINT_GAU_TITLE}${C_RESET}"
  echo ""

  local gau_config="$HOME/.gau.toml"
  # Ensure gau config exists and is in the expected format (providers = [..])
  if [[ -f "$gau_config" ]]; then
    # Detect legacy/table format (TOML table: [providers]) and convert if present
    if grep -qE '^\s*\[providers\]' "$gau_config" 2>/dev/null; then
      echo -e "${C_YELLOW}${OSINT_GAU_CONFIG_DEPRECATED}$gau_config${OSINT_GAU_CONFIG_CONVERTING}${C_RESET}"
      mkdir -p "$(dirname "$gau_config")"
      local bak="${gau_config}.bak.$(date +%Y%m%d_%H%M%S)"
      cp -v "$gau_config" "$bak" 2>/dev/null || true
      # Extract keys set to true under [providers]
      local provs
      provs=$(awk '
        BEGIN{in=0}
        /^\s*\[providers\]/{in=1; next}
        in && /^\s*\[/{exit}
        in && /^[[:space:]]*[a-zA-Z0-9_-]+[[:space:]]*=[[:space:]]*true/ {
          gsub(/=.*/,"",$0); gsub(/^[ \t]+|[ \t]+$/,"",$0); print $0
        }
      ' "$gau_config" | tr '\n' ' ' | awk '{for(i=1;i<=NF;i++) printf "%s%s", (i==1?"":"\", \""), $i; if(NF>0) printf "\""}' )
      if [[ -n "$provs" ]]; then
        # provs now contains something like wayback","commoncrawl
        printf 'providers = ["%s"]\n' "$provs" >"$gau_config"
      else
        # fallback default
        printf '%s\n' 'providers = ["wayback","commoncrawl","otx","urlscan"]' >"$gau_config"
      fi
      echo -e "${C_INFO}${OSINT_GAU_CONFIG_CONVERTED}$gau_config${OSINT_GAU_CONFIG_BACKUP}$bak)${C_RESET}"
    fi
  else
    mkdir -p "$(dirname "$gau_config")"
    printf '%s\n' 'providers = ["wayback","commoncrawl","otx","urlscan"]' >"$gau_config"
    echo -e "${C_INFO}${OSINT_GAU_CONFIG_CREATED}$gau_config${C_RESET}"
  fi

  local domain
  domain=$(prompt_domain)

  local outdir="$BALORSH_DATA_DIR/osint/gau"
  mkdir -p "$outdir"
  local outfile="$outdir/urls_${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).txt"

  echo ""
  echo -e "${C_INFO}${OSINT_GAU_FETCHING} ${domain} ${OSINT_GAU_VIA_GAU}${C_RESET}"

  run_direct "$outfile.log" gau "$domain"


  echo ""
  if [[ -f "$outfile" ]]; then
    local count
    count=$(wc -l <"$outfile")
    echo -e "${C_GOOD}$count ${OSINT_GAU_URLS_FOUND}${C_RESET}"
    echo -e "${C_GOOD}${OSINT_GAU_RESULTS} $outfile${C_RESET}"
  fi
}

osint_waybackurls() {
  echo -e "${C_HIGHLIGHT}${OSINT_WAYBACKURLS_TITLE}${C_RESET}"
  echo ""

  local domain
  domain=$(prompt_domain)

  local outdir="$BALORSH_DATA_DIR/osint/waybackurls"
  mkdir -p "$outdir"
  local outfile="$outdir/urls_${domain//[^a-zA-Z0-9]/_}_$(date +%Y%m%d_%H%M%S).txt"

  echo ""
  echo -e "${C_INFO}${OSINT_WAYBACKURLS_FETCHING} ${domain} ${OSINT_WAYBACKURLS_VIA_WAYBACKURLS}${C_RESET}"

  run_direct "$outfile.log" bash -c "echo '$domain' | waybackurls"

  echo ""
  if [[ -f "$outfile" ]]; then
    local count
    count=$(wc -l <"$outfile")
    echo -e "${C_GOOD}$count ${OSINT_GAU_URLS_FOUND}${C_RESET}"
    echo -e "${C_GOOD}${OSINT_GAU_RESULTS} $outfile${C_RESET}"
  fi
}

osint_httprobe() {
  echo -e "${C_HIGHLIGHT}${OSINT_HTTPROBE_TITLE}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${OSINT_HTTPROBE_FILE_PROMPT}: ${C_RESET}"
  read -r urls_file

  if [[ ! -f "$urls_file" ]]; then
    echo -e "${C_RED}${OSINT_HTTPROBE_FILE_NOT_FOUND}$urls_file${C_RESET}"
    return 1
  fi

  local outdir="$BALORSH_DATA_DIR/osint/httprobe"
  mkdir -p "$outdir"
  local outfile="$outdir/alive_$(date +%Y%m%d_%H%M%S).txt"

  echo ""
  echo -e "${C_INFO}${OSINT_HTTPROBE_CHECKING}${C_RESET}"

  run_direct "$outfile.log" bash -c "cat '$urls_file' | httprobe"

  echo ""
  if [[ -f "$outfile" ]]; then
    local count
    count=$(wc -l <"$outfile")
    echo -e "${C_GOOD}$count${OSINT_HTTPROBE_HOSTS_FOUND}${C_RESET}"
    echo -e "${C_GOOD}${OSINT_GAU_RESULTS}$outfile${C_RESET}"
  fi
}

osint_help() {
  cat <<EOF
${C_ACCENT1}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}
${C_ACCENT1}║${C_RESET}                   ${C_GOOD}${OSINT_HELP_TITLE}${C_RESET}                          ${C_ACCENT1}║${C_RESET}
${C_ACCENT1}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}

${C_HIGHLIGHT}${OSINT_HELP_MAIN_TOOLS}${C_RESET}
  • ${OSINT_HELP_MALTEGO}
  • ${OSINT_HELP_SPIDERFOOT}
  • ${OSINT_HELP_CENSYS}
  • ${OSINT_HELP_HARVESTER}
  • ${OSINT_HELP_AMASS}
  • ${OSINT_HELP_SHODAN}
  • ${OSINT_HELP_MASSDNS}
  • ${OSINT_HELP_GAU_WAYBACK}
  • ${OSINT_HELP_HTTPROBE}
  • ${OSINT_HELP_GITTOOLS}
  • ${OSINT_HELP_JQ}

${C_HIGHLIGHT}${OSINT_HELP_OUTPUT_DIR}${C_RESET}
  ${BALORSH_DATA_DIR}/osint/

${C_YELLOW}${OSINT_HELP_NOTE}${C_RESET}
  ${OSINT_HELP_API_KEYS}
  ${OSINT_HELP_CONFIGURE}
  ${OSINT_HELP_SPIDERFOOT_LONG}
EOF
  echo ""
  echo -ne "${C_ACCENT1}${OSINT_HELP_PRESS_ENTER}${C_RESET}"
  read -r
}

osint_diag() {
  echo -e "${C_HIGHLIGHT}${OSINT_DIAG_TITLE}${C_RESET}"
  echo ""
  local tools=(maltego spiderfoot-web spiderfoot-cli censys theHarvester amass massdns trufflehog gitleaks jq gau waybackurls httprobe)
  for t in "${tools[@]}"; do
    if command -v "$t" &>/dev/null; then
      local path
      path=$(command -v "$t")
      echo -e "${C_GOOD}✓ $t${C_RESET} ${C_SHADOW}($path)${C_RESET}"
      # try common version flags
      if "$t" --version &>/dev/null; then
        "$t" --version 2>/dev/null | head -1
      elif "$t" -v &>/dev/null; then
        "$t" -v 2>/dev/null | head -1
      elif "$t" -V &>/dev/null; then
        "$t" -V 2>/dev/null | head -1
      fi
    else
      printf "%-15s: ${OSINT_DIAG_NOT_FOUND}\n" "$t"
    fi
    echo ""
  done
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================

stack_menu() {
  while true; do
    clear
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "                  ${C_GOOD}${OSINT_MENU_TITLE}${C_RESET}"
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${OSINT_MENU_CONFIG}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${OSINT_MENU_CONFIG_HARVESTER}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${OSINT_MENU_CONFIG_CENSYS}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${OSINT_MENU_CONFIG_SHODAN}${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${OSINT_MENU_TOOLS}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${OSINT_MENU_MALTEGO}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}5)${C_RESET} ${C_INFO}${OSINT_MENU_SPIDERFOOT}${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${OSINT_MENU_DOMAINS}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}6)${C_RESET} ${C_INFO}${OSINT_MENU_CENSYS_SEARCH}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}7)${C_RESET} ${C_INFO}${OSINT_MENU_CENSYS_CERTS}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}8)${C_RESET} ${C_INFO}${OSINT_MENU_MULTIPLE_SEARCHES}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}9)${C_RESET} ${C_INFO}${OSINT_SUBDOMAIN_ENUM_AMASS}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}11)${C_RESET} ${C_INFO}${OSINT_MENU_SHODAN_SEARCH}${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${OSINT_MENU_OTHER}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}12)${C_RESET} ${C_INFO}${OSINT_MENU_SHODAN_PORTS}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}13)${C_RESET} ${C_INFO}${OSINT_MASSDNS_RESOLUTION}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}14)${C_RESET} ${C_INFO}${OSINT_MENU_GIT_SECRETS}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}15)${C_RESET} ${C_INFO}Manipulation JSON (JQ)${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${OSINT_MENU_URLS}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}16)${C_RESET} ${C_INFO}${OSINT_MENU_MULTIPLE_HISTORIES}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}17)${C_RESET} ${C_INFO}Historique Wayback Machine (WaybackURLs)${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}18)${C_RESET} ${C_INFO}${OSINT_HTTPROBE_CHECK}${C_RESET}"
    echo ""
    echo -e "   ${C_HIGHLIGHT}19)${C_RESET} ${C_INFO}${OSINT_MENU_HELP}${C_RESET}"
    echo ""
    echo -e "   ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}Quitter${C_RESET}"
    echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
    echo -ne "${C_ACCENT1}${OSINT_MENU_CHOICE}: ${C_RESET}"
    read -r choice

    case "$choice" in
      1) osint_config_harvester ;;
      2) osint_config_censys ;;
      3) osint_config_shodan ;;
      4) osint_maltego ;;
      5) osint_spiderfoot_menu ;;
      6) osint_censys_search ;;
      7) osint_censys_certs ;;
      8) osint_harvester ;;
      9) osint_amass_menu ;;
      11) osint_shodan_search ;;
      12) osint_shodan_ports ;;
      13) osint_massdns ;;
      14) osint_gittools ;;
      15) osint_jq_filter ;;
      16) osint_gau ;;
      17) osint_waybackurls ;;
      18) osint_httprobe ;;
      19) osint_diag ;;
      20) osint_help ;;
      21) osint_jobs ;;
      22) osint_spiderfoot_index ;;
      0)
        echo -e "${C_GOOD}Quitter${C_RESET}"
        break
        ;;
      *)
        echo -e "${C_RED}${OSINT_MENU_INVALID_CHOICE}${C_RESET}"
        ;;
    esac

    if [[ "$choice" != "0" ]]; then
      echo ""
      echo -ne "${C_INFO}${REMOTEACCESS_PRESS_ENTER}${C_RESET}"
      read -r
    fi
  done
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  stack_menu
fi