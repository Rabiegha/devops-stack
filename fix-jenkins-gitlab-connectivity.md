# Fix Jenkins-GitLab Connectivity Issues

## Problem Identified
Jenkins can't connect to GitLab because:
1. Using wrong hostname: `gitlab.local` instead of `gitlab` (container name)
2. Using wrong port: `2222` instead of `22` (internal container port)
3. Missing network tools in Jenkins container

## Solution Steps

### 1. Rebuild Jenkins with Network Tools
```bash
docker-compose stop jenkins
docker-compose rm -f jenkins
docker-compose build jenkins
docker-compose up -d jenkins
```

### 2. Fix Git Repository URL in Jenkins
The repository URL should be one of these formats:

**Option A: SSH with container name (RECOMMENDED)**
```
git@gitlab:furious-ducks/sample-app.git
```

**Option B: SSH with explicit port**
```
ssh://git@gitlab:22/furious-ducks/sample-app.git
```

**Option C: HTTP (if SSH issues persist)**
```
http://gitlab/furious-ducks/sample-app.git
```

### 3. Update Jenkins Job Configuration
1. Go to your Jenkins job configuration
2. In the "Source Code Management" section
3. Update the Repository URL to use `gitlab` instead of `gitlab.local`
4. Change port from `2222` to `22` (or remove port entirely)

### 4. Test Network Connectivity
Run this to test if Jenkins can reach GitLab:
```bash
docker exec jenkins ping -c 2 gitlab
docker exec jenkins nc -zv gitlab 22
docker exec jenkins nc -zv gitlab 80
```

### 5. SSH Key Configuration
Make sure your SSH key is properly configured:
1. The SSH key should be added to GitLab user
2. Jenkins credential should use the private key
3. Known hosts should include `gitlab` (not `gitlab.local`)

## Alternative: Use HTTP Instead of SSH
If SSH continues to be problematic, switch to HTTP:

1. **Change repository URL to HTTP:**
   ```
   http://gitlab/furious-ducks/sample-app.git
   ```

2. **Create HTTP credentials in Jenkins:**
   - Kind: Username with password
   - Username: Your GitLab username
   - Password: Your GitLab Personal Access Token

3. **Update job to use HTTP credentials**

## Network Debugging Commands
```bash
# Check if containers can communicate
docker exec jenkins ping gitlab
docker exec jenkins nslookup gitlab
docker exec jenkins curl -I http://gitlab

# Check SSH connectivity
docker exec jenkins ssh-keyscan gitlab
docker exec jenkins ssh -T git@gitlab
```

## Key Points
- Use container names (`gitlab`) not external hostnames (`gitlab.local`)
- Use internal ports (`22`, `80`) not mapped ports (`2222`, `8081`)
- Both containers must be on the same Docker network (`devops-stack_ci_net`)
