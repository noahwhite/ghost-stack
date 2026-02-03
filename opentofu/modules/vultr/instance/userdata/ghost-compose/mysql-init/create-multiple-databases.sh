#!/bin/bash
# Create additional databases for Ghost services (e.g., ActivityPub)
# Source: https://github.com/TryGhost/ghost-docker/blob/main/mysql-init/create-multiple-databases.sh

set -e
set -u

if [ -n "$MYSQL_MULTIPLE_DATABASES" ]; then
  echo "Creating multiple databases: $MYSQL_MULTIPLE_DATABASES"

  for db in $(echo "$MYSQL_MULTIPLE_DATABASES" | tr ',' ' '); do
    echo "Creating database: $db"
    mysql -u root -p"$MYSQL_ROOT_PASSWORD" <<-EOSQL
      CREATE DATABASE IF NOT EXISTS \`$db\`;
      GRANT ALL ON \`$db\`.* TO '$MYSQL_USER'@'%';
EOSQL
  done

  echo "Multiple databases created"
fi
