#!/bin/bash
# One-shot Kong Admin API configuration script.
# Provisions services, routes, plugins, and a consumer for the credential-brokering demo.
# Uses PUT for idempotency on services/routes/consumers; checks existence before POST on plugins/credentials.

set -euo pipefail

ADMIN=http://kong:8001

# ---------------------------------------------------------------------------
# Wait for the Admin API
# ---------------------------------------------------------------------------
echo "Waiting for Kong Admin API..."
ATTEMPTS=0
until curl -sf "${ADMIN}/status" > /dev/null; do
  ATTEMPTS=$((ATTEMPTS + 1))
  if [ "$ATTEMPTS" -ge 30 ]; then
    echo "ERROR: Kong Admin API did not become available after 60 seconds." >&2
    exit 1
  fi
  sleep 2
done
echo "Kong Admin API is ready."

# ---------------------------------------------------------------------------
# Helper
# ---------------------------------------------------------------------------
put() {
  local url="$1"; shift
  HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$url" "$@")
  if [ "$HTTP" != "200" ] && [ "$HTTP" != "201" ]; then
    echo "ERROR: PUT $url returned HTTP $HTTP" >&2
    exit 1
  fi
}

post_if_absent() {
  # $1=check_url $2=match_string $3=post_url, rest=curl data args
  local check_url="$1" match="$2" post_url="$3"; shift 3
  if curl -sf "$check_url" | grep -q "$match"; then
    echo "  already exists, skipping."
  else
    HTTP=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$post_url" "$@")
    if [ "$HTTP" != "200" ] && [ "$HTTP" != "201" ]; then
      echo "ERROR: POST $post_url returned HTTP $HTTP" >&2
      exit 1
    fi
    echo "  created (HTTP $HTTP)."
  fi
}

# ---------------------------------------------------------------------------
# Services
# ---------------------------------------------------------------------------
echo ""
echo "==> Configuring services..."

echo -n "  sidecar1-svc... "
put "${ADMIN}/services/sidecar1-svc" \
  --data name=sidecar1-svc \
  --data url=http://kong-sidecar1:80
echo "ok"

echo -n "  sidecar2-svc... "
put "${ADMIN}/services/sidecar2-svc" \
  --data name=sidecar2-svc \
  --data url=http://kong-sidecar2:80
echo "ok"

# ---------------------------------------------------------------------------
# Routes  (strip_path=true so /sidecar1/... proxies as /...)
# ---------------------------------------------------------------------------
echo ""
echo "==> Configuring routes..."

echo -n "  sidecar1-route... "
put "${ADMIN}/services/sidecar1-svc/routes/sidecar1-route" \
  --data name=sidecar1-route \
  --data 'paths[]=/sidecar1' \
  --data strip_path=true
echo "ok"

echo -n "  sidecar2-route... "
put "${ADMIN}/services/sidecar2-svc/routes/sidecar2-route" \
  --data name=sidecar2-route \
  --data 'paths[]=/sidecar2' \
  --data strip_path=true
echo "ok"

# ---------------------------------------------------------------------------
# Global key-auth plugin (validates KONG_MASTER_API_KEY on all requests)
# hide_credentials=true strips the apikey header before forwarding upstream
# ---------------------------------------------------------------------------
echo ""
echo "==> Global key-auth plugin..."
echo -n "  key-auth... "
post_if_absent \
  "${ADMIN}/plugins?name=key-auth" '"name":"key-auth"' \
  "${ADMIN}/plugins" \
  --data name=key-auth \
  --data config.hide_credentials=true

# ---------------------------------------------------------------------------
# request-transformer: inject upstream credentials per service
# ---------------------------------------------------------------------------
echo ""
echo "==> request-transformer plugins..."

echo -n "  sidecar1 (Bearer token)... "
post_if_absent \
  "${ADMIN}/services/sidecar1-svc/plugins?name=request-transformer" '"name":"request-transformer"' \
  "${ADMIN}/services/sidecar1-svc/plugins" \
  --data name=request-transformer \
  --data "config.add.headers[]=Authorization:Bearer ${SIDECAR1_API_KEY}"

# Encode Basic auth credentials for sidecar2
SIDECAR2_BASIC=$(printf '%s:%s' "${SIDECAR2_USER}" "${SIDECAR2_PASSWORD}" | base64 | tr -d '\n')

echo -n "  sidecar2 (Basic auth)... "
post_if_absent \
  "${ADMIN}/services/sidecar2-svc/plugins?name=request-transformer" '"name":"request-transformer"' \
  "${ADMIN}/services/sidecar2-svc/plugins" \
  --data name=request-transformer \
  --data "config.add.headers[]=Authorization:Basic ${SIDECAR2_BASIC}"

# ---------------------------------------------------------------------------
# Consumer + master API key credential
# ---------------------------------------------------------------------------
echo ""
echo "==> Consumer..."

echo -n "  demo-user... "
put "${ADMIN}/consumers/demo-user" \
  --data username=demo-user
echo "ok"

echo -n "  key-auth credential... "
post_if_absent \
  "${ADMIN}/consumers/demo-user/key-auth" "${KONG_MASTER_API_KEY}" \
  "${ADMIN}/consumers/demo-user/key-auth" \
  --data "key=${KONG_MASTER_API_KEY}"

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "======================================================"
echo " Kong credential-brokering demo configured."
echo "======================================================"
echo ""
echo " Test commands:"
echo ""
echo "  # Sidecar 1 (Bearer token auth behind Kong)"
echo "  curl -H 'apikey: ${KONG_MASTER_API_KEY}' https://kong.internal.earles.io/sidecar1"
echo ""
echo "  # Sidecar 2 (Basic auth behind Kong)"
echo "  curl -H 'apikey: ${KONG_MASTER_API_KEY}' https://kong.internal.earles.io/sidecar2"
echo ""
echo "  # No key → 401 from Kong"
echo "  curl https://kong.internal.earles.io/sidecar1"
echo ""
echo "======================================================"
