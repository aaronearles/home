#!/usr/bin/env bash
# Usage: ./build-house.sh <player|@p> [wall_block] [floor_block]

MC="docker compose -f $HOME/mc-bedrock/docker-compose.yml exec minecraft send-command"
PLAYER="${1:?Usage: $0 <player|@p> [wall_block] [floor_block]}"
WALL="${2:-oak_planks}"
FLOOR="${3:-$WALL}"

run() { $MC execute at "$PLAYER" run "$@"; }

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
