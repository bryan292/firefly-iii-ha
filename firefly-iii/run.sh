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

# Check if stock entrypoint.sh exists and is executable
if [ -f /entrypoint.sh ] && [ -x /entrypoint.sh ]; then
    echo "🚀 Executing stock Firefly III entrypoint.sh with proper environment"
    # Export our environment variables to ensure they override any defaults
    export APP_ENV=production
    export APP_DEBUG=false
    export APP_KEY
    export DB_CONNECTION=mysql
    export DB_HOST="${DB_HOST:-core-mariadb}"
    export DB_PORT="${DB_PORT:-3306}"
    export DB_DATABASE="${DB_DATABASE:-firefly}"
    export DB_USERNAME="${DB_USERNAME:-firefly}"
    export DB_PASSWORD="${DB_PASSWORD}"
    
    # Execute the original entrypoint script with all our environment variables
    exec /entrypoint.sh
else
    # Fallback to a simple PHP server if entrypoint.sh isn't available
    echo "🔄 Running database migrations..."
    cd /var/www/html
    php artisan migrate --force
    php artisan db:seed --force
    php artisan firefly-iii:upgrade-database
    
    # Create a healthcheck endpoint for Home Assistant
    mkdir -p /var/www/html/public/healthcheck
    cat > /var/www/html/public/healthcheck/index.php << 'EOF'
<?php
header('Content-Type: application/json');
echo json_encode(['status' => 'ok', 'timestamp' => time()]);
EOF
    
    echo "🚀 Starting PHP server..."
    exec php -S 0.0.0.0:8080 -t public
fi
