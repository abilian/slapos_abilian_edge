#!/bin/bash
set -e
VERSION="${LIMESURVEY_VERSION:-6.16.10}"
DATE_SUFFIX="${LIMESURVEY_DATE:-260223}"
echo "Downloading LimeSurvey v${VERSION}..."
# Download from official LimeSurvey site
hop3-fetch "https://download.limesurvey.org/latest-master/limesurvey${VERSION}+${DATE_SUFFIX}.zip" -o limesurvey.zip
unzip -q limesurvey.zip
# The archive unpacks to one directory. A move that fails must stop the build:
# it used to end in `|| true`, which left the app without its tmp/ and upload/
# and failed later, at the first console command, far from the cause.
unpacked=$(find . -maxdepth 1 -type d -name 'limesurvey*' | head -1)
[ -n "$unpacked" ] || { echo "LimeSurvey: the archive unpacked no limesurvey*/ directory" >&2; exit 1; }
mv "$unpacked"/* .
rm -rf "$unpacked" limesurvey.zip
mkdir -p tmp upload
chmod 755 tmp upload
echo "LimeSurvey downloaded successfully"
