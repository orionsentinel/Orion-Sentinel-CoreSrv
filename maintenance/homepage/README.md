# Homepage Dashboard Configuration

This directory contains pre-configured Homepage dashboard files for Orion Sentinel CoreSrv.

## Quick Start

### Option 1: Use Pre-configured Orion Template

```bash
# Copy pre-configured services
cp maintenance/homepage/services-orion.yml /srv/orion-sentinel-core/maintenance/homepage/services.yml

# Copy other templates
cp maintenance/homepage/settings.yml /srv/orion-sentinel-core/maintenance/homepage/
cp maintenance/homepage/bookmarks.yml.example /srv/orion-sentinel-core/maintenance/homepage/bookmarks.yml
cp maintenance/homepage/widgets.yml.example /srv/orion-sentinel-core/maintenance/homepage/widgets.yml

# Restart homepage
make restart SVC=homepage
```

### Option 2: Customize from Examples

```bash
# Copy examples to active config directory
cd /srv/orion-sentinel-core/maintenance/homepage/
cp services.yml.example services.yml
cp bookmarks.yml.example bookmarks.yml
cp widgets.yml.example widgets.yml

# Edit as needed
nano services.yml
```

## Files

- **services-orion.yml** - Pre-configured service links for all Orion services
- **services.yml.example** - Original template
- **settings.yml** - General Homepage settings (title, theme, etc.)
- **bookmarks.yml.example** - Quick links template
- **widgets.yml.example** - System widgets template
- **docker.yml** - Docker socket configuration

## Configuration

### API Keys Required

For Homepage widgets to work, you need to set these API keys in the Homepage container environment:

```yaml
# In compose file or .env
environment:
  - HOMEPAGE_VAR_JELLYFIN_API_KEY=${JELLYFIN_API_KEY}
  - HOMEPAGE_VAR_SONARR_API_KEY=${SONARR_API_KEY}
  - HOMEPAGE_VAR_RADARR_API_KEY=${RADARR_API_KEY}
  - HOMEPAGE_VAR_PROWLARR_API_KEY=${PROWLARR_API_KEY}
  - HOMEPAGE_VAR_JELLYSEERR_API_KEY=${JELLYSEERR_API_KEY}
  - HOMEPAGE_VAR_GRAFANA_USER=${GRAFANA_ADMIN_USER}
  - HOMEPAGE_VAR_GRAFANA_PASSWORD=${GRAFANA_ADMIN_PASSWORD}
```

### How to Get API Keys

**Jellyfin:**
1. Go to Dashboard → API Keys
2. Click "+" to create new key
3. Name it "Homepage"
4. Copy the key

**Sonarr/Radarr/Prowlarr/Bazarr:**
1. Go to Settings → General
2. Find "API Key" section
3. Click "Show" or copy directly

**Jellyseerr:**
1. Go to Settings → General
2. Find "API Key"
3. Copy the key

**Home Assistant:**
1. Go to Profile → Long-Lived Access Tokens
2. Create new token
3. Copy immediately (won't show again)

**Grafana:**
Use your admin username and password from `.env`

## Customization

### Change Theme

Edit `settings.yml`:

```yaml
theme: dark  # or light
color: slate  # or zinc, gray, neutral, stone, red, orange, amber, etc.
```

### Add Custom Bookmarks

Edit `bookmarks.yml`:

```yaml
- Developer:
    - GitHub:
        - href: https://github.com/
          icon: github.png
    - GitLab:
        - href: https://gitlab.com/
          icon: gitlab.png
```

### Add System Widgets

Edit `widgets.yml`:

```yaml
- resources:
    cpu: true
    memory: true
    disk: /
    cputemp: true
    uptime: true

- datetime:
    text_size: xl
    format:
      dateStyle: long
      timeStyle: short
```

## Service Groups

The pre-configured `services-orion.yml` organizes services into groups:

1. **Media** - Jellyfin, streaming
2. **Downloads** - qBittorrent, Prowlarr
3. **Content Management** - Sonarr, Radarr, Bazarr
4. **Cloud & Search** - Nextcloud, SearXNG
5. **Home Automation** - Home Assistant, Zigbee, Mealie
6. **Monitoring** - Grafana, Prometheus, Uptime Kuma
7. **Infrastructure** - Traefik, Authelia, Watchtower
8. **Pi Nodes** - Remote Pi servers (if applicable)

## Widget Types

Homepage supports many widget types. See [Homepage Docs](https://gethomepage.dev/latest/widgets/) for all options.

Common widgets used:
- **Docker** - Container status
- **Jellyfin** - Now playing, library stats
- **Sonarr/Radarr** - Queue, calendar
- **qBittorrent** - Download speeds, active torrents
- **Grafana** - Dashboard links
- **Prometheus** - Metrics summary
- **Home Assistant** - Entity states
- **Uptime Kuma** - Service status

## Troubleshooting

**Widgets not showing data:**
1. Check API keys are set correctly in Homepage container environment
2. Verify services are accessible from Homepage container
3. Check Homepage logs: `make logs SVC=homepage`

**Services not accessible:**
1. Verify Traefik is running
2. Check DNS resolution
3. Verify service is running: `make status`

**Icons not loading:**
1. Homepage auto-downloads icons from walkxcode/dashboard-icons
2. Check internet connectivity from Homepage container
3. Use custom icons: place in `/var/www/html/icons/`

## Advanced Configuration

### Custom CSS

Create `custom.css`:

```css
.service-card {
  background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
}
```

Mount in compose file:

```yaml
volumes:
  - /path/to/custom.css:/app/public/custom.css
```

Reference in `settings.yml`:

```yaml
theme: dark
customCss: /custom.css
```

### Docker Socket Access

Homepage can monitor Docker containers directly.

Already configured in `docker.yml`:

```yaml
my-docker:
  socket: /var/run/docker.sock
```

Requires volume mount:

```yaml
volumes:
  - /var/run/docker.sock:/var/run/docker.sock:ro
```

## Resources

- [Homepage Documentation](https://gethomepage.dev/)
- [Service Widgets](https://gethomepage.dev/latest/widgets/services/)
- [Information Widgets](https://gethomepage.dev/latest/widgets/info/)
- [Icon Repository](https://github.com/walkxcode/dashboard-icons)
- [Community Configs](https://gethomepage.dev/latest/configs/examples/)

## Example Screenshots

Access your homepage at:
- Direct: http://localhost:3000
- Via Traefik: https://home.local

The dashboard provides:
- Quick links to all services
- Real-time service status
- System resource monitoring
- Media library statistics
- Download queue status
- And much more!
