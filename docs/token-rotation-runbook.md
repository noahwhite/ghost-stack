# Token Rotation Runbook

This document provides step-by-step procedures for rotating all tokens and secrets used in the ghost-stack infrastructure. Regular rotation is critical for maintaining security hygiene.

---

## Table of Contents

1. [Overview](#overview)
2. [Token Inventory](#token-inventory)
3. [CI/CD Tokens](#cicd-tokens)
   - [GHCR Read/Write Token](#ghcr-readwrite-token-ghcr_token)

   - [BWS Access Token](#bws-access-token-bws_access_token)
   - [Cloudflare API Token](#cloudflare-api-token-opentofu)
   - [Cloudflare Token Creator](#cloudflare-token-creator-dev-token-creator)
   - [Cloudflare Bootstrap Token](#cloudflare-bootstrap-token)
   - [R2 Access Key ID & Secret Access Key](#r2-access-key-id--secret-access-key)

   - [Vultr API Key](#vultr-api-key)
   - [Tailscale API Key](#tailscale-api-key)
   - [Tailscale Auth Key](#tailscale-auth-key-device-registration)
   - [PagerDuty OAuth Credentials](#pagerduty-oauth-credentials)
   - [PagerDuty User API Token](#pagerduty-user-api-token)
   - [Grafana Cloud Access Token](#grafana-cloud-access-token)
   - [Grafana Cloud Terraform Service Account Token](#grafana-cloud-terraform-service-account-token)
4. [Ghost Application Secrets (Infisical)](#ghost-application-secrets-infisical)
   - [TinyBird Workspace Admin Token](#tinybird-workspace-admin-token-tinybird_admin_token)
   - [TinyBird Tracker Token](#tinybird-tracker-token-tinybird_tracker_token)
   - [Health Check Token](#health-check-token)
   - [Ghost Mail SMTP Password](#ghost-mail-smtp-password)
   - [MySQL Database Credentials](#mysql-database-credentials)
5. [Claude Code Integration](#claude-code-integration)
   - [Claude GitHub MCP Access Token](#claude-github-mcp-access-token)
   - [Linear API Token](#linear-api-token)
6. [Verification Procedures](#verification-procedures)

---

## Overview

### Storage Locations

Secrets in this project are stored in three primary locations:

| Location | Purpose | Access Method |
|----------|---------|---------------|
| **Infisical** | Ghost application secrets fetched at boot | Infisical CLI / UI; instance uses machine identity |
| **Bitwarden Secrets Manager** | Runtime secrets for OpenTofu and scripts | `bws` CLI via `infra-shell.sh` |
| **GitHub Secrets** | CI/CD workflow secrets | GitHub Actions environment variables |

### GitHub Secrets Scoping

GitHub secrets are scoped at two levels:

| Scope | Usage | Naming Convention |
|-------|-------|-------------------|
| **Repository-level** | PR workflows (cannot access environment secrets) | `SECRET_NAME_DEV` suffix |
| **Environment-scoped (dev)** | Deploy workflows (`environment: dev`) | `SECRET_NAME` (no suffix) |
| **Environment-scoped (dev-ci)** | PR workflows (`environment: dev-ci`) | `SECRET_NAME` (no suffix) |

**Important:** When a secret is environment-scoped, you must update it in the GitHub environment settings (Settings → Environments → dev or dev-ci), not in the repository secrets. Secrets shared between `dev` and `dev-ci` must be updated in both environments.

---

## Token Inventory

### Quick Reference Table

| Token | Source | GitHub Secret | Env Scope | Expiration |
|-------|--------|---------------|-----------|------------|
| GHCR RW Token | GitHub PAT | `GHCR_TOKEN` | Repository | Configurable |

| BWS Access Token¹ | Bitwarden | `BWS_ACCESS_TOKEN` | Environment (dev) | 30 days |
| Cloudflare API Token | Cloudflare | N/A | N/A | Configurable |
| Cloudflare Token Creator | Cloudflare | N/A | N/A | 30 days recommended |
| Cloudflare Bootstrap Token | Cloudflare | N/A | N/A | 30 days recommended |
| R2 Access Key ID | Cloudflare R2 | N/A | N/A | 90 days |
| R2 Secret Access Key | Cloudflare R2 | N/A | N/A | 90 days |

| Vultr API Key | Vultr | N/A | N/A | 30 days |
| Tailscale API Key | Tailscale | N/A | N/A | 90 days default |
| Tailscale Auth Key | Tailscale (OpenTofu) | N/A | N/A | One-time (single use) |
| PagerDuty Client ID | PagerDuty | N/A | N/A | Never |
| PagerDuty Client Secret | PagerDuty | N/A | N/A | Never |
| PagerDuty User Token | PagerDuty | N/A | N/A | Never |
| Grafana Cloud Token | Grafana | N/A | N/A | 30 days |
| Grafana Cloud SA Token | Grafana | N/A | N/A | 30 days |
| TinyBird Workspace Admin | TinyBird | N/A (instance) | N/A | Never |
| TinyBird Tracker Token | TinyBird | N/A (instance) | N/A | Never |
| Health Check Token | Infisical | `HEALTH_CHECK_TOKEN` | Environment (dev) | N/A |
| Admin IP | N/A | `ADMIN_IP` | Environment (dev) | N/A |
| Cloudflare Zone ID | N/A | `CLOUDFLARE_ZONE_ID` | Environment (dev) | N/A |
| Claude MCP Token | GitHub PAT | N/A (local) | N/A | Configurable |
| Linear API Token | Linear | N/A (local) | N/A | Never |

¹ BWS Access Tokens expire after 30 days; rotate before expiry.

---

## CI/CD Tokens

These tokens are used by GitHub Actions workflows, OpenTofu infrastructure provisioning, and supporting infrastructure services. Most are stored in Bitwarden Secrets Manager and retrieved at runtime by `infra-shell.sh`.

---

### GHCR Read/Write Token (`GHCR_TOKEN`)

**Purpose:** Authenticate to GitHub Container Registry to pull the `ghost-stack-shell` image in CI/CD workflows.

**Scope:** Repository-level (used by both PR and deploy workflows)

**Expiration:** Configurable (recommend 90 days)

#### Rotation Steps

1. **Generate new token:**
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Tokens (classic)
   - Click "Generate new token (classic)"
   - Name: `ghost-stack-ghcr-rw`
   - Expiration: 90 days (or your preferred period)
   - Scopes: `repo` (includes `repo:status`, `repo_deployment`, `public_repo`, `repo:invite`, `security_events`), `write:packages`, `read:packages`
   - Click "Generate token"
   - Copy the token immediately

2. **Update GitHub Secret:**
   - Go to `github.com/noahwhite/ghost-stack` → Settings → Secrets and variables → Actions
   - Find `GHCR_TOKEN` under Repository secrets
   - Click "Update"
   - Paste the new token
   - Click "Update secret"

3. **Verify:**
   - Trigger a workflow that uses GHCR (e.g., create a draft PR)
   - Confirm the "Log in to GHCR" step succeeds

---


### BWS Access Token (`BWS_ACCESS_TOKEN`)

**Purpose:** Authenticate to Bitwarden Secrets Manager to retrieve runtime secrets in CI/CD.

**Scope:** Environment-scoped (`dev` and `dev-ci` environments)

- `dev` environment: Used by deploy workflows
- `dev-ci` environment: Used by PR workflows (shadow environment for validation)

**Expiration:** 30 days (set at creation time)

#### Rotation Steps

1. **Generate new token:**
   - Log into Bitwarden web vault
   - Go to Organizations → Machine accounts
   - Select the `github-actions` machine account
   - Go to Access tokens tab
   - Click "Create access token"
   - Name: `gha-bw-tok-MMDDYY` (where MMDDYY is the expiration date, e.g., `gha-bw-tok-032626`)
   - Set expiration to 30 days
   - Copy the token immediately (shown only once)

2. **Update GitHub Secrets (both environments):**
   - Go to `github.com/noahwhite/ghost-stack` → Settings → Environments → dev
   - Find `BWS_ACCESS_TOKEN` → Update → paste new token
   - Repeat for Environments → dev-ci

3. **Revoke old token:**
   - In Bitwarden, delete the old access token from the machine account

4. **Verify:**
   - Trigger a deploy workflow
   - Confirm secrets retrieval succeeds in the logs

---

### Cloudflare API Token (OpenTofu)

**Purpose:** Manage Cloudflare resources (DNS, Page Rules) via OpenTofu.

**Bitwarden Secret ID:** `59624245-6a0c-4fde-9d6d-b39c014882a6`

**Expiration:** Configurable at creation

#### Rotation Steps

1. **Generate new token:**
   - Log into Cloudflare dashboard (dev account)
   - Go to My Profile → API Tokens → Create Token
   - Use "Edit zone DNS" template or custom:
     - Zone: DNS: Edit
     - Zone: Zone: Read
     - Zone Resources: Include specific zone or all zones
   - Do not set IP restrictions — GitHub runner IPs are too numerous and dynamic to whitelist
   - Set TTL (recommend 90 days)
   - Create token and copy immediately

2. **Update Bitwarden:**
   - Log into Bitwarden web vault
   - Find secret with ID `59624245-6a0c-4fde-9d6d-b39c014882a6`
   - Update the value with the new token
   - Save

3. **Revoke old token:**
   - In Cloudflare, go to My Profile → API Tokens
   - Find the old token and click "Revoke"

4. **Verify:**
   - Run `./opentofu/scripts/tofu.sh dev plan`
   - Confirm no authentication errors

---

### Cloudflare Token Creator (`dev-token-creator`)

**Purpose:** Create other scoped Cloudflare API tokens programmatically.

**Storage:** Bitwarden Secrets Manager

**Expiration:** 30 days recommended

#### Rotation Steps

1. **Generate new token:**
   - Log into Cloudflare dashboard (dev account)
   - Go to My Profile → API Tokens → Create Token
   - Select template: "Create Additional Tokens"
   - Permissions: User, API Tokens, Edit
   - Do not set IP restrictions
   - Set TTL: 30 days
   - Create and copy token

2. **Update Bitwarden:**
   - Log into Bitwarden web vault
   - Find secret with ID `6bc45446-1aa1-4e2c-804e-b39b002c32ea`
   - Update the value with the new token
   - Save

3. **Revoke old token:**
   - In Cloudflare, revoke the previous token creator

---

### Cloudflare Bootstrap Token

**Purpose:** Provision R2 bucket and DNS zone during initial bootstrap.

**Storage:** Bitwarden Secrets Manager

**Expiration:** 30 days recommended

#### Rotation Steps

1. **Generate new token:**
   - Use the token creator script (recommended):
     ```bash
     ./opentofu/bootstrap/scripts/generate-bootstrap-token.sh
     ```
   - Or manually create in Cloudflare:
     - Go to My Profile → API Tokens → Create Token → Create Custom Token
     - Name: `bootstrap-dev-token`
     - Add the following permission rows:

       | Resource Type | Permission | Access |
       |---|---|---|
       | Account | Workers R2 Storage | Read |
       | Account | Workers R2 Storage | Edit |
       | Account | Email Routing Addresses | Read |
       | Account | Email Routing Addresses | Edit |
       | Zone | Zone Settings | Read |
       | Zone | Zone Settings | Edit |
       | Zone | Zone | Read |
       | Zone | Zone | Edit |
       | Zone | DNS | Read |
       | Zone | DNS | Edit |
       | Zone | Email Routing Rules | Read |
       | Zone | Email Routing Rules | Edit |

     - **Account Resources:** Set to Include → **Noah@separationofconcerns.dev's Account**
     - **Zone Resources:** Set to Include → **Specific zone** → **separationofconcerns.dev**

     - **IP Address Filtering:** Set Operator to **is in**, then click **Use my IP** (assuming you are on the dev workstation — otherwise enter the dev workstation's public IP)
     - **TTL:** Set start date to today and end date to 30 days in the future
     - Click **Continue to Summary**, review all details, and if correct click **Create Token**
     - Copy the token immediately (shown only once)

2. **Update Bitwarden:**
   - Log into Bitwarden web vault
   - Find secret with ID `bde8e810-8be6-4090-aa1d-b39b002c9eb8`
   - Update the value with the new token
   - Save

---

### R2 Access Key ID & Secret Access Key

**Purpose:** Access R2 buckets for OpenTofu state storage and sysext image storage.

**Bitwarden Secret IDs:**
- Access Key ID: `9dfdf110-5a84-48c3-ad7e-b39b002afd6b`
- Secret Access Key: `f5d9794d-fd45-4dcb-9994-b39b002b5056`

**Expiration:** Never (but rotate periodically)

#### Rotation Steps

1. **Generate new credentials:**
   - Log into Cloudflare dashboard
   - Go to Storage & Databases → R2 Object Storage → Overview
   - Click the **Manage** button next to **API tokens** in the Account Details section
   - Click **Create Account API token**
   - Name: `ghost-stack-r2-YYYY-MM`
   - Permissions: Object Read & Write
   - Specify bucket(s): `ghost-stack-dev-state`, `ghost-dev-sysext-images`
   - TTL: 90 days
   - Client IP Address Filtering: leave blank — GitHub runner IPs are too numerous and dynamic to whitelist
   - Create and copy both Access Key ID and Secret Access Key

2. **Update Bitwarden:**
   - Update secret `9dfdf110-5a84-48c3-ad7e-b39b002afd6b` with new Access Key ID
   - Update secret `f5d9794d-fd45-4dcb-9994-b39b002b5056` with new Secret Access Key

3. **Revoke old credentials:**
   - In Cloudflare R2, delete the old API token

4. **Verify:**
   - Run `./opentofu/scripts/tofu.sh dev plan`
   - Confirm state can be read/written

---


### Vultr API Key

**Purpose:** Manage Vultr compute instances, firewalls, and block storage.

**Bitwarden Secret ID:** `d68b6562-0d9e-424c-b2c5-b39c013ae34d`

**Expiration:** 30 days

#### Rotation Steps

1. **Generate new key:**
   - Log into Vultr (dev account)
   - Go to Account → API
   - Click "Enable API" if not already enabled
   - Set expiration to 30 days
   - Copy the API key (or regenerate if rotating)

   **Note:** Vultr only supports one API key per account. Regenerating creates a new key and invalidates the old one immediately.

   **IP Access Control:** The API page has a separate IP access control section that applies to all API keys account-wide. It is currently configured with the management workstation IP and a catch-all **Any IPv4** entry. The catch-all is required because GitHub Actions runner IPs cannot be whitelisted. Do not remove either entry.

2. **Update Bitwarden:**
   - Update secret `d68b6562-0d9e-424c-b2c5-b39c013ae34d` with new key

3. **Verify:**
   - Run `./opentofu/scripts/tofu.sh dev plan`
   - Confirm Vultr resources are accessible

---

### Tailscale API Key

**Purpose:** Register/deregister Tailscale devices via OpenTofu.

**Bitwarden Secret IDs:**
- API Key: `34b620b7-edf6-4d06-9792-b39b00317467`
- Tailnet: `a8f07ce5-ed4d-42bb-b012-b39b00311d41`

**Expiration:** 90 days by default

#### Rotation Steps

1. **Generate new key:**
   - Log into Tailscale admin console
   - Go to Settings → Keys
   - Click "Generate access token..."
   - Description: `ghost-stack-tofu-YYYY-MM`
   - Expiry: 90 days
   - Copy the key

2. **Update Bitwarden:**
   - Update secret `34b620b7-edf6-4d06-9792-b39b00317467` with new key

3. **Revoke old key:**
   - In Tailscale, delete the old API key

4. **Verify:**
   - Run `./opentofu/scripts/tofu.sh dev plan`
   - Confirm Tailscale provider initializes

---

### Tailscale Auth Key (Device Registration)

**Purpose:** Authenticate new Flatcar instances to join the Tailnet during first boot.

**Storage:** Generated dynamically by OpenTofu via `tailscale_tailnet_key` resource

**Expiration:** One-time use (key is invalidated after first use)

**Important:** This project uses **one-time auth keys** for security. The key is generated automatically by OpenTofu during `tofu apply` and is configured with `reusable = false`, meaning it's invalidated after a single use. This prevents key reuse if exposed in OpenTofu state or logs.

#### Why One-Time Keys?

| Key Type | Risk if Exposed | Mitigation |
|----------|-----------------|------------|
| Reusable | Attacker can register unlimited rogue devices | Manual revocation required |
| One-time | Key already invalidated after legitimate use | Automatic - no action needed |

#### How It Works

The auth key is managed entirely by OpenTofu:

1. **Key Generation:** The `tailscale_tailnet_key` resource in `opentofu/modules/tailscale/main.tofu` creates a new auth key
2. **Key Configuration:**
   - `reusable = false` - One-time use only
   - `ephemeral = false` - Device persists after disconnect
   - `preauthorized = true` - No admin approval needed
   - Tagged with `tag:ghost-dev`
3. **Key Injection:** The key is passed to the Flatcar instance via Ignition userdata
4. **Key Consumption:** On first boot, `tailscale-auth.service` uses the key to join the Tailnet
5. **Key Invalidation:** Tailscale automatically invalidates the key after first use

#### Pre-Provisioning Checklist

Before running `tofu apply` that will create or recreate an instance:

1. **Remove the old Tailscale device** from the admin console (see `docs/runbooks/tailscale-device-cleanup.md`)
2. **Run `tofu apply`** - OpenTofu will generate a fresh one-time auth key automatically
3. **Verify the device appears** in Tailscale admin console after instance boots

#### Key Lifecycle During Provisioning

```
tofu apply
    │
    ├─► tailscale_tailnet_key resource creates new one-time key
    │
    ├─► Key embedded in Ignition userdata (stored in tofu state)
    │
    ├─► Vultr instance created with Ignition config
    │
    └─► Instance boots
            │
            ├─► tailscale-auth.service runs on first boot
            │
            ├─► tailscale up --authkey=<key> --ssh
            │
            └─► Key is consumed and invalidated by Tailscale

Subsequent tofu apply (no instance change):
    │
    └─► Same key reference in state, but key is already invalidated
        (This is fine - the device is already registered)
```

#### Verification

After instance provisioning:

```bash
# SSH to the new instance
tailscale ssh core@ghost-dev-01

# Verify Tailscale is connected
tailscale status
```

To verify the key was invalidated:
1. Go to Tailscale admin console → Settings → Keys
2. The auth key should show as "Used" or no longer appear in active keys
3. The new device should appear in the Machines list

#### Troubleshooting

- **Instance fails to join Tailnet:** The auth key may have been consumed by a previous failed provisioning attempt. Run `tofu apply` again to generate a fresh key.
- **Device named `ghost-dev-01-1`:** The old device wasn't removed from Tailscale before reprovisioning. Remove it and reprovision. See `docs/runbooks/tailscale-device-cleanup.md`
- **Key in state but device not registered:** The instance may have failed to boot or the tailscale-auth.service failed. Check instance console and `journalctl -u tailscale-auth.service`

#### Security Considerations

- **State file exposure:** The auth key is stored in OpenTofu state. Use encrypted state backend (R2 with server-side encryption) and restrict state access.
- **One-time mitigation:** Even if state is compromised, the key cannot be reused after the legitimate instance has consumed it.
- **Key rotation:** Each `tofu apply` that recreates the instance generates a fresh key automatically.

---

### PagerDuty OAuth Credentials

**Purpose:** Configure PagerDuty integrations via OpenTofu.

**Bitwarden Secret IDs:**
- Subdomain: `8ee84397-e563-4278-9a3f-b39c013f7575`
- Client ID: `7d51661b-736a-43ff-b01f-b39c013fe49b`
- Client Secret: `b15575c0-0d28-459d-b92d-b39c01403a38`

**Expiration:** Never

#### Rotation Steps

1. **Regenerate OAuth credentials:**
   - Log into PagerDuty
   - Go to Integrations → Developer Mode → My Apps
   - Find your OAuth app
   - Regenerate client secret (this invalidates the old one)

2. **Update Bitwarden:**
   - Update secret `b15575c0-0d28-459d-b92d-b39c01403a38` with new Client Secret

---

### PagerDuty User API Token

**Purpose:** User-level API access for PagerDuty operations.

**Bitwarden Secret ID:** `02805292-4311-4290-9b6e-b39c01554ae6`

**Expiration:** Never

#### Rotation Steps

1. **Generate new token:**
   - Log into PagerDuty
   - Go to My Profile → User Settings → Create API User Token
   - Description: `ghost-stack-tofu-YYYY-MM`
   - Copy the token

2. **Update Bitwarden:**
   - Update secret `02805292-4311-4290-9b6e-b39c01554ae6` with new token

3. **Revoke old token:**
   - Delete the old API user token in PagerDuty

---

### Grafana Cloud Access Token

**Purpose:** Configure Grafana Cloud observability via OpenTofu.

**Bitwarden Secret:** `grafana_cloud_access_token`

**Bitwarden Secret ID:** `bfc8dd06-bd97-499a-98f8-b3a101570606`

**Expiration:** 30 days

#### Rotation Steps

1. **Generate new token:**
   - Log into Grafana Cloud
   - Go to Administration → Users and access → Cloud access policies
   - Find the access policy named `ghost-stack-dev-terraform-token`
   - Click "Add token"
   - Name: `soc-dev-grafana-cloud-access-tok-DD-MM-YYYY` (use expiration date)
   - Set expiry to 30 days
   - Click "Create"
   - Copy the token immediately

2. **Update Bitwarden:**
   - Update the secret `grafana_cloud_access_token` with the new token value
   - Update the notes field with the new expiration date

3. **Revoke old token:**
   - In Grafana Cloud, delete the old token from the access policy

4. **Verify the token before saving:**
   ```bash
   read -s BEARER_TOKEN
   curl -H "Authorization: Bearer ${BEARER_TOKEN}" https://grafana.com/api/instances
   unset BEARER_TOKEN
   ```
   - Should return a JSON response with your stacks
   - If you get 401 Unauthorized, the token is invalid or truncated

5. **Verify after updating Bitwarden:**
   - Run `./opentofu/scripts/tofu.sh dev plan`
   - Confirm Grafana Cloud provider initializes

#### Troubleshooting

- **Token appears truncated:** Grafana cloud access tokens are base64-encoded and often end with `=` or `==`. Ensure the entire token was copied including any trailing characters.
- **Token format:** Valid cloud access tokens are typically 50+ characters and follow the pattern `glc_xxxx...xxxx==`. If significantly shorter or missing the `==` suffix, it was likely truncated during copy.
- **401 Unauthorized after rotation:** Always verify the token works with the curl command above before saving to Bitwarden. If curl fails, regenerate the token.
- **Copy issues:** When copying tokens, use the copy button in the Grafana UI rather than manual selection to avoid truncation.

---

### Grafana Cloud Terraform Service Account Token

**Purpose:** Service account for Grafana Cloud Terraform provider (soc-dev project).

**Bitwarden Secret:** `grafana_cloud_soc_dev_terraform_sa`

**Bitwarden Secret ID:** `3ebc4398-f4fa-448c-b2c1-b3a6006c063d`

**Expiration:** 30 days

#### Rotation Steps

1. **Generate new token:**
   - Log into Grafana Cloud
   - Go to Administration → Users and access → Service Accounts
   - Click on `sa-1-extsvc-grafana-terraform-app` to open the service account details page
   - Click "Add service account token"
   - Keep the auto-generated name
   - Set expiration to 30 days
   - Click "Generate token"
   - Copy the token immediately

2. **Update Bitwarden:**
   - Update the secret `grafana_cloud_soc_dev_terraform_sa` with the new token value
   - Update the comment with the new token name (auto-generated)
   - Update the notes field with the new expiration date

3. **Delete old token:**
   - In Grafana Cloud, remove the old token from the service account

4. **Verify the token before saving:**
   ```bash
   read -s BEARER_TOKEN
   curl -H "Authorization: Bearer ${BEARER_TOKEN}" \
     https://separationofconcerns0dev.grafana.net/api/folders
   unset BEARER_TOKEN
   ```
   - Should return a JSON response with folders
   - If you get 401 Unauthorized, the token is invalid or truncated

5. **Verify after updating Bitwarden:**
   - Run `./opentofu/scripts/tofu.sh dev plan`
   - Confirm Grafana resources are accessible

#### Troubleshooting

- **Token appears truncated:** Service account tokens are base64-encoded and often end with `=` or `==`. Ensure the entire token was copied including any trailing characters.
- **Token format:** Valid service account tokens are typically 50+ characters and follow the pattern `glsa_xxxx...xxxx==`. If significantly shorter or missing the `==` suffix, it was likely truncated during copy.
- **401 Unauthorized after rotation:** Always verify the token works with the curl command above before saving to Bitwarden. If curl fails, regenerate the token.
- **Wrong service account:** Ensure you're creating the token under `sa-1-extsvc-grafana-terraform-app`, not a different service account.
- **Copy issues:** When copying tokens, use the copy button in the Grafana UI rather than manual selection to avoid truncation.

---

## Ghost Application Secrets (Infisical)

These secrets are stored in Infisical and fetched by the Ghost instance at boot time via `infisical-secrets-fetch.service`. For initial provisioning and an overview of the rotation approach, see [Infisical Secret Provisioning and Rotation](./runbooks/infisical-secrets.md).

---

### TinyBird Workspace Admin Token (`TINYBIRD_ADMIN_TOKEN`)

**Purpose:** JWT signing for Ghost Stats dashboard queries and administrative TinyBird operations.

**Storage:** `/var/mnt/storage/ghost-compose/.env.secrets` on the Ghost instance

**Expiration:** Never (but rotate periodically)

#### Critical: Workspace Admin Token vs Personal Admin Token

**⚠️ Ghost requires the Workspace admin token, NOT a personal admin token.**

| Token Type | Name in TinyBird UI | Works for API Calls | Works for JWT Signing |
|------------|---------------------|---------------------|----------------------|
| Workspace admin token | "Workspace admin token" | ✓ | ✓ |
| Personal admin token | "Admin your@email.com" | ✓ | ✗ |

Ghost generates JWTs signed with the admin token for browser-side TinyBird API calls. TinyBird validates these signatures **only** against the Workspace admin token. Using a personal admin token will result in:
- Direct API calls work (e.g., `curl` with the token)
- Ghost Stats dashboard shows 403 Forbidden errors
- JWT signature verification fails

#### How to Identify the Correct Token

1. Log into TinyBird dashboard
2. Go to **Tokens** section
3. Look for the token named exactly **"Workspace admin token"**
4. Do NOT use tokens named "Admin your@email.com" - these are personal tokens

#### Rotation Steps

1. **Refresh the token in TinyBird:**
   - Log into [TinyBird console](https://ui.tinybird.co) and select the `soc_dev` workspace
   - Click **Tokens** in the left sidebar
   - Find **"Workspace admin token"** and click the refresh button — TinyBird will display the CLI command
   - Run the command locally:
     ```bash
     tb --cloud token refresh "workspace admin token"
     ```
   - Copy the new token value from the command output

2. **Update Infisical:**
   - Log into [app.infisical.com](https://app.infisical.com) → **Ghost Stack** → **dev** → **Secrets**
   - Find `TINYBIRD_ADMIN_TOKEN` and update the value

   > **Alternative (CLI):**
   > ```bash
   > read -s SECRET_VALUE; export SECRET_VALUE
   > infisical secrets set TINYBIRD_ADMIN_TOKEN="$SECRET_VALUE" \
   >   --projectId ghost-stack \
   >   --env dev
   > unset SECRET_VALUE
   > ```

3. **Update `.env.secrets` on the instance and restart Ghost:**
   ```bash
   tailscale ssh core@ghost-dev-01

   read -s NEW_VALUE
   sudo sed -i "s|^TINYBIRD_ADMIN_TOKEN=.*|TINYBIRD_ADMIN_TOKEN=${NEW_VALUE}|" \
     /var/mnt/storage/ghost-compose/.env.secrets
   unset NEW_VALUE

   sudo docker restart ghost-compose-ghost-1
   ```

4. **Verify Ghost Stats is functional:**
   - Go to Ghost Admin → **Analytics**
   - Confirm analytics data loads without errors

#### Troubleshooting

**Symptom:** Ghost Stats shows "Unable to load data" or network requests return 403.

**Diagnosis:**
```bash
# Check what token Ghost has
docker exec ghost-compose-ghost-1 sh -c 'echo "${tinybird__adminToken:0:10}..."'

# Test JWT signing by decoding a Ghost-generated token
# (Get token from Chrome DevTools Network tab on Stats page)
echo "JWT_TOKEN_HERE" | cut -d. -f2 | base64 -d | jq .
```

**Common causes:**
1. Using personal admin token instead of Workspace admin token
2. Token has trailing whitespace or newlines
3. Token was regenerated in TinyBird (invalidates all existing JWTs)

---

### TinyBird Tracker Token (`TINYBIRD_TRACKER_TOKEN`)

**Purpose:** Authenticate page view tracking events sent to TinyBird via traffic-analytics proxy.

**Storage:** `/var/mnt/storage/ghost-compose/.env.generated` (auto-generated by tinybird-provision.service)

**Expiration:** Never

#### How It Works

The tracker token is automatically extracted during provisioning:
1. `tinybird-provision.service` runs on boot
2. Uses the admin token to query `tb token ls`
3. Extracts the token named "tracker"
4. Writes it to `.env.generated`

#### Manual Rotation (if needed)

> **Note:** On instance recreation, `tinybird-provision.service` automatically fetches the current tracker token from TinyBird and writes it to `.env.generated`. Manual rotation is only needed if the token is compromised on a running instance.

1. **Refresh the token in TinyBird:**
   - Log into [TinyBird console](https://ui.tinybird.co) and select the `soc_dev` workspace
   - Click **Tokens** in the left sidebar
   - Find **"tracker"** and click the refresh button — TinyBird will display the CLI command
   - Run the command locally:
     ```bash
     tb --cloud token refresh "tracker"
     ```
   - Copy the new token value from the command output

2. **Update `.env.generated` on the instance:**
   ```bash
   tailscale ssh core@ghost-dev-01

   read -s NEW_VALUE
   sudo sed -i "s|^TINYBIRD_TRACKER_TOKEN=.*|TINYBIRD_TRACKER_TOKEN=${NEW_VALUE}|" \
     /var/mnt/storage/ghost-compose/.env.generated
   unset NEW_VALUE
   ```

3. **Restart the stack:**
   ```bash
   sudo systemctl restart ghost-compose
   ```

---

### Health Check Token

**Secret name:** `HEALTH_CHECK_TOKEN` (managed in Infisical)

**Purpose:** Caddy uses this token to authenticate health check requests from GitHub Actions and manual `curl` checks.

**Impact:** Rotating this token invalidates all existing health check calls. Update the GitHub Secret `HEALTH_CHECK_TOKEN` (in both `dev` and `dev-ci` environments) at the same time.

#### Rotation Steps

1. Generate a new token (random, URL-safe):
   ```bash
   openssl rand -base64 32 | tr '+/' '-_' | tr -d '='
   ```

2. Update Infisical:
   - Log into [app.infisical.com](https://app.infisical.com) → **Ghost Stack** → **dev** → **Secrets**
   - Find `HEALTH_CHECK_TOKEN` and update the value

   > **Alternative (CLI):**
   > ```bash
   > read -s SECRET_VALUE; export SECRET_VALUE
   > infisical secrets set HEALTH_CHECK_TOKEN="$SECRET_VALUE" \
   >   --projectId ghost-stack \
   >   --env dev
   > unset SECRET_VALUE
   > ```

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

### Ghost Mail SMTP Password

**Secret name:** `mail__options__auth__pass` (managed in Infisical)

**Purpose:** SMTP password for transactional email via Mailgun (password resets, staff invites).

**Impact:** Rotating this breaks outbound email until Ghost is restarted with the new value.

#### Rotation Steps

1. Reset the SMTP password in Mailgun:
   1. Log into [Mailgun](https://app.mailgun.com)
   2. Navigate to **Sending → Domain settings** in the left-hand sidebar
   3. Select your domain: `mg.separationofconcerns.dev`
   4. Click the **Reset password** button next to `postmaster@mg.separationofconcerns.dev`
   5. Copy the new password shown — it will not be displayed again

2. Update Infisical:
   - Log into [app.infisical.com](https://app.infisical.com) → **Ghost Stack** → **dev** → **Secrets**
   - Find `mail__options__auth__pass` and update the value

   > **Alternative (CLI):**
   > ```bash
   > read -s SECRET_VALUE; export SECRET_VALUE
   > infisical secrets set "mail__options__auth__pass"="$SECRET_VALUE" \
   >   --projectId ghost-stack \
   >   --env dev
   > unset SECRET_VALUE
   > ```

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

### MySQL Database Credentials

Both MySQL secrets are managed in Infisical but also require a MySQL `ALTER USER` statement — updating Infisical alone does not change the password stored in MySQL's data directory.

#### `DATABASE_PASSWORD`

**Purpose:** Password for the `ghost` MySQL user. Used by Ghost to connect to its database.

**Impact:** This rotation requires coordinating a MySQL password change with an Infisical update. If they get out of sync, Ghost will fail to connect to the database.

##### Rotation Steps

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
   - Log into [app.infisical.com](https://app.infisical.com) → **Ghost Stack** → **dev** → **Secrets**
   - Find `DATABASE_PASSWORD` and update the value

   > **Alternative (CLI):**
   > ```bash
   > read -s SECRET_VALUE; export SECRET_VALUE
   > infisical secrets set DATABASE_PASSWORD="$SECRET_VALUE" \
   >   --projectId ghost-stack \
   >   --env dev
   > unset SECRET_VALUE
   > ```

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

#### `DATABASE_ROOT_PASSWORD`

**Purpose:** MySQL root password. Used for administrative database operations only — Ghost uses `DATABASE_PASSWORD` (ghost user), not the root password.

**Impact:** This only affects administrative access to MySQL, not Ghost's normal operation.

##### Rotation Steps

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
   - Log into [app.infisical.com](https://app.infisical.com) → **Ghost Stack** → **dev** → **Secrets**
   - Find `DATABASE_ROOT_PASSWORD` and update the value

   > **Alternative (CLI):**
   > ```bash
   > read -s SECRET_VALUE; export SECRET_VALUE
   > infisical secrets set DATABASE_ROOT_PASSWORD="$SECRET_VALUE" \
   >   --projectId ghost-stack \
   >   --env dev
   > unset SECRET_VALUE
   > ```

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

## Claude Code Integration

These tokens are used locally by Claude Code for GitHub and Linear integration. They are not stored in Bitwarden or GitHub Secrets.

---

### Claude GitHub MCP Access Token

**Purpose:** Allows Claude Code to interact with GitHub via MCP (Model Context Protocol) for issue management, PR creation, etc.

**Scope:** Local development only (not stored in GitHub)

**Expiration:** Configurable (recommend 90 days)

#### Rotation Steps

1. **Generate new token:**
   - Go to GitHub → Settings → Developer settings → Personal access tokens → Fine-grained tokens
   - Click "Generate new token"
   - Name: `claude-mcp-access`
   - Expiration: 90 days
   - Repository access: Select repositories → choose `ghost-stack`, `alloy-sysext-build`
   - Permissions:
     - Contents: Read and write
     - Issues: Read and write
     - Pull requests: Read and write
     - Metadata: Read-only
   - Click "Generate token"

2. **Update local configuration:**
   - Update your Claude Code MCP configuration with the new token
   - Location varies by setup (typically `~/.config/claude/mcp.json` or similar)

3. **Verify:**
   - Use Claude Code to list issues or create a test comment

---

### Linear API Token

**Purpose:** Claude Code integration with Linear for issue tracking.

**Storage:** Local Claude Code MCP configuration

**Expiration:** Never

#### Rotation Steps

1. **Log into Linear.**

2. **Open your account settings:**
   - Click **NO noahwhite** (avatar/initials) in the bottom-left corner
   - Select **Settings** from the dropdown menu

3. **Navigate to Security & access.**

4. **Generate a new key:**
   - Under **Personal API keys**, click **New API Key**
   - Name it something like `claude-mcp-linear-key-2` (increment the suffix each rotation)
   - Click **Only select permissions...** and select **Read and Write**
   - Under **Team access**, select **All teams you have access to**
   - Click **Create**
   - Copy the token immediately — it is only shown once

5. **Update local configuration:**
   - Update your Claude Code MCP configuration with the new token

6. **Test the new key:**
   - Open a Claude dev container session and verify the Linear MCP integration responds correctly

7. **Revoke the old key:**
   - Back on the **Security & access** screen, find the old key in the list
   - Click the **...** button next to it
   - Select **Revoke API key**

---

## Verification Procedures

After rotating any token, perform the following verifications:

### CI/CD Workflow Verification

1. **PR Workflow:**
   - Create a draft PR with a minor change
   - Verify all workflow steps pass:
     - Log in to GHCR
     - Retrieve secrets from Bitwarden
     - OpenTofu plan executes successfully

2. **Deploy Workflow:**
   - Trigger a manual workflow run or merge a PR
   - Verify deployment completes successfully

### Local Development Verification

1. **OpenTofu:**
   ```bash
   source docker/scripts/infra-shell.sh
   ./opentofu/scripts/tofu.sh dev plan
   ```
   Confirm no authentication errors.

2. **Bitwarden:**
   ```bash
   bws secret list
   ```
   Confirm secrets are accessible.

### Service-Specific Verification

| Service | Verification Command/Action |
|---------|---------------------------|
| Cloudflare | `curl -X GET "https://api.cloudflare.com/client/v4/user/tokens/verify" -H "Authorization: Bearer $TOKEN"` |
| Vultr | `curl -H "Authorization: Bearer $VULTR_API_KEY" https://api.vultr.com/v2/account` |
| Tailscale | Check admin console for API key status |
| PagerDuty | OpenTofu plan with PagerDuty resources |
| Grafana | OpenTofu plan with Grafana resources |
| TinyBird | Ghost Admin → Analytics shows data without 403 errors |

---

## Rotation Schedule Recommendations

| Token | Recommended Rotation | Priority |
|-------|---------------------|----------|
| GHCR Token | Every 90 days | High |

| Cloudflare API Tokens | Every 90 days | High |
| Tailscale API Key | Before 90-day expiry | High |
| Tailscale Auth Key | Before each instance provisioning | High |
| Grafana Tokens | Every 30 days (expiry enforced) | High |
| BWS Access Tokens | Every 30 days (before expiry) | High |
| R2 Credentials | Every 90 days | High |
| Vultr API Key | Every 30 days (before expiry) | High |
| PagerDuty Tokens | Annually | Low |
| TinyBird Tokens | Annually | Low |
| Linear API Token | Annually | Low |

---

## Emergency Rotation

If a token is suspected to be compromised:

1. **Immediately revoke** the compromised token at its source
2. **Generate a new token** following the steps above
3. **Update all storage locations** (Bitwarden, GitHub Secrets)
4. **Audit logs** for unauthorized access
5. **Document the incident** and review access patterns

---

_This document lives at `docs/token-rotation-runbook.md` in the repository._
