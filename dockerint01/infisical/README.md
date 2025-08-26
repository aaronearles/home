# Infisical - Open Source SecretOps Platform

Infisical is an open-source secret management platform that helps teams manage application configuration and secrets across their entire software development lifecycle.

## Features

- **Secret Management**: Centralized storage and management of application secrets
- **Environment Management**: Organize secrets by environment (dev, staging, prod)
- **Team Collaboration**: Role-based access control and team workflows
- **Developer Tools**: CLI, SDKs, and integrations for popular frameworks
- **Security**: End-to-end encryption, audit logs, and compliance features
- **Integrations**: Native support for CI/CD, cloud providers, and deployment platforms

## Quick Start

### 1. Configuration

Copy the environment template and customize it:

```bash
cp .env.sample .env
```

**Critical Security Steps:**
- Generate new `ENCRYPTION_KEY` (32-character hex string)
- Generate new `AUTH_SECRET`, `JWT_*_SECRET` values
- Update `SITE_URL` to match your domain
- Set strong database password in `DB_CONNECTION_PASSWORD`

Generate secure keys:
```bash
# Generate encryption key (32 bytes hex)
openssl rand -hex 32

# Generate auth secrets
openssl rand -base64 32
```

### 2. Deploy

Start the services:

```bash
docker-compose up -d
```

Check service status:
```bash
docker-compose ps
docker-compose logs -f infisical
```

### 3. Access

- **Web UI**: https://infisical.internal.earles.io
- **Default Admin**: Create your first user through the web interface

## Initial Setup

1. **First Login**: Navigate to the web interface and create your first user account
2. **Create Organization**: Set up your organization and workspace
3. **Create Project**: Create your first project for managing secrets
4. **Add Secrets**: Start adding your application secrets organized by environment

## Usage Examples

### Web Interface
- Access the dashboard to manage secrets through the UI
- Create projects and environments
- Invite team members and manage permissions
- View audit logs and access history

### CLI Usage
Install the Infisical CLI:
```bash
# Install CLI
curl -1sLf 'https://dl.cloudsmith.io/public/infisical/infisical-cli/setup.deb.sh' | sudo -E bash
sudo apt-get update && sudo apt-get install infisical

# Login
infisical login

# Pull secrets from a project
infisical secrets
```

### SDK Integration
Example Node.js integration:
```javascript
import { InfisicalSDK } from '@infisical/sdk';

const infisical = new InfisicalSDK({
  serverURL: 'https://infisical.internal.earles.io',
});

// Get secrets
const secrets = await infisical.listSecrets({
  environment: 'production',
  projectId: 'your-project-id'
});
```

## Service Configuration

### Database
- **PostgreSQL 14**: Primary database for application data
- **Redis**: Session storage and caching
- **Volumes**: Persistent storage for both databases

### Security Features
- End-to-end encryption of secrets
- Role-based access control (RBAC)
- Audit logging
- SAML/OIDC/LDAP authentication support
- API key management

### Integrations
- **CI/CD**: GitHub Actions, GitLab CI, Jenkins
- **Cloud**: AWS, GCP, Azure secret injection
- **Frameworks**: Next.js, React, Node.js, Python, Go
- **Infrastructure**: Kubernetes, Docker, Terraform

## Maintenance

### Backups
Regular database backups are recommended:
```bash
# Backup PostgreSQL
docker-compose exec postgres pg_dump -U infisical infisical > backup.sql

# Backup volumes
docker run --rm -v infisical_postgres_data:/data -v $(pwd):/backup alpine tar czf /backup/postgres_backup.tar.gz -C /data .
```

### Updates
```bash
# Pull latest images
docker-compose pull

# Recreate containers
docker-compose up -d
```

### Monitoring
Check logs for any issues:
```bash
docker-compose logs -f
```

## Troubleshooting

### Common Issues

1. **Database Connection Errors**
   - Verify PostgreSQL is running: `docker-compose ps postgres`
   - Check database logs: `docker-compose logs postgres`

2. **Redis Connection Issues**
   - Verify Redis is running: `docker-compose ps redis`
   - Check Redis logs: `docker-compose logs redis`

3. **Authentication Problems**
   - Ensure `AUTH_SECRET` and JWT secrets are properly set
   - Verify `SITE_URL` matches your access URL

4. **Performance Issues**
   - Monitor resource usage: `docker stats`
   - Consider scaling Redis or PostgreSQL if needed

## Links

- **Official Documentation**: https://infisical.com/docs
- **GitHub Repository**: https://github.com/Infisical/infisical
- **Community**: https://infisical.com/slack