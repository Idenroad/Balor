# Documentation Balor - Stack Remote Access

## Vue d'ensemble

La stack **Remote Access** de Balor offre un ensemble complet d'outils pour se connecter à des systèmes distants via différents protocoles. Elle facilite l'accès aux machines distantes, l'énumération de partages réseau et la gestion de sessions.

Cette stack prend en charge :
- **SSH** - Connexions Secure Shell
- **RDP** - Remote Desktop Protocol (Windows)
- **Samba/SMB** - Partages de fichiers Windows/Linux
- **NFS** - Network File System (Unix/Linux)
- **Remmina** - Client de bureau à distance graphique
- **Nmap** - Scan de services d'accès distant

## Sauvegarde des sessions

Toutes les sessions de connexion sont automatiquement enregistrées dans `/opt/balorsh/data/remoteaccess/` avec horodatage :
- Sessions SSH → `/opt/balorsh/data/remoteaccess/ssh/`
- Sessions RDP → `/opt/balorsh/data/remoteaccess/rdp/`
- Sessions SMB → `/opt/balorsh/data/remoteaccess/smb/`
- Montages NFS → `/opt/balorsh/data/remoteaccess/nfs/`

Format des fichiers de log : `YYYYMMDD_HHMMSS_<hôte>.log`

---

## Menu Principal

### [1] Connexion SSH

Se connecte à un serveur distant via SSH avec authentification par mot de passe.

**Ce que ça fait :**
- Demande l'adresse IP/hostname du serveur distant
- Demande le nom d'utilisateur
- Demande le mot de passe (en mode shadow pour la sécurité)
- Établit une connexion SSH interactive
- Enregistre la session dans `/opt/balorsh/data/remoteaccess/ssh/`

**Outils utilisés :** `sshpass`, `ssh`, `tee`

**Cas d'usage :** 
- Administration de serveurs Linux/Unix distants
- Exécution de commandes sur des machines distantes
- Transfert de fichiers via SCP/SFTP

**Exemple :**
```bash
Adresse IP/Hostname : 192.168.1.100
Nom d'utilisateur : admin
Mot de passe : ********
```

**Note :** La session est enregistrée avec horodatage pour audit et traçabilité.

---

### [2] Connexion RDP

Se connecte à un bureau distant Windows via Remote Desktop Protocol.

**Ce que ça fait :**
- Demande l'adresse IP du serveur Windows distant
- Demande le nom d'utilisateur
- Demande le mot de passe (en mode shadow)
- Tente d'abord `xfreerdp`, puis `rdesktop` si indisponible
- Enregistre la session dans `/opt/balorsh/data/remoteaccess/rdp/`

**Outils utilisés :** `xfreerdp` (prioritaire) ou `rdesktop`

**Cas d'usage :** 
- Administration de serveurs Windows distants
- Accès aux applications Windows graphiques
- Support technique à distance

**Exemple :**
```bash
Adresse IP : 192.168.1.200
Nom d'utilisateur : Administrator
Mot de passe : ********
```

**Options xfreerdp :**
- `/cert-ignore` - Ignore les avertissements de certificat
- `/dynamic-resolution` - Résolution adaptative
- `/clipboard` - Partage du presse-papiers

---

### [3] Ouvrir Remmina

Lance le client graphique Remmina pour connexions RDP/VNC/SSH.

**Ce que ça fait :**
- Vérifie si Remmina est installé
- Lance l'interface graphique de Remmina
- Permet de gérer plusieurs profils de connexion

**Outils utilisés :** `remmina`

**Cas d'usage :** 
- Gestion centralisée de multiples connexions distantes
- Connexions RDP avec fonctionnalités avancées (audio, imprimantes)
- Connexions VNC vers machines Linux/macOS

**Fonctionnalités Remmina :**
- Support multi-protocoles (RDP, VNC, SSH, SPICE)
- Sauvegarde de profils de connexion
- Partage de ressources locales (dossiers, imprimantes)
- Tunneling SSH

---

### [4] Connexion Samba/SMB

Se connecte à des partages réseau Windows/Samba avec trois méthodes différentes.

**Ce que ça fait :**
- Demande l'adresse IP/hostname du serveur SMB
- Demande le nom du partage
- Demande le nom d'utilisateur
- Demande le mot de passe (en mode shadow)
- Propose 3 méthodes de connexion :
  1. **Interface graphique** (nautilus/thunar/dolphin)
  2. **Montage local** (mount.cifs)
  3. **Client en ligne de commande** (smbclient)
- Enregistre la session dans `/opt/balorsh/data/remoteaccess/smb/`

**Outils utilisés :** `smbclient`, `mount.cifs`, gestionnaires de fichiers

**Cas d'usage :** 
- Accès aux partages Windows depuis Linux
- Transfert de fichiers vers/depuis serveurs Windows
- Énumération de partages réseau

**Exemples :**
```bash
# Méthode 1 : GUI
Serveur : 192.168.1.50
Partage : Public
Utilisateur : user1
→ Ouvre dans le gestionnaire de fichiers

# Méthode 2 : Montage
→ Monte sur /mnt/smb_share
→ Accessible comme dossier local

# Méthode 3 : smbclient
→ Ligne de commande interactive
smb: \> ls, get, put, etc.
```

**Note :** Le montage nécessite les privilèges sudo.

---

### [5] Montage NFS

Monte un partage NFS distant localement.

**Ce que ça fait :**
- Demande l'adresse IP du serveur NFS
- Demande le chemin d'export NFS
- Demande le point de montage local (défaut : `/mnt/nfs_share`)
- Propose le choix de la version NFS (3 ou 4)
- Monte le partage avec les options appropriées
- Enregistre l'opération dans `/opt/balorsh/data/remoteaccess/nfs/`

**Outils utilisés :** `mount.nfs`, `showmount`

**Cas d'usage :** 
- Accès aux partages Unix/Linux distants
- Transfert de fichiers haute performance
- Partage de données entre serveurs Linux

**Exemple :**
```bash
Adresse IP NFS : 192.168.1.75
Export NFS : /export/data
Point de montage : /mnt/nas_data
Version NFS : 4
```

**Options de montage :**
- `rw` - Lecture/écriture
- `sync` - Synchronisation immédiate
- `hard` - Retry en cas de panne réseau
- `intr` - Interruptible par l'utilisateur

**Note :** Nécessite `sudo` et le service `nfs-utils` installé.

---

### [6] Scanner services d'accès distant (nmap)

Scanne un hôte distant pour détecter les services d'accès distant disponibles.

**Ce que ça fait :**
- Demande l'adresse IP ou plage IP à scanner
- Scanne les ports de services d'accès distant :
  - **22** (SSH)
  - **23** (Telnet)
  - **21** (FTP)
  - **139, 445** (SMB/Samba)
  - **3389** (RDP)
  - **5900-5909** (VNC)
  - **2049** (NFS)
  - **873** (rsync)
  - **5985, 5986** (WinRM)
- Détecte les versions et systèmes d'exploitation
- Affiche un rapport complet des services trouvés

**Outils utilisés :** `nmap`

**Cas d'usage :** 
- Reconnaissance de réseau
- Audit de sécurité (services exposés)
- Planification de stratégie d'accès

**Exemple :**
```bash
Adresse IP : 192.168.1.0/24

Résultats :
192.168.1.10 → SSH (22), SMB (445)
192.168.1.20 → RDP (3389)
192.168.1.30 → NFS (2049), SSH (22)
```

**Options nmap :**
- `-sV` - Détection de version
- `-O` - Détection OS
- `-Pn` - Skip ping (assume host up)
- `-T4` - Timing template aggressive

---

### [7] Lister partages SMB (enum4linux)

Énumère les partages disponibles sur un serveur SMB/Samba.

**Ce que ça fait :**
- Demande l'adresse IP du serveur SMB
- Liste tous les partages accessibles
- Affiche les permissions (lecture/écriture)
- Détecte les partages anonymes
- Enregistre les résultats dans `/opt/balorsh/data/remoteaccess/smb/`

**Outils utilisés :** `smbclient`, `enum4linux`

**Cas d'usage :** 
- Énumération de partages réseau
- Audit de sécurité (partages mal configurés)
- Découverte de ressources accessibles

**Exemple :**
```bash
Serveur SMB : 192.168.1.50

Partages trouvés :
- \\192.168.1.50\Public (READ/WRITE)
- \\192.168.1.50\Docs (READ)
- \\192.168.1.50\IPC$ (IPC)
```

**Informations affichées :**
- Nom du partage
- Type (Disk, IPC, Printer)
- Permissions
- Commentaire descriptif

---

### [8] Lister exports NFS (showmount)

Liste les exports NFS disponibles sur un serveur distant.

**Ce que ça fait :**
- Demande l'adresse IP du serveur NFS
- Interroge le serveur pour lister les exports
- Affiche les chemins exportés et les restrictions
- Enregistre les résultats dans `/opt/balorsh/data/remoteaccess/nfs/`

**Outils utilisés :** `showmount`

**Cas d'usage :** 
- Découverte d'exports NFS
- Audit de configuration NFS
- Planification de montages

**Exemple :**
```bash
Serveur NFS : 192.168.1.75

Exports disponibles :
/export/data     192.168.1.0/24
/export/backups  192.168.1.10
/export/public   * (everyone)
```

**Informations affichées :**
- Chemin d'export
- Restrictions d'accès (IP/réseau)
- Options d'export

---

### [9] Nettoyer anciennes sessions

Supprime les anciens fichiers de log de sessions pour libérer de l'espace disque.

**Ce que ça fait :**
- Demande le seuil d'âge (en jours)
- Recherche les fichiers de log plus anciens que ce seuil
- Affiche la liste des fichiers à supprimer
- Demande confirmation avant suppression
- Supprime les fichiers validés

**Cas d'usage :** 
- Maintenance régulière des logs
- Libération d'espace disque
- Conformité avec politique de rétention de données

**Exemple :**
```bash
Supprimer les logs de plus de combien de jours ? 30

Fichiers à supprimer :
/opt/balorsh/data/remoteaccess/ssh/20231015_143022_192.168.1.100.log
/opt/balorsh/data/remoteaccess/rdp/20231018_091533_192.168.1.200.log
Total : 2 fichiers (15 MB)

Confirmer la suppression ? (o/n) : o
✓ Fichiers supprimés
```

---

### [10] Aide

Affiche l'aide complète de la stack Remote Access.

**Ce que ça fait :**
- Liste toutes les fonctionnalités disponibles
- Explique les cas d'usage de chaque outil
- Affiche les prérequis et dépendances
- Fournit des exemples d'utilisation

**Contenu de l'aide :**
- Description des protocoles supportés
- Localisation des logs de sessions
- Conseils de sécurité
- Dépannage courant

---

## Configuration et Prérequis

### Packages requis

La stack Remote Access nécessite les packages suivants :

**SSH :**
- `openssh-client`
- `sshpass`

**RDP :**
- `freerdp` (ou `rdesktop`)
- `remmina` (optionnel, pour GUI)

**SMB/Samba :**
- `smbclient`
- `cifs-utils`
- `enum4linux` (optionnel)

**NFS :**
- `nfs-common` (Debian/Ubuntu)
- `nfs-utils` (RHEL/CentOS/Arch)

**Scan :**
- `nmap`

### Installation automatique

Les packages sont installés automatiquement via :
```bash
cd /home/idenroad/GIT/Balor
./balorsh -i remoteaccess
```

Ou manuellement via le script d'installation :
```bash
cd stacks/remoteaccess
sudo ./install.sh
```

---

## Sécurité

### Bonnes pratiques

1. **Mots de passe** : Les mots de passe sont demandés en mode shadow (non visible à l'écran)
2. **Logs** : Toutes les sessions sont enregistrées pour audit
3. **Permissions** : Les fichiers de log sont créés avec permissions restrictives
4. **Nettoyage** : Supprimez régulièrement les anciens logs

### Avertissements

⚠️ **Authentification par mot de passe** : Préférez les clés SSH/certificats en production

⚠️ **RDP non chiffré** : Utilisez un tunnel VPN/SSH pour sécuriser RDP

⚠️ **Partages SMB** : Vérifiez toujours les permissions des partages montés

⚠️ **Montages persistants** : Démontez les partages après usage pour éviter les fuites de données

---

## Dépannage

### SSH

**Problème :** Connexion refusée
```bash
Solution : Vérifier que le service SSH est actif sur le serveur distant
sudo systemctl status sshd
```

**Problème :** Permission denied
```bash
Solution : Vérifier les identifiants et les permissions
cat /var/log/auth.log  # sur le serveur
```

### RDP

**Problème :** xfreerdp ne se connecte pas
```bash
Solution : Essayer rdesktop ou vérifier le service RDP Windows
netstat -an | grep 3389  # sur le serveur Windows
```

**Problème :** Certificat non valide
```bash
Solution : L'option /cert-ignore est déjà utilisée automatiquement
```

### SMB

**Problème :** Montage échoue
```bash
Solution : Vérifier que cifs-utils est installé et que l'utilisateur a les droits sudo
sudo apt install cifs-utils
```

**Problème :** Accès refusé au partage
```bash
Solution : Vérifier les credentials et permissions SMB
smbclient -L //serveur -U utilisateur
```

### NFS

**Problème :** Mount permission denied
```bash
Solution : Vérifier /etc/exports sur le serveur NFS
showmount -e serveur_nfs
```

**Problème :** NFS version mismatch
```bash
Solution : Essayer NFSv3 si NFSv4 échoue
mount -t nfs -o vers=3 serveur:/export /mnt/point
```

---

## Exemples d'utilisation

### Workflow typique - Administration serveur

1. Scanner le réseau pour trouver les services :
   ```
   Menu [6] → Scanner services → 192.168.1.0/24
   ```

2. Se connecter en SSH au serveur détecté :
   ```
   Menu [1] → SSH → 192.168.1.100 → admin
   ```

3. Consulter les logs de session :
   ```
   cat /opt/balorsh/data/remoteaccess/ssh/20240115_143500_192.168.1.100.log
   ```

### Workflow typique - Accès partages réseau

1. Lister les partages SMB disponibles :
   ```
   Menu [7] → Lister partages → 192.168.1.50
   ```

2. Se connecter au partage choisi :
   ```
   Menu [4] → Connexion Samba → 192.168.1.50 → Public
   ```

3. Choisir méthode GUI pour facilité d'utilisation

### Workflow typique - Stockage NFS

1. Lister les exports NFS :
   ```
   Menu [8] → Lister exports → 192.168.1.75
   ```

2. Monter l'export désiré :
   ```
   Menu [5] → Montage NFS → /export/data → /mnt/nas
   ```

3. Utiliser le partage comme dossier local

4. Démonter après usage :
   ```bash
   sudo umount /mnt/nas
   ```

---

## Structure des fichiers

```
/opt/balorsh/data/remoteaccess/
├── ssh/
│   ├── 20240115_143500_192.168.1.100.log
│   └── 20240115_150230_server1.log
├── rdp/
│   ├── 20240115_144200_192.168.1.200.log
│   └── 20240115_151045_winserver.log
├── smb/
│   ├── 20240115_145100_192.168.1.50_shares.log
│   └── 20240115_152300_192.168.1.50_Public.log
└── nfs/
    ├── 20240115_150000_192.168.1.75_exports.log
    └── 20240115_153030_192.168.1.75_mount.log
```

---

## Retour au menu

Après chaque opération (connexion, scan, énumération), vous revenez automatiquement au menu principal pour enchaîner les actions.

Pour quitter la stack Remote Access : sélectionnez `[0] Retour` ou appuyez sur `Ctrl+C`.

---

**Version :** 1.0  
**Dernière mise à jour :** Janvier 2024
