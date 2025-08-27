#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Firefly III
# Configures Firefly III
# ==============================================================================

# Get database configuration
DB_TYPE=$(bashio::config 'database_type')
DB_HOST=$(bashio::config 'database_host')
DB_PORT=$(bashio::config 'database_port')
DB_NAME=$(bashio::config 'database_name')
DB_USER=$(bashio::config 'database_username')
DB_PASS=$(bashio::config 'database_password')

if [ "$DB_TYPE" == "internal" ]; then
    # Make sure the database directory exists
    mkdir -p /data/mysql
    
    # Initialize MySQL data directory if it's empty
    if [ ! -d /data/mysql/mysql ]; then
        bashio::log.info "Initializing internal MySQL database..."
        mysql_install_db --datadir=/data/mysql
        
        # Start MySQL server
        service mysql start
        
        # Secure MySQL installation
        if [ -z "$DB_PASS" ]; then
            DB_PASS=$(< /dev/urandom tr -dc _A-Z-a-z-0-9 | head -c16)
            bashio::log.warning "No database password set, using a random one. Please set it in your add-on configuration."
        fi
        
        # Create database and user
        mysql -u root <<-EOSQL
            DELETE FROM mysql.user WHERE User='';
            DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
            DROP DATABASE IF EXISTS test;
            DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
            CREATE DATABASE firefly;
            CREATE USER 'firefly'@'localhost' IDENTIFIED BY '${DB_PASS}';
            GRANT ALL PRIVILEGES ON firefly.* TO 'firefly'@'localhost';
            FLUSH PRIVILEGES;
EOSQL
        
        # Stop MySQL server
        service mysql stop
    fi
    
    # Link MySQL data directory
    rm -rf /var/lib/mysql
    ln -s /data/mysql /var/lib/mysql
    
    # Set database connection parameters for internal MySQL
    DB_HOST="localhost"
    DB_PORT="3306"
    DB_NAME="firefly"
    DB_USER="firefly"
else
    # External database - disable internal MySQL service
    bashio::log.info "Using external MariaDB database"
    rm -f /etc/services.d/mysql/run
    
    # Check if MariaDB add-on is available
    if bashio::services.available "mysql"; then
        bashio::log.info "MariaDB service is available, using those credentials"
        if [ -z "$DB_HOST" ]; then
            DB_HOST=$(bashio::services "mysql" "host")
        fi
        if [ -z "$DB_PORT" ]; then
            DB_PORT=$(bashio::services "mysql" "port")
        fi
        if [ -z "$DB_USER" ]; then
            DB_USER=$(bashio::services "mysql" "username")
        fi
        if [ -z "$DB_PASS" ]; then
            DB_PASS=$(bashio::services "mysql" "password")
        fi
    fi
    
    # Create database on external MySQL if it doesn't exist
    if [ -n "$DB_HOST" ] && [ -n "$DB_PORT" ] && [ -n "$DB_USER" ] && [ -n "$DB_PASS" ]; then
        bashio::log.info "Creating database on external MySQL if it doesn't exist"
        
        # Wait for MySQL to be available
        COUNTER=0
        while ! mysqladmin ping -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" --silent; do
            sleep 1
            COUNTER=$((COUNTER + 1))
            if [ "$COUNTER" -gt 30 ]; then
                bashio::log.error "Could not connect to external MySQL server"
                exit 1
            fi
        done
        
        # Create database if it doesn't exist
        if [ -z "$DB_NAME" ]; then
            DB_NAME="firefly"
        fi
        
        mysql -h "$DB_HOST" -P "$DB_PORT" -u "$DB_USER" -p"$DB_PASS" <<-EOSQL
            CREATE DATABASE IF NOT EXISTS \`${DB_NAME}\`;
EOSQL
    else
        bashio::log.error "External database selected but connection details missing"
        exit 1
    fi
fi

# Create .env file for Firefly III
APP_KEY=$(bashio::config 'app_key')
if [ -z "$APP_KEY" ]; then
    APP_KEY=$(php -r "echo base64_encode(random_bytes(32));")
    bashio::log.warning "No app key set, using a random one. Please set it in your add-on configuration."
fi

TRUSTED_PROXIES=$(bashio::config 'trusted_proxies')

cat > /var/www/firefly-iii/.env <<EOL
APP_ENV=production
APP_DEBUG=false
APP_KEY=base64:${APP_KEY}
APP_URL=http://localhost:8080

DB_CONNECTION=mysql
DB_HOST=${DB_HOST}
DB_PORT=${DB_PORT}
DB_DATABASE=${DB_NAME}
DB_USERNAME=${DB_USER}
DB_PASSWORD=${DB_PASS}

BROADCAST_DRIVER=log
CACHE_DRIVER=file
QUEUE_CONNECTION=sync
SESSION_DRIVER=file
SESSION_LIFETIME=120

REDIS_HOST=127.0.0.1
REDIS_PASSWORD=null
REDIS_PORT=6379

MAIL_MAILER=log
MAIL_HOST=smtp.mailtrap.io
MAIL_PORT=2525
MAIL_USERNAME=null
MAIL_PASSWORD=null
MAIL_ENCRYPTION=null
MAIL_FROM_ADDRESS=null
MAIL_FROM_NAME="\${APP_NAME}"

TRUSTED_PROXIES=${TRUSTED_PROXIES}
EOL

# Set proper permissions
chown -R www-data:www-data /var/www/firefly-iii
chmod -R 775 /var/www/firefly-iii/storage
