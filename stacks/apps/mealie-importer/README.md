# Mealie Recipe Importer

Automated recipe discovery and import for Mealie v3.7.0.

## Features

- **ONE-TIME backfill**: Import newest 75 recipes per site from 20 curated sources
- **MONTHLY delta**: Automatically import new recipes each month
- **Multiple discovery strategies**: RSS feeds, sitemaps, HTML listing pages
- **Strict URL filtering**: Per-site allowlist/denylist regex patterns
- **Idempotent**: SQLite state database prevents duplicate imports
- **Fallback HTML import**: When URL scraping fails, tries raw HTML import
- **Rate limiting**: Polite crawling with exponential backoff
- **robots.txt respect**: Honors site crawling preferences

## Configuration

### sources.yaml

Defines the 20 recipe sources with:
- Discovery URLs (RSS, sitemap, listing pages)
- Tags and categories to apply
- Per-site settings

### allowlist.yaml

Per-site URL filtering rules:
- Allow patterns (regex)
- Deny patterns (regex)
- Common deny patterns for all sites

## Quick Start

### 1. Configure Environment

```bash
cd stacks/apps/mealie-importer
cp .env.example .env
nano .env
```

Set `MEALIE_IMPORTER_TOKEN` (generate in Mealie UI).

### 2. Run Initial Backfill

```bash
# From stacks/apps/mealie directory
docker compose -f docker-compose.mealie.yml --profile importer run --rm \
  mealie-importer python /app/importer.py --mode backfill
```

### 3. Enable Monthly Cron

```bash
docker compose -f docker-compose.mealie.yml --profile importer-cron up -d
```

## Usage

### Commands

```bash
# Backfill mode (initial import)
python importer.py --mode backfill

# Monthly mode (delta updates)
python importer.py --mode monthly

# Dry run (discover without importing)
python importer.py --mode backfill --dry-run

# Force import single URL
python importer.py --force-url "https://example.com/recipe"

# Force reimport all from domain
python importer.py --force-domain "example.com"

# Reset state for a domain
python importer.py --reset-domain "example.com"
```

### Import Limits

| Mode | Per Site | Total Cap |
|------|----------|-----------|
| Backfill | 75 | 1500 |
| Monthly | 40 | 800 |

### Rate Limiting

- 1 second between requests to same domain
- Exponential backoff on HTTP 429/503
- robots.txt respected

## The 20 Sources

1. **Ottolenghi** - ottolenghi.co.uk
2. **The Guardian (Food)** - theguardian.com/food
3. **Meera Sodha** - meerasodha.com
4. **The Happy Foodie** - thehappyfoodie.co.uk
5. **Akis Petretzikis** - akispetretzikis.com
6. **RecipeTin Eats** - recipetineats.com
7. **Great British Chefs** - greatbritishchefs.com
8. **BBC Good Food** - bbcgoodfood.com
9. **The Mediterranean Dish** - themediterraneandish.com
10. **Serious Eats** - seriouseats.com
11. **Bon Appétit** - bonappetit.com
12. **SAVEUR** - saveur.com
13. **Feasting at Home** - feastingathome.com
14. **Olive Magazine** - olivemagazine.com
15. **Spain on a Fork** - spainonafork.com
16. **Pati Jinich** - patijinich.com
17. **Rick Bayless** - rickbayless.com
18. **Hot Thai Kitchen** - hot-thai-kitchen.com
19. **Rasa Malaysia** - rasamalaysia.com
20. **The Woks of Life** - thewoksoflife.com

## Tagging Strategy

Each imported recipe gets:
- `source:<site-key>` tag (e.g., `source:ottolenghi`)
- Cuisine/style tags (e.g., `cuisine:mediterranean`, `style:ottolenghi`)
- Category assignment from sources.yaml

## API Endpoints Used

- `POST /api/recipes/create/url` - Import from URL
- `POST /api/recipes/create/url/bulk` - Bulk URL import
- `POST /api/recipes/create/html-or-json` - Fallback HTML import
- `POST /api/organizers/tags` - Create tags
- `POST /api/organizers/categories` - Create categories

## State Database

SQLite database at `/data/importer_state.db`:
- `urls` - Discovered URLs with status
- `runs` - Import run statistics

View statistics:
```bash
docker exec orion_mealie_importer sqlite3 /data/importer_state.db \
  "SELECT domain, COUNT(*) FROM urls WHERE status='imported' GROUP BY domain"
```

## Troubleshooting

### Cannot connect to Mealie

1. Check Mealie is running: `docker ps | grep mealie`
2. Verify network connectivity
3. Check API token is valid

### URL import fails

1. Check URL matches allowlist patterns
2. Try HTML fallback (automatic)
3. Check logs for specific error

### Rate limited

The importer automatically backs off on HTTP 429/503. Increase `THROTTLE_SECONDS` if needed.

## Files

```
stacks/apps/mealie-importer/
├── app/
│   ├── importer.py          # Main application
│   ├── mealie_api.py        # Mealie API client
│   ├── discovery.py         # URL discovery (RSS, sitemap, crawl)
│   ├── domain_filters.py    # URL filtering
│   ├── state_db.py          # SQLite state management
│   ├── sources_loader.py    # Configuration loader
│   ├── logger.py            # Logging configuration
│   └── requirements.txt     # Python dependencies
├── config/
│   ├── sources.yaml         # 20 source sites configuration
│   └── allowlist.yaml       # URL filtering rules
├── Dockerfile               # Standard importer image
├── Dockerfile.cron          # Cron-enabled importer image
├── .env.example             # Environment template
└── README.md                # This file
```
