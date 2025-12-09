# Orion-Sentinel-CoreSrv

**Production-ready, modular home lab stack for the Orion core services server.**

## Overview

Orion-Sentinel-CoreSrv is the central services hub in a 3-node home lab architecture. The stack is organized into **independent modules** that can be started and stopped separately:

| Module | Services | Description |
|--------|----------|-------------|
| **Media** | Jellyfin, Sonarr, Radarr, qBittorrent, Prowlarr, Jellyseerr | Media streaming & automation |
| **Gateway** | Traefik, Authelia, Redis | Reverse proxy & SSO |
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

### Key Benefits

- **Media is standalone**: The media module works independently without any other infrastructure
- **Incremental adoption**: Start with media, add gateway/monitoring later
- **Clean separation**: Each module has its own network and configuration
- **Simpler debugging**: Smaller compose files, easier to reason about
- **No hidden dependencies**: Missing env vars have safe defaults

## Quick Start (Media Stack)

Get the media stack running in **3 simple steps**:

### 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
sudo apt install -y docker-compose-plugin
# Log out and back in
```

### 2. Setup Directories & Environment

```bash
# Clone the repo
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv

# Create media directories
sudo mkdir -p /srv/media/{downloads,library}/{movies,tv}
sudo mkdir -p /srv/docker/media/{jellyfin,qbittorrent,sonarr,radarr,prowlarr,jellyseerr}/config
sudo chown -R $USER:$USER /srv/media /srv/docker/media

# Copy and customize the env file
cp env/.env.media.modular.example env/.env.media
# Edit env/.env.media if needed (defaults work out of the box)
```

### 3. Start the Media Stack

```bash
./scripts/orionctl up media
```

### Access Services

All media services are immediately accessible on your LAN:

| Service | URL | Description |
|---------|-----|-------------|
| Jellyfin | http://localhost:8096 | Media streaming |
| qBittorrent | http://localhost:5080 | Torrent client |
| Radarr | http://localhost:7878 | Movie management |
| Sonarr | http://localhost:8989 | TV show management |
| Prowlarr | http://localhost:9696 | Indexer manager |
| Jellyseerr | http://localhost:5055 | Request management |

## Module Management

Use the `orionctl` script to manage modules:

```bash
# Start a module
./scripts/orionctl up media
./scripts/orionctl up gateway
./scripts/orionctl up observability
./scripts/orionctl up homeauto

# Stop a module
./scripts/orionctl down media

# View status
./scripts/orionctl status
./scripts/orionctl status media

# View logs
./scripts/orionctl logs media
./scripts/orionctl logs media jellyfin

# Restart a service
./scripts/orionctl restart media sonarr
```

### Media Profiles

The media module supports multiple profiles:

```bash
# Default: Core media services (no VPN)
./scripts/orionctl up media

# With VPN: Routes qBittorrent through Gluetun VPN
./scripts/orionctl up media media-vpn

# Extras: Bazarr (subtitles), Recommendarr (AI recommendations)
docker compose -f compose/docker-compose.media.yml --profile media-extra up -d
```

## Adding Other Modules

### Gateway (Traefik + Authelia)

```bash
# Setup
cp env/.env.gateway.example env/.env.gateway
# Edit env/.env.gateway - MUST change Authelia secrets!

# Start
./scripts/orionctl up gateway
```

### Observability (Prometheus + Grafana)

```bash
# Setup  
cp env/.env.observability.example env/.env.observability

# Start (requires gateway for reverse proxy)
./scripts/orionctl up observability
```

### Home Automation

```bash
# Setup
cp env/.env.homeauto.example env/.env.homeauto

# Start
./scripts/orionctl up homeauto
```

## Installation Order

For a complete setup, install modules in this order:

1. **Media** (most important, must be rock-solid)
2. **Gateway** (adds reverse proxy + SSO to existing services)
3. **Observability** (monitoring for all services)
4. **Home Automation** (when ready)

Each step is optional - the media stack works perfectly fine on its own.

## Directory Structure

```
/srv/
├── media/                      # Media content
│   ├── downloads/              # qBittorrent downloads
│   │   ├── movies/
│   │   └── tv/
│   └── library/                # Organized media (Jellyfin)
│       ├── movies/
│       └── tv/
└── docker/
    ├── media/                  # Media service configs
    │   ├── jellyfin/config/
    │   ├── qbittorrent/config/
    │   ├── sonarr/config/
    │   ├── radarr/config/
    │   ├── prowlarr/config/
    │   └── jellyseerr/config/
    ├── gateway/                # Gateway service configs
    ├── observability/          # Monitoring service configs
    └── homeauto/               # Home automation configs
```

**📖 For detailed installation instructions, see [INSTALL.md](INSTALL.md)**

## Documentation

- **[INSTALL.md](INSTALL.md)** - ⚡ **Quick installation guide**
- **[docs/SETUP-CoreSrv.md](docs/SETUP-CoreSrv.md)** - Detailed CoreSrv setup guide
- **[docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Complete 3-node system architecture
- **[docs/UPSTREAM-SYNC.md](docs/UPSTREAM-SYNC.md)** - Sync workflow for upstream updates
- **[docs/CREDITS.md](docs/CREDITS.md)** - Acknowledgements and licenses

### Module Compose Files

| File | Module | Description |
|------|--------|-------------|
| `compose/docker-compose.media.yml` | Media | Jellyfin + *arr + qBittorrent |
| `compose/docker-compose.gateway.yml` | Gateway | Traefik + Authelia |
| `compose/docker-compose.observability.yml` | Observability | Prometheus + Grafana + Loki |
| `compose/docker-compose.homeauto.yml` | Home Automation | Home Assistant + Zigbee + MQTT |

### Environment Files

| File | Module | Description |
|------|--------|-------------|
| `env/.env.media.modular.example` | Media | Media stack configuration |
| `env/.env.gateway.example` | Gateway | Gateway configuration + secrets |
| `env/.env.observability.example` | Observability | Monitoring configuration |
| `env/.env.homeauto.example` | Home Automation | Home automation configuration |

### Service-Specific READMEs

- [Core Services](core/README.md) - Traefik + Authelia
- [Media Stack](media/README.md) - Jellyfin + *arr + VPN
- [Monitoring Stack](monitoring/README.md) - Prometheus + Grafana + Loki
- [Home Automation](home-automation/README.md) - Home Assistant + Zigbee2MQTT + MQTT + Mealie

## Migration from Old Stack

If you were using the old monolithic compose.yml:

1. **Stop the old stack:**
   ```bash
   docker compose down
   ```

2. **The old compose file is archived at:**
   ```
   legacy/compose.yml.monolithic
   ```

3. **Start the new modular media stack:**
   ```bash
   ./scripts/orionctl up media
   ```

4. **Gradually add other modules as needed**

The new media module is designed to be the stable, primary module that works independently of all other infrastructure. Your existing data and configurations should continue to work - just update the paths in your env file if needed.

## Profiles (Media Module)

The media module uses profiles to control which services start:

- **`media-core`** - Jellyfin + *arr + qBittorrent (no VPN)
- **`media-vpn`** - Gluetun VPN + qBittorrent (torrent privacy)
- **`media-extra`** - Bazarr + Recommendarr (optional extras)

Start specific profiles:

```bash
# Media core (default)
./scripts/orionctl up media

# With VPN
./scripts/orionctl up media media-vpn

# Or directly with docker compose
docker compose -f compose/docker-compose.media.yml --profile media-core up -d
```

## Security

### Zero-Trust Architecture

- All services behind Traefik reverse proxy
- Authelia SSO with 2FA for all admin tools
- VPN isolation for torrent traffic (qBittorrent)
- No services exposed without authentication

### Secrets Management

- All secrets in `.env.*` files (git-ignored)
- Generate strong secrets: `openssl rand -hex 32`
- See [secrets/README.md](secrets/README.md) for details

## Inspired By

This project reuses patterns from excellent upstream projects:

- [AdrienPoupa/docker-compose-nas](https://github.com/AdrienPoupa/docker-compose-nas) - NAS/media stack patterns
- [navilg/media-stack](https://github.com/navilg/media-stack) - Modern Jellyfin + AI recommendations

See [CREDITS.md](docs/CREDITS.md) for details and licenses.

## License

MIT License - See [LICENSE](LICENSE)

## Support

- **Issues:** https://github.com/orionsentinel/Orion-Sentinel-CoreSrv/issues
- **Discussions:** https://github.com/orionsentinel/Orion-Sentinel-CoreSrv/discussions

---

**Maintained By:** Orion Home Lab Team  
**Last Updated:** 2025-12-09