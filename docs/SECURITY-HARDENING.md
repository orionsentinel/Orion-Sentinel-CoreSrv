# Security Hardening Guide

This document describes the security hardening measures implemented in Orion-Sentinel-CoreSrv.

## Table of Contents

1. [Network Segmentation](#network-segmentation)
2. [TLS & HTTPS Enforcement](#tls--https-enforcement)
3. [Zero-Trust Authentication](#zero-trust-authentication)
4. [Security Headers](#security-headers)
5. [Container Security](#container-security)
6. [Rate Limiting & DDoS Protection](#rate-limiting--ddos-protection)
7. [Health Checks & Auto-Healing](#health-checks--auto-healing)
8. [VPN Isolation](#vpn-isolation)
9. [Secrets Management](#secrets-management)
10. [Audit & Monitoring](#audit--monitoring)

---

## Network Segmentation

### Docker Networks

The stack uses dedicated Docker networks to isolate services by function:

- **`orion_proxy`** - HTTP services behind Traefik reverse proxy
  - All services with web UIs attach here
  - Traefik routes external traffic to internal services
  - Authelia SSO intercepts all requests for authentication

- **`orion_internal`** - Internal service-to-service communication
  - *arr apps communicate with qBittorrent, Jellyfin
  - Prometheus scrapes metrics from services
  - Loki collects logs from Promtail
  - No direct external access

- **`orion_vpn`** - VPN container + qBittorrent (complete isolation)
  - qBittorrent shares network namespace with VPN container
  - ALL qBittorrent traffic exits via VPN tunnel
  - WebUI accessible via Traefik through VPN container port
  - Firewall blocks non-VPN traffic

- **`orion_monitoring`** - Observability stack
  - Prometheus, Loki, Grafana, Promtail, node_exporter, cAdvisor
  - Metrics and logs collection isolated from application traffic

### Firewall Rules

On the host, configure `ufw` or `iptables`:

```bash
# Allow SSH (adjust port if needed)
sudo ufw allow 22/tcp

# Allow HTTP/HTTPS for Traefik
sudo ufw allow 80/tcp
sudo ufw allow 443/tcp

# Optionally allow Loki for remote Promtail agents (LAN only)
# sudo ufw allow from 192.168.0.0/16 to any port 3100 proto tcp

# Enable firewall
sudo ufw enable
```

---

## TLS & HTTPS Enforcement

### Automatic HTTP → HTTPS Redirect

All HTTP traffic on port 80 is automatically redirected to HTTPS (port 443) with a **permanent 301** redirect.

**Configuration:** `core/traefik/traefik.yml`

```yaml
entryPoints:
  web:
    address: ":80"
    http:
      redirections:
        entryPoint:
          to: websecure
          scheme: https
          permanent: true
```

### TLS Configuration

- **Minimum TLS version:** TLS 1.2
- **Cipher suites:** Modern, secure ciphers (ECDHE, AES-GCM, ChaCha20-Poly1305)
- **Curves:** CurveP521, CurveP384
- **SNI strict mode:** Enabled (prevents IP-based access bypass)

**Configuration:** `core/traefik/dynamic/security.yml`

### Certificate Management

#### Let's Encrypt (DNS-01 Challenge)

Uncomment the `certificatesResolvers` section in `core/traefik/traefik.yml` and configure:

1. Set DNS provider in `.env.core`:
   ```bash
   TRAEFIK_ACME_EMAIL=your-email@example.com
   TRAEFIK_ACME_DNS_PROVIDER=cloudflare  # or route53, digitalocean, etc.
   ```

2. Add provider-specific credentials (e.g., for Cloudflare):
   ```bash
   CF_API_EMAIL=your-email@example.com
   CF_API_KEY=your-global-api-key
   ```

3. Restart Traefik:
   ```bash
   ./scripts/orionctl.sh restart traefik
   ```

#### Self-Signed Certificates (for testing)

For local testing without Let's Encrypt:

```bash
# Generate self-signed cert
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout /srv/orion-sentinel-core/config/traefik/certs/self-signed.key \
  -out /srv/orion-sentinel-core/config/traefik/certs/self-signed.crt \
  -subj "/CN=*.local"

# Add to Traefik dynamic config
# See Traefik docs: https://doc.traefik.io/traefik/https/tls/
```

---

## Zero-Trust Authentication

### Authelia SSO

All admin services are protected by Authelia ForwardAuth by default:

- **Default policy:** `deny` (explicit allow required)
- **MFA:** TOTP (Time-based One-Time Password) enabled
- **Brute-force protection:** Max 5 retries in 10 minutes, 15-minute ban
- **Session management:** 1-hour expiration, 15-minute inactivity timeout

**Protected services:**
- Traefik dashboard (`traefik.local`)
- Prometheus (`prometheus.local`)
- Grafana (`grafana.local`)
- Uptime Kuma (`status.local`)
- Sonarr, Radarr, Bazarr, Prowlarr, Jellyseerr
- qBittorrent WebUI (`qbit.local`)
- Recommendarr (`recommend.local`)
- Homepage (`home.local`)
- Nextcloud (`cloud.local`)
- SearXNG (`search.local`) - optionally public

### User Management

1. **Create user password hash:**
   ```bash
   docker run --rm -it authelia/authelia:4.38.6 authelia hash-password
   ```

2. **Add user to** `core/authelia/users.yml`:
   ```yaml
   users:
     yorgos:
       displayname: "Yorgos"
       password: "$argon2id$v=19$m=65536,t=3,p=4$..."
       email: "you@example.com"
       groups:
         - admins
   ```

3. **Restart Authelia:**
   ```bash
   ./scripts/orionctl.sh restart authelia
   ```

### Access Control Rules

**Edit:** `core/authelia/configuration.yml`

```yaml
access_control:
  default_policy: deny
  rules:
    # Admins get access to everything
    - domain: "*.local"
      policy: one_factor
      subject:
        - "group:admins"
    
    # Example: Allow unauthenticated Jellyfin streaming
    - domain: jellyfin.local
      resources:
        - "^/web.*"
        - "^/Videos.*"
      policy: bypass
    
    # Example: LAN-only SearXNG (no auth)
    - domain: search.local
      policy: bypass
      networks:
        - 192.168.0.0/16
```

---

## Security Headers

All services receive **OWASP-recommended security headers** via Traefik middleware.

**Configuration:** `core/traefik/dynamic/security.yml`

### Headers Applied

| Header | Value | Purpose |
|--------|-------|---------|
| `X-Frame-Options` | `DENY` | Prevent clickjacking |
| `Strict-Transport-Security` | `max-age=31536000; includeSubDomains; preload` | Enforce HTTPS for 1 year |
| `X-Content-Type-Options` | `nosniff` | Prevent MIME sniffing |
| `X-XSS-Protection` | `1; mode=block` | Enable XSS filter (legacy browsers) |
| `Referrer-Policy` | `strict-origin-when-cross-origin` | Limit referrer leakage |
| `Permissions-Policy` | `geolocation=(), microphone=(), camera=()` | Disable browser features |
| `X-Robots-Tag` | `noindex, nofollow` | Prevent search indexing |

---

## Container Security

### Capabilities Management

Containers run with **least privilege**:

- **Default:** `cap_drop: ALL` (drop all Linux capabilities)
- **VPN container:**
  - `cap_add: NET_ADMIN` (required for tunnel)
  - `cap_drop: ALL` (then add only NET_ADMIN)
  - `devices: /dev/net/tun` (TUN/TAP device access)

- **node_exporter:**
  - `cap_drop: ALL`
  - `read_only: true` (read-only root filesystem)

### Security Options

All containers use:

```yaml
security_opt:
  - no-new-privileges:true
```

This prevents privilege escalation attacks.

### User Namespaces

Media services run as non-root user:

```yaml
environment:
  - PUID=1001  # orion user
  - PGID=1001  # orion group
user: "${PUID}:${PGID}"  # Prometheus, Grafana, Loki
```

---

## Rate Limiting & DDoS Protection

### Global Rate Limits

**Middleware:** `rate-limit@file`

- **Average:** 100 requests/second
- **Burst:** 50 requests
- **Applied to:** General services

### Auth Endpoint Protection

**Middleware:** `rate-limit-auth@file`

- **Average:** 10 requests/minute
- **Burst:** 20 requests
- **Applied to:** Authelia authentication endpoint

**Configuration:** `core/traefik/dynamic/security.yml`

### IP Whitelisting (Optional)

Restrict admin tools to LAN IPs only:

```yaml
middlewares:
  lan-only:
    ipWhiteList:
      sourceRange:
        - "192.168.0.0/16"
        - "172.16.0.0/12"
        - "10.0.0.0/8"
```

Apply to service:

```yaml
labels:
  - "traefik.http.routers.admin-tool.middlewares=lan-only@file,authelia-forwardauth@file"
```

---

## Health Checks & Auto-Healing

### Health Checks

Critical services have health checks:

**VPN (Gluetun):**
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -q --spider http://localhost:9999/v1/openvpn/status || exit 1"]
  interval: 60s
  timeout: 10s
  retries: 3
  start_period: 30s
```

**Authelia:**
```yaml
healthcheck:
  test: ["CMD-SHELL", "wget -q --spider http://localhost:9091/api/health || exit 1"]
  interval: 30s
```

**Nextcloud DB (PostgreSQL):**
```yaml
healthcheck:
  test: ["CMD-SHELL", "pg_isready -U nextcloud"]
  interval: 30s
```

### Auto-Healing

**Autoheal** automatically restarts unhealthy containers.

**Enable for a service:**

```yaml
labels:
  - "autoheal=true"
```

**Services with autoheal enabled:**
- VPN (critical for qBittorrent)
- Authelia (critical for SSO)

---

## VPN Isolation

### Architecture

```
Internet → VPN Container (Gluetun) ⟷ qBittorrent
                 ↓
           orion_internal ← Traefik (WebUI only)
```

### Security Features

1. **Network namespace sharing:**
   - qBittorrent uses `network_mode: "service:vpn"`
   - **ALL** qBittorrent traffic exits via VPN

2. **Firewall:**
   - Gluetun built-in firewall blocks non-VPN traffic
   - `FIREWALL=on` enforces killswitch

3. **Health check dependency:**
   - qBittorrent waits for VPN `service_healthy` before starting
   - Ensures VPN is connected before torrenting

4. **WebUI routing:**
   - qBittorrent WebUI port (`8080`) exposed via VPN container
   - Traefik routes `qbit.local` → VPN container → qBittorrent
   - WebUI protected by Authelia SSO

### Verify VPN Isolation

```bash
# Check qBittorrent's public IP (should be VPN IP, not your ISP IP)
docker exec qbittorrent curl -s ifconfig.me
```

---

## Secrets Management

### Environment Variables

**Never commit secrets to Git.**

1. **Copy env examples:**
   ```bash
   cp env/.env.core.example env/.env.core
   cp env/.env.media.example env/.env.media
   ```

2. **Generate secrets:**
   ```bash
   # Auth secrets (use same value 3 times or generate unique)
   openssl rand -hex 32  # AUTHELIA_JWT_SECRET
   openssl rand -hex 32  # AUTHELIA_SESSION_SECRET
   openssl rand -hex 32  # AUTHELIA_STORAGE_ENCRYPTION_KEY
   ```

3. **Set restrictive permissions:**
   ```bash
   chmod 600 env/.env.*
   ```

### Secrets Rotation

**See:** `docs/SECRETS.md` for rotation procedures.

**Critical secrets:**
- Authelia JWT/session/storage keys
- Database passwords
- VPN credentials
- Nextcloud admin password
- Grafana admin password

**Rotation schedule:**
- **Critical services:** Every 90 days
- **Non-critical:** Annually or on breach

---

## Audit & Monitoring

### Access Logs

**Traefik access logs:**
- Enabled by default (buffered)
- Location: stdout (captured by Promtail → Loki)

**Filter in Grafana Explore:**
```logql
{container_name="traefik"} |= "access"
```

### Authentication Attempts

**Authelia logs failed/successful logins:**

```logql
{container_name="authelia"} |= "authentication"
```

### Metrics Monitoring

**Prometheus scrapes:**
- **Traefik metrics:** `:8082/metrics` (request rates, errors, latencies)
- **node_exporter:** Host CPU, RAM, disk, network
- **cAdvisor:** Container CPU, RAM, disk I/O
- **Uptime Kuma:** Service availability

**Alert examples (configure in Prometheus):**
- High failed auth rate → possible brute-force
- VPN container unhealthy → qBittorrent isolated
- Disk usage >90% → cleanup required

---

## Security Checklist

### Initial Setup

- [ ] Generate all secrets with `openssl rand -hex 32`
- [ ] Set `chmod 600` on all `.env.*` files
- [ ] Configure host firewall (ufw/iptables)
- [ ] Create Authelia user with strong password + TOTP
- [ ] Test Authelia SSO flow with a protected service
- [ ] Verify VPN killswitch (check qBittorrent public IP)
- [ ] Enable Traefik ACME for production TLS certs
- [ ] Review and customize access control rules
- [ ] Set up log retention and monitoring alerts

### Ongoing Maintenance

- [ ] Rotate secrets quarterly (see `docs/SECRETS.md`)
- [ ] Review Authelia logs for suspicious activity monthly
- [ ] Update Docker images (`./scripts/orionctl.sh pull`) monthly
- [ ] Backup config directory weekly (`./scripts/backup.sh`)
- [ ] Test disaster recovery procedure quarterly
- [ ] Audit Traefik access logs for anomalies
- [ ] Monitor Prometheus alerts in Grafana

---

## References

- **Traefik Security:** https://doc.traefik.io/traefik/https/overview/
- **Authelia Docs:** https://www.authelia.com/
- **OWASP Security Headers:** https://owasp.org/www-project-secure-headers/
- **Docker Security:** https://docs.docker.com/engine/security/
- **Gluetun VPN:** https://github.com/qdm12/gluetun

---

**Last Updated:** 2024-11-23  
**Maintainer:** Orion Sentinel CoreSrv Team
