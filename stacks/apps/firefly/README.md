# Firefly III - Personal Finance Manager

## Overview

Firefly III is a free and open-source personal finance manager. It helps you keep track of your expenses and income, so you can spend less and save more.

**Services:**
- **firefly** - Main Firefly III application
- **firefly-db** - MariaDB database
- **firefly-cron** - Scheduled tasks (recurring transactions, etc.)
- **firefly-importer** - Data importer for bank statements and CSV files

## Quick Start

### 1. Generate APP_KEY

The APP_KEY is a 32-character random string required for encryption. Generate it with one of these methods:

```bash
# Method 1: Using /dev/urandom
head /dev/urandom | LC_ALL=C tr -dc 'A-Za-z0-9' | head -c 32 && echo

# Method 2: Using Docker
docker run --rm fireflyiii/core:latest php artisan key:generate --show

# Method 3: Using OpenSSL
openssl rand -base64 32 | head -c 32 && echo
```

### 2. Configure Environment

Copy the example environment file and add your generated APP_KEY:

```bash
cd stacks/apps/firefly
cp .env.example .env
nano .env  # Add APP_KEY and change FIREFLY_DB_PASSWORD
```

**Required variables:**
- `FIREFLY_APP_KEY` - 32 character random string (see above)
- `FIREFLY_DB_PASSWORD` - Strong database password

### 3. Start the Stack

```bash
# From repository root
./scripts/orionctl up apps --profile finance

# Or using Docker Compose directly
docker compose --profile finance up -d
```

### 4. Initial Setup

1. Navigate to **https://firefly.orion.lan** (or your configured domain)
2. Complete the installation wizard:
   - Set admin email and password
   - Configure your currency and locale
3. Create your first account (checking, savings, etc.)

### 5. Configure Data Importer (Optional)

To use the data importer for automatic bank imports:

1. In Firefly III, go to **Options → Profile → OAuth**
2. Click **Create New Token**
3. Give it a name (e.g., "Data Importer")
4. Copy the generated token
5. Add to `.env` file:
   ```bash
   FIREFLY_IMPORTER_TOKEN=your-generated-token-here
   ```
6. Restart the importer:
   ```bash
   docker compose --profile finance restart firefly-importer
   ```

## Accessing Services

- **Firefly III**: https://firefly.orion.lan
- **Data Importer**: https://firefly-importer.orion.lan

## Features

### Core Features
- Track income and expenses
- Manage multiple accounts (checking, savings, credit cards)
- Categorize transactions with tags and categories
- Budget management with envelopes
- Recurring transactions (automatic bills, subscriptions)
- Reports and charts
- Multi-currency support
- Rule engine for automatic transaction processing

### Data Import Options

1. **Manual Entry** - Add transactions manually
2. **CSV Import** - Import bank statements via CSV files
3. **Bank Integration** - Connect directly to your bank (EU):
   - Nordigen (GoCardless) - Free for EU banks
   - Spectre (Salt Edge) - Paid service, more banks
4. **API** - Programmatic access via REST API

## Bank Integration Setup

### Nordigen (Free - EU Banks)

1. Sign up at https://nordigen.com/en/account/login/
2. Get your API credentials (ID and Secret Key)
3. Add to `.env`:
   ```bash
   FIREFLY_NORDIGEN_ID=your-nordigen-id
   FIREFLY_NORDIGEN_KEY=your-nordigen-secret-key
   ```
4. Restart services:
   ```bash
   docker compose --profile finance restart firefly-importer
   ```
5. In Data Importer, select Nordigen and authorize your bank

**Supported:** Most EU banks through Open Banking PSD2

### Spectre / Salt Edge (Paid)

1. Sign up at https://www.saltedge.com/products/spectre
2. Get your App ID and Secret
3. Add to `.env`:
   ```bash
   FIREFLY_SPECTRE_APP_ID=your-app-id
   FIREFLY_SPECTRE_SECRET=your-secret
   ```
4. Restart and configure in Data Importer

## Configuration

### Email Notifications

To enable email notifications for budgets, bills, etc:

1. Edit `.env`:
   ```bash
   FIREFLY_MAIL_MAILER=smtp
   FIREFLY_MAIL_HOST=smtp.gmail.com
   FIREFLY_MAIL_PORT=587
   FIREFLY_MAIL_FROM=your-email@gmail.com
   FIREFLY_MAIL_USERNAME=your-email@gmail.com
   FIREFLY_MAIL_PASSWORD=your-app-password
   FIREFLY_MAIL_ENCRYPTION=tls
   ```

2. Restart Firefly:
   ```bash
   docker compose --profile finance restart firefly
   ```

### Recurring Transactions

The `firefly-cron` container runs scheduled tasks daily:
- Process recurring transactions
- Auto-budget management
- Execute automatic rules
- Currency exchange rate updates

**No configuration needed** - runs automatically once deployed.

## Backup

### What to Backup

Critical data:
1. **Database** - All your financial data
2. **Uploads** - Attachments and receipts

### Backup Database

```bash
# Backup database to SQL file
docker exec orion_firefly_db mysqldump -u firefly -p firefly > firefly-backup-$(date +%Y%m%d).sql

# Or backup the entire database directory
sudo tar -czf firefly-db-backup-$(date +%Y%m%d).tar.gz \
  /srv/orion/internal/db/firefly
```

### Backup Uploads

```bash
sudo tar -czf firefly-uploads-backup-$(date +%Y%m%d).tar.gz \
  /srv/orion/internal/appdata/firefly
```

### Restore

1. Stop services:
   ```bash
   docker compose --profile finance down
   ```

2. Restore database:
   ```bash
   # Start only the database
   docker compose --profile finance up -d firefly-db
   
   # Wait for it to be ready, then restore
   docker exec -i orion_firefly_db mysql -u firefly -p firefly < firefly-backup.sql
   ```

3. Restore uploads:
   ```bash
   sudo tar -xzf firefly-uploads-backup.tar.gz -C /
   ```

4. Start all services:
   ```bash
   docker compose --profile finance up -d
   ```

## Troubleshooting

### "APP_KEY is not set" Error

Generate a new APP_KEY (see Quick Start) and add it to `.env`.

### Cannot Access Firefly III

```bash
# Check service status
docker compose --profile finance ps

# Check logs
docker compose --profile finance logs firefly

# Verify Traefik routing
docker logs orion_traefik | grep firefly
```

### Database Connection Errors

```bash
# Check database is healthy
docker compose --profile finance ps firefly-db

# Check database logs
docker compose --profile finance logs firefly-db

# Verify credentials in .env match database configuration
```

### Importer Cannot Connect to Firefly

1. Verify `FIREFLY_IMPORTER_TOKEN` is set correctly
2. Token must be generated in Firefly III (Options → Profile → OAuth)
3. Restart importer after setting token:
   ```bash
   docker compose --profile finance restart firefly-importer
   ```

### Recurring Transactions Not Processing

Check cron container logs:
```bash
docker compose --profile finance logs firefly-cron
```

The cron runs once per day. To trigger manually:
```bash
docker exec orion_firefly_cron php artisan firefly-iii:cron
```

## Security Best Practices

1. **Change Default Passwords**
   - Use strong, unique APP_KEY (32 chars)
   - Use strong database password
   - Use strong admin password in Firefly UI

2. **Enable 2FA** (Two-Factor Authentication)
   - In Firefly: Options → Profile → 2FA
   - Use authenticator app (Google Authenticator, Authy, etc.)

3. **Regular Backups**
   - Schedule daily/weekly database backups
   - Test restore procedure periodically

4. **Keep Updated**
   - Update images regularly for security patches
   - Check Firefly III release notes before updating

5. **Limit Access**
   - Use Traefik authentication middleware if desired
   - Consider VPN access for external connections

## API Access

Firefly III provides a REST API for automation and integrations.

### Generate API Token

1. Login to Firefly III
2. Go to **Options → Profile → OAuth**
3. Create **New Personal Access Token**
4. Copy the token (shown only once!)

### Example API Usage

```bash
# Get all accounts
curl -X GET "https://firefly.orion.lan/api/v1/accounts" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Accept: application/json"

# Create a transaction
curl -X POST "https://firefly.orion.lan/api/v1/transactions" \
  -H "Authorization: Bearer YOUR_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "transactions": [{
      "type": "withdrawal",
      "date": "2024-01-01",
      "amount": "12.34",
      "description": "Groceries",
      "source_name": "Checking Account",
      "destination_name": "Supermarket"
    }]
  }'
```

**API Documentation**: https://api-docs.firefly-iii.org/

## Resources

- **Official Documentation**: https://docs.firefly-iii.org/
- **GitHub Repository**: https://github.com/firefly-iii/firefly-iii
- **Community Forum**: https://reddit.com/r/FireflyIII
- **API Documentation**: https://api-docs.firefly-iii.org/
- **Data Importer Docs**: https://docs.firefly-iii.org/data-importer/

## Updates

To update Firefly III to the latest version:

```bash
# Pull latest images
docker compose --profile finance pull

# Recreate containers
docker compose --profile finance up -d

# Check logs for any migration issues
docker compose --profile finance logs -f firefly
```

**Important**: Always backup before updating!

---

**Stack Profile**: `finance`  
**Required in compose.yaml**: Add `- path: stacks/apps/firefly/compose.yml` to include section  
**Maintained by**: Orion Home Lab Team
