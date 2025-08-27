#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Firefly III
# Configures Firefly III
# ==============================================================================
declare admin_email
declare app_url
declare db_host
declare db_port
declare db_name
declare db_user
declare db_password
declare timezone
declare log_level
declare wait_timeout

# Make sure persistent data directory exists
mkdir -p /data/firefly-iii

# Make directory for env file
mkdir -p /var/www/html/storage/upload

# Get config
admin_email=$(bashio::config 'admin_email')
app_url=$(bashio::config 'app_url')
db_host=$(bashio::config 'database.host')
db_port=$(bashio::config 'database.port')
db_name=$(bashio::config 'database.database')
db_user=$(bashio::config 'database.username')
db_password=$(bashio::config 'database.password')
timezone=$(bashio::config 'timezone')
log_level=$(bashio::config 'log_level')

# If no app URL is provided, use the hassio ingress URL
if [[ -z "${app_url}" ]]; then
    app_url=$(bashio::addon.ingress_url)
fi

# Wait for database to be available
bashio::log.info "Waiting for database ${db_host}:${db_port} to be available..."
wait_timeout=30
while ! nc -z "${db_host}" "${db_port}" > /dev/null 2>&1; do
    wait_timeout=$((wait_timeout - 1))
    if [[ ${wait_timeout} -eq 0 ]]; then
        bashio::log.error "Database ${db_host}:${db_port} not available, timeout."
        exit 1
    fi
    sleep 1
done

# Setup environment file
cat > /var/www/html/.env << EOF
APP_ENV=production
APP_DEBUG=false
APP_KEY=
APP_URL=${app_url}
APP_LOG_LEVEL=${log_level}
APP_TIMEZONE=${timezone}

DB_CONNECTION=mysql
DB_HOST=${db_host}
DB_PORT=${db_port}
DB_DATABASE=${db_name}
DB_USERNAME=${db_user}
DB_PASSWORD=${db_password}

CACHE_DRIVER=file
SESSION_DRIVER=file
QUEUE_DRIVER=sync

MAIL_DRIVER=log
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_FROM=changeme@example.com
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null

TRUSTED_PROXIES=**

TZ=${timezone}
EOF

cd /var/www/html || exit

# Generate app key if not already set
if grep -q "APP_KEY=$" .env; then
    bashio::log.info "Generating app key..."
    php artisan key:generate --no-interaction
fi

# Run migrations
bashio::log.info "Running database migrations..."
php artisan migrate --no-interaction --force

# Create admin user if not exists
if php artisan firefly-iii:user:list | grep -q "${admin_email}"; then
    bashio::log.info "Admin user ${admin_email} already exists"
else
    bashio::log.info "Creating admin user ${admin_email}..."
    php artisan firefly-iii:create-admin "${admin_email}" --no-interaction
fi

# Set permissions
chown -R nginx:nginx /var/www/html
chmod -R 755 /var/www/html/storage
