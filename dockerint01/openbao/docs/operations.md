# Operations

Every procedure here was run against OpenBao 2.7.1 while building this stack,
except [Authentik login](#optional-log-in-with-authentik), which is marked
as untested.

- [Health checks](#health-checks)
- [Restarts and reboots](#restarts-and-reboots)
- [Backups](#backups) · [Restore](#restore)
- [Break-glass root token](#break-glass-root-token)
- [Upgrading OpenBao](#upgrading-openbao)
- [Rotating the unseal key](#rotating-the-unseal-key)
- [Audit log rotation](#audit-log-rotation)
- [More admins / Authentik login](#adding-admins)
- [Migrating from hashicorp-vault](#migrating-from-hashicorp-vault)
- [Troubleshooting](#troubleshooting)

## Health checks

```bash
docker compose ps                        # openbao should be "healthy"
./scripts/bao status                     # Initialized true, Sealed false
curl -s https://openbao.internal.earles.io/v1/sys/health | jq
```

`/v1/sys/health` returns **200** when unsealed and active, **503** when sealed,
and **501** when not initialised. Gatus watches it (endpoint "OpenBao").
Prometheus metrics are at `/v1/sys/metrics?format=prometheus` without a token.

## Restarts and reboots

Nothing to do: the server auto-unseals from `unseal/unseal.key` on every start.
If it comes up **sealed**, the key file is missing, unreadable, or the wrong
one; see [Troubleshooting](#troubleshooting).

Tokens survive restarts. Agents and the sync just carry on.

## Backups

`openbao-backup` takes a Raft snapshot at start-up and then every 24 h, into
`$BACKUP_DIR` (default `/mnt/documents/openbao_backup`), and deletes snapshots
older than 30 days.

A snapshot holds **everything**: secrets, history, policies, auth config,
users, agent roles. It's encrypted, so it's useless without the unseal key.
That's why the key is stored in Vaultwarden, never next to the backups.

```bash
docker compose logs openbao-backup | tail -3     # "saved /backups/openbao-….snap (… bytes)"
ls -lh /mnt/documents/openbao_backup
```

**Manual snapshot** (before upgrades or risky changes):

```bash
./scripts/bao operator raft snapshot save /openbao/file/manual.snap
sudo mv data/manual.snap /mnt/documents/openbao_backup/openbao-manual-$(date +%F).snap
```

**Offsite copy:** the vaultwarden stack already syncs `/mnt/documents/vw_backup`
to B2 with rclone. To add OpenBao, add a second line to that cron, e.g.
`rclone sync /openbao_backup b2:earles-vw-backup/openbao-backup/`. Snapshots
are encrypted, so they're safe to ship offsite.

## Restore

Tested: a fresh, empty server plus a snapshot plus the unseal key gives back
everything, including your userpass login and every agent role.

1. Get the unseal key back if `unseal/` is gone:
   ```bash
   sudo mkdir -p unseal
   echo '<base64 from Vaultwarden>' | base64 -d | sudo tee unseal/unseal.key >/dev/null
   sudo chown -R 100:1000 unseal && sudo chmod 400 unseal/unseal.key && sudo chmod 500 unseal
   ```
2. Start from an empty data dir (move the old one aside, don't delete it):
   ```bash
   docker compose down
   sudo mv data data.broken-$(date +%F)
   docker compose up -d openbao
   ```
3. Initialise the empty server. This throwaway init only exists so you can run
   the restore; its root token and keys become meaningless once you do.
   ```bash
   ./scripts/bao operator init -recovery-shares=1 -recovery-threshold=1
   ```
4. Restore, using that throwaway root token:
   ```bash
   sudo cp /mnt/documents/openbao_backup/openbao-<latest>.snap data/restore.snap
   BAO_TOKEN=<throwaway root> ./scripts/bao operator raft snapshot restore -force /openbao/file/restore.snap
   sudo rm data/restore.snap
   ```
5. The server is now the snapshot: same users, same recovery keys (the
   **original** 5), same everything. Log in as yourself and bring the rest up:
   ```bash
   ./scripts/bao login -method=userpass username=<you>
   docker compose up -d
   ```

If the snapshot is older than your last [unseal key rotation](#rotating-the-unseal-key),
the server comes up sealed after the restore. Add the old key as
`previous_key` and restart.

## Break-glass root token

When no admin can log in (forgotten password, broken OIDC…), use the
recovery keys from `init` (any 3 of the 5) to mint a new root token:

```bash
sudo ./scripts/generate-root.sh
# Recovery key 1/3: ****
# Recovery key 2/3: ****
# Recovery key 3/3: ****
# ==> New root token (no expiry, no policy limits):
# s.xxxxxxxxxxxxxxxxxxxxxxxx
```

Fix what you need (e.g. reset your password, below), then revoke it:

```bash
export BAO_TOKEN=<new root>
printf '%s' '<new password>' | ./scripts/bao write auth/userpass/users/<you>/password password=-
./scripts/bao token revoke -self
```

Why a script and not the plain CLI? OpenBao 2.x only allows unauthenticated
root generation on the legacy `sys/generate-root/*` endpoints, and only on
a listener that opts in, but the `bao` CLI uses the newer authenticated
endpoints. `config/openbao.hcl` therefore has a second listener on
`127.0.0.1:8210` *inside the container* that opts in. It's reachable only via
`docker exec` on the host, never over the network (Traefik answers
`unsupported operation`). The script talks to it directly.

## Upgrading OpenBao

1. Read the release notes between your version and the target:
   https://github.com/openbao/openbao/releases. Watch for config keys being
   renamed or removed (2.x removed `disable_mlock`, for example).
2. Take a [manual snapshot](#backups).
3. Bump the tag on **both** `openbao` and `openbao-backup` in
   `docker-compose.yml`, commit, then:
   ```bash
   docker compose pull && docker compose up -d
   docker compose logs openbao | grep -iE 'error|warn' | tail
   ./scripts/bao status
   ```
4. Rollback: put the old tag back, and if the new version migrated storage,
   restore the snapshot from step 2.

The tag is pinned on purpose: Watchtower can still pick up rebuilds of the
same version (base-image security fixes), but it never jumps a secrets
manager to a new version behind your back.

The sync image is built locally and opted out of Watchtower. To update the
Bitwarden CLI inside it, bump `BW_CLI_VERSION` in `vaultwarden-sync/Dockerfile`
and run `docker compose up -d --build openbao-vaultwarden-sync`.

## Rotating the unseal key

Tested; the server re-encrypts its stored root key with the new key on the
first start.

```bash
sudo chmod 700 unseal
sudo sh -c 'head -c 32 /dev/urandom > unseal/unseal-2027-01.key'
sudo chown 100:1000 unseal/unseal-2027-01.key && sudo chmod 400 unseal/unseal-2027-01.key && sudo chmod 500 unseal
base64 < unseal/unseal-2027-01.key       # -> save in Vaultwarden next to the old one
```

```hcl
seal "static" {
  current_key_id  = "int01-2027-01"
  current_key     = "file:///openbao/unseal/unseal-2027-01.key"
  previous_key_id = "int01-2026-10"
  previous_key    = "file:///openbao/unseal/unseal.key"
}
```

`docker compose restart openbao`. Once it's unsealed, the `previous_*` lines
can go.

**Keep the old key** (in Vaultwarden at least) **until every snapshot taken
before the rotation has aged out** (30 days). An old snapshot restored onto
the server needs the old key to unseal; with it configured as `previous_key`,
it works.

## Audit log rotation

`logs/audit.log` records every request. The sync alone adds a few thousand
lines a day, so rotate it:

```bash
sudo ./scripts/install-logrotate.sh      # writes /etc/logrotate.d/openbao-audit
```

That rotates daily and keeps 30 compressed days. After each rotation it sends
`SIGHUP`, which makes OpenBao reopen the log file. If the audit log can't be
written (full disk, for example), OpenBao refuses requests rather than
running unaudited. That's by design, but it means "disk full" looks like
"everything broken".

## Adding admins

```bash
printf '%s' '<password>' | ./scripts/bao write auth/userpass/users/<name> \
  password=- token_policies=admin token_ttl=8h token_max_ttl=24h
```

For a read-only human, write a policy in `policies/` (e.g. `read` + `list` on
`kv/data/*` and `kv/metadata/*`), apply it, and use it instead of `admin`.

### Optional: log in with Authentik

*Not tested in this repo; adapt as needed.* Gives you SSO in the UI, with
access driven by an Authentik group.

1. In Authentik, create an **OAuth2/OpenID provider** + application `openbao`:
   - Client type: confidential. Note the client ID and secret.
   - Redirect URIs:
     `https://openbao.internal.earles.io/ui/vault/auth/oidc/oidc/callback` and
     `http://localhost:8250/oidc/callback` (for `bao login -method=oidc` on a laptop)
   - Scopes: `openid`, `email`, `profile`. Make sure a `groups` claim is
     included.
   - Create a group `openbao-admins` and add yourself.
2. In OpenBao:
   ```bash
   ./scripts/bao auth enable oidc
   ./scripts/bao write auth/oidc/config \
     oidc_discovery_url="https://authentik.internal.earles.io/application/o/openbao/" \
     oidc_client_id="<client id>" oidc_client_secret="<client secret>" \
     default_role=admin
   ./scripts/bao write auth/oidc/role/admin - <<'EOF'
   {
     "user_claim": "email",
     "groups_claim": "groups",
     "bound_audiences": ["<client id>"],
     "bound_claims": {"groups": ["openbao-admins"]},
     "allowed_redirect_uris": [
       "https://openbao.internal.earles.io/ui/vault/auth/oidc/oidc/callback",
       "http://localhost:8250/oidc/callback"
     ],
     "token_policies": ["admin"],
     "token_ttl": "8h"
   }
   EOF
   ```
3. In the UI, choose method **OIDC**, role `admin`. Keep your userpass login as
   the fallback for when Authentik is down.

## Migrating from hashicorp-vault

The old stack (`../hashicorp-vault/`) held only a test secret
(`kv-v1/test`). If you put anything else there, copy it across. From a machine
with the `vault` CLI and the old unseal keys (in Azure Key Vault, per its readme):

```bash
export VAULT_ADDR=https://vault.internal.earles.io
vault operator unseal   # x3
vault login
vault secrets list                       # see what exists
vault kv get -format=json kv-v1/<path> | jq .data
# then, for each secret worth keeping:
./scripts/bao kv put kv/<new path> key=value …
```

Then decommission it:

```bash
cd ../hashicorp-vault && docker compose down
```

After that, delete the unseal keys and root token from Azure Key Vault, and
finally the `hashicorp-vault/` directory (and `vault.internal.earles.io` DNS,
if it has a record). Its data dir is plain old Vault storage; archive it if
you're unsure.

## Troubleshooting

| Symptom | Cause / fix |
|---|---|
| `Sealed true` after start | Key problem. `docker compose logs openbao \| grep -i unseal`. *"no such file"*: `unseal/unseal.key` missing, restore it from Vaultwarden. *"failed to decrypt"*: wrong key (or a restored snapshot predating a rotation; add `previous_key`). *"permission denied"*: `sudo chown -R 100:1000 unseal`. |
| `Initialized false` | Empty or new `data/`. Either it's genuinely new (do the quickstart) or you meant to [restore](#restore). |
| Container restarts in a loop | Usually a config error. `docker compose logs openbao \| head -30`. |
| `permission denied` for you | Your login expired (8 h): `./scripts/bao login …`. Or check with `./scripts/bao token capabilities <path>`. |
| Agent: `source address … unauthorized by CIDR restrictions` | The agent's IP changed, or OpenBao sees Traefik's IP instead of the agent's because `x_forwarded_for_authorized_addrs` doesn't match the Traefik subnet. The error message shows the IP OpenBao saw. |
| Agent: `invalid role or secret ID` | `secret_id` destroyed, expired, or the role was revoked. Issue new credentials. |
| Agent: `permission denied` on a path | Not granted in `agents/<name>.hcl`, or you forgot `apply-policies.sh`. Remember the `kv/data/` prefix in policies. |
| `bootstrap.sh`: `No 'file' audit device` | The `audit` block is missing from `config/openbao.hcl`, or the server wasn't restarted after adding it. |
| `bootstrap.sh`: `Could not find the openbao_backend network` | Start the server first (`docker compose up -d openbao`). If the directory isn't called `openbao`, set `BACKEND_NETWORK=<dir>_backend`. |
| `cannot enable audit device via API` | Expected in OpenBao 2.x. Audit devices go in the config file. |
| Every request fails / hangs | Disk full, so the audit log can't be written. Free space; check `logs/` and that logrotate is installed. |
| Backup: `no credentials yet` | `credentials/backup/` missing. Run `bootstrap.sh`, which reissues anything missing. |

Re-issuing a sidecar's credentials: `sudo rm -r credentials/<role>`, re-run
`sudo -E ./scripts/bootstrap.sh` (with an admin token), then
`docker compose restart <container>`.
