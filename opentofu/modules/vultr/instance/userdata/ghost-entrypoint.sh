#!/bin/sh
# ghost-entrypoint.sh — Inject Docker secrets into Ghost environment before startup
#
# Reads secrets from /run/secrets/ (mounted by Docker Compose secrets: directive)
# and passes them to Ghost via `exec env`. Secrets are injected into Ghost's
# process environment but are never part of the container's Config.Env, so they
# are not visible in `docker inspect` or `docker exec CONTAINER env`.
set -eu

DB_PASS=$(cat /run/secrets/db_password)
MAIL_PASS=$(cat /run/secrets/mail_smtp_password)

if [ -f /run/secrets/tinybird_admin_token ]; then
  exec env \
    database__connection__password="$DB_PASS" \
    mail__options__auth__pass="$MAIL_PASS" \
    tinybird__adminToken="$(cat /run/secrets/tinybird_admin_token)" \
    docker-entrypoint.sh "$@"
else
  exec env \
    database__connection__password="$DB_PASS" \
    mail__options__auth__pass="$MAIL_PASS" \
    docker-entrypoint.sh "$@"
fi
