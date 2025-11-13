#!/bin/bash
set +e

# Script to validate all changes after fixes
# Usage: ./validate-changes.sh <project_path> [output_file]

PROJECT_PATH=$1
VALIDATION_OUTPUT=${2:-/tmp/validation-result.json}

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
echo "Validating Changes..." >&2
echo "Project: $PROJECT_PATH" >&2
echo "========================================" >&2

# Create temp files
LINT_LOG="/tmp/lint-output-$(date +%s).log"
TEST_LOG="/tmp/final-test-$(date +%s).log"
BUILD_LOG="/tmp/final-build-$(date +%s).log"

# Run linting (optional, may not exist in all projects)
echo "Running linting..." >&2
if ng lint > "$LINT_LOG" 2>&1; then
    LINT_EXIT=0
    echo "✓ Linting passed" >&2
else
    LINT_EXIT=$?
    echo "✗ Linting failed (exit code: $LINT_EXIT)" >&2
fi

# Run tests
# Set Chrome binary to Brave Browser
export CHROME_BIN="/Applications/Brave Browser.app/Contents/MacOS/Brave Browser"
echo "Running tests..." >&2
if ng test --watch=false --browsers=ChromeHeadless > "$TEST_LOG" 2>&1; then
    TEST_EXIT=0
    echo "✓ Tests passed" >&2
else
    TEST_EXIT=$?
    echo "✗ Tests failed (exit code: $TEST_EXIT)" >&2
fi

# Run production build
echo "Running production build..." >&2
if ng build --configuration production > "$BUILD_LOG" 2>&1; then
    BUILD_EXIT=0
    echo "✓ Build passed" >&2
else
    BUILD_EXIT=$?
    echo "✗ Build failed (exit code: $BUILD_EXIT)" >&2
fi

# Calculate overall success
if [ $LINT_EXIT -eq 0 ] && [ $TEST_EXIT -eq 0 ] && [ $BUILD_EXIT -eq 0 ]; then
    SUCCESS=true
    OVERALL_STATUS="success"
else
    SUCCESS=false
    OVERALL_STATUS="failure"
fi

# Extract warnings and errors
extract_summary() {
    local log_file=$1
    tail -n 20 "$log_file" | grep -E "(Error|Warning|Failed|Passed|Success)" || echo "See full log for details"
}

# Create validation result JSON
cat > "$VALIDATION_OUTPUT" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "projectPath": "$PROJECT_PATH",
  "success": $SUCCESS,
  "status": "$OVERALL_STATUS",
  "lint": {
    "exitCode": $LINT_EXIT,
    "passed": $([ $LINT_EXIT -eq 0 ] && echo "true" || echo "false"),
    "output": $(cat "$LINT_LOG" | jq -Rs .),
    "summary": $(extract_summary "$LINT_LOG" | jq -Rs .)
  },
  "test": {
    "exitCode": $TEST_EXIT,
    "passed": $([ $TEST_EXIT -eq 0 ] && echo "true" || echo "false"),
    "output": $(cat "$TEST_LOG" | jq -Rs .),
    "summary": $(extract_summary "$TEST_LOG" | jq -Rs .)
  },
  "build": {
    "exitCode": $BUILD_EXIT,
    "passed": $([ $BUILD_EXIT -eq 0 ] && echo "true" || echo "false"),
    "output": $(cat "$BUILD_LOG" | jq -Rs .),
    "summary": $(extract_summary "$BUILD_LOG" | jq -Rs .)
  }
}
EOF

echo "" >&2
echo "========================================" >&2
echo "Validation complete!" >&2
echo "Overall status: $OVERALL_STATUS" >&2
echo "  - Linting: $([ $LINT_EXIT -eq 0 ] && echo '✓ PASSED' || echo '✗ FAILED')" >&2
echo "  - Tests: $([ $TEST_EXIT -eq 0 ] && echo '✓ PASSED' || echo '✗ FAILED')" >&2
echo "  - Build: $([ $BUILD_EXIT -eq 0 ] && echo '✓ PASSED' || echo '✗ FAILED')" >&2
echo "Output saved to: $VALIDATION_OUTPUT" >&2
echo "========================================" >&2

# Output to stdout for n8n
cat "$VALIDATION_OUTPUT"

# Cleanup temp files
rm -f "$LINT_LOG" "$TEST_LOG" "$BUILD_LOG"

# Exit with combined error code
exit $(($LINT_EXIT + $TEST_EXIT + $BUILD_EXIT))
