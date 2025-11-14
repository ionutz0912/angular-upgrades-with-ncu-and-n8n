# Confluence Integration Guide

Complete guide for setting up and using the Confluence documentation integration for Angular dependency automation.

## Overview

The Confluence integration automatically creates comprehensive documentation pages for each dependency update run, including:
- Dependency update summary with version changes
- npm install errors and dependency conflicts
- Claude AI analysis and fix solutions
- Test and build validation results
- Links to GitHub Pull Requests

## Prerequisites

1. **Confluence Cloud Account** with API access
2. **Confluence API Token** (see setup below)
3. **Parent Page** in Confluence where documentation will be created

## Quick Setup

### Step 1: Get Confluence API Token

1. Go to [https://id.atlassian.com/manage-profile/security/api-tokens](https://id.atlassian.com/manage-profile/security/api-tokens)
2. Click **"Create API token"**
3. Enter label: `n8n Dependency Automation`
4. Click **"Create"** and copy the token immediately

### Step 2: Find Your Parent Page ID

**Method 1: From Page Information**
1. Navigate to your Confluence page
2. Click "..." menu → **"Page Information"**
3. Look at the URL: `https://yourcompany.atlassian.net/wiki/pages/viewinfo.action?pageId=123456789`
4. The page ID is: `123456789`

**Method 2: From Modern URL**
1. Open your Confluence page
2. Look at the URL: `https://yourcompany.atlassian.net/wiki/spaces/~xxx/pages/327682/Page+Title`
3. The number after `/pages/` is your page ID: `327682`

**Method 3: Using REST API (Most Reliable)**
```bash
# Load environment
set -a && source .env && set +a

# Find your parent page by title
curl -s -u "$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN" \
  "https://$CONFLUENCE_DOMAIN/wiki/rest/api/space/${CONFLUENCE_SPACE_KEY}/content/page?limit=50" \
  | jq -r '.results[] | "\(.id) - \(.title)"'

# To find ancestors of a known page
curl -s -u "$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN" \
  "https://$CONFLUENCE_DOMAIN/wiki/rest/api/content/PAGE_ID?expand=ancestors" \
  | jq -r '.ancestors[] | "\(.id) - \(.title)"'
```

### Step 3: Configure Environment Variables

Add to your `.env` file:

```bash
# Confluence Configuration
CONFLUENCE_DOMAIN=yourcompany.atlassian.net
CONFLUENCE_EMAIL=your-email@company.com
CONFLUENCE_API_TOKEN=ATATT3xFfGF0...  # Token from Step 1
CONFLUENCE_SPACE_KEY=DEV               # Your space key (e.g., DEV, TECH)
CONFLUENCE_PARENT_PAGE_ID=123456789    # Page ID from Step 2
```

### Step 4: Test Confluence Connection

Create a test data file:

```bash
cat > /tmp/confluence-test-data.json << 'EOF'
{
  "runId": "test-20251113-120000",
  "branchName": "test-deps-update_11-13-2025_12-00-00_PM",
  "projectPath": "/path/to/project",
  "totalUpdates": 3,
  "updates": [
    {"name": "@angular/core", "from": "19.0.0", "to": "20.0.0"},
    {"name": "@angular/common", "from": "19.0.0", "to": "20.0.0"},
    {"name": "typescript", "from": "5.5.0", "to": "5.7.0"}
  ],
  "hasInstallErrors": false,
  "testPassed": true,
  "buildPassed": true,
  "prUrl": "https://github.com/yourorg/yourrepo/pull/123",
  "prNumber": "123"
}
EOF
```

Run the test:

```bash
# Load environment variables
set -a && source .env && set +a

# Test Confluence documentation creation
./scripts/create-confluence-doc.sh /tmp/confluence-test-data.json /tmp/confluence-result.json

# Check result
cat /tmp/confluence-result.json
```

Expected output:
```json
{
  "success": true,
  "page": {
    "id": "987654321",
    "url": "https://yourcompany.atlassian.net/wiki/spaces/DEV/pages/987654321",
    "title": "Dependency Update - test-20251113-120000"
  },
  "timestamp": "2025-11-13 12:00:00 UTC"
}
```

## Using the Full Automation Workflow

### Import the Workflow

1. Open n8n: `http://localhost:5678`
2. Click **"Import from File"**
3. Select: `workflows/dependency-update-with-pr-and-confluence.json`
4. Click **"Import"**

### Configure the Workflow

The workflow uses environment variables automatically. Ensure `.env` contains:
- All Confluence variables (from Step 3)
- All GitHub variables (`GITHUB_TOKEN`, `GITHUB_REPO_OWNER`, `GITHUB_REPO_NAME`)
- Claude API key (`CLAUDE_API_KEY`)

### Execute the Workflow

1. In n8n UI, select the imported workflow
2. Click **"Execute Workflow"** button
3. Monitor execution in real-time
4. Check final node "Parse Confluence Response" for Confluence page URL

## Workflow Execution Flow with Confluence

The full workflow (`dependency-update-with-pr-and-confluence.json`) executes 22 steps:

**Steps 1-14**: Core dependency update and npm install fix loop
**Steps 15-18**: GitHub PR creation
**Steps 19-22**: Confluence documentation

### Confluence-Specific Steps:

**Step 19: Prepare Confluence Data**
- Collects all workflow data from previous nodes
- Extracts dependency updates, install errors, Claude fixes
- Gathers test/build results and PR information
- Formats data for Confluence template

**Step 20: Save Confluence Data JSON**
- Writes structured data to `/tmp/confluence-data.json`
- Used as input for documentation script

**Step 21: Create Confluence Doc**
- Calls `create-confluence-doc.sh` script
- Generates Confluence page from template
- Creates page via Confluence REST API
- Returns page ID and URL

**Step 22: Parse Confluence Response**
- Extracts Confluence page details
- Validates successful page creation
- Logs page URL for reference

## Confluence Page Structure

The generated Confluence page includes:

### Summary Section
- Run ID and timestamp
- Branch name
- Project path
- Total updates count
- npm install status (color-coded)
- Overall status (PASSED/FAILED)

### Dependencies Updated Table
- Package name
- From version → To version
- Change type (MAJOR/MINOR/PATCH)
- Color-coded status badges

### npm Install Errors Section (if errors occurred)
- Dependency conflict errors (code block)
- Claude AI analysis
- Fix-by-fix breakdown:
  - File affected
  - Reason for fix
  - Complete file content (code block)
- Resolution strategy summary

### Test & Validation Results
- Unit tests status
- Production build status
- Color-coded PASSED/FAILED badges

### Related Links
- GitHub Pull Request (clickable link)
- Branch name
- Repository information

## Confluence Template Customization

The template is located at: `confluence-templates/update-page-template.html`

### Confluence Storage Format

Uses Confluence-specific HTML markup:

**Status Macros**:
```html
<ac:structured-macro ac:name="status">
  <ac:parameter ac:name="colour">Green</ac:parameter>
  <ac:parameter ac:name="title">PASSED</ac:parameter>
</ac:structured-macro>
```

**Code Blocks**:
```html
<ac:structured-macro ac:name="code">
  <ac:parameter ac:name="language">json</ac:parameter>
  <ac:parameter ac:name="title">package.json</ac:parameter>
  <ac:plain-text-body><![CDATA[
    { "code": "here" }
  ]]></ac:plain-text-body>
</ac:structured-macro>
```

**Info/Warning Panels**:
```html
<ac:structured-macro ac:name="warning">
  <ac:rich-text-body>
    <p>Warning message here</p>
  </ac:rich-text-body>
</ac:structured-macro>
```

### Customization Examples

**Add Custom Section**:
```html
<h2>📋 Additional Notes</h2>
<p>Custom content goes here</p>
```

**Modify Color Scheme**:
- `Green` → Success
- `Red` → Failure
- `Yellow` → Warning/Fixed
- `Blue` → Info

**Add Custom Metadata**:
Edit the script `create-confluence-doc.sh` to pass additional data to the template.

## Troubleshooting

### Error: 401 Unauthorized

**Cause**: Invalid API token or email

**Solution**:
1. Verify `CONFLUENCE_EMAIL` matches your Atlassian account email
2. Generate a new API token
3. Ensure token is correctly copied (no extra spaces)

```bash
# Test authentication
curl -u "$CONFLUENCE_EMAIL:$CONFLUENCE_API_TOKEN" \
  "https://$CONFLUENCE_DOMAIN/wiki/rest/api/content?limit=1"
```

### Error: 403 Forbidden

**Cause**: Insufficient permissions

**Solution**:
1. Verify you have "Can Add" permissions in the space
2. Check parent page exists and is accessible
3. Ensure your user can create pages in that space

### Error: 400 Bad Request

**Cause**: Invalid data or duplicate title

**Solution**:
1. Check JSON structure in `/tmp/confluence-data.json`
2. Verify parent page ID is correct
3. Ensure page title is unique (includes timestamp)
4. Check space key matches your Confluence space

### Pages Not Appearing

**Cause**: Wrong parent page or space

**Solution**:
1. Verify `CONFLUENCE_PARENT_PAGE_ID` in `.env`
2. Check `CONFLUENCE_SPACE_KEY` matches your space
3. Look in space's page tree for created pages
4. Search by run ID in Confluence

### Error: Connection Timeout

**Cause**: Network issues or firewall

**Solution**:
1. Check internet connection
2. Verify Confluence domain is accessible
3. Test with curl:
   ```bash
   curl -I "https://$CONFLUENCE_DOMAIN/wiki"
   ```

## Best Practices

### Documentation Organization

1. **Create a Dedicated Parent Page**
   - Title: "Automated Dependency Updates"
   - Add table of contents macro
   - Set up page labels for filtering

2. **Use Consistent Naming**
   - Run IDs include timestamp
   - Makes pages easy to find chronologically
   - Search by branch name or date

3. **Regular Cleanup**
   - Archive old update pages after merging
   - Keep last 10-20 runs for reference
   - Create quarterly summary pages

### Performance Optimization

1. **Rate Limiting**
   - Confluence API: 200 requests/minute
   - Script includes proper throttling
   - Avoid manual API calls during workflow execution

2. **Page Size**
   - Template generates ~10-50KB per page
   - Large error outputs may increase size
   - Confluence handles pages up to 1MB

### Security Considerations

1. **API Token Security**
   - Never commit `.env` file
   - Rotate tokens every 90 days
   - Use minimum required permissions

2. **Sensitive Data**
   - Review error messages for secrets
   - Script sanitizes some output
   - Consider additional filtering for production

## Advanced Configuration

### Multiple Projects

To document multiple Angular projects:

1. Create separate parent pages in Confluence
2. Duplicate workflow in n8n
3. Edit "Prepare Confluence Data" node
4. Update `CONFLUENCE_PARENT_PAGE_ID` for each workflow

### Custom Page Templates

Create project-specific templates:

1. Copy `confluence-templates/update-page-template.html`
2. Modify structure and styling
3. Update `create-confluence-doc.sh` to use new template
4. Pass template path as script parameter

### Automated Cleanup

Add cleanup node to workflow:

```javascript
// Delete Confluence pages older than 30 days
const deleteOldPages = async () => {
  const cutoffDate = new Date();
  cutoffDate.setDate(cutoffDate.getDate() - 30);

  // Call Confluence API to find and delete old pages
  // Implementation details...
};
```

## API Reference

### Confluence REST API Endpoints

**Create Page**:
```
POST https://{domain}/wiki/rest/api/content
```

**Get Page**:
```
GET https://{domain}/wiki/rest/api/content/{pageId}
```

**Update Page**:
```
PUT https://{domain}/wiki/rest/api/content/{pageId}
```

**Delete Page**:
```
DELETE https://{domain}/wiki/rest/api/content/{pageId}
```

### Script Parameters

**create-confluence-doc.sh**:
```bash
Usage: ./create-confluence-doc.sh <workflow_data_json> <output_json>

Arguments:
  workflow_data_json - Path to JSON with workflow data
  output_json       - Path for result JSON

Environment Variables:
  CONFLUENCE_DOMAIN
  CONFLUENCE_EMAIL
  CONFLUENCE_API_TOKEN
  CONFLUENCE_SPACE_KEY
  CONFLUENCE_PARENT_PAGE_ID
```

## Resources

- [Confluence REST API Documentation](https://developer.atlassian.com/cloud/confluence/rest/v1/)
- [Confluence Storage Format Guide](https://confluence.atlassian.com/doc/confluence-storage-format-790796544.html)
- [Confluence API Authentication](https://developer.atlassian.com/cloud/confluence/basic-auth-for-rest-apis/)

## Support

If you encounter issues:

1. Check error messages in n8n execution logs
2. Verify environment variables are loaded
3. Test Confluence connection manually
4. Review script output in `/tmp/confluence-result.json`
5. Check Confluence page creation in UI
