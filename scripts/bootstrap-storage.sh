#!/usr/bin/env bash
# ============================================================================
# bootstrap-storage.sh - Dell Storage Bootstrap Script
# ============================================================================
#
# Sets up the standardized Orion storage paths for Dell deployment with
# master/replica external SSDs. This script:
#   1. Verifies external SSDs are mounted
#   2. Creates Orion directory structure on each disk
#   3. Sets up bind mounts to standardized paths
#   4. Optionally installs fstab entries
#
# Physical layout:
#   - /mnt/SMSNG4T1 (master) -> /srv/orion/external_primary
#   - /mnt/SMSNG4T2 (replica) -> /srv/orion/external_replica
#   - /srv/orion/internal (internal disk)
#
# Usage:
#   ./scripts/bootstrap-storage.sh              # Create dirs and mount
#   ./scripts/bootstrap-storage.sh --install-fstab  # Also add to fstab
#   ./scripts/bootstrap-storage.sh --no-mount   # Only create dirs, no mounts
#
# This script is idempotent and safe to re-run.
#
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Physical mount points (where SSDs are mounted)
MASTER_MOUNT="/mnt/SMSNG4T1"
REPLICA_MOUNT="/mnt/SMSNG4T2"

# Standardized Orion paths (bind mount targets)
ORION_INTERNAL_ROOT="${ORION_INTERNAL_ROOT:-/srv/orion/internal}"
ORION_EXTERNAL_PRIMARY="${ORION_EXTERNAL_PRIMARY:-/srv/orion/external_primary}"
ORION_EXTERNAL_REPLICA="${ORION_EXTERNAL_REPLICA:-/srv/orion/external_replica}"

# Derived paths
ORION_MEDIA_DIR="${ORION_MEDIA_DIR:-${ORION_EXTERNAL_PRIMARY}/media}"
ORION_CAMERAS_DIR="${ORION_CAMERAS_DIR:-${ORION_EXTERNAL_PRIMARY}/cameras}"
ORION_BACKUPS_DIR="${ORION_BACKUPS_DIR:-${ORION_EXTERNAL_PRIMARY}/backups}"

# Ownership (default to current user or specified)
ORION_UID="${ORION_UID:-$(id -u)}"
ORION_GID="${ORION_GID:-$(id -g)}"

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
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

err() {
    echo -e "${RED}[ERR]${NC} $*"
}

fail() {
    err "$*"
    exit 1
}

# Check if a path is a real mount point (not just a directory)
is_mounted() {
    local path="$1"
    findmnt -rn "$path" > /dev/null 2>&1
}

# Check if running as root
require_root() {
    if [[ $EUID -ne 0 ]]; then
        fail "This operation requires root privileges. Run with sudo."
    fi
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

INSTALL_FSTAB=false
NO_MOUNT=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --install-fstab)
            INSTALL_FSTAB=true
            shift
            ;;
        --no-mount)
            NO_MOUNT=true
            shift
            ;;
        -h|--help)
            cat << 'EOF'
bootstrap-storage.sh - Dell Storage Bootstrap Script

USAGE:
    ./scripts/bootstrap-storage.sh [OPTIONS]

OPTIONS:
    --install-fstab    Add bind mounts to /etc/fstab (idempotent)
    --no-mount         Only create directories, don't perform mounts
    -h, --help         Show this help message

ENVIRONMENT VARIABLES:
    ORION_INTERNAL_ROOT     Internal disk root (default: /srv/orion/internal)
    ORION_EXTERNAL_PRIMARY  External primary root (default: /srv/orion/external_primary)
    ORION_EXTERNAL_REPLICA  External replica root (default: /srv/orion/external_replica)
    ORION_UID               Owner UID for directories (default: current user)
    ORION_GID               Owner GID for directories (default: current group)

EXAMPLES:
    # Set up storage with default options
    sudo ./scripts/bootstrap-storage.sh

    # Set up and add to fstab for persistence
    sudo ./scripts/bootstrap-storage.sh --install-fstab

    # Only create directories (for testing)
    ./scripts/bootstrap-storage.sh --no-mount

For more information, see README.md "Storage & Replication (Dell)" section.
EOF
            exit 0
            ;;
        *)
            fail "Unknown option: $1\nUse --help for usage information."
            ;;
    esac
done

# ============================================================================
# MAIN SCRIPT
# ============================================================================

print_header "Orion Sentinel - Dell Storage Bootstrap"

echo "Configuration:"
echo "  Master mount:     $MASTER_MOUNT"
echo "  Replica mount:    $REPLICA_MOUNT"
echo "  Internal root:    $ORION_INTERNAL_ROOT"
echo "  External primary: $ORION_EXTERNAL_PRIMARY"
echo "  External replica: $ORION_EXTERNAL_REPLICA"
echo "  Owner UID/GID:    $ORION_UID:$ORION_GID"
echo ""

# ============================================================================
# STEP 1: Verify External SSDs are Mounted
# ============================================================================

print_header "Step 1: Verifying External SSD Mounts"

MOUNTS_OK=true

if is_mounted "$MASTER_MOUNT"; then
    success "Master SSD mounted at $MASTER_MOUNT"
else
    err "Master SSD NOT mounted at $MASTER_MOUNT"
    MOUNTS_OK=false
fi

if is_mounted "$REPLICA_MOUNT"; then
    success "Replica SSD mounted at $REPLICA_MOUNT"
else
    err "Replica SSD NOT mounted at $REPLICA_MOUNT"
    MOUNTS_OK=false
fi

if [[ "$MOUNTS_OK" != "true" ]]; then
    echo ""
    err "External SSDs are not properly mounted!"
    echo ""
    echo "To fix this, ensure your SSDs are mounted in /etc/fstab:"
    echo ""
    echo "  # Find your disk UUIDs:"
    echo "  sudo blkid"
    echo ""
    echo "  # Add to /etc/fstab (example):"
    echo "  UUID=<master-uuid>  /mnt/SMSNG4T1  ext4  defaults,nofail  0  2"
    echo "  UUID=<replica-uuid> /mnt/SMSNG4T2  ext4  defaults,nofail  0  2"
    echo ""
    echo "  # Then mount:"
    echo "  sudo mount -a"
    echo ""
    exit 1
fi

# ============================================================================
# STEP 2: Create Orion Roots on Each Disk
# ============================================================================

print_header "Step 2: Creating Orion Roots on Each Disk"

if [[ "$NO_MOUNT" != "true" ]]; then
    require_root
fi

# Create orion subdirectory on each physical disk
info "Creating $MASTER_MOUNT/orion..."
mkdir -p "$MASTER_MOUNT/orion"
success "Created $MASTER_MOUNT/orion"

info "Creating $REPLICA_MOUNT/orion..."
mkdir -p "$REPLICA_MOUNT/orion"
success "Created $REPLICA_MOUNT/orion"

# ============================================================================
# STEP 3: Create Standardized Mount Points
# ============================================================================

print_header "Step 3: Creating Standardized Mount Points"

info "Creating mount point: $ORION_INTERNAL_ROOT"
mkdir -p "$ORION_INTERNAL_ROOT"
success "Created $ORION_INTERNAL_ROOT"

info "Creating mount point: $ORION_EXTERNAL_PRIMARY"
mkdir -p "$ORION_EXTERNAL_PRIMARY"
success "Created $ORION_EXTERNAL_PRIMARY"

info "Creating mount point: $ORION_EXTERNAL_REPLICA"
mkdir -p "$ORION_EXTERNAL_REPLICA"
success "Created $ORION_EXTERNAL_REPLICA"

# ============================================================================
# STEP 4: Perform Bind Mounts (unless --no-mount)
# ============================================================================

if [[ "$NO_MOUNT" != "true" ]]; then
    print_header "Step 4: Setting Up Bind Mounts"
    
    require_root
    
    # Mount external_primary -> master SSD
    if is_mounted "$ORION_EXTERNAL_PRIMARY"; then
        success "$ORION_EXTERNAL_PRIMARY is already mounted"
    else
        info "Bind mounting $MASTER_MOUNT/orion -> $ORION_EXTERNAL_PRIMARY"
        mount --bind "$MASTER_MOUNT/orion" "$ORION_EXTERNAL_PRIMARY"
        success "Mounted $ORION_EXTERNAL_PRIMARY"
    fi
    
    # Mount external_replica -> replica SSD
    if is_mounted "$ORION_EXTERNAL_REPLICA"; then
        success "$ORION_EXTERNAL_REPLICA is already mounted"
    else
        info "Bind mounting $REPLICA_MOUNT/orion -> $ORION_EXTERNAL_REPLICA"
        mount --bind "$REPLICA_MOUNT/orion" "$ORION_EXTERNAL_REPLICA"
        success "Mounted $ORION_EXTERNAL_REPLICA"
    fi
else
    print_header "Step 4: Skipping Bind Mounts (--no-mount)"
    warn "Bind mounts were skipped. To mount manually:"
    echo ""
    echo "  sudo mount --bind $MASTER_MOUNT/orion $ORION_EXTERNAL_PRIMARY"
    echo "  sudo mount --bind $REPLICA_MOUNT/orion $ORION_EXTERNAL_REPLICA"
    echo ""
fi

# ============================================================================
# STEP 5: Install fstab Entries (if --install-fstab)
# ============================================================================

if [[ "$INSTALL_FSTAB" == "true" ]]; then
    print_header "Step 5: Installing fstab Entries"
    
    require_root
    
    FSTAB_ENTRY_PRIMARY="$MASTER_MOUNT/orion $ORION_EXTERNAL_PRIMARY none bind 0 0"
    FSTAB_ENTRY_REPLICA="$REPLICA_MOUNT/orion $ORION_EXTERNAL_REPLICA none bind 0 0"
    
    # Check and add primary entry
    if grep -qF "$ORION_EXTERNAL_PRIMARY" /etc/fstab; then
        success "fstab entry for $ORION_EXTERNAL_PRIMARY already exists"
    else
        info "Adding fstab entry for $ORION_EXTERNAL_PRIMARY"
        echo "$FSTAB_ENTRY_PRIMARY" >> /etc/fstab
        success "Added fstab entry"
    fi
    
    # Check and add replica entry
    if grep -qF "$ORION_EXTERNAL_REPLICA" /etc/fstab; then
        success "fstab entry for $ORION_EXTERNAL_REPLICA already exists"
    else
        info "Adding fstab entry for $ORION_EXTERNAL_REPLICA"
        echo "$FSTAB_ENTRY_REPLICA" >> /etc/fstab
        success "Added fstab entry"
    fi
    
    echo ""
    info "fstab entries added:"
    echo "  $FSTAB_ENTRY_PRIMARY"
    echo "  $FSTAB_ENTRY_REPLICA"
else
    print_header "Step 5: fstab Installation Skipped"
    info "To persist mounts across reboots, run with --install-fstab"
    info "Or manually add these lines to /etc/fstab:"
    echo ""
    echo "  $MASTER_MOUNT/orion $ORION_EXTERNAL_PRIMARY none bind 0 0"
    echo "  $REPLICA_MOUNT/orion $ORION_EXTERNAL_REPLICA none bind 0 0"
    echo ""
fi

# ============================================================================
# STEP 6: Create Directory Structure
# ============================================================================

print_header "Step 6: Creating Directory Structure"

# Internal directories (configs, app state, databases)
info "Creating internal directories..."
mkdir -p "${ORION_INTERNAL_ROOT}/appdata"
mkdir -p "${ORION_INTERNAL_ROOT}/db"
mkdir -p "${ORION_INTERNAL_ROOT}/observability"
mkdir -p "${ORION_INTERNAL_ROOT}/config-snapshots"
success "Created internal directories"

# External primary directories (media, cameras, backups)
info "Creating external primary directories..."
mkdir -p "${ORION_EXTERNAL_PRIMARY}/media"
mkdir -p "${ORION_EXTERNAL_PRIMARY}/cameras"
mkdir -p "${ORION_EXTERNAL_PRIMARY}/backups"
mkdir -p "${ORION_EXTERNAL_PRIMARY}/internal-mirror"
mkdir -p "${ORION_BACKUPS_DIR}/db"
mkdir -p "${ORION_BACKUPS_DIR}/replication"
success "Created external primary directories"

# External replica directories (mirror structure)
info "Creating external replica directories..."
mkdir -p "${ORION_EXTERNAL_REPLICA}/media"
mkdir -p "${ORION_EXTERNAL_REPLICA}/cameras"
mkdir -p "${ORION_EXTERNAL_REPLICA}/backups"
mkdir -p "${ORION_EXTERNAL_REPLICA}/internal-mirror"
success "Created external replica directories"

# ============================================================================
# STEP 7: Set Ownership
# ============================================================================

print_header "Step 7: Setting Ownership"

info "Setting ownership to $ORION_UID:$ORION_GID..."

# Set ownership on all created directories (may need root for external mounts)
chown -R "$ORION_UID:$ORION_GID" "$ORION_INTERNAL_ROOT" 2>/dev/null || warn "Could not set ownership on internal root (may need root)"
chown -R "$ORION_UID:$ORION_GID" "$ORION_EXTERNAL_PRIMARY" 2>/dev/null || warn "Could not set ownership on external_primary (may need root)"
chown -R "$ORION_UID:$ORION_GID" "$ORION_EXTERNAL_REPLICA" 2>/dev/null || warn "Could not set ownership on external_replica (may need root)"

success "Ownership set"

# ============================================================================
# STEP 8: Summary
# ============================================================================

print_header "Bootstrap Complete!"

echo "Storage Layout:"
echo ""
echo "  Internal Disk:"
echo "    ${ORION_INTERNAL_ROOT}/"
echo "    ├── appdata/           # Service configurations"
echo "    ├── db/                # Database files"
echo "    ├── observability/     # Monitoring data"
echo "    └── config-snapshots/  # Config backups"
echo ""
echo "  External Primary (Master SSD - $MASTER_MOUNT):"
echo "    ${ORION_EXTERNAL_PRIMARY}/"
echo "    ├── media/             # Media streaming data"
echo "    ├── cameras/           # Camera recordings"
echo "    ├── backups/           # Backup archives"
echo "    │   ├── db/            # Database dumps"
echo "    │   └── replication/   # Replication logs"
echo "    └── internal-mirror/   # Mirror of internal data"
echo ""
echo "  External Replica (Mirror SSD - $REPLICA_MOUNT):"
echo "    ${ORION_EXTERNAL_REPLICA}/"
echo "    └── (mirror of primary)"
echo ""

if [[ "$NO_MOUNT" != "true" ]]; then
    echo "Current Mount Status:"
    echo ""
    findmnt | grep -E "(SMSNG4T|external_primary|external_replica|orion)" || true
    echo ""
fi

echo "Verification Commands:"
echo ""
echo "  # Check mounts:"
echo "  findmnt | grep -E 'SMSNG4T|external_primary|external_replica'"
echo ""
echo "  # Check disk usage:"
echo "  df -h $ORION_EXTERNAL_PRIMARY $ORION_EXTERNAL_REPLICA"
echo ""
echo "  # List directory structure:"
echo "  tree -L 2 $ORION_INTERNAL_ROOT $ORION_EXTERNAL_PRIMARY"
echo ""

if [[ "$INSTALL_FSTAB" == "true" ]]; then
    success "fstab entries installed - mounts will persist across reboots"
else
    warn "fstab entries NOT installed - run with --install-fstab to persist"
fi

echo ""
echo "Next Steps:"
echo "  1. Copy .env.example to .env and configure"
echo "  2. Run replication: ./scripts/replicate-external.sh --dry-run"
echo "  3. Install systemd timer: sudo ./scripts/install-systemd.sh"
echo ""

success "Bootstrap completed successfully!"
