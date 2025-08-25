# DevOps Stack

Ce projet contient une stack **DevOps** avec :
- GitLab CE (SCM + Registry)
- Jenkins (CI/CD)
- Traefik (reverse-proxy + HTTPS)
- (plus tard : monitoring, backups...)

## Structure

devops-stack/
├── data/ # volumes persistants (NE PAS versionner)
├── gitlab/ # config GitLab (montée en volumes)
├── jenkins/ # config Jenkins
├── traefik/ # config Traefik
├── .env # variables d'environnement (local, secrets) [IGNORED]
├── docker-compose.yml # stack principale
└── README.md

markdown
Copier
Modifier

## Démarrage rapide

1. Copier `.env.example` → `.env` et adapter les valeurs.
2. Lancer la stack :
   ```bash
   docker compose up -d
Accès :

GitLab : http://localhost:8080

Jenkins : http://localhost:8081

Traefik Dashboard : http://localhost:8082

