#!/bin/sh
set -eu

CONFIG_PATH="/var/lib/ghost/config.production.json"

# Read secrets from /run/secrets/ (mounted by Docker Compose secrets: directive)
DB_PASS=$(cat /run/secrets/db_password)
MAIL_PASS=$(cat /run/secrets/mail_smtp_password)
TINYBIRD_TOKEN=""
[ -f /run/secrets/tinybird_admin_token ] && TINYBIRD_TOKEN=$(cat /run/secrets/tinybird_admin_token)

# Write full Ghost config. Secrets never appear in env — not visible in
# docker inspect or docker exec CONTAINER env.
cat <<EOF > "$CONFIG_PATH"
{
  "url": "${url:-http://localhost:2368}",
  "database": {
    "client": "mysql",
    "connection": {
      "host": "${database__connection__host}",
      "user": "${database__connection__user}",
      "password": "${DB_PASS}",
      "database": "${database__connection__database}"
    }
  },
  "mail": {
    "transport": "SMTP",
    "options": {
      "auth": {
        "user": "${mail__options__auth__user}",
        "pass": "${MAIL_PASS}"
      }
    }
  },
  "tinybird": {
    "adminToken": "${TINYBIRD_TOKEN}"
  }
}
EOF

# Ghost runs as 'node' but this script runs as root — hand ownership over
# so Ghost can update the config (e.g. generated secrets) at runtime.
chown node:node "$CONFIG_PATH"

exec /usr/local/bin/docker-entrypoint.sh node current/index.js
