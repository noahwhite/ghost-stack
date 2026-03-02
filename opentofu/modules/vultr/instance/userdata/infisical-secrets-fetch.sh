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

# Write individual Docker secret files (GHO-69)
# Each secret gets its own file at /var/mnt/storage/ghost-compose/secrets/<name>
# mounted into containers via Docker Compose secrets: directive.
# Files use printf '%s' (no trailing newline) so $(cat ...) in containers reads clean values.
SECRETS_DIR="${SECRETS_FILE%/*}/secrets"
mkdir -p "${SECRETS_DIR}"

write_secret() {
    local key="$1" filename="$2" value tmpfile
    value=$(jq -r --arg k "$key" '.secrets[] | select(.secretKey == $k) | .secretValue' <<< "${HTTP_RESPONSE}")
    if [ -n "$value" ] && [ "$value" != "null" ]; then
        tmpfile=$(mktemp "${SECRETS_DIR}/${filename}.XXXXXX")
        printf '%s' "$value" > "${tmpfile}"
        chmod 0600 "${tmpfile}"
        mv "${tmpfile}" "${SECRETS_DIR}/${filename}"
        log "Secret file written: ${SECRETS_DIR}/${filename}"
    else
        log_err "Secret '${key}' not found in Infisical response"
    fi
}

write_secret "DATABASE_PASSWORD"         "db_password"
write_secret "DATABASE_ROOT_PASSWORD"    "db_root_password"
write_secret "HEALTH_CHECK_TOKEN"        "health_check_token"
write_secret "mail__options__auth__pass" "mail_smtp_password"
write_secret "TINYBIRD_ADMIN_TOKEN"      "tinybird_admin_token"
write_secret "GHOST_DEV_BCKUP_R2_ACCESS_KEY_ID"     "ghost_dev_bckup_r2_access_key_id"
write_secret "GHOST_DEV_BCKUP_R2_SECRET_ACCESS_KEY" "ghost_dev_bckup_r2_secret_access_key"

# Write .env.secrets with TINYBIRD_ADMIN_TOKEN only.
# tinybird-provision.sh sources this file directly; no Docker service uses it via env_file any more.
TMPFILE=$(mktemp "${SECRETS_FILE}.XXXXXX")
jq -r '
  .secrets[]
  | select(.secretKey == "TINYBIRD_ADMIN_TOKEN")
  | "\(.secretKey)=\(.secretValue)"
' <<< "${HTTP_RESPONSE}" > "${TMPFILE}" || {
    log_err "Failed to write .env.secrets"
    rm -f "${TMPFILE}"
    exit 0
}
chmod 0600 "${TMPFILE}"
mv "${TMPFILE}" "${SECRETS_FILE}"

log "Secrets written to ${SECRETS_DIR}/ and ${SECRETS_FILE}"

# Write Tailscale monitor .env (second jq pass over same API response)
TAILSCALE_DIR="/var/mnt/storage/sbin/tailscale_monitor"
mkdir -p "${TAILSCALE_DIR}"
TAILSCALE_TMPFILE=$(mktemp "${TAILSCALE_DIR}/.env.XXXXXX")
{
    jq -r '
      .secrets[]
      | select(.secretKey | IN(
          "TAILSCALE_CLIENT_ID",
          "TAILSCALE_CLIENT_SECRET"
        ))
      | "\(.secretKey)=\(.secretValue)"
    ' <<< "${HTTP_RESPONSE}"
    echo "TAILSCALE_TAILNET=${TAILSCALE_TAILNET}"
} > "${TAILSCALE_TMPFILE}" || {
    log_err "Failed to write tailscale monitor .env"
    rm -f "${TAILSCALE_TMPFILE}"
}
if [ -f "${TAILSCALE_TMPFILE}" ]; then
    chmod 0600 "${TAILSCALE_TMPFILE}"
    mv "${TAILSCALE_TMPFILE}" "${TAILSCALE_DIR}/.env"
    log "Tailscale monitor .env written to ${TAILSCALE_DIR}/.env"
fi
