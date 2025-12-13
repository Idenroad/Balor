#!/usr/bin/env bash
# Script de vérification de sécurité pour Balor

set -e

echo "========================================"
echo "Vérification de sécurité - Balor"
echo "========================================"
echo ""

ERRORS=0
WARNINGS=0

# Fonction pour vérifier un fichier
check_file() {
  local file="$1"
  local should_be_exec="$2"
  
  if [[ ! -f "$file" ]]; then
    echo "❌ ERREUR: Fichier manquant: $file"
    ((ERRORS++))
    return 1
  fi
  
  if [[ "$should_be_exec" == "yes" ]]; then
    if [[ ! -x "$file" ]]; then
      echo "⚠️  WARNING: Fichier non exécutable: $file"
      ((WARNINGS++))
    else
      echo "✅ $file (exécutable)"
    fi
  else
    echo "✅ $file (présent)"
  fi
}

# Fonction pour vérifier un dossier
check_dir() {
  local dir="$1"
  
  if [[ ! -d "$dir" ]]; then
    echo "❌ ERREUR: Dossier manquant: $dir"
    ((ERRORS++))
    return 1
  fi
  
  echo "✅ $dir/ (présent)"
}

echo "=== Vérification des fichiers core ==="
check_file "balorsh" "yes"
check_file "install.sh" "yes"
check_file "VERSION" "no"
check_file "banner.txt" "no"

echo ""
echo "=== Vérification du système i18n ==="
check_file "lib/i18n.sh" "no"
check_file "lib/common.sh" "no"
check_dir "lib/lang"
check_file "lib/lang/fr.sh" "no"
check_file "lib/lang/en.sh" "no"

echo ""
echo "=== Vérification des stacks ==="
STACKS=(framework networkscan osint password remoteaccess webexploit wifi)

for stack in "${STACKS[@]}"; do
  echo "Stack: $stack"
  check_dir "stacks/$stack"
  check_file "stacks/$stack/install.sh" "yes"
  check_file "stacks/$stack/uninstall.sh" "yes"
  check_file "stacks/$stack/packages.txt" "no"
done

# Vérification spéciale pour wifi/commands.sh
echo ""
echo "=== Vérification spéciale WiFi ==="
check_file "stacks/wifi/commands.sh" "yes"

echo ""
echo "=== Vérification de la syntaxe bash ==="
echo "Vérification de balorsh..."
if bash -n balorsh; then
  echo "✅ balorsh: syntaxe correcte"
else
  echo "❌ ERREUR: balorsh a des erreurs de syntaxe"
  ((ERRORS++))
fi

echo ""
echo "=== Vérification des permissions dangereuses ==="
# Vérifier qu'aucun fichier n'a les permissions 777
DANGEROUS_PERMS=$(find . -type f -perm 0777 2>/dev/null | grep -v "\.git" || true)
if [[ -n "$DANGEROUS_PERMS" ]]; then
  echo "⚠️  WARNING: Fichiers avec permissions 777 (trop permissif):"
  echo "$DANGEROUS_PERMS"
  ((WARNINGS++))
else
  echo "✅ Aucun fichier avec permissions dangereuses (777)"
fi

echo ""
echo "=== Vérification des fichiers sources dans lib/ ==="
# Les fichiers .sh dans lib/ ne doivent PAS être exécutables (ils sont sourcés)
LIB_EXEC=$(find lib/ -name "*.sh" -type f -executable 2>/dev/null || true)
if [[ -n "$LIB_EXEC" ]]; then
  echo "⚠️  WARNING: Fichiers exécutables dans lib/ (doivent être sourcés, pas exécutés):"
  echo "$LIB_EXEC"
  ((WARNINGS++))
else
  echo "✅ Fichiers lib/ correctement non-exécutables"
fi

echo ""
echo "=== Résumé ==="
echo "Erreurs: $ERRORS"
echo "Warnings: $WARNINGS"

if [[ $ERRORS -gt 0 ]]; then
  echo ""
  echo "❌ Des erreurs critiques ont été détectées!"
  exit 1
elif [[ $WARNINGS -gt 0 ]]; then
  echo ""
  echo "⚠️  Des avertissements ont été détectés, veuillez les vérifier."
  exit 0
else
  echo ""
  echo "✅ Toutes les vérifications sont passées avec succès!"
  exit 0
fi
