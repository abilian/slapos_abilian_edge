#!/bin/bash
# Download Keycloak. Use the system JVM; fetch one only if it is too old.
#
# Keycloak is Java: its distribution tarball is architecture-neutral and there
# is nothing here that needs to match the host's CPU. The JRE download was the
# only arch-specific thing in this recipe, and it existed as a workaround —
# `[build].packages` could not get `openjdk-21-jdk` installed, and the installer
# shipped `default-jdk`, which is JDK 17 on Debian bookworm while Keycloak 26
# needs 21.
#
# That workaround is what broke on arm64: the Adoptium URL was pinned to
# `linux/x64`, so the app installed cleanly and then died with
#     OrbStack ERROR: Dynamic loader not found: /lib64/ld-linux-x86-64.so.2
# on a machine whose own `java` was a perfectly good JDK 21.
#
# So: ask the system first. Ubuntu 24.04 and Debian 13 both make `default-jdk`
# JDK 21, which covers the platform's supported targets, and `kc.sh` picks up
# JAVA_HOME. The download stays as a fallback for older distros — and is now
# arch-aware, so when it is needed it also works.

set -e

KEYCLOAK_VERSION="${KEYCLOAK_VERSION:-26.1.4}"
JAVA_REQUIRED_MAJOR=21

echo "Downloading Keycloak ${KEYCLOAK_VERSION}..."
KC_URL="https://github.com/keycloak/keycloak/releases/download/${KEYCLOAK_VERSION}/keycloak-${KEYCLOAK_VERSION}.tar.gz"
hop3-fetch "$KC_URL" -o keycloak.tar.gz
tar -xzf keycloak.tar.gz
rm keycloak.tar.gz
mv "keycloak-${KEYCLOAK_VERSION}" keycloak
echo "  → $(du -sh keycloak | cut -f1)"

# The major version of the system `java`, or 0 when there is none. The version
# line is "openjdk version \"21.0.11\" ..." — take the first dotted component.
system_java_major() {
    command -v java >/dev/null 2>&1 || { echo 0; return; }
    java -version 2>&1 \
        | awk -F'"' '/version/ {split($2, v, "."); print v[1]; exit}' \
        | grep -E '^[0-9]+$' || echo 0
}

JAVA_MAJOR="$(system_java_major)"
if [ "$JAVA_MAJOR" -ge "$JAVA_REQUIRED_MAJOR" ]; then
    echo "  → using system Java ${JAVA_MAJOR} ($(command -v java)); no JRE download"
    # start.sh exports JAVA_HOME=$PWD/jre when it exists; leaving it absent is
    # what tells it to fall through to the system java that kc.sh finds itself.
    exit 0
fi

case "$(uname -m)" in
    x86_64)          JRE_ARCH=x64 ;;
    aarch64 | arm64) JRE_ARCH=aarch64 ;;
    *)
        echo "keycloak: system Java is ${JAVA_MAJOR} (need ${JAVA_REQUIRED_MAJOR}+)" >&2
        echo "and Adoptium publishes no JRE for $(uname -m)." >&2
        echo "Install a JDK ${JAVA_REQUIRED_MAJOR} on the host." >&2
        exit 1
        ;;
esac

echo "System Java is ${JAVA_MAJOR}; fetching Temurin ${JAVA_REQUIRED_MAJOR} JRE (${JRE_ARCH})..."
JDK_VERSION_URL="${JDK_VERSION_URL:-https://api.adoptium.net/v3/binary/latest/${JAVA_REQUIRED_MAJOR}/ga/linux/${JRE_ARCH}/jre/hotspot/normal/eclipse}"
hop3-fetch -o jre.tar.gz "$JDK_VERSION_URL"
mkdir -p jre
tar -xzf jre.tar.gz --strip-components=1 -C jre
rm jre.tar.gz
echo "  → JRE at $(./jre/bin/java -version 2>&1 | head -1)"
