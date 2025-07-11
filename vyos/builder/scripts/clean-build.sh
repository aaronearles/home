#!/bin/bash
# clean-build.sh - Clean VyOS Build Artifacts
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Parse command line arguments
FULL_CLEAN=false
CONFIRM=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --full)
            FULL_CLEAN=true
            shift
            ;;
        --yes|-y)
            CONFIRM=true
            shift
            ;;
        -h|--help)
            echo "Usage: $0 [OPTIONS]"
            echo "Clean VyOS build artifacts and temporary files"
            echo ""
            echo "Options:"
            echo "  --full              Full clean including source directory"
            echo "  --yes, -y           Skip confirmation prompts"
            echo "  -h, --help          Show this help"
            echo ""
            echo "Default: Clean build artifacts and output files only"
            echo "Full clean: Also reset VyOS source and clean Docker"
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            echo "Use --help for usage information"
            exit 1
            ;;
    esac
done

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# Confirmation function
confirm() {
    if [[ "$CONFIRM" == "true" ]]; then
        return 0
    fi
    
    echo -n "$1 (y/N): "
    read -r response
    case "$response" in
        [yY][eE][sS]|[yY])
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

# Clean output directory
clean_output() {
    if [[ -d "$PROJECT_ROOT/output" ]] && [[ -n "$(ls -A "$PROJECT_ROOT/output" 2>/dev/null)" ]]; then
        if confirm "Clean output directory ($PROJECT_ROOT/output)?"; then
            log "🧹 Cleaning output directory..."
            rm -rf "$PROJECT_ROOT/output"/*
            log "✅ Output directory cleaned"
        fi
    else
        log "✅ Output directory is already clean"
    fi
}

# Clean logs
clean_logs() {
    if [[ -d "$PROJECT_ROOT/logs" ]] && [[ -n "$(ls -A "$PROJECT_ROOT/logs" 2>/dev/null)" ]]; then
        if confirm "Clean log files ($PROJECT_ROOT/logs)?"; then
            log "🧹 Cleaning log files..."
            rm -f "$PROJECT_ROOT/logs"/*.log
            log "✅ Log files cleaned"
        fi
    else
        log "✅ No log files to clean"
    fi
}

# Clean VyOS build artifacts
clean_vyos_build() {
    if [[ -d "$PROJECT_ROOT/vyos-build/build" ]]; then
        if confirm "Clean VyOS build artifacts?"; then
            log "🧹 Cleaning VyOS build artifacts..."
            cd "$PROJECT_ROOT/vyos-build"
            sudo rm -rf build/
            log "✅ VyOS build artifacts cleaned"
        fi
    else
        log "✅ No VyOS build artifacts to clean"
    fi
}

# Full clean: Reset VyOS source
reset_vyos_source() {
    if [[ -d "$PROJECT_ROOT/vyos-build" ]]; then
        if confirm "Reset VyOS source code to clean state?"; then
            log "🧹 Resetting VyOS source code..."
            cd "$PROJECT_ROOT/vyos-build"
            git clean -fdx
            git reset --hard origin/current
            log "✅ VyOS source code reset"
        fi
    else
        log "⚠️  VyOS source directory not found"
    fi
}

# Clean Docker artifacts
clean_docker() {
    if command -v docker >/dev/null 2>&1; then
        if confirm "Clean Docker containers and unused images?"; then
            log "🧹 Cleaning Docker artifacts..."
            
            # Remove stopped containers
            if docker container ls -aq --filter "status=exited" | grep -q .; then
                docker container prune -f
                log "✅ Stopped containers removed"
            fi
            
            # Remove unused images
            if docker image ls -q --filter "dangling=true" | grep -q .; then
                docker image prune -f
                log "✅ Unused images removed"
            fi
            
            # Clean build cache
            docker builder prune -f >/dev/null 2>&1 || true
            
            log "✅ Docker cleanup completed"
        fi
    else
        log "⚠️  Docker not available for cleanup"
    fi
}

# Check disk usage
check_disk_usage() {
    log "💾 Disk usage information:"
    if [[ -d "$PROJECT_ROOT/output" ]]; then
        local output_size
        output_size=$(du -sh "$PROJECT_ROOT/output" 2>/dev/null | cut -f1)
        echo "   Output directory: $output_size"
    fi
    
    if [[ -d "$PROJECT_ROOT/logs" ]]; then
        local logs_size
        logs_size=$(du -sh "$PROJECT_ROOT/logs" 2>/dev/null | cut -f1)
        echo "   Log files: $logs_size"
    fi
    
    if [[ -d "$PROJECT_ROOT/vyos-build" ]]; then
        local vyos_size
        vyos_size=$(du -sh "$PROJECT_ROOT/vyos-build" 2>/dev/null | cut -f1)
        echo "   VyOS source: $vyos_size"
    fi
    
    if command -v docker >/dev/null 2>&1; then
        echo "   Docker system:"
        docker system df 2>/dev/null | grep -E "(TYPE|Images|Containers|Build Cache)" || true
    fi
}

# Main execution
main() {
    log "🎯 VyOS Builder Cleanup Started"
    
    if [[ "$FULL_CLEAN" == "true" ]]; then
        log "🔥 Full cleanup mode enabled"
    else
        log "🧹 Standard cleanup mode"
    fi
    
    echo ""
    check_disk_usage
    echo ""
    
    # Standard cleanup
    clean_output
    clean_logs
    clean_vyos_build
    
    # Full cleanup additional steps
    if [[ "$FULL_CLEAN" == "true" ]]; then
        reset_vyos_source
        clean_docker
    fi
    
    echo ""
    log "🎉 Cleanup completed!"
    echo ""
    check_disk_usage
}

# Run main function
main "$@"