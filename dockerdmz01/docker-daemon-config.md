# dockerdmz01 — Docker Daemon Config

Host-level `/etc/docker/daemon.json` decisions for **dockerdmz01**, and why.
This file isn't itself version-controlled (root-owned, lives only on the
host) — this doc is the source of truth for what it should contain and why.
Companion to [dockerint01/docker-daemon-config.md](../dockerint01/docker-daemon-config.md),
which covers the same two settings for dockerint01.

## Default address pool: `10.201.0.0/16`

**Problem:** `default-address-pools` is undefined on dockerdmz01, so Docker
auto-assigns bridge subnets out of its default `172.17.0.0/16`–
`172.30.0.0/16` range. As of 2026-08-07 that's already given `bridge`,
`cloudflared`, `traefik`, and `watchtower_default` four different `172.x.0.0/16`
networks — the same range used for routing to remote sites (site-to-site
VPN routes, other VLANs, etc.), so any of those subnets can collide with a
real route.

**Standard:** each Proxmox host gets its own `10.<PCT_ID>.0.0/16` block for
Docker's internal bridge networks, where `<PCT_ID>` is that host's Proxmox
container/VM ID. dockerdmz01 is **PCT 201** (static IP `172.20.255.201`), so
it gets:

```json
{
  "default-address-pools": [
    { "base": "10.201.0.0/16", "size": 24 }
  ]
}
```

Each compose stack's bridge network gets a `/24` out of that `/16`. The PCT
ID → pool mapping means every Docker host's internal networks are guaranteed
non-overlapping with each other and with the real infrastructure network,
just by construction — dockerint01 (PCT 202) is on `10.202.0.0/16`, so
dockerdmz01 (PCT 201) on `10.201.0.0/16` can never collide with it either.
Apply the same pattern on dockerlab01 and any future Docker host, keyed to
each host's own PCT ID.

**Note:** this only affects *new* networks — `bridge`, `cloudflared`,
`traefik`, and `watchtower_default` all keep their current `172.x` subnets
until their stacks are torn down and brought back up after the daemon
restart below.

## Log rotation: `json-file` with `max-size`/`max-file`

**Problem:** dockerdmz01 has no `/etc/docker/daemon.json` at all, so
`log-driver`/`log-opts` are unset and every container's `json-file` log is
unbounded. This is the same gap that caused an incident on dockerint01 on
2026-08-07: a corrupted MyISAM table in the `blog-db` container's WordPress
database made every query against it fail and log continuously for ~9 hours,
writing 92GB to one container's log file and filling that host's root disk
to 100%. dockerdmz01 runs the public-facing edge (Traefik, Cloudflare
tunnel, auth proxy) — a disk-full failure here takes down external access to
everything behind it, so this is at least as important to fix here as it was
on dockerint01.

**Standard:** cap logs host-wide, so no single container can do this again:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  }
}
```

That's a 50MB ceiling per container. Requires `sudo systemctl restart
docker` to take effect, and (like the address pool) only applies to
containers started/recreated after the restart.

As belt-and-suspenders, stacks can also set this per-service in their own
`docker-compose.yml`, so the cap applies even before/without a daemon-wide
restart. See `dockerint01/blog/docker-compose.yml` for an example of the
`logging:` block to copy into dockerdmz01 stacks.

## Combined `daemon.json`

dockerdmz01 has no `daemon.json` today, so this is the full file to create
at `/etc/docker/daemon.json`:

```json
{
  "default-address-pools": [
    { "base": "10.201.0.0/16", "size": 24 }
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  }
}
```

## Follow-up

- Create `/etc/docker/daemon.json` on dockerdmz01 with the block above, then
  `sudo systemctl restart docker` (briefly restarts every container on the
  host — the edge for all external-facing services, so pick a low-traffic
  window).
- Recreate `bridge`, `cloudflared`, `traefik`, and `watchtower_default` next
  time it's convenient, so they pick up the `10.201.x.0/24` pool.
- Apply the same `daemon.json` to dockerlab01 (own PCT ID) too — the
  unbounded-log risk isn't specific to any one host.
