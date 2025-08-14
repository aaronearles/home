#!/bin/bash

# OpenIntegrationEngine Setup Script
# Sets up directories and initializes the service

echo "Setting up OpenIntegrationEngine..."

# Create data directories
mkdir -p data
mkdir -p extensions

# Set proper permissions
chmod 755 data
chmod 755 extensions

echo "Creating Docker networks if they don't exist..."
docker network create traefik 2>/dev/null || true

echo "Starting OpenIntegrationEngine..."
docker-compose up -d

echo "OpenIntegrationEngine is starting up..."
echo "Web interface will be available at: https://openintegration.lab.earles.io"
echo "Default credentials: admin/admin"
echo ""
echo "Check logs with: docker-compose logs -f"