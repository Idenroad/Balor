# Système Multilingue Balor

## 🌍 Vue d'ensemble

Balor supporte maintenant **2 langues** avec détection automatique :
- 🇫🇷 **Français** (fr)
- 🇬🇧 **Anglais** (en)

La langue est détectée automatiquement depuis la variable d'environnement `LANG` de CachyOS.

## ✨ Fonctionnalités

- ✅ Détection automatique de la langue système
- ✅ Support français et anglais complet
- ✅ Changement de langue à la volée
- ✅ Messages paramétrés (avec variables dynamiques)
- ✅ Architecture modulaire et extensible
- ✅ Compatible avec tous les scripts Balor

## 🚀 Démarrage rapide

### Utilisation normale (détection auto)

```bash
# La langue sera détectée automatiquement depuis $LANG
balorsh

# Si LANG=fr_FR.UTF-8 → Interface en français
# Si LANG=en_US.UTF-8 → Interface en anglais
```

### Forcer une langue spécifique

```bash
# Forcer le français
BALOR_LANG=fr balorsh

# Forcer l'anglais
BALOR_LANG=en balorsh
```

### Changer la langue système (CachyOS)

```bash
# Vérifier la langue actuelle
echo $LANG

# Changer temporairement
export LANG=fr_FR.UTF-8  # Français
export LANG=en_US.UTF-8  # Anglais

# Changer définitivement (éditer ~/.bashrc ou ~/.config/fish/config.fish)
echo 'export LANG=fr_FR.UTF-8' >> ~/.bashrc
```

## 📂 Structure

```
Balor/
├── lib/
│   ├── i18n.sh          # Système i18n principal
│   ├── common.sh        # Bibliothèque commune (charge i18n)
│   └── lang/
│       ├── fr.sh        # 🇫🇷 Traductions françaises
│       └── en.sh        # 🇬🇧 Traductions anglaises
├── stacks/
│   └── wifi/
│       └── commands.sh  # ✅ Adapté i18n
├── test_i18n.sh         # Script de test
├── extract_i18n.sh      # Helper d'extraction
├── I18N.md              # Documentation technique
└── MIGRATION_I18N.md    # Guide de migration
```

## 🔧 Pour les développeurs

### Ajouter un nouveau message

1. **Ajouter dans `lib/lang/fr.sh` :**
   ```bash
   MY_MESSAGE="Mon message en français"
   ```

2. **Ajouter dans `lib/lang/en.sh` :**
   ```bash
   MY_MESSAGE="My message in English"
   ```

3. **Utiliser dans votre code :**
   ```bash
   echo "$MY_MESSAGE"
   ```

### Messages avec variables

Pour les messages contenant des informations dynamiques :

**Dans fr.sh et en.sh :**
```bash
# Français
WIFI_ENABLE_MONITOR="Activation du mode monitor sur %s..."

# Anglais
WIFI_ENABLE_MONITOR="Enabling monitor mode on %s..."
```

**Dans votre code :**
```bash
iface="wlan0"
printf "$WIFI_ENABLE_MONITOR\n" "$iface"
# Affiche: "Activation du mode monitor sur wlan0..." (FR)
# Affiche: "Enabling monitor mode on wlan0..." (EN)
```

### Tester vos modifications

```bash
# Exécuter les tests
./test_i18n.sh

# Tester en français
BALOR_LANG=fr ./stacks/wifi/commands.sh

# Tester en anglais  
BALOR_LANG=en ./stacks/wifi/commands.sh
```

## 📚 Documentation complète

- **[I18N.md](I18N.md)** - Documentation technique détaillée
- **[MIGRATION_I18N.md](MIGRATION_I18N.md)** - Guide de migration pour adapter vos scripts
- **[lib/lang/fr.sh](lib/lang/fr.sh)** - Toutes les traductions françaises
- **[lib/lang/en.sh](lib/lang/en.sh)** - Toutes les traductions anglaises

## 🛠️ Outils inclus

### test_i18n.sh
Script de test pour valider le fonctionnement du système i18n :
```bash
./test_i18n.sh
```

### extract_i18n.sh
Helper pour extraire les messages d'un fichier et suggérer les variables :
```bash
./extract_i18n.sh stacks/wifi/install.sh
```

## 🎯 Exemples

### Menu WiFi multilingue

**Français (BALOR_LANG=fr) :**
```
╔═══════════════════════════════════════════════════════════════════╗
                     📡 WiFi Stack - balorsh                      
╚═══════════════════════════════════════════════════════════════════╝
   ──── Contrôle Interface ────
   [1] Lister interfaces WiFi
   [2] Sélectionner interface WiFi et activer monitor mode
   [3] Désactiver monitor mode sur interface
```

**Anglais (BALOR_LANG=en) :**
```
╔═══════════════════════════════════════════════════════════════════╗
                     📡 WiFi Stack - balorsh                      
╚═══════════════════════════════════════════════════════════════════╝
   ──── Interface Control ────
   [1] List WiFi interfaces
   [2] Select WiFi interface and enable monitor mode
   [3] Disable monitor mode on interface
```

### Messages d'installation

**Français :**
```
[Balor] paru détecté.
  [OK] aircrack-ng déjà installé (pacman).
  [INSTALL] wifite (AUR)...
```

**Anglais :**
```
[Balor] paru detected.
  [OK] aircrack-ng already installed (pacman).
  [INSTALL] wifite (AUR)...
```

## 🌟 Ajouter une nouvelle langue

Pour ajouter une nouvelle langue (ex: espagnol) :

1. **Créer le fichier de langue :**
   ```bash
   cp lib/lang/en.sh lib/lang/es.sh
   # Traduire tous les messages en espagnol
   ```

2. **Modifier `lib/i18n.sh` :**
   ```bash
   detect_system_language() {
     local sys_lang="${LANG:-en_US.UTF-8}"
     local lang_code="${sys_lang:0:2}"
     
     case "$lang_code" in
       fr) echo "fr" ;;
       en) echo "en" ;;
       es) echo "es" ;;  # ← Ajouter ici
       *) echo "en" ;;
     esac
   }
   ```

3. **Tester :**
   ```bash
   BALOR_LANG=es ./balorsh
   ```

## 🐛 Dépannage

### La langue n'est pas détectée correctement

```bash
# Vérifier votre LANG
echo $LANG

# Forcer manuellement
export BALOR_LANG=fr
./balorsh
```

### Messages en double langue

Vérifiez que vous n'avez pas de messages en dur mélangés avec des variables i18n.

### Variables non trouvées

Assurez-vous que `lib/common.sh` est chargé avant d'utiliser les variables :
```bash
source "$ROOT_DIR/lib/common.sh"
```

## 📊 État actuel

| Fichier | Statut | Notes |
|---------|--------|-------|
| `lib/i18n.sh` | ✅ Complet | Système i18n de base |
| `lib/lang/fr.sh` | ✅ Complet | Traductions françaises |
| `lib/lang/en.sh` | ✅ Complet | Traductions anglaises |
| `lib/common.sh` | ✅ Adapté | Messages d'installation |
| `stacks/wifi/commands.sh` | ✅ Adapté | Menu et fonctions WiFi |
| Autres stacks | ⏳ À faire | Peuvent être adaptés selon besoin |

## 🤝 Contribution

Pour contribuire aux traductions :
1. Vérifier les messages manquants dans `lib/lang/fr.sh` et `lib/lang/en.sh`
2. Ajouter les nouvelles variables dans les deux fichiers
3. Tester avec `./test_i18n.sh`
4. Soumettre vos modifications

## 📝 Licence

Même licence que le projet Balor principal.

---

**Développé pour CachyOS** 🐧
