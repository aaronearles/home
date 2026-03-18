#!/bin/bash
# =============================================================================
# reset_drive_health.sh
# Clears false "Critical" drive health status on Synology DSM 7.x after a
# power failure or I/O event where drives have been confirmed healthy by
# extended S.M.A.R.T. tests.
#
# Tested on: DSM 7.1.1 (build 42962), DS215j
# Usage: sudo bash reset_drive_health.sh [SERIAL1] [SERIAL2] ...
#   e.g. sudo bash reset_drive_health.sh WD-WX11D35C8H1R WD-WX41D25L1SVV
#
# If no serials are provided, the script will list all drives currently in
# the error log and prompt you to confirm which to clear.
# =============================================================================

set -euo pipefail

DISKDB="/var/log/synolog/.SYNODISKDB"
OVERVIEW_XML="/var/log/disk_overview.xml"
BACKUP_SUFFIX=".bak.$(date +%Y%m%d_%H%M%S)"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Error message types that contribute to health weight calculation
ERROR_MSGS="'unc','timeout','other_kernel_err','timeout_notify','unc_notify','status_critical'"

# =============================================================================
# Helpers
# =============================================================================

log()    { echo -e "${GREEN}[+]${NC} $*"; }
warn()   { echo -e "${YELLOW}[!]${NC} $*"; }
error()  { echo -e "${RED}[!]${NC} $*"; exit 1; }

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root. Use: sudo bash $0"
    fi
}

check_deps() {
    if ! command -v sqlite3 &>/dev/null; then
        error "sqlite3 not found. This script requires sqlite3."
    fi
}

check_smart() {
    warn "========================================================"
    warn "  IMPORTANT: Have you run extended S.M.A.R.T. tests"
    warn "  on all affected drives and confirmed they are healthy?"
    warn "  This script removes real error records. Only proceed"
    warn "  if drives are confirmed healthy."
    warn "========================================================"
    echo ""
    read -rp "Confirm drives have passed extended S.M.A.R.T. (yes/no): " confirm
    if [[ "$confirm" != "yes" ]]; then
        echo "Aborted. Run extended S.M.A.R.T. tests first."
        exit 0
    fi
}

list_affected_drives() {
    echo ""
    log "Drives with error events in the log:"
    sqlite3 "$DISKDB" "
        SELECT serial, model, COUNT(*) as events
        FROM logs
        WHERE msg IN ($ERROR_MSGS)
        GROUP BY serial, model
        ORDER BY serial;
    " | column -t -s '|'
    echo ""
}

get_serials_from_user() {
    list_affected_drives
    read -rp "Enter serial numbers to clear (space-separated): " -a SERIALS
    if [[ ${#SERIALS[@]} -eq 0 ]]; then
        error "No serial numbers provided. Aborting."
    fi
}

build_serial_clause() {
    local serials=("$@")
    local clause=""
    for serial in "${serials[@]}"; do
        [[ -n "$clause" ]] && clause+=","
        clause+="'${serial}'"
    done
    echo "($clause)"
}

show_current_weights() {
    local label="$1"
    echo ""
    log "$label runtime weights:"
    for dev in /run/synostorage/disks/*/; do
        local name
        name=$(basename "$dev")
        local unc_w timeout_w unc_s timeout_s
        unc_w=$(cat "${dev}unc_weight" 2>/dev/null || echo "n/a")
        timeout_w=$(cat "${dev}timeout_weight" 2>/dev/null || echo "n/a")
        unc_s=$(cat "${dev}unc_status" 2>/dev/null || echo "n/a")
        timeout_s=$(cat "${dev}timeout_status" 2>/dev/null || echo "n/a")
        printf "  %-6s  unc_weight=%-4s unc_status=%-8s timeout_weight=%-4s timeout_status=%s\n" \
            "$name" "$unc_w" "$unc_s" "$timeout_w" "$timeout_s"
    done
    echo ""
}

# =============================================================================
# Main
# =============================================================================

check_root
check_deps
check_smart

echo ""
log "Synology Drive Health Status Reset"
log "==================================="

# Determine which serials to process
SERIALS=("$@")
if [[ ${#SERIALS[@]} -eq 0 ]]; then
    get_serials_from_user
fi

SERIAL_CLAUSE=$(build_serial_clause "${SERIALS[@]}")
log "Processing serials: ${SERIALS[*]}"

# Show pre-fix state
show_current_weights "BEFORE"

# Preview what will be deleted
echo ""
log "Error events to be removed:"
sqlite3 "$DISKDB" "
    SELECT msg, serial, COUNT(*) as count
    FROM logs
    WHERE msg IN ($ERROR_MSGS)
    AND serial IN $SERIAL_CLAUSE
    GROUP BY msg, serial
    ORDER BY serial, msg;
" | column -t -s '|'
echo ""

TOTAL=$(sqlite3 "$DISKDB" "
    SELECT COUNT(*) FROM logs
    WHERE msg IN ($ERROR_MSGS)
    AND serial IN $SERIAL_CLAUSE;
")

if [[ "$TOTAL" -eq 0 ]]; then
    warn "No matching error events found for the specified serials."
    warn "Drives may already be clear, or serials may be incorrect."
    exit 0
fi

read -rp "Proceed with removing $TOTAL error event(s)? (yes/no): " confirm
if [[ "$confirm" != "yes" ]]; then
    echo "Aborted."
    exit 0
fi

# Backup database
log "Backing up $DISKDB..."
cp "$DISKDB" "${DISKDB}${BACKUP_SUFFIX}"
log "Backup saved to ${DISKDB}${BACKUP_SUFFIX}"

# Delete error events
log "Removing error events from database..."
sqlite3 "$DISKDB" "
    DELETE FROM logs
    WHERE msg IN ($ERROR_MSGS)
    AND serial IN $SERIAL_CLAUSE;
"

# Checkpoint WAL
log "Checkpointing WAL..."
sqlite3 "$DISKDB" "PRAGMA wal_checkpoint(TRUNCATE);" > /dev/null

# Verify deletion
REMAINING=$(sqlite3 "$DISKDB" "
    SELECT COUNT(*) FROM logs
    WHERE msg IN ($ERROR_MSGS)
    AND serial IN $SERIAL_CLAUSE;
")
log "Remaining error events for specified drives: $REMAINING"

# Zero overview XML
if [[ -f "$OVERVIEW_XML" ]]; then
    log "Zeroing error counts in $OVERVIEW_XML..."
    cp "$OVERVIEW_XML" "${OVERVIEW_XML}${BACKUP_SUFFIX}"
    # Only zero the top-level unc/timeout counts, not the history entries
    # History entries are in a comma-separated format so this pattern is safe
    sed -i 's|<unc>[0-9]*</unc>|<unc>0</unc>|g' "$OVERVIEW_XML"
    sed -i 's|<timeout>[0-9]*</timeout>|<timeout>0</timeout>|g' "$OVERVIEW_XML"
    log "Overview XML zeroed. Backup saved to ${OVERVIEW_XML}${BACKUP_SUFFIX}"
else
    warn "$OVERVIEW_XML not found, skipping."
fi

# Restart daemon
log "Restarting synostoraged..."
systemctl restart synostoraged.service
log "Waiting for daemon to initialize..."
sleep 15

# Show post-fix state
show_current_weights "AFTER"

# Final check
ALL_NORMAL=true
for dev in /run/synostorage/disks/*/; do
    unc_w=$(cat "${dev}unc_weight" 2>/dev/null || echo "0")
    timeout_w=$(cat "${dev}timeout_weight" 2>/dev/null || echo "0")
    if [[ "$unc_w" != "0" ]] || [[ "$timeout_w" != "0" ]]; then
        ALL_NORMAL=false
    fi
done

echo ""
if $ALL_NORMAL; then
    log "✓ All drive weights are 0. Check Storage Manager — drives should now show Normal."
    log "  Reboot the NAS to confirm the fix is persistent."
else
    warn "Some weights are still non-zero. Additional error events may remain in the log."
    warn "Run the following to check:"
    warn "  sudo sqlite3 $DISKDB \"SELECT msg, level, COUNT(*) FROM logs WHERE serial IN $SERIAL_CLAUSE GROUP BY msg, level;\""
fi

echo ""
log "Done."