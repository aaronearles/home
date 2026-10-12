# Add-ons

Community add-ons (third-party content, not committed to git). Each one has `BP/` (behavior pack) and `RP/` (resource pack) extracted from the `.mcaddon`. `setup-addons.sh` installs them into `data/` and enables them for a world.

| Dir | Add-on | Author | CurseForge project / file | File | sha256 (.mcaddon) |
|---|---|---|---|---|---|
| `blasters` | [Blasters](https://www.curseforge.com/minecraft-bedrock/addons/blasters) v1.0.0 | arcstarstudios | 1707080 / 8945889 | `Blasters-v1.0.0.mcaddon` | `8b0630783678ea8dbc053202e233c97834e505e2ab5168a1dac1af5dad918ad2` |
| `tnt_destructive` | [TNT Destructive](https://www.curseforge.com/minecraft-bedrock/addons/tnt-destructive-addon) V17 | LasokarXD | 1421053 / 8774863 | `TNT Destructive Addon.mcaddon` | `1eb875eaafde814a28a6ac70b19a50d86f0900b3b0fe5e3d994dbb58238605f9` |

Exact IDs and hashes for every add-on are in `addons.tsv`. The table above lists the first two in detail.

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

## Review of the 2026-10-12 batch (downloaded, NOT enabled yet)

Downloaded with `fetch-addon.sh`, hashes pinned in `addons.tsv`. Checks:
- safe extraction
- manifests and dependencies
- script imports
- `eval` / `new Function` / network modules
- commands each script runs
- `player.json` overrides
- experiment requirements

| Add-on | Version | Size | Verdict | Notes |
|---|---|---|---|---|
| `orbital_railgun` | v7 (26.30) | 2 MB | OK | Stable script modules. Runs `fill`, `setblock`, `camerashake`, `tickingarea`, `time`. Big terrain damage by design. |
| `portal_gun` | v1.1.1 (26.40) | 7 MB | OK | Stable modules. Runs `camera`, `setblock`. Author says "under active development". |
| `quick_structures` | Quick Craft v3.8 | 5 MB | OK | Stable modules (1.12.0). Runs `tickingarea`, `playsound`. |
| `tree_physics` | 1.0.2 (26.40) | 1 MB | **Doesn't run on this server (2026-10-12)**. Its script imports `EntitySwingSource`, which BDS 1.26.52's `@minecraft/server` 2.8.0 doesn't export, so the script fails and a block fails to parse. Retry after a BDS update. | Stable modules. URLs are code comments. `packs.list` enables the main BP+RP only (the Compatible BP is an optional alternative). Only affects **newly generated** trees, so best in a new world. |
| `immortal_dogs` | V1.1 | 1 MB | OK | Data-only behavior pack, no scripts. |
| `serp_pokedrock` | v1.34.13 Base | 11 MB | OK | Stable modules. Declares the `script_eval` capability but never uses eval. The base download has 1 BP + 1 RP; the page mentions optional extra resource packs (not downloaded). |
| `cobbledrock` | Full 1.3.2 | 273 MB | **Core only** (pokemon mode, 2026-10-12). Content (gyms, raid dens, fossils, villages) needs a newer Minecraft than BDS 1.26.52: script export `BiomeTypes` missing, and the `minecraft:multi_block` block trait. Enabling the Upcoming Creator Features + Beta APIs experiments did **not** help. `packs.list` limits it to Core; re-test Content after a BDS update. Core: no script errors; 1,220 harmless 'duplicate crafting item catalog' errors. | Core + Content (2 BP + 2 RP, ~24k files). Stable modules, ~140 scripts, nothing risky. **Overrides player.json.** Clients must download ~270 MB on first join, which is slow on Xbox. |
| `spiderman` | v1.0.3 (26.40) | 28 MB | OK | 202 scripts, normal gameplay commands. **Overrides player.json** (BP and RP). |
| `marvel` | v3.0.1 (26.30) | 30 MB | Caution | Includes Spider-Man and many heroes. **Overrides player.json.** Flight runs `gamemode c` / `gamemode s` / `gamemode a` and `ability mayfly`, so it **switches players' game mode**. It needs the **Education Edition** world toggle for flight. Declares `script_eval` but doesn't use it. |
| `morphing_bracelet` | v0.3.4 beta (26.50) | 2 MB | OK, solo | Packed in `.brarchive`. Its `eval` only evaluates sound conditions from its own data. The author says it heavily modifies **player.json**, so don't combine it with other add-ons. |
| ~~`pickup_carry`~~ | v3.1.14 (26.50) | 1 MB | **Rejected and deleted 2026-10-12. Project 1251469 is blocked in `fetch-addon.sh`** | Scripts are **deliberately obfuscated**: encrypted strings, `eval`/`new Function` of runtime-decoded code, anti-debug. Can't be verified. Needs the **Beta APIs** experiment. **Overrides player.json.** |

### Can't share a world: player.json overrides
Only one add-on that replaces the player definition works per world. Those are `cobbledrock`, `marvel`, `spiderman` and `morphing_bracelet`. Blasters and TNT don't override it.

### Suggested groupings (when the kids are ready)
- **Experimental (current world):** `blasters`, `tnt_destructive` + `orbital_railgun`, `portal_gun`, `quick_structures`, `immortal_dogs`, `serp_pokedrock`. None of these touch player.json. **Enabled 2026-10-12:** orbital_railgun, portal_gun, quick_structures (plus tornado_tnt, ours); a file/identifier overlap check found no conflicts. `tree_physics` failed to load (see above).
- **Pokémon world:** `cobbledrock` alone. It's heavy and owns player.json. Start with `serp_pokedrock` in Experimental to see whether they like it first.
- **Heroes world:** `spiderman` (simpler), or `marvel` (bigger, needs the Education toggle, flips game modes).
- **Morph world:** `morphing_bracelet` on its own.
- **Rejected:** `pickup_carry` was deleted, and its project is blocked from being fetched again.
