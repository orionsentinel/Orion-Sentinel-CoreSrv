# Repository Split - Read This First!

This repository has been reorganized into two independent deployment targets:

## 🏠 Orion-Sentinel-HomeCore (Raspberry Pi 5)

**Location:** `./Orion-Sentinel-HomeCore/`

Home automation and light apps stack for Raspberry Pi 5.

**What's included:**
- Home Assistant (smart home hub)
- Mosquitto MQTT broker (optional)
- Zigbee2MQTT (optional)
- Node-RED (optional)
- ESPHome (optional)
- Mealie recipe management (optional)

**Quick start:**
```bash
cd Orion-Sentinel-HomeCore
./scripts/setup.sh
./scripts/orionctl.sh up mqtt zigbee
```

**Access:** `http://<PI_IP>:8123`

**Documentation:** [Orion-Sentinel-HomeCore/README.md](Orion-Sentinel-HomeCore/README.md)

---

## ☁️ Orion-Sentinel-DataAICore (Dell Optiplex)

**Location:** `./Orion-Sentinel-DataAICore/`

Cloud storage, intelligent search, and local AI stack for Dell Optiplex.

**What's included:**
- Nextcloud (self-hosted cloud)
- SearXNG + local document indexing
- Meilisearch + Apache Tika
- Ollama + Open WebUI (local AI)
- Optional Caddy (for public Nextcloud)

**Quick start:**
```bash
cd Orion-Sentinel-DataAICore
./scripts/setup.sh
./scripts/orionctl.sh up nextcloud search llm
```

**Access:**
- Nextcloud: `http://<OPTIPLEX_IP>:8080`
- SearXNG: `http://<OPTIPLEX_IP>:8888`
- Open WebUI: `http://<OPTIPLEX_IP>:3000`

**Documentation:** [Orion-Sentinel-DataAICore/README.md](Orion-Sentinel-DataAICore/README.md)

---

## 🔄 Migrating from Old Setup

If you're upgrading from the previous monolithic setup, see [MIGRATION.md](MIGRATION.md) for detailed migration instructions.

---

## Why Split?

**Separation of Concerns:**
- Home automation isolated on always-on Pi 5
- Data/AI services on more powerful Optiplex
- Failures in one don't affect the other

**Better Resource Utilization:**
- Pi 5 optimized for low-power always-on services
- Optiplex handles heavy workloads (Nextcloud, AI)
- Each system independently tunable

**Simpler Architecture:**
- No complex reverse proxy for local-only services
- Optional public exposure only where needed (Nextcloud)
- Easier to understand and maintain

**Default Security Posture:**
- All services LOCAL ONLY by default
- No public exposure except when explicitly enabled
- Simple, secure, and predictable

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                   SPLIT ARCHITECTURE                            │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  Raspberry Pi 5 (HomeCore)           Dell Optiplex (DataAICore)│
│  ┌──────────────────────┐            ┌──────────────────────┐  │
│  │                      │            │                      │  │
│  │  Home Assistant      │            │  Nextcloud           │  │
│  │  MQTT Broker         │            │  SearXNG             │  │
│  │  Zigbee Gateway      │            │  Meilisearch         │  │
│  │  Node-RED            │            │  Ollama + OpenWebUI  │  │
│  │  Mealie              │            │  [Caddy Proxy]       │  │
│  │                      │            │                      │  │
│  └──────────────────────┘            └──────────────────────┘  │
│         │                                     │                │
│         └─────────── LAN Only ────────────────┘                │
│                                                                 │
│  Optional: Public Nextcloud via Caddy (443 → Optiplex)        │
│                                                                 │
└─────────────────────────────────────────────────────────────────┘
```

---

## Quick Navigation

| Resource | Location |
|----------|----------|
| **HomeCore README** | [Orion-Sentinel-HomeCore/README.md](Orion-Sentinel-HomeCore/README.md) |
| **HomeCore Installation** | [Orion-Sentinel-HomeCore/INSTALL.md](Orion-Sentinel-HomeCore/INSTALL.md) |
| **DataAICore README** | [Orion-Sentinel-DataAICore/README.md](Orion-Sentinel-DataAICore/README.md) |
| **DataAICore Installation** | [Orion-Sentinel-DataAICore/INSTALL.md](Orion-Sentinel-DataAICore/INSTALL.md) |
| **Migration Guide** | [MIGRATION.md](MIGRATION.md) |

---

## Old Monolithic Setup (Deprecated)

The previous monolithic setup files remain in the repository root for reference:
- `compose.yaml` - Old root compose file
- `stacks/` - Old stack definitions
- `scripts/` - Old scripts

**These are deprecated and should not be used for new deployments.**

For new deployments, use the split architecture in:
- `Orion-Sentinel-HomeCore/`
- `Orion-Sentinel-DataAICore/`

---

## Support

For issues or questions:
- **HomeCore:** Open issue with `[HomeCore]` prefix
- **DataAICore:** Open issue with `[DataAICore]` prefix
- **Migration:** Open issue with `[Migration]` prefix

GitHub Issues: https://github.com/orionsentinel/Orion-Sentinel-CoreSrv/issues

---

**Last Updated:** 2025-01-20  
**Repository:** https://github.com/orionsentinel/Orion-Sentinel-CoreSrv
