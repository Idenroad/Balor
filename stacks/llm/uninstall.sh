#!/usr/bin/env bash
set -Eeuo pipefail

# stacks/llm/uninstall.sh
# Désinstallation de la stack LLM

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

echo "[LLM] Désinstallation de la stack LLM..."

# Arrêter le service Ollama
echo "[LLM] Arrêt du service Ollama..."
sudo systemctl stop ollama.service 2>/dev/null || true
sudo systemctl disable ollama.service 2>/dev/null || true

# Supprimer les modèles Ollama créés
echo "[LLM] Suppression des modèles Balor..."
ollama rm balor:base 2>/dev/null || true
ollama rm balor:loganalyst 2>/dev/null || true
ollama rm balor:redteam 2>/dev/null || true
ollama rm balor:blueteam 2>/dev/null || true
ollama rm balor:purpleteam 2>/dev/null || true

# Demander si on supprime les données
echo ""
echo -ne "Voulez-vous supprimer les données LLM (/opt/balorsh/data/llm) ? [o/N]: "
read -r response

if [[ "$response" =~ ^[oOyY]$ ]]; then
  echo "[LLM] Suppression des données..."
  sudo rm -rf /opt/balorsh/data/llm
  echo "[LLM] Données supprimées"
else
  echo "[LLM] Données conservées dans /opt/balorsh/data/llm"
fi

echo "[LLM] Désinstallation terminée!"
echo "[LLM] Note: Ollama reste installé. Désinstallez-le manuellement si nécessaire avec: yay -R ollama"
