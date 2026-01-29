# Système d'Addons - Framework Balor

[English version](#addons-system---balor-framework)

---

## 🔌 Système d'Addons - Framework Balor

Le système d'addons étend les stacks principales de Balor avec des modules optionnels et légers qui suivent les mêmes principes modulaires que le framework principal.

### 🎯 Concept

Les addons sont des **extensions optionnelles** qui complètent les stacks principales sans faire partie du framework central. Ils sont conçus pour :

- **Cas d'usage spécialisés** qui peuvent ne pas être nécessaires pour tous les utilisateurs
- **Fonctionnalités expérimentales** ou outils encore en développement
- **Intégrations tierces** nécessitant une configuration supplémentaire
- **Outils spécifiques à un domaine** (phishing, forensique, etc.)

### 🏗️ Architecture

Chaque addon suit la même structure que les stacks principales :

```
addons/
└── <nom_addon>/
    ├── install.sh          # Script d'installation
    ├── uninstall.sh        # Script de désinstallation
    ├── commands.sh         # Interface menu
    └── packages.txt        # Dépendances (pacman|aur)
```

### 📦 Installation et Gestion

#### Via l'Installateur Principal

```bash
./install.sh
# Choisir :
# 10) Lister les addons
# 11) Installer un addon
# 12) Désinstaller un addon
# 13) Installer tous les addons
```

#### Via le Wrapper balorsh

```bash
# Lister les addons disponibles
balorsh list

# Accéder au menu de l'addon
balorsh <nom_addon>
# Exemple : balorsh phishing
```

### 🔧 Fonctionnalités

- **Autonomes** : Chaque addon gère ses propres dépendances
- **Désinstallation propre** : Suppression complète sans affecter les stacks principales
- **Interface cohérente** : Mêmes menus, couleurs et navigation que les stacks principales
- **i18n complet** : Support français/anglais avec détection automatique de langue
- **Isolation des données** : Chaque addon utilise son propre répertoire de données
- **Services en arrière-plan** : Support pour les services qui tournent indépendamment

### 📁 Emplacements des Fichiers

- **Racine des addons** : `/opt/balorsh/addons/`
- **Applications** : `/opt/balorsh/addons/apps/`
- **Données** : `/opt/balorsh/data/<addon>/`
- **Logs** : `/opt/balorsh/data/<addon>/logs/`

### 🎨 Intégration Menu

Les addons s'intègrent parfaitement avec le wrapper balorsh :

```bash
balorsh <addon>
# Ouvre le menu de l'addon avec options numérotées
# Même schéma de couleurs et navigation que les stacks principales
```

### 🛠️ Créer des Addons

Pour créer un nouvel addon :

1. **Créer le répertoire** : `addons/<nom>/`
2. **Ajouter packages.txt** : Lister les dépendances (format pacman|aur)
3. **Écrire install.sh** : Utiliser les helpers common.sh pour l'installation des paquets
4. **Écrire uninstall.sh** : Suppression propre des paquets et fichiers
5. **Écrire commands.sh** : Interface menu avec options numérotées
6. **Ajouter les clés i18n** : Mettre à jour lib/lang/fr.sh et lib/lang/en.sh

#### Exemple packages.txt

```
pacman:curl wget unzip
aur:wifipumpkin3-git
```

#### Exemple de structure install.sh

```bash
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

# Lire les paquets
PKGS_RAW=$(read_stack_packages "$SCRIPT_DIR")
PAC_PKGS="${PKGS_RAW%%|*}"
AUR_PKGS="${PKGS_RAW#*|}"

# Installer les paquets
for p in $PAC_PKGS; do
  install_pacman_pkg "$p"
done
for a in $AUR_PKGS; do
  install_aur_pkg "$a"
done

# Configurer le répertoire de données
ensure_stack_data_dir "<nom_addon>"

echo "${<ADDON>_INSTALLED}"
```

### 🌍 Support i18n

Les addons doivent supporter le français et l'anglais :

```bash
# Dans install.sh/uninstall.sh
echo "${ADDON_NAME_INSTALLED}"

# Dans lib/lang/fr.sh
ADDON_NAME_INSTALLED="[Balor] Addon <nom> installé."

# Dans lib/lang/en.sh
ADDON_NAME_INSTALLED="[Balor] <name> addon installed."
```

### 🔍 Addons Disponibles

#### 🎣 Addon Phishing

- **Gophish** : Gestion de campagnes de phishing
- **Zphisher** : Modèles de pages de phishing
- **WifiPumpkin3** : Outils de phishing Wi-Fi

📖 **Documentation complète** : [../balorsh/balorsh_phishing_fr.md](../balorsh/balorsh_phishing_fr.md)

### 🚀 Bonnes Pratiques

1. **Utiliser les helpers common.sh** : Tirer parti des fonctions existantes pour la gestion des paquets
2. **Respecter les conventions de nommage** : Utiliser des noms d'addons descriptifs en minuscules
3. **Fournir une désinstallation propre** : Supprimer tous les fichiers, paquets et données
4. **Ajouter les clés i18n** : Supporter le français et l'anglais
5. **Tester minutieusement** : Assurer que l'installation/désinstallation fonctionne de manière fiable
6. **Documenter l'usage** : Fournir des instructions et exemples clairs

### 🐛 Dépannage

#### L'addon n'apparaît pas dans balorsh list

```bash
# Vérifier si le répertoire de l'addon existe
ls -la /opt/balorsh/addons/

# Vérifier si commands.sh est exécutable
ls -la /opt/balorsh/addons/<nom>/commands.sh

# Réinstaller l'addon
./install.sh → 12) Désinstaller un addon → sélectionner l'addon
```

#### L'installation échoue

```bash
# Vérifier les dépendances
cat addons/<nom>/packages.txt

# Consulter les logs
tail -f /opt/balorsh/data/<nom>/logs/install.log
```

#### Désinstallation incomplète

```bash
# Nettoyer manuellement
sudo rm -rf /opt/balorsh/addons/<nom>
sudo rm -rf /opt/balorsh/data/<nom>
```

---

## 🔌 Addons System - Balor Framework

The addons system extends Balor's core stacks with optional, lightweight modules that follow the same modular principles as the main framework.

### 🎯 Concept

Addons are **optional extensions** that complement the core stacks without being part of the main framework. They are designed for:

- **Specialized use cases** that may not be needed by all users
- **Experimental features** or tools still in development
- **Third-party integrations** that require additional setup
- **Domain-specific tools** (phishing, forensics, etc.)

### 🏗️ Architecture

Each addon follows the same structure as core stacks:

```
addons/
└── <addon_name>/
    ├── install.sh          # Installation script
    ├── uninstall.sh        # Uninstallation script
    ├── commands.sh         # Menu interface
    └── packages.txt        # Dependencies (pacman|aur)
```

### 📦 Installation & Management

#### Via Main Installer

```bash
./install.sh
# Choose:
# 10) List addons
# 11) Install an addon
# 12) Uninstall an addon
# 13) Install all addons
```

#### Via balorsh Wrapper

```bash
# List available addons
balorsh list

# Access addon menu
balorsh <addon_name>
# Example: balorsh phishing
```

### 🔧 Features

- **Self-contained**: Each addon manages its own dependencies
- **Clean uninstall**: Complete removal without affecting core stacks
- **Consistent UI**: Same menus, colors, and navigation as core stacks
- **Full i18n**: French/English support with automatic language detection
- **Data isolation**: Each addon uses its own data directory
- **Background services**: Support for services that run independently

### 📁 File Locations

- **Addons root**: `/opt/balorsh/addons/`
- **Applications**: `/opt/balorsh/addons/apps/`
- **Data**: `/opt/balorsh/data/<addon>/`
- **Logs**: `/opt/balorsh/data/<addon>/logs/`

### 🎨 Menu Integration

Addons integrate seamlessly with the balorsh wrapper:

```bash
balorsh <addon>
# Opens the addon's menu with numbered options
# Same color scheme and navigation as core stacks
```

### 🛠️ Creating Addons

To create a new addon:

1. **Create directory**: `addons/<name>/`
2. **Add packages.txt**: List dependencies (pacman|aur format)
3. **Write install.sh**: Use common.sh helpers for package installation
4. **Write uninstall.sh**: Clean removal of packages and files
5. **Write commands.sh**: Menu interface with numbered options
6. **Add i18n keys**: Update lib/lang/fr.sh and lib/lang/en.sh

#### Example packages.txt

```
pacman:curl wget unzip
aur:wifipumpkin3-git
```

#### Example install.sh structure

```bash
#!/usr/bin/env bash
set -e
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../../lib/common.sh"

# Read packages
PKGS_RAW=$(read_stack_packages "$SCRIPT_DIR")
PAC_PKGS="${PKGS_RAW%%|*}"
AUR_PKGS="${PKGS_RAW#*|}"

# Install packages
for p in $PAC_PKGS; do
  install_pacman_pkg "$p"
done
for a in $AUR_PKGS; do
  install_aur_pkg "$a"
done

# Setup data directory
ensure_stack_data_dir "<addon_name>"

echo "${<ADDON>_INSTALLED}"
```

### 🌍 i18n Support

Addons must support both French and English:

```bash
# In install.sh/uninstall.sh
echo "${ADDON_NAME_INSTALLED}"

# In lib/lang/fr.sh
ADDON_NAME_INSTALLED="[Balor] Addon <name> installé."

# In lib/lang/en.sh
ADDON_NAME_INSTALLED="[Balor] <name> addon installed."
```

### 🔍 Available Addons

#### 🎣 Phishing Addon

- **Gophish**: Phishing campaign management
- **Zphisher**: Phishing page templates
- **WifiPumpkin3**: Wi-Fi phishing tools

📖 **Full documentation**: [../balorsh/balorsh_phishing.md](../balorsh/balorsh_phishing.md)

### 🚀 Best Practices

1. **Use common.sh helpers**: Leverage existing functions for package management
2. **Follow naming conventions**: Use descriptive, lowercase addon names
3. **Provide clean uninstall**: Remove all files, packages, and data
4. **Add i18n keys**: Support both French and English
5. **Test thoroughly**: Ensure installation/uninstallation works reliably
6. **Document usage**: Provide clear instructions and examples

### 🐛 Troubleshooting

#### Addon not showing in balorsh list

```bash
# Check if addon directory exists
ls -la /opt/balorsh/addons/

# Check if commands.sh is executable
ls -la /opt/balorsh/addons/<name>/commands.sh

# Reinstall addon
./install.sh → 12) Uninstall an addon → select addon
```

#### Installation fails

```bash
# Check dependencies
cat addons/<name>/packages.txt

# Check logs
tail -f /opt/balorsh/data/<name>/logs/install.log
```

#### Uninstall incomplete

```bash
# Manually clean up
sudo rm -rf /opt/balorsh/addons/<name>
sudo rm -rf /opt/balorsh/data/<name>
```

---

## 📚 Ressources Supplémentaires

- **README Principal** : [../../README.md](../../README.md)
- **README Français** : [../../README_fr.md](../../README_fr.md)
- **Addon Phishing** : [../balorsh/balorsh_phishing_fr.md](../balorsh/balorsh_phishing_fr.md)
- **Wrapper balorsh** : Voir README principal pour exemples d'utilisation
