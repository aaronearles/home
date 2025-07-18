#!/usr/bin/env node

import http from 'http';

const PORT = process.env.MCP_SERVER_PORT || 3000;
const HOST = process.env.MCP_SERVER_HOST || '0.0.0.0';

console.log(`Starting MCP Playwright HTTP service on ${HOST}:${PORT}`);

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

  if (req.method === 'GET' && req.url === '/') {
    res.writeHead(200, { 'Content-Type': 'application/json' });
    res.end(JSON.stringify({ 
      service: 'mcp-playwright',
      version: '1.0.6',
      status: 'running',
      description: 'MCP Playwright server for browser automation',
      endpoints: {
        health: '/health',
        info: '/'
      }
    }));
    return;
  }

  // For any other requests, return API info
  res.writeHead(200, { 'Content-Type': 'application/json' });
  res.end(JSON.stringify({ 
    message: 'MCP Playwright server is running',
    note: 'This server provides browser automation tools via Model Context Protocol',
    usage: 'Connect via MCP client using stdio transport'
  }));
});

server.listen(PORT, HOST, () => {
  console.log(`MCP Playwright HTTP service listening on ${HOST}:${PORT}`);
  console.log('This is a status server - MCP communication happens via stdio');
  console.log('Available endpoints:');
  console.log('  GET  /health - Health check');
  console.log('  GET  /       - Service info');
});

// Keep the process running
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