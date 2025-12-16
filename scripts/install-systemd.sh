#!/usr/bin/env bash
# ============================================================================
# install-systemd.sh - Install Orion Sentinel Systemd Units
# ============================================================================
#
# Installs the systemd service and timer units for automatic maintenance tasks:
#   - External SSD replication (nightly)
#   - Daily/weekly config backups
#   - Frigate recording backup & retention
#
# Usage:
#   sudo ./scripts/install-systemd.sh [--all|--replica|--backup|--frigate]
#
# Options:
#   --all      Install all systemd units (default)
#   --replica  Install only replica sync timer
#   --backup   Install only backup timers (daily/weekly)
#   --frigate  Install only Frigate backup timer
#
# This script requires root privileges.
#
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Determine script location and repo root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Systemd unit paths
SYSTEMD_DIR="/etc/systemd/system"

# Default installation path for repo
INSTALL_PATH="/opt/orion/Orion-Sentinel-CoreSrv"

# What to install (default: all)
INSTALL_REPLICA=false
INSTALL_BACKUP=false
INSTALL_FRIGATE=false
INSTALL_ALL=true

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

usage() {
    echo "Usage: $0 [--all|--replica|--backup|--frigate]"
    echo ""
    echo "Options:"
    echo "  --all      Install all systemd units (default)"
    echo "  --replica  Install only replica sync timer"
    echo "  --backup   Install only backup timers (daily/weekly)"
    echo "  --frigate  Install only Frigate backup timer"
    echo ""
    exit 1
}

install_unit() {
    local service_file="$1"
    local timer_file="$2"
    local description="$3"
    
    if [[ ! -f "$REPO_ROOT/systemd/$service_file" ]]; then
        warn "Service file not found: $REPO_ROOT/systemd/$service_file - skipping"
        return 1
    fi
    
    if [[ ! -f "$REPO_ROOT/systemd/$timer_file" ]]; then
        warn "Timer file not found: $REPO_ROOT/systemd/$timer_file - skipping"
        return 1
    fi
    
    info "Installing $description..."
    
    # Copy service file
    cp "$REPO_ROOT/systemd/$service_file" "$SYSTEMD_DIR/$service_file"
    success "Installed $SYSTEMD_DIR/$service_file"
    
    # Copy timer file
    cp "$REPO_ROOT/systemd/$timer_file" "$SYSTEMD_DIR/$timer_file"
    success "Installed $SYSTEMD_DIR/$timer_file"
    
    return 0
}

enable_timer() {
    local timer_file="$1"
    
    info "Enabling $timer_file..."
    systemctl enable "$timer_file"
    success "Timer enabled"
    
    info "Starting $timer_file..."
    systemctl start "$timer_file"
    success "Timer started"
}

# ============================================================================
# PARSE ARGUMENTS
# ============================================================================

while [[ $# -gt 0 ]]; do
    case "$1" in
        --all)
            INSTALL_ALL=true
            INSTALL_REPLICA=true
            INSTALL_BACKUP=true
            INSTALL_FRIGATE=true
            shift
            ;;
        --replica)
            INSTALL_ALL=false
            INSTALL_REPLICA=true
            shift
            ;;
        --backup)
            INSTALL_ALL=false
            INSTALL_BACKUP=true
            shift
            ;;
        --frigate)
            INSTALL_ALL=false
            INSTALL_FRIGATE=true
            shift
            ;;
        -h|--help)
            usage
            ;;
        *)
            err "Unknown option: $1"
            usage
            ;;
    esac
done

# If --all or no options, install everything
if $INSTALL_ALL; then
    INSTALL_REPLICA=true
    INSTALL_BACKUP=true
    INSTALL_FRIGATE=true
fi

# ============================================================================
# CHECKS
# ============================================================================

# Check for root
if [[ $EUID -ne 0 ]]; then
    fail "This script requires root privileges. Run with sudo."
fi

# Check for systemctl
if ! command -v systemctl &> /dev/null; then
    fail "systemctl not found. This script requires systemd."
fi

# ============================================================================
# MAIN SCRIPT
# ============================================================================

print_header "Installing Orion Sentinel Systemd Units"

echo "Configuration:"
echo "  Repository root: $REPO_ROOT"
echo "  Install path:    $INSTALL_PATH"
echo "  Systemd dir:     $SYSTEMD_DIR"
echo ""
echo "Units to install:"
$INSTALL_REPLICA && echo "  - Replica sync (nightly at 02:30)"
$INSTALL_BACKUP && echo "  - Daily backup (03:00)"
$INSTALL_BACKUP && echo "  - Weekly backup (Sundays 04:00)"
$INSTALL_FRIGATE && echo "  - Frigate backup (03:30)"
echo ""

# ============================================================================
# STEP 1: Symlink or Copy Repository (if needed)
# ============================================================================

print_header "Step 1: Setting Up Repository Path"

if [[ "$REPO_ROOT" != "$INSTALL_PATH" ]]; then
    if [[ -L "$INSTALL_PATH" ]]; then
        CURRENT_TARGET=$(readlink -f "$INSTALL_PATH")
        if [[ "$CURRENT_TARGET" == "$REPO_ROOT" ]]; then
            success "Symlink already exists: $INSTALL_PATH -> $REPO_ROOT"
        else
            warn "Symlink points elsewhere: $INSTALL_PATH -> $CURRENT_TARGET"
            info "Updating symlink..."
            rm -f "$INSTALL_PATH"
            ln -s "$REPO_ROOT" "$INSTALL_PATH"
            success "Updated symlink: $INSTALL_PATH -> $REPO_ROOT"
        fi
    elif [[ -d "$INSTALL_PATH" ]]; then
        warn "Directory exists at $INSTALL_PATH (not a symlink)"
        warn "Skipping symlink creation - using existing directory"
    else
        info "Creating symlink: $INSTALL_PATH -> $REPO_ROOT"
        mkdir -p "$(dirname "$INSTALL_PATH")"
        ln -s "$REPO_ROOT" "$INSTALL_PATH"
        success "Created symlink"
    fi
else
    success "Repository is already at install path: $INSTALL_PATH"
fi

# ============================================================================
# STEP 2: Install Systemd Units
# ============================================================================

print_header "Step 2: Installing Systemd Unit Files"

INSTALLED_TIMERS=()

# Install replica sync units
if $INSTALL_REPLICA; then
    if install_unit "orion-replica-sync.service" "orion-replica-sync.timer" "Replica Sync"; then
        INSTALLED_TIMERS+=("orion-replica-sync.timer")
    fi
fi

# Install backup units (daily and weekly)
if $INSTALL_BACKUP; then
    if install_unit "orion-backup-daily.service" "orion-backup-daily.timer" "Daily Backup"; then
        INSTALLED_TIMERS+=("orion-backup-daily.timer")
    fi
    if install_unit "orion-backup-weekly.service" "orion-backup-weekly.timer" "Weekly Backup"; then
        INSTALLED_TIMERS+=("orion-backup-weekly.timer")
    fi
fi

# Install Frigate backup units
if $INSTALL_FRIGATE; then
    if install_unit "orion-frigate-backup.service" "orion-frigate-backup.timer" "Frigate Backup"; then
        INSTALLED_TIMERS+=("orion-frigate-backup.timer")
    fi
fi

if [[ ${#INSTALLED_TIMERS[@]} -eq 0 ]]; then
    fail "No units were installed. Check that the unit files exist in $REPO_ROOT/systemd/"
fi

# ============================================================================
# STEP 3: Reload Systemd
# ============================================================================

print_header "Step 3: Reloading Systemd Daemon"

info "Running systemctl daemon-reload..."
systemctl daemon-reload
success "Daemon reloaded"

# ============================================================================
# STEP 4: Enable Timers
# ============================================================================

print_header "Step 4: Enabling Timers"

for timer in "${INSTALLED_TIMERS[@]}"; do
    enable_timer "$timer"
done

# ============================================================================
# STEP 5: Show Status
# ============================================================================

print_header "Status Information"

echo "Timer Status:"
echo ""
systemctl list-timers | grep -E "orion|NEXT|PASSED" || true

# ============================================================================
# SUMMARY
# ============================================================================

print_header "Installation Complete!"

echo "Installed timers:"
for timer in "${INSTALLED_TIMERS[@]}"; do
    echo "  - $timer"
done
echo ""
echo "Timer schedule:"
$INSTALL_REPLICA && echo "  - Replica sync:   Nightly at 02:30"
$INSTALL_BACKUP && echo "  - Daily backup:   Daily at 03:00"
$INSTALL_BACKUP && echo "  - Weekly backup:  Sundays at 04:00"
$INSTALL_FRIGATE && echo "  - Frigate backup: Daily at 03:30"
echo ""
echo "Management commands:"
echo ""
echo "  # View timer status:"
echo "  systemctl list-timers | grep orion"
echo ""
echo "  # Run a service manually:"
echo "  sudo systemctl start <service-name>.service"
echo ""
echo "  # View logs:"
echo "  journalctl -u <service-name>.service -f"
echo ""
echo "  # Disable a timer:"
echo "  sudo systemctl disable --now <timer-name>.timer"
echo ""

success "Installation completed successfully!"
