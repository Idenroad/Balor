# balorsh wifi - Référence des commandes WiFi Stack

[English version](balorsh_wifi.md)

Ce document décrit toutes les options de menu disponibles dans la stack WiFi de balorsh (v0.6).

## Table des matières

- [Contrôle Interface](#contrôle-interface)
- [Reconnaissance](#reconnaissance)
- [Attaques](#attaques)
- [Cracking](#cracking)

---

## Contrôle Interface

### [1] Lister interfaces WiFi

Affiche toutes les interfaces WiFi disponibles détectées sur le système.

**Ce que ça fait :**
- Utilise `iw dev` pour énumérer les interfaces WiFi
- Affiche les noms d'interfaces (ex: wlan0, wlan1)
- Indique si aucune interface n'est trouvée

**Cas d'usage :** Vérifier quelles cartes WiFi sont disponibles avant de commencer toute opération.

---

### [2] Sélectionner interface WiFi et activer monitor mode

Vous invite à sélectionner une interface WiFi et active le mode monitor dessus.

**Ce que ça fait :**
- Liste les interfaces WiFi disponibles
- Vous demande d'en choisir une (avec suggestion par défaut)
- Active le mode monitor avec `airmon-ng` ou `iw`/`iwconfig`
- Tue les processus conflictuels (NetworkManager, wpa_supplicant)
- Vérifie que le mode monitor est bien activé

**Cas d'usage :** Requis avant la plupart des attaques WiFi (capture de paquets, deauth, etc.).

**Note :** Cela désactivera temporairement votre connexion WiFi normale sur cette interface.

---

### [3] Désactiver monitor mode sur interface

Désactive le mode monitor et restore l'interface en mode managed.

**Ce que ça fait :**
- Demande la sélection d'interface
- Arrête le mode monitor avec `airmon-ng` ou `iw`/`iwconfig`
- Restore l'interface en mode managed
- Permet à nouveau la connectivité WiFi normale

**Cas d'usage :** Quand vous avez terminé les attaques et voulez restaurer le WiFi normal.

---

### [4] Saut de canaux

Boucle continuellement sur les canaux WiFi 1-11.

**Ce que ça fait :**
- Change l'interface sélectionnée sur les canaux 1 à 11
- Se met à jour toutes les ~0.3 secondes
- Affiche le canal actuel en temps réel
- Tourne jusqu'à ce que vous appuyiez sur Ctrl+C

**Cas d'usage :** Utile pour le monitoring passif ou pour capturer du trafic sur plusieurs canaux.

---

## Reconnaissance

### [5] Scan WiFi (airodump-ng)

Lance airodump-ng pour scanner les réseaux WiFi à proximité.

**Ce que ça fait :**
- Démarre airodump-ng sur l'interface sélectionnée (doit être en mode monitor)
- Affiche les points d'accès à proximité (BSSID, canal, chiffrement, ESSID)
- Montre les clients connectés
- Mise à jour en temps réel

**Cas d'usage :** Découvrir les réseaux WiFi disponibles, leurs canaux, types de chiffrement et clients connectés.

**Astuce :** Appuyez sur Ctrl+C pour arrêter le scan.

---

### [6] Attaque automatique (wifite)

Lance wifite pour des attaques WiFi automatisées.

**Ce que ça fait :**
- Scan automatique des réseaux WiFi
- Tente diverses attaques (WEP, capture handshake WPA, WPS)
- Utilise la wordlist rockyou.txt si disponible
- Sauvegarde les captures dans `/opt/balorsh/data/wifi_wifite/hs/`
- Tue automatiquement les processus conflictuels

**Cas d'usage :** Pentest WiFi entièrement automatisé - bon pour les débutants ou évaluations rapides.

---

### [7] Reconnaissance bettercap

Lance bettercap pour la reconnaissance WiFi.

**Ce que ça fait :**
- Démarre bettercap sur l'interface sélectionnée
- Active le module de reconnaissance WiFi
- Active le saut de canaux
- Affiche les réseaux et clients découverts
- Mise à jour automatique chaque seconde

**Cas d'usage :** Reconnaissance WiFi avancée avec capacités de scripting.

---

### [8] Scanner PMF (Protected Management Frames)

Scanne les réseaux WiFi pour détecter le support de PMF (802.11w).

**Ce que ça fait :**
- Scanne les réseaux WiFi à proximité
- Détecte si PMF est activé, requis ou désactivé
- Affiche les informations de sécurité des réseaux
- Sauvegarde les résultats dans `/opt/balorsh/data/wifi/pmf_scans/`

**Informations détectées :**
- ESSID (nom du réseau)
- BSSID (adresse MAC de l'AP)
- Canal
- Signal (puissance)
- Sécurité (WPA2/WPA3)
- État PMF (Capable, Required, Disabled)

**Cas d'usage :** 
- Identifier les réseaux avec PMF activé (protection contre les attaques deauth)
- Déterminer quels réseaux sont vulnérables aux attaques de déauthentification
- Auditer la sécurité des réseaux WiFi d'entreprise

**Note :** PMF (Protected Management Frames) est une fonctionnalité de sécurité qui protège contre les attaques de déauthentification. Les réseaux WPA3 requirent PMF obligatoirement.

---

## Attaques

### [9] Attaque deauth (aireplay-ng)

Effectue des attaques de déauthentification pour déconnecter les clients d'un point d'accès.

**Ce que ça fait :**
- Demande le BSSID cible (adresse MAC du point d'accès)
- Demande optionnellement la MAC du client (ou cible tous les clients)
- Demande le nombre de paquets deauth à envoyer
- Envoie des trames de déauthentification avec aireplay-ng

**Cas d'usage :**
- Déconnecter des clients d'un AP (DoS)
- Forcer les clients à se reconnecter (pour capturer des handshakes)

**Avertissement :** C'est une attaque par déni de service. À utiliser uniquement sur des réseaux autorisés.

---

### [10] Attaque WPS (reaver, bully, pixie dust)

Tente de cracker le PIN WPS pour récupérer le mot de passe WiFi.

**Ce que ça fait :**
- Demande le BSSID cible et le canal
- Propose trois méthodes d'attaque :
  1. **Reaver** - Brute force du PIN WPS
  2. **Bully** - Outil alternatif de cracking WPS
  3. **Pixie Dust** - Exploite les implémentations WPS faibles

**Cas d'usage :** Attaquer les routeurs WPS activé pour récupérer le mot de passe WiFi.

**Note :** WPS doit être activé sur l'AP cible. Pixie dust est le plus rapide mais ne fonctionne que sur les routeurs vulnérables.

---

### [11] Capture handshake

Capture les handshakes WPA/WPA2 4-way pour cracking offline.

**Ce que ça fait :**
- Demande le BSSID cible et le canal
- Démarre airodump-ng focalisé sur cet AP spécifique
- Capture le trafic jusqu'à obtention d'un handshake
- Sauvegarde les fichiers de capture dans `/opt/balorsh/data/wifi_captures/`
- Crée plusieurs formats de fichiers (.cap, .csv, fichiers .kismet)

**Cas d'usage :** Capturer des handshakes pour cracking offline ultérieur avec aircrack-ng ou hashcat.

**Astuce :** Vous devrez peut-être deauth les clients (option 8) pour forcer un handshake.

---

## Cracking

### [12] Crack avec aircrack-ng

Cracke les handshakes capturés avec aircrack-ng et une wordlist.

**Ce que ça fait :**
- Demande le fichier de capture (.cap)
- Propose une sélection interactive de wordlist (rockyou, personnalisée, etc.)
- Peut concaténer plusieurs wordlists
- Lance aircrack-ng avec la wordlist sélectionnée
- Affiche le mot de passe si trouvé

**Cas d'usage :** Cracker les handshakes WPA/WPA2 avec des attaques par dictionnaire.

---

### [13] Crack avec hashcat

Cracke les handshakes avec hashcat (accélération GPU).

**Ce que ça fait :**
- Demande le fichier de hash (format .hc22000)
- Propose une sélection interactive de wordlist
- Prépare et concatène les wordlists si nécessaire
- Lance hashcat en mode 22000 (WPA-PBKDF2-PMKID+EAPOL)
- Affiche le statut en temps réel toutes les 15 secondes

**Cas d'usage :** Cracking rapide par GPU des handshakes WiFi.

**Note :** Nécessite un GPU compatible et une installation hashcat correcte.

---

### [14] Convertir capture en hashcat

Convertit les fichiers .cap en format .hc22000 compatible hashcat.

**Ce que ça fait :**
- Demande le fichier source .cap ou .pcapng
- Utilise hcxpcapngtool pour convertir la capture
- Crée un fichier .hc22000 compatible avec hashcat
- Génère un fichier de métadonnées avec les informations de capture

**Cas d'usage :** Préparer les captures pour le cracking hashcat.

---

### [15] Auto-capture (handshake/PMKID)

Capture automatiquement les handshakes et PMKID avec hcxdumptool.

**Ce que ça fait :**
- Utilise hcxdumptool pour capture avancée (PMKID + EAPOL)
- Convertit automatiquement au format hashcat (.hc22000)
- Se replie sur airodump-ng si hcxdumptool n'est pas disponible
- Sauvegarde tous les fichiers dans `/opt/balorsh/data/wifi_captures/`
- Crée des fichiers de métadonnées pour le suivi

**Cas d'usage :** Méthode moderne et efficace pour capturer des hashes crackables depuis les réseaux WiFi.

**Avantage :** Peut capturer PMKID sans deauth (attaque sans client).

---

### [16] Capture PMKID (hcxdumptool)

Capture spécifiquement les PMKID des points d'accès.

**Ce que ça fait :**
- Utilise hcxdumptool pour capturer le PMKID
- Fonctionne sans clients connectés (attaque sans client)
- Convertit automatiquement au format hashcat
- Sauvegarde les fichiers de capture et de hash

**Cas d'usage :** Capturer des identifiants WiFi sans attendre que des clients se connectent.

**Note :** Tous les routeurs ne sont pas vulnérables aux attaques PMKID (surtout anciennes implémentations WPA2).

---

### [17] Gestion de session (démarrer/terminer)

Gère les sessions de capture pour une meilleure organisation.

**Ce que ça fait :**
- **Démarrer session :** Crée un répertoire horodaté pour organiser les captures
- **Terminer session :** Ferme la session actuelle et sauvegarde les métadonnées
- Aide à garder trace de plusieurs sessions de pentest

**Cas d'usage :** Organiser les captures de différentes missions de pentest.

---

### [18] Sélectionner cible (TUI)

Sélection interactive de cible avec fzf (fuzzy finder).

**Ce que ça fait :**
- Effectue un scan rapide de 6 secondes
- Affiche les résultats dans un menu interactif
- Montre BSSID, canal et ESSID
- Permet la sélection avec les flèches

**Cas d'usage :** Sélection de cible plus facile sans taper manuellement les adresses MAC.

**Prérequis :** Nécessite l'installation de `fzf`.

---

### [19] Bruteforce

Effectue des attaques bruteforce basées sur des masques avec hashcat.

**Ce que ça fait :**
- Demande le fichier de hash (.hc22000)
- Vous laisse choisir le jeu de caractères (minuscules, majuscules, chiffres, personnalisé)
- Demande la longueur min/max du mot de passe
- Peut exclure les mots de passe connus (comme rockyou.txt)
- Itère sur toutes les longueurs de mot de passe

**Cas d'usage :** Bruteforce de mots de passe courts quand les attaques par dictionnaire échouent.

**Avertissement :** Très chronophage. Pratique uniquement pour les mots de passe courts (8-10 caractères max).

---

### [20] Adresse MAC aléatoire

Change l'adresse MAC de l'interface sélectionnée.

**Ce que ça fait :**
- Génère une adresse MAC aléatoire
- Change la MAC de l'interface avec `macchanger`
- Utile pour l'anonymat

**Cas d'usage :** Contourner le filtrage MAC ou rester anonyme durant les attaques.

---

### [21] Nettoyer anciennes captures

Supprime les anciens fichiers de capture pour libérer de l'espace disque.

**Ce que ça fait :**
- Demande le seuil d'âge (en jours)
- Trouve et supprime les fichiers plus vieux que le nombre de jours spécifié
- Cible les répertoires `/opt/balorsh/data/wifi_*`
- Affiche le nombre de fichiers supprimés

**Cas d'usage :** Nettoyer l'espace disque après les sessions de pentest.

---

### [22] Saut de canaux adaptatif

Saut de canaux intelligent qui se concentre sur les canaux actifs.

**Ce que ça fait :**
- Effectue un scan rapide pour détecter les canaux actifs
- Saute uniquement sur les canaux avec des AP détectés
- Plus efficace que le saut de canaux simple

**Cas d'usage :** Meilleure reconnaissance sur les réseaux chargés.

---

### [23] Aide

Affiche des informations d'aide complètes sur la stack WiFi.

**Ce que ça fait :**
- Montre les descriptions d'outils
- Explique les flux de travail courants
- Liste les emplacements de fichiers
- Fournit des astuces d'utilisation

**Cas d'usage :** Référence rapide quand vous avez besoin d'aide.

---

### [24] Redémarrer NetworkManager

Redémarre le service NetworkManager.

**Ce que ça fait :**
- Redémarre le service systemd NetworkManager
- Utile quand le WiFi est bloqué après le mode monitor
- Restaure la fonctionnalité réseau normale

**Cas d'usage :** Corriger les problèmes de connectivité WiFi après le pentest.

---

### [0] Retour

Quitte le menu de la stack WiFi et retourne au menu principal balorsh.

---

## Emplacements des fichiers

Tous les fichiers de la stack WiFi sont stockés dans :

```
/opt/balorsh/data/
├── wifi_captures/       # Captures handshake
├── wifi_wifite/         # Résultats wifite
│   └── hs/             # Handshakes wifite
└── wifi_sessions/       # Captures par session
```

---

## Astuces

1. **Toujours utiliser une carte WiFi dédiée** - N'utilisez pas le WiFi principal de votre système pour les attaques
2. **Vérifier le mode monitor** - La plupart des attaques nécessitent le mode monitor (option 2)
3. **Utiliser l'option 22 pour l'aide** - Une aide complète est disponible dans le menu
4. **Redémarrer NetworkManager** - Utilisez l'option 23 si le WiFi est bloqué
5. **Commencer avec airodump-ng** - L'option 5 est idéale pour la reconnaissance
6. **Auto-capture recommandée** - L'option 14 est la méthode de capture la plus efficace

---

## Avis légal

Utilisez ces outils uniquement sur des réseaux que vous possédez ou pour lesquels vous avez une autorisation écrite explicite de tester.
L'accès non autorisé aux réseaux informatiques est illégal dans la plupart des juridictions.

---

**Version de la documentation :** 0.6  
**Dernière mise à jour :** Décembre 2025
