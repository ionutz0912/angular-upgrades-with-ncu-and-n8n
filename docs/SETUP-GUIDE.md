# 📖 Complete Setup Guide

This guide will walk you through setting up the Angular Dependency Automation system step by step.

## Table of Contents

1. [System Requirements](#system-requirements)
2. [Installation Steps](#installation-steps)
3. [API Keys and Credentials](#api-keys-and-credentials)
4. [n8n Configuration](#n8n-configuration)
5. [Workflow Import](#workflow-import)
6. [Testing](#testing)
7. [Production Deployment](#production-deployment)

## System Requirements

### Required Software

- **Node.js**: Version 18.0.0 or higher
- **npm**: Version 9.0.0 or higher
- **Git**: Any recent version with SSH or HTTPS configured
- **Angular CLI**: Version matching your project
- **Chrome/Chromium**: For headless testing (already included in most systems)

### Optional but Recommended

- **jq**: JSON processor for shell scripts (install via `brew install jq` on macOS)
- **VS Code**: For editing workflows and scripts
- **Postman**: For testing API endpoints

### System Resources

- **RAM**: Minimum 4GB, 8GB recommended
- **Disk Space**: At least 2GB free
- **Network**: Stable internet connection for API calls

## Installation Steps

### Step 1: Verify Prerequisites

```bash
# Check Node.js version
node --version  # Should be v18.0.0 or higher

# Check npm version
npm --version   # Should be 9.0.0 or higher

# Check Git
git --version

# Install jq if not present
which jq || brew install jq  # macOS
which jq || sudo apt-get install jq  # Linux
```

### Step 2: Clone or Create Project

```bash
# If cloning from existing repository
git clone <repository-url>
cd ng-ncu-n8n

# If starting fresh, create directory
mkdir ng-ncu-n8n
cd ng-ncu-n8n
```

### Step 3: Install Dependencies

```bash
# Install project dependencies
npm install

# Install global tools
npm install -g n8n npm-check-updates @angular/cli

# Verify installations
n8n --version
ncu --version
ng version
```

### Step 4: Make Scripts Executable

```bash
# Make all shell scripts executable
chmod +x scripts/*.sh

# Verify permissions
ls -la scripts/
```

## API Keys and Credentials

### Claude API Key

1. Go to https://console.anthropic.com/
2. Sign up or log in
3. Navigate to "API Keys"
4. Click "Create Key"
5. Copy the key (starts with `sk-ant-api03-`)
6. Store it securely

### GitHub Personal Access Token

1. Go to https://github.com/settings/tokens
2. Click "Generate new token (classic)"
3. Give it a descriptive name: "n8n Dependency Automation"
4. Select scopes:
   - ✅ `repo` (Full control of private repositories)
   - ✅ `workflow` (Update GitHub Actions workflows)
5. Click "Generate token"
6. Copy the token (starts with `ghp_`)
7. Store it securely (you won't see it again!)

### Confluence API Token

1. Go to https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Enter label: "n8n Automation"
4. Click "Create"
5. Copy the token
6. Store it securely

### Finding Confluence Page ID

1. Open Confluence in your browser
2. Navigate to the parent page where you want documentation
3. Click "..." menu → "Page Information"
4. Look at the URL: `pages/viewinfo.action?pageId=123456789`
5. Copy the number after `pageId=`

## Environment Configuration

### Create .env File

```bash
# Copy template
cp .env.example .env

# Edit with your preferred editor
nano .env
# or
code .env
# or
vim .env
```

### Fill in Required Values

```bash
# n8n Authentication
N8N_BASIC_AUTH_ACTIVE=true
N8N_BASIC_AUTH_USER=admin
N8N_BASIC_AUTH_PASSWORD=your_secure_password_here  # Change this!

# Claude API
CLAUDE_API_KEY=sk-ant-api03-your-actual-key-here
CLAUDE_MODEL=claude-sonnet-4-5

# Git Configuration
GIT_USER_NAME=n8n-automation-bot
GIT_USER_EMAIL=automation@yourcompany.com
GITHUB_TOKEN=ghp_your_actual_token_here
GITHUB_REPO_OWNER=your-github-username
GITHUB_REPO_NAME=your-repo-name

# Confluence
CONFLUENCE_DOMAIN=yourcompany.atlassian.net
CONFLUENCE_EMAIL=your.email@yourcompany.com
CONFLUENCE_API_TOKEN=your_actual_token_here
CONFLUENCE_SPACE_KEY=DEV  # Your space key
CONFLUENCE_PARENT_PAGE_ID=123456789  # Your parent page ID

# Project Configuration
DEFAULT_PROJECT_PATH=/absolute/path/to/your/angular/project
MAX_RETRY_ATTEMPTS=3
EXPONENTIAL_BACKOFF_DELAY=5000
```

### Validate Configuration

```bash
# Load environment variables
source .env

# Test Claude API
curl -s -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"'"$CLAUDE_MODEL"'","max_tokens":1024,"messages":[{"role":"user","content":"test"}]}' | jq .

# Test GitHub API
curl -s -H "Authorization: Bearer $GITHUB_TOKEN" \
  https://api.github.com/user | jq .

# Test Confluence API
curl -s -u "$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN" \
  "https://$CONFLUENCE_DOMAIN/wiki/rest/api/content/$CONFLUENCE_PARENT_PAGE_ID" | jq .
```

All commands should return valid JSON without errors.

## n8n Configuration

### Start n8n

```bash
# Start n8n with your environment
source .env
npm run n8n

# Or use n8n:dev for tunnel (useful for webhooks)
npm run n8n:dev
```

You should see:

```
Editor is now accessible via:
http://localhost:5678/
```

### Initial Setup

1. Open http://localhost:5678 in your browser
2. Log in with credentials from `.env`:
   - Username: Value of `N8N_BASIC_AUTH_USER`
   - Password: Value of `N8N_BASIC_AUTH_PASSWORD`
3. You'll see the n8n dashboard

### Configure Environment Variables in n8n

n8n needs access to your environment variables:

#### Option 1: Use .env file (Recommended)

n8n automatically loads variables from `.env` if present in the working directory.

#### Option 2: Set via CLI

```bash
export N8N_USER_FOLDER=~/.n8n
n8n start
```

#### Option 3: Set in n8n Settings

1. Click "Settings" in n8n
2. Go to "Environments"
3. Add each variable manually

## Workflow Import

### Import Main Workflow

1. In n8n, click "Workflows" in sidebar
2. Click "Import from File" button (top right)
3. Select `workflows/main-dependency-update.json`
4. Click "Import"

### Configure Workflow Settings

After import, you need to configure a few nodes:

#### 1. Schedule Trigger Node

- Click on "Schedule Trigger" node
- Set your desired schedule:
  - **Cron Expression**: `0 9 * * 1` (Every Monday at 9 AM)
  - Or use the visual editor to set schedule

#### 2. Set Project Variables Node

- Click on "Set Project Variables" node
- Verify `projectPath` uses environment variable correctly:
  ```javascript
  {{$env.DEFAULT_PROJECT_PATH || $json.projectPath}}
  ```

#### 3. Execute Command Nodes

All "Execute Command" nodes should automatically use environment variables. Verify the paths are correct:

```javascript
{{$env.NODE_PATH}}/scripts/update-dependencies.sh
```

If needed, update to absolute paths:

```javascript
/absolute/path/to/ng-ncu-n8n/scripts/update-dependencies.sh
```

### Activate Workflow

1. Click the toggle switch at top of workflow
2. Ensure it says "Active"
3. Workflow will now run on schedule

## Testing

### Test Individual Scripts

Before running the full workflow, test each script:

#### Test 1: Update Dependencies Script

```bash
./scripts/update-dependencies.sh /path/to/your/angular/project /tmp/test-ncu.json
cat /tmp/test-ncu.json | jq .
```

Expected: JSON output with available updates.

#### Test 2: Run Tests Script

```bash
./scripts/run-tests.sh /path/to/your/angular/project /tmp/test-results.json
cat /tmp/test-results.json | jq .
```

Expected: JSON output with test and build results.

#### Test 3: Claude API Script

First, create a sample error file:

```bash
echo '{"error": "Sample error for testing"}' > /tmp/sample-error.json
```

Then test Claude script:

```bash
source .env
./scripts/apply-claude-fix.sh /path/to/your/project /tmp/sample-error.json $CLAUDE_API_KEY /tmp/claude-response.json
cat /tmp/claude-response.json | jq .
```

Expected: JSON with Claude's response.

### Test Full Workflow

#### Manual Test Execution

1. Open the workflow in n8n
2. Click "Execute Workflow" button (top right)
3. Watch the execution in real-time
4. Each node will show its status:
   - ✅ Green: Success
   - ⏳ Yellow: Running
   - ❌ Red: Error
5. Click on each node to see its output

#### Test with Specific Project

You can pass project path as input:

1. Click "Execute Workflow"
2. In the execution dialog, add JSON input:
   ```json
   {
     "projectPath": "/path/to/different/project"
   }
   ```
3. Click "Execute"

### Verify Outputs

After successful execution:

#### Check Git Branch

```bash
cd /path/to/your/project
git branch -a | grep automated-deps-update
```

#### Check GitHub PR

1. Go to your GitHub repository
2. Click "Pull requests" tab
3. You should see a new PR from the automation

#### Check Confluence Page

1. Go to your Confluence space
2. Navigate to the parent page
3. You should see a new child page with the run documentation

## Production Deployment

### Option 1: Run as Background Service (macOS/Linux)

Create a systemd service (Linux) or launchd service (macOS).

#### Linux (systemd)

Create `/etc/systemd/system/n8n.service`:

```ini
[Unit]
Description=n8n Workflow Automation
After=network.target

[Service]
Type=simple
User=youruser
WorkingDirectory=/path/to/ng-ncu-n8n
EnvironmentFile=/path/to/ng-ncu-n8n/.env
ExecStart=/usr/bin/npm run n8n
Restart=always
RestartSec=10

[Install]
WantedBy=multi-user.target
```

Enable and start:

```bash
sudo systemctl enable n8n
sudo systemctl start n8n
sudo systemctl status n8n
```

### Option 2: Use Process Manager (PM2)

```bash
# Install PM2
npm install -g pm2

# Start n8n with PM2
pm2 start npm --name "n8n" -- run n8n

# Save PM2 configuration
pm2 save

# Set up PM2 to start on boot
pm2 startup
```

### Option 3: Run in Docker (Alternative)

If you prefer Docker after all:

```bash
# Create Dockerfile
cat > Dockerfile <<EOF
FROM node:18-alpine
WORKDIR /app
COPY package*.json ./
RUN npm install -g n8n npm-check-updates @angular/cli
RUN npm install
COPY . .
RUN chmod +x scripts/*.sh
CMD ["npm", "run", "n8n"]
EOF

# Build and run
docker build -t n8n-automation .
docker run -d -p 5678:5678 --env-file .env n8n-automation
```

### Monitoring

#### Check Logs

```bash
# If using PM2
pm2 logs n8n

# If using systemd
sudo journalctl -u n8n -f

# If running directly
npm run n8n 2>&1 | tee n8n.log
```

#### Set Up Alerts

Add notification nodes to your workflow:
- Email notifications on failure
- Slack messages on success
- PagerDuty for critical errors

## Security Hardening

### 1. Secure .env File

```bash
chmod 600 .env
```

### 2. Use SSH Keys for Git

```bash
# Generate SSH key if needed
ssh-keygen -t ed25519 -C "n8n-automation@yourcompany.com"

# Add to GitHub
cat ~/.ssh/id_ed25519.pub
# Copy and add to GitHub → Settings → SSH Keys
```

### 3. Rotate API Keys Regularly

Set calendar reminder to rotate every 90 days:
- Claude API key
- GitHub token
- Confluence API token

### 4. Enable IP Whitelisting

If possible, restrict API access to your server's IP address.

### 5. Use HTTPS for n8n

If exposing n8n, use a reverse proxy with SSL:

```nginx
server {
    listen 443 ssl;
    server_name n8n.yourcompany.com;

    ssl_certificate /path/to/cert.pem;
    ssl_certificate_key /path/to/key.pem;

    location / {
        proxy_pass http://localhost:5678;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
```

## Backup and Recovery

### Backup n8n Data

```bash
# Backup workflows
cp -r ~/.n8n/workflows ~/backups/n8n-workflows-$(date +%Y%m%d)

# Backup credentials (encrypted)
cp -r ~/.n8n/credentials ~/backups/n8n-credentials-$(date +%Y%m%d)
```

### Restore from Backup

```bash
# Restore workflows
cp -r ~/backups/n8n-workflows-20250111/* ~/.n8n/workflows/

# Restart n8n
pm2 restart n8n
```

## Next Steps

1. ✅ Run a test execution
2. ✅ Verify PR creation
3. ✅ Check Confluence documentation
4. ✅ Set up monitoring and alerts
5. ✅ Configure multiple projects if needed
6. ✅ Schedule regular maintenance windows
7. ✅ Document your specific customizations

## Getting Help

If you encounter issues:

1. Check the [Troubleshooting section](../README.md#troubleshooting) in README
2. Review n8n execution logs
3. Test individual scripts manually
4. Verify all API credentials
5. Create an issue on GitHub with:
   - Error messages
   - Workflow execution logs
   - Environment details (Node version, OS, etc.)

---

**Setup complete! Your automation system is ready to keep your Angular dependencies up to date! 🚀**
