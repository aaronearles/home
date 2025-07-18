#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { createToolDefinitions } from "./dist/tools.js";
import { setupRequestHandlers } from "./dist/requestHandler.js";
import express from 'express';

const PORT = process.env.MCP_SERVER_PORT || 3000;
const HOST = process.env.MCP_SERVER_HOST || '0.0.0.0';

console.log(`Starting MCP Playwright server on ${HOST}:${PORT}`);

const app = express();
app.use(express.json());

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'mcp-playwright' });
});

// SSE endpoint for MCP communication
app.get('/sse', async (req, res) => {
  const server = new Server(
    {
      name: "playwright-mcp",
      version: "1.0.6",
    },
    {
      capabilities: {
        resources: {},
        tools: {},
      },
    }
  );

  // Create tool definitions
  const TOOLS = createToolDefinitions();
  
  // Setup request handlers
  setupRequestHandlers(server, TOOLS);

  // Create SSE transport
  const transport = new SSEServerTransport("/message", res);
  await server.connect(transport);
  
  console.log('MCP server connected via SSE');
});

// Basic info endpoint
app.get('/', (req, res) => {
  res.json({ 
    service: 'mcp-playwright',
    version: '1.0.6',
    endpoints: {
      health: '/health',
      sse: '/sse'
    }
  });
});

app.listen(PORT, HOST, () => {
  console.log(`MCP Playwright server listening on ${HOST}:${PORT}`);
  console.log('Available endpoints:');
  console.log('  GET  /health - Health check');
  console.log('  GET  /sse    - MCP SSE connection');
  console.log('  GET  /       - Service info');
});

// Graceful shutdown
function shutdown() {
  console.log('Shutting down MCP Playwright server');
  process.exit(0);
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);