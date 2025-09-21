# 🔄 Système de Sauvegarde DevOps avec MinIO et Restic

Ce système intègre MinIO (stockage S3 compatible) et Restic (outil de sauvegarde) dans votre workflow DevOps pour automatiser les sauvegardes de votre infrastructure.

## 📋 Vue d'ensemble

### Composants
- **MinIO**: Stockage S3 compatible pour héberger les sauvegardes
- **Restic**: Outil de sauvegarde déduplicante et chiffrée
- **Pushgateway**: Export de métriques vers Prometheus
- **Jenkins**: Orchestration des sauvegardes via pipeline

### Architecture
```
Jenkins Pipeline → Restic Runner → MinIO S3 → Métriques Pushgateway
```

## 🚀 Installation et Configuration

### 1. Configuration des variables d'environnement

Copiez le fichier d'exemple et adaptez les valeurs :
```bash
cp .env.example .env
```

Variables importantes à configurer dans `.env` :
```bash
# MinIO
MINIO_ROOT_USER=admin
MINIO_ROOT_PASSWORD=votre_mot_de_passe_fort
MINIO_API_HOST=minio.local
MINIO_CONSOLE_HOST=minio-console.local
MINIO_BACKUP_BUCKET=backups

# Pushgateway
PUSHGATEWAY_HOST=push.local
```

### 2. Configuration DNS locale

Ajoutez à votre `/etc/hosts` :
```
127.0.0.1 minio.local
127.0.0.1 minio-console.local
127.0.0.1 push.local
```

### 3. Démarrage des services

```bash
# Créer le réseau si nécessaire
docker network create devops-stack_ci_net

# Démarrer les services
docker compose up -d minio restic-runner pushgateway
```

### 4. Configuration Jenkins Credentials

Créez les credentials suivants dans Jenkins :

1. **restic-password-file** (Secret file)
   - Créez un fichier contenant le mot de passe Restic
   - Uploadez-le comme "Secret file"

2. **minio-access-key** (Secret text)
   - Clé d'accès MinIO

3. **minio-secret-key** (Secret text)
   - Clé secrète MinIO

### 5. Configuration MinIO

1. Accédez à la console MinIO : `http://minio-console.local`
2. Connectez-vous avec `MINIO_ROOT_USER` / `MINIO_ROOT_PASSWORD`
3. Créez le bucket `backups`
4. Créez les clés d'accès pour Restic

## 📊 Utilisation

### Sauvegarde manuelle

```bash
# Via Jenkins (recommandé)
# Déclenchez le job "Backup Workflow" manuellement

# Via ligne de commande (debug)
docker exec -it restic-runner sh
export RESTIC_REPOSITORY="s3:http://minio.local/backups"
export AWS_ACCESS_KEY_ID="votre_access_key"
export AWS_SECRET_ACCESS_KEY="votre_secret_key"
echo "votre_passphrase" > /secrets/restic_password
export RESTIC_PASSWORD_FILE="/secrets/restic_password"
/backup-scripts/backup.sh
```

### Test de restauration

```bash
# Restauration complète
./infra/backups/restore.sh /restore

# Restauration sélective
./infra/backups/restore.sh /restore /backup/jenkins/jobs

# Restauration d'un snapshot spécifique
./infra/backups/restore.sh /restore /backup/jenkins latest
```

### Vérification des sauvegardes

```bash
# Lister les snapshots
docker exec restic-runner restic snapshots

# Statistiques du repository
docker exec restic-runner restic stats

# Vérification d'intégrité
docker exec restic-runner restic check
```

## 🔧 Scripts disponibles

### backup.sh
Script principal de sauvegarde qui :
- Crée des dumps des bases de données (MariaDB, PostgreSQL)
- Effectue la sauvegarde GitLab intégrée
- Lance Restic pour sauvegarder les volumes
- Applique la politique de rétention
- Exporte les métriques

### restore.sh
Script de restauration qui :
- Restaure un snapshot vers un répertoire cible
- Supporte la restauration sélective
- Vérifie l'intégrité après restauration

### metrics.sh
Utilitaire pour exporter des métriques personnalisées vers Pushgateway.

## 📈 Monitoring et Métriques

### Métriques exportées
- `restic_last_success_timestamp`: Timestamp de la dernière sauvegarde réussie
- `restic_snapshots_total`: Nombre total de snapshots
- `restic_backup_duration_seconds`: Durée de la sauvegarde
- `restic_repository_size_bytes`: Taille du repository
- `restic_backup_success`: Statut de la sauvegarde (1=succès, 0=échec)

### Dashboards Grafana
Créez des dashboards pour visualiser :
- Historique des sauvegardes
- Taille du repository dans le temps
- Durée des sauvegardes
- Taux de succès

## 🔒 Politique de Rétention

Configuration par défaut :
- **Horaire**: 24 dernières heures
- **Quotidien**: 7 derniers jours
- **Hebdomadaire**: 4 dernières semaines
- **Mensuel**: 12 derniers mois

Modifiez dans `backup.sh` :
```bash
restic forget --group-by host,tags \
  --keep-hourly 24 \
  --keep-daily 7 \
  --keep-weekly 4 \
  --keep-monthly 12 \
  --prune
```

## 🛠️ Dépannage

### Problèmes courants

#### MinIO inaccessible
```bash
# Vérifier le statut
docker ps | grep minio
docker logs minio

# Tester la connectivité
curl http://minio.local/minio/health/live
```

#### Échec d'initialisation Restic
```bash
# Vérifier les credentials
docker exec restic-runner env | grep -E "(AWS_|RESTIC_)"

# Tester manuellement
docker exec -it restic-runner restic init
```

#### Problèmes de permissions
```bash
# Vérifier les montages
docker exec restic-runner ls -la /backup/

# Vérifier les permissions des scripts
ls -la infra/backups/
```

### Logs utiles
```bash
# Logs MinIO
docker logs minio

# Logs Restic Runner
docker logs restic-runner

# Logs Jenkins (backup job)
# Consultez directement dans l'interface Jenkins
```

## 🔄 Maintenance

### Nettoyage périodique
```bash
# Nettoyage des snapshots orphelins
docker exec restic-runner restic prune

# Vérification complète (mensuelle)
docker exec restic-runner restic check --read-data

# Nettoyage des données MinIO (si nécessaire)
# Attention : supprime définitivement les données !
docker exec minio mc rm --recursive --force local/backups/old-data
```

### Mise à jour des images
```bash
# Mise à jour MinIO
docker compose pull minio
docker compose up -d minio

# Mise à jour Restic
docker compose pull restic-runner
docker compose up -d restic-runner
```

## 📞 Support

### Commandes de diagnostic
```bash
# État général
docker compose ps
docker compose logs --tail=50

# Test de connectivité S3
docker exec restic-runner restic list snapshots

# Vérification des métriques
curl http://push.local/metrics | grep restic
```

### Contacts
- Documentation Restic : https://restic.readthedocs.io/
- Documentation MinIO : https://docs.min.io/
- Issues : Créez un ticket dans votre système de ticketing

---

**⚠️ Important**: Testez régulièrement vos restaurations pour vous assurer que vos sauvegardes sont fonctionnelles !
