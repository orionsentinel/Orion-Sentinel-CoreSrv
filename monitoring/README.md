# Orion-Sentinel-CoreSrv Observability Stack

## Overview

The observability stack provides comprehensive monitoring, metrics collection, log aggregation, and visualization for the entire Orion-Sentinel home lab infrastructure. It supports both **Standalone Mode** (CoreSrv only) and **Integrated Mode** (CoreSrv + Pi nodes).

## Components

### Prometheus (Metrics Collection)
- **Version:** v2.54.0
- **Purpose:** Time-series metrics database and scraping engine
- **Retention:** 15 days (configurable)
- **Access:** `https://prometheus.local`

### Grafana (Visualization)
- **Version:** v11.0.0
- **Purpose:** Metrics visualization and dashboards
- **Access:** `https://grafana.local`
- **Default Credentials:** `admin` / `change_me_to_a_strong_password` (configure in `.env.monitoring`)

### Loki (Log Aggregation)
- **Version:** 2.9.5
- **Purpose:** Log storage and querying
- **Retention:** 7 days (configurable)
- **Access:** Internal only (via Grafana)

### Promtail (Log Shipping)
- **Version:** 2.9.5
- **Purpose:** Collect and forward logs from Docker containers to Loki
- **Scope:** All CoreSrv Docker containers

### Uptime Kuma (Service Monitoring)
- **Version:** 1.23.11
- **Purpose:** Service availability monitoring and status page
- **Access:** `https://status.local`

### node_exporter (Host Metrics)
- **Version:** v1.8.1
- **Purpose:** Export host-level metrics (CPU, RAM, disk, network)
- **Network Mode:** Host (for accurate host metrics)

### cAdvisor (Container Metrics)
- **Version:** v0.49.1
- **Purpose:** Docker container resource usage and performance metrics
- **Metrics:** Per-container CPU, memory, network, disk I/O

## Architecture

### Standalone Mode (CoreSrv Only)

```
┌─────────────────────────────────────────────────┐
│              CoreSrv Observability               │
├─────────────────────────────────────────────────┤
│                                                  │
│  Prometheus ←─ node_exporter (localhost:9100)   │
│      ↓         cAdvisor (cadvisor:8080)          │
│      ↓                                           │
│   Grafana  ←── Loki ←── Promtail                │
│      ↓                     ↑                     │
│ Dashboards           Docker Logs                │
│                                                  │
│  [Pi targets: DOWN - Expected & Tolerated]      │
└─────────────────────────────────────────────────┘
```

**Characteristics:**
- ✅ Full observability for CoreSrv
- ✅ All services monitored
- ⚠️ Pi targets show as DOWN (expected)
- ✅ No impact on functionality

### Integrated Mode (CoreSrv + Pi Nodes)

```
┌─────────────────────────────────────────────────┐
│              CoreSrv Observability               │
├─────────────────────────────────────────────────┤
│                                                  │
│  Prometheus ←─ node_exporter (localhost:9100)   │
│      ↓         cAdvisor (cadvisor:8080)          │
│      ↓         ┌──────────────────────────────┐ │
│      ↓         │ Pi DNS (192.168.8.240)       │ │
│      ├────────→│  - node_exporter:9100        │ │
│      │         │  - pihole_exporter:9617      │ │
│      │         │  - unbound_exporter:9167     │ │
│      │         └──────────────────────────────┘ │
│      ↓         ┌──────────────────────────────┐ │
│      └────────→│ Pi NetSec (192.168.8.241)    │ │
│                │  - node_exporter:9100        │ │
│                └──────────────────────────────┘ │
│   Grafana  ←── Loki ←── Promtail (CoreSrv)      │
│      ↓                   ↑                       │
│ Dashboards         Promtail (Pi DNS) ←─ Optional│
│                    Promtail (Pi NetSec) ←─ Opt. │
└─────────────────────────────────────────────────┘
```

**Characteristics:**
- ✅ Complete infrastructure observability
- ✅ CoreSrv + Pi nodes metrics
- ✅ Centralized logging (optional)
- ✅ Single pane of glass

## Setup

### 1. Initial Configuration

#### Environment Variables
Edit `env/.env.monitoring`:

```bash
# User/Group
PUID=1000
PGID=1000
TZ=Europe/Amsterdam

# Paths
CONFIG_ROOT=/srv/orion-sentinel-core/config
DATA_ROOT=/srv/orion-sentinel-core/data
MONITORING_ROOT=/srv/orion-sentinel-core/monitoring

# Retention
PROMETHEUS_RETENTION_TIME=15d
LOKI_RETENTION_PERIOD=168h  # 7 days

# Grafana credentials
GRAFANA_ADMIN_USER=admin
GRAFANA_ADMIN_PASSWORD=change_me_to_a_strong_password
```

#### Create Directory Structure

```bash
sudo mkdir -p /srv/orion-sentinel-core/monitoring/{prometheus,loki,grafana,promtail}
sudo mkdir -p /srv/orion-sentinel-core/monitoring/prometheus/data
sudo mkdir -p /srv/orion-sentinel-core/monitoring/grafana/{data,provisioning}
sudo mkdir -p /srv/orion-sentinel-core/config/redis
sudo chown -R $USER:$USER /srv/orion-sentinel-core
```

### 2. Copy Configuration Files

```bash
# Prometheus config
cp monitoring/prometheus/prometheus.yml /srv/orion-sentinel-core/monitoring/prometheus/

# Loki config
cp monitoring/loki/config.yml /srv/orion-sentinel-core/monitoring/loki/

# Promtail config
cp monitoring/promtail/config.yml /srv/orion-sentinel-core/monitoring/promtail/

# Grafana provisioning
cp -r monitoring/grafana/provisioning/* /srv/orion-sentinel-core/monitoring/grafana/provisioning/
```

### 3. Start Observability Stack

```bash
# Start core + observability
./orionctl.sh up-observability

# Verify services
docker ps | grep -E "(prometheus|grafana|loki|promtail|cadvisor|node-exporter|uptime-kuma)"

# Check logs
docker logs prometheus
docker logs grafana
docker logs loki
```

### 4. Initial Access

1. **Grafana:** `https://grafana.local`
   - Login: `admin` / `<password from .env.monitoring>`
   - Add data sources (Prometheus, Loki) via provisioning

2. **Prometheus:** `https://prometheus.local`
   - Verify targets: Status → Targets
   - Expected UP: `prometheus`, `coresrv-node`, `coresrv-cadvisor`
   - Expected DOWN (Standalone): `pi-dns-node`, `pihole`, `unbound`, `pi-netsec-node`

3. **Uptime Kuma:** `https://status.local`
   - First-time setup wizard
   - Configure monitors for critical services

### 5. Configure Dashboards (Grafana)

#### Import Pre-built Dashboards

1. **Node Exporter Full** (ID: 1860)
   - Comprehensive host metrics
   - CPU, RAM, disk, network, filesystem

2. **cAdvisor** (ID: 14282)
   - Docker container resource usage
   - Per-container CPU, memory, network

3. **Loki Logs** (ID: 13639)
   - Log exploration and filtering
   - Real-time log tailing

4. **Pi-hole Exporter** (ID: 10176) - For Integrated Mode
   - DNS queries and blocks
   - Top clients and domains

#### Import Steps
```
Grafana → Dashboards → Import → Enter Dashboard ID → Load → Select Prometheus data source → Import
```

## Deployment Modes

### Standalone Mode (CoreSrv Only)

**Use Case:** Initial setup, testing, or when Pi nodes are not deployed.

**What Works:**
- ✅ CoreSrv metrics (CPU, RAM, disk, network)
- ✅ Container metrics (all Docker services)
- ✅ Log aggregation (CoreSrv containers)
- ✅ Service availability monitoring
- ✅ Grafana dashboards for CoreSrv

**Expected Behavior:**
- ⚠️ Pi targets show as "DOWN" in Prometheus - **This is normal**
- ⚠️ Pi-related dashboards show no data - **This is normal**
- ✅ No impact on CoreSrv functionality

**Prometheus Targets Status:**
```
✅ prometheus          UP
✅ coresrv-node        UP
✅ coresrv-cadvisor    UP
❌ pi-dns-node         DOWN (expected)
❌ pihole              DOWN (expected)
❌ unbound             DOWN (expected)
❌ pi-netsec-node      DOWN (expected)
```

### Integrated Mode (CoreSrv + Pi Nodes)

**Prerequisites:**
1. Pi DNS deployed at 192.168.8.240 with exporters
2. Pi NetSec deployed at 192.168.8.241 with exporters
3. Network connectivity between CoreSrv and Pi nodes
4. Firewall rules allowing metric scraping

**Additional Capabilities:**
- ✅ Pi-hole DNS metrics (queries, blocks, clients)
- ✅ Unbound recursive DNS metrics
- ✅ Pi node health metrics (CPU, RAM, disk)
- ✅ NetSec AI metrics (if deployed)
- ✅ Centralized log aggregation (optional)

**Prometheus Targets Status:**
```
✅ prometheus          UP
✅ coresrv-node        UP
✅ coresrv-cadvisor    UP
✅ pi-dns-node         UP
✅ pihole              UP
✅ unbound             UP
✅ pi-netsec-node      UP
```

**Setup:**
See `agents/pi-dns/README.md` for Pi exporter deployment.

## Metrics Reference

### CoreSrv Metrics

#### node_exporter (Host Metrics)
- `node_cpu_seconds_total` - CPU usage by mode
- `node_memory_*` - Memory usage and availability
- `node_disk_*` - Disk I/O and space
- `node_network_*` - Network interface statistics
- `node_filesystem_*` - Filesystem usage

#### cAdvisor (Container Metrics)
- `container_cpu_usage_seconds_total` - CPU usage per container
- `container_memory_usage_bytes` - Memory usage per container
- `container_network_*` - Network I/O per container
- `container_fs_*` - Filesystem usage per container

### Pi DNS Metrics (Integrated Mode)

#### pihole_exporter
- `pihole_queries_today` - Total queries today
- `pihole_blocked_today` - Blocked queries today
- `pihole_domains_blocked` - Total domains on blocklist
- `pihole_top_queries` - Most queried domains
- `pihole_top_clients` - Most active clients

#### unbound_exporter
- `unbound_queries_total` - Total DNS queries
- `unbound_query_*` - Query types and response codes
- `unbound_cache_*` - Cache hit/miss statistics
- `unbound_memory_*` - Memory usage

## Alerting

### Prometheus Alerts (Future Enhancement)

Example alert rules to implement:

```yaml
groups:
  - name: coresrv_alerts
    rules:
      # High CPU usage
      - alert: HighCPUUsage
        expr: 100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80
        for: 5m
        annotations:
          summary: "High CPU usage on {{ $labels.instance }}"
          
      # High memory usage
      - alert: HighMemoryUsage
        expr: (1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90
        for: 5m
        annotations:
          summary: "High memory usage on {{ $labels.instance }}"
          
      # Disk space low
      - alert: DiskSpaceLow
        expr: (node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10
        for: 5m
        annotations:
          summary: "Low disk space on {{ $labels.instance }}"
```

### Uptime Kuma Monitors

Configure monitors for:
- CoreSrv services (HTTP/HTTPS checks)
- Pi DNS services (HTTP checks)
- Pi NetSec services (HTTP checks)
- External connectivity (ping/HTTP checks)

## Troubleshooting

### Prometheus Issues

#### Problem: Prometheus target DOWN
```bash
# Check target accessibility
curl http://localhost:9100/metrics  # node_exporter
curl http://cadvisor:8080/metrics   # cAdvisor (from inside Docker network)

# Check Prometheus logs
docker logs prometheus

# Verify Prometheus config
docker exec prometheus promtool check config /etc/prometheus/prometheus.yml
```

#### Problem: High memory usage
```bash
# Check Prometheus stats
curl http://localhost:9090/api/v1/status/tsdb

# Reduce retention time in .env.monitoring
PROMETHEUS_RETENTION_TIME=7d  # instead of 15d

# Restart Prometheus
docker restart prometheus
```

### Grafana Issues

#### Problem: Cannot access Grafana
```bash
# Check Grafana status
docker logs grafana

# Verify Authelia is working
curl -k https://auth.local

# Check Traefik routing
docker logs traefik | grep grafana
```

#### Problem: Data source connection failed
```bash
# Verify Prometheus is accessible from Grafana
docker exec grafana wget -O- http://prometheus:9090/api/v1/query?query=up

# Check Grafana provisioning
docker exec grafana ls -la /etc/grafana/provisioning/datasources/
```

### Loki Issues

#### Problem: Logs not appearing
```bash
# Check Promtail is running
docker logs promtail

# Verify Loki is accessible
curl http://localhost:3100/ready

# Test log query
curl -G http://localhost:3100/loki/api/v1/query \
  --data-urlencode 'query={job="docker"}' \
  --data-urlencode 'limit=10'
```

#### Problem: High disk usage
```bash
# Check Loki storage
du -sh /srv/orion-sentinel-core/monitoring/loki/

# Reduce retention in loki/config.yml
retention_period: 72h  # instead of 168h

# Restart Loki
docker restart loki
```

### node_exporter Issues

#### Problem: node_exporter not starting
```bash
# Check logs
docker logs node-exporter

# Verify host network mode
docker inspect node-exporter | grep NetworkMode
# Should show: "NetworkMode": "host"

# Test metrics endpoint
curl http://localhost:9100/metrics
```

### cAdvisor Issues

#### Problem: cAdvisor missing metrics
```bash
# Check cAdvisor logs
docker logs cadvisor

# Verify privileged mode
docker inspect cadvisor | grep Privileged
# Should show: "Privileged": true

# Test metrics endpoint
docker exec prometheus wget -O- http://cadvisor:8080/metrics
```

### Pi Node Connectivity Issues (Integrated Mode)

#### Problem: Pi targets remain DOWN
```bash
# From CoreSrv, test Pi DNS connectivity
curl http://192.168.8.240:9100/metrics  # node_exporter
curl http://192.168.8.240:9617/metrics  # pihole_exporter
curl http://192.168.8.240:9167/metrics  # unbound_exporter

# If curl fails, check firewall on Pi
# On Pi DNS:
sudo ufw status
sudo ufw allow 9100/tcp
sudo ufw allow 9167/tcp
sudo ufw allow 9617/tcp

# Verify exporters are running on Pi
# On Pi DNS:
docker ps | grep exporter
```

#### Problem: Pi logs not appearing in Loki
```bash
# Verify Loki port is accessible from Pi
# On Pi DNS:
curl http://<coresrv-ip>:3100/ready

# Check Pi Promtail logs
# On Pi DNS:
docker logs promtail

# Verify Promtail config points to correct Loki address
# On Pi DNS:
docker exec promtail cat /etc/promtail/config.yml | grep loki
```

## Maintenance

### Regular Tasks

#### Daily
- Monitor Uptime Kuma for service availability
- Check Grafana dashboards for anomalies

#### Weekly
- Review Prometheus target health
- Check disk usage for Prometheus and Loki data
- Verify backup jobs completed successfully

#### Monthly
- Review and update Grafana dashboards
- Audit Prometheus retention settings
- Clean up old logs and metrics data

### Backup

**Critical Data:**
- Prometheus data: `/srv/orion-sentinel-core/monitoring/prometheus/data`
- Grafana database: `/srv/orion-sentinel-core/monitoring/grafana/data`
- Loki data: `/srv/orion-sentinel-core/monitoring/loki/data`
- Uptime Kuma data: `/srv/orion-sentinel-core/data/uptime-kuma`

**Backup Strategy:**
See `docs/BACKUP-RESTORE.md` for automated backup setup.

### Performance Tuning

#### Prometheus
```yaml
# Reduce scrape interval for lower resource usage
global:
  scrape_interval: 30s  # instead of 15s
  
# Reduce retention
storage.tsdb.retention.time=7d  # instead of 15d
```

#### Loki
```yaml
# Reduce retention
retention_period: 72h  # instead of 168h

# Limit ingestion rate
ingestion_rate_mb: 4
ingestion_burst_size_mb: 6
```

#### Grafana
```bash
# Disable unused plugins
# Set in docker-compose.yml
GF_INSTALL_PLUGINS=""  # remove unnecessary plugins
```

## References

- [Prometheus Documentation](https://prometheus.io/docs/)
- [Grafana Documentation](https://grafana.com/docs/)
- [Loki Documentation](https://grafana.com/docs/loki/)
- [node_exporter](https://github.com/prometheus/node_exporter)
- [cAdvisor](https://github.com/google/cadvisor)
- [Pi DNS Deployment Guide](../agents/pi-dns/README.md)
- [Topology & Deployment Modes](../docs/TOPOLOGY.md)
