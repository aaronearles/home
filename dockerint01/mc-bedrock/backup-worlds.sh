#!/usr/bin/env bash
# Backs up every world in data/worlds to backups/nightly/worlds-<timestamp>.tar.gz
# and prunes backups older than KEEP_DAYS. Meant for cron; safe to run any time.
# Usage: ./backup-worlds.sh [keep_days]     (default 14)
#
# The active world is copied consistently while the server runs, using BDS's
# `save hold` / `save query` / `save resume`: hold pauses writes, query returns the
# file list with exact lengths, and each file is copied then truncated to that length.
# Inactive worlds aren't being written, so they're tarred as-is.
set -euo pipefail
export PATH=/usr/local/bin:/usr/bin:/bin
cd "$(dirname "$0")"

KEEP_DAYS="${1:-14}"
DEST=backups/nightly
STAMP=$(date +%Y%m%d-%H%M%S)
OUT="$DEST/worlds-$STAMP.tar.gz"
log() { echo "$(date '+%F %T') $*"; }

mkdir -p "$DEST"
STAGE=$(mktemp -d)
HELD=0
cleanup() {
    [[ $HELD -eq 1 ]] && docker compose exec -T minecraft send-command "save resume" </dev/null >/dev/null 2>&1 || true
    rm -rf -- "${STAGE:?}"
}
trap cleanup EXIT

ACTIVE=$(docker compose config minecraft | sed -n 's/^ *LEVEL_NAME: *"\{0,1\}\([^"]*\)"\{0,1\}$/\1/p' | head -1)
others=()
for d in data/worlds/*; do
    name=$(basename "$d")
    [[ "$name" == "$ACTIVE" ]] || others+=("$name")
done

if docker compose ps --status running --services | grep -qx minecraft && [[ -d "data/worlds/$ACTIVE" ]]; then
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
    tar -czf "$OUT" -C data/worlds "${others[@]}" -C "$STAGE" "$ACTIVE"
else
    log "Server not running - archiving worlds directly."
    tar -czf "$OUT" -C data/worlds .
fi

log "Wrote $OUT ($(du -h "$OUT" | cut -f1))"
pruned=$(find "$DEST" -name 'worlds-*.tar.gz' -mtime +"$KEEP_DAYS" -print -delete | wc -l)
log "Pruned $pruned backup(s) older than $KEEP_DAYS days."
