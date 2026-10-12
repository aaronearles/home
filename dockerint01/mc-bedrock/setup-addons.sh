#!/usr/bin/env bash
# Installs add-ons from addons/<name>/ (downloaded) or custom-addons/<name>/ (our own,
# in git) into the server and enables them for a world.
# Usage: ./setup-addons.sh <World> <addon> [addon...]
#   e.g. ./setup-addons.sh Experimental blasters tnt_destructive
#
# Packs per add-on: addons/<name>/BP and RP, or every addons/<name>/packs/<pack>, or
# exactly the paths listed (one per line, relative to addons/<name>/) in
# addons/<name>/packs.list if it exists. Each pack is copied to
# data/{behavior,resource}_packs/addon_<name>[__<pack>] (replacing older copies;
# root-owned dirs, so this runs in a container). Then the world's
# world_behavior_packs.json / world_resource_packs.json are rewritten to list exactly
# these packs, in add-on order. The world dir is created if needed, so a brand-new
# world is generated with them.
# Safe to re-run. Takes effect the next time the server loads that world.
# Don't combine add-ons that override player.json (see addons/SOURCES.md): only one wins.
set -euo pipefail
cd "$(dirname "$0")"

WORLD="${1:?Usage: $0 <World> <addon> [addon...]}"
shift
[[ $# -gt 0 ]] || { echo "Usage: $0 <World> <addon> [addon...]" >&2; exit 1; }
for a in "$@"; do
    [[ -d "addons/$a" || -d "custom-addons/$a" ]] || { echo "No such add-on: $a (not in addons/ or custom-addons/; fetch it with fetch-addon.sh)" >&2; exit 1; }
done

mkdir -p "data/worlds/$WORLD"
mkdir -p custom-addons
docker run --rm -i -v "$PWD/addons:/src:ro" -v "$PWD/custom-addons:/custom:ro" -v "$PWD/data:/data" python:3.12-alpine \
    python3 -I - "$WORLD" "$@" <<'EOF'
import json, os, re, shutil, sys
world, addons = sys.argv[1], sys.argv[2:]
bps, rps = [], []
for a in addons:
    base = f"/src/{a}" if os.path.isdir(f"/src/{a}") else f"/custom/{a}"
    lst = os.path.join(base, "packs.list")
    if os.path.exists(lst):
        rels = [l.strip() for l in open(lst) if l.strip() and not l.startswith("#")]
    else:
        rels = [k for k in ("BP", "RP") if os.path.isdir(os.path.join(base, k))]
        if os.path.isdir(os.path.join(base, "packs")):
            rels += [f"packs/{p}" for p in sorted(os.listdir(os.path.join(base, "packs")))]
    for rel in rels:
        src = os.path.join(base, rel)
        t = re.sub(r"^\s*//.*$", "", open(os.path.join(src, "manifest.json"), encoding="utf-8").read(), flags=re.M)
        m = json.loads(t)
        types = {mod.get("type") for mod in m.get("modules", [])}
        kind = "resource" if types == {"resources"} else "behavior"
        sub = "" if rel in ("BP", "RP") else "__" + os.path.basename(rel)
        dst = f"/data/{kind}_packs/addon_{a}{sub}"
        if os.path.exists(dst):
            shutil.rmtree(dst)
        shutil.copytree(src, dst)
        v = m["header"]["version"]
        if isinstance(v, str):  # some manifests use "1.0.2"
            v = [int(x) for x in v.split(".")[:3]]
        (rps if kind == "resource" else bps).append({"pack_id": m["header"]["uuid"], "version": v})
        print(f"Installed {a}: {rel} -> {dst}")
w = f"/data/worlds/{world}"
json.dump(bps, open(f"{w}/world_behavior_packs.json", "w"), indent=2)
json.dump(rps, open(f"{w}/world_resource_packs.json", "w"), indent=2)
print(f"{world}: {len(bps)} behavior pack(s), {len(rps)} resource pack(s) enabled")
EOF
