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
import { system, world } from "@minecraft/server";
import { ActionFormData, ModalFormData } from "@minecraft/server-ui";

const OBJECTIVE = "earles_claims";
const SIZE = 32;              // claim is SIZE x SIZE blocks
const MAX_PER_PLAYER = 3;
const FLAG = "earles:claim_flag";
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
    const claim = claimAt(ev.block.dimension.id, ev.block.location.x, ev.block.location.z);
    if (!canBuild(ev.player.name, claim)) {
        ev.cancel = true;
        deny(ev.player, claim);
    }
});

// Placing blocks, buckets, flint and steel, chests, doors, buttons... all start as an
// interaction with a block. Check the clicked block and the spot a block would go into.
world.beforeEvents.playerInteractWithBlock.subscribe((ev) => {
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

// Explosions (TNT, creepers, add-on explosives) skip claimed blocks
world.beforeEvents.explosion.subscribe((ev) => {
    const dimId = ev.dimension.id;
    if (!getClaims().some((c) => c.dim === dimId)) return;
    const blocks = ev.getImpactedBlocks();
    const keep = blocks.filter((b) => !claimAt(dimId, b.location.x, b.location.z));
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
    if (here) { form.button("Show borders"); actions.push("border"); }
    if (here?.owner === name) { form.button("§cRemove this claim"); actions.push("remove"); }
    form.button("Trust a player"); actions.push("trust");
    if (trusted.length) { form.button("Stop trusting a player"); actions.push("untrust"); }
    form.button("Where are my claims?"); actions.push("list");

    const r = await show(player, form);
    if (r.canceled || r.selection === undefined) return;
    const action = actions[r.selection];

    if (action === "claim") {
        if (mine.length >= MAX_PER_PLAYER) return player.sendMessage(`§cYou already have ${MAX_PER_PLAYER} claims. Remove one first.`);
        const x1 = Math.floor(player.location.x) - SIZE / 2, z1 = Math.floor(player.location.z) - SIZE / 2;
        const c = { id: Math.max(0, ...getClaims().map((k) => k.id)) + 1, dim: dim.id, x1, z1, x2: x1 + SIZE - 1, z2: z1 + SIZE - 1, owner: name };
        const clash = getClaims().find((k) => k.dim === c.dim && k.x1 <= c.x2 && k.x2 >= c.x1 && k.z1 <= c.z2 && k.z2 >= c.z1);
        if (clash) return player.sendMessage(`§cToo close to ${clash.owner === name ? "your other" : clash.owner + "'s"} land - move a bit further away.`);
        addClaim(c);
        lastClaim.set(name, c.id);
        player.sendMessage(`§aClaimed! ${SIZE}×${SIZE} from (${c.x1}, ${c.z1}) to (${c.x2}, ${c.z2}), bedrock to sky.`);
        showBorder(dim, c, Math.floor(player.location.y));
    } else if (action === "border") {
        showBorder(dim, here, Math.floor(player.location.y));
    } else if (action === "remove") {
        const ok = await show(player, new ActionFormData().title("§cRemove claim?")
            .body("Anyone will be able to change this land again.").button("§cYes, remove it").button("Cancel"));
        if (!ok.canceled && ok.selection === 0) { removeClaim(here); player.sendMessage("§eClaim removed."); }
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
        if (c) { removeClaim(c); console.warn(`[claims] removed #${c.id} (${c.owner})`); } else console.warn(`[claims] no claim #${rest[0]}`);
    } else if (cmd === "removeall") {
        const owner = rest.join(" ");
        const theirs = claims.filter((k) => k.owner === owner);
        for (const c of theirs) removeClaim(c);
        console.warn(`[claims] removed ${theirs.length} claim(s) of ${owner}`);
    } else {
        console.warn("[claims] usage: scriptevent earles:claims list | remove <id> | removeall <owner>");
    }
});
