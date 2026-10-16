# vaultwarden-sync: used by the openbao-vaultwarden-sync container
# (AppRole "vaultwarden-sync"). Read-only. Keep the prefixes here in step with
# SYNC_PREFIXES in .env. A prefix missing here is skipped with a warning.

# Mirrored prefixes: list + read metadata (for version/opt-out) + read data.
path "kv/metadata/infra/*" {
  capabilities = ["read", "list"]
}
path "kv/data/infra/*" {
  capabilities = ["read"]
}

path "kv/metadata/agents/*" {
  capabilities = ["read", "list"]
}
path "kv/data/agents/*" {
  capabilities = ["read"]
}

path "kv/metadata/apps/*" {
  capabilities = ["read", "list"]
}
path "kv/data/apps/*" {
  capabilities = ["read"]
}

# The sync's own Vaultwarden login (email / password / optional API key).
path "kv/data/system/vaultwarden-sync" {
  capabilities = ["read"]
}
