#!/usr/bin/env bash

# Détection de paru
have_paru() {
  command -v paru >/dev/null 2>&1
}

# Installer paru si absent
ensure_aur_helper() {
  if have_paru; then
    echo "[Balor] paru détecté."
    return
  fi

  echo "[Balor] paru non trouvé."
  echo "1) Installer paru depuis les dépôts (recommandé sur CachyOS)"
  echo "2) Ne pas installer de helper AUR (les paquets AUR seront ignorés)"
  read -rp "Choix [1/2]: " choice

  case "$choice" in
    1)
      echo "[Balor] Installation de paru via pacman..."
      sudo pacman -S --needed --noconfirm paru || echo "[!] Échec installation paru."
      ;;
    2)
      echo "[Balor] Ok, pas de helper AUR. Les paquets AUR seront ignorés."
      ;;
    *)
      echo "[Balor] Choix invalide, aucun helper installé."
      ;;
  esac
}

# Installer un paquet pacman si pas déjà présent
install_pacman_pkg() {
  local pkg="$1"
  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    echo "  [OK] $pkg déjà installé (pacman)."
  else
    echo "  [INSTALL] $pkg (pacman)..."
    sudo pacman -S --needed --noconfirm "$pkg"
  fi
}

# Installer un paquet AUR via paru si dispo
install_aur_pkg() {
  local pkg="$1"

  if ! have_paru; then
    echo "  [SKIP] $pkg (AUR) : paru non configuré."
    return
  fi

  if pacman -Qi "$pkg" >/dev/null 2>&1; then
    echo "  [OK] $pkg déjà installé (AUR/pacman)."
  else
    echo "  [INSTALL] $pkg (AUR via paru)..."
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
