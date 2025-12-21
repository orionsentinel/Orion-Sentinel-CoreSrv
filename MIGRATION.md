# Migration Guide: Monolithic to Split Architecture

This guide explains how to migrate from the monolithic Orion-Sentinel-CoreSrv setup to the new split architecture with HomeCore and DataAICore.

## Overview

The repository has been split into two independent deployment targets:

1. **Orion-Sentinel-HomeCore** (Raspberry Pi 5)
   - Home Assistant + home automation services
   - Mealie recipe management
   - MQTT, Zigbee, Node-RED, ESPHome (optional)

2. **Orion-Sentinel-DataAICore** (Dell Optiplex)
   - Nextcloud cloud storage
   - SearXNG intelligent search + local document indexing
   - Ollama + Open WebUI for local AI

## What Moved Where

### HomeCore (Raspberry Pi 5)
Services that moved to HomeCore:
- ✓ Home Assistant (from `stacks/home/stack.yaml`)
- ✓ Mosquitto MQTT (from `stacks/home/stack.yaml`)
- ✓ Zigbee2MQTT (from `stacks/home/stack.yaml`)
- ✓ Node-RED (new, optional)
- ✓ ESPHome (new, optional)
- ✓ Mealie (from `stacks/apps/stack.yaml`)

Data locations:
- Old: `/srv/orion/internal/appdata/`
- New: `/srv/homecore/`

### DataAICore (Dell Optiplex)
Services that moved to DataAICore:
- ✓ Nextcloud (from `stacks/cloud/nextcloud/compose.yml`)
- ✓ Nextcloud Postgres database
- ✓ Nextcloud Redis cache
- ✓ SearXNG (new)
- ✓ Meilisearch + local document indexing (new)
- ✓ Ollama + Open WebUI (new)

Data locations:
- Old: `/srv/orion/internal/appdata/nextcloud/`
- New: `/srv/dataaicore/nextcloud/`

### Not Migrated (Deprecated or Optional)
These services were NOT migrated and should be handled separately if needed:
- Media stack (Jellyfin, Sonarr, Radarr, etc.) - Keep on current system or migrate manually
- Traefik reverse proxy - Replaced with simpler setup (local-only by default, optional Caddy for public Nextcloud)
- Authelia SSO - Intentionally removed (not needed for split architecture)
- Monitoring stack (Prometheus, Grafana) - Keep on current system if needed
- Other services (Firefly, DSMR Reader, etc.) - Migrate manually if needed

## Pre-Migration Checklist

Before starting migration:

- [ ] **Backup everything** - Cannot stress this enough!
  ```bash
  # Backup old configuration and data
  sudo tar -czf ~/orion-backup-$(date +%Y%m%d).tar.gz \
    /srv/orion \
    ~/Orion-Sentinel-CoreSrv/.env \
    ~/Orion-Sentinel-CoreSrv/env/
  ```

- [ ] **Document current setup** - Note which services you're actually using
- [ ] **Test hardware** - Ensure Pi 5 and Optiplex are ready
- [ ] **Prepare storage** - SSD for Pi 5, sufficient storage for Optiplex
- [ ] **Network planning** - Static IPs or DHCP reservations for both systems

## Migration Steps

### Phase 1: Stop Old Services

⚠️ **This will cause downtime. Plan accordingly.**

```bash
# On your current server
cd ~/Orion-Sentinel-CoreSrv

# Stop all services
docker compose down

# Or stop specific stacks if keeping some running
./scripts/orionctl down home
./scripts/orionctl down cloud
./scripts/orionctl down apps
```

### Phase 2: Backup and Export Data

#### Home Assistant Data

```bash
# Backup Home Assistant
sudo tar -czf ~/homeassistant-backup.tar.gz \
  /srv/orion/internal/appdata/homeassistant

# Backup Zigbee2MQTT (if used)
sudo tar -czf ~/zigbee2mqtt-backup.tar.gz \
  /srv/orion/internal/appdata/zigbee2mqtt

# Backup Mosquitto (if used)
sudo tar -czf ~/mosquitto-backup.tar.gz \
  /srv/orion/internal/appdata/mosquitto

# Backup Mealie
sudo tar -czf ~/mealie-backup.tar.gz \
  /srv/orion/internal/appdata/mealie \
  /srv/orion/internal/db/mealie
```

#### Nextcloud Data

```bash
# Backup Nextcloud database
docker exec orion_nextcloud_db pg_dump -U nextcloud nextcloud | \
  gzip > ~/nextcloud-db-backup.sql.gz

# Backup Nextcloud data
sudo tar -czf ~/nextcloud-app-backup.tar.gz \
  /srv/orion/internal/appdata/nextcloud

# Backup Redis cache (optional, can rebuild)
sudo tar -czf ~/nextcloud-redis-backup.tar.gz \
  /srv/orion/internal/appdata/nextcloud-redis
```

### Phase 3: Setup HomeCore (Raspberry Pi 5)

#### 3.1 Install OS and Docker

Follow [Orion-Sentinel-HomeCore/INSTALL.md](Orion-Sentinel-HomeCore/INSTALL.md) steps 1-2.

#### 3.2 Clone and Setup

```bash
# On Raspberry Pi
cd ~
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv/Orion-Sentinel-HomeCore

# Run setup
./scripts/setup.sh
```

#### 3.3 Restore Data

Transfer backups to Pi 5, then restore:

```bash
# Home Assistant
sudo tar -xzf ~/homeassistant-backup.tar.gz -C /srv/homecore/homeassistant --strip-components=5

# Zigbee2MQTT (if used)
sudo tar -xzf ~/zigbee2mqtt-backup.tar.gz -C /srv/homecore/zigbee2mqtt --strip-components=5

# Mosquitto (if used)
sudo tar -xzf ~/mosquitto-backup.tar.gz -C /srv/homecore/mosquitto --strip-components=5

# Mealie
sudo tar -xzf ~/mealie-backup.tar.gz -C /srv/homecore/mealie --strip-components=5

# Set ownership
sudo chown -R 1000:1000 /srv/homecore
```

#### 3.4 Start Services

```bash
# Start Home Assistant
./scripts/orionctl.sh up

# Or with profiles
./scripts/orionctl.sh up mqtt zigbee mealie

# Verify
./scripts/orionctl.sh ps
```

#### 3.5 Verify HomeCore

- Access Home Assistant: `http://<PI_IP>:8123`
- Check automations still work
- Re-pair Zigbee devices if needed (Zigbee2MQTT database should have them)
- Verify MQTT connections

### Phase 4: Setup DataAICore (Dell Optiplex)

#### 4.1 Install OS and Docker

Follow [Orion-Sentinel-DataAICore/INSTALL.md](Orion-Sentinel-DataAICore/INSTALL.md) steps 1-2.

#### 4.2 Clone and Setup

```bash
# On Dell Optiplex
cd ~
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv/Orion-Sentinel-DataAICore

# Run setup
./scripts/setup.sh
```

#### 4.3 Restore Nextcloud Data

Transfer Nextcloud backups to Optiplex, then:

```bash
# Extract Nextcloud data
sudo tar -xzf ~/nextcloud-app-backup.tar.gz -C /srv/dataaicore/nextcloud/app --strip-components=5

# Set ownership
sudo chown -R www-data:www-data /srv/dataaicore/nextcloud/app
```

#### 4.4 Start Nextcloud

```bash
# Start Nextcloud stack
./scripts/orionctl.sh up nextcloud

# Wait for containers to be healthy
docker compose ps

# Restore database
gunzip < ~/nextcloud-db-backup.sql.gz | \
  docker exec -i orion_dataaicore_nextcloud_db psql -U nextcloud nextcloud
```

#### 4.5 Fix Nextcloud Configuration

```bash
# Update trusted domains
docker exec -it orion_dataaicore_nextcloud \
  php occ config:system:set trusted_domains 1 --value=<OPTIPLEX_IP>

# Clear cache
docker exec -it orion_dataaicore_nextcloud \
  php occ maintenance:mode --off

# Run database migrations
docker exec -it orion_dataaicore_nextcloud \
  php occ upgrade

# Restart Nextcloud
docker restart orion_dataaicore_nextcloud
```

#### 4.6 Verify Nextcloud

- Access: `http://<OPTIPLEX_IP>:8080`
- Log in with your credentials
- Check files are accessible
- Test sync from mobile app

#### 4.7 Setup New Services (Optional)

```bash
# Start search stack
./scripts/orionctl.sh up search

# Start LLM stack
./scripts/orionctl.sh up llm

# Pull an LLM model
docker exec -it orion_dataaicore_ollama ollama pull llama3.2:3b
```

### Phase 5: Post-Migration Tasks

#### Update DNS/DHCP

Update your network configuration:
- Raspberry Pi 5: Reserve IP for HomeCore (e.g., 192.168.1.50)
- Dell Optiplex: Reserve IP for DataAICore (e.g., 192.168.1.100)

#### Update Mobile Apps

- **Home Assistant app:** Update server URL to new Pi 5 IP
- **Nextcloud app:** Update server URL to new Optiplex IP

#### Update Integrations

If you had integrations between services:
- Update Home Assistant → Mealie URL (same Pi, still works locally)
- Update any external services pointing to Nextcloud

#### Decommission Old Server (Optional)

Once everything is verified working:

```bash
# On old server
cd ~/Orion-Sentinel-CoreSrv

# Final backup
sudo tar -czf ~/final-backup-$(date +%Y%m%d).tar.gz /srv/orion

# Stop all services
docker compose down

# Remove containers and networks (optional)
docker system prune -a

# Keep the backup safe!
```

## Optional: Enable Public Nextcloud

Once DataAICore is stable, you can optionally expose Nextcloud to the internet:

### Requirements

1. Domain name (e.g., `cloud.yourdomain.com`)
2. DNS A record pointing to your public IP
3. Router port forwarding: `443` → Optiplex IP
4. ORION_DOMAIN set in `.env`

### Enable Public Access

```bash
# On Optiplex
cd ~/Orion-Sentinel-CoreSrv/Orion-Sentinel-DataAICore

# Edit .env and set ORION_DOMAIN
nano .env
# Set: ORION_DOMAIN=yourdomain.com

# Stop and restart with public-nextcloud profile
./scripts/orionctl.sh down
./scripts/orionctl.sh up nextcloud public-nextcloud

# Configure Nextcloud
docker exec -it orion_dataaicore_nextcloud \
  php occ config:system:set trusted_domains 2 --value=cloud.yourdomain.com

docker exec -it orion_dataaicore_nextcloud \
  php occ config:system:set overwrite.cli.url --value=https://cloud.yourdomain.com

docker exec -it orion_dataaicore_nextcloud \
  php occ config:system:set overwriteprotocol --value=https

# Enable 2FA in Nextcloud web UI!
```

**Security checklist:**
- [ ] 2FA enabled for all users
- [ ] Strong passwords enforced
- [ ] Regular backups configured
- [ ] Monitor access logs
- [ ] Update regularly

## Troubleshooting

### Home Assistant not starting on Pi 5

```bash
# Check logs
./scripts/orionctl.sh logs homeassistant

# Common issue: Permission problems
sudo chown -R 1000:1000 /srv/homecore/homeassistant

# Restart
./scripts/orionctl.sh restart
```

### Nextcloud database connection failed

```bash
# Check database health
docker exec orion_dataaicore_nextcloud_db pg_isready -U nextcloud

# Check logs
./scripts/orionctl.sh logs nextcloud-db

# If corrupted, restore from backup
gunzip < ~/nextcloud-db-backup.sql.gz | \
  docker exec -i orion_dataaicore_nextcloud_db psql -U nextcloud nextcloud
```

### Zigbee devices not connecting

```bash
# Check USB device path
ls -l /dev/serial/by-id/

# Update .env with correct path
nano .env

# Restart Zigbee2MQTT
docker restart orion_homecore_zigbee2mqtt

# If needed, re-pair devices in Zigbee2MQTT UI
```

### Lost Home Assistant configuration

If you didn't backup properly or lost data:

```bash
# Check if old data still exists on old server
# SSH to old server
cd /srv/orion/internal/appdata/homeassistant

# If found, create new backup and transfer to Pi
```

## Rollback Plan

If migration fails and you need to rollback:

### HomeCore Rollback

```bash
# On Pi 5
./scripts/orionctl.sh down

# On old server
cd ~/Orion-Sentinel-CoreSrv
./scripts/orionctl up home
```

### DataAICore Rollback

```bash
# On Optiplex
./scripts/orionctl.sh down

# On old server
cd ~/Orion-Sentinel-CoreSrv
./scripts/orionctl up cloud
```

### Full Rollback

```bash
# On old server
cd ~/Orion-Sentinel-CoreSrv

# Restore from backup if needed
sudo rm -rf /srv/orion
sudo tar -xzf ~/orion-backup-YYYYMMDD.tar.gz -C /

# Start all services
./scripts/orionctl up all
```

## Support

If you encounter issues during migration:

1. Check service logs: `./scripts/orionctl.sh logs <service>`
2. Verify backups are intact
3. Review INSTALL.md for each repo
4. Open GitHub issue with details

## Post-Migration Benefits

After successful migration:

✅ **Separation of Concerns**
- Home automation isolated on Pi 5
- Data/AI services on more powerful Optiplex
- Failures in one don't affect the other

✅ **Better Resource Utilization**
- Pi 5 optimized for always-on home automation
- Optiplex handles heavy workloads (Nextcloud, AI)
- Each system can be tuned independently

✅ **Simpler Architecture**
- No complex reverse proxy for local-only services
- Optional public exposure only for Nextcloud
- Easier to understand and maintain

✅ **Scalability**
- Add more storage to Optiplex independently
- Upgrade Pi 5 without touching Nextcloud
- Easy to add more services to appropriate system

---

**Migration complete!** Enjoy your split architecture! 🎉
