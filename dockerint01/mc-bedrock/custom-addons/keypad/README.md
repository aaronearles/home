# PIN Keypad (our own add-on)

Written 2026-10-12. Block `earles:keypad`: a grey keypad block that powers redstone (doors, pistons, lamps, dust) for a few seconds when the right 4-digit PIN is entered. Enabled in **experimental** and **creative** modes.

## Using it
- **Get it:** search "PIN Keypad" in the creative inventory, or from the console `give <player> earles:keypad`.
- **Place it** next to an iron door, piston or redstone line. The player who places it **owns** it.
- **Owner's first use** asks for the PIN twice.
- **PIN entry:** a menu with **4 sliders (0–9)** and an Enter button. It's controller-friendly and doesn't pop up the on-screen keyboard, so it works on split-screen Xbox.
- **Visitors:**
  - The right PIN gives a click sound, the keypad glows green and powers redstone for the pulse length (default 3 s).
  - A wrong PIN gives a buzzer. 3 wrong tries lock it for 10 s.
- **Owner menu:** Open (no PIN needed), Change PIN, How long it stays on (1–10 s), and Try the PIN like a visitor.
- **Only the owner can break it.** Explosions can't.

## How the redstone works
The block has a state `earles:powered`. Its "on" permutation adds `minecraft:redstone_producer` (power 15 on all faces, strongly powering the block below), which works on BDS 1.26.52 without experiments. When the pulse ends, the script **re-places** the block in its off state: just flipping the state back doesn't notify neighbours, so lamps and doors would stay on.

Tested:
- an adjacent lamp and a lamp through redstone dust light up
- an iron door opens during the pulse and closes after

## Storage and admin
Per keypad, in this pack's world dynamic properties: `kp:<dimension>:<x>,<y>,<z>` = `{"owner","pin","pulse"}`. The PIN is plain text (it's for kids' doors, not a bank). A keypad placed by command gets the first player who uses it as owner.

```
scriptevent earles:keypad list                       # all keypads with owner/PIN (server log)
scriptevent earles:keypad reset <x> <y> <z>          # forget the PIN; the owner sets a new one
scriptevent earles:keypad pulse <x> <y> <z> [secs]   # power it as if the PIN was entered (testing)
```

Uses `@minecraft/server` 2.9.0 and `@minecraft/server-ui` 2.1.0.
