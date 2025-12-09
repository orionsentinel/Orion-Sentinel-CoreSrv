# Update Guide

This guide explains how to keep your Orion-Sentinel-CoreSrv stack up to date with the latest Docker images, security patches, and features.

## Table of Contents

- [Update Strategy](#update-strategy)
- [Manual Updates](#manual-updates)
- [Automated Updates](#automated-updates)
- [Service-Specific Updates](#service-specific-updates)
- [Rollback Procedures](#rollback-procedures)
- [Security Updates](#security-updates)

## Update Strategy

Orion-Sentinel-CoreSrv uses **pinned image versions** for stability and reproducibility. Images are specified with version tags (not `:latest`) to ensure consistent deployments.

### Recommended Update Schedule

- **Security patches**: Immediately (within 24-48 hours)
- **Minor updates**: Monthly
- **Major updates**: Quarterly (with testing)
- **Configuration review**: Quarterly

## Manual Updates

### 1. Check for Updates

Review the latest image versions on Docker Hub or GitHub releases:

```bash
# Media stack
# - Jellyfin: https://hub.docker.com/r/jellyfin/jellyfin
# - Sonarr: https://hub.docker.com/r/linuxserver/sonarr
# - Radarr: https://hub.docker.com/r/linuxserver/radarr
# - Prowlarr: https://hub.docker.com/r/linuxserver/prowlarr
# - qBittorrent: https://hub.docker.com/r/linuxserver/qbittorrent

# Gateway stack
# - Traefik: https://hub.docker.com/_/traefik
# - Authelia: https://hub.docker.com/r/authelia/authelia

# Monitoring stack
# - Prometheus: https://hub.docker.com/r/prom/prometheus
# - Grafana: https://hub.docker.com/r/grafana/grafana
# - Loki: https://hub.docker.com/r/grafana/loki
```

### 2. Update Compose Files

Edit the relevant compose file and update image tags:

```bash
# Example: Update Jellyfin
nano compose/docker-compose.media.yml

# Change:
# image: jellyfin/jellyfin:10.8.13
# To:
# image: jellyfin/jellyfin:10.9.0
```

### 3. Pull New Images

```bash
# Pull all images for a specific stack
make pull

# Or pull for specific compose file
docker compose -f compose/docker-compose.media.yml pull
docker compose -f compose/docker-compose.gateway.yml pull
docker compose -f compose/docker-compose.observability.yml pull
docker compose -f compose/docker-compose.homeauto.yml pull
```

### 4. Backup Before Updating

**Always backup before updating:**

```bash
# Backup all critical volumes
sudo ./backup/backup-volumes.sh manual

# Or backup specific service
sudo ./backup/backup-volumes.sh manual jellyfin
```

### 5. Update Services

```bash
# Update entire stack
make down
make up-all

# Or update specific module
docker compose -f compose/docker-compose.media.yml down
docker compose -f compose/docker-compose.media.yml up -d

# Or update single service
docker compose -f compose/docker-compose.media.yml up -d --force-recreate jellyfin
```

### 6. Verify Updates

```bash
# Check running containers
make ps

# Check service health
make health

# View logs
make logs SVC=jellyfin

# Test service access
curl -f http://localhost:8096  # Jellyfin
curl -f http://localhost:9090  # Prometheus
```

## Automated Updates

You have two options for automated updates:

### Option 1: Watchtower (Recommended for Home Labs)

Watchtower automatically updates running containers when new images are available.

**Enable Watchtower:**

1. Add to `compose/docker-compose.observability.yml`:

```yaml
watchtower:
  image: containrrr/watchtower:1.7.1
  container_name: orion_watchtower
  restart: unless-stopped
  environment:
    - WATCHTOWER_CLEANUP=true
    - WATCHTOWER_SCHEDULE=0 0 4 * * *  # 4 AM daily
    - WATCHTOWER_ROLLING_RESTART=true
    - WATCHTOWER_INCLUDE_STOPPED=false
    - WATCHTOWER_REVIVE_STOPPED=false
    - TZ=${TZ:-UTC}
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock
  networks:
    - orion_observability_net
```

2. Start Watchtower:

```bash
docker compose -f compose/docker-compose.observability.yml up -d watchtower
```

**Watchtower Configuration:**

- Updates daily at 4 AM
- Removes old images after update
- Rolling restart (one service at a time)
- Only updates running containers

**Exclude services from auto-update:**

Add label to services you want to exclude:

```yaml
labels:
  - "com.centurylinklabs.watchtower.enable=false"
```

### Option 2: Manual with Reminders

If you prefer manual control, set up a monthly reminder:

**Create reminder script:**

```bash
#!/bin/bash
# /usr/local/bin/orion-update-reminder.sh

cat << EOF | mail -s "Orion-Sentinel Monthly Update Reminder" your@email.com
It's time for monthly Orion-Sentinel updates!

Steps:
1. Check for new image versions
2. Backup critical services: sudo /path/to/backup/backup-volumes.sh monthly
3. Update compose files with new versions
4. Pull and restart: make pull && make down && make up-all
5. Verify all services: make health

See docs/update.md for detailed instructions.
EOF
```

**Add to crontab:**

```bash
sudo crontab -e

# Add:
0 9 1 * * /usr/local/bin/orion-update-reminder.sh
```

## Service-Specific Updates

### Updating Jellyfin

```bash
# 1. Backup
sudo ./backup/backup-volumes.sh manual jellyfin

# 2. Update image version in compose file
nano compose/docker-compose.media.yml

# 3. Pull and restart
docker compose -f compose/docker-compose.media.yml pull jellyfin
docker compose -f compose/docker-compose.media.yml up -d --force-recreate jellyfin

# 4. Verify
docker compose -f compose/docker-compose.media.yml logs -f jellyfin
curl -f http://localhost:8096
```

### Updating Traefik

```bash
# 1. Backup (includes certificates)
sudo ./backup/backup-volumes.sh manual traefik

# 2. Update image version
nano compose/docker-compose.gateway.yml

# 3. Pull and restart (brief downtime)
docker compose -f compose/docker-compose.gateway.yml pull traefik
docker compose -f compose/docker-compose.gateway.yml up -d --force-recreate traefik

# 4. Verify HTTPS still works
curl -k https://localhost
```

### Updating Grafana

```bash
# 1. Backup (includes dashboards)
sudo ./backup/backup-volumes.sh manual grafana

# 2. Update image version
nano compose/docker-compose.observability.yml

# 3. Pull and restart
docker compose -f compose/docker-compose.observability.yml pull grafana
docker compose -f compose/docker-compose.observability.yml up -d --force-recreate grafana

# 4. Verify dashboards
curl -f http://localhost:3000
```

### Updating Home Assistant

```bash
# 1. Backup (includes automations and config)
sudo ./backup/backup-volumes.sh manual homeassistant

# 2. Update image version
nano compose/docker-compose.homeauto.yml

# 3. Pull and restart
docker compose -f compose/docker-compose.homeauto.yml pull homeassistant
docker compose -f compose/docker-compose.homeauto.yml up -d --force-recreate homeassistant

# 4. Verify and check for breaking changes
docker compose -f compose/docker-compose.homeauto.yml logs -f homeassistant
```

## Rollback Procedures

If an update causes issues, you can rollback:

### Method 1: Revert Image Version

```bash
# 1. Edit compose file and change back to old version
nano compose/docker-compose.media.yml

# 2. Pull old image (if still available)
docker compose -f compose/docker-compose.media.yml pull jellyfin

# 3. Restart with old image
docker compose -f compose/docker-compose.media.yml up -d --force-recreate jellyfin
```

### Method 2: Restore from Backup

```bash
# 1. Stop service
docker compose -f compose/docker-compose.media.yml stop jellyfin

# 2. Restore from backup
sudo ./backup/restore-volume.sh manual 2024-12-09 jellyfin

# 3. Start service
docker compose -f compose/docker-compose.media.yml start jellyfin

# 4. Verify
docker compose -f compose/docker-compose.media.yml logs -f jellyfin
```

## Security Updates

### Checking for Security Vulnerabilities

```bash
# Scan images for vulnerabilities (using Trivy)
docker run --rm -v /var/run/docker.sock:/var/run/docker.sock \
  aquasec/trivy:latest image jellyfin/jellyfin:10.8.13

# Or use Docker Scout (if available)
docker scout cves jellyfin/jellyfin:10.8.13
```

### Responding to Security Advisories

1. **Assess severity**: Check CVE database and vendor announcements
2. **Test update**: Update in development/staging first if possible
3. **Backup**: Always backup before security updates
4. **Update immediately**: For critical vulnerabilities (CVSS >= 7.0)
5. **Verify**: Ensure patch is applied and vulnerability is resolved

### Security Update Workflow

```bash
# 1. Check for security updates
# Subscribe to:
# - GitHub security advisories for each project
# - Docker Hub automated vulnerability scanning
# - LinuxServer.io Discord/announcements

# 2. Backup affected service
sudo ./backup/backup-volumes.sh manual <service>

# 3. Update immediately
nano compose/docker-compose.<module>.yml  # Update version
docker compose -f compose/docker-compose.<module>.yml pull <service>
docker compose -f compose/docker-compose.<module>.yml up -d --force-recreate <service>

# 4. Verify and monitor
docker compose -f compose/docker-compose.<module>.yml logs -f <service>
make health
```

## Image Version Pinning Strategy

### Current Strategy: Version Tags

All images use specific version tags (e.g., `10.8.13`, `v2.10.5`) rather than `:latest`.

**Benefits:**
- ✓ Reproducible deployments
- ✓ Controlled updates
- ✓ Easier rollback
- ✓ No surprise breaking changes

**Example:**
```yaml
# Good: Pinned version
image: jellyfin/jellyfin:10.8.13

# Avoid: Latest tag
image: jellyfin/jellyfin:latest
```

### Advanced: Digest Pinning

For maximum reproducibility, pin to image digests:

```yaml
# Pin to specific digest
image: jellyfin/jellyfin:10.8.13@sha256:abc123def456...

# This ensures the EXACT image is used, even if tags are moved
```

Get digest:
```bash
docker inspect jellyfin/jellyfin:10.8.13 | grep -A1 RepoDigests
```

## Update Checklist

Use this checklist for each update cycle:

- [ ] Review release notes for all services
- [ ] Check for breaking changes
- [ ] Backup all critical services (`sudo ./backup/backup-volumes.sh monthly`)
- [ ] Update image versions in compose files
- [ ] Pull new images (`make pull`)
- [ ] Test in development (if available)
- [ ] Stop services (`make down`)
- [ ] Start services with new images (`make up-all`)
- [ ] Verify all services are healthy (`make health`)
- [ ] Check logs for errors (`make logs`)
- [ ] Test critical functionality (web UIs, API endpoints)
- [ ] Monitor for 24-48 hours
- [ ] Document any issues or changes
- [ ] Clean up old images (`docker system prune -a`)

## Monitoring Updates

### Subscribe to Release Notifications

**GitHub:**
- Watch repositories → Custom → Releases only

**Docker Hub:**
- Enable email notifications for image updates

**RSS Feeds:**
- Add release RSS feeds to your reader

### Automated Update Checking

**diun (Docker Image Update Notifier):**

```yaml
# Add to compose/docker-compose.observability.yml
diun:
  image: crazymax/diun:latest
  container_name: orion_diun
  restart: unless-stopped
  environment:
    - TZ=${TZ:-UTC}
    - DIUN_WATCH_SCHEDULE=0 0 8 * * *  # Check at 8 AM daily
    - DIUN_NOTIF_MAIL_HOST=smtp.gmail.com
    - DIUN_NOTIF_MAIL_PORT=587
    - DIUN_NOTIF_MAIL_FROM=your@email.com
    - DIUN_NOTIF_MAIL_TO=your@email.com
  volumes:
    - /var/run/docker.sock:/var/run/docker.sock:ro
    - ./monitoring/diun:/data
```

## Best Practices

1. **Always backup before updating**
2. **Read release notes and changelogs**
3. **Update one service at a time for critical services**
4. **Monitor logs after updates**
5. **Keep old images for 7 days before cleaning up**
6. **Test updates in non-production environment when possible**
7. **Update during low-traffic hours**
8. **Have rollback plan ready**
9. **Document all changes**
10. **Keep stack configuration in git for version control**

## Getting Help

If you encounter issues during updates:

1. Check the service logs: `make logs SVC=<service>`
2. Review GitHub issues for the service
3. Check Docker Hub comments
4. Search LinuxServer.io forums
5. Restore from backup if needed

## Related Documentation

- [backup/README.md](../backup/README.md) - Backup procedures
- [docs/BACKUP-RESTORE.md](BACKUP-RESTORE.md) - Detailed backup/restore guide
- [README.md](../README.md) - Main documentation
