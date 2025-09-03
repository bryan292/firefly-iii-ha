#!/bin/bash
set -e

# If the firefly-iii run.sh exists, use that
if [ -f /run.sh ]; then
    exec /run.sh
else
    echo "Error: run.sh not found. Check your Docker build."
    exit 1
fi
