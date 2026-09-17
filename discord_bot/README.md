# Rokugan: L5R 4e Discord Bot

A Discord bot that runs Legend of the Five Rings **4th Edition** rules: dice,
character sheets, combat, and NPCs, with a Dungeon Master kept in the loop.

> **This folder is a completely separate project.** It is Python, and it does
> **not** touch the Godot / GDScript game elsewhere in this repository. The
> GDScript is used only as a *reference* that the Python rules were translated
> from: there is no shared code, no imports across the boundary, and running
> this bot changes nothing about the Godot project.

---

## Status: Phase 63: Combat Enhancements

**Help & Navigation**

| Command | What it does |
|---|---|
| `/help` | Categorized command reference: 13 categories, expandable. Shows a compact overview or drill into one category. Ephemeral (only you see it). |
| `/whoami` | Your character hub, ephemeral: the quick status card (rings, wounds, VP, honor, movement, wielded weapon, active Kata, combat conditions) with buttons for the full sheet, the inventory panel, spending or resting Void, fight status and JSON export, plus menus to set the active Kata, Kiho (s38 exclusivity enforced) and tattoo. |
| `/ref search` | Unified search across **all** catalogs (spells, schools, kata, kiho, advantages, weapons, creatures). Find anything without knowing which command to use. Ephemeral. |

**Dice**

| Command | What it does |
|---|---|
| `/ping` | Confirms the bot is online (shows gateway latency). |
| `/roll` | Full L5R 4e **Roll & Keep**: `rolled` (X) and `kept` (Y), with optional Target Number, Called Raises (+5 each), flat bonus, Emphasis (reroll 1s once), and an Unskilled flag (dice don't explode). |

**Character sheets** (each sheet is linked to your Discord account, per server)

Players roll their own `/check` commands (skill, stealth, social, lore, craft, medicine, fear, honor, poison, horsemanship, investigate) for their active character; the **Fortune** role is only needed to roll for someone else or an NPC. `/help` is generated from the live command list and never goes stale.

| Command | What it does |
|---|---|
| `/sheet create` | Make a character and set it active. Pass a `school:` from the catalog (autocomplete) and it **auto-fills** the school's Benefit trait, starting skills (with free emphases), Honor, clan, and type: a Hida Bushi in one command. Any-choice skill slots ("any one Bugei Skill") are reported for you to fill. Without a school, Traits start at 2. |
| Wizard resume | The creation wizard saves its state at every step. If it sits idle for an hour, the message gains a **Resume** button; after a bot restart, `/sheet create` (or the lobby button) posts a Resume button in your private channel. Nothing is lost. |
| One submission | Pressing Submit locks the wizard: the player sees "Thank you, staff are looking into it", a second press or a Resume while the review is pending shows the same, and nothing is posted twice. A denial re-opens the wizard with a Resume button in the player's channel so they can adjust and submit again. |
| Click-once approvals | Every approval button (damage, healing, spells, creatures, Medicine, conditions, character approval, wizard Resume) accepts exactly one final click; a second click says so instead of applying twice. |
| Fight safety | `/combat start` cannot wipe a fight that already has combatants or a roster unless you are staff. `/combat next` works for staff, the player whose turn it is, or the roster organizer opening the fight. Players cannot re-roll initiative by re-joining. `/sheet delete` is staff-only. |
| Sheet edit audit | Every `/stat` change writes one line to the combat log: who edited, whose sheet, and the exact fields that changed (staff edits are marked). |
| Who may change a sheet | Players manage only gear and purse (`/inventory`), activations, Void spends, and advancement through `/xp`. Traits, skills, numeric fields, armor, weapon qualities, advantages, disadvantages, free Kata/Kiho records, wounds, healing and JSON import are **Fortune** only. |
| XP log (Kami only) | `/setup server` creates `#xp-log` visible only to Kami and registers it; `/dm xp_log_channel` sets or clears it. Every `/xp grant` (who granted, to whom, how much, why, balance) and every XP spend is written there. A grant made while no channel is set warns the granter. |
| Button errors | If a button or menu ever fails, the bot answers with an explanation instead of Discord's bare "This interaction failed", and logs the details. |
| `/sheet view` | Show a sheet: rings (derived as min of two traits), wounds & wound level, Insight & Rank, standing, gear, skills. `member:` shows another player's (DM only). |
| `/sheet list` | List your characters (active one marked). |
| `/sheet activate` | Choose which of your characters is active. |
| `/stat trait` | Set a Trait or Void (0–10). |
| `/stat skill` | Set a skill rank (0 removes it). |
| `/stat set` | Set a numeric field: honor, glory, status, infamy, taint, koku, age, school rank, void points, armor TN/reduction. |
| `/sheet wound` / `/sheet heal` | Apply or heal wounds; shows the wound-level change. |
| `/sheet data export` | Export your active character as JSON (for backup or sharing between servers). |
| `/sheet data import` | Import a character from JSON (paste from `/sheet data export`). |
| `/sheet delete` | Delete a character. |

**DM (game master) accounts**

| Command | What it does |
|---|---|
| Fortune / Kami roles | DMs are members with the **Fortune** Discord role; **Kami** is the admin role. `/dm roles` shows who has them. |
| `/dm new_day` | **DM** advances the in-game day: full VP refresh, natural healing (Stamina x 2 wounds), and spell slot refresh (Ring + School Rank per element) for all active PCs. No real-time connection: the DM decides when a new day dawns. |
| `/dm damage` | **DM** applies raw damage to any PC or NPC: posts the pending effect publicly with Approve / Deny buttons. Damage respects Reduction. |
| `/dm heal` | **DM** heals wounds on any PC or NPC: posts pending healing with Approve / Deny buttons. |
| `/dm treat` | **DM** calls for a Medicine treatment: the healer rolls Medicine/Intelligence vs a TN (wound treatment TN 15, poison TN 20, etc.), and on success the DM authorizes the healing (Intelligence x 2 wounds by default). |
| `/dm revive` | **DM** staff override: reverses a death caused by a bug (required reason, written to the combat log). Sets the character to the top of the Out level unless a wound total is given and re-activates the player's sheet. |
| `/dm undo` | **DM** rolls back the last recorded change to a character or creature (wound, heal, damage approval, Taint change, new day, sheet edit…). Every save keeps the previous state as an undo entry (last 20 per sheet, purged after 30 days). `preview:true` lists the newest entries and what each would restore; omit the name to undo the newest change on the server. Undoing a death or a revive runs the usual bookkeeping (initiative removal / re-activation). |
| `/dm pending` | **DM** lists every approval still waiting (attack, spell, DM damage/heal, creature damage, Medicine treatment, character submissions) with age and a jump link. Every approval prompt now pings the **Fortune** role (make the role mentionable, or give the bot *Mention Everyone*). |
| `/dm log_channel` | **DM** sets a text channel for automatic combat event logging. Attacks, damage, turn advances, conditions, stances, grapple/duel events are posted as compact one-line entries. |
| `/dm clear_log` | **DM** removes the combat log channel: events stop being logged. |
| `/dm party` | DM-only roster of every active PC: school, rings, wounds, VP, honor/glory/status, wielded weapon. Gold embed with player mention. |

A **DM** (the **Fortune** role, or **Kami** for admins) can `view`, edit (`/stat`, `/sheet wound`, `/sheet heal`) and
`delete` **any** player's active character by adding `member:@player`. Everyone
else can only manage their own. Sheets are scoped **per server**, so one bot can
run many separate games without them mixing.

**DM-gated effect pipeline**: all rolls and calculations are free and automatic,
but **applying any effect that changes another character's state** (damage,
healing, conditions) requires explicit DM approval. The bot calculates everything,
posts the result publicly in the channel with the relevant rule, and presents
Approve / Deny buttons that only a DM can click. This applies to:

- **Attack damage** (`/fight attack` → DM clicks "Roll & Apply Damage" or "Deny")
- **Spell damage** (`/spell damage` with `target:` → DM clicks "Apply Damage" or "Deny")
- **Creature attacks** (`/creature attack` → DM clicks "Apply Creature Damage" or "No Damage")
- **Arbitrary damage** (`/dm damage` → DM clicks "Apply Damage" or "Deny")
- **Healing** (`/dm heal` → DM clicks "Apply Healing" or "Deny")
- **Medicine treatment** (`/dm treat` → roll, then DM clicks "Apply Healing" or "Deny")

No damage, wounds, or healing are applied without DM authorization. There is no
automatic connection between real time and in-game time: the DM pushes day
advancement via `/dm new_day`.

**Experience & advancement**: DMs grant, players spend, tabletop **RAW**

A DM hands out XP; players spend it themselves through the bot. Insight Rank
follows automatically.

| Command | What it does |
|---|---|
| `/xp grant` | **DM** gives (or corrects) a player's XP. |
| `/xp balance` | Show a character's available/spent XP and Insight Rank. |
| `/xp trait` | Raise a Trait or Void. Cost = **new rank × 4** (Void **× 6**). |
| `/xp skill` | Raise or learn a Skill. Cost = **new rank × 1**. |
| `/xp emphasis` | Add a Skill Emphasis. **Flat 2 XP**, max **⌈rank ÷ 2⌉** per skill. |
| `/xp kata` · `/xp kiho` · `/xp spell` | Learn a Kata / Kiho / memorise a Spell. Cost = **1 × Mastery Level**: the name autocompletes and the ML is **auto-filled** from the catalog. `/xp kiho` also takes `non_brotherhood:` (1.5 × ML, rounded up, per s38a). |
| `/xp advantage` | Buy an Advantage with XP (cost = its point value). |
| `/xp remove_disadvantage` | Buy off a Disadvantage with XP. Cost = **2 × point value** (L5R 4e RAW). |
| `/xp costs` | The RAW cost reference. |

**Costs are tabletop L5R 4e RAW:** Skill → N×1, Trait → N×4, Void → N×6, Emphasis
flat 2 (capped at ⌈rank÷2⌉), Kata/memorised-Spell → 1×Mastery Level, Kiho → 1×ML
(Brotherhood) or 1.5×ML rounded up (non-Brotherhood, s38a). Traits/Void
cap at rank 5, Skills at 10. RAW raises **Traits** (not Rings), so a Ring only rises
once *both* its Traits do; **Insight** (`Σrings×10 + skill ranks`) and **Insight Rank**
(150 → Rank 2, then +25/rank) recompute automatically.

Kata/Kiho/spell prerequisites (school/ring gating) are DM-adjudicated: the bot
handles the XP economy and records what was bought. Learning a new Rank
*Technique* on advancement is roleplay (a dojo/Sensei visit).

**Kata & Kiho** (all of **GDD s30** and **s38**, transcribed verbatim)

Every Kata and Kiho is in the bot: **43 Kata** and **73 Kiho**, each with element,
Mastery Level, and full effect text (Kata also carry their eligible Schools; Kiho
their Type and Atemi flag).

| Command | What it does |
|---|---|
| `/ref kata list` · `/ref kata search` · `/ref kata view` | Browse Kata by element/Mastery, with Schools and effect. |
| `/ref kiho list` · `/ref kiho search` · `/ref kiho view` | Browse Kiho by element/Mastery, with Type and effect. |
| `/sheet kata` · `/sheet kiho` | Record/remove a Kata or Kiho on the sheet (free): e.g. one granted at creation. Buy with XP via `/xp kata`/`/xp kiho` instead. |
| `/sheet kata activate` | Set your **active Kata** (Simple Action; only one active: s30). Blank name drops it. |
| `/sheet kiho activate` | Activate/deactivate a **Kiho**: one Internal / one Kharmic / one Mystical at a time, Martial stacks (s38). |

`/xp kata` and `/xp kiho` autocomplete real names and **auto-fill the Mastery
Level**, so the RAW cost is computed for you.

**Active-Kata combat effects**: the active Kata (⚑ on the sheet) feeds straight
into `/fight attack`. The bot auto-applies the **deterministic subset** it can compute
faithfully from the sheet, the chosen stance, the maneuver, and the weapon
(main- and off-hand, via `/inventory`): **14 Kata**:

| Kata | Auto-applied in `/fight attack` |
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

Weapon-conditional Kata read what the character is **wielding**: set that with
`/inventory` (the main hand also becomes `/fight attack`'s default weapon; nothing wielded means an unarmed Jiujutsu attack).

**Rate-limited Kata: enforced while a `/combat` encounter is running.** The
initiative tracker now carries real round/turn state (it resets each combatant's
*once-per-Turn* abilities when their turn begins and everyone's *once-per-Round*
abilities at the top of a new Round). When the attacker is a combatant in the
channel's encounter, `/fight attack` applies these and marks them spent; attack again
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
Kiho** remain DM-adjudicated reminders (activation cost: a Void Point or
Meditation/Void roll: and durations are DM-adjudicated); their category limits
(one Internal/Kharmic/Mystical, Martial stacks) *are* enforced by
`/sheet kiho activate`. The **6 deterministic Kiho** whose effects the bot can
compute faithfully are auto-applied (see the Kiho combat effects table below);
auto-applied Kiho are suppressed from the reminder list to reduce noise.

**Advantages & Disadvantages** (all of **GDD s45**, transcribed verbatim)

**149 entries**: 86 Advantages, 63 Disadvantages: each with category, point cost,
and full effect text.

| Command | What it does |
|---|---|
| `/ref advantage list` · `/ref advantage search` · `/ref advantage view` | Browse both, with costs and effects. |
| `/xp advantage` | Buy an Advantage with XP (cost = its point value; pass `points:` for Variable-cost ones). |
| `/stat advantage` · `/stat disadvantage` | Record/remove on the sheet (free): e.g. at creation. Taking a Disadvantage tells you the XP it grants; a DM applies that with `/xp grant`. |

**Auto-applied Advantage & Disadvantage combat effects**: when a character has
one of the entries below, `/fight attack` applies the modifier automatically, the same
way it does for Kata and Techniques (`l5r_rules/advantage_effects.py`). **12
effects across 10 entries:**

| Advantage / Disadvantage | Auto-applied in `/fight attack` |
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

Everything else from GDD s45 stays **DM-adjudicated**: Quick (Initiative),
Prodigy (school-skill detection), Sacred Weapons (weapon identity beyond name),
Crab Hands (unskilled fallback), movement penalties (Blind, Small, Lame),
Missing Limb, Weakness/Doubt (parameterised skills/traits), Momoku/Consumed/
Failure of Bushido (Void-spend restrictions), and Magic Resistance (spell
combat not modelled).

**Auto-applied Kiho combat effects**: when a character has one of the kiho
below **active** (`/sheet kiho activate`), `/fight attack` applies the modifier
automatically (`l5r_rules/kiho_effects.py`). **6 effects across 6 kiho:**

| Kiho | Auto-applied in `/fight attack` |
|---|---|
| Soul of the Four Winds | defender Armor TN **+Insight Rank + Air Ring** |
| Musubi | defender Armor TN **+Water Ring + Staves Rank** (staff equipped) |
| Embrace the Stone | defender Reduction **+Earth Ring x2** |
| Partaking the Waters | defender Reduction **+Water Ring** |
| Grasp the Earth Dragon | attacker wound penalties **reduced by Earth Ring** |
| Air Fist | unarmed damage **−Air Ring** flat (tradeoff for +5 Initiative) |

Everything else from GDD s38 stays **DM-adjudicated**: atemi-delivered effects
(Rolling Avalanche, Flame Fist, Censure of Thunder, etc.), reactive abilities
(Destiny's Strike, Way of the Willow), duration-tracked debuffs (Stain Upon the
Soul, Earth Palm), cumulative tracking (Rising Mountain), action-economy changes
(Dance of the Flames), and non-combat effects. Auto-applied kiho are suppressed
from the reminder line to reduce noise.

**Auto-applied Condition effects**: when a combatant has a condition set via
`/combat condition set`, `/fight attack` applies the modifier automatically
(`l5r_rules/condition_effects.py`). Successful Knockdown maneuvers auto-set
Prone on the target. **15 effects across 7 conditions:**

| Condition | Auto-applied in `/fight attack` |
|---|---|
| Blinded | attacker: melee **−1k1**, ranged **−3k3**; defender Armor TN = **Reflexes + 5 + armor** |
| Dazed | attacker: **−3k0** to all actions |
| Fatigued | attacker: **+5 TN** (applied as −5 flat to attack roll) |
| Grappled | defender: Armor TN = **5 + armor bonus**; large weapons unusable; stances don't apply |
| Pinned | fully immobilized (grapple); can only speak or cast verbal-only Mastery 1 spells |
| Mounted | attacker: **+1k0** attack rolls (vs unmounted/lower) |
| Prone | defender: **−10** Armor TN vs melee; attacker: **−2k0** with Medium/Small, **cannot attack** with Large |
| Stunned | defender: Armor TN = **5 + armor bonus** |

**Entangled** is reminder-only (break-free TN set by DM). Each condition also
displays non-auto-applied reminders (movement restrictions, stance limits,
recovery rolls) in the DM-adjudicates section of the attack embed. Conditions
are transient per-encounter state on the Combatant: they are cleared when the
encounter ends, not persisted to the database.

**Enforced condition restrictions**: the bot blocks commands when a condition
forbids the action, with a clear error message explaining why:

| Restriction | Blocked commands |
|---|---|
| **Stunned** - cannot take actions | attack, guard, full_defense, hold, delay, grapple initiate/hit/throw/pin/break_free |
| **Pinned** - fully immobilized | attack, guard, full_defense, hold, delay, grapple initiate/hit/throw/pin (break_free is allowed) |
| **Entangled** - can only break free | attack, guard, full_defense, hold, delay, grapple initiate/hit/throw/pin (break_free is allowed) |
| **Grappled + Large weapon** - large weapons unusable | attack (with a Large weapon only) |
| **Prone + Large weapon** - cannot attack with Large | attack (with a Large weapon only) |
| **Dazed** - Defense/Full Defense only | stance set to Attack, Full Attack, or Center |
| **Fatigued** - no Full Attack | stance set to Full Attack |
| **Mounted** - no Full Attack | stance set to Full Attack |
| **Grappled** - stances don't apply | any stance change |

**Schools & Techniques** (all of **GDD s29**, transcribed verbatim)

Every school **and path** and its techniques are in the bot: **347 entries**
(**108 Basic Schools · 26 Advanced Schools · 213 Alternate Paths**) with
**647 techniques**. Each entry is tagged with its `category`.

| Command | What it does |
|---|---|
| `/ref school list` | Overall summary (basic/advanced/alternate + per-clan counts), or `clan:` for that clan's entries grouped by category. |
| `/ref school search` | Find schools/paths by name or clan (each tagged basic / adv / path). |
| `/ref school view` | An entry's Benefit, Skills, Honor, Outfit, Affinity, Prerequisites, and every Technique (Rank + name + full effect text). |
| `/sheet learn` | Record the techniques your school grants **up to your School Rank** onto your sheet (RAW: techniques come free with rank at a dojo). Uses your sheet's school, or pass `school_name:`. |

Only **Basic Schools** appear in `/sheet create` and `/npc generate` autocomplete
(you start as a Basic School; Advanced Schools and Alternate Paths are transitions
a character moves into later).

**Auto-applied Technique effects**: the techniques a character has recorded
(`/sheet learn`) feed into `/fight attack`. The bot auto-applies **every s29 Technique
whose condition it can actually evaluate**: a modifier gated only on stance, the
weapon, armour worn, an Initiative or Honor comparison, or a trait scalar : 
**36 techniques** in all (`l5r_rules/technique_effects.py`). The remaining ~600
turn on things the engine can't know (target type: "vs Shadowlands / unaware",
mounted, duels, grapples, terrain, multiple opponents, allies), are
reactive / Void-gated / "once per X", need player choice, or need systems the bot
doesn't model (spells, tattoos, mass battle, conditions, kiho): those stay
**DM-adjudicated**, full text on the sheet via `/ref school view`.

The 36 span: attack-roll dice/flat (Torch's Flame Flickers, The Force of Honor,
The Way of the Crane, Always Be Ready, The Subtle Sting, Togashi Tattooed Order,
Temper Steel With Honor, Magari-Yarijutsu, To Defend Unto Death, Matsu's Courage,
Speed of Lightning †, Fast and Furious †); a Trait override (Spotting the Prey : 
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
(re-runnable) straight from the s29 markdown: nothing invented. It handles every
technique shape in the source: the `- Rank N: Name:` ladder, dash- and inline
`Technique : ` paths, the compressed `Rank 1: … Rank 2: …` monk line, and the
`- Technique: Name: effect` shugenja form. s29.15 (the LOCKED courtier framework)
is skipped: its two schools already appear in the clan files.

**Weapon Skill Masteries** (GDD s24, auto-applied in `/fight attack`)

Every weapon skill has mastery abilities at Ranks 3, 5, and 7. The bot
auto-applies the **18** whose conditions it can evaluate from the sheet, the
weapon, and the encounter state (`l5r_rules/skill_mastery.py`):

| Skill | Rank | Auto-applied in `/fight attack` |
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
(s24): this is now correctly modeled. Ninjutsu R5 overrides it.

Mastery abilities that need systems the bot doesn't model (off-hand penalties,
extra attacks, grappling, range, ready actions) or need per-round initiative
changes (Polearms R3 +5 Init) stay **DM-adjudicated**.

**Spells** (all of **GDD s32–s37**, transcribed verbatim)

Every spell is in the bot: **287 spells** (Air 68, Water 62, Fire 59, Earth 58,
Void 35, plus universal), each with element, Mastery Level, range, area, duration,
raises, and full effect text.

| Command | What it does |
|---|---|
| `/spell list` | Summary by element, or `element:` for that element's spells grouped by Mastery Level. |
| `/spell search` | Find spells by name, element, or keyword. |
| `/spell view` | A spell's element, Mastery, range/area/duration, raises, and effect. |
| `/spell cast` | Cast a spell: rolls **(Ring + School Rank) keep Ring** vs TN **5 + (5 × Mastery Level)**. Affinity +1 / Deficiency −1 effective rank. Supports Void Point (+1k1), Called Raises (+5 TN each, reduce casting time), wound penalty. **Spell slots** (Ring + School Rank per element per day) are consumed on cast: whether the roll succeeds or fails. Refresh slots with `/dm new_day`. DMs can cast for NPCs or other players. |

`/xp spell` (memorise a spell) autocompletes real spell names and **auto-fills the
Mastery Level**: so the RAW cost (1 × Mastery Level) is computed for you.

**Equipment** (weapons & armor, verbatim from the game data)

| Command | What it does |
|---|---|
| `/ref weapon list` · `/ref weapon view` | Browse all **44 weapons** (damage rating, skill, trait, size). |
| `/ref armor list` | The **7 armor types** with Armor TN bonus and Reduction. |
| `/inventory` | One ephemeral panel for gear and purse: main hand and off hand menus (from owned weapons), add a catalog weapon, drop one, add or remove items, add or spend koku. Staff also set armor and weapon qualities here, and can open any player's character (`member:`) or an NPC (`npc:`). Every change saves at once with an undo snapshot and an audit line. |
| `/stat identity` | Staff: set clan, family and/or school text on a sheet. A catalog family also applies its +1 Trait (once; `apply_bonus:false` to skip), which repairs a sheet created before minor clans were selectable in the wizard. |
| `/stat armor` | Equip an armor type: sets the sheet's **Armor TN bonus** and **Reduction** automatically (e.g. Light → +5 TN, Reduction 3; Heavy → +10, 5); `none` removes it. |

Weapon damage (used by `/fight attack`) and armor Reduction/Armor-TN (used by combat)
now come from the full catalogs: Ashigaru +3/1, Tatami +4/1, Light +5/3, Heavy
+10/5, Tetsu-do +13/8, Riding +4/4, Bogu +0/1.

**Combat: player rolls, DM approves damage**

| Command | What it does |
|---|---|
| `/fight attack` | Your active character attacks another player's. Rolls **to hit**: `(Agility + weapon skill) keep Agility` (Reflexes for bows) vs the target's **Armor TN** (`Reflexes×5 + 5 + armor`), minus your wound penalty, with raises and stances. |

On a **hit**, the message shows **DM-only buttons**:

- **⚔️ Roll & Apply Damage**: rolls the weapon's damage (`weapon dice + Strength`
  for melee, exploding), subtracts the target's armor **Reduction**, and adds the
  wounds to the target's sheet, announcing any wound-level change (and death).
- **🛡️ No Damage**: the DM rules the blow off.

Only a DM can press them, so the flow is exactly *"a player submits an attack; if
it lands, the DM authorizes the outcome."*

`/fight attack` options: `weapon` (autocomplete), `raises` (+5 TN each),
`increased_damage` (+5 TN and +1 damage die each), `maneuver`, `spend_void`,
`attacker_stance`, `defender_stance`, `bonus_tn` (DM situational modifier), and
`weapon_material` (jade/crystal/obsidian/nemuranai - bypasses creature Invulnerability).

**Maneuvers & Void** (the maneuver's raise cost is added to the TN automatically):

- **Feint** (2 raises): on a hit, adds bonus damage = ½ the attack margin, capped
  at 5 × Insight Rank.
- **Disarm** (3 raises): on a hit, deals 2k1 damage and a contested Strength roll;
  win and the target is disarmed.
- **Knockdown** (2 raises): on a hit, a contested Strength roll; win and the target
  is knocked prone (quadrupeds resist at +4).
- **Called Shot** (1–4 raises via `raises:`): targets a body part (1=limb, 2=hand/foot,
  3=head, 4=eye/ear/finger). Normal damage; the embed notes the targeted part and the
  DM rules on the effect of sufficient damage.
- **Extra Attack** (5 raises): on a hit, damage resolves normally, then a free second
  attack roll fires automatically (no raises, same weapon). The 2nd attack can miss.
  Once per Turn (enforced by the encounter tracker).
- **Spend Void**: `spend_void:true` spends one Void Point for **+1k1** on the attack
  roll (RAW: Void is not valid on damage rolls) and decrements the sheet's pool.
- **Armor penalty**: Heavy armor imposes **−5** on the attack roll (Agi/Ref skill
  TN +5); Tetsu-Do imposes **−10** (or **−5** if Strength ≥ 5). Hida Bushi R1
  ("The Way of the Crab") ignores these penalties. Light/Ashigaru/Riding armor
  have no attack penalty. Auto-applied when the attacker has armor equipped.

**Initiative tracker** (`/combat`, one encounter per channel)

| Command | What it does |
|---|---|
| `/combat start` | Begin a fresh encounter in this channel. |
| `/combat setup` | Anyone sets up an **encounter roster**: pick the players from a member menu, and the bot posts a roster with **Join** / **Decline** / **Force (staff)** / **Begin** buttons. Invited players accept or decline for themselves; Fortune/Kami can force everyone pending or declined in; the organizer or staff press Begin to roll initiative for all who are in (late Joins roll in at once). While a roster is open, `/combat join` only works for rostered players (staff can still add anyone). The buttons survive a bot restart. |
| `/combat roster add` / `remove` / `close` | Organizer or staff manage an open roster: invite another player (pinged; they still press Join), uninvite someone not yet in initiative (staff-forced players only by staff), or close a roster that has not begun (once begun, only `/combat end` by staff). |
| `/fight status` | Your compact combat card (ephemeral): wounds and level with the roll penalty, Void, weapon, Armor TN with stance/Full Defense/Void/cover, initiative, stance, actions used, conditions, Fear, hold/delay. DMs can view another player's with `member:`. |
| *(automatic)* Stale-turn nudge | Once per turn, if the current actor has not ended their turn after **10 minutes**, the bot pings them in the fight channel with the commands to move on. Constant `STALE_TURN_MINUTES` in `bot.py`. |
| `/combat recap` / summary on `/combat end` | Fight tally kept on the encounter (survives restarts): per participant hits/attacks, damage dealt and taken (counted when a DM approves it), healing, kills, Void spent, and wound level at join → now. `/combat end` posts the final summary with rounds, elapsed time, the fallen, and callouts for most damage dealt, most taken, and most accurate (3+ attacks); one compact line per participant also goes to the combat log. `/dm undo` rolls back sheets, not the tally. |
| `/fight condition` | Any player asks a DM to apply a condition (Dazed, Prone, Stunned, Blinded, Entangled, Fatigued…) to a combatant, with an optional duration in Rounds and a source. Posts Apply / Deny buttons (Fortune-pinged, restart-safe, in the damage-approval channel when one is set) exactly like damage. Nothing changes until a DM approves. |
| Conditions with durations | `/combat condition set` takes `rounds:`; timed conditions end at the start of that Round and the turn message says so (⌛). The initiative list shows `dazed(2r)`. |
| Spell conditions | When a cast spell's text names a condition, the result gets a footer; cast with `target:` (a combatant here) and it gets one-click **Request** buttons that open the same approval, prefilled with the duration when the spell states one for that condition. Prone is never timed (it ends when you stand). |

**Raises and Emphases (enforced):** called Raises on an attack (including a maneuver's cost after Free Raises) or a spell may not exceed the caster's **Void Ring**; an **Unskilled** attack may not use Raises of any kind (called, maneuver or Free). Every `/check` command takes an optional `emphasis` (autocompleted from the sheet) that must be on the sheet for that Skill and rerolls 1s once; `/fight attack` applies a weapon Emphasis (e.g. Kenjutsu: Katana) automatically, as does `/check investigate` with its emphasis choice.
| `/combat join` | Add your active character; rolls initiative `(Reflexes + Insight Rank) keep Reflexes`. DMs can add a player with `member:`. |
| `/combat add` | Add an NPC/monster by `name`, `reflexes`, `insight_rank` (rolls its initiative). DM only. |
| `/combat next` | Advance to the next combatant; wraps and bumps the round. |
| `/combat status` | Show the current order and whose turn it is. |
| `/combat remove` / `/combat end` | Drop a combatant / end the encounter. |
| `/combat condition set` | Apply a condition to a combatant (DM only). 8 choices: Blinded, Dazed, Entangled, Fatigued, Grappled, Mounted, Prone, Stunned. |
| `/combat condition clear` | Remove a condition from a combatant (DM only). |
| `/combat condition list` | Show a combatant's active conditions and their DM-adjudicated effects. |
| `/fight guard` | Guard another combatant (DM only). Ward gets +10 Armor TN, guarder gets −5. Clears on guarder's next turn. |
| `/fight full_defense` | Full Defense (DM only). Rolls Defense/Reflexes, adds half (rounded up) to Armor TN until next turn. Complex Action. |
| `/combat summary` | Compact DM-only overview of all combatants: wounds, wound level, Armor TN, VP, conditions, guards, and Full Defense: at a glance. Ephemeral. |

Initiative order is in-memory scratch state (a bot restart clears an in-progress
fight; sheets and wounds are in the database and persist). Each combatant also
carries **round/turn usage state**, **active conditions**, and **guard state** : 
`/combat next` resets the incoming actor's once-per-Turn abilities, guard
assignment, and, at the top of a new Round, everyone's once-per-Round abilities : 
which is what lets `/fight attack` enforce rate-limited Kata (see the Active-Kata
section). Conditions display inline in the initiative listing (e.g. `[dazed,
prone]`), active guards show as `🛡️→WardName`, and Full Defense as
`🛡️FD+N`.

**Grappling** (`/engage grapple`, all DM-only: s40 Grappling rules)

| Command | What it does |
|---|---|
| `/engage grapple initiate` | Initiate a grapple: Jiujutsu/Agility vs Armor TN (ignoring armor bonus), then contested Jiujutsu/Strength. On success, both gain **Grappled**; initiator has control. Complex Action. |
| `/engage grapple control` | Contested Jiujutsu/Strength roll between two grapple participants. Winner has control until the next Turn. |
| `/engage grapple hit` | Grapple Hit (controller only): unarmed damage on a grappled opponent. No attack roll: DM authorizes damage via the standard button flow. Complex Action. |
| `/engage grapple throw` | Throw a grappled opponent: both become **Prone**, grapple ends for both. Complex Action. |
| `/engage grapple pin` | Pin a grappled opponent: target gains **Pinned** condition (fully immobilized; prerequisite for Bind). Complex Action. |
| `/engage grapple break_free` | Break free. No opponent = controller break (Simple Action, no roll). With opponent = defender break-free (Complex Action, contested Jiujutsu/Strength). |

**Iaijutsu dueling** (`/engage duel`, all DM-only: s40 Iaijutsu rules)

| Command | What it does |
|---|---|
| `/engage duel assess` | Assessment: both duelists roll Iaijutsu(Assessment)/Awareness vs TN 10 + opponent's Insight Rank × 5. On success, learn opponent's Void, Reflexes, Iaijutsu, emphases, VP, or wound level (+1 per Raise). If one exceeds the other by 10+, that duelist gains +1k1 on Focus. |
| `/engage duel focus` | Focus: contested Iaijutsu(Focus)/Void roll. Winner by 5+ strikes first; +1 Free Raise per additional 5. Neither by 5 → Kharmic Strike (simultaneous, cause dropped). |
| `/engage duel strike` | Strike: Iaijutsu/Reflexes attack vs normal Armor TN. Free Raises from Focus apply as Increased Damage. On hit, DM-authorized damage via the standard button flow (default weapon: katana). |

**Contested checks, Fear, and Honor rolls** (roll for your own character; other characters and NPCs need the Fortune role)

| Command | What it does |
|---|---|
| `/check contest` | Contested Skill/Trait roll between two characters. Each side rolls **(Trait + Skill) keep Trait** with per-side explode (skilled only), wound penalties, and optional flat bonuses. Supports encounter combatants, NPCs, and players. |
| `/check fear` | Fear check: **Willpower vs TN 5 + (Fear Rank × 5)**. Raw Willpower roll (no explosion). |
| `/check honor` | Honor Roll: **Honor Rank dice, keep 1** vs a DM-set TN. Resists temptation or dishonor. |

**Void Point management** (`/sheet void`)

| Command | What it does |
|---|---|
| `/sheet void spend` | Spend a Void Point with a reason label (+1k1, negate conditional, etc.). Tracks VP. Players can spend their own; DMs can spend for NPCs/other players. |
| `/sheet void refresh` | Recover VP: **Rest** (full refresh) or **Meditation** (Meditation/Void check vs TN, recovers 1 VP on success). |
| `/sheet void status` | Show current VP with a visual bar. |

**Poison & Medicine** (your own character, or Fortune for others)

| Command | What it does |
|---|---|
| `/check poison` | Poison resistance: **Stamina vs TN (Strength × 5)**. Raw Stamina roll (no explosion). Optional poison name for display. |
| `/check medicine` | Medicine/Intelligence check vs a DM-set TN. Treats wounds, poison, disease, etc. Explodes only if skilled. |

**Skill checks: Stealth, Investigation, Social, Craft, Lore** (your own character, or Fortune for others)

Six commands that all use the same engine: `(Trait + Skill) keep Trait` vs TN,
exploding only when skilled (skill rank > 0). Wound penalty auto-applied. Each
uses `resolve_skill_check` in `combat.py` and the shared `_build_check_embed`
helper for a consistent three-field embed (Roll / Dice / Result).

| Command | What it does |
|---|---|
| `/check skill` | **Universal** skill check: DM picks the trait (dropdown) and skill name (autocomplete from sheet; rank read automatically). For anything not covered by a dedicated command. |
| `/check stealth` | **Stealth/Agility** vs TN. Auto-reads the Stealth skill from the sheet. Verdict: "Undetected!" / "Spotted!" |
| `/check investigate` | **Investigation/Perception** vs TN. Optional emphasis choice (Notice, Interrogation, Search): checks the sheet for a matching emphasis and adds a footer reminder about emphasis rerolls. |
| `/check social` | **Social skill** dropdown (Courtier, Etiquette, Intimidation, Temptation, Sincerity, Perform): auto-selects the correct trait per L5R 4e rules (Awareness for most, Willpower for Intimidation). |
| `/check craft` | **Artisan or Craft / Intelligence** vs TN. Skill name autocompletes from sheet (e.g. "Artisan: Painting", "Craft: Weaponsmithing"). |
| `/check lore` | **Lore / Intelligence** vs TN. Specialty autocompletes from sheet (e.g. "Lore: Heraldry", "Lore: Shadowlands"). |

All six support `member:` (DM targets a player's active character), `is_npc:`
(look up by name), `bonus:` (flat modifier for advantages, tools, etc.), and
`reason:` (label shown with the roll). The opposed-check use case (e.g.
Stealth vs Investigation) is already handled by `/check contest`.

**NPCs** (generated from **GDD s22.4**: Generation Templates, LOCKED)

| Command | What it does |
|---|---|
| `/npc generate` | DM generates a samurai NPC by `insight_rank` (1–5): Traits/Rings, Honor, Glory, age, koku within the s22.4 bands, random variance. A `school:` from the catalog (autocomplete) auto-fills the school's skills, Honor, clan, and type (the Benefit is already baked into the s22.4 ring bands, so it isn't re-applied); or set `skills` manually. |
| `/npc view` · `/npc list` · `/npc delete` | View / roster / remove NPCs (delete is DM-only). |
| `/npc-edit trait` · `/npc-edit skill` · `/npc-edit set` · `/npc-edit wound` · `/npc-edit heal` · `/npc rename` | Edit a generated NPC field-by-field (DM only): same fields as the `/sheet` editors. |

NPCs plug into combat: `/combat npc name:` adds one to initiative, and `/fight attack`
takes `target_npc:` (fight an NPC) and `attacker_npc:` (a DM runs a monster
against a player). NPCs are stored per server and never mix with player sheets.

*NPC fidelity & limits:* every value traces to s22.4: nothing invented. Because
s22.4 pulls school-specific skills and Trait bonuses from Sections 27/29 (not
ported), you supply the school **skill names** (`skills:`) and the generator sets
their ranks; Ranks are capped at **1–5** (s22.4 gives no 6+ ranges); koku is the
`1d10 × Rank` savings term only (the role stipend needs role data). Generated
NPCs can be tuned field-by-field with the `/npc` editors above.

*Still faithful-core:* deterministic subsets of **Kata**, **School Techniques**,
**Skill Masteries**, **Advantages/Disadvantages**, **Kiho**, and **Conditions**
now auto-apply in `/fight attack` (see the tables above); the rest of Kata, most
Techniques, and most Kiho stay DM-adjudicated (shown as reminders; technique
text on the sheet via `/ref school view`). **Void Point damage reduction** adds a
second button on every hit: DM clicks "Void Reduce" to spend 1 VP and subtract
10 wounds from the target (L5R 4e core rule). The button is hidden for creature
targets (no VP) and knockdown maneuvers (no damage). **Called Shot** (1–4 raises)
labels the targeted body part in the damage embed; **Extra Attack** (5 raises)
auto-fires a second attack roll after the first hit resolves (once per Turn);
**Guard** (`/fight guard`) assigns a ward (+10 TN) and penalizes the guarder
(−5 TN), clearing on the guarder's next turn. **Armor attack penalties** (s39)
auto-apply: Heavy −5, Tetsu-Do −10 (−5 if Str ≥ 5); Hida Bushi R1 is exempt.
**Full Defense** (`/fight full_defense`) rolls Defense/Reflexes and adds half
(rounded up) to Armor TN until the combatant's next turn: a Complex Action.
**Grappling** (`/engage grapple`) covers the full subsystem: initiate (Jiujutsu/Agility
vs TN ignoring armor), contested control rolls, Hit (unarmed damage via DM
buttons), Throw (Prone + leave grapple), and Break Free.
**Spell Casting** (`/spell cast`) rolls (Ring + School Rank) keep Ring vs TN
5 + (5 × Mastery Level), with Affinity (+1 effective rank) and Deficiency (−1),
Void Point (+1k1), Called Raises (+5 TN each, reduce casting time by 1 per
raise), and wound penalty. **Spell slots** are tracked per element: max = Ring +
School Rank per day, consumed on each cast (success or failure). DM refreshes all
slots and heals wounds via `/dm new_day`: no connection between real time and game
time. Players cast their own spells; DMs can cast for NPCs or other players.
**Iaijutsu Dueling** (`/engage duel`) covers the full three-stage formal duel:
Assessment (Iaijutsu/Awareness, reveals opponent stats, +1k1 Focus bonus if
exceeded by 10+), Focus (contested Iaijutsu/Void, winner by 5+ strikes first
with Free Raises per additional 5, otherwise Kharmic Strike), and Strike
(Iaijutsu/Reflexes attack vs normal Armor TN, Free Raises as Increased Damage,
DM-authorized damage via buttons): DM only.
**Contested Checks** (`/check contest`) handle any opposed Skill/Trait roll between
two characters, with per-side explode, wound penalties, and flat bonuses.
**Fear Checks** (`/check fear`) roll Willpower vs TN 5 + Fear Rank × 5.
**Honor Rolls** (`/check honor`) roll Honor Rank dice, keep 1, vs a DM-set TN.
**Void Point Management** (`/sheet void`) tracks VP spending (with reason labels),
rest recovery (full refresh), and Meditation/Void checks (recover 1 on success).
**Poison Resistance** (`/check poison`) rolls Stamina vs TN Strength × 5.
**Medicine Checks** (`/check medicine`) roll Medicine/Intelligence vs a TN for treatment.
Dual-wielding and thrown/charge maneuvers are still **not** modelled: the DM
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

Players fight creatures through the normal `/fight attack` with `target_creature:`: the
attacker rolls their weapon as usual, and the DM-authorized damage goes onto the
creature's wound track (plain hit or Feint; Disarm/Knockdown against creatures
aren't wired). `/combat creature` drops a spawned creature into initiative.

*The full bestiary is in*: **208 creatures**, transcribed verbatim from the Godot
bestiary files by `tools/extract_bestiary.py` (re-runnable): ~42 animals, ~41
Shadowlands beasts, ~38 oni, ~20 undead, ~53 spirits, plus kenku, tsuno, nezumi,
ningyo, and named antagonists (the Lost). Creatures whose sheet uses the human
wound track (Healthy `Earth×5`, then `Earth×2` per level, as for PCs) are handled correctly; one non-combat environmental
hazard is excluded. `l5r_rules/creature_catalog.py` is generated: don't hand-edit
it; re-run the extractor to refresh.

**Creature Special Abilities (GDD s54.0)** - auto-applied when dealing damage to
creatures via `/fight attack target_creature:`:

| Tag | Effect | Bypassed by |
|---|---|---|
| `partial_invuln` | 1 Wound from normal attacks | jade/crystal/obsidian weapon, nemuranai, spells |
| `superior_invuln` | 1 Wound from ALL attacks (spells too) | nothing (immune to everything) |
| `partial_invuln_half_damage` | Half damage from normal attacks | jade/crystal/obsidian, nemuranai, spells |
| `spirit` | Half damage from non-jade weapons and non-Jade/Crystal spells | jade/crystal/obsidian weapon (or Jade/Crystal spell) |
| `undead` | No wound penalties; immune to Fear; functional until Dead | (DM reminder only) |

Specify `weapon_material:` on `/fight attack` to indicate jade/crystal/obsidian/nemuranai.
Creature spawn/view embeds now show "Special Abilities" for creatures with these tags.

**Bokken weapon special** (GDD s39): targets hit by a bokken have their armor
Reduction doubled before applying damage. Auto-applied in both PC-vs-PC and
PC-vs-creature damage paths.

**Arrow & blowgun specials** (GDD s39): select the arrow type as your weapon in
`/fight attack` to apply its special effect. Arrow entries in the weapon catalog use
Kyujutsu/Reflexes like bows.

| Weapon | DR | Armor TN Effect | Other |
|---|---|---|---|
| `willow_leaf_arrow` | 2k2 | Normal (standard arrow) | - |
| `armor_piercing_arrow` | 1k1 | **Ignores** armor TN bonus from armor | - |
| `flesh_cutter_arrow` | 2k3 | **Doubles** armor TN bonus from armor | Half range |
| `humming_bulb_arrow` | 0k1 | Normal | Whistles (flavor) |
| `rope_cutter_arrow` | 1k1 | Normal | +2 raises vs inanimate (DM); half range |
| `bo_hiya` | 3k3 | Normal | **Ignores ALL Reduction** (armor, kata, technique, natural) |
| `blowgun` | 0k1 | **Triples** armor TN bonus from armor | DR scales: 1k1 at Ninjutsu 3, 2k1 at Ninjutsu 7 |

Armor TN modification is auto-applied in the attack roll against PC/NPC targets
(creatures use flat Armor TN with no separable armor bonus). The adjustment
appears in the "Combat effects" field. Blowgun damage scaling is auto-applied at
damage time based on the attacker's Ninjutsu rank. Bo-Hiya ignores all forms of
Reduction at damage time (armor, kata bonuses, technique bonuses, natural
toughness). "Half range" arrows display a DM reminder in the combat effects.

**Weapon Breakage** (GDD s39 - auto-checked at damage time)

| Weapon | Break Threshold |
|---|---|
| `kumade` | 25+ raw damage |
| `lance` | 30+ raw damage |
| `parangu` | 30+ raw damage |
| `ninja_to` | 40+ raw damage |

When a weapon's raw damage (pre-Reduction) meets or exceeds its break threshold,
a **WEAPON BROKEN** warning appears in the damage embed. The DM should enforce
removal of the weapon from play.

**Weapon Stance Penalties** (GDD s39 - auto-applied on attack)

| Weapon | On Foot | Mounted |
|---|---|---|
| `dai_kyu` | +10 TN | - |
| `yumi` | - | +10 TN |
| `han_kyu` | - | +10 TN |
| `lance` | +10 TN | +5 TN |

Lance uses DR 1k2 (non-charging). Full DR 3k4 requires a mounted charge,
which is not yet modeled - the DM can use `bonus_tn:` to remove the penalty
and override DR manually for a charge.

**Grapple-Capable Polearms** (GDD s39)

Sasumata and sodegarami can be used to initiate a grapple while armed (normally
a grapple requires free hands). When `/engage grapple initiate` is used and the
attacker has a weapon equipped:
- If the weapon is **grapple-capable**: a green checkmark note confirms it
- If the weapon is **not** grapple-capable: a warning reminds the DM that the
  attacker must drop/sheathe the weapon first

The grapple roll itself is still Jiujutsu/Agility (per s40). The weapon special
only removes the "free hands" requirement.

**Thrown Weapon Variants** (GDD s39)

Melee weapons that can be thrown have separate `_thrown` catalog entries. Select
the thrown entry (e.g. `yari_thrown`) to make a ranged attack with that weapon.
Thrown attacks use **Reflexes** (ranged trait) instead of Agility, with the
weapon's normal skill. Range is DM-adjudicated.

| Weapon | Melee DR | Thrown DR | Range | Skill |
|---|---|---|---|---|
| `wakizashi` / `wakizashi_thrown` | 2k2 | 2k2 | 20' | Kenjutsu |
| `yari` / `yari_thrown` | 2k2 | **1k2** | 50' | Spears |
| `nage_yari` / `nage_yari_thrown` | 1k2 | 1k2 | 50' | Spears |
| `mai_chong` / `mai_chong_thrown` | 0k3 | 0k3 | 25' | Spears |

Shuriken (25') and tsubute (30') are already in the catalog as ranged weapons
(Ninjutsu / Agility, `no_explode`). They have no separate melee entry.

**Katana Void Damage** (GDD s39): pass `void_damage:True` on `/fight attack` with a
katana. The VP is spent at damage resolution time (not attack time), adding
**+1k1** to the damage roll. If the attacker has no VP when damage resolves, a
"no Void Points" note appears and no bonus is applied. Only the katana catalog
entry has the `void_damage` flag - other weapons are rejected with an error.

**Kyoketsu-shogi** (GDD s39): doubles the target's armor TN bonus (same
`armor_tn_mult: 2` mechanic as flesh cutter arrows). Auto-applied.

**Firearms** (GDD s39 - Teppoudo / Intelligence)

All firearms ignore armor effects on both Armor TN and Reduction. Attack rolls
use Intelligence (the Teppoudo skill trait), not Agility or Reflexes.

| Weapon | DR | Skill | Armor TN | Reduction Effect | Other |
|---|---|---|---|---|---|
| `kakiyari` | 3k2 | Teppoudo | Ignores armor TN bonus | Ignores armor Reduction | Can use as `yari` in melee (DR 1k1) |
| `hand_cannon` | 4k3 | Teppoudo | Ignores armor TN bonus | Ignores armor + natural toughness Reduction | Can use as `tetsubo` in melee |
| `bajozutsu` | 3k2 | Teppoudo | Ignores armor TN bonus | Ignores armor Reduction | Can be drawn with Iaijutsu (DM) |
| `teppo` | 3k3 | Teppoudo | Ignores armor TN bonus | Ignores armor Reduction | At half range: also ignores natural toughness (DM) |

**Teppoudo mastery damage bonuses** (auto-applied at damage time):
- Rank 3: +1k0 to all firearm damage rolls
- Rank 7: additionally +0k1 (cumulative +1k1)

Firearms do not add Strength to damage. The DM may optionally rule that
Perception adds to damage (comparable to Strength for melee) - use
`increased_damage` raises to represent this if desired.

**Extraordinary Weapon Qualities** (GDD s39 - Crafting Specials)

Master crafters in Rokugan can forge weapons with exceptional properties. These
are managed per-character via `/stat quality` (the qualities belong to the
character's currently-equipped weapon, not to a weapon type). When attacking,
qualities apply only if the weapon used matches the character's `equipped_weapon`.

| Command | What it does |
|---|---|
| `/sheet quality qualities:"balanced, swift"` | Set qualities on the equipped weapon (comma-separated). |
| `/sheet quality clear:True` | Remove all weapon qualities. |
| `/stat quality` | View current weapon qualities. |

| Quality | Effect | Auto-applied? |
|---|---|---|
| **Balanced** | +1k0 to attack rolls | Yes - added to rolled dice in `/fight attack` |
| **Radiant** | Counts as jade (bypasses creature Invulnerability) | Yes - treated as jade material in creature damage path |
| **Signature** | Bears the creator's personal stamp (flavor only) | N/A - no mechanical effect |
| **Swift** | +5 Initiative | Yes - added at `/combat join`/`npc`/`room` time |
| **True** | Subtract wielder's Strength from target's Reduction | Yes - applied in both creature and PC/NPC damage paths |
| **Unbreakable** | Cannot be broken by damage exceeding break threshold | Yes - suppresses weapon breakage |

Quality names are validated against `WEAPON_QUALITIES` in `combat.py`. Invalid
names are rejected. Qualities are displayed as `[balanced, swift]` after the
weapon name in `/sheet view`, `/whoami`, and `/dm party`.

**True** subtracts the wielder's Strength from the target's Reduction (both
armor-based and creature natural Reduction). The subtraction happens after
ignore-armor and double-reduction checks, so if Reduction is already zeroed by
another effect, True has no additional impact. The subtraction cannot reduce
Reduction below 0.

**Swift** adds +5 to the initiative total at join time (baked into the
Combatant's base initiative), so it flows through `effective_initiative`
alongside Void and Center Stance bonuses.

**Armor Catalog** (GDD s39 - full reference with `/ref armor`)

All 7 armor types from GDD s39 are browsable with full details: TN bonus,
Reduction, cost (koku), type (heavy/light), and special penalties.

| Command | What it does |
|---|---|
| `/ref armor list` | All 7 armor types with TN, Reduction, cost, and heavy flag. |
| `/ref armor view` | Detailed embed for one armor type (autocomplete). |
| `/ref armor search` | Search by name substring. |

| Armor | TN Bonus | Reduction | Cost | Special |
|---|---|---|---|---|
| Bogu | +0 | 1 | 1 koku | - |
| Ashigaru | +3 | 1 | 5 koku | - |
| Tatami | +4 | 1 | 10 koku | - |
| Light | +5 | 3 | 25 koku | Athletics/Stealth TN +5 |
| Heavy | +10 | 5 | 40 koku | Agility/Reflexes skill TN +5 |
| Tetsu-Do | +13 | 8 | 100 koku | Heavy. Agi/Ref TN +10 (+5 if Str 5+) |
| Riding | +12/+4 | 4 | 55 koku | +12 mounted, +4 on foot. Agi/Ref TN +5 except mounted |

Armor is also included in the unified `/ref search` results alongside weapons,
spells, schools, kata, kiho, advantages, and creatures. Equipping armor via
`/stat armor` now shows the cost and special penalty text.

**Rooms** (private play rooms: each is a Discord **private thread**)

| Command | What it does |
|---|---|
| `/room create` | Opens a private thread as a play room and makes you its host. |
| `/room invite` · `/room kick` | Add/remove a member (run **inside** the room; host or DM only). |
| `/room members` · `/room list` | Who's in this room / all open rooms on the server. |
| `/room close` | Archive the room (host or DM only). |

Because a room *is* a channel, everything else works inside it with no extra
steps: `/sheet`, `/roll`, `/fight attack`, and `/combat` all just work in the thread,
and each room's initiative tracker is naturally separate (initiative is
per-channel). So a DM can run several games at once in one server, each in its
own room.

**Phase 42: Stances, Action Economy, and Remaining Mechanics**

| Command | What it does |
|---|---|
| `/fight stance` | Declare stance for the round: Attack, Full Attack (−10 ATN, +2k1), Defense (+Air+Defense ATN), Full Defense (Complex Action), Center (+Void ATN, +1k1 next turn). Resets on turn advance. |
| `/fight action` | Track Simple/Complex action usage per turn. L5R 4e: 1 Complex OR 2 Simple per turn. |
| `/combat turn init` | **DM** adjusts a combatant's initiative mid-combat (covers re-rolls and delayed-action repositioning). |
| `/combat turn hold` | **DM** toggles a combatant's held-action flag. Shown in the encounter display. |
| `/combat turn delay` | **DM** toggles delayed status, with an optional new initiative value. |
| `/combat turn act` | **DM** resolves a held/delayed combatant's action: clears the flag and resets action economy. |
| `/combat room` | **DM** adds all room members' active characters to initiative at once (run inside a room thread). |
| `/combat turn surprise` | **DM** toggles the surprise-round flag. Auto-clears when Round 2 begins. |
| `/fight mount` | Mount or dismount: toggles the Mounted condition on a combatant (DM only). |
| `/ref dual_wield` | Show dual-wielding rules and off-hand penalties based on weapon size (Small −5, Medium −10, Large −15). |
| `/ref heritage roll` | Roll on the Heritage table for a clan (d10). |
| `/ref heritage table` | View the full Heritage table for a clan (10 entries). |
| `/dm taint` | View or modify Shadowlands Taint. Shows Taint Rank (floor(Taint/Earth)), effects, mutations, and madness when crossing rank boundaries. |
| `/engage battle roll` | Mass Battle engagement roll: Battle/Perception vs a DM-set TN. Result determines engagement level (Reserves → Heroic Opportunity). |
| `/engage battle damage` | Incidental damage by engagement level: Reserves 0, Disengaged 1k1, Engaged 2k1, Heavily Engaged 3k2, Heroic 4k3. |
| `/ref family list` | Browse all 47 families grouped by clan with their +1 Trait bonuses. |
| `/ref family search` | Search families by name or clan. |
| `/spell damage` | Roll spell damage dice (XkY), optionally auto-apply to a target. |
| `/dm craft_extended` | Multi-step extended crafting roll (Craft or Artisan/Intelligence). Shows quality tier thresholds (Standard, Fine at 1.5×, Exceptional at 2×). |
| `/ref encumbrance` | Check carrying capacity (Strength × 5 items). |
| `/ref armor_tn` | Armor TN breakdown: base (Reflexes × 5 + 5), armor, stance, guard, Full Defense, condition overrides. Shows in-combat context when applicable. |
| `/spell resist` | Spell resistance: target rolls raw Willpower vs a DM-set TN. DM only. |
| `/check horsemanship` | Horsemanship/Agility check vs a TN. |
| `/dm influence` | Track court influence points for a character (DM-managed). |
| `/ref travel` | Calculate travel time by mode (foot, horse, forced march, cart, ship, river) and terrain (normal, rough, mountains). |
| `/ref ancestors` | Show Ancestor advantage mechanical effects (21 ancestors with their bonuses). |

`/combat status` and `/combat summary` now display each combatant's **stance**
and **actions remaining** alongside initiative, conditions, guards, and Full
Defense. `/combat next` now shows **condition reminders** when advancing to a
combatant who has active conditions (Stunned: can't act, Dazed: Defense only,
Entangled: break-free only, etc.). `/fight stance` now shows the mechanical
effects of each stance when declared. Initiative ties now break by **Reflexes**
(L5R 4e rule). `/whoami` and `/sheet view` display a visual **wound track**
(H → Ni → Gr → [**Hu**] → In → Cr → Dn → Ou → De with current level marked).
`/dm damage` now includes a **Void Reduce (−10)** button.

`/ref modifiers` is a quick-reference card for **terrain and range modifiers**: cover
(+10/+20 TN), range increments (+10 TN each beyond the first), higher ground
(+1k0), darkness, mounted vs foot, and prone targets: with a note on how to apply
them via the `/fight attack bonus_tn:` parameter. `/ref calledshot` shows the Called Shot
raise-cost table (1–4 raises → limb, hand/foot, head, eye/ear/finger) and DM-adjudicated
effects for each body part. `/dm treat` adds a full **Medicine treatment workflow**:
the DM picks a healer and patient, the healer rolls Medicine/Intelligence vs a TN
(wound treatment TN 15, disease diagnosis TN 15, poison treatment TN 20, antidote
TN 20), and on success the DM authorizes healing (Intelligence × 2 wounds by
default, overridable). Failed treatment follows the L5R 4e rule that it cannot be
re-attempted until the next day. `/sheet data export` dumps the active character as JSON
(inline for small sheets, as a `.json` file attachment for large ones), and
`/sheet data import` creates a character from pasted JSON: enabling backup,
sharing between servers, and pre-built character loading.

**Family bonuses** are auto-applied at `/sheet create`: pick a `family:` from
the autocomplete and the character gets +1 to the family's Trait automatically
(e.g. Hida → +1 Strength, Doji → +1 Awareness). The `clan:` is auto-set from
the family if not specified.

`/dm log_channel` designates a text channel as the **combat log**: a compact,
persistent record of combat events. Attacks (hit/miss), damage applied (with wound
level and death), healing, turn/round advances, conditions set/cleared, stances,
Guard, Full Defense, grapple events, duel stages, creature attacks, spell damage,
and medicine treatments are all logged as one-line entries. `/dm clear_log` removes
the setting. The log is per-server (guild-scoped) and stored in the database.

`/combat turn hold` and `/combat turn delay` let the DM mark a combatant as holding or
delaying their action: the encounter display shows ⏸️HELD / ⏳DELAYED markers.
`/combat turn act` resolves a held or delayed combatant's action: clears the flag,
resets action economy, and logs the event to the combat log channel.

**Combatant autocomplete**: all combat commands that take a combatant name
(`/fight stance`, `/combat condition set`, `/fight guard`, etc.) now offer
Discord autocomplete, so DMs pick from a dropdown rather than typing names.

**Encounter persistence**: encounters are saved to the database on every state
change and restored automatically on bot startup. A restart no longer loses an
in-progress fight.

**Room-scoped initiative**: `/combat room` (run inside a room thread) adds
every room member's active character to initiative in one command. The DM can
then add NPCs and creatures with `/combat npc` and `/combat creature`.

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
│   ├── advantages_catalog.py # AUTO-GENERATED: 177 advantages/disadvantages (verbatim).
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

**Phase 61: Creature Template Info (Bestiary Viewer)**

| Command | What it does |
|---|---|
| `/creature search` | Search templates with detailed multi-line output: rings (with abbreviated trait overrides), attack/damage with flat bonuses, TN, Reduction, Fear, wound total, and tags. Paginated at 5 per page. Richer than `/creature catalog`. |
| `/creature info` | Full stat block of a bestiary template: rings with overridden traits, initiative, attack/damage (including flat bonuses), Armor TN, Reduction, Fear, wound track with level ranges, special abilities (invulnerability, spirit, undead, fear), and all tags. Ephemeral, DM-only. Uses existing template autocomplete. |
| `/creature compare` | Side-by-side comparison of two bestiary templates in one embed. Each creature shown as a compact stat summary (abbreviated traits, attack/damage, TN, wounds, specials, tags). Useful for DM encounter prep. Ephemeral, DM-only. |

The embed shows:
- **Rings** - e.g. "Air **1** (Reflexes 3) · Earth **2** · Fire **1** (Agility 3) · Water **3**" - trait overrides in parentheses, non-overridden rings shown clean
- **Combat** - initiative, named attack with roll/keep + flat bonus, damage roll/keep + flat bonus, Armor TN, Reduction, Fear (if > 0)
- **Wound Track** - level ranges derived from thresholds, e.g. "Healthy 0–16 · Nicked 17–31 · Dead 32"; proportional fallback for creatures with no explicit thresholds
- **Special Abilities** - generated from tags (undead immunities, invulnerability type, spirit half-damage, fear penalty)
- **Tags** - full tag list as inline code

Distinct from existing `/creature view` (which shows a *spawned* instance with current wounds). This is a reference lookup - no instance needed.

**Phase 61 (cont.): Category System**

| Command | What it does |
|---|---|
| `/category create` | Create a named category (e.g. "Bandits", "Town Guards"). 64-char limit, case-insensitive unique per server. |
| `/category delete` | Delete a category. Members (NPCs/creatures) are **not** deleted - only the grouping is removed. |
| `/category rename` | Rename a category (same uniqueness rules). |
| `/category add` | Add an NPC or creature to a category. Validates the entity exists before adding. |
| `/category remove` | Remove an NPC or creature from a category. |
| `/category bulk_add` | Add multiple NPCs or creatures at once (comma-separated names). Reports added, already-present, and not-found. |
| `/category bulk_remove` | Remove multiple NPCs or creatures at once (comma-separated names). |
| `/category list` | List all categories on this server with member counts. |
| `/category view` | View all members of a category, grouped by type (NPCs / Creatures). |
| `/category spawn` | Spawn all creature templates in a category as combat-ready instances. Skips already-spawned and unknown templates. |
| `/combat category` | Add all NPCs and creatures in a category to the active encounter's initiative tracker. Rolls initiative for each, applies Swift bonus for NPCs with swift weapons. |

Categories use **name-based** references rather than IDs, so entries survive creature delete/respawn cycles. Storage uses two tables (`categories` + `category_members`) with cascading deletes. Autocomplete on category names across all subcommands.

Viewing an NPC (`/npc view`) or creature (`/creature view`) now shows which categories they belong to in a "Categories" field on the embed.

**Phase 62: NPC Enhancements**

| Command | What it does |
|---|---|
| `/npc-edit item` | Add or remove items from an NPC's inventory. Supports quantity, case-insensitive matching, partial removal. Mirrors `/inventory` for PCs. |
| `/npc-edit spell` | Add or remove a spell from an NPC's known spell list. Case-insensitive duplicate detection. |
| `/npc notes` | Set or clear free-text notes on an NPC (appearance, personality, plot hooks). Shown in the Details section of the NPC embed. Omit text to clear. |
| `/npc clone` | Clone an existing NPC with a new name. Deep copies all fields (traits, skills, equipment, spells, inventory), resets wounds to 0. Useful for creating variants (e.g. "Guard Captain" from "Town Guard"). |
| `/npc create` | Staff NPC builder with exact stats, ephemeral: name and notes, clan, family (+1 Trait), school and Rank (Benefit, skills, Honor, outfit, techniques), every Ring/Trait from a menu, skills by category (specialty skills and emphases via a popup), advantages and disadvantages by category, weapon/off-hand/armor, Honor/Glory/Status/Koku. Review, then save as an NPC, as a template, or both. |
| `/npc edit` | Reopen a stored NPC in the same builder, seeded with its current values, starting at Rings and Traits. Save changes overwrites the NPC (wounds are kept; techniques follow the school and Rank). |
| `/npc form` | The same in one popup: a typed stat block (`Sta 3 Wil 2 ...`, `Kenjutsu 3 (Katana), Lore: Shadowlands 2`, `weapon: katana; armor: light; adv: Large`, `clan: Crab; school: Hida Bushi; rank: 2; honor: 4.5`). Traits typed here are final values. Validated, previewed, then saved. |
| `/npc template save` · `spawn` · `list` · `view` · `delete` | Reusable NPC templates. `save` copies an existing NPC; `spawn` creates fresh NPCs from a template (`count:` numbers them: Bandit 1, Bandit 2). Spawned NPCs are independent: wounds and edits never touch the template. |
| `/npc-edit equip` | Set an NPC's equipped weapon, off-hand weapon, and/or armor name. All three parameters are optional - provide whichever you're changing. Empty string clears the field. |
| `/npc-edit feature` | Add or remove from any list field: Advantage, Disadvantage, Technique, Kata, Kiho, Weapon (owned), Weapon Quality, or Emphasis (requires `skill:` parameter). Case-insensitive duplicate detection. |
| `/npc-edit affinity` | Set an NPC's shugenja affinity and/or deficiency element. Choice of Air/Earth/Fire/Water/Void/(clear). |

**Phase 63: Combat Enhancements**

Three new commands for managing terrain, environmental effects, and area damage during encounters:

| Command | What it does |
|---|---|
| `/fight env cover` | Set a combatant's cover/terrain Armor TN bonus (range -30 to +30). Persists until the DM changes it or the encounter ends. Automatically applied during attack resolution. Set to 0 to clear. |
| `/fight env notes` | Set or clear an environment description for the encounter (e.g. "Burning temple, dense smoke, slippery floor"). Shown in the initiative tracker and combat summary. Omit text to clear. |
| `/fight env damage` | Apply environmental damage (fire, falling, poison, etc.) to multiple combatants at once. Comma-separated names or "all". Handles both characters and creatures. Optional `ignore_reduction` flag bypasses armor reduction. Logged to combat log. |

Cover bonus is wired into all attack resolution paths: main attacks, Extra Attack second strikes, and creature attacks. It stacks with Guard, Full Defense, Void Armor TN, and other modifiers. Displayed in both the initiative tracker and the `/combat summary` embed.

---

## Step 1: Create your Discord bot (one time, ~5 minutes)

You do this once, in a web browser. No Linux needed.

1. Go to <https://discord.com/developers/applications> and log in.
2. Click **New Application**, give it a name (e.g. "Rokugan"), and **Create**.
3. In the left sidebar, open **Bot**. Click **Reset Token**, then **Copy** : 
   this long string is your **bot token**. Keep it secret (it's a password to
   your bot). You'll paste it into `.env` in Step 2.
   - You do **not** need to turn on any "Privileged Gateway Intents": this bot
     uses slash commands, which don't require them.
4. In the left sidebar, open **OAuth2 → URL Generator**:
   - Under **Scopes**, tick **`bot`** and **`applications.commands`**.
   - Under **Bot Permissions**, tick **Administrator** (simplest), or at
     minimum: **Manage Roles**, **Manage Channels**, **Manage Messages**,
     **Send Messages**, **Embed Links**, **Manage Nicknames**, and for
     play rooms: **Create Private Threads**, **Send Messages in Threads**,
     and **Manage Threads**.
   - Copy the generated URL at the bottom, open it in your browser, and pick
     the server you want to add the bot to. (You must have "Manage Server" on
     that server.)

The bot now belongs to your server, but it's offline until you run it (Step 2).

---

## Step 2: Run it (locally first, to make sure it works)

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
#     DISCORD_GUILD_ID to your server's ID: right-click your server icon in
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

## Security: the one rule that matters

- **Never share or commit your bot token.** It lives only in `.env`, which
  `.gitignore` already keeps out of git. If it ever leaks, go back to the
  Developer Portal → Bot → **Reset Token** and update `.env`.

---

## What's next

- **Hosting on Vultr**: a small, cheap Linux box with the bot running as a
  background service that restarts itself and survives reboots, plus a
  copy-paste setup script and a plain-English runbook. (You won't need to
  learn Linux to operate it.)
