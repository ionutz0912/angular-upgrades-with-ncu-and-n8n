#### n8n is an open-source workflow automation tool that connects different apps and services to automate tasks and data flows through a visual node-based interface."


# 🤖 Angular Dependency Automation with n8n, Multi-Provider AI & Confluence

Automated Angular dependency updates using **npm-check-updates**, with **Multi-Provider AI error fixing** (Claude, OpenAI, GitHub Copilot, Ollama, Gemini) and **automatic Confluence documentation**.

## ✨ Features

- 🔄 **Automated Dependency Updates**: Runs npm-check-updates on any schedule (seconds, minutes, hours, days, weeks)
- 🤖 **Multi-Provider AI Error Fixing**: Support for 5 LLM providers with automatic detection and fallback:
  - **Claude AI** (Anthropic) - claude-sonnet-4-5, claude-opus-4, claude-haiku-4
  - **OpenAI** - gpt-4o, gpt-4-turbo, gpt-4, gpt-3.5-turbo
  - **GitHub Copilot** - Uses GitHub token for Copilot API access
  - **Ollama** (Local LLM) - codellama, deepseek-coder, llama2, mistral
  - **Google Gemini** - gemini-2.0-flash, gemini-1.5-pro, gemini-1.5-flash
- 🔄 **Smart Fallback Chain**: Automatically tries next provider if primary fails
- 📝 **Confluence Documentation**: Automatically documents all changes, errors, and solutions in Confluence ✅
- 🌿 **Git Integration**: Creates branches, commits, and pull requests automatically ✅
- 🔁 **Smart Retry Logic**: Retries fixes up to 3 times with improved context ✅
- ✅ **Comprehensive Validation**: Fixes npm install issues first, then runs linting, tests, and production builds ✅
- 🎯 **Flexible Scheduling**: Configure any interval using cron expressions ✅

## 🧪 Testing Status

✅ **100% COMPLETE - PRODUCTION READY (2025-11-14)**

### Current Version Features:
- ✅ **Core workflow**: `workflows/dependency-update-workflow.json` (25 nodes) - npm install error fixes + validation
- ✅ **PR workflow**: `workflows/dependency-update-with-github-pr.json` (30 nodes) - Core + automated PR creation + branch checkout fix
- ✅ **Full workflow**: `workflows/dependency-update-with-pr-and-confluence.json` (34 nodes) - Core + PR + Confluence docs + branch checkout fix
- ✅ **npm install error detection**: `npm-install-with-capture.sh` script captures ERESOLVE and peer dependency conflicts
- ✅ **Multi-Provider AI integration**: Automatically fixes npm install dependency conflicts using any of 5 LLM providers
- ✅ **Intelligent error handling**: Separates npm install failures from test/build failures
- ✅ **Complete automation flow**: Update package.json → npm install (with AI fixes) → Tests/Build validation → GitHub PR → Confluence docs
- ✅ **GitHub PR Creation**: Fully automated PR creation with professional formatting ([Example PRs](https://github.com/ionutz0912/angular-test-project/pulls))
- ✅ **Confluence Documentation**: Automatic documentation with npm install errors, AI-generated fixes, and test results ([See Guide](docs/CONFLUENCE-INTEGRATION-GUIDE.md))

### Workflow Capabilities:
- **Core workflow (25 nodes)**: Complete dependency update cycle without PR creation
- **PR workflow (30 nodes)**: All core features + automatic GitHub PR generation with branch checkout fix
- **Full workflow (34 nodes)**: All features + automatic Confluence documentation with branch checkout fix
- Handles common Angular dependency conflicts (peer dependencies, version mismatches, TypeScript version conflicts)
- Smart retry logic with AI analysis between attempts (supports all 5 providers)
- Clean JSON parsing with separated script execution and result reading
- Comprehensive error context extraction for AI analysis
- Professional PR formatting with emoji, tables, and detailed update lists
- Rich Confluence documentation with color-coded status, error analysis, and AI-generated fixes

### Testing History:
- ✅ Tested with Angular 19 → 20 upgrade (19 dependency updates)
- ✅ All 8 automation scripts verified working
- ✅ Full update cycle tested end-to-end (~31 seconds)
- ✅ All API integrations verified (Claude, GitHub, Confluence)
- ✅ Multi-Provider AI error fixing tested (3 error types, 100% success rate with Claude)
- ✅ GitHub PR creation tested successfully (Multiple PRs: #2, #4)
- ✅ Confluence documentation tested (2 test pages created successfully)
- ✅ Decision logic validated (skips AI processing when not needed)
- ✅ PR formatting validated (markdown, emoji, tables)
- ✅ Duplicate PR detection working
- ✅ Confluence page creation with error handling validated

**Available Workflows**:
- `workflows/dependency-update-workflow.json` (25 nodes) - Core automation
- `workflows/dependency-update-with-github-pr.json` (30 nodes) - Core + PR + branch fix
- `workflows/dependency-update-with-pr-and-confluence.json` (34 nodes) - **Full automation** (RECOMMENDED)

**Branch Naming Format**: `test-deps-update_MM-DD-YYYY_HH-MM-SS_AM/PM`

### Fully Integrated:
- ✅ GitHub PR creation nodes added and tested
- ✅ Professional PR formatting with markdown
- ✅ Ready for scheduled execution
- **Total time to full production**: ~1 hour

## 🏗️ Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                   n8n Workflow Orchestration                     │
├─────────────────────────────────────────────────────────────────┤
│  Schedule → Check Updates → Apply to package.json               │
│                ↓                                                 │
│           npm install (capture errors)                           │
│                ↓                                                 │
│         Install Failed? → YES → Multi-Provider AI Fix → Retry   │
│                ↓ NO                                              │
│         Run Tests & Build → PR + Confluence Docs                │
└─────────────────────────────────────────────────────────────────┘
```

## 📋 Prerequisites

- **Node.js** 18+ and npm 9+
- **Git** configured with SSH or HTTPS access
- **GitHub Account** with Personal Access Token
- **Claude API Key** from Anthropic
- **Confluence Cloud** account with API token
- **Angular Project(s)** to monitor

## 🚀 Quick Start

### 1. Clone and Install

```bash
# Clone the repository
git clone <your-repo-url>
cd ng-ncu-n8n

# Install dependencies
npm install

# Install global tools
npm install -g npm-check-updates @angular/cli
```

### 2. Configure Environment

```bash
# Copy environment template
cp .env.example .env

# Edit .env with your credentials
nano .env
```

Required environment variables (configure at least one LLM provider):

```bash
# LLM Provider Priority (auto-detects available providers)
LLM_PROVIDER_PRIORITY=claude,openai,copilot,ollama,gemini
LLM_ENABLE_FALLBACK=true
LLM_PROVIDER_RETRIES=2

# Claude API (optional - if you want to use Claude)
CLAUDE_API_KEY=sk-ant-api03-your-key-here
CLAUDE_MODEL=claude-sonnet-4-5

# OpenAI API (optional - if you want to use OpenAI)
OPENAI_API_KEY=sk-your-openai-key-here
OPENAI_MODEL=gpt-4o

# GitHub Copilot (optional - if you want to use Copilot)
GITHUB_COPILOT_TOKEN=ghu_your-copilot-token-here

# Ollama (optional - if you want to use local LLM)
OLLAMA_HOST=http://localhost:11434
OLLAMA_MODEL=codellama

# Gemini API (optional - if you want to use Gemini)
GEMINI_API_KEY=AIza-your-gemini-key-here
GEMINI_MODEL=gemini-2.0-flash

# GitHub
GITHUB_TOKEN=ghp_your_token_here
GITHUB_REPO_OWNER=your-username
GITHUB_REPO_NAME=your-repo-name

# Confluence
CONFLUENCE_DOMAIN=yourcompany.atlassian.net
CONFLUENCE_EMAIL=your-email@company.com
CONFLUENCE_API_TOKEN=your_api_token
CONFLUENCE_SPACE_KEY=DEV
CONFLUENCE_PARENT_PAGE_ID=123456789

# Project
DEFAULT_PROJECT_PATH=/path/to/your/angular/project
```

### 3. Start n8n

```bash
# Start n8n
npm run n8n

# Or with development tunnel for webhooks
npm run n8n:dev
```

n8n will be available at: http://localhost:5678

### 4. Import Workflow

1. Open n8n at http://localhost:5678
2. Log in with your credentials (from .env)
3. Click "Import from File"
4. Select `workflows/main-dependency-update.json`
5. Activate the workflow

### 5. Configure Schedule

Edit the "Schedule Trigger" node in the workflow:

- **Every Monday at 9 AM**: `0 9 * * 1`
- **Every Day at 2 AM**: `0 2 * * *`
- **Every 6 Hours**: `0 */6 * * *`
- **Every Hour**: `0 * * * *`
- **Every 30 Minutes**: `*/30 * * * *`

### 6. Test the Workflow

1. Click "Execute Workflow" button in n8n
2. Monitor the execution in real-time
3. Check Confluence for documentation
4. Verify PR creation in GitHub

## 📁 Project Structure

```
ng-ncu-n8n/
├── scripts/                           # Automation scripts
│   ├── update-dependencies.sh         # npm-check-updates wrapper
│   ├── npm-install-with-capture.sh    # npm install with error capture
│   ├── run-tests.sh                   # Test and build execution
│   ├── apply-claude-fix.sh            # Claude API integration
│   ├── validate-changes.sh            # Final validation
│   └── apply-file-fixes.sh            # Apply AI-generated fixes
├── workflows/                         # n8n workflow definitions
│   ├── dependency-update-workflow.json # Primary workflow (npm install fixes)
│   └── main-dependency-update.json    # Legacy workflow (reference)
├── mcp-config/                        # Confluence MCP setup
│   └── confluence-mcp-setup.md        # Setup instructions
├── confluence-templates/              # Documentation templates
│   └── update-page-template.html      # Confluence page template
├── docs/                              # Additional documentation
├── package.json                       # Project dependencies
├── .env.example                       # Environment template
├── .gitignore                         # Git ignore rules
└── README.md                          # This file
```

## 🔧 How It Works

### Workflow Execution Steps

1. **Schedule Trigger**: Starts at configured interval
2. **Set Variables**: Initializes run ID, branch name, project path
3. **Git Status Check**: Ensures clean working directory
4. **Create Branch**: Creates feature branch for updates
5. **Run NCU**: Checks for available dependency updates
6. **Apply Updates**: Updates package.json and runs npm install
7. **Commit Changes**: Commits dependency updates
8. **Run Tests**: Executes tests and production build
9. **AI Fix Loop** (if errors):
   - Extract error context
   - Call Claude API for fix suggestions
   - Apply fixes to files
   - Commit fixes
   - Re-run tests
   - Retry up to 3 times
10. **Final Validation**: Runs linting, tests, and build
11. **Create PR**: Opens pull request on GitHub
12. **Document in Confluence**: Creates comprehensive documentation page

### Scripts Overview

#### `update-dependencies.sh`

```bash
./scripts/update-dependencies.sh <project_path> [output_file]
```

- Runs npm-check-updates with JSON output
- Captures current and target versions
- Returns structured data for n8n processing

#### `npm-install-with-capture.sh`

```bash
./scripts/npm-install-with-capture.sh <project_path> [output_file]
```

- Runs npm install with --legacy-peer-deps flag
- Captures ERESOLVE and peer dependency errors
- Extracts dependency conflict details
- Returns structured install results with error context

#### `run-tests.sh`

```bash
./scripts/run-tests.sh <project_path> [output_file]
```

- Runs Angular tests with ChromeHeadless
- Executes production build
- Captures all errors and output
- Returns structured test results

#### `apply-claude-fix.sh`

```bash
./scripts/apply-claude-fix.sh <project_path> <error_context_file> <api_key> [output_file]
```

- Sends error context to Claude API
- Receives file-by-file fix suggestions
- Returns structured fix data

#### `apply-file-fixes.sh`

```bash
./scripts/apply-file-fixes.sh <project_path> <fixes_json_file>
```

- Applies fixes from Claude response
- Creates backups of original files
- Handles errors gracefully

#### `validate-changes.sh`

```bash
./scripts/validate-changes.sh <project_path> [output_file]
```

- Runs linting, tests, and production build
- Validates all changes are working
- Returns comprehensive validation report

## 🎯 Customization

### Adjusting Retry Logic

Edit the "Set Project Variables" node in the workflow:

```javascript
{
  "maxRetries": 3,  // Change this value
  "currentRetry": 0
}
```

### Changing LLM Provider or Model

Update your `.env` file:

```bash
# Change provider priority order
LLM_PROVIDER_PRIORITY=openai,claude,gemini

# Change specific models
CLAUDE_MODEL=claude-opus-4
OPENAI_MODEL=gpt-4-turbo
GEMINI_MODEL=gemini-1.5-pro

# Disable fallback (use only first provider)
LLM_ENABLE_FALLBACK=false
```

### Custom Project Paths

You can override the default project path in the workflow execution or set per-project schedules by duplicating the workflow and changing the `projectPath` variable.

### Modifying Confluence Documentation

Edit `confluence-templates/update-page-template.html` to customize the documentation structure and content.

## 🔐 Security Best Practices

1. **Never commit `.env` file** - It contains sensitive API keys
2. **Use environment variables** - Store all secrets in `.env`
3. **Rotate API tokens regularly** - Update tokens every 90 days
4. **Limit GitHub token scope** - Use repo-only permissions
5. **Use SSH keys for Git** - More secure than HTTPS credentials
6. **Enable 2FA** - On GitHub, Confluence, and Claude accounts

## 🐛 Troubleshooting

### Issue: n8n Can't Find Scripts

**Solution**: Ensure scripts are executable and paths are correct

```bash
chmod +x scripts/*.sh
export NODE_PATH=$(pwd)
```

### Issue: LLM API Returns Errors

**Solution**: Check API keys and configure multiple providers for fallback

```bash
# The system will automatically try the next provider if one fails
# Check which providers are available:
echo "Checking provider availability..."

# Test Claude API
curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-4-5","max_tokens":100,"messages":[{"role":"user","content":"test"}]}'

# Test OpenAI API
curl -X POST https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "content-type: application/json" \
  -d '{"model":"gpt-4o","messages":[{"role":"user","content":"test"}],"max_tokens":100}'

# Test Ollama (local)
curl -X GET http://localhost:11434/api/tags
```

### Issue: Git Push Fails

**Solution**: Verify Git credentials and permissions

```bash
# Test Git access
cd /path/to/your/project
git remote -v
git push --dry-run origin main
```

### Issue: Tests Fail in n8n but Pass Locally

**Solution**: Ensure environment variables are available to n8n

```bash
# Add to your n8n startup script
export PATH=$PATH:/usr/local/bin
export NODE_OPTIONS="--max-old-space-size=4096"
```

### Issue: Confluence API Returns 401

**Solution**: Verify API token and email

- Regenerate Confluence API token
- Ensure email matches Confluence account
- Check token hasn't expired

### Issue: No Updates Found but Package is Outdated

**Solution**: Clear npm cache and verify package.json

```bash
cd /path/to/your/project
npm cache clean --force
ncu --target latest
```

### Manual Branch Cleanup

**Note**: The latest workflow (v7) does NOT automatically delete test branches. This allows you to review changes before cleanup.

**To manually delete a specific test branch:**
```bash
cd /path/to/your/angular/project
git branch -D test-deps-update_11-13-2025_07-30-45_AM
```

**To delete all test branches at once:**
```bash
cd /path/to/your/angular/project
git branch | grep test-deps-update | xargs git branch -D
```

**To view all test branches:**
```bash
cd /path/to/your/angular/project
git branch | grep test-deps-update
```

## 📊 Monitoring and Maintenance

### Check Workflow Execution History

1. Open n8n UI
2. Go to "Executions" tab
3. Filter by workflow name
4. Review success/failure rates

### View Confluence Documentation

1. Go to your Confluence space
2. Navigate to parent page (configured in `.env`)
3. Find child pages for each update run
4. Review errors, fixes, and validation results

### GitHub Pull Requests

1. Go to your repository
2. Check "Pull requests" tab
3. Review automated PRs
4. Merge when validation passes

## 🚀 Advanced Features

### Multiple Projects

Duplicate the workflow for each project:

1. Import workflow again
2. Rename it (e.g., "Project A Updates")
3. Change `projectPath` in "Set Project Variables" node
4. Configure different schedule if needed

### Slack/Email Notifications

Add notification nodes after:
- Successful PR creation
- Failure after max retries
- Max retries reached without resolution

### Custom Test Commands

Modify `run-tests.sh` to add custom test commands:

```bash
# Add before final validation
npm run e2e-tests
npm run integration-tests
```

### Dependency Filtering

Modify `update-dependencies.sh` to exclude certain packages:

```bash
# Skip specific packages
ncu --reject react,webpack
```

## 📈 Performance Tips

1. **Run during off-hours**: Schedule for nights or weekends
2. **Batch updates**: Run weekly instead of daily for stability
3. **Cache node_modules**: Preserve node_modules between runs
4. **Parallel execution**: Run multiple projects in parallel workflows
5. **Optimize tests**: Use `--watch=false --progress=false` for faster tests

## 🤝 Contributing

Contributions welcome! Please:

1. Fork the repository
2. Create a feature branch
3. Make your changes
4. Test thoroughly
5. Submit a pull request

## 📝 License

MIT License - See LICENSE file for details

## 🙏 Acknowledgments

- [n8n](https://n8n.io/) - Workflow automation platform
- [npm-check-updates](https://www.npmjs.com/package/npm-check-updates) - Dependency update tool
- [Claude AI](https://www.anthropic.com/) - AI provider (Anthropic)
- [OpenAI](https://openai.com/) - AI provider (GPT models)
- [GitHub Copilot](https://github.com/features/copilot) - AI provider (GitHub)
- [Ollama](https://ollama.ai/) - Local LLM runner
- [Google Gemini](https://ai.google.dev/) - AI provider (Google)
- [Confluence](https://www.atlassian.com/software/confluence) - Documentation platform

## 📞 Support

For issues, questions, or suggestions:

1. Check the troubleshooting section above
2. Review existing issues on GitHub
3. Create a new issue with detailed information
4. Include workflow execution logs if relevant

## 🗺️ Roadmap

- [ ] Support for multiple package managers (yarn, pnpm)
- [ ] Rollback failed updates automatically
- [ ] AI-powered test generation for new features
- [ ] Integration with Jira for ticket creation
- [ ] Slack bot for interactive approval
- [ ] Dashboard for monitoring all projects
- [ ] Docker container deployment option
- [ ] Support for monorepos (Nx, Lerna)

---

**Built with ❤️ using n8n, Multi-Provider AI, and modern DevOps practices**

---
> **ARCHIVED 2026-07-09 — tuition paid:** Angular↔n8n era (Nov–Dec 2025) — longest-lived early project; taught the notification-pipeline patterns still in use
