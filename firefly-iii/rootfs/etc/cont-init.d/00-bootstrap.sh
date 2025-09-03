#!/bin/bash
set -e

CONFIG_PATH=/data/options.json
APP_KEY_OPT=$(jq --raw-output '.app_key // ""' $CONFIG_PATH)
DB_HOST=$(jq --raw-output '.db_host' $CONFIG_PATH)
DB_PORT=$(jq --raw-output '.db_port' $CONFIG_PATH)
DB_NAME=$(jq --raw-output '.db_name' $CONFIG_PATH)
DB_USER=$(jq --raw-output '.db_user' $CONFIG_PATH)
DB_PASSWORD=$(jq --raw-output '.db_password' $CONFIG_PATH)
APP_URL=$(jq --raw-output '.app_url // ""' $CONFIG_PATH)
TRUSTED_PROXIES=$(jq --raw-output '.trusted_proxies' $CONFIG_PATH)
TIMEZONE=$(jq --raw-output '.timezone' $CONFIG_PATH)
PHP_MEMORY_LIMIT=$(jq --raw-output '.php_memory_limit' $CONFIG_PATH)

# Create and persist environment file
echo "Creating environment file for persistence between container restarts..."
ENV_FILE=/data/firefly-iii.env

# Handle APP_KEY
if [ -z "$APP_KEY_OPT" ] && [ -z "$APP_KEY" ]; then
    if [ -f /data/app_key ]; then
        # Read APP_KEY from file
        APP_KEY=$(cat /data/app_key)
        export APP_KEY
        echo "Using APP_KEY from /data/app_key"
    else
        # Generate new APP_KEY
        echo "Generating new APP_KEY..."
        cd /var/www/html
        NEW_APP_KEY=$(php artisan key:generate --show)
        echo "$NEW_APP_KEY" > /data/app_key
        export APP_KEY="$NEW_APP_KEY"
        echo "New APP_KEY generated and stored in /data/app_key"
    fi
else
    # Use provided APP_KEY from options
    APP_KEY="$APP_KEY_OPT"
    export APP_KEY
    echo "Using APP_KEY from configuration"
fi

# Create .env file with the required environment variables
cat > /var/www/html/.env << EOF
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
PHP_MEMORY_LIMIT=${PHP_MEMORY_LIMIT}
# Disable demo accounts by default
DISABLE_DEMO_USER=true
# Recommended settings for Home Assistant integration
ALLOW_WEBHOOKS=true
# Use sqlite for caching to avoid adding load to MariaDB
CACHE_DRIVER=file
# Better session handling for ingress
SESSION_DRIVER=file
# Enable CORS for potential API use
ALLOW_CORS=true
EOF

# Save to persistent environment file for restarts
cp /var/www/html/.env $ENV_FILE

# Export variables to environment
export DB_CONNECTION=mysql
export DB_HOST=$DB_HOST
export DB_PORT=$DB_PORT
export DB_DATABASE=$DB_NAME
export DB_USERNAME=$DB_USER
export DB_PASSWORD=$DB_PASSWORD

# Ensure storage directories are writable
echo "Setting up file permissions..."
chown -R www-data:www-data /var/www/html/storage
chown -R www-data:www-data /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/bootstrap/cache

# Wait for database to be ready
echo "Waiting for database connection..."
COUNTER=0
while ! nc -z "$DB_HOST" "$DB_PORT"; do
    if [ $COUNTER -gt 30 ]; then
        echo "Database connection timed out after 30 seconds"
        exit 1
    fi
    echo "Waiting for database connection..."
    sleep 1
    COUNTER=$((COUNTER+1))
done
echo "Database connection successful!"

# Run migrations
echo "Initializing database..."
cd /var/www/html
php artisan migrate --force
php artisan db:seed --force
php artisan firefly-iii:upgrade-database

echo "Bootstrap completed successfully"
