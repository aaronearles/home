#!/usr/bin/env bash
# Builds a 9x9 starter house centred on a player (they end up standing inside it), or at
# fixed coordinates.
# Usage: ./build-house.sh <player>       [wall_block] [floor_block] [--extras-only]
#        ./build-house.sh --at <x> <y> <z> [wall_block] [floor_block] [--extras-only]
#   e.g. ./build-house.sh aearles oak_planks spruce_planks
#        ./build-house.sh --at 2257 70 401 --extras-only      (add door + bed to an existing house)
# <y> is the player's feet level inside the house (floor is one below).
# Layout: 9x9 footprint, 6 tall, flat roof. Everything inside the shell is cleared (it digs
# into hillsides). Wooden door in the south (+z) wall, glass windows on the other three.
# Furnished: bed (east wall), crafting table, furnace, chest, a lantern in each corner.
# Prints the house centre so it can be found again. Commands ignore Land Claims.
#
# Block-state notes (BDS 1.26.5x): the oak door block is `wooden_door` (oak_door is the
# item); setting its lower half adds the upper half. Setting a bed's head half adds the
# foot one block north (-z) of it.

MCX="docker compose -f $HOME/mc-bedrock/docker-compose.yml exec -T minecraft send-command"

if [[ "${1:-}" == "--at" ]]; then
    X="${2:?--at needs x y z}"; Y="${3:?}"; Z="${4:?}"; shift 4
    AT="execute positioned $X $Y $Z run"
    WHERE="($X, $Y, $Z)"
else
    PLAYER="${1:?Usage: $0 <player> | --at <x> <y> <z>  [wall_block] [floor_block] [--extras-only]}"; shift
    AT="execute at $PLAYER run"
    # Record where the house goes (the player's position, floored)
    since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    $MCX "querytarget $PLAYER" </dev/null >/dev/null; sleep 1
    pos=$(docker compose -f "$HOME/mc-bedrock/docker-compose.yml" logs --no-log-prefix --since "$since" minecraft \
        | python3 -I -c "import sys,re,math; m=re.search(r'\"x\" : ([-\d.]+),\s*\"y\" : ([-\d.]+),\s*\"z\" : ([-\d.]+)', sys.stdin.read()); print(' '.join(str(math.floor(float(v))) for v in m.groups()) if m else '')")
    [[ -n "$pos" ]] || { echo "Player '$PLAYER' isn't online." >&2; exit 1; }
    WHERE="($pos)"
fi
EXTRAS_ONLY=0
args=()
for a in "$@"; do [[ "$a" == "--extras-only" ]] && EXTRAS_ONLY=1 || args+=("$a"); done
WALL="${args[0]:-oak_planks}"
FLOOR="${args[1]:-$WALL}"

run() { $MCX $AT "$@" </dev/null >/dev/null; }

if [[ $EXTRAS_ONLY -eq 0 ]]; then
    # Outer shell: 9x9 footprint, 6 blocks tall, floor one below feet
    run fill '~-4' '~-1' '~-4' '~4' '~4' '~4' "$WALL" '[]' hollow
    [[ "$FLOOR" != "$WALL" ]] && run fill '~-4' '~-1' '~-4' '~4' '~-1' '~4' "$FLOOR"
    # Windows on the west, east and north walls
    run fill '~-4' '~1' '~-1' '~-4' '~2' '~1' glass '[]' replace "$WALL"
    run fill '~4'  '~1' '~-1' '~4'  '~2' '~1' glass '[]' replace "$WALL"
    run fill '~-1' '~1' '~-4' '~1'  '~2' '~-4' glass '[]' replace "$WALL"
    # Furnishings along the north wall, lanterns in the corners
    run setblock '~-2' '~0' '~-3' crafting_table
    run setblock '~-1' '~0' '~-3' furnace
    run setblock '~2'  '~0' '~-3' chest
    for c in "~-3 ~-3" "~3 ~-3" "~-3 ~3" "~3 ~3"; do
        set -- $c
        run setblock "$1" '~0' "$2" lantern
    done
fi

# Door: older houses had a 2x2 gap at x -1..0 - wall up the west half, door in the east half
run fill '~-1' '~0' '~4' '~-1' '~1' '~4' "$WALL"
run fill '~0' '~0' '~4' '~0' '~1' '~4' air
run setblock '~0' '~0' '~4' wooden_door '["direction"=3,"upper_block_bit"=false]'
# Bed along the east wall: head at z=+1, foot appears at z=0
run fill '~3' '~0' '~0' '~3' '~0' '~1' air
run setblock '~3' '~0' '~1' bed '["direction"=0,"head_piece_bit"=true]'

echo "House centre (feet level): $WHERE  - re-run extras with: ./build-house.sh --at ${WHERE//[(),]/} --extras-only"
