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

# Check if we need to use a stored APP_KEY or generate a new one
if [ -z "$APP_KEY_OPT" ]; then
    if [ -f /data/app_key ]; then
        APP_KEY=$(cat /data/app_key)
        echo "Using stored APP_KEY from /data/app_key"
    else
        # Will be generated in bootstrap.sh
        echo "APP_KEY is empty and will be generated during bootstrap"
        APP_KEY=""
    fi
else
    APP_KEY="$APP_KEY_OPT"
    echo "Using APP_KEY from config"
fi

# Export environment variables for Firefly III
export DB_CONNECTION=mysql
export DB_HOST=$DB_HOST
export DB_PORT=$DB_PORT
export DB_DATABASE=$DB_NAME
export DB_USERNAME=$DB_USER
export DB_PASSWORD=$DB_PASSWORD
export TZ=$TIMEZONE
export PHP_MEMORY_LIMIT=$PHP_MEMORY_LIMIT
export TRUSTED_PROXIES=$TRUSTED_PROXIES

# Set APP_KEY if we have it
if [ -n "$APP_KEY" ]; then
    export APP_KEY=$APP_KEY
fi

# Set APP_URL if provided
if [ -n "$APP_URL" ]; then
    export APP_URL=$APP_URL
fi

# Set up ingress URL - this helps Firefly work behind the HA proxy
export TRUSTED_PROXIES=$TRUSTED_PROXIES

# Write minimal .env file for Laravel
cat > /var/www/html/.env <<EOL
APP_KEY=${APP_KEY}
DB_CONNECTION=mysql
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASSWORD}
TRUSTED_PROXIES=${TRUSTED_PROXIES}
EOL

if [ -n "$APP_URL" ]; then
    echo "APP_URL=${APP_URL}" >> /var/www/html/.env
fi

# Start s6-overlay
exec /init
