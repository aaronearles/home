// mc-coords: self-hosted Minecraft coordinate tracker
// Zero dependencies: node:http + node:sqlite. Static PWA served from ./public.
import http from 'node:http';
import fs from 'node:fs';
import path from 'node:path';
import crypto from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';

const PORT = Number(process.env.PORT || 3000);
const DATA_DIR = process.env.DATA_DIR || path.resolve('data');
const PUBLIC_DIR = path.resolve(import.meta.dirname, 'public');
const IMG_DIR = path.join(DATA_DIR, 'images');
const INVITE_TTL_MS = Number(process.env.INVITE_TTL_HOURS || 24) * 3600 * 1000;
const MAX_IMAGE_BYTES = 8 * 1024 * 1024;
const MAX_JSON_BYTES = 256 * 1024;

fs.mkdirSync(IMG_DIR, { recursive: true });

// ---------------------------------------------------------------- database
const db = new DatabaseSync(path.join(DATA_DIR, 'coords.db'));
db.exec(`
  PRAGMA journal_mode = WAL;
  PRAGMA foreign_keys = ON;
  CREATE TABLE IF NOT EXISTS worlds (
    id TEXT PRIMARY KEY,
    name TEXT NOT NULL,
    invite_code TEXT UNIQUE,
    invite_expires INTEGER,
    created_at INTEGER NOT NULL,
    updated_at INTEGER NOT NULL
  );
  CREATE TABLE IF NOT EXISTS categories (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    world_id TEXT NOT NULL REFERENCES worlds(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    icon TEXT NOT NULL,
    color TEXT NOT NULL,
    sort INTEGER NOT NULL DEFAULT 0
  );
  CREATE TABLE IF NOT EXISTS locations (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    world_id TEXT NOT NULL REFERENCES worlds(id) ON DELETE CASCADE,
    name TEXT NOT NULL,
    dimension TEXT NOT NULL CHECK (dimension IN ('overworld','nether','end')),
    x INTEGER NOT NULL, y INTEGER NOT NULL, z INTEGER NOT NULL,
    category_id INTEGER REFERENCES categories(id) ON DELETE SET NULL,
    notes TEXT NOT NULL DEFAULT '',
    image TEXT,
    favorite INTEGER NOT NULL DEFAULT 0,
    created_by TEXT, updated_by TEXT,
    created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL
  );
  CREATE INDEX IF NOT EXISTS locations_world ON locations(world_id);
  CREATE TABLE IF NOT EXISTS location_links (
    location_id INTEGER NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
    related_id INTEGER NOT NULL REFERENCES locations(id) ON DELETE CASCADE,
    PRIMARY KEY (location_id, related_id)
  );
`);

const DEFAULT_CATEGORIES = [
  ['Home', '🏠', '#e5534b'],
  ['Nether Portal', '🟪', '#8957e5'],
  ['Village', '🏘️', '#d29922'],
  ['Farm', '🌾', '#56d364'],
  ['Iron Farm', '⚙️', '#b1bac4'],
  ['Mine', '⛏️', '#a5a5a5'],
  ['Spawner', '💀', '#768390'],
  ['Mountain', '⛰️', '#3fb950'],
  ['Fortress', '🏯', '#b62324'],
  ['Stronghold', '🏰', '#6e7681'],
  ['End Portal', '🌀', '#39d3bb'],
  ['Monument', '🔱', '#1f6feb'],
  ['Other', '📍', '#8b949e'],
];

const now = () => Date.now();
const newId = () => crypto.randomBytes(16).toString('base64url');

function tx(fn) {
  db.exec('BEGIN');
  try { const r = fn(); db.exec('COMMIT'); return r; }
  catch (e) { db.exec('ROLLBACK'); throw e; }
}

function createWorld(name) {
  const id = newId();
  const t = now();
  tx(() => {
    db.prepare('INSERT INTO worlds (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)').run(id, name, t, t);
    const ins = db.prepare('INSERT INTO categories (world_id, name, icon, color, sort) VALUES (?, ?, ?, ?, ?)');
    DEFAULT_CATEGORIES.forEach(([n, i, c], idx) => ins.run(id, n, i, c, idx));
  });
  return id;
}

function getWorld(id) {
  return db.prepare('SELECT * FROM worlds WHERE id = ?').get(id);
}

function worldState(id) {
  const w = getWorld(id);
  const categories = db.prepare('SELECT id, name, icon, color, sort FROM categories WHERE world_id = ? ORDER BY sort, id').all(id);
  const locations = db.prepare('SELECT * FROM locations WHERE world_id = ? ORDER BY name COLLATE NOCASE').all(id);
  const links = db.prepare(`SELECT l.location_id, l.related_id FROM location_links l
    JOIN locations a ON a.id = l.location_id WHERE a.world_id = ?`).all(id);
  const rel = new Map();
  for (const { location_id, related_id } of links) {
    if (!rel.has(location_id)) rel.set(location_id, []);
    rel.get(location_id).push(related_id);
  }
  return {
    world: { id: w.id, name: w.name, created_at: w.created_at, updated_at: w.updated_at },
    categories,
    locations: locations.map((l) => ({
      id: l.id, name: l.name, dimension: l.dimension, x: l.x, y: l.y, z: l.z,
      category_id: l.category_id, notes: l.notes, image: l.image, favorite: !!l.favorite,
      created_by: l.created_by, updated_by: l.updated_by,
      created_at: l.created_at, updated_at: l.updated_at,
      related: rel.get(l.id) || [],
    })),
  };
}

function touchWorld(id) {
  db.prepare('UPDATE worlds SET updated_at = ? WHERE id = ?').run(now(), id);
}

// ---------------------------------------------------------------- validation
class HttpError extends Error {
  constructor(status, message) { super(message); this.status = status; }
}
const str = (v, field, max = 200, { required = false } = {}) => {
  if (v === undefined || v === null) {
    if (required) throw new HttpError(400, `${field} is required`);
    return undefined;
  }
  if (typeof v !== 'string') throw new HttpError(400, `${field} must be a string`);
  const s = v.trim();
  if (required && !s) throw new HttpError(400, `${field} is required`);
  if (s.length > max) throw new HttpError(400, `${field} is too long`);
  return s;
};
const int = (v, field) => {
  const n = typeof v === 'string' ? Number(v) : v;
  if (!Number.isFinite(n) || Math.abs(n) > 30_000_000) throw new HttpError(400, `${field} must be a coordinate`);
  return Math.round(n);
};
const DIMENSIONS = new Set(['overworld', 'nether', 'end']);
const COLOR_RE = /^#[0-9a-fA-F]{6}$/;

function playerName(req) {
  // Prefer an SSO identity if Traefik forward-auth (Authentik) is in front of us.
  const sso = req.headers['x-authentik-username'] || req.headers['remote-user'];
  const raw = sso || req.headers['x-player'] || '';
  let name = String(raw);
  try { name = decodeURIComponent(name); } catch { /* keep raw */ }
  return name.trim().slice(0, 40) || 'Someone';
}

// ---------------------------------------------------------------- live sync (SSE)
const subscribers = new Map(); // worldId -> Set<res>
function broadcast(worldId, event) {
  const subs = subscribers.get(worldId);
  if (!subs) return;
  const msg = `data: ${JSON.stringify(event)}\n\n`;
  for (const res of subs) res.write(msg);
}
setInterval(() => {
  for (const subs of subscribers.values()) for (const res of subs) res.write(': ping\n\n');
}, 25_000).unref();

// ---------------------------------------------------------------- http helpers
function send(res, status, body, headers = {}) {
  const isBuf = Buffer.isBuffer(body);
  const payload = isBuf || typeof body === 'string' ? body : JSON.stringify(body);
  res.writeHead(status, {
    'Content-Type': isBuf ? 'application/octet-stream' : typeof body === 'string' ? 'text/plain; charset=utf-8' : 'application/json',
    'Cache-Control': 'no-store',
    ...headers,
  });
  res.end(payload);
}

function readBody(req, limit) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    let size = 0;
    req.on('data', (c) => {
      size += c.length;
      if (size > limit) { reject(new HttpError(413, 'Payload too large')); req.destroy(); return; }
      chunks.push(c);
    });
    req.on('end', () => resolve(Buffer.concat(chunks)));
    req.on('error', reject);
  });
}

async function readJson(req) {
  const buf = await readBody(req, MAX_JSON_BYTES);
  if (!buf.length) return {};
  try { return JSON.parse(buf.toString('utf8')); }
  catch { throw new HttpError(400, 'Invalid JSON'); }
}

// Naive in-memory rate limit for invite code guessing.
const joinAttempts = new Map();
function rateLimitJoin(req) {
  const ip = req.headers['x-forwarded-for']?.split(',')[0].trim() || req.socket.remoteAddress;
  const t = now();
  const rec = joinAttempts.get(ip) || { count: 0, reset: t + 60_000 };
  if (t > rec.reset) { rec.count = 0; rec.reset = t + 60_000; }
  rec.count += 1;
  joinAttempts.set(ip, rec);
  if (rec.count > 10) throw new HttpError(429, 'Too many attempts, try again in a minute');
}

function requireWorld(id) {
  const w = getWorld(id);
  if (!w) throw new HttpError(404, 'World not found');
  return w;
}

function requireLocation(worldId, locId) {
  const l = db.prepare('SELECT * FROM locations WHERE id = ? AND world_id = ?').get(Number(locId), worldId);
  if (!l) throw new HttpError(404, 'Location not found');
  return l;
}

function setLinks(worldId, locId, related) {
  if (!Array.isArray(related)) throw new HttpError(400, 'related must be an array');
  const ids = [...new Set(related.map(Number))].filter((r) => Number.isInteger(r) && r !== locId).slice(0, 50);
  db.prepare('DELETE FROM location_links WHERE location_id = ?').run(locId);
  const check = db.prepare('SELECT 1 FROM locations WHERE id = ? AND world_id = ?');
  const ins = db.prepare('INSERT OR IGNORE INTO location_links (location_id, related_id) VALUES (?, ?)');
  for (const r of ids) if (check.get(r, worldId)) ins.run(locId, r);
}

function checkCategory(worldId, categoryId) {
  if (categoryId === null || categoryId === undefined || categoryId === '') return null;
  const c = db.prepare('SELECT id FROM categories WHERE id = ? AND world_id = ?').get(Number(categoryId), worldId);
  if (!c) throw new HttpError(400, 'Unknown category');
  return c.id;
}

function removeImageFile(name) {
  if (!name) return;
  fs.rm(path.join(IMG_DIR, name), { force: true }, () => {});
}

const IMAGE_TYPES = { 'image/jpeg': 'jpg', 'image/png': 'png', 'image/webp': 'webp' };
const IMAGE_MIME = { jpg: 'image/jpeg', png: 'image/png', webp: 'image/webp' };

// ---------------------------------------------------------------- API routes
const routes = [];
const route = (method, pattern, handler) => routes.push({ method, pattern, handler });
const W = '([A-Za-z0-9_-]{22})';

route('GET', /^\/healthz$/, () => ({ ok: true }));

route('POST', /^\/api\/worlds$/, async (req) => {
  const body = await readJson(req);
  const name = str(body.name, 'name', 60, { required: true });
  return { status: 201, body: worldState(createWorld(name)) };
});

route('GET', new RegExp(`^/api/worlds/${W}$`), (req, [wid]) => {
  requireWorld(wid);
  return worldState(wid);
});

route('PATCH', new RegExp(`^/api/worlds/${W}$`), async (req, [wid]) => {
  requireWorld(wid);
  const body = await readJson(req);
  const name = str(body.name, 'name', 60, { required: true });
  db.prepare('UPDATE worlds SET name = ?, updated_at = ? WHERE id = ?').run(name, now(), wid);
  broadcast(wid, { type: 'change', by: playerName(req) });
  return worldState(wid);
});

route('DELETE', new RegExp(`^/api/worlds/${W}$`), (req, [wid]) => {
  requireWorld(wid);
  const imgs = db.prepare('SELECT image FROM locations WHERE world_id = ? AND image IS NOT NULL').all(wid);
  db.prepare('DELETE FROM worlds WHERE id = ?').run(wid);
  imgs.forEach((r) => removeImageFile(r.image));
  broadcast(wid, { type: 'deleted', by: playerName(req) });
  return { ok: true };
});

route('GET', new RegExp(`^/api/worlds/${W}/export$`), (req, [wid]) => {
  const w = requireWorld(wid);
  const state = worldState(wid);
  const safe = w.name.replace(/[^a-z0-9-_ ]/gi, '').trim() || 'world';
  return {
    body: { format: 'mc-coords', version: 1, exported_at: new Date().toISOString(), ...state },
    headers: { 'Content-Disposition': `attachment; filename="${safe}.json"` },
  };
});

route('POST', new RegExp(`^/api/worlds/${W}/invite$`), (req, [wid]) => {
  requireWorld(wid);
  let code;
  for (let i = 0; i < 20; i++) {
    code = String(crypto.randomInt(0, 1_000_000)).padStart(6, '0');
    const clash = db.prepare('SELECT id FROM worlds WHERE invite_code = ? AND invite_expires > ? AND id != ?').get(code, now(), wid);
    if (!clash) break;
  }
  // Clear any stale holder of this code before assigning it.
  db.prepare('UPDATE worlds SET invite_code = NULL WHERE invite_code = ? AND id != ?').run(code, wid);
  const expires = now() + INVITE_TTL_MS;
  db.prepare('UPDATE worlds SET invite_code = ?, invite_expires = ? WHERE id = ?').run(code, expires, wid);
  return { code, expires };
});

route('POST', /^\/api\/join$/, async (req) => {
  rateLimitJoin(req);
  const body = await readJson(req);
  const code = str(body.code, 'code', 10, { required: true }).replace(/\D/g, '');
  const w = db.prepare('SELECT id FROM worlds WHERE invite_code = ? AND invite_expires > ?').get(code, now());
  if (!w) throw new HttpError(404, 'Invite code not found or expired');
  broadcast(w.id, { type: 'joined', by: playerName(req) });
  return worldState(w.id);
});

route('GET', new RegExp(`^/api/worlds/${W}/events$`), (req, [wid], res) => {
  requireWorld(wid);
  res.writeHead(200, {
    'Content-Type': 'text/event-stream',
    'Cache-Control': 'no-store',
    Connection: 'keep-alive',
    'X-Accel-Buffering': 'no',
  });
  res.write('retry: 5000\n\n');
  if (!subscribers.has(wid)) subscribers.set(wid, new Set());
  subscribers.get(wid).add(res);
  req.on('close', () => {
    const subs = subscribers.get(wid);
    subs?.delete(res);
    if (subs && !subs.size) subscribers.delete(wid);
  });
  return null; // stream stays open
});

// Categories
route('POST', new RegExp(`^/api/worlds/${W}/categories$`), async (req, [wid]) => {
  requireWorld(wid);
  const b = await readJson(req);
  const name = str(b.name, 'name', 40, { required: true });
  const icon = str(b.icon, 'icon', 16, { required: true });
  const color = str(b.color, 'color', 7) || '#8b949e';
  if (!COLOR_RE.test(color)) throw new HttpError(400, 'color must be #rrggbb');
  const sort = db.prepare('SELECT COALESCE(MAX(sort), 0) + 1 AS s FROM categories WHERE world_id = ?').get(wid).s;
  const r = db.prepare('INSERT INTO categories (world_id, name, icon, color, sort) VALUES (?, ?, ?, ?, ?)').run(wid, name, icon, color, sort);
  touchWorld(wid);
  broadcast(wid, { type: 'change', by: playerName(req) });
  return { status: 201, body: { id: Number(r.lastInsertRowid) } };
});

route('PATCH', new RegExp(`^/api/worlds/${W}/categories/(\\d+)$`), async (req, [wid, cid]) => {
  requireWorld(wid);
  const c = db.prepare('SELECT * FROM categories WHERE id = ? AND world_id = ?').get(Number(cid), wid);
  if (!c) throw new HttpError(404, 'Category not found');
  const b = await readJson(req);
  const name = str(b.name, 'name', 40) || c.name;
  const icon = str(b.icon, 'icon', 16) || c.icon;
  const color = str(b.color, 'color', 7) || c.color;
  if (!COLOR_RE.test(color)) throw new HttpError(400, 'color must be #rrggbb');
  db.prepare('UPDATE categories SET name = ?, icon = ?, color = ? WHERE id = ?').run(name, icon, color, c.id);
  touchWorld(wid);
  broadcast(wid, { type: 'change', by: playerName(req) });
  return { ok: true };
});

route('DELETE', new RegExp(`^/api/worlds/${W}/categories/(\\d+)$`), (req, [wid, cid]) => {
  requireWorld(wid);
  db.prepare('DELETE FROM categories WHERE id = ? AND world_id = ?').run(Number(cid), wid);
  touchWorld(wid);
  broadcast(wid, { type: 'change', by: playerName(req) });
  return { ok: true };
});

// Locations
function locationFields(wid, b, existing) {
  const out = {};
  out.name = b.name !== undefined ? str(b.name, 'name', 80, { required: true }) : existing?.name;
  if (!out.name) throw new HttpError(400, 'name is required');
  out.dimension = b.dimension !== undefined ? b.dimension : existing?.dimension ?? 'overworld';
  if (!DIMENSIONS.has(out.dimension)) throw new HttpError(400, 'invalid dimension');
  for (const k of ['x', 'y', 'z']) {
    const v = b[k] !== undefined ? b[k] : existing?.[k] ?? (k === 'y' ? 64 : undefined);
    if (v === undefined) throw new HttpError(400, `${k} is required`);
    out[k] = int(v, k);
  }
  out.category_id = b.category_id !== undefined ? checkCategory(wid, b.category_id) : existing?.category_id ?? null;
  out.notes = b.notes !== undefined ? str(b.notes, 'notes', 4000) ?? '' : existing?.notes ?? '';
  out.favorite = b.favorite !== undefined ? (b.favorite ? 1 : 0) : existing?.favorite ?? 0;
  return out;
}

route('POST', new RegExp(`^/api/worlds/${W}/locations$`), async (req, [wid]) => {
  requireWorld(wid);
  const b = await readJson(req);
  const f = locationFields(wid, b);
  const who = playerName(req);
  const t = now();
  const id = tx(() => {
    const r = db.prepare(`INSERT INTO locations
      (world_id, name, dimension, x, y, z, category_id, notes, favorite, created_by, updated_by, created_at, updated_at)
      VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .run(wid, f.name, f.dimension, f.x, f.y, f.z, f.category_id, f.notes, f.favorite, who, who, t, t);
    const lid = Number(r.lastInsertRowid);
    if (b.related) setLinks(wid, lid, b.related);
    return lid;
  });
  touchWorld(wid);
  broadcast(wid, { type: 'change', by: who });
  return { status: 201, body: { id } };
});

route('PATCH', new RegExp(`^/api/worlds/${W}/locations/(\\d+)$`), async (req, [wid, lid]) => {
  requireWorld(wid);
  const existing = requireLocation(wid, lid);
  const b = await readJson(req);
  const f = locationFields(wid, b, existing);
  const who = playerName(req);
  // Toggling a favorite isn't an "edit" worth crediting.
  const onlyFavorite = Object.keys(b).every((k) => k === 'favorite');
  tx(() => {
    db.prepare(`UPDATE locations SET name = ?, dimension = ?, x = ?, y = ?, z = ?, category_id = ?, notes = ?, favorite = ?,
      updated_by = ?, updated_at = ? WHERE id = ?`)
      .run(f.name, f.dimension, f.x, f.y, f.z, f.category_id, f.notes, f.favorite,
        onlyFavorite ? existing.updated_by : who, onlyFavorite ? existing.updated_at : now(), existing.id);
    if (b.related) setLinks(wid, existing.id, b.related);
  });
  touchWorld(wid);
  broadcast(wid, { type: 'change', by: who });
  return { ok: true };
});

route('DELETE', new RegExp(`^/api/worlds/${W}/locations/(\\d+)$`), (req, [wid, lid]) => {
  requireWorld(wid);
  const l = requireLocation(wid, lid);
  db.prepare('DELETE FROM locations WHERE id = ?').run(l.id);
  removeImageFile(l.image);
  touchWorld(wid);
  broadcast(wid, { type: 'change', by: playerName(req) });
  return { ok: true };
});

route('PUT', new RegExp(`^/api/worlds/${W}/locations/(\\d+)/image$`), async (req, [wid, lid]) => {
  requireWorld(wid);
  const l = requireLocation(wid, lid);
  const ext = IMAGE_TYPES[(req.headers['content-type'] || '').split(';')[0].trim()];
  if (!ext) throw new HttpError(415, 'Upload a JPEG, PNG or WebP image');
  const buf = await readBody(req, MAX_IMAGE_BYTES);
  if (!buf.length) throw new HttpError(400, 'Empty image');
  const name = `${wid}-${l.id}-${crypto.randomBytes(6).toString('hex')}.${ext}`;
  fs.writeFileSync(path.join(IMG_DIR, name), buf);
  const who = playerName(req);
  db.prepare('UPDATE locations SET image = ?, updated_by = ?, updated_at = ? WHERE id = ?').run(name, who, now(), l.id);
  removeImageFile(l.image);
  touchWorld(wid);
  broadcast(wid, { type: 'change', by: who });
  return { image: name };
});

route('DELETE', new RegExp(`^/api/worlds/${W}/locations/(\\d+)/image$`), (req, [wid, lid]) => {
  requireWorld(wid);
  const l = requireLocation(wid, lid);
  db.prepare('UPDATE locations SET image = NULL, updated_by = ?, updated_at = ? WHERE id = ?').run(playerName(req), now(), l.id);
  removeImageFile(l.image);
  touchWorld(wid);
  broadcast(wid, { type: 'change', by: playerName(req) });
  return { ok: true };
});

route('GET', new RegExp(`^/api/worlds/${W}/images/([A-Za-z0-9_-]+\\.(jpg|png|webp))$`), (req, [wid, file, ext], res) => {
  // Image names are prefixed with their world id; the world id is the access capability.
  if (!file.startsWith(`${wid}-`)) throw new HttpError(404, 'Not found');
  const p = path.join(IMG_DIR, file);
  if (!fs.existsSync(p)) throw new HttpError(404, 'Not found');
  res.writeHead(200, { 'Content-Type': IMAGE_MIME[ext], 'Cache-Control': 'private, max-age=31536000, immutable' });
  fs.createReadStream(p).pipe(res);
  return null;
});

// ---------------------------------------------------------------- static files
const STATIC_TYPES = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'text/javascript; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.webmanifest': 'application/manifest+json',
  '.json': 'application/json',
  '.png': 'image/png',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
};

function serveStatic(req, res, pathname) {
  let rel = decodeURIComponent(pathname);
  if (rel === '/' || !path.extname(rel)) rel = '/index.html'; // SPA fallback
  const file = path.join(PUBLIC_DIR, path.normalize(rel));
  if (!file.startsWith(PUBLIC_DIR + path.sep)) return send(res, 403, 'Forbidden');
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) return send(res, 404, 'Not found');
    const ext = path.extname(file);
    const noCache = ext === '.html' || file.endsWith('sw.js') || ext === '.webmanifest';
    res.writeHead(200, {
      'Content-Type': STATIC_TYPES[ext] || 'application/octet-stream',
      'Cache-Control': noCache ? 'no-cache' : 'public, max-age=3600',
    });
    fs.createReadStream(file).pipe(res);
  });
}

// ---------------------------------------------------------------- server
const server = http.createServer(async (req, res) => {
  const { pathname } = new URL(req.url, 'http://localhost');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('Referrer-Policy', 'no-referrer');
  try {
    if (pathname.startsWith('/api/') || pathname === '/healthz') {
      for (const r of routes) {
        const m = r.method === req.method && pathname.match(r.pattern);
        if (!m) continue;
        const result = await r.handler(req, m.slice(1), res);
        if (result === null) return; // handler streamed its own response
        if (result && result.status) return send(res, result.status, result.body ?? {}, result.headers);
        if (result && result.body !== undefined && result.headers) return send(res, 200, result.body, result.headers);
        return send(res, 200, result);
      }
      throw new HttpError(404, 'Not found');
    }
    if (req.method !== 'GET' && req.method !== 'HEAD') throw new HttpError(405, 'Method not allowed');
    serveStatic(req, res, pathname);
  } catch (e) {
    if (!(e instanceof HttpError)) console.error(e);
    if (res.headersSent) return res.end();
    send(res, e.status || 500, { error: e instanceof HttpError ? e.message : 'Internal error' });
  }
});

server.listen(PORT, () => console.log(`mc-coords listening on :${PORT} (data: ${DATA_DIR})`));

const shutdown = () => { server.close(); db.close(); process.exit(0); };
process.on('SIGTERM', shutdown);
process.on('SIGINT', shutdown);
