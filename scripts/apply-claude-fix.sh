#!/bin/bash
set -e

# Script to call Claude API and get fix suggestions
# Usage: ./apply-claude-fix.sh <project_path> <error_context_file> <claude_api_key> [output_file]

PROJECT_PATH=$1
ERROR_CONTEXT_FILE=$2
CLAUDE_API_KEY=$3
OUTPUT_FILE=${4:-/tmp/claude-fix.json}

if [ -z "$PROJECT_PATH" ] || [ -z "$ERROR_CONTEXT_FILE" ] || [ -z "$CLAUDE_API_KEY" ]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 <project_path> <error_context_file> <claude_api_key> [output_file]"
    exit 1
fi

if [ ! -f "$ERROR_CONTEXT_FILE" ]; then
    echo "Error: Error context file does not exist: $ERROR_CONTEXT_FILE"
    exit 1
fi

cd "$PROJECT_PATH"

echo "========================================" >&2
echo "Requesting Claude AI Fix Suggestions..." >&2
echo "Project: $PROJECT_PATH" >&2
echo "========================================" >&2

# Read error context
ERROR_CONTEXT=$(cat "$ERROR_CONTEXT_FILE")

# Prepare the prompt for Claude
PROMPT="I have an Angular project with compilation and test errors after updating dependencies. Please analyze these errors and provide specific fixes.

Errors:
$ERROR_CONTEXT

Please respond with a JSON array of fixes in this exact format:
[
  {
    \"file\": \"relative/path/to/file.ts\",
    \"action\": \"update\",
    \"content\": \"complete corrected file content here\",
    \"reason\": \"explanation of what was fixed and why\"
  }
]

Only include files that need changes. Provide the complete file content for each file."

# Create request body
REQUEST_BODY=$(cat <<EOF
{
  "model": "${CLAUDE_MODEL:-claude-sonnet-4-5}",
  "max_tokens": 16000,
  "system": "You are an expert Angular developer. Analyze compilation and test errors, then provide specific fixes. Return ONLY a valid JSON array of file changes. Do not include any other text or markdown formatting.",
  "messages": [
    {
      "role": "user",
      "content": $(echo "$PROMPT" | jq -Rs .)
    }
  ]
}
EOF
)

echo "Calling Claude API..." >&2

# Call Claude API
CLAUDE_RESPONSE=$(curl -s -X POST https://api.anthropic.com/v1/messages \
  -H "Content-Type: application/json" \
  -H "x-api-key: $CLAUDE_API_KEY" \
  -H "anthropic-version: 2023-06-01" \
  -d "$REQUEST_BODY")

# Check if API call was successful
if echo "$CLAUDE_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
    ERROR_MSG=$(echo "$CLAUDE_RESPONSE" | jq -r '.error.message')
    echo "Error: Claude API returned an error: $ERROR_MSG" >&2
    echo "{\"success\": false, \"error\": \"$ERROR_MSG\", \"rawResponse\": $CLAUDE_RESPONSE}" > "$OUTPUT_FILE"
    cat "$OUTPUT_FILE"
    exit 1
fi

# Extract the content from Claude's response
CONTENT=$(echo "$CLAUDE_RESPONSE" | jq -r '.content[0].text')

# Try to extract JSON array from the content
# Claude might wrap it in markdown code blocks
FIXES=$(echo "$CONTENT" | sed -n '/\[/,/\]/p' | jq '.')

if [ $? -ne 0 ] || [ -z "$FIXES" ]; then
    echo "Error: Could not parse fixes from Claude response" >&2
    echo "{\"success\": false, \"error\": \"Could not parse JSON from response\", \"rawContent\": $(echo "$CONTENT" | jq -Rs .)}" > "$OUTPUT_FILE"
    cat "$OUTPUT_FILE"
    exit 1
fi

FIX_COUNT=$(echo "$FIXES" | jq 'length')

# Create output
cat > "$OUTPUT_FILE" <<EOF
{
  "success": true,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "projectPath": "$PROJECT_PATH",
  "fixes": $FIXES,
  "fixCount": $FIX_COUNT,
  "rawResponse": $CLAUDE_RESPONSE
}
EOF

echo "" >&2
echo "========================================" >&2
echo "Claude AI analysis complete!" >&2
echo "Fixes suggested: $FIX_COUNT" >&2
echo "Output saved to: $OUTPUT_FILE" >&2
echo "========================================" >&2

# Output to stdout for n8n
cat "$OUTPUT_FILE"

exit 0
