#!/usr/bin/env bash
# Backs up Minecraft worlds. Meant for cron; safe to run any time, even with players on.
# Usage: ./backup-worlds.sh [keep_days]
#            Nightly: every world in data/worlds -> backups/nightly/worlds-<timestamp>.tar.gz
#            (default keep 14 days)
#        ./backup-worlds.sh --snapshot <reason> [keep_days]
#            Active world only -> backups/snapshots/<World>-<timestamp>-<reason>.tar.gz
#            (default keep 7 days). Used by join-snapshot.sh when a player joins.
#
# The active world is copied consistently while the server runs, using BDS's
# `save hold` / `save query` / `save resume`: hold pauses writes, query returns the
# file list with exact lengths, and each file is copied then truncated to that length.
# Inactive worlds aren't being written, so they're tarred as-is.
# A lock (backups/.backup.lock) keeps nightly backups and snapshots from overlapping.
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin
cd "$(dirname "$0")"

SNAPSHOT=""
if [[ "${1:-}" == "--snapshot" ]]; then
    SNAPSHOT=$(printf '%s' "${2:?--snapshot needs a reason}" | tr -c 'A-Za-z0-9_.-' '_')
    shift 2
fi

STAMP=$(date +%Y%m%d-%H%M%S)
if [[ -n "$SNAPSHOT" ]]; then
    KEEP_DAYS="${1:-7}"; DEST=backups/snapshots
else
    KEEP_DAYS="${1:-14}"; DEST=backups/nightly
fi
log() { echo "$(date '+%F %T') $*"; }

mkdir -p "$DEST"
exec 9>backups/.backup.lock
flock -w 300 9 || { log "ERROR: another backup is still running"; exit 1; }

STAGE=$(mktemp -d)
HELD=0
cleanup() {
    [[ $HELD -eq 1 ]] && docker compose exec -T minecraft send-command "save resume" </dev/null >/dev/null 2>&1 || true
    rm -rf -- "${STAGE:?}"
}
trap cleanup EXIT

ACTIVE=$(docker compose config minecraft | sed -n 's/^ *LEVEL_NAME: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' | head -1)
RUNNING=0
docker compose ps --status running --services | grep -qx minecraft && [[ -d "data/worlds/$ACTIVE" ]] && RUNNING=1

if [[ -n "$SNAPSHOT" && $RUNNING -eq 0 ]]; then
    log "Server not running - nothing to snapshot."
    exit 0
fi

if [[ $RUNNING -eq 1 ]]; then
    log "Holding saves on active world $ACTIVE..."
    since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
    docker compose exec -T minecraft send-command "save hold" </dev/null >/dev/null
    HELD=1
    files=""
    for _ in $(seq 1 30); do
        sleep 2
        docker compose exec -T minecraft send-command "save query" </dev/null >/dev/null
        sleep 1
        files=$(docker compose logs --no-log-prefix --since "$since" minecraft \
            | grep -A1 'Files are now ready to be copied' | tail -1)
        [[ -n "$files" && "$files" != *"Files are now ready"* ]] && break
        files=""
    done
    [[ -n "$files" ]] || { log "ERROR: server never reported files ready"; exit 1; }

    # "Skyblock/db/CURRENT:16, Skyblock/level.dat:2952, ..." -> copy + truncate each
    python3 -I - "$files" data/worlds "$STAGE" <<'EOF'
import os, shutil, sys
listing, src, dst = sys.argv[1:4]
for entry in listing.split(", "):
    path, _, length = entry.strip().rpartition(":")
    out = os.path.join(dst, path)
    os.makedirs(os.path.dirname(out), exist_ok=True)
    shutil.copyfile(os.path.join(src, path), out)
    with open(out, "r+b") as f:
        f.truncate(int(length))
EOF
    docker compose exec -T minecraft send-command "save resume" </dev/null >/dev/null
    HELD=0
    log "Copied $(echo "$files" | tr ',' '\n' | wc -l) files from $ACTIVE; saves resumed."
fi

if [[ -n "$SNAPSHOT" ]]; then
    OUT="$DEST/$ACTIVE-$STAMP-$SNAPSHOT.tar.gz"
    tar -czf "$OUT" -C "$STAGE" "$ACTIVE"
    pattern='*.tar.gz'
elif [[ $RUNNING -eq 1 ]]; then
    OUT="$DEST/worlds-$STAMP.tar.gz"
    others=()
    for d in data/worlds/*; do
        name=$(basename "$d")
        [[ "$name" == "$ACTIVE" ]] || others+=("$name")
    done
    tar -czf "$OUT" -C data/worlds "${others[@]}" -C "$STAGE" "$ACTIVE"
    pattern='worlds-*.tar.gz'
else
    log "Server not running - archiving worlds directly."
    OUT="$DEST/worlds-$STAMP.tar.gz"
    tar -czf "$OUT" -C data/worlds .
    pattern='worlds-*.tar.gz'
fi

log "Wrote $OUT ($(du -h "$OUT" | cut -f1))"
pruned=$(find "$DEST" -name "$pattern" -mtime +"$KEEP_DAYS" -print -delete | wc -l)
log "Pruned $pruned backup(s) older than $KEEP_DAYS days."
