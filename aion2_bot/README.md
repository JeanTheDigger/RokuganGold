# Aion 2 Discord Bot

A Discord bot for a faction's Discord server in **Aion 2** (NCSoft's MMO).

> **This folder is a completely separate project.** It shares no code with the
> Godot / GDScript game in this repository, and none with the Rokugan L5R bot
> in `../discord_bot/`. Nothing here imports from, or is imported by, anything
> outside this folder.

- `.gdignore` keeps the Godot editor from scanning or importing this folder.
- `.gitignore` keeps the bot token (`.env`) and local databases out of git.

## Commands

| Command | Who | What it does |
|---|---|---|
| `/setup server` | Head Admin | Creates the server's categories and channels from `layout.py`. |

### `/setup server`

- **Who may run it:** members with the **Head Admin** role (name matched
  ignoring case). On a brand-new server with no Head Admin role yet, the
  **server owner** may run it once: that run creates the Head Admin role and
  gives it to the owner. From then on, only Head Admin may run it, the owner
  included.
- **Safe to re-run.** It only creates what is missing, matched by name. It never
  deletes, renames, moves or changes the permissions of anything that already
  exists, so hand-made channels and edits are left alone. If it stops partway
  (a Discord error), running it again picks up where it stopped.
- **Access levels**, set per category in `layout.py` (a channel can override
  its category's):
  - `public`: everyone sees and posts.
  - `read_only`: everyone reads; only Head Admin (and the bot) post.
  - `admin`: only Head Admin (and the bot) can see it.
- The reply is private to whoever ran it and lists what was created and what
  was already there. The run is also noted in `#bot-log` if that channel exists.

**To change what setup builds, edit `LAYOUT` in `layout.py`.** Setup checks the
layout first (duplicate names, read-only voice channels) and refuses to run on a
broken one. The current layout is a **draft** until the owner gives the real list.

## Running it

1. **Create the bot** at the [Discord Developer Portal](https://discord.com/developers/applications):
   New Application → **Bot** → **Reset Token** and copy the token.
2. **Invite it:** OAuth2 → URL Generator → scopes `bot` and `applications.commands`,
   permission **Administrator** (or at least Manage Channels, Manage Roles, View
   Channels, Send Messages, Manage Messages, Connect, Create Public/Private Threads,
   Send Messages in Threads). Open the URL and pick your server.
3. **Configure:** copy `.env.example` to `.env` and paste the token. Optionally
   set `DISCORD_GUILD_ID` to your server's ID so commands appear instantly.
4. **Run** (Python 3.10+):
   ```
   pip install -r requirements.txt
   python bot.py
   ```
5. In Discord, the server owner runs `/setup server`.

## Files

| File | Purpose |
|---|---|
| `bot.py` | Entry point: logs in, registers and syncs slash commands. |
| `layout.py` | The roles/categories/channels setup builds. Edit this to change the server. |
| `setup_server.py` | The `/setup server` command. |
