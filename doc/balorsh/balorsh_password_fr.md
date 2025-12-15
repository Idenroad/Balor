# balorsh password - Référence des commandes du stack Password

[English version](balorsh_password.md)

Ce document décrit toutes les options de menu disponibles dans le stack Password Cracking de balorsh.

## Table des matières

- [Identification de hash](#identification-de-hash)
- [Hashcat (GPU)](#hashcat-gpu)
- [John the Ripper (CPU)](#john-the-ripper-cpu)
- [Génération de wordlists](#génération-de-wordlists)
- [Attaques réseau](#attaques-réseau)
- [Utilitaires](#utilitaires)

---

## Identification de hash

### [1] Identifier un type de hash (hashid)

Identifie le type de hash pour vous aider à choisir le bon mode de crack.

**Ce que ça fait :**
- Demande si vous voulez identifier un hash unique ou un fichier de hashes
- Utilise `hashid` pour analyser et identifier les types de hash
- Affiche tous les types possibles avec les modes hashcat et john
- Sauvegarde les résultats dans `/opt/balorsh/data/password/hashid/identify_*.txt`

**Cas d'usage :** Avant de cracker, identifier le type de hash (MD5, SHA1, bcrypt, etc.).

**Exemple de résultat :**
```
Analyse du hash : 5f4dcc3b5aa765d61d8327deb882cf99
Hashs possibles :
[+] MD5
[+] Domain Cached Credentials - MD4(MD4(($pass)).(strtolower($username)))
```

---

### [2] Lister les wordlists disponibles

Explorateur interactif pour parcourir les wordlists disponibles sur le système.

**Ce que ça fait :**
- Affiche les wordlists organisées par répertoire dans `/usr/share/wordlists`
- Affiche les tailles de fichiers et le nombre de lignes
- Permet la navigation dans les sous-répertoires
- Affiche des statistiques pour chaque répertoire

**Cas d'usage :** Explorer les wordlists disponibles avant de lancer une attaque.

**Fonctionnalités :**
- Navigation interactive dans les répertoires
- Affichage des tailles et nombre de lignes
- Retour au répertoire parent ou racine
- Trouve rapidement la bonne wordlist pour votre attaque

---

## Hashcat (GPU)

### [3] Hashcat : Attaque par dictionnaire

Crack de hash accéléré par GPU utilisant une wordlist.

**Ce que ça fait :**
- Demande un fichier de hashes à cracker
- Demande le mode hashcat (0=MD5, 1000=NTLM, 22000=WPA, etc.)
- Vous permet de sélectionner une wordlist (rockyou.txt, parcourir, ou personnalisé)
- Lance hashcat en mode dictionnaire
- Sauvegarde la session dans `/opt/balorsh/data/password/hashcat/session_*.txt`

**Cas d'usage :** Crack rapide de hash utilisant la puissance du GPU et une wordlist.

**Modes courants :**
- `0` - MD5
- `100` - SHA1
- `1000` - NTLM
- `1400` - SHA256
- `1800` - sha512crypt (Linux)
- `3200` - bcrypt
- `5600` - NetNTLMv2
- `22000` - WPA/WPA2 (PMKID/EAPOL)

**Astuce :** Pour la liste complète des modes, exécutez `hashcat --help | grep 'Hash modes'`

---

### [4] Hashcat : Attaque avec règles

Attaque par dictionnaire améliorée avec des règles de transformation.

**Ce que ça fait :**
- Demande le fichier de hashes et le mode
- Demande la wordlist
- Demande le fichier de règles (best64.rule, rockyou-30000.rule, dive.rule, ou personnalisé)
- Applique des transformations aux entrées de la wordlist (leetspeak, changements de casse, etc.)
- Augmente significativement le taux de réussite du crack

**Cas d'usage :** Quand l'attaque par dictionnaire échoue, les règles appliquent des variations à chaque mot.

**Règles populaires :**
- `best64.rule` - Équilibre optimal entre vitesse et efficacité
- `rockyou-30000.rule` - Règles plus complètes
- `dive.rule` - Ensemble de règles approfondies

**Exemple :** Le mot de passe "password" devient : Password, p@ssword, PASSWORD, passw0rd, etc.

---

### [5] Hashcat : Bruteforce (attaque par masque)

Bruteforce systématique utilisant des masques de caractères.

**Ce que ça fait :**
- Demande le fichier de hashes et le mode
- Demande un motif de masque
- Teste toutes les combinaisons possibles correspondant au masque
- Peut être très lent selon la complexité du masque

**Cas d'usage :** Quand vous connaissez la structure du mot de passe (ex: 8 caractères avec des motifs spécifiques).

**Syntaxe du masque :**
- `?l` = minuscules (a-z)
- `?u` = majuscules (A-Z)
- `?d` = chiffres (0-9)
- `?s` = caractères spéciaux (!@#$...)
- `?a` = tous les caractères

**Exemples :**
- `?l?l?l?l?l?l` = 6 lettres minuscules
- `?u?l?l?l?l?d?d` = Majuscule + 4 minuscules + 2 chiffres
- `?a?a?a?a?a?a?a?a` = 8 caractères quelconques (très lent !)

**Attention :** Le bruteforce peut prendre extrêmement longtemps. À utiliser uniquement quand la structure est connue.

---

### [6] Hashcat : Afficher les résultats

Affiche les mots de passe crackés lors des sessions hashcat précédentes.

**Ce que ça fait :**
- Demande le fichier de hashes et le mode
- Exécute `hashcat --show` pour afficher tous les mots de passe crackés
- Affiche les paires hash:motdepasse

**Cas d'usage :** Voir les résultats après la fin d'une session de crack.

---

## John the Ripper (CPU)

### [7] John : Crack auto/wordlist/incrémental

Modes de crack principaux de John the Ripper.

**Ce que ça fait :**
- Propose 3 modes d'attaque :
  1. **Automatique (single)** - Utilise le nom d'utilisateur pour générer des variations
  2. **Wordlist** - Attaque par dictionnaire avec une wordlist sélectionnée
  3. **Incrémental** - Attaque par bruteforce
- Sauvegarde la session dans `/opt/balorsh/data/password/john/session_*.txt`

**Cas d'usage :** Crack basé CPU quand aucun GPU n'est disponible, ou pour les formats que John gère mieux.

**Avantages de John :**
- Support de formats très versatile
- Excellent mode automatique
- Bon pour les types de hash complexes

---

### [8] John : Crack avec règles

Attaque par dictionnaire avec transformations de règles.

**Ce que ça fait :**
- Demande le fichier de hashes
- Demande la wordlist
- Demande les règles (best64, d3ad0ne, dive, jumbo)
- Applique des transformations aux entrées de la wordlist

**Cas d'usage :** Augmenter le taux de réussite avec des variations de mots de passe.

---

### [9] John : Afficher les résultats

Affiche les mots de passe crackés lors des sessions John.

**Ce que ça fait :**
- Demande le fichier de hashes
- Exécute `john --show` pour afficher les mots de passe crackés

**Cas d'usage :** Voir tous les mots de passe crackés par John.

---

## Génération de wordlists

### [10] Crunch : Générer une wordlist personnalisée

Créer des wordlists personnalisées basées sur des motifs spécifiques.

**Ce que ça fait :**
- Demande la longueur minimale et maximale des mots de passe
- Demande le jeu de caractères :
  - Minuscules (a-z)
  - Majuscules (A-Z)
  - Chiffres (0-9)
  - Minuscules + chiffres
  - Alphanumérique (a-zA-Z0-9)
  - Caractères personnalisés
- Estime la taille de sortie
- Génère la wordlist dans `/opt/balorsh/data/password/crunch/wordlist_*.txt`

**Cas d'usage :** Générer des wordlists ciblées quand vous connaissez les contraintes du mot de passe.

**Attention :** Les fichiers peuvent devenir TRÈS volumineux rapidement !

**Exemple :** 
- Longueur 6-8, chiffres uniquement : ~111 millions de combinaisons
- Longueur 8, alphanumérique : ~218 billions de combinaisons (pas faisable)

---

## Attaques réseau

### [11] Medusa : Attaque réseau

Bruteforce parallèle de services réseau.

**Ce que ça fait :**
- Demande la cible (IP ou nom d'hôte)
- Demande le service (ssh, ftp, http, mysql, postgres, rdp, smb, telnet, vnc, etc.)
- Demande le nom d'utilisateur ou un fichier d'utilisateurs
- Demande la wordlist
- Effectue des tentatives de connexion parallèles
- Sauvegarde les résultats dans `/opt/balorsh/data/password/medusa/attack_*.txt`

**Cas d'usage :** Tester les identifiants de connexion sur les services réseau.

**Services supportés :**
- SSH, FTP, HTTP, MySQL, PostgreSQL, RDP, SMB, Telnet, VNC, et plus

**Attention :** 
- Peut verrouiller les comptes après des tentatives échouées
- À utiliser uniquement sur des systèmes autorisés
- Illégal sans autorisation appropriée

---

### [12] Ncrack : Audit de services réseau

Cracker d'authentification réseau avec timing intelligent.

**Ce que ça fait :**
- Demande la cible (ex: `ssh://192.168.1.1` ou `rdp://192.168.1.10`)
- Propose deux modes :
  1. Nom d'utilisateur + wordlist de mots de passe
  2. Fichier d'identifiants (format login:motdepasse)
- Effectue un timing intelligent pour éviter la détection
- Sauvegarde les résultats dans `/opt/balorsh/data/password/ncrack/attack_*.txt`

**Cas d'usage :** Auditer la sécurité de l'authentification des services réseau.

**Avantages :**
- Timing plus intelligent que medusa
- Bon pour l'évasion
- Gère plusieurs protocoles

---

## Utilitaires

### [13] Nettoyer les anciens fichiers

Supprimer les anciens fichiers de sessions de crack.

**Ce que ça fait :**
- Demande l'âge de rétention des fichiers en jours (par défaut : 30)
- Recherche les anciens fichiers dans :
  - `/opt/balorsh/data/password/hashid/`
  - `/opt/balorsh/data/password/hashcat/`
  - `/opt/balorsh/data/password/john/`
  - `/opt/balorsh/data/password/crunch/`
  - `/opt/balorsh/data/password/medusa/`
  - `/opt/balorsh/data/password/ncrack/`
- Affiche les fichiers à supprimer
- Demande confirmation avant suppression

**Cas d'usage :** Libérer de l'espace disque des anciens fichiers de session.

---

### [14] Aide

Affiche l'aide de référence rapide pour le stack password.

**Ce que ça fait :**
- Affiche un résumé des outils disponibles
- Présente le workflow typique
- Liste les types de hash courants
- Fournit des conseils de performance
- Affiche des exemples d'utilisation
- Présente les avertissements légaux

**Cas d'usage :** Guide de référence rapide pour le crack de mots de passe.

---

## Workflow typique

1. **Identifier le hash**
   - Utiliser l'option [1] pour identifier le type de hash
   - Noter le numéro de mode hashcat ou john

2. **Choisir votre outil**
   - Hashcat (GPU) - Le plus rapide pour les formats supportés
   - John (CPU) - Meilleur pour les formats complexes

3. **Sélectionner la méthode d'attaque**
   - Commencer par dictionnaire (rockyou.txt)
   - Ajouter des règles si le dictionnaire échoue
   - Bruteforce en dernier recours

4. **Voir les résultats**
   - Utiliser l'option "Afficher les résultats"
   - Vérifier les fichiers de session sauvegardés

## Notes importantes

**Performance :**
- Hashcat + GPU >> John (CPU) en vitesse
- MD5 : ~10 milliards hash/sec (GPU moderne)
- bcrypt : ~100k hash/sec (conçu pour être lent)

**Wordlists :**
- Emplacement : `/usr/share/wordlists/`
- Principale : `rockyou.txt` (14M mots de passe, couvre ~80% des cas)
- Collection : SecLists (listes de mots de passe complètes)

**Avertissement légal :**
Le crack de mots de passe doit être effectué uniquement :
- Sur vos propres systèmes
- Dans un contexte légal (test de pénétration autorisé)
- Pour récupérer vos propres données

L'accès non autorisé est illégal. Utilisez de manière responsable.
