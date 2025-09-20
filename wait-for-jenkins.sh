#!/bin/bash

echo "Waiting for Jenkins to be ready..."
echo "This may take 2-3 minutes on first startup..."

while true; do
    if curl -s http://localhost:8080/login >/dev/null 2>&1; then
        echo "✅ Jenkins is ready!"
        echo "🌐 Access Jenkins at: http://localhost:8080"
        echo "👤 Username: admin"
        echo "🔑 Password: admin123"
        break
    else
        echo "⏳ Still waiting for Jenkins..."
        sleep 10
    fi
done
