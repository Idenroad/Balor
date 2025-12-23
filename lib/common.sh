#!/usr/bin/env bash

# Charger le système i18n
SCRIPT_DIR_COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=i18n.sh
source "$SCRIPT_DIR_COMMON/i18n.sh"

# Packages essentiels - protégés de la désinstallation
ESSENTIAL_PACKAGES=(
  "curl"
  "git"
  "openssh"
  "python"
  "python-pip"
  "fzf"
  "smbclient"
  "nfs-utils"
  "rpcbind"
  "freerdp"
  "python-pipx"
  "ollama"
)

export ESSENTIAL_PACKAGES

# Détection de paru
have_paru() {
  command -v paru >/dev/null 2>&1
}

# Installer paru si absent
ensure_aur_helper() {
  if have_paru; then
    echo "$MSG_PARU_DETECTED"
    return
  fi

  echo "$MSG_PARU_NOT_FOUND"
  echo -e "$MSG_PARU_INSTALL_PROMPT"
  read -rp "$MSG_PARU_CHOICE" choice

  case "$choice" in
    1)
      echo "$MSG_PARU_INSTALLING"
      sudo pacman -S --needed --noconfirm paru || echo "$MSG_PARU_INSTALL_FAILED"
      ;;
    2)
      echo "$MSG_PARU_SKIPPED"
      ;;
    *)
      echo "$MSG_PARU_INVALID_CHOICE"
      ;;
  esac
}

# Installer un paquet pacman si pas déjà présent
install_pacman_pkg() {
  local pkg="$1"
  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    printf "$MSG_PKG_ALREADY_INSTALLED\n" "$pkg"
  else
    printf "$MSG_PKG_INSTALLING\n" "$pkg"
    sudo pacman -S --needed --noconfirm "$pkg"
  fi
}

# Installer un paquet AUR via paru si dispo
install_aur_pkg() {
  local pkg="$1"

  if ! have_paru; then
    printf "$MSG_PKG_AUR_SKIP\n" "$pkg"
    return
  fi

  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    printf "$MSG_PKG_AUR_ALREADY\n" "$pkg"
  else
    printf "$MSG_PKG_AUR_INSTALLING\n" "$pkg"
    paru -S --needed --noconfirm "$pkg"
  fi
}

# Désinstaller un paquet (pacman ou AUR)
remove_pkg() {
  local pkg="$1"

  # Vérifier si le package est dans la liste des essentiels
  for essential in "${ESSENTIAL_PACKAGES[@]}"; do
    if [[ "$pkg" == "$essential" ]]; then
      printf "$MSG_ESSENTIAL_PROTECTED\n" "$pkg"
      return
    fi
  done

  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    printf "$MSG_PKG_REMOVING\n" "$pkg"
    sudo pacman -Rns --noconfirm "$pkg" || {
      printf "$MSG_PKG_REMOVE_FAILED\n" "$pkg"
    }
  else
    printf "$MSG_PKG_NOT_INSTALLED\n" "$pkg"
  fi
}

# Lire packages.txt d'une stack
# Format:
#   pacman:aircrack-ng
#   aur:airgeddon
read_stack_packages() {
  local stack_dir="$1"
  local pacman_pkgs=()
  local aur_pkgs=()

  while IFS= read -r line; do
    [[ -z "$line" || "$line" == \#* ]] && continue
    local type="${line%%:*}"
    local name="${line#*:}"
    if [[ "$type" == "pacman" ]]; then
      pacman_pkgs+=("$name")
    elif [[ "$type" == "aur" ]]; then
      aur_pkgs+=("$name")
    fi
  done < "$stack_dir/packages.txt"

  echo "${pacman_pkgs[*]}|${aur_pkgs[*]}"
}

# Créer le dossier data pour une stack (marqueur d'installation)
ensure_stack_data_dir() {
  local stack_name="$1"
  local data_dir="${BALOR_OPT_ROOT:-/opt/balorsh}/data/$stack_name"
  
  if [[ ! -d "$data_dir" ]]; then
    if ! mkdir -p "$data_dir" 2>/dev/null; then
      sudo mkdir -p "$data_dir" || return 1
    fi
  fi
  
  # Permissions et ownership
  if ! chmod 775 "$data_dir" 2>/dev/null; then
    sudo chmod 775 "$data_dir" || true
  fi
  
  local owner="${SUDO_USER:-$USER}"
  if ! chown "$owner:$owner" "$data_dir" 2>/dev/null; then
    sudo chown "$owner:$owner" "$data_dir" || true
  fi
  
  return 0
}

# --- Aides couleur du terminal ---
# Convertit une couleur hexadécimale #RRGGBB en séquence ANSI 24-bit
# pour la couleur du texte (foreground)
hex_to_ansi_fg() {
  local hex="$1"
  hex="${hex#\#}"
  local r=$((16#${hex:0:2}))
  local g=$((16#${hex:2:2}))
  local b=$((16#${hex:4:2}))
  printf '\033[38;2;%d;%d;%dm' "$r" "$g" "$b"
}

# Variables de couleur communes (palette du menu)
# Palette fournie : #751EE9, #9075E2, #06FB06, #25FD9D
C_RESET="\033[0m"
C_BOLD="\033[1m"
C_ACCENT1="$(hex_to_ansi_fg '#751EE9')"
C_ACCENT2="$(hex_to_ansi_fg '#9075E2')"
C_GOOD="$(hex_to_ansi_fg '#06FB06')"
C_HIGHLIGHT="$(hex_to_ansi_fg '#25FD9D')"
# couleur d'ombre/étiquette subtile (effet atténué)
C_SHADOW="\033[2m"
# Couleurs additionnelles pour les messages
C_INFO="$(hex_to_ansi_fg '#25FD9D')"   # Cyan/turquoise pour info
C_RED="\033[91m"                        # Rouge pour erreurs
C_YELLOW="\033[93m"                     # Jaune pour warnings

export C_RESET C_BOLD C_ACCENT1 C_ACCENT2 C_GOOD C_HIGHLIGHT C_SHADOW C_INFO C_RED C_YELLOW

# Supprimer le répertoire de données d'une stack
remove_stack_data_dir() {
  local stack="$1"
  local data_dir="$BALOR_OPT_ROOT/data/$stack"
  
  # Si on est en mode "supprimer toutes les données" (désinstallation complète)
  if [[ "${UNINSTALL_ALL_DATA:-false}" == "true" ]]; then
    if [[ -d "$data_dir" ]]; then
      printf "${C_YELLOW}${UNINSTALL_DATA_DIR_REMOVING}${C_RESET}\n" "$data_dir"
      sudo rm -rf "$data_dir"
    fi
    return
  fi
  
  # Mode individuel : demander confirmation
  if [[ -d "$data_dir" ]]; then
    printf "${UNINSTALL_DATA_DIR_PROMPT}" "$stack" "$data_dir" "[o/N]"
    read -r choice
    if [[ "$choice" =~ ^[oOyY]$ ]]; then
      printf "${C_YELLOW}${UNINSTALL_DATA_DIR_REMOVING}${C_RESET}\n" "$data_dir"
      sudo rm -rf "$data_dir"
    else
      echo -e "${C_INFO}${UNINSTALL_DATA_DIR_SKIPPED}${C_RESET}"
    fi
  fi
}

# Vérifier et installer les packages essentiels
check_essential_packages() {
  echo "$MSG_ESSENTIAL_CHECK"
  
  for pkg in "${ESSENTIAL_PACKAGES[@]}"; do
    if pacman -Qi "$pkg" >/dev/null 2>&1; then
      printf "$MSG_ESSENTIAL_OK\n" "$pkg"
    else
      printf "$MSG_ESSENTIAL_MISSING\n" "$pkg"
      sudo pacman -S --needed --noconfirm "$pkg"
      printf "$MSG_ESSENTIAL_INSTALLED\n" "$pkg"
    fi
  done
}

# Option globale pour activer/désactiver les pauses "Appuyez sur Entrée"
# Par défaut activée; peut être surchargée via l'environnement (ex: ENABLE_PRESS_ENTER_PROMPT=0)
ENABLE_PRESS_ENTER_PROMPT=${ENABLE_PRESS_ENTER_PROMPT:-1}

# Affiche l'invite localisée 'Appuyez sur Entrée' et attend l'entrée utilisateur
# Ne fait rien si ENABLE_PRESS_ENTER_PROMPT est à 0 (utile pour CI/batch)
press_enter_if_enabled() {
  if [[ "${ENABLE_PRESS_ENTER_PROMPT}" == "1" ]]; then
    # Utiliser la chaîne i18n INSTALL_PRESS_ENTER définie côté install.sh/i18n
    echo ""
    if [[ -n "${C_ACCENT1:-}" && -n "${C_RESET:-}" ]]; then
      echo -ne "${C_ACCENT1}${INSTALL_PRESS_ENTER}${C_RESET}"
    else
      printf "%s" "${INSTALL_PRESS_ENTER:-Appuyez sur Entrée pour continuer...}"
    fi
    if [[ -e /dev/tty ]]; then
      IFS= read -r </dev/tty
    else
      read -r
    fi
  fi
}
