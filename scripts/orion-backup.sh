#!/usr/bin/env bash
# ============================================================================
# orion-backup.sh - Orion-Sentinel-CoreSrv Database Backup Script
# ============================================================================
#
# Creates database dumps for Mealie and DSMR Reader Postgres databases.
# Supports daily and weekly backup schedules with configurable retention.
#
# Usage:
#   ./scripts/orion-backup.sh           # Daily backup
#   ./scripts/orion-backup.sh --weekly  # Weekly backup (longer retention)
#
# Backup location: ${ORION_BACKUPS_DIR}/db/
#
# ============================================================================

set -euo pipefail

# ============================================================================
# CONFIGURATION
# ============================================================================

# Source from environment or use defaults
ORION_BACKUPS_DIR="${ORION_BACKUPS_DIR:-/srv/orion/external_primary/backups}"
BACKUP_DIR="${ORION_BACKUPS_DIR}/db"
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
DATE_ONLY=$(date +%Y%m%d)

# Retention settings (in days)
DAILY_RETENTION=7
WEEKLY_RETENTION=30

# Database containers
MEALIE_DB_CONTAINER="orion_mealie_db"
DSMR_DB_CONTAINER="orion_dsmr_db"

# Database credentials (from environment)
MEALIE_DB_USER="${MEALIE_DB_USER:-mealie}"
MEALIE_DB_NAME="${MEALIE_DB_NAME:-mealie}"
MEALIE_DB_PASSWORD="${MEALIE_DB_PASSWORD:-mealie-secure-password}"
DSMR_DB_USER="${DSMR_DB_USER:-dsmrreader}"
DSMR_DB_NAME="${DSMR_DB_NAME:-dsmrreader}"
DSMR_DB_PASSWORD="${DSMR_DB_PASSWORD:-dsmr-secure-password}"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# ============================================================================
# HELPER FUNCTIONS
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

err() {
    echo -e "${RED}[ERR]${NC} $*"
}

fail() {
    err "$*"
    exit 1
}

# ============================================================================
# ARGUMENT PARSING
# ============================================================================

BACKUP_TYPE="daily"
RETENTION_DAYS=$DAILY_RETENTION

while [[ $# -gt 0 ]]; do
    case "$1" in
        --weekly)
            BACKUP_TYPE="weekly"
            RETENTION_DAYS=$WEEKLY_RETENTION
            shift
            ;;
        -h|--help)
            cat << 'EOF'
orion-backup.sh - Database Backup Script

USAGE:
    ./scripts/orion-backup.sh [OPTIONS]

OPTIONS:
    --weekly    Create weekly backup with 30-day retention
    -h, --help  Show this help message

Without options, creates a daily backup with 7-day retention.

ENVIRONMENT VARIABLES:
    ORION_BACKUPS_DIR   Backup root directory
    MEALIE_DB_USER      Mealie database user
    MEALIE_DB_NAME      Mealie database name
    DSMR_DB_USER        DSMR database user
    DSMR_DB_NAME        DSMR database name

BACKUP SCHEDULE:
    Daily backups:  Retained for 7 days
    Weekly backups: Retained for 30 days (1 month)

Use with systemd timers for automated scheduling:
    - orion-backup-daily.timer
    - orion-backup-weekly.timer
EOF
            exit 0
            ;;
        *)
            fail "Unknown option: $1"
            ;;
    esac
done

# ============================================================================
# MAIN SCRIPT
# ============================================================================

info "Orion-Sentinel-CoreSrv Database Backup"
info "Type: $BACKUP_TYPE (${RETENTION_DAYS}-day retention)"
info "Timestamp: $TIMESTAMP"
echo ""

# Create backup directories
mkdir -p "${BACKUP_DIR}/daily"
mkdir -p "${BACKUP_DIR}/weekly"

TARGET_DIR="${BACKUP_DIR}/${BACKUP_TYPE}"

# ============================================================================
# MEALIE BACKUP
# ============================================================================

info "Backing up Mealie database..."

if docker ps --format '{{.Names}}' | grep -q "^${MEALIE_DB_CONTAINER}$"; then
    MEALIE_BACKUP_FILE="${TARGET_DIR}/mealie-${BACKUP_TYPE}-${DATE_ONLY}.sql.gz"
    
    # Use PGPASSWORD for authentication
    docker exec -e "PGPASSWORD=${MEALIE_DB_PASSWORD}" -t "$MEALIE_DB_CONTAINER" \
        pg_dump -U "$MEALIE_DB_USER" -d "$MEALIE_DB_NAME" \
        | gzip > "$MEALIE_BACKUP_FILE"
    
    if [[ -s "$MEALIE_BACKUP_FILE" ]]; then
        MEALIE_SIZE=$(du -h "$MEALIE_BACKUP_FILE" | cut -f1)
        success "Mealie backup: $MEALIE_BACKUP_FILE ($MEALIE_SIZE)"
    else
        warn "Mealie backup file is empty - database may be empty"
    fi
else
    warn "Mealie database container not running: $MEALIE_DB_CONTAINER"
fi

# ============================================================================
# DSMR BACKUP
# ============================================================================

info "Backing up DSMR database..."

if docker ps --format '{{.Names}}' | grep -q "^${DSMR_DB_CONTAINER}$"; then
    DSMR_BACKUP_FILE="${TARGET_DIR}/dsmr-${BACKUP_TYPE}-${DATE_ONLY}.sql.gz"
    
    # Use PGPASSWORD for authentication
    docker exec -e "PGPASSWORD=${DSMR_DB_PASSWORD}" -t "$DSMR_DB_CONTAINER" \
        pg_dump -U "$DSMR_DB_USER" -d "$DSMR_DB_NAME" \
        | gzip > "$DSMR_BACKUP_FILE"
    
    if [[ -s "$DSMR_BACKUP_FILE" ]]; then
        DSMR_SIZE=$(du -h "$DSMR_BACKUP_FILE" | cut -f1)
        success "DSMR backup: $DSMR_BACKUP_FILE ($DSMR_SIZE)"
    else
        warn "DSMR backup file is empty - database may be empty"
    fi
else
    warn "DSMR database container not running: $DSMR_DB_CONTAINER"
fi

# ============================================================================
# CLEANUP OLD BACKUPS
# ============================================================================

info "Cleaning up old $BACKUP_TYPE backups (keeping ${RETENTION_DAYS} days)..."

# Find and delete old backups
find "$TARGET_DIR" -name "*.sql.gz" -type f -mtime "+${RETENTION_DAYS}" -delete 2>/dev/null || true

REMAINING=$(find "$TARGET_DIR" -name "*.sql.gz" -type f | wc -l)
success "Cleanup complete. $REMAINING backup files remaining."

# ============================================================================
# SUMMARY
# ============================================================================

echo ""
info "Backup summary:"
echo "  Type:      $BACKUP_TYPE"
echo "  Location:  $TARGET_DIR"
echo "  Retention: ${RETENTION_DAYS} days"
echo ""

# List recent backups
info "Recent backups:"
ls -lh "$TARGET_DIR"/*.sql.gz 2>/dev/null | tail -10 || echo "  (no backups found)"
echo ""

success "Backup completed!"
