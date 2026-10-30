# Aion 2 Discord Bot

A Discord bot for an Asmodian faction Discord server in **Aion 2** (NCSoft's MMO):
arrivals, and approval tickets for Legion commanders and Legion members.

> **This folder is a completely separate project.** It shares no code with the
> Godot / GDScript game in this repository, and none with the Rokugan L5R bot
> in `../discord_bot/`. Nothing here imports from, or is imported by, anything
> outside this folder.

- `.gdignore` keeps the Godot editor from scanning or importing this folder.
- `.gitignore` keeps the bot token (`.env`) and the database (`aion2.db`) out of git.

## The server

| Category | Who sees it | Channels |
|---|---|---|
| **Welcome** | everyone, including people with no role | `#arrivals` (read-only: the bot posts "**Name** entered the server."), `#chat` (anyone can talk), `#commander-applications` and `#member-applications` (read-only, each holds an apply button) |
| **Asmodian Command** | approved commanders and members, Head Admin | `#general`, `#pvp-planning` (*draft names*) |
| **Legions** | Head Admin; each Legion's channel is also open to that Legion | one private channel per approved Legion, made automatically |
| **Tickets** | Head Admin; each ticket is also open to the people in it | one private channel per open application, made automatically |
| **Head Admin** | Head Admin only | `#admin-chat`, `#bot-log` (everything the bot does, plus ticket transcripts) |

Roles: **Head Admin**, **Legion Commander**, **Legion Member**, and one
**Legion: Name** role per approved Legion.

## How applications work

**Legion commander.** In `#commander-applications`, click **Apply as Legion
Commander** and fill in your character name, the name of the Legion you lead,
and who you are. A private ticket opens with you and the Head Admin. Only the
Head Admin can approve or deny. Approving approves **the commander and the
Legion together**: the Legion gets its **Legion: Name** role and private
channel, the commander gets **Legion Commander** + that role, and the Legion
now appears in the member application list. If two people claim the same
Legion, the ticket warns the Head Admin; once one is approved, the other cannot
be.

**Legion member.** In `#member-applications`, click **Apply to a Legion**, pick
your Legion from the list of approved ones and fill in your character name. A
private ticket opens with you, the Head Admin and **that Legion's commander**.
**Both** the commander and the Head Admin must click Approve (a person who is
both counts for both). Either may deny. Approved members get **Legion Member** +
their Legion's role, which opens Asmodian Command and their Legion's channel.

**Rules for everyone:**
- One open application at a time, and one Legion per person.
- Nobody can approve their own application.
- A denial can carry a reason. The applicant is told in the ticket and by DM
  (if their DMs are open), and may apply again.
- After a decision the ticket goes read-only for the applicant and commander.
  The Head Admin's **Close ticket** button posts a transcript to `#bot-log`
  and deletes the ticket channel.
- Every button keeps working after the bot restarts.

## Commands

| Command | Who | What it does |
|---|---|---|
| `/setup server` | Head Admin | Creates the roles, categories and channels from `layout.py`, and posts the apply buttons. |
| `/legion list` | anyone | Lists approved Legions, their commanders and how many are approved in each. |

### `/setup server`

- **Who may run it:** members with the **Head Admin** role. On a brand-new
  server with no Head Admin role yet, the **server owner** may run it once; that
  run creates the role and gives it to the owner. After that only Head Admin may
  run it, the owner included.
- **Safe to re-run.** It only creates what is missing. It never deletes,
  renames, moves or changes the permissions of anything that already exists.
  Channels the bot uses (arrivals, the application rooms, tickets, Legions, the
  log) are remembered by ID, so renaming one by hand is fine. If an apply-button
  message was deleted, re-running posts it again. If setup stops partway, running
  it again picks up where it stopped.
- **To change what setup builds, edit `LAYOUT` in `layout.py`.** Setup checks the
  layout first and refuses to run on a broken one (duplicate names, a missing
  required channel, and so on).

## Running it

1. **Create the bot** at the [Discord Developer Portal](https://discord.com/developers/applications):
   New Application → **Bot** → **Reset Token** and copy the token. On the same
   page, turn on **Server Members Intent**. The bot needs it to see people
   join, and won't start without it.
2. **Invite it:** OAuth2 → URL Generator → scopes `bot` and `applications.commands`,
   permission **Administrator**. Open the URL and pick your server. In
   **Server Settings → Roles**, keep the bot's role **above** Head Admin, Legion
   Commander, Legion Member and the Legion roles, or it can't hand them out.
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
| `bot.py` | Entry point: logs in, registers commands and buttons, posts arrivals. |
| `layout.py` | The roles/categories/channels setup builds. Edit this to change the server. |
| `setup_server.py` | The `/setup server` command. |
| `applications.py` | Apply buttons, forms, tickets, approvals, `/legion list`. |
| `roles.py` | Finding roles by name; the bot's own channel permissions. |
| `storage.py` | The SQLite database (`aion2.db`, or the path in `AION2_DB`). |

## Known limits

- Discord allows 50 channels per category, so at most 50 approved Legions and
  50 open tickets at once.
- There are no commands yet to remove a member from a Legion, change a Legion's
  commander or delete a Legion. The bot remembers memberships even if someone
  leaves the server.
