// Tornado TNT - written for the Earles server.
// Light the block (flint and steel, fire charge, or redstone) and after a short fuse it
// becomes a tornado that wanders around, rips up surface blocks, and flings mobs and
// players into the air. Built with limits so it can't lag the server:
// short lifetime, capped block-breaking rate, max tornadoes at once, no item drops
// (flying debris items are removed after a few seconds and capped in number).
//
// Console/test: `scriptevent earles:tornado <x> <y> <z>` spawns one in the overworld.
import { system, world } from "@minecraft/server";

const MAX_TORNADOES = 3;
const FUSE_TICKS = 60;            // 3 s hiss, like vanilla TNT
const LIFETIME_TICKS = 30 * 20;   // 30 s
const STEP = 2;                   // simulate every 2 ticks
const SPEED = 0.15;               // blocks per step (~1.5 blocks/s)
const HEIGHT = 18;                // funnel height
const PULL_RADIUS = 8;            // entities inside get sucked in
const BREAK_RADIUS = 3;           // blocks inside get ripped up
const BLOCKS_PER_STEP = 3;        // ~30 blocks/s max
const FUNNEL_PARTICLES = 36;      // custom earles:tornado_cloud puffs per step (3 spiral arms)
const DEBRIS_CHANCE = 0.6;        // share of ripped-up blocks that fly as visible debris
const MAX_DEBRIS = 40;            // flying debris items alive at once (all tornadoes)
const DEBRIS_TICKS = 70;          // debris is removed after ~3.5 s so it can't pile up
const CLOUD = "earles:tornado_cloud";
const DEBRIS_TAG = "earles_tornado_debris"; // admin cleanup: kill @e[type=item,tag=earles_tornado_debris]

const UNBREAKABLE = new Set([
    "minecraft:air", "minecraft:bedrock", "minecraft:barrier", "minecraft:light_block",
    "minecraft:command_block", "minecraft:chain_command_block", "minecraft:repeating_command_block",
    "minecraft:structure_block", "minecraft:jigsaw", "minecraft:end_portal", "minecraft:end_portal_frame",
    "minecraft:portal", "minecraft:end_gateway", "minecraft:reinforced_deepslate",
    "earles:tornado_tnt",
]);
const DONT_FLING = new Set(["minecraft:xp_orb", "minecraft:painting", "minecraft:leash_knot"]);

const tornadoes = [];
const debris = [];                // { entity, id, expires }
const usedDims = new Set();       // dimensions that have had tornadoes (for the orphan sweep)
const lit = new Set();            // blocks currently fusing, so they can't be lit twice
let tick = 0;

function tryRun(fn) {
    try { return fn(); } catch { return undefined; }
}

function ignite(block) {
    const dim = block.dimension;
    const { x, y, z } = block.location;
    const key = `${dim.id}:${x},${y},${z}`;
    if (lit.has(key)) return;
    lit.add(key);
    const at = { x: x + 0.5, y: y + 0.5, z: z + 0.5 };
    tryRun(() => dim.playSound("random.fuse", at));
    let t = 0;
    const id = system.runInterval(() => {
        t += 2;
        // Block stays put while it fizzes, like vanilla TNT
        tryRun(() => dim.spawnParticle("minecraft:basic_flame_particle", { x: at.x, y: at.y + 0.55, z: at.z }));
        tryRun(() => dim.spawnParticle(CLOUD, { x: at.x, y: at.y + 0.8, z: at.z }));
        if (t >= FUSE_TICKS) {
            system.clearRun(id);
            lit.delete(key);
            const b = tryRun(() => dim.getBlock({ x, y, z }));
            if (b?.typeId === "earles:tornado_tnt") tryRun(() => b.setType("minecraft:air"));
            spawnTornado(dim, at);
        }
    }, 2);
}

function spawnTornado(dim, at) {
    if (tornadoes.length >= MAX_TORNADOES) {
        world.sendMessage(`§eToo many tornadoes! (max ${MAX_TORNADOES}) - wait for one to fade.`);
        return;
    }
    tornadoes.push({ dim, x: at.x, y: Math.floor(at.y), z: at.z, age: 0, heading: Math.random() * Math.PI * 2 });
    usedDims.add(dim.id);
    tryRun(() => dim.playSound("ambient.weather.thunder", at, { volume: 2 }));
}

function groundY(dim, x, z, fallback) {
    const top = dim.getTopmostBlock({ x: Math.floor(x), z: Math.floor(z) });
    return top ? top.location.y + 1 : fallback;
}

function dropsEnabled() {
    return tryRun(() => world.gameRules.doTileDrops) ?? true;
}

function step(tw) {
    const { dim } = tw;
    tw.age += STEP;

    // Wander, following the ground
    tw.heading += (Math.random() - 0.5) * 0.5;
    tw.x += Math.cos(tw.heading) * SPEED;
    tw.z += Math.sin(tw.heading) * SPEED;
    tw.y = groundY(dim, tw.x, tw.z, tw.y);   // throws in unloaded chunks -> tornado ends

    // Funnel: a rising spiral that widens with height
    for (let i = 0; i < FUNNEL_PARTICLES; i++) {
        const arm = i % 3;
        const h = Math.random() * HEIGHT;
        const r = 0.5 + h * 0.3 + Math.random() * 0.4;
        const a = tw.age * 0.5 - h * 0.35 + arm * (Math.PI * 2 / 3);
        const p = { x: tw.x + Math.cos(a) * r, y: tw.y + h, z: tw.z + Math.sin(a) * r };
        tryRun(() => dim.spawnParticle(CLOUD, p));
    }
    for (let i = 0; i < 6; i++) {                                   // dust skirt at the base
        const a = Math.random() * Math.PI * 2, r = 1.5 + Math.random() * 2;
        tryRun(() => dim.spawnParticle(CLOUD, { x: tw.x + Math.cos(a) * r, y: tw.y + 0.3, z: tw.z + Math.sin(a) * r }));
    }
    if (tw.age % 10 === 0) {
        tryRun(() => dim.spawnParticle("minecraft:large_explosion", { x: tw.x, y: tw.y + 0.5, z: tw.z }));
    }
    if (tw.age % 40 === 0) {
        tryRun(() => dim.playSound("ambient.weather.rain", { x: tw.x, y: tw.y, z: tw.z }, { volume: 1.5 }));
    }

    // Suck in and fling entities
    const center = { x: tw.x, y: tw.y + 2, z: tw.z };
    for (const e of dim.getEntities({ location: center, maxDistance: PULL_RADIUS + 4 })) {
        if (DONT_FLING.has(e.typeId)) continue;
        const dx = tw.x - e.location.x, dz = tw.z - e.location.z;
        const dist = Math.hypot(dx, dz) || 0.01;
        if (dist > PULL_RADIUS || e.location.y > tw.y + HEIGHT) continue;
        // Pull inward + spin around the funnel; lift until ~70% of the funnel height,
        // then stop lifting so things get thrown out sideways and fall.
        const inward = 0.3, swirl = 0.45;
        const hx = (inward * dx - swirl * dz) / dist;
        const hz = (inward * dz + swirl * dx) / dist;
        const lifting = e.location.y < tw.y + HEIGHT * 0.7;
        const up = lifting ? (dist < 2.5 ? 0.5 : 0.35) : 0;
        if (e.typeId === "minecraft:player") {
            tryRun(() => e.applyKnockback({ x: hx * 0.8, z: hz * 0.8 }, lifting ? up + 0.2 : 0.05));
            tryRun(() => e.addEffect("slow_falling", 160, { showParticles: false }));
        } else {
            if (tryRun(() => { e.applyImpulse({ x: hx * 0.3, y: up, z: hz * 0.3 }); return true; }) === undefined) {
                tryRun(() => e.applyKnockback({ x: hx * 0.6, z: hz * 0.6 }, up + 0.1));
            }
        }
    }

    // Rip up surface blocks (capped per step)
    const destroy = !dropsEnabled() ? "destroy" : null;   // "destroy" shows break particles but drops items
    for (let k = 0; k < BLOCKS_PER_STEP; k++) {
        const a = Math.random() * Math.PI * 2, r = Math.random() * BREAK_RADIUS;
        const bx = Math.floor(tw.x + Math.cos(a) * r), bz = Math.floor(tw.z + Math.sin(a) * r);
        const top = tryRun(() => dim.getTopmostBlock({ x: bx, z: bz }));
        if (!top || UNBREAKABLE.has(top.typeId) || top.isLiquid) continue;
        if (top.location.y < tw.y - 4 || top.location.y > tw.y + 8) continue;   // stay near the ground
        const { x, y, z } = top.location;
        if (debris.length < MAX_DEBRIS && Math.random() < DEBRIS_CHANCE) {
            const stack = tryRun(() => top.getItemStack(1));
            const chunk = stack && tryRun(() => dim.spawnItem(stack, { x: x + 0.5, y: y + 1, z: z + 0.5 }));
            if (chunk) {
                tryRun(() => chunk.addTag(DEBRIS_TAG));
                tryRun(() => chunk.applyImpulse({ x: (Math.random() - 0.5) * 0.4, y: 0.5 + Math.random() * 0.3, z: (Math.random() - 0.5) * 0.4 }));
                debris.push({ entity: chunk, id: chunk.id, expires: tick + DEBRIS_TICKS });
            }
        }
        if (destroy) {
            tryRun(() => dim.runCommand(`setblock ${x} ${y} ${z} air destroy`));
        } else {
            tryRun(() => top.setType("minecraft:air"));
            tryRun(() => dim.spawnParticle("minecraft:basic_smoke_particle", { x: x + 0.5, y: y + 0.5, z: z + 0.5 }));
        }
    }
}

system.runInterval(() => {
    tick += STEP;
    for (let i = debris.length - 1; i >= 0; i--) {
        const d = debris[i];
        if (tick < d.expires) continue;
        // Re-resolve by id: the entity may have been unloaded (flung out of loaded chunks)
        const e = tryRun(() => (d.entity.isValid ? d.entity : world.getEntity(d.id)));
        if (e && tryRun(() => e.isValid)) {
            tryRun(() => e.dimension.spawnParticle(CLOUD, e.location));
            tryRun(() => e.remove());
            debris.splice(i, 1);
        } else if (tick > d.expires + 20 * 60) {
            debris.splice(i, 1);   // still unloaded after a minute: the orphan sweep will get it later
        }
    }
    // Orphan sweep: tagged debris we're no longer tracking (e.g. its chunk just reloaded)
    if (tick % 100 === 0) {
        const tracked = new Set(debris.map((d) => d.id));
        for (const dimId of usedDims) {
            const dim = tryRun(() => world.getDimension(dimId));
            for (const e of tryRun(() => dim.getEntities({ type: "minecraft:item", tags: [DEBRIS_TAG] })) ?? []) {
                if (!tracked.has(e.id)) tryRun(() => e.remove());
            }
        }
    }
    for (let i = tornadoes.length - 1; i >= 0; i--) {
        const tw = tornadoes[i];
        let alive = tw.age < LIFETIME_TICKS;
        if (alive) {
            try { step(tw); } catch { alive = false; }   // e.g. wandered into an unloaded chunk
        }
        if (!alive) {
            tryRun(() => tw.dim.spawnParticle("minecraft:large_explosion", { x: tw.x, y: tw.y + 1, z: tw.z }));
            tornadoes.splice(i, 1);
        }
    }
}, STEP);

system.beforeEvents.startup.subscribe((ev) => {
    ev.blockComponentRegistry.registerCustomComponent("earles:tornado_tnt", {
        onPlayerInteract(e) {
            const player = e.player;
            if (!player) return;
            const inv = player.getComponent("minecraft:inventory")?.container;
            const held = inv?.getItem(player.selectedSlotIndex)?.typeId;
            if (held === "minecraft:flint_and_steel" || held === "minecraft:fire_charge") {
                system.run(() => ignite(e.block));
            }
        },
        onTick(e) {
            // A custom block doesn't report power fed into it, so check its neighbours
            // (redstone block, powered dust, lever, button...) like vanilla TNT would.
            const b = e.block;
            const powered = [b, b.above(), b.below(), b.north(), b.south(), b.east(), b.west()]
                .some((n) => (tryRun(() => n?.getRedstonePower()) ?? 0) > 0);
            if (powered) system.run(() => ignite(b));
        },
    });
});

// Testing / admin: /scriptevent earles:tornado <x> <y> <z>
system.afterEvents.scriptEventReceive.subscribe((ev) => {
    if (ev.id !== "earles:tornado") return;
    const src = ev.sourceEntity;
    const parts = ev.message.trim().split(/\s+/).map(Number);
    const dim = src?.dimension ?? world.getDimension("overworld");
    const at = parts.length === 3 && parts.every(Number.isFinite)
        ? { x: parts[0] + 0.5, y: parts[1], z: parts[2] + 0.5 }
        : src?.location;
    if (at) spawnTornado(dim, at);
});
