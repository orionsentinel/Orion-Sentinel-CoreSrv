# Grafana Dashboards

This directory contains pre-configured Grafana dashboards for monitoring your Orion Sentinel CoreSrv infrastructure.

## Available Dashboards

### System Monitoring
- **node-exporter-full.json** - Complete system metrics (CPU, RAM, disk, network)
- **docker-containers.json** - Container metrics and health status
- **cadvisor-dashboard.json** - Detailed container performance metrics

### Media Stack
- **media-stack-overview.json** - Overview of all media services
- **jellyfin-monitoring.json** - Jellyfin performance and usage
- **qbittorrent-stats.json** - Download statistics and torrent activity

### Application Monitoring
- **loki-logs.json** - Log viewer for all services
- **traefik-metrics.json** - Reverse proxy traffic and performance
- **uptime-kuma.json** - Service availability dashboard

## How to Import

### Automatic Import (Recommended)

Dashboards in this directory are automatically provisioned to Grafana on startup via the Grafana provisioning system.

To add dashboards automatically:

1. Copy dashboard JSON files to this directory
2. Restart Grafana: `make restart SVC=grafana`
3. Dashboards will appear in Grafana under "General" folder

### Manual Import

1. Open Grafana web UI (default: http://localhost:3000 or https://grafana.local)
2. Click "+" → "Import dashboard"
3. Upload JSON file or paste JSON content
4. Select Prometheus as data source
5. Click "Import"

## Creating Custom Dashboards

### Using Grafana Dashboard Library

Browse community dashboards at: https://grafana.com/grafana/dashboards/

Popular dashboard IDs:
- **1860** - Node Exporter Full
- **893** - Docker and System Monitoring
- **14282** - cadvisor exporter
- **12486** - Traefik 2
- **13639** - Loki & Promtail

To import by ID:
1. Go to Grafana → Dashboards → Import
2. Enter dashboard ID
3. Select Prometheus as data source
4. Click "Import"

## Resources

- [Grafana Documentation](https://grafana.com/docs/grafana/latest/)
- [Prometheus Query Examples](https://prometheus.io/docs/prometheus/latest/querying/examples/)
- [Grafana Dashboard Best Practices](https://grafana.com/docs/grafana/latest/best-practices/)
