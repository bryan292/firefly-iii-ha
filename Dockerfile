FROM fireflyiii/core:version-6.4.0

# Add bootstrap script with executable bit at copy-time (no chmod RUN needed)
COPY --chmod=0755 run.sh /usr/local/bin/ha-run.sh

# Add php-fpm pool override for Home Assistant
COPY zz-ha-user.conf /usr/local/etc/php-fpm.d/zz-ha-user.conf

# hadolint ignore=DL3002
# Home Assistant requires root for data directory permissions
USER 0

ENV HA_DATA_DIR=/data/firefly \
    APP_DIR=/var/www/html \
    PORT=8080 \
    PHP_FPM_USER=www-data \
    PHP_FPM_GROUP=www-data \
    S6_KEEP_ENV=1

EXPOSE 8080
ENTRYPOINT ["/usr/local/bin/ha-run.sh"]
