# Orion Sentinel CoreSrv - Docker Compose Profiles

## Overview

This document provides a comprehensive guide to all Docker Compose profiles available in the Orion Sentinel CoreSrv stack. Profiles allow you to selectively start groups of services based on your needs.

## Available Profiles

### Finance Profile: `finance`

**Services:** Firefly III (personal finance manager)

**What's included:**
- Firefly III application
- MariaDB database
- Data Importer (for bank integrations)
- Automated cron tasks

**Start command:**
```bash
./scripts/orionctl up apps --profile finance
# Or: docker compose --profile finance up -d
```

**Access:** https://firefly.orion.lan  
**Documentation:** `stacks/apps/firefly/README.md`

**Use case:** Track personal finances, budgets, and expenses

---

### Cloud Profile: `cloud`

**Services:** Nextcloud (self-hosted cloud storage)

**What's included:**
- Nextcloud application
- PostgreSQL database
- Redis cache
- Background cron processor

**Start command:**
```bash
./scripts/orionctl up cloud --profile cloud
# Or: docker compose --profile cloud up -d
```

**Access:** https://cloud.orion.lan  
**Documentation:** `stacks/cloud/nextcloud/README.md`

**Use case:** File sync, calendar, contacts, collaboration

---

### Portal Profiles: `portal_homepage` | `portal_homearr`

**Services:** Homepage (default) or Homarr (alternative)

**What's included:**
- Docker socket proxy (secure Docker API access)
- Homepage dashboard OR Homarr dashboard
- Service widgets and integrations

**Start commands:**
```bash
# Homepage (recommended)
./scripts/orionctl up portal --profile portal_homepage

# Homarr (alternative)
./scripts/orionctl up portal --profile portal_homearr
```

**Access:** https://portal.orion.lan  
**Documentation:** `stacks/portal/README.md`

**Use case:** Unified dashboard for all services

**Note:** Only run one portal at a time (same URL for both)

---

### Network Mapping Profile: `net_map`

**Services:** NetAlertX (network device discovery)

**What's included:**
- NetAlertX scanner
- Nginx proxy for Traefik integration
- Device inventory and alerts

**Start command:**
```bash
./scripts/orionctl up observability --profile net_map
# Or: docker compose --profile net_map up -d
```

**Access:** https://netmap.orion.lan  
**Documentation:** `stacks/observability/netmap/README.md`

**Use case:** Monitor network devices, get alerts for new devices

---

### Recipe Sync Profile: `food_sync`

**Services:** Mealie Recipe Sync (automated recipe importing)

**What's included:**
- Python-based sync service
- RSS feed processing
- URL list importing
- Sitemap scanning

**Start command:**
```bash
./scripts/orionctl up apps --profile food_sync
# Or: docker compose --profile food_sync up -d
```

**Access:** No web UI (background service)  
**Documentation:** `stacks/apps/mealie-sync/README.md`

**Use case:** Automatically import recipes from food blogs into Mealie

**Prerequisites:** Requires Mealie to be running (from apps stack)

---

## Core Stacks (No Profile Required)

### Ingress Stack

**Services:** Traefik reverse proxy

**Start command:**
```bash
./scripts/orionctl up ingress
```

**Access:** https://traefik.orion.lan  
**Documentation:** `stacks/ingress/`

**Purpose:** HTTPS routing, SSL termination

---

### Observability Stack

**Services:** Grafana, Prometheus, Loki, Promtail, Uptime Kuma, exporters

**Start command:**
```bash
./scripts/orionctl up observability
```

**Access:**
- https://grafana.orion.lan
- https://prometheus.orion.lan
- https://uptime.orion.lan

**Documentation:** `stacks/observability/`

**Purpose:** Monitoring, metrics, logging, alerting

---

### Home Automation Stack

**Services:** Home Assistant, Node-RED, Mosquitto MQTT, Zigbee2MQTT

**Start command:**
```bash
./scripts/orionctl up home
```

**Access:**
- https://home.orion.lan (Home Assistant)
- https://nodered.orion.lan (Node-RED)
- https://zigbee.orion.lan (Zigbee2MQTT)

**Documentation:**
- `stacks/home/`
- `stacks/home/docs/NODE-RED-INTEGRATION.md`

**Purpose:** Smart home automation and IoT

---

### Apps Stack

**Services:** Mealie, DSMR Reader

**Start command:**
```bash
./scripts/orionctl up apps
```

**Access:**
- https://mealie.orion.lan
- https://dsmr.orion.lan

**Documentation:** `stacks/apps/`

**Purpose:** Recipe management, smart meter monitoring

---

## Quick Start Examples

### Minimal Setup

Start just the essentials:
```bash
./scripts/orionctl up ingress
./scripts/orionctl up portal --profile portal_homepage
```

### Finance & Cloud

Personal productivity stack:
```bash
./scripts/orionctl up ingress
./scripts/orionctl up apps --profile finance
./scripts/orionctl up cloud --profile cloud
./scripts/orionctl up portal --profile portal_homepage
```

### Home Lab Full Stack

Everything except optional profiles:
```bash
./scripts/orionctl up ingress
./scripts/orionctl up observability
./scripts/orionctl up home
./scripts/orionctl up apps
./scripts/orionctl up portal --profile portal_homepage
```

### Add Optional Services

Add finance tracking:
```bash
docker compose --profile finance up -d
```

Add network monitoring:
```bash
docker compose --profile net_map up -d
```

Enable recipe syncing:
```bash
docker compose --profile food_sync up -d
```

## Profile Combinations

You can combine multiple profiles in a single command:

```bash
# Finance + Cloud + Homepage
docker compose \
  --profile finance \
  --profile cloud \
  --profile portal_homepage \
  up -d

# All optional services
docker compose \
  --profile finance \
  --profile cloud \
  --profile portal_homepage \
  --profile net_map \
  --profile food_sync \
  up -d
```

## Environment Variables

Each profile may require specific environment variables. See the corresponding `.env.example` files:

- **Finance:** `stacks/apps/firefly/.env.example`
- **Cloud:** `stacks/cloud/nextcloud/.env.example`
- **Portal:** Use root `.env.example` (includes ORION_UID, ORION_GID, etc.)
- **Network Mapping:** `stacks/observability/netmap/.env.example`
- **Recipe Sync:** `stacks/apps/mealie-sync/.env.example`

## Managing Profiles

### Check Running Services

```bash
docker compose ps
```

### Stop Specific Profile

```bash
docker compose --profile finance down
```

### Restart Profile

```bash
docker compose --profile portal_homepage restart
```

### View Profile Logs

```bash
docker compose --profile finance logs -f
```

## Profile Dependencies

Some profiles depend on other services:

**food_sync depends on:**
- Apps stack (Mealie must be running)
- Ingress stack (for network connectivity)

**portal profiles depend on:**
- Ingress stack (Traefik for routing)
- Other services (to display in dashboard)

**net_map depends on:**
- Ingress stack (Traefik for routing)

Always start the ingress stack first:
```bash
./scripts/orionctl up ingress
```

## Troubleshooting

### Profile Not Starting

**Check logs:**
```bash
docker compose --profile <profile-name> logs
```

**Verify environment variables:**
```bash
# Check if .env exists and has required variables
cat .env | grep VARIABLE_NAME
```

**Validate configuration:**
```bash
docker compose --profile <profile-name> config
```

### Service Not Accessible

**Check Traefik routing:**
```bash
docker logs orion_traefik | grep <service-name>
```

**Verify service is running:**
```bash
docker compose ps | grep <service-name>
```

### Profile Conflicts

Some profiles use the same URL and cannot run simultaneously:
- `portal_homepage` and `portal_homearr` both use `portal.orion.lan`

**Solution:** Stop one before starting the other:
```bash
docker compose --profile portal_homepage down
docker compose --profile portal_homearr up -d
```

## Best Practices

### 1. Start in Order

Start stacks in this recommended order:
1. Ingress (Traefik)
2. Observability (monitoring)
3. Core stacks (home, apps)
4. Optional profiles (finance, cloud, etc.)

### 2. Use orionctl

The `orionctl` script handles profile management automatically:
```bash
./scripts/orionctl up apps
./scripts/orionctl down apps
./scripts/orionctl logs apps
```

### 3. Document Your Setup

Keep track of which profiles you're using in your deployment:
```bash
# Create a deployment notes file
cat > DEPLOYMENT.md << EOF
# My Orion Deployment

Active Profiles:
- finance: Firefly III for expense tracking
- cloud: Nextcloud for file sync
- portal_homepage: Dashboard
- net_map: Network monitoring

Inactive Profiles:
- portal_homearr: Alternative dashboard (not using)
- food_sync: Recipe sync (don't need it)
EOF
```

### 4. Regular Updates

Keep profiles updated by pulling new images:
```bash
docker compose --profile finance pull
docker compose --profile finance up -d
```

### 5. Backup Configuration

Backup profile-specific configuration:
```bash
# Backup Firefly data
sudo tar -czf firefly-backup.tar.gz /srv/orion/internal/appdata/firefly

# Backup Nextcloud data
sudo tar -czf nextcloud-backup.tar.gz /srv/orion/internal/nextcloud-data
```

## Summary Table

| Profile | Service | URL | Dependencies | Purpose |
|---------|---------|-----|--------------|---------|
| `finance` | Firefly III | firefly.orion.lan | Ingress | Finance tracking |
| `cloud` | Nextcloud | cloud.orion.lan | Ingress | Cloud storage |
| `portal_homepage` | Homepage | portal.orion.lan | Ingress | Dashboard (default) |
| `portal_homearr` | Homarr | portal.orion.lan | Ingress | Dashboard (alt) |
| `net_map` | NetAlertX | netmap.orion.lan | Ingress | Network monitoring |
| `food_sync` | Mealie Sync | N/A (background) | Apps (Mealie) | Recipe importing |

---

**For detailed service documentation, see individual README files in each stack directory.**

**Last Updated:** 2024-12-17  
**Maintained by:** Orion Home Lab Team
