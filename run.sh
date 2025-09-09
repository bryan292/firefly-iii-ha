#!/usr/bin/env bash
set -euo pipefail

APP_DIR="${APP_DIR:-/var/www/html}"
HA_DATA_DIR="${HA_DATA_DIR:-/data/firefly}"
PORT="${PORT:-8080}"

mkdir -p "${HA_DATA_DIR}"
cd "${APP_DIR}"

echo "Starting Firefly III Home Assistant add-on"
echo "=========================================="

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
  echo "Creating new .env file from example..."
  cp .env.example "${ENV_FILE}" || touch "${ENV_FILE}"
fi

# Ensure storage exists and is writable
mkdir -p "${STORAGE_DIR}"
echo "Ensuring proper storage directory permissions..."
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
    echo "Generating new APP_KEY..."
    php artisan key:generate --force --no-ansi --env-file "${ENV_FILE}"
  fi
else
  if [ "${GENERATE_APP_KEY}" = "true" ]; then
    echo "APP_KEY not found, creating and generating..."
    echo "APP_KEY=" >> "${ENV_FILE}"
    php artisan key:generate --force --no-ansi --env-file "${ENV_FILE}"
  fi
fi

# Link persistent storage into app dir
echo "Setting up storage directory symlink..."
if [ ! -L "${APP_DIR}/storage" ]; then
  # If storage exists and is a directory but not a symlink, we need to handle it carefully
  if [ -d "${APP_DIR}/storage" ]; then
    # First try to safely unmount any busy resources
    for dir in "${APP_DIR}/storage/"*; do
      if [ -d "$dir" ]; then
        # Try to find and kill processes using these directories
        echo "Checking processes using $dir..."
        fuser -k "$dir" >/dev/null 2>&1 || true
        
        # For upload directory specifically (common issue)
        if [[ "$dir" == *"/upload" ]]; then
          echo "Special handling for upload directory..."
          # Ensure no lingering PHP processes are using this directory
          pkill -f "php.*upload" >/dev/null 2>&1 || true
        fi
      fi
    done
    
    # Wait a moment for processes to terminate
    sleep 2
    
    # Move any existing content to our persistent location first
    echo "Moving existing content to persistent storage..."
    cp -a "${APP_DIR}/storage/"* "${STORAGE_DIR}/" || true
    
    # Remove the original directory - use force if needed with careful checks
    echo "Removing original storage directory..."
    rm -rf "${APP_DIR}/storage" || {
      echo "Warning: Could not remove storage directory cleanly."
      echo "Trying alternative approach..."
      
      # If rmdir fails due to "device or resource busy", try alternative
      # Find and kill all processes that might be using the directory
      lsof "${APP_DIR}/storage" >/dev/null 2>&1 || true
      
      # Remove contents one by one
      find "${APP_DIR}/storage" -type f -delete || true
      find "${APP_DIR}/storage" -type d -empty -delete || true
      
      # If directory still exists, try more aggressive approach
      if [ -d "${APP_DIR}/storage" ]; then
        echo "Using mount tricks to remove busy directory..."
        # Temporarily mount an empty directory over the busy one
        mkdir -p /tmp/empty
        mount --bind /tmp/empty "${APP_DIR}/storage"
        umount "${APP_DIR}/storage"
        rmdir "${APP_DIR}/storage" || true
      fi
    }
  fi
  
  # Now create the symlink
  echo "Creating symlink from ${STORAGE_DIR} to ${APP_DIR}/storage"
  ln -s "${STORAGE_DIR}" "${APP_DIR}/storage"
fi

# Double-check the symlink exists and is valid
if [ ! -L "${APP_DIR}/storage" ] || [ ! -d "$(readlink "${APP_DIR}/storage")" ]; then
  echo "Error: Storage directory symlink is missing or invalid!"
  echo "Attempting emergency recovery..."
  rm -f "${APP_DIR}/storage"
  ln -s "${STORAGE_DIR}" "${APP_DIR}/storage"
fi

# Permissions
echo "Setting final permissions..."
chown -R www-data:www-data "${HA_DATA_DIR}" || true
chown -R www-data:www-data "${APP_DIR}/storage" || true

# Optimize config/cache using the persistent env file
export APP_ENV=production
export PORT="${PORT}"

# Use the env file for artisan commands
echo "Clearing and caching configuration..."
php artisan config:clear --no-ansi --env-file "${ENV_FILE}" || true
php artisan cache:clear --no-ansi --env-file "${ENV_FILE}" || true
php artisan config:cache --no-ansi --env-file "${ENV_FILE}" || true

# Run migrations (retry for DB readiness)
echo "Running database migrations..."
tries=0
until php artisan migrate --force --no-ansi --env-file "${ENV_FILE}" || [ $tries -ge 15 ]; do
  tries=$((tries+1))
  echo "DB not ready... retry ${tries}/15"
  sleep 4
done

# Start the upstream web server stack.
echo "Starting Firefly III web server..."
# The official image uses supervisord to run nginx+php-fpm via /entrypoint.sh
# We exec it so PID 1 is replaced (signals handled correctly).
exec /entrypoint.sh
