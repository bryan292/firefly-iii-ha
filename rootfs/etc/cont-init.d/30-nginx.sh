#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Firefly III
# Configures NGINX for use with Firefly III
# ==============================================================================

# Get the server IP for debugging
addon_ip=$(bashio::addon.ip_address || echo "unknown")
bashio::log.info "Add-on IP address: ${addon_ip}"

# Display network interfaces for debugging
bashio::log.info "Network interfaces:"
ip addr || true

# Create temp directories with proper structure in /tmp (which is writable)
mkdir -p /tmp/client_temp/0 /tmp/client_temp/1/1 /tmp/client_temp/1/2
mkdir -p /tmp/proxy_temp/0 /tmp/proxy_temp/1/1 /tmp/proxy_temp/1/2
mkdir -p /tmp/fastcgi_temp/0 /tmp/fastcgi_temp/1/1 /tmp/fastcgi_temp/1/2
mkdir -p /tmp/uwsgi_temp/0 /tmp/uwsgi_temp/1/1 /tmp/uwsgi_temp/1/2
mkdir -p /tmp/scgi_temp/0 /tmp/scgi_temp/1/1 /tmp/scgi_temp/1/2

# Create needed directories for logs - using /tmp instead
mkdir -p /tmp/nginx/logs

# Make sure Nginx can write to these directories in /tmp
chmod -R 777 /tmp/client_temp /tmp/proxy_temp /tmp/fastcgi_temp /tmp/uwsgi_temp /tmp/scgi_temp /tmp/nginx

# Remove any existing configuration to avoid conflicts
rm -f /etc/nginx/http.d/default.conf
rm -f /etc/nginx/http.d/direct.conf

# Create a symbolic link for Nginx error log to redirect to stdout
if [ -d "/var/lib/nginx/logs" ]; then
    rm -f /var/lib/nginx/logs/error.log 2>/dev/null || true
    ln -sf /proc/1/fd/2 /var/lib/nginx/logs/error.log 2>/dev/null || true
fi

# Create a simple nginx config in http.d with no ownership operations
cat > /etc/nginx/http.d/ingress.conf << EOF
server {
    listen 8099 default_server;
    listen 8080 default_server;
    
    root /var/www/html/public;
    index index.php;

    # Required for ingress
    absolute_redirect off;
    port_in_redirect off;

    client_max_body_size 100M;

    # Error and access logs to stdout/stderr instead of files
    error_log /proc/1/fd/2;
    access_log /proc/1/fd/1 combined;

    # Disable MIME type sniffing
    add_header X-Content-Type-Options "nosniff" always;
    
    # Disable iframe embedding except from same origin
    add_header X-Frame-Options "SAMEORIGIN" always;
    
    # Enable XSS protection
    add_header X-XSS-Protection "1; mode=block" always;
    
    # Disable search engine indexing
    add_header X-Robots-Tag none always;
    
    # Set referrer policy
    add_header Referrer-Policy "no-referrer-when-downgrade" always;
    
    # Enable cross-origin requests for Home Assistant ingress
    add_header Access-Control-Allow-Origin "*" always;
    add_header Access-Control-Allow-Methods "GET, POST, OPTIONS, PUT, DELETE, HEAD" always;
    add_header Access-Control-Allow-Headers "X-Requested-With, Content-Type, Authorization, Accept" always;

    # Laravel pretty URLs
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
        
        # Add support for OPTIONS preflight requests
        if (\$request_method = 'OPTIONS') {
            add_header 'Access-Control-Allow-Origin' '*' always;
            add_header 'Access-Control-Allow-Methods' 'GET, POST, OPTIONS, PUT, DELETE' always;
            add_header 'Access-Control-Allow-Headers' 'DNT,User-Agent,X-Requested-With,If-Modified-Since,Cache-Control,Content-Type,Range,Authorization' always;
            add_header 'Access-Control-Max-Age' 1728000 always;
            add_header 'Content-Type' 'text/plain; charset=utf-8' always;
            add_header 'Content-Length' 0 always;
            return 204;
        }
    }

    # Handle PHP files
    location ~ \.php$ {
        try_files \$uri =404;
        
        # Split path info from path
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        
        # Connect to php-fpm via TCP socket
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        
        # Include standard fastcgi parameters
        include fastcgi_params;
        
        # Ensure document root is properly set
        fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        fastcgi_param PATH_INFO \$fastcgi_path_info if_not_empty;
        fastcgi_param HTTP_PROXY "";
        
        # Pass ingress info for Firefly
        fastcgi_param HTTP_X_INGRESS "true";
        fastcgi_param HTTP_X_ORIGINAL_URL \$request_uri;
        
        # Pass request headers
        fastcgi_param HTTP_X_FORWARDED_HOST \$http_host;
        fastcgi_param HTTP_X_FORWARDED_PORT \$server_port;
        fastcgi_param HTTP_X_FORWARDED_PROTO \$scheme;
        
        # FastCGI settings
        fastcgi_connect_timeout 60;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
        fastcgi_buffer_size 128k;
        fastcgi_buffers 4 256k;
        fastcgi_busy_buffers_size 256k;
        fastcgi_temp_file_write_size 256k;
    }
    
    # Handle assets with proper caching
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires max;
        access_log off;
        log_not_found off;
        add_header Cache-Control "public, max-age=31536000" always;
    }
    
    # Block access to hidden files
    location ~ /\.(?!well-known) {
        deny all;
        access_log off;
        log_not_found off;
    }
}
EOF

# Try to make the Firefly III directory accessible but don't fail if not permitted
chmod -R 777 /var/www/html/storage 2>/dev/null || true
chmod -R 777 /var/www/html/bootstrap 2>/dev/null || true
chmod -R 777 /var/www/html/bootstrap/cache 2>/dev/null || true

# Check if Nginx configuration is valid
bashio::log.info "Checking Nginx configuration..."
nginx -t && bashio::log.info "Nginx configuration complete" || bashio::log.warning "Nginx configuration test failed"
