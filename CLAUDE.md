# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an **n8n-based automation system** that automatically updates Angular project dependencies using npm-check-updates, with **multi-provider AI-powered error fixing** (Claude, OpenAI, or GitHub Copilot) and Confluence documentation. The system runs locally (no Docker), orchestrates updates via bash scripts, and creates pull requests with comprehensive documentation.

## Core Architecture

### Orchestration Layer
Four n8n workflows available for different use cases:

1. **dependency-update-workflow.json** (25 nodes) - Core automation workflow
   - Handles npm install error detection and fixes with AI (Claude/OpenAI/Copilot)
   - Executes on configurable schedule (cron expressions)
   - Runs tests and builds after successful dependency installation
   - Does NOT create GitHub PRs or Confluence docs (stops after validation)

2. **dependency-update-with-github-pr.json** (30 nodes) - Automation with PR creation
   - Includes all features from core workflow
   - Automatically creates GitHub Pull Requests after successful validation
   - **NEW**: Explicit branch checkout before PR creation (fixes intermittent failures)
   - Generates detailed PR descriptions with update summary and test results
   - Pushes branch to remote and creates PR via GitHub API
   - Does NOT create Confluence documentation

3. **dependency-update-with-pr-and-confluence.json** (34 nodes) - Full automation with documentation
   - Includes all features from PR workflow
   - **NEW**: Explicit branch checkout before PR creation (fixes intermittent failures)
   - Automatically creates Confluence documentation page after PR creation
   - Documents npm install errors and AI solutions
   - Links Confluence page to GitHub PR for complete traceability
   - **RECOMMENDED for production use with full documentation**

4. **main-dependency-update.json** (28 nodes) - Legacy workflow (reference only)
   - Original workflow focusing on test/build error fixes
   - Kept for reference and comparison

**Key Features**:
- Separates npm install error detection and fixes from test/build error handling
- Smart retry logic with error context analysis
- All execution state managed through n8n variables
- **Branch checkout fix (2025-11-18)**: Explicit branch verification before PR creation eliminates intermittent failures

### Execution Layer (Bash Scripts)
Nine core scripts in `scripts/` directory that handle actual operations:

1. **update-dependencies.sh**: npm-check-updates wrapper with structured JSON output
2. **npm-install-with-capture.sh**: npm install with ERESOLVE/peer dependency error capture
3. **run-tests.sh**: Angular testing (ng test) + production build (ng build --configuration production)
4. **apply-ai-fix.sh**: **Multi-provider AI integration** (Claude/OpenAI/Copilot) for error analysis and fix generation
5. **apply-claude-fix.sh**: Legacy Claude-only API integration (kept for backward compatibility)
6. **apply-file-fixes.sh**: Applies AI-generated fixes to project files
7. **validate-changes.sh**: Final validation (lint + test + build)
8. **create-github-pr.sh**: GitHub Pull Request creation via GitHub API
9. **create-confluence-doc.sh**: Confluence documentation page creation via Confluence REST API

All scripts follow same pattern:
- Accept project path as first argument
- Output structured JSON to stdout or specified file
- Error messages to stderr
- Exit codes: 0 (success), 1 (failure)

### Integration Layer
- **GitHub API**: Pull request creation via workflow HTTP requests
- **AI Provider APIs**: Multi-provider error fixing support
  - **Claude (Anthropic)**: Default provider using claude-sonnet-4-5
  - **OpenAI**: GPT-4-Turbo, GPT-4o, GPT-3.5-Turbo support
  - **GitHub Copilot**: Via GitHub Models API (gpt-4o, o1-preview, etc.)
- **Confluence API** (optional): Documentation via MCP integration

## Environment Configuration

All configuration in `.env` file (see `.env.example` for template):

**AI Provider Configuration (choose one):**
- `AI_PROVIDER`: Explicit provider selection (`claude`, `openai`, or `copilot`). If not set, auto-detects based on available API keys.
- `CLAUDE_API_KEY`: Anthropic API key (format: sk-ant-api03-...)
- `OPENAI_API_KEY`: OpenAI API key (format: sk-...)
- `GITHUB_TOKEN`: Also used for GitHub Copilot via GitHub Models API

**Model Selection (optional):**
- `CLAUDE_MODEL`: Default `claude-sonnet-4-5` (options: claude-opus-4, claude-haiku-4)
- `OPENAI_MODEL`: Default `gpt-4-turbo` (options: gpt-4o, gpt-4o-mini, gpt-4, gpt-3.5-turbo)
- `COPILOT_MODEL`: Default `gpt-4o` (options: gpt-4o-mini, o1-preview, o1-mini)

**Critical variables:**
- `GITHUB_TOKEN`: Personal access token with repo scope (also used for Copilot)
- `GITHUB_REPO_OWNER`, `GITHUB_REPO_NAME`: Target repository
- `DEFAULT_PROJECT_PATH`: Absolute path to Angular project to monitor

**n8n variables:**
- `N8N_BASIC_AUTH_*`: Web interface authentication
- `N8N_PORT`: Default 5678

**Optional:**
- `CONFLUENCE_*`: For documentation integration
- `SLACK_WEBHOOK_URL`: For notifications

## Common Commands

### Development & Testing

```bash
# Start n8n locally (access at http://localhost:5678)
npm run n8n

# Start n8n with webhook tunnel for testing
npm run n8n:dev

# Test all scripts individually
npm run test:scripts

# Make scripts executable if needed
chmod +x scripts/*.sh
```

### Manual Script Testing

```bash
# Test dependency check
./scripts/update-dependencies.sh /path/to/project /tmp/updates.json

# Test npm install with error capture
./scripts/npm-install-with-capture.sh /path/to/project /tmp/install.json

# Test running tests and build
./scripts/run-tests.sh /path/to/project /tmp/results.json

# Test multi-provider AI integration (auto-detects provider from env)
./scripts/apply-ai-fix.sh /path/to/project /tmp/errors.txt /tmp/fixes.json

# Or explicitly set provider:
AI_PROVIDER=openai ./scripts/apply-ai-fix.sh /path/to/project /tmp/errors.txt /tmp/fixes.json
AI_PROVIDER=copilot ./scripts/apply-ai-fix.sh /path/to/project /tmp/errors.txt /tmp/fixes.json

# Legacy Claude-only script (backward compatible)
./scripts/apply-claude-fix.sh /path/to/project /tmp/errors.txt $CLAUDE_API_KEY /tmp/fixes.json

# Test applying fixes
./scripts/apply-file-fixes.sh /path/to/project /tmp/fixes.json

# Test final validation
./scripts/validate-changes.sh /path/to/project /tmp/validation.json

# Test GitHub PR creation (requires GITHUB_TOKEN)
./scripts/create-github-pr.sh /path/to/project branch-name /tmp/pr-data.json $GITHUB_TOKEN main

# Test Confluence documentation creation (requires CONFLUENCE credentials in .env)
./scripts/create-confluence-doc.sh /tmp/confluence-data.json /tmp/confluence-result.json
```

### Workflow Management

```bash
# Import workflow: Use n8n UI → Import from File → choose workflow file:
#   - dependency-update-workflow.json (core automation, no PR or docs)
#   - dependency-update-with-github-pr.json (automation with PR, no docs)
#   - dependency-update-with-pr-and-confluence.json (RECOMMENDED: full automation with PR and docs)
# Activate workflow: Toggle switch in n8n UI
# Execute manually: Click "Execute Workflow" button
# View execution history: n8n UI → Executions tab
```

## Workflow Execution Flow

1. **Manual Trigger** → Start workflow execution
2. **Create Branch** → `git checkout -b test-deps-update_{timestamp}`
3. **Check for Updates** → Run npm-check-updates to detect available updates
4. **Parse Updates** → Extract update information
5. **Has Updates?** → Decision point
6. **Apply Updates to package.json** → Run `ncu -u` to update package.json only
7. **Commit package.json** → Commit updated package.json (separate from node_modules)
8. **Run npm install** → Execute npm install with error capture script
9. **Read Install Results** → Read JSON output from install script
10. **Parse Install Results** → Extract install status and errors
11. **Install Failed?** → Decision point for npm install errors
    - **YES** → Enter npm install fix loop:
      - Prepare Error Context → Extract ERESOLVE, peer dependency errors
      - Save Error Context → Write errors to temp file
      - Get Claude Fixes → Call Claude API with install error context
      - Read Claude Response → Read AI fix suggestions
      - Parse Claude Response → Extract file changes
      - Apply Claude Fixes → Update package.json/other files based on AI suggestions
      - Commit Fixes → Commit AI-generated changes
      - Retry npm install → Attempt install again
      - Read Retry Results → Check if install succeeded
      - Check Retry Result → Validate retry outcome
    - **NO** → npm install succeeded, continue to tests
12. **Run Tests & Build** → Execute ng test + ng build --configuration production
13. **Read Test Results** → Read JSON output from test script
14. **Parse Test Results** → Extract test and build status

**Additional steps for `dependency-update-with-github-pr.json` workflow:**

15. **Prepare PR Data** → Collect branch name, update info, test results; format PR title and body
16. **Save PR Data JSON** → Write PR data to temporary JSON file
17. **Create GitHub PR** → Call create-github-pr.sh script to push branch and create PR via GitHub API
18. **Parse PR Response** → Extract PR number, URL, and creation status

**Additional steps for `dependency-update-with-pr-and-confluence.json` workflow (FULL AUTOMATION):**

19. **Prepare Confluence Data** → Collect all workflow data (updates, install errors, Claude fixes, test results, PR info)
20. **Save Confluence Data JSON** → Write comprehensive documentation data to temporary JSON file
21. **Create Confluence Doc** → Call create-confluence-doc.sh script to create Confluence page via REST API
22. **Parse Confluence Response** → Extract Confluence page ID, URL, and creation status

**Note**:
- The core workflow (`dependency-update-workflow.json`) stops after step 14
- The PR workflow (`dependency-update-with-github-pr.json`) stops after step 18
- The full automation workflow (`dependency-update-with-pr-and-confluence.json`) completes all 22 steps
- The legacy `main-dependency-update.json` workflow handled test/build errors instead of npm install errors

## Key Design Patterns

### Error Handling Strategy
- All scripts use `set +e` or `set -e` appropriately (capture vs. fail-fast)
- Structured JSON output for easy n8n parsing
- Progress messages to stderr, JSON data to stdout
- **Separated read operations**: Scripts write to files, separate nodes read JSON to avoid parsing errors
- npm install errors captured with detailed dependency conflict information

### Multi-Provider AI Integration
The system supports three AI providers for error analysis and fix generation:

**Provider Selection** (in order of auto-detection priority):
1. **Claude (Anthropic)**: If `CLAUDE_API_KEY` is set
2. **OpenAI**: If `OPENAI_API_KEY` is set
3. **GitHub Copilot**: If `GITHUB_TOKEN` is set (uses GitHub Models API)

**Configuration**:
- Set `AI_PROVIDER=claude|openai|copilot` to explicitly choose provider
- Or let the system auto-detect based on available API keys
- Model selection via `CLAUDE_MODEL`, `OPENAI_MODEL`, or `COPILOT_MODEL`

**Common Format** (all providers):
- Prompt format: Structured request with error context
- Response format: JSON array of file fixes
- Each fix contains: `file` (path), `action` (update), `content` (full file), `reason` (explanation)

**API Endpoints**:
- Claude: `https://api.anthropic.com/v1/messages`
- OpenAI: `https://api.openai.com/v1/chat/completions`
- Copilot: `https://models.inference.ai.azure.com/chat/completions`

### Git Workflow
- Feature branches: `dependency-update-{timestamp}`
- Bot identity: Uses `GIT_USER_NAME` and `GIT_USER_EMAIL` from .env
- Commit messages: Descriptive with context ("Update dependencies", "Apply AI fix - Iteration 1")
- PR creation: Automated with detailed body including changes, errors, and solutions

### State Management
- n8n workflow variables track: `currentRetry`, `maxRetries`, `runId`, `branchName`, `projectPath`
- No persistent state between runs (stateless execution)
- Each run creates new branch, new PR, new Confluence page (if enabled)

### Confluence Documentation Integration
- Template: Uses Confluence Storage Format (HTML-like markup with macros)
- Page creation: Automated via Confluence REST API
- Content includes:
  - Dependency update summary with version changes
  - npm install errors and dependency conflicts
  - AI analysis and solutions applied (with provider name)
  - Test and build validation results
  - Links to GitHub PR and branch
- Parent page: All update documentation appears as child pages under configured parent
- Formatting: Status macros (color-coded), code blocks, structured tables

## Testing & Validation

### Test Strategy
1. **Pre-update**: Check git status (must be clean)
2. **Post-update**: Run tests and build
3. **Post-fix**: Re-run tests after each AI fix attempt
4. **Final validation**: Comprehensive lint + test + build

### Angular Test Configuration
- Uses `ng test --watch=false --browsers=ChromeHeadless`
- Production build: `ng build --configuration production`
- Requires Angular CLI in project or global install

## Customization Points

### Scheduling
Edit "Schedule Trigger" node in n8n workflow:
- Monday 9 AM: `0 9 * * 1`
- Daily 2 AM: `0 2 * * *`
- Every 6 hours: `0 */6 * * *`

### Retry Logic
Edit `.env`:
```bash
MAX_RETRY_ATTEMPTS=3        # Number of Claude fix attempts
```

### Claude Model
Edit `.env`:
```bash
CLAUDE_MODEL=claude-sonnet-4-5   # or claude-opus-4, claude-haiku-4
```

### Update Strategy
Modify `scripts/update-dependencies.sh` to customize npm-check-updates behavior:
- Skip packages: Add `--reject package1,package2`
- Target specific updates: Add `--target minor` or `--target patch`
- Filter by pattern: Add `--filter '@angular/*'`

### Confluence Documentation
Template at `confluence-templates/update-page-template.html`
Edit to customize structure, formatting, or content sections

## Troubleshooting

### Scripts Not Found
```bash
export NODE_PATH=$(pwd)
chmod +x scripts/*.sh
```

### AI Provider API Errors

**Test Claude API:**
```bash
curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-4-5","max_tokens":100,"messages":[{"role":"user","content":"test"}]}'
```

**Test OpenAI API:**
```bash
curl -X POST https://api.openai.com/v1/chat/completions \
  -H "Authorization: Bearer $OPENAI_API_KEY" \
  -H "content-type: application/json" \
  -d '{"model":"gpt-4-turbo","max_tokens":100,"messages":[{"role":"user","content":"test"}]}'
```

**Test GitHub Copilot API:**
```bash
curl -X POST https://models.inference.ai.azure.com/chat/completions \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "content-type: application/json" \
  -d '{"model":"gpt-4o","max_tokens":100,"messages":[{"role":"user","content":"test"}]}'
```

### Git Push Failures
Verify credentials and remote configuration:
```bash
cd $DEFAULT_PROJECT_PATH
git remote -v
git push --dry-run origin main
```

### Tests Pass Locally but Fail in n8n
Ensure environment availability:
```bash
export PATH=$PATH:/usr/local/bin
export NODE_OPTIONS="--max-old-space-size=4096"
```

### n8n Not Starting
Check port availability:
```bash
lsof -i :5678
# Kill existing process if needed
kill -9 <PID>
```

## Security Considerations

- Never commit `.env` file (already in .gitignore)
- Rotate API tokens every 90 days
- Use minimum GitHub token scope (repo only)
- n8n basic auth enabled by default
- Scripts use absolute paths to prevent directory traversal
- File backups created before applying Claude fixes

## Multiple Projects

To automate multiple Angular projects:
1. Duplicate the workflow in n8n
2. Rename (e.g., "Project A - Dependency Updates")
3. Edit "Set Project Variables" node → change `projectPath` value
4. Configure different schedule if needed
5. Ensure each project has proper Git remote and GitHub repo configured

## File Structure Reference

```
ng-ncu-n8n/
├── scripts/                                        # Automation scripts (bash)
│   ├── update-dependencies.sh                      # NCU wrapper
│   ├── npm-install-with-capture.sh                 # npm install error capture
│   ├── run-tests.sh                                # Test executor
│   ├── apply-ai-fix.sh                             # Multi-provider AI client (Claude/OpenAI/Copilot) (NEW)
│   ├── apply-claude-fix.sh                         # Legacy Claude-only API client
│   ├── apply-file-fixes.sh                         # Fix applicator
│   ├── validate-changes.sh                         # Final validator
│   ├── create-github-pr.sh                         # GitHub PR creator
│   └── create-confluence-doc.sh                    # Confluence doc creator
├── workflows/                                      # n8n workflows (JSON)
│   ├── dependency-update-workflow.json             # Core workflow (25 nodes, no PR or docs)
│   ├── dependency-update-with-github-pr.json       # PR workflow (29 nodes, with PR)
│   ├── dependency-update-with-pr-and-confluence.json # Full workflow (33 nodes, PR + Confluence) (NEW)
│   └── main-dependency-update.json                 # Legacy workflow (reference)
├── mcp-config/                                     # Confluence MCP setup docs
├── confluence-templates/                           # Confluence page templates (HTML)
│   └── update-page-template.html                   # Updated with npm install error docs (UPDATED)
├── docs/                                           # Additional documentation
│   └── CONFLUENCE-INTEGRATION-GUIDE.md             # Complete Confluence setup guide (NEW)
├── .env.example                       # Environment template
├── .env                               # Your configuration (gitignored)
├── package.json                       # n8n + CLI dependencies
├── README.md                          # User documentation
├── QUICK-START.md                     # 10-minute setup guide
└── PROJECT-SUMMARY.md                 # Project overview
```

## Development Notes

- This is a **bash-based automation system**, not a Node.js application
- The only Node.js dependency is n8n itself (runs locally)
- Scripts are designed to be idempotent where possible
- All operations are logged to n8n execution history
- Workflow JSON can be exported/imported for backup or sharing
- AI API calls are synchronous (n8n waits for response)
- No database or persistent storage required

## Testing Status (2025-11-24)

✅ **FULLY TESTED AND PRODUCTION READY**

### Verified Components
- All 9 automation scripts tested individually (including apply-ai-fix.sh multi-provider support)
- Full update cycle with npm install error handling working
- n8n workflow execution successful:
  - dependency-update-workflow.json (25 nodes) - core automation
  - dependency-update-with-github-pr.json (29 nodes) - with PR creation
- All API integrations confirmed (Claude, OpenAI, GitHub Copilot, GitHub, Confluence)
- Multi-provider AI fix generation verified (auto-detection + explicit selection)
- npm install dependency conflict detection and AI fixes verified
- GitHub PR creation via API verified (push branch + create PR)
- Separated script execution and JSON reading (clean parsing, no errors)

### Key Configuration for Testing
```bash
# Start n8n with environment variables
set -a && source .env && set +a && npm run n8n

# Browser for testing (uses Brave instead of Chrome)
export CHROME_BIN="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"

# npm install configuration (handles peer dependency conflicts)
npm install --legacy-peer-deps
```

### Production Workflows
**Core Workflow**: `workflows/dependency-update-workflow.json` (25 nodes)
- Handles npm install dependency conflicts with AI (Claude/OpenAI/Copilot)
- Runs tests and builds, stops after validation
- No GitHub PR creation

**Full Workflow**: `workflows/dependency-update-with-github-pr.json` (29 nodes)
- All features from core workflow
- Automatically creates GitHub PRs with detailed descriptions
- Pushes branch to remote and creates PR via GitHub API

**Both workflows tested with:**
- Angular 19 → 20 upgrade (18 dependency updates)
- Successfully detects ERESOLVE errors, peer dependency conflicts
- Multi-provider AI support (Claude, OpenAI, GitHub Copilot)
- Clean JSON parsing with separated read operations
- Safe to run in production

### Known Working Configuration
- n8n: v1.119.1
- Node.js: v24.10.0
- npm: 11.6.0
- Target project: Angular 20.3.0
- Claude API model: claude-sonnet-4-5
