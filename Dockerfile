ARG BUILD_FROM=ghcr.io/hassio-addons/base:14.0.0

FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set environment variables
ENV FIREFLY_PATH=/var/www/html
ENV FIREFLY_III_VERSION=6.0.30

# Install required packages
RUN apk update && \
    apk add --no-cache \
        php82 \
        php82-fpm \
        php82-pdo \
        php82-pdo_mysql \
        php82-mysqli \
        php82-json \
        php82-openssl \
        php82-curl \
        php82-zlib \
        php82-xml \
        php82-phar \
        php82-intl \
        php82-dom \
        php82-xmlreader \
        php82-ctype \
        php82-session \
        php82-mbstring \
        php82-gmp \
        php82-simplexml \
        php82-tokenizer \
        php82-fileinfo \
        php82-iconv \
        php82-zip \
        php82-bcmath \
        php82-sodium \
        php82-gd \
        php82-pcntl \
        php82-posix \
        php82-xmlwriter \
        mysql-client \
        nginx \
        curl \
        supervisor \
        composer \
        netcat-openbsd \
        jq \
        git

# Create required directories and set permissions
RUN mkdir -p ${FIREFLY_PATH} && \
    mkdir -p /data/nginx/logs && \
    mkdir -p /data/firefly-iii && \
    # Create directory structure with necessary permissions
    mkdir -p ${FIREFLY_PATH}/storage/app/public && \
    mkdir -p ${FIREFLY_PATH}/storage/framework/cache && \
    mkdir -p ${FIREFLY_PATH}/storage/framework/sessions && \
    mkdir -p ${FIREFLY_PATH}/storage/framework/views && \
    mkdir -p ${FIREFLY_PATH}/storage/logs && \
    mkdir -p ${FIREFLY_PATH}/bootstrap/cache && \
    # Set very permissive permissions for add-on container environment
    chmod -R 777 ${FIREFLY_PATH} && \
    chmod -R 777 /data

# Download and install a specific version of Firefly III
RUN curl -SL https://github.com/firefly-iii/firefly-iii/archive/v${FIREFLY_III_VERSION}.tar.gz | tar xzf - -C /tmp/ && \
    cp -r /tmp/firefly-iii-${FIREFLY_III_VERSION}/* ${FIREFLY_PATH}/ && \
    rm -rf /tmp/firefly-iii-${FIREFLY_III_VERSION}

# Make sure the correct PHP version is used for composer
RUN ln -sf /usr/bin/php82 /usr/bin/php

# Set PHP configuration 
RUN echo "memory_limit = 512M" > /etc/php82/conf.d/99-firefly.ini && \
    echo "user = root" >> /etc/php82/php-fpm.d/www.conf && \
    echo "group = root" >> /etc/php82/php-fpm.d/www.conf

# Install dependencies with ignore-platform-reqs to avoid extension issues
RUN cd ${FIREFLY_PATH} && \
    IGNORE_FLAGS="--ignore-platform-req=php --ignore-platform-req=ext-bcmath --ignore-platform-req=ext-fileinfo --ignore-platform-req=ext-intl --ignore-platform-req=ext-pdo --ignore-platform-req=ext-session --ignore-platform-req=ext-simplexml --ignore-platform-req=ext-sodium --ignore-platform-req=ext-tokenizer --ignore-platform-req=ext-xml --ignore-platform-req=ext-xmlwriter --ignore-platform-req=ext-dom" && \
    composer install --no-dev --no-interaction --no-scripts $IGNORE_FLAGS && \
    composer dump-autoload --optimize $IGNORE_FLAGS && \
    rm -rf /root/.composer

# Fix bootstrap/app.php to handle missing bcscale
RUN cd ${FIREFLY_PATH} && \
    sed -i '35s/bcscale(12)/function_exists("bcscale") ? bcscale(12) : null/' bootstrap/app.php || true

# Prepare Nginx configuration sample
RUN mkdir -p /etc/nginx/http.d && \
    cat > /etc/nginx/http.d/ingress.conf.sample << 'EOT'
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

    # Laravel pretty URLs
    location / {
        try_files $uri $uri/ /index.php?$query_string;
    }

    # Handle PHP files
    location ~ \.php$ {
        try_files $uri =404;
        
        # Split path info from path
        fastcgi_split_path_info ^(.+?\.php)(/.*)$;
        
        # Connect to php-fpm via TCP socket
        fastcgi_pass 127.0.0.1:9000;
        fastcgi_index index.php;
        
        # Include standard fastcgi parameters
        include fastcgi_params;
        
        # Ensure document root is properly set
        fastcgi_param SCRIPT_FILENAME $document_root$fastcgi_script_name;
        fastcgi_param PATH_INFO $fastcgi_path_info if_not_empty;
    }
}
EOT

# Set permissive permissions for all critical directories
RUN chmod -R 777 ${FIREFLY_PATH} && \
    chmod -R 777 /data && \
    chmod -R 777 /etc/nginx && \
    chmod 777 /etc/nginx/http.d/ingress.conf.sample

# Copy root filesystem
COPY rootfs /

# Set execute permissions on all scripts
RUN chmod -R a+x /etc/cont-init.d && \
    chmod -R a+x /etc/services.d

# Remove default Nginx configuration
RUN rm -f /etc/nginx/http.d/default.conf

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_DESCRIPTION
ARG BUILD_NAME
ARG BUILD_REF
ARG BUILD_REPOSITORY
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="${BUILD_NAME}" \
    io.hass.description="${BUILD_DESCRIPTION}" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="Bryan <github@example.com>" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Home Assistant Add-ons" \
    org.opencontainers.image.authors="Bryan <github@example.com>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
