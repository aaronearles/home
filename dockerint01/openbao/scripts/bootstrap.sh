#!/bin/sh
# One-time (and safely re-runnable) setup of a freshly initialised server.
#
#   export BAO_TOKEN=<root token from `bao operator init`>
#   sudo -E ./scripts/bootstrap.sh
#
# What it does, in order:
#   1. Checks the audit device from config/openbao.hcl is active
#   2. KV v2 secrets engine at kv/
#   3. Auth methods: approle/ (machines) and userpass/ (humans, break-glass)
#   4. All policies from policies/ and agents/
#   5. AppRole roles for the backup and vaultwarden-sync containers, and their
#      credentials in credentials/<role>/
#   6. A human admin user (asks for username + password)
# Each step checks first, so re-running only fills in what's missing.
set -eu
. "$(dirname -- "$0")/lib.sh"

require_token

# 1. Audit ---------------------------------------------------------------------
# Declared in config/openbao.hcl (OpenBao refuses API-enabled audit devices).
# Check it's live before anything else, so setup itself is recorded.
audit_enabled file || die "No 'file' audit device. Check the audit block in config/openbao.hcl and restart."
log "audit: file device active (logs/audit.log)"

# 2. KV v2 ---------------------------------------------------------------------
if secret_enabled kv; then
  log "secrets: kv/ already enabled"
else
  log "secrets: enabling kv-v2 at kv/ (keeps 10 versions per secret)"
  "$BAO" secrets enable -path=kv -version=2 -description="Key/value secrets" kv >/dev/null
  "$BAO" write kv/config max_versions=10 >/dev/null
fi

# 3. Auth methods --------------------------------------------------------------
for method in approle userpass; do
  if auth_enabled "$method"; then
    log "auth: $method/ already enabled"
  else
    log "auth: enabling $method/"
    "$BAO" auth enable "$method" >/dev/null
  fi
done

# 4. Policies ------------------------------------------------------------------
"$STACK_DIR/scripts/apply-policies.sh"

# 5. Service AppRoles ----------------------------------------------------------
# Short-lived tokens; secret_ids never expire but are only usable from the
# Docker backend network, so a leaked credentials/ file is useless elsewhere.
backend_net=${BACKEND_NETWORK:-openbao_backend}
backend_cidr=$(docker network inspect "$backend_net" \
  -f '{{(index .IPAM.Config 0).Subnet}}' 2>/dev/null || true)
[ -n "$backend_cidr" ] || die "Could not find the $backend_net network. Run 'docker compose up -d openbao' first."

log "approle: role backup (bound to $backend_cidr)"
"$BAO" write auth/approle/role/backup \
  token_policies=backup token_ttl=15m token_max_ttl=1h \
  secret_id_ttl=0 secret_id_bound_cidrs="$backend_cidr" token_bound_cidrs="$backend_cidr" >/dev/null

log "approle: role vaultwarden-sync (bound to $backend_cidr)"
"$BAO" write auth/approle/role/vaultwarden-sync \
  token_policies=vaultwarden-sync token_ttl=1h token_max_ttl=24h \
  secret_id_ttl=0 secret_id_bound_cidrs="$backend_cidr" token_bound_cidrs="$backend_cidr" >/dev/null

# backup runs as root in its container; the sync runs as uid 1000 (node).
for pair in backup:0 vaultwarden-sync:1000; do
  role=${pair%%:*} uid=${pair#*:}
  if [ -s "$STACK_DIR/credentials/$role/secret_id" ]; then
    log "credentials: credentials/$role already present (delete it to re-issue)"
  else
    log "credentials: issuing credentials/$role"
    write_credentials "$STACK_DIR/credentials/$role" "$role" "$uid"
  fi
done

# 6. Human admin ---------------------------------------------------------------
# `bao list` exits 2 when there is nothing to list.
if "$BAO" list auth/userpass/users >/dev/null 2>&1; then
  log "userpass: at least one user exists, skipping admin creation"
else
  tty=/dev/stdin; if (: < /dev/tty) 2>/dev/null; then tty=/dev/tty; fi
  printf 'Admin username: ' >&2; read -r admin_user < "$tty"
  stty -echo < "$tty" 2>/dev/null || true
  printf 'Admin password: ' >&2; read -r admin_pass < "$tty"; echo >&2
  stty echo < "$tty" 2>/dev/null || true
  [ -n "$admin_user" ] && [ -n "$admin_pass" ] || die "username and password are required"
  log "userpass: creating $admin_user with policy admin (8h tokens)"
  # Password goes over stdin, so it never appears in a process list.
  printf '%s' "$admin_pass" | "$BAO" write "auth/userpass/users/$admin_user" \
    password=- token_policies=admin token_ttl=8h token_max_ttl=24h >/dev/null
fi

log "Bootstrap complete."
cat >&2 <<'NEXT'

Next:
  1. Log in as your admin user:   ./scripts/bao login -method=userpass username=<you>
  2. Revoke the root token:       BAO_TOKEN=<root> ./scripts/bao token revoke -self
  3. Store the sync's Vaultwarden login (see docs/vaultwarden-sync.md), then
                                  docker compose up -d
NEXT
