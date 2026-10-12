#!/usr/bin/env bash
# Fast-forwards through full Minecraft day cycles. Ctrl+C to stop.
# Usage: ./cycle-days.sh <seconds_per_day>
# Examples: 5 (blazing fast), 10 (fast), 60 (1 min/day), 1200 (real Minecraft speed)

MC="docker compose -f $HOME/mc-bedrock/docker-compose.yml exec minecraft send-command"
DAY_SECONDS="${1:?Usage: $0 <seconds_per_day>}"

STEPS=24                          # one step per in-game "hour" (1000 ticks each)
TICK_STEP=$(( 24000 / STEPS ))
SLEEP=$(awk "BEGIN {printf \"%.3f\", $DAY_SECONDS / $STEPS}")

trap 'echo; echo "Stopped."; exit 0' INT

echo "Full day every ${DAY_SECONDS}s (${STEPS} steps × ${TICK_STEP} ticks, ${SLEEP}s apart) — Ctrl+C to stop"

tick=0
while true; do
    $MC time set $tick > /dev/null
    case $tick in
        0)     label="dawn"     ;;
        6000)  label="noon"     ;;
        12000) label="dusk"     ;;
        18000) label="midnight" ;;
        *)     label=""         ;;
    esac
    [[ -n "$label" ]] && echo "$(date +%T) → $label (tick $tick)"
    tick=$(( (tick + TICK_STEP) % 24000 ))
    sleep "$SLEEP"
done
