# Orion Home Lab Architecture

## Overview

This document describes the complete architecture of the Orion home lab, a 3-node system designed for privacy, security, and comprehensive media/cloud/monitoring services.

## System Components

### 3-Node Architecture

```
                    Internet
                       |
                       v
                   [Router]
                       |
        +--------------+--------------+
        |              |              |
        v              v              v
   [Pi 5 #1]      [Pi 5 #2]      [CoreSrv]
  DNS Stack      NetSec Stack    Services Hub
  Pi-hole        Orion           (This Repo)
  Unbound        Sentinel
  HA VIP
```

### Node Responsibilities

#### Pi 5 #1: DNS Brain (Dedicated DNS Stack)
- **Purpose:** Network-wide DNS resolution, ad-blocking, and privacy protection
- **Services:**
  - Pi-hole (DNS-based ad blocking)
  - Unbound (recursive DNS resolver, no upstream)
  - High Availability VIP (Keepalived for failover)
- **Network Role:** Primary DNS for entire home lab (192.168.1.x)
- **Repository:** Separate dedicated DNS repo
- **Monitoring:** Exports metrics to CoreSrv monitoring stack

#### Pi 5 #2: Network Security & AI
- **Purpose:** Network security monitoring, threat detection, AI-powered analysis
- **Services:**
  - Orion Sentinel (custom NetSec monitoring)
  - Network traffic analysis
  - AI-powered threat detection
  - Security event correlation
- **Repository:** Separate Orion Sentinel repo
- **Monitoring:** Exports metrics to CoreSrv monitoring stack

#### CoreSrv: Central Services Hub (This Repository)
- **Purpose:** Primary services host for media, cloud, search, monitoring, and automation
- **Services:** See "CoreSrv Services Stack" section below
- **Network Role:** All user-facing services, reverse proxy, SSO
- **DNS:** All lookups go through Pi 5 #1 (Pi-hole)

## CoreSrv Services Stack (This Repository)

### Docker Network Architecture

The CoreSrv runs all services in Docker with isolated networks for security and traffic control:

```
                      [Traefik Reverse Proxy]
                     (orion_proxy network)
                              |
                              v
                      [Authelia SSO]
                              |
        +---------------------+---------------------+
        |                     |                     |
        v                     v                     v
   [Media Stack]        [Cloud Stack]      [Monitoring Stack]
   orion_internal       orion_internal      orion_monitoring
        |
        v
   [VPN Stack]
   orion_vpn
   (isolated)
```

### Network Segmentation

1. **orion_proxy** (Reverse Proxy Network)
   - Purpose: All HTTP/HTTPS traffic goes through Traefik
   - Services: Traefik, all web UIs
   - Security: External-facing, protected by Authelia SSO

2. **orion_internal** (Internal Service Communication)
   - Purpose: Backend service-to-service communication
   - Services: All app backends, databases, API calls
   - Security: Not exposed externally, internal-only

3. **orion_vpn** (VPN Isolation Network)
   - Purpose: Isolated network for torrent traffic
   - Services: VPN container (Gluetun), qBittorrent
   - Security: All torrent traffic forced through VPN, no direct internet access

4. **orion_monitoring** (Optional Monitoring Network)
   - Purpose: Metrics collection and logging
   - Services: Prometheus, Loki, Promtail, exporters
   - Security: Internal-only, scrapes metrics from all nodes

### Service Categories (Docker Compose Profiles)

#### Core Profile (`core`)
- **Traefik v3** - Reverse proxy, SSL termination, routing
- **Authelia** - Single Sign-On (SSO), 2FA, access control

#### Media Profiles
- **media-core** - Main media services
  - Jellyfin (media server)
  - Sonarr (TV shows)
  - Radarr (Movies)
  - Bazarr (Subtitles)
  - Prowlarr (Indexer manager)
  - qBittorrent (torrent client, behind VPN)
  - Jellyseerr (media requests)
  - VPN (Gluetun with ProtonVPN)

- **media-ai** - AI-powered media enhancement
  - Recommendarr (AI recommendations based on viewing habits)

#### Cloud Profile (`cloud`)
- Nextcloud (file sync, calendar, contacts, collaboration)
- PostgreSQL 16 (Nextcloud database)

#### Search Profile (`search`)
- SearXNG (privacy-respecting metasearch engine)

#### Monitoring Profile (`monitoring`)
- Prometheus (metrics collection)
- Grafana (dashboards and visualization)
- Loki (log aggregation)
- Promtail (log collection)
- Uptime Kuma (uptime monitoring)

#### Home Automation Profile (`home-automation`)
- Home Assistant (smart home hub)

#### Maintenance Profile (`maintenance`)
- Homepage (unified dashboard)
- Watchtower (automatic container updates)
- Autoheal (automatic container restart on health check failure)
- Cleanuparr (Radarr cleanup automation)
- Decluttarr (Sonarr cleanup automation)
- Unpackerr (automatic archive extraction)

## Data Flow Examples

### Media Download Flow
```
User Request (Jellyseerr)
    |
    v
Sonarr/Radarr (decides what to download)
    |
    v
Prowlarr (finds torrent/NZB)
    |
    v
qBittorrent (downloads via VPN)
    |
    v
Sonarr/Radarr (imports with hardlink to library)
    |
    v
Jellyfin (plays media)
```

### Authentication Flow
```
User -> https://jellyfin.local
    |
    v
Traefik (receives request)
    |
    v
Authelia (checks authentication)
    |
    +---> Not authenticated: Redirect to auth.local
    |
    +---> Authenticated: Forward to Jellyfin
```

### Monitoring Flow
```
CoreSrv Services + Pi DNS + Pi NetSec
    |
    v
Prometheus (scrapes metrics every 15s)
    |
    v
Grafana (visualizes metrics)
    |
    v
User views dashboards at https://grafana.local
```

## Storage Layout

### Host Directory Structure

```
/srv/orion-sentinel-core-sentinel-core/
├── config/                    # Application configurations
│   ├── traefik/
│   ├── authelia/
│   ├── jellyfin/
│   ├── sonarr/
│   ├── radarr/
│   ├── prowlarr/
│   ├── qbittorrent/
│   ├── jellyseerr/
│   ├── recommendarr/
│   ├── nextcloud/
│   ├── searxng/
│   ├── prometheus/
│   ├── grafana/
│   ├── loki/
│   ├── promtail/
│   ├── uptime-kuma/
│   ├── homeassistant/
│   └── homepage/
├── data/                      # Application data
├── media/                     # Media files (hardlink-friendly layout)
│   ├── torrents/              # qBittorrent downloads
│   │   ├── movies/
│   │   └── tv/
│   └── library/               # Final media library
│       ├── movies/
│       └── tv/
├── cloud/                     # Nextcloud data
│   ├── db/                    # PostgreSQL database
│   ├── app/                   # Nextcloud application files
│   └── data/                  # User files
└── monitoring/                # Monitoring data
    ├── prometheus/
    ├── grafana/
    └── loki/
```

### Hardlink-Friendly Media Layout

The media directory structure follows Trash-Guides recommendations:
- Downloads and library on same filesystem
- Enables instant "moves" via hardlinks (no copying)
- Saves disk space (one physical file, multiple references)
- Faster imports (instant vs. slow copy)

## Security Posture

### Defense in Depth

1. **Network Segmentation**
   - VPN traffic isolated in orion_vpn network
   - Internal services not exposed to proxy network
   - Monitoring network separate from production

2. **Zero-Trust Access Control**
   - All web UIs protected by Traefik reverse proxy
   - Default policy: Deny all, require Authelia SSO
   - 2FA enabled for administrative access
   - Per-service access control policies

3. **Privacy Protection**
   - All torrent traffic forced through VPN (ProtonVPN)
   - DNS queries handled by local Pi-hole (no upstream tracking)
   - SearXNG for privacy-respecting search
   - No telemetry in containerized services

4. **Secrets Management**
   - All secrets in .env files (not committed to git)
   - .env.*.example templates with placeholders
   - Authelia encryption keys for sensitive data
   - Database passwords isolated per service

## Monitoring & Observability

### Metrics Collection
- Prometheus scrapes all services (CoreSrv + Pi DNS + Pi NetSec)
- Node exporters on all hosts (CPU, RAM, disk, network)
- cAdvisor for container metrics
- Service-specific exporters (Pi-hole, Traefik, etc.)

### Log Aggregation
- Promtail collects Docker container logs
- Loki stores and indexes logs
- Grafana provides unified log/metric viewing

### Uptime Monitoring
- Uptime Kuma monitors service availability
- Tracks CoreSrv node services, Pi services, external connectivity
- Alerting via notifications (email, Slack, etc.)

## Disaster Recovery

### Backup Strategy

**Critical Data:**
1. Nextcloud: `/srv/orion-sentinel-core-sentinel-core/cloud/` (daily encrypted backups)
2. Home Assistant: `/srv/orion-sentinel-core-sentinel-core/config/homeassistant/` (weekly backups)
3. Monitoring: Grafana dashboards, Prometheus data (optional)

**Configuration:**
- All configuration in `/srv/orion-sentinel-core-sentinel-core/config/`
- Backed up weekly
- Version controlled where possible

**Media:**
- Media library is replaceable (can be re-downloaded)
- Focus backup resources on irreplaceable data

### Recovery Plan
1. Reinstall host OS (Ubuntu/Debian)
2. Restore `/srv/orion-sentinel-core-sentinel-core/` from backup
3. Clone this repository
4. Copy `.env.*.example` → `.env.*` and adjust paths
5. Run `docker compose --profile all up -d`
6. Verify services come up healthy

## Future Expansion

### Planned Additions
- Additional monitoring dashboards for cross-node correlation
- Automated backup solution (Restic to cloud storage)
- VPN split-tunneling for selective routing
- Additional Home Assistant integrations

### Scalability Considerations
- Profile-based deployment allows selective service hosting
- Can migrate heavy services to dedicated hardware
- Network architecture supports additional nodes
- Monitoring designed to scale to 10+ nodes

## References

- Trash-Guides: https://trash-guides.info/
- AdrienPoupa/docker-compose-nas: https://github.com/AdrienPoupa/docker-compose-nas
- navilg/media-stack: https://github.com/navilg/media-stack

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
