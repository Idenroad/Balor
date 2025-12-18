#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/balorsh/data/password/mywordlist"
OUTPUT_DIR="$BASE_DIR/passwords_output"
mkdir -p "$BASE_DIR" "$OUTPUT_DIR"

cleanup() {
  echo
  echo "Nettoyage des fichiers temporaires..."
  rm -rf "$TMP_DIR"
  echo "Terminé."
}

trap cleanup EXIT INT TERM

download_and_extract() {
  local url="$1"
  local filename=$(basename "$url")
  local filepath="$BASE_DIR/$filename"

  if [[ ! -f "$filepath" ]]; then
    echo "Téléchargement de $filename..."
    wget -c "$url" -O "$filepath"
  else
    echo "$filename déjà présent, saut du téléchargement."
  fi

  # Décompression selon extension
  case "$filename" in
    *.7z)
      echo "Décompression de $filename..."
      7z x -o"$BASE_DIR" "$filepath"
      ;;
    *.txt)
      echo "Fichier texte, pas de décompression nécessaire."
      ;;
    *)
      echo "Extension inconnue, pas de décompression automatique."
      ;;
  esac
}

# === MENU DE CHOIX ===

echo "Choisissez la source de la liste de mots de passe :"
echo "1) Fournir un fichier local (chemin complet)"
echo "2) Télécharger weakpass_4.txt.7z (22.46 Go décompressé)"
echo "3) Télécharger weakpass_4a.txt (81.37 Go décompressé)"
echo "4) Télécharger weakpass_4a.latin.txt (79.4 Go)"
echo "5) Télécharger weakpass_4.merged.txt (37.72 Go)"
echo "6) Télécharger weakpass_4.latin.txt (22.03 Go)"
read -rp "Votre choix (1-6) : " choice

case "$choice" in
  1)
    echo "Entrez le chemin complet vers votre fichier :"
    read -r input_file
    if [[ ! -f "$input_file" ]]; then
      echo "Fichier introuvable : $input_file"
      exit 1
    fi
    ;;
  2)
    download_and_extract "https://weakpass.com/download/2012/weakpass_4.txt.7z"
    input_file="$BASE_DIR/weakpass_4.txt"
    ;;
  3)
    download_and_extract "https://weakpass.com/wordlists/weakpass_4a.txt"
    input_file="$BASE_DIR/weakpass_4a.txt"
    ;;
  4)
    download_and_extract "https://weakpass.com/wordlists/weakpass_4a.latin.txt"
    input_file="$BASE_DIR/weakpass_4a.latin.txt"
    ;;
  5)
    download_and_extract "https://weakpass.com/wordlists/weakpass_4.merged.txt"
    input_file="$BASE_DIR/weakpass_4.merged.txt"
    ;;
  6)
    download_and_extract "https://weakpass.com/wordlists/weakpass_4.latin.txt"
    input_file="$BASE_DIR/weakpass_4.latin.txt"
    ;;
  *)
    echo "Choix invalide."
    exit 1
    ;;
esac

# === DÉTECTION DES RESSOURCES ===

CPU_CORES=$(nproc --all)
RAM_AVAILABLE=$(free -m | awk '/^Mem:/ {print $7}')

echo "CPU cores détectés : $CPU_CORES"
echo "RAM disponible (Mo) : $RAM_AVAILABLE"

while true; do
  echo "Entrez le pourcentage de ressources à utiliser (entre 10 et 80) :"
  read -r PERCENT
  if [[ "$PERCENT" =~ ^[0-9]+$ ]] && (( PERCENT >= 10 && PERCENT <= 80 )); then
    break
  else
    echo "Valeur invalide. Veuillez entrer un nombre entre 10 et 80."
  fi
done

MAX_JOBS=$(( CPU_CORES * PERCENT / 100 ))
if (( MAX_JOBS < 1 )); then MAX_JOBS=1; fi

RAM_FOR_CHUNKS=$(( RAM_AVAILABLE * PERCENT / 100 ))
CHUNK_LINES=$(( RAM_FOR_CHUNKS * 1000000 / 100 ))

if (( CHUNK_LINES < 500000 )); then CHUNK_LINES=500000; fi
if (( CHUNK_LINES > 5000000 )); then CHUNK_LINES=5000000; fi

echo "Utilisation CPU : $MAX_JOBS jobs parallèles"
echo "Utilisation RAM : $RAM_FOR_CHUNKS Mo"
echo "Taille des chunks : $CHUNK_LINES lignes par morceau"

# === PRÉPARATION ===

TMP_DIR=$(mktemp -d)
mkdir -p "$OUTPUT_DIR"

echo "Découpage du fichier en morceaux de $CHUNK_LINES lignes..."
split -l "$CHUNK_LINES" --numeric-suffixes=1 --suffix-length=4 "$input_file" "$TMP_DIR/part_"

PARTS=("$TMP_DIR"/part_*)
TOTAL_PARTS=${#PARTS[@]}
echo "$TOTAL_PARTS morceaux créés."

# === TRAITEMENT PARALLÈLE ===

process_part() {
  local part="$1"
  local index="$2"
  local total="$3"

  echo "[$index/$total] Traitement de $(basename "$part")..."

  awk -v tmpdir="$TMP_DIR" '
    length($0) >= 1 && length($0) <= 30 {
      len = length($0)
      print > (tmpdir "/temp_" len "_" "'$(basename "$part")'")
    }
  ' "$part"
}

export -f process_part
export TMP_DIR

echo "Traitement parallèle avec $MAX_JOBS jobs..."
i=0
for part in "${PARTS[@]}"; do
  ((i++))
  process_part "$part" "$i" "$TOTAL_PARTS" &
  while (( $(jobs -r | wc -l) >= MAX_JOBS )); do
    sleep 0.1
  done
done

wait

echo "Fusion des fichiers temporaires..."

for len in {1..30}; do
  outfile="$OUTPUT_DIR/passwords-$len.txt"
  tempfile_pattern="$TMP_DIR/temp_${len}_part_*"
  if compgen -G "$tempfile_pattern" > /dev/null; then
    cat $tempfile_pattern > "$outfile"
    echo "  → $outfile créé."
  else
    echo "  → Aucun mot de passe de $len caractères trouvé."
  fi
done

echo "✅ Traitement terminé. Fichiers créés dans '$OUTPUT_DIR'."

# === PROPOSITION DE SUPPRESSION ===

echo
echo "Voulez-vous supprimer les fichiers compressés téléchargés ? (y/n)"
read -r del_compressed
if [[ "$del_compressed" =~ ^[Yy]$ ]]; then
  case "$choice" in
    2) rm -f "$BASE_DIR/weakpass_4.txt.7z" ;;
    3) rm -f "$BASE_DIR/weakpass_4a.txt" ;;
    4) rm -f "$BASE_DIR/weakpass_4a.latin.txt" ;;
    5) rm -f "$BASE_DIR/weakpass_4.merged.txt" ;;
    6) rm -f "$BASE_DIR/weakpass_4.latin.txt" ;;
  esac
  echo "Fichiers compressés supprimés."
fi

echo "Voulez-vous supprimer la liste complète décompressée ? (y/n)"
read -r del_decompressed
if [[ "$del_decompressed" =~ ^[Yy]$ ]]; then
  case "$choice" in
    2) rm -f "$BASE_DIR/weakpass_4.txt" ;;
    # Les autres sont déjà des fichiers txt non compressés
    3) rm -f "$BASE_DIR/weakpass_4a.txt" ;;
    4) rm -f "$BASE_DIR/weakpass_4a.latin.txt" ;;
    5) rm -f "$BASE_DIR/weakpass_4.merged.txt" ;;
    6) rm -f "$BASE_DIR/weakpass_4.latin.txt" ;;
  esac
  echo "Fichiers décompressés supprimés."
fi