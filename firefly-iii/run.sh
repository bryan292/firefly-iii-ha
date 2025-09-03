#!/usr/bin/env bash
set -e

# Load environment variables if they exist
if [ -f /data/firefly-iii.env ]; then
    set -a
    source /data/firefly-iii.env
    set +a
    echo "🔄 Loaded environment from /data/firefly-iii.env"
fi

# Ensure we have an APP_KEY
if [ -z "$APP_KEY" ] && [ -f /data/app_key ]; then
    export APP_KEY=$(cat /data/app_key)
    echo "🔑 Loaded APP_KEY from /data/app_key"
fi

# Make sure we have the Laravel .env file
if [ -f /data/firefly-iii.env ]; then
    cp /data/firefly-iii.env /var/www/html/.env
    echo "📝 Copied environment to Laravel .env file"
fi

# Check database connection
db_host="${DB_HOST:-core-mariadb}"
db_port="${DB_PORT:-3306}"
echo "🔄 Checking connection to database at $db_host:$db_port..."

max_attempts=30
attempt=0
while ! nc -z "$db_host" "$db_port"; do
    attempt=$((attempt+1))
    if [ $attempt -ge $max_attempts ]; then
        echo "❌ Failed to connect to database after $max_attempts attempts"
        exit 1
    fi
    echo "⏳ Waiting for database connection... ($attempt/$max_attempts)"
    sleep 1
done
echo "✅ Database connection established"

# Ensure storage directories exist and have proper permissions
echo "🔧 Setting up file permissions..."
mkdir -p /var/www/html/storage/framework/sessions
mkdir -p /var/www/html/storage/framework/views
mkdir -p /var/www/html/storage/framework/cache
mkdir -p /var/www/html/storage/logs
chown -R www-data:www-data /var/www/html/storage
chmod -R 775 /var/www/html/storage
chown -R www-data:www-data /var/www/html/bootstrap/cache
chmod -R 775 /var/www/html/bootstrap/cache

# Run database migrations and setup
echo "🔄 Running database migrations..."
cd /var/www/html
php artisan migrate --force
php artisan db:seed --force
php artisan firefly-iii:upgrade-database
php artisan firefly-iii:correct-database

# Create a special script to handle ingress authentication
cat > /var/www/html/public/ingress-auth.php << 'EOF'
<?php
session_start();
// This file handles ingress authentication for Home Assistant
$_SESSION['auth_user_id'] = 1; // Set as authenticated
$_SESSION['auth_guard'] = 'web';
$_SESSION['auth_remember'] = true;

// Redirect to main page
header('Location: /');
exit;
EOF

# Create a simple router to handle Home Assistant ingress
cat > /var/www/html/public/index-ingress.php << 'EOF'
<?php
// Simple router for ingress support
$uri = $_SERVER['REQUEST_URI'];

// Handle basic auth or ingress auth
if (strpos($uri, '/login') !== false) {
    include 'ingress-auth.php';
    exit;
}

// Forward to standard index.php
include 'index.php';
EOF

# Create a healthcheck endpoint for Home Assistant
mkdir -p /var/www/html/public/healthcheck
cat > /var/www/html/public/healthcheck/index.php << 'EOF'
<?php
header('Content-Type: application/json');
echo json_encode(['status' => 'ok', 'timestamp' => time()]);
EOF

echo "🚀 Starting PHP server..."
cd /var/www/html
exec php -S 0.0.0.0:8080 -t public public/index-ingress.php
