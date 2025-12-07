# DSMR Reader - Dutch Smart Meter

## Overview

DSMR Reader is a data logger and dashboard for Dutch Smart Meters (DSMR protocol). It reads energy consumption data from your smart meter via the P1 port and provides detailed analytics, graphs, and energy monitoring.

## Features

- **Live Monitoring**: Real-time electricity and gas consumption
- **Historical Data**: Store and analyze years of consumption data
- **Cost Tracking**: Calculate energy costs
- **Tariff Support**: Day/night tariffs and dynamic pricing
- **Graphs & Charts**: Visualize consumption patterns
- **Export**: Export data to CSV, JSON
- **API**: REST API for integrations
- **Notifications**: Alerts for high consumption

## Hardware Requirements

### P1 Cable

You need a USB-to-P1 cable to connect your smart meter to the server:

- **Type**: USB to RJ12 P1 cable
- **Protocol**: DSMR 4.0/5.0 compatible
- **Price**: ~€15-25
- **Where to buy**:
  - AliExpress: Search "USB P1 cable"
  - Local electronics stores
  - Amazon

### Smart Meter Compatibility

DSMR Reader works with Dutch smart meters using DSMR protocol:

- DSMR 4.0 (older meters)
- DSMR 5.0 (newer meters)
- DSMR 5.0.2 (latest)

**How to check**: Look at your meter for "DSMR" marking and version number.

## Installation

### 1. Connect P1 Cable

1. Locate P1 port on your smart meter (usually labeled "P1" with RJ12 connector)
2. Plug in P1 cable to meter
3. Connect USB end to your CoreSrv server
4. Identify device path: `ls -l /dev/ttyUSB*`
5. Update `.env.home-automation`: `DSMR_SERIAL_PORT=/dev/ttyUSB0`

### 2. Start DSMR Reader

```bash
docker compose --profile home-automation up -d dsmrdb dsmr
```

### 3. Access Web Interface

- URL: `https://energy.local`
- Default credentials:
  - Username: `admin`
  - Password: `admin` (change immediately!)

### 4. Initial Configuration

1. Log in to web interface
2. Change admin password
3. Go to Configuration → DSMR Settings
4. Verify serial port settings
5. Wait for data to start flowing (may take a few minutes)

## Serial Port Configuration

Common device paths:

- `/dev/ttyUSB0` - Most common for USB P1 cables
- `/dev/ttyUSB1` - If ttyUSB0 is used by Zigbee coordinator
- `/dev/serial/by-id/usb-...` - Persistent path (recommended)

**Find your device**:

```bash
ls -l /dev/serial/by-id/
```

**Troubleshooting**: If device not found:
1. Check cable connection
2. Try different USB port
3. Check dmesg: `dmesg | grep ttyUSB`
4. Verify permissions: `ls -l /dev/ttyUSB0`

## Energy Cost Configuration

To track costs:

1. Go to Configuration → Energy Prices
2. Add your electricity tariffs:
   - Day tariff (peak)
   - Night tariff (off-peak)
3. Add gas price
4. Set currency (EUR)
5. Enable cost calculations

## Data Retention

DSMR Reader stores data indefinitely by default. Configure retention:

1. Configuration → Data Management
2. Set retention period (e.g., 2 years)
3. Enable automatic cleanup

## Backup

Database and configuration stored in:

- Database: `${CONFIG_ROOT}/dsmr/db/`
- Application: `${CONFIG_ROOT}/dsmr/app/`

**Backup command**:

```bash
docker compose exec dsmrdb pg_dump -U dsmrreader dsmrreader > dsmr-backup.sql
```

## Integration with Home Assistant

### Option 1: DSMR Reader Integration (Recommended)

1. In Home Assistant: Settings → Devices & Services
2. Add Integration → DSMR Reader
3. Host: `dsmr` or `energy.local`
4. Port: `80`
5. Configure sensors

### Option 2: Direct Serial Integration

Alternatively, use Home Assistant's built-in DSMR integration:

1. Settings → Devices & Services → Add Integration
2. DSMR
3. Serial port: Use same as DSMR Reader
4. Note: Cannot use both at once on same serial port!

### Sensors in Home Assistant

Once integrated, you'll have sensors for:

- Current electricity usage (W)
- Current electricity return (solar)
- Total electricity consumed (kWh)
- Total electricity returned (kWh)
- Gas consumption (m³)
- Tariff indicator (peak/off-peak)

### Energy Dashboard

Add DSMR sensors to Home Assistant's Energy Dashboard:

1. Settings → Dashboards → Energy
2. Add electricity grid consumption
3. Add gas consumption
4. Add electricity return (if solar)
5. Configure costs

## API

DSMR Reader provides a REST API for automation:

**Endpoint**: `https://energy.local/api/v2/`

**Authentication**: API key required (generate in DSMR settings)

**Examples**:

- Current usage: `/api/v2/consumption/today`
- Latest reading: `/api/v2/datalogger/dsmrreading`

## Notifications

Configure notifications for:

- High electricity usage
- Daily consumption summary
- Monthly reports

Supported methods:

- Email
- Telegram
- Pushover
- Custom webhooks

## Graphs & Analytics

Available visualizations:

- Live usage graph
- Daily comparison
- Week/month/year comparison
- Cost tracking
- Peak usage times
- Tariff distribution

## Resources

- Documentation: https://dsmr-reader.readthedocs.io/
- GitHub: https://github.com/dsmrreader/dsmr-reader
- Dutch Smart Meter Info: https://www.netbeheernederland.nl/

## Troubleshooting

### No Data Received

1. Check cable connection
2. Verify serial port: `docker compose exec dsmr ls -l /dev/ttyUSB*`
3. Check DSMR logs: `docker compose logs dsmr`
4. Ensure meter P1 port is enabled (some meters require activation)

### Connection Errors

1. Check serial port permissions
2. Verify device path in .env
3. Try different baud rate in DSMR settings
4. Check for conflicting applications using the port

### Database Issues

1. Check disk space
2. Restart containers: `docker compose restart dsmrdb dsmr`
3. Check logs: `docker compose logs dsmrdb`

---

**Note**: DSMR Reader is specifically for Dutch smart meters. If you're not in the Netherlands or don't have a DSMR-compatible meter, you can skip this service.
