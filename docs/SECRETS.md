# Secrets Management Guide

## Overview

This document explains how secrets (passwords, API keys, tokens) are managed in Orion-Sentinel-CoreSrv and provides best practices for keeping them secure.

## Where Secrets Live

### Current Approach: Environment Files

All secrets are stored in `.env.*` files in the `env/` directory:

```
env/
├── .env.core              # Traefik + Authelia secrets
├── .env.media             # Media stack secrets (VPN, API keys)
├── .env.monitoring        # Monitoring secrets (Grafana password)
├── .env.cloud             # Nextcloud secrets
├── .env.search            # SearXNG secrets
├── .env.home-automation   # Home Assistant secrets
└── .env.maintenance       # Maintenance tool secrets
```

**These files are git-ignored and never committed to the repository.**

### What's in Each File

**`.env.core`:**
- `AUTHELIA_JWT_SECRET` - JWT token signing key
- `AUTHELIA_SESSION_SECRET` - Session encryption key
- `AUTHELIA_STORAGE_ENCRYPTION_KEY` - Database encryption key
- Optional: ACME/Let's Encrypt credentials

**`.env.media`:**
- `VPN_WIREGUARD_PRIVATE_KEY` - VPN private key
- `SONARR_API_KEY`, `RADARR_API_KEY`, etc. - Service API keys
- `JELLYFIN_API_KEY` - Jellyfin API access
- `TRAKT_CLIENT_ID`, `TRAKT_CLIENT_SECRET` - Trakt.tv OAuth

**`.env.monitoring`:**
- `GRAFANA_ADMIN_PASSWORD` - Grafana admin password

**`.env.cloud`:**
- `NEXTCLOUD_ADMIN_PASSWORD` - Nextcloud admin password
- `POSTGRES_PASSWORD` - PostgreSQL database password

## Security Properties

### ✅ Safe to Share Repository

**The repository itself contains NO secrets:**
- ✅ Safe to push to GitHub
- ✅ Safe to share with others
- ✅ Can be public or private

**What's in Git:**
- `.env.*.example` files (templates with placeholders)
- `compose.yml` references `${VARIABLES}` but no values
- Config file templates (no real passwords)

### ✅ Secrets Protected by `.gitignore`

The `.gitignore` file explicitly blocks:

```gitignore
# Environment files with secrets
.env
env/*.env
!env/*.env.example

# Authelia user database
core/authelia/users.yml
```

### ⚠️ Backup Security

**Backups contain secrets!**

Backup archives (`/srv/orion-sentinel-core/backups/*.tar.gz`) include:
- All `.env.*` files
- Authelia users database (with password hashes)
- Service configs (may contain API keys)

**Therefore:**
- ✅ Encrypt backups before uploading to cloud
- ✅ Restrict access to backup directory (chmod 700)
- ✅ Use secure transfer (SFTP, encrypted rclone, etc.)

## Generating Secrets

### Authelia Secrets (JWT, Session, Storage)

Generate with OpenSSL:

```bash
# Generate 3 random secrets (32 bytes hex)
openssl rand -hex 32    # JWT_SECRET
openssl rand -hex 32    # SESSION_SECRET
openssl rand -hex 32    # STORAGE_ENCRYPTION_KEY
```

Paste into `.env.core`:

```bash
AUTHELIA_JWT_SECRET=a1b2c3d4e5f6...   # ← Paste here
AUTHELIA_SESSION_SECRET=f9e8d7c6...   # ← Paste here
AUTHELIA_STORAGE_ENCRYPTION_KEY=...   # ← Paste here
```

### Authelia User Passwords

Generate password hash for `users.yml`:

```bash
docker run --rm -it authelia/authelia:latest \
  authelia crypto hash generate argon2 --password 'MySecurePassword123!'
```

Output:
```
Digest: $argon2id$v=19$m=65536,t=3,p=4$abc123...
```

Copy the hash to `core/authelia/users.yml`:

```yaml
users:
  yorgos:
    password: "$argon2id$v=19$m=65536,t=3,p=4$abc123..."  # ← Paste hash here
```

### VPN WireGuard Key

Generate WireGuard private key:

```bash
wg genkey
```

Or use ProtonVPN's provided key from account settings.

### Service API Keys

Most service API keys are auto-generated on first startup:

1. Start the service
2. Access web UI (via Authelia)
3. Settings → API → Generate API Key
4. Copy key to `.env.media`

**Example (Sonarr):**
1. Access `https://sonarr.local`
2. Settings → General → Security → API Key
3. Click "Regenerate" or copy existing
4. Add to `.env.media`:
   ```bash
   SONARR_API_KEY=abc123def456...
   ```

## Secret Rotation

**When to rotate secrets:**
- Every 12 months (routine rotation)
- After suspected compromise
- When team member leaves (if secrets were shared)
- After security incident

### Rotation Procedure

#### 1. Rotate Authelia Secrets

```bash
# Generate new secrets
NEW_JWT=$(openssl rand -hex 32)
NEW_SESSION=$(openssl rand -hex 32)
NEW_STORAGE=$(openssl rand -hex 32)

# Update .env.core
nano env/.env.core

# Restart Authelia
docker compose restart authelia

# Test login
curl -k https://auth.local
```

#### 2. Rotate Service API Keys

**Example: Sonarr**

1. Access Sonarr web UI
2. Settings → General → Security → API Key → Regenerate
3. Update `.env.media` with new key
4. Restart services that use Sonarr API (Jellyseerr, Prowlarr, Recommendarr)
5. Test integration

#### 3. Rotate Grafana Password

```bash
# Access Grafana container
docker compose exec grafana grafana-cli admin reset-admin-password NewPassword123

# Update .env.monitoring
nano env/.env.monitoring

# Restart Grafana
docker compose restart grafana
```

## Access Control

### File Permissions

Restrict access to secrets on the host:

```bash
# Env files - owner read/write only
chmod 600 env/.env.*

# Authelia users database
chmod 600 core/authelia/users.yml

# Config directory - owner only
chmod 700 /srv/orion-sentinel-core/config

# Backup directory - owner only
chmod 700 /srv/orion-sentinel-core/backups
```

### User Access

**Who should have access to secrets:**
- ✅ Root user
- ✅ Your primary user account (sudo access)
- ❌ Other users on the system
- ❌ Web server processes
- ❌ Docker containers (only via env vars)

## Alternative: Docker Secrets (Future)

For higher security, consider migrating to Docker secrets:

### Current (Environment Variables)

```yaml
environment:
  - AUTHELIA_JWT_SECRET=${AUTHELIA_JWT_SECRET}
```

**Pros:**
- Simple to set up
- Easy to manage
- Works everywhere

**Cons:**
- Visible in `docker inspect`
- Stored in plain text on disk
- Passed via environment variables

### Future (Docker Secrets)

```yaml
secrets:
  - authelia_jwt_secret

environment:
  - AUTHELIA_JWT_SECRET_FILE=/run/secrets/authelia_jwt_secret
```

**Pros:**
- Not visible in `docker inspect`
- Encrypted at rest (if using Swarm)
- Better audit trail
- Can integrate with Vault, etc.

**Cons:**
- More complex setup
- Requires code changes in some services

**Migration path documented in `docs/DOCKER-SECRETS.md` (future)**

## Secret Storage Best Practices

### ✅ DO

1. **Use a password manager**
   - Store all secrets in Bitwarden, 1Password, KeePassXC, etc.
   - Tag with "orion-coresrv" for easy finding
   - Include notes (what service, when generated)

2. **Keep offline backup**
   - Print critical secrets (Authelia, root passwords)
   - Store in safe/fireproof location
   - Update when rotated

3. **Document secret locations**
   - This file (SECRETS.md)
   - Password manager notes
   - Backup manifest (MANIFEST.txt in backups)

4. **Encrypt backups**
   - Always encrypt before sending offsite
   - Use GPG, rclone crypt, or restic encryption

5. **Restrict access**
   - `chmod 600` on .env files
   - `chmod 700` on config directories
   - Firewall rules for remote access

### ❌ DON'T

1. **Never commit secrets to Git**
   - Double-check `.gitignore` works
   - Use `git diff` before committing
   - Enable pre-commit hooks if paranoid

2. **Never share secrets in plain text**
   - No email, Slack, Discord
   - Use password manager sharing features
   - Or encrypted file transfer (GPG)

3. **Never reuse secrets**
   - Each service gets unique API key
   - Each environment (dev/prod) gets unique secrets
   - Never copy from tutorials/examples

4. **Never store in cloud unencrypted**
   - Encrypt before uploading to Dropbox, Google Drive, etc.
   - Use cloud provider encryption features
   - Better: use dedicated secret management (Vault)

## Audit & Monitoring

### Checking for Exposed Secrets

**Scan Git history (paranoid check):**

```bash
# Check if secrets accidentally committed
git log --all --full-history -- "**/env/.env*"

# Should show only .env.*.example files
```

**Check file permissions:**

```bash
# All .env files should be 600 (rw-------)
ls -la env/.env.*

# Expected: -rw------- 1 user user ...
```

**Check Docker inspect (what containers see):**

```bash
# View environment variables passed to Authelia
docker inspect authelia | grep -A 20 "Env"

# Should see: AUTHELIA_JWT_SECRET=*** (masked)
```

### Monitoring for Unauthorized Access

**Set up alerts in Authelia:**
- Failed login attempts
- New user added
- Policy changes

**Monitor backup access:**
- Log who accesses `/srv/orion-sentinel-core/backups/`
- Alert on unexpected access

**File integrity monitoring:**
- Use `auditd` to monitor `.env.*` file access
- Alert on modifications outside maintenance windows

## Compromised Secrets

**If you suspect a secret is compromised:**

1. **Immediately rotate** (see Rotation Procedure above)
2. **Check logs** for unauthorized access:
   ```bash
   docker compose logs authelia | grep -i "authentication failed"
   docker compose logs traefik | grep -i "401\|403"
   ```
3. **Review Authelia sessions**:
   - Check for unknown devices/IPs
   - Force logout all sessions
4. **Change all related secrets**:
   - If Authelia compromised → rotate all SSO-protected services
   - If Jellyfin API key compromised → check for unauthorized media access
5. **Document incident**:
   - What was compromised
   - When detected
   - Actions taken
   - Root cause

## Summary

### Current State

- ✅ Secrets stored in `.env.*` files (git-ignored)
- ✅ Repository is safe to share (no secrets in Git)
- ✅ Backups include secrets (must be encrypted)
- ✅ Simple to manage and understand

### Security Checklist

- [ ] All `.env.*` files have `chmod 600`
- [ ] Secrets stored in password manager
- [ ] Offline backup of critical secrets (printed or USB)
- [ ] `.gitignore` verified (`.env` files excluded)
- [ ] Backups encrypted before cloud upload
- [ ] Secret rotation schedule documented (12 months)
- [ ] Team knows where secrets are stored
- [ ] Incident response plan for compromised secrets

### Future Improvements

- [ ] Migrate to Docker secrets for Swarm compatibility
- [ ] Integrate with HashiCorp Vault or similar
- [ ] Set up secret rotation automation
- [ ] Add pre-commit hooks to prevent secret commits
- [ ] Implement secret scanning in CI/CD

---

**Last Updated:** 2025-11-23  
**Maintained By:** Orion Home Lab Team

**CRITICAL REMINDER:** This repository is safe to share because secrets live in `.env.*` files that are git-ignored. Never commit real secrets!
