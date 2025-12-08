#!/usr/bin/env bash
# orionctl - Orion-Sentinel-CoreSrv control script
# Quick helper for common Docker Compose operations with proper env/profile handling

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory - resolve symlinks to find the real script location
SCRIPT_SOURCE="${BASH_SOURCE[0]}"
while [ -L "$SCRIPT_SOURCE" ]; do
    LINK_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
    SCRIPT_SOURCE="$(readlink "$SCRIPT_SOURCE")"
    # If relative symlink, resolve relative to directory containing symlink
    [[ $SCRIPT_SOURCE != /* ]] && SCRIPT_SOURCE="$LINK_DIR/$SCRIPT_SOURCE"
done
SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
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

# Validation error (doesn't exit)
validation_error() {
    echo -e "${RED}✗${NC} $*"
}

# Check if env files exist
check_env_file() {
    local env_file="$1"
    if [ ! -f "$env_file" ]; then
        error "Environment file not found: $env_file"
    fi
}

# Main command handling
CMD=${1:-}

case "$CMD" in
    # =========================================================================
    # Start commands (different profiles)
    # =========================================================================
    
    up-core)
        info "Starting core profile (Traefik + Authelia)..."
        check_env_file "env/.env.core"
        docker compose \
            --env-file env/.env.core \
            --profile core up -d
        success "Core services started"
        info "Access Authelia at: https://auth.local"
        info "Access Traefik at: https://traefik.local"
        ;;
    
    up-observability)
        info "Starting core + observability profiles..."
        check_env_file "env/.env.core"
        check_env_file "env/.env.monitoring"
        docker compose \
            --env-file env/.env.core \
            --env-file env/.env.monitoring \
            --profile core --profile monitoring up -d
        success "Core + observability services started"
        info "Access Grafana at: https://grafana.local"
        info "Access Prometheus at: https://prometheus.local"
        ;;
    
    up-media)
        info "Starting core + media profiles..."
        check_env_file "env/.env.core"
        check_env_file "env/.env.media"
        docker compose \
            --env-file env/.env.core \
            --env-file env/.env.media \
            --profile core --profile media-core --profile media-ai up -d
        success "Core + media services started"
        info "Access Jellyfin at: https://jellyfin.local"
        info "Access Jellyseerr at: https://requests.local"
        ;;
    
    up-full)
        info "Starting all profiles (core, media, monitoring, maintenance)..."
        check_env_file "env/.env.core"
        check_env_file "env/.env.media"
        check_env_file "env/.env.monitoring"
        docker compose \
            --env-file env/.env.core \
            --env-file env/.env.media \
            --env-file env/.env.monitoring \
            --profile core --profile media-core --profile media-ai \
            --profile monitoring --profile maintenance up -d
        success "All services started"
        info "Access Homepage at: https://home.local"
        ;;
    
    # =========================================================================
    # Stop commands
    # =========================================================================
    
    down)
        info "Stopping all services..."
        docker compose down
        success "All services stopped"
        ;;
    
    stop)
        info "Stopping all services (keeping containers)..."
        docker compose stop
        success "All services stopped (use 'up-*' to restart)"
        ;;
    
    # =========================================================================
    # Status & logs
    # =========================================================================
    
    status)
        info "Service status:"
        docker compose ps
        ;;
    
    logs)
        SERVICE=${2:-}
        if [ -n "$SERVICE" ]; then
            info "Following logs for $SERVICE..."
            docker compose logs -f "$SERVICE"
        else
            info "Following logs for all services..."
            docker compose logs -f
        fi
        ;;
    
    ps)
        docker compose ps
        ;;
    
    # =========================================================================
    # Maintenance
    # =========================================================================
    
    pull)
        info "Pulling latest images..."
        docker compose pull
        success "Images updated"
        ;;
    
    restart)
        SERVICE=${2:-}
        if [ -n "$SERVICE" ]; then
            info "Restarting $SERVICE..."
            docker compose restart "$SERVICE"
            success "$SERVICE restarted"
        else
            info "Restarting all services..."
            docker compose restart
            success "All services restarted"
        fi
        ;;
    
    # =========================================================================
    # Backup
    # =========================================================================
    
    backup)
        info "Running backup..."
        if [ -x "$SCRIPT_DIR/backup.sh" ]; then
            "$SCRIPT_DIR/backup.sh"
        else
            error "Backup script not found or not executable: $SCRIPT_DIR/backup.sh"
        fi
        ;;
    
    # =========================================================================
    # Health checks
    # =========================================================================
    
    health)
        info "Checking service health..."
        echo ""
        
        # Core services
        echo "Core Services:"
        curl -s http://localhost/ping > /dev/null 2>&1 && \
            echo "  ✓ Traefik: OK" || echo "  ✗ Traefik: DOWN"
        curl -s http://localhost:9091/api/health > /dev/null 2>&1 && \
            echo "  ✓ Authelia: OK" || echo "  ✗ Authelia: DOWN"
        
        # Monitoring
        echo ""
        echo "Monitoring Services:"
        curl -s http://localhost:9090/-/healthy > /dev/null 2>&1 && \
            echo "  ✓ Prometheus: OK" || echo "  ✗ Prometheus: DOWN"
        curl -s http://localhost:3000/api/health > /dev/null 2>&1 && \
            echo "  ✓ Grafana: OK" || echo "  ✗ Grafana: DOWN"
        curl -s http://localhost:3100/ready > /dev/null 2>&1 && \
            echo "  ✓ Loki: OK" || echo "  ✗ Loki: DOWN"
        ;;
    
    # =========================================================================
    # Setup & Validation
    # =========================================================================
    
    setup)
        info "Running interactive setup..."
        if [ -x "$SCRIPT_DIR/setup.sh" ]; then
            "$SCRIPT_DIR/setup.sh"
        else
            error "Setup script not found: $SCRIPT_DIR/setup.sh"
        fi
        ;;
    
    validate)
        info "Validating configuration..."
        
        # Check env files
        MISSING=0
        if [ ! -f "env/.env.core" ]; then
            validation_error "Missing env/.env.core"
            ((MISSING++))
        else
            success "Found env/.env.core"
        fi
        
        # Check for placeholders
        if [ -f "env/.env.core" ]; then
            if grep -q "change-me" env/.env.core; then
                warn "env/.env.core contains 'change-me' placeholders"
                info "Run: ./orionctl.sh setup"
            fi
        fi
        
        # Check Docker
        if docker ps &> /dev/null; then
            success "Docker daemon is running"
        else
            validation_error "Cannot connect to Docker daemon"
            info "Try: sudo systemctl start docker"
        fi
        
        # Check directories
        if [ -f "env/.env.core" ]; then
            CONFIG_ROOT=$(grep "^CONFIG_ROOT=" env/.env.core | cut -d'=' -f2- | tr -d '"' | tr -d "'")
            if [ -n "$CONFIG_ROOT" ] && [ -d "$CONFIG_ROOT" ]; then
                success "Config directory exists: $CONFIG_ROOT"
            elif [ -n "$CONFIG_ROOT" ]; then
                warn "Config directory not found: $CONFIG_ROOT"
            fi
        fi
        
        if [ $MISSING -eq 0 ]; then
            success "Validation complete!"
            exit 0
        else
            warn "Please fix issues above"
            exit 1
        fi
        ;;
    
    # =========================================================================
    # Bootstrap Commands
    # =========================================================================
    
    grafana-bootstrap)
        info "Bootstrapping Grafana provisioning..."
        
        # Resolve repo root using git (with fallback to script directory)
        if command -v git &> /dev/null && git rev-parse --show-toplevel &> /dev/null; then
            BOOTSTRAP_REPO_ROOT="$(git rev-parse --show-toplevel)"
        else
            BOOTSTRAP_REPO_ROOT="$REPO_ROOT"
        fi
        
        # Check for Python venv
        VENV_PYTHON="$BOOTSTRAP_REPO_ROOT/.venv/bin/python"
        if [ ! -f "$VENV_PYTHON" ]; then
            error "Python venv not found or missing."
            echo "  To create it, run:"
            echo "    cd \"$BOOTSTRAP_REPO_ROOT\""
            echo "    python3 -m venv .venv"
            echo "    .venv/bin/pip install --upgrade pip"
            exit 1
        fi
        
        # Ensure Grafana container is up
        info "Starting Grafana container..."
        check_env_file "env/.env.core"
        check_env_file "env/.env.monitoring"
        docker compose \
            --env-file env/.env.core \
            --env-file env/.env.monitoring \
            --profile monitoring up -d grafana
        
        # Run bootstrap script
        info "Running Grafana bootstrap script..."
        "$VENV_PYTHON" "$BOOTSTRAP_REPO_ROOT/scripts/bootstrap_grafana.py"
        BOOTSTRAP_EXIT=$?
        
        if [ $BOOTSTRAP_EXIT -eq 0 ]; then
            success "Grafana bootstrap completed successfully"
        else
            error "Grafana bootstrap failed with exit code $BOOTSTRAP_EXIT"
            exit $BOOTSTRAP_EXIT
        fi
        ;;
    
    # =========================================================================
    # Help
    # =========================================================================
    
    help|--help|-h|"")
        cat << 'EOF'
orionctl - Orion-Sentinel-CoreSrv Control Script

USAGE:
    ./orionctl.sh COMMAND [OPTIONS]

SETUP COMMANDS:
    setup           Run interactive setup wizard (first-time setup)
    validate        Validate configuration and prerequisites

BOOTSTRAP COMMANDS:
    grafana-bootstrap   Bootstrap Grafana provisioning (datasources + dashboards)

STARTUP COMMANDS:
    up-core         Start core services only (Traefik + Authelia)
    up-observability Start core + observability (Prometheus, Grafana, Loki)
    up-media        Start core + media stack (Jellyfin, *arr, qBit)
    up-full         Start all services (core + media + monitoring + maintenance)

STOP COMMANDS:
    down            Stop and remove all containers
    stop            Stop containers (but don't remove them)

STATUS & LOGS:
    status          Show service status
    ps              Show running containers
    logs [SERVICE]  Follow logs (all services or specific service)
    health          Quick health check of services

MAINTENANCE:
    pull            Pull latest Docker images
    restart [SVC]   Restart all services or specific service
    backup          Run backup script

EXAMPLES:
    # First-time setup
    ./orionctl.sh setup

    # Validate configuration
    ./orionctl.sh validate

    # Bootstrap Grafana provisioning
    ./orionctl.sh grafana-bootstrap

    # Start just core services for testing
    ./orionctl.sh up-core

    # Start everything
    ./orionctl.sh up-full

    # View Jellyfin logs
    ./orionctl.sh logs jellyfin

    # Restart Authelia
    ./orionctl.sh restart authelia

    # Check service health
    ./orionctl.sh health

    # Stop everything
    ./orionctl.sh down

NOTES:
    - For first-time setup, run: ./orionctl.sh setup
    - Ensure .env files are created (setup script does this automatically)
    - Run from the repository root or use the full path to this script
    - All commands use Docker Compose under the hood

For more information, see: INSTALL.md or docs/SETUP-CoreSrv.md
EOF
        ;;
    
    *)
        error "Unknown command: $CMD\n  Use './orionctl.sh help' for usage"
        ;;
esac
