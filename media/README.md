# Media Stack: Jellyfin + *arr + qBittorrent + VPN

## Overview

The media stack provides a complete automated media downloading, organizing, and streaming solution with privacy protection via VPN.

## Profiles

### media-core
Core media services for downloading, organizing, and streaming:
- Jellyfin (media server)
- Sonarr (TV show management)
- Radarr (movie management)
- Bazarr (subtitle management)
- Prowlarr (indexer manager)
- qBittorrent (torrent client, behind VPN)
- Jellyseerr (media request portal)
- VPN (Gluetun with ProtonVPN)

### media-ai
AI-powered media enhancement:
- Recommendarr (AI recommendations based on viewing habits)

## What Lives Here

```
media/
├── config/                # Service configurations
│   ├── jellyfin/          # Jellyfin config and cache
│   ├── qbittorrent/       # qBittorrent settings
│   ├── sonarr/            # Sonarr config and database
│   ├── radarr/            # Radarr config and database
│   ├── bazarr/            # Bazarr config (optional)
│   ├── prowlarr/          # Prowlarr config and indexers
│   ├── jellyseerr/        # Jellyseerr config
│   └── recommendarr/      # Recommendarr config
└── README.md              # This file
```

## Media Download Flow

```
1. User Request
   ↓
   [Jellyseerr] ← User requests movie/TV show
   ↓
2. Management Decision
   ↓
   [Sonarr/Radarr] ← Monitors for release, decides quality
   ↓
3. Indexer Search
   ↓
   [Prowlarr] ← Searches configured indexers/trackers
   ↓
4. Download (via VPN)
   ↓
   [VPN Container] → [qBittorrent] ← Downloads torrent
   ↓
5. Import (hardlink, instant)
   ↓
   [Sonarr/Radarr] ← Imports to library with hardlink
   ↓
6. Playback
   ↓
   [Jellyfin] ← Streams to user devices
```

## Services

### Jellyfin

**Purpose:** Self-hosted media server (alternative to Plex, Emby)

**Key Features:**
- Stream movies, TV shows, music, photos
- Multiple user profiles with watch state tracking
- Mobile apps (iOS, Android), TV apps, web browser
- Hardware transcoding (GPU acceleration)
- No subscription fees, fully open source

**Access:**
- Web UI: `https://jellyfin.local`
- Default: Protected by Authelia (can be exempted for family access)

**Configuration:**
- Libraries: `/library/movies`, `/library/tv`
- Metadata providers: TMDB, TVDB, OMDb

### Sonarr

**Purpose:** TV show management and automation

**Key Features:**
- Automatically downloads new episodes as they air
- Quality profiles (1080p, 4K, etc.)
- Series monitoring (all episodes, future only, etc.)
- Integration with Prowlarr for indexer management
- Rename files to standard format

**Access:**
- Web UI: `https://sonarr.local` (protected by Authelia)

**Configuration:**
- Root folder: `/library/tv`
- Download client: qBittorrent (via VPN)
- Indexer manager: Prowlarr

### Radarr

**Purpose:** Movie management and automation

**Key Features:**
- Automatically downloads new movies on release
- Quality profiles (1080p, 4K, HDR, etc.)
- Custom format scoring (prefer specific release groups)
- Integration with Prowlarr for indexer management
- Rename files to standard format

**Access:**
- Web UI: `https://radarr.local` (protected by Authelia)

**Configuration:**
- Root folder: `/library/movies`
- Download client: qBittorrent (via VPN)
- Indexer manager: Prowlarr

### Bazarr (Optional)

**Purpose:** Subtitle management and automation

**Key Features:**
- Automatically downloads subtitles for movies and TV shows
- Multiple subtitle providers (OpenSubtitles, Subscene, etc.)
- Language preferences and fallbacks
- Integration with Sonarr and Radarr

**Access:**
- Web UI: `https://bazarr.local` (protected by Authelia)

**Configuration:**
- Sonarr/Radarr integration
- Subtitle providers and API keys
- Language preferences

### Prowlarr

**Purpose:** Indexer manager for Sonarr/Radarr

**Key Features:**
- Centralized indexer configuration
- Automatic sync to Sonarr/Radarr
- Support for 500+ indexers (public and private trackers)
- Indexer health monitoring

**Access:**
- Web UI: `https://prowlarr.local` (protected by Authelia)

**Configuration:**
- Add indexers (public trackers or private with API keys)
- Connect Sonarr and Radarr (they auto-sync indexers)

### qBittorrent

**Purpose:** Torrent client for downloading media

**Key Features:**
- Lightweight, feature-rich torrent client
- Web UI for remote management
- Sequential downloading (for streaming during download)
- IP binding to VPN interface (extra safety)

**Access:**
- Web UI: `https://qbit.local` (protected by Authelia)
- **CRITICAL:** Only accessible via VPN container port forwarding

**Configuration:**
- Downloads: `/downloads` (mapped to `${DOWNLOAD_ROOT}`)
- Network: Forced through VPN container (no direct internet access)
- WebUI: Exposed via VPN container port

**Security:**
- ALL traffic goes through VPN
- IP binding prevents leaks if VPN disconnects
- Isolated on `orion_vpn` network

### VPN (Gluetun)

**Purpose:** VPN container that routes qBittorrent traffic through ProtonVPN

**Key Features:**
- Lightweight VPN client (supports 30+ providers)
- Kill switch (blocks traffic if VPN disconnects)
- Port forwarding support (for better torrent seeding)
- Health checks and auto-reconnect

**Access:**
- No direct UI (check logs for connection status)

**Configuration:**
- Provider: ProtonVPN (configurable in `env/.env.media`)
- Server: Auto-selected or choose specific country
- Local network: Allows LAN access to qBittorrent UI

**Verification:**
```bash
# Check VPN is connected
docker compose logs vpn | grep -i "connected"

# Verify qBittorrent IP matches VPN
docker compose exec qbittorrent curl ifconfig.me
# Compare with your ISP IP (should be different)
curl ifconfig.me
```

### Jellyseerr

**Purpose:** Media request portal for users

**Key Features:**
- User-friendly interface for requesting movies/TV shows
- Integration with Sonarr/Radarr (auto-submits requests)
- User management and request approval workflow
- Email notifications for request status

**Access:**
- Web UI: `https://requests.local` (protected by Authelia)

**Configuration:**
- Connect to Jellyfin (for library sync)
- Connect to Sonarr/Radarr (for request handling)
- User permissions (auto-approve, request limits)

### Recommendarr

**Purpose:** AI-powered media recommendations

**Key Features:**
- Analyzes Jellyfin watch history
- Provides personalized movie/TV show recommendations
- Integration with Sonarr/Radarr (auto-add recommendations)
- Optional Trakt.tv integration for social recommendations

**Access:**
- Web UI: `https://recommend.local` (protected by Authelia)

**Configuration:**
- Connect to Jellyfin (for watch history)
- Connect to Sonarr/Radarr (for adding recommendations)
- Optional: Trakt.tv API credentials

## Directory Layout (Hardlink-Friendly)

This setup follows Trash-Guides recommendations for optimal performance:

```
/srv/orion-sentinel-core-sentinel-core/media/
├── torrents/              # qBittorrent downloads here
│   ├── movies/            # Movie torrents
│   │   └── Movie.Title.2024.1080p/
│   │       └── Movie.Title.2024.1080p.mkv
│   └── tv/                # TV show torrents
│       └── Show.Title.S01E01.1080p/
│           └── Show.Title.S01E01.1080p.mkv
└── library/               # Jellyfin reads from here
    ├── movies/            # Organized movies
    │   └── Movie Title (2024)/
    │       └── Movie Title (2024).mkv  ← Hardlink to torrent
    └── tv/                # Organized TV shows
        └── Show Title/
            └── Season 01/
                └── Show Title S01E01.mkv  ← Hardlink to torrent
```

### Why Hardlinks?

**Without hardlinks (copy/move):**
- Slow: Copying a 50GB movie takes minutes
- Wasteful: Uses 2x disk space (one in torrents, one in library)

**With hardlinks:**
- Instant: Hardlink created in milliseconds
- Efficient: One physical file, two directory entries
- Safe: Can delete from torrents without affecting library

**Requirements:**
- Downloads and library must be on same filesystem
- Filesystem must support hardlinks (ext4, XFS, BTRFS, ZFS)

## Initial Setup Workflow

### 1. Start Services

```bash
docker compose --profile media-core up -d
```

### 2. Configure VPN

Edit `env/.env.media`:

```bash
VPN_SERVICE_PROVIDER=protonvpn
OPENVPN_USER=your-protonvpn-username
OPENVPN_PASSWORD=your-protonvpn-password
SERVER_COUNTRIES=Netherlands
LOCAL_NETWORK=192.168.1.0/24  # Adjust to your LAN
```

Restart VPN:

```bash
docker compose up -d vpn
docker compose logs -f vpn
```

Verify connection:

```bash
docker compose exec vpn curl ifconfig.me
# Should show VPN IP, not your ISP IP
```

### 3. Configure Prowlarr

1. Access: `https://prowlarr.local`
2. Add indexers:
   - Settings → Indexers → Add Indexer
   - Add public trackers (1337x, RARBG proxies, etc.)
   - Add private trackers if you have accounts
3. Connect to Sonarr/Radarr:
   - Settings → Apps → Add Application
   - Add Sonarr: `http://sonarr:8989`
   - Add Radarr: `http://radarr:7878`
   - Use API keys from their respective UIs

### 4. Configure Sonarr

1. Access: `https://sonarr.local`
2. Add download client:
   - Settings → Download Clients → Add
   - qBittorrent:
     - Host: `vpn` (service name)
     - Port: `8080`
     - Username/password from qBittorrent UI
3. Add root folder:
   - Settings → Media Management → Root Folders
   - Add: `/library/tv`
4. Indexers auto-sync from Prowlarr

### 5. Configure Radarr

1. Access: `https://radarr.local`
2. Add download client:
   - Settings → Download Clients → Add
   - qBittorrent:
     - Host: `vpn`
     - Port: `8080`
     - Username/password from qBittorrent UI
3. Add root folder:
   - Settings → Media Management → Root Folders
   - Add: `/library/movies`
4. Indexers auto-sync from Prowlarr

### 6. Configure qBittorrent

1. Access: `https://qbit.local`
2. Default credentials: `admin` / `adminadmin` (change immediately!)
3. Configure:
   - Downloads → Default Save Path: `/downloads`
   - Connection → Listen on interface: `tun0` (VPN interface)
   - WebUI → Change password

### 7. Configure Jellyfin

1. Access: `https://jellyfin.local`
2. Complete setup wizard
3. Add libraries:
   - Movies: `/library/movies`
   - TV Shows: `/library/tv`
4. Configure metadata providers (TMDB, TVDB)

### 8. Configure Jellyseerr

1. Access: `https://requests.local`
2. Complete setup wizard
3. Connect to Jellyfin:
   - URL: `http://jellyfin:8096`
   - API key: From Jellyfin settings
4. Connect to Sonarr:
   - URL: `http://sonarr:8989`
   - API key: From Sonarr settings
5. Connect to Radarr:
   - URL: `http://radarr:7878`
   - API key: From Radarr settings

### 9. (Optional) Configure Recommendarr

1. Access: `https://recommend.local`
2. Connect to services (similar to Jellyseerr)
3. Configure recommendation preferences

## Troubleshooting

### VPN Not Connecting

```bash
# Check VPN logs
docker compose logs vpn

# Common issues:
# - Wrong credentials
# - Invalid server country
# - Firewall blocking VPN ports

# Test VPN manually
docker compose exec vpn ping 1.1.1.1
docker compose exec vpn curl ifconfig.me
```

### qBittorrent Not Accessible

```bash
# Check if VPN container is running
docker compose ps vpn

# Check if port is exposed from VPN container
docker compose port vpn 8080

# Verify qBittorrent is using VPN network
docker compose ps qbittorrent | grep -i network
```

### Downloads Not Starting

```bash
# Check Prowlarr indexers
# Settings → Indexers → Test All

# Check Sonarr/Radarr download client
# Settings → Download Clients → Test

# Check qBittorrent connection from *arr apps
# Should show "Connected" status
```

### Hardlinks Not Working

```bash
# Verify same filesystem
df -h /srv/orion-sentinel-core-sentinel-core/media/torrents
df -h /srv/orion-sentinel-core-sentinel-core/media/library
# Should show same device

# Test hardlink manually
cd /srv/orion-sentinel-core-sentinel-core/media/torrents/movies
touch test.txt
ln test.txt /srv/orion-sentinel-core-sentinel-core/media/library/movies/test.txt
ls -li /srv/orion-sentinel-core-sentinel-core/media/torrents/movies/test.txt
ls -li /srv/orion-sentinel-core-sentinel-core/media/library/movies/test.txt
# Same inode number = hardlink works
```

## TODO

- [ ] Configure quality profiles in Sonarr/Radarr (1080p, 4K, etc.)
- [ ] Set up custom formats for preferred release groups
- [ ] Configure Bazarr subtitle providers
- [ ] Add private trackers to Prowlarr (if you have accounts)
- [ ] Set up qBittorrent categories for better organization
- [ ] Configure Jellyfin hardware transcoding (if GPU available)
- [ ] Set up Jellyseerr notification webhooks
- [ ] Configure Recommendarr Trakt.tv integration
- [ ] Add media cleanup automation (Cleanuparr/Decluttarr)
- [ ] Set up monitoring for download speeds and disk usage

## References

- Trash-Guides: https://trash-guides.info/
- Jellyfin: https://jellyfin.org/docs/
- Sonarr: https://wiki.servarr.com/sonarr
- Radarr: https://wiki.servarr.com/radarr
- Prowlarr: https://wiki.servarr.com/prowlarr
- qBittorrent: https://github.com/qbittorrent/qBittorrent/wiki
- Gluetun: https://github.com/qdm12/gluetun
- Jellyseerr: https://github.com/Fallenbagel/jellyseerr

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
