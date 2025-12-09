# ============================================================================
# Orion-Sentinel-CoreSrv Makefile
# ============================================================================
#
# Simple, user-friendly commands for managing the Orion Sentinel stack.
# Based on navilg/media-stack patterns for ease of use.
#
# Quick Start:
#   make setup          # Run initial setup
#   make up-core        # Start core media services
#   make up-traefik     # Start Traefik + Authelia
#   make up-full        # Start everything
#   make down           # Stop all services
#   make logs           # View logs
#   make status         # Check service status
#
# ============================================================================

.PHONY: help setup validate up-core up-media up-traefik up-gateway up-observability up-monitoring up-home-automation up-homeauto up-extras up-all up-full down stop restart logs status ps health pull clean backup

# Default target
.DEFAULT_GOAL := help

# ============================================================================
# HELP
# ============================================================================

help: ## Show this help message
	@echo ""
	@echo "╔════════════════════════════════════════════════════════════════════╗"
	@echo "║         Orion-Sentinel-CoreSrv - Production Home Lab Stack        ║"
	@echo "╚════════════════════════════════════════════════════════════════════╝"
	@echo ""
	@echo "Setup Commands:"
	@echo "  make setup          - Run initial setup (create dirs, copy env files)"
	@echo "  make validate       - Validate configuration"
	@echo "  make bootstrap      - Bootstrap services (run after setup)"
	@echo ""
	@echo "Deployment Commands:"
	@echo "  make up-core        - Start core media services (Jellyfin, *arr, qBit)"
	@echo "  make up-media       - Alias for up-core"
	@echo "  make up-traefik     - Start Traefik reverse proxy + Authelia SSO"
	@echo "  make up-gateway     - Alias for up-traefik"
	@echo "  make up-observability - Start monitoring stack (Prometheus, Grafana, Loki)"
	@echo "  make up-monitoring  - Alias for up-observability"
	@echo "  make up-home-automation - Start home automation (Home Assistant, etc.)"
	@echo "  make up-homeauto    - Alias for up-home-automation"
	@echo "  make up-extras      - Start additional services (Homepage, SearXNG)"
	@echo "  make up-full        - Start ALL services"
	@echo "  make up-all         - Alias for up-full (standardized command)"
	@echo ""
	@echo "Management Commands:"
	@echo "  make down           - Stop all services"
	@echo "  make stop           - Stop all services (keep containers)"
	@echo "  make restart        - Restart all services"
	@echo "  make restart SVC=<name> - Restart specific service"
	@echo "  make logs           - Follow all logs"
	@echo "  make logs SVC=<name> - Follow logs for specific service"
	@echo "  make status         - Show service status"
	@echo "  make ps             - List containers"
	@echo "  make health         - Check service health"
	@echo ""
	@echo "Maintenance Commands:"
	@echo "  make pull           - Pull latest images"
	@echo "  make backup         - Run backup script"
	@echo "  make clean          - Remove stopped containers and unused images"
	@echo ""
	@echo "Examples:"
	@echo "  make up-core                    # Start media stack only"
	@echo "  make up-core up-traefik         # Start media + reverse proxy"
	@echo "  make logs SVC=jellyfin          # View Jellyfin logs"
	@echo "  make restart SVC=sonarr         # Restart Sonarr"
	@echo ""

# ============================================================================
# SETUP & VALIDATION
# ============================================================================

setup: ## Run initial setup script
	@echo "🚀 Running setup script..."
	@./scripts/setup.sh

validate: ## Validate configuration files
	@echo "✓ Validating configuration..."
	@./scripts/orionctl.sh validate || true

bootstrap: ## Bootstrap services (Grafana, etc.)
	@echo "🔧 Bootstrapping services..."
	@if [ -f scripts/bootstrap-coresrv.sh ]; then \
		./scripts/bootstrap-coresrv.sh; \
	else \
		echo "⚠️  bootstrap-coresrv.sh not found, skipping..."; \
	fi

# ============================================================================
# DEPLOYMENT COMMANDS (Using modular compose files)
# ============================================================================

up-core: up-media ## Start core media services
up-media: ## Start media stack (Jellyfin, Sonarr, Radarr, qBittorrent, etc.)
	@echo "🎬 Starting media stack..."
	@if [ ! -f env/.env.media ]; then \
		echo "⚠️  env/.env.media not found. Copying from example..."; \
		cp env/.env.media.modular.example env/.env.media; \
	fi
	@docker compose -f compose/docker-compose.media.yml --profile media-core up -d
	@echo "✓ Media stack started"
	@echo ""
	@echo "Access your services:"
	@echo "  Jellyfin:     http://localhost:8096"
	@echo "  qBittorrent:  http://localhost:5080"
	@echo "  Sonarr:       http://localhost:8989"
	@echo "  Radarr:       http://localhost:7878"
	@echo "  Prowlarr:     http://localhost:9696"
	@echo "  Jellyseerr:   http://localhost:5055"

up-traefik: up-gateway ## Start Traefik + Authelia
up-gateway: ## Start gateway (Traefik reverse proxy + Authelia SSO)
	@echo "🌐 Starting gateway (Traefik + Authelia)..."
	@if [ ! -f env/.env.gateway ]; then \
		echo "⚠️  env/.env.gateway not found. Copying from example..."; \
		cp env/.env.gateway.example env/.env.gateway; \
		echo ""; \
		echo "⚠️  WARNING: You MUST edit env/.env.gateway and change the Authelia secrets!"; \
		echo "   Generate secrets with: openssl rand -hex 32"; \
		echo ""; \
	fi
	@docker compose -f compose/docker-compose.gateway.yml up -d
	@echo "✓ Gateway started"

up-observability: up-monitoring ## Start observability stack
up-monitoring: ## Start monitoring (Prometheus, Grafana, Loki, Uptime Kuma)
	@echo "📊 Starting observability stack..."
	@if [ ! -f env/.env.observability ]; then \
		echo "⚠️  env/.env.observability not found. Copying from example..."; \
		cp env/.env.observability.example env/.env.observability; \
	fi
	@docker compose -f compose/docker-compose.observability.yml up -d
	@echo "✓ Observability stack started"

up-home-automation: up-homeauto ## Start home automation
up-homeauto: ## Start home automation (Home Assistant, Zigbee2MQTT, MQTT, Mealie)
	@echo "🏠 Starting home automation stack..."
	@if [ ! -f env/.env.homeauto ]; then \
		echo "⚠️  env/.env.homeauto not found. Copying from example..."; \
		cp env/.env.homeauto.example env/.env.homeauto; \
	fi
	@docker compose -f compose/docker-compose.homeauto.yml up -d
	@echo "✓ Home automation stack started"

up-extras: ## Start additional services (Homepage, SearXNG, etc.)
	@echo "🔧 Starting additional services..."
	@if [ ! -f env/.env.extras ]; then \
		echo "ℹ️  env/.env.extras not found. Using .env defaults..."; \
	fi
	@docker compose -f compose/docker-compose.extras.yml up -d
	@echo "✓ Additional services started"
	@echo ""
	@echo "Access your services:"
	@echo "  Homepage:  http://localhost:3003 or https://homepage.${DOMAIN:-local}"
	@echo "  SearXNG:   http://localhost:8888 or https://search.${DOMAIN:-local}"

up-full: up-all ## Start ALL services (media + gateway + monitoring + home automation)
up-all: ## Alias for up-full (standardized command)
	@echo "🚀 Starting full stack..."
	@$(MAKE) up-media
	@$(MAKE) up-gateway
	@$(MAKE) up-observability
	@$(MAKE) up-homeauto
	@echo ""
	@echo "✓ Full stack started!"
	@echo ""
	@echo "📋 Services running:"
	@$(MAKE) status

# ============================================================================
# MANAGEMENT COMMANDS
# ============================================================================

down: ## Stop all services
	@echo "🛑 Stopping all services..."
	@docker compose -f compose/docker-compose.media.yml down || true
	@docker compose -f compose/docker-compose.gateway.yml down || true
	@docker compose -f compose/docker-compose.observability.yml down || true
	@docker compose -f compose/docker-compose.homeauto.yml down || true
	@docker compose -f compose/docker-compose.extras.yml down || true
	@echo "✓ All services stopped"

stop: ## Stop all services (keep containers)
	@echo "⏸️  Stopping all services (containers preserved)..."
	@docker compose -f compose/docker-compose.media.yml stop || true
	@docker compose -f compose/docker-compose.gateway.yml stop || true
	@docker compose -f compose/docker-compose.observability.yml stop || true
	@docker compose -f compose/docker-compose.homeauto.yml stop || true
	@docker compose -f compose/docker-compose.extras.yml stop || true
	@echo "✓ All services stopped"

restart: ## Restart services (optionally specify SVC=servicename)
ifdef SVC
	@echo "🔄 Restarting $(SVC)..."
	@docker compose -f compose/docker-compose.media.yml restart $(SVC) 2>/dev/null || \
	 docker compose -f compose/docker-compose.gateway.yml restart $(SVC) 2>/dev/null || \
	 docker compose -f compose/docker-compose.observability.yml restart $(SVC) 2>/dev/null || \
	 docker compose -f compose/docker-compose.homeauto.yml restart $(SVC) 2>/dev/null || \
	 docker compose -f compose/docker-compose.extras.yml restart $(SVC) 2>/dev/null || \
	 echo "❌ Service $(SVC) not found"
	@echo "✓ $(SVC) restarted"
else
	@echo "🔄 Restarting all services..."
	@docker compose -f compose/docker-compose.media.yml restart || true
	@docker compose -f compose/docker-compose.gateway.yml restart || true
	@docker compose -f compose/docker-compose.observability.yml restart || true
	@docker compose -f compose/docker-compose.homeauto.yml restart || true
	@docker compose -f compose/docker-compose.extras.yml restart || true
	@echo "✓ All services restarted"
endif

logs: ## Follow logs (optionally specify SVC=servicename)
ifdef SVC
	@echo "📋 Following logs for $(SVC)..."
	@docker compose -f compose/docker-compose.media.yml logs -f $(SVC) 2>/dev/null || \
	 docker compose -f compose/docker-compose.gateway.yml logs -f $(SVC) 2>/dev/null || \
	 docker compose -f compose/docker-compose.observability.yml logs -f $(SVC) 2>/dev/null || \
	 docker compose -f compose/docker-compose.homeauto.yml logs -f $(SVC) 2>/dev/null || \
	 docker compose -f compose/docker-compose.extras.yml logs -f $(SVC) 2>/dev/null || \
	 echo "❌ Service $(SVC) not found"
else
	@echo "📋 Following all logs (Ctrl+C to stop)..."
	@docker compose -f compose/docker-compose.media.yml logs -f 2>/dev/null & \
	 docker compose -f compose/docker-compose.gateway.yml logs -f 2>/dev/null & \
	 docker compose -f compose/docker-compose.observability.yml logs -f 2>/dev/null & \
	 docker compose -f compose/docker-compose.homeauto.yml logs -f 2>/dev/null & \
	 docker compose -f compose/docker-compose.extras.yml logs -f 2>/dev/null & \
	 wait
endif

status: ps ## Show service status
ps: ## List running containers
	@echo "📊 Service Status:"
	@echo ""
	@docker compose -f compose/docker-compose.media.yml ps 2>/dev/null || true
	@docker compose -f compose/docker-compose.gateway.yml ps 2>/dev/null || true
	@docker compose -f compose/docker-compose.observability.yml ps 2>/dev/null || true
	@docker compose -f compose/docker-compose.homeauto.yml ps 2>/dev/null || true
	@docker compose -f compose/docker-compose.extras.yml ps 2>/dev/null || true

health: ## Check service health
	@echo "🏥 Checking service health..."
	@./scripts/orionctl.sh health 2>/dev/null || echo "Using basic health check..."
	@echo ""
	@echo "Container Health:"
	@docker ps --format "table {{.Names}}\t{{.Status}}" | grep -E "orion_|NAME"

# ============================================================================
# MAINTENANCE COMMANDS
# ============================================================================

pull: ## Pull latest images
	@echo "📥 Pulling latest images..."
	@docker compose -f compose/docker-compose.media.yml pull
	@docker compose -f compose/docker-compose.gateway.yml pull
	@docker compose -f compose/docker-compose.observability.yml pull
	@docker compose -f compose/docker-compose.homeauto.yml pull
	@docker compose -f compose/docker-compose.extras.yml pull
	@echo "✓ Images updated"

backup: ## Run backup script
	@echo "💾 Running backup..."
	@if [ -f backup/backup-volumes.sh ]; then \
		sudo ./backup/backup-volumes.sh; \
	elif [ -f scripts/backup.sh ]; then \
		./scripts/backup.sh; \
	else \
		echo "❌ Backup script not found"; \
	fi

clean: ## Remove stopped containers and unused images
	@echo "🧹 Cleaning up..."
	@docker compose -f compose/docker-compose.media.yml down --remove-orphans 2>/dev/null || true
	@docker compose -f compose/docker-compose.gateway.yml down --remove-orphans 2>/dev/null || true
	@docker compose -f compose/docker-compose.observability.yml down --remove-orphans 2>/dev/null || true
	@docker compose -f compose/docker-compose.homeauto.yml down --remove-orphans 2>/dev/null || true
	@docker compose -f compose/docker-compose.extras.yml down --remove-orphans 2>/dev/null || true
	@docker system prune -f
	@echo "✓ Cleanup complete"

# ============================================================================
# SPECIAL TARGETS
# ============================================================================

# Create necessary networks
networks: ## Create Docker networks
	@echo "🌐 Creating Docker networks..."
	@docker network create orion_media_net 2>/dev/null || echo "  orion_media_net already exists"
	@docker network create orion_gateway_net 2>/dev/null || echo "  orion_gateway_net already exists"
	@docker network create orion_backbone_net 2>/dev/null || echo "  orion_backbone_net already exists"
	@docker network create orion_observability_net 2>/dev/null || echo "  orion_observability_net already exists"
	@docker network create orion_homeauto_net 2>/dev/null || echo "  orion_homeauto_net already exists"
	@echo "✓ Networks ready"

# Quick shortcuts for common tasks
quick-media: ## Quick start: media only (no setup checks)
	@docker compose -f compose/docker-compose.media.yml --profile media-core up -d

quick-full: ## Quick start: everything (no setup checks)
	@docker compose -f compose/docker-compose.media.yml --profile media-core up -d
	@docker compose -f compose/docker-compose.gateway.yml up -d
	@docker compose -f compose/docker-compose.observability.yml up -d
	@docker compose -f compose/docker-compose.homeauto.yml up -d

# ============================================================================
# DEVELOPER COMMANDS
# ============================================================================

dev-media: ## Start media stack with logs attached (for development)
	@docker compose -f compose/docker-compose.media.yml --profile media-core up

dev-gateway: ## Start gateway with logs attached (for development)
	@docker compose -f compose/docker-compose.gateway.yml up

# ============================================================================
# NOTES
# ============================================================================
#
# Environment Files:
#   - .env.example          : Master environment template
#   - env/.env.media        : Media stack configuration
#   - env/.env.gateway      : Traefik + Authelia configuration
#   - env/.env.observability: Monitoring configuration
#   - env/.env.homeauto     : Home automation configuration
#
# Compose Files:
#   - compose/docker-compose.media.yml        : Media services
#   - compose/docker-compose.gateway.yml      : Traefik + Authelia
#   - compose/docker-compose.observability.yml: Monitoring
#   - compose/docker-compose.homeauto.yml     : Home automation
#
# For more information, see README.md
#
# ============================================================================
