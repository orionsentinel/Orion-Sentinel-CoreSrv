# Portal Stack - Homepage vs Homarr

## Overview

The Portal stack provides a unified dashboard for accessing all your Orion Sentinel services. You can choose between two dashboard options using Docker Compose profiles:

- **Homepage** (recommended) - Modern, widget-rich dashboard with extensive integrations
- **Homarr** - Alternative dashboard with a different UI/UX approach

Both dashboards access Docker securely through a dedicated socket proxy that provides read-only access with limited permissions.

## Quick Start

### Option 1: Homepage (Default - Recommended)

```bash
# Start Homepage dashboard
./scripts/orionctl up portal --profile portal_homepage

# Or using docker compose directly
docker compose --profile portal_homepage up -d
```

**Access:** https://portal.orion.lan

### Option 2: Homarr (Alternative)

```bash
# Start Homarr dashboard
./scripts/orionctl up portal --profile portal_homearr

# Or using docker compose directly
docker compose --profile portal_homearr up -d
```

**Access:** https://portal.orion.lan

## Why Two Dashboards?

We provide both options because:

1. **Homepage** - Best for users who want:
   - Rich widget integration (stats, charts, API data)
   - Extensive service support out of the box
   - YAML-based configuration
   - Lightweight and fast
   - Active development and large community

2. **Homarr** - Best for users who want:
   - Web-based configuration (no YAML editing)
   - Drag-and-drop interface customization
   - Integrated media request management
   - Calendar and RSS feed widgets
   - More visual/aesthetic focus

**Our recommendation:** Start with Homepage. It's more actively maintained, has better documentation, and provides superior integration with the Orion Sentinel stack.

## Switching Between Dashboards

To switch from one dashboard to another:

```bash
# Stop current dashboard
docker compose --profile portal_homepage down  # or portal_homearr

# Start the other one
docker compose --profile portal_homearr up -d  # or portal_homepage
```

Both use the same URL (portal.orion.lan) so only one should be running at a time.

## Docker Socket Security

Both dashboards need read-only access to Docker to show container status. Instead of mounting `/var/run/docker.sock` directly (which is a security risk), we use a dedicated **docker-socket-proxy** container.

**Security features:**
- Read-only access only
- Limited to specific Docker API endpoints
- No POST/PUT/DELETE operations allowed
- Internal network isolation
- Containers can't manage other containers

**What the dashboards can access:**
- ✅ Container list and status
- ✅ Container stats (CPU, memory, network)
- ✅ Service information
- ✅ Image information
- ❌ Cannot start/stop containers
- ❌ Cannot create/delete containers
- ❌ Cannot access volumes
- ❌ Cannot modify network settings

## Homepage Configuration

Homepage is configured through YAML files located at `/srv/orion/internal/appdata/homepage/`:

**Main configuration files:**
- `settings.yaml` - General settings (theme, layout, title)
- `services.yaml` - Service tiles and widgets
- `widgets.yaml` - Homepage widgets (weather, resources, search)
- `docker.yaml` - Docker integration settings
- `bookmarks.yaml` - Quick links

### Example Configuration

Example configurations are provided in `maintenance/homepage/config/`:

```bash
# Copy example configs (first time setup)
sudo cp -r maintenance/homepage/config/* /srv/orion/internal/appdata/homepage/

# Edit configurations
sudo nano /srv/orion/internal/appdata/homepage/services.yaml
```

### Adding API Keys

Many widgets require API keys for full functionality:

1. **Firefly III:** Options → Profile → OAuth → Create Token
2. **Home Assistant:** Profile → Long-Lived Access Tokens
3. **Jellyfin:** Settings → API Keys
4. **Sonarr/Radarr:** Settings → General → API Key
5. **Grafana:** Use admin credentials or create service account

Edit `services.yaml` and add the keys to the respective widget configurations.

### Widget Types

Homepage supports widgets for:
- Firefly III (account balances, net worth)
- Home Assistant (entity states, automations)
- Nextcloud (storage usage, user count)
- Jellyfin (library stats, recent media)
- Sonarr/Radarr (upcoming, missing, queue)
- Grafana (dashboard screenshots)
- Prometheus (query results)
- Uptime Kuma (status pages)
- And many more...

**Documentation:** https://gethomepage.dev/latest/widgets/

## Homarr Configuration

Homarr is configured through its web interface:

1. Access https://portal.orion.lan
2. Click the edit/settings icon (top right)
3. Drag and drop to add/arrange tiles
4. Click tiles to configure integrations
5. Click "Save" when done

**Features:**
- Drag-and-drop interface builder
- Service integrations (similar to Homepage)
- Media request integration
- Calendar widget
- RSS feeds
- Weather widget
- Custom CSS theming

**Data location:** `/srv/orion/internal/appdata/homearr/`

## Customization

### Homepage Themes

Homepage supports multiple themes. Edit `settings.yaml`:

```yaml
theme: dark  # dark, light, or auto
color: slate  # slate, gray, zinc, neutral, stone, red, orange, amber, yellow, lime, green, emerald, teal, cyan, sky, blue, indigo, violet, purple, fuchsia, pink, rose
```

### Homepage Layout

Control service group layout in `settings.yaml`:

```yaml
layout:
  Finance:
    style: row      # row or column
    columns: 3      # number of columns
```

### Adding New Services

To add a new service to Homepage:

1. Edit `services.yaml`
2. Add service under appropriate group:
   ```yaml
   - Finance:
       - My New Service:
           icon: custom-icon.png
           href: https://myservice.orion.lan
           description: My awesome service
           server: docker-socket-proxy
           container: orion_myservice
   ```
3. Restart Homepage:
   ```bash
   docker compose --profile portal_homepage restart homepage
   ```

## Troubleshooting

### Homepage shows "No services found"

```bash
# Check Homepage logs
docker compose --profile portal_homepage logs homepage

# Verify socket proxy is running
docker compose --profile portal_homepage ps docker-socket-proxy

# Test socket proxy connection
docker compose --profile portal_homepage exec homepage wget -O- http://docker-socket-proxy:2375/containers/json
```

### Homarr configuration not saving

```bash
# Check Homarr logs
docker compose --profile portal_homearr logs homearr

# Verify data directory permissions
ls -la /srv/orion/internal/appdata/homearr/

# Fix permissions if needed
sudo chown -R 1000:1000 /srv/orion/internal/appdata/homearr/
```

### "Cannot connect to Docker socket"

This usually means the socket proxy isn't running:

```bash
# Check proxy status
docker compose --profile portal_homepage ps docker-socket-proxy

# Restart it
docker compose --profile portal_homepage restart docker-socket-proxy
```

### Service widgets not showing data

1. Verify service is running
2. Check API key is correct in configuration
3. Verify URL is accessible from Homepage container
4. Check Homepage logs for error messages

## Resources

### Homepage
- **Documentation:** https://gethomepage.dev
- **GitHub:** https://github.com/gethomepage/homepage
- **Widget Gallery:** https://gethomepage.dev/latest/widgets/
- **Service Integrations:** https://gethomepage.dev/latest/widgets/services/

### Homarr
- **Documentation:** https://homarr.dev/docs/getting-started
- **GitHub:** https://github.com/ajnart/homarr
- **Demo:** https://demo.homarr.dev

### Docker Socket Proxy
- **GitHub:** https://github.com/Tecnativa/docker-socket-proxy
- **Security Best Practices:** https://docs.docker.com/engine/security/

---

**Stack Profiles:**
- `portal_homepage` - Homepage dashboard
- `portal_homearr` - Homarr dashboard

**Both dashboards available at:** https://portal.orion.lan  
**Maintained by:** Orion Home Lab Team
