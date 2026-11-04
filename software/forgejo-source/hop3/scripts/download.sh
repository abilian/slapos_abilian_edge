#!/bin/bash
set -e
# Forgejo's source release, checked against the sha256 Forgejo publishes next to it.
# It vendors its Go modules and ships its built web assets, so `make backend`
# needs Go and nothing else from the network.
VERSION="${FORGEJO_VERSION:-14.0.3}"
SHA256="${FORGEJO_SHA256:-98410f3f2aa26d3b1e25f509a78854315f8b5a99b9f7b1c9d60f04db2c65c8c8}"

echo "Downloading Forgejo v${VERSION} source..."
hop3-fetch --sha256 "$SHA256" -o forgejo-src.tar.gz \
  "https://codeberg.org/forgejo/forgejo/releases/download/v${VERSION}/forgejo-src-${VERSION}.tar.gz"
tar xz --strip-components=1 -f forgejo-src.tar.gz
rm -f forgejo-src.tar.gz

mkdir -p custom/conf data
echo "Forgejo source downloaded successfully"
