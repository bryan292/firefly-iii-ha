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

# Create directory structure
RUN mkdir -p ${FIREFLY_PATH}

# Download and install a specific version of Firefly III
RUN curl -SL https://github.com/firefly-iii/firefly-iii/archive/v${FIREFLY_III_VERSION}.tar.gz | tar xzf - -C /tmp/ && \
    cp -r /tmp/firefly-iii-${FIREFLY_III_VERSION}/* ${FIREFLY_PATH}/ && \
    rm -rf /tmp/firefly-iii-${FIREFLY_III_VERSION}

# Make sure the correct PHP version is used for composer
RUN ln -sf /usr/bin/php82 /usr/bin/php

# Set PHP configuration 
RUN echo "memory_limit = 512M" > /etc/php82/conf.d/99-firefly.ini

# Install dependencies with ignore-platform-reqs to avoid extension issues
RUN cd ${FIREFLY_PATH} && \
    IGNORE_FLAGS="--ignore-platform-req=php --ignore-platform-req=ext-bcmath --ignore-platform-req=ext-fileinfo --ignore-platform-req=ext-intl --ignore-platform-req=ext-pdo --ignore-platform-req=ext-session --ignore-platform-req=ext-simplexml --ignore-platform-req=ext-sodium --ignore-platform-req=ext-tokenizer --ignore-platform-req=ext-xml --ignore-platform-req=ext-xmlwriter --ignore-platform-req=ext-dom" && \
    composer install --no-dev --no-interaction --no-scripts $IGNORE_FLAGS && \
    composer dump-autoload --optimize $IGNORE_FLAGS && \
    rm -rf /root/.composer

# Fix bootstrap/app.php to handle missing bcscale
RUN cd ${FIREFLY_PATH} && \
    sed -i '35s/bcscale(12)/function_exists("bcscale") ? bcscale(12) : null/' bootstrap/app.php || true

# Create required directories
RUN mkdir -p ${FIREFLY_PATH}/storage/upload && \
    mkdir -p ${FIREFLY_PATH}/storage/framework/cache && \
    mkdir -p ${FIREFLY_PATH}/storage/framework/sessions && \
    mkdir -p ${FIREFLY_PATH}/storage/framework/views && \
    mkdir -p ${FIREFLY_PATH}/storage/logs

# Prepare permissions
RUN chown -R nginx:nginx ${FIREFLY_PATH} \
    && chmod -R 775 ${FIREFLY_PATH}/storage

# Copy root filesystem
COPY rootfs /

# Set execute permissions on all scripts
RUN chmod -R a+x /etc/cont-init.d && \
    chmod -R a+x /etc/services.d

# Configure nginx
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
    maintainer="Your Name <your.email@example.com>" \
    org.opencontainers.image.title="${BUILD_NAME}" \
    org.opencontainers.image.description="${BUILD_DESCRIPTION}" \
    org.opencontainers.image.vendor="Home Assistant Add-ons" \
    org.opencontainers.image.authors="Your Name <your.email@example.com>" \
    org.opencontainers.image.licenses="MIT" \
    org.opencontainers.image.url="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
