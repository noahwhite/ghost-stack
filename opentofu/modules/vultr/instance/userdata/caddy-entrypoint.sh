#!/bin/sh
# caddy-entrypoint.sh — Pre-process Caddyfile with health check token before startup
#
# Reads the health check token from /run/secrets/health_check_token (mounted by
# Docker Compose secrets: directive) and substitutes it into the Caddyfile using
# awk, then starts Caddy pointing at the processed config. The token is never
# exported as an env var, so it is not visible in `docker inspect` or
# `docker exec CONTAINER env`.
#
# Other {$VAR} references in the Caddyfile (DOMAIN, ADMIN_DOMAIN, ADMIN_IP) are
# left intact for Caddy to expand at load time from the container environment
# (sourced from .env.config via env_file:).
set -eu

HEALTH_CHECK_TOKEN=$(cat /run/secrets/health_check_token)

# Substitute {$HEALTH_CHECK_TOKEN} using awk.
# awk -v passes the value as an awk-local variable (not a shell export).
# BEGIN block escapes & and \ in the token value to prevent awk gsub replacement issues.
PROCESSED="/etc/caddy/Caddyfile.processed"
awk -v tok="$HEALTH_CHECK_TOKEN" '
  BEGIN { gsub(/[&\\]/, "\\\\&", tok) }
  { gsub(/\{\$HEALTH_CHECK_TOKEN\}/, tok); print }
' /etc/caddy/Caddyfile > "$PROCESSED"

# Shell-local var was never exported, but unset for hygiene
unset HEALTH_CHECK_TOKEN

exec caddy run --config "$PROCESSED" --adapter caddyfile
