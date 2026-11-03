# Running the Rokugan Bot on a server

A plain-English guide. You do not need to know Linux to follow it. Every command goes in its own block, so you can copy one at a time.

Replace `YOUR_SERVER_IP` with your server's address from the hosting dashboard.

## How it is laid out

The whole repository lives in one folder, and the bot runs from the `discord_bot` folder inside it. Updating is a `git pull`.

| What | Where |
|---|---|
| The repository | `/home/rokugan/repo/` |
| The bot's code and its home folder | `/home/rokugan/repo/discord_bot/` |
| Bot token and settings | `/home/rokugan/repo/discord_bot/.env` |
| The database (characters, rooms, XP, settings) | `/home/rokugan/repo/discord_bot/rokugan.db` |
| Character portraits | `/home/rokugan/repo/discord_bot/portraits/` |
| Backups | `/home/rokugan/backups/` |
| The service | `/etc/systemd/system/rokugan-bot.service` |
| The backup schedule | `/etc/cron.d/rokugan-backup` |
| Logs | `journalctl -u rokugan-bot` |

The database and the portraits are the only things that cannot be rebuilt from the repository. Everything else comes back with a `git pull`.

---

## First-time setup (about 15 minutes)

You need a fresh Ubuntu 24.04 server, your Discord bot token (Discord Developer Portal, your application, Bot, Reset Token), and access to the GitHub repository.

1. Log in to the server as root. Use an SSH key if you can.

```bash
ssh root@YOUR_SERVER_IP
```

2. Get the code onto the server. If the repository is private, GitHub will ask for a username and a personal access token.

```bash
apt update && apt install -y git
```

```bash
git clone https://github.com/JeanTheDigger/RokuganGold.git /tmp/rokugangold
```

If you cannot clone, upload the folder from your own computer instead. Run this on your computer, not the server:

```bash
scp -r /path/to/RokuganGold root@YOUR_SERVER_IP:/tmp/rokugangold
```

3. Run the setup script.

```bash
bash /tmp/rokugangold/discord_bot/deploy/setup.sh
```

It installs Python, creates a `rokugan` user the bot runs as, moves the repository to `/home/rokugan/repo`, installs the dependencies, asks you to paste your bot token, installs the service so the bot starts on boot and restarts after a crash, schedules the daily backups, turns on the firewall, and runs one test backup.

When it says "SUCCESS! The bot is running." go to Discord and try `/ping`.

If you uploaded with `scp`, the folder has no git history, so `git pull` will not work later. Clone the repository properly instead if you want one-line updates.

---

## Day-to-day

You do not need to touch the server during normal play.

Is the bot running?

```bash
systemctl status rokugan-bot
```

Green "active (running)" is good. Red means something is wrong, so check the log.

Last 50 log lines:

```bash
journalctl -u rokugan-bot -n 50 --no-pager
```

Restart (takes a couple of seconds):

```bash
systemctl restart rokugan-bot
```

Stop, and start again later:

```bash
systemctl stop rokugan-bot
```

```bash
systemctl start rokugan-bot
```

---

## Updating the bot

Update, restart, then check the log. Characters are never touched by an update. They live in the database file, which git ignores.

```bash
cd /home/rokugan/repo && git pull origin main && systemctl restart rokugan-bot
```

```bash
journalctl -u rokugan-bot -n 30 --no-pager | grep -iE "synced|skipped|FAILED|problem|Ready"
```

- "Synced" means the commands changed and were registered with Discord. Players should press Ctrl+R in Discord to see them.
- "Sync skipped" means no command changed, so nobody needs to do anything.
- "FAILED" or "problem" means something is wrong. Copy the line and look into it before players notice.

If `requirements.txt` changed in the update, install the new dependencies before restarting:

```bash
sudo -u rokugan /home/rokugan/repo/discord_bot/.venv/bin/pip install -r /home/rokugan/repo/discord_bot/requirements.txt
```

---

## Backups

Every day at 04:00 UTC the server saves two things into `/home/rokugan/backups/` and keeps the last 14 days:

- `rokugan-YYYYMMDD-HHMM.db`, a consistent copy of the database.
- `portraits-YYYYMMDD-HHMM.tgz`, the uploaded character pictures. This file only appears once someone has uploaded a portrait.

The `.env` file is deliberately not backed up, because it holds your bot token. If you lose it, reset the token in the Discord Developer Portal.

### Check that backups really work

Do this once after setup, and again after any change to the server.

```bash
ls -la /home/rokugan/backups
```

You should see files dated within the last day. The log shows each run, and a failure is spelled out there:

```bash
tail -n 20 /home/rokugan/backups/backup.log
```

### Back up by hand (before a risky change)

```bash
sudo -u rokugan /home/rokugan/repo/discord_bot/deploy/backup.sh
```

### Fix a server that was set up the old way

Older copies of this guide put the bot in `/home/rokugan/bot`, and the old backup script looked for the database there. If your bot runs from `/home/rokugan/repo/discord_bot` instead, the old backup was looking in the wrong place and may have saved nothing. To fix that:

1. Update the code so the new backup script is on the server.

```bash
cd /home/rokugan/repo && git pull origin main
```

2. Confirm where the bot really runs. The `WorkingDirectory` line should say `/home/rokugan/repo/discord_bot`.

```bash
systemctl cat rokugan-bot | grep -E "WorkingDirectory|ExecStart"
```

3. Create the backup folder and schedule the new script.

```bash
mkdir -p /home/rokugan/backups && chown rokugan:rokugan /home/rokugan/backups
```

```bash
echo "0 4 * * * rokugan /home/rokugan/repo/discord_bot/deploy/backup.sh >> /home/rokugan/backups/backup.log 2>&1" > /etc/cron.d/rokugan-backup
```

```bash
chmod 644 /etc/cron.d/rokugan-backup && chmod +x /home/rokugan/repo/discord_bot/deploy/backup.sh
```

4. Run one now and look at the result.

```bash
sudo -u rokugan /home/rokugan/repo/discord_bot/deploy/backup.sh
```

You should see a line starting `backup: ok`. If it says `FAILED. No database at ...`, the bot runs from somewhere else. Set `BOT_DIR` to that folder, in the cron line too.

### Restore from a backup

This replaces every character with the backed-up copy, so be sure. Take a fresh manual backup first.

```bash
systemctl stop rokugan-bot
```

```bash
cd /home/rokugan/repo/discord_bot && rm -f rokugan.db-wal rokugan.db-shm
```

The two files removed there are the database's scratch files. Leaving them behind could mix old changes into the restored copy.

```bash
cp /home/rokugan/backups/rokugan-YYYYMMDD-HHMM.db /home/rokugan/repo/discord_bot/rokugan.db
```

```bash
chown rokugan:rokugan /home/rokugan/repo/discord_bot/rokugan.db
```

If portraits were lost too:

```bash
tar xzf /home/rokugan/backups/portraits-YYYYMMDD-HHMM.tgz -C /home/rokugan/repo/discord_bot && chown -R rokugan:rokugan /home/rokugan/repo/discord_bot/portraits
```

```bash
systemctl start rokugan-bot
```

### Keep a copy off the server

A backup on the same server does not survive losing the server. Now and then, copy the newest files to your own computer. Run this on your computer, not the server:

```bash
scp "root@YOUR_SERVER_IP:/home/rokugan/backups/rokugan-*.db" .
```

---

## Moving the bot to a new server

You keep the same Discord bot, the same token and all your data. Players see a few minutes of downtime. The order matters: the setup script starts the bot when it finishes, and two copies running on one token both answer every command. So stop the old one first.

1. On the old server, stop the bot and make a final backup.

```bash
systemctl stop rokugan-bot
```

```bash
sudo -u rokugan /home/rokugan/repo/discord_bot/deploy/backup.sh
```

2. Copy the newest backups to your own computer. Run these on your computer, not on a server.

```bash
mkdir move
```

```bash
scp "root@OLD_SERVER_IP:/home/rokugan/backups/*" ./move/
```

3. Set up the new server with the first-time steps above, using the same bot token. It starts the bot with an empty database. That is fine, because the next step replaces it.

4. Send the backups to the new server. Run this on your computer.

```bash
scp ./move/* root@NEW_SERVER_IP:/tmp/
```

5. On the new server, restore them with the steps in "Restore from a backup" above, using the files in `/tmp/` instead of the backups folder. If you also want the old portrait pictures, restore the `portraits-` file too.

6. Check the log and try `/ping`. When everything works, leave the old server stopped for a few days, then destroy it.

---

## Adding the bot to another Discord server

One running bot can serve many Discord servers, and each keeps its own characters and settings. You do not need a second copy.

1. In the Developer Portal, open your application, then OAuth2, then URL Generator. Tick the `bot` and `applications.commands` scopes with the same permissions as before, open the link, and pick the new Discord server.
2. Make sure `DISCORD_GUILD_ID` in `.env` is empty or missing. When it is set, the bot registers commands on that one server only.
3. In the new Discord server, as an administrator, run `/setup server`, then set the staff channels with `/dm approval_channel`, `/dm damage_channel`, `/dm log_channel`, `/dm xp_log_channel` and `/dm date_channel`.

A completely separate world needs a second Discord application and token, its own folder, `.env` and database, and its own service.

---

## Changing the bot token

```bash
nano /home/rokugan/repo/discord_bot/.env
```

Change the `DISCORD_BOT_TOKEN=` line, save with `Ctrl+X`, then `Y`, then `Enter`, and restart:

```bash
systemctl restart rokugan-bot
```

---

## Troubleshooting

**The bot is offline in Discord.** Look at the status and the log.

```bash
systemctl status rokugan-bot
```

```bash
journalctl -u rokugan-bot -n 50 --no-pager
```

Common causes: a bad token in `.env`, a Python error shown in the log, or the server rebooted and the service did not start (`systemctl start rokugan-bot`).

**Commands are not showing up.** Press Ctrl+R in Discord. If they are still missing, a Kami can run `/sync`. If you set `DISCORD_GUILD_ID` in `.env`, commands appear on that one Discord server only.

**Characters seem to be gone after an update.** They almost certainly are not. If the bot started from a different folder, it created a new empty database and the old one is still there. Check which database the service uses:

```bash
systemctl cat rokugan-bot | grep -E "WorkingDirectory|DB_PATH"
```

```bash
ls -la /home/rokugan/repo/discord_bot/*.db
```

**The in-game date does not show in #calendar.** Run `/setup server` once so the channel exists, then `/dm setdate`. Since this update the bot finds `#calendar` by itself. If it still cannot post, it tells you why.

### Wiping everything and starting fresh

This permanently deletes every character, room and setting. Do not do this on a live game. Take a manual backup first, even if you are sure.

```bash
systemctl stop rokugan-bot
```

```bash
mv /home/rokugan/repo/discord_bot/rokugan.db /home/rokugan/rokugan-old.db
```

```bash
rm -f /home/rokugan/repo/discord_bot/rokugan.db-wal /home/rokugan/repo/discord_bot/rokugan.db-shm
```

```bash
systemctl start rokugan-bot
```

The `mv` keeps the old database as `rokugan-old.db` instead of deleting it. A new empty database is created on start.

---

## Server costs

- A small server with one CPU core and 1 GB of memory is enough. At Vultr that is about $5 a month.
- The bot uses roughly 100 to 150 MB of memory and almost no CPU.
- To stop paying, destroy the server in your hosting dashboard. Download your newest backups first.
