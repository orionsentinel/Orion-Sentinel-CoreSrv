#!/usr/bin/env bash
# Orion-Sentinel-HomeCore Setup Script
# Creates directories, generates secrets, and initializes configuration
#
# This script is idempotent - safe to run multiple times

set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to repo root
cd "$REPO_ROOT"

# Helper functions
info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
}

error() {
    echo -e "${RED}✗${NC} $*"
    exit 1
}

# Generate random password
# 25 characters provides ~149 bits of entropy (sufficient for internal use)
generate_password() {
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-25
}

# Create directory if it doesn't exist
ensure_dir() {
    local dir="$1"
    if [ ! -d "$dir" ]; then
        info "Creating directory: $dir"
        sudo mkdir -p "$dir"
        sudo chown -R "$USER:$USER" "$dir"
        success "Created: $dir"
    else
        info "Directory already exists: $dir"
    fi
}

# Banner
echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║         Orion-Sentinel-HomeCore Setup Script                  ║"
echo "║         Raspberry Pi 5 - Home Automation Stack                ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Check if running as root
if [ "$EUID" -eq 0 ]; then
    error "Do not run this script as root. It will use sudo when needed."
fi

# Check for Docker
if ! command -v docker &> /dev/null; then
    warn "Docker not found. Install Docker first:"
    echo "  curl -fsSL https://get.docker.com -o get-docker.sh"
    echo "  sudo sh get-docker.sh"
    echo "  sudo usermod -aG docker \$USER"
    error "Docker is required"
fi

# Check for Docker Compose
if ! docker compose version &> /dev/null; then
    error "Docker Compose not found. Please install Docker Compose v2"
fi

# Default data root
DATA_ROOT="${DATA_ROOT:-/srv/homecore}"

info "Data root: $DATA_ROOT"
warn "Ensure $DATA_ROOT is on an SSD, not a microSD card!"
echo ""

# Create directory structure
info "Creating directory structure..."
ensure_dir "$DATA_ROOT"
ensure_dir "$DATA_ROOT/homeassistant"
ensure_dir "$DATA_ROOT/mosquitto/config"
ensure_dir "$DATA_ROOT/mosquitto/data"
ensure_dir "$DATA_ROOT/mosquitto/log"
ensure_dir "$DATA_ROOT/zigbee2mqtt"
ensure_dir "$DATA_ROOT/nodered"
ensure_dir "$DATA_ROOT/esphome"
ensure_dir "$DATA_ROOT/mealie/data"
ensure_dir "$DATA_ROOT/mealie/postgres"

echo ""
success "Directory structure created"
echo ""

# Create Docker network
info "Creating Docker network: homecore_internal"
if docker network inspect homecore_internal &> /dev/null; then
    info "Network homecore_internal already exists"
else
    docker network create homecore_internal
    success "Network homecore_internal created"
fi
echo ""

# Generate secrets and create .env file
ENV_FILE="$REPO_ROOT/.env"
ENV_EXAMPLE="$REPO_ROOT/env/.env.example"

if [ -f "$ENV_FILE" ]; then
    warn ".env file already exists - skipping generation"
    info "To regenerate, delete .env and run this script again"
else
    info "Generating .env file with secure secrets..."
    
    # Generate passwords
    MEALIE_DB_PASSWORD=$(generate_password)
    
    # Copy example and replace placeholders
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    
    # Replace passwords in .env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/MEALIE_DB_PASSWORD=CHANGE_ME_GENERATED_BY_SETUP/MEALIE_DB_PASSWORD=$MEALIE_DB_PASSWORD/" "$ENV_FILE"
    else
        # Linux
        sed -i "s/MEALIE_DB_PASSWORD=CHANGE_ME_GENERATED_BY_SETUP/MEALIE_DB_PASSWORD=$MEALIE_DB_PASSWORD/" "$ENV_FILE"
    fi
    
    success ".env file created with generated secrets"
    info "Edit .env to customize settings: nano .env"
fi
echo ""

# Create Mosquitto configuration
MOSQUITTO_CONF="$DATA_ROOT/mosquitto/config/mosquitto.conf"
if [ ! -f "$MOSQUITTO_CONF" ]; then
    info "Creating Mosquitto configuration..."
    cat > "$MOSQUITTO_CONF" << 'EOF'
# Mosquitto MQTT Broker Configuration
# Allow anonymous connections for internal network

listener 1883
allow_anonymous true
persistence true
persistence_location /mosquitto/data/

# WebSocket support (for web clients)
listener 9001
protocol websockets

# Logging
log_dest file /mosquitto/log/mosquitto.log
log_dest stdout
log_type error
log_type warning
log_type notice
log_type information
log_timestamp true
EOF
    success "Mosquitto configuration created"
else
    info "Mosquitto configuration already exists"
fi
echo ""

# Create Zigbee2MQTT configuration template
Z2M_CONF="$DATA_ROOT/zigbee2mqtt/configuration.yaml"
if [ ! -f "$Z2M_CONF" ]; then
    info "Creating Zigbee2MQTT configuration template..."
    cat > "$Z2M_CONF" << 'EOF'
# Zigbee2MQTT Configuration
# Documentation: https://www.zigbee2mqtt.io/

# Home Assistant integration
homeassistant: true

# Enable web frontend
frontend:
  port: 8080
  host: 0.0.0.0

# Permit joining (set to false after pairing devices)
permit_join: true

# MQTT settings
mqtt:
  base_topic: zigbee2mqtt
  server: mqtt://mosquitto:1883

# Serial port settings
serial:
  port: /dev/ttyACM0
  adapter: auto

# Advanced settings
advanced:
  log_level: info
  pan_id: GENERATE
  network_key: GENERATE
  channel: 11
  
  # Homeassistant legacy mode (disable for new setups)
  legacy_api: false
  legacy_availability_payload: false

# Device options
device_options:
  retain: true
EOF
    success "Zigbee2MQTT configuration template created"
    warn "Edit $Z2M_CONF to configure your Zigbee coordinator device"
else
    info "Zigbee2MQTT configuration already exists"
fi
echo ""

# Set permissions
info "Setting correct permissions..."
sudo chown -R "$USER:$USER" "$DATA_ROOT"
success "Permissions set"
echo ""

# Summary
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║                    Setup Complete!                             ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""
success "HomeCore is ready to deploy!"
echo ""
info "Next steps:"
echo "  1. Review configuration: nano .env"
echo "  2. Start Home Assistant: ./scripts/orionctl.sh up"
echo "  3. Access at: http://<PI_IP>:8123"
echo ""
info "Optional profiles:"
echo "  - MQTT:      ./scripts/orionctl.sh up mqtt"
echo "  - Zigbee:    ./scripts/orionctl.sh up mqtt zigbee"
echo "  - Node-RED:  ./scripts/orionctl.sh up nodered"
echo "  - Mealie:    ./scripts/orionctl.sh up mealie"
echo ""
info "For complete installation guide, see INSTALL.md"
echo ""
