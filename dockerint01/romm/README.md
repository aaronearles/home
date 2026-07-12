# romm

[RomM](https://github.com/rommapp/romm) is a self-hosted ROM manager with a web UI for browsing, organizing, and downloading game files. This stack runs RomM with a MariaDB backend and a lightweight compatibility proxy sidecar (`romm-compat-proxy`) that keeps the [Grout](https://github.com/rommapp/grout) handheld client working against RomM 4.9.x.

## Services

| Service | Image | Purpose |
|---|---|---|
| `romm` | `rommapp/romm:latest` | ROM manager web application |
| `romm-proxy` | built from `./romm-compat-proxy` | Grout compatibility proxy (see below) |
| `romm-db` | `mariadb:lts` | Database backend |

## Directory structure

```
romm/
├── docker-compose.yml
├── .env                        # App secrets (not in git — see .env.sample)
├── .db.env                     # DB credentials (not in git — see .db.env.sample)
├── config/
│   └── config.yml              # RomM configuration
├── db/                         # MariaDB data directory (not in git)
└── romm-compat-proxy/
    ├── proxy.py                # FastAPI proxy application
    └── dockerfile              # python:3.12-slim image
```

## Setup

### 1. Create environment files

```bash
cp .env.sample .env
cp .db.env.sample .db.env
```

Edit both files and fill in your values (library path, asset path, IGDB credentials, etc.).

### 2. Start the stack

```bash
docker compose up -d
```

RomM will be available at `https://romm.internal.earles.io` via Traefik.

## Grout compatibility proxy

### Why it exists

In June 2026, RomM 4.9.0 (PR #3425) removed the `files` field from the
paginated `GET /api/roms` response (`SimpleRomSchema`). Grout 4.8.x builds
its download queue from this list and crashes when `files` is missing.

RomM 4.9.0 (PR #3490) re-added `files` as opt-in via `?with_files=true`,
but Grout 4.8.x doesn't know to request it.

Downgrading RomM was not viable — the 4.9.x Alembic migrations (e.g.
`0082_save_origin_device`) have no clean downgrade path against MariaDB.

### What the proxy does

`romm-proxy` sits between Traefik and the `romm` container. It intercepts
`GET /api/roms` requests and appends `with_files=true` to the query string
before forwarding upstream. All other requests pass through unmodified.

```
Grout (handheld)
      │
      ▼
Traefik (TLS termination)
      │
      ▼
romm-proxy:8888  ← injects with_files=true on GET /api/roms
      │
      ▼
romm:8080
      │
      ▼
romm-db:3306
```

Key behaviours:
- `GET /api/roms*` — appends `with_files=true` if not already present
- All other requests — transparent passthrough
- `set-cookie` is forwarded (sessions work correctly)
- `content-encoding` is stripped to prevent double-decompression (RomM's
  internal nginx gzips responses; httpx decompresses them transparently)

### Removing the proxy (when Grout 4.9.x is released)

1. In `docker-compose.yml`, move the Traefik labels back to the `romm` service
2. Restore `romm` to the `traefik` network
3. Remove the `romm-proxy` service block entirely
4. Delete the `romm-compat-proxy/` directory
5. `docker compose up -d`

Track the Grout release: https://github.com/rommapp/grout/releases
