#!/bin/bash

# Cleanup script for Mirth Connect Lab - Dual Instance Setup
echo "🧹 Mirth Connect Lab Cleanup"
echo "This will completely remove all containers, volumes, and data!"
echo ""

# Show what will be removed
echo "The following will be removed:"
echo "📦 Containers:"
echo "  - mirth-connect-a"
echo "  - mirth-connect-b" 
echo "  - mirth-db-a"
echo "  - mirth-db-b"
echo ""
echo "💾 Volumes (all data will be lost):"
echo "  - db_data_a (PostgreSQL data for Instance A)"
echo "  - db_data_b (PostgreSQL data for Instance B)"
echo "  - mirth_data_a (Instance A application data)"
echo "  - mirth_extensions_a (Instance A custom extensions)"
echo "  - mirth_data_b (Instance B application data)"
echo "  - mirth_extensions_b (Instance B custom extensions)"
echo ""

# Confirmation prompt
read -p "⚠️  Are you sure you want to proceed? This cannot be undone! (y/N): " -n 1 -r
echo ""

if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ""
    echo "🛑 Stopping and removing containers..."
    docker-compose down
    
    echo ""
    echo "🗑️  Removing volumes..."
    
    # Remove all volumes defined in docker-compose.yml
    docker volume rm mirth-connect-lab_db_data_a 2>/dev/null || true
    docker volume rm mirth-connect-lab_db_data_b 2>/dev/null || true
    docker volume rm mirth-connect-lab_mirth_data_a 2>/dev/null || true
    docker volume rm mirth-connect-lab_mirth_extensions_a 2>/dev/null || true
    docker volume rm mirth-connect-lab_mirth_data_b 2>/dev/null || true
    docker volume rm mirth-connect-lab_mirth_extensions_b 2>/dev/null || true
    
    echo ""
    echo "🧼 Pruning unused volumes..."
    docker volume prune -f
    
    echo ""
    echo "✅ Cleanup complete!"
    echo "   All containers and volumes have been removed."
    echo "   You can now run './setup.sh' and 'docker-compose up -d' to start fresh."
else
    echo ""
    echo "❌ Cleanup cancelled."
    echo "   No changes were made."
fi