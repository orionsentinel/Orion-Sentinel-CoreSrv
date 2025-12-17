# Orion-Sentinel-CoreSrv

**Production-ready, modular home lab stack for Dell OptiPlex core services node.**

> **Built on proven patterns from [navilg/media-stack](https://github.com/navilg/media-stack)** - Stability and simplicity for media management, extended with enterprise-grade reverse proxy, SSO, monitoring, and home automation.

## Overview

Orion-Sentinel-CoreSrv is a complete, self-hosted home lab stack designed for a Dell OptiPlex or similar hardware. Deploy a full media center, reverse proxy, monitoring solution, and home automation hub with **one command per module**.

### Quick Start (3 Steps)

```bash
# 1. Bootstrap (creates directories, generates secrets)
./scripts/bootstrap-coresrv.sh

# 2. Review configuration (optional, has working defaults)
nano .env

# 3. Deploy media stack
make up-media
```

Access Jellyfin at `http://localhost:8096` - you're done!

## Features

| Module | Services | Description |
|--------|----------|-------------|
| **Core Media** | Jellyfin, Sonarr, Radarr, qBittorrent, Prowlarr, Jellyseerr | Media streaming & automation |
| **Traefik** | Traefik, Authelia, Redis | Reverse proxy with HTTPS & SSO |
| **Observability** | Prometheus, Grafana, Loki, Promtail, Uptime Kuma, NetAlertX | Monitoring, alerting & network mapping |
| **Home Automation** | Home Assistant, Node-RED, Mosquitto, Zigbee2MQTT, Mealie | Smart home, IoT & automation |
| **Finance** | Firefly III | Personal finance & budget management |
| **Cloud** | Nextcloud | Self-hosted file sync & collaboration |
| **Portal** | Homepage / Homarr | Unified dashboard (profile-selectable) |
| **NVR** | Frigate | Camera recording with object detection |

## Modular Architecture

```
┌─────────────────────────────────────────────────────────────────────┐
│                         MODULAR ARCHITECTURE                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────┐  ┌─────────────┐  ┌─────────────┐  ┌────────────┐ │
│  │   MEDIA     │  │   GATEWAY   │  │OBSERVABILITY│  │  HOMEAUTO  │ │
│  │             │  │             │  │             │  │            │ │
│  │ • Jellyfin  │  │ • Traefik   │  │ • Prometheus│  │ • Home     │ │
│  │ • Sonarr    │  │ • Authelia  │  │ • Grafana   │  │   Assistant│ │
│  │ • Radarr    │  │ • Redis     │  │ • Loki      │  │ • Zigbee   │ │
│  │ • qBit      │  │             │  │ • Uptime    │  │ • Mealie   │ │
│  │ • Prowlarr  │  │             │  │   Kuma      │  │ • MQTT     │ │
│  │ • Jellyseerr│  │             │  │             │  │            │ │
│  └──────┬──────┘  └──────┬──────┘  └──────┬──────┘  └─────┬──────┘ │
│         │                │                │                │       │
│         │    ┌───────────┴────────────────┴────────────────┘       │
│         │    │         orion_backbone_net                          │
│         │    │    (optional cross-module network)                  │
│         │    └─────────────────────────────────────────────────────│
│         │                                                          │
│    orion_media_net                                                 │
│   (standalone)                                                     │
│                                                                    │
└────────────────────────────────────────────────────────────────────┘
```

### Why Orion-Sentinel-CoreSrv?

✓ **One command deployment** - `make up-media` and you're streaming  
✓ **Based on navilg/media-stack** - Proven, stable media management patterns  
✓ **Production-ready** - Reverse proxy, SSO, monitoring built-in  
✓ **No manual editing** - Configure via `.env`, not compose files  
✓ **Modular & independent** - Use only what you need  
✓ **Security first** - VPN for torrents, Authelia 2FA, HTTPS everywhere  

## Architecture

```
┌───────────────────────────────────────────────────────────────┐
│                    MODULAR ARCHITECTURE                        │
├───────────────────────────────────────────────────────────────┤
│                                                               │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐     │
│  │  MEDIA   │  │ TRAEFIK  │  │OBSERV-   │  │  HOME    │     │
│  │          │  │          │  │ABILITY   │  │  AUTO    │     │
│  ├──────────┤  ├──────────┤  ├──────────┤  ├──────────┤     │
│  │Jellyfin  │  │Traefik   │  │Prometheus│  │Home Asst.│     │
│  │Sonarr    │  │Authelia  │  │Grafana   │  │Zigbee    │     │
│  │Radarr    │  │Redis     │  │Loki      │  │MQTT      │     │
│  │qBit+VPN  │  │          │  │Uptime    │  │Mealie    │     │
│  │Prowlarr  │  │          │  │Kuma      │  │          │     │
│  │Jellyseerr│  │          │  │          │  │          │     │
│  └──────────┘  └──────────┘  └──────────┘  └──────────┘     │
│       ↓              ↓              ↓              ↓         │
│  Independent    Adds HTTPS    Monitoring     IoT Hub        │
│                                                              │
└───────────────────────────────────────────────────────────────┘
```

## Installation

### Prerequisites

- **Hardware**: Dell OptiPlex or similar (16GB+ RAM recommended)
- **OS**: Ubuntu Server 24.04 LTS, Debian 12, or similar
- **Network**: Static IP recommended
- **Storage**: 100GB+ for system, 500GB+ for media

### Method 1: Automated Bootstrap (Recommended)

The bootstrap script handles everything automatically:

```bash
# Clone repository
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv

# Run bootstrap (installs Docker if needed, creates dirs, generates secrets)
./scripts/bootstrap-coresrv.sh

# Start media stack
make up-media
```

**What the bootstrap does:**
- ✅ Checks and installs Docker + Docker Compose if needed
- ✅ Creates directory structure under `/srv/orion-sentinel-core/`
- ✅ Copies `.env.example` → `.env` with generated secrets
- ✅ Copies all module env files
- ✅ Creates Docker networks
- ✅ Ready to deploy!

### Method 2: Manual Setup

If you prefer manual control:

```bash
# 1. Clone repo
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv

# 2. Copy and edit environment file
cp .env.example .env
nano .env  # Customize DOMAIN, paths, credentials

# 3. Create directories
sudo mkdir -p /srv/orion-sentinel-core/{core,media,monitoring,home-automation}
sudo chown -R $USER:$USER /srv/orion-sentinel-core

# 4. Copy module env files
cp env/.env.media.modular.example env/.env.media
cp env/.env.gateway.example env/.env.gateway
# Edit as needed...

# 5. Generate Authelia secrets
openssl rand -hex 32  # Copy to .env for AUTHELIA_JWT_SECRET
openssl rand -hex 32  # Copy to .env for AUTHELIA_SESSION_SECRET
openssl rand -hex 32  # Copy to .env for AUTHELIA_STORAGE_ENCRYPTION_KEY

# 6. Create networks
make networks

# 7. Deploy
make up-media
```

## Quick Start Examples

### Media Stack Only (Recommended Start)

Perfect for getting started - media services with direct port access:

```bash
make up-media
```

**Access your services:**
- Jellyfin: http://localhost:8096
- qBittorrent: http://localhost:5080  
- Sonarr: http://localhost:8989
- Radarr: http://localhost:7878
- Prowlarr: http://localhost:9696
- Jellyseerr: http://localhost:5055

### Media + Reverse Proxy (Production Setup)

Add Traefik for HTTPS and friendly URLs:

```bash
# Edit gateway config (set your domain)
nano env/.env.gateway

# Deploy
make up-media
make up-traefik
```

**Access via Traefik (configure DNS first):**
- https://jellyfin.local
- https://sonarr.local
- https://radarr.local
- etc.

### Full Stack (Everything)

Media + Reverse Proxy + Monitoring + Home Automation:

```bash
make up-full
```

### Orion Camera NVR (Frigate) – 7 Cameras & Retention

Network Video Recorder for RTSP cameras (Tapo C220/C210, etc.) with object detection.

**Purpose:** Records video from Tapo and other RTSP cameras with **event-only recording** (no continuous 24/7 footage). Features two-tier storage retention: 14 days on primary SSD, then 30 days in backup archive.

**Config files:** `config/frigate/`

#### Quick Start

```bash
# 1. Create Frigate config from template
cp config/frigate/config.example.yml config/frigate/config.yml

# 2. Edit config with your 7 camera IPs and credentials
nano config/frigate/config.yml

# 3. Set storage paths in .env
# ORION_CCTV_MEDIA_DIR=/mnt/orion-cctv          # Primary (SSD) - 14 days
# ORION_CCTV_BACKUP_DIR=/mnt/orion-cctv-backup  # Backup (HDD) - 30 days

# 4. Start NVR
make up-nvr
# Or directly:
docker compose -f stacks/home/cam_nvr.compose.yml up -d
```

**Access Frigate:**
- WebUI: http://localhost:5000
- RTSP restream: rtsp://localhost:8554/<camera_name>
- Via Traefik: https://frigate.orion.lan

#### Camera Setup

**Setting up Tapo cameras:**
1. Open Tapo app → Camera Settings → Advanced Settings → Camera Account
2. Create a username and password (this is different from your Tapo account)
3. Edit `config/frigate/config.yml` with your camera details:
   - Replace `RTSP_USER` and `RTSP_PASS` with the camera account credentials
   - Update IP addresses (default scheme: 192.168.10.11 through 192.168.10.17)
   - Adjust camera names/locations as needed (cam1_living_room, cam2_kitchen, etc.)
4. RTSP URLs:
   - `rtsp://USER:PASS@IP:554/stream1` - 1080p (for recording)
   - `rtsp://USER:PASS@IP:554/stream2` - 360p (for detection, uses less CPU)

#### Recording & Retention Workflow

**Event-Only Recording:**
- Frigate does **NOT** keep continuous 24/7 recordings
- Only stores clips when motion/objects are detected
- Pre-capture: 5 seconds before event
- Post-capture: 10 seconds after event
- Configured objects: person, car, dog, cat

**Two-Tier Storage Retention:**
1. **Primary Storage (Hot):** Event clips kept on fast SSD for **14 days**
   - Set via `ORION_CCTV_MEDIA_DIR` in `.env`
   - Recommend: SSD with good write endurance

2. **Backup Storage (Archive):** After 14 days, clips moved to backup for **30 more days**
   - Set via `ORION_CCTV_BACKUP_DIR` in `.env`
   - Can be slower/cheaper storage (HDD)

3. **Final Purge:** After ~44 days total, recordings are deleted from both locations

**Automated Backup Script:**

Run `scripts/backup-frigate-recordings.sh` daily to maintain retention:

```bash
# Test run (dry run mode)
DRY_RUN=1 ./scripts/backup-frigate-recordings.sh

# Manual run
./scripts/backup-frigate-recordings.sh

# Add to crontab (runs daily at 03:30 AM)
30 3 * * * /usr/bin/env bash /path/to/Orion-Sentinel-CoreSrv/scripts/backup-frigate-recordings.sh >> /var/log/frigate-backup.log 2>&1
```

Or use systemd timer (see script header for example configuration).

**MQTT Integration (optional):**
To enable Home Assistant integration, set in `.env`:
```bash
FRIGATE_MQTT_HOST=orion_mosquitto  # If using the home stack
FRIGATE_MQTT_USER=frigate
FRIGATE_MQTT_PASSWORD=your_password
```
Then enable MQTT in `config/frigate/config.yml`.

**Hardware acceleration (optional):**
- Intel QSV: Uncomment `/dev/dri` device in `stacks/home/cam_nvr.compose.yml`
- Coral TPU: Uncomment USB device mapping and coral detector in config

See `config/frigate/config.example.yml` for all configuration options.

## Configuration Guide

### Essential Settings (.env)

Only a few settings need to be changed from defaults:

```bash
# User/Group (run 'id' to find yours)
PUID=1000
PGID=1000

# Your timezone
TZ=Europe/Amsterdam

# Domain for Traefik routing (only needed with Traefik)
DOMAIN=local  # or yourdomain.com

# Authelia secrets (auto-generated by bootstrap)
AUTHELIA_JWT_SECRET=<generated>
AUTHELIA_SESSION_SECRET=<generated>
AUTHELIA_STORAGE_ENCRYPTION_KEY=<generated>
```

### VPN Configuration (Optional)

To route qBittorrent through VPN (recommended for privacy):

```bash
# Edit env/.env.media
VPN_ENABLED=true
VPN_SERVICE_PROVIDER=protonvpn  # or mullvad, nordvpn, etc.
VPN_WIREGUARD_PRIVATE_KEY=<your-key>

# Deploy with VPN profile
docker compose -f compose/docker-compose.media.yml --profile media-vpn up -d
```

### Directory Paths

All data stored under `/srv/orion-sentinel-core/` by default. Customize in `.env`:

```bash
CORE_ROOT=/srv/orion-sentinel-core/core
MEDIA_CONFIG_ROOT=/srv/orion-sentinel-core/media/config
MEDIA_ROOT=/srv/orion-sentinel-core/media/content
MONITORING_ROOT=/srv/orion-sentinel-core/monitoring
HOME_AUTOMATION_ROOT=/srv/orion-sentinel-core/home-automation
```

## Makefile Commands

All common operations via `make`:

```bash
# Deployment
make up-media           # Start media stack
make up-traefik         # Start Traefik + Authelia  
make up-observability   # Start monitoring
make up-homeauto        # Start home automation
make up-nvr             # Start NVR/Frigate (cameras)
make up-full            # Start everything

# Management  
make down               # Stop all services
make restart            # Restart all
make restart SVC=name   # Restart specific service
make logs               # View all logs
make logs SVC=name      # View specific logs
make status             # Show service status
make health             # Check service health

# Maintenance
make pull               # Update images
make backup             # Run backup
make clean              # Clean up

# Help
make help               # Show all commands
```

## Service Configuration

### Initial Setup Workflow

1. **Start media stack** - `make up-media`

2. **Configure Prowlarr** (indexer manager)
   - Add your indexers (torrent sites)
   - Sync to Sonarr and Radarr

3. **Configure Sonarr/Radarr**
   - Add qBittorrent as download client
   - Set up quality profiles
   - Add root folders

4. **Configure Jellyfin**
   - Add media libraries
   - Set up users
   - Configure transcoding

5. **Configure Jellyseerr** (request management)
   - Connect to Jellyfin
   - Connect to Sonarr/Radarr
   - Set up users and permissions

### Authelia Users (when using Traefik)

Edit user database:

```bash
nano /srv/orion-sentinel-core/core/authelia/users.yml
```

Generate password hash:

```bash
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'YourPassword'
```

Restart Authelia:

```bash
make restart SVC=authelia
```

### DNS Configuration

For Traefik to work with friendly names, add DNS entries:

**Option 1: Local /etc/hosts**
```bash
echo "192.168.1.100  jellyfin.local sonarr.local radarr.local" | sudo tee -a /etc/hosts
```

**Option 2: Pi-hole / DNS Server**
Add local DNS records pointing to CoreSrv IP.

**Option 3: Split DNS**
Configure router or local DNS for `*.local` → CoreSrv IP

## Module Details

### Media Stack

Based on **navilg/media-stack** patterns for stability:

- **Jellyfin** - Media streaming server (Plex alternative)
- **Sonarr** - TV show automation
- **Radarr** - Movie automation  
- **qBittorrent** - Torrent client (optional VPN routing)
- **Prowlarr** - Indexer manager (connects to Sonarr/Radarr)
- **Jellyseerr** - Request management (Overseerr for Jellyfin)
- **Bazarr** - Subtitle management (optional, media-extra profile)

**Profiles:**
- `media-core` - Essential services (default)
- `media-vpn` - qBittorrent through VPN
- `media-extra` - Bazarr, Recommendarr

### Traefik (Reverse Proxy)

- **Automatic HTTPS** - Let's Encrypt certificates
- **HTTP→HTTPS redirect** - Enforced secure connections
- **Friendly hostnames** - service.yourdomain.com
- **Dynamic configuration** - Add services via labels

### Authelia (SSO & 2FA)

- **Single Sign-On** - One login for all services
- **Two-Factor Authentication** - TOTP, WebAuthn support
- **Access control** - Per-service policies
- **Session management** - Redis-backed sessions

### Observability

- **Prometheus** - Metrics collection from all services
- **Grafana** - Dashboards and visualization
- **Loki** - Log aggregation (all container logs)
- **Promtail** - Log shipping agent
- **Uptime Kuma** - Uptime monitoring with alerts
- **Node Exporter** - Host system metrics
- **cAdvisor** - Container metrics

**Pre-built dashboards** in `grafana_dashboards/`:
- System Overview
- Container Performance
- More available from Grafana.com

### Home Automation

- **Home Assistant** - Smart home hub
- **Mosquitto** - MQTT broker for IoT devices
- **Zigbee2MQTT** - Zigbee device gateway (requires USB coordinator)
- **Mealie** - Recipe and meal planning
- **DSMR Reader** - Dutch smart meter monitoring (optional)

## Hardware Requirements

### Dell OptiPlex Recommended Specs

- **CPU**: Intel i5/i7 (4+ cores)
- **RAM**: 16GB minimum, 32GB recommended
- **Storage**: 
  - 100GB SSD for OS and configs
  - 500GB+ HDD/SSD for media
- **Network**: Gigabit Ethernet
- **Optional**: Intel iGPU for Jellyfin hardware transcoding

### USB Devices

- **Zigbee Coordinator**: Sonoff Zigbee 3.0 USB, ConBee II, or similar
- **P1 Cable**: For DSMR Reader (Netherlands smart meters)

Find USB device paths:

```bash
ls -l /dev/serial/by-id/
# or
ls -l /dev/ttyACM* /dev/ttyUSB*
```

## Directory Structure

After installation, your filesystem looks like:

```
/srv/orion-sentinel-core/
├── core/
│   ├── traefik/          # Reverse proxy configs
│   ├── authelia/         # SSO & user database
│   └── redis/            # Session storage
├── media/
│   ├── config/           # Service configs
│   │   ├── jellyfin/
│   │   ├── sonarr/
│   │   ├── radarr/
│   │   └── ...
│   └── content/          # Media files
│       ├── downloads/    # qBittorrent downloads
│       └── library/      # Organized media
├── monitoring/
│   ├── prometheus/
│   ├── grafana/
│   ├── loki/
│   └── uptime-kuma/
└── home-automation/
    ├── homeassistant/
    ├── zigbee2mqtt/
    ├── mosquitto/
    └── mealie/
```

## Security

### Built-in Security Features

✓ **Reverse Proxy** - All services behind Traefik  
✓ **HTTPS Everywhere** - Automatic Let's Encrypt certificates  
✓ **SSO + 2FA** - Authelia authentication for all admin tools  
✓ **VPN Isolation** - qBittorrent traffic through VPN  
✓ **No Direct Exposure** - Services not accessible without auth  
✓ **Secret Management** - All credentials in .env (git-ignored)  
✓ **Network Isolation** - Services in separate Docker networks  

### Security Best Practices

1. **Change all default passwords** in `.env`
2. **Enable 2FA** in Authelia for all users
3. **Use VPN** for torrent traffic
4. **Rotate secrets** every 6-12 months
5. **Keep services updated** - `make pull && make up-full`
6. **Regular backups** - `make backup`
7. **Monitor logs** for suspicious activity

### Secrets Management

Never commit `.env` files to version control (already in `.gitignore`).

Store backups securely:
- Password manager (1Password, Bitwarden)
- Encrypted USB drive
- Encrypted cloud storage

## Optional Services & Profiles

Orion Sentinel CoreSrv now includes optional services that can be enabled via Docker Compose profiles. These extend the core functionality with additional capabilities.

### Available Profiles

**Finance Management:**
```bash
# Start Firefly III for personal finance tracking
docker compose --profile finance up -d
```
- **Firefly III**: Budget management, expense tracking, bank integrations
- **Access**: https://firefly.orion.lan
- **Docs**: `stacks/apps/firefly/README.md`

**Cloud Storage:**
```bash
# Start Nextcloud for self-hosted file sync
docker compose --profile cloud up -d
```
- **Nextcloud**: File sync, calendar, contacts, collaboration
- **Access**: https://cloud.orion.lan
- **Docs**: `stacks/cloud/nextcloud/README.md`

**Dashboard (choose one):**
```bash
# Homepage (recommended) - widget-rich dashboard
docker compose --profile portal_homepage up -d

# Homarr (alternative) - visual dashboard with drag-and-drop
docker compose --profile portal_homearr up -d
```
- **Access**: https://portal.orion.lan
- **Docs**: `stacks/portal/README.md`
- **Note**: Only run one at a time (same URL)

**Network Monitoring:**
```bash
# Start NetAlertX for network device discovery
docker compose --profile net_map up -d
```
- **NetAlertX**: Network scanner, device inventory, alerts for new devices
- **Access**: https://netmap.orion.lan
- **Docs**: `stacks/observability/netmap/README.md`

**Recipe Automation:**
```bash
# Start Mealie Recipe Sync (requires Mealie to be running)
docker compose --profile food_sync up -d
```
- **Mealie Sync**: Automatically import recipes from RSS feeds and URL lists
- **No web UI** (background service)
- **Docs**: `stacks/apps/mealie-sync/README.md`

### Quick Start Examples

**Minimal setup (dashboard only):**
```bash
./scripts/orionctl up ingress
docker compose --profile portal_homepage up -d
```

**Personal productivity (finance + cloud + dashboard):**
```bash
./scripts/orionctl up ingress
docker compose --profile finance --profile cloud --profile portal_homepage up -d
```

**Full stack with all optional services:**
```bash
./scripts/orionctl up all
docker compose \
  --profile finance \
  --profile cloud \
  --profile portal_homepage \
  --profile net_map \
  --profile food_sync \
  up -d
```

### Comprehensive Profile Documentation

See **[docs/PROFILES.md](docs/PROFILES.md)** for:
- Detailed profile descriptions
- Configuration requirements
- Environment variables
- Dependencies
- Troubleshooting
- Best practices

## Troubleshooting

### Common Issues

**Services not starting:**
```bash
make logs SVC=<servicename>  # Check logs
make status                  # Check container status
```

**Permission errors:**
```bash
id  # Verify PUID/PGID in .env match
sudo chown -R $USER:$USER /srv/orion-sentinel-core
```

**Can't access via Traefik:**
```bash
# Check DNS resolution
ping jellyfin.local

# Check Traefik logs
make logs SVC=traefik

# Verify service has correct labels
docker inspect <container> | grep traefik
```

**VPN not connecting:**
```bash
make logs SVC=gluetun
# Verify credentials in env/.env.media
```

**Out of disk space:**
```bash
# Check usage
df -h

# Clean up Docker
make clean
docker system prune -a
```

## Monitoring & Observability

### Grafana Dashboards

Pre-configured dashboards in `grafana_dashboards/`:

1. **System Overview** - CPU, RAM, disk, network
2. **Container Performance** - Docker container metrics
3. **Service Health** - Application-specific metrics

Import more from [Grafana.com](https://grafana.com/grafana/dashboards/):
- **1860** - Node Exporter Full
- **893** - Docker Monitoring  
- **12486** - Traefik Dashboard

### Prometheus Metrics

Automatically scraping:
- Node Exporter (host metrics)
- cAdvisor (container metrics)
- Service endpoints (application metrics)

View targets: http://prometheus.local/targets

### Loki Logs

All container logs aggregated in Loki.

View in Grafana → Explore → Loki

## Backup & Restore

Orion Sentinel includes comprehensive backup and restore scripts for all critical data.

### Quick Backup

```bash
# Backup everything (requires sudo)
sudo ./backup/backup-volumes.sh

# Or use Makefile
make backup
```

Backups are saved to `/srv/backups/orion/YYYYMMDD/` by default.

### What Gets Backed Up

**Core Services** (Highest Priority):
- Traefik configuration and SSL certificates
- Authelia user database and configuration
- Redis session storage

**Media Configurations**:
- Jellyfin, Sonarr, Radarr, Prowlarr configurations
- Jellyseerr, qBittorrent, Bazarr settings

**Home Automation**:
- Home Assistant configuration and database
- Zigbee2MQTT device pairings
- Mosquitto MQTT configuration
- Mealie recipes and meal plans

**Monitoring & Extras**:
- Grafana dashboards and users
- Prometheus metrics (optional)
- Uptime Kuma monitors
- Homepage dashboard configuration
- SearXNG search settings

**Note:** Media files (movies/TV shows) are NOT backed up due to size. Only configurations.

### Restore a Service

```bash
# Restore specific service from a backup
sudo ./backup/restore-volume.sh <volume-name> <backup-date>

# Examples:
sudo ./backup/restore-volume.sh core-traefik 20250109
sudo ./backup/restore-volume.sh media-jellyfin 20250109
sudo ./backup/restore-volume.sh homeauto-mealie 20250109
```

### Automated Backups

Set up automated daily/weekly backups with cron:

```bash
# Edit crontab
sudo crontab -e

# Add daily backup at 2 AM
0 2 * * * /path/to/Orion-Sentinel-CoreSrv/backup/backup-volumes.sh >> /var/log/orion-backup.log 2>&1
```

### Full Documentation

For complete backup/restore procedures, disaster recovery, and troubleshooting:

- [backup/README.md](backup/README.md) - Complete backup guide
- [docs/BACKUP-RESTORE.md](docs/BACKUP-RESTORE.md) - Detailed procedures

## Updates & Maintenance

### Update Strategy

Orion Sentinel uses **version pinning** for stability. Updates are manual and deliberate.

**Recommended:**
- Security patches: Apply immediately
- Minor updates: Monthly review
- Major updates: Quarterly, with testing

### Update Docker Images

```bash
# 1. Backup first!
sudo ./backup/backup-volumes.sh

# 2. Pull latest images
make pull

# 3. Review what changed
# Edit compose files to new version tags if needed

# 4. Restart with new images
make down
make up-full

# 5. Verify everything works
make health
make logs
```

### Update Repository Code

```bash
cd ~/Orion-Sentinel-CoreSrv

# Backup before updating
sudo ./backup/backup-volumes.sh

# Pull latest code
git pull origin main

# Review changes
git log --oneline -10

# Restart if needed
make down
make up-all
```

### Automated Updates

**Option 1: Watchtower (Recommended for home labs)**

Automatically updates running containers when new images are available.

**Option 1: Watchtower (Automatic, use with caution)**

Uncomment the Watchtower service in `compose/docker-compose.extras.yml` to enable automatic updates.

**⚠️ WARNING:** Can apply breaking changes automatically!

**Option 2: DIUN (Notifications only, recommended)**

Get notified of updates but apply manually. See [docs/UPDATE.md](docs/UPDATE.md) for setup.

**Option 3: Manual monthly checks**

Set a calendar reminder to check for updates monthly.

### Version Pinning

All services use specific version tags (never `latest`):

```yaml
# Good - pinned version
jellyfin:
  image: jellyfin/jellyfin:10.8.13

# Bad - unpredictable
jellyfin:
  image: jellyfin/jellyfin:latest  # Don't do this!
```

### Complete Update Guide

For detailed update procedures, rollback instructions, and security updates:

- [docs/UPDATE.md](docs/UPDATE.md) - Complete update guide
- [docs/SECURITY-HARDENING.md](docs/SECURITY-HARDENING.md) - Security best practices

## Advanced Configuration

### Custom Traefik Configuration

Edit dynamic configs:

```bash
nano /srv/orion-sentinel-core/core/traefik/dynamic/security.yml
```

Restart Traefik:

```bash
make restart SVC=traefik
```

### Custom Grafana Dashboards

Add JSON files to `grafana_dashboards/`, restart Grafana:

```bash
make restart SVC=grafana
```

### Multiple qBittorrent Instances

Edit `compose/docker-compose.media.yml` to add more instances.

### External Storage

Mount NAS/SAN for media:

```bash
# In .env
MEDIA_ROOT=/mnt/nas/media
```

## Storage & Replication (Dell Deployment)

For Dell OptiPlex deployments with external Samsung SSDs, Orion Sentinel supports a two-tier storage model with automatic replication.

### Storage Architecture

```
┌─────────────────────────────────────────────────────────────────────────┐
│                       DELL STORAGE ARCHITECTURE                         │
├─────────────────────────────────────────────────────────────────────────┤
│                                                                         │
│  Internal Disk                    External SSDs                         │
│  (/srv/orion/internal)            (Samsung 4TB x2)                      │
│  ┌───────────────────┐            ┌────────────────────────────────────┐│
│  │ • appdata/        │            │ Master (/mnt/SMSNG4T1)             ││
│  │ • db/             │            │  └─ /srv/orion/external_primary    ││
│  │ • observability/  │            │      • media/                      ││
│  │ • config-snapshots│            │      • cameras/                    ││
│  └───────────────────┘            │      • backups/                    ││
│         │                         │      • internal-mirror/            ││
│         │                         ├────────────────────────────────────┤│
│         │                         │ Replica (/mnt/SMSNG4T2)            ││
│         └─────────────────────────│  └─ /srv/orion/external_replica    ││
│           Mirrored to backup      │      (mirror of master)            ││
│                                   └────────────────────────────────────┘│
│                                              ↑                          │
│                                        Nightly rsync                    │
│                                        (systemd timer)                  │
└─────────────────────────────────────────────────────────────────────────┘
```

### Mountpoints

| Path | Description | Physical Location |
|------|-------------|-------------------|
| `/mnt/SMSNG4T1` | Master SSD mount | External Samsung SSD 1 |
| `/mnt/SMSNG4T2` | Replica SSD mount | External Samsung SSD 2 |
| `/srv/orion/internal` | Internal storage root | Internal disk |
| `/srv/orion/external_primary` | Bind mount to master | → `/mnt/SMSNG4T1/orion` |
| `/srv/orion/external_replica` | Bind mount to replica | → `/mnt/SMSNG4T2/orion` |

### Quick Setup

```bash
# 1. Ensure external SSDs are mounted (add to /etc/fstab)
sudo blkid  # Find UUIDs
# Add to /etc/fstab:
# UUID=<master-uuid> /mnt/SMSNG4T1 ext4 defaults,nofail 0 2
# UUID=<replica-uuid> /mnt/SMSNG4T2 ext4 defaults,nofail 0 2
sudo mount -a

# 2. Bootstrap storage directories and bind mounts
sudo ./scripts/bootstrap-storage.sh --install-fstab

# 3. Configure environment
cp .env.example .env
# Edit .env to set ORION_* variables

# 4. Test replication
./scripts/replicate-external.sh --dry-run

# 5. Install systemd timer for automatic nightly replication
sudo ./scripts/install-systemd.sh
```

### Verification

```bash
# Check mounts
findmnt | grep -E 'SMSNG4T|external_primary|external_replica'

# Check disk usage
df -h /srv/orion/external_primary /srv/orion/external_replica

# Check timer status
systemctl list-timers | grep orion-replica

# View replication logs
tail -50 /srv/orion/external_primary/backups/replication/replica-sync.log
```

### Environment Variables (Dell Deployment)

Add these to your `.env` for Dell deployment:

```bash
# Storage roots
ORION_INTERNAL_ROOT=/srv/orion/internal
ORION_EXTERNAL_PRIMARY=/srv/orion/external_primary
ORION_EXTERNAL_REPLICA=/srv/orion/external_replica

# Derived paths (on external SSD)
ORION_MEDIA_DIR=${ORION_EXTERNAL_PRIMARY}/media
ORION_CAMERAS_DIR=${ORION_EXTERNAL_PRIMARY}/cameras
ORION_BACKUPS_DIR=${ORION_EXTERNAL_PRIMARY}/backups

# Map compose variables to Dell storage
GATEWAY_CONFIG_ROOT=${ORION_INTERNAL_ROOT}/appdata/gateway
MEDIA_CONFIG_ROOT=${ORION_INTERNAL_ROOT}/appdata/media
HOMEAUTO_CONFIG_ROOT=${ORION_INTERNAL_ROOT}/appdata/homeauto
OBSERVABILITY_CONFIG_ROOT=${ORION_INTERNAL_ROOT}/observability
MEDIA_ROOT=${ORION_MEDIA_DIR}
```

### Safety Notes

⚠️ **The replication script will ABORT if mounts are missing** - This prevents accidentally syncing into the root filesystem if external SSDs are disconnected.

📋 **fstab entries are added idempotently** - Running `bootstrap-storage.sh --install-fstab` multiple times won't create duplicate entries.

🔄 **Replication is one-way (master → replica)** - Changes on the replica will be overwritten on the next sync.

## Dell Traefik Deployment (orion.lan)

This section describes deploying all services behind Traefik with the `orion.lan` domain using Pi-hole Local DNS.

### Service Endpoints

| Service | URL | Description |
|---------|-----|-------------|
| Portal | https://portal.orion.lan | Homepage dashboard |
| Grafana | https://grafana.orion.lan | Monitoring dashboards |
| Prometheus | https://prometheus.orion.lan | Metrics collection |
| Uptime Kuma | https://uptime.orion.lan | Status monitoring |
| Home Assistant | https://home.orion.lan | Smart home hub |
| Zigbee2MQTT | https://zigbee.orion.lan | Zigbee gateway |
| Mealie | https://mealie.orion.lan | Recipe management |
| DSMR Reader | https://dsmr.orion.lan | Energy monitoring |
| Traefik | https://traefik.orion.lan | Reverse proxy dashboard |

### Pi-hole Local DNS Setup

Configure Pi-hole to resolve all `*.orion.lan` subdomains to your Dell server IP:

1. **Open Pi-hole Admin** → Local DNS → DNS Records

2. **Add wildcard CNAME record:**
   - This method requires adding each subdomain individually in Pi-hole

3. **Add A records for each service:**
   ```
   portal.orion.lan     → 192.168.1.100  # Replace with Dell IP
   grafana.orion.lan    → 192.168.1.100
   prometheus.orion.lan → 192.168.1.100
   uptime.orion.lan     → 192.168.1.100
   home.orion.lan       → 192.168.1.100
   zigbee.orion.lan     → 192.168.1.100
   mealie.orion.lan     → 192.168.1.100
   dsmr.orion.lan       → 192.168.1.100
   traefik.orion.lan    → 192.168.1.100
   mqtt.orion.lan       → 192.168.1.100
   ```

4. **Alternative: Use dnsmasq wildcard** (advanced):
   Add to `/etc/dnsmasq.d/02-orion.conf` on Pi-hole:
   ```
   address=/orion.lan/192.168.1.100
   ```

### Quick Deployment

```bash
# 1. Bootstrap storage (if not done)
sudo ./scripts/bootstrap-storage.sh --install-fstab

# 2. Configure environment
cp .env.example .env
# Set LOCAL_DOMAIN=orion.lan in .env

# 3. Copy config files
cp -r config/traefik/* ${ORION_INTERNAL_ROOT}/appdata/traefik/
cp -r config/ha-proxy/* ${ORION_INTERNAL_ROOT}/appdata/ha-proxy/
cp -r config/prometheus/* ${ORION_INTERNAL_ROOT}/observability/prometheus/
cp -r config/loki/* ${ORION_INTERNAL_ROOT}/observability/loki/
cp -r config/promtail/* ${ORION_INTERNAL_ROOT}/observability/promtail/
cp -r config/grafana/provisioning/* ${ORION_INTERNAL_ROOT}/observability/grafana/provisioning/
cp -r config/mosquitto/* ${ORION_INTERNAL_ROOT}/appdata/mosquitto/

# 4. Start stacks in order
./scripts/orionctl up ingress
./scripts/orionctl up observability
./scripts/orionctl up home
./scripts/orionctl up apps
./scripts/orionctl up portal

# 5. Verify deployment
./scripts/orionctl ps
curl -k https://portal.orion.lan
```

### Home Assistant Host Networking

Home Assistant runs with `network_mode: host` for device discovery (mDNS, Bluetooth, etc.). Since Traefik cannot route directly to host-network containers, we use an nginx proxy (`ha-proxy`) as an intermediary:

```
Client → Traefik → ha-proxy → Home Assistant (host:8123)
```

Home Assistant is also directly accessible at `http://<dell-ip>:8123`.

### Automated Backups

Database backups run automatically via systemd timers:

| Schedule | Retention | Command |
|----------|-----------|---------|
| Daily @ 3:00 AM | 7 days | `./scripts/orion-backup.sh` |
| Weekly @ 4:00 AM (Sun) | 30 days | `./scripts/orion-backup.sh --weekly` |

Install backup timers:
```bash
sudo cp systemd/orion-backup-*.{service,timer} /etc/systemd/system/
sudo systemctl daemon-reload
sudo systemctl enable --now orion-backup-daily.timer
sudo systemctl enable --now orion-backup-weekly.timer
```

Backup location: `${ORION_BACKUPS_DIR}/db/`

### Stack Files

The modular stack architecture:

```
stacks/
├── ingress/
│   └── traefik.yaml      # Traefik reverse proxy
├── observability/
│   └── stack.yaml        # Grafana, Prometheus, Loki, etc.
├── home/
│   └── stack.yaml        # Home Assistant, Mosquitto, Zigbee2MQTT
├── apps/
│   └── stack.yaml        # Mealie, DSMR Reader
└── portal/
    └── stack.yaml        # Homepage dashboard
```

## Documentation

### Getting Started
- **[README.md](README.md)** - This file, quick start guide
- **[docs/INSTALLATION.md](docs/INSTALLATION.md)** - Complete installation guide
- **[INSTALL.md](INSTALL.md)** - Legacy installation guide

### Architecture & Planning
- **[PLAN.md](PLAN.md)** - Architecture & deployment plan
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - 3-node system architecture
- **[docs/SETUP-CoreSrv.md](docs/SETUP-CoreSrv.md)** - Dell OptiPlex setup guide

### Operations & Maintenance
- **[backup/README.md](backup/README.md)** - Backup and restore guide
- **[docs/UPDATE.md](docs/UPDATE.md)** - Update procedures and version management
- **[docs/RUNBOOKS.md](docs/RUNBOOKS.md)** - Troubleshooting and operational procedures
- **[docs/BACKUP-RESTORE.md](docs/BACKUP-RESTORE.md)** - Detailed backup/restore procedures

### Security
- **[docs/SECURITY-HARDENING.md](docs/SECURITY-HARDENING.md)** - Security best practices
- **[docs/SECRETS.md](docs/SECRETS.md)** - Secrets management

### Additional Resources
- **[docs/CREDITS.md](docs/CREDITS.md)** - Acknowledgements and licenses
- **[docs/DEPLOYMENT-GUIDE.md](docs/DEPLOYMENT-GUIDE.md)** - Deployment workflows
- **[docs/TOPOLOGY.md](docs/TOPOLOGY.md)** - Network topology and design

## Support & Community

- **Issues**: https://github.com/orionsentinel/Orion-Sentinel-CoreSrv/issues
- **Discussions**: https://github.com/orionsentinel/Orion-Sentinel-CoreSrv/discussions

## Credits & Inspiration

This project builds on excellent work from:

- **[navilg/media-stack](https://github.com/navilg/media-stack)** - Stable, proven media stack patterns
- **[AdrienPoupa/docker-compose-nas](https://github.com/AdrienPoupa/docker-compose-nas)** - NAS/media inspiration
- **LinuxServer.io** - Excellent Docker images
- **Traefik Labs** - Modern reverse proxy
- **Authelia** - Open-source SSO solution

See [docs/CREDITS.md](docs/CREDITS.md) for full credits and licenses.

## License

MIT License - See [LICENSE](LICENSE)

---

**Maintained by:** Orion Home Lab Team  
**Last Updated:** 2025-12-09

**Ready to deploy?** Run `make help` to see all commands!