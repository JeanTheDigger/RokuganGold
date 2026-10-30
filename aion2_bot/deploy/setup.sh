#!/bin/bash
# ============================================================
# Aion 2 Discord Bot: one-shot server setup (and update)
# ============================================================
# Run as root on Ubuntu 24.04 LTS (Vultr or similar). It can share a server
# with the Rokugan bot: separate user, folder, service and backups.
#
# What this does:
#   1. Updates the system
#   2. Installs Python 3, venv, git, sqlite3, ufw
#   3. Creates an 'aion2' system user (the bot runs as this user, not root)
#   4. Copies the bot code into /home/aion2/bot/
#   5. Creates a Python virtual environment and installs dependencies
#   6. Asks for your Discord bot token (and, optionally, your server's ID)
#   7. Installs a systemd service (auto-start on boot, auto-restart on crash)
#   8. Sets up daily database backups (04:15 UTC, keeps 14 days)
#   9. Enables the firewall (SSH only: the bot only makes outbound connections)
#
# Running it again later UPDATES the bot: it copies the new code, installs
# any new dependencies and restarts. Your .env and database are never touched.
# ============================================================
set -euo pipefail

BOT_USER=aion2
HOME_DIR=/home/$BOT_USER
BOT_DIR=$HOME_DIR/bot
SERVICE=aion2-bot

echo ""
echo "=== Aion 2 Discord Bot: Server Setup ==="
echo ""

# --- Must be root ---
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root (sudo bash setup.sh)."
    exit 1
fi

# --- Where is the code? (the aion2_bot folder this script lives in) ---
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_DIR="$(dirname "$SCRIPT_DIR")"
if [ ! -f "$SRC_DIR/bot.py" ] || [ ! -f "$SRC_DIR/siege.py" ]; then
    echo "ERROR: Can't find the bot code next to this script."
    echo "Run it from inside the aion2_bot/deploy/ folder of the repository, e.g.:"
    echo "    bash /tmp/rokugangold/aion2_bot/deploy/setup.sh"
    exit 1
fi

# --- 1. System update ---
echo "[1/9] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq && apt-get upgrade -y -qq

# --- 2. Install dependencies ---
echo "[2/9] Installing Python, git, sqlite3, firewall..."
apt-get install -y -qq python3 python3-pip python3-venv git sqlite3 ufw

# --- 3. Create bot user ---
echo "[3/9] Creating '$BOT_USER' user..."
if id "$BOT_USER" &>/dev/null; then
    echo "  User '$BOT_USER' already exists, keeping it."
else
    useradd --system --create-home --shell /bin/bash "$BOT_USER"
fi

# --- 4. Copy bot code (never the .env or the database) ---
echo "[4/9] Copying bot code to $BOT_DIR ..."
mkdir -p "$BOT_DIR"
cp "$SRC_DIR"/*.py "$BOT_DIR/"
cp "$SRC_DIR/requirements.txt" "$SRC_DIR/.env.example" "$BOT_DIR/"
rm -rf "$BOT_DIR/deploy"
cp -r "$SRC_DIR/deploy" "$BOT_DIR/"
chown -R "$BOT_USER:$BOT_USER" "$HOME_DIR"

# --- 5. Python venv + dependencies ---
echo "[5/9] Setting up the Python virtual environment..."
cd "$BOT_DIR"
if [ ! -d ".venv" ]; then
    sudo -u "$BOT_USER" python3 -m venv .venv
fi
sudo -u "$BOT_USER" .venv/bin/pip install -q --upgrade pip
sudo -u "$BOT_USER" .venv/bin/pip install -q -r requirements.txt

# --- 6. Bot token ---
echo "[6/9] Discord bot token..."
if [ -f "$BOT_DIR/.env" ]; then
    echo "  .env already exists: keeping it. To change the token or server ID:"
    echo "    nano $BOT_DIR/.env"
else
    echo ""
    echo "  Your bot token is at https://discord.com/developers/applications"
    echo "  -> your application -> Bot -> Reset Token."
    echo ""
    read -rsp "  Paste your Discord bot token (it won't show): " BOT_TOKEN
    echo ""
    echo ""
    echo "  Optional: your Discord server's ID makes slash commands appear at once"
    echo "  instead of up to an hour later. (Discord: Settings -> Advanced -> Developer"
    echo "  Mode on, then right-click your server icon -> Copy Server ID.)"
    read -rp "  Server ID (press Enter to skip): " GUILD_ID
    if [ -z "$BOT_TOKEN" ]; then
        echo "  WARNING: No token entered. The bot won't start until you add it:"
        echo "    nano $BOT_DIR/.env"
        BOT_TOKEN=paste-your-bot-token-here
    fi
    cat > "$BOT_DIR/.env" << ENVEOF
DISCORD_BOT_TOKEN=${BOT_TOKEN}
DISCORD_GUILD_ID=${GUILD_ID}
AION2_DB=$BOT_DIR/aion2.db
ENVEOF
    chmod 600 "$BOT_DIR/.env"
    chown "$BOT_USER:$BOT_USER" "$BOT_DIR/.env"
fi

# --- 7. Systemd service ---
echo "[7/9] Installing the systemd service..."
cp "$BOT_DIR/deploy/$SERVICE.service" "/etc/systemd/system/$SERVICE.service"
systemctl daemon-reload
systemctl enable "$SERVICE" >/dev/null

# --- 8. Database backups ---
echo "[8/9] Setting up daily database backups..."
cp "$BOT_DIR/deploy/backup.sh" "$HOME_DIR/backup.sh"
chmod +x "$HOME_DIR/backup.sh"
chown "$BOT_USER:$BOT_USER" "$HOME_DIR/backup.sh"
echo "15 4 * * * $BOT_USER $HOME_DIR/backup.sh" > /etc/cron.d/aion2-backup
chmod 644 /etc/cron.d/aion2-backup

# --- 9. Firewall ---
echo "[9/9] Firewall (SSH only)..."
ufw allow OpenSSH >/dev/null
ufw --force enable >/dev/null

# --- Start (or restart, when updating) ---
echo ""
echo "Starting the bot..."
systemctl restart "$SERVICE"
sleep 5

if systemctl is-active --quiet "$SERVICE"; then
    echo ""
    echo "============================================"
    echo "  SUCCESS! The Aion 2 bot is running."
    echo "============================================"
    echo ""
    echo "  Next, in Discord: the server owner runs /setup server"
    echo ""
    echo "  Useful commands:"
    echo "    systemctl status $SERVICE    : is it running?"
    echo "    journalctl -u $SERVICE -f    : live log (Ctrl+C to stop watching)"
    echo "    systemctl restart $SERVICE   : restart"
    echo "    systemctl stop $SERVICE      : stop"
    echo ""
    echo "  Database backups: daily at 04:15 UTC in $HOME_DIR/backups/"
    echo ""
else
    echo ""
    echo "WARNING: The bot didn't stay running. The last log lines:"
    echo ""
    journalctl -u "$SERVICE" -n 15 --no-pager || true
    echo ""
    echo "Common causes:"
    echo "  - Wrong token:           nano $BOT_DIR/.env   then   systemctl restart $SERVICE"
    echo "  - 'PrivilegedIntentsRequired': turn on Server Members Intent AND Message"
    echo "    Content Intent on the Bot page of the Developer Portal, then"
    echo "    systemctl restart $SERVICE"
    echo ""
fi
