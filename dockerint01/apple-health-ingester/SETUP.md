# Apple Health Ingester — Deployment Guide

Simple Go HTTP server that ingests Apple Health data exported by the
[Health Auto Export](https://www.healthexportapp.com) iOS app via its REST API automation.
Source: https://github.com/irvinlim/apple-health-ingester

This deployment enables the **LocalFile** backend only — ingested payloads are written
as JSON to a bind-mounted directory, one file per metric. No database is required.

---

## Prerequisites

- Traefik running with the `traefik` external network
- DNS record for `apple-health-ingester.internal.earles.io` → dockerint01 host
- Your phone must be able to reach `*.internal.earles.io` when the Health Auto Export
  automation runs (e.g. via Tailscale/VPN back to the home network) — this stack is
  deployed on the internal tier, not DMZ, so it is not reachable from the open internet.
- A [Health Auto Export](https://www.healthexportapp.com) Premium subscription (or trial)
  on the iOS device, to unlock the Automations feature.

---

## Step 1 — Create .env

```bash
cd dockerint01/apple-health-ingester
cp .env.sample .env
```

Set `AUTH_TOKEN` to a strong random value:

```bash
python3 -c "import secrets; print(secrets.token_urlsafe(32))"
```

---

## Step 2 — Start the service

```bash
docker-compose up -d
```

No build step is required — this uses the pre-built `irvinlim/apple-health-ingester` image
from Docker Hub.

---

## Step 3 — Configure Health Auto Export on iOS

In the Health Auto Export app, create a new Automation:

1. **Automation Type**: `REST API`
2. **URL**: `https://apple-health-ingester.internal.earles.io/api/healthautoexport/v1/localfile/ingest`
   - Optional: append `?target=NAME` to tag exports from a specific person/device
     (e.g. `?target=Aaron`) — files will be prefixed with that name.
3. **Export format**: `JSON`
4. **Authorization header**: `Bearer <AUTH_TOKEN>` (the value you set in `.env`)
5. Choose which Health Metrics / Workouts to export.
6. Under **Manual Sync**, pick a time range and tap "Export" to test the connection.

Full instructions: https://www.healthyapps.dev/how-to-configure-automatic-apple-health-exports#restapi

---

## Step 4 — Verify

```bash
docker-compose logs -f apple-health-ingester
ls -la data/
```

After a successful export, you should see one JSON file per metric in `./data`
(e.g. `active_energy_kJ.json`, `step_count_count.json`), optionally prefixed with the
`target` name if used.

---

## Notes

- **Workout data is not supported by the LocalFile backend** (upstream limitation) —
  only metrics are written. Switch to (or add) the InfluxDB backend if you need workout
  data persisted.
- To add the InfluxDB backend later: append `--backend.influxdb`,
  `--influxdb.serverURL=...`, `--influxdb.authToken=...`, `--influxdb.orgName=...`,
  `--influxdb.metricsBucketName=...`, `--influxdb.workoutsBucketName=...` to the
  `command:` list in `docker-compose.yml` (requires an InfluxDB instance — none exists
  elsewhere in this repo yet).
- The image's Dockerfile does not `EXPOSE` a port, so Traefik can't auto-detect it —
  that's why `loadbalancer.server.port=8080` is set explicitly in the labels.
