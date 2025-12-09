# Installation Guide

Complete step-by-step installation guide for Orion Sentinel CoreSrv.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Quick Install (Recommended)](#quick-install-recommended)
- [Manual Installation](#manual-installation)
- [Post-Installation Setup](#post-installation-setup)
- [Service Configuration](#service-configuration)
- [Troubleshooting](#troubleshooting)

## Prerequisites

### Hardware Requirements

**Minimum:**
- CPU: Intel i5 or AMD equivalent (4 cores)
- RAM: 16 GB
- Storage: 100 GB SSD + 500 GB HDD
- Network: Gigabit Ethernet

**Recommended:**
- CPU: Intel i7 or AMD equivalent (6+ cores)
- RAM: 32 GB
- Storage: 256 GB NVMe SSD + 2 TB HDD
- Network: Gigabit Ethernet with static IP

**Optional Hardware:**
- Intel iGPU for Jellyfin hardware transcoding
- Zigbee USB coordinator (Sonoff, ConBee II)
- P1 cable for Dutch smart meters (DSMR)

### Software Requirements

**Operating System (choose one):**
- Ubuntu Server 24.04 LTS (recommended)
- Ubuntu Server 22.04 LTS
- Debian 12 (Bookworm)
- Debian 11 (Bullseye)

**Required packages** (auto-installed by bootstrap):
- Docker Engine 24.0+
- Docker Compose v2.20+
- Git
- curl, wget

### Network Requirements

- Static IP address (recommended for server)
- Router access (for port forwarding if needed)
- Domain name (optional, for Traefik HTTPS)
- DNS server or hosts file access

## Quick Install (Recommended)

This method uses the automated bootstrap script for fastest setup.

### Step 1: Prepare System

```bash
# Update system
sudo apt update && sudo apt upgrade -y

# Install git
sudo apt install -y git

# Optional: Set static IP (recommended)
# Edit: sudo nano /etc/netplan/00-installer-config.yaml
```

### Step 2: Clone Repository

```bash
# Clone to home directory
cd ~
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv
```

### Step 3: Run Bootstrap

The bootstrap script will:
- ✅ Check and install Docker if needed
- ✅ Create directory structure
- ✅ Copy environment files
- ✅ Generate Authelia secrets
- ✅ Create Docker networks
- ✅ Set up basic configuration

```bash
# Run bootstrap (requires sudo)
sudo ./scripts/bootstrap-coresrv.sh
```

**Expected output:**
```
╔══════════════════════════════════════════════════════════════╗
║         Orion-Sentinel-CoreSrv Bootstrap Script              ║
╚══════════════════════════════════════════════════════════════╝

[INFO] Checking prerequisites...
[OK] Git is installed
[INFO] Checking Docker installation...
[OK] Docker is installed
[OK] Docker Compose is installed
[INFO] Creating directory structure...
[OK] Directory structure created
[INFO] Copying environment files...
[OK] Environment files copied
[INFO] Generating Authelia secrets...
[OK] Secrets generated
[OK] Bootstrap completed successfully!
```

### Step 4: Review Configuration (Optional)

```bash
# Review main environment file
nano .env

# Common settings to verify:
# - PUID/PGID (run 'id' to get yours)
# - TZ (your timezone)
# - DOMAIN (if using Traefik)
```

### Step 5: Deploy Services

**Option A: Media Stack Only (Quickest Start)**

```bash
make up-media
```

Access services:
- Jellyfin: http://localhost:8096
- Sonarr: http://localhost:8989
- Radarr: http://localhost:7878
- qBittorrent: http://localhost:5080

**Option B: Full Stack**

```bash
make up-full
```

**That's it!** You're running Orion Sentinel CoreSrv.

Continue to [Post-Installation Setup](#post-installation-setup) to configure services.

## Manual Installation

If you prefer manual control or troubleshooting the bootstrap:

### Step 1: Install Docker

**Ubuntu/Debian:**

```bash
# Remove old versions
sudo apt remove docker docker-engine docker.io containerd runc

# Install dependencies
sudo apt update
sudo apt install -y \
    ca-certificates \
    curl \
    gnupg \
    lsb-release

# Add Docker's official GPG key
sudo mkdir -p /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg

# Set up repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin

# Verify installation
docker --version
docker compose version
```

**Add user to docker group:**

```bash
sudo usermod -aG docker $USER
newgrp docker  # Activate group without logout
```

### Step 2: Clone Repository

```bash
cd ~
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv
```

### Step 3: Create Directory Structure

```bash
# Create base directory
sudo mkdir -p /srv/orion-sentinel-core

# Create subdirectories
sudo mkdir -p /srv/orion-sentinel-core/{core,media/{config,content},monitoring,home-automation}

# Create specific service directories
sudo mkdir -p /srv/orion-sentinel-core/core/{traefik,authelia,redis}
sudo mkdir -p /srv/orion-sentinel-core/media/config/{jellyfin,sonarr,radarr,prowlarr,jellyseerr,qbittorrent,bazarr}
sudo mkdir -p /srv/orion-sentinel-core/media/content/{downloads,library/{movies,tv}}
sudo mkdir -p /srv/orion-sentinel-core/monitoring/{prometheus,grafana,loki,promtail,uptime-kuma}
sudo mkdir -p /srv/orion-sentinel-core/home-automation/{homeassistant,zigbee2mqtt,mosquitto,mealie}
sudo mkdir -p /srv/orion-sentinel-core/search/searxng
sudo mkdir -p /srv/orion-sentinel-core/maintenance/homepage

# Set ownership
sudo chown -R $USER:$USER /srv/orion-sentinel-core
```

### Step 4: Configure Environment Files

```bash
# Copy main .env file
cp .env.example .env

# Generate Authelia secrets
AUTHELIA_JWT_SECRET=$(openssl rand -hex 32)
AUTHELIA_SESSION_SECRET=$(openssl rand -hex 32)
AUTHELIA_STORAGE_ENCRYPTION_KEY=$(openssl rand -hex 32)

# Update .env file with secrets
nano .env
# Set the secrets you just generated
# Also set PUID, PGID (run 'id' to find), TZ, DOMAIN
```

**Required .env settings:**

```bash
# User/Group
PUID=1000  # Your user ID
PGID=1000  # Your group ID

# Timezone
TZ=Europe/Amsterdam  # Your timezone

# Domain (for Traefik)
DOMAIN=local  # or your actual domain

# Authelia secrets (generated above)
AUTHELIA_JWT_SECRET=<your-generated-secret>
AUTHELIA_SESSION_SECRET=<your-generated-secret>
AUTHELIA_STORAGE_ENCRYPTION_KEY=<your-generated-secret>
```

**Copy module env files:**

```bash
# Copy all module environment files
cp env/.env.media.modular.example env/.env.media
cp env/.env.gateway.example env/.env.gateway
cp env/.env.observability.example env/.env.observability
cp env/.env.homeauto.example env/.env.homeauto

# Review and customize each
nano env/.env.media      # Media stack settings
nano env/.env.gateway    # Traefik/Authelia settings
# ... etc
```

### Step 5: Create Docker Networks

```bash
# Create all required networks
docker network create orion_media_net
docker network create orion_gateway_net
docker network create orion_backbone_net
docker network create orion_observability_net
docker network create orion_homeauto_net
```

### Step 6: Deploy Services

```bash
# Start with media stack
make up-media

# Or start everything
make up-full
```

## Post-Installation Setup

After installation, configure each service.

### 1. Configure Jellyfin

Access: http://localhost:8096 (or http://jellyfin.local with Traefik)

1. **Initial Setup Wizard**
   - Set preferred language
   - Create admin user
   - Set up media libraries:
     - Movies: `/media/library/movies`
     - TV Shows: `/media/library/tv`
   - Configure transcoding (use Intel QSV if available)
   - Complete setup

### 2. Configure Prowlarr (Indexer Manager)

Access: http://localhost:9696

1. **Add Indexers**
   - Click "Indexers" → "Add Indexer"
   - Search for your preferred torrent sites
   - Configure credentials/API keys

2. **Connect to Sonarr and Radarr**
   - Click "Apps" → "Add"
   - Select Sonarr/Radarr
   - Set:
     - Name: Sonarr / Radarr
     - Sync Level: Full Sync
     - Prowlarr Server: http://prowlarr:9696
     - Sonarr/Radarr Server: http://sonarr:8989 / http://radarr:7878
     - API Key: (from Sonarr/Radarr Settings → General)
   - Test and Save

### 3. Configure Sonarr (TV Shows)

Access: http://localhost:8989

1. **Add Download Client (qBittorrent)**
   - Settings → Download Clients → Add → qBittorrent
   - Host: qbittorrent
   - Port: 8080
   - Username: admin
   - Password: adminadmin (change in qBittorrent first!)
   - Category: tv-sonarr

2. **Configure Root Folders**
   - Series → Add New → Root Folder: `/media/library/tv`

3. **Set Quality Profile**
   - Settings → Profiles → Choose preferred quality

### 4. Configure Radarr (Movies)

Access: http://localhost:7878

1. **Add Download Client**
   - Settings → Download Clients → Add → qBittorrent
   - Same as Sonarr but Category: movies-radarr

2. **Configure Root Folder**
   - Movies → Add New → Root Folder: `/media/library/movies`

3. **Set Quality Profile**
   - Settings → Profiles → Choose preferred quality

### 5. Configure qBittorrent

Access: http://localhost:5080

1. **Login** (default admin/adminadmin)

2. **Change Password**
   - Tools → Options → Web UI
   - Change password from default

3. **Configure Categories** (optional)
   - Set up tv-sonarr and movies-radarr categories
   - Set save paths

### 6. Configure Jellyseerr (Request Management)

Access: http://localhost:5055

1. **Initial Setup**
   - Select "Sign in with Jellyfin"
   - Jellyfin URL: http://jellyfin:8096
   - Enter Jellyfin admin credentials
   - Import users

2. **Configure Sonarr**
   - Settings → Services → Sonarr → Add Server
   - Server Name: Sonarr
   - Host: sonarr
   - Port: 8989
   - API Key: (from Sonarr)
   - Default Quality Profile: HD-1080p
   - Root Folder: /media/library/tv

3. **Configure Radarr**
   - Settings → Services → Radarr → Add Server
   - Similar to Sonarr

### 7. Configure Traefik + Authelia (Optional)

If using reverse proxy:

1. **Set Domain in .env**
   ```bash
   nano .env
   # Set DOMAIN=yourdomain.com or local
   ```

2. **Configure DNS**
   - Add local DNS entries or /etc/hosts:
     ```
     192.168.1.100  jellyfin.local sonarr.local radarr.local
     ```

3. **Create Authelia Users**
   ```bash
   # Generate password hash
   docker run --rm authelia/authelia:latest \
     authelia crypto hash generate argon2 --password 'YourPassword'
   
   # Edit users file
   sudo nano /srv/orion-sentinel-core/core/authelia/users.yml
   ```

4. **Start Traefik**
   ```bash
   make up-traefik
   ```

### 8. Configure Home Assistant (Optional)

If deployed home automation:

Access: http://localhost:8123

1. **Initial Setup**
   - Create admin account
   - Set location and timezone
   - Configure integrations

2. **Add Zigbee2MQTT Integration** (if using Zigbee)
   - Settings → Devices & Services → Add Integration
   - Search for "MQTT"
   - Host: mosquitto
   - Port: 1883

## Service Configuration

### Media Library Structure

Recommended structure:

```
/srv/orion-sentinel-core/media/content/
├── downloads/          # qBittorrent downloads here
│   ├── complete/
│   └── incomplete/
└── library/           # Final organized media
    ├── movies/        # Radarr manages
    └── tv/            # Sonarr manages
```

### VPN Setup (Optional)

To route qBittorrent through VPN:

1. **Edit media env file**:
   ```bash
   nano env/.env.media
   ```

2. **Configure VPN**:
   ```bash
   VPN_ENABLED=true
   VPN_SERVICE_PROVIDER=protonvpn  # or mullvad, nordvpn, etc.
   VPN_WIREGUARD_PRIVATE_KEY=your-wireguard-key
   ```

3. **Restart with VPN profile**:
   ```bash
   docker compose -f compose/docker-compose.media.yml --profile media-vpn up -d
   ```

### Monitoring Setup

If using observability stack:

1. **Access Grafana**: http://localhost:3000
   - Default: admin/admin
   - Change password on first login

2. **Import Dashboards**:
   - Dashboards → Import
   - Upload JSON from `grafana_dashboards/`
   - Or import from Grafana.com (IDs: 1860, 893, 12486)

3. **Access Prometheus**: http://localhost:9090
   - Check targets: Status → Targets

4. **Access Uptime Kuma**: http://localhost:3001
   - Create admin account
   - Add monitors for your services

## Troubleshooting

### Services Won't Start

**Check logs:**
```bash
make logs SVC=<service-name>
```

**Common issues:**

1. **Permission errors:**
   ```bash
   # Check PUID/PGID in .env
   id
   # Update .env to match
   
   # Fix ownership
   sudo chown -R $USER:$USER /srv/orion-sentinel-core
   ```

2. **Port conflicts:**
   ```bash
   # Check what's using the port
   sudo netstat -tulpn | grep <port>
   
   # Stop conflicting service or change port in compose file
   ```

3. **Network issues:**
   ```bash
   # Recreate networks
   make down
   docker network prune
   make networks
   make up-full
   ```

### Can't Access Services

1. **Check if containers are running:**
   ```bash
   make status
   ```

2. **Check firewall:**
   ```bash
   sudo ufw status
   sudo ufw allow 8096/tcp  # For Jellyfin
   # ... allow other ports as needed
   ```

3. **Check Docker networks:**
   ```bash
   docker network ls
   docker network inspect orion_media_net
   ```

### Database/Config Issues

**Reset a service** (WARNING: Deletes data!):

```bash
# Stop service
make down

# Remove config
sudo rm -rf /srv/orion-sentinel-core/media/config/jellyfin

# Restart
make up-media

# Reconfigure through web UI
```

### Getting Help

1. **Check logs**: `make logs SVC=<service>`
2. **Check documentation**: See [README.md](../README.md)
3. **Check service logs**: Service-specific docs
4. **Open issue**: https://github.com/orionsentinel/Orion-Sentinel-CoreSrv/issues

## Next Steps

After installation:

1. **Set up backups**: See [backup/README.md](../backup/README.md)
2. **Review security**: See [docs/SECURITY-HARDENING.md](SECURITY-HARDENING.md)
3. **Configure monitoring**: See observability section above
4. **Plan updates**: See [docs/UPDATE.md](UPDATE.md)
5. **Read runbooks**: See [docs/RUNBOOKS.md](RUNBOOKS.md)

## See Also

- [README.md](../README.md) - Main documentation
- [docs/RUNBOOKS.md](RUNBOOKS.md) - Operational procedures
- [docs/UPDATE.md](UPDATE.md) - Update procedures
- [backup/README.md](../backup/README.md) - Backup and restore
- [docs/ARCHITECTURE.md](ARCHITECTURE.md) - System architecture
