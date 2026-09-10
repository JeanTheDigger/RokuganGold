# Rokugan — L5R 4e Discord Bot

A Discord bot that runs Legend of the Five Rings **4th Edition** rules: dice,
character sheets, combat, and NPCs, with a Dungeon Master kept in the loop.

> **This folder is a completely separate project.** It is Python, and it does
> **not** touch the Godot / GDScript game elsewhere in this repository. The
> GDScript is used only as a *reference* that the Python rules were translated
> from — there is no shared code, no imports across the boundary, and running
> this bot changes nothing about the Godot project.

---

## Status: Phase 16 — active-Kata combat effects (GDD s30 & s38)

**Dice**

| Command | What it does |
|---|---|
| `/ping` | Confirms the bot is online (shows gateway latency). |
| `/roll` | Full L5R 4e **Roll & Keep**: `rolled` (X) and `kept` (Y), with optional Target Number, Called Raises (+5 each), flat bonus, Emphasis (reroll 1s once), and an Unskilled flag (dice don't explode). |

**Character sheets** (each sheet is linked to your Discord account, per server)

| Command | What it does |
|---|---|
| `/sheet create` | Make a character and set it active. Pass a `school:` from the catalog (autocomplete) and it **auto-fills** the school's Benefit trait, starting skills (with free emphases), Honor, clan, and type — a Hida Bushi in one command. Any-choice skill slots ("any one Bugei Skill") are reported for you to fill. Without a school, Traits start at 2. |
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

**Experience & advancement** — DMs grant, players spend, tabletop **RAW**

A DM hands out XP; players spend it themselves through the bot. Insight Rank
follows automatically.

| Command | What it does |
|---|---|
| `/xp grant` | **DM** gives (or corrects) a player's XP. |
| `/xp balance` | Show a character's available/spent XP and Insight Rank. |
| `/xp trait` | Raise a Trait or Void. Cost = **new rank × 4** (Void **× 6**). |
| `/xp skill` | Raise or learn a Skill. Cost = **new rank × 1**. |
| `/xp emphasis` | Add a Skill Emphasis. **Flat 2 XP**, max **⌈rank ÷ 2⌉** per skill. |
| `/xp kata` · `/xp kiho` · `/xp spell` | Learn a Kata / Kiho / memorise a Spell. Cost = **1 × Mastery Level** — the name autocompletes and the ML is **auto-filled** from the catalog. `/xp kiho` also takes `non_brotherhood:` (1.5 × ML, rounded up, per s38a). |
| `/xp costs` | The RAW cost reference. |

**Costs are tabletop L5R 4e RAW:** Skill → N×1, Trait → N×4, Void → N×6, Emphasis
flat 2 (capped at ⌈rank÷2⌉), Kata/memorised-Spell → 1×Mastery Level, Kiho → 1×ML
(Brotherhood) or 1.5×ML rounded up (non-Brotherhood, s38a). Traits/Void
cap at rank 5, Skills at 10. RAW raises **Traits** (not Rings), so a Ring only rises
once *both* its Traits do; **Insight** (`Σrings×10 + skill ranks`) and **Insight Rank**
(150 → Rank 2, then +25/rank) recompute automatically.

Kata/Kiho/spell prerequisites (school/ring gating) are DM-adjudicated — the bot
handles the XP economy and records what was bought. Learning a new Rank
*Technique* on advancement is roleplay (a dojo/Sensei visit).

**Kata & Kiho** (all of **GDD s30** and **s38**, transcribed verbatim)

Every Kata and Kiho is in the bot — **43 Kata** and **73 Kiho**, each with element,
Mastery Level, and full effect text (Kata also carry their eligible Schools; Kiho
their Type and Atemi flag).

| Command | What it does |
|---|---|
| `/kata list` · `/kata search` · `/kata view` | Browse Kata by element/Mastery, with Schools and effect. |
| `/kiho list` · `/kiho search` · `/kiho view` | Browse Kiho by element/Mastery, with Type and effect. |
| `/sheet kata` · `/sheet kiho` | Record/remove a Kata or Kiho on the sheet (free) — e.g. one granted at creation. Buy with XP via `/xp kata`/`/xp kiho` instead. |
| `/sheet kata_activate` | Set your **active Kata** (Simple Action; only one active — s30). Blank name drops it. |
| `/sheet kiho_activate` | Activate/deactivate a **Kiho** — one Internal / one Kharmic / one Mystical at a time, Martial stacks (s38). |

`/xp kata` and `/xp kiho` autocomplete real names and **auto-fill the Mastery
Level**, so the RAW cost is computed for you.

**Active-Kata combat effects** — the active Kata (⚑ on the sheet) feeds straight
into `/attack`. The bot auto-applies the **deterministic subset** it can compute
faithfully from the sheet, the chosen stance, the maneuver, and the weapon
(main- and off-hand, via `/sheet wield`) — **14 Kata**:

| Kata | Auto-applied in `/attack` |
|---|---|
| Striking as Air | Defense Stance → target Armor TN **+Air Ring** |
| Reckless Abandon Style | Full Attack Stance → Armor TN **+Fire Ring** |
| Striking as Void | Center Stance → Armor TN **+Void Ring** |
| Lee of the Stone | Defense Stance → Armor TN **+Earth Ring** |
| Iron in the Mountains Style | Defense Stance uses **Earth Ring instead of Air** |
| Strength of the Crane | wielding sword/spear → Armor TN **+max(1, Honor Rank−3)** |
| Strength of the Dragon | katana + wakizashi (daishō) → Armor TN **+3** |
| North Wind Style | Increased Damage maneuver → attack total **+Air Ring** |
| South Wind Style | Knockdown maneuver → attack total **+Air Ring** |
| Iron Forest Style | spear/polearm → attack roll uses **Air Ring, not Agility** |
| Waves upon the Breakers | weapon with 3+ Skill Ranks → damage **+1k0** |
| Strike as the Avalanche | Heavy Weapons skill → **Strength +1 rank** for damage (**+1k0**) |
| Son of Storms | Small melee weapon → target Reduction **−1** |
| Strength of the Crab | Attack Stance + wearing armor → **+2 Reduction** |

Weapon-conditional Kata read what the character is **wielding** — set that with
`/sheet wield weapon: off_hand:` (it also becomes `/attack`'s default weapon).

Everything else stays **DM-adjudicated on purpose** and is surfaced as a reminder
line on the attack, never silently applied or dropped: rate-limited effects
("once per Turn/Round" — the stateless `/attack` has no round tracking), "up to X"
player-choice tradeoffs, and Initiative/movement/mount/ally/guard effects. **All
Kiho** are reminder-only (activation cost — a Void Point or Meditation/Void roll —
and durations are DM-adjudicated); their category limits (one Internal/Kharmic/
Mystical, Martial stacks) *are* enforced by `/sheet kiho_activate`.

**Advantages & Disadvantages** (all of **GDD s45**, transcribed verbatim)

**149 entries** — 86 Advantages, 63 Disadvantages — each with category, point cost,
and full effect text.

| Command | What it does |
|---|---|
| `/advantage list` · `/advantage search` · `/advantage view` | Browse both, with costs and effects. |
| `/xp advantage` | Buy an Advantage with XP (cost = its point value; pass `points:` for Variable-cost ones). |
| `/sheet advantage` · `/sheet disadvantage` | Record/remove on the sheet (free) — e.g. at creation. Taking a Disadvantage tells you the XP it grants; a DM applies that with `/xp grant`. |

**Schools & Techniques** (all of **GDD s29**, transcribed verbatim)

Every school and its techniques are in the bot — **106 schools, 345 techniques**.

| Command | What it does |
|---|---|
| `/school list` | Summary by clan, or `clan:` for that clan's schools. |
| `/school search` | Find schools by name or clan. |
| `/school view` | A school's Benefit, Skills, Honor, Outfit, Affinity, and every Technique (Rank + name + full effect text). |
| `/school learn` | Record the techniques your school grants **up to your School Rank** onto your sheet (RAW: techniques come free with rank at a dojo). Uses your sheet's school, or pass `school_name:`. |

`l5r_rules/schools_catalog.py` is generated by `tools/extract_bestiary.py`'s
sibling `tools/extract_schools.py` (re-runnable) straight from the s29 markdown —
nothing invented. Bushi/monk schools carry the full Rank 1–5 ladder; shugenja
schools carry their Affinity/Deficiency line; advanced/alternate schools carry
their single Technique plus prerequisites.

**Spells** (all of **GDD s32–s37**, transcribed verbatim)

Every spell is in the bot — **287 spells** (Air 68, Water 62, Fire 59, Earth 58,
Void 35, plus universal), each with element, Mastery Level, range, area, duration,
raises, and full effect text.

| Command | What it does |
|---|---|
| `/spell list` | Summary by element, or `element:` for that element's spells grouped by Mastery Level. |
| `/spell search` | Find spells by name, element, or keyword. |
| `/spell view` | A spell's element, Mastery, range/area/duration, raises, and effect. |

`/xp spell` (memorise a spell) autocompletes real spell names and **auto-fills the
Mastery Level** — so the RAW cost (1 × Mastery Level) is computed for you.

**Equipment** (weapons & armor, verbatim from the game data)

| Command | What it does |
|---|---|
| `/weapon list` · `/weapon view` | Browse all **44 weapons** (damage rating, skill, trait, size). |
| `/armor list` | The **7 armor types** with Armor TN bonus and Reduction. |
| `/sheet equip` | Add/remove a weapon on your character's gear list (autocomplete). |
| `/sheet wield` | Set the weapon(s) in hand — `weapon:` (main) and optional `off_hand:`. This is `/attack`'s **default weapon** and gates defender weapon-conditional Kata (Crane, Dragon). `unwield:true` goes unarmed. |
| `/sheet armor` | Equip an armor type — sets the sheet's **Armor TN bonus** and **Reduction** automatically (e.g. Light → +5 TN, Reduction 3; Heavy → +10, 5); `none` removes it. |

Weapon damage (used by `/attack`) and armor Reduction/Armor-TN (used by combat)
now come from the full catalogs — Ashigaru +3/1, Tatami +4/1, Light +5/3, Heavy
+10/5, Tetsu-do +13/8, Riding +4/4, Bogu +0/1.

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
| `/npc generate` | DM generates a samurai NPC by `insight_rank` (1–5): Traits/Rings, Honor, Glory, age, koku within the s22.4 bands, random variance. A `school:` from the catalog (autocomplete) auto-fills the school's skills, Honor, clan, and type (the Benefit is already baked into the s22.4 ring bands, so it isn't re-applied); or set `skills` manually. |
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

*Still faithful-core:* a **deterministic subset of Kata** now auto-applies in
`/attack` (see the Active-Kata table above); the rest of Kata, and all Kiho,
stay DM-adjudicated (shown as reminders). Skill masteries (R3/R5/R7 damage
bonuses and 9-explosions), dual-wielding, and thrown/charge/called-shot maneuvers
are still **not** modelled — the DM can express those with `raises`/`bonus_tn`.

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

Still to come: Vultr hosting (the one original wish-list item left).

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
│   ├── advancement.py     # RAW XP costs: Traits/Void/Skills/Emphasis/Kata/Kiho/Spell.
│   ├── combat.py          # Attack/damage/armor-TN core + full weapon & armor catalogs.
│   ├── npc_gen.py         # Procedural NPC samurai generator (GDD s22.4, LOCKED).
│   ├── creature.py        # Creature model + combat; loads the generated catalog.
│   ├── creature_catalog.py# AUTO-GENERATED: 208 bestiary stat blocks (verbatim).
│   ├── schools.py         # Access helpers over the school catalog (GDD s29).
│   ├── schools_catalog.py # AUTO-GENERATED: 106 schools + 345 techniques (verbatim).
│   ├── spells.py          # Access helpers over the spell catalog (GDD s32-s37).
│   ├── spells_catalog.py  # AUTO-GENERATED: 287 spells (verbatim).
│   ├── advantages.py      # Access helpers over the advantage catalog (GDD s45).
│   ├── advantages_catalog.py # AUTO-GENERATED: 149 advantages/disadvantages (verbatim).
│   ├── kata.py            # Access helpers over the kata catalog (GDD s30).
│   ├── kata_catalog.py    # AUTO-GENERATED: 43 Kata (verbatim).
│   ├── kata_effects.py    # Deterministic active-Kata combat modifiers for /attack (GDD s30).
│   ├── kiho.py            # Access helpers over the kiho catalog (GDD s38).
│   ├── kiho_catalog.py    # AUTO-GENERATED: 73 Kiho (verbatim).
│   ├── enums.py           # Traits/rings/wound tables (enums.gd).
│   └── __init__.py
├── tools/
│   ├── extract_bestiary.py # Re-runnable transcriber: bestiary .gd → creature_catalog.py.
│   ├── extract_schools.py  # Re-runnable transcriber: GDD s29 → schools_catalog.py.
│   ├── extract_spells.py   # Re-runnable transcriber: GDD s32-s37 → spells_catalog.py.
│   ├── extract_advantages.py # Re-runnable transcriber: GDD s45 → advantages_catalog.py.
│   └── extract_kata_kiho.py # Re-runnable transcriber: GDD s30/s38 → kata_catalog.py, kiho_catalog.py.
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
