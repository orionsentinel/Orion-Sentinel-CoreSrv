# Upstream Synchronization Guide

## Overview

This repository (`Orion-Sentinel-CoreSrv`) is **not a fork** of any upstream project. Instead, it is a **derived work** that cherry-picks patterns, configurations, and best practices from two excellent upstream repositories:

1. **[AdrienPoupa/docker-compose-nas](https://github.com/AdrienPoupa/docker-compose-nas)**
   - NAS/media stack with Traefik, VPN, Homepage, maintenance tools
   - Excellent folder structure and environment variable patterns
   - Hardlink-friendly media layout (Trash-Guides compatible)

2. **[navilg/media-stack](https://github.com/navilg/media-stack)**
   - Modern Jellyfin media stack
   - Recommendarr integration (AI-powered recommendations)
   - VPN profile patterns with Gluetun

## Why Not Fork?

### Advantages of Derived Work Approach

1. **Flexibility:** We can mix patterns from both repos without conflicts
2. **Customization:** Tailored specifically for our 3-node home lab architecture
3. **Independence:** Not tied to upstream merge conflicts or breaking changes
4. **Selective Adoption:** Cherry-pick only relevant improvements

### Trade-offs

1. **Manual Sync:** We must manually track and apply upstream changes
2. **Maintenance Burden:** Requires periodic review of upstream repos
3. **Documentation:** Must document what we've borrowed and why

## Synchronization Workflow

### Recommended Cadence

- **Quarterly:** Review both upstream repos for major changes
- **Before Major Upgrades:** Check upstream before upgrading Docker images
- **Security Updates:** Immediately apply security-related changes
- **Optional Features:** Adopt new features as needed

---

## Step-by-Step Sync Process

### 1. Preparation (Quarterly or Before Upgrades)

#### A. Check Upstream Repositories

Visit both upstream repos and review recent changes:

```bash
# Clone or update upstream repos (optional, for offline review)
mkdir -p ~/upstream-repos
cd ~/upstream-repos

# AdrienPoupa/docker-compose-nas
git clone https://github.com/AdrienPoupa/docker-compose-nas.git || \
  (cd docker-compose-nas && git pull)

# navilg/media-stack
git clone https://github.com/navilg/media-stack.git || \
  (cd media-stack && git pull)
```

#### B. Review Changelogs and Commits

For **AdrienPoupa/docker-compose-nas:**
- Check: https://github.com/AdrienPoupa/docker-compose-nas/releases
- Review: `README.md`, `docker-compose.yml`, `.env.example`

For **navilg/media-stack:**
- Check: https://github.com/navilg/media-stack/releases
- Review: `README.md`, `docker-compose.yaml`, `config/` directory

#### C. Note Current Versions

Record current versions in Orion-Sentinel-CoreSrv:

```bash
cd ~/Orion-Sentinel-CoreSrv
git log --oneline -1  # Note current commit
docker compose config | grep image:  # Note current image tags
```

---

### 2. Identify Relevant Changes

For each service we use, compare upstream changes:

#### Services to Track

| Service | Upstream Source | Notes |
|---------|----------------|-------|
| Traefik | Both repos | Focus on label patterns, middleware |
| Authelia | AdrienPoupa | SSO configuration |
| Jellyfin | Both repos | Image version, env vars |
| Sonarr | Both repos | Image version, volume mappings |
| Radarr | Both repos | Image version, volume mappings |
| Bazarr | AdrienPoupa | Optional subtitle service |
| Prowlarr | Both repos | Indexer manager |
| qBittorrent | Both repos | VPN integration critical |
| Jellyseerr | Both repos | Request management |
| Recommendarr | navilg | AI recommendations |
| VPN (Gluetun) | Both repos | VPN container configuration |
| Nextcloud | AdrienPoupa | Cloud storage |
| Prometheus | - | We maintain independently |
| Grafana | - | We maintain independently |
| Homepage | AdrienPoupa | Dashboard configuration |
| Watchtower | AdrienPoupa | Auto-update patterns |
| Autoheal | AdrienPoupa | Health check restart |

#### What to Look For

For each service, check:

1. **Image Tags:**
   - Compare: `image: jellyfin/jellyfin:10.8.13` vs. current
   - Look for: Major version bumps, security tags

2. **Environment Variables:**
   - New required variables
   - Deprecated variables
   - Changed defaults

3. **Volume Mappings:**
   - New config directories
   - Changed paths
   - New data requirements

4. **Traefik Labels:**
   - Improved middleware patterns
   - Better routing rules
   - Security enhancements

5. **Network Configuration:**
   - New network requirements
   - Changed isolation patterns
   - Port mappings

6. **VPN Integration:**
   - Gluetun version changes
   - VPN provider updates
   - qBittorrent routing changes

---

### 3. Decide What to Adopt

#### Decision Matrix

For each change found upstream, ask:

| Question | Yes → Adopt | No → Skip |
|----------|------------|----------|
| Does it fix a security issue? | ✅ Always adopt | - |
| Does it improve stability? | ✅ Likely adopt | ❌ Skip if breaking |
| Does it add a feature we want? | ✅ Adopt if useful | ❌ Skip if not needed |
| Does it conflict with our architecture? | ❌ Skip or adapt | ✅ Adopt if compatible |
| Is it DNS-related (AdGuard Home)? | ❌ **Never adopt** | - |
| Is it specific to their setup? | ❌ Skip | ✅ Adapt if applicable |

#### Special Considerations

**DO NOT adopt:**
- DNS services (AdGuard Home, etc.) - We use Pi 5 #1 (Pi-hole)
- Home Assistant integrations specific to their hardware
- Services we don't run

**Always review carefully:**
- VPN configuration (critical for privacy)
- Traefik labels (affects access control)
- Authelia policies (affects security)

---

### 4. Apply Changes Manually

#### A. Update Image Tags

In `compose.yml`, update image tags:

```yaml
# Before
jellyfin:
  image: jellyfin/jellyfin:10.8.13

# After (example)
jellyfin:
  image: jellyfin/jellyfin:10.9.1
```

#### B. Update Environment Variables

In `env/.env.*.example` files, add/update variables:

```bash
# Example: New Jellyfin variable from upstream
JELLYFIN_PublishedServerUrl=https://jellyfin.local
```

Also update your actual `.env.*` files (not tracked in git).

#### C. Update Traefik Labels

If upstream has improved label patterns:

```yaml
# Example: Better Authelia middleware pattern
labels:
  - "traefik.http.routers.jellyfin.middlewares=authelia@docker"
  - "traefik.http.routers.jellyfin.rule=Host(`jellyfin.local`)"
```

#### D. Update Volume Mappings

If upstream changed volume structure:

```yaml
volumes:
  - ${CONFIG_ROOT}/jellyfin:/config  # Check if path changed
  - ${MEDIA_ROOT}/library:/library:ro  # Check if permissions changed
```

#### E. Test VPN Changes Carefully

VPN configuration is critical. Test thoroughly:

```bash
# Start only VPN + qBittorrent
docker compose --profile media-core up -d vpn qbittorrent

# Check VPN connection
docker compose exec vpn curl ifconfig.me

# Check qBittorrent can reach internet via VPN
docker compose exec qbittorrent curl ifconfig.me

# Verify IP matches VPN, not your ISP
```

---

### 5. Test Changes in Controlled Environment

#### A. Backup Current Configuration

```bash
# Backup compose file
cp compose.yml compose.yml.backup

# Backup env files
cp -r env env.backup

# Backup critical data
sudo tar -czf ~/orion-backup-$(date +%Y%m%d).tar.gz /srv/orion-sentinel-core-sentinel-core/config
```

#### B. Test with Limited Profile First

```bash
# Test only media profile first
docker compose --profile core --profile media-core up -d

# Check logs
docker compose logs -f

# Verify services are healthy
docker compose ps
```

#### C. Verify Functionality

Test critical paths:

1. **Media Flow:**
   - Add a test TV show in Jellyseerr
   - Verify it appears in Sonarr
   - Check qBittorrent downloads via VPN
   - Confirm Jellyfin can play it

2. **Authentication:**
   - Access a protected service
   - Verify Authelia prompts for login
   - Test 2FA if enabled

3. **Monitoring:**
   - Check Prometheus targets
   - Verify Grafana dashboards load
   - Confirm logs appear in Loki

#### D. Gradual Rollout

```bash
# If media works, add cloud
docker compose --profile cloud up -d

# Then monitoring
docker compose --profile monitoring up -d

# Finally, all profiles
docker compose --profile all up -d
```

---

### 6. Document the Sync

#### A. Update This File

Add entry to sync log (see table at bottom of this document).

#### B. Update Commit Message

```bash
git add compose.yml env/
git commit -m "sync: Update from upstream (YYYY-MM-DD)

Upstream sources:
- AdrienPoupa/docker-compose-nas @ vX.Y / commit abc123
- navilg/media-stack @ vA.B / commit def456

Changes:
- Updated Jellyfin to 10.9.1 (from 10.8.13)
- Updated qBittorrent to latest tag
- Improved Traefik labels for VPN routing
- Added new env vars for Recommendarr

Tested:
- Media download flow
- VPN connectivity
- Authelia SSO

Ref: https://github.com/AdrienPoupa/docker-compose-nas/releases/tag/vX.Y"
```

#### C. Create Sync Report (Optional)

For major syncs, create a brief report:

```markdown
## Sync Report: YYYY-MM-DD

### Upstream Versions Reviewed
- AdrienPoupa/docker-compose-nas: vX.Y (released YYYY-MM-DD)
- navilg/media-stack: vA.B (released YYYY-MM-DD)

### Changes Applied
1. Image updates:
   - Jellyfin: 10.8.13 → 10.9.1
   - qBittorrent: 4.6.0 → 4.6.2
   
2. Configuration changes:
   - Added JELLYFIN_PublishedServerUrl env var
   - Updated Traefik middleware for better VPN routing

3. New features adopted:
   - Homepage dashboard improvements from AdrienPoupa

### Changes Skipped
- AdGuard Home updates (we use Pi-hole on Pi 5 #1)
- Specific HA integrations not applicable to our hardware

### Testing Results
- ✅ Media download flow working
- ✅ VPN connection verified (IP: X.X.X.X matches ProtonVPN)
- ✅ Authelia SSO protecting all services
- ✅ Monitoring dashboards functional

### Issues Encountered
None

### Next Sync
- Scheduled for: YYYY-MM-DD (3 months)
```

---

## Sync Log

Use this table to track synchronization history:

| Date | Upstream Repo | Reference (tag/commit) | Changes Pulled | Notes |
|------|---------------|----------------------|----------------|-------|
| 2025-11-23 | Initial setup | - | Created Orion-Sentinel-CoreSrv from upstream patterns | Baseline configuration |
| | | | | |
| | | | | |
| | | | | |

---

## Useful Commands

### Compare Files with Upstream

```bash
# Compare compose files
cd ~/upstream-repos
diff -u docker-compose-nas/docker-compose.yml ~/Orion-Sentinel-CoreSrv/compose.yml

# Compare env examples
diff -u docker-compose-nas/.env.example ~/Orion-Sentinel-CoreSrv/env/.env.media.example
```

### Check Image Updates

```bash
# List current images
docker compose config | grep image:

# Check for newer tags on Docker Hub
docker search jellyfin/jellyfin --limit 5
```

### Validate Compose File

```bash
# Check syntax
docker compose config > /dev/null && echo "✅ Valid" || echo "❌ Invalid"

# Show resolved configuration
docker compose config
```

---

## Resources

### Upstream Repositories

- **AdrienPoupa/docker-compose-nas**
  - Repo: https://github.com/AdrienPoupa/docker-compose-nas
  - Wiki: https://github.com/AdrienPoupa/docker-compose-nas/wiki
  - License: MIT

- **navilg/media-stack**
  - Repo: https://github.com/navilg/media-stack
  - Docs: https://github.com/navilg/media-stack/blob/main/README.md
  - License: GPL-3.0

### Related Guides

- Trash-Guides: https://trash-guides.info/
- Traefik Documentation: https://doc.traefik.io/traefik/
- Authelia Documentation: https://www.authelia.com/
- Gluetun Wiki: https://github.com/qdm12/gluetun/wiki

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
