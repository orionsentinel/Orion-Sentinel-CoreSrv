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
| **Observability** | Prometheus, Grafana, Loki, Promtail, Uptime Kuma | Monitoring & alerting |
| **Home Automation** | Home Assistant, Mosquitto, Zigbee2MQTT, Mealie | Smart home & IoT |

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