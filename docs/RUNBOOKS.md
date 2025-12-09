# Runbooks: Common Issues & Solutions

## Overview

Quick reference guide for diagnosing and fixing common issues with Orion-Sentinel-CoreSrv.

**When to use this:** It's 2 AM, something's broken, and you need to fix it fast.

---

## Quick Diagnostics

### Overall Health Check

```bash
# Check all services
./scripts/orionctl.sh status

# Quick health test
./scripts/orionctl.sh health

# View recent logs
./scripts/orionctl.sh logs --tail 50
```

### Common Quick Fixes

**"Have you tried turning it off and on again?"**

```bash
# Restart specific service
docker compose restart <service>

# Restart everything
./scripts/orionctl.sh down
./scripts/orionctl.sh up-full
```

---

## Runbook 1: Cannot Access Any Service (Traefik Down)

### Symptoms
- All `*.local` URLs return connection refused or timeout
- `https://auth.local`, `https://jellyfin.local`, etc. all broken
- Direct container ports work (e.g., `http://coresrv:8096` for Jellyfin)

### Diagnosis

```bash
# Check if Traefik is running
docker compose ps traefik

# Check Traefik logs
docker compose logs traefik --tail 100

# Check if ports are bound
sudo netstat -tulpn | grep :80
sudo netstat -tulpn | grep :443
```

### Common Causes & Fixes

**1. Traefik Container Not Running**

```bash
# Check status
docker compose ps traefik
# If exited/unhealthy:

# View why it stopped
docker compose logs traefik

# Restart
docker compose up -d traefik

# If it keeps crashing, check config
docker compose exec traefik cat /etc/traefik/traefik.yml
```

**2. Port Conflict (Another Service Using 80/443)**

```bash
# Check what's using port 80
sudo lsof -i :80

# Common culprits: Apache, nginx, other reverse proxy
# Stop conflicting service:
sudo systemctl stop apache2
sudo systemctl stop nginx

# Restart Traefik
docker compose restart traefik
```

**3. Docker Socket Permission Issue**

```bash
# Check socket permissions
ls -la /var/run/docker.sock

# Fix permissions
sudo chmod 666 /var/run/docker.sock

# Restart Traefik
docker compose restart traefik
```

**4. Traefik Config Syntax Error**

```bash
# Validate config
docker compose config

# Check Traefik static config
cat core/traefik/traefik.yml

# Check dynamic config
cat core/traefik/dynamic/authelia.yml

# If errors, fix and restart
docker compose restart traefik
```

---

## Runbook 2: SSO Broken (Can't Login to Authelia)

### Symptoms
- `https://auth.local` loads but login fails
- Correct password rejected
- Redirect loop after login
- "Invalid credentials" error

### Diagnosis

```bash
# Check Authelia status
docker compose ps authelia

# Check Authelia logs
docker compose logs authelia --tail 100

# Test Authelia health
curl http://localhost:9091/api/health
```

### Common Causes & Fixes

**1. Authelia Container Not Running**

```bash
# Start Authelia
docker compose up -d authelia

# If it keeps crashing, check logs
docker compose logs authelia
```

**2. Wrong Password**

```bash
# Reset admin password
# Generate new hash
docker run --rm -it authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'NewPassword123'

# Update users.yml
nano core/authelia/users.yml

# Paste new hash for your user
# Restart Authelia
docker compose restart authelia
```

**3. Database Corruption**

```bash
# Backup current database
cp /srv/orion-sentinel-core/config/authelia/db.sqlite3 \
   /srv/orion-sentinel-core/config/authelia/db.sqlite3.bak

# Remove and recreate
rm /srv/orion-sentinel-core/config/authelia/db.sqlite3

# Restart Authelia (will create new DB)
docker compose restart authelia

# Reconfigure users and test
```

**4. Secrets Not Set**

```bash
# Check .env.core has secrets
grep AUTHELIA env/.env.core

# If missing or "changeme":
nano env/.env.core

# Generate new secrets
openssl rand -hex 32    # JWT_SECRET
openssl rand -hex 32    # SESSION_SECRET
openssl rand -hex 32    # STORAGE_KEY

# Restart Authelia
docker compose restart authelia
```

**5. Bypass Authelia Temporarily (Emergency)**

To access services without SSO:

```bash
# Edit service labels in compose.yml
# Comment out Authelia middleware
nano compose.yml

# Find service (e.g., Grafana):
# - "traefik.http.routers.grafana.middlewares=authelia-forwardauth@file"
# Change to:
# # - "traefik.http.routers.grafana.middlewares=authelia-forwardauth@file"

# Restart service
docker compose up -d grafana

# Access directly (no SSO)
# https://grafana.local

# REMEMBER TO RE-ENABLE SSO AFTER FIXING!
```

---

## Runbook 3: Media Services Broken (No Streaming)

### Symptoms
- Jellyfin won't play media
- Sonarr/Radarr not downloading
- qBittorrent not connecting
- Prowlarr not finding torrents

### Diagnosis

```bash
# Check media services status
docker compose ps jellyfin sonarr radarr qbittorrent vpn prowlarr

# Check VPN status (critical for qBit)
docker compose logs vpn --tail 50

# Check qBittorrent through VPN
docker compose logs qbittorrent --tail 50

# Test VPN connection
docker compose exec vpn curl ifconfig.me
# Should show VPN IP, not your real IP
```

### Common Causes & Fixes

**1. VPN Container Down (qBittorrent Unreachable)**

```bash
# Check VPN status
docker compose ps vpn

# View VPN logs
docker compose logs vpn

# Common issue: Wrong credentials
nano env/.env.media
# Check: VPN_WIREGUARD_PRIVATE_KEY

# Restart VPN and qBit
docker compose restart vpn
# qBittorrent will restart automatically (network_mode: service:vpn)
```

**2. qBittorrent Web UI Not Accessible**

```bash
# qBittorrent runs through VPN container
# Check VPN exposes port 8080
docker compose ps vpn

# Check Traefik can reach qBit
docker compose logs traefik | grep qbit

# Test directly via VPN container
curl http://localhost:8080
# Should return qBittorrent web UI HTML

# If not working, restart both
docker compose restart vpn
sleep 5
docker compose restart qbittorrent
```

**3. Jellyfin Can't Find Media**

```bash
# Check media library volume
docker compose exec jellyfin ls -la /media

# Should show movies/ and tv/ directories
# If empty, check volume mount in compose.yml

# Check permissions
ls -la /srv/orion-sentinel-core/media/library/

# Fix permissions if needed
sudo chown -R 1000:1000 /srv/orion-sentinel-core/media/library/

# Restart Jellyfin
docker compose restart jellyfin

# Scan library
# In Jellyfin UI: Dashboard → Libraries → Scan All Libraries
```

**4. Sonarr/Radarr Can't Download**

```bash
# Check if Sonarr can reach qBittorrent
docker compose exec sonarr curl http://vpn:8080
# Should return qBittorrent page

# Check Prowlarr connection
docker compose logs prowlarr | grep -i error

# Check download path permissions
ls -la /srv/orion-sentinel-core/media/torrents/

# Fix permissions
sudo chown -R 1000:1000 /srv/orion-sentinel-core/media/torrents/

# Restart media stack
docker compose restart sonarr radarr prowlarr
```

**5. Jellyseerr Can't Request Media**

```bash
# Check Jellyseerr can reach Sonarr/Radarr
docker compose exec jellyseerr curl http://sonarr:8989
docker compose exec jellyseerr curl http://radarr:7878

# Check API keys in .env.media
grep -E "SONARR_API_KEY|RADARR_API_KEY" env/.env.media

# Verify in Sonarr/Radarr web UI:
# Settings → General → Security → API Key

# Update API keys and restart
docker compose restart jellyseerr
```

---

## Runbook 4: Logs Missing (Loki/Promtail Issues)

### Symptoms
- No logs appear in Grafana Explore
- Promtail not shipping logs
- Loki not receiving data
- Pi nodes not sending logs to CoreSrv

### Diagnosis

```bash
# Check Loki status
docker compose ps loki

# Check Loki health
curl http://localhost:3100/ready
# Should return: ready

# Check Promtail status
docker compose ps promtail

# Check Promtail is tailing files
docker compose logs promtail | grep -i "successfully"

# Check if Loki has data
curl http://localhost:3100/loki/api/v1/label
# Should return JSON with labels
```

### Common Causes & Fixes

**1. Loki Container Not Running**

```bash
# Start Loki
docker compose up -d loki

# Check logs for errors
docker compose logs loki --tail 100

# Common issue: Permission denied on /loki directory
sudo chown -R 10001:10001 /srv/orion-sentinel-core/monitoring/loki/
docker compose restart loki
```

**2. Promtail Can't Reach Docker Logs**

```bash
# Check Promtail has access to Docker socket
docker compose exec promtail ls -la /var/run/docker.sock

# Check Promtail config
docker compose exec promtail cat /etc/promtail/config.yml

# Restart Promtail
docker compose restart promtail

# Verify it's shipping
docker compose logs promtail | tail -50
```

**3. Grafana Can't Query Loki**

```bash
# In Grafana UI:
# Configuration → Data Sources → Loki → Test

# If failing, check Loki URL
# Should be: http://loki:3100

# Check Grafana can reach Loki
docker compose exec grafana curl http://loki:3100/ready

# If not, check networks
docker network inspect orion_internal
docker network inspect orion_monitoring
```

**4. Pi Nodes Not Sending Logs**

```bash
# On Pi node:
ssh pi@pi-dns  # or pi-netsec

# Check Promtail running
docker ps | grep promtail

# Check Promtail logs
docker logs promtail --tail 50

# Test CoreSrv Loki reachability
curl http://<coresrv-ip>:3100/ready

# If failing:
# - Check firewall on CoreSrv
# - Check Loki port published (3100:3100 in compose.yml)
# - Check Promtail config has correct CoreSrv IP
```

---

## Runbook 5: Monitoring Down (Grafana/Prometheus Issues)

### Symptoms
- Grafana dashboard blank or "No data"
- Prometheus not scraping targets
- Metrics missing
- Alerts not firing

### Diagnosis

```bash
# Check monitoring services
docker compose ps prometheus grafana loki

# Check Prometheus targets
curl http://localhost:9090/api/v1/targets | jq
# Or visit: http://localhost:9090/targets

# Check Grafana health
curl http://localhost:3000/api/health
```

### Common Causes & Fixes

**1. Prometheus Not Scraping**

```bash
# Check Prometheus config
cat monitoring/prometheus/prometheus.yml

# Check Prometheus logs
docker compose logs prometheus --tail 100

# Restart Prometheus
docker compose restart prometheus

# Verify targets in UI
# http://localhost:9090/targets
# All should show "UP"
```

**2. Grafana Shows "No Data"**

```bash
# Check Grafana datasources
curl -u admin:password http://localhost:3000/api/datasources

# In Grafana UI:
# Configuration → Data Sources → Prometheus → Test
# Should show: "Data source is working"

# If failing, check Prometheus URL
# Should be: http://prometheus:9090

# Test connection
docker compose exec grafana curl http://prometheus:9090/-/healthy
```

**3. Dashboards Not Loading**

```bash
# Check Grafana provisioning
docker compose exec grafana ls -la /etc/grafana/provisioning/

# Check dashboard files
ls -la /srv/orion-sentinel-core/monitoring/grafana/dashboards/orion/

# Restart Grafana to re-provision
docker compose restart grafana
```

---

## Runbook 6: High Resource Usage

### Symptoms
- CoreSrv running slow
- High CPU/RAM usage
- Disk space filling up
- Services crashing due to OOM

### Diagnosis

```bash
# Check system resources
htop  # or top

# Check Docker resource usage
docker stats

# Check disk space
df -h /srv/orion-sentinel-core/

# Find large files
du -sh /srv/orion-sentinel-core/* | sort -h
```

### Common Causes & Fixes

**1. Loki/Prometheus Data Too Large**

```bash
# Check Loki data size
du -sh /srv/orion-sentinel-core/monitoring/loki/

# Check Prometheus data size
du -sh /srv/orion-sentinel-core/monitoring/prometheus/

# Reduce retention
nano monitoring/loki/config.yml
# Set: retention_period: 72h  # 3 days instead of 7

nano monitoring/prometheus/prometheus.yml
# Or set in compose.yml: --storage.tsdb.retention.time=7d

# Restart services
docker compose restart loki prometheus
```

**2. Docker Images Taking Up Space**

```bash
# Check Docker disk usage
docker system df

# Clean up unused images
docker image prune -a

# Clean up unused volumes
docker volume prune

# Clean up build cache
docker builder prune
```

**3. Log Files Growing**

```bash
# Check Docker container logs
du -sh /var/lib/docker/containers/*/*-json.log | sort -h | tail -10

# Configure log rotation
sudo nano /etc/docker/daemon.json

# Add:
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  }
}

# Restart Docker
sudo systemctl restart docker

# Restart containers
./scripts/orionctl.sh down
./scripts/orionctl.sh up-full
```

**4. qBittorrent Downloads Filling Disk**

```bash
# Check torrent downloads
du -sh /srv/orion-sentinel-core/media/torrents/

# Clean up completed/old torrents
# In qBittorrent UI or via Sonarr/Radarr cleanup
```

---

## Emergency Procedures

### Complete System Recovery

If everything is broken:

```bash
# 1. Stop all services
./scripts/orionctl.sh down

# 2. Backup current state (just in case)
sudo tar -czf /tmp/emergency-backup.tar.gz /srv/orion-sentinel-core/config

# 3. Restore from last known good backup
# See: docs/BACKUP-RESTORE.md

# 4. Start services incrementally
./scripts/orionctl.sh up-core
# Test, then:
./scripts/orionctl.sh up-observability
# Test, then:
./scripts/orionctl.sh up-full
```

### Factory Reset (Nuclear Option)

**WARNING: This deletes everything!**

```bash
# 1. Backup first!
./scripts/backup.sh

# 2. Stop all containers
docker compose down -v  # -v removes volumes too

# 3. Remove all data
sudo rm -rf /srv/orion-sentinel-core/config/*
sudo rm -rf /srv/orion-sentinel-core/monitoring/*
sudo rm -rf /srv/orion-sentinel-core/cloud/*

# 4. Recreate .env files from examples
cp env/.env.core.example env/.env.core
# Edit and add secrets...

# 5. Start fresh
./scripts/orionctl.sh up-full
```

---

## Getting Help

### Log Collection for Support

```bash
# Collect all relevant logs
mkdir -p /tmp/orion-logs

docker compose logs > /tmp/orion-logs/all-services.log
docker compose ps > /tmp/orion-logs/service-status.txt
docker stats --no-stream > /tmp/orion-logs/resource-usage.txt

# Create archive
tar -czf orion-logs-$(date +%Y%m%d-%H%M%S).tar.gz -C /tmp orion-logs/

# Share this archive when asking for help
```


---

## Runbook: Homepage Dashboard Issues

### Symptoms
- Homepage not loading or showing blank page
- Services not appearing in dashboard
- Unable to access at http://localhost:3003

### Diagnosis

```bash
# Check if Homepage is running
docker compose -f compose/docker-compose.extras.yml ps homepage

# Check logs
docker compose -f compose/docker-compose.extras.yml logs homepage --tail 100

# Check config files
ls -la /srv/orion-sentinel-core/maintenance/homepage/
```

### Common Causes & Fixes

**1. Configuration Files Missing**

```bash
# Homepage needs config files
cd /srv/orion-sentinel-core/maintenance/homepage

# Check for required files
ls -la settings.yml services.yml widgets.yml bookmarks.yml

# If missing, copy from examples
cp services.yml.example services.yml
cp settings.yml.example settings.yml
cp widgets.yml.example widgets.yml
cp bookmarks.yml.example bookmarks.yml

# Restart Homepage
docker compose -f compose/docker-compose.extras.yml restart homepage
```

**2. Docker Socket Permission Issue**

```bash
# Homepage needs access to Docker socket
ls -la /var/run/docker.sock

# Fix permissions if needed
sudo chmod 666 /var/run/docker.sock

# Restart
docker compose -f compose/docker-compose.extras.yml restart homepage
```

**3. Service Not Detected**

```bash
# Homepage discovers services via Docker labels
# Check if services have correct labels
docker inspect <service-name> | grep -A 10 "Labels"

# Verify networks
docker network inspect orion_backbone_net
docker network inspect orion_proxy_net
```

---

## Runbook: Mealie (Recipe Manager) Issues

### Symptoms
- Cannot access Mealie at http://localhost:9000
- Login fails or database errors
- Recipes not saving

### Diagnosis

```bash
# Check if Mealie is running
docker compose -f compose/docker-compose.homeauto.yml ps mealie

# Check logs
docker compose -f compose/docker-compose.homeauto.yml logs mealie --tail 100

# Check database
docker compose -f compose/docker-compose.homeauto.yml exec mealie ls -la /app/data
```

### Common Causes & Fixes

**1. Database Not Initialized**

```bash
# First time setup requires database initialization
# Check if database exists
ls -la /srv/orion-sentinel-core/home-automation/mealie/

# Create directory if missing
sudo mkdir -p /srv/orion-sentinel-core/home-automation/mealie
sudo chown -R $USER:$USER /srv/orion-sentinel-core/home-automation/mealie

# Restart to initialize
docker compose -f compose/docker-compose.homeauto.yml restart mealie

# Wait 30 seconds, then check logs
sleep 30
docker compose -f compose/docker-compose.homeauto.yml logs mealie
```

**2. Permission Issues**

```bash
# Check ownership
ls -la /srv/orion-sentinel-core/home-automation/mealie/

# Fix permissions
sudo chown -R $PUID:$PGID /srv/orion-sentinel-core/home-automation/mealie

# Restart
docker compose -f compose/docker-compose.homeauto.yml restart mealie
```

**3. Cannot Create Admin User**

```bash
# Reset and create new admin
docker compose -f compose/docker-compose.homeauto.yml down mealie

# Remove database (WARNING: deletes all data!)
# Backup first if you have data
sudo mv /srv/orion-sentinel-core/home-automation/mealie/mealie.db \
       /srv/orion-sentinel-core/home-automation/mealie/mealie.db.backup

# Restart
docker compose -f compose/docker-compose.homeauto.yml up -d mealie

# Access web UI and create admin user
```

---

## Runbook: SearXNG (Search Engine) Issues

### Symptoms
- SearXNG not accessible at http://localhost:8888
- Search results not loading
- Some search engines not working

### Diagnosis

```bash
# Check if SearXNG is running
docker compose -f compose/docker-compose.extras.yml ps searxng

# Check logs
docker compose -f compose/docker-compose.extras.yml logs searxng --tail 100

# Check configuration
docker compose -f compose/docker-compose.extras.yml exec searxng cat /etc/searxng/settings.yml
```

### Common Causes & Fixes

**1. Settings File Issues**

```bash
# SearXNG needs valid settings.yml
cd /srv/orion-sentinel-core/search/searxng

# Check if settings exists
ls -la settings.yml

# If corrupted or missing, use default
docker compose -f compose/docker-compose.extras.yml down searxng
rm settings.yml
# SearXNG will generate default on next start
docker compose -f compose/docker-compose.extras.yml up -d searxng
```

**2. Network/DNS Issues**

```bash
# SearXNG needs internet access to search
# Test from container
docker compose -f compose/docker-compose.extras.yml exec searxng ping -c 3 google.com

# If ping fails, check Docker DNS
docker compose -f compose/docker-compose.extras.yml exec searxng cat /etc/resolv.conf

# Restart with DNS override
docker compose -f compose/docker-compose.extras.yml down searxng
# Add to compose file under searxng service:
#   dns:
#     - 8.8.8.8
#     - 8.8.4.4
docker compose -f compose/docker-compose.extras.yml up -d searxng
```

**3. Rate Limiting / Blocked by Search Engines**

```bash
# Some search engines may block or rate-limit
# Check logs for specific errors
docker compose -f compose/docker-compose.extras.yml logs searxng | grep -i "error\|block\|limit"

# Edit settings to disable problematic engines
nano /srv/orion-sentinel-core/search/searxng/settings.yml
# Under 'engines:', disable failing ones

# Restart
docker compose -f compose/docker-compose.extras.yml restart searxng
```

**4. Permission Issues**

```bash
# Check directory permissions
ls -la /srv/orion-sentinel-core/search/searxng/

# Fix ownership
sudo chown -R $PUID:$PGID /srv/orion-sentinel-core/search/searxng

# Restart
docker compose -f compose/docker-compose.extras.yml restart searxng
```

---

### Useful Commands Reference

```bash
# Service management
./scripts/orionctl.sh status
./scripts/orionctl.sh health
./scripts/orionctl.sh logs [service]
./scripts/orionctl.sh restart [service]

# Makefile commands (recommended)
make status              # Check all services
make logs SVC=homepage   # Check specific service logs
make restart SVC=mealie  # Restart specific service
make health              # Health check all services

# Docker
docker compose ps
docker compose logs [service] --tail 100
docker compose exec [service] bash
docker stats

# System
df -h
free -h
htop
netstat -tulpn
```

---

**Last Updated:** 2025-01-09  
**Maintained By:** Orion Home Lab Team

**Remember:** When in doubt, check the logs first!
