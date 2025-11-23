# Core Services: Traefik + Authelia

## Overview

The core profile provides the foundational services for the Orion CoreSrv Hub:

- **Traefik v3** - Modern reverse proxy with automatic SSL, routing, and middleware
- **Authelia** - Single Sign-On (SSO) platform with 2FA support

These services protect all other services in the stack with centralized authentication and secure HTTPS access.

## What Lives Here

```
core/
├── traefik/           # Traefik dynamic configuration
│   ├── config.yml     # Dynamic routers and middlewares (future)
│   └── tls.yml        # TLS options (future)
├── authelia/          # Authelia configuration
│   ├── configuration.yml  # Main Authelia config (future)
│   └── users.yml      # User database (future)
└── README.md          # This file
```

## Services

### Traefik

**Purpose:** Reverse proxy that routes all HTTP/HTTPS traffic to appropriate services.

**Key Features:**
- Automatic service discovery via Docker labels
- SSL/TLS termination with Let's Encrypt (ACME)
- Middleware support (rate limiting, auth forwarding, headers)
- Built-in dashboard for monitoring

**Access:**
- Dashboard: `https://traefik.local` (protected by Authelia)

**Configuration:**
- Environment: `env/.env.core`
- Dynamic config: `core/traefik/config.yml` (optional)
- Labels: Defined in `compose.yml` per service

### Authelia

**Purpose:** SSO (Single Sign-On) platform that protects all services with centralized authentication.

**Key Features:**
- User/password authentication with password reset
- Two-factor authentication (TOTP, U2F, WebAuthn)
- Access control policies (per-domain, per-user, per-group)
- Session management with configurable timeout
- Integration with Traefik via ForwardAuth middleware

**Access:**
- Login portal: `https://auth.local`

**Configuration:**
- Environment: `env/.env.core`
- Main config: `core/authelia/configuration.yml` (to be created)
- Users: `core/authelia/users.yml` (to be created)

## How It Works

### Request Flow

```
User Request (https://jellyfin.local)
         |
         v
    [Traefik]
         |
         v
  Check Authelia middleware?
         |
    Yes  |  No
         |
         v
   [Authelia]
         |
    Authenticated?
         |
    Yes  |  No
         |        |
         v        v
   [Jellyfin]  Redirect to auth.local
```

### Authentication Workflow

1. **User accesses protected service** (e.g., `https://sonarr.local`)
2. **Traefik intercepts request** and checks for `authelia@docker` middleware
3. **Traefik forwards to Authelia** for authentication check
4. **Authelia checks session:**
   - ✅ Valid session → Allow access to service
   - ❌ No session → Redirect to `auth.local` for login
5. **User logs in** at `auth.local` (with optional 2FA)
6. **Authelia creates session** and redirects back to original service
7. **Future requests** use session cookie (no re-authentication needed)

### Network Architecture

Traefik and Authelia operate on two networks:

- **orion_proxy** - Public-facing network for receiving HTTP/HTTPS traffic
- **orion_internal** - Backend network for communicating with protected services

```
Internet
   |
   v
[Traefik] (orion_proxy + orion_internal)
   |
   +----> [Authelia] (orion_proxy + orion_internal)
   |
   +----> [Protected Services] (orion_proxy + orion_internal)
```

## Configuration Steps

### 1. Generate Authelia Secrets

Authelia requires three secret keys. Generate them:

```bash
# Generate JWT secret
openssl rand -hex 32

# Generate session secret
openssl rand -hex 32

# Generate storage encryption key
openssl rand -hex 32
```

Add these to `env/.env.core`:

```bash
AUTHELIA_JWT_SECRET=<generated-value>
AUTHELIA_SESSION_SECRET=<generated-value>
AUTHELIA_STORAGE_ENCRYPTION_KEY=<generated-value>
```

### 2. Configure ACME (Let's Encrypt)

For automatic SSL certificates, configure ACME in `env/.env.core`:

```bash
# Your email for Let's Encrypt notifications
ACME_EMAIL=your-email@example.com

# Challenge type: 'http' or 'dns'
ACME_CHALLENGE_TYPE=dns

# DNS provider (if using dns challenge)
ACME_DNS_PROVIDER=cloudflare

# DNS provider credentials (example for Cloudflare)
CLOUDFLARE_EMAIL=your-email@example.com
CLOUDFLARE_API_KEY=your-cloudflare-api-key
```

**Note:** For local-only deployment (*.local domains), you can skip ACME and use self-signed certificates.

### 3. Create Authelia Configuration

Create `core/authelia/configuration.yml`:

```yaml
# See: https://www.authelia.com/configuration/prologue/introduction/
# This is a minimal stub - customize for your needs

server:
  host: 0.0.0.0
  port: 9091

log:
  level: info

jwt_secret: ${AUTHELIA_JWT_SECRET}

default_redirection_url: https://home.local

authentication_backend:
  file:
    path: /config/users.yml

session:
  domain: local
  expiration: 12h
  inactivity: 5m
  secret: ${AUTHELIA_SESSION_SECRET}

storage:
  encryption_key: ${AUTHELIA_STORAGE_ENCRYPTION_KEY}
  local:
    path: /config/db.sqlite3

notifier:
  filesystem:
    filename: /config/notifications.txt

access_control:
  default_policy: deny
  rules:
    # Allow access to auth portal itself
    - domain: auth.local
      policy: bypass
    
    # Protect all other services with 2FA
    - domain: "*.local"
      policy: two_factor
```

### 4. Create Initial Users

Create `core/authelia/users.yml`:

```yaml
# See: https://www.authelia.com/reference/guides/passwords/
# Generate password hash with: docker run authelia/authelia:latest authelia crypto hash generate argon2 --password 'yourpassword'

users:
  admin:
    displayname: "Admin User"
    password: "$argon2id$v=19$m=65536,t=3,p=4$hash-here"
    email: admin@example.com
    groups:
      - admins
```

**Generate password hash:**

```bash
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'your-password-here'
```

### 5. Start Core Services

```bash
docker compose --profile core up -d
```

### 6. Access Authelia

1. Navigate to `https://auth.local`
2. Login with credentials from `users.yml`
3. Configure 2FA (recommended):
   - Go to "Two-Factor Authentication"
   - Scan QR code with authenticator app (Authy, Google Authenticator, etc.)
   - Enter code to verify

## Security Best Practices

### Recommended Configuration

1. **Enable 2FA for all admin users:**
   - Required for accessing sensitive services (qBittorrent, *arr apps, Grafana)
   - Use policy: `two_factor` in access control rules

2. **Use strong session settings:**
   - Expiration: 12 hours (force re-login daily)
   - Inactivity: 5 minutes (logout if inactive)

3. **Separate access policies:**
   - Admin services: Require 2FA + admin group
   - User services (Jellyfin): Allow with 1FA for family members

4. **Rotate secrets regularly:**
   - Change Authelia secrets every 6-12 months
   - Generate new passwords for users periodically

### Example Access Control Rules

```yaml
access_control:
  default_policy: deny
  rules:
    # Auth portal - no auth required
    - domain: auth.local
      policy: bypass
    
    # Public services - require login only
    - domain:
        - jellyfin.local
        - requests.local
      policy: one_factor
    
    # Admin services - require 2FA + admin group
    - domain:
        - traefik.local
        - qbit.local
        - sonarr.local
        - radarr.local
        - prowlarr.local
        - grafana.local
        - prometheus.local
      policy: two_factor
      subject:
        - "group:admins"
    
    # Homepage - require login, any authenticated user
    - domain: home.local
      policy: one_factor
```

## Troubleshooting

### Traefik Issues

**Dashboard not accessible:**
```bash
# Check Traefik logs
docker compose logs -f traefik

# Verify Traefik is running
docker compose ps traefik

# Check Traefik configuration
docker compose exec traefik cat /etc/traefik/traefik.yml
```

**Services not routed:**
```bash
# Check service labels
docker compose config | grep -A 10 "traefik.http.routers"

# Verify networks
docker network ls | grep orion
docker network inspect orion_proxy
```

**SSL certificate errors:**
```bash
# Check ACME storage
docker compose exec traefik ls -la /acme

# Review Traefik logs for ACME challenges
docker compose logs traefik | grep -i acme
```

### Authelia Issues

**Cannot login:**
```bash
# Check Authelia logs
docker compose logs -f authelia

# Verify users.yml syntax
docker compose exec authelia cat /config/users.yml

# Check session storage
docker compose exec authelia ls -la /config
```

**Redirects not working:**
```bash
# Verify session domain matches your domain
docker compose exec authelia env | grep SESSION_DOMAIN

# Check Authelia URL in Traefik middleware
docker compose config | grep -A 5 "authelia"
```

**2FA not working:**
```bash
# Check time sync (TOTP requires accurate time)
date
docker compose exec authelia date

# Verify TOTP secret in database
docker compose exec authelia cat /config/db.sqlite3
```

## TODO

- [ ] Create detailed `configuration.yml` for Authelia with all options documented
- [ ] Add example `users.yml` with multiple user types (admin, family, guest)
- [ ] Configure LDAP backend (optional, for larger households)
- [ ] Set up email notifications for password resets (SMTP config)
- [ ] Add Traefik rate limiting middleware
- [ ] Configure Traefik access logs for security auditing
- [ ] Add Fail2Ban integration for brute-force protection
- [ ] Document backup/restore procedure for Authelia database

## References

- Traefik Documentation: https://doc.traefik.io/traefik/
- Authelia Documentation: https://www.authelia.com/
- Traefik + Authelia Integration: https://www.authelia.com/integration/proxies/traefik/
- Let's Encrypt: https://letsencrypt.org/

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
