#!/usr/bin/env bash
set -euo pipefail

# Script de test de sauvegarde manuelle
echo "🧪 Test de sauvegarde manuelle..."

# Chargement des variables d'environnement
if [ -f ".env" ]; then
    source .env
else
    echo "❌ Fichier .env manquant"
    exit 1
fi

# Configuration des variables pour le test
ACCESS_KEY="${MINIO_ACCESS_KEY:-minio-ci-ak}"
SECRET_KEY="${MINIO_SECRET_KEY:-minio-ci-sk}"
BUCKET_NAME="${MINIO_BACKUP_BUCKET:-backups}"
RESTIC_PASSWORD="test-password-123"

echo "📋 Configuration du test:"
echo "  - Repository: s3:http://minio.local/${BUCKET_NAME}"
echo "  - Access Key: ${ACCESS_KEY}"
echo "  - Hostname: ${BACKUP_HOSTNAME:-workflow}"

echo ""
echo "🔧 Initialisation du repository Restic..."

# Test dans le conteneur restic-runner
docker exec restic-runner sh -c "
    export AWS_ACCESS_KEY_ID='${ACCESS_KEY}'
    export AWS_SECRET_ACCESS_KEY='${SECRET_KEY}'
    export RESTIC_REPOSITORY='s3:http://minio.local/${BUCKET_NAME}'
    export RESTIC_PASSWORD='${RESTIC_PASSWORD}'
    
    echo '🔍 Test de connectivité S3...'
    restic version
    
    echo '🔧 Initialisation du repository (si nécessaire)...'
    if ! restic snapshots >/dev/null 2>&1; then
        echo 'Repository non initialisé, création...'
        restic init
        echo '✅ Repository initialisé'
    else
        echo '✅ Repository déjà initialisé'
    fi
    
    echo '📊 État actuel du repository:'
    restic snapshots --compact || echo 'Aucun snapshot existant'
"

echo ""
echo "📦 Création de données de test..."

# Créer quelques fichiers de test dans le conteneur
docker exec restic-runner sh -c "
    mkdir -p /test-data
    echo 'Test backup $(date)' > /test-data/test-file-1.txt
    echo 'Jenkins data simulation' > /test-data/jenkins-test.txt
    echo 'GitLab data simulation' > /test-data/gitlab-test.txt
    ls -la /test-data/
"

echo ""
echo "🚀 Lancement de la sauvegarde de test..."

docker exec restic-runner sh -c "
    export AWS_ACCESS_KEY_ID='${ACCESS_KEY}'
    export AWS_SECRET_ACCESS_KEY='${SECRET_KEY}'
    export RESTIC_REPOSITORY='s3:http://minio.local/${BUCKET_NAME}'
    export RESTIC_PASSWORD='${RESTIC_PASSWORD}'
    export BACKUP_HOSTNAME='${BACKUP_HOSTNAME:-workflow}'
    
    echo '📁 Sauvegarde des données de test...'
    restic backup /test-data \
        --tag manual-test \
        --host \"\${BACKUP_HOSTNAME}\" \
        --verbose
    
    echo '📊 Snapshots après sauvegarde:'
    restic snapshots --compact
    
    echo '📈 Statistiques du repository:'
    restic stats --mode raw-data
"

echo ""
echo "🔄 Test de restauration..."

docker exec restic-runner sh -c "
    export AWS_ACCESS_KEY_ID='${ACCESS_KEY}'
    export AWS_SECRET_ACCESS_KEY='${SECRET_KEY}'
    export RESTIC_REPOSITORY='s3:http://minio.local/${BUCKET_NAME}'
    export RESTIC_PASSWORD='${RESTIC_PASSWORD}'
    
    echo '🔄 Restauration du dernier snapshot...'
    rm -rf /restore-test
    mkdir -p /restore-test
    
    restic restore latest --target /restore-test --verbose
    
    echo '📋 Contenu restauré:'
    find /restore-test -type f -exec ls -la {} \;
    
    echo '🔍 Vérification du contenu:'
    cat /restore-test/test-data/test-file-1.txt
"

echo ""
echo "🧹 Nettoyage..."
docker exec restic-runner sh -c "
    rm -rf /test-data /restore-test
"

echo ""
echo "✅ Test de sauvegarde terminé avec succès !"
echo ""
echo "📊 Pour voir les métriques, visitez: http://push.local"
echo "🗄️ Pour voir MinIO, visitez: http://minio-console.local"
