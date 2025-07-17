# Browser MCP Server Deployment Guide

## Overview

This deploys the Browser MCP server as a containerized service on dockerint01.earles.internal, accessible by other hosts running Claude Code on the same network.

## Deployment

1. **Deploy the service**:
   ```bash
   cd /home/aearles/code/home/custom_containers/browser-mcp
   docker-compose up -d
   ```

2. **Verify deployment**:
   ```bash
   docker-compose logs -f browser-mcp
   curl -k https://browser-mcp.internal.earles.io
   ```

## Remote Claude Code Configuration

### For hosts on the same network:

1. **Create MCP configuration** on remote hosts:
   ```bash
   # Create .claude/settings.local.json
   mkdir -p ~/.claude
   ```

2. **Add MCP server configuration**:
   ```json
   {
     "mcpServers": {
       "browser-automation": {
         "command": "curl",
         "args": [
           "-X", "POST",
           "-H", "Content-Type: application/json",
           "-d", "@-",
           "https://browser-mcp.internal.earles.io/mcp"
         ],
         "description": "Remote browser automation via Puppeteer MCP server"
       }
     }
   }
   ```

### Alternative: Direct network connection

For hosts that can reach dockerint01.earles.internal directly:

```json
{
  "mcpServers": {
    "browser-automation": {
      "command": "node",
      "args": ["-e", "
        const net = require('net');
        const client = net.createConnection(3000, 'dockerint01.earles.internal');
        process.stdin.pipe(client);
        client.pipe(process.stdout);
      "],
      "description": "Remote browser automation via TCP connection"
    }
  }
}
```

## Network Requirements

- Remote hosts must be able to resolve `dockerint01.earles.internal`
- Network connectivity on port 443 (HTTPS) or port 3000 (direct)
- Traefik must be running on dockerint01 for HTTPS access

## Usage from Remote Hosts

Once configured, use browser automation from any Claude Code instance:

```bash
# Navigate to a page and take screenshot
claude "Navigate to https://example.com and take a screenshot"

# Extract content from dynamic pages
claude "Go to the React documentation and extract the getting started steps"

# Interactive testing
claude "Navigate to httpbin.org and test the form submission endpoints"
```

## Service Management

```bash
# View logs
docker-compose logs -f browser-mcp

# Restart service
docker-compose restart browser-mcp

# Update image
docker-compose pull && docker-compose up -d

# Stop service
docker-compose down
```

## Troubleshooting

### Connection Issues
- Verify dockerint01.earles.internal resolves correctly
- Check if port 3000 or 443 is accessible
- Ensure Traefik is running and configured properly

### MCP Server Issues
- Check container logs: `docker-compose logs browser-mcp`
- Verify the mcp/puppeteer image is latest
- Test direct connection: `telnet dockerint01.earles.internal 3000`

### Performance Issues
- Browser automation can be memory-intensive
- Consider increasing container memory limits if needed
- Monitor CPU usage during heavy automation tasks