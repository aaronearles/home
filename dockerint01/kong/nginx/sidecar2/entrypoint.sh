#!/bin/sh
# Generate .htpasswd from environment variables, then hand off to the standard nginx entrypoint.
# nginx:alpine includes openssl; apr1 (MD5-based) is universally supported by nginx auth_basic.
printf '%s:%s\n' "$SIDECAR_USER" "$(openssl passwd -apr1 "$SIDECAR_PASSWORD")" \
  > /etc/nginx/.htpasswd

exec /docker-entrypoint.sh nginx -g "daemon off;"
