# Minecraft Server Admin Runbook

Operating guide for the family Minecraft Bedrock server. It's written so an AI agent (e.g. Claude Haiku in Claude Code) can act as server admin. Each task gives the exact commands, how to check that it worked, and what to watch out for.

## Quick facts

| Thing | Value |
|---|---|
| Host | `dockerint01`, LAN IP `172.20.100.202` (LXC on Proxmox) |
| Deployed stack | `~/mc-bedrock` (run all commands from here) |
| Repo copy | `~/code/home/dockerint01/mc-bedrock` (git; keep in sync with the deployed stack) |
| Traefik stack | `~/traefik-internal` (repo copy: `~/code/home/dockerint01/traefik`) |
| Containers | `minecraft_itzg` (service `minecraft`), `mcxboxbroadcast`, `traefik` |
| Server address | `mc.earles.io` (port 19132), or `172.20.100.202` |
| Xbox broadcast account | `mcearlesio`: players friend it and join from the Friends tab |
| Current world | `Skyblock` (`LEVEL_NAME` in `docker-compose.yml`) |
| Game settings | Survival, easy, **cheats ON**, keep inventory ON, coordinates shown, **no operators** |
| Bedrock version | 1.26.52 (NetherNet transport) |

### Players

| Gamertag | XUID | Who |
|---|---|---|
| `aearles` | 2533275026015377 | Dad / owner |
| `hcearles` | 2535421067961767 | kid |
| `ttearles` | 2535407829863530 | kid |
| `hairlesspete846` | 2535456288371262 | friend |

## Golden rules

1. **Run from `~/mc-bedrock`.** All `docker compose` commands assume this directory.
2. **Ask the owner before anything destructive or hard to undo:**
   - full world reset or deleting worlds
   - switching worlds
   - restarting or updating the server while people are playing
   - editing Traefik's static config or restarting Traefik (it fronts ~30 other services)
   - giving anyone operator status
   - toggling cheats (enabling cheats permanently disables achievements for that world)

   Live resets, giving items, time and weather are routine. Do them when asked.
3. **Never delete a world without a backup.** `reset-skyblock.sh` backs up automatically, and `.claude/settings.json` blocks `rm -rf worlds*`.
4. **Warn players before a restart:** `say` a message and wait ~10s.
5. **Always check the result.** Console commands don't print to your terminal; read the server log (see below).
6. Don't run `docker compose down` casually. Use `restart` or `up -d`.

## Running console commands (the core skill)

```bash
docker compose exec -T minecraft send-command "<command>" </dev/null
sleep 1
docker compose logs --since 5s minecraft | grep -E 'INFO|ERROR' | tail
```

- **Output goes to the server log**, not stdout. Always read it back with `logs --since`.
- **Always add `</dev/null`** (and `-T`). Inside a `while read` loop, `docker compose exec` otherwise swallows the rest of the loop's input, so only the first command runs.
- The console **doesn't need cheats or operator status.** It can run `give`, `fill`, `tp`, `gamerule` and so on even when cheats are off. Console commands don't disable achievements; only the cheats setting does.
- Quote the whole command as one argument. Selectors work: `@a` (all players), `@p`, or a gamertag.
- **Blocks only load near players.** `fill`/`setblock`/`testforblock` fail with `Cannot place blocks outside of the world` / `Cannot test for block outside of the world` when no player is nearby. Load the area first:
  ```bash
  ...send-command "tickingarea add -70 0 -10 10 100 10 work_area"   # wait ~5s before building
  ...send-command "tickingarea remove work_area"                    # when done
  ```
- `fill` is capped at 32768 blocks per command; split big areas into slabs.
- `fill` reports `0 blocks filled` as an ERROR when nothing changed. That's harmless.

A handy alias for an interactive shell:
```bash
alias mc='docker compose -f ~/mc-bedrock/docker-compose.yml exec -T minecraft send-command'
```

## Routine tasks

### Who's online / where are they
```bash
...send-command "list"
...send-command "querytarget aearles"     # JSON with position {"x":..,"y":..,"z":..} and dimension
```
`spawn-chest.sh` shows how to parse a player's position from `querytarget`.

### Give items
```bash
...send-command "give aearles obsidian 64"
...send-command "give @a diamond_pickaxe"
```
- Item IDs are lowercase with underscores (`flint_and_steel`, `lava_bucket`, `oak_log`, `cobblestone`, `torch`).
- Max stack is usually 64. Tools and armor stack to 1.
- If the inventory is full, items drop on the ground.
- Log line on success: `Gave Obsidian * 64 to aearles`. `No targets matched selector` means the player isn't online.

### Equip armor directly (worn, not in inventory)
```bash
for slot in "head diamond_helmet" "chest diamond_chestplate" "legs diamond_leggings" "feet diamond_boots"; do
  set -- $slot
  docker compose exec -T minecraft send-command "replaceitem entity @a slot.armor.$1 0 $2" </dev/null
done
```
Full diamond tool set: `diamond_sword diamond_pickaxe diamond_axe diamond_shovel diamond_hoe` (use `give`).
This **replaces** whatever armor they were wearing; the old armor isn't returned.

### Teleport
```bash
...send-command "tp hcearles aearles"                       # player to player
...send-command "execute in overworld run tp @a 1 65 1"     # everyone to Skyblock spawn (from any dimension)
```

### Time, weather, game rules
```bash
...send-command "time set day"        # or noon / night / midnight
...send-command "weather clear"       # or rain / thunder
...send-command "gamerule keepinventory true"
...send-command "gamerule dodaylightcycle false"   # freeze time ("pause" the day)
...send-command "gamerule domobspawning false"
```
Game rules live in the world, so they survive restarts. A full Skyblock reset re-applies `spawnradius 0` and `keepinventory true`. Other game rules go back to their defaults.

### Chat message to players
```bash
...send-command "say Dinner in 10 minutes!"
```

### Build helpers (run with a player name or @p)
`./build-house.sh <player> [wall] [floor]`, `./build-smiley.sh <player>`, `./build-smiley-xl.sh <player>`, `./build-sonic.sh <player> [scale]`, `./spawn-chest.sh <player>` (a chest of netherite gear next to them), `./cycle-time.sh <secs>` / `./cycle-days.sh <secs>` (time-lapse; Ctrl+C to stop).

## Skyblock resets

| Want | Command | Effect |
|---|---|---|
| Kids wrecked the island, keep playing | `./reset-skyblock.sh --live -y` | ~25s, no restart. Parks everyone in a glass box at y=120, clears the area around both islands (x -16..20, y 40..111, z -16..20, plus the sand island area) and dropped items, rebuilds, teleports everyone to `1 65 1`. **Inventories, XP and the Nether are kept.** |
| Completely fresh start | `./reset-skyblock.sh -y` (ask the owner first) | ~2 min, restarts the server. Backs up to `backups/Skyblock-<timestamp>.tar.gz`, creates a brand-new world (new seed, empty inventories), rebuilds the island. |

- Both modes finish with 4 block checks and print `Done! Fresh Skyblock is ready.` If you see `only N/4 checks passed`, check the log.
- The script refuses to run unless `LEVEL_NAME=Skyblock` and `LEVEL_TYPE=FLAT`.
- Players who were **offline** during a live reset reappear where they logged out. If that spot was cleared, they fall into the void (keep inventory saves their items).
- The island layout and chest contents are the heredoc in `build_island()` in the script.
- **Restoring a backup** (ask first): `docker compose stop minecraft && mv data/worlds/Skyblock data/worlds/Skyblock.old-$(date +%s) && tar -xzf backups/<file> -C data/worlds && docker compose start minecraft`. `data/worlds/` is owned by aearles, so no container is needed for this.

### Cobblestone generator (players ask about this a lot)
Water touching the lava **source** block makes obsidian, and that lava is lost. Water touching **flowing** lava makes cobblestone.

Classic layout:
1. Dig a 1-deep trench 4 long: `[Lava][ ][ ][Water]`.
2. Dig one extra block down under the 3rd spot.
3. Place the water first, then the lava.

Cobblestone forms in spot 2. If they get obsidian, a live reset gives them a fresh lava bucket.

## Server lifecycle

### Restart
```bash
docker compose exec -T minecraft send-command "say Server restarting in 10 seconds" </dev/null; sleep 10
docker compose restart minecraft
```
- **Expect `Quick restart: waiting ~65s for port 19133 TIME_WAIT to clear...`.** That's intentional (see Troubleshooting). Total ~80s.
- Started when the log shows `Accepting clients on [::]:19133` **and then** `Server started.`
- Careful when waiting with `logs --since 2m`: it can match the *previous* boot's `Server started`. Record a timestamp before restarting (`since=$(date -u +%Y-%m-%dT%H:%M:%SZ)`) and use `--since "$since"`.

### Apply docker-compose.yml changes
`docker compose up -d minecraft` recreates the container if its config changed. Same restart caveats.

### Update to the latest Bedrock and broadcaster
`./update.sh` (ask first if people are playing). Afterwards, run the health checklist.

### Switch worlds (ask the owner first)
Edit `docker-compose.yml`:
1. Set `LEVEL_NAME=<World>`.
2. For non-Skyblock worlds, **comment out `LEVEL_TYPE=FLAT`.**
3. Run `docker compose up -d minecraft`.

Worlds live in `data/worlds/` (`Skyblock`, `Earles2026`, `PaleGarden`, `DroneWorld`, ...). A new `LEVEL_NAME` generates a new world.

## Permissions, cheats and game modes

- **Operators:** none right now. Two places control this:
  - `OPS=` in `docker-compose.yml` (commented out)
  - `data/permissions.json` (currently `[]`)

  Commenting out `OPS` **does not** clear `permissions.json`. The image only rewrites that file when `OPS` is set.
  - Make someone an operator (ask first; they can then switch to creative): `...send-command "op aearles"`, or add them to `OPS` and recreate.
  - Remove: `...send-command "deop aearles"`. Also check `permissions.json`.
  - Old worlds (e.g. `Earles2026`) may still remember `aearles` as an operator from earlier play. Run `deop aearles` after switching to one.
- **Cheats:** `ALLOW_CHEATS=true` in compose, which shows as `commandsEnabled = 1` in `level.dat`. Turning cheats on for a world **permanently disables achievements** for it. Changing it needs a restart.
- **Game mode:** without operator status, players can't change their own game mode. The console can: `...send-command "gamemode survival hcearles"`.

## Health checklist (run this when "I can't join")

```bash
cd ~/mc-bedrock
docker compose ps                     # minecraft "(healthy)", mcxboxbroadcast "Up"
python3 ping.py                       # both targets OK (exit 0)
docker compose logs --since 10m minecraft | grep -E 'Accepting|Server started|Player (connected|disconnected)'
docker compose logs --since 10m mcxboxbroadcast | sed 's/\x1b\[[0-9;]*m//g' | grep -E 'INFO|WARN' | tail
```

Read the results:
- **`ping.py` fails for both targets** → BDS isn't serving. Check for `Accepting clients on [::]:19133` in the latest boot.
  - If it's missing, it's the **TIME_WAIT bind failure**. Wait 70s and `docker compose restart minecraft`. The wrapper normally prevents this.
- **`ping.py 172.20.100.202:19133` OK, but port 19132 fails** → Traefik problem.
  - `docker ps --filter name=^traefik$`
  - `curl -s http://127.0.0.1:8080/api/tcp/routers` should list `minecraft-tls@file`, `minecraft-tls-ip@file` and `minecraft-plain@file`, all `enabled`.
  - `tail ~/traefik-internal/logs/traefik.log`
- **Hostname fails with a certificate error, IP OK** → the Let's Encrypt cert for `mc.earles.io` is missing or expired. Traefik renews it automatically; look for ACME errors in `traefik.log`.
  - A stuck `identical record already exists` error clears if you re-save `~/traefik-internal/config/conf/external-minecraft.yaml` (Traefik reloads it and retries).
- **Friends tab join fails but `ping.py` OK** →
  - Was the server restarting at that moment? The broadcaster log shows `Transferred bedrock client X to target server.` with a time; compare it with the server log.
  - Check `ip:` in `config/config.yml`. It must be `mc.earles.io` (trusted cert) or the IP. Restart `mcxboxbroadcast` after editing.
- **Friend request to `mcearlesio` stays pending** → `friend-sync.auto-friend: true` in `config/config.yml`, then `docker compose restart mcxboxbroadcast`. The log should show `Added <gamertag> ... as a friend`.
- **Not in the LAN list** → expected for devices on another subnet (e.g. 172.20.10.x): LAN discovery is a broadcast. Use the Friends tab or a server entry.
- **`mcxboxbroadcast` crash-looping with `Device or resource busy`** → `config.yml` is mounted as a single file. It must be the whole `./config` directory (see README).
- **Harmless noise:**
  - `Failed to ping server, falling back to config values` (broadcaster, every 30s)
  - `TRANSPORT TYPE ERROR` should no longer appear
  - `0 blocks filled`

### Seeing what a device is actually doing (advanced)
Packet capture without sudo, using a throwaway container on the host network:
```bash
docker run --rm --net host --cap-add NET_RAW --cap-add NET_ADMIN python:3.12-alpine sh -c \
  'apk add -q tcpdump >/dev/null && timeout 300 tcpdump -i any -nn -l -A "host <device-ip> and (tcp port 19132 or udp portrange 19140-19159)"'
```
Run it in the background, have the player retry, then read it. What normal traffic looks like:
- a TLS ClientHello on 19132 (SNI `mc.earles.io` when joining by hostname)
- HTTP `GET /v1/join` then `POST /v1/join/<id>`
- UDP on 19140-19159

If `docker run` gets interrupted, remove leftover capture containers: `docker ps -q --filter ancestor=python:3.12-alpine | xargs -r docker rm -f`.

## Editing world settings (level.dat)

Some settings only live in `level.dat`: bonus chest, starter map, flat-world layers, spawn. World files are root-owned, so run the editor in a container **with the server stopped** (BDS rewrites `level.dat` on shutdown):

```bash
docker compose stop minecraft
docker run --rm -v "$PWD/data/worlds/Skyblock:/w" -v "$PWD/tools/leveldat.py:/leveldat.py:ro" python:3.12-alpine \
  python3 -I /leveldat.py /w/level.dat showcoordinates=1 spawnradius:i=0
docker compose start minecraft
```
- `key=1` sets a byte (true/false), `key:i=N` an int, `key:s=text` a string. With no edits it prints all values; reading also works from the host without a container.
- Bonus chest and starter map only take effect when terrain is (re)generated. That's why the full reset deletes `db/` after editing.

## Files reference

| Path | What |
|---|---|
| `docker-compose.yml` | Server settings (env vars → `server.properties`), networking, healthcheck, TIME_WAIT wrapper |
| `config/config.yml` | MCXboxBroadcast settings (`ip`, `auto-friend`, expiry) |
| `data/server.properties` | Generated from compose env on every start. Edit compose, not this. |
| `data/permissions.json` | Operator list (`[]` = none) |
| `data/keys/server_identity_key.pem` | Server identity (keep it; regenerating forces players to re-trust) |
| `data/worlds/<name>/` | Worlds (root-owned) |
| `backups/` | Tarballs from `reset-skyblock.sh` |
| `~/traefik-internal/config/conf/external-minecraft.yaml` | TCP routers 19132 → 172.20.100.202:19133 |
| `*.bak-YYYYMMDD` | Hand-made backups of edited files |
