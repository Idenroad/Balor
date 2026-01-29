#!/usr/bin/env bash
set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../../lib/common.sh
source "$SCRIPT_DIR/../../lib/common.sh"

printf "$UNINSTALL_STACK_START\n" "ADDON: phishing"

BALOR_ROOT_OPT="${BALOR_OPT_ROOT:-/opt/balorsh}"

PKGS_RAW=$(read_stack_packages "$SCRIPT_DIR")
PAC_PKGS="${PKGS_RAW%%|*}"
AUR_PKGS="${PKGS_RAW#*|}"

for p in $PAC_PKGS; do
  remove_pkg "$p"
done

for a in $AUR_PKGS; do
  remove_pkg "$a"
done

sudo rm -rf "$BALOR_ROOT_OPT/addons/apps/gophish" "$BALOR_ROOT_OPT/addons/apps/phishing/zphisher" || true

remove_stack_data_dir "phishing"

echo "${PHISHING_ADDON_UNINSTALLED}"
