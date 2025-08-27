#!/usr/bin/with-contenv bashio
# ==============================================================================
# Home Assistant Add-on: Firefly III
# Configures NGINX
# ==============================================================================

# Generate Ingress configuration
bashio::var.json \
    interface "$(bashio::addon.ip_address)" \
    | tempio \
      -template /etc/nginx/templates/ingress.gtpl \
      -out /etc/nginx/http.d/ingress.conf

# Set correct permissions
chmod 755 /etc/nginx/http.d/ingress.conf
