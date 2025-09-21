# Configuration Cloudflare Tunnel (Gratuit)

## Étapes :

1. **Installer cloudflared :**
```bash
brew install cloudflared
```

2. **Se connecter à Cloudflare :**
```bash
cloudflared tunnel login
```

3. **Créer un tunnel :**
```bash
cloudflared tunnel create devops-stack
```

4. **Configurer le tunnel :**
Créer `~/.cloudflared/config.yml` :
```yaml
tunnel: devops-stack
credentials-file: ~/.cloudflared/YOUR-TUNNEL-ID.json

ingress:
  - hostname: gitlab.votre-domaine.com
    service: http://localhost:8081
  - hostname: jenkins.votre-domaine.com  
    service: http://localhost:8080
  - service: http_status:404
```

5. **Démarrer le tunnel :**
```bash
cloudflared tunnel run devops-stack
```

## Avantages :
- ✅ URLs fixes et personnalisables
- ✅ Certificats SSL automatiques
- ✅ Gratuit
- ✅ Plus professionnel que ngrok gratuit
