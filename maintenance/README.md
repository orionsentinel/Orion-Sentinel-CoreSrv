# Maintenance Stack: Homepage + Watchtower + Autoheal + Media Cleaners

## Overview

The maintenance profile provides tools for managing, monitoring, and maintaining the Orion-Sentinel-CoreSrv stack:

- **Homepage** - Unified dashboard for all services
- **Watchtower** - Automatic container image updates
- **Autoheal** - Automatic restart of unhealthy containers
- **Cleanuparr** - Radarr cleanup automation
- **Decluttarr** - Sonarr cleanup automation
- **Unpackerr** - Automatic archive extraction

## What Lives Here

```
maintenance/
├── homepage/            # Homepage dashboard config
│   ├── services.yml     # Service definitions (to be created)
│   ├── widgets.yml      # Dashboard widgets (to be created)
│   └── bookmarks.yml    # Quick links (to be created)
└── README.md            # This file
```

## Services

### Homepage

**Purpose:** Unified dashboard for all Orion home lab services

**Key Features:**
- Clean, modern UI
- Service status monitoring
- Widget support (weather, search, calendar)
- Bookmarks and quick links
- Docker integration (automatic service discovery)
- Custom CSS/JS support

**Access:**
- Web UI: `https://home.local` (protected by Authelia)

**Configuration:**
- Services: `maintenance/homepage/services.yml`
- Widgets: `maintenance/homepage/widgets.yml`
- Bookmarks: `maintenance/homepage/bookmarks.yml`

### Watchtower

**Purpose:** Automatic Docker image updates

**Key Features:**
- Monitors for new image versions
- Automatically pulls and restarts containers
- Configurable schedule
- Notification support
- Cleanup old images

**⚠️ WARNING:** Only enable after your stack is stable!

**Configuration:**
- Schedule: Set in `.env.maintenance` (default: Sundays at 3 AM)
- Enable/Disable: `WATCHTOWER_ENABLED=true/false`

**Recommended Approach:**
1. Start with `WATCHTOWER_ENABLED=false`
2. Manually update and test for 2-4 weeks
3. Enable Watchtower only for stable services
4. Exclude critical services (databases, Authelia)

### Autoheal

**Purpose:** Automatically restart unhealthy containers

**Key Features:**
- Monitors container health checks
- Restarts containers that fail health checks
- Configurable restart thresholds
- Low overhead

**How It Works:**

```
Container fails health check
    ↓
Autoheal detects unhealthy status
    ↓
Waits for configured threshold
    ↓
Restarts container
    ↓
Container recovers (hopefully)
```

**Configuration:**
- Interval: 60 seconds (check frequency)
- Automatic, no manual config needed

**Requirements:**
Services must define health checks in `compose.yml`:

```yaml
healthcheck:
  test: ["CMD", "curl", "-f", "http://localhost:8096/health"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 40s
```

### Cleanuparr

**Purpose:** Automatic Radarr library cleanup

**Key Features:**
- Remove watched movies based on criteria
- Disk space threshold triggers
- Quality-based cleanup (keep high quality, remove low)
- Configurable rules per tag/folder

**⚠️ WARNING:** Can delete media files! Test carefully!

**Configuration:**
- Enable: `CLEANUPARR_ENABLED=true/false`
- Radarr URL: Set in `.env.maintenance`
- Radarr API Key: From Radarr settings

**Recommended Rules:**
- Remove movies watched > 6 months ago
- Keep movies rated > 8.0
- Remove when disk < 10% free
- Exclude favorites (use Radarr tags)

### Decluttarr

**Purpose:** Automatic Sonarr library cleanup

**Key Features:**
- Remove watched TV episodes/seasons
- Handle ended series
- Disk space management
- Per-series rules

**⚠️ WARNING:** Can delete media files! Test carefully!

**Configuration:**
- Enable: `DECLUTTARR_ENABLED=true/false`
- Sonarr URL: Set in `.env.maintenance`
- Sonarr API Key: From Sonarr settings

**Recommended Rules:**
- Remove episodes watched > 3 months ago
- Keep current season of ongoing shows
- Remove ended series after 1 year
- Exclude favorites (use Sonarr tags)

### Unpackerr

**Purpose:** Automatic extraction of compressed downloads

**Key Features:**
- Monitors download folders
- Extracts .rar, .zip, .7z files
- Cleans up archives after extraction
- Integrates with Sonarr/Radarr

**Configuration:**
- Enable: `UNPACKERR_ENABLED=true/false`
- Sonarr/Radarr URLs and API keys

**How It Works:**

```
Download completes (compressed)
    ↓
Unpackerr detects archive
    ↓
Extracts files to download folder
    ↓
Sonarr/Radarr processes extracted files
    ↓
Unpackerr deletes archive
```

## Homepage Configuration

### Example services.yml

```yaml
---
# My Homepage Configuration

# Media Services
- Media:
    - Jellyfin:
        href: https://jellyfin.local
        description: Media Server
        icon: jellyfin.png
        server: my-docker
        container: jellyfin
        
    - Jellyseerr:
        href: https://requests.local
        description: Request Movies & TV
        icon: jellyseerr.png
        server: my-docker
        container: jellyseerr
        
    - Sonarr:
        href: https://sonarr.local
        description: TV Show Management
        icon: sonarr.png
        server: my-docker
        container: sonarr
        widget:
          type: sonarr
          url: http://sonarr:8989
          key: {{SONARR_API_KEY}}
        
    - Radarr:
        href: https://radarr.local
        description: Movie Management
        icon: radarr.png
        server: my-docker
        container: radarr
        widget:
          type: radarr
          url: http://radarr:7878
          key: {{RADARR_API_KEY}}
        
    - qBittorrent:
        href: https://qbit.local
        description: Torrent Client
        icon: qbittorrent.png
        server: my-docker
        container: qbittorrent
        widget:
          type: qbittorrent
          url: http://vpn:8080
          username: admin
          password: {{QBIT_PASSWORD}}

# Cloud & Search
- Cloud:
    - Nextcloud:
        href: https://cloud.local
        description: Cloud Storage
        icon: nextcloud.png
        server: my-docker
        container: nextcloud
        
    - SearXNG:
        href: https://search.local
        description: Private Search
        icon: searxng.png
        server: my-docker
        container: searxng

# Monitoring
- Monitoring:
    - Grafana:
        href: https://grafana.local
        description: Dashboards
        icon: grafana.png
        server: my-docker
        container: grafana
        
    - Prometheus:
        href: https://prometheus.local
        description: Metrics
        icon: prometheus.png
        server: my-docker
        container: prometheus
        
    - Uptime Kuma:
        href: https://status.local
        description: Uptime Monitoring
        icon: uptime-kuma.png
        server: my-docker
        container: uptime-kuma

# Core Services
- Core:
    - Traefik:
        href: https://traefik.local
        description: Reverse Proxy
        icon: traefik.png
        server: my-docker
        container: traefik
        widget:
          type: traefik
          url: http://traefik:8080
        
    - Authelia:
        href: https://auth.local
        description: SSO Authentication
        icon: authelia.png
        server: my-docker
        container: authelia

# External Services (Pi Nodes)
- Pi Infrastructure:
    - Pi-hole (DNS):
        href: http://192.168.1.10/admin  # Adjust IP
        description: DNS & Ad Blocking
        icon: pi-hole.png
        
    - Orion Sentinel (NetSec):
        href: http://192.168.1.20  # Adjust IP
        description: Network Security
        icon: shield.png
```

### Example widgets.yml

```yaml
---
# Homepage Widgets

- search:
    provider: custom
    url: https://search.local
    target: _blank

- resources:
    cpu: true
    memory: true
    disk: /srv/orion-sentinel-core

- datetime:
    text_size: xl
    format:
      timeStyle: short
      dateStyle: short
```

### Example bookmarks.yml

```yaml
---
# Quick Links

- Orion Home Lab:
    - GitHub:
        - href: https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv
          icon: github.png
    - Documentation:
        - Trash-Guides:
            - href: https://trash-guides.info/
              icon: book.png
        - Servarr Wiki:
            - href: https://wiki.servarr.com/
              icon: book.png

- Media:
    - TMDB:
        - href: https://www.themoviedb.org/
          icon: themoviedb.png
    - Trakt:
        - href: https://trakt.tv/
          icon: trakt.png

- Monitoring:
    - Docker Hub:
        - href: https://hub.docker.com/
          icon: docker.png
```

## Usage Recommendations

### When to Enable Each Tool

**Immediately (Day 1):**
- ✅ **Homepage** - Central dashboard, no risk
- ✅ **Autoheal** - Automatic restart of failed containers, low risk

**After 2-4 Weeks (Stable Stack):**
- ⚠️ **Unpackerr** - Test with a few downloads first
- ⚠️ **Watchtower** - Start with dry-run mode, then enable for non-critical services

**After 2-3 Months (Well-Tested):**
- ⚠️ **Cleanuparr** - Run in dry-run mode first, verify rules
- ⚠️ **Decluttarr** - Run in dry-run mode first, verify rules

### Best Practices

**Watchtower:**
1. Start disabled: `WATCHTOWER_ENABLED=false`
2. Test manual updates for 1 month
3. Enable for stable services only
4. Exclude critical services:
   ```yaml
   labels:
     - "com.centurylinklabs.watchtower.enable=false"
   ```
5. Monitor update logs carefully

**Autoheal:**
1. Enable immediately (low risk)
2. Ensure services have proper health checks
3. Monitor restart frequency (if constant, fix the issue!)

**Media Cleaners (Cleanuparr/Decluttarr):**
1. Start completely disabled
2. After 2-3 months, enable in dry-run mode
3. Review what would be deleted
4. Adjust rules to protect favorites
5. Enable for real, monitor closely
6. Always keep backups!

## Troubleshooting

### Homepage Not Showing Services

```bash
# Check Homepage logs
docker compose logs homepage

# Verify docker socket mount
docker compose exec homepage ls -la /var/run/docker.sock

# Check services.yml syntax
docker compose exec homepage cat /app/config/services.yml
```

### Watchtower Not Updating

```bash
# Check Watchtower logs
docker compose logs watchtower

# Verify schedule (cron format)
# Example: "0 0 3 * * 0" = Sundays at 3 AM

# Check container labels
docker inspect <container> | grep watchtower
```

### Autoheal Not Restarting Containers

```bash
# Check Autoheal logs
docker compose logs autoheal

# Verify container has health check
docker inspect <container> | grep -A 10 Health

# Check if container is actually unhealthy
docker compose ps
```

### Media Cleaners Deleting Too Much

```bash
# Immediately disable
CLEANUPARR_ENABLED=false
DECLUTTARR_ENABLED=false

# Restore from backup (if needed)
# Review rules and adjust criteria

# Re-enable in dry-run mode first
```

## Monitoring Maintenance Tasks

### Check Watchtower Activity

```bash
# View recent updates
docker compose logs watchtower --since 24h

# Check for errors
docker compose logs watchtower | grep -i error
```

### Check Autoheal Activity

```bash
# View restart events
docker compose logs autoheal | grep -i restart

# Frequent restarts = underlying issue to fix!
```

### Check Media Cleanup Activity

```bash
# Cleanuparr activity
docker compose logs cleanuparr | grep -i deleted

# Decluttarr activity
docker compose logs decluttarr | grep -i deleted
```

## TODO

- [ ] Create Homepage configuration files (services.yml, widgets.yml, bookmarks.yml)
- [ ] Configure Homepage Docker integration
- [ ] Add health checks to all services in compose.yml
- [ ] Enable Autoheal (low risk)
- [ ] Test Unpackerr with sample downloads
- [ ] After 1 month: Test Watchtower in dry-run mode
- [ ] After 2 months: Configure Cleanuparr/Decluttarr rules (dry-run first)
- [ ] Document backup/restore procedures
- [ ] Set up notifications for Watchtower updates
- [ ] Create Homepage custom theme (optional)

## References

- Homepage: https://gethomepage.dev/
- Watchtower: https://containrrr.dev/watchtower/
- Autoheal: https://github.com/willfarrell/docker-autoheal
- Unpackerr: https://github.com/davidnewhall/unpackerr
- Docker Health Checks: https://docs.docker.com/engine/reference/builder/#healthcheck

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
