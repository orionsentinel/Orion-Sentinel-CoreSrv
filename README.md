# Orion-Sentinel-CoreSrv

**Production-ready home lab stack for the Orion core services server.**

## Overview

Orion-Sentinel-CoreSrv is the central services hub in a 3-node home lab architecture, providing:

- **Media Stack:** Jellyfin + Sonarr + Radarr + qBittorrent (behind VPN) + Jellyseerr + AI recommendations
- **Core Services:** Traefik reverse proxy + Authelia SSO (zero-trust security)
- **Cloud:** Nextcloud + PostgreSQL
- **Monitoring:** Prometheus + Grafana + Loki + Promtail + Uptime Kuma
- **Search:** SearXNG (privacy-respecting metasearch)
- **Home Automation:** Home Assistant
- **Maintenance:** Homepage dashboard + Watchtower + Autoheal

## Architecture

```
Internet → Router → [CoreSrv] + [Pi DNS] + [Pi NetSec]
                         ↓
              ┌──────────┴──────────┐
              │   Docker Networks   │
              ├────────────────────┤
              │ orion_proxy        │ ← Traefik + Authelia
              │ orion_internal     │ ← Service communication
              │ orion_vpn          │ ← qBittorrent isolation
              │ orion_monitoring   │ ← Metrics & logs
              └────────────────────┘
```

### 3-Node Setup

- **CoreSrv** (this repo) - Media, cloud, monitoring, search, SSO
- **Pi 5 #1** - DNS (Pi-hole + Unbound + HA VIP)
- **Pi 5 #2** - Network Security (Orion Sentinel + AI)

## Quick Start

Get up and running in **5 simple steps**:

### 1. Install Docker

```bash
curl -fsSL https://get.docker.com | sudo sh
sudo usermod -aG docker $USER
sudo apt install -y docker-compose-plugin
# Log out and back in
```

### 2. Clone Repository

```bash
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv
```

### 3. Run Setup Script

The setup script will configure everything automatically:

```bash
./scripts/setup.sh
```

This interactive script will:
- ✅ Check prerequisites
- ✅ Create directory structure
- ✅ Configure environment files with secure generated secrets
- ✅ Validate your setup

### 4. Start Services

```bash
# Start core services (Traefik + Authelia)
./orionctl.sh up-core

# Or start everything
./orionctl.sh up-full
```

### 5. Access Services

All services are accessible via HTTPS with Authelia SSO:

- **Authelia (SSO):** https://auth.local
- **Traefik (Dashboard):** https://traefik.local
- **Homepage Dashboard:** https://home.local
- **Jellyfin:** https://jellyfin.local
- **Jellyseerr:** https://requests.local
- **Grafana:** https://grafana.local
- **Nextcloud:** https://cloud.local
- **SearXNG:** https://search.local

**📖 For detailed installation instructions, see [INSTALL.md](INSTALL.md)**

## Documentation

- **[INSTALL.md](INSTALL.md)** - ⚡ **Quick installation guide (start here!)**
- **[SETUP-CoreSrv.md](docs/SETUP-CoreSrv.md)** - Detailed CoreSrv setup guide
- **[ARCHITECTURE.md](docs/ARCHITECTURE.md)** - Complete 3-node system architecture
- **[UPSTREAM-SYNC.md](docs/UPSTREAM-SYNC.md)** - Sync workflow for upstream updates
- **[CREDITS.md](docs/CREDITS.md)** - Acknowledgements and licenses

### Service-Specific READMEs

- [Core Services](core/README.md) - Traefik + Authelia
- [Media Stack](media/README.md) - Jellyfin + *arr + VPN
- [Monitoring Stack](monitoring/README.md) - Prometheus + Grafana + Loki
- [Cloud Stack](cloud/README.md) - Nextcloud
- [Search](search/README.md) - SearXNG
- [Home Automation](home-automation/README.md) - Home Assistant
- [Maintenance](maintenance/README.md) - Homepage + automation tools

## Profiles

Services are organized into Docker Compose profiles:

- **`core`** - Traefik + Authelia (required)
- **`media-core`** - Jellyfin + *arr + qBittorrent + VPN
- **`media-ai`** - Recommendarr (AI recommendations)
- **`cloud`** - Nextcloud + PostgreSQL
- **`search`** - SearXNG
- **`monitoring`** - Prometheus + Grafana + Loki + Uptime Kuma
- **`home-automation`** - Home Assistant
- **`maintenance`** - Homepage + Watchtower + Autoheal

Start specific profiles:

```bash
docker compose --profile core --profile media-core up -d
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

- **Issues:** https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv/issues
- **Discussions:** https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv/discussions

---

**Maintained By:** Orion Home Lab Team  
**Last Updated:** 2025-11-23