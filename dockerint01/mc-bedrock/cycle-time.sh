#!/usr/bin/env bash
# Cycles between day and night every N seconds. Ctrl+C to stop.
# Usage: ./cycle-time.sh <seconds>

MC="docker compose -f $HOME/mc-bedrock/docker-compose.yml exec minecraft send-command"
INTERVAL="${1:?Usage: $0 <seconds>}"

trap 'echo; echo "Stopped."; exit 0' INT

echo "Cycling day/night every ${INTERVAL}s — Ctrl+C to stop"

while true; do
    $MC time set day
    echo "$(date +%T) → day"
    sleep "$INTERVAL"
    $MC time set midnight
    echo "$(date +%T) → midnight"
    sleep "$INTERVAL"
done
