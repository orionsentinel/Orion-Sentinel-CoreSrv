#!/usr/bin/env bash
# restore-volume.sh - Restore Docker volumes for Orion-Sentinel-CoreSrv
# Restores service volumes from backup archives
#
# Usage:
#   sudo ./backup/restore-volume.sh <backup-mode> <date> <service>
#   sudo ./backup/restore-volume.sh daily 2024-12-09 jellyfin

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() { echo -e "${BLUE}ℹ${NC} $*"; }
success() { echo -e "${GREEN}✓${NC} $*"; }
warn() { echo -e "${YELLOW}⚠${NC} $*"; }
error() { echo -e "${RED}✗${NC} $*"; exit 1; }

# ============================================================================
# Configuration
# ============================================================================

BACKUP_ROOT=${BACKUP_ROOT:-/srv/backups/orion}

# Volume destination paths (adjust to your configuration)
MEDIA_CONFIG_ROOT=${MEDIA_CONFIG_ROOT:-/srv/docker/media}
GATEWAY_CONFIG_ROOT=${GATEWAY_CONFIG_ROOT:-/srv/orion-sentinel-core/core}
MONITORING_ROOT=${MONITORING_ROOT:-/srv/orion-sentinel-core/monitoring}
HOME_AUTOMATION_ROOT=${HOME_AUTOMATION_ROOT:-/srv/orion-sentinel-core/home-automation}

# ============================================================================
# Critical Volumes (must match backup-volumes.sh)
# ============================================================================

declare -A CRITICAL_VOLUMES=(
    # Media Stack
    ["jellyfin"]="${MEDIA_CONFIG_ROOT}/jellyfin/config"
    ["sonarr"]="${MEDIA_CONFIG_ROOT}/sonarr/config"
    ["radarr"]="${MEDIA_CONFIG_ROOT}/radarr/config"
    ["prowlarr"]="${MEDIA_CONFIG_ROOT}/prowlarr/config"
    ["jellyseerr"]="${MEDIA_CONFIG_ROOT}/jellyseerr/config"
    ["qbittorrent"]="${MEDIA_CONFIG_ROOT}/qbittorrent/config"
    
    # Gateway Stack
    ["traefik"]="${GATEWAY_CONFIG_ROOT}/traefik"
    ["authelia"]="${GATEWAY_CONFIG_ROOT}/authelia"
    
    # Monitoring Stack
    ["grafana"]="${MONITORING_ROOT}/grafana/data"
    ["prometheus-config"]="${MONITORING_ROOT}/prometheus"
    ["loki-config"]="${MONITORING_ROOT}/loki"
    
    # Home Automation
    ["homeassistant"]="${HOME_AUTOMATION_ROOT}/homeassistant/config"
    ["mosquitto"]="${HOME_AUTOMATION_ROOT}/mosquitto"
    ["zigbee2mqtt"]="${HOME_AUTOMATION_ROOT}/zigbee2mqtt/data"
    ["mealie"]="${HOME_AUTOMATION_ROOT}/mealie"
)

# ============================================================================
# Functions
# ============================================================================

show_help() {
    cat << EOF
Orion-Sentinel-CoreSrv Volume Restore Script
============================================

Usage:
  sudo ./backup/restore-volume.sh <backup-mode> <date> <service> [options]

Arguments:
  backup-mode     Backup mode to restore from (daily, weekly, monthly, manual)
  date            Date of backup in YYYY-MM-DD format
  service         Service name to restore

Options:
  --force         Skip confirmation prompt
  --keep-backup   Don't delete old volume, rename to .backup-TIMESTAMP

Available services:
$(for service in "${!CRITICAL_VOLUMES[@]}"; do echo "  - $service"; done | sort)

Examples:
  # Restore Jellyfin from weekly backup
  sudo ./backup/restore-volume.sh weekly 2024-12-01 jellyfin

  # Restore Traefik from daily backup without confirmation
  sudo ./backup/restore-volume.sh daily 2024-12-09 traefik --force

  # Restore Home Assistant keeping old data as backup
  sudo ./backup/restore-volume.sh manual 2024-12-09 homeassistant --keep-backup

Restore Process:
  1. Verify backup exists and is readable
  2. Check if service is running (will warn if it is)
  3. Create backup of existing volume (unless --force)
  4. Extract backup archive to destination
  5. Verify restore was successful

IMPORTANT:
  - Always stop the service before restoring:
    docker compose -f compose/docker-compose.<module>.yml stop <service>
  
  - Test restored service before removing backup:
    docker compose -f compose/docker-compose.<module>.yml start <service>
  
  - Keep offsite backups for disaster recovery

Environment Variables:
  BACKUP_ROOT               Backup location (default: /srv/backups/orion)
  MEDIA_CONFIG_ROOT         Media config path (default: /srv/docker/media)
  GATEWAY_CONFIG_ROOT       Gateway config path (default: /srv/orion-sentinel-core/core)
  MONITORING_ROOT           Monitoring path (default: /srv/orion-sentinel-core/monitoring)
  HOME_AUTOMATION_ROOT      Home automation path (default: /srv/orion-sentinel-core/home-automation)

EOF
}

check_requirements() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root or with sudo"
    fi
    
    # Check if tar is available
    if ! command -v tar &> /dev/null; then
        error "tar command not found. Please install tar."
    fi
    
    # Check if docker is available
    if ! command -v docker &> /dev/null; then
        warn "docker command not found. Cannot check if service is running."
    fi
}

find_backup_archive() {
    local backup_mode=$1
    local backup_date=$2
    local service=$3
    
    local backup_dir="${BACKUP_ROOT}/${backup_mode}/${backup_date}"
    
    if [ ! -d "$backup_dir" ]; then
        error "Backup directory does not exist: $backup_dir"
    fi
    
    # Find the most recent backup for this service on this date
    local archive=$(find "$backup_dir" -name "${service}-*.tar.gz" -type f | sort -r | head -n 1)
    
    if [ -z "$archive" ]; then
        error "No backup archive found for service '$service' in $backup_dir"
    fi
    
    echo "$archive"
}

check_service_running() {
    local service=$1
    
    if ! command -v docker &> /dev/null; then
        return 0
    fi
    
    # Check if container is running
    if docker ps --format '{{.Names}}' | grep -q "orion_${service}"; then
        warn "Service '$service' appears to be running!"
        warn "It's recommended to stop the service before restoring."
        echo ""
        info "To stop the service, run:"
        info "  docker compose -f compose/docker-compose.<module>.yml stop $service"
        echo ""
        
        if [ "${FORCE:-false}" != "true" ]; then
            read -p "Continue anyway? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                error "Restore cancelled by user"
            fi
        fi
    fi
}

backup_existing_volume() {
    local volume_path=$1
    local service=$2
    
    if [ ! -e "$volume_path" ]; then
        info "No existing volume found at $volume_path (this is OK for new installs)"
        return 0
    fi
    
    if [ "${KEEP_BACKUP:-false}" = "true" ]; then
        local backup_suffix=".backup-$(date +%Y%m%d-%H%M%S)"
        local backup_path="${volume_path}${backup_suffix}"
        
        info "Creating backup of existing volume..."
        mv "$volume_path" "$backup_path"
        success "Existing volume backed up to: $backup_path"
    else
        warn "Existing volume will be replaced: $volume_path"
        if [ "${FORCE:-false}" != "true" ]; then
            read -p "Continue? (y/N): " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Yy]$ ]]; then
                error "Restore cancelled by user"
            fi
        fi
        
        info "Removing existing volume..."
        rm -rf "$volume_path"
        success "Existing volume removed"
    fi
}

restore_archive() {
    local archive=$1
    local volume_path=$2
    local service=$3
    
    info "Restoring from archive: $(basename "$archive")"
    
    # Get parent directory and target name
    local parent_dir=$(dirname "$volume_path")
    local target_name=$(basename "$volume_path")
    
    # Ensure parent directory exists
    mkdir -p "$parent_dir"
    
    # Extract archive
    info "Extracting to: $volume_path"
    tar -xzf "$archive" -C "$parent_dir" 2>/dev/null || {
        error "Failed to extract backup archive"
    }
    
    # Verify restoration
    if [ -e "$volume_path" ]; then
        local size=$(du -sh "$volume_path" | cut -f1)
        success "Restore complete! Volume size: $size"
    else
        error "Restore verification failed: $volume_path does not exist after extraction"
    fi
}

show_post_restore_info() {
    local service=$1
    
    echo ""
    info "Restore completed for: $service"
    echo ""
    info "Next steps:"
    info "  1. Start the service:"
    info "     docker compose -f compose/docker-compose.<module>.yml start $service"
    echo ""
    info "  2. Verify the service works correctly:"
    info "     docker compose -f compose/docker-compose.<module>.yml logs -f $service"
    echo ""
    info "  3. Access the service and check configuration"
    echo ""
    
    if [ "${KEEP_BACKUP:-false}" = "true" ]; then
        info "  4. Once verified, you can remove the old backup:"
        info "     rm -rf ${CRITICAL_VOLUMES[$service]}.backup-*"
        echo ""
    fi
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Orion-Sentinel-CoreSrv Volume Restore                     ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Handle help flag
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ] || [ $# -lt 3 ]; then
        show_help
        exit 0
    fi
    
    # Parse arguments
    local backup_mode=$1
    local backup_date=$2
    local service=$3
    
    # Parse options
    export FORCE=false
    export KEEP_BACKUP=false
    shift 3
    while [ $# -gt 0 ]; do
        case $1 in
            --force) FORCE=true ;;
            --keep-backup) KEEP_BACKUP=true ;;
            *) warn "Unknown option: $1" ;;
        esac
        shift
    done
    
    info "Restore configuration:"
    info "  Backup mode: $backup_mode"
    info "  Backup date: $backup_date"
    info "  Service: $service"
    info "  Force: $FORCE"
    info "  Keep backup: $KEEP_BACKUP"
    echo ""
    
    # Validate service
    if [ -z "${CRITICAL_VOLUMES[$service]:-}" ]; then
        error "Unknown service: $service (use --help to see available services)"
    fi
    
    local volume_path=${CRITICAL_VOLUMES[$service]}
    
    check_requirements
    
    # Find backup archive
    local archive=$(find_backup_archive "$backup_mode" "$backup_date" "$service")
    local archive_size=$(du -h "$archive" | cut -f1)
    
    success "Found backup archive: $(basename "$archive") ($archive_size)"
    echo ""
    
    # Check if service is running
    check_service_running "$service"
    
    # Backup existing volume
    backup_existing_volume "$volume_path" "$service"
    
    # Restore from archive
    echo ""
    restore_archive "$archive" "$volume_path" "$service"
    
    # Show post-restore information
    show_post_restore_info "$service"
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Restore completed successfully!                           ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
}

main "$@"
