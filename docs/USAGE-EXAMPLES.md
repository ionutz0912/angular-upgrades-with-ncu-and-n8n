# 📚 Usage Examples

This document provides practical examples for common use cases and customizations.

## Table of Contents

1. [Basic Usage](#basic-usage)
2. [Custom Schedules](#custom-schedules)
3. [Multiple Projects](#multiple-projects)
4. [Selective Updates](#selective-updates)
5. [Custom Notifications](#custom-notifications)
6. [Advanced Scenarios](#advanced-scenarios)

## Basic Usage

### Example 1: Run Once Immediately

Perfect for testing or one-off updates:

1. Open n8n workflow
2. Click "Execute Workflow" button
3. Monitor execution in real-time
4. Check results in GitHub and Confluence

### Example 2: Weekly Updates on Monday Morning

Schedule for minimal disruption:

**Schedule Trigger Node Configuration:**
```
Cron Expression: 0 9 * * 1
Timezone: America/New_York
```

This runs every Monday at 9 AM Eastern Time.

### Example 3: Daily Security Updates

Run every night to catch security patches quickly:

**Schedule Trigger Node Configuration:**
```
Cron Expression: 0 2 * * *
Timezone: UTC
```

This runs daily at 2 AM UTC.

## Custom Schedules

### Every 6 Hours

```
Cron Expression: 0 */6 * * *
```

### Every Business Day at 8 AM

```
Cron Expression: 0 8 * * 1-5
```

### First Day of Every Month

```
Cron Expression: 0 9 1 * *
```

### Every 30 Minutes (Development/Testing)

```
Cron Expression: */30 * * * *
```

**Warning**: Frequent runs can exceed API rate limits. Use for testing only.

### Custom Business Hours Only

Run every hour between 9 AM and 5 PM on weekdays:

```
Cron Expression: 0 9-17 * * 1-5
```

## Multiple Projects

### Scenario: Managing 3 Angular Projects

#### Option 1: Multiple Workflows

1. Import workflow 3 times
2. Rename each:
   - "Project A - Dependency Updates"
   - "Project B - Dependency Updates"
   - "Project C - Dependency Updates"
3. Edit "Set Project Variables" node in each:

**Project A:**
```javascript
{
  "projectPath": "/home/user/projects/project-a",
  "branchName": "automated-deps-update-projecta-{{$now.format('YYYY-MM-DD-HHmmss')}}",
  "runId": "{{$now.toUnixInteger()}}",
  "maxRetries": 3,
  "currentRetry": 0
}
```

**Project B:**
```javascript
{
  "projectPath": "/home/user/projects/project-b",
  "branchName": "automated-deps-update-projectb-{{$now.format('YYYY-MM-DD-HHmmss')}}",
  "runId": "{{$now.toUnixInteger()}}",
  "maxRetries": 3,
  "currentRetry": 0
}
```

4. Set different schedules:
   - Project A: Monday 9 AM
   - Project B: Tuesday 9 AM
   - Project C: Wednesday 9 AM

#### Option 2: Single Workflow with Loop

Create a wrapper workflow:

1. Add a "Function" node that outputs project list:

```javascript
return [
  { json: { projectPath: "/home/user/projects/project-a", projectName: "Project A" } },
  { json: { projectPath: "/home/user/projects/project-b", projectName: "Project B" } },
  { json: { projectPath: "/home/user/projects/project-c", projectName: "Project C" } }
];
```

2. Add "Split In Batches" node
3. Connect to main workflow
4. Each project runs sequentially

## Selective Updates

### Example 1: Only Patch Updates

Modify `scripts/update-dependencies.sh`:

```bash
# Replace this line:
ncu --jsonUpgraded --target latest > "$OUTPUT_FILE"

# With:
ncu --jsonUpgraded --target patch > "$OUTPUT_FILE"
```

### Example 2: Exclude Specific Packages

Modify `scripts/update-dependencies.sh`:

```bash
# Replace this line:
ncu --jsonUpgraded --target latest > "$OUTPUT_FILE"

# With (exclude Angular and TypeScript):
ncu --jsonUpgraded --target latest --reject "@angular/*,typescript" > "$OUTPUT_FILE"
```

### Example 3: Only Update Specific Packages

Modify `scripts/update-dependencies.sh`:

```bash
# Replace this line:
ncu --jsonUpgraded --target latest > "$OUTPUT_FILE"

# With (only update testing libraries):
ncu --jsonUpgraded --target latest --filter "jasmine*,karma*,@testing-library/*" > "$OUTPUT_FILE"
```

### Example 4: Separate Major and Minor Updates

Create two workflows:

**Minor Updates Workflow** (runs weekly):
```bash
ncu --jsonUpgraded --target minor > "$OUTPUT_FILE"
```

**Major Updates Workflow** (runs monthly):
```bash
ncu --jsonUpgraded --target major > "$OUTPUT_FILE"
```

## Custom Notifications

### Example 1: Slack Notification on Success

Add a "Slack" node after "Extract PR Info" node:

**Node Configuration:**
- **Webhook URL**: Your Slack webhook
- **Message**:
```
✅ *Dependency Update Complete*

*Project*: {{$json.projectPath}}
*Updates*: {{$json.totalUpdates}} dependencies
*AI Fixes*: {{$json.fixCount || 0}}
*PR*: {{$json.prUrl}}
*Confluence*: {{$json.confluencePageUrl}}

Status: All tests passed! 🎉
```

### Example 2: Email Notification on Failure

Add an "Email" node in the error path:

**Node Configuration:**
- **To**: your-team@company.com
- **Subject**: `❌ Dependency Update Failed - {{$json.projectPath}}`
- **Body**:
```html
<h2>Dependency Update Failed</h2>

<p><strong>Project:</strong> {{$json.projectPath}}</p>
<p><strong>Run ID:</strong> {{$json.runId}}</p>
<p><strong>Error:</strong></p>
<pre>{{$json.error}}</pre>

<p><strong>Action Required:</strong> Review logs and fix manually</p>
```

### Example 3: PagerDuty Alert for Critical Failures

Add an "HTTP Request" node:

**Node Configuration:**
- **Method**: POST
- **URL**: https://events.pagerduty.com/v2/enqueue
- **Body**:
```json
{
  "routing_key": "YOUR_INTEGRATION_KEY",
  "event_action": "trigger",
  "payload": {
    "summary": "Dependency update failed after max retries",
    "severity": "error",
    "source": "n8n-automation",
    "custom_details": {
      "project": "{{$json.projectPath}}",
      "runId": "{{$json.runId}}",
      "attempts": "{{$json.currentRetry}}"
    }
  }
}
```

### Example 4: Microsoft Teams Notification

Add an "HTTP Request" node:

**Node Configuration:**
- **Method**: POST
- **URL**: Your Teams webhook URL
- **Body**:
```json
{
  "@type": "MessageCard",
  "@context": "https://schema.org/extensions",
  "summary": "Dependency Update",
  "themeColor": "0078D7",
  "title": "✅ Dependency Update Complete",
  "sections": [
    {
      "activityTitle": "Project: {{$json.projectPath}}",
      "facts": [
        {
          "name": "Updates:",
          "value": "{{$json.totalUpdates}}"
        },
        {
          "name": "AI Fixes:",
          "value": "{{$json.fixCount || 0}}"
        },
        {
          "name": "Status:",
          "value": "All tests passed"
        }
      ],
      "markdown": true
    }
  ],
  "potentialAction": [
    {
      "@type": "OpenUri",
      "name": "View Pull Request",
      "targets": [
        {
          "os": "default",
          "uri": "{{$json.prUrl}}"
        }
      ]
    }
  ]
}
```

## Advanced Scenarios

### Scenario 1: Two-Stage Approval Process

Add manual approval before creating PR:

1. After "Parse Validation Results" node, add "Wait" node
2. Configure webhook for approval
3. Add "HTTP Request" node to send approval request
4. Wait for approval webhook
5. Continue to PR creation

**Implementation:**

Add these nodes between validation and PR creation:

- **Send Approval Request** (HTTP/Email/Slack)
- **Webhook Trigger** (wait for approval)
- **Conditional** (check approval status)
- **Create PR** (only if approved)

### Scenario 2: Automatic Rollback on Test Failure

Add rollback logic in error handler:

1. Create error workflow
2. Add "Execute Command" node:

```bash
cd {{$json.projectPath}} && \
git reset --hard origin/main && \
git checkout main && \
git branch -D {{$json.branchName}} && \
git push origin --delete {{$json.branchName}}
```

3. Add notification of rollback

### Scenario 3: Incremental Updates

Update one dependency at a time:

1. Modify workflow to process updates in loop
2. For each dependency:
   - Update single package
   - Run tests
   - If pass, commit and continue
   - If fail, skip and try next
3. Create PR with all successful updates

### Scenario 4: Integration with Jira

Create Jira ticket for each update run:

Add "HTTP Request" node after PR creation:

**Node Configuration:**
- **Method**: POST
- **URL**: `https://yourcompany.atlassian.net/rest/api/3/issue`
- **Authentication**: Basic (email + API token)
- **Body**:
```json
{
  "fields": {
    "project": {
      "key": "DEV"
    },
    "summary": "Dependency Update - {{$json.projectPath}} - {{$now.format('YYYY-MM-DD')}}",
    "description": {
      "type": "doc",
      "version": 1,
      "content": [
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "Automated dependency update completed"
            }
          ]
        },
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "Updates: {{$json.totalUpdates}}"
            }
          ]
        },
        {
          "type": "paragraph",
          "content": [
            {
              "type": "text",
              "text": "PR: ",
              "marks": [{"type": "strong"}]
            },
            {
              "type": "text",
              "text": "{{$json.prUrl}}",
              "marks": [{"type": "link", "attrs": {"href": "{{$json.prUrl}}"}}]
            }
          ]
        }
      ]
    },
    "issuetype": {
      "name": "Task"
    }
  }
}
```

### Scenario 5: Performance Monitoring

Track execution time and success rate:

1. Add "Set" node at start to capture start time
2. Add "Set" node at end to calculate duration
3. Send metrics to monitoring service:

**Node Configuration (HTTP Request to metrics service):**
```json
{
  "metric": "dependency_update",
  "value": 1,
  "tags": {
    "project": "{{$json.projectPath}}",
    "status": "{{$json.status}}",
    "duration_seconds": "{{$json.duration}}",
    "updates_count": "{{$json.totalUpdates}}",
    "fixes_count": "{{$json.fixCount}}"
  },
  "timestamp": "{{$now.toISO()}}"
}
```

### Scenario 6: Custom Test Strategy

Different test strategies for different update types:

1. Add "Switch" node after "Parse Dependency Updates"
2. Route based on update type:

**Switch Configuration:**
- **Case 1**: Major updates → Run full test suite + E2E
- **Case 2**: Minor updates → Run unit tests + build
- **Case 3**: Patch updates → Run smoke tests only

**Implementation:**

Create separate test scripts:
- `scripts/run-full-tests.sh` (all tests)
- `scripts/run-unit-tests.sh` (unit only)
- `scripts/run-smoke-tests.sh` (critical paths)

### Scenario 7: Weekend Batch Processing

Process multiple projects over the weekend:

**Friday Night:**
- Kick off updates for all projects
- Run tests overnight

**Saturday Morning:**
- Review failures
- Trigger AI fixes
- Re-run tests

**Sunday Evening:**
- Create PRs for successful updates
- Send summary report

**Implementation:**

Create 3 workflows:
1. **Friday Workflow** (runs 11 PM Friday): Initiates updates
2. **Saturday Workflow** (runs 8 AM Saturday): Processes failures
3. **Sunday Workflow** (runs 6 PM Sunday): Creates PRs and reports

## Testing Examples

### Test Single Script

```bash
# Test dependency check
./scripts/update-dependencies.sh ~/projects/my-app /tmp/test.json
cat /tmp/test.json | jq .

# Test with specific version target
NCU_TARGET=minor ./scripts/update-dependencies.sh ~/projects/my-app /tmp/test.json
```

### Test Claude Integration

```bash
# Create sample error
cat > /tmp/sample-error.json <<EOF
{
  "buildErrors": "ERROR in src/app/app.component.ts:10:5 - Property 'oldMethod' does not exist on type 'AppComponent'",
  "testErrors": ""
}
EOF

# Test Claude fix
source .env
./scripts/apply-claude-fix.sh ~/projects/my-app /tmp/sample-error.json $CLAUDE_API_KEY /tmp/fix.json

# View response
cat /tmp/fix.json | jq .
```

### Dry Run Mode

Create a dry-run version of the workflow:

1. Duplicate workflow
2. Rename to "Dependency Updates (Dry Run)"
3. Replace all "git push" commands with "git push --dry-run"
4. Skip PR creation node
5. Add final summary node showing what would happen

## Common Customizations

### Change Commit Message Format

Edit "Git Commit Dependencies" node:

```bash
git commit -m "chore: update dependencies

Updated {{$json.totalUpdates}} packages
- Angular: {{$json.angularVersion}}
- TypeScript: {{$json.typescriptVersion}}

Run ID: {{$json.runId}}
[skip ci]"
```

### Add Pre-Update Backup

Add node before "Apply Dependency Updates":

```bash
cd {{$json.projectPath}} && \
cp package.json package.json.backup && \
cp package-lock.json package-lock.json.backup
```

### Custom Branch Naming

Edit "Set Project Variables" node:

```javascript
{
  "branchName": "deps/{{$now.format('YYYY-MM')}}/auto-update-{{$now.format('DD')}}",
  // Other variables...
}
```

### Add Update Summary in PR Description

Edit "Create GitHub Pull Request" node body:

```markdown
## 📦 Dependency Updates

| Package | From | To | Type |
|---------|------|-----|------|
{{$json.updates.map(u => `| ${u.package} | ${u.from} | ${u.to} | ${u.type} |`).join('\n')}}

## 🤖 AI Fixes Applied

{{$json.fixes ? $json.fixes.length : 0}} files were automatically fixed

## ✅ Validation

- ✓ Linting passed
- ✓ Tests passed ({{$json.validationResult.test.summary}})
- ✓ Production build successful

## 📚 Documentation

[View detailed Confluence documentation]({{$json.confluencePageUrl}})

---
*Generated by n8n automation on {{$now.format('YYYY-MM-DD HH:mm:ss')}}*
```

---

**These examples should help you customize the automation to fit your specific needs! 🚀**
