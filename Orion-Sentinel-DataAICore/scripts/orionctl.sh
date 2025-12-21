#!/usr/bin/env bash
# Orion-Sentinel-DataAICore Control Script
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
Orion-Sentinel-DataAICore Control Script

Usage: $0 COMMAND [PROFILES...]

COMMANDS:
  up [profiles...]    Start DataAICore with specified profiles
  down                Stop all services
  restart             Restart all services
  ps                  Show running containers
  logs [service]      View logs (all or specific service)
  pull                Pull latest Docker images
  validate            Validate compose configuration

PROFILES:
  nextcloud         - Nextcloud + Postgres + Redis
  search            - SearXNG + Valkey + Meilisearch + Tika + Indexer
  llm               - Ollama + Open WebUI
  public-nextcloud  - Caddy reverse proxy for public Nextcloud (requires nextcloud)

EXAMPLES:
  $0 up nextcloud                    # Nextcloud only
  $0 up search                       # Search stack only
  $0 up llm                          # LLM stack only
  $0 up nextcloud search llm         # All stacks
  $0 up nextcloud public-nextcloud   # Public Nextcloud (requires domain, DNS, port forwarding)
  $0 down                            # Stop all services
  $0 ps                              # Show running containers
  $0 logs nextcloud                  # View Nextcloud logs

NOTES:
  - All services are LOCAL ONLY by default
  - Use public-nextcloud profile only for internet-exposed Nextcloud
  - See INSTALL.md for public Nextcloud setup requirements

EOF
}

# Main command handling
CMD="${1:-help}"
shift || true

case "$CMD" in
    up)
        check_env
        
        if [ $# -eq 0 ]; then
            error "At least one profile required. Use: $0 up nextcloud|search|llm"
        fi
        
        PROFILES=("$@")
        PROFILE_ARGS=$(build_profile_args "${PROFILES[@]}")
        info "Starting DataAICore with profiles: ${PROFILES[*]}"
        eval "docker compose $PROFILE_ARGS up -d"
        
        echo ""
        success "DataAICore started"
        echo ""
        info "Access points:"
        
        # Show profile-specific access info
        for profile in "$@"; do
            case "$profile" in
                nextcloud)
                    echo "  - Nextcloud: http://<OPTIPLEX_IP>:8080"
                    echo "    Default admin: admin / (see .env for password)"
                    ;;
                search)
                    echo "  - SearXNG: http://<OPTIPLEX_IP>:8888"
                    echo "    Local docs: Drop files into ${DATA_ROOT:-/srv/dataaicore}/search/local-search/"
                    ;;
                llm)
                    echo "  - Open WebUI: http://<OPTIPLEX_IP>:3000"
                    echo "    Pull model: docker exec -it orion_dataaicore_ollama ollama pull llama3.2:3b"
                    ;;
                public-nextcloud)
                    echo "  - Public Nextcloud: https://cloud.\${ORION_DOMAIN}"
                    warn "Ensure DNS and port forwarding (443) are configured!"
                    ;;
            esac
        done
        echo ""
        ;;
    
    down)
        info "Stopping all DataAICore services..."
        docker compose down
        success "All services stopped"
        ;;
    
    restart)
        info "Restarting all DataAICore services..."
        docker compose restart
        success "All services restarted"
        ;;
    
    ps)
        info "DataAICore services:"
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
