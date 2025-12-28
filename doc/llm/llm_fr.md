# Stack LLM - Documentation Complète

La stack LLM de Balor permet d'utiliser des modèles d'IA locaux pour la cybersécurité avec support multi-modèles et personas personnalisables.

## Table des matières

1. [Installation](#installation)
2. [Choix des modèles](#choix-des-modèles)
3. [Utilisation](#utilisation)
4. [Personas](#personas)
5. [Gestion des modèles](#gestion-des-modèles)
6. [Personnalisation](#personnalisation)

---

## Installation

### Prérequis

- Ollama installé (via AUR)
- Au moins 8 GB de RAM disponible
- ~4-5 GB d'espace disque par modèle

### Installation de la stack

```bash
cd /path/to/Balor
sudo bash stacks/llm/install.sh
```

Lors de l'installation, un menu vous propose de choisir le(s) modèle(s) à installer.

---

## Choix des modèles

### Menu d'installation

```
╔════════════════════════════════════════════════════════════════╗
║           Sélection du/des modèle(s) IA à installer           ║
╚════════════════════════════════════════════════════════════════╝

  1) Seneca Cybersecurity LLM (7B, Q4_K_M) - Recommandé
     Spécialisé en cybersécurité

  2) WhiteRabbitNeo 2.5 Qwen Coder (7B, Q4_K_M)
     Spécialisé en code et offensive security

  3) Les deux modèles ci-dessus

  4) Installer un modèle personnalisé (GGUF depuis URL)

Votre choix [1-4]:
```

### Modèles disponibles

#### 1. Seneca Cybersecurity LLM ⭐ Recommandé
- **Taille**: ~4 GB
- **Spécialisation**: Cybersécurité générale
- **Points forts**: Analyse de logs, détection d'incidents, recommandations de sécurité
- **Source**: [HuggingFace](https://huggingface.co/AlicanKiraz0/Seneca-Cybersecurity-LLM-Q4_K_M-GGUF)

#### 2. WhiteRabbitNeo 2.5 Qwen Coder
- **Taille**: ~4 GB
- **Spécialisation**: Code et offensive security
- **Points forts**: Pentesting, exploitation, développement d'outils
- **Source**: [HuggingFace](https://huggingface.co/tensorblock/WhiteRabbitNeo-2.5-Qwen-2.5-Coder-7B-GGUF)

#### 3. Les deux modèles
- Installe les deux modèles ci-dessus
- Vous pouvez switcher entre eux depuis le menu

#### 4. Modèle personnalisé
- Permet d'installer n'importe quel modèle GGUF
- Vous devez fournir:
  - URL de téléchargement
  - Nom du fichier (ex: `mymodel.gguf`)
  - Nom d'affichage

---

## Stockage des modèles

### Comment Ollama stocke les modèles

Lorsque vous installez un modèle LLM avec la stack `llm`, **deux copies** sont créées:

#### 1. Fichier GGUF source
- **Emplacement**: `/opt/balorsh/data/llm/models/`
- **Exemples**: 
  - `senecallm-q4_k_m.gguf` (~4 GB)
  - `whiterabbitneo-2.5-qwen-2.5-coder-7b-q4_k_m.gguf` (~4 GB)
- **Rôle**: Fichier source référencé dans les Modelfiles
- **Utilisation**: Copie de référence, utilisée pour créer les personas

#### 2. Stockage interne Ollama
- **Emplacement**: `~/.ollama/models/`
- **Structure**: 
  ```
  ~/.ollama/models/
  ├── blobs/           # Données binaires optimisées
  └── manifests/       # Métadonnées des modèles
  ```
- **Rôle**: Format optimisé interne d'Ollama
- **Utilisation**: Version utilisée lors de l'exécution
- **Taille**: ~4 GB supplémentaire par modèle de base

### Implications de stockage

⚠️ **Duplication nécessaire**: Chaque modèle GGUF nécessite environ **2x son espace disque**.

**Exemple avec 2 modèles:**
```
/opt/balorsh/data/llm/models/
├── senecallm-q4_k_m.gguf                    ~4 GB
└── whiterabbitneo-q4_k_m.gguf               ~4 GB
                                              ─────
                                              ~8 GB

~/.ollama/models/blobs/
├── sha256:abc123... (Seneca interne)        ~4 GB
└── sha256:def456... (WhiteRabbitNeo interne)~4 GB
                                              ─────
                                              ~8 GB

TOTAL:                                        ~16 GB
```

### Partage des blobs entre personas

Les personas (base, loganalyst, redteam, etc.) créés avec `ollama create` **partagent les blobs** du modèle de base:

```bash
# Tous ces modèles partagent le même blob Seneca:
ollama create seneca:base
ollama create seneca:loganalyst
ollama create seneca:redteam
# → Pas de duplication supplémentaire! (~quelques KB de métadonnées par persona)
```

### Nettoyage

Pour libérer de l'espace:

**Supprimer un modèle via le menu:**
```bash
./balorsh llm
# → Option 6 (Supprimer un modèle)
```

Cela supprime **automatiquement**:
- ✅ Le fichier GGUF source (`/opt/balorsh/data/llm/models/`)
- ✅ Tous les modèles Ollama personas (`seneca:base`, `seneca:loganalyst`, etc.)
- ✅ Les blobs internes Ollama (`~/.ollama/models/blobs/`)

**Nettoyage manuel (si nécessaire):**
```bash
# Lister les modèles Ollama restants
ollama list

# Supprimer manuellement un modèle Ollama spécifique
ollama rm seneca:custom

# Nettoyer les blobs orphelins (si vous avez d'autres modèles Ollama)
# ATTENTION: Vérifie bien qu'aucun autre modèle Ollama n'est utilisé!
docker exec ollama ollama gc  # Si Ollama est dans Docker
# OU
rm -rf ~/.ollama/models/blobs/sha256:*  # Si installation native
```

### Pourquoi cette duplication?

C'est le **fonctionnement standard d'Ollama**:

1. **Fichier GGUF**: Format universel, compatible avec tous les outils (Ollama, llama.cpp, etc.)
2. **Blobs Ollama**: Format interne optimisé pour:
   - Chargement rapide
   - Gestion de la mémoire
   - Partage entre modèles similaires
   - Versioning et manifests

---

## Utilisation

### Lancer le menu LLM

```bash
./balorsh llm
```

### Structure du menu

```
╔═══════════════════════════════════════════════════════════════════╗
                    IA Cybersécurité - Seneca
╚═══════════════════════════════════════════════════════════════════╝
   Statut: ● Actif    Persona: base
   Modèle: Seneca Cybersecurity LLM
───────────────────────────────────────────────────────────────────

   MODÈLES IA
   1. Charger/Changer de modèle IA
   2. Supprimer un modèle IA

   INTERACTION
   3. Analyser un log
   4. Chat avec l'IA

   PERSONAS
   5. Persona: Standard
   6. Persona: Analyste de Logs
   7. Persona: Red Team (Offensif)
   8. Persona: Blue Team (Défensif)
   9. Persona: Purple Team (Hybride)

   SYSTÈME
   10. Arrêter le serveur Ollama
   11. Voir les conversations sauvegardées
   12. Voir les analyses de logs

   0. Retour au menu principal
═══════════════════════════════════════════════════════════════════
```

### Fonctionnalités principales

#### 1. Charger/Changer de modèle IA
- Liste tous les modèles installés
- Permet de switcher entre les modèles
- Recrée automatiquement tous les personas avec le nouveau modèle

**Exemple:**
```
1. Seneca Cybersecurity LLM
   (senecallm-q4_k_m.gguf)
2. WhiteRabbitNeo 2.5 Qwen Coder
   (whiterabbitneo-q4_k_m.gguf)

Choisir le modèle [1-2] (0 pour annuler): 2
```

#### 2. Supprimer un modèle IA
- Liste les modèles avec indication du modèle actif
- Demande confirmation avant suppression
- **Supprime automatiquement** tous les personas Ollama (`seneca:*`)
- Supprime le fichier GGUF source et la configuration
- Gère automatiquement le changement de modèle actif si nécessaire

#### 3. Analyser un log
- Ouvre automatiquement le gestionnaire de fichiers (Dolphin/Nautilus/Thunar/etc.)
- Navigue vers `/opt/balorsh/data`
- Vous demande le chemin du fichier log
- Convertit automatiquement les formats:
  - **XML** → TXT (avec xmllint)
  - **PCAP/CAP** → Résumé TXT (avec tcpdump)
- Limite à 5000 lignes pour les gros fichiers
- Soumet le log à l'IA pour analyse
- Sauvegarde l'analyse dans `/opt/balorsh/data/llm/logs/`

**Formats supportés:**
- `.txt` - Direct
- `.log` - Direct
- `.xml` - Converti
- `.pcap`, `.cap` - Résumé extrait

#### 4. Chat avec l'IA
- Conversation interactive
- Historique sauvegardé automatiquement
- Commandes spéciales:
  - `exit` ou `quit` - Quitter
  - `clear` - Effacer l'écran

**Sauvegarde:** `/opt/balorsh/data/llm/conversations/chat_YYYYMMDD_HHMMSS.txt`

---

## Personas

Les personas sont des configurations de comportement pour l'IA. Ils sont **dynamiques** et s'adaptent automatiquement au modèle actif.

### Personas par défaut

#### Base (Standard)
- **Temperature**: 0.7
- **Utilisation**: Questions générales de cybersécurité
- **Comportement**: Équilibré, informatif

#### Log Analyst (Analyste de Logs)
- **Temperature**: 0.5 (plus précis)
- **Context**: 8192 tokens (pour gros logs)
- **Utilisation**: Analyse de logs, détection d'anomalies
- **Comportement**: Méthodique, focalisé sur les IOCs

#### Red Team (Offensif)
- **Temperature**: 0.8 (plus créatif)
- **Utilisation**: Pentesting, exploitation, attaque
- **Comportement**: Perspective attaquant
- **Note**: Rappelle toujours l'aspect légal/éthique

#### Blue Team (Défensif)
- **Temperature**: 0.6
- **Utilisation**: Défense, incident response, hardening
- **Comportement**: Perspective défenseur

#### Purple Team (Hybride)
- **Temperature**: 0.7
- **Utilisation**: Vision globale offensive + défensive
- **Comportement**: Amélioration continue de la sécurité

### Ajouter un nouveau persona

1. **Créer le Modelfile**

Créez `/home/user/Balor/lib/models/Modelfile.monpersona`:

```
FROM /opt/balorsh/data/llm/models/senecallm-q4_k_m.gguf
PARAMETER temperature 0.7
PARAMETER top_p 0.9
PARAMETER num_ctx 4096
SYSTEM You are Seneca, a [votre spécialisation]. [Instructions détaillées en une ligne]
```

2. **Réinstaller ou copier manuellement**

Option A - Réinstallation (recommandé):
```bash
sudo bash stacks/llm/install.sh
```

Option B - Copie manuelle:
```bash
# Adapter le Modelfile au modèle actif
ACTIVE=$(cat /opt/balorsh/data/llm/models/active_model.txt)
sed "s|FROM /opt/balorsh/data/llm/models/.*\.gguf|FROM /opt/balorsh/data/llm/models/$ACTIVE|g" \
  lib/models/Modelfile.monpersona > /opt/balorsh/data/llm/modelfiles/Modelfile.monpersona

# Créer le modèle Ollama
ollama create seneca:monpersona -f /opt/balorsh/data/llm/modelfiles/Modelfile.monpersona
```

3. **Le persona apparaît automatiquement dans le menu**

### Paramètres des Modelfiles

- **temperature** (0.0-2.0)
  - `0.1-0.3`: Très précis, déterministe
  - `0.5-0.7`: Équilibré (recommandé)
  - `0.8-1.0`: Créatif
  - `1.5+`: Très créatif, imprévisible

- **top_p** (0.0-1.0)
  - Nucleus sampling
  - `0.8-0.9`: Recommandé
  - Plus bas = plus conservateur

- **num_ctx** (tokens)
  - `2048`: Petit contexte
  - `4096`: Standard
  - `8192`: Gros contexte (logs volumineux)

### Exemples de personas personnalisés

**Forensics:**
```
FROM /opt/balorsh/data/llm/models/senecallm-q4_k_m.gguf
PARAMETER temperature 0.4
PARAMETER top_p 0.85
PARAMETER num_ctx 8192
SYSTEM You are Seneca, a digital forensics expert. Analyze evidence, reconstruct attack timelines, identify artifacts, and provide detailed forensic reports. Focus on chain of custody and evidence preservation. Be methodical and document everything.
```

**Compliance:**
```
FROM /opt/balorsh/data/llm/models/senecallm-q4_k_m.gguf
PARAMETER temperature 0.5
PARAMETER top_p 0.85
PARAMETER num_ctx 4096
SYSTEM You are Seneca, a cybersecurity compliance expert. Help organizations meet security standards like ISO 27001, NIST, PCI-DSS, and GDPR. Provide audit guidance and compliance recommendations. Focus on practical implementation.
```

**Threat Intelligence:**
```
FROM /opt/balorsh/data/llm/models/senecallm-q4_k_m.gguf
PARAMETER temperature 0.6
PARAMETER top_p 0.9
PARAMETER num_ctx 4096
SYSTEM You are Seneca, a cyber threat intelligence analyst. Track APT groups, analyze TTPs, correlate IOCs, and provide actionable threat intelligence. Focus on attribution and threat actor profiling. Cite sources when possible.
```

---

## Gestion des modèles

### Fichiers de configuration

- `/opt/balorsh/data/llm/models/models.conf`
  - Liste des modèles installés
  - Format: `filename.gguf|Display Name`

- `/opt/balorsh/data/llm/models/active_model.txt`
  - Nom du fichier du modèle actuellement actif

- `/opt/balorsh/data/llm/models/*.gguf`
  - Fichiers des modèles IA

- `/opt/balorsh/data/llm/modelfiles/Modelfile.*`
  - Définitions des personas (adaptées au modèle actif)

### JSON d'état des Modelfiles

La stack LLM maintient également un fichier JSON récapitulatif des Modelfiles et de leurs versions :

- Emplacement: `/opt/balorsh/json/models_status.json`
- Contenu: champs `last_update` et un objet `models` listant chaque persona avec sa `version` et un booléen `installed`.

Ce JSON est mis à jour par la fonction `update_models_json()` présente dans `lib/common.sh` lors des opérations d'installation/entretien. Lorsqu'une différence de version est détectée entre le fichier `VERSION` du dépôt et l'entrée correspondante dans le JSON, Balor tentera de recréer automatiquement les modèles Ollama en utilisant la logique de `check_and_recreate_models_if_needed()` :

1. Lire la version déclarée dans `VERSION` (ligne `Modelfile.<persona>:<version>`).
2. Comparer avec la valeur stockée dans `/opt/balorsh/json/models_status.json`.
3. Si différente, recréer le Modelfile adapté au modèle `active_model.txt` et exécuter `ollama rm` puis `ollama create` pour recréer le modèle `balor:<persona>`.
4. Mettre à jour le JSON via `update_models_json()`.

Remarques:

- Si un Modelfile n'est pas déclaré dans `VERSION`, il est exclu du JSON (par conception).
- Le JSON permet aux interfaces non interactives (scripts, UI) de connaître l'état des personas sans interroger Ollama à chaque fois.
### Ajouter un modèle manuellement

```bash
# 1. Télécharger le modèle
cd /opt/balorsh/data/llm/models
curl -L -o mon-modele.gguf "https://example.com/model.gguf"

# 2. Ajouter à la configuration
echo "mon-modele.gguf|Mon Modèle IA" >> models.conf

# 3. Le modèle apparaît dans le menu option 1
```

### Workflow de changement de modèle

Quand vous changez de modèle actif via le menu:

1. Le nouveau modèle est marqué comme actif dans `active_model.txt`
2. Tous les Modelfiles dans `lib/models/` sont copiés
3. La ligne `FROM` est modifiée pour pointer vers le nouveau modèle
4. Les Modelfiles sont sauvés dans `/opt/balorsh/data/llm/modelfiles/`
5. Tous les modèles Ollama `seneca:*` sont supprimés
6. Tous les modèles Ollama sont recréés avec les nouveaux Modelfiles
7. Le système est prêt avec le nouveau modèle

### Workflow de suppression

Quand vous supprimez un modèle:

1. Demande de confirmation
2. Suppression du fichier `.gguf`
3. Retrait de la ligne dans `models.conf`
4. Si c'était le modèle actif:
   - Sélection automatique d'un autre modèle
   - Mise à jour de `active_model.txt`
5. **Note**: Les modèles Ollama `seneca:*` ne sont PAS supprimés automatiquement
   - Ils deviendront invalides si le modèle source n'existe plus
   - Utilisez `ollama rm seneca:persona` pour les nettoyer manuellement

---

## Personnalisation

### Structure du projet

```
Balor/
├── lib/
│   └── models/              # Sources des Modelfiles
│       ├── Modelfile.base
│       ├── Modelfile.loganalyst
│       ├── Modelfile.redteam
│       ├── Modelfile.blueteam
│       ├── Modelfile.purpleteam
│       └── README.md
│
├── stacks/
│   └── llm/
│       ├── commands.sh      # Menu et fonctionnalités
│       ├── install.sh       # Installation multi-modèles
│       ├── uninstall.sh
│       ├── packages.txt
│       └── README.md
│
└── /opt/balorsh/data/llm/   # Données runtime
    ├── models/              # Fichiers GGUF + config
    ├── modelfiles/          # Modelfiles adaptés
    ├── logs/                # Analyses de logs
    └── conversations/       # Historiques de chat
```

### Conseils

**Pour l'analyse de logs:**
- Utilisez le persona `loganalyst`
- Modèle recommandé: Seneca Cybersecurity LLM
- Limitez la taille des logs (5000 lignes max automatique)

**Pour le pentesting:**
- Utilisez le persona `redteam`
- Modèle recommandé: WhiteRabbitNeo 2.5
- Combinez avec les outils de la stack `networkscan` ou `wifi`

**Pour la défense:**
- Utilisez le persona `blueteam`
- Modèle recommandé: Seneca Cybersecurity LLM
- Analysez les logs de détection (Suricata, Snort, etc.)

**Pour du code:**
- Utilisez WhiteRabbitNeo 2.5
- Temperature plus élevée (0.7-0.8) pour la créativité

---

## Dépannage

### Ollama ne démarre pas

```bash
sudo systemctl status ollama.service
sudo systemctl start ollama.service
sudo journalctl -u ollama.service -n 50
```

### Modèle Ollama invalide

Si vous avez supprimé le fichier GGUF mais les modèles Ollama existent encore:

```bash
# Lister les modèles
ollama list

# Supprimer un modèle invalide
ollama rm seneca:persona

# Recréer tous les modèles
cd /opt/balorsh/data/llm/modelfiles
for f in Modelfile.*; do
  persona=$(basename "$f" | sed 's/Modelfile\.//')
  ollama create "seneca:$persona" -f "$f"
done
```

### Espace disque insuffisant

Chaque modèle fait ~4 GB. Pour libérer de l'espace:

```bash
# Voir l'espace utilisé
du -sh /opt/balorsh/data/llm/models/*

# Supprimer via le menu (option 2)
./balorsh llm

# Ou manuellement
rm /opt/balorsh/data/llm/models/nom-du-modele.gguf
# Puis éditer models.conf
```

### Erreur "command must be one of..."

Le Modelfile a des lignes vides ou une syntaxe incorrecte.

**Règles:**
- Pas de lignes vides entre les commandes
- `SYSTEM` doit être sur UNE SEULE ligne
- Pas de retours à la ligne dans les prompts

---

## Notes importantes

- Tous les prompts système doivent être sur UNE SEULE ligne
- Évitez les lignes vides entre les commandes dans les Modelfiles
- Les fichiers doivent être en UTF-8
- Les noms de personas sont automatiquement capitalisés dans le menu
- Le menu est dynamique et se met à jour automatiquement
- Les conversations et analyses sont sauvegardées automatiquement
- Le modèle actif est affiché dans le header du menu

---

## Voir aussi

- [README principal](../../README.md)
- [Documentation des Modelfiles](../../lib/models/README.md)
- [README de la stack](../stacks/llm/README.md)

