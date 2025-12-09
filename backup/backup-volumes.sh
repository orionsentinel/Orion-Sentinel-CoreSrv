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
=======================================

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
