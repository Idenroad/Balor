#!/usr/bin/env bash
set -e

BALOR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Version de l'installateur (lit la première ligne non-commentaire de VERSION)
VERSION="${VERSION:-$(grep -v '^#' "$BALOR_ROOT/VERSION" 2>/dev/null | grep -v '^$' | head -n1 | tr -d ' \n\r\t' || echo 'unknown')}"

# shellcheck source=lib/common.sh
source "$BALOR_ROOT/lib/common.sh"

# Vérifier les packages essentiels au lancement
check_essential_packages
# Ensure AUR helper (paru) is present or offer to install it
ensure_aur_helper

# Codes couleur
C_RESET="\e[0m"
C_BOLD="\e[1m"
C_ACCENT1="\e[38;2;117;30;233m"
C_ACCENT2="\e[38;2;144;117;226m"
C_GOOD="\e[38;2;6;251;6m"
C_HIGHLIGHT="\e[38;2;37;253;157m"
C_RED="\e[31m"
C_YELLOW="\e[33m"
C_INFO="\e[36m"
C_SHADOW="\e[90m"

STACKS_DIR="$BALOR_ROOT/stacks"
BANNER_FILE="$BALOR_ROOT/banner.txt"
BALOR_OPT_ROOT="${BALOR_OPT_ROOT:-/opt/balorsh}"
BALOR_BIN_PATH="${BALOR_BIN_PATH:-/usr/local/bin/balorsh}"
BALOR_WRAPPER_SRC="$BALOR_ROOT/balorsh"

# Lire la version d'une stack depuis le fichier VERSION centralisé
get_stack_version() {
  local stack="$1"
  local version_file="$BALOR_ROOT/VERSION"
  
  if [[ -f "$version_file" ]]; then
    # Chercher la ligne "stack:version" dans VERSION
    local version=$(grep -E "^${stack}:" "$version_file" | cut -d':' -f2)
    
    if [[ -n "$version" ]]; then
      echo "$version"
      return
    fi
  fi
  
  # Fallback: lire depuis packages.txt (rétrocompatibilité)
  local packages_file="$STACKS_DIR/$stack/packages.txt"
  if [[ -f "$packages_file" ]]; then
    local version=$(grep -E '^#stack[[:space:]]+' "$packages_file" | head -n1 | sed -E 's/^#stack[[:space:]]+//')
    if [[ -n "$version" ]]; then
      echo "$version"
      return
    fi
  fi
  
  echo "${INSTALL_UNKNOWN}"
}

# Lire la version installée d'une stack depuis le JSON
get_installed_stack_version() {
  local stack="$1"
  local json_file="$BALOR_OPT_ROOT/json/stacks_status.json"
  
  if [[ ! -f "$json_file" ]]; then
    echo "${INSTALL_UNKNOWN}"
    return
  fi
  
  # Extraire la version depuis le JSON - chercher la ligne exacte avec le nom de la stack
  local json_line
  json_line=$(grep "\"$stack\":" "$json_file" || true)
  if [[ -z "$json_line" ]]; then
    echo "${INSTALL_UNKNOWN}"
    return
  fi

  # Extract installed flag (true/false) and version
  local installed_flag
  installed_flag=$(sed -E 's/.*"installed":[[:space:]]*(true|false).*/\1/' <<<"$json_line" 2>/dev/null || true)
  local version
  version=$(sed -E 's/.*"version":[[:space:]]*"([^"]+)".*/\1/' <<<"$json_line" 2>/dev/null || true)

  # If the JSON says not installed, treat as unknown
  if [[ "$installed_flag" == "false" || -z "$installed_flag" ]]; then
    echo "${INSTALL_UNKNOWN}"
    return
  fi

  if [[ -n "$version" ]]; then
    echo "$version"
  else
    echo "${INSTALL_UNKNOWN}"
  fi
}

# Mettre à jour le JSON des stacks installées avec leur version
update_stacks_json() {
  local json_dir="$BALOR_OPT_ROOT/json"
  local json_file="$json_dir/stacks_status.json"
  
  # Créer le dossier si nécessaire
  if [[ ! -d "$json_dir" ]]; then
    if ! mkdir -p "$json_dir" 2>/dev/null; then
      sudo mkdir -p "$json_dir" || true
    fi
  fi
  
  # Permissions et ownership du dossier
  if ! chmod 775 "$json_dir" 2>/dev/null; then
    sudo chmod 775 "$json_dir" || true
  fi
  owner="${SUDO_USER:-$USER}"
  if ! chown "$owner:$owner" "$json_dir" 2>/dev/null; then
    sudo chown "$owner:$owner" "$json_dir" || true
  fi
  
  # Construire le JSON
  local tmpf=$(mktemp)
  trap 'rm -f "$tmpf"' RETURN
  
  printf '{\n' > "$tmpf"
  printf '  "last_update": "%s",\n' "$(date -Iseconds)" >> "$tmpf"
  printf '  "stacks": {\n' >> "$tmpf"
  
  local first=1
  while IFS= read -r stack; do
    local version=$(get_stack_version "$stack")
    local installed="false"
    if is_stack_installed "$stack"; then
      installed="true"
    fi
    
    if [[ $first -eq 0 ]]; then
      printf ',\n' >> "$tmpf"
    fi
    printf '    "%s": {"version": "%s", "installed": %s}' "$stack" "$version" "$installed" >> "$tmpf"
    first=0
  done < <(list_stacks)
  
  printf '\n  }\n}\n' >> "$tmpf"
  
  # Écrire le fichier JSON
  if ! cp "$tmpf" "$json_file" 2>/dev/null; then
    sudo tee "$json_file" >/dev/null <"$tmpf" || true
  fi
  
  # Ownership du fichier
  if ! chown "$owner:$owner" "$json_file" 2>/dev/null; then
    sudo chown "$owner:$owner" "$json_file" 2>/dev/null || true
  fi
  
  return 0
}

list_stacks() {
  find "$STACKS_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort
}

install_stack() {
  local stack="$1"
  local script="$STACKS_DIR/$stack/install.sh"
  if [[ -x "$script" ]]; then
    # Run the script and capture exit code, ignoring set -e
    local exit_code=0
    bash "$script" </dev/tty || exit_code=$?
    return $exit_code
  else
    printf "$INSTALL_SCRIPT_NOT_FOUND\n" "$stack"
    return 1
  fi
}

uninstall_stack() {
  local stack="$1"
  local script="$STACKS_DIR/$stack/uninstall.sh"
  if [[ -x "$script" ]]; then
    printf "${C_SHADOW}${UNINSTALL_STACK_START}${C_RESET}\n" "$stack"
    # Exécuter le script en direct pour que l'utilisateur voie la sortie en temps réel
    set +e
    bash "$script" </dev/tty 2>&1
    local exit_code=$?
    set -e
    if [[ $exit_code -eq 0 ]]; then
      printf "${C_GOOD}${UNINSTALL_STACK_COMPLETE}${C_RESET}\n" "$stack"
    else
      printf "${C_RED}${UNINSTALL_STACK_ERROR}${C_RESET}\n" "$stack"
    fi
    # Supprimer les données de la stack si demandé
    remove_stack_data_dir "$stack"
    update_stacks_json
  else
    printf "$UNINSTALL_SCRIPT_NOT_FOUND\n" "$stack"
  fi
}

menu_install_specific() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "              ${C_GOOD}${INSTALL_MENU_SPECIFIC_TITLE}${C_RESET}                       "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  echo -e "${C_SHADOW}${INSTALL_STACKS_AVAILABLE}${C_RESET}"
  local i=1
  local stacks=()
  while IFS= read -r s; do
    stacks+=("$s")
    echo -e "  $i) ${C_HIGHLIGHT}$s${C_RESET}"
    ((i++))
  done < <(list_stacks)

  echo -e "  0) ${C_RED}${INSTALL_RETURN}${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${INSTALL_YOUR_CHOICE}${C_RESET} "
  read -r choice

  if [[ "$choice" == "0" ]]; then
    return
  fi

  local idx=$((choice-1))
  local sel="${stacks[$idx]}"

  if [[ -n "$sel" ]]; then
    ask_force_install "Forcer l'installation de $sel ? [y/N]: " || true
    if [[ "$FORCE_INSTALL" -eq 1 ]]; then
      printf "${C_YELLOW}${INSTALL_FORCE_INSTALL}${C_RESET}\n" "$sel"
      install_stack "$sel" || echo -e "${C_RED}${INSTALL_FORCE_FAILED}${C_RESET}"
    else
      if install_stack "$sel"; then
        :
      else
        printf "${C_RED}${INSTALL_FAILED}${C_RESET}\n" "$sel"
      fi
    fi
    update_stacks_json || true
    press_enter_if_enabled
  else
    echo "${INSTALL_INVALID_CHOICE}"
  fi
}

menu_uninstall() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "                  ${C_RED}${INSTALL_MENU_8}${C_RESET}                          "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  echo -e "${C_SHADOW}${INSTALL_STACKS_AVAILABLE}${C_RESET}"
  local i=1
  local stacks=()
  while IFS= read -r s; do
    stacks+=("$s")
    echo -e "  $i) ${C_HIGHLIGHT}$s${C_RESET}"
    ((i++))
  done < <(list_stacks)

  echo -e "  0) ${C_GOOD}${INSTALL_RETURN}${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${INSTALL_YOUR_CHOICE}${C_RESET} "
  read -r choice

  if [[ "$choice" == "0" ]]; then
    return
  fi

  local idx=$((choice-1))
  local sel="${stacks[$idx]}"

  if [[ -n "$sel" ]]; then
    uninstall_stack "$sel"
    # Attendre que l'utilisateur lise la sortie puis appuyer sur Entrée
    press_enter_if_enabled
  else
    echo "${INSTALL_INVALID_CHOICE}"
  fi
}

uninstall_all() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "          ${C_RED}${INSTALL_UNINSTALL_ALL_TITLE}${C_RESET}                    "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  echo -e "${C_YELLOW}${INSTALL_UNINSTALL_ALL_WARNING}${C_RESET}"
  echo ""
  echo -ne "${C_RED}${INSTALL_UNINSTALL_ALL_CONFIRM} ${C_RESET}"
  if [[ -e /dev/tty ]]; then
    IFS= read -r confirm </dev/tty
  else
    read -r confirm
  fi
  
  if [[ "$confirm" =~ ^[oOyY]$ ]]; then
    # Demander si on supprime les données
    echo ""
    printf "$INSTALL_UNINSTALL_ALL_DATA_PROMPT"
    if [[ -e /dev/tty ]]; then
      IFS= read -r data_choice </dev/tty
    else
      read -r data_choice
    fi
    if [[ "$data_choice" =~ ^[oOyY]$ ]]; then
      export UNINSTALL_ALL_DATA=true
      echo -e "${C_YELLOW}${INSTALL_UNINSTALL_ALL_DATA_REMOVING}${C_RESET}"
    else
      export UNINSTALL_ALL_DATA=false
      echo -e "${C_INFO}${INSTALL_UNINSTALL_ALL_DATA_SKIPPED}${C_RESET}"
    fi
    
    # Pour bien nettoyer les artefacts non-packagés (pip etc.),
    # exécuter d'abord chaque script `uninstall` de stack (best-effort),
    # puis collecter les paquets pour suppression via le gestionnaire de paquets.
    declare -A all_pkgs_to_remove=()
    declare -A all_pipx_pkgs_to_remove=()
    while IFS= read -r s; do
      echo -e "${C_INFO}${INSTALL_UNINSTALL_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET}"
      # Essayer d'exécuter le script de désinstallation de la stack (ne pas stopper en cas d'erreur)
      set +e
      uninstall_stack "$s" || true
      set -e
      # Lire les paquets de la stack
      packages_data=$(read_stack_packages "$STACKS_DIR/$s")
      IFS='|' read -r pacman_list aur_list <<< "$packages_data"
      for pkg in $pacman_list $aur_list; do
        if [[ -n "$pkg" ]]; then
          all_pkgs_to_remove["$pkg"]=1
        fi
      done
      # Collecter les packages pipx de cette stack
      mapfile -t pipx_pkgs < <(collect_pipx_packages_from_stack "$STACKS_DIR/$s")
      for pkg in "${pipx_pkgs[@]}"; do
        if [[ -n "$pkg" ]]; then
          all_pipx_pkgs_to_remove["$pkg"]=1
        fi
      done
      # Supprimer (en complément) les données de la stack
      remove_stack_data_dir "$s"
    done < <(list_stacks)
    
    # Désinstaller tous les paquets collectés (sans vérification de partage puisque tout est supprimé)
    echo -e "${C_YELLOW}${INSTALL_UNINSTALLING_PACKAGES}${C_RESET}"
    for pkg in "${!all_pkgs_to_remove[@]}"; do
      if [[ " ${ESSENTIAL_PACKAGES[*]} " =~ " $pkg " ]]; then
        printf "$MSG_PKG_SKIP_SHARED\n" "$pkg"
      else
        remove_pkg "$pkg"
      fi
    done
    
    # Désinstaller tous les paquets pipx collectés
    if [[ ${#all_pipx_pkgs_to_remove[@]} -gt 0 ]]; then
      echo -e "${C_YELLOW}Désinstallation des paquets pipx...${C_RESET}"
      for pkg in "${!all_pipx_pkgs_to_remove[@]}"; do
        remove_pipx_pkg "$pkg"
      done
    fi
    
    # Supprimer json sous BALOR_OPT_ROOT
    echo -e "${C_YELLOW}Suppression de $BALOR_OPT_ROOT/json...${C_RESET}"
    sudo rm -rf "$BALOR_OPT_ROOT/json"
    
    echo ""
    echo -e "${C_GOOD}${INSTALL_UNINSTALL_ALL_COMPLETE}${C_RESET}"
  else
    echo -e "${C_INFO}${INSTALL_CANCELLED}${C_RESET}"
  fi
  press_enter_if_enabled
}

install_all_except_llm() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "      ${C_GOOD}${INSTALL_INSTALL_EXCEPT_LLM_TITLE}${C_RESET}                  "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  local failures=()
  ask_force_install "${INSTALL_FORCE_PROMPT_ALL_EXCEPT_LLM}" || true

  # Set up error handling to continue on failures
  trap 'true' ERR
  set +e

  if [[ "$FORCE_INSTALL" -eq 1 ]]; then
    echo -e "${C_YELLOW}${INSTALL_FORCE_MODE_ALL_EXCEPT_LLM}${C_RESET}"
    while IFS= read -r s; do
      if [[ "$s" != "llm" ]]; then
        echo -e "${C_INFO}${INSTALL_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET}"
        if install_stack "$s"; then
          :
        else
          failures+=("$s")
        fi
      else
        echo -e "${C_YELLOW}${INSTALL_LLM_IGNORED}${C_RESET}"
      fi
    done < <(list_stacks)
    # Update JSON
    update_stacks_json || true
    echo ""
    echo -e "${C_GOOD}${INSTALL_ALL_EXCEPT_LLM_COMPLETE}${C_RESET}"
    if (( ${#failures[@]} > 0 )); then
      echo -e "${C_RED}Some stacks failed to install:${C_RESET}"
      for f in "${failures[@]}"; do echo "  - $f"; done
    fi
    press_enter_if_enabled
    return
  fi
  while IFS= read -r s; do
    if [[ "$s" != "llm" ]]; then
      echo -e "${C_INFO}${INSTALL_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET}"
      if install_stack "$s"; then
        :
      else
        failures+=("$s")
      fi
    else
      echo -e "${C_YELLOW}${INSTALL_LLM_IGNORED}${C_RESET}"
    fi
  done < <(list_stacks)

  # Restore error handling
  set -e
  trap - ERR

  # Update JSON status
  update_stacks_json || true

  echo ""
  echo -e "${C_GOOD}${INSTALL_ALL_EXCEPT_LLM_COMPLETE}${C_RESET}"
  if (( ${#failures[@]} > 0 )); then
    echo -e "${C_RED}Some stacks failed to install:${C_RESET}"
    for f in "${failures[@]}"; do echo "  - $f"; done
  fi
  press_enter_if_enabled
}

install_all() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "          ${C_GOOD}${INSTALL_INSTALL_ALL_TITLE}${C_RESET}                       "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  local installed_count=0
  local skipped_count=0
  local failures=()
  # Prompt to force install (ignore JSON) or if JSON missing act as forced
  ask_force_install "${INSTALL_FORCE_PROMPT_ALL}" || true

  # Set up error handling to continue on failures
  trap 'true' ERR
  set +e

  if [[ "$FORCE_INSTALL" -eq 1 ]]; then
    echo -e "${C_YELLOW}${INSTALL_FORCE_MODE_ALL}${C_RESET}"
    while IFS= read -r s; do
      echo -e "${C_INFO}${INSTALL_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET}"
      if install_stack "$s"; then
        installed_count=$((installed_count + 1))
      else
        failures+=("$s")
      fi
    done < <(list_stacks)
  else
    while IFS= read -r s; do
      local current_version=$(get_installed_stack_version "$s")
      local available_version=$(get_stack_version "$s")
      
      # Si pas installé ou version différente, installer
      if [[ "$current_version" == "${INSTALL_UNKNOWN}" ]] || [[ "$current_version" != "$available_version" ]]; then
        if [[ "$current_version" == "${INSTALL_UNKNOWN}" ]]; then
          echo -e "${C_INFO}${INSTALL_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET}"
        else
          echo -e "${C_INFO}${INSTALL_UPDATE_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET} ${C_SHADOW}($current_version → $available_version)${C_RESET}"
        fi
        if install_stack "$s"; then
          installed_count=$((installed_count + 1))
        else
          failures+=("$s")
        fi
      else
        printf "${C_SHADOW}${INSTALL_ALREADY_UP_TO_DATE}${C_RESET}\n" "$s" "$current_version"
        skipped_count=$((skipped_count + 1))
      fi
    done < <(list_stacks)
  fi

  # Restore error handling
  set -e
  trap - ERR
  
  echo ""
  # Update JSON status
  update_stacks_json || true

  if [[ $installed_count -gt 0 ]]; then
    printf "${C_GOOD}${INSTALL_UPDATED_COUNT}${C_RESET}\n" "$installed_count"
  fi
  if [[ $skipped_count -gt 0 ]]; then
    printf "${C_INFO}${INSTALL_ALREADY_UP_TO_DATE_COUNT}${C_RESET}\n" "$skipped_count"
  fi
  if [[ $installed_count -eq 0 && $skipped_count -eq 0 ]]; then
    echo -e "${C_YELLOW}${INSTALL_NO_STACKS_TO_UPDATE}${C_RESET}"
  fi
  if (( ${#failures[@]} > 0 )); then
    echo ""
    echo -e "${C_RED}The following stacks failed to install/update:${C_RESET}"
    for f in "${failures[@]}"; do echo "  - $f"; done
  fi
  press_enter_if_enabled
}

# Ask user whether to force installation. If JSON is missing, behave as forced.
ask_force_install() {
  local prompt="$1"
  FORCE_INSTALL=0
  local json_file="$BALOR_OPT_ROOT/json/stacks_status.json"
  if [[ ! -f "$json_file" ]]; then
    printf "${C_YELLOW}${INSTALL_NO_JSON_FILE}${C_RESET}\n" "$json_file"
    FORCE_INSTALL=1
    return 0
  fi

  # Default prompt if not provided
  if [[ -z "$prompt" ]]; then
    prompt="${INSTALL_FORCE_PROMPT_DEFAULT}"
  fi

  printf "${C_ACCENT1}%s${C_RESET}" "$prompt"
  if [[ -e /dev/tty ]]; then
    IFS= read -r ans </dev/tty
  else
    read -r ans
  fi
  case "$ans" in
    y|Y|o|O)
      FORCE_INSTALL=1
      return 0
      ;;
    *)
      FORCE_INSTALL=0
      return 1
      ;;
  esac
}

# Vérifie si une stack semble installée (heuristique basée sur /opt/balorsh/data/)
is_stack_installed() {
  local stack="$1"
  # Vérifier si le dossier de données existe
  if [[ -d "$BALOR_OPT_ROOT/data/$stack" ]]; then
    return 0
  fi
  return 1
}

update_existing_stacks() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "         ${C_INFO}${INSTALL_MENU_3}${C_RESET}                     "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  # Vérifier et mettre à jour les fichiers racine si nécessaire
  if [[ -d "$BALOR_OPT_ROOT" ]]; then
    echo -e "${C_INFO}${INSTALL_CHECKING_ROOT_FILES}${C_RESET}"
    
    # Mettre à jour VERSION si différent
    if [[ -f "$BALOR_ROOT/VERSION" && -f "$BALOR_OPT_ROOT/VERSION" ]]; then
      if ! cmp -s "$BALOR_ROOT/VERSION" "$BALOR_OPT_ROOT/VERSION"; then
        echo -e "${C_HIGHLIGHT}${INSTALL_UPDATING_VERSION_FILE}${C_RESET}"
        sudo cp "$BALOR_ROOT/VERSION" "$BALOR_OPT_ROOT/VERSION"
        echo -e "${C_GOOD}${INSTALL_VERSION_UPDATED}${C_RESET}"
      fi
    elif [[ -f "$BALOR_ROOT/VERSION" && ! -f "$BALOR_OPT_ROOT/VERSION" ]]; then
      echo -e "${C_HIGHLIGHT}${INSTALL_COPYING_MISSING_VERSION}${C_RESET}"
      sudo cp "$BALOR_ROOT/VERSION" "$BALOR_OPT_ROOT/VERSION"
      echo -e "${C_GOOD}${INSTALL_VERSION_COPIED}${C_RESET}"
    fi
    
    # Mettre à jour balorsh si différent
    if [[ -f "$BALOR_ROOT/balorsh" && -f "$BALOR_OPT_ROOT/balorsh" ]]; then
      if ! cmp -s "$BALOR_ROOT/balorsh" "$BALOR_OPT_ROOT/balorsh"; then
        echo -e "${C_HIGHLIGHT}${INSTALL_UPDATING_BALORSH_SCRIPT}${C_RESET}"
        sudo cp "$BALOR_ROOT/balorsh" "$BALOR_OPT_ROOT/balorsh"
        sudo chmod +x "$BALOR_OPT_ROOT/balorsh"
        echo -e "${C_GOOD}${INSTALL_BALORSH_UPDATED}${C_RESET}"
      fi
    fi
    
    # Mettre à jour banner.txt si présent et différent
    if [[ -f "$BALOR_ROOT/banner.txt" && -f "$BALOR_OPT_ROOT/banner.txt" ]]; then
      if ! cmp -s "$BALOR_ROOT/banner.txt" "$BALOR_OPT_ROOT/banner.txt"; then
        echo -e "${C_HIGHLIGHT}${INSTALL_UPDATING_BANNER}${C_RESET}"
        sudo cp "$BALOR_ROOT/banner.txt" "$BALOR_OPT_ROOT/banner.txt"
        echo -e "${C_GOOD}${INSTALL_BANNER_UPDATED}${C_RESET}"
      fi
    elif [[ -f "$BALOR_ROOT/banner.txt" && ! -f "$BALOR_OPT_ROOT/banner.txt" ]]; then
      echo -e "${C_HIGHLIGHT}${INSTALL_COPYING_MISSING_BANNER}${C_RESET}"
      sudo cp "$BALOR_ROOT/banner.txt" "$BALOR_OPT_ROOT/banner.txt"
      echo -e "${C_GOOD}${INSTALL_BANNER_COPIED}${C_RESET}"
    fi
    
    echo ""
  fi
  
  local updated_count=0
  local skipped_count=0
  local failures=()
  ask_force_install "${INSTALL_FORCE_PROMPT_UPDATE_EXISTING}" || true

  # Set up error handling to continue on failures
  trap 'true' ERR
  set +e

  if [[ "$FORCE_INSTALL" -eq 1 ]]; then
    echo -e "${C_YELLOW}${INSTALL_FORCE_MODE_UPDATE}${C_RESET}"
    while IFS= read -r s; do
      echo -e "${C_INFO}Reinstalling ${C_HIGHLIGHT}$s${C_RESET}"
      if install_stack "$s"; then
        updated_count=$((updated_count + 1))
      else
        failures+=("$s")
      fi
    done < <(list_stacks)
    # update json
    update_stacks_json || true
    echo ""
    if (( ${#failures[@]} > 0 )); then
      echo -e "${C_RED}The following stacks failed to reinstall:${C_RESET}"
      for f in "${failures[@]}"; do echo "  - $f"; done
    fi
    press_enter_if_enabled
    return
  fi
  while IFS= read -r s; do
    if is_stack_installed "$s"; then
      local current_version=$(get_installed_stack_version "$s")
      local available_version=$(get_stack_version "$s")
      
      if [[ "$current_version" != "$available_version" ]]; then
        echo -e "${C_INFO}${INSTALL_UPDATE_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET} ${C_SHADOW}($current_version → $available_version)${C_RESET}"
        if install_stack "$s"; then
          updated_count=$((updated_count + 1))
        else
          failures+=("$s")
        fi
      else
        printf "${C_SHADOW}${INSTALL_ALREADY_UP_TO_DATE}${C_RESET}\n" "$s" "$current_version"
        skipped_count=$((skipped_count + 1))
      fi
    else
      printf "${C_SHADOW}${INSTALL_NOT_INSTALLED_IGNORED}${C_RESET}\n" "$s"
    fi
  done < <(list_stacks)

  # Restore error handling
  set -e
  trap - ERR
  
  echo ""
  if [[ $updated_count -gt 0 ]]; then
    printf "${C_GOOD}${INSTALL_UPDATED_COUNT}${C_RESET}\n" "$updated_count"
  fi
  if [[ $skipped_count -gt 0 ]]; then
    printf "${C_INFO}${INSTALL_ALREADY_UP_TO_DATE_COUNT}${C_RESET}\n" "$skipped_count"
  fi
  if [[ $updated_count -eq 0 && $skipped_count -eq 0 ]]; then
    echo -e "${C_YELLOW}${INSTALL_NO_STACKS_TO_UPDATE}${C_RESET}"
  fi
  if (( ${#failures[@]} > 0 )); then
    echo ""
    echo -e "${C_RED}The following stacks failed to update:${C_RESET}"
    for f in "${failures[@]}"; do echo "  - $f"; done
  fi
  # Mettre à jour le JSON des stacks après l'opération (chemin normal)
  update_stacks_json || true
  press_enter_if_enabled
}

install_missing_stacks() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "          ${C_GOOD}${INSTALL_MENU_4}${C_RESET}                        "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  local installed_count=0
  local failures=()
  ask_force_install "Forcer l'installation des stacks manquantes ? [y/N]: " || true

  # Set up error handling to continue on failures
  trap 'true' ERR
  set +e

  if [[ "$FORCE_INSTALL" -eq 1 ]]; then
    echo -e "${C_YELLOW}${INSTALL_FORCE_MODE_MISSING}${C_RESET}"
    while IFS= read -r s; do
      echo -e "${C_INFO}${INSTALL_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET}"
      if install_stack "$s"; then
        installed_count=$((installed_count + 1))
      else
        failures+=("$s")
      fi
    done < <(list_stacks)
    # Update JSON
    update_stacks_json || true
    if (( ${#failures[@]} > 0 )); then
      echo ""
      echo -e "${C_RED}The following stacks failed to install:${C_RESET}"
      for f in "${failures[@]}"; do echo "  - $f"; done
    fi
    press_enter_if_enabled
    return
  fi
  while IFS= read -r s; do
    if ! is_stack_installed "$s"; then
      echo -e "${C_INFO}${INSTALL_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET}"
      if install_stack "$s"; then
        installed_count=$((installed_count + 1))
      else
        failures+=("$s")
      fi
    else
      printf "${C_SHADOW}${INSTALL_ALREADY_INSTALLED}${C_RESET}\n" "$s"
    fi
  done < <(list_stacks)

  # Restore error handling
  set -e
  trap - ERR
  
  echo ""
  if [[ $installed_count -gt 0 ]]; then
    printf "${C_GOOD}${INSTALL_INSTALLED_COUNT}${C_RESET}\n" "$installed_count"
  else
    echo -e "${C_INFO}${INSTALL_ALL_ALREADY_INSTALLED}${C_RESET}"
  fi
  # Update JSON status
  update_stacks_json || true
  if (( ${#failures[@]} > 0 )); then
    echo ""
    echo -e "${C_RED}The following stacks failed to install:${C_RESET}"
    for f in "${failures[@]}"; do echo "  - $f"; done
  fi
  press_enter_if_enabled
}

update_all() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "              ${C_INFO}${INSTALL_UPDATE_SYSTEM_TITLE}${C_RESET}                           "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  echo -e "${C_INFO}${INSTALL_PACMAN_SYU}${C_RESET}"
  sudo pacman -Syu --noconfirm

  if have_paru; then
    echo -e "${C_INFO}${INSTALL_PARU_UPDATE}${C_RESET}"
    paru -Syu --noconfirm
  else
    echo -e "${C_YELLOW}${INSTALL_PARU_NOT_PRESENT}${C_RESET}"
  fi

  echo ""
  echo -e "${C_SHADOW}${INSTALL_NOTE_PACKAGES}${C_RESET}"
  press_enter_if_enabled
}

install_balorsh_wrapper() {
  echo "${INSTALL_WRAPPER_TITLE}"

  if [[ ! -f "$BALOR_WRAPPER_SRC" ]]; then
    printf "${INSTALL_WRAPPER_NOT_FOUND}\n" "$BALOR_WRAPPER_SRC"
    echo "${INSTALL_WRAPPER_EXPECTED}"
    return 1
  fi

  # Vérifier et installer rsync si absent
  if ! command -v rsync >/dev/null 2>&1; then
    echo "${INSTALL_RSYNC_NOT_INSTALLED}"
    sudo pacman -S --needed --noconfirm rsync || {
      echo "${INSTALL_RSYNC_FAILED}"
      return 1
    }
    echo "${INSTALL_RSYNC_INSTALLED}"
  fi

  printf "${INSTALL_WRAPPER_PREPARING}\n" "$BALOR_OPT_ROOT"
  sudo mkdir -p "$BALOR_OPT_ROOT"

  # S'assure que le répertoire de données existe sous /opt/balorsh
  # et qu'il a les permissions et le propriétaire corrects
  BALORSH_DATA_DIR="$BALOR_OPT_ROOT/data"
  if [[ ! -d "$BALORSH_DATA_DIR" ]]; then
    if ! mkdir -p "$BALORSH_DATA_DIR" 2>/dev/null; then
      sudo mkdir -p "$BALORSH_DATA_DIR" || true
    fi
  fi
  if ! chmod 775 "$BALORSH_DATA_DIR" 2>/dev/null; then
    sudo chmod 775 "$BALORSH_DATA_DIR" || true
  fi
  owner="${SUDO_USER:-$USER}"
  if ! chown "$owner:$owner" "$BALORSH_DATA_DIR" 2>/dev/null; then
    sudo chown "$owner:$owner" "$BALORSH_DATA_DIR" || true
  fi

  echo "${INSTALL_WRAPPER_SYNCING}"

  # Fichiers racine indispensables
  sudo rsync -a --delete \
    --exclude='.git' \
    --exclude='*.md' \
    "$BALOR_ROOT/VERSION" \
    "$BALOR_ROOT/balorsh" \
    "$BALOR_OPT_ROOT/"

  # Banner optionnel (ne pas échouer si absent)
  if [[ -f "$BALOR_ROOT/banner.txt" ]]; then
    sudo rsync -a "$BALOR_ROOT/banner.txt" "$BALOR_OPT_ROOT/"
  fi

  # Dossiers (NOTE : slash final => copie le contenu dans le dossier cible)
  sudo rsync -a --delete --exclude='.git' "$BALOR_ROOT/lib/"    "$BALOR_OPT_ROOT/lib/"
  sudo rsync -a --delete --exclude='.git' "$BALOR_ROOT/stacks/" "$BALOR_OPT_ROOT/stacks/"
  
  # Copie de la documentation
  if [[ -d "$BALOR_ROOT/doc" ]]; then
    echo "${INSTALL_WRAPPER_DOC}"
    sudo rsync -a --delete --exclude='.git' "$BALOR_ROOT/doc/" "$BALOR_OPT_ROOT/doc/"
  fi

  # S'assurer que tous les scripts dans /opt/balorsh/stacks ont les bonnes permissions
  echo "${INSTALL_WRAPPER_PERMISSIONS}"
  sudo find "$BALOR_OPT_ROOT/stacks" -type f -name "*.sh" -exec chmod +x {} \;
  
  printf "${INSTALL_WRAPPER_INSTALLING}\n" "$BALOR_BIN_PATH"
  sudo install -m 0755 "$BALOR_OPT_ROOT/balorsh" "$BALOR_BIN_PATH"

  echo "${INSTALL_WRAPPER_OK}"
  "$BALOR_BIN_PATH" --version || true

  echo "${INSTALL_WRAPPER_VERIFY}"
  if [[ -d "$BALOR_OPT_ROOT/stacks" ]]; then
    echo "${INSTALL_WRAPPER_STACKS_COPIED}"
    ls -1 "$BALOR_OPT_ROOT/stacks" | head -n 20 || true
  else
    printf "${INSTALL_WRAPPER_STACKS_NOT_FOUND}\n" "$BALOR_OPT_ROOT"
  fi
  
  echo "${INSTALL_WRAPPER_LIB_I18N}"
  if [[ -f "$BALOR_OPT_ROOT/lib/i18n.sh" ]]; then
    echo "${INSTALL_WRAPPER_I18N_PRESENT}"
  else
    echo "${INSTALL_WRAPPER_I18N_MISSING}"
  fi
  
  if [[ -d "$BALOR_OPT_ROOT/lib/lang" ]]; then
    echo "${INSTALL_WRAPPER_LANG_PRESENT}"
    ls -1 "$BALOR_OPT_ROOT/lib/lang" | sed 's/^/      - /' || true
  else
    echo "${INSTALL_WRAPPER_LANG_MISSING}"
  fi
}

uninstall_balorsh_wrapper() {
  echo "${INSTALL_WRAPPER_UNINSTALL_TITLE}"

  printf "${INSTALL_WRAPPER_REMOVING_BIN}\n" "$BALOR_BIN_PATH"
  sudo rm -f "$BALOR_BIN_PATH"

  printf "${INSTALL_WRAPPER_REMOVING_FRAMEWORK}\n" "$BALOR_OPT_ROOT"
  sudo rm -rf "$BALOR_OPT_ROOT"

  echo "${INSTALL_WRAPPER_REMOVED}"
}

# --------- START: Check installed tools ---------
# Retourne une liste unique de paquets extraits des packages.txt
# Normalise les sorties sous la forme "type:name" où type est "pacman" ou "aur"
collect_packages_from_packages_txt() {
  local f line token type name
  declare -A pkgs=()
  while IFS= read -r -d '' f; do
    while IFS= read -r line; do
      # ignore comments and blank lines
      [[ "$line" =~ ^[[:space:]]*# ]] && continue
      [[ -z "${line//[[:space:]]/}" ]] && continue
      # découper par espaces : supporter plusieurs tokens par ligne
      for token in $line; do
        # Si le token contient un préfixe comme "pacman:pkg" ou "aur:pkg", le conserver
        if [[ "$token" == *":"* ]]; then
          type="${token%%:*}"
          name="${token#*:}"
        else
          # défaut à pacman si aucun préfixe fourni
          type="pacman"
          name="$token"
        fi
        # normaliser le type
        if [[ "$type" =~ ^(pacman|aur)$ ]]; then
          pkgs["${type}:${name}"]=1
        else
          # préfixe inconnu, supposer pacman
          pkgs["pacman:${name}"]=1
        fi
      done
    done < "$f"
  done < <(find "$STACKS_DIR" -type f -name "packages.txt" -print0 2>/dev/null)
  for k in "${!pkgs[@]}"; do echo "$k"; done
}

# Extrait URL(s) de git clone des scripts (heuristique raisonnable)
collect_git_repos_from_install_sh() {
  local line url token rest
  declare -A urls=()
  # grep -I ignore les fichiers binaires, -n permet d'obtenir les lignes
  # mais nous lirons uniquement le contenu texte
  while IFS= read -r -d '' file; do
    while IFS= read -r line; do
        if [[ "$line" =~ git[[:space:]]+clone ]]; then
        rest="${line#*git clone}"
        # split rest into tokens, find first token like URL
        for token in $rest; do
          # supprimer les guillemets autour du token
          token="${token%\"}"
          token="${token#\"}"
          token="${token%\'}"
          token="${token#\'}"
          # ignorer les flags/options
          [[ "$token" == --* || "$token" == -* ]] && continue
          # nettoyer la ponctuation finale (ex. 'Idenroad/repo...') en retirant
          # les caractères terminaux comme '.', ',', ';', ':', ')', '"', '\''
          # retirer toute ponctuation finale via classe POSIX
          while [[ "$token" =~ [[:punct:]]$ ]]; do
            token="${token%?}"
          done

          # heuristique d'URL : contient '://' ou contient '@' et ':'
          if [[ "$token" == *"://"* || ( "$token" == *"@"* && "$token" == *:* ) ]]; then
            urls["$token"]=1
            break
          fi
          # also accept github:user/repo or user/repo -> convert to https URL
          if [[ "$token" =~ ^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$ ]]; then
            urls["https://github.com/$token.git"]=1
            break
          fi
        done
      fi

      # Support pip installs using git+https://... or git+ssh://... tokens
      # but skip if it's a pipx install (handled separately)
      if [[ "$line" =~ git\+ ]] && [[ ! "$line" =~ pipx[[:space:]]+install ]]; then
        # extract tokens like git+https://... or git+ssh://... (stop at space or quote)
        for token in $line; do
          if [[ "$token" == git+* ]]; then
            # strip surrounding quotes and trailing punctuation
            token="${token%\"}"
            token="${token#\"}"
            token="${token%\'}"
            token="${token#\'}"
            token="${token%%[,;.:)]}"
            # remove git+ prefix
            url="${token#git+}"
            urls["$url"]=1
            break
          fi
        done
      fi
    done < "$file"
  done < <(find "$STACKS_DIR" -type f -name "install.sh" -print0 2>/dev/null)

  for u in "${!urls[@]}"; do echo "$u"; done
}

# Extrait paquets référencés directement via paru -S ou pacman -S dans les scripts
# Emit des entrées sous la forme "pacman:name" ou "aur:name" selon le binaire utilisé
collect_pkgs_from_script_commands() {
  local file line tok
  declare -A pkgs=()
  while IFS= read -r -d '' file; do
    while IFS= read -r line; do
      # heuristique simple : détecte les occurrences 'paru -S' ou 'pacman -S'
      if grep -qE '\b(paru|pacman)\b[[:space:]]+-S' <<<"$line"; then
        # déterminer l'outil utilisé sur la ligne (paru => aur)
        local tool
        if grep -qE '\bparu\b' <<<"$line"; then
          tool="aur"
        else
          tool="pacman"
        fi

        # découper les tokens et collecter ceux après '-S' (ignorer les options)
        read -ra toks <<<"$line"
        local saw_S=0
        for tok in "${toks[@]}"; do
          if [[ "$saw_S" -eq 1 ]]; then
            	    # arrêter sur ;, &&, ||, redirection ou mots-clés shell
            	    [[ "$tok" =~ ^(\&\&|\|\||;|>|<)$ ]] && break
            	    # considérer les mots-clés de contrôle shell comme terminaisons
            	    [[ "$tok" =~ ^(then|do|done|fi|else|elif|then)$ ]] && break
            	    [[ "$tok" == -* ]] && continue

            	    # nettoyer le token capturé :
            	    # - retirer les variables de couleur comme ${C_RESET}
            	    # - enlever guillemets simples/doubles
            	    # - couper toute ponctuation finale
            	    # - ignorer si vide après nettoyage
            	    # retirer séquences ${C_...}
            	    tok=$(sed -E 's/\$\{C_[^}]*\}//g' <<<"$tok")
            	    # enlever guillemets éventuels
            	    tok="${tok%\"}"
            	    tok="${tok#\"}"
            	    tok="${tok%\'}"
            	    tok="${tok#\'}"
            	    # retirer ponctuation finale commune
            	    tok="${tok%,}"
            	    tok="${tok%;}"
            	    tok="${tok%%\).*}"
            	    # retirer tout ce qui n'est pas caractère valide de nom de paquet
            	    tok=$(sed -E 's/[^A-Za-z0-9._+:-].*$//g' <<<"$tok")
            	    tok="${tok%% }"
            	    if [[ -n "$tok" ]]; then
            	      pkgs["${tool}:${tok}"]=1
            	    fi
          fi
          if [[ "$tok" =~ ^-S ]]; then
            saw_S=1
          fi
        done
      fi
    done < "$file"
  done < <(find "$STACKS_DIR" -type f -name "*.sh" -print0 2>/dev/null)

  for k in "${!pkgs[@]}"; do echo "$k"; done
}

# Extrait paquets pipx des scripts d'installation
collect_pipx_packages_from_install_scripts() {
  local file line
  declare -A pipx_pkgs=()
  while IFS= read -r -d '' file; do
    while IFS= read -r line; do
      # détecte les occurrences 'pipx install'
      if grep -qE '\bpipx\b[[:space:]]+install' <<<"$line"; then
        # Chercher les URLs git dans la ligne
        if [[ "$line" =~ git\+https://github\.com/[^/]+/([^.]+) ]]; then
          local pkg_name="${BASH_REMATCH[1]}"
          pipx_pkgs["$pkg_name"]=1
        fi
      fi
    done < "$file"
  done < <(find "$STACKS_DIR" -type f -name "install.sh" -print0 2>/dev/null)

  for k in "${!pipx_pkgs[@]}"; do echo "$k"; done
}

# Extrait paquets pipx d'une stack spécifique
collect_pipx_packages_from_stack() {
  local stack_dir="$1"
  local file="$stack_dir/install.sh"
  local line
  declare -A pipx_pkgs=()
  
  if [[ -f "$file" ]]; then
    while IFS= read -r line; do
      # détecte les occurrences 'pipx install'
      if grep -qE '\bpipx\b[[:space:]]+install' <<<"$line"; then
        # Chercher les URLs git dans la ligne
        if [[ "$line" =~ git\+https://github\.com/[^/]+/([^.]+) ]]; then
          local pkg_name="${BASH_REMATCH[1]}"
          pipx_pkgs["$pkg_name"]=1
        fi
      fi
    done < "$file"
  fi

  for k in "${!pipx_pkgs[@]}"; do echo "$k"; done
}

# Vérifie si un paquet pacman est installé
is_pacman_pkg_installed() {
  local pkg="$1"
  if pacman -Q "$pkg" >/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# Vérifie si un git repo semble installé (heuristique)
is_git_repo_installed() {
  local url="$1"
  local url_basename name
  url_basename="$(basename "${url%%.git}")"

  # Build a list of candidate package/command names to check.
  # Some repos use names like 'censys-python' while the installed
  # pipx/pip package/command is 'censys'. Try a few heuristics.
  local candidates=()
  candidates+=("$url_basename")
  # remove common suffix/prefix
  if [[ "$url_basename" == *-python ]]; then
    candidates+=("${url_basename%-python}")
  fi
  if [[ "$url_basename" == python-* ]]; then
    candidates+=("${url_basename#python-}")
  fi
  # also try part before first dash (e.g. repo 'foo-bar' -> 'foo')
  if [[ "$url_basename" == *-* ]]; then
    candidates+=("${url_basename%%-*}")
  fi

  # unique-ify candidates
  declare -A _seen=()
  local uniq_candidates=()
  for c in "${candidates[@]}"; do
    [[ -z "$c" ]] && continue
    if [[ -z "${_seen[$c]}" ]]; then
      uniq_candidates+=("$c")
      _seen[$c]=1
    fi
  done

  # 1) Prefer pip-installed package (explicitly via python -m pip)
  for c in "${uniq_candidates[@]}"; do
    if python3 -m pip show "$c" >/dev/null 2>&1; then
      return 0
    fi
  done

  # 2) If a command with a candidate name exists in PATH, consider it installed
  # only if it does not point into local source directories (stacks or ~/.local/src)
  for c in "${uniq_candidates[@]}"; do
    if command -v "$c" >/dev/null 2>&1; then
      local cmdpath
      cmdpath=$(command -v "$c") || true
      case "$cmdpath" in
        "$STACKS_DIR"/*|"$HOME/.local/src"/*)
          # ignore commands pointing into local source dirs
          continue
          ;;
        *)
          return 0
          ;;
      esac
    fi
  done

  # Otherwise, not considered installed
  return 1
}

# Cache pipx list output to avoid calling it repeatedly (which can spam warnings
# when interpreters are missing).
_pipx_list_short_cached() {
  if [[ -n "${_BALOR_PIPX_LIST_SHORT_CACHE:-}" ]]; then
    printf '%s\n' "${_BALOR_PIPX_LIST_SHORT_CACHE}"
    return 0
  fi

  if ! command -v pipx >/dev/null 2>&1; then
    _BALOR_PIPX_LIST_SHORT_CACHE=""
    _BALOR_PIPX_LIST_SHORT_WARN=""
    return 1
  fi

  local out
  out=$(pipx list --short 2>&1 || true)
  _BALOR_PIPX_LIST_SHORT_WARN=""
  if grep -qiE 'invalid interpreter|missing python interpreter' <<<"$out"; then
    _BALOR_PIPX_LIST_SHORT_WARN="$out"
  fi
  _BALOR_PIPX_LIST_SHORT_CACHE="$(grep -v -iE 'invalid interpreter|missing python interpreter|^\s*To fix, execute:' <<<"$out" || true)"
  printf '%s\n' "${_BALOR_PIPX_LIST_SHORT_CACHE}"
  return 0
}

_pipx_offer_repair_if_needed() {
  if [[ -z "${_BALOR_PIPX_LIST_SHORT_WARN:-}" ]]; then
    return 0
  fi

  if [[ -n "${BALOR_PIPX_REPAIR_DONE:-}" ]]; then
    return 0
  fi
  BALOR_PIPX_REPAIR_DONE=1

  echo -e "${C_YELLOW}${_BALOR_PIPX_LIST_SHORT_WARN}${C_RESET}"
  echo ""

  if [[ -t 0 || -e /dev/tty ]]; then
    echo -ne "${C_ACCENT1}Exécuter 'pipx reinstall-all' pour réparer ? [y/N]: ${C_RESET}"
    local ans
    if [[ -e /dev/tty ]]; then
      IFS= read -r ans </dev/tty
    else
      IFS= read -r ans
    fi
    if [[ "$ans" =~ ^[yYoO]$ ]]; then
      local py="python3"
      if command -v python3.13 >/dev/null 2>&1; then
        py="python3.13"
      fi
      echo -e "${C_INFO}pipx reinstall-all --python $py${C_RESET}"
      pipx reinstall-all --python "$py" || true
      unset _BALOR_PIPX_LIST_SHORT_CACHE
      unset _BALOR_PIPX_LIST_SHORT_WARN
      _pipx_list_short_cached >/dev/null 2>&1 || true
    fi
  fi
}

# Vérifie si un paquet pipx est installé
is_pipx_pkg_installed() {
  local pkg="$1"

  # Vérifier si pipx est disponible
  if ! command -v pipx >/dev/null 2>&1; then
    return 1
  fi

  # Some repos use names like 'censys-python' while the installed
  # pipx/pip package/command is 'censys'. Try a few heuristics.
  local pkg_variants=("$pkg")

  # Add common name mappings
  case "$pkg" in
    censys-python)
      pkg_variants+=("censys")
      ;;
    theHarvester)
      pkg_variants+=("theharvester")
      ;;
  esac

  # Try each variant
  for variant in "${pkg_variants[@]}"; do
    # Utiliser pipx list pour vérifier si le paquet est installé
    if _pipx_list_short_cached | grep -q "^${variant} "; then
      return 0
    fi

    # Sinon, essayer de voir si la commande existe dans PATH
    if command -v "$variant" >/dev/null 2>&1; then
      local cmdpath
      cmdpath=$(command -v "$variant") || true
      case "$cmdpath" in
        "$HOME/.local/pipx"/*)
          # C'est probablement installé via pipx
          return 0
          ;;
      esac
    fi
  done

  return 1
}

# Fonction principale : construit la liste "attendue" et vérifie l'état
check_installed_tools() {
  echo "${INSTALL_CHECK_TITLE}"

  # désactive 'errexit' dans cette fonction pour permettre de vérifier
  # plusieurs paquets sans interrompre la routine
  set +e

  # Function to join array elements with comma
  join_array() {
    local IFS=','
    echo "$*"
  }

  # collecter paquets depuis packages.txt
  mapfile -t pkgs_from_txt < <(collect_packages_from_packages_txt)
  # collecter paquets explicitement dans scripts (paru/pacman)
  mapfile -t pkgs_from_scripts < <(collect_pkgs_from_script_commands)
  # combine unique packages
  declare -A ALL_PKG_SET=()
  for p in "${pkgs_from_txt[@]}" "${pkgs_from_scripts[@]}"; do
    [[ -n "$p" ]] || continue
    ALL_PKG_SET["$p"]=1
  done
  # Ajouter les paquets essentiels
  for ess in "${ESSENTIAL_PACKAGES[@]}"; do
    ALL_PKG_SET["pacman:$ess"]=1
  done
  # list of packages
  pkgs=()
  for p in "${!ALL_PKG_SET[@]}"; do pkgs+=("$p"); done
  IFS=$'\n' pkgs=($(sort -u <<<"${pkgs[*]}")) || true
  unset IFS

  # collect git repos
  mapfile -t git_urls < <(collect_git_repos_from_install_sh)

  # collect pipx packages
  mapfile -t pipx_pkgs < <(collect_pipx_packages_from_install_scripts)

  _pipx_list_short_cached >/dev/null 2>&1 || true
  _pipx_offer_repair_if_needed || true

  local total_expected=0
  local installed_count=0
  local protected_count=0
  declare -a pacman_found=() pacman_missing=() pacman_protected=()
  declare -a aur_found=() aur_missing=() aur_protected=()
  declare -a git_found=() git_missing=() git_protected=() git_missing_names=()
  declare -a pipx_found=() pipx_missing=() pipx_protected=()

  # check packages (entries are normalized as type:name)
  for p in "${pkgs[@]}"; do
    [[ -n "$p" ]] && :
    type="${p%%:*}"
    name="${p#*:}"
    ((total_expected++))
    case "$type" in
      pacman)
        if is_pacman_pkg_installed "$name"; then
          if [[ " ${ESSENTIAL_PACKAGES[*]} " =~ " $name " ]]; then
            pacman_protected+=("$name")
            ((protected_count++))
          else
            pacman_found+=("$name")
          fi
          ((installed_count++))
        else
          pacman_missing+=("$name")
        fi
        ;;
      aur)
        # AUR packages, check via pacman DB (if built/installed they appear there)
        if is_pacman_pkg_installed "$name"; then
          if [[ " ${ESSENTIAL_PACKAGES[*]} " =~ " $name " ]]; then
            aur_protected+=("$name")
            ((protected_count++))
          else
            aur_found+=("$name")
          fi
          ((installed_count++))
        else
          aur_missing+=("$name")
        fi
        ;;
      *)
        # unknown type -> assume pacman
        if is_pacman_pkg_installed "$name"; then
          if [[ " ${ESSENTIAL_PACKAGES[*]} " =~ " $name " ]]; then
            pacman_protected+=("$name")
            ((protected_count++))
          else
            pacman_found+=("$name")
          fi
          ((installed_count++))
        else
          pacman_missing+=("$name")
        fi
        ;;
    esac
  done

  # check git repos
  for url in "${git_urls[@]}"; do
    ((total_expected++))
    repo_name="$(basename "${url%%.git}")"
    if is_git_repo_installed "$url"; then
      git_found+=("$repo_name")
      ((installed_count++))
    else
      git_missing+=("${repo_name}:${url}")
      git_missing_names+=("$repo_name")
    fi
  done

  # check pipx packages
  for pkg in "${pipx_pkgs[@]}"; do
    ((total_expected++))
    if is_pipx_pkg_installed "$pkg"; then
      pipx_found+=("$pkg")
      ((installed_count++))
    else
      pipx_missing+=("$pkg")
    fi
  done

  echo
  echo "${INSTALL_CHECK_SUMMARY}"
  echo "  ${INSTALL_CHECK_EXPECTED} $total_expected"
  echo "  ${INSTALL_CHECK_INSTALLED} $installed_count"
  echo "  ${INSTALL_CHECK_MISSING} $((total_expected - installed_count))"
  echo "  ${INSTALL_CHECK_PROTECTED} $protected_count"
  echo

  echo "${INSTALL_CHECK_DETAILS}"

  # Combine git and pipx arrays
  declare -a git_pipx_found=("${git_found[@]}" "${pipx_found[@]}")
  declare -a git_pipx_missing=("${git_missing_names[@]}" "${pipx_missing[@]}")
  declare -a git_pipx_protected=("${git_protected[@]}" "${pipx_protected[@]}")

  # Function to print a table
  print_table() {
    local title="$1"
    local col1="$2" col2="$3" col3="$4"
    local arr1_name="$5" arr2_name="$6" arr3_name="$7"

    eval "local arr1=(\"\${$arr1_name[@]}\")"
    eval "local arr2=(\"\${$arr2_name[@]}\")"
    eval "local arr3=(\"\${$arr3_name[@]}\")"

    echo -e "${C_ACCENT2}$title${C_RESET}"
    printf "${C_ACCENT2}%-30s %-30s %-30s${C_RESET}\n" "$col1" "$col2" "$col3"
    printf "${C_ACCENT2}%-30s %-30s %-30s${C_RESET}\n" "------------------------------" "------------------------------" "------------------------------"

    local max_len=0
    (( ${#arr1[@]} > max_len )) && max_len=${#arr1[@]}
    (( ${#arr2[@]} > max_len )) && max_len=${#arr2[@]}
    (( ${#arr3[@]} > max_len )) && max_len=${#arr3[@]}

    for ((i=0; i<max_len; i++)); do
      printf "${C_GOOD}%-30s${C_RESET} ${C_RED}%-30s${C_RESET} ${C_ACCENT1}%-30s${C_RESET}\n" \
        "${arr1[i]:-}" "${arr2[i]:-}" "${arr3[i]:-}"
    done

    printf "${C_ACCENT2}%-30s %-30s %-30s${C_RESET}\n" \
      "${#arr1[@]}" "${#arr2[@]}" "${#arr3[@]}"
    echo
  }

  # PACMAN table
  print_table "${INSTALL_CHECK_TABLE_PACMAN}" "${INSTALL_CHECK_TABLE_INSTALLED}" "${INSTALL_CHECK_TABLE_MISSING}" "${INSTALL_CHECK_TABLE_PROTECTED}" pacman_found pacman_missing pacman_protected

  # AUR table
  print_table "${INSTALL_CHECK_TABLE_AUR}" "${INSTALL_CHECK_TABLE_INSTALLED}" "${INSTALL_CHECK_TABLE_MISSING}" "${INSTALL_CHECK_TABLE_PROTECTED}" aur_found aur_missing aur_protected

  # GIT/PIPX table
  print_table "${INSTALL_CHECK_TABLE_GIT_PIPX}" "${INSTALL_CHECK_TABLE_INSTALLED}" "${INSTALL_CHECK_TABLE_MISSING}" "${INSTALL_CHECK_TABLE_PROTECTED}" git_pipx_found git_pipx_missing git_pipx_protected

  echo
  echo "${INSTALL_CHECK_TIPS}"
  echo "${INSTALL_CHECK_TIP1}"
  echo "${INSTALL_CHECK_TIP2}"
  echo "${INSTALL_CHECK_TIP3}"
  echo

  # restaurer le comportement 'errexit' avant de retourner
  set -e
  if (( total_expected - installed_count == 0 )); then
    return 0
  fi

  return 1
}
# --------- END: Check installed tools ---------

ensure_stack_scripts_executable() {
  find "$STACKS_DIR" -type f -name "*.sh" -print0 | while IFS= read -r -d '' f; do
    chmod +x "$f"
  done
}

check_essential_packages() {
  echo -e "${C_INFO}${MSG_ESSENTIAL_CHECK}${C_RESET}"
  echo ""
  
  for pkg in "${ESSENTIAL_PACKAGES[@]}"; do
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
      printf "${MSG_ESSENTIAL_OK}\n" "$pkg"
    else
      printf "${MSG_ESSENTIAL_MISSING}\n" "$pkg"
      install_pacman_pkg "$pkg"
      printf "${MSG_ESSENTIAL_INSTALLED}\n" "$pkg"
    fi
  done
  echo ""
}

# Supprimer les paquets orphelins
remove_orphaned_packages() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "        ${C_RED}${INSTALL_REMOVE_ORPHANS_TITLE}${C_RESET}                      "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  # Lister les paquets orphelins
  local orphans
  orphans=$(pacman -Qdtq 2>/dev/null || true)
  
  if [[ -z "$orphans" ]]; then
    echo -e "${C_GOOD}${INSTALL_NO_ORPHANS}${C_RESET}"
    press_enter_if_enabled
    return
  fi
  
  echo -e "${C_YELLOW}${INSTALL_ORPHANS_FOUND}${C_RESET}"
  echo "$orphans" | sed 's/^/  - /'
  echo ""
  
  echo -ne "${C_RED}${INSTALL_ORPHANS_CONFIRM}${C_RESET} "
  read -r confirm
  
  if [[ "$confirm" =~ ^[oOyY]$ ]]; then
    echo -e "${C_YELLOW}${INSTALL_ORPHANS_REMOVING}${C_RESET}"
    echo "$orphans" | sudo pacman -Rns --noconfirm - || true
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
      echo -e "${C_GOOD}${INSTALL_ORPHANS_REMOVED}${C_RESET}"
    else
      echo -e "${C_RED}${INSTALL_ORPHANS_FAILED}${C_RESET}"
    fi
  else
    echo -e "${C_INFO}${INSTALL_CANCELLED}${C_RESET}"
  fi
  
  press_enter_if_enabled
}

add_cachyos_repo() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "            ${C_GOOD}${INSTALL_CACHYOS_TITLE}${C_RESET}                        "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  echo -e "${C_INFO}${INSTALL_CACHYOS_DOWNLOADING}${C_RESET}"
  if curl https://mirror.cachyos.org/cachyos-repo.tar.xz -o cachyos-repo.tar.xz; then
    echo -e "${C_GOOD}${INSTALL_CACHYOS_DOWNLOAD_SUCCESS}${C_RESET}"
    
    echo -e "${C_INFO}${INSTALL_CACHYOS_EXTRACTING}${C_RESET}"
    if tar xvf cachyos-repo.tar.xz && cd cachyos-repo; then
      echo -e "${C_GOOD}${INSTALL_CACHYOS_EXTRACT_SUCCESS}${C_RESET}"
      
      echo -e "${C_INFO}${INSTALL_CACHYOS_INSTALLING}${C_RESET}"
      if sudo ./cachyos-repo.sh; then
        echo -e "${C_GOOD}${INSTALL_CACHYOS_INSTALL_SUCCESS}${C_RESET}"
        
        # Nettoyage
        cd ..
        rm -rf cachyos-repo cachyos-repo.tar.xz
        echo -e "${C_INFO}${INSTALL_CACHYOS_CLEANUP}${C_RESET}"
      else
        echo -e "${C_RED}${INSTALL_CACHYOS_INSTALL_ERROR}${C_RESET}"
        cd ..
        rm -rf cachyos-repo cachyos-repo.tar.xz
      fi
    else
      echo -e "${C_RED}${INSTALL_CACHYOS_EXTRACT_ERROR}${C_RESET}"
      rm -f cachyos-repo.tar.xz
    fi
  else
    echo -e "${C_RED}${INSTALL_CACHYOS_DOWNLOAD_ERROR}${C_RESET}"
  fi
  
  echo ""
  press_enter_if_enabled
}

main_menu() {
  while true; do
    clear
    
    # Détecter la largeur du terminal
    local term_width=$(tput cols 2>/dev/null || echo 80)
    local min_width=125
    
    # Lire la bannière dans un tableau
    local banner_lines=()
    if [[ -f "$BANNER_FILE" ]]; then
      mapfile -t banner_lines < "$BANNER_FILE"
    else
      banner_lines=("${INSTALL_BANNER_FALLBACK}")
    fi
    
    # Préparer le menu (côté droit) - centré verticalement
    local menu_lines=(
      "${C_ACCENT2}╔═══════════════════════════════════════════════════════╗${C_RESET}"
      "$(printf "  ${C_GOOD}${INSTALL_MENU_TITLE}${C_RESET}  " "${VERSION}")"
      "${C_ACCENT2}╚═══════════════════════════════════════════════════════╝${C_RESET}"
      ""
      " ${C_SHADOW}${INSTALL_SECTION_INSTALL}${C_RESET}"
      " ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${INSTALL_MENU_1}${C_RESET}"
      " ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${INSTALL_MENU_2}${C_RESET}"
      " ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${INSTALL_MENU_3}${C_RESET}"
      " ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${INSTALL_MENU_4}${C_RESET}"
      " ${C_HIGHLIGHT}5)${C_RESET} ${C_INFO}${INSTALL_MENU_5}${C_RESET}"
      " ${C_HIGHLIGHT}6)${C_RESET} ${C_INFO}${INSTALL_MENU_6}${C_RESET}"
      ""
      " ${C_SHADOW}${INSTALL_SECTION_UNINSTALL}${C_RESET}"
      " ${C_HIGHLIGHT}7)${C_RESET} ${C_INFO}${INSTALL_MENU_7}${C_RESET}"
      " ${C_HIGHLIGHT}8)${C_RESET} ${C_INFO}${INSTALL_MENU_8}${C_RESET}"
      " ${C_HIGHLIGHT}9)${C_RESET} ${C_INFO}${INSTALL_MENU_9}${C_RESET}"
      ""
      " ${C_SHADOW}${INSTALL_SECTION_OTHER}${C_RESET}"
      " ${C_HIGHLIGHT}10)${C_RESET} ${C_INFO}${INSTALL_MENU_10}${C_RESET}"
      " ${C_HIGHLIGHT}11)${C_RESET} ${C_INFO}${INSTALL_MENU_11}${C_RESET}"
      " ${C_HIGHLIGHT}12)${C_RESET} ${C_INFO}${INSTALL_MENU_12}${C_RESET}"
      " ${C_HIGHLIGHT}13)${C_RESET} ${C_INFO}${INSTALL_MENU_13}${C_RESET}"
      ""
      " ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${INSTALL_MENU_0}${C_RESET}"
    )
    
    # Affichage adaptatif selon la largeur du terminal
    if [[ $term_width -lt $min_width ]]; then
      # Mode vertical : bannière au-dessus, menu en dessous
      echo -e "${C_ACCENT2}"
      for line in "${banner_lines[@]}"; do
        echo "$line"
      done
      echo -e "${C_RESET}"
      echo ""
      for line in "${menu_lines[@]}"; do
        echo -e "$line"
      done
      echo ""
      echo -e "${C_ACCENT2}$(printf '═%.0s' {1..60})${C_RESET}"
    else
      # Mode horizontal : bannière à gauche, menu à droite
      local max_lines=${#banner_lines[@]}
      if [[ ${#menu_lines[@]} -gt $max_lines ]]; then
        max_lines=${#menu_lines[@]}
      fi
      
      for ((i=0; i<max_lines; i++)); do
        # Ligne de bannière (en violet)
        if [[ $i -lt ${#banner_lines[@]} ]]; then
          echo -ne "${C_ACCENT2}${banner_lines[$i]}${C_RESET}"
        else
          printf "%80s" ""
        fi
        
        # Espacement entre bannière et menu
        echo -n "  "
        
        # Ligne de menu
        if [[ $i -lt ${#menu_lines[@]} ]]; then
          echo -e "${menu_lines[$i]}"
        else
          echo ""
        fi
      done
      
      echo ""
      echo -e "${C_ACCENT2}$(printf '═%.0s' {1..123})${C_RESET}"
    fi
    
    echo ""
    echo -ne "${C_ACCENT1}${INSTALL_YOUR_CHOICE}${C_RESET} "
    read -r choice

    case "$choice" in
      1) install_all ;;
      2) install_all_except_llm ;;
      3) update_existing_stacks ;;
      4) install_missing_stacks ;;
      5) menu_install_specific ;;
      6) install_balorsh_wrapper ;;
      7) uninstall_balorsh_wrapper ;;
      8) menu_uninstall ;;
      9) uninstall_all ;;
      10) update_all ;;
      11)
        check_installed_tools || true
        echo ""
        # Prompt and wait (centralisé)
        press_enter_if_enabled
        ;;
      12) remove_orphaned_packages ;;
      13) add_cachyos_repo ;;
      0) 
        clear
        echo -e "${C_GOOD}[Idenroad] ${INSTALL_BYE}${C_RESET}"
        exit 0
        ;;
      *) 
        echo -e "${C_RED}[!] ${INSTALL_INVALID_CHOICE}${C_RESET}"
        sleep 1
        ;;
    esac
  done
}

ensure_stack_scripts_executable

# Aide : convertir un tableau bash en tableau JSON de chaînes
_json_join() {
  local -n _arr=$1
  local out=""
  for v in "${_arr[@]}"; do
    # escape backslashes and quotes
    esc=${v//\\/\\\\}
    esc=${esc//\"/\\\"}
    if [[ -n "$out" ]]; then out+=","; fi
    out+="\"${esc}\""
  done
  printf "[%s]" "$out"
}

# Sortie JSON non interactive pour CI : affiche un JSON structuré et renvoie
# un code non-nul si des éléments manquent
check_installed_tools_json() {
  set +e
  mapfile -t pkgs_from_txt < <(collect_packages_from_packages_txt)
  mapfile -t pkgs_from_scripts < <(collect_pkgs_from_script_commands)
  declare -A ALL_PKG_SET=()
  for p in "${pkgs_from_txt[@]}" "${pkgs_from_scripts[@]}"; do
    [[ -n "$p" ]] || continue
    ALL_PKG_SET["$p"]=1
  done
  pkgs=()
  for p in "${!ALL_PKG_SET[@]}"; do pkgs+=("$p"); done
  IFS=$'\n' pkgs=($(sort -u <<<"${pkgs[*]}")) || true
  unset IFS
  mapfile -t git_urls < <(collect_git_repos_from_install_sh)

  declare -a pacman_found=() pacman_missing=()
  declare -a aur_found=() aur_missing=()
  declare -a git_found=() git_missing=()
  local total_expected=0 installed_count=0

  for p in "${pkgs[@]}"; do
    [[ -n "$p" ]] || continue
    type="${p%%:*}"
    name="${p#*:}"
    ((total_expected++))
    case "$type" in
      pacman)
        if is_pacman_pkg_installed "$name"; then pacman_found+=("$name"); ((installed_count++)); else pacman_missing+=("$name"); fi
        ;;
      aur)
        if is_pacman_pkg_installed "$name"; then aur_found+=("$name"); ((installed_count++)); else aur_missing+=("$name"); fi
        ;;
      *)
        if is_pacman_pkg_installed "$name"; then pacman_found+=("$name"); ((installed_count++)); else pacman_missing+=("$name"); fi
        ;;
    esac
  done

  for url in "${git_urls[@]}"; do
    ((total_expected++))
    repo_name="$(basename "${url%%.git}")"
    if is_git_repo_installed "$url"; then git_found+=("$repo_name"); ((installed_count++)); else git_missing+=("${repo_name}:${url}"); fi
  done

  # construit le JSON dans un fichier temporaire, puis tente d'écrire
  # vers $BALOR_OPT_ROOT/json/tools_status.json
  tmpf=$(mktemp)
  trap 'rm -f "$tmpf"' EXIT
  printf '{\n' >>"$tmpf"
  printf '  "total_expected": %d,\n' "$total_expected" >>"$tmpf"
  printf '  "installed": %d,\n' "$installed_count" >>"$tmpf"
  printf '  "missing": %d,\n' "$((total_expected - installed_count))" >>"$tmpf"

  # pacman
  printf '  "pacman": {"expected": %d, "installed": %d, "missing": %d, "installed_list": ' "$(( ${#pacman_found[@]} + ${#pacman_missing[@]} ))" "${#pacman_found[@]}" "${#pacman_missing[@]}" >>"$tmpf"
  _json_join pacman_found >>"$tmpf"; printf ', "missing_list": ' >>"$tmpf"; _json_join pacman_missing >>"$tmpf"; printf '},\n' >>"$tmpf"

  # aur
  printf '  "aur": {"expected": %d, "installed": %d, "missing": %d, "installed_list": ' "$(( ${#aur_found[@]} + ${#aur_missing[@]} ))" "${#aur_found[@]}" "${#aur_missing[@]}" >>"$tmpf"
  _json_join aur_found >>"$tmpf"; printf ', "missing_list": ' >>"$tmpf"; _json_join aur_missing >>"$tmpf"; printf '},\n' >>"$tmpf"

  # git
  printf '  "git": {"expected": %d, "installed": %d, "missing": %d, "installed_list": ' "$(( ${#git_found[@]} + ${#git_missing[@]} ))" "${#git_found[@]}" "${#git_missing[@]}" >>"$tmpf"
  _json_join git_found >>"$tmpf"; printf ', "missing_list": [' >>"$tmpf"
  local first=1
  for gm in "${git_missing[@]}"; do
    name="${gm%%:*}"
    url="${gm#*:}"
    # escape quotes for JSON
    esc_name=${name//\"/\\\"}
    esc_url=${url//\"/\\\"}
    if [[ $first -eq 0 ]]; then printf ',' >>"$tmpf"; fi
    printf '{"name":"%s","url":"%s"}' "$esc_name" "$esc_url" >>"$tmpf"
    first=0
  done
  printf ']}}\n' >>"$tmpf"

  # print to stdout
  cat "$tmpf"

  # tenter de créer le dossier de sortie (d'abord sans sudo, sinon avec sudo)
  outdir="$BALOR_OPT_ROOT/json"
  if [[ ! -d "$outdir" ]]; then
    if ! mkdir -p "$outdir" 2>/dev/null; then
      sudo mkdir -p "$outdir" || true
    fi
  fi

  # ensure directory permissions are writable by owner and group (rwxrwxr-x)
  if ! chmod 775 "$outdir" 2>/dev/null; then
    sudo chmod 775 "$outdir" || true
  fi

  # ensure directory ownership is set to the installer user (SUDO_USER when using sudo, otherwise current user)
  owner="${SUDO_USER:-$USER}"
  if ! chown "$owner:$owner" "$outdir" 2>/dev/null; then
    sudo chown "$owner:$owner" "$outdir" || true
  fi

  dest="$outdir/tools_status.json"
  # tenter d'écrire en tant qu'utilisateur courant, sinon utiliser sudo tee
  if ! cp "$tmpf" "$dest" 2>/dev/null; then
    if ! sudo tee "$dest" >/dev/null <"$tmpf"; then
      echo "[WARN] Unable to write $dest (permission denied)." >&2
    else
      echo "[OK] JSON written to $dest (via sudo)." >&2
    fi
  else
    echo "[OK] JSON written to $dest." >&2
  fi
  # S'assurer que le fichier JSON appartient à l'utilisateur installateur
  owner="${SUDO_USER:-$USER}"
  if ! chown "$owner:$owner" "$dest" 2>/dev/null; then
    sudo chown "$owner:$owner" "$dest" 2>/dev/null || echo "[WARN] Unable to chown $dest to $owner." >&2
  fi

  set -e
  if (( total_expected - installed_count == 0 )); then
    return 0
  fi
  return 1
}

# Options CLI : permettre les vérifications non-interactives
if [[ "${1:-}" == "--check-tools" ]]; then
  check_installed_tools
  exit $?
fi
# Options CLI : permettre les vérifications non-interactives
if [[ "${1:-}" == "--check-tools" ]]; then
  check_installed_tools
  exit $?
fi
if [[ "${1:-}" == "--check-tools-json" ]]; then
  check_installed_tools_json
  exit $?
fi
# permettre le sourcing non-interactif pour le débogage : définir NO_MAIN_MENU=1 pour
# ignorer le menu
if [[ -z "${NO_MAIN_MENU:-}" ]]; then
  check_essential_packages
  main_menu
fi

