# Nextcloud - Self-Hosted Cloud Storage

## Overview

Nextcloud is a self-hosted productivity platform that provides file sync and share, calendar, contacts, and collaboration tools - your own private Dropbox/Google Drive alternative.

**Services:**
- **nextcloud** - Main Nextcloud application (Apache + PHP)
- **nextcloud-db** - PostgreSQL database
- **nextcloud-redis** - Redis for caching and file locking
- **nextcloud-cron** - Background job processor

## Quick Start

### 1. Configure Environment

Copy the example environment file and set your credentials:

```bash
cd stacks/cloud/nextcloud
cp .env.example .env
nano .env  # Change admin password, database password, and Redis password
```

**Required variables:**
- `NEXTCLOUD_ADMIN_PASSWORD` - Strong admin password
- `NEXTCLOUD_DB_PASSWORD` - Strong database password
- `NEXTCLOUD_REDIS_PASSWORD` - Redis password

Generate secure passwords:
```bash
openssl rand -base64 32
```

### 2. Start the Stack

```bash
# From repository root
./scripts/orionctl up cloud --profile cloud

# Or using Docker Compose directly
docker compose --profile cloud up -d
```

### 3. Initial Setup

1. Navigate to **https://cloud.orion.lan** (or your configured domain)
2. Wait for initial setup to complete (1-2 minutes)
3. Login with admin credentials from `.env`
4. Complete the setup wizard

**Note**: The admin account is created automatically on first run using environment variables.

## Features

### Core Capabilities
- **File Sync & Share** - Access files from any device
- **Calendar & Contacts** - CalDAV/CardDAV sync
- **Collaborative Editing** - Documents, spreadsheets, presentations
- **Photo Management** - Automatic photo uploads and galleries
- **Mobile Apps** - iOS and Android clients
- **Desktop Sync** - Windows, macOS, Linux clients
- **WebDAV Access** - Mount as network drive

### Security Features
- End-to-end encryption
- Two-factor authentication
- Brute-force protection
- Server-side encryption
- Activity monitoring

## Client Setup

### Desktop Sync Client

**Download:** https://nextcloud.com/install/#install-clients

**Configuration:**
1. Install Nextcloud Desktop Client
2. Server URL: `https://cloud.orion.lan`
3. Enter your Nextcloud credentials
4. Choose folders to sync

### Mobile Apps

**iOS:** https://apps.apple.com/app/nextcloud/id1125420102  
**Android:** https://play.google.com/store/apps/details?id=com.nextcloud.client

**Features:**
- Auto-upload photos and videos
- Offline file access
- Share files via link
- Calendar and contacts sync

### WebDAV Access

Mount Nextcloud as a network drive:

**WebDAV URL:**
```
https://cloud.orion.lan/remote.php/dav/files/USERNAME/
```

**Linux (davfs2):**
```bash
sudo apt install davfs2
sudo mount -t davfs https://cloud.orion.lan/remote.php/dav/files/admin/ /mnt/nextcloud
```

**macOS:**
```
Finder → Go → Connect to Server
Server Address: https://cloud.orion.lan/remote.php/dav/files/USERNAME/
```

**Windows:**
```
Map Network Drive → Use WebDAV URL
```

## Configuration

### Recommended Apps to Enable

After initial login, install these apps from the App Store:

**Productivity:**
- Calendar - Schedule and task management
- Contacts - Contact management with CardDAV
- Tasks - Todo lists
- Deck - Kanban-style project management

**Collaboration:**
- Talk - Video/audio calls and chat
- Collabora Online or OnlyOffice - Office document editing

**Media:**
- Photos - Photo management and timeline view
- Music - Music player and library

**Security:**
- Two-Factor TOTP Provider - 2FA with authenticator apps
- Brute-force settings - Additional login protection

### Email Configuration

To enable email notifications and password resets:

1. Go to **Settings → Administration → Basic Settings**
2. Configure SMTP settings:
   - **Send mode:** SMTP
   - **Encryption:** SSL/TLS
   - **From address:** nextcloud@yourdomain.com
   - **Server:** smtp.gmail.com (or your SMTP server)
   - **Port:** 587 (STARTTLS) or 465 (SSL)
   - **Authentication:** Yes
   - **Credentials:** Your email username and password

3. Click **Send email** to test

### Two-Factor Authentication

Enable 2FA for all admin accounts:

1. Install **Two-Factor TOTP Provider** app
2. Go to **Settings → Security**
3. Click **Enable TOTP**
4. Scan QR code with authenticator app (Google Authenticator, Authy, etc.)
5. Enter verification code

### Trusted Domains

If you need to access Nextcloud from additional domains or IPs, add them to config:

```bash
# Method 1: Edit config.php directly
docker exec -it orion_nextcloud vi /var/www/html/config/config.php

# Method 2: Use occ command
docker exec -u www-data orion_nextcloud php occ config:system:set trusted_domains 2 --value=192.168.1.100
```

### Large File Uploads

Default upload limit is 10GB. To increase:

1. Edit `.env`:
   ```bash
   NEXTCLOUD_PHP_UPLOAD_LIMIT=50G
   ```

2. Restart Nextcloud:
   ```bash
   docker compose --profile cloud restart nextcloud
   ```

3. If using Traefik, also check proxy settings for body size limits

### External Storage (Optional)

Link to media library without duplicating files:

1. Enable **External storage support** app
2. Go to **Settings → Administration → External Storage**
3. Add Local storage:
   - Folder name: `Media`
   - Configuration: `/media` (mount your media directory)
   - Available for: Your user or groups
4. Click checkmark to save

## Performance Tuning

### Memory Configuration

For deployments with many users or large files:

Edit `.env`:
```bash
NEXTCLOUD_PHP_MEMORY_LIMIT=1G
```

Restart:
```bash
docker compose --profile cloud restart nextcloud
```

### Background Jobs

Nextcloud uses a dedicated cron container for background tasks:
- File indexing
- Activity email notifications
- File cleanup
- App updates

**Runs every 5 minutes automatically** - no configuration needed.

To check cron status:
```bash
docker compose --profile cloud logs nextcloud-cron
```

### Redis Caching

Redis is already configured and provides:
- File locking (prevents data corruption with concurrent access)
- Distributed caching (faster page loads)
- Session storage

**No additional configuration needed** - enabled by default.

## Backup

### What to Backup

**Critical data:**
1. Nextcloud data directory: `/srv/orion/internal/nextcloud-data/`
2. Nextcloud app directory: `/srv/orion/internal/appdata/nextcloud/`
3. Database: `/srv/orion/internal/db/nextcloud/`

### Backup Procedure

#### Option 1: Full Backup (Recommended)

```bash
# Stop services for consistent backup
docker compose --profile cloud stop nextcloud nextcloud-cron

# Backup everything
sudo tar -czf nextcloud-backup-$(date +%Y%m%d).tar.gz \
  /srv/orion/internal/nextcloud-data/ \
  /srv/orion/internal/appdata/nextcloud/ \
  /srv/orion/internal/db/nextcloud/

# Restart services
docker compose --profile cloud start nextcloud nextcloud-cron
```

#### Option 2: Live Backup with pg_dump

```bash
# Backup database (can run while Nextcloud is running)
docker exec orion_nextcloud_db pg_dump -U nextcloud nextcloud \
  > nextcloud-db-$(date +%Y%m%d).sql

# Backup data and config
sudo tar -czf nextcloud-data-$(date +%Y%m%d).tar.gz \
  /srv/orion/internal/nextcloud-data/ \
  /srv/orion/internal/appdata/nextcloud/config/
```

### Restore Procedure

1. Stop services:
   ```bash
   docker compose --profile cloud down
   ```

2. Restore files:
   ```bash
   sudo tar -xzf nextcloud-backup.tar.gz -C /
   ```

3. Start database first:
   ```bash
   docker compose --profile cloud up -d nextcloud-db
   ```

4. If using SQL dump, restore database:
   ```bash
   docker exec -i orion_nextcloud_db psql -U nextcloud nextcloud < nextcloud-db.sql
   ```

5. Start all services:
   ```bash
   docker compose --profile cloud up -d
   ```

## Troubleshooting

### Cannot Access Nextcloud

```bash
# Check service status
docker compose --profile cloud ps

# Check logs
docker compose --profile cloud logs nextcloud
docker compose --profile cloud logs nextcloud-db

# Verify Traefik routing
docker logs orion_traefik | grep nextcloud
```

### Database Connection Errors

```bash
# Check database is running
docker compose --profile cloud ps nextcloud-db

# Test database connection
docker exec orion_nextcloud_db psql -U nextcloud -c '\l'

# Check credentials match in .env and database
```

### "Trusted Domain" Error

Add your domain/IP to trusted domains:

```bash
docker exec -u www-data orion_nextcloud php occ config:system:set trusted_domains 2 --value=your-domain-or-ip
```

### File Upload Fails

1. Check upload limit in `.env` (`NEXTCLOUD_PHP_UPLOAD_LIMIT`)
2. Check available disk space:
   ```bash
   df -h /srv/orion/internal
   ```
3. Check Nextcloud logs:
   ```bash
   docker compose --profile cloud logs nextcloud | tail -100
   ```

### Redis Connection Issues

```bash
# Check Redis is running
docker compose --profile cloud ps nextcloud-redis

# Check Redis password matches in .env
docker exec orion_nextcloud_redis redis-cli -a ${NEXTCLOUD_REDIS_PASSWORD} PING
```

### Cron Jobs Not Running

```bash
# Check cron container logs
docker compose --profile cloud logs nextcloud-cron

# Manually trigger cron
docker exec -u www-data orion_nextcloud php cron.php
```

## Maintenance

### OCC Command Line Tool

Nextcloud provides the `occ` command for administration:

```bash
# Run occ commands as www-data user
docker exec -u www-data orion_nextcloud php occ <command>

# Examples:
docker exec -u www-data orion_nextcloud php occ status
docker exec -u www-data orion_nextcloud php occ app:list
docker exec -u www-data orion_nextcloud php occ user:list
docker exec -u www-data orion_nextcloud php occ files:scan --all
docker exec -u www-data orion_nextcloud php occ maintenance:mode --on
```

### Updates

To update Nextcloud to the latest version:

```bash
# Pull latest image
docker compose --profile cloud pull nextcloud

# Recreate containers
docker compose --profile cloud up -d

# Check logs for any upgrade steps
docker compose --profile cloud logs -f nextcloud
```

**Important:**
- Always backup before updating
- Major version upgrades may require manual steps
- Check Nextcloud release notes
- Updates happen automatically in the container

### Database Maintenance

Optimize database periodically:

```bash
# Add missing indices
docker exec -u www-data orion_nextcloud php occ db:add-missing-indices

# Convert filecache to big int (for large installations)
docker exec -u www-data orion_nextcloud php occ db:convert-filecache-bigint
```

## Security Best Practices

1. **Use Strong Passwords**
   - Admin: 20+ characters
   - Database: 32+ characters
   - User accounts: enforce via policy

2. **Enable Two-Factor Authentication**
   - Required for all admin accounts
   - Recommended for all users

3. **Regular Updates**
   - Update monthly for security patches
   - Always backup before updating
   - Test in non-production first if possible

4. **Monitor Access**
   - Review audit logs in Settings → Logging
   - Check for suspicious login attempts
   - Review user activity regularly

5. **Limit External Access**
   - Use VPN for remote access
   - Consider Traefik forward authentication
   - Use firewall rules if exposing to internet

6. **Regular Backups**
   - Daily automated backups
   - Test restore procedure quarterly
   - Store backups off-site

## Resources

- **Official Documentation**: https://docs.nextcloud.com/
- **Admin Manual**: https://docs.nextcloud.com/server/latest/admin_manual/
- **User Manual**: https://docs.nextcloud.com/server/latest/user_manual/
- **Apps**: https://apps.nextcloud.com/
- **Desktop Clients**: https://nextcloud.com/install/#install-clients
- **Community Forum**: https://help.nextcloud.com/
- **GitHub**: https://github.com/nextcloud/server

---

**Stack Profile**: `cloud`  
**Required in compose.yaml**: Add `- path: stacks/cloud/nextcloud/compose.yml` to include section  
**Maintained by**: Orion Home Lab Team
