#!/usr/bin/env bash
set -e

# If we're in the Firefly III home assistant addon context
if [ -f /data/options.json ]; then
    # Load environment variables
    if [ -f /etc/firefly.env ]; then
        set -a
        source /etc/firefly.env
        set +a
        echo "Loaded environment from /etc/firefly.env"
    elif [ -f /data/firefly-iii.env ]; then
        set -a
        source /data/firefly-iii.env
        set +a
        echo "Loaded environment from /data/firefly-iii.env"
    fi

    # Ensure .env file exists
    if [ -f /data/firefly-iii.env ]; then
        cp /data/firefly-iii.env /var/www/html/.env
        echo "Copied /data/firefly-iii.env to /var/www/html/.env"
    fi

    # Force the environment variables
    if [ -f /data/app_key ]; then
        export APP_KEY=$(cat /data/app_key)
    fi
    export APP_ENV=production
    export DB_CONNECTION=mysql
    export DB_HOST=$(jq --raw-output '.db_host' /data/options.json)
    export DB_PORT=$(jq --raw-output '.db_port' /data/options.json)
    export DB_DATABASE=$(jq --raw-output '.db_name' /data/options.json)
    export DB_USERNAME=$(jq --raw-output '.db_user' /data/options.json)
    export DB_PASSWORD=$(jq --raw-output '.db_password' /data/options.json)
    
    # Ensure PHP has the session directory with proper permissions
    mkdir -p /var/www/html/storage/framework/sessions
    mkdir -p /var/www/html/storage/framework/views
    mkdir -p /var/www/html/storage/framework/cache
    mkdir -p /var/www/html/storage/logs
    chown -R www-data:www-data /var/www/html/storage
    chmod -R 775 /var/www/html/storage
    
    # Create a healthcheck endpoint for Home Assistant
    mkdir -p /var/www/html/public/healthcheck
    cat > /var/www/html/public/healthcheck/index.php << 'EOF'
<?php
header('Content-Type: application/json');
echo json_encode(['status' => 'ok', 'timestamp' => time()]);
EOF
    
    # Create ingress-friendly htaccess for direct PHP server
    cat > /var/www/html/public/.htaccess << 'EOF'
<IfModule mod_rewrite.c>
    <IfModule mod_negotiation.c>
        Options -MultiViews -Indexes
    </IfModule>

    RewriteEngine On

    # Handle ingress path
    RewriteCond %{HTTP:X-Ingress-Path} ^(.+)$
    RewriteRule ^ %1/ [L,R=301]

    # Handle Authorization Header
    RewriteCond %{HTTP:Authorization} .
    RewriteRule .* - [E=HTTP_AUTHORIZATION:%{HTTP:Authorization}]

    # Redirect Trailing Slashes If Not A Folder...
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_URI} (.+)/$
    RewriteRule ^ %1 [L,R=301]

    # Send Requests To Front Controller...
    RewriteCond %{REQUEST_FILENAME} !-d
    RewriteCond %{REQUEST_FILENAME} !-f
    RewriteRule ^ index.php [L]
</IfModule>
EOF

    # Try to run our specialized Firefly-III run script for Home Assistant
    if [ -f /firefly-iii/run.sh ]; then
        echo "Executing Firefly III addon run script"
        exec /firefly-iii/run.sh
    # Try to run the stock entrypoint with our environment
    elif [ -f /entrypoint.sh ]; then
        echo "Running stock entrypoint.sh with proper environment"
        exec /entrypoint.sh
    else
        echo "Starting PHP server directly (entrypoint.sh not found)"
        cd /var/www/html
        # Use -t public to set the document root to the public directory
        exec php -S 0.0.0.0:8080 -t public
    fi
else
    # Not in Home Assistant context, try default locations
    if [ -f /firefly-iii/run.sh ]; then
        echo "Executing /firefly-iii/run.sh"
        exec /firefly-iii/run.sh
    else
        echo "No specific run.sh found, starting web server"
        if [ -f /entrypoint.sh ]; then
            exec /entrypoint.sh
        else
            cd /var/www/html
            # Use -t public to set the document root to the public directory
            exec php -S 0.0.0.0:8080 -t public
        fi
    fi
fi
