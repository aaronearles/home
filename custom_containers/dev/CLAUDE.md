# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a **containerized development environment** that provides a comprehensive, portable development setup with all necessary tools for modern software development, infrastructure management, and cloud operations. The container is built on Ubuntu 22.04 and includes a complete toolchain for Node.js, Python, cloud infrastructure, and DevOps workflows.

## Container Architecture

### Core Development Stack
- **Runtime Environments**: Node.js 20.x LTS, Python 3 with pip/venv
- **Development IDE**: VS Code Server (code-server) for web-based development
- **AI Integration**: Claude CLI (@anthropic-ai/claude-code) for AI-assisted coding
- **Container Platform**: Docker CLI with Docker-in-Docker support

### Infrastructure & DevOps Tools
- **Infrastructure as Code**: Terraform and OpenTofu for provisioning
- **Configuration Management**: Ansible with common libraries (hvac, requests, jmespath, netaddr)
- **Cloud Platforms**: AWS CLI, Azure CLI, Linode CLI, kubectl, Helm for Kubernetes
- **Cross-Platform Automation**: PowerShell for scripting and automation
- **Development Workflow**: Git, tmux, various text editors

### Language-Specific Tooling
- **JavaScript/TypeScript**: Angular CLI, Vue CLI, Create React App, PM2, ESLint, Prettier
- **Python**: Black (formatter), Flake8 (linter), pytest (testing)
- **System Tools**: htop, tree, jq, zip utilities

## Common Development Commands

### Container Management
```bash
# Build the development container
docker build -t dev-environment:latest .

# Run interactive container with port forwarding
docker run -it --rm \
  --name dev-container \
  -p 8080:8080 -p 3000:3000 -p 4200:4200 -p 8000:8000 -p 9000:9000 \
  -v $(pwd):/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  dev-environment:latest

# Create persistent workspace
docker volume create dev-workspace
docker run -it --rm \
  --name dev-container \
  -p 8080:8080 -p 3000:3000 -p 4200:4200 -p 8000:8000 -p 9000:9000 \
  -v dev-workspace:/workspace \
  -v /var/run/docker.sock:/var/run/docker.sock \
  dev-environment:latest
```

### Development Environment Setup
```bash
# Start VS Code Server (web-based IDE)
code-server --bind-addr 0.0.0.0:8080 --auth none

# Initialize Claude CLI (requires authentication)
claude doctor
claude  # Start interactive session

# Setup development aliases (already configured in container)
alias k="kubectl"
alias tf="terraform"
alias tofu="tofu"
alias linode="linode-cli"
alias ll="ls -la"
```

### Framework-Specific Development
```bash
# Node.js project setup
npm init -y
npm install express
npm start

# Angular development server
ng new my-app
cd my-app
ng serve --host 0.0.0.0 --port 4200

# React development server
npx create-react-app my-app
cd my-app
npm start

# Python development with virtual environment
python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
```

### Infrastructure Operations
```bash
# Terraform workflow
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -auto-approve

# OpenTofu workflow (drop-in replacement for Terraform)
tofu init
tofu plan -var-file="terraform.tfvars"
tofu apply -auto-approve

# Ansible operations
ansible-playbook -i inventory playbook.yml
ansible all -i inventory -m ping

# Kubernetes operations
kubectl get nodes
kubectl apply -f deployment.yaml
helm install my-release chart/

# AWS CLI operations
aws configure
aws s3 ls
aws ec2 describe-instances

# Azure CLI operations
az login
az account list
az vm list

# Linode CLI operations
linode-cli configure
linode-cli linodes list
linode-cli domains list

# PowerShell operations
pwsh
Get-Help
Import-Module Az
```

## Port Configuration

The container exposes these ports for development:
- **8080**: VS Code Server web interface
- **3000**: Node.js development server (Express, React default)
- **4200**: Angular development server
- **8000**: Python development server (Django, Flask)
- **9000**: Additional development server

## Development Workflow Patterns

### Multi-Language Development
This container supports simultaneous development across multiple languages and frameworks:
- Run VS Code Server on port 8080 for IDE access
- Use different ports for different framework development servers
- Leverage Docker-in-Docker for containerized application development

### Cloud-Native Development
The container includes comprehensive cloud-native development tools:
- Use kubectl and Helm for Kubernetes development
- Terraform for infrastructure provisioning
- Ansible for configuration management
- AWS CLI for cloud operations

### AI-Assisted Development
The container includes the Claude CLI for AI-assisted coding:
- Authenticate with `claude doctor` on first use
- Use `claude` for interactive AI coding sessions
- Requires active billing at console.anthropic.com

## Security Considerations

### User Configuration
- Container runs as non-root user `developer` (UID 1000)
- Sudo access configured for necessary operations
- User permissions properly configured for development workflow

### Docker Socket Access
- Docker socket mounted for Docker-in-Docker scenarios
- User added to docker group for container management
- Use carefully in production environments

### Authentication Requirements
- Claude CLI requires Anthropic API authentication
- VS Code Server configured without authentication for local development
- Consider using Docker secrets for sensitive configuration

## Customization Patterns

### Container Customization
```bash
# Custom user ID/GID for host compatibility
docker build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -t dev-environment:latest .

# Custom username
docker build --build-arg USERNAME=myuser -t dev-environment:latest .
```

### Environment Extensions
To add additional tools or modify configuration:
1. Edit the Dockerfile to add packages via apt-get, pip, or npm
2. Rebuild the image: `docker build -t dev-environment:latest .`
3. Update environment variables or aliases in the user setup section

### Persistent Configuration
- Use named volumes for persistent workspace data
- Mount host directories for project-specific configurations
- Configure development tools through their respective config files

## Troubleshooting Common Issues

### Permission Problems
```bash
# Check host UID/GID
id

# Rebuild with correct UID/GID
docker build --build-arg USER_UID=$(id -u) --build-arg USER_GID=$(id -g) -t dev-environment:latest .
```

### Port Conflicts
```bash
# Check port usage
netstat -tulpn | grep 8080

# Use alternative ports
code-server --bind-addr 0.0.0.0:8081
```

### Docker Socket Access
```bash
# Verify docker group membership
groups

# Add user to docker group if needed
sudo usermod -aG docker $USER
```

This development container provides a complete, portable development environment suitable for modern software development, infrastructure management, and cloud-native application development.