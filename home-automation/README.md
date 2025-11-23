# Home Automation: Home Assistant

## Overview

Home Assistant is an open-source home automation platform that focuses on privacy and local control.

## What Lives Here

```
home-automation/
├── homeassistant/       # Home Assistant configuration
│   └── .gitkeep
└── README.md            # This file
```

**Note:** Home Assistant config files will be created at:
`/srv/orion-sentinel-core/config/homeassistant/`

## Service

### Home Assistant

**Purpose:** Smart home automation and integration hub

**Key Features:**
- 2000+ integrations (devices, services, platforms)
- Local control (works without internet)
- Automation builder (visual and YAML)
- Beautiful dashboards (Lovelace UI)
- Voice assistants (Alexa, Google Assistant integration)
- Mobile apps (iOS, Android) with notifications
- Energy monitoring
- Presence detection
- Media player control

**Access:**
- Web UI: `http://<coresrv-ip>:8123` (if using host networking)
- Or: `https://ha.local` (if using bridge networking with Traefik)

**Current Setup:**
- Network mode: `host` (recommended for device discovery)
- Direct access via host IP (bypasses Traefik initially)

## Network Modes

### Option 1: Host Networking (Current Default)

**Pros:**
- Automatic device discovery (mDNS, SSDP, etc.)
- Simplest setup for smart home devices
- No port mapping needed

**Cons:**
- Bypasses Docker networks
- Direct access to host network
- Cannot use Traefik reverse proxy

**Access:**
```
http://192.168.1.100:8123  # Replace with your CoreSrv IP
```

### Option 2: Bridge Networking with Traefik

**Pros:**
- Integrated with Traefik (https://ha.local)
- Authelia SSO protection
- Better network isolation

**Cons:**
- Device discovery may not work
- Requires manual configuration for some integrations
- More complex setup

**To Enable:**

In `compose.yml`, change `homeassistant` service:

```yaml
homeassistant:
  # Remove: network_mode: host
  networks:
    - orion_internal
    - orion_proxy
  labels:
    - "traefik.enable=true"
    - "traefik.http.routers.ha.rule=Host(`ha.local`)"
    - "traefik.http.routers.ha.entrypoints=websecure"
    - "traefik.http.routers.ha.tls=true"
    - "traefik.http.services.ha.loadbalancer.server.port=8123"
    # Optional: Protect with Authelia
    # - "traefik.http.routers.ha.middlewares=authelia@docker"
```

### Option 3: Macvlan (Advanced)

Give Home Assistant its own IP on your LAN:

```yaml
networks:
  macvlan:
    driver: macvlan
    driver_opts:
      parent: eth0  # Your network interface
    ipam:
      config:
        - subnet: 192.168.1.0/24
          gateway: 192.168.1.1
          ip_range: 192.168.1.240/28  # Use a small range

homeassistant:
  networks:
    macvlan:
      ipv4_address: 192.168.1.240
```

**Pros:**
- Full network functionality
- Device discovery works
- Separate IP on LAN

**Cons:**
- More complex setup
- Requires careful network configuration

## Initial Setup

### 1. Start Home Assistant

```bash
docker compose --profile home-automation up -d
```

### 2. Access Web UI

Navigate to:
- Host networking: `http://<coresrv-ip>:8123`
- Bridge networking: `https://ha.local`

### 3. Complete Onboarding

1. Create admin account
2. Set location (for weather, sunrise/sunset)
3. Set timezone and units
4. Allow/skip device discovery

### 4. Install HACS (Recommended)

**HACS** (Home Assistant Community Store) provides access to thousands of custom integrations and themes.

Install via terminal:

```bash
docker compose exec homeassistant bash
wget -O - https://get.hacs.xyz | bash -
exit

# Restart Home Assistant
docker compose restart homeassistant
```

Then in UI:
1. Settings → Devices & Services → Add Integration
2. Search for "HACS"
3. Follow authentication flow

## Popular Integrations

### Smart Home Devices

**Philips Hue:**
- Automatic discovery
- Full light control
- Scenes and groups

**Google Cast / Chromecast:**
- Media player control
- TTS (text-to-speech)

**Zigbee (via Zigbee2MQTT or ZHA):**
- Requires Zigbee USB stick
- Control Zigbee devices locally
- See below for setup

**MQTT:**
- Connect IoT devices
- See below for Mosquitto broker

### Media Integration

**Jellyfin:**
- Install Jellyfin integration
- Monitor playback, control players
- Recently added media

**Spotify:**
- Control playback
- Create playlists
- Music automations

**Plex/Emby:**
- Alternative to Jellyfin
- Same features

### Presence Detection

**Smartphone Apps:**
- Home Assistant Companion (iOS/Android)
- GPS tracking
- Battery monitoring
- Notifications

**Network Presence:**
- Device tracker (by MAC address)
- Router integration

**Bluetooth:**
- Bluetooth LE tracking
- Room presence

### Weather & Calendar

**Weather:**
- OpenWeatherMap
- Met.no
- AccuWeather

**Calendar:**
- Google Calendar
- Nextcloud Calendar
- Local calendar

### Monitoring & Utilities

**System Monitor:**
- CPU, RAM, disk usage
- Temperature sensors
- Network stats

**Uptime Kuma:**
- Monitor service status
- Display on dashboard

**Speedtest:**
- Internet speed monitoring
- Track ISP performance

## Automation Examples

### Example 1: Welcome Home

```yaml
automation:
  - alias: "Welcome Home"
    trigger:
      - platform: state
        entity_id: person.you
        to: 'home'
    action:
      - service: light.turn_on
        target:
          entity_id: light.living_room
      - service: climate.set_temperature
        target:
          entity_id: climate.living_room
        data:
          temperature: 21
      - service: notify.mobile_app
        data:
          message: "Welcome home!"
```

### Example 2: Media Notification

```yaml
automation:
  - alias: "New Media Available"
    trigger:
      - platform: state
        entity_id: sensor.jellyfin_latest_movie
    action:
      - service: notify.all_devices
        data:
          message: "New movie added: {{ states('sensor.jellyfin_latest_movie') }}"
```

### Example 3: Night Mode

```yaml
automation:
  - alias: "Night Mode"
    trigger:
      - platform: time
        at: "22:00:00"
    action:
      - service: light.turn_off
        target:
          entity_id: all
      - service: switch.turn_off
        target:
          entity_id: switch.tv
```

## Advanced Setup

### MQTT Broker (Mosquitto)

For IoT devices:

Add to `compose.yml`:

```yaml
mosquitto:
  image: eclipse-mosquitto:latest
  container_name: mosquitto
  volumes:
    - ${CONFIG_ROOT}/mosquitto:/mosquitto
  ports:
    - "1883:1883"
    - "9001:9001"
  networks:
    - orion_internal
  profiles:
    - home-automation
```

Configure in Home Assistant:
1. Settings → Devices & Services → Add Integration
2. MQTT → Manual configuration
3. Broker: `mosquitto`, Port: `1883`

### Zigbee2MQTT

For Zigbee devices (requires USB Zigbee stick):

Add to `compose.yml`:

```yaml
zigbee2mqtt:
  image: koenkk/zigbee2mqtt:latest
  container_name: zigbee2mqtt
  volumes:
    - ${CONFIG_ROOT}/zigbee2mqtt:/app/data
    - /run/udev:/run/udev:ro
  devices:
    - /dev/ttyUSB0:/dev/ttyUSB0  # Adjust to your Zigbee stick
  environment:
    - TZ=${TZ}
  ports:
    - "8080:8080"
  networks:
    - orion_internal
  profiles:
    - home-automation
```

## Mobile Apps

### Home Assistant Companion

**Download:**
- iOS: https://apps.apple.com/app/home-assistant/id1099568401
- Android: https://play.google.com/store/apps/details?id=io.homeassistant.companion.android

**Features:**
- Control dashboards
- GPS presence tracking
- Receive notifications
- Device sensors (battery, activity, etc.)
- Actionable notifications
- Widgets

**Setup:**
1. Install app
2. Enter Home Assistant URL
3. Login with credentials
4. Grant location permissions (for presence)

## Dashboard (Lovelace)

### Recommended Cards

**Custom Cards (via HACS):**
- **Mini Media Player** - Better media control
- **Button Card** - Customizable buttons
- **Mushroom Cards** - Modern card designs
- **Mini Graph Card** - Compact sensor graphs
- **Auto Entities** - Dynamic entity lists

### Dashboard Ideas

**Home Overview:**
- Weather
- Presence (who's home)
- Climate controls
- Quick actions (lights, scenes)

**Media Dashboard:**
- Jellyfin now playing
- Sonarr/Radarr upcoming
- Media player controls

**Monitoring Dashboard:**
- System resources (CPU, RAM, disk)
- Network stats
- Service status (from Uptime Kuma)

**Security Dashboard:**
- Cameras (if any)
- Door/window sensors
- Motion sensors
- Alarm status

## Backups

### Built-in Backups

Home Assistant has built-in backup system:

1. Settings → System → Backups
2. Create backup (full or partial)
3. Download to safe location

**Recommended:** Weekly full backups

### External Backup

Backup config directory:

```bash
sudo tar -czf ha-backup-$(date +%Y%m%d).tar.gz \
  /srv/orion-sentinel-core/config/homeassistant/
```

**Critical files:**
- `configuration.yaml`
- `automations.yaml`
- `scripts.yaml`
- `secrets.yaml`
- `.storage/` directory

## Troubleshooting

### Cannot Access Home Assistant

```bash
# Check container status
docker compose ps homeassistant

# Check logs
docker compose logs homeassistant

# If using host networking, verify port
netstat -tulpn | grep 8123
```

### Devices Not Discovered

```bash
# If using host networking, should work automatically
# If using bridge, may need manual configuration

# Check Home Assistant logs
docker compose logs homeassistant | grep -i discovery
```

### Integration Errors

```bash
# Check configuration
docker compose exec homeassistant bash
cd /config
hass --script check_config
```

### Performance Issues

```yaml
# In configuration.yaml, enable recorder database optimization
recorder:
  purge_keep_days: 7  # Keep 7 days of history
  db_url: sqlite:////config/home-assistant_v2.db
```

## TODO

- [ ] Complete initial Home Assistant setup
- [ ] Configure user account and timezone
- [ ] Install HACS (Home Assistant Community Store)
- [ ] Add core integrations (weather, system monitor)
- [ ] Set up mobile app with presence tracking
- [ ] Create basic automations (welcome home, night mode)
- [ ] Design Lovelace dashboard
- [ ] Consider MQTT broker for IoT devices
- [ ] Consider Zigbee2MQTT for Zigbee devices
- [ ] Set up automated backups
- [ ] Add Home Assistant to Homepage dashboard

## References

- Home Assistant: https://www.home-assistant.io/
- Documentation: https://www.home-assistant.io/docs/
- HACS: https://hacs.xyz/
- Community: https://community.home-assistant.io/
- Mobile Apps: https://companion.home-assistant.io/
- Automation Examples: https://www.home-assistant.io/examples/

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
