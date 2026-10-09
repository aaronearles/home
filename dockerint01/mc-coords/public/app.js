// mc-coords client — vanilla JS, no build step.

// ------------------------------------------------------------------ storage
const LS = {
  get(key, fallback) {
    try { const v = localStorage.getItem(key); return v === null ? fallback : JSON.parse(v); }
    catch { return fallback; }
  },
  set(key, value) { try { localStorage.setItem(key, JSON.stringify(value)); } catch { /* quota/private mode */ } },
  del(key) { try { localStorage.removeItem(key); } catch { /* ignore */ } },
};

const prefs = {
  get player() { return LS.get('player', ''); },
  set player(v) { LS.set('player', v); },
  get worlds() { return LS.get('worlds', []); },
  set worlds(v) { LS.set('worlds', v); },
  get current() { return LS.get('currentWorld', null); },
  set current(v) { LS.set('currentWorld', v); },
  get copyFormat() { return LS.get('copyFormat', 'xyz'); },
  set copyFormat(v) { LS.set('copyFormat', v); },
};

const DIMS = {
  overworld: { label: 'Overworld', short: 'Over', group: 'Overworld' },
  nether: { label: 'Nether', short: 'Nether', group: 'Nether' },
  end: { label: 'The End', short: 'End', group: 'The End' },
};

const EMOJI_PICKS = ['🏠','🟪','🏘️','🌾','⚙️','⛏️','💀','⛰️','🏯','🏰','🌀','🔱','📍','🧪','📦','🛏️','🐄','🐑','🐔','🐝','🌲','🌋','🏜️','❄️','🌊','🏝️','⛵','💎','🪙','🔥','🗺️','⭐','⚔️','🛡️','🧱','🚂','🗿','🍄','🌸','🎣'];

// ------------------------------------------------------------------ helpers
const $ = (sel, root = document) => root.querySelector(sel);
const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const esc = (s) => String(s ?? '').replace(/[&<>"']/g, (c) => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c]));

let toastTimer;
function toast(msg, isError = false) {
  const el = $('#toast');
  el.textContent = msg;
  el.classList.toggle('error', isError);
  el.classList.add('show');
  clearTimeout(toastTimer);
  toastTimer = setTimeout(() => el.classList.remove('show'), 2600);
}

async function api(method, url, body, { raw = false, contentType } = {}) {
  const headers = { 'X-Player': encodeURIComponent(prefs.player || '') };
  let payload;
  if (body instanceof Blob) { payload = body; headers['Content-Type'] = contentType || body.type; }
  else if (body !== undefined) { payload = JSON.stringify(body); headers['Content-Type'] = 'application/json'; }
  let res;
  try { res = await fetch(url, { method, headers, body: payload }); }
  catch { throw new Error('You appear to be offline'); }
  if (raw) return res;
  const data = await res.json().catch(() => ({}));
  if (!res.ok) { const e = new Error(data.error || `Request failed (${res.status})`); e.status = res.status; throw e; }
  return data;
}

const fmtNum = (n) => String(n);
const toNether = (v) => Math.floor(v / 8);
const fromNether = (v) => v * 8;

function coordText(l) {
  switch (prefs.copyFormat) {
    case 'comma': return `${l.x}, ${l.y}, ${l.z}`;
    case 'tp': return `/tp @s ${l.x} ${l.y} ${l.z}`;
    default: return `${l.x} ${l.y} ${l.z}`;
  }
}

async function copy(text) {
  try { await navigator.clipboard.writeText(text); toast(`Copied: ${text}`); }
  catch {
    const ta = document.createElement('textarea');
    ta.value = text; document.body.append(ta); ta.select();
    try { document.execCommand('copy'); toast(`Copied: ${text}`); } catch { toast('Copy failed', true); }
    ta.remove();
  }
}

function conversionHint(l) {
  if (l.dimension === 'overworld') return `Nether ≈ ${toNether(l.x)}, ${l.y}, ${toNether(l.z)}`;
  if (l.dimension === 'nether') return `Overworld ≈ ${fromNether(l.x)}, ${l.y}, ${fromNether(l.z)}`;
  return '';
}

const fmtDate = (t) => new Date(t).toLocaleDateString(undefined, { month: 'short', day: 'numeric', year: 'numeric' });

// ------------------------------------------------------------------ state
const state = {
  data: null, // { world, categories, locations }
  view: 'coords',
  listTab: 'bookmarks',
  search: '',
  mapDim: 'overworld',
  selected: null,
  es: null,
};

const catById = (id) => state.data?.categories.find((c) => c.id === id);
const locById = (id) => state.data?.locations.find((l) => l.id === id);
const fallbackCat = { icon: '📍', color: '#8b949e', name: '' };
const catOf = (l) => catById(l.category_id) || fallbackCat;
const imgUrl = (name) => `/api/worlds/${state.data.world.id}/images/${name}`;

function rememberWorld(world) {
  const list = prefs.worlds.filter((w) => w.id !== world.id);
  list.unshift({ id: world.id, name: world.name });
  prefs.worlds = list;
}

function forgetWorld(id) {
  prefs.worlds = prefs.worlds.filter((w) => w.id !== id);
  LS.del(`cache:${id}`);
  if (prefs.current === id) prefs.current = prefs.worlds[0]?.id ?? null;
}

function setData(data) {
  state.data = data;
  LS.set(`cache:${data.world.id}`, data);
  rememberWorld(data.world);
  render();
}

async function loadWorld(id, { quiet = false } = {}) {
  prefs.current = id;
  const cached = LS.get(`cache:${id}`, null);
  if (cached && !state.data) { state.data = cached; render(); }
  try {
    setData(await api('GET', `/api/worlds/${id}`));
    connectLive(id);
  } catch (e) {
    if (e.status === 404) {
      toast('That world no longer exists', true);
      forgetWorld(id);
      state.data = null;
      return boot();
    }
    if (!quiet) toast(cached ? 'Offline — showing saved copy' : e.message, !cached);
    if (cached) { state.data = cached; render(); }
  }
}

let refreshTimer;
function connectLive(id) {
  state.es?.close();
  const es = new EventSource(`/api/worlds/${id}/events`);
  state.es = es;
  const dot = $('#live-dot');
  es.onopen = () => dot.classList.add('on');
  es.onerror = () => dot.classList.remove('on');
  es.onmessage = (ev) => {
    let msg; try { msg = JSON.parse(ev.data); } catch { return; }
    const mine = msg.by === (prefs.player || 'Someone');
    if (msg.type === 'deleted') {
      if (!mine) toast(`${msg.by} deleted this world`, true);
      forgetWorld(id); state.data = null; es.close(); return boot();
    }
    if (msg.type === 'joined' && !mine) toast(`${msg.by} joined the world 🎉`);
    if (msg.type === 'change') {
      clearTimeout(refreshTimer);
      refreshTimer = setTimeout(async () => {
        try { setData(await api('GET', `/api/worlds/${id}`)); } catch { /* ignore */ }
      }, 250);
    }
  };
}

// Mutations re-fetch the whole (small) world state; SSE keeps other devices in step.
async function mutate(fn, okMsg) {
  try {
    await fn();
    setData(await api('GET', `/api/worlds/${state.data.world.id}`));
    if (okMsg) toast(okMsg);
    return true;
  } catch (e) { toast(e.message, true); return false; }
}

// ------------------------------------------------------------------ rendering
function render() {
  if (!state.data) return;
  $('#world-title').textContent = state.data.world.name;
  document.title = `${state.data.world.name} · Coords`;
  if (state.view === 'coords') renderList();
  if (state.view === 'map') { renderMapSearch(); map.draw(); renderSheet(); }
  if (state.view === 'settings') renderSettings();
}

function setView(v) {
  state.view = v;
  for (const id of ['coords', 'map', 'settings']) $(`#view-${id}`).hidden = id !== v;
  $$('#bottombar button').forEach((b) => b.classList.toggle('active', b.dataset.view === v));
  if (v === 'map') map.resize();
  render();
}

function chipsHtml(l, { removable = false } = {}) {
  const rel = l.related.map(locById).filter(Boolean);
  if (!rel.length) return '';
  return `<div class="chips">${rel.map((r) => {
    const c = catOf(r);
    return `<span class="chip" data-goto="${r.id}"><span class="dot" style="background:${esc(c.color)}">${esc(c.icon)}</span><span class="label">${esc(r.name)}</span>${removable ? `<button class="x" data-unlink="${r.id}" aria-label="Remove">×</button>` : ''}</span>`;
  }).join('')}</div>`;
}

const copyIcon = '<svg viewBox="0 0 24 24"><rect x="9" y="9" width="12" height="12" rx="2"/><path d="M5 15H4a1 1 0 0 1-1-1V4a1 1 0 0 1 1-1h10a1 1 0 0 1 1 1v1"/></svg>';
const heartIcon = '<svg viewBox="0 0 24 24"><path d="M12 21s-7.5-4.6-9.6-9.2C.9 8.4 3 4.5 6.7 4.5c2.1 0 3.6 1.1 5.3 3 1.7-1.9 3.2-3 5.3-3 3.7 0 5.8 3.9 4.3 7.3C19.5 16.4 12 21 12 21z"/></svg>';

function locRowHtml(l) {
  const c = catOf(l);
  const catLabel = c.name && c.name !== l.name ? `<small>(${esc(c.name)})</small>` : '';
  return `<div class="loc" data-id="${l.id}">
    <div class="loc-icon" style="color:${esc(c.color)}">${esc(c.icon)}</div>
    <div class="loc-name">${esc(l.name)}${catLabel}</div>
    <div class="loc-side"><button class="heart ${l.favorite ? 'on' : ''}" data-fav="${l.id}" aria-label="Bookmark">${heartIcon}</button></div>
    <div class="loc-coords"><span>${fmtNum(l.x)}</span><span>${fmtNum(l.y)}</span><span>${fmtNum(l.z)}</span>
      <button class="copy" data-copy="${l.id}" aria-label="Copy coordinates">${copyIcon}</button></div>
    ${l.related.length ? `<div class="loc-chips">${chipsHtml(l)}</div>` : ''}
  </div>`;
}

function matches(l, q) {
  if (!q) return true;
  const c = catOf(l);
  return [l.name, l.notes, c.name, `${l.x} ${l.y} ${l.z}`].some((s) => s?.toLowerCase().includes(q));
}

function renderList() {
  const q = state.search.trim().toLowerCase();
  const locs = state.data.locations.filter((l) => matches(l, q));
  const el = $('#list');
  let html = '';
  if (state.listTab === 'bookmarks') {
    for (const d of Object.keys(DIMS)) {
      const items = locs.filter((l) => l.favorite && l.dimension === d);
      if (items.length) html += `<div class="group-title">${DIMS[d].group}</div>${items.map(locRowHtml).join('')}`;
    }
    if (!html) html = `<div class="empty"><div class="big">💜</div>${q ? 'No bookmarks match your search.' : 'Tap the heart on a location to bookmark it here.'}</div>`;
  } else {
    const items = locs.filter((l) => l.dimension === state.listTab);
    // Group by category, ordered by category sort.
    const groups = new Map();
    for (const l of items) {
      const key = l.category_id ?? 0;
      if (!groups.has(key)) groups.set(key, []);
      groups.get(key).push(l);
    }
    const order = [...groups.keys()].sort((a, b) => (catById(a)?.sort ?? 999) - (catById(b)?.sort ?? 999));
    for (const k of order) {
      const c = catById(k);
      html += `<div class="group-title">${c ? `${esc(c.icon)} ${esc(c.name)}` : 'Uncategorized'}</div>${groups.get(k).map(locRowHtml).join('')}`;
    }
    if (!html) html = `<div class="empty"><div class="big">🧭</div>${q ? 'Nothing matches your search.' : `No ${DIMS[state.listTab].label} locations yet.<br>Tap + to add one.`}</div>`;
  }
  el.innerHTML = html;
}

async function toggleFavorite(id) {
  const l = locById(id);
  if (!l) return;
  l.favorite = !l.favorite; // optimistic
  render();
  await mutate(() => api('PATCH', `/api/worlds/${state.data.world.id}/locations/${id}`, { favorite: l.favorite }));
}

// ------------------------------------------------------------------ modals
function openModal(html, { full = false, onClose, dismissable = true } = {}) {
  const root = $('#modal-root');
  const backdrop = document.createElement('div');
  backdrop.className = 'modal-backdrop';
  backdrop.innerHTML = `<div class="modal ${full ? 'full' : ''}">${html}</div>`;
  root.append(backdrop);
  const modal = backdrop.firstElementChild;
  const close = () => { backdrop.remove(); onClose?.(); };
  if (dismissable) backdrop.addEventListener('click', (e) => { if (e.target === backdrop) close(); });
  $$('[data-close]', modal).forEach((b) => b.addEventListener('click', close));
  return { modal, close };
}

const closeBtn = '<button class="icon-btn" data-close aria-label="Close"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6 6 18"/></svg></button>';

// Pull three integers (and maybe a dimension) out of anything: F3+C, chat, "x: 1 y: 2 z: 3"...
function parseCoords(text) {
  const nums = (text.match(/-?\d+(?:\.\d+)?/g) || []).map(Number);
  let dim;
  if (/the_nether|nether/i.test(text)) dim = 'nether';
  else if (/the_end|\bend\b/i.test(text)) dim = 'end';
  else if (/overworld/i.test(text)) dim = 'overworld';
  if (nums.length < 2) return null;
  if (nums.length === 2) return { x: Math.floor(nums[0]), z: Math.floor(nums[1]), dim };
  return { x: Math.floor(nums[0]), y: Math.floor(nums[1]), z: Math.floor(nums[2]), dim };
}

async function resizeImage(file, max = 1600) {
  const url = URL.createObjectURL(file);
  try {
    const img = await new Promise((resolve, reject) => {
      const i = new Image(); i.onload = () => resolve(i); i.onerror = reject; i.src = url;
    });
    const scale = Math.min(1, max / Math.max(img.naturalWidth, img.naturalHeight));
    const canvas = document.createElement('canvas');
    canvas.width = Math.round(img.naturalWidth * scale);
    canvas.height = Math.round(img.naturalHeight * scale);
    canvas.getContext('2d').drawImage(img, 0, 0, canvas.width, canvas.height);
    return await new Promise((resolve) => canvas.toBlob(resolve, 'image/jpeg', 0.82));
  } finally { URL.revokeObjectURL(url); }
}

function openEditor(loc, preset = {}) {
  const isNew = !loc;
  const d = state.data;
  const draft = loc ? { ...loc, related: [...loc.related] } : {
    name: '', dimension: preset.dimension || 'overworld',
    x: preset.x ?? '', y: preset.y ?? 64, z: preset.z ?? '',
    category_id: d.categories.find((c) => c.name === 'Other')?.id ?? null,
    notes: '', related: [], favorite: false, image: null,
  };
  let pendingImage = null; // Blob
  let removeImage = false;

  const heroImg = () => (pendingImage ? URL.createObjectURL(pendingImage) : (!removeImage && draft.image ? imgUrl(draft.image) : null));

  const html = `
    <div class="modal-head ${draft.image ? 'hero' : ''}" id="ed-head">
      ${closeBtn}
      <h2>${isNew ? 'New Location' : esc(loc.name)}</h2>
      <span></span>
      ${!isNew ? `<div class="meta">Last edited by ${esc(loc.updated_by || 'someone')} on ${fmtDate(loc.updated_at)}</div>` : ''}
    </div>
    <div class="modal-body">
      <div class="field">
        <label for="ed-paste">Quick paste <span style="opacity:.7">(F3+C, chat, “x y z”…)</span></label>
        <input class="input" id="ed-paste" placeholder="Paste coordinates here" autocomplete="off">
      </div>
      <div class="field">
        <label for="ed-name">Location Name</label>
        <input class="input" id="ed-name" value="${esc(draft.name)}" maxlength="80" placeholder="e.g. Main Base" autocomplete="off">
      </div>
      <div class="field">
        <span class="field-label">Dimension</span>
        <div class="seg" id="ed-dim">${Object.entries(DIMS).map(([k, v]) => `<button type="button" data-dim="${k}" class="${draft.dimension === k ? 'active' : ''}">${v.short}</button>`).join('')}</div>
      </div>
      <div class="field">
        <span class="field-label">Coordinates</span>
        <div class="xyz">
          ${['x', 'y', 'z'].map((k) => `<div class="coord"><span class="axis">${k.toUpperCase()}</span>
            <input class="input" id="ed-${k}" inputmode="numeric" pattern="-?[0-9]*" value="${esc(draft[k])}" autocomplete="off">
            <button type="button" class="neg" data-neg="${k}" aria-label="Toggle negative">±</button></div>`).join('')}
        </div>
        <div class="hint" id="ed-convert"></div>
      </div>
      <div class="field">
        <span class="field-label">Location Category</span>
        <div class="row">
          <select class="input grow" id="ed-cat">
            <option value="">— None —</option>
            ${d.categories.map((c) => `<option value="${c.id}" ${c.id === draft.category_id ? 'selected' : ''}>${esc(c.icon)}  ${esc(c.name)}</option>`).join('')}
          </select>
          <button type="button" class="btn teal" id="ed-editcat">✎ Edit</button>
        </div>
      </div>
      <div class="field">
        <span class="field-label">Related Locations</span>
        <select class="input" id="ed-rel-add"></select>
        <div id="ed-rel"></div>
      </div>
      <div class="field">
        <label for="ed-notes">Notes</label>
        <textarea class="input" id="ed-notes" maxlength="4000" placeholder="Chest contents, directions, who built it…">${esc(draft.notes)}</textarea>
        <div class="photo" id="ed-photo"></div>
      </div>
      ${!isNew ? '<button type="button" class="btn danger block" id="ed-delete">Delete location</button>' : ''}
    </div>
    <div class="modal-foot"><button class="btn primary grow" id="ed-save">Save</button></div>`;

  const { modal, close } = openModal(html, { full: true });
  const f = (id) => $(`#ed-${id}`, modal);

  const readDraft = () => {
    draft.name = f('name').value;
    for (const k of ['x', 'y', 'z']) draft[k] = f(k).value;
    draft.notes = f('notes').value;
    draft.category_id = f('cat').value ? Number(f('cat').value) : null;
  };

  const updateConvert = () => {
    readDraft();
    const x = parseInt(draft.x, 10); const z = parseInt(draft.z, 10);
    f('convert').textContent = Number.isFinite(x) && Number.isFinite(z)
      ? conversionHint({ ...draft, x, z, y: parseInt(draft.y, 10) || 0 }) : '';
  };

  const renderRelated = () => {
    const others = d.locations.filter((l) => l.id !== draft.id && !draft.related.includes(l.id));
    f('rel-add').innerHTML = `<option value="">${draft.related.length ? `${draft.related.length} selected — add more…` : 'Add a related location…'}</option>`
      + others.map((l) => `<option value="${l.id}">${esc(catOf(l).icon)}  ${esc(l.name)} (${DIMS[l.dimension].short})</option>`).join('');
    f('rel').innerHTML = chipsHtml({ related: draft.related }, { removable: true });
  };

  const renderPhoto = () => {
    const src = heroImg();
    f('photo').innerHTML = src
      ? `<img src="${esc(src)}" alt=""><button type="button" class="linkish" id="ed-photo-rm">Remove image</button>`
      : '<label class="btn photo-btn">📷 Add photo<input type="file" accept="image/*" id="ed-file"></label>';
    const head = f('head');
    head.classList.toggle('hero', !!src);
    head.style.backgroundImage = src ? `url("${src}")` : '';
  };

  f('paste').addEventListener('input', () => {
    const p = parseCoords(f('paste').value);
    if (!p) return;
    f('x').value = p.x; f('z').value = p.z;
    if (p.y !== undefined) f('y').value = p.y;
    if (p.dim) {
      draft.dimension = p.dim;
      $$('#ed-dim button', modal).forEach((b) => b.classList.toggle('active', b.dataset.dim === p.dim));
    }
    updateConvert();
    toast('Coordinates filled in');
  });
  $('#ed-dim', modal).addEventListener('click', (e) => {
    const b = e.target.closest('button[data-dim]'); if (!b) return;
    draft.dimension = b.dataset.dim;
    $$('#ed-dim button', modal).forEach((x) => x.classList.toggle('active', x === b));
    updateConvert();
  });
  $$('[data-neg]', modal).forEach((b) => b.addEventListener('click', () => {
    const input = f(b.dataset.neg);
    const v = input.value.trim();
    input.value = v.startsWith('-') ? v.slice(1) : `-${v}`;
    updateConvert();
  }));
  ['x', 'y', 'z'].forEach((k) => f(k).addEventListener('input', updateConvert));
  f('rel-add').addEventListener('change', () => {
    const v = Number(f('rel-add').value);
    if (v) { draft.related.push(v); renderRelated(); }
  });
  f('rel').addEventListener('click', (e) => {
    const b = e.target.closest('[data-unlink]'); if (!b) return;
    draft.related = draft.related.filter((r) => r !== Number(b.dataset.unlink));
    renderRelated();
  });
  f('photo').addEventListener('change', async (e) => {
    if (e.target.id !== 'ed-file' || !e.target.files[0]) return;
    try { pendingImage = await resizeImage(e.target.files[0]); removeImage = false; renderPhoto(); }
    catch { toast('Could not read that image', true); }
  });
  f('photo').addEventListener('click', (e) => {
    if (e.target.id !== 'ed-photo-rm') return;
    pendingImage = null; removeImage = true; renderPhoto();
  });
  f('editcat').addEventListener('click', () => openCategories(() => {
    // refresh the select after categories change
    readDraft();
    f('cat').innerHTML = `<option value="">— None —</option>${state.data.categories.map((c) => `<option value="${c.id}" ${c.id === draft.category_id ? 'selected' : ''}>${esc(c.icon)}  ${esc(c.name)}</option>`).join('')}`;
  }));
  f('delete')?.addEventListener('click', async () => {
    if (!confirm(`Delete “${loc.name}” for everyone in this world?`)) return;
    const ok = await mutate(() => api('DELETE', `/api/worlds/${d.world.id}/locations/${loc.id}`), 'Location deleted');
    if (ok) { if (state.selected === loc.id) state.selected = null; close(); render(); }
  });
  f('save').addEventListener('click', async () => {
    readDraft();
    if (!draft.name.trim()) { toast('Give it a name', true); f('name').focus(); return; }
    for (const k of ['x', 'z']) {
      if (!/^\s*-?\d+(\.\d+)?\s*$/.test(String(draft[k]))) { toast(`${k.toUpperCase()} must be a number`, true); f(k).focus(); return; }
    }
    if (draft.y === '' || draft.y === null) draft.y = 64;
    const body = {
      name: draft.name, dimension: draft.dimension, x: Number(draft.x), y: Number(draft.y), z: Number(draft.z),
      category_id: draft.category_id, notes: draft.notes, related: draft.related, favorite: draft.favorite,
    };
    f('save').disabled = true;
    const base = `/api/worlds/${d.world.id}/locations`;
    const ok = await mutate(async () => {
      const id = isNew ? (await api('POST', base, body)).id : (await api('PATCH', `${base}/${loc.id}`, body), loc.id);
      if (pendingImage) await api('PUT', `${base}/${id}/image`, pendingImage, { contentType: 'image/jpeg' });
      else if (removeImage && draft.image) await api('DELETE', `${base}/${id}/image`);
      draft.id = id;
    }, isNew ? 'Location added' : 'Saved');
    f('save').disabled = false;
    if (ok) {
      close();
      if (state.view === 'map') { state.selected = draft.id; render(); }
    }
  });

  renderRelated();
  renderPhoto();
  updateConvert();
  if (isNew) setTimeout(() => f('name').focus(), 250);
}

function openCategories(onDone) {
  const wid = () => state.data.world.id;
  const rowHtml = (c) => `<div class="cat-row" data-cid="${c.id}">
      <input class="input emoji" value="${esc(c.icon)}" maxlength="8" data-k="icon" aria-label="Icon">
      <input class="input" value="${esc(c.name)}" maxlength="40" data-k="name" aria-label="Name">
      <input type="color" value="${esc(c.color)}" data-k="color" aria-label="Color">
      <button class="icon-btn" data-del="${c.id}" aria-label="Delete"><svg viewBox="0 0 24 24"><path d="M4 7h16M9 7V4h6v3M6 7l1 13h10l1-13"/></svg></button>
    </div>`;
  const { modal } = openModal(`
    <div class="modal-head">${closeBtn}<h2>Categories</h2><span></span></div>
    <div class="modal-body">
      <div id="cat-list">${state.data.categories.map(rowHtml).join('')}</div>
      <div class="field-label" style="margin-top:18px">Add a category</div>
      <div class="cat-row">
        <input class="input emoji" id="new-icon" value="📍" maxlength="8" aria-label="Icon">
        <input class="input" id="new-name" maxlength="40" placeholder="Name" aria-label="Name">
        <input type="color" id="new-color" value="#b388ff" aria-label="Color">
        <button class="icon-btn" id="new-add" aria-label="Add"><svg viewBox="0 0 24 24"><path d="M12 5v14M5 12h14"/></svg></button>
      </div>
      <div class="emoji-picks" id="emoji-picks">${EMOJI_PICKS.map((e) => `<button type="button">${e}</button>`).join('')}</div>
      <div class="hint">Tap an emoji to use it for the new category, or type any emoji into an icon box. Changes save automatically.</div>
    </div>`, { onClose: onDone });

  let lastIconInput = $('#new-icon', modal);
  modal.addEventListener('focusin', (e) => { if (e.target.classList.contains('emoji')) lastIconInput = e.target; });
  $('#emoji-picks', modal).addEventListener('click', (e) => {
    const b = e.target.closest('button'); if (!b) return;
    lastIconInput.value = b.textContent;
    lastIconInput.dispatchEvent(new Event('change', { bubbles: true }));
  });
  $('#cat-list', modal).addEventListener('change', async (e) => {
    const row = e.target.closest('[data-cid]'); if (!row || !e.target.dataset.k) return;
    const v = e.target.value.trim(); if (!v) return;
    await mutate(() => api('PATCH', `/api/worlds/${wid()}/categories/${row.dataset.cid}`, { [e.target.dataset.k]: v }));
  });
  $('#cat-list', modal).addEventListener('click', async (e) => {
    const b = e.target.closest('[data-del]'); if (!b) return;
    const c = catById(Number(b.dataset.del));
    const used = state.data.locations.filter((l) => l.category_id === c.id).length;
    if (!confirm(`Delete “${c.name}”?${used ? ` ${used} location(s) will become uncategorized.` : ''}`)) return;
    if (await mutate(() => api('DELETE', `/api/worlds/${wid()}/categories/${c.id}`))) b.closest('.cat-row').remove();
  });
  $('#new-add', modal).addEventListener('click', async () => {
    const name = $('#new-name', modal).value.trim();
    if (!name) { toast('Name the category', true); return; }
    const body = { name, icon: $('#new-icon', modal).value.trim() || '📍', color: $('#new-color', modal).value };
    if (await mutate(() => api('POST', `/api/worlds/${wid()}/categories`, body), 'Category added')) {
      $('#cat-list', modal).innerHTML = state.data.categories.map(rowHtml).join('');
      $('#new-name', modal).value = '';
    }
  });
}

function openInvite() {
  const { modal } = openModal(`
    <div class="modal-head">${closeBtn}<h2>Invite Friends</h2><span></span></div>
    <div class="modal-body" style="text-align:center">
      <h2 style="margin:8px 0 4px;font-weight:500">Invite Your Friends!</h2>
      <div style="color:var(--muted)">Send the 6-digit invite code<br>to edit the world together!</div>
      <div class="code" id="inv-code">— — — — — —</div>
      <button class="btn primary block" id="inv-gen">Generate invite code</button>
      <button class="btn block" id="inv-share" style="margin-top:10px" hidden>Share link</button>
      <ol class="steps" style="text-align:left;display:inline-block;margin-top:20px">
        <li>Share the invite code.</li>
        <li>Select “Join” in the app.</li>
        <li>Enter the code to complete.</li>
      </ol>
      <div class="hint" id="inv-exp"></div>
    </div>`);
  let code;
  $('#inv-gen', modal).addEventListener('click', async () => {
    try {
      const r = await api('POST', `/api/worlds/${state.data.world.id}/invite`);
      code = r.code;
      $('#inv-code', modal).innerHTML = `<span>${code}</span><button class="copy" aria-label="Copy code">${copyIcon}</button>`;
      $('#inv-exp', modal).textContent = `Expires ${new Date(r.expires).toLocaleString()}`;
      $('#inv-share', modal).hidden = !navigator.share;
    } catch (e) { toast(e.message, true); }
  });
  $('#inv-code', modal).addEventListener('click', (e) => { if (e.target.closest('.copy')) copy(code); });
  $('#inv-share', modal).addEventListener('click', () => {
    navigator.share({
      title: `Join ${state.data.world.name}`,
      text: `Join my Minecraft world “${state.data.world.name}” on MC Coords with code ${code}`,
      url: `${location.origin}/?join=${code}`,
    }).catch(() => {});
  });
}

function openJoin(prefill = '') {
  const { modal, close } = openModal(`
    <div class="modal-head">${closeBtn}<h2>Join a World</h2><span></span></div>
    <div class="modal-body">
      <div class="field"><label for="join-code">Invite code</label>
        <input class="input code-input" id="join-code" inputmode="numeric" maxlength="6" autocomplete="one-time-code" value="${esc(prefill)}" placeholder="000000"></div>
      ${prefs.player ? '' : `<div class="field"><label for="join-name">Your name</label><input class="input" id="join-name" maxlength="40" placeholder="Shown on your edits"></div>`}
    </div>
    <div class="modal-foot"><button class="btn primary grow" id="join-go">Join</button></div>`);
  const input = $('#join-code', modal);
  setTimeout(() => input.focus(), 250);
  const go = async () => {
    const nameInput = $('#join-name', modal);
    if (nameInput) { if (!nameInput.value.trim()) { toast('Enter your name', true); return; } prefs.player = nameInput.value.trim(); }
    const code = input.value.replace(/\D/g, '');
    if (code.length !== 6) { toast('Codes are 6 digits', true); return; }
    try {
      const data = await api('POST', '/api/join', { code });
      close();
      state.data = null;
      setData(data);
      prefs.current = data.world.id;
      connectLive(data.world.id);
      showApp();
      toast(`Joined ${data.world.name}!`);
    } catch (e) { toast(e.message, true); }
  };
  $('#join-go', modal).addEventListener('click', go);
  input.addEventListener('keydown', (e) => { if (e.key === 'Enter') go(); });
}

function openCreateWorld() {
  const { modal, close } = openModal(`
    <div class="modal-head">${closeBtn}<h2>New World</h2><span></span></div>
    <div class="modal-body">
      <div class="field"><label for="nw-name">World name</label><input class="input" id="nw-name" maxlength="60" placeholder="My World"></div>
    </div>
    <div class="modal-foot"><button class="btn primary grow" id="nw-go">Create</button></div>`);
  setTimeout(() => $('#nw-name', modal).focus(), 250);
  $('#nw-go', modal).addEventListener('click', async () => {
    const name = $('#nw-name', modal).value.trim() || 'My World';
    try { const data = await api('POST', '/api/worlds', { name }); close(); switchWorld(data); }
    catch (e) { toast(e.message, true); }
  });
}

function switchWorld(data) {
  state.data = null; state.selected = null;
  map.reset();
  setData(data);
  prefs.current = data.world.id;
  connectLive(data.world.id);
  showApp();
}

function openDrawer() {
  const { modal, close } = openModal(`
    <div class="modal-head">${closeBtn}<h2>Worlds</h2><span></span></div>
    <div class="modal-body" style="padding:0">
      <div class="card">${prefs.worlds.map((w) => `<button class="item" data-wid="${esc(w.id)}">
        <span style="font-size:22px">🌍</span><span class="grow">${esc(w.name)}</span>
        ${w.id === prefs.current ? '<span class="check">✓</span>' : ''}</button>`).join('')}</div>
      <div class="card" style="margin-top:16px">
        <button class="item" id="dr-new"><span style="font-size:22px">➕</span><span class="grow">Create a new world</span></button>
        <button class="item" id="dr-join"><span style="font-size:22px">🔑</span><span class="grow">Join with invite code</span></button>
      </div>
    </div>`);
  modal.addEventListener('click', (e) => {
    const w = e.target.closest('[data-wid]');
    if (w) { close(); if (w.dataset.wid !== prefs.current) { state.data = null; state.selected = null; map.reset(); loadWorld(w.dataset.wid); } }
  });
  $('#dr-new', modal).addEventListener('click', () => { close(); openCreateWorld(); });
  $('#dr-join', modal).addEventListener('click', () => { close(); openJoin(); });
}

// ------------------------------------------------------------------ settings
function renderSettings() {
  const d = state.data;
  const counts = Object.keys(DIMS).map((k) => `${d.locations.filter((l) => l.dimension === k).length} ${DIMS[k].short}`).join(' · ');
  $('#view-settings').innerHTML = `<div class="settings">
    <h3>You</h3>
    <div class="card"><div class="item"><span class="grow">Player name<span class="sub">Shown as “last edited by”</span></span>
      <input class="input" id="st-player" style="max-width:50%" maxlength="40" value="${esc(prefs.player)}" placeholder="Steve"></div>
      <div class="item"><span class="grow">Copy format</span>
      <select class="input" id="st-copy" style="max-width:50%">
        <option value="xyz" ${prefs.copyFormat === 'xyz' ? 'selected' : ''}>x y z</option>
        <option value="comma" ${prefs.copyFormat === 'comma' ? 'selected' : ''}>x, y, z</option>
        <option value="tp" ${prefs.copyFormat === 'tp' ? 'selected' : ''}>/tp @s x y z</option>
      </select></div></div>

    <h3>This world</h3>
    <div class="card">
      <div class="item"><span class="grow">Name</span><input class="input" id="st-wname" style="max-width:55%" maxlength="60" value="${esc(d.world.name)}"></div>
      <div class="item"><span class="grow">Locations<span class="sub">${counts}</span></span></div>
      <button class="item" id="st-invite"><span class="grow">Invite friends<span class="sub">Generate a 6-digit code</span></span>›</button>
      <button class="item" id="st-cats"><span class="grow">Edit categories</span>›</button>
      <button class="item" id="st-export"><span class="grow">Export backup (JSON)</span>›</button>
    </div>

    <h3>Worlds</h3>
    <div class="card">
      <button class="item" id="st-switch"><span class="grow">Switch world<span class="sub">${prefs.worlds.length} on this device</span></span>›</button>
      <button class="item" id="st-new"><span class="grow">Create a new world</span>›</button>
      <button class="item" id="st-join"><span class="grow">Join with invite code</span>›</button>
    </div>

    <h3>Danger zone</h3>
    <div class="card">
      <button class="item danger" id="st-leave"><span class="grow">Remove world from this device<span class="sub">Others keep access; rejoin with a new code</span></span></button>
      <button class="item danger" id="st-delete"><span class="grow">Delete world for everyone</span></button>
    </div>
    <div class="hint" style="text-align:center;margin-top:24px">MC Coords · not affiliated with Mojang or Microsoft<br>Tip: “Add to Home Screen” to install as an app.</div>
  </div>`;

  const v = $('#view-settings');
  $('#st-player', v).addEventListener('change', (e) => { prefs.player = e.target.value.trim(); toast('Name saved'); });
  $('#st-copy', v).addEventListener('change', (e) => { prefs.copyFormat = e.target.value; });
  $('#st-wname', v).addEventListener('change', (e) => {
    const name = e.target.value.trim(); if (!name) return;
    mutate(() => api('PATCH', `/api/worlds/${d.world.id}`, { name }), 'World renamed');
  });
  $('#st-invite', v).addEventListener('click', openInvite);
  $('#st-cats', v).addEventListener('click', () => openCategories());
  $('#st-export', v).addEventListener('click', () => { location.href = `/api/worlds/${d.world.id}/export`; });
  $('#st-switch', v).addEventListener('click', openDrawer);
  $('#st-new', v).addEventListener('click', openCreateWorld);
  $('#st-join', v).addEventListener('click', () => openJoin());
  $('#st-leave', v).addEventListener('click', () => {
    if (!confirm(`Remove “${d.world.name}” from this device? You'll need a new invite code to get back in.`)) return;
    state.es?.close(); forgetWorld(d.world.id); state.data = null; boot();
  });
  $('#st-delete', v).addEventListener('click', async () => {
    const typed = prompt(`This permanently deletes “${d.world.name}” and all its locations for everyone.\nType the world name to confirm:`);
    if (typed?.trim() !== d.world.name) return;
    try {
      await api('DELETE', `/api/worlds/${d.world.id}`);
      state.es?.close(); forgetWorld(d.world.id); state.data = null; toast('World deleted'); boot();
    } catch (e) { toast(e.message, true); }
  });
}

// ------------------------------------------------------------------ map
const map = (() => {
  const canvas = $('#map-canvas');
  const wrap = $('#map-wrap');
  const ctx = canvas.getContext('2d');
  const views = {}; // per-dimension {cx, cz, scale}
  let ghost = false;
  let w = 0; let h = 0; let dpr = 1;

  const view = () => (views[state.mapDim] ||= fitView(state.mapDim) || { cx: 0, cz: 0, scale: 0.5 });

  function resize() {
    dpr = window.devicePixelRatio || 1;
    w = wrap.clientWidth; h = wrap.clientHeight;
    canvas.width = Math.round(w * dpr); canvas.height = Math.round(h * dpr);
    draw();
  }

  function pointsFor(dim) {
    if (!state.data) return [];
    const own = state.data.locations.filter((l) => l.dimension === dim).map((l) => ({ l, x: l.x, z: l.z, ghost: false }));
    if (!ghost || dim === 'end') return own;
    const other = dim === 'overworld' ? 'nether' : 'overworld';
    const conv = dim === 'overworld' ? fromNether : toNether;
    return own.concat(state.data.locations.filter((l) => l.dimension === other)
      .map((l) => ({ l, x: conv(l.x), z: conv(l.z), ghost: true })));
  }

  function fitView(dim) {
    const pts = pointsFor(dim);
    if (!pts.length || !w) return null;
    const xs = pts.map((p) => p.x); const zs = pts.map((p) => p.z);
    const minX = Math.min(...xs); const maxX = Math.max(...xs);
    const minZ = Math.min(...zs); const maxZ = Math.max(...zs);
    const span = Math.max(maxX - minX, maxZ - minZ, 64);
    const scale = Math.min(w, h - 120) / (span * 1.3);
    return { cx: (minX + maxX) / 2, cz: (minZ + maxZ) / 2, scale: Math.max(0.005, Math.min(scale, 8)) };
  }

  const toScreen = (x, z, v) => [(x - v.cx) * v.scale + w / 2, (z - v.cz) * v.scale + h / 2];
  const toWorld = (sx, sy, v) => [(sx - w / 2) / v.scale + v.cx, (sy - h / 2) / v.scale + v.cz];

  function gridStep(scale) {
    // Snap grid to chunk multiples (16 blocks * 2^n) so lines are >= ~44px apart.
    let step = 16;
    while (step * scale < 44) step *= 2;
    while (step > 16 && step * scale > 110) step /= 2;
    return step;
  }

  function draw() {
    if (!w || state.view !== 'map') return;
    const v = view();
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.fillStyle = state.mapDim === 'nether' ? '#120606' : state.mapDim === 'end' ? '#0b0a12' : '#000';
    ctx.fillRect(0, 0, w, h);

    const step = gridStep(v.scale);
    const [x0, z0] = toWorld(0, 0, v); const [x1, z1] = toWorld(w, h, v);
    ctx.lineWidth = 1;
    ctx.strokeStyle = '#2a2a2a';
    ctx.beginPath();
    for (let x = Math.floor(x0 / step) * step; x <= x1; x += step) { const [sx] = toScreen(x, 0, v); ctx.moveTo(Math.round(sx) + .5, 0); ctx.lineTo(Math.round(sx) + .5, h); }
    for (let z = Math.floor(z0 / step) * step; z <= z1; z += step) { const [, sy] = toScreen(0, z, v); ctx.moveTo(0, Math.round(sy) + .5); ctx.lineTo(w, Math.round(sy) + .5); }
    ctx.stroke();

    // axes
    const [ox, oz] = toScreen(0, 0, v);
    ctx.strokeStyle = '#c6d84a'; ctx.globalAlpha = .7;
    ctx.beginPath(); ctx.moveTo(ox, 0); ctx.lineTo(ox, h); ctx.moveTo(0, oz); ctx.lineTo(w, oz); ctx.stroke();
    ctx.globalAlpha = 1;

    // axis labels, in blocks; pinned to the edges when the axis is off-screen
    ctx.font = '11px ui-monospace, Menlo, monospace';
    ctx.fillStyle = '#bbb';
    const ly = Math.min(Math.max(oz + 4, 60), h - 30);
    const lx = Math.min(Math.max(ox + 4, 4), w - 50);
    ctx.textBaseline = 'top';
    for (let x = Math.floor(x0 / step) * step; x <= x1; x += step) {
      if (x === 0) continue;
      const [sx] = toScreen(x, 0, v);
      const t = String(x); ctx.fillStyle = 'rgba(0,0,0,.7)'; ctx.fillRect(sx + 2, ly - 1, ctx.measureText(t).width + 4, 14);
      ctx.fillStyle = '#bbb'; ctx.fillText(t, sx + 4, ly);
    }
    for (let z = Math.floor(z0 / step) * step; z <= z1; z += step) {
      if (z === 0) continue;
      const [, sy] = toScreen(0, z, v);
      if (sy < 56) continue;
      const t = String(z); ctx.fillStyle = 'rgba(0,0,0,.7)'; ctx.fillRect(lx - 2, sy + 2, ctx.measureText(t).width + 4, 14);
      ctx.fillStyle = '#bbb'; ctx.fillText(t, lx, sy + 3);
    }

    // markers
    const pts = pointsFor(state.mapDim).sort((a, b) => (a.ghost === b.ghost ? 0 : a.ghost ? -1 : 1));
    ctx.textAlign = 'center'; ctx.textBaseline = 'middle';
    for (const p of pts) {
      const [sx, sy] = toScreen(p.x, p.z, v);
      if (sx < -30 || sy < -30 || sx > w + 30 || sy > h + 30) continue;
      const c = catOf(p.l);
      const sel = !p.ghost && state.selected === p.l.id;
      ctx.globalAlpha = p.ghost ? 0.4 : 1;
      ctx.beginPath(); ctx.arc(sx, sy, sel ? 17 : 14, 0, Math.PI * 2);
      ctx.fillStyle = 'rgba(20,20,20,.85)'; ctx.fill();
      ctx.lineWidth = sel ? 3 : 2; ctx.strokeStyle = sel ? '#fff' : c.color;
      if (p.ghost) ctx.setLineDash([3, 3]);
      ctx.stroke(); ctx.setLineDash([]);
      ctx.font = `${sel ? 18 : 15}px system-ui, "Apple Color Emoji", "Segoe UI Emoji", sans-serif`;
      ctx.fillStyle = '#fff';
      ctx.fillText(c.icon, sx, sy + 1);
      if (v.scale > 0.6 || sel) {
        ctx.font = '11px system-ui, sans-serif';
        const t = p.l.name; const tw = ctx.measureText(t).width;
        ctx.fillStyle = 'rgba(0,0,0,.65)'; ctx.fillRect(sx - tw / 2 - 3, sy + 18, tw + 6, 15);
        ctx.fillStyle = '#eee'; ctx.fillText(t, sx, sy + 26);
      }
      ctx.globalAlpha = 1;
    }
    ctx.textAlign = 'start';

    const chunks = step / 16;
    $('#map-scale').textContent = `1 grid = ${chunks} chunk${chunks === 1 ? '' : 's'} (${step} blocks)`;
  }

  function hitTest(sx, sy) {
    const v = view();
    let best = null; let bestD = 26;
    for (const p of pointsFor(state.mapDim)) {
      const [px, py] = toScreen(p.x, p.z, v);
      const dd = Math.hypot(px - sx, py - sy);
      if (dd < bestD || (best?.ghost && !p.ghost && dd < 26)) { best = p; bestD = dd; }
    }
    return best;
  }

  function zoomAt(sx, sy, factor) {
    const v = view();
    const [wx, wz] = toWorld(sx, sy, v);
    v.scale = Math.max(0.004, Math.min(v.scale * factor, 16));
    v.cx = wx - (sx - w / 2) / v.scale;
    v.cz = wz - (sy - h / 2) / v.scale;
    draw();
  }

  // ---- input: pan / pinch / tap / long-press
  const pointers = new Map();
  let gesture = null; let longTimer;
  const local = (e) => { const r = canvas.getBoundingClientRect(); return [e.clientX - r.left, e.clientY - r.top]; };

  canvas.addEventListener('pointerdown', (e) => {
    canvas.setPointerCapture(e.pointerId);
    pointers.set(e.pointerId, local(e));
    clearTimeout(longTimer);
    if (pointers.size === 1) {
      const [sx, sy] = local(e);
      const v = view();
      gesture = { type: 'pan', sx, sy, cx: v.cx, cz: v.cz, t: Date.now(), moved: false };
      longTimer = setTimeout(() => {
        if (gesture && !gesture.moved && pointers.size === 1) {
          gesture.type = 'done';
          const [wx, wz] = toWorld(sx, sy, view());
          navigator.vibrate?.(20);
          openEditor(null, { dimension: state.mapDim, x: Math.round(wx), z: Math.round(wz) });
        }
      }, 600);
    } else if (pointers.size === 2) {
      const [a, b] = [...pointers.values()];
      gesture = { type: 'pinch', dist: Math.hypot(a[0] - b[0], a[1] - b[1]), mid: [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2] };
    }
  });

  canvas.addEventListener('pointermove', (e) => {
    const [sx, sy] = local(e);
    if (e.pointerType === 'mouse') {
      const [wx, wz] = toWorld(sx, sy, view());
      $('#map-cursor').textContent = `X ${Math.floor(wx)}  Z ${Math.floor(wz)}`;
    }
    if (!pointers.has(e.pointerId)) return;
    pointers.set(e.pointerId, [sx, sy]);
    if (!gesture) return;
    const v = view();
    if (gesture.type === 'pan') {
      const dx = sx - gesture.sx; const dy = sy - gesture.sy;
      if (Math.hypot(dx, dy) > 6) gesture.moved = true;
      if (gesture.moved) { v.cx = gesture.cx - dx / v.scale; v.cz = gesture.cz - dy / v.scale; draw(); }
    } else if (gesture.type === 'pinch' && pointers.size === 2) {
      const [a, b] = [...pointers.values()];
      const dist = Math.hypot(a[0] - b[0], a[1] - b[1]);
      const mid = [(a[0] + b[0]) / 2, (a[1] + b[1]) / 2];
      v.cx -= (mid[0] - gesture.mid[0]) / v.scale; v.cz -= (mid[1] - gesture.mid[1]) / v.scale;
      zoomAt(mid[0], mid[1], dist / gesture.dist);
      gesture.dist = dist; gesture.mid = mid;
    }
  });

  const end = (e) => {
    clearTimeout(longTimer);
    const had = pointers.delete(e.pointerId);
    if (!had) return;
    if (gesture?.type === 'pan' && !gesture.moved && Date.now() - gesture.t < 600) {
      const [sx, sy] = local(e);
      const hit = hitTest(sx, sy);
      const [wx, wz] = toWorld(sx, sy, view());
      $('#map-cursor').textContent = `X ${Math.floor(wx)}  Z ${Math.floor(wz)}`;
      if (hit && hit.ghost) {
        // Tapping a ghost jumps to the other dimension and selects it there.
        setMapDim(hit.l.dimension); state.selected = hit.l.id; centerOn(hit.l);
      } else {
        state.selected = hit ? hit.l.id : null;
      }
      draw(); renderSheet();
    }
    if (pointers.size === 1 && gesture?.type === 'pinch') {
      const [p] = [...pointers.values()]; const v = view();
      gesture = { type: 'pan', sx: p[0], sy: p[1], cx: v.cx, cz: v.cz, t: 0, moved: true };
    } else if (!pointers.size) gesture = null;
  };
  canvas.addEventListener('pointerup', end);
  canvas.addEventListener('pointercancel', end);
  canvas.addEventListener('wheel', (e) => {
    e.preventDefault();
    const [sx, sy] = local(e);
    zoomAt(sx, sy, Math.exp(-e.deltaY * (e.ctrlKey ? 0.01 : 0.0015)));
  }, { passive: false });
  canvas.addEventListener('contextmenu', (e) => e.preventDefault());

  function centerOn(l) {
    const v = view();
    v.cx = l.x; v.cz = l.z;
    if (v.scale < 0.5) v.scale = 1;
    draw();
  }

  window.addEventListener('resize', () => { if (state.view === 'map') resize(); });

  return {
    draw, resize, centerOn,
    reset() { for (const k of Object.keys(views)) delete views[k]; },
    fit() { const f = fitView(state.mapDim); views[state.mapDim] = f || { cx: 0, cz: 0, scale: 0.5 }; draw(); },
    origin() { const v = view(); v.cx = 0; v.cz = 0; draw(); },
    setGhost(on) { ghost = on; draw(); },
  };
})();

function setMapDim(dim) {
  state.mapDim = dim;
  $$('#map-tabs button').forEach((b) => b.classList.toggle('active', b.dataset.dim === dim));
  const g = $('#ghost-toggle-wrap');
  g.hidden = dim === 'end';
  $('#ghost-label').textContent = dim === 'overworld' ? 'NETHER' : 'OVER';
  if (state.selected && locById(state.selected)?.dimension !== dim) state.selected = null;
  map.draw(); renderSheet();
}

function renderMapSearch() {
  $('#map-search-list').innerHTML = state.data.locations
    .map((l) => `<option value="${esc(l.name)}">${DIMS[l.dimension].short} · ${l.x} ${l.y} ${l.z}</option>`).join('');
}

function renderSheet() {
  const sheet = $('#map-sheet');
  const l = state.selected && locById(state.selected);
  if (!l) { sheet.hidden = true; return; }
  const c = catOf(l);
  sheet.hidden = false;
  sheet.innerHTML = `<div class="grab"></div>
    <div class="sheet-head">
      <div class="loc-icon">${esc(c.icon)}</div>
      <div class="loc-name">${esc(l.name)}</div>
      <button class="heart ${l.favorite ? 'on' : ''}" data-fav="${l.id}" aria-label="Bookmark">${heartIcon}</button>
      <button class="icon-btn" data-sheet-close aria-label="Close"><svg viewBox="0 0 24 24"><path d="M6 6l12 12M18 6 6 18"/></svg></button>
      <div class="loc-coords" style="grid-column:2/5"><span>${l.x}</span><span>${l.y}</span><span>${l.z}</span>
        <button class="copy" data-copy="${l.id}" aria-label="Copy">${copyIcon}</button></div>
    </div>
    ${chipsHtml(l)}
    ${l.image || l.notes ? `<div class="sheet-body">${l.image ? `<img src="${esc(imgUrl(l.image))}" alt="">` : ''}${l.notes ? `<p>${esc(l.notes)}</p>` : ''}</div>` : ''}
    <div class="convert">${esc(conversionHint(l))}</div>
    <div class="row" style="margin-top:12px"><button class="btn grow" data-edit="${l.id}">Edit</button></div>`;
}

// ------------------------------------------------------------------ global event wiring
function wire() {
  $('#bottombar').addEventListener('click', (e) => { const b = e.target.closest('[data-view]'); if (b) setView(b.dataset.view); });
  $('#list-tabs').addEventListener('click', (e) => {
    const b = e.target.closest('[data-tab]'); if (!b) return;
    state.listTab = b.dataset.tab;
    $$('#list-tabs button').forEach((x) => x.classList.toggle('active', x === b));
    renderList();
  });
  $('#list-search').addEventListener('input', (e) => { state.search = e.target.value; renderList(); });
  $('#fab-add').addEventListener('click', () => openEditor(null, { dimension: state.listTab === 'bookmarks' ? 'overworld' : state.listTab }));
  $('#btn-drawer').addEventListener('click', openDrawer);
  $('#btn-invite').addEventListener('click', openInvite);

  // Delegated actions shared by the list and the map sheet.
  const onAction = (e) => {
    const t = e.target;
    const fav = t.closest('[data-fav]'); if (fav) { e.stopPropagation(); toggleFavorite(Number(fav.dataset.fav)); return; }
    const cp = t.closest('[data-copy]'); if (cp) { e.stopPropagation(); copy(coordText(locById(Number(cp.dataset.copy)))); return; }
    const go = t.closest('[data-goto]');
    if (go) {
      e.stopPropagation();
      const l = locById(Number(go.dataset.goto));
      if (l) { setView('map'); setMapDim(l.dimension); state.selected = l.id; map.centerOn(l); renderSheet(); }
      return;
    }
    const ed = t.closest('[data-edit]'); if (ed) { openEditor(locById(Number(ed.dataset.edit))); return; }
    if (t.closest('[data-sheet-close]')) { state.selected = null; map.draw(); renderSheet(); return; }
    const row = t.closest('.loc[data-id]'); if (row) openEditor(locById(Number(row.dataset.id)));
  };
  $('#list').addEventListener('click', onAction);
  $('#map-sheet').addEventListener('click', onAction);

  $('#map-tabs').addEventListener('click', (e) => { const b = e.target.closest('[data-dim]'); if (b) setMapDim(b.dataset.dim); });
  $('#ghost-toggle').addEventListener('change', (e) => map.setGhost(e.target.checked));
  $('#map-fit').addEventListener('click', () => map.fit());
  $('#map-origin').addEventListener('click', () => map.origin());
  const ms = $('#map-search');
  const findOnMap = () => {
    const q = ms.value.trim().toLowerCase(); if (!q) return;
    const l = state.data.locations.find((x) => x.name.toLowerCase() === q)
      || state.data.locations.find((x) => matches(x, q));
    if (!l) { toast('No match'); return; }
    setMapDim(l.dimension); state.selected = l.id; map.centerOn(l); renderSheet();
    ms.blur();
  };
  ms.addEventListener('change', findOnMap);
  ms.addEventListener('keydown', (e) => { if (e.key === 'Enter') findOnMap(); });

  document.addEventListener('visibilitychange', () => {
    if (document.visibilityState === 'visible' && state.data) loadWorld(state.data.world.id, { quiet: true });
  });
}

// ------------------------------------------------------------------ boot / onboarding
function showApp() {
  $('#app').hidden = false;
  $('#modal-root').innerHTML = '';
  setView(state.view);
}

function onboarding(joinCode) {
  $('#app').hidden = true;
  const { modal } = openModal(`
    <div class="onboard">
      <img class="logo" src="/icons/icon-192.png" alt="">
      <h2>MC Coords</h2>
      <p>Never lose a location again. Track coordinates, map them, and share them with friends.</p>
      <div class="field"><label for="ob-name">Your player name</label>
        <input class="input" id="ob-name" maxlength="40" value="${esc(prefs.player)}" placeholder="Steve"></div>
      <div class="field"><label for="ob-world">Create a world</label>
        <input class="input" id="ob-world" maxlength="60" placeholder="My World"></div>
      <button class="btn primary block" id="ob-create">Create world</button>
      <div class="or">— or —</div>
      <button class="btn block" id="ob-join">Join a friend's world</button>
    </div>`, { full: true, dismissable: false });
  const name = () => {
    const n = $('#ob-name', modal).value.trim();
    if (!n) { toast('Enter your player name', true); $('#ob-name', modal).focus(); return null; }
    prefs.player = n; return n;
  };
  $('#ob-create', modal).addEventListener('click', async () => {
    if (!name()) return;
    try { switchWorld(await api('POST', '/api/worlds', { name: $('#ob-world', modal).value.trim() || 'My World' })); }
    catch (e) { toast(e.message, true); }
  });
  $('#ob-join', modal).addEventListener('click', () => { if (name()) openJoin(joinCode || ''); });
  if (joinCode) {
    $('#ob-join', modal).classList.add('primary');
    if (prefs.player) openJoin(joinCode); else toast('Enter your name, then tap Join');
  }
}

function boot() {
  const params = new URLSearchParams(location.search);
  const joinCode = params.get('join')?.replace(/\D/g, '').slice(0, 6);
  if (joinCode) history.replaceState(null, '', '/');
  const id = prefs.current || prefs.worlds[0]?.id;
  if (!id) return onboarding(joinCode);
  showApp();
  loadWorld(id);
  if (joinCode) openJoin(joinCode);
}

wire();
boot();

if ('serviceWorker' in navigator) {
  window.addEventListener('load', () => navigator.serviceWorker.register('/sw.js').catch(() => {}));
}
