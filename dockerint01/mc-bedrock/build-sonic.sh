#!/usr/bin/env bash
# Builds a giant Sonic the Hedgehog pixel art sculpture
# Usage: ./build-sonic.sh <player|@p> [scale]
# Scale defaults to 5 (each pixel = 5x5 blocks → 100 wide x 160 tall)
# Stand back and face south after running to see him.

MC="docker compose -f $HOME/mc-bedrock/docker-compose.yml exec minecraft send-command"
PLAYER="${1:?Usage: $0 <player|@p> [scale]}"
SCALE="${2:-5}"
Z=5     # blocks south of player
BASE=2  # blocks above player's feet

# Color key
declare -A BLOCKS=(
    [B]="blue_concrete"    # Sonic's body
    [T]="sandstone"        # tan face/skin
    [W]="white_concrete"   # eyes and gloves
    [K]="black_concrete"   # pupils and mouth
    [R]="red_concrete"     # shoes
)
# . = air (skipped)

# Sprite definition — 20 columns wide, row 0 = bottom (shoes), row 31 = top (spike tips)
ROWS=(
    "....RRR...RRR......."  #  0  shoe tips
    "...RRRRR.RRRRR......"  #  1  shoes
    "...RRRRR.RRRRR......"  #  2  shoes
    "...RRRRR.RRRRR......"  #  3  shoes
    "....BB.....BB......."  #  4  lower legs
    "....BB.....BB......."  #  5  legs
    "....BBB...BBB......."  #  6  upper legs
    "...BBBBBBBBBBB......"  #  7  waist
    "..WWBBBBBBBBBWW....."  #  8  gloves
    ".WWBBBBBBBBBBBWW...."  #  9  gloves / lower body
    ".BBBBBBBBBBBBBBB...."  # 10  lower body
    "BBBBTTTTTTTTTBBBB..."  # 11  belly
    "BBBBTTTTTTTTTBBBB..."  # 12  belly
    "BBBBTTTTTTTTTBBBB..."  # 13  belly
    ".BBBBBBBBBBBBBB....."  # 14  upper body
    "..BBBBBBBBBBBB......"  # 15  chest
    "..BBBBBBBBBBBB......"  # 16  neck
    ".BBTTKKTTTTTTB......"  # 17  smirk
    ".BBTTTTTTTTTTTB....."  # 18  chin
    "BBTTTTTTTTTTTTBB...."  # 19  face lower
    "BBTTWWWKTTTTTTBB...."  # 20  eye
    "BBTTWWWKTTTTTTBB...."  # 21  eye
    "BBTTTTTTTTTTTTBB...."  # 22  face upper
    "BBBBBBBBBBBBBBBB...."  # 23  head
    "BBBBBBBBBBBBBBBB...."  # 24  head
    ".BBBBBBBBBBBBBBB...."  # 25  upper head
    "..BBBBBBBBBBBBB....."  # 26  head top
    "..BBBBBBBBBBBBB....."  # 27  spike base
    "...BBBBBBBBBBB......"  # 28  spikes connect
    "...BBB.....BBB......"  # 29  two spikes
    "...BBB.....BBB......"  # 30  two spikes
    "....BB.....BB......."  # 31  spike tips
)

NCOLS=20
NROWS=${#ROWS[@]}
HALF=$(( NCOLS / 2 ))

run() { $MC execute at "$PLAYER" run "$@"; }

echo "Building Sonic (${NROWS}×${NCOLS} pixels at ${SCALE}x scale = $(( NROWS*SCALE )) blocks tall)..."

for (( row=0; row<NROWS; row++ )); do
    line="${ROWS[$row]}"
    y1=$(( BASE + row * SCALE ))
    y2=$(( y1 + SCALE - 1 ))

    col=0
    while (( col < NCOLS )); do
        char="${line:$col:1}"
        run_start=$col

        # Scan to end of this color run
        while (( col < NCOLS )) && [[ "${line:$col:1}" == "$char" ]]; do
            (( col++ ))
        done
        run_end=$(( col - 1 ))

        block="${BLOCKS[$char]:-}"
        [[ -z "$block" ]] && continue

        x1=$(( (run_start - HALF) * SCALE ))
        x2=$(( (run_end   - HALF) * SCALE + SCALE - 1 ))

        run fill "~$x1" "~$y1" "~$Z" "~$x2" "~$y2" "~$Z" "$block"
    done
done

echo "Done! Sonic is ${Z} blocks south of $PLAYER — step back and face south to see him."
