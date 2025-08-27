ARG BUILD_FROM
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Install required packages
RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        nginx \
        mariadb-server \
        mariadb-client \
        php-fpm \
        php-cli \
        php-common \
        php-curl \
        php-zip \
        php-gd \
        php-mbstring \
        php-xml \
        php-bcmath \
        php-mysql \
        php-intl \
        php-ldap \
        php-gmp \
        composer \
        curl \
        unzip \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Set working directory
WORKDIR /var/www

# Download and install Firefly III
RUN curl -L -o firefly-iii.zip https://github.com/firefly-iii/firefly-iii/archive/refs/tags/v6.0.24.zip \
    && unzip firefly-iii.zip \
    && rm firefly-iii.zip \
    && mv firefly-iii-6.0.24 firefly-iii \
    && cd firefly-iii \
    && composer install --no-dev --no-interaction \
    && chown -R www-data:www-data /var/www/firefly-iii \
    && chmod -R 775 /var/www/firefly-iii/storage

# Copy configurations
COPY rootfs /

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
    org.opencontainers.image.url="https://addons.community" \
    org.opencontainers.image.source="https://github.com/${BUILD_REPOSITORY}" \
    org.opencontainers.image.documentation="https://github.com/${BUILD_REPOSITORY}/blob/main/README.md" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
