#!/usr/bin/env bash
set -Eeuo pipefail

# stacks/password/commands.sh
# Menu Password Stack complet pour balorsh

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
WORDLISTS_DIR="/usr/share/wordlists"

# ==============================================================================
# FONCTIONS D'IDENTIFICATION DE HASH
# ==============================================================================

# Identifier un type de hash avec hashid
password_identify_hash() {
  echo -e "${C_HIGHLIGHT}${PASSWORD_MENU_1}${C_RESET}"
  echo ""
  echo "${PASSWORD_CHOOSE_OPTION}:"
  echo "  1) ${PASSWORD_IDENTIFY_SINGLE}"
  echo "  2) ${PASSWORD_IDENTIFY_FILE}"
  echo ""
  echo -ne "${C_ACCENT1}${BALORSH_CHOICE} [1]: ${C_RESET}"
  read -r choice
  choice="${choice:-1}"
  
  local outdir="$BALORSH_DATA_DIR/password/hashid"
  mkdir -p "$outdir"
  local outfile="$outdir/identify_$(date +%Y%m%d_%H%M%S).txt"
  
  case "$choice" in
    1)
      echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_HASH}: ${C_RESET}"
      read -r hash
      if [[ -z "$hash" ]]; then
        echo -e "${C_RED}${PASSWORD_NO_HASH}${C_RESET}"
        return 1
      fi
      echo ""
      echo -e "${C_HIGHLIGHT}${NETSCAN_SCANNING}${C_RESET}"
      {
        echo "${PASSWORD_HEADER_HASH_ID}"
        echo "${PASSWORD_LABEL_DATE} $(date)"
        echo "${PASSWORD_LABEL_HASH} $hash"
        echo ""
        hashid "$hash"
      } | tee "$outfile"
      ;;
    2)
      echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_HASHFILE}: ${C_RESET}"
      read -r hashfile
      if [[ ! -f "$hashfile" ]]; then
        echo -e "${C_RED}${PASSWORD_FILE_NOT_FOUND}: $hashfile${C_RESET}"
        return 1
      fi
      echo ""
      echo -e "${C_HIGHLIGHT}${NETSCAN_SCANNING}${C_RESET}"
      {
        echo "${PASSWORD_HEADER_HASHES_ID}"
        echo "${PASSWORD_LABEL_DATE} $(date)"
        echo "${PASSWORD_LABEL_SOURCE_FILE} $hashfile"
        echo ""
        hashid -m "$hashfile"
      } | tee "$outfile"
      ;;
    *)
      echo -e "${C_RED}${PASSWORD_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac
  
  echo ""
  echo -e "${C_GOOD}${PASSWORD_RESULTS_SAVED}: $outfile${C_RESET}"
}

# ==============================================================================
# FONCTIONS DE GESTION DES WORDLISTS
# ==============================================================================

# Lister les wordlists disponibles
password_list_wordlists() {
  echo -e "${C_HIGHLIGHT}${PASSWORD_WORDLIST_EXPLORER}${C_RESET}"
  echo ""
  
  if [[ ! -d "$WORDLISTS_DIR" ]]; then
    echo -e "${C_RED}${PASSWORD_WORDLISTS_DIR_NOT_FOUND//%s/$WORDLISTS_DIR}${C_RESET}"
    echo -e "${C_INFO}${PASSWORD_INSTALL_WORDLISTS_AUR}${C_RESET}"
    return 1
  fi

  local current_dir="$WORDLISTS_DIR"
  
  while true; do
    clear
    echo -e "${C_HIGHLIGHT}${PASSWORD_WORDLIST_EXPLORER}${C_RESET}"
    echo ""
    echo -e "${C_ACCENT1}${PASSWORD_CURRENT_PATH} ${current_dir}${C_RESET}"
    echo ""
    
    # Lister les sous-répertoires avec stats
    echo -e "${C_GOOD}=== ${PASSWORD_SUBDIRS} ===${C_RESET}"
    local index=1
    declare -A dir_map
    
    while IFS= read -r dir; do
      local dirname=$(basename "$dir")
      local filecount=$(find "$dir" -type f 2>/dev/null | wc -l)
      local dirsize=$(du -sh "$dir" 2>/dev/null | cut -f1)
      echo -e "${C_ACCENT1}  $index) 📁 $dirname${C_RESET} - ${C_SHADOW}$filecount fichiers, $dirsize${C_RESET}"
      dir_map[$index]="$dir"
      ((index++))
    done < <(find "$current_dir" -maxdepth 1 -type d ! -path "$current_dir" 2>/dev/null | sort)
    
    # Lister les fichiers
    echo ""
    echo -e "${C_INFO}=== ${PASSWORD_FILES_HERE} ===${C_RESET}"
    local file_index=$index
    declare -A file_map
    
    while IFS= read -r file; do
      local filename=$(basename "$file")
      local filesize=$(du -h "$file" 2>/dev/null | cut -f1)
      local linecount=$(wc -l < "$file" 2>/dev/null)
      echo -e "${C_INFO}  $file_index) 📄 $filename${C_RESET} - ${C_SHADOW}$filesize, $linecount lignes${C_RESET}"
      file_map[$file_index]="$file"
      ((file_index++))
    done < <(find "$current_dir" -maxdepth 1 -type f \( -name "*.txt" -o -name "*.lst" \) 2>/dev/null | sort | head -30)
    
    # Menu de navigation
    echo ""
    echo -e "${C_YELLOW}=== ${PASSWORD_NAVIGATION} ===${C_RESET}"
    if [[ "$current_dir" != "$WORDLISTS_DIR" ]]; then
      echo -e "  ${C_YELLOW}0) ⬆️  ${PASSWORD_GO_UP}${C_RESET}"
    fi
    echo -e "  ${C_YELLOW}r) 🏠 ${PASSWORD_RETURN_ROOT}${C_RESET}"
    echo -e "  ${C_YELLOW}q) ❌ ${PASSWORD_QUIT_EXPLORER}${C_RESET}"
    echo ""
    echo -ne "${C_ACCENT1}${PASSWORD_CHOICE_PROMPT} ${C_RESET}"
    read -r choice
    
    case "$choice" in
      q)
        break
        ;;
      0)
        if [[ "$current_dir" != "$WORDLISTS_DIR" ]]; then
          current_dir=$(dirname "$current_dir")
        fi
        ;;
      r)
        current_dir="$WORDLISTS_DIR"
        ;;
      *)
        if [[ -n "${dir_map[$choice]}" ]]; then
          current_dir="${dir_map[$choice]}"
        elif [[ -n "${file_map[$choice]}" ]]; then
          echo ""
          echo -e "${C_INFO}${PASSWORD_FILE_SELECTED} ${file_map[$choice]}${C_RESET}"
          echo ""
          read -p "Appuyez sur Entrée pour continuer..." 
        else
          echo -e "${C_RED}${PASSWORD_INVALID_CHOICE}${C_RESET}"
          sleep 1
        fi
        ;;
    esac
  done
}

# Sélectionner une wordlist
password_select_wordlist() {
  local selected=""

  echo -e "${C_HIGHLIGHT}${PASSWORD_WORDLIST_SELECTION}${C_RESET}" >&2
  echo "" >&2
  echo "${PASSWORD_OPTIONS_COMMON}" >&2
  printf "  1) ${PASSWORD_OPT_ROCKYOU}\n" >&2
  printf "  2) ${PASSWORD_OPT_BROWSE}\n" "$WORDLISTS_DIR" >&2
  echo "  3) ${PASSWORD_OPT_CUSTOM_FILE}" >&2
  echo "" >&2
  echo -ne "${C_ACCENT1}Choix [1]: ${C_RESET}" >&2
  read -r choice
  choice="${choice:-1}"
  
  case "$choice" in
    1)
      selected="$WORDLISTS_DIR/seclists/Passwords/Leaked-Databases/rockyou.txt"
      if [[ ! -f "$selected" ]]; then
        echo -e "${C_RED}${PASSWORD_ROCKYOU_NOT_FOUND}${C_RESET}" >&2
        echo -e "${C_INFO}${PASSWORD_INSTALL_WORDLISTS}${C_RESET}" >&2
        return 1
      fi
      ;;
    2)
      # Explorateur de répertoires de wordlists
      echo -e "${C_INFO}${PASSWORD_WORDLIST_EXPLORER}${C_RESET}" >&2
      echo "" >&2
      
      # Fonction pour afficher un répertoire avec ses stats
      local browse_dir="$WORDLISTS_DIR"
      local indent=""
      
      while true; do
        echo -e "${C_HIGHLIGHT}${PASSWORD_CURRENT_PATH} ${browse_dir/${WORDLISTS_DIR}\//}${C_RESET}" >&2
        echo "" >&2
        
        # Lister les sous-répertoires avec nombre de fichiers
        local dir_index=1
        declare -A dir_map
        
        # Répertoires directs
        while IFS= read -r dir; do
          local dirname=$(basename "$dir")
          local filecount=$(find "$dir" -type f \( -name "*.txt" -o -name "*.lst" \) 2>/dev/null | wc -l)
          echo -e "${C_ACCENT1}  $dir_index) 📁 $dirname${C_RESET} ${C_SHADOW}($filecount fichiers)${C_RESET}" >&2
          dir_map[$dir_index]="$dir"
          ((dir_index++))
        done < <(find "$browse_dir" -maxdepth 1 -type d ! -path "$browse_dir" 2>/dev/null | sort)
        
        # Fichiers dans le répertoire courant
        local file_index=$dir_index
        declare -A file_map
        echo "" >&2
        echo -e "${C_INFO}${PASSWORD_FILES_HERE}${C_RESET}" >&2
        while IFS= read -r file; do
          local filename=$(basename "$file")
          local filesize=$(du -h "$file" 2>/dev/null | cut -f1)
          echo -e "${C_GOOD}  $file_index) 📄 $filename${C_RESET} ${C_SHADOW}($filesize)${C_RESET}" >&2
          file_map[$file_index]="$file"
          ((file_index++))
        done < <(find "$browse_dir" -maxdepth 1 -type f \( -name "*.txt" -o -name "*.lst" \) 2>/dev/null | sort)
        
        echo "" >&2
        if [[ "$browse_dir" != "$WORDLISTS_DIR" ]]; then
          echo -e "  ${C_YELLOW}0) ${PASSWORD_GO_UP}${C_RESET}" >&2
        fi
        echo -e "  ${C_YELLOW}c) ${PASSWORD_WORDLIST_CUSTOM_PATH}${C_RESET}" >&2
        echo -e "  ${C_YELLOW}q) ${PASSWORD_QUIT_EXPLORER}${C_RESET}" >&2
        echo "" >&2
        echo -ne "${C_ACCENT1}${PASSWORD_CHOOSE_OPTION}: ${C_RESET}" >&2
        read -r browse_choice
        
        case "$browse_choice" in
          q)
            return 1
            ;;
          0)
            browse_dir=$(dirname "$browse_dir")
            ;;
          c)
            echo -ne "${C_ACCENT1}${PASSWORD_OPT_CUSTOM_FILE} ${C_RESET}" >&2
            read -r selected
            break
            ;;
          *)
            if [[ -n "${dir_map[$browse_choice]:-}" ]]; then
              browse_dir="${dir_map[$browse_choice]}"
            elif [[ -n "${file_map[$browse_choice]:-}" ]]; then
              selected="${file_map[$browse_choice]}"
              break
            else
              echo -e "${C_RED}${PASSWORD_INVALID_CHOICE}${C_RESET}" >&2
            fi
            ;;
        esac
      done
      ;;
    3)
      echo -ne "${C_ACCENT1}${PASSWORD_OPT_CUSTOM_FILE} ${C_RESET}" >&2
      read -r selected
      ;;
    *)
      # Si ce n'est pas 1, 2 ou 3, considérer que c'est un chemin direct
      selected="$choice"
      ;;
  esac
  
  # Validation finale du fichier
  if [[ -z "$selected" ]]; then
    echo -e "${C_RED}${PASSWORD_NO_FILE_SELECTED}${C_RESET}" >&2
    return 1
  fi
  
  if [[ ! -f "$selected" ]]; then
    echo -e "${C_RED}${PASSWORD_FILE_NOT_FOUND_PREFIX} $selected${C_RESET}" >&2
    return 1
  fi
  
  echo "$selected"
}

# ==============================================================================
# FONCTIONS DE CRACKING HASHCAT
# ==============================================================================

# Crack avec hashcat
password_hashcat_crack() {
  echo -e "${C_HIGHLIGHT}${PASSWORD_HASHCAT_TITLE}${C_RESET}"
  echo ""

  # Sélection du fichier de hash
  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_HASHFILE} ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}${PASSWORD_FILE_NOT_FOUND_PREFIX} $hashfile${C_RESET}"
    return 1
  fi
  
  # Sélection du type de hash
  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_HASHCAT_MODES_TITLE}${C_RESET}"
  echo "  ${PASSWORD_MODE_MD5}"
  echo "  ${PASSWORD_MODE_SHA1}"
  echo "  ${PASSWORD_MODE_NTLM}"
  echo "  ${PASSWORD_MODE_SHA256}"
  echo "  ${PASSWORD_MODE_SHA512}"
  echo "  ${PASSWORD_MODE_BCRYPT}"
  echo "  ${PASSWORD_MODE_NETNTLM}"
  echo "  ${PASSWORD_MODE_WPA}"
  echo ""
  echo -e "${C_INFO}${PASSWORD_HASHCAT_HELP}${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_MODE} ${C_RESET}"
  read -r mode

  if [[ -z "$mode" ]]; then
    echo -e "${C_RED}${PASSWORD_MODE_REQUIRED}${C_RESET}"
    return 1
  fi
  
  # Sélection de la wordlist
  echo ""
  local wordlist
  wordlist=$(password_select_wordlist) || return 1
  
  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_HASHCAT_STARTING}${C_RESET}"
  echo -e "${C_INFO}${PASSWORD_LABEL_MODE} $mode${C_RESET}"
  echo -e "${C_INFO}${PASSWORD_LABEL_HASHES} $hashfile${C_RESET}"
  echo -e "${C_INFO}${PASSWORD_LABEL_WORDLIST} $wordlist${C_RESET}"
  echo ""
  
  # Préparation du log
  local outdir="$BALORSH_DATA_DIR/password/hashcat"
  mkdir -p "$outdir"
  local logfile="$outdir/session_$(date +%Y%m%d_%H%M%S).txt"
  
  {
    echo "${PASSWORD_HEADER_SESSION_DICT}"
    echo "${PASSWORD_LABEL_DATE} $(date)"
    echo "${PASSWORD_LABEL_MODE} $mode"
    echo "${PASSWORD_LABEL_HASHFILE} $hashfile"
    echo "${PASSWORD_LABEL_WORDLIST} $wordlist"
    echo ""
    echo "${PASSWORD_HEADER_STARTING}"
  } > "$logfile"
  
  # Lancement hashcat avec affichage en temps réel
  echo -e "${C_INFO}${PASSWORD_HASHCAT_RUNNING}${C_RESET}"
  echo -e "${C_SHADOW}${PASSWORD_HASHCAT_CONTROLS}${C_RESET}"
  echo ""
  
  hashcat -m "$mode" -a 0 "$hashfile" "$wordlist" --status --status-timer=10 2>&1 | tee -a "$logfile"
  
  local hashcat_status=$?
  
  # Résultats
  {
    echo ""
    echo "${PASSWORD_HEADER_RESULTS}"
    hashcat -m "$mode" "$hashfile" --show 2>/dev/null || echo "${PASSWORD_NO_HASH_CRACKED}"
    echo ""
    echo "${PASSWORD_LABEL_SESSION_END} $(date)"
  } >> "$logfile"
  
  echo ""
  if [[ $hashcat_status -eq 0 ]]; then
    echo -e "${C_GOOD}${PASSWORD_CRACK_COMPLETE}${C_RESET}"
  else
    printf "${C_YELLOW}${PASSWORD_HASHCAT_STOPPED}${C_RESET}\n" "$hashcat_status"
  fi
  printf "${C_INFO}${PASSWORD_HASHCAT_SHOW_RESULTS}${C_RESET}\n" "$mode" "$hashfile"
  echo -e "${C_GOOD}${PASSWORD_RESULTS_SAVED} $logfile${C_RESET}"
}

# Hashcat avec règles
password_hashcat_rules() {
  echo -e "${C_HIGHLIGHT}${PASSWORD_HASHCAT_RULES_TITLE}${C_RESET}"
  echo ""
  
  # Sélection du fichier de hash
  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_HASHFILE} ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}${PASSWORD_FILE_NOT_FOUND_PREFIX} $hashfile${C_RESET}"
    return 1
  fi
  
  # Sélection du type de hash
  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_MODE} ${C_RESET}"
  read -r mode

  # Sélection de la wordlist
  echo ""
  local wordlist
  wordlist=$(password_select_wordlist) || return 1
  
  # Sélection des règles
  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_RULES_OPTIONS}${C_RESET}"
  echo "  1) ${PASSWORD_RULE_BEST64}"
  echo "  2) ${PASSWORD_RULE_ROCKYOU}"
  echo "  3) ${PASSWORD_RULE_DIVE}"
  echo "  4) ${PASSWORD_RULE_CUSTOM}"
  echo ""
  echo -ne "${C_ACCENT1}Choix [1]: ${C_RESET}"
  read -r rchoice
  rchoice="${rchoice:-1}"
  
  local rulefile=""
  case "$rchoice" in
    1) rulefile="/usr/share/doc/hashcat/rules/best66.rule" ;;
    2) rulefile="/usr/share/doc/hashcat/rules/rockyou-30000.rule" ;;
    3) rulefile="/usr/share/doc/hashcat/rules/dive.rule" ;;
    4)
      echo -ne "${C_ACCENT1}${PASSWORD_RULES_PATH_PROMPT} ${C_RESET}"
      read -r rulefile
      ;;
    *)
      echo -e "${C_RED}${PASSWORD_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac
  
  if [[ ! -f "$rulefile" ]]; then
    echo -e "${C_RED}${PASSWORD_RULES_FILE_NOT_FOUND} $rulefile${C_RESET}"
    return 1
  fi

  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_RULES_STARTING}${C_RESET}"
  echo -e "${C_INFO}${PASSWORD_RULES_LABEL} $(basename "$rulefile")${C_RESET}"
  
  # Préparation du log
  local outdir="$BALORSH_DATA_DIR/password/hashcat"
  mkdir -p "$outdir"
  local logfile="$outdir/rules_$(date +%Y%m%d_%H%M%S).txt"
  
  {
    echo "${PASSWORD_HEADER_SESSION_RULES}"
    echo "${PASSWORD_LABEL_DATE} $(date)"
    echo "${PASSWORD_LABEL_MODE} $mode"
    echo "${PASSWORD_LABEL_HASHFILE} $hashfile"
    echo "${PASSWORD_LABEL_WORDLIST} $wordlist"
    echo "${PASSWORD_LABEL_RULES} $rulefile"
    echo ""
    echo "${PASSWORD_HEADER_STARTING}"
  } > "$logfile"
  
  hashcat -m "$mode" -a 0 "$hashfile" "$wordlist" -r "$rulefile" --status --status-timer=10 2>&1 | tee -a "$logfile"
  
  {
    echo ""
    echo "${PASSWORD_HEADER_RESULTS}"
    hashcat -m "$mode" "$hashfile" --show 2>/dev/null || echo "${PASSWORD_NO_HASH_CRACKED}"
    echo ""
    echo "${PASSWORD_LABEL_SESSION_END} $(date)"
  } >> "$logfile"

  echo ""
  echo -e "${C_GOOD}${PASSWORD_CRACK_COMPLETE}${C_RESET}"
  echo -e "${C_GOOD}${PASSWORD_RESULTS_SAVED} $logfile${C_RESET}"
}

# Hashcat bruteforce (masque)
password_hashcat_mask() {
  echo -e "${C_HIGHLIGHT}${PASSWORD_MASK_ATTACK_TITLE}${C_RESET}"
  echo ""

  # Sélection du fichier de hash
  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_HASHFILE} ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}${PASSWORD_FILE_NOT_FOUND}: $hashfile${C_RESET}"
    return 1
  fi

  # Sélection du type de hash
  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_MODE} ${C_RESET}"
  read -r mode
  
  # Explication des masques
  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_MASK_TITLE}${C_RESET}"
  echo "  ${PASSWORD_MASK_LOWER}"
  echo "  ${PASSWORD_MASK_UPPER}"
  echo "  ${PASSWORD_MASK_DIGIT}"
  echo "  ${PASSWORD_MASK_SPECIAL}"
  echo "  ${PASSWORD_MASK_ALL}"
  echo ""
  echo -e "${C_INFO}${PASSWORD_EXAMPLES}${C_RESET}"
  echo "  ${PASSWORD_EXAMPLE_1}"
  echo "  ${PASSWORD_EXAMPLE_2}"
  echo "  ${PASSWORD_EXAMPLE_3}"
  echo ""

  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_MASK} ${C_RESET}"
  read -r mask
  
  if [[ -z "$mask" ]]; then
    echo -e "${C_RED}${PASSWORD_MASK_REQUIRED}${C_RESET}"
    return 1
  fi

  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_BRUTEFORCE_STARTING}${C_RESET}"
  echo -e "${C_INFO}${PASSWORD_MASK_LABEL} $mask${C_RESET}"
  echo -e "${C_YELLOW}${PASSWORD_WARNING_LONG}${C_RESET}"
  
  # Préparation du log
  local outdir="$BALORSH_DATA_DIR/password/hashcat"
  mkdir -p "$outdir"
  local logfile="$outdir/mask_$(date +%Y%m%d_%H%M%S).txt"
  
  {
    echo "${PASSWORD_HEADER_SESSION_MASK}"
    echo "${PASSWORD_LABEL_DATE} $(date)"
    echo "${PASSWORD_LABEL_MODE} $mode"
    echo "${PASSWORD_LABEL_HASHFILE} $hashfile"
    echo "${PASSWORD_LABEL_MASK} $mask"
    echo ""
    echo "${PASSWORD_HEADER_STARTING}"
  } > "$logfile"
  
  hashcat -m "$mode" -a 3 "$hashfile" "$mask" --status --status-timer=10 2>&1 | tee -a "$logfile"
  
  {
    echo ""
    echo "${PASSWORD_HEADER_RESULTS}"
    hashcat -m "$mode" "$hashfile" --show 2>/dev/null || echo "${PASSWORD_NO_HASH_CRACKED}"
    echo ""
    echo "${PASSWORD_LABEL_SESSION_END} $(date)"
  } >> "$logfile"

  echo ""
  echo -e "${C_GOOD}${PASSWORD_BRUTEFORCE_COMPLETE}${C_RESET}"
  echo -e "${C_GOOD}${PASSWORD_RESULTS_SAVED} $logfile${C_RESET}"
}

# Afficher les résultats hashcat
password_hashcat_show() {
  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_HASHFILE} ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}${PASSWORD_FILE_NOT_FOUND}: $hashfile${C_RESET}"
    return 1
  fi

  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_MODE} ${C_RESET}"
  read -r mode
  
  local outdir="$BALORSH_DATA_DIR/password/hashcat"
  mkdir -p "$outdir"
  local outfile="$outdir/results_$(date +%Y%m%d_%H%M%S).txt"
  
  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_HASHCAT_SHOW_TITLE}${C_RESET}"

  {
    echo "${PASSWORD_HASHCAT_RESULTS_HEADER}"
    echo "${PASSWORD_LABEL_DATE} $(date)"
    echo "${PASSWORD_LABEL_MODE} $mode"
    echo "${PASSWORD_LABEL_HASHFILE} $hashfile"
    echo ""
    echo "${PASSWORD_HASHCAT_HASHES_CRACKED}"
    hashcat -m "$mode" "$hashfile" --show 2>&1
  } | tee "$outfile"

  echo ""
  echo -e "${C_GOOD}${PASSWORD_RESULTS_SAVED}: $outfile${C_RESET}"
}

# ==============================================================================
# FONCTIONS JOHN THE RIPPER
# ==============================================================================

# Crack avec John
password_john_crack() {
  echo -e "${C_HIGHLIGHT}${PASSWORD_JOHN_TITLE}${C_RESET}"
  echo ""
  
  # Afficher l'aide sur les formats
  echo -e "${C_INFO}${PASSWORD_JOHN_FORMATS_HELP}${C_RESET}"
  echo -e "${C_SHADOW}${PASSWORD_JOHN_FORMAT_EXAMPLES}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_HASHFILE} ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}${PASSWORD_FILE_NOT_FOUND}: $hashfile${C_RESET}"
    return 1
  fi
  
  # Détection automatique du format (John détecte tout seul)
  echo -e "${C_INFO}${PASSWORD_JOHN_AUTO_DETECT}${C_RESET}"
  echo ""

  echo -e "${C_HIGHLIGHT}${PASSWORD_JOHN_ATTACK_MODES}${C_RESET}"
  echo "  1) ${PASSWORD_JOHN_AUTO}"
  echo "  2) ${PASSWORD_JOHN_WORDLIST}"
  echo "  3) ${PASSWORD_JOHN_INCREMENTAL}"
  echo ""
  echo -ne "${C_ACCENT1}${PASSWORD_CHOOSE_OPTION} [1]: ${C_RESET}"
  read -r choice
  choice="${choice:-1}"
  
  local outdir="$BALORSH_DATA_DIR/password/john"
  mkdir -p "$outdir"
  local logfile="$outdir/session_$(date +%Y%m%d_%H%M%S).txt"
  
  case "$choice" in
    1)
      echo -e "${C_HIGHLIGHT}${PASSWORD_JOHN_STARTING_SINGLE}${C_RESET}"
      {
        echo "${PASSWORD_JOHN_HEADER_SINGLE}"
        echo "${PASSWORD_LABEL_DATE} $(date)"
        echo "${PASSWORD_LABEL_HASHFILE} $hashfile"
        echo ""
        john --single "$hashfile" 2>&1
        echo ""
        echo "${PASSWORD_HEADER_RESULTS}"
        john --show "$hashfile" 2>&1
      } | tee "$logfile"
      echo ""
      ;;
    2)
      local wordlist
      wordlist=$(password_select_wordlist) || return 1
      echo ""
      echo -e "${C_HIGHLIGHT}${PASSWORD_JOHN_STARTING_WORDLIST}${C_RESET}"
      {
        echo "${PASSWORD_JOHN_HEADER_WORDLIST}"
        echo "${PASSWORD_LABEL_DATE} $(date)"
        echo "${PASSWORD_LABEL_HASHFILE} $hashfile"
        echo "${PASSWORD_LABEL_WORDLIST} $wordlist"
        echo ""
        john --wordlist="$wordlist" "$hashfile" 2>&1
        echo ""
        echo "${PASSWORD_HEADER_RESULTS}"
        john --show "$hashfile" 2>&1
      } | tee "$logfile"
      echo ""
      ;;
    3)
      echo -e "${C_HIGHLIGHT}${PASSWORD_JOHN_STARTING_INCREMENTAL}${C_RESET}"
      echo -e "${C_YELLOW}${PASSWORD_WARNING_LONG}${C_RESET}"
      {
        echo "${PASSWORD_JOHN_HEADER_INCREMENTAL}"
        echo "${PASSWORD_LABEL_DATE} $(date)"
        echo "${PASSWORD_LABEL_HASHFILE} $hashfile"
        echo ""
        john --incremental "$hashfile" 2>&1
        echo ""
        echo "${PASSWORD_HEADER_RESULTS}"
        john --show "$hashfile" 2>&1
      } | tee "$logfile"
      echo ""
      ;;
    *)
      echo -e "${C_RED}${PASSWORD_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac
  
  echo ""
  echo -e "${C_GOOD}${PASSWORD_JOHN_SHOW_RESULTS} \"$hashfile\"${C_RESET}"
  echo -e "${C_GOOD}${PASSWORD_RESULTS_SAVED} $logfile${C_RESET}"
  echo ""
  read -p "${PASSWORD_PRESS_ENTER}" 
}

# John avec règles
password_john_rules() {
  echo -e "${C_HIGHLIGHT}${PASSWORD_JOHN_RULES_TITLE}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_HASHFILE} ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}${PASSWORD_FILE_NOT_FOUND}: $hashfile${C_RESET}"
    return 1
  fi

  local wordlist
  wordlist=$(password_select_wordlist) || return 1

  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_JOHN_RULES_AVAILABLE}${C_RESET}"
  echo "  1) ${PASSWORD_JOHN_RULE_BEST64}"
  echo "  2) ${PASSWORD_JOHN_RULE_D3AD0NE}"
  echo "  3) ${PASSWORD_JOHN_RULE_DIVE}"
  echo "  4) ${PASSWORD_JOHN_RULE_JUMBO}"
  echo ""
  echo -ne "${C_ACCENT1}${PASSWORD_CHOOSE_OPTION} [1]: ${C_RESET}"
  read -r rchoice
  rchoice="${rchoice:-1}"
  
  local rules=""
  case "$rchoice" in
    1) rules="best64" ;;
    2) rules="d3ad0ne" ;;
    3) rules="dive" ;;
    4) rules="jumbo" ;;
    *)
      echo -e "${C_RED}${PASSWORD_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac

  local outdir="$BALORSH_DATA_DIR/password/john"
  mkdir -p "$outdir"
  local logfile="$outdir/rules_$(date +%Y%m%d_%H%M%S).txt"

  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_JOHN_STARTING_RULES} $rules...${C_RESET}"

  {
    echo "${PASSWORD_JOHN_HEADER_RULES}"
    echo "${PASSWORD_LABEL_DATE} $(date)"
    echo "${PASSWORD_LABEL_HASHFILE} $hashfile"
    echo "${PASSWORD_LABEL_WORDLIST} $wordlist"
    echo "${PASSWORD_LABEL_RULES} $rules"
    echo ""
    john --wordlist="$wordlist" --rules="$rules" "$hashfile" 2>&1
    echo ""
    echo "${PASSWORD_HEADER_RESULTS}"
    john --show "$hashfile" 2>&1
  } | tee "$logfile"

  echo ""
  echo -e "${C_GOOD}${PASSWORD_JOHN_SHOW_RESULTS} \"$hashfile\"${C_RESET}"
  echo -e "${C_GOOD}${PASSWORD_RESULTS_SAVED} $logfile${C_RESET}"
  echo ""
  read -p "${PASSWORD_PRESS_ENTER}" 
}

# Afficher résultats John
password_john_show() {
  echo -ne "${C_ACCENT1}${PASSWORD_PROMPT_HASHFILE} ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}${PASSWORD_FILE_NOT_FOUND}: $hashfile${C_RESET}"
    return 1
  fi
  
  local outdir="$BALORSH_DATA_DIR/password/john"
  mkdir -p "$outdir"
  local outfile="$outdir/results_$(date +%Y%m%d_%H%M%S).txt"
  
  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_HASHCAT_SHOW_TITLE}${C_RESET}"
  
  {
    echo "${PASSWORD_JOHN_RESULTS_TITLE}"
    echo "${PASSWORD_LABEL_DATE} $(date)"
    echo "${PASSWORD_LABEL_HASHFILE} $hashfile"
    echo ""
    echo "${PASSWORD_HASHCAT_HASHES_CRACKED}"
    john --show "$hashfile" 2>&1
  } | tee "$outfile"
  
  echo ""
  echo -e "${C_GOOD}${PASSWORD_RESULTS_SAVED}: $outfile${C_RESET}"
  echo ""
  read -p "${PASSWORD_PRESS_ENTER}" 
}

# ==============================================================================
# FONCTIONS DE GÉNÉRATION DE WORDLISTS
# ==============================================================================

# Générer wordlist avec crunch
password_crunch_generate() {
  echo -e "${C_HIGHLIGHT}${PASSWORD_CRUNCH_TITLE}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${PASSWORD_CRUNCH_MIN_LEN} ${C_RESET}"
  read -r minlen
  echo -ne "${C_ACCENT1}${PASSWORD_CRUNCH_MAX_LEN} ${C_RESET}"
  read -r maxlen

  if ! [[ "$minlen" =~ ^[0-9]+$ ]] || ! [[ "$maxlen" =~ ^[0-9]+$ ]]; then
    echo -e "${C_RED}${PASSWORD_CRUNCH_INVALID_LEN}${C_RESET}"
    return 1
  fi

  if (( minlen > maxlen )); then
    echo -e "${C_RED}${PASSWORD_CRUNCH_MIN_MAX}${C_RESET}"
    return 1
  fi

  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_CRUNCH_CHARSET_TITLE}${C_RESET}"
  echo "  1) ${PASSWORD_CRUNCH_CHARSET_LOWER}"
  echo "  2) ${PASSWORD_CRUNCH_CHARSET_UPPER}"
  echo "  3) ${PASSWORD_CRUNCH_CHARSET_DIGIT}"
  echo "  4) ${PASSWORD_CRUNCH_CHARSET_LOWER_DIGIT}"
  echo "  5) ${PASSWORD_CRUNCH_CHARSET_ALPHA}"
  echo "  6) ${PASSWORD_CRUNCH_CHARSET_ALPHA_SPECIAL}"
  echo "  7) ${PASSWORD_CRUNCH_CHARSET_ALL}"
  echo "  8) ${PASSWORD_CRUNCH_CHARSET_CUSTOM}"
  echo ""
  echo -ne "${C_ACCENT1}${PASSWORD_CHOOSE_OPTION} [4]: ${C_RESET}"
  read -r cchoice
  cchoice="${cchoice:-4}"
  
  local charset=""
  case "$cchoice" in
    1) charset="abcdefghijklmnopqrstuvwxyz" ;;
    2) charset="ABCDEFGHIJKLMNOPQRSTUVWXYZ" ;;
    3) charset="0123456789" ;;
    4) charset="abcdefghijklmnopqrstuvwxyz0123456789" ;;
    5) charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" ;;
    6) charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()" ;;
    7) charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!@#\$%^&*()_+-=[]{}|;:,.<>?/" ;;
    8)
      echo -ne "${C_ACCENT1}${PASSWORD_CRUNCH_CUSTOM_PROMPT} ${C_RESET}"
      read -r charset
      ;;
    *)
      echo -e "${C_RED}${PASSWORD_INVALID_CHOICE}${C_RESET}"
      return 1
      ;;
  esac

  # Fichier de sortie
  local outdir="$BALORSH_DATA_DIR/password/wordlists"
  mkdir -p "$outdir"
  local outfile="$outdir/crunch_${minlen}-${maxlen}_$(date +%Y%m%d_%H%M%S).txt"

  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_CRUNCH_ESTIMATION}${C_RESET}"
  
  # Calcul estimation (simplifié)
  local charcount=${#charset}
  echo -e "${C_INFO}${PASSWORD_CRUNCH_CHARSET_SIZE//%d/$charcount}${C_RESET}"
  echo -e "${C_INFO}${PASSWORD_CRUNCH_LENGTHS//%s/$minlen}${C_RESET}\" | sed \"s/%s/$maxlen/"
  
  echo ""
  echo -e "${C_YELLOW}${PASSWORD_CRUNCH_WARNING}${C_RESET}"
  echo -ne "${C_ACCENT1}${PASSWORD_CRUNCH_CONFIRM} ${C_RESET}"
  read -r confirm
  
  if [[ "${confirm,,}" != "y" ]]; then
    echo "${PASSWORD_CRUNCH_CANCELLED}"
    return 0
  fi

  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_CRUNCH_GENERATING}${C_RESET}"
  echo -e "${C_INFO}${PASSWORD_CRUNCH_OUTPUT} $outfile${C_RESET}"
  crunch "$minlen" "$maxlen" "$charset" -o "$outfile"
  
  echo ""
  echo -e "${C_GOOD}${PASSWORD_WORDLIST_GENERATED}: $outfile${C_RESET}"

  if [[ -f "$outfile" ]]; then
    local size=$(du -sh "$outfile" | awk '{print $1}')
    local lines=$(wc -l < "$outfile")
    echo -e "${C_INFO}${PASSWORD_CRUNCH_SIZE} $size${C_RESET}"
    echo -e "${C_INFO}${PASSWORD_CRUNCH_LINES} $lines${C_RESET}"
  fi
}

# ==============================================================================
# FONCTIONS DE CRACKING RÉSEAU
# ==============================================================================

# Medusa - brute force services réseau
password_medusa_attack() {
  echo -e "${C_HIGHLIGHT}${PASSWORD_MEDUSA_TITLE}${C_RESET}"
  echo ""

  echo -e "${C_HIGHLIGHT}${PASSWORD_MEDUSA_SERVICES}${C_RESET}"
  echo "  ${PASSWORD_MEDUSA_SERVICES_LIST}"
  echo ""

  echo -ne "${C_ACCENT1}${PASSWORD_MEDUSA_TARGET} ${C_RESET}"
  read -r target
  
  echo -ne "${C_ACCENT1}${PASSWORD_MEDUSA_SERVICE} ${C_RESET}"
  read -r service

  echo -ne "${C_ACCENT1}${PASSWORD_MEDUSA_USER_OPT} ${C_RESET}"
  read -r user_input
  
  local user_opt
  if [[ -f "$user_input" ]]; then
    user_opt="-U $user_input"
  else
    user_opt="-u $user_input"
  fi
  
  echo ""
  local wordlist
  wordlist=$(password_select_wordlist) || return 1
  
  local outdir="$BALORSH_DATA_DIR/password/medusa"
  mkdir -p "$outdir"
  local outfile="$outdir/attack_$(date +%Y%m%d_%H%M%S).txt"
  
  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_MEDUSA_STARTING}${C_RESET}"
  echo -e "${C_INFO}${PASSWORD_MEDUSA_TARGET_LABEL} $target${C_RESET}"
  echo -e "${C_INFO}${PASSWORD_MEDUSA_SERVICE_LABEL} $service${C_RESET}"
  echo ""
  
  {
    echo "${PASSWORD_MEDUSA_HEADER}"
    echo "${PASSWORD_LABEL_DATE} $(date)"
    echo "${PASSWORD_MEDUSA_TARGET_LABEL} $target"
    echo "${PASSWORD_MEDUSA_SERVICE_LABEL} $service"
    echo "${PASSWORD_MEDUSA_USER_OPTION} $user_opt"
    echo "${PASSWORD_LABEL_WORDLIST} $wordlist"
    echo ""
    echo "${PASSWORD_HEADER_RESULTS}"
    medusa -h "$target" -M "$service" $user_opt -P "$wordlist" -t 4 -v 4 2>&1
  } | tee "$outfile"
  
  echo ""
  echo -e "${C_GOOD}${PASSWORD_ATTACK_COMPLETE}${C_RESET}"
  echo -e "${C_GOOD}${PASSWORD_RESULTS_SAVED}: $outfile${C_RESET}"
  echo ""
  read -p "${PASSWORD_PRESS_ENTER}" 
}

# Ncrack - network cracker
password_ncrack_attack() {
  echo -e "${C_HIGHLIGHT}${PASSWORD_NCRACK_TITLE}${C_RESET}"
  echo ""
  
  echo -e "${C_INFO}${PASSWORD_NCRACK_CREDS_HELP}${C_RESET}"
  echo ""

  echo -ne "${C_ACCENT1}${PASSWORD_NCRACK_TARGET} ${C_RESET}"
  read -r target
  
  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_NCRACK_CREDS_MODE}${C_RESET}"
  echo "  1) ${PASSWORD_NCRACK_MODE_USER_WORDLIST}"
  echo "  2) ${PASSWORD_NCRACK_MODE_CREDS_FILE}"
  echo ""
  echo -ne "${C_ACCENT1}${PASSWORD_CHOOSE_OPTION} [1]: ${C_RESET}"
  read -r cred_mode
  cred_mode="${cred_mode:-1}"
  
  local ncrack_opts=""
  
  case "$cred_mode" in
    1)
      echo -ne "${C_ACCENT1}${PASSWORD_NCRACK_USERNAME} ${C_RESET}"
      read -r username
      
      echo ""
      local wordlist
      wordlist=$(password_select_wordlist)
      if [[ $? -ne 0 ]]; then
        echo ""
        read -p "${PASSWORD_PRESS_ENTER}" 
        return 1
      fi
      
      ncrack_opts="-u \"$username\" -P \"$wordlist\""
      ;;
    2)
      echo -ne "${C_ACCENT1}${PASSWORD_NCRACK_CREDS_FILE_PROMPT} ${C_RESET}"
      read -r credsfile
      
      if [[ ! -f "$credsfile" ]]; then
        echo -e "${C_RED}${PASSWORD_FILE_NOT_FOUND_PREFIX} $credsfile${C_RESET}"
        echo ""
        read -p "${PASSWORD_PRESS_ENTER}" 
        return 1
      fi
      
      ncrack_opts="-C \"$credsfile\""
      ;;
    *)
      echo -e "${C_RED}${PASSWORD_INVALID_CHOICE}${C_RESET}"
      echo ""
      read -p "${PASSWORD_PRESS_ENTER}" 
      return 1
      ;;
  esac
  
  local outdir="$BALORSH_DATA_DIR/password/ncrack"
  mkdir -p "$outdir"
  local outfile="$outdir/attack_$(date +%Y%m%d_%H%M%S).txt"
  
  echo ""
  echo -e "${C_HIGHLIGHT}${PASSWORD_NCRACK_STARTING}${C_RESET}"

  {
    echo "${PASSWORD_NCRACK_HEADER}"
    echo "${PASSWORD_LABEL_DATE} $(date)"
    echo "${PASSWORD_MEDUSA_TARGET_LABEL} $target"
    if [[ "$cred_mode" == "1" ]]; then
      echo "${PASSWORD_NCRACK_USER_LABEL} $username"
      echo "${PASSWORD_LABEL_WORDLIST} $wordlist"
    else
      echo "${PASSWORD_NCRACK_CREDS_FILE_LABEL} $credsfile"
    fi
    echo ""
    echo "${PASSWORD_HEADER_RESULTS}"
    eval "ncrack $ncrack_opts \"$target\" -v" 2>&1
  } | tee "$outfile"

  echo ""
  echo -e "${C_GOOD}${PASSWORD_SCAN_COMPLETE}${C_RESET}"
  echo -e "${C_GOOD}${PASSWORD_RESULTS_SAVED}: $outfile${C_RESET}"
  echo ""
  read -p "${PASSWORD_PRESS_ENTER}" 
}

# ==============================================================================
# UTILITAIRES
# ==============================================================================

# Nettoyer anciens fichiers
password_cleanup() {
  echo -e "${C_YELLOW}${PASSWORD_CLEANUP_TITLE_SHORT}${C_RESET}"
  echo -ne "${C_ACCENT1}${PASSWORD_CLEANUP_PROMPT_DAYS} ${C_RESET}"
  read -r days
  days="${days:-7}"

  if ! [[ "$days" =~ ^[0-9]+$ ]]; then
    echo -e "${C_RED}${PASSWORD_CLEANUP_INVALID_DAYS}${C_RESET}"
    return 1
  fi
  
  local count=0
  while IFS= read -r -d '' file; do
    rm -f "$file"
    ((count++))
  done < <(find "$BALORSH_DATA_DIR/password" -type f -mtime +"$days" -print0 2>/dev/null)
  
  echo -e "${C_GOOD}${PASSWORD_CLEANUP_FILES_DELETED//%d/$count}${C_RESET}"
}

# Aide
password_help() {
  cat <<EOF
${C_ACCENT1}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}
${C_ACCENT1}║${C_RESET}                   ${C_GOOD}${PASSWORD_HELP_HEADER}${C_RESET}                        ${C_ACCENT1}║${C_RESET}
${C_ACCENT1}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}

${C_HIGHLIGHT}${PASSWORD_HELP_TOOLS_TITLE}${C_RESET}
  • ${PASSWORD_HELP_TOOL_HASHID}
  • ${PASSWORD_HELP_TOOL_HASHCAT}
  • ${PASSWORD_HELP_TOOL_JOHN}
  • ${PASSWORD_HELP_TOOL_CRUNCH}
  • ${PASSWORD_HELP_TOOL_MEDUSA}
  • ${PASSWORD_HELP_TOOL_NCRACK}
  • ${PASSWORD_HELP_TOOL_WORDLISTS}

${C_HIGHLIGHT}${PASSWORD_HELP_WORKFLOW_TITLE}${C_RESET}
  ${PASSWORD_HELP_WORKFLOW_1}
  ${PASSWORD_HELP_WORKFLOW_2}
  ${PASSWORD_HELP_WORKFLOW_3}
  ${PASSWORD_HELP_WORKFLOW_4}

${C_HIGHLIGHT}${PASSWORD_HELP_HASH_TYPES_TITLE}${C_RESET}
  • ${PASSWORD_HELP_HASH_MD5}
  • ${PASSWORD_HELP_HASH_SHA1}
  • ${PASSWORD_HELP_HASH_NTLM}
  • ${PASSWORD_HELP_HASH_BCRYPT}
  • ${PASSWORD_HELP_HASH_WPA}

${C_HIGHLIGHT}${PASSWORD_HELP_WORDLISTS_TITLE}${C_RESET}
  ${PASSWORD_HELP_WORDLISTS_LOCATION} \$WORDLISTS_DIR
  ${PASSWORD_HELP_WORDLISTS_MAIN}
  ${PASSWORD_HELP_WORDLISTS_COLLECTION}

${C_HIGHLIGHT}${PASSWORD_HELP_ATTACKS_TITLE}${C_RESET}
  • ${PASSWORD_HELP_ATTACK_DICT}
  • ${PASSWORD_HELP_ATTACK_RULES}
  • ${PASSWORD_HELP_ATTACK_MASK}

${C_HIGHLIGHT}${PASSWORD_HELP_PERFORMANCE_TITLE}${C_RESET}
  ${PASSWORD_HELP_PERF_HASHCAT}
  ${PASSWORD_HELP_PERF_MD5}
  ${PASSWORD_HELP_PERF_BCRYPT}

${C_HIGHLIGHT}${PASSWORD_HELP_TIPS_TITLE}${C_RESET}
  • ${PASSWORD_HELP_TIP_1}
  • ${PASSWORD_HELP_TIP_2}
  • ${PASSWORD_HELP_TIP_3}
  • ${PASSWORD_HELP_TIP_4}
  • ${PASSWORD_HELP_TIP_5}

${C_HIGHLIGHT}${PASSWORD_HELP_NETWORK_TITLE}${C_RESET}
  ${PASSWORD_HELP_NETWORK_SERVICES}
  ${PASSWORD_HELP_NETWORK_WARNING}

${C_YELLOW}${PASSWORD_HELP_WARNING_TITLE}${C_RESET}
  ${PASSWORD_HELP_WARNING_1}
  ${PASSWORD_HELP_WARNING_2}
  ${PASSWORD_HELP_WARNING_3}
  ${PASSWORD_HELP_WARNING_4}

  ${PASSWORD_HELP_WARNING_5}

${C_HIGHLIGHT}${PASSWORD_HELP_EXAMPLES_TITLE}${C_RESET}
  ${PASSWORD_HELP_EXAMPLE_HASHID}
  ${PASSWORD_HELP_EXAMPLE_HASHCAT}
  ${PASSWORD_HELP_EXAMPLE_JOHN}
  ${PASSWORD_HELP_EXAMPLE_CRUNCH}
  ${PASSWORD_HELP_EXAMPLE_MEDUSA}

EOF
  
  echo -ne "${C_ACCENT1}${PASSWORD_HELP_PRESS_ENTER}${C_RESET}"
  read -r
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================

stack_menu() {
  while true; do
    clear
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "                  ${C_GOOD}${PASSWORD_MENU_TITLE}${C_RESET}                 "
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_IDENTIFICATION}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${PASSWORD_MENU_1}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${PASSWORD_MENU_2}${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_HASHCAT}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${PASSWORD_MENU_3}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${PASSWORD_MENU_4}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}5)${C_RESET} ${C_INFO}${PASSWORD_MENU_5}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}6)${C_RESET} ${C_INFO}${PASSWORD_MENU_6}${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_JOHN}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}7)${C_RESET} ${C_INFO}${PASSWORD_MENU_7}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}8)${C_RESET} ${C_INFO}${PASSWORD_MENU_8}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}9)${C_RESET} ${C_INFO}${PASSWORD_MENU_9}${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_WORDLIST}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}10)${C_RESET} ${C_INFO}${PASSWORD_MENU_10}${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_NETWORK}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}11)${C_RESET} ${C_INFO}${PASSWORD_MENU_11}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}12)${C_RESET} ${C_INFO}${PASSWORD_MENU_12}${C_RESET}"
    echo ""
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_UTILS}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}13)${C_RESET} ${C_INFO}${PASSWORD_MENU_13}${C_RESET}"
    echo -e "   ${C_HIGHLIGHT}14)${C_RESET} ${C_INFO}${PASSWORD_MENU_14}${C_RESET}"
    echo ""
    echo -e "   ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${PASSWORD_MENU_0}${C_RESET}"
    echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
    echo -ne "${C_ACCENT1}${BALORSH_CHOICE}${C_RESET}"
    read -r choice

    case "$choice" in
      1) password_identify_hash ;;
      2) password_list_wordlists ;;
      3) password_hashcat_crack ;;
      4) password_hashcat_rules ;;
      5) password_hashcat_mask ;;
      6) password_hashcat_show ;;
      7) password_john_crack ;;
      8) password_john_rules ;;
      9) password_john_show ;;
      10) password_crunch_generate ;;
      11) password_medusa_attack ;;
      12) password_ncrack_attack ;;
      13) password_cleanup ;;
      14) password_help ;;
      0) echo -e "${C_GOOD}${BALORSH_QUIT}${C_RESET}"; break ;;
      *) echo -e "${C_RED}${PASSWORD_INVALID_CHOICE}${C_RESET}" ;;
    esac
    
    if [[ "$choice" != "0" ]]; then
      echo -e "\n${C_INFO}${PASSWORD_PRESS_ENTER}${C_RESET}"
      read -r
    fi
  done
}

# Point d'entrée principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  stack_menu
fi
