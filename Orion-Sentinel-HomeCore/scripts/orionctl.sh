#!/usr/bin/env bash
# Orion-Sentinel-HomeCore Control Script
# Wrapper for Docker Compose operations with profile handling

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

# Check if .env exists
check_env() {
    if [ ! -f ".env" ]; then
        error ".env file not found. Run ./scripts/setup.sh first"
    fi
}

# Build profile arguments from command line
build_profile_args() {
    local profiles=("$@")
    local args=""
    
    for profile in "${profiles[@]}"; do
        args="$args --profile $profile"
    done
    
    echo "$args"
}

# Show usage
usage() {
    cat << EOF
Orion-Sentinel-HomeCore Control Script

Usage: $0 COMMAND [PROFILES...]

COMMANDS:
  up [profiles...]    Start HomeCore with optional profiles
  down                Stop all services
  restart             Restart all services
  ps                  Show running containers
  logs [service]      View logs (all or specific service)
  pull                Pull latest Docker images
  validate            Validate compose configuration

PROFILES:
  mqtt      - Enable Mosquitto MQTT broker
  zigbee    - Enable Zigbee2MQTT (requires mqtt)
  nodered   - Enable Node-RED
  esphome   - Enable ESPHome
  mealie    - Enable Mealie recipe management

EXAMPLES:
  $0 up                      # Home Assistant only
  $0 up mqtt                 # Home Assistant + MQTT
  $0 up mqtt zigbee          # Home Assistant + MQTT + Zigbee
  $0 up mqtt zigbee mealie   # Home Assistant + MQTT + Zigbee + Mealie
  $0 down                    # Stop all services
  $0 ps                      # Show running containers
  $0 logs homeassistant      # View Home Assistant logs

EOF
}

# Main command handling
CMD="${1:-help}"
shift || true

case "$CMD" in
    up)
        check_env
        
        if [ $# -eq 0 ]; then
            info "Starting Home Assistant (base stack)..."
            docker compose up -d
        else
            PROFILES=("$@")
            PROFILE_ARGS=$(build_profile_args "${PROFILES[@]}")
            info "Starting HomeCore with profiles: ${PROFILES[*]}"
            eval "docker compose $PROFILE_ARGS up -d"
        fi
        
        echo ""
        success "HomeCore started"
        echo ""
        info "Access points:"
        echo "  - Home Assistant: http://<PI_IP>:8123"
        
        # Show profile-specific access info
        for profile in "$@"; do
            case "$profile" in
                mqtt)
                    echo "  - MQTT Broker: mqtt://<PI_IP>:1883"
                    ;;
                zigbee)
                    echo "  - Zigbee2MQTT: http://<PI_IP>:8080"
                    ;;
                nodered)
                    echo "  - Node-RED: http://<PI_IP>:1880"
                    ;;
                esphome)
                    echo "  - ESPHome: http://<PI_IP>:6052"
                    ;;
                mealie)
                    echo "  - Mealie: http://<PI_IP>:9000"
                    ;;
            esac
        done
        echo ""
        ;;
    
    down)
        info "Stopping all HomeCore services..."
        docker compose down
        success "All services stopped"
        ;;
    
    restart)
        info "Restarting all HomeCore services..."
        docker compose restart
        success "All services restarted"
        ;;
    
    ps)
        info "HomeCore services:"
        docker compose ps
        ;;
    
    logs)
        if [ $# -eq 0 ]; then
            info "Showing logs for all services (Ctrl+C to exit)..."
            docker compose logs -f
        else
            SERVICE="$1"
            info "Showing logs for $SERVICE (Ctrl+C to exit)..."
            docker compose logs -f "$SERVICE"
        fi
        ;;
    
    pull)
        info "Pulling latest Docker images..."
        docker compose pull
        success "Images updated"
        warn "Run '$0 down' then '$0 up [profiles]' to use new images"
        ;;
    
    validate)
        info "Validating compose configuration..."
        docker compose config --quiet
        success "Configuration is valid"
        ;;
    
    help|--help|-h)
        usage
        ;;
    
    *)
        error "Unknown command: $CMD"
        echo ""
        usage
        ;;
esac
