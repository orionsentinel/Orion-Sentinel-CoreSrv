# Pi DNS Exporter Deployment Guide

## Overview

This guide covers deploying Prometheus exporters on the DNS Pi node (Pi 5 #1) to enable metrics collection by the Orion-Sentinel-CoreSrv observability stack.

**DNS Pi Role:** Primary DNS server with Pi-hole ad-blocking and Unbound recursive DNS.

**IP Address:** 192.168.8.240 (adjust to match your network)

## Exporters to Deploy

| Exporter | Port | Purpose | Metrics |
|----------|------|---------|---------|
| `node_exporter` | 9100 | Host metrics | CPU, RAM, disk, network |
| `pihole_exporter` | 9617 | Pi-hole metrics | DNS queries, blocks, clients |
| `unbound_exporter` | 9167 | Unbound metrics | Recursive DNS performance |

## Architecture

```
┌──────────────────────────────────────────────┐
│         Pi DNS (192.168.8.240)               │
├──────────────────────────────────────────────┤
│                                              │
│  ┌──────────┐  ┌──────────┐  ┌────────────┐│
│  │ Pi-hole  │  │ Unbound  │  │ Node       ││
│  │  :80     │  │  :5335   │  │ Exporter   ││
│  └────┬─────┘  └────┬─────┘  │  :9100     ││
│       │             │         └────────────┘│
│  ┌────┴─────┐  ┌────┴─────┐  ┌────────────┐│
│  │ Pihole   │  │ Unbound  │  │ Promtail   ││
│  │ Exporter │  │ Exporter │  │ (Optional) ││
│  │  :9617   │  │  :9167   │  └────────────┘│
│  └──────────┘  └──────────┘                 │
│       ↓             ↓             ↓          │
│       └─────────────┴─────────────┘          │
│                     ↓                        │
└─────────────────────┼────────────────────────┘
                      ↓
         ┌────────────┴───────────┐
         │  CoreSrv Prometheus    │
         │  (Scrapes metrics)     │
         └────────────────────────┘
```

## Prerequisites

- Pi DNS node running Pi-hole and Unbound
- Docker and Docker Compose installed on Pi DNS
- Network connectivity to CoreSrv
- Firewall rules allowing metric scraping

## Installation

### 1. Create Exporter Configuration

On the Pi DNS node, create a directory for exporter configs:

```bash
mkdir -p ~/pi-dns-exporters
cd ~/pi-dns-exporters
```

### 2. Deploy Exporters

Copy the example compose file:

```bash
# From this repository (agents/pi-dns/)
scp exporters-docker-compose.example.yml pi-dns:~/pi-dns-exporters/docker-compose.yml
```

Or create it manually using the example below.

### 3. Configure Unbound Remote Control

The `unbound_exporter` requires Unbound's remote-control interface to be enabled.

#### Option A: Using unbound-control (Recommended)

Edit Unbound configuration:

```bash
# Edit unbound.conf (location depends on your setup)
# Docker Pi-hole: /etc/unbound/unbound.conf.d/
# Bare metal: /etc/unbound/unbound.conf.d/

sudo nano /etc/unbound/unbound.conf.d/remote-control.conf
```

Add:

```yaml
remote-control:
  control-enable: yes
  control-interface: 127.0.0.1
  control-port: 8953
```

Generate certificates:

```bash
# If using Docker Pi-hole
docker exec unbound unbound-control-setup

# If using bare metal
sudo unbound-control-setup
```

Restart Unbound:

```bash
docker restart unbound
# OR
sudo systemctl restart unbound
```

Verify:

```bash
# Test remote-control
docker exec unbound unbound-control status
# OR
sudo unbound-control status
```

#### Option B: Using Unbound Stats (Alternative)

If remote-control is not available, you can use the stats endpoint:

```bash
# In unbound.conf.d/stats.conf
server:
  statistics-interval: 0
  extended-statistics: yes
  statistics-cumulative: yes
```

### 4. Configure Pi-hole API Access

The `pihole_exporter` requires Pi-hole API access.

#### Get Pi-hole API Token

```bash
# From Pi-hole web interface:
# Settings → API → Show API token

# OR via command line:
docker exec pihole pihole -a -p
# Enter new password when prompted
# API token will be displayed
```

#### Update Exporter Configuration

Edit `docker-compose.yml` and add your Pi-hole API token:

```yaml
environment:
  PIHOLE_API_TOKEN: "your-actual-api-token-here"
```

### 5. Start Exporters

```bash
cd ~/pi-dns-exporters
docker compose up -d
```

Verify all exporters are running:

```bash
docker compose ps
```

Expected output:
```
NAME                IMAGE                              STATUS
node-exporter       prom/node-exporter:v1.8.1         Up
pihole-exporter     ekofr/pihole-exporter:latest      Up
unbound-exporter    svenstaro/unbound_exporter:latest Up
```

### 6. Test Metrics Endpoints

```bash
# Test node_exporter
curl http://localhost:9100/metrics | head -20

# Test pihole_exporter
curl http://localhost:9617/metrics | head -20

# Test unbound_exporter
curl http://localhost:9167/metrics | head -20
```

All should return Prometheus metrics in text format.

### 7. Configure Firewall

Allow CoreSrv to scrape metrics:

```bash
# UFW (Ubuntu)
sudo ufw allow from <coresrv-ip> to any port 9100 proto tcp
sudo ufw allow from <coresrv-ip> to any port 9167 proto tcp
sudo ufw allow from <coresrv-ip> to any port 9617 proto tcp

# Or allow from entire LAN (less secure)
sudo ufw allow 9100/tcp
sudo ufw allow 9167/tcp
sudo ufw allow 9617/tcp
```

### 8. Verify from CoreSrv

From the CoreSrv node, test connectivity:

```bash
# Test each exporter
curl http://192.168.8.240:9100/metrics | head -20  # node_exporter
curl http://192.168.8.240:9617/metrics | head -20  # pihole_exporter
curl http://192.168.8.240:9167/metrics | head -20  # unbound_exporter
```

If successful, check Prometheus targets:

```bash
# Access Prometheus UI
https://prometheus.local/targets

# Verify Pi DNS targets show as UP:
# - pi-dns-node (192.168.8.240:9100)
# - pihole (192.168.8.240:9617)
# - unbound (192.168.8.240:9167)
```

## Exporter Configuration

### node_exporter

**Purpose:** Export host-level metrics (CPU, RAM, disk, network)

**Configuration:** Minimal - runs with default collectors

**Key Metrics:**
- `node_cpu_seconds_total` - CPU usage by mode (user, system, idle)
- `node_memory_MemAvailable_bytes` - Available memory
- `node_disk_io_time_seconds_total` - Disk I/O time
- `node_network_receive_bytes_total` - Network RX bytes
- `node_filesystem_avail_bytes` - Filesystem available space

### pihole_exporter

**Purpose:** Export Pi-hole DNS filtering metrics

**Configuration:**
- Requires Pi-hole API token
- Can monitor multiple Pi-hole instances
- Scrape interval: 15s (default)

**Key Metrics:**
- `pihole_queries_today` - Total queries today
- `pihole_blocked_today` - Blocked queries today
- `pihole_percent_blocked_today` - Block percentage
- `pihole_domains_on_blocklist` - Total blocklist entries
- `pihole_top_queries` - Most queried domains
- `pihole_top_clients` - Most active clients

**Environment Variables:**
```yaml
PIHOLE_HOSTNAME: pihole         # Pi-hole container name or hostname
PIHOLE_PORT: 80                 # Pi-hole web interface port
PIHOLE_API_TOKEN: "your-token"  # Pi-hole API token (required)
```

**Multi-Instance Support:**
```yaml
# Monitor multiple Pi-hole instances
environment:
  PIHOLE_HOSTNAME: "pihole1,pihole2"
  PIHOLE_PORT: "80,80"
  PIHOLE_API_TOKEN: "token1,token2"
```

### unbound_exporter

**Purpose:** Export Unbound recursive DNS metrics

**Configuration:**
- Requires Unbound remote-control or stats endpoint
- Default: Uses `unbound-control` via Unix socket

**Key Metrics:**
- `unbound_queries_total` - Total DNS queries
- `unbound_query_time_seconds` - Query response time
- `unbound_cache_hits_total` - Cache hit count
- `unbound_cache_misses_total` - Cache miss count
- `unbound_memory_cache_bytes` - Cache memory usage

**Environment Variables:**
```yaml
UNBOUND_HOST: unbound           # Unbound container name
UNBOUND_CA: /etc/unbound/unbound_server.pem
UNBOUND_CERT: /etc/unbound/unbound_control.pem
UNBOUND_KEY: /etc/unbound/unbound_control.key
```

## Optional: Log Forwarding with Promtail

To send Pi DNS logs to CoreSrv Loki, deploy Promtail on the Pi node.

### 1. Create Promtail Config

Use the example from `agents/pi-dns/promtail-config.example.yml`:

```bash
# Copy to Pi DNS
scp promtail-config.example.yml pi-dns:~/pi-dns-exporters/promtail-config.yml
```

### 2. Update Loki Address

Edit `promtail-config.yml`:

```yaml
clients:
  - url: http://<coresrv-ip>:3100/loki/api/v1/push
```

### 3. Add Promtail to docker-compose.yml

```yaml
  promtail:
    image: grafana/promtail:2.9.5
    container_name: promtail
    restart: unless-stopped
    command: -config.file=/etc/promtail/config.yml
    volumes:
      - /var/lib/docker/containers:/var/lib/docker/containers:ro
      - /var/run/docker.sock:/var/run/docker.sock:ro
      - ./promtail-config.yml:/etc/promtail/config.yml:ro
    networks:
      - default
```

### 4. Expose Loki Port on CoreSrv

Edit CoreSrv `compose.yml` and uncomment:

```yaml
  loki:
    # ...
    ports:
      - "3100:3100"
```

Restart CoreSrv Loki:

```bash
docker compose restart loki
```

### 5. Start Promtail on Pi DNS

```bash
docker compose up -d promtail
```

Verify logs appear in Grafana Explore (Loki data source).

## Grafana Dashboard Setup

### Import Pi-hole Dashboard

1. Go to `https://grafana.local`
2. Click **Dashboards** → **Import**
3. Enter dashboard ID: **10176** (Pi-hole Exporter)
4. Click **Load**
5. Select **Prometheus** as data source
6. Click **Import**

### Import Unbound Dashboard

1. Create custom dashboard or use community dashboard
2. Example queries:
   ```promql
   # Total queries per minute
   rate(unbound_queries_total[5m]) * 60
   
   # Cache hit rate
   rate(unbound_cache_hits_total[5m]) / rate(unbound_queries_total[5m]) * 100
   
   # Average query time
   rate(unbound_query_time_seconds_sum[5m]) / rate(unbound_query_time_seconds_count[5m])
   ```

### Import Node Exporter Dashboard

1. Import dashboard ID: **1860** (Node Exporter Full)
2. Select **Prometheus** as data source
3. Filter by `instance="pi-dns"`

## Monitoring & Alerts

### Key Metrics to Monitor

#### DNS Health
- **High block rate:** `pihole_percent_blocked_today > 50`
- **Query spike:** `rate(pihole_queries_today[5m]) > 1000`
- **Cache efficiency:** `unbound_cache_hits_total / unbound_queries_total < 0.7`

#### System Health
- **High CPU:** `100 - (avg(rate(node_cpu_seconds_total{mode="idle"}[5m])) * 100) > 80`
- **High memory:** `(1 - (node_memory_MemAvailable_bytes / node_memory_MemTotal_bytes)) * 100 > 90`
- **Disk space low:** `(node_filesystem_avail_bytes / node_filesystem_size_bytes) * 100 < 10`

### Example Prometheus Alert Rules

Create `alerts.yml` on CoreSrv:

```yaml
groups:
  - name: pi_dns_alerts
    rules:
      - alert: PiDNSDown
        expr: up{job="pi-dns-node"} == 0
        for: 2m
        annotations:
          summary: "Pi DNS node is down"
          
      - alert: HighDNSBlockRate
        expr: pihole_percent_blocked_today > 60
        for: 10m
        annotations:
          summary: "High DNS block rate: {{ $value }}%"
          
      - alert: UnboundCacheLow
        expr: rate(unbound_cache_hits_total[5m]) / rate(unbound_queries_total[5m]) < 0.6
        for: 15m
        annotations:
          summary: "Unbound cache hit rate low: {{ $value }}"
```

## Troubleshooting

### Exporters Not Starting

```bash
# Check logs
docker compose logs node-exporter
docker compose logs pihole-exporter
docker compose logs unbound-exporter

# Common issues:
# 1. Port already in use
sudo netstat -tulpn | grep -E "9100|9167|9617"

# 2. Permission issues
ls -la /var/run/docker.sock
sudo usermod -aG docker $USER
```

### No Metrics from pihole_exporter

```bash
# Verify Pi-hole is accessible
curl http://pihole/admin/api.php

# Check API token
docker exec pihole pihole -a -p

# Test exporter directly
docker exec pihole-exporter wget -O- http://localhost:9617/metrics
```

### No Metrics from unbound_exporter

```bash
# Verify Unbound remote-control is enabled
docker exec unbound unbound-control status

# Check certificates exist
docker exec unbound ls -la /etc/unbound/unbound_*.pem

# Test exporter directly
docker exec unbound-exporter wget -O- http://localhost:9167/metrics
```

### CoreSrv Cannot Scrape Metrics

```bash
# From CoreSrv, test connectivity
curl http://192.168.8.240:9100/metrics  # node_exporter
curl http://192.168.8.240:9617/metrics  # pihole_exporter
curl http://192.168.8.240:9167/metrics  # unbound_exporter

# If timeout, check firewall on Pi DNS
sudo ufw status
sudo ufw allow 9100/tcp
sudo ufw allow 9167/tcp
sudo ufw allow 9617/tcp

# Check network connectivity
ping 192.168.8.240
traceroute 192.168.8.240
```

### Prometheus Targets Remain DOWN

```bash
# Check Prometheus config on CoreSrv
docker exec prometheus cat /etc/prometheus/prometheus.yml | grep pi-dns

# Verify IP addresses match
# Check Prometheus logs
docker logs prometheus | grep "pi-dns"

# Reload Prometheus config
docker exec prometheus kill -HUP 1
```

## Maintenance

### Update Exporters

```bash
cd ~/pi-dns-exporters
docker compose pull
docker compose up -d
```

### Monitor Exporter Health

```bash
# Check all exporters
docker compose ps

# Check exporter logs
docker compose logs -f --tail=50

# Check metrics collection
curl http://localhost:9100/metrics | grep "node_scrape_collector_success"
```

### Backup Configuration

```bash
# Backup exporter configs
tar -czf pi-dns-exporters-backup-$(date +%F).tar.gz ~/pi-dns-exporters/

# Store backup off-site
scp pi-dns-exporters-backup-*.tar.gz backup-server:/backups/
```

## Security Considerations

### Network Security

1. **Firewall Rules:** Only allow CoreSrv IP to scrape metrics
2. **No Public Exposure:** Exporters should only be accessible on LAN
3. **API Tokens:** Use secure Pi-hole API tokens, store securely

### Exporter Security

1. **Read-Only Access:** Exporters have read-only access to services
2. **No Authentication:** Metrics endpoints are unauthenticated (secured via firewall)
3. **Regular Updates:** Keep exporters updated for security patches

### Unbound Remote Control

1. **Certificate-Based:** Uses TLS certificates for authentication
2. **Local Only:** Remote-control only accessible on localhost
3. **Minimal Permissions:** unbound-control has minimal privileges

## Performance Impact

### Resource Usage

| Exporter | CPU | Memory | Network |
|----------|-----|--------|---------|
| node_exporter | <1% | ~10MB | <1KB/s |
| pihole_exporter | <1% | ~20MB | <1KB/s |
| unbound_exporter | <1% | ~15MB | <1KB/s |

**Total:** Minimal impact on Pi DNS performance.

### Scrape Impact

- Prometheus scrapes every 15 seconds (configurable)
- Each scrape: <1ms query time
- Negligible impact on DNS performance

## References

- [node_exporter GitHub](https://github.com/prometheus/node_exporter)
- [pihole_exporter GitHub](https://github.com/eko/pihole-exporter)
- [unbound_exporter GitHub](https://github.com/svenstaro/unbound_exporter)
- [Prometheus Configuration](https://prometheus.io/docs/prometheus/latest/configuration/configuration/)
- [Pi-hole Documentation](https://docs.pi-hole.net/)
- [Unbound Documentation](https://unbound.docs.nlnetlabs.nl/)
- [CoreSrv Topology](../../docs/TOPOLOGY.md)
- [Observability Stack Setup](../../monitoring/README.md)
