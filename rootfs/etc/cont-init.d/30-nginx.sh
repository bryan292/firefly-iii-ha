#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Firefly III
# Configures NGINX for use with Firefly III
# ==============================================================================

# Create log directory with proper permissions first
mkdir -p /data/nginx/logs
chmod 777 /data
chmod 777 /data/nginx
chmod 777 /data/nginx/logs

# Now create the log files
touch /data/nginx/logs/error.log
touch /data/nginx/logs/access.log
chmod 666 /data/nginx/logs/error.log
chmod 666 /data/nginx/logs/access.log

# Get the server IP for debugging
addon_ip=$(bashio::addon.ip_address)
bashio::log.info "Add-on IP address: ${addon_ip}"

# Display network interfaces for debugging
bashio::log.info "Network interfaces:"
ip addr

# Remove any existing configuration to avoid conflicts
rm -f /etc/nginx/http.d/default.conf || true
rm -f /etc/nginx/http.d/direct.conf || true
rm -f /etc/nginx/http.d/ingress.conf || true

# Copy our configuration file directly instead of using templates
cp -f /etc/nginx/http.d/ingress.conf.sample /etc/nginx/http.d/ingress.conf || true
chmod 644 /etc/nginx/http.d/ingress.conf

# Create a test HTML file to verify Nginx is serving files
mkdir -p /var/www/html/public
echo "<html><body><h1>Nginx Test Page</h1><p>If you can see this, Nginx is working.</p></body></html>" > /var/www/html/public/test.html
chmod 644 /var/www/html/public/test.html
chown nginx:nginx /var/www/html/public/test.html

# Check if Nginx configuration is valid
bashio::log.info "Checking Nginx configuration..."
nginx -t && bashio::log.info "Nginx configuration complete" || bashio::log.warning "Nginx configuration test failed"
