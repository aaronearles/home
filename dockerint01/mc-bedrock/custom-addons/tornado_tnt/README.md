# Tornado TNT (our own add-on)

Written 2026-10-12 for Henry and Theo. Block `earles:tornado_tnt`: a sky-blue TNT with a white band.

- **Get it:** search "Tornado" in the creative inventory (Items tab), or from the console run `give <player> earles:tornado_tnt 16`.
- **Light it:** flint and steel, a fire charge, or redstone power next to it. The block stays put and fizzes for a 3 s fuse, then becomes a tornado. It can't be lit twice.
- **What it does:**
  - It wanders across the ground for 30 s.
  - A funnel of big grey-brown cloud puffs (custom particle `earles:tornado_cloud`, in `RP/particles/`) rises 18 blocks in three twisting arms, with a dust skirt at the base.
  - It rips up surface blocks within 3 blocks (max ~30/s). ~60% of them fly as visible debris items that get caught in the funnel.
  - Debris is tagged `earles_tornado_debris`, removed after ~3.5 s, and capped at 40 at once. A 5 s sweep removes tagged debris that was flung into unloaded chunks once they reload. Manual cleanup: `kill @e[type=item,tag=earles_tornado_debris]`.
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

- Resource-pack changes (particles, textures) need a manifest **version bump** (now 1.1.0) so clients re-download, plus a server restart.
- Debris flung outside loaded chunks freezes there and can't be removed until the chunk loads, hence the tag + orphan sweep.
- The vanilla smoke particles (`basic_smoke_particle`) are too small and faint to read as a tornado. The custom billboard particle reuses the vanilla smoke flipbook at ~10× size.

- Block format `1.26.10` requires `minecraft:geometry` alongside `material_instances` (`minecraft:geometry.full_block`).
- A custom block's `getRedstonePower()` doesn't report power fed into it, so check the 6 neighbours.
- `applyImpulse` lift must beat gravity (~0.16 per 2-tick step) or mobs never rise.
- World edits from block callbacks are deferred with `system.run`.

Uses `@minecraft/server` 2.9.0 (stable): `system.beforeEvents.startup` + `blockComponentRegistry`. Textures are drawn with PIL; there are no vanilla assets in BDS.
