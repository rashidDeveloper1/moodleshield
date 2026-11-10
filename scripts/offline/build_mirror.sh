#!/usr/bin/env bash
# MoodleShield Enterprise
# Offline APT Repository Builder
#
# Run on an internet-connected Debian 13 amd64 machine
# with the required package repositories configured.
#
# Usage:
#   sudo bash scripts/offline/build_mirror.sh [output-dir]
#
# Note: This creates a package repository, not a complete
# air-gapped operating system installer.

set -euo pipefail

OUTPUT_DIR="${1:-/opt/moodleshield-mirror}"
ARCH="amd64"

PACKAGES=(
    nginx
    postgresql-17
    postgresql-client-17
    python3-psycopg2
    php8.4-fpm
    php8.4-pgsql
    php8.4-xml
    php8.4-mbstring
    php8.4-curl
    php8.4-zip
    php8.4-gd
    php8.4-intl
    php8.4-soap
    php8.4-redis
    php8.4-opcache
    php8.4-cli
    redis-server
    wireguard
    restic
    certbot
    python3-certbot-nginx
    curl
    wget
    git
    unzip
    ufw
    fail2ban
    logrotate
    ca-certificates
    gnupg
    lsb-release
    python3-pip
    qpdf
)

echo "==> MoodleShield Offline Repository Builder"

if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run as root." >&2
    exit 1
fi

if [[ "$(dpkg --print-architecture)" != "$ARCH" ]]; then
    echo "ERROR: This build requires $ARCH architecture." >&2
    exit 1
fi

for cmd in apt-get apt-cache dpkg-scanpackages \
           sha256sum awk sort gzip; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Missing dependency: $cmd" >&2
        exit 1
    fi
done

mkdir -p "$OUTPUT_DIR/debs"

echo "==> Checking package availability..."

for package in "${PACKAGES[@]}"; do
    candidate=$(apt-cache policy "$package" |
        awk '/Candidate:/ {print $2; exit}')

    if [[ -z "$candidate" || "$candidate" == "(none)" ]]; then
        echo "ERROR: Package unavailable: $package" >&2
        exit 1
    fi
done

echo "==> Resolving package dependencies..."

mapfile -t dependencies < <(
    apt-cache depends --recurse \
        --no-recommends \
        --no-suggests \
        --no-conflicts \
        --no-breaks \
        --no-replaces \
        --no-enhances \
        "${PACKAGES[@]}" |
    awk '/^[[:alnum:]][[:alnum:].+:-]*$/ {print}' |
    sort -u
)

if [[ ${#dependencies[@]} -eq 0 ]]; then
    echo "ERROR: No packages resolved." >&2
    exit 1
fi

echo "==> Downloading packages..."

cd "$OUTPUT_DIR/debs"

for package in "${dependencies[@]}"; do
    apt-get download "$package"
done

echo "==> Generating APT package index..."

dpkg-scanpackages . /dev/null |
    gzip -9c > Packages.gz

echo "==> Generating SHA256 checksums..."

(
    cd "$OUTPUT_DIR"
    find debs -type f -name '*.deb' -print0 |
        sort -z |
        xargs -0 -r sha256sum > SHA256SUMS
)

echo "==> Verifying downloaded files..."

(
    cd "$OUTPUT_DIR"
    sha256sum -c SHA256SUMS
)

echo "========================================"
echo " MoodleShield Repository Build Complete"
echo "========================================"
echo "Output: $OUTPUT_DIR"
echo "Architecture: $ARCH"
echo "Packages downloaded: ${#dependencies[@]}"
echo ""
echo "Next: Test dependency completeness in a clean"
echo "Debian 13 VM with network access disabled."

