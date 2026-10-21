#!/usr/bin/env bash
# Switches the server between the rotation worlds.
# Usage: ./switch-world.sh [skyblock|survival|creative|experimental|pokemon|horror] [-y]
#        ./switch-world.sh            (no mode: show the active world)
#   -y skips the confirmation prompt
#
# Modes:
#   skyblock  Skyblock    void FLAT world, survival, cheats on (built by reset-skyblock.sh if missing)
#   survival  Earles2026  normal world, survival, cheats OFF (keeps achievements)
#   creative  Creative    normal world, creative, cheats on (generated on first switch)
#   experimental  Experimental  normal world, creative, cheats on, with community add-ons
#             (see ADDONS below and addons/SOURCES.md); add-ons are (re)installed
#             by setup-addons.sh on every switch to this mode
#   pokemon   Pokemon     normal world, survival, cheats on, keep inventory, CobbleDrock add-on
#   horror    Horror      normal world, survival, cheats on, keep inventory, Twixxel's Stalkers
#             (a stalker that watches from windows, hides in beds and breaks blocks; no land claims)
#             (Core + Content; ~270 MB resource pack - first join downloads it)
#
# How it works: docker-compose.yml takes LEVEL_NAME / LEVEL_TYPE / GAMEMODE / ALLOW_CHEATS from .env.
# This rewrites .env, recreates the minecraft container (~80s, incl. the TIME_WAIT
# wait), turns on coordinates, turns off PvP, and updates the world name the Xbox broadcast shows.
# Worlds are never deleted; switching back resumes where you left off.
set -euo pipefail
cd "$(dirname "$0")"

declare -A LEVEL=([skyblock]=Skyblock [survival]=Earles2026 [creative]=Creative [experimental]=Experimental [pokemon]=Pokemon [horror]=Horror)
declare -A TYPE=([skyblock]=FLAT [survival]=DEFAULT [creative]=DEFAULT [experimental]=DEFAULT [pokemon]=DEFAULT [horror]=DEFAULT)
# What visitors see as the world name in the Xbox friends list, if it should differ from the
# world name (e.g. DISPLAY=([horror]=Survival) as a prank; the world's level.dat LevelName and
# levelname.txt would need the same name). Empty = every world shows its own name.
declare -A DISPLAY=()
declare -A GAMEMODE=([skyblock]=survival [survival]=survival [creative]=creative [experimental]=creative [pokemon]=survival [horror]=survival)
# Cheats permanently disable achievements in a world, so keep them off for survival
declare -A CHEATS=([skyblock]=true [survival]=false [creative]=true [experimental]=true [pokemon]=true [horror]=true)
# Add-ons (dirs under addons/) enabled for a mode's world
declare -A ADDONS=([experimental]="land_claims owner_button blasters tnt_destructive tornado_tnt orbital_railgun portal_gun quick_structures morphing_bracelet_032" [creative]="land_claims owner_button" [survival]="land_claims" [pokemon]="cobbledrock" [horror]="twixxel_stalkers the_bloop")
# Extra game rules applied after every switch to a mode ("rule value" pairs, ;-separated)
declare -A RULES=([pokemon]="keepinventory true" [horror]="keepinventory true")

MC="docker compose exec -T minecraft send-command"
mc() { $MC "$1" </dev/null >/dev/null; }

current_mode() { sed -n 's/^MC_MODE=//p' .env 2>/dev/null || true; }

MODE=""; YES=0
for a in "$@"; do
    case "$a" in
        -y) YES=1 ;;
        skyblock|survival|creative|experimental|pokemon|horror) MODE="$a" ;;
        *) echo "Unknown option: $a (expected skyblock, survival, creative, experimental, pokemon or horror)" >&2; exit 1 ;;
    esac
done

CUR=$(current_mode); CUR=${CUR:-skyblock}   # no .env = compose defaults = Skyblock
if [[ -z "$MODE" ]]; then
    echo "Active: $CUR (world ${LEVEL[$CUR]}, ${GAMEMODE[$CUR]})"
    exit 0
fi
if [[ "$MODE" == "$CUR" ]]; then
    echo "Already on $MODE (world ${LEVEL[$MODE]})."
    exit 0
fi

NEW_WORLD=0
[[ -d "data/worlds/${LEVEL[$MODE]}" ]] || NEW_WORLD=1

if [[ $YES -eq 0 ]]; then
    note=""; [[ $NEW_WORLD -eq 1 ]] && note=" (new world will be created)"
    read -rp "Switch from $CUR to $MODE - world ${LEVEL[$MODE]}${note}? Players will be disconnected. [y/N] " ans
    [[ "$ans" =~ ^[Yy]$ ]] || { echo "Cancelled."; exit 0; }
fi

if docker compose ps --status running --services | grep -qx minecraft; then
    echo "Warning players..."
    mc "say Switching to ${MODE} in 10 seconds - rejoin in about 2 minutes!" || true
    sleep 10
fi

echo "Writing .env..."
cat > .env <<EOF
# Active world - managed by switch-world.sh (read by docker-compose.yml)
MC_MODE=$MODE
MC_LEVEL_NAME=${LEVEL[$MODE]}
MC_LEVEL_TYPE=${TYPE[$MODE]}
MC_GAMEMODE=${GAMEMODE[$MODE]}
MC_ALLOW_CHEATS=${CHEATS[$MODE]}
EOF

if [[ -n "${ADDONS[$MODE]:-}" ]]; then
    echo "Installing add-ons: ${ADDONS[$MODE]}..."
    # shellcheck disable=SC2086
    ./setup-addons.sh "${LEVEL[$MODE]}" ${ADDONS[$MODE]}
fi

echo "Recreating server (waits ~65s for the port to clear)..."
since=$(date -u +%Y-%m-%dT%H:%M:%SZ)
docker compose up -d minecraft >/dev/null 2>&1
timeout 300 bash -c "until docker compose logs --since '$since' minecraft 2>/dev/null | grep -q 'Server started'; do sleep 3; done" \
    || { echo "Server did not start - check: docker compose logs minecraft" >&2; exit 1; }

if [[ "$MODE" == "skyblock" && $NEW_WORLD -eq 1 ]]; then
    # A fresh FLAT world isn't Skyblock yet - make it void and build the island
    echo "Skyblock world was missing - building it..."
    ./reset-skyblock.sh -y
fi

mc "gamerule showcoordinates true"
mc "gamerule pvp false"   # no friendly fire in any world
if [[ -n "${RULES[$MODE]:-}" ]]; then
    IFS=";" read -ra rules <<< "${RULES[$MODE]}"
    for r in "${rules[@]}"; do mc "gamerule $r"; done
fi

# What the Xbox friends list shows for the session
sed -i -E "s/^(    world-name: ).*/\1${DISPLAY[$MODE]:-${LEVEL[$MODE]}}/; s/^(    game-mode: ).*/\1${GAMEMODE[$MODE]^}/" config/config.yml
docker compose restart mcxboxbroadcast >/dev/null 2>&1

echo "Done! Now on $MODE (world ${LEVEL[$MODE]}, ${GAMEMODE[$MODE]})."
