# CoreSrv Setup Guide

This guide walks through setting up the CoreSrv as the Orion home lab services hub.

## Table of Contents

1. [Prerequisites](#prerequisites)
2. [Operating System Installation](#operating-system-installation)
3. [Initial System Configuration](#initial-system-configuration)
4. [Docker Installation](#docker-installation)
5. [Directory Structure Setup](#directory-structure-setup)
6. [Network Configuration](#network-configuration)
7. [Repository Setup](#repository-setup)
8. [Service Deployment](#service-deployment)
9. [Post-Deployment Configuration](#post-deployment-configuration)

---

## Prerequisites

### Hardware Requirements

- **CoreSrv** (recommended: 16GB+ RAM, 256GB+ SSD)
- **Storage:**
  - System: 50GB minimum
  - Config: 10GB minimum
  - Media: 500GB+ recommended (external drive acceptable)
- **Network:** Gigabit Ethernet (preferred over Wi-Fi for reliability)

### Network Requirements

- Static IP address on LAN (recommended)
- DNS server: Pi 5 #1 (Pi-hole + Unbound)
- Accessible ports:
  - 80 (HTTP) - Traefik
  - 443 (HTTPS) - Traefik
  - 8123 (optional) - Home Assistant (if using host networking)

---

## Operating System Installation

### Recommended: Ubuntu Server 24.04 LTS

1. **Download Ubuntu Server:**
   ```bash
   # Download from https://ubuntu.com/download/server
   # Use 24.04 LTS for long-term support
   ```

2. **Create Bootable USB:**
   ```bash
   # Linux/Mac:
   sudo dd if=ubuntu-24.04-live-server-amd64.iso of=/dev/sdX bs=4M status=progress
   
   # Windows: Use Rufus or Balena Etcher
   ```

3. **Install Ubuntu Server:**
   - Boot from USB
   - Choose "Ubuntu Server" (not minimal)
   - Configure network (static IP recommended)
   - Partition disk (use entire disk, LVM optional)
   - Create user account (e.g., `orion`)
   - Enable OpenSSH server
   - Do NOT install additional snaps yet

### Alternative: Debian 12 (Bookworm)

Ubuntu Server is recommended for beginners, but Debian 12 is also fully supported.

---

## Initial System Configuration

### 1. Update System

```bash
sudo apt update && sudo apt upgrade -y
sudo apt autoremove -y
```

### 2. Install Essential Packages

```bash
sudo apt install -y \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg \
    lsb-release \
    git \
    vim \
    htop \
    tree \
    net-tools \
    nfs-common \
    cifs-utils
```

### 3. Configure Static IP (if not done during install)

Edit netplan configuration:

```bash
sudo vim /etc/netplan/00-installer-config.yaml
```

Example configuration:

```yaml
network:
  version: 2
  ethernets:
    eth0:  # Adjust interface name as needed
      dhcp4: false
      addresses:
        - 192.168.1.100/24  # Adjust to your network
      routes:
        - to: default
          via: 192.168.1.1  # Your router IP
      nameservers:
        addresses:
          - 192.168.1.10    # Pi 5 #1 (Pi-hole) - PRIMARY DNS
          - 1.1.1.1         # Cloudflare (fallback)
```

Apply configuration:

```bash
sudo netplan apply
```

### 4. Set Hostname

```bash
sudo hostnamectl set-hostname Orion-Sentinel-CoreSrv
```

Edit `/etc/hosts`:

```bash
sudo vim /etc/hosts
```

Add:

```
127.0.0.1       localhost
192.168.1.100   Orion-Sentinel-CoreSrv.local Orion-Sentinel-CoreSrv

# The following lines are desirable for IPv6 capable hosts
::1     localhost ip6-localhost ip6-loopback
ff02::1 ip6-allnodes
ff02::2 ip6-allrouters
```

### 5. Configure Firewall (UFW)

```bash
sudo ufw default deny incoming
sudo ufw default allow outgoing
sudo ufw allow ssh
sudo ufw allow 80/tcp    # HTTP (Traefik)
sudo ufw allow 443/tcp   # HTTPS (Traefik)
sudo ufw enable
```

---

## Docker Installation

### 1. Install Docker Engine

```bash
# Add Docker's official GPG key
sudo install -m 0755 -d /etc/apt/keyrings
curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
sudo chmod a+r /etc/apt/keyrings/docker.gpg

# Add Docker repository
echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  sudo tee /etc/apt/sources.list.d/docker.list > /dev/null

# Install Docker
sudo apt update
sudo apt install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
```

### 2. Post-Installation Steps

```bash
# Add your user to the docker group (avoid using sudo for docker commands)
sudo usermod -aG docker $USER

# Log out and back in for group changes to take effect
# Or run: newgrp docker

# Verify Docker installation
docker --version
docker compose version
```

### 3. Configure Docker Daemon

Create `/etc/docker/daemon.json`:

```bash
sudo vim /etc/docker/daemon.json
```

Add:

```json
{
  "log-driver": "json-file",
  "log-opts": {
    "max-size": "10m",
    "max-file": "3"
  },
  "dns": ["192.168.1.10", "1.1.1.1"],
  "storage-driver": "overlay2"
}
```

Restart Docker:

```bash
sudo systemctl restart docker
sudo systemctl enable docker
```

---

## Directory Structure Setup

### 1. Create Orion Root Directory

```bash
sudo mkdir -p /srv/orion-sentinel-core
sudo chown -R $USER:$USER /srv/orion-sentinel-core
```

### 2. Create Directory Structure

```bash
cd /srv/orion-sentinel-core

# Create main directories
mkdir -p config data media cloud monitoring

# Create media subdirectories (hardlink-friendly layout)
mkdir -p media/torrents/{movies,tv}
mkdir -p media/library/{movies,tv}

# Create cloud subdirectories
mkdir -p cloud/{db,app,data}

# Create monitoring subdirectories
mkdir -p monitoring/{prometheus,grafana,loki}

# Verify structure
tree -L 2 /srv/orion-sentinel-core
```

Expected output:

```
/srv/orion-sentinel-core-sentinel-core/
├── cloud
│   ├── app
│   ├── data
│   └── db
├── config
├── data
├── media
│   ├── library
│   └── torrents
└── monitoring
    ├── grafana
    ├── loki
    └── prometheus
```

### 3. Set Permissions

```bash
# Get your PUID and PGID
id

# Set ownership (adjust PUID/PGID as needed)
sudo chown -R 1000:1000 /srv/orion-sentinel-core

# Set permissions
chmod -R 755 /srv/orion-sentinel-core
```

### 4. (Optional) Mount External Storage

If using external drive for media:

```bash
# Find drive
lsblk

# Create mount point
sudo mkdir -p /mnt/media-drive

# Get UUID
sudo blkid /dev/sdX1  # Replace with your drive

# Edit fstab
sudo vim /etc/fstab

# Add line (replace UUID):
UUID=your-uuid-here /mnt/media-drive ext4 defaults,nofail 0 2

# Mount
sudo mount -a

# Symlink to /srv/orion-sentinel-core-sentinel-core/media
rm -rf /srv/orion-sentinel-core-sentinel-core/media
ln -s /mnt/media-drive /srv/orion-sentinel-core-sentinel-core/media
```

---

## Network Configuration

### 1. DNS Resolution

Ensure CoreSrv is using Pi 5 #1 (Pi-hole) as primary DNS:

```bash
# Check current DNS
resolvectl status

# If needed, update netplan (see step 3 of Initial System Configuration)
```

### 2. Test Connectivity

```bash
# Test internet
ping -c 4 1.1.1.1

# Test DNS via Pi-hole
ping -c 4 google.com

# Test Pi DNS
ping -c 4 pi-dns.local  # Adjust hostname

# Test Pi NetSec
ping -c 4 pi-netsec.local  # Adjust hostname
```

### 3. (Optional) Configure Local DNS Entries

Add local DNS entries to Pi-hole for service discovery:

```
192.168.1.100   Orion-Sentinel-CoreSrv.local
192.168.1.100   jellyfin.local
192.168.1.100   requests.local
192.168.1.100   qbit.local
192.168.1.100   sonarr.local
192.168.1.100   radarr.local
192.168.1.100   prowlarr.local
192.168.1.100   recommend.local
192.168.1.100   cloud.local
192.168.1.100   search.local
192.168.1.100   grafana.local
192.168.1.100   prometheus.local
192.168.1.100   status.local
192.168.1.100   home.local
192.168.1.100   auth.local
192.168.1.100   traefik.local
```

---

## Repository Setup

### 1. Clone Repository

```bash
cd ~
git clone https://github.com/yorgosroussakis/Orion-Sentinel-CoreSrv.git Orion-Sentinel-CoreSrv
cd Orion-Sentinel-CoreSrv
```

### 2. Copy Environment Files

```bash
# Copy all example env files
cp env/.env.core.example env/.env.core
cp env/.env.media.example env/.env.media
cp env/.env.monitoring.example env/.env.monitoring
cp env/.env.cloud.example env/.env.cloud
cp env/.env.search.example env/.env.search
cp env/.env.home-automation.example env/.env.home-automation
cp env/.env.maintenance.example env/.env.maintenance
```

### 3. Configure Environment Variables

Edit each `.env.*` file and customize:

```bash
vim env/.env.core
vim env/.env.media
# ... etc.
```

**Critical variables to change:**

- `PUID` / `PGID` - Your user ID (run `id`)
- `TZ` - Your timezone (e.g., `Europe/Amsterdam`)
- All `*_PASSWORD` and `*_SECRET` variables
- `DOMAIN` - Your domain (or keep `local` for LAN-only)
- VPN credentials in `.env.media`
- ACME email in `.env.core`

---

## Service Deployment

### 1. Start Core Services First

```bash
cd ~/Orion-Sentinel-CoreSrv

# Start Traefik + Authelia
docker compose --profile core up -d

# Check logs
docker compose logs -f traefik authelia
```

### 2. Configure Authelia

1. Access Authelia: `https://auth.local`
2. Create initial user (see `core/authelia/users.yml`)
3. Set up 2FA (recommended)

### 3. Start Media Stack

```bash
# Start media-core profile
docker compose --profile media-core up -d

# Check logs
docker compose logs -f jellyfin sonarr radarr vpn qbittorrent
```

### 4. Start Additional Services

```bash
# Start all services
docker compose --profile core --profile media-core --profile media-ai --profile cloud --profile search --profile monitoring --profile maintenance up -d

# Or use individual profiles as needed
docker compose --profile cloud up -d
docker compose --profile monitoring up -d
```

### 5. Verify Services

```bash
# Check running containers
docker compose ps

# Check networks
docker network ls | grep orion

# Check service health
docker compose ps --format json | jq -r '.[] | "\(.Name): \(.Status)"'
```

---

## Post-Deployment Configuration

### 1. Configure Media Services

Access each service and complete initial setup:

1. **Prowlarr** (`https://qbit.local`):
   - Add indexers
   - Connect to Sonarr/Radarr

2. **Sonarr** (`https://sonarr.local`):
   - Add Prowlarr as indexer
   - Connect to qBittorrent
   - Add root folder: `/library/tv`

3. **Radarr** (`https://radarr.local`):
   - Add Prowlarr as indexer
   - Connect to qBittorrent
   - Add root folder: `/library/movies`

4. **Jellyfin** (`https://jellyfin.local`):
   - Add libraries: `/library/movies`, `/library/tv`
   - Configure metadata providers

5. **Jellyseerr** (`https://requests.local`):
   - Connect to Jellyfin
   - Connect to Sonarr/Radarr

### 2. Configure Monitoring

1. **Grafana** (`https://grafana.local`):
   - Login with admin credentials
   - Add Prometheus datasource
   - Import dashboards

2. **Prometheus** (`https://prometheus.local`):
   - Verify targets are being scraped
   - Add scrape configs for Pi DNS + NetSec

3. **Uptime Kuma** (`https://status.local`):
   - Add monitors for all services
   - Configure notifications

### 3. Configure Homepage Dashboard

Edit `maintenance/homepage/config.yml` to add service tiles.

---

## Troubleshooting

### Common Issues

**Services not accessible:**
- Check Traefik logs: `docker compose logs traefik`
- Verify DNS resolution: `nslookup jellyfin.local`
- Check firewall: `sudo ufw status`

**VPN not working:**
- Check Gluetun logs: `docker compose logs vpn`
- Verify VPN credentials in `.env.media`
- Test connectivity: `docker compose exec vpn curl ifconfig.me`

**Permissions errors:**
- Verify PUID/PGID in env files: `id`
- Check directory ownership: `ls -la /srv/orion-sentinel-core`
- Fix ownership: `sudo chown -R 1000:1000 /srv/orion-sentinel-core`

---

## Next Steps

1. Review [ARCHITECTURE.md](ARCHITECTURE.md) for system overview
2. Review [UPSTREAM-SYNC.md](UPSTREAM-SYNC.md) for maintenance workflow
3. Set up automated backups for critical data
4. Configure monitoring dashboards
5. Customize Authelia access policies

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
