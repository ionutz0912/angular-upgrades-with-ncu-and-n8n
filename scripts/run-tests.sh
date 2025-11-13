#!/bin/bash
set +e  # Don't exit on error, we want to capture failures

# Script to run Angular tests and build, capturing all errors
# Usage: ./run-tests.sh <project_path> [output_file]

PROJECT_PATH=$1
OUTPUT_FILE=${2:-/tmp/test-output.json}

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
echo "Running Angular Tests and Build..." >&2
echo "Project: $PROJECT_PATH" >&2
echo "========================================" >&2

# Create temp files for output
TEST_LOG="/tmp/test-output-$(date +%s).log"
BUILD_LOG="/tmp/build-output-$(date +%s).log"

# Run tests with JSON reporter
# Set Chrome binary to Brave Browser
export CHROME_BIN="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
echo "Running tests..." >&2
ng test --watch=false --code-coverage --browsers=ChromeHeadless > "$TEST_LOG" 2>&1
TEST_EXIT_CODE=$?

echo "Test exit code: $TEST_EXIT_CODE" >&2

# Run build to check for compilation errors
echo "Running production build..." >&2
ng build --configuration production > "$BUILD_LOG" 2>&1
BUILD_EXIT_CODE=$?

echo "Build exit code: $BUILD_EXIT_CODE" >&2

# Extract specific errors from logs
extract_errors() {
    local log_file=$1
    grep -E "(Error:|ERROR|Failed|FAILED|✖|×)" "$log_file" || echo "No specific errors found"
}

TEST_ERRORS=$(extract_errors "$TEST_LOG")
BUILD_ERRORS=$(extract_errors "$BUILD_LOG")

# Determine overall status
if [ $TEST_EXIT_CODE -eq 0 ] && [ $BUILD_EXIT_CODE -eq 0 ]; then
    OVERALL_STATUS="success"
    HAS_ERRORS=false
else
    OVERALL_STATUS="failure"
    HAS_ERRORS=true
fi

# Create JSON output
cat > "$OUTPUT_FILE" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "projectPath": "$PROJECT_PATH",
  "status": "$OVERALL_STATUS",
  "hasErrors": $HAS_ERRORS,
  "test": {
    "exitCode": $TEST_EXIT_CODE,
    "passed": $([ $TEST_EXIT_CODE -eq 0 ] && echo "true" || echo "false"),
    "output": $(cat "$TEST_LOG" | jq -Rs .),
    "errors": $(echo "$TEST_ERRORS" | jq -Rs .)
  },
  "build": {
    "exitCode": $BUILD_EXIT_CODE,
    "passed": $([ $BUILD_EXIT_CODE -eq 0 ] && echo "true" || echo "false"),
    "output": $(cat "$BUILD_LOG" | jq -Rs .),
    "errors": $(echo "$BUILD_ERRORS" | jq -Rs .)
  }
}
EOF

echo "" >&2
echo "========================================" >&2
echo "Tests and build complete!" >&2
echo "Overall status: $OVERALL_STATUS" >&2
echo "Output saved to: $OUTPUT_FILE" >&2
echo "========================================" >&2

# Output the JSON to stdout for n8n
cat "$OUTPUT_FILE"

# Cleanup temp files
rm -f "$TEST_LOG" "$BUILD_LOG"

# Exit with combined error code
exit $(($TEST_EXIT_CODE + $BUILD_EXIT_CODE))
