#!/usr/bin/env bash
# Installs add-ons from addons/<name>/{BP,RP} into the server and enables them for a world.
# Usage: ./setup-addons.sh <World> <addon> [addon...]
#   e.g. ./setup-addons.sh Experimental blasters tnt_destructive
#
# - Copies each pack to data/behavior_packs/addon_<name> and data/resource_packs/addon_<name>
#   (replacing any older copy; data/behavior_packs is root-owned, so this runs in a container)
# - Writes data/worlds/<World>/world_behavior_packs.json and world_resource_packs.json
#   listing exactly these add-ons (creating the world dir if needed, so a brand-new world
#   is generated with them)
# Safe to re-run. Takes effect the next time the server loads that world.
# See addons/SOURCES.md for where each add-on came from.
set -euo pipefail
cd "$(dirname "$0")"

WORLD="${1:?Usage: $0 <World> <addon> [addon...]}"
shift
[[ $# -gt 0 ]] || { echo "Usage: $0 <World> <addon> [addon...]" >&2; exit 1; }
for a in "$@"; do
    [[ -f "addons/$a/BP/manifest.json" ]] || { echo "Missing addons/$a/BP/manifest.json" >&2; exit 1; }
done

# Install packs (root-owned dirs -> throwaway container)
docker run --rm -v "$PWD/addons:/src:ro" -v "$PWD/data:/data" python:3.12-alpine sh -c '
    for a in "$@"; do
        rm -rf "/data/behavior_packs/addon_$a" "/data/resource_packs/addon_$a"
        cp -a "/src/$a/BP" "/data/behavior_packs/addon_$a"
        [ -d "/src/$a/RP" ] && cp -a "/src/$a/RP" "/data/resource_packs/addon_$a"
        echo "Installed $a"
    done' sh "$@"

# Enable for the world: [{"pack_id": uuid, "version": [x,y,z]}, ...]
mkdir -p "data/worlds/$WORLD"
docker run --rm -i -v "$PWD/addons:/src:ro" -v "$PWD/data/worlds/$WORLD:/w" python:3.12-alpine \
    python3 -I - "$@" <<'EOF'
import json, os, sys
for kind, out in (("BP", "world_behavior_packs.json"), ("RP", "world_resource_packs.json")):
    packs = []
    for a in sys.argv[1:]:
        m = f"/src/{a}/{kind}/manifest.json"
        if os.path.exists(m):
            h = json.load(open(m))["header"]
            packs.append({"pack_id": h["uuid"], "version": h["version"]})
    json.dump(packs, open(f"/w/{out}", "w"), indent=2)
    print(f"{out}: {len(packs)} pack(s)")
EOF
echo "Add-ons enabled for $WORLD: $*"
