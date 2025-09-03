#!/bin/bash
set -e

CONFIG_PATH=/data/options.json
APP_KEY_OPT=$(jq --raw-output '.app_key // ""' $CONFIG_PATH)

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
        
        # Update .env file
        sed -i "s|APP_KEY=.*|APP_KEY=${NEW_APP_KEY}|" /var/www/html/.env
    fi
fi

# Ensure storage directories are writable
echo "Ensuring proper permissions on storage directories..."
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

# Run migrations
echo "Running database migrations..."
cd /var/www/html
php artisan migrate --force

echo "Bootstrap completed successfully"
