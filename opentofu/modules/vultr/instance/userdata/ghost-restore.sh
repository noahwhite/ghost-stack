#!/bin/bash
# ghost-restore.sh — Restore Ghost stack data from Cloudflare R2 backup
#
# Restores /var/mnt/storage/ from the R2 backup bucket using rclone sync (R2 → local).
# R2 credentials are read from secret files written by infisical-secrets-fetch.sh at boot.
# The rclone config is written to tmpfs (/run/) and shredded on exit.
# Credentials are NOT passed as -e env vars to docker run (would appear in docker inspect).
#
# WARNING: This is a destructive operation — it overwrites /var/mnt/storage/ with
# the contents of the R2 bucket. Run only on a freshly provisioned instance or after
# confirming data loss has occurred.
#
# The following paths are excluded from the sync (same as backup) to protect
# live credentials and generated files on the running instance:
#   ghost-compose/secrets/**  ghost-compose/.env.secrets  ghost-compose/.env.generated  sbin/**
set -euo pipefail

CONFIG_FILE="/etc/ghost-compose/.env.config"
SECRETS_DIR="/var/mnt/storage/ghost-compose/secrets"
STORAGE_DIR="/var/mnt/storage"
COMPOSE_FILE="/etc/ghost-compose/compose.yml"
RCLONE_CONFIG="/run/rclone-restore.conf"

log()     { logger -t ghost-restore "$*"; echo "[ghost-restore] $*"; }
log_err() { logger -t ghost-restore -p err "ERROR: $*"; echo "[ghost-restore] ERROR: $*" >&2; }

# Shred the rclone config on exit (success or failure)
trap 'shred -u "${RCLONE_CONFIG}" 2>/dev/null || true' EXIT

# Confirmation prompt — restore is a destructive, manual operation
echo ""
echo "WARNING: This will overwrite /var/mnt/storage/ with the contents of the R2 backup."
echo "Ghost-compose will be stopped during the restore and restarted when complete."
echo ""
read -r -p "Type 'yes' to continue: " CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
    log "Restore aborted."
    exit 0
fi

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

log "Restoring from r2:${R2_DEV_BACKUPS_BUCKET} to ${STORAGE_DIR}..."
docker run --rm \
    --network host \
    -v "${RCLONE_CONFIG}:/config/rclone/rclone.conf:ro" \
    -v "${STORAGE_DIR}:/data" \
    rclone/rclone:1.69.1 sync "r2:${R2_DEV_BACKUPS_BUCKET}" /data \
    --exclude "ghost-compose/secrets/**" \
    --exclude "ghost-compose/.env.secrets" \
    --exclude "ghost-compose/.env.generated" \
    --exclude "sbin/**" \
    --create-empty-src-dirs \
    --log-level INFO

log "Restore complete. Starting ghost-compose..."
docker compose -f "${COMPOSE_FILE}" --project-directory /etc/ghost-compose up -d

log "Done."
docker ps --format "table {{.Names}}\t{{.Status}}"
# EXIT trap runs: shred rclone config
