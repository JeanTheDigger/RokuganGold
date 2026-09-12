#!/bin/bash
# ============================================================
# Rokugan Discord Bot: One-Shot Server Setup
# ============================================================
# Run as root on a fresh Ubuntu 24.04 LTS (Vultr or similar).
#
# What this does:
#   1. Updates the system
#   2. Installs Python 3, pip, venv, git, sqlite3, ufw
#   3. Creates a 'rokugan' system user (the bot runs as this user, not root)
#   4. Copies bot code into /home/rokugan/bot/
#   5. Creates a Python virtual environment and installs dependencies
#   6. Asks you to paste your Discord bot token
#   7. Installs a systemd service (auto-start on boot, auto-restart on crash)
#   8. Sets up daily database backups (keeps 14 days)
#   9. Enables the firewall (SSH only: the bot makes outbound connections)
#
# After this script finishes, the bot is running. You're done.
# ============================================================
set -euo pipefail

echo ""
echo "=== Rokugan Discord Bot: Server Setup ==="
echo ""

# --- Must be root ---
if [ "$(id -u)" -ne 0 ]; then
    echo "ERROR: Run this script as root (sudo bash setup.sh)."
    exit 1
fi

# --- 1. System update ---
echo "[1/9] Updating system packages..."
apt update -qq && apt upgrade -y -qq

# --- 2. Install dependencies ---
echo "[2/9] Installing Python, git, sqlite3, firewall..."
apt install -y -qq python3 python3-pip python3-venv git sqlite3 ufw

# --- 3. Create bot user ---
echo "[3/9] Creating 'rokugan' user..."
if id rokugan &>/dev/null; then
    echo "  User 'rokugan' already exists, skipping."
else
    useradd --system --create-home --shell /bin/bash rokugan
fi

# --- 4. Copy bot code ---
echo "[4/9] Setting up bot code in /home/rokugan/bot/ ..."
BOT_DIR=/home/rokugan/bot

if [ -d "$BOT_DIR" ]; then
    echo "  Bot directory already exists. Updating files..."
    # Pull if it's a git checkout, otherwise just warn
    if [ -d "$BOT_DIR/.git" ]; then
        cd "$BOT_DIR"
        sudo -u rokugan git pull || echo "  Git pull failed: you may need to update manually."
        cd /root
    fi
else
    # Check if we're running from inside the repo
    SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
    DISCORD_BOT_DIR="$(dirname "$SCRIPT_DIR")"

    if [ -f "$DISCORD_BOT_DIR/bot.py" ] && [ -d "$DISCORD_BOT_DIR/l5r_rules" ]; then
        echo "  Copying from $DISCORD_BOT_DIR ..."
        mkdir -p "$BOT_DIR"
        cp -r "$DISCORD_BOT_DIR"/*.py "$BOT_DIR/"
        cp -r "$DISCORD_BOT_DIR/l5r_rules" "$BOT_DIR/"
        cp "$DISCORD_BOT_DIR/requirements.txt" "$BOT_DIR/"
        cp "$DISCORD_BOT_DIR/.env.example" "$BOT_DIR/"
        [ -d "$DISCORD_BOT_DIR/deploy" ] && cp -r "$DISCORD_BOT_DIR/deploy" "$BOT_DIR/"
        chown -R rokugan:rokugan "$BOT_DIR"
    else
        echo "  ERROR: Can't find bot.py. Run this script from inside the discord_bot/deploy/"
        echo "  directory, or clone the repo first and re-run."
        echo ""
        echo "  To clone (if the repo is public):"
        echo "    git clone https://github.com/jeanthedigger/rokugangold.git /tmp/rokugangold"
        echo "    bash /tmp/rokugangold/discord_bot/deploy/setup.sh"
        exit 1
    fi
fi

# --- 5. Python venv + dependencies ---
echo "[5/9] Setting up Python virtual environment..."
cd "$BOT_DIR"
if [ ! -d ".venv" ]; then
    sudo -u rokugan python3 -m venv .venv
fi
sudo -u rokugan .venv/bin/pip install -q -r requirements.txt

# --- 6. Bot token ---
echo "[6/9] Discord bot token setup..."
if [ -f "$BOT_DIR/.env" ]; then
    echo "  .env already exists: keeping it. Edit manually if you need to change the token:"
    echo "    nano /home/rokugan/bot/.env"
else
    echo ""
    echo "  You need your Discord bot token from:"
    echo "  https://discord.com/developers/applications -> your app -> Bot -> Token"
    echo ""
    read -rsp "  Paste your Discord bot token (it won't show): " BOT_TOKEN
    echo ""
    if [ -z "$BOT_TOKEN" ]; then
        echo "  WARNING: No token entered. The bot won't start until you set it:"
        echo "    nano /home/rokugan/bot/.env"
        cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
    else
        cat > "$BOT_DIR/.env" << ENVEOF
DISCORD_BOT_TOKEN=${BOT_TOKEN}
DB_PATH=/home/rokugan/bot/rokugan.db
ENVEOF
    fi
fi

# --- Fix ownership ---
chown -R rokugan:rokugan /home/rokugan

# --- 7. Systemd service ---
echo "[7/9] Installing systemd service..."
cp "$BOT_DIR/deploy/rokugan-bot.service" /etc/systemd/system/rokugan-bot.service
systemctl daemon-reload
systemctl enable rokugan-bot

# --- 8. Database backups ---
echo "[8/9] Setting up daily database backups..."
chmod +x "$BOT_DIR/deploy/backup.sh"
cp "$BOT_DIR/deploy/backup.sh" /home/rokugan/backup.sh
chown rokugan:rokugan /home/rokugan/backup.sh
echo "0 4 * * * rokugan /home/rokugan/backup.sh" > /etc/cron.d/rokugan-backup
chmod 644 /etc/cron.d/rokugan-backup

# --- 9. Firewall ---
echo "[9/9] Configuring firewall (SSH only)..."
ufw allow OpenSSH
ufw --force enable

# --- Start the bot ---
echo ""
echo "Starting the bot..."
systemctl start rokugan-bot
sleep 2

if systemctl is-active --quiet rokugan-bot; then
    echo ""
    echo "============================================"
    echo "  SUCCESS! The bot is running."
    echo "============================================"
    echo ""
    echo "  Useful commands:"
    echo "    systemctl status rokugan-bot   : is it running?"
    echo "    journalctl -u rokugan-bot -f   : live log (Ctrl+C to stop watching)"
    echo "    systemctl restart rokugan-bot  : restart after changes"
    echo "    systemctl stop rokugan-bot     : stop the bot"
    echo ""
    echo "  The bot auto-starts on boot and auto-restarts on crash."
    echo "  Database backups run daily at 04:00 UTC in /home/rokugan/backups/"
    echo ""
else
    echo ""
    echo "WARNING: The bot may not have started correctly."
    echo "Check the logs:  journalctl -u rokugan-bot -n 50"
    echo ""
    echo "Common fix: make sure .env has a valid token:"
    echo "  nano /home/rokugan/bot/.env"
    echo "  systemctl restart rokugan-bot"
    echo ""
fi
