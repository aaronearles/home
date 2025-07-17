# Browser MCP Server - Puppeteer

This project provides browser automation capabilities for Claude Code using the official Puppeteer MCP server.

## Setup

1. **Pull the Docker image** (already done):
   ```bash
   docker pull mcp/puppeteer
   ```

2. **Configure Claude Code**:
   The `.mcp.json` file is already configured to use the Puppeteer MCP server.

3. **Test the setup**:
   ```bash
   # Test that the MCP server tools are available
   echo '{"jsonrpc": "2.0", "id": 1, "method": "tools/list", "params": {}}' | docker run -i --rm --init -e DOCKER_CONTAINER=true mcp/puppeteer
   ```

## Available Tools

The Puppeteer MCP server provides these browser automation tools:

- **puppeteer_navigate**: Navigate to a URL
- **puppeteer_screenshot**: Take screenshots
- **puppeteer_click**: Click elements
- **puppeteer_fill**: Fill form fields
- **puppeteer_select**: Select dropdown options
- **puppeteer_hover**: Hover over elements
- **puppeteer_evaluate**: Execute JavaScript

## Usage with Claude Code

Once configured, you can ask Claude Code to:
- Navigate to websites
- Take screenshots for debugging
- Interact with web pages (click, fill forms)
- Execute JavaScript code
- Extract content from dynamic pages

## Example Commands

```bash
# Navigate to a page
claude "Navigate to https://httpbin.org/html and take a screenshot"

# Extract content
claude "Go to the Fortinet API documentation and extract the endpoint list"

# Interactive testing
claude "Navigate to httpbin.org, fill out any forms you find, and show me the results"
```

## Security Notes

- The container runs with `--no-sandbox` flag for Docker compatibility
- Uses headless Chrome for browser automation
- Container is ephemeral (--rm flag) for security
- No persistent storage by default

## Troubleshooting

If you encounter issues:

1. **Check Docker**: Ensure Docker is running and accessible
2. **Memory**: The container may need more memory for complex pages
3. **Network**: Ensure the container can access external websites
4. **Timeout**: Some pages may take longer to load

## Integration with Existing Crawlers

This MCP server can enhance your existing web crawlers by providing:
- JavaScript rendering for SPA applications
- Screenshot capabilities for debugging
- Interactive element testing
- Dynamic content extraction