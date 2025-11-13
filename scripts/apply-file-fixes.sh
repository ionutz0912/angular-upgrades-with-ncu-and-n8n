#!/bin/bash
set -e

# Script to apply file fixes from Claude response
# Usage: ./apply-file-fixes.sh <project_path> <fixes_json_file>

PROJECT_PATH=$1
FIXES_JSON_FILE=$2

if [ -z "$PROJECT_PATH" ] || [ -z "$FIXES_JSON_FILE" ]; then
    echo "Error: Missing required arguments"
    echo "Usage: $0 <project_path> <fixes_json_file>"
    exit 1
fi

if [ ! -f "$FIXES_JSON_FILE" ]; then
    echo "Error: Fixes JSON file does not exist: $FIXES_JSON_FILE"
    exit 1
fi

cd "$PROJECT_PATH"

echo "========================================" >&2
echo "Applying File Fixes..." >&2
echo "Project: $PROJECT_PATH" >&2
echo "========================================" >&2

# Read fixes array
FIXES=$(cat "$FIXES_JSON_FILE" | jq -r '.fixes')
FIX_COUNT=$(echo "$FIXES" | jq 'length')

echo "Total fixes to apply: $FIX_COUNT" >&2

if [ "$FIX_COUNT" -eq 0 ]; then
    echo "No fixes to apply" >&2
    exit 0
fi

# Track applied fixes
APPLIED=0
FAILED=0

# Iterate through each fix
for i in $(seq 0 $(($FIX_COUNT - 1))); do
    FILE=$(echo "$FIXES" | jq -r ".[$i].file")
    CONTENT=$(echo "$FIXES" | jq -r ".[$i].content")
    REASON=$(echo "$FIXES" | jq -r ".[$i].reason")

    echo "" >&2
    echo "[$((i+1))/$FIX_COUNT] Applying fix to: $FILE" >&2
    echo "Reason: $REASON" >&2

    # Create directory if it doesn't exist
    FILE_DIR=$(dirname "$FILE")
    if [ ! -d "$FILE_DIR" ]; then
        echo "Creating directory: $FILE_DIR" >&2
        mkdir -p "$FILE_DIR"
    fi

    # Backup original file if it exists
    if [ -f "$FILE" ]; then
        BACKUP_FILE="${FILE}.backup.$(date +%s)"
        cp "$FILE" "$BACKUP_FILE"
        echo "Backup created: $BACKUP_FILE" >&2
    fi

    # Write the new content
    echo "$CONTENT" > "$FILE"

    if [ $? -eq 0 ]; then
        echo "✓ Successfully applied fix to $FILE" >&2
        APPLIED=$((APPLIED + 1))
    else
        echo "✗ Failed to apply fix to $FILE" >&2
        FAILED=$((FAILED + 1))

        # Restore backup if write failed and backup exists
        if [ -f "$BACKUP_FILE" ]; then
            mv "$BACKUP_FILE" "$FILE"
            echo "Restored backup for $FILE" >&2
        fi
    fi
done

echo "" >&2
echo "========================================" >&2
echo "File fixes application complete!" >&2
echo "Successfully applied: $APPLIED" >&2
echo "Failed: $FAILED" >&2
echo "========================================" >&2

if [ $FAILED -gt 0 ]; then
    exit 1
fi

exit 0
