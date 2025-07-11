#!/bin/bash
# monitor-build.sh - Real-time Build Monitoring Helper
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Usage information
show_usage() {
    echo "Usage: $0 [OPTIONS]"
    echo "Monitor VyOS build progress in real-time"
    echo ""
    echo "Options:"
    echo "  --follow, -f        Follow the latest build log"
    echo "  --summary, -s       Show build summary"
    echo "  --status            Show current build status"
    echo "  --clean-logs        Clean old log files"
    echo "  --help, -h          Show this help"
    echo ""
    echo "Examples:"
    echo "  $0 --follow         # Watch latest build in progress"
    echo "  $0 --summary        # Show recent build results"
    echo "  $0 --status         # Check if build is running"
}

# Get latest build log
get_latest_log() {
    local latest_log
    latest_log=$(find "$PROJECT_ROOT/logs" -name "build-*.log" -type f -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n1 | cut -d' ' -f2-)
    echo "$latest_log"
}

# Check if build is currently running
is_build_running() {
    # Check for VyOS build containers or recent build activity
    local running_containers
    running_containers=$(docker ps -q --filter "ancestor=vyos/vyos-build:current" 2>/dev/null || true)
    
    if [[ -n "$running_containers" ]]; then
        return 0
    fi
    
    # Also check if there's a recent build log that's still being written to
    local latest_log
    latest_log=$(get_latest_log)
    if [[ -n "$latest_log" && -f "$latest_log" ]]; then
        # Check if log file was modified in the last 2 minutes
        local last_modified
        last_modified=$(stat -c %Y "$latest_log" 2>/dev/null || echo 0)
        local current_time
        current_time=$(date +%s)
        local time_diff=$((current_time - last_modified))
        
        if [[ $time_diff -lt 120 ]]; then
            return 0
        fi
    fi
    
    return 1
}

# Show build status
show_status() {
    echo -e "${BLUE}VyOS Build Status${NC}"
    echo "===================="
    
    if is_build_running; then
        echo -e "Status: ${YELLOW}BUILD IN PROGRESS${NC}"
        echo "Running containers:"
        docker ps --filter "ancestor=vyos/vyos-build:current" --format "table {{.ID}}\t{{.Status}}\t{{.Names}}"
    else
        echo -e "Status: ${GREEN}IDLE${NC}"
    fi
    
    echo ""
    echo "Recent builds:"
    if [[ -f "$PROJECT_ROOT/logs/build-summary.log" ]]; then
        tail -5 "$PROJECT_ROOT/logs/build-summary.log" | while read -r line; do
            if [[ "$line" == *"SUCCESS"* ]]; then
                echo -e "${GREEN}✓${NC} $line"
            elif [[ "$line" == *"FAILED"* ]]; then
                echo -e "${RED}✗${NC} $line"
            elif [[ "$line" == *"STARTED"* ]]; then
                echo -e "${YELLOW}▶${NC} $line"
            else
                echo "  $line"
            fi
        done
    else
        echo "No build history found"
    fi
}

# Follow build log
follow_log() {
    local latest_log
    latest_log=$(get_latest_log)
    
    if [[ -z "$latest_log" ]]; then
        echo -e "${RED}No build logs found${NC}"
        echo "Start a build with: ./scripts/build-iso.sh"
        exit 1
    fi
    
    echo -e "${BLUE}Following build log: $latest_log${NC}"
    echo "Press Ctrl+C to stop monitoring"
    echo ""
    
    # Show last few lines first
    tail -10 "$latest_log" 2>/dev/null || true
    echo ""
    echo -e "${YELLOW}--- LIVE OUTPUT ---${NC}"
    
    # Follow the log with colored output
    tail -f "$latest_log" 2>/dev/null | while read -r line; do
        if [[ "$line" == *"ERROR:"* ]]; then
            echo -e "${RED}$line${NC}"
        elif [[ "$line" == *"WARNING:"* ]]; then
            echo -e "${YELLOW}$line${NC}"
        elif [[ "$line" == *"✅"* ]] || [[ "$line" == *"SUCCESS"* ]]; then
            echo -e "${GREEN}$line${NC}"
        elif [[ "$line" == *"PROGRESS:"* ]]; then
            echo -e "${BLUE}$line${NC}"
        else
            echo "$line"
        fi
    done
}

# Show build summary
show_summary() {
    echo -e "${BLUE}Build Summary${NC}"
    echo "=============="
    
    if [[ -f "$PROJECT_ROOT/logs/build-summary.log" ]]; then
        echo "Recent builds:"
        cat "$PROJECT_ROOT/logs/build-summary.log" | tail -10 | while read -r line; do
            if [[ "$line" == *"SUCCESS"* ]]; then
                echo -e "${GREEN}✓${NC} $line"
            elif [[ "$line" == *"FAILED"* ]]; then
                echo -e "${RED}✗${NC} $line"
            elif [[ "$line" == *"STARTED"* ]]; then
                echo -e "${YELLOW}▶${NC} $line"
            else
                echo "  $line"
            fi
        done
    else
        echo "No build summary found"
    fi
    
    echo ""
    echo "Output files:"
    if [[ -d "$PROJECT_ROOT/output/current" ]]; then
        ls -lah "$PROJECT_ROOT/output/current"/*.iso 2>/dev/null | while read -r line; do
            echo -e "${GREEN}  $line${NC}"
        done || echo "No ISO files found"
    else
        echo "No output directory found"
    fi
    
    echo ""
    echo "Disk usage:"
    echo "  Output: $(du -sh "$PROJECT_ROOT/output" 2>/dev/null | cut -f1 || echo "0B")"
    echo "  Logs: $(du -sh "$PROJECT_ROOT/logs" 2>/dev/null | cut -f1 || echo "0B")"
    echo "  VyOS source: $(du -sh "$PROJECT_ROOT/vyos-build" 2>/dev/null | cut -f1 || echo "0B")"
}

# Clean old log files
clean_logs() {
    echo -e "${BLUE}Cleaning old log files${NC}"
    
    local log_count
    log_count=$(find "$PROJECT_ROOT/logs" -name "build-*.log" -type f | wc -l)
    
    if [[ $log_count -gt 10 ]]; then
        echo "Found $log_count log files, keeping latest 10..."
        find "$PROJECT_ROOT/logs" -name "build-*.log" -type f -printf '%T@ %p\n' | sort -n | head -n -10 | cut -d' ' -f2- | xargs rm -f
        echo -e "${GREEN}Old log files cleaned${NC}"
    else
        echo "Only $log_count log files found, no cleanup needed"
    fi
}

# Main execution
main() {
    if [[ $# -eq 0 ]]; then
        show_status
        exit 0
    fi
    
    case "$1" in
        --follow|-f)
            follow_log
            ;;
        --summary|-s)
            show_summary
            ;;
        --status)
            show_status
            ;;
        --clean-logs)
            clean_logs
            ;;
        --help|-h)
            show_usage
            ;;
        *)
            echo "Unknown option: $1"
            show_usage
            exit 1
            ;;
    esac
}

main "$@"