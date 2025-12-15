#!/usr/bin/env bash
set -e

BALOR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Version de l'installateur (lit la première ligne non-commentaire de VERSION)
VERSION="${VERSION:-$(grep -v '^#' "$BALOR_ROOT/VERSION" 2>/dev/null | grep -v '^$' | head -n1 | tr -d ' \n\r\t' || echo 'unknown')}"

# shellcheck source=lib/common.sh
source "$BALOR_ROOT/lib/common.sh"

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
  local version=$(grep "\"$stack\":" "$json_file" | sed -E 's/.*"version":[[:space:]]*"([^"]+)".*/\1/')
  
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
    bash "$script" </dev/tty
    local exit_code=$?
    update_stacks_json
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
    bash "$script"
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
    install_stack "$sel"
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
  read -r confirm
  
  if [[ "$confirm" =~ ^[oOyY]$ ]]; then
    while IFS= read -r s; do
      echo -e "${C_INFO}${INSTALL_UNINSTALL_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET}"
      uninstall_stack "$s"
    done < <(list_stacks)
    echo ""
    echo -e "${C_GOOD}${INSTALL_UNINSTALL_ALL_COMPLETE}${C_RESET}"
  else
    echo -e "${C_INFO}${INSTALL_CANCELLED}${C_RESET}"
  fi
  echo ""
  echo -ne "${C_ACCENT1}${INSTALL_PRESS_ENTER}${C_RESET}"
  read -r
}

install_all_except_llm() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "      ${C_GOOD}${INSTALL_INSTALL_EXCEPT_LLM_TITLE}${C_RESET}                  "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  while IFS= read -r s; do
    if [[ "$s" != "llm" ]]; then
      echo -e "${C_INFO}${INSTALL_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET}"
      install_stack "$s"
    else
      echo -e "${C_YELLOW}${INSTALL_LLM_IGNORED}${C_RESET}"
    fi
  done < <(list_stacks)
  echo ""
  echo -e "${C_GOOD}${INSTALL_ALL_EXCEPT_LLM_COMPLETE}${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${INSTALL_PRESS_ENTER}${C_RESET}"
  read -r
}

install_all() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "          ${C_GOOD}${INSTALL_INSTALL_ALL_TITLE}${C_RESET}                       "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  while IFS= read -r s; do
    echo -e "${C_INFO}${INSTALL_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET}"
    install_stack "$s"
  done < <(list_stacks)
  echo ""
  echo -e "${C_GOOD}${INSTALL_ALL_COMPLETE}${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${INSTALL_PRESS_ENTER}${C_RESET}"
  read -r
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
  
  local updated_count=0
  local skipped_count=0
  while IFS= read -r s; do
    if is_stack_installed "$s"; then
      local current_version=$(get_installed_stack_version "$s")
      local available_version=$(get_stack_version "$s")
      
      if [[ "$current_version" != "$available_version" ]]; then
        echo -e "${C_INFO}${INSTALL_UPDATE_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET} ${C_SHADOW}($current_version → $available_version)${C_RESET}"
        if install_stack "$s"; then
          updated_count=$((updated_count + 1))
        else
          printf "${C_RED}${INSTALL_UPDATE_FAILED}${C_RESET}\n" "$s"
        fi
      else
        printf "${C_SHADOW}${INSTALL_ALREADY_UP_TO_DATE}${C_RESET}\n" "$s" "$current_version"
        skipped_count=$((skipped_count + 1))
      fi
    else
      printf "${C_SHADOW}${INSTALL_NOT_INSTALLED_IGNORED}${C_RESET}\n" "$s"
    fi
  done < <(list_stacks)
  
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
  echo ""
  echo -ne "${C_ACCENT1}${INSTALL_PRESS_ENTER}${C_RESET}"
  read -r
}

install_missing_stacks() {
  echo ""
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo -e "          ${C_GOOD}${INSTALL_MENU_4}${C_RESET}                        "
  echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
  echo ""
  
  local installed_count=0
  while IFS= read -r s; do
    if ! is_stack_installed "$s"; then
      echo -e "${C_INFO}${INSTALL_STACK_MSG} ${C_HIGHLIGHT}$s${C_RESET}"
      install_stack "$s"
      installed_count=$((installed_count + 1))
    else
      printf "${C_SHADOW}${INSTALL_ALREADY_INSTALLED}${C_RESET}\n" "$s"
    fi
  done < <(list_stacks)
  
  echo ""
  if [[ $installed_count -gt 0 ]]; then
    printf "${C_GOOD}${INSTALL_INSTALLED_COUNT}${C_RESET}\n" "$installed_count"
  else
    echo -e "${C_INFO}${INSTALL_ALL_ALREADY_INSTALLED}${C_RESET}"
  fi
  echo ""
  echo -ne "${C_ACCENT1}${INSTALL_PRESS_ENTER}${C_RESET}"
  read -r
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
  echo ""
  echo -ne "${C_ACCENT1}${INSTALL_PRESS_ENTER}${C_RESET}"
  read -r
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
            # retirer la ponctuation finale
            tok="${tok%,}"
            tok="${tok%;}"
            # ajouter avec le type d'outil détecté
            pkgs["${tool}:${tok}"]=1
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
  local name
  # extraire le nom
  name="$(basename "${url%%.git}")"
  # vérifier les emplacements courants
  local paths=(
    "$BALOR_OPT_ROOT/$name"
    "$BALOR_OPT_ROOT/stacks/$name"
    "/opt/$name"
    "$HOME/.local/src/$name"
    "$STACKS_DIR/$name"
  )
  for p in "${paths[@]}"; do
    if [[ -d "$p" ]]; then
      return 0
    fi
  done
  # tester la présence d'une commande porteuse du nom
  if command -v "$name" >/dev/null 2>&1; then
    return 0
  fi
  # tenter de rechercher sous BALOR_OPT_ROOT (coûteux mais acceptable)
  if [[ -d "$BALOR_OPT_ROOT" ]]; then
    if find "$BALOR_OPT_ROOT" -maxdepth 3 -type d -name "$name" -print -quit 2>/dev/null | grep -q .; then
      return 0
    fi
  fi
  return 1
}

# Fonction principale : construit la liste "attendue" et vérifie l'état
check_installed_tools() {
  echo "${INSTALL_CHECK_TITLE}"

  # désactive 'errexit' dans cette fonction pour permettre de vérifier
  # plusieurs paquets sans interrompre la routine
  set +e

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
  # list of packages
  pkgs=()
  for p in "${!ALL_PKG_SET[@]}"; do pkgs+=("$p"); done
  IFS=$'\n' pkgs=($(sort -u <<<"${pkgs[*]}")) || true
  unset IFS

  # collect git repos
  mapfile -t git_urls < <(collect_git_repos_from_install_sh)

  local total_expected=0
  local installed_count=0
  declare -a pacman_found=() pacman_missing=()
  declare -a aur_found=() aur_missing=()
  declare -a git_found=() git_missing=()

  # check packages (entries are normalized as type:name)
  for p in "${pkgs[@]}"; do
    [[ -n "$p" ]] && :
    type="${p%%:*}"
    name="${p#*:}"
    ((total_expected++))
    case "$type" in
      pacman)
        if is_pacman_pkg_installed "$name"; then
          pacman_found+=("$name")
          ((installed_count++))
        else
          pacman_missing+=("$name")
        fi
        ;;
      aur)
        # AUR packages, check via pacman DB (if built/installed they appear there)
        if is_pacman_pkg_installed "$name"; then
          aur_found+=("$name")
          ((installed_count++))
        else
          aur_missing+=("$name")
        fi
        ;;
      *)
        # unknown type -> assume pacman
        if is_pacman_pkg_installed "$name"; then
          pacman_found+=("$name")
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
    fi
  done

  echo
  echo "${INSTALL_CHECK_SUMMARY}"
  echo "  ${INSTALL_CHECK_EXPECTED} $total_expected"
  echo "  ${INSTALL_CHECK_INSTALLED} $installed_count"
  echo "  ${INSTALL_CHECK_MISSING} $((total_expected - installed_count))"
  echo

  echo "${INSTALL_CHECK_DETAILS}"
  echo "  ${INSTALL_CHECK_PACMAN} $(( ${#pacman_found[@]} + ${#pacman_missing[@]} ))${INSTALL_CHECK_INSTALLEDS} ${#pacman_found[@]}${INSTALL_CHECK_MISSINGS} ${#pacman_missing[@]}"
  if (( ${#pacman_found[@]} )); then
    echo "${INSTALL_CHECK_INST_LIST} ${pacman_found[*]}"
  fi
  if (( ${#pacman_missing[@]} )); then
    echo "${INSTALL_CHECK_MISS_LIST} ${pacman_missing[*]}"
  fi

  echo "  ${INSTALL_CHECK_AUR} $(( ${#aur_found[@]} + ${#aur_missing[@]} ))${INSTALL_CHECK_INSTALLEDS} ${#aur_found[@]}${INSTALL_CHECK_MISSINGS} ${#aur_missing[@]}"
  if (( ${#aur_found[@]} )); then
    echo "${INSTALL_CHECK_INST_LIST} ${aur_found[*]}"
  fi
  if (( ${#aur_missing[@]} )); then
    echo "${INSTALL_CHECK_MISS_LIST} ${aur_missing[*]}"
  fi

  echo "  ${INSTALL_CHECK_GIT} $(( ${#git_found[@]} + ${#git_missing[@]} ))${INSTALL_CHECK_INSTALLEDS} ${#git_found[@]}${INSTALL_CHECK_MISSINGS} ${#git_missing[@]}"
  if (( ${#git_found[@]} )); then
    echo "${INSTALL_CHECK_INST_LIST} ${git_found[*]}"
  fi
  if (( ${#git_missing[@]} )); then
    for gm in "${git_missing[@]}"; do
      name="${gm%%:*}"
      url="${gm#*:}"
      echo "${INSTALL_CHECK_MISS_ITEM} ${name} (${url})"
    done
  fi

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


main_menu() {
  while true; do
    clear
    # Affichage du banner en violet
    echo -e "${C_ACCENT2}"
    if [[ -f "$BANNER_FILE" ]]; then
      cat "$BANNER_FILE"
    else
      echo "${INSTALL_BANNER_FALLBACK}"
    fi
    echo -e "${C_RESET}"
    echo ""
    
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    printf "                ${C_GOOD}${INSTALL_MENU_TITLE}${C_RESET}                  \n" "${VERSION}"
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${INSTALL_SECTION_INSTALL}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${INSTALL_MENU_1}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${INSTALL_MENU_2}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${INSTALL_MENU_3}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${INSTALL_MENU_4}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}5)${C_RESET} ${C_INFO}${INSTALL_MENU_5}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}6)${C_RESET} ${C_INFO}${INSTALL_MENU_6}${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${INSTALL_SECTION_UNINSTALL}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}7)${C_RESET} ${C_INFO}${INSTALL_MENU_7}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}8)${C_RESET} ${C_INFO}${INSTALL_MENU_8}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}9)${C_RESET} ${C_INFO}${INSTALL_MENU_9}${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${INSTALL_SECTION_OTHER}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}10)${C_RESET} ${C_INFO}${INSTALL_MENU_10}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}11)${C_RESET} ${C_INFO}${INSTALL_MENU_11}${C_RESET}"
    echo ""
    echo -e "   ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${INSTALL_MENU_0}${C_RESET}"
    echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
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
        check_installed_tools
        echo ""
        echo -ne "${C_ACCENT1}${INSTALL_PRESS_ENTER}${C_RESET}"
        read -r
        ;;
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
    esc=${esc//"/\\"}
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
    esc_name=${name//"/\\"}
    esc_url=${url//"/\\"}
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
if [[ "${1:-}" == "--check-tools-json" ]]; then
  check_installed_tools_json
  exit $?
fi
# permettre le sourcing non-interactif pour le débogage : définir NO_MAIN_MENU=1 pour
# ignorer le menu
if [[ -z "${NO_MAIN_MENU:-}" ]]; then
  main_menu
fi
