#!/bin/bash

# Script pour récupérer automatiquement les nouvelles URLs ngrok
echo "🔄 Récupération des nouvelles URLs ngrok..."

# Attendre que ngrok soit prêt
sleep 5

# Récupérer les URLs depuis l'API ngrok
URLS=$(curl -s http://localhost:4040/api/tunnels | python3 -c "
import sys, json
data = json.load(sys.stdin)
for tunnel in data['tunnels']:
    print(f'{tunnel[\"name\"].upper()}: {tunnel[\"public_url\"]}')
")

echo "📋 Nouvelles URLs disponibles :"
echo "$URLS"

# Optionnel : sauvegarder dans un fichier
echo "$URLS" > ngrok-urls.txt
echo "✅ URLs sauvegardées dans ngrok-urls.txt"
