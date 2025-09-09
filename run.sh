#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/html}"
HA_DATA_DIR="${HA_DATA_DIR:-/data/firefly}"
PORT="${PORT:-8080}"

mkdir -p "${HA_DATA_DIR}"
cd "${APP_DIR}"

# Read add-on options (Supervisor mounts at /data/options.json)
OPTIONS_FILE="/data/options.json"
jq_installed=0
if command -v jq >/dev/null 2>&1; then jq_installed=1; fi
if [ $jq_installed -eq 0 ]; then
  echo "jq not found in image. Firefly III image should include it; if not, please install or adjust script."
fi

# Extract options with fallbacks
get_opt() {
  local key="$1" default="$2"
  if [ -f "${OPTIONS_FILE}" ] && [ $jq_installed -eq 1 ]; then
    val=$(jq -r --arg k "$key" '.[$k] // empty' "${OPTIONS_FILE}")
    [ -n "$val" ] && { echo "$val"; return; }
  fi
  echo "$default"
}

DB_HOST="$(get_opt db_host 127.0.0.1)"
DB_PORT="$(get_opt db_port 3306)"
DB_NAME="$(get_opt db_name firefly)"
DB_USER="$(get_opt db_user firefly)"
DB_PASSWORD="$(get_opt db_password "")"
APP_URL="$(get_opt app_url "")"
TIMEZONE="$(get_opt timezone UTC)"
SITE_OWNER="$(get_opt site_owner owner@example.com)"
GENERATE_APP_KEY="$(get_opt generate_app_key true)"

# Prepare persistent env & storage
ENV_FILE="${HA_DATA_DIR}/.env"
STORAGE_DIR="${HA_DATA_DIR}/storage"

# Create default .env if missing
if [ ! -f "${ENV_FILE}" ]; then
  cp .env.example "${ENV_FILE}" || touch "${ENV_FILE}"
fi

# Ensure storage exists and is writable
mkdir -p "${STORAGE_DIR}"
chown -R www-data:www-data "${STORAGE_DIR}" || true

# Update .env with options (idempotent: use crudini-like sed replaces)
set_kv() {
  local key="$1" value="$2"
  # Escape slashes in value
  value_escaped=$(printf '%s\n' "$value" | sed -e 's/[\/&]/\\&/g')
  if grep -qE "^${key}=" "${ENV_FILE}"; then
    sed -i "s|^${key}=.*|${key}=${value_escaped}|" "${ENV_FILE}"
  else
    echo "${key}=${value}" >> "${ENV_FILE}"
  fi
}

# Core Laravel/Firefly settings
set_kv APP_ENV "production"
# If APP_URL is empty, avoid forcing absolute URLs; Firefly can still work behind reverse proxy.
[ -n "${APP_URL}" ] && set_kv APP_URL "${APP_URL}"

set_kv TZ "${TIMEZONE}"
set_kv TRUSTED_PROXIES "**"
set_kv LOG_CHANNEL "stack"
set_kv SITE_OWNER "${SITE_OWNER}"

# DB settings
set_kv DB_CONNECTION "mysql"
set_kv DB_HOST "${DB_HOST}"
set_kv DB_PORT "${DB_PORT}"
set_kv DB_DATABASE "${DB_NAME}"
set_kv DB_USERNAME "${DB_USER}"
set_kv DB_PASSWORD "${DB_PASSWORD}"

# Mail defaults (no SMTP by default)
set_kv MAIL_MAILER "log"

# Ensure APP_KEY exists
if grep -q "^APP_KEY=" "${ENV_FILE}"; then
  if [ "${GENERATE_APP_KEY}" = "true" ] && [ -z "$(grep '^APP_KEY=' "${ENV_FILE}" | cut -d= -f2-)" ]; then
    php artisan key:generate --force --no-ansi --env-file "${ENV_FILE}"
  fi
else
  if [ "${GENERATE_APP_KEY}" = "true" ]; then
    echo "APP_KEY=" >> "${ENV_FILE}"
    php artisan key:generate --force --no-ansi --env-file "${ENV_FILE}"
  fi
fi

# Link persistent storage into app dir if not already
if [ ! -L "${APP_DIR}/storage" ] && [ -d "${APP_DIR}/storage" ]; then
  rm -rf "${APP_DIR}/storage"
  ln -s "${STORAGE_DIR}" "${APP_DIR}/storage"
fi

# Permissions
chown -R www-data:www-data "${HA_DATA_DIR}" || true

# Optimize config/cache using the persistent env file
export APP_ENV=production
export PORT="${PORT}"

# Use the env file for artisan commands
php artisan config:clear --no-ansi --env-file "${ENV_FILE}" || true
php artisan cache:clear --no-ansi --env-file "${ENV_FILE}" || true
php artisan config:cache --no-ansi --env-file "${ENV_FILE}" || true

# Run migrations (retry for DB readiness)
tries=0
until php artisan migrate --force --no-ansi --env-file "${ENV_FILE}" || [ $tries -ge 15 ]; do
  tries=$((tries+1))
  echo "DB not ready... retry ${tries}/15"
  sleep 4
done

# Start the upstream web server stack.
# The official image uses supervisord to run nginx+php-fpm via /entrypoint.sh
# We exec it so PID 1 is replaced (signals handled correctly).
exec /entrypoint.sh
