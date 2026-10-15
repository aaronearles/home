// Browser side of the relay: a stand-in for the parts of require("electron") that the official
// preload.cjs uses, carried over one WebSocket (async IPC + MessagePorts) and sync XHR (sendSync).
// Loaded first in <head>, before the wrapped preload and the renderer bundle.
(function () {
  'use strict';
  const codec = window.__relayCodec;
  const base = new URL('./__relay/', document.baseURI);

  function syncPost(path, body) {
    const xhr = new XMLHttpRequest();
    xhr.open('POST', new URL(path, base), false); // sendSync must block, like Electron's
    xhr.setRequestHeader('Content-Type', 'application/json');
    xhr.send(JSON.stringify(body));
    if (xhr.status !== 200) throw new Error(`relay ${path} failed: ${xhr.status} ${xhr.responseText}`);
    return JSON.parse(xhr.responseText);
  }

  // Every page load is its own client of the shared hidden main window
  const session = syncPost('session', {});

  // --- WebSocket transport with an outbound queue until open
  const wsUrl = new URL('ws', base);
  wsUrl.protocol = wsUrl.protocol === 'https:' ? 'wss:' : 'ws:';
  wsUrl.searchParams.set('session', session.id);
  wsUrl.searchParams.set('client', session.client);
  const ws = new WebSocket(wsUrl);
  const outbox = [];
  const send = (m) => (ws.readyState === 1 ? ws.send(JSON.stringify(m)) : outbox.push(m));
  ws.onopen = () => { while (outbox.length) ws.send(JSON.stringify(outbox.shift())); };
  ws.onclose = () => console.warn('[relay] connection closed');

  // --- MessagePort bridging: each relayed port is one end of a local MessageChannel
  const ports = new Map();
  let portSeq = 0; // browser-allocated ids are "<client>:<n>", server-allocated are numbers
  const newPortId = () => `${session.client}:${++portSeq}`;
  function bindPort(id, port) {
    ports.set(id, port);
    port.onmessage = (e) => {
      const ids = [...e.ports].map((p) => { const nid = newPortId(); bindPort(nid, p); return nid; });
      send({ t: 'pm', id, d: codec.encode(e.data), p: ids });
    };
  }
  function portFromServer(id) {
    const ch = new MessageChannel();
    bindPort(id, ch.port1);
    return ch.port2;
  }

  // --- ipcRenderer
  const listeners = new Map();
  const invokes = new Map();
  let nextInvoke = 1;
  function addListener(channel, fn, once) {
    if (!listeners.has(channel)) listeners.set(channel, []);
    listeners.get(channel).push({ fn, once });
    return ipcRenderer;
  }
  function removeListener(channel, fn) {
    const l = listeners.get(channel);
    if (l) listeners.set(channel, l.filter((x) => x.fn !== fn));
    return ipcRenderer;
  }
  const ipcRenderer = {
    send: (channel, ...args) => send({ t: 'ipc', ch: channel, a: codec.encode(args) }),
    sendSync: (channel, ...args) => codec.decode(syncPost('sync', { session: session.id, client: session.client, ch: channel, a: codec.encode(args) }).r),
    invoke: (channel, ...args) => new Promise((resolve, reject) => {
      const id = nextInvoke++;
      invokes.set(id, { resolve, reject });
      send({ t: 'inv', id, ch: channel, a: codec.encode(args) });
    }),
    postMessage: (channel, message, transfer = []) => {
      const ids = transfer.map((p) => { const nid = newPortId(); bindPort(nid, p); return nid; });
      send({ t: 'ipc', ch: channel, a: codec.encode([message]), p: ids });
    },
    on: (channel, fn) => addListener(channel, fn, false),
    addListener: (channel, fn) => addListener(channel, fn, false),
    once: (channel, fn) => addListener(channel, fn, true),
    off: removeListener,
    removeListener,
    removeAllListeners: (channel) => { channel == null ? listeners.clear() : listeners.delete(channel); return ipcRenderer; },
  };

  ws.onmessage = (msg) => {
    const m = JSON.parse(msg.data);
    if (m.t === 'ipc') {
      const args = codec.decode(m.a);
      const event = { sender: ipcRenderer, senderId: 0, ports: (m.p || []).map(portFromServer) };
      for (const l of [...(listeners.get(m.ch) || [])]) {
        if (l.once) removeListener(m.ch, l.fn);
        try { l.fn(event, ...args); } catch (err) { console.error('[relay] listener for', m.ch, 'threw', err); }
      }
    } else if (m.t === 'pm') {
      const port = ports.get(m.id);
      if (port) port.postMessage(codec.decode(m.d), (m.p || []).map(portFromServer));
    } else if (m.t === 'pc') {
      const port = ports.get(m.id);
      if (port) { port.close(); ports.delete(m.id); }
    } else if (m.t === 'inv') {
      const p = invokes.get(m.id);
      if (p) { invokes.delete(m.id); m.e ? p.reject(codec.decode(m.e)) : p.resolve(codec.decode(m.r)); }
    } else if (m.t === 'reload') {
      location.reload();
    } else if (m.t === 'open') {
      openExternal(m.url);
    }
  };

  // shell.openExternal from the app: try a new tab; popup blockers allow it only right after a click,
  // so also show a banner with the link for when the round trip took too long
  function openExternal(url) {
    const w = window.open(url, '_blank');
    if (w) { try { w.opener = null; } catch {} }
    let bar = document.getElementById('relay-open-banner');
    if (!bar) {
      bar = document.createElement('div');
      bar.id = 'relay-open-banner';
      bar.style.cssText = 'position:fixed;left:50%;bottom:24px;transform:translateX(-50%);z-index:2147483647;'
        + 'background:#111;color:#fff;font:14px system-ui,sans-serif;padding:10px 14px;border-radius:10px;'
        + 'box-shadow:0 4px 16px rgba(0,0,0,.3);display:flex;gap:12px;align-items:center;max-width:calc(100vw - 32px)';
      document.body.appendChild(bar);
    }
    bar.replaceChildren();
    const a = document.createElement('a');
    a.href = url; a.target = '_blank'; a.rel = 'noopener'; a.textContent = 'Open link from Grok Bot';
    a.style.cssText = 'color:#8ab4ff;font-weight:600;white-space:nowrap';
    const host = document.createElement('span');
    host.textContent = new URL(url).host; host.style.cssText = 'opacity:.7;overflow:hidden;text-overflow:ellipsis';
    const x = document.createElement('button');
    x.textContent = '×'; x.style.cssText = 'background:none;border:0;color:#fff;font-size:18px;cursor:pointer';
    x.onclick = () => bar.remove();
    a.onclick = () => setTimeout(() => bar.remove(), 0);
    bar.append(a, host, x);
  }

  // --- Custom schemes the app serves itself (sand-media://, sand-avatar:, ...) cannot load in a browser;
  // rewrite them to the relay's proxy wherever the UI can hand a URL to the page
  const proto = session.proto || { base: '', schemes: [] };
  const protoBase = new URL(proto.base, document.baseURI).href;
  const schemeRe = proto.schemes.length
    ? new RegExp('^(' + proto.schemes.map((s) => s.replace(/[.+-]/g, '\\$&')).join('|') + '):(//)?', 'i') : null;
  function rewrite(value) {
    if (!schemeRe || value == null) return value;
    const s = String(value);
    const m = schemeRe.exec(s);
    if (!m) return value;
    return protoBase + (m[2] ? 's/' : 'o/') + m[1].toLowerCase() + '/' + s.slice(m[0].length);
  }
  const rewriteSrcset = (v) => String(v).split(',').map((c) => {
    const parts = c.trim().split(/\s+/);
    parts[0] = rewrite(parts[0]);
    return parts.join(' ');
  }).join(', ');
  const rewriteCss = (v) => (typeof v === 'string' && v.includes('url(')
    ? v.replace(/url\((['"]?)([^'")]+)\1\)/g, (all, q, u) => `url(${q}${rewrite(u)}${q})`) : v);

  if (schemeRe) {
    const URL_ATTRS = { src: rewrite, href: rewrite, poster: rewrite, data: rewrite, srcset: rewriteSrcset };
    const setAttribute = Element.prototype.setAttribute;
    Element.prototype.setAttribute = function (name, value) {
      const fn = URL_ATTRS[String(name).toLowerCase()];
      return setAttribute.call(this, name, fn ? fn(value) : value);
    };
    const patchProp = (ctor, prop, fn) => {
      const d = ctor && Object.getOwnPropertyDescriptor(ctor.prototype, prop);
      if (!d || !d.set) return;
      Object.defineProperty(ctor.prototype, prop, { ...d, set(v) { d.set.call(this, fn(v)); } });
    };
    for (const C of [window.HTMLImageElement, window.HTMLMediaElement, window.HTMLSourceElement, window.HTMLIFrameElement,
      window.HTMLEmbedElement, window.HTMLTrackElement, window.HTMLInputElement]) patchProp(C, 'src', rewrite);
    patchProp(window.HTMLImageElement, 'srcset', rewriteSrcset);
    patchProp(window.HTMLSourceElement, 'srcset', rewriteSrcset);
    patchProp(window.HTMLVideoElement, 'poster', rewrite);
    patchProp(window.HTMLObjectElement, 'data', rewrite);
    patchProp(window.HTMLAnchorElement, 'href', rewrite);
    patchProp(window.HTMLLinkElement, 'href', rewrite);
    for (const p of ['backgroundImage', 'background', 'maskImage', 'listStyleImage', 'content', 'cssText']) {
      patchProp(window.CSSStyleDeclaration, p, rewriteCss);
    }
    const setProperty = CSSStyleDeclaration.prototype.setProperty;
    CSSStyleDeclaration.prototype.setProperty = function (name, value, prio) {
      return setProperty.call(this, name, rewriteCss(value), prio);
    };
    const fetch0 = window.fetch;
    window.fetch = function (input, init) {
      if (typeof input === 'string' || input instanceof URL) input = rewrite(String(input));
      else if (input instanceof Request && schemeRe.test(input.url)) input = new Request(rewrite(input.url), input);
      return fetch0.call(this, input, init);
    };
    const open0 = XMLHttpRequest.prototype.open;
    XMLHttpRequest.prototype.open = function (method, url, ...rest) { return open0.call(this, method, rewrite(url), ...rest); };
  }

  // --- Chromium-only APIs the renderer assumes (it is built for Electron) ---
  // ResizeObserver box "device-pixel-content-box": Safari throws a TypeError on observe(). Fall back to
  // content-box and derive devicePixelContentBoxSize from it and devicePixelRatio.
  function installResizeObserverFallback(win) {
    const RO = win.ResizeObserver;
    if (!RO) return false;
    try {
      const probe = new RO(() => {});
      probe.observe(win.document.documentElement, { box: 'device-pixel-content-box' });
      probe.disconnect();
      return false;
    } catch { /* unsupported: install the fallback */ }
    const devicePixelBox = (sizes) => [...(sizes || [])].map((s) => ({
      inlineSize: Math.round(s.inlineSize * win.devicePixelRatio),
      blockSize: Math.round(s.blockSize * win.devicePixelRatio),
    }));
    const withDevicePixelBox = (e) => (e.devicePixelContentBoxSize ? e : {
      target: e.target, contentRect: e.contentRect, borderBoxSize: e.borderBoxSize,
      contentBoxSize: e.contentBoxSize, devicePixelContentBoxSize: devicePixelBox(e.contentBoxSize),
    });
    win.ResizeObserver = class ResizeObserver extends RO {
      constructor(callback) { super((entries, observer) => callback(entries.map(withDevicePixelBox), observer)); }
      observe(target, options) {
        if (options && options.box === 'device-pixel-content-box') options = { ...options, box: 'content-box' };
        return super.observe(target, options);
      }
    };
    return true;
  }
  if (installResizeObserverFallback(window)) console.info('[relay] ResizeObserver device-pixel-content-box fallback active');
  window.__relayInstallResizeObserverFallback = installResizeObserverFallback; // for tools/ tests

  window.__relayElectron = {
    ipcRenderer,
    contextBridge: { exposeInMainWorld: (key, api) => { window[key] = api; } },
    webFrame: { getZoomFactor: () => 1, setZoomFactor: () => {}, getZoomLevel: () => 0, setZoomLevel: () => {} },
    // No disk paths in a browser: the preload falls back to uploading the file's bytes
    webUtils: { getPathForFile: () => '' },
  };
  window.__relayProcess = {
    platform: 'linux',
    type: 'renderer',
    env: {},
    argv: session.argv || [],
    versions: session.versions || {},
    cwd: () => '/',
  };
})();
