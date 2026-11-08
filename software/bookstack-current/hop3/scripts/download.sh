#!/bin/bash
set -eo pipefail
VERSION="26.09.2"
echo "Downloading BookStack v${VERSION}..."
hop3-fetch "https://github.com/BookStackApp/BookStack/archive/refs/tags/v${VERSION}.tar.gz" --sha256 63d6be10b6d2db89a5f82c439e478480fc12daaaca0de9a88a700b583e1d2c65 | tar xz --strip-components=1
mkdir -p storage/app storage/framework/{cache,sessions,views} storage/logs bootstrap/cache
chmod -R 775 storage bootstrap/cache
echo "BookStack downloaded successfully"
