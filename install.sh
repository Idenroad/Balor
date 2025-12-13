#!/usr/bin/env bash
set -e

BALOR_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Version de l'installateur (lit VERSION si présent)
VERSION="${VERSION:-$(tr -d ' \n\r\t' < "$BALOR_ROOT/VERSION" 2>/dev/null || echo 'unknown')}"

# shellcheck source=lib/common.sh
source "$BALOR_ROOT/lib/common.sh"

STACKS_DIR="$BALOR_ROOT/stacks"
BANNER_FILE="$BALOR_ROOT/banner.txt"
BALOR_OPT_ROOT="${BALOR_OPT_ROOT:-/opt/balorsh}"
BALOR_BIN_PATH="${BALOR_BIN_PATH:-/usr/local/bin/balorsh}"
BALOR_WRAPPER_SRC="$BALOR_ROOT/balorsh"

# Affichage du banner Idenroad / Balor
echo
if [[ -f "$BANNER_FILE" ]]; then
  cat "$BANNER_FILE"
else
  echo "Balor – Powered by Idenroad"
fi
echo
echo "$INSTALL_HAVE_FUN"
echo "$INSTALL_BANNER_TITLE"
echo

list_stacks() {
  find "$STACKS_DIR" -maxdepth 1 -mindepth 1 -type d -printf '%f\n' | sort
}

install_stack() {
  local stack="$1"
  local script="$STACKS_DIR/$stack/install.sh"
  if [[ -x "$script" ]]; then
    bash "$script"
  else
    printf "$INSTALL_SCRIPT_NOT_FOUND\n" "$stack"
  fi
}

uninstall_stack() {
  local stack="$1"
  local script="$STACKS_DIR/$stack/uninstall.sh"
  if [[ -x "$script" ]]; then
    bash "$script"
  else
    printf "$UNINSTALL_SCRIPT_NOT_FOUND\n" "$stack"
  fi
}

menu_install_specific() {
  echo "=== Installer une stack spécifique ==="
  echo "Stacks disponibles :"
  local i=1
  local stacks=()
  while IFS= read -r s; do
    stacks+=("$s")
    echo "  $i) $s"
    ((i++))
  done < <(list_stacks)

  echo "  0) Retour"
  read -rp "Choix: " choice

  if [[ "$choice" == "0" ]]; then
    return
  fi

  local idx=$((choice-1))
  local sel="${stacks[$idx]}"

  if [[ -n "$sel" ]]; then
    install_stack "$sel"
  else
    echo "[!] Choix invalide."
  fi
}

menu_uninstall() {
  echo "=== Désinstaller une stack ==="
  echo "Stacks disponibles :"
  local i=1
  local stacks=()
  while IFS= read -r s; do
    stacks+=("$s")
    echo "  $i) $s"
    ((i++))
  done < <(list_stacks)

  echo "  0) Retour"
  read -rp "Choix: " choice

  if [[ "$choice" == "0" ]]; then
    return
  fi

  local idx=$((choice-1))
  local sel="${stacks[$idx]}"

  if [[ -n "$sel" ]]; then
    uninstall_stack "$sel"
  else
    echo "[!] Choix invalide."
  fi
}

install_all() {
  echo "=== Installation de TOUTES les stacks ==="
  while IFS= read -r s; do
    echo "[Balor] Installation stack: $s"
    install_stack "$s"
  done < <(list_stacks)
  echo "[Balor] Installation complète terminée."
}

update_all() {
  echo "=== Mise à jour système + AUR ==="
  echo "[Balor] pacman -Syu..."
  sudo pacman -Syu --noconfirm

  if have_paru; then
    echo "[Balor] Mise à jour AUR via paru..."
    paru -Syu --noconfirm
  else
    echo "[Balor] paru non présent, pas de mise à jour AUR."
  fi

  echo
  echo "[NOTE] Si tu modifies packages.txt, relance l'install de la stack concernée."
}

install_balorsh_wrapper() {
  echo "=== Installation / Mise à jour du wrapper balorsh ==="

  if [[ ! -f "$BALOR_WRAPPER_SRC" ]]; then
    echo "[!] Wrapper introuvable: $BALOR_WRAPPER_SRC"
    echo "    (attendu: un fichier 'balorsh' à la racine du projet)"
    return 1
  fi

  # Vérifier et installer rsync si absent
  if ! command -v rsync >/dev/null 2>&1; then
    echo "[Balor] rsync n'est pas installé. Installation en cours..."
    sudo pacman -S --needed --noconfirm rsync || {
      echo "[!] Échec de l'installation de rsync."
      return 1
    }
    echo "[Balor] rsync installé avec succès."
  fi

  echo "[Balor] Préparation: $BALOR_OPT_ROOT"
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

  echo "[Balor] Synchronisation du framework (lib/, stacks/, VERSION, banner, wrapper)..."

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

  # S'assurer que tous les scripts dans /opt/balorsh/stacks ont les bonnes permissions
  echo "[Balor] Application des permissions exécutables aux scripts..."
  sudo find "$BALOR_OPT_ROOT/stacks" -type f -name "*.sh" -exec chmod +x {} \;
  
  echo "[Balor] Installation du binaire: $BALOR_BIN_PATH"
  sudo install -m 0755 "$BALOR_OPT_ROOT/balorsh" "$BALOR_BIN_PATH"

  echo "[Balor] OK. Version:"
  "$BALOR_BIN_PATH" --version || true

  echo "[Balor] Quick verification:"
  if [[ -d "$BALOR_OPT_ROOT/stacks" ]]; then
    echo "  Stacks copiées:"
    ls -1 "$BALOR_OPT_ROOT/stacks" | head -n 20 || true
  else
    echo "  [!] Dossier stacks introuvable dans $BALOR_OPT_ROOT"
  fi
  
  echo "  Lib i18n:"
  if [[ -f "$BALOR_OPT_ROOT/lib/i18n.sh" ]]; then
    echo "    ✓ i18n.sh présent"
  else
    echo "    ✗ i18n.sh manquant"
  fi
  
  if [[ -d "$BALOR_OPT_ROOT/lib/lang" ]]; then
    echo "    ✓ lib/lang/ présent"
    ls -1 "$BALOR_OPT_ROOT/lib/lang" | sed 's/^/      - /' || true
  else
    echo "    ✗ lib/lang/ manquant"
  fi
}

uninstall_balorsh_wrapper() {
  echo "=== Désinstallation du wrapper balorsh ==="

  echo "[Balor] Suppression du binaire: $BALOR_BIN_PATH"
  sudo rm -f "$BALOR_BIN_PATH"

  echo "[Balor] Suppression du framework: $BALOR_OPT_ROOT"
  sudo rm -rf "$BALOR_OPT_ROOT"

  echo "[Balor] Wrapper supprimé."
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
  echo "=== Checking tools listed in the stacks ==="

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
  echo "Résumé :"
  echo "  Outils attendus : $total_expected"
  echo "  Installés       : $installed_count"
  echo "  Manquants       : $((total_expected - installed_count))"
  echo

  echo "Détails par type :"
  echo "  pacman - attendus: $(( ${#pacman_found[@]} + ${#pacman_missing[@]} ))  installés: ${#pacman_found[@]}  manquants: ${#pacman_missing[@]}"
  if (( ${#pacman_found[@]} )); then
    echo "    Installés: ${pacman_found[*]}"
  fi
  if (( ${#pacman_missing[@]} )); then
    echo "    Manquants: ${pacman_missing[*]}"
  fi

  echo "  aur    - attendus: $(( ${#aur_found[@]} + ${#aur_missing[@]} ))  installés: ${#aur_found[@]}  manquants: ${#aur_missing[@]}"
  if (( ${#aur_found[@]} )); then
    echo "    Installés: ${aur_found[*]}"
  fi
  if (( ${#aur_missing[@]} )); then
    echo "    Manquants: ${aur_missing[*]}"
  fi

  echo "  git    - attendus: $(( ${#git_found[@]} + ${#git_missing[@]} ))  installés: ${#git_found[@]}  manquants: ${#git_missing[@]}"
  if (( ${#git_found[@]} )); then
    echo "    Installés: ${git_found[*]}"
  fi
  if (( ${#git_missing[@]} )); then
    for gm in "${git_missing[@]}"; do
      name="${gm%%:*}"
      url="${gm#*:}"
      echo "    Manquant: ${name} (${url})"
    done
  fi

  echo
  echo "Conseils :"
  echo "  - Pour installer les paquets manquants (officiels) : sudo pacman -S <paquet>"
  echo "  - Pour les paquets AUR listés explicitement dans scripts : installe via paru ou manuellement"
  echo "  - Pour les repos git manquants : vérifie le script d'installation de la stack concernée (stacks/*/install.sh)"
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
    echo
    echo "==== Balor ${VERSION} - Hacker RPG IRL ===="
    echo "1) Installer TOUTES les stacks"
    echo "2) Installer une stack"
    echo "3) Désinstaller une stack"
    echo "4) Mettre à jour (système + AUR)"
    echo "5) Installer/Mettre à jour le wrapper balorsh"
    echo "6) Désinstaller le wrapper balorsh"
    echo "7) Vérifier l'état des outils listés (paquets/git)"
    echo "8) Quitter"
    read -rp "Choix: " choice

    case "$choice" in
      1) install_all ;;
      2) menu_install_specific ;;
      3) menu_uninstall ;;
      4) update_all ;;
      5) install_balorsh_wrapper ;;
      6) uninstall_balorsh_wrapper ;;
      7) check_installed_tools ;;
      8) echo "[Idenroad] Bye."; exit 0 ;;
      *) echo "[!] Choix invalide." ;;
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
