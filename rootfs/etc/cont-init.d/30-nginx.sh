#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Firefly III
# Configures NGINX for use with Firefly III
# ==============================================================================

# Create log directory - avoid using chmod on /data
mkdir -p /var/log/nginx || true

# Now create the log files
touch /var/log/nginx/error.log || true
touch /var/log/nginx/access.log || true

# Get the server IP for debugging
addon_ip=$(bashio::addon.ip_address || echo "unknown")
bashio::log.info "Add-on IP address: ${addon_ip}"

# Display network interfaces for debugging
bashio::log.info "Network interfaces:"
ip addr || true

# Create temp directories but don't try to change ownership
mkdir -p /tmp/nginx/client_temp || true
mkdir -p /tmp/nginx/proxy_temp || true
mkdir -p /tmp/nginx/fastcgi_temp || true
mkdir -p /tmp/nginx/uwsgi_temp || true
mkdir -p /tmp/nginx/scgi_temp || true

# Remove any existing configuration to avoid conflicts
rm -f /etc/nginx/http.d/default.conf || true
rm -f /etc/nginx/http.d/direct.conf || true

# Create a minimal nginx configuration directly that uses root instead of nginx user
cat > /etc/nginx/nginx.conf << EOF
worker_processes auto;
pid /var/run/nginx.pid;
error_log /proc/1/fd/1 info;
include /etc/nginx/modules/*.conf;

# Run as root to avoid permission issues
user root;

events {
    worker_connections 1024;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;

    # Disable temp file ownership checks that cause permission errors
    disable_symlinks off;
    
    # Use temp directories with no specific ownership settings
    client_body_temp_path /tmp/nginx/client_temp;
    proxy_temp_path /tmp/nginx/proxy_temp;
    fastcgi_temp_path /tmp/nginx/fastcgi_temp;
    uwsgi_temp_path /tmp/nginx/uwsgi_temp;
    scgi_temp_path /tmp/nginx/scgi_temp;

    # Basic Settings
    sendfile on;
    tcp_nopush on;
    tcp_nodelay on;
    keepalive_timeout 65;
    types_hash_max_size 2048;
    server_tokens off;
    
    # Logging Settings
    access_log /proc/1/fd/1 combined;
    
    # Gzip Settings
    gzip on;
    gzip_disable "msie6";
    
    # Virtual Host Configs
    include /etc/nginx/http.d/*.conf;
}
EOF

# Check if Nginx configuration is valid
bashio::log.info "Checking Nginx configuration..."
nginx -t && bashio::log.info "Nginx configuration complete" || bashio::log.warning "Nginx configuration test failed"
