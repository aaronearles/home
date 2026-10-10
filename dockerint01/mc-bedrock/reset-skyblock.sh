#!/usr/bin/env bash
# Resets the Skyblock world to a fresh classic island.
# Usage: ./reset-skyblock.sh [-y]          full reset: new world, backs up the old one first
#        ./reset-skyblock.sh --live [-y]   rebuild the islands in place while the server runs
#                                          (players keep inventories; nothing else is reset)
#   -y skips the confirmation prompt
#
# Full reset (world files are root-owned, so file work runs in a throwaway container):
#   1. Warn players, back up worlds/<LEVEL_NAME> to backups/, stop the server, delete the world
#   2. Start the server so it generates a new FLAT world, then stop it
#   3. Edit level.dat: a single air layer (true void), coordinates on, no bonus chest/map,
#      spawn radius 0; delete the generated chunks
#   4. Start the server and build the island from the console (works with cheats off)
# Live reset: park everyone in a glass box above the void, clear the area around both
#   islands (incl. dropped items), rebuild, and teleport everyone back to spawn.
set -euo pipefail
cd "$(dirname "$0")"

# Effective settings (compose interpolates them from .env, which switch-world.sh manages)
compose_env() { docker compose config minecraft | sed -n "s/^ *$1: *\"\{0,1\}\([^\"]*\)\"\{0,1\}$/\1/p" | head -1; }
WORLD=$(compose_env LEVEL_NAME)
[[ "$WORLD" == "Skyblock" ]] || { echo "LEVEL_NAME is '$WORLD', not Skyblock - refusing to reset." >&2; exit 1; }
[[ "$(compose_env LEVEL_TYPE)" == "FLAT" ]] || { echo "LEVEL_TYPE is not FLAT - is Skyblock the active world? (./switch-world.sh skyblock)" >&2; exit 1; }

LIVE=0; YES=0
for a in "$@"; do
    case "$a" in
        --live) LIVE=1 ;;
        -y) YES=1 ;;
        *) echo "Unknown option: $a" >&2; exit 1 ;;
    esac
done

if [[ $YES -eq 0 ]]; then
    if [[ $LIVE -eq 1 ]]; then
        prompt="Rebuild the islands in '$WORLD' live? Everything built near them is erased. [y/N] "
    else
        prompt="Reset world '$WORLD'? Current world will be backed up to backups/. [y/N] "
    fi
    read -rp "$prompt" ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }
fi

PY=python:3.12-alpine
MC="docker compose exec -T minecraft send-command"

mc() { $MC "$1" </dev/null >/dev/null; }

# Wait for a "Server started" log line newer than $1 (BDS may first wait ~65s for TIME_WAIT)
wait_started() {
    echo "  waiting for server to start..."
    timeout 300 bash -c "until docker compose logs --since '$1' minecraft 2>/dev/null | grep -q 'Server started'; do sleep 3; done" \
        || { echo "Server did not start - check: docker compose logs minecraft" >&2; exit 1; }
}

start_server() {
    local since; since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    docker compose up -d minecraft >/dev/null 2>&1
    wait_started "$since"
}

build_island() {
    echo "Building island..."
    mc "tickingarea add -70 0 -10 10 100 10 skyblock_build"
    sleep 6
    while IFS= read -r cmd; do
        [[ -z "$cmd" || "$cmd" == \#* ]] && continue
        mc "$cmd"
        sleep 0.3
    done <<'EOF'
# Main L-shaped island: 3 deep, grass on dirt, one bedrock block inside
fill 0 62 0 5 63 2 dirt
fill 0 62 3 2 63 5 dirt
fill 0 64 0 5 64 2 grass_block
fill 0 64 3 2 64 5 grass_block
setblock 1 62 1 bedrock
# Oak tree: leaves first, then the trunk through them
fill 0 67 3 4 68 7 oak_leaves
fill 0 67 3 0 68 3 air
fill 4 67 3 4 68 3 air
fill 0 67 7 0 68 7 air
fill 4 67 7 4 68 7 air
fill 1 69 4 3 69 6 oak_leaves
fill 2 70 4 2 70 6 oak_leaves
fill 1 70 5 3 70 5 oak_leaves
fill 2 65 5 2 69 5 oak_log
# Starter chest
setblock 4 65 1 chest
replaceitem block 4 65 1 slot.container 0 lava_bucket 1
replaceitem block 4 65 1 slot.container 1 ice 2
replaceitem block 4 65 1 slot.container 2 string 12
replaceitem block 4 65 1 slot.container 3 bone 1
replaceitem block 4 65 1 slot.container 4 melon_slice 1
replaceitem block 4 65 1 slot.container 5 cactus 1
replaceitem block 4 65 1 slot.container 6 red_mushroom 1
replaceitem block 4 65 1 slot.container 7 brown_mushroom 1
replaceitem block 4 65 1 slot.container 8 pumpkin_seeds 1
replaceitem block 4 65 1 slot.container 9 sugar_cane 1
# Sand island to the west (sandstone base so the sand doesn't fall)
fill -62 62 -1 -58 62 1 sandstone
fill -62 63 -1 -58 64 1 sand
setblock -60 65 0 cactus
# Spawn on the island
setworldspawn 1 65 1
gamerule spawnradius 0
# Keep inventory on death
gamerule keepinventory true
EOF

    # Verify a few key blocks before releasing the ticking area
    since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    for t in "1 64 1 grass_block" "4 65 1 chest" "2 69 5 oak_log" "-60 65 0 cactus"; do
        mc "testforblock $t"
    done
    sleep 2
    found=$(docker compose logs --since "$since" minecraft | grep -c 'Successfully found the block' || true)
    mc "tickingarea remove skyblock_build"

    if [[ "$found" -eq 4 ]]; then
        echo "Done! Fresh Skyblock is ready.${BACKUP:+ Old world: $BACKUP}"
    else
        echo "Island built but only $found/4 checks passed - check: docker compose logs minecraft" >&2
        exit 1
    fi
}

running() { docker compose ps --status running --services | grep -qx minecraft; }

if [[ $LIVE -eq 1 ]]; then
    running || { echo "Server isn't running - start it first (or use a full reset)." >&2; exit 1; }
    echo "Parking players in a holding box..."
    mc "say Rebuilding the islands - hold tight!"
    mc "tickingarea add -70 0 -16 20 100 20 skyblock_clear"
    mc "fill -2 119 -42 2 123 -38 glass hollow"
    mc "execute in overworld run tp @a 0 120 -40"
    sleep 2
    echo "Clearing the area around the islands..."
    # /fill is capped at 32768 blocks, so clear the main island area in slabs
    for y in 40 58 76 94; do
        mc "fill -16 $y -16 20 $((y+17)) 20 air"
    done
    mc "fill -70 50 -10 -50 80 10 air"
    mc "kill @e[type=item]"
    build_island
    mc "execute in overworld run tp @a 1 65 1"
    mc "fill -2 119 -42 2 123 -38 air"
    mc "tickingarea remove skyblock_clear"
    mc "say Islands rebuilt - good luck!"
    exit 0
fi

if docker compose ps --status running --services | grep -qx minecraft; then
    echo "Warning players..."
    mc "say Skyblock is resetting in 10 seconds!" || true
    sleep 10
fi

echo "Stopping server..."
docker compose stop minecraft >/dev/null 2>&1

mkdir -p backups
BACKUP="backups/${WORLD}-$(date +%Y%m%d-%H%M%S).tar.gz"
if [[ -d "data/worlds/$WORLD" ]]; then
    echo "Backing up to $BACKUP..."
    tar -czf "$BACKUP" -C data/worlds "$WORLD"
    docker run --rm -v "$PWD/data/worlds:/w" $PY rm -rf "/w/$WORLD"
fi

echo "Generating new world..."
start_server
docker compose stop minecraft >/dev/null 2>&1

echo "Making it a void world..."
LAYERS='{"biome_id":1,"block_layers":[{"block_name":"minecraft:air","count":1}],"encoding_version":6,"preset_id":null,"structure_options":null,"world_version":"version.post_1_18"}'
docker run --rm -v "$PWD/data/worlds/$WORLD:/w" -v "$PWD/tools/leveldat.py:/leveldat.py:ro" $PY sh -c "
    python3 -I /leveldat.py /w/level.dat 'FlatWorldLayers:s=$LAYERS' \
        bonusChestEnabled=0 startWithMapEnabled=0 showcoordinates=1 \
        spawnradius:i=0 SpawnX:i=1 SpawnY:i=65 SpawnZ:i=1 >/dev/null &&
    rm -rf /w/db /w/level.dat_old"

echo "Starting server..."
start_server

build_island
