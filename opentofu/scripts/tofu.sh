#!/usr/bin/env bash
set -euo pipefail

# Usage: ./opentofu/scripts/tofu.sh <env> <init|plan|apply|destroy|output> [extra args...]
# Example:
#   ./opentofu/scripts/tofu.sh dev init
#   ./opentofu/scripts/tofu.sh dev plan
#   ./opentofu/scripts/tofu.sh dev apply -auto-approve

ENV="${1:-}"; ACTION="${2:-}"; shift 2 || true
EXTRA_ARGS=("$@")
if [[ -z "${ENV}" || -z "${ACTION}" ]]; then
  echo "Usage: $0 <env> <init|plan|apply|destroy|output> [extra args...]"
  exit 1
fi

# Where things live
REPO_ROOT="$(git rev-parse --show-toplevel)"
echo "REPO_ROOT= ${REPO_ROOT}"
BOOTSTRAP_ROOT="${REPO_ROOT}/opentofu/bootstrap"
echo "BOOTSTRAP_ROOT= ${BOOTSTRAP_ROOT}"
# Use the actual bootstrap ENV directory, not a raw state path
BOOTSTRAP_ENV_DIR="${BOOTSTRAP_ROOT}/envs/${ENV}"
echo "BOOTSTRAP_ENV_DIR= ${BOOTSTRAP_ENV_DIR}"
BOOTSTRAP_TF_DATA_DIR="${BOOTSTRAP_ENV_DIR}/.terraform"
echo "BOOTSTRAP_TF_DATA_DIR ${BOOTSTRAP_TF_DATA_DIR}"
ENV_DIR="${REPO_ROOT}/opentofu/envs/${ENV}"
STATE_DIR="${ENV_DIR}"
OUT="${ENV_DIR}/backend.hcl"
# Prefix for the state object in the R2 bucket
KEY="opentofu/${ENV}"

# Keep non-bootstrap working files under env/state/.terraform
mkdir -p "${STATE_DIR}/.terraform"

# ---- helpers ---------------------------------------------------------------
# Read the bootstrap output using the bootstrap env's own working dir
# Important: do NOT reuse the non-bootstrap TF_DATA_DIR here.
get_r2_bucket() {
  mkdir -p "${BOOTSTRAP_TF_DATA_DIR}"
  # Initialize bootstrap env using its own TF_DATA_DIR (local backend)
  # Use a subshell to cd into the bootstrap config dir
  (
    cd "${BOOTSTRAP_ROOT}" || exit 1

    # Init with LOCAL backend pinned to the env's state file
    TF_DATA_DIR="${BOOTSTRAP_ENV_DIR}/.terraform" \
      tofu init -reconfigure \
        -backend-config="path=${BOOTSTRAP_TF_DATA_DIR}/terraform.tfstate" >&2
  ) || {
    echo "❌ Failed to init bootstrap (local backend pinned to ${BOOTSTRAP_STATE_PATH})" >&2
    return 1
  }

  # Read the output from that same dir
  local bucket
    bucket="$(TF_DATA_DIR="${BOOTSTRAP_ENV_DIR}/.terraform" \
        tofu -chdir="${BOOTSTRAP_ROOT}" output -state="${BOOTSTRAP_ENV_DIR}/terraform.tfstate" -raw r2_bucket_name)"

    if [[ -z "${bucket}" ]]; then
      echo "❌ Could not read bootstrap output 'r2_bucket_name' for env '${ENV}'" >&2
      return 1
    fi
    # Only the value goes to stdout so callers can capture it cleanly.
    printf '%s\n' "${bucket}"
}

# Generate backend.hcl from bootstrap output and (re)initialize this env.
ensure_backend() {
  local bucket
  bucket="$(get_r2_bucket)" || {
    echo "❌ Could not read 'r2_bucket_name' from bootstrap env: ${BOOTSTRAP_ENV_DIR}" >&2
    exit 1
  }
  echo "bucket=${bucket}"

  : "${TF_VAR_cloudflare_account_id:?TF_VAR_cloudflare_account_id must be set in the environment}"

  cat > "${OUT}" <<EOF
bucket   = "${bucket}"
key      = "${KEY}"
endpoint = "https://${TF_VAR_cloudflare_account_id}.r2.cloudflarestorage.com"
region   = "us-east-1"
use_path_style              = true
skip_credentials_validation = true
skip_metadata_api_check     = true
skip_region_validation      = true
skip_requesting_account_id  = true
EOF

  echo "➡️  Generated ${OUT} (bucket=${bucket}, key=${KEY})"

  # Ensure the AWS SDK doesn't try EC2 metadata for creds
  export AWS_EC2_METADATA_DISABLED=true

  # Always reconfigure to align backend metadata for this working dir
  tofu -chdir="${ENV_DIR}" init -reconfigure -backend-config="${OUT}"
}

  if [[ ! -d "${ENV_DIR}" ]]; then
    echo "❌ Env directory not found: ${ENV_DIR}"
    exit 1
  fi

# --- Ensure Cloudflare provider sees the account id if provided via TF_VAR ---
if [ -n "${TF_VAR_cloudflare_account_id:-}" ]; then
  export CLOUDFLARE_ACCOUNT_ID="${TF_VAR_cloudflare_account_id}"
fi
if [ -n "${TF_VAR_cloudflare_api_token:-}" ]; then
  export CLOUDFLARE_API_TOKEN="${TF_VAR_cloudflare_api_token}"
fi

# --- Export R2 creds for ALL tofu invocations (backend needs them on plan/apply/etc) ---
: "${R2_ACCESS_KEY_ID:?R2_ACCESS_KEY_ID required}"
: "${R2_SECRET_ACCESS_KEY:?R2_SECRET_ACCESS_KEY required}"
export AWS_ACCESS_KEY_ID="${R2_ACCESS_KEY_ID}"
export AWS_SECRET_ACCESS_KEY="${R2_SECRET_ACCESS_KEY}"
# if you use temporary creds, also export AWS_SESSION_TOKEN before calling this script
export AWS_EC2_METADATA_DISABLED=true

case "${ACTION}" in
  init)
    ensure_backend
    tofu -chdir="${ENV_DIR}" init -reconfigure -backend-config="${OUT}" "${EXTRA_ARGS[@]}"
    ;;

  plan|apply|destroy|output)
    # Always ensure backend is generated and initialized (cheap & robust)
    ensure_backend
    # For provider auth (e.g., Vultr), expect env to be exported outside this script.
    tofu -chdir="${ENV_DIR}" "${ACTION}" "${EXTRA_ARGS[@]}"
    ;;

  *)
    echo "Usage: $0 <env> <init|plan|apply|destroy|output> [extra args...]"
    exit 1
    ;;
esac