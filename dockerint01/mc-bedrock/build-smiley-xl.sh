#!/usr/bin/env bash
# Builds a 150x150 block glowing smiley face in the sky (15x15 pixels, each 10x10 blocks)
# Usage: ./build-smiley-xl.sh <player|@p> [face_block] [feature_block]

MC="docker compose -f $HOME/mc-bedrock/docker-compose.yml exec minecraft send-command"
PLAYER="${1:?Usage: $0 <player|@p> [face_block] [feature_block]}"
FACE="${2:-glowstone}"
FEAT="${3:-black_concrete}"
Z=30   # blocks in front (south)
BASE=5 # y above player's feet

run() { $MC execute at "$PLAYER" run "$@"; }

# Circular face — each pixel scaled to 10x10 blocks, row by row bottom to top
run fill "~-20" "~$((BASE+0))"   "~$Z" "~20"  "~$((BASE+9))"   "~$Z" "$FACE"  # row 0
run fill "~-40" "~$((BASE+10))"  "~$Z" "~40"  "~$((BASE+19))"  "~$Z" "$FACE"  # row 1
run fill "~-50" "~$((BASE+20))"  "~$Z" "~50"  "~$((BASE+29))"  "~$Z" "$FACE"  # row 2
run fill "~-60" "~$((BASE+30))"  "~$Z" "~60"  "~$((BASE+39))"  "~$Z" "$FACE"  # row 3
run fill "~-60" "~$((BASE+40))"  "~$Z" "~60"  "~$((BASE+49))"  "~$Z" "$FACE"  # row 4
run fill "~-70" "~$((BASE+50))"  "~$Z" "~70"  "~$((BASE+59))"  "~$Z" "$FACE"  # row 5
run fill "~-70" "~$((BASE+60))"  "~$Z" "~70"  "~$((BASE+69))"  "~$Z" "$FACE"  # row 6
run fill "~-70" "~$((BASE+70))"  "~$Z" "~70"  "~$((BASE+79))"  "~$Z" "$FACE"  # row 7
run fill "~-70" "~$((BASE+80))"  "~$Z" "~70"  "~$((BASE+89))"  "~$Z" "$FACE"  # row 8
run fill "~-70" "~$((BASE+90))"  "~$Z" "~70"  "~$((BASE+99))"  "~$Z" "$FACE"  # row 9
run fill "~-60" "~$((BASE+100))" "~$Z" "~60"  "~$((BASE+109))" "~$Z" "$FACE"  # row 10
run fill "~-60" "~$((BASE+110))" "~$Z" "~60"  "~$((BASE+119))" "~$Z" "$FACE"  # row 11
run fill "~-50" "~$((BASE+120))" "~$Z" "~50"  "~$((BASE+129))" "~$Z" "$FACE"  # row 12
run fill "~-40" "~$((BASE+130))" "~$Z" "~40"  "~$((BASE+139))" "~$Z" "$FACE"  # row 13
run fill "~-20" "~$((BASE+140))" "~$Z" "~20"  "~$((BASE+149))" "~$Z" "$FACE"  # row 14

# Eyes (20x20 blocks each)
run fill "~-50" "~$((BASE+100))" "~$Z" "~-40" "~$((BASE+119))" "~$Z" "$FEAT"  # left eye
run fill "~40"  "~$((BASE+100))" "~$Z" "~50"  "~$((BASE+119))" "~$Z" "$FEAT"  # right eye

# Smile (U-shaped arc, 3 rows scaled)
run fill "~-20" "~$((BASE+20))"  "~$Z" "~20"  "~$((BASE+29))"  "~$Z" "$FEAT"  # bottom center
run fill "~-40" "~$((BASE+30))"  "~$Z" "~-30" "~$((BASE+39))"  "~$Z" "$FEAT"  # left side
run fill "~30"  "~$((BASE+30))"  "~$Z" "~40"  "~$((BASE+39))"  "~$Z" "$FEAT"  # right side
run fill "~-60" "~$((BASE+40))"  "~$Z" "~-50" "~$((BASE+49))"  "~$Z" "$FEAT"  # left corner
run fill "~50"  "~$((BASE+40))"  "~$Z" "~60"  "~$((BASE+49))"  "~$Z" "$FEAT"  # right corner

echo "Giant glowing smiley face built above $PLAYER"
