# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is an **n8n-based automation system** that automatically updates Angular project dependencies using npm-check-updates, with Claude AI-powered error fixing and Confluence documentation. The system runs locally (no Docker), orchestrates updates via bash scripts, and creates pull requests with comprehensive documentation.

## Core Architecture

### Orchestration Layer
- **Primary n8n workflow** (`workflows/dependency-update-workflow.json`): 25-node workflow that orchestrates the complete automation pipeline
- **Key Feature**: Separates npm install error detection and fixes from test/build error handling
- Executes on configurable schedule (cron expressions)
- Handles npm install failures with Claude AI fix integration BEFORE running tests
- Smart retry logic with error context analysis
- All execution state managed through n8n variables

### Execution Layer (Bash Scripts)
Six core scripts in `scripts/` directory that handle actual operations:

1. **update-dependencies.sh**: npm-check-updates wrapper with structured JSON output
2. **npm-install-with-capture.sh**: npm install with ERESOLVE/peer dependency error capture (NEW)
3. **run-tests.sh**: Angular testing (ng test) + production build (ng build --configuration production)
4. **apply-claude-fix.sh**: Claude API integration for error analysis and fix generation
5. **apply-file-fixes.sh**: Applies Claude-generated fixes to project files
6. **validate-changes.sh**: Final validation (lint + test + build)

All scripts follow same pattern:
- Accept project path as first argument
- Output structured JSON to stdout or specified file
- Error messages to stderr
- Exit codes: 0 (success), 1 (failure)

### Integration Layer
- **GitHub API**: Pull request creation via workflow HTTP requests
- **Claude API**: Error fixing using Anthropic API (model: claude-sonnet-4-5)
- **Confluence API** (optional): Documentation via MCP integration

## Environment Configuration

All configuration in `.env` file (see `.env.example` for template):

**Critical variables:**
- `CLAUDE_API_KEY`: Anthropic API key (format: sk-ant-api03-...)
- `GITHUB_TOKEN`: Personal access token with repo scope
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

# Test Claude API integration
./scripts/apply-claude-fix.sh /path/to/project /tmp/errors.txt $CLAUDE_API_KEY /tmp/fixes.json

# Test applying fixes
./scripts/apply-file-fixes.sh /path/to/project /tmp/fixes.json

# Test final validation
./scripts/validate-changes.sh /path/to/project /tmp/validation.json
```

### Workflow Management

```bash
# Import workflow: Use n8n UI → Import from File → workflows/dependency-update-workflow.json
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

**Note**: This workflow focuses on fixing npm install dependency conflicts with Claude AI BEFORE running tests/builds. The legacy `main-dependency-update.json` workflow handled test/build errors instead.

## Key Design Patterns

### Error Handling Strategy
- All scripts use `set +e` or `set -e` appropriately (capture vs. fail-fast)
- Structured JSON output for easy n8n parsing
- Progress messages to stderr, JSON data to stdout
- **Separated read operations**: Scripts write to files, separate nodes read JSON to avoid parsing errors
- npm install errors captured with detailed dependency conflict information

### Claude API Integration
- Prompt format: Structured request with error context
- Response format: JSON array of file fixes
- Each fix contains: `file` (path), `action` (update), `content` (full file), `reason` (explanation)
- API model configurable via `CLAUDE_MODEL` env var

### Git Workflow
- Feature branches: `dependency-update-{timestamp}`
- Bot identity: Uses `GIT_USER_NAME` and `GIT_USER_EMAIL` from .env
- Commit messages: Descriptive with context ("Update dependencies", "Apply Claude AI fix - Iteration 1")
- PR creation: Automated with detailed body including changes, errors, and solutions

### State Management
- n8n workflow variables track: `currentRetry`, `maxRetries`, `runId`, `branchName`, `projectPath`
- No persistent state between runs (stateless execution)
- Each run creates new branch, new PR

## Testing & Validation

### Test Strategy
1. **Pre-update**: Check git status (must be clean)
2. **Post-update**: Run tests and build
3. **Post-fix**: Re-run tests after each Claude fix attempt
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

### Claude API Errors
Test API key directly:
```bash
curl -X POST https://api.anthropic.com/v1/messages \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -H "content-type: application/json" \
  -d '{"model":"claude-sonnet-4-5","max_tokens":100,"messages":[{"role":"user","content":"test"}]}'
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
├── scripts/                           # Automation scripts (bash)
│   ├── update-dependencies.sh         # NCU wrapper
│   ├── npm-install-with-capture.sh    # npm install error capture
│   ├── run-tests.sh                   # Test executor
│   ├── apply-claude-fix.sh            # Claude API client
│   ├── apply-file-fixes.sh            # Fix applicator
│   └── validate-changes.sh            # Final validator
├── workflows/                         # n8n workflows (JSON)
│   ├── dependency-update-workflow.json # Primary workflow (npm install fixes)
│   └── main-dependency-update.json    # Legacy workflow (reference)
├── mcp-config/                        # Confluence MCP setup docs
├── confluence-templates/              # Confluence page templates (HTML)
├── docs/                              # Additional documentation
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
- Claude API calls are synchronous (n8n waits for response)
- No database or persistent storage required

## Testing Status (2025-11-13)

✅ **FULLY TESTED AND PRODUCTION READY**

### Verified Components
- All 6 automation scripts tested individually (including new npm-install-with-capture.sh)
- Full update cycle with npm install error handling working
- n8n workflow execution successful (dependency-update-workflow.json - 25 nodes)
- All API integrations confirmed (Claude, GitHub, Confluence)
- npm install dependency conflict detection and Claude AI fixes verified
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

### Production Workflow
**File**: `workflows/dependency-update-workflow.json`
- 25 nodes orchestrating complete automation
- Tested with Angular 19 → 20 upgrade (18 dependency updates)
- Handles npm install dependency conflicts with Claude AI
- Successfully detects ERESOLVE errors, peer dependency conflicts
- Clean JSON parsing with separated read operations
- Safe to run in production

### Known Working Configuration
- n8n: v1.119.1
- Node.js: v24.10.0
- npm: 11.6.0
- Target project: Angular 20.3.0
- Claude API model: claude-sonnet-4-5
