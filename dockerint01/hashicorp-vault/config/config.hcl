ui = true
disable_mlock = "true"

storage "raft" {
  path    = "/vault/data"
  node_id = "node1"
}

listener "tcp" {
  address = "[::]:8200"
  tls_disable = "false"
  tls_cert_file = "/certs/wildcard.earles.internal.crt"
  tls_key_file  = "/certs/wildcard.earles.internal_decrypted.key"
}

api_addr = "https://vault.earles.internal:8200"
cluster_addr = "https://vault.earles.internal:8201"