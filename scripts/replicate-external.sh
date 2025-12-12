#!/usr/bin/env bash
# ============================================================================
# replicate-external.sh - External SSD Replication Script (Master -> Replica)
# ============================================================================
#
# Safely replicates data from the master external SSD to the replica SSD.
# This script REFUSES to run if mounts are missing to prevent accidentally
# syncing data into the root filesystem.
#
# Usage:
#   ./scripts/replicate-external.sh             # Full sync with --delete
#   ./scripts/replicate-external.sh --dry-run   # Preview changes
#   ./scripts/replicate-external.sh --no-delete # Sync without deletions
#   ./scripts/replicate-external.sh --exclude "*.tmp"  # Exclude patterns
#
# This script is idempotent and safe to re-run.
#
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Source from environment or use defaults
ORION_EXTERNAL_PRIMARY="${ORION_EXTERNAL_PRIMARY:-/srv/orion/external_primary}"
ORION_EXTERNAL_REPLICA="${ORION_EXTERNAL_REPLICA:-/srv/orion/external_replica}"
ORION_BACKUPS_DIR="${ORION_BACKUPS_DIR:-${ORION_EXTERNAL_PRIMARY}/backups}"

# Log file
LOG_DIR="${ORION_BACKUPS_DIR}/replication"
LOG_FILE="${LOG_DIR}/replica-sync.log"
TIMESTAMP=$(date +%Y-%m-%d_%H:%M:%S)

# Rsync options (use array for proper handling of spaces in patterns)
RSYNC_OPTS=(-aHAX --numeric-ids --info=stats2)
USE_DELETE=true
DRY_RUN=false
EXCLUDES=()

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# ============================================================================
# HELPER FUNCTIONS
# ============================================================================

print_header() {
    echo -e "\n${CYAN}${BOLD}════════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $*${NC}"
    echo -e "${CYAN}${BOLD}════════════════════════════════════════════════════════════════${NC}\n"
}

info() {
    local msg="[INFO] $*"
    echo -e "${BLUE}${msg}${NC}"
    log "$msg"
}

success() {
    local msg="[OK] $*"
    echo -e "${GREEN}${msg}${NC}"
    log "$msg"
}

warn() {
    local msg="[WARN] $*"
    echo -e "${YELLOW}${msg}${NC}"
    log "$msg"
}

err() {
    local msg="[ERR] $*"
    echo -e "${RED}${msg}${NC}"
    log "$msg"
}

fail() {
    err "$*"
    log "[FATAL] Replication aborted"
    exit 1
}

log() {
    if [[ -d "$LOG_DIR" ]]; then
        echo "[$TIMESTAMP] $*" >> "$LOG_FILE"
    fi
}

# Check if a path is a real mount point (not just a directory)
is_mounted() {
    local path="$1"
    findmnt -rn "$path" > /dev/null 2>&1
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --dry-run)
            DRY_RUN=true
            RSYNC_OPTS+=(--dry-run)
            shift
            ;;
        --no-delete)
            USE_DELETE=false
            shift
            ;;
        --exclude)
            if [[ -z "${2:-}" ]]; then
                fail "--exclude requires a pattern argument"
            fi
            EXCLUDES+=("$2")
            shift 2
            ;;
        -h|--help)
            cat << 'EOF'
replicate-external.sh - External SSD Replication (Master -> Replica)

USAGE:
    ./scripts/replicate-external.sh [OPTIONS]

OPTIONS:
    --dry-run          Preview changes without making them
    --no-delete        Don't delete files on replica that don't exist on master
    --exclude PATTERN  Exclude files matching pattern (can be used multiple times)
    -h, --help         Show this help message

ENVIRONMENT VARIABLES:
    ORION_EXTERNAL_PRIMARY  Source directory (default: /srv/orion/external_primary)
    ORION_EXTERNAL_REPLICA  Destination directory (default: /srv/orion/external_replica)
    ORION_BACKUPS_DIR       Backups directory for logs (default: ${ORION_EXTERNAL_PRIMARY}/backups)

SAFETY:
    This script WILL NOT RUN if the source or destination are not real mount points.
    This prevents accidentally syncing into the root filesystem if mounts are missing.

EXAMPLES:
    # Preview what would be synced
    ./scripts/replicate-external.sh --dry-run

    # Full sync (default)
    ./scripts/replicate-external.sh

    # Sync without deleting extra files on replica
    ./scripts/replicate-external.sh --no-delete

    # Exclude certain patterns
    ./scripts/replicate-external.sh --exclude "*.tmp" --exclude "cache/"

For more information, see README.md "Storage & Replication (Dell)" section.
EOF
            exit 0
            ;;
        *)
            fail "Unknown option: $1\nUse --help for usage information."
            ;;
    esac
done

# Add --delete if not disabled
if [[ "$USE_DELETE" == "true" ]]; then
    RSYNC_OPTS+=(--delete)
fi

# Add excludes
for pattern in "${EXCLUDES[@]:-}"; do
    if [[ -n "$pattern" ]]; then
        RSYNC_OPTS+=("--exclude=$pattern")
    fi
done

# ============================================================================
# MAIN SCRIPT
# ============================================================================

print_header "Orion Sentinel - External SSD Replication"

echo "Configuration:"
echo "  Source (Primary):  $ORION_EXTERNAL_PRIMARY"
echo "  Destination (Replica): $ORION_EXTERNAL_REPLICA"
echo "  Log file:          $LOG_FILE"
echo "  Dry run:           $DRY_RUN"
echo "  Delete orphans:    $USE_DELETE"
if [[ ${#EXCLUDES[@]} -gt 0 ]]; then
    echo "  Excludes:          ${EXCLUDES[*]}"
fi
echo ""

# ============================================================================
# STEP 1: Create Log Directory
# ============================================================================

info "Ensuring log directory exists..."
mkdir -p "$LOG_DIR"
success "Log directory ready: $LOG_DIR"

log "=========================================="
log "Starting replication: $ORION_EXTERNAL_PRIMARY -> $ORION_EXTERNAL_REPLICA"
log "Options: ${RSYNC_OPTS[*]}"

# ============================================================================
# STEP 2: Verify Mounts (CRITICAL SAFETY CHECK)
# ============================================================================

print_header "Step 1: Verifying Mount Points (Safety Check)"

MOUNTS_OK=true

if is_mounted "$ORION_EXTERNAL_PRIMARY"; then
    success "Primary mount verified: $ORION_EXTERNAL_PRIMARY"
else
    err "PRIMARY NOT MOUNTED: $ORION_EXTERNAL_PRIMARY"
    MOUNTS_OK=false
fi

if is_mounted "$ORION_EXTERNAL_REPLICA"; then
    success "Replica mount verified: $ORION_EXTERNAL_REPLICA"
else
    err "REPLICA NOT MOUNTED: $ORION_EXTERNAL_REPLICA"
    MOUNTS_OK=false
fi

if [[ "$MOUNTS_OK" != "true" ]]; then
    echo ""
    fail "ABORTING: One or more mount points are not mounted!

This is a SAFETY CHECK to prevent syncing into the root filesystem.
If the mounts are missing, rsync would sync data into empty directories
on the root disk, potentially filling it up.

To fix:
  1. Verify disks are connected
  2. Run: sudo mount -a
  3. Or: sudo ./scripts/bootstrap-storage.sh

To verify mounts:
  findmnt | grep -E 'SMSNG4T|external_primary|external_replica'"
fi

# ============================================================================
# STEP 3: Perform Replication
# ============================================================================

print_header "Step 2: Running Replication"

if [[ "$DRY_RUN" == "true" ]]; then
    warn "DRY RUN MODE - No changes will be made"
    echo ""
fi

info "Starting rsync from $ORION_EXTERNAL_PRIMARY to $ORION_EXTERNAL_REPLICA..."
info "This may take a while depending on data size..."
echo ""

# Run rsync with tee to both stdout and log file
if rsync "${RSYNC_OPTS[@]}" "${ORION_EXTERNAL_PRIMARY}/" "${ORION_EXTERNAL_REPLICA}/" 2>&1 | tee -a "$LOG_FILE"; then
    RSYNC_EXIT=0
else
    RSYNC_EXIT=$?
fi

echo ""

# ============================================================================
# STEP 4: Report Results
# ============================================================================

print_header "Replication Results"

if [[ $RSYNC_EXIT -eq 0 ]]; then
    success "Replication completed successfully!"
    log "Replication completed successfully (exit code 0)"
elif [[ $RSYNC_EXIT -eq 24 ]]; then
    # Exit code 24 means "some files vanished" - usually OK
    warn "Replication completed with warnings (some files vanished during sync)"
    log "Replication completed with warnings (exit code 24 - files vanished)"
else
    err "Replication failed with exit code: $RSYNC_EXIT"
    log "Replication FAILED (exit code $RSYNC_EXIT)"
    exit $RSYNC_EXIT
fi

echo ""
echo "Log file: $LOG_FILE"
echo ""

if [[ "$DRY_RUN" == "true" ]]; then
    warn "This was a DRY RUN - no changes were made"
    info "Run without --dry-run to perform actual sync"
fi

echo ""
echo "Verification commands:"
echo "  # Compare directory sizes:"
echo "  du -sh $ORION_EXTERNAL_PRIMARY $ORION_EXTERNAL_REPLICA"
echo ""
echo "  # View recent log entries:"
echo "  tail -50 $LOG_FILE"
echo ""

success "Done!"
