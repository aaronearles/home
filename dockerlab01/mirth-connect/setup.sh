#!/bin/bash

# Create required directories for Mirth Connect
echo "Creating Mirth Connect data directories..."

mkdir -p data
mkdir -p extensions

# Set proper permissions - make directories writable by all users
# This is needed because the Mirth Connect container runs as a specific user ID
chmod 777 data
chmod 777 extensions

echo "Directories created successfully:"
echo "  ./data - for Mirth Connect application data (permissions: 777)"
echo "  ./extensions - for custom extensions (permissions: 777)"
echo ""
echo "Note: Wide permissions are required for Docker volume mounts"
echo "You can now run: docker-compose up -d"