#!/bin/sh
# nginx:alpine is minimal — install openssl at runtime for htpasswd generation.
apk add --no-cache openssl > /dev/null 2>&1
# Generate .htpasswd; apr1 (MD5-based) is universally supported by nginx auth_basic.
printf '%s:%s\n' "$SIDECAR_USER" "$(openssl passwd -apr1 "$SIDECAR_PASSWORD")" \
  > /etc/nginx/.htpasswd

exec /docker-entrypoint.sh nginx -g "daemon off;"
