#!/usr/bin/env bash
# deploy.sh - Automated deployment script for Orion-Sentinel-CoreSrv
#
# This script deploys one or more stacks with proper health checking
#
# Usage: 
#   ./scripts/deploy.sh <stack-name> [<stack-name> ...]
#   ./scripts/deploy.sh ingress
#   ./scripts/deploy.sh observability
#   ./scripts/deploy.sh all
#
# Available stacks:
#   - ingress       : Traefik reverse proxy
#   - observability : Prometheus, Grafana, Loki, Uptime Kuma
#   - apps          : Mealie, DSMR
#   - portal        : Homepage/Homearr
#   - home          : Home Assistant and related services
#   - netdata       : Netdata monitoring (if available)
#   - all           : All stacks

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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
}

section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$*${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

usage() {
    cat << EOF
Usage: $0 <stack> [stack...]

Available stacks:
  ingress          Traefik reverse proxy
  observability    Prometheus, Grafana, Loki, Uptime Kuma
  apps             Mealie, DSMR
  portal           Homepage/Homearr portal
  home             Home Assistant, Zigbee2MQTT, etc.
  netdata          Netdata monitoring (if configured)
  all              Deploy all stacks in order

Examples:
  $0 ingress
  $0 observability apps
  $0 all

EOF
    exit 1
}

# Check if stack name is valid
get_stack_file() {
    local stack="$1"
    
    case "$stack" in
        ingress)
            echo "stacks/ingress/traefik.yaml"
            ;;
        observability)
            echo "stacks/observability/stack.yaml"
            ;;
        apps)
            echo "stacks/apps/stack.yaml"
            ;;
        portal)
            echo "stacks/portal/stack.yaml"
            ;;
        home)
            echo "stacks/home/stack.yaml"
            ;;
        netdata)
            if [ -f "stacks/observability/netdata/compose.yml" ]; then
                echo "stacks/observability/netdata/compose.yml"
            else
                echo ""
            fi
            ;;
        *)
            echo ""
            ;;
    esac
}

# Wait for containers to become healthy
wait_for_health() {
    local compose_file="$1"
    local timeout="${2:-120}"
    
    info "Waiting for containers to become healthy (timeout: ${timeout}s)..."
    
    local start_time=$(date +%s)
    local all_healthy=false
    
    while [ $all_healthy = false ]; do
        local current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        
        if [ $elapsed -ge $timeout ]; then
            warn "Timeout waiting for containers to become healthy"
            return 1
        fi
        
        # Get container health status
        local containers=$(docker compose -f "$compose_file" ps --format json 2>/dev/null | jq -r '.Name' 2>/dev/null || true)
        
        if [ -z "$containers" ]; then
            warn "No containers found"
            sleep 2
            continue
        fi
        
        local unhealthy=0
        local healthy=0
        
        while IFS= read -r container; do
            if [ -z "$container" ]; then
                continue
            fi
            
            local health=$(docker inspect "$container" --format='{{if .State.Health}}{{.State.Health.Status}}{{else}}no-healthcheck{{end}}' 2>/dev/null || echo "unknown")
            
            case "$health" in
                healthy|no-healthcheck)
                    healthy=$((healthy + 1))
                    ;;
                *)
                    unhealthy=$((unhealthy + 1))
                    ;;
            esac
        done <<< "$containers"
        
        if [ $unhealthy -eq 0 ]; then
            all_healthy=true
            success "All containers are healthy ($healthy containers)"
        else
            echo -n "."
            sleep 2
        fi
    done
}

# Deploy a single stack
deploy_stack() {
    local stack="$1"
    
    section "Deploying: $stack"
    
    local stack_file=$(get_stack_file "$stack")
    
    if [ -z "$stack_file" ]; then
        error "Unknown stack: $stack"
        return 1
    fi
    
    if [ ! -f "$stack_file" ]; then
        error "Stack file not found: $stack_file"
        return 1
    fi
    
    info "Stack file: $stack_file"
    
    # Pull images
    info "Pulling images..."
    if docker compose -f "$stack_file" pull; then
        success "Images pulled"
    else
        warn "Some images could not be pulled (may not exist yet or already latest)"
    fi
    
    # Start services
    info "Starting services..."
    if docker compose -f "$stack_file" up -d; then
        success "Services started"
    else
        error "Failed to start services"
        return 1
    fi
    
    # Wait for health
    if wait_for_health "$stack_file" 180; then
        success "Stack deployed successfully"
    else
        warn "Stack deployed but some containers may not be healthy"
        
        # Show status
        echo ""
        info "Container status:"
        docker compose -f "$stack_file" ps
        
        # Show logs for unhealthy containers
        local unhealthy_containers=$(docker compose -f "$stack_file" ps --format json 2>/dev/null | jq -r 'select(.Health == "unhealthy") | .Name' 2>/dev/null || true)
        
        if [ -n "$unhealthy_containers" ]; then
            echo ""
            warn "Logs from unhealthy containers:"
            while IFS= read -r container; do
                if [ -n "$container" ]; then
                    echo ""
                    echo "=== $container ==="
                    docker logs --tail 50 "$container" 2>&1 || true
                fi
            done <<< "$unhealthy_containers"
        fi
        
        return 1
    fi
    
    # Show service URLs
    echo ""
    info "Service URLs:"
    show_service_urls "$stack"
    
    return 0
}

# Show service URLs for a stack
show_service_urls() {
    local stack="$1"
    local domain="${LOCAL_DOMAIN:-orion.lan}"
    
    case "$stack" in
        ingress)
            echo "  🌐 Traefik Dashboard: https://traefik.$domain"
            ;;
        observability)
            echo "  📊 Grafana:       https://grafana.$domain"
            echo "  📈 Prometheus:    https://prometheus.$domain"
            echo "  🔔 Uptime Kuma:   https://uptime.$domain"
            ;;
        apps)
            echo "  🍳 Mealie:        https://mealie.$domain"
            echo "  ⚡ DSMR Reader:   https://dsmr.$domain"
            ;;
        portal)
            echo "  🏠 Homepage:      https://home.$domain or https://homearr.$domain"
            ;;
        home)
            echo "  🏡 Home Assistant: https://homeassistant.$domain"
            ;;
        netdata)
            echo "  📊 Netdata:       https://netdata.$domain"
            ;;
    esac
}

# Print header
echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║   Orion-Sentinel-CoreSrv Deployment    ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# Check arguments
if [ $# -eq 0 ]; then
    usage
fi

# Check if .env exists
if [ ! -f .env ]; then
    error ".env file not found"
    info "Please copy .env.example to .env and configure it"
    exit 1
fi

# Source .env
set -a
source .env
set +a

# Determine stacks to deploy
STACKS_TO_DEPLOY=()

for arg in "$@"; do
    if [ "$arg" = "all" ]; then
        STACKS_TO_DEPLOY=("ingress" "observability" "apps" "portal" "home")
        if [ -f "stacks/observability/netdata/compose.yml" ]; then
            STACKS_TO_DEPLOY+=("netdata")
        fi
        break
    else
        STACKS_TO_DEPLOY+=("$arg")
    fi
done

# Deploy each stack
DEPLOYED=0
FAILED=0

for stack in "${STACKS_TO_DEPLOY[@]}"; do
    if deploy_stack "$stack"; then
        DEPLOYED=$((DEPLOYED + 1))
    else
        FAILED=$((FAILED + 1))
    fi
    echo ""
done

# Summary
section "Deployment Summary"

echo ""
echo -e "${GREEN}✓ Deployed: $DEPLOYED${NC}"
echo -e "${RED}✗ Failed:   $FAILED${NC}"
echo ""

if [ $FAILED -gt 0 ]; then
    error "Some stacks failed to deploy properly"
    info "Check the logs above for details"
    exit 1
else
    success "All stacks deployed successfully!"
    echo ""
    info "Next steps:"
    echo "  1. Check service URLs above"
    echo "  2. Configure each service via web UI"
    echo "  3. Check docs/ for service-specific setup guides"
    exit 0
fi
