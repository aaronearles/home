# dockerint01 — Docker Daemon Config

Host-level `/etc/docker/daemon.json` decisions for **dockerint01**, and why. This
file isn't itself version-controlled (root-owned, lives only on the host) —
this doc is the source of truth for what it should contain and why.

## Default address pool: `10.202.0.0/16`

**Problem:** `default-address-pools` was undefined, so Docker auto-assigned
bridge subnets out of its default `172.17.0.0/16`–`172.30.0.0/16` range. Those
overlapped with the real internal network scheme used for routing to remote
sites (site-to-site VPN routes, other VLANs, etc.), causing conflicts whenever
a new compose network landed on a subnet that was already in use elsewhere.

**Standard:** each Proxmox host gets its own `10.<PCT_ID>.0.0/16` block for
Docker's internal bridge networks, where `<PCT_ID>` is that host's Proxmox
container/VM ID. dockerint01 is **PCT 202** (static IP `172.20.100.202`), so
it gets:

```json
{
  "default-address-pools": [
    { "base": "10.202.0.0/16", "size": 24 }
  ]
}
```

Each compose stack's bridge network gets a `/24` out of that `/16`, giving
~254 possible networks before the pool is exhausted — plenty for this host.

The PCT ID → pool mapping means every Docker host's internal networks are
guaranteed non-overlapping with each other and with the `172.20.100.0/24`
management network, just by construction — no need to track subnet
allocations by hand across hosts. Apply the same pattern (`10.<PCT_ID>.0.0/16`)
on dockerlab01, dockerdmz01, etc. using each host's own PCT ID.

**Note:** this only affects *new* networks — anything created before the
`daemon.json` change (and not since recreated) keeps its old `172.x` subnet
until the stack is torn down and brought back up. E.g. on dockerint01 the
`traefik` network is still on `172.18.0.0/16` as of 2026-08-07; newer stacks
(`romm_backend`, `blog_backend`, etc.) are already on `10.202.x.0/24`.

## Log rotation: `json-file` with `max-size`/`max-file`

**Problem:** the daemon had no `log-driver`/`log-opts` set, so every
container's `json-file` log was unbounded. On 2026-08-07, `blog-db`'s
`wp_options` table got corrupted (unrelated MyISAM crash-safety issue,
surfaced by a container restart during the address-pool change above), which
caused every WordPress query against it to fail and log continuously for
~9 hours — 92GB in one container's log file, which filled the host's root
disk to 100%.

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
`docker-compose.yml` (see `dockerint01/blog/docker-compose.yml` for an
example) so the cap applies even before/without a daemon-wide restart.

## Combined `daemon.json`

```json
{
  "default-address-pools": [
    { "base": "10.202.0.0/16", "size": 24 }
  ],
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "5"
  }
}
```

## Follow-up

- Apply the same `log-driver`/`log-opts` default to dockerlab01 and
  dockerdmz01 — the unbounded-log risk isn't specific to dockerint01.
  dockerdmz01 is covered in
  [dockerdmz01/docker-daemon-config.md](../dockerdmz01/docker-daemon-config.md)
  (PCT 201 → `10.201.0.0/16`).
- Recreate the `traefik` network (and any other pre-existing network still on
  a `172.x` subnet) next time it's convenient, so it picks up the
  `10.202.x.0/24` pool.
