#!/bin/sh
# Create the static auto-unseal key: 32 random bytes in ./unseal/unseal.key.
# Run once, before the first `docker compose up`. Back the printed value up in
# Vaultwarden. Without it, ./data and every backup are unrecoverable.
set -eu
. "$(dirname -- "$0")/lib.sh"

key="$STACK_DIR/unseal/unseal.key"
[ -e "$key" ] && die "$key already exists. Refusing to overwrite (that would brick the data)."

mkdir -p "$STACK_DIR/unseal"
umask 077
head -c 32 /dev/urandom > "$key"
# The server runs as uid 100 (openbao) inside the container.
chown -R 100:1000 "$STACK_DIR/unseal" 2>/dev/null \
  || warn "Could not chown unseal/ to 100:1000. Re-run with sudo, or the server can't read the key."
chmod 0500 "$STACK_DIR/unseal"
chmod 0400 "$key"

log "Created $key"
echo
echo "Store this in Vaultwarden as 'OpenBao unseal key (dockerint01)':"
echo
echo "  $(base64 < "$key" | tr -d '\n')"
echo
echo "Restore later with: echo '<value>' | base64 -d > unseal/unseal.key"
