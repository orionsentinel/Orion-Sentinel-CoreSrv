# Orion-Sentinel-CoreSrv Topology & Deployment Modes

## Overview

Orion-Sentinel-CoreSrv serves as the central observability and services hub in a multi-node home lab architecture. The system supports two deployment modes to accommodate different infrastructure maturity levels.

## Architecture

### Physical Topology

```
Internet
  ↓
Router (192.168.8.1)
  ↓
├─ CoreSrv (192.168.8.xxx)      [Main Services Hub]
├─ Pi DNS (192.168.8.240)       [DNS & Ad-blocking] (Optional)
└─ Pi NetSec (192.168.8.241)    [Network Security]  (Optional)
```

### Logical Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                     ORION-SENTINEL-CORESRV                   │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌────────────┐  ┌────────────┐  ┌───────────────────────┐ │
│  │  Traefik   │  │  Authelia  │  │   Observability       │ │
│  │ (Reverse   │◄─┤   (SSO)    │  │   - Prometheus        │ │
│  │  Proxy)    │  └────────────┘  │   - Grafana           │ │
│  └──────┬─────┘                   │   - Loki              │ │
│         │                          │   - Promtail          │ │
│         │                          │   - Uptime Kuma       │ │
│         ↓                          └───────────────────────┘ │
│  ┌─────────────────────────────────────────────────────────┐│
│  │              Protected Services                          ││
│  ├──────────────┬──────────────┬─────────────┬────────────┤│
│  │ Media Stack  │ Cloud        │ Search      │ Home Auto  ││
│  │ - Jellyfin   │ - Nextcloud  │ - SearXNG   │ - HA       ││
│  │ - Sonarr     │              │             │            ││
│  │ - Radarr     │              │             │            ││
│  │ - qBittorrent│              │             │            ││
│  │ - Jellyseerr │              │             │            ││
│  └──────────────┴──────────────┴─────────────┴────────────┘│
└─────────────────────────────────────────────────────────────┘
         ↑ Metrics & Logs            ↑ Metrics & Logs
         │ (Optional)                │ (Optional)
    ┌────┴──────┐              ┌─────┴──────┐
    │  Pi DNS   │              │ Pi NetSec  │
    │ 192.168   │              │ 192.168    │
    │  .8.240   │              │  .8.241    │
    └───────────┘              └────────────┘
```

## Deployment Modes

### Mode 1: Standalone Mode (CoreSrv Only)

**Use Case:** Initial deployment, testing, or when Pi nodes are not yet available.

**Characteristics:**
- CoreSrv runs fully independently
- All core services are functional
- Pi targets show as "down" in Prometheus (expected and tolerated)
- Pi routes return 503 Service Unavailable (expected)
- Zero-trust SSO protection active for all admin services

**Services Available:**
- ✅ Traefik reverse proxy with HTTPS
- ✅ Authelia SSO authentication
- ✅ Media stack (Jellyfin, Sonarr, Radarr, qBittorrent, Jellyseerr)
- ✅ Cloud services (Nextcloud)
- ✅ Privacy search (SearXNG)
- ✅ Home automation (Home Assistant)
- ✅ Complete observability stack (Prometheus, Grafana, Loki, Promtail, Uptime Kuma)
- ✅ Maintenance tools (Homepage, Watchtower, Autoheal)

**Limitations:**
- No Pi-hole metrics
- No Unbound metrics
- No NetSec AI metrics
- No remote Pi admin access via Traefik

**Startup:**
```bash
# Start core services only
./orionctl.sh up-core

# Start core + observability
./orionctl.sh up-observability

# Start everything except Pi nodes
./orionctl.sh up-full
```

### Mode 2: Integrated Mode (CoreSrv + Pi Nodes)

**Use Case:** Complete home lab deployment with DNS filtering and network security monitoring.

**Characteristics:**
- CoreSrv + DNS Pi + NetSec Pi working together
- Centralized observability for entire infrastructure
- SSO-protected access to Pi admin interfaces
- Complete metrics and logs aggregation
- Single pane of glass for entire home lab

**Additional Capabilities:**
- ✅ Pi-hole metrics (DNS queries, blocked domains, clients)
- ✅ Unbound metrics (recursive DNS performance)
- ✅ Pi node health metrics (CPU, RAM, disk, network)
- ✅ NetSec AI monitoring (if deployed)
- ✅ Reverse proxy access to Pi UIs via Traefik
  - `https://dns.local` → Pi-hole admin (192.168.8.240)
  - `https://security.local` → NetSec AI stack (192.168.8.241:8080)
- ✅ Centralized log aggregation from all nodes

**Prerequisites:**
- Pi DNS node at 192.168.8.240 with exporters deployed
- Pi NetSec node at 192.168.8.241 with exporters deployed
- Network connectivity between CoreSrv and Pi nodes
- Firewall rules allowing metric scraping (ports 9100, 9167, 9617)

**Deployment:**

1. **Deploy CoreSrv (this repository)**
   ```bash
   ./orionctl.sh up-full
   ```

2. **Deploy DNS Pi exporters** (see `agents/pi-dns/README.md`)
   ```bash
   # On Pi DNS (192.168.8.240)
   docker compose -f exporters-docker-compose.yml up -d
   ```

3. **Deploy NetSec Pi exporters** (see `agents/pi-netsec/README.md`)
   ```bash
   # On Pi NetSec (192.168.8.241)
   docker compose -f exporters-docker-compose.yml up -d
   ```

4. **Verify metrics collection**
   - Check Prometheus targets: `https://prometheus.local/targets`
   - All Pi targets should show "UP" status
   - View dashboards: `https://grafana.local`

## Network Architecture

### Docker Networks

| Network | Purpose | Attached Services |
|---------|---------|-------------------|
| `orion_proxy` | External-facing traffic | Traefik, Authelia, all user-facing services |
| `orion_internal` | Service-to-service communication | Authelia, Prometheus, Loki, Grafana |
| `orion_monitoring` | Metrics collection | Prometheus, Grafana, Loki, Promtail, cAdvisor, (node-exporter uses host network) |
| `orion_vpn` | VPN-isolated traffic | qBittorrent, VPN container |
| `orion_cloud` | Nextcloud stack | Nextcloud, PostgreSQL |

### Port Mapping

#### CoreSrv Exposed Ports
- `80/tcp` → Traefik HTTP (redirects to HTTPS)
- `443/tcp` → Traefik HTTPS (all services)

#### Pi DNS (192.168.8.240)
- `9100/tcp` → node_exporter (host metrics)
- `9167/tcp` → unbound_exporter (DNS metrics)
- `9617/tcp` → pihole_exporter (Pi-hole metrics)
- `3100/tcp` → Loki (log ingestion, optional)

#### Pi NetSec (192.168.8.241)
- `9100/tcp` → node_exporter (host metrics)
- `8080/tcp` → NetSec AI stack UI
- `3100/tcp` → Loki (log ingestion, optional)

## Service Routing

### Traefik Routes

All services use Authelia SSO authentication via the `secure-chain` middleware (security headers + SSO).

#### CoreSrv Services
- `https://auth.local` → Authelia SSO portal
- `https://traefik.local` → Traefik dashboard
- `https://prometheus.local` → Prometheus
- `https://grafana.local` → Grafana
- `https://status.local` → Uptime Kuma
- `https://home.local` → Homepage dashboard
- `https://jellyfin.local` → Jellyfin media server
- `https://requests.local` → Jellyseerr
- `https://qbit.local` → qBittorrent
- `https://sonarr.local` → Sonarr
- `https://radarr.local` → Radarr
- `https://bazarr.local` → Bazarr
- `https://prowlarr.local` → Prowlarr
- `https://recommend.local` → Recommendarr
- `https://cloud.local` → Nextcloud
- `https://search.local` → SearXNG

#### Pi Node Services (Integrated Mode Only)
- `https://dns.local` → Pi DNS admin UI (192.168.8.240:80)
- `https://security.local` → NetSec AI stack (192.168.8.241:8080)

### Middleware Chain

All admin services use the `secure-chain@file` middleware:

```yaml
secure-chain:
  chain:
    middlewares:
      - security-headers  # OWASP security headers
      - authelia-forwardauth  # SSO authentication
```

**Security Headers Applied:**
- HTTP Strict Transport Security (HSTS)
- Content Security Policy (CSP)
- X-Frame-Options (clickjacking protection)
- X-Content-Type-Options (MIME sniffing protection)
- Referrer-Policy
- Permissions-Policy

## Metrics & Logs

### Prometheus Scrape Targets

#### CoreSrv Targets (Always Available)
- `prometheus` - Prometheus self-monitoring
- `coresrv-node` - Host metrics (node_exporter on localhost:9100)
- `coresrv-cadvisor` - Container metrics (cAdvisor)

#### Pi DNS Targets (Optional - Integrated Mode)
- `pi-dns-node` - Pi DNS host metrics (192.168.8.240:9100)
- `pihole` - Pi-hole DNS metrics (192.168.8.240:9617)
- `unbound` - Unbound recursive DNS metrics (192.168.8.240:9167)

#### Pi NetSec Targets (Optional - Integrated Mode)
- `pi-netsec-node` - Pi NetSec host metrics (192.168.8.241:9100)

**Tolerance for Unavailable Targets:**
- Prometheus will mark unavailable targets as "DOWN" but continue operating
- No impact on CoreSrv functionality
- Grafana dashboards gracefully handle missing data sources

### Log Aggregation

**Loki Architecture:**
- CoreSrv Loki receives logs from:
  - CoreSrv Promtail (local Docker containers)
  - Pi DNS Promtail (optional, via network)
  - Pi NetSec Promtail (optional, via network)

**Log Sources:**
- Docker container logs (all CoreSrv services)
- System logs (via Promtail)
- Application logs (service-specific)

**Retention:**
- Default: 7 days (configurable via `LOKI_RETENTION_PERIOD`)
- Adjustable based on disk space

## High Availability Considerations

### Current Setup
- Single-instance deployment
- Suitable for home lab use
- Data persistence via Docker volumes

### Future HA Enhancements
- [ ] Multiple CoreSrv instances behind load balancer
- [ ] Shared storage for media and cloud data (NFS/Ceph)
- [ ] External Prometheus/Grafana storage (S3/GCS)
- [ ] Alertmanager for redundant alerting
- [ ] Database replication for stateful services

## Security Architecture

### Zero-Trust Model
1. **Default Deny:** All routes require authentication by default
2. **SSO Enforcement:** Authelia protects all admin services
3. **Security Headers:** OWASP recommendations applied via middleware
4. **Network Segmentation:** Isolated Docker networks for different service tiers
5. **VPN Isolation:** Torrent traffic isolated via VPN-only network

### Authentication Flow
```
User → Traefik (HTTPS) → Authelia ForwardAuth → Service
         ↑                      ↓
         └── If not authenticated, redirect to auth.local
```

### Session Management
- Redis-backed session storage
- 12-hour session expiration (configurable)
- 5-minute inactivity timeout
- Remember me: 1 month

## Backup & Recovery

### Critical Data
- Authelia database (`/config/authelia/db.sqlite3`)
- Authelia users (`/config/authelia/users.yml`)
- Grafana dashboards (`/monitoring/grafana/data`)
- Prometheus data (`/monitoring/prometheus/data`)
- Service configurations (`/config/*/`)

### Backup Strategy
- Daily automated backups (see `docs/BACKUP-RESTORE.md`)
- Retention: 7 daily, 4 weekly, 3 monthly
- Off-site backup recommended for disaster recovery

## Troubleshooting

### Standalone Mode Issues

**Symptom:** Prometheus shows Pi targets as "DOWN"
- **Expected:** This is normal in standalone mode
- **Action:** No action needed unless you want to deploy Pi nodes

**Symptom:** Traefik returns 503 for dns.local or security.local
- **Expected:** Backends are not available in standalone mode
- **Action:** Deploy Pi nodes or ignore these routes

### Integrated Mode Issues

**Symptom:** Pi targets remain "DOWN" in Prometheus
- **Cause:** Network connectivity, firewall, or exporter not running
- **Action:** 
  1. Verify Pi exporters are running: `docker ps` on Pi node
  2. Test connectivity: `curl http://192.168.8.240:9100/metrics`
  3. Check firewall rules on Pi nodes

**Symptom:** Cannot access Pi UIs via Traefik (dns.local, security.local)
- **Cause:** Backend services not running or network issue
- **Action:**
  1. Verify Pi services are accessible: `curl http://192.168.8.240`
  2. Check Traefik logs: `docker logs traefik`
  3. Verify healthchecks pass in `orion-remotes.yml`

## Scaling Considerations

### Current Capacity
- Single-node CoreSrv suitable for:
  - ~10 concurrent users
  - ~20 media streams (Jellyfin)
  - ~100k Prometheus series
  - ~50GB/day log ingestion

### Scaling Options
1. **Vertical:** Increase CoreSrv resources (CPU, RAM, disk)
2. **Horizontal:** Add more Pi nodes for distributed workload
3. **Service Split:** Move services to dedicated nodes (e.g., Nextcloud to separate server)

## Migration Path

### From Standalone to Integrated
1. Deploy Pi nodes with exporters
2. No CoreSrv changes required
3. Verify metrics appear in Prometheus
4. Update Grafana dashboards to include Pi data

### From Integrated to Standalone
1. Pi nodes can be taken offline anytime
2. Prometheus will mark targets as DOWN
3. No service interruption on CoreSrv
4. Grafana dashboards will show gaps in Pi data

## References

- [Deployment Checklist](DEPLOYMENT-CHECKLIST.md)
- [Backup & Restore](BACKUP-RESTORE.md)
- [Runbooks](RUNBOOKS.md)
- [Security Hardening](SECURITY-HARDENING.md)
- [Pi DNS Deployment](../agents/pi-dns/README.md)
- [Monitoring Stack](../monitoring/README.md)
