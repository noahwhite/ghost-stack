#!/usr/bin/env bash
set -euo pipefail

# --- args ---
ENV="${1:-}"
FLAG="${2:-}"  # optional --plan-only

case "${ENV}" in
  dev|stage|prod) ;;
  *)
    echo "Usage: $0 <dev|stage|prod> [--plan-only]"
    exit 1
    ;;
esac

REPO_ROOT="$(git rev-parse --show-toplevel)"
BOOTSTRAP_ROOT="${REPO_ROOT}/opentofu/bootstrap"
ENV_DIR="${BOOTSTRAP_ROOT}/envs/${ENV}"
STATE_DIR="${ENV_DIR}"
STATE_PATH="${STATE_DIR}/terraform.tfstate"

# Ensure state dirs exist and keep .terraform under state/
mkdir -p "${STATE_DIR}/.terraform"
export TF_DATA_DIR="${STATE_DIR}/.terraform"

: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required for ${ENV}}"

echo "→ init (local backend path = ${STATE_PATH})"
tofu -chdir="${BOOTSTRAP_ROOT}" init -reconfigure \
  -backend-config="path=${STATE_PATH}"

# Optional: pick up an env-specific tfvars file if present
TFVARS_OPTS=()
if [[ -f "${ENV_DIR}/${ENV}.tfvars" ]]; then
  TFVARS_OPTS=(-var-file="${ENV_DIR}/${ENV}.tfvars")
fi

echo "→ plan (${ENV})"
tofu -chdir="${BOOTSTRAP_ROOT}" plan "${TFVARS_OPTS[@]}"

if [[ "${FLAG}" == "--plan-only" ]]; then
  echo "✔ Plan-only complete."
  exit 0
fi

echo "→ apply (${ENV})"
tofu -chdir="${BOOTSTRAP_ROOT}" apply "${TFVARS_OPTS[@]}"

echo
echo "Bootstrap outputs:"
tofu -chdir="${BOOTSTRAP_ROOT}" output -state="${STATE_PATH}"