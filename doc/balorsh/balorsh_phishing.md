# Phishing Addon - Balor Framework

[Version française](#addon-phishing---framework-balor)

---

## 🎣 Phishing Addon - Balor Framework

The phishing addon provides a comprehensive toolkit for social engineering assessments, phishing campaign management, and Wi-Fi based attacks. It integrates three powerful tools with a unified interface.

### 🛠️ Included Tools

#### 1. Gophish - Campaign Management
- **Purpose**: Open-source phishing toolkit for campaigns and credential harvesting
- **Features**: 
  - Campaign creation and management
  - Email template system
  - Landing page editor
  - Results tracking and dashboard
  - Credential capture and logging
- **Web Interface**: http://127.0.0.1:3333
- **Data Location**: `/opt/balorsh/data/phishing/gophish/`

#### 2. Zphisher - Page Templates
- **Purpose**: Collection of phishing page templates and generators
- **Features**:
  - 38+ phishing page templates
  - Social media platforms (Instagram, Facebook, etc.)
  - Corporate login pages
  - Custom template generation
  - Tunneling support (ngrok, cloudflared)
- **Location**: `/opt/balorsh/addons/apps/phishing/zphisher/`

#### 3. WifiPumpkin3 - Wi-Fi Phishing
- **Purpose**: Wi-Fi security toolkit for rogue AP attacks
- **Features**:
  - Rogue AP creation
  - Captive portal attacks
  - Credential harvesting
  - DNS spoofing
  - Network monitoring
- **Installation**: AUR package `wifipumpkin3-git`

### 🚀 Quick Start

#### Installation

```bash
# Install the addon
./install.sh
# Choose: 11) Install an addon → select "phishing"

# Or install all addons
./install.sh
# Choose: 13) Install all addons
```

#### Access

```bash
# Open the phishing menu
balorsh phishing
# Or: sudo balorsh phishing
```

### 📋 Menu Options

```
═══════════════════════════════════════════════════════════════════
                    Phishing
═══════════════════════════════════════════════════════════════════

  1) Campaign management (gophish)
  2) Phishing pages (zphisher)
  3) WiFi Phishing (wifi-pumpking 3 CLI)

  0) Quit
═══════════════════════════════════════════════════════════════════
```

### 🎯 Use Cases & Examples

#### 1. Gophish Campaign Setup

```bash
# Launch Gophish
balorsh phishing
# Choose: 1) Campaign management (gophish)

# Gophish starts in background
# Access: http://127.0.0.1:3333
# Initial password saved to: /opt/balorsh/data/phishing/gophish/password.txt
```

**Campaign Workflow:**
1. **Access Web Interface**: Open http://127.0.0.1:3333
2. **Login**: Use admin + initial password from password.txt
3. **Create Landing Page**: Import or create phishing page
4. **Create Email Template**: Design convincing email
5. **Create User Groups**: Import target email lists
6. **Launch Campaign**: Send and track results
7. **Monitor Results**: View opened emails, clicked links, submitted credentials

#### 2. Zphisher Page Generation

```bash
# Launch Zphisher
balorsh phishing
# Choose: 2) Phishing pages (zphisher)

# Follow the menu to:
# - Select template (Instagram, Facebook, etc.)
# - Set up tunneling (ngrok/cloudflared)
# - Generate phishing URL
```

**Template Examples:**
- **Social Media**: Instagram, Facebook, Twitter, LinkedIn
- **Corporate**: Microsoft 365, Google Workspace, Slack
- **E-commerce**: Amazon, eBay, PayPal
- **Custom**: Upload your own HTML templates

#### 3. WiFiPumpkin3 Rogue AP

```bash
# Launch WiFiPumpkin3
balorsh phishing
# Choose: 3) WiFi Phishing (wifi-pumpking 3 CLI)

# Common workflow:
# 1) Set interface: wifi-pumpkin3 -i wlan1
# 2) Create AP: wifi-pumpkin3 --ap
# 3) Configure captive portal
# 4) Start monitoring
```

### 📁 File Locations

```
/opt/balorsh/addons/apps/
├── gophish/                    # Gophish binary and config
└── phishing/
    └── zphisher/              # Zphisher templates and scripts

/opt/balorsh/data/phishing/
├── gophish/
│   ├── password.txt           # Initial admin password
│   ├── gophish.log           # Runtime logs
│   └── gophish.pid           # Process ID
└── zphisher_data/            # Zphisher generated files
```

### 🔧 Configuration

#### Gophish Configuration

```bash
# Edit Gophish config
sudo nano /opt/balorsh/addons/apps/gophish/config.json

# Default settings:
{
  "admin_server": {
    "listen_url": "0.0.0.0:3333",
    "use_tls": false,
    "cert_path": "gophish.crt",
    "key_path": "gophish.key"
  },
  "phish_server": {
    "listen_url": "0.0.0.0:80",
    "use_tls": false,
    "cert_path": "gophish.crt",
    "key_path": "gophish.key"
  }
}
```

#### Zphisher Tunneling

```bash
# Zphisher supports multiple tunneling services:
# - ngrok (default)
# - cloudflared
# - localtunnel

# Configure in Zphisher menu
# Option: Tunneling → Select service
```

### 🛡️ Security Considerations

#### Legal Usage
- **Only use on systems you own or have explicit permission to test**
- **Comply with local laws and regulations**
- **Obtain written authorization before conducting assessments**
- **Use for educational purposes and security awareness training**

#### Operational Security
- **Isolate testing environment** from production networks
- **Use VPN or dedicated connection** for external campaigns
- **Secure captured data** with proper encryption
- **Clean up artifacts** after assessments

#### Data Protection
- **Encrypt stored credentials** and sensitive data
- **Limit data retention** to necessary timeframe
- **Secure disposal** of test data
- **Document data handling procedures**

### 📊 Monitoring & Logging

#### Gophish Logs
```bash
# View Gophish activity
tail -f /opt/balorsh/data/phishing/gophish/gophish.log

# Check campaign results in web interface
# Database: /opt/balorsh/data/phishing/gophish/gophish.db
```

#### System Monitoring
```bash
# Check if Gophish is running
ps aux | grep gophish

# Monitor network connections
sudo netstat -tulpn | grep :3333

# Check WiFi interfaces
iwconfig
```

### 🐛 Troubleshooting

#### Gophish Issues

**Problem**: Gophish won't start
```bash
# Check permissions
ls -la /opt/balorsh/addons/apps/gophish/gophish

# Check logs
tail -f /opt/balorsh/data/phishing/gophish/gophish.log

# Restart Gophish
sudo pkill gophish
balorsh phishing → 1) Campaign management
```

**Problem**: Can't access web interface
```bash
# Check if port is listening
sudo netstat -tulpn | grep :3333

# Check firewall
sudo ufw status
sudo ufw allow 3333

# Verify IP binding
curl http://127.0.0.1:3333
```

#### Zphisher Issues

**Problem**: Templates not loading
```bash
# Check Zphisher installation
ls -la /opt/balorsh/addons/apps/phishing/zphisher/

# Reinstall Zphisher
cd /opt/balorsh/addons/apps/phishing/zphisher/
git pull origin main
```

**Problem**: Tunneling not working
```bash
# Check ngrok installation
which ngrok

# Test ngrok
ngrok http 80

# Check internet connection
ping google.com
```

#### WiFiPumpkin3 Issues

**Problem**: No WiFi interfaces available
```bash
# List interfaces
iwconfig
ip link show

# Check if interface is up
sudo ip link set wlan1 up
sudo iw dev wlan1 scan
```

**Problem**: Can't create AP
```bash
# Check NetworkManager conflicts
sudo systemctl stop NetworkManager
# Try again
# Restart NetworkManager when done
sudo systemctl start NetworkManager
```

### 📚 Advanced Usage

#### Custom Gophish Templates

```bash
# Create custom landing pages
mkdir -p /opt/balorsh/data/phishing/gophish/templates

# Import HTML templates
cp your_template.html /opt/balorsh/data/phishing/gophish/templates/

# Access in Gophish web interface
```

#### Automated Campaigns

```bash
# Script to check campaign status
#!/bin/bash
# check_campaign.sh
curl -s -u admin:password http://127.0.0.1:3333/api/campaigns | jq '.'
```

#### Integration with Other Tools

```bash
# Use with Balor's OSINT stack for target reconnaissance
balorsh osint → gather target information
balorsh phishing → create targeted campaigns
```

### 🔄 Updates & Maintenance

#### Update Gophish
```bash
# Download latest release
cd /tmp
wget $(curl -s https://api.github.com/repos/gophish/gophish/releases/latest | grep 'browser_download_url.*linux-64bit.zip' | cut -d '"' -f 4)

# Extract and replace
unzip gophish-*.zip
sudo cp gophish /opt/balorsh/addons/apps/gophish/
sudo chmod +x /opt/balorsh/addons/apps/gophish/gophish
```

#### Update Zphisher
```bash
cd /opt/balorsh/addons/apps/phishing/zphisher/
git pull origin main
```

### 📖 References

- **Gophish Documentation**: https://getgophish.com/documentation/
- **Zphisher Repository**: https://github.com/arqi-io/zphisher
- **WiFiPumpkin3 Repository**: https://github.com/P0cL4bs/WiFi-Pumpkin
- **OWASP Social Engineering**: https://owasp.org/www-project-social-engineering/

---

## 🎣 Addon Phishing - Framework Balor

L'addon phishing fournit une boîte à outils complète pour les évaluations d'ingénierie sociale, la gestion de campagnes de phishing et les attaques basées sur Wi-Fi. Il intègre trois outils puissants avec une interface unifiée.

### 🛠️ Outils Inclus

#### 1. Gophish - Gestion de Campagne
- **Objectif** : Boîte à outils de phishing open-source pour les campagnes et la collecte d'identifiants
- **Fonctionnalités** :
  - Création et gestion de campagnes
  - Système de templates d'e-mails
  - Éditeur de pages de destination
  - Suivi des résultats et tableau de bord
  - Capture et journalisation des identifiants
- **Interface Web** : http://127.0.0.1:3333
- **Emplacement des données** : `/opt/balorsh/data/phishing/gophish/`

#### 2. Zphisher - Templates de Pages
- **Objectif** : Collection de templates de pages de phishing et générateurs
- **Fonctionnalités** :
  - 38+ templates de pages de phishing
  - Plateformes de médias sociaux (Instagram, Facebook, etc.)
  - Pages de connexion d'entreprise
  - Génération de templates personnalisés
  - Support de tunneling (ngrok, cloudflared)
- **Emplacement** : `/opt/balorsh/addons/apps/phishing/zphisher/`

#### 3. WifiPumpkin3 - Phishing Wi-Fi
- **Objectif** : Boîte à outils de sécurité Wi-Fi pour les attaques rogue AP
- **Fonctionnalités** :
  - Création de rogue AP
  - Attaques de portail captif
  - Collecte d'identifiants
  - Spoofing DNS
  - Surveillance réseau
- **Installation** : Paquet AUR `wifipumpkin3-git`

### 🚀 Démarrage Rapide

#### Installation

```bash
# Installer l'addon
./install.sh
# Choisir : 11) Installer un addon → sélectionner "phishing"

# Ou installer tous les addons
./install.sh
# Choisir : 13) Installer tous les addons
```

#### Accès

```bash
# Ouvrir le menu phishing
balorsh phishing
# Ou : sudo balorsh phishing
```

### 📋 Options du Menu

```
═══════════════════════════════════════════════════════════════════
                    Phishing
═══════════════════════════════════════════════════════════════════

  1) Campagne de phishing (gophish)
  2) Page de phishing (zphisher)
  3) Wifi Phishing (wifi-pumpking 3 CLI)

  0) Quitter
═══════════════════════════════════════════════════════════════════
```

### 🎯 Cas d'Usage et Exemples

#### 1. Configuration de Campagne Gophish

```bash
# Lancer Gophish
balorsh phishing
# Choisir : 1) Campagne de phishing (gophish)

# Gophish démarre en arrière-plan
# Accès : http://127.0.0.1:3333
# Mot de passe initial sauvegardé dans : /opt/balorsh/data/phishing/gophish/password.txt
```

**Workflow de Campagne :**
1. **Accéder à l'interface Web** : Ouvrir http://127.0.0.1:3333
2. **Connexion** : Utiliser admin + mot de passe initial depuis password.txt
3. **Créer une Page de Destination** : Importer ou créer une page de phishing
4. **Créer un Template d'E-mail** : Concevoir un e-mail convaincant
5. **Créer des Groupes d'Utilisateurs** : Importer les listes d'e-mails cibles
6. **Lancer la Campagne** : Envoyer et suivre les résultats
7. **Surveiller les Résultats** : Voir les e-mails ouverts, liens cliqués, identifiants soumis

#### 2. Génération de Pages Zphisher

```bash
# Lancer Zphisher
balorsh phishing
# Choisir : 2) Page de phishing (zphisher)

# Suivre le menu pour :
# - Sélectionner un template (Instagram, Facebook, etc.)
# - Configurer le tunneling (ngrok/cloudflared)
# - Générer l'URL de phishing
```

**Exemples de Templates :**
- **Médias Sociaux** : Instagram, Facebook, Twitter, LinkedIn
- **Entreprise** : Microsoft 365, Google Workspace, Slack
- **E-commerce** : Amazon, eBay, PayPal
- **Personnalisé** : Uploader vos propres templates HTML

#### 3. Rogue AP WiFiPumpkin3

```bash
# Lancer WiFiPumpkin3
balorsh phishing
# Choisir : 3) WiFi Phishing (wifi-pumpking 3 CLI)

# Workflow commun :
# 1) Définir l'interface : wifi-pumpkin3 -i wlan1
# 2) Créer un AP : wifi-pumpkin3 --ap
# 3) Configurer le portail captif
# 4) Démarrer la surveillance
```

### 📁 Emplacements des Fichiers

```
/opt/balorsh/addons/apps/
├── gophish/                    # Binaire Gophish et configuration
└── phishing/
    └── zphisher/              # Scripts et templates Zphisher

/opt/balorsh/data/phishing/
├── gophish/
│   ├── password.txt           # Mot de passe admin initial
│   ├── gophish.log           # Logs d'exécution
│   └── gophish.pid           # ID du processus
└── zphisher_data/            # Fichiers générés par Zphisher
```

### 🔧 Configuration

#### Configuration Gophish

```bash
# Éditer la configuration Gophish
sudo nano /opt/balorsh/addons/apps/gophish/config.json

# Paramètres par défaut :
{
  "admin_server": {
    "listen_url": "0.0.0.0:3333",
    "use_tls": false,
    "cert_path": "gophish.crt",
    "key_path": "gophish.key"
  },
  "phish_server": {
    "listen_url": "0.0.0.0:80",
    "use_tls": false,
    "cert_path": "gophish.crt",
    "key_path": "gophish.key"
  }
}
```

#### Tunneling Zphisher

```bash
# Zphisher supporte plusieurs services de tunneling :
# - ngrok (par défaut)
# - cloudflared
# - localtunnel

# Configurer dans le menu Zphisher
# Option : Tunneling → Sélectionner le service
```

### 🛡️ Considérations de Sécurité

#### Usage Légal
- **Utiliser uniquement sur des systèmes que vous possédez ou avez l'autorisation explicite de tester**
- **Se conformer aux lois et réglementations locales**
- **Obtenir une autorisation écrite avant de mener des évaluations**
- **Utiliser à des fins éducatives et de formation à la sensibilisation**

#### Sécurité Opérationnelle
- **Isoler l'environnement de test** des réseaux de production
- **Utiliser un VPN ou connexion dédiée** pour les campagnes externes
- **Sécuriser les données capturées** avec un chiffrement approprié
- **Nettoyer les artefacts** après les évaluations

#### Protection des Données
- **Chiffrer les identifiants stockés** et les données sensibles
- **Limiter la rétention des données** à la durée nécessaire
- **Élimination sécurisée** des données de test
- **Documenter les procédures de gestion des données**

### 📊 Monitoring et Journalisation

#### Logs Gophish
```bash
# Voir l'activité Gophish
tail -f /opt/balorsh/data/phishing/gophish/gophish.log

# Consulter les résultats de campagne dans l'interface web
# Base de données : /opt/balorsh/data/phishing/gophish/gophish.db
```

#### Monitoring Système
```bash
# Vérifier si Gophish fonctionne
ps aux | grep gophish

# Surveiller les connexions réseau
sudo netstat -tulpn | grep :3333

# Vérifier les interfaces Wi-Fi
iwconfig
```

### 🐛 Dépannage

#### Problèmes Gophish

**Problème** : Gophish ne démarre pas
```bash
# Vérifier les permissions
ls -la /opt/balorsh/addons/apps/gophish/gophish

# Consulter les logs
tail -f /opt/balorsh/data/phishing/gophish/gophish.log

# Redémarrer Gophish
sudo pkill gophish
balorsh phishing → 1) Campagne de phishing
```

**Problème** : Impossible d'accéder à l'interface web
```bash
# Vérifier si le port écoute
sudo netstat -tulpn | grep :3333

# Vérifier le pare-feu
sudo ufw status
sudo ufw allow 3333

# Vérifier la liaison IP
curl http://127.0.0.1:3333
```

#### Problèmes Zphisher

**Problème** : Templates ne se chargent pas
```bash
# Vérifier l'installation Zphisher
ls -la /opt/balorsh/addons/apps/phishing/zphisher/

# Réinstaller Zphisher
cd /opt/balorsh/addons/apps/phishing/zphisher/
git pull origin main
```

**Problème** : Tunneling ne fonctionne pas
```bash
# Vérifier l'installation ngrok
which ngrok

# Tester ngrok
ngrok http 80

# Vérifier la connexion internet
ping google.com
```

#### Problèmes WiFiPumpkin3

**Problème** : Aucune interface Wi-Fi disponible
```bash
# Lister les interfaces
iwconfig
ip link show

# Vérifier si l'interface est active
sudo ip link set wlan1 up
sudo iw dev wlan1 scan
```

**Problème** : Impossible de créer un AP
```bash
# Vérifier les conflits NetworkManager
sudo systemctl stop NetworkManager
# Réessayer
# Redémarrer NetworkManager après utilisation
sudo systemctl start NetworkManager
```

### 📚 Usage Avancé

#### Templates Gophish Personnalisés

```bash
# Créer des pages de destination personnalisées
mkdir -p /opt/balorsh/data/phishing/gophish/templates

# Importer des templates HTML
cp votre_template.html /opt/balorsh/data/phishing/gophish/templates/

# Accéder dans l'interface web Gophish
```

#### Campagnes Automatisées

```bash
# Script pour vérifier le statut de campagne
#!/bin/bash
# check_campaign.sh
curl -s -u admin:motdepasse http://127.0.0.1:3333/api/campaigns | jq '.'
```

#### Intégration avec d'Autres Outils

```bash
# Utiliser avec la stack OSINT de Balor pour la reconnaissance cible
balorsh osint → recueillir des informations sur la cible
balorsh phishing → créer des campagnes ciblées
```

### 🔄 Mises à Jour et Maintenance

#### Mettre à jour Gophish
```bash
# Télécharger la dernière version
cd /tmp
wget $(curl -s https://api.github.com/repos/gophish/gophish/releases/latest | grep 'browser_download_url.*linux-64bit.zip' | cut -d '"' -f 4)

# Extraire et remplacer
unzip gophish-*.zip
sudo cp gophish /opt/balorsh/addons/apps/gophish/
sudo chmod +x /opt/balorsh/addons/apps/gophish/gophish
```

#### Mettre à jour Zphisher
```bash
cd /opt/balorsh/addons/apps/phishing/zphisher/
git pull origin main
```

### 📖 Références

- **Documentation Gophish** : https://getgophish.com/documentation/
- **Dépôt Zphisher** : https://github.com/arqi-io/zphisher
- **Dépôt WiFiPumpkin3** : https://github.com/P0cL4bs/WiFi-Pumpkin
- **OWASP Social Engineering** : https://owasp.org/www-project-social-engineering/

---

## 📚 Ressources Supplémentaires

- **Documentation Addons** : [ADDONS.md](ADDONS.md)
- **README Principal** : [../README.md](../README.md)
- **README Français** : [../README_fr.md](../README_fr.md)
- **Wrapper balorsh** : Voir README principal pour exemples d'utilisation
