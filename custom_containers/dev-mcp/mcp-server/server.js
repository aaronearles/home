const express = require('express');
const WebSocket = require('ws');
const fs = require('fs-extra');
const path = require('path');
const { execSync, spawn } = require('child_process');
const simpleGit = require('simple-git');

const app = express();
const server = require('http').createServer(app);
const wss = new WebSocket.Server({ server });

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

// HTTP API endpoints
app.use(express.json());

app.get('/tools', (req, res) => {
  res.json({ tools });
});

app.post('/tools/:toolName', async (req, res) => {
  const { toolName } = req.params;
  const args = req.body;
  
  if (toolHandlers[toolName]) {
    try {
      const result = await toolHandlers[toolName](args);
      res.json({ success: true, result });
    } catch (error) {
      res.status(500).json({ success: false, error: error.message });
    }
  } else {
    res.status(404).json({ success: false, error: `Unknown tool: ${toolName}` });
  }
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

// Basic web interface
app.get('/', (req, res) => {
  res.send(`
    <html>
      <head><title>MCP Development Server</title></head>
      <body>
        <h1>MCP Development Server</h1>
        <p>Server is running on port ${process.env.PORT || 3000}</p>
        <h2>Available Tools:</h2>
        <ul>
          ${tools.map(tool => `<li><strong>${tool.name}</strong>: ${tool.description}</li>`).join('')}
        </ul>
        <h2>API Endpoints:</h2>
        <ul>
          <li>GET /tools - List all available tools</li>
          <li>POST /tools/:toolName - Execute a tool</li>
          <li>WebSocket connection available for real-time communication</li>
        </ul>
      </body>
    </html>
  `);
});

// Start server
const PORT = process.env.PORT || 3000;
server.listen(PORT, '0.0.0.0', () => {
  console.log(`Development Server running on port ${PORT}`);
  console.log(`WebSocket server available for real-time communication`);
  console.log(`HTTP API available at http://localhost:${PORT}`);
});