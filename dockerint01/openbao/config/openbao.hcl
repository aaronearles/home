# OpenBao server configuration
# Docs: https://openbao.org/docs/configuration/
#
# Every *.hcl file in this directory is loaded by the server, so keep only
# server config here (policies live in ../policies).

ui = true

# Log as JSON so Dozzle/Grafana can parse it.
log_format = "json"

# Integrated storage (Raft). A single node is fine for a homelab; the data dir
# holds the *encrypted* barrier. It is useless without the unseal key below.
storage "raft" {
  path    = "/openbao/file/raft"
  node_id = "openbao-int01"
}

# Plain HTTP inside the Docker network only. Traefik terminates TLS with the
# Let's Encrypt certificate and is the only path in from outside. Port 8200
# is NOT published on the host.
listener "tcp" {
  address     = "0.0.0.0:8200"
  tls_disable = true

  # Trust X-Forwarded-For only from the Traefik network, so OpenBao sees the
  # caller's real IP. AppRole CIDR binding (token_bound_cidrs /
  # secret_id_bound_cidrs) depends on this. Set it to the subnet printed by:
  #   docker network inspect traefik -f '{{(index .IPAM.Config 0).Subnet}}'
  # If this is wrong, CIDR-bound agent logins fail with "permission denied"
  # (they see Traefik's IP instead of the agent's IP).
  x_forwarded_for_authorized_addrs  = "172.18.0.0/16"
  x_forwarded_for_reject_not_present = false

  # /v1/sys/metrics without a token, so Grafana/Prometheus can scrape it.
  telemetry {
    unauthenticated_metrics_access = true
  }
}

# Break-glass listener: loopback inside the container only, so it's reachable
# only through `docker exec` on the host, never over the network. OpenBao 2.x
# refuses unauthenticated root-token generation by default; this listener
# re-allows it so scripts/generate-root.sh works when nobody can log in. It
# still takes 3 of the 5 recovery keys.
listener "tcp" {
  address     = "127.0.0.1:8210"
  tls_disable = true
  disable_unauthed_generate_root_endpoints = false
}

# Auto-unseal with a static 32-byte key kept on the host, outside ./data and
# outside the backup directory. See docs/concepts.md ("Sealing") for the
# trade-off. To rotate it, add a new key as current_* and move the old one to
# previous_*, then restart.
seal "static" {
  current_key_id = "int01-2026-10"
  current_key    = "file:///openbao/unseal/unseal.key"
}

# Audit log: every request and response, with secret values HMAC'd (so the
# log itself isn't a secret store). OpenBao only allows audit devices to be
# declared here, not enabled through the API.
# Search it: sudo jq 'select(.auth.metadata.role_name=="agent-<name>")' logs/audit.log
audit "file" "file" {
  description = "All requests and responses; secret values are HMAC'd"
  options {
    file_path = "/openbao/logs/audit.log"
  }
}

api_addr     = "https://openbao.internal.earles.io"
cluster_addr = "http://openbao:8201"

telemetry {
  prometheus_retention_time = "24h"
  disable_hostname          = true
}
