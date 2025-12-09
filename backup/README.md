# Backup & Restore Scripts

This directory contains scripts for backing up and restoring critical Orion-Sentinel-CoreSrv volumes.

## Quick Start

### Backup All Critical Volumes

```bash
# Manual backup (no auto-cleanup)
sudo ./backup/backup-volumes.sh

# Daily backup (keeps last 7 days)
sudo ./backup/backup-volumes.sh daily

# Weekly backup (keeps last 30 days)
sudo ./backup/backup-volumes.sh weekly

# Monthly backup (keeps last 365 days)
sudo ./backup/backup-volumes.sh monthly
```

### Backup Specific Service

```bash
# Backup only Jellyfin
sudo ./backup/backup-volumes.sh daily jellyfin

# Backup only Traefik
sudo ./backup/backup-volumes.sh weekly traefik
```

### Restore a Service

```bash
# Restore Jellyfin from weekly backup
sudo ./backup/restore-volume.sh weekly 2024-12-09 jellyfin

# Restore Traefik from daily backup, keeping old data as backup
sudo ./backup/restore-volume.sh daily 2024-12-09 traefik --keep-backup

# Restore without confirmation prompt
sudo ./backup/restore-volume.sh manual 2024-12-09 homeassistant --force
```

## Critical Volumes

The following volumes are backed up:

### Media Stack
- **jellyfin** - Jellyfin media metadata and user data
- **sonarr** - Sonarr TV show configuration
- **radarr** - Radarr movie configuration
- **prowlarr** - Prowlarr indexer configuration
- **jellyseerr** - Jellyseerr request configuration
- **qbittorrent** - qBittorrent settings and state

### Gateway Stack
- **traefik** - Traefik configuration and SSL certificates
- **authelia** - Authelia SSO configuration and user database

### Monitoring Stack
- **grafana** - Grafana dashboards and user preferences
- **prometheus-config** - Prometheus configuration and rules
- **loki-config** - Loki configuration

### Home Automation
- **homeassistant** - Home Assistant configuration and automations
- **mosquitto** - MQTT broker configuration
- **zigbee2mqtt** - Zigbee2MQTT device database
- **mealie** - Mealie recipe database

## Automated Backups with Cron

### Daily Backups at 2 AM

```bash
# Edit crontab as root
sudo crontab -e

# Add this line:
0 2 * * * /path/to/Orion-Sentinel-CoreSrv/backup/backup-volumes.sh daily >> /var/log/orion-backup.log 2>&1
```

### Weekly Backups on Sunday at 3 AM

```bash
# Edit crontab as root
sudo crontab -e

# Add this line:
0 3 * * 0 /path/to/Orion-Sentinel-CoreSrv/backup/backup-volumes.sh weekly >> /var/log/orion-backup.log 2>&1
```

### Monthly Backups on 1st at 4 AM

```bash
# Edit crontab as root
sudo crontab -e

# Add this line:
0 4 1 * * /path/to/Orion-Sentinel-CoreSrv/backup/backup-volumes.sh monthly >> /var/log/orion-backup.log 2>&1
```

### Combined Cron Schedule (Recommended)

```bash
# Daily backups at 2 AM (keeps 7 days)
0 2 * * * /path/to/backup/backup-volumes.sh daily >> /var/log/orion-backup.log 2>&1

# Weekly backups on Sunday at 3 AM (keeps 30 days)
0 3 * * 0 /path/to/backup/backup-volumes.sh weekly >> /var/log/orion-backup.log 2>&1

# Monthly backups on 1st at 4 AM (keeps 365 days)
0 4 1 * * /path/to/backup/backup-volumes.sh monthly >> /var/log/orion-backup.log 2>&1
```

## Backup Location

Backups are stored in:
```
/srv/backups/orion/
├── daily/
│   └── 2024-12-09/
│       ├── jellyfin-20241209-020000.tar.gz
│       ├── traefik-20241209-020100.tar.gz
│       └── MANIFEST.txt
├── weekly/
│   └── 2024-12-08/
├── monthly/
│   └── 2024-12-01/
└── manual/
    └── 2024-12-09/
```

## Environment Variables

You can customize backup locations by setting environment variables:

```bash
# Custom backup destination
export BACKUP_ROOT=/mnt/nas/backups/orion

# Custom source paths
export MEDIA_CONFIG_ROOT=/srv/docker/media
export GATEWAY_CONFIG_ROOT=/srv/orion-sentinel-core/core
export MONITORING_ROOT=/srv/orion-sentinel-core/monitoring
export HOME_AUTOMATION_ROOT=/srv/orion-sentinel-core/home-automation

# Run backup
sudo -E ./backup/backup-volumes.sh daily
```

## Restore Process

### 1. Stop the Service

Before restoring, always stop the service:

```bash
# For media services
docker compose -f compose/docker-compose.media.yml stop jellyfin

# For gateway services
docker compose -f compose/docker-compose.gateway.yml stop traefik

# For monitoring services
docker compose -f compose/docker-compose.observability.yml stop grafana

# For home automation services
docker compose -f compose/docker-compose.homeauto.yml stop homeassistant
```

### 2. Run Restore

```bash
sudo ./backup/restore-volume.sh daily 2024-12-09 jellyfin --keep-backup
```

### 3. Start and Verify

```bash
# Start the service
docker compose -f compose/docker-compose.media.yml start jellyfin

# Check logs
docker compose -f compose/docker-compose.media.yml logs -f jellyfin

# Verify service is working
curl http://localhost:8096
```

### 4. Clean Up Old Backup (Optional)

If the restore was successful and `--keep-backup` was used:

```bash
# Remove the old backup
sudo rm -rf /srv/docker/media/jellyfin/config.backup-*
```

## What's NOT Backed Up

The following are excluded due to size or rebuild-ability:

- **Media library files** (`/srv/media/library`) - Keep separate backups
- **Download files** (`/srv/media/downloads`) - Temporary data
- **Prometheus metrics data** - Time-series data, can be rebuilt
- **Loki logs data** - Log data, can be rebuilt
- **Raw log files** - Can be rebuilt from sources

## Offsite Backup

For disaster recovery, copy backups to an offsite location:

```bash
# Sync to NAS
rsync -avz /srv/backups/orion/ /mnt/nas/backups/orion/

# Sync to remote server via SSH
rsync -avz /srv/backups/orion/ user@remote:/backups/orion/

# Encrypt and upload to cloud (example with rclone)
tar -czf - /srv/backups/orion/daily/ | \
  gpg --encrypt --recipient your@email.com | \
  rclone rcat remote:orion-backups/daily-$(date +%Y%m%d).tar.gz.gpg
```

## Testing Backups

**Critical: Test your backups regularly!**

```bash
# Monthly backup test (add to cron)
0 5 15 * * /path/to/backup/test-restore.sh >> /var/log/orion-backup-test.log 2>&1
```

Example test script:
```bash
#!/bin/bash
# test-restore.sh - Test backup integrity

BACKUP_ROOT=/srv/backups/orion
LATEST_DAILY=$(ls -t $BACKUP_ROOT/daily/ | head -n 1)

echo "Testing backup from: $LATEST_DAILY"

# Test a few critical services
for service in jellyfin traefik grafana; do
    ARCHIVE=$(find $BACKUP_ROOT/daily/$LATEST_DAILY -name "${service}-*.tar.gz" | head -n 1)
    if [ -f "$ARCHIVE" ]; then
        echo "Testing $service: $ARCHIVE"
        tar -tzf "$ARCHIVE" > /dev/null && echo "✓ $service OK" || echo "✗ $service FAILED"
    fi
done
```

## Troubleshooting

### Permission Denied

Run with sudo:
```bash
sudo ./backup/backup-volumes.sh daily
```

### Service Still Running Warning

Stop the service before restoring:
```bash
docker compose -f compose/docker-compose.media.yml stop jellyfin
./backup/restore-volume.sh daily 2024-12-09 jellyfin
```

### Backup Directory Not Found

Check environment variables:
```bash
echo $BACKUP_ROOT
echo $MEDIA_CONFIG_ROOT
```

### Archive Extraction Failed

Verify archive integrity:
```bash
tar -tzf /srv/backups/orion/daily/2024-12-09/jellyfin-*.tar.gz
```

## Security Notes

⚠️ **IMPORTANT**: Backups contain sensitive data including:
- API keys and tokens
- User passwords (hashed)
- SSL certificates
- Authentication secrets
- Configuration files with credentials

**Security recommendations:**
1. Encrypt backups for offsite storage
2. Use restrictive permissions (600/700)
3. Store backups on encrypted volumes
4. Use secure transfer methods (SSH, encrypted channels)
5. Regularly rotate encryption keys
6. Test restore procedures in isolated environments

## For More Information

See the main documentation:
- [docs/BACKUP-RESTORE.md](../docs/BACKUP-RESTORE.md) - Complete backup/restore guide
- [README.md](../README.md) - Main repository documentation
