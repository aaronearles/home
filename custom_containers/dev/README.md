# Development Container with NodeJS, Claude, VS Code, Terraform & Ansible

This Docker container provides a complete development environment with all the tools you need for modern infrastructure and application development.

## Included Tools

### Core Development Tools
- **Node.js 20.x LTS** - JavaScript runtime
- **Python 3** - With pip and venv
- **Git** - Version control
- **VS Code Server** (code-server) - Web-based IDE
- **Claude CLI** (@anthropic-ai/claude-code) - Official Anthropic AI coding assistant

### Infrastructure Tools
- **Terraform** - Infrastructure as Code
- **OpenTofu** - Open-source Terraform fork
- **Ansible** - Configuration management
- **AWS CLI** - Amazon Web Services CLI
- **Azure CLI** - Microsoft Azure CLI
- **Linode CLI** - Linode cloud platform CLI
- **kubectl** - Kubernetes command line tool
- **Helm** - Kubernetes package manager
- **Docker CLI** - Container management
- **PowerShell** - Cross-platform automation framework

### Node.js Development Tools
- **npm & yarn** - Package managers
- **TypeScript** - Static typing for JavaScript
- **Angular CLI** - Angular framework CLI
- **Vue CLI** - Vue.js framework CLI
- **Create React App** - React application generator
- **PM2** - Process manager
- **ESLint & Prettier** - Code linting and formatting

### Python Development Tools
- **Black** - Code formatter
- **Flake8** - Code linter
- **pytest** - Testing framework
- **Ansible libraries** - hvac, requests, jmespath, netaddr

### System Tools
- **tmux** - Terminal multiplexer
- **vim & nano** - Text editors
- **htop** - Process viewer
- **tree** - Directory tree viewer
- **jq** - JSON processor

## Build Instructions

### Step 1: Build the Docker Image

```bash
# Navigate to the directory containing the Dockerfile
cd ./custom_containers/dev

# Build the image (this will take several minutes)
docker build -t dev-environment:latest .
```

### Step 2: Run the Container

#### Option A: Basic Interactive Container
```bash
# Run with basic setup
docker run -it --rm \
  --name dev-container \
  -v $(pwd):/workspace \
  dev-environment:latest
```

#### Option B: Full Development Setup (Recommended)
```bash
# Run with port forwarding and volume mounts
docker run -it --rm \
  --name dev-container \
  -p 8080:8080 \
  -p 3000:3000 \
  -p 4200:4200 \
  -p 8000:8000 \
  -p 9000:9000 \
  -v $(pwd):/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  dev-environment:latest
```

#### Option C: Persistent Container with Named Volume
```bash
# Create a named volume for persistent storage
docker volume create dev-workspace

# Run with persistent storage
docker run -it --rm \
  --name dev-container \
  -p 8080:8080 \
  -p 3000:3000 \
  -p 4200:4200 \
  -p 8000:8000 \
  -p 9000:9000 \
  -v dev-workspace:/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  dev-environment:latest
```

## Using the Container

### Starting VS Code Server
```bash
# Inside the container, start code-server
code-server --bind-addr 0.0.0.0:8080 --auth none
```
Then access VS Code at `http://localhost:8080`

### Using Claude CLI
```bash
# Verify Claude CLI installation
claude doctor

# Start an interactive session (will prompt for authentication)
claude

# Note: Authentication requires active billing at console.anthropic.com
# Follow the OAuth process when prompted
```

### Using Terraform
```bash
# Initialize a Terraform project
terraform init

# Plan infrastructure changes
terraform plan

# Apply changes
terraform apply
```

### Using OpenTofu
```bash
# Initialize an OpenTofu project
tofu init

# Plan infrastructure changes
tofu plan

# Apply changes
tofu apply
```

### Using Ansible
```bash
# Run an Ansible playbook
ansible-playbook -i inventory playbook.yml

# Run ad-hoc commands
ansible all -i inventory -m ping
```

### Using Azure CLI
```bash
# Login to Azure
az login

# List subscriptions
az account list

# List virtual machines
az vm list
```

### Using Linode CLI
```bash
# Configure Linode CLI
linode-cli configure

# List Linode instances
linode-cli linodes list

# List domains
linode-cli domains list
```

### Using PowerShell
```bash
# Start PowerShell
pwsh

# Get help
Get-Help

# Import Azure PowerShell module (if installed)
Import-Module Az
```

### Development Workflow Examples

#### Node.js Project
```bash
# Create a new Node.js project
npm init -y
npm install express

# Start development server
npm start
```

#### Angular Project
```bash
# Create new Angular app
ng new my-app
cd my-app
ng serve --host 0.0.0.0 --port 4200
```

#### React Project
```bash
# Create new React app
npx create-react-app my-app
cd my-app
npm start
```

## Port Mapping

The container exposes the following ports:
- **8080**: VS Code Server
- **3000**: Node.js development server
- **4200**: Angular development server
- **8000**: Python development server
- **9000**: Additional development server

## Volume Mounts

- `/workspace`: Main working directory
- `/var/run/docker.sock`: Docker socket for Docker-in-Docker scenarios

## Environment Variables

You can customize the container by setting these environment variables:

```bash
# Set custom user ID and group ID
docker run -it --rm \
  --build-arg USERNAME=myuser \
  --build-arg USER_UID=1001 \
  --build-arg USER_GID=1001 \
  dev-environment:latest
```

## Troubleshooting

### Permission Issues
If you encounter permission issues with mounted volumes, ensure the container user has the same UID/GID as your host user:

```bash
# Check your host UID/GID
id

# Rebuild with your UID/GID
docker build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -t dev-environment:latest .
```

### Docker Socket Access
If you need to use Docker inside the container, ensure the Docker socket is mounted and your user has access:

```bash
# Add user to docker group (inside container)
sudo usermod -aG docker $USER
```

### VS Code Server Issues
If VS Code Server doesn't start properly:

```bash
# Check if the port is already in use
netstat -tulpn | grep 8080

# Try a different port
code-server --bind-addr 0.0.0.0:8081
```

## Customization

You can extend this Dockerfile to add more tools or modify the configuration:

1. Edit the Dockerfile to add additional packages
2. Rebuild the image: `docker build -t dev-environment:latest .`
3. Update any scripts or configurations as needed

## Security Considerations

- The container runs as a non-root user for security
- VS Code Server is configured without authentication for local development
- Docker socket access should be used carefully in production environments
- Consider using Docker secrets for sensitive configuration