#!/bin/bash
set -euo pipefail

# ============================================================================
# infra-shell.sh
#
# Default behavior (interactive/workstation):
#   - Optionally prompts for BWS_ACCESS_TOKEN (secure read)
#   - Retrieves secrets (BWS if available) and prompts for missing
#   - Discovers public IP, reads SSH pubkey, builds and runs the tooling container
#
# CI behavior (non-interactive):
#   - Use --ci to disable all prompts
#   - Use --secrets-only to retrieve/export secrets and exit (no docker build/run)
#   - Optionally export to GitHub Actions via $GITHUB_ENV
#
# Usage examples:
#   Workstation interactive (current behavior):
#     ./docker/scripts/infra-shell.sh
#
#   CI: retrieve secrets and export to GitHub Actions env:
#     ./docker/scripts/infra-shell.sh --ci --secrets-only --export-github-env
#
#   CI: retrieve secrets only, fail if anything missing (no prompts):
#     ./docker/scripts/infra-shell.sh --ci --secrets-only
# ============================================================================

# ----------------------------
# Flags / Modes
# ----------------------------
CI_MODE=false
SECRETS_ONLY=false
EXPORT_GITHUB_ENV=false
RUN_CONTAINER=true
BUILD_CONTAINER=true

usage() {
  cat <<'EOF'
Usage: infra-shell.sh [options]

Options:
  --ci                 Non-interactive mode. Never prompts. Requires env vars / BWS_ACCESS_TOKEN.
  --secrets-only        Retrieve and export secrets, then exit. Skips IP discovery, SSH key, docker build/run.
  --export-github-env   Write exported secrets to $GITHUB_ENV (GitHub Actions). Also works if $GITHUB_ENV is set.
  --no-build            Do not run docker build (workstation only).
  --no-run              Do not run docker run (workstation only).
  -h, --help            Show help.

EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --ci) CI_MODE=true; shift ;;
    --secrets-only) SECRETS_ONLY=true; RUN_CONTAINER=false; BUILD_CONTAINER=false; shift ;;
    --export-github-env) EXPORT_GITHUB_ENV=true; shift ;;
    --no-build) BUILD_CONTAINER=false; shift ;;
    --no-run) RUN_CONTAINER=false; shift ;;
    -h|--help) usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; usage; exit 2 ;;
  esac
done

# In GitHub Actions, $GITHUB_ENV is the canonical cross-step export mechanism.
# If it's present, enable export automatically unless explicitly disabled.
if [[ -n "${GITHUB_ENV:-}" ]]; then
  EXPORT_GITHUB_ENV=true
fi

# ============================================================================
# Bitwarden Secrets Manager Integration
# ============================================================================

BWS_PROJECT="${BWS_PROJECT:-ghost-stack-dev}"

check_bws_available() {
  command -v bws &> /dev/null
}

mask_value() {
  local value="$1"
  if [[ -n "${GITHUB_ACTIONS:-}" && -n "$value" ]]; then
    echo "::add-mask::$value"
  fi
}

# Retrieve a secret from Bitwarden Secrets Manager by secret id
# Usage: get_bws_secret <secret_id>
get_bws_secret() {
  local secret_id="$1"
  local value=""

  # bws output shape can vary by version. This implementation matches your current jq-based parsing.
  # We suppress stderr to avoid accidental log noise.
  value="$(bws secret get "$secret_id" 2>/dev/null | jq -r '.value // empty' 2>/dev/null || true)"

  printf "%s" "$value"
}

# Export a variable into current process and optionally into GitHub Actions environment file
# Usage: export_var <name> <value>
export_var() {
  local name="$1"
  local value="$2"

  # Export into current shell environment (useful for workstation / same-step usage)
  export "$name=$value"

  # For GitHub Actions: persist across steps without printing secrets
  if [[ "$EXPORT_GITHUB_ENV" == "true" ]]; then
    # Use the multiline-safe format to avoid edge cases with special characters/newlines
    {
      echo "${name}<<__GHO_EOF__"
      echo "${value}"
      echo "__GHO_EOF__"
    } >> "$GITHUB_ENV"
  fi
}

# Prompt helper (interactive only)
prompt_if_empty() {
  local var_name="$1"
  local prompt_text="$2"
  local is_secret="${3:-false}"

  if [[ -z "${!var_name:-}" ]]; then
    if [[ "$CI_MODE" == "true" ]]; then
      echo "❌ Missing required environment variable in CI mode: $var_name" >&2
      exit 1
    fi

    printf "%s" "$prompt_text"
    if [[ "$is_secret" == "true" ]]; then
      IFS= read -rs "$var_name"
    else
      IFS= read -r "$var_name"
    fi
    printf "\n"
  fi
}

# Decide whether to use BWS
USE_BWS=false
if check_bws_available; then
  # In CI mode, never prompt; require BWS_ACCESS_TOKEN if you expect to use BWS.
  if [[ -z "${BWS_ACCESS_TOKEN:-}" ]]; then
    if [[ "$CI_MODE" == "true" ]]; then
      # If token absent in CI, we simply won't use BWS; downstream required vars may still fail.
      USE_BWS=false
    else
      printf "Bitwarden Secrets Manager CLI detected.\n"
      printf "Enter your BWS machine account token (or press Enter to skip): "
      IFS= read -rs BWS_ACCESS_TOKEN
      printf "\n"
      export BWS_ACCESS_TOKEN
    fi
  else
    export BWS_ACCESS_TOKEN
  fi

  if [[ -n "${BWS_ACCESS_TOKEN:-}" ]]; then
    USE_BWS=true
    echo "Retrieving secrets from Bitwarden Secrets Manager project: $BWS_PROJECT"
  else
    echo "Skipping Bitwarden Secrets Manager (no token)."
  fi
else
  echo "Bitwarden Secrets Manager CLI (bws) not found."
fi

# ============================================================================
# Retrieve secrets
# ============================================================================

if [[ "$USE_BWS" == "true" ]]; then
  # Retrieve into local variables (do not echo values)
  #TF_VAR_cloudflare_api_token="$(get_bws_secret "59624245-6a0c-4fde-9d6d-b39c014882a6")"
  TF_VAR_cloudflare_account_id="$(get_bws_secret "2fea4609-0d6b-4d8d-b9b5-b39b002de85b")"
  mask_value "$TF_VAR_cloudflare_account_id"
  #R2_ACCESS_KEY_ID="$(get_bws_secret "9dfdf110-5a84-48c3-ad7e-b39b002afd6b")"
  #R2_SECRET_ACCESS_KEY="$(get_bws_secret "f5d9794d-fd45-4dcb-9994-b39b002b5056")"
  #TF_VAR_vultr_api_key="$(get_bws_secret "d68b6562-0d9e-424c-b2c5-b39c013ae34d")"
  #TAILSCALE_API_KEY="$(get_bws_secret "34b620b7-edf6-4d06-9792-b39b00317467")"
  #TAILSCALE_TAILNET="$(get_bws_secret "a8f07ce5-ed4d-42bb-b012-b39b00311d41")"
  #PD_SUBDOMAIN="$(get_bws_secret "8ee84397-e563-4278-9a3f-b39c013f7575")"
  #PD_CLIENT_ID="$(get_bws_secret "7d51661b-736a-43ff-b01f-b39c013fe49b")"
  #PD_CLIENT_SECRET="$(get_bws_secret "b15575c0-0d28-459d-b92d-b39c01403a38")"
  #PD_USER_TOK="$(get_bws_secret "02805292-4311-4290-9b6e-b39c01554ae6")"
  #TF_VAR_GC_ACCESS_TOK="$(get_bws_secret "bfc8dd06-bd97-499a-98f8-b3a101570606")"
  #TF_VAR_SOC_DEV_TERRAFORM_SA_TOK="$(get_bws_secret "3ebc4398-f4fa-448c-b2c1-b3a6006c063d")"

  echo "Successfully retrieved secrets from Bitwarden Secrets Manager"
fi

# Prompt for any required values not set by BWS (interactive only; CI will fail)
#prompt_if_empty "TF_VAR_vultr_api_key" "Enter your Vultr API key: " true
#prompt_if_empty "R2_ACCESS_KEY_ID" "Enter your R2 ACCESS KEY ID: " true
#prompt_if_empty "R2_SECRET_ACCESS_KEY" "Enter your R2 SECRET ACCESS KEY: " true
#prompt_if_empty "TF_VAR_cloudflare_api_token" "Enter your ghost-stack-dev Cloudflare API token: " true
prompt_if_empty "TF_VAR_cloudflare_account_id" "Enter your Cloudflare Account ID: " false
#prompt_if_empty "TAILSCALE_API_KEY" "Enter your Tailscale API Key: " true
#prompt_if_empty "TAILSCALE_TAILNET" "Enter your Tailscale TAILNET Name: " false
#prompt_if_empty "PD_CLIENT_ID" "Enter your PagerDuty client id: " false
#prompt_if_empty "PD_CLIENT_SECRET" "Enter your PagerDuty client secret: " true
#prompt_if_empty "PD_SUBDOMAIN" "Enter your PagerDuty subdomain: " false
#prompt_if_empty "PD_USER_TOK" "Enter your PagerDuty user API token: " true
#prompt_if_empty "TF_VAR_GC_ACCESS_TOK" "Enter your Grafana Cloud access token: " true
#prompt_if_empty "TF_VAR_SOC_DEV_TERRAFORM_SA_TOK" "Enter your Grafana Cloud SOC DEV Terraform access token: " true

# Export (and optionally write to $GITHUB_ENV) without printing values
#export_var "TF_VAR_vultr_api_key" "${TF_VAR_vultr_api_key}"
#export_var "R2_ACCESS_KEY_ID" "${R2_ACCESS_KEY_ID}"
#export_var "R2_SECRET_ACCESS_KEY" "${R2_SECRET_ACCESS_KEY}"
export_var "TF_VAR_cloudflare_account_id" "${TF_VAR_cloudflare_account_id}"
#export_var "TF_VAR_cloudflare_api_token" "${TF_VAR_cloudflare_api_token}"
#export_var "CLOUDFLARE_API_TOKEN" "${TF_VAR_cloudflare_api_token}"
#export_var "TAILSCALE_API_KEY" "${TAILSCALE_API_KEY}"
#export_var "TAILSCALE_TAILNET" "${TAILSCALE_TAILNET}"
#export_var "PD_CLIENT_ID" "${PD_CLIENT_ID}"
#export_var "PD_CLIENT_SECRET" "${PD_CLIENT_SECRET}"
#export_var "PD_SUBDOMAIN" "${PD_SUBDOMAIN}"
#export_var "PD_USER_TOK" "${PD_USER_TOK}"
#export_var "TF_VAR_GC_ACCESS_TOK" "${TF_VAR_GC_ACCESS_TOK}"
#export_var "TF_VAR_SOC_DEV_TERRAFORM_SA_TOK" "${TF_VAR_SOC_DEV_TERRAFORM_SA_TOK}"

# Ensure required secrets are available
#: "${TF_VAR_vultr_api_key:?Environment variable not set}"
#: "${R2_ACCESS_KEY_ID:?Environment variable not set}"
#: "${R2_SECRET_ACCESS_KEY:?Environment variable not set}"
: "${TF_VAR_cloudflare_account_id:?Environment variable not set}"
#: "${TF_VAR_cloudflare_api_token:?Environment variable not set}"
#: "${TAILSCALE_API_KEY:?Environment variable not set}"
#: "${TAILSCALE_TAILNET:?Environment variable not set}"
#: "${PD_CLIENT_ID:?Environment variable not set}"
#: "${PD_CLIENT_SECRET:?Environment variable not set}"
#: "${PD_SUBDOMAIN:?Environment variable not set}"
#: "${PD_USER_TOK:?Environment variable not set}"
#: "${TF_VAR_GC_ACCESS_TOK:?Environment variable not set}"
#: "${TF_VAR_SOC_DEV_TERRAFORM_SA_TOK:?Environment variable not set}"

# Exit early for CI secrets-only mode (no IP discovery, no SSH key, no docker actions)
if [[ "$SECRETS_ONLY" == "true" ]]; then
  echo "Secrets exported successfully."
  exit 0
fi

# ============================================================================
# Workstation-only setup (unchanged intent, but gated)
# ============================================================================

# Discover caller public IPv4 and pass it to OpenTofu as admin_subnets
MYIP="$(curl -fsS https://checkip.amazonaws.com | tr -d '\r\n')"
if [[ -z "$MYIP" ]]; then
  echo "❌ Could not determine public IPv4 (check network/DNS/proxy)."
  exit 1
fi

export TF_VAR_admin_subnets
TF_VAR_admin_subnets="$(printf '[{"subnet":"%s","subnet_size":32}]' "$MYIP")"
echo "Restricting SSH to your IP: ${MYIP}/32"

# SSH public key injection (for Vultr SSH key resource)
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
echo "Using SSH public key: $PUBKEY_PATH"

# Build container if enabled
if [[ "$BUILD_CONTAINER" == "true" ]]; then
  docker build -t ghost-stack-shell ./docker
fi

# Run container if enabled
if [[ "$RUN_CONTAINER" == "true" ]]; then
  HISTFILE=/dev/null HISTSIZE=0 HISTFILESIZE=0 docker run --rm -it \
    -e TF_VAR_cloudflare_account_id="$TF_VAR_cloudflare_account_id" \
    -e USER_UID="$(id -u)" \
    -e USER_GID="$(id -g)" \
    -e DISPLAY=$DISPLAY \
    -e XAUTHORITY=$XAUTHORITY \
    -v /tmp/.X11-unix:/tmp/.X11-unix \
    -v "$(pwd)":/home/devops/app \
    -v tofu_plugins:/home/devops/.tofu.d \
    ghost-stack-shell \
    bash --norc --noprofile -c 'unset HISTFILE; export HISTFILE=/dev/null; export HISTSIZE=0; export HISTFILESIZE=0; exec bash'
fi
