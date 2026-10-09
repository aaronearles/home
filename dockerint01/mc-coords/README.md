# mc-coords

Self-hosted Minecraft coordinate tracker (a take on the "Minecraft Coords" iOS app) as an installable PWA.

- **Coords**: Bookmarks / Overworld / Nether / End tabs, search, one-tap copy (`x y z`, `x, y, z` or `/tp`)
- **Map**: per-dimension chunk grid with pan / pinch / wheel zoom, nether↔overworld overlay (÷8 / ×8),
  tap a marker for details, long-press empty space to add a location there
- **Locations**: name, XYZ, dimension, category (emoji + colour, editable per world), related-location
  tags, notes, a photo; "quick paste" pulls coordinates out of F3+C / chat text
- **Multiplayer**: 6-digit invite codes (24h TTL), invite links (`/?join=123456`), live sync over SSE,
  "last edited by" attribution
- Works offline read-only (app shell cached by the service worker, last world state in localStorage)

## Stack
Single Node 22 process, zero npm dependencies: `node:http` + built-in `node:sqlite`.
Data (SQLite DB + images) lives in the `mc_coords_data` named volume at `/data`.

## Deploy
```bash
cd dockerint01/mc-coords
docker compose up -d --build
```
Served at `https://mc-coords.internal.earles.io`. Add a Gatus check on `/healthz`.

## Access model
There are no accounts. Each world has a random 128-bit id that acts as its access key; devices that
created or joined a world keep the id in localStorage. Invite codes are 6 digits, expire, and joining is
rate-limited per IP. Player names are self-declared — or, if Authentik forward-auth is put in front via a
Traefik middleware, the `X-Authentik-Username` header is used instead.

## Backup
Settings → "Export backup (JSON)", or snapshot the volume:
```bash
docker run --rm -v mc_coords_data:/data -v "$PWD":/backup alpine tar czf /backup/mc-coords.tgz -C /data .
```

## Local dev
```bash
DATA_DIR=./data node server.mjs   # http://localhost:3000
python3 make_icons.py              # regenerate PWA icons (needs Pillow)
```
