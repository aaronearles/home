#!/usr/bin/env bash
# Watches the server log and snapshots the active world whenever a player joins,
# so a world can be rolled back to how it was before that session.
# Snapshots: backups/snapshots/<World>-<timestamp>-join-<player>.tar.gz (kept 7 days)
#
# Runs forever. Started by cron every minute under `flock -n`, so exactly one copy
# runs and it comes back after reboots or crashes:
#   * * * * * flock -n ~/mc-bedrock/backups/.join-snapshot.lock ~/mc-bedrock/join-snapshot.sh >> ~/mc-bedrock/backups/snapshots/snapshot.log 2>&1
#
# COOLDOWN (seconds, default 120) skips a snapshot if one was taken recently, so
# several people joining together produce one snapshot.
set -uo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin
cd "$(dirname "$0")"

COOLDOWN="${COOLDOWN:-120}"
STATE=backups/snapshots/.last-snapshot
CONTAINER=minecraft_itzg
log() { echo "$(date '+%F %T') $*"; }

mkdir -p backups/snapshots
log "Watching $CONTAINER for player joins (cooldown ${COOLDOWN}s)..."

while true; do
    since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    # Ends when the container stops or is recreated (e.g. switch-world.sh); then re-attach
    docker logs -f --since "$since" "$CONTAINER" 2>&1 | while IFS= read -r line; do
        [[ "$line" =~ Player\ connected:\ ([^,]+), ]] || continue
        player="${BASH_REMATCH[1]}"
        now=$(date +%s)
        last=$(cat "$STATE" 2>/dev/null || echo 0)
        if (( now - last < COOLDOWN )); then
            log "$player joined - snapshot taken $((now - last))s ago, skipping."
            continue
        fi
        echo "$now" > "$STATE"
        log "$player joined - taking snapshot..."
        ./backup-worlds.sh --snapshot "join-$player" </dev/null || log "Snapshot failed for $player"
    done
    sleep 5
done
