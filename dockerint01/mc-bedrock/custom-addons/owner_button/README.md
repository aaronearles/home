# Owner Button & Owner Lever (our own add-on)

Written 2026-10-12. It replaces the PIN Keypad: the PIN menu showed on screen, so it wasn't private on split-screen. Block `earles:owner_button` is a **bright orange button** that **only its owner can press**. Enabled in **experimental** and **creative** modes. Best used inside a Land Claim, so nobody can dig around the door instead.

## Owner Lever (`earles:owner_lever`, added 2026-10-12)
- **Looks:** an orange base with a handle. **Off** = handle down + red knob, **on** = handle up + green knob.
- **Only the owner can flip it.** While ON it powers redstone **continuously** and strongly powers the block it's on, so doors stay open and lights stay on until the owner flips it off.
- Same placement (walls, floor, ceiling), owner-only breaking and explosion-proofing as the button.
- **Models:** the 12 geometries (6 faces × off/on) are **generated** from one canonical model (wall on +z) by rotating about the cell centre. See the generator notes in git history (2026-10-12 commit) if it needs changing.
- **Tested:**
  - flipping it ON opens an iron door through a stone wall, and the door is still open 3 s later
  - flipping it OFF closes the door

## Using the button
- **Get it:** search "Owner Button" in the creative inventory, or from the console `give <player> earles:owner_button`.
- **Place it** like a vanilla button, on a wall, floor or ceiling. Whoever places it owns it.
- **The owner presses it:** a click, it darkens, and redstone is powered for **1.5 s**. Like a vanilla button, it also **strongly powers the block it's attached to**, so a door on the other side of the wall opens too.
- **Anyone else** gets "This is Henry's button" and nothing happens.
- **Only the owner can break it.** Explosions can't.

## How it works
- **Orientation:** the `minecraft:placement_position` trait gives `minecraft:block_face`, the face that was clicked, pointing away from the wall. There are 6 permutations, each with its own geometry (`RP/models/blocks/button_<face>.geo.json`) and selection box, and no collision.
- **Power:** a pressed permutation adds `minecraft:redstone_producer` (power 15, strongly powering the face toward the wall). Releasing **re-places** the block, because just flipping the state doesn't notify neighbouring redstone.
- **Tested:**
  - an iron door through a stone wall opens when pressed and closes 1.5 s later
  - a floor button next to a door does the same

## Admin (server log output)
```
scriptevent earles:button list                          # all buttons and owners
scriptevent earles:button place <x> <y> <z> <owner> [lever]   # place a button (or lever); attaches to a solid neighbour
scriptevent earles:button press <x> <y> <z>                   # press a button / flip a lever (testing)
```
Owners are stored per button in this pack's dynamic properties: `btn:<dimension>:<x>,<y>,<z>` = owner gamertag. A button placed by a plain `setblock` gets its first presser as owner.
