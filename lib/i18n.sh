#!/usr/bin/env bash

# lib/i18n.sh
# Système d'internationalisation (i18n) pour Balor
# Supporte: Français (fr), Anglais (en)

# Détection automatique de la langue système
detect_system_language() {
  local sys_lang="${LANG:-en_US.UTF-8}"
  
  # Extraire le code de langue (2 premières lettres)
  local lang_code="${sys_lang:0:2}"
  
  # Vérifier si la langue est supportée
  case "$lang_code" in
    fr)
      echo "fr"
      ;;
    en)
      echo "en"
      ;;
    *)
      # Par défaut: anglais
      echo "en"
      ;;
  esac
}

# Variable globale pour la langue actuelle
BALOR_LANG="${BALOR_LANG:-$(detect_system_language)}"

# Répertoire des fichiers de langue
I18N_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/lang" && pwd)"

# Charger le fichier de langue approprié
load_language() {
  local lang="${1:-$BALOR_LANG}"
  local lang_file="$I18N_DIR/${lang}.sh"
  
  if [[ -f "$lang_file" ]]; then
    # shellcheck source=/dev/null
    source "$lang_file"
    BALOR_LANG="$lang"
    return 0
  else
    echo "[Warning] Language file not found: $lang_file, falling back to English"
    # shellcheck source=/dev/null
    source "$I18N_DIR/en.sh"
    BALOR_LANG="en"
    return 1
  fi
}

# Fonction pour changer de langue à la volée
set_language() {
  local new_lang="$1"
  
  case "$new_lang" in
    fr|en)
      load_language "$new_lang"
      echo "Language changed to: $new_lang"
      ;;
    *)
      echo "Unsupported language: $new_lang. Supported: fr, en"
      return 1
      ;;
  esac
}

# Fonction utilitaire pour obtenir la langue actuelle
get_current_language() {
  echo "$BALOR_LANG"
}

# Charger la langue par défaut au sourcing
load_language "$BALOR_LANG"
