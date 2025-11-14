#!/bin/bash
# Script to create GitHub Pull Request
# Usage: ./create-github-pr.sh <project_path> <branch_name> <pr_data_json> <github_token> [base_branch]

set +e

PROJECT_PATH=$1
BRANCH_NAME=$2
PR_DATA_JSON=$3
GITHUB_TOKEN=$4
BASE_BRANCH=${5:-main}

if [ -z "$PROJECT_PATH" ] || [ -z "$BRANCH_NAME" ] || [ -z "$PR_DATA_JSON" ] || [ -z "$GITHUB_TOKEN" ]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 <project_path> <branch_name> <pr_data_json> <github_token> [base_branch]"
    exit 1
fi

if [ ! -f "$PR_DATA_JSON" ]; then
    echo "Error: PR data JSON file does not exist: $PR_DATA_JSON"
    exit 1
fi

cd "$PROJECT_PATH"

echo "========================================" >&2
echo "Creating GitHub Pull Request..." >&2
echo "Project: $PROJECT_PATH" >&2
echo "Branch: $BRANCH_NAME" >&2
echo "Base: $BASE_BRANCH" >&2
echo "========================================" >&2

# Read PR data from JSON - use jq directly on file to handle special characters
TITLE=$(jq -r '.title' "$PR_DATA_JSON")
BODY=$(jq -r '.body' "$PR_DATA_JSON")
UPDATE_COUNT=$(jq -r '.updateCount // 0' "$PR_DATA_JSON")

echo "PR Title: $TITLE" >&2
echo "Update Count: $UPDATE_COUNT" >&2

# Get repository info from git remote
REPO_URL=$(git remote get-url origin)
echo "Repository URL: $REPO_URL" >&2

# Extract owner and repo name from URL
# Handles both HTTPS and SSH URLs
if [[ "$REPO_URL" =~ github\.com[:/]([^/]+)/([^/.]+) ]]; then
    REPO_OWNER="${BASH_REMATCH[1]}"
    REPO_NAME="${BASH_REMATCH[2]}"
else
    echo "Error: Could not extract repository info from URL: $REPO_URL" >&2
    exit 1
fi

echo "Repository: $REPO_OWNER/$REPO_NAME" >&2

# Push branch to remote if not already pushed
echo "" >&2
echo "Pushing branch to remote..." >&2
git push -u origin "$BRANCH_NAME" 2>&1 | grep -v "remote:" >&2

if [ $? -ne 0 ]; then
    echo "Warning: Branch push may have failed, continuing anyway..." >&2
fi

# Create PR using GitHub API
echo "" >&2
echo "Creating pull request via GitHub API..." >&2

PR_REQUEST=$(jq -n \
  --arg title "$TITLE" \
  --arg body "$BODY" \
  --arg head "$BRANCH_NAME" \
  --arg base "$BASE_BRANCH" \
  '{
    title: $title,
    body: $body,
    head: $head,
    base: $base,
    maintainer_can_modify: true
  }'
)

echo "Request payload prepared" >&2

# Call GitHub API
API_RESPONSE=$(curl -s -X POST \
  -H "Accept: application/vnd.github+json" \
  -H "Authorization: Bearer $GITHUB_TOKEN" \
  -H "X-GitHub-Api-Version: 2022-11-28" \
  "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls" \
  -d "$PR_REQUEST")

# Check for errors
if echo "$API_RESPONSE" | jq -e '.message' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$API_RESPONSE" | jq -r '.message')

    # Check if PR already exists
    if echo "$ERROR_MSG" | grep -q "already exists"; then
        echo "PR already exists for this branch" >&2

        # Get existing PR
        EXISTING_PR=$(curl -s \
          -H "Accept: application/vnd.github+json" \
          -H "Authorization: Bearer $GITHUB_TOKEN" \
          -H "X-GitHub-Api-Version: 2022-11-28" \
          "https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/pulls?head=$REPO_OWNER:$BRANCH_NAME&state=open")

        if [ "$(echo "$EXISTING_PR" | jq 'length')" -gt 0 ]; then
            PR_NUMBER=$(echo "$EXISTING_PR" | jq -r '.[0].number')
            PR_URL=$(echo "$EXISTING_PR" | jq -r '.[0].html_url')
            PR_STATE=$(echo "$EXISTING_PR" | jq -r '.[0].state')

            # Output result
            cat <<EOF
{
  "success": true,
  "prExists": true,
  "pr": {
    "number": $PR_NUMBER,
    "url": "$PR_URL",
    "state": "$PR_STATE"
  },
  "message": "Pull request already exists"
}
EOF
            exit 0
        fi
    fi

    # Other error
    echo "Error: GitHub API returned an error: $ERROR_MSG" >&2
    echo "{\"success\": false, \"error\": \"$ERROR_MSG\", \"rawResponse\": $API_RESPONSE}"
    exit 1
fi

# Extract PR info
PR_NUMBER=$(echo "$API_RESPONSE" | jq -r '.number')
PR_URL=$(echo "$API_RESPONSE" | jq -r '.html_url')
PR_STATE=$(echo "$API_RESPONSE" | jq -r '.state')

echo "" >&2
echo "========================================" >&2
echo "Pull Request Created Successfully!" >&2
echo "PR #$PR_NUMBER: $PR_URL" >&2
echo "========================================" >&2

# Output result
cat <<EOF
{
  "success": true,
  "prExists": false,
  "pr": {
    "number": $PR_NUMBER,
    "url": "$PR_URL",
    "state": "$PR_STATE",
    "title": "$TITLE",
    "base": "$BASE_BRANCH",
    "head": "$BRANCH_NAME"
  },
  "repository": {
    "owner": "$REPO_OWNER",
    "name": "$REPO_NAME"
  },
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF

exit 0
