#!/usr/bin/env bash
set -euo pipefail

# Script de configuration automatique de MinIO
echo "🔧 Configuration automatique de MinIO..."

# Chargement des variables d'environnement
if [ -f ".env" ]; then
    source .env
else
    echo "❌ Fichier .env manquant"
    exit 1
fi

# Vérification que MinIO est démarré
if ! docker ps --format '{{.Names}}' | grep -q '^minio$'; then
    echo "❌ Conteneur MinIO non démarré"
    exit 1
fi

echo "📦 Installation du client MinIO (mc) dans le conteneur..."
docker exec minio sh -c '
    if ! command -v mc >/dev/null 2>&1; then
        curl -o /usr/local/bin/mc https://dl.min.io/client/mc/release/linux-amd64/mc
        chmod +x /usr/local/bin/mc
    fi
'

echo "🔗 Configuration de l'alias MinIO local..."
docker exec minio mc alias set local http://localhost:9000 "${MINIO_ROOT_USER}" "${MINIO_ROOT_PASSWORD}"

echo "📁 Création du bucket de sauvegarde..."
BUCKET_NAME="${MINIO_BACKUP_BUCKET:-backups}"
if docker exec minio mc ls local/ | grep -q "${BUCKET_NAME}/"; then
    echo "✅ Bucket '${BUCKET_NAME}' existe déjà"
else
    docker exec minio mc mb "local/${BUCKET_NAME}"
    echo "✅ Bucket '${BUCKET_NAME}' créé avec succès"
fi

echo "🔐 Création des clés d'accès pour Restic..."
ACCESS_KEY="${MINIO_ACCESS_KEY:-minio-ci-ak}"
SECRET_KEY="${MINIO_SECRET_KEY:-minio-ci-sk}"

# Vérifier si les clés existent déjà
if docker exec minio mc admin user list local | grep -q "${ACCESS_KEY}"; then
    echo "✅ Utilisateur '${ACCESS_KEY}' existe déjà"
else
    # Créer l'utilisateur
    docker exec minio mc admin user add local "${ACCESS_KEY}" "${SECRET_KEY}"
    echo "✅ Utilisateur '${ACCESS_KEY}' créé"
fi

echo "📋 Configuration des politiques d'accès..."
# Créer un fichier de politique temporaire
docker exec minio sh -c "cat > /tmp/restic-policy.json <<EOF
{
  \"Version\": \"2012-10-17\",
  \"Statement\": [
    {
      \"Effect\": \"Allow\",
      \"Action\": [
        \"s3:GetBucketLocation\",
        \"s3:ListBucket\",
        \"s3:ListBucketMultipartUploads\"
      ],
      \"Resource\": \"arn:aws:s3:::${BUCKET_NAME}\"
    },
    {
      \"Effect\": \"Allow\",
      \"Action\": [
        \"s3:AbortMultipartUpload\",
        \"s3:DeleteObject\",
        \"s3:GetObject\",
        \"s3:ListMultipartUploadParts\",
        \"s3:PutObject\"
      ],
      \"Resource\": \"arn:aws:s3:::${BUCKET_NAME}/*\"
    }
  ]
}
EOF"

# Créer la politique
docker exec minio mc admin policy create local restic-backup-policy /tmp/restic-policy.json

# Attacher la politique à l'utilisateur
docker exec minio mc admin policy attach local restic-backup-policy --user="${ACCESS_KEY}"

echo "🧪 Test de connectivité avec les nouvelles clés..."
docker exec restic-runner sh -c "
    export AWS_ACCESS_KEY_ID='${ACCESS_KEY}'
    export AWS_SECRET_ACCESS_KEY='${SECRET_KEY}'
    export RESTIC_REPOSITORY='s3:http://minio.local/${BUCKET_NAME}'
    
    # Test de connexion S3
    echo 'Test de connexion S3...'
    restic version
"

echo "📊 Informations de configuration:"
echo "  - Bucket: ${BUCKET_NAME}"
echo "  - Access Key: ${ACCESS_KEY}"
echo "  - Console: http://minio-console.local"
echo "  - API: http://minio.local"

echo "✅ Configuration MinIO terminée avec succès !"
