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
echo "🔧 Configuring Firefly III..."
ENV_FILE=/data/firefly-iii.env
GLOBAL_ENV=/etc/environment

# Handle APP_KEY
if [ -z "$APP_KEY_OPT" ]; then
    if [ -f /data/app_key ]; then
        # Read APP_KEY from file
        APP_KEY=$(cat /data/app_key)
        echo "✅ Using stored APP_KEY from /data/app_key"
    else
        # Generate new APP_KEY
        echo "⏳ Generating new APP_KEY..."
        cd /var/www/html
        NEW_APP_KEY=$(php artisan key:generate --show)
        echo "$NEW_APP_KEY" > /data/app_key
        APP_KEY="$NEW_APP_KEY"
        echo "✅ New APP_KEY generated and stored in /data/app_key"
    fi
else
    # Use provided APP_KEY from options
    APP_KEY="$APP_KEY_OPT"
    echo "$APP_KEY" > /data/app_key
    echo "✅ Using APP_KEY from configuration"
fi

# Create the environment file for persistence
cat > $ENV_FILE << EOF
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

# Create .env file for Laravel
cp $ENV_FILE /var/www/html/.env

# Also add environment variables to global system env for all processes
cat > $GLOBAL_ENV << EOF
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
DISABLE_DEMO_USER=true
ALLOW_WEBHOOKS=true
CACHE_DRIVER=file
SESSION_DRIVER=file
ALLOW_CORS=true
EOF

# Export variables to current shell
export APP_KEY="${APP_KEY}"
export APP_URL="${APP_URL:-http://localhost}"
export DB_CONNECTION="mysql"
export DB_HOST="${DB_HOST}"
export DB_PORT="${DB_PORT}"
export DB_DATABASE="${DB_NAME}"
export DB_USERNAME="${DB_USER}"
export DB_PASSWORD="${DB_PASSWORD}"
export MAIL_MAILER="log"
export TRUSTED_PROXIES="${TRUSTED_PROXIES}"
export TZ="${TIMEZONE}"
export PHP_MEMORY_LIMIT="${PHP_MEMORY_LIMIT}"
export DISABLE_DEMO_USER="true"
export ALLOW_WEBHOOKS="true"
export CACHE_DRIVER="file"
export SESSION_DRIVER="file"
export ALLOW_CORS="true"

# Print created configuration
echo "✅ Created .env file with the following settings:"
grep -v "PASSWORD" /var/www/html/.env

# Wait for database to be ready
echo "⏳ Waiting for database connection..."
COUNTER=0
while ! nc -z "$DB_HOST" "$DB_PORT"; do
    if [ $COUNTER -gt 30 ]; then
        echo "❌ Database connection timed out after 30 seconds"
        exit 1
    fi
    sleep 1
    COUNTER=$((COUNTER+1))
done
echo "✅ Database connection successful!"

# Set correct permissions
echo "🔧 Setting up file permissions..."
mkdir -p /var/www/html/storage/framework/{sessions,views,cache}
mkdir -p /var/www/html/storage/logs
chown -R www-data:www-data /var/www/html/storage
chown -R www-data:www-data /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/storage
chmod -R 775 /var/www/html/bootstrap/cache

# Initialize database
echo "🔄 Initializing database..."
cd /var/www/html
php artisan migrate --force
php artisan db:seed --force
php artisan firefly-iii:upgrade-database
php artisan firefly-iii:correct-database

# Create a profile.d script to ensure environment variables are loaded for all shells
mkdir -p /etc/profile.d
cat > /etc/profile.d/firefly-env.sh << EOF
#!/bin/bash
set -a
source $ENV_FILE
set +a
EOF
chmod +x /etc/profile.d/firefly-env.sh

# Also create a systemwide env file that the entrypoint.sh can source
cat > /etc/firefly.env << EOF
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
DISABLE_DEMO_USER=true
ALLOW_WEBHOOKS=true
CACHE_DRIVER=file
SESSION_DRIVER=file
ALLOW_CORS=true
EOF

echo "✅ Bootstrap completed successfully"
