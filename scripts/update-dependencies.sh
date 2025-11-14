#!/bin/bash
set -e

# Script to run npm-check-updates and capture dependency information
# Usage: ./update-dependencies.sh <project_path> [output_file]

PROJECT_PATH=$1
OUTPUT_FILE=${2:-/tmp/ncu-output.json}

if [ -z "$PROJECT_PATH" ]; then
    echo "Error: Project path is required"
    echo "Usage: $0 <project_path> [output_file]"
    exit 1
fi

if [ ! -d "$PROJECT_PATH" ]; then
    echo "Error: Project path does not exist: $PROJECT_PATH"
    exit 1
fi

if [ ! -f "$PROJECT_PATH/package.json" ]; then
    echo "Error: package.json not found in $PROJECT_PATH"
    exit 1
fi

cd "$PROJECT_PATH"

echo "========================================" >&2
echo "Running npm-check-updates analysis..." >&2
echo "Project: $PROJECT_PATH" >&2
echo "========================================" >&2

# Get current versions
CURRENT_VERSIONS=$(cat package.json | jq '{dependencies, devDependencies}')

# Run npm-check-updates with JSON output
echo "Checking for updates..." >&2
NCU_OUTPUT=$(ncu --jsonUpgraded --target latest 2>&1 || true)

# Parse the JSON output
if echo "$NCU_OUTPUT" | jq empty 2>/dev/null; then
    UPGRADES=$(echo "$NCU_OUTPUT" | jq '.')
else
    # If ncu returns non-JSON (no updates), create empty object
    UPGRADES="{}"
fi

# Count updates
UPDATE_COUNT=$(echo "$UPGRADES" | jq 'length')

# Create detailed report
ncu --format group > /tmp/ncu-report.txt 2>&1 || echo "No updates available" > /tmp/ncu-report.txt

# Convert upgrades object to array format for easier consumption
# Format: [{name: "package", from: "1.0.0", to: "2.0.0"}]
UPGRADES_ARRAY=$(echo "$UPGRADES" | jq -r 'to_entries | map({name: .key, to: .value}) | .[]' | \
  jq -s '.' | \
  jq --argjson current "$CURRENT_VERSIONS" '
    map(
      . as $upgrade |
      {
        name: .name,
        from: (
          ($current.dependencies // {})[$upgrade.name] //
          ($current.devDependencies // {})[$upgrade.name] //
          "unknown"
        ),
        to: .to
      }
    )
  ')

# Create comprehensive JSON output
cat > "$OUTPUT_FILE" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "projectPath": "$PROJECT_PATH",
  "currentVersions": $CURRENT_VERSIONS,
  "upgrades": $UPGRADES_ARRAY,
  "totalUpdates": $UPDATE_COUNT,
  "hasUpdates": $([ $UPDATE_COUNT -gt 0 ] && echo "true" || echo "false"),
  "detailedReport": $(cat /tmp/ncu-report.txt | jq -Rs .)
}
EOF

echo "" >&2
echo "========================================" >&2
echo "Analysis complete!" >&2
echo "Total updates available: $UPDATE_COUNT" >&2
echo "Output saved to: $OUTPUT_FILE" >&2
echo "========================================" >&2

# Output the JSON to stdout for n8n to capture
cat "$OUTPUT_FILE"

exit 0
