# Orion-Sentinel-DataAICore Installation Guide

Complete step-by-step installation guide for Dell Optiplex or similar x86-64 hardware.

## Prerequisites

### Hardware
- Dell Optiplex 7050/9020 or similar x86-64 PC
- CPU: Intel i5/i7 (4+ cores recommended)
- RAM: 16GB minimum, 32GB recommended for LLMs
- Storage:
  - 256GB+ SSD for system and databases
  - 1TB+ for Nextcloud data (can be separate drive)
- Network: Gigabit Ethernet

### Software
- Ubuntu Server 24.04 LTS (or Debian 12)
- Docker Engine 24.0+
- Docker Compose 2.20+

## Step 1: Prepare System

### 1.1 Install Ubuntu Server

Use Ubuntu Server 24.04 LTS for best compatibility.

**During installation:**
- Enable OpenSSH server
- Create admin user
- Set static IP (recommended) or use DHCP reservation

### 1.2 Update System

```bash
# SSH into your Optiplex
ssh admin@<OPTIPLEX_IP>

# Update system
sudo apt update && sudo apt upgrade -y

# Install prerequisites
sudo apt install -y git curl vim htop
```

### 1.3 Configure Storage

**For single drive:**
```bash
# Data will be stored on main system drive
sudo mkdir -p /srv/dataaicore
sudo chown -R $USER:$USER /srv/dataaicore
```

**For separate data drive (recommended):**
```bash
# Find your data drive
lsblk

# Example: /dev/sdb is your 1TB data drive
# Format it (WARNING: Erases all data!)
sudo mkfs.ext4 /dev/sdb1

# Create mount point
sudo mkdir -p /mnt/data

# Get UUID
sudo blkid /dev/sdb1
# Example output: UUID="xyz-123-abc"

# Add to /etc/fstab
echo "UUID=xyz-123-abc /mnt/data ext4 defaults,nofail 0 2" | sudo tee -a /etc/fstab

# Mount
sudo mount -a

# Verify
df -h /mnt/data

# Create data root
sudo mkdir -p /mnt/data/dataaicore
sudo chown -R $USER:$USER /mnt/data/dataaicore

# Symlink for convenience
sudo ln -s /mnt/data/dataaicore /srv/dataaicore
```

## Step 2: Install Docker

```bash
# Install Docker (official method)
curl -fsSL https://get.docker.com -o get-docker.sh
sudo sh get-docker.sh

# Add user to docker group
sudo usermod -aG docker $USER

# Log out and back in for group change
exit
# Then SSH back in

# Verify installation
docker --version
docker compose version
```

## Step 3: Clone and Setup DataAICore

### 3.1 Clone Repository

```bash
# Clone the repository
cd ~
git clone https://github.com/orionsentinel/Orion-Sentinel-CoreSrv.git
cd Orion-Sentinel-CoreSrv/Orion-Sentinel-DataAICore
```

### 3.2 Run Setup Script

```bash
# Run setup
./scripts/setup.sh

# What it does:
# ✓ Creates directory structure under /srv/dataaicore
# ✓ Generates secure random secrets for databases
# ✓ Creates env/.env.example with defaults
# ✓ Creates Docker networks
# ✓ Initializes config files
```

### 3.3 Configure Environment

```bash
# Copy example env to .env
cp env/.env.example .env

# Edit configuration
nano .env
```

**Key settings to review:**

```bash
# Timezone
TZ=Europe/Amsterdam

# Data root
DATA_ROOT=/srv/dataaicore

# Domain (for public Nextcloud phase 2)
ORION_DOMAIN=yourdomain.com

# Nextcloud settings
NEXTCLOUD_ADMIN_USER=admin
NEXTCLOUD_ADMIN_PASSWORD=<generated-password>
NEXTCLOUD_TRUSTED_DOMAINS=<OPTIPLEX_IP> cloud.${ORION_DOMAIN}

# Database passwords (auto-generated)
NEXTCLOUD_DB_PASSWORD=<generated-password>
NEXTCLOUD_REDIS_PASSWORD=<generated-password>

# Ollama settings (optional)
OLLAMA_GPU_LAYERS=0  # Set to 1 if you have GPU
```

## Step 4: Start Services

### 4.1 Start Nextcloud Stack

```bash
# Start Nextcloud
./scripts/orionctl.sh up nextcloud

# Check status
./scripts/orionctl.sh ps

# View logs
./scripts/orionctl.sh logs nextcloud
```

**Access Nextcloud:**
- Open browser: `http://<OPTIPLEX_IP>:8080`
- Log in with admin credentials from .env
- Complete initial setup wizard

**First-time Nextcloud setup:**
1. Choose apps to install (recommended: Calendar, Contacts, Tasks)
2. Configure email (optional)
3. Install mobile apps (iOS/Android)

### 4.2 Start Search Stack (Optional)

```bash
# Start search services
./scripts/orionctl.sh up search

# Verify all services running
./scripts/orionctl.sh ps

# Check indexer logs
./scripts/orionctl.sh logs local-indexer
```

**Test SearXNG:**
- Open: `http://<OPTIPLEX_IP>:8888`
- Try a search query
- Results from multiple search engines appear

**Add documents to index:**
```bash
# Copy PDFs, TXTs, DOCX files
cp ~/Documents/*.pdf /srv/dataaicore/search/local-search/

# Wait ~30 seconds for indexing
# Then search for content in SearXNG
```

### 4.3 Start LLM Stack (Optional)

```bash
# Start LLM services
./scripts/orionctl.sh up llm

# Wait for Ollama to be ready (~30 seconds)
./scripts/orionctl.sh logs ollama

# Pull a small model (recommended for CPU)
docker exec -it orion_dataaicore_ollama ollama pull llama3.2:3b

# Or a larger model if you have resources
docker exec -it orion_dataaicore_ollama ollama pull llama3.2:7b
```

**Model download times:**
- 3B model: ~2GB, 2-5 minutes on fast connection
- 7B model: ~4GB, 5-10 minutes
- 13B+ model: ~8GB+, 10-30 minutes

**Access Open WebUI:**
- Open: `http://<OPTIPLEX_IP>:3000`
- Create account (first user becomes admin)
- Select model from dropdown
- Start chatting!

## Step 5: Configure Nextcloud

### 5.1 Trusted Domains

If you can't access Nextcloud, add your IP to trusted domains:

```bash
# Edit Nextcloud config
docker exec -it orion_dataaicore_nextcloud \
  php occ config:system:set trusted_domains 1 --value=<OPTIPLEX_IP>

# Verify
docker exec -it orion_dataaicore_nextcloud \
  php occ config:system:get trusted_domains
```

### 5.2 Redis Cache (Already configured)

Redis is pre-configured for file locking and caching.

### 5.3 Background Jobs

```bash
# Set background jobs to use cron (recommended)
docker exec -it orion_dataaicore_nextcloud \
  php occ background:cron
```

### 5.4 Mobile Apps

Install Nextcloud mobile app:
- iOS: App Store
- Android: Google Play or F-Droid

Configure server: `http://<OPTIPLEX_IP>:8080`

## Step 6: Configure SearXNG (Optional)

### 6.1 Enable/Disable Search Engines

Edit SearXNG settings:

```bash
nano /srv/dataaicore/search/searxng/settings.yml
```

Add or remove engines in the `engines:` section.

Restart SearXNG:
```bash
./scripts/orionctl.sh restart
```

### 6.2 Verify Local Search

After adding documents to `/srv/dataaicore/search/local-search/`:

1. Check indexer processed them:
   ```bash
   ./scripts/orionctl.sh logs local-indexer
   ```

2. Search in SearXNG for content from your documents

3. Results should appear with "Local" tag

## Step 7: Verify Installation

```bash
# Check all services are running
./scripts/orionctl.sh ps

# Expected output (with all profiles):
# NAME                              STATUS    PORTS
# orion_dataaicore_nextcloud          Up      0.0.0.0:8080->80/tcp
# orion_dataaicore_nextcloud_db       Up
# orion_dataaicore_nextcloud_redis    Up
# orion_dataaicore_searxng            Up      0.0.0.0:8888->8080/tcp
# orion_dataaicore_valkey             Up
# orion_dataaicore_meilisearch        Up
# orion_dataaicore_tika               Up
# orion_dataaicore_local_indexer      Up
# orion_dataaicore_ollama             Up
# orion_dataaicore_open_webui         Up      0.0.0.0:3000->8080/tcp

# Validate configuration
./scripts/orionctl.sh validate
```

## Step 8: Optional - Public Nextcloud Access (Phase 2)

**⚠️ Only do this if you want Nextcloud accessible from the internet!**

### Prerequisites
- Domain name (e.g., `cloud.yourdomain.com`)
- DNS A record: `cloud.yourdomain.com` → Your public IP
- Router port forwarding: 443 → Optiplex IP

### Enable Public Access

```bash
# Edit .env and set your domain
nano .env
# Set: ORION_DOMAIN=yourdomain.com

# Start with public-nextcloud profile
./scripts/orionctl.sh down
./scripts/orionctl.sh up nextcloud public-nextcloud

# Caddy will automatically obtain Let's Encrypt SSL certificate
# Check logs: ./scripts/orionctl.sh logs caddy
```

### Configure Nextcloud for Public Access

```bash
# Add public domain to trusted domains
docker exec -it orion_dataaicore_nextcloud \
  php occ config:system:set trusted_domains 2 --value=cloud.${ORION_DOMAIN}

# Set overwrite settings for reverse proxy
docker exec -it orion_dataaicore_nextcloud \
  php occ config:system:set overwrite.cli.url --value=https://cloud.${ORION_DOMAIN}

docker exec -it orion_dataaicore_nextcloud \
  php occ config:system:set overwriteprotocol --value=https

# Enable 2FA (HIGHLY RECOMMENDED)
# Do this in Nextcloud web UI:
# Settings → Security → Two-Factor Authentication
```

### Verify Public Access

1. Open browser: `https://cloud.yourdomain.com`
2. You should see Nextcloud login
3. SSL certificate should be valid (green lock icon)

**Security checklist:**
- [ ] 2FA enabled for all users
- [ ] Strong passwords enforced
- [ ] Brute force protection enabled (default in Nextcloud)
- [ ] Regular security updates
- [ ] Monitor access logs

## Troubleshooting

### Nextcloud database connection failed
```bash
# Check database is healthy
docker exec orion_dataaicore_nextcloud_db pg_isready -U nextcloud

# Check logs
./scripts/orionctl.sh logs nextcloud-db

# Restart database
docker restart orion_dataaicore_nextcloud_db
```

### SearXNG returns no results
```bash
# Check if SearXNG can reach the internet
docker exec orion_dataaicore_searxng wget -O- https://www.google.com

# Check Valkey is working
docker exec orion_dataaicore_valkey redis-cli ping

# Restart SearXNG
./scripts/orionctl.sh restart
```

### Local indexer not processing documents
```bash
# Check indexer logs
./scripts/orionctl.sh logs local-indexer

# Check Tika is running
docker exec orion_dataaicore_tika curl -I http://localhost:9998/tika

# Check Meilisearch health
curl http://localhost:7700/health  # Should return OK

# Manually trigger index (restart indexer)
docker restart orion_dataaicore_local_indexer
```

### Ollama model won't load
```bash
# Check disk space (models are large!)
df -h

# Check Ollama logs
./scripts/orionctl.sh logs ollama

# Try smaller model
docker exec -it orion_dataaicore_ollama ollama pull llama3.2:3b

# List models
docker exec -it orion_dataaicore_ollama ollama list
```

### Open WebUI can't connect to Ollama
```bash
# Check Ollama is running
curl http://localhost:11434/api/tags

# Check Open WebUI environment
docker exec orion_dataaicore_open_webui env | grep OLLAMA

# Restart Open WebUI
docker restart orion_dataaicore_open_webui
```

### Caddy SSL certificate fails (public-nextcloud)
```bash
# Check Caddy logs
./scripts/orionctl.sh logs caddy

# Verify DNS record
nslookup cloud.${ORION_DOMAIN}

# Verify port 443 is forwarded
# Check your router settings

# Restart Caddy
docker restart orion_dataaicore_caddy
```

## Maintenance

### Update Docker Images

```bash
# Pull latest images
./scripts/orionctl.sh pull

# Restart with new images
./scripts/orionctl.sh down
./scripts/orionctl.sh up [profiles...]
```

### Backup Nextcloud Data

```bash
# Stop Nextcloud (optional but recommended)
docker stop orion_dataaicore_nextcloud

# Backup database
docker exec orion_dataaicore_nextcloud_db pg_dump -U nextcloud nextcloud > \
  ~/nextcloud-backup-$(date +%Y%m%d).sql

# Backup data directory
sudo tar -czf ~/nextcloud-data-$(date +%Y%m%d).tar.gz \
  /srv/dataaicore/nextcloud/app

# Restart Nextcloud
docker start orion_dataaicore_nextcloud
```

### Automated Backups

Set up with cron:

```bash
# Create backup script
cat > ~/backup-dataaicore.sh << 'EOF'
#!/bin/bash
docker exec orion_dataaicore_nextcloud_db pg_dump -U nextcloud nextcloud | \
  gzip > ~/backups/nextcloud-$(date +%Y%m%d).sql.gz
EOF

chmod +x ~/backup-dataaicore.sh

# Add to crontab (daily at 2 AM)
crontab -e
# Add: 0 2 * * * ~/backup-dataaicore.sh
```

## Next Steps

1. **Nextcloud:** Install apps (Calendar, Contacts, Deck, Talk)
2. **Search:** Add more documents to local search
3. **LLM:** Experiment with different models and prompts
4. **Security:** Enable 2FA, review access logs
5. **Monitoring:** Consider adding Uptime Kuma or Grafana

## Performance Tuning

### For LLMs with GPU

If you have NVIDIA GPU:

```bash
# Install NVIDIA Container Toolkit
# See: https://docs.nvidia.com/datacenter/cloud-native/container-toolkit/install-guide.html

# Edit stacks/llm/compose.yml
# Uncomment GPU device sections

# Restart LLM stack
./scripts/orionctl.sh down
./scripts/orionctl.sh up llm
```

### For Large Nextcloud Instances

```bash
# Increase PHP memory limit
docker exec orion_dataaicore_nextcloud \
  sed -i 's/memory_limit = .*/memory_limit = 512M/' /usr/local/etc/php/php.ini

# Increase max upload size
docker exec orion_dataaicore_nextcloud \
  sed -i 's/upload_max_filesize = .*/upload_max_filesize = 10G/' /usr/local/etc/php/php.ini

# Restart Nextcloud
docker restart orion_dataaicore_nextcloud
```

## Support

For issues or questions:
- GitHub Issues: https://github.com/orionsentinel/Orion-Sentinel-CoreSrv/issues
- Nextcloud Community: https://help.nextcloud.com/

---

**Installation complete!** Enjoy your self-hosted cloud and AI stack! ☁️🤖
