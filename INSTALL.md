# Quick Installation Guide

This guide will help you install Orion Sentinel CoreSrv in **5 simple steps**.

For detailed setup instructions, see [docs/SETUP-CoreSrv.md](docs/SETUP-CoreSrv.md).

---

## Prerequisites

- **Operating System:** Ubuntu Server 24.04 LTS or Debian 12 (recommended)
- **Hardware:** 16GB+ RAM, 100GB+ storage (500GB+ for media)
- **Network:** Static IP address on your LAN
- **Required Software:** Docker Engine + Docker Compose plugin

---

## Step 1: Install Docker

If you don't have Docker installed, run:

```bash
# Install Docker Engine
curl -fsSL https://get.docker.com | sudo sh

# Add your user to the docker group
sudo usermod -aG docker $USER

# Install Docker Compose plugin
sudo apt install -y docker-compose-plugin

# Log out and back in for group changes to take effect
```

Verify installation:

```bash
docker --version
docker compose version
```

---

## Step 2: Clone the Repository

```bash
cd ~
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv
```

---

## Step 3: Run the Setup Script

The setup script will:
- Check prerequisites
- Create directory structure
- Configure environment files with generated secrets
- Validate your setup

```bash
./scripts/setup.sh
```

Follow the interactive prompts to configure your installation.

**What the script does:**
- ✅ Creates `/srv/orion-sentinel-core` with proper permissions
- ✅ Copies and configures all `.env` files
- ✅ Generates secure secrets for Authelia and other services
- ✅ Sets up your timezone, domain, and paths
- ✅ Validates everything is ready to go

---

## Step 4: Review Configuration

After the setup script completes, review your configuration files:

```bash
# Check core configuration
cat env/.env.core

# If using VPN for torrents, add your credentials
vim env/.env.media
# Set: OPENVPN_USER and OPENVPN_PASSWORD
```

**Important:** If you're using the Media stack, you **must** add your VPN credentials to `env/.env.media`.

---

## Step 5: Start Services

Start with the core services (Traefik + Authelia):

```bash
./orionctl.sh up-core
```

Check that services are running:

```bash
./orionctl.sh status
```

Access your services:
- **Authelia (SSO):** https://auth.local
- **Traefik (Dashboard):** https://traefik.local

---

## Next Steps

### Start Additional Services

**Start Media Stack (Jellyfin, Sonarr, Radarr, etc.):**
```bash
./orionctl.sh up-media
```

**Start Monitoring (Prometheus, Grafana, Loki):**
```bash
./orionctl.sh up-observability
```

**Start Everything:**
```bash
./orionctl.sh up-full
```

### Configure Services

1. **Set up Authelia users:**
   - Edit `core/authelia/users.yml` (see instructions in file)
   - Generate password hash: `docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'YourPassword'`
   - Restart Authelia: `./orionctl.sh restart authelia`

2. **Configure DNS (Optional but recommended):**
   - Add local DNS entries in Pi-hole or `/etc/hosts`:
     ```
     192.168.1.100  jellyfin.local
     192.168.1.100  auth.local
     192.168.1.100  grafana.local
     # ... etc
     ```

3. **Configure Media Services:**
   - Access each service and complete the initial setup wizard
   - Connect services together (Prowlarr → Sonarr/Radarr → qBittorrent)
   - See [media/README.md](media/README.md) for detailed configuration

### Useful Commands

```bash
# View service status
./orionctl.sh status

# View logs for a service
./orionctl.sh logs jellyfin

# Restart a service
./orionctl.sh restart traefik

# Check service health
./orionctl.sh health

# Stop all services
./orionctl.sh down

# View all available commands
./orionctl.sh help
```

---

## Troubleshooting

### Services not accessible

1. **Check if services are running:**
   ```bash
   ./orionctl.sh status
   ```

2. **Check Traefik logs:**
   ```bash
   ./orionctl.sh logs traefik
   ```

3. **Verify DNS resolution:**
   ```bash
   ping auth.local
   nslookup auth.local
   ```

4. **Check firewall:**
   ```bash
   sudo ufw status
   # Ensure ports 80 and 443 are allowed
   ```

### VPN not connecting

1. **Check Gluetun (VPN) logs:**
   ```bash
   ./orionctl.sh logs vpn
   ```

2. **Verify VPN credentials in env/.env.media**

3. **Test VPN connection:**
   ```bash
   docker compose exec vpn curl ifconfig.me
   ```

### Permission errors

1. **Check PUID/PGID in env files match your user:**
   ```bash
   id  # Should match PUID/PGID in env files
   ```

2. **Fix directory ownership:**
   ```bash
   sudo chown -R $USER:$USER /srv/orion-sentinel-core
   ```

### Need more help?

- **Full Setup Guide:** [docs/SETUP-CoreSrv.md](docs/SETUP-CoreSrv.md)
- **Runbooks:** [docs/RUNBOOKS.md](docs/RUNBOOKS.md)
- **Architecture:** [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md)
- **Security:** [docs/SECURITY-HARDENING.md](docs/SECURITY-HARDENING.md)
- **Issues:** https://github.com/orionsentinel/Orion-Sentinel-CoreSrv/issues

---

## Architecture Overview

```
Internet → Router → CoreSrv (This Installation)
                       ↓
            ┌──────────┴──────────┐
            │   Docker Networks   │
            ├─────────────────────┤
            │ orion_proxy         │ ← Traefik + Authelia
            │ orion_internal      │ ← Service communication
            │ orion_vpn           │ ← qBittorrent isolation
            │ orion_monitoring    │ ← Metrics & logs
            └─────────────────────┘
```

### Services Included

- **Core:** Traefik (reverse proxy) + Authelia (SSO with 2FA)
- **Media:** Jellyfin + Sonarr + Radarr + qBittorrent (VPN) + Jellyseerr + Prowlarr + Bazarr
- **Cloud:** Nextcloud + PostgreSQL
- **Monitoring:** Prometheus + Grafana + Loki + Promtail + Uptime Kuma
- **Search:** SearXNG (privacy-respecting metasearch)
- **Home Automation:** Home Assistant
- **Maintenance:** Homepage dashboard + Watchtower + Autoheal

---

## Directory Structure

After running the setup script, your directory structure will look like this:

```
/srv/orion-sentinel-core/
├── config/          # Service configurations
├── data/            # Service data
├── media/
│   ├── torrents/    # Download location
│   │   ├── movies/
│   │   └── tv/
│   └── library/     # Media library (hardlink destination)
│       ├── movies/
│       └── tv/
├── cloud/
│   ├── db/          # PostgreSQL data
│   ├── app/         # Nextcloud app
│   └── data/        # Nextcloud files
├── monitoring/
│   ├── prometheus/
│   ├── grafana/
│   └── loki/
└── backups/         # Backup destination
```

---

## Security Notes

### Zero-Trust Architecture

- All services are behind Traefik reverse proxy
- Authelia provides SSO with 2FA for all admin tools
- qBittorrent traffic is isolated in VPN network
- No services are exposed without authentication

### Secrets Management

- All secrets are stored in `.env.*` files (git-ignored)
- Setup script generates cryptographically secure secrets
- Store your `.env` files in a password manager as backup
- See [secrets/README.md](secrets/README.md) for details

### Best Practices

1. **Use strong passwords** for all services
2. **Enable 2FA** in Authelia for all users
3. **Keep services updated** with `./orionctl.sh pull`
4. **Regular backups** of configuration and data
5. **Monitor logs** for suspicious activity

---

## Profile Reference

Services are organized into Docker Compose profiles:

| Profile | Services | Description |
|---------|----------|-------------|
| `core` | Traefik, Authelia, Redis | **Required** - Reverse proxy + SSO |
| `media-core` | Jellyfin, Sonarr, Radarr, qBittorrent, VPN, Jellyseerr, Prowlarr, Bazarr | Media stack |
| `media-ai` | Recommendarr | AI-powered recommendations |
| `cloud` | Nextcloud, PostgreSQL | Personal cloud storage |
| `search` | SearXNG | Privacy-respecting search |
| `monitoring` | Prometheus, Grafana, Loki, Promtail, Uptime Kuma | Observability |
| `home-automation` | Home Assistant | Smart home control |
| `maintenance` | Homepage, Watchtower, Autoheal | Dashboard & automation |

Start specific combinations:

```bash
# Just core and media
./orionctl.sh up-media

# Core and monitoring
./orionctl.sh up-observability

# Everything
./orionctl.sh up-full
```

---

**Ready to get started?** Run `./scripts/setup.sh` and you'll be up and running in minutes!

For production deployment, see [docs/DEPLOYMENT-CHECKLIST.md](docs/DEPLOYMENT-CHECKLIST.md).

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
