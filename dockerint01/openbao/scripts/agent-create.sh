#!/bin/sh
# Scaffold a new agent identity from agents/_template.hcl and apply it.
#
#   ./scripts/agent-create.sh <name> [--read <kv path>]... [--cidr <cidr>] [--secret-id-ttl <dur>]
#
# Example: an infra agent on 10.0.20.15 that may read the Cloudflare token
#   ./scripts/agent-create.sh claude-infra \
#     --read infra/cloudflare/dns-token --cidr 10.0.20.15/32
#
# Paths for --read are KV paths without the mount, the same ones you'd type in
# `bao kv get kv/<path>`. A trailing /* grants a whole folder.
# The generated agents/<name>.hcl is the source of truth: review it, commit it,
# and edit it later (then ./scripts/apply-policies.sh <name>).
set -eu
. "$(dirname -- "$0")/lib.sh"

usage() { sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }

[ $# -ge 1 ] || usage
name=$1; shift
printf '%s' "$name" | grep -Eq '^[a-z0-9][a-z0-9-]{1,40}$' \
  || die "Agent name must be lowercase letters, digits and dashes."

grants="" cidr="" secret_ttl="0"
while [ $# -gt 0 ]; do
  case $1 in
    --read)
      [ $# -ge 2 ] || usage
      p=${2#kv/}; p=${p#/}
      grants="${grants}path \"kv/data/$p\" {
  capabilities = [\"read\"]
}
"
      shift 2 ;;
    --cidr) [ $# -ge 2 ] || usage; cidr=$2; shift 2 ;;
    --secret-id-ttl) [ $# -ge 2 ] || usage; secret_ttl=$2; shift 2 ;;
    *) usage ;;
  esac
done

file="$STACK_DIR/agents/$name.hcl"
[ -e "$file" ] && die "$file exists. Edit it and run ./scripts/apply-policies.sh $name instead."
[ -n "$grants" ] || grants="# (none yet) e.g.
# path \"kv/data/infra/cloudflare/dns-token\" {
#   capabilities = [\"read\"]
# }
"
[ -n "$cidr" ] || warn "No --cidr given: this agent's credentials will work from any IP."

require_token

# Fill in the template. awk handles the multi-line grants block safely.
GRANTS=$grants awk -v name="$name" -v date="$(date +%F)" -v cidr="$cidr" -v ttl="$secret_ttl" '
  { gsub(/__NAME__/, name); gsub(/__DATE__/, date); gsub(/__CIDR__/, cidr); gsub(/__SECRET_ID_TTL__/, ttl) }
  /^__GRANTS__$/ { printf "%s", ENVIRON["GRANTS"]; next }
  { print }
' "$STACK_DIR/agents/_template.hcl" > "$file"

log "Wrote $file"
apply_agent_file "$file"
log "Done. Commit agents/$name.hcl, then issue credentials with:"
log "  ./scripts/agent-credentials.sh $name"
