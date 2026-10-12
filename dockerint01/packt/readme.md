# packt

Serves the locally-archived Packt library (built by
[`packt-archive.py`](https://github.com/aaronearles/packt-archiver)) as a
browsable web library at `https://packt.internal.earles.io`, via a plain
nginx container behind Traefik.

Each title's video package is Packt's own self-contained "Packt Video
player" (video.js, chapter TOC, prev/next nav) — this stack doesn't build
any playback UI, it just serves those files and adds one landing page that
links out to all of them.

## Layout

```
packt/
├── docker-compose.yml
├── nginx.conf              # landing page + /library/ autoindex + mp4 byte-range
├── generate-index.py       # (re)builds html/index.html from the archive
└── html/
    ├── index.html          # generated — not committed, see .gitignore
    └── library/.gitkeep    # empty mountpoint the archive bind-mounts onto
```

`html/library/.gitkeep` exists only so the directory is present at clone
time — Docker can't create a mountpoint inside an already-mounted
read-only volume, so the empty dir has to already exist on disk before
`docker compose up`.

The archive itself (`/mnt/media/Packt/Material`, ~83GB) is bind-mounted
read-only into the container at `/library/` — nothing is copied.

## Setup

```bash
./generate-index.py     # writes html/index.html from the current archive
docker compose up -d
```

Available at `https://packt.internal.earles.io`.

## Adding new titles later

Whenever `packt-archive.py` picks up newly-purchased titles (e.g. via its
cron/systemd-timer job), just regenerate the landing page — no rebuild or
restart needed, nginx reads it fresh on every request:

```bash
./generate-index.py
```

## Notes

- Titles are matched from `manifest.csv` (written by `packt-archive.py`) to
  their on-disk folder by the trailing `_<isbn>` suffix. If a title dir has
  no matching manifest row (e.g. it was added manually), its folder-name
  slug is used as a fallback title.
- `/library/` has `autoindex on`, so you can also just browse straight into
  any title's `code/` folder or other package assets that aren't explicitly
  linked from a card.
- Internal-only by design (`*.internal.earles.io`, no DMZ/external
  exposure) — this is your own purchased content, served only to your own
  network.
