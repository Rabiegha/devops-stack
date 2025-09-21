#!/usr/bin/env bash
set -euo pipefail

# Script de restauration pour le workflow DevOps
# Usage: ./restore.sh [TARGET_DIR] [INCLUDE_PATTERN] [SNAPSHOT_ID]

# Configuration par défaut
TARGET_DIR="${1:-/restore}"
INCLUDE_PATTERN="${2:-/backup/jenkins}"
SNAPSHOT_ID="${3:-latest}"

echo "[restore] $(date '+%Y-%m-%d %H:%M:%S') - Début de la restauration..."

# Vérification des variables requises
if [[ -z "${RESTIC_REPOSITORY:-}" ]]; then
    echo "ERREUR: RESTIC_REPOSITORY non défini"
    exit 1
fi

if [[ -z "${RESTIC_PASSWORD_FILE:-}" ]] || [[ ! -f "${RESTIC_PASSWORD_FILE}" ]]; then
    echo "ERREUR: RESTIC_PASSWORD_FILE non défini ou fichier inexistant"
    exit 1
fi

# Création du répertoire de destination
mkdir -p "$TARGET_DIR"
echo "[restore] Répertoire de destination: $TARGET_DIR"

# Affichage des snapshots disponibles
echo "[restore] Snapshots disponibles:"
restic snapshots --compact

# Vérification que le snapshot existe
if [[ "$SNAPSHOT_ID" != "latest" ]]; then
    if ! restic snapshots --json | jq -r '.[].short_id' | grep -q "^$SNAPSHOT_ID"; then
        echo "ERREUR: Snapshot $SNAPSHOT_ID introuvable"
        echo "Snapshots disponibles:"
        restic snapshots --compact
        exit 1
    fi
fi

# Restauration
echo "[restore] Restauration du snapshot '$SNAPSHOT_ID' vers '$TARGET_DIR'"
echo "[restore] Pattern d'inclusion: '$INCLUDE_PATTERN'"

if [[ -n "$INCLUDE_PATTERN" ]]; then
    restic restore "$SNAPSHOT_ID" \
        --target "$TARGET_DIR" \
        --include "$INCLUDE_PATTERN" \
        --verbose
else
    restic restore "$SNAPSHOT_ID" \
        --target "$TARGET_DIR" \
        --verbose
fi

# Vérification de l'intégrité après restauration
echo "[restore] Vérification de l'intégrité du repository..."
restic check

# Affichage du contenu restauré
echo "[restore] Contenu restauré dans $TARGET_DIR:"
find "$TARGET_DIR" -type f | head -20
TOTAL_FILES=$(find "$TARGET_DIR" -type f | wc -l)
echo "[restore] Total: $TOTAL_FILES fichiers restaurés"

echo "[restore] $(date '+%Y-%m-%d %H:%M:%S') - Restauration terminée avec succès"
echo "[restore] Répertoire de destination: $TARGET_DIR"
