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
        # Generate a new key
        APP_KEY=$(openssl rand -base64 32)
        echo "Generated new APP_KEY: $APP_KEY"
        echo "$APP_KEY" > /data/app_key
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
export APP_KEY=$APP_KEY
export PHP_MEMORY_LIMIT=$PHP_MEMORY_LIMIT
export TRUSTED_PROXIES=$TRUSTED_PROXIES

# Set APP_URL if provided
if [ -n "$APP_URL" ]; then
    export APP_URL=$APP_URL
fi

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

# If we're running as PID 1, exec the original entrypoint
if [ $$ -eq 1 ]; then
    exec /init
else
    # Otherwise, we're probably running from s6, so just keep going
    php-fpm
    nginx -g "daemon off;"
fi
