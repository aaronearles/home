# admin: full control for humans (userpass / OIDC logins).
#
# This is effectively root, with two differences that matter:
#   - tokens carrying it expire (token_ttl on the login method), and
#   - every action is tied to a named human identity in the audit log.
# Keep the real root token revoked; regenerate one with recovery keys only
# for break-glass (see docs/operations.md).
path "*" {
  capabilities = ["create", "read", "update", "patch", "delete", "list", "sudo"]
}
