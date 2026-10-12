# Land Claims (our own add-on)

Written 2026-10-12. Each player can claim up to **3** squares of **32×32**, from **bedrock to the sky**. Others can't change claimed land unless the owner trusts them. Enabled in **experimental** and **creative** modes.

## Using it
- **Get the Claim Flag** (gold/red flag): creative inventory (search "Claim Flag"), or from the console `give <player> earles:claim_flag`.
- **Use it** (LT on Xbox / tap-hold on iPhone) to open the menu:
  - **Claim land here:** 32×32 centred on you. It can't overlap another claim, and green sparkles show the border for 10 s.
  - **Claim land here + stone wall** / **Build stone wall** (on your own claim): a ring of cobblestone walls, **2 high**, **5 blocks inside the edge**, following the terrain.
    - Why it's inside the edge: walking into a claim isn't blocked, so without a wall someone could pillar up just outside the edge and jump in. With the wall 5 blocks in, they'd have to stand inside the claim to get over it, and there they can't place blocks.
    - Walls replace grass, plants and leaves, go under tree canopies, and leave existing solid blocks (your house) alone.
    - Water columns are skipped (no walls underwater), so lake edges stay open.
    - To make a gate, break a piece; only the owner and trusted players can.
  - **Show borders**
  - **Remove this claim** (with confirmation)
  - **Trust a player / Stop trusting:** a trusted player can build on **all** of your land.
  - **Where are my claims?**
- **Walking in or out** shows "Entering Henry's land" / "Leaving claimed land" above the hotbar.

## What's protected inside someone else's claim
- Breaking blocks
- Placing blocks, buckets, flint and steel
- Opening chests, doors, buttons. Everything that starts as "use on a block" is blocked; the check covers both the clicked block and the spot a block would go into.
- Explosions: vanilla TNT, creepers, and add-on explosives that use real explosions skip claimed blocks. Tested: TNT on a claim edge destroyed 3 blocks outside, 0 inside.
- **Tornado TNT** won't rip up claimed land (it reads the same registry). Tested: 0 blocks inside, 7 outside.

## Known gaps (can't be blocked by a script add-on)
- **Orbital Railgun** and some **TNT Destructive** types edit blocks directly with commands or scripts, not real explosions, so they **may still damage claims**.
- **Quick Craft** structures placed overlapping a claim.
- Fire spreading in, lava/water flowing in from outside, pistons, mob griefing (endermen).
- **The wall stops walking, not everything:** ender pearls, elytra, or a very tall pillar plus a sprint-jump can still get over. Walls skip water.
- Claims belong to a **gamertag**: if Theo plays as `aearles`, he's using aearles's claims.

## Admin (server console; output appears in the server log as `[Scripting] [claims] ...`)
```
scriptevent earles:claims list
scriptevent earles:claims remove <id>
scriptevent earles:claims removeall <owner>
scriptevent earles:claims wall <id>        # build the stone wall on a claim
scriptevent earles:claims unwall <id>      # remove it (only cobblestone walls on the ring)
scriptevent earles:claims probe <x> <z>    # debug: what the wall builder sees as ground
```
Note: `fill ... replace cobblestone_wall` from the console misses walls that have connected to each other (different block state), so use `unwall` to remove walls.

## How it's stored
Claims are kept in the scoreboard objective `earles_claims` as fake-player names, because the scoreboard is the one piece of world state every add-on can read:
- `c|<id>|<dimension>|<x1>|<z1>|<x2>|<z2>|<owner>` is a claim (inclusive bounds)
- `t|<owner>|<name>,<name>` is the owner's trust list

Claims are per world (each world has its own scoreboard). Script lookups are read-only because before-events can't change the world; the objective is created on the first tick.

Uses `@minecraft/server` 2.9.0 and `@minecraft/server-ui` 2.1.0. Item format copied from Quick Craft's hammer (`use_modifiers.use_duration: 0` makes `itemUse` fire immediately).
