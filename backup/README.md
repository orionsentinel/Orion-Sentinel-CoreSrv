# Backup & Restore Scripts

This directory contains scripts for backing up and restoring critical Orion Sentinel CoreSrv volumes.

## Quick Start

### Backup Everything

```bash
# Run weekly or monthly
sudo ./backup/backup-volumes.sh
```

Backups are saved to `/srv/backups/orion/YYYYMMDD/` by default.

### Restore a Specific Volume

```bash
# Restore Traefik configuration from January 9, 2025
sudo ./backup/restore-volume.sh core-traefik 20250109

# Restore Jellyfin data
sudo ./backup/restore-volume.sh media-jellyfin 20250109
```

## Scripts

### backup-volumes.sh

Creates timestamped backups of all critical service volumes.

**Usage:**
```bash
sudo ./backup/backup-volumes.sh [BACKUP_TARGET_DIR]
```

**Arguments:**
- `BACKUP_TARGET_DIR` - Optional. Where to store backups (default: `/srv/backups/orion`)

**What gets backed up:**

**Core Services** (Highest Priority):
- `core-traefik` - Traefik configuration, dynamic configs, certificates
- `core-authelia` - User database, authentication configuration
- `core-redis` - Session storage

**Media Service Configurations**:
- `media-jellyfin` - Jellyfin database, libraries, users
- `media-sonarr` - TV automation configuration
- `media-radarr` - Movie automation configuration  
- `media-prowlarr` - Indexer configuration
- `media-jellyseerr` - Request management data
- `media-qbittorrent` - Download client configuration
- `media-bazarr` - Subtitle automation configuration

> **Note:** Actual media files are NOT backed up (too large). Only configurations.

**Monitoring Data** (Optional - can rebuild):
- `monitoring-grafana` - Dashboards, datasources, users
- `monitoring-prometheus` - Metrics database
- `monitoring-loki` - Log aggregation data
- `monitoring-uptime-kuma` - Uptime monitors

**Home Automation**:
- `homeauto-homeassistant` - Smart home configuration and database
- `homeauto-zigbee2mqtt` - Zigbee device pairings
- `homeauto-mosquitto` - MQTT broker configuration
- `homeauto-mealie` - Recipe and meal planning data

**Other Services**:
- `search-searxng` - Search engine configuration
- `maintenance-homepage` - Homepage dashboard configuration

**Repository Configurations**:
- All `.env` files (contain secrets and settings)

**Features:**
- Automatic cleanup of backups older than 30 days (configurable)
- Backup manifest with restoration instructions
- Individual tar.gz archives per service (granular restore)

### restore-volume.sh

Restores a specific service volume from backup.

**Usage:**
```bash
sudo ./backup/restore-volume.sh <volume-name> <backup-date> [backup-dir]
```

**Arguments:**
- `volume-name` - Name of volume to restore (see available volumes above)
- `backup-date` - Backup date in YYYYMMDD format
- `backup-dir` - Optional. Base backup directory (default: `/srv/backups/orion`)

**Examples:**
```bash
# Restore Traefik from specific date
sudo ./backup/restore-volume.sh core-traefik 20250109

# Restore Home Assistant from custom backup location
sudo ./backup/restore-volume.sh homeauto-homeassistant 20250108 /mnt/nas/backups
```

**Safety Features:**
- Confirmation prompt before restore
- Automatically stops related containers
- Backs up current data before overwrite (with .backup-* suffix)
- Automatically restarts containers after restore

## Backup Strategy

### Recommended Schedule

**Daily** (automated with cron):
- Core services: `core-traefik`, `core-authelia`
- Critical configs: `.env` files

**Weekly** (automated with cron):
- All media service configurations
- Home automation data
- Full backup script

**Monthly** (manual verification):
- Verify backup integrity
- Test restore procedure
- Archive to external storage

### Setting Up Automated Backups

Add to crontab (`sudo crontab -e`):

```bash
# Daily backup at 2 AM
0 2 * * * /path/to/Orion-Sentinel-CoreSrv/backup/backup-volumes.sh >> /var/log/orion-backup.log 2>&1

# Weekly backup to NAS at 3 AM on Sundays
0 3 * * 0 /path/to/Orion-Sentinel-CoreSrv/backup/backup-volumes.sh /mnt/nas/backups >> /var/log/orion-backup.log 2>&1
```

### Storage Requirements

Approximate backup sizes (excluding media files):

- Core services: ~100 MB
- Media configurations: ~500 MB
- Monitoring data: ~1-5 GB (varies with retention)
- Home automation: ~200 MB
- Total (typical): ~2-6 GB

**Recommendations:**
- Keep 30 days of backups on local disk (~60-180 GB)
- Archive monthly backups to external storage
- Media library backups require separate strategy (too large)

## Disaster Recovery

### Full System Restore

If you need to rebuild from scratch:

1. **Fresh install** - Set up new system with Docker
2. **Clone repository** - Get latest code
3. **Restore .env files**:
   ```bash
   cd /path/to/backups/20250109
   tar -xzf orion-backup-*-repo-configs.tar.gz -C /path/to/Orion-Sentinel-CoreSrv/
   ```
4. **Run bootstrap** - Creates directory structure:
   ```bash
   sudo ./scripts/bootstrap-coresrv.sh
   ```
5. **Restore core services**:
   ```bash
   sudo ./backup/restore-volume.sh core-traefik 20250109
   sudo ./backup/restore-volume.sh core-authelia 20250109
   ```
6. **Restore other services** - As needed
7. **Start services**:
   ```bash
   make up-full
   ```

### Partial Service Restore

To restore just one service (e.g., Jellyfin after corruption):

1. **Stop service**:
   ```bash
   make down
   ```
2. **Restore volume**:
   ```bash
   sudo ./backup/restore-volume.sh media-jellyfin 20250109
   ```
3. **Restart**:
   ```bash
   make up-media
   ```

## Backup Verification

Periodically verify your backups:

```bash
# List available backups
ls -lh /srv/backups/orion/

# Check backup manifest
cat /srv/backups/orion/20250109/orion-backup-*-manifest.txt

# Test restore to temp location (advanced)
sudo ./backup/restore-volume.sh core-traefik 20250109 /tmp/test-restore
```

## Excluded from Backups

The following are **intentionally excluded** to save space:

- **Media files** - Movies, TV shows, music (too large, can re-download)
- **Docker images** - Can be pulled fresh
- **Log files** - Only current logs needed
- **Temporary data** - Cache, session files

These should be backed up separately if needed (e.g., media to NAS).

## Security

**Important:** Backup files contain sensitive data:

- Traefik SSL certificates
- Authelia user passwords (hashed)
- API keys and tokens from .env files
- Service databases

**Recommendations:**
- Encrypt backups if storing off-site
- Restrict access to backup directory (`chmod 700`)
- Don't share backups publicly
- Use encrypted external storage for archival

Example encryption:

```bash
# Encrypt backup directory
tar -czf - /srv/backups/orion/20250109 | gpg -c > orion-backup-20250109.tar.gz.gpg

# Decrypt when needed
gpg -d orion-backup-20250109.tar.gz.gpg | tar -xz
```

## Troubleshooting

**"Permission denied" errors:**
```bash
# Scripts must be run as root
sudo ./backup/backup-volumes.sh
```

**"No space left on device":**
```bash
# Clean up old backups manually
sudo rm -rf /srv/backups/orion/YYYYMMDD

# Or reduce RETENTION_DAYS
export RETENTION_DAYS=7
sudo ./backup/backup-volumes.sh
```

**Restore doesn't start containers:**
```bash
# Manually start after restore
make up-full
```

## See Also

- [docs/BACKUP-RESTORE.md](../docs/BACKUP-RESTORE.md) - Detailed backup/restore procedures
- [docs/RUNBOOKS.md](../docs/RUNBOOKS.md) - Operational procedures
- [README.md](../README.md) - Main documentation
