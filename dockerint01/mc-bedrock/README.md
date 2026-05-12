# mc-bedrock

Minecraft Bedrock Dedicated Server with Xbox Live broadcasting via MCXboxBroadcast, allowing Xbox and mobile players to join through the friends list without requiring manual server entry.

## Services

| Service | Image | Purpose |
|---|---|---|
| `minecraft` | `itzg/minecraft-bedrock-server` | Bedrock dedicated server |
| `mcxboxbroadcast` | `eclipse-temurin:21-jre-jammy` | Broadcasts server as Xbox Live session so friends can join via the in-game Social menu |

## Directory structure

```
mc-bedrock/
├── docker-compose.yml
├── update.sh                   # Updates JAR, pulls images, recreates containers
├── commands.txt                # Useful in-game admin commands
├── MCXboxBroadcastStandalone.jar  # Downloaded by update.sh (not in git)
├── config/
│   └── config.yml              # MCXboxBroadcast configuration
└── data/                       # Minecraft server data (not in git)
```

## Setup

### 1. Download the MCXboxBroadcast JAR

```bash
wget https://github.com/MCXboxBroadcast/Broadcaster/releases/latest/download/MCXboxBroadcastStandalone.jar
```

Or run `update.sh` which handles this plus pulling images.

### 2. Configure `config/config.yml`

Set the server IP, world name, and host name. The critical fields:

```yaml
session:
  session-info:
    ip: mc.earles.io        # hostname or IP the client connects to after transfer
    host-name: EARLES
    world-name: PaleGarden
```

See [MCXboxBroadcast config reference](#mcxboxbroadcast-config-notes) below.

### 3. Start the stack

```bash
docker compose up -d
```

### 4. Authenticate the MCXboxBroadcast Xbox account

On first start (or after the auth token expires), the container logs an auth code:

```
[Auth] To sign in, use a web browser to open the page https://www.microsoft.com/link and enter the code XXXXXXXX
```

Run `docker logs mcxboxbroadcast` to get the code, then authenticate using a Microsoft account dedicated to broadcasting (e.g. `mcearlesio`). Players must follow this account on Xbox to see the server in their friends list.

### 5. Add the Cobblemon Bedrock addon (optional)

```bash
# Download and extract the addon
curl -L -o cobblemon-bedrock.mcaddon "https://github.com/kirbycope/cobblemon-bedrock/raw/main/cobblemon-bedrock.mcaddon"
mkdir -p cobblemon_extract && unzip cobblemon-bedrock.mcaddon -d cobblemon_extract/

# Copy packs into the server (requires sudo for root-owned data dir)
docker cp "cobblemon_extract/cobblemon behavior/cobblemon" minecraft_itzg:/data/behavior_packs/cobblemon
docker cp "cobblemon_extract/cobblemon resources/cobblemon" minecraft_itzg:/data/resource_packs/cobblemon

# Enable for your world (replace PaleGarden with your LEVEL_NAME)
docker exec minecraft_itzg bash -c 'cat > /data/worlds/PaleGarden/world_behavior_packs.json << EOF
[{"pack_id": "891b54b5-04fa-e63d-22be-a1ccbc41fc5d", "version": [1, 0, 0]}]
EOF'
docker exec minecraft_itzg bash -c 'cat > /data/worlds/PaleGarden/world_resource_packs.json << EOF
[{"pack_id": "e43f561a-90a4-6b16-f237-a666de2d4174", "version": [1, 0, 0]}]
EOF'

docker compose restart minecraft
rm -rf cobblemon_extract cobblemon-bedrock.mcaddon
```

## Updating

```bash
./update.sh
```

This removes the old JAR, downloads the latest MCXboxBroadcast release, pulls the latest `itzg/minecraft-bedrock-server` image, and recreates all containers.

## Useful commands

Run commands against the Minecraft server:

```bash
docker compose exec minecraft send-command <command>

# or with the alias from commands.txt:
alias mc="docker compose -f ~/mc-bedrock/docker-compose.yml exec minecraft send-command"
mc give @a torch 64
mc time set noon
mc weather clear
```

See `commands.txt` for more examples.

## MCXboxBroadcast config notes

### Critical volume mount

The MCXboxBroadcast jar reads `config.yml` from its **working directory** (`/opt/app/config.yml`). The docker-compose must mount the file directly — **not** a parent directory:

```yaml
# CORRECT — mounts the file where the jar reads it
volumes:
  - ./config/config.yml:/opt/app/config.yml
  - ./config/cache:/opt/app/cache
  - ./config/logs:/opt/app/logs

# WRONG — jar never reads from this subdirectory path
volumes:
  - ./config:/opt/app/config   # ← jar reads /opt/app/config.yml, not /opt/app/config/config.yml
```

If the file isn't mounted correctly, the jar silently runs with hardcoded defaults including `ip: test.geysermc.org`, causing all Social/friends joins to land on GeyserMC's demo server.

### Key config options

| Option | Default | Notes |
|---|---|---|
| `query-server` | `true` | Pings the server to sync player count / world name. May time out inside Docker due to hairpin NAT. |
| `web-query-fallback` | `false` | When enabled, uses `checker.geysermc.org` as a fallback ping. Leave disabled — the checker resolves your hostname using your public IP, which can return stale data. |
| `config-fallback` | `true` | When `query-server` ping fails, use static values from config. Requires `query-server: true` to have effect. |
| `auto-follow` | `false` | Automatically follows back anyone who follows the broadcast account. Keep disabled to avoid cross-pollinating your friends list with GeyserMC bot accounts. |

### Split DNS

`mc.earles.io` uses split DNS:
- **Internal (LAN):** resolves to `172.20.100.202` (host LAN IP)
- **External:** resolves to `65.130.147.150` (public IP)

Clients (Xbox, iOS) on the LAN use the internal address. The `ip` in the MCXboxBroadcast config is the address sent in the transfer packet to connecting clients.

## Networking

- Minecraft Bedrock listens on `19132/tcp` and `19132/udp`
- MCXboxBroadcast has no published ports — it connects outbound to Xbox Live via NetherNet (Xbox P2P relay)
- Both containers are on the `backend` Docker network so MCXboxBroadcast can query the Minecraft server for player counts
