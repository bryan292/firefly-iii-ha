FROM fireflyiii/core:latest

# Create directory structure first
USER root
RUN mkdir -p /etc/cont-init.d /etc/services.d/app /etc/services.d/cron

# Install additional dependencies
RUN apt-get update && apt-get install -y \
    tini \
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

# Set environment variables
ENV TZ=UTC \
    PHP_MEMORY_LIMIT=512M \
    TRUSTED_PROXIES=**

# Expose port
EXPOSE 8080

# Use standard init instead of tini since fireflyiii/core already uses s6
CMD ["/run.sh"]
