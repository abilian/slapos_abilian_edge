#!/bin/bash
# Download Kanboard source

set -eo pipefail

KANBOARD_VERSION="${KANBOARD_VERSION:-1.2.37}"
DOWNLOAD_URL="https://github.com/kanboard/kanboard/archive/refs/tags/v${KANBOARD_VERSION}.tar.gz"

echo "Downloading Kanboard v${KANBOARD_VERSION}..."

# Download and extract (strip the top-level directory)
hop3-fetch "$DOWNLOAD_URL" | tar xz --strip-components=1

# Create necessary directories if they don't exist
mkdir -p data plugins

echo "Kanboard source downloaded successfully"
