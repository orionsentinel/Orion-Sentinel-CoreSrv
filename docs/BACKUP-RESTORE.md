# Backup and Restore Guide

## Overview

This guide explains how to backup and restore your Orion-Sentinel-CoreSrv installation. Regular backups are **critical** - if the CoreSrv disk fails at 3 AM, this document will save you.

## What Gets Backed Up

### Critical Data (MUST backup)

1. **Service Configurations** (`${CONFIG_ROOT}`)
   - Traefik configuration and ACME certificates
   - Authelia users, policies, and database
   - Media service configs (Sonarr, Radarr, Prowlarr, Jellyfin, etc.)
   - Homepage dashboard configuration
   - ~500MB-2GB depending on services

2. **Environment Files** (`env/.env.*`)
   - All secrets (API keys, passwords, tokens)
   - Service URLs and configuration
   - **CRITICAL**: Without these, services won't start
   - ~10KB total

3. **Nextcloud Data** (`${CLOUD_ROOT}`)
   - Database files (PostgreSQL data)
   - Nextcloud app configuration
   - **User data excluded by default** (too large - backup separately)
   - ~1-5GB (without user files)

4. **Grafana Dashboards** (`${MONITORING_ROOT}/grafana`)
   - Custom dashboards
   - User preferences and settings
   - Datasource configurations
   - ~100-500MB

### Excluded from Backup (Too Large or Rebuildable)

1. **Media Library** - Your actual movies/TV shows (backup separately to NAS/cloud)
2. **Prometheus Metrics** - Historical data (can be rebuilt)
3. **Loki Logs** - Log history (can be rebuilt)
4. **Docker Images** - Can be re-pulled
5. **Nextcloud User Files** - Backup separately with dedicated tool

## Automated Backup

### Using the Backup Script

The included backup script handles everything:

```bash
# Run manual backup
sudo ./scripts/backup.sh

# Or via orionctl
sudo ./scripts/orionctl.sh backup
```

**What it does:**
1. Stops Nextcloud temporarily (for database consistency)
2. Copies all critical configs and data
3. Creates manifest file
4. Compresses to `.tar.gz`
5. Stores in `/srv/orion-sentinel-core/backups/`
6. Keeps last 7 backups (configurable)
7. Restarts Nextcloud

**Output:**
```
/srv/orion-sentinel-core/backups/orion-backup-20251123-140530.tar.gz
```

### Automated Daily Backups

Set up a cron job for daily backups:

```bash
# Edit crontab
sudo crontab -e

# Add daily backup at 3 AM
0 3 * * * /srv/orion-sentinel-core/Orion-Sentinel-CoreSrv/scripts/backup.sh >> /var/log/orion-backup.log 2>&1
```

### Backup to Remote Location

**Option 1: rsync to NAS**

```bash
# After backup completes, sync to NAS
rsync -avz --delete \
  /srv/orion-sentinel-core/backups/ \
  user@nas:/volume1/backups/orion-coresrv/
```

**Option 2: rclone to Cloud (Encrypted)**

```bash
# Install rclone
curl https://rclone.org/install.sh | sudo bash

# Configure remote (e.g., Google Drive, B2, S3)
rclone config

# Sync backups (encrypted)
rclone sync \
  /srv/orion-sentinel-core/backups/ \
  remote:orion-backups/ \
  --crypt-password="your-encryption-password"
```

**Option 3: Restic (Recommended)**

```bash
# Install restic
sudo apt install restic

# Initialize repo (one time)
restic -r /mnt/nas/orion-backups init

# Backup
restic -r /mnt/nas/orion-backups backup \
  /srv/orion-sentinel-core/backups/

# To cloud (B2, S3, etc.)
export RESTIC_REPOSITORY="b2:bucket-name:orion-backups"
export RESTIC_PASSWORD="your-encryption-password"
export B2_ACCOUNT_ID="your-b2-account-id"
export B2_ACCOUNT_KEY="your-b2-application-key"

restic backup /srv/orion-sentinel-core/backups/
```

## Manual Backup (Step-by-Step)

If you need to backup manually without the script:

```bash
# 1. Create backup directory
sudo mkdir -p /srv/orion-sentinel-core/backups
cd /srv/orion-sentinel-core/backups

# 2. Stop Nextcloud (for consistency)
docker compose stop nextcloud nextcloud-db

# 3. Create timestamped backup
TIMESTAMP=$(date +%Y%m%d-%H%M%S)
sudo tar -czf orion-backup-${TIMESTAMP}.tar.gz \
  ../config \
  ../cloud \
  ../monitoring/grafana \
  ../Orion-Sentinel-CoreSrv/env/.env.*

# 4. Restart Nextcloud
docker compose start nextcloud nextcloud-db

# 5. Verify backup
tar -tzf orion-backup-${TIMESTAMP}.tar.gz | head -20
```

## Restore Procedure

### Full System Restore (New Server)

If CoreSrv disk died and you're starting from scratch:

#### Step 1: Prepare New Server

```bash
# Install Ubuntu Server 24.04 LTS
# Set hostname: coresrv
# Configure network with same IP as old server

# Update system
sudo apt update && sudo apt upgrade -y

# Install Docker
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
newgrp docker

# Install Docker Compose
sudo apt install docker-compose-plugin

# Create directory structure
sudo mkdir -p /srv/orion-sentinel-core
sudo chown -R $USER:$USER /srv/orion-sentinel-core
```

#### Step 2: Restore Repository

```bash
cd /srv/orion-sentinel-core

# Clone repo
git clone https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv
```

#### Step 3: Restore from Backup

```bash
# Copy backup to server (from NAS, cloud, or USB)
# Example: scp from another machine
scp user@backup-server:/backups/orion-backup-20251123-140530.tar.gz /tmp/

# Extract backup
cd /srv/orion-sentinel-core
sudo tar -xzf /tmp/orion-backup-20251123-140530.tar.gz --strip-components=1

# Verify extracted files
ls -la config/ env/ cloud/ monitoring/
```

#### Step 4: Verify Environment Files

```bash
cd /srv/orion-sentinel-core/Orion-Sentinel-CoreSrv

# Check that .env files exist
ls -la env/.env.*

# If missing, restore from backup or recreate from .example files
```

#### Step 5: Start Services

```bash
# Start in phases to verify
./scripts/orionctl.sh up-core

# Verify core works
curl -k https://auth.local
curl -k https://traefik.local

# Start monitoring
./scripts/orionctl.sh up-monitoring

# Verify Grafana
curl http://localhost:3000/api/health

# Start everything
./scripts/orionctl.sh up-full
```

#### Step 6: Verify Services

```bash
# Check all containers
docker compose ps

# Check service health
./scripts/orionctl.sh health

# Verify in browser
# - https://auth.local → Authelia login
# - https://jellyfin.local → Jellyfin
# - https://grafana.local → Grafana with dashboards
```

### Partial Restore (Specific Service)

To restore just one service config:

```bash
# Example: Restore Sonarr config only
cd /tmp
tar -xzf /path/to/orion-backup-20251123-140530.tar.gz \
  orion-backup-20251123-140530/config/sonarr

# Copy to config directory
sudo cp -r orion-backup-20251123-140530/config/sonarr \
  /srv/orion-sentinel-core/config/

# Restart Sonarr
docker compose restart sonarr
```

### Restore from Cloud Backup

**Using Restic:**

```bash
# List available snapshots
restic -r /mnt/nas/orion-backups snapshots

# Restore latest
restic -r /mnt/nas/orion-backups restore latest \
  --target /srv/orion-sentinel-core-restore

# Or restore specific snapshot
restic -r /mnt/nas/orion-backups restore abc123 \
  --target /srv/orion-sentinel-core-restore
```

**Using rclone:**

```bash
# Download from cloud
rclone copy remote:orion-backups/ /tmp/orion-backups/

# Extract latest
LATEST=$(ls -t /tmp/orion-backups/*.tar.gz | head -1)
tar -xzf $LATEST -C /srv/orion-sentinel-core/
```

## Testing Backups

**Test backups regularly!** A backup you haven't tested is not a backup.

### Quick Test (Every Month)

```bash
# 1. Extract backup to temp location
mkdir -p /tmp/backup-test
cd /tmp/backup-test
tar -xzf /srv/orion-sentinel-core/backups/orion-backup-*.tar.gz

# 2. Verify critical files exist
test -f orion-backup-*/env/.env.core && echo "✓ .env.core exists"
test -d orion-backup-*/config/authelia && echo "✓ Authelia config exists"
test -d orion-backup-*/config/sonarr && echo "✓ Sonarr config exists"

# 3. Verify backup is recent
BACKUP_AGE=$(find /srv/orion-sentinel-core/backups/ -name "*.tar.gz" -mtime -1 | wc -l)
if [ $BACKUP_AGE -gt 0 ]; then
    echo "✓ Backup is recent (< 24 hours old)"
else
    echo "✗ WARNING: No recent backup found!"
fi

# 4. Cleanup
rm -rf /tmp/backup-test
```

### Full Restore Test (Every 6 Months)

1. Spin up a test VM or spare machine
2. Follow full restore procedure above
3. Verify all services start and work
4. Test login to Authelia, Grafana, Jellyfin
5. Verify data integrity (Sonarr shows all series, etc.)

## Disaster Recovery Checklist

If CoreSrv dies completely:

- [ ] Boot from USB installer (Ubuntu Server 24.04 LTS)
- [ ] Install OS with same hostname and IP
- [ ] Install Docker and Docker Compose
- [ ] Create directory structure (`/srv/orion-sentinel-core`)
- [ ] Clone Git repository
- [ ] Download backup from remote location
- [ ] Extract backup
- [ ] Verify `.env` files are present
- [ ] Start services with `orionctl.sh up-full`
- [ ] Verify Authelia login works
- [ ] Verify media services (Sonarr, Radarr, Jellyfin)
- [ ] Verify monitoring (Grafana dashboards)
- [ ] Verify Nextcloud (if used)
- [ ] Update DNS if IP changed
- [ ] Update Pi nodes' Promtail configs if IP changed

**Estimated recovery time:** 2-4 hours (depending on download speed)

## Backup Best Practices

### The 3-2-1 Rule

- **3** copies of data (original + 2 backups)
- **2** different types of media (local disk + cloud)
- **1** offsite backup (cloud or remote location)

### Recommended Strategy

1. **Local backups** (fast restore)
   - Daily automated backups to `/srv/orion-sentinel-core/backups/`
   - Keep last 7 days

2. **NAS backups** (same network)
   - Daily rsync to NAS
   - Keep last 30 days

3. **Cloud backups** (offsite)
   - Weekly upload to cloud (Backblaze B2, AWS S3, etc.)
   - Keep last 12 weeks
   - **Encrypt before upload!**

### Monitoring Backups

Add to monitoring/Uptime Kuma:

- Monitor: Backup file age
- Alert if backup > 25 hours old
- Alert if backup directory size changes dramatically

### Encryption

Always encrypt backups before sending offsite:

```bash
# Encrypt backup
gpg --symmetric --cipher-algo AES256 orion-backup-20251123-140530.tar.gz

# Decrypt
gpg --decrypt orion-backup-20251123-140530.tar.gz.gpg > orion-backup.tar.gz
```

## What About Media Files?

Your actual media library (movies, TV shows) should be backed up **separately**:

**Options:**
1. **RAID** on CoreSrv (RAID 1 or RAID 5 for redundancy)
2. **Separate NAS** with snapshots (Synology, TrueNAS, etc.)
3. **Cloud storage** (Backblaze B2, Wasabi, AWS S3 Glacier)
4. **External USB drives** (monthly full backup)

**Don't rely on the media staying on CoreSrv!** Hard drives fail.

## Troubleshooting Restore

### Services Won't Start After Restore

```bash
# Check permissions
sudo chown -R 1000:1000 /srv/orion-sentinel-core/config
sudo chown -R 1000:1000 /srv/orion-sentinel-core/cloud

# Check .env files
ls -la env/.env.*

# Check Docker networks
docker network ls | grep orion

# Recreate networks if missing
docker compose up --no-start
```

### Authelia Database Corrupt

```bash
# Remove database, will be recreated
rm /srv/orion-sentinel-core/config/authelia/db.sqlite3

# Restart Authelia
docker compose restart authelia

# Reconfigure users in users.yml
```

### Nextcloud Won't Start

```bash
# Check database permissions
sudo chown -R 999:999 /srv/orion-sentinel-core/cloud/db

# Check logs
docker compose logs nextcloud-db
docker compose logs nextcloud

# If database corrupt, restore from backup
```

## Summary

- **Backup daily** with automated script
- **Test restores** monthly (quick) and every 6 months (full)
- **Store offsite** (cloud/NAS) with encryption
- **Document changes** that affect restore (new secrets, config changes)
- **Keep this guide accessible** (print it or store offline)

**Remember:** The best backup is the one you actually test!

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
