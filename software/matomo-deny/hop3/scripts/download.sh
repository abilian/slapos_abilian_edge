#!/bin/bash
set -eo pipefail
VERSION="5.14.2"
echo "Downloading Matomo v${VERSION}..."
hop3-fetch "https://builds.matomo.org/matomo-${VERSION}.tar.gz" --sha256 769982163c1677cfd23490f20daffbaa6d0d39b32844399dbfbacba2457fefb7 | tar xz --strip-components=1
mkdir -p tmp/assets tmp/cache tmp/logs tmp/tcpdf tmp/templates_c
chmod -R 775 tmp config
echo "Matomo downloaded successfully"
