#!/usr/bin/env node

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { SSEServerTransport } from "@modelcontextprotocol/sdk/server/sse.js";
import { createToolDefinitions } from "./dist/tools.js";
import { setupRequestHandlers } from "./dist/requestHandler.js";
import express from 'express';

const PORT = process.env.MCP_SERVER_PORT || 3000;
const HOST = process.env.MCP_SERVER_HOST || '0.0.0.0';

console.log(`Starting MCP Playwright HTTP server on ${HOST}:${PORT}`);

const app = express();
app.use(express.json());

// CORS middleware
app.use((req, res, next) => {
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  if (req.method === 'OPTIONS') {
    res.sendStatus(200);
    return;
  }
  next();
});

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ status: 'healthy', service: 'mcp-playwright' });
});

// MCP Server instance
let mcpServer = null;

async function createMCPServer() {
  if (mcpServer) return mcpServer;
  
  mcpServer = new Server(
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
  setupRequestHandlers(mcpServer, TOOLS);
  
  return mcpServer;
}

// SSE endpoint for MCP communication
app.get('/sse', async (req, res) => {
  try {
    const server = await createMCPServer();
    
    // Set SSE headers
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-cache',
      'Connection': 'keep-alive',
      'Access-Control-Allow-Origin': '*',
    });

    // Create SSE transport
    const transport = new SSEServerTransport("/message", res);
    await server.connect(transport);
    
    console.log('MCP server connected via SSE');
    
    req.on('close', () => {
      console.log('SSE connection closed');
    });
    
  } catch (error) {
    console.error('Error setting up SSE:', error);
    res.status(500).json({ error: error.message });
  }
});

// POST endpoint for direct MCP requests
app.post('/mcp', async (req, res) => {
  try {
    const server = await createMCPServer();
    
    // Handle MCP request directly
    const response = await server.handleRequest(req.body);
    res.json(response);
    
  } catch (error) {
    console.error('Error handling MCP request:', error);
    res.status(500).json({ error: error.message });
  }
});

// Basic info endpoint
app.get('/', (req, res) => {
  res.json({ 
    service: 'mcp-playwright',
    version: '1.0.6',
    status: 'running',
    description: 'MCP Playwright server for browser automation',
    transport: 'http',
    endpoints: {
      health: '/health',
      sse: '/sse',
      mcp: '/mcp',
      info: '/'
    }
  });
});

app.listen(PORT, HOST, () => {
  console.log(`MCP Playwright HTTP server listening on ${HOST}:${PORT}`);
  console.log('Available endpoints:');
  console.log('  GET  /health - Health check');
  console.log('  GET  /sse    - MCP SSE connection');
  console.log('  POST /mcp    - MCP request handler');
  console.log('  GET  /       - Service info');
});

// Graceful shutdown
function shutdown() {
  console.log('Shutting down MCP Playwright HTTP server');
  process.exit(0);
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);