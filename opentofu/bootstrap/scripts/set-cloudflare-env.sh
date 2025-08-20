# Prompt for Cloudflare API token
printf "🔐 Enter your bootstrap-dev-token Cloudflare API token: "
# Use -r to prevent backslash interpretation, -s for silent input
IFS= read -rs TF_VAR_cloudflare_api_token
printf "\n"

# Prompt for Account ID
printf "🆔 Enter your Cloudflare Account ID: "
IFS= read -r TF_VAR_cloudflare_account_id
printf "\n"

# Export for current shell session
export TF_VAR_cloudflare_api_token
export TF_VAR_cloudflare_account_id
export CLOUDFLARE_API_TOKEN="$TF_VAR_cloudflare_api_token"

echo "✅ Exported: TF_VAR_cloudflare_api_token, TF_VAR_cloudflare_account_id and CLOUDFLARE_API_TOKEN"
