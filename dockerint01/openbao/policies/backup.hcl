# backup: used by the openbao-backup container (AppRole "backup").
# Can take Raft snapshots and nothing else. It cannot read secrets through
# the API; snapshot contents stay encrypted with the barrier key.
path "sys/storage/raft/snapshot" {
  capabilities = ["read"]
}
