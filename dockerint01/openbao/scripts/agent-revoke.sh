#!/bin/sh
# Cut off an agent.
#
#   ./scripts/agent-revoke.sh <name> [--yes]            # kill switch: everything
#   ./scripts/agent-revoke.sh <name> --list             # show issued secret_ids
#   ./scripts/agent-revoke.sh <name> --old <accessor>   # rotate: drop one secret_id
#
# The kill switch destroys every secret_id, deletes the role, and replaces the
# policy with an empty one. Tokens the agent already holds lose all access
# right away, because policies are checked on every request. The agent file
# is renamed to agents/<name>.hcl.revoked so apply-policies.sh won't bring it
# back. Its own secrets under kv/agents/<name>/ are left in place.
set -eu
. "$(dirname -- "$0")/lib.sh"

[ $# -ge 1 ] || { sed -n '2,11p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
name=$1; shift
role="agent-$name"
require_token

accessors() {
  "$BAO" list -format=json "auth/approle/role/$role/secret-id" 2>/dev/null </dev/null \
    | tr -d '[]", ' | grep -v '^$' || true
}

case ${1:-} in
  --list)
    for a in $(accessors); do
      "$BAO" write -format=json "auth/approle/role/$role/secret-id-accessor/lookup" \
        secret_id_accessor="$a" </dev/null | jq -c --arg a "$a" \
        '{accessor: $a, created: .data.creation_time, last_used: .data.last_updated_time, metadata: .data.metadata}' 2>/dev/null \
        || echo "$a"
    done
    ;;
  --old)
    [ -n "${2:-}" ] || die "--old needs a secret_id accessor (see --list)"
    "$BAO" write "auth/approle/role/$role/secret-id-accessor/destroy" secret_id_accessor="$2" >/dev/null
    log "Destroyed secret_id $2 for $name"
    ;;
  ""|--yes)
    # shellcheck disable=SC2034 # read by confirm() in lib.sh
    [ "${1:-}" = --yes ] && ASSUME_YES=1
    confirm "Revoke ALL access for agent $name?" || die "Aborted."
    for a in $(accessors); do
      "$BAO" write "auth/approle/role/$role/secret-id-accessor/destroy" secret_id_accessor="$a" >/dev/null </dev/null
    done
    "$BAO" delete "auth/approle/role/$role" >/dev/null </dev/null
    echo "# revoked $(date -u +%FT%TZ)" | "$BAO" policy write "$role" - >/dev/null
    [ -f "$STACK_DIR/agents/$name.hcl" ] && mv "$STACK_DIR/agents/$name.hcl" "$STACK_DIR/agents/$name.hcl.revoked"
    log "Agent $name revoked. Commit the rename of agents/$name.hcl."
    ;;
  *) die "Unknown option $1" ;;
esac
