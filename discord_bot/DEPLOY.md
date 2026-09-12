# Deploying the Rokugan Bot to Vultr

A plain-English guide. You do not need to know Linux to follow this.

---

## First-Time Setup (15 minutes)

### 1. Get your bot code onto the server

Open a terminal (Mac/Linux) or PowerShell (Windows) and connect:

```bash
ssh root@96.30.196.68
```

It will ask for the password from your Vultr dashboard. Type it (nothing shows
while you type: that's normal) and press Enter.

Once you're in, get the bot code onto the server. **Pick one method:**

**Method A: Clone from GitHub (if the repo is public or you have a token):**
```bash
git clone https://github.com/jeanthedigger/rokugangold.git /tmp/rokugangold
```

**Method B: Upload from your computer (if the repo is private):**

Open a *second* terminal on your own computer (not the server) and run:
```bash
scp -r /path/to/RokuganGold/discord_bot root@96.30.196.68:/tmp/discord_bot_upload
```
Then back on the server:
```bash
mkdir -p /tmp/rokugangold
mv /tmp/discord_bot_upload /tmp/rokugangold/discord_bot
```

### 2. Run the setup script

On the server:
```bash
bash /tmp/rokugangold/discord_bot/deploy/setup.sh
```

It will:
- Update the system and install Python
- Create a `rokugan` user (the bot runs as this user, not root)
- Copy the bot code to `/home/rokugan/bot/`
- Install Python dependencies
- **Ask you to paste your Discord bot token** (get it from
  https://discord.com/developers/applications → your app → Bot → Token)
- Set up the bot as a system service (auto-starts on boot, auto-restarts on crash)
- Set up daily database backups
- Turn on the firewall

When it says **"SUCCESS! The bot is running."**: you're done. Go to Discord
and try `/ping`.

---

## Day-to-Day Operations

You don't need to touch the server during normal use. The bot runs itself.
These are for when you *want* to check on it or make changes.

### Connect to the server
```bash
ssh root@96.30.196.68
```

### Is the bot running?
```bash
systemctl status rokugan-bot
```
Green "active (running)" = good. Red = something's wrong (check the logs).

### View live logs
```bash
journalctl -u rokugan-bot -f
```
Press `Ctrl+C` to stop watching. Add `-n 100` to see the last 100 lines.

### Restart the bot
```bash
systemctl restart rokugan-bot
```
Takes ~2 seconds. Players will see slash commands briefly disappear and return.

### Stop the bot
```bash
systemctl stop rokugan-bot
```
Start it again with `systemctl start rokugan-bot`.

---

## Updating the Bot

When you have new code to deploy:

### Option A: If you cloned from GitHub
```bash
ssh root@96.30.196.68
cd /home/rokugan/bot
sudo -u rokugan git pull
# If dependencies changed:
sudo -u rokugan .venv/bin/pip install -r requirements.txt
systemctl restart rokugan-bot
```

### Option B: Upload new files
From your computer:
```bash
scp -r discord_bot/*.py root@96.30.196.68:/home/rokugan/bot/
scp -r discord_bot/l5r_rules root@96.30.196.68:/home/rokugan/bot/
```
Then on the server:
```bash
chown -R rokugan:rokugan /home/rokugan/bot
systemctl restart rokugan-bot
```

---

## Backups

The database (`rokugan.db`) holds all character sheets, DM roles, rooms, and
encounters. It is backed up automatically every day at 04:00 UTC. Backups are
in `/home/rokugan/backups/` and the last 14 days are kept.

### Manual backup (before a risky change)
```bash
sudo -u rokugan /home/rokugan/backup.sh
```

### Restore from backup
```bash
systemctl stop rokugan-bot
cp /home/rokugan/backups/rokugan-YYYYMMDD-HHMM.db /home/rokugan/bot/rokugan.db
chown rokugan:rokugan /home/rokugan/bot/rokugan.db
systemctl start rokugan-bot
```

### Download a backup to your computer
From your computer:
```bash
scp root@96.30.196.68:/home/rokugan/bot/rokugan.db ./rokugan-backup.db
```

---

## Changing the Bot Token

```bash
nano /home/rokugan/bot/.env
```
Change the `DISCORD_BOT_TOKEN=` line, save (`Ctrl+X`, then `Y`, then `Enter`),
and restart:
```bash
systemctl restart rokugan-bot
```

---

## Troubleshooting

### "The bot is offline in Discord"
```bash
ssh root@96.30.196.68
systemctl status rokugan-bot
journalctl -u rokugan-bot -n 50
```
Common causes:
- **Bad token**: check `.env` has the right token
- **Server rebooted**: the bot should auto-start, but check with `systemctl status`
- **Python error**: the logs will show the traceback

### "Commands aren't showing up"
After the first deploy, Discord can take up to 1 hour to sync global commands.
If you set `DISCORD_GUILD_ID` in `.env` to your server's ID, commands appear
instantly (but only on that one server).

### "I need to wipe and start fresh"
```bash
systemctl stop rokugan-bot
rm /home/rokugan/bot/rokugan.db
systemctl start rokugan-bot
```
A new empty database is created automatically on start.

---

## Server Costs

- **Vultr vc2-1c-1gb**: $5/month (1 vCPU, 1 GB RAM, 25 GB SSD)
- The bot uses ~100–150 MB RAM and near-zero CPU
- To stop paying: destroy the instance in the Vultr dashboard (download your
  database backup first!)

---

## File Locations on the Server

| What | Where |
|---|---|
| Bot code | `/home/rokugan/bot/` |
| Bot token | `/home/rokugan/bot/.env` |
| Database | `/home/rokugan/bot/rokugan.db` |
| Database backups | `/home/rokugan/backups/` |
| Systemd service | `/etc/systemd/system/rokugan-bot.service` |
| Backup cron | `/etc/cron.d/rokugan-backup` |
| Logs | `journalctl -u rokugan-bot` |
