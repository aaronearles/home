#!/usr/bin/env bash
# Spawns a chest stocked with netherite gear near a player
# Usage: ./spawn-chest.sh <player>

MC="docker compose -f $HOME/mc-bedrock/docker-compose.yml exec minecraft send-command"
PLAYER="${1:?Usage: $0 <player>}"

# --- Locate player via querytarget ---
echo "Locating $PLAYER..."
$MC querytarget "$PLAYER" > /dev/null 2>&1
sleep 1

LOGS=$(docker logs --since 5s minecraft_itzg 2>&1)

PX=$(echo "$LOGS" | grep -oP '"x"\s*:\s*\K[0-9.-]+' | tail -1)
PY=$(echo "$LOGS" | grep -oP '"y"\s*:\s*\K[0-9.-]+' | tail -1)
PZ=$(echo "$LOGS" | grep -oP '"z"\s*:\s*\K[0-9.-]+' | tail -1)

if [[ -z "$PX" || -z "$PY" || -z "$PZ" ]]; then
    echo "Error: could not read position for $PLAYER — are they online?"
    exit 1
fi

PX=$(echo "$PX" | awk '{print int($1)}')
PY=$(echo "$PY" | awk '{print int($1)}')
PZ=$(echo "$PZ" | awk '{print int($1)}')

echo "Player at: $PX $PY $PZ"

# Place chest 2 blocks east at foot level
CX=$(( PX + 2 ))
CY=$PY
CZ=$PZ

echo "Placing chest at: $CX $CY $CZ"
$MC setblock $CX $CY $CZ chest
sleep 0.3

# Stock slots with netherite gear
stock() { $MC replaceitem block $CX $CY $CZ slot.container $1 "$2" 1; }

stock 0 netherite_helmet
stock 1 netherite_chestplate
stock 2 netherite_leggings
stock 3 netherite_boots
stock 4 netherite_sword
stock 5 netherite_pickaxe
stock 6 netherite_axe
stock 7 netherite_shovel
stock 8 netherite_hoe

echo "Done — chest is 2 blocks east of $PLAYER."
