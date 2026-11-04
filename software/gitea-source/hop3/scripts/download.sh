#!/bin/bash
set -e
# Gitea's source release, checked against the sha256 Gitea publishes next to it.
# It vendors its Go modules and ships its built web assets, so `make backend`
# needs Go and nothing else from the network.
VERSION="${GITEA_VERSION:-1.21.4}"
SHA256="${GITEA_SHA256:-6e4448da6eda1eb407e7041b9b8328ca0ac5e5d6bb8f88bc41dfdaa0c25b852d}"

echo "Downloading Gitea v${VERSION} source..."
hop3-fetch --sha256 "$SHA256" -o gitea-src.tar.gz \
  "https://dl.gitea.com/gitea/${VERSION}/gitea-src-${VERSION}.tar.gz"
tar xz --strip-components=1 -f gitea-src.tar.gz
rm -f gitea-src.tar.gz

mkdir -p custom/conf data
echo "Gitea source downloaded successfully"
