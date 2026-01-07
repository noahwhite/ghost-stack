# Runbook: Setup GitHub Environment Variables for PR CI

## Overview

This runbook details how to configure GitHub environment variables required for the OpenTofu PR CI workflow that runs `init`, `validate`, and `plan` operations on pull requests targeting the `develop` branch.

## Prerequisites

- Administrator access to the GitHub repository
- Access to the bootstrap Terraform state file locally
- The bootstrap Terraform infrastructure must be already deployed

## Background

The PR CI workflow (`.github/workflows/pr-tofu-plan-develop.yml`) runs OpenTofu operations in a containerized environment. Since the bootstrap Terraform state file is stored locally (not in the container), the workflow needs the R2 bucket name to be provided via a GitHub environment variable.

The workflow uses the `infra-shell.sh` script to retrieve secrets from Bitwarden Secrets Manager, and the `tofu.sh` wrapper script to run OpenTofu commands. The `tofu.sh` script has been modified to check for the `TF_BACKEND_BUCKET` environment variable first before attempting to read from the local bootstrap state file.

## Required GitHub Environment Variable

### Variable Name
`BOOTSTRAP_R2_BUCKET_DEV`

### Variable Type
Repository/Environment Variable (not a secret)

### Description
The name of the Cloudflare R2 bucket used for storing OpenTofu state files for the `dev` environment.

## How to Retrieve the Bucket Name

On your local workstation where you have the bootstrap Terraform state:

```bash
# Navigate to the bootstrap directory
cd /path/to/repo/opentofu/bootstrap

# Initialize the bootstrap environment (this is required before reading outputs)
tofu init -reconfigure -backend-config="path=envs/dev/terraform.tfstate"

# Read the R2 bucket name output
tofu output -state=envs/dev/terraform.tfstate -raw r2_bucket_name
```

This will output the bucket name, which should look something like: `ghost-stack-dev-state` or `ghost-stack-terraform-state-dev-<random-suffix>`

**Important Notes**:
- If you encounter errors during `tofu init`, ensure you're in the `opentofu/bootstrap` directory and that the `envs/dev/terraform.tfstate` file exists.
- **Do NOT include the `%` character** if you see one at the end of the output. The `%` is a shell prompt indicator (common in Zsh) showing that the output didn't end with a newline - it is NOT part of the bucket name.
  - Example: If you see `ghost-stack-dev-state%`, the actual bucket name is `ghost-stack-dev-state`

## Steps to Configure GitHub Environment Variable

### Option 1: Repository-level Variable (Recommended for single environment)

1. Navigate to your GitHub repository
2. Click on **Settings** → **Secrets and variables** → **Actions**
3. Click on the **Variables** tab
4. Click **New repository variable**
5. Set the following values:
   - **Name**: `BOOTSTRAP_R2_BUCKET_DEV`
   - **Value**: The bucket name retrieved from the previous step
6. Click **Add variable**

### Option 2: Environment-level Variable (Recommended for multiple environments)

1. Navigate to your GitHub repository
2. Click on **Settings** → **Environments**
3. Click on the `dev` environment (or create it if it doesn't exist)
4. Under **Environment variables**, click **Add variable**
5. Set the following values:
   - **Name**: `BOOTSTRAP_R2_BUCKET_DEV`
   - **Value**: The bucket name retrieved from the previous step
6. Click **Add variable**

**Note**: The PR workflow in this repository uses `environment: dev`, so if you create an environment-level variable, make sure the environment is named `dev`.

## Verification

After adding the variable, you can verify it's configured correctly by:

1. Creating a test pull request targeting the `develop` branch
2. Checking the GitHub Actions workflow run
3. Looking for the log line: `Using bootstrap R2 bucket from GitHub environment variable: <bucket-name>`
4. Verifying that the `tofu init` step completes successfully

## Workflow Integration

The workflow integrates this variable as follows:

1. **GitHub Actions Workflow** (`pr-tofu-plan-develop.yml`):
   ```yaml
   - name: Retrieve secrets via infra-shell.sh (CI mode)
     env:
       BWS_ACCESS_TOKEN: ${{ secrets.BWS_ACCESS_TOKEN }}
       BOOTSTRAP_R2_BUCKET_DEV: ${{ vars.BOOTSTRAP_R2_BUCKET_DEV }}
     run: |
       ./docker/scripts/infra-shell.sh --ci --secrets-only --export-github-env
   ```

2. **infra-shell.sh** detects CI mode and sets `TF_BACKEND_BUCKET`:
   ```bash
   if [[ "$CI_MODE" == "true" && -n "${BOOTSTRAP_R2_BUCKET_DEV:-}" ]]; then
     TF_BACKEND_BUCKET="${BOOTSTRAP_R2_BUCKET_DEV}"
   fi
   ```

3. **tofu.sh** uses `TF_BACKEND_BUCKET` if set:
   ```bash
   if [[ -n "${TF_BACKEND_BUCKET:-}" ]]; then
     bucket="${TF_BACKEND_BUCKET}"
   else
     # Fall back to reading from local bootstrap state
   fi
   ```

## Troubleshooting

### Error: "Could not read 'r2_bucket_name' from bootstrap env"

**Cause**: The `BOOTSTRAP_R2_BUCKET_DEV` variable is not set or is empty.

**Solution**:
1. Verify the variable is created in GitHub with the correct name
2. Check that the variable has a non-empty value
3. If using environment-level variables, ensure the workflow specifies `environment: dev`

### Error: "Missing required environment variable in CI mode: TF_BACKEND_BUCKET"

**Cause**: The variable is not being passed to the `infra-shell.sh` script.

**Solution**:
1. Check the workflow file to ensure the `BOOTSTRAP_R2_BUCKET_DEV` is set in the `env:` section
2. Verify the variable is accessible to the repository/environment

### Workflow runs but fails during init

**Cause**: The bucket name might be incorrect or the R2 credentials might be invalid.

**Solution**:
1. Verify the bucket name matches the one in your bootstrap state
2. Check that the Bitwarden Secrets Manager credentials are valid
3. Verify R2 access credentials in Bitwarden Secrets Manager

## Maintenance

### When to Update

You need to update this variable when:
- The bootstrap infrastructure is recreated with a new R2 bucket
- Migrating to a different R2 bucket for state storage
- Setting up additional environments (staging, prod)

### Future Environments

When adding new environments (e.g., `staging`, `prod`), create corresponding variables:
- `BOOTSTRAP_R2_BUCKET_STAGING`
- `BOOTSTRAP_R2_BUCKET_PROD`

And update the workflow files to use the appropriate variable for each environment.

## Related Documentation

- GitHub Actions workflow: `.github/workflows/pr-tofu-plan-develop.yml`
- Secrets retrieval script: `docker/scripts/infra-shell.sh`
- OpenTofu wrapper script: `opentofu/scripts/tofu.sh`
- Bootstrap Terraform: `opentofu/bootstrap/`

## Support

For issues or questions about this setup, please refer to:
- GitHub repository issues
- Internal DevOps documentation
- Team Slack channel: #devops or #infrastructure
