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
#   4. Puts the repository in /home/rokugan/repo/ (the bot runs from its discord_bot/ folder)
#   5. Creates a Python virtual environment and installs dependencies
#   6. Asks you to paste your Discord bot token
#   7. Installs a systemd service (auto-start on boot, auto-restart on crash)
#   8. Sets up daily backups of the database and portraits (keeps 14 days)
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

# --- 4. Put the repository in place ---
REPO_DIR=/home/rokugan/repo
BOT_DIR=$REPO_DIR/discord_bot
echo "[4/9] Setting up the code in $REPO_DIR ..."

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SRC_ROOT="$(dirname "$(dirname "$SCRIPT_DIR")")"   # the repository this script came from

if [ -d "$REPO_DIR/.git" ]; then
    echo "  $REPO_DIR already exists. Updating it..."
    git -C "$REPO_DIR" pull || echo "  Git pull failed: update it by hand later."
elif [ -d "$REPO_DIR" ]; then
    echo "  $REPO_DIR exists but is not a git checkout. Leaving the code as it is."
elif [ -f "$SRC_ROOT/discord_bot/bot.py" ]; then
    echo "  Copying the repository from $SRC_ROOT (keeps its git history so 'git pull' works)..."
    cp -a "$SRC_ROOT" "$REPO_DIR"
else
    echo "  ERROR: Can't find the repository. Clone it first, then run this script from inside the clone:"
    echo "    git clone https://github.com/JeanTheDigger/RokuganGold.git /tmp/rokugangold"
    echo "    bash /tmp/rokugangold/discord_bot/deploy/setup.sh"
    exit 1
fi
# root runs 'git pull' on a folder the rokugan user owns, so tell git that is fine.
git config --global --add safe.directory "$REPO_DIR"
chown -R rokugan:rokugan /home/rokugan

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
    echo "    nano /home/rokugan/repo/discord_bot/.env"
else
    echo ""
    echo "  You need your Discord bot token from:"
    echo "  https://discord.com/developers/applications -> your app -> Bot -> Token"
    echo ""
    read -rsp "  Paste your Discord bot token (it won't show): " BOT_TOKEN
    echo ""
    if [ -z "$BOT_TOKEN" ]; then
        echo "  WARNING: No token entered. The bot won't start until you set it:"
        echo "    nano /home/rokugan/repo/discord_bot/.env"
        cp "$BOT_DIR/.env.example" "$BOT_DIR/.env"
    else
        cat > "$BOT_DIR/.env" << ENVEOF
DISCORD_BOT_TOKEN=${BOT_TOKEN}
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

# --- 8. Backups (database + portraits) ---
echo "[8/9] Setting up daily backups..."
chmod +x "$BOT_DIR/deploy/backup.sh"
mkdir -p /home/rokugan/backups
chown rokugan:rokugan /home/rokugan/backups
# Cron runs the script straight from the repository, so 'git pull' keeps it current.
echo "0 4 * * * rokugan $BOT_DIR/deploy/backup.sh >> /home/rokugan/backups/backup.log 2>&1" > /etc/cron.d/rokugan-backup
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
    echo "  Backups of the database and portraits run daily at 04:00 UTC in /home/rokugan/backups/"
    echo "  Testing one now..."
    sudo -u rokugan "$BOT_DIR/deploy/backup.sh" || echo "  The test backup failed: see DEPLOY.md, section Backups."
    echo ""
else
    echo ""
    echo "WARNING: The bot may not have started correctly."
    echo "Check the logs:  journalctl -u rokugan-bot -n 50"
    echo ""
    echo "Common fix: make sure .env has a valid token:"
    echo "  nano /home/rokugan/repo/discord_bot/.env"
    echo "  systemctl restart rokugan-bot"
    echo ""
fi
