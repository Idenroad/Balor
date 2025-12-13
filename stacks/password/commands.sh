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
        echo "=== Identification de hash - hashid ==="
        echo "Date: $(date)"
        echo "Hash: $hash"
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
        echo "=== Identification de hashes - hashid ==="
        echo "Date: $(date)"
        echo "Fichier source: $hashfile"
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
  echo -e "${C_HIGHLIGHT}Wordlists disponibles:${C_RESET}"
  echo ""
  
  if [[ ! -d "$WORDLISTS_DIR" ]]; then
    echo -e "${C_RED}Répertoire $WORDLISTS_DIR non trouvé${C_RESET}"
    echo -e "${C_INFO}Installez le paquet 'wordlists' depuis l'AUR${C_RESET}"
    return 1
  fi
  
  local outdir="$BALORSH_DATA_DIR/password/inventory"
  mkdir -p "$outdir"
  local outfile="$outdir/wordlists_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_ACCENT1}Répertoire: $WORDLISTS_DIR${C_RESET}"
  echo ""
  
  {
    echo "=== Inventaire des Wordlists ==="
    echo "Date: $(date)"
    echo "Répertoire: $WORDLISTS_DIR"
    echo ""
    echo "=== Contenu ==="
    
    # Affiche la structure avec taille des fichiers
    du -sh "$WORDLISTS_DIR"/* 2>/dev/null | while read -r size path; do
      name=$(basename "$path")
      if [[ -d "$path" ]]; then
        echo "[DIR]  $size\t$name/"
      else
        echo "[FILE] $size\t$name"
      fi
    done
    
    echo ""
    echo "=== Fichiers populaires ==="
    
    # Rockyou
    if [[ -f "$WORDLISTS_DIR/seclists/Passwords/Leaked-Databases/rockyou.txt" ]]; then
      local size=$(du -sh "$WORDLISTS_DIR/seclists/Passwords/Leaked-Databases/rockyou.txt" 2>/dev/null | awk '{print $1}')
      echo "✓ rockyou.txt ($size)"
    fi
    
    # Common passwords
    if [[ -d "$WORDLISTS_DIR/seclists/Passwords" ]]; then
      echo "✓ SecLists Passwords collection"
    fi
    
    echo ""
    echo "=== Liste détaillée des fichiers .txt ==="
    find "$WORDLISTS_DIR" -type f -name "*.txt" 2>/dev/null | head -n 50
    
  } | tee "$outfile"
  
  # Affichage coloré pour le terminal
  echo ""
  du -sh "$WORDLISTS_DIR"/* 2>/dev/null | while read -r size path; do
    name=$(basename "$path")
    if [[ -d "$path" ]]; then
      echo -e "  ${C_GOOD}[DIR]${C_RESET}  $size\t$name/"
    else
      echo -e "  ${C_INFO}[FILE]${C_RESET} $size\t$name"
    fi
  done
  
  echo ""
  echo -e "${C_HIGHLIGHT}Fichiers populaires:${C_RESET}"
  
  if [[ -f "$WORDLISTS_DIR/seclists/Passwords/Leaked-Databases/rockyou.txt" ]]; then
    local size=$(du -sh "$WORDLISTS_DIR/seclists/Passwords/Leaked-Databases/rockyou.txt" 2>/dev/null | awk '{print $1}')
    echo -e "  ✓ rockyou.txt ($size)"
  fi
  
  if [[ -d "$WORDLISTS_DIR/seclists/Passwords" ]]; then
    echo -e "  ✓ SecLists Passwords collection"
  fi
  
  echo ""
  echo -e "${C_GOOD}Inventaire sauvegardé: $outfile${C_RESET}"
}

# Sélectionner une wordlist
password_select_wordlist() {
  local selected=""
  
  echo -e "${C_HIGHLIGHT}Sélection de wordlist${C_RESET}"
  echo ""
  echo "Options communes:"
  echo "  1) rockyou.txt (14M - le plus utilisé)"
  echo "  2) Parcourir $WORDLISTS_DIR"
  echo "  3) Fichier personnalisé"
  echo ""
  echo -ne "${C_ACCENT1}Choix [1]: ${C_RESET}"
  read -r choice
  choice="${choice:-1}"
  
  case "$choice" in
    1)
      selected="$WORDLISTS_DIR/seclists/Passwords/Leaked-Databases/rockyou.txt"
      if [[ ! -f "$selected" ]]; then
        echo -e "${C_RED}rockyou.txt non trouvé${C_RESET}"
        echo -e "${C_INFO}Installez le paquet 'wordlists' depuis l'AUR${C_RESET}"
        return 1
      fi
      ;;
    2)
      echo -e "${C_INFO}Listage des wordlists...${C_RESET}"
      echo ""
      find "$WORDLISTS_DIR" -type f -name "*.txt" 2>/dev/null | head -n 20
      echo ""
      echo -ne "${C_ACCENT1}Chemin complet de la wordlist: ${C_RESET}"
      read -r selected
      ;;
    3)
      echo -ne "${C_ACCENT1}Chemin complet de la wordlist: ${C_RESET}"
      read -r selected
      ;;
    *)
      echo -e "${C_RED}Choix invalide${C_RESET}"
      return 1
      ;;
  esac
  
  if [[ ! -f "$selected" ]]; then
    echo -e "${C_RED}Fichier non trouvé: $selected${C_RESET}"
    return 1
  fi
  
  echo "$selected"
}

# ==============================================================================
# FONCTIONS DE CRACKING HASHCAT
# ==============================================================================

# Crack avec hashcat
password_hashcat_crack() {
  echo -e "${C_HIGHLIGHT}Cracking avec Hashcat${C_RESET}"
  echo ""
  
  # Sélection du fichier de hash
  echo -ne "${C_ACCENT1}Fichier de hashes: ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}Fichier non trouvé: $hashfile${C_RESET}"
    return 1
  fi
  
  # Sélection du type de hash
  echo ""
  echo -e "${C_HIGHLIGHT}Types de hash courants:${C_RESET}"
  echo "  0     - MD5"
  echo "  100   - SHA1"
  echo "  1000  - NTLM"
  echo "  1400  - SHA256"
  echo "  1700  - SHA512"
  echo "  1800  - sha512crypt (Linux)"
  echo "  3200  - bcrypt"
  echo "  5600  - NetNTLMv2"
  echo "  22000 - WPA/WPA2 (PMKID/EAPOL)"
  echo ""
  echo -e "${C_INFO}Pour la liste complète: hashcat --help | grep 'Hash modes'${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}Mode hashcat: ${C_RESET}"
  read -r mode
  
  if [[ -z "$mode" ]]; then
    echo -e "${C_RED}Mode requis${C_RESET}"
    return 1
  fi
  
  # Sélection de la wordlist
  echo ""
  local wordlist
  wordlist=$(password_select_wordlist) || return 1
  
  echo ""
  echo -e "${C_HIGHLIGHT}Lancement de hashcat...${C_RESET}"
  echo -e "${C_INFO}Mode: $mode${C_RESET}"
  echo -e "${C_INFO}Hashes: $hashfile${C_RESET}"
  echo -e "${C_INFO}Wordlist: $wordlist${C_RESET}"
  echo ""
  
  # Préparation du log
  local outdir="$BALORSH_DATA_DIR/password/hashcat"
  mkdir -p "$outdir"
  local logfile="$outdir/session_$(date +%Y%m%d_%H%M%S).txt"
  
  {
    echo "=== Session Hashcat - Dictionnaire ==="
    echo "Date: $(date)"
    echo "Mode: $mode"
    echo "Fichier hashes: $hashfile"
    echo "Wordlist: $wordlist"
    echo ""
    echo "=== Démarrage ==="
  } > "$logfile"
  
  # Lancement hashcat
  hashcat -m "$mode" -a 0 "$hashfile" "$wordlist" --status --status-timer=10 2>&1 | tee -a "$logfile"
  
  # Résultats
  {
    echo ""
    echo "=== Résultats crackés ==="
    hashcat -m "$mode" "$hashfile" --show 2>/dev/null || echo "Aucun hash cracké"
    echo ""
    echo "Session terminée: $(date)"
  } >> "$logfile"
  
  echo ""
  echo -e "${C_GOOD}Cracking terminé${C_RESET}"
  echo -e "${C_INFO}Pour voir les résultats: hashcat -m $mode \"$hashfile\" --show${C_RESET}"
  echo -e "${C_GOOD}Log sauvegardé: $logfile${C_RESET}"
}

# Hashcat avec règles
password_hashcat_rules() {
  echo -e "${C_HIGHLIGHT}Cracking avec Hashcat + Règles${C_RESET}"
  echo ""
  
  # Sélection du fichier de hash
  echo -ne "${C_ACCENT1}Fichier de hashes: ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}Fichier non trouvé: $hashfile${C_RESET}"
    return 1
  fi
  
  # Sélection du type de hash
  echo -ne "${C_ACCENT1}Mode hashcat (ex: 0 pour MD5): ${C_RESET}"
  read -r mode
  
  # Sélection de la wordlist
  echo ""
  local wordlist
  wordlist=$(password_select_wordlist) || return 1
  
  # Sélection des règles
  echo ""
  echo -e "${C_HIGHLIGHT}Fichiers de règles disponibles:${C_RESET}"
  echo "  1) best64.rule (règles optimales)"
  echo "  2) rockyou-30000.rule"
  echo "  3) dive.rule"
  echo "  4) Fichier personnalisé"
  echo ""
  echo -ne "${C_ACCENT1}Choix [1]: ${C_RESET}"
  read -r rchoice
  rchoice="${rchoice:-1}"
  
  local rulefile=""
  case "$rchoice" in
    1) rulefile="/usr/share/hashcat/rules/best64.rule" ;;
    2) rulefile="/usr/share/hashcat/rules/rockyou-30000.rule" ;;
    3) rulefile="/usr/share/hashcat/rules/dive.rule" ;;
    4)
      echo -ne "${C_ACCENT1}Chemin du fichier de règles: ${C_RESET}"
      read -r rulefile
      ;;
    *)
      echo -e "${C_RED}Choix invalide${C_RESET}"
      return 1
      ;;
  esac
  
  if [[ ! -f "$rulefile" ]]; then
    echo -e "${C_RED}Fichier de règles non trouvé: $rulefile${C_RESET}"
    return 1
  fi
  
  echo ""
  echo -e "${C_HIGHLIGHT}Lancement de hashcat avec règles...${C_RESET}"
  echo -e "${C_INFO}Règles: $(basename "$rulefile")${C_RESET}"
  echo ""
  
  # Préparation du log
  local outdir="$BALORSH_DATA_DIR/password/hashcat"
  mkdir -p "$outdir"
  local logfile="$outdir/rules_$(date +%Y%m%d_%H%M%S).txt"
  
  {
    echo "=== Session Hashcat - Dictionnaire + Règles ==="
    echo "Date: $(date)"
    echo "Mode: $mode"
    echo "Fichier hashes: $hashfile"
    echo "Wordlist: $wordlist"
    echo "Règles: $rulefile"
    echo ""
    echo "=== Démarrage ==="
  } > "$logfile"
  
  hashcat -m "$mode" -a 0 "$hashfile" "$wordlist" -r "$rulefile" --status --status-timer=10 2>&1 | tee -a "$logfile"
  
  {
    echo ""
    echo "=== Résultats crackés ==="
    hashcat -m "$mode" "$hashfile" --show 2>/dev/null || echo "Aucun hash cracké"
    echo ""
    echo "Session terminée: $(date)"
  } >> "$logfile"
  
  echo ""
  echo -e "${C_GOOD}Cracking terminé${C_RESET}"
  echo -e "${C_GOOD}Log sauvegardé: $logfile${C_RESET}"
}

# Hashcat bruteforce (masque)
password_hashcat_mask() {
  echo -e "${C_HIGHLIGHT}Hashcat Mask Attack (Bruteforce)${C_RESET}"
  echo ""
  
  # Sélection du fichier de hash
  echo -ne "${C_ACCENT1}Fichier de hashes: ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}Fichier non trouvé: $hashfile${C_RESET}"
    return 1
  fi
  
  # Sélection du type de hash
  echo -ne "${C_ACCENT1}Mode hashcat (ex: 0 pour MD5): ${C_RESET}"
  read -r mode
  
  # Explication des masques
  echo ""
  echo -e "${C_HIGHLIGHT}Masques hashcat:${C_RESET}"
  echo "  ?l = minuscules (a-z)"
  echo "  ?u = majuscules (A-Z)"
  echo "  ?d = chiffres (0-9)"
  echo "  ?s = symboles (!@#$...)"
  echo "  ?a = tous caractères"
  echo ""
  echo -e "${C_INFO}Exemples:${C_RESET}"
  echo "  ?l?l?l?l?l?l = 6 lettres minuscules"
  echo "  ?u?l?l?l?l?d?d = Majuscule + 4 minuscules + 2 chiffres"
  echo "  ?a?a?a?a?a?a?a?a = 8 caractères quelconques"
  echo ""
  
  echo -ne "${C_ACCENT1}Masque (ex: ?l?l?l?l?d?d): ${C_RESET}"
  read -r mask
  
  if [[ -z "$mask" ]]; then
    echo -e "${C_RED}Masque requis${C_RESET}"
    return 1
  fi
  
  echo ""
  echo -e "${C_HIGHLIGHT}Lancement du bruteforce...${C_RESET}"
  echo -e "${C_INFO}Masque: $mask${C_RESET}"
  echo -e "${C_YELLOW}Attention: peut être très long selon la complexité${C_RESET}"
  echo ""
  
  # Préparation du log
  local outdir="$BALORSH_DATA_DIR/password/hashcat"
  mkdir -p "$outdir"
  local logfile="$outdir/mask_$(date +%Y%m%d_%H%M%S).txt"
  
  {
    echo "=== Session Hashcat - Mask Attack ==="
    echo "Date: $(date)"
    echo "Mode: $mode"
    echo "Fichier hashes: $hashfile"
    echo "Masque: $mask"
    echo ""
    echo "=== Démarrage ==="
  } > "$logfile"
  
  hashcat -m "$mode" -a 3 "$hashfile" "$mask" --status --status-timer=10 2>&1 | tee -a "$logfile"
  
  {
    echo ""
    echo "=== Résultats crackés ==="
    hashcat -m "$mode" "$hashfile" --show 2>/dev/null || echo "Aucun hash cracké"
    echo ""
    echo "Session terminée: $(date)"
  } >> "$logfile"
  
  echo ""
  echo -e "${C_GOOD}Bruteforce terminé${C_RESET}"
  echo -e "${C_GOOD}Log sauvegardé: $logfile${C_RESET}"
}

# Afficher les résultats hashcat
password_hashcat_show() {
  echo -ne "${C_ACCENT1}Fichier de hashes: ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}Fichier non trouvé: $hashfile${C_RESET}"
    return 1
  fi
  
  echo -ne "${C_ACCENT1}Mode hashcat utilisé: ${C_RESET}"
  read -r mode
  
  local outdir="$BALORSH_DATA_DIR/password/hashcat"
  mkdir -p "$outdir"
  local outfile="$outdir/results_$(date +%Y%m%d_%H%M%S).txt"
  
  echo ""
  echo -e "${C_HIGHLIGHT}Mots de passe crackés:${C_RESET}"
  
  {
    echo "=== Résultats Hashcat ==="
    echo "Date: $(date)"
    echo "Mode: $mode"
    echo "Fichier: $hashfile"
    echo ""
    echo "=== Hashes crackés ==="
    hashcat -m "$mode" "$hashfile" --show 2>&1
  } | tee "$outfile"
  
  echo ""
  echo -e "${C_GOOD}Résultats sauvegardés: $outfile${C_RESET}"
}

# ==============================================================================
# FONCTIONS JOHN THE RIPPER
# ==============================================================================

# Crack avec John
password_john_crack() {
  echo -e "${C_HIGHLIGHT}Cracking avec John the Ripper${C_RESET}"
  echo ""
  
  echo -ne "${C_ACCENT1}Fichier de hashes: ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}Fichier non trouvé: $hashfile${C_RESET}"
    return 1
  fi
  
  echo ""
  echo -e "${C_HIGHLIGHT}Modes d'attaque:${C_RESET}"
  echo "  1) Mode automatique (single crack)"
  echo "  2) Wordlist"
  echo "  3) Incremental (bruteforce)"
  echo ""
  echo -ne "${C_ACCENT1}Choix [1]: ${C_RESET}"
  read -r choice
  choice="${choice:-1}"
  
  local outdir="$BALORSH_DATA_DIR/password/john"
  mkdir -p "$outdir"
  local logfile="$outdir/session_$(date +%Y%m%d_%H%M%S).txt"
  
  case "$choice" in
    1)
      echo -e "${C_HIGHLIGHT}Lancement de John en mode single...${C_RESET}"
      {
        echo "=== Session John the Ripper - Single Mode ==="
        echo "Date: $(date)"
        echo "Fichier: $hashfile"
        echo ""
        john --single "$hashfile" 2>&1
        echo ""
        echo "=== Résultats ==="
        john --show "$hashfile" 2>&1
      } | tee "$logfile"
      ;;
    2)
      local wordlist
      wordlist=$(password_select_wordlist) || return 1
      echo ""
      echo -e "${C_HIGHLIGHT}Lancement de John avec wordlist...${C_RESET}"
      {
        echo "=== Session John the Ripper - Wordlist ==="
        echo "Date: $(date)"
        echo "Fichier: $hashfile"
        echo "Wordlist: $wordlist"
        echo ""
        john --wordlist="$wordlist" "$hashfile" 2>&1
        echo ""
        echo "=== Résultats ==="
        john --show "$hashfile" 2>&1
      } | tee "$logfile"
      ;;
    3)
      echo -e "${C_HIGHLIGHT}Lancement de John en mode incremental...${C_RESET}"
      echo -e "${C_YELLOW}Attention: peut être très long${C_RESET}"
      {
        echo "=== Session John the Ripper - Incremental ==="
        echo "Date: $(date)"
        echo "Fichier: $hashfile"
        echo ""
        john --incremental "$hashfile" 2>&1
        echo ""
        echo "=== Résultats ==="
        john --show "$hashfile" 2>&1
      } | tee "$logfile"
      ;;
    *)
      echo -e "${C_RED}Choix invalide${C_RESET}"
      return 1
      ;;
  esac
  
  echo ""
  echo -e "${C_GOOD}Pour voir les résultats: john --show \"$hashfile\"${C_RESET}"
  echo -e "${C_GOOD}Log sauvegardé: $logfile${C_RESET}"
}

# John avec règles
password_john_rules() {
  echo -e "${C_HIGHLIGHT}John the Ripper avec règles${C_RESET}"
  echo ""
  
  echo -ne "${C_ACCENT1}Fichier de hashes: ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}Fichier non trouvé: $hashfile${C_RESET}"
    return 1
  fi
  
  local wordlist
  wordlist=$(password_select_wordlist) || return 1
  
  echo ""
  echo -e "${C_HIGHLIGHT}Règles disponibles:${C_RESET}"
  echo "  1) best64"
  echo "  2) d3ad0ne"
  echo "  3) dive"
  echo "  4) jumbo"
  echo ""
  echo -ne "${C_ACCENT1}Choix [1]: ${C_RESET}"
  read -r rchoice
  rchoice="${rchoice:-1}"
  
  local rules=""
  case "$rchoice" in
    1) rules="best64" ;;
    2) rules="d3ad0ne" ;;
    3) rules="dive" ;;
    4) rules="jumbo" ;;
    *)
      echo -e "${C_RED}Choix invalide${C_RESET}"
      return 1
      ;;
  esac
  
  local outdir="$BALORSH_DATA_DIR/password/john"
  mkdir -p "$outdir"
  local logfile="$outdir/rules_$(date +%Y%m%d_%H%M%S).txt"
  
  echo ""
  echo -e "${C_HIGHLIGHT}Lancement de John avec règles $rules...${C_RESET}"
  
  {
    echo "=== Session John the Ripper - Règles ==="
    echo "Date: $(date)"
    echo "Fichier: $hashfile"
    echo "Wordlist: $wordlist"
    echo "Règles: $rules"
    echo ""
    john --wordlist="$wordlist" --rules="$rules" "$hashfile" 2>&1
    echo ""
    echo "=== Résultats ==="
    john --show "$hashfile" 2>&1
  } | tee "$logfile"
  
  echo ""
  echo -e "${C_GOOD}Log sauvegardé: $logfile${C_RESET}"
}

# Afficher résultats John
password_john_show() {
  echo -ne "${C_ACCENT1}Fichier de hashes: ${C_RESET}"
  read -r hashfile
  if [[ ! -f "$hashfile" ]]; then
    echo -e "${C_RED}Fichier non trouvé: $hashfile${C_RESET}"
    return 1
  fi
  
  local outdir="$BALORSH_DATA_DIR/password/john"
  mkdir -p "$outdir"
  local outfile="$outdir/results_$(date +%Y%m%d_%H%M%S).txt"
  
  echo ""
  echo -e "${C_HIGHLIGHT}Mots de passe crackés (John):${C_RESET}"
  
  {
    echo "=== Résultats John the Ripper ==="
    echo "Date: $(date)"
    echo "Fichier: $hashfile"
    echo ""
    echo "=== Hashes crackés ==="
    john --show "$hashfile" 2>&1
  } | tee "$outfile"
  
  echo ""
  echo -e "${C_GOOD}Résultats sauvegardés: $outfile${C_RESET}"
}

# ==============================================================================
# FONCTIONS DE GÉNÉRATION DE WORDLISTS
# ==============================================================================

# Générer wordlist avec crunch
password_crunch_generate() {
  echo -e "${C_HIGHLIGHT}Génération de wordlist avec Crunch${C_RESET}"
  echo ""
  
  echo -ne "${C_ACCENT1}Longueur minimale: ${C_RESET}"
  read -r minlen
  echo -ne "${C_ACCENT1}Longueur maximale: ${C_RESET}"
  read -r maxlen
  
  if ! [[ "$minlen" =~ ^[0-9]+$ ]] || ! [[ "$maxlen" =~ ^[0-9]+$ ]]; then
    echo -e "${C_RED}Longueurs invalides${C_RESET}"
    return 1
  fi
  
  if (( minlen > maxlen )); then
    echo -e "${C_RED}Min doit être <= Max${C_RESET}"
    return 1
  fi
  
  echo ""
  echo -e "${C_HIGHLIGHT}Jeu de caractères:${C_RESET}"
  echo "  1) Minuscules (a-z)"
  echo "  2) Majuscules (A-Z)"
  echo "  3) Chiffres (0-9)"
  echo "  4) Minuscules + chiffres"
  echo "  5) Alphanumériques (a-zA-Z0-9)"
  echo "  6) Personnalisé"
  echo ""
  echo -ne "${C_ACCENT1}Choix [4]: ${C_RESET}"
  read -r cchoice
  cchoice="${cchoice:-4}"
  
  local charset=""
  case "$cchoice" in
    1) charset="abcdefghijklmnopqrstuvwxyz" ;;
    2) charset="ABCDEFGHIJKLMNOPQRSTUVWXYZ" ;;
    3) charset="0123456789" ;;
    4) charset="abcdefghijklmnopqrstuvwxyz0123456789" ;;
    5) charset="abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789" ;;
    6)
      echo -ne "${C_ACCENT1}Caractères personnalisés: ${C_RESET}"
      read -r charset
      ;;
    *)
      echo -e "${C_RED}Choix invalide${C_RESET}"
      return 1
      ;;
  esac
  
  # Fichier de sortie
  local outdir="$BALORSH_DATA_DIR/password/wordlists"
  mkdir -p "$outdir"
  local outfile="$outdir/crunch_${minlen}-${maxlen}_$(date +%Y%m%d_%H%M%S).txt"
  
  echo ""
  echo -e "${C_HIGHLIGHT}Estimation de la taille...${C_RESET}"
  
  # Calcul estimation (simplifié)
  local charcount=${#charset}
  echo -e "${C_INFO}Jeu de $charcount caractères${C_RESET}"
  echo -e "${C_INFO}Longueurs: $minlen à $maxlen${C_RESET}"
  
  echo ""
  echo -e "${C_YELLOW}Attention: la génération peut créer des fichiers TRÈS volumineux${C_RESET}"
  echo -ne "${C_ACCENT1}Continuer? [y/N]: ${C_RESET}"
  read -r confirm
  
  if [[ "${confirm,,}" != "y" ]]; then
    echo "Annulé"
    return 0
  fi
  
  echo ""
  echo -e "${C_HIGHLIGHT}Génération en cours...${C_RESET}"
  echo -e "${C_INFO}Sortie: $outfile${C_RESET}"
  
  crunch "$minlen" "$maxlen" "$charset" -o "$outfile"
  
  echo ""
  echo -e "${C_GOOD}Wordlist générée: $outfile${C_RESET}"
  
  if [[ -f "$outfile" ]]; then
    local size=$(du -sh "$outfile" | awk '{print $1}')
    local lines=$(wc -l < "$outfile")
    echo -e "${C_INFO}Taille: $size${C_RESET}"
    echo -e "${C_INFO}Lignes: $lines${C_RESET}"
  fi
}

# ==============================================================================
# FONCTIONS DE CRACKING RÉSEAU
# ==============================================================================

# Medusa - brute force services réseau
password_medusa_attack() {
  echo -e "${C_HIGHLIGHT}Medusa - Brute force réseau${C_RESET}"
  echo ""
  
  echo -e "${C_HIGHLIGHT}Services supportés:${C_RESET}"
  echo "  ssh, ftp, http, mysql, postgres, rdp, smb, telnet, vnc..."
  echo ""
  
  echo -ne "${C_ACCENT1}Cible (IP ou hostname): ${C_RESET}"
  read -r target
  
  echo -ne "${C_ACCENT1}Service (ex: ssh, ftp, http): ${C_RESET}"
  read -r service
  
  echo -ne "${C_ACCENT1}Utilisateur (-u) ou fichier users (-U): ${C_RESET}"
  read -r user_input
  
  local user_opt=""
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
  echo -e "${C_HIGHLIGHT}Lancement de Medusa...${C_RESET}"
  echo -e "${C_INFO}Cible: $target${C_RESET}"
  echo -e "${C_INFO}Service: $service${C_RESET}"
  echo ""
  
  {
    echo "=== Attaque Medusa ==="
    echo "Date: $(date)"
    echo "Cible: $target"
    echo "Service: $service"
    echo "User option: $user_opt"
    echo "Wordlist: $wordlist"
    echo ""
    echo "=== Résultats ==="
    medusa -h "$target" -M "$service" $user_opt -P "$wordlist" -t 4 -v 4 2>&1
  } | tee "$outfile"
  
  echo ""
  echo -e "${C_GOOD}Attaque terminée${C_RESET}"
  echo -e "${C_GOOD}Résultats sauvegardés: $outfile${C_RESET}"
}

# Ncrack - network cracker
password_ncrack_attack() {
  echo -e "${C_HIGHLIGHT}Ncrack - Network Authentication Cracker${C_RESET}"
  echo ""
  
  echo -ne "${C_ACCENT1}Cible (ex: ssh://192.168.1.1): ${C_RESET}"
  read -r target
  
  echo -ne "${C_ACCENT1}Utilisateur: ${C_RESET}"
  read -r username
  
  echo ""
  local wordlist
  wordlist=$(password_select_wordlist) || return 1
  
  local outdir="$BALORSH_DATA_DIR/password/ncrack"
  mkdir -p "$outdir"
  local outfile="$outdir/attack_$(date +%Y%m%d_%H%M%S).txt"
  
  echo ""
  echo -e "${C_HIGHLIGHT}Lancement de Ncrack...${C_RESET}"
  
  {
    echo "=== Attaque Ncrack ==="
    echo "Date: $(date)"
    echo "Cible: $target"
    echo "Username: $username"
    echo "Wordlist: $wordlist"
    echo ""
    echo "=== Résultats ==="
    ncrack -u "$username" -P "$wordlist" "$target" -v 2>&1
  } | tee "$outfile"
  
  echo ""
  echo -e "${C_GOOD}Scan terminé${C_RESET}"
  echo -e "${C_GOOD}Résultats sauvegardés: $outfile${C_RESET}"
}

# ==============================================================================
# UTILITAIRES
# ==============================================================================

# Nettoyer anciens fichiers
password_cleanup() {
  echo -e "${C_YELLOW}Nettoyage des anciens fichiers...${C_RESET}"
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
  done < <(find "$BALORSH_DATA_DIR/password" -type f -mtime +"$days" -print0 2>/dev/null)
  
  echo -e "${C_GOOD}$count fichier(s) supprimé(s)${C_RESET}"
}

# Aide
password_help() {
  cat <<EOF
${C_ACCENT1}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}
${C_ACCENT1}║${C_RESET}                   ${C_GOOD}AIDE PASSWORD STACK${C_RESET}                        ${C_ACCENT1}║${C_RESET}
${C_ACCENT1}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}

${C_HIGHLIGHT}OUTILS DISPONIBLES:${C_RESET}
  • hashid      - Identifier les types de hash
  • hashcat     - Cracking GPU-accéléré (le plus rapide)
  • john        - John the Ripper (CPU, très versatile)
  • crunch      - Générateur de wordlists
  • medusa      - Brute force services réseau (parallèle)
  • ncrack      - Network authentication cracker
  • wordlists   - Collection massive de wordlists

${C_HIGHLIGHT}WORKFLOW TYPIQUE:${C_RESET}
  1. Identifier le hash → hashid
  2. Choisir l'outil: hashcat (GPU) ou john (CPU)
  3. Sélectionner wordlist ou bruteforce
  4. Analyser les résultats

${C_HIGHLIGHT}TYPES DE HASH COURANTS:${C_RESET}
  • MD5 (hashcat: 0, john: raw-md5)
  • SHA1 (hashcat: 100, john: raw-sha1)
  • NTLM (hashcat: 1000, john: nt)
  • bcrypt (hashcat: 3200, john: bcrypt)
  • WPA/WPA2 (hashcat: 22000)

${C_HIGHLIGHT}WORDLISTS:${C_RESET}
  Emplacement: $WORDLISTS_DIR
  Principale: rockyou.txt (14M, 14 millions de mots de passe)
  Collection: SecLists (passwords, usernames, etc.)

${C_HIGHLIGHT}MODES D'ATTAQUE:${C_RESET}
  • Dictionary: Utilise une wordlist existante
  • Rules: Applique des transformations (leet, case, etc.)
  • Mask/Brute: Teste toutes les combinaisons d'un pattern

${C_HIGHLIGHT}PERFORMANCE:${C_RESET}
  Hashcat + GPU >> John (CPU)
  MD5: ~10 milliards hash/sec (GPU moderne)
  bcrypt: ~100k hash/sec (très lent par design)

${C_HIGHLIGHT}CONSEILS:${C_RESET}
  • Toujours commencer par hashid pour identifier
  • Utiliser hashcat si vous avez un GPU
  • Commencer par rockyou.txt (couvre 80% des cas)
  • Ajouter des règles pour augmenter les chances
  • Le bruteforce est un dernier recours (très lent)

${C_HIGHLIGHT}SERVICES RÉSEAU (MEDUSA/NCRACK):${C_RESET}
  SSH, FTP, HTTP, MySQL, PostgreSQL, RDP, SMB, Telnet, VNC
  Attention: peut verrouiller les comptes après X tentatives

${C_YELLOW}AVERTISSEMENT:${C_RESET}
  Le cracking de mots de passe doit être fait uniquement:
  - Sur vos propres systèmes
  - Dans un cadre légal (pentest autorisé)
  - Pour la récupération de vos propres données

  L'accès non autorisé est illégal.

${C_HIGHLIGHT}EXEMPLES:${C_RESET}
  hashid 5f4dcc3b5aa765d61d8327deb882cf99
  hashcat -m 0 -a 0 hashes.txt rockyou.txt
  john --wordlist=rockyou.txt hashes.txt
  crunch 6 8 abcdef123 -o wordlist.txt
  medusa -h 192.168.1.1 -M ssh -u admin -P rockyou.txt

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
    echo -e "                  ${C_GOOD}${PASSWORD_MENU_TITLE}${C_RESET}                 "
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_IDENTIFICATION}${C_RESET}                                   "
    echo -e "   ${PASSWORD_MENU_1}                              "
    echo -e "   ${PASSWORD_MENU_2}                         "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_HASHCAT}${C_RESET}                          "
    echo -e "   ${PASSWORD_MENU_3}                                   "
    echo -e "   ${PASSWORD_MENU_4}                          "
    echo -e "   ${PASSWORD_MENU_5}                       "
    echo -e "   ${PASSWORD_MENU_6}                               "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_JOHN}${C_RESET}                  "
    echo -e "   ${PASSWORD_MENU_7}                         "
    echo -e "   ${PASSWORD_MENU_8}                                 "
    echo -e "   ${PASSWORD_MENU_9}                                  "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_WORDLIST}${C_RESET}                            "
    echo -e "   ${PASSWORD_MENU_10}                 "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_NETWORK}${C_RESET}                                 "
    echo -e "   ${PASSWORD_MENU_11}                    "
    echo -e "   ${PASSWORD_MENU_12}                 "
    echo -e "                                                                 "
    echo -e "   ${C_SHADOW}${PASSWORD_MENU_SECTION_UTILS}${C_RESET}                                     "
    echo -e "   ${PASSWORD_MENU_13}                               "
    echo -e "   ${PASSWORD_MENU_14}                                                    "
    echo -e "                                                                 "
    echo -e "   ${PASSWORD_MENU_0}                                                   "
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
