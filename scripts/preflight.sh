#!/usr/bin/env bash
# preflight.sh - Pre-deployment validation script for Orion-Sentinel-CoreSrv
# 
# This script validates your environment before deploying services:
# - Checks Docker and Docker Compose are installed
# - Validates all compose files
# - Checks required external networks exist
# - Checks for obvious port conflicts
#
# Usage: ./scripts/preflight.sh [--verbose]

set -euo pipefail

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

VERBOSE=false
if [[ "${1:-}" == "--verbose" ]] || [[ "${1:-}" == "-v" ]]; then
    VERBOSE=true
fi

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Change to repo root
cd "$REPO_ROOT"

# Counters
CHECKS_PASSED=0
CHECKS_FAILED=0
CHECKS_WARNING=0

# Helper functions
info() {
    echo -e "${BLUE}ℹ${NC} $*"
}

success() {
    echo -e "${GREEN}✓${NC} $*"
    CHECKS_PASSED=$((CHECKS_PASSED + 1))
}

warn() {
    echo -e "${YELLOW}⚠${NC} $*"
    CHECKS_WARNING=$((CHECKS_WARNING + 1))
}

error() {
    echo -e "${RED}✗${NC} $*"
    CHECKS_FAILED=$((CHECKS_FAILED + 1))
}

section() {
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${BLUE}$*${NC}"
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Print header
echo ""
echo -e "${BLUE}╔════════════════════════════════════════╗${NC}"
echo -e "${BLUE}║  Orion-Sentinel-CoreSrv Preflight Check ║${NC}"
echo -e "${BLUE}╚════════════════════════════════════════╝${NC}"

# ============================================================================
# Check 1: Docker and Docker Compose
# ============================================================================
section "1. Docker Environment"

if command -v docker &> /dev/null; then
    DOCKER_VERSION=$(docker --version | cut -d' ' -f3 | tr -d ',')
    success "Docker installed: $DOCKER_VERSION"
else
    error "Docker is not installed"
fi

if docker compose version &> /dev/null; then
    COMPOSE_VERSION=$(docker compose version --short)
    success "Docker Compose installed: $COMPOSE_VERSION"
else
    error "Docker Compose is not installed (or using old docker-compose v1)"
fi

# Check if Docker daemon is running
if docker info &> /dev/null; then
    success "Docker daemon is running"
else
    error "Docker daemon is not running or not accessible"
fi

# ============================================================================
# Check 2: Validate Compose Files
# ============================================================================
section "2. Compose File Validation"

info "Validating all compose files..."

# Find all compose files
COMPOSE_FILES=$(find . -type f \( -name "compose*.yml" -o -name "compose*.yaml" -o -name "docker-compose*.yml" -o -name "docker-compose*.yaml" -o -name "stack.yaml" -o -name "stack.yml" \) | grep -v ".github" | grep -v "node_modules" | sort)

VALIDATED=0
INVALID=0

while IFS= read -r file; do
    if [ -z "$file" ]; then
        continue
    fi
    
    if $VERBOSE; then
        info "  Checking: $file"
    fi
    
    if docker compose -f "$file" config > /dev/null 2>&1; then
        if $VERBOSE; then
            success "  Valid: $file"
        fi
        VALIDATED=$((VALIDATED + 1))
    else
        error "Invalid compose file: $file"
        if $VERBOSE; then
            docker compose -f "$file" config 2>&1 | sed 's/^/    /'
        fi
        INVALID=$((INVALID + 1))
    fi
done <<< "$COMPOSE_FILES"

if [ $INVALID -eq 0 ]; then
    success "All $VALIDATED compose files are valid"
else
    error "$INVALID compose file(s) failed validation"
fi

# ============================================================================
# Check 3: Environment Files
# ============================================================================
section "3. Environment Configuration"

if [ -f .env ]; then
    success ".env file exists"
else
    warn ".env file not found (copy from .env.example)"
fi

# Check for required env vars in .env if it exists
if [ -f .env ]; then
    REQUIRED_VARS=("LOCAL_DOMAIN" "ORION_INTERNAL_ROOT")
    MISSING_VARS=0
    
    for VAR in "${REQUIRED_VARS[@]}"; do
        if grep -q "^${VAR}=" .env; then
            if $VERBOSE; then
                success "  Required variable set: $VAR"
            fi
        else
            warn "  Missing or commented variable: $VAR"
            MISSING_VARS=$((MISSING_VARS + 1))
        fi
    done
    
    if [ $MISSING_VARS -eq 0 ]; then
        success "All required environment variables are set"
    else
        warn "$MISSING_VARS required variable(s) may be missing"
    fi
fi

# ============================================================================
# Check 4: External Networks
# ============================================================================
section "4. Docker Networks"

info "Checking for required external networks..."

REQUIRED_NETWORKS=("orion_proxy")
MISSING_NETWORKS=0

for NETWORK in "${REQUIRED_NETWORKS[@]}"; do
    if docker network inspect "$NETWORK" &> /dev/null; then
        success "Network exists: $NETWORK"
    else
        warn "Network not found: $NETWORK (will be created on first deployment)"
        MISSING_NETWORKS=$((MISSING_NETWORKS + 1))
    fi
done

if [ $MISSING_NETWORKS -eq 0 ]; then
    info "All networks exist (stack is already deployed)"
else
    info "Some networks don't exist yet (normal for first deployment)"
fi

# ============================================================================
# Check 5: Port Conflicts
# ============================================================================
section "5. Port Conflict Check"

info "Checking for obvious port conflicts..."

# Common ports used by this stack
PORTS_TO_CHECK=(80 443 8883 8096 8989 7878 8686 8080 9090 3000 3001)
PORTS_IN_USE=0

for PORT in "${PORTS_TO_CHECK[@]}"; do
    if command -v ss &> /dev/null; then
        if ss -tuln | grep -q ":$PORT "; then
            warn "Port $PORT is already in use"
            PORTS_IN_USE=$((PORTS_IN_USE + 1))
            if $VERBOSE; then
                ss -tuln | grep ":$PORT " | sed 's/^/    /'
            fi
        else
            if $VERBOSE; then
                success "  Port $PORT is available"
            fi
        fi
    else
        warn "Cannot check ports (ss command not found)"
        break
    fi
done

if [ $PORTS_IN_USE -eq 0 ]; then
    success "No obvious port conflicts detected"
elif [ $PORTS_IN_USE -gt 0 ]; then
    warn "$PORTS_IN_USE port(s) are already in use (may cause conflicts)"
fi

# ============================================================================
# Check 6: Storage Paths
# ============================================================================
section "6. Storage Paths"

if [ -f .env ]; then
    # Source .env to get ORION_INTERNAL_ROOT
    set -a
    source .env
    set +a
    
    if [ -n "${ORION_INTERNAL_ROOT:-}" ]; then
        if [ -d "$ORION_INTERNAL_ROOT" ]; then
            success "Internal storage path exists: $ORION_INTERNAL_ROOT"
        else
            warn "Internal storage path does not exist: $ORION_INTERNAL_ROOT (will be created)"
        fi
    else
        info "ORION_INTERNAL_ROOT not set in .env"
    fi
else
    info "Skipping storage path check (.env not found)"
fi

# ============================================================================
# Summary
# ============================================================================
section "Summary"

echo ""
echo -e "${GREEN}✓ Passed:   $CHECKS_PASSED${NC}"
echo -e "${YELLOW}⚠ Warnings: $CHECKS_WARNING${NC}"
echo -e "${RED}✗ Failed:   $CHECKS_FAILED${NC}"
echo ""

if [ $CHECKS_FAILED -gt 0 ]; then
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${RED}Preflight check FAILED${NC}"
    echo -e "${RED}Please fix the errors above before deploying${NC}"
    echo -e "${RED}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 1
elif [ $CHECKS_WARNING -gt 0 ]; then
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${YELLOW}Preflight check completed with warnings${NC}"
    echo -e "${YELLOW}Review warnings above and proceed with caution${NC}"
    echo -e "${YELLOW}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
else
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${GREEN}✅ Preflight check PASSED${NC}"
    echo -e "${GREEN}System is ready for deployment${NC}"
    echo -e "${GREEN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    exit 0
fi
