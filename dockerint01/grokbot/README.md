# Grok Bot (browser-streamed)

This stack runs the official Grok Bot Linux build (an Electron app) in a container. **Xpra** streams its windows to the browser at `https://grokbot.internal.earles.io`, behind the Xpra password. It is internal only: no public route, and Traefik serves it on the LAN/VPN.

The app is installed as shipped, with no patches. It talks to xAI and Cursor directly from the container.

**Why Xpra over KasmVNC:** Xpra is seamless, so each app window becomes its own browser window instead of a whole remote desktop. It also forwards audio (Opus) and the clipboard over a single WebSocket, and it can keep `xdg-open` local (`--forward-xdg-open=off`). That last point matters for sign-in: the Cursor callback has to land on a browser inside the container, not on your laptop.

```
browser ──HTTPS──▶ Traefik ──ws (traefik network)──▶ grokbot:14500 ── Xpra password ──▶ Xvfb + Grok Bot + Firefox
```

## Layout

| Path | Purpose |
|------|---------|
| `Dockerfile` | Debian trixie + Xpra (xpra.org repo) + Firefox ESR + gnome-keyring + the official package |
| `rootfs/usr/local/bin/install-app` | Installs the `.deb` with apt, or unpacks an AppImage without running it. Records the launcher and URL schemes. |
| `rootfs/usr/local/bin/grokbot-entrypoint` | Writes the passwords to private files, sets the default URL handlers, runs Xpra |
| `rootfs/usr/local/bin/grokbot-session` | Unlocks the keyring and runs the app, restarting it if it exits |
| `installer/` | Put the official installer here (not committed) |
| `data/home/` | Persistent `$HOME`: app profile (`~/.config/<App Name>`), keyring, Firefox profile (not committed) |
| `tools/` | Phase 1 inspection script and its throwaway image |

## Phase 1 inspection (run before the first build)

This step is read-only. It unpacks the package and greps the bundle, and it never runs the app. It has no network access.

```bash
docker build -t grokbot-inspect -f tools/Dockerfile.inspect tools
mkdir -p scratch
docker run --rm --network none \
  -v "$PWD/installer:/in:ro" -v "$PWD/tools:/tools:ro" -v "$PWD/scratch:/out" \
  grokbot-inspect bash /tools/inspect.sh "/in/<installer file>"
less scratch/REPORT.md
```

Read the report for the following:

- **URL scheme:** check the `MimeType=x-scheme-handler/...` line.
- **Updater feed host:** check `app-update.yml`.
- **Load model:** check whether the app uses `loadURL` or `loadFile`.
- **Keyring:** check for `safeStorage` or `keytar`.

## First-time setup

1. **Installer.** Copy the `.deb` (preferred) or `.AppImage` that matches the host architecture into `installer/`. Use the one from *More downloads* on x.ai/bot. An `.rpm` is not supported on this Debian base, so use the `.deb` instead.
2. **Environment.** Run `cp .env.sample .env`. Set `GROKBOT_INSTALLER`, then set `XPRA_PASSWORD` and `KEYRING_PASSWORD` using `openssl rand -base64 24`. Store both passwords in Vaultwarden.
3. **Data directory.** Run `mkdir -p data/home && sudo chown 1000:1000 data/home`.
4. **Build and start.** Run `docker compose build && docker compose up -d`.
5. **Check the gate.** Open `https://grokbot.internal.earles.io` in a browser; it must show the Xpra password prompt before any stream. Gatus checks that the page returns 200 and alerts if it stops.

## First-run sign-in

1. Open `https://grokbot.internal.earles.io` and enter the Xpra password. The Grok Bot window appears.
2. Click **Sign In with Cursor**. The app calls `xdg-open`, which opens **Firefox inside the session** as a second streamed window. Sign in there.
3. The callback returns to the app in one of these ways:
   - **Custom scheme:** Firefox asks which app should open the link. Choose Grok Bot, tick *Always*, and confirm. The entrypoint already registered the scheme from the app's `.desktop` file.
   - **Localhost callback:** works as-is, because Firefox and the app share the container's loopback.
   - **Device code:** copy the code into the in-session Firefox, or any browser.
4. Close Firefox. The tokens are encrypted in the keyring under `data/home`, so the sign-in survives restarts and rebuilds.

## Updating

Run the app as a fixed version and rebuild the image to update it, instead of letting it update itself.

- **Why in-app updates can't install.** The app runs as an unprivileged user with no `sudo` or `pkexec`, and `/opt` is root-owned. Rebuilding also resets the image anyway. An AppImage that has been unpacked has no `$APPIMAGE` variable, so electron-updater skips it.
- **Blocking the update check.** If the app keeps notifying you about updates, you can block its feed host. Take the host from `app-update.yml` in the Phase 1 report, then add `extra_hosts: ["<feed host>:0.0.0.0"]` to the service. Only do this if the host is dedicated to updates, never if it is an API host.

To update:

```bash
# download the new official package into installer/, then:
sed -i 's/^GROKBOT_INSTALLER=.*/GROKBOT_INSTALLER=<new file>/' .env
docker compose build --pull && docker compose up -d
docker image prune -f
```

Re-run the Phase 1 inspection on each new version. If the update feed host or the URL scheme changed, update `extra_hosts` or rebuild accordingly.

## Backups

`data/home/` holds everything stateful: the app profile, the keyring, and the Firefox profile. Treat it as a credential store.

```bash
docker compose stop
sudo tar -czf grokbot-home-$(date +%F).tgz -C data home
docker compose start
```

- Encrypt the archive at rest.
- The keyring can only be read with `KEYRING_PASSWORD`. Back that password up separately, in Vaultwarden.
- If the backup is lost, you lose nothing except the sign-in: sign in again.

## Exposure plan (what is reachable, by whom)

| Surface | Reachable from | Protection |
|---------|---------------|------------|
| Xpra `:14500` | Only containers on the `traefik` Docker network. No host port is published. | Xpra password |
| `https://grokbot.internal.earles.io` | Wherever the dockerint01 Traefik `:443` is reachable (LAN/VPN) | TLS (Let's Encrypt), Xpra password. No Authentik. |
| Public internet | **Not exposed.** There is no Cloudflare tunnel, DMZ route, or port forward. | — |

Do not add this to `dockerdmz01` or a Cloudflare tunnel without a separate review. Anyone who reaches the stream controls the Grok/Cursor account and its Bots' cloud computers.

The commented `127.0.0.1:14500` port in `docker-compose.yml` is for debugging on the host only, and it bypasses the Xpra password.

## Security notes

- **Chromium sandbox.** `APP_ARGS` includes `--no-sandbox` because Docker's default seccomp profile blocks Chromium's namespace sandbox.
  - The container is the isolation boundary, and the app only renders first-party xAI/Cursor content.
  - To keep the Chromium sandbox instead, remove the flag and run with a seccomp profile that allows `clone`/`unshare` namespaces. Do not use `CAP_SYS_ADMIN`.
- **Keyring backend.** `--password-store=gnome-libsecret` forces Electron's `safeStorage` to use the keyring. With no desktop environment, Chromium would otherwise fall back to plaintext ("basic") storage.
- **Disabled Xpra features.** Microphone, webcam, file transfer, opening files, and client-initiated commands are all off. Clipboard is two-way. The HTML5 client asks the browser for clipboard permission.
