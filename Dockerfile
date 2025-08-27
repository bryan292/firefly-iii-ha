ARG BUILD_FROM=ghcr.io/hassio-addons/base:14.0.0

FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Set environment variables
ENV FIREFLY_III_VERSION=6.0.27
ENV FIREFLY_PATH=/var/www/html

# Install required packages
RUN apk add --no-cache \
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
    nginx \
    curl \
    supervisor \
    composer \
    netcat-openbsd

# Create directory structure
RUN mkdir -p ${FIREFLY_PATH}

# Download and install Firefly III
RUN curl -SL https://github.com/firefly-iii/firefly-iii/archive/v${FIREFLY_III_VERSION}.tar.gz | tar xzf - -C /tmp/ \
    && cp -r /tmp/firefly-iii-${FIREFLY_III_VERSION}/* ${FIREFLY_PATH}/ \
    && rm -rf /tmp/firefly-iii-${FIREFLY_III_VERSION}

# Make sure the correct PHP version is used for composer
RUN ln -sf /usr/bin/php82 /usr/bin/php

# Set PHP configuration 
RUN echo "memory_limit = 512M" > /etc/php82/conf.d/99-firefly.ini

# Install dependencies with ignore-platform-reqs to avoid extension issues
RUN cd ${FIREFLY_PATH} \
    && composer install --no-dev --no-interaction --ignore-platform-reqs \
    && rm -rf /root/.composer

# Prepare permissions
RUN chown -R nginx:nginx ${FIREFLY_PATH} \
    && chmod -R 775 ${FIREFLY_PATH}/storage

# Copy root filesystem
COPY rootfs /

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
