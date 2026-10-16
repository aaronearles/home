# Vaultwarden sync

`openbao-vaultwarden-sync` mirrors selected OpenBao secrets into Vaultwarden,
so you can look them up in the Bitwarden browser extension or phone app.

- **One-way.** OpenBao → Vaultwarden. OpenBao is the source of truth; edits
  made in Vaultwarden are reverted on the next cycle.
- **Every 5 minutes** (`SYNC_INTERVAL_SECONDS`), it walks `kv/infra/`,
  `kv/agents/` and `kv/apps/` (`SYNC_PREFIXES`).
- **Only touches its own items.** It manages only items that carry an
  `openbao_path` field. Anything else in the same folder or collection is
  left alone.

## How it works

Bitwarden encrypts everything client-side, so there's no plain HTTP API to
write items to. The container therefore runs the official **Bitwarden CLI**
in server mode (`bw serve`, listening on 127.0.0.1 inside the container only),
which handles the crypto. `sync.mjs` reads OpenBao and drives `bw serve`.

```
OpenBao ──(AppRole "vaultwarden-sync", read-only)──▶ sync.mjs ──▶ bw serve ──HTTPS──▶ Vaultwarden
                                                        ▲
                     kv/system/vaultwarden-sync ────────┘ (its own Vaultwarden login)
```

The only credentials on disk are the AppRole `role_id`/`secret_id` in
`credentials/vaultwarden-sync/`, bound to the stack's backend network. The
Vaultwarden login is fetched from OpenBao at startup.

## Setup

### 1. Create a dedicated Vaultwarden account

Use the web vault at https://vaultwarden.internal.earles.io, e.g.
`openbao-sync@earles.io` with a long random master password. **Don't use your
own account.** The sync needs the master password to decrypt, and a dedicated
account means a leak exposes only what's mirrored, not your whole vault.

(If signups are disabled, invite the address from the Vaultwarden admin page
first.)

### 2. Share it with yourself through an organization (recommended)

Still logged in as the sync account:

1. **New organization**, e.g. "Homelab".
2. It comes with a **Default collection**. Rename it "OpenBao" if you like.
3. **Members → Invite** your personal account, with access to that collection
   (read-only is enough: *Can view*).
4. Accept the invite from your own account, then **confirm** the member back
   in the sync account.

Copy the organization ID and the collection ID from the web vault URL
(`…/organizations/<org id>/vault?collectionId=<collection id>`).

Without an organization, the sync can write into a folder in its own vault
instead (`VW_FOLDER=OpenBao`). That works too, but then you have to log in as
the sync account to see anything.

### 3. Store its login in OpenBao

```bash
./scripts/bao kv put kv/system/vaultwarden-sync \
  email=openbao-sync@earles.io password=-
# type the master password, then Enter and Ctrl-D
```

Optional: also add `client_id=` and `client_secret=` from the sync account's
*Settings → Security → Keys → API key*. Then the CLI logs in with the API key,
which avoids "new device login" emails. The password is still needed to
decrypt.

### 4. Configure and start

In `.env`:

```bash
VW_URL=https://vaultwarden.internal.earles.io
VW_ORGANIZATION_ID=<org id>
VW_COLLECTION_ID=<collection id>
```

```bash
docker compose up -d --build openbao-vaultwarden-sync
docker compose logs -f openbao-vaultwarden-sync
```

A healthy start looks like:

```
bw: logging in to https://vaultwarden.internal.earles.io as openbao-sync@earles.io
bw: vault unlocked
target: organization 090cc7fb-…, collection 6ef7f58b-…
create infra/cloudflare/dns-token
sync done: {"created":3,"updated":0,"unchanged":0,"trashed":0,"skipped":1}
```

To preview without writing anything, set `SYNC_DRY_RUN=true`.

## What an item looks like

| OpenBao secret | Vaultwarden item |
|---|---|
| has a `username` or `password` key | **Login** item: `username`, `password`, `totp` and `url` map to the login fields |
| no `username`/`password` | **Secure note** |
| every other key | a **hidden custom field** with the same name |
| path, e.g. `infra/proxmox/api` | item name (override with `custom_metadata.vaultwarden_name`) |
| always | a text field `openbao_path` (how the sync recognises its items) and a note saying where it came from |

Control it per secret with **custom metadata**. It doesn't change the secret
or create a new version:

```bash
# Don't mirror this one
./scripts/bao kv metadata put -custom-metadata=vaultwarden_sync=false kv/infra/some/secret

# Nicer name, a URL for autofill, and a description in the notes
./scripts/bao kv metadata put \
  -custom-metadata=vaultwarden_name="Proxmox API (terraform)" \
  -custom-metadata=url=https://pve.earles.internal:8006 \
  -custom-metadata=description="Used by terraform/proxmox" \
  kv/infra/proxmox/api
```

Lifecycle:

| In OpenBao | In Vaultwarden (next cycle) |
|---|---|
| new secret | item created |
| new version / metadata change | item updated |
| `kv delete` (soft) or `kv metadata delete` | item moved to **trash** (`SYNC_DELETE=false` to keep it) |
| `kv undelete` | item recreated |
| `vaultwarden_sync=false` set later | item moved to trash |
| item edited by hand in Vaultwarden | edit reverted |

## Changing what's mirrored

`SYNC_PREFIXES` and `policies/vaultwarden-sync.hcl` must agree. To add
`kv/personal/`, add `personal/` to `SYNC_PREFIXES`, add matching `metadata`
(read, list) and `data` (read) blocks to the policy, then:

```bash
./scripts/apply-policies.sh && docker compose up -d openbao-vaultwarden-sync
```

If a prefix is in `.env` but not in the policy, the sync logs
`WARN: cannot list kv/personal/: … permission denied` and skips it. It never
treats "can't read" as "deleted", so nothing gets trashed.

## Troubleshooting

| Log says | Fix |
|---|---|
| `waiting for OpenBao credentials` | `credentials/vaultwarden-sync/` missing. Run `./scripts/bootstrap.sh`. |
| `waiting for kv/system/vaultwarden-sync` | Do setup step 3. |
| `Insecure URL not allowed. All URLs must use HTTPS` | `VW_URL` must be `https://…`. The Bitwarden CLI refuses plain HTTP. |
| `unable to verify the first certificate` / `self-signed certificate` | Vaultwarden's certificate is from a private CA. Put the CA in `credentials/vaultwarden-sync/ca.crt` and set `NODE_EXTRA_CA_CERTS=/credentials/ca.crt`. |
| `source address … unauthorized by CIDR restrictions` | The container reached OpenBao over the wrong network. `BAO_ADDR` must be `http://openbao-backend:8200` (the backend-only alias). If the backend subnet changed, re-run `bootstrap.sh`. |
| `getaddrinfo ENOTFOUND vaultwarden.internal.earles.io` / `ECONNREFUSED` | The container can't resolve or reach the host's Traefik. Add `extra_hosts: ["vaultwarden.internal.earles.io:host-gateway"]` to the service. |
| `Username or password is incorrect` | Wrong password in `kv/system/vaultwarden-sync`. |
| Login fails after a Bitwarden CLI or Vaultwarden upgrade | Version skew. Pin `BW_CLI_VERSION` in `vaultwarden-sync/Dockerfile` to a release from around your Vaultwarden version, then rebuild (`--build`). |
| Container `unhealthy` | No successful cycle in 30 minutes. Read the log above the latest `ERROR`. |

Known limits: one OpenBao instance per target folder or collection. Two syncs
pointed at the same place would trash each other's items. Attachments and
non-string values are not supported; nested JSON becomes a string field.
