#!/usr/bin/env bash
# Orion-Sentinel-DataAICore Setup Script
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
    openssl rand -base64 32 | tr -d "=+/" | cut -c1-32
}

# Generate random secret
generate_secret() {
    openssl rand -hex 32
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
echo "║       Orion-Sentinel-DataAICore Setup Script                  ║"
echo "║       Dell Optiplex - Cloud, Search, and AI Stack             ║"
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
DATA_ROOT="${DATA_ROOT:-/srv/dataaicore}"

info "Data root: $DATA_ROOT"
echo ""

# Create directory structure
info "Creating directory structure..."
ensure_dir "$DATA_ROOT"
ensure_dir "$DATA_ROOT/nextcloud/app"
ensure_dir "$DATA_ROOT/nextcloud/postgres"
ensure_dir "$DATA_ROOT/nextcloud/redis"
ensure_dir "$DATA_ROOT/nextcloud/caddy"
ensure_dir "$DATA_ROOT/search/searxng"
ensure_dir "$DATA_ROOT/search/valkey"
ensure_dir "$DATA_ROOT/search/meilisearch"
ensure_dir "$DATA_ROOT/search/local-search"
ensure_dir "$DATA_ROOT/llm/ollama"
ensure_dir "$DATA_ROOT/llm/open-webui"

echo ""
success "Directory structure created"
echo ""

# Create Docker network
info "Creating Docker network: dataaicore_internal"
if docker network inspect dataaicore_internal &> /dev/null; then
    info "Network dataaicore_internal already exists"
else
    docker network create dataaicore_internal
    success "Network dataaicore_internal created"
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
    
    # Generate passwords and secrets
    NEXTCLOUD_ADMIN_PASSWORD=$(generate_password)
    NEXTCLOUD_DB_PASSWORD=$(generate_password)
    NEXTCLOUD_REDIS_PASSWORD=$(generate_password)
    SEARXNG_SECRET=$(generate_secret)
    MEILISEARCH_MASTER_KEY=$(generate_secret)
    
    # Copy example and replace placeholders
    cp "$ENV_EXAMPLE" "$ENV_FILE"
    
    # Replace passwords in .env
    if [[ "$OSTYPE" == "darwin"* ]]; then
        # macOS
        sed -i '' "s/NEXTCLOUD_ADMIN_PASSWORD=CHANGE_ME_GENERATED_BY_SETUP/NEXTCLOUD_ADMIN_PASSWORD=$NEXTCLOUD_ADMIN_PASSWORD/" "$ENV_FILE"
        sed -i '' "s/NEXTCLOUD_DB_PASSWORD=CHANGE_ME_GENERATED_BY_SETUP/NEXTCLOUD_DB_PASSWORD=$NEXTCLOUD_DB_PASSWORD/" "$ENV_FILE"
        sed -i '' "s/NEXTCLOUD_REDIS_PASSWORD=CHANGE_ME_GENERATED_BY_SETUP/NEXTCLOUD_REDIS_PASSWORD=$NEXTCLOUD_REDIS_PASSWORD/" "$ENV_FILE"
        sed -i '' "s/SEARXNG_SECRET=CHANGE_ME_GENERATED_BY_SETUP/SEARXNG_SECRET=$SEARXNG_SECRET/" "$ENV_FILE"
        sed -i '' "s/MEILISEARCH_MASTER_KEY=CHANGE_ME_GENERATED_BY_SETUP/MEILISEARCH_MASTER_KEY=$MEILISEARCH_MASTER_KEY/" "$ENV_FILE"
    else
        # Linux
        sed -i "s/NEXTCLOUD_ADMIN_PASSWORD=CHANGE_ME_GENERATED_BY_SETUP/NEXTCLOUD_ADMIN_PASSWORD=$NEXTCLOUD_ADMIN_PASSWORD/" "$ENV_FILE"
        sed -i "s/NEXTCLOUD_DB_PASSWORD=CHANGE_ME_GENERATED_BY_SETUP/NEXTCLOUD_DB_PASSWORD=$NEXTCLOUD_DB_PASSWORD/" "$ENV_FILE"
        sed -i "s/NEXTCLOUD_REDIS_PASSWORD=CHANGE_ME_GENERATED_BY_SETUP/NEXTCLOUD_REDIS_PASSWORD=$NEXTCLOUD_REDIS_PASSWORD/" "$ENV_FILE"
        sed -i "s/SEARXNG_SECRET=CHANGE_ME_GENERATED_BY_SETUP/SEARXNG_SECRET=$SEARXNG_SECRET/" "$ENV_FILE"
        sed -i "s/MEILISEARCH_MASTER_KEY=CHANGE_ME_GENERATED_BY_SETUP/MEILISEARCH_MASTER_KEY=$MEILISEARCH_MASTER_KEY/" "$ENV_FILE"
    fi
    
    success ".env file created with generated secrets"
    info "Edit .env to customize settings: nano .env"
fi
echo ""

# Create Caddy configuration for public Nextcloud
CADDY_CONF="$DATA_ROOT/nextcloud/caddy/Caddyfile"
if [ ! -f "$CADDY_CONF" ]; then
    info "Creating Caddy configuration for public Nextcloud..."
    cat > "$CADDY_CONF" << 'EOF'
# Caddy configuration for public Nextcloud access
# ONLY routes cloud.{$ORION_DOMAIN} to Nextcloud
# Does NOT route any other services

cloud.{$ORION_DOMAIN} {
    # Reverse proxy to Nextcloud
    reverse_proxy nextcloud:80 {
        # Headers for Nextcloud behind proxy
        header_up X-Forwarded-Proto https
        header_up X-Real-IP {remote_host}
        header_up X-Forwarded-For {remote_host}
        header_up X-Forwarded-Host {host}
    }

    # Security headers
    header {
        Strict-Transport-Security "max-age=31536000; includeSubDomains; preload"
        X-Content-Type-Options "nosniff"
        X-Frame-Options "SAMEORIGIN"
        X-XSS-Protection "1; mode=block"
        Referrer-Policy "no-referrer-when-downgrade"
    }

    # Logging
    log {
        output file /data/access.log
        format json
    }

    # Automatic HTTPS via Let's Encrypt
    # Caddy handles this automatically
}

# Explicitly disable all other domains/services
# This ensures ONLY Nextcloud is exposed publicly
EOF
    success "Caddy configuration created"
    warn "Edit ORION_DOMAIN in .env before enabling public-nextcloud profile"
else
    info "Caddy configuration already exists"
fi
echo ""

# Create SearXNG settings template
SEARXNG_SETTINGS="$DATA_ROOT/search/searxng/settings.yml"
if [ ! -f "$SEARXNG_SETTINGS" ]; then
    info "Creating SearXNG settings template..."
    cat > "$SEARXNG_SETTINGS" << 'EOF'
# SearXNG settings for Orion-Sentinel-DataAICore

use_default_settings: true

general:
  instance_name: "Orion Search"
  privacypolicy_url: false
  donation_url: false
  contact_url: false
  enable_metrics: false

search:
  safe_search: 0
  autocomplete: "google"
  default_lang: "en"
  formats:
    - html
    - json

server:
  secret_key: "__SEARXNG_SECRET__"
  limiter: true
  image_proxy: true
  method: "GET"

redis:
  url: redis://valkey:6379/0

ui:
  static_use_hash: true
  default_theme: simple
  theme_args:
    simple_style: dark

engines:
  # Add local Meilisearch engine for indexed documents
  - name: local
    engine: meilisearch
    shortcut: local
    base_url: http://meilisearch:7700
    index: local_documents
    enable_http: true
EOF
    success "SearXNG settings template created"
else
    info "SearXNG settings already exists"
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
success "DataAICore is ready to deploy!"
echo ""
info "Next steps:"
echo "  1. Review configuration: nano .env"
echo "  2. Start Nextcloud: ./scripts/orionctl.sh up nextcloud"
echo "  3. Access at: http://<OPTIPLEX_IP>:8080"
echo ""
info "Optional profiles:"
echo "  - Search:    ./scripts/orionctl.sh up search"
echo "  - LLM:       ./scripts/orionctl.sh up llm"
echo "  - All:       ./scripts/orionctl.sh up nextcloud search llm"
echo ""
info "For complete installation guide, see INSTALL.md"
echo ""
