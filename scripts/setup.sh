#!/usr/bin/env bash
# setup.sh - Automated Orion-Sentinel-CoreSrv Setup Script
# This script helps users quickly set up the Orion Sentinel CoreSrv stack

set -euo pipefail

# Default configuration
DEFAULT_BASE_DIR="/srv/orion-sentinel-core"
SELECTED_BASE_DIR=""  # Will be set during directory creation

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to repo root
cd "$REPO_ROOT"

# Helper functions
print_header() {
    echo -e "\n${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}"
    echo -e "${CYAN}${BOLD}  $*${NC}"
    echo -e "${CYAN}${BOLD}═══════════════════════════════════════════════════════════════${NC}\n"
}

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

fail() {
    error "$*"
    exit 1
}

prompt() {
    local message="$1"
    local default="${2:-}"
    local response
    
    if [ -n "$default" ]; then
        echo -ne "${BLUE}?${NC} $message [${BOLD}$default${NC}]: " >&2
    else
        echo -ne "${BLUE}?${NC} $message: " >&2
    fi
    
    read -r response
    echo "${response:-$default}"
}

confirm() {
    local message="$1"
    local response
    
    echo -ne "${YELLOW}?${NC} $message [y/N]: "
    read -r response
    [[ "$response" =~ ^[Yy]$ ]]
}

# Check if running as root
check_not_root() {
    if [ "$EUID" -eq 0 ]; then
        fail "Please do not run this script as root or with sudo"
    fi
}

# Check prerequisites
check_prerequisites() {
    print_header "Checking Prerequisites"
    
    local all_good=true
    
    # Check Docker
    if command -v docker &> /dev/null; then
        local docker_version=$(docker --version | cut -d' ' -f3 | cut -d',' -f1)
        success "Docker installed: v$docker_version"
    else
        error "Docker is not installed"
        info "Install Docker: https://docs.docker.com/engine/install/"
        all_good=false
    fi
    
    # Check Docker Compose
    if docker compose version &> /dev/null; then
        local compose_version=$(docker compose version --short)
        success "Docker Compose plugin installed: v$compose_version"
    else
        error "Docker Compose plugin is not installed"
        info "Install with: sudo apt install docker-compose-plugin"
        all_good=false
    fi
    
    # Check if user is in docker group
    if groups | grep -q docker; then
        success "User is in docker group"
    else
        warn "User is not in docker group"
        info "Add yourself with: sudo usermod -aG docker \$USER"
        info "Then log out and back in"
        all_good=false
    fi
    
    # Check Git
    if command -v git &> /dev/null; then
        success "Git installed"
    else
        warn "Git is not installed (optional but recommended)"
    fi
    
    # Check available disk space
    local available_space=$(df -BG "$REPO_ROOT" 2>/dev/null | awk 'NR==2 {print $4}' | sed 's/[^0-9]//g' || echo "")
    if [ -n "$available_space" ] && [ "$available_space" -eq "$available_space" ] 2>/dev/null; then
        if [ "$available_space" -gt 50 ]; then
            success "Sufficient disk space: ${available_space}GB available"
        else
            warn "Low disk space: only ${available_space}GB available (50GB+ recommended)"
        fi
    else
        warn "Could not determine available disk space"
    fi
    
    if [ "$all_good" = false ]; then
        echo ""
        fail "Please fix the issues above and run this script again"
    fi
    
    echo ""
}

# Create directory structure
create_directories() {
    print_header "Creating Directory Structure"
    
    local base_dir=$(prompt "Where should we create the data directories?" "$DEFAULT_BASE_DIR")
    
    info "Creating directories at: $base_dir"
    
    # Create main directories
    sudo mkdir -p "$base_dir"/{config,data,media,cloud,monitoring,backups}
    
    # Create media subdirectories
    sudo mkdir -p "$base_dir/media/torrents"/{movies,tv}
    sudo mkdir -p "$base_dir/media/library"/{movies,tv}
    
    # Create cloud subdirectories
    sudo mkdir -p "$base_dir/cloud"/{db,app,data}
    
    # Create monitoring subdirectories
    sudo mkdir -p "$base_dir/monitoring"/{prometheus,grafana,loki}
    
    # Set ownership
    local current_user=$(id -un)
    local current_group=$(id -gn)
    info "Setting ownership to $current_user:$current_group"
    sudo chown -R "$current_user:$current_group" "$base_dir"
    
    success "Directory structure created successfully"
    
    # Show structure
    if command -v tree &> /dev/null; then
        echo ""
        info "Directory structure:"
        tree -L 2 -d "$base_dir" 2>/dev/null || true
    fi
    
    echo ""
    
    # Save base dir globally for later use
    SELECTED_BASE_DIR="$base_dir"
}

# Setup environment files
setup_env_files() {
    print_header "Setting Up Environment Files"
    
    local puid=$(id -u)
    local pgid=$(id -g)
    
    info "Detected PUID: $puid, PGID: $pgid"
    
    # Get user preferences
    local tz=$(prompt "Enter your timezone" "Europe/Amsterdam")
    local domain=$(prompt "Enter your domain (use 'local' for LAN-only)" "local")
    local base_dir="${SELECTED_BASE_DIR:-$DEFAULT_BASE_DIR}"
    
    # Copy and configure core env file
    if [ ! -f "env/.env.core" ]; then
        info "Creating env/.env.core..."
        cp env/.env.core.example env/.env.core
        
        # Replace values
        sed -i "s|PUID=1000|PUID=$puid|g" env/.env.core
        sed -i "s|PGID=1000|PGID=$pgid|g" env/.env.core
        sed -i "s|TZ=Europe/Amsterdam|TZ=$tz|g" env/.env.core
        sed -i "s|DOMAIN=local|DOMAIN=$domain|g" env/.env.core
        sed -i "s|CONFIG_ROOT=/srv/orion-sentinel-core/config|CONFIG_ROOT=$base_dir/config|g" env/.env.core
        sed -i "s|DATA_ROOT=/srv/orion-sentinel-core/data|DATA_ROOT=$base_dir/data|g" env/.env.core
        
        # Generate secrets
        info "Generating Authelia secrets..."
        local jwt_secret=$(openssl rand -hex 32)
        local session_secret=$(openssl rand -hex 32)
        local storage_secret=$(openssl rand -hex 32)
        
        sed -i "s|AUTHELIA_JWT_SECRET=change-me-run-openssl-rand-hex-32|AUTHELIA_JWT_SECRET=$jwt_secret|g" env/.env.core
        sed -i "s|AUTHELIA_SESSION_SECRET=change-me-run-openssl-rand-hex-32|AUTHELIA_SESSION_SECRET=$session_secret|g" env/.env.core
        sed -i "s|AUTHELIA_STORAGE_ENCRYPTION_KEY=change-me-run-openssl-rand-hex-32|AUTHELIA_STORAGE_ENCRYPTION_KEY=$storage_secret|g" env/.env.core
        
        success "Created env/.env.core with generated secrets"
    else
        warn "env/.env.core already exists, skipping"
    fi
    
    # Ask about other profiles
    echo ""
    if confirm "Do you want to set up the Media stack (Jellyfin, Sonarr, Radarr, etc.)?"; then
        if [ ! -f "env/.env.media" ]; then
            info "Creating env/.env.media..."
            cp env/.env.media.example env/.env.media
            sed -i "s|PUID=1000|PUID=$puid|g" env/.env.media
            sed -i "s|PGID=1000|PGID=$pgid|g" env/.env.media
            sed -i "s|TZ=Europe/Amsterdam|TZ=$tz|g" env/.env.media
            sed -i "s|/srv/orion-sentinel-core|$base_dir|g" env/.env.media
            success "Created env/.env.media"
            warn "Remember to add your VPN credentials to env/.env.media"
        else
            warn "env/.env.media already exists, skipping"
        fi
    fi
    
    echo ""
    if confirm "Do you want to set up Monitoring (Prometheus, Grafana, Loki)?"; then
        if [ ! -f "env/.env.monitoring" ]; then
            info "Creating env/.env.monitoring..."
            cp env/.env.monitoring.example env/.env.monitoring
            sed -i "s|PUID=1000|PUID=$puid|g" env/.env.monitoring
            sed -i "s|PGID=1000|PGID=$pgid|g" env/.env.monitoring
            sed -i "s|TZ=Europe/Amsterdam|TZ=$tz|g" env/.env.monitoring
            sed -i "s|/srv/orion-sentinel-core|$base_dir|g" env/.env.monitoring
            
            # Generate Grafana password
            local grafana_pass=$(openssl rand -base64 16)
            sed -i "s|GRAFANA_ADMIN_PASSWORD=changeme|GRAFANA_ADMIN_PASSWORD=$grafana_pass|g" env/.env.monitoring
            success "Created env/.env.monitoring (Grafana password: $grafana_pass)"
        else
            warn "env/.env.monitoring already exists, skipping"
        fi
    fi
    
    echo ""
    if confirm "Do you want to set up Cloud services (Nextcloud)?"; then
        if [ ! -f "env/.env.cloud" ]; then
            info "Creating env/.env.cloud..."
            cp env/.env.cloud.example env/.env.cloud
            sed -i "s|PUID=1000|PUID=$puid|g" env/.env.cloud
            sed -i "s|PGID=1000|PGID=$pgid|g" env/.env.cloud
            sed -i "s|TZ=Europe/Amsterdam|TZ=$tz|g" env/.env.cloud
            sed -i "s|/srv/orion-sentinel-core|$base_dir|g" env/.env.cloud
            
            # Generate passwords
            local nc_pass=$(openssl rand -base64 16)
            local db_pass=$(openssl rand -base64 16)
            sed -i "s|NEXTCLOUD_ADMIN_PASSWORD=changeme|NEXTCLOUD_ADMIN_PASSWORD=$nc_pass|g" env/.env.cloud
            sed -i "s|POSTGRES_PASSWORD=changeme|POSTGRES_PASSWORD=$db_pass|g" env/.env.cloud
            success "Created env/.env.cloud"
            info "Nextcloud admin password: $nc_pass"
        else
            warn "env/.env.cloud already exists, skipping"
        fi
    fi
    
    # Always create search and home automation (they're simple)
    for env_file in search home-automation maintenance; do
        if [ ! -f "env/.env.$env_file" ]; then
            info "Creating env/.env.$env_file..."
            cp "env/.env.$env_file.example" "env/.env.$env_file"
            sed -i "s|PUID=1000|PUID=$puid|g" "env/.env.$env_file"
            sed -i "s|PGID=1000|PGID=$pgid|g" "env/.env.$env_file"
            sed -i "s|TZ=Europe/Amsterdam|TZ=$tz|g" "env/.env.$env_file"
            sed -i "s|/srv/orion-sentinel-core|$base_dir|g" "env/.env.$env_file"
            
            # Generate SearXNG secret
            if [ "$env_file" = "search" ]; then
                local searx_secret=$(openssl rand -hex 32)
                sed -i "s|SEARXNG_SECRET_KEY=change-me-run-openssl-rand-hex-32|SEARXNG_SECRET_KEY=$searx_secret|g" "env/.env.$env_file"
            fi
            
            success "Created env/.env.$env_file"
        fi
    done
    
    echo ""
    success "Environment files configured successfully"
}

# Validate configuration
validate_config() {
    print_header "Validating Configuration"
    
    local issues=0
    
    # Check env files exist
    if [ ! -f "env/.env.core" ]; then
        error "Missing env/.env.core"
        ((issues++))
    fi
    
    # Check for placeholder secrets in core env
    if [ -f "env/.env.core" ]; then
        if grep -q "change-me" env/.env.core; then
            warn "env/.env.core still contains 'change-me' placeholders"
            info "The setup script should have replaced these, please check the file"
            ((issues++))
        else
            success "env/.env.core secrets are configured"
        fi
    fi
    
    # Check directory exists
    local base_dir="${SELECTED_BASE_DIR:-$DEFAULT_BASE_DIR}"
    if [ -d "$base_dir" ]; then
        success "Base directory exists: $base_dir"
    else
        error "Base directory not found: $base_dir"
        ((issues++))
    fi
    
    # Check docker
    if docker ps &> /dev/null; then
        success "Docker daemon is running"
    else
        error "Cannot connect to Docker daemon"
        info "Try: sudo systemctl start docker"
        ((issues++))
    fi
    
    if [ $issues -eq 0 ]; then
        success "All validation checks passed!"
    else
        warn "Found $issues issue(s) - please review and fix before starting services"
    fi
    
    echo ""
}

# Show next steps
show_next_steps() {
    print_header "Setup Complete! 🎉"
    
    cat << 'EOF'
Your Orion Sentinel CoreSrv is ready to launch!

Next Steps:
───────────

1. Review your configuration:
   - Check env/.env.core and other env files
   - Update VPN credentials in env/.env.media (if using media stack)
   - Review docs/SETUP-CoreSrv.md for detailed configuration

2. Start the core services:
   ./orionctl.sh up-core

   This starts Traefik (reverse proxy) and Authelia (SSO)

3. Access the services:
   - Authelia:  https://auth.local
   - Traefik:   https://traefik.local

4. Start additional services as needed:
   ./orionctl.sh up-media          # Media stack
   ./orionctl.sh up-observability  # Monitoring
   ./orionctl.sh up-full           # Everything

5. Configure services:
   - Set up Authelia users (see core/authelia/users.yml)
   - Configure DNS entries in Pi-hole (if available)
   - Set up media services (Sonarr, Radarr, etc.)

6. Check service status:
   ./orionctl.sh status
   ./orionctl.sh health

Documentation:
──────────────
- Quick Start:    INSTALL.md
- Full Setup:     docs/SETUP-CoreSrv.md
- Architecture:   docs/ARCHITECTURE.md
- Troubleshooting: docs/RUNBOOKS.md

Need Help?
──────────
- Issues: https://github.com/orionsentinel/Orion-Sentinel-CoreSrv/issues
- Docs:   https://github.com/orionsentinel/Orion-Sentinel-CoreSrv/tree/main/docs

EOF
    
    echo -e "${GREEN}${BOLD}Happy self-hosting! 🚀${NC}\n"
}

# Main setup flow
main() {
    clear
    
    cat << 'EOF'
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║        ██████╗ ██████╗ ██╗ ██████╗ ███╗   ██╗              ║
║       ██╔═══██╗██╔══██╗██║██╔═══██╗████╗  ██║              ║
║       ██║   ██║██████╔╝██║██║   ██║██╔██╗ ██║              ║
║       ██║   ██║██╔══██╗██║██║   ██║██║╚██╗██║              ║
║       ╚██████╔╝██║  ██║██║╚██████╔╝██║ ╚████║              ║
║        ╚═════╝ ╚═╝  ╚═╝╚═╝ ╚═════╝ ╚═╝  ╚═══╝              ║
║                                                               ║
║              Sentinel CoreSrv Setup Script                    ║
║                                                               ║
╚═══════════════════════════════════════════════════════════════╝

EOF
    
    info "This script will help you set up Orion Sentinel CoreSrv"
    info "It will create directories, configure environment files, and validate your setup"
    echo ""
    
    if ! confirm "Do you want to continue?"; then
        info "Setup cancelled"
        exit 0
    fi
    
    check_not_root
    check_prerequisites
    
    # Ask what to set up
    local setup_dirs=false
    local setup_env=false
    
    if [ ! -d "$DEFAULT_BASE_DIR" ]; then
        setup_dirs=true
    else
        if confirm "Directory $DEFAULT_BASE_DIR exists. Do you want to set up directories anyway?"; then
            setup_dirs=true
        fi
    fi
    
    if [ ! -f "env/.env.core" ]; then
        setup_env=true
    else
        if confirm "Environment files exist. Do you want to reconfigure them?"; then
            setup_env=true
        fi
    fi
    
    # Run setup steps
    if [ "$setup_dirs" = true ]; then
        create_directories
    fi
    
    if [ "$setup_env" = true ]; then
        setup_env_files
    fi
    
    validate_config
    show_next_steps
}

# Run main function
main "$@"
