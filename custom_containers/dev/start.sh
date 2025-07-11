#!/bin/bash

# Start script for development container
# This script starts code-server automatically

echo "Starting development container..."

# Ensure workspace directory exists and has proper permissions
mkdir -p /workspace
sudo chown -R $(whoami):$(whoami) /workspace

# Start code-server in the background
echo "Starting VS Code Server on port 8080..."
code-server \
    --bind-addr 0.0.0.0:8080 \
    --auth none \
    --disable-telemetry \
    --disable-update-check \
    --extensions-dir /home/$(whoami)/.local/share/code-server/extensions \
    --user-data-dir /home/$(whoami)/.local/share/code-server \
    /workspace &

# Start MCP server in the background
echo "Starting MCP Server on port 3000..."
cd /home/$(whoami)/mcp-server
node server.js &

# Wait for services to start
sleep 5

echo "Development container is ready!"
echo "Access VS Code Server at: http://localhost:8080"
echo "Access MCP Server at: http://localhost:3000"
echo "Workspace directory: /workspace"
echo ""
echo "Available aliases:"
echo "  k = kubectl"
echo "  tf = terraform"
echo "  tofu = tofu"
echo "  linode = linode-cli"
echo "  ll = ls -la"
echo ""
echo "Available ports:"
echo "  8080 - VS Code Server"
echo "  3000 - MCP Server / Node.js development server"
echo "  4200 - Angular development server"
echo "  8000 - Python development server"
echo "  9000 - Additional development server"
echo ""

# Keep the container running
tail -f /dev/null