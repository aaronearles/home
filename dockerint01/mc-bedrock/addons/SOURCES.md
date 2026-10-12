# Add-ons

Community add-ons (third-party content, not committed to git). Each one has `BP/` (behavior pack) and `RP/` (resource pack) extracted from the `.mcaddon`. `setup-addons.sh` installs them into `data/` and enables them for a world.

| Dir | Add-on | Author | CurseForge project / file | File | sha256 (.mcaddon) |
|---|---|---|---|---|---|
| `blasters` | [Blasters](https://www.curseforge.com/minecraft-bedrock/addons/blasters) v1.0.0 | arcstarstudios | 1707080 / 8945889 | `Blasters-v1.0.0.mcaddon` | `8b0630783678ea8dbc053202e233c97834e505e2ab5168a1dac1af5dad918ad2` |
| `tnt_destructive` | [TNT Destructive](https://www.curseforge.com/minecraft-bedrock/addons/tnt-destructive-addon) V17 | LasokarXD | 1421053 / 8774863 | `TNT Destructive Addon.mcaddon` | `1eb875eaafde814a28a6ac70b19a50d86f0900b3b0fe5e3d994dbb58238605f9` |

## Saved add-ons and re-fetching

`addons/addons.tsv` (in git) is the registry: name, CurseForge project ID, file ID, sha256. Each `addons/<name>/` holds the unpacked `BP/`, `RP/` and the `original.mcaddon`.

    ./fetch-addon.sh --all                          # restore every registered add-on (hash-checked)
    ./fetch-addon.sh <name> <project_id> <file_id>  # add a new one (then review it!)
    ./setup-addons.sh <World> <name> [name...]      # enable add-ons for any world

The CurseForge web pages are behind a Cloudflare bot check, but the download API isn't (`https://www.curseforge.com/api/v1/mods/<project>/files/<file>/download`).

**Favorites** (the kids loved these, 2026-10-12): `blasters`, `tnt_destructive`. They're on in `experimental` mode. To put them in another world: `./setup-addons.sh <World> blasters tnt_destructive`, then restart while that world is active.

## Review notes (2026-10-12)

- **Blasters:** minified `scripts/main.js`.
  - Imports only `@minecraft/server` 2.9.0 and `@minecraft/server-ui` 2.1.0 (stable).
  - Only command it runs is `stopsound`.
  - No network or dynamic code; one URL is a text credit.
- **TNT Destructive:** `scripts/tnt_logic.js`.
  - Imports only `@minecraft/server` 1.12.0.
  - Runs `time set day` / `time set night` (day/night TNT).
- **Neither needs experimental toggles** (`is_experimental: false` throughout).
- When updating an add-on: re-download, re-check the hash, and re-review the scripts before replacing the folder.
