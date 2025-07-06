# TinyAuth Setup

TinyAuth is a simple authentication middleware that provides a login screen for protecting self-hosted applications. This setup integrates with the existing Traefik lab infrastructure.

## Quick Start

1. **Copy environment configuration:**
   ```bash
   cp .env.sample .env
   ```

2. **Generate a secret:**
   ```bash
   openssl rand -hex 32
   ```
   Update the `SECRET` variable in `.env` with this value.

3. **Configure users:**
   - Use the default admin user (password: `password`) for testing
   - Or generate new bcrypt hashes and update the `USERS` variable
   - **Important:** Escape bcrypt hashes by doubling every `$` sign in Docker Compose

4. **Start the services:**
   ```bash
   docker-compose up -d
   ```

## Access Points

- **TinyAuth Dashboard:** https://tinyauth.lab.earles.io
- **Protected Test Service:** https://whoami-protected.lab.earles.io
- **Regular Test Service:** https://whoami.lab.earles.io (unprotected)

## Configuration

### Required Variables
- `SECRET`: 32-character random string for JWT signing
- `USERS`: Username:password_hash pairs (comma-separated for multiple users)

### User Management
- **Default User:** `admin` / `password` (for testing only)
- **Generate Password Hash:** Use IT-Tools at `it-tools.lab.earles.io` → Bcrypt generator
- **Format:** `username:$$2a$$10$$hashedpassword` (note the double `$$`)

### OAuth Integration (Optional)
- GitHub OAuth supported
- Generic OAuth providers supported
- Callback URL format: `https://tinyauth.lab.earles.io/api/oauth/{provider}/callback`

## Protecting Other Services

To protect any service with TinyAuth, add this middleware to its Traefik labels:
```yaml
labels:
  - traefik.http.routers.SERVICE_NAME.middlewares=tinyauth@docker
```

## Security Notes

1. **Change default credentials** before production use
2. **Use strong passwords** and proper bcrypt hashing
3. **Keep SECRET secure** - regenerate if compromised
4. **Enable OAuth** for better security and user management
5. **Monitor access logs** in TinyAuth dashboard

## Troubleshooting

- **Authentication fails:** Check bcrypt hash escaping (double `$$`)
- **Redirect loops:** Verify `APP_URL` matches the actual domain
- **Service access:** Ensure Traefik middleware is properly applied
- **Logs:** `docker-compose logs tinyauth`

## Documentation

- Official Docs: https://tinyauth.app/docs/
- GitHub: https://github.com/steveiliop56/tinyauth
- Configuration Reference: https://tinyauth.app/docs/reference/configuration.html