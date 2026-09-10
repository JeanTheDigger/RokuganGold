# Rokugan — L5R 4e Discord Bot

A Discord bot that runs Legend of the Five Rings **4th Edition** rules: dice,
character sheets, combat, and NPCs, with a Dungeon Master kept in the loop.

> **This folder is a completely separate project.** It is Python, and it does
> **not** touch the Godot / GDScript game elsewhere in this repository. The
> GDScript is used only as a *reference* that the Python rules were translated
> from — there is no shared code, no imports across the boundary, and running
> this bot changes nothing about the Godot project.

---

## Status: Phase 8 — + XP / level-up (GDD s48)

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

**Experience & advancement** (costs from **GDD s48**, LOCKED)

The DM controls the XP supply; players spend it to level up. Insight Rank follows
automatically.

| Command | What it does |
|---|---|
| `/xp grant` | DM grants (or corrects) a player's XP. |
| `/xp balance` | Show a character's available/spent XP and Insight Rank. |
| `/xp ring` | Spend XP to raise a Ring (Air/Earth/Fire/Water/Void). Cost = **new rank × 20** XP. |
| `/xp skill` | Spend XP to raise or learn a Skill. Cost = **new rank × 5** XP. |
| `/xp costs` | The s48 cost reference. |

Rings and Skills cap at rank 5. Raising a Ring raises its underlying Trait(s) (the
lower of the pair, or both when equal — the exact `npc_advancement.gd` rule), so
the Ring's value rises by one; **Insight** (`Σrings×10 + skill ranks`) and **Insight
Rank** (150 → Rank 2, then +25/rank, per s48) recompute automatically. Learning a
new Rank *Technique* still needs a dojo/Sensei visit — the DM adjudicates that;
the mechanical advancement is automatic. Every cost traces to s48 — nothing invented.

**Combat — player rolls, DM approves damage**

| Command | What it does |
|---|---|
| `/attack` | Your active character attacks another player's. Rolls **to hit** — `(Agility + weapon skill) keep Agility` (Reflexes for bows) vs the target's **Armor TN** (`Reflexes×5 + 5 + armor`), minus your wound penalty, with raises and stances. |

On a **hit**, the message shows **DM-only buttons**:

- **⚔️ Roll & Apply Damage** — rolls the weapon's damage (`weapon dice + Strength`
  for melee, exploding), subtracts the target's armor **Reduction**, and adds the
  wounds to the target's sheet, announcing any wound-level change (and death).
- **🛡️ No Damage** — the DM rules the blow off.

Only a DM can press them, so the flow is exactly *"a player submits an attack; if
it lands, the DM authorizes the outcome."*

`/attack` options: `weapon` (autocomplete), `raises` (+5 TN each),
`increased_damage` (+5 TN and +1 damage die each), `maneuver`, `spend_void`,
`attacker_stance`, `defender_stance`, and `bonus_tn` (DM situational modifier).

**Maneuvers & Void** (the maneuver's raise cost is added to the TN automatically):

- **Feint** (2 raises) — on a hit, adds bonus damage = ½ the attack margin, capped
  at 5 × Insight Rank.
- **Disarm** (3 raises) — on a hit, deals 2k1 damage and a contested Strength roll;
  win and the target is disarmed.
- **Knockdown** (2 raises) — on a hit, a contested Strength roll; win and the target
  is knocked prone (quadrupeds resist at +4).
- **Spend Void** — `spend_void:true` spends one Void Point for **+1k1** on the attack
  roll (RAW: Void is not valid on damage rolls) and decrements the sheet's pool.

**Initiative tracker** (`/combat`, one encounter per channel)

| Command | What it does |
|---|---|
| `/combat start` | Begin a fresh encounter in this channel. |
| `/combat join` | Add your active character; rolls initiative `(Reflexes + Insight Rank) keep Reflexes`. DMs can add a player with `member:`. |
| `/combat add` | Add an NPC/monster by `name`, `reflexes`, `insight_rank` (rolls its initiative). DM only. |
| `/combat next` | Advance to the next combatant; wraps and bumps the round. |
| `/combat status` | Show the current order and whose turn it is. |
| `/combat remove` / `/combat end` | Drop a combatant / end the encounter. |

Initiative order is in-memory scratch state (a bot restart clears an in-progress
fight; sheets and wounds are in the database and persist).

**NPCs** (generated from **GDD s22.4** — Generation Templates, LOCKED)

| Command | What it does |
|---|---|
| `/npc generate` | DM generates a samurai NPC by `insight_rank` (1–5): Traits/Rings, Honor, Glory, age, and koku all within the s22.4 bands, with random variance so two are never identical. Optional `clan`/`family`/`school` (flavor), `skills` (comma list → distributed per Rank, one specialty), `base_honor`. |
| `/npc view` · `/npc list` · `/npc delete` | View / roster / remove NPCs (delete is DM-only). |
| `/npc trait` · `/npc skill` · `/npc set` · `/npc wound` · `/npc heal` · `/npc rename` | Edit a generated NPC field-by-field (DM only) — same fields as the `/sheet` editors. |

NPCs plug into combat: `/combat npc name:` adds one to initiative, and `/attack`
takes `target_npc:` (fight an NPC) and `attacker_npc:` (a DM runs a monster
against a player). NPCs are stored per server and never mix with player sheets.

*NPC fidelity & limits:* every value traces to s22.4 — nothing invented. Because
s22.4 pulls school-specific skills and Trait bonuses from Sections 27/29 (not
ported), you supply the school **skill names** (`skills:`) and the generator sets
their ranks; Ranks are capped at **1–5** (s22.4 gives no 6+ ranges); koku is the
`1d10 × Rank` savings term only (the role stipend needs role data). Generated
NPCs can be tuned field-by-field with the `/npc` editors above.

*Still faithful-core:* kata, kiho, skill masteries (R3/R5/R7 damage bonuses and
9-explosions), dual-wielding, and thrown/charge/called-shot maneuvers are **not**
modelled — the DM can express those with `raises`/`bonus_tn`.

**Creatures / monsters** (stat blocks transcribed **verbatim** from the bestiaries)

Unlike samurai, a creature attacks and takes damage from a **fixed** stat block
(fixed `XkY` attack/damage, explicit Armor TN and Reduction, and a wound track
that dies at `wounds_dead`).

| Command | What it does |
|---|---|
| `/creature catalog` | Search the bestiary (`search:` by name/id/tag; omit for a category summary). |
| `/creature spawn` | DM spawns a creature instance (give it a `name:` to run several). |
| `/creature list` · `/creature view` · `/creature delete` | Roster / sheet / remove. |
| `/creature wound` · `/creature heal` | Adjust a creature's wounds directly. |
| `/creature attack` | A creature attacks a player/NPC (fixed attack vs their Armor TN); on a hit, a **DM-only** button applies the creature's fixed damage. |

Players fight creatures through the normal `/attack` with `target_creature:` — the
attacker rolls their weapon as usual, and the DM-authorized damage goes onto the
creature's wound track (plain hit or Feint; Disarm/Knockdown against creatures
aren't wired). `/combat creature` drops a spawned creature into initiative.

*The full bestiary is in* — **208 creatures**, transcribed verbatim from the Godot
bestiary files by `tools/extract_bestiary.py` (re-runnable): ~42 animals, ~41
Shadowlands beasts, ~38 oni, ~20 undead, ~53 spirits, plus kenku, tsuno, nezumi,
ningyo, and named antagonists (the Lost). Creatures whose sheet uses the human
wound track (`Earth×2`) are handled correctly; one non-combat environmental
hazard is excluded. `l5r_rules/creature_catalog.py` is generated — don't hand-edit
it; re-run the extractor to refresh.

**Rooms** (private play rooms — each is a Discord **private thread**)

| Command | What it does |
|---|---|
| `/room create` | Opens a private thread as a play room and makes you its host. |
| `/room invite` · `/room kick` | Add/remove a member (run **inside** the room; host or DM only). |
| `/room members` · `/room list` | Who's in this room / all open rooms on the server. |
| `/room close` | Archive the room (host or DM only). |

Because a room *is* a channel, everything else works inside it with no extra
steps — `/sheet`, `/roll`, `/attack`, and `/combat` all just work in the thread,
and each room's initiative tracker is naturally separate (initiative is
per-channel). So a DM can run several games at once in one server, each in its
own room.

Still to come: expanding the bestiary roster, and Vultr hosting.

---

## How the code is laid out

```
discord_bot/
├── bot.py                 # Discord plumbing only (slash commands). No game math here.
├── storage.py             # SQLite persistence: characters, active-links, DM roles.
├── encounter.py           # In-memory initiative tracker (per channel).
├── l5r_rules/             # Pure-Python L5R 4e rules. No Discord, no Godot. Testable alone.
│   ├── dice.py            # Roll & Keep engine (ported from simulation/dice_engine.gd).
│   ├── character.py       # The playable character sheet (subset of character_data.gd).
│   ├── stats.py           # Derived values: rings, wound levels, Insight (character_stats.gd).
│   ├── advancement.py     # XP costs + Ring/Skill raising (GDD s48).
│   ├── combat.py          # Attack/damage/armor-TN core (individual_combat.gd s40).
│   ├── npc_gen.py         # Procedural NPC samurai generator (GDD s22.4, LOCKED).
│   ├── creature.py        # Creature model + combat; loads the generated catalog.
│   ├── creature_catalog.py# AUTO-GENERATED: 208 bestiary stat blocks (verbatim).
│   ├── enums.py           # Traits/rings/wound tables (enums.gd).
│   └── __init__.py
├── tools/
│   └── extract_bestiary.py # Re-runnable transcriber: bestiary .gd → creature_catalog.py.
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
   - Under **Bot Permissions**, tick **Send Messages**, **Embed Links**, and —
     for play rooms — **Create Private Threads**, **Send Messages in Threads**,
     and **Manage Threads**.
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
