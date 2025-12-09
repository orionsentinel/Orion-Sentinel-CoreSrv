#!/usr/bin/env bash
################################################################################
# backup-volumes.sh - Backup critical Orion Sentinel volumes
#
# This script creates timestamped tar.gz archives of all critical service
# volumes and configuration data.
#
# Usage:
#   sudo ./backup/backup-volumes.sh [BACKUP_TARGET_DIR]
#
# Arguments:
#   BACKUP_TARGET_DIR - Optional. Directory to store backups.
#                       Default: /srv/backups/orion
#
# Example:
#   sudo ./backup/backup-volumes.sh /mnt/nas/backups
#
################################################################################

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color


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
    
    if ! tar -czf "$archive_path" -C "$parent_dir" "$target_name"; then
        error "  Failed to create backup archive for $service"
    fi
    
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
        # Find and remove old backup directories safely
        find "$mode_path" -type d -name "20*" -mtime +$retention_days 2>/dev/null | while read -r dir; do
            if ! rm -rf "$dir" 2>/dev/null; then
                warn "Failed to remove old backup: $dir"
            fi
        done
        success "Old backups cleaned up"
    fi
}

create_manifest() {
    local backup_path="${BACKUP_ROOT}/${BACKUP_MODE}/${DATE_DIR}"
    local manifest="${backup_path}/MANIFEST.txt"
    
    cat > "$manifest" << EOF
Orion-Sentinel-CoreSrv Volume Backup

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
info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERR]${NC} $*"
    exit 1
}

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DATE_ONLY=$(date +%Y%m%d)

# Default backup target
BACKUP_TARGET="${1:-/srv/backups/orion}"
BACKUP_NAME="orion-backup-${TIMESTAMP}"
BACKUP_DIR="${BACKUP_TARGET}/${DATE_ONLY}"

# Source directory (where actual data lives)
SOURCE_ROOT="/srv/orion-sentinel-core"

# Retention (keep backups for N days)
RETENTION_DAYS=${RETENTION_DAYS:-30}

################################################################################
# CRITICAL VOLUMES TO BACKUP
################################################################################

# Define critical volumes/directories to backup
declare -A CRITICAL_VOLUMES=(
    # Core services (highest priority)
    ["core-traefik"]="${SOURCE_ROOT}/core/traefik"
    ["core-authelia"]="${SOURCE_ROOT}/core/authelia"
    ["core-redis"]="${SOURCE_ROOT}/core/redis"
    
    # Media configurations (not the actual media files - too large)
    ["media-jellyfin"]="${SOURCE_ROOT}/media/config/jellyfin"
    ["media-sonarr"]="${SOURCE_ROOT}/media/config/sonarr"
    ["media-radarr"]="${SOURCE_ROOT}/media/config/radarr"
    ["media-prowlarr"]="${SOURCE_ROOT}/media/config/prowlarr"
    ["media-jellyseerr"]="${SOURCE_ROOT}/media/config/jellyseerr"
    ["media-qbittorrent"]="${SOURCE_ROOT}/media/config/qbittorrent"
    ["media-bazarr"]="${SOURCE_ROOT}/media/config/bazarr"
    
    # Monitoring data (optional - can rebuild)
    ["monitoring-grafana"]="${SOURCE_ROOT}/monitoring/grafana"
    ["monitoring-prometheus"]="${SOURCE_ROOT}/monitoring/prometheus"
    ["monitoring-loki"]="${SOURCE_ROOT}/monitoring/loki"
    ["monitoring-uptime-kuma"]="${SOURCE_ROOT}/monitoring/uptime-kuma"
    
    # Home automation
    ["homeauto-homeassistant"]="${SOURCE_ROOT}/home-automation/homeassistant"
    ["homeauto-zigbee2mqtt"]="${SOURCE_ROOT}/home-automation/zigbee2mqtt"
    ["homeauto-mosquitto"]="${SOURCE_ROOT}/home-automation/mosquitto"
    ["homeauto-mealie"]="${SOURCE_ROOT}/home-automation/mealie"
    
    # Search
    ["search-searxng"]="${SOURCE_ROOT}/search/searxng"
    
    # Maintenance
    ["maintenance-homepage"]="${SOURCE_ROOT}/maintenance/homepage"
)

# Also backup repo configuration files
REPO_CONFIGS=(
    ".env"
    "env/.env.media"
    "env/.env.gateway"
    "env/.env.observability"
    "env/.env.homeauto"
)

################################################################################
# FUNCTIONS
################################################################################

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

create_backup_dir() {
    info "Creating backup directory: ${BACKUP_DIR}"
    mkdir -p "${BACKUP_DIR}"
    
    if [[ ! -d "${BACKUP_DIR}" ]]; then
        error "Failed to create backup directory"
    fi
    
    success "Backup directory ready: ${BACKUP_DIR}"
}

backup_volume() {
    local name=$1
    local path=$2
    local archive="${BACKUP_DIR}/${BACKUP_NAME}-${name}.tar.gz"
    
    if [[ ! -d "$path" ]]; then
        warn "Skipping ${name}: directory not found at ${path}"
        return 0
    fi
    
    info "Backing up ${name}..."
    
    # Create tar.gz archive
    if tar -czf "${archive}" -C "$(dirname "$path")" "$(basename "$path")" 2>/dev/null; then
        local size=$(du -h "${archive}" | cut -f1)
        success "Backed up ${name} (${size})"
    else
        warn "Failed to backup ${name}"
    fi
}

backup_repo_configs() {
    local config_archive="${BACKUP_DIR}/${BACKUP_NAME}-repo-configs.tar.gz"
    
    info "Backing up repository configuration files..."
    
    cd "${REPO_ROOT}"
    
    # Create list of existing config files
    local files_to_backup=()
    for config in "${REPO_CONFIGS[@]}"; do
        if [[ -f "$config" ]]; then
            files_to_backup+=("$config")
        fi
    done
    
    if [[ ${#files_to_backup[@]} -eq 0 ]]; then
        warn "No configuration files found to backup"
        return 0
    fi
    
    if tar -czf "${config_archive}" "${files_to_backup[@]}" 2>/dev/null; then
        local size=$(du -h "${config_archive}" | cut -f1)
        success "Backed up ${#files_to_backup[@]} config file(s) (${size})"
    else
        warn "Failed to backup configuration files"
    fi
}

create_backup_manifest() {
    local manifest="${BACKUP_DIR}/${BACKUP_NAME}-manifest.txt"
    
    info "Creating backup manifest..."
    
    cat > "${manifest}" << EOF
Orion Sentinel CoreSrv Backup Manifest

Backup Timestamp: ${TIMESTAMP}
Backup Location:  ${BACKUP_DIR}
Hostname:         $(hostname)
User:             $(whoami)

Backed up volumes:
EOF
    
    for name in "${!CRITICAL_VOLUMES[@]}"; do
        local path="${CRITICAL_VOLUMES[$name]}"
        local archive="${BACKUP_NAME}-${name}.tar.gz"
        
        if [[ -f "${BACKUP_DIR}/${archive}" ]]; then
            local size=$(du -h "${BACKUP_DIR}/${archive}" | awk '{print $1}')
            echo "  ✓ ${name}: ${archive} (${size})" >> "${manifest}"
        fi
    done
    
    cat >> "${manifest}" << EOF

Repository configs:
  ${BACKUP_NAME}-repo-configs.tar.gz

To restore a specific volume:
  sudo ./backup/restore-volume.sh <volume-name> <backup-date>

Example:
  sudo ./backup/restore-volume.sh core-traefik ${DATE_ONLY}
EOF
    
    success "Manifest created: ${manifest}"
}

cleanup_old_backups() {
    info "Cleaning up backups older than ${RETENTION_DAYS} days..."
    
    if [[ ! -d "${BACKUP_TARGET}" ]]; then
        return 0
    fi
    
    local deleted=0
    
    # Find and delete old backup directories
    while IFS= read -r -d '' dir; do
        rm -rf "$dir"
        deleted=$((deleted + 1))
    done < <(find "${BACKUP_TARGET}" -maxdepth 1 -type d -mtime "+${RETENTION_DAYS}" -print0 2>/dev/null)
    
    if [[ $deleted -gt 0 ]]; then
        success "Removed ${deleted} old backup(s)"
    else
        info "No old backups to remove"
    fi
}

################################################################################
# MAIN
################################################################################

main() {
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Orion Sentinel CoreSrv - Volume Backup                    ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_root
    create_backup_dir
    
    info "Starting backup at $(date)"
    echo ""
    
    # Backup all critical volumes
    for name in "${!CRITICAL_VOLUMES[@]}"; do
        backup_volume "$name" "${CRITICAL_VOLUMES[$name]}"
    done
    
    echo ""
    backup_repo_configs
    
    echo ""
    create_backup_manifest
    
    echo ""
    cleanup_old_backups
    
    echo ""
    success "Backup completed successfully!"
    echo ""
    info "Backup location: ${BACKUP_DIR}"
    info "To restore a volume: sudo ./backup/restore-volume.sh <volume-name> ${DATE_ONLY}"
    echo ""
}

main "$@"
