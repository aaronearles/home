#!/bin/sh
# Break-glass: mint a new root token from the recovery keys (3 of 5).
#
#   ./scripts/generate-root.sh
#
# Use it when no admin can log in (lost password, broken OIDC, …). It asks for
# recovery keys one at a time without echoing them, then prints the new root
# token. Fix what you came to fix, then revoke it:
#   BAO_TOKEN=<token> ./scripts/bao token revoke -self
#
# How: OpenBao 2.x only allows unauthenticated root generation on the legacy
# sys/generate-root/* endpoints, and only on a listener that opts in. The
# `bao` CLI uses the newer authenticated endpoints, so this script talks HTTP
# to the loopback-only break-glass listener (127.0.0.1:8210 inside the
# container, see config/openbao.hcl), which is reachable only via docker exec.
# Needs python3 on the host.
set -eu
. "$(dirname -- "$0")/lib.sh"

command -v python3 >/dev/null || die "python3 is required"
container=${BAO_CONTAINER:-openbao}

# post <endpoint>: JSON body on stdin -> JSON response on stdout
post() {
  docker exec -i "$container" wget -qO- --header 'Content-Type: application/json' \
    --post-file=/dev/stdin "http://127.0.0.1:8210/v1/sys/generate-root/$1"
}
field() { python3 -c 'import json,sys; v=json.load(sys.stdin)[sys.argv[1]]; print(str(v).lower() if isinstance(v,bool) else v)' "$1"; }
# Cancel via the bao CLI's generic DELETE (busybox wget can't send DELETE).
# Drop any cached CLI login first: a stale token gets a 403 even here.
cancel() {
  docker exec "$container" sh -c 'rm -f "$HOME/.vault-token"
    bao delete -address=http://127.0.0.1:8210 sys/generate-root/attempt' >/dev/null 2>&1 || true
}

# Clear any half-finished attempt (a previous run, or a mistyped key).
cancel
init=$(printf '{}' | post attempt) || die "Could not start root generation."
otp=$(printf '%s' "$init" | field otp)
nonce=$(printf '%s' "$init" | field nonce)
required=$(printf '%s' "$init" | field required)
log "Root generation started; $required recovery keys needed."

tty=/dev/stdin; if (: < /dev/tty) 2>/dev/null; then tty=/dev/tty; fi
i=1
while :; do
  printf 'Recovery key %s/%s: ' "$i" "$required" >&2
  stty -echo < "$tty" 2>/dev/null || true
  read -r key < "$tty" || key=""
  stty echo < "$tty" 2>/dev/null || true
  echo >&2
  [ -n "$key" ] || { cancel; die "Aborted."; }
  # Key goes over stdin into the request body, never onto a command line.
  resp=$(KEY=$key NONCE=$nonce python3 -c 'import json,os; print(json.dumps({"key": os.environ["KEY"], "nonce": os.environ["NONCE"]}))' \
    | post update) || { cancel; die "Key rejected; attempt cancelled."; }
  [ "$(printf '%s' "$resp" | field complete)" = true ] && break
  i=$((i + 1))
done

encoded=$(printf '%s' "$resp" | field encoded_token)
# encoded_token = base64(root_token XOR otp)
token=$(python3 -c '
import base64, sys
enc, otp = sys.argv[1], sys.argv[2]
raw = base64.b64decode(enc + "=" * (-len(enc) % 4))
print(bytes(a ^ b for a, b in zip(raw, otp.encode())).decode())' "$encoded" "$otp")

log "New root token (no expiry, no policy limits):"
echo "$token"
log "Revoke it when done: BAO_TOKEN=<token> ./scripts/bao token revoke -self"
