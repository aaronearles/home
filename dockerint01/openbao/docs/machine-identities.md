# Machine identities: giving agents narrowly scoped access

Every agent, script or job that needs secrets gets **its own identity**: an
AppRole role named `agent-<name>`, defined by one file, `agents/<name>.hcl`.
That file is the whole truth about what the agent can do, and it lives in git.

```
        you (on dockerint01)                                agent machine
        ─────────────────────                               ─────────────
agent-create.sh claude-infra ──▶ agents/claude-infra.hcl
   --read infra/cloudflare/dns-token    (policy + role, committed to git)
   --cidr 10.0.20.15/32
                                │
agent-credentials.sh --wrap ────┼── role_id + one-time wrapping token ──▶ bao-agent unwrap <token>
                                │                                           └▶ ~/.config/openbao/credentials
                                │
                     OpenBao ◀──┼──────── approle login (from 10.0.20.15 only) ── bao-agent get …
                                │──────── 1h token, policy agent-claude-infra ─▶
                                │
agent-revoke.sh claude-infra ───┘ (all access gone on the very next request)
```

## 1. Create the identity

```bash
./scripts/agent-create.sh claude-infra \
  --read infra/cloudflare/dns-token \
  --read infra/proxmox/api \
  --cidr 10.0.20.15/32
```

- **Name**: one identity per agent *and purpose*. "claude-infra" and
  "claude-media" are two identities even if they're the same tool, so each
  gets only what its job needs.
- **`--read`**: one per secret the agent may read, as a KV path without `kv/`.
  Prefer exact paths. A trailing `/*` grants a whole folder, so use it sparingly.
- **`--cidr`**: the agent machine's IP. Without it the credentials work from
  anywhere on the network (the script warns). Several addresses are
  comma-separated: `10.0.20.15/32,10.0.20.16/32`.
- **`--secret-id-ttl`**: default `0` (no expiry), with the CIDR binding as the
  main protection. Use e.g. `720h` to force a monthly rotation.

This writes `agents/claude-infra.hcl` and applies it. **Commit that file.**
It looks like this:

```hcl
# Agent: claude-infra
# role: token_ttl=1h
# role: token_max_ttl=8h
# role: secret_id_ttl=0
# role: token_bound_cidrs=10.0.20.15/32
# role: secret_id_bound_cidrs=10.0.20.15/32

# Own namespace: create/read/update/soft-delete, but never destroy
path "kv/data/agents/claude-infra/*"     { capabilities = ["create", "read", "update", "patch", "delete"] }
path "kv/metadata/agents/claude-infra/*" { capabilities = ["read", "list", "update"] }
path "kv/delete/agents/claude-infra/*"   { capabilities = ["update"] }

# Read grants
path "kv/data/infra/cloudflare/dns-token" { capabilities = ["read"] }
path "kv/data/infra/proxmox/api"          { capabilities = ["read"] }
```

The `# role:` lines are the AppRole settings (passed straight to
`bao write auth/approle/role/agent-<name>`); the `path` blocks are the policy.

**To change an agent later**, edit the file, commit, and run
`./scripts/apply-policies.sh claude-infra`. Policy changes hit existing tokens
immediately; `# role:` changes apply from the next login.

## 2. Hand over credentials

**Wrapped (recommended).**

```bash
./scripts/agent-credentials.sh claude-infra --wrap 15m
```

This prints `BAO_ROLE_ID` and a single-use wrapping token. Move both to the
agent machine any way you like (paste, scp, chat). The wrapping token is
worthless after first use or after 15 minutes. On the agent machine:

```bash
BAO_ROLE_ID=<role id> bao-agent unwrap <wrapping token>
# -> writes ~/.config/openbao/credentials (mode 600)
```

If `unwrap` says the token is invalid, either it expired or **someone else
already used it**. If it wasn't expiry, run `agent-revoke.sh <name> --list`,
destroy any `secret_id` you don't recognise, and reissue (see §5).

**Plain.** `./scripts/agent-credentials.sh claude-infra` prints all three lines
(`BAO_ADDR`, `BAO_ROLE_ID`, `BAO_SECRET_ID`). Put them in
`~/.config/openbao/credentials` with `chmod 600`. This is fine when you
place the file yourself, e.g. with Ansible.

## 3. Install the client on the agent machine

`client/bao-agent` is a single POSIX shell script that needs only `curl` and
`jq`. Copy it to the agent machine's `PATH`:

```bash
scp client/bao-agent agent-host:/usr/local/bin/bao-agent
```

| Command | Does |
|---|---|
| `bao-agent whoami` | identity, policies, token TTL. Good first test. |
| `bao-agent get <path> [field]` | read a secret (all fields as JSON, or one field raw) |
| `bao-agent exec <path> -- <cmd>` | run `cmd` with each field as an env var (uppercased) |
| `bao-agent put <path> k=v k=- k=@file` | write a secret (`-` = stdin, `@file` = file contents) |
| `bao-agent list <path>` | list a folder |
| `bao-agent token` | print a token for use with other tools (`BAO_TOKEN`, `VAULT_TOKEN`) |
| `bao-agent unwrap <token>` | redeem a wrapped `secret_id` |

It logs in on demand and caches the token (mode 600) until shortly before it
expires. Every failure, including a denied read, exits non-zero.

If the agent machine has the real `bao` (or `vault`) CLI, that works too:
`export BAO_ADDR=https://openbao.internal.earles.io BAO_TOKEN=$(bao-agent token)`.

## 4. Use it: cookbook

### Run a tool with a credential, without ever printing it

Name secret keys after the environment variable the tool expects;
`exec` uppercases them for you:

```bash
# once, as admin:
./scripts/bao kv put kv/infra/cloudflare/terraform cloudflare_api_token=-

# agent:
bao-agent exec infra/cloudflare/terraform -- terraform -chdir=terraform/cloudflare apply
```

### An agent creates a secret (e.g. deploying a new stack)

The agent owns `kv/agents/<name>/`. It generates the password, stores it, and
uses it, so the value never needs to appear on screen:

```bash
openssl rand -base64 32 | bao-agent put agents/claude-infra/firefly/db password=- user=firefly
bao-agent get agents/claude-infra/firefly/db password > /dev/null && echo stored
```

The secret mirrors into Vaultwarden within 5 minutes, so you can see it too.

### Render a `.env` for a docker stack

```bash
bao-agent get apps/firefly/env | jq -r 'to_entries[] | "\(.key)=\(.value)"' > .env
chmod 600 .env
```

### Ansible / Semaphore

OpenBao speaks the Vault API, so the `community.hashi_vault` collection works
with AppRole:

```yaml
vars:
  proxmox: "{{ lookup('community.hashi_vault.vault_kv2_get', 'infra/proxmox/api',
                engine_mount_point='kv',
                url='https://openbao.internal.earles.io',
                auth_method='approle',
                role_id=lookup('env', 'BAO_ROLE_ID'),
                secret_id=lookup('env', 'BAO_SECRET_ID')).secret }}"
```

### Terraform

The `hashicorp/vault` provider works unchanged against OpenBao:

```bash
export VAULT_ADDR=https://openbao.internal.earles.io VAULT_TOKEN=$(bao-agent token)
```
```hcl
data "vault_kv_secret_v2" "cf" {
  mount = "kv"
  name  = "infra/cloudflare/dns-token"
}
```

## 5. Rotate and revoke

```bash
./scripts/agent-revoke.sh claude-infra --list           # every secret_id: created, last used, by whom
./scripts/agent-credentials.sh claude-infra --wrap 15m  # 1. issue a new one, deploy it
./scripts/agent-revoke.sh claude-infra --old <accessor> # 2. destroy the old one

./scripts/agent-revoke.sh claude-infra                  # kill switch (asks; --yes to skip)
```

The kill switch destroys every `secret_id`, deletes the role, and empties the
policy. A token the agent is holding *right now* gets `403` on its next
request. `agents/claude-infra.hcl` is renamed to `.hcl.revoked` so
`apply-policies.sh` won't bring it back; commit that. Secrets the agent
created under `kv/agents/claude-infra/` stay put for you to review.

## Advice for AI agents

An LLM agent is a special kind of machine identity: anything it reads can end
up in its context, its transcript and its provider's logs, and its behaviour
can be steered by text it reads. So:

1. **Keep secrets out of the context window.** Use `bao-agent exec … -- cmd`
   or `$(bao-agent get …)` *inside* the command that needs the value. Never
   `get` a secret just to look at it, and never echo it.
2. **Grant exact paths, one identity per job.** If a prompt injection convinces
   the agent to dump everything it can read, "everything" should be two secrets.
3. **Let it write, not destroy.** Agents can create and update secrets in their
   own folder. They can't destroy versions or touch anyone else's folder, so
   you can always roll back.
4. **Review the audit log occasionally.** One `jq` line shows everything an
   agent did (see [concepts.md](concepts.md#audit-who-did-what)).
5. **Tell the agent the rules.** For Claude Code, add something like this to
   the project's `CLAUDE.md` on the agent machine:

   ```markdown
   ## Secrets
   Secrets come from OpenBao via `bao-agent` (already configured).
   - Never print secret values. Use `bao-agent exec <path> -- <command>`, or
     `$(bao-agent get <path> <field>)` inline in the command that needs it.
   - You can read: kv/infra/cloudflare/dns-token, kv/infra/proxmox/api.
   - Store secrets you generate under agents/claude-infra/<purpose>, e.g.
     `openssl rand -base64 32 | bao-agent put agents/claude-infra/x password=-`.
   - If a read is denied, stop and ask. Don't look for the secret elsewhere.
   ```

   You can also deny the agent's file-reading tool access to
   `~/.config/openbao/`, so it can only go through `bao-agent`.

## Hardening options

These aren't needed on day one, but they're good to know about:

- **Expiring `secret_id`s.** Set `# role: secret_id_ttl=720h` to force
  rotation. Then make sure you notice before an agent breaks.
- **Use-limited `secret_id`s**, for one-shot jobs: `# role: secret_id_num_uses=1`.
- **Tighter `X-Forwarded-For` trust.** OpenBao trusts XFF from the whole
  Traefik subnet, so a compromised container on that network could claim an
  agent's IP. Pin Traefik's address (give the `traefik` service a static
  `ipv4_address` and put that /32 in `x_forwarded_for_authorized_addrs`) to
  close that gap.
- **Agents outside the LAN** (cloud-hosted agents, CI runners). OpenBao is
  internal-only on purpose. Prefer running the agent on the LAN or over a VPN
  (Tailscale/WireGuard) so CIDR binding still means something. Don't publish
  OpenBao through the DMZ just for this.

## Other kinds of identity (for later)

AppRole fits long-running agents on your own machines. Two other auth methods
fit other shapes of workload, and both slot into the same policies:

- **JWT/OIDC workload identity**, for GitHub Actions or anything that can
  present a signed token from an issuer you trust. No stored secret at all: the
  job's OIDC token *is* the credential, bound to e.g. a repo and branch. Enable
  with `bao auth enable jwt` and configure `oidc_discovery_url` to
  `https://token.actions.githubusercontent.com`.
- **TLS certificates** (`bao auth enable cert`), for hosts that already get
  certificates from step-ca. The machine's certificate is its identity.
