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

// --- Relay state: one "session" per load of the hidden main window ----------------------------------
let mainWin = null;
let mainReady = null;
let session = null;
let relayReload = false;
const ports = new Map();
let nextServerPortId = 1;

function newSession() {
  if (session && session.client) {
    sendTo(session.client, { t: relayReload ? 'superseded' : 'reload' });
    session.client.close();
  }
  for (const p of ports.values()) { try { p.close(); } catch {} }
  ports.clear();
  session = { id: crypto.randomUUID(), queue: [], client: null, claimed: false };
  debug('new session', session.id);
}

function toClient(m) {
  if (session.client && session.client.open) sendTo(session.client, m);
  else session.queue.push(m);
}

function bindPort(id, port) {
  ports.set(id, port);
  port.on('message', (e) => {
    debug('port', id, '-> browser');
    toClient({ t: 'pm', id, d: codec.encode(e.data), p: e.ports.map(registerPort) });
  });
  port.on('close', () => { if (ports.get(id) === port) { ports.delete(id); toClient({ t: 'pc', id }); } });
  port.start();
}
function registerPort(port) { const id = nextServerPortId++; bindPort(id, port); return id; }
function portsForBrowserIds(ids = []) {
  return ids.map((id) => { const { port1, port2 } = new MessageChannelMain(); bindPort(id, port1); return port2; });
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
  newSession();

  win.loadFile = () => win.loadURL(BLANK);
  wc.send = (channel, ...args) => { debug('main send', channel); toClient({ t: 'ipc', ch: channel, a: codec.encode(args) }); };
  wc.postMessage = (channel, message, transfer = []) => {
    debug('main postMessage', channel, `(${transfer.length} ports)`);
    toClient({ t: 'ipc', ch: channel, a: codec.encode([message]), p: transfer.map(registerPort) });
  };
  wc.on('did-start-navigation', (details) => {
    if (details.isMainFrame && !details.isSameDocument) { newSession(); relayReload = false; }
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
    if (session) toClient({ t: 'open', url: String(url) });
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
    if (session.claimed) {
      relayReload = true;
      const reloaded = new Promise((r) => mainWin.webContents.once('did-finish-load', r));
      mainWin.webContents.reload();
      await reloaded;
    }
    session.claimed = true;
    return respond(res, 200, JSON.stringify({
      id: session.id, argv: mainArgv, versions: process.versions,
      proto: { base: `./__relay/p/${PROTO_SECRET}/`, schemes: [...appSchemes] },
    }), TYPES['.json']);
  }
  if (req.method === 'POST' && url.pathname === '/__relay/sync') {
    const body = await readBody(req);
    if (body.session !== session.id) return respond(res, 409, 'stale session');
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

function onBrowserMessage(m) {
  if (m.t === 'ipc') emitIpc(m.ch, codec.decode(m.a), portsForBrowserIds(m.p), false);
  else if (m.t === 'pm') {
    const port = ports.get(m.id);
    if (!port) return debug('message for unknown port', m.id);
    debug('port', m.id, '<- browser');
    port.postMessage(codec.decode(m.d), portsForBrowserIds(m.p));
  } else if (m.t === 'pc') {
    const port = ports.get(m.id);
    if (port) { ports.delete(m.id); port.close(); }
  } else if (m.t === 'inv') {
    const args = codec.decode(m.a);
    const method = args[0] && typeof args[0] === 'object' && args[0].method ? `.${args[0].method}` : '';
    debug('invoke', m.ch + method);
    Promise.resolve().then(() => invokeIpc(m.ch, args))
      .then((r) => toClient({ t: 'inv', id: m.id, r: codec.encode(r) }))
      .catch((e) => { log('invoke failed:', m.ch + method, e && e.message); toClient({ t: 'inv', id: m.id, e: codec.encode(e) }); });
  }
}

const server = http.createServer((req, res) => {
  handle(req, res).catch((err) => { log('request failed:', req.url, err); if (!res.headersSent) respond(res, 500, 'relay error'); });
});
server.on('upgrade', (req, socket) => {
  const url = new URL(req.url, 'http://relay');
  if (url.pathname !== '/__relay/ws' || !authorized(req) || !session || url.searchParams.get('session') !== session.id) {
    socket.end('HTTP/1.1 403 Forbidden\r\n\r\n');
    return;
  }
  const client = acceptWebSocket(req, socket);
  client.onmessage = onBrowserMessage;
  if (session.client) session.client.close();
  session.client = client;
  debug('browser attached; flushing', session.queue.length, 'queued messages');
  while (session.queue.length && client.open) sendTo(client, session.queue.shift());
});
server.listen(PORT, '0.0.0.0', () => log(`listening on :${PORT}${TOKEN ? '' : ' (WARNING: no RELAY_TOKEN set, unauthenticated)'}`));

// --- Hand over to the official app ------------------------------------------------------------------
log('starting official app from', ASAR);
require(path.join(ASAR, 'dist', 'electron-main', 'main.cjs'));
