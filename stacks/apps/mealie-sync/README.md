# Mealie Recipe Sync - Automated Recipe Importing

## Overview

Mealie Recipe Sync is an automated service that periodically imports recipes into your Mealie instance from configured sources. It supports:

- **RSS Feeds** - Import latest recipes from food blogs (standard RSS or with suffix)
- **Index Crawling** - Discover recipes by crawling recipe index pages
- **Hybrid RSS/Crawl** - Try RSS feeds first, fall back to crawling if needed
- **URL Lists** - Curated lists of specific recipe URLs

The service runs continuously with **production-ready features**:

- ✅ **SQLite state tracking** - Never imports the same recipe twice
- ✅ **Rate limiting per domain** - Polite crawling with configurable delays
- ✅ **URL normalization** - Removes tracking parameters and deduplicates URLs
- ✅ **Domain filtering** - Only processes URLs from allowed domains
- ✅ **Dry run mode** - Test configuration without importing
- ✅ **Structured logging** - JSON logs compatible with Loki/Promtail
- ✅ **Retry logic** - Automatic retries for transient failures
- ✅ **Error tracking** - Records failures in database for troubleshooting

## Pre-configured Sources

10 curated recipe sources are **already configured** in `config/recipe_sources.yaml`:

1. **Ottolenghi** - Official recipes (crawl)
2. **The Guardian** - Ottolenghi column (RSS)
3. **The Happy Foodie** - Recipe archive (crawl)
4. **Meera Sodha** - The New Vegan (RSS)
5. **Akis Petretzikis** - Greek recipes (crawl)
6. **RecipeTin Eats** - RSS with crawl fallback
7. **Great British Chefs** - Middle Eastern collection (crawl)
8. **BBC Good Food** - Middle Eastern recipes (crawl)
9. **The Mediterranean Dish** - RSS with crawl fallback
10. **Serious Eats** - Middle Eastern recipes (crawl)

All sources are enabled by default and ready to use!

## Quick Start

### 1. Generate Mealie API Token

First, create an API token in Mealie:

1. Navigate to **Mealie** (https://mealie.orion.lan)
2. Go to **Settings → API Tokens**
3. Click **Create Token**
4. Name it: `Recipe Sync Service`
5. **Copy the token** (shown only once!)

### 2. Configure Environment

```bash
cd stacks/apps/mealie-sync
cp .env.example .env
nano .env  # Add your MEALIE_API_TOKEN
```

**Required:** `MEALIE_API_TOKEN`

### 3. Configure Recipe Sources (Optional)

The service comes with **10 pre-configured sources** ready to use! You can:

**Option A: Use defaults (recommended for first run)**
```bash
# Use pre-configured sources as-is
# Skip this step and go straight to starting the service
```

**Option B: Customize sources**
```bash
# Edit the configuration
cd stacks/apps/mealie-sync
sudo nano config/recipe_sources.yaml
```

See [Configuration](#configuration) section for details on source types.

### 4. Start the Service

```bash
# From repository root
./scripts/orionctl up apps --profile food_sync

# Or using Docker Compose directly
docker compose --profile food_sync up -d
```

### 5. Monitor Imports

Check the logs to see recipe imports in progress:

```bash
docker logs -f orion_mealie_sync
```

You should see output like:
```
Starting Mealie Recipe Sync
✓ Connected to Mealie API
Found 10 entries in RSS feed
Importing recipe from: https://example.com/recipe
✓ Imported: Amazing Chocolate Cake
Sync complete! Imported 5 new recipes
```

## How It Works

### Sync Process

1. **Discover URLs** - Fetches URLs from all enabled sources (RSS, crawling, etc.)
2. **Normalize** - Removes tracking parameters (utm_*, fbclid, etc.) and deduplicates
3. **Filter by Domain** - Only processes URLs from allowed domains
4. **Check State** - Skips URLs already successfully imported (tracked in SQLite)
5. **Rate Limit** - Waits between requests to same domain (default: 2 seconds)
6. **Import** - Uses Mealie's built-in recipe scraper to import each URL
7. **Track Results** - Records success/failure in database
8. **Wait** - Sleeps until next sync interval
9. **Repeat** - Continuous loop

### State Persistence

The service uses **SQLite database** (`/data/state.db`) to track:
- **seen_urls** - All URLs discovered, with domain and timestamp
- **attempts** - Every import attempt (success/failure)
- **imports** - Successfully imported recipes
- **sync_runs** - Statistics for each sync run

This ensures recipes are never imported twice and provides full audit trail.

### Dry Run Mode

Test your configuration safely:

```bash
# Enable dry run in .env
DRY_RUN=true

# Start service
docker compose --profile food_sync up -d

# Watch logs to see what would be imported
docker logs -f orion_mealie_sync
```

**Dry run will:**
- ✅ Discover all URLs from sources
- ✅ Apply filters and normalization
- ✅ Log what would be imported
- ❌ NOT import to Mealie
- ❌ NOT modify state database

## Configuration

### Recipe Sources (`config/recipe_sources.yaml`)

The service comes with 10 pre-configured sources. All sources support:
- `enabled: true/false` - Enable/disable individual sources
- `allow_domains` - List of allowed domains (security feature)

#### Source Types

**1. RSS with Suffix (`rss_suffix`)**

Constructs RSS URL by adding suffix to index URL:

```yaml
- name: "The Guardian — Ottolenghi recipes"
  type: "rss_suffix"
  enabled: true
  index_url: "https://www.theguardian.com/food/series/yotam-ottolenghi-recipes"
  rss_suffix: "/rss"  # Final URL: index_url + rss_suffix
  allow_domains: ["theguardian.com"]
  max_entries: 20  # Number of latest entries to check
```

**2. Index Crawling (`crawl_index`)**

Fetches an index page and extracts recipe links:

```yaml
- name: "Ottolenghi — Official recipes"
  type: "crawl_index"
  enabled: true
  index_url: "https://ottolenghi.co.uk/pages/recipes"
  allow_domains: ["ottolenghi.co.uk"]  # REQUIRED for crawling
  max_pages: 50  # Maximum links to extract
```

**Best for:** Recipe archives, collection pages, category indexes

**3. RSS with Crawl Fallback (`rss_or_crawl`)**

Tries RSS feeds first, falls back to crawling if RSS fails:

```yaml
- name: "RecipeTin Eats"
  type: "rss_or_crawl"
  enabled: true
  rss_url_candidates:  # Try these RSS URLs in order
    - "https://www.recipetineats.com/feed/"
  crawl_fallback_url: "https://www.recipetineats.com/category/vegetarian-recipes/"
  allow_domains: ["recipetineats.com"]
  max_entries: 20  # For RSS
  max_pages: 50    # For crawl fallback
```

**Best for:** Sites where RSS might be unreliable

**4. Standard RSS (`rss`)**

Direct RSS feed URL:

```yaml
- name: "Minimalist Baker"
  type: "rss"
  enabled: true
  rss_url: "https://minimalistbaker.com/feed/"
  allow_domains: ["minimalistbaker.com"]
  max_entries: 10
```

**5. URL Lists (`url_list`)**

Static list of specific URLs:

```yaml
- name: "Family Favorites"
  type: "url_list"
  enabled: true
  urls:
    - "https://www.allrecipes.com/recipe/228823/classic-lasagna/"
    - "https://www.foodnetwork.com/recipes/mac-and-cheese-123"
  allow_domains: ["allrecipes.com", "foodnetwork.com"]  # Optional
```

**Best for:** Specific recipes, themed collections

#### Crawling Best Practices

**Rate Limiting:**
- Default: 2 seconds between requests to same domain
- Configurable via `RATE_LIMIT_SECONDS_PER_DOMAIN`
- Prevents overwhelming recipe sites

**Domain Filtering:**
- `allow_domains` is **required** for crawling sources
- Supports subdomains: `example.com` matches `www.example.com`
- Supports wildcard: `.example.com` matches all subdomains

**URL Normalization:**
- Automatically removes tracking parameters (`utm_*`, `fbclid`, `gclid`)
- Removes URL fragments (`#comments`)
- Deduplicates identical recipes from different sources

### Environment Variables

**`.env` file:**

```bash
# Mealie connection
MEALIE_BASE_URL=http://mealie:9000
MEALIE_API_TOKEN=your-token-here

# Sync behavior
SYNC_INTERVAL_MINUTES=1440         # 24 hours (recommended default)
MAX_NEW_RECIPES_PER_RUN=10         # Limit per sync (conservative)

# Network & rate limiting
REQUEST_TIMEOUT_SECONDS=30         # Timeout for requests
RATE_LIMIT_SECONDS_PER_DOMAIN=2.0  # Min time between requests to same domain
USER_AGENT=Mozilla/5.0...          # User agent for requests

# Operational
DRY_RUN=false                      # Test mode (true = no imports)
JSON_LOGS=false                    # Structured logs for Loki (true = JSON)
```

**Key Variables:**

- `SYNC_INTERVAL_MINUTES`: How often to run sync (default: 1440 = daily)
- `MAX_NEW_RECIPES_PER_RUN`: Safety limit (default: 10)
- `RATE_LIMIT_SECONDS_PER_DOMAIN`: Politeness delay (default: 2.0s)
- `DRY_RUN`: Test configuration without importing (default: false)

## Advanced Usage

### Testing Configuration with Dry Run

Before importing real recipes, test your configuration:

```bash
# 1. Edit .env
cd stacks/apps/mealie-sync
sudo nano .env

# 2. Enable dry run
DRY_RUN=true

# 3. Start service
docker compose --profile food_sync up -d

# 4. Watch logs
docker logs -f orion_mealie_sync

# 5. Review discovered URLs (no imports happen)
# Look for lines like: [DRY RUN] Would import recipe from: ...

# 6. When satisfied, disable dry run
sudo nano .env  # Set DRY_RUN=false
docker compose --profile food_sync restart mealie-sync
```

### Adjusting Sync Frequency

Edit `.env` and restart:

```bash
# Daily sync
MEALIE_SYNC_INTERVAL_MINUTES=1440

# Every 6 hours (default)
MEALIE_SYNC_INTERVAL_MINUTES=360

# Hourly (aggressive - not recommended)
MEALIE_SYNC_INTERVAL_MINUTES=60
```

Restart the service:
```bash
docker compose --profile food_sync restart mealie-sync
```

### Manual Trigger

Force an immediate sync by restarting the container:

```bash
docker restart orion_mealie_sync
```

The sync runs immediately on container start.

## Troubleshooting

### "Cannot connect to Mealie"

**Check Mealie is running:**
```bash
docker ps | grep mealie
curl http://localhost:9000/api/app/about
```

**Verify network:**
```bash
# Check mealie-sync is on orion_apps network
docker network inspect orion_apps

# Service should be able to reach Mealie by container name
docker exec orion_mealie_sync ping -c 2 mealie
```

**Verify API token:**
1. Check token is set in `.env`
2. Verify token is valid in Mealie settings
3. Regenerate token if needed

### "Failed to scrape recipe from URL"

**Possible causes:**
1. **Unsupported site** - Mealie can't scrape all recipe sites
2. **Invalid URL** - URL doesn't point to a recipe page
3. **Site blocking** - Site blocks scrapers or requires JavaScript
4. **Network error** - Temporary connection issue
5. **Rate limiting** - Too many requests to the site

**Solutions:**
- Try the URL manually in Mealie UI first
- Check Mealie's supported sites list
- Increase `RATE_LIMIT_SECONDS_PER_DOMAIN` in .env
- Remove problematic URLs/sources from configuration
- Check logs for specific error messages

### Crawling Issues

**"URL not in allowed domains"**
- Check `allow_domains` in source configuration
- Ensure domain matches exactly (case-insensitive)
- Try adding subdomain wildcard: `.example.com`

**"Timeout fetching URL"**
- Increase `REQUEST_TIMEOUT_SECONDS` in .env (default: 30)
- Site may be slow or temporarily down
- Check network connectivity from container

**"Rate limiting: waiting X seconds"**
- This is normal - respects `RATE_LIMIT_SECONDS_PER_DOMAIN`
- Increase value to be more polite to sites
- Decrease value for faster (but less polite) crawling

### "Failed to scrape recipe from URL"

**Possible causes:**
1. **Unsupported site** - Mealie can't scrape all recipe sites
2. **Invalid URL** - URL doesn't point to a recipe page
3. **Site blocking** - Site blocks scrapers
4. **Network error** - Temporary connection issue

**Solutions:**
- Try the URL manually in Mealie
- Check Mealie's supported sites list
- Remove problematic URLs from sources

### "Recipe already exists"

This is normal - the recipe was previously imported. The sync automatically skips it.

### No New Recipes Imported

**Check logs:**
```bash
docker logs orion_mealie_sync
```

**Common reasons:**
- All URLs already imported
- RSS feeds have no new entries
- `max_entries` or `max_pages` set too low
- Sources disabled (`enabled: false`)

### High Import Volume

If too many recipes are being imported:

1. **Reduce max_entries:**
   ```yaml
   max_entries: 5  # Lower from 10
   ```

2. **Reduce max_recipes_per_run:**
   ```bash
   MEALIE_MAX_RECIPES_PER_RUN=10  # Lower from 20
   ```

3. **Disable aggressive sources:**
   ```yaml
   enabled: false  # Disable sitemap sources
   ```

## Maintenance

### View Import Statistics

```bash
# Check overall stats in logs
docker logs orion_mealie_sync | grep "Total imported"

# Or access SQLite database directly
docker exec orion_mealie_sync sqlite3 /data/state.db \
  "SELECT COUNT(*) as total_imports FROM imports"
```

### View State Database

```bash
# View all imported recipes
docker exec orion_mealie_sync sqlite3 /data/state.db \
  "SELECT url, recipe_name, imported_at FROM imports ORDER BY imported_at DESC LIMIT 10"

# View recent failures
docker exec orion_mealie_sync sqlite3 /data/state.db \
  "SELECT url, attempted_at, error_message FROM attempts WHERE success = 0 ORDER BY attempted_at DESC LIMIT 10"

# View sync run history
docker exec orion_mealie_sync sqlite3 /data/state.db \
  "SELECT * FROM sync_runs ORDER BY started_at DESC LIMIT 5"
```

### Reset Import History

⚠️ **Warning:** This will mark all recipes as new and may cause re-imports!

```bash
# Stop service
docker compose --profile food_sync down

# Delete state database
sudo rm /srv/orion/internal/appdata/mealie-sync/data/state.db

# Restart service (creates fresh database)
docker compose --profile food_sync up -d
```

**Note:** Mealie will reject duplicate recipes (HTTP 409), so re-imports are safe but logged as failures.

### Check Logs

```bash
# Follow logs live
docker logs -f orion_mealie_sync

# Last 100 lines
docker logs --tail 100 orion_mealie_sync

# Since specific time
docker logs --since 1h orion_mealie_sync
```

### Update Configuration

1. Edit `config/recipe_sources.yaml`:
   ```bash
   cd stacks/apps/mealie-sync
   sudo nano config/recipe_sources.yaml
   ```

2. Restart service to apply changes:
   ```bash
   docker compose --profile food_sync restart mealie-sync
   ```

**Note:** Configuration is read on container start, so restart is required after edits.

## Best Practices

### 1. Start Small

Begin with 1-2 RSS feeds, test the setup, then add more sources gradually.

### 2. Use Reasonable Limits

- `max_entries: 10` for RSS feeds
- `max_pages: 20` for sitemaps
- `max_recipes_per_run: 20` overall limit

### 3. Monitor Initial Imports

Watch logs during first few syncs to ensure recipes import correctly.

### 4. Curate Sources

Regularly review and update your sources. Disable feeds that no longer work or aren't relevant.

### 5. Respect Rate Limits

Don't set sync intervals too aggressively. 6-12 hours is reasonable for most use cases.

### 6. Organize in Mealie

After importing, use Mealie's features to:
- Organize recipes into categories
- Add tags
- Mark favorites
- Rate recipes

## Security Considerations

### API Token Security

- Store API token in `.env` (never commit to git)
- Use a dedicated token for this service
- Rotate token periodically
- Revoke unused tokens in Mealie

### Network Isolation

- Service runs on internal `orion_apps` network
- No external ports exposed
- Cannot be accessed from outside

### Resource Limits

- Built-in rate limiting (delay between imports)
- Max recipes per run limit
- Runs as non-root user in container

## Resources

- **Mealie Documentation:** https://docs.mealie.io/
- **Mealie API:** https://docs.mealie.io/api/
- **Recipe Scraping:** https://docs.mealie.io/documentation/getting-started/introduction/

---

**Stack Profile:** `food_sync`  
**Container:** `orion_mealie_sync`  
**Data Location:** `/srv/orion/internal/appdata/mealie-sync/`  
**Maintained by:** Orion Home Lab Team
