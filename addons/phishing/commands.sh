#!/usr/bin/env bash
set -Eeuo pipefail

if [ -z "${BASH_VERSION-}" ]; then
  return 1 2>/dev/null || exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

: "${BALORSH_DATA_DIR:=/opt/balorsh/data}"

PHISHING_DATA_DIR="$BALORSH_DATA_DIR/phishing"

phishing_gophish() {
  local balor_root_opt="${BALOR_OPT_ROOT:-/opt/balorsh}"
  local app_dir="$balor_root_opt/addons/apps/gophish"
  local bin="$app_dir/gophish"
  if [[ ! -x "$bin" ]]; then
    echo "[!] gophish non installé (attendu: $bin)"
    return 1
  fi

  local outdir="$PHISHING_DATA_DIR/gophish"
  mkdir -p "$outdir"
  local pw_file="$outdir/password.txt"
  local log_file="$outdir/gophish.log"
  local pid_file="$outdir/gophish.pid"

  : >"$log_file"

  echo ""
  echo "Accès (par défaut) : http://127.0.0.1:3333"
  echo "Le mot de passe initial (temporaire) sera enregistré dans : $pw_file"
  echo ""

  (
    tail -n +1 -F "$log_file" 2>/dev/null | grep -m1 -E 'Please login with the username[[:space:]]+admin[[:space:]]+and the password' | \
      sed -E 's/.*password[[:space:]]+([^"[:space:]]+).*/\1/' | \
      while IFS= read -r pw; do
        [[ -n "$pw" ]] || exit 0
        printf "%s\n" "$pw" >"$pw_file"
        chmod 600 "$pw_file" 2>/dev/null || true
        echo ""
        echo "[Balor] Mot de passe initial détecté et sauvegardé dans $pw_file"
      done
  ) &
  local watcher_pid=$!
  disown "$watcher_pid" 2>/dev/null || true

  if [[ -f "$pid_file" ]]; then
    local existing_pid
    existing_pid=$(cat "$pid_file" 2>/dev/null || true)
    if [[ -n "$existing_pid" ]] && kill -0 "$existing_pid" 2>/dev/null; then
      echo ""
      echo "[Balor] gophish semble déjà démarré (PID: $existing_pid)"
      return 0
    fi
  fi

  # Start gophish in background so the user can return to the menu.
  # Note: we keep the watcher running in background to capture the initial password.
  local pid
  pid=$(sudo sh -c "cd '$app_dir' && nohup '$bin' >>'$log_file' 2>&1 & echo \$!" 2>/dev/null | tr -d '\r' || true)
  if [[ -n "$pid" ]]; then
    printf "%s\n" "$pid" >"$pid_file" 2>/dev/null || true
  fi
}

phishing_zphisher() {
  local balor_root_opt="${BALOR_OPT_ROOT:-/opt/balorsh}"
  local app_dir="$balor_root_opt/addons/apps/phishing/zphisher"
  local script="$app_dir/zphisher.sh"
  if [[ ! -f "$script" ]]; then
    echo "[!] zphisher non installé (attendu: $script)"
    return 1
  fi
  ( cd "$app_dir" && bash "$script" )
}

phishing_wifipumpkin3() {
  if command -v wifipumpkin3 >/dev/null 2>&1; then
    sudo wifipumpkin3
    return 0
  fi
  if command -v wifipumpkin3-cli >/dev/null 2>&1; then
    sudowifipumpkin3-cli
    return 0
  fi
  echo "[!] wifipumpkin3 non installé"
  return 1
}

stack_menu() {
  while true; do
    clear
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "                  ${C_GOOD}Phishing${C_RESET}"
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}Campagne de phishing (gophish)${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}Page de phishing (zphisher)${C_RESET}"
    echo -e "  ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}Wifi Phishing (wifi-pumpking 3 CLI)${C_RESET}"
    echo ""
    echo -e "  ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}Quitter${C_RESET}"
    echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
    echo -ne "${C_ACCENT1}${INSTALL_YOUR_CHOICE:-Votre choix:}${C_RESET} "
    read -r choice
    case "$choice" in
      01|1) phishing_gophish ;;
      02|2) phishing_zphisher ;;
      03|3) phishing_wifipumpkin3 ;;
      0) return 0 ;;
      *) echo "Choix invalide"; sleep 1 ;;
    esac

    if [[ "$choice" != "0" ]]; then
      echo ""
      echo -ne "${C_INFO}${REMOTEACCESS_PRESS_ENTER:-Appuyez sur [Entrée] pour continuer...}${C_RESET}"
      read -r
    fi
  done
}
