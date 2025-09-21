#!/usr/bin/env bash
set -euo pipefail

# Script de sauvegarde pour le workflow DevOps
# Variables attendues : RESTIC_REPOSITORY, AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, RESTIC_PASSWORD_FILE
# Variables optionnelles : BACKUP_HOSTNAME, PUSHGATEWAY_URL

echo "[backup] $(date '+%Y-%m-%d %H:%M:%S') - Début de la sauvegarde..."

# Vérification des variables requises
if [[ -z "${RESTIC_REPOSITORY:-}" ]]; then
    echo "ERREUR: RESTIC_REPOSITORY non défini"
    exit 1
fi

if [[ -z "${RESTIC_PASSWORD_FILE:-}" ]] || [[ ! -f "${RESTIC_PASSWORD_FILE}" ]]; then
    echo "ERREUR: RESTIC_PASSWORD_FILE non défini ou fichier inexistant"
    exit 1
fi

# Configuration
HOSTNAME_TAG="${BACKUP_HOSTNAME:-workflow}"
DUMP_DIR="/tmp/dumps"
BACKUP_START_TIME=$(date +%s)

echo "[backup] Préparation des dumps de bases de données..."
mkdir -p "$DUMP_DIR"

# Dump MariaDB si le conteneur existe et est en cours d'exécution
if docker ps --format '{{.Names}}' | grep -q '^mariadb$'; then
    echo "[backup] Dump MariaDB détecté, création du dump..."
    if docker exec mariadb sh -c 'mysqldump -uroot -p"$MYSQL_ROOT_PASSWORD" --all-databases --single-transaction --routines --triggers' > "$DUMP_DIR/mariadb_all.sql" 2>/dev/null; then
        echo "[backup] Dump MariaDB créé avec succès"
    else
        echo "[backup] ATTENTION: Échec du dump MariaDB"
    fi
fi

# Dump PostgreSQL si le conteneur existe et est en cours d'exécution
if docker ps --format '{{.Names}}' | grep -q '^postgres$'; then
    echo "[backup] Dump PostgreSQL détecté, création du dump..."
    if docker exec -e PGPASSWORD="$POSTGRES_PASSWORD" postgres pg_dumpall -U "$POSTGRES_USER" > "$DUMP_DIR/postgres_all.sql" 2>/dev/null; then
        echo "[backup] Dump PostgreSQL créé avec succès"
    else
        echo "[backup] ATTENTION: Échec du dump PostgreSQL"
    fi
fi

# Dump GitLab si nécessaire (backup GitLab intégré)
if docker ps --format '{{.Names}}' | grep -q '^gitlab$'; then
    echo "[backup] Création du backup GitLab..."
    if docker exec gitlab gitlab-backup create BACKUP=gitlab_backup_$(date +%Y%m%d_%H%M%S) 2>/dev/null; then
        echo "[backup] Backup GitLab créé avec succès"
    else
        echo "[backup] ATTENTION: Échec du backup GitLab"
    fi
fi

# Initialisation du repository Restic si nécessaire
echo "[backup] Vérification du repository Restic..."
if ! restic snapshots >/dev/null 2>&1; then
    echo "[backup] Initialisation du repository Restic..."
    restic init
    echo "[backup] Repository Restic initialisé"
fi

# Sauvegarde avec Restic
echo "[backup] Lancement de la sauvegarde Restic..."
restic backup \
    /backup/gitlab \
    /backup/jenkins \
    /backup/gitlab_data \
    /backup/gitlab_config \
    /backup/gitlab_logs \
    "$DUMP_DIR" \
    --tag daily \
    --host "$HOSTNAME_TAG" \
    --verbose

# Capturer le code de sortie de restic backup
BACKUP_EXIT_CODE=$?

# Restic exit codes:
# 0 = success, no warnings
# 3 = success with warnings (some files couldn't be read)
# other = actual error
if [ $BACKUP_EXIT_CODE -eq 0 ]; then
    echo "[backup] Sauvegarde terminée avec succès"
elif [ $BACKUP_EXIT_CODE -eq 3 ]; then
    echo "[backup] Sauvegarde terminée avec succès (quelques fichiers n'ont pas pu être lus - normal pour un système en cours d'exécution)"
else
    echo "[backup] ERREUR: Échec de la sauvegarde (code de sortie: $BACKUP_EXIT_CODE)"
    exit $BACKUP_EXIT_CODE
fi

echo "[backup] Application de la politique de rétention..."
restic forget \
    --group-by host,tags \
    --keep-hourly 24 \
    --keep-daily 7 \
    --keep-weekly 4 \
    --keep-monthly 12 \
    --prune \
    --verbose

echo "[backup] Vérification de l'intégrité (échantillon 1%)..."
restic check --read-data-subset=1%

# Nettoyage des dumps temporaires
rm -rf "$DUMP_DIR"
echo "[backup] Dumps temporaires supprimés"

# Calcul du temps d'exécution
BACKUP_END_TIME=$(date +%s)
BACKUP_DURATION=$((BACKUP_END_TIME - BACKUP_START_TIME))

# Export des métriques vers Pushgateway si configuré
if [[ -n "${PUSHGATEWAY_URL:-}" ]]; then
    echo "[backup] Export des métriques vers Pushgateway..."
    
    # Récupération du nombre de snapshots
    SNAP_COUNT=$(restic snapshots --json | jq 'length' 2>/dev/null || echo "0")
    
    # Récupération de la taille du repository
    REPO_SIZE=$(restic stats --json | jq '.total_size' 2>/dev/null || echo "0")
    
    # Export des métriques
    cat <<EOF | curl --data-binary @- "${PUSHGATEWAY_URL}/metrics/job/restic_backup/instance/${HOSTNAME_TAG}" --max-time 10 --silent || true
# TYPE restic_last_success_timestamp gauge
# HELP restic_last_success_timestamp Timestamp of last successful backup
restic_last_success_timestamp ${BACKUP_END_TIME}

# TYPE restic_snapshots_total gauge
# HELP restic_snapshots_total Total number of snapshots in repository
restic_snapshots_total ${SNAP_COUNT}

# TYPE restic_backup_duration_seconds gauge
# HELP restic_backup_duration_seconds Duration of backup in seconds
restic_backup_duration_seconds ${BACKUP_DURATION}

# TYPE restic_repository_size_bytes gauge
# HELP restic_repository_size_bytes Total size of repository in bytes
restic_repository_size_bytes ${REPO_SIZE}

# TYPE restic_backup_success gauge
# HELP restic_backup_success 1 if backup succeeded, 0 if failed
restic_backup_success 1
EOF
    echo "[backup] Métriques exportées vers Pushgateway"
fi

echo "[backup] $(date '+%Y-%m-%d %H:%M:%S') - Sauvegarde terminée avec succès en ${BACKUP_DURATION}s"

# Assurer que le script se termine avec succès même si restic a retourné des warnings
exit 0
