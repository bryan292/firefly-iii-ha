#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Firefly III
# Configures NGINX for use with Firefly III
# ==============================================================================

# Create log directory with proper permissions first - avoid using chmod on /data
mkdir -p /data/nginx/logs || true

# Now create the log files with proper permissions
touch /data/nginx/logs/error.log 2>/dev/null || true
touch /data/nginx/logs/access.log 2>/dev/null || true

# Get the server IP for debugging
addon_ip=$(bashio::addon.ip_address || echo "unknown")
bashio::log.info "Add-on IP address: ${addon_ip}"

# Display network interfaces for debugging
bashio::log.info "Network interfaces:"
ip addr || true

# Remove any existing configuration to avoid conflicts
rm -f /etc/nginx/http.d/default.conf 2>/dev/null || true
rm -f /etc/nginx/http.d/direct.conf 2>/dev/null || true
rm -f /etc/nginx/http.d/ingress.conf 2>/dev/null || true

# Create a minimal nginx configuration directly
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

    # Error and access logs
    error_log /proc/1/fd/1 info;
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

    # Enable gzip compression
    gzip on;
    gzip_vary on;
    gzip_proxied any;
    gzip_comp_level 6;
    gzip_types text/plain text/css text/xml application/json application/javascript application/xml+rss application/atom+xml image/svg+xml;

    # Laravel pretty URLs
    location / {
        try_files \$uri \$uri/ /index.php?\$query_string;
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
        
        # FastCGI settings
        fastcgi_connect_timeout 60;
        fastcgi_send_timeout 300;
        fastcgi_read_timeout 300;
    }
    
    # Handle assets with proper caching
    location ~* \.(css|js|jpg|jpeg|png|gif|ico|svg|woff|woff2|ttf|eot)$ {
        expires max;
        access_log off;
        log_not_found off;
        try_files \$uri \$uri/ /index.php?\$query_string;
    }
}
EOF

# Create a test HTML file to verify Nginx is serving files
mkdir -p /var/www/html/public 2>/dev/null || true
echo "<html><body><h1>Nginx Test Page</h1><p>If you can see this, Nginx is working.</p></body></html>" > /var/www/html/public/test.html 2>/dev/null || true

# Check if Nginx configuration is valid
bashio::log.info "Checking Nginx configuration..."
nginx -t && bashio::log.info "Nginx configuration complete" || bashio::log.warning "Nginx configuration test failed"
