#!/usr/bin/env python3
"""Ping a Minecraft Bedrock server and display its MOTD info."""

import socket
import struct
import sys
import time


def ping_bedrock(host, port=19132, timeout=5):
    UNCONNECTED_PING = b'\x01'
    TIME_STAMP = struct.pack('>Q', int(time.time() * 1000))
    MAGIC = b'\x00\xff\xff\x00\xfe\xfe\xfe\xfe\xfd\xfd\xfd\xfd\x12\x34\x56\x78'
    CLIENT_GUID = struct.pack('>Q', 12345)
    packet = UNCONNECTED_PING + TIME_STAMP + MAGIC + CLIENT_GUID

    s = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    s.settimeout(timeout)
    try:
        s.sendto(packet, (host, port))
        data, addr = s.recvfrom(2048)
        offset = 35
        length = struct.unpack('>H', data[offset:offset+2])[0]
        motd = data[offset+2:offset+2+length].decode('utf-8', errors='replace')
        fields = motd.split(';')
        print(f"Host:        {addr[0]}:{addr[1]}")
        print(f"Edition:     {fields[0]}")
        print(f"Server name: {fields[1]}")
        print(f"Version:     {fields[3]}")
        print(f"Players:     {fields[4]}/{fields[5]}")
        print(f"Level name:  {fields[7]}")
        print(f"Game mode:   {fields[8]}")
        print(f"Raw MOTD:    {motd}")
        return True
    except socket.timeout:
        print(f"Timed out connecting to {host}:{port}")
        return False
    except Exception as e:
        print(f"Error: {e}")
        return False
    finally:
        s.close()


if __name__ == "__main__":
    targets = sys.argv[1:] if len(sys.argv) > 1 else ["172.20.100.202", "65.130.147.150"]

    for target in targets:
        host, port = (target.rsplit(":", 1) + ["19132"])[:2]
        print(f"=== {host}:{port} ===")
        ping_bedrock(host, int(port))
        print()
