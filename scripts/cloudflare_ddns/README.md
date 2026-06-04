# Cloudflare DDNS Updater

Bash script that monitors your external IP and updates Cloudflare DNS A records when it changes. Supports multiple records via separate `.env` config files.

## Features

- **Single script, multiple records** — one `ddns.sh` driven by per-record `.env` files
- **Retry with backoff** — 3 attempts per cycle with exponential backoff between rounds
- **Provider fallback** — cycles through ifconfig.io, api.ipify.org, and icanhazip.com
- **Request jitter** — random 0–30s delay to avoid thundering herd on round-minute cron
- **Notifications** — pushes updates and errors to [ntfy.sh](https://ntfy.sh)

## Dependencies

- `curl`
- `jq`

## Setup

### 1. Create env file

```bash
cp env.sample /etc/ddns/myrecord.env
```

Fill in the values:

| Variable | Description |
|---|---|
| `ZONEID` | Cloudflare Zone ID ([docs](https://developers.cloudflare.com/api/operations/zones-get)) |
| `RECORDID` | DNS Record ID ([docs](https://developers.cloudflare.com/api/operations/dns-records-for-a-zone-list-dns-records)) |
| `TOKEN` | API Token with `Zone:DNS:Edit` permission |
| `NAME` | FQDN of the A record (e.g. `vpn.earles.io`) |
| `NTFYTOPIC` | ntfy.sh topic for notifications |
| `LOGPATH` | Log file path (default: `/var/log/ddns.log`) |

### 2. Deploy script

```bash
sudo cp ddns.sh /usr/local/bin/ddns
sudo chmod 755 /usr/local/bin/ddns
```

### 3. Add cron entries

```cron
*/5 * * * * /usr/local/bin/ddns /etc/ddns/vpn.env
*/5 * * * * /usr/local/bin/ddns /etc/ddns/watchman.env
```

## Finding your Record ID

```bash
ZONEID="your-zone-id"
TOKEN="your-api-token"
curl -s "https://api.cloudflare.com/client/v4/zones/$ZONEID/dns_records" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" | jq '.result[] | {id, name, type, content}'
```

## How it works

1. Sleeps a random 0–30s to jitter off the cron minute boundary
2. Queries external IP providers (with retry/fallback if one is down)
3. Fetches the current A record value from Cloudflare
4. If the IP changed, PUTs the update and sends an ntfy notification
5. Logs every run (change or no-change) to `$LOGPATH`

## File structure

```
cloudflare_ddns/
├── ddns.sh          # Main script
├── env.sample       # Template for new records
├── vpn.env          # Config for vpn.earles.io
├── watchman.env     # Config for watchman.earles.io
├── archive/         # Previous per-record scripts
└── README.md
```

> **Note:** `*.env` files are gitignored to prevent committing API tokens.
