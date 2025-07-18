#!/usr/bin/env node

const http = require('http');
const { spawn } = require('child_process');

const PORT = process.env.MCP_SERVER_PORT || 3000;
const HOST = process.env.MCP_SERVER_HOST || '0.0.0.0';

console.log(`Starting MCP Playwright HTTP wrapper on ${HOST}:${PORT}`);

const server = http.createServer((req, res) => {
  // Set CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PUT, DELETE, OPTIONS');
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

  if (req.method === 'POST' && req.url === '/mcp') {
    let body = '';
    req.on('data', chunk => {
      body += chunk.toString();
    });
    
    req.on('end', () => {
      try {
        // Spawn the MCP server process
        const mcpProcess = spawn('node', ['dist/index.js'], {
          stdio: ['pipe', 'pipe', 'pipe']
        });

        let responseData = '';
        let errorData = '';

        mcpProcess.stdout.on('data', (data) => {
          responseData += data.toString();
        });

        mcpProcess.stderr.on('data', (data) => {
          errorData += data.toString();
        });

        mcpProcess.on('close', (code) => {
          if (code === 0) {
            res.writeHead(200, { 'Content-Type': 'application/json' });
            res.end(responseData || JSON.stringify({ result: 'success' }));
          } else {
            res.writeHead(500, { 'Content-Type': 'application/json' });
            res.end(JSON.stringify({ error: errorData || 'MCP process failed' }));
          }
        });

        // Send the request body to the MCP process
        if (body) {
          mcpProcess.stdin.write(body);
        }
        mcpProcess.stdin.end();

      } catch (error) {
        res.writeHead(500, { 'Content-Type': 'application/json' });
        res.end(JSON.stringify({ error: error.message }));
      }
    });
    return;
  }

  // Default response for other routes
  res.writeHead(404, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ error: 'Not found' }));
});

server.listen(PORT, HOST, () => {
  console.log(`MCP Playwright HTTP wrapper listening on ${HOST}:${PORT}`);
  console.log('Available endpoints:');
  console.log('  GET  /health - Health check');
  console.log('  POST /mcp    - MCP server proxy');
});

// Graceful shutdown
process.on('SIGTERM', () => {
  console.log('Received SIGTERM, shutting down gracefully');
  server.close(() => {
    process.exit(0);
  });
});

process.on('SIGINT', () => {
  console.log('Received SIGINT, shutting down gracefully');
  server.close(() => {
    process.exit(0);
  });
});