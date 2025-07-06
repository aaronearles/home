# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Repository Overview

This is a comprehensive Infrastructure as Code (IaC) homelab implementation featuring a **multi-tier containerized architecture** with three segregated Docker environments:

- **dockerdmz01/**: DMZ tier - External-facing services with WAF protection
- **dockerint01/**: Internal tier - Private services behind authentication 
- **dockerlab01/**: Lab tier - Development and testing services

The infrastructure spans **multi-cloud deployment** (Proxmox on-premises + Linode + Cloudflare) with **50+ self-hosted applications** and comprehensive automation via Terraform and Ansible.

## Key Architecture Patterns

### Docker Compose Structure
All services follow a standardized docker-compose.yml format with consistent property ordering:
1. `image` → `container_name` → `restart` → `env_file/environment` → `volumes` → `ports` → `networks` → `depends_on` → `devices/cap_add` → `healthcheck` → `labels`

### Network Architecture
- **Traefik** serves as the primary reverse proxy with multiple instances (DMZ, Internal, Lab)
- **Network Segmentation**: Services use `traefik` (external) and `backend` (internal) networks
- **SSL Termination**: Automated Let's Encrypt certificates via Cloudflare DNS challenges
- **WAF Integration**: Coraza-powered Web Application Firewall with OWASP rule sets

### Authentication & Security
- **Authentik**: Centralized SSO/OIDC provider for all internal services
- **Vaultwarden**: Self-hosted password management
- **HashiCorp Vault**: Enterprise secrets management
- **Network Isolation**: Services properly segregated with minimal exposure

## Common Development Commands

### Infrastructure Provisioning
```bash
# Deploy Proxmox VMs/LXC containers
cd terraform/proxmox/vm
terraform init && terraform plan && terraform apply

# Deploy Linode proxy instances  
cd terraform/linode/proxy
terraform init && terraform apply

# Manage Cloudflare DNS/tunnels
cd terraform/cloudflare
terraform init && terraform apply
```

### Configuration Management
```bash
# Run Ansible playbooks for system setup
cd ansible
ansible-playbook -i inventory/lab.yml playbook/terminal-setup.yml -u root

# Deploy to specific hosts
ansible-playbook -i "172.20.100.57," playbook/apt-setup.yml

# Test connectivity
ansible hosts -m ping -i inventory/lab.ini
```

### Docker Service Management
```bash
# Deploy core infrastructure (Traefik first)
cd dockerint01/traefik
docker-compose up -d

# Deploy specific service stack
cd dockerint01/jellyfin
docker-compose up -d

# Update all containers in a stack
docker-compose pull && docker-compose up -d

# View service logs
docker-compose logs -f [service_name]

# Check Traefik routing and labels
docker logs traefik
```

### Terraform Operations
```bash
# Standard Terraform workflow
terraform init
terraform plan -var-file="terraform.tfvars"
terraform apply -auto-approve

# Destroy specific resources
terraform destroy -target=resource_type.resource_name

# Import existing infrastructure
terraform import resource_type.resource_name resource_id
```

## Critical Configuration Patterns

### Environment Variables
- **Terraform**: Use `*.auto.tfvars` for automatic loading, `sample.tfvars` as templates
- **Docker**: Services use `.env` files for environment-specific configurations
- **Secrets**: Managed via HashiCorp Vault integration, never committed to git

### Docker Compose Standardization Patterns

**All docker-compose.yml files follow consistent structure and formatting:**

#### Property Order Standard
Services must follow this exact order:
1. `image`
2. `container_name` 
3. `restart` (always use `unless-stopped`)
4. `env_file` / `environment`
5. `volumes`
6. `ports` (commented out if using Traefik)
7. `networks`
8. `depends_on`
9. `devices` / `cap_add` (if needed)
10. `command` / `entrypoint` (if needed)
11. `healthcheck`
12. `labels` (always last, grouped together)

#### Formatting Standards
- **Indentation**: 2 spaces throughout
- **Comments**: Use `#` with space, organize inline when brief
- **Ports**: Comment out when using Traefik proxy
- **Quotes**: Consistent quote usage in labels (use `-` format)
- **Spacing**: Empty line between services and major sections

#### Traefik Label Patterns
Standard Traefik configuration for internal services:
```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.SERVICE_NAME.rule=Host(`service.internal.earles.io`)
  - traefik.http.routers.SERVICE_NAME.entrypoints=websecure
  - traefik.http.routers.SERVICE_NAME.tls.certresolver=production
```

For lab environment services:
```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.SERVICE_NAME.rule=Host(`service.lab.earles.io`)
  - traefik.http.routers.SERVICE_NAME.entrypoints=websecure
  - traefik.http.routers.SERVICE_NAME.tls.certresolver=production
```

For DMZ/external services:
```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.SERVICE_NAME.rule=Host(`service.earles.io`)
  - traefik.http.routers.SERVICE_NAME.entrypoints=websecure
  - traefik.http.routers.SERVICE_NAME.tls.certresolver=production
```

#### Network Definitions
```yaml
networks:
  traefik:
    external: true  # Shared across services
  backend:
    external: false # Internal to stack
```

#### Multi-Service Stack Standards
For services with databases:
```yaml
services:
  app:
    image: app/image:latest
    container_name: app-name
    restart: unless-stopped
    env_file:
      - .env
    volumes:
      - ./data:/app/data
    networks:
      - traefik
      - backend
    depends_on:
      - database
    labels:
      - traefik.enable=true
      # ... traefik config

  database:
    image: postgres:latest
    container_name: app-db
    restart: unless-stopped
    environment:
      - POSTGRES_DB=dbname
      - POSTGRES_USER=user
      - POSTGRES_PASSWORD=password
    volumes:
      - db_data:/var/lib/postgresql/data
    networks:
      - backend

volumes:
  db_data:

networks:
  traefik:
    external: true
  backend:
    external: false
```

### Tier-Specific Configuration Patterns

#### dockerint01/ (Internal Tier)
- Domain pattern: `service.internal.earles.io`
- Full Traefik integration with SSL
- Backend networks for database isolation
- Environment files for configuration

#### dockerdmz01/ (DMZ Tier) 
- Domain pattern: `service.earles.io`
- External-facing services with WAF protection
- Authentik proxy integration
- Enhanced security labeling

#### dockerlab01/ (Lab Tier)
- Domain pattern: `service.lab.earles.io` 
- Development and testing services
- Simplified configurations
- Optional SSL certificates

### Container Naming Standards
- Single service: Use descriptive name matching service function
- Multi-service: Use `app-component` format (e.g., `firefly-db`, `wazuh-dashboard`)
- Avoid generic names like `app` or `web` when possible

### Volume and Data Management
- **Local volumes**: Use `./data:/app/data` pattern for persistence
- **Named volumes**: For databases and shared storage
- **Bind mounts**: For configuration files and logs
- **Read-only**: Mark configuration mounts as `:ro` when appropriate

### Development Workflow for Compose Files
1. **Always** add `container_name` for easier management
2. **Always** use `restart: unless-stopped` for production services  
3. **Comment out** ports when using Traefik (keep for reference)
4. **Group labels** at the end in consistent order
5. **Use environment files** for sensitive or environment-specific config
6. **Add health checks** for critical services
7. **Follow network patterns** (traefik + backend for multi-service stacks)

## Infrastructure Dependencies

### Service Hierarchy
1. **Core Infrastructure**: Traefik → DNS → Certificates
2. **Authentication**: Authentik → Vault → SSO integration  
3. **Monitoring**: Gatus → Grafana → Alerting
4. **Applications**: All other services depend on core + auth

### Resource Requirements
- **Traefik**: Requires access to Docker socket and Cloudflare API
- **Jellyfin**: Needs GPU passthrough for transcoding (`/dev/dri/renderD128`)
- **Databases**: Persistent volumes for data retention
- **VPN Services**: Require `NET_ADMIN` capability and `/dev/net/tun`

## Development Workflow

### Adding New Services
1. Create service directory under appropriate docker tier
2. Use standardized docker-compose.yml structure
3. Configure Traefik labels for routing
4. Add monitoring endpoints to Gatus
5. Document in service catalog

### Infrastructure Changes
1. Test in `dockerlab01/` environment first
2. Update Terraform configurations with proper variables
3. Run Ansible playbooks for system configuration
4. Deploy to staging (`dockerint01/`) then production (`dockerdmz01/`)

### Secret Management
- Use Vault for production secrets
- Environment variables for non-sensitive configuration
- `.env.sample` files as templates
- Never commit actual secrets to repository

## Monitoring & Observability

### Health Monitoring
- **Gatus**: Service availability monitoring at `status.yourdomain.com`
- **Uptime Kuma**: Application uptime tracking
- **Beszel**: Infrastructure resource monitoring

### Log Aggregation
- **Dozzle**: Real-time Docker log viewing
- **Grafana**: Metrics visualization and alerting
- **Wazuh**: SIEM and security event monitoring

### Service Discovery
Services are discoverable via:
- Traefik dashboard at `:8080`
- DNS resolution through internal domain
- Service mesh networking via Docker networks

## Security Considerations

### Network Security
- Services isolated via Docker networks
- WAF protection for external services
- VPN tunneling for sensitive applications
- Cloudflare Access for additional protection

### Data Protection
- Encrypted at rest via container volumes
- TLS termination at Traefik
- Regular backups via automated scripts
- Secret rotation through Vault

This repository maintains Infrastructure as Code principles with Git as the single source of truth for all infrastructure configurations.