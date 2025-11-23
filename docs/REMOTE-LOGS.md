# Remote Logs: Centralized Logging from Pi Nodes to CoreSrv

## Overview

This document explains how to ship logs from the Pi nodes (Pi DNS and Pi NetSec) to the central Loki instance running on CoreSrv.

### Architecture

```
┌─────────────────┐
│   Pi 5 #1 (DNS) │
│                 │
│  ┌───────────┐  │
│  │ Promtail  │──┼──┐
│  │  Agent    │  │  │
│  └───────────┘  │  │
│                 │  │
│  ┌───────────┐  │  │
│  │ Pi-hole   │  │  │
│  │ Unbound   │  │  │
│  │ Keepalived│  │  │
│  └───────────┘  │  │
└─────────────────┘  │
                     │
┌─────────────────┐  │     ┌──────────────────────┐
│ Pi 5 #2 (NetSec)│  │     │   CoreSrv (Hub)      │
│                 │  │     │                      │
│  ┌───────────┐  │  │     │  ┌────────────────┐ │
│  │ Promtail  │──┼──┼────>│  │ Loki (Central) │ │
│  │  Agent    │  │  │     │  │ :3100          │ │
│  └───────────┘  │  │     │  └────────┬───────┘ │
│                 │  │     │           │         │
│  ┌───────────┐  │  │     │  ┌────────▼───────┐ │
│  │ Suricata  │  │  │     │  │ Grafana        │ │
│  │ AI NSM    │  │  │     │  │ (Query logs)   │ │
│  │ IDS/IPS   │  │  │     │  └────────────────┘ │
│  └───────────┘  │  │     │                      │
└─────────────────┘  │     └──────────────────────┘
                     │
         HTTP :3100  │
         ────────────┘
```

### Design Principles

1. **CoreSrv as Central Log Sink**
   - Single Loki instance on CoreSrv aggregates all logs
   - Reduces resource usage on Pis (no local Loki needed)
   - Unified log viewing in Grafana

2. **Lightweight Agents on Pis**
   - Each Pi runs a single Promtail container
   - Promtail ships Docker container logs via HTTP
   - Minimal CPU/memory footprint (~50MB RAM per agent)

3. **LAN-Only Communication**
   - Logs shipped over local network (not internet)
   - Optional: VPN/wireguard tunnel for remote Pis
   - Security via network segmentation (firewall rules)

## Prerequisites

### On CoreSrv

1. **Loki service running**
   ```bash
   docker compose --profile monitoring up -d loki
   ```

2. **Loki port exposed on LAN** (optional but recommended)
   
   Edit `compose.yml` and uncomment the Loki port binding:
   ```yaml
   loki:
     # ...
     ports:
       - "3100:3100"  # ← Uncomment this line
   ```
   
   Then restart Loki:
   ```bash
   docker compose restart loki
   ```

3. **Firewall rules** (if using UFW or firewalld)
   
   Allow Pi nodes to access Loki:
   ```bash
   # Example: Allow from Pi DNS (192.168.1.10)
   sudo ufw allow from 192.168.1.10 to any port 3100
   
   # Example: Allow from Pi NetSec (192.168.1.20)
   sudo ufw allow from 192.168.1.20 to any port 3100
   
   # Or allow entire subnet
   sudo ufw allow from 192.168.1.0/24 to any port 3100
   ```

4. **Verify Loki is accessible**
   
   From a Pi node, test connectivity:
   ```bash
   curl http://<coresrv-lan-ip>:3100/ready
   # Should return: ready
   ```

### On Pi Nodes

1. **Docker installed**
   ```bash
   docker --version
   # Docker version 24.0.0 or later
   ```

2. **Network connectivity to CoreSrv**
   ```bash
   ping <coresrv-lan-ip>
   # Should have low latency (<5ms on LAN)
   ```

## Setup Instructions

### Step 1: Deploy Promtail on Pi 5 #1 (DNS Pi)

1. **Copy configuration to Pi DNS**
   
   From this repo, copy the example config:
   ```bash
   # On CoreSrv
   scp agents/pi-dns/promtail-config.example.yml \
     pi@pi-dns:/opt/promtail/config.yml
   ```

2. **Edit configuration on Pi DNS**
   
   SSH into Pi DNS:
   ```bash
   ssh pi@pi-dns
   ```
   
   Edit the config:
   ```bash
   sudo nano /opt/promtail/config.yml
   ```
   
   Replace `CORESRV_LAN_IP` with your CoreSrv's actual IP:
   ```yaml
   clients:
     - url: http://192.168.1.100:3100/loki/api/v1/push  # ← Update this
   ```

3. **Deploy Promtail container**
   
   Using Docker CLI:
   ```bash
   docker run -d --name promtail \
     --restart unless-stopped \
     -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
     -v /var/run/docker.sock:/var/run/docker.sock:ro \
     -v /opt/promtail/config.yml:/etc/promtail/config.yml:ro \
     grafana/promtail:2.9.5 \
     -config.file=/etc/promtail/config.yml
   ```
   
   Or create `/opt/promtail/docker-compose.yml`:
   ```yaml
   services:
     promtail:
       image: grafana/promtail:2.9.5
       container_name: promtail
       restart: unless-stopped
       command: -config.file=/etc/promtail/config.yml
       volumes:
         - /var/lib/docker/containers:/var/lib/docker/containers:ro
         - /var/run/docker.sock:/var/run/docker.sock:ro
         - /opt/promtail/config.yml:/etc/promtail/config.yml:ro
   ```
   
   Then start:
   ```bash
   cd /opt/promtail
   docker compose up -d
   ```

4. **Verify logs are shipping**
   
   Check Promtail logs:
   ```bash
   docker logs promtail
   # Should see: "Successfully connected to Loki"
   ```

### Step 2: Deploy Promtail on Pi 5 #2 (NetSec Pi)

Follow the same process as Pi 5 #1, but use the NetSec configuration:

1. **Copy configuration**
   ```bash
   scp agents/pi-netsec/promtail-config.example.yml \
     pi@pi-netsec:/opt/promtail/config.yml
   ```

2. **Edit and update IP**
   ```bash
   ssh pi@pi-netsec
   sudo nano /opt/promtail/config.yml
   # Update CORESRV_LAN_IP
   ```

3. **Deploy container**
   ```bash
   docker run -d --name promtail \
     --restart unless-stopped \
     -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
     -v /var/run/docker.sock:/var/run/docker.sock:ro \
     -v /opt/promtail/config.yml:/etc/promtail/config.yml:ro \
     grafana/promtail:2.9.5 \
     -config.file=/etc/promtail/config.yml
   ```

4. **Verify**
   ```bash
   docker logs promtail
   ```

### Step 3: View Logs in Grafana

1. **Access Grafana**
   
   Navigate to: `https://grafana.local` (or CoreSrv IP:3000)

2. **Open Explore view**
   
   - Click "Explore" in left sidebar
   - Select "Loki" datasource

3. **Query logs from Pi DNS**
   
   Use LogQL queries:
   ```logql
   # All logs from Pi DNS
   {host="pi-dns"}
   
   # Pi-hole logs specifically
   {host="pi-dns", container_name="pihole"}
   
   # Unbound logs
   {host="pi-dns", container_name="unbound"}
   
   # DNS stack errors
   {host="pi-dns"} |= "error"
   ```

4. **Query logs from Pi NetSec**
   
   ```logql
   # All logs from Pi NetSec
   {host="pi-netsec"}
   
   # Suricata IDS logs
   {host="pi-netsec", container_name="suricata"}
   
   # Security alerts
   {host="pi-netsec"} |= "ALERT"
   
   # AI pipeline logs
   {host="pi-netsec", container_name=~".*ai.*"}
   ```

5. **Multi-node queries**
   
   ```logql
   # Logs from all Pi nodes
   {host=~"pi-.*"}
   
   # Errors across all nodes
   {host=~"pi-.*"} |= "error"
   
   # Specific service across nodes
   {container_name="promtail"}
   ```

## Log Labels

All logs from Pi nodes include these labels:

### Pi DNS Labels
- `job: pi-dns-docker`
- `host: pi-dns`
- `node: pi-dns`
- `stack: dns-ha`
- `role: dns-server`
- `environment: production`
- `container_name: <name>` (auto-added by Promtail)

### Pi NetSec Labels
- `job: pi-netsec-docker`
- `host: pi-netsec`
- `node: pi-netsec`
- `stack: netsec-ai`
- `role: security-monitoring`
- `environment: production`
- `container_name: <name>` (auto-added by Promtail)

## Security Considerations

### Network Security

1. **LAN-only exposure**
   - Loki port 3100 should only be accessible on LAN
   - Use firewall rules to restrict access to known Pi IPs

2. **Optional: Basic authentication**
   
   Add to Loki configuration (advanced):
   ```yaml
   auth_enabled: true
   ```
   
   Then configure Promtail with credentials:
   ```yaml
   clients:
     - url: http://coresrv:3100/loki/api/v1/push
       basic_auth:
         username: promtail
         password: secret
   ```

3. **Optional: TLS/HTTPS**
   
   For production, consider putting Loki behind reverse proxy:
   - Use Traefik with TLS termination
   - Promtail connects via HTTPS
   - Example: `https://loki.local/loki/api/v1/push`

### Data Privacy

- Logs may contain sensitive information (IPs, usernames, etc.)
- Configure Loki retention appropriately (7-30 days)
- Consider log filtering in Promtail to drop sensitive data
- Restrict Grafana access to authorized users only

## Troubleshooting

### Promtail Not Sending Logs

**Check Promtail status:**
```bash
docker logs promtail --tail 100
```

**Common issues:**

1. **Cannot connect to Loki**
   ```
   Error: connection refused
   ```
   - Verify Loki is running: `docker ps | grep loki`
   - Verify Loki port is published: `docker port loki`
   - Test connectivity: `curl http://coresrv:3100/ready`
   - Check firewall rules

2. **Permission denied on Docker socket**
   ```
   Error: permission denied while trying to connect to Docker daemon socket
   ```
   - Add Promtail user to docker group (if running as service)
   - Ensure volume mount is `:ro` (read-only)

3. **No logs appearing in Grafana**
   - Check Promtail is tailing files: `docker logs promtail | grep "Successfully"`
   - Verify label filters in Grafana query
   - Check time range in Grafana (last 15 minutes)

### High Network Usage

If Promtail is sending too much data:

1. **Add log filtering in pipeline_stages**
   ```yaml
   pipeline_stages:
     - match:
         selector: '{job="pi-dns-docker"} |~ "debug"'
         action: drop
   ```

2. **Reduce retention on Loki**
   - Edit `monitoring/loki/config.yml`
   - Set `retention_period: 72h` (3 days) instead of 7 days

3. **Sample logs (send only percentage)**
   ```yaml
   pipeline_stages:
     - sampling:
         rate: 0.1  # Send 10% of logs
   ```

### Viewing Logs Not Working in Grafana

1. **Verify Loki datasource**
   - Grafana → Configuration → Data Sources → Loki
   - URL should be: `http://loki:3100`
   - Click "Test" button

2. **Check label names**
   - Grafana → Explore → Loki
   - Click "Log browser" to see available labels

3. **Verify time range**
   - Logs are time-sensitive
   - Ensure time range covers when logs were sent
   - Try "Last 1 hour" or "Last 15 minutes"

## Advanced Configuration

### Scraping System Logs (Non-Docker)

To scrape syslog, auth.log, etc. from Pi nodes, add to Promtail config:

```yaml
scrape_configs:
  - job_name: pi-dns-system
    static_configs:
      - targets:
          - localhost
        labels:
          job: pi-dns-system
          host: pi-dns
          __path__: /var/log/*.log
```

Then mount `/var/log`:
```bash
docker run ... -v /var/log:/var/log:ro ...
```

### Log Retention

Adjust in `monitoring/loki/config.yml`:

```yaml
limits_config:
  retention_period: 168h  # 7 days (default)
  # Or: 72h (3 days), 720h (30 days), etc.
```

Restart Loki after changes:
```bash
docker compose restart loki
```

## Future Improvements

### TODO

- [ ] Add authentication to Loki endpoint (Basic Auth or API key)
- [ ] Set up TLS for Loki ingestion (HTTPS instead of HTTP)
- [ ] Create Grafana dashboard for Pi logs overview
- [ ] Add alerting rules for critical Pi events (DNS failures, security alerts)
- [ ] Implement log sampling/filtering to reduce storage usage
- [ ] Document log rotation on Pi nodes to prevent disk fill
- [ ] Consider migrating local Loki on Pi NetSec to centralized CoreSrv only

### Optional: Decommission Local Loki on Pis

If either Pi is running a local Loki instance:

1. Verify all logs are flowing to CoreSrv Loki
2. Stop local Loki: `docker stop loki`
3. Remove from compose file or disable profile
4. Free up resources (Loki uses ~500MB-1GB RAM)
5. Keep Promtail running, now pointing only to CoreSrv

### Optional: Add More Label Context

Enhance Promtail configs with additional labels via relabeling:

```yaml
pipeline_stages:
  - labels:
      environment:
      criticality:
      service_tier:
```

## References

- [Loki Documentation](https://grafana.com/docs/loki/latest/)
- [Promtail Configuration](https://grafana.com/docs/loki/latest/clients/promtail/configuration/)
- [LogQL Query Language](https://grafana.com/docs/loki/latest/logql/)
- [Grafana Explore](https://grafana.com/docs/grafana/latest/explore/)

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
