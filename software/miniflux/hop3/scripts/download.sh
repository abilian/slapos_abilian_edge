#!/bin/bash
# Download Miniflux source

set -eo pipefail

MINIFLUX_VERSION="${MINIFLUX_VERSION:-2.1.1}"
DOWNLOAD_URL="https://github.com/miniflux/v2/archive/refs/tags/${MINIFLUX_VERSION}.tar.gz"

echo "Downloading Miniflux v${MINIFLUX_VERSION}..."

# Download and extract (strip the top-level directory)
hop3-fetch "$DOWNLOAD_URL" | tar xz --strip-components=1

echo "Miniflux source downloaded successfully"
