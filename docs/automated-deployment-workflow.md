# Automated Deployment Workflow

This document describes the automated deployment workflow for the Ghost Stack infrastructure. When changes are merged to the `develop` branch, they are automatically deployed to the dev environment after manual approval.

---

## Overview

The deployment workflow consists of two main stages:

1. **PR Validation** - Generates and publishes an OpenTofu plan for review
2. **Deployment** - Applies approved changes to the dev environment

```
Feature Branch → PR Created → Plan Generated → PR Approved & Merged → Deployment Triggered → Manual Approval → Changes Applied
```

---

## Stage 1: PR Validation (pr-tofu-plan-develop.yml)

### Trigger
- Pull requests targeting the `develop` branch
- Events: opened, synchronize, reopened

### Workflow Steps

1. **Install Bitwarden CLI** - Installs `bws` for secret retrieval
2. **Checkout Repository** - Gets the PR branch code
3. **Log in to GHCR** - Authenticates to GitHub Container Registry
4. **Pull Tools Image** - Downloads `ghost-stack-shell:latest` Docker image
5. **Retrieve Secrets** - Fetches credentials from Bitwarden Secrets Manager
6. **Fix Permissions** - Makes workspace writable for Docker container
7. **Run OpenTofu Init** - Initializes backend with R2 state storage
8. **Run OpenTofu Validate** - Validates configuration syntax
9. **Run OpenTofu Plan** - Generates execution plan (`tfplan`)
10. **Generate Plan Output** - Converts binary plan to human-readable text
11. **Upload Plan Artifact** - Publishes plan for review and deployment use

### Artifacts Generated
- **Name**: `tofu-plan-dev-<PR#>`
- **Contents**: `plan-output.txt` (human-readable plan)
- **Retention**: 30 days
- **Usage**: Downloaded by deployment workflow for validation

### Secrets Required (Repository-Level)
- `BWS_ACCESS_TOKEN` - Bitwarden Secrets Manager token
- `GHCR_TOKEN` - GitHub Container Registry authentication
- `ADMIN_IP_DEV` - Admin workstation IP for SSH firewall rules
- `CLOUDFLARE_ZONE_ID_DEV` - Cloudflare Zone ID
- `BOOTSTRAP_R2_BUCKET_DEV` - R2 bucket name for backend state

---

## Stage 2: Deployment (deploy-dev.yml)

### Trigger
- Push to `develop` branch (typically from PR merge)

### Environment Protection
- **Environment**: `dev`
- **Protection Rules**:
  - Requires manual approval from designated reviewers
  - Restricted to `develop` branch only
  - Reviewers can view the plan before approving

### Workflow Steps

#### 1. Setup & Verification
- Checkout repository
- Log in to GHCR
- Pull deployment tools image
- Verify deployment context
- Verify OpenTofu tooling availability

#### 2. Plan Retrieval & Validation
- **Extract PR number** from merge commit message
- **Download plan artifact** from the PR workflow
- **Verify artifact** contains `plan-output.txt`

#### 3. Secret Retrieval
- **Install Bitwarden CLI** (`bws`)
- **Retrieve secrets** via `infra-shell.sh --ci --secrets-only`
- **Export to environment** for subsequent steps

#### 4. Current State Analysis
- **Fix workspace permissions** for Docker container
- **Run tofu init** to initialize backend
- **Generate fresh plan** for current infrastructure state
- **Convert to text** for comparison

#### 5. Drift Detection
- **Compare plans** using `diff` command
- **PR plan** (from artifact) vs **Current plan** (just generated)
- **If identical**: Proceed to apply
- **If different**: Fail with drift warning

#### 6. Apply Changes (If No Drift)
- **Run tofu apply** with the generated plan
- **Apply is conditional** - only runs if `PLANS_MATCH=true`
- **Changes are applied** to dev infrastructure

#### 7. Deployment Summary
- **Report status** - success or failure
- **Show PR number** that was deployed
- **Display drift message** if plans didn't match

### Secrets Required (Environment-Scoped: dev)
- `BWS_ACCESS_TOKEN` - Bitwarden Secrets Manager token
- `ADMIN_IP` - Admin workstation IP for SSH firewall rules
- `CLOUDFLARE_ZONE_ID` - Cloudflare Zone ID
- `BOOTSTRAP_R2_BUCKET` - R2 bucket name for backend state

### Key Environment Variables (From Bitwarden)
All provider credentials and configuration are retrieved from Bitwarden:
- `TF_VAR_cloudflare_account_id` / `TF_VAR_cloudflare_api_token`
- `R2_ACCESS_KEY_ID` / `R2_SECRET_ACCESS_KEY`
- `TF_VAR_vultr_api_key`
- `TAILSCALE_API_KEY` / `TAILSCALE_TAILNET`
- `TF_VAR_PD_CLIENT_ID` / `TF_VAR_PD_CLIENT_SECRET` / etc.
- `TF_VAR_GC_ACCESS_TOK`
- `TF_VAR_SOC_DEV_TERRAFORM_SA_TOK`

---

## Safety Features

### Plan Validation
The deployment workflow compares the PR plan with a fresh plan to detect state drift:

- **Why**: Infrastructure state may have changed between PR approval and deployment
- **How**: `diff -u ./pr-plan/plan-output.txt ./opentofu/envs/dev/current-plan.txt`
- **Result**: Deployment fails if plans differ, requiring manual review

### Manual Approval Gate
The `dev` environment requires manual approval before deployment:

- **Who**: Designated reviewers (configured in GitHub environment settings)
- **When**: After merge to develop, before apply runs
- **What**: Reviewers see the plan from the PR and approve deployment

### Atomic Operations
- Each tofu apply operates on a single plan file
- No partial applies - either all changes succeed or none do
- Failed deployments don't affect infrastructure state

### Clear Failure Messages
The workflow provides specific error messages for common failures:
- No PR number found in commit
- Plan artifact missing or incomplete
- State drift detected
- Secrets retrieval failed
- Apply operation failed

---

## Infrastructure Impact

### What Gets Deployed
When a deployment runs, OpenTofu applies changes to:
- **Vultr instances** (ghost-dev-01)
- **Block storage** volumes
- **Firewall rules**
- **DNS records** (Cloudflare)
- **Tailscale ACLs**
- **PagerDuty integrations**
- **Grafana Cloud configurations**

### Butane Configuration Updates
When butane (`.bu`) files are modified:
1. OpenTofu detects the change in userdata
2. Instance is recreated with new ignition config
3. Flatcar boots with updated configuration
4. Systemd services start automatically:
   - `ghost-compose.service` - Docker Compose stack
   - `tailscaled.service` - Tailscale VPN
   - `alloy.service` - Grafana Alloy monitoring
5. Docker Compose services restart with new configuration

### Service Restart Behavior
Docker Compose services are managed by systemd:
- **Location**: `/var/mnt/storage/ghost-compose/`
- **Service File**: `ghost-compose.service`
- **Restart**: Automatic on instance boot or service failure
- **Services**: caddy, ghost, db, optional analytics/activitypub

---

## Deployment Scenarios

### Scenario 1: Successful Deployment (No Changes)
```
PR #42 merged → Deploy triggered → Manual approval →
Plans match (no infrastructure changes) → Apply runs (no-op) → Success
```

### Scenario 2: Successful Deployment (With Changes)
```
PR #43 merged → Deploy triggered → Manual approval →
Plans match → Apply runs → Instance updated → Services restart → Success
```

### Scenario 3: Drift Detected
```
PR #44 merged → Deploy triggered → Manual approval →
Fresh plan generated → Plans DON'T match → Deployment fails → Manual investigation required
```

**Common causes of drift:**
- Manual changes made outside of tofu (e.g., via Vultr console)
- Provider API changes between PR and deployment
- Race condition with another deployment

**Resolution:**
- Review the diff output in workflow logs
- Determine if drift is expected or problematic
- If acceptable: Create new PR with updated plan
- If unexpected: Revert manual changes and retry deployment

### Scenario 4: Direct Push to Develop (No PR)
```
Direct commit to develop → Deploy triggered → Extract PR number fails →
Error: "No PR number found in commit message" → Deployment blocked
```

**Resolution**: Always merge via PR, not direct push

---

## Troubleshooting

### Deployment Workflow Not Triggered
**Symptom**: Merged PR but no deployment workflow appears in Actions

**Causes**:
- Workflow file has syntax errors
- Branch protection rules blocking push
- Workflow permissions insufficient

**Check**:
```bash
# Verify workflow file syntax
gh workflow view deploy-dev.yml

# Check recent workflow runs
gh run list --workflow=deploy-dev.yml
```

### Plan Artifact Not Found
**Symptom**: "if_no_artifact_found: fail" error in deployment workflow

**Causes**:
- PR workflow didn't complete successfully
- Artifact expired (30-day retention)
- PR number extraction failed

**Resolution**:
1. Check PR workflow run status
2. Re-run PR workflow if needed
3. Verify artifact exists: Actions → PR run → Artifacts section

### State Drift Detected
**Symptom**: "Plans differ - state has drifted since PR approval"

**Investigate**:
1. Review diff in workflow logs
2. Check for manual changes to infrastructure
3. Compare timestamps: PR plan vs current state
4. Look for provider API changes

**Resolution**:
- If drift is expected: Create new PR incorporating drift
- If drift is unexpected: Revert manual changes, create new PR
- If provider changed: Update provider version, create new PR

### Secrets Retrieval Failed
**Symptom**: "❌ ADMIN_IP not set in CI mode" or Bitwarden error

**Causes**:
- BWS_ACCESS_TOKEN expired or invalid
- Bitwarden project misconfigured
- Environment secrets not set

**Resolution**:
1. Verify environment secrets exist: Settings → Environments → dev
2. Check BWS token validity
3. Verify Bitwarden project has required secrets
4. Review `infra-shell.sh` output in logs

### Apply Failed
**Symptom**: tofu apply returns non-zero exit code

**Common Causes**:
- Provider rate limiting (Vultr, Cloudflare)
- Resource dependencies not met
- Invalid configuration
- Insufficient permissions

**Resolution**:
1. Review apply logs for specific error
2. Check provider API status
3. Verify resource dependencies
4. Validate credentials/permissions
5. Consider manual terraform state cleanup if needed

---

## Monitoring & Observability

### Workflow Logs
- **Location**: GitHub Actions → deploy-dev.yml runs
- **Contents**: Full output of each step
- **Retention**: 90 days (default)

### Plan Artifacts
- **Location**: Actions → PR workflow run → Artifacts
- **Contents**: Human-readable tofu plan
- **Retention**: 30 days
- **Usage**: Review before approval, debug drift issues

### Deployment Status
- **GitHub Environments**: Settings → Environments → dev
  - Shows recent deployments
  - Links to workflow runs
  - Displays approval history

### Infrastructure State
- **OpenTofu State**: Stored in R2 bucket
- **Location**: `s3://<bucket>/opentofu/dev/default.tfstate`
- **Access**: Via `tofu.sh` script or direct R2 access
- **Backup**: Versioned in R2

---

## Manual Deployment (Emergency)

If automated deployment fails and manual intervention is required:

### Prerequisites
- Access to workstation with `infra-shell.sh` configured
- Proper credentials in Bitwarden
- Understanding of changes to be applied

### Steps

1. **Clone repository and checkout develop**:
   ```bash
   git clone https://github.com/noahwhite/ghost-stack
   cd ghost-stack
   git checkout develop
   ```

2. **Start infra shell**:
   ```bash
   ./docker/scripts/infra-shell.sh
   ```

3. **Run plan to review changes**:
   ```bash
   ./opentofu/scripts/tofu.sh dev plan
   ```

4. **Apply changes (after review)**:
   ```bash
   ./opentofu/scripts/tofu.sh dev apply
   ```

5. **Verify deployment**:
   - Check Vultr console for instance status
   - Verify DNS propagation
   - Test Ghost site accessibility
   - Review Grafana dashboards for metrics

---

## Future Enhancements

### Planned Improvements
- **Staging environment** - Add pre-production testing
- **Production deployment** - Extend workflow to prod
- **Rollback automation** - Quick revert on failure
- **Terraform state locking** - Prevent concurrent applies
- **Deployment notifications** - Slack/email alerts
- **Change log generation** - Automatic release notes
- **Blue-green deployments** - Zero-downtime updates

### Known Limitations
- Single environment (dev only)
- No automatic rollback
- Manual approval required for every deployment
- State drift requires manual investigation
- Direct push to develop bypasses workflow

---

## Related Documentation

- [Git Workflow MVP](./git-workflow-mvp.md)
- [Branch Protection Rules](./branch-protection-rules.md)
- [Secrets Management](./secrets-management.md)
- [Setup GitHub Environment Variables](./runbooks/setup-github-environment-variables-for-pr-ci.md)

---

## Support & Questions

For issues or questions about the deployment workflow:
1. Review workflow logs in GitHub Actions
2. Check this documentation for troubleshooting steps
3. Review related documentation listed above
4. Create an issue in the repository with:
   - Workflow run link
   - Error messages
   - Steps to reproduce
