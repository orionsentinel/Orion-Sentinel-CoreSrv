# Secrets Management

## Overview

This directory is for storing secrets used by the Orion-Sentinel-CoreSrv stack. **All files in this directory (except this README) are ignored by git** and should never be committed to version control.

## Philosophy

**Secrets should NEVER be committed to git.** This includes:
- Passwords
- API keys
- Certificates
- Private keys
- Database credentials
- OAuth tokens
- Encryption keys

## Where Secrets Are Stored

### Primary Method: Environment Variables

Most secrets are stored in `.env.*` files in the `env/` directory:

```
env/
├── .env.core           # Actual secrets (git-ignored)
├── .env.media          # Actual secrets (git-ignored)
├── .env.monitoring     # Actual secrets (git-ignored)
├── .env.cloud          # Actual secrets (git-ignored)
├── .env.search         # Actual secrets (git-ignored)
├── .env.core.example   # Templates (committed to git)
├── .env.media.example  # Templates (committed to git)
└── ...
```

**How to use:**
1. Copy `.env.*.example` → `.env.*`
2. Replace all `changeme_*` and placeholder values with real secrets
3. Never commit the actual `.env.*` files

### Alternative: Docker Secrets (Optional)

For production deployments, consider using Docker secrets:

```bash
# Create a secret
echo "my-secret-password" | docker secret create nextcloud_db_password -

# Use in compose.yml
services:
  nextcloud-db:
    secrets:
      - nextcloud_db_password
    environment:
      POSTGRES_PASSWORD_FILE: /run/secrets/nextcloud_db_password

secrets:
  nextcloud_db_password:
    external: true
```

**Pros:**
- Encrypted at rest
- Not visible in environment variables
- Better security for production

**Cons:**
- Requires Docker Swarm mode
- More complex setup
- Overkill for home lab (but good practice)

## Generating Secrets

### Random Strings (for encryption keys, JWT secrets, etc.)

```bash
# 32-character hexadecimal string (recommended for Authelia)
openssl rand -hex 32

# 64-character hexadecimal string (extra strong)
openssl rand -hex 64

# Base64-encoded random bytes
openssl rand -base64 32
```

### Password Hashes (for Authelia users)

```bash
# Generate Argon2id hash for Authelia users.yml
docker run --rm authelia/authelia:latest authelia crypto hash generate argon2 --password 'YourPasswordHere'
```

### API Keys

Most services generate API keys in their UI after first startup:
- Sonarr: Settings → General → API Key
- Radarr: Settings → General → API Key
- Prowlarr: Settings → General → API Key
- Jellyfin: Dashboard → API Keys → New API Key

Copy these into your `.env.media` file for other services to use.

## Secret Checklist

When setting up Orion-Sentinel-CoreSrv, you need to generate/configure these secrets:

### Core Services

- [ ] `AUTHELIA_JWT_SECRET` - `openssl rand -hex 32`
- [ ] `AUTHELIA_SESSION_SECRET` - `openssl rand -hex 32`
- [ ] `AUTHELIA_STORAGE_ENCRYPTION_KEY` - `openssl rand -hex 32`
- [ ] `ACME_EMAIL` - Your email for Let's Encrypt
- [ ] Authelia user passwords - Generate with Docker command above

### VPN

- [ ] `OPENVPN_USER` - Your ProtonVPN username
- [ ] `OPENVPN_PASSWORD` - Your ProtonVPN password

### Cloud

- [ ] `NEXTCLOUD_ADMIN_PASSWORD` - Strong password for Nextcloud admin
- [ ] `POSTGRES_PASSWORD` - Strong password for Nextcloud database

### Monitoring

- [ ] `GRAFANA_ADMIN_PASSWORD` - Strong password for Grafana admin

### Search

- [ ] `SEARXNG_SECRET_KEY` - `openssl rand -hex 32`

### Service API Keys (generate after first startup)

- [ ] `SONARR_API_KEY` - From Sonarr UI
- [ ] `RADARR_API_KEY` - From Radarr UI
- [ ] `PROWLARR_API_KEY` - From Prowlarr UI
- [ ] `BAZARR_API_KEY` - From Bazarr UI (optional)
- [ ] `JELLYSEERR_API_KEY` - From Jellyseerr UI
- [ ] `JELLYFIN_API_KEY` - From Jellyfin UI (for Recommendarr)

## Backup Considerations

### What to Backup

**DO backup (encrypted):**
- `.env.*` files (store in password manager or encrypted backup)
- Authelia `users.yml` (contains user accounts)
- Service API keys (document in password manager)

**DO NOT backup to unencrypted storage:**
- Never store secrets in plain text on cloud storage
- Never email secrets to yourself
- Never commit secrets to git (even private repos)

### Recommended: Password Manager

Store all secrets in a password manager:
- **1Password** - Secure Notes with custom fields
- **Bitwarden** - Secure Notes or custom item types
- **KeePassXC** - Local database with strong encryption

Example structure in password manager:

```
Orion-Sentinel-CoreSrv/
├── Core Services/
│   ├── Authelia Secrets (3 keys)
│   ├── Authelia Admin Password
│   └── ACME Email
├── VPN/
│   ├── ProtonVPN Username
│   └── ProtonVPN Password
├── Media Services/
│   ├── Sonarr API Key
│   ├── Radarr API Key
│   └── ...
└── Cloud/
    ├── Nextcloud Admin Password
    └── Postgres Password
```

## Recovery Procedure

If you lose your secrets:

1. **Authelia secrets:** Will need to regenerate and re-login all users
2. **Service API keys:** Regenerate in each service's UI
3. **Database passwords:** Requires database recreation (data loss)
4. **VPN credentials:** Retrieve from ProtonVPN account

**Prevention:** Always keep an encrypted backup of all `.env.*` files.

## Security Best Practices

### 1. Use Strong, Unique Secrets

```bash
# ❌ BAD
POSTGRES_PASSWORD=password123
AUTHELIA_JWT_SECRET=my-secret

# ✅ GOOD
POSTGRES_PASSWORD=$(openssl rand -base64 32)
AUTHELIA_JWT_SECRET=$(openssl rand -hex 32)
```

### 2. Rotate Secrets Regularly

- **Critical services** (Authelia, databases): Every 6-12 months
- **API keys**: When staff changes or on suspicion of compromise
- **VPN credentials**: Per provider's security recommendations

### 3. Limit Secret Exposure

- Use Docker secrets for production (encrypted at rest)
- Don't log secrets (check `docker compose logs`)
- Don't expose secrets in URLs or GET parameters

### 4. Audit Secret Usage

```bash
# Check if secrets are exposed in environment
docker compose config | grep -i password

# Check running containers for environment variables
docker inspect <container> | jq '.[].Config.Env'
```

### 5. Use Minimal Permissions

- Service API keys should have minimal required permissions
- Create separate users in Authelia for different access levels
- Use read-only database users where possible

## This Directory

The `secrets/` directory can be used for:

- **SSL certificates** (if not using ACME)
- **SSH keys** (for git access, backups, etc.)
- **GPG keys** (for encrypted backups)
- **Any other secret files** needed by services

All files here are git-ignored except this README.

Example usage:

```bash
# Generate SSL certificate (if not using Let's Encrypt)
openssl req -x509 -nodes -days 365 -newkey rsa:2048 \
  -keyout secrets/selfsigned.key \
  -out secrets/selfsigned.crt

# Mount in compose.yml
volumes:
  - ./secrets/selfsigned.crt:/etc/ssl/certs/selfsigned.crt:ro
  - ./secrets/selfsigned.key:/etc/ssl/private/selfsigned.key:ro
```

---

## References

- [Docker Secrets Documentation](https://docs.docker.com/engine/swarm/secrets/)
- [Authelia Security Considerations](https://www.authelia.com/overview/security/introduction/)
- [OWASP Secrets Management Cheat Sheet](https://cheatsheetseries.owasp.org/cheatsheets/Secrets_Management_Cheat_Sheet.html)

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team
