#!/usr/bin/env bash
# Disaster recovery restore.
# Restores the latest Restic snapshot to the current server (run on the replica).
# Usage: ./scripts/restore/restore.sh [snapshot-id]
#   snapshot-id defaults to "latest"

set -euo pipefail

ENV_FILE="/etc/restic-env"
SNAPSHOT="${1:-latest}"
RESTORE_TMP="/tmp/moodle-restore"
WEBROOT="/var/www/moodle"
DATAROOT="/var/moodledata"
DB_NAME="moodle"
DB_USER="moodle"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found." >&2
    exit 1
fi
set -a; source "$ENV_FILE"; set +a

echo "==> Stopping Nginx and PHP-FPM..."
systemctl stop nginx php8.4-fpm

echo "==> Restoring snapshot $SNAPSHOT to $RESTORE_TMP..."
rm -rf "$RESTORE_TMP"
restic restore "$SNAPSHOT" --target "$RESTORE_TMP"

echo "==> Syncing web root..."
rsync -a --delete "$RESTORE_TMP$WEBROOT/" "$WEBROOT/"

echo "==> Syncing Moodle data root..."
rsync -a --delete "$RESTORE_TMP$DATAROOT/" "$DATAROOT/"

DUMP=$(find "$RESTORE_TMP/tmp" -name "moodle-*.sql" | sort | tail -1)
if [[ -f "$DUMP" ]]; then
    echo "==> Restoring database from $DUMP..."
    psql -U "$DB_USER" -d postgres -c "DROP DATABASE IF EXISTS $DB_NAME;"
    psql -U "$DB_USER" -d postgres -c "CREATE DATABASE $DB_NAME OWNER $DB_USER;"
    psql -U "$DB_USER" -d "$DB_NAME" < "$DUMP"
else
    echo "WARNING: No SQL dump found in snapshot. Database not restored." >&2
fi

chown -R www-data:www-data "$WEBROOT" "$DATAROOT"

echo "==> Restarting services..."
systemctl start php8.4-fpm nginx

rm -rf "$RESTORE_TMP"
echo "==> Restore complete."
