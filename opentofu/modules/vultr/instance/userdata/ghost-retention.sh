#!/bin/bash
# ghost-retention.sh — Tiered backup retention (GFS: daily → weekly → monthly → quarterly)
#
# Called by ghost-backup.service after ghost-backup.sh completes (ExecStartPost).
# Implements Grandfather-Father-Son rotation:
#
#   Daily:     keep 7   — r2:bucket/daily/YYYY-MM-DD/
#   Weekly:    keep 4   — r2:bucket/weekly/YYYY-WXX/    (promoted from daily every Sunday)
#   Monthly:   keep 3   — r2:bucket/monthly/YYYY-MM/    (promoted from weekly on last day of month)
#   Quarterly: keep 4   — r2:bucket/quarterly/YYYY-QX/  (promoted from monthly on last day of Q)
#
# Promotions are server-side R2 copies (rclone copy) — no data transfer through the instance.
# Pruning uses rclone purge to delete oldest entries beyond each tier's retention limit.
#
# R2 credentials are read from secret files written by infisical-secrets-fetch.sh at boot.
# The rclone config is written to tmpfs (/run/) and shredded on exit.
# Credentials are NOT passed as -e env vars to docker run (would appear in docker inspect).
set -euo pipefail

CONFIG_FILE="/etc/ghost-compose/.env.config"
SECRETS_DIR="/var/mnt/storage/ghost-compose/secrets"
RCLONE_CONFIG="/run/rclone-retention.conf"
RCLONE_IMAGE="rclone/rclone:1.69.1"

log()     { logger -t ghost-retention "$*"; echo "[ghost-retention] $*"; }
log_err() { logger -t ghost-retention -p err "ERROR: $*"; echo "[ghost-retention] ERROR: $*" >&2; }

trap 'shred -u "${RCLONE_CONFIG}" 2>/dev/null || true' EXIT

set -a; source "${CONFIG_FILE}"; set +a

if [ ! -f "${SECRETS_DIR}/ghost_dev_bckup_r2_access_key_id" ] || \
   [ ! -f "${SECRETS_DIR}/ghost_dev_bckup_r2_secret_access_key" ]; then
    log_err "R2 secret files not found — was infisical-secrets-fetch.sh run at boot?"
    exit 1
fi

R2_ACCESS_KEY_ID="$(cat "${SECRETS_DIR}/ghost_dev_bckup_r2_access_key_id")"
R2_SECRET_ACCESS_KEY="$(cat "${SECRETS_DIR}/ghost_dev_bckup_r2_secret_access_key")"

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

# Run rclone in docker. No local volume needed for R2-to-R2 operations.
rclone_cmd() {
    docker run --rm \
        --network host \
        -v "${RCLONE_CONFIG}:/config/rclone/rclone.conf:ro" \
        "${RCLONE_IMAGE}" \
        "$@"
}

# List entries in a tier sorted ascending, one per line (trailing slashes stripped).
# Returns empty string when the tier is empty or does not yet exist.
list_tier() {
    local tier="$1"
    rclone_cmd lsf "r2:${BUCKET}/${tier}/" --dirs-only 2>/dev/null \
        | sed 's|/$||' | sort || true
}

# Prune a tier to retain only the N most recent entries (by sorted ascending name).
prune_tier() {
    local tier="$1"
    local keep="$2"
    local entries count excess
    entries=$(list_tier "${tier}")
    count=$(printf '%s\n' "${entries}" | grep -c '[^[:space:]]' 2>/dev/null || echo 0)
    if [ "${count}" -gt "${keep}" ]; then
        excess=$(( count - keep ))
        printf '%s\n' "${entries}" | head -n "${excess}" | while IFS= read -r entry; do
            [ -z "${entry}" ] && continue
            log "Pruning ${tier}/${entry}"
            rclone_cmd purge "r2:${BUCKET}/${tier}/${entry}" --log-level INFO
        done
    fi
}

TODAY=$(date +%Y-%m-%d)
DOW=$(date +%u)         # 1=Monday … 7=Sunday
DOM=$(date +%d)         # Day of month (zero-padded, e.g. 09)
MONTH_NUM=$(date +%-m)  # Month number without leading zero (e.g. 3)
LAST_DOM=$(date -d "$(date +%Y-%m-01) +1 month -1 day" +%d)

# ---------------------------------------------------------------------------
# Weekly rollup — every Sunday, promote today's daily snapshot to weekly tier
# ---------------------------------------------------------------------------
if [ "${DOW}" -eq 7 ]; then
    WEEK=$(date +%G-W%V)   # ISO year-week, e.g. 2026-W11
    log "Weekly rollup: daily/${TODAY} → weekly/${WEEK}"
    rclone_cmd copy "r2:${BUCKET}/daily/${TODAY}" "r2:${BUCKET}/weekly/${WEEK}" \
        --log-level INFO
    prune_tier weekly 4
fi

# ---------------------------------------------------------------------------
# Monthly rollup — on last day of month, promote latest weekly to monthly tier
# ---------------------------------------------------------------------------
if [ "${DOM}" -eq "${LAST_DOM}" ]; then
    MONTH=$(date +%Y-%m)
    LATEST_WEEKLY=$(list_tier weekly | tail -1)
    if [ -n "${LATEST_WEEKLY}" ]; then
        log "Monthly rollup: weekly/${LATEST_WEEKLY} → monthly/${MONTH}"
        rclone_cmd copy "r2:${BUCKET}/weekly/${LATEST_WEEKLY}" "r2:${BUCKET}/monthly/${MONTH}" \
            --log-level INFO
        prune_tier monthly 3
    else
        log_err "No weekly backup found for monthly rollup — skipping"
    fi

    # -------------------------------------------------------------------------
    # Quarterly rollup — on last day of Q1 (Mar), Q2 (Jun), Q3 (Sep), Q4 (Dec)
    # -------------------------------------------------------------------------
    if [ "${MONTH_NUM}" -eq 3 ] || [ "${MONTH_NUM}" -eq 6 ] || \
       [ "${MONTH_NUM}" -eq 9 ] || [ "${MONTH_NUM}" -eq 12 ]; then
        QN=$(( (MONTH_NUM - 1) / 3 + 1 ))
        QUARTER="$(date +%Y)-Q${QN}"
        LATEST_MONTHLY=$(list_tier monthly | tail -1)
        if [ -n "${LATEST_MONTHLY}" ]; then
            log "Quarterly rollup: monthly/${LATEST_MONTHLY} → quarterly/${QUARTER}"
            rclone_cmd copy "r2:${BUCKET}/monthly/${LATEST_MONTHLY}" \
                "r2:${BUCKET}/quarterly/${QUARTER}" \
                --log-level INFO
            prune_tier quarterly 4
        else
            log_err "No monthly backup found for quarterly rollup — skipping"
        fi
    fi
fi

# ---------------------------------------------------------------------------
# Always prune daily tier to 7
# ---------------------------------------------------------------------------
prune_tier daily 7

log "Retention complete."
# EXIT trap runs: shred rclone config
