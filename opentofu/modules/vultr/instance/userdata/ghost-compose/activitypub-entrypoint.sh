#!/bin/sh
set -e

# Read db_password from Docker secret (mounted by Docker Compose secrets: directive).
# Exports MYSQL_PASSWORD for the activitypub container and constructs MYSQL_DB DSN
# for the activitypub-migrate container (same pattern as ghost-entrypoint.sh).
DB_PASS=$(cat /run/secrets/db_password)
export MYSQL_PASSWORD="$DB_PASS"

# activitypub-migrate reads MYSQL_DB (full DSN).
# Construct it from component env vars set via compose environment: directive.
# Only set if MYSQL_HOST is present (activitypub-migrate case).
if [ -n "${MYSQL_HOST:-}" ]; then
    export MYSQL_DB="mysql://${MYSQL_USER:-ghost}:${DB_PASS}@tcp(${MYSQL_HOST}:3306)/${MYSQL_DATABASE:-activitypub}"
fi

exec "$@"
