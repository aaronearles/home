#!/usr/bin/env bash
# Downloads a CurseForge Bedrock add-on and unpacks it into addons/<name>/{BP,RP},
# keeping the original .mcaddon as addons/<name>/original.mcaddon.
# Usage: ./fetch-addon.sh <name> <project_id> <file_id> [expected_sha256]
#   e.g. ./fetch-addon.sh blasters 1707080 8945889 8b0630...
#   ./fetch-addon.sh --all      re-fetch everything listed in addons/addons.tsv
#
# Find the IDs on the add-on's CurseForge page: project ID in the sidebar, file ID in
# the download link (/download/<file_id>). The web pages are behind Cloudflare, but the
# download API below isn't.
# A new add-on is recorded in addons/addons.tsv. Then REVIEW it (manifest.json and
# scripts/*.js, see addons/SOURCES.md) before enabling it with setup-addons.sh.
set -euo pipefail
cd "$(dirname "$0")"
REG=addons/addons.tsv

fetch() {
    local name="$1" project="$2" file="$3" want="${4:-}"
    local tmp; tmp=$(mktemp -d)
    trap 'rm -rf -- "${tmp:?}"' RETURN
    echo "Downloading $name (project $project, file $file)..."
    curl -fsSL -A 'Mozilla/5.0' -o "$tmp/a.mcaddon" \
        "https://www.curseforge.com/api/v1/mods/$project/files/$file/download"
    local got; got=$(sha256sum "$tmp/a.mcaddon" | cut -d' ' -f1)
    if [[ -n "$want" && "$got" != "$want" ]]; then
        echo "ERROR: sha256 mismatch for $name (got $got, expected $want) - not installing" >&2
        return 1
    fi
    # Unpack safely (no paths escaping the dir), sort packs into BP/RP by manifest module type
    python3 -I - "$tmp/a.mcaddon" "$tmp/x" <<'EOF'
import json, os, shutil, sys, zipfile, io
src, out = sys.argv[1:3]
def safe_extract(zf, dest):
    for i in zf.infolist():
        p = os.path.normpath(i.filename)
        if p.startswith("..") or os.path.isabs(p):
            sys.exit(f"unsafe path in archive: {i.filename}")
    zf.extractall(dest)
z = zipfile.ZipFile(src)
safe_extract(z, out + "/raw")
# .mcaddon may contain nested .mcpack zips
for root, _, files in os.walk(out + "/raw"):
    for f in files:
        if f.lower().endswith(".mcpack"):
            safe_extract(zipfile.ZipFile(os.path.join(root, f)), os.path.join(root, f[:-7]))
found = {}
for root, _, files in os.walk(out + "/raw"):
    if "manifest.json" in files:
        m = json.load(open(os.path.join(root, "manifest.json")))
        types = {mod.get("type") for mod in m.get("modules", [])}
        kind = "RP" if types == {"resources"} else "BP"
        if kind in found:
            sys.exit(f"more than one {kind} pack found - handle this add-on manually")
        found[kind] = root
for kind, root in found.items():
    shutil.move(root, os.path.join(out, kind))
print("packs:", ", ".join(sorted(found)) or "none")
if not found: sys.exit("no manifest.json found")
EOF
    mkdir -p "addons/$name"
    rm -rf -- "addons/$name/BP" "addons/$name/RP"
    [[ -d "$tmp/x/BP" ]] && mv "$tmp/x/BP" "addons/$name/BP"
    [[ -d "$tmp/x/RP" ]] && mv "$tmp/x/RP" "addons/$name/RP"
    cp "$tmp/a.mcaddon" "addons/$name/original.mcaddon"
    # Record (or update) in the registry
    touch "$REG"
    grep -v "^$name	" "$REG" > "$REG.new" || true
    printf '%s\t%s\t%s\t%s\n' "$name" "$project" "$file" "$got" >> "$REG.new"
    sort -o "$REG" "$REG.new"; rm -f "$REG.new"
    echo "OK: addons/$name (sha256 $got)"
}

if [[ "${1:-}" == "--all" ]]; then
    while IFS=$'\t' read -r name project file sha; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        fetch "$name" "$project" "$file" "$sha"
    done < "$REG"
else
    [[ $# -ge 3 ]] || { sed -n '2,12p' "$0"; exit 1; }
    fetch "$@"
fi
