# Open Wearables — Deployment Guide

Self-hosted platform to unify wearable health data (Garmin, Whoop, Oura, Polar, Suunto,
Strava, Fitbit, Ultrahuman, Apple/Samsung/Google Health) through one AI-ready API.
Source: https://github.com/the-momentum/open-wearables

---

## Prerequisites

- Traefik running with the `traefik` external network
- DNS records → dockerint01 host for:
  - `open-wearables.internal.earles.io` (developer portal / frontend)
  - `open-wearables-api.internal.earles.io` (FastAPI backend + Swagger docs)
  - `open-wearables-flower.internal.earles.io` (Celery Flower dashboard)

---

## Step 1 — Clone upstream source

The backend and frontend images are built from source; there are no pre-built images.

```bash
cd dockerint01/open-wearables
git clone https://github.com/the-momentum/open-wearables.git .tmp
# Move upstream files in without overwriting the customized compose + env
rsync -av --ignore-existing .tmp/ . && rm -rf .tmp
```

This brings in the `backend/` and `frontend/` directories (including their Dockerfiles)
that the `docker-compose.yml` in this directory builds against, plus `backend/config/.env.example`
and `frontend/.env.example`. The `docker-compose.yml` and `.env.sample` here already replace
the upstream root-level versions and add Traefik labels / network segmentation.

---

## Step 2 — Create env files

```bash
cp .env.sample .env
cp backend/config/.env.example backend/config/.env
```

(`frontend/.env.example` is not used — `VITE_API_URL` is passed as a Docker build arg from
the top-level `.env` instead, see below.)

### Decisions required

**Required, in `.env` (compose-level):**

| Variable | Decision |
|---|---|
| `DB_USER` / `DB_PASSWORD` | Must match the same values set in `backend/config/.env` — used here only to build the svix-server Postgres DSN. |
| `VITE_API_URL` | Public, browser-facing URL for the API. Defaults to the `open-wearables-api.internal.earles.io` Traefik host — leave as-is unless you changed that router's rule. |

**Required, in `backend/config/.env`:**

| Variable | Decision |
|---|---|
| `DB_USER` / `DB_PASSWORD` | Same values as above. |
| `SECRET_KEY` | Generate with `python3 -c "import secrets; print(secrets.token_urlsafe(64))"`. Also used as the default svix JWT signing secret. |
| `ADMIN_EMAIL` / `ADMIN_PASSWORD` | Auto-seeds the first developer account on startup. |
| `FRONTEND_URL` | Set to `https://open-wearables.internal.earles.io`. |
| `API_BASE_URL` | Set to `https://open-wearables-api.internal.earles.io` (used for OAuth redirect URIs). |
| `CORS_ORIGINS` | Set to `["https://open-wearables.internal.earles.io"]`. |

**Optional:** provider OAuth client IDs/secrets (Garmin, Polar, Suunto, Whoop, Oura, Strava,
Fitbit, Ultrahuman), Resend email API key, Sentry DSN, S3/AWS settings for raw payload storage.
All have working defaults/no-ops if left unset.

---

## Step 3 — Build and start

```bash
cd dockerint01/open-wearables
docker-compose up -d --build
```

On first boot the `app` container ensures the `svix` database exists, runs Alembic
migrations, seeds provider settings/device priorities/series types, and creates the
admin account. Watch progress with:

```bash
docker-compose logs -f app
```

Ready when logs show the FastAPI app serving on port 8000.

---

## Step 4 — Verify

- Developer portal: `https://open-wearables.internal.earles.io`
- API / Swagger docs: `https://open-wearables-api.internal.earles.io/docs`
- Flower (Celery monitoring): `https://open-wearables-flower.internal.earles.io`

Log in to the portal with `ADMIN_EMAIL` / `ADMIN_PASSWORD` from `backend/config/.env`.

Optional test data: `docker-compose exec app make seed` (creates test users + sample
activity data — check the upstream `Makefile` for the exact target).

---

## Notes

- `db` (Postgres) and `redis` are internal-only — no Traefik labels, `backend` network only.
- `svix-server` (webhook delivery) is also internal-only; it uses its own `svix` database
  on the same Postgres instance, auto-created by the backend on startup.
- Postgres and Redis data persist to `./db` and `./redis` bind mounts in this directory.
- To pick up upstream changes later, re-run Step 1's `git clone` + `rsync --ignore-existing`
  into a fresh `.tmp`, then `docker-compose up -d --build`.
