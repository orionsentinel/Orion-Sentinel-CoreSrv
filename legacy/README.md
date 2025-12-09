# Legacy Configuration

This directory contains the original monolithic Docker Compose configuration
that was used before the modular architecture refactoring.

## Files

- `compose.yml.monolithic` - The original all-in-one compose file with all services

## Why Archived?

The original compose file grew too large with many services:
- Difficult to debug and reason about
- Overlapping port configurations
- Many hidden `.env` dependencies causing warnings
- Fragile profile and dependency relationships
- Inconsistent volume and path configurations

## New Architecture

The new modular architecture splits services into independent modules:

```
compose/
├── docker-compose.media.yml        # Media stack (Jellyfin, *arr, etc.)
├── docker-compose.gateway.yml      # Gateway (Traefik, Authelia)
├── docker-compose.observability.yml # Monitoring (Prometheus, Grafana, etc.)
└── docker-compose.homeauto.yml     # Home automation (Home Assistant, etc.)
```

Each module:
- Can be started/stopped independently
- Has its own dedicated network
- Uses clean, self-contained environment files
- Can optionally connect to other modules via the backbone network

## Migration

If you were using the old monolithic stack:

1. Stop the old stack: `docker compose down`
2. Start the new modular media stack: `./scripts/orionctl up media`
3. Gradually add other modules as needed

The new media module is designed to be the stable, primary module that
works independently of all other infrastructure.

## Do Not Use

This legacy compose file is kept for reference only. Do not use it for
new deployments. Use the new modular compose files in `compose/` instead.
