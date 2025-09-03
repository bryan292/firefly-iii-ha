#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

# Get options from config
DB_HOST=$(jq --raw-output '.db_host // "core-mariadb"' $CONFIG_PATH)
DB_PORT=$(jq --raw-output '.db_port // 3306' $CONFIG_PATH)
DB_NAME=$(jq --raw-output '.db_name // "homeassistant"' $CONFIG_PATH)
DB_USER=$(jq --raw-output '.db_user // "homeassistant"' $CONFIG_PATH)
DB_PASSWORD=$(jq --raw-output '.db_password // ""' $CONFIG_PATH)
APP_KEY_OPT=$(jq --raw-output '.app_key // ""' $CONFIG_PATH)
APP_URL=$(jq --raw-output '.app_url // ""' $CONFIG_PATH)
TRUSTED_PROXIES=$(jq --raw-output '.trusted_proxies // "**"' $CONFIG_PATH)
TIMEZONE=$(jq --raw-output '.timezone // "UTC"' $CONFIG_PATH)
PHP_MEMORY_LIMIT=$(jq --raw-output '.php_memory_limit // "512M"' $CONFIG_PATH)

# Generate proper base64 APP_KEY - must be exactly 32 bytes long
if [ -z "$APP_KEY_OPT" ]; then
    if [ -f /data/app_key ]; then
        APP_KEY=$(cat /data/app_key)
        echo "Using stored APP_KEY from /data/app_key"
    else
        # Generate a proper Laravel key (must be a 32-byte base64 string)
        APP_KEY=$(php -r "echo 'base64:'.base64_encode(random_bytes(32));")
        echo "Generated new APP_KEY: $APP_KEY"
        echo "$APP_KEY" > /data/app_key
    fi
else
    # If the key doesn't start with base64:, add it
    if [[ "$APP_KEY_OPT" != base64:* ]]; then
        APP_KEY="base64:$APP_KEY_OPT"
    else
        APP_KEY="$APP_KEY_OPT"
    fi
    echo "Using APP_KEY from config"
fi

# Create .env file in Laravel format
cat > /var/www/html/.env <<EOL
APP_ENV=production
APP_DEBUG=false
APP_KEY=${APP_KEY}
APP_URL=${APP_URL:-http://localhost}

DB_CONNECTION=mysql
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}

MAIL_MAILER=log
MAIL_FROM=changeme@example.com
SITE_OWNER=changeme@example.com

TRUSTED_PROXIES=${TRUSTED_PROXIES}
TZ=${TIMEZONE}
EOL

# Fix permissions for Laravel
chown -R www-data:www-data /var/www/html/storage
chmod -R 775 /var/www/html/storage

# Display the .env file (excluding password)
echo "Created .env file with the following settings:"
grep -v "PASSWORD" /var/www/html/.env

# Start Firefly III using the correct entrypoint
if [ -f /entrypoint.sh ]; then
    exec /entrypoint.sh
else
    echo "ERROR: Cannot find Firefly III entrypoint script"
    exit 1
fi
