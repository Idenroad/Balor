## BalorSH — OSINT (Documentation complète)

Ce document décrit en détail la stack `osint` : le menu principal, les sous-menus et le rôle de chaque option. Il vise à être exhaustif afin que l'utilisateur comprenne précisément le comportement de chaque entrée du menu.

Chemins importants

- Dossier de données: `/opt/balorsh/data/osint/`
- Config utilisateur: `$HOME/.config/balorsh/osint/`

Menu principal — options et comportements

Le menu principal affiche les sections suivantes : configuration, outils, domaines, autres, URLs et aides.

Configuration

1) Configurer `theHarvester`
	- Ouvre un assistant pour renseigner les sources et clefs API pour `theHarvester`.
	- Permet d'ajuster les sources activées via la variable interne `harvester_available_sources`.

2) Configurer `Censys`
	- Permet d'indiquer la configuration de `censys` (fichier `~/.config/censys/censys.cfg`) ou d'initialiser les paramètres.

3) Configurer `Shodan`
	- Permet d'ajouter ou modifier la clé API Shodan et les réglages de recherche.

Outils

4) `Maltego`
	- Lance la pré-configuration et ouvre les aides pour intégrer Maltego avec Java 17 si nécessaire.

5) `SpiderFoot`
	- Lance le sous-menu SpiderFoot qui propose plusieurs presets (scans ciblés, modules par défaut, scan complet, modules personnalisés).
	- Les scans sont lancés en mode JSON, journalisés et indexés dans `/opt/balorsh/data/osint/spiderfoot/`.

Domaines / Recherches ciblées

6) Recherche Censys (search)
	- Interroge Censys pour un domaine/host et stocke le résultat JSON dans le dossier `censys`.

7) Certificats Censys (certs)
	- Recherche des certificats TLS/SSL liés au domaine via Censys.

8) Recherches multiples (theHarvester)
	- Lance `theHarvester` avec un ensemble de sources configurables. Option pour DNS resolve ou reverse lookup avant exécution.

9) Enumération de sous-domaines (Amass)
	- Ouvre le sous-menu Amass (passif/actif). Le menu propose presets, inclusion TLD, export de résultats et stockage dans `/opt/balorsh/data/osint/`.

11) Recherche Shodan
	- Recherche Shodan par IP/hôte et affiche/récupère les informations.

Autres

12) Ports Shodan
	- Recherche de ports exposés via Shodan pour un IP donné.

13) Résolution massDNS
	- Lance `massdns` pour résoudre une liste de noms et stocke les résultats.

14) Outils Git / secrets (gittools)
	- Interface vers `gittools` et autres utilitaires d'analyse de dépôts pour trouver des secrets ou fuites.

15) Manipulation JSON (JQ)
	- Sous-menu pour filtrer, formater et extraire des champs JSON via `jq`. Propose des presets de filtre et export.

URLs et historiques

16) Collecte d'historiques multiples (gau, wayback)
	- Lance `gau`/`waybackurls` pour collecter URLs associées à un domaine et les stocke dans `/opt/balorsh/data/osint/urls/`.

17) Historique Wayback Machine (WaybackURLs)
	- Outils pour parcourir et filtrer les résultats Wayback.

18) Vérification HTTP (httprobe)
	- Passe en revue une liste d'URLs et vérifie leur accessibilité (http/https) en parallèle.

Aide et diagnostics

19) Diagnostic du module OSINT
	- Affiche diagnostics et conseils (vérification des dépendances, chemins, versions).

20) Aide détaillée
	- Affiche le guide d'utilisation et les chemins vers les logs et configurations.

21) Jobs en arrière-plan
	- Affiche et permet contrôler les tâches lancées par les sous-menus (tail, kill, nettoyage).

22) Index SpiderFoot
	- Affiche l'index JSONL des scans SpiderFoot exécutés.

Notes détaillées sur quelques actions clés

- SpiderFoot: les presets 1..7 définissent des modules prédéfinis; le preset 7 lance un scan complet (`-u all`). Les sorties sont indexées via `append_index()`.
- Amass: propose modes passif/actif, option d'inclusion TLD et export standardisé.
- theHarvester: propose un mode "noapi" (exécution directe) et un menu pour choisir DNS resolve ou reverse lookup avant exécution.
- Jobs: les tâches de longue durée (ex: SpiderFoot) sont lancées en arrière-plan et enregistrées dans `JOB_DIR` pour suivi.

Bonnes pratiques

- Toujours vérifier les clés API et quotas (Censys, Shodan) avant d'exécuter des scans lourds.
- Respecter la législation et obtenir les autorisations nécessaires.
- Nettoyer les logs sensibles avant partage.

Voir aussi

- `stacks/osint/commands.sh` pour le comportement exact et les i18n keys
- `lib/common.sh` pour l'emplacement des dossiers et helpers

