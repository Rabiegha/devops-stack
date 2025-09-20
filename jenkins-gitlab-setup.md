# Jenkins-GitLab Integration Setup Guide

## ✅ **Fixed Compatibility Issue**
- **Problem**: `SNAKE_CASE` error with GitLab Plugin 1.9.9
- **Solution**: Switched to `gitlab-branch-source` plugin (more stable)
- **Status**: ✅ Compatible with Jenkins LTS + JDK 17

## 🔧 Step 1: Access Jenkins
- **URL**: http://localhost:8080
- **Username**: admin
- **Password**: admin123

## 🔗 Step 2: Create GitLab Personal Access Token

### 2.1 Access GitLab
1. Go to GitLab: http://localhost:8081
2. **Sign in** (create account if needed)
3. Go to **User Settings** → **Access Tokens**

### 2.2 Create Personal Access Token
- **Token name**: `jenkins-integration`
- **Scopes** (check these):
   - ✅ `api`
   - ✅ `read_user` 
   - ✅ `read_repository`
   - ✅ `write_repository` (for webhooks)
- **Expires at**: Set future date or leave blank
- Click **Create personal access token**
- **⚠️ COPY THE TOKEN** - you won't see it again!

## 🔑 Step 3: Add GitLab Credentials to Jenkins

### 3.1 Navigate to Credentials
1. Go to **Manage Jenkins** → **Credentials**
2. Click **System** → **Global credentials (unrestricted)**
3. Click **Add Credentials**

### 3.2 Add GitLab Token
- **Kind**: `Username with password`
- **Username**: Your GitLab username
- **Password**: [paste your GitLab personal access token]
- **ID**: `gitlab-credentials`
- **Description**: `GitLab Personal Access Token`
- Click **Create**

## 🚀 Step 4: Create Multibranch Pipeline

### 4.1 Create New Item
1. Go to Jenkins dashboard
2. Click **New Item**
3. **Enter name**: `my-project-pipeline`
4. Select **Multibranch Pipeline**
5. Click **OK**

### 4.2 Configure Branch Sources
1. **Add source** → **GitLab**
2. **Server URL**: `http://gitlab.local` (or try alternatives):
   - `http://gitlab`
   - `http://172.20.0.3`
   - `http://localhost:8081`
3. **Credentials**: Select `gitlab-credentials`
4. **Owner**: Your GitLab username or group name
5. **Repository**: Your GitLab project name

### 4.3 Build Configuration
- **Mode**: by Jenkinsfile
- **Script Path**: `Jenkinsfile` (default)

### 4.4 Scan Multibranch Pipeline Triggers
- ✅ **Periodically if not otherwise run**
- **Interval**: 1 minute (for testing)

### 4.5 Save and Scan
- Click **Save**
- Jenkins will automatically scan for branches

## 🔍 Troubleshooting

### If connection fails with `http://gitlab.local`:
Try these alternatives in order:
1. `http://gitlab`
2. `http://localhost:8081`
3. `http://172.18.0.3` (check actual GitLab container IP)

### Check GitLab container IP:
```bash
docker inspect gitlab | grep IPAddress
```

### Check Jenkins logs:
```bash
docker-compose logs jenkins --tail=50
```

## ✅ Verification
- GitLab connection test passes
- Multibranch pipeline scans successfully
- Branches are detected and jobs created
