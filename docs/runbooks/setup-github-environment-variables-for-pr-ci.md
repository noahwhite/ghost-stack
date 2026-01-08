# Runbook: Setup GitHub Configuration for PR CI

## Overview

This runbook details how to configure GitHub variables, secrets, and repository files required for the OpenTofu PR CI workflow that runs `init`, `validate`, and `plan` operations on pull requests targeting the `develop` branch.

## Prerequisites

- Administrator access to the GitHub repository
- Access to the bootstrap Terraform state file locally
- The bootstrap Terraform infrastructure must be already deployed
- SSH public key for infrastructure access

## Background

The PR CI workflow (`.github/workflows/pr-tofu-plan-develop.yml`) runs OpenTofu operations in a containerized environment. The workflow requires several configurations:

1. **R2 Bucket Name**: Since the bootstrap Terraform state file is stored locally (not in the container), the workflow needs the R2 bucket name from a GitHub environment variable

2. **Admin IP Address**: The workflow needs your workstation's IP address to configure SSH firewall rules that restrict infrastructure access

3. **SSH Public Key**: Infrastructure resources need an SSH public key for access, which is stored in the repository

The workflow uses:
- `infra-shell.sh` script to retrieve secrets from Bitwarden Secrets Manager and set infrastructure variables
- `tofu.sh` wrapper script to run OpenTofu commands
- Repository-stored SSH public key for consistent access configuration

## Required Configurations

### 1. BOOTSTRAP_R2_BUCKET_DEV

**Type**: Repository/Environment Variable (not a secret)

**Description**: The name of the Cloudflare R2 bucket used for storing OpenTofu state files for the `dev` environment.

### 2. ADMIN_IP_DEV

**Type**: Secret

**Description**: Your workstation's public IP address used for SSH firewall rules. This restricts SSH access to infrastructure created/managed by CI to only your workstation.

**Important**: This IP address must be manually updated in GitHub if your workstation's public IP changes (e.g., if you switch networks or your ISP rotates your IP).

### 3. SSH Public Key

**Type**: Repository file (`keys/ghost-dev.pub`)

**Description**: SSH public key for infrastructure access. This is safely stored in version control as public keys are designed to be public.

## How to Retrieve Required Values

### Retrieve the R2 Bucket Name

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

### Retrieve Your Workstation IP Address

On your admin workstation:

```bash
curl -fsS https://checkip.amazonaws.com
```

This will output your current public IP address, for example: `203.0.113.42`

**Important**: Your public IP may change if:
- You switch networks (e.g., from office to home)
- Your ISP rotates your IP address
- You reconnect to your VPN

If your IP changes, you must manually update the `ADMIN_IP_DEV` secret in GitHub for CI-managed infrastructure to remain accessible from your workstation.

## Steps to Configure GitHub Variables and Secrets

### Configure BOOTSTRAP_R2_BUCKET_DEV (Variable)

#### Option 1: Repository-level Variable (Recommended for single environment)

1. Navigate to your GitHub repository
2. Click on **Settings** → **Secrets and variables** → **Actions**
3. Click on the **Variables** tab
4. Click **New repository variable**
5. Set the following values:
   - **Name**: `BOOTSTRAP_R2_BUCKET_DEV`
   - **Value**: The bucket name retrieved from the bootstrap state
6. Click **Add variable**

#### Option 2: Environment-level Variable (Recommended for multiple environments)

1. Navigate to your GitHub repository
2. Click on **Settings** → **Environments**
3. Click on the `dev` environment (or create it if it doesn't exist)
4. Under **Environment variables**, click **Add variable**
5. Set the following values:
   - **Name**: `BOOTSTRAP_R2_BUCKET_DEV`
   - **Value**: The bucket name retrieved from the bootstrap state
6. Click **Add variable**

**Note**: The PR workflow in this repository uses `environment: dev`, so if you create an environment-level variable, make sure the environment is named `dev`.

### Configure ADMIN_IP_DEV (Secret)

#### Option 1: Repository-level Secret (Recommended for single environment)

1. Navigate to your GitHub repository
2. Click on **Settings** → **Secrets and variables** → **Actions**
3. Click on the **Secrets** tab
4. Click **New repository secret**
5. Set the following values:
   - **Name**: `ADMIN_IP_DEV`
   - **Secret**: Your workstation's public IP address (e.g., `203.0.113.42`)
6. Click **Add secret**

#### Option 2: Environment-level Secret (Recommended for multiple environments)

1. Navigate to your GitHub repository
2. Click on **Settings** → **Environments**
3. Click on the `dev` environment (or create it if it doesn't exist)
4. Under **Environment secrets**, click **Add secret**
5. Set the following values:
   - **Name**: `ADMIN_IP_DEV`
   - **Secret**: Your workstation's public IP address (e.g., `203.0.113.42`)
6. Click **Add secret**

### Configure SSH Public Key (Repository File)

The SSH public key is stored in the repository itself, not as a GitHub secret:

1. Copy your SSH public key to the repository:
   ```bash
   cp ~/.ssh/ghost-dev.pub keys/ghost-dev.pub
   ```

2. Commit and push the key:
   ```bash
   git add keys/ghost-dev.pub
   git commit -m "Add SSH public key for infrastructure access"
   git push
   ```

**Note**: This is safe because SSH **public** keys are designed to be public. Only the private key must be kept secret.

## Verification

After configuring all variables and secrets, you can verify they're set correctly by:

1. Copy your SSH public key to the repository (if not already done)
2. Creating a test pull request targeting the `develop` branch
3. Checking the GitHub Actions workflow run for these log lines:
   - `Using bootstrap R2 bucket from GitHub environment variable: <bucket-name>`
   - `Using admin IP from GitHub secret: <your-ip>/32`
   - `Using SSH public key: /home/devops/app/keys/ghost-dev.pub`
4. Verifying that the `tofu init`, `tofu validate`, and `tofu plan` steps complete successfully

## Workflow Integration

The workflow integrates these configurations as follows:

1. **GitHub Actions Workflow** (`pr-tofu-plan-develop.yml`):
   ```yaml
   - name: Retrieve secrets via infra-shell.sh (CI mode)
     env:
       BWS_ACCESS_TOKEN: ${{ secrets.BWS_ACCESS_TOKEN }}
       BOOTSTRAP_R2_BUCKET_DEV: ${{ vars.BOOTSTRAP_R2_BUCKET_DEV }}
       ADMIN_IP_DEV: ${{ secrets.ADMIN_IP_DEV }}
     run: |
       ./docker/scripts/infra-shell.sh --ci --secrets-only --export-github-env
   ```

2. **infra-shell.sh** sets infrastructure variables based on mode:
   ```bash
   # Set TF_BACKEND_BUCKET from GitHub variable
   if [[ "$CI_MODE" == "true" && -n "${BOOTSTRAP_R2_BUCKET_DEV:-}" ]]; then
     TF_BACKEND_BUCKET="${BOOTSTRAP_R2_BUCKET_DEV}"
   fi

   # Set admin subnets from GitHub secret (CI) or detect IP (workstation)
   if [[ "$CI_MODE" == "true" ]]; then
     MYIP="${ADMIN_IP_DEV}"
   else
     MYIP="$(curl -fsS https://checkip.amazonaws.com | tr -d '\r\n')"
   fi
   TF_VAR_admin_subnets="$(printf '[{"subnet":"%s","subnet_size":32}]' "$MYIP")"

   # Read SSH public key from repository (same for both modes)
   PUBKEY_PATH="${REPO_ROOT}/keys/ghost-dev.pub"
   TF_VAR_ssh_public_key="$(<"$PUBKEY_PATH")"
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

### Error: "Missing required environment variable in CI mode: ADMIN_IP_DEV"

**Cause**: The `ADMIN_IP_DEV` secret is not set.

**Solution**:
1. Verify the secret is created in GitHub with the correct name
2. Check that it's configured as a **Secret** (not a Variable)
3. Ensure the secret contains only your IP address (no extra characters or spaces)
4. If using environment-level secrets, ensure the workflow specifies `environment: dev`

### Error: "SSH public key not found at: .../keys/ghost-dev.pub"

**Cause**: The SSH public key file is not checked into the repository.

**Solution**:
1. Copy your SSH public key to the repository:
   ```bash
   cp ~/.ssh/ghost-dev.pub keys/ghost-dev.pub
   ```
2. Commit and push the key:
   ```bash
   git add keys/ghost-dev.pub
   git commit -m "Add SSH public key for infrastructure access"
   git push
   ```

### Workflow runs but fails during init

**Cause**: The bucket name might be incorrect or the R2 credentials might be invalid.

**Solution**:
1. Verify the bucket name matches the one in your bootstrap state
2. Check that the Bitwarden Secrets Manager credentials are valid
3. Verify R2 access credentials in Bitwarden Secrets Manager

### SSH access to infrastructure not working

**Cause**: Your workstation IP has changed since setting `ADMIN_IP_DEV`.

**Solution**:
1. Check your current IP: `curl -fsS https://checkip.amazonaws.com`
2. Update the `ADMIN_IP_DEV` secret in GitHub with your new IP
3. Re-run infrastructure apply (or wait for next scheduled run) to update firewall rules

## Maintenance

### When to Update

**BOOTSTRAP_R2_BUCKET_DEV** - Update when:
- The bootstrap infrastructure is recreated with a new R2 bucket
- Migrating to a different R2 bucket for state storage
- Setting up additional environments (staging, prod)

**ADMIN_IP_DEV** - Update when:
- Your workstation's public IP address changes
- You switch to a different admin workstation
- Your ISP rotates your IP address
- You need to grant access from a different location

**SSH Public Key** (keys/ghost-dev.pub) - Update when:
- Rotating SSH keys for security
- Changing the admin workstation
- Key compromise (immediately rotate)

### Future Environments

When adding new environments (e.g., `staging`, `prod`), create corresponding variables and secrets:

**Variables**:
- `BOOTSTRAP_R2_BUCKET_STAGING`
- `BOOTSTRAP_R2_BUCKET_PROD`

**Secrets**:
- `ADMIN_IP_STAGING`
- `ADMIN_IP_PROD`

**SSH Keys** (if different per environment):
- `keys/ghost-staging.pub`
- `keys/ghost-prod.pub`

And update the workflow files and `infra-shell.sh` to use the appropriate variable/secret for each environment.

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
