#!/bin/bash
# ghost-backup.sh — Nightly backup of Ghost stack data to Cloudflare R2
#
# R2 credentials are read from secret files written by infisical-secrets-fetch.sh at boot.
# The rclone config is written to tmpfs (/run/) at backup runtime and shredded after use.
# Credentials are NOT passed as -e env vars to docker run (would appear in docker inspect).
set -euo pipefail

CONFIG_FILE="/etc/ghost-compose/.env.config"
SECRETS_DIR="/var/mnt/storage/ghost-compose/secrets"
STORAGE_DIR="/var/mnt/storage"
COMPOSE_FILE="/etc/ghost-compose/compose.yml"
RCLONE_CONFIG="/run/rclone-backup.conf"

log()     { logger -t ghost-backup "$*"; echo "[ghost-backup] $*"; }
log_err() { logger -t ghost-backup -p err "ERROR: $*"; echo "[ghost-backup] ERROR: $*" >&2; }

# Always restart ghost-compose and shred the rclone config on exit (success or failure)
trap '
  log "Restarting ghost-compose..."
  docker compose -f "${COMPOSE_FILE}" --project-directory /etc/ghost-compose up -d || true
  shred -u "${RCLONE_CONFIG}" 2>/dev/null || true
' EXIT

set -a; source "${CONFIG_FILE}"; set +a

if [ ! -f "${SECRETS_DIR}/ghost_dev_bckup_r2_access_key_id" ] || \
   [ ! -f "${SECRETS_DIR}/ghost_dev_bckup_r2_secret_access_key" ]; then
    log_err "R2 secret files not found — was infisical-secrets-fetch.sh run at boot?"
    exit 1
fi

R2_ACCESS_KEY_ID="$(cat "${SECRETS_DIR}/ghost_dev_bckup_r2_access_key_id")"
R2_SECRET_ACCESS_KEY="$(cat "${SECRETS_DIR}/ghost_dev_bckup_r2_secret_access_key")"

# Write rclone config to tmpfs (/run is tmpfs on Flatcar) — not a persistent file.
# Credentials are never passed as -e env vars to docker run (would appear in docker inspect).
cat > "${RCLONE_CONFIG}" <<EOF
[r2]
type = s3
provider = Cloudflare
access_key_id = ${R2_ACCESS_KEY_ID}
secret_access_key = ${R2_SECRET_ACCESS_KEY}
endpoint = https://${R2_ACCOUNT_ID}.r2.cloudflarestorage.com
EOF
chmod 0600 "${RCLONE_CONFIG}"
unset R2_ACCESS_KEY_ID R2_SECRET_ACCESS_KEY

log "Stopping ghost-compose..."
docker compose -f "${COMPOSE_FILE}" --project-directory /etc/ghost-compose down

log "Running rclone sync to r2:${R2_DEV_BACKUPS_BUCKET}..."
docker run --rm \
    --network host \
    -v "${RCLONE_CONFIG}:/config/rclone/rclone.conf:ro" \
    -v "${STORAGE_DIR}:/data:ro" \
    rclone/rclone:1.69.1 sync /data "r2:${R2_DEV_BACKUPS_BUCKET}" \
    --exclude "ghost-compose/secrets/**" \
    --exclude "ghost-compose/.env.secrets" \
    --exclude "ghost-compose/.env.generated" \
    --exclude "sbin/**" \
    --log-level INFO

log "Backup complete."
# EXIT trap runs: docker compose up -d + shred rclone config
