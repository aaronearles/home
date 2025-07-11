#!/bin/bash
# build-native.sh - Native VyOS Build (No Docker)
set -eo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Load environment variables
if [[ -f "$PROJECT_ROOT/.env" ]]; then
    set -a
    source "$PROJECT_ROOT/.env"
    set +a
fi

BUILD_BY="${BUILD_BY:-builder@localhost}"
BUILD_ARCHITECTURE="${BUILD_ARCHITECTURE:-amd64}"
BUILD_TYPE="${BUILD_TYPE:-generic}"

echo "🏗️  Native VyOS Build (No Docker)"
echo "=================================="

# Install dependencies
echo "📦 Installing build dependencies..."
sudo apt update
sudo apt install -y live-build git python3-venv

# Build VyOS
echo "🚀 Starting VyOS build..."
cd "$PROJECT_ROOT/vyos-build"

# Clean previous builds
sudo make clean

# Build ISO
sudo ./build-vyos-image \
    --architecture "$BUILD_ARCHITECTURE" \
    --build-by "$BUILD_BY" \
    "$BUILD_TYPE"

echo "✅ Build completed!"
echo "📁 Check vyos-build/build/ for ISO files"