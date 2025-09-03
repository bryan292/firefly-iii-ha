#!/bin/bash
set -e

CONFIG_PATH=/data/options.json

# Get options from config
DB_HOST=$(jq --raw-output '.db_host // "core-mariadb"' $CONFIG_PATH)
DB_PORT=$(jq --raw-output '.db_port // 3306' $CONFIG_PATH)
DB_NAME=$(jq --raw-output '.db_name // "firefly"' $CONFIG_PATH)
DB_USER=$(jq --raw-output '.db_user // "firefly"' $CONFIG_PATH)
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

# Wait for database to be available
echo "Waiting for database connection..."
timeout=60
while ! nc -z $DB_HOST $DB_PORT; do
    timeout=$((timeout - 1))
    if [ $timeout -eq 0 ]; then
        echo "Timed out waiting for database connection"
        break
    fi
    echo "Waiting for database to be available... ($timeout seconds left)"
    sleep 1
done

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

# Export environment variables for PHP
export APP_ENV=production
export APP_DEBUG=false
export APP_KEY="$APP_KEY"
export APP_URL="${APP_URL:-http://localhost}"
export DB_CONNECTION=mysql
export DB_HOST="$DB_HOST"
export DB_PORT="$DB_PORT"
export DB_DATABASE="$DB_NAME"
export DB_USERNAME="$DB_USER"
export DB_PASSWORD="$DB_PASSWORD"
export MAIL_MAILER=log
export MAIL_FROM=changeme@example.com
export SITE_OWNER=changeme@example.com
export TRUSTED_PROXIES="$TRUSTED_PROXIES"
export TZ="$TIMEZONE"

# Fix permissions for Laravel
mkdir -p /var/www/html/storage/app
mkdir -p /var/www/html/storage/framework/cache
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/logs
chown -R www-data:www-data /var/www/html/storage
chmod -R 775 /var/www/html/storage

# Display the .env file (excluding password)
echo "Created .env file with the following settings:"
grep -v "PASSWORD" /var/www/html/.env

# Define function to execute application using PHP's built-in server
start_application() {
    cd /var/www/html
    
    # Try to run artisan commands without failing the script
    php artisan migrate --force || echo "Migration failed but continuing"
    php artisan firefly-iii:upgrade-database || echo "Database upgrade failed but continuing"
    php artisan firefly-iii:verify || echo "Verification failed but continuing"
    
    # Create a simple PHP server script that avoids the urldecode issue
    cat > /var/www/html/server-fixed.php <<'EOF'
<?php
// This fixed server script handles all incoming requests properly
$uri = $_SERVER['REQUEST_URI'] ?? '/';
$publicPath = __DIR__ . '/public';

// Check if file exists in public directory
$requestedFile = $publicPath . $uri;
if ($uri !== '/' && file_exists($requestedFile) && !is_dir($requestedFile)) {
    // Serve the file directly
    return false;
}

// Otherwise, include the front controller
require_once $publicPath . '/index.php';
EOF

    # Start the web server with the fixed script
    echo "Starting PHP server on port 8080..."
    exec php -S 0.0.0.0:8080 -t /var/www/html/public /var/www/html/server-fixed.php
}

# Run database migrations
cd /var/www/html
php artisan migrate --force || echo "Migration failed but continuing"
php artisan firefly-iii:upgrade-database || echo "Database upgrade failed but continuing"
php artisan firefly-iii:verify || echo "Verification failed but continuing"

# Start Firefly III using the correct entrypoint
if [ -f /entrypoint.sh ] && [ -x /entrypoint.sh ]; then
    echo "Using entrypoint.sh"
    exec /entrypoint.sh
elif [ -x "$(command -v apache2-foreground)" ]; then
    echo "Starting Apache web server"
    exec apache2-foreground
elif [ -f /var/www/html/artisan ]; then
    echo "Starting Laravel application with built-in server"
    start_application
else
    echo "ERROR: Cannot find Firefly III application"
    ls -la /var/www/html || echo "No /var/www/html directory"
    exit 1
fi
