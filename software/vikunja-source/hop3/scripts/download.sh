#!/bin/bash
set -eo pipefail
# Vikunja publishes no source release: this is the tag's archive, checked by a
# sha256 taken from it, not published by Vikunja.
VERSION="${VIKUNJA_VERSION:-0.24.6}"
SHA256="${VIKUNJA_SHA256:-d6c290a577dddb8f235e28b0f536773faff8f3ecce3460eb4c6e1691ae56cb13}"

echo "Downloading Vikunja v${VERSION} source..."
hop3-fetch --sha256 "$SHA256" -o vikunja-src.tar.gz \
  "https://github.com/go-vikunja/vikunja/archive/refs/tags/v${VERSION}.tar.gz"
tar xz --strip-components=1 -f vikunja-src.tar.gz
rm -f vikunja-src.tar.gz

mkdir -p files
echo "Vikunja source downloaded successfully"
