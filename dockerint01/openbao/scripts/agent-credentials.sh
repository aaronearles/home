#!/bin/sh
# Issue credentials for an agent: its role_id plus a NEW secret_id.
#
#   ./scripts/agent-credentials.sh <name>               # print as env lines
#   ./scripts/agent-credentials.sh <name> --wrap 15m    # print a one-time wrapping token
#
# Plain mode prints:
#   BAO_ADDR=...  BAO_ROLE_ID=...  BAO_SECRET_ID=...
# Put those in the agent's credentials file (mode 600, see client/bao-agent).
#
# Wrap mode prints the role_id and a single-use token that expires after the
# TTL. The agent redeems it with `bao-agent unwrap <token>`. If someone else
# redeemed it first, the agent's unwrap fails, so you know it was intercepted.
#
# Every call adds a secret_id; old ones keep working until revoked. To rotate:
# issue a new one, deploy it, then ./scripts/agent-revoke.sh <name> --old <accessor>.
set -eu
. "$(dirname -- "$0")/lib.sh"

[ $# -ge 1 ] || { sed -n '2,17p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
name=$1; shift
wrap=""
[ "${1:-}" = "--wrap" ] && wrap=${2:-15m}

role="agent-$name"
require_token
"$BAO" read "auth/approle/role/$role" >/dev/null 2>&1 \
  || die "No AppRole role $role. Create it with ./scripts/agent-create.sh $name"

addr=${BAO_PUBLIC_ADDR:-https://openbao.internal.earles.io}
role_id=$("$BAO" read -field=role_id "auth/approle/role/$role/role-id")
# Shows up in `agent-revoke.sh <name> --list`, so you can tell secret_ids apart.
meta=$(printf '{"issued_by":"%s","issued_at":"%s"}' "$(id -un)" "$(date -u +%FT%TZ)")

if [ -n "$wrap" ]; then
  token=$("$BAO" write -f -wrap-ttl="$wrap" -field=wrapping_token \
    "auth/approle/role/$role/secret-id" metadata="$meta")
  echo "BAO_ADDR=$addr"
  echo "BAO_ROLE_ID=$role_id"
  echo "# One-time wrapping token, valid for $wrap. On the agent's machine run:"
  echo "#   bao-agent unwrap $token"
  echo "BAO_WRAPPED_SECRET_ID=$token"
else
  secret_id=$("$BAO" write -f -field=secret_id "auth/approle/role/$role/secret-id" metadata="$meta")
  echo "BAO_ADDR=$addr"
  echo "BAO_ROLE_ID=$role_id"
  echo "BAO_SECRET_ID=$secret_id"
fi
