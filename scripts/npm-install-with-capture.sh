#!/bin/bash
set +e  # Don't exit on error, we want to capture failures

# Script to run npm install and capture dependency resolution errors
# Usage: ./npm-install-with-capture.sh <project_path> [output_file]

PROJECT_PATH=$1
OUTPUT_FILE=${2:-/tmp/npm-install-output.json}

if [ -z "$PROJECT_PATH" ]; then
    echo "Error: Project path is required"
    echo "Usage: $0 <project_path> [output_file]"
    exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Project path does not exist: $PROJECT_PATH"
    exit 1
fi

cd "$PROJECT_PATH"

echo "========================================" >&2
echo "Running npm install..." >&2
echo "Project: $PROJECT_PATH" >&2
echo "========================================" >&2

# Create temp file for output
INSTALL_LOG="/tmp/npm-install-$(date +%s).log"

# Run npm install with legacy peer deps (common fix for Angular)
echo "Attempting: npm install --legacy-peer-deps" >&2
npm install --legacy-peer-deps > "$INSTALL_LOG" 2>&1
INSTALL_EXIT_CODE=$?

echo "npm install exit code: $INSTALL_EXIT_CODE" >&2

# Extract dependency errors
extract_dependency_errors() {
    local log_file=$1
    # Look for ERESOLVE, peer dependency conflicts, version conflicts
    grep -A 10 -E "(ERESOLVE|Could not resolve|Conflicting peer dependency|Fix the upstream dependency conflict|peer typescript)" "$log_file" || echo ""
}

DEPENDENCY_ERRORS=$(extract_dependency_errors "$INSTALL_LOG")

# Get full install output for context
FULL_OUTPUT=$(cat "$INSTALL_LOG")

# Determine status
if [ $INSTALL_EXIT_CODE -eq 0 ]; then
    OVERALL_STATUS="success"
    HAS_ERRORS=false
else
    OVERALL_STATUS="failure"
    HAS_ERRORS=true
fi

# Create JSON output with detailed error information
cat > "$OUTPUT_FILE" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "projectPath": "$PROJECT_PATH",
  "status": "$OVERALL_STATUS",
  "hasErrors": $HAS_ERRORS,
  "install": {
    "exitCode": $INSTALL_EXIT_CODE,
    "passed": $([ $INSTALL_EXIT_CODE -eq 0 ] && echo "true" || echo "false"),
    "command": "npm install --legacy-peer-deps",
    "output": $(echo "$FULL_OUTPUT" | jq -Rs .),
    "dependencyErrors": $(echo "$DEPENDENCY_ERRORS" | jq -Rs .)
  }
}
EOF

echo "" >&2
echo "========================================" >&2
echo "npm install complete!" >&2
echo "Status: $OVERALL_STATUS" >&2
echo "Output saved to: $OUTPUT_FILE" >&2
echo "========================================" >&2

# Output the JSON to stdout for n8n
cat "$OUTPUT_FILE"

# Cleanup temp file
rm -f "$INSTALL_LOG"

# Exit with install exit code
exit $INSTALL_EXIT_CODE
