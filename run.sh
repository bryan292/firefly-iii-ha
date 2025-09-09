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

# Ensure storage exists
mkdir -p "${STORAGE_DIR}"
echo "Ensuring storage directory exists..."

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

# Simpler approach for storage directory symlink
echo "Setting up storage directory symlink using safer approach..."

# Create all subdirectories in persistent storage first
mkdir -p "${STORAGE_DIR}/app" "${STORAGE_DIR}/build" "${STORAGE_DIR}/database" \
         "${STORAGE_DIR}/debugbar" "${STORAGE_DIR}/export" "${STORAGE_DIR}/framework" \
         "${STORAGE_DIR}/logs" "${STORAGE_DIR}/upload"

# First, copy the upstream storage permissions and content (if this is first run)
if [ -d "${APP_DIR}/storage" ] && [ ! -L "${APP_DIR}/storage" ]; then
  echo "Copying existing storage content and permissions to persistent storage..."
  
  # Copy existing content recursively, preserving attributes
  cp -a "${APP_DIR}/storage/." "${STORAGE_DIR}/" 2>/dev/null || true
  
  # Now, instead of deleting the old directory (which can be busy),
  # let's use a different approach - move the original out of the way
  echo "Renaming original storage directory..."
  if [ -d "${APP_DIR}/storage" ]; then
    mv "${APP_DIR}/storage" "${APP_DIR}/storage.orig" 2>/dev/null || {
      echo "Could not rename storage directory, using alternate method..."
      # If we can't rename, try to at least create the symlink for new content
      mkdir -p "${APP_DIR}/storage.new"
      ln -sfn "${STORAGE_DIR}" "${APP_DIR}/storage.new"
      # Try to use mount bind to overlay the symlink on the original directory
      if command -v mount >/dev/null 2>&1; then
        echo "Attempting bind mount overlay..."
        mount --bind "${APP_DIR}/storage.new" "${APP_DIR}/storage" 2>/dev/null || true
      fi
    }
  fi
fi

# Create the symlink (this works if original was successfully renamed/moved)
if [ ! -e "${APP_DIR}/storage" ]; then
  echo "Creating storage symlink..."
  ln -sfn "${STORAGE_DIR}" "${APP_DIR}/storage"
elif [ ! -L "${APP_DIR}/storage" ]; then
  # If storage still exists and isn't a symlink, we'll try one more approach
  echo "Using PHP to operate on storage directory..."
  php -r "
    // Create storage directories if they don't exist
    @mkdir('${STORAGE_DIR}', 0755, true);
    
    // Get the current directory
    \$appDir = '${APP_DIR}';
    \$storageDir = '${STORAGE_DIR}';
    
    // If the storage directory exists and is not a symlink, try to handle it
    if (is_dir(\$appDir . '/storage') && !is_link(\$appDir . '/storage')) {
      // Copy any existing content
      \$files = new RecursiveIteratorIterator(
        new RecursiveDirectoryIterator(\$appDir . '/storage', RecursiveDirectoryIterator::SKIP_DOTS),
        RecursiveIteratorIterator::SELF_FIRST
      );
      
      foreach (\$files as \$fileinfo) {
        \$target = \$storageDir . '/' . substr(\$fileinfo->getPathname(), strlen(\$appDir . '/storage/'));
        if (\$fileinfo->isDir()) {
          @mkdir(\$target, 0755, true);
        } else {
          @copy(\$fileinfo->getPathname(), \$target);
        }
      }
      
      // Rename the original (this might work where shell commands failed)
      @rename(\$appDir . '/storage', \$appDir . '/storage.bak');
      
      // Create the symlink
      if (!file_exists(\$appDir . '/storage')) {
        @symlink(\$storageDir, \$appDir . '/storage');
      }
    }
    
    echo 'PHP storage handling complete';
  "
fi

# Set permissions on the storage directory
echo "Setting final permissions..."
chmod -R 755 "${STORAGE_DIR}" 2>/dev/null || true
chown -R www-data:www-data "${STORAGE_DIR}" 2>/dev/null || true

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
