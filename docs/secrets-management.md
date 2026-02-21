# Secrets Management

This document describes how secrets are managed in Ghost Stack. Secrets are stored in three locations depending on their purpose.

---

## Architecture Overview

| Layer | Tool | Contents | Access Method |
|-------|------|----------|---------------|
| Infrastructure credentials | Bitwarden Secrets Manager | Provider API keys, tokens, account IDs | `bws` CLI via `infra-shell.sh` |
| CI/CD-only values | GitHub Secrets | Admin IP, Zone IDs, health check token | GitHub Actions environment variables |
| Application secrets | Infisical | DB passwords, SMTP password, analytics tokens | Single-use Token Auth at boot (GHO-75/76) |

---

## Infrastructure Secrets: Bitwarden Secrets Manager

All provider credentials used by OpenTofu and `infra-shell.sh` are stored in Bitwarden Secrets Manager under the `ghost-stack-dev` project. Secrets are retrieved at runtime by UUID using the `bws` CLI.

### How It Works

**Workstation:** `infra-shell.sh` prompts for `BWS_ACCESS_TOKEN` interactively, retrieves all secrets by UUID, and exports them as environment variables before launching the `ghost-stack-shell` container.

**CI/CD:** `BWS_ACCESS_TOKEN` is stored in the `dev` and `dev-ci` GitHub environments. The `--ci --secrets-only` flags disable prompts and skip the container launch.

```bash
# Workstation
source docker/scripts/infra-shell.sh

# CI (GitHub Actions)
./docker/scripts/infra-shell.sh --ci --secrets-only --export-github-env
```

### Secrets Stored in Bitwarden

| Variable | Purpose | Bitwarden UUID |
|----------|---------|----------------|
| `TF_VAR_cloudflare_api_token` | Cloudflare DNS/zone management | `59624245-6a0c-4fde-9d6d-b39c014882a6` |
| `TF_VAR_cloudflare_account_id` | Cloudflare account ID | `2fea4609-0d6b-4d8d-b9b5-b39b002de85b` |
| `R2_ACCESS_KEY_ID` | R2 state bucket + sysext image storage | `9dfdf110-5a84-48c3-ad7e-b39b002afd6b` |
| `R2_SECRET_ACCESS_KEY` | R2 state bucket + sysext image storage | `f5d9794d-fd45-4dcb-9994-b39b002b5056` |
| `TF_VAR_vultr_api_key` | Vultr compute management | `d68b6562-0d9e-424c-b2c5-b39c013ae34d` |
| `TAILSCALE_API_KEY` | Tailscale device registration | `34b620b7-edf6-4d06-9792-b39b00317467` |
| `TAILSCALE_TAILNET` | Tailscale network name | `a8f07ce5-ed4d-42bb-b012-b39b00311d41` |
| `TF_VAR_PD_CLIENT_ID` | PagerDuty OAuth client ID | `7d51661b-736a-43ff-b01f-b39c013fe49b` |
| `TF_VAR_PD_CLIENT_SECRET` | PagerDuty OAuth client secret | `b15575c0-0d28-459d-b92d-b39c01403a38` |
| `TF_VAR_pd_subdomain` | PagerDuty subdomain | `8ee84397-e563-4278-9a3f-b39c013f7575` |
| `TF_VAR_pd_user_tok` | PagerDuty user API token | `02805292-4311-4290-9b6e-b39c01554ae6` |
| `TF_VAR_GC_ACCESS_TOK` | Grafana Cloud access token | `bfc8dd06-bd97-499a-98f8-b3a101570606` |
| `TF_VAR_SOC_DEV_TERRAFORM_SA_TOK` | Grafana Cloud Terraform service account | `3ebc4398-f4fa-448c-b2c1-b3a6006c063d` |
| `TF_VAR_infisical_client_id` | Infisical management identity client ID (Universal Auth) | `5cbee56f-4cd9-4504-b9d7-b3f7015a2b7f` |
| `TF_VAR_infisical_client_secret` | Infisical management identity client secret (Universal Auth) | `3379153b-6a36-4eff-99e6-b3f7015acd6e` |
| `TF_VAR_infisical_org_id` | Infisical organization ID | `27c88ca1-ab19-4c28-aeab-b3f70156c18a` |

For rotation procedures see the [Token Rotation Runbook](./token-rotation-runbook.md).

---

## CI/CD Values: GitHub Secrets

Values that are only needed inside GitHub Actions workflows are stored directly as GitHub Secrets, not in Bitwarden. These are injected by the runner and do not pass through `infra-shell.sh`.

| Secret | Environments | Purpose |
|--------|-------------|---------|
| `BWS_ACCESS_TOKEN` | `dev`, `dev-ci` | Authenticate to Bitwarden Secrets Manager |
| `ADMIN_IP` | `dev`, `dev-ci` | Admin workstation IP for firewall rules |
| `CLOUDFLARE_ZONE_ID` | `dev`, `dev-ci` | Cloudflare zone ID for DNS |
| `HEALTH_CHECK_TOKEN` | `dev`, `dev-ci` | Caddy health check authentication |
| `GHCR_TOKEN` | Repository | Pull `ghost-stack-shell` image from GHCR |

**Important:** Secrets shared between `dev` and `dev-ci` must be updated in both environments (Settings → Environments → dev and dev-ci).

---

## Application Secrets: Infisical

Application secrets consumed by the Ghost containers at runtime are stored in Infisical under the **Ghost Stack** project (slug: `ghost-stack`), in the `dev` environment.

### Access Model

The `ghost-dev` machine identity uses Token Auth. A single-use token is generated per-provisioning-run by OpenTofu (GHO-75) and injected directly into the instance's Ignition config. The instance uses the token once at boot to fetch secrets, after which the token is consumed. No credentials persist on the instance after first use.

The `ghost-dev` identity has `no-access` as its base project role, with a specific privilege granting `read` on the `dev` environment only — it cannot access staging or production environments.

### Secrets in Infisical

| Secret | Purpose |
|--------|---------|
| `DATABASE_PASSWORD` | MySQL ghost user password |
| `DATABASE_ROOT_PASSWORD` | MySQL root password |
| `HEALTH_CHECK_TOKEN` | Caddy health check authentication |
| `mail__options__auth__pass` | SMTP password for transactional email |
| `TINYBIRD_ADMIN_TOKEN` | TinyBird workspace admin token |

For provisioning and rotation procedures see [Infisical Secrets Runbook](./runbooks/infisical-secrets.md).

> **Status:** Infisical boot-time delivery is being deployed via GHO-74 through GHO-76. Until GHO-76 is deployed, application secrets are sourced from `/var/mnt/storage/ghost-compose/.env.secrets` on the instance.

---

## Vultr API Key Limitations

Vultr does not support scoped or expiring API tokens. The account uses a single key with full account access. Mitigations:

- **Environment isolation:** Separate Vultr accounts for `dev`, staging, and production limit the blast radius of a compromised key
- **Stored in Bitwarden:** Never stored in plaintext or version-controlled files
- **One key per account:** Regenerating the key in the Vultr console immediately invalidates the old one

| Feature | Vultr Support |
|---------|--------------|
| Scoped API Tokens | ❌ No |
| Expiring Credentials | ❌ No |
| Role-based Access Control | ❌ No |
| Per-environment Isolation | ✅ Yes (via separate accounts) |

---

## Related Documentation

- [Token Rotation Runbook](./token-rotation-runbook.md) — Full inventory and rotation procedures for all tokens
- [Infisical Secrets Runbook](./runbooks/infisical-secrets.md) — Application secret provisioning and rotation

---

📁 _This document lives at `docs/secrets-management.md` in the repository._
=======
---

## Application Secrets (Infisical)

Ghost application secrets (database passwords, health check token, mail password, TinyBird token) are managed in **Infisical**, not Bitwarden or 1Password. Infisical is provisioned via OpenTofu and instances fetch secrets at boot using a scoped machine identity.

See [Infisical Secret Provisioning and Rotation](./runbooks/infisical-secrets.md) for the full provisioning and rotation procedures.

