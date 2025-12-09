# Deployment Guide - Orion-Sentinel-CoreSrv

Complete deployment guide for Orion Sentinel CoreSrv, from bare metal to fully operational.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Quick Deployment](#quick-deployment)
3. [Detailed Step-by-Step](#detailed-step-by-step)
4. [Post-Deployment Configuration](#post-deployment-configuration)
5. [Verification & Testing](#verification--testing)
6. [Troubleshooting](#troubleshooting)

---

## Prerequisites

### Hardware

- **Minimum**: Dell OptiPlex or similar with 8GB RAM, 100GB storage
- **Recommended**: 16GB+ RAM, 100GB SSD + 500GB+ HDD for media
- **Optional**: Intel iGPU for hardware transcoding, Zigbee USB coordinator

### Software

- **OS**: Ubuntu Server 24.04 LTS, Debian 12, or similar (clean install recommended)
- **Network**: Static IP address configured
- **Access**: SSH access and sudo privileges

### Network Setup

1. **Static IP**: Configure on your router or via netplan
2. **DNS**: Optional but recommended - add local DNS entries or use `/etc/hosts`
3. **Firewall**: Ensure ports 80 and 443 are accessible from your LAN

---

## Quick Deployment

For experienced users who want to deploy quickly:

```bash
# 1. Clone repository
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv

# 2. Run bootstrap (handles everything automatically)
./scripts/bootstrap-coresrv.sh

# 3. Start media stack
make up-media

# 4. Access Jellyfin
# Open browser: http://YOUR_IP:8096
```

Done! Media stack is running. Continue to [Post-Deployment Configuration](#post-deployment-configuration).

---

## Detailed Step-by-Step

### Phase 1: System Preparation

#### 1.1 Update System

```bash
sudo apt update && sudo apt upgrade -y
sudo apt install -y git curl wget vim nano
```

#### 1.2 Set Static IP (if not already done)

Edit netplan configuration:

```bash
sudo nano /etc/netplan/00-installer-config.yaml
```

Example configuration:

```yaml
network:
  version: 2
  ethernets:
    ens18:  # Your interface name
      addresses:
        - 192.168.1.100/24  # Your desired IP
      gateway4: 192.168.1.1
      nameservers:
        addresses:
          - 192.168.1.1
          - 1.1.1.1
```

Apply:

```bash
sudo netplan apply
```

#### 1.3 Set Hostname

```bash
sudo hostnamectl set-hostname orion-coresrv
```

### Phase 2: Install Docker

The bootstrap script can install Docker automatically, or you can do it manually:

#### Manual Docker Installation

```bash
# Install Docker
curl -fsSL https://get.docker.com | sudo sh

# Add your user to docker group
sudo usermod -aG docker $USER

# Install Docker Compose plugin
sudo apt install -y docker-compose-plugin

# Log out and back in for group changes
```

Verify installation:

```bash
docker --version
docker compose version
```

### Phase 3: Deploy Orion-Sentinel-CoreSrv

#### 3.1 Clone Repository

```bash
# Clone repository
cd ~
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv

# Ensure bootstrap script is executable (should already be, but just in case)
chmod +x scripts/bootstrap-coresrv.sh
```

#### 3.2 Run Bootstrap Script

```bash
./scripts/bootstrap-coresrv.sh
```

**What the bootstrap does:**
- Checks for Docker (installs if needed)
- Creates directory structure
- Copies .env files
- Generates secure secrets for Authelia
- Creates Docker networks
- Ready to deploy!

Answer the prompts:
- **Data root location**: Press Enter for default `/srv/orion-sentinel-core/` or specify custom path
- **Install Docker**: `Y` if not already installed
- **Proceed**: `Y` to continue

#### 3.3 Review Configuration

The bootstrap creates `.env` with sane defaults. Review and customize if needed:

```bash
nano .env
```

**Critical settings to review:**

```bash
# User/Group IDs (run 'id' to verify these match)
PUID=1000
PGID=1000

# Timezone
TZ=Europe/Amsterdam  # Change to your timezone

# Domain (for Traefik)
DOMAIN=local  # Or yourdomain.com for production

# Authelia secrets (auto-generated, verify they're not placeholder values)
AUTHELIA_JWT_SECRET=<long-hex-string>
AUTHELIA_SESSION_SECRET=<long-hex-string>
AUTHELIA_STORAGE_ENCRYPTION_KEY=<long-hex-string>
```

#### 3.4 Deploy Media Stack

Start with the media stack (most important services):

```bash
make up-media
```

This starts:
- Jellyfin (media streaming)
- Sonarr (TV shows)
- Radarr (movies)
- qBittorrent (torrent client)
- Prowlarr (indexer manager)
- Jellyseerr (request management)

**Wait 1-2 minutes** for all services to start.

Verify:

```bash
make status
```

All services should show as "Up" or "healthy".

### Phase 4: Add Reverse Proxy (Optional but Recommended)

#### 4.1 Configure Gateway

```bash
nano env/.env.gateway
```

Verify:
- `DOMAIN` is set correctly
- Authelia secrets are populated (should be auto-generated)

#### 4.2 Deploy Traefik + Authelia

```bash
make up-traefik
```

This adds:
- Traefik (reverse proxy with HTTPS)
- Authelia (SSO with 2FA)
- Redis (session storage)

#### 4.3 Configure DNS

For Traefik to work with friendly hostnames, you need DNS entries.

**Option A: /etc/hosts (simplest for testing)**

On your client machine:

```bash
# Linux/Mac
sudo nano /etc/hosts

# Windows
# Edit C:\Windows\System32\drivers\etc\hosts as Administrator
```

Add:

```
192.168.1.100  jellyfin.local sonarr.local radarr.local
192.168.1.100  qbit.local prowlarr.local requests.local
192.168.1.100  traefik.local auth.local
```

**Option B: Pi-hole or Router DNS**

Add local DNS records pointing all `*.local` to your CoreSrv IP.

**Option C: Split DNS**

Configure your DNS server to resolve `*.local` or `*.yourdomain.com` to CoreSrv.

### Phase 5: Add Monitoring (Optional)

```bash
make up-observability
```

This adds:
- Prometheus (metrics)
- Grafana (dashboards)
- Loki (logs)
- Uptime Kuma (uptime monitoring)
- Node Exporter (system metrics)
- cAdvisor (container metrics)

Access Grafana:
- Direct: http://YOUR_IP:3000
- Via Traefik: https://grafana.local

Default login: `admin` / `changeme` (set in `.env`)

### Phase 6: Add Home Automation (Optional)

Only if you need home automation features.

#### 6.1 Configure Hardware

Find your Zigbee coordinator:

```bash
ls -l /dev/serial/by-id/
# or
ls -l /dev/ttyACM* /dev/ttyUSB*
```

Update `.env`:

```bash
ZIGBEE_DEVICE=/dev/ttyACM0  # Your device path
```

#### 6.2 Deploy

```bash
make up-homeauto
```

This adds:
- Home Assistant
- Mosquitto (MQTT broker)
- Zigbee2MQTT
- Mealie (recipe manager)

---

## Post-Deployment Configuration

### Configure Media Services

#### 1. Prowlarr (Indexer Manager)

1. Access: http://YOUR_IP:9696 or https://prowlarr.local
2. Settings → Indexers → Add Indexers
3. Add your torrent indexers (sites)
4. Settings → Apps → Add Applications
   - Add Sonarr (http://sonarr:8989, get API key from Sonarr)
   - Add Radarr (http://radarr:7878, get API key from Radarr)
5. Click "Sync App Indexers" - indexers now available in Sonarr/Radarr

#### 2. qBittorrent

1. Access: http://YOUR_IP:5080 or https://qbit.local
2. Default login: `admin` / `adminadmin`
3. **Immediately change password**: Tools → Options → Web UI
4. Set download paths:
   - Tools → Options → Downloads
   - Default Save Path: `/downloads/`
   - Categories:
     - `movies` → `/downloads/movies/`
     - `tv` → `/downloads/tv/`

#### 3. Sonarr (TV Shows)

1. Access: http://YOUR_IP:8989 or https://sonarr.local
2. Settings → Media Management
   - Enable "Rename Episodes"
   - Standard Episode Format: `{Series Title} - S{season:00}E{episode:00} - {Episode Title}`
3. Settings → Download Clients → Add → qBittorrent
   - Host: `qbittorrent` (or `gluetun` if using VPN)
   - Port: `5080`
   - Category: `tv`
4. Settings → General → Copy API Key (needed for Jellyseerr)
5. Add root folder: `/media/library/tv/`

#### 4. Radarr (Movies)

1. Access: http://YOUR_IP:7878 or https://radarr.local
2. Settings → Media Management
   - Enable "Rename Movies"
   - Standard Movie Format: `{Movie Title} ({Release Year})`
3. Settings → Download Clients → Add → qBittorrent
   - Host: `qbittorrent` (or `gluetun` if using VPN)
   - Port: `5080`
   - Category: `movies`
4. Settings → General → Copy API Key
5. Add root folder: `/media/library/movies/`

#### 5. Jellyfin

1. Access: http://YOUR_IP:8096 or https://jellyfin.local
2. Initial setup wizard:
   - Set admin username and password
   - Add media libraries:
     - Movies: `/data/library/movies/`
     - TV Shows: `/data/library/tv/`
3. Dashboard → API Keys → Generate new key (needed for Jellyseerr)
4. (Optional) Enable hardware transcoding:
   - Dashboard → Playback → Hardware acceleration → Intel QuickSync

#### 6. Jellyseerr (Request Management)

1. Access: http://YOUR_IP:5055 or https://requests.local
2. Initial setup:
   - Connect to Jellyfin:
     - URL: `http://jellyfin:8096`
     - API Key: (from Jellyfin)
   - Connect to Sonarr:
     - URL: `http://sonarr:8989`
     - API Key: (from Sonarr)
   - Connect to Radarr:
     - URL: `http://radarr:7878`
     - API Key: (from Radarr)
3. Import Jellyfin users
4. Set up request permissions

### Configure Authelia (if using Traefik)

#### 1. Set Up Users

Edit user database:

```bash
nano /srv/orion-sentinel-core/core/authelia/users.yml
```

Example user:

```yaml
users:
  admin:
    displayname: "Admin User"
    password: "$argon2id$v=19$m=65536..."  # Generate with command below
    email: admin@example.com
    groups:
      - admins
```

#### 2. Generate Password Hash

```bash
docker run --rm authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'YourSecurePassword'
```

Copy the hash to `users.yml`.

#### 3. Restart Authelia

```bash
make restart SVC=authelia
```

#### 4. Test Login

1. Go to https://auth.local
2. Login with your credentials
3. Set up 2FA (TOTP or WebAuthn)

### Configure Grafana Dashboards

#### 1. Login

- URL: http://YOUR_IP:3000 or https://grafana.local
- Username: `admin`
- Password: (from `.env` GRAFANA_ADMIN_PASSWORD)

#### 2. Verify Data Sources

Go to Configuration → Data Sources:
- Prometheus should be auto-configured
- Loki should be auto-configured

#### 3. Import Dashboards

**Method A: From grafana_dashboards/ folder**

The system overview dashboard is already provisioned.

**Method B: Import from Grafana.com**

1. Go to Dashboards → Import
2. Enter dashboard ID:
   - **1860** - Node Exporter Full (system metrics)
   - **893** - Docker Monitoring
   - **12486** - Traefik 2
   - **13639** - Loki Logs
3. Select Prometheus as data source
4. Click Import

### Configure Homepage Dashboard

#### 1. Copy Configuration

```bash
cp maintenance/homepage/services-orion.yml \
   /srv/orion-sentinel-core/maintenance/homepage/services.yml
```

#### 2. Set API Keys

Edit `/srv/orion-sentinel-core/maintenance/homepage/services.yml`:

Replace placeholders:
- `${JELLYFIN_API_KEY}` - from Jellyfin
- `${SONARR_API_KEY}` - from Sonarr
- `${RADARR_API_KEY}` - from Radarr
- etc.

#### 3. Restart Homepage

```bash
make restart SVC=homepage
```

#### 4. Access

- Direct: http://YOUR_IP:3000
- Via Traefik: https://home.local

---

## Verification & Testing

### Service Health Check

```bash
make health
```

All services should show as healthy.

### Individual Service Tests

**Media Stack:**

```bash
# Jellyfin
curl http://localhost:8096/health

# Sonarr
curl http://localhost:8989/ping

# Radarr  
curl http://localhost:7878/ping

# Prowlarr
curl http://localhost:9696/ping
```

**Monitoring:**

```bash
# Prometheus
curl http://localhost:9090/-/healthy

# Grafana
curl http://localhost:3000/api/health
```

### Log Verification

Check for errors:

```bash
make logs SVC=jellyfin | grep -i error
make logs SVC=traefik | grep -i error
```

### Network Connectivity

From one container to another:

```bash
# Test Sonarr can reach qBittorrent
docker exec orion_sonarr ping -c 3 qbittorrent

# Test Jellyseerr can reach Jellyfin
docker exec orion_jellyseerr ping -c 3 jellyfin
```

---

## Troubleshooting

### Services Not Starting

**Check logs:**

```bash
make logs SVC=<service-name>
```

**Common issues:**

1. **Port already in use**
   ```bash
   sudo lsof -i :8096  # Check what's using port 8096
   sudo kill -9 <PID>  # Kill the process
   ```

2. **Permission denied**
   ```bash
   # Check PUID/PGID in .env match your user
   id
   # Fix ownership
   sudo chown -R $USER:$USER /srv/orion-sentinel-core
   ```

3. **Out of disk space**
   ```bash
   df -h
   make clean  # Clean up Docker
   ```

### Can't Access via Traefik

1. **Check Traefik is running:**
   ```bash
   make status | grep traefik
   ```

2. **Verify DNS resolution:**
   ```bash
   ping jellyfin.local
   ```

3. **Check Traefik logs:**
   ```bash
   make logs SVC=traefik
   ```

4. **Verify service labels:**
   ```bash
   docker inspect orion_jellyfin | grep traefik
   ```

### VPN Not Working

1. **Check Gluetun logs:**
   ```bash
   make logs SVC=gluetun
   ```

2. **Verify credentials:**
   ```bash
   # Check env/.env.media
   grep VPN_ env/.env.media
   ```

3. **Test VPN connection:**
   ```bash
   # Should show VPN IP, not your real IP
   docker exec orion_gluetun wget -qO- ifconfig.me
   ```

### Performance Issues

1. **Check resource usage:**
   ```bash
   docker stats
   htop  # or top
   ```

2. **Reduce Jellyfin transcoding:**
   - Enable hardware acceleration
   - Reduce max simultaneous streams

3. **Increase memory limits** in compose files if needed

### Database Corruption

If a service won't start due to database issues:

```bash
# Example for Sonarr
make down
sudo rm -rf /srv/orion-sentinel-core/media/config/sonarr/sonarr.db*
make up-media
# Reconfigure Sonarr
```

**Always backup first!**

---

## Next Steps

1. **Configure Backups**: Set up automated backups with `make backup`
2. **Enable 2FA**: Set up two-factor authentication in Authelia
3. **Add Content**: Start adding movies and TV shows via Jellyseerr
4. **Customize**: Adjust settings, themes, and preferences
5. **Monitor**: Set up alerts in Uptime Kuma and Grafana
6. **Secure**: Review security settings and rotate secrets regularly

---

## Quick Reference

### Common Commands

```bash
# Start services
make up-media           # Media stack
make up-full            # Everything

# Manage services
make status             # Check status
make logs SVC=<name>    # View logs
make restart SVC=<name> # Restart service
make down               # Stop all

# Maintenance
make pull               # Update images
make backup             # Backup configs
make clean              # Clean up

# Help
make help               # Show all commands
```

### Service URLs

**Direct Access (HTTP):**
- Jellyfin: http://YOUR_IP:8096
- Sonarr: http://YOUR_IP:8989
- Radarr: http://YOUR_IP:7878
- qBittorrent: http://YOUR_IP:5080
- Prowlarr: http://YOUR_IP:9696
- Jellyseerr: http://YOUR_IP:5055
- Grafana: http://YOUR_IP:3000

**Via Traefik (HTTPS):**
- Jellyfin: https://jellyfin.local
- Sonarr: https://sonarr.local
- Radarr: https://radarr.local
- qBittorrent: https://qbit.local
- Prowlarr: https://prowlarr.local
- Jellyseerr: https://requests.local
- Grafana: https://grafana.local
- Traefik: https://traefik.local
- Authelia: https://auth.local

### Default Credentials

**qBittorrent:**
- Username: `admin`
- Password: `adminadmin`
- **Change immediately!**

**Grafana:**
- Username: `admin`
- Password: (set in `.env` as `GRAFANA_ADMIN_PASSWORD`)

**Authelia:**
- Configure in `/srv/orion-sentinel-core/core/authelia/users.yml`

---

**Deployment Complete!** 🎉

Your Orion Sentinel CoreSrv stack is now operational. Enjoy your self-hosted media center!
