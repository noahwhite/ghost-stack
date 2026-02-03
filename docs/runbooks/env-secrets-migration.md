# Runbook: Migrate to Ephemeral Ghost Compose Configuration

## Overview

This runbook documents the one-time migration process to transition from a fully manual Ghost Docker Compose deployment to the hybrid ephemeral/persistent model. After migration, configuration files will be deployed via Ignition at boot time, while secrets remain on block storage.

## Background

### Current State (Before Migration)

All Ghost Compose files are manually managed on block storage:

| File | Location | Contains |
|------|----------|----------|
| `compose.yml` | `/var/mnt/storage/ghost-compose/` | Service definitions |
| `.env` | `/var/mnt/storage/ghost-compose/` | All config + secrets |
| `caddy/Caddyfile` | `/var/mnt/storage/ghost-compose/caddy/` | Hardcoded tokens |
| `caddy/snippets/*` | `/var/mnt/storage/ghost-compose/caddy/snippets/` | Static config |
| `mysql-init/*` | `/var/mnt/storage/ghost-compose/mysql-init/` | Init scripts |

### Target State (After Migration)

| Component | Location | Source | Contains |
|-----------|----------|--------|----------|
| `compose.yml` | `/etc/ghost-compose/` | Ignition | Service definitions |
| `.env.config` | `/etc/ghost-compose/` | Ignition | Non-secret config |
| `.env.secrets` | `/var/mnt/storage/ghost-compose/` | Block storage | **Secrets only** |
| `caddy/Caddyfile` | `/etc/ghost-compose/caddy/` | Ignition | Uses `{$VAR}` placeholders |
| `caddy/snippets/*` | `/etc/ghost-compose/caddy/snippets/` | Ignition | Static config |
| `mysql-init/*` | `/etc/ghost-compose/mysql-init/` | Ignition | Init scripts |

## Prerequisites

- SSH access to the Ghost instance via Tailscale
- Admin access to Tailscale admin console (for device cleanup)
- The OpenTofu changes for ephemeral compose are ready in a feature branch (PR will be created in Step 8)

## Procedure

### Step 1: Backup Current Configuration

SSH to the instance and create a backup:

```bash
# SSH to instance
tailscale ssh core@ghost-dev-01

# Create backup directory with timestamp
BACKUP_DIR="/var/mnt/storage/backups/ghost-compose-$(date +%Y%m%d-%H%M%S)"
sudo mkdir -p "$BACKUP_DIR"

# Backup all current config (including hidden files like .env)
sudo cp -a /var/mnt/storage/ghost-compose/. "$BACKUP_DIR/"

# Verify backup
ls -la "$BACKUP_DIR/"
cat "$BACKUP_DIR/.env"  # Verify .env was captured
```

### Step 2: Identify Secrets in Current .env

Review the current `.env` file to identify which values are secrets:

```bash
# View current .env
sudo cat /var/mnt/storage/ghost-compose/.env
```

**Secrets to extract** (these go in `.env.secrets`):
- `DATABASE_PASSWORD` - MySQL ghost user password
- `DATABASE_ROOT_PASSWORD` - MySQL root password
- `HEALTH_CHECK_TOKEN` - Token for health check authentication (may be in Caddyfile)
- `mail__options__auth__pass` - SMTP password for transactional email

**Non-secrets** (will be managed by Ignition in `.env.config`):
- `DOMAIN` / domain names
- `ADMIN_DOMAIN` / admin domain
- `ADMIN_IP` / workstation IP for ACL
- `UPLOAD_LOCATION` / data paths
- `MYSQL_DATA_LOCATION` / data paths
- `mail__transport` / mail config
- `mail__options__host` / mail host
- `mail__options__port` / mail port
- `mail__options__secure` / mail TLS setting
- `mail__options__auth__user` / mail username (not password)

### Step 3: Extract Health Check Token from Caddyfile

The health check token may be hardcoded in the Caddyfile:

```bash
# Check Caddyfile for hardcoded token
sudo grep -A1 "X-Health-Check-Token" /var/mnt/storage/ghost-compose/caddy/Caddyfile
```

Expected output format:
```
header X-Health-Check-Token "your-token-value-here"
```

Copy this token value - it will go in `.env.secrets`.

### Step 4: Create .env.secrets File

Create the secrets-only file on block storage:

```bash
# Create the secrets file
sudo tee /var/mnt/storage/ghost-compose/.env.secrets << 'EOF'
# Ghost Compose Secrets
# This file contains sensitive credentials only.
# Non-secret configuration is deployed via Ignition to /etc/ghost-compose/.env.config

# MySQL Credentials
DATABASE_PASSWORD=REPLACE_WITH_ACTUAL_PASSWORD
DATABASE_ROOT_PASSWORD=REPLACE_WITH_ACTUAL_ROOT_PASSWORD

# Health Check Token (used by Caddy to authenticate health check requests)
HEALTH_CHECK_TOKEN=REPLACE_WITH_ACTUAL_TOKEN

# Mail Credentials (SMTP password for transactional email)
mail__options__auth__pass=REPLACE_WITH_ACTUAL_SMTP_PASSWORD
EOF
```

**Important:** Now edit the file to replace placeholders with actual values:

```bash
sudo vim /var/mnt/storage/ghost-compose/.env.secrets
```

Replace each `REPLACE_WITH_...` placeholder with the corresponding value from:
- The backup `.env` file (for database passwords and mail password)
- The Caddyfile (for health check token)

### Step 5: Set Correct File Permissions

Secure the secrets file:

```bash
# Set restrictive permissions (owner read/write only)
sudo chmod 0600 /var/mnt/storage/ghost-compose/.env.secrets

# Verify permissions
ls -la /var/mnt/storage/ghost-compose/.env.secrets
# Expected: -rw------- 1 root root ... .env.secrets
```

### Step 6: Verify Secrets File Contents

Confirm the file has the correct format and values:

```bash
# Check file contents (be careful in shared terminals)
sudo cat /var/mnt/storage/ghost-compose/.env.secrets

# Check line endings are Unix-style (LF, not CRLF)
sudo cat -A /var/mnt/storage/ghost-compose/.env.secrets | head -5
# Lines should end with $ not ^M$
```

### Step 6a: Secure Original .env File

After verifying `.env.secrets` contains the correct values, you should remove the secrets from the original `.env` file to avoid having secrets in two locations:

**Option 1: Remove original .env (recommended after successful deployment)**

Wait until after Step 9 verification completes successfully, then:
```bash
sudo rm /var/mnt/storage/ghost-compose/.env
```

**Option 2: Keep .env but redact secrets (safer during migration)**

If you want to keep the file structure for reference but remove secrets:
```bash
# Create a redacted version
sudo sed -i \
  -e 's/^DATABASE_ROOT_PASSWORD=.*/DATABASE_ROOT_PASSWORD=REDACTED/' \
  -e 's/^DATABASE_PASSWORD=.*/DATABASE_PASSWORD=REDACTED/' \
  -e 's/^mail__options__auth__pass=.*/mail__options__auth__pass=REDACTED/' \
  /var/mnt/storage/ghost-compose/.env
```

**Note:** The backup directory still contains the original `.env` with secrets. Keep this backup secure or delete it after confirming the migration is successful.

**About the Caddyfile token:** The original Caddyfile at `/var/mnt/storage/ghost-compose/caddy/Caddyfile` contains the hardcoded health check token. After migration, this file is no longer used - the new Caddyfile at `/etc/ghost-compose/caddy/Caddyfile` reads the token from the `HEALTH_CHECK_TOKEN` environment variable. The old Caddyfile (and entire `/var/mnt/storage/ghost-compose/` directory except `.env.secrets`) can be deleted during post-migration cleanup.

### Step 7: Clean Up Tailscale Device

Before applying infrastructure changes, remove the old device from Tailscale:

1. Navigate to https://login.tailscale.com/admin/machines
2. Find `ghost-dev-01`
3. Click "..." menu > "Remove device"
4. Confirm removal

See [Tailscale Device Cleanup Runbook](./tailscale-device-cleanup.md) for details.

### Step 8: Deploy via CI

Infrastructure changes are applied through the CI/CD pipeline, not manually.

1. **Create a PR** with the ephemeral compose changes targeting `develop` branch
   ```bash
   git checkout -b feature/GHO-XX-ephemeral-ghost-compose
   git add -A
   git commit -m "feat: make Ghost Docker Compose stack ephemeral"
   git push -u origin feature/GHO-XX-ephemeral-ghost-compose
   gh pr create --base develop --title "Make Ghost Docker Compose stack ephemeral"
   ```

2. **Review the PR plan** - The `pr-tofu-plan-develop.yml` workflow runs automatically
   - Check the workflow output for the plan
   - Verify it shows `vultr_instance.ghost will be replaced`
   - All other resources should be unchanged or updated in-place

3. **Merge the PR** - After approval, merge to `develop`

4. **Monitor deployment** - The `deploy-dev.yml` workflow triggers automatically
   - Requires manual approval via GitHub environment protection
   - Compares fresh plan with PR plan (drift detection)
   - Applies changes and runs health checks

5. **Watch for completion** - The workflow will:
   - Recreate the instance with new Ignition config
   - Run health checks against `https://separationofconcerns.dev`
   - Report success or failure in the workflow summary

### Step 9: Post-Migration Verification

After the new instance is running:

```bash
# SSH to new instance
tailscale ssh core@ghost-dev-01

# 1. Verify ephemeral config files exist
ls -la /etc/ghost-compose/
ls -la /etc/ghost-compose/caddy/snippets/

# 2. Verify .env.config has no secrets
cat /etc/ghost-compose/.env.config
# Should contain: DOMAIN, ADMIN_DOMAIN, ADMIN_IP, paths, mail config (except password)

# 3. Verify .env.secrets exists on block storage
ls -la /var/mnt/storage/ghost-compose/.env.secrets
# Should show -rw------- permissions

# 4. Check Docker Compose is running
docker compose -f /etc/ghost-compose/compose.yml ps
# All services should be "running"

# 5. Check container logs for errors
docker logs ghost-compose-caddy-1 2>&1 | tail -20
docker logs ghost-compose-ghost-1 2>&1 | tail -20
docker logs ghost-compose-db-1 2>&1 | tail -20

# 6. Verify Ghost responds (using health check token since direct access is restricted)
curl -sI -H "X-Health-Check-Token: YOUR_TOKEN_VALUE" https://separationofconcerns.dev
# Should return HTTP 200
```

### Step 10: Verify Health Check Works

Test that the health check token is correctly passed from `.env.secrets`:

```bash
# From your workstation - with token (should succeed)
curl -sI -H "X-Health-Check-Token: YOUR_TOKEN_VALUE" https://separationofconcerns.dev
# Should return HTTP 200

# From your workstation - without token (should be blocked)
curl -sI https://separationofconcerns.dev
# Should return HTTP 403 (unless your IP is the allowed admin IP going through Cloudflare)

# Verify token in Caddy config uses environment variable
tailscale ssh core@ghost-dev-01 \
  "grep -A1 'X-Health-Check-Token' /etc/ghost-compose/caddy/Caddyfile"
# Should show: header X-Health-Check-Token "{$HEALTH_CHECK_TOKEN}"
# NOT a hardcoded value
```

**Note:** The site is restricted to requests that either have the health check token OR come from the admin IP via Cloudflare (`Cf-Connecting-IP` header). Direct requests without the token will receive `403 Access Denied`.

### Step 11: Enable Alloy Service (If Needed)

Due to a known timing issue, Alloy may not auto-start after instance recreation:

```bash
# Check if Alloy is running
systemctl status alloy.service

# If not running, enable it manually
sudo systemctl enable --now alloy.service

# Verify it started
systemctl status alloy.service
journalctl -u alloy.service -n 20
```

## Rollback Procedure

If migration fails and you need to revert:

### Option 1: Quick Rollback (Restore Manual Config)

```bash
# SSH to instance
tailscale ssh core@ghost-dev-01

# Stop current services
sudo docker compose -f /etc/ghost-compose/compose.yml down

# Restore backup to original location
BACKUP_DIR="/var/mnt/storage/backups/ghost-compose-YYYYMMDD-HHMMSS"  # Use actual timestamp
sudo cp -r "$BACKUP_DIR"/* /var/mnt/storage/ghost-compose/

# Override systemd service to use old location temporarily
sudo mkdir -p /etc/systemd/system/ghost-compose.service.d/
sudo tee /etc/systemd/system/ghost-compose.service.d/override.conf << 'EOF'
[Service]
WorkingDirectory=/var/mnt/storage/ghost-compose
EOF

sudo systemctl daemon-reload
sudo systemctl restart ghost-compose.service

# Verify
docker compose -f /var/mnt/storage/ghost-compose/compose.yml ps
```

### Option 2: Full Rollback (Revert OpenTofu Changes)

1. Revert the OpenTofu changes in git:
   ```bash
   git checkout develop
   git pull
   git revert <commit-hash>
   ```

2. Create a PR for the revert and merge to `develop`:
   ```bash
   git push -u origin revert-ephemeral-compose
   gh pr create --base develop --title "Revert: Make Ghost Docker Compose stack ephemeral"
   # Get PR reviewed, approved, and merged
   ```

3. Clean up Tailscale device (see Step 7) before the deployment workflow runs

4. Approve the deployment in GitHub Actions when prompted

5. Manually restore `.env` from backup after instance recreation:
   ```bash
   tailscale ssh core@ghost-dev-01
   sudo cp /var/mnt/storage/backups/ghost-compose-*/. /var/mnt/storage/ghost-compose/ -a
   ```

## Troubleshooting

### Ghost Container Fails to Start

**Symptom:** `ghost-compose-ghost-1` container exits or restarts repeatedly

**Check:**
```bash
docker logs ghost-compose-ghost-1 2>&1 | tail -50
```

**Common Causes:**
- Database password mismatch - verify `DATABASE_PASSWORD` in `.env.secrets` matches existing MySQL
- Missing environment variables - check both `.env.config` and `.env.secrets` are sourced

### Caddy Returns 403 for Health Checks

**Symptom:** Health check requests fail with 403

**Check:**
```bash
docker logs ghost-compose-caddy-1 2>&1 | grep -i "health"
```

**Common Causes:**
- `HEALTH_CHECK_TOKEN` not set or incorrect in `.env.secrets`
- Environment variable not expanded - Caddy needs `{$VAR}` syntax (not `${VAR}`)

### Database Connection Errors

**Symptom:** Ghost shows "Error establishing database connection"

**Check:**
```bash
docker logs ghost-compose-db-1 2>&1 | tail -20
docker exec ghost-compose-ghost-1 env | grep DATABASE
```

**Common Causes:**
- `DATABASE_PASSWORD` doesn't match what MySQL has stored
- MySQL data directory permissions changed

### Mail Sending Fails

**Symptom:** Ghost admin shows mail errors, password reset emails not sent

**Check:**
```bash
docker exec ghost-compose-ghost-1 env | grep mail
```

**Common Causes:**
- `mail__options__auth__pass` missing or incorrect in `.env.secrets`
- Special characters in password not properly escaped

## Post-Migration Cleanup

After confirming the migration is successful (wait at least 24-48 hours):

```bash
# 1. Remove orphaned config files (now deployed via Ignition to /etc/ghost-compose/)
#    Keep only .env.secrets which is still used
sudo rm /var/mnt/storage/ghost-compose/.env
sudo rm /var/mnt/storage/ghost-compose/compose.yml
sudo rm -rf /var/mnt/storage/ghost-compose/caddy/      # Contains hardcoded token
sudo rm -rf /var/mnt/storage/ghost-compose/mysql-init/

# 2. Verify only .env.secrets remains
ls -la /var/mnt/storage/ghost-compose/
# Should show only: .env.secrets

# 3. Remove old backup directory (contains secrets!)
#    Only do this after you're confident the migration is stable
sudo rm -rf /var/mnt/storage/backups/ghost-compose-*
```

**Security note:** The backup directory and old Caddyfile contain plaintext secrets (`.env` passwords and health check token). Delete them after confirming the migration is stable, or ensure restrictive permissions (`chmod 0700`).

## Related Documentation

- [CLAUDE.md - Ghost Compose Architecture](../../CLAUDE.md#ghost-compose-architecture)
- [CLAUDE.md - Ghost Compose Secrets Management](../../CLAUDE.md#ghost-compose-secrets-management)
- [Tailscale Device Cleanup Runbook](./tailscale-device-cleanup.md)
- [Token Rotation Runbook](../token-rotation-runbook.md)
