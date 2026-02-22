#!/bin/bash
# infisical-secrets-fetch.sh — Boot-time secrets fetch from Infisical
#
# Uses the single-use Token Auth token provisioned by OpenTofu (GHO-75) to fetch
# application secrets from Infisical and write them to the block storage secrets
# file used by Docker Compose.
#
# On reboot the token will be spent/expired — the service logs this and exits 0.
# The existing .env.secrets file on block storage is used by Ghost as normal.
#
# The boot token is delivered via a terraform_data snapshot (GHO-85) which decouples
# token TTL expiry from user_data, preventing spurious instance rebuilds.

CONFIG_FILE="/etc/ghost-compose/.env.config"
TOKEN_FILE="/etc/infisical/access-token"
SECRETS_FILE="/var/mnt/storage/ghost-compose/.env.secrets"
INFISICAL_API_BASE="https://us.infisical.com"

log()     { echo "[infisical-secrets] $*"; }
log_err() { echo "[infisical-secrets] ERROR: $*" >&2; }

# Always shred the token on exit — token is single-use and already consumed after the API call
trap 'shred -u "${TOKEN_FILE}" 2>/dev/null || true' EXIT

# Load INFISICAL_PROJECT_ID and INFISICAL_ENVIRONMENT from .env.config
set -a
# shellcheck source=/dev/null
source "${CONFIG_FILE}"
set +a

if [ -z "${INFISICAL_PROJECT_ID:-}" ] || [ -z "${INFISICAL_ENVIRONMENT:-}" ]; then
    log_err "INFISICAL_PROJECT_ID or INFISICAL_ENVIRONMENT not set in ${CONFIG_FILE}"
    exit 0
fi

if [ ! -s "${TOKEN_FILE}" ]; then
    log_err "Boot token missing or empty at ${TOKEN_FILE} — skipping fetch"
    exit 0
fi

TOKEN="$(cat "${TOKEN_FILE}")"

log "Fetching secrets from Infisical (project=${INFISICAL_PROJECT_ID} env=${INFISICAL_ENVIRONMENT})..."

HTTP_RESPONSE=$(curl -s -f \
    -H "Authorization: Bearer ${TOKEN}" \
    "${INFISICAL_API_BASE}/api/v4/secrets?projectId=${INFISICAL_PROJECT_ID}&environment=${INFISICAL_ENVIRONMENT}&secretPath=/" \
    2>&1) || {
    log_err "Infisical API call failed — token may be spent or expired. Using existing ${SECRETS_FILE}."
    exit 0
}

# Write selected KEY=VALUE pairs atomically to avoid leaving a partial secrets file
TMPFILE=$(mktemp "${SECRETS_FILE}.XXXXXX")
jq -r '
  .secrets[]
  | select(.secretKey | IN(
      "DATABASE_PASSWORD",
      "DATABASE_ROOT_PASSWORD",
      "HEALTH_CHECK_TOKEN",
      "mail__options__auth__pass",
      "TINYBIRD_ADMIN_TOKEN"
    ))
  | "\(.secretKey)=\(.secretValue)"
' <<< "${HTTP_RESPONSE}" > "${TMPFILE}" || {
    log_err "Failed to parse Infisical response"
    rm -f "${TMPFILE}"
    exit 0
}
chmod 0600 "${TMPFILE}"
mv "${TMPFILE}" "${SECRETS_FILE}"

log "Secrets written to ${SECRETS_FILE}"
