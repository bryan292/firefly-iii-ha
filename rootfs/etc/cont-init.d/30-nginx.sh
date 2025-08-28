#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Firefly III
# Configures NGINX
# ==============================================================================

# Get the addon IP address for proper interface binding
ADDON_IP=$(bashio::addon.ip_address)
bashio::log.info "Add-on IP address: ${ADDON_IP}"

# Display network interfaces for debugging
bashio::log.info "Network interfaces:"
ip addr

# Remove any existing configuration to avoid conflicts
rm -f /etc/nginx/http.d/default.conf
rm -f /etc/nginx/http.d/direct.conf
rm -f /etc/nginx/http.d/ingress.conf

# Generate Ingress configuration with proper IP binding
bashio::var.json \
    interface "${ADDON_IP}" \
    | tempio \
      -template /etc/nginx/templates/ingress.gtpl \
      -out /etc/nginx/http.d/ingress.conf

# Ensure directories exist with proper permissions
mkdir -p /data/nginx/logs
touch /data/nginx/logs/error.log
touch /data/nginx/logs/access.log
chmod 644 /data/nginx/logs/*.log
chown -R nginx:nginx /data/nginx

# Create a test HTML file to verify Nginx is serving files
mkdir -p /var/www/html/public
echo "<html><body><h1>Nginx Test Page</h1><p>If you can see this, Nginx is working.</p></body></html>" > /var/www/html/public/test.html
chmod 644 /var/www/html/public/test.html
chown nginx:nginx /var/www/html/public/test.html

# Check if Nginx configuration is valid
bashio::log.info "Checking Nginx configuration..."
nginx -t || bashio::log.warning "Nginx configuration test failed"

# Set correct permissions
chmod 644 /etc/nginx/http.d/ingress.conf

# Log completion
bashio::log.info "Nginx configuration complete"
