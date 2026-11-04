#!/bin/bash
set -eo pipefail
# Mattermost publishes no source release: this is the tag's archive, checked by a
# sha256 taken from it, not published by Mattermost.
VERSION="${MATTERMOST_VERSION:-9.4.2}"
SHA256="${MATTERMOST_SHA256:-84e0fdf3100bfa044e3bbf79ff7c8204ceceb236e9e477e33ae2f5b105065854}"

echo "Downloading Mattermost v${VERSION} source..."
hop3-fetch --sha256 "$SHA256" -o mattermost-src.tar.gz \
  "https://github.com/mattermost/mattermost/archive/refs/tags/v${VERSION}.tar.gz"
tar xz --strip-components=1 -f mattermost-src.tar.gz
rm -f mattermost-src.tar.gz

mkdir -p data logs config plugins client/plugins
echo "Mattermost source downloaded successfully"
