# Stack LLM - Multi-Modèles IA

La stack LLM de Balor supporte maintenant plusieurs modèles IA.

## Installation

Lors de l'installation, vous pouvez choisir parmi :

1. **Seneca Cybersecurity LLM** (7B, Q4_K_M) - Recommandé
   - Spécialisé en cybersécurité
   - Optimisé pour l'analyse de logs et la sécurité

2. **WhiteRabbitNeo 2.5 Qwen Coder** (7B, Q4_K_M)
   - Spécialisé en code et offensive security
   - Excellentes capacités de programmation

3. **Les deux modèles**
   - Vous pourrez switcher entre les deux

4. **Modèle personnalisé**
   - Fournissez une URL vers un fichier GGUF

## Utilisation

### Menu LLM

Le menu propose :

**MODÈLES IA**
- **1. Charger/Changer de modèle IA** - Switcher entre les modèles installés
- **2. Supprimer un modèle IA** - Supprimer un modèle et ses personas

**INTERACTION**
- **3. Analyser un log** - Soumettre un fichier log à l'IA
- **4. Chat avec l'IA** - Conversation interactive

**PERSONAS** (dynamiques)
- Liste automatique basée sur les Modelfiles disponibles

**SYSTÈME**
- Arrêter Ollama
- Voir conversations
- Voir analyses

### Changement de modèle

Quand vous changez de modèle actif :
1. Tous les Modelfiles sont recréés avec le nouveau modèle
2. Tous les personas Ollama sont recréés
3. Le nouveau modèle devient actif immédiatement

### Suppression de modèle

Lors de la suppression d'un modèle :
1. Le fichier GGUF est supprimé
2. Il est retiré de la configuration
3. Si c'était le modèle actif, un autre est sélectionné automatiquement
4. Les personas Ollama ne sont pas supprimés (mais seront invalides)

## Fichiers de configuration

- `/opt/balorsh/data/llm/models/models.conf` - Liste des modèles installés
- `/opt/balorsh/data/llm/models/active_model.txt` - Modèle actuellement actif
- `/opt/balorsh/data/llm/models/*.gguf` - Fichiers des modèles
- `/opt/balorsh/data/llm/modelfiles/Modelfile.*` - Définitions des personas

## Ajouter un nouveau modèle

Pour ajouter manuellement un modèle après installation :

```bash
# Télécharger le modèle
cd /opt/balorsh/data/llm/models
curl -L -o monmodele.gguf "URL_DU_MODELE"

# Ajouter à la configuration
echo "monmodele.gguf|Mon Modèle Personnalisé" >> models.conf

# Le modèle apparaîtra dans le menu option 1
```

## Personas

Les personas sont automatiquement adaptés au modèle actif. Les Modelfiles sources dans `lib/models/` sont copiés et modifiés pour pointer vers le bon modèle.

Pour ajouter un persona, voir [lib/models/README.md](../../lib/models/README.md).
