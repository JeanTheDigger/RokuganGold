# Rokugan — L5R 4e Discord Bot

A Discord bot that runs Legend of the Five Rings **4th Edition** rules: dice,
character sheets, combat, and NPCs, with a Dungeon Master kept in the loop.

> **This folder is a completely separate project.** It is Python, and it does
> **not** touch the Godot / GDScript game elsewhere in this repository. The
> GDScript is used only as a *reference* that the Python rules were translated
> from — there is no shared code, no imports across the boundary, and running
> this bot changes nothing about the Godot project.

---

## Status: Phase 2 — dice + character sheets + accounts

**Dice**

| Command | What it does |
|---|---|
| `/ping` | Confirms the bot is online (shows gateway latency). |
| `/roll` | Full L5R 4e **Roll & Keep**: `rolled` (X) and `kept` (Y), with optional Target Number, Called Raises (+5 each), flat bonus, Emphasis (reroll 1s once), and an Unskilled flag (dice don't explode). |

**Character sheets** (each sheet is linked to your Discord account, per server)

| Command | What it does |
|---|---|
| `/sheet create` | Make a character (name, optional clan/family/school/type/age) and set it active. Traits start at 2 (the L5R 4e baseline). |
| `/sheet view` | Show a sheet — rings (derived as min of two traits), wounds & wound level, Insight & Rank, standing, gear, skills. `member:` shows another player's (DM only). |
| `/sheet list` | List your characters (active one marked). |
| `/sheet activate` | Choose which of your characters is active. |
| `/sheet trait` | Set a Trait or Void (0–10). |
| `/sheet skill` | Set a skill rank (0 removes it). |
| `/sheet set` | Set a numeric field: honor, glory, status, infamy, taint, koku, age, school rank, void points, armor TN/reduction. |
| `/sheet wound` / `/sheet heal` | Apply or heal wounds; shows the wound-level change. |
| `/sheet delete` | Delete a character. |

**DM (game master) accounts**

| Command | What it does |
|---|---|
| `/dm grant` / `/dm revoke` | Server admins make/unmake a member a DM. |
| `/dm list` | Show this server's DMs. |

A **DM** — a server admin, anyone with *Manage Server*, or a member granted via
`/dm grant` — can `view`, edit (`trait`/`skill`/`set`/`wound`/`heal`), and
`delete` **any** player's active character by adding `member:@player`. Everyone
else can only manage their own. Sheets are scoped **per server**, so one bot can
run many separate games without them mixing.

Still to come in later phases: tables/rooms with invites, combat (`/attack` and
the "player rolls → DM approves damage" flow), NPC templates, and Vultr hosting.

---

## How the code is laid out

```
discord_bot/
├── bot.py                 # Discord plumbing only (slash commands). No game math here.
├── storage.py             # SQLite persistence: characters, active-links, DM roles.
├── l5r_rules/             # Pure-Python L5R 4e rules. No Discord, no Godot. Testable alone.
│   ├── dice.py            # Roll & Keep engine (ported from simulation/dice_engine.gd).
│   ├── character.py       # The playable character sheet (subset of character_data.gd).
│   ├── stats.py           # Derived values: rings, wound levels, Insight (character_stats.gd).
│   ├── enums.py           # Traits/rings/wound tables (enums.gd).
│   └── __init__.py
├── requirements.txt       # Python dependencies.
├── .env.example           # Template for your secret token. Copy to .env.
├── .gitignore             # Keeps .env and the database out of git.
└── README.md              # This file.
```

The database is a single file (`rokugan.db` by default, or set `DB_PATH`). It is
git-ignored and safe to back up by simply copying it.

The split is deliberate: **rules never depend on Discord.** You can run and
check the rules engine on their own with no bot and no internet:

```bash
python3 l5r_rules/dice.py     # runs a built-in validation of the dice rules
```

---

## Step 1 — Create your Discord bot (one time, ~5 minutes)

You do this once, in a web browser. No Linux needed.

1. Go to <https://discord.com/developers/applications> and log in.
2. Click **New Application**, give it a name (e.g. "Rokugan"), and **Create**.
3. In the left sidebar, open **Bot**. Click **Reset Token**, then **Copy** —
   this long string is your **bot token**. Keep it secret (it's a password to
   your bot). You'll paste it into `.env` in Step 2.
   - You do **not** need to turn on any "Privileged Gateway Intents" — this bot
     uses slash commands, which don't require them.
4. In the left sidebar, open **OAuth2 → URL Generator**:
   - Under **Scopes**, tick **`bot`** and **`applications.commands`**.
   - Under **Bot Permissions**, tick **Send Messages** and **Embed Links**
     (more permissions get added in later phases).
   - Copy the generated URL at the bottom, open it in your browser, and pick
     the server you want to add the bot to. (You must have "Manage Server" on
     that server.)

The bot now belongs to your server, but it's offline until you run it (Step 2).

---

## Step 2 — Run it (locally first, to make sure it works)

You can do this on your own computer before ever touching a server. You need
**Python 3.10 or newer** installed.

```bash
# From inside the discord_bot/ folder:

# 1. (Recommended) create an isolated environment so nothing else is affected:
python3 -m venv .venv
source .venv/bin/activate        # on Windows: .venv\Scripts\activate

# 2. install the dependencies:
pip install -r requirements.txt

# 3. create your secret file from the template, then edit it:
cp .env.example .env
#    open .env in any text editor and paste your bot token after
#    DISCORD_BOT_TOKEN=
#    (optional, for instant command updates while testing: also set
#     DISCORD_GUILD_ID to your server's ID — right-click your server icon in
#     Discord with Developer Mode on → "Copy Server ID")

# 4. start the bot:
python3 bot.py
```

You should see a log line like `Logged in as Rokugan#1234 ... Ready.` In your
Discord server, type `/` and you'll see `/ping` and `/roll`.

> If you set `DISCORD_GUILD_ID`, commands appear instantly. Without it, Discord
> can take up to ~1 hour to show global commands the first time.

Try:
```
/roll rolled:7 kept:3
/roll rolled:6 kept:3 tn:20 raises:1 reason:Kenjutsu attack
```

**Stop the bot** with `Ctrl+C`.

---

## Security — the one rule that matters

- **Never share or commit your bot token.** It lives only in `.env`, which
  `.gitignore` already keeps out of git. If it ever leaks, go back to the
  Developer Portal → Bot → **Reset Token** and update `.env`.

---

## What's next (later phases — not built yet)

- **Tables / rooms** — private threads or channels as "rooms," with invites.
- **Combat** — `/attack` against a TN, damage, wounds, armor, and the
  **DM-authorizes-damage** button flow.
- **NPC templates** — generate stat blocks (ashigaru, bandit, bushi…) with
  controlled randomness.
- **Hosting on Vultr** — a small, cheap Linux box with the bot running as a
  background service that restarts itself and survives reboots, plus a
  copy-paste setup script and a plain-English runbook. (You won't need to
  learn Linux to operate it.)
