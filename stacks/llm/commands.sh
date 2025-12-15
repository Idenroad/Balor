#!/usr/bin/env bash
set -Eeuo pipefail

# stacks/llm/commands.sh
# Menu LLM/IA pour balorsh avec modèle Seneca Cybersecurity

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"
# shellcheck source=../../lib/common.sh
source "$ROOT_DIR/lib/common.sh"

# alias locaux pour la lisibilité
C_RESET="${C_RESET:-\033[0m}"
C_BOLD="${C_BOLD:-\033[1m}"
C_ACCENT1="${C_ACCENT1:-\033[38;2;117;30;233m}"
C_ACCENT2="${C_ACCENT2:-\033[38;2;144;117;226m}"
C_GOOD="${C_GOOD:-\033[38;2;6;251;6m}"
C_HIGHLIGHT="${C_HIGHLIGHT:-\033[38;2;37;253;157m}"
C_RED="\e[31m"
C_YELLOW="\e[33m"
C_INFO="\e[36m"
C_SHADOW="\e[90m"

# Variables globales
: "${BALORSH_DATA_DIR:=/opt/balorsh/data}"
LLM_LOGS_DIR="$BALORSH_DATA_DIR/llm/logs"
LLM_CONVERSATIONS_DIR="$BALORSH_DATA_DIR/llm/conversations"
LLM_MODELS_DIR="$BALORSH_DATA_DIR/llm/models"
LLM_MODELFILES_DIR="$BALORSH_DATA_DIR/llm/modelfiles"
MODELS_CONFIG="$LLM_MODELS_DIR/models.conf"
ACTIVE_MODEL_FILE="$LLM_MODELS_DIR/active_model.txt"
CURRENT_PERSONA="base"
OLLAMA_RUNNING=false

# Créer les répertoires nécessaires
mkdir -p "$LLM_LOGS_DIR"
mkdir -p "$LLM_CONVERSATIONS_DIR"
mkdir -p "$LLM_MODELS_DIR"
mkdir -p "$LLM_MODELFILES_DIR"

# ==============================================================================
# FONCTIONS DE ${LLM_MENU_SECTION_GESTION} DES ${LLM_MENU_SECTION_MODELS}
# ==============================================================================

# Obtenir le modèle actif
get_active_model() {
  if [[ -f "$ACTIVE_MODEL_FILE" ]]; then
    cat "$ACTIVE_MODEL_FILE"
  else
    echo "senecallm-q4_k_m.gguf"
  fi
}

# Lister les modèles installés
list_installed_models() {
  local -a models=()
  if [[ -f "$MODELS_CONFIG" ]]; then
    while IFS='|' read -r filename display; do
      if [[ -f "$LLM_MODELS_DIR/$filename" ]]; then
        echo "$filename|$display"
      fi
    done < "$MODELS_CONFIG"
  fi
}

# Changer de modèle actif
switch_active_model() {
  echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "                ${C_GOOD}${LLM_SWITCH_TITLE}${C_RESET}                     "
  echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
  
  # Liste les modèles Ollama installés avec balorsh
  if check_ollama_installed; then
    local ollama_models=$(ollama list 2>/dev/null | grep "^balor:" | awk '{print $1}' || true)
    if [[ -n "$ollama_models" ]]; then
      echo -e "  ${C_GOOD}${LLM_MODELS_OLLAMA}${C_RESET}"
      while IFS= read -r model_name; do
        local persona=$(echo "$model_name" | sed 's/^balor://')
        echo -e "    ${C_SHADOW}●${C_RESET} ${C_INFO}$model_name${C_RESET}"
      done <<< "$ollama_models"
      echo ""
    fi
  fi
  
  # Liste les modèles GGUF de base
  echo -e "  ${C_HIGHLIGHT}${LLM_MODELS_GGUF}${C_RESET}"
  echo ""
  
  local -a model_files=()
  local -a model_names=()
  local count=1
  
  while IFS='|' read -r filename display; do
    echo -e "  ${C_HIGHLIGHT}$count)${C_RESET} ${C_INFO}$display${C_RESET}"
    echo -e "     ${C_SHADOW}($filename)${C_RESET}"
    model_files+=("$filename")
    model_names+=("$display")
    ((count++))
  done < <(list_installed_models)
  
  if [[ ${#model_files[@]} -eq 0 ]]; then
    echo -e "${C_RED}${LLM_NO_MODELS}${C_RESET}"
    echo -e "${C_YELLOW}${LLM_DOWNLOAD_PROMPT}${C_RESET}"
    echo ""
    echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
    read -r
    return 0
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_CHOOSE_MODEL} [1-${#model_files[@]}] (0 ${LLM_CANCEL}): ${C_RESET}"
  read -r choice
  
  if [[ "$choice" == "0" ]]; then
    return 0
  fi
  
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#model_files[@]} )); then
    local selected_model="${model_files[$((choice-1))]}"
    local selected_name="${model_names[$((choice-1))]}"
    
    echo "$selected_model" > "$ACTIVE_MODEL_FILE"
    echo -e "${C_GOOD}${LLM_MODEL_CHANGED} $selected_name${C_RESET}"
    echo -e "${C_INFO}${LLM_RECREATING_PERSONAS}${C_RESET}"
    
    # Recréer tous les Modelfiles avec le nouveau modèle
    for src_modelfile in "$ROOT_DIR/lib/models"/Modelfile.*; do
      if [[ -f "$src_modelfile" ]]; then
        persona=$(basename "$src_modelfile" | sed 's/^Modelfile\.//')
        dest_modelfile="$LLM_MODELFILES_DIR/Modelfile.$persona"
        
        sed "s|FROM /opt/balorsh/data/llm/models/.*\.gguf|FROM $LLM_MODELS_DIR/$selected_model|g" \
          "$src_modelfile" > "$dest_modelfile"
        
        # Supprimer et recréer le modèle Ollama
        ollama rm "balor:$persona" 2>/dev/null || true
        ollama create "balor:$persona" -f "$dest_modelfile" 2>/dev/null || true
      fi
    done
    
    echo -e "${C_GOOD}${LLM_PERSONAS_SUCCESS}${C_RESET}"
  else
    echo -e "${C_RED}${LLM_INVALID_CHOICE}${C_RESET}"
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
  read -r
}

# ${LLM_MENU_3}
delete_ai_model() {
  echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "              ${C_RED}${LLM_DELETE_TITLE}${C_RESET}                     "
  echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
  
  local -a model_files=()
  local -a model_names=()
  local count=1
  local active_model=$(get_active_model)
  
  while IFS='|' read -r filename display; do
    local marker=""
    if [[ "$filename" == "$active_model" ]]; then
      marker=" ${C_GOOD}[ACTIF]${C_RESET}"
    fi
    echo -e "  ${C_HIGHLIGHT}$count)${C_RESET} ${C_INFO}$display${C_RESET}$marker"
    echo -e "     ${C_SHADOW}($filename)${C_RESET}"
    model_files+=("$filename")
    model_names+=("$display")
    ((count++))
  done < <(list_installed_models)
  
  if [[ ${#model_files[@]} -eq 0 ]]; then
    echo -e "${C_RED}${LLM_NO_MODELS}${C_RESET}"
    echo -e "${C_YELLOW}${LLM_DOWNLOAD_PROMPT}${C_RESET}"
    echo ""
    echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
    read -r
    return 0
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_CHOOSE_MODEL} à supprimer [1-${#model_files[@]}] (0 ${LLM_CANCEL}): ${C_RESET}"
  read -r choice
  
  if [[ "$choice" == "0" ]]; then
    return 0
  fi
  
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#model_files[@]} )); then
    local selected_model="${model_files[$((choice-1))]}"
    local selected_name="${model_names[$((choice-1))]}"
    
    echo ""
    echo -e "${C_YELLOW}${LLM_DELETE_WARNING}${C_RESET}"
    echo -e "  ${LLM_DELETE_FILE} $selected_model"
    echo -e "  ${LLM_DELETE_PERSONAS}"
    echo ""
    echo -ne "${C_RED}Êtes-vous sûr? [o/N]: ${C_RESET}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[oOyY]$ ]]; then
      # Supprimer tous les personas Ollama associés à ce modèle
      if check_ollama_installed; then
        echo -e "${C_INFO}${LLM_DELETING_PERSONAS}${C_RESET}"
        local ollama_models=$(ollama list 2>/dev/null | grep "^balor:" | awk '{print $1}' || true)
        if [[ -n "$ollama_models" ]]; then
          while IFS= read -r model_name; do
            echo -e "  ${C_SHADOW}- Suppression de $model_name${C_RESET}"
            ollama rm "$model_name" &>/dev/null || true
          done <<< "$ollama_models"
        fi
      fi
      
      # Supprimer le fichier du modèle
      rm -f "$LLM_MODELS_DIR/$selected_model"
      
      # Supprimer de la config
      grep -v "^$selected_model|" "$MODELS_CONFIG" > "$MODELS_CONFIG.tmp" 2>/dev/null || true
      mv "$MODELS_CONFIG.tmp" "$MODELS_CONFIG" 2>/dev/null || true
      
      # Si c'était le modèle actif, sélectionner un autre
      if [[ "$selected_model" == "$active_model" ]]; then
        local new_active=$(list_installed_models | head -n1 | cut -d'|' -f1)
        if [[ -n "$new_active" ]]; then
          echo "$new_active" > "$ACTIVE_MODEL_FILE"
          echo -e "${C_INFO}${LLM_NEW_ACTIVE} $new_active${C_RESET}"
        else
          rm -f "$ACTIVE_MODEL_FILE"
          echo -e "${C_YELLOW}${LLM_NO_MORE_MODELS}${C_RESET}"
        fi
      fi
      
      echo -e "${C_GOOD}Modèle $selected_name ${LLM_DELETED}${C_RESET}"
    else
      echo -e "${C_INFO}${LLM_DELETE_CANCELLED}${C_RESET}"
    fi
  else
    echo -e "${C_RED}${LLM_INVALID_CHOICE}${C_RESET}"
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
  read -r
}

# ${LLM_MENU_3}
delete_ai_model() {
  echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "                ${C_RED}${LLM_DELETE_TITLE}${C_RESET}                     "
  echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
  
  local -a model_files=()
  local -a model_names=()
  local count=1
  local active_model=$(get_active_model)
  
  while IFS='|' read -r filename display; do
    local marker=""
    if [[ "$filename" == "$active_model" ]]; then
      marker=" ${C_GOOD}[ACTIF]${C_RESET}"
    fi
    echo -e "  ${C_HIGHLIGHT}$count)${C_RESET} ${C_INFO}$display${C_RESET}$marker"
    echo -e "     ${C_SHADOW}($filename)${C_RESET}"
    model_files+=("$filename")
    model_names+=("$display")
    ((count++))
  done < <(list_installed_models)
  
  if [[ ${#model_files[@]} -eq 0 ]]; then
    echo -e "${C_RED}${LLM_NO_MODELS}${C_RESET}"
    echo ""
    echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
    read -r
    return 1
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_CHOOSE_MODEL} à supprimer [1-${#model_files[@]}] (0 ${LLM_CANCEL}): ${C_RESET}"
  read -r choice
  
  if [[ "$choice" == "0" ]]; then
    return 0
  fi
  
  if [[ "$choice" =~ ^[0-9]+$ ]] && (( choice >= 1 && choice <= ${#model_files[@]} )); then
    local selected_model="${model_files[$((choice-1))]}"
    local selected_name="${model_names[$((choice-1))]}"
    
    echo ""
    echo -e "${C_YELLOW}${LLM_DELETE_WARNING}${C_RESET}"
    echo -e "  ${LLM_DELETE_FILE} $selected_model"
    echo -e "  ${LLM_DELETE_PERSONAS}"
    echo ""
    echo -ne "${C_RED}Êtes-vous sûr? [o/N]: ${C_RESET}"
    read -r confirm
    
    if [[ "$confirm" =~ ^[oOyY]$ ]]; then
      # Supprimer tous les personas Ollama associés à ce modèle
      if check_ollama_installed; then
        echo -e "${C_INFO}${LLM_DELETING_PERSONAS}${C_RESET}"
        local ollama_models=$(ollama list 2>/dev/null | grep "^balor:" | awk '{print $1}' || true)
        if [[ -n "$ollama_models" ]]; then
          while IFS= read -r model_name; do
            echo -e "  ${C_SHADOW}- Suppression de $model_name${C_RESET}"
            ollama rm "$model_name" &>/dev/null || true
          done <<< "$ollama_models"
        fi
      fi
      
      # Supprimer le fichier du modèle
      rm -f "$LLM_MODELS_DIR/$selected_model"
      
      # Supprimer de la config
      grep -v "^$selected_model|" "$MODELS_CONFIG" > "$MODELS_CONFIG.tmp" 2>/dev/null || true
      mv "$MODELS_CONFIG.tmp" "$MODELS_CONFIG" 2>/dev/null || true
      
      # Si c'était le modèle actif, sélectionner un autre
      if [[ "$selected_model" == "$active_model" ]]; then
        local new_active=$(list_installed_models | head -n1 | cut -d'|' -f1)
        if [[ -n "$new_active" ]]; then
          echo "$new_active" > "$ACTIVE_MODEL_FILE"
          echo -e "${C_INFO}${LLM_NEW_ACTIVE} $new_active${C_RESET}"
        else
          rm -f "$ACTIVE_MODEL_FILE"
          echo -e "${C_YELLOW}${LLM_NO_MORE_MODELS}${C_RESET}"
        fi
      fi
      
      echo -e "${C_GOOD}Modèle $selected_name ${LLM_DELETED}${C_RESET}"
    else
      echo -e "${C_INFO}${LLM_DELETE_CANCELLED}${C_RESET}"
    fi
  else
    echo -e "${C_RED}${LLM_INVALID_CHOICE}${C_RESET}"
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
  read -r
}

# ${LLM_MENU_2}
download_new_llm() {
  echo ""
  echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "              ${C_GOOD}${LLM_DOWNLOAD_TITLE}${C_RESET}                   "
  echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
  
  echo -e "${C_HIGHLIGHT}${LLM_DOWNLOAD_PRECONFIGURED}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${LLM_DOWNLOAD_OPT1}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${LLM_DOWNLOAD_OPT2}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${LLM_DOWNLOAD_OPT3}${C_RESET}"
  echo -e "  ${C_HIGHLIGHT}0)${C_RESET} ${C_YELLOW}Annuler${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${LLM_YOUR_CHOICE}${C_RESET} "
  read -r choice
  
  local url=""
  local filename=""
  local display_name=""
  
  case "$choice" in
    1)
      url="https://huggingface.co/AlicanKiraz0/Seneca-Cybersecurity-LLM-Q4_K_M-GGUF/resolve/main/senecallm-q4_k_m.gguf"
      filename="senecallm-q4_k_m.gguf"
      display_name="Seneca Cybersecurity LLM"
      ;;
    2)
      url="https://huggingface.co/tensorblock/WhiteRabbitNeo-2.5-Qwen-2.5-Coder-7B-GGUF/resolve/main/WhiteRabbitNeo-2.5-Qwen-2.5-Coder-7B-Q4_K_M.gguf"
      filename="whiterabbitneo-2.5-qwen-2.5-coder-7b-q4_k_m.gguf"
      display_name="WhiteRabbitNeo 2.5 Qwen Coder"
      ;;
    3)
      echo ""
      echo -ne "${C_ACCENT1}${LLM_CUSTOM_URL} ${C_RESET}"
      read -r url
      echo -ne "${C_ACCENT1}${LLM_CUSTOM_FILENAME} ${C_RESET}"
      read -r filename
      echo -ne "${C_ACCENT1}${LLM_CUSTOM_DISPLAY} ${C_RESET}"
      read -r display_name
      ;;
    0)
      return 0
      ;;
    *)
      echo -e "${C_RED}${LLM_INVALID_CHOICE}${C_RESET}"
      sleep 1
      return 1
      ;;
  esac
  
  # Vérifier si le modèle existe déjà
  if [[ -f "$LLM_MODELS_DIR/$filename" ]]; then
    echo ""
    printf "${C_YELLOW}${LLM_MODEL_EXISTS}${C_RESET}\n" "$filename"
    echo -ne "${C_ACCENT1}${LLM_REDOWNLOAD_CONFIRM}${C_RESET} "
    read -r confirm
    if [[ ! "$confirm" =~ ^[oOyY]$ ]]; then
      return 0
    fi
    rm -f "$LLM_MODELS_DIR/$filename"
  fi
  
  echo ""
  printf "${C_INFO}${LLM_DOWNLOADING}${C_RESET}\n" "$display_name"
  echo -e "${C_SHADOW}${LLM_DOWNLOAD_URL} $url${C_RESET}"
  echo -e "${C_SHADOW}${LLM_DOWNLOAD_DEST} $LLM_MODELS_DIR/$filename${C_RESET}"
  echo ""
  
  if curl -L --progress-bar -o "$LLM_MODELS_DIR/$filename" "$url"; then
    echo ""
    echo -e "${C_GOOD}${LLM_DOWNLOAD_SUCCESS}${C_RESET}"
    
    # Ajouter à models.conf si pas déjà présent
    if ! grep -q "^$filename|" "$MODELS_CONFIG" 2>/dev/null; then
      echo "$filename|$display_name" >> "$MODELS_CONFIG"
      echo -e "${C_INFO}${LLM_ADDED_CONFIG}${C_RESET}"
    fi
    
    # Définir comme modèle actif
    echo "$filename" > "$ACTIVE_MODEL_FILE"
    echo -e "${C_INFO}${LLM_SET_ACTIVE}${C_RESET}"
    
    # Créer les personas avec ce nouveau modèle
    echo ""
    echo -e "${C_INFO}${LLM_CREATING_PERSONAS}${C_RESET}"
    if [[ -d "$ROOT_DIR/lib/models" ]]; then
      for modelfile in "$ROOT_DIR/lib/models"/Modelfile.*; do
        if [[ -f "$modelfile" ]]; then
          local persona_name="${modelfile##*/Modelfile.}"
          local dest_file="$LLM_MODELFILES_DIR/Modelfile.$persona_name"
          
          # Adapter le Modelfile au nouveau modèle
          sed "s|FROM /opt/balorsh/data/llm/models/.*\.gguf|FROM $LLM_MODELS_DIR/$filename|g" \
            "$modelfile" > "$dest_file"
          
          # Créer le modèle Ollama
          if check_ollama_installed && check_ollama; then
            echo -e "  ${C_SHADOW}- Création de balor:$persona_name${C_RESET}"
            ollama create "balor:$persona_name" -f "$dest_file" &>/dev/null || true
          fi
        fi
      done
    fi
    
    echo ""
    echo -e "${C_GOOD}${LLM_INSTALL_COMPLETE}${C_RESET}"
  else
    echo ""
    echo -e "${C_RED}${LLM_DOWNLOAD_FAILED}${C_RESET}"
    rm -f "$LLM_MODELS_DIR/$filename"
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
  read -r
}

# Effacer les conversations sauvegardées
clear_conversations() {
  echo ""
  echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "            ${C_RED}${LLM_CLEAR_CONV_TITLE}${C_RESET}              "
  echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
  
  local count=$(find "$LLM_CONVERSATIONS_DIR" -type f 2>/dev/null | wc -l)
  
  if [[ $count -eq 0 ]]; then
    echo -e "${C_INFO}${LLM_NO_CONVERSATIONS} sauvegardée${C_RESET}"
  else
    printf "${C_YELLOW}${LLM_CONVERSATIONS_WARNING}${C_RESET}\n" "$count"
    echo ""
    ls -lh "$LLM_CONVERSATIONS_DIR" 2>/dev/null
    echo ""
    echo -ne "${C_RED}${LLM_DELETE_ALL_CONFIRM}${C_RESET} "
    read -r confirm
    
    if [[ "$confirm" =~ ^[oOyY]$ ]]; then
      rm -f "$LLM_CONVERSATIONS_DIR"/*
      echo ""
      echo -e "${C_GOOD}${LLM_CONVERSATIONS_DELETED}${C_RESET}"
    else
      echo -e "${C_INFO}${LLM_CANCELLED}${C_RESET}"
    fi
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
  read -r
}

# Effacer les analyses de logs
clear_log_analyses() {
  echo ""
  echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "              ${C_RED}${LLM_CLEAR_LOGS_TITLE}${C_RESET}                    "
  echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
  
  local count=$(find "$LLM_LOGS_DIR" -type f 2>/dev/null | wc -l)
  
  if [[ $count -eq 0 ]]; then
    echo -e "${C_INFO}${LLM_NO_ANALYSES} de log sauvegardée${C_RESET}"
  else
    printf "${C_YELLOW}${LLM_ANALYSES_WARNING}${C_RESET}\n" "$count"
    echo ""
    ls -lh "$LLM_LOGS_DIR" 2>/dev/null
    echo ""
    echo -ne "${C_RED}${LLM_DELETE_ALL_CONFIRM}${C_RESET} "
    read -r confirm
    
    if [[ "$confirm" =~ ^[oOyY]$ ]]; then
      rm -f "$LLM_LOGS_DIR"/*
      echo ""
      echo -e "${C_GOOD}${LLM_ANALYSES_DELETED}${C_RESET}"
    else
      echo -e "${C_INFO}${LLM_CANCELLED}${C_RESET}"
    fi
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
  read -r
}

# ${LLM_MENU_GESTION_7}
clear_all_data() {
  echo ""
  echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "          ${C_RED}${LLM_CLEAR_ALL_TITLE}${C_RESET}             "
  echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
  
  local conv_count=$(find "$LLM_CONVERSATIONS_DIR" -type f 2>/dev/null | wc -l)
  local log_count=$(find "$LLM_LOGS_DIR" -type f 2>/dev/null | wc -l)
  local total=$((conv_count + log_count))
  
  if [[ $total -eq 0 ]]; then
    echo -e "${C_INFO}${LLM_NO_DATA}${C_RESET}"
  else
    echo -e "${C_YELLOW}${LLM_DATA_WARNING}${C_RESET}"
    echo -e "  - ${LLM_DATA_CONVERSATIONS} $conv_count fichier(s)"
    echo -e "  - ${LLM_ANALYSES} $log_count fichier(s)"
    echo -e "  ${C_RED}${LLM_DATA_TOTAL} $total fichier(s)${C_RESET}"
    echo ""
    echo -ne "${C_RED}${LLM_DELETE_ALL_CONFIRM}${C_RESET} "
    read -r confirm
    
    if [[ "$confirm" =~ ^[oOyY]$ ]]; then
      rm -f "$LLM_CONVERSATIONS_DIR"/*
      rm -f "$LLM_LOGS_DIR"/*
      echo ""
      echo -e "${C_GOOD}${LLM_ALL_DATA_DELETED}${C_RESET}"
    else
      echo -e "${C_INFO}${LLM_CANCELLED}${C_RESET}"
    fi
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
  read -r
}

# ==============================================================================
# FONCTIONS DE ${LLM_MENU_SECTION_GESTION} OLLAMA
# ==============================================================================

# Vérifier si Ollama est installé
check_ollama_installed() {
  if ! command -v ollama &>/dev/null; then
    return 1
  fi
  return 0
}

# Vérifier si Ollama est en cours d'exécution
check_ollama() {
  if ! check_ollama_installed; then
    OLLAMA_RUNNING=false
    return 1
  fi
  
  if systemctl is-active --quiet ollama.service 2>/dev/null; then
    OLLAMA_RUNNING=true
    return 0
  else
    OLLAMA_RUNNING=false
    return 1
  fi
}

# Démarrer Ollama avec un persona spécifique
start_ollama_persona() {
  local persona="$1"
  
  if ! check_ollama_installed; then
    echo -e "${C_RED}${LLM_OLLAMA_ERROR}. ${LLM_OLLAMA_INSTALL_STACK}${C_RESET}"
    return 1
  fi
  
  echo -e "${C_INFO}${LLM_OLLAMA_STOPPING}${C_RESET}"
  sudo systemctl stop ollama.service 2>/dev/null || true
  sleep 2
  
  echo -e "${C_INFO}${LLM_OLLAMA_STARTING} ${C_HIGHLIGHT}$persona${C_RESET}"
  sudo systemctl start ollama.service
  sleep 3
  
  # Vérifier que le modèle existe
  if ! ollama list 2>/dev/null | grep -q "balor:$persona"; then
    printf "${C_YELLOW}${LLM_MODEL_NOT_EXISTS} ${LLM_OLLAMA_NOT_EXISTS2}${C_RESET}\n" "$persona"
    local modelfile="/opt/balorsh/data/llm/modelfiles/Modelfile.$persona"
    if [[ -f "$modelfile" ]]; then
      ollama create "balor:$persona" -f "$modelfile"
      printf "${C_GOOD}${LLM_MODEL_CREATED}${C_RESET}\n" "$persona"
    else
      echo -e "${C_RED}${LLM_OLLAMA_MODELFILE_NOT_FOUND} $modelfile${C_RESET}"
      return 1
    fi
  fi
  
  CURRENT_PERSONA="$persona"
  OLLAMA_RUNNING=true
  echo -e "${C_GOOD}${LLM_OLLAMA_STARTED} $persona${C_RESET}"
}

# Arrêter Ollama
stop_ollama() {
  if ! check_ollama_installed; then
    echo -e "${C_RED}${LLM_OLLAMA_NOT_INSTALLED}${C_RESET}"
    return 1
  fi
  
  echo -e "${C_INFO}${LLM_OLLAMA_STOPPING}${C_RESET}"
  sudo systemctl stop ollama.service 2>/dev/null || true
  OLLAMA_RUNNING=false
  echo -e "${C_GOOD}${LLM_OLLAMA_STOPPED}${C_RESET}"
}

# ==============================================================================
# FONCTIONS D'${LLM_MENU_SECTION_INTERACTION} IA
# ==============================================================================

# Ouvrir le gestionnaire de fichiers approprié
open_file_manager() {
  local path="${1:-$HOME}"
  
  # Détection du gestionnaire de fichiers
  if command -v dolphin &>/dev/null; then
    dolphin "$path" &>/dev/null &
  elif command -v nautilus &>/dev/null; then
    nautilus "$path" &>/dev/null &
  elif command -v thunar &>/dev/null; then
    thunar "$path" &>/dev/null &
  elif command -v nemo &>/dev/null; then
    nemo "$path" &>/dev/null &
  elif command -v caja &>/dev/null; then
    caja "$path" &>/dev/null &
  elif command -v pcmanfm &>/dev/null; then
    pcmanfm "$path" &>/dev/null &
  elif command -v xdg-open &>/dev/null; then
    xdg-open "$path" &>/dev/null &
  else
    echo -e "${C_YELLOW}${LLM_NO_FILE_MANAGER}${C_RESET}"
    return 1
  fi
}

# Chat interactif avec l'IA
llm_chat() {
  if ! check_ollama; then
    echo -e "${C_YELLOW}${LLM_OLLAMA_NOT_STARTED}${C_RESET}"
    start_ollama_persona "$CURRENT_PERSONA"
  fi
  
  local conversation_file="$LLM_CONVERSATIONS_DIR/chat_$(date +%Y%m%d_%H%M%S).txt"
  local active_model=$(get_active_model)
  local active_model_name=$(grep "^$active_model|" "$MODELS_CONFIG" 2>/dev/null | cut -d'|' -f2 || echo "IA")
  
  clear
  echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "        ${C_GOOD}Chat $active_model_name - ${LLM_PERSONA} ${C_HIGHLIGHT}$CURRENT_PERSONA${C_RESET}        "
  echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
  echo -e "${C_INFO}${LLM_CHAT_INSTRUCTION_1}${C_RESET}"
  echo -e "${C_INFO}${LLM_CHAT_INSTRUCTION_2}${C_RESET}"
  echo -e "${C_INFO}${LLM_CHAT_INSTRUCTION_3}${C_RESET}"
  echo ""
  
  {
    printf "${LLM_CHAT_HEADER_TITLE}\n" "${LLM_PERSONA}" "$CURRENT_PERSONA"
    echo "${LLM_DATE} $(date)"
    echo "=========================================="
    echo ""
  } > "$conversation_file"
  
  while true; do
    echo -ne "${C_ACCENT1}Vous >${C_RESET} "
    read -r user_input
    
    if [[ -z "$user_input" ]]; then
      continue
    fi
    
    case "$user_input" in
      exit|quit)
        echo -e "${C_GOOD}${LLM_CHAT_GOODBYE}${C_RESET}"
        break
        ;;
      clear)
        clear
        echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
        echo -e "            ${C_GOOD}${LLM_CHAT_TITLE} ${C_HIGHLIGHT}$CURRENT_PERSONA${C_RESET}        "
        echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
        echo ""
        continue
        ;;
    esac
    
    # Sauvegarder la question
    echo "${LLM_YOU_LABEL} $user_input" >> "$conversation_file"
    
    # Envoyer à Ollama et afficher la réponse
    echo -ne "${C_HIGHLIGHT}${LLM_CHAT_BALOR}${C_RESET} "
    ollama run "balor:$CURRENT_PERSONA" "$user_input" | tee -a "$conversation_file"
    echo ""
  done
  
  echo -e "${C_INFO}${LLM_CHAT_SAVED} $conversation_file${C_RESET}"
}

# Analyser un fichier log avec l'IA
llm_analyze_log() {
  if ! check_ollama; then
    echo -e "${C_YELLOW}${LLM_LOG_STARTING}${C_RESET}"
    start_ollama_persona "loganalyst"
  fi
  
  local active_model=$(get_active_model)
  local active_model_name=$(grep "^$active_model|" "$MODELS_CONFIG" 2>/dev/null | cut -d'|' -f2 || echo "IA")
  
  echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "            ${C_GOOD}${LLM_LOG_TITLE} $active_model_name${C_RESET}              "
  echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
  echo -e "${C_INFO}${LLM_LOG_OPENING_BROWSER}${C_RESET}"
  echo -e "${C_INFO}${LLM_LOG_NAVIGATE}${C_RESET}"
  echo ""
  
  # Ouvrir le gestionnaire de fichiers dans le répertoire de données
  open_file_manager /opt/balorsh/data
  
  echo -e "${C_ACCENT1}${LLM_LOG_ENTER_PATH}${C_RESET}"
  echo -ne "${C_HIGHLIGHT}${LLM_LOG_FILE_PROMPT}${C_RESET} "
  read -r logfile
  
  if [[ ! -f "$logfile" ]]; then
    printf "${C_RED}${LLM_LOG_NOT_FOUND} %s${C_RESET}\n" "$logfile"
    return 1
  fi
  
  # Créer une version texte si nécessaire dans le répertoire LLM
  local logfile_txt="$logfile"
  local file_ext="${logfile##*.}"
  local filename=$(basename "$logfile")
  
  # Convertir certains formats en texte dans le répertoire LLM
  case "$file_ext" in
    xml)
      echo -e "${C_INFO}${LLM_LOG_CONVERTING_XML}${C_RESET}"
      logfile_txt="$LLM_LOGS_DIR/${filename%.xml}.txt"
      xmllint --format "$logfile" > "$logfile_txt" 2>/dev/null || cat "$logfile" > "$logfile_txt"
      echo -e "${C_GOOD}${LLM_LOG_FILE_CONVERTED} $logfile_txt${C_RESET}"
      ;;
    pcap|cap)
      echo -e "${C_INFO}${LLM_LOG_EXTRACTING_PCAP}${C_RESET}"
      logfile_txt="$LLM_LOGS_DIR/${filename%.*}_summary.txt"
      if [[ -f "$logfile_txt" ]]; then
        echo -e "${C_GOOD}${LLM_LOG_SUMMARY_FOUND} $logfile_txt${C_RESET}"
      else
        echo -e "${C_YELLOW}${LLM_LOG_GENERATING_SUMMARY}${C_RESET}"
        {
          printf "${LLM_LOG_PCAP_SUMMARY_TITLE}\n" "$logfile"
          echo "${LLM_GENERATED_ON} $(date)"
          echo ""
          sudo tcpdump -r "$logfile" -n 2>&1 | head -n 500
        } > "$logfile_txt"
        echo -e "${C_GOOD}${LLM_LOG_FILE_CONVERTED} $logfile_txt${C_RESET}"
      fi
      ;;
  esac
  
  # Lire le contenu du fichier
  local file_size=$(wc -c < "$logfile_txt")
  local max_size=$((1024 * 1024))  # 1MB max
  
  if (( file_size > max_size )); then
    printf "${C_YELLOW}${LLM_LOG_FILE_LARGE}${C_RESET}\n" "$(numfmt --to=iec $file_size)"
    local log_content=$(head -n 5000 "$logfile_txt")
  else
    local log_content=$(cat "$logfile_txt")
  fi
  
  # Créer le fichier d'analyse
  local analysis_file="$LLM_LOGS_DIR/analysis_$(basename "$logfile_txt" .txt)_$(date +%Y%m%d_%H%M%S).txt"
  
  echo -e "${C_HIGHLIGHT}${LLM_LOG_ANALYZING}${C_RESET}"
  echo ""
  
  {
    echo "${LLM_LOG_HEADER_TITLE}"
    echo "${LLM_DATE} $(date)"
    echo "${LLM_SOURCE_FILE} $logfile"
    echo "${LLM_PERSONA} $CURRENT_PERSONA"
    echo "=========================================="
    echo ""
  } > "$analysis_file"
  
  # Préparer le prompt d'analyse
  local prompt=$(printf "${LLM_LOG_PROMPT_ANALYSIS}" "$log_content")
  
  # Envoyer à Ollama
  echo "$prompt" | ollama run "balor:$CURRENT_PERSONA" | tee -a "$analysis_file"
  
  echo ""
  echo -e "${C_GOOD}${LLM_LOG_COMPLETE} $analysis_file${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
  read -r
}

# Gestion des modèles Ollama
manage_ollama_models() {
  if ! check_ollama_installed; then
    echo -e "${C_RED}${LLM_OLLAMA_ERROR}${C_RESET}"
    echo ""
    echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
    read -r
    return 1
  fi
  
  clear
  echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
  echo -e "                ${C_GOOD}${LLM_MANAGE_TITLE}${C_RESET}                    "
  echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
  echo ""
  
  echo -e "${C_INFO}${LLM_MANAGE_INSTALLED}${C_RESET}"
  echo ""
  ollama list
  echo ""
  
  echo -ne "${C_ACCENT1}${LLM_MANAGE_DELETE_CONFIRM}${C_RESET} "
  read -r confirm
  
  if [[ ! "$confirm" =~ ^[oOyY]$ ]]; then
    return 0
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_MANAGE_ENTER_NAME} ${C_RESET}"
  read -r model_name
  
  if [[ -z "$model_name" ]]; then
    echo -e "${C_RED}${LLM_MANAGE_NO_NAME}${C_RESET}"
    echo ""
    echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
    read -r
    return 1
  fi
  
  # Vérifier que le modèle existe
  if ! ollama list 2>/dev/null | grep -q "^$model_name"; then
    echo -e "${C_RED}Le modèle '$model_name' n'existe pas${C_RESET}"
    echo ""
    echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
    read -r
    return 1
  fi
  
  echo ""
  echo -e "${C_YELLOW}${LLM_MANAGE_WARN_DELETE} $model_name${C_RESET}"
  echo -ne "${C_RED}${LLM_MANAGE_CONFIRM_SURE}${C_RESET} "
  read -r final_confirm
  
  if [[ "$final_confirm" =~ ^[oOyY]$ ]]; then
    echo ""
    printf "${C_INFO}${LLM_MANAGE_DELETING}${C_RESET}\n" "$model_name"
    if ollama rm "$model_name"; then
      printf "${C_GOOD}${LLM_MANAGE_DELETED}${C_RESET}\n" "$model_name"
    else
      echo -e "${C_RED}${LLM_MANAGE_ERROR}${C_RESET}"
    fi
  else
    echo -e "${C_INFO}${LLM_DELETE_CANCELLED}${C_RESET}"
  fi
  
  echo ""
  echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
  read -r
}

# ==============================================================================
# FONCTIONS DE ${LLM_MENU_SECTION_GESTION} DES ${LLM_MENU_SECTION_PERSONAS}
# ==============================================================================

# Récupérer la liste des personas disponibles
get_available_personas() {
  local -a personas=()
  local modelfiles_dir="/opt/balorsh/data/llm/modelfiles"
  
  # Vérifier si le répertoire existe
  if [[ ! -d "$modelfiles_dir" ]]; then
    echo "base"
    return
  fi
  
  # Lister tous les Modelfiles
  for modelfile in "$modelfiles_dir"/Modelfile.*; do
    if [[ -f "$modelfile" ]]; then
      local persona=$(basename "$modelfile" | sed 's/^Modelfile\.//')
      personas+=("$persona")
    fi
  done
  
  # Retourner la liste ou "base" par défaut
  if [[ ${#personas[@]} -eq 0 ]]; then
    echo "base"
  else
    printf '%s\n' "${personas[@]}"
  fi
}

# Obtenir le nom affiché d'un persona
get_persona_display_name() {
  local persona="$1"
  case "$persona" in
    base) echo "${LLM_PERSONA_STANDARD}" ;;
    loganalyst) echo "${LLM_PERSONA_LOGANALYST}" ;;
    redteam) echo "${LLM_PERSONA_REDTEAM}" ;;
    blueteam) echo "${LLM_PERSONA_BLUETEAM}" ;;
    purpleteam) echo "${LLM_PERSONA_PURPLETEAM}" ;;
    *) echo "${persona^}" ;;  # Capitaliser la première lettre
  esac
}

# Obtenir la couleur d'un persona
get_persona_color() {
  local persona="$1"
  case "$persona" in
    base) echo "$C_INFO" ;;
    loganalyst) echo "$C_ACCENT1" ;;
    redteam) echo "$C_RED" ;;
    blueteam) echo "$C_GOOD" ;;
    purpleteam) echo "\e[35m" ;;  # Violet
    *) echo "$C_HIGHLIGHT" ;;
  esac
}

# Changer de persona
llm_switch_persona() {
  local persona="$1"
  local persona_name="$2"
  
  echo -e "${C_INFO}${LLM_PERSONA_SWITCHING} ${C_HIGHLIGHT}$persona_name${C_RESET}"
  start_ollama_persona "$persona"
  echo -e "${C_GOOD}${LLM_PERSONA_ACTIVE} $persona_name${C_RESET}"
  echo ""
  echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
  read -r
}

# ==============================================================================
# MENU PRINCIPAL
# ==============================================================================

stack_menu() {
  # Vérifier l'état d'Ollama au démarrage
  check_ollama || true
  
  # Message si Ollama n'est pas installé
  local ollama_installed=true
  if ! check_ollama_installed; then
    ollama_installed=false
  fi
  
  while true; do
    clear
    
    # Récupérer la liste des personas disponibles à chaque itération
    local -a personas_list=()
    mapfile -t personas_list < <(get_available_personas)
    
    # Afficher le statut
    local status_icon="${C_RED}●${C_RESET}"
    local status_text="${LLM_STOPPED}"
    if [[ "$OLLAMA_RUNNING" == true ]]; then
      status_icon="${C_GOOD}●${C_RESET}"
      status_text="${LLM_RUNNING}"
    fi
    
    echo -e "${C_ACCENT2}╔═══════════════════════════════════════════════════════════════════╗${C_RESET}"
    echo -e "                    ${C_GOOD}${LLM_MENU_TITLE}${C_RESET}                 "
    echo -e "${C_ACCENT2}╚═══════════════════════════════════════════════════════════════════╝${C_RESET}"
    
    # Avertissement si Ollama n'est pas installé
    if [[ "$ollama_installed" == false ]]; then
      echo -e "   ${C_RED}${LLM_WARN_NOT_INSTALLED}${C_RESET}                                    "
      echo -e "   ${C_YELLOW}${LLM_WARN_INSTALL}${C_RESET}                 "
      echo -e "${C_ACCENT2}───────────────────────────────────────────────────────────────────${C_RESET}"
    else
      local active_model=$(get_active_model)
      local active_model_name=$(grep "^$active_model|" "$MODELS_CONFIG" 2>/dev/null | cut -d'|' -f2 || echo "${LLM_UNKNOWN_MODEL}")
      echo -e "   ${C_SHADOW}${LLM_STATUS}${C_RESET} $status_icon $status_text    ${C_SHADOW}${LLM_PERSONA}${C_RESET} ${C_HIGHLIGHT}$CURRENT_PERSONA${C_RESET}"
      echo -e "   ${C_SHADOW}${LLM_MODEL}${C_RESET} ${C_INFO}$active_model_name${C_RESET}"
      echo -e "${C_ACCENT2}───────────────────────────────────────────────────────────────────${C_RESET}"
    fi
    
    echo -e "   ${C_SHADOW}${LLM_MENU_SECTION_MODELS}${C_RESET}                                                     "
    echo -e "   ${C_HIGHLIGHT}1)${C_RESET} ${C_INFO}${LLM_MENU_1}${C_RESET}                            "
    echo -e "   ${C_HIGHLIGHT}2)${C_RESET} ${C_INFO}${LLM_MENU_2}${C_RESET}                       "
    echo -e "   ${C_HIGHLIGHT}3)${C_RESET} ${C_INFO}${LLM_MENU_3}${C_RESET}                                   "
    echo -e "                                                                   "
    
    echo -e "   ${C_SHADOW}${LLM_MENU_SECTION_INTERACTION}${C_RESET}                                                    "
    echo -e "   ${C_HIGHLIGHT}4)${C_RESET} ${C_INFO}${LLM_MENU_4}${C_RESET}                                         "
    echo -e "   ${C_HIGHLIGHT}5)${C_RESET} ${C_INFO}${LLM_MENU_5}${C_RESET}                                          "
    echo -e "                                                                   "
    
    # Générer dynamiquement la section ${LLM_MENU_SECTION_PERSONAS}
    echo -e "   ${C_SHADOW}${LLM_MENU_SECTION_PERSONAS}${C_RESET}                                                       "
    local choice_num=6
    local -A persona_choice_map=()
    for persona in "${personas_list[@]}"; do
      local display_name=$(get_persona_display_name "$persona")
      local color=$(get_persona_color "$persona")
      printf "   %b%d)%b ${LLM_PERSONA} %b%s%b\n" "$C_HIGHLIGHT" "$choice_num" "$C_RESET" "$color" "$display_name" "$C_RESET"
      persona_choice_map[$choice_num]="$persona"
      ((choice_num++))
    done
    echo -e "                                                                   "
    
    # Section ${LLM_MENU_SECTION_GESTION} (numéros dynamiques)
    local manage_start=$choice_num
    echo -e "   ${C_SHADOW}${LLM_MENU_SECTION_GESTION}${C_RESET}                                                        "
    echo -e "   ${C_HIGHLIGHT}$choice_num)${C_RESET} ${C_INFO}${LLM_MENU_GESTION_1}${C_RESET}                                       "
    ((choice_num++))
    echo -e "   ${C_HIGHLIGHT}$choice_num)${C_RESET} ${C_INFO}${LLM_MENU_GESTION_2}${C_RESET}                               "
    ((choice_num++))
    echo -e "   ${C_HIGHLIGHT}$choice_num)${C_RESET} ${C_INFO}${LLM_MENU_GESTION_3}${C_RESET}                         "
    ((choice_num++))
    echo -e "   ${C_HIGHLIGHT}$choice_num)${C_RESET} ${C_INFO}${LLM_MENU_GESTION_4}${C_RESET}                                   "
    ((choice_num++))
    echo -e "   ${C_HIGHLIGHT}$choice_num)${C_RESET} ${C_INFO}${LLM_MENU_GESTION_5}${C_RESET}                                   "
    ((choice_num++))
    echo -e "   ${C_HIGHLIGHT}$choice_num)${C_RESET} ${C_INFO}${LLM_MENU_GESTION_6}${C_RESET}                               "
    ((choice_num++))
    echo -e "   ${C_HIGHLIGHT}$choice_num)${C_RESET} ${C_INFO}${LLM_MENU_GESTION_7}${C_RESET}                           "
    echo -e "                                                                   "
    echo -e "   ${C_HIGHLIGHT}0)${C_RESET} ${C_INFO}${LLM_MENU_0}${C_RESET}"
    echo -e "${C_ACCENT2}═══════════════════════════════════════════════════════════════════${C_RESET}"
    echo -ne "${C_ACCENT1}${LLM_YOUR_CHOICE}${C_RESET} "
    read -r choice

    case "$choice" in
      1) switch_active_model ;;
      2) download_new_llm ;;
      3) delete_ai_model ;;
      4) llm_analyze_log ;;
      5) llm_chat ;;
      0) 
        echo -e "${C_GOOD}${LLM_GOODBYE}${C_RESET}"
        break
        ;;
      *)
        # Vérifier si c'est un choix de persona
        if [[ -v "persona_choice_map[$choice]" ]]; then
          local selected_persona="${persona_choice_map[$choice]}"
          local display_name=$(get_persona_display_name "$selected_persona")
          llm_switch_persona "$selected_persona" "$display_name"
        # Vérifier si c'est une option de gestion
        elif [[ "$choice" == "$manage_start" ]]; then
          manage_ollama_models
        elif [[ "$choice" == "$((manage_start + 1))" ]]; then
          stop_ollama
          echo ""
          echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
          read -r
        elif [[ "$choice" == "$((manage_start + 2))" ]]; then
          echo -e "${C_INFO}${LLM_CONVERSATIONS}${C_RESET}"
          ls -lh "$LLM_CONVERSATIONS_DIR" 2>/dev/null || echo "${LLM_NO_CONVERSATIONS}"
          echo ""
          echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
          read -r
        elif [[ "$choice" == "$((manage_start + 3))" ]]; then
          echo -e "${C_INFO}${LLM_ANALYSES}${C_RESET}"
          ls -lh "$LLM_LOGS_DIR" 2>/dev/null || echo "${LLM_NO_ANALYSES}"
          echo ""
          echo -ne "${C_ACCENT1}${LLM_PRESS_ENTER}${C_RESET}"
          read -r
        elif [[ "$choice" == "$((manage_start + 4))" ]]; then
          clear_conversations
        elif [[ "$choice" == "$((manage_start + 5))" ]]; then
          clear_log_analyses
        elif [[ "$choice" == "$((manage_start + 6))" ]]; then
          clear_all_data
        else
          echo -e "${C_RED}${LLM_INVALID_CHOICE}${C_RESET}"
          sleep 1
        fi
        ;;
    esac
    
    # Rafraîchir le statut
    check_ollama || true
  done
}

# Point d'entrée principal
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  stack_menu
fi
