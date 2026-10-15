// Grok Bot web relay: runs the official, unmodified app.asar under stock Electron (same version the app
// ships with) and serves its own renderer to remote browsers. The app's main window is kept hidden and
// blank; its IPC and MessagePorts are relayed to the browser, where the official preload.cjs runs
// against a WebSocket-backed stand-in for require("electron") (see shim.js).
'use strict';
const path = require('node:path');
const fs = require('node:fs');
const http = require('node:http');
const crypto = require('node:crypto');
const Module = require('node:module');
const electron = require('electron');
const codec = require('./codec.js');

const { Readable } = require('node:stream');
const { app, ipcMain, MessageChannelMain } = electron;
const RESOURCES = process.env.GROKBOT_RESOURCES || '/opt/Grok Bot/resources';
const ASAR = path.join(RESOURCES, 'app.asar');
const RENDERER = path.join(ASAR, 'dist', 'renderer');
const PRELOAD = path.join(ASAR, 'dist', 'electron-preload', 'preload.cjs');
const PORT = Number(process.env.RELAY_PORT || 14600);
const TOKEN = process.env.RELAY_TOKEN || '';
const DEBUG = process.env.RELAY_DEBUG === '1';
const log = (...a) => console.log('[relay]', ...a);
const debug = (...a) => DEBUG && console.log('[relay:debug]', ...a);
const BLANK = 'data:text/html,<!doctype html><title>Grok Bot relay</title>';
// Per-process capability prefix for the custom-scheme proxy: sandboxed frames send no cookies
const PROTO_SECRET = crypto.randomBytes(18).toString('base64url');
// The app serves these itself (protocol.handle); in the browser they are proxied through the relay
const appSchemes = new Set();
const FRAME_SCHEMES = new Set(['sand-html-preview', 'sand-canvas', 'sand-mcp-app']);

// --- Make the vendor code see a packaged app at its real install location -------------------------
function override(obj, key, value) {
  try { Object.defineProperty(obj, key, { configurable: true, get: () => value }); }
  catch (err) { log(`could not override ${key}:`, err.message); }
}
override(app, 'isPackaged', true);
override(process, 'resourcesPath', RESOURCES);
app.getAppPath = () => ASAR;

// --- Relay state ---------------------------------------------------------------------------------------
// A "load" is one navigation of the hidden main window. Any number of browser clients (tabs, devices)
// attach to the same load: replies go to the client that asked, main-process broadcasts go to all.
let mainWin = null;
let mainReady = null;
let load = null;
let nextClientNum = 1;
let lastActive = null; // client that last sent something: receives openExternal and unsolicited ports
const ports = new Map(); // port id -> { port, owner }; browser-made ids are "<clientId>:<n>"
let nextServerPortId = 1;
// Sent once by main when the window loads; replayed to clients that attach later
const STICKY_CHANNELS = new Set(['sand:main-edge-served']);
// Renderer boot signals main expects once per window load, not once per browser tab
const ONCE_PER_LOAD = new Set(['sand:renderer-boot-gate-opened', 'sand:renderer-boot-gate-landed']);

function newLoad() {
  if (load) for (const c of load.clients.values()) { deliver(c, { t: 'reload' }); if (c.ws) c.ws.close(); }
  for (const { port } of ports.values()) { try { port.close(); } catch {} }
  ports.clear();
  coordReset();
  load = { id: crypto.randomUUID(), clients: new Map(), sticky: [], gates: new Set() };
  debug('new load', load.id);
}

function deliver(client, m) {
  if (client.ws && client.ws.open) sendTo(client.ws, m);
  else client.queue.push(m);
}
function broadcast(m) { for (const c of load.clients.values()) deliver(c, m); }
function toOwner(owner, m) { const c = owner && load.clients.get(owner); if (c) deliver(c, m); }
function activeClient() {
  return load.clients.get(lastActive) || [...load.clients.values()].filter((c) => c.ws && c.ws.open).pop() || null;
}

function addClient() {
  const client = { id: `c${nextClientNum++}`, ws: null, queue: [...load.sticky], loadId: load.id };
  load.clients.set(client.id, client);
  // A page that never opens its WebSocket (closed mid-boot) is dropped after a minute
  setTimeout(() => { if (!client.ws) removeClient(client); }, 60000).unref();
  debug('client', client.id, 'joined;', load.clients.size, 'attached');
  return client;
}
function removeClient(client) {
  if (!load || load.clients.get(client.id) !== client) return;
  load.clients.delete(client.id);
  for (const [id, rec] of ports) if (rec.owner === client.id) { ports.delete(id); try { rec.port.close(); } catch {} }
  closeVirtual(client.id);
  if (lastActive === client.id) lastActive = null;
  debug('client', client.id, 'left;', load.clients.size, 'attached');
}

function bindPort(id, port, owner) {
  ports.set(id, { port, owner });
  port.on('message', (e) => {
    debug('port', id, '-> browser', owner);
    toOwner(owner, { t: 'pm', id, d: codec.encode(e.data), p: e.ports.map((p) => registerPort(p, owner)) });
  });
  port.on('close', () => {
    const rec = ports.get(id);
    if (rec && rec.port === port) { ports.delete(id); toOwner(owner, { t: 'pc', id }); }
  });
  port.start();
}
function registerPort(port, owner) { const id = nextServerPortId++; bindPort(id, port, owner); return id; }
function portsForBrowserIds(ids, owner) {
  return (ids || []).map((id) => { const { port1, port2 } = new MessageChannelMain(); bindPort(id, port1, owner); return port2; });
}

// --- Coordinator multiplexer --------------------------------------------------------------------------
// Main serves the coordinator to exactly one renderer: a second port request disposes the coordinator
// process and starts a new one. So the relay holds that single upstream connection and gives each client
// a virtual port, speaking the coordinator's frame protocol (lifecycle/request/cancel/reply/event):
// request ids are prefixed per client and replies routed back, events go to every client.
const COORD_TRANSPORT_FAMILY = 'coordinator-transport-state';
const coord = { upstream: null, requested: false, ready: false, version: null, helloVersion: null,
  transportEvent: null, virtual: new Map(), backlog: [], inbound: new Map(), methods: new Map() };

function coordReset() {
  if (coord.upstream) { try { coord.upstream.close(); } catch {} }
  for (const cid of [...coord.virtual.keys()]) closeVirtual(cid);
  Object.assign(coord, { upstream: null, requested: false, ready: false, version: null, transportEvent: null, backlog: [] });
  coord.inbound.clear();
}

function closeVirtual(cid) {
  const v = coord.virtual.get(cid);
  if (!v) return;
  coord.virtual.delete(cid);
  try { v.port.close(); } catch {}
}

function coordRequestUpstream() {
  if (coord.requested || coord.upstream) return;
  coord.requested = true;
  debug('coordinator: requesting upstream port');
  invokeIpc('sand:coordinator-port-request', [undefined])
    .catch((e) => { coord.requested = false; log('coordinator port request failed:', e.message); });
}

function coordAdoptUpstream(port) {
  const replacing = coord.upstream != null || coord.version != null;
  if (coord.upstream) { try { coord.upstream.close(); } catch {} }
  // A replacement upstream means the coordinator restarted: clients reconnect through fresh ports.
  // The first one answers the request clients are already waiting on, so their ports stay.
  if (replacing) for (const cid of [...coord.virtual.keys()]) closeVirtual(cid);
  Object.assign(coord, { upstream: port, requested: false, ready: false, transportEvent: null });
  coord.inbound.clear();
  port.on('message', (e) => coordFromUpstream(e.data));
  port.on('close', () => {
    if (coord.upstream !== port) return;
    log('coordinator connection closed');
    coord.upstream = null; coord.ready = false;
    for (const cid of [...coord.virtual.keys()]) closeVirtual(cid);
  });
  port.start();
  port.postMessage({ kind: 'lifecycle', phase: 'hello', protocolVersion: coord.helloVersion ?? 3 });
  log('coordinator: upstream adopted');
}

function coordGreet(v) {
  v.port.postMessage({ kind: 'lifecycle', phase: 'ready', protocolVersion: coord.version });
  if (coord.transportEvent) v.port.postMessage(coord.transportEvent);
  v.ready = true;
}

function coordServeClient(client) {
  closeVirtual(client.id); // a renderer that re-requests replaces its previous port
  const { port1: muxEnd, port2: clientEnd } = new MessageChannelMain();
  const v = { port: muxEnd, ready: false, helloPending: false };
  coord.virtual.set(client.id, v);
  muxEnd.on('message', (e) => coordFromClient(client.id, v, e.data));
  muxEnd.start();
  const id = registerPort(clientEnd, client.id);
  deliver(client, { t: 'ipc', ch: 'sand:coordinator-port', a: codec.encode([null]), p: [id] });
  debug('coordinator: virtual port for', client.id);
}

function coordFromClient(cid, v, f) {
  if (coord.virtual.get(cid) !== v || !f || typeof f !== 'object') return;
  if (f.kind === 'lifecycle') {
    if (f.phase === 'hello') {
      coord.helloVersion ??= f.protocolVersion;
      if (coord.ready) coordGreet(v);
      else { v.helloPending = true; coordRequestUpstream(); }
    } else if (f.phase === 'shutdown') {
      closeVirtual(cid); // never forwarded: it would end the coordinator connection for every client
    }
    return;
  }
  if ((f.kind === 'request' || f.kind === 'cancel') && typeof f.requestId === 'string') {
    const out = { ...f, requestId: `${cid}|${f.requestId}` };
    if (f.kind === 'request') coord.methods.set(out.requestId, f.method);
    if (coord.ready) coord.upstream.postMessage(out); else coord.backlog.push(out);
    return;
  }
  if (f.kind === 'reply' && coord.inbound.has(f.requestId)) { // reply to a coordinator-initiated request
    coord.inbound.delete(f.requestId);
    if (coord.upstream) coord.upstream.postMessage(f);
    return;
  }
  debug('coordinator: unhandled client frame', f.kind);
}

function coordFromUpstream(f) {
  if (!f || typeof f !== 'object') return;
  if (f.kind === 'lifecycle') {
    if (f.phase === 'ready') {
      coord.ready = true; coord.version = f.protocolVersion;
      for (const v of coord.virtual.values()) if (v.helloPending) { v.helloPending = false; coordGreet(v); }
      for (const out of coord.backlog.splice(0)) coord.upstream.postMessage(out);
      log('coordinator: ready, serving', coord.virtual.size, 'client(s)');
    } else if (f.phase === 'shutdown') {
      log('coordinator: shutdown', f.reason, f.detail || '');
      for (const v of coord.virtual.values()) v.port.postMessage(f);
    }
    return;
  }
  if (f.kind === 'reply' && typeof f.requestId === 'string') {
    const method = coord.methods.get(f.requestId);
    coord.methods.delete(f.requestId);
    if (f.outcome && f.outcome.status !== 'ok') {
      log('coordinator error reply:', method || '?', JSON.stringify(f.outcome).slice(0, 600));
    }
    const sep = f.requestId.indexOf('|');
    const v = sep > 0 && coord.virtual.get(f.requestId.slice(0, sep));
    if (v) v.port.postMessage({ ...f, requestId: f.requestId.slice(sep + 1) });
    return;
  }
  if (f.kind === 'event') {
    if (f.family === COORD_TRANSPORT_FAMILY) coord.transportEvent = f;
    for (const v of coord.virtual.values()) if (v.ready) v.port.postMessage(f);
    return;
  }
  if (f.kind === 'request' || f.kind === 'cancel') { // coordinator asking the UI: the active client answers
    const target = (activeClient() && coord.virtual.get(activeClient().id)) || [...coord.virtual.values()].find((v) => v.ready);
    if (f.kind === 'request') coord.inbound.set(f.requestId, true);
    if (target) target.port.postMessage(f);
    return;
  }
  debug('coordinator: unhandled upstream frame', f.kind);
}

// Replay a browser IPC message as if the hidden window's real renderer sent it, so the app's own
// sender checks (sender === main webContents, senderFrame === its main frame) still hold
function emitIpc(channel, args, eventPorts, sync) {
  const wc = mainWin.webContents;
  const frame = wc.mainFrame;
  const event = {
    type: 'frame', sender: wc, senderFrame: frame, frameId: frame.routingId, processId: frame.processId,
    ports: eventPorts, returnValue: undefined, preventDefault() {},
    reply: (ch, ...a) => wc.send(ch, ...a),
  };
  debug(sync ? 'sendSync' : 'send', channel);
  wc.emit(sync ? 'ipc-message-sync' : 'ipc-message', event, channel, ...args);
  wc.ipc.emit(channel, event, ...args);
  ipcMain.emit(channel, event, ...args);
  return event.returnValue;
}

async function invokeIpc(channel, args) {
  const wc = mainWin.webContents;
  const handler = wc.ipc._invokeHandlers?.get(channel) || ipcMain._invokeHandlers?.get(channel);
  if (!handler) throw new Error(`No handler registered for '${channel}'`);
  const frame = wc.mainFrame;
  return handler({ type: 'frame', sender: wc, senderFrame: frame, frameId: frame.routingId, processId: frame.processId }, ...args);
}

// --- Hook the app's main window: hidden, blank, preload removed, renderer traffic redirected ----------
function isMainWindowOptions(opts) {
  const preload = opts && opts.webPreferences && opts.webPreferences.preload;
  return typeof preload === 'string' && path.basename(preload) === 'preload.cjs'
    && path.basename(path.dirname(preload)) === 'electron-preload';
}

let mainArgv = [];
function adoptMainWindow(win, opts) {
  mainWin = win;
  mainArgv = [...(opts.webPreferences.additionalArguments || [])];
  const wc = win.webContents;
  let resolveReady;
  mainReady = new Promise((r) => { resolveReady = r; });
  newLoad();

  win.loadFile = () => win.loadURL(BLANK);
  wc.send = (channel, ...args) => {
    debug('main send', channel);
    const m = { t: 'ipc', ch: channel, a: codec.encode(args) };
    if (STICKY_CHANNELS.has(channel)) load.sticky.push(m);
    broadcast(m);
  };
  wc.postMessage = (channel, message, transfer = []) => {
    debug('main postMessage', channel, `(${transfer.length} ports)`);
    if (channel === 'sand:coordinator-port' && transfer.length === 1) return coordAdoptUpstream(transfer[0]);
    const owner = activeClient();
    if (!owner) { log('dropping', channel, 'from main: no browser attached'); transfer.forEach((p) => p.close()); return; }
    deliver(owner, { t: 'ipc', ch: channel, a: codec.encode([message]), p: transfer.map((p) => registerPort(p, owner.id)) });
  };
  wc.on('did-start-navigation', (details) => {
    if (details.isMainFrame && !details.isSameDocument) newLoad();
  });
  wc.on('did-finish-load', () => resolveReady());
  wc.on('render-process-gone', (_e, d) => log('hidden window renderer gone:', d.reason));
  log('adopted main window');
}

const RealBrowserWindow = electron.BrowserWindow;
class RelayBrowserWindow extends RealBrowserWindow {
  constructor(options = {}) {
    const main = isMainWindowOptions(options);
    let opts = options;
    if (main) {
      const { preload, ...webPreferences } = options.webPreferences;
      opts = { ...options, show: false, webPreferences };
    }
    super(opts);
    if (main) adoptMainWindow(this, options);
    else this.on('ready-to-show', () => debug('secondary window', JSON.stringify(options.title || '')));
  }
}

function overlay(target, overrides) {
  return new Proxy(target, {
    get(t, key) {
      if (Object.prototype.hasOwnProperty.call(overrides, key)) return overrides[key];
      const v = Reflect.get(t, key);
      return typeof v === 'function' ? v.bind(t) : v;
    },
  });
}

// Links the app opens (sign-in page, docs, dashboards) belong in the user's browser, not the container
const relayShell = overlay(electron.shell, {
  openExternal: async (url) => {
    log('openExternal ->', String(url).replace(/([?&](challenge|uuid|verifier)=)[^&]+/g, '$1…'));
    const target = load && activeClient();
    if (target) deliver(target, { t: 'open', url: String(url) });
  },
});

// Record the custom schemes the app serves so the browser-side shim knows what to proxy
const relayProtocol = overlay(electron.protocol, {
  handle: (scheme, handler) => { appSchemes.add(scheme); debug('app scheme', scheme); return electron.protocol.handle(scheme, handler); },
});

const patchedElectron = {};
for (const key of Object.getOwnPropertyNames(electron)) {
  Object.defineProperty(patchedElectron, key, {
    enumerable: true,
    get: () => (key === 'BrowserWindow' ? RelayBrowserWindow
      : key === 'shell' ? relayShell
        : key === 'protocol' ? relayProtocol
          : electron[key]),
  });
}
const originalLoad = Module._load;
Module._load = function (request, ...rest) {
  if (request === 'electron') return patchedElectron;
  return originalLoad.call(this, request, ...rest);
};

// --- HTTP: renderer assets, wrapped preload, shim, sync IPC ------------------------------------------
const TYPES = {
  '.html': 'text/html; charset=utf-8', '.js': 'text/javascript; charset=utf-8', '.mjs': 'text/javascript; charset=utf-8',
  '.cjs': 'text/javascript; charset=utf-8', '.css': 'text/css; charset=utf-8', '.json': 'application/json',
  '.map': 'application/json', '.wasm': 'application/wasm', '.svg': 'image/svg+xml', '.png': 'image/png',
  '.jpg': 'image/jpeg', '.jpeg': 'image/jpeg', '.gif': 'image/gif', '.webp': 'image/webp', '.ico': 'image/x-icon',
  '.woff': 'font/woff', '.woff2': 'font/woff2', '.ttf': 'font/ttf', '.otf': 'font/otf', '.mp3': 'audio/mpeg',
  '.wav': 'audio/wav', '.ogg': 'audio/ogg', '.mp4': 'video/mp4', '.webm': 'video/webm', '.txt': 'text/plain; charset=utf-8',
};

const read = (p) => fs.readFileSync(p); // Electron's fs reads inside app.asar transparently
let indexHtml = null;
function getIndexHtml() {
  if (!indexHtml) {
    indexHtml = read(path.join(RENDERER, 'index.html')).toString('utf8').replace(
      /<head>/i,
      '<head>\n    <script src="./__relay/codec.js"></script>\n    <script src="./__relay/shim.js"></script>\n    <script src="./__relay/preload.js"></script>',
    // Proxied frame schemes load from the relay's own origin (sandboxed by response header)
    ).replace(/frame-src /, "frame-src 'self' ");
  }
  return indexHtml;
}
let preloadJs = null;
function getPreloadJs() {
  if (!preloadJs) {
    const src = read(PRELOAD).toString('utf8');
    preloadJs = '(function () {\n'
      + 'var __m = { exports: {} };\n'
      + '(function (require, module, exports, process, __filename, __dirname) {\n'
      + src
      + '\n}).call(window, function (name) { if (name === "electron") return window.__relayElectron;'
      + ' throw new Error("relay: preload cannot require " + name); }, __m, __m.exports, window.__relayProcess,'
      + ' "/preload.cjs", "/");\n})();\n//# sourceURL=grokbot-preload.cjs\n';
  }
  return preloadJs;
}

function authorized(req) {
  if (!TOKEN) return true;
  const cookie = (req.headers.cookie || '').split(/;\s*/).find((c) => c.startsWith('grokbot_relay='));
  const given = cookie ? decodeURIComponent(cookie.slice('grokbot_relay='.length)) : '';
  return given.length === TOKEN.length && crypto.timingSafeEqual(Buffer.from(given), Buffer.from(TOKEN));
}

function readBody(req) {
  return new Promise((resolve, reject) => {
    const chunks = [];
    req.on('data', (c) => chunks.push(c));
    req.on('end', () => { try { resolve(JSON.parse(Buffer.concat(chunks).toString('utf8') || '{}')); } catch (e) { reject(e); } });
    req.on('error', reject);
  });
}

function respond(res, status, body, type = 'text/plain; charset=utf-8', extra = {}) {
  res.writeHead(status, { 'Content-Type': type, 'Cache-Control': 'no-store', ...extra });
  res.end(body);
}

async function handle(req, res) {
  const url = new URL(req.url, 'http://relay');
  if (TOKEN && url.searchParams.get('token') === TOKEN) {
    url.searchParams.delete('token');
    return respond(res, 302, '', undefined, {
      'Set-Cookie': `grokbot_relay=${encodeURIComponent(TOKEN)}; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=31536000`,
      Location: url.pathname + url.search,
    });
  }
  if (url.pathname === '/healthz') return respond(res, mainWin ? 200 : 503, mainWin ? 'ok' : 'starting');
  if (url.pathname.startsWith(`/__relay/p/${PROTO_SECRET}/`)) return proxyScheme(req, res, url);
  if (!authorized(req)) return respond(res, 401, 'Unauthorized: open this URL once with ?token=<RELAY_TOKEN>');

  if (url.pathname === '/__relay/codec.js') return respond(res, 200, read(path.join(__dirname, 'codec.js')), TYPES['.js']);
  if (url.pathname === '/__relay/shim.js') return respond(res, 200, read(path.join(__dirname, 'shim.js')), TYPES['.js']);
  if (url.pathname === '/__relay/preload.js') return respond(res, 200, getPreloadJs(), TYPES['.js']);

  if (req.method === 'POST' && url.pathname === '/__relay/session') {
    if (!mainWin) await new Promise((r) => { const t = setInterval(() => mainWin && (clearInterval(t), r()), 200); });
    await mainReady;
    const client = addClient();
    return respond(res, 200, JSON.stringify({
      id: load.id, client: client.id, argv: mainArgv, versions: process.versions,
      proto: { base: `./__relay/p/${PROTO_SECRET}/`, schemes: [...appSchemes] },
    }), TYPES['.json']);
  }
  if (req.method === 'POST' && url.pathname === '/__relay/sync') {
    const body = await readBody(req);
    if (body.session !== load.id || !load.clients.has(body.client)) return respond(res, 409, 'stale session');
    lastActive = body.client;
    const ret = emitIpc(body.ch, codec.decode(body.a), [], true);
    return respond(res, 200, JSON.stringify({ r: codec.encode(ret) }), TYPES['.json']);
  }

  let rel = decodeURIComponent(url.pathname);
  if (rel === '/' || rel === '') rel = '/index.html';
  if (rel === '/index.html') return respond(res, 200, getIndexHtml(), TYPES['.html']);
  const file = path.normalize(path.join(RENDERER, rel));
  if (!file.startsWith(RENDERER + path.sep)) return respond(res, 403, 'Forbidden');
  try {
    const data = read(file);
    return respond(res, 200, data, TYPES[path.extname(file).toLowerCase()] || 'application/octet-stream',
      { 'Cache-Control': rel.startsWith('/assets/') ? 'public, max-age=31536000, immutable' : 'no-store' });
  } catch {
    debug('404', rel);
    return respond(res, 404, 'Not found');
  }
}

// --- Custom-scheme proxy: /__relay/p/<secret>/<s|o>/<scheme>/<rest> -> <scheme>://<rest> (s) or <scheme>:<rest> (o)
const PASS_REQUEST = ['range', 'accept', 'if-none-match', 'if-modified-since'];
const PASS_RESPONSE = ['content-type', 'content-length', 'content-range', 'accept-ranges', 'etag', 'last-modified', 'cache-control'];
async function proxyScheme(req, res, url) {
  const rest = url.pathname.slice(`/__relay/p/${PROTO_SECRET}/`.length);
  const m = /^([so])\/([a-z][a-z0-9+.-]*)\/(.*)$/s.exec(rest);
  if (!m || !appSchemes.has(m[2])) return respond(res, 404, 'Unknown scheme');
  const [, kind, scheme, tail] = m;
  const target = `${scheme}:${kind === 's' ? '//' : ''}${tail}${url.search}`;
  const headers = {};
  for (const h of PASS_REQUEST) if (req.headers[h]) headers[h] = req.headers[h];
  let upstream;
  try {
    upstream = await electron.session.defaultSession.fetch(target, { method: req.method === 'HEAD' ? 'HEAD' : 'GET', headers });
  } catch (err) {
    log('scheme fetch failed:', scheme, err.message);
    return respond(res, 502, 'Scheme handler failed');
  }
  debug('scheme', scheme, upstream.status);
  const out = { 'X-Content-Type-Options': 'nosniff' };
  for (const h of PASS_RESPONSE) { const v = upstream.headers.get(h); if (v != null) out[h] = v; }
  // In the app these frames get their own origin; here they would share the relay's, so force an opaque one
  if (FRAME_SCHEMES.has(scheme)) {
    out['Content-Security-Policy'] = 'sandbox allow-scripts allow-forms allow-popups allow-popups-to-escape-sandbox allow-modals allow-downloads';
  }
  res.writeHead(upstream.status, out);
  if (!upstream.body || req.method === 'HEAD') return res.end();
  Readable.fromWeb(upstream.body).on('error', () => res.destroy()).pipe(res);
}

// --- Minimal RFC 6455 WebSocket (text frames, fragmentation, ping/pong, close) ----------------------
function sendTo(client, m) {
  if (!client.open) return;
  const payload = Buffer.from(JSON.stringify(m));
  const n = payload.length;
  const header = n < 126 ? Buffer.from([0x81, n])
    : n < 65536 ? Buffer.from([0x81, 126, n >> 8, n & 255])
      : (() => { const h = Buffer.alloc(10); h[0] = 0x81; h[1] = 127; h.writeBigUInt64BE(BigInt(n), 2); return h; })();
  client.socket.write(Buffer.concat([header, payload]));
}

function acceptWebSocket(req, socket) {
  const key = req.headers['sec-websocket-key'];
  const accept = crypto.createHash('sha1').update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11').digest('base64');
  socket.write(`HTTP/1.1 101 Switching Protocols\r\nUpgrade: websocket\r\nConnection: Upgrade\r\nSec-WebSocket-Accept: ${accept}\r\n\r\n`);
  socket.setNoDelay(true);
  const client = { socket, open: true, close() { if (this.open) { this.open = false; socket.end(Buffer.from([0x88, 0])); } } };
  let buf = Buffer.alloc(0);
  let fragments = [];
  socket.on('data', (chunk) => {
    buf = Buffer.concat([buf, chunk]);
    for (;;) {
      if (buf.length < 2) return;
      const fin = buf[0] & 0x80; const op = buf[0] & 0x0f; const masked = buf[1] & 0x80;
      let len = buf[1] & 0x7f; let off = 2;
      if (len === 126) { if (buf.length < 4) return; len = buf.readUInt16BE(2); off = 4; }
      else if (len === 127) { if (buf.length < 10) return; len = Number(buf.readBigUInt64BE(2)); off = 10; }
      const maskOff = off; if (masked) off += 4;
      if (buf.length < off + len) return;
      const data = Buffer.from(buf.subarray(off, off + len));
      if (masked) for (let i = 0; i < len; i++) data[i] ^= buf[maskOff + (i & 3)];
      buf = buf.subarray(off + len);
      if (op === 0x8) { client.close(); return; }
      if (op === 0x9) { socket.write(Buffer.concat([Buffer.from([0x8a, data.length]), data])); continue; }
      if (op === 0xa) continue;
      fragments.push(data);
      if (!fin) continue;
      const text = Buffer.concat(fragments).toString('utf8'); fragments = [];
      try { client.onmessage(JSON.parse(text)); } catch (err) { log('bad message from browser:', err.message); }
    }
  });
  socket.on('close', () => { client.open = false; client.onclose && client.onclose(); });
  socket.on('error', () => { client.open = false; });
  return client;
}

function onBrowserMessage(client, m) {
  if (load.clients.get(client.id) !== client) return;
  lastActive = client.id;
  if (m.t === 'ipc') {
    if (ONCE_PER_LOAD.has(m.ch)) {
      if (load.gates.has(m.ch)) return debug('swallowed repeat', m.ch, 'from', client.id);
      load.gates.add(m.ch);
    }
    emitIpc(m.ch, codec.decode(m.a), portsForBrowserIds(m.p, client.id), false);
  } else if (m.t === 'pm') {
    const rec = ports.get(m.id);
    if (!rec) return debug('message for unknown port', m.id);
    debug('port', m.id, '<- browser', client.id);
    rec.port.postMessage(codec.decode(m.d), portsForBrowserIds(m.p, client.id));
  } else if (m.t === 'pc') {
    const rec = ports.get(m.id);
    if (rec) { ports.delete(m.id); rec.port.close(); }
  } else if (m.t === 'inv') {
    const args = codec.decode(m.a);
    debug('invoke', m.ch, 'from', client.id);
    if (m.ch === 'sand:coordinator-port-request') {
      coordServeClient(client);
      return deliver(client, { t: 'inv', id: m.id, r: codec.encode(null) });
    }
    // The UI's reliability reports (mostly outcome "ok" telemetry): log the ones that are not ok, so
    // relay-specific breakage is visible. They are also sent upstream by the app.
    if (m.ch.endsWith(':reportClientFailure')) {
      const report = args[0];
      const bad = !report || typeof report !== 'object'
        || (report.outcome !== undefined && report.outcome !== 'ok')
        || Object.keys(report).some((k) => /error/i.test(k));
      if (bad) {
        log('client failure:', JSON.stringify(codec.encode(args)).slice(0, 1500));
      }
    }
    Promise.resolve().then(() => invokeIpc(m.ch, args))
      .then((r) => deliver(client, { t: 'inv', id: m.id, r: codec.encode(r) }))
      .catch((e) => { log('invoke failed:', m.ch, e && e.message); deliver(client, { t: 'inv', id: m.id, e: codec.encode(e) }); });
  }
}

const server = http.createServer((req, res) => {
  handle(req, res).catch((err) => { log('request failed:', req.url, err); if (!res.headersSent) respond(res, 500, 'relay error'); });
});
server.on('upgrade', (req, socket) => {
  const url = new URL(req.url, 'http://relay');
  const client = load && url.searchParams.get('session') === load.id && load.clients.get(url.searchParams.get('client'));
  if (url.pathname !== '/__relay/ws' || !authorized(req) || !client || client.ws) {
    socket.end('HTTP/1.1 403 Forbidden\r\n\r\n');
    return;
  }
  const ws = acceptWebSocket(req, socket);
  ws.onmessage = (m) => onBrowserMessage(client, m);
  ws.onclose = () => removeClient(client);
  client.ws = ws;
  debug('client', client.id, 'connected; flushing', client.queue.length, 'queued messages');
  while (client.queue.length && ws.open) sendTo(ws, client.queue.shift());
});
server.listen(PORT, '0.0.0.0', () => log(`listening on :${PORT}${TOKEN ? '' : ' (WARNING: no RELAY_TOKEN set, unauthenticated)'}`));

// --- Hand over to the official app ------------------------------------------------------------------
log('starting official app from', ASAR);
require(path.join(ASAR, 'dist', 'electron-main', 'main.cjs'));
