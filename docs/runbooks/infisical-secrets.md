# Runbook: Infisical Secret Provisioning and Rotation

## Overview

This runbook documents how to provision and rotate application secrets stored in Infisical for the Ghost Stack. Secrets in Infisical are used by Ghost instances to fetch credentials at boot time.

**Storage location:** Infisical project `Ghost Stack` (slug: `ghost-stack`), environment `dev`.

**Related stories:**
- [GHO-74](https://linear.app/noahwhite/issue/GHO-74): Infisical infrastructure provisioned by OpenTofu (prerequisite)
- [GHO-75](https://linear.app/noahwhite/issue/GHO-75): Boot-time token generation (required before instance reads from Infisical)
- [GHO-76](https://linear.app/noahwhite/issue/GHO-76): RAM-backed secrets delivery at boot (required before instance reads from Infisical)

> **Note:** Provisioning secrets in Infisical (this runbook) can be done before [GHO-75](https://linear.app/noahwhite/issue/GHO-75)/[GHO-76](https://linear.app/noahwhite/issue/GHO-76) are deployed. The secrets will sit in Infisical ready to be consumed once boot-time delivery is in place.

---

## Prerequisites

| Prerequisite | Why Required |
|--------------|-------------|
| [GHO-74](https://linear.app/noahwhite/issue/GHO-74) deployed (`tofu apply`) | Creates the Infisical project, environment, and machine identity |
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
read -s INFISICAL_CLIENT_ID; export INFISICAL_CLIENT_ID
read -s INFISICAL_CLIENT_SECRET; export INFISICAL_CLIENT_SECRET

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

These are the application secrets that must exist in Infisical before boot-time delivery ([GHO-76](https://linear.app/noahwhite/issue/GHO-76)) can serve them to the instance:

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

Run this procedure once after [GHO-74](https://linear.app/noahwhite/issue/GHO-74) is deployed, to populate the Infisical `dev` environment with secret values from the existing instance.

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

Set each secret using the Infisical CLI. Use `read -s` to enter each value interactively — the value is stored in a shell variable and never appears in the command text, so it cannot leak into shell history.

```bash
read -s SECRET_VALUE; export SECRET_VALUE
infisical secrets set DATABASE_PASSWORD="$SECRET_VALUE" \
  --projectId ghost-stack \
  --env dev

read -s SECRET_VALUE; export SECRET_VALUE
infisical secrets set DATABASE_ROOT_PASSWORD="$SECRET_VALUE" \
  --projectId ghost-stack \
  --env dev

read -s SECRET_VALUE; export SECRET_VALUE
infisical secrets set HEALTH_CHECK_TOKEN="$SECRET_VALUE" \
  --projectId ghost-stack \
  --env dev

read -s SECRET_VALUE; export SECRET_VALUE
infisical secrets set "mail__options__auth__pass"="$SECRET_VALUE" \
  --projectId ghost-stack \
  --env dev

read -s SECRET_VALUE; export SECRET_VALUE
infisical secrets set TINYBIRD_ADMIN_TOKEN="$SECRET_VALUE" \
  --projectId ghost-stack \
  --env dev

unset SECRET_VALUE
```

After the last secret is set, `unset SECRET_VALUE` clears the variable from the shell environment.

> **Alternative — Infisical UI:** Log into https://app.infisical.com, navigate to the **Ghost Stack** project → **dev** environment → **Secrets**, and add each secret manually.

### Step 4: Verify Secrets Are Stored

Confirm all five secrets exist in the `dev` environment:

```bash
infisical secrets list --projectId ghost-stack --env dev
```

Expected output should show all five secret names. Do not verify values here — validate them from the UI if needed.

### Step 5: Verify Secret Access via Machine Identity

This step confirms the `ghost-dev` machine identity's Token Auth method and privilege scoping are configured correctly.

> **Important:** The `ghost-dev` identity uses Token Auth with single-use tokens (`number_of_uses_limit = 1`). Each token is generated per-provisioning-run by OpenTofu ([GHO-75](https://linear.app/noahwhite/issue/GHO-75)) and injected directly into the instance's Ignition config. Unlike Universal Auth, there are no client credentials to authenticate with manually — the token itself is the credential, and consuming it during verification wastes the boot token.

Verify the configuration in the Infisical UI instead:

1. Log into [app.infisical.com](https://app.infisical.com)
2. Navigate to **Organization Settings → Machine Identities → ghost-dev**
3. Confirm **Token Auth** is configured as the authentication method
4. Navigate to the **Ghost Stack** project → **Access Control → Machine Identities**
5. Confirm `ghost-dev` appears with the `no-access` base role
6. Confirm a **Specific Privilege** exists granting `read` on `secrets` scoped to the `dev` environment only

The full integration test occurs on first boot after [GHO-76](https://linear.app/noahwhite/issue/GHO-76) is deployed — the instance will use the injected token to fetch secrets and populate `.env.secrets`.

---

## Rotating a Secret

> **Important:** Updating a secret in Infisical does **not** automatically update the running instance. `infisical-secrets-fetch.service` only runs once at first boot — after that, the file at `/var/mnt/storage/ghost-compose/.env.secrets` is the live source of truth for containers. You must update that file on the instance before restarting containers, or the old value will continue to be used.

### Rotation Approaches

**Option A — Manual update (recommended for routine rotation):**
1. Update the secret in Infisical
2. Update `/var/mnt/storage/ghost-compose/.env.secrets` on the running instance directly
3. Restart affected containers

**Option B — Instance recreation (for multiple secrets or a clean slate):**
1. Update all secrets in Infisical
2. Trigger instance recreation via `tofu apply` (e.g., bump a config value to change `instance_replacement_hash`)
3. The new instance runs Ignition on first boot, `infisical-secrets-fetch.service` fetches all current Infisical values, and containers start with fresh secrets

### Which Restart Is Required?

| Scenario | Action |
|----------|--------|
| `HEALTH_CHECK_TOKEN`, `mail__options__auth__pass`, `TINYBIRD_ADMIN_TOKEN` | Container restart only |
| `DATABASE_PASSWORD`, `DATABASE_ROOT_PASSWORD` | MySQL ALTER USER + `.env.secrets` update + container restart |

### Updating `.env.secrets` on the Running Instance

Use `read -s` + `sed -i` to replace the value in-place without leaking it into shell history. Replace `KEY_NAME` and the file path as appropriate:

```bash
tailscale ssh core@ghost-dev-01

read -s NEW_VALUE
sudo sed -i "s|^KEY_NAME=.*|KEY_NAME=${NEW_VALUE}|" \
  /var/mnt/storage/ghost-compose/.env.secrets
unset NEW_VALUE
```

Then restart the affected container(s):

```bash
# Restart individual container
sudo docker restart ghost-compose-caddy-1   # Caddy
sudo docker restart ghost-compose-ghost-1   # Ghost

# Or restart the entire stack
sudo systemctl restart ghost-compose
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
   read -s SECRET_VALUE; export SECRET_VALUE
   infisical secrets set HEALTH_CHECK_TOKEN="$SECRET_VALUE" \
     --projectId ghost-stack \
     --env dev
   unset SECRET_VALUE
   ```

3. Update GitHub Secrets (both environments):
   - Go to `github.com/noahwhite/ghost-stack` → Settings → Environments → `dev`
   - Update `HEALTH_CHECK_TOKEN`
   - Repeat for Environments → `dev-ci`

4. Update `.env.secrets` on the instance and restart Caddy:
   ```bash
   tailscale ssh core@ghost-dev-01

   read -s NEW_VALUE
   sudo sed -i "s|^HEALTH_CHECK_TOKEN=.*|HEALTH_CHECK_TOKEN=${NEW_VALUE}|" \
     /var/mnt/storage/ghost-compose/.env.secrets
   unset NEW_VALUE

   sudo docker restart ghost-compose-caddy-1
   ```

5. Verify health check works with the new token:
   ```bash
   read -s NEW_VALUE
   curl -sI -H "X-Health-Check-Token: ${NEW_VALUE}" https://separationofconcerns.dev
   unset NEW_VALUE
   # Should return HTTP 200
   ```

---

### `mail__options__auth__pass`

**Purpose:** SMTP password for transactional email (password resets, staff invites).

**Impact:** Rotating this breaks outbound email until the container is restarted with the new value.

**Rotation steps:**

1. Reset the SMTP password in Mailgun:
   1. Log into [Mailgun](https://app.mailgun.com)
   2. Navigate to **Sending → Domain settings** in the left-hand sidebar
   3. Select your domain: `mg.separationofconcerns.dev`
   4. Click the **Reset password** button next to `postmaster@mg.separationofconcerns.dev`
   5. Copy the new password shown — it will not be displayed again

2. Update Infisical:
   ```bash
   read -s SECRET_VALUE; export SECRET_VALUE
   infisical secrets set "mail__options__auth__pass"="$SECRET_VALUE" \
     --projectId ghost-stack \
     --env dev
   unset SECRET_VALUE
   ```

3. Update `.env.secrets` on the instance and restart Ghost:
   ```bash
   tailscale ssh core@ghost-dev-01

   read -s NEW_VALUE
   sudo sed -i "s|^mail__options__auth__pass=.*|mail__options__auth__pass=${NEW_VALUE}|" \
     /var/mnt/storage/ghost-compose/.env.secrets
   unset NEW_VALUE

   sudo docker restart ghost-compose-ghost-1
   ```

4. Verify email delivery:
   1. Log into the Ghost admin dashboard at `https://admin.separationofconcerns.dev/ghost`
   2. Click **Welcome emails** under **Membership** in the left-hand sidebar
   3. Click the **Separation of Concerns** field in the **Free Members** section
   4. Click the **Test** button
   5. Set the email address to send the test to and click **Send**
   6. Verify the test email was received

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
   read -s SECRET_VALUE; export SECRET_VALUE
   infisical secrets set TINYBIRD_ADMIN_TOKEN="$SECRET_VALUE" \
     --projectId ghost-stack \
     --env dev
   unset SECRET_VALUE
   ```

3. Update `.env.secrets` on the instance and restart Ghost:
   ```bash
   tailscale ssh core@ghost-dev-01

   read -s NEW_VALUE
   sudo sed -i "s|^TINYBIRD_ADMIN_TOKEN=.*|TINYBIRD_ADMIN_TOKEN=${NEW_VALUE}|" \
     /var/mnt/storage/ghost-compose/.env.secrets
   unset NEW_VALUE

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

2. Update MySQL and `.env.secrets` on the instance:
   ```bash
   tailscale ssh core@ghost-dev-01

   # Read passwords securely — no echo, no history
   read -s NEW_PASSWORD    # enter the new ghost user password generated in step 1
   read -s ROOT_PASSWORD   # enter the current DATABASE_ROOT_PASSWORD

   # Apply ALTER USER — SQL piped via stdin, root auth via env var
   # Neither value appears in shell history or MySQL history
   printf "ALTER USER 'ghost'@'%%' IDENTIFIED BY '%s'; FLUSH PRIVILEGES;\n" "${NEW_PASSWORD}" | \
     sudo docker exec -i -e MYSQL_PWD="${ROOT_PASSWORD}" ghost-compose-db-1 mysql -u root
   unset ROOT_PASSWORD

   # Update .env.secrets with the new password so containers pick it up on restart
   sudo sed -i "s|^DATABASE_PASSWORD=.*|DATABASE_PASSWORD=${NEW_PASSWORD}|" \
     /var/mnt/storage/ghost-compose/.env.secrets
   unset NEW_PASSWORD
   ```

3. Update Infisical with the new password:
   ```bash
   read -s SECRET_VALUE; export SECRET_VALUE
   infisical secrets set DATABASE_PASSWORD="$SECRET_VALUE" \
     --projectId ghost-stack \
     --env dev
   unset SECRET_VALUE
   ```

4. Restart Ghost containers:
   ```bash
   tailscale ssh core@ghost-dev-01
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

2. Update MySQL and `.env.secrets` on the instance:
   ```bash
   tailscale ssh core@ghost-dev-01

   # Read passwords securely — no echo, no history
   read -s NEW_ROOT_PASSWORD      # enter the new root password generated in step 1
   read -s CURRENT_ROOT_PASSWORD  # enter the current DATABASE_ROOT_PASSWORD

   # Apply ALTER USER — SQL piped via stdin, current root auth via env var
   # Neither value appears in shell history or MySQL history
   printf "ALTER USER 'root'@'%%' IDENTIFIED BY '%s'; ALTER USER 'root'@'localhost' IDENTIFIED BY '%s'; FLUSH PRIVILEGES;\n" \
     "${NEW_ROOT_PASSWORD}" "${NEW_ROOT_PASSWORD}" | \
     sudo docker exec -i -e MYSQL_PWD="${CURRENT_ROOT_PASSWORD}" ghost-compose-db-1 mysql -u root
   unset CURRENT_ROOT_PASSWORD

   # Update .env.secrets with the new root password so containers pick it up on restart
   sudo sed -i "s|^DATABASE_ROOT_PASSWORD=.*|DATABASE_ROOT_PASSWORD=${NEW_ROOT_PASSWORD}|" \
     /var/mnt/storage/ghost-compose/.env.secrets
   unset NEW_ROOT_PASSWORD
   ```

3. Update Infisical with the new password:
   ```bash
   read -s SECRET_VALUE; export SECRET_VALUE
   infisical secrets set DATABASE_ROOT_PASSWORD="$SECRET_VALUE" \
     --projectId ghost-stack \
     --env dev
   unset SECRET_VALUE
   ```

4. Restart MySQL to pick up the new root password:
   ```bash
   tailscale ssh core@ghost-dev-01
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

## Post-Deploy: Verifying Boot-Time Secret Delivery

After deploying a new instance, run these steps to confirm `infisical-secrets-fetch.service` ran successfully and all secrets are in place.

### Step 1: Check Service Status

```bash
tailscale ssh core@ghost-dev-01 'systemctl status infisical-secrets-fetch.service'
```

Expected output: `Active: inactive (dead)` with result `exit-code=0`. The service is a oneshot unit — it runs once at boot and exits.

### Step 2: Check Service Logs

```bash
tailscale ssh core@ghost-dev-01 'journalctl -u infisical-secrets-fetch.service'
```

**Success output looks like:**

```
[infisical-secrets] Fetching secrets from Infisical (project=<id> env=dev)...
[infisical-secrets] Secrets written to /var/mnt/storage/ghost-compose/.env.secrets
[infisical-secrets] Tailscale monitor .env written to /var/mnt/storage/sbin/tailscale_monitor/.env
```

**Token already spent (subsequent reboots — normal):**

```
[infisical-secrets] ERROR: Boot token missing or empty at /etc/infisical/access-token — skipping fetch
```

This is expected on all reboots after the first. The service exits 0 and the existing `.env.secrets` on block storage is used.

### Step 3: Verify Ghost Secrets File

```bash
tailscale ssh core@ghost-dev-01 'ls -la /var/mnt/storage/ghost-compose/.env.secrets'
```

Expected output:
```
-rw------- 1 root root <size> <date> /var/mnt/storage/ghost-compose/.env.secrets
```

- Permissions must be `0600` (`-rw-------`)
- File must be non-empty (size > 0)

To verify all five expected keys are present (without revealing values):

```bash
tailscale ssh core@ghost-dev-01 'sudo grep -o "^[^=]*" /var/mnt/storage/ghost-compose/.env.secrets | sort'
```

Expected keys:

```
DATABASE_PASSWORD
DATABASE_ROOT_PASSWORD
HEALTH_CHECK_TOKEN
TINYBIRD_ADMIN_TOKEN
mail__options__auth__pass
```

### Step 4: Verify Tailscale Monitor Secrets File

```bash
tailscale ssh core@ghost-dev-01 'ls -la /var/mnt/storage/sbin/tailscale_monitor/.env'
```

Expected output:
```
-rw------- 1 root root <size> <date> /var/mnt/storage/sbin/tailscale_monitor/.env
```

- Permissions must be `0600` (`-rw-------`)

To verify all expected keys are present:

```bash
tailscale ssh core@ghost-dev-01 'sudo grep -o "^[^=]*" /var/mnt/storage/sbin/tailscale_monitor/.env | sort'
```

Expected keys:

```
TAILSCALE_CLIENT_ID
TAILSCALE_CLIENT_SECRET
TAILSCALE_TAILNET
```

### Step 5: Verify Boot Token Was Consumed

The boot token at `/etc/infisical/access-token` is shredded by the service on exit (whether successful or not). Confirm it is gone:

```bash
tailscale ssh core@ghost-dev-01 'ls -la /etc/infisical/access-token 2>&1 || echo "Token absent — consumed as expected"'
```

Expected: `No such file or directory` or the "Token absent" message.

You can also confirm token consumption in the Infisical UI:
1. Log into [app.infisical.com](https://app.infisical.com)
2. Navigate to **Organization Settings → Machine Identities → ghost-dev**
3. Under **Token Auth**, the issued token should show a `uses` count of `1` (consumed), or it may no longer appear if it was a single-use token that has been spent

---

## Troubleshooting

### Boot-Time Fetch Failed — Containers Have No Secrets

**Symptom:** `journalctl -u infisical-secrets-fetch.service` shows `ERROR: Infisical API call failed` on first boot. Ghost containers fail to start because `.env.secrets` is missing or empty.

**Cause:** The boot token was expired or already consumed before first boot. This can happen if `tofu apply` ran but instance startup was delayed past the token's TTL, or if the token was consumed by a previous failed boot attempt.

**Fix:** Force instance replacement to regenerate a fresh token:
```bash
# Trigger instance replacement by changing a value in instance_replacement_hash,
# or apply with -replace on the instance resource
./opentofu/scripts/tofu.sh dev apply
```

> **Note:** The boot token is a single-use Token Auth token (`number_of_uses_limit = 1`). If the API call failed partway through, the token is spent and cannot be reused.

---

### Boot-Time Fetch Failed — Token File Missing

**Symptom:** `journalctl -u infisical-secrets-fetch.service` shows `ERROR: Boot token missing or empty at /etc/infisical/access-token`.

**On first boot:** This indicates the Ignition config did not deliver the token file. Verify the `terraform_data` snapshot resource ([GHO-85](https://linear.app/noahwhite/issue/GHO-85)) was applied correctly and the token path `/etc/infisical/access-token` is present in the Butane config.

**On subsequent reboots:** This is expected and normal — the token was consumed and shredded on first boot. The existing `.env.secrets` on block storage is used.

---

### Secret Not Found in Infisical

**Symptom:** `infisical secrets list` does not show the expected secret.

**Check:** Confirm you are targeting the correct project and environment:
```bash
infisical secrets list --projectId ghost-stack --env dev
```

If the project does not exist, the Infisical infrastructure ([GHO-74](https://linear.app/noahwhite/issue/GHO-74)) has not been deployed. Run:
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
