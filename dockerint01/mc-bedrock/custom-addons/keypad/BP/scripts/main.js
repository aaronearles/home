// PIN Keypad - written for the Earles server.
// Place it next to a door / piston / redstone line. The player who places it owns it and
// sets a 4-digit PIN. Anyone who enters the right PIN (4 sliders, controller-friendly - no
// on-screen keyboard) powers redstone for a few seconds. 3 wrong tries lock it for 10 s.
// Only the owner can break it; explosions can't.
//
// Settings are stored per keypad in this pack's world dynamic properties:
//   kp:<dimension>:<x>,<y>,<z>  ->  {"owner": "...", "pin": "1234" | null, "pulse": 3}
// Console admin (output in the server log):
//   scriptevent earles:keypad list
//   scriptevent earles:keypad reset <x> <y> <z>     forget the PIN (owner sets a new one)
//   scriptevent earles:keypad pulse <x> <y> <z> [s] power it as if the right PIN was entered
import { system, world } from "@minecraft/server";
import { ActionFormData, ModalFormData } from "@minecraft/server-ui";

const KEYPAD = "earles:keypad";
const POWERED = "earles:powered";
const MAX_TRIES = 3;
const LOCK_TICKS = 200;     // 10 s

const tries = new Map();    // key -> wrong attempts in a row
const lockedUntil = new Map();

function tryRun(fn) {
    try { return fn(); } catch { return undefined; }
}

function keyOf(block) {
    const { x, y, z } = block.location;
    return `kp:${block.dimension.id}:${x},${y},${z}`;
}

function getData(block) {
    const raw = tryRun(() => world.getDynamicProperty(keyOf(block)));
    return typeof raw === "string" ? JSON.parse(raw) : undefined;
}

function setData(block, data) {
    world.setDynamicProperty(keyOf(block), data ? JSON.stringify(data) : undefined);
}

function say(player, text) {
    tryRun(() => player.onScreenDisplay.setActionBar(text));
}

async function show(player, form) {
    for (let i = 0; i < 10; i++) {
        const r = await form.show(player);
        if (r.cancelationReason !== "UserBusy") return r;
        await new Promise((res) => system.runTimeout(res, 5));
    }
    return { canceled: true };
}

// 4 sliders, one per digit. Returns "1234" or undefined if cancelled.
async function askPin(player, title) {
    const f = new ModalFormData().title(title);
    for (const n of ["1st", "2nd", "3rd", "4th"]) f.slider(`${n} number`, 0, 9, { defaultValue: 0, valueStep: 1 });
    f.submitButton("Enter");
    const r = await show(player, f);
    if (r.canceled || !r.formValues) return undefined;
    return r.formValues.map((v) => String(v)).join("");
}

function pulse(block, seconds) {
    const dim = block.dimension, loc = { ...block.location };
    tryRun(() => block.setPermutation(block.permutation.withState(POWERED, true)));
    tryRun(() => dim.playSound("random.click", loc, { pitch: 1.4 }));
    system.runTimeout(() => {
        const b = tryRun(() => dim.getBlock(loc));
        if (b?.typeId !== KEYPAD) return;
        // Just flipping the state back doesn't tell neighbouring redstone that the power
        // went away (lamps/doors stay on). Re-placing the block forces neighbour updates.
        // Settings are keyed by location, so the PIN survives.
        const off = b.permutation.withState(POWERED, false);
        tryRun(() => { b.setType("minecraft:air"); b.setPermutation(off); });
    }, Math.round(seconds * 20));
}

async function setPin(player, block, data) {
    const pin = await askPin(player, "§6Choose a PIN");
    if (pin === undefined) return;
    const again = await askPin(player, "§6Enter it again");
    if (again === undefined) return;
    if (pin !== again) return player.sendMessage("§cThose didn't match - try again.");
    setData(block, { ...data, pin });
    player.sendMessage(`§aPIN set! Remember it: §l${pin}`);
}

async function enterPin(player, block, data) {
    const key = keyOf(block);
    if (system.currentTick < (lockedUntil.get(key) ?? 0)) {
        tryRun(() => block.dimension.playSound("note.bass", block.location));
        return say(player, "§cLocked - too many wrong tries. Wait a few seconds.");
    }
    const pin = await askPin(player, "§6Enter PIN");
    if (pin === undefined) return;
    const b = tryRun(() => block.dimension.getBlock(block.location));
    if (b?.typeId !== KEYPAD) return;
    if (pin === data.pin) {
        tries.delete(key);
        say(player, "§aCorrect!");
        pulse(b, data.pulse ?? 3);
    } else {
        const n = (tries.get(key) ?? 0) + 1;
        tries.set(key, n);
        tryRun(() => b.dimension.playSound("note.bass", b.location, { pitch: 0.5 }));
        if (n >= MAX_TRIES) {
            tries.delete(key);
            lockedUntil.set(key, system.currentTick + LOCK_TICKS);
            say(player, "§cWrong PIN - locked for 10 seconds.");
        } else {
            say(player, `§cWrong PIN (${MAX_TRIES - n} tries left)`);
        }
    }
}

async function ownerMenu(player, block, data) {
    const r = await show(player, new ActionFormData()
        .title("§6Your keypad")
        .body(`PIN: §l${data.pin}§r   Stays on for: ${data.pulse ?? 3} s`)
        .button("§2Open")
        .button("Change PIN")
        .button("How long it stays on")
        .button("Try the PIN like a visitor"));
    if (r.canceled) return;
    if (r.selection === 0) pulse(block, data.pulse ?? 3);
    else if (r.selection === 1) await setPin(player, block, data);
    else if (r.selection === 2) {
        const f = await show(player, new ModalFormData().title("Stays on for")
            .slider("Seconds", 1, 10, { defaultValue: data.pulse ?? 3, valueStep: 1 }).submitButton("Save"));
        if (!f.canceled && f.formValues) {
            setData(block, { ...data, pulse: Number(f.formValues[0]) });
            player.sendMessage(`§aIt now stays on for ${f.formValues[0]} s.`);
        }
    } else if (r.selection === 3) await enterPin(player, block, data);
}

async function onUse(player, block) {
    let data = getData(block);
    if (!data) {   // placed before tracking, or by a command: first user becomes the owner
        data = { owner: player.name, pin: null, pulse: 3 };
        setData(block, data);
    }
    if (!data.pin) {
        if (data.owner === player.name) return setPin(player, block, data);
        return say(player, `§e${data.owner} hasn't set a PIN yet.`);
    }
    if (data.owner === player.name) return ownerMenu(player, block, data);
    return enterPin(player, block, data);
}

system.beforeEvents.startup.subscribe((ev) => {
    ev.blockComponentRegistry.registerCustomComponent(KEYPAD, {
        onPlayerInteract(e) {
            if (e.player) system.run(() => onUse(e.player, e.block).catch(() => {}));
        },
    });
});

world.afterEvents.playerPlaceBlock.subscribe((ev) => {
    if (ev.block.typeId !== KEYPAD) return;
    setData(ev.block, { owner: ev.player.name, pin: null, pulse: 3 });
    say(ev.player, "§6Use the keypad to set its PIN");
});

world.beforeEvents.playerBreakBlock.subscribe((ev) => {
    if (ev.block.typeId !== KEYPAD) return;
    const data = getData(ev.block);
    if (data && data.owner !== ev.player.name) {
        ev.cancel = true;
        system.run(() => say(ev.player, `§c${data.owner}'s keypad - you can't break it`));
    }
});

world.afterEvents.playerBreakBlock.subscribe((ev) => {
    if (ev.brokenBlockPermutation.type.id === KEYPAD) tryRun(() => setData(ev.block, undefined));
});

system.afterEvents.scriptEventReceive.subscribe((ev) => {
    if (ev.id !== "earles:keypad") return;
    const [cmd, ...rest] = ev.message.trim().split(/\s+/);
    if (cmd === "list" || !cmd) {
        const ids = world.getDynamicPropertyIds().filter((k) => k.startsWith("kp:"));
        console.warn(`[keypad] ${ids.length} keypad(s): ` + ids.map((k) => `${k.slice(3)} ${world.getDynamicProperty(k)}`).join("; "));
    } else if (cmd === "reset") {
        const [x, y, z] = rest.map(Number);
        const k = `kp:minecraft:overworld:${x},${y},${z}`;
        const raw = world.getDynamicProperty(k);
        if (typeof raw !== "string") return console.warn(`[keypad] no keypad at ${x},${y},${z}`);
        world.setDynamicProperty(k, JSON.stringify({ ...JSON.parse(raw), pin: null }));
        console.warn(`[keypad] PIN cleared at ${x},${y},${z}; the owner sets a new one on next use`);
    } else if (cmd === "pulse") {
        // Test/admin: act as if the right PIN was entered at <x> <y> <z>
        const [x, y, z] = rest.map(Number);
        const b = tryRun(() => world.getDimension("minecraft:overworld").getBlock({ x, y, z }));
        if (b?.typeId !== KEYPAD) return console.warn(`[keypad] no keypad at ${x},${y},${z}`);
        pulse(b, Number(rest[3]) || 3);
        console.warn(`[keypad] pulsed ${x},${y},${z}`);
    } else {
        console.warn("[keypad] usage: scriptevent earles:keypad list | reset <x> <y> <z> | pulse <x> <y> <z> [seconds]");
    }
});
