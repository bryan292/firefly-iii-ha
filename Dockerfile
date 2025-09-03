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
    APP_DEBUG=false \
    DISABLE_DEMO_USER=true \
    CACHE_DRIVER=file \
    SESSION_DRIVER=file \
    ALLOW_CORS=true

# Expose port
EXPOSE 8080

# Use the run.sh script as entrypoint
CMD ["/run.sh"]
