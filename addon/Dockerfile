FROM fireflyiii/core:latest

# Install additional dependencies
RUN apt-get update && apt-get install -y \
    tini \
    cron \
    bash \
    jq \
    netcat-openbsd \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copy rootfs
COPY rootfs /

# Copy run script
COPY run.sh /run.sh
RUN chmod +x /run.sh

# Set environment variables
ENV TZ=UTC \
    PHP_MEMORY_LIMIT=512M \
    TRUSTED_PROXIES=**

# Expose port
EXPOSE 8080

# Use tini as init
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD ["/bin/bash", "/run.sh"]
