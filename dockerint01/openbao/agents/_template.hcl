# Agent: __NAME__
# Created: __DATE__
#
# One file = one machine identity. It defines:
#   - the policy "agent-__NAME__" (the path blocks below), and
#   - the AppRole role "agent-__NAME__" (the "# role:" lines).
# Edit, commit, then run ./scripts/apply-policies.sh. Changes to policies
# apply to existing tokens immediately; role changes apply to new logins.
#
# Role settings, passed to `bao write auth/approle/role/agent-__NAME__`.
# role: token_ttl=1h
# role: token_max_ttl=8h
# role: secret_id_ttl=__SECRET_ID_TTL__
# role: token_bound_cidrs=__CIDR__
# role: secret_id_bound_cidrs=__CIDR__

# --- Own namespace -----------------------------------------------------------
# The agent may create, read, update and soft-delete secrets it owns
# (e.g. a database password it generated). It cannot destroy versions, so a
# human can always undelete / roll back with `bao kv undelete` / `kv rollback`.
path "kv/data/agents/__NAME__/*" {
  capabilities = ["create", "read", "update", "patch", "delete"]
}
path "kv/metadata/agents/__NAME__/*" {
  capabilities = ["read", "list", "update"]
}
path "kv/delete/agents/__NAME__/*" {
  capabilities = ["update"]
}

# --- Read grants -------------------------------------------------------------
# One block per secret the agent needs. Prefer exact paths over globs.
__GRANTS__
