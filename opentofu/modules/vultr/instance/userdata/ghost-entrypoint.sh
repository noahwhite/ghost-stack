#!/bin/sh
# ghost-entrypoint.sh — Inject Docker secrets into Ghost config before startup
#
# Reads secrets from /run/secrets/ (mounted by Docker Compose secrets: directive)
# and writes them to /var/lib/ghost/config.production.json using node for proper
# JSON encoding. Secrets are never exported as env vars, so they are not visible
# in `docker inspect` or `docker exec CONTAINER env`.
#
# Ghost config priority: env vars > config file. We therefore also remove
# database__connection__password and tinybird__adminToken from the compose.yml
# environment: section so those empty strings don't override our config file values.
set -eu

DB_PASS=$(cat /run/secrets/db_password)
MAIL_PASS=$(cat /run/secrets/mail_smtp_password)
TB_TOKEN=""
[ -f /run/secrets/tinybird_admin_token ] && TB_TOKEN=$(cat /run/secrets/tinybird_admin_token)

# Write secrets to Ghost config file.
# DB_PASS="$DB_PASS" ... syntax sets vars only in node's subprocess env (not exported to shell).
# node handles proper JSON encoding so special characters in passwords are safe.
DB_PASS="$DB_PASS" MAIL_PASS="$MAIL_PASS" TB_TOKEN="$TB_TOKEN" \
  /usr/local/bin/node -e "
var f = require('fs');
var cfg = {
  database: { connection: { password: process.env.DB_PASS } },
  mail: { options: { auth: { pass: process.env.MAIL_PASS } } }
};
if (process.env.TB_TOKEN) { cfg.tinybird = { adminToken: process.env.TB_TOKEN }; }
f.writeFileSync('/var/lib/ghost/config.production.json', JSON.stringify(cfg));
"

# Shell-local vars were never exported, but unset for hygiene
unset DB_PASS MAIL_PASS TB_TOKEN

exec docker-entrypoint.sh "$@"
