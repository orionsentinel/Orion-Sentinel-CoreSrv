# Orion-Sentinel-HomeCore Installation Guide

Complete step-by-step installation guide for Raspberry Pi 5.

## Prerequisites

### Hardware
- Raspberry Pi 5 (4GB RAM minimum, 8GB recommended)
- **SSD required** (USB 3.0 connected, 64GB minimum)
  - DO NOT use microSD for database storage
  - MicroSD can be used for OS only
- Power supply (official Pi 5 power adapter recommended)
- Ethernet cable (recommended for stability)

### Optional Hardware
- Zigbee USB coordinator (Sonoff Zigbee 3.0, ConBee II, etc.)
- Z-Wave USB stick (if using Z-Wave devices)

### Software
- Raspberry Pi OS (64-bit, Bookworm or newer recommended)
- Docker Engine 24.0+
- Docker Compose 2.20+

## Step 1: Prepare Raspberry Pi

### 1.1 Install Raspberry Pi OS

Use Raspberry Pi Imager to flash Raspberry Pi OS (64-bit) to your microSD card.

**Recommended settings in Imager:**
- Enable SSH
- Set username and password
- Configure WiFi (if not using Ethernet)
- Set hostname (e.g., `homecore`)

### 1.2 Boot and Update

```bash
# SSH into your Pi
ssh pi@homecore.local

# Update system
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y git curl vim
```

### 1.3 Mount SSD (Critical!)

**Important:** Do not skip this step. Databases must run on SSD.

```bash
# Find your SSD device
lsblk

# Example output:
# sda           8:0    0 119.2G  0 disk
# └─sda1        8:1    0 119.2G  0 part

# Format SSD (WARNING: This erases all data!)
sudo mkfs.ext4 /dev/sda1

# Create mount point
sudo mkdir -p /srv/homecore

# Get UUID
sudo blkid /dev/sda1
# Example output: UUID="abc-123-def"

# Add to /etc/fstab for automatic mounting
echo "UUID=abc-123-def /srv/homecore ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# Mount
sudo mount -a

# Verify
df -h /srv/homecore

# Set ownership
sudo chown -R $USER:$USER /srv/homecore
```

## Step 2: Install Docker

```bash
# Install Docker (official method)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in for group change to take effect
exit
# Then SSH back in

# Verify Docker installation
docker --version
docker compose version
```

## Step 3: Clone and Setup HomeCore

### 3.1 Clone Repository

```bash
# Clone the repository
cd ~
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv/Orion-Sentinel-HomeCore
```

### 3.2 Run Setup Script

The setup script is idempotent and safe to run multiple times.

```bash
# Run setup
./scripts/setup.sh

# What it does:
# ✓ Creates directory structure under /srv/homecore
# ✓ Generates secure random secrets
# ✓ Creates env/.env.example with defaults
# ✓ Creates Docker network
# ✓ Sets up basic Mosquitto and Zigbee2MQTT configs
```

### 3.3 Configure Environment

```bash
# Copy example env to .env
cp env/.env.example .env

# Edit configuration
nano .env
```

**Key settings to review:**

```bash
# Timezone (change to yours)
TZ=Europe/Amsterdam

# Data root (should match your SSD mount)
DATA_ROOT=/srv/homecore

# Zigbee USB device (if using Zigbee)
# Find with: ls -l /dev/serial/by-id/
ZIGBEE_DEVICE=/dev/serial/by-id/usb-Silicon_Labs_Sonoff_Zigbee_3.0_USB_Dongle_Plus_0001-if00-port0

# Mealie database password (auto-generated, can change)
MEALIE_DB_PASSWORD=<generated-password>

# Home Assistant external URL (optional, for mobile app)
HA_EXTERNAL_URL=http://homecore.local:8123
```

## Step 4: Start Services

### 4.1 Basic Home Assistant

```bash
# Start Home Assistant only
./scripts/orionctl.sh up

# Check status
./scripts/orionctl.sh ps

# View logs
./scripts/orionctl.sh logs homeassistant
```

**Access Home Assistant:**
- Open browser: `http://<PI_IP>:8123`
- Or: `http://homecore.local:8123`

### 4.2 Enable MQTT (Optional)

```bash
# Stop services
./scripts/orionctl.sh down

# Start with MQTT
./scripts/orionctl.sh up mqtt

# Verify Mosquitto is running
./scripts/orionctl.sh ps
```

### 4.3 Enable Zigbee (Optional)

**Prerequisites:**
- Zigbee USB coordinator plugged in
- `ZIGBEE_DEVICE` set correctly in `.env`

```bash
# Stop services
./scripts/orionctl.sh down

# Start with MQTT and Zigbee
./scripts/orionctl.sh up mqtt zigbee

# Check Zigbee2MQTT logs
./scripts/orionctl.sh logs zigbee2mqtt
```

**Configure Zigbee2MQTT:**

Edit the configuration file:
```bash
sudo nano /srv/homecore/zigbee2mqtt/configuration.yaml
```

Key settings:
```yaml
permit_join: true  # Enable pairing (set to false when done)
mqtt:
  server: mqtt://mosquitto:1883
homeassistant: true
```

### 4.4 Enable Mealie (Optional)

```bash
# Stop services
./scripts/orionctl.sh down

# Start with Mealie
./scripts/orionctl.sh up mealie

# Check Mealie logs
./scripts/orionctl.sh logs mealie
```

**Access Mealie:**
- Open browser: `http://<PI_IP>:9000`
- Create admin account on first visit

## Step 5: Home Assistant Configuration

### 5.1 Initial Setup

1. Open Home Assistant: `http://<PI_IP>:8123`
2. Create admin account
3. Set location and timezone
4. Skip integrations for now (we'll add them next)

### 5.2 Add MQTT Integration (if enabled)

1. Go to Settings → Devices & Services
2. Click "Add Integration"
3. Search for "MQTT"
4. Configure:
   - Broker: `mosquitto`
   - Port: `1883`
   - Username: (leave blank for now)
   - Password: (leave blank for now)

### 5.3 Add Zigbee2MQTT Integration (if enabled)

Zigbee2MQTT automatically publishes devices to Home Assistant via MQTT. No manual integration needed!

**To pair Zigbee devices:**
1. Open Zigbee2MQTT: `http://<PI_IP>:8080`
2. Click "Permit join (All)" to enable pairing mode
3. Put your Zigbee device in pairing mode (check device manual)
4. Device should appear in Zigbee2MQTT and Home Assistant

### 5.4 Configure Mobile App (Optional)

1. Install Home Assistant app on iOS/Android
2. Add server with URL: `http://<PI_IP>:8123`
3. Log in with your admin credentials

## Step 6: Verify Installation

```bash
# Check all running services
./scripts/orionctl.sh ps

# Validate configuration
./scripts/orionctl.sh validate

# Check logs for errors
./scripts/orionctl.sh logs
```

**Expected output from `ps`:**
```
NAME                        STATUS    PORTS
orion_homecore_homeassistant  Up      0.0.0.0:8123->8123/tcp
orion_homecore_mosquitto      Up      0.0.0.0:1883->1883/tcp (if mqtt profile)
orion_homecore_zigbee2mqtt    Up      0.0.0.0:8080->8080/tcp (if zigbee profile)
orion_homecore_mealie         Up      0.0.0.0:9000->9000/tcp (if mealie profile)
orion_homecore_mealie_db      Up                              (if mealie profile)
```

## Step 7: Backup Configuration

After initial setup, back up your configuration:

```bash
# Create backup directory
mkdir -p ~/homecore-backups

# Backup Home Assistant config
sudo tar -czf ~/homecore-backups/homeassistant-$(date +%Y%m%d).tar.gz \
  /srv/homecore/homeassistant

# Backup Zigbee2MQTT database
sudo tar -czf ~/homecore-backups/zigbee2mqtt-$(date +%Y%m%d).tar.gz \
  /srv/homecore/zigbee2mqtt

# Copy backups off-site or to cloud storage
```

## Troubleshooting

### Home Assistant not accessible

```bash
# Check if container is running
./scripts/orionctl.sh ps

# Check logs for errors
./scripts/orionctl.sh logs homeassistant

# Check if port is listening
sudo netstat -tlnp | grep 8123

# Try restarting
./scripts/orionctl.sh restart
```

### Zigbee2MQTT can't find USB device

```bash
# List all USB devices
ls -l /dev/serial/by-id/

# Check if device is accessible
ls -l /dev/ttyACM0

# Update .env with correct device path
nano .env

# Restart services
./scripts/orionctl.sh down
./scripts/orionctl.sh up mqtt zigbee
```

### Mealie database errors

```bash
# Check database health
docker exec orion_homecore_mealie_db pg_isready -U mealie

# Check database logs
./scripts/orionctl.sh logs mealie-db

# If database is corrupted, restore from backup or recreate:
./scripts/orionctl.sh down
sudo rm -rf /srv/homecore/mealie/postgres
./scripts/orionctl.sh up mealie
```

### SSD not mounting on boot

```bash
# Check /etc/fstab entry
cat /etc/fstab | grep homecore

# Check UUID matches
sudo blkid /dev/sda1

# Manual mount
sudo mount -a

# Check mount
df -h /srv/homecore
```

### Out of disk space

```bash
# Check disk usage
df -h /srv/homecore

# Check Docker disk usage
docker system df

# Clean up old images
docker system prune -a

# If using microSD: MIGRATE TO SSD IMMEDIATELY!
```

## Maintenance

### Update Docker Images

```bash
# Pull latest images
./scripts/orionctl.sh pull

# Restart with new images
./scripts/orionctl.sh down
./scripts/orionctl.sh up [profiles...]
```

### Update Home Assistant

Home Assistant updates are managed through its UI:
1. Go to Settings → System → Updates
2. Review available updates
3. Click "Update" button
4. Wait for update to complete (container will restart automatically)

### Regular Backups

Set up automated backups with cron:

```bash
# Edit crontab
crontab -e

# Add daily backup at 3 AM
0 3 * * * cd /srv/homecore && tar -czf ~/homecore-backups/homecore-$(date +\%Y\%m\%d).tar.gz homeassistant zigbee2mqtt mosquitto mealie
```

## Next Steps

1. **Add Integrations** - Explore Home Assistant integrations for your devices
2. **Create Automations** - Set up automations in Home Assistant
3. **Add Dashboards** - Customize Home Assistant dashboards
4. **Enable Node-RED** (optional) - For visual automation flows
5. **Add Recipes to Mealie** (optional) - Start importing your favorite recipes

## Remote Access (Optional)

For secure remote access, consider:

1. **VPN (Recommended):**
   - Set up WireGuard or Tailscale on your network
   - Access HomeCore through VPN tunnel

2. **Home Assistant Cloud (Nabu Casa):**
   - Paid service ($6.50/month)
   - Easiest remote access option
   - Supports Alexa/Google Assistant

3. **Reverse Proxy (Advanced):**
   - Not included in HomeCore (intentionally kept simple)
   - Consider Cloudflare Tunnel or Nginx Proxy Manager
   - Requires domain name and SSL certificates

## Support

For issues or questions:
- GitHub Issues: https://github.com/orionsentinel/Orion-Sentinel-CoreSrv/issues
- Home Assistant Community: https://community.home-assistant.io/

---

**Installation complete!** Enjoy your smart home! 🏠
