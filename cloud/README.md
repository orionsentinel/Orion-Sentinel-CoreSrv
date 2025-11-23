# Cloud Stack: Nextcloud + PostgreSQL

## Overview

The cloud stack provides self-hosted cloud storage and collaboration platform:

- **Nextcloud** - File sync, calendar, contacts, collaboration
- **PostgreSQL 16** - Database backend for Nextcloud

## What Lives Here

```
cloud/
├── nextcloud/           # Placeholder for custom Nextcloud config
│   └── .gitkeep
└── README.md            # This file
```

**Note:** Actual Nextcloud data stored at `/srv/orion-sentinel-core/cloud/`:
- `db/` - PostgreSQL database files
- `app/` - Nextcloud application files
- `data/` - User files and data

## Services

### Nextcloud

**Purpose:** Self-hosted cloud storage and productivity platform

**Key Features:**
- File sync and sharing (like Dropbox)
- Calendar and contacts (CalDAV/CardDAV)
- Collaborative document editing
- Photo management and galleries
- Mobile apps (iOS, Android)
- Desktop sync clients (Windows, macOS, Linux)
- Extensive app ecosystem

**Access:**
- Web UI: `https://cloud.local` (protected by Authelia)
- WebDAV: `https://cloud.local/remote.php/dav`

**Default Admin:**
- Username: Set in `.env.cloud` (`NEXTCLOUD_ADMIN_USER`)
- Password: Set in `.env.cloud` (`NEXTCLOUD_ADMIN_PASSWORD`)

### PostgreSQL

**Purpose:** Database backend for Nextcloud

**Configuration:**
- Version: PostgreSQL 16
- Database: `nextcloud`
- User: `nextcloud`
- Password: Set in `.env.cloud`

**Why PostgreSQL over SQLite/MySQL?**
- Better performance for larger deployments
- More reliable for concurrent users
- Better scaling characteristics
- Recommended by Nextcloud for production

## Initial Setup

### 1. Configure Environment

Edit `.env.cloud`:

```bash
# Set strong admin password
NEXTCLOUD_ADMIN_PASSWORD=your-strong-password-here

# Set strong database password
POSTGRES_PASSWORD=your-database-password-here

# Add your server's IP/hostname to trusted domains
NEXTCLOUD_TRUSTED_DOMAINS=cloud.local 192.168.1.100
```

### 2. Start Services

```bash
docker compose --profile cloud up -d
```

### 3. Initial Nextcloud Setup

1. Navigate to `https://cloud.local`
2. First visit will complete installation (may take 1-2 minutes)
3. Login with admin credentials from `.env.cloud`

### 4. Recommended Configuration

After first login:

#### A. Configure Trusted Domains

If not set correctly via environment variables:

1. Edit config.php in container or volume
2. Add trusted domains:

```php
'trusted_domains' =>
array (
  0 => 'cloud.local',
  1 => '192.168.1.100',
),
```

#### B. Configure Email (Optional)

For password resets and notifications:

1. Settings → Administration → Basic Settings
2. Email server settings (SMTP recommended)

#### C. Enable Apps

Recommended apps to enable:

- **Productivity:**
  - Calendar
  - Contacts
  - Tasks
  - Deck (Kanban boards)

- **Collaboration:**
  - Talk (chat and video calls)
  - Collabora Online or OnlyOffice (document editing)

- **Media:**
  - Photos (photo management)
  - Music (music player)

- **Security:**
  - Two-Factor TOTP Provider
  - Brute-force settings

#### D. Set Up External Storage (Optional)

Link to media library for streaming:

1. Enable "External storage support" app
2. Settings → Administration → External Storage
3. Add local storage: `/library` (from media stack)
4. Use for streaming media without duplicating files

## Desktop & Mobile Sync

### Desktop Clients

Download from: https://nextcloud.com/install/#install-clients

**Configuration:**
- Server: `https://cloud.local`
- Username/Password: Your Nextcloud credentials
- Local folder: Choose where to sync

### Mobile Apps

**Android:** https://play.google.com/store/apps/details?id=com.nextcloud.client
**iOS:** https://apps.apple.com/app/nextcloud/id1125420102

**Features:**
- Auto-upload photos/videos
- Offline access to files
- Share files via link
- Calendar/contacts sync

## WebDAV Access

Access files via WebDAV (for mounting as network drive):

**WebDAV URL:**
```
https://cloud.local/remote.php/dav/files/USERNAME/
```

**Mounting on Linux:**
```bash
sudo mount -t davfs https://cloud.local/remote.php/dav/files/admin/ /mnt/nextcloud
```

**Windows:** Map Network Drive → Use WebDAV URL

**macOS:** Finder → Go → Connect to Server → Use WebDAV URL

## Backup Strategy

### Critical Data

**Must backup:**
1. `/srv/orion-sentinel-core/cloud/data/` - User files
2. `/srv/orion-sentinel-core/cloud/db/` - Database (or use pg_dump)
3. `/srv/orion-sentinel-core/cloud/app/config/config.php` - Nextcloud config

### Backup Methods

#### Option 1: Filesystem Backup

```bash
# Stop containers
docker compose stop nextcloud nextcloud-db

# Backup
sudo tar -czf nextcloud-backup-$(date +%Y%m%d).tar.gz \
  /srv/orion-sentinel-core/cloud/

# Restart
docker compose start nextcloud nextcloud-db
```

#### Option 2: Database Dump (Better)

```bash
# Backup database (while running)
docker compose exec nextcloud-db pg_dump -U nextcloud nextcloud > nextcloud-db-$(date +%Y%m%d).sql

# Backup data directory
sudo tar -czf nextcloud-data-$(date +%Y%m%d).tar.gz \
  /srv/orion-sentinel-core/cloud/data/ \
  /srv/orion-sentinel-core/cloud/app/config/
```

#### Option 3: Automated with Restic/Borg

Set up automated encrypted backups (recommended for production).

### Restore Procedure

1. Restore files to `/srv/orion-sentinel-core/cloud/`
2. Start services: `docker compose --profile cloud up -d`
3. Restore database (if using pg_dump):
   ```bash
   docker compose exec -T nextcloud-db psql -U nextcloud nextcloud < nextcloud-db-backup.sql
   ```

## Performance Tuning

### PHP Memory Limit

If you have many users or large files, increase PHP memory:

In `.env.cloud`:
```bash
PHP_MEMORY_LIMIT=1024M  # Default: 512M
```

### Redis Cache (Optional)

For better performance with multiple users, add Redis:

Add to `compose.yml`:
```yaml
redis:
  image: redis:alpine
  networks:
    - orion_internal
  profiles:
    - cloud

nextcloud:
  environment:
    - REDIS_HOST=redis
```

Then configure in Nextcloud `config.php`:
```php
'memcache.distributed' => '\OC\Memcache\Redis',
'memcache.local' => '\OC\Memcache\APCu',
'memcache.locking' => '\OC\Memcache\Redis',
'redis' => [
  'host' => 'redis',
  'port' => 6379,
],
```

## Troubleshooting

### Cannot Access Nextcloud

```bash
# Check service status
docker compose ps nextcloud nextcloud-db

# Check logs
docker compose logs nextcloud
docker compose logs nextcloud-db

# Verify Traefik routing
docker compose logs traefik | grep nextcloud
```

### Database Connection Errors

```bash
# Check database is running
docker compose ps nextcloud-db

# Verify database credentials match in .env.cloud
docker compose exec nextcloud-db psql -U nextcloud -c '\l'

# Check database logs
docker compose logs nextcloud-db
```

### Trusted Domain Errors

Edit `config.php` directly:

```bash
docker compose exec nextcloud vi /var/www/html/config/config.php

# Or from host (if volume mounted)
sudo vi /srv/orion-sentinel-core/cloud/app/config/config.php
```

Add your domain/IP to `trusted_domains` array.

### File Upload Errors

Check PHP limits in `.env.cloud`:

```bash
PHP_UPLOAD_LIMIT=10G  # Adjust as needed
```

Restart Nextcloud:
```bash
docker compose restart nextcloud
```

## Security Considerations

### 1. Use Strong Passwords

- Admin password: 20+ characters, unique
- Database password: 32+ characters, generated
- User passwords: Enforce via Nextcloud settings

### 2. Enable Two-Factor Authentication

1. Install "Two-Factor TOTP Provider" app
2. Settings → Security → Enable 2FA
3. Scan QR code with authenticator app

### 3. Configure Brute-Force Protection

Nextcloud has built-in protection, but verify:

1. Settings → Administration → Security
2. Check "Brute-force settings"

### 4. Regular Updates

Nextcloud releases security updates frequently:

1. Enable "Nextcloud announcements" app for notifications
2. Update via web UI or Docker image updates
3. Always backup before updating

### 5. Monitor Access

Review access logs:

1. Settings → Administration → Logging
2. Check for suspicious login attempts
3. Review user activity

## TODO

- [ ] Complete initial Nextcloud setup
- [ ] Install recommended apps (Calendar, Contacts, Photos)
- [ ] Configure email server for notifications
- [ ] Set up desktop/mobile sync clients
- [ ] Configure automatic backups (daily)
- [ ] Enable Redis caching for performance
- [ ] Set up external storage link to media library
- [ ] Configure user quotas
- [ ] Enable and test 2FA
- [ ] Document restore procedure with test restore

## References

- Nextcloud Documentation: https://docs.nextcloud.com/
- Nextcloud Apps: https://apps.nextcloud.com/
- Desktop Clients: https://nextcloud.com/install/#install-clients
- Nextcloud Docker: https://github.com/nextcloud/docker
- PostgreSQL Documentation: https://www.postgresql.org/docs/

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
