# Plan: multiple servers on the LAN tab (no extra Xbox accounts)

**Status:** partly tested 2026-10-17 (see [Results](#results-2026-10-17)). **Discovery works and several servers list at once. Joining fails** because of a BDS 1.26.5x NetherNet bug ([BDS-23108](https://mojira.dev/BDS-23108)). Xbox not tested yet. Written 2026-10-12.

**Goal:** run several Bedrock servers at once (e.g. Skyblock, survival, creative) and let the Xbox join any of them, including **split-screen**. Avoid three Microsoft broadcast accounts and three MCXboxBroadcast sidecars. Ideally avoid needing a Game Pass subscription.

## Results (2026-10-17)

Tested with [aaronearles/mc-lan](https://github.com/aaronearles/mc-lan): two LXCs on pve (CT 221 "EARLES Survival", CT 222 "EARLES Creative"), each with eth0 on Trusted and eth1 tagged VLAN 10 (Users, `172.20.10.5` / `.6`), running the same itzg image with host networking. BDS 1.26.52.3 (latest stable; the only newer build is the 1.26.70.20 preview). Client: iPhone, 1.26.52.

**What works**
- **The theory about discovery was right.** With an address on `172.20.10.0/24`, both servers answer NetherNet LAN discovery (UDP 7551) and appear in the iPhone's LAN list together, with no extra accounts. They also appear when the phone is on VLAN 100.
- `dockerint01` answers LAN discovery too. While MCXboxBroadcast runs, the client shows Skyblock only once, as "Friend's world".
- VLAN 10 broadcasts also reach the Trusted segment (they show up on the CTs' untagged eth0). That explains the 2026-10-09 captures.

**What fails: every LAN join**
- Joining any LAN entry fails with **"Boat", `InitialConnection-145`, `Transport: NetherNet:2193`**. This happened with both new servers, and with **Skyblock on `dockerint01` with MCXboxBroadcast stopped**, from both VLAN 10 and VLAN 100. So it isn't the network, the VLAN, the firewall (Users → Trusted is allowed) or the LXC setup.
- **What the captures show** (the discovery packets decrypt with the fixed key `sha256(uint64le 0xdeadbeef)`, as in `df-mc/go-nethernet`):
  - The server's reply is well-formed: name, protocol 2193, 1.26.52, world, player counts.
  - On join, the phone sends the server **one NetherNet message (id 2) with sender ID 0 and empty data** to 7551. The server never replies, and the phone sends nothing else: no TCP 19132, no ICE, nothing through the signaling service. Skyblock showed "Connecting…" before failing. The new servers failed instantly. The traffic on the wire was the same.
- **This is a known, open, unconfirmed bug: [BDS-23108](https://mojira.dev/BDS-23108)** "Transport type 'nethernet' renders server inaccessible" (1.26.51.1 and 1.26.52.3; Windows, Xbox, PlayStation, Switch, iOS). People there report the same `InitialConnection-145 … NetherNet:2193`. See also [BDS-23111](https://mojira.dev/BDS-23111).
- **`transport=raknet` is not an option.** BDS 1.26.52.3 logs "NetherNet is the only supported transport type". A RakNet server answers the phone's RakNet LAN pings (UDP 19132), but the phone still never tries to join it.
- **Also found:** on a fresh data directory, current BDS writes `allow-list=true` with an empty list, which rejects everyone. Set `ALLOW_LIST=false`. `dockerint01`'s older `server.properties` already has it off.

**Workarounds reported on BDS-23108 (not tested yet)**
1. **Join once by IP:** after one successful manual join by IP:port, LAN joins reportedly work until the next BDS restart.
2. **`online-mode=false` + `allow-list=false`:** reportedly works every time. It turns off Xbox Live authentication, which might be acceptable for LAN-only servers on the Users VLAN, but gamertags are then unverified.

**Next**
- Try the two workarounds from the iPhone.
- Test from the Xbox: LAN list, join, split-screen.
- Watch BDS-23108 and the next BDS release. If LAN joins stay broken, the [fallback](#fallback-three-broadcast-accounts-friends-tab-works-anywhere) is the only working route today. Check first whether split-screen works on the Friends route with today's Skyblock.
- The public servers (CubeCraft and so on) that show up as "LAN world" on the phone come from the internet. They also appear on cellular, so they aren't LAN discovery.

## The constraints

- **Xbox can't add custom servers.** The Servers tab only offers featured servers. An Xbox can reach our server through exactly two routes:
  - **Friends tab:** MCXboxBroadcast advertises the `mcearlesio` account's session and hands joiners off to one address. One account = one server.
  - **LAN tab:** local discovery.
- **The DNS trick** (redirecting a featured server's hostname) lets Xbox reach a custom server, but it's treated as a public server, so **split-screen doesn't work**. Friends-list joins (and presumably LAN joins) count as joining a friend's world, which supports split-screen.

## Why the LAN tab never worked before

You remembered needing MCXboxBroadcast even on the LAN, including on the same VLAN. There were two independent blockers. **Both are explained, and one is already gone.**

1. **Docker bridge networking (fixed 2026-10-09).** Until then the server ran in Docker's default bridge network with ports published. Published ports forward packets addressed to the host itself. LAN discovery uses **broadcast** packets, which Docker's port forwarding doesn't pick up. So the server never saw a discovery request, whatever VLAN the Xbox was on. The server now uses `network_mode: host` (required for NetherNet's UDP), so this blocker no longer applies.
2. **Subnet mismatch (still present).** Packet captures on 2026-10-09 showed:
   - iPhone `172.20.10.67` and Xbox `172.20.10.109` sending discovery broadcasts to `172.20.10.255:7551` (NetherNet) and `:19132` (legacy RakNet).
   - **Those broadcasts arrive at this host's `eth0`.** The client subnet and `172.20.100.0/24` share one Layer-2 segment.
   - The host only has `172.20.100.202/24`, so the kernel drops packets addressed to `172.20.10.255`, which isn't one of its broadcast addresses.
   - BDS *is* listening for them: `*:7551` UDP (NetherNet LAN discovery).

**Theory:** give the server an address on `172.20.10.0/24` and it should answer discovery, so "EARLES" appears in the Xbox LAN tab.

Another point in favour: NetherNet LAN joins happen directly between the devices (discovery and signaling on 7551, gameplay over WebRTC/UDP). They don't use the TCP 19132 HTTPS handshake, Traefik, or the `mc.earles.io` certificate.

## Game Pass (to verify, not confirmed)

My understanding, which may be out of date:

| Route | Subscription needed on Xbox? |
|---|---|
| Friends tab via MCXboxBroadcast | **Yes**. It counts as online multiplayer (Game Pass Core/Ultimate). Since this works for us today, the Xbox account presumably has it. |
| LAN tab | Traditionally **no**: LAN and split-screen were exempt. |
| Realms | Has its own subscription. |

If LAN joins really don't need Game Pass, that's one more reason to prefer this route. Check against Microsoft's current policy when testing, e.g. on an Xbox profile without Game Pass.

## Test plan (one server first)

Needs root on the Proxmox host. The server is in **CT 202** (going by its disk name `pve-vm--202--disk--0`).

1. **Add an address on the client subnet**, using one of:
   - **Temporary**, as root inside CT 202: `ip addr add 172.20.10.250/24 dev eth0`. It's lost on reboot, which is fine for a test.
   - **Permanent**, on the Proxmox host: add a second NIC, e.g. `pct set 202 -net1 name=eth1,bridge=<same bridge as net0>,ip=172.20.10.250/24`. Check the bridge/VLAN tag matches where the Xbox lives.
   - Pick an address that's free and outside the DHCP range.
2. **Watch the traffic** while the Xbox opens Play → Friends/LAN:
   ```bash
   docker run --rm --net host --cap-add NET_RAW --cap-add NET_ADMIN python:3.12-alpine sh -c \
     'apk add -q tcpdump >/dev/null && timeout 300 tcpdump -i any -nn "host 172.20.10.109 and udp port 7551"'
   ```
   Expect Xbox → `172.20.10.255:7551` requests **and** replies from the server.
3. **Check the LAN tab.** "EARLES" should be listed. Join it.
4. **Try split-screen.** Second controller and profile, join the same LAN game.
5. **Optional:** sign in with a profile that has no Game Pass and see whether the LAN join still works.

**Success:** the server shows in the LAN tab and the join works, including split-screen.

**If it doesn't show:**
- Confirm broadcasts reach the new address.
- Check whether BDS replies at all (maybe it only answers on certain interfaces).
- Check whether `ENABLE_LAN_VISIBILITY=true` is still honoured under NetherNet. The server log may mention LAN or broadcast-domain messages (the binary has `[LAN] removing %s from broadcast domain`).

## If it works: the multi-server design

Each server needs **its own IP**, because each binds UDP 7551 for discovery. Two ways:

- **One LXC per server (cleanest):** CT A = Skyblock, CT B = survival, CT C = creative.
  - Each LXC has an address on `172.20.10.0/24` and runs this same `mc-bedrock` stack (minus or plus MCXboxBroadcast).
  - Each needs its own `SERVER_NAME` so the LAN tab can tell them apart.
  - The ports can be the same in every LXC, since they're separate network stacks.
- **One host, several IPs:** possible, but BDS would have to bind a specific address (`server-ip=`). Port conflicts (7551, gameplay UDP range) need care. More fiddly than separate LXCs.

**What changes compared with today:**

| | Today (rotation) | LAN multi-server |
|---|---|---|
| Worlds online at once | 1 (`switch-world.sh`, ~80s) | all |
| Xbox route | Friends tab (MCXboxBroadcast) | LAN tab |
| Extra accounts | none | none |
| Split-screen | yes | expected yes (untested) |
| Works away from home | via broadcaster + port forward | no, LAN only |
| Game Pass on Xbox | needed (online) | possibly not |
| Resources | 1 server | ~3× RAM/CPU |

You can still keep MCXboxBroadcast on one server (e.g. survival) for away-from-home or friend access.

**Things to carry over to each new LXC:**
- host networking
- NetherNet settings
- the TIME_WAIT entrypoint wrapper
- the TCP healthcheck
- per-mode cheats
- `gamerule pvp false`
- backups (a nightly backup and join snapshot per server, or centralise them)

## Fallback: three broadcast accounts (Friends tab, works anywhere)

If LAN discovery can't be made to work:
- Run three servers on this host with distinct internal signaling ports and UDP ranges.
- Run three MCXboxBroadcast sidecars, each signed in as its own Microsoft account and pointing at its own hostname.
- Route by hostname on the single port 19132 with Traefik `HostSNI` routers: `mc.earles.io`, `creative.earles.io`, `skyblock.earles.io`, each with its own Let's Encrypt cert.
  - This works because the friends-list hand-off uses the hostname.
  - Joining by IP can only reach one default server, since there's no hostname to route on.
- **Costs:**
  - three accounts to create and friend
  - needs Game Pass (online route)
  - ~3× resources

## Open questions

- ~~Does BDS 1.26.5x answer NetherNet LAN discovery on every interface, or only some?~~ Every interface: it answered on both eth0 and eth1 (2026-10-17). Joining is the problem, see Results.
- ~~Does the iPhone LAN tab behave the same?~~ It lists the servers, but joins fail (BDS-23108).
- Do the BDS-23108 workarounds (join once by IP, or `online-mode=false`) make LAN joins work?
- Does the Xbox behave the same?
- Is split-screen allowed when joining a dedicated server through the LAN tab? (Untestable until a LAN join works.)
- Is Game Pass really not required for LAN joins on current Xbox Minecraft?
