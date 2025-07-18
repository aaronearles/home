# Stagehand MCP Server Deployment

Headless browser automation using Stagehand/Browserbase MCP server with Traefik integration.

## Quick Start

1. **Configure Environment**
   ```bash
   cp .env.sample .env
   # Edit .env with your API keys
   ```

2. **Deploy**
   ```bash
   docker-compose up -d
   ```

3. **Access**
   - Service available at: `https://browser.lab.earles.io`
   - Logs: `docker-compose logs -f`

## Required API Keys

### Browserbase API Key & Project ID
1. Sign up at [browserbase.com](https://browserbase.com)
2. Navigate to your dashboard
3. Create a new project (if needed)
4. Copy the Project ID and generate an API key
5. Add both to `.env` as `BROWSERBASE_API_KEY` and `BROWSERBASE_PROJECT_ID`

### OpenAI API Key  
1. Go to [platform.openai.com](https://platform.openai.com)
2. Create an API key
3. Add to `.env` as `OPENAI_API_KEY`

**Note**: The MCP server requires OpenAI API, not Anthropic. This is used for the AI-powered browser automation capabilities.

## Claude Code Integration

Add to your `.mcp.json`:

```json
{
  "mcpServers": {
    "stagehand-remote": {
      "command": "curl",
      "args": [
        "-X", "POST",
        "-H", "Content-Type: application/json",
        "https://browser.lab.earles.io/mcp",
        "-d", "@-"
      ]
    }
  }
}
```

## Available Commands

- **stagehand_navigate**: Navigate to URLs
- **stagehand_act**: Perform actions with natural language
- **stagehand_extract**: Extract structured data
- **stagehand_observe**: Identify page interactions

## Troubleshooting

```bash
# Check service status
docker-compose ps

# View logs
docker-compose logs -f stagehand-mcp

# Restart service
docker-compose restart stagehand-mcp

# Rebuild after changes
docker-compose build --no-cache
```

## Security Notes

- Service runs as non-root user
- API keys stored in environment variables
- Network isolated via Traefik and Docker networks
- Regular health checks enabled