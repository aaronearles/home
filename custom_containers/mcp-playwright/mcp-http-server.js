#!/usr/bin/env node

import http from 'http';
import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { createToolDefinitions } from "./dist/tools.js";
import { setupRequestHandlers } from "./dist/requestHandler.js";
import { patchBrowserLaunch } from "./toolHandler-patch.js";
import { 
  ListToolsRequestSchema, 
  CallToolRequestSchema,
  InitializeRequestSchema
} from "@modelcontextprotocol/sdk/types.js";

const PORT = process.env.MCP_SERVER_PORT || 3000;
const HOST = process.env.MCP_SERVER_HOST || '0.0.0.0';

console.log(`Starting MCP Playwright HTTP server on ${HOST}:${PORT}`);

// Apply browser configuration patch
patchBrowserLaunch();

// Create MCP Server instance
const mcpServer = new Server(
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

// Create tool definitions and setup handlers
const TOOLS = createToolDefinitions();
setupRequestHandlers(mcpServer, TOOLS);

console.log('MCP Server initialized with tools:', TOOLS.length);

const server = http.createServer(async (req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization');
  
  if (req.method === 'OPTIONS') {
    res.writeHead(200);
    res.end();
    return;
  }

  if (req.method === 'GET' && req.url === '/health') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ status: 'healthy', service: 'mcp-playwright' }));
    return;
  }

  if (req.method === 'GET' && req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ 
      service: 'mcp-playwright',
      version: '1.0.6',
      status: 'running',
      description: 'MCP Playwright server for browser automation',
      transport: 'http',
      endpoints: {
        health: '/health',
        mcp: '/mcp',
        info: '/',
        register: '/register'
      },
      availableTools: TOOLS.map(tool => tool.name)
    }));
    return;
  }

  // Handle dynamic client registration
  if (req.method === 'POST' && req.url === '/register') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({
      success: true,
      message: 'Client registered successfully',
      serverInfo: {
        name: 'playwright-mcp',
        version: '1.0.6'
      }
    }));
    return;
  }

  // Handle MCP JSON-RPC requests at both root and /mcp
  if (req.method === 'POST' && (req.url === '/' || req.url === '/mcp')) {
    let body = '';
    
    req.on('data', chunk => {
      body += chunk.toString();
    });
    
    req.on('end', async () => {
      try {
        const jsonRpcRequest = JSON.parse(body);
        console.log('Received MCP request:', jsonRpcRequest.method);
        
        // Use the MCP server's built-in request handling
        let response;
        
        try {
          // Create a mock request object that the MCP server expects
          const mockRequest = {
            method: jsonRpcRequest.method,
            params: jsonRpcRequest.params || {}
          };
          
          let result;
          
          switch (jsonRpcRequest.method) {
            case 'initialize':
              response = {
                jsonrpc: "2.0",
                id: jsonRpcRequest.id,
                result: {
                  protocolVersion: "2024-11-05",
                  capabilities: {
                    tools: {
                      listChanged: true
                    },
                    resources: {},
                    prompts: {},
                    experimental: {}
                  },
                  serverInfo: {
                    name: "playwright-mcp",
                    version: "1.0.6"
                  }
                }
              };
              break;
              
            case 'tools/list':
              response = {
                jsonrpc: "2.0",
                id: jsonRpcRequest.id,
                result: {
                  tools: TOOLS
                }
              };
              break;
              
            case 'tools/call':
              // Import the tool handler directly
              const { handleToolCall } = await import('./dist/toolHandler.js');
              
              const toolResult = await handleToolCall(
                jsonRpcRequest.params.name, 
                jsonRpcRequest.params.arguments || {}, 
                mcpServer
              );
              
              response = {
                jsonrpc: "2.0",
                id: jsonRpcRequest.id,
                result: toolResult
              };
              break;
              
            default:
              response = {
                jsonrpc: "2.0",
                id: jsonRpcRequest.id,
                error: {
                  code: -32601,
                  message: `Method '${jsonRpcRequest.method}' not found`
                }
              };
          }
        } catch (error) {
          response = {
            jsonrpc: "2.0",
            id: jsonRpcRequest.id,
            error: {
              code: -32603,
              message: error.message
            }
          };
        }
        
        res.writeHead(200, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(response));
        
      } catch (error) {
        console.error('Error processing MCP request:', error);
        const errorResponse = {
          jsonrpc: "2.0",
          id: null,
          error: {
            code: -32700,
            message: "Parse error"
          }
        };
        res.writeHead(400, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify(errorResponse));
      }
    });
    return;
  }

  // Default 404 response
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, HOST, () => {
  console.log(`MCP Playwright HTTP server listening on ${HOST}:${PORT}`);
  console.log('Available endpoints:');
  console.log('  GET  /health - Health check');
  console.log('  POST /mcp    - MCP JSON-RPC endpoint');
  console.log('  GET  /       - Service info');
  console.log(`Tools available: ${TOOLS.map(tool => tool.name).join(', ')}`);
});

// Graceful shutdown
function shutdown() {
  console.log('Shutting down MCP Playwright HTTP server');
  server.close(() => {
    process.exit(0);
  });
}

process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);