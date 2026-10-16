#!/bin/sh
# Runs inside the openbao-backup container (see docker-compose.yml).
# Logs in with AppRole, saves a Raft snapshot, prunes old ones, sleeps.
set -eu

interval=${BACKUP_INTERVAL_SECONDS:-86400}
keep_days=${BACKUP_RETENTION_DAYS:-30}

snapshot() {
  role_id=$(cat /credentials/role_id)
  secret_id=$(cat /credentials/secret_id)
  # Secrets go over stdin (key=-), never on the command line.
  BAO_TOKEN=$(printf '%s' "$secret_id" | bao write -field=token auth/approle/login \
    role_id="$role_id" secret_id=-)
  export BAO_TOKEN
  file="/backups/openbao-$(date -u +%Y%m%dT%H%M%SZ).snap"
  bao operator raft snapshot save "$file"
  bao token revoke -self >/dev/null 2>&1 || true
  unset BAO_TOKEN
  echo "$(date -u +%FT%TZ) saved $file ($(wc -c < "$file") bytes)"
  find /backups -name 'openbao-*.snap' -mtime +"$keep_days" -print -delete
}

echo "openbao-backup: every ${interval}s, keeping ${keep_days} days, to /backups"
while true; do
  if [ ! -s /credentials/secret_id ]; then
    echo "$(date -u +%FT%TZ) no credentials yet (run ./scripts/bootstrap.sh); retrying in 60s"
    sleep 60; continue
  fi
  if snapshot; then
    sleep "$interval"
  else
    echo "$(date -u +%FT%TZ) snapshot FAILED; retrying in 300s" >&2
    sleep 300
  fi
done
