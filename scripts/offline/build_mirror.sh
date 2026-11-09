#!/usr/bin/env bash
# Build a local APT mirror containing every package needed for air-gapped install.
# Run this on an internet-connected machine, then transfer the output directory.
# Usage: ./scripts/offline/build_mirror.sh [output-dir]

set -euo pipefail

OUTPUT_DIR="${1:-/opt/moodleshield-mirror}"
ARCH="amd64"

PACKAGES=(
    nginx
    postgresql-17 postgresql-client-17 python3-psycopg2
    php8.4-fpm php8.4-pgsql php8.4-xml php8.4-mbstring php8.4-curl
    php8.4-zip php8.4-gd php8.4-intl php8.4-soap php8.4-redis
    php8.4-opcache php8.4-cli
    redis-server
    wireguard
    restic
    certbot python3-certbot-nginx
    curl wget git unzip ufw fail2ban logrotate ca-certificates
    gnupg lsb-release python3-pip
    qpdf
)

mkdir -p "$OUTPUT_DIR/debs"

echo "==> Downloading packages and dependencies..."
apt-get download $(apt-cache depends --recurse --no-recommends --no-suggests \
    --no-conflicts --no-breaks --no-replaces --no-enhances \
    "${PACKAGES[@]}" 2>/dev/null | grep "^\w" | sort -u)

mv ./*.deb "$OUTPUT_DIR/debs/" 2>/dev/null || true

echo "==> Building APT Packages index..."
cd "$OUTPUT_DIR"
dpkg-scanpackages debs /dev/null | gzip -9c > debs/Packages.gz

echo "==> Generating checksums..."
find "$OUTPUT_DIR/debs" -name "*.deb" -exec sha256sum {} \; > "$OUTPUT_DIR/SHA256SUMS"

echo "==> Mirror built at $OUTPUT_DIR"
echo "    Transfer this directory to the air-gapped server, then run:"
echo "    echo 'deb [trusted=yes] file://$OUTPUT_DIR/debs ./' > /etc/apt/sources.list.d/local.list"
echo "    apt-get update && apt-get install <package>"
