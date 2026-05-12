#!/bin/bash
rm -rf ./MCXboxBroadcastStandalone.jar
wget https://github.com/MCXboxBroadcast/Broadcaster/releases/latest/download/MCXboxBroadcastStandalone.jar
docker compose down
docker compose pull
docker compose up -d --force-recreate --remove-orphans
