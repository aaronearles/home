#!/bin/bash
# run.sh — execute on the Docker LXC host after pulling this repo.
# Prerequisites: Docker Engine, Docker Compose plugin, git, curl
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

echo "==> [1/6] Checking prerequisites..."
docker info --format '{{.ServerVersion}}' || { echo "ERROR: Docker not running"; exit 1; }
docker compose version || { echo "ERROR: Docker Compose plugin not found"; exit 1; }

# ── Detect docker socket GID ──────────────────────────────────────────────────
# Proxmox privileged LXC: no UID/GID remapping — value is the real GID.
DOCKER_GID=$(stat -c '%g' /var/run/docker.sock)
echo "    Docker socket GID: $DOCKER_GID"

# Patch DOCKER_GID placeholder in compose.yaml (sed in-place, backup as .bak)
sed -i.bak "s/\${DOCKER_GID}/${DOCKER_GID}/g" compose.yaml
echo "    compose.yaml patched with GID $DOCKER_GID"

# ── Create .env if it doesn't exist ──────────────────────────────────────────
echo ""
echo "==> [2/6] Setting up .env..."
if [ ! -f .env ]; then
  cp .env.example .env

  # Auto-detect LAN IP for CODER_ACCESS_URL
  HOST_IP=$(ip route get 1.1.1.1 2>/dev/null | awk '{print $7; exit}')
  sed -i "s|CODER_ACCESS_URL=.*|CODER_ACCESS_URL=http://${HOST_IP}:7080|" .env

  # Generate a random Postgres password
  PG_PASS="coder_$(openssl rand -hex 12)"
  sed -i "s|POSTGRES_PASSWORD=.*|POSTGRES_PASSWORD=${PG_PASS}|" .env

  echo "    .env created with auto-detected values."
  echo ""
  echo "    !! Review .env now and set your API key before continuing."
  echo "    Edit .env, then re-run this script."
  echo ""
  cat .env
  exit 0
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
echo "==> [5/6] Logging into Coder at $CODER_ACCESS_URL..."
echo "    If this is the first run, complete the admin account setup in your"
echo "    browser first, then re-run this script from this step:"
echo "    SKIP_START=1 bash run.sh"
echo ""
coder login "$CODER_ACCESS_URL"

# ── Push template ─────────────────────────────────────────────────────────────
echo ""
echo "==> [6/6] Pushing workspace template..."
cd "$SCRIPT_DIR/template"
coder template push claude-workspace \
  --directory . \
  --name "Claude Code (Docker)" \
  --yes

echo ""
echo "==> Done. Visit $CODER_ACCESS_URL to create your first workspace."
echo ""
echo "Post-setup hardening checklist:"
echo "  [ ] Build a custom image with Claude Code pre-baked, then lock down egress"
echo "  [ ] Enable OIDC SSO in compose.yaml (CODER_OIDC_* vars)"
echo "  [ ] Pin ghcr.io/coder/coder:latest to a specific version tag"
