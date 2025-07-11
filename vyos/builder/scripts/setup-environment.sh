#!/bin/bash
# setup-environment.sh - Initial VyOS Builder Environment Setup
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

echo "=== VyOS Builder Environment Setup ==="

# Check if running as root
if [[ $EUID -eq 0 ]]; then
    echo "❌ Do not run this script as root!"
    exit 1
fi

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Check Docker installation
echo "🔍 Checking Docker installation..."
if ! command_exists docker; then
    echo "❌ Docker is not installed. Please install Docker first."
    echo "   Ubuntu/Debian: sudo apt update && sudo apt install docker.io"
    exit 1
fi

# Check Docker service
if ! systemctl is-active --quiet docker; then
    echo "❌ Docker service is not running. Starting Docker..."
    sudo systemctl start docker
    sudo systemctl enable docker
fi

# Check Docker permissions
if ! docker ps >/dev/null 2>&1; then
    echo "❌ Current user cannot access Docker. Adding to docker group..."
    sudo usermod -aG docker "$USER"
    echo "⚠️  You need to logout and login again for group changes to take effect."
    echo "   After relogging, run this script again."
    exit 1
fi

echo "✅ Docker is properly configured"

# Check Git installation
echo "🔍 Checking Git installation..."
if ! command_exists git; then
    echo "❌ Git is not installed. Please install Git first."
    echo "   Ubuntu/Debian: sudo apt update && sudo apt install git"
    exit 1
fi
echo "✅ Git is available"

# Create .env file if it doesn't exist
if [[ ! -f "$PROJECT_ROOT/.env" ]]; then
    echo "📝 Creating .env file from template..."
    cp "$PROJECT_ROOT/.env.sample" "$PROJECT_ROOT/.env"
    echo "⚠️  Please edit .env file to customize your build settings"
fi

# Create output and logs directories
echo "📁 Creating required directories..."
mkdir -p "$PROJECT_ROOT"/{output/current,logs,packages/custom}

# Clone VyOS build repository if it doesn't exist
if [[ ! -d "$PROJECT_ROOT/vyos-build" ]]; then
    echo "📥 Cloning VyOS build repository..."
    cd "$PROJECT_ROOT"
    git clone -b current --single-branch https://github.com/vyos/vyos-build vyos-build
    echo "✅ VyOS source code cloned"
else
    echo "✅ VyOS source code already exists"
fi

# Pull latest VyOS build container
echo "🐳 Pulling latest VyOS build container..."
docker pull vyos/vyos-build:current

# Make scripts executable
echo "🔧 Setting script permissions..."
chmod +x "$SCRIPT_DIR"/*.sh

echo ""
echo "🎉 Environment setup complete!"
echo ""
echo "Next steps:"
echo "1. Edit .env file to customize build settings"
echo "2. Run './scripts/build-iso.sh' to build your first VyOS ISO"
echo ""
echo "For help: cat CLAUDE.md"