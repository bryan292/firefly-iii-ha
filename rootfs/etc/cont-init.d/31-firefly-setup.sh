#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Firefly III
# Runs after MySQL is started to finalize Firefly setup
# ==============================================================================

# Check database type
DB_TYPE=$(bashio::config 'database_type')

if [ "$DB_TYPE" == "internal" ]; then
    # Wait for MySQL to be ready
    bashio::log.info "Waiting for internal MySQL to be ready..."
    while ! mysqladmin ping -h localhost --silent; do
        sleep 1
    done
else
    # External database
    DB_HOST=$(bashio::config 'database_host')
    DB_PORT=$(bashio::config 'database_port')
    DB_USER=$(bashio::config 'database_username')
    DB_PASS=$(bashio::config 'database_password')
    
    # Wait for external MySQL to be ready
    bashio::log.info "Waiting for external MySQL to be ready..."
    COUNTER=0
    while ! mysqladmin ping -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --silent; do
        sleep 1
        COUNTER=$((COUNTER + 1))
        if [ "$COUNTER" -gt 30 ]; then
            bashio::log.error "Could not connect to external MySQL server"
            exit 1
        fi
    done
fi

# Navigate to Firefly III directory
cd /var/www/firefly-iii

# Run the database migrations
bashio::log.info "Running database migrations..."
php artisan migrate --seed --force

# Clear caches
bashio::log.info "Clearing caches..."
php artisan cache:clear
php artisan config:clear
php artisan route:clear
php artisan view:clear

# Set up storage links
bashio::log.info "Setting up storage links..."
php artisan storage:link

# Generate encryption keys if needed
php artisan firefly-iii:verify-security-features

# Fix permissions again after all operations
chown -R www-data:www-data /var/www/firefly-iii
chmod -R 775 /var/www/firefly-iii/storage

bashio::log.info "Firefly III setup completed!"
