#!/usr/bin/env bash
set -Eeuo pipefail

# stacks/llm/install.sh
# Installation de la stack LLM avec Ollama et choix de modèles IA

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
MODELS_SOURCE_DIR="$ROOT_DIR/lib/models"

# Charger les bibliothèques communes et i18n
source "$ROOT_DIR/lib/common.sh"
source "$ROOT_DIR/lib/i18n.sh"

echo "[LLM] Installation de la stack LLM..."

# Créer les répertoires nécessaires
MODELS_DIR="/opt/balorsh/data/llm/models"
MODELFILES_DIR="/opt/balorsh/data/llm/modelfiles"
LOGS_DIR="/opt/balorsh/data/llm/logs"
MODELS_CONFIG="$MODELS_DIR/models.conf"

sudo mkdir -p "$MODELS_DIR"
sudo mkdir -p "$MODELFILES_DIR"
sudo mkdir -p "$LOGS_DIR"
sudo chown -R "$USER:$USER" /opt/balorsh/data/llm

# Menu de sélection des modèles
echo ""
echo -e "${C_ACCENT2}╔════════════════════════════════════════════════════════════════╗${C_RESET}"
echo -e "${C_ACCENT2}║${C_RESET}           ${C_GOOD}${LLM_INSTALL_SELECT_TITLE}${C_RESET}           ${C_ACCENT2}║${C_RESET}"
echo -e "${C_ACCENT2}╚════════════════════════════════════════════════════════════════╝${C_RESET}"
echo ""
echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_GOOD}${LLM_INSTALL_OPT1_TITLE}${C_RESET} ${C_SHADOW}- ${LLM_INSTALL_OPT1_RECOMMENDED}${C_RESET}"
echo -e "     ${C_SHADOW}${LLM_INSTALL_OPT1_DESC}${C_RESET}"
echo ""
echo -e "  ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${LLM_INSTALL_OPT2_TITLE}${C_RESET}"
echo -e "     ${C_SHADOW}${LLM_INSTALL_OPT2_DESC}${C_RESET}"
echo ""
echo -e "  ${C_HIGHLIGHT}3)${C_RESET} ${C_ACCENT1}${LLM_INSTALL_OPT3}${C_RESET}"
echo ""
echo -e "  ${C_HIGHLIGHT}4)${C_RESET} ${LLM_INSTALL_OPT4}"
echo ""
echo -ne "${C_ACCENT1}${LLM_INSTALL_YOUR_CHOICE}${C_RESET} "
read -r model_choice

# Fonction pour télécharger un modèle
download_model() {
  local url="$1"
  local filename="$2"
  local display_name="$3"
  local filepath="$MODELS_DIR/$filename"
  
  if [[ -f "$filepath" ]]; then
    printf "[LLM] ${LLM_INSTALL_ALREADY_PRESENT}\n" "$display_name"
    return 0
  fi
  
  printf "[LLM] ${LLM_INSTALL_DOWNLOADING}\n" "$display_name"
  if curl -L -o "$filepath" "$url"; then
    printf "[LLM] ${LLM_INSTALL_SUCCESS}\n" "$display_name"
    # Enregistrer dans la config
    echo "$filename|$display_name" >> "$MODELS_CONFIG"
    return 0
  else
    printf "[LLM] ${LLM_INSTALL_ERROR}\n" "$display_name"
    return 1
  fi
}

# Initialiser le fichier de config
> "$MODELS_CONFIG"

case "$model_choice" in
  1)
    download_model \
      "https://huggingface.co/AlicanKiraz0/Seneca-Cybersecurity-LLM-Q4_K_M-GGUF/resolve/main/senecallm-q4_k_m.gguf" \
      "senecallm-q4_k_m.gguf" \
      "Seneca Cybersecurity LLM"
    ;;
  2)
    download_model \
      "https://huggingface.co/tensorblock/WhiteRabbitNeo-2.5-Qwen-2.5-Coder-7B-GGUF/resolve/main/WhiteRabbitNeo-2.5-Qwen-2.5-Coder-7B-Q4_K_M.gguf?download=true" \
      "whiterabbitneo-q4_k_m.gguf" \
      "WhiteRabbitNeo 2.5 Qwen Coder"
    ;;
  3)
    download_model \
      "https://huggingface.co/AlicanKiraz0/Seneca-Cybersecurity-LLM-Q4_K_M-GGUF/resolve/main/senecallm-q4_k_m.gguf" \
      "senecallm-q4_k_m.gguf" \
      "Seneca Cybersecurity LLM"
    download_model \
      "https://huggingface.co/tensorblock/WhiteRabbitNeo-2.5-Qwen-2.5-Coder-7B-GGUF/resolve/main/WhiteRabbitNeo-2.5-Qwen-2.5-Coder-7B-Q4_K_M.gguf?download=true" \
      "whiterabbitneo-q4_k_m.gguf" \
      "WhiteRabbitNeo 2.5 Qwen Coder"
    ;;
  4)
    echo ""
    echo -n "${LLM_INSTALL_CUSTOM_URL} "
    read -r custom_url
    echo -n "${LLM_INSTALL_CUSTOM_FILENAME} "
    read -r custom_filename
    echo -n "${LLM_INSTALL_CUSTOM_DISPLAY} "
    read -r custom_display
    
    download_model "$custom_url" "$custom_filename" "$custom_display"
    ;;
  *)
    echo "[LLM] Choix invalide, installation annulée"
    exit 1
    ;;
esac

# Définir le modèle actif par défaut (le premier installé)
if [[ -f "$MODELS_CONFIG" && -s "$MODELS_CONFIG" ]]; then
  ACTIVE_MODEL=$(head -n1 "$MODELS_CONFIG" | cut -d'|' -f1)
  echo "$ACTIVE_MODEL" > "$MODELS_DIR/active_model.txt"
  echo "[LLM] Modèle actif par défaut: $ACTIVE_MODEL"
fi

# Démarrer le service Ollama
echo "[LLM] Démarrage du service Ollama..."
sudo systemctl enable ollama.service
sudo systemctl start ollama.service

# Attendre que le service soit prêt
sleep 5

# Copier les Modelfiles depuis lib/models vers le répertoire de données
echo "[LLM] Copie des Modelfiles..."
if [[ -d "$MODELS_SOURCE_DIR" ]]; then
  # Copier les Modelfiles et adapter le chemin du modèle actif
  # S'assurer que ACTIVE_MODEL a une valeur même si $MODELS_CONFIG est vide
  if [[ -z "${ACTIVE_MODEL:-}" ]]; then
    if [[ -f "$MODELS_DIR/active_model.txt" ]]; then
      ACTIVE_MODEL=$(cat "$MODELS_DIR/active_model.txt" 2>/dev/null || true)
    fi
    if [[ -z "${ACTIVE_MODEL:-}" ]]; then
      ACTIVE_MODEL=$(ls -1 "$MODELS_DIR" 2>/dev/null | grep -E '\.gguf$' | head -n1 || true)
    fi
  fi
  for src_modelfile in "$MODELS_SOURCE_DIR"/Modelfile.*; do
    if [[ -f "$src_modelfile" ]]; then
      persona=$(basename "$src_modelfile" | sed 's/^Modelfile\.//')
      dest_modelfile="$MODELFILES_DIR/Modelfile.$persona"
      
      # Remplacer le chemin du modèle par le modèle actif (protéger expansion si vide)
      sed "s|FROM /opt/balorsh/data/llm/models/.*\\.gguf|FROM /opt/balorsh/data/llm/models/${ACTIVE_MODEL:-senecallm-q4_k_m.gguf}|g" \
        "$src_modelfile" > "$dest_modelfile"
    fi
  done
  echo "[LLM] Modelfiles copiés et adaptés au modèle actif"
else
  echo "[LLM] Attention: Répertoire $MODELS_SOURCE_DIR non trouvé"
fi

# Créer les modèles Ollama pour chaque Modelfile trouvé
echo "[LLM] Création des modèles Ollama..."
for modelfile in "$MODELFILES_DIR"/Modelfile.*; do
  if [[ -f "$modelfile" ]]; then
    persona=$(basename "$modelfile" | sed 's/^Modelfile\.//')
    echo "[LLM] Création du modèle balor:$persona..."
    ollama create "balor:$persona" -f "$modelfile" 2>/dev/null || true
  fi
done

# Mettre à jour le JSON des modèles pour refléter l'état actuel
update_models_json || true

# Créer le dossier data pour marquer l'installation
ensure_stack_data_dir "llm"

echo "[LLM] Installation terminée!"
echo "[LLM] Modèle(s) installé(s):"
cat "$MODELS_CONFIG" 2>/dev/null | while IFS='|' read -r filename display; do
  echo "  - $display ($filename)"
done
echo "[LLM] ${LLM_INSTALL_ACTIVE_MODEL} $ACTIVE_MODEL"
echo ""
echo "[LLM] ${LLM_INSTALL_PERSONAS_AVAILABLE}"
ollama list | grep balor || echo "  ${LLM_INSTALL_PERSONAS_LATER}"
