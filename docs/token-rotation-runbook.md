# Token Rotation Runbook

This document provides step-by-step procedures for rotating all tokens and secrets used in the ghost-stack infrastructure. Regular rotation is critical for maintaining security hygiene.

---

## Table of Contents

1. [Overview](#overview)
2. [Token Inventory](#token-inventory)
3. [GitHub Tokens](#github-tokens)
4. [Bitwarden Secrets Manager](#bitwarden-secrets-manager)
5. [Cloudflare Tokens](#cloudflare-tokens)
6. [R2 Storage Credentials](#r2-storage-credentials)
7. [Vultr API Key](#vultr-api-key)
8. [Tailscale API Key](#tailscale-api-key)
9. [PagerDuty Credentials](#pagerduty-credentials)
10. [Grafana Cloud Credentials](#grafana-cloud-credentials)
11. [Linear API Token](#linear-api-token)
12. [Verification Procedures](#verification-procedures)

---

## Overview

### Storage Locations

Secrets in this project are stored in two primary locations:

| Location | Purpose | Access Method |
|----------|---------|---------------|
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

| Token | Source | Bitwarden ID | GitHub Secret | Env Scope | Expiration |
|-------|--------|--------------|---------------|-----------|------------|
| GHCR RW Token | GitHub PAT | N/A | `GHCR_TOKEN` | Repository | Configurable |
| BWS Access Token | Bitwarden | N/A | `BWS_ACCESS_TOKEN` | Environment (dev) | Never* |
| Claude MCP Token | GitHub PAT | N/A | N/A (local) | N/A | Configurable |
| Cloudflare API Token | Cloudflare | `59624245-...` | N/A | N/A | Configurable |
| Cloudflare Token Creator | Cloudflare | N/A | N/A | N/A | 30 days recommended |
| Cloudflare Bootstrap Token | Cloudflare | N/A | N/A | N/A | 30 days recommended |
| R2 Access Key ID | Cloudflare R2 | `9dfdf110-...` | N/A | N/A | Never |
| R2 Secret Access Key | Cloudflare R2 | `f5d9794d-...` | N/A | N/A | Never |
| R2 Bootstrap Access Key | Cloudflare R2 | N/A | N/A | N/A | Never |
| R2 Bootstrap Secret Key | Cloudflare R2 | N/A | N/A | N/A | Never |
| Vultr API Key | Vultr | `d68b6562-...` | N/A | N/A | Never |
| Tailscale API Key | Tailscale | `34b620b7-...` | N/A | N/A | 90 days default |
| PagerDuty Client ID | PagerDuty | `7d51661b-...` | N/A | N/A | Never |
| PagerDuty Client Secret | PagerDuty | `b15575c0-...` | N/A | N/A | Never |
| PagerDuty User Token | PagerDuty | `02805292-...` | N/A | N/A | Never |
| Grafana Cloud Token | Grafana | `bfc8dd06-...` | N/A | N/A | 30 days |
| Grafana Cloud SA Token | Grafana | `3ebc4398-...` | N/A | N/A | 30 days |
| Linear API Token | Linear | N/A | N/A (local) | N/A | Never |
| Admin IP | N/A | N/A | `ADMIN_IP` | Environment (dev) | N/A |
| Cloudflare Zone ID | N/A | N/A | `CLOUDFLARE_ZONE_ID` | Environment (dev) | N/A |
| Health Check Token | N/A | N/A | `HEALTH_CHECK_TOKEN` | Environment (dev) | N/A |

*Bitwarden machine account tokens do not expire but should be rotated periodically.

---

## GitHub Tokens

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
   - Scopes: `write:packages`, `read:packages`
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

## Bitwarden Secrets Manager

### BWS Access Token (`BWS_ACCESS_TOKEN`)

**Purpose:** Authenticate to Bitwarden Secrets Manager to retrieve runtime secrets in CI/CD.

**Scope:** Environment-scoped (`dev` and `dev-ci` environments)

- `dev` environment: Used by deploy workflows
- `dev-ci` environment: Used by PR workflows (shadow environment for validation)

**Expiration:** Machine account tokens do not expire, but rotation is recommended every 6-12 months.

#### Rotation Steps

1. **Generate new token:**
   - Log into Bitwarden web vault
   - Go to Organizations → Machine accounts
   - Select the relevant machine account (e.g., `ghost-stack-dev`)
   - Go to Access tokens tab
   - Click "Create access token"
   - Name: Include date (e.g., `ci-2025-01`)
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

## Cloudflare Tokens

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
   - Set IP restrictions if desired
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
   - Set IP restrictions to your admin IP
   - Set TTL: 30 days
   - Create and copy token

2. **Update Bitwarden:**
   - Update the `dev-token-creator` secret in Bitwarden

3. **Revoke old token:**
   - In Cloudflare, revoke the previous token creator

---

### Cloudflare Bootstrap Token

**Purpose:** Provision R2 bucket and DNS zone during initial bootstrap.

**Storage:** Bitwarden Secrets Manager

**Expiration:** 30 days recommended

#### Rotation Steps

1. **Generate new token:**
   - Use the token creator script:
     ```bash
     ./opentofu/bootstrap/scripts/generate-bootstrap-token.sh
     ```
   - Or manually create in Cloudflare with permissions:
     - Zone: Edit, Read
     - DNS: Edit
     - R2 Storage Buckets: Edit

2. **Update Bitwarden:**
   - Update the `bootstrap-dev-token` secret in Bitwarden

---

## R2 Storage Credentials

### R2 Access Key ID & Secret Access Key

**Purpose:** Access R2 buckets for OpenTofu state storage and sysext image storage.

**Bitwarden Secret IDs:**
- Access Key ID: `9dfdf110-5a84-48c3-ad7e-b39b002afd6b`
- Secret Access Key: `f5d9794d-fd45-4dcb-9994-b39b002b5056`

**Expiration:** Never (but rotate periodically)

#### Rotation Steps

1. **Generate new credentials:**
   - Log into Cloudflare dashboard
   - Go to R2 → Overview → Manage R2 API Tokens
   - Click "Create API token"
   - Name: `ghost-stack-r2-YYYY-MM`
   - Permissions: Object Read & Write
   - Specify bucket(s): `ghost-stack-dev-state`, `ghost-dev-sysext-images`
   - TTL: None (or set expiration)
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

### R2 Bootstrap Credentials

**Purpose:** Bootstrap R2 bucket creation (used only during initial setup).

**Storage:** Bitwarden Secrets Manager

**Rotation:** Only needed if re-bootstrapping infrastructure

#### Rotation Steps

1. **Generate new credentials:**
   - Log into Cloudflare dashboard
   - Go to R2 → Overview → Manage R2 API Tokens
   - Create new token with R2 bucket creation permissions
   - Copy Access Key ID and Secret Access Key

2. **Update Bitwarden:**
   - Update the bootstrap R2 access key and secret key secrets in Bitwarden

---

## Vultr API Key

**Purpose:** Manage Vultr compute instances, firewalls, and block storage.

**Bitwarden Secret ID:** `d68b6562-0d9e-424c-b2c5-b39c013ae34d`

**Expiration:** Never

#### Rotation Steps

1. **Generate new key:**
   - Log into Vultr (dev account)
   - Go to Account → API
   - Click "Enable API" if not already enabled
   - Copy the API key (or regenerate if rotating)

   **Note:** Vultr only supports one API key per account. Regenerating creates a new key and invalidates the old one immediately.

2. **Update Bitwarden:**
   - Update secret `d68b6562-0d9e-424c-b2c5-b39c013ae34d` with new key

3. **Verify:**
   - Run `./opentofu/scripts/tofu.sh dev plan`
   - Confirm Vultr resources are accessible

---

## Tailscale API Key

**Purpose:** Register/deregister Tailscale devices via OpenTofu.

**Bitwarden Secret IDs:**
- API Key: `34b620b7-edf6-4d06-9792-b39b00317467`
- Tailnet: `a8f07ce5-ed4d-42bb-b012-b39b00311d41`

**Expiration:** 90 days by default

#### Rotation Steps

1. **Generate new key:**
   - Log into Tailscale admin console
   - Go to Settings → Keys
   - Click "Generate API key"
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

## PagerDuty Credentials

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

## Grafana Cloud Credentials

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

4. **Verify:**
   - Run `./opentofu/scripts/tofu.sh dev plan`
   - Confirm Grafana Cloud provider initializes

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
   - Find the service account named `sa-1-extsvc-grafana-terraform-app`
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

4. **Verify:**
   - Run `./opentofu/scripts/tofu.sh dev plan`
   - Confirm Grafana resources are accessible

---

## Linear API Token

**Purpose:** Claude Code integration with Linear for issue tracking.

**Storage:** Local Claude Code MCP configuration

**Expiration:** Never

#### Rotation Steps

1. **Generate new token:**
   - Log into Linear
   - Go to Settings → API → Personal API keys
   - Click "Create key"
   - Label: `claude-code-YYYY-MM`
   - Copy the token

2. **Update local configuration:**
   - Update your Claude Code MCP configuration with the new token

3. **Revoke old token:**
   - Delete the old API key in Linear

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

---

## Rotation Schedule Recommendations

| Token | Recommended Rotation | Priority |
|-------|---------------------|----------|
| GHCR Token | Every 90 days | High |
| Cloudflare API Tokens | Every 90 days | High |
| Tailscale API Key | Before 90-day expiry | High |
| BWS Access Tokens | Every 6-12 months | Medium |
| R2 Credentials | Every 6-12 months | Medium |
| Vultr API Key | Annually | Medium |
| PagerDuty Tokens | Annually | Low |
| Grafana Tokens | Annually | Low |
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
