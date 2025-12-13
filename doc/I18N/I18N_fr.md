# Système d'Internationalisation (i18n) de Balor

## Vue d'ensemble

Balor intègre maintenant un système multilingue complet supportant le français et l'anglais avec détection automatique de la langue système.

## Structure

```
lib/
├── i18n.sh              # Bibliothèque principale i18n
└── lang/
    ├── fr.sh            # Traductions françaises
    └── en.sh            # Traductions anglaises
```

## Utilisation

### 1. Dans vos scripts

Ajoutez l'import de i18n via common.sh (qui le charge automatiquement) :

```bash
#!/usr/bin/env bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"
```

### 2. Utiliser les variables de traduction

Au lieu d'écrire des messages en dur :

```bash
# ❌ Ancien style
echo "[Balor] paru détecté."
echo "Choix invalide."
```

Utilisez les variables i18n :

```bash
# ✅ Nouveau style
echo "$MSG_PARU_DETECTED"
echo "$WIFI_INVALID_CHOICE"
```

Pour les messages avec paramètres, utilisez `printf` :

```bash
# Message avec placeholder %s
printf "$WIFI_ENABLE_MONITOR\n" "$iface"
# Affiche: "Activation du mode monitor sur wlan0..." (FR)
# Affiche: "Enabling monitor mode on wlan0..." (EN)
```

### 3. Détection automatique de la langue

La langue est détectée automatiquement depuis la variable `$LANG` du système :

```bash
# Français si LANG=fr_FR.UTF-8
# Anglais si LANG=en_US.UTF-8 ou non reconnu
```

### 4. Changer la langue manuellement

```bash
# Depuis votre script
source "$ROOT_DIR/lib/i18n.sh"
set_language "en"  # Passer en anglais
set_language "fr"  # Passer en français

# Depuis l'environnement
export BALOR_LANG=en
./balorsh
```

## Variables disponibles

### Common (lib/common.sh)

| Variable | Français | Anglais |
|----------|----------|---------|
| `MSG_PARU_DETECTED` | paru détecté. | paru detected. |
| `MSG_PARU_NOT_FOUND` | paru non trouvé. | paru not found. |
| `MSG_PKG_ALREADY_INSTALLED` | %s déjà installé (pacman). | %s already installed (pacman). |
| `MSG_PKG_INSTALLING` | [INSTALL] %s (pacman)... | [INSTALL] %s (pacman)... |

### WiFi (stacks/wifi/commands.sh)

| Variable | Français | Anglais |
|----------|----------|---------|
| `WIFI_MENU_TITLE` | 📡 WiFi Stack - balorsh | 📡 WiFi Stack - balorsh |
| `WIFI_MENU_SECTION_INTERFACE` | Contrôle Interface | Interface Control |
| `WIFI_MENU_SECTION_RECON` | Reconnaissance | Reconnaissance |
| `WIFI_MENU_1` | [1] Lister interfaces WiFi | [1] List WiFi interfaces |
| `WIFI_NO_IFACE_DETECTED` | Aucune interface WiFi détectée. | No WiFi interface detected. |
| `WIFI_ENABLE_MONITOR` | Activation du mode monitor sur %s... | Enabling monitor mode on %s... |
| `WIFI_INVALID_CHOICE` | Choix invalide. | Invalid choice. |

Consultez [lib/lang/fr.sh](lib/lang/fr.sh) et [lib/lang/en.sh](lib/lang/en.sh) pour la liste complète.

## Ajouter de nouvelles traductions

1. **Ajoutez la variable dans les deux fichiers de langue :**

   Dans `lib/lang/fr.sh` :
   ```bash
   MY_NEW_MESSAGE="Mon nouveau message"
   ```

   Dans `lib/lang/en.sh` :
   ```bash
   MY_NEW_MESSAGE="My new message"
   ```

2. **Utilisez la variable dans votre code :**
   ```bash
   echo "$MY_NEW_MESSAGE"
   ```

## Ajouter une nouvelle langue

1. Créez `lib/lang/XX.sh` (XX = code langue ISO 639-1)
2. Copiez toutes les variables depuis `en.sh` ou `fr.sh`
3. Traduisez tous les messages
4. Ajoutez le support dans `lib/i18n.sh` :

```bash
detect_system_language() {
  local sys_lang="${LANG:-en_US.UTF-8}"
  local lang_code="${sys_lang:0:2}"
  
  case "$lang_code" in
    fr) echo "fr" ;;
    en) echo "en" ;;
    xx) echo "xx" ;;  # Ajoutez votre langue ici
    *) echo "en" ;;
  esac
}
```

## Migration des fichiers existants

Pour migrer un fichier vers le système i18n :

1. **Identifiez tous les messages utilisateur**
2. **Créez les variables dans fr.sh et en.sh**
3. **Remplacez les messages en dur par les variables**

Exemple :

```bash
# Avant
echo "Aucune interface WiFi détectée."

# Après
echo "$WIFI_NO_IFACE_DETECTED"
```

## Fichiers adaptés

- ✅ `lib/common.sh` - Complètement adapté
- ✅ `stacks/wifi/commands.sh` - Menu et fonctions principales adaptées
- ⏳ `stacks/*/install.sh` - À adapter selon besoin

## Bonnes pratiques

1. **Nommage des variables :**
   - Préfixe selon le contexte : `MSG_`, `WIFI_`, `INSTALL_`, etc.
   - Tout en majuscules avec underscore : `WIFI_ENABLE_MONITOR`
   - Descriptif et clair

2. **Messages avec paramètres :**
   - Utilisez `printf` au lieu de `echo`
   - Placeholders : `%s` (string), `%d` (number)
   - Exemple : `printf "$MSG_FORMAT\n" "$var1" "$var2"`

3. **Cohérence :**
   - Gardez le même ton dans toutes les langues
   - Format identique (ponctuation, majuscules, etc.)

4. **Test :**
   ```bash
   # Tester en français
   BALOR_LANG=fr ./balorsh
   
   # Tester en anglais
   BALOR_LANG=en ./balorsh
   ```

## Support

Pour toute question ou problème avec le système i18n, consultez les fichiers d'exemple ou créez une issue.
