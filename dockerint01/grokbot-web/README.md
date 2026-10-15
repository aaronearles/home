# Grok Bot web UI (spike)

This stack serves the **official Grok Bot UI as a normal web page** at `https://grokbot-web.internal.earles.io`. It does not stream a desktop.

The app's own `app.asar` (main process, preload, renderer) runs unmodified. Only the transport between the UI and the main process is replaced.

```
browser                                         container (nothing displayed or streamed)
┌───────────────────────────────┐  WebSocket    ┌─────────────────────────────────────────┐
│ official renderer             │◀────────────▶│ relay/main.cjs (Electron main wrapper)  │
│ official preload.cjs          │ + sync XHR    │   hidden blank main window, IPC/ports   │
│ relay/shim.js = fake electron │   for boot    │   relayed  ⇅  official main + helpers   │
└───────────────────────────────┘               └─────────────────────────────────────────┘
```

## How it works

- **Runtime.** The vendor binary is fuse-locked: no run-as-node, no `NODE_OPTIONS`, no inspector, and ASAR integrity is enforced. So the app's `app.asar` runs under **stock Electron 42.1.0** instead. That is the same version the app ships, so its native modules load. The download's checksum is pinned in the `Dockerfile`.
- **`relay/main.cjs`.** This wrapper:
  - makes the app see a packaged install at `/opt/Grok Bot/resources`;
  - hands the app a `BrowserWindow` subclass. For the main window, the subclass drops the preload, keeps the window hidden, and loads a blank page instead of `renderer/index.html`;
  - forwards the window's `send` and `postMessage` (and their MessagePorts) to the browser;
  - replays browser IPC as events from that real window, so the app's trusted-sender checks hold;
  - forwards `shell.openExternal` to the browser.
- **`relay/shim.js`.** This is the browser-side stand-in for the 7 `electron` APIs the preload uses: `contextBridge`, `ipcRenderer` (send/sendSync/invoke/on), `webFrame`, and `webUtils`. The preload is served wrapped as a normal script, so the vendor's CSP stays intact.
- **Multiple clients.** Every page load is a client of the same hidden window:
  - `sendSync`/`invoke` replies go back to the client that asked.
  - The main process's broadcasts go to every client.
  - MessagePorts belong to the client they were made for.
  - `openExternal` opens in whichever client was last active.
  - The two renderer boot-gate signals are forwarded once per window load.
- **Coordinator multiplexer.** The main process serves the coordinator to exactly one renderer, and a second port request restarts the coordinator process. So the relay holds that single connection and gives each client a virtual port, using the coordinator's frame protocol:
  - The relay answers each client's `hello` itself with `ready` and the last transport-state event.
  - `request`/`cancel` ids are prefixed per client, and `reply` frames are routed back by that prefix.
  - `event` frames go to every client.
  - A client's `shutdown` only drops that client.
  - If the main process hands over a new upstream (the coordinator restarted), the virtual ports are closed and the clients reconnect, which is the app's own recovery path.
- **Custom schemes.** The app serves `sand-avatar:`, `sand-favicon:`, `sand-media:`, `sand-canvas:`, `sand-html-preview:` and `sand-mcp-app:` through `protocol.handle`, and the relay records each registration. The shim rewrites those URLs wherever the UI can set one (src/href/srcset/poster, inline styles, `fetch`, XHR) to `/__relay/p/<secret>/…`. The relay fetches them back through `session.fetch`, which runs the app's own handlers, and streams the response, including Range requests. The secret is an unguessable per-process prefix rather than the cookie, because sandboxed frames send no cookies.
- **Sign-in.** Cursor login is a polling flow (`loginDeepControl` → `/auth/poll`). The sign-in page opens in your browser (a new tab, or the banner link if the popup was blocked), and the main process picks up the result.

## Setup

The image builds on `grokbot-xpra:local`, the Xpra POC image in `../grokbot`. Build that first; it provides the installed app, the keyring, and Xvfb.

```bash
cp .env.sample .env      # set RELAY_TOKEN (openssl rand -hex 24) and KEYRING_PASSWORD
mkdir -p data/home
docker compose build && docker compose up -d
```

Open `https://grokbot-web.internal.earles.io/?token=<RELAY_TOKEN>` once per browser. The token is stored in an HttpOnly cookie.

Any number of tabs and devices can be open at once. They all share the one hidden window and one coordinator. Changes made in one tab (new messages, agent state) reach the others as the app's own events.

## Smoke test

`tools/` runs the image's own Electron as a headless browser. It loads the page, optionally clicks a button, and logs console output, failed requests, and window.open URLs. It also saves a screenshot.

```bash
docker run --rm -v "$PWD/tools:/test:ro" -v /tmp/out:/out \
  -e TEST_URL="https://grokbot-web.internal.earles.io/?token=$(grep -oP '^RELAY_TOKEN=\K.*' .env)" \
  -e TEST_CLICK="Sign in" --entrypoint /test/smoke-test.sh grokbot-web:local
```

## Logs

`docker logs grokbot-web` shows `[relay]` lines: startup, links opened through `openExternal`, failed IPC invokes, scheme proxy failures, and UI reliability reports that are not `ok` (`client failure:`). Despite the name, most of the UI's `reportClientFailure` calls are ok-telemetry, so those are not logged. `RELAY_DEBUG=1` also logs every relayed channel name.

## Known gaps (spike)

- **Frame schemes.** `sand-html-preview:`, `sand-canvas:` and `sand-mcp-app:` frames are proxied but untested. In the app they get their own origin; here they are forced to an opaque origin with a `CSP: sandbox` header (no `allow-same-origin`), so features that need frame storage may break. Absolute paths (`/x`) inside framed documents resolve to the relay root.
- **Desktop-only features.** Window controls are no-ops. The `<webview>` teach-recording feature and the remote-computer (VNC) panel are untested.
- **Fragility.** The relay depends on internal names: the `preload.cjs` path, the main-window detection, and the `sand:*` channels. Re-test after every app update.
