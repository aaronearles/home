// Owner Button & Owner Lever - written for the Earles server.
// Owner Lever: an orange lever only its owner can flip; while ON it powers redstone
// continuously (handle up + green knob), OFF = handle down + red knob.
// Owner Button: a bright orange button only its owner can press. Pressing powers redstone for 1.5 s,
// including strongly powering the block it's attached to (so it works through walls,
// like a vanilla button). Anyone else just gets told whose button it is.
// Only the owner can break it; explosions can't. Pairs with Land Claims to lock doors.
//
// Owner per button in this pack's world dynamic properties: btn:<dim>:<x>,<y>,<z> -> name
// Console admin (output in the server log):
//   scriptevent earles:button list
//   scriptevent earles:button place <x> <y> <z> <owner> [lever]   place one, attached to a neighbour
//   scriptevent earles:button press <x> <y> <z>           press a button / flip a lever (testing)
import { BlockPermutation, system, world } from "@minecraft/server";

const BUTTON = "earles:owner_button";
const PRESSED = "earles:pressed";
const LEVER = "earles:owner_lever";
const ON = "earles:on";
const OWNED = new Set([BUTTON, LEVER]);
const PULSE_TICKS = 30;   // 1.5 s, like a wooden button
// block_face = the clicked face of the wall block = direction pointing away from the wall
const AWAY = { north: [0, 0, -1], south: [0, 0, 1], east: [1, 0, 0], west: [-1, 0, 0], up: [0, 1, 0], down: [0, -1, 0] };

function tryRun(fn) {
    try { return fn(); } catch { return undefined; }
}

function keyAt(dimId, { x, y, z }) {
    return `btn:${dimId}:${x},${y},${z}`;
}

function ownerOf(block) {
    const v = tryRun(() => world.getDynamicProperty(keyAt(block.dimension.id, block.location)));
    return typeof v === "string" ? v : undefined;
}

function setOwner(block, name) {
    world.setDynamicProperty(keyAt(block.dimension.id, block.location), name);
}

function press(block) {
    if (block.permutation.getState(PRESSED)) return;
    const dim = block.dimension, loc = { ...block.location };
    tryRun(() => block.setPermutation(block.permutation.withState(PRESSED, true)));
    tryRun(() => dim.playSound("random.click", loc, { pitch: 1.2 }));
    system.runTimeout(() => {
        const b = tryRun(() => dim.getBlock(loc));
        if (b?.typeId !== BUTTON) return;
        // Re-place in the released state: only flipping the state doesn't tell
        // neighbouring redstone that the power went away (doors would stay open).
        const off = b.permutation.withState(PRESSED, false);
        tryRun(() => { b.setType("minecraft:air"); b.setPermutation(off); });
        tryRun(() => dim.playSound("random.click", loc, { pitch: 0.9 }));
    }, PULSE_TICKS);
}

function flip(block) {
    const dim = block.dimension, loc = { ...block.location };
    const turnOn = !block.permutation.getState(ON);
    const next = block.permutation.withState(ON, turnOn);
    // Turning on: a state change is enough. Turning off: re-place so neighbours notice
    // the power went away (same reason as the button release).
    tryRun(() => { if (!turnOn) block.setType("minecraft:air"); block.setPermutation(next); });
    tryRun(() => dim.playSound("random.click", loc, { pitch: turnOn ? 0.6 : 0.5 }));
}

function use(player, block) {
    const b = tryRun(() => block.dimension.getBlock(block.location));
    if (!b || !OWNED.has(b.typeId)) return;
    let owner = ownerOf(b);
    if (!owner) { owner = player.name; setOwner(b, owner); }   // placed by command: first user owns it
    if (owner === player.name) {
        if (b.typeId === LEVER) flip(b); else press(b);
    } else {
        const what = b.typeId === LEVER ? "lever" : "button";
        tryRun(() => player.onScreenDisplay.setActionBar(`§6This is ${owner}'s ${what}`));
        tryRun(() => b.dimension.playSound("note.bass", b.location, { volume: 0.4, pitch: 0.6 }));
    }
}

system.beforeEvents.startup.subscribe((ev) => {
    for (const id of OWNED) {
        ev.blockComponentRegistry.registerCustomComponent(id, {
            onPlayerInteract(e) {
                if (e.player) system.run(() => use(e.player, e.block));
            },
        });
    }
});

world.afterEvents.playerPlaceBlock.subscribe((ev) => {
    if (!OWNED.has(ev.block.typeId)) return;
    setOwner(ev.block, ev.player.name);
    const what = ev.block.typeId === LEVER ? "lever - only you can flip it" : "button - only you can press it";
    tryRun(() => ev.player.onScreenDisplay.setActionBar(`§6Your ${what}`));
});

world.beforeEvents.playerBreakBlock.subscribe((ev) => {
    if (!OWNED.has(ev.block.typeId)) return;
    const owner = ownerOf(ev.block);
    if (owner && owner !== ev.player.name) {
        ev.cancel = true;
        const what = ev.block.typeId === LEVER ? "lever" : "button";
        system.run(() => tryRun(() => ev.player.onScreenDisplay.setActionBar(`§c${owner}'s ${what} - you can't break it`)));
    }
});

world.afterEvents.playerBreakBlock.subscribe((ev) => {
    if (OWNED.has(ev.brokenBlockPermutation.type.id)) {
        tryRun(() => world.setDynamicProperty(keyAt(ev.block.dimension.id, ev.block.location), undefined));
    }
});

system.afterEvents.scriptEventReceive.subscribe((ev) => {
    if (ev.id !== "earles:button") return;
    const [cmd, ...rest] = ev.message.trim().split(/\s+/);
    const dim = world.getDimension("minecraft:overworld");
    if (cmd === "list" || !cmd) {
        const ids = world.getDynamicPropertyIds().filter((k) => k.startsWith("btn:"));
        console.warn(`[button] ${ids.length} button(s): ` + ids.map((k) => `${k.slice(4)}=${world.getDynamicProperty(k)}`).join("; "));
    } else if (cmd === "place") {
        const [x, y, z] = rest.slice(0, 3).map(Number);
        const isLever = rest[rest.length - 1] === "lever";
        const owner = rest.slice(3, isLever ? -1 : undefined).join(" ");
        if (!owner) return console.warn("[button] usage: place <x> <y> <z> <owner> [lever]");
        // Attach to the first solid neighbour, preferring walls over floor/ceiling
        for (const face of ["north", "south", "east", "west", "up", "down"]) {
            const [dx, dy, dz] = AWAY[face];
            const wall = tryRun(() => dim.getBlock({ x: x - dx, y: y - dy, z: z - dz }));
            if (wall && !wall.isAir && !wall.isLiquid) {
                const b = dim.getBlock({ x, y, z });
                b.setPermutation(isLever
                    ? BlockPermutation.resolve(LEVER, { "minecraft:block_face": face, [ON]: false })
                    : BlockPermutation.resolve(BUTTON, { "minecraft:block_face": face, [PRESSED]: false }));
                setOwner(b, owner);
                return console.warn(`[button] placed ${isLever ? "lever" : "button"} at ${x},${y},${z} on ${wall.typeId} (block_face=${face}), owner ${owner}`);
            }
        }
        console.warn(`[button] nothing solid next to ${x},${y},${z} to attach to`);
    } else if (cmd === "press") {
        const [x, y, z] = rest.map(Number);
        const b = tryRun(() => dim.getBlock({ x, y, z }));
        if (!b || !OWNED.has(b.typeId)) return console.warn(`[button] no button or lever at ${x},${y},${z}`);
        if (b.typeId === LEVER) flip(b); else press(b);
        console.warn(`[button] ${b.typeId === LEVER ? "flipped" : "pressed"} ${x},${y},${z}`);
    } else {
        console.warn("[button] usage: scriptevent earles:button list | place <x> <y> <z> <owner> [lever] | press <x> <y> <z>");
    }
});
