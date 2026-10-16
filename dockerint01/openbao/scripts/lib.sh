# Shared helpers for the scripts in this directory. Source, don't execute.
# shellcheck shell=sh

STACK_DIR=$(CDPATH='' cd -- "$(dirname -- "$0")/.." && pwd)
BAO="$STACK_DIR/scripts/bao"

log()  { printf '==> %s\n' "$*" >&2; }
warn() { printf 'WARN: %s\n' "$*" >&2; }
die()  { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

# Fail early with a useful message if we can't talk to an unsealed server
# with a valid token.
# Calls that don't need input get </dev/null: if the script's own stdin is a
# pipe, `docker exec -i` would otherwise consume it.
require_token() {
  "$BAO" status >/dev/null 2>&1 </dev/null || {
    "$BAO" status >&2 </dev/null || true
    die "OpenBao is not reachable, not initialised, or sealed."
  }
  "$BAO" token lookup >/dev/null 2>&1 </dev/null \
    || die "No valid token. Run ./scripts/bao login -method=userpass username=<you>, or export BAO_TOKEN."
}

# confirm "question"  -> returns 0 on y/Y. Reads the terminal, not stdin.
# Set ASSUME_YES=1 (or pass --yes where supported) for unattended use.
confirm() {
  [ "${ASSUME_YES:-}" = 1 ] && return 0
  tty=/dev/stdin; if (: < /dev/tty) 2>/dev/null; then tty=/dev/tty; fi
  printf '%s [y/N] ' "$1" >&2
  read -r answer < "$tty" || answer=""
  [ "$answer" = y ] || [ "$answer" = Y ]
}

# auth_enabled <path>  e.g. auth_enabled approle
auth_enabled()   { "$BAO" auth list -format=json </dev/null | grep -q "\"$1/\""; }
secret_enabled() { "$BAO" secrets list -format=json </dev/null | grep -q "\"$1/\""; }
audit_enabled()  { "$BAO" audit list -format=json 2>/dev/null </dev/null | grep -q "\"$1/\""; }

# write_credentials <dir> <role> <owner-uid>
# Writes role_id and a fresh secret_id for an AppRole role into <dir>, readable
# only by <owner-uid> (the uid the consuming container runs as).
write_credentials() {
  dir=$1 role=$2 owner=$3
  mkdir -p "$dir"
  chmod 0700 "$dir"
  umask 077
  rm -f "$dir/role_id" "$dir/secret_id"
  "$BAO" read -field=role_id "auth/approle/role/$role/role-id" > "$dir/role_id"
  "$BAO" write -f -field=secret_id "auth/approle/role/$role/secret-id" \
    metadata="{\"issued_to\":\"$role container\"}" > "$dir/secret_id"
  chmod 0400 "$dir/role_id" "$dir/secret_id"
  chown -R "$owner" "$dir" 2>/dev/null \
    || warn "Could not chown $dir to uid $owner (run with sudo?). The container may not be able to read it."
}

# apply_agent_file <path/to/agents/name.hcl>
# Writes the agent's policy and AppRole role from one declarative file.
apply_agent_file() {
  file=$1
  name=$(basename "$file" .hcl)
  log "agent $name: policy agent-$name"
  "$BAO" policy write "agent-$name" - < "$file" >/dev/null
  # Collect "# role: key=value" lines as arguments.
  set -- token_policies="agent-$name"
  while IFS= read -r line; do
    case $line in
      "# role: "*) set -- "$@" "${line#\# role: }" ;;
    esac
  done < "$file"
  log "agent $name: approle role agent-$name ($*)"
  "$BAO" write "auth/approle/role/agent-$name" "$@" >/dev/null
}
