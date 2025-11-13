# Confluence MCP Setup Guide

This guide explains how to set up the Confluence MCP (Model Context Protocol) integration for automated documentation.

## Prerequisites

1. Confluence Cloud account with API access
2. Confluence API Token
3. Node.js 18+ installed
4. n8n installed locally

## Step 1: Install Confluence MCP Server

```bash
# Install the MCP Confluence server globally
npm install -g @modelcontextprotocol/server-confluence

# Or install locally in the project
npm install @modelcontextprotocol/server-confluence
```

## Step 2: Configure Confluence Credentials

Add the following to your `.env` file:

```bash
CONFLUENCE_DOMAIN=yourcompany.atlassian.net
CONFLUENCE_EMAIL=your-email@company.com
CONFLUENCE_API_TOKEN=your_api_token_here
CONFLUENCE_SPACE_KEY=DEV
CONFLUENCE_PARENT_PAGE_ID=123456789
```

### How to Get Confluence API Token:

1. Go to https://id.atlassian.com/manage-profile/security/api-tokens
2. Click "Create API token"
3. Give it a name (e.g., "n8n Automation")
4. Copy the token and add it to your `.env` file

### How to Find Parent Page ID:

1. Go to your Confluence space
2. Navigate to the page where you want to create update documentation
3. Click on the "..." menu → "Page Information"
4. The page ID is in the URL: `pages/viewinfo.action?pageId=123456789`

## Step 3: MCP Server Configuration

Create or update `~/.config/claude/mcp.json`:

```json
{
  "mcpServers": {
    "confluence": {
      "command": "npx",
      "args": [
        "-y",
        "@modelcontextprotocol/server-confluence"
      ],
      "env": {
        "CONFLUENCE_DOMAIN": "yourcompany.atlassian.net",
        "CONFLUENCE_EMAIL": "your-email@company.com",
        "CONFLUENCE_API_TOKEN": "your_api_token"
      }
    }
  }
}
```

## Step 4: Create n8n HTTP Request Node for Confluence

In n8n, you'll use HTTP Request nodes to interact with Confluence REST API:

### Configuration:

- **Method**: POST (for creating pages) / PUT (for updating)
- **URL**: `https://{{CONFLUENCE_DOMAIN}}/wiki/rest/api/content`
- **Authentication**: Basic Auth
  - Username: Your Confluence email
  - Password: Your API token
- **Headers**:
  - `Content-Type`: `application/json`
- **Body**: See templates below

## Confluence Page Templates

### Create New Page

```json
{
  "type": "page",
  "title": "Dependency Update Run - {{runId}}",
  "space": {
    "key": "{{CONFLUENCE_SPACE_KEY}}"
  },
  "ancestors": [
    {
      "id": "{{CONFLUENCE_PARENT_PAGE_ID}}"
    }
  ],
  "body": {
    "storage": {
      "value": "<h2>Update Summary</h2><p>Content here...</p>",
      "representation": "storage"
    }
  }
}
```

### Update Existing Page

```json
{
  "id": "{{pageId}}",
  "type": "page",
  "title": "Updated Title",
  "version": {
    "number": "{{currentVersion + 1}}"
  },
  "body": {
    "storage": {
      "value": "<h2>Updated Content</h2>",
      "representation": "storage"
    }
  }
}
```

## Confluence Storage Format Examples

### Headers and Text

```html
<h1>Main Title</h1>
<h2>Subtitle</h2>
<p>Regular paragraph text</p>
<p><strong>Bold text</strong></p>
<p><em>Italic text</em></p>
```

### Tables

```html
<table>
  <thead>
    <tr>
      <th>Package</th>
      <th>From</th>
      <th>To</th>
      <th>Type</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td>@angular/core</td>
      <td>17.0.0</td>
      <td>18.0.0</td>
      <td>Major</td>
    </tr>
  </tbody>
</table>
```

### Code Blocks

```html
<ac:structured-macro ac:name="code">
  <ac:parameter ac:name="language">typescript</ac:parameter>
  <ac:plain-text-body><![CDATA[
    // Your code here
    function example() {
      return true;
    }
  ]]></ac:plain-text-body>
</ac:structured-macro>
```

### Status Macros

```html
<ac:structured-macro ac:name="status">
  <ac:parameter ac:name="colour">Green</ac:parameter>
  <ac:parameter ac:name="title">PASSED</ac:parameter>
</ac:structured-macro>
```

### Info/Warning Panels

```html
<ac:structured-macro ac:name="info">
  <ac:rich-text-body>
    <p>This is an info panel</p>
  </ac:rich-text-body>
</ac:structured-macro>

<ac:structured-macro ac:name="warning">
  <ac:rich-text-body>
    <p>This is a warning panel</p>
  </ac:rich-text-body>
</ac:structured-macro>
```

## Testing Confluence Integration

### Test 1: Create a Simple Page

```bash
curl -X POST \
  -u "your-email@company.com:your-api-token" \
  -H "Content-Type: application/json" \
  -d '{
    "type": "page",
    "title": "Test Page from n8n",
    "space": {"key": "DEV"},
    "ancestors": [{"id": "123456789"}],
    "body": {
      "storage": {
        "value": "<h1>Test</h1><p>This is a test page</p>",
        "representation": "storage"
      }
    }
  }' \
  https://yourcompany.atlassian.net/wiki/rest/api/content
```

### Test 2: Get Page Info

```bash
curl -X GET \
  -u "your-email@company.com:your-api-token" \
  https://yourcompany.atlassian.net/wiki/rest/api/content/123456789
```

## Troubleshooting

### Error: 401 Unauthorized
- Verify your API token is correct
- Ensure you're using email address as username
- Check that API token hasn't expired

### Error: 403 Forbidden
- Verify you have permission to create pages in the space
- Check that the parent page exists and you have access
- Ensure your user has "Can Add" permissions in the space

### Error: 400 Bad Request
- Validate your JSON structure
- Check that space key is correct
- Verify parent page ID exists
- Ensure title is unique within the parent page

### Pages Not Appearing
- Check the parent page ID is correct
- Verify the space key matches your Confluence space
- Look in the space's page tree to find created pages

## Best Practices

1. **Use Descriptive Titles**: Include timestamp or run ID in page titles
2. **Organize Pages**: Use a consistent parent page for all automation docs
3. **Format Consistently**: Use templates for similar types of documentation
4. **Include Metadata**: Add run IDs, timestamps, and links to related resources
5. **Error Handling**: Always check response status and handle errors gracefully
6. **Rate Limiting**: Be mindful of Confluence API rate limits (200 requests/minute)

## Next Steps

After completing the setup:

1. Test creating a simple page manually
2. Import the confluence documentation workflow into n8n
3. Configure the workflow with your credentials
4. Run a test execution
5. Verify the page appears in Confluence with correct formatting

## Additional Resources

- [Confluence REST API Documentation](https://developer.atlassian.com/cloud/confluence/rest/v1/)
- [Confluence Storage Format](https://confluence.atlassian.com/doc/confluence-storage-format-790796544.html)
- [Model Context Protocol Docs](https://modelcontextprotocol.io/)
