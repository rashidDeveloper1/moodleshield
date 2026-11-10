#!/usr/bin/env bash
# MoodleShield Enterprise
# Disaster Recovery Restore Script
#
# Usage:
#   sudo ./scripts/restore/restore.sh [snapshot-id]
#
# Defaults to the latest Restic snapshot.
#
# WARNING:
# This script replaces Moodle application files, Moodle data,
# and the PostgreSQL database. Use only on a dedicated
# recovery server after verifying the backup.

set -euo pipefail

# Configuration
ENV_FILE="/etc/restic-env"
SNAPSHOT="${1:-latest}"
RESTORE_TMP="/var/tmp/moodle-restore"
WEBROOT="/var/www/moodle"
DATAROOT="/var/moodledata"
DB_NAME="moodle"
DB_USER="moodle"

# Require root privileges
if [[ "$EUID" -ne 0 ]]; then
    echo "ERROR: Run this script as root." >&2
    exit 1
fi

# Validate environment configuration
if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found." >&2
    exit 1
fi

# Load Restic environment variables
# shellcheck disable=SC1090
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a

# Check required commands
for cmd in restic rsync psql systemctl find sort; do
    if ! command -v "$cmd" >/dev/null 2>&1; then
        echo "ERROR: Missing command: $cmd" >&2
        exit 1
    fi
done

# Prevent accidental reuse of an existing restore directory
if [[ -e "$RESTORE_TMP" ]]; then
    echo "ERROR: Restore directory already exists." >&2
    echo "Inspect it before retrying: $RESTORE_TMP" >&2
    exit 1
fi

# Confirm destructive restore
echo "========================================"
echo " MoodleShield Enterprise Restore"
echo "========================================"
echo "Snapshot: $SNAPSHOT"
echo "Web root: $WEBROOT"
echo "Data root: $DATAROOT"
echo "Database: $DB_NAME"
echo ""
echo "WARNING: Existing application data will be replaced."

read -r -p "Type RESTORE to continue: " CONFIRM

if [[ "$CONFIRM" != "RESTORE" ]]; then
    echo "Restore cancelled."
    exit 1
fi

# Download backup before touching running services
echo "==> Restoring Restic snapshot..."

mkdir -m 700 "$RESTORE_TMP"
restic restore "$SNAPSHOT" --target "$RESTORE_TMP"

# Validate backup content
if [[ ! -d "$RESTORE_TMP$WEBROOT" ]]; then
    echo "ERROR: Moodle web root missing from backup." >&2
    exit 1
fi

if [[ ! -d "$RESTORE_TMP$DATAROOT" ]]; then
    echo "ERROR: Moodle data root missing from backup." >&2
    exit 1
fi

# Find latest SQL dump
DUMP=""

if [[ -d "$RESTORE_TMP/tmp" ]]; then
    DUMP=$(
        find "$RESTORE_TMP/tmp" \
            -type f \
            -name 'moodle-*.sql' \
            -print |
        sort |
        tail -n 1
    )
fi

if [[ -z "$DUMP" || ! -s "$DUMP" ]]; then
    echo "ERROR: Valid Moodle SQL dump not found." >&2
    echo "Existing services and database were not modified." >&2
    exit 1
fi

# Stop application services
echo "==> Stopping Moodle application services..."

systemctl stop nginx php8.4-fpm

# Restore application files
echo "==> Restoring Moodle application..."

mkdir -p "$WEBROOT" "$DATAROOT"

rsync -a --delete \
    "$RESTORE_TMP$WEBROOT/" \
    "$WEBROOT/"

# Restore Moodle user data
echo "==> Restoring Moodle data..."

rsync -a --delete \
    "$RESTORE_TMP$DATAROOT/" \
    "$DATAROOT/"

# Restore PostgreSQL database
echo "==> Restoring PostgreSQL database..."

# PostgreSQL administration runs under the postgres account.
# Terminate active connections before replacing the database.
runuser -u postgres -- psql \
    -v ON_ERROR_STOP=1 \
    -d postgres \
    -c "SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE datname = '$DB_NAME'
        AND pid <> pg_backend_pid();"

runuser -u postgres -- dropdb \
    --if-exists "$DB_NAME"

runuser -u postgres -- createdb \
    --owner="$DB_USER" "$DB_NAME"

# Restore the SQL dump and stop immediately on SQL errors
runuser -u postgres -- psql \
    -v ON_ERROR_STOP=1 \
    -d "$DB_NAME" \
    -f "$DUMP"

# Restore filesystem permissions
echo "==> Applying Moodle permissions..."

chown -R www-data:www-data \
    "$WEBROOT" "$DATAROOT"

# Start services only after successful restoration
echo "==> Starting application services..."

systemctl start php8.4-fpm nginx

# Check service health
systemctl is-active --quiet php8.4-fpm
systemctl is-active --quiet nginx

echo "==> Services are running."

# Remove temporary restore files
rm -rf -- "$RESTORE_TMP"

echo "========================================"
echo " MoodleShield Restore Completed"
echo "========================================"
echo "Snapshot: $SNAPSHOT"
echo "Status: Restore commands completed successfully"
echo "Next: Verify Moodle login, courses, files, and database."

