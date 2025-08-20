#!/bin/bash
set -euo pipefail

cd "$(dirname "$0")/.."
pwd
echo "📦 Initializing OpenTofu backend..."
tofu init

echo "🔍 Planning changes for dev environment..."
tofu plan -var-file=envs/dev/dev.tfvars

echo "🚀 Applying changes to provision bootstrap infrastructure..."
tofu apply -var-file=envs/dev/dev.tfvars
