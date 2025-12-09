# Orion-Sentinel-CoreSrv - Architecture & Deployment Plan

## Executive Summary

Orion-Sentinel-CoreSrv is a production-ready, modular home lab stack that combines:
- **Media Management** (Jellyfin, Sonarr, Radarr, qBittorrent, etc.)
- **Reverse Proxy & SSO** (Traefik, Authelia)
- **Observability** (Prometheus, Grafana, Loki, Uptime Kuma)
- **Home Automation** (Home Assistant, Zigbee2MQTT, MQTT, Mealie)

This document outlines the architectural design, deployment strategy, and operational procedures based on proven patterns from navilg/media-stack.

## Architecture Overview

### Design Principles

1. **Modularity** - Each module is independent and can run standalone
2. **Simplicity** - One command to deploy each module
3. **Security** - All secrets in .env files, Authelia SSO, VPN for torrents
4. **Observability** - Built-in monitoring and logging
5. **Maintainability** - Clear directory structure, documented workflows

### Module Structure

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORION SENTINEL CORESRV                       │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐          │
│  │ CORE-MEDIA   │  │   TRAEFIK    │  │OBSERVABILITY │          │
│  │  (Profile)   │  │  (Profile)   │  │  (Profile)   │          │
│  ├──────────────┤  ├──────────────┤  ├──────────────┤          │
│  │• Jellyfin    │  │• Traefik     │  │• Prometheus  │          │
│  │• Sonarr      │  │• Authelia    │  │• Grafana     │          │
│  │• Radarr      │  │• Redis       │  │• Loki        │          │
│  │• qBittorrent │  │              │  │• Promtail    │          │
│  │• Prowlarr    │  │              │  │• Uptime Kuma │          │
│  │• Jellyseerr  │  │              │  │• Node Export │          │
│  │• Bazarr      │  │              │  │• cAdvisor    │          │
│  └──────────────┘  └──────────────┘  └──────────────┘          │
│                                                                 │
│  ┌──────────────┐  ┌──────────────┐                           │
│  │HOME-AUTOMATION│  │   EXTRAS     │                           │
│  │  (Profile)   │  │  (Profile)   │                           │
│  ├──────────────┤  ├──────────────┤                           │
│  │• Home Assist │  │• Homepage    │                           │
│  │• Zigbee2MQTT │  │• Watchtower  │                           │
│  │• Mosquitto   │  │• Autoheal    │                           │
│  │• Mealie      │  │• SearXNG     │                           │
│  │• DSMR Reader │  │              │                           │
│  └──────────────┘  └──────────────┘                           │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

### Network Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                      DOCKER NETWORKS                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  orion_media_net         → Media services (standalone)          │
│  orion_gateway_net       → Traefik + Authelia + Redis          │
│  orion_backbone_net      → Cross-module communication          │
│  orion_observability_net → Monitoring services                 │
│  orion_homeauto_net      → Home automation services            │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘

Internet → Router → Host → Traefik (ports 80/443)
                              ↓
                    orion_backbone_net
                              ↓
                    ┌─────────┴─────────┐
                    ↓                   ↓
              Media Services    Home Automation
```

## Directory Layout

### Host Filesystem

```
/srv/orion-sentinel-core/
├── core/                        # Core services (Traefik, Authelia)
│   ├── traefik/
│   │   ├── traefik.yml         # Static config
│   │   ├── dynamic/            # Dynamic configs
│   │   │   ├── security.yml    # Security headers
│   │   │   ├── authelia.yml    # Authelia middleware
│   │   │   └── orion-remotes.yml
│   │   └── acme/               # Let's Encrypt certs
│   ├── authelia/
│   │   ├── configuration.yml   # Authelia config
│   │   └── users.yml           # User database
│   └── redis/data/             # Session storage
│
├── media/
│   ├── config/                 # Service configurations
│   │   ├── jellyfin/
│   │   ├── sonarr/
│   │   ├── radarr/
│   │   ├── qbittorrent/
│   │   ├── prowlarr/
│   │   ├── jellyseerr/
│   │   └── bazarr/
│   └── content/                # Media files
│       ├── downloads/          # qBittorrent downloads
│       │   ├── movies/
│       │   └── tv/
│       └── library/            # Organized library
│           ├── movies/
│           └── tv/
│
├── monitoring/
│   ├── prometheus/
│   │   ├── prometheus.yml      # Scrape configs
│   │   ├── rules/              # Alert rules
│   │   └── data/               # Time-series data
│   ├── grafana/
│   │   ├── data/               # Grafana DB
│   │   ├── provisioning/       # Auto-provisioning
│   │   │   ├── datasources/
│   │   │   └── dashboards/
│   │   └── dashboards/         # Dashboard JSONs
│   ├── loki/data/              # Log storage
│   └── uptime-kuma/data/       # Uptime monitoring
│
├── home-automation/
│   ├── homeassistant/          # HA config & DB
│   ├── zigbee2mqtt/data/       # Zigbee devices
│   ├── mosquitto/              # MQTT broker
│   │   ├── config/
│   │   ├── data/
│   │   └── log/
│   ├── mealie/                 # Recipe manager
│   └── dsmr/                   # Smart meter reader
│
└── cloud/
    └── nextcloud/              # Personal cloud (optional)
```

### Repository Structure

```
Orion-Sentinel-CoreSrv/
├── .env.example                # Master environment template
├── Makefile                    # Simple deployment commands
├── README.md                   # User documentation
├── PLAN.md                     # This document
├── INSTALL.md                  # Installation guide
│
├── compose/                    # Docker Compose files
│   ├── docker-compose.media.yml
│   ├── docker-compose.gateway.yml
│   ├── docker-compose.observability.yml
│   └── docker-compose.homeauto.yml
│
├── env/                        # Module-specific env templates
│   ├── .env.media.modular.example
│   ├── .env.gateway.example
│   ├── .env.observability.example
│   └── .env.homeauto.example
│
├── scripts/
│   ├── bootstrap-coresrv.sh   # Initial setup automation
│   ├── setup.sh               # Interactive setup
│   ├── orionctl.sh            # Service management
│   ├── backup.sh              # Backup automation
│   └── bootstrap_grafana.py   # Grafana setup
│
├── core/                       # Core service configs
│   ├── traefik/
│   └── authelia/
│
├── monitoring/                 # Monitoring configs
│   ├── prometheus/
│   ├── grafana/
│   ├── loki/
│   └── promtail/
│
├── grafana_dashboards/         # Pre-built dashboards
│   ├── README.md
│   └── system-overview.json
│
├── home-automation/            # Home automation configs
│   ├── homeassistant/
│   ├── zigbee2mqtt/
│   ├── mosquitto/
│   ├── mealie/
│   └── dsmr/
│
└── docs/                       # Detailed documentation
    ├── ARCHITECTURE.md
    ├── SETUP-CoreSrv.md
    ├── SECURITY-HARDENING.md
    └── RUNBOOKS.md
```

## Deployment Workflow

### Phase 1: Initial Setup

```bash
# 1. Clone repository
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv

# 2. Run bootstrap script (creates directories, generates secrets)
./scripts/bootstrap-coresrv.sh

# 3. Review and customize configuration
nano .env
nano env/.env.media
nano env/.env.gateway

# 4. Deploy media stack (most critical services)
make up-media
```

### Phase 2: Add Reverse Proxy

```bash
# 1. Configure gateway
nano env/.env.gateway  # Set domain, verify secrets

# 2. Deploy Traefik + Authelia
make up-traefik

# 3. Configure Authelia users
nano /srv/orion-sentinel-core/core/authelia/users.yml
make restart SVC=authelia
```

### Phase 3: Enable Monitoring

```bash
# 1. Deploy observability stack
make up-observability

# 2. Access Grafana
# https://grafana.local (or http://localhost:3000)

# 3. Import dashboards from grafana_dashboards/
```

### Phase 4: Home Automation (Optional)

```bash
# 1. Configure hardware (Zigbee USB, P1 cable)
nano env/.env.homeauto  # Set device paths

# 2. Deploy home automation
make up-homeauto

# 3. Configure Home Assistant
# https://ha.local:8123
```

## Environment Variable Strategy

### Consolidation Approach

1. **Master .env** - Common variables (PUID, PGID, TZ, DOMAIN, paths)
2. **Module env files** - Module-specific settings (VPN, API keys)
3. **No duplication** - Each variable defined once, sourced as needed
4. **Safe defaults** - All variables have working default values

### Required vs Optional Variables

**Required (Must Set):**
- `DOMAIN` - Your domain name
- `PUID` / `PGID` - User/group IDs (run `id`)
- `AUTHELIA_*_SECRET` - Three secrets (auto-generated by bootstrap)

**Optional (Has Defaults):**
- `TZ` - Timezone (defaults to Europe/Amsterdam)
- `*_ROOT` - Data directories (defaults to /srv/orion-sentinel-core/*)
- `VPN_*` - VPN settings (only if using VPN)

### Secret Management

**Generation:**
```bash
openssl rand -hex 32  # Run 3 times for Authelia secrets
```

**Storage:**
- Never commit .env files to git (.gitignore prevents this)
- Store in password manager (1Password, Bitwarden, etc.)
- Backup encrypted copy offsite

**Rotation:**
- Rotate secrets every 6-12 months
- Update .env, restart affected services

## Service Dependencies

### Dependency Graph

```
Media Services (Independent)
  ↓ (optional)
Traefik + Authelia
  ↓ (optional)
Observability Stack
  ↓ (optional)
Home Automation
```

### Startup Order

1. **Media** - Can run completely standalone
2. **Gateway** - Adds reverse proxy to existing services
3. **Observability** - Monitors existing services
4. **Home Automation** - Independent, can run anytime

### Service Health Checks

All services include health checks:
```yaml
healthcheck:
  test: ["CMD-SHELL", "curl -sf http://localhost:PORT/health || exit 1"]
  interval: 30s
  timeout: 10s
  retries: 3
  start_period: 30s
```

## Makefile Commands

### Deployment
- `make up-media` - Start media stack
- `make up-traefik` - Start reverse proxy
- `make up-observability` - Start monitoring
- `make up-homeauto` - Start home automation
- `make up-full` - Start everything

### Management
- `make down` - Stop all services
- `make restart` - Restart all
- `make restart SVC=name` - Restart specific service
- `make logs` - View all logs
- `make logs SVC=name` - View specific service logs
- `make status` - Show service status
- `make health` - Check service health

### Maintenance
- `make pull` - Update images
- `make backup` - Run backup
- `make clean` - Clean up containers

## Monitoring Strategy

### Metrics Collection

**Prometheus scrapes:**
- Node Exporter - Host metrics (CPU, RAM, disk, network)
- cAdvisor - Container metrics
- Service endpoints - Application-specific metrics

**Retention:** 15 days (configurable via `PROMETHEUS_RETENTION_TIME`)

### Log Aggregation

**Loki collects logs from:**
- All Docker containers (via Promtail)
- System logs
- Application logs

**Retention:** 30 days (configurable via `LOKI_RETENTION_PERIOD`)

### Dashboards

**Pre-configured dashboards:**
1. System Overview - Host metrics
2. Container Performance - Docker stats
3. Media Stack - Service-specific metrics
4. Logs - Unified log viewer

**Located in:** `grafana_dashboards/`

### Alerting

**Alert channels:**
- Email (via SMTP)
- Webhook (Discord, Slack, etc.)
- Pushover / Telegram

**Alert rules located in:** `monitoring/prometheus/rules/`

## Security Hardening

### Network Isolation

1. **Media network** - Isolated, no external access
2. **Gateway network** - Traefik + Authelia only
3. **Backbone network** - Controlled cross-module access
4. **No direct port exposure** - All via Traefik

### Authentication

1. **Authelia SSO** - Single sign-on for all services
2. **2FA support** - TOTP, WebAuthn
3. **Access control** - Per-service policies
4. **Session management** - Redis-backed sessions

### VPN for Torrents

1. **Gluetun container** - VPN tunnel
2. **qBittorrent** - Runs inside VPN network
3. **Kill switch** - Automatic if VPN drops
4. **No IP leakage** - Traffic forced through VPN

### Secrets

1. **Environment variables** - Never hardcoded
2. **Auto-generation** - Bootstrap script creates secure secrets
3. **Git ignored** - .env never committed
4. **Encrypted backups** - Store securely

## Backup Strategy

### What to Backup

**Critical:**
- All .env files
- Authelia users database
- Traefik certificates
- Service configurations

**Important:**
- Grafana dashboards
- Prometheus data (recent)
- Home Assistant config

**Optional:**
- Media files (large, can re-download)
- Logs (ephemeral)

### Backup Script

```bash
make backup  # Runs scripts/backup.sh
```

**Creates archive with:**
- All configs
- Environment files
- Service data
- Timestamp and version info

**Exclude from backup:**
- Media files (/srv/orion-sentinel-core/media/content/)
- Large log files
- Docker images (can re-pull)

## Operational Procedures

### Daily Operations

```bash
make status          # Check all services
make health          # Verify health
make logs SVC=xxx    # Investigate issues
```

### Updates

```bash
make pull            # Pull new images
make down            # Stop services
make up-full         # Start with new images
```

### Troubleshooting

**Service won't start:**
```bash
make logs SVC=service-name
docker compose -f compose/docker-compose.xxx.yml ps
```

**Network issues:**
```bash
docker network ls
docker network inspect orion_backbone_net
```

**Permission errors:**
```bash
id  # Check PUID/PGID match
sudo chown -R $USER:$USER /srv/orion-sentinel-core
```

## Scaling & Future Enhancements

### Horizontal Scaling

- Add more media servers (Jellyfin sync)
- Distribute services across nodes
- Load balancing via Traefik

### Additional Services

- Nextcloud (personal cloud)
- Calibre (ebook management)
- Paperless-NGX (document management)
- FreshRSS (RSS reader)

### Advanced Features

- Automated backups to cloud
- Multi-site replication
- Advanced Grafana dashboards
- Custom Prometheus exporters

## Comparison with navilg/media-stack

### Adopted Patterns

✓ Profile-based deployment (vpn, no-vpn, etc.)
✓ Environment variable configuration
✓ Volume management for media
✓ PUID/PGID for permissions
✓ Health checks on all services
✓ Clear documentation

### Enhancements Made

+ Modular compose files (media, gateway, observability, homeauto)
+ Makefile for simple commands
+ Automated bootstrap script
+ Integrated reverse proxy (Traefik)
+ Built-in SSO (Authelia)
+ Full observability stack
+ Home automation integration
+ Comprehensive documentation
+ Pre-built Grafana dashboards

## Conclusion

Orion-Sentinel-CoreSrv provides a production-ready, modular home lab stack that's:

- **Easy to deploy** - One command per module
- **Secure by default** - SSO, VPN, secrets management
- **Observable** - Built-in monitoring and logging
- **Maintainable** - Clear structure, good documentation
- **Flexible** - Enable only what you need

For questions or issues, see:
- [README.md](README.md) - User guide
- [INSTALL.md](INSTALL.md) - Installation
- [docs/](docs/) - Detailed documentation
