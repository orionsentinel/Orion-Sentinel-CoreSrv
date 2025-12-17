# Mealie Recipe Sync - Automated Recipe Importing

## Overview

Mealie Recipe Sync is an automated service that periodically imports recipes into your Mealie instance from configured sources. It supports:

- **RSS Feeds** - Import latest recipes from food blogs
- **URL Lists** - Curated lists of specific recipe URLs
- **Sitemaps** - Bulk import from recipe site sitemaps (with filtering)

The service runs continuously, checking for new recipes on a configurable schedule and importing them automatically to your Mealie instance.

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

### 3. Configure Recipe Sources

Copy and edit the sources configuration:

```bash
cp config/sources.yaml.example config/sources.yaml
cp config/settings.yaml.example config/settings.yaml
nano config/sources.yaml  # Add your recipe sources
```

See [Configuration](#configuration) section below for details.

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

1. **Check Sources** - Fetches URLs from all enabled sources
2. **Filter** - Skips already-imported recipes (tracked in `/data/imported_urls.txt`)
3. **Limit** - Imports up to `MAX_NEW_RECIPES_PER_RUN` recipes
4. **Import** - Uses Mealie's built-in recipe scraper to import each URL
5. **Wait** - Sleeps until next sync interval
6. **Repeat** - Continuous loop

### State Persistence

The service tracks:
- **Imported URLs** - `/data/imported_urls.txt` (one URL per line)
- **Sync State** - `/data/sync_state.json` (last run time, counts)

This prevents re-importing the same recipe multiple times.

## Configuration

### Recipe Sources (`config/sources.yaml`)

#### RSS Feeds

Import from recipe blog RSS feeds:

```yaml
sources:
  - type: rss
    enabled: true
    name: Minimalist Baker
    url: https://minimalistbaker.com/feed/
    max_entries: 10  # Check latest 10 posts
```

**Popular Recipe RSS Feeds:**
- Minimalist Baker: `https://minimalistbaker.com/feed/`
- Budget Bytes: `https://www.budgetbytes.com/feed/`
- Serious Eats: `https://www.seriouseats.com/recipes.rss`
- Cookie and Kate: `https://cookieandkate.com/feed/`
- Gimme Some Oven: `https://www.gimmesomeoven.com/feed/`

#### URL Lists

Manually curated recipe collections:

```yaml
sources:
  - type: url_list
    enabled: true
    name: Family Favorites
    urls:
      - https://www.allrecipes.com/recipe/228823/classic-lasagna/
      - https://www.foodnetwork.com/recipes/alton-brown/homemade-mac-and-cheese-recipe-1911679
```

**Best for:**
- Specific recipes you want to save
- Themed collections (Holiday Recipes, Quick Dinners, etc.)
- Recipes shared by friends/family

#### Sitemaps

Bulk import from recipe site sitemaps:

```yaml
sources:
  - type: sitemap
    enabled: false  # Use with caution!
    name: Recipe Site
    url: https://example.com/sitemap.xml
    allowlist:  # Only import URLs containing these
      - /recipes/
      - /dinner/
    max_pages: 20  # Limit URLs to process
```

**⚠️ Use Carefully:**
- Can import many recipes quickly
- Always use `allowlist` to filter relevant URLs
- Set reasonable `max_pages` limit
- Test with small limits first

### Settings (`config/settings.yaml`)

```yaml
mealie_url: http://mealie:9000
max_new_recipes_per_run: 20
```

Most settings are controlled via environment variables (see `.env.example`).

### Environment Variables

**`.env` file:**

```bash
# Mealie connection
MEALIE_BASE_URL=http://mealie:9000
MEALIE_API_TOKEN=your-token-here

# Sync behavior
MEALIE_SYNC_INTERVAL_MINUTES=360  # 6 hours
MEALIE_MAX_RECIPES_PER_RUN=20     # Limit per sync
```

## Advanced Usage

### Adding Multiple RSS Feeds

To import from multiple blogs, add multiple RSS sources:

```yaml
sources:
  - type: rss
    enabled: true
    name: Blog 1
    url: https://blog1.com/feed/
    max_entries: 10

  - type: rss
    enabled: true
    name: Blog 2
    url: https://blog2.com/feed/
    max_entries: 10
```

The sync will collect URLs from all enabled sources before importing.

### Themed Collections

Create curated collections with URL lists:

```yaml
sources:
  - type: url_list
    enabled: true
    name: Holiday Recipes
    urls:
      - https://example.com/thanksgiving-turkey
      - https://example.com/christmas-cookies
      - https://example.com/easter-brunch

  - type: url_list
    enabled: true
    name: Quick Weeknight Dinners
    urls:
      - https://example.com/30-minute-pasta
      - https://example.com/sheet-pan-chicken
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

**Verify API token:**
1. Check token is set in `.env`
2. Verify token is valid in Mealie settings
3. Regenerate token if needed

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

### View Imported URLs

```bash
cat /srv/orion/internal/appdata/mealie-sync/data/imported_urls.txt
```

### View Sync State

```bash
cat /srv/orion/internal/appdata/mealie-sync/data/sync_state.json
```

### Reset Import History

⚠️ **Warning:** This will cause all recipes to be re-imported!

```bash
docker compose --profile food_sync down
sudo rm /srv/orion/internal/appdata/mealie-sync/data/imported_urls.txt
docker compose --profile food_sync up -d
```

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

1. Edit `config/sources.yaml` or `config/settings.yaml`
2. Restart service:
   ```bash
   docker compose --profile food_sync restart mealie-sync
   ```

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
