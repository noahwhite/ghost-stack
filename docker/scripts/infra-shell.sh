#!/bin/bash
set -euo pipefail

# ============================================================================
# Bitwarden Secrets Manager Integration
# ============================================================================
# This script can automatically retrieve secrets from Bitwarden Secrets Manager.
#
# Prerequisites:
#   1. Install Bitwarden Secrets Manager CLI: https://bitwarden.com/help/secrets-manager-cli/
#   2. Create a machine account access token in the Bitwarden web vault
#   3. The script will prompt for the token securely (won't appear in shell history)
#
# Secret Mappings (from ghost-stack-dev project):
#   ghost_dev_cf_api_tok          → TF_VAR_cloudflare_api_token
#   cf_account_id                 → TF_VAR_cloudflare_account_id
#   ghost_dev_cf_r2_access_key    → R2_ACCESS_KEY_ID
#   ghost_dev_cf_r2_secret_access_key → R2_SECRET_ACCESS_KEY
#   ghost_dev_vultr_api_key       → TF_VAR_vultr_api_key
#   ghost_dev_ts_api_key          → TAILSCALE_API_KEY
#   ghost_dev_tailnet_name        → TAILSCALE_TAILNET
#   ghost_dev_pd_subdomain        → PD_SUBDOMAIN
#   ghost_dev_pd_api_key_id       → PD_CLIENT_ID
#   ghost_dev_pd_api_key          → PD_CLIENT_SECRET
#   ghost_dev_pd_user_api_tok     → PD_USER_TOK
#   grafana_cloud_access_token    → TF_VAR_SOC_DEV_TERRAFORM_SA_TOK
#
# Configuration:
#   - Set BWS_PROJECT to override the default project name (default: "ghost-stack-dev")
#
# Usage:
#   ./docker/scripts/infra-shell.sh
# ============================================================================

# Default Bitwarden Secrets Manager project name
BWS_PROJECT="${BWS_PROJECT:-ghost-stack-dev}"

# Check if Bitwarden Secrets Manager CLI is available
check_bws_available() {
  command -v bws &> /dev/null
}

# Retrieve a secret from Bitwarden Secrets Manager by key name
# Usage: get_bws_secret <secret_key>
get_bws_secret() {
  local secret_key="$1"
  local value

  # Use bws secret get to retrieve the secret value
  # BWS_ACCESS_TOKEN must be set in the environment for this to work
  value=$(bws secret get "$secret_key" 2>/dev/null | jq -r '.value // empty' 2>/dev/null || echo "")

  echo "$value"
}

# Prompt for a value if not already set
# Usage: prompt_if_empty <var_name> <prompt_text> <is_secret>
prompt_if_empty() {
  local var_name="$1"
  local prompt_text="$2"
  local is_secret="${3:-false}"

  # Use indirect reference to check if variable is already set
  if [[ -z "${!var_name:-}" ]]; then
    printf "%s" "$prompt_text"
    if [[ "$is_secret" == "true" ]]; then
      IFS= read -rs "$var_name"
    else
      IFS= read -r "$var_name"
    fi
    printf "\n"
  fi
}

# Try to use Bitwarden Secrets Manager if available
USE_BWS=false
if check_bws_available; then
  # Check if BWS_ACCESS_TOKEN is already set (for automation/CI)
  if [[ -z "${BWS_ACCESS_TOKEN:-}" ]]; then
    # Prompt for the token securely
    printf "🔓 Bitwarden Secrets Manager CLI detected.\n"
    printf "🔐 Enter your BWS machine account token (or press Enter to skip): "
    IFS= read -rs BWS_ACCESS_TOKEN
    printf "\n"
    # Export immediately after reading so bws command can use it
    export BWS_ACCESS_TOKEN
  else
    # Already set (e.g., from CI/automation), ensure it's exported
    export BWS_ACCESS_TOKEN
  fi

  # Only use BWS if we have a token
  if [[ -n "${BWS_ACCESS_TOKEN:-}" ]]; then
    USE_BWS=true
    echo "🔓 Retrieving secrets from Bitwarden Secrets Manager project: $BWS_PROJECT"
  else
    echo "ℹ️  Skipping Bitwarden Secrets Manager. Will prompt for credentials manually."
  fi
else
  echo "ℹ️  Bitwarden Secrets Manager CLI (bws) not found. Will prompt for credentials manually."
  echo "   To install: https://bitwarden.com/help/secrets-manager-cli/"
fi

# Retrieve secrets from BWS if available
if [[ "$USE_BWS" == "true" ]]; then
  TF_VAR_cloudflare_api_token="$(get_bws_secret "59624245-6a0c-4fde-9d6d-b39c014882a6")"
  TF_VAR_cloudflare_account_id="$(get_bws_secret "2fea4609-0d6b-4d8d-b9b5-b39b002de85b")"
  R2_ACCESS_KEY_ID="$(get_bws_secret "9dfdf110-5a84-48c3-ad7e-b39b002afd6b")"
  R2_SECRET_ACCESS_KEY="$(get_bws_secret "f5d9794d-fd45-4dcb-9994-b39b002b5056")"
  TF_VAR_vultr_api_key="$(get_bws_secret "d68b6562-0d9e-424c-b2c5-b39c013ae34d")"
  TAILSCALE_API_KEY="$(get_bws_secret "34b620b7-edf6-4d06-9792-b39b00317467")"
  TAILSCALE_TAILNET="$(get_bws_secret "a8f07ce5-ed4d-42bb-b012-b39b00311d41")"
  PD_SUBDOMAIN="$(get_bws_secret "8ee84397-e563-4278-9a3f-b39c013f7575")"
  PD_CLIENT_ID="$(get_bws_secret "7d51661b-736a-43ff-b01f-b39c013fe49b")"
  PD_CLIENT_SECRET="$(get_bws_secret "b15575c0-0d28-459d-b92d-b39c01403a38")"
  PD_USER_TOK="$(get_bws_secret "02805292-4311-4290-9b6e-b39c01554ae6")"
  TF_VAR_GC_ACCESS_TOK="$(get_bws_secret "bfc8dd06-bd97-499a-98f8-b3a101570606")"
  TF_VAR_SOC_DEV_TERRAFORM_SA_TOK="$(get_bws_secret "3ebc4398-f4fa-448c-b2c1-b3a6006c063d")"

  echo "✅ Successfully retrieved secrets from Bitwarden Secrets Manager"
fi

# Prompt for any secrets that weren't retrieved from Bitwarden Secrets Manager
prompt_if_empty "TF_VAR_vultr_api_key" "🔐 Enter your Vultr API key: " true
prompt_if_empty "R2_ACCESS_KEY_ID" "🔐 Enter your R2 ACCESS KEY ID: " true
prompt_if_empty "R2_SECRET_ACCESS_KEY" "🔐 Enter your R2 SECRET ACCESS KEY: " true
prompt_if_empty "TF_VAR_cloudflare_api_token" "🔐 Enter your ghost-stack-dev Cloudflare API token: " true
prompt_if_empty "TF_VAR_cloudflare_account_id" "🆔 Enter your Cloudflare Account ID: " false
prompt_if_empty "TAILSCALE_API_KEY" "🔐 Enter your Tailscale API Key: " true
prompt_if_empty "TAILSCALE_TAILNET" "🆔 Enter your Tailscale TAILNET Name: " false
prompt_if_empty "PD_CLIENT_ID" "🆔 Enter your PagerDuty client id: " false
prompt_if_empty "PD_CLIENT_SECRET" "🔐 Enter your PagerDuty client secret: " true
prompt_if_empty "PD_SUBDOMAIN" "🆔 Enter your PagerDuty subdomain: " false
prompt_if_empty "PD_USER_TOK" "🔐 Enter your PagerDuty user API token: " true
prompt_if_empty "TF_VAR_GC_ACCESS_TOK" "🔐 Enter your Grafana Cloud access token: " true
prompt_if_empty "TF_VAR_SOC_DEV_TERRAFORM_SA_TOK" "🔐 Enter your Grafana Cloud SOC DEV Terraform access token: " true

# Discover caller public IPv4 and pass it to OpenTofu as admin_subnets
MYIP="$(curl -fsS https://checkip.amazonaws.com | tr -d '\r\n')"
if [[ -z "$MYIP" ]]; then
  echo "❌ Could not determine public IPv4 (check network/DNS/proxy)."
  exit 1
fi

# Export JSON exactly once; keep it machine- and CI-friendly
export TF_VAR_admin_subnets
TF_VAR_admin_subnets="$(printf '[{"subnet":"%s","subnet_size":32}]' "$MYIP")"

echo "🔐 Restricting SSH to your IP: ${MYIP}/32"

# --- SSH public key injection (for Vultr SSH key resource) ---
# Default to ~/.ssh/ghost-dev.pub, allow override via GHOST_SSH_PUBKEY
PUBKEY_PATH="${GHOST_SSH_PUBKEY:-$HOME/.ssh/ghost-dev.pub}"
if [[ ! -f "$PUBKEY_PATH" ]]; then
  echo "❌ SSH public key not found at: $PUBKEY_PATH"
  echo "   Set GHOST_SSH_PUBKEY to the correct path or create one:"
  echo "   ssh-keygen -t ed25519 -C \"ghost-dev\" -f ~/.ssh/ghost-dev"
  exit 1
fi

if [[ ! -s "$PUBKEY_PATH" ]]; then
  echo "❌ SSH public key file missing or empty: $PUBKEY_PATH"
  exit 1
fi
TF_VAR_ssh_public_key="$(<"$PUBKEY_PATH")"
export TF_VAR_ssh_public_key
echo "🔑 Using SSH public key: $PUBKEY_PATH"

# Export for current shell session
export TF_VAR_vultr_api_key
export R2_ACCESS_KEY_ID
export R2_SECRET_ACCESS_KEY
export TF_VAR_cloudflare_account_id
export TF_VAR_cloudflare_api_token
export CLOUDFLARE_API_TOKEN="$TF_VAR_cloudflare_api_token"
export TAILSCALE_API_KEY
export TAILSCALE_TAILNET
export PD_CLIENT_ID
export PD_CLIENT_SECRET
export PD_SUBDOMAIN
export PD_USER_TOK
export TF_VAR_GC_ACCESS_TOK
export TF_VAR_SOC_DEV_TERRAFORM_SA_TOK

# Ensure required secrets are available in the host environment
: "${TF_VAR_vultr_api_key:?Environment variable not set}"
: "${R2_ACCESS_KEY_ID:?Environment variable not set}"
: "${R2_SECRET_ACCESS_KEY:?Environment variable not set}"
: "${TF_VAR_cloudflare_account_id:?Environment variable not set}"
: "${TF_VAR_cloudflare_api_token:?Environment variable not set}"
: "${TAILSCALE_API_KEY:?Environment variable not set}"
: "${TAILSCALE_TAILNET:?Environment variable not set}"
: "${PD_CLIENT_ID:?Environment variable not set}"
: "${PD_CLIENT_SECRET:?Environment variable not set}"
: "${PD_SUBDOMAIN:?Environment variable not set}"
: "${PD_USER_TOK:?Environment variable not set}"
: "${TF_VAR_GC_ACCESS_TOK:?Environment variable not set}"
: "${TF_VAR_SOC_DEV_TERRAFORM_SA_TOK:?Environment variable not set}"

# Build container if needed
docker build -t ghost_stack_shell ./docker

# Run container with secure env injection and history suppression
HISTFILE=/dev/null HISTSIZE=0 HISTFILESIZE=0 docker run --rm -it \
  -e TF_VAR_vultr_api_key="$TF_VAR_vultr_api_key" \
  -e TF_VAR_cloudflare_account_id="$TF_VAR_cloudflare_account_id" \
  -e TF_VAR_cloudflare_api_token="$TF_VAR_cloudflare_api_token" \
  -e TF_VAR_ssh_public_key="$TF_VAR_ssh_public_key" \
  -e TF_VAR_admin_subnets="$TF_VAR_admin_subnets" \
  -e R2_ACCESS_KEY_ID="$R2_ACCESS_KEY_ID" \
  -e R2_SECRET_ACCESS_KEY="$R2_SECRET_ACCESS_KEY" \
  -e TAILSCALE_API_KEY="$TAILSCALE_API_KEY" \
  -e TAILSCALE_TAILNET="$TAILSCALE_TAILNET" \
  -e TF_VAR_PD_CLIENT_ID="$PD_CLIENT_ID" \
  -e TF_VAR_PD_CLIENT_SECRET="$PD_CLIENT_SECRET" \
  -e TF_VAR_pd_subdomain="$PD_SUBDOMAIN" \
  -e TF_VAR_pd_user_tok="$PD_USER_TOK" \
  -e TF_VAR_GC_ACCESS_TOK="$TF_VAR_GC_ACCESS_TOK" \
  -e TF_VAR_SOC_DEV_TERRAFORM_SA_TOK="$TF_VAR_SOC_DEV_TERRAFORM_SA_TOK" \
  -e USER_UID="$(id -u)" \
  -e USER_GID="$(id -g)" \
  -v "$(pwd)":/home/devops/app \
  -v tofu_plugins:/home/devops/.tofu.d \
  ghost_stack_shell \
  bash --norc --noprofile -c 'unset HISTFILE; export HISTFILE=/dev/null; export HISTSIZE=0; export HISTFILESIZE=0; exec bash'
