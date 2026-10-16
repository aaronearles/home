// openbao-vaultwarden-sync
//
// One-way mirror: OpenBao KV v2 -> Vaultwarden. OpenBao is the source of
// truth. Every SYNC_INTERVAL_SECONDS this:
//   1. logs in to OpenBao with AppRole (credentials/role_id + secret_id)
//   2. walks every path under SYNC_PREFIXES in the kv/ mount
//   3. creates/updates one Vaultwarden item per secret, and trashes items whose
//      secret was deleted
//
// Vaultwarden encrypts client-side, so we can't just call its HTTP API. Instead
// we run the official Bitwarden CLI's local REST server (`bw serve`, bound to
// 127.0.0.1 inside this container), which does the crypto for us.
//
// Only items carrying an `openbao_path` field are ever touched, so items you
// add to the same folder or collection by hand are safe.

import { spawn, execFile } from "node:child_process";
import { readFile, writeFile } from "node:fs/promises";
import { isDeepStrictEqual, promisify } from "node:util";

const run = promisify(execFile);
const env = process.env;

const cfg = {
  baoAddr: (env.BAO_ADDR || "http://openbao-backend:8200").replace(/\/$/, ""),
  credsDir: env.CREDENTIALS_DIR || "/credentials",
  mount: env.BAO_KV_MOUNT || "kv",
  prefixes: (env.SYNC_PREFIXES || "infra/,agents/,apps/")
    .split(",").map((p) => p.trim().replace(/^\/+/, "")).filter(Boolean)
    .map((p) => (p.endsWith("/") ? p : p + "/")),
  vwCredsPath: env.VW_CREDENTIALS_PATH || "system/vaultwarden-sync",
  intervalMs: Number(env.SYNC_INTERVAL_SECONDS || 300) * 1000,
  vwUrl: env.VW_URL || "https://vaultwarden.internal.earles.io",
  folder: env.VW_FOLDER || "OpenBao",
  orgId: env.VW_ORGANIZATION_ID || "",
  collectionId: env.VW_COLLECTION_ID || "",
  deleteMissing: (env.SYNC_DELETE || "true") !== "false",
  dryRun: (env.SYNC_DRY_RUN || "false") === "true",
  bwPort: Number(env.BW_SERVE_PORT || 8087),
};

const MARK = "openbao_path";
// Keys that map onto Bitwarden login fields instead of custom fields.
const LOGIN_KEYS = ["username", "password", "totp", "url"];

const log = (...a) => console.log(new Date().toISOString(), ...a);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ---------------------------------------------------------------- OpenBao --

class Bao {
  token = null;
  expires = 0;

  async login() {
    const roleId = (await readFile(`${cfg.credsDir}/role_id`, "utf8")).trim();
    const secretId = (await readFile(`${cfg.credsDir}/secret_id`, "utf8")).trim();
    const r = await this.raw("POST", "auth/approle/login", { role_id: roleId, secret_id: secretId }, false);
    this.token = r.auth.client_token;
    this.expires = Date.now() + (r.auth.lease_duration - 60) * 1000;
  }

  async raw(method, path, body, auth = true) {
    const res = await fetch(`${cfg.baoAddr}/v1/${path}`, {
      method,
      headers: {
        ...(auth ? { "X-Vault-Token": this.token } : {}),
        ...(body ? { "Content-Type": "application/json" } : {}),
      },
      body: body ? JSON.stringify(body) : undefined,
    });
    if (res.status === 404) return null;
    const json = await res.json().catch(() => ({}));
    if (!res.ok) {
      const err = new Error(`OpenBao ${method} ${path}: HTTP ${res.status} ${(json.errors || []).join("; ").replace(/\s+/g, " ").trim()}`);
      err.status = res.status;
      throw err;
    }
    return json;
  }

  async call(method, path) {
    if (!this.token || Date.now() > this.expires) await this.login();
    try {
      return await this.raw(method, path);
    } catch (e) {
      if (e.status !== 403) throw e;
      await this.login(); // token revoked or expired early: retry once
      return this.raw(method, path);
    }
  }

  // All leaf paths under a folder prefix, e.g. "infra/" -> ["infra/cloudflare/dns-token", ...]
  async walk(prefix) {
    const r = await this.call("LIST", `${cfg.mount}/metadata/${prefix}`);
    if (!r) return [];
    const out = [];
    for (const k of r.data.keys) {
      if (k.endsWith("/")) out.push(...(await this.walk(prefix + k)));
      else out.push(prefix + k);
    }
    return out;
  }

  async metadata(path) {
    const r = await this.call("GET", `${cfg.mount}/metadata/${path}`);
    return r && r.data;
  }

  async data(path) {
    const r = await this.call("GET", `${cfg.mount}/data/${path}`);
    return r && r.data && r.data.data;
  }
}

// -------------------------------------------------------------- Bitwarden --

class Bw {
  base = `http://127.0.0.1:${cfg.bwPort}`;
  proc = null;

  async start({ email, password, client_id, client_secret }) {
    const bwEnv = { ...env, BW_PASSWORD: password, BW_CLIENTID: client_id || "", BW_CLIENTSECRET: client_secret || "" };
    const bw = (...args) => run("bw", args, { env: bwEnv });

    await bw("logout").catch(() => {}); // fresh state on every start
    await bw("config", "server", cfg.vwUrl);
    if (client_id && client_secret) {
      log(`bw: logging in to ${cfg.vwUrl} with API key ${client_id}`);
      await bw("login", "--apikey");
    } else {
      log(`bw: logging in to ${cfg.vwUrl} as ${email}`);
      await bw("login", email, "--passwordenv", "BW_PASSWORD");
    }

    this.proc = spawn("bw", ["serve", "--hostname", "127.0.0.1", "--port", String(cfg.bwPort)], {
      env: bwEnv, stdio: ["ignore", "inherit", "inherit"],
    });
    this.proc.on("exit", (code) => {
      log(`bw serve exited (${code}); restarting container`);
      process.exit(1);
    });
    for (let i = 0; i < 60; i++) {
      try { await fetch(`${this.base}/status`); break; } catch { await sleep(500); }
    }
    await this.req("POST", "/unlock", { password });
    log("bw: vault unlocked");
  }

  async req(method, path, body) {
    const res = await fetch(this.base + path, {
      method,
      headers: body ? { "Content-Type": "application/json" } : {},
      body: body ? JSON.stringify(body) : undefined,
    });
    const json = await res.json().catch(() => ({}));
    if (!res.ok || json.success === false) {
      throw new Error(`bw ${method} ${path}: HTTP ${res.status} ${json.message || ""}`);
    }
    return json.data;
  }

  async folderId(name) {
    const folders = (await this.req("GET", `/list/object/folders?search=${encodeURIComponent(name)}`)).data;
    const hit = folders.find((f) => f.name === name);
    if (hit) return hit.id;
    if (cfg.dryRun) return null;
    log(`bw: creating folder "${name}"`);
    return (await this.req("POST", "/object/folder", { name })).id;
  }

  async managedItems(target) {
    const q = target.organizationId
      ? `organizationId=${target.organizationId}&collectionid=${target.collectionIds[0]}`
      : `folderid=${target.folderId}`;
    const items = target.folderId === null && !target.organizationId ? [] : (await this.req("GET", `/list/object/items?${q}`)).data;
    const byPath = new Map();
    for (const it of items) {
      const p = (it.fields || []).find((f) => f.name === MARK)?.value;
      if (p) byPath.set(p, it);
    }
    return byPath;
  }
}

// ---------------------------------------------------------------- Mapping --

const str = (v) => (typeof v === "string" ? v : JSON.stringify(v));

// The parts of a Bitwarden item we own. Compared against the existing item to
// decide whether an update is needed (which also reverts hand edits).
function desired(path, data, meta) {
  const d = { ...data };
  const cm = meta.custom_metadata || {};
  const isLogin = "username" in d || "password" in d;
  const item = {
    type: isLogin ? 1 : 2,
    name: cm.vaultwarden_name || path,
    notes:
      `Mirrored from OpenBao ${cfg.mount}/${path} (version ${meta.current_version}).\n` +
      `Edits made here are overwritten. Change the secret in OpenBao instead.` +
      (cm.description ? `\n\n${cm.description}` : ""),
    fields: [{ name: MARK, value: path, type: 0, linkedId: null }],
  };
  if (isLogin) {
    const uri = d.url || cm.url;
    item.login = {
      username: d.username != null ? str(d.username) : null,
      password: d.password != null ? str(d.password) : null,
      totp: d.totp != null ? str(d.totp) : null,
      uris: uri ? [{ match: null, uri: str(uri) }] : [],
    };
    for (const k of LOGIN_KEYS) delete d[k];
  }
  for (const [k, v] of Object.entries(d).sort(([a], [b]) => a.localeCompare(b))) {
    item.fields.push({ name: k, value: str(v), type: 1, linkedId: null }); // 1 = hidden
  }
  return item;
}

function comparable(it) {
  return {
    type: it.type,
    name: it.name,
    notes: it.notes,
    fields: (it.fields || []).map(({ name, value, type }) => ({ name, value, type })),
    login: it.type === 1
      ? {
          username: it.login?.username ?? null,
          password: it.login?.password ?? null,
          totp: it.login?.totp ?? null,
          uris: (it.login?.uris || []).map(({ uri }) => uri),
        }
      : undefined,
  };
}

// ------------------------------------------------------------------- Main --

async function cycle(bao, bw, target) {
  await bw.req("POST", "/sync");
  const existing = await bw.managedItems(target);
  const seen = new Set();
  const failedPrefixes = [];
  const stats = { created: 0, updated: 0, unchanged: 0, trashed: 0, skipped: 0 };

  for (const prefix of cfg.prefixes) {
    let paths;
    try {
      paths = await bao.walk(prefix);
    } catch (e) {
      // e.g. 403 because the policy doesn't cover this prefix. Don't treat
      // that as "everything was deleted".
      log(`WARN: cannot list ${cfg.mount}/${prefix}: ${e.message}`);
      failedPrefixes.push(prefix);
      continue;
    }
    for (const path of paths) {
      try {
        const meta = await bao.metadata(path);
        const latest = meta?.versions?.[String(meta.current_version)];
        if (!meta || !latest || latest.deletion_time || latest.destroyed) continue; // deleted: trash below
        if ((meta.custom_metadata || {}).vaultwarden_sync === "false") { stats.skipped++; continue; }
        const data = await bao.data(path);
        if (!data) continue;
        seen.add(path);

        const want = desired(path, data, meta);
        const have = existing.get(path);
        if (have && have.type === want.type) {
          if (isDeepStrictEqual(comparable(have), comparable(want))) { stats.unchanged++; continue; }
          log(`update ${path}`);
          if (!cfg.dryRun) await bw.req("PUT", `/object/item/${have.id}`, { ...have, ...want });
          stats.updated++;
        } else {
          if (have) { // type changed (login <-> note): replace
            log(`replace ${path} (type changed)`);
            if (!cfg.dryRun) await bw.req("DELETE", `/object/item/${have.id}`);
          } else {
            log(`create ${path}`);
          }
          if (!cfg.dryRun) {
            await bw.req("POST", "/object/item", {
              ...want,
              organizationId: target.organizationId,
              collectionIds: target.collectionIds,
              folderId: target.folderId,
              favorite: false,
              reprompt: 0,
              secureNote: want.type === 2 ? { type: 0 } : undefined,
            });
          }
          stats.created++;
        }
      } catch (e) {
        log(`WARN: ${path}: ${e.message}`);
        seen.add(path); // don't trash an item just because one read failed
      }
    }
  }

  if (cfg.deleteMissing) {
    for (const [path, it] of existing) {
      if (seen.has(path)) continue;
      if (failedPrefixes.some((p) => path.startsWith(p))) continue;
      if (!cfg.prefixes.some((p) => path.startsWith(p))) continue; // prefix removed from config: leave alone
      log(`trash ${path} (deleted or opted out in OpenBao)`);
      if (!cfg.dryRun) await bw.req("DELETE", `/object/item/${it.id}`);
      stats.trashed++;
    }
  }

  log(`sync done${cfg.dryRun ? " (dry run)" : ""}: ${JSON.stringify(stats)}`);
  await writeFile("/tmp/last-success", String(Date.now()));
}

async function main() {
  log(`openbao-vaultwarden-sync: ${cfg.baoAddr} [${cfg.prefixes.join(", ")}] -> ${cfg.vwUrl}, every ${cfg.intervalMs / 1000}s`);
  const bao = new Bao();

  // Wait for bootstrap to have issued our AppRole credentials.
  for (;;) {
    try { await bao.login(); break; } catch (e) {
      log(`waiting for OpenBao credentials (${e.code || e.message}); retrying in 60s`);
      await sleep(60_000);
    }
  }

  // The sync's own Vaultwarden login lives in OpenBao too.
  let vw;
  for (;;) {
    vw = await bao.data(cfg.vwCredsPath).catch((e) => { log(`WARN: ${e.message}`); return null; });
    if (vw && vw.password && (vw.email || vw.client_id)) break;
    log(`waiting for ${cfg.mount}/${cfg.vwCredsPath} (keys: email, password[, client_id, client_secret]); retrying in 60s`);
    await sleep(60_000);
  }

  const bw = new Bw();
  await bw.start(vw);

  const target = cfg.orgId
    ? { organizationId: cfg.orgId, collectionIds: [cfg.collectionId], folderId: null }
    : { organizationId: null, collectionIds: [], folderId: await bw.folderId(cfg.folder) };
  if (cfg.orgId && !cfg.collectionId) throw new Error("VW_ORGANIZATION_ID needs VW_COLLECTION_ID too");
  log(cfg.orgId ? `target: organization ${cfg.orgId}, collection ${cfg.collectionId}` : `target: folder "${cfg.folder}"`);

  for (;;) {
    try { await cycle(bao, bw, target); } catch (e) { log(`ERROR: sync failed: ${e.message}`); }
    await sleep(cfg.intervalMs);
  }
}

process.on("SIGTERM", () => process.exit(0));
main().catch((e) => { log(`FATAL: ${e.stack || e.message}`); process.exit(1); });
