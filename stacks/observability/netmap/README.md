# NetAlertX - Network Device Discovery & IP Inventory

## Overview

NetAlertX (formerly Pi.Alert) is a network scanner and device inventory tool that helps you monitor and track all devices on your local network. It provides real-time notifications when new devices join your network and maintains a comprehensive inventory of all discovered devices.

**Features:**
- Automatic network device discovery
- Real-time alerts for new devices
- Device MAC address tracking with vendor identification
- IP address history and changes
- Custom device naming and grouping
- Network topology visualization
- Notification support (email, webhooks, etc.)

## Quick Start

### 1. Configure Network Subnet (Optional)

NetAlertX can auto-detect your network, but you can specify a subnet for more control:

```bash
cd stacks/observability/netmap
cp .env.example .env
nano .env  # Set NETALERTX_SCAN_SUBNET if needed
```

**Examples:**
- Home network: `NETALERTX_SCAN_SUBNET=192.168.1.0/24`
- Office network: `NETALERTX_SCAN_SUBNET=10.0.0.0/24`
- Leave empty for auto-detection

### 2. Start NetAlertX

```bash
# From repository root
./scripts/orionctl up observability --profile net_map

# Or using Docker Compose directly
docker compose --profile net_map up -d
```

### 3. Initial Setup

1. Navigate to **https://netmap.orion.lan**
2. Complete first-time setup wizard:
   - Confirm network subnet
   - Set scan interval (default: 5 minutes)
   - Configure notification preferences
3. Wait for first scan to complete (1-2 minutes)
4. View discovered devices in the dashboard

**Access:** https://netmap.orion.lan

## How It Works

### Network Scanning

NetAlertX uses multiple methods to discover devices:

1. **ARP Scanning** - Discovers devices via ARP requests (layer 2)
2. **Ping Scanning** - ICMP echo requests to find active hosts
3. **DHCP Monitoring** - Tracks DHCP leases if accessible
4. **Network Capture** - Passive monitoring of network traffic

**Scan Interval:** Configurable (default 5 minutes)  
**Network Mode:** Host networking (required for direct network access)  
**Capabilities:** NET_ADMIN and NET_RAW (for network scanning)

### Device Detection

When a device is discovered, NetAlertX records:
- **MAC Address** - Hardware identifier
- **IP Address** - Current and historical IPs
- **Hostname** - Device name if available
- **Vendor** - Manufacturer from MAC OUI database
- **First Seen** - When device was first detected
- **Last Seen** - Most recent detection timestamp
- **Status** - Online/Offline/Away

## Configuration

### Basic Settings

Configure scan behavior in the web UI:

1. Go to **Settings → Scan**
2. Adjust:
   - **Scan Interval** - How often to scan (default: 5 min)
   - **Scan Method** - ARP, Ping, or both
   - **Subnet** - Network range to scan
   - **Timeout** - How long to wait for responses

### Device Management

**Naming Devices:**
1. Click on a device in the list
2. Click **Edit**
3. Set **Name** and **Icon**
4. Add to a **Group** if desired
5. Save changes

**Device Groups:**
- Family Devices
- IoT Devices
- Servers & Infrastructure
- Guest Devices
- Security Cameras
- Smart Home

**Ignoring Devices:**
- Mark devices as "Always Ignore" to hide them from alerts
- Useful for known transient devices

### Notifications

NetAlertX can alert you when new devices join the network:

**Notification Methods:**
1. **Email** - SMTP configuration
2. **Webhooks** - HTTP POST to custom endpoint
3. **Apprise** - Unified notification library (supports 70+ services)
4. **MQTT** - Publish to MQTT broker (integrate with Home Assistant)

**Configure Notifications:**
1. Settings → Notifications
2. Choose notification method
3. Configure credentials/endpoints
4. Set which events trigger notifications:
   - New device detected
   - Device comes online
   - Device goes offline
   - IP address changed

### Alert Types

Configure which events generate alerts:

- **New Device** - Previously unseen device joins network
- **Device Down** - Known device hasn't been seen for X scans
- **Device Up** - Known device comes back online
- **IP Change** - Device changes IP address
- **MAC Change** - Rare, but can indicate spoofing

## Use Cases

### 1. Network Security

**Monitor for unauthorized devices:**
- Get notified when unknown devices connect
- Track when devices join/leave the network
- Identify suspicious MAC addresses or vendors
- Detect MAC spoofing attempts

**Example:** Alert on any new device that isn't a known phone or laptop.

### 2. Device Inventory

**Maintain an accurate inventory:**
- Track all network-connected equipment
- Document IP assignments and reservations
- Identify device types and vendors
- Plan network expansions

**Example:** Generate monthly reports of all active devices.

### 3. IoT Device Management

**Monitor smart home devices:**
- Track when IoT devices go offline
- Identify firmware update requirements
- Detect unusual device behavior
- Ensure security cameras are online

**Example:** Alert if security camera hasn't been seen in 10 minutes.

### 4. Family Device Tracking

**Know when family members are home:**
- Track phones and tablets
- Integrate with home automation
- Presence detection for lighting/climate
- Parental monitoring

**Example:** Trigger "home" automation when family phones connect to WiFi.

### 5. Guest Network Monitoring

**Track guest devices:**
- See who's using guest WiFi
- Monitor bandwidth usage
- Time-limit guest access
- Identify repeat visitors

**Example:** Alert if same guest device connects more than 5 times.

## Integration with Home Assistant

NetAlertX can publish device presence to MQTT for Home Assistant integration:

### Setup MQTT Publishing

1. In NetAlertX: **Settings → Integrations → MQTT**
2. Configure:
   - **MQTT Broker:** `mosquitto` (container name) or IP
   - **Port:** `1883`
   - **Username/Password:** Your MQTT credentials
   - **Topic Prefix:** `netalertx/`
3. Enable "Publish presence updates"
4. Save and restart scan

### Home Assistant Configuration

Add to Home Assistant `configuration.yaml`:

```yaml
# NetAlertX Device Tracking
device_tracker:
  - platform: mqtt
    devices:
      john_phone: "netalertx/device/AA:BB:CC:DD:EE:FF"
      jane_phone: "netalertx/device/11:22:33:44:55:66"
```

Or use MQTT Discovery for automatic setup.

### Automations

**Example: Welcome home automation**

```yaml
automation:
  - alias: "Welcome Home"
    trigger:
      - platform: state
        entity_id: device_tracker.john_phone
        to: 'home'
    action:
      - service: light.turn_on
        target:
          entity_id: light.living_room
      - service: climate.set_temperature
        target:
          entity_id: climate.thermostat
        data:
          temperature: 22
```

## Troubleshooting

### No Devices Detected

**Possible causes:**

1. **Wrong subnet configured**
   ```bash
   # Check your actual network
   ip addr show
   # Update NETALERTX_SCAN_SUBNET if needed
   ```

2. **Firewall blocking scans**
   - Check host firewall rules
   - Ensure ARP and ICMP aren't blocked
   - Verify container has NET_ADMIN capability

3. **Network isolation**
   - NetAlertX runs in host network mode
   - Ensure it's on the same network as devices
   - Check if router has client isolation enabled

### Devices Show as Offline

**Check scan results:**
```bash
docker logs orion_netalertx | grep -i scan
```

**Common issues:**
- Scan interval too long (increase frequency)
- Devices don't respond to ping (normal for some devices)
- Network congestion during scan
- ARP table size limits

### Cannot Access Web Interface

```bash
# Check NetAlertX is running
docker ps | grep netalertx

# Check proxy is running
docker ps | grep netmap-proxy

# Check logs
docker logs orion_netalertx
docker logs orion_netmap_proxy

# Verify Traefik routing
docker logs orion_traefik | grep netmap
```

### High CPU Usage

**Reduce scan frequency:**

Edit `.env`:
```bash
NETALERTX_SCAN_INTERVAL=15  # Increase to 15 minutes
```

Restart:
```bash
docker compose --profile net_map restart netalertx
```

### MAC Vendor Not Showing

Update the OUI database:

1. Settings → Database → Update OUI Database
2. Click "Update Now"
3. Wait for download to complete

## Performance Considerations

### Scan Frequency

**Trade-offs:**
- **Every 1-2 minutes:** Real-time detection, higher CPU usage
- **Every 5 minutes:** Good balance (recommended)
- **Every 15-30 minutes:** Lower overhead, delayed detection

### Network Size

**Recommended settings by network size:**

| Network Size | Scan Interval | Expected Scan Time |
|--------------|---------------|-------------------|
| < 50 devices | 5 minutes     | < 30 seconds      |
| 50-100 devices | 10 minutes  | < 1 minute        |
| 100-200 devices | 15 minutes | 1-2 minutes       |
| > 200 devices | 30 minutes    | 2-5 minutes       |

### Resource Usage

**Typical resource usage:**
- **CPU:** < 5% average, spikes during scans
- **Memory:** 200-500 MB depending on device count
- **Disk:** 50-200 MB for database
- **Network:** Minimal (ARP/ICMP packets)

## Data Management

### Database Location

NetAlertX stores data in SQLite:
```
/srv/orion/internal/appdata/netalertx/db/app.db
```

### Backup

```bash
# Backup database
sudo cp /srv/orion/internal/appdata/netalertx/db/app.db \
  netalertx-backup-$(date +%Y%m%d).db

# Backup entire config
sudo tar -czf netalertx-backup-$(date +%Y%m%d).tar.gz \
  /srv/orion/internal/appdata/netalertx/
```

### Restore

```bash
# Stop NetAlertX
docker compose --profile net_map down

# Restore database
sudo cp netalertx-backup.db \
  /srv/orion/internal/appdata/netalertx/db/app.db

# Restart
docker compose --profile net_map up -d
```

### Cleanup Old Data

Prune old device records:
1. Settings → Database → Cleanup
2. Set retention period (e.g., 90 days)
3. Click "Cleanup Now"

## Security Considerations

### Network Access

NetAlertX requires:
- **Host networking** - Direct network interface access
- **NET_ADMIN** - Network administration capabilities
- **NET_RAW** - Raw packet capture

**Security measures:**
- Read-only filesystem (except /tmp)
- No-new-privileges security option
- Minimal exposed ports
- Regular security updates

### Privacy

**What NetAlertX collects:**
- MAC addresses and vendors
- IP addresses and hostnames
- Device online/offline times
- Network traffic metadata

**Does NOT collect:**
- Actual network traffic content
- Browsing history
- Personal data
- Passwords

**Data stays local** - No cloud uploads, all data stored on your server.

### Authentication

Consider adding authentication via Traefik middleware for additional security on the web interface.

## Resources

- **Official GitHub:** https://github.com/jokob-sk/NetAlertX
- **Documentation:** https://github.com/jokob-sk/NetAlertX/tree/main/docs
- **Docker Image:** https://hub.docker.com/r/jokobsk/netalertx
- **Community Forum:** GitHub Discussions

---

**Stack Profile:** `net_map`  
**URL:** https://netmap.orion.lan  
**Data Location:** `/srv/orion/internal/appdata/netalertx/`  
**Maintained by:** Orion Home Lab Team
