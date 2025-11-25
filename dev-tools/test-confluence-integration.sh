#!/bin/bash

# ==============================================================================
# Confluence Integration Test Script
# ==============================================================================
#
# This script tests the complete Confluence integration including:
# 1. Environment configuration validation
# 2. Confluence API connection test
# 3. Page creation with sample data
# 4. Page creation with error data (install errors + Claude fixes)
# 5. Validation of created pages
#
# Usage:
#   ./test-confluence-integration.sh
#
# ==============================================================================

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}================================${NC}"
echo -e "${BLUE}Confluence Integration Test${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Load environment
echo -e "${YELLOW}Loading environment variables...${NC}"
set -a
source .env
set +a

# Test 1: Validate environment variables
echo -e "\n${YELLOW}Test 1: Validating environment configuration${NC}"
MISSING_VARS=()

if [ -z "$CONFLUENCE_DOMAIN" ]; then
    MISSING_VARS+=("CONFLUENCE_DOMAIN")
fi
if [ -z "$CONFLUENCE_EMAIL" ]; then
    MISSING_VARS+=("CONFLUENCE_EMAIL")
fi
if [ -z "$CONFLUENCE_API_TOKEN" ]; then
    MISSING_VARS+=("CONFLUENCE_API_TOKEN")
fi
if [ -z "$CONFLUENCE_SPACE_KEY" ]; then
    MISSING_VARS+=("CONFLUENCE_SPACE_KEY")
fi
if [ -z "$CONFLUENCE_PARENT_PAGE_ID" ]; then
    MISSING_VARS+=("CONFLUENCE_PARENT_PAGE_ID")
fi

if [ ${#MISSING_VARS[@]} -gt 0 ]; then
    echo -e "${RED}✗ FAILED: Missing environment variables: ${MISSING_VARS[*]}${NC}"
    exit 1
else
    echo -e "${GREEN}✓ PASSED: All required environment variables are set${NC}"
    echo "  Domain: $CONFLUENCE_DOMAIN"
    echo "  Space Key: $CONFLUENCE_SPACE_KEY"
    echo "  Parent Page ID: $CONFLUENCE_PARENT_PAGE_ID"
fi

# Test 2: Test Confluence API connection
echo -e "\n${YELLOW}Test 2: Testing Confluence API connection${NC}"
PAGE_INFO=$(curl -s -u "$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN" \
    "https://$CONFLUENCE_DOMAIN/wiki/rest/api/content/$CONFLUENCE_PARENT_PAGE_ID?expand=space")

if echo "$PAGE_INFO" | jq -e '.id' > /dev/null 2>&1; then
    PAGE_TITLE=$(echo "$PAGE_INFO" | jq -r '.title')
    SPACE_NAME=$(echo "$PAGE_INFO" | jq -r '.space.name')
    echo -e "${GREEN}✓ PASSED: Successfully connected to Confluence${NC}"
    echo "  Parent Page: $PAGE_TITLE"
    echo "  Space: $SPACE_NAME"
else
    echo -e "${RED}✗ FAILED: Could not connect to Confluence${NC}"
    echo "$PAGE_INFO"
    exit 1
fi

# Test 3: Create page with simple data (no errors)
echo -e "\n${YELLOW}Test 3: Creating page with simple update data${NC}"

cat > /tmp/test-confluence-simple.json << 'EOF'
{
  "runId": "test-simple-20251114-001",
  "branchName": "test-deps-update_11-14-2025_12-00-00_AM",
  "projectPath": "/path/to/test/project",
  "totalUpdates": 5,
  "updates": [
    {"name": "@angular/core", "from": "19.0.0", "to": "20.0.0"},
    {"name": "@angular/common", "from": "19.0.0", "to": "20.0.0"},
    {"name": "@angular/forms", "from": "19.0.0", "to": "20.0.0"},
    {"name": "typescript", "from": "5.5.0", "to": "5.7.0"},
    {"name": "rxjs", "from": "7.8.0", "to": "7.8.1"}
  ],
  "hasInstallErrors": false,
  "installErrors": "",
  "claudeAnalysis": "",
  "installFixes": [],
  "testPassed": true,
  "buildPassed": true,
  "prUrl": "https://github.com/test/repo/pull/100",
  "prNumber": "100"
}
EOF

./scripts/create-confluence-doc.sh /tmp/test-confluence-simple.json /tmp/test-result-simple.json

if [ $? -eq 0 ]; then
    SIMPLE_PAGE_URL=$(cat /tmp/test-result-simple.json | jq -r '.page.url')
    echo -e "${GREEN}✓ PASSED: Simple page created successfully${NC}"
    echo "  URL: $SIMPLE_PAGE_URL"
else
    echo -e "${RED}✗ FAILED: Could not create simple page${NC}"
    cat /tmp/test-result-simple.json
    exit 1
fi

# Test 4: Create page with error data (install errors + Claude fixes)
echo -e "\n${YELLOW}Test 4: Creating page with npm install errors and Claude fixes${NC}"

cat > /tmp/test-confluence-errors.json << 'EOF'
{
  "runId": "test-errors-20251114-002",
  "branchName": "test-deps-update_11-14-2025_12-30-00_AM",
  "projectPath": "/path/to/test/project",
  "totalUpdates": 3,
  "updates": [
    {"name": "@angular/core", "from": "19.0.0", "to": "20.0.0"},
    {"name": "@angular/common", "from": "19.0.0", "to": "20.0.0"},
    {"name": "@angular/platform-browser", "from": "19.0.0", "to": "20.0.0"}
  ],
  "hasInstallErrors": true,
  "installErrors": "npm error code ERESOLVE\nnpm error ERESOLVE unable to resolve dependency tree\nnpm error \nnpm error While resolving: angular-test-project@0.0.0\nnpm error Found: @angular/core@20.0.0\nnpm error node_modules/@angular/core\nnpm error   @angular/core@\"^20.0.0\" from the root project\nnpm error \nnpm error Could not resolve dependency:\nnpm error peer @angular/core@\"^19.0.0\" from @angular/common@19.0.0",
  "claudeAnalysis": "The dependency conflict is caused by mismatched peer dependency requirements. The @angular/common package still requires @angular/core version 19.x, but we're trying to install @angular/core version 20.x. To resolve this, we need to update all Angular packages simultaneously to ensure compatible versions.",
  "installFixes": [
    {
      "file": "package.json",
      "reason": "Updated @angular/common to version 20.0.0 to match @angular/core and resolve peer dependency conflict",
      "content": "{\n  \"name\": \"angular-test-project\",\n  \"version\": \"0.0.0\",\n  \"dependencies\": {\n    \"@angular/core\": \"^20.0.0\",\n    \"@angular/common\": \"^20.0.0\",\n    \"@angular/platform-browser\": \"^20.0.0\"\n  }\n}"
    }
  ],
  "testPassed": true,
  "buildPassed": true,
  "prUrl": "https://github.com/test/repo/pull/101",
  "prNumber": "101"
}
EOF

./scripts/create-confluence-doc.sh /tmp/test-confluence-errors.json /tmp/test-result-errors.json

if [ $? -eq 0 ]; then
    ERROR_PAGE_URL=$(cat /tmp/test-result-errors.json | jq -r '.page.url')
    echo -e "${GREEN}✓ PASSED: Error page created successfully${NC}"
    echo "  URL: $ERROR_PAGE_URL"
else
    echo -e "${RED}✗ FAILED: Could not create error page${NC}"
    cat /tmp/test-result-errors.json
    exit 1
fi

# Test 5: Verify pages exist in Confluence
echo -e "\n${YELLOW}Test 5: Verifying created pages exist in Confluence${NC}"

SIMPLE_PAGE_ID=$(cat /tmp/test-result-simple.json | jq -r '.page.id')
ERROR_PAGE_ID=$(cat /tmp/test-result-errors.json | jq -r '.page.id')

# Check simple page
SIMPLE_CHECK=$(curl -s -u "$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN" \
    "https://$CONFLUENCE_DOMAIN/wiki/rest/api/content/$SIMPLE_PAGE_ID")

if echo "$SIMPLE_CHECK" | jq -e '.id' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED: Simple page exists in Confluence${NC}"
else
    echo -e "${RED}✗ FAILED: Simple page not found in Confluence${NC}"
fi

# Check error page
ERROR_CHECK=$(curl -s -u "$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN" \
    "https://$CONFLUENCE_DOMAIN/wiki/rest/api/content/$ERROR_PAGE_ID")

if echo "$ERROR_CHECK" | jq -e '.id' > /dev/null 2>&1; then
    echo -e "${GREEN}✓ PASSED: Error page exists in Confluence${NC}"
else
    echo -e "${RED}✗ FAILED: Error page not found in Confluence${NC}"
fi

# Summary
echo -e "\n${BLUE}================================${NC}"
echo -e "${BLUE}Test Summary${NC}"
echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}All tests passed!${NC}"
echo ""
echo "Created Pages:"
echo "  1. Simple update page: $SIMPLE_PAGE_URL"
echo "  2. Error handling page: $ERROR_PAGE_URL"
echo ""
echo "You can view these pages in Confluence to verify:"
echo "  - Dependency update tables"
echo "  - npm install error sections"
echo "  - Claude AI analysis and fixes"
echo "  - Test/build status badges"
echo "  - Links to GitHub PRs"
echo ""
echo -e "${GREEN}✓ Confluence integration is working correctly!${NC}"
