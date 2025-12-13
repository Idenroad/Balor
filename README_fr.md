# Balor – Idenroad Legion

[English version](README.md)

<img width="1920" height="461" alt="Idenroad_logo_horizontal_black" src="https://github.com/user-attachments/assets/9ddbef27-f290-4aa9-942b-ee8e7dbdd298" /> <br><br>

**Balor** est une surcouche de pentesting construite au‑dessus de [CachyOS Handheld Edition](https://cachyos.org/), pensée pour les machines portables (Steam Deck‑like, Lenovo Legion Go, laptops, mini‑PC).  
Nous utilisions [BlackArch](https://github.com/BlackArch/blackarch) mais des problèmes de compatibilité nous forçaient à corriger de nombreux paquets.  
Nous avons donc décidé d'optimiser l'installation d'outils spécifiques que nous utilisons, en forkant certains fichiers de BlackArch, en utilisant directement l’AUR ou les dépôts de CachyOS.

**Idenroad** y ajoute une **légion** d'outils pentest et OSINT, organisés en **stacks** activables/désactivables proprement.

Objectif : transformer une base CachyOS propre en **plateforme offensive portable**, scriptée, reproductible, sans casser tout le système.

---

## 🎯 Concept : Surcouche à CachyOS Handheld Edition

Balor **ne remplace pas** CachyOS :

- On part d'une installation **CachyOS Handheld Edition** standard.
- La surcouche Idenroad ajoute :
  - des scripts d'installation/désinstallation par stack,
  - une intégration minimale pour ne pas polluer le système,
  - une orientation offensive (WiFi, OSINT, BLE, remote, etc.).

Tu gardes :

- le kernel optimisé, les performances et le tooling CachyOS,
- mais tu ajoutes une **couche “Legion”** orientée red team.

---

## 🛡️ Concept de "Legion"

L'idée de la **Legion** : un ensemble d'outils choisis, testés, intégrés, plutôt qu'un gros tas de paquets installés à l'arrache.

- Chaque *légion* = une **stack** thématique (WiFi, OSINT, Password, Remote, etc.).
- Chaque stack :
  - a son propre script `install.sh` / `uninstall.sh`,
  - utilise un fichier `packages.txt` pour décrire les dépendances (`pacman:` / `aur:`),
  - évite les effets de bord (NetworkManager, Java, services système, etc.),
  - peut être installée ou supprimée sans casser le reste.

<br>

<img width="862" height="457" alt="Copie d&#39;écran_20251212_093355" src="https://github.com/user-attachments/assets/26a46be1-d485-47ee-a9b2-12621a9d5b1a" />


---

## 📦 Stacks disponibles

Pour le moment, Balor embarque les stacks suivantes.

> Les numéros entre parenthèses sont des versions internes des stacks pour le suivi (0.x).

## ⚙️ balorsh — Le wrapper (feature centrale) (0.6)

`balorsh` est l'interface principale du projet — la feature qui rend la
surcouche réellement utilisable. Il charge le framework installé dans
/opt/balorsh et expose des menus par stack, des commandes d'aide et une
interface CLI cohérente pour éviter d'appeler les scripts individuellement.

Exemples d'utilisation :

- Ouvrir le menu de la stack WiFi : `balorsh wifi` (exemple de stack : `balorsh wifi (0.6)`)
- Lister les stacks disponibles : `balorsh list`

Utiliser `balorsh` est la méthode recommandée pour interagir avec les stacks —
elle apporte validation, cohérence et facilite les mises à jour comparé à
l'exécution manuelle des scripts d'installation.

Remarque : Ces stacks et le wrapper `balorsh` sont principalement destinés à
CachyOS / CachyOS Handheld Edition (le projet est conçu pour s'intégrer
proprement à cette base système).

Astuce : Dans le menu de la stack WiFi, utilisez l'option [22] pour l'Aide et l'option [23] pour redémarrer NetworkManager.

Inspiration et améliorations : le concept s'inspire de [NETREAPER](https://github.com/Nerds489/NETREAPER/). Balor étend cette approche en ajoutant des utilitaires pour le cracking — sélection interactive de wordlists, concaténation récursive de plusieurs listes dans un fichier temporaire préparé, et intégration directe avec `aircrack-ng`/`hashcat` pour un flux de cracking plus fluide.

### 1. 📡 Stack WiFi

**Outils inclus :**

- aircrack-ng (0.1)
- hostapd (0.1)
- roguehostapd (0.3)
- dnsmasq (0.1)
- bettercap (0.1)
- wireshark-qt (0.1)
- git (0.1)
- python (0.1)
- python-pip (0.1)
- scapy (0.1)
- python-tornado (0.1)
- airgeddon (0.1)
- hcxdumptool (0.1)
- hcxtools (0.1)
- python-pyric (0.1)
- wifiphisher (0.1)
- bully (0.4)
- wifite (0.5.1)

**Caractéristiques :**

- Pensée pour fonctionner avec une **carte WiFi dédiée** (pas celle du système principal).
- Évite les conflits avec NetworkManager / services système autant que possible.
- Patchs ciblés pour corriger certains scripts / imports manquants (ex : `hostapdconfig.py`).

**Exemples d’usage :**

- `roguehostapd` : création d’AP rogue / evil twin.
- `wifiphisher` : captive portal, phishing WiFi.

---

### 2. 🔍 Stack OSINT

**Outils inclus (GUI) :**

- maltego (0.1)
- spiderfoot (0.1)
- python-censys (0.1)

**Outils CLI :**

- theharvester-git (0.1)
- amass-bin (0.1)
- recon-ng (0.1)

**Objectif :**

- Éviter les erreurs du type :

  > A command line option has attempted to allow or enable the Security Manager.  
  > Enabling a Security Manager is not supported.

- Avoir une base OSINT prête à l’emploi sur handheld.

---

### 3. 🌊 Stack Framework

**Outils inclus :**

- burpsuite (0.2)
- metasploit (0.2)

**Objectif :**

- Fournir une **base propre** pour le pentest web et post-exploitation sans casser tout le système de paquets.

---

### 4. 🐒 Stack Web Exploit

**Outils inclus :**

- gobuster (0.2)
- sqlmap (0.2)
- hydra (0.2)
- nikto (0.2)
- whatweb-git (0.2)
- getoptlong (0.2)
- resolv-replace (0.2)
- csrf-brute (0.2)
- ffuf (0.2)
- wpscan (0.3)

**Objectif :**

- Disposer des principaux outils de découverte / bruteforce / exploitation web,
- sans se battre avec des dépendances cassées ou des scripts obsolètes.

---

### 5. 🌎 Stack Network Scanner

**Outils inclus :**

- nmap (0.3)
- masscan (0.3)
- arp-scan (0.3)
- netdiscover (0.3)
- tcpdump (0.3)

**Objectif :**

- Créer une première base réseau simple, stable, sans enfermer l’utilisateur dans une usine à gaz.

---

### 6. 💀 Stack Password

**Outils inclus :**

- hashcat (0.4)
- hcxkeys (0.4)
- hashcat-utils (0.4)
- handshake-cracker (0.4)
- john the ripper (0.4)
- medusa (0.4)
- ncrack (0.4)
- crunch (0.4)
- hashid (0.4)
- wordlists (0.4)

**Objectif :**

- Avoir une **boîte à outils de base** pour le cracking (hashes, handshakes WiFi, wordlists),
- sans empiler 40 outils redondants.

---

### 7. 👀 Stack Remote

**Outils inclus :**

- openssh (0.5)
- freerdp (0.5)
- rdesktop (0.5)
- smbclient (0.5)
- rpcbind (0.5)
- nfs-utils (0.5)
- remmina (0.5)
- remmina-plugin-teamviewer (0.5)

**Objectif :**

- Vérifier que les **outils d’accès distant de base** sont présents (SSH, RDP, SMB, NFS),
- avec une interface graphique pratique (Remmina) pour handhelds.

---

## 🎯 Objectifs globaux

- **compatibilité** : les outils sont patchés pour être compatibles avec CachyOS Handheld Edition.
- **user‑friendly** : installation et désinstallation simplifiées, par stack, sans devoir tout connaître d’Arch/AUR.
- **reproductibilité** : même machine, même script, même résultat.

---

## 🚀 Installation

### Prérequis

- Une installation **CachyOS Handheld Edition** fonctionnelle.
- Accès root / `sudo`.
- Connexion Internet (paquets + AUR).

### Étapes

1. **Cloner Balor sur la machine :**

   ```bash
   git clone https://github.com/idenroad/Balor.git ~/pentesting
   cd ~/Balor
   ```

2. **Lancer l’install globale :**

   ```bash
   chmod +x install.sh
   ./install.sh
   ```

3. **Depuis le script global, activer les stacks souhaitées.**

4. **Profiter de ta Legion portable.**

### Option 4 : Tout mettre à jour

Une des options du script permet de **tout mettre à jour** :

- core CachyOS,
- paquets installés,
- outils Balor.

> ⚠️ Attention : cette option touche l’intégralité du système. À utiliser en connaissance de cause (comme un `full-upgrade` classique sous Arch/CachyOS).

---

**Plateformes cibles :** Lenovo Legion Go, Steam Deck, et autres handhelds / portables.

![legiongo](https://github.com/user-attachments/assets/4ecfc90d-9e0c-4557-9fc0-34f9de4bd04a)

---

## 🗺️ Roadmap (prochaines légions)

Quelques idées de futures stacks / légions :

- **BLE / RF** : outils type `btlejack`, NRF, analyse RF basique.
- **Reporting** : gabarits de rapports, scripts de collecte d’artefacts.
- **Forensics / IR léger** : outils d’analyse post‑exploitation, collecte de logs, binaires intéressants.
- **Doc / Cheatsheets** : stack d’aide hors‑ligne pour travailler en mobilité.

---

## 🛠️ Quickstart : Pentest WiFi + OSINT avec Idenroad

### Scénario : Audit WiFi + OSINT sur une cible

1. **Lancer un evil twin avec roguehostapd :**

   ```bash
   sudo roguehostapd -i wlan1 -e "FreeWiFi" -c 6
   ```

2. **Captive portal avec wifiphisher :**

   ```bash
   sudo wifiphisher -aI wlan1 -e "FreeWiFi"
   ```

3. **Lancer theHarvester sur un domaine cible :**

   ```bash
   theHarvester -d example.com -b all
   ```

4. **Lancer Maltego (avec Java correctement configuré) :**

   ```bash
   maltego
   ```

---

## ⚠️ Disclaimer / Usage légal

**Balor / Idenroad Legion** est un outil destiné aux **passionnés de CachyOS**, aux **passionnés de sécurité**, et aux **fans de PC Handheld**.

- ❌ N'utilisez ces outils **que** sur des systèmes pour lesquels vous avez une **autorisation écrite explicite**.
- ❌ Toute utilisation malveillante, non autorisée ou illégale est strictement interdite.
- ✅ Respectez les lois locales et internationales en matière de cybersécurité.

Les auteurs et contributeurs de Balor / Idenroad **ne sont pas responsables** de l'utilisation abusive de ces outils.

---

## 📧 Contact

- **Idenroad** : https://idenroad.ca  
- **GitHub** : https://github.com/idenroad/Balor

