#!/usr/bin/env python3
"""Patch Tree Physics (addons/tree_physics) to run on BDS 1.26.52.

Tree Physics 1.0.x imports `EntitySwingSource` and subscribes to
`world.afterEvents.playerSwingStart`. This BDS's @minecraft/server 2.8.0 has neither,
so the whole script crashes at load (and its interaction_target block fails, because
its custom component never gets registered). Both are only used by the player
interaction controller (touch-screen breaking, contraption editing), not by tree felling.

The patch:
  1. drops EntitySwingSource from the @minecraft/server import and defines a local
     stand-in with the same member names
  2. subscribes to playerSwingStart only if the server has it
  3. the settings screen imports CustomForm / ObservableBoolean / ObservableNumber /
     DataDrivenScreenClosedReason from @minecraft/server-ui (2.1.0 doesn't export them).
     Those four are replaced with local stubs. Opening the settings screen throws
     (operator-only menu); the rest of the add-on is unaffected.

Idempotent. Re-run after `./fetch-addon.sh tree_physics ...` / `--all`, which overwrite
the files. Usage: python3 tools/patch-tree-physics.py
"""
import pathlib
import re
import sys

JS = pathlib.Path(__file__).resolve().parent.parent / "addons/tree_physics/packs/TreePhysicsBP/scripts/main.js"
MARK = "// [earles patch] EntitySwingSource stand-in"
MARK2 = "// [earles patch] server-ui stand-ins"
UI_STUBS = """
// [earles patch] server-ui stand-ins (not exported by @minecraft/server-ui 2.1.0)
class CustomForm {
  constructor() { throw new Error("Tree Physics settings screen isn't supported on this server"); }
}
const DataDrivenScreenClosedReason = { UserClosed: "UserClosed", UserBusy: "UserBusy", Unknown: "Unknown" };
class ObservableBoolean {
  constructor(v) { this._v = !!v; this._subs = []; }
  get value() { return this._v; }
  set value(v) { this._v = !!v; this._subs.forEach((f) => f(this._v)); }
  subscribe(f) { this._subs.push(f); return f; }
  unsubscribe(f) { this._subs = this._subs.filter((g) => g !== f); }
}
class ObservableNumber {
  constructor(v) { this._v = Number(v) || 0; this._subs = []; }
  get value() { return this._v; }
  set value(v) { this._v = Number(v) || 0; this._subs.forEach((f) => f(this._v)); }
  subscribe(f) { this._subs.push(f); return f; }
  unsubscribe(f) { this._subs = this._subs.filter((g) => g !== f); }
}
"""

src = JS.read_text(encoding="utf-8")
if MARK in src and MARK2 in src:
    print("already patched")
    sys.exit(0)

# 0. server-ui import -> stubs
ui = re.search(r'import \{[^}]*\} from "@minecraft/server-ui";\n', src)
if ui and "CustomForm" in ui.group(0) and MARK2 not in src:
    src = src[:ui.start()] + f"{MARK2}" + UI_STUBS + src[ui.end():]
    print("stubbed @minecraft/server-ui imports")

# 1. remove the import specifier and add a local stand-in right after that import block
if MARK not in src:
    imp = re.search(r'import \{([^}]*?)\n\s*EntitySwingSource,\n([^}]*)\} from "@minecraft/server";\n', src)
    if not imp:
        sys.exit("could not find the EntitySwingSource import - Tree Physics changed; patch needs updating")
    new_imp = (imp.group(0).replace("\n  EntitySwingSource,\n", "\n")
               + f'{MARK}\nconst EntitySwingSource = {{ Attack: "Attack", Build: "Build", Mine: "Mine", None: "None" }};\n')
    src = src[:imp.start()] + new_imp + src[imp.end():]

# 2. guard the swing event subscription
old = "world10.afterEvents.playerSwingStart.subscribe("
if src.count(old) == 1:
    src = src.replace(old, "world10.afterEvents.playerSwingStart?.subscribe(")
elif "playerSwingStart?.subscribe(" not in src:
    sys.exit("could not find the playerSwingStart subscription - patch needs updating")

JS.write_text(src, encoding="utf-8")
print("patched", JS)
