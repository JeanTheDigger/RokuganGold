#!/bin/bash
# Daily backup of the Rokugan bot: the database and the character portraits.
#
# Run by cron at 04:00 UTC (installed by setup.sh), and by hand before risky
# changes:   sudo -u rokugan /home/rokugan/repo/discord_bot/deploy/backup.sh
#
# Writes to /home/rokugan/backups/ and keeps 14 days:
#   rokugan-YYYYMMDD-HHMM.db      a consistent copy of the database
#   portraits-YYYYMMDD-HHMM.tgz   the uploaded portrait pictures (if any exist)
# The .env file (with the bot token) is deliberately NOT backed up. The token
# can always be reset in the Discord Developer Portal.
#
# Unlike the old version this fails loudly when it cannot find the database, so
# a wrong path shows up in backup.log instead of silently backing up nothing.
#
# Settings, all optional (set them in the environment):
#   BOT_DIR     folder the bot runs from  (default /home/rokugan/repo/discord_bot)
#   BACKUP_DIR  where backups go          (default /home/rokugan/backups)
#   KEEP_DAYS   how long to keep them     (default 14)
set -euo pipefail

BOT_DIR="${BOT_DIR:-/home/rokugan/repo/discord_bot}"
BACKUP_DIR="${BACKUP_DIR:-/home/rokugan/backups}"
KEEP_DAYS="${KEEP_DAYS:-14}"
DB="${DB_PATH:-$BOT_DIR/rokugan.db}"
PORTRAITS="${PORTRAIT_DIR:-$BOT_DIR/portraits}"

stamp="$(date +%Y%m%d-%H%M)"

if [ ! -f "$DB" ]; then
    echo "backup: FAILED. No database at $DB. Is BOT_DIR right? (BOT_DIR=$BOT_DIR)" >&2
    exit 1
fi

mkdir -p "$BACKUP_DIR"

# SQLite's own backup API gives a consistent copy even while the bot is writing.
# It uses Python (always installed for the bot), so the sqlite3 program is not needed.
python3 - "$DB" "$BACKUP_DIR/rokugan-$stamp.db" <<'PY'
import sqlite3, sys
src = sqlite3.connect(sys.argv[1])
dst = sqlite3.connect(sys.argv[2])
with dst:
    src.backup(dst)
dst.close()
src.close()
PY

portrait_note="no portraits yet"
if [ -d "$PORTRAITS" ] && [ -n "$(ls -A "$PORTRAITS" 2>/dev/null)" ]; then
    tar czf "$BACKUP_DIR/portraits-$stamp.tgz" -C "$(dirname "$PORTRAITS")" "$(basename "$PORTRAITS")"
    portrait_note="portraits-$stamp.tgz"
fi

find "$BACKUP_DIR" -maxdepth 1 \( -name 'rokugan-*.db' -o -name 'portraits-*.tgz' \) \
    -mtime +"$KEEP_DAYS" -delete

echo "backup: ok $(date -u +%FT%TZ) rokugan-$stamp.db + $portrait_note"
