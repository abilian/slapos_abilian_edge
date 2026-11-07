#!/bin/bash
# Download WordPress

set -eo pipefail

WP_VERSION="7.1.4"
WP_SHA256="881e53a4681ff2cd911651b11cccdede5ae477ddf0765af5d6a1a8b219a1d835"
DOWNLOAD_URL="https://wordpress.org/wordpress-${WP_VERSION}.tar.gz"

echo "Downloading WordPress v${WP_VERSION}..."

# Download and extract (strip the top-level directory)
hop3-fetch "$DOWNLOAD_URL" --sha256 "$WP_SHA256" | tar xz --strip-components=1

# Create wp-content directories with proper permissions
mkdir -p wp-content/uploads wp-content/plugins wp-content/themes
chmod 755 wp-content wp-content/uploads wp-content/plugins wp-content/themes

echo "WordPress downloaded successfully"
