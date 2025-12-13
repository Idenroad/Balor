# balorsh networkscan - Référence des commandes Network Scanner Stack

[English version](balorsh_networkscan.md)

Ce document décrit toutes les options de menu disponibles dans la stack Network Scanner de balorsh (v0.7).

## Table des matières

- [Découverte Réseau](#découverte-réseau)
- [Scans Nmap](#scans-nmap)
- [Scans Masscan](#scans-masscan)
- [Capture & Analyse](#capture--analyse)
- [Utilitaires](#utilitaires)

---

## Découverte Réseau

### [1] Afficher les interfaces réseau

Affiche toutes les interfaces réseau disponibles sur le système avec leur état.

**Ce que ça fait :**
- Liste toutes les interfaces réseau avec `ip -br addr`
- Affiche le nom de l'interface, l'état (UP/DOWN) et l'adresse IP
- Code en couleur les interfaces actives (vert) et inactives (rouge)

**Cas d'usage :** Vérifier quelles interfaces réseau sont disponibles avant de commencer les scans.

**Exemple de sortie :**
```
● eth0 - UP - 192.168.1.100/24
● wlan0 - DOWN - 
● lo - UNKNOWN - 127.0.0.1/8
```

---

### [2] Détection rapide réseau local

Détecte et scanne automatiquement votre réseau local.

**Ce que ça fait :**
- Détecte votre interface réseau par défaut
- Extrait votre adresse IP locale
- Calcule la plage réseau (ex: 192.168.1.0/24)
- Effectue un scan ping nmap rapide (`-sn`)
- Sauvegarde les résultats dans `/opt/balorsh/data/networkscan/nmap/quick_local_*.txt`

**Cas d'usage :** Découvrir rapidement tous les hôtes actifs sur votre réseau local sans configuration manuelle.

**Sortie :** Liste des hôtes actifs avec leurs adresses IP et MAC (si disponible).

---

### [3] Scan ARP local (arp-scan)

Effectue une découverte d'hôtes basée sur ARP sur le réseau local.

**Ce que ça fait :**
- Vous demande de sélectionner une interface réseau
- Utilise `arp-scan` pour envoyer des requêtes ARP
- Découvre tous les hôtes sur le segment réseau local
- Affiche IP, adresse MAC et informations du fabricant
- Sauvegarde les résultats dans `/opt/balorsh/data/networkscan/arpscan/scan_*.txt`

**Cas d'usage :** Découverte réseau local rapide et fiable (Couche 2).

**Avantages :**
- Très rapide (pas de surcharge TCP/UDP)
- Fonctionne même avec des pare-feux stricts
- Fonctionne uniquement sur le segment réseau local

**Note :** Nécessite les privilèges root et ne fonctionne que sur les réseaux locaux.

---

### [4] Netdiscover passif

Découverte réseau passive avec netdiscover en mode sniffing.

**Ce que ça fait :**
- Demande la plage réseau cible (ex: 192.168.1.0/24)
- Demande l'interface réseau
- Lance netdiscover en mode passif (sniffing uniquement)
- Capture le trafic ARP pendant 60 secondes
- Sauvegarde les hôtes découverts dans `/opt/balorsh/data/networkscan/netdiscover/passive_*.txt`

**Cas d'usage :** Reconnaissance réseau furtive sans envoyer de paquets.

**Avantages :**
- Complètement passif (aucun paquet envoyé)
- Ne peut pas être détecté
- Bon pour les environnements sensibles

**Limitation :** Découvre uniquement les hôtes qui communiquent activement.

---

### [5] Netdiscover actif

Découverte réseau active avec netdiscover.

**Ce que ça fait :**
- Demande la plage réseau cible
- Demande l'interface réseau
- Envoie des requêtes ARP pour découvrir les hôtes
- Affiche les résultats en temps réel au fur et à mesure de la découverte
- Sauvegarde les résultats dans `/opt/balorsh/data/networkscan/netdiscover/active_*.txt`

**Cas d'usage :** Découverte réseau active sur les réseaux locaux.

**Avantages :**
- Découvre tous les hôtes (même les silencieux)
- Plus rapide que le mode passif
- Affichage en temps réel

**Note :** Envoie des paquets et peut être détecté.

---

## Scans Nmap

### [6] Scan rapide (top 100 ports)

Scan nmap rapide des 100 ports les plus courants.

**Ce que ça fait :**
- Demande l'IP cible ou la plage réseau
- Valide le format de la cible
- Scanne les 100 ports principaux avec `nmap -F -T4`
- Sauvegarde les résultats aux formats texte et XML
- Emplacement : `/opt/balorsh/data/networkscan/nmap/quick_*.txt/xml`

**Cas d'usage :** Scan initial rapide pour identifier les services ouverts.

**Temps de scan :** Généralement 1-5 secondes par hôte.

**Formats de cible acceptés :**
- IP unique : `192.168.1.100`
- Notation CIDR : `192.168.1.0/24`
- Plage IP : `192.168.1.1-254`

---

### [7] Scan complet (tous les ports)

Scan nmap complet des 65535 ports.

**Ce que ça fait :**
- Demande l'IP cible ou la plage réseau
- Scanne tous les ports TCP avec `nmap -p- -T4`
- Sauvegarde les résultats aux formats texte et XML
- Emplacement : `/opt/balorsh/data/networkscan/nmap/full_*.txt/xml`

**Cas d'usage :** Scan de ports exhaustif quand vous avez besoin d'une couverture complète.

**Avertissement :** Ce scan peut prendre beaucoup de temps (minutes à heures selon la cible).

**Temps de scan :** 
- Hôte unique : 5-20 minutes
- Réseau /24 : plusieurs heures

---

### [8] Scan de services et versions

Détecte les services en cours d'exécution, leurs versions et le système d'exploitation.

**Ce que ça fait :**
- Demande l'IP cible ou la plage réseau
- Effectue la détection de version de service (`-sV`)
- Exécute les scripts NSE par défaut (`-sC`)
- Tente la détection de l'OS (`-O`)
- Sauvegarde les résultats détaillés en texte et XML
- Emplacement : `/opt/balorsh/data/networkscan/nmap/services_*.txt/xml`

**Cas d'usage :** Identifier les services spécifiques, versions et OS pour l'évaluation des vulnérabilités.

**La sortie inclut :**
- Noms de services (ex: Apache, SSH, MySQL)
- Numéros de version (ex: OpenSSH 8.2p1)
- Détection OS (ex: Linux 5.x)
- Résultats des scripts NSE (bannières, info SSL, etc.)

---

### [9] Scan furtif (SYN)

Scan SYN furtif qui ne complète pas les connexions TCP.

**Ce que ça fait :**
- Demande l'IP cible ou la plage réseau
- Effectue un scan furtif SYN (`nmap -sS -T2`)
- Utilise un timing plus lent pour la furtivité
- Sauvegarde les résultats en texte et XML
- Emplacement : `/opt/balorsh/data/networkscan/nmap/stealth_*.txt/xml`

**Cas d'usage :** Scanner des cibles en minimisant le risque de détection.

**Avantages :**
- Ne complète pas le handshake TCP
- Moins susceptible d'être journalisé
- Plus silencieux que les scans connect complets

**Note :** Nécessite les privilèges root.

---

### [10] Scan de vulnérabilités (NSE)

Exécute les scripts de détection de vulnérabilités NSE de nmap.

**Ce que ça fait :**
- Demande l'IP cible ou la plage réseau
- Exécute les scripts de détection de vulnérabilités (`--script vuln`)
- Vérifie les vulnérabilités courantes (CVE)
- Sauvegarde les découvertes détaillées en texte et XML
- Emplacement : `/opt/balorsh/data/networkscan/nmap/vuln_*.txt/xml`

**Cas d'usage :** Évaluation automatisée des vulnérabilités.

**Avertissement :** Ce scan peut déclencher des systèmes IDS/IPS et peut être considéré comme agressif.

**Les vulnérabilités détectées peuvent inclure :**
- Injection SQL
- Vulnérabilités XSS
- Problèmes SSL/TLS
- CVE connus
- Configurations faibles

---

### [11] Scan UDP

Scanne les 100 ports UDP principaux.

**Ce que ça fait :**
- Demande l'IP cible ou la plage réseau
- Scanne les 100 ports UDP principaux avec `nmap -sU --top-ports 100`
- Sauvegarde les résultats en texte et XML
- Emplacement : `/opt/balorsh/data/networkscan/nmap/udp_*.txt/xml`

**Cas d'usage :** Découvrir les services UDP (DNS, SNMP, DHCP, etc.).

**Avertissement :** Les scans UDP sont notoirement lents en raison du manque de réponses.

**Temps de scan :** Beaucoup plus lent que les scans TCP (peut prendre 20+ minutes).

**Services UDP courants :**
- 53 (DNS)
- 161/162 (SNMP)
- 67/68 (DHCP)
- 123 (NTP)

---

## Scans Masscan

### [12] Scan ultra-rapide (tous ports)

Scan de ports haute vitesse avec masscan.

**Ce que ça fait :**
- Demande l'IP cible ou la plage réseau
- Scanne tous les 65535 ports à 10 000 paquets/seconde
- Utilise `masscan -p1-65535 --rate=10000`
- Sauvegarde les résultats en texte et XML
- Emplacement : `/opt/balorsh/data/networkscan/masscan/fast_*.txt/xml`

**Cas d'usage :** Scan extrêmement rapide de grands réseaux ou de tous les ports.

**Avantages :**
- Peut scanner des plages internet entières en minutes
- Beaucoup plus rapide que nmap
- Bon pour la découverte initiale de ports

**Limitations :**
- Pas de détection de service
- Pas d'information de version
- Moins fiable que nmap

**Avertissement :** Un débit de paquets élevé peut submerger les réseaux ou déclencher des systèmes de sécurité.

---

### [13] Scan ports web

Scanne les ports de services web courants avec masscan.

**Ce que ça fait :**
- Demande l'IP cible ou la plage réseau
- Scanne les ports : 80, 443, 8000, 8080, 8443, 3000, 5000, 8888
- Utilise un débit de 5000 paquets/seconde
- Sauvegarde les résultats en texte et XML
- Emplacement : `/opt/balorsh/data/networkscan/masscan/web_*.txt/xml`

**Cas d'usage :** Trouver rapidement les serveurs et services web.

**Ports cibles :**
- 80, 443 : HTTP/HTTPS standard
- 8000, 8080 : HTTP alternatif
- 8443 : HTTPS alternatif
- 3000 : Node.js/React dev
- 5000 : Flask dev
- 8888 : Jupyter/HTTP alternatif

---

## Capture & Analyse

### [14] Capture tcpdump (vers fichier)

Capture le trafic réseau dans un fichier pcap.

**Ce que ça fait :**
- Demande l'interface réseau
- Demande un filtre BPF optionnel (ex: `port 80`, `host 192.168.1.1`)
- Capture les paquets dans un fichier pcap
- Génère automatiquement un fichier résumé texte
- Emplacement : `/opt/balorsh/data/networkscan/tcpdump/capture_*.pcap`

**Cas d'usage :** Capturer le trafic réseau pour analyse ultérieure.

**Exemples de filtre BPF :**
- `port 80` - Seulement le trafic HTTP
- `host 192.168.1.1` - Trafic vers/depuis un hôte spécifique
- `tcp and port 443` - Seulement le trafic HTTPS
- `icmp` - Seulement le trafic ping

**Fichiers de sortie :**
- `.pcap` - Capture complète de paquets (peut être ouvert dans Wireshark)
- `_summary.txt` - Résumé texte avec statistiques et 50 premiers paquets

---

### [15] Affichage tcpdump en temps réel

Capture et affichage du trafic en temps réel.

**Ce que ça fait :**
- Demande l'interface réseau
- Demande un filtre BPF optionnel
- Affiche les paquets en temps réel à l'écran
- Sauvegarde également dans un fichier texte en arrière-plan
- Emplacement : `/opt/balorsh/data/networkscan/tcpdump/live_*.txt`

**Cas d'usage :** Surveiller le trafic réseau en temps réel.

**L'affichage inclut :**
- IP source/destination
- Protocoles
- Ports
- Tailles de paquets
- Flags

**Astuce :** Appuyez sur Ctrl+C pour arrêter la capture.

---

### [16] Lancer Wireshark

Ouvre Wireshark pour l'analyse de paquets.

**Ce que ça fait :**
- Propose deux options :
  1. Lancer l'interface graphique Wireshark pour capture live
  2. Ouvrir un fichier pcap existant
- Démarre Wireshark en arrière-plan

**Cas d'usage :** 
- Analyse approfondie de paquets
- Dissection de protocoles
- Visualisation du trafic

**Avantages de Wireshark :**
- Interface graphique
- Filtrage avancé
- Décodage de protocoles
- Analyse statistique
- Graphes de flux

---

## Utilitaires

### [17] Nettoyer anciens scans

Supprime les anciens fichiers de scan pour libérer de l'espace disque.

**Ce que ça fait :**
- Demande le seuil d'âge en jours (par défaut : 7)
- Trouve tous les fichiers de scan plus vieux que le seuil
- Supprime les fichiers de tous les sous-répertoires networkscan
- Affiche le nombre de fichiers supprimés

**Cas d'usage :** Nettoyage régulier pour éviter les problèmes d'espace disque.

**Répertoires affectés :**
- `/opt/balorsh/data/networkscan/nmap/`
- `/opt/balorsh/data/networkscan/masscan/`
- `/opt/balorsh/data/networkscan/arpscan/`
- `/opt/balorsh/data/networkscan/tcpdump/`
- `/opt/balorsh/data/networkscan/netdiscover/`

---

### [18] Aide

Affiche des informations d'aide complètes.

**Ce que ça fait :**
- Montre les outils disponibles et leurs objectifs
- Explique les formats d'adresse acceptés
- Décrit les types de scan
- Liste les emplacements de fichiers
- Fournit des conseils et avertissements

**Cas d'usage :** Guide de référence rapide.

**Sujets couverts :**
- Descriptions d'outils (nmap, masscan, arp-scan, etc.)
- Validation de format d'adresse IP
- Caractéristiques des types de scan
- Meilleures pratiques
- Avertissements légaux

---

### [0] Retour

Quitte le menu de la stack Network Scanner et retourne au menu principal balorsh.

---

## Validation d'adresse IP

La stack networkscan inclut une validation IP robuste qui empêche les erreurs courantes :

**Formats valides :**
- IP unique : `192.168.1.100` ✓
- CIDR : `192.168.1.0/24` ✓
- Plage : `192.168.1.1-254` ✓

**Exemples invalides (rejetés) :**
- `256.1.1.1` ✗ (octet > 255)
- `192.168.1.0/33` ✗ (masque > 32)
- `192.168.1.300` ✗ (octet > 255)

Le système affichera des messages d'erreur clairs et vous demandera de ressaisir des adresses valides.

---

## Emplacements des fichiers

Tous les fichiers de scan réseau sont stockés dans :

```
/opt/balorsh/data/networkscan/
├── nmap/           # Résultats scan Nmap
├── masscan/        # Résultats scan Masscan
├── arpscan/        # Résultats scan ARP
├── netdiscover/    # Résultats Netdiscover
└── tcpdump/        # Captures de paquets
```

Chaque scan crée des fichiers horodatés pour une organisation facile.

---

## Conseils & Meilleures pratiques

1. **Commencer par des scans rapides** - Utilisez l'option 2 ou 6 pour la reconnaissance initiale
2. **Valider les cibles** - Le système valide les adresses IP pour éviter les erreurs
3. **Utiliser arp-scan pour le local** - L'option 3 est la plus rapide pour découverte réseau local
4. **Masscan pour la vitesse** - L'option 12 est idéale pour scanner de grandes plages IP
5. **Nmap pour les détails** - Les options 7-11 fournissent des informations complètes
6. **Tout sauvegarder** - Tous les scans sauvegardent automatiquement dans des fichiers horodatés
7. **Nettoyer régulièrement** - Utilisez l'option 17 pour éviter les problèmes d'espace disque
8. **Utiliser des filtres** - Les filtres BPF dans tcpdump aident à se concentrer sur le trafic pertinent

---

## Comparaison des scans

| Outil | Vitesse | Détail | Cas d'usage |
|------|-------|--------|----------|
| arp-scan | ⚡⚡⚡ | Faible | Découverte réseau local |
| netdiscover | ⚡⚡⚡ | Faible | Découverte hôtes local |
| masscan | ⚡⚡⚡ | Faible | Scan de ports rapide |
| nmap quick | ⚡⚡ | Moyen | Reconnaissance initiale |
| nmap full | ⚡ | Élevé | Couverture ports complète |
| nmap services | ⚡ | Très élevé | Identification services |
| nmap vuln | ⚡ | Très élevé | Évaluation vulnérabilités |

---

## Avis légal

**Important :** Scannez uniquement les réseaux que vous possédez ou pour lesquels vous avez une autorisation écrite explicite.

- ❌ Le scan réseau non autorisé est illégal dans la plupart des juridictions
- ❌ Peut être considéré comme tentative d'intrusion
- ✅ Obtenez toujours une permission écrite avant de scanner
- ✅ Respectez les limites de débit et évitez les conditions DoS

Les auteurs et contributeurs de Balor/balorsh ne peuvent être tenus responsables de l'utilisation abusive de ces outils.

---

## Flux de travail courants

### Flux 1 : Découverte réseau local
1. [2] Détection rapide réseau local
2. [3] Scan ARP local pour détails
3. [6] Scan nmap rapide sur hôtes intéressants
4. [8] Scan services pour évaluation vulnérabilités

### Flux 2 : Évaluation cible externe
1. [6] Scan rapide pour trouver ports ouverts
2. [8] Détection services et versions
3. [10] Scan de vulnérabilités
4. [14] Capture tcpdump pour analyse trafic

### Flux 3 : Découverte applications web
1. [13] Masscan ports web
2. [8] Scan services sur hôtes découverts
3. [16] Wireshark pour analyse HTTP/HTTPS

---

**Version de la documentation :** 0.7  
**Dernière mise à jour :** Décembre 2025
