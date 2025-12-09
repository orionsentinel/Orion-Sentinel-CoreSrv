# Update Guide

This guide covers how to update Orion Sentinel CoreSrv components safely.

## Table of Contents

- [Quick Update Workflow](#quick-update-workflow)
- [Update Strategy](#update-strategy)
- [Updating Docker Images](#updating-docker-images)
- [Updating Repository Code](#updating-repository-code)
- [Version Pinning](#version-pinning)
- [Rollback Procedures](#rollback-procedures)
- [Security Updates](#security-updates)
- [Automated Updates](#automated-updates)

## Quick Update Workflow

For most updates, follow this simple workflow:

```bash
# 1. Backup first!
sudo ./backup/backup-volumes.sh

# 2. Pull latest images
make pull

# 3. Restart services
make down
make up-full

# 4. Verify everything works
make health
make logs
```

## Update Strategy

Orion Sentinel CoreSrv uses **version pinning** to ensure stability. Updates are manual and deliberate.

### Philosophy

- ✅ **Stability over bleeding edge** - Pin to specific versions
- ✅ **Test before deploy** - Review changelogs, test in dev if possible
- ✅ **Backup before update** - Always have a rollback plan
- ✅ **Update regularly** - Don't fall too far behind (security!)
- ⚠️ **No auto-updates by default** - Unless explicitly enabled (Watchtower)

### Update Frequency

**Recommended schedule:**

- **Security patches** - As soon as available (especially core services)
- **Minor updates** - Monthly review
- **Major updates** - Quarterly review, test carefully

## Updating Docker Images

### Check for Updates

```bash
# See current versions
docker compose -f compose/docker-compose.media.yml images
docker compose -f compose/docker-compose.gateway.yml images
docker compose -f compose/docker-compose.observability.yml images
docker compose -f compose/docker-compose.homeauto.yml images

# Check for newer versions on Docker Hub
# Visit: https://hub.docker.com/
```

### Update a Single Service

**Example: Updating Jellyfin**

1. **Check release notes**: https://github.com/jellyfin/jellyfin/releases

2. **Edit compose file**:
   ```bash
   nano compose/docker-compose.media.yml
   ```
   
   Change:
   ```yaml
   jellyfin:
     image: jellyfin/jellyfin:10.8.13
   ```
   
   To:
   ```yaml
   jellyfin:
     image: jellyfin/jellyfin:10.9.0  # New version
   ```

3. **Backup before update**:
   ```bash
   sudo ./backup/backup-volumes.sh
   ```

4. **Pull new image and restart**:
   ```bash
   docker compose -f compose/docker-compose.media.yml pull jellyfin
   docker compose -f compose/docker-compose.media.yml up -d jellyfin
   ```

5. **Verify**:
   ```bash
   make logs SVC=jellyfin
   # Check Jellyfin web UI
   ```

6. **If problems occur**, rollback (see [Rollback Procedures](#rollback-procedures))

### Update All Services

**WARNING:** Only do this if you've reviewed all changelogs!

```bash
# 1. Backup everything
sudo ./backup/backup-volumes.sh

# 2. Review what will be updated
make pull  # Shows which images will be updated

# 3. Update compose files to new versions
# Edit each compose/*.yml file with new version tags

# 4. Pull and restart
make down
make pull
make up-full

# 5. Monitor for issues
make health
make logs
```

## Updating Repository Code

When the Orion Sentinel repository itself is updated:

### Standard Update

```bash
cd /path/to/Orion-Sentinel-CoreSrv

# 1. Backup current config
sudo ./backup/backup-volumes.sh

# 2. Stash any local changes
git stash

# 3. Pull latest code
git pull origin main

# 4. Review changes
git log --oneline -10
cat CHANGELOG.md  # If exists

# 5. Update dependencies (if needed)
# Check if new .env variables are needed
diff .env.example .env

# 6. Restart if needed
make down
make up-full
```

### Handling Merge Conflicts

If you have local customizations:

```bash
# Pull updates
git pull origin main
# If conflicts:
#   ERROR: merge conflict in ...

# Resolve conflicts manually
nano <conflicted-file>
# Fix conflicts, then:
git add <conflicted-file>
git commit -m "Merged upstream changes"
```

### Applying New Features

If the repository adds new services or features:

```bash
# 1. Pull latest code
git pull origin main

# 2. Check for new env files
ls env/.env.*.example

# 3. Copy new env files if needed
cp env/.env.newservice.example env/.env.newservice

# 4. Review and edit new env file
nano env/.env.newservice

# 5. Deploy new service
make up-<service>
```

## Version Pinning

### Why Pin Versions?

- ✅ **Predictable behavior** - Know exactly what you're running
- ✅ **Avoid breaking changes** - Update on your schedule
- ✅ **Easy rollback** - Just use old version tag
- ✅ **Reproducible deployments** - Same version everywhere

### How to Pin Versions

All services should use specific version tags, never `latest`:

**Good:**
```yaml
jellyfin:
  image: jellyfin/jellyfin:10.8.13
```

**Bad:**
```yaml
jellyfin:
  image: jellyfin/jellyfin:latest  # Don't do this!
```

### Version Tag Formats

Different projects use different formats:

- **Semantic versioning**: `10.8.13`, `v2.11.0`
- **Date-based**: `2024.1.0`, `20240109`
- **SHA digests** (most stable):
  ```yaml
  # Full SHA256 digest for maximum stability
  image: jellyfin/jellyfin:10.8.13@sha256:1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef
  ```

### Current Versions Reference

Track current versions in a file for easy reference:

```bash
# Create versions.txt
cat > versions.txt << 'EOF'
# Orion Sentinel CoreSrv - Image Versions
# Last updated: 2025-01-09

# Media Stack
jellyfin: 10.8.13
sonarr: 4.0.0
radarr: 5.2.6
prowlarr: 1.11.4
qbittorrent: 4.6.2
jellyseerr: 1.7.0

# Gateway
traefik: v2.11
authelia: 4.37
redis: 7-alpine

# Monitoring
prometheus: v2.48
grafana: 10.2.3
loki: 2.9.3
uptime-kuma: 1.23.11

# Home Automation
homeassistant: 2024.1.0
mosquitto: 2.0
zigbee2mqtt: 1.35.1
mealie: v1.12.0
EOF
```

## Rollback Procedures

### Quick Rollback (Same Day)

If an update just failed:

```bash
# 1. Stop services
make down

# 2. Restore from today's backup
sudo ./backup/restore-volume.sh <service> $(date +%Y%m%d)

# 3. Revert image version in compose file
nano compose/docker-compose.<module>.yml
# Change image tag back to old version

# 4. Restart
make up-<module>
```

### Full Rollback (Older Backup)

If you discover problems days later:

```bash
# 1. Identify last known good backup date
ls -lh /srv/backups/orion/

# 2. Stop all services
make down

# 3. Restore all affected services
sudo ./backup/restore-volume.sh core-traefik 20250101
sudo ./backup/restore-volume.sh media-jellyfin 20250101
# ... etc

# 4. Revert compose files to old versions
git log --oneline compose/
git checkout <commit-hash> -- compose/

# 5. Restart
make up-full
```

### Emergency Rollback (Git)

If repository update broke everything:

```bash
# Find last working commit
git log --oneline

# Reset to that commit
git reset --hard <commit-hash>

# Restore from backup
sudo ./backup/restore-volume.sh core-traefik 20250101
# ... restore other services

# Restart
make up-full
```

## Security Updates

### Critical Security Updates

For CVEs and critical security issues:

1. **Assess urgency** - Check CVSS score, exploit availability
2. **Backup immediately** - `sudo ./backup/backup-volumes.sh`
3. **Update affected service** - Follow single service update above
4. **Test critical functionality** - Don't just check if it starts
5. **Monitor logs** - Watch for issues for 24-48 hours

### Security Scanning

Regularly scan for vulnerabilities:

```bash
# Scan compose files for known issues
docker scout cves compose/docker-compose.media.yml

# Scan running containers
docker scout cves <container-name>

# Check GitHub Security Advisories
# Visit: https://github.com/advisories
```

### Security Checklist

Before deploying security updates:

- [ ] Read CVE details and impact
- [ ] Check if your configuration is affected
- [ ] Backup affected services
- [ ] Review release notes for breaking changes
- [ ] Update and test in dev if possible
- [ ] Deploy to production
- [ ] Monitor for 24-48 hours
- [ ] Document what was updated and why

## Automated Updates

### Option 1: Watchtower (Automatic)

**WARNING:** Can break things! Use carefully.

Enable Watchtower for automatic updates:

```yaml
# Add to compose/docker-compose.extras.yml
watchtower:
  image: containrrr/watchtower:latest
  container_name: orion_watchtower
  restart: unless-stopped
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
  environment:
    - WATCHTOWER_SCHEDULE=0 0 4 * * *  # 4 AM daily
    - WATCHTOWER_CLEANUP=true
    - WATCHTOWER_INCLUDE_STOPPED=false
    - WATCHTOWER_NOTIFICATIONS=email
    - WATCHTOWER_NOTIFICATION_EMAIL_TO=your@email.com
    # Only update specific containers
    - WATCHTOWER_MONITOR_ONLY=false
  command: jellyfin sonarr radarr  # Only these
```

**Pros:**
- ✅ Always up-to-date
- ✅ Automatic security patches

**Cons:**
- ⚠️ Breaking changes applied automatically
- ⚠️ No manual review
- ⚠️ Can break production

### Option 2: DIUN (Notification Only)

Recommended: Get notified but update manually.

```yaml
# Add to compose/docker-compose.extras.yml
diun:
  image: crazymax/diun:latest
  container_name: orion_diun
  restart: unless-stopped
  volumes:
    - ./maintenance/diun:/data
    - /var/run/docker.sock:/var/run/docker.sock
  environment:
    - DIUN_WATCH_SCHEDULE=0 0 8 * * *  # 8 AM daily
    - DIUN_PROVIDERS_DOCKER=true
    - DIUN_NOTIF_MAIL_HOST=smtp.gmail.com
    - DIUN_NOTIF_MAIL_TO=your@email.com
```

### Option 3: Manual Cron Reminder (Recommended)

Set up a monthly reminder to check for updates:

```bash
# Add to crontab (crontab -e)
0 9 1 * * echo "Reminder: Check for Orion Sentinel updates (make pull)" | mail -s "Orion Update Check" your@email.com
```

## Best Practices

### Before Every Update

- [ ] Read release notes and changelog
- [ ] Check for breaking changes
- [ ] Backup affected services
- [ ] Note current versions (in case of rollback)
- [ ] Plan rollback strategy

### During Update

- [ ] Update one service at a time (when possible)
- [ ] Monitor logs during/after update
- [ ] Test critical functionality
- [ ] Keep terminal session open (in case immediate rollback needed)

### After Update

- [ ] Verify all services healthy: `make health`
- [ ] Check logs for errors: `make logs`
- [ ] Test user-facing functionality
- [ ] Monitor for 24-48 hours
- [ ] Document what was updated
- [ ] Update version tracking file

### Monthly Update Routine

Recommended monthly workflow:

```bash
# 1st of each month
# 1. Check for updates
make pull  # See what's available

# 2. Review release notes
# Visit GitHub releases for each service

# 3. Backup
sudo ./backup/backup-volumes.sh

# 4. Update repository
git pull origin main

# 5. Update images (if reviewed)
# Edit compose files with new versions
make down
make pull
make up-full

# 6. Verify
make health
make logs

# 7. Monitor for a week
# Check logs daily
```

## Troubleshooting

### Update Fails to Apply

```bash
# Check for port conflicts
sudo netstat -tulpn | grep <port>

# Check for permission issues
ls -la /srv/orion-sentinel-core/

# Check Docker daemon
systemctl status docker
```

### Service Won't Start After Update

```bash
# Check logs
make logs SVC=<service>

# Check compose file syntax
docker compose -f compose/docker-compose.<module>.yml config

# Rollback
git checkout HEAD~1 -- compose/docker-compose.<module>.yml
make restart SVC=<service>
```

### Database Migration Issues

Some updates require database migrations:

```bash
# Check service documentation
# Usually automatic, but may need manual intervention

# Example: Home Assistant
docker exec -it orion_homeassistant bash
# Check logs inside container
```

## See Also

- [backup/README.md](../backup/README.md) - Backup and restore procedures
- [docs/RUNBOOKS.md](../docs/RUNBOOKS.md) - Operational procedures
- [docs/SECURITY-HARDENING.md](../docs/SECURITY-HARDENING.md) - Security best practices
- [README.md](../README.md) - Main documentation
