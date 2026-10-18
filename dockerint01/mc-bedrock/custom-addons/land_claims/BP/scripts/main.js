// Land Claims - written for the Earles server.
// Use the Claim Flag to claim a 32x32 square around you, from bedrock to the sky.
// Inside someone else's claim you can't break, place or use blocks (incl. buckets,
// chests, doors) unless the owner trusts you, and explosions don't damage claimed land.
//
// Claims live in the scoreboard objective "earles_claims" as fake-player names, because
// the scoreboard is the one piece of world state every add-on can read (Tornado TNT uses
// it to skip claimed land). Formats:
//   c|<id>|<dimension>|<x1>|<z1>|<x2>|<z2>|<owner>     a claim (inclusive bounds)
//   t|<owner>|<name>,<name>,...                        players the owner trusts
//
// Console admin (output goes to the server log as [Scripting] warnings):
//   scriptevent earles:claims list
//   scriptevent earles:claims remove <id>
//   scriptevent earles:claims removeall <owner>
//   scriptevent earles:claims wall <id>                build the stone wall on a claim
//   scriptevent earles:claims unwall <id>              remove that wall (cobblestone walls on the ring only)
//   scriptevent earles:claims probe <x> <z>            debug: what the wall builder sees as ground there
//   scriptevent earles:claims skybox <player>         5x5x5 bulletproof-glass box, 50 blocks above that player
//   scriptevent earles:claims book <player[,player...]> <enchantment> [level]
//                                                      give an enchanted book, e.g. book henry,theo feather_falling 4
//                                                      (nicknames work; the level must be allowed for that enchantment)
//   scriptevent earles:claims clearglass              remove every skybox built since boxes were recorded
//   scriptevent earles:claims clearglass <x1> <y1> <z1> <x2> <y2> <z2> [dimension]
//                                                      remove bulletproof glass in that region (overworld by default;
//                                                      use for hand-placed glass and older skyboxes)
//
// earles:bulletproof_glass looks like vanilla glass. It is not in the creative inventory,
// not mineable, and not destroyed by explosions. Players can't break or place it; the
// console places it with skybox (or fill / setblock) and removes it with fill ... air.
import { EnchantmentType, ItemStack, system, world } from "@minecraft/server";
import { ActionFormData, ModalFormData } from "@minecraft/server-ui";

const OBJECTIVE = "earles_claims";
const SIZE = 32;              // claim is SIZE x SIZE blocks
const MAX_PER_PLAYER = 3;
const FLAG = "earles:claim_flag";
const GLASS = "earles:bulletproof_glass";
const SKYBOX_ABOVE = 50;      // blocks above the player's feet
// Console nicknames for skybox. Gamertags always work too.
const PLAYER_ALIASES = { henry: "hcearles", theo: "ttearles", dad: "aearles" };
const WALL_INSET = 5;         // stone wall this many blocks inside the claim edge
const WALL_HEIGHT = 2;        // min blocks above the ground (cobblestone + wall cap; can't be jumped)
const WALL_BLOCK = "minecraft:cobblestone_wall";
// Blocks the wall may replace / looks through when finding the ground
const SOFT = /^minecraft:(cave_)?air$|grass$|short_grass|tall_grass|fern|flower|dandelion|poppy|tulip|orchid|allium|bluet|daisy|cornflower|lily_of_the_valley|sapling|bush|dead_bush|snow_layer|vine|leaves|leaf_litter|mushroom$|sweet_berry|azalea$|pink_petals|wildflowers|seagrass|kelp/;
const PASS_THROUGH = /^minecraft:(cave_)?air$|leaves|log|_wood$|vine|snow_layer|leaf_litter|grass$|short_grass|tall_grass|fern|flower|bush|sapling/;
const FACE = { Up: [0, 1, 0], Down: [0, -1, 0], North: [0, 0, -1], South: [0, 0, 1], East: [1, 0, 0], West: [-1, 0, 0] };

let claims = null;            // cache: [{ id, dim, x1, z1, x2, z2, owner }]
let trust = null;             // cache: { owner: Set(names) }

function tryRun(fn) {
    try { return fn(); } catch { return undefined; }
}

// Creating the objective is a world change, which isn't allowed inside before-events,
// so it's created on the first tick and lookups never create it.
function objective(create = false) {
    const o = world.scoreboard.getObjective(OBJECTIVE);
    return o ?? (create ? world.scoreboard.addObjective(OBJECTIVE, "Land Claims") : undefined);
}

function load() {
    claims = [];
    trust = {};
    for (const p of objective()?.getParticipants() ?? []) {
        const parts = p.displayName.split("|");
        if (parts[0] === "c" && parts.length >= 8) {
            const [, id, dim, x1, z1, x2, z2, ...owner] = parts;
            claims.push({ id: Number(id), dim, x1: Number(x1), z1: Number(z1), x2: Number(x2), z2: Number(z2), owner: owner.join("|") });
        } else if (parts[0] === "t" && parts.length >= 3) {
            trust[parts[1]] = new Set(parts[2].split(",").filter(Boolean));
        }
    }
}

function getClaims() {
    if (!claims) load();
    return claims;
}

function claimKey(c) {
    return `c|${c.id}|${c.dim}|${c.x1}|${c.z1}|${c.x2}|${c.z2}|${c.owner}`;
}

function addClaim(c) {
    objective(true).setScore(claimKey(c), 1);
    load();
}

function removeClaim(c) {
    tryRun(() => objective()?.removeParticipant(claimKey(c)));
    load();
}

function setTrust(owner, names) {
    const obj = objective(true);
    for (const p of obj.getParticipants()) {
        if (p.displayName.startsWith(`t|${owner}|`)) tryRun(() => obj.removeParticipant(p));
    }
    if (names.size) obj.setScore(`t|${owner}|${[...names].join(",")}`, 1);
    load();
}

function claimAt(dimId, x, z) {
    x = Math.floor(x); z = Math.floor(z);
    return getClaims().find((c) => c.dim === dimId && x >= c.x1 && x <= c.x2 && z >= c.z1 && z <= c.z2);
}

function canBuild(name, claim) {
    if (!claim || claim.owner === name) return true;
    if (!trust) load();
    return trust[claim.owner]?.has(name) ?? false;
}

function deny(player, claim) {
    system.run(() => tryRun(() => player.onScreenDisplay.setActionBar(`§c${claim.owner}'s land - you can't change it`)));
}

// ---- Protection -----------------------------------------------------------------

world.beforeEvents.playerBreakBlock.subscribe((ev) => {
    if (ev.block.typeId === GLASS) {
        ev.cancel = true;
        system.run(() => tryRun(() => ev.player.onScreenDisplay.setActionBar("§cBulletproof glass")));
        return;
    }
    const claim = claimAt(ev.block.dimension.id, ev.block.location.x, ev.block.location.z);
    if (!canBuild(ev.player.name, claim)) {
        ev.cancel = true;
        deny(ev.player, claim);
    }
});

// Placing blocks, buckets, flint and steel, chests, doors, buttons... all start as an
// interaction with a block. Check the clicked block and the spot a block would go into.
// This server's @minecraft/server has no playerPlaceBlock before-event, so holding the
// glass is rejected here. That keeps a picked-up stack from being placed.
world.beforeEvents.playerInteractWithBlock.subscribe((ev) => {
    if (ev.itemStack?.typeId === GLASS) {
        ev.cancel = true;
        system.run(() => tryRun(() => ev.player.onScreenDisplay.setActionBar("§cBulletproof glass is admin-only")));
        return;
    }
    if (ev.itemStack?.typeId === FLAG) return;
    const { x, y, z } = ev.block.location;
    const [dx, , dz] = FACE[ev.blockFace] ?? [0, 0, 0];
    const dim = ev.block.dimension.id;
    for (const c of [claimAt(dim, x, z), claimAt(dim, x + dx, z + dz)]) {
        if (!canBuild(ev.player.name, c)) {
            ev.cancel = true;
            deny(ev.player, c);
            return;
        }
    }
});

// Explosions (TNT, creepers, add-on explosives) skip claimed blocks and bulletproof glass.
world.beforeEvents.explosion.subscribe((ev) => {
    const dimId = ev.dimension.id;
    const claimsHere = getClaims().some((c) => c.dim === dimId);
    let blocks;
    try { blocks = ev.getImpactedBlocks(); } catch { return; }
    const keep = blocks.filter((b) => b.typeId !== GLASS && !(claimsHere && claimAt(dimId, b.location.x, b.location.z)));
    if (keep.length !== blocks.length) ev.setImpactedBlocks(keep);
});

// ---- Enter / leave messages ----------------------------------------------------------

const lastClaim = new Map();   // player name -> claim id or -1
system.runInterval(() => {
    for (const p of world.getAllPlayers()) {
        const c = claimAt(p.dimension.id, p.location.x, p.location.z);
        const id = c ? c.id : -1;
        const prev = lastClaim.get(p.name) ?? -1;
        if (id !== prev) {
            lastClaim.set(p.name, id);
            if (c) {
                const who = c.owner === p.name ? "your" : `${c.owner}'s`;
                const extra = canBuild(p.name, c) ? "" : " §7(look, don't touch)";
                tryRun(() => p.onScreenDisplay.setActionBar(`§aEntering ${who} land${extra}`));
            } else if (prev !== -1) {
                tryRun(() => p.onScreenDisplay.setActionBar("§7Leaving claimed land"));
            }
        }
    }
}, 10);

// Create the objective on the first tick, then refresh the cache now and then (console edits)
system.run(() => tryRun(() => { objective(true); load(); }));
system.runInterval(() => tryRun(load), 200);

// ---- Claim Flag menu -----------------------------------------------------------------

async function show(player, form) {
    for (let i = 0; i < 10; i++) {
        const r = await form.show(player);
        if (r.cancelationReason !== "UserBusy") return r;
        await new Promise((res) => system.runTimeout(res, 5));
    }
    return { canceled: true };
}

// Ground at (x, z): scanning down from the topmost block, the first block that isn't air,
// leaves, a trunk or a plant (so walls go on the terrain, not on tree tops).
function groundAt(dim, x, z) {
    const top = tryRun(() => dim.getTopmostBlock({ x, z }));
    if (!top) return undefined;
    for (let y = top.location.y; y > top.location.y - 40; y--) {
        const b = tryRun(() => dim.getBlock({ x, y, z }));
        if (!b) return undefined;
        if (!PASS_THROUGH.test(b.typeId)) return y;
    }
    return undefined;
}

// The wall ring as a closed loop (order matters for smoothing): top edge, right edge,
// bottom edge (backwards), left edge (backwards).
function wallRing(c) {
    const x1 = c.x1 + WALL_INSET, z1 = c.z1 + WALL_INSET, x2 = c.x2 - WALL_INSET, z2 = c.z2 - WALL_INSET;
    const ring = [];
    for (let x = x1; x <= x2; x++) ring.push([x, z1]);
    for (let z = z1 + 1; z <= z2; z++) ring.push([x2, z]);
    for (let x = x2 - 1; x >= x1; x--) ring.push([x, z2]);
    for (let z = z2 - 1; z > z1; z--) ring.push([x1, z]);
    return ring;
}

const WALL_BASE = "minecraft:cobblestone";   // solid fill under the cap where the wall stands taller
const MAX_RISE = 10;                        // never more than this above local ground (ravines)
let lastWallStats = "";

function wallKey(c) {
    return `wall:${c.id}`;
}

// Remove the claim's wall: exactly the blocks we placed (recorded), or - for walls built
// before recording existed - any cobblestone walls on the ring columns.
function removeWall(dim, c) {
    let removed = 0;
    const rec = tryRun(() => world.getDynamicProperty(wallKey(c)));
    if (typeof rec === "string") {
        for (const [x, y, z] of JSON.parse(rec)) {
            const b = tryRun(() => dim.getBlock({ x, y, z }));
            if (b && (b.typeId === WALL_BLOCK || b.typeId === WALL_BASE)) { tryRun(() => b.setType("minecraft:air")); removed++; }
        }
        tryRun(() => world.setDynamicProperty(wallKey(c), undefined));
        return removed;
    }
    for (const [x, z] of wallRing(c)) {
        const top = tryRun(() => dim.getTopmostBlock({ x, z }));
        if (!top) continue;
        for (let y = top.location.y; y > top.location.y - 48; y--) {
            const b = tryRun(() => dim.getBlock({ x, y, z }));
            if (b?.typeId === WALL_BLOCK) { tryRun(() => b.setType("minecraft:air")); removed++; }
        }
    }
    return removed;
}

// Water surface above a column's ground, or undefined if it's dry
function waterSurface(dim, x, z, g) {
    let y = g + 1, wet = false;
    for (; y < g + 64; y++) {
        const t = tryRun(() => dim.getBlock({ x, y, z })?.typeId);
        if (t === "minecraft:water" || t === "minecraft:flowing_water") wet = true; else break;
    }
    return wet ? y - 1 : undefined;
}

// A ring of stone wall WALL_INSET blocks inside the claim, with a SMOOTH top line:
//  1. measure the ground under every ring column
//  2. target top = ground + WALL_HEIGHT, then relax around the loop so neighbouring tops
//     differ by at most 1 block (dips are raised to meet their neighbours, never lowered,
//     so the wall is always at least WALL_HEIGHT above its own ground)
//  3. build cobblestone up from the ground with a cobblestone-wall cap on top
// Water columns follow the water surface for smoothing but get no blocks (no walls in lakes).
// Rebuilding replaces the previous wall. Every placed block is recorded for clean removal.
function buildWall(dim, c) {
    removeWall(dim, c);
    const ring = wallRing(c);
    const n = ring.length;
    const ground = new Array(n), wet = new Array(n).fill(false);
    let last;
    for (let i = 0; i < n; i++) {
        const [x, z] = ring[i];
        let g = groundAt(dim, x, z);
        if (g !== undefined) {
            const w = waterSurface(dim, x, z, g);
            if (w !== undefined) { wet[i] = true; g = w; }
        }
        ground[i] = g ?? last;
        if (ground[i] !== undefined) last = ground[i];
    }
    for (let i = 0; i < n; i++) ground[i] ??= last ?? 64;    // fill any leading unknowns

    const top = ground.map((g) => g + WALL_HEIGHT);
    for (let changed = true, guard = 0; changed && guard < 200; guard++) {
        changed = false;
        for (let i = 0; i < n; i++) {
            const want = Math.min(Math.max(top[i], top[(i + n - 1) % n] - 1, top[(i + 1) % n] - 1), ground[i] + MAX_RISE);
            if (want !== top[i]) { top[i] = want; changed = true; }
        }
    }

    const placed = [];
    for (let i = 0; i < n; i++) {
        if (wet[i]) continue;
        const [x, z] = ring[i];
        for (let y = ground[i] + 1; y <= top[i]; y++) {
            const b = tryRun(() => dim.getBlock({ x, y, z }));
            if (!b || !SOFT.test(b.typeId)) continue;
            if (tryRun(() => { b.setType(y === top[i] ? WALL_BLOCK : WALL_BASE); return true; })) placed.push([x, y, z]);
        }
    }
    tryRun(() => world.setDynamicProperty(wallKey(c), JSON.stringify(placed)));
    let maxStep = 0, minAbove = Infinity, maxAbove = 0;
    for (let i = 0; i < n; i++) {
        maxStep = Math.max(maxStep, Math.abs(top[i] - top[(i + 1) % n]));
        minAbove = Math.min(minAbove, top[i] - ground[i]);
        maxAbove = Math.max(maxAbove, top[i] - ground[i]);
    }
    lastWallStats = `columns=${n} wet=${wet.filter(Boolean).length} ground=${Math.min(...ground)}..${Math.max(...ground)} ` +
        `top=${Math.min(...top)}..${Math.max(...top)} maxStep=${maxStep} heightAboveGround=${minAbove}..${maxAbove}`;
    return placed.length;
}

function showBorder(dim, c, y) {
    let t = 0;
    const id = system.runInterval(() => {
        t += 10;
        for (let i = 0; i <= SIZE; i += 2) {
            for (const [x, z] of [[c.x1 + i, c.z1], [c.x1 + i, c.z2 + 1], [c.x1, c.z1 + i], [c.x2 + 1, c.z1 + i]]) {
                tryRun(() => dim.spawnParticle("minecraft:villager_happy", { x, y: y + 1, z }));
            }
        }
        if (t >= 200) system.clearRun(id);
    }, 10);
}

async function menu(player) {
    const name = player.name;
    const dim = player.dimension;
    const here = claimAt(dim.id, player.location.x, player.location.z);
    const mine = getClaims().filter((c) => c.owner === name);
    const trusted = [...(trust?.[name] ?? [])];

    const where = here ? (here.owner === name ? "You're on §ayour§r land." : `You're on §e${here.owner}'s§r land.`) : "This land is §7unclaimed§r.";
    const form = new ActionFormData()
        .title("§6Land Claims")
        .body(`${where}\nYou have ${mine.length}/${MAX_PER_PLAYER} claims.\nTrusted: ${trusted.length ? trusted.join(", ") : "nobody"}`);
    const actions = [];
    if (!here) { form.button(`§2Claim land here\n§r${SIZE}×${SIZE}, bedrock to sky`); actions.push("claim"); }
    if (!here) { form.button(`§2Claim land here + stone wall\n§r${WALL_INSET} blocks inside the edge`); actions.push("claim_wall"); }
    if (here) { form.button("Show borders"); actions.push("border"); }
    if (here?.owner === name) { form.button(`Build stone wall\n§r${WALL_INSET} blocks inside the edge`); actions.push("wall"); }
    if (here?.owner === name) { form.button("§cRemove this claim"); actions.push("remove"); }
    form.button("Trust a player"); actions.push("trust");
    if (trusted.length) { form.button("Stop trusting a player"); actions.push("untrust"); }
    form.button("Where are my claims?"); actions.push("list");

    const r = await show(player, form);
    if (r.canceled || r.selection === undefined) return;
    const action = actions[r.selection];

    if (action === "claim" || action === "claim_wall") {
        if (mine.length >= MAX_PER_PLAYER) return player.sendMessage(`§cYou already have ${MAX_PER_PLAYER} claims. Remove one first.`);
        const x1 = Math.floor(player.location.x) - SIZE / 2, z1 = Math.floor(player.location.z) - SIZE / 2;
        const c = { id: Math.max(0, ...getClaims().map((k) => k.id)) + 1, dim: dim.id, x1, z1, x2: x1 + SIZE - 1, z2: z1 + SIZE - 1, owner: name };
        const clash = getClaims().find((k) => k.dim === c.dim && k.x1 <= c.x2 && k.x2 >= c.x1 && k.z1 <= c.z2 && k.z2 >= c.z1);
        if (clash) return player.sendMessage(`§cToo close to ${clash.owner === name ? "your other" : clash.owner + "'s"} land - move a bit further away.`);
        addClaim(c);
        lastClaim.set(name, c.id);
        player.sendMessage(`§aClaimed! ${SIZE}×${SIZE} from (${c.x1}, ${c.z1}) to (${c.x2}, ${c.z2}), bedrock to sky.`);
        showBorder(dim, c, Math.floor(player.location.y));
        if (action === "claim_wall") {
            const n = buildWall(dim, c);
            player.sendMessage(`§aBuilt a stone wall (${n} blocks) ${WALL_INSET} blocks inside the edge. Break a piece to make a gate - only you can.`);
        }
    } else if (action === "wall") {
        const n = buildWall(dim, here);
        player.sendMessage(`§aBuilt a stone wall (${n} blocks) ${WALL_INSET} blocks inside the edge. Building it again replaces it.`);
    } else if (action === "border") {
        showBorder(dim, here, Math.floor(player.location.y));
    } else if (action === "remove") {
        const ok = await show(player, new ActionFormData().title("§cRemove claim?")
            .body("Anyone will be able to change this land again.").button("§cYes, remove it").button("Cancel"));
        if (!ok.canceled && ok.selection === 0) { removeWall(dim, here); removeClaim(here); player.sendMessage("§eClaim (and its wall) removed."); }
    } else if (action === "trust") {
        const others = world.getAllPlayers().map((p) => p.name).filter((n) => n !== name && !trusted.includes(n));
        if (!others.length) return player.sendMessage("§eNobody else is online to trust right now.");
        const f = await show(player, new ModalFormData().title("Trust a player")
            .dropdown("They can build on all your land:", others));
        if (f.canceled || !f.formValues) return;
        const who = others[f.formValues[0]];
        setTrust(name, new Set([...trusted, who]));
        player.sendMessage(`§a${who} can now build on your land.`);
    } else if (action === "untrust") {
        const f = await show(player, new ModalFormData().title("Stop trusting").dropdown("Remove:", trusted));
        if (f.canceled || !f.formValues) return;
        const who = trusted[f.formValues[0]];
        setTrust(name, new Set(trusted.filter((n) => n !== who)));
        player.sendMessage(`§e${who} can no longer build on your land.`);
    } else if (action === "list") {
        player.sendMessage(mine.length
            ? "§6Your claims:§r\n" + mine.map((c) => `#${c.id}: (${c.x1}, ${c.z1}) to (${c.x2}, ${c.z2}) in ${c.dim.replace("minecraft:", "")}`).join("\n")
            : "§eYou don't have any claims yet.");
    }
}

world.afterEvents.itemUse.subscribe((ev) => {
    if (ev.itemStack?.typeId === FLAG && ev.source?.typeId === "minecraft:player") {
        menu(ev.source).catch(() => {});
    }
});

// ---- Console admin ---------------------------------------------------------------------

system.afterEvents.scriptEventReceive.subscribe((ev) => {
    if (ev.id !== "earles:claims") return;
    const [cmd, ...rest] = ev.message.trim().split(/\s+/);
    load();
    if (cmd === "list" || !cmd) {
        console.warn(`[claims] ${claims.length} claim(s): ` + claims.map((c) => `#${c.id} ${c.owner} ${c.dim} (${c.x1},${c.z1})-(${c.x2},${c.z2})`).join("; "));
        console.warn(`[claims] trust: ` + JSON.stringify(Object.fromEntries(Object.entries(trust).map(([k, v]) => [k, [...v]]))));
    } else if (cmd === "remove") {
        const c = claims.find((k) => k.id === Number(rest[0]));
        if (c) { removeWall(world.getDimension(c.dim), c); removeClaim(c); console.warn(`[claims] removed #${c.id} (${c.owner}) and its wall`); } else console.warn(`[claims] no claim #${rest[0]}`);
    } else if (cmd === "wall") {
        const c = claims.find((k) => k.id === Number(rest[0]));
        if (!c) { console.warn(`[claims] no claim #${rest[0]}`); return; }
        const n = buildWall(world.getDimension(c.dim), c);
        console.warn(`[claims] built wall on #${c.id}: ${n} blocks; ${lastWallStats}`);
    } else if (cmd === "unwall") {
        const c = claims.find((k) => k.id === Number(rest[0]));
        if (!c) { console.warn(`[claims] no claim #${rest[0]}`); return; }
        console.warn(`[claims] removed wall on #${c.id}: ${removeWall(world.getDimension(c.dim), c)} blocks`);
    } else if (cmd === "probe") {
        // Debug the wall builder: what does the ground finder see at x z?
        const [x, z] = rest.map(Number);
        const dim = world.getDimension("minecraft:overworld");
        const top = tryRun(() => dim.getTopmostBlock({ x, z }));
        const g = groundAt(dim, x, z);
        const above = g === undefined ? [] : [1, 2].map((h) => tryRun(() => dim.getBlock({ x, y: g + h, z })?.typeId));
        console.warn(`[claims] probe ${x},${z}: top=${top ? top.typeId + "@" + top.location.y : "none"} ground=${g} above=${above.join(",")}`);
    } else if (cmd === "removeall") {
        const owner = rest.join(" ");
        const theirs = claims.filter((k) => k.owner === owner);
        for (const c of theirs) { removeWall(world.getDimension(c.dim), c); removeClaim(c); }
        console.warn(`[claims] removed ${theirs.length} claim(s) of ${owner}`);
    } else if (cmd === "skybox") {
        skybox(rest[0]);
    } else if (cmd === "clearglass") {
        clearGlass(rest);
    } else if (cmd === "book") {
        enchantBook(rest);
    } else {
        console.warn("[claims] usage: scriptevent earles:claims list | remove <id> | removeall <owner> | wall <id> | unwall <id> | probe <x> <z> | skybox <player> | book <player[,player]> <enchantment> [level] | clearglass [x1 y1 z1 x2 y2 z2 [dimension]]");
    }
});

// Hollow 5x5x5 of bulletproof glass, 50 blocks above an online player (3x3x3 of air
// inside). The player is teleported up into it. "skybox henry" and "skybox hcearles"
// are the same. Extra words are ignored, so "skybox henry in bulletproof glass" works too.
function skybox(name) {
    if (!name) {
        console.warn("[claims] usage: scriptevent earles:claims skybox <player>");
        return;
    }
    const want = (PLAYER_ALIASES[name.toLowerCase()] ?? name).toLowerCase();
    const player = world.getAllPlayers().find((p) => p.name.toLowerCase() === want);
    if (!player) {
        const online = world.getAllPlayers().map((p) => p.name).join(", ") || "nobody";
        console.warn(`[claims] skybox: no player '${name}' online (${online})`);
        return;
    }
    const dim = player.dimension;
    const x = Math.floor(player.location.x);
    const z = Math.floor(player.location.z);
    const feet = Math.floor(player.location.y);
    const y = feet + SKYBOX_ABOVE;
    let minY = -64, maxY = 319;
    try {
        const r = dim.heightRange;
        if (r && Number.isFinite(r.min) && Number.isFinite(r.max)) { minY = r.min; maxY = r.max - 1; }
    } catch { /* vanilla overworld limits */ }
    const x1 = x - 2, y1 = y - 1, z1 = z - 2, x2 = x + 2, y2 = y + 3, z2 = z + 2;
    if (y1 < minY || y2 > maxY) {
        console.warn(`[claims] skybox: ${player.name} at y=${feet} can't fit a box ${SKYBOX_ABOVE} above (limit ${maxY})`);
        return;
    }
    try {
        dim.runCommand(`fill ${x1} ${y1} ${z1} ${x2} ${y2} ${z2} ${GLASS} hollow`);
        player.teleport({ x: x + 0.5, y, z: z + 0.5 });
        recordGlassBox({ dim: dim.id, x1, y1, z1, x2, y2, z2 });
        console.warn(`[claims] skybox ${player.name}: bulletproof glass (${x1},${y1},${z1}) to (${x2},${y2},${z2}) in ${dim.id}, ${SKYBOX_ABOVE} above y=${feet}`);
        console.warn(`[claims] remove it with: scriptevent earles:claims clearglass   (or: fill ${x1} ${y1} ${z1} ${x2} ${y2} ${z2} air replace ${GLASS})`);
    } catch (e) {
        console.warn(`[claims] skybox failed: ${e}`);
    }
}

// ---- Clearing bulletproof glass ---------------------------------------------------------
// Every skybox is recorded, so `clearglass` with no arguments removes all of them. Glass placed
// any other way (fill / setblock, or skyboxes built before recording) can be cleared by giving
// a region. Chunks that aren't loaded get a temporary ticking area; the fill runs once they are.
const GLASS_BOXES_KEY = "earles_claims_glass_boxes";
const CLEAR_MAX_BLOCKS = 32768;   // the fill command's limit per call

function glassBoxes() {
    const raw = tryRun(() => world.getDynamicProperty(GLASS_BOXES_KEY));
    return typeof raw === "string" ? JSON.parse(raw) : [];
}

function recordGlassBox(box) {
    const all = glassBoxes();
    all.push(box);
    world.setDynamicProperty(GLASS_BOXES_KEY, JSON.stringify(all));
}

let clearJob = 0;
function clearRegion(box, done) {
    const dim = world.getDimension(box.dim);
    const [x1, x2] = [Math.min(box.x1, box.x2), Math.max(box.x1, box.x2)];
    const [y1, y2] = [Math.min(box.y1, box.y2), Math.max(box.y1, box.y2)];
    const [z1, z2] = [Math.min(box.z1, box.z2), Math.max(box.z1, box.z2)];
    const area = `earles_clr_${++clearJob}`;
    tryRun(() => dim.runCommand(`tickingarea add ${x1} ${y1} ${z1} ${x2} ${y2} ${z2} ${area}`));
    system.runTimeout(() => {
        // Slice by height so every fill stays under the command's block limit
        const layer = (x2 - x1 + 1) * (z2 - z1 + 1);
        const step = Math.max(1, Math.floor(CLEAR_MAX_BLOCKS / layer));
        let ok = 0, failed = 0;
        for (let y = y1; y <= y2; y += step) {
            const top = Math.min(y2, y + step - 1);
            try { dim.runCommand(`fill ${x1} ${y} ${z1} ${x2} ${top} ${z2} air replace ${GLASS}`); ok++; } catch { failed++; }
        }
        tryRun(() => dim.runCommand(`tickingarea remove ${area}`));
        done({ ok, failed });
    }, 40);
}

function clearGlass(args) {
    const nums = args.slice(0, 6).map(Number);
    let boxes, explicit = false;
    if (args.length >= 6 && nums.every(Number.isFinite)) {
        explicit = true;
        const dimId = args[6] ? (args[6].includes(":") ? args[6] : `minecraft:${args[6]}`) : "minecraft:overworld";
        if (!tryRun(() => world.getDimension(dimId))) return console.warn(`[claims] clearglass: unknown dimension '${args[6]}'`);
        boxes = [{ dim: dimId, x1: nums[0], y1: nums[1], z1: nums[2], x2: nums[3], y2: nums[4], z2: nums[5] }];
    } else if (args.length === 0) {
        boxes = glassBoxes();
        if (!boxes.length) return console.warn("[claims] clearglass: no recorded skybox boxes. Give a region to clear hand-placed or older glass: clearglass <x1> <y1> <z1> <x2> <y2> <z2>");
    } else {
        return console.warn("[claims] usage: scriptevent earles:claims clearglass [x1 y1 z1 x2 y2 z2 [dimension]]");
    }
    let pending = boxes.length, failedBoxes = [];
    for (const b of boxes) {
        clearRegion(b, ({ ok, failed }) => {
            console.warn(`[claims] clearglass: (${b.x1},${b.y1},${b.z1}) to (${b.x2},${b.y2},${b.z2}) in ${b.dim}: ${ok} fill(s) ok${failed ? `, ${failed} failed` : ""}`);
            if (failed) failedBoxes.push(b);
            if (--pending === 0) {
                if (!explicit) world.setDynamicProperty(GLASS_BOXES_KEY, failedBoxes.length ? JSON.stringify(failedBoxes) : undefined);
                console.warn(`[claims] clearglass: done, ${boxes.length - failedBoxes.length}/${boxes.length} region(s) cleared${failedBoxes.length ? " (failed ones stay recorded - rerun)" : ""}`);
            }
        });
    }
    console.warn(`[claims] clearglass: clearing ${boxes.length} region(s)...`);
}

// ---- Enchanted books ----------------------------------------------------------------------
// /give can't put an enchantment on a book, but the scripting engine can.
function enchantBook(args) {
    const [who, enchantArg, levelArg] = args;
    if (!who || !enchantArg) {
        return console.warn("[claims] usage: scriptevent earles:claims book <player[,player...]> <enchantment> [level]   e.g. book henry,theo feather_falling 4");
    }
    const enchant = enchantArg.replace(/^minecraft:/, "").toLowerCase();
    const level = levelArg === undefined ? 1 : Number(levelArg);
    if (!Number.isInteger(level) || level < 1) return console.warn(`[claims] book: bad level '${levelArg}'`);
    for (const name of who.split(",")) {
        const want = (PLAYER_ALIASES[name.toLowerCase()] ?? name).toLowerCase();
        const player = world.getAllPlayers().find((p) => p.name.toLowerCase() === want);
        if (!player) {
            console.warn(`[claims] book: no player '${name}' online (${world.getAllPlayers().map((p) => p.name).join(", ") || "nobody"})`);
            continue;
        }
        try {
            const stack = new ItemStack("minecraft:enchanted_book", 1);
            const ench = stack.getComponent("minecraft:enchantable");
            ench.addEnchantment({ type: new EnchantmentType(enchant), level });
            const given = ench.getEnchantments().map((e) => `${e.type.id} ${e.level}`).join(", ");
            const left = player.getComponent("minecraft:inventory").container.addItem(stack);
            if (left) player.dimension.spawnItem(left, player.location);   // inventory full: drop it at their feet
            console.warn(`[claims] book: gave ${player.name} an enchanted book (${given})${left ? " - inventory full, dropped at their feet" : ""}`);
        } catch (e) {
            console.warn(`[claims] book failed for ${player.name}: ${e}`);
        }
    }
}
