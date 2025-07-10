# Development Container with MCP Server Setup

This guide will help you deploy a development container with an MCP server that allows Claude to write code, use tools, access filesystems, and manage git repositories remotely.

## Prerequisites

- Docker and Docker Compose installed on your headless host
- Network access to the host from your mobile device
- Basic understanding of Docker containers and networking

## Step 1: Create Project Structure

Create the following directory structure on your headless host:

```
dev-container-mcp/
├── docker-compose.yml
├── Dockerfile
├── mcp-server/
│   ├── server.js
│   ├── package.json
│   └── config.json
├── workspace/
│   └── (your code projects will go here)
└── .env
```

## Step 2: Create the Dockerfile

Create `Dockerfile`:

```dockerfile
FROM node:18-bullseye

# Install system dependencies
RUN apt-get update && apt-get install -y \
    git \
    curl \
    wget \
    vim \
    nano \
    python3 \
    python3-pip \
    build-essential \
    && rm -rf /var/lib/apt/lists/*

# Create workspace directory
RUN mkdir -p /workspace
WORKDIR /workspace

# Install MCP server dependencies
COPY mcp-server/package.json /mcp-server/
WORKDIR /mcp-server
RUN npm install

# Copy MCP server code
COPY mcp-server/ /mcp-server/

# Set up git (these will be overridden by environment variables)
RUN git config --global user.name "Claude Dev" && \
    git config --global user.email "claude@dev.local"

# Expose MCP server port
EXPOSE 3000

# Start MCP server
CMD ["node", "/mcp-server/server.js"]
```

## Step 3: Create MCP Server Package Configuration

Create `mcp-server/package.json`:

```json
{
  "name": "mcp-dev-server",
  "version": "1.0.0",
  "description": "MCP Server for Claude development container",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "@modelcontextprotocol/sdk": "^0.4.0",
    "ws": "^8.14.2",
    "express": "^4.18.2",
    "child_process": "^1.0.2",
    "fs-extra": "^11.1.1",
    "path": "^0.12.7",
    "simple-git": "^3.19.1"
  }
}
```

## Step 4: Create MCP Server Implementation

Create `mcp-server/server.js`:

```javascript
const { Server } = require('@modelcontextprotocol/sdk/server/index.js');
const { StdioServerTransport } = require('@modelcontextprotocol/sdk/server/stdio.js');
const { CallToolRequestSchema, ListToolsRequestSchema } = require('@modelcontextprotocol/sdk/types.js');
const express = require('express');
const WebSocket = require('ws');
const fs = require('fs-extra');
const path = require('path');
const { execSync, spawn } = require('child_process');
const simpleGit = require('simple-git');

const app = express();
const server = require('http').createServer(app);
const wss = new WebSocket.Server({ server });

// MCP Server instance
const mcpServer = new Server(
  {
    name: 'dev-container-server',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Tool definitions
const tools = [
  {
    name: 'read_file',
    description: 'Read contents of a file',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Path to the file' }
      },
      required: ['path']
    }
  },
  {
    name: 'write_file',
    description: 'Write content to a file',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Path to the file' },
        content: { type: 'string', description: 'Content to write' }
      },
      required: ['path', 'content']
    }
  },
  {
    name: 'execute_command',
    description: 'Execute a shell command',
    inputSchema: {
      type: 'object',
      properties: {
        command: { type: 'string', description: 'Command to execute' },
        cwd: { type: 'string', description: 'Working directory (optional)' }
      },
      required: ['command']
    }
  },
  {
    name: 'list_directory',
    description: 'List contents of a directory',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Path to directory' }
      },
      required: ['path']
    }
  },
  {
    name: 'git_status',
    description: 'Get git status of repository',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Repository path' }
      },
      required: ['path']
    }
  },
  {
    name: 'git_commit',
    description: 'Commit changes to git',
    inputSchema: {
      type: 'object',
      properties: {
        path: { type: 'string', description: 'Repository path' },
        message: { type: 'string', description: 'Commit message' }
      },
      required: ['path', 'message']
    }
  },
  {
    name: 'create_project',
    description: 'Create a new project directory with basic structure',
    inputSchema: {
      type: 'object',
      properties: {
        name: { type: 'string', description: 'Project name' },
        type: { type: 'string', description: 'Project type (node, python, etc.)' }
      },
      required: ['name', 'type']
    }
  }
];

// Tool handlers
const toolHandlers = {
  read_file: async (args) => {
    try {
      const filePath = path.resolve('/workspace', args.path);
      const content = await fs.readFile(filePath, 'utf8');
      return { content };
    } catch (error) {
      return { error: error.message };
    }
  },

  write_file: async (args) => {
    try {
      const filePath = path.resolve('/workspace', args.path);
      await fs.ensureDir(path.dirname(filePath));
      await fs.writeFile(filePath, args.content);
      return { success: true, path: filePath };
    } catch (error) {
      return { error: error.message };
    }
  },

  execute_command: async (args) => {
    try {
      const cwd = args.cwd ? path.resolve('/workspace', args.cwd) : '/workspace';
      const output = execSync(args.command, { 
        cwd, 
        encoding: 'utf8',
        timeout: 30000 
      });
      return { output, success: true };
    } catch (error) {
      return { error: error.message, output: error.stdout || '' };
    }
  },

  list_directory: async (args) => {
    try {
      const dirPath = path.resolve('/workspace', args.path);
      const files = await fs.readdir(dirPath, { withFileTypes: true });
      const result = files.map(file => ({
        name: file.name,
        type: file.isDirectory() ? 'directory' : 'file'
      }));
      return { files: result };
    } catch (error) {
      return { error: error.message };
    }
  },

  git_status: async (args) => {
    try {
      const repoPath = path.resolve('/workspace', args.path);
      const git = simpleGit(repoPath);
      const status = await git.status();
      return { status };
    } catch (error) {
      return { error: error.message };
    }
  },

  git_commit: async (args) => {
    try {
      const repoPath = path.resolve('/workspace', args.path);
      const git = simpleGit(repoPath);
      await git.add('.');
      const result = await git.commit(args.message);
      return { success: true, result };
    } catch (error) {
      return { error: error.message };
    }
  },

  create_project: async (args) => {
    try {
      const projectPath = path.resolve('/workspace', args.name);
      await fs.ensureDir(projectPath);
      
      // Initialize git
      const git = simpleGit(projectPath);
      await git.init();
      
      // Create basic structure based on project type
      switch (args.type) {
        case 'node':
          await fs.writeFile(path.join(projectPath, 'package.json'), JSON.stringify({
            name: args.name,
            version: '1.0.0',
            description: '',
            main: 'index.js',
            scripts: { start: 'node index.js' }
          }, null, 2));
          await fs.writeFile(path.join(projectPath, 'index.js'), 'console.log("Hello World!");');
          break;
        case 'python':
          await fs.writeFile(path.join(projectPath, 'main.py'), 'print("Hello World!")');
          await fs.writeFile(path.join(projectPath, 'requirements.txt'), '');
          break;
        default:
          await fs.writeFile(path.join(projectPath, 'README.md'), `# ${args.name}\n\n`);
      }
      
      return { success: true, path: projectPath };
    } catch (error) {
      return { error: error.message };
    }
  }
};

// MCP Server setup
mcpServer.setRequestHandler(ListToolsRequestSchema, async () => {
  return { tools };
});

mcpServer.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;
  
  if (toolHandlers[name]) {
    const result = await toolHandlers[name](args);
    return { content: [{ type: 'text', text: JSON.stringify(result, null, 2) }] };
  }
  
  throw new Error(`Unknown tool: ${name}`);
});

// WebSocket setup for web interface
wss.on('connection', (ws) => {
  console.log('Client connected');
  
  ws.on('message', async (message) => {
    try {
      const request = JSON.parse(message);
      
      if (request.method === 'tools/list') {
        ws.send(JSON.stringify({ tools }));
      } else if (request.method === 'tools/call') {
        const result = await toolHandlers[request.params.name](request.params.arguments);
        ws.send(JSON.stringify({ result }));
      }
    } catch (error) {
      ws.send(JSON.stringify({ error: error.message }));
    }
  });
  
  ws.on('close', () => {
    console.log('Client disconnected');
  });
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`MCP Server running on port ${PORT}`);
});

// Run MCP server
async function runMCPServer() {
  const transport = new StdioServerTransport();
  await mcpServer.connect(transport);
}

// Start both servers
if (process.argv.includes('--mcp-only')) {
  runMCPServer().catch(console.error);
} else {
  // Start WebSocket server by default
  console.log('Starting WebSocket server...');
}
```

## Step 5: Create Docker Compose Configuration

Create `docker-compose.yml`:

```yaml
version: '3.8'

services:
  dev-container:
    build: .
    container_name: claude-dev-container
    ports:
      - "3000:3000"  # MCP server port
    volumes:
      - ./workspace:/workspace
      - ./mcp-server:/mcp-server
      - /var/run/docker.sock:/var/run/docker.sock  # For Docker-in-Docker if needed
    environment:
      - NODE_ENV=development
      - PORT=3000
      - GIT_USER_NAME=${GIT_USER_NAME:-Claude Dev}
      - GIT_USER_EMAIL=${GIT_USER_EMAIL:-claude@dev.local}
    restart: unless-stopped
    working_dir: /workspace
    networks:
      - dev-network

networks:
  dev-network:
    driver: bridge
```

## Step 6: Create Environment Configuration

Create `.env`:

```env
# Git configuration
GIT_USER_NAME=Your Name
GIT_USER_EMAIL=your.email@example.com

# Server configuration
PORT=3000
NODE_ENV=development
```

## Step 7: Create MCP Server Configuration

Create `mcp-server/config.json`:

```json
{
  "mcpServers": {
    "dev-container": {
      "command": "node",
      "args": ["/mcp-server/server.js", "--mcp-only"],
      "env": {
        "NODE_ENV": "development"
      }
    }
  }
}
```

## Step 8: Deploy the Container

1. **Navigate to your project directory:**
   ```bash
   cd dev-container-mcp
   ```

2. **Build and start the container:**
   ```bash
   docker-compose up -d --build
   ```

3. **Verify the container is running:**
   ```bash
   docker-compose ps
   docker-compose logs dev-container
   ```

## Step 9: Configure Claude to Connect

### Option A: Direct WebSocket Connection (for testing)
You can test the connection by connecting to `ws://YOUR_HOST_IP:3000` from a WebSocket client.

### Option B: Claude Desktop/Mobile Integration
1. **For Claude Desktop:** Add the MCP server to your Claude configuration
2. **For Claude Mobile/Web:** The container exposes a WebSocket endpoint that Claude can connect to

## Step 10: Test the Setup

1. **Check if the container is accessible:**
   ```bash
   curl http://YOUR_HOST_IP:3000
   ```

2. **Test file operations through the workspace:**
   ```bash
   docker-compose exec dev-container ls -la /workspace
   ```

## Step 11: Usage Examples

Once connected, you can ask Claude to:

- **Create a new project:** "Create a new Node.js project called 'my-app'"
- **Write code:** "Write a simple Express server in the my-app project"
- **Run commands:** "Install dependencies and start the server"
- **Manage git:** "Initialize git, commit the changes, and show status"
- **Deploy code:** "Build and deploy the application"

## Security Considerations

1. **Network Security:** Ensure the container is only accessible from trusted networks
2. **Authentication:** Consider adding authentication to the MCP server
3. **Resource Limits:** Set appropriate resource limits in docker-compose.yml
4. **File Permissions:** Ensure proper file permissions for the workspace

## Troubleshooting

1. **Container won't start:** Check logs with `docker-compose logs dev-container`
2. **Connection refused:** Verify port 3000 is accessible and not blocked by firewall
3. **Permission errors:** Check volume mount permissions
4. **Git operations fail:** Verify git configuration in environment variables

## Next Steps

- Add authentication to the MCP server
- Implement SSL/TLS for secure connections
- Add more specialized tools for your development needs
- Set up automatic backups of the workspace
- Configure CI/CD pipelines within the container

This setup provides a complete development environment that Claude can interact with remotely, enabling code writing, deployment, and management from your mobile device or web interface.