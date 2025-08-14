#!/bin/bash

# OpenIntegrationEngine Lab Cleanup Script
# Stops and removes all containers, volumes, and data

echo "Stopping OpenIntegrationEngine Lab instances..."
docker-compose down

echo "Removing volumes and data..."
docker-compose down -v

echo "Removing any orphaned containers..."
docker container prune -f

echo "Cleanup complete!"
echo ""
echo "To restart fresh instances, run: docker-compose up -d"