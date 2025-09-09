# Minimal wrapper to inject HA-specific bootstrap; reuse official image
FROM fireflyiii/core:latest

# Add our bootstrap script(s)
COPY run.sh /usr/local/bin/ha-run.sh
RUN chmod +x /usr/local/bin/ha-run.sh

# Install jq for parsing options.json
RUN apt-get update && apt-get install -y jq && apt-get clean && rm -rf /var/lib/apt/lists/*

# Ensure a writable data volume inside the container mapped to HA /data
# We'll store .env and storage here, then symlink into the app dir.
ENV HA_DATA_DIR=/data/firefly \
    APP_DIR=/var/www/html \
    PORT=8080

EXPOSE 8080
# Use our wrapper which will prep .env/storage then hand off to the upstream entrypoint
ENTRYPOINT ["/usr/local/bin/ha-run.sh"]
