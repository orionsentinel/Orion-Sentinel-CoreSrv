# Mealie Recipe Management

Mealie v3.7.0 deployment with automated recipe importing.

## Overview

This stack provides:
- **Mealie v3.7.0** - Recipe management application
- **PostgreSQL 16** - Database backend
- **Automated Importer** - Discovers and imports recipes from 20 curated sites

## Quick Start

### 1. Configure Environment

```bash
cd stacks/apps/mealie
cp .env.example .env
nano .env
```

**Required settings:**
- `MEALIE_POSTGRES_PASSWORD` - Generate a secure password

**Optional settings:**
- `OPENAI_API_KEY` - For AI-powered features
- `MEALIE_IMPORTER_TOKEN` - Required for importer (set after first login)

### 2. Start Mealie

```bash
# From repository root
make mealie-up

# Or directly
cd stacks/apps/mealie
docker compose -f docker-compose.mealie.yml up -d
```

### 3. Access Mealie

Open http://192.168.8.205:9000 in your browser.

**First-time setup:**
1. Create an admin account (signup is disabled after first user)
2. Configure your household
3. Generate an API token for the importer

### 4. Generate API Token for Importer

1. Go to **Settings** → **API Tokens**
2. Click **Create Token**
3. Name it "Recipe Importer Service"
4. Copy the token (shown only once!)
5. Add to `.env`:
   ```bash
   MEALIE_IMPORTER_TOKEN=your-token-here
   ```

### 5. Run Initial Backfill

```bash
# From stacks/apps/mealie directory
docker compose -f docker-compose.mealie.yml --profile importer run --rm \
  mealie-importer python /app/importer.py --mode backfill
```

This imports up to 75 newest recipes from each of 20 curated sites.

### 6. Enable Monthly Auto-Import

```bash
docker compose -f docker-compose.mealie.yml --profile importer-cron up -d
```

The importer runs automatically on the 1st of each month at 03:20.

## Make Targets

```bash
make mealie-up                  # Start Mealie stack
make mealie-down                # Stop Mealie stack
make mealie-logs                # View logs
make mealie-import-backfill     # Run initial backfill
make mealie-import-monthly      # Run monthly delta import
```

## Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                    Docker Network                            │
│  orion_mealie_net                                           │
│                                                              │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐  │
│  │  mealie-db   │    │    mealie    │    │   importer   │  │
│  │  PostgreSQL  │◄───│   v3.7.0     │◄───│   Python     │  │
│  │     :5432    │    │    :9000     │    │   (cron)     │  │
│  └──────────────┘    └──────────────┘    └──────────────┘  │
│                             │                                │
│                       port 9000                             │
└─────────────────────────────┼───────────────────────────────┘
                              │
                              ▼
                    http://192.168.8.205:9000
```

## Configuration Reference

### Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `MEALIE_POSTGRES_PASSWORD` | Database password | Required |
| `MEALIE_BASE_URL` | Public URL | http://192.168.8.205:9000 |
| `MEALIE_ALLOW_SIGNUP` | Allow new user signups | false |
| `TZ` | Timezone | Europe/Amsterdam |
| `OPENAI_API_KEY` | OpenAI API key (optional) | - |
| `OPENAI_MODEL` | OpenAI model | gpt-4o |
| `MEALIE_IMPORTER_TOKEN` | API token for importer | Required for import |

### Import Settings

| Variable | Description | Default |
|----------|-------------|---------|
| `MEALIE_BACKFILL_PER_SITE` | Recipes per site (backfill) | 75 |
| `MEALIE_BACKFILL_TOTAL_CAP` | Total recipes (backfill) | 1500 |
| `MEALIE_MONTHLY_PER_SITE` | Recipes per site (monthly) | 40 |
| `MEALIE_MONTHLY_TOTAL_CAP` | Total recipes (monthly) | 800 |
| `MEALIE_THROTTLE_SECONDS` | Delay between requests | 1.0 |

## Importer Sources

The importer fetches recipes from 20 curated sites:

### Mediterranean / Ottolenghi Style
1. Ottolenghi (ottolenghi.co.uk)
2. The Guardian Food (theguardian.com/food)
3. Meera Sodha (meerasodha.com)
4. The Happy Foodie (thehappyfoodie.co.uk)
5. Great British Chefs (greatbritishchefs.com)
6. BBC Good Food (bbcgoodfood.com)
7. The Mediterranean Dish (themediterraneandish.com)
8. Olive Magazine (olivemagazine.com)

### Reference / Technique
9. Akis Petretzikis (akispetretzikis.com) - Greek cuisine
10. RecipeTin Eats (recipetineats.com)
11. Serious Eats (seriouseats.com)
12. Bon Appétit (bonappetit.com)
13. SAVEUR (saveur.com)
14. Feasting at Home (feastingathome.com)

### Regional Cuisines
15. Spain on a Fork (spainonafork.com) - Spanish
16. Pati Jinich (patijinich.com) - Mexican
17. Rick Bayless (rickbayless.com) - Mexican
18. Hot Thai Kitchen (hot-thai-kitchen.com) - Thai
19. Rasa Malaysia (rasamalaysia.com) - Malaysian
20. The Woks of Life (thewoksoflife.com) - Chinese

## Tagging Strategy

Each imported recipe receives:
- **Source tag**: `source:<site-key>` (e.g., `source:ottolenghi`)
- **Cuisine tags**: `cuisine:mediterranean`, `cuisine:mexican`, etc.
- **Style tags**: `style:ottolenghi`, `style:weeknight`, etc.

Categories are also assigned per source configuration.

## Troubleshooting

### Mealie won't start

1. Check database is healthy:
   ```bash
   docker logs orion_mealie_db
   ```

2. Verify environment variables are set:
   ```bash
   docker compose -f docker-compose.mealie.yml config
   ```

### Cannot login / lost password

Reset the database (warning: destroys all data):
```bash
docker compose -f docker-compose.mealie.yml down -v
docker compose -f docker-compose.mealie.yml up -d
```

### Importer fails to connect

1. Verify API token is valid in Mealie UI
2. Check token is set in `.env`
3. Ensure containers are on same network:
   ```bash
   docker network inspect orion_mealie_net
   ```

### HTTP 403/429 errors

Some sites block automated scraping. The importer:
1. Respects robots.txt
2. Uses exponential backoff on rate limits
3. Falls back to HTML import when URL scraping fails

Increase `MEALIE_THROTTLE_SECONDS` if needed.

### Recipe not importing

1. Check URL matches allowlist patterns in `allowlist.yaml`
2. Verify recipe has schema.org Recipe JSON-LD
3. Try importing manually in Mealie UI

### Duplicate recipes

The importer tracks imported URLs in SQLite. To reimport:
```bash
docker compose run --rm mealie-importer python /app/importer.py \
  --force-url "https://example.com/recipe"
```

Or reset a domain:
```bash
docker compose run --rm mealie-importer python /app/importer.py \
  --reset-domain "example.com"
```

## Data Locations

| Path | Description |
|------|-------------|
| `mealie_pgdata` | PostgreSQL database |
| `mealie_data` | Mealie application data |
| `./data/mealie-importer/` | Importer state and logs |

## Backup

### Mealie Data

```bash
# Backup Mealie data volume
docker run --rm -v orion_mealie_data:/data -v $(pwd):/backup \
  alpine tar cvf /backup/mealie_data.tar /data

# Backup PostgreSQL
docker exec orion_mealie_db pg_dump -U mealie mealie > mealie_backup.sql
```

### Restore

```bash
# Restore Mealie data
docker run --rm -v orion_mealie_data:/data -v $(pwd):/backup \
  alpine tar xvf /backup/mealie_data.tar -C /

# Restore PostgreSQL
docker exec -i orion_mealie_db psql -U mealie mealie < mealie_backup.sql
```

## Security Notes

1. **API Token**: Store securely, rotate periodically
2. **No external exposure**: LAN-only by default
3. **Signup disabled**: Only admin can create users
4. **robots.txt respected**: Importer is a polite crawler

## Resources

- [Mealie Documentation](https://docs.mealie.io/)
- [Mealie API Reference](https://docs.mealie.io/api/)
- [Mealie GitHub](https://github.com/mealie-recipes/mealie)
