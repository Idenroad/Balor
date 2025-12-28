
## BalorSH — Framework (Documentation claire et pratique)

Cette page décrit le cœur `framework` de Balor, en se concentrant sur ce qu'un utilisateur ou contributeur a réellement besoin de savoir : les fonctionnalités du menu, le flux de travail typique, les chemins importants, et un guide pour étendre ou déboguer la stack.

Objectifs du document

- Décrire précisément les options du menu `framework` et leur comportement.
- Expliquer où sont stockées les sorties, logs et configurations.
- Donner des instructions pratiques pour contribuer et tester de nouvelles fonctionnalités.

Emplacements clés

- Données de la stack : `/opt/balorsh/data/framework/`
- Variables d'environnement utiles : `FRAMEWORK_LHOST`, `FRAMEWORK_LPORT`, `FRAMEWORK_TARGET`
- Dossier de logs : créer automatiquement sous `$FRAMEWORK_DATA_DIR` par outil (ex. `metasploit/`, `burpsuite/`).

Résumé du menu principal

Le menu `framework` est divisé en sections : Burp Suite, Metasploit, ExploitDB, Workflows, CVE/Aide.

Section Burp Suite

- **1) Lancer Burp Suite** — démarre l'application (non gérée par systemd) et affiche une confirmation.
- **2) Configurer le proxy Burp** — active/désactive `http_proxy`/`https_proxy` vers `127.0.0.1:8080` pour rediriger le trafic local vers Burp.
- **3) Exporter le certificat CA Burp** — crée un fichier `burp_ca_cert.der` dans le répertoire data pour import dans navigateurs.

Section Metasploit

- **4) Ouvrir `msfconsole`** — lance la console Metasploit en mode interactif.
- **5) Initialiser la base Metasploit** — exécute `msfdb init --use-defaults` avec un timeout pour éviter blocages.
- **6) Mettre à jour Metasploit** — utilise `paru -S metasploit-git` (timeout appliqué).
- **7) Démarrer un handler** — demande LHOST/LPORT et choix de payload, puis lance un handler via `msfconsole` (timeout configurable).
- **8) Générer payload (msfvenom)** — propose différents formats (exe, elf, php, python, apk) et fournit la commande handler.
- **9) Lancer des scans Metasploit** — choix de modules scanner (http/ssh/ftp/smb/mysql/arp) et stockage du log.
- **10) Génération avancée** — encodage (shikata, xor) et options d'encodage via `msfvenom`.

Section ExploitDB

- **11) Mise à jour ExploitDB** — synchronise la base d'exploits locale.
- **12) Recherche ExploitDB** — recherche par mot-clé/CVE dans la base locale.
- **13) Copier un exploit** — export d'un exploit vers un espace de travail.
- **14) Recherche avancée** — filtres et options pour trouver un exploit précis.
- **15) Compiler un C exploit** — compilation locale avec `gcc` si nécessaire.

Workflows et utilitaires

- **16) Workflow payload+handler** — enchaîne génération de payload et lancement d'un handler prêt à l'emploi.
- **17) Workflow scan→exploit** — exécute un scan puis propose des exploits potentiels.
- **18) Afficher IP** — affiche IP utile (publique/locale) pour les workflows.

CVE et aide

- **19) Recherche CVE (balorcve)** — lance `balorcve` si présent ; sinon affiche la commande d'installation (pipx) et où la trouver.
- **20) Aide détaillée** — affiche la page d'aide complète et exemples d'utilisation.

0) Retour au menu principal

Comportement commun des actions

- Avant d'exécuter une commande potentiellement destructive, le script affiche la ligne de commande proposée et demande confirmation.
- Les sorties brutes sont écrites dans des `.log` et nettoyées en `.txt` (suppression des caractères non imprimables). Les chemins sont standardisés sous `$FRAMEWORK_DATA_DIR`.
- Certaines opérations lourdes (`msfdb init`, `paru`) sont exécutées avec `timeout` pour éviter que l'installateur ne se bloque indéfiniment.

Exemples de fichiers et structure

```
/opt/balorsh/data/framework/
├── metasploit/
│   └── scan_... .log
├── burpsuite/
│   └── burp_ca_cert.der
└── balorcve/
	 └── balorcve_YYYYMMDD_HHMMSS.log
```

Bonnes pratiques pour les contributeurs

1. Écrire des fonctions claires nommées `framework_<action>()` pour chaque action.
2. Ajouter l'entrée correspondante dans le `case` du `stack_menu()` (regarder `stacks/framework/commands.sh`).
3. Utiliser les helpers de `lib/common.sh` (gestion des dossiers, i18n, `run_direct`, `run_bg_stream`).
4. Rendre les scripts idempotents et vérifier le comportement avec `NO_MAIN_MENU=1` pour tests non-interactifs.

Debugging et validation

- Pour reproduire un bug ou tester une action :

```bash
NO_MAIN_MENU=1 bash -c 'source stacks/framework/commands.sh; framework_msf_payload_reverse'
```

- Vérifier les logs sous `/opt/balorsh/data/framework/` et les fichiers job dans `$JOB_DIR` si l'action lance des processus de fond.

Internationalisation (i18n)

- Les textes affichés par le menu utilisent les clés i18n définies dans `lib/lang/fr.sh` et `lib/lang/en.sh`. Ajoutez de nouvelles clés lorsque vous ajoutez des messages.

Sécurité et éthique

- N'exécuter les workflows offensifs que sur des cibles autorisées.
- Protéger les logs et les peudo-exploits générés; ne les partagez pas sans nettoyage.

Voir aussi

- `stacks/framework/commands.sh` (implémentation complète)
- `lib/common.sh` (helpers, i18n, Modelfile helpers)

