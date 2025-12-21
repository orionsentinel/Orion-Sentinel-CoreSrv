# Orion-Sentinel-DataAICore

**Data, cloud, and AI services stack for Dell Optiplex**

## Overview

Orion-Sentinel-DataAICore is a production-ready stack for self-hosted cloud storage, intelligent search, and local AI. Designed for Dell Optiplex or similar x86-64 hardware, it provides Nextcloud for file sync, SearXNG for meta-search with local document indexing, and Ollama with Open WebUI for local LLM interactions.

**Default Security Posture:** All services are LOCAL ONLY (LAN access). No public exposure by default.

**Optional Phase 2:** Enable public access for ONLY Nextcloud via dedicated reverse proxy.

## What Runs Here

### Core Services (Profile: nextcloud)
- **Nextcloud** - Self-hosted file sync and collaboration
- **PostgreSQL** - Nextcloud database
- **Redis** - File locking and caching

### Intelligent Search (Profile: search)
- **SearXNG** - Privacy-focused meta-search engine
- **Valkey** - Rate limiting for SearXNG
- **Meilisearch** - Fast search engine for local documents
- **Apache Tika** - Document text extraction
- **Local Indexer** - Custom service to index local documents

### LLM Stack (Profile: llm)
- **Ollama** - Local LLM inference engine
- **Open WebUI** - Chat interface for Ollama (ChatGPT-like UI)

## Quick Start

```bash
# 1. Run setup script (creates directories, generates secrets)
./scripts/setup.sh

# 2. Review and edit configuration
cp env/.env.example .env
nano .env

# 3. Start Nextcloud stack
./scripts/orionctl.sh up nextcloud

# 4. Start search stack
./scripts/orionctl.sh up search

# 5. Start LLM stack
./scripts/orionctl.sh up llm

# 6. Or start everything at once
./scripts/orionctl.sh up nextcloud search llm
```

## Access

**Nextcloud (when nextcloud profile enabled):**
- LAN: `http://<OPTIPLEX_IP>:8080`
- Local network access only by default

**SearXNG (when search profile enabled):**
- LAN: `http://<OPTIPLEX_IP>:8888`
- Local network access only

**Open WebUI (when llm profile enabled):**
- LAN: `http://<OPTIPLEX_IP>:3000`
- Local network access only

**Internal Services (NOT published):**
- Meilisearch: Internal only, accessed via SearXNG
- Valkey: Internal only
- Tika: Internal only
- Ollama API: Internal only (or optionally LAN if needed)

## Hardware Requirements

### Recommended
- **Hardware:** Dell Optiplex 7050/9020 or similar x86-64 PC
- **CPU:** Intel i5/i7 (4+ cores, 8+ threads)
- **RAM:** 16GB minimum, 32GB recommended for LLMs
- **Storage:**
  - 256GB+ SSD for system and databases
  - 1TB+ for Nextcloud data
- **Network:** Gigabit Ethernet

### For LLM Performance
- **CPU-only:** Works but slow. Recommended: small models (3B parameters)
- **Intel iGPU:** Moderate acceleration with oneAPI
- **Dedicated GPU:** Best performance (NVIDIA recommended)

## Profiles

Enable services using Docker Compose profiles:

| Profile | Services | Storage Impact | Use Case |
|---------|----------|----------------|----------|
| `nextcloud` | Nextcloud + Postgres + Redis | High (user data) | Self-hosted cloud |
| `search` | SearXNG + Valkey + Meilisearch + Tika + Indexer | Low | Privacy search + local docs |
| `llm` | Ollama + Open WebUI | High (models) | Local AI assistant |

**Examples:**
```bash
# Nextcloud only
./scripts/orionctl.sh up nextcloud

# Search and LLM
./scripts/orionctl.sh up search llm

# Everything
./scripts/orionctl.sh up nextcloud search llm
```

## Storage Configuration

All data is stored under `${DATA_ROOT}` (default: `/srv/dataaicore`):

```
/srv/dataaicore/
├── nextcloud/
│   ├── app/                # Nextcloud application data
│   ├── postgres/           # Nextcloud database
│   └── redis/              # Redis cache
├── search/
│   ├── searxng/            # SearXNG configuration
│   ├── valkey/             # Valkey data
│   ├── meilisearch/        # Search index
│   └── local-search/       # Drop documents here to index
│       ├── *.pdf
│       ├── *.txt
│       ├── *.md
│       └── *.docx
└── llm/
    ├── ollama/             # LLM models and data
    └── open-webui/         # Open WebUI data
```

## Local Document Indexing (Search Profile)

The local indexer watches `${DATA_ROOT}/search/local-search/` and automatically:
1. Detects new documents (PDF, TXT, MD, DOCX)
2. Extracts text using Apache Tika
3. Indexes content in Meilisearch
4. Makes documents searchable via SearXNG

**To index documents:**
```bash
# Copy files to the watched directory
cp ~/Documents/*.pdf /srv/dataaicore/search/local-search/

# Indexer processes them automatically
# Check logs: ./scripts/orionctl.sh logs local-indexer
```

**To search:**
1. Open SearXNG: `http://<OPTIPLEX_IP>:8888`
2. Search for content from your documents
3. Results appear alongside web results

## LLM Usage

### Pull a Model

After starting the LLM stack, pull a model:

```bash
# Small models for CPU (recommended for Optiplex)
docker exec -it orion_dataaicore_ollama ollama pull llama3.2:3b
docker exec -it orion_dataaicore_ollama ollama pull qwen2.5:3b

# Larger models (if you have 32GB+ RAM or GPU)
docker exec -it orion_dataaicore_ollama ollama pull llama3.2:7b
docker exec -it orion_dataaicore_ollama ollama pull mistral:7b
```

**Model size guide:**
- 3B parameters: ~2GB RAM, fast on CPU
- 7B parameters: ~4GB RAM, slower on CPU
- 13B+ parameters: Requires GPU or very patient waiting

### Use Open WebUI

1. Open browser: `http://<OPTIPLEX_IP>:3000`
2. Create an account (first user is admin)
3. Select your pulled model
4. Start chatting!

## Network Configuration

By default, all services use the `dataaicore_internal` Docker network.

**Published to LAN (local access):**
- Nextcloud: `0.0.0.0:8080` (when nextcloud profile enabled)
- SearXNG: `0.0.0.0:8888` (when search profile enabled)
- Open WebUI: `0.0.0.0:3000` (when llm profile enabled)

**Internal only (NOT published):**
- Meilisearch
- Valkey
- Postgres
- Redis
- Tika
- Ollama (internal by default; can optionally expose to LAN if needed)

No services are exposed to the internet by default.

## Optional: Public Nextcloud (Phase 2)

To expose ONLY Nextcloud to the internet securely:

```bash
# Enable public-nextcloud profile (adds Caddy reverse proxy)
./scripts/orionctl.sh up nextcloud public-nextcloud
```

**Requirements:**
- Domain name (e.g., `cloud.yourdomain.com`)
- DNS record pointing to your public IP
- Router port forwarding: 443 → Optiplex IP
- Trusted domains configured in Nextcloud

**Security notes:**
- Only Nextcloud is exposed publicly
- Other services (search, LLM) remain local-only
- Enable 2FA in Nextcloud settings
- Use strong passwords

See [INSTALL.md](INSTALL.md) for detailed public exposure setup.

## Management Commands

The `orionctl.sh` script provides convenient management:

```bash
# Start services
./scripts/orionctl.sh up [profiles...]       # Start with profiles
./scripts/orionctl.sh down                   # Stop all services
./scripts/orionctl.sh restart                # Restart all services

# View status and logs
./scripts/orionctl.sh ps                     # Show running containers
./scripts/orionctl.sh logs [service]         # View logs
./scripts/orionctl.sh validate               # Validate configuration

# Maintenance
./scripts/orionctl.sh pull                   # Update Docker images
```

## Configuration

See [INSTALL.md](INSTALL.md) for detailed installation and configuration instructions.

## Migrating from Old Setup

If you're migrating from the monolithic Orion-Sentinel-CoreSrv, see [../MIGRATION.md](../MIGRATION.md) for step-by-step migration instructions.

## Troubleshooting

### Nextcloud not accessible
```bash
# Check logs
./scripts/orionctl.sh logs nextcloud

# Check database health
docker exec orion_dataaicore_nextcloud_db pg_isready -U nextcloud
```

### SearXNG search not working
```bash
# Check SearXNG logs
./scripts/orionctl.sh logs searxng

# Check Valkey is running
docker exec orion_dataaicore_valkey redis-cli ping
```

### Local documents not indexing
```bash
# Check indexer logs
./scripts/orionctl.sh logs local-indexer

# Check Tika is running
docker exec orion_dataaicore_tika curl http://localhost:9998/tika
```

### Ollama model loading fails
```bash
# Check available disk space
df -h

# Check Ollama logs
./scripts/orionctl.sh logs ollama

# List pulled models
docker exec orion_dataaicore_ollama ollama list
```

## Documentation

- [INSTALL.md](INSTALL.md) - Complete installation guide
- [../MIGRATION.md](../MIGRATION.md) - Migration from old setup

## Timezone

Default timezone is `Europe/Amsterdam`. Change in `.env`:
```bash
TZ=America/New_York  # or your timezone
```

## Security Notes

- All services run on LAN only by default
- No public exposure except when explicitly enabled (public-nextcloud profile)
- Reverse proxy (Caddy) only routes Nextcloud, never other services
- For remote access to search/LLM, use VPN

## License

MIT License - See [LICENSE](../LICENSE)

---

**Hardware:** Dell Optiplex (x86-64)  
**Purpose:** Cloud storage, intelligent search, local AI  
**Security:** Local-only by default, optional public Nextcloud only
