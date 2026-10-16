# OpenBao

Secrets manager for the homelab, at **https://openbao.internal.earles.io**.
[OpenBao](https://openbao.org) is the Linux Foundation fork of HashiCorp Vault
from before the license change. Same concepts, same API, and the `bao` CLI
takes the same commands as `vault`.

It replaces `../hashicorp-vault/` (see [Migrating](docs/operations.md#migrating-from-hashicorp-vault)).

**What it's for here:**

1. **One place for infrastructure secrets** (Cloudflare tokens, Proxmox API
   users, database passwords) instead of scattered `.env` files.
2. **Narrowly scoped machine identities for agents.** Each agent gets its own
   login, can read only the secrets you grant it, has its own folder to
   store secrets it creates, and can be cut off instantly.
3. **A human-friendly mirror in Vaultwarden.** Selected secrets show up in
   your Bitwarden apps automatically. OpenBao stays the source of truth.

| Doc | Read it when |
|---|---|
| This README | First deploy, and as a daily cheat sheet |
| [docs/concepts.md](docs/concepts.md) | You want to understand how it actually works (start here if Vault never "clicked") |
| [docs/machine-identities.md](docs/machine-identities.md) | Giving an agent, script or CI job access |
| [docs/vaultwarden-sync.md](docs/vaultwarden-sync.md) | Setting up or debugging the Vaultwarden mirror |
| [docs/operations.md](docs/operations.md) | Backups, restore, upgrades, break-glass, troubleshooting |

## What's in the stack

| Container | What it does |
|---|---|
| `openbao` | The server. Raft storage in `./data`, auto-unseals with `./unseal/unseal.key`, audit log in `./logs/audit.log`. Behind Traefik only, with no host ports. |
| `openbao-backup` | Daily Raft snapshot to `$BACKUP_DIR` (NAS), keeps 30 days. Its identity can take snapshots and nothing else. |
| `openbao-vaultwarden-sync` | Every 5 min, mirrors `kv/infra/`, `kv/agents/` and `kv/apps/` into Vaultwarden. Read-only identity. |

```
openbao/
├── docker-compose.yml
├── config/openbao.hcl        # server config (storage, listener, seal, audit)
├── policies/                 # one .hcl per policy: admin, backup, vaultwarden-sync
├── agents/                   # one .hcl per agent identity (policy + AppRole settings)
│   └── _template.hcl
├── scripts/                  # run on the dockerint01 host
│   ├── bao                   # the bao CLI, run inside the container
│   ├── init-unseal-key.sh    # first-time: make the auto-unseal key
│   ├── bootstrap.sh          # first-time (re-runnable): engines, auth, policies, roles
│   ├── apply-policies.sh     # push policies/ + agents/ from git to the server
│   ├── agent-create.sh       # new agent identity
│   ├── agent-credentials.sh  # issue credentials to an agent
│   ├── agent-revoke.sh       # rotate or kill an agent's access
│   ├── generate-root.sh      # break-glass: new root token from recovery keys
│   ├── install-logrotate.sh  # daily rotation for logs/audit.log
│   └── backup-loop.sh        # runs inside openbao-backup
├── client/bao-agent          # tiny curl+jq client, copy it to agent machines
├── vaultwarden-sync/         # the sync sidecar (Dockerfile + sync.mjs)
└── (gitignored) data/ logs/ unseal/ credentials/ backups/ .env
```

## Quickstart (first deploy)

Everything runs on dockerint01 from this directory. You need `docker` and
`sudo`; you don't need the `bao` CLI on the host (`./scripts/bao` runs it
inside the container).

### 1. Check the Traefik subnet

OpenBao trusts `X-Forwarded-For` only from Traefik, so it sees each caller's
real IP (needed for IP-bound agent logins). Confirm the subnet matches
`x_forwarded_for_authorized_addrs` in `config/openbao.hcl`:

```bash
docker network inspect traefik -f '{{(index .IPAM.Config 0).Subnet}}'
```

### 2. Create the unseal key

```bash
cp .env.sample .env          # nothing secret in it; adjust BACKUP_DIR if needed
sudo ./scripts/init-unseal-key.sh
```

It prints the key in base64. **Save it in Vaultwarden now** as
"OpenBao unseal key (dockerint01)". Without it, the data and every backup are
unrecoverable. ([Why a key file?](docs/concepts.md#sealing-and-the-unseal-key))

### 3. Start the server and initialise it

```bash
docker compose up -d openbao
./scripts/bao operator init -recovery-shares=5 -recovery-threshold=3
```

`init` prints **5 recovery keys** and the **initial root token**, once.
Save all of it in Vaultwarden (one secure note is fine). Recovery keys are only
for break-glass (minting a new root token); day to day you never need them.

`./scripts/bao status` should now show `Initialized true`, `Sealed false`.
Restarts from now on unseal by themselves.

### 4. Bootstrap

```bash
export BAO_TOKEN=<initial root token>
sudo -E ./scripts/bootstrap.sh
```

It enables the KV store and auth methods, loads every policy, creates the
identities for the two sidecars (writing their credentials to `credentials/`),
and asks for a username and password for **your** admin login. It is safe to
re-run: it only fills in what's missing.

### 5. Switch to your own login and revoke root

```bash
unset BAO_TOKEN
./scripts/bao login -method=userpass username=<you>   # token valid 8h
BAO_TOKEN=<initial root token> ./scripts/bao token revoke -self
```

From now on you're a named human with an expiring token, and the audit log
says so. If you ever need root again, [regenerate it](docs/operations.md#break-glass-root-token)
with the recovery keys.

### 6. Vaultwarden sync (optional, recommended)

Follow [docs/vaultwarden-sync.md](docs/vaultwarden-sync.md#setup). In short:
create a dedicated Vaultwarden account, store its login in
`kv/system/vaultwarden-sync`, set the target in `.env`. Then:

```bash
docker compose up -d          # starts openbao-backup and openbao-vaultwarden-sync
docker compose logs -f openbao-vaultwarden-sync
```

(Without step 6 the sync container just waits and logs that it's waiting.)

### 7. Log rotation

```bash
sudo ./scripts/install-logrotate.sh   # the audit log grows by MBs a day
```

### 8. Check it

- UI: https://openbao.internal.earles.io (method: Username)
- `docker compose ps`: all three containers up, `openbao` healthy
- `ls $BACKUP_DIR`: a `openbao-*.snap` appears within a minute of step 6
- Gatus: the "OpenBao" endpoint goes green

## Where secrets live

One KV v2 store, mounted at `kv/`. The folder decides who can see a secret:

| Path | For | Who can read | Mirrored to Vaultwarden |
|---|---|---|---|
| `kv/infra/<service>/<name>` | Infrastructure creds (Cloudflare, Proxmox, Linode…) | you; agents you grant, per secret | yes |
| `kv/apps/<stack>/<name>` | Secrets for docker stacks on dockerint01 | you; agents you grant | yes |
| `kv/agents/<agent>/…` | Secrets an agent created (e.g. a DB password it generated) | you; that agent | yes |
| `kv/personal/…` | Yours only | you | no |
| `kv/system/…` | OpenBao's own plumbing (sync's Vaultwarden login) | you; the one service that needs it | no |

Opt a single secret out of the mirror with
`./scripts/bao kv metadata put -custom-metadata=vaultwarden_sync=false kv/<path>`.

## Daily cheat sheet

```bash
./scripts/bao login -method=userpass username=<you>        # once per 8h

# Write / read / list
./scripts/bao kv put kv/infra/cloudflare/dns-token token=-  # "-" reads the value from stdin (not saved in shell history)
./scripts/bao kv get kv/infra/cloudflare/dns-token
./scripts/bao kv get -field=token kv/infra/cloudflare/dns-token
./scripts/bao kv list kv/infra/

# Update one field, keep the rest
./scripts/bao kv patch kv/infra/proxmox/api password=-

# History: every write is a new version (last 10 kept)
./scripts/bao kv metadata get kv/infra/proxmox/api
./scripts/bao kv get -version=2 kv/infra/proxmox/api
./scripts/bao kv rollback -version=2 kv/infra/proxmox/api
./scripts/bao kv undelete -versions=3 kv/infra/proxmox/api  # after a `kv delete`

# Agents
./scripts/agent-create.sh <name> --read infra/cloudflare/dns-token --cidr 10.0.20.15/32
./scripts/agent-credentials.sh <name> --wrap 15m
./scripts/agent-revoke.sh <name>                          # kill switch

# Who did what
sudo jq -c 'select(.type=="response") | {time, who: (.auth.metadata.role_name // .auth.display_name),
  op: .request.operation, path: .request.path, from: .request.remote_address}' logs/audit.log | tail
```

Any machine with the `bao` CLI can also talk to it directly:
`export BAO_ADDR=https://openbao.internal.earles.io`.
