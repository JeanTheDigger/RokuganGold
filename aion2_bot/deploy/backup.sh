#!/bin/bash
# Daily backup of the Aion 2 bot database (every Legion, membership, vote,
# setting and the rules text). Installed by setup.sh as a cron job (04:15 UTC).
# Keeps the last 14 days. Safe while the bot is running: sqlite3 .backup
# takes a consistent copy.
set -euo pipefail

BACKUP_DIR=/home/aion2/backups
DB=/home/aion2/bot/aion2.db

mkdir -p "$BACKUP_DIR"

if [ -f "$DB" ]; then
    sqlite3 "$DB" ".backup '$BACKUP_DIR/aion2-$(date +%Y%m%d-%H%M).db'"
    find "$BACKUP_DIR" -name "aion2-*.db" -mtime +14 -delete
fi
