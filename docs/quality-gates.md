# Quality Gates & CI/CD Pipeline

This document describes the automated quality gates, CI/CD workflows, and local validation tools for the Orion-Sentinel-CoreSrv repository.

## Overview

The Orion-Sentinel-CoreSrv uses a multi-layered quality assurance approach:

1. **CI Workflows** - Automated checks on every push and PR
2. **Local Preflight** - Pre-deployment validation on your CoreSrv host
3. **Deploy Scripts** - Automated deployment with health checking

## CI/CD Workflows

All CI workflows run automatically on push to `main`/`develop` branches and on pull requests.

### 1. Compose Validation (`compose-validate.yml`)

**What it checks:**
- ✅ All Docker Compose files are syntactically valid
- ✅ YAML files pass linting rules
- ✅ All compose profiles can be validated
- ✅ No secrets are committed to the repository

**Runs on:** Every push and pull request

**What it catches:**
- Invalid YAML syntax
- Missing service dependencies
- Invalid Docker Compose configuration
- Accidentally committed passwords or tokens

**What it cannot catch:**
- Runtime issues (containers failing to start)
- Network connectivity problems
- Missing volumes or incorrect permissions on your host
- Hardware-specific issues (USB devices, network interfaces)

### 2. Smoke Tests (`smoke-test.yml`)

**What it checks:**
- ✅ CI-safe services can start and become healthy
- ✅ HTTP endpoints respond correctly
- ✅ Database-backed services work properly

**Runs on:** Pull requests

**Services tested:**
- Uptime Kuma (simple web service)
- Mealie + PostgreSQL (database-backed service)

**What it catches:**
- Services that fail to start
- Container health check failures
- Basic connectivity issues

**What it cannot test:**
- Services requiring host networking (node-exporter, cAdvisor)
- Services requiring special hardware (Zigbee, cameras, GPUs)
- Services requiring privileged mode
- Full integration between all services

### 3. Existing Workflows

The repository also includes:
- **CI Workflow** (`.github/workflows/ci.yml`) - Legacy validation for compose files in `compose/` directory
- **YAML Linting** - Ensures consistent YAML formatting
- **Shellcheck** - Lints shell scripts for common issues

## Local Validation Tools

Use these tools on your CoreSrv host before deploying changes.

### Preflight Check

Run before deploying to catch issues early:

```bash
./scripts/preflight.sh
```

**What it checks:**
1. ✅ Docker and Docker Compose are installed and running
2. ✅ All compose files are valid
3. ✅ Environment files exist and have required variables
4. ✅ External networks exist (or will be created)
5. ✅ Common ports are available (80, 443, etc.)
6. ✅ Storage paths exist or can be created

**Exit codes:**
- `0` - All checks passed
- `1` - Critical checks failed (must fix before deploying)

**Usage with verbose output:**

```bash
./scripts/preflight.sh --verbose
```

### Deploy Script

Automated deployment with health checking:

```bash
# Deploy a single stack
./scripts/deploy.sh ingress

# Deploy multiple stacks
./scripts/deploy.sh ingress observability

# Deploy everything
./scripts/deploy.sh all
```

**What it does:**
1. Pulls latest images
2. Starts services with `docker compose up -d`
3. Waits for containers to become healthy (up to 3 minutes)
4. Shows service URLs
5. On failure: displays logs from unhealthy containers

**Available stacks:**
- `ingress` - Traefik reverse proxy
- `observability` - Prometheus, Grafana, Loki, Uptime Kuma
- `apps` - Mealie, DSMR Reader
- `portal` - Homepage or Homearr
- `home` - Home Assistant, Zigbee2MQTT, Mosquitto
- `netdata` - Netdata monitoring (if configured)
- `all` - All stacks in dependency order

**Example deployment workflow:**

```bash
# 1. Run preflight check
./scripts/preflight.sh

# 2. Deploy ingress first (required by other services)
./scripts/deploy.sh ingress

# 3. Deploy observability stack
./scripts/deploy.sh observability

# 4. Deploy applications
./scripts/deploy.sh apps portal
```

## What CI Can and Cannot Guarantee

### ✅ CI Catches

- Invalid YAML syntax
- Docker Compose configuration errors
- Basic service startup issues (for CI-compatible services)
- Accidentally committed secrets
- Missing service dependencies in compose files

### ❌ CI Cannot Catch

These issues are specific to your hardware/network and must be validated locally:

1. **Host-specific issues:**
   - Incorrect volume mount paths
   - Permission issues on host directories
   - Insufficient disk space

2. **Network issues:**
   - LAN/WAN connectivity
   - DNS resolution
   - Pi-hole configuration
   - Port conflicts with other services

3. **Hardware dependencies:**
   - USB devices (Zigbee adapters, cameras)
   - GPU availability (for Frigate)
   - Network interfaces
   - Storage devices

4. **Runtime integration:**
   - Service-to-service communication in production
   - Traefik routing with real DNS
   - Authelia authentication flow
   - Actual media file processing

5. **Performance:**
   - Resource usage under load
   - Storage I/O performance
   - Network throughput

## Editing Compose Files

When documentation instructs you to edit a compose file, always use:

```bash
sudo nano /path/to/compose/file.yml
```

For example:
```bash
# Edit Traefik configuration
sudo nano /home/runner/work/Orion-Sentinel-CoreSrv/Orion-Sentinel-CoreSrv/stacks/ingress/traefik.yaml

# Edit observability stack
sudo nano /home/runner/work/Orion-Sentinel-CoreSrv/Orion-Sentinel-CoreSrv/stacks/observability/stack.yaml

# Edit Netdata configuration
sudo nano /home/runner/work/Orion-Sentinel-CoreSrv/Orion-Sentinel-CoreSrv/stacks/observability/netdata/compose.yml
```

Always validate after editing:
```bash
docker compose -f /path/to/compose/file.yml config
```

## Recommended GitHub Branch Protection

To maintain code quality and prevent breaking changes, configure these GitHub branch protection rules:

### Settings → Branches → Branch Protection Rules

**For `main` branch:**

1. **Require pull request reviews before merging**
   - Required approving reviews: 1
   - Dismiss stale pull request approvals when new commits are pushed

2. **Require status checks to pass before merging**
   - Require branches to be up to date before merging
   - Status checks that are required:
     - ✅ `Validate Docker Compose Files` (from compose-validate.yml)
     - ✅ `YAML Linting` (from compose-validate.yml)
     - ✅ `Validate Compose Profiles` (from compose-validate.yml)
     - ✅ `Secrets Hygiene Check` (from compose-validate.yml)
     - ✅ `Smoke Test - CI-Safe Services` (from smoke-test.yml)

3. **Require linear history**
   - Prevents merge commits, keeps history clean

4. **Do not allow bypassing the above settings**
   - Even administrators must follow the rules

5. **Restrict who can push to matching branches**
   - Only allow specific users/teams to push directly

6. **Require deployments to succeed before merging** (optional)
   - If you have a staging environment

### Settings → Code security and analysis

1. **Dependency graph** - Enable to track dependencies
2. **Dependabot alerts** - Enable to get security notifications
3. **Dependabot security updates** - Enable to auto-create PRs for vulnerabilities

**Note:** These settings cannot be configured automatically via Git. You must configure them manually in the GitHub web interface.

## Testing Workflow Example

Here's a complete workflow for testing changes:

### 1. Development (Local or PR)

```bash
# Pull latest changes
git pull origin main

# Create feature branch
git checkout -b feature/my-changes

# Make your changes
# ... edit files ...

# Validate locally (optional but recommended)
./scripts/preflight.sh

# Commit and push
git add .
git commit -m "Description of changes"
git push origin feature/my-changes
```

### 2. CI Validation (Automatic)

GitHub Actions will automatically:
- Validate all compose files
- Run YAML linting
- Check for secrets
- Run smoke tests (on PR)

Wait for green checkmarks before proceeding.

### 3. Merge to Main

Once CI passes and PR is approved:
- Merge the PR via GitHub interface
- GitHub will run CI again on `main` branch

### 4. Deploy to CoreSrv (Manual)

```bash
# SSH to your CoreSrv host
ssh user@coresrv

# Pull latest changes
cd /path/to/Orion-Sentinel-CoreSrv
git pull origin main

# Run preflight check
./scripts/preflight.sh

# Deploy updated stacks
./scripts/deploy.sh <stack-name>

# Verify services
docker compose ps
docker compose logs -f <service-name>
```

## Troubleshooting

### Preflight Check Fails

**Issue:** Compose file validation fails
```bash
# Check specific file
docker compose -f stacks/ingress/traefik.yaml config

# Check for syntax errors
yamllint stacks/ingress/traefik.yaml
```

**Issue:** Networks don't exist
```bash
# Networks are created on first deployment - this is normal
# Or create manually:
docker network create orion_proxy
```

**Issue:** Ports in use
```bash
# Check what's using the port
sudo ss -tulpn | grep :80

# Stop conflicting service or change port in .env
```

### Deploy Script Fails

**Issue:** Containers unhealthy
```bash
# Check logs
docker compose -f stacks/<stack>/stack.yaml logs

# Check specific container
docker logs <container-name>

# Restart unhealthy container
docker compose -f stacks/<stack>/stack.yaml restart <service-name>
```

**Issue:** Images can't be pulled
```bash
# Check Docker Hub connectivity
docker pull hello-world

# Try pulling manually
docker compose -f stacks/<stack>/stack.yaml pull
```

### CI Workflow Fails

**Issue:** Secrets found in code
- Review the flagged file
- Ensure secrets are only in `.env` (which is gitignored)
- Use `.env.example` for templates (with dummy values)

**Issue:** Smoke test fails
- Check GitHub Actions logs
- Test the compose file locally
- May be a temporary Docker Hub issue - retry

## Best Practices

1. **Always run preflight before deploying**
   ```bash
   ./scripts/preflight.sh && ./scripts/deploy.sh <stack>
   ```

2. **Test changes in a branch first**
   - Create a feature branch
   - Let CI validate
   - Merge only when green

3. **Keep .env.example up to date**
   - Add new variables to `.env.example`
   - Use dummy values, never real secrets

4. **Use deploy.sh for deployment**
   - Handles image pulling
   - Waits for health checks
   - Shows helpful logs on failure

5. **Monitor after deployment**
   ```bash
   # Check status
   docker compose ps
   
   # Watch logs
   docker compose logs -f
   
   # Check Grafana for metrics
   # Check Uptime Kuma for service status
   ```

## Additional Resources

- [Docker Compose Documentation](https://docs.docker.com/compose/)
- [GitHub Actions Documentation](https://docs.github.com/en/actions)
- [yamllint Documentation](https://yamllint.readthedocs.io/)
- [Main README](../README.md)
- [Deployment Guide](DEPLOYMENT-GUIDE.md)
- [Architecture Documentation](ARCHITECTURE.md)
