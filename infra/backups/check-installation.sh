#!/usr/bin/env bash
set -euo pipefail

# Script de vérification de l'installation MinIO/Restic
# Usage: ./check-installation.sh

echo "🔍 Vérification de l'installation MinIO/Restic..."
echo "================================================"

# Couleurs pour l'affichage
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Fonction pour afficher le statut
check_status() {
    if [ $1 -eq 0 ]; then
        echo -e "${GREEN}✅ $2${NC}"
        return 0
    else
        echo -e "${RED}❌ $2${NC}"
        return 1
    fi
}

check_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

ERRORS=0

echo "1. Vérification des fichiers de configuration..."
echo "-----------------------------------------------"

# Vérification du fichier .env
if [ -f ".env" ]; then
    check_status 0 "Fichier .env présent"
    
    # Vérification des variables MinIO
    if grep -q "MINIO_ROOT_USER" .env && grep -q "MINIO_ROOT_PASSWORD" .env; then
        check_status 0 "Variables MinIO configurées"
    else
        check_status 1 "Variables MinIO manquantes dans .env"
        ((ERRORS++))
    fi
else
    check_status 1 "Fichier .env manquant (copiez .env.example)"
    ((ERRORS++))
fi

# Vérification des scripts
if [ -x "infra/backups/backup.sh" ] && [ -x "infra/backups/restore.sh" ]; then
    check_status 0 "Scripts de backup exécutables"
else
    check_status 1 "Scripts de backup non exécutables"
    ((ERRORS++))
fi

echo ""
echo "2. Vérification du réseau Docker..."
echo "-----------------------------------"

# Vérification du réseau
if docker network ls --format '{{.Name}}' | grep -q "^devops-stack_ci_net$"; then
    check_status 0 "Réseau devops-stack_ci_net existe"
else
    check_status 1 "Réseau devops-stack_ci_net manquant"
    echo "   Créez-le avec: docker network create devops-stack_ci_net"
    ((ERRORS++))
fi

echo ""
echo "3. Vérification des conteneurs..."
echo "---------------------------------"

# Vérification des conteneurs
for container in "minio" "restic-runner" "pushgateway"; do
    if docker ps --format '{{.Names}}' | grep -q "^${container}$"; then
        check_status 0 "Conteneur $container en cours d'exécution"
    elif docker ps -a --format '{{.Names}}' | grep -q "^${container}$"; then
        check_status 1 "Conteneur $container existe mais n'est pas démarré"
        echo "   Démarrez-le avec: docker compose up -d $container"
        ((ERRORS++))
    else
        check_status 1 "Conteneur $container n'existe pas"
        echo "   Créez-le avec: docker compose up -d $container"
        ((ERRORS++))
    fi
done

echo ""
echo "4. Vérification de la connectivité..."
echo "------------------------------------"

# Test de connectivité MinIO (si le conteneur est en cours d'exécution)
if docker ps --format '{{.Names}}' | grep -q "^minio$"; then
    if [ -f ".env" ]; then
        source .env
        if curl -f -s "http://${MINIO_API_HOST:-minio.local}/minio/health/live" >/dev/null 2>&1; then
            check_status 0 "MinIO API accessible"
        else
            check_status 1 "MinIO API non accessible"
            check_warning "Vérifiez votre fichier /etc/hosts pour ${MINIO_API_HOST:-minio.local}"
            ((ERRORS++))
        fi
    else
        check_warning "Impossible de tester MinIO sans fichier .env"
    fi
else
    check_warning "MinIO non démarré, test de connectivité ignoré"
fi

# Test Restic
if docker ps --format '{{.Names}}' | grep -q "^restic-runner$"; then
    if docker exec restic-runner restic version >/dev/null 2>&1; then
        check_status 0 "Restic fonctionnel"
    else
        check_status 1 "Restic non fonctionnel"
        ((ERRORS++))
    fi
else
    check_warning "Restic-runner non démarré, test ignoré"
fi

echo ""
echo "5. Vérification des volumes..."
echo "-----------------------------"

# Vérification des volumes
for volume in "minio_data" "restic_cache"; do
    if docker volume ls --format '{{.Name}}' | grep -q "${volume}$"; then
        check_status 0 "Volume $volume existe"
    else
        check_status 1 "Volume $volume manquant"
        ((ERRORS++))
    fi
done

echo ""
echo "6. Vérification des credentials Jenkins (optionnel)..."
echo "-----------------------------------------------------"

check_warning "Vérifiez manuellement dans Jenkins :"
echo "   - restic-password-file (Secret file)"
echo "   - minio-access-key (Secret text)"
echo "   - minio-secret-key (Secret text)"

echo ""
echo "7. Résumé de l'installation..."
echo "=============================="

if [ $ERRORS -eq 0 ]; then
    echo -e "${GREEN}🎉 Installation complète et fonctionnelle !${NC}"
    echo ""
    echo "Prochaines étapes :"
    echo "1. Configurez les credentials Jenkins"
    echo "2. Créez le bucket 'backups' dans MinIO"
    echo "3. Testez une sauvegarde manuelle"
    echo ""
    echo "URLs d'accès :"
    if [ -f ".env" ]; then
        source .env
        echo "- Console MinIO: http://${MINIO_CONSOLE_HOST:-minio-console.local}"
        echo "- API MinIO: http://${MINIO_API_HOST:-minio.local}"
        echo "- Pushgateway: http://${PUSHGATEWAY_HOST:-push.local}"
    fi
    exit 0
else
    echo -e "${RED}❌ Installation incomplète ($ERRORS erreurs détectées)${NC}"
    echo ""
    echo "Corrigez les erreurs ci-dessus avant de continuer."
    exit 1
fi
