#!/usr/bin/env bash
# Removes bulletproof glass (earles:bulletproof_glass) and prints the result.
# Usage: ./clear-glass.sh                        every skybox recorded since recording was added
#        ./clear-glass.sh X1 Y1 Z1 X2 Y2 Z2 [dimension]
#                                                bulletproof glass inside that region (overworld by
#                                                default); for hand-placed glass or older skyboxes
# Unloaded chunks are loaded with a temporary ticking area first, so this takes a few seconds.
# Runs scriptevent earles:claims clearglass (Land Claims add-on); needs the server running.
set -euo pipefail
cd "$(dirname "$0")"

since=$(date -u +%Y-%m-%dT%H:%M:%S.%NZ)   # sub-second, so back-to-back runs don't read each other's output
docker compose exec -T minecraft send-command "scriptevent earles:claims clearglass $*" </dev/null >/dev/null
# Wait for the "done"/error line (the fill happens ~2 s later, after chunks load)
for _ in $(seq 1 60); do
    sleep 1
    out=$(docker compose logs --no-log-prefix --since "$since" minecraft | grep '\[claims\] clearglass' || true)
    grep -qE 'clearglass: (done|no recorded|usage|unknown)' <<< "$out" && break
done
sed -E 's/^\[[^]]*\] \[Scripting\] //' <<< "$out"
[[ -n "$out" ]] || { echo "No answer from the server - is the Land Claims add-on loaded?" >&2; exit 1; }
