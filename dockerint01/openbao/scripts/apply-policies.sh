#!/bin/sh
# Apply every policy in policies/*.hcl and every agent in agents/*.hcl.
# Git is the source of truth: edit the files, commit, run this. Idempotent.
#   ./scripts/apply-policies.sh            # everything
#   ./scripts/apply-policies.sh my-agent   # one agent only
set -eu
. "$(dirname -- "$0")/lib.sh"

require_token

if [ $# -gt 0 ]; then
  for name in "$@"; do
    f="$STACK_DIR/agents/$name.hcl"
    [ -f "$f" ] || die "No such agent file: $f"
    apply_agent_file "$f"
  done
  exit 0
fi

for f in "$STACK_DIR"/policies/*.hcl; do
  name=$(basename "$f" .hcl)
  log "policy $name"
  "$BAO" policy write "$name" - < "$f" >/dev/null
done

auth_enabled approle || die "approle/ is not enabled yet. Run ./scripts/bootstrap.sh."
for f in "$STACK_DIR"/agents/*.hcl; do
  case $(basename "$f") in _*) continue ;; esac
  [ -f "$f" ] || continue
  apply_agent_file "$f"
done
