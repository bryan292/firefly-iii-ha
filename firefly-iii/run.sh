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

# Create a minimal nginx configuration if nginx is installed but config is missing
if [ -x "$(command -v nginx)" ] && [ ! -f /etc/nginx/nginx.conf ]; then
    mkdir -p /etc/nginx/conf.d
    
    # Create a basic nginx.conf
    cat > /etc/nginx/nginx.conf <<'EOF'
worker_processes auto;
pid /tmp/nginx.pid;
error_log /dev/stderr info;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    
    access_log /dev/stdout;
    
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    
    server {
        listen 8080 default_server;
        root /var/www/html/public;
        index index.php index.html;
        
        location / {
            try_files $uri $uri/ /index.php?$query_string;
        }
        
        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
            fastcgi_pass 127.0.0.1:9000;
        }
    }
}
EOF

    # Create a mime.types file if it doesn't exist
    if [ ! -f /etc/nginx/mime.types ]; then
        cat > /etc/nginx/mime.types <<'EOF'
types {
    text/html                             html htm shtml;
    text/css                              css;
    text/xml                              xml;
    image/gif                             gif;
    image/jpeg                            jpeg jpg;
    application/javascript                js;
    application/json                      json;
    image/png                             png;
    image/svg+xml                         svg svgz;
    application/font-woff                 woff;
    application/font-woff2                woff2;
    application/pdf                       pdf;
}
EOF
    fi

    # Create fastcgi_params if it doesn't exist
    if [ ! -f /etc/nginx/fastcgi_params ]; then
        cat > /etc/nginx/fastcgi_params <<'EOF'
fastcgi_param  QUERY_STRING       $query_string;
fastcgi_param  REQUEST_METHOD     $request_method;
fastcgi_param  CONTENT_TYPE       $content_type;
fastcgi_param  CONTENT_LENGTH     $content_length;
fastcgi_param  SCRIPT_NAME        $fastcgi_script_name;
fastcgi_param  REQUEST_URI        $request_uri;
fastcgi_param  DOCUMENT_URI       $document_uri;
fastcgi_param  DOCUMENT_ROOT      $document_root;
fastcgi_param  SERVER_PROTOCOL    $server_protocol;
fastcgi_param  REQUEST_SCHEME     $scheme;
fastcgi_param  HTTPS              $https if_not_empty;
fastcgi_param  GATEWAY_INTERFACE  CGI/1.1;
fastcgi_param  SERVER_SOFTWARE    nginx/$nginx_version;
fastcgi_param  REMOTE_ADDR        $remote_addr;
fastcgi_param  REMOTE_PORT        $remote_port;
fastcgi_param  SERVER_ADDR        $server_addr;
fastcgi_param  SERVER_PORT        $server_port;
fastcgi_param  SERVER_NAME        $server_name;
fastcgi_param  REDIRECT_STATUS    200;
EOF
    fi

    echo "Created minimal Nginx configuration"
fi

# Define function to start PHP-FPM if it exists
start_php_fpm() {
    if [ -x "$(command -v php-fpm)" ]; then
        echo "Starting PHP-FPM..."
        php-fpm -D
    elif [ -x "$(command -v php-fpm7)" ]; then
        echo "Starting PHP-FPM7..."
        php-fpm7 -D
    elif [ -x "$(command -v php-fpm8)" ]; then
        echo "Starting PHP-FPM8..."
        php-fpm8 -D
    else
        echo "PHP-FPM not found, using built-in server instead"
        return 1
    fi
    return 0
}

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
elif [ -x "$(command -v nginx)" ] && start_php_fpm; then
    echo "Starting Nginx web server"
    exec nginx -g "daemon off;"
elif [ -f /var/www/html/artisan ]; then
    echo "Starting Laravel application with built-in server"
    start_application
else
    echo "ERROR: Cannot find Firefly III application"
    ls -la /var/www/html || echo "No /var/www/html directory"
    exit 1
fi
