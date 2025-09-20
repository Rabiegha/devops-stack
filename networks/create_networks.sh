#!/bin/bash

# Script pour créer les réseaux Docker partagés
# Utilisé par tous les modules de la stack DevOps

echo "🌐 Création des réseaux Docker partagés..."

# Réseau principal pour tous les services exposés via Traefik
if ! docker network ls | grep -q "web"; then
    echo "📡 Création du réseau 'web'..."
    docker network create web
    echo "✅ Réseau 'web' créé avec succès"
else
    echo "ℹ️  Le réseau 'web' existe déjà"
fi

# Réseau pour la communication interne entre services (optionnel)
if ! docker network ls | grep -q "internal"; then
    echo "🔒 Création du réseau 'internal'..."
    docker network create internal --internal
    echo "✅ Réseau 'internal' créé avec succès"
else
    echo "ℹ️  Le réseau 'internal' existe déjà"
fi

echo ""
echo "📋 Réseaux disponibles :"
docker network ls | grep -E "(web|internal)"

echo ""
echo "🎉 Configuration des réseaux terminée !"
echo ""
echo "💡 Pour démarrer les services :"
echo "   cd reverse-proxy && docker-compose up -d"
echo "   cd ../scm && docker-compose up -d"
echo "   cd ../ci && docker-compose up -d"
