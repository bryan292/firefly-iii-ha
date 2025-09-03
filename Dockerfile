FROM fireflyiii/core:latest

# Create directory structure first
USER root

# Install additional dependencies
RUN apt-get update && apt-get install -y \
    cron \
    bash \
    jq \
    netcat-openbsd \
    openssl \
    php8.2-fpm \
    nginx \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy rootfs if it exists
COPY firefly-iii/rootfs/ /
COPY addon/rootfs/ /

# Copy run script
COPY firefly-iii/run.sh /run.sh
RUN chmod +x /run.sh

# Ensure directories are writable
RUN mkdir -p /data && \
    chmod -R 755 /etc/cont-init.d /etc/services.d || true && \
    find /etc/cont-init.d -type f -exec chmod +x {} \; || true && \
    find /etc/services.d -name run -exec chmod +x {} \; || true

# Fix PHP-FPM configuration if it exists
RUN for php_ver in 5 7 8; do \
        for conf in $(find /etc/php -name "www.conf" 2>/dev/null); do \
            sed -i 's/;user = .*/user = www-data/g' $conf; \
            sed -i 's/;group = .*/group = www-data/g' $conf; \
            echo "Updated PHP-FPM config: $conf"; \
        done; \
    done || echo "No PHP-FPM configs found to update"

# Fix storage directory permissions
RUN mkdir -p /var/www/html/storage/app \
    /var/www/html/storage/framework/cache \
    /var/www/html/storage/framework/sessions \
    /var/www/html/storage/framework/views \
    /var/www/html/storage/logs && \
    chown -R www-data:www-data /var/www/html/storage || true && \
    chmod -R 775 /var/www/html/storage || true

# Set environment variables
ENV TZ=UTC \
    PHP_MEMORY_LIMIT=512M \
    TRUSTED_PROXIES=** \
    MAIL_MAILER=log \
    MAIL_FROM=changeme@example.com \
    SITE_OWNER=changeme@example.com \
    APP_ENV=production \
    APP_DEBUG=false

# Create necessary directories for nginx
RUN mkdir -p /var/log/nginx /run/nginx /tmp/nginx

# Expose port
EXPOSE 8080

# Use the run.sh script as entrypoint
CMD ["/run.sh"]
