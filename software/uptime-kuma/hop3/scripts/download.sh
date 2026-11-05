#!/bin/bash
set -e
# Pinned release tag, verified by checksum, built from source.
#
# Upstream publishes no build artifact for self-hosting outside Docker, and we
# would not use one anyway: the frontend is built here from the committed
# package-lock.json so the deployed tree is one we produced and can reproduce.
VERSION="${UPTIME_KUMA_VERSION:-2.4.0}"
SHA256="${UPTIME_KUMA_SHA256:-0ad39c4cbe2de5a2dd4869d02a8a4f0398b7b16217b0aeaff98d78cf37500c42}"
URL="https://github.com/louislam/uptime-kuma/archive/refs/tags/${VERSION}.tar.gz"

echo "Downloading Uptime Kuma v${VERSION} (source)..."
[ -n "$SHA256" ] || echo "Uptime Kuma: no UPTIME_KUMA_SHA256 pinned; source archive not verified." >&2
hop3-fetch --sha256 "$SHA256" -o uptime-kuma-src.tar.gz "$URL"

# --strip-components=1 would drop scripts/ from the recipe, so unpack the tag
# directory beside it and move its contents in.
tar xz -f uptime-kuma-src.tar.gz
rm -f uptime-kuma-src.tar.gz
src_dir="uptime-kuma-${VERSION}"
if [ ! -d "$src_dir" ]; then
    echo "Uptime Kuma archive did not contain the expected ${src_dir}/ directory." >&2
    exit 1
fi
# Copy over the recipe without clobbering scripts/ (the admin bootstrap lives there).
cp -a "$src_dir"/. .
rm -rf "$src_dir"

if [ ! -f package.json ] || [ ! -f package-lock.json ]; then
    echo "Uptime Kuma source lacks package.json / package-lock.json (npm ci would be unpinned)." >&2
    exit 1
fi

mkdir -p data
echo "Uptime Kuma downloaded successfully"
