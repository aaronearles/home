#!/usr/bin/env python3
"""Ping a Minecraft Bedrock (NetherNet) server and display its status.

Since Bedrock 1.26.5x the server uses the NetherNet transport: clients do an HTTP
handshake on TCP server-port before negotiating UDP. `GET /v1/join` returns the
server's status as JSON, so that's what this queries - the same request the game makes.
(The old RakNet UDP ping no longer gets an answer.)

Clients try HTTPS first. For a hostname they require a publicly trusted certificate;
for a bare IP they fall back to plain HTTP. This script reports which of those works.

Usage:
    python3 ping.py                     # mc.earles.io and 172.20.100.202
    python3 ping.py mc.earles.io        # one host, port 19132
    python3 ping.py 172.20.100.202:19133  # straight to BDS, bypassing Traefik

Requires only the Python 3 standard library.
"""

import ipaddress
import json
import ssl
import sys
import urllib.request

DEFAULT_TARGETS = ["mc.earles.io:19132", "172.20.100.202:19132"]


def is_ip(host):
    try:
        ipaddress.ip_address(host)
        return True
    except ValueError:
        return False


def fetch(url, context=None, timeout=5):
    with urllib.request.urlopen(url, context=context, timeout=timeout) as resp:
        return json.loads(resp.read())


def ping(target):
    host, _, port = target.partition(":")
    port = port or "19132"
    base = f"{host}:{port}"
    print(f"=== {base} ===")

    attempts = [("HTTPS (verified cert)", f"https://{base}/v1/join", ssl.create_default_context())]
    if is_ip(host):
        # Clients connecting by IP accept the fallback, so it counts as working
        attempts.append(("plain HTTP (IP fallback)", f"http://{base}/v1/join", None))

    for label, url, ctx in attempts:
        try:
            info = fetch(url, ctx)
        except Exception as e:
            print(f"  {label:26} FAILED: {e}")
            continue
        print(f"  {label:26} OK")
        print(f"  Server name: {info.get('name')}")
        print(f"  Version:     {info.get('version')} (protocol {info.get('protocol')})")
        print(f"  Level name:  {info.get('level')}")
        print(f"  Players:     {info.get('players')}/{info.get('maxPlayers')}")
        print(f"  Game type:   {info.get('gameType')}")
        return True
    return False


def main():
    targets = sys.argv[1:] or DEFAULT_TARGETS
    results = [ping(t) for t in targets]
    sys.exit(0 if all(results) else 1)


if __name__ == "__main__":
    main()
