# mc-bedrock

Minecraft Bedrock Dedicated Server (BDS) with Xbox Live broadcasting via MCXboxBroadcast, so Xbox and mobile players can join from the friends list. Rotates between three worlds (a hand-built classic **Skyblock**, a normal **survival** world and a **creative** world), with nightly backups.

> Day-to-day operation (giving items, resets, restarts, troubleshooting) is documented in **[ADMIN-RUNBOOK.md](ADMIN-RUNBOOK.md)**, which is written so an AI agent can operate the server.

## Services

| Service | Image | Purpose |
|---|---|---|
| `minecraft` (`minecraft_itzg`) | `itzg/minecraft-bedrock-server` | Bedrock dedicated server, host networking |
| `mcxboxbroadcast` | `eclipse-temurin:21-jre-jammy` | Runs the MCXboxBroadcast jar: advertises the server as an Xbox Live session for the `mcearlesio` account and hands joining friends off to `mc.earles.io:19132` |
| Traefik (`../traefik`) | `traefik` | Terminates HTTPS for the NetherNet handshake on TCP 19132 with a Let's Encrypt cert for `mc.earles.io` |

## Directory structure

```
mc-bedrock/
├── docker-compose.yml
├── README.md
├── ADMIN-RUNBOOK.md            # Operating guide (AI-agent friendly)
├── CLAUDE.md                   # Loads the runbook for Claude Code sessions in this dir
├── switch-world.sh             # Rotate between skyblock / survival / creative
├── reset-skyblock.sh           # Full or live reset of the Skyblock world
├── backup-worlds.sh            # Nightly (cron) backup of all worlds, 14-day retention
├── .env                        # Active world/mode, written by switch-world.sh (not in git)
├── tools/leveldat.py           # Reads/edits Bedrock level.dat (little-endian NBT)
├── ping.py                     # NetherNet status check (GET /v1/join)
├── update.sh                   # Updates JAR, pulls images, recreates containers
├── commands.txt                # Handy console commands
├── MCXboxBroadcastStandalone.jar  # Downloaded by update.sh (not in git)
├── config/
│   └── config.yml              # MCXboxBroadcast configuration
├── backups/                    # nightly/ archives + backup.log, Skyblock reset backups (not in git)
└── data/                       # BDS data: worlds, server.properties, permissions.json (not in git)
```

## How networking works (NetherNet)

Since Bedrock 1.26.5x, **NetherNet is the only supported transport**. RakNet (plain UDP 19132) is gone. A client connection works like this:

1. **Handshake: TCP 19132, HTTPS.** The client sends `GET /v1/join` and `POST /v1/join/<id>`. BDS only speaks *plain HTTP*, and answers a TLS ClientHello with a handshake-failure alert. So Traefik terminates TLS on 19132 and forwards to BDS on **19133** (`SERVER_PORT=19133`).
   - **By hostname** (`mc.earles.io`, also used by the Xbox friends hand-off): the client requires a **publicly trusted cert** and does *not* fall back. Traefik serves the `production` (Let's Encrypt via Cloudflare DNS-01) cert.
   - **By IP** (`172.20.100.202`): the client rejects Traefik's default cert, then **retries in plain HTTP**, which Traefik passes straight through.
2. **Gameplay: UDP 19140-19159.** This is one WebRTC/ICE port per client (`SERVER_UDP_PORTS`), going **directly to BDS**, not through Traefik.

Why host networking: the per-client UDP negotiation doesn't survive Docker's bridge NAT.

| Port | Proto | Who listens | Purpose |
|---|---|---|---|
| 19132 | TCP | Traefik (`minecraft` entrypoint) | HTTPS/HTTP handshake → BDS 19133 |
| 19133 | TCP | BDS | Plain-HTTP signaling (internal) |
| 19140-19159 | UDP | BDS | Gameplay (WebRTC) |
| 7551 | UDP | BDS | NetherNet LAN discovery (broadcast; doesn't cross subnets) |

Traefik config lives in `../traefik`: the `minecraft` entrypoint in `config/traefik.yaml`, port `19132:19132/tcp` in `docker-compose.yml`, and the routers in `config/conf/external-minecraft.yaml`.

**Firewall / port forwarding:** LAN clients need TCP 19132 + UDP 19140-19159 to `172.20.100.202`. External players would also need those forwarded on the router (not set up).

`mc.earles.io` uses split DNS: internally it resolves to `172.20.100.202`.

### Gotchas baked into docker-compose.yml

- **Healthcheck:** the image's default is a RakNet ping, which NetherNet never answers, so it's replaced with a TCP check on 19133.
- **TIME_WAIT bind failure:** if BDS restarts within ~60s of having had connections, it **silently fails to bind** 19133. It logs no `Accepting clients on [::]:19133` and nobody can join. The entrypoint wrapper sleeps until the newest world file is ≥65s old. This is why restarts take ~1 extra minute.
- **Server identity key:** stored at `data/keys/server_identity_key.pem` (saved with the console command `serveridentity save`). Without it BDS generates a new identity each start.

## Setup from scratch

1. `./update.sh` downloads the MCXboxBroadcast JAR and starts everything. Or download the JAR manually and run `docker compose up -d`.
2. **Authenticate the broadcast account.** On first start, run `docker logs mcxboxbroadcast` to find a `microsoft.com/link` code. Sign in as the dedicated broadcast account (`mcearlesio`).
3. **Deploy the Traefik side** (`../traefik`): the entrypoint, the port, and `external-minecraft.yaml`. Then recreate Traefik. Getting the first cert for `mc.earles.io` takes ~70s (DNS propagation delay).
4. **Save the server identity key:** `docker compose exec -T minecraft send-command "serveridentity save"`.
5. Check with `python3 ping.py`. Both targets should report `OK`.

## MCXboxBroadcast notes

- **Mount the whole `./config` dir** as the working dir (`/opt/app`). Newer builds rewrite `config.yml` on startup (config migration) using an atomic temp-file rename, which fails with `Device or resource busy` on a single-file bind mount. The container then crash-loops.
- The jar is mounted outside the working dir (`/opt/MCXboxBroadcastStandalone.jar`).
- If the config isn't actually read, the jar silently uses defaults, including `ip: test.geysermc.org`.
- Key settings in `config/config.yml`:

| Option | Value | Notes |
|---|---|---|
| `session.session-info.ip` | `mc.earles.io` | Address joining friends are transferred to. Must be the hostname (trusted cert) or an IP (plain-HTTP fallback). |
| `friend-sync.auto-friend` | `true` | Auto-accepts friend requests to `mcearlesio`. (Replaced `auto-follow` in config-version 5.) |
| `friend-sync.expiry` | enabled, 15 days | Unfriends players who haven't joined in 15 days. They can re-add. |
| `query-server` | `true` | Its ping is RakNet, so it logs `Failed to ping server, falling back to config values` every ~30s. Harmless. |

## Skyblock world

The Skyblock world is a FLAT world whose `FlatWorldLayers` in `level.dat` is a single `minecraft:air` layer, i.e. a true void with no bedrock floor. The island is built from the server console:

- **Main island:** an L shape (6×6, 3 deep) with grass on dirt and one bedrock block inside, an oak tree, and a starter chest. The chest holds a lava bucket, 2 ice, 12 string, a bone, a melon slice, a cactus, red and brown mushrooms, pumpkin seeds and sugar cane.
- **Sand island:** at `-60 64 0`, with a cactus.
- **Settings:** spawn at `1 65 1` with spawn radius 0, coordinates shown, keep inventory on.

```bash
./reset-skyblock.sh            # full reset: back up to backups/, new world, rebuild (~2 min)
./reset-skyblock.sh --live     # rebuild islands in place while playing (~25s, keeps inventories)
./reset-skyblock.sh -y ...     # skip the confirmation prompt
```

`tools/leveldat.py` is what makes the full reset possible. It edits `level.dat` (a root-owned file, so the script runs it in a throwaway `python:3.12-alpine` container).

## World rotation

| Mode | World | Type | Game mode |
|---|---|---|---|
| `skyblock` | `Skyblock` | void FLAT | survival |
| `survival` | `Earles2026` | normal | survival |
| `creative` | `Creative` | normal | creative |

```bash
./switch-world.sh               # show active mode
./switch-world.sh creative      # switch (~80s; players are warned, then disconnected)
```

`docker-compose.yml` reads `LEVEL_NAME`, `LEVEL_TYPE` and `GAMEMODE` from `.env` (`MC_LEVEL_NAME`, `MC_LEVEL_TYPE`, `MC_GAMEMODE`). Without a `.env` it defaults to Skyblock. `switch-world.sh`:
- rewrites `.env` and recreates the container
- enables coordinates
- updates the world name and game mode the Xbox broadcast advertises

Worlds are never reset by switching. `FORCE_GAMEMODE=true` keeps players in each world's game mode. Older worlds (`PaleGarden`, `DroneWorld`) remain in `data/worlds/`.

## Backups

A cron job runs `backup-worlds.sh` nightly at 10:00 UTC (3-4am Denver):

```
0 10 * * * /home/aearles/mc-bedrock/backup-worlds.sh >> /home/aearles/mc-bedrock/backups/nightly/backup.log 2>&1
```

It archives all of `data/worlds/` to `backups/nightly/worlds-<timestamp>.tar.gz` (~80 MB) and prunes archives older than 14 days. The active world is captured consistently while the server runs: BDS `save hold`, then `save query` (file list with exact lengths; files are copied and truncated to them), then `save resume`. The world is paused for ~3s. Run it by hand any time with `./backup-worlds.sh`.

## Updating

```bash
./update.sh
```

This removes the old JAR, downloads the latest MCXboxBroadcast release, pulls the latest `itzg/minecraft-bedrock-server`, and recreates the containers. Expect the ~65s TIME_WAIT wait on the Minecraft start.

## Checking status

```bash
python3 ping.py                       # handshake via Traefik: hostname (verified TLS) + IP (HTTP fallback)
python3 ping.py 172.20.100.202:19133  # BDS directly
docker compose ps                     # minecraft should be (healthy)
```
