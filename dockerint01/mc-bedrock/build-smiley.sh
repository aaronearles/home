#!/usr/bin/env bash
# Builds a 15x15 smiley face floating in the air in front of the player
# Usage: ./build-smiley.sh <player|@p> [face_block] [feature_block]

MC="docker compose -f $HOME/mc-bedrock/docker-compose.yml exec minecraft send-command"
PLAYER="${1:?Usage: $0 <player|@p> [face_block] [feature_block]}"
FACE="${2:-yellow_wool}"
FEAT="${3:-black_wool}"
Z=5     # blocks in front (south)
BASE=12 # y above player's feet

run() { $MC execute at "$PLAYER" run "$@"; }

# Circular face, 15 wide x 15 tall, row by row bottom to top
run fill "~-2" "~$((BASE+0))"  "~$Z" "~2"  "~$((BASE+0))"  "~$Z" "$FACE"
run fill "~-4" "~$((BASE+1))"  "~$Z" "~4"  "~$((BASE+1))"  "~$Z" "$FACE"
run fill "~-5" "~$((BASE+2))"  "~$Z" "~5"  "~$((BASE+2))"  "~$Z" "$FACE"
run fill "~-6" "~$((BASE+3))"  "~$Z" "~6"  "~$((BASE+3))"  "~$Z" "$FACE"
run fill "~-6" "~$((BASE+4))"  "~$Z" "~6"  "~$((BASE+4))"  "~$Z" "$FACE"
run fill "~-7" "~$((BASE+5))"  "~$Z" "~7"  "~$((BASE+5))"  "~$Z" "$FACE"
run fill "~-7" "~$((BASE+6))"  "~$Z" "~7"  "~$((BASE+6))"  "~$Z" "$FACE"
run fill "~-7" "~$((BASE+7))"  "~$Z" "~7"  "~$((BASE+7))"  "~$Z" "$FACE"
run fill "~-7" "~$((BASE+8))"  "~$Z" "~7"  "~$((BASE+8))"  "~$Z" "$FACE"
run fill "~-7" "~$((BASE+9))"  "~$Z" "~7"  "~$((BASE+9))"  "~$Z" "$FACE"
run fill "~-6" "~$((BASE+10))" "~$Z" "~6"  "~$((BASE+10))" "~$Z" "$FACE"
run fill "~-6" "~$((BASE+11))" "~$Z" "~6"  "~$((BASE+11))" "~$Z" "$FACE"
run fill "~-5" "~$((BASE+12))" "~$Z" "~5"  "~$((BASE+12))" "~$Z" "$FACE"
run fill "~-4" "~$((BASE+13))" "~$Z" "~4"  "~$((BASE+13))" "~$Z" "$FACE"
run fill "~-2" "~$((BASE+14))" "~$Z" "~2"  "~$((BASE+14))" "~$Z" "$FACE"

# Eyes (2x2 each, upper third)
run fill "~-5" "~$((BASE+10))" "~$Z" "~-4" "~$((BASE+11))" "~$Z" "$FEAT"
run fill "~4"  "~$((BASE+10))" "~$Z" "~5"  "~$((BASE+11))" "~$Z" "$FEAT"

# Smile (U-shaped arc, lower third)
run fill "~-2" "~$((BASE+2))"  "~$Z" "~2"  "~$((BASE+2))"  "~$Z" "$FEAT"  # bottom center
run fill "~-4" "~$((BASE+3))"  "~$Z" "~-3" "~$((BASE+3))"  "~$Z" "$FEAT"  # left side
run fill "~3"  "~$((BASE+3))"  "~$Z" "~4"  "~$((BASE+3))"  "~$Z" "$FEAT"  # right side
run fill "~-6" "~$((BASE+4))"  "~$Z" "~-5" "~$((BASE+4))"  "~$Z" "$FEAT"  # left corner
run fill "~5"  "~$((BASE+4))"  "~$Z" "~6"  "~$((BASE+4))"  "~$Z" "$FEAT"  # right corner

echo "Smiley face built above $PLAYER"
