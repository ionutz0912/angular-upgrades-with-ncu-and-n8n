#!/bin/bash

# ==============================================================================
# Cleanup Confluence Test Pages
# ==============================================================================
#
# This script deletes test Confluence pages created during testing
#
# Usage:
#   ./cleanup-confluence-test-pages.sh
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
echo -e "${BLUE}Confluence Test Pages Cleanup${NC}"
echo -e "${BLUE}================================${NC}"
echo ""

# Load environment
set -a
source .env
set +a

# Test page IDs (from our test runs)
TEST_PAGES=(
    "819202"   # Original workflow run
    "884738"   # Simple test page
    "786434"   # Error test page
    "1146881"  # Demo with real updates
)

echo -e "${YELLOW}Found ${#TEST_PAGES[@]} test pages to delete${NC}"
echo ""

for PAGE_ID in "${TEST_PAGES[@]}"; do
    echo -e "${YELLOW}Deleting page ID: $PAGE_ID${NC}"

    RESPONSE=$(curl -s -w "\n%{http_code}" -X DELETE \
        -u "$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN" \
        "https://$CONFLUENCE_DOMAIN/wiki/rest/api/content/$PAGE_ID")

    HTTP_CODE=$(echo "$RESPONSE" | tail -n1)

    if [ "$HTTP_CODE" = "204" ] || [ "$HTTP_CODE" = "200" ]; then
        echo -e "${GREEN}✓ Deleted page $PAGE_ID${NC}"
    elif [ "$HTTP_CODE" = "404" ]; then
        echo -e "${YELLOW}⚠ Page $PAGE_ID already deleted or doesn't exist${NC}"
    else
        echo -e "${RED}✗ Failed to delete page $PAGE_ID (HTTP $HTTP_CODE)${NC}"
    fi

    echo ""
done

echo -e "${BLUE}================================${NC}"
echo -e "${GREEN}Cleanup complete!${NC}"
echo ""
echo "You can now run the workflow again to see new pages created."
echo ""
