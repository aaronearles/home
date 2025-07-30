# Docker Standards

## Docker Compose Structure Standards

### Property Order Standard
All docker-compose.yml files must follow this exact property order for services:

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

### Formatting Standards

#### General Formatting
- **Indentation**: 2 spaces throughout
- **Comments**: Use `#` with space, organize inline when brief
- **Ports**: Comment out when using Traefik proxy (keep for reference)
- **Quotes**: Consistent quote usage in labels (use `-` format)
- **Spacing**: Empty line between services and major sections

#### Container Naming Standards
- **Single service**: Use descriptive name matching service function
- **Multi-service**: Use `app-component` format (e.g., `firefly-db`, `wazuh-dashboard`)
- **Avoid generic names** like `app` or `web` when possible

#### Restart Policy
- **Always** use `restart: unless-stopped` for production services

## Network Architecture Standards

### Network Definitions
```yaml
networks:
  traefik:
    external: true  # Shared across services
  backend:
    external: false # Internal to stack
```

### Network Segmentation
- **traefik**: External network for reverse proxy access
- **backend**: Internal network for database and service isolation
- Services requiring external access use both networks
- Database services only use backend network

## Traefik Integration Standards

### Domain Patterns by Tier

#### Internal Tier (dockerint01/)
```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.SERVICE_NAME.rule=Host(`service.internal.earles.io`)
  - traefik.http.routers.SERVICE_NAME.entrypoints=websecure
  - traefik.http.routers.SERVICE_NAME.tls.certresolver=production
```

#### Lab Tier (dockerlab01/)
```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.SERVICE_NAME.rule=Host(`service.lab.earles.io`)
  - traefik.http.routers.SERVICE_NAME.entrypoints=websecure
  - traefik.http.routers.SERVICE_NAME.tls.certresolver=production
```

#### DMZ Tier (dockerdmz01/)
```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.SERVICE_NAME.rule=Host(`service.earles.io`)
  - traefik.http.routers.SERVICE_NAME.entrypoints=websecure
  - traefik.http.routers.SERVICE_NAME.tls.certresolver=production
```

### Label Organization
- **Always** place labels at the end of service definition
- **Group labels** together with proper indentation
- **Use consistent** router naming based on service name

## Multi-Service Stack Template

### Application with Database
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
      - traefik.docker.network=traefik
      - traefik.http.routers.app-name.rule=Host(`service.internal.earles.io`)
      - traefik.http.routers.app-name.entrypoints=websecure
      - traefik.http.routers.app-name.tls.certresolver=production

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

## Volume and Data Management Standards

### Volume Patterns
- **Local volumes**: Use `./data:/app/data` pattern for persistence
- **Named volumes**: For databases and shared storage
- **Bind mounts**: For configuration files and logs
- **Read-only**: Mark configuration mounts as `:ro` when appropriate

### Data Persistence
- **Database volumes**: Always use named volumes for data retention
- **Application data**: Use bind mounts for easy access and backup
- **Configuration**: Mount configuration files as read-only when possible

## Environment and Secret Management

### Environment Files

#### Environment File Structure
```yaml
# In docker-compose.yml - prefer env_file over inline environment
services:
  app:
    image: app/image:latest
    container_name: app-name
    restart: unless-stopped
    env_file:
      - .env
    # Avoid inline environment for sensitive data
    # environment:
    #   - SENSITIVE_VAR=value
```

#### Environment File Patterns
- **Use `.env` files** for environment-specific configurations
- **Create `.env.sample`** files as templates for new deployments
- **Never commit** actual secrets to repository (add `.env` to `.gitignore`)
- **Use HashiCorp Vault** for production secrets

#### .env File Template
```bash
# Service Configuration
SERVICE_NAME=myapp
SERVICE_VERSION=latest
SERVICE_PORT=3000

# Database Configuration
DB_HOST=database
DB_PORT=5432
DB_NAME=appdb
DB_USER=dbuser
DB_PASSWORD=secure_password_here

# Authentication
ADMIN_USER=admin
ADMIN_PASSWORD=change_me_please
ADMIN_EMAIL=admin@yourdomain.com

# External Services
API_KEY=your_api_key_here
SECRET_KEY=your_secret_key_here
```

#### .env.sample File Template
```bash
# Service Configuration Template
# Copy this file to .env and update with your actual values

# Service Configuration
SERVICE_NAME=myapp
SERVICE_VERSION=latest
SERVICE_PORT=3000

# Database Configuration
DB_HOST=database
DB_PORT=5432
DB_NAME=appdb
DB_USER=dbuser
DB_PASSWORD=your_secure_password_here

# Authentication
ADMIN_USER=admin
ADMIN_PASSWORD=your_secure_admin_password
ADMIN_EMAIL=admin@yourdomain.com

# External Services
API_KEY=your_api_key_here
SECRET_KEY=your_secret_key_here
```

#### Environment File Best Practices
1. **Always prefer `env_file` over inline `environment`** for sensitive data
2. **Use descriptive variable names** that indicate their purpose
3. **Group related variables** with comments for organization
4. **Include default values** in `.env.sample` where appropriate
5. **Document required vs optional** variables in comments
6. **Use consistent naming conventions** (UPPER_CASE with underscores)

### Bcrypt Hash Escaping
For authentication services using bcrypt hashes in `.env` files:
```bash
# ❌ Wrong - Raw bcrypt hash
USERS=username:$2a$10$abcdef123456

# ✅ Correct - Escaped for Docker Compose  
USERS=username:$$2a$$10$$abcdef123456
```

## Development Workflow Standards

### Compose File Development Process
1. **Always** add `container_name` for easier management
2. **Always** use `restart: unless-stopped` for production services  
3. **Comment out** ports when using Traefik (keep for reference)
4. **Group labels** at the end in consistent order
5. **Use environment files** for sensitive or environment-specific config
6. **Add health checks** for critical services
7. **Follow network patterns** (traefik + backend for multi-service stacks)

### Service Deployment Order
1. **Core Infrastructure**: Deploy Traefik first
2. **Dependencies**: Deploy databases and supporting services
3. **Applications**: Deploy main application services
4. **Monitoring**: Add health checks and monitoring endpoints

## Common Docker Commands

### Service Management
```bash
# Deploy specific service stack
docker-compose up -d

# Update all containers in a stack
docker-compose pull && docker-compose up -d

# View service logs
docker-compose logs -f [service_name]

# Restart specific service
docker-compose restart [service_name]
```

### Troubleshooting
```bash
# Check container status
docker-compose ps

# View container resource usage
docker stats

# Execute commands in running container
docker-compose exec [service_name] /bin/bash

# View detailed container information
docker inspect [container_name]
```

## Health Checks and Monitoring

### Health Check Standards
```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8080/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 60s
```

### Monitoring Integration
- **Always** add services to Gatus for availability monitoring
- **Include** health check endpoints where available
- **Use** proper service discovery labels for monitoring tools

## Security Standards

### Network Security
- **Isolate services** using Docker networks
- **Minimize exposed ports** (prefer Traefik routing)
- **Use backend networks** for database access
- **Implement proper** service-to-service communication

### Container Security
- **Run containers** as non-root when possible
- **Use specific image tags** instead of `latest`
- **Mount secrets** as read-only volumes
- **Limit container capabilities** with `cap_drop` when needed

## Traefik Label Configuration Patterns

### Basic Service Configuration

#### Standard Labels (Required)
```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.SERVICE_NAME.rule=Host(`service.domain.tld`)
  - traefik.http.routers.SERVICE_NAME.entrypoints=websecure
  - traefik.http.routers.SERVICE_NAME.tls.certresolver=production
```

#### Optional Labels
```yaml
labels:
  # Custom service port (if not 80/443)
  - traefik.http.services.SERVICE_NAME.loadbalancer.server.port=8080
  
  # HTTPS backend service
  - traefik.http.services.SERVICE_NAME.loadbalancer.server.scheme=https
  
  # Disable host header forwarding
  - traefik.http.services.SERVICE_NAME.loadbalancer.passHostHeader=false
```

### Advanced Routing Rules

#### Multiple Host Matching
```yaml
labels:
  # Using OR operator (recommended)
  - traefik.http.routers.authentik.rule=Host(`authentik.internal.earles.io`) || Host(`auth.earles.io`)
  
  # Using HostRegexp (alternative)
  - traefik.http.routers.authentik.rule=HostRegexp(`^auth\.earles\.io$|^authentik\.internal\.earles\.io$`)
  
  # Case-insensitive matching
  - traefik.http.routers.service.rule=HostRegexp(`(?i)^service\.domain\.tld$`)
```

#### Path-Based Routing
```yaml
labels:
  - traefik.http.routers.service.rule=Host(`domain.tld`) && PathPrefix(`/api`)
  - traefik.http.routers.service.rule=Host(`domain.tld`) && Path(`/specific/path`)
```

#### Service-Specific Port Configuration
```yaml
labels:
  # Custom application port
  - traefik.http.services.vault.loadbalancer.server.port=8200
  - traefik.http.services.vault.loadbalancer.server.scheme=https
  
  # Standard web service
  - traefik.http.services.app.loadbalancer.server.port=3000
```

### Authentication Middleware

#### Basic Authentication
```yaml
labels:
  - traefik.http.routers.service.middlewares=auth
  - traefik.http.middlewares.auth.basicauth.usersfile=/etc/traefik/conf/authorizedusers
```

#### Forward Authentication (Authentik)
```yaml
labels:
  # Authentik proxy configuration
  - traefik.http.routers.authentik.rule=Host(`app.company`) && PathPrefix(`/outpost.goauthentik.io/`)
  - traefik.http.middlewares.authentik.forwardauth.address=http://authentik-proxy:9000/outpost.goauthentik.io/auth/traefik
  - traefik.http.middlewares.authentik.forwardauth.trustForwardHeader=true
  - traefik.http.middlewares.authentik.forwardauth.authResponseHeaders=X-authentik-username,X-authentik-groups,X-authentik-email,X-authentik-name,X-authentik-uid,X-authentik-jwt,X-authentik-meta-jwks,X-authentik-meta-outpost,X-authentik-meta-provider,X-authentik-meta-app,X-authentik-meta-version
```

#### Forward Authentication (TinyAuth)
```yaml
labels:
  # TinyAuth service configuration
  - traefik.http.middlewares.tinyauth.forwardauth.address=http://tinyauth:3000/api/auth/traefik
  - traefik.http.middlewares.tinyauth.forwardauth.trustForwardHeader=true
  - traefik.http.middlewares.tinyauth.forwardauth.authResponseHeaders=X-User,X-Email,X-Groups
  
  # Protected service using TinyAuth
  - traefik.http.routers.protected-service.middlewares=tinyauth@docker
```

### Security Middleware

#### Web Application Firewall (WAF)
```yaml
labels:
  # Enable WAF protection
  - traefik.http.routers.service.middlewares=waf@file
  
  # Combined middlewares (WAF + Auth)
  - traefik.http.routers.service.middlewares=waf@file,auth
```

#### HTTPS Redirect
```yaml
labels:
  # HTTP to HTTPS redirect
  - traefik.http.routers.service-http.rule=Host(`service.domain.tld`)
  - traefik.http.routers.service-http.entrypoints=web
  - traefik.http.routers.service-http.middlewares=redirect-to-https
  - traefik.http.middlewares.redirect-to-https.redirectscheme.scheme=https
```

### SSL/TLS Configuration

#### Certificate Resolvers
```yaml
labels:
  # Production certificates
  - traefik.http.routers.service.tls.certresolver=production
  
  # Staging certificates (for testing)
  - traefik.http.routers.service.tls.certresolver=staging
  
  # Manual TLS (no automatic certificates)
  - traefik.http.routers.service.tls=true
```

#### SAN and Wildcard Certificates
```yaml
labels:
  # Multiple domains with single certificate
  - traefik.http.routers.service.tls.domains[0].main=domain.tld
  - traefik.http.routers.service.tls.domains[0].sans=*.domain.tld,sub.domain.tld
```

### Service Discovery and Load Balancing

#### Multi-Container Load Balancing
```yaml
labels:
  # Sticky sessions
  - traefik.http.services.service.loadbalancer.sticky.cookie=true
  - traefik.http.services.service.loadbalancer.sticky.cookie.name=server
  
  # Health checks
  - traefik.http.services.service.loadbalancer.healthcheck.path=/health
  - traefik.http.services.service.loadbalancer.healthcheck.interval=30s
```

#### Service Weight Distribution
```yaml
labels:
  # Service weight for load balancing
  - traefik.http.services.service.loadbalancer.server.weight=100
  
  # Multiple backend servers
  - traefik.http.services.service.loadbalancer.server.port=8080
  - traefik.http.services.service.loadbalancer.server.scheme=http
```

### Common Service Examples

#### Web Application (Standard)
```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.webapp.rule=Host(`app.internal.earles.io`)
  - traefik.http.routers.webapp.entrypoints=websecure
  - traefik.http.routers.webapp.tls.certresolver=production
```

#### API Service with Custom Port
```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.api.rule=Host(`api.internal.earles.io`)
  - traefik.http.routers.api.entrypoints=websecure
  - traefik.http.routers.api.tls.certresolver=production
  - traefik.http.services.api.loadbalancer.server.port=3000
```

#### HTTPS Backend Service
```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.secure-app.rule=Host(`secure.internal.earles.io`)
  - traefik.http.routers.secure-app.entrypoints=websecure
  - traefik.http.routers.secure-app.tls.certresolver=production
  - traefik.http.services.secure-app.loadbalancer.server.port=9443
  - traefik.http.services.secure-app.loadbalancer.server.scheme=https
```

#### Multi-Service Application (Firefly Example)
```yaml
# Main application
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.firefly.rule=Host(`firefly.internal.earles.io`)
  - traefik.http.routers.firefly.entrypoints=websecure
  - traefik.http.routers.firefly.tls.certresolver=production

# Additional service (importer)
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  - traefik.http.routers.firefly-importer.rule=Host(`firefly-importer.internal.earles.io`)
  - traefik.http.routers.firefly-importer.entrypoints=websecure
  - traefik.http.routers.firefly-importer.tls.certresolver=production
```

### Label Organization Standards

#### Label Order
1. **Enable/Network**: `traefik.enable`, `traefik.docker.network`
2. **Router Configuration**: `rule`, `entrypoints`, `tls`, `middlewares`
3. **Service Configuration**: `loadbalancer.server.port`, `loadbalancer.server.scheme`
4. **Advanced Configuration**: Health checks, weights, etc.

#### Naming Conventions
- **Router names**: Use service name or descriptive identifier
- **Service names**: Match router name unless multiple services
- **Middleware names**: Descriptive of function (auth, waf, redirect)

#### Comments and Documentation
```yaml
labels:
  - traefik.enable=true
  - traefik.docker.network=traefik
  # Main service routing
  - traefik.http.routers.service.rule=Host(`service.internal.earles.io`)
  - traefik.http.routers.service.entrypoints=websecure
  - traefik.http.routers.service.tls.certresolver=production
  # Custom port configuration
  - traefik.http.services.service.loadbalancer.server.port=8080
  # Security middleware
  - traefik.http.routers.service.middlewares=waf@file,auth
```

### Debugging and Testing

#### Testing Labels
```yaml
labels:
  # Staging certificate for testing
  - traefik.http.routers.service.tls.certresolver=staging
  
  # Enable detailed logging
  - traefik.http.routers.service.middlewares=debug@file
```

#### Common Troubleshooting Labels
```yaml
# Force specific TLS version
- traefik.http.routers.service.tls.options=default

# Disable TLS verification for backend
- traefik.http.services.service.loadbalancer.serversTransport=insecure

# Custom headers for debugging
- traefik.http.middlewares.debug.headers.customRequestHeaders.X-Debug=true
```

### Traefik Label Best Practices

1. **Always specify `traefik.docker.network=traefik`** for services using Traefik
2. **Use descriptive router and service names** that match your service
3. **Group related labels together** for readability
4. **Comment complex configurations** for future reference
5. **Use consistent domain patterns** per tier (internal/lab/dmz)
6. **Test with staging certificates** before using production
7. **Keep middleware chains simple** to avoid conflicts
8. **Document custom middleware** configurations

## Tier-Specific Configurations

### dockerint01/ (Internal Tier)
- Domain pattern: `service.internal.earles.io`
- Full Traefik integration with SSL
- Backend networks for database isolation
- Environment files for configuration

### dockerdmz01/ (DMZ Tier) 
- Domain pattern: `service.earles.io`
- External-facing services with WAF protection
- Authentik proxy integration
- Enhanced security labeling

### dockerlab01/ (Lab Tier)
- Domain pattern: `service.lab.earles.io` 
- Development and testing services
- Simplified configurations
- Optional SSL certificates