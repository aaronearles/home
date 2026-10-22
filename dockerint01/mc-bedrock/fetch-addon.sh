#!/usr/bin/env bash
# Downloads a CurseForge Bedrock add-on and unpacks it into addons/<name>/, keeping
# the original download(s) as addons/<name>/original-<file_id>.<ext>.
# Usage: ./fetch-addon.sh <name> <project_id> <file_id>[+<file_id>...] [sha256[+sha256...]] [cdn_file_name]
#   e.g. ./fetch-addon.sh blasters 1707080 8945889
#        ./fetch-addon.sh pickup_carry 1251469 8896058+8896059     (BP and RP are separate files)
#   ./fetch-addon.sh --all      re-fetch everything listed in addons/addons.tsv (hash-checked)
#   Some projects return 404 from the download API. Give the file's name as the last argument
#   (e.g. "The Bloop.mcaddon", pass "" for the sha256 if unknown) and the script falls back to
#   the CDN link the website uses, https://mediafilez.forgecdn.net/files/<id/1000>/<id%1000>/<name>.
#   The name is stored as a 5th column in addons.tsv so --all can restore it.
#
# Layout: an add-on with one behavior pack and/or one resource pack is unpacked to
# addons/<name>/BP and addons/<name>/RP. One with more packs (e.g. Core + Content) goes
# to addons/<name>/packs/<pack>/. setup-addons.sh enables every pack found, or only those
# listed in addons/<name>/packs.list if that file exists.
#
# Find the IDs on the CurseForge page: project ID in the sidebar, file ID in the download
# link (/download/<file_id>). The web pages are behind Cloudflare; the download API isn't.
# Local fixes are re-applied after every fetch, so a re-download never brings back what we removed:
#   tools/patches/<name>.patch         git-format patch, applied to addons/<name>/BP with -p1
#   tools/patch-tree-physics.py        the Tree Physics compatibility patch
# (tnt_destructive: God TNT removed - its chunk erase hangs the scripting watchdog and crashes the server.)
# New add-ons are recorded in addons/addons.tsv. Then REVIEW them (manifests, scripts,
# player.json overrides, experiments; see addons/SOURCES.md) before enabling any.
set -euo pipefail
cd "$(dirname "$0")"
REG=addons/addons.tsv
# CurseForge projects we never want (reviewed and rejected - see addons/SOURCES.md)
BLOCKED_PROJECTS=(
    1251469   # Pickup & Carry (sirob): obfuscated scripts that eval runtime-decoded code
)

apply_local_patches() {
    local name="$1" patch="tools/patches/$1.patch"
    if [[ -f "$patch" ]]; then
        if (cd "addons/$name/BP" && git apply -p1 --check "$OLDPWD/$patch" 2>/dev/null); then
            (cd "addons/$name/BP" && git apply -p1 "$OLDPWD/$patch")
            echo "  applied local patch: $patch"
        else
            echo "ERROR: $patch doesn't apply to the freshly fetched $name - the add-on changed; the patch needs updating" >&2
            return 1
        fi
    fi
    if [[ "$name" == "tree_physics" ]]; then
        python3 -I tools/patch-tree-physics.py | sed 's/^/  /'
    fi
}

fetch() {
    local name="$1" project="$2" files="$3" wants="${4:-}" cdn_name="${5:-}"
    local b
    for b in "${BLOCKED_PROJECTS[@]}"; do
        if [[ "$project" == "$b" ]]; then
            echo "ERROR: CurseForge project $project is blocked (rejected in review, see addons/SOURCES.md)" >&2
            return 1
        fi
    done
    local tmp; tmp=$(mktemp -d)
    trap 'rm -rf -- "${tmp:?}"' RETURN
    IFS='+' read -ra ids <<< "$files"
    IFS='+' read -ra want <<< "$wants"
    local shas=() i=0
    for id in "${ids[@]}"; do
        echo "Downloading $name (project $project, file $id)..."
        if ! curl -fsSL -A 'Mozilla/5.0' -o "$tmp/$id.bin" \
                "https://www.curseforge.com/api/v1/mods/$project/files/$id/download"; then
            [[ -n "$cdn_name" ]] || { echo "ERROR: download API failed for file $id (pass the file name as the last argument to try the CDN)" >&2; return 1; }
            local enc="${cdn_name// /%20}"
            echo "  download API failed, trying the CDN link..."
            curl -fsSL -A 'Mozilla/5.0' -o "$tmp/$id.bin" \
                "https://mediafilez.forgecdn.net/files/${id:0:${#id}-3}/${id: -3}/$enc"
        fi
        local got; got=$(sha256sum "$tmp/$id.bin" | cut -d' ' -f1)
        if [[ -n "${want[$i]:-}" && "$got" != "${want[$i]}" ]]; then
            echo "ERROR: sha256 mismatch for $name file $id (got $got, expected ${want[$i]}) - not installing" >&2
            return 1
        fi
        shas+=("$got"); i=$((i + 1))
    done

    # Unpack safely (no paths escaping the dir, size cap, nested .mcpack/.mcaddon),
    # then sort packs by manifest module type
    python3 -I - "$tmp" "${ids[@]}" <<'EOF'
import json, os, re, shutil, sys, zipfile
tmp, ids = sys.argv[1], sys.argv[2:]
raw = os.path.join(tmp, "raw")
def safe_extract(path, dest):
    z = zipfile.ZipFile(path)
    if sum(i.file_size for i in z.infolist()) > 2_000_000_000:
        sys.exit(f"archive too large: {path}")
    for i in z.infolist():
        p = os.path.normpath(i.filename)
        if p.startswith("..") or os.path.isabs(p):
            sys.exit(f"unsafe path in archive: {i.filename}")
    z.extractall(dest)
for fid in ids:
    safe_extract(os.path.join(tmp, f"{fid}.bin"), os.path.join(raw, fid))
again = True
while again:
    again = False
    for r, _, fs in os.walk(raw):
        for f in fs:
            if f.lower().endswith((".mcpack", ".mcaddon", ".zip")):
                p = os.path.join(r, f)
                safe_extract(p, os.path.join(r, re.sub(r"\.\w+$", "", f) + "__x"))
                os.remove(p); again = True
packs = []
for r, dirs, fs in os.walk(raw):
    if "manifest.json" in fs:
        t = re.sub(r"^\s*//.*$", "", open(os.path.join(r, "manifest.json"), encoding="utf-8").read(), flags=re.M)
        types = {m.get("type") for m in json.loads(t).get("modules", [])}
        packs.append(("RP" if types == {"resources"} else "BP", r))
        dirs[:] = []          # don't descend into a pack
if not packs:
    sys.exit("no manifest.json found")
kinds = [k for k, _ in packs]
out = os.path.join(tmp, "out")
if kinds.count("BP") <= 1 and kinds.count("RP") <= 1:
    for k, r in packs:
        shutil.move(r, os.path.join(out, k))
else:
    for k, r in packs:
        sub = re.sub(r"[^A-Za-z0-9_.-]+", "_", os.path.basename(r).removesuffix("__x")).strip("_") or k
        shutil.move(r, os.path.join(out, "packs", sub))
for k, r in packs:
    print(f"  {k}: {os.path.relpath(r, raw)}")
EOF
    mkdir -p "addons/$name"
    rm -rf -- "addons/$name/BP" "addons/$name/RP" "addons/$name/packs"
    rm -f -- addons/"$name"/original*
    cp -a "$tmp/out/." "addons/$name/"
    for id in "${ids[@]}"; do cp "$tmp/$id.bin" "addons/$name/original-$id.zip"; done

    apply_local_patches "$name"

    touch "$REG"
    grep -v "^$name	" "$REG" > "$REG.new" || true
    printf '%s\t%s\t%s\t%s%s\n' "$name" "$project" "$files" "$(IFS=+; echo "${shas[*]}")" "${cdn_name:+$'\t'$cdn_name}" >> "$REG.new"
    sort -o "$REG" "$REG.new"; rm -f "$REG.new"
    echo "OK: addons/$name"
}

if [[ "${1:-}" == "--all" ]]; then
    while IFS=$'\t' read -r name project files sha cdn; do
        [[ -z "$name" || "$name" == \#* ]] && continue
        fetch "$name" "$project" "$files" "$sha" "$cdn"
    done < "$REG"
else
    [[ $# -ge 3 ]] || { sed -n '2,20p' "$0"; exit 1; }
    fetch "$@"
fi
