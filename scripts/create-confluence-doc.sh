#!/bin/bash

# ==============================================================================
# Create Confluence Documentation Page for Dependency Update Run
# ==============================================================================
#
# This script creates a Confluence page documenting a dependency update run,
# including npm install errors, Claude AI fixes, and test results.
#
# Usage:
#   ./create-confluence-doc.sh <workflow_data_json> <output_json>
#
# Arguments:
#   workflow_data_json - Path to JSON file containing workflow data
#   output_json        - Path where result JSON will be written
#
# Workflow data JSON structure:
# {
#   "runId": "20251113-123456",
#   "branchName": "test-deps-update_11-13-2025_10-30-00_AM",
#   "projectPath": "/path/to/project",
#   "updates": [{"name": "@angular/core", "from": "19.0.0", "to": "20.0.0"}],
#   "hasInstallErrors": true,
#   "installErrors": "ERESOLVE unable to resolve...",
#   "claudeAnalysis": "Analysis text",
#   "installFixes": [{"file": "package.json", "reason": "...", "content": "..."}],
#   "testPassed": true,
#   "buildPassed": true,
#   "prUrl": "https://github.com/...",
#   "prNumber": 123
# }
#
# Environment variables required:
#   CONFLUENCE_DOMAIN       - Confluence domain (e.g., company.atlassian.net)
#   CONFLUENCE_EMAIL        - Email for Confluence authentication
#   CONFLUENCE_API_TOKEN    - Confluence API token
#   CONFLUENCE_SPACE_KEY    - Space key (e.g., DEV)
#   CONFLUENCE_PARENT_PAGE_ID - Parent page ID for documentation
#
# Exit codes:
#   0 - Success
#   1 - Error (missing args, invalid data, API failure)
# ==============================================================================

set -e  # Exit on error

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages to stderr
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1" >&2
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1" >&2
}

# Validate arguments
if [ "$#" -ne 2 ]; then
    log_error "Usage: $0 <workflow_data_json> <output_json>"
    exit 1
fi

WORKFLOW_DATA_FILE="$1"
OUTPUT_FILE="$2"

# Validate input file exists
if [ ! -f "$WORKFLOW_DATA_FILE" ]; then
    log_error "Workflow data file not found: $WORKFLOW_DATA_FILE"
    exit 1
fi

# Validate required environment variables
REQUIRED_ENV_VARS=(
    "CONFLUENCE_DOMAIN"
    "CONFLUENCE_EMAIL"
    "CONFLUENCE_API_TOKEN"
    "CONFLUENCE_SPACE_KEY"
    "CONFLUENCE_PARENT_PAGE_ID"
)

for var in "${REQUIRED_ENV_VARS[@]}"; do
    if [ -z "${!var}" ]; then
        log_error "Required environment variable not set: $var"
        exit 1
    fi
done

log_info "Reading workflow data from: $WORKFLOW_DATA_FILE"

# Read and parse workflow data
WORKFLOW_DATA=$(cat "$WORKFLOW_DATA_FILE")

# Extract key fields with jq
RUN_ID=$(echo "$WORKFLOW_DATA" | jq -r '.runId // "unknown"')
BRANCH_NAME=$(echo "$WORKFLOW_DATA" | jq -r '.branchName // "unknown"')
PROJECT_PATH=$(echo "$WORKFLOW_DATA" | jq -r '.projectPath // "unknown"')
TOTAL_UPDATES=$(echo "$WORKFLOW_DATA" | jq -r '.totalUpdates // 0')
HAS_INSTALL_ERRORS=$(echo "$WORKFLOW_DATA" | jq -r '.hasInstallErrors // false')
TEST_PASSED=$(echo "$WORKFLOW_DATA" | jq -r '.testPassed // false')
BUILD_PASSED=$(echo "$WORKFLOW_DATA" | jq -r '.buildPassed // false')
PR_URL=$(echo "$WORKFLOW_DATA" | jq -r '.prUrl // ""')
PR_NUMBER=$(echo "$WORKFLOW_DATA" | jq -r '.prNumber // ""')

log_info "Processing run: $RUN_ID"
log_info "Branch: $BRANCH_NAME"
log_info "Total updates: $TOTAL_UPDATES"

# Determine overall status
if [ "$TEST_PASSED" = "true" ] && [ "$BUILD_PASSED" = "true" ]; then
    STATUS_COLOR="Green"
    STATUS_TEXT="SUCCESS"
else
    STATUS_COLOR="Red"
    STATUS_TEXT="FAILED"
fi

# Determine npm install status
if [ "$HAS_INSTALL_ERRORS" = "true" ]; then
    NPM_INSTALL_COLOR="Yellow"
    NPM_INSTALL_STATUS="FIXED BY AI"
else
    NPM_INSTALL_COLOR="Green"
    NPM_INSTALL_STATUS="SUCCESS"
fi

# Build dependency updates table rows
log_info "Building dependency updates table..."
UPDATES_TABLE=""
UPDATES=$(echo "$WORKFLOW_DATA" | jq -c '.updates // []')

if [ "$UPDATES" != "[]" ]; then
    while IFS= read -r update; do
        PKG_NAME=$(echo "$update" | jq -r '.name')
        PKG_FROM=$(echo "$update" | jq -r '.from')
        PKG_TO=$(echo "$update" | jq -r '.to')

        # Determine if major version change
        FROM_MAJOR=$(echo "$PKG_FROM" | cut -d. -f1)
        TO_MAJOR=$(echo "$PKG_TO" | cut -d. -f1)

        if [ "$FROM_MAJOR" != "$TO_MAJOR" ]; then
            CHANGE_TYPE='<ac:structured-macro ac:name="status"><ac:parameter ac:name="colour">Red</ac:parameter><ac:parameter ac:name="title">MAJOR</ac:parameter></ac:structured-macro>'
        else
            CHANGE_TYPE='<ac:structured-macro ac:name="status"><ac:parameter ac:name="colour">Blue</ac:parameter><ac:parameter ac:name="title">MINOR/PATCH</ac:parameter></ac:structured-macro>'
        fi

        UPDATES_TABLE+="<tr><td><code>$PKG_NAME</code></td><td>$PKG_FROM</td><td>$PKG_TO</td><td>$CHANGE_TYPE</td></tr>"
    done < <(echo "$UPDATES" | jq -c '.[]')
else
    UPDATES_TABLE="<tr><td colspan=\"4\">No updates available</td></tr>"
fi

# Build install errors section
INSTALL_ERRORS_SECTION=""
if [ "$HAS_INSTALL_ERRORS" = "true" ]; then
    log_info "Building npm install errors section..."

    INSTALL_ERRORS=$(echo "$WORKFLOW_DATA" | jq -r '.installErrors // "No error details"' | sed 's/&/&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
    CLAUDE_ANALYSIS=$(echo "$WORKFLOW_DATA" | jq -r '.claudeAnalysis // "No analysis available"' | sed 's/&/&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

    INSTALL_ERRORS_SECTION="<h2>⚠️ npm Install Errors Encountered</h2>
<ac:structured-macro ac:name=\"warning\">
  <ac:rich-text-body>
    <p>Dependency conflicts were detected during npm install. AI-powered fixes were automatically applied.</p>
  </ac:rich-text-body>
</ac:structured-macro>

<h3>Dependency Conflict Errors</h3>
<ac:structured-macro ac:name=\"code\">
  <ac:parameter ac:name=\"language\">bash</ac:parameter>
  <ac:parameter ac:name=\"title\">npm install errors</ac:parameter>
  <ac:plain-text-body><![CDATA[
$INSTALL_ERRORS
  ]]></ac:plain-text-body>
</ac:structured-macro>

<h2>🤖 AI-Generated Solutions for npm Install</h2>

<p><strong>Claude Analysis:</strong> $CLAUDE_ANALYSIS</p>"

    # Build fixes table
    INSTALL_FIXES=$(echo "$WORKFLOW_DATA" | jq -c '.installFixes // []')
    if [ "$INSTALL_FIXES" != "[]" ]; then
        FIX_INDEX=1
        while IFS= read -r fix; do
            FIX_FILE=$(echo "$fix" | jq -r '.file')
            FIX_REASON=$(echo "$fix" | jq -r '.reason' | sed 's/&/&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')
            FIX_CONTENT=$(echo "$fix" | jq -r '.content' | sed 's/&/&amp;/g; s/</\&lt;/g; s/>/\&gt;/g')

            INSTALL_ERRORS_SECTION+="<h3>Fix $FIX_INDEX: $FIX_FILE</h3>
<p><strong>Reason:</strong> $FIX_REASON</p>

<ac:structured-macro ac:name=\"code\">
  <ac:parameter ac:name=\"language\">json</ac:parameter>
  <ac:parameter ac:name=\"title\">$FIX_FILE</ac:parameter>
  <ac:plain-text-body><![CDATA[
$FIX_CONTENT
  ]]></ac:plain-text-body>
</ac:structured-macro>"

            FIX_INDEX=$((FIX_INDEX + 1))
        done < <(echo "$INSTALL_FIXES" | jq -c '.[]')
    fi

    INSTALL_ERRORS_SECTION+="<h3>Resolution Strategy</h3>
<p>Common solutions applied:</p>
<ul>
  <li>Updated peer dependency ranges to resolve conflicts</li>
  <li>Added package resolutions to package.json</li>
  <li>Used --legacy-peer-deps flag where appropriate</li>
  <li>Aligned conflicting dependency versions</li>
</ul>"
fi

# Build PR links section
PR_LINKS=""
if [ -n "$PR_URL" ] && [ "$PR_URL" != "null" ]; then
    PR_LINKS="<li><strong>Pull Request:</strong> <a href=\"$PR_URL\">View PR #$PR_NUMBER</a></li>"
else
    PR_LINKS="<li><strong>Pull Request:</strong> Not created yet</li>"
fi

# Get current timestamp
TIMESTAMP=$(date -u +"%Y-%m-%d %H:%M:%S UTC")

# Build complete Confluence page content
log_info "Building Confluence page content..."

PAGE_CONTENT="<h1>Dependency Update Run - $RUN_ID</h1>

<ac:structured-macro ac:name=\"info\">
  <ac:rich-text-body>
    <p><strong>Automated dependency update executed by n8n workflow with AI-powered error resolution</strong></p>
  </ac:rich-text-body>
</ac:structured-macro>

<h2>Summary</h2>
<table>
  <tbody>
    <tr>
      <td><strong>Run ID</strong></td>
      <td>$RUN_ID</td>
    </tr>
    <tr>
      <td><strong>Timestamp</strong></td>
      <td>$TIMESTAMP</td>
    </tr>
    <tr>
      <td><strong>Project Path</strong></td>
      <td><code>$PROJECT_PATH</code></td>
    </tr>
    <tr>
      <td><strong>Branch Name</strong></td>
      <td><code>$BRANCH_NAME</code></td>
    </tr>
    <tr>
      <td><strong>Total Updates</strong></td>
      <td>$TOTAL_UPDATES</td>
    </tr>
    <tr>
      <td><strong>npm Install Status</strong></td>
      <td>
        <ac:structured-macro ac:name=\"status\">
          <ac:parameter ac:name=\"colour\">$NPM_INSTALL_COLOR</ac:parameter>
          <ac:parameter ac:name=\"title\">$NPM_INSTALL_STATUS</ac:parameter>
        </ac:structured-macro>
      </td>
    </tr>
    <tr>
      <td><strong>Overall Status</strong></td>
      <td>
        <ac:structured-macro ac:name=\"status\">
          <ac:parameter ac:name=\"colour\">$STATUS_COLOR</ac:parameter>
          <ac:parameter ac:name=\"title\">$STATUS_TEXT</ac:parameter>
        </ac:structured-macro>
      </td>
    </tr>
  </tbody>
</table>

<h2>📦 Dependencies Updated</h2>

<table>
  <thead>
    <tr>
      <th>Package</th>
      <th>From Version</th>
      <th>To Version</th>
      <th>Change Type</th>
    </tr>
  </thead>
  <tbody>
    $UPDATES_TABLE
  </tbody>
</table>

$INSTALL_ERRORS_SECTION

<h2>✅ Test & Validation Results</h2>

<table>
  <thead>
    <tr>
      <th>Test Type</th>
      <th>Status</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>Unit Tests</td>
      <td>
        <ac:structured-macro ac:name=\"status\">
          <ac:parameter ac:name=\"colour\">$([ "$TEST_PASSED" = "true" ] && echo "Green" || echo "Red")</ac:parameter>
          <ac:parameter ac:name=\"title\">$([ "$TEST_PASSED" = "true" ] && echo "PASSED" || echo "FAILED")</ac:parameter>
        </ac:structured-macro>
      </td>
    </tr>
    <tr>
      <td>Production Build</td>
      <td>
        <ac:structured-macro ac:name=\"status\">
          <ac:parameter ac:name=\"colour\">$([ "$BUILD_PASSED" = "true" ] && echo "Green" || echo "Red")</ac:parameter>
          <ac:parameter ac:name=\"title\">$([ "$BUILD_PASSED" = "true" ] && echo "PASSED" || echo "FAILED")</ac:parameter>
        </ac:structured-macro>
      </td>
    </tr>
  </tbody>
</table>

<h2>🔗 Related Links</h2>

<ul>
  $PR_LINKS
  <li><strong>Branch:</strong> <code>$BRANCH_NAME</code></li>
  <li><strong>Repository:</strong> $GITHUB_REPO_OWNER/$GITHUB_REPO_NAME</li>
</ul>

<hr/>

<p><em>Generated automatically by n8n workflow on $TIMESTAMP</em></p>"

# Build Confluence API request body
PAGE_TITLE="Dependency Update - $RUN_ID"

CONFLUENCE_BODY=$(jq -n \
    --arg type "page" \
    --arg title "$PAGE_TITLE" \
    --arg spaceKey "$CONFLUENCE_SPACE_KEY" \
    --arg parentId "$CONFLUENCE_PARENT_PAGE_ID" \
    --arg content "$PAGE_CONTENT" \
    '{
        type: $type,
        title: $title,
        space: {
            key: $spaceKey
        },
        ancestors: [
            {
                id: $parentId
            }
        ],
        body: {
            storage: {
                value: $content,
                representation: "storage"
            }
        }
    }')

log_info "Creating Confluence page..."

# Make API request to create page
API_URL="https://$CONFLUENCE_DOMAIN/wiki/rest/api/content"

RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$API_URL" \
    -u "$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN" \
    -H "Content-Type: application/json" \
    -d "$CONFLUENCE_BODY")

# Extract HTTP status code
HTTP_CODE=$(echo "$RESPONSE" | tail -n1)
RESPONSE_BODY=$(echo "$RESPONSE" | sed '$d')

# Check if request was successful
if [ "$HTTP_CODE" -ge 200 ] && [ "$HTTP_CODE" -lt 300 ]; then
    log_info "Confluence page created successfully!"

    # Extract page details
    PAGE_ID=$(echo "$RESPONSE_BODY" | jq -r '.id')
    PAGE_URL="https://$CONFLUENCE_DOMAIN/wiki/spaces/$CONFLUENCE_SPACE_KEY/pages/$PAGE_ID"

    # Build output JSON
    OUTPUT_JSON=$(jq -n \
        --arg success "true" \
        --arg pageId "$PAGE_ID" \
        --arg pageUrl "$PAGE_URL" \
        --arg pageTitle "$PAGE_TITLE" \
        --arg timestamp "$TIMESTAMP" \
        '{
            success: ($success == "true"),
            page: {
                id: $pageId,
                url: $pageUrl,
                title: $pageTitle
            },
            timestamp: $timestamp
        }')

    echo "$OUTPUT_JSON" > "$OUTPUT_FILE"
    echo "$OUTPUT_JSON"

    log_info "Page URL: $PAGE_URL"
    exit 0
else
    log_error "Failed to create Confluence page (HTTP $HTTP_CODE)"
    log_error "Response: $RESPONSE_BODY"

    # Build error output JSON
    ERROR_JSON=$(jq -n \
        --arg success "false" \
        --arg error "HTTP $HTTP_CODE" \
        --arg details "$RESPONSE_BODY" \
        --arg timestamp "$TIMESTAMP" \
        '{
            success: ($success == "true"),
            error: $error,
            details: $details,
            timestamp: $timestamp
        }')

    echo "$ERROR_JSON" > "$OUTPUT_FILE"
    echo "$ERROR_JSON"
    exit 1
fi
