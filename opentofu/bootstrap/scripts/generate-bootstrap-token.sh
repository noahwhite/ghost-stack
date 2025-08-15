#!/usr/bin/env bash

set -euo pipefail

echo "🔐 Enter your dev-token-creator API token:"
read -s DEV_CREATOR_TOKEN
echo

echo "🆔 Enter your Cloudflare Account ID:"
read ACCOUNT_ID
echo

# Optional: Update IP allowlist and TTL as needed
IP_FILTER=$(curl -s ifconfig.me)/32
EXPIRATION_DATE=$(date -u -d "+30 days" +"%Y-%m-%dT%H:%M:%SZ")

# Create a single token that can manage both R2 and DNS resources
echo "🚧 Creating bootstrap-dev-token with DNS and R2 permissions..."

RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/user/tokens" \
  -H "Authorization: Bearer ${DEV_CREATOR_TOKEN}" \
  -H "Content-Type: application/json" \
  --data @- <<EOF
{
  "name": "bootstrap-dev-token",
  "policies": [
    {
      "effect": "allow",
      "resources": {
        "com.cloudflare.api.account.${ACCOUNT_ID}": "*"
      },
      "permission_groups": [
        { "id": "9a7e5d14c4b64c95a5b6f4b2aa4a3db5" },  // Zone:Edit
        { "id": "e8c9a1c5bd8d4a1caeb15e8b11cbb8c4" },  // Zone:Read
        { "id": "4c9f12c1d3b144c0b3aafddcc9f6c3c1" }   // R2 Storage:Edit
      ],
      "condition": {
        "request.ip": { "in": ["${IP_FILTER}"] }
      }
    }
  ],
  "expires_on": "${EXPIRATION_DATE}"
}
EOF
)

TOKEN_VALUE=$(echo "$RESPONSE" | jq -r '.result.value // empty')

if [ "$NEW_TOKEN" == "null" ]; then
  echo "❌ Failed to create token. Response:"
  echo "$RESPONSE"
  exit 1
fi

# Copy token to clipboard
echo -n "$NEW_TOKEN" | pbcopy

echo "✅ R2 bootstrap token created and copied to clipboard."
echo "📋 Paste it into 1Password and delete securely after use."
