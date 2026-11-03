#!/bin/bash
set -e
echo "Preparing Radicale..."
mkdir -p collections

# requirements.txt is COMMITTED alongside this script, not written here.
#
# It used to be generated with a single unpinned line (`radicale[bcrypt]`),
# which the Python toolchain rightly rejects as unreproducible — but because the
# file did not exist until build time, `hop3-catalog validate` could not see it
# and the broken blueprint shipped. A committed, pinned file is both
# reproducible and checkable before release.

echo "Radicale directories ready"
