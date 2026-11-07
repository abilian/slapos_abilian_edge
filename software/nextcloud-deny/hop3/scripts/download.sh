#!/bin/bash
set -eo pipefail
VERSION="35.0.2"
echo "Downloading Nextcloud v${VERSION}..."
# The zip, since a SlapOS build has unzip and no bzip2.
hop3-fetch "https://download.nextcloud.com/server/releases/nextcloud-${VERSION}.zip" -o nextcloud.zip --sha256 2f1dcec6a7cdab70346e80a823ccaaa2001a6085013d9f2ae0a2606fa38c2835
unzip -q nextcloud.zip
rm nextcloud.zip
shopt -s dotglob
mv nextcloud/* .
rmdir nextcloud
mkdir -p data custom_apps
chmod 750 data config
echo "Nextcloud downloaded successfully"
