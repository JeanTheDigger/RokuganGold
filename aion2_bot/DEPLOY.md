# Deploying the Aion 2 Bot

A plain-English guide. You don't need to know Linux to follow it.

The bot runs on a small Linux server (Ubuntu 24.04), for example a $5/month
Vultr instance. It can share the **same server as the Rokugan bot**: it gets
its own user (`aion2`), folder (`/home/aion2/bot`), service (`aion2-bot`)
and backups (`/home/aion2/backups`), so the two never touch each other.

Below, replace `<server-ip>` with your server's IP address (the same one you
use for the Rokugan bot, if you share the server).

---

## Before you start: create the bot in Discord (5 minutes)

1. Go to <https://discord.com/developers/applications> → **New Application**,
   name it (e.g. "Aion 2 Bot").
2. Open **Bot**:
   - **Reset Token** → copy it and keep it somewhere safe (it's a password).
   - Turn on **Server Members Intent** and **Message Content Intent**. The bot
     won't start without both.
3. Open **OAuth2 → URL Generator**:
   - Scopes: `bot` and `applications.commands`.
   - Bot permissions: **Administrator**.
   - Open the generated link and add the bot to your server.
4. In your Discord server: **Server Settings → Roles** → drag the bot's role
   **to the top** (or at least above every role it creates). If it's lower,
   Discord refuses when it tries to give roles out.

---

## First-time setup on the server (10 minutes)

### 1. Connect

On your computer, open a terminal (Mac/Linux) or PowerShell (Windows):
```bash
ssh root@<server-ip>
```
Type the password from your Vultr dashboard (nothing shows while you type) and
press Enter.

### 2. Get the code onto the server

**If the repository is public** (or you have a GitHub token):
```bash
rm -rf /tmp/rokugangold
git clone https://github.com/jeanthedigger/rokugangold.git /tmp/rokugangold
```

**If it's private**, upload it from your computer instead. In a *second*
terminal on your own computer (not the server):
```bash
scp -r /path/to/RokuganGold/aion2_bot root@<server-ip>:/tmp/aion2_upload
```
Then back on the server:
```bash
mkdir -p /tmp/rokugangold && rm -rf /tmp/rokugangold/aion2_bot
mv /tmp/aion2_upload /tmp/rokugangold/aion2_bot
```

### 3. Run the setup script

```bash
bash /tmp/rokugangold/aion2_bot/deploy/setup.sh
```

It installs everything, then asks two things:
- **Your bot token**: paste it (it won't show) and press Enter.
- **Your server ID** (optional, recommended): makes slash commands appear
  immediately instead of up to an hour later. In Discord: **Settings →
  Advanced → Developer Mode** on, then right-click your server icon → **Copy
  Server ID**. Press Enter to skip.

When it says **"SUCCESS! The Aion 2 bot is running."**, you're done on the server.

### 4. Build the Discord server

In Discord, the **server owner** types `/setup server`. The bot creates the
Head Admin role (and gives it to the owner), the other roles, every category
and channel, and all the panels and buttons. Then:
- Write the rules: `#admin-tools` → **Edit rules**.
- Give your helpers the **Officer** role, if you have any.

---

## First test: checklist

Do this once on a **small test Discord server** before the real one, with a
second Discord account (an "alt") to play the applicant. Each step should work
as described; if one doesn't, the bot usually says why.

1. `/setup server` as the owner → it lists everything it created. Run it again
   → "Nothing was missing".
2. Alt joins → `#arrivals` says "*Alt* entered the server."
3. Alt: `#commander-applications` → **Apply** → fill in a Legion name and a
   color like `200, 30, 60` → a private ticket opens.
4. Owner: **Approve** in the ticket → the alt gets **Legion Commander** and
   **Legion: Name** (name shows in the color), a Legion channel appears with
   its management panel, and the alt now sees **Asmodian Command**.
5. **Close ticket** → a transcript arrives in `#bot-log` **with the alt's
   messages in it** (if they're blank, Message Content Intent is off).
6. `#siege-timer` shows the next siege and updates every minute.
7. `#faction-commander` → **Apply**, and `#siege-alerts` → turn alerts on.
8. `/help` shows the guide; `#how-it-works` shows the same.
9. `#admin-tools` → **Post announcement** → it appears in `#announcements`.
10. Join **War Room** with both accounts: nobody can talk except the Faction
    Commander. (To test that, use `#siege-control` → **Appoint commander** on
    the alt during a siege term, 8:30–11 PM Eastern on a siege day.)

---

## Day-to-day

The bot runs itself: it starts on boot and restarts if it crashes.

```bash
ssh root@<server-ip>
systemctl status aion2-bot      # is it running? green "active (running)" = good
journalctl -u aion2-bot -f      # live log (Ctrl+C to stop watching)
journalctl -u aion2-bot -n 100  # the last 100 log lines
systemctl restart aion2-bot     # restart
systemctl stop aion2-bot        # stop (start again: systemctl start aion2-bot)
```

---

## Updating the bot

Get the new code onto the server (step 2 above), then run the same script:
```bash
bash /tmp/rokugangold/aion2_bot/deploy/setup.sh
```
It copies the new code, installs any new dependencies and restarts. It does
**not** ask for the token again, and never touches your `.env` or database.
If the update added channels or panels, run `/setup server` again in Discord.

---

## Backups

The database `/home/aion2/bot/aion2.db` holds every Legion, membership,
application, vote, setting and the rules text. If it's lost, the bot forgets all
of that (the Discord roles stay, but the bot no longer knows who is in what).

It's backed up automatically **every day at 04:15 UTC** to
`/home/aion2/backups/`, keeping **14 days**.

**Manual backup** (before a risky change):
```bash
sudo -u aion2 /home/aion2/backup.sh
```

**Restore** a backup:
```bash
systemctl stop aion2-bot
cp /home/aion2/backups/aion2-YYYYMMDD-HHMM.db /home/aion2/bot/aion2.db
chown aion2:aion2 /home/aion2/bot/aion2.db
systemctl start aion2-bot
```

**Download a copy to your computer** (run on your computer). Worth doing now
and then: backups on the same server don't help if the server itself is lost.
```bash
scp root@<server-ip>:/home/aion2/bot/aion2.db ./aion2-backup.db
```

---

## Changing the token or server ID

```bash
nano /home/aion2/bot/.env
```
Edit `DISCORD_BOT_TOKEN=` or `DISCORD_GUILD_ID=`, save (`Ctrl+X`, `Y`, `Enter`),
then `systemctl restart aion2-bot`.

---

## Troubleshooting

**The bot is offline in Discord.**
```bash
systemctl status aion2-bot
journalctl -u aion2-bot -n 50
```
- `LoginFailure` / "Improper token": wrong token, so fix it in `.env`.
- `PrivilegedIntentsRequired`: turn on **Server Members Intent** and
  **Message Content Intent** on the Bot page of the Developer Portal, then
  `systemctl restart aion2-bot`.

**Slash commands don't show up.** Without a server ID in `.env`, Discord can take
up to an hour the first time. Add `DISCORD_GUILD_ID=` and restart.

**"Discord refused part of that" / roles aren't given out.** The bot's role must
be above the roles it hands out: **Server Settings → Roles**, drag it to the top.

**Start completely fresh** (deletes everything the bot remembers; back up first):
```bash
systemctl stop aion2-bot
rm /home/aion2/bot/aion2.db
systemctl start aion2-bot
```

---

## Cost

The bot uses roughly 100 MB of memory and almost no CPU, so it fits easily next
to the Rokugan bot on a $5/month Vultr instance (1 vCPU, 1 GB RAM). To stop
paying, destroy the instance in the Vultr dashboard, **after** downloading a
backup.
