# Jenkins-GitLab Integration Fix Guide

## Problem Solved
The Jackson library version conflict (`java.lang.NoSuchFieldError: SNAKE_CASE`) has been resolved by using a minimal plugin set that avoids dependency conflicts.

## Step-by-Step Setup

### 1. Access Jenkins
- URL: http://localhost:8080 (or your configured URL)
- Username: `admin`
- Password: `admin123`

### 2. Create GitLab Personal Access Token (PAT)
1. Go to your GitLab instance
2. Click on your profile picture → **Preferences**
3. Go to **Access Tokens** in the left sidebar
4. Create a new token with these scopes:
   - `api` (full API access)
   - `read_user` (read user information)
   - `read_repository` (read repository)
   - `write_repository` (write repository - if needed for webhooks)

### 3. Add GitLab Server in Jenkins
1. Go to **Manage Jenkins** → **Configure System**
2. Scroll down to **GitLab** section
3. Click **Add GitLab Server**
4. Configure:
   - **Name**: `GitLab Local` (or any name you prefer)
   - **GitLab host URL**: `http://gitlab` (container name) or `http://localhost:8081`
   - **Credentials**: Click **Add** → **Jenkins**

### 4. Create GitLab API Token Credential
When adding credentials, select:
- **Kind**: `GitLab API token`
- **Scope**: `Global`
- **API token**: Paste your GitLab Personal Access Token here
- **ID**: `gitlab-api-token` (or any ID you prefer)
- **Description**: `GitLab API Token`

### 5. Test Connection
1. Select the credential you just created
2. Click **Test Connection**
3. You should see "Success" message

## Alternative URLs to Try
If `http://gitlab` doesn't work, try these in order:
1. `http://gitlab:80`
2. `http://localhost:8081`
3. `http://host.docker.internal:8081` (for Docker Desktop on Mac/Windows)

## Troubleshooting

### If you still get connection errors:
1. Check if GitLab is accessible from Jenkins container:
   ```bash
   docker exec -it jenkins curl -I http://gitlab/api/v4/version
   ```

2. Verify GitLab API responds:
   ```bash
   curl -H "PRIVATE-TOKEN: your-token-here" http://localhost:8081/api/v4/version
   ```

### Network Issues:
- Ensure both containers are on the same Docker network
- Check docker-compose.yml network configuration

### Plugin Issues:
If you encounter plugin conflicts again:
1. Go to **Manage Jenkins** → **Manage Plugins**
2. Check for updates to GitLab-related plugins
3. Restart Jenkins after updates

## Next Steps
Once the connection works:
1. Create a new Pipeline job
2. Use "Pipeline script from SCM"
3. Select "Git" as SCM
4. Use your GitLab repository URL
5. Select your GitLab credentials

## Important Notes
- The minimal plugin set avoids Jackson conflicts
- Use Personal Access Tokens, not username/password
- Test the API connection manually if Jenkins fails
- Container networking uses service names (gitlab, jenkins)
