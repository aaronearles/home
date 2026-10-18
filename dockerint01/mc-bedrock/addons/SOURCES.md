# Add-ons

Community add-ons (third-party content, not committed to git). Each one has `BP/` (behavior pack) and `RP/` (resource pack) extracted from the `.mcaddon`. `setup-addons.sh` installs them into `data/` and enables them for a world.

| Dir | Add-on | Author | CurseForge project / file | File | sha256 (.mcaddon) |
|---|---|---|---|---|---|
| `blasters` | [Blasters](https://www.curseforge.com/minecraft-bedrock/addons/blasters) v1.0.0 | arcstarstudios | 1707080 / 8945889 | `Blasters-v1.0.0.mcaddon` | `8b0630783678ea8dbc053202e233c97834e505e2ab5168a1dac1af5dad918ad2` |
| `tnt_destructive` | [TNT Destructive](https://www.curseforge.com/minecraft-bedrock/addons/tnt-destructive-addon) V17 | LasokarXD | 1421053 / 8774863 | `TNT Destructive Addon.mcaddon` | `1eb875eaafde814a28a6ac70b19a50d86f0900b3b0fe5e3d994dbb58238605f9` |

**Local edit - God TNT removed (2026-10-17):** its chunk-erase job hangs the scripting watchdog and shuts the server down. Off the creative menu, recipes deleted, script no longer detonates it. Kept as `tools/patches/tnt_destructive.patch` and re-applied by `fetch-addon.sh`, so the registry hash is still the original download's.

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
  - **2026-10-17:** God TNT (`destructive:tnt_god`) and God Dynamite (`destructive:dynamite_god`) are disabled in the unpacked pack. God TNT's chunk-erase job hangs the scripting watchdog and shuts the server down. `./fetch-addon.sh` overwrites this edit; re-apply it after a re-download.
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
| `tree_physics` | 1.0.2 (26.40) | 1 MB | **Disabled** (removed from `ADDONS[experimental]` 2026-10-17). Stock 1.0.2 doesn't run on BDS 1.26.52: it imports `EntitySwingSource` (`@minecraft/server` 2.8.0) and `CustomForm` etc. (`@minecraft/server-ui` 2.1.0), none of which exist here. `tools/patch-tree-physics.py` (applied automatically by `fetch-addon.sh`) stubs those so it loads, and in a test **trees did fall**, but fallen trees were **not breakable and could be walked through**, because breaking them needs `playerSwingStart`, which this server lacks. Retry after a BDS update. | Stable modules otherwise. Only affects **newly generated** trees. `packs.list` enables the main BP+RP only. The download stays in `addons/tree_physics`. |
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
- **Experimental (current world):** `blasters`, `tnt_destructive` + `orbital_railgun`, `portal_gun`, `quick_structures`, `immortal_dogs`, `serp_pokedrock`. None of these touch player.json. **Enabled 2026-10-12:** orbital_railgun, portal_gun, quick_structures (plus tornado_tnt, ours); a file/identifier overlap check found no conflicts. `tree_physics` was removed from this world on 2026-10-17 (see above).
- **Pokémon world:** `cobbledrock` alone. It's heavy and owns player.json. Start with `serp_pokedrock` in Experimental to see whether they like it first.
- **Heroes world:** `spiderman` (simpler), or `marvel` (bigger, needs the Education toggle, flips game modes).
- **Morph world:** `morphing_bracelet` on its own.
- **Rejected:** `pickup_carry` was deleted, and its project is blocked from being fetched again.

## Horror add-on (2026-10-18)

| Add-on | Version | Size | Verdict | Notes |
|---|---|---|---|---|
| `twixxel_stalkers` ([Twixxel's Stalkers](https://www.curseforge.com/minecraft-bedrock/addons/twixxels-stalkers-bedrock-edition), PnTMC, project 1567781 / file 9190816) | 3.0.0 | 47 MB | **Enabled in `horror` mode only** | The most-downloaded horror add-on on CurseForge Bedrock (2.6M), picked by download count since CurseForge's rating sort returns the same order. Stable modules (`@minecraft/server` 2.0.0, `server-ui` 2.0.0), no `eval`, no network, no `player.json` override, no experiments, ~8,000 lines of script. 21 entities (`pntmc:cave_stalker`, `evil_stalker`, `hole_stalker2`, `chicken_stalker`, ...); a test spawn worked. **Behaviour to know:** stalkers watch from windows and unexpected places, hide in beds, **break blocks** (`setblock ... air destroy`, which Land Claims can't stop), and the script flips `gamerule sendcommandfeedback` off and back on around one scare. Loaded with 0 errors. It's horror: not for the 7-year-olds' default world. |
| `the_bloop` ([The Bloop BE](https://www.curseforge.com/minecraft-bedrock/addons/the-bloop-be), Im_here_mc, project 1661921 / file 8723271) | 0.0.1 "(Experimental)" | 0.3 MB | **Enabled in `horror` mode only** | Data-only: one entity (`skinscraft:bloop`), a spawn rule, a resource pack. **No scripts**, no `player.json` override, `is_experimental` false, so the page's "experimental / may not work without Beta APIs" warning didn't apply (it works without experiments). A reskinned manatee scaled **16×** with **500 HP** and a **50-damage attack + Bad Omen** (one-shot kills a player). Spawns only in water in **forest biomes**, in herds of 1-2, density limit 5, so it's rare. Its `break_blocks` list names 15 kinds of **boats**, which aren't blocks, so each restart logs 15 harmless `Block type doesn't exist` errors and it can't smash boats. Test spawn/kill worked. License is All Rights Reserved, so it's kept out of git (only the registry entry is committed). |
