#!/bin/sh
# Install /etc/logrotate.d/openbao-audit for logs/audit.log.
#
#   sudo ./scripts/install-logrotate.sh
#
# The audit log records every request (the sync alone adds a few thousand
# lines a day), so rotate it daily and keep 30 days. After rotating, logrotate
# sends SIGHUP, which makes OpenBao reopen the file. Rotated logs are compressed
# and stay readable by root only.
set -eu
. "$(dirname -- "$0")/lib.sh"

target=/etc/logrotate.d/openbao-audit
cat > "$target" <<CONF
$STACK_DIR/logs/audit.log {
  daily
  rotate 30
  compress
  delaycompress
  missingok
  notifempty
  create 0600 100 1000
  postrotate
    docker kill -s HUP ${BAO_CONTAINER:-openbao} >/dev/null 2>&1 || true
  endscript
}
CONF
log "Wrote $target"
logrotate --debug "$target" 2>&1 | grep -E "rotating pattern|error" || true
