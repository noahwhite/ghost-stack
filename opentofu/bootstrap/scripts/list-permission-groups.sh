#!/usr/bin/env bash

set -euo pipefail
NEW_TOKEN=""

echo "🔐 Enter your dev-token-creator API token:"
read -s DEV_CREATOR_TOKEN
echo

# Fetch permission groups
echo "🚧 Fetching available permission groups..."

RESPONSE=$(curl -s "https://api.cloudflare.com/client/v4/user/tokens/permission_groups" \
             --header "Authorization: Bearer $DEV_CREATOR_TOKEN")

if ! echo "$RESPONSE" | jq -e '.success' | grep true > /dev/null; then
  echo "❌ Failed to fetch permission groups. API response:"
  echo "$RESPONSE"
  exit 1
fi

# Print a list of group names and IDs
echo "✅ Available permission groups:"
echo "$RESPONSE" | jq -r '.result[] | "\(.name): \(.id)"'