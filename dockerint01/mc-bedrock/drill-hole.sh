#!/usr/bin/env bash
# Drills a 1x1 shaft straight down, one block in front of a player, to y=-50 and puts a
# water source at the bottom so they can jump in and land safely.
# Usage: ./drill-hole.sh <player> [bottom_y]     (bottom_y default -50; water goes there)
#
# The single command everything is built on (run from the console or a script):
#   execute as <player> at @s rotated ~ 0 positioned ^ ^ ^1 run <command>
#   = one block in front of the player at feet level, ignoring head pitch.
# Steps, all relative to that spot:
#   1. lava guard: lava in a 3x3 around the shaft becomes stone (so it can't pour in)
#   2. floor: stone under the water
#   3. shaft: air from feet level down to just above the water
#   4. water source at the bottom
# Notes: commands ignore Land Claims; water can leak sideways if the shaft cuts a cave.
set -euo pipefail
cd "$(dirname "$0")"

PLAYER="${1:?Usage: $0 <player> [bottom_y]}"
BOTTOM="${2:--50}"
AT="execute as $PLAYER at @s rotated ~ 0 positioned ^ ^ ^1 run"

mc() { docker compose exec -T minecraft send-command "$1" </dev/null >/dev/null; sleep 0.3; }

since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
mc "$AT fill ~-1 $((BOTTOM - 1)) ~-1 ~1 ~ ~1 stone replace lava"
mc "$AT fill ~-1 $((BOTTOM - 1)) ~-1 ~1 ~ ~1 stone replace flowing_lava"
mc "$AT setblock ~ $((BOTTOM - 1)) ~ stone"
mc "$AT fill ~ ~ ~ ~ $((BOTTOM + 1)) ~ air"
mc "$AT setblock ~ $BOTTOM ~ water"
sleep 1
out=$(docker compose logs --no-log-prefix --since "$since" minecraft | grep -E 'filled|placed|No targets|ERROR|Cannot' || true)
if grep -q 'No targets' <<< "$out"; then
    echo "Player '$PLAYER' isn't online." >&2; exit 1
fi
echo "$out" | sed -E 's/^\[[^]]*\] //'
echo "Done: shaft in front of $PLAYER down to y=$BOTTOM with water at the bottom."
