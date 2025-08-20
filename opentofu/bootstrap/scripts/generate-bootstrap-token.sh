#!/usr/bin/env bash

set -euo pipefail
NEW_TOKEN=""

echo "🔐 Enter your dev-token-creator API token:"
read -s DEV_CREATOR_TOKEN
echo

echo "🆔 Enter your Cloudflare Account ID:"
read ACCOUNT_ID
echo

# Optional: Update IP allowlist and TTL as needed
IP_FILTER=$(curl -s ifconfig.me)/32
if date -d "+30 days" >/dev/null 2>&1; then
  EXPIRATION_DATE=$(date -u -d "+30 days" +"%Y-%m-%dT%H:%M:%SZ")  # GNU/Linux
else
  EXPIRATION_DATE=$(date -u -v+30d +"%Y-%m-%dT%H:%M:%SZ")          # macOS
fi

# "c8fed203ed3043cba015a93ad1616f1f"  Zone Read
# "e6d2666161e84845a636613608cee8d5"  Zone Write
# "4755a26eedb94da69e1066d98aa820be"  DNS Write
# "82e64a83756745bbbb1c9c2701bf816b"  DNS Read
# "b4992e1108244f5d8bfbd5744320c2e1"  Workers R2 Storage Read
# "bf7481a1826f439697cb59a20b22293e"  Workers R2 Storage Write

# Create a single token that can manage both R2 and DNS resources
echo "🚧 Creating bootstrap-dev-token with DNS and R2 permissions..."

RESPONSE=$(curl -s -X POST "https://api.cloudflare.com/client/v4/accounts/${ACCOUNT_ID}/tokens" \
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
        { "id": "b4992e1108244f5d8bfbd5744320c2e1" },
        { "id": "bf7481a1826f439697cb59a20b22293e" }
      ]
    },
    {
      "effect":"allow",
      "resources": {
        "com.cloudflare.api.account.${ACCOUNT_ID}": {
          "com.cloudflare.api.account.zone.*": "*"
        }
      },
      "permission_groups": [
        { "id": "e6d2666161e84845a636613608cee8d5" },
        { "id": "c8fed203ed3043cba015a93ad1616f1f" },
        { "id": "4755a26eedb94da69e1066d98aa820be" },
        { "id": "82e64a83756745bbbb1c9c2701bf816b" }
      ]
    }
  ],
  "condition": {
    "request.ip": { "in": ["${IP_FILTER}"] }
  },
  "expires_on": "${EXPIRATION_DATE}"
}
EOF
)

NEW_TOKEN=$(echo "$RESPONSE" | jq -r '.result.value // empty')

if [ -z "$NEW_TOKEN" ]; then
  echo "❌ Failed to create token. Check your dev-token-creator token and account ID."
  echo "🌐 Full Cloudflare API response:"
  echo "$RESPONSE"
  exit 1
fi

# Copy token to clipboard
echo -n "$NEW_TOKEN" | pbcopy

echo "✅ R2 bootstrap token created and copied to clipboard."
echo "📋 Paste it into 1Password and delete securely after use."
