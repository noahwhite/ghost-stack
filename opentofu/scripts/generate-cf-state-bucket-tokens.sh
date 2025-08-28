#!/usr/bin/env bash

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
BOOTSTRAP_DIR="${REPO_ROOT}/opentofu/bootstrap"

# 1) Ensure bootstrap local state exists
if [[ ! -f "${BOOTSTRAP_DIR}/terraform.tfstate" && ! -f "${BOOTSTRAP_DIR}/tofu.tfstate" ]]; then
  echo "❌ Bootstrap state not found. Run: tofu -chdir=opentofu/bootstrap apply"
  exit 1
fi

# 2) Read bucket name from bootstrap output (single source of truth)
BUCKET="$(tofu -chdir="${BOOTSTRAP_DIR}" output -raw r2_bucket_name)"
if [[ -z "${BUCKET}" ]]; then
  echo "❌ Could not read 'r2_bucket_name' from bootstrap state."
  exit 1
fi

echo "🔐 Enter your dev-token-creator API token:"
read -s DEV_CREATOR_TOKEN
echo

echo "🆔 Enter your Cloudflare Account ID:"
read ACCOUNT_ID
echo

# Optional: Update IP allowlist and TTL as needed
IP_FILTER=$(curl -s ifconfig.me)/32
if date -d "+1 days" >/dev/null 2>&1; then
  EXPIRATION_DATE=$(date -u -d "+1 days" +"%Y-%m-%dT%H:%M:%SZ")  # GNU/Linux
else
  EXPIRATION_DATE=$(date -u -v+1d +"%Y-%m-%dT%H:%M:%SZ")          # macOS
fi

# Create a single token that can manage both R2 and DNS resources
echo "🚧 Creating ghost-shell-state-tokens..."

RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/tokens" \
  -H "Authorization: Bearer ${DEV_CREATOR_TOKEN}" \
  -H "Content-Type: application/json" \
  --data @- <<EOF
{
  "name": "ghost-stack-dev-state-token-2",
  "policies": [
    {
      "effect": "allow",
      "resources": { "com.cloudflare.edge.r2.bucket.${ACCOUNT_ID}_default_${BUCKET}": "*" },
      "permission_groups": [ { "id": "2efd5506f9c8494dacb1fa10a3e7d5b6" } ]
    }
  ],
  "condition": { "request.ip": { "in": ["${IP_FILTER}"] } },
  "expires_on": "${EXPIRATION_DATE}"
}
EOF
)

echo "$RESPONSE"

echo "✅ R2 bootstrap token created and copied to clipboard."
echo "📋 Paste it into 1Password and delete securely after use."