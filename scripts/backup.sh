#!/usr/bin/env bash
# backup.sh - Backup Orion-Sentinel-CoreSrv critical data
# Creates timestamped backup archives of configs, data, and databases

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*"
    exit 1
}

# Configuration
BACKUP_ROOT=${BACKUP_ROOT:-/srv/orion-sentinel-core/backups}
CONFIG_ROOT=${CONFIG_ROOT:-/srv/orion-sentinel-core/config}
CLOUD_ROOT=${CLOUD_ROOT:-/srv/orion-sentinel-core/cloud}
MONITORING_ROOT=${MONITORING_ROOT:-/srv/orion-sentinel-core/monitoring}
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
BACKUP_NAME="orion-backup-${TIMESTAMP}"
TEMP_DIR="/tmp/${BACKUP_NAME}"

# Retention (keep last N backups)
RETENTION_COUNT=${RETENTION_COUNT:-7}

# ============================================================================
# Pre-flight checks
# ============================================================================

info "Orion-Sentinel-CoreSrv Backup Script"
info "Timestamp: $TIMESTAMP"
echo ""

# Check if running as root or with sudo
if [ "$EUID" -ne 0 ]; then
    warn "Not running as root. Some files may not be accessible."
    warn "Consider running with: sudo $0"
    echo ""
fi

# Create backup directory
mkdir -p "$BACKUP_ROOT"
mkdir -p "$TEMP_DIR"

info "Backup directory: $BACKUP_ROOT"
info "Temporary staging: $TEMP_DIR"
echo ""

# ============================================================================
# Backup functions
# ============================================================================

backup_configs() {
    info "Backing up service configurations..."
    
    if [ -d "$CONFIG_ROOT" ]; then
        mkdir -p "$TEMP_DIR/config"
        
        # Copy config directories
        info "  - Copying Traefik config"
        cp -r "$CONFIG_ROOT/traefik" "$TEMP_DIR/config/" 2>/dev/null || true
        
        info "  - Copying Authelia config"
        cp -r "$CONFIG_ROOT/authelia" "$TEMP_DIR/config/" 2>/dev/null || true
        
        info "  - Copying media service configs"
        for service in jellyfin sonarr radarr bazarr prowlarr jellyseerr qbittorrent recommendarr; do
            if [ -d "$CONFIG_ROOT/$service" ]; then
                cp -r "$CONFIG_ROOT/$service" "$TEMP_DIR/config/" 2>/dev/null || true
            fi
        done
        
        info "  - Copying Homepage config"
        cp -r "$CONFIG_ROOT/homepage" "$TEMP_DIR/config/" 2>/dev/null || true
        
        success "Service configurations backed up"
    else
        warn "Config directory not found: $CONFIG_ROOT"
    fi
    echo ""
}

backup_cloud() {
    info "Backing up Nextcloud data..."
    
    if [ -d "$CLOUD_ROOT" ]; then
        mkdir -p "$TEMP_DIR/cloud"
        
        # Stop Nextcloud for consistent backup
        info "  - Stopping Nextcloud containers..."
        docker compose stop nextcloud nextcloud-db 2>/dev/null || true
        sleep 2
        
        info "  - Copying Nextcloud database"
        cp -r "$CLOUD_ROOT/db" "$TEMP_DIR/cloud/" 2>/dev/null || true
        
        info "  - Copying Nextcloud app config"
        cp -r "$CLOUD_ROOT/app" "$TEMP_DIR/cloud/" 2>/dev/null || true
        
        # Nextcloud data can be huge - consider excluding or separate backup
        # info "  - Copying Nextcloud user data (this may take a while...)"
        # cp -r "$CLOUD_ROOT/data" "$TEMP_DIR/cloud/" 2>/dev/null || true
        
        # Restart Nextcloud
        info "  - Restarting Nextcloud containers..."
        docker compose start nextcloud nextcloud-db 2>/dev/null || true
        
        success "Nextcloud backed up (data directory excluded)"
        warn "NOTE: Nextcloud user data (/cloud/data) is NOT backed up by default"
        warn "      due to size. Consider separate backup solution for user files."
    else
        warn "Cloud directory not found: $CLOUD_ROOT"
    fi
    echo ""
}

backup_monitoring() {
    info "Backing up Grafana dashboards and config..."
    
    if [ -d "$MONITORING_ROOT" ]; then
        mkdir -p "$TEMP_DIR/monitoring"
        
        # Grafana data (dashboards, users, preferences)
        info "  - Copying Grafana data"
        cp -r "$MONITORING_ROOT/grafana/data" "$TEMP_DIR/monitoring/grafana" 2>/dev/null || true
        
        # Prometheus config (rules, alerts)
        info "  - Copying Prometheus config"
        cp -r "$MONITORING_ROOT/prometheus/prometheus.yml" "$TEMP_DIR/monitoring/" 2>/dev/null || true
        
        # Loki config
        info "  - Copying Loki config"
        cp -r "$MONITORING_ROOT/loki/config.yml" "$TEMP_DIR/monitoring/" 2>/dev/null || true
        
        # Note: Prometheus data and Loki data excluded (huge and can be rebuilt)
        
        success "Monitoring configs backed up (metrics/logs data excluded)"
    else
        warn "Monitoring directory not found: $MONITORING_ROOT"
    fi
    echo ""
}

backup_env_files() {
    info "Backing up environment files..."
    
    mkdir -p "$TEMP_DIR/env"
    
    # Copy actual .env files (NOT .example files)
    for env_file in env/.env.core env/.env.media env/.env.monitoring env/.env.cloud; do
        if [ -f "$env_file" ]; then
            info "  - Copying $env_file"
            cp "$env_file" "$TEMP_DIR/env/" 2>/dev/null || true
        fi
    done
    
    success "Environment files backed up"
    echo ""
}

create_manifest() {
    info "Creating backup manifest..."
    
    cat > "$TEMP_DIR/MANIFEST.txt" << EOF
Orion-Sentinel-CoreSrv Backup
=============================

Backup Created: $TIMESTAMP
Hostname: $(hostname)
Backup Script Version: 1.0

Contents:
---------
- config/         Service configurations (Traefik, Authelia, *arr, etc.)
- cloud/          Nextcloud database and app config (user data excluded)
- monitoring/     Grafana dashboards and monitoring configs
- env/            Environment files with secrets

Excluded (due to size or rebuild-ability):
-------------------------------------------
- Nextcloud user data (/cloud/data)
- Prometheus metrics data
- Loki logs data
- Media library files

Restore Instructions:
---------------------
See docs/BACKUP-RESTORE.md for complete restore procedure.

Quick restore:
1. Extract this archive to /srv/orion-sentinel-core/
2. Ensure .env files are in place
3. Run: docker compose up -d

Notes:
------
- This backup contains SENSITIVE DATA (secrets, API keys, passwords)
- Store securely and encrypt if backing up to cloud/remote storage
- Test restore procedure periodically to ensure backups are valid
EOF
    
    success "Manifest created"
    echo ""
}

create_archive() {
    info "Creating compressed archive..."
    
    cd /tmp
    tar -czf "${BACKUP_ROOT}/${BACKUP_NAME}.tar.gz" "${BACKUP_NAME}" 2>/dev/null
    
    BACKUP_SIZE=$(du -h "${BACKUP_ROOT}/${BACKUP_NAME}.tar.gz" | cut -f1)
    
    success "Backup archive created: ${BACKUP_ROOT}/${BACKUP_NAME}.tar.gz"
    info "Size: $BACKUP_SIZE"
    echo ""
}

cleanup_old_backups() {
    info "Cleaning up old backups (keeping last $RETENTION_COUNT)..."
    
    cd "$BACKUP_ROOT"
    ls -t orion-backup-*.tar.gz 2>/dev/null | tail -n +$((RETENTION_COUNT + 1)) | xargs -r rm -f
    
    REMAINING=$(ls -1 orion-backup-*.tar.gz 2>/dev/null | wc -l)
    success "Old backups removed. $REMAINING backups remaining."
    echo ""
}

cleanup_temp() {
    info "Cleaning up temporary files..."
    rm -rf "$TEMP_DIR"
    success "Temporary files removed"
}

# ============================================================================
# Main backup process
# ============================================================================

echo "=========================================="
echo "Starting backup process..."
echo "=========================================="
echo ""

# Run backups
backup_configs
backup_cloud
backup_monitoring
backup_env_files
create_manifest
create_archive
cleanup_old_backups
cleanup_temp

echo "=========================================="
echo "Backup completed successfully!"
echo "=========================================="
echo ""
success "Backup file: ${BACKUP_ROOT}/${BACKUP_NAME}.tar.gz"
info "Next steps:"
info "  1. Verify backup integrity: tar -tzf ${BACKUP_ROOT}/${BACKUP_NAME}.tar.gz"
info "  2. Test restore procedure: See docs/BACKUP-RESTORE.md"
info "  3. Copy to offsite location for disaster recovery"
echo ""
warn "IMPORTANT: This backup contains sensitive data (secrets, passwords)"
warn "           Store securely and encrypt if copying to cloud storage"
echo ""
