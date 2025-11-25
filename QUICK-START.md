# ⚡ Quick Start Guide

Get up and running in 10 minutes!

## 1️⃣ Install Dependencies (2 minutes)

```bash
cd ng-ncu-n8n
npm install
npm install -g n8n npm-check-updates @angular/cli
chmod +x scripts/*.sh
```

## 2️⃣ Configure Environment (3 minutes)

```bash
cp .env.example .env
nano .env  # or use your favorite editor
```

**Minimum required:**
```bash
CLAUDE_API_KEY=sk-ant-api03-your-key
GITHUB_TOKEN=ghp_your-token
GITHUB_REPO_OWNER=your-username
GITHUB_REPO_NAME=your-repo
DEFAULT_PROJECT_PATH=/path/to/your/angular/project
```

## 3️⃣ Start n8n (1 minute)

```bash
npm run n8n
```

Open http://localhost:5678

Login with credentials from `.env`:
- User: `admin` (or your `N8N_BASIC_AUTH_USER`)
- Pass: Your `N8N_BASIC_AUTH_PASSWORD`

## 4️⃣ Import Workflow (2 minutes)

1. Click "Import from File"
2. Select your desired workflow:
   - `workflows/dependency-update-workflow.json` - Core automation (25 nodes)
   - `workflows/dependency-update-with-github-pr.json` - Core + PR creation (30 nodes)
   - `workflows/dependency-update-with-pr-and-confluence.json` - **Full automation** (34 nodes, recommended)
3. Click "Import"
4. Activate the workflow (toggle switch)

**Note:** The workflow uses readable branch names (e.g., `test-deps-update_11-13-2025_07-30-45_AM`) and does NOT automatically delete branches, allowing you to review changes before cleanup.

## 5️⃣ Test It! (2 minutes)

1. Click "Execute Workflow" button
2. Watch it run in real-time
3. Check GitHub for PR
4. (Optional) Check Confluence for docs

## 🎯 What Happens When It Runs

```
1. Creates Git branch →
2. Checks for updates →
3. Updates dependencies →
4. Runs tests →
5. AI fixes errors (if any) →
6. Creates pull request →
7. Documents in Confluence
```

## 📅 Set Your Schedule

Click on "Schedule Trigger" node and set:

- **Every Monday at 9 AM**: `0 9 * * 1`
- **Every day at 2 AM**: `0 2 * * *`
- **Every 6 hours**: `0 */6 * * *`

## ✅ Checklist

- [ ] Dependencies installed
- [ ] `.env` file configured with API keys
- [ ] n8n running on http://localhost:5678
- [ ] Workflow imported and activated
- [ ] Test execution successful
- [ ] GitHub PR created
- [ ] Schedule configured

## 🆘 Quick Troubleshooting

**Can't find scripts?**
```bash
export NODE_PATH=$(pwd)
chmod +x scripts/*.sh
```

**Claude API errors?**
```bash
# Test your API key
curl -s -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: YOUR_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-4-5","max_tokens":100,"messages":[{"role":"user","content":"hi"}]}'
```

**Git push fails?**
```bash
cd /path/to/your/project
git remote -v
git config user.name "Bot Name"
git config user.email "bot@example.com"
```

**Tests fail in n8n but work locally?**
- Check Angular project has `@angular/cli` in devDependencies
- Ensure ChromeHeadless is available
- Check file permissions

## 📚 Next Steps

1. Read [README.md](README.md) for detailed features
2. Check [docs/SETUP-GUIDE.md](docs/SETUP-GUIDE.md) for full setup
3. See [docs/USAGE-EXAMPLES.md](docs/USAGE-EXAMPLES.md) for customizations
4. Set up Confluence integration (optional but recommended)

## 🎉 You're Done!

Your automation is now running! It will:
- ✅ Check for dependency updates on schedule
- ✅ Automatically fix errors with Claude AI
- ✅ Create pull requests for review
- ✅ Document everything for your team

**Happy Automating! 🚀**
