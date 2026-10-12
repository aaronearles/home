#!/usr/bin/env bash
# Builds a 9x9 starter house centred on a player (they end up standing inside it).
# Usage: ./build-house.sh <player|@p> [wall_block] [floor_block]
#   e.g. ./build-house.sh aearles                      (oak walls, oak floor)
#        ./build-house.sh hcearles oak_planks spruce_planks
# Layout: 9x9 footprint, 6 tall, flat roof, floor one below their feet. Everything inside
# the shell is cleared (it digs into hillsides). 2x2 doorway on the south (+z) side,
# glass windows on the other three walls. Furnished: crafting table, furnace, chest
# and a lantern in each corner.
# Commands ignore Land Claims - aim it at the player's own land.

MC="docker compose -f $HOME/mc-bedrock/docker-compose.yml exec -T minecraft send-command"
PLAYER="${1:?Usage: $0 <player|@p> [wall_block] [floor_block]}"
WALL="${2:-oak_planks}"
FLOOR="${3:-$WALL}"

run() { $MC execute at "$PLAYER" run "$@" </dev/null; }

# Outer shell: 9x9 footprint, 6 blocks tall, floor one below feet
run fill '~-4' '~-1' '~-4' '~4' '~4' '~4' "$WALL" '[]' hollow

# Different floor material (optional)
[[ "$FLOOR" != "$WALL" ]] && run fill '~-4' '~-1' '~-4' '~4' '~-1' '~4' "$FLOOR"

# Door gap on south face (2 wide x 2 tall)
run fill '~-1' '~0' '~4' '~0' '~1' '~4' air '[]' replace "$WALL"

# Windows on the other 3 walls
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
