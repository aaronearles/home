# MCP Playwright Docker Container

This directory contains the Docker containerization of the MCP Playwright server for use with Traefik.

## Setup

The MCP Playwright server has been containerized with:

- **Multi-stage build** with Alpine for builder and Debian Slim for runtime
- **System browsers** (Chromium & Firefox) pre-installed
- **Security hardening** with non-root user and restricted capabilities
- **Traefik integration** with SSL termination and lab domain routing
- **Health checks** and proper logging

## Files

- `Dockerfile` - Multi-stage container build with browser dependencies
- `docker-compose.yml` - Service definition with Traefik labels
- `.env` - Environment configuration for MCP server
- `.dockerignore` - Build optimization exclusions

## Deployment

1. Ensure Traefik network exists:
```bash
docker network create traefik
```

2. Build and start the service:
```bash
docker compose up -d --build
```

3. Check logs:
```bash
docker compose logs -f
```

## Access

The service will be available at: `https://mcp-playwright.lab.earles.io`

**Note**: This container runs an HTTP status service for monitoring. The actual MCP Playwright server communicates via STDIO transport, which is the standard for MCP servers.

## Configuration

The MCP server runs on port 3000 internally and is routed through Traefik. Browser executables are configured to use system-installed versions for better security and reduced image size.

### Available Endpoints
- `GET /health` - Health check endpoint  
- `GET /` - Service information

### MCP Usage
The actual MCP Playwright tools are available when connecting to the container via the MCP protocol using STDIO transport. The HTTP service provides status and monitoring capabilities.

## Security Features

- Non-root user execution
- Dropped capabilities with minimal additions
- System browsers instead of downloaded versions
- Health check monitoring