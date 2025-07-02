# HOME 2.0 - Modern Self-Hosted Infrastructure

A comprehensive Infrastructure as Code (IaC) homelab implementation featuring containerized services, automated provisioning, and security-first architecture. This repository serves as a complete blueprint for deploying production-ready self-hosted infrastructure across multi-tier environments.

## 🏗️ Architecture Overview

This homelab implements a **multi-tier containerized architecture** with:

- **Three segregated Docker environments**: DMZ, Internal, and Lab tiers
- **Multi-cloud infrastructure**: Proxmox (on-premises) + Linode + Cloudflare integration  
- **Comprehensive service mesh**: 50+ self-hosted applications and services
- **Security-first design**: WAF, SSO, network segmentation, and automated certificate management
- **Full automation**: Infrastructure provisioning (Terraform) + Configuration management (Ansible)

## 🎯 Design Principles

- **Infrastructure as Code**: Git serves as the single source of truth for all infrastructure
- **Environment Agnostic**: Variable-driven configurations supporting lab/staging/production deployments
- **Security by Design**: Public repository encouraging secure secret management and best practices
- **Simplicity Over Complexity**: Preference for straightforward solutions over complex templating
- **Self-Hosted First**: Emphasis on data sovereignty and privacy

---

## 📋 Service Catalog

### 🔐 Authentication & Security
- **Authentik** - Enterprise SSO/OIDC provider
- **Vaultwarden** - Self-hosted password manager
- **HashiCorp Vault** - Secrets management
- **Wazuh** - SIEM/security monitoring platform

### 🌐 Reverse Proxy & Networking  
- **Traefik** (Multi-instance) - Load balancing with WAF capabilities
- **Cloudflared** - Secure tunnel management
- **Squid** - Caching proxy server

### 📊 Monitoring & Observability
- **Gatus** - Service health monitoring
- **Grafana** - Data visualization
- **Uptime Kuma** - Uptime monitoring
- **Beszel** - Infrastructure monitoring
- **Dozzle** - Docker log aggregation

### 💻 Development & Productivity
- **Code Server** - Web-based VS Code IDE
- **Forgejo** - Self-hosted Git service
- **Nextcloud AIO** - Collaboration platform
- **Hedgedoc** - Collaborative markdown editor
- **IT Tools** - Developer utilities collection

### 🎵 Media & Entertainment
- **Jellyfin** - Media server with GPU transcoding
- **Immich** - Self-hosted photo management

### 🏠 Home Automation & Communication
- **Home Assistant** - Home automation platform
- **Synapse** - Matrix homeserver
- **LibreChat/OpenWebUI** - AI chat interfaces

### 💼 Business & Finance
- **Actual** - Personal finance management
- **Firefly III** - Financial management
- **Vikunja** - Task management
- **Paperless-NGX** - Document management

### 🤖 AI & Machine Learning
- **AnythingLLM** - Document chat with LLM
- **OpenAI Proxy** - API proxy services

---

## 🏛️ Infrastructure Components

### 🖥️ Compute & Virtualization
- **Proxmox VE**: Primary virtualization platform with VM/LXC management
- **Docker**: Container orchestration across multiple environments
- **Kubernetes**: K3s cluster for container orchestration (testing)

### ☁️ Cloud Integration
- **Linode**: External proxy instances and public-facing services  
- **Cloudflare**: DNS management, CDN, and secure tunnel services
- **AWS/Azure**: Multi-cloud deployment configurations

### 🔧 Automation & Management
- **Terraform**: Infrastructure provisioning across multiple providers
- **Ansible**: Configuration management and system hardening
- **Watchtower**: Automated container updates
- **Dockge**: Docker Compose stack management

---

## 📁 Repository Structure

```
├── ansible/              # Configuration management & automation
│   ├── playbook/         # Ansible playbooks for system configuration
│   └── inventory/        # Environment-specific inventory files
├── dockerdmz01/          # DMZ tier - External-facing services
├── dockerint01/          # Internal tier - Private services  
├── dockerlab01/          # Lab tier - Development & testing
├── terraform/            # Infrastructure provisioning
│   ├── aws/              # AWS resources
│   ├── azure/            # Azure resources  
│   ├── cloudflare/       # DNS & CDN management
│   ├── linode/           # Linode instances
│   └── proxmox/          # VM/LXC provisioning
├── scripts/              # Automation scripts
│   ├── bash/             # System setup & maintenance
│   ├── cloudflare_ddns/  # Dynamic DNS management
│   └── proxmox/          # VM template management
└── docs/                 # Documentation & reference materials
```

---

## 🚀 Quick Start

### Prerequisites
- Proxmox VE cluster (primary compute)
- Cloudflare account (DNS management)
- Terraform >= 1.0
- Ansible >= 2.9
- Docker & Docker Compose

### Deployment Steps

1. **Clone Repository**
   ```bash
   git clone <repository-url>
   cd home
   ```

2. **Configure Variables**
   ```bash
   # Copy and edit terraform variables
   cp terraform/proxmox/sample.tfvars terraform/proxmox/terraform.tfvars
   
   # Update Ansible inventory
   vim ansible/inventory/lab.yml
   ```

3. **Provision Infrastructure**
   ```bash
   # Deploy VMs/LXC containers
   cd terraform/proxmox
   terraform init && terraform apply
   ```

4. **Configure Systems**
   ```bash
   # Run Ansible playbooks
   cd ansible
   ansible-playbook -i inventory/lab.yml playbook/terminal-setup.yml
   ```

5. **Deploy Services**
   ```bash
   # Start core services
   cd dockerint01/traefik
   docker-compose up -d
   
   # Deploy additional services as needed
   ```

---

## 🔒 Security Features

- **Network Segmentation**: Isolated Docker networks and VLANs
- **Web Application Firewall**: Coraza-powered WAF with OWASP rule sets
- **Single Sign-On**: Centralized authentication via Authentik
- **Certificate Management**: Automated Let's Encrypt via DNS challenges
- **Secret Management**: HashiCorp Vault integration
- **Access Control**: Cloudflare Access for external services
- **SIEM**: Comprehensive logging and monitoring via Wazuh

---

## 🔧 Management & Operations

### Monitoring Dashboards
- **Gatus**: https://status.yourdomain.com - Service health monitoring
- **Grafana**: https://grafana.yourdomain.com - Infrastructure metrics
- **Authentik**: https://auth.yourdomain.com - User management

### Key Management Commands
```bash
# View service status
docker-compose ps

# Update all containers
docker-compose pull && docker-compose up -d

# Check Traefik routing
docker logs traefik

# Backup Vaultwarden
./scripts/backup-vaultwarden.sh
```

---

## 🤝 Contributing

This repository is designed to be publicly shareable and educational. When contributing:

- Follow Infrastructure as Code best practices
- Use variables for environment-specific configurations  
- Document any new services or significant changes
- Ensure secrets are properly externalized
- Test changes in lab environment first

---

## 📚 Additional Resources

- **Documentation**: See `/docs` directory for detailed guides
- **Configuration Examples**: Check `/zz_Examples` for reference configurations  
- **Terraform Modules**: Reusable infrastructure components in `/terraform`
- **Scripts**: Automation utilities in `/scripts`

---

*This homelab represents a sophisticated, production-ready infrastructure that balances security, functionality, and ease of management while maintaining strong self-hosting principles.*