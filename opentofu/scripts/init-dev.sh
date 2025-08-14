#!/bin/bash
# Initializes OpenTofu dev environment with remote R2 backend using env vars

set -euo pipefail

if [ -z "${R2_ACCOUNT_ID:-}" ] || [ -z "${R2_ACCESS_KEY_ID:-}" ] || [ -z "${R2_SECRET_ACCESS_KEY:-}" ]; then
  echo "ERROR: R2_ACCOUNT_ID, R2_ACCESS_KEY_ID, and R2_SECRET_ACCESS_KEY must be set in your environment."
  exit 1
fi

tofu init \
  -backend-config="bucket=ghost-stack-dev-tofu-state" \
  -backend-config="key=dev/terraform.tfstate" \
  -backend-config="region=auto" \
  -backend-config="endpoint=https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com" \
  -backend-config="access_key=${R2_ACCESS_KEY_ID}" \
  -backend-config="secret_key=${R2_SECRET_ACCESS_KEY}" \
  -backend-config="skip_credentials_validation=true" \
  -backend-config="skip_metadata_api_check=true" \
  -backend-config="force_path_style=true"
