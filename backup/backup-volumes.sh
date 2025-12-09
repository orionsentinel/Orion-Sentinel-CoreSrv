#!/usr/bin/env bash
# backup-volumes.sh - Backup Docker volumes for Orion-Sentinel-CoreSrv
# Creates timestamped tar.gz archives of critical service volumes
#
# Usage:
#   sudo ./backup/backup-volumes.sh [daily|weekly|monthly]
#   sudo ./backup/backup-volumes.sh all          # Backup all critical volumes
#   sudo ./backup/backup-volumes.sh jellyfin     # Backup specific service

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

# Backup destination
BACKUP_ROOT=${BACKUP_ROOT:-/srv/backups/orion}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DATE_DIR=$(date +%Y-%m-%d)

# Volume source paths (adjust to your configuration)
MEDIA_CONFIG_ROOT=${MEDIA_CONFIG_ROOT:-/srv/docker/media}
GATEWAY_CONFIG_ROOT=${GATEWAY_CONFIG_ROOT:-/srv/orion-sentinel-core/core}
MONITORING_ROOT=${MONITORING_ROOT:-/srv/orion-sentinel-core/monitoring}
HOME_AUTOMATION_ROOT=${HOME_AUTOMATION_ROOT:-/srv/orion-sentinel-core/home-automation}

# Backup mode (daily, weekly, monthly)
BACKUP_MODE=${1:-manual}

# Retention policy (days)
DAILY_RETENTION=7
WEEKLY_RETENTION=30
MONTHLY_RETENTION=365

# ============================================================================
# Critical Volumes to Backup
# ============================================================================

# Define critical volumes with their paths and descriptions
declare -A CRITICAL_VOLUMES=(
    # Media Stack
    ["jellyfin"]="${MEDIA_CONFIG_ROOT}/jellyfin/config|Jellyfin media metadata and user data"
    ["sonarr"]="${MEDIA_CONFIG_ROOT}/sonarr/config|Sonarr TV show configuration"
    ["radarr"]="${MEDIA_CONFIG_ROOT}/radarr/config|Radarr movie configuration"
    ["prowlarr"]="${MEDIA_CONFIG_ROOT}/prowlarr/config|Prowlarr indexer configuration"
    ["jellyseerr"]="${MEDIA_CONFIG_ROOT}/jellyseerr/config|Jellyseerr request configuration"
    ["qbittorrent"]="${MEDIA_CONFIG_ROOT}/qbittorrent/config|qBittorrent settings and state"
    
    # Gateway Stack
    ["traefik"]="${GATEWAY_CONFIG_ROOT}/traefik|Traefik configuration and certificates"
    ["authelia"]="${GATEWAY_CONFIG_ROOT}/authelia|Authelia SSO configuration and user database"
    
    # Monitoring Stack
    ["grafana"]="${MONITORING_ROOT}/grafana/data|Grafana dashboards and user preferences"
    ["prometheus-config"]="${MONITORING_ROOT}/prometheus|Prometheus configuration and rules"
    ["loki-config"]="${MONITORING_ROOT}/loki|Loki configuration"
    
    # Home Automation
    ["homeassistant"]="${HOME_AUTOMATION_ROOT}/homeassistant/config|Home Assistant configuration and automations"
    ["mosquitto"]="${HOME_AUTOMATION_ROOT}/mosquitto|MQTT broker configuration"
    ["zigbee2mqtt"]="${HOME_AUTOMATION_ROOT}/zigbee2mqtt/data|Zigbee2MQTT device database"
    ["mealie"]="${HOME_AUTOMATION_ROOT}/mealie|Mealie recipe database"
)

# ============================================================================
# Functions
# ============================================================================

show_help() {
    cat << EOF
Orion-Sentinel-CoreSrv Volume Backup Script
===========================================

Usage:
  sudo ./backup/backup-volumes.sh [MODE] [SERVICE]

Modes:
  daily       Perform daily backup (keeps last ${DAILY_RETENTION} days)
  weekly      Perform weekly backup (keeps last ${WEEKLY_RETENTION} days)
  monthly     Perform monthly backup (keeps last ${MONTHLY_RETENTION} days)
  manual      Manual backup (default, no auto-cleanup)

Services:
  all         Backup all critical volumes (default)
  <name>      Backup specific service volume

Available services:
$(for service in "${!CRITICAL_VOLUMES[@]}"; do echo "  - $service"; done | sort)

Examples:
  sudo ./backup/backup-volumes.sh                    # Manual backup of all
  sudo ./backup/backup-volumes.sh weekly             # Weekly backup of all
  sudo ./backup/backup-volumes.sh daily jellyfin     # Daily backup of Jellyfin only
  sudo ./backup/backup-volumes.sh manual traefik     # Manual backup of Traefik

Environment Variables:
  BACKUP_ROOT               Backup destination (default: /srv/backups/orion)
  MEDIA_CONFIG_ROOT         Media config path (default: /srv/docker/media)
  GATEWAY_CONFIG_ROOT       Gateway config path (default: /srv/orion-sentinel-core/core)
  MONITORING_ROOT           Monitoring path (default: /srv/orion-sentinel-core/monitoring)
  HOME_AUTOMATION_ROOT      Home automation path (default: /srv/orion-sentinel-core/home-automation)

Notes:
  - This script requires root/sudo for consistent backups
  - Backups are stored in: ${BACKUP_ROOT}/${BACKUP_MODE}/YYYY-MM-DD/
  - Use cron for automated backups (see README for examples)

EOF
}

check_requirements() {
    # Check if running as root
    if [ "$EUID" -ne 0 ]; then
        error "This script must be run as root or with sudo for consistent backups"
    fi
    
    # Check if tar is available
    if ! command -v tar &> /dev/null; then
        error "tar command not found. Please install tar."
    fi
}

create_backup_dirs() {
    local backup_path="${BACKUP_ROOT}/${BACKUP_MODE}/${DATE_DIR}"
    mkdir -p "$backup_path"
    info "Backup directory: $backup_path"
}

backup_volume() {
    local service=$1
    local volume_info=${CRITICAL_VOLUMES[$service]}
    local volume_path=$(echo "$volume_info" | cut -d'|' -f1)
    local description=$(echo "$volume_info" | cut -d'|' -f2)
    
    local backup_path="${BACKUP_ROOT}/${BACKUP_MODE}/${DATE_DIR}"
    local archive_name="${service}-${TIMESTAMP}.tar.gz"
    local archive_path="${backup_path}/${archive_name}"
    
    info "Backing up: $service"
    info "  Source: $volume_path"
    info "  Description: $description"
    
    # Check if source exists
    if [ ! -d "$volume_path" ] && [ ! -f "$volume_path" ]; then
        warn "  Source path does not exist, skipping: $volume_path"
        return 0
    fi
    
    # Create tar archive
    local parent_dir=$(dirname "$volume_path")
    local target_name=$(basename "$volume_path")
    
    tar -czf "$archive_path" -C "$parent_dir" "$target_name" 2>/dev/null || {
        error "  Failed to create backup archive for $service"
    }
    
    local size=$(du -h "$archive_path" | cut -f1)
    success "  Backed up $service ($size): $archive_name"
    
    # Create metadata file
    cat > "${archive_path}.info" << EOF
Service: $service
Description: $description
Source: $volume_path
Backup Date: $(date -Iseconds)
Backup Mode: $BACKUP_MODE
Archive Size: $size
Hostname: $(hostname)
EOF
}

cleanup_old_backups() {
    local retention_days
    
    case "$BACKUP_MODE" in
        daily)   retention_days=$DAILY_RETENTION ;;
        weekly)  retention_days=$WEEKLY_RETENTION ;;
        monthly) retention_days=$MONTHLY_RETENTION ;;
        *)       info "Manual backup - no auto-cleanup"; return 0 ;;
    esac
    
    info "Cleaning up backups older than $retention_days days for mode: $BACKUP_MODE"
    
    local mode_path="${BACKUP_ROOT}/${BACKUP_MODE}"
    if [ -d "$mode_path" ]; then
        find "$mode_path" -type d -name "20*" -mtime +$retention_days -exec rm -rf {} + 2>/dev/null || true
        success "Old backups cleaned up"
    fi
}

create_manifest() {
    local backup_path="${BACKUP_ROOT}/${BACKUP_MODE}/${DATE_DIR}"
    local manifest="${backup_path}/MANIFEST.txt"
    
    cat > "$manifest" << EOF
Orion-Sentinel-CoreSrv Volume Backup
====================================

Backup Created: $(date -Iseconds)
Backup Mode: $BACKUP_MODE
Date: $DATE_DIR
Hostname: $(hostname)

Backed Up Volumes:
------------------
EOF
    
    # List all backup files
    for file in "${backup_path}"/*.tar.gz; do
        if [ -f "$file" ]; then
            local name=$(basename "$file")
            local size=$(du -h "$file" | cut -f1)
            echo "  - $name ($size)" >> "$manifest"
        fi
    done
    
    cat >> "$manifest" << EOF

Restore Instructions:
---------------------
To restore a specific service:
  sudo ./backup/restore-volume.sh $BACKUP_MODE $DATE_DIR <service-name>

Examples:
  sudo ./backup/restore-volume.sh $BACKUP_MODE $DATE_DIR jellyfin
  sudo ./backup/restore-volume.sh $BACKUP_MODE $DATE_DIR traefik

For complete restore documentation, see:
  docs/BACKUP-RESTORE.md

IMPORTANT:
----------
- Stop the service before restoring: docker compose stop <service>
- Verify backup integrity before restoring
- Test restores periodically to ensure backups are valid
- Store copies offsite for disaster recovery

EOF
    
    success "Manifest created: $manifest"
}

# ============================================================================
# Main
# ============================================================================

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Orion-Sentinel-CoreSrv Volume Backup                      ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    # Handle help flag
    if [ "${1:-}" = "-h" ] || [ "${1:-}" = "--help" ]; then
        show_help
        exit 0
    fi
    
    # Parse arguments
    local target_service=${2:-all}
    
    info "Backup mode: $BACKUP_MODE"
    info "Target: $target_service"
    echo ""
    
    check_requirements
    create_backup_dirs
    
    # Perform backups
    if [ "$target_service" = "all" ]; then
        info "Backing up all critical volumes..."
        echo ""
        local count=0
        for service in "${!CRITICAL_VOLUMES[@]}"; do
            backup_volume "$service"
            count=$((count + 1))
            echo ""
        done
        success "Backed up $count volumes"
    else
        if [ -z "${CRITICAL_VOLUMES[$target_service]:-}" ]; then
            error "Unknown service: $target_service (use --help to see available services)"
        fi
        backup_volume "$target_service"
    fi
    
    echo ""
    create_manifest
    cleanup_old_backups
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Backup completed successfully!                            ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    local backup_path="${BACKUP_ROOT}/${BACKUP_MODE}/${DATE_DIR}"
    success "Backup location: $backup_path"
    
    info "Next steps:"
    info "  1. Verify backup integrity: ls -lh $backup_path"
    info "  2. Test restore procedure: sudo ./backup/restore-volume.sh --help"
    info "  3. Copy to offsite location for disaster recovery"
    echo ""
    
    warn "IMPORTANT: These backups may contain sensitive data"
    warn "           Store securely and encrypt for offsite storage"
    echo ""
}

main "$@"
