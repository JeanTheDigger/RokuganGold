#!/bin/bash
# Daily backup of the Rokugan bot database.
# Installed by setup.sh as a cron job (runs at 04:00 UTC daily).
# Keeps the last 14 days of backups.
set -euo pipefail

BACKUP_DIR=/home/rokugan/backups
DB=/home/rokugan/bot/rokugan.db

mkdir -p "$BACKUP_DIR"

if [ -f "$DB" ]; then
    sqlite3 "$DB" ".backup '$BACKUP_DIR/rokugan-$(date +%Y%m%d-%H%M).db'"
    find "$BACKUP_DIR" -name "rokugan-*.db" -mtime +14 -delete
fi
