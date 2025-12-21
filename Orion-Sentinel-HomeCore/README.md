# Orion-Sentinel-HomeCore

**Home automation and light apps stack for Raspberry Pi 5**

## Overview

Orion-Sentinel-HomeCore is a production-ready home automation stack designed for Raspberry Pi 5. It provides Home Assistant for smart home control, along with optional add-ons for MQTT, Zigbee devices, Node-RED automation, and Mealie recipe management.

**Default Security Posture:** All services are LOCAL ONLY (LAN access). No public exposure by default.

## What Runs Here

- **Home Assistant** - Smart home hub and automation platform
- **Mosquitto** (optional, profile: mqtt) - MQTT broker for IoT devices
- **Zigbee2MQTT** (optional, profile: zigbee) - Zigbee device gateway
- **Node-RED** (optional, profile: nodered) - Visual automation flows
- **ESPHome** (optional, profile: esphome) - ESP device management
- **Mealie** (optional, profile: mealie) - Recipe and meal planning with Postgres

## Quick Start

```bash
# 1. Run setup script (creates directories, generates secrets, writes env files)
./scripts/setup.sh

# 2. Review and edit configuration (optional)
nano env/.env.example
# Copy to .env and customize if needed
cp env/.env.example .env

# 3. Start Home Assistant (basic)
./scripts/orionctl.sh up

# 4. Start with MQTT and Zigbee support
./scripts/orionctl.sh up mqtt zigbee

# 5. Start everything including Mealie
./scripts/orionctl.sh up mealie mqtt zigbee
```

## Access

**Home Assistant:**
- LAN: `http://<PI_IP>:8123`
- Local network access only by default

**Mealie (when enabled):**
- LAN: `http://<PI_IP>:9000`
- Local network access only

## Hardware Requirements

### Minimum
- **Hardware:** Raspberry Pi 5 (4GB RAM minimum, 8GB recommended)
- **Storage:** **SSD REQUIRED** - Do not use microSD for databases
  - 64GB minimum for system + configs
  - 128GB+ recommended
- **Network:** Ethernet connection recommended for reliability

### Optional USB Devices
- **Zigbee Coordinator:** Sonoff Zigbee 3.0 USB Dongle, ConBee II, or similar
- **Z-Wave Stick:** Aeotec Z-Stick (if using Z-Wave devices)

To find your USB device path:
```bash
ls -l /dev/serial/by-id/
```

## Profiles

Enable optional services using profiles:

| Profile | Services | Use Case |
|---------|----------|----------|
| (none) | Home Assistant only | Basic smart home |
| `mqtt` | + Mosquitto | IoT devices, sensors |
| `zigbee` | + Zigbee2MQTT | Zigbee lights, sensors |
| `nodered` | + Node-RED | Visual automation flows |
| `esphome` | + ESPHome | ESP8266/ESP32 devices |
| `mealie` | + Mealie + Postgres | Recipe management |

**Examples:**
```bash
# Home Assistant + MQTT
./scripts/orionctl.sh up mqtt

# Home Assistant + MQTT + Zigbee
./scripts/orionctl.sh up mqtt zigbee

# Everything
./scripts/orionctl.sh up mqtt zigbee nodered esphome mealie
```

## Storage Configuration

All data is stored under `${DATA_ROOT}` (default: `/srv/homecore`):

```
/srv/homecore/
├── homeassistant/          # Home Assistant config and database
├── mosquitto/              # MQTT broker data
│   ├── config/
│   ├── data/
│   └── log/
├── zigbee2mqtt/            # Zigbee device database
├── nodered/                # Node-RED flows
├── esphome/                # ESPHome device configs
└── mealie/                 # Mealie recipes and database
    ├── data/
    └── postgres/
```

**Important:** Use an SSD for the DATA_ROOT location. MicroSD cards will degrade quickly with database writes.

## Network Configuration

By default, all services use the `homecore_internal` Docker network and expose ports to LAN:

- Home Assistant: `0.0.0.0:8123` (accessible on LAN)
- Mealie: `0.0.0.0:9000` (when mealie profile enabled)
- Mosquitto MQTT: `0.0.0.0:1883` (when mqtt profile enabled)
- Node-RED: `0.0.0.0:1880` (when nodered profile enabled)
- ESPHome: `0.0.0.0:6052` (when esphome profile enabled)

No services are exposed to the internet by default.

## Management Commands

The `orionctl.sh` script provides convenient management:

```bash
# Start services
./scripts/orionctl.sh up [profiles...]       # Start HomeCore with optional profiles
./scripts/orionctl.sh down                   # Stop all services
./scripts/orionctl.sh restart                # Restart all services

# View status and logs
./scripts/orionctl.sh ps                     # Show running containers
./scripts/orionctl.sh logs [service]         # View logs
./scripts/orionctl.sh validate               # Validate configuration

# Maintenance
./scripts/orionctl.sh pull                   # Update Docker images
```

## Configuration

See [INSTALL.md](INSTALL.md) for detailed installation and configuration instructions.

## Migrating from Old Setup

If you're migrating from the monolithic Orion-Sentinel-CoreSrv, see [../MIGRATION.md](../MIGRATION.md) for step-by-step migration instructions.

## Troubleshooting

### Home Assistant won't start
```bash
# Check logs
./scripts/orionctl.sh logs homeassistant

# Verify permissions
sudo chown -R 1000:1000 ${DATA_ROOT}/homeassistant
```

### Zigbee2MQTT can't find USB device
```bash
# List USB devices
ls -l /dev/serial/by-id/

# Update ZIGBEE_DEVICE in .env with correct path
nano .env
```

### Mealie database connection issues
```bash
# Check database health
docker exec orion_homecore_mealie_db pg_isready -U mealie

# View database logs
./scripts/orionctl.sh logs mealie-db
```

### Out of disk space
```bash
# Check disk usage
df -h

# If using microSD, migrate to SSD immediately!
# See INSTALL.md for SSD setup instructions
```

## Documentation

- [INSTALL.md](INSTALL.md) - Complete installation guide
- [../MIGRATION.md](../MIGRATION.md) - Migration from old setup

## Timezone

Default timezone is `Europe/Amsterdam`. Change in `.env`:
```bash
TZ=America/New_York  # or your timezone
```

## Security Notes

- All services run on LAN only by default
- No public exposure
- No reverse proxy included (intentionally simple)
- For remote access, use VPN (WireGuard, Tailscale, etc.)

## License

MIT License - See [LICENSE](../LICENSE)

---

**Hardware:** Raspberry Pi 5  
**Purpose:** Home automation and light applications  
**Security:** Local-only by default
