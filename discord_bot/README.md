# Rokugan — L5R 4e Discord Bot

A Discord bot that runs Legend of the Five Rings **4th Edition** rules: dice,
character sheets, combat, and NPCs, with a Dungeon Master kept in the loop.

> **This folder is a completely separate project.** It is Python, and it does
> **not** touch the Godot / GDScript game elsewhere in this repository. The
> GDScript is used only as a *reference* that the Python rules were translated
> from — there is no shared code, no imports across the boundary, and running
> this bot changes nothing about the Godot project.

---

## Status: Phase 44 — DM-Gated Effect Pipeline

**Help & Navigation**

| Command | What it does |
|---|---|
| `/help` | Categorized command reference — 13 categories, expandable. Shows a compact overview or drill into one category. Ephemeral (only you see it). |
| `/whoami` | Quick glance at your active character: name, school, rings, wounds, VP, wielded weapon, active Kata, and combat conditions (if in an encounter). Ephemeral. |
| `/lookup` | Unified search across **all** catalogs (spells, schools, kata, kiho, advantages, weapons, creatures). Find anything without knowing which command to use. Ephemeral. |

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
| `/dm new_day` | **DM** advances the in-game day: full VP refresh, natural healing (Stamina x 2 wounds), and spell slot refresh (Ring + School Rank per element) for all active PCs. No real-time connection — the DM decides when a new day dawns. |
| `/dm damage` | **DM** applies raw damage to any PC or NPC — posts the pending effect publicly with Approve / Deny buttons. Damage respects Reduction. |
| `/dm heal` | **DM** heals wounds on any PC or NPC — posts pending healing with Approve / Deny buttons. |
| `/party` | DM-only roster of every active PC: school, rings, wounds, VP, honor/glory/status, wielded weapon. Gold embed with player mention. |

A **DM** — a server admin, anyone with *Manage Server*, or a member granted via
`/dm grant` — can `view`, edit (`trait`/`skill`/`set`/`wound`/`heal`), and
`delete` **any** player's active character by adding `member:@player`. Everyone
else can only manage their own. Sheets are scoped **per server**, so one bot can
run many separate games without them mixing.

**DM-gated effect pipeline** — all rolls and calculations are free and automatic,
but **applying any effect that changes another character's state** (damage,
healing, conditions) requires explicit DM approval. The bot calculates everything,
posts the result publicly in the channel with the relevant rule, and presents
Approve / Deny buttons that only a DM can click. This applies to:

- **Attack damage** (`/attack` → DM clicks "Roll & Apply Damage" or "Deny")
- **Spell damage** (`/spell_damage` with `target:` → DM clicks "Apply Damage" or "Deny")
- **Creature attacks** (`/creature attack` → DM clicks "Apply Creature Damage" or "No Damage")
- **Arbitrary damage** (`/dm damage` → DM clicks "Apply Damage" or "Deny")
- **Healing** (`/dm heal` → DM clicks "Apply Healing" or "Deny")

No damage, wounds, or healing are applied without DM authorization. There is no
automatic connection between real time and in-game time — the DM pushes day
advancement via `/dm new_day`.

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
| `/xp advantage` | Buy an Advantage with XP (cost = its point value). |
| `/xp remove_disadvantage` | Buy off a Disadvantage with XP. Cost = **2 × point value** (L5R 4e RAW). |
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

**Rate-limited Kata — enforced while a `/combat` encounter is running.** The
initiative tracker now carries real round/turn state (it resets each combatant's
*once-per-Turn* abilities when their turn begins and everyone's *once-per-Round*
abilities at the top of a new Round). When the attacker is a combatant in the
channel's encounter, `/attack` applies these and marks them spent; attack again
in the same Turn/Round and it says "already used." **Without** a tracked
encounter the bot can't count rounds, so they fall back to a DM reminder:

| Kata | Enforced effect |
|---|---|
| Striking as Fire | Full Attack → **+Fire Ring** to one attack **per Round** |
| Strength in Arms Style | Heavy Weapon → **Strength** replaces Agility on one attack **per Turn** |
| Strength of the Scorpion | after a Feint → **+3 damage**, once **per Turn** |
| Power of the Tsunami | ignore **Water Ring** of Reduction, once **per Round** |

Everything else stays **DM-adjudicated on purpose** and is surfaced as a reminder
line on the attack, never silently applied or dropped: the remaining rate-limited
effects (those that also need a chosen target or an opponent-debuff the bot
doesn't model), "up to X" player-choice tradeoffs, and Initiative/movement/mount/
ally/guard effects. **Most
Kiho** remain DM-adjudicated reminders (activation cost — a Void Point or
Meditation/Void roll — and durations are DM-adjudicated); their category limits
(one Internal/Kharmic/Mystical, Martial stacks) *are* enforced by
`/sheet kiho_activate`. The **6 deterministic Kiho** whose effects the bot can
compute faithfully are auto-applied (see the Kiho combat effects table below);
auto-applied Kiho are suppressed from the reminder list to reduce noise.

**Advantages & Disadvantages** (all of **GDD s45**, transcribed verbatim)

**149 entries** — 86 Advantages, 63 Disadvantages — each with category, point cost,
and full effect text.

| Command | What it does |
|---|---|
| `/advantage list` · `/advantage search` · `/advantage view` | Browse both, with costs and effects. |
| `/xp advantage` | Buy an Advantage with XP (cost = its point value; pass `points:` for Variable-cost ones). |
| `/sheet advantage` · `/sheet disadvantage` | Record/remove on the sheet (free) — e.g. at creation. Taking a Disadvantage tells you the XP it grants; a DM applies that with `/xp grant`. |

**Auto-applied Advantage & Disadvantage combat effects** — when a character has
one of the entries below, `/attack` applies the modifier automatically, the same
way it does for Kata and Techniques (`l5r_rules/advantage_effects.py`). **12
effects across 10 entries:**

| Advantage / Disadvantage | Auto-applied in `/attack` |
|---|---|
| Large | melee with a Large weapon → damage **+1k0** |
| Hands of Stone | unarmed → damage **+0k1** |
| Small | melee → damage **−1k0** |
| Bad Eyesight | ranged attack → attack roll **−1k1** |
| Blind | melee attack **−1k1**; ranged attack **−3k3**; defender Armor TN base = **Reflexes + 5** (not ×5) |
| Strength of the Earth | wound penalties **reduced by 3** |
| Low Pain Threshold | wound penalties **increased by 5** |
| Permanent Wound | always at least **Nicked** wound level (applied in wound calculation) |
| Touch of the Spirit Realms: Jigoku | attack roll **+Taint Rank** flat |
| Touch of the Spirit Realms: Gaki-do | on kill, attacker **heals 5 Wounds** |
| Seven Fortunes' Curse: Bishamon | damage **−1k0** (Strength −1) |
| Bishamon's Blessing | 3+ Increased Damage raises → **+1k0** extra damage (one bonus raise) |

Everything else from GDD s45 stays **DM-adjudicated** — Quick (Initiative),
Prodigy (school-skill detection), Sacred Weapons (weapon identity beyond name),
Crab Hands (unskilled fallback), movement penalties (Blind, Small, Lame),
Missing Limb, Weakness/Doubt (parameterised skills/traits), Momoku/Consumed/
Failure of Bushido (Void-spend restrictions), and Magic Resistance (spell
combat not modelled).

**Auto-applied Kiho combat effects** — when a character has one of the kiho
below **active** (`/sheet kiho_activate`), `/attack` applies the modifier
automatically (`l5r_rules/kiho_effects.py`). **6 effects across 6 kiho:**

| Kiho | Auto-applied in `/attack` |
|---|---|
| Soul of the Four Winds | defender Armor TN **+Insight Rank + Air Ring** |
| Musubi | defender Armor TN **+Water Ring + Staves Rank** (staff equipped) |
| Embrace the Stone | defender Reduction **+Earth Ring x2** |
| Partaking the Waters | defender Reduction **+Water Ring** |
| Grasp the Earth Dragon | attacker wound penalties **reduced by Earth Ring** |
| Air Fist | unarmed damage **−Air Ring** flat (tradeoff for +5 Initiative) |

Everything else from GDD s38 stays **DM-adjudicated** — atemi-delivered effects
(Rolling Avalanche, Flame Fist, Censure of Thunder, etc.), reactive abilities
(Destiny's Strike, Way of the Willow), duration-tracked debuffs (Stain Upon the
Soul, Earth Palm), cumulative tracking (Rising Mountain), action-economy changes
(Dance of the Flames), and non-combat effects. Auto-applied kiho are suppressed
from the reminder line to reduce noise.

**Auto-applied Condition effects** — when a combatant has a condition set via
`/combat condition_set`, `/attack` applies the modifier automatically
(`l5r_rules/condition_effects.py`). Successful Knockdown maneuvers auto-set
Prone on the target. **15 effects across 7 conditions:**

| Condition | Auto-applied in `/attack` |
|---|---|
| Blinded | attacker: melee **−1k1**, ranged **−3k3**; defender Armor TN = **Reflexes + 5 + armor** |
| Dazed | attacker: **−3k0** to all actions |
| Fatigued | attacker: **+5 TN** (applied as −5 flat to attack roll) |
| Grappled | defender: Armor TN = **5 + armor bonus** |
| Mounted | attacker: **+1k0** attack rolls (vs unmounted/lower) |
| Prone | defender: **−10** Armor TN vs melee; attacker: **−2k0** with Medium/Small, **cannot attack** with Large |
| Stunned | defender: Armor TN = **5 + armor bonus** |

**Entangled** is reminder-only (break-free TN set by DM). Each condition also
displays non-auto-applied reminders (movement restrictions, stance limits,
recovery rolls) in the DM-adjudicates section of the attack embed. Conditions
are transient per-encounter state on the Combatant — they are cleared when the
encounter ends, not persisted to the database.

**Schools & Techniques** (all of **GDD s29**, transcribed verbatim)

Every school **and path** and its techniques are in the bot — **347 entries**
(**108 Basic Schools · 26 Advanced Schools · 213 Alternate Paths**) with
**647 techniques**. Each entry is tagged with its `category`.

| Command | What it does |
|---|---|
| `/school list` | Overall summary (basic/advanced/alternate + per-clan counts), or `clan:` for that clan's entries grouped by category. |
| `/school search` | Find schools/paths by name or clan (each tagged basic / adv / path). |
| `/school view` | An entry's Benefit, Skills, Honor, Outfit, Affinity, Prerequisites, and every Technique (Rank + name + full effect text). |
| `/school learn` | Record the techniques your school grants **up to your School Rank** onto your sheet (RAW: techniques come free with rank at a dojo). Uses your sheet's school, or pass `school_name:`. |

Only **Basic Schools** appear in `/sheet create` and `/npc generate` autocomplete
(you start as a Basic School; Advanced Schools and Alternate Paths are transitions
a character moves into later).

**Auto-applied Technique effects** — the techniques a character has recorded
(`/school learn`) feed into `/attack`. The bot auto-applies **every s29 Technique
whose condition it can actually evaluate** — a modifier gated only on stance, the
weapon, armour worn, an Initiative or Honor comparison, or a trait scalar —
**36 techniques** in all (`l5r_rules/technique_effects.py`). The remaining ~600
turn on things the engine can't know (target type — "vs Shadowlands / unaware",
mounted, duels, grapples, terrain, multiple opponents, allies), are
reactive / Void-gated / "once per X", need player choice, or need systems the bot
doesn't model (spells, tattoos, mass battle, conditions, kiho) — those stay
**DM-adjudicated**, full text on the sheet via `/school view`.

The 36 span: attack-roll dice/flat (Torch's Flame Flickers, The Force of Honor,
The Way of the Crane, Always Be Ready, The Subtle Sting, Togashi Tattooed Order,
Temper Steel With Honor, Magari-Yarijutsu, To Defend Unto Death, Matsu's Courage,
Speed of Lightning †, Fast and Furious †); a Trait override (Spotting the Prey —
Perception for bows); damage dice/flat (The Way of the Crab, The Way of the
Unicorn, The Arrow Knows the Way, The Hand of Thunder, The Lion's Roar, The Face
of Justice, Strength of the Forest, Aligned With the Elements); Reduction ignored
(Strike Like the Lion, Harmony and Precision, Crushing Blow); defender Armor TN
(Drawing the Void, The Fury of Matsu, Tamedaore's Secret, Kitsuki's Method,
Harmony, Temper Steel With Honor, Way of the Dragon, The Way of the Scorpion †,
Wing of Thunder †, Purity of Chi); and defender Reduction (The Mountain Does Not
Move, Hida's Strength, Honor Is My Shield, Aligned With the Elements).

† Initiative-comparison techniques apply only while both combatants are in the
channel's `/combat` encounter (so the tracker knows their Initiative); untracked,
they fall back to DM adjudication. Each auto-applied effect is shown by name on
the attack. Techniques stack (a character holds every technique up to their School
Rank), so all a character's qualifying techniques apply together, alongside any
active Kata.

`l5r_rules/schools_catalog.py` is generated by `tools/extract_schools.py`
(re-runnable) straight from the s29 markdown — nothing invented. It handles every
technique shape in the source: the `- Rank N — Name:` ladder, dash- and inline
`Technique —` paths, the compressed `Rank 1: … Rank 2: …` monk line, and the
`- Technique: Name — effect` shugenja form. s29.15 (the LOCKED courtier framework)
is skipped — its two schools already appear in the clan files.

**Weapon Skill Masteries** (GDD s24, auto-applied in `/attack`)

Every weapon skill has mastery abilities at Ranks 3, 5, and 7. The bot
auto-applies the **18** whose conditions it can evaluate from the sheet, the
weapon, and the encounter state (`l5r_rules/skill_mastery.py`):

| Skill | Rank | Auto-applied in `/attack` |
|---|---|---|
| Kenjutsu | 3 | sword damage **+1k0** |
| Kenjutsu | 7 | sword damage dice **explode on 9+** |
| Jiujutsu | 3 | unarmed damage **+1k0** |
| Jiujutsu | 7 | unarmed damage **+0k1** |
| Heavy Weapons | 3 | target Reduction **−2** |
| Heavy Weapons | 5 | **free raise** toward Knockdown |
| Heavy Weapons | 7 | damage dice **explode on 9+** |
| Kyujutsu | 7 | bow damage **+1k0** (Strength +1) |
| Spears | 3 | target Reduction **−3** (first round only †) |
| Ninjutsu | 3 | damage **+1k0** |
| Ninjutsu | 5 | damage dice **explode normally** (overrides default no-explode) |
| Ninjutsu | 7 | damage **+0k1** |
| Staves | 5 | **free raise** toward Knockdown |
| Staves | 7 | small staves damage **+1k0** |
| Knives | 5 | **free raise** toward Disarm (sai/jitte only) |
| Chain Weapons | 7 | **free raise** toward Disarm or Knockdown |
| War Fan | 5 | defender Armor TN **+1** |
| War Fan | 7 | defender Armor TN **+3** |

† Spears R3 fires only when the encounter is in round 1; without a tracked
encounter it falls back to DM adjudication.

Ninjutsu weapons (shuriken, tsubute, blowgun) do **not** explode by default
(s24) — this is now correctly modeled. Ninjutsu R5 overrides it.

Mastery abilities that need systems the bot doesn't model (off-hand penalties,
extra attacks, grappling, range, ready actions) or need per-round initiative
changes (Polearms R3 +5 Init) stay **DM-adjudicated**.

**Spells** (all of **GDD s32–s37**, transcribed verbatim)

Every spell is in the bot — **287 spells** (Air 68, Water 62, Fire 59, Earth 58,
Void 35, plus universal), each with element, Mastery Level, range, area, duration,
raises, and full effect text.

| Command | What it does |
|---|---|
| `/spell list` | Summary by element, or `element:` for that element's spells grouped by Mastery Level. |
| `/spell search` | Find spells by name, element, or keyword. |
| `/spell view` | A spell's element, Mastery, range/area/duration, raises, and effect. |
| `/spell cast` | Cast a spell: rolls **(Ring + School Rank) keep Ring** vs TN **5 + (5 × Mastery Level)**. Affinity +1 / Deficiency −1 effective rank. Supports Void Point (+1k1), Called Raises (+5 TN each, reduce casting time), wound penalty. **Spell slots** (Ring + School Rank per element per day) are consumed on cast — whether the roll succeeds or fails. Refresh slots with `/dm new_day`. DMs can cast for NPCs or other players. |

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
- **Called Shot** (1–4 raises via `raises:`) — targets a body part (1=limb, 2=hand/foot,
  3=head, 4=eye/ear/finger). Normal damage; the embed notes the targeted part and the
  DM rules on the effect of sufficient damage.
- **Extra Attack** (5 raises) — on a hit, damage resolves normally, then a free second
  attack roll fires automatically (no raises, same weapon). The 2nd attack can miss.
  Once per Turn (enforced by the encounter tracker).
- **Spend Void** — `spend_void:true` spends one Void Point for **+1k1** on the attack
  roll (RAW: Void is not valid on damage rolls) and decrements the sheet's pool.
- **Armor penalty** — Heavy armor imposes **−5** on the attack roll (Agi/Ref skill
  TN +5); Tetsu-Do imposes **−10** (or **−5** if Strength ≥ 5). Hida Bushi R1
  ("The Way of the Crab") ignores these penalties. Light/Ashigaru/Riding armor
  have no attack penalty. Auto-applied when the attacker has armor equipped.

**Initiative tracker** (`/combat`, one encounter per channel)

| Command | What it does |
|---|---|
| `/combat start` | Begin a fresh encounter in this channel. |
| `/combat join` | Add your active character; rolls initiative `(Reflexes + Insight Rank) keep Reflexes`. DMs can add a player with `member:`. |
| `/combat add` | Add an NPC/monster by `name`, `reflexes`, `insight_rank` (rolls its initiative). DM only. |
| `/combat next` | Advance to the next combatant; wraps and bumps the round. |
| `/combat status` | Show the current order and whose turn it is. |
| `/combat remove` / `/combat end` | Drop a combatant / end the encounter. |
| `/combat condition_set` | Apply a condition to a combatant (DM only). 8 choices: Blinded, Dazed, Entangled, Fatigued, Grappled, Mounted, Prone, Stunned. |
| `/combat condition_clear` | Remove a condition from a combatant (DM only). |
| `/combat conditions` | Show a combatant's active conditions and their DM-adjudicated effects. |
| `/combat guard` | Guard another combatant (DM only). Ward gets +10 Armor TN, guarder gets −5. Clears on guarder's next turn. |
| `/combat full_defense` | Full Defense (DM only). Rolls Defense/Reflexes, adds half (rounded up) to Armor TN until next turn. Complex Action. |
| `/combat summary` | Compact DM-only overview of all combatants: wounds, wound level, Armor TN, VP, conditions, guards, and Full Defense — at a glance. Ephemeral. |

Initiative order is in-memory scratch state (a bot restart clears an in-progress
fight; sheets and wounds are in the database and persist). Each combatant also
carries **round/turn usage state**, **active conditions**, and **guard state** —
`/combat next` resets the incoming actor's once-per-Turn abilities, guard
assignment, and, at the top of a new Round, everyone's once-per-Round abilities —
which is what lets `/attack` enforce rate-limited Kata (see the Active-Kata
section). Conditions display inline in the initiative listing (e.g. `[dazed,
prone]`), active guards show as `🛡️→WardName`, and Full Defense as
`🛡️FD+N`.

**Grappling** (`/grapple`, all DM-only — s40 Grappling rules)

| Command | What it does |
|---|---|
| `/grapple initiate` | Initiate a grapple: Jiujutsu/Agility vs Armor TN (ignoring armor bonus). On success, both combatants gain the **Grappled** condition; initiator has control. |
| `/grapple control` | Contested Jiujutsu/Strength roll between two grapple participants. Winner has control until the next Turn. |
| `/grapple hit` | Grapple Hit (controller only): unarmed damage (1k1+Str) on a grappled opponent. No attack roll — DM authorizes damage via the standard button flow. |
| `/grapple throw` | Throw a grappled opponent: target becomes **Prone** and leaves the grapple. |
| `/grapple break_free` | Break free from a grapple (controller's Simple Action): removes the Grappled condition. |

**Iaijutsu dueling** (`/duel`, all DM-only — s40 Iaijutsu rules)

| Command | What it does |
|---|---|
| `/duel assess` | Assessment: both duelists roll Iaijutsu(Assessment)/Awareness vs TN 10 + opponent's Insight Rank × 5. On success, learn opponent's Void, Reflexes, Iaijutsu, emphases, VP, or wound level (+1 per Raise). If one exceeds the other by 10+, that duelist gains +1k1 on Focus. |
| `/duel focus` | Focus: contested Iaijutsu(Focus)/Void roll. Winner by 5+ strikes first; +1 Free Raise per additional 5. Neither by 5 → Kharmic Strike (simultaneous, cause dropped). |
| `/duel strike` | Strike: Iaijutsu/Reflexes attack vs normal Armor TN. Free Raises from Focus apply as Increased Damage. On hit, DM-authorized damage via the standard button flow (default weapon: katana). |

**Contested checks, Fear, and Honor rolls** (all DM-only)

| Command | What it does |
|---|---|
| `/contest` | Contested Skill/Trait roll between two characters. Each side rolls **(Trait + Skill) keep Trait** with per-side explode (skilled only), wound penalties, and optional flat bonuses. Supports encounter combatants, NPCs, and players. |
| `/fear` | Fear check: **Willpower vs TN 5 + (Fear Rank × 5)**. Raw Willpower roll (no explosion). |
| `/honor_roll` | Honor Roll: **Honor Rank dice, keep 1** vs a DM-set TN. Resists temptation or dishonor. |

**Void Point management** (`/void`)

| Command | What it does |
|---|---|
| `/void spend` | Spend a Void Point with a reason label (+1k1, negate conditional, etc.). Tracks VP. Players can spend their own; DMs can spend for NPCs/other players. |
| `/void refresh` | Recover VP: **Rest** (full refresh) or **Meditation** (Meditation/Void check vs TN, recovers 1 VP on success). |
| `/void status` | Show current VP with a visual bar. |

**Poison & Medicine** (DM-only)

| Command | What it does |
|---|---|
| `/poison` | Poison resistance: **Stamina vs TN (Strength × 5)**. Raw Stamina roll (no explosion). Optional poison name for display. |
| `/medicine` | Medicine/Intelligence check vs a DM-set TN. Treats wounds, poison, disease, etc. Explodes only if skilled. |

**Skill checks — Stealth, Investigation, Social, Craft, Lore** (all DM-only)

Six commands that all use the same engine: `(Trait + Skill) keep Trait` vs TN,
exploding only when skilled (skill rank > 0). Wound penalty auto-applied. Each
uses `resolve_skill_check` in `combat.py` and the shared `_build_check_embed`
helper for a consistent three-field embed (Roll / Dice / Result).

| Command | What it does |
|---|---|
| `/skillcheck` | **Universal** skill check — DM picks the trait (dropdown) and skill name (autocomplete from sheet; rank read automatically). For anything not covered by a dedicated command. |
| `/stealth` | **Stealth/Agility** vs TN. Auto-reads the Stealth skill from the sheet. Verdict: "Undetected!" / "Spotted!" |
| `/investigate` | **Investigation/Perception** vs TN. Optional emphasis choice (Notice, Interrogation, Search) — checks the sheet for a matching emphasis and adds a footer reminder about emphasis rerolls. |
| `/social` | **Social skill** dropdown (Courtier, Etiquette, Intimidation, Temptation, Sincerity, Perform) — auto-selects the correct trait per L5R 4e rules (Awareness for most, Willpower for Intimidation). |
| `/craft` | **Artisan or Craft / Intelligence** vs TN. Skill name autocompletes from sheet (e.g. "Artisan: Painting", "Craft: Weaponsmithing"). |
| `/lore` | **Lore / Intelligence** vs TN. Specialty autocompletes from sheet (e.g. "Lore: Heraldry", "Lore: Shadowlands"). |

All six support `member:` (DM targets a player's active character), `is_npc:`
(look up by name), `bonus:` (flat modifier for advantages, tools, etc.), and
`reason:` (label shown with the roll). The opposed-check use case (e.g.
Stealth vs Investigation) is already handled by `/contest`.

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

*Still faithful-core:* deterministic subsets of **Kata**, **School Techniques**,
**Skill Masteries**, **Advantages/Disadvantages**, **Kiho**, and **Conditions**
now auto-apply in `/attack` (see the tables above); the rest of Kata, most
Techniques, and most Kiho stay DM-adjudicated (shown as reminders; technique
text on the sheet via `/school view`). **Void Point damage reduction** adds a
second button on every hit — DM clicks "Void Reduce" to spend 1 VP and subtract
10 wounds from the target (L5R 4e core rule). The button is hidden for creature
targets (no VP) and knockdown maneuvers (no damage). **Called Shot** (1–4 raises)
labels the targeted body part in the damage embed; **Extra Attack** (5 raises)
auto-fires a second attack roll after the first hit resolves (once per Turn);
**Guard** (`/combat guard`) assigns a ward (+10 TN) and penalizes the guarder
(−5 TN), clearing on the guarder's next turn. **Armor attack penalties** (s39)
auto-apply: Heavy −5, Tetsu-Do −10 (−5 if Str ≥ 5); Hida Bushi R1 is exempt.
**Full Defense** (`/combat full_defense`) rolls Defense/Reflexes and adds half
(rounded up) to Armor TN until the combatant's next turn — a Complex Action.
**Grappling** (`/grapple`) covers the full subsystem: initiate (Jiujutsu/Agility
vs TN ignoring armor), contested control rolls, Hit (unarmed damage via DM
buttons), Throw (Prone + leave grapple), and Break Free.
**Spell Casting** (`/spell cast`) rolls (Ring + School Rank) keep Ring vs TN
5 + (5 × Mastery Level), with Affinity (+1 effective rank) and Deficiency (−1),
Void Point (+1k1), Called Raises (+5 TN each, reduce casting time by 1 per
raise), and wound penalty. **Spell slots** are tracked per element: max = Ring +
School Rank per day, consumed on each cast (success or failure). DM refreshes all
slots and heals wounds via `/dm new_day` — no connection between real time and game
time. Players cast their own spells; DMs can cast for NPCs or other players.
**Iaijutsu Dueling** (`/duel`) covers the full three-stage formal duel:
Assessment (Iaijutsu/Awareness, reveals opponent stats, +1k1 Focus bonus if
exceeded by 10+), Focus (contested Iaijutsu/Void, winner by 5+ strikes first
with Free Raises per additional 5, otherwise Kharmic Strike), and Strike
(Iaijutsu/Reflexes attack vs normal Armor TN, Free Raises as Increased Damage,
DM-authorized damage via buttons) — DM only.
**Contested Checks** (`/contest`) handle any opposed Skill/Trait roll between
two characters, with per-side explode, wound penalties, and flat bonuses.
**Fear Checks** (`/fear`) roll Willpower vs TN 5 + Fear Rank × 5.
**Honor Rolls** (`/honor_roll`) roll Honor Rank dice, keep 1, vs a DM-set TN.
**Void Point Management** (`/void`) tracks VP spending (with reason labels),
rest recovery (full refresh), and Meditation/Void checks (recover 1 on success).
**Poison Resistance** (`/poison`) rolls Stamina vs TN Strength × 5.
**Medicine Checks** (`/medicine`) roll Medicine/Intelligence vs a TN for treatment.
Dual-wielding and thrown/charge maneuvers are still **not** modelled — the DM
can express those with `raises`/`bonus_tn`.

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

**Phase 42 — Stances, Action Economy, and Remaining Mechanics**

| Command | What it does |
|---|---|
| `/combat stance` | Declare stance for the round: Attack, Full Attack (−10 ATN, +2k1), Defense (+Air+Defense ATN), Full Defense (Complex Action), Center (+Void ATN, +1k1 next turn). Resets on turn advance. |
| `/combat action` | Track Simple/Complex action usage per turn. L5R 4e: 1 Complex OR 2 Simple per turn. |
| `/combat init` | **DM** adjusts a combatant's initiative mid-combat (covers re-rolls and delayed-action repositioning). |
| `/combat hold` | **DM** toggles a combatant's held-action flag. Shown in the encounter display. |
| `/combat delay` | **DM** toggles delayed status, with an optional new initiative value. |
| `/combat surprise` | **DM** toggles the surprise-round flag. Auto-clears when Round 2 begins. |
| `/combat mount` | Mount or dismount — toggles the Mounted condition on a combatant (DM only). |
| `/dual_wield` | Show dual-wielding rules and off-hand penalties based on weapon size (Small −5, Medium −10, Large −15). |
| `/heritage roll` | Roll on the Heritage table for a clan (d10). |
| `/heritage table` | View the full Heritage table for a clan (10 entries). |
| `/taint` | View or modify Shadowlands Taint. Shows Taint Rank (floor(Taint/Earth)), effects, mutations, and madness when crossing rank boundaries. |
| `/battle roll` | Mass Battle engagement roll: Battle/Perception vs a DM-set TN. Result determines engagement level (Reserves → Heroic Opportunity). |
| `/battle damage` | Incidental damage by engagement level: Reserves 0, Disengaged 1k1, Engaged 2k1, Heavily Engaged 3k2, Heroic 4k3. |
| `/family list` | Browse all 47 families grouped by clan with their +1 Trait bonuses. |
| `/family search` | Search families by name or clan. |
| `/spell_damage` | Roll spell damage dice (XkY), optionally auto-apply to a target. |
| `/craft_extended` | Multi-step extended crafting roll (Craft or Artisan/Intelligence). Shows quality tier thresholds (Standard, Fine at 1.5×, Exceptional at 2×). |
| `/encumbrance` | Check carrying capacity (Strength × 5 items). |
| `/horsemanship` | Horsemanship/Agility check vs a TN. |
| `/influence` | Track court influence points for a character (DM-managed). |
| `/travel` | Calculate travel time by mode (foot, horse, forced march, cart, ship, river) and terrain (normal, rough, mountains). |
| `/ancestors` | Show Ancestor advantage mechanical effects (21 ancestors with their bonuses). |

`/combat status` and `/combat summary` now display each combatant's **stance**
and **actions remaining** alongside initiative, conditions, guards, and Full
Defense.

**Family bonuses** are auto-applied at `/sheet create` — pick a `family:` from
the autocomplete and the character gets +1 to the family's Trait automatically
(e.g. Hida → +1 Strength, Doji → +1 Awareness). The `clan:` is auto-set from
the family if not specified.

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
│   ├── combat.py          # Attack/damage/armor-TN/grapple core + full weapon & armor catalogs.
│   ├── npc_gen.py         # Procedural NPC samurai generator (GDD s22.4, LOCKED).
│   ├── creature.py        # Creature model + combat; loads the generated catalog.
│   ├── creature_catalog.py# AUTO-GENERATED: 208 bestiary stat blocks (verbatim).
│   ├── schools.py         # Access helpers over the school catalog (GDD s29).
│   ├── schools_catalog.py # AUTO-GENERATED: 347 schools/paths + 647 techniques (verbatim).
│   ├── spells.py          # Access helpers over the spell catalog (GDD s32-s37).
│   ├── spells_catalog.py  # AUTO-GENERATED: 287 spells (verbatim).
│   ├── advantages.py      # Access helpers over the advantage catalog (GDD s45).
│   ├── advantages_catalog.py # AUTO-GENERATED: 149 advantages/disadvantages (verbatim).
│   ├── kata.py            # Access helpers over the kata catalog (GDD s30).
│   ├── kata_catalog.py    # AUTO-GENERATED: 43 Kata (verbatim).
│   ├── kata_effects.py    # Deterministic active-Kata combat modifiers for /attack (GDD s30).
│   ├── technique_effects.py # Deterministic School-Technique combat modifiers for /attack (GDD s29).
│   ├── skill_mastery.py   # Weapon Skill Mastery combat modifiers for /attack (GDD s24).
│   ├── advantage_effects.py # Advantage/Disadvantage combat modifiers for /attack (GDD s45).
│   ├── kiho_effects.py    # Active-Kiho combat modifiers for /attack (GDD s38).
│   ├── condition_effects.py # Condition combat modifiers for /attack (GDD s40).
│   ├── families.py        # Family catalog access helpers (47 families).
│   ├── families_catalog.py# Family data: name, clan, bonus_trait (L5R 4e).
│   ├── heritage.py        # Heritage tables (d10 per clan, 8 Great Clans + default).
│   ├── mass_battle.py     # Mass Battle engagement & damage (L5R 4e p.173-175).
│   ├── taint.py           # Shadowlands Taint progression (L5R 4e p.274-276).
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

## What's next

- **Hosting on Vultr** — a small, cheap Linux box with the bot running as a
  background service that restarts itself and survives reboots, plus a
  copy-paste setup script and a plain-English runbook. (You won't need to
  learn Linux to operate it.)
