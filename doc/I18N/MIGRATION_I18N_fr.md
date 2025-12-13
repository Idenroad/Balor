#!/usr/bin/env bash

# Guide de migration rapide pour adapter vos scripts à i18n

cat << 'EOF'
╔══════════════════════════════════════════════════════════════════╗
║       Guide de Migration i18n - Balor Multilingue               ║
╚══════════════════════════════════════════════════════════════════╝

## 📋 Checklist de migration

Pour chaque fichier .sh à adapter :

1. ✅ Charger i18n via common.sh
   
   Ajoutez en haut du fichier :
   ```bash
   SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
   source "$SCRIPT_DIR/../../lib/common.sh"
   ```

2. ✅ Identifier tous les messages utilisateur

   Cherchez tous les :
   - echo "message en français"
   - echo -e "message avec couleurs"
   - Messages d'erreur, d'info, de succès

3. ✅ Créer les variables dans fr.sh et en.sh

   Exemple :
   lib/lang/fr.sh :
   ```bash
   INSTALL_WELCOME="Installation du stack %s..."
   ```
   
   lib/lang/en.sh :
   ```bash
   INSTALL_WELCOME="Installing %s stack..."
   ```

4. ✅ Remplacer les messages dans le code

   Avant :
   ```bash
   echo "Installation du stack wifi..."
   ```
   
   Après :
   ```bash
   printf "$INSTALL_WELCOME\n" "wifi"
   ```

## 🔍 Patterns de remplacement courants

### Pattern 1: Message simple

Avant:
  echo "Aucune interface WiFi détectée."

Après:
  echo "$WIFI_NO_IFACE_DETECTED"


### Pattern 2: Message avec variable

Avant:
  echo "Mode monitor activé sur $iface."

Après:
  printf "$WIFI_MONITOR_ENABLED\n" "$iface"

Variable dans fr.sh:
  WIFI_MONITOR_ENABLED="Mode monitor activé sur %s."

Variable dans en.sh:
  WIFI_MONITOR_ENABLED="Monitor mode enabled on %s."


### Pattern 3: Message avec couleurs

Avant:
  echo -e "${C_RED}Choix invalide.${C_RESET}"

Après:
  echo -e "${C_RED}${WIFI_INVALID_CHOICE}${C_RESET}"


### Pattern 4: Message avec plusieurs variables

Avant:
  echo "Cible: BSSID=$bssid, Canal=$channel"

Après:
  printf "$WIFI_TARGET_SELECTED\n" "$bssid" "$channel"

Variable dans fr.sh:
  WIFI_TARGET_SELECTED="Cible sélectionnée: BSSID=%s, Canal=%s"


## 📝 Conventions de nommage

Préfixes recommandés :
- MSG_*        : Messages généraux (common.sh)
- WIFI_*       : Messages WiFi stack
- INSTALL_*    : Messages d'installation
- ERROR_*      : Messages d'erreur
- SUCCESS_*    : Messages de succès

Exemples :
- MSG_PARU_DETECTED
- WIFI_MENU_TITLE
- INSTALL_WELCOME
- ERROR_NO_PERMISSION
- SUCCESS_OPERATION_COMPLETE


## 🧪 Tester votre migration

1. Tester en français :
   ```bash
   BALOR_LANG=fr ./votre_script.sh
   ```

2. Tester en anglais :
   ```bash
   BALOR_LANG=en ./votre_script.sh
   ```

3. Tester avec détection auto :
   ```bash
   ./votre_script.sh
   ```


## ⚠️ Pièges à éviter

1. ❌ Ne pas oublier \n avec printf
   printf "$MESSAGE"        # Mauvais
   printf "$MESSAGE\n"      # Bon

2. ❌ Ne pas mélanger echo et printf pour les messages formatés
   echo "$MESSAGE" "$var"   # Mauvais
   printf "$MESSAGE\n" "$var"  # Bon

3. ❌ Ne pas oublier les guillemets autour des variables
   printf $MESSAGE\n        # Mauvais
   printf "$MESSAGE\n"      # Bon

4. ❌ Vérifier l'ordre des paramètres
   printf "$MSG\n" "$var2" "$var1"    # Mauvais ordre
   printf "$MSG\n" "$var1" "$var2"    # Bon ordre


## 📚 Ressources

- Documentation complète : I18N.md
- Fichiers de traduction : lib/lang/fr.sh, lib/lang/en.sh
- Script de test : test_i18n.sh
- Exemples : lib/common.sh, stacks/wifi/commands.sh

EOF
