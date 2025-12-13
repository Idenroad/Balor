#!/usr/bin/env bash
# Script de vérification de sécurité pour Balor

set -e

# Charger i18n si disponible
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
I18N_FILE="${I18N_FILE:-$SCRIPT_DIR/lib/i18n.sh}"
[[ -f "$I18N_FILE" ]] && source "$I18N_FILE"

echo "${SECURITY_SEPARATOR}"
echo "${SECURITY_TITLE}"
echo "${SECURITY_SEPARATOR}"
echo ""

ERRORS=0
WARNINGS=0

# Fonction pour vérifier un fichier
check_file() {
  local file="$1"
  local should_be_exec="$2"
  
  if [[ ! -f "$file" ]]; then
    echo "${SECURITY_ERROR}: ${SECURITY_FILE_MISSING}: $file"
    ((ERRORS++))
    return 1
  fi
  
  if [[ "$should_be_exec" == "yes" ]]; then
    if [[ ! -x "$file" ]]; then
      echo "${SECURITY_WARNING}: ${SECURITY_NOT_EXECUTABLE}: $file"
      ((WARNINGS++))
    else
      echo "${SECURITY_OK} $file (${SECURITY_EXECUTABLE})"
    fi
  else
    echo "${SECURITY_OK} $file (${SECURITY_PRESENT})"
  fi
}

# Fonction pour vérifier un dossier
check_dir() {
  local dir="$1"
  
  if [[ ! -d "$dir" ]]; then
    echo "${SECURITY_ERROR}: ${SECURITY_DIR_MISSING}: $dir"
    ((ERRORS++))
    return 1
  fi
  
  echo "${SECURITY_OK} $dir/ (${SECURITY_PRESENT})"
}

echo "${SECURITY_CHECK_CORE}"
check_file "balorsh" "yes"
check_file "install.sh" "yes"
check_file "VERSION" "no"
check_file "banner.txt" "no"

echo ""
echo "${SECURITY_CHECK_I18N}"
check_file "lib/i18n.sh" "no"
check_file "lib/common.sh" "no"
check_dir "lib/lang"
check_file "lib/lang/fr.sh" "no"
check_file "lib/lang/en.sh" "no"

echo ""
echo "${SECURITY_CHECK_STACKS}"
STACKS=(framework networkscan osint password remoteaccess webexploit wifi)

for stack in "${STACKS[@]}"; do
  echo "${SECURITY_STACK}: $stack"
  check_dir "stacks/$stack"
  check_file "stacks/$stack/install.sh" "yes"
  check_file "stacks/$stack/uninstall.sh" "yes"
  check_file "stacks/$stack/packages.txt" "no"
done

# Vérification spéciale pour wifi/commands.sh
echo ""
echo "${SECURITY_CHECK_WIFI}"
check_file "stacks/wifi/commands.sh" "yes"

echo ""
echo "${SECURITY_CHECK_SYNTAX}"
echo "${SECURITY_CHECKING} balorsh..."
if bash -n balorsh; then
  echo "${SECURITY_OK} balorsh: ${SECURITY_SYNTAX_OK}"
else
  echo "${SECURITY_ERROR}: balorsh ${SECURITY_SYNTAX_ERROR}"
  ((ERRORS++))
fi

echo ""
echo "${SECURITY_CHECK_PERMS}"
# Vérifier qu'aucun fichier n'a les permissions 777
DANGEROUS_PERMS=$(find . -type f -perm 0777 2>/dev/null | grep -v "\.git" || true)
if [[ -n "$DANGEROUS_PERMS" ]]; then
  echo "${SECURITY_WARNING}: ${SECURITY_PERMS_777}"
  echo "$DANGEROUS_PERMS"
  ((WARNINGS++))
else
  echo "${SECURITY_OK} ${SECURITY_NO_DANGEROUS}"
fi

echo ""
echo "${SECURITY_CHECK_LIB}"
# Les fichiers .sh dans lib/ ne doivent PAS être exécutables (ils sont sourcés)
LIB_EXEC=$(find lib/ -name "*.sh" -type f -executable 2>/dev/null || true)
if [[ -n "$LIB_EXEC" ]]; then
  echo "${SECURITY_WARNING}: ${SECURITY_LIB_EXEC}"
  echo "$LIB_EXEC"
  ((WARNINGS++))
else
  echo "${SECURITY_OK} ${SECURITY_LIB_OK}"
fi

echo ""
echo "${SECURITY_SUMMARY}"
echo "${SECURITY_ERRORS}: $ERRORS"
echo "${SECURITY_WARNINGS}: $WARNINGS"

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "${SECURITY_ERROR} ${SECURITY_CRITICAL_ERRORS}"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo ""
  echo "${SECURITY_WARNING} ${SECURITY_WARNINGS_FOUND}"
  exit 0
else
  echo ""
  echo "${SECURITY_OK} ${SECURITY_ALL_PASSED}"
  exit 0
fi
