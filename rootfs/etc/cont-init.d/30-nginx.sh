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

# Create temp directories with proper permissions for nobody user
mkdir -p /tmp/nginx/client_temp || true
mkdir -p /tmp/nginx/proxy_temp || true
mkdir -p /tmp/nginx/fastcgi_temp || true
mkdir -p /tmp/nginx/uwsgi_temp || true
mkdir -p /tmp/nginx/scgi_temp || true

# Set very permissive permissions on temp directories
chmod -R 777 /tmp/nginx || true

# Also ensure /var/lib/nginx is writable
mkdir -p /var/lib/nginx/logs || true
chmod -R 777 /var/lib/nginx || true

# Make web root writable
chmod -R 777 /var/www || true

# Remove any existing configuration to avoid conflicts
rm -f /etc/nginx/http.d/default.conf || true
rm -f /etc/nginx/http.d/direct.conf || true

# Check if Nginx configuration is valid
bashio::log.info "Checking Nginx configuration..."
nginx -t && bashio::log.info "Nginx configuration complete" || bashio::log.warning "Nginx configuration test failed"
