# How OpenBao works (and how this deployment uses it)

Vault/OpenBao feels opaque because a handful of ideas all show up at once.
They make sense in this order, each building on the one before:

1. [Sealing and the unseal key](#sealing-and-the-unseal-key): how data is protected on disk
2. [Secrets engines](#secrets-engines-where-secrets-live): where secrets live
3. [Tokens](#tokens-the-only-way-in): the only thing that grants access
4. [Auth methods](#auth-methods-how-you-get-a-token): how you trade an identity for a token
5. [Policies](#policies-what-a-token-may-do): what a token is allowed to do
6. [Response wrapping](#response-wrapping-handing-over-a-secret-safely): handing secrets over safely
7. [Audit](#audit-who-did-what): who did what

Then [the threat model](#threat-model-what-this-setup-protects-against) ties it
together.

---

## Sealing and the unseal key

Everything OpenBao stores in `./data` is encrypted with an internal
**encryption key**. That key is itself encrypted by a **root key**, and the root
key is what "unsealing" recovers. Until the server is unsealed it can't decrypt
anything, so it answers almost every request with `503 sealed`.

```
unseal key ──decrypts──▶ root key ──decrypts──▶ encryption key ──decrypts──▶ your secrets
(./unseal/)              (in ./data)           (in ./data)                  (in ./data)
```

There are two ways to provide the unseal key:

- **Shamir (the default, and what the old Vault setup used).** The key is split
  into 5 shares; after *every* restart someone types in 3 of them. That's very
  secure, and also why a homelab Vault ends up sealed and unused after the
  first reboot.
- **Auto-unseal (what this setup uses).** A `seal` block in the config tells
  the server where to fetch the key. Big deployments use a cloud KMS or an
  HSM. Here it's a `static` seal: a 32-byte key in `./unseal/unseal.key`.
  Restarts unseal by themselves.

**The trade-off, honestly:** anyone who gets root on dockerint01 can read the
key file *and* the data, and so every secret. That's true of every `.env` file
on that host today too, so this loses nothing. What the key file still buys you:

- `./data` and the NAS backups on their own are useless ciphertext. Someone who
  steals a snapshot from the NAS, or B2 if you sync it there, gets nothing
  without the key.
- The key lives outside the data dir and the backup path on purpose, and its
  copy lives in Vaultwarden.

With auto-unseal, init gives you **recovery keys** instead of unseal keys. They
can't decrypt anything. Their only use is to authorise operations like
[generating a new root token](operations.md#break-glass-root-token).

## Secrets engines: where secrets live

A *secrets engine* is a plugin mounted at a path. This setup mounts one:
**KV version 2** at `kv/`. It's a versioned key/value store: each secret is a
small JSON object (`{"username": "...", "password": "..."}`) at a path like
`kv/infra/proxmox/api`.

KV v2 has two kinds of paths under the hood, and policies are written against
them, so it's worth knowing:

| You type | The API path | Holds |
|---|---|---|
| `bao kv get kv/infra/x` | `kv/data/infra/x` | the secret's values |
| `bao kv metadata get kv/infra/x` | `kv/metadata/infra/x` | versions, timestamps, `custom_metadata` |
| `bao kv list kv/infra/` | `kv/metadata/infra/` (LIST) | the names in a folder |
| `bao kv delete kv/infra/x` | `kv/delete/infra/x` | soft delete (undo with `kv undelete`) |
| `bao kv destroy …` | `kv/destroy/infra/x` | permanent delete of a version |

Every write creates a new version, and the last 10 are kept. "Delete" is a soft
delete. Agents in this setup can soft-delete their own secrets but never
destroy them, so you can always roll back what an agent did.

`custom_metadata` is free-form key/value data about a secret, separate from the
secret itself. This setup uses it to control the Vaultwarden mirror
(`vaultwarden_sync=false`, `url=…`, `description=…`).

Other engines exist and are worth knowing about for later: *database*
(generates short-lived DB users on demand), *PKI* (issues certificates; you
already have step-ca for that), *transit* (encryption as a service), and *SSH*
(signed SSH certs). This setup starts with KV because it covers the actual need,
which is storing and sharing static credentials.

## Tokens: the only way in

Every request to OpenBao carries a **token**: a header `X-Vault-Token: s.xxxx`.
A token has:

- **policies**: what it may do (next sections)
- **a TTL**: when it expires. Tokens here last 15 min (backup), 1 h (agents),
  or 8 h (you).
- **metadata**: who it was issued to, used in the audit log

Nobody uses a long-lived token. Machines and people present an *identity* to an
auth method and get back a short-lived token. The root token is the one
exception (no policies, no TTL), which is why the quickstart revokes it.

## Auth methods: how you get a token

An auth method checks some proof of identity and, if it's good, mints a token
with the policies configured for that identity.

| Method | Mounted at | Used by | Proof |
|---|---|---|---|
| `userpass` | `auth/userpass/` | you | username + password |
| `approle` | `auth/approle/` | agents, the backup and sync containers | `role_id` + `secret_id` (+ source IP) |
| `oidc` (optional) | `auth/oidc/` | you, via Authentik SSO | Authentik login, see [operations.md](operations.md#optional-log-in-with-authentik) |

**AppRole** is the one to really understand, because it's how agents get in.
A *role* is a machine identity, for example `agent-claude-infra`.

- `role_id` is like a username. It isn't secret on its own and never changes.
- `secret_id` is like a password. It's random, you can issue several and revoke
  each one, and it can have its own TTL and use limit.
- **CIDR binding** pins both the `secret_id` and the resulting token to source
  IPs. A copied credentials file is useless from another machine.

The full lifecycle is in [machine-identities.md](machine-identities.md).

## Policies: what a token may do

A policy is a list of paths and the operations allowed on each. **Everything not
listed is denied.**

```hcl
# The agent can read exactly one infra secret…
path "kv/data/infra/cloudflare/dns-token" {
  capabilities = ["read"]
}
# …and manage its own folder.
path "kv/data/agents/claude-infra/*" {
  capabilities = ["create", "read", "update", "patch", "delete"]
}
```

- Capabilities: `read`, `list`, `create`, `update`, `patch`, `delete`, `sudo`, `deny`.
- `*` at the end is a prefix glob; `+` matches one path segment.
- A token's access is the union of its policies. `deny` always wins.
- **Policies are checked on every request.** Change or delete one and every
  token carrying it is affected immediately. That's what makes the agent
  kill switch instant.

The policies in this repo:

| Policy | Attached to | Grants |
|---|---|---|
| `admin` | your userpass/OIDC login | everything (like root, but with an expiry and your name on it) |
| `backup` | `backup` AppRole | `sys/storage/raft/snapshot` only |
| `vaultwarden-sync` | `vaultwarden-sync` AppRole | read `kv/{infra,agents,apps}/*` and its own login at `kv/system/vaultwarden-sync` |
| `agent-<name>` | `agent-<name>` AppRole | its own folder + whatever you grant in `agents/<name>.hcl` |
| `default` | every token automatically | look up / renew / revoke itself; unwrap response-wrapped data |

Test what a token can do before handing it out:

```bash
./scripts/bao token capabilities <token> kv/data/infra/proxmox/api
```

## Response wrapping: handing over a secret safely

Getting a `secret_id` to an agent is the chicken-and-egg problem: you need a
secret to get secrets. **Response wrapping** makes the handover safer. Instead
of the `secret_id`, OpenBao gives you a single-use **wrapping token** that
expires after, say, 15 minutes. The agent "unwraps" it to get the real
`secret_id`.

- If it leaks after the agent used it, it's worthless (single use).
- If someone intercepts it and uses it first, the agent's unwrap fails, so you
  *know* it was intercepted and can revoke.
- If it's never used, it expires.

`./scripts/agent-credentials.sh <name> --wrap 15m` and
`bao-agent unwrap <token>` do this for you.

## Audit: who did what

Every request and response is written to `logs/audit.log` as JSON lines.
Secret values are replaced with HMACs, so the log itself is not a secret store.
Each line has the identity (`.auth.display_name`, `.auth.metadata.role_name`),
the path, the operation and the source IP. If OpenBao can't write the audit
log, it refuses the request. Failing closed is deliberate.

```bash
# Everything a given agent did
sudo jq -c 'select(.auth.metadata.role_name=="agent-claude-infra" and .type=="response")
  | {time, op: .request.operation, path: .request.path, from: .request.remote_address}' logs/audit.log
```

In OpenBao 2.x, audit devices can only be declared in the server config (the
`audit` block in `config/openbao.hcl`), not enabled through the API.

---

## Threat model: what this setup protects against

| If this happens… | …then | Because |
|---|---|---|
| An agent's credentials file is copied off its machine | Useless elsewhere | `secret_id` and tokens are CIDR-bound to the agent's IP |
| An agent goes rogue / gets prompt-injected | It can read only its granted secrets, and write only under `kv/agents/<name>/` | Least-privilege policy, no `destroy` |
| You need to cut an agent off *now* | `agent-revoke.sh <name>`, effective on the next request | Policies are evaluated per request |
| A wrapping token is intercepted | You find out (the agent's unwrap fails) | Single-use wrapping |
| A backup snapshot leaks | Ciphertext only | Unseal key is not in the backup |
| `./data` is lost | Restore the latest snapshot + the unseal key from Vaultwarden | [Tested procedure](operations.md#restore) |
| The unseal key is lost | **Data is gone** | Keep the copy in Vaultwarden |
| Someone has root on dockerint01 | They can read everything | Same as every `.env` on that host; out of scope |
| A compromised container on the `traefik` network | Can reach OpenBao directly and claim any IP in `X-Forwarded-For`, defeating CIDR binding (it still needs a valid `role_id` + `secret_id`) | OpenBao trusts XFF from the whole Traefik subnet. See [hardening](machine-identities.md#hardening-options) |

What you don't get from this setup: protection if the host itself is owned, or
secrets that are safe once they're in an agent's context window (see
[advice for AI agents](machine-identities.md#advice-for-ai-agents)).
