#!/usr/bin/env bash

# Charger le système i18n
SCRIPT_DIR_COMMON="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=i18n.sh
source "$SCRIPT_DIR_COMMON/i18n.sh"

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

  # Paquets qu'on ne supprime jamais automatiquement (trop core / partagés)
  local protected_pkgs=("iptables-nft" "iproute2" "ufw" "git" "python" "python-pip")

  for prot in "${protected_pkgs[@]}"; do
    if [[ "$pkg" == "$prot" ]]; then
      echo "  [SKIP] $pkg est marqué comme protégé, non désinstallé automatiquement."
      return
    fi
  done

  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    echo "  [REMOVE] $pkg..."
    sudo pacman -Rns --noconfirm "$pkg" || {
      echo "  [WARN] Impossible de désinstaller $pkg (dépendances système ?)."
    }
  else
    echo "  [SKIP] $pkg pas installé."
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
