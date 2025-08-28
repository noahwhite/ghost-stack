#!/bin/bash
set -euo pipefail

# Prompt for Cloudflare API token
printf "🔐 Enter your Vultr API key: "
# Use -r to prevent backslash interpretation, -s for silent input
IFS= read -rs TF_VAR_vultr_api_key
printf "\n"

# Prompt for Cloudflare R2 access key id
printf "🔐 Enter your R2 ACCESS KEY ID: "
# Use -r to prevent backslash interpretation, -s for silent input
IFS= read -rs R2_ACCESS_KEY_ID
printf "\n"

# Prompt for Cloudflare R2 secret access key
printf "🔐 Enter your R2 SECRET ACCESS KEY: "
# Use -r to prevent backslash interpretation, -s for silent input
IFS= read -rs R2_SECRET_ACCESS_KEY
printf "\n"

# Prompt for Cloudflare API token
printf "🔐 Enter your ghost-stack-dev Cloudflare API token: "
# Use -r to prevent backslash interpretation, -s for silent input
IFS= read -rs TF_VAR_cloudflare_api_token
printf "\n"

# Prompt for Account ID
printf "🆔 Enter your Cloudflare Account ID: "
IFS= read -r TF_VAR_cloudflare_account_id
printf "\n"

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

# Ensure required secrets are available in the host environment
: "${TF_VAR_vultr_api_key:?Environment variable not set}"
: "${R2_ACCESS_KEY_ID:?Environment variable not set}"
: "${R2_SECRET_ACCESS_KEY:?Environment variable not set}"
: "${TF_VAR_cloudflare_account_id:?Environment variable not set}"
: "${TF_VAR_cloudflare_api_token:?Environment variable not set}"

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
  -e USER_UID="$(id -u)" \
  -e USER_GID="$(id -g)" \
  -v "$(pwd)":/home/devops/app \
  -v tofu_plugins:/home/devops/.tofu.d \
  ghost_stack_shell \
  bash --norc --noprofile -c 'unset HISTFILE; export HISTFILE=/dev/null; export HISTSIZE=0; export HISTFILESIZE=0; exec bash'
