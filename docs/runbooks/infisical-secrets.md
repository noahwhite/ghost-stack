# Runbook: Infisical Secret Provisioning and Rotation

## Overview

This runbook documents how to provision and rotate application secrets stored in Infisical for the Ghost Stack. Secrets in Infisical are used by Ghost instances to fetch credentials at boot time.

**Storage location:** Infisical project `Ghost Stack` (slug: `ghost-stack`), environment `dev`.

**Related stories:**
- GHO-74: Infisical infrastructure provisioned by OpenTofu (prerequisite)
- GHO-75: Boot-time token generation (required before instance reads from Infisical)
- GHO-76: RAM-backed secrets delivery at boot (required before instance reads from Infisical)

> **Note:** Provisioning secrets in Infisical (this runbook) can be done before GHO-75/76 are deployed. The secrets will sit in Infisical ready to be consumed once boot-time delivery is in place.

---

## Prerequisites

| Prerequisite | Why Required |
|--------------|-------------|
| GHO-74 deployed (`tofu apply`) | Creates the Infisical project, environment, and machine identity |
| Infisical CLI installed | To set secrets from the command line |
| Infisical management credentials | Client ID and client secret for the management identity |
| Access to current `.env.secrets` on the instance | Source of truth for current secret values |

### Install Infisical CLI

```bash
# macOS
brew install infisical/get-cli/infisical

# Or download directly from https://infisical.com/docs/cli/overview
```

### Authenticate the CLI

Use the management identity credentials (stored in Bitwarden, retrieved via `infra-shell.sh`):

```bash
export INFISICAL_CLIENT_ID="<management identity client ID>"
export INFISICAL_CLIENT_SECRET="<management identity client secret>"

infisical login \
  --method=universal-auth \
  --client-id="$INFISICAL_CLIENT_ID" \
  --client-secret="$INFISICAL_CLIENT_SECRET"
```

> **Tip:** You can also log in with your personal Infisical account if you have access to the organization:
> ```bash
> infisical login
> ```

---

## Secrets Inventory

These are the application secrets that must exist in Infisical before boot-time delivery (GHO-76) can serve them to the instance:

| Secret Name | Description | Service Impact | Restart Required |
|-------------|-------------|----------------|-----------------|
| `DATABASE_PASSWORD` | MySQL ghost user password | Ghost, MySQL | Container restart + MySQL ALTER USER |
| `DATABASE_ROOT_PASSWORD` | MySQL root password | MySQL | Container restart + MySQL ALTER USER |
| `HEALTH_CHECK_TOKEN` | Token for Caddy health check authentication | Caddy | Container restart |
| `mail__options__auth__pass` | SMTP password for transactional email | Ghost | Container restart |
| `TINYBIRD_ADMIN_TOKEN` | TinyBird workspace admin token for analytics | Ghost, tinybird-provision.service | Container restart |

> **Note:** `DATABASE_PASSWORD` and `DATABASE_ROOT_PASSWORD` require a MySQL ALTER USER step in addition to a container restart, because MySQL stores the password hash in its data directory — updating the secret in Infisical alone does not change the MySQL user's password.

---

## Initial Provisioning

Run this procedure once after GHO-74 is deployed, to populate the Infisical `dev` environment with secret values from the existing instance.

### Step 1: Confirm Infisical Infrastructure Is Deployed

Verify the project and environment exist:

```bash
infisical projects list
# Should show: Ghost Stack (ghost-stack)
```

### Step 2: Retrieve Current Secret Values from the Instance

SSH to the Ghost instance and read the current `.env.secrets`:

```bash
tailscale ssh core@ghost-dev-01

sudo cat /var/mnt/storage/ghost-compose/.env.secrets
```

The file contains values in `KEY=value` format. Copy each value — you will use them in the next step.

Also retrieve the TinyBird admin token if it is stored in `.env.secrets`:

```bash
sudo grep TINYBIRD_ADMIN_TOKEN /var/mnt/storage/ghost-compose/.env.secrets
```

Exit the SSH session when done:

```bash
exit
```

### Step 3: Set Secrets in Infisical

Set each secret using the Infisical CLI. Replace `<value>` with the actual secret values retrieved in Step 2:

```bash
# Set secrets one at a time to avoid shell history issues with sensitive values
infisical secrets set DATABASE_PASSWORD="<value>" \
  --projectId ghost-stack \
  --env dev

infisical secrets set DATABASE_ROOT_PASSWORD="<value>" \
  --projectId ghost-stack \
  --env dev

infisical secrets set HEALTH_CHECK_TOKEN="<value>" \
  --projectId ghost-stack \
  --env dev

infisical secrets set "mail__options__auth__pass"="<value>" \
  --projectId ghost-stack \
  --env dev

infisical secrets set TINYBIRD_ADMIN_TOKEN="<value>" \
  --projectId ghost-stack \
  --env dev
```

> **Alternative — Infisical UI:** Log into https://app.infisical.com, navigate to the **Ghost Stack** project → **dev** environment → **Secrets**, and add each secret manually. This avoids any risk of secrets appearing in terminal history.

> **Shell history note:** The commands above will store secret values in your shell history. After setting secrets, clear history with `history -c` or set `HISTIGNORE="infisical*"` before running these commands.

### Step 4: Verify Secrets Are Stored

Confirm all five secrets exist in the `dev` environment:

```bash
infisical secrets list --projectId ghost-stack --env dev
```

Expected output should show all five secret names. Do not verify values here — validate them from the UI if needed.

### Step 5: Verify Secret Access via Machine Identity

This step confirms the `ghost-dev` machine identity (used by instances at boot) can read secrets:

```bash
# Get the ghost-dev identity credentials from OpenTofu output
# The client ID is the machine identity ID — retrieve from tofu output or Infisical UI

# Test that the identity can fetch secrets (uses single-use token — don't run repeatedly)
infisical secrets list \
  --method=universal-auth \
  --clientId="<ghost-dev identity client ID>" \
  --clientSecret="<ghost-dev client secret>" \
  --projectId ghost-stack \
  --env dev
```

> **Important:** The `ghost-dev` identity uses single-use tokens (`access_token_num_uses_limit = 1`). Running the CLI command above consumes one token. Only use this for initial verification — routine checks should use the management identity.

---

## Rotating a Secret

When rotating a secret, update it in Infisical first, then restart affected services. The instance will pick up the new value on the next boot (or after a service restart if GHO-76 supports live reload).

### Which Restart Is Required?

| Scenario | Action |
|----------|--------|
| `HEALTH_CHECK_TOKEN`, `mail__options__auth__pass`, `TINYBIRD_ADMIN_TOKEN` | Container restart only |
| `DATABASE_PASSWORD`, `DATABASE_ROOT_PASSWORD` | MySQL ALTER USER + container restart |

### Container Restart Procedure

After updating a secret in Infisical:

```bash
tailscale ssh core@ghost-dev-01

# Restart the entire Ghost Compose stack
sudo systemctl restart ghost-compose

# Or restart individual containers if only one service is affected
# sudo docker restart ghost-compose-ghost-1   # Ghost only
# sudo docker restart ghost-compose-caddy-1   # Caddy only
```

---

## Per-Secret Rotation Procedures

### `HEALTH_CHECK_TOKEN`

**Purpose:** Caddy uses this token to authenticate health check requests from GitHub Actions and manual `curl` checks.

**Impact:** Rotating this token invalidates all existing health check calls. Update the GitHub Secret `HEALTH_CHECK_TOKEN` (in both `dev` and `dev-ci` environments) at the same time.

**Rotation steps:**

1. Generate a new token (random, URL-safe):
   ```bash
   openssl rand -base64 32 | tr '+/' '-_' | tr -d '='
   ```

2. Update Infisical:
   ```bash
   infisical secrets set HEALTH_CHECK_TOKEN="<new-token>" \
     --projectId ghost-stack \
     --env dev
   ```

3. Update GitHub Secrets (both environments):
   - Go to `github.com/noahwhite/ghost-stack` → Settings → Environments → `dev`
   - Update `HEALTH_CHECK_TOKEN`
   - Repeat for Environments → `dev-ci`

4. Restart Caddy:
   ```bash
   tailscale ssh core@ghost-dev-01
   sudo docker restart ghost-compose-caddy-1
   ```

5. Verify health check works with the new token:
   ```bash
   curl -sI -H "X-Health-Check-Token: <new-token>" https://separationofconcerns.dev
   # Should return HTTP 200
   ```

---

### `mail__options__auth__pass`

**Purpose:** SMTP password for transactional email (password resets, staff invites).

**Impact:** Rotating this breaks outbound email until the container is restarted with the new value.

**Rotation steps:**

1. Generate or retrieve the new SMTP password from your mail provider (Mailgun or similar).

2. Update Infisical:
   ```bash
   infisical secrets set "mail__options__auth__pass"="<new-password>" \
     --projectId ghost-stack \
     --env dev
   ```

3. Restart Ghost:
   ```bash
   tailscale ssh core@ghost-dev-01
   sudo docker restart ghost-compose-ghost-1
   ```

4. Verify email delivery:
   - Go to Ghost Admin → Settings → Email → Send test email
   - Confirm it is delivered

---

### `TINYBIRD_ADMIN_TOKEN`

**Purpose:** JWT signing for Ghost Stats dashboard queries. Ghost uses this token to sign JWTs that TinyBird validates for browser-side analytics API calls.

**Critical:** Use the **Workspace admin token**, NOT the personal admin token. See [Token Rotation Runbook — TinyBird](../token-rotation-runbook.md#tinybird-credentials) for how to identify the correct token.

**Impact:** Rotating this token invalidates Ghost Stats until the container is restarted. The TinyBird tracker token (auto-generated by `tinybird-provision.service`) is separate and does not need to be rotated here.

**Rotation steps:**

1. Get the new Workspace admin token from TinyBird:
   - Log into TinyBird dashboard → Tokens
   - Copy the token named exactly **"Workspace admin token"**

2. Update Infisical:
   ```bash
   infisical secrets set TINYBIRD_ADMIN_TOKEN="<new-token>" \
     --projectId ghost-stack \
     --env dev
   ```

3. Restart Ghost:
   ```bash
   tailscale ssh core@ghost-dev-01
   sudo docker restart ghost-compose-ghost-1
   ```

4. Verify Ghost Stats is functional:
   - Go to Ghost Admin → Stats
   - Confirm analytics data loads without 403 errors

---

### `DATABASE_PASSWORD`

**Purpose:** Password for the `ghost` MySQL user. Used by Ghost to connect to its database.

**Impact:** This rotation requires coordinating a MySQL password change with an Infisical update. If they get out of sync, Ghost will fail to connect to the database.

**Rotation steps:**

1. Generate a new password:
   ```bash
   openssl rand -base64 24
   ```

2. Update the MySQL user password on the instance:
   ```bash
   tailscale ssh core@ghost-dev-01

   # Connect to MySQL as root
   sudo docker exec -it ghost-compose-db-1 mysql -u root -p
   # Enter DATABASE_ROOT_PASSWORD when prompted

   # Change the ghost user password
   ALTER USER 'ghost'@'%' IDENTIFIED BY '<new-password>';
   FLUSH PRIVILEGES;
   EXIT;
   ```

3. Update Infisical with the new password:
   ```bash
   infisical secrets set DATABASE_PASSWORD="<new-password>" \
     --projectId ghost-stack \
     --env dev
   ```

4. Restart Ghost containers:
   ```bash
   sudo systemctl restart ghost-compose
   ```

5. Verify Ghost is running and can connect to the database:
   ```bash
   docker logs ghost-compose-ghost-1 2>&1 | tail -20
   # Should show no database connection errors
   ```

---

### `DATABASE_ROOT_PASSWORD`

**Purpose:** MySQL root password. Used for administrative database operations.

**Impact:** This only affects administrative access to MySQL, not Ghost's normal operation. Ghost uses `DATABASE_PASSWORD` (ghost user), not the root password.

**Rotation steps:**

1. Generate a new root password:
   ```bash
   openssl rand -base64 24
   ```

2. Update the MySQL root password on the instance:
   ```bash
   tailscale ssh core@ghost-dev-01

   # Connect to MySQL as root (with current password)
   sudo docker exec -it ghost-compose-db-1 mysql -u root -p
   # Enter current DATABASE_ROOT_PASSWORD when prompted

   # Change root password
   ALTER USER 'root'@'%' IDENTIFIED BY '<new-password>';
   ALTER USER 'root'@'localhost' IDENTIFIED BY '<new-password>';
   FLUSH PRIVILEGES;
   EXIT;
   ```

3. Update Infisical with the new password:
   ```bash
   infisical secrets set DATABASE_ROOT_PASSWORD="<new-password>" \
     --projectId ghost-stack \
     --env dev
   ```

4. Restart MySQL to pick up the new root password:
   ```bash
   sudo docker restart ghost-compose-db-1
   # Wait for MySQL to be ready, then restart Ghost
   sleep 15
   sudo docker restart ghost-compose-ghost-1
   ```

5. Verify MySQL is healthy:
   ```bash
   docker logs ghost-compose-db-1 2>&1 | tail -10
   docker logs ghost-compose-ghost-1 2>&1 | tail -10
   ```

---

## Verification After Provisioning or Rotation

After provisioning or rotating any secret, verify the Ghost stack is healthy:

```bash
# 1. Check all containers are running
tailscale ssh core@ghost-dev-01 'docker ps --format "table {{.Names}}\t{{.Status}}"'

# 2. Health check — should return HTTP 200
curl -sI -H "X-Health-Check-Token: <token>" https://separationofconcerns.dev

# 3. Ghost admin is accessible
curl -sI https://admin.separationofconcerns.dev/ghost
# Should redirect to /ghost/#/signin (302 or 200)

# 4. Check for container errors
tailscale ssh core@ghost-dev-01 '
  docker logs ghost-compose-ghost-1 2>&1 | tail -20
  docker logs ghost-compose-caddy-1 2>&1 | tail -10
  docker logs ghost-compose-db-1 2>&1 | tail -10
'
```

---

## Troubleshooting

### Secret Not Found in Infisical

**Symptom:** `infisical secrets list` does not show the expected secret.

**Check:** Confirm you are targeting the correct project and environment:
```bash
infisical secrets list --projectId ghost-stack --env dev
```

If the project does not exist, the Infisical infrastructure (GHO-74) has not been deployed. Run:
```bash
./opentofu/scripts/tofu.sh dev apply
```

### Ghost Fails to Start After Database Password Rotation

**Symptom:** `ghost-compose-ghost-1` exits with "Error establishing database connection"

**Cause:** MySQL password was not updated before restarting, or the MySQL ALTER USER was not applied.

**Fix:**
```bash
# Check what password Ghost is using
docker exec ghost-compose-ghost-1 env | grep DATABASE_PASSWORD

# Check what password MySQL expects
docker exec -it ghost-compose-db-1 mysql -u ghost -p
# Try both old and new password to identify which MySQL has stored
```

Ensure the ALTER USER step in the rotation procedure completed successfully before restarting containers.

### Caddy Returns 403 After Health Check Token Rotation

**Symptom:** Health check requests fail with 403 after rotating `HEALTH_CHECK_TOKEN`.

**Common causes:**
1. GitHub Secret was not updated — check `HEALTH_CHECK_TOKEN` in both `dev` and `dev-ci` environments
2. Caddy container was not restarted after the secret changed
3. New token has trailing whitespace or newline characters

**Check:**
```bash
# Verify the token Caddy is using
tailscale ssh core@ghost-dev-01 \
  'docker exec ghost-compose-caddy-1 env | grep HEALTH_CHECK_TOKEN'
```

---

## Related Documentation

- [Token Rotation Runbook](../token-rotation-runbook.md) — Infrastructure token rotation (Cloudflare, Vultr, Tailscale, etc.)
- [Secrets Management](../secrets-management.md) — Overview of the secrets management strategy
- [CLAUDE.md — Ghost Compose Secrets Management](../../CLAUDE.md#ghost-compose-secrets-management) — File split strategy and security model
- [env-secrets-migration.md](./env-secrets-migration.md) — Historical migration from `.env` to `.env.secrets`

---

_This document lives at `docs/runbooks/infisical-secrets.md` in the repository._
