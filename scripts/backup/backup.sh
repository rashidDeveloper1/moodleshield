#!/usr/bin/env bash
# On-demand backup: PostgreSQL dump + full Moodle data snapshot via Restic.
# The cron version lives in the Ansible backup role; this is for manual runs.
# Usage: ./scripts/backup/backup.sh

set -euo pipefail

ENV_FILE="/etc/restic-env"
DATAROOT="/var/moodledata"
WEBROOT="/var/www/moodle"
DB_NAME="moodle"
DB_USER="moodle"
DUMP_FILE="/tmp/moodle-manual-$(date +%Y%m%dT%H%M%S).sql"

if [[ ! -f "$ENV_FILE" ]]; then
    echo "ERROR: $ENV_FILE not found. Run the Ansible backup role first." >&2
    exit 1
fi
set -a
# shellcheck disable=SC1090
source "$ENV_FILE"
set +a
echo "==> Dumping PostgreSQL database..."
pg_dump -U "$DB_USER" "$DB_NAME" > "$DUMP_FILE"

echo "==> Creating Restic snapshot..."
restic backup \
    "$WEBROOT" \
    "$DATAROOT" \
    "$DUMP_FILE" \
    --tag "manual,moodleshield" \
    --exclude="*.log"

rm -f "$DUMP_FILE"

echo "==> Backup complete."
restic snapshots --tag moodleshield --last 5
