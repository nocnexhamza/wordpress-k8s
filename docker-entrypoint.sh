#!/bin/bash
set -euo pipefail

# Wait for MySQL to be ready (only in Kubernetes)
if [ -n "${WORDPRESS_DB_HOST}" ]; then
  while ! mysqladmin ping -h"${WORDPRESS_DB_HOST}" -u"${WORDPRESS_DB_USER}" -p"${WORDPRESS_DB_PASSWORD}" --silent; do
    echo "Waiting for MySQL to be ready..."
    sleep 2
  done
fi

# Execute the original WordPress entrypoint
exec docker-entrypoint.sh "$@"