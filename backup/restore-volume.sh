#!/usr/bin/env bash
################################################################################
# restore-volume.sh - Restore a specific Orion Sentinel volume from backup
#
# This script restores a single service volume from a timestamped backup.
#
# Usage:
#   sudo ./backup/restore-volume.sh <volume-name> <backup-date> [backup-dir]
#
# Arguments:
#   volume-name   - Name of the volume to restore (e.g., core-traefik)
#   backup-date   - Date of backup in YYYYMMDD format (e.g., 20250109)
#   backup-dir    - Optional. Base backup directory. Default: /srv/backups/orion
#
# Examples:
#   sudo ./backup/restore-volume.sh core-traefik 20250109
#   sudo ./backup/restore-volume.sh media-jellyfin 20250108 /mnt/nas/backups
#
# Available volumes:
#   Core: core-traefik, core-authelia, core-redis
#   Media: media-jellyfin, media-sonarr, media-radarr, media-prowlarr, 
#          media-jellyseerr, media-qbittorrent, media-bazarr
#   Monitoring: monitoring-grafana, monitoring-prometheus, monitoring-loki,
#               monitoring-uptime-kuma
#   Home Auto: homeauto-homeassistant, homeauto-zigbee2mqtt, 
#              homeauto-mosquitto, homeauto-mealie
#   Other: search-searxng, maintenance-homepage
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
SOURCE_ROOT="/srv/orion-sentinel-core"

# Volume name to path mapping
declare -A VOLUME_PATHS=(
    # Core services
    ["core-traefik"]="${SOURCE_ROOT}/core/traefik"
    ["core-authelia"]="${SOURCE_ROOT}/core/authelia"
    ["core-redis"]="${SOURCE_ROOT}/core/redis"
    
    # Media configurations
    ["media-jellyfin"]="${SOURCE_ROOT}/media/config/jellyfin"
    ["media-sonarr"]="${SOURCE_ROOT}/media/config/sonarr"
    ["media-radarr"]="${SOURCE_ROOT}/media/config/radarr"
    ["media-prowlarr"]="${SOURCE_ROOT}/media/config/prowlarr"
    ["media-jellyseerr"]="${SOURCE_ROOT}/media/config/jellyseerr"
    ["media-qbittorrent"]="${SOURCE_ROOT}/media/config/qbittorrent"
    ["media-bazarr"]="${SOURCE_ROOT}/media/config/bazarr"
    
    # Monitoring data
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

################################################################################
# FUNCTIONS
################################################################################

usage() {
    cat << EOF
Usage: sudo ./backup/restore-volume.sh <volume-name> <backup-date> [backup-dir]

Arguments:
  volume-name   - Name of the volume to restore
  backup-date   - Date of backup in YYYYMMDD format
  backup-dir    - Optional. Base backup directory (default: /srv/backups/orion)

Available volumes:
EOF
    
    for volume in "${!VOLUME_PATHS[@]}"; do
        echo "  - ${volume}"
    done | sort
    
    echo ""
    echo "Examples:"
    echo "  sudo ./backup/restore-volume.sh core-traefik 20250109"
    echo "  sudo ./backup/restore-volume.sh media-jellyfin 20250108"
    exit 1
}

check_root() {
    if [[ $EUID -ne 0 ]]; then
        error "This script must be run as root (use sudo)"
    fi
}

validate_volume() {
    local volume=$1
    
    if [[ ! -v "VOLUME_PATHS[$volume]" ]]; then
        error "Unknown volume: ${volume}. Run without arguments to see available volumes."
    fi
}

find_backup_archive() {
    local volume=$1
    local backup_date=$2
    local backup_base=$3
    local backup_dir="${backup_base}/${backup_date}"
    
    if [[ ! -d "${backup_dir}" ]]; then
        error "Backup directory not found: ${backup_dir}"
    fi
    
    # Find the backup archive (there may be multiple with different timestamps)
    local archives=($(find "${backup_dir}" -name "*-${volume}.tar.gz" -type f 2>/dev/null))
    
    if [[ ${#archives[@]} -eq 0 ]]; then
        error "No backup found for ${volume} in ${backup_dir}"
    fi
    
    # Use the most recent one if multiple exist
    local archive="${archives[-1]}"
    
    echo "${archive}"
}

confirm_restore() {
    local volume=$1
    local path=$2
    local archive=$3
    
    echo ""
    warn "WARNING: This will replace the current ${volume} data!"
    echo ""
    info "Volume:       ${volume}"
    info "Current path: ${path}"
    info "Backup file:  $(basename "${archive}")"
    info "Backup size:  $(du -h "${archive}" | cut -f1)"
    echo ""
    
    read -p "Are you sure you want to proceed? (yes/no): " confirm
    
    if [[ "${confirm}" != "yes" ]]; then
        info "Restore cancelled"
        exit 0
    fi
}

stop_related_containers() {
    local volume=$1
    
    info "Stopping related containers..."
    
    # Determine which compose file to use based on volume prefix
    local compose_file=""
    
    case "${volume}" in
        core-*)
            compose_file="compose/docker-compose.gateway.yml"
            ;;
        media-*)
            compose_file="compose/docker-compose.media.yml"
            ;;
        monitoring-*)
            compose_file="compose/docker-compose.observability.yml"
            ;;
        homeauto-*)
            compose_file="compose/docker-compose.homeauto.yml"
            ;;
        search-*|maintenance-*)
            warn "No specific compose file for ${volume}, skipping container stop"
            return 0
            ;;
    esac
    
    if [[ -n "${compose_file}" ]] && [[ -f "${compose_file}" ]]; then
        docker compose -f "${compose_file}" down 2>/dev/null || true
        success "Containers stopped"
    fi
}

backup_current_data() {
    local volume=$1
    local path=$2
    
    if [[ ! -d "${path}" ]]; then
        info "No existing data to backup"
        return 0
    fi
    
    local backup_name="${path}.backup-$(date +%Y%m%d-%H%M%S)"
    
    info "Backing up current data to: ${backup_name}"
    
    mv "${path}" "${backup_name}"
    
    success "Current data backed up"
}

restore_volume() {
    local volume=$1
    local path=$2
    local archive=$3
    
    info "Restoring ${volume}..."
    
    # Create parent directory if it doesn't exist
    mkdir -p "$(dirname "${path}")"
    
    # Extract archive
    local parent_dir="$(dirname "${path}")"
    local volume_basename="$(basename "${path}")"
    
    if tar -xzf "${archive}" -C "${parent_dir}" 2>/dev/null; then
        success "Volume restored successfully"
    else
        error "Failed to extract backup archive"
    fi
}

start_containers() {
    local volume=$1
    
    info "Starting containers..."
    
    # Determine which compose file to use
    local compose_file=""
    
    case "${volume}" in
        core-*)
            compose_file="compose/docker-compose.gateway.yml"
            ;;
        media-*)
            compose_file="compose/docker-compose.media.yml"
            ;;
        monitoring-*)
            compose_file="compose/docker-compose.observability.yml"
            ;;
        homeauto-*)
            compose_file="compose/docker-compose.homeauto.yml"
            ;;
        *)
            warn "No specific compose file for ${volume}, skipping container start"
            return 0
            ;;
    esac
    
    if [[ -n "${compose_file}" ]] && [[ -f "${compose_file}" ]]; then
        docker compose -f "${compose_file}" up -d 2>/dev/null || true
        success "Containers started"
    fi
}

################################################################################
# MAIN
################################################################################

main() {
    # Check arguments
    if [[ $# -lt 2 ]]; then
        usage
    fi
    
    local volume=$1
    local backup_date=$2
    local backup_base="${3:-/srv/backups/orion}"
    
    echo ""
    echo "╔════════════════════════════════════════════════════════════╗"
    echo "║  Orion Sentinel CoreSrv - Volume Restore                   ║"
    echo "╚════════════════════════════════════════════════════════════╝"
    echo ""
    
    check_root
    validate_volume "${volume}"
    
    local path="${VOLUME_PATHS[$volume]}"
    local archive=$(find_backup_archive "${volume}" "${backup_date}" "${backup_base}")
    
    confirm_restore "${volume}" "${path}" "${archive}"
    
    echo ""
    stop_related_containers "${volume}"
    
    echo ""
    backup_current_data "${volume}" "${path}"
    
    echo ""
    restore_volume "${volume}" "${path}" "${archive}"
    
    echo ""
    start_containers "${volume}"
    
    echo ""
    success "Restore completed successfully!"
    echo ""
    info "Volume ${volume} has been restored from backup"
    info "Previous data backed up with .backup-* suffix if it existed"
    echo ""
}

main "$@"
