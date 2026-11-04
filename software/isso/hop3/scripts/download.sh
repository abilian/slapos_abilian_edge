#!/bin/bash
set -e
# Pinned release tag, verified by checksum.
#
# This used to fetch `archive/refs/heads/master.tar.gz` — whatever the branch
# happened to be that day — while a VERSION variable sat unused next to it,
# implying a pin that did not exist. Two deploys of the same catalog serial
# installed different code, and an upstream regression would land silently on
# every node that redeployed.
VERSION="${ISSO_VERSION:-0.14.0}"
SHA256="${ISSO_SHA256:-ea2550be4a52b61c8bf2c9f94bd4e15ae8c366c35153918530668a7596ee5012}"
URL="https://github.com/isso-comments/isso/archive/refs/tags/${VERSION}.tar.gz"

echo "Downloading Isso v${VERSION}..."
[ -n "$SHA256" ] || echo "Isso: no ISSO_SHA256 pinned; source archive not verified." >&2
hop3-fetch --sha256 "$SHA256" -o isso-src.tar.gz "$URL"

tar xz --strip-components=1 -f isso-src.tar.gz
rm -f isso-src.tar.gz

# The client-side JS is committed upstream, so `pip install .` is the whole
# build. Assert it is there rather than discovering an assetless comment widget
# in a browser.
if [ ! -f isso/js/embed.js ]; then
    echo "Isso source lacks its bundled client JS (isso/js/embed.js)." >&2
    exit 1
fi

mkdir -p data
echo "Isso downloaded successfully"
