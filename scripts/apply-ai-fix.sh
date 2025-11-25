#!/bin/bash
# Don't use set -e because we need to handle jq parsing errors gracefully
set +e

# =============================================================================
# Multi-Provider AI Fix Script
# =============================================================================
# This script supports multiple AI providers for fixing Angular dependency issues:
# - Claude (Anthropic API)
# - OpenAI (GPT-4, GPT-4-Turbo, GPT-3.5-Turbo)
# - GitHub Copilot (via GitHub Models API)
#
# Usage: ./apply-ai-fix.sh <project_path> <error_context_file> [output_file]
#
# Environment Variables:
#   AI_PROVIDER       - Provider to use: "claude", "openai", "copilot" (auto-detected if not set)
#   CLAUDE_API_KEY    - Anthropic API key (required for claude provider)
#   CLAUDE_MODEL      - Claude model (default: claude-sonnet-4-5)
#   OPENAI_API_KEY    - OpenAI API key (required for openai provider)
#   OPENAI_MODEL      - OpenAI model (default: gpt-4-turbo)
#   GITHUB_TOKEN      - GitHub token with Copilot access (required for copilot provider)
#   COPILOT_MODEL     - Copilot model (default: gpt-4o)
# =============================================================================

PROJECT_PATH=$1
ERROR_CONTEXT_FILE=$2
OUTPUT_FILE=${3:-/tmp/ai-fix.json}

# =============================================================================
# Input Validation
# =============================================================================
if [ -z "$PROJECT_PATH" ] || [ -z "$ERROR_CONTEXT_FILE" ]; then
    echo "Error: Missing required arguments" >&2
    echo "Usage: $0 <project_path> <error_context_file> [output_file]" >&2
    echo "" >&2
    echo "Environment Variables:" >&2
    echo "  AI_PROVIDER       - Provider: claude, openai, or copilot (auto-detected)" >&2
    echo "  CLAUDE_API_KEY    - Anthropic API key" >&2
    echo "  OPENAI_API_KEY    - OpenAI API key" >&2
    echo "  GITHUB_TOKEN      - GitHub token with Copilot access" >&2
    exit 1
fi

if [ ! -f "$ERROR_CONTEXT_FILE" ]; then
    echo "Error: Error context file does not exist: $ERROR_CONTEXT_FILE" >&2
    exit 1
fi

# Read error context BEFORE changing directory
ERROR_CONTEXT=$(cat "$ERROR_CONTEXT_FILE")

cd "$PROJECT_PATH"

# =============================================================================
# Provider Auto-Detection
# =============================================================================
detect_provider() {
    # If AI_PROVIDER is explicitly set, use it
    if [ -n "$AI_PROVIDER" ]; then
        echo "$AI_PROVIDER"
        return
    fi

    # Auto-detect based on available API keys (priority: claude > openai > copilot)
    if [ -n "$CLAUDE_API_KEY" ]; then
        echo "claude"
    elif [ -n "$OPENAI_API_KEY" ]; then
        echo "openai"
    elif [ -n "$GITHUB_TOKEN" ]; then
        echo "copilot"
    else
        echo ""
    fi
}

PROVIDER=$(detect_provider)

if [ -z "$PROVIDER" ]; then
    echo "Error: No AI provider configured. Set one of the following:" >&2
    echo "  - CLAUDE_API_KEY (for Claude/Anthropic)" >&2
    echo "  - OPENAI_API_KEY (for OpenAI)" >&2
    echo "  - GITHUB_TOKEN (for GitHub Copilot)" >&2
    echo "  Or explicitly set AI_PROVIDER=claude|openai|copilot" >&2
    exit 1
fi

echo "========================================" >&2
echo "Requesting AI Fix Suggestions..." >&2
echo "Provider: $PROVIDER" >&2
echo "Project: $PROJECT_PATH" >&2
echo "========================================" >&2

# =============================================================================
# Common Prompt Template
# =============================================================================
SYSTEM_PROMPT="You are an expert Angular developer. Analyze compilation and test errors, then provide specific fixes. Return ONLY a valid JSON array of file changes. Do not include any other text or markdown formatting."

USER_PROMPT="I have an Angular project with compilation and test errors after updating dependencies. Please analyze these errors and provide specific fixes.

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

# =============================================================================
# Claude (Anthropic) Provider
# =============================================================================
call_claude_api() {
    if [ -z "$CLAUDE_API_KEY" ]; then
        echo '{"success": false, "error": "CLAUDE_API_KEY not set"}' > "$OUTPUT_FILE"
        cat "$OUTPUT_FILE"
        exit 1
    fi

    local MODEL="${CLAUDE_MODEL:-claude-sonnet-4-5}"
    echo "Model: $MODEL" >&2

    REQUEST_BODY=$(jq -n \
      --arg model "$MODEL" \
      --arg system "$SYSTEM_PROMPT" \
      --arg prompt "$USER_PROMPT" \
      '{
        model: $model,
        max_tokens: 16000,
        system: $system,
        messages: [
          {
            role: "user",
            content: $prompt
          }
        ]
      }'
    )

    echo "Calling Claude API..." >&2

    API_RESPONSE=$(curl -s -X POST https://api.anthropic.com/v1/messages \
      -H "Content-Type: application/json" \
      -H "x-api-key: $CLAUDE_API_KEY" \
      -H "anthropic-version: 2023-06-01" \
      -d "$REQUEST_BODY")

    # Check for API error
    if echo "$API_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$API_RESPONSE" | jq -r '.error.message')
        echo "Error: Claude API returned an error: $ERROR_MSG" >&2
        echo "{\"success\": false, \"error\": \"$ERROR_MSG\", \"provider\": \"claude\", \"rawResponse\": $API_RESPONSE}" > "$OUTPUT_FILE"
        cat "$OUTPUT_FILE"
        exit 1
    fi

    # Extract content from Claude's response format
    CONTENT=$(echo "$API_RESPONSE" | jq -r '.content[0].text')
    echo "$CONTENT"
}

# =============================================================================
# OpenAI Provider
# =============================================================================
call_openai_api() {
    if [ -z "$OPENAI_API_KEY" ]; then
        echo '{"success": false, "error": "OPENAI_API_KEY not set"}' > "$OUTPUT_FILE"
        cat "$OUTPUT_FILE"
        exit 1
    fi

    local MODEL="${OPENAI_MODEL:-gpt-4-turbo}"
    echo "Model: $MODEL" >&2

    REQUEST_BODY=$(jq -n \
      --arg model "$MODEL" \
      --arg system "$SYSTEM_PROMPT" \
      --arg prompt "$USER_PROMPT" \
      '{
        model: $model,
        max_tokens: 16000,
        temperature: 0.2,
        messages: [
          {
            role: "system",
            content: $system
          },
          {
            role: "user",
            content: $prompt
          }
        ]
      }'
    )

    echo "Calling OpenAI API..." >&2

    API_RESPONSE=$(curl -s -X POST https://api.openai.com/v1/chat/completions \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $OPENAI_API_KEY" \
      -d "$REQUEST_BODY")

    # Check for API error
    if echo "$API_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$API_RESPONSE" | jq -r '.error.message')
        echo "Error: OpenAI API returned an error: $ERROR_MSG" >&2
        echo "{\"success\": false, \"error\": \"$ERROR_MSG\", \"provider\": \"openai\", \"rawResponse\": $API_RESPONSE}" > "$OUTPUT_FILE"
        cat "$OUTPUT_FILE"
        exit 1
    fi

    # Extract content from OpenAI's response format
    CONTENT=$(echo "$API_RESPONSE" | jq -r '.choices[0].message.content')
    echo "$CONTENT"
}

# =============================================================================
# GitHub Copilot Provider (via GitHub Models API)
# =============================================================================
call_copilot_api() {
    if [ -z "$GITHUB_TOKEN" ]; then
        echo '{"success": false, "error": "GITHUB_TOKEN not set for Copilot access"}' > "$OUTPUT_FILE"
        cat "$OUTPUT_FILE"
        exit 1
    fi

    # GitHub Copilot uses the GitHub Models API endpoint
    # Available models: gpt-4o, gpt-4o-mini, o1-preview, o1-mini
    local MODEL="${COPILOT_MODEL:-gpt-4o}"
    echo "Model: $MODEL" >&2

    REQUEST_BODY=$(jq -n \
      --arg model "$MODEL" \
      --arg system "$SYSTEM_PROMPT" \
      --arg prompt "$USER_PROMPT" \
      '{
        model: $model,
        max_tokens: 16000,
        temperature: 0.2,
        messages: [
          {
            role: "system",
            content: $system
          },
          {
            role: "user",
            content: $prompt
          }
        ]
      }'
    )

    echo "Calling GitHub Copilot API (via GitHub Models)..." >&2

    # GitHub Models API endpoint for Copilot
    API_RESPONSE=$(curl -s -X POST "https://models.inference.ai.azure.com/chat/completions" \
      -H "Content-Type: application/json" \
      -H "Authorization: Bearer $GITHUB_TOKEN" \
      -d "$REQUEST_BODY")

    # Check for API error
    if echo "$API_RESPONSE" | jq -e '.error' > /dev/null 2>&1; then
        ERROR_MSG=$(echo "$API_RESPONSE" | jq -r '.error.message // .error')
        echo "Error: GitHub Copilot API returned an error: $ERROR_MSG" >&2
        echo "{\"success\": false, \"error\": \"$ERROR_MSG\", \"provider\": \"copilot\", \"rawResponse\": $API_RESPONSE}" > "$OUTPUT_FILE"
        cat "$OUTPUT_FILE"
        exit 1
    fi

    # Extract content from OpenAI-compatible response format
    CONTENT=$(echo "$API_RESPONSE" | jq -r '.choices[0].message.content')
    echo "$CONTENT"
}

# =============================================================================
# Main Execution
# =============================================================================
case "$PROVIDER" in
    claude)
        CONTENT=$(call_claude_api)
        ;;
    openai)
        CONTENT=$(call_openai_api)
        ;;
    copilot)
        CONTENT=$(call_copilot_api)
        ;;
    *)
        echo "Error: Unknown provider '$PROVIDER'. Supported: claude, openai, copilot" >&2
        exit 1
        ;;
esac

# Check if we got content
if [ -z "$CONTENT" ] || [ "$CONTENT" == "null" ]; then
    echo "Error: No content received from AI provider" >&2
    echo "{\"success\": false, \"error\": \"No content received from AI provider\", \"provider\": \"$PROVIDER\"}" > "$OUTPUT_FILE"
    cat "$OUTPUT_FILE"
    exit 1
fi

# =============================================================================
# Response Parsing (common for all providers)
# =============================================================================
# Clean markdown code blocks if present
CONTENT_CLEAN=$(echo "$CONTENT" | sed 's/^```json//g' | sed 's/^```//g' | sed '/^$/d')
FIXES=$(echo "$CONTENT_CLEAN" | jq '.')

if [ $? -ne 0 ] || [ -z "$FIXES" ]; then
    echo "Error: Could not parse fixes from AI response" >&2
    echo "{\"success\": false, \"error\": \"Could not parse JSON from response\", \"provider\": \"$PROVIDER\", \"rawContent\": $(echo "$CONTENT" | jq -Rs .)}" > "$OUTPUT_FILE"
    cat "$OUTPUT_FILE"
    exit 1
fi

FIX_COUNT=$(echo "$FIXES" | jq 'length')

# Create output
cat > "$OUTPUT_FILE" <<EOF
{
  "success": true,
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "provider": "$PROVIDER",
  "projectPath": "$PROJECT_PATH",
  "fixes": $FIXES,
  "fixCount": $FIX_COUNT
}
EOF

echo "" >&2
echo "========================================" >&2
echo "AI analysis complete!" >&2
echo "Provider: $PROVIDER" >&2
echo "Fixes suggested: $FIX_COUNT" >&2
echo "Output saved to: $OUTPUT_FILE" >&2
echo "========================================" >&2

# Output to stdout for n8n
cat "$OUTPUT_FILE"

exit 0
