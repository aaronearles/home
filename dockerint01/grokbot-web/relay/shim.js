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

  // A session is one load of the hidden main window; the server reloads it for each new page load
  const session = syncPost('session', {});

  // --- WebSocket transport with an outbound queue until open
  const wsUrl = new URL('ws', base);
  wsUrl.protocol = wsUrl.protocol === 'https:' ? 'wss:' : 'ws:';
  wsUrl.searchParams.set('session', session.id);
  const ws = new WebSocket(wsUrl);
  const outbox = [];
  const send = (m) => (ws.readyState === 1 ? ws.send(JSON.stringify(m)) : outbox.push(m));
  ws.onopen = () => { while (outbox.length) ws.send(JSON.stringify(outbox.shift())); };
  ws.onclose = () => console.warn('[relay] connection closed');

  // --- MessagePort bridging: each relayed port is one end of a local MessageChannel
  const ports = new Map();
  let nextPortId = -1; // browser-allocated ids are negative, server-allocated positive
  function bindPort(id, port) {
    ports.set(id, port);
    port.onmessage = (e) => {
      const ids = [...e.ports].map((p) => { const nid = nextPortId--; bindPort(nid, p); return nid; });
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
    sendSync: (channel, ...args) => codec.decode(syncPost('sync', { session: session.id, ch: channel, a: codec.encode(args) }).r),
    invoke: (channel, ...args) => new Promise((resolve, reject) => {
      const id = nextInvoke++;
      invokes.set(id, { resolve, reject });
      send({ t: 'inv', id, ch: channel, a: codec.encode(args) });
    }),
    postMessage: (channel, message, transfer = []) => {
      const ids = transfer.map((p) => { const nid = nextPortId--; bindPort(nid, p); return nid; });
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
