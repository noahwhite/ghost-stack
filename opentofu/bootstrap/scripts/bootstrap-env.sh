#!/usr/bin/env bash
set -euo pipefail

ENV="${1:-}"
PLAN_ONLY="${2:-}"

if [[ -z "$ENV" ]]; then
  echo "Usage: $0 <dev|stage|prod> [--plan-only]"
  exit 1
fi

REPO_ROOT="$(git rev-parse --show-toplevel)"
BOOTSTRAP_ROOT="${REPO_ROOT}/opentofu/bootstrap"
ENV_DIR="${BOOTSTRAP_ROOT}/envs/${ENV}"
STATE_DIR="${ENV_DIR}/state"

mkdir -p "${STATE_DIR}"

: "${CLOUDFLARE_API_TOKEN:?CLOUDFLARE_API_TOKEN is required for ${ENV}}"

echo "→ init (local backend path = ${STATE_DIR}/terraform.tfstate)"
tofu -chdir="${BOOTSTRAP_ROOT}" init -reconfigure \
  -backend-config="path=${STATE_DIR}/terraform.tfstate"

TFVARS_OPTS=()
if [[ -f "${ENV_DIR}/${ENV}.tfvars" ]]; then
  TFVARS_OPTS=(-var-file="${ENV_DIR}/${ENV}.tfvars")
fi

echo "→ plan (${ENV})"
tofu -chdir="${BOOTSTRAP_ROOT}" plan "${TFVARS_OPTS[@]}"

if [[ "${PLAN_ONLY}" == "--plan-only" ]]; then
  echo "✔ Plan-only complete."
  exit 0
fi

echo "→ apply (${ENV})"
tofu -chdir="${BOOTSTRAP_ROOT}" apply "${TFVARS_OPTS[@]}"

echo
echo "Bootstrap outputs:"
tofu -chdir="${BOOTSTRAP_ROOT}" output \
  -state="${STATE_DIR}/terraform.tfstate"