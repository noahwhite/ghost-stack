#!/bin/bash
# ghost-restore.sh — Restore Ghost stack data from a tiered Cloudflare R2 backup
#
# Usage:
#   ghost-restore.sh [OPTIONS] [all|images|mysql|-h|--help]
#   ghost-restore.sh list [--tier daily|weekly|monthly|quarterly]
#
# OPTIONS:
#   --tier TIER   Backup tier to restore from: daily, weekly, monthly, quarterly
#                 Default: daily
#   --date DATE   Specific snapshot within the tier (e.g. 2026-03-15, 2026-W11,
#                 2026-03, 2026-Q1). Default: most recent snapshot in the tier.
#
# COMPONENTS:
#   all    (default) Full restore — syncs entire /var/mnt/storage/ from R2.
#   images Images only — syncs ghost/upload-data/images/ from R2.
#   mysql  MySQL only — syncs mysql/data/ from R2.
#   -h, --help    Show usage and exit.
#
# SUBCOMMANDS:
#   list   List available snapshots in a tier (does not restore anything).
#          Uses --tier to filter; defaults to daily.
#
# All restore modes use rclone sync (R2 → local) so the target path is made to
# match R2 exactly — files present locally but absent in R2 are deleted.
#
# R2 credentials are read from secret files written by infisical-secrets-fetch.sh at boot.
# The rclone config is written to tmpfs (/run/) and shredded on exit.
# Credentials are NOT passed as -e env vars to docker run (would appear in docker inspect).
set -euo pipefail

usage() {
    cat <<EOF
Usage: $0 [OPTIONS] [all|images|mysql|-h|--help]
       $0 list [--tier daily|weekly|monthly|quarterly]

Options:
  --tier TIER   Backup tier: daily (default), weekly, monthly, quarterly
  --date DATE   Snapshot name within the tier. Default: most recent.
                  daily:     YYYY-MM-DD  (e.g. 2026-03-15)
                  weekly:    YYYY-WXX    (e.g. 2026-W11)
                  monthly:   YYYY-MM     (e.g. 2026-03)
                  quarterly: YYYY-QX     (e.g. 2026-Q1)

Components (default: all):
  all    Full restore — syncs entire /var/mnt/storage/ from R2.
  images Images only — syncs ghost/upload-data/images/ from R2.
  mysql  MySQL only — syncs mysql/data/ from R2.

All modes stop ghost-compose before restoring and restart it after.
All modes use rclone sync so the target path is made to match R2 exactly.

Examples:
  $0                                   # Restore all from latest daily backup
  $0 list                              # List available daily snapshots
  $0 list --tier weekly                # List available weekly snapshots
  $0 --tier weekly --date 2026-W11     # Restore all from weekly snapshot
  $0 --tier daily --date 2026-03-14 mysql  # Restore MySQL from a specific day
EOF
}

CONFIG_FILE="/etc/ghost-compose/.env.config"
GENERATED_FILE="/var/mnt/storage/ghost-compose/.env.generated"
SECRETS_DIR="/var/mnt/storage/ghost-compose/secrets"
STORAGE_DIR="/var/mnt/storage"
COMPOSE_FILE="/etc/ghost-compose/compose.yml"
RCLONE_CONFIG="/run/rclone-restore.conf"
RCLONE_IMAGE="rclone/rclone:1.69.1"

log()     { logger -t ghost-restore "$*"; echo "[ghost-restore] $*"; }
log_err() { logger -t ghost-restore -p err "ERROR: $*"; echo "[ghost-restore] ERROR: $*" >&2; }

trap 'shred -u "${RCLONE_CONFIG}" 2>/dev/null || true' EXIT

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
TIER="daily"
DATE=""
COMPONENT="all"
SUBCOMMAND=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --tier)
            shift
            TIER="${1:-}"
            case "${TIER}" in
                daily|weekly|monthly|quarterly) ;;
                *) log_err "Unknown tier '${TIER}'. Must be: daily, weekly, monthly, quarterly"; exit 1 ;;
            esac
            ;;
        --date)
            shift
            DATE="${1:-}"
            ;;
        list)
            SUBCOMMAND="list"
            ;;
        all|images|mysql)
            COMPONENT="$1"
            ;;
        -h|--help)
            usage; exit 0
            ;;
        *)
            log_err "Unknown argument '$1'"; usage; exit 1
            ;;
    esac
    shift
done

# ---------------------------------------------------------------------------
# Load env config and credentials
# ---------------------------------------------------------------------------
set -a; source "${CONFIG_FILE}"; [ -f "${GENERATED_FILE}" ] && source "${GENERATED_FILE}"; set +a

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

BUCKET="${R2_DEV_BACKUPS_BUCKET}"

# Run rclone for R2-only operations (listing, no local volume needed)
rclone_r2() {
    docker run --rm \
        --network host \
        -v "${RCLONE_CONFIG}:/config/rclone/rclone.conf:ro" \
        "${RCLONE_IMAGE}" \
        "$@"
}

# List snapshots in a tier (sorted ascending, trailing slashes stripped)
list_snapshots() {
    local tier="$1"
    rclone_r2 lsf "r2:${BUCKET}/${tier}/" --dirs-only 2>/dev/null \
        | sed 's|/$||' | sort || true
}

# ---------------------------------------------------------------------------
# Subcommand: list
# ---------------------------------------------------------------------------
if [ "${SUBCOMMAND}" = "list" ]; then
    echo "Available snapshots in tier '${TIER}':"
    snapshots=$(list_snapshots "${TIER}")
    if [ -z "${snapshots}" ]; then
        echo "  (none)"
    else
        printf '%s\n' "${snapshots}" | while IFS= read -r s; do
            echo "  ${s}"
        done
    fi
    exit 0
fi

# ---------------------------------------------------------------------------
# Resolve snapshot date (default: latest in tier)
# ---------------------------------------------------------------------------
if [ -z "${DATE}" ]; then
    DATE=$(list_snapshots "${TIER}" | tail -1)
    if [ -z "${DATE}" ]; then
        log_err "No snapshots found in tier '${TIER}'. Run '$0 list --tier ${TIER}' to check."
        exit 1
    fi
    log "Using latest ${TIER} snapshot: ${DATE}"
fi

SNAPSHOT_PATH="${TIER}/${DATE}"

# Verify the snapshot exists
snapshot_check=$(rclone_r2 lsf "r2:${BUCKET}/${SNAPSHOT_PATH}/" 2>/dev/null | head -1 || true)
if [ -z "${snapshot_check}" ]; then
    log_err "Snapshot '${SNAPSHOT_PATH}' not found or is empty in R2."
    log_err "Run '$0 list --tier ${TIER}' to see available snapshots."
    exit 1
fi

# ---------------------------------------------------------------------------
# Confirmation prompt — restore is a destructive, manual operation
# ---------------------------------------------------------------------------
echo ""
case "${COMPONENT}" in
    all)    echo "WARNING: This will overwrite /var/mnt/storage/ with r2:${BUCKET}/${SNAPSHOT_PATH}/" ;;
    images) echo "WARNING: This will overwrite ghost/upload-data/images/ with r2:${BUCKET}/${SNAPSHOT_PATH}/ghost/upload-data/images/" ;;
    mysql)  echo "WARNING: This will overwrite mysql/data/ with r2:${BUCKET}/${SNAPSHOT_PATH}/mysql/data/" ;;
esac
echo "Tier: ${TIER}  |  Snapshot: ${DATE}"
echo "Ghost-compose will be stopped during the restore and restarted when complete."
echo ""
read -r -p "Type 'yes' to continue: " CONFIRM
if [ "${CONFIRM}" != "yes" ]; then
    log "Restore aborted."
    exit 0
fi

log "Stopping ghost-compose..."
docker compose -f "${COMPOSE_FILE}" --project-directory /etc/ghost-compose down

case "${COMPONENT}" in
    all)
        log "Restoring all from r2:${BUCKET}/${SNAPSHOT_PATH} to ${STORAGE_DIR}..."
        docker run --rm \
            --network host \
            -v "${RCLONE_CONFIG}:/config/rclone/rclone.conf:ro" \
            -v "${STORAGE_DIR}:/data" \
            "${RCLONE_IMAGE}" sync "r2:${BUCKET}/${SNAPSHOT_PATH}" /data \
            --exclude "ghost-compose/secrets/**" \
            --exclude "ghost-compose/.env.secrets" \
            --exclude "ghost-compose/.env.generated" \
            --exclude "sbin/**" \
            --create-empty-src-dirs \
            --log-level INFO
        ;;
    images)
        log "Restoring images from r2:${BUCKET}/${SNAPSHOT_PATH}/ghost/upload-data/images to ${STORAGE_DIR}/ghost/upload-data/images..."
        docker run --rm \
            --network host \
            -v "${RCLONE_CONFIG}:/config/rclone/rclone.conf:ro" \
            -v "${STORAGE_DIR}:/data" \
            "${RCLONE_IMAGE}" sync "r2:${BUCKET}/${SNAPSHOT_PATH}/ghost/upload-data/images" /data/ghost/upload-data/images \
            --create-empty-src-dirs \
            --log-level INFO
        ;;
    mysql)
        log "Restoring MySQL from r2:${BUCKET}/${SNAPSHOT_PATH}/mysql/data to ${STORAGE_DIR}/mysql/data..."
        docker run --rm \
            --network host \
            -v "${RCLONE_CONFIG}:/config/rclone/rclone.conf:ro" \
            -v "${STORAGE_DIR}:/data" \
            "${RCLONE_IMAGE}" sync "r2:${BUCKET}/${SNAPSHOT_PATH}/mysql/data" /data/mysql/data \
            --create-empty-src-dirs \
            --log-level INFO
        ;;
esac

log "Restore complete. Starting ghost-compose..."
docker compose -f "${COMPOSE_FILE}" --project-directory /etc/ghost-compose up -d

log "Done."
docker ps --format "table {{.Names}}\t{{.Status}}"
# EXIT trap runs: shred rclone config
