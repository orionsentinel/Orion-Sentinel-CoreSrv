# Deployment Checklist

Use this checklist for deploying Orion-Sentinel-CoreSrv in production.

## Pre-Deployment

### Host Preparation

- [ ] **Install Ubuntu/Debian Server** (recommended: Ubuntu 22.04 LTS or later)
- [ ] **Update system:**
  ```bash
  sudo apt update && sudo apt upgrade -y
  ```
- [ ] **Install Docker:**
  ```bash
  curl -fsSL https://get.docker.com | sudo sh
  sudo usermod -aG docker $USER
  ```
- [ ] **Install Docker Compose plugin:**
  ```bash
  sudo apt install docker-compose-plugin
  ```
- [ ] **Create orion user:**
  ```bash
  sudo useradd -r -m -s /usr/sbin/nologin orion
  id orion  # Note UID/GID (e.g., 1001:1001)
  ```

### Directory Structure

- [ ] **Create directories:**
  ```bash
  sudo mkdir -p \
    /srv/orion-sentinel-core/config \
    /srv/orion-sentinel-core/data \
    /srv/orion-sentinel-core/media/torrents \
    /srv/orion-sentinel-core/media/library/movies \
    /srv/orion-sentinel-core/media/library/tv \
    /srv/orion-sentinel-core/cloud/db \
    /srv/orion-sentinel-core/cloud/app \
    /srv/orion-sentinel-core/cloud/data \
    /srv/orion-sentinel-core/monitoring \
    /srv/orion-sentinel-core/backups
  
  sudo chown -R orion:orion /srv/orion-sentinel-core
  ```

### Security Hardening (Host)

- [ ] **Configure SSH:**
  ```bash
  # Edit /etc/ssh/sshd_config
  sudo nano /etc/ssh/sshd_config
  # Set: PermitRootLogin no
  # Set: PasswordAuthentication no
  # Set: PubkeyAuthentication yes
  sudo systemctl restart sshd
  ```

- [ ] **Configure firewall (ufw):**
  ```bash
  sudo ufw allow 22/tcp      # SSH
  sudo ufw allow 80/tcp      # HTTP (Traefik)
  sudo ufw allow 443/tcp     # HTTPS (Traefik)
  # Optional: Loki for remote Promtail (LAN only)
  # sudo ufw allow from 192.168.0.0/16 to any port 3100 proto tcp
  sudo ufw enable
  ```

- [ ] **Configure time sync:**
  ```bash
  sudo systemctl enable systemd-timesyncd
  sudo systemctl start systemd-timesyncd
  timedatectl status
  ```

### Repository Setup

- [ ] **Clone repository:**
  ```bash
  cd /opt
  sudo git clone https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv.git
  cd Orion-Sentinel-CoreSrv
  ```

- [ ] **Make scripts executable:**
  ```bash
  chmod +x scripts/*.sh
  ```

## Configuration

### Environment Files

- [ ] **Copy environment examples:**
  ```bash
  cp env/.env.core.example env/.env.core
  cp env/.env.media.example env/.env.media
  cp env/.env.monitoring.example env/.env.monitoring
  cp env/.env.cloud.example env/.env.cloud
  cp env/.env.search.example env/.env.search
  ```

- [ ] **Set permissions:**
  ```bash
  chmod 600 env/.env.*
  ```

### Core Configuration (.env.core)

- [ ] **Generate secrets:**
  ```bash
  # Generate three secrets (or use same for all three)
  openssl rand -hex 32  # AUTHELIA_JWT_SECRET
  openssl rand -hex 32  # AUTHELIA_SESSION_SECRET
  openssl rand -hex 32  # AUTHELIA_STORAGE_ENCRYPTION_KEY
  ```

- [ ] **Edit env/.env.core:**
  ```bash
  nano env/.env.core
  ```
  Set:
  - `CONFIG_ROOT=/srv/orion-sentinel-core/config`
  - `PUID=1001` (orion user UID from `id orion`)
  - `PGID=1001` (orion group GID)
  - `TZ=Europe/Amsterdam` (your timezone)
  - `AUTHELIA_JWT_SECRET=<generated-secret>`
  - `AUTHELIA_SESSION_SECRET=<generated-secret>`
  - `AUTHELIA_STORAGE_ENCRYPTION_KEY=<generated-secret>`

### Media Configuration (.env.media)

- [ ] **Edit env/.env.media:**
  ```bash
  nano env/.env.media
  ```
  Set:
  - `DOWNLOAD_ROOT=/srv/orion-sentinel-core/media/torrents`
  - `MEDIA_LIBRARY_ROOT=/srv/orion-sentinel-core/media/library`
  - `TV_ROOT=/srv/orion-sentinel-core/media/library/tv`
  - `MOVIES_ROOT=/srv/orion-sentinel-core/media/library/movies`
  - VPN credentials (ProtonVPN WireGuard):
    - `VPN_WIREGUARD_PRIVATE_KEY=<your-private-key>`
    - `VPN_WIREGUARD_ADDRESS=<your-wg-address>`
    - `VPN_COUNTRY=<country>` (e.g., Netherlands)

### Monitoring Configuration (.env.monitoring)

- [ ] **Edit env/.env.monitoring:**
  ```bash
  nano env/.env.monitoring
  ```
  Set:
  - `MONITORING_ROOT=/srv/orion-sentinel-core/monitoring`
  - `GRAFANA_ADMIN_PASSWORD=<strong-password>`
  - `PROMETHEUS_RETENTION_TIME=15d`

### Cloud Configuration (.env.cloud)

- [ ] **Edit env/.env.cloud:**
  ```bash
  nano env/.env.cloud
  ```
  Set:
  - `CLOUD_ROOT=/srv/orion-sentinel-core/cloud`
  - `NEXTCLOUD_DB_PASSWORD=<strong-password>`
  - `NEXTCLOUD_ADMIN_PASSWORD=<strong-password>`

### Authelia User Setup

- [ ] **Generate password hash:**
  ```bash
  docker run --rm -it authelia/authelia:4.38.6 authelia hash-password
  # Enter your password when prompted
  # Copy the hash output
  ```

- [ ] **Create user file:**
  ```bash
  cp core/authelia/users.yml.example /srv/orion-sentinel-core/config/authelia/users.yml
  nano /srv/orion-sentinel-core/config/authelia/users.yml
  ```
  Replace:
  - `password:` with your generated hash
  - `email:` with your email
  - `displayname:` with your name

- [ ] **Set permissions:**
  ```bash
  chmod 600 /srv/orion-sentinel-core/config/authelia/users.yml
  ```

### Traefik Configuration

- [ ] **Copy Traefik configs:**
  ```bash
  sudo cp -r core/traefik /srv/orion-sentinel-core/config/
  ```

- [ ] **Optional: Configure Let's Encrypt (DNS-01):**
  - Edit `core/traefik/traefik.yml`
  - Uncomment `certificatesResolvers` section
  - Set DNS provider in `.env.core` (e.g., Cloudflare, Route53)
  - Add provider credentials to `.env.core`

### Prometheus Targets

- [ ] **Update Prometheus targets:**
  ```bash
  nano monitoring/prometheus/prometheus.yml
  ```
  Adjust IP addresses:
  - Pi DNS: Change `192.168.8.240` to your Pi DNS IP
  - Pi NetSec: Change `192.168.8.241` to your Pi NetSec IP

## Phase 1: Core Services

### Start Core (Traefik + Authelia)

- [ ] **Start core profile:**
  ```bash
  ./scripts/orionctl.sh up-core
  ```

- [ ] **Check logs:**
  ```bash
  docker logs traefik
  docker logs authelia
  ```

### Verify Core Services

- [ ] **Test Authelia:**
  - Navigate to `https://auth.local`
  - Log in with your username/password
  - Set up TOTP MFA (scan QR code with authenticator app)

- [ ] **Test Traefik:**
  - Navigate to `https://traefik.local`
  - Should redirect to Authelia for login
  - After auth, view Traefik dashboard

- [ ] **Check health:**
  ```bash
  ./scripts/orionctl.sh health
  ```

## Phase 2: Monitoring

### Start Monitoring Stack

- [ ] **Start monitoring profile:**
  ```bash
  ./scripts/orionctl.sh up-monitoring
  ```

- [ ] **Check logs:**
  ```bash
  docker logs prometheus
  docker logs grafana
  docker logs loki
  ```

### Configure Grafana

- [ ] **Access Grafana:**
  - Navigate to `https://grafana.local`
  - Authenticate via Authelia
  - Login: `admin` / `<GRAFANA_ADMIN_PASSWORD>`

- [ ] **Verify datasources:**
  - Grafana → Configuration → Data sources
  - Prometheus: Test connection (should be green)
  - Loki: Test connection (should be green)

- [ ] **Import dashboards:**
  - Node Exporter Full (ID: 1860)
  - Docker Container & Host Metrics (ID: 14282)
  - Loki Dashboard (ID: 13639)
  - Traefik 2 (ID: 11462)

### Configure Uptime Kuma

- [ ] **Access Uptime Kuma:**
  - Navigate to `https://status.local`
  - Create admin account
  - Add HTTP monitors for:
    - `https://traefik.local`
    - `https://auth.local`
    - `https://grafana.local`
    - `https://prometheus.local`

## Phase 3: Media Stack

### Start Media Services

- [ ] **Start media profiles:**
  ```bash
  # Only media
  docker compose --env-file env/.env.core --env-file env/.env.media \
    --profile core --profile media-core --profile media-ai up -d
  
  # OR use orionctl for full stack
  ./scripts/orionctl.sh up-full
  ```

### Configure Media Services

- [ ] **Jellyfin:**
  - Navigate to `https://jellyfin.local`
  - Complete setup wizard
  - Add media libraries (`/media/movies`, `/media/tv`)

- [ ] **Prowlarr:**
  - Navigate to `https://prowlarr.local`
  - Add indexers
  - Copy API key

- [ ] **Sonarr:**
  - Navigate to `https://sonarr.local`
  - Settings → Indexers → Add Prowlarr
  - Settings → Download Clients → Add qBittorrent
    - Host: `vpn` (service name)
    - Port: `8080`
  - Add root folder: `/tv`

- [ ] **Radarr:**
  - Navigate to `https://radarr.local`
  - Settings → Indexers → Add Prowlarr
  - Settings → Download Clients → Add qBittorrent
  - Add root folder: `/movies`

- [ ] **Bazarr:**
  - Navigate to `https://bazarr.local`
  - Connect to Sonarr and Radarr

- [ ] **Jellyseerr:**
  - Navigate to `https://requests.local`
  - Connect to Jellyfin
  - Connect to Sonarr and Radarr

### Verify VPN Isolation

- [ ] **Check qBittorrent public IP:**
  ```bash
  docker exec qbittorrent curl -s ifconfig.me
  ```
  Should show VPN IP, not your ISP IP.

## Phase 4: Cloud & Additional Services

### Nextcloud (Optional)

- [ ] **Start cloud profile:**
  ```bash
  docker compose --env-file env/.env.core --env-file env/.env.cloud \
    --profile core --profile cloud up -d
  ```

- [ ] **Access Nextcloud:**
  - Navigate to `https://cloud.local`
  - Complete setup wizard

### SearXNG (Optional)

- [ ] **Start search profile:**
  ```bash
  docker compose --env-file env/.env.core --env-file env/.env.search \
    --profile core --profile search up -d
  ```

- [ ] **Access SearXNG:**
  - Navigate to `https://search.local`
  - Optionally configure engines in `search/searxng/settings.yml`

### Home Assistant (Optional)

- [ ] **Start home-automation profile:**
  ```bash
  docker compose --env-file env/.env.core \
    --profile core --profile home-automation up -d
  ```

- [ ] **Access Home Assistant:**
  - Navigate to `https://ha.local`
  - Complete onboarding

## Post-Deployment

### Backups

- [ ] **Test backup script:**
  ```bash
  ./scripts/backup.sh
  ls -lh /srv/orion-sentinel-core/backups/
  ```

- [ ] **Schedule automatic backups:**
  ```bash
  sudo crontab -e
  # Add: 0 2 * * * /opt/Orion-Sentinel-CoreSrv/scripts/backup.sh
  ```

### Remote Logging (Pi Nodes)

- [ ] **Expose Loki port (optional):**
  - Uncomment `ports: - "3100:3100"` in `loki` service
  - Restart: `docker compose up -d loki`

- [ ] **Deploy Promtail on Pi DNS:**
  ```bash
  # On Pi DNS
  docker run -d --name promtail --restart unless-stopped \
    -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v /path/to/agents/pi-dns/promtail-config.yml:/etc/promtail/config.yml:ro \
    grafana/promtail:2.9.5 -config.file=/etc/promtail/config.yml
  ```
  (Adjust `CORESRV_LAN_IP` in config first)

- [ ] **Deploy Promtail on Pi NetSec:**
  ```bash
  # On Pi NetSec
  docker run -d --name promtail --restart unless-stopped \
    -v /var/lib/docker/containers:/var/lib/docker/containers:ro \
    -v /var/run/docker.sock:/var/run/docker.sock:ro \
    -v /path/to/agents/pi-netsec/promtail-config.yml:/etc/promtail/config.yml:ro \
    grafana/promtail:2.9.5 -config.file=/etc/promtail/config.yml
  ```

- [ ] **Verify logs in Grafana Explore:**
  ```logql
  {host="pi-dns"}    # Pi DNS logs
  {host="pi-netsec"} # Pi NetSec logs
  ```

### Monitoring Pi Nodes

- [ ] **Deploy node_exporter on Pi DNS:**
  ```bash
  docker run -d --name node-exporter --restart unless-stopped \
    --net="host" --pid="host" \
    -v "/:/host:ro,rslave" \
    prom/node-exporter:v1.7.0 \
    --path.rootfs=/host
  ```

- [ ] **Deploy node_exporter on Pi NetSec:**
  ```bash
  docker run -d --name node-exporter --restart unless-stopped \
    --net="host" --pid="host" \
    -v "/:/host:ro,rslave" \
    prom/node-exporter:v1.7.0 \
    --path.rootfs=/host
  ```

- [ ] **Verify Pi metrics in Prometheus:**
  - Navigate to `https://prometheus.local`
  - Status → Targets
  - Check `pi-dns-node` and `pi-netsec-node` are "UP"

### Security Audit

- [ ] **Review Authelia logs:**
  ```bash
  docker logs authelia | grep -i "authentication"
  ```

- [ ] **Review Traefik access logs:**
  ```logql
  # In Grafana Explore (Loki)
  {container_name="traefik"} |= "access"
  ```

- [ ] **Test SSO protection:**
  - Try accessing protected service without auth (should redirect to Authelia)
  - Verify TOTP required for login

- [ ] **Verify VPN killswitch:**
  - Stop VPN container: `docker stop vpn`
  - Check qBittorrent logs: should show no connectivity
  - Restart VPN: `docker start vpn`

### Documentation

- [ ] **Read security guide:**
  ```bash
  cat docs/SECURITY-HARDENING.md
  ```

- [ ] **Review runbooks:**
  ```bash
  cat docs/RUNBOOKS.md
  ```

- [ ] **Review backup/restore procedure:**
  ```bash
  cat docs/BACKUP-RESTORE.md
  ```

## Ongoing Maintenance

### Weekly

- [ ] **Check service health:**
  ```bash
  ./scripts/orionctl.sh health
  docker ps --filter "health=unhealthy"
  ```

- [ ] **Review logs for errors:**
  ```logql
  # In Grafana Explore
  {job="docker"} |~ "(?i)error"
  ```

- [ ] **Run backup:**
  ```bash
  ./scripts/backup.sh
  ```

### Monthly

- [ ] **Update Docker images:**
  ```bash
  ./scripts/orionctl.sh pull
  docker compose up -d
  ```

- [ ] **Review Authelia auth logs:**
  ```logql
  {container_name="authelia"} |= "authentication"
  ```

- [ ] **Review Prometheus alerts (if configured)**

- [ ] **Test disaster recovery (every 3 months)**

### Quarterly

- [ ] **Rotate secrets** (see `docs/SECRETS.md`)

- [ ] **Check upstream repos for updates:**
  - See `docs/UPSTREAM-SYNC.md`
  - Compare compose.yml with upstream changes
  - Update image versions if needed

- [ ] **Audit access control rules:**
  - Review `core/authelia/configuration.yml`
  - Review Traefik labels and middlewares

---

**Last Updated:** 2024-11-23  
**Stack Version:** Production v1.0
