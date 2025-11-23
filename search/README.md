# Search: SearXNG - Privacy-Respecting Metasearch

## Overview

SearXNG is a free, privacy-respecting metasearch engine that aggregates results from multiple search engines without tracking users.

## What Lives Here

```
search/
├── searxng/
│   └── settings.yml     # SearXNG configuration (to be created)
└── README.md            # This file
```

## Service

### SearXNG

**Purpose:** Privacy-focused metasearch engine

**Key Features:**
- Aggregates results from 70+ search engines
- No user tracking or profiling
- No ads
- Highly configurable
- Self-hosted (complete privacy control)
- Built-in image proxy (prevents tracking from result images)

**Access:**
- Web UI: `https://search.local` (protected by Authelia by default)

**Supported Engines:**
- General: Google, Bing, DuckDuckGo, Brave, Qwant
- Images: Google Images, Bing Images, Flickr
- Videos: YouTube, Dailymotion, Vimeo
- News: Google News, Bing News
- Maps: OpenStreetMap, Google Maps
- Science: arXiv, PubMed, Semantic Scholar
- IT: GitHub, Stack Overflow, Docker Hub
- Files: Archive.org, Wikimedia Commons
- And many more...

## Initial Setup

### 1. Create SearXNG Configuration

Create `search/searxng/settings.yml`:

```yaml
# SearXNG Configuration
# See: https://docs.searxng.org/admin/settings/index.html

general:
  instance_name: "Orion Search"
  privacypolicy_url: false
  donation_url: false
  contact_url: false
  enable_metrics: false

server:
  secret_key: "REPLACE_WITH_SECRET_FROM_ENV"  # Use ${SEARXNG_SECRET_KEY}
  limiter: false  # Enable if you want rate limiting
  image_proxy: true  # Prevent tracking via images

search:
  safe_search: 0  # 0=off, 1=moderate, 2=strict
  autocomplete: "google"  # or duckduckgo, startpage, etc.
  default_lang: "en"
  formats:
    - html
    - json

ui:
  static_use_hash: true
  default_locale: "en"
  theme_args:
    simple_style: auto  # auto, light, dark

# Enable specific search engines
engines:
  - name: google
    engine: google
    shortcut: g
    
  - name: duckduckgo
    engine: duckduckgo
    shortcut: ddg
    
  - name: brave
    engine: brave
    shortcut: br
    
  - name: wikipedia
    engine: wikipedia
    shortcut: wp
    
  - name: github
    engine: github
    shortcut: gh
    
  - name: stack overflow
    engine: stackoverflow
    shortcut: so
    
  - name: youtube
    engine: youtube
    shortcut: yt
    disabled: false
    
  # Add more engines as needed
  # See full list: https://docs.searxng.org/admin/engines/configured_engines.html
```

### 2. Configure Environment

Edit `.env.search`:

```bash
# Generate secret key
SEARXNG_SECRET_KEY=$(openssl rand -hex 32)

# Base URL
SEARXNG_BASE_URL=https://search.local

# Instance name
SEARXNG_INSTANCE_NAME="Orion Search"
```

### 3. Start Service

```bash
docker compose --profile search up -d
```

### 4. Access SearXNG

Navigate to `https://search.local` and authenticate via Authelia.

## Configuration

### Search Engines

Enable/disable specific engines in `settings.yml`:

```yaml
engines:
  - name: google
    engine: google
    disabled: false  # Set to true to disable
    
  - name: bing
    engine: bing
    disabled: true  # Disabled by default
```

### Privacy Settings

**Image Proxy:**
```yaml
server:
  image_proxy: true  # Prevents tracking via images
```

**Safe Search:**
```yaml
search:
  safe_search: 0  # 0=off, 1=moderate, 2=strict
```

**Autocomplete:**
```yaml
search:
  autocomplete: "google"  # or false to disable
```

### UI Customization

**Theme:**
```yaml
ui:
  theme_args:
    simple_style: auto  # auto, light, dark
```

**Default Search Categories:**

You can set which categories are searched by default:

```yaml
categories_as_tabs:
  general:
  images:
  videos:
  news:
  map:
  music:
  it:
  science:
  files:
```

### Rate Limiting (Optional)

To prevent abuse if exposed to internet:

```yaml
server:
  limiter: true
  
outgoing:
  request_timeout: 3.0  # seconds
  max_request_timeout: 10.0
```

## Usage Tips

### Search Shortcuts

Use `!` prefix for search shortcuts:

- `!g query` - Search with Google
- `!ddg query` - Search with DuckDuckGo
- `!gh query` - Search GitHub
- `!so query` - Search Stack Overflow
- `!yt query` - Search YouTube
- `!wp query` - Search Wikipedia

### Search Categories

Use tabs at top of results or append to URL:

- General: `https://search.local/search?q=query&categories=general`
- Images: `?categories=images`
- Videos: `?categories=videos`
- News: `?categories=news`
- Maps: `?categories=map`

### Advanced Query Syntax

**Exact phrase:**
```
"exact phrase search"
```

**Exclude terms:**
```
query -excluded
```

**Site-specific search:**
```
site:github.com docker
```

## Privacy Features

### What SearXNG Does NOT Track

- No search history
- No user profiles
- No cookies (except session cookie)
- No analytics or telemetry
- No ads
- No tracking parameters in outgoing requests

### What SearXNG Anonymizes

- Your IP address (not sent to search engines)
- Your browser fingerprint (generic user agent)
- Referer headers (stripped)

### Additional Privacy

**Behind Authelia SSO:**
- Only authenticated users can access
- Centralized user management
- Additional layer of access control

**Optional: Disable Authelia for Family**

To allow family members to search without login, add alternate Traefik route in `compose.yml`:

```yaml
labels:
  # Protected route (default)
  - "traefik.http.routers.searxng.rule=Host(`search.local`)"
  - "traefik.http.routers.searxng.middlewares=authelia@docker"
  
  # Unprotected route (optional, for LAN-only access)
  # - "traefik.http.routers.searxng-open.rule=Host(`search.local`)"
  # - "traefik.http.routers.searxng-open.priority=1"
```

## Browser Integration

### Set as Default Search Engine

**Firefox:**
1. Visit `https://search.local`
2. Click address bar dropdown
3. "Add SearXNG"

**Chrome:**
1. Settings → Search Engine → Manage search engines
2. Add new search engine:
   - Name: SearXNG
   - Keyword: search
   - URL: `https://search.local/search?q=%s`
3. Click "Make default"

### Search from Address Bar

**Firefox:**
- Add keyword bookmark: `https://search.local/search?q=%s`
- Keyword: `s`
- Usage: `s search query`

**Chrome:**
- Already works with custom search engine above
- Just type in address bar

## Troubleshooting

### Search Results Not Loading

```bash
# Check SearXNG logs
docker compose logs searxng

# Common issues:
# - Engine timeout (increase timeout in settings.yml)
# - Too many engines enabled (disable some)
# - Network issues (check container network)
```

### Slow Search Results

```yaml
# Reduce number of engines in settings.yml
# Increase timeouts
outgoing:
  request_timeout: 5.0  # Increase from default 3.0
```

### Specific Engine Not Working

```bash
# Check engine status
# Visit: https://search.local/stats

# Engines may be blocked by:
# - CAPTCHA challenges
# - IP rate limiting
# - Network blocks
```

### Cannot Access SearXNG

```bash
# Check service status
docker compose ps searxng

# Check Traefik routing
docker compose logs traefik | grep searxng

# Verify Authelia if protected
docker compose logs authelia
```

## Comparison with Other Search Engines

| Feature | SearXNG | Google | DuckDuckGo | Brave Search |
|---------|---------|--------|------------|--------------|
| Privacy | ✅ Excellent | ❌ Poor | ✅ Good | ✅ Good |
| Self-hosted | ✅ Yes | ❌ No | ❌ No | ❌ No |
| Tracking | ❌ None | ✅ Heavy | ❌ None | ❌ Minimal |
| Ads | ❌ None | ✅ Many | ✅ Some | ✅ Some |
| Results Quality | ✅ Good (aggregated) | ✅ Excellent | ✅ Good | ✅ Good |
| Customizable | ✅ Highly | ❌ No | ❌ Limited | ❌ Limited |

## TODO

- [ ] Create `settings.yml` with opinionated engine selection
- [ ] Configure image proxy and privacy settings
- [ ] Test search results quality
- [ ] Add to browser as default search engine
- [ ] Configure autocomplete preferences
- [ ] Set up rate limiting if needed
- [ ] Add SearXNG to Homepage dashboard
- [ ] Document engine selection criteria
- [ ] Test with family members (adjust Authelia if needed)
- [ ] Monitor query performance and tune timeouts

## References

- SearXNG Documentation: https://docs.searxng.org/
- Configured Engines: https://docs.searxng.org/admin/engines/configured_engines.html
- Settings Reference: https://docs.searxng.org/admin/settings/index.html
- SearXNG GitHub: https://github.com/searxng/searxng
- Public Instances: https://searx.space/ (for testing)

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
