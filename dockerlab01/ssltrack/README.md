# SSLTrack - Docker Lab Setup

SSL certificate expiry monitoring application deployed in the lab environment.

## Overview

SSLTrack is an ASP.NET Core application that monitors SSL certificate expiration dates and sends alerts before certificates expire. This deployment uses Docker Compose with Traefik integration.

**Repository**: [zimbres/SSLTrack](https://github.com/zimbres/SSLTrack)
**Docker Image**: [zimbres/ssltrack](https://hub.docker.com/r/zimbres/ssltrack)

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- Traefik running and accessible via `traefik` network
- DNS entry for `ssltrack.lab.earles.io` configured (or update domain as needed)

### Setup Steps

1. **Navigate to the directory**:
```bash
cd dockerlab01/ssltrack
```

2. **Create environment file**:
```bash
cp .env.sample .env
```

3. **Configure environment variables**:
```bash
# Edit .env with your settings
vi .env
```

Key variables to configure:
- `SMTP_HOST`, `SMTP_PORT`, `SMTP_USERNAME`, `SMTP_PASSWORD` - Email alert configuration
- `SMTP_FROM_EMAIL`, `SMTP_FROM_NAME` - Sender information
- `APP_TIMEZONE` - Application timezone
- `ALERT_THRESHOLD` - Days before expiry to trigger alert (default: 30)
- `CHECK_INTERVAL` - Hours between certificate checks (default: 24)

4. **Deploy the service**:
```bash
docker-compose up -d
```

5. **Verify the service**:
```bash
docker-compose logs -f ssltrack
```

6. **Access the application**:
Open browser to: `https://ssltrack.lab.earles.io`

## Configuration Details

### Database

SSLTrack uses SQLite by default, with the database stored in `/app/data/ssltrack.db`. This volume is persisted across container restarts via the named volume `ssltrack_data`.

### Email Alerts

To enable email notifications:
1. Configure SMTP settings in `.env`
2. Supported providers: Gmail, Office 365, custom SMTP
3. For Gmail: Use [App Passwords](https://myaccount.google.com/apppasswords) instead of your actual password

### Health Checks

The container includes a health check that pings the `/api/health` endpoint every 30 seconds. This is important for background job persistence.

**Important Note**: Background jobs (certificate expiry verification and email alerts) will not continue if the application is idle. Configure monitoring tools to call the health endpoint periodically, or refer to [HangFire documentation](https://docs.hangfire.io/en/latest/deployment-to-production/making-aspnet-app-always-running.html).

### Network Configuration

- **External Network**: `traefik` - Shared reverse proxy network
- **Internal Network**: `backend` - Private backend network (if needed for databases)
- **Port**: 80 (internal), exposed via Traefik at `ssltrack.lab.earles.io`

### Traefik Integration

The service is automatically registered with Traefik using labels:
- Hostname: `ssltrack.lab.earles.io`
- Protocol: HTTPS (websecure)
- Certificate: Automatically provisioned via Let's Encrypt

## Usage

### Adding SSL Certificates to Monitor

1. Log in to SSLTrack web interface
2. Add certificates by:
   - Domain name (automatic lookup)
   - Certificate file upload
   - Manual entry

3. Configure alert settings:
   - Alert threshold (days before expiry)
   - Email recipients
   - Notification frequency

### Monitoring

- View dashboard showing:
  - Certificate expiry dates
  - Days remaining
  - Alert status
  - Last check time

- API endpoint for health checks: `https://ssltrack.lab.earles.io/api/health`

## Troubleshooting

### Container Not Starting
```bash
docker-compose logs ssltrack
```

### Health Check Failing
- Ensure the container is running: `docker ps | grep ssltrack`
- Check logs for errors: `docker-compose logs ssltrack`
- Verify Traefik routing: Check Traefik dashboard at `traefik.lab.earles.io:8080`

### Email Alerts Not Working
- Verify SMTP credentials in `.env`
- Check container logs for SMTP errors
- Test SMTP manually (use mailhog or similar for testing)
- Ensure firewall allows SMTP connections

### Background Jobs Not Running
- **Critical**: Ensure the application receives periodic HTTP requests
- Configure a monitoring tool (Uptime Kuma, Gatus, etc.) to ping `/api/health`
- Or manually access the web UI regularly
- Refer to [HangFire production deployment guide](https://docs.hangfire.io/en/latest/deployment-to-production/making-aspnet-app-always-running.html)

## Maintenance

### Updating the Image
```bash
docker-compose pull
docker-compose up -d
```

### Backing Up Data
```bash
# Backup SQLite database
docker run --rm -v ssltrack_ssltrack_data:/data -v /path/to/backup:/backup \
  alpine cp /data/ssltrack.db /backup/ssltrack.db.backup
```

### Logs
```bash
# View live logs
docker-compose logs -f ssltrack

# View last 100 lines
docker-compose logs --tail=100 ssltrack
```

## Advanced Configuration

### Custom SMTP Server
Update `.env`:
```bash
SMTP_HOST=mail.example.com
SMTP_PORT=25
SMTP_USERNAME=user@example.com
SMTP_PASSWORD=password
```

### Slack Integration (if supported)
```bash
ENABLE_SLACK_ALERTS=true
SLACK_WEBHOOK_URL=https://hooks.slack.com/services/YOUR/WEBHOOK/URL
```

### Change Check Interval
In `.env`:
```bash
CHECK_INTERVAL=12  # Check every 12 hours instead of 24
```

## Project Structure
```
ssltrack/
├── docker-compose.yml      # Docker Compose configuration
├── .env.sample             # Environment variables template
├── README.md               # This file
└── (data volumes created at runtime)
    └── ssltrack_data/      # SQLite database and application data
```

## Additional Resources

- [SSLTrack GitHub Repository](https://github.com/zimbres/SSLTrack)
- [Docker Hub Image](https://hub.docker.com/r/zimbres/ssltrack)
- [HangFire Documentation](https://docs.hangfire.io/)
- [ASP.NET Core Documentation](https://learn.microsoft.com/en-us/dotnet/core/extensions/logging)

## Notes

- Application runs on port 80 internally, exposed via Traefik
- Uses ASP.NET Core Runtime 8.x
- SQLite database is persistence-friendly and requires no external dependencies
- Consider monitoring the health endpoint to ensure background jobs continue
