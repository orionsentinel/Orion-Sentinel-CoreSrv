# Home Automation Suite

## Overview

Complete home automation stack integrating smart home control, IoT devices, energy monitoring, and meal planning.

## Services

### Core Services

1. **Home Assistant** - Smart home automation hub
   - 2000+ integrations for devices and services
   - Automation engine with visual and YAML editors
   - Beautiful dashboards (Lovelace UI)
   - Mobile apps (iOS/Android)
   - Voice assistant integration
   - **Access**: `https://ha.local`

2. **Mosquitto** - MQTT broker for IoT devices
   - Lightweight message broker
   - WebSocket support
   - Authentication and ACL support
   - **Ports**: 1883 (MQTT), 9001 (WebSocket)

3. **Zigbee2MQTT** - Zigbee to MQTT bridge
   - Control Zigbee devices locally
   - Web-based device management
   - Auto-discovery in Home Assistant
   - **Access**: `https://zigbee.local`
   - **Requires**: Zigbee USB coordinator

4. **Mealie** - Recipe management and meal planning
   - Import recipes from URLs
   - Meal planning calendar
   - Auto-generated shopping lists
   - Multi-user support
   - **Access**: `https://mealie.local`

5. **DSMR Reader** - Dutch smart meter data logger
   - Real-time energy consumption
   - Historical data and analytics
   - Cost tracking
   - Home Assistant integration
   - **Access**: `https://energy.local`
   - **Requires**: P1 USB cable (Dutch smart meters only)

## Directory Structure

```
home-automation/
├── README.md                           # This file
├── homeassistant/                      # Home Assistant docs
│   └── .gitkeep
├── mosquitto/                          # Mosquitto MQTT broker
│   └── mosquitto.conf.example         # Example config
├── zigbee2mqtt/                        # Zigbee2MQTT gateway
│   └── configuration.yaml.example     # Example config
├── mealie/                            # Mealie recipe manager
│   └── README.md
└── dsmr/                              # DSMR Reader
    └── README.md
```

**Runtime Configuration**: All service configs are created at:
`/srv/orion-sentinel-core/config/<service>/`

## Hardware Requirements

### Required for Basic Setup

- **None!** Home Assistant, Mosquitto, and Mealie work without additional hardware.

### Optional Hardware

1. **Zigbee USB Coordinator** (for Zigbee2MQTT)
   - **Recommended**: Sonoff Zigbee 3.0 USB Dongle Plus (~€20)
   - **Alternatives**: ConBee II, CC2531, CC2652
   - **Purpose**: Control Zigbee smart devices (lights, sensors, switches)
   - **Skip if**: Using WiFi/cloud devices or Home Assistant ZHA instead

2. **P1 USB Cable** (for DSMR Reader - Dutch meters only)
   - **Type**: USB to RJ12 P1 cable (~€15)
   - **Purpose**: Read Dutch smart meter data
   - **Skip if**: Not in Netherlands or no DSMR meter

## Quick Start

### 1. Configure Environment

```bash
# Copy environment file
cp env/.env.home-automation.example env/.env.home-automation

# Edit configuration
vim env/.env.home-automation
```

**Essential settings**:
- `TZ=Europe/Amsterdam` (your timezone)
- `CONFIG_ROOT=/srv/orion-sentinel-core/config`
- `ZIGBEE_DEVICE=/dev/ttyACM0` (if using Zigbee)
- `DSMR_SERIAL_PORT=/dev/ttyUSB0` (if using DSMR Reader)

### 2. Create Configuration Files

Copy example configs to runtime directories:

```bash
# Create config directories
sudo mkdir -p /srv/orion-sentinel-core/config/{homeassistant,mosquitto/config,zigbee2mqtt/data,mealie,dsmr}

# Copy Mosquitto config
sudo cp home-automation/mosquitto/mosquitto.conf.example \
  /srv/orion-sentinel-core/config/mosquitto/config/mosquitto.conf

# Copy Zigbee2MQTT config (if using Zigbee)
sudo cp home-automation/zigbee2mqtt/configuration.yaml.example \
  /srv/orion-sentinel-core/config/zigbee2mqtt/data/configuration.yaml

# Set permissions
sudo chown -R $USER:$USER /srv/orion-sentinel-core/config
```

### 3. Start Services

```bash
# Start all home automation services
docker compose --profile home-automation up -d

# Or start selectively
docker compose up -d homeassistant mosquitto mealie

# Check status
docker compose ps
```

### 4. Access Services

All services are accessible via HTTPS through Traefik:

| Service | URL | Default Credentials |
|---------|-----|-------------------|
| Home Assistant | https://ha.local | (set on first visit) |
| Zigbee2MQTT | https://zigbee.local | (no auth by default) |
| Mealie | https://mealie.local | admin@local / changeme |
| DSMR Reader | https://energy.local | admin / admin |
| Homepage | https://home.local | (dashboard) |

**Note**: Add these to `/etc/hosts` or configure local DNS if using `.local` domains.

## Initial Setup

### Home Assistant

1. Navigate to `https://ha.local`
2. Complete onboarding wizard:
   - Create admin account
   - Set location (for weather, sunrise/sunset)
   - Set timezone and units
   - Allow device discovery

3. Install HACS (Home Assistant Community Store):
   ```bash
   docker compose exec homeassistant bash
   wget -O - https://get.hacs.xyz | bash -
   exit
   docker compose restart homeassistant
   ```

4. Add MQTT integration:
   - Settings → Devices & Services → Add Integration
   - Search for "MQTT"
   - Broker: `mosquitto`, Port: `1883`
   - Leave credentials empty (or use MQTT_USER/MQTT_PASSWORD from .env)

### Zigbee2MQTT (if using)

1. Navigate to `https://zigbee.local`
2. Click "Permit join (All)"
3. Put Zigbee devices in pairing mode
4. Devices appear in UI and auto-discover in Home Assistant
5. Rename devices with friendly names

### Mealie

1. Navigate to `https://mealie.local`
2. Log in with `admin@local` / `changeme`
3. Change password immediately
4. Create your household
5. Import your first recipe (try pasting a recipe URL!)

### DSMR Reader (if using)

1. Connect P1 cable to smart meter and server
2. Navigate to `https://energy.local`
3. Log in with `admin` / `admin`
4. Change password immediately
5. Verify serial port settings
6. Wait for data to start flowing (~5 minutes)

## Integration with Monitoring Stack

### Prometheus (Metrics)

Home Assistant metrics are available via the Prometheus integration:

1. In Home Assistant: Settings → Devices & Services → Add Integration → Prometheus
2. Metrics exposed at: `http://homeassistant:8123/api/prometheus`
3. Already configured in `monitoring/prometheus/prometheus.yml`
4. View in Grafana: `https://grafana.local`

### Loki (Logs)

All container logs are automatically collected by Promtail:

- Configured in `monitoring/promtail/config.yml`
- View in Grafana → Explore → Loki
- Filter by: `{container_name="homeassistant"}` or `{stack="home"}`

### Uptime Kuma (Status)

Add monitors in Uptime Kuma (`https://status.local`):

1. Add HTTP(s) monitor for each service
2. Monitor URLs:
   - `https://ha.local`
   - `https://zigbee.local`
   - `https://mealie.local`
   - `https://energy.local`
3. Set check interval (60-300 seconds)
4. Configure notifications (optional)

### Grafana Dashboards

Create dashboards for:

- **Home Assistant**: Automation counts, entity states, integration status
- **Energy (DSMR)**: Real-time usage, daily/monthly consumption, costs
- **MQTT**: Message rates, connected clients
- **Zigbee**: Device count, link quality, battery levels

## Common Automations

### Example 1: Welcome Home

```yaml
# In Home Assistant: automations.yaml
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
      - service: notify.mobile_app
        data:
          message: "Welcome home!"
```

### Example 2: Energy Alert

```yaml
# Alert on high energy usage
automation:
  - alias: "High Energy Usage Alert"
    trigger:
      - platform: numeric_state
        entity_id: sensor.dsmr_power_consumption
        above: 3000  # Watts
        for: "00:05:00"
    action:
      - service: notify.all_devices
        data:
          message: "High energy usage detected: {{ states('sensor.dsmr_power_consumption') }}W"
```

### Example 3: Meal Plan Reminder

```yaml
# Reminder to check meal plan
automation:
  - alias: "Meal Plan Reminder"
    trigger:
      - platform: time
        at: "10:00:00"
    condition:
      - condition: time
        weekday:
          - sun
    action:
      - service: notify.mobile_app
        data:
          message: "Don't forget to plan meals for the week!"
          data:
            url: "https://mealie.local"
```

## Backup Strategy

### Critical Directories

```bash
# Home Assistant (config, automations, integrations)
/srv/orion-sentinel-core/config/homeassistant/

# Mosquitto (broker config, persistence)
/srv/orion-sentinel-core/config/mosquitto/

# Zigbee2MQTT (device database, network config)
/srv/orion-sentinel-core/config/zigbee2mqtt/

# Mealie (recipes, meal plans)
/srv/orion-sentinel-core/config/mealie/

# DSMR Reader (energy data)
/srv/orion-sentinel-core/config/dsmr/
```

### Backup Commands

```bash
# Automated backup script (add to cron)
sudo tar -czf ~/backups/home-automation-$(date +%Y%m%d).tar.gz \
  /srv/orion-sentinel-core/config/homeassistant \
  /srv/orion-sentinel-core/config/mosquitto \
  /srv/orion-sentinel-core/config/zigbee2mqtt \
  /srv/orion-sentinel-core/config/mealie \
  /srv/orion-sentinel-core/config/dsmr

# Home Assistant built-in backup
# Settings → System → Backups → Create Backup
```

## Troubleshooting

### Home Assistant Won't Start

```bash
# Check logs
docker compose logs homeassistant

# Check config
docker compose exec homeassistant bash
cd /config
hass --script check_config

# Restart
docker compose restart homeassistant
```

### Zigbee2MQTT No Devices

```bash
# Check coordinator connection
ls -l /dev/ttyACM*

# Check logs
docker compose logs zigbee2mqtt

# Verify config
cat /srv/orion-sentinel-core/config/zigbee2mqtt/data/configuration.yaml

# Try different USB port
# Update ZIGBEE_DEVICE in .env.home-automation
```

### MQTT Connection Issues

```bash
# Test MQTT broker
docker compose exec mosquitto mosquitto_sub -h localhost -t '#' -v

# Publish test message
docker compose exec mosquitto mosquitto_pub -h localhost -t test -m "hello"

# Check broker logs
docker compose logs mosquitto
```

### DSMR No Data

```bash
# Check serial port
ls -l /dev/ttyUSB*

# Check DSMR logs
docker compose logs dsmr

# Verify cable connection to meter P1 port
# Some meters require P1 port activation (contact energy provider)
```

## Advanced Configuration

### MQTT Authentication

Enable authentication for production use:

1. Edit `/srv/orion-sentinel-core/config/mosquitto/config/mosquitto.conf`:
   ```conf
   allow_anonymous false
   password_file /mosquitto/config/passwordfile
   ```

2. Create password file:
   ```bash
   docker compose exec mosquitto mosquitto_passwd -c /mosquitto/config/passwordfile admin
   ```

3. Update `.env.home-automation`:
   ```bash
   MQTT_USER=admin
   MQTT_PASSWORD=your_secure_password
   ```

4. Restart Mosquitto:
   ```bash
   docker compose restart mosquitto
   ```

5. Update Home Assistant MQTT integration with credentials

### Home Assistant + Energy Dashboard

1. Settings → Dashboards → Energy
2. Add Electricity Grid Consumption:
   - Use DSMR sensors: `sensor.dsmr_power_consumption`
3. Add Gas Consumption:
   - Use: `sensor.dsmr_gas_consumption`
4. Set costs (from DSMR Reader or manual)
5. View energy insights and trends

### Custom Zigbee Network Key

For security, use a custom network key:

1. Generate key: `openssl rand -hex 16`
2. Edit `/srv/orion-sentinel-core/config/zigbee2mqtt/data/configuration.yaml`:
   ```yaml
   advanced:
     network_key: [0x01, 0x03, 0x05, ...]  # Your 16-byte key
   ```
3. Restart Zigbee2MQTT
4. Re-pair all devices

**Warning**: Changing network key requires re-pairing ALL devices!

## Performance Tips

1. **Database Optimization** (Home Assistant):
   ```yaml
   # configuration.yaml
   recorder:
     purge_keep_days: 7
     commit_interval: 30
     exclude:
       domains:
         - automation
         - updater
       entity_globs:
         - sensor.weather_*
   ```

2. **Reduce Log Verbosity**:
   - Mosquitto: `log_type error` and `log_type warning` only
   - Zigbee2MQTT: `log_level: warn`
   - Home Assistant: Default logger level

3. **Monitor Resource Usage**:
   ```bash
   docker stats homeassistant mosquitto zigbee2mqtt mealie dsmr
   ```

## Resources

### Official Documentation

- **Home Assistant**: https://www.home-assistant.io/docs/
- **Mosquitto**: https://mosquitto.org/documentation/
- **Zigbee2MQTT**: https://www.zigbee2mqtt.io/
- **Mealie**: https://docs.mealie.io/
- **DSMR Reader**: https://dsmr-reader.readthedocs.io/

### Community

- **Home Assistant Community**: https://community.home-assistant.io/
- **Home Assistant Discord**: https://discord.gg/home-assistant
- **Zigbee2MQTT Discord**: https://discord.gg/dadfWTd
- **r/homeassistant**: https://reddit.com/r/homeassistant

### Mobile Apps

- **Home Assistant Companion**:
  - iOS: https://apps.apple.com/app/home-assistant/id1099568401
  - Android: https://play.google.com/store/apps/details?id=io.homeassistant.companion.android

## FAQ

**Q: Do I need all these services?**

A: No! Start with Home Assistant and Mosquitto. Add others as needed.

**Q: Can I use Home Assistant without Zigbee2MQTT?**

A: Yes! Use Home Assistant's built-in ZHA integration or WiFi/cloud devices.

**Q: Is DSMR Reader only for Netherlands?**

A: Yes, it's specific to Dutch smart meters with P1 port. Skip if not applicable.

**Q: Can I import my existing Home Assistant config?**

A: Yes! Copy your config files to `/srv/orion-sentinel-core/config/homeassistant/`

**Q: How do I update services?**

A: `docker compose pull && docker compose up -d` (or use Watchtower)

---

**Maintained By**: Orion Home Lab Team  
**Last Updated**: 2025-12-07
