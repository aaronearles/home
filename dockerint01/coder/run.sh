#!/bin/bash
# run.sh — deploy Coder on Docker host with Traefik
# Prerequisites: Docker Engine, Docker Compose plugin, Traefik running
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> [1/6] Checking prerequisites..."
docker info --format '{{.ServerVersion}}' || { echo "ERROR: Docker not running"; exit 1; }
docker compose version || { echo "ERROR: Docker Compose plugin not found"; exit 1; }

# Check if Traefik network exists
if ! docker network inspect traefik &>/dev/null; then
  echo "ERROR: Traefik network not found. Deploy Traefik first:"
  echo "  cd ../traefik && docker compose up -d"
  exit 1
fi

# ── Detect docker socket GID ──────────────────────────────────────────────────
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
echo "    Docker socket GID: $DOCKER_GID"

# ── Create .env if it doesn't exist ──────────────────────────────────────────
echo ""
echo "==> [2/6] Setting up .env..."
if [ ! -f .env ]; then
  cp .env.sample .env

  # Generate a random Postgres password
  PG_PASS="coder_$(openssl rand -hex 12)"
  sed -i "s|POSTGRES_PASSWORD=changeme|POSTGRES_PASSWORD=${PG_PASS}|" .env

  # Update DOCKER_GID
  sed -i "s|DOCKER_GID=.*|DOCKER_GID=${DOCKER_GID}|" .env

  echo "    .env created with auto-generated values."
  echo ""
  echo "    Review the configuration and update if needed:"
  echo "    - CODER_ACCESS_URL: https://coder.internal.earles.io"
  echo "    - Add OIDC settings if using SSO"
  echo ""
  cat .env
  echo ""
  read -p "Press Enter to continue or Ctrl+C to abort and edit .env..."
fi

echo "    .env already exists — using existing values."
source .env

# ── Start Coder ───────────────────────────────────────────────────────────────
echo ""
echo "==> [3/6] Starting Coder..."
docker compose pull
docker compose up -d

echo "    Waiting for coder-db to be healthy..."
timeout 90 bash -c 'until docker inspect coder-db --format "{{.State.Health.Status}}" 2>/dev/null | grep -q healthy; do sleep 3; done'
echo "    coder-db healthy."

timeout 30 bash -c 'until docker inspect coder --format "{{.State.Status}}" 2>/dev/null | grep -q running; do sleep 2; done'
echo "    coder running."

# ── Install Coder CLI ─────────────────────────────────────────────────────────
echo ""
echo "==> [4/6] Installing Coder CLI..."
if ! command -v coder &>/dev/null; then
  curl -fsSL https://coder.com/install.sh | sh
else
  echo "    Coder CLI already installed: $(coder version 2>/dev/null | head -1)"
fi

# ── Login ─────────────────────────────────────────────────────────────────────
echo ""
echo "==> [5/6] Logging into Coder at ${CODER_ACCESS_URL}..."
echo "    If this is the first run, complete the admin account setup in your"
echo "    browser first, then re-run this script."
echo ""
coder login "${CODER_ACCESS_URL}"

# ── Push template ─────────────────────────────────────────────────────────────
echo ""
echo "==> [6/6] Pushing workspace template..."
cd "$SCRIPT_DIR/template"
coder template push claude-workspace \
  --directory . \
  --name "Claude Code (Docker)" \
  --yes

echo ""
echo "==> Done! Access Coder at ${CODER_ACCESS_URL}"
echo ""
echo "Post-setup hardening checklist:"
echo "  [ ] Build custom image with Claude Code pre-baked, then lock down egress"
echo "  [ ] Enable OIDC SSO in .env (CODER_OIDC_* variables)"
echo "  [ ] Pin ghcr.io/coder/coder:latest to a specific version tag"
echo "  [ ] Add Coder to Gatus monitoring"
