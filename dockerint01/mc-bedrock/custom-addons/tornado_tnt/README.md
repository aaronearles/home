# Tornado TNT (our own add-on)

Written 2026-10-12 for Henry and Theo. Block `earles:tornado_tnt`: a sky-blue TNT with a white band.

- **Get it:** search "Tornado" in the creative inventory (Items tab), or from the console run `give <player> earles:tornado_tnt 16`.
- **Light it:** flint and steel, a fire charge, or redstone power next to it. 3 s fuse, then a tornado.
- **What it does:**
  - It wanders across the ground for 30 s.
  - A smoke funnel spirals up 18 blocks.
  - It rips up surface blocks within 3 blocks (max ~30/s).
  - It sucks in mobs and players within 8 blocks, spins them, lifts them up to ~70% of the funnel height and throws them out.
  - Players get slow falling so they land safely; mobs take fall damage.
- **Limits:**
  - max 3 tornadoes at once (it says so in chat)
  - can't break bedrock, portals or command blocks
  - no item drops when `doTileDrops` is on (blocks just vanish); with drops off it uses `setblock … destroy` for break particles
- **Admin/test:** `scriptevent earles:tornado <x> <y> <z>` spawns one in the overworld without the fuse.

## Tuning

The constants at the top of `BP/scripts/main.js`: `LIFETIME_TICKS`, `SPEED`, `HEIGHT`, `PULL_RADIUS`, `BREAK_RADIUS`, `BLOCKS_PER_STEP`, `MAX_TORNADOES`. Lift and spin strength are in `step()` (`inward`, `swirl`, `up`).

After editing:
1. `./setup-addons.sh Experimental blasters tnt_destructive tornado_tnt`.
2. `docker compose exec -T minecraft send-command reload` reloads scripts without a restart. JSON/block/texture changes need a restart.
3. Check the server log for `[Scripting]` / `[Blocks]` errors.

## Gotchas found while building

- Block format `1.26.10` requires `minecraft:geometry` alongside `material_instances` (`minecraft:geometry.full_block`).
- A custom block's `getRedstonePower()` doesn't report power fed into it, so check the 6 neighbours.
- `applyImpulse` lift must beat gravity (~0.16 per 2-tick step) or mobs never rise.
- World edits from block callbacks are deferred with `system.run`.

Uses `@minecraft/server` 2.9.0 (stable): `system.beforeEvents.startup` + `blockComponentRegistry`. Textures are drawn with PIL; there are no vanilla assets in BDS.
