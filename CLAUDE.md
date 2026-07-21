# CLAUDE.md — Rokugan Persistent World

## What This Project Is
An online persistent world set in Rokugan (Legend of the Five Rings, 4th Edition).
The simulation runs continuously server-side whether players are connected or not.
Players connect to a living world — they do not host or drive it.
All gameplay resolves through L5R 4th Edition rules (Roll and Keep dice system).

## Engine and Language
- Godot 4.6.2-stable
- GDScript (typed where possible — always annotate variables and return types)
- Networking is NOT in scope yet — do not scaffold multiplayer, RPC, or
  ENet/WebSocket systems until explicitly instructed

## The GDD Is the Authoritative Source
All game mechanics are in /gdd/ as markdown files.
The master index is at /gdd/00_INDEX.md — read it before asking what exists.

**All GDD sections are now open for implementation — there are no off-limits sections by policy.**
**Any game design decision (new mechanics, numeric values, behavioral rules not already specified in the GDD) requires explicit owner approval before implementation.** If the GDD doesn't specify a value or behavior, stop and ask — do not invent defaults.
Never extrapolate from one system to another (e.g. land combat rules to naval
combat, one school's technique to another's). If the GDD is silent, stop and ask.

**The GDD design files in /gdd/ are NOT read-only — they MAY be edited, but
every edit requires the owner's explicit, prior permission.** You may NEVER
edit, add, remove, or reword any design content in /gdd/ on your own initiative. Before touching a GDD design
file you MUST: (1) state exactly what you propose to change and why, (2) ask
for the owner's opinion, and (3) receive explicit, unambiguous approval. No
approval, no edit — silence is not approval, and a general "go ahead" on a
task does not extend to GDD design changes. The owner's opinion governs the
final wording. Updating the Code Implementation Status table in
/gdd/00_INDEX.md to reflect what code now exists does NOT require approval
(it records implementation status, not design); changing design intent,
mechanics, or numeric values anywhere in /gdd/ always does.

When implementing any system, read its LOCKED section directly from /gdd/.
Do not rely on summaries, cross-references, or inference. LOCKED sections win.

## Section Quick-Reference
When implementing or auditing a system, go here first:

| System                                        | GDD Section(s)       |
|-----------------------------------------------|----------------------|
| Dice engine — Roll & Keep (xky)               | 4.5                  |
| Character stats, wound levels, AP budget      | 4.5                  |
| Honor & Glory scale and consequences          | 4.6                  |
| Resource production / consumption / tick      | 4.3                  |
| Rice market and trade routes                  | 4.3.18               |
| Feasibility ledger / war readiness            | 4.3.17               |
| Starvation warfare / harvest raid             | 4.3.17 Phase 4       |
| Settlement creation / construction            | 4.3.22               |
| Kami worship economy                          | 4.3.21               |
| Province and settlement data                  | 2.3                  |
| Kaiu Wall — SI, pressure, sorties             | 2.4                  |
| Jigoku Horde generation                       | 2.4.4–2.4.8          |
| Shadowlands, Taint, jade rules                | 2.4                  |
| Regional price modifiers                      | 11.8                 |
| Province insurgency lifecycle                 | 11.11                |
| Festivals, Rokuyo, championships              | 11.5                 |
| Miya's Blessing (annual rice transfer)        | 11.5b                |
| Clan elite units (24 types)                   | 11.6                 |
| Mass battle resolution                        | 11.7                 |
| Army upkeep and field deprivation             | 11.7                 |
| Supply tether system                          | 11.7                 |
| Siege mechanics                               | 11.7                 |
| Army movement (sub-tile)                      | 11.7a                |
| Levy & mobilization                           | 11.7a                |
| Military promotion system                     | 11.7a                |
| Order system (command budgets)                | 11.7a                |
| Military service assignment                   | 11.7a                |
| PU reconciliation (battle → world map)        | 11.7                 |
| Ship types & naval trade                      | 11.9                 |
| Naval combat system                           | 11.9                 |
| Event durations                               | 11.7b                |
| Disposition scale and modifiers               | 12.2                 |
| Clan & family collective disposition          | 12.2b                |
| Gift-giving system                            | 12.3                 |
| Performative arts system                      | 12.4                 |
| Daily conversation system                     | 12.6                 |
| Letter system / delivery pipeline             | 12.7                 |
| Secret, seduction, assassination, bound/escape| 12.8                 |
| Intimidation & blackmail                      | 12.9                 |
| Favor system                                  | 12.10                |
| Inventory system                              | 12.11                |
| Time system (IC day / season / year)          | 13                   |
| Action point budget                           | 14                   |
| Court types and lifecycle                     | 15.1, 15.2           |
| Court commitment system                       | 16.4                 |
| Imperial Edicts                               | 15.1, 15.2, 55.10    |
| Topic momentum / propagation                  | 16, 15.5, 15.6       |
| Court action menu (s15.4)                     | 15.4                 |
| Court priority and early departure            | 15.8                 |
| Winter Court lifecycle (host selection,       | 55.10                |
|   invitations, delegation, Emperor's Peace)   |                      |
| Personal visits                               | 17                   |
| NPC objectives and personality                | 18, 19               |
| Biological family web                         | 22.6                 |
| Marriage system                               | 22.7                 |
| Hostage system                                | 22.9                 |
| Succession system                             | 22.5                 |
| Law, legal status, consequence mapping        | 2.8, 57.47           |
| Crime investigation (scene, witnesses)        | 57.15, 57.16, 57.47  |
| War status / war score                        | 53                   |
| War justification / casus belli               | 53.1                 |
| War termination                               | 53                   |
| Intra-clan civil war                          | 53.2                 |
| Courtier school techniques & rerolls          | 29.15                |
| Skill resolver (technique/wound/emphasis)     | 29.15, 4.5           |
| Individual combat                             | 40                   |
| ASCII map mission generation                  | 56                   |
| Quest seeds                                   | 56.1                 |
| Spiritual insurgency (trigger layer)          | 56.16                |
| Bloodspeaker cult network                     | 56.14                |
| NPC decision engine — core loop               | 55 (all subsects)    |
| NPC decision engine — amendments              | 57 (all subsects)    |
| Province triage                               | 55.9                 |
| Strategic review (lord seasonal)              | 55.10                |
| Dragon governance (Togashi oversight)         | 55.10.2              |
| Phoenix governance (Elemental Council)        | 55.10.3              |
| Reactive decision path                        | 55.11                |
| Named monk standing objectives                | 55.11b               |
| Information system / knowledge transfer       | 55.12, 55.7, 55.6    |
| Commitment registry / social obligation       | 55.31                |
| Approach evaluation / action retry            | 55.30                |
| Resource availability modifier                | 55.32                |
| Orphaned objectives (lord death)              | 55.33                |
| Court availability helper                     | 55.34                |
| Opportunity scanner / objective self-selection| 55.26.1              |
| Primary objective decomposer (13 trees)       | 55.28                |
| Travel commitment and oscillation prevention  | 55.29                |
| Objective progress functions                  | 55.29.3              |
| NeedType enum reconciliation                  | 57.11                |
| ActionID naming reconciliation                | 57.12                |
| Military hierarchy                            | 57.21                |
| Governance action wiring (marriage, vacancy)  | 57.20                |
| Zone subtypes and flag matrix                 | 57.36                |
| Character sheet field index                   | 57.35                |
| Tattoo system                                 | 57.25                |
| Spell system (Ring values, casting, slots)    | 31–37                |
| Kata eligibility, acquisition, effect stubs   | 30, 30a              |
| Artisan & crafting system                     | 49                   |
| Sculpture system (COMPOSE_SCULPTURE)          | 57.28                |
| Musha Shugyo (warrior's pilgrimage)           | 57.48                |
| Clan Champion strategic evaluation           | 57.54                |
| Otomo Seiyaku (alliance suppression)          | 55.22b               |
| NPC advancement (XP, skill/ring progression)  | 52 Part 3, 48, 48a   |
| World population generator (game start pass)  | 52 Part 1, 22.4, 22.8|
| Gempukku / NPC spawning / natural death       | 52, 22.4, 22.7       |
| Ronin system (status transitions, petition)   | 52 Part 5, 52.5      |
| PC integration (presence, AP banking, offline)| 60                   |

## Directory Structure
```
/gdd/                              — GDD markdown files (design source; edit ONLY with the
                                     owner's explicit prior approval — see "The GDD Is the
                                     Authoritative Source". 00_INDEX.md status table is the
                                     one exception: status updates need no approval)
/simulation/                       — Headless simulation logic: NPC engine, resource tick,
                                     world event resolution. NO Node inheritance here.
                                     Plain GDScript classes only (class_name, no extends Node).
/shared/                           — Data models: CharacterData, ProvinceData, etc.
                                     Use Resource subclasses for serialisable data.
/tests/                            — Pre-existing GUT tests. Do NOT add new test files
                                     here (see "Testing — DO NOT WRITE TEST CODE").
/scripts/managers/                 — Godot Autoloads / singletons (WorldState, SimScheduler).
                                     Registered in Project Settings. May extend Node.
/scripts/ui/                       — Player-facing Godot scenes (UI, ASCII map display, etc.).
                                     Nothing here should contain simulation logic.
/systems/npc_engine/data/tables/   — JSON scoring tables for the NPC decision engine
                                     (8 files: objective_alignment, personality_lean,
                                     personality_filter, action_skill_map, competence_table,
                                     disposition_tiers, urgency_rules, topic_position_alignment).
```

## GDScript Conventions
- Always use static typing: `var x: int`, `func foo(a: String) -> bool:`
- Use `class_name` on every file that defines a reusable type
- Simulation classes must NOT extend Node. They are plain objects.
  Correct:  `class_name ResourceTick` (no extends)
  Wrong:    `class_name ResourceTick extends Node`
- Use `const` for lookup tables and enum-equivalent dictionaries
- Prefer `enum` blocks for NeedType, ActionID, DispositionTier, WoundLevel, etc.
- Autoloads are the only global singletons — do not use static variables as
  a substitute for proper singleton registration
- Never put simulation logic inside a scene's _ready() or _process().
  Scenes call into /simulation/ — simulation does not call into scenes.

## Testing — DO NOT WRITE TEST CODE
**Do not write GUT tests or any test files. Write only the real production code
that will actually run.** When a task is done, deliver the implementation and
wiring — not a `test_*.gd` file. Validate by re-reading the actual code against
its GDD section and by parse-checking (`godot --headless --check-only -s <file>`),
not by authoring tests. Existing tests under `/tests/` may remain, but new work
does not add to them. (Design intent — keep pure simulation functions callable
without a scene tree and pass dependencies explicitly — still holds, because it
keeps the real code clean; it is no longer a directive to write tests.)

## Hard Constraints — Never Violate Without Asking
- PC death is permanent. No resurrection mechanic of any kind.
- Jade counters Jigoku only. No effect on other spirit realms.
- Any maho use raises PTL whether detected or not.
- The simulation does not pause for absent players.
- NPCs never use the ASCII map unless a PC is personally present.
  NPC-only resolution goes through the dice engine, not map generation.
  (NPC-vs-NPC fights resolve via summary roll, not tile-by-tile — GDD s40.x.)
- ASCII map movement is real-time when no combat is active in a zone; the
  zone switches to turn-based (Initiative/Round/Turn) only when combat is
  initiated, and returns to real-time when combat resolves. See GDD s40.x.
- CrimeRecord exists at world level. The system always knows who committed
  the crime. Investigation is players discovering what the system knows.
- met_characters, hostile tag, provocation flag, zone_event_log,
  operational_superior_id, spell_intent tag, and weapon material tag are
  cross-cutting constraints. Read their authoritative sections before writing
  any code that reads or writes these fields.
- One topic per piece of information. One topic per death. One topic per event.
- Dead characters always carry NEUTRAL subject_role valence.
- Spirit realms are not evil except Jigoku. Do not implement jade as a
  general-purpose spirit ward.
- **Check existing channels before wiring any ActionID.** Before adding an
  ActionID to a context action list, creating an executor intercept, or
  assigning an AP cost, verify that the action does not already have a
  dedicated system (Strategic Review directives, daily letter pass, reactive
  events, etc.). If a channel already handles it, the wiring belongs in that
  system — not the daily AP loop. Do not create duplicate execution paths.
- **Do not invent mechanics.** Every game mechanic, numeric value, enum value,
  edict type, action type, honor cost, disposition modifier, deadline, threshold,
  or behavioral rule must trace back to a specific LOCKED GDD section or to an
  explicit entry in this CLAUDE.md file. If the GDD does not specify a value or
  behavior, stop and ask — do not fill in plausible defaults, extrapolate from
  adjacent systems, or invent new enum values. Structural wiring (routing,
  function signatures, orchestrator plumbing) is allowed; game design is not.

## What's Been Built So Far

The detailed dated changelog ("Systems Added" + "Known Code Issues" entries) has been
**archived to `docs/CLAUDE_CHANGELOG_ARCHIVE.md`** to reduce per-turn token cost. It is
NOT auto-loaded. When you need history on a specific past system, `grep` the archive for
its name/section before assuming it doesn't exist.

Evergreen rules that lived in that section:
- **Before writing any new `/simulation/` or `/shared/` file, search both dirs** to confirm
  the system doesn't already exist. Per-section status (DONE / PARTIAL / NOT STARTED /
  REFERENCE) lives in the **Code Implementation Status** table at the bottom of
  `/gdd/00_INDEX.md`.
- **The entire ASCII-map / tile-combat / individual-combat (s40) / PC-facing spawn stack is
  built and headless-verified, but NOT live-reachable** — it is on the owner's PC-travel
  HOLD (2026-06-06). The world-map → mission entry point is deferred. Anything in that stack
  is validated by headless drivers, not a live session, until the HOLD lifts.
- **GUT is non-functional headless in this environment** and writing test code is against
  policy — validate new work by re-reading it against its GDD section, parse-checking
  (`godot --headless --check-only`), and hand-tracing reachability, or with a temporary
  headless SceneTree driver (deleted after).
- **Godot 4.6.2-stable is installed** (see SessionStart) — headless `--check-only` and
  `--import` parse-checks and `-s` driver runs work, but the full project's Node/autoload
  graph stalls a bare `-s` run; use a minimal autoload-free copy of `simulation/`+`shared/`
  for driver verification, matching the pattern used throughout the archive.

**Sections available for design (source material exists, owner authorization required before
coding — see "Decisions Needed", Section D):** s38 kiho, s40 individual combat (partial),
s54.7 Kolat, s57.42–s57.43 sailing, s57.46 allied NPC companion. DONE: s31–s37 spells,
s43 maho, s44 mutations, s45 advantages, and the s57 art/craft systems.

## Resolved Design Decisions

### 1. Topic Identity — RESOLVED: int IDs
**Decision:** Standardise on `int` as canonical topic identity everywhere.
- `topic_pool` migrates from `Array[String]` to `Array[int]`
- `TopicData.topic_id: int` remains unchanged (already correct)
- `ContextSnapshot.known_topics: Array[int]` remains unchanged
- A world-level auto-incrementing counter assigns each new topic its `topic_id`
- Slugs (e.g. `"crane_scandal_y3m7"`) become a `slug: String` metadata field
  on `TopicData` — used for logging and debugging, never matched on as identity
- Letter/conversation code migrates from string slug matching to int comparison
- **Rationale:** Consistent with NPC engine's existing int patterns, compact for
  network payload, matches Godot's idiomatic int-ID conventions, fast Dictionary
  lookups. No translation layer needed.

### 2. Timestamp Sentinel — RESOLVED: -1 for "never happened"
**Decision:** All "never happened" int timestamps use `-1` as sentinel.
- IC day 0 remains a valid game day (no epoch shift)
- Fields currently defaulting to `0` for "never" migrate to `-1`:
  `last_medicine_treatment_ic_day`, `void_refresh_blocked_until`, and any others
- Comparison convention: `if timestamp == -1: never happened`
- **Rationale:** `-1` is a universal sentinel convention and matches Godot's own
  patterns (e.g. `String.find()` returns `-1`). Avoids the hidden rule of "day 0
  isn't real" and requires no time system changes.

### 3. CommitmentData Redundant Fields — RESOLVED: keep source_action_id
**Decision:** Remove `created_by_action`. Keep `source_action_id` only.
- One fact ("which action created this commitment") = one field
- `source_action_id` follows the `_id` suffix convention used across the
  codebase (`commanded_unit_id`, `assigned_company_id`, `kolat_superior_id`)
- If a future distinction genuinely arises, it gets a new field with a clear
  name — not silent divergence of an originally-identical pair
- **Rationale:** Eliminates a redundancy that would otherwise become a debugging
  hazard if the two fields ever drifted apart unintentionally.

### 4. knowledge_pool Typing — RESOLVED: typed KnowledgeEntry Resource
**Decision:** Promote `knowledge_pool` from `Array[Dictionary]` to
`Array[KnowledgeEntry]` where `KnowledgeEntry` is a Resource subclass.
- Create `shared/knowledge_entry.gd` with `class_name KnowledgeEntry`
  extending Resource, typed fields for the ~6 known keys
- `L5RCharacterData.knowledge_pool` becomes `Array[KnowledgeEntry]`
- InformationSystem reads/writes update from `entry["key"]` to `entry.key`
- **Rationale:** Consistent with CommitmentData, TattooData, TopicData pattern.
  Catches key typos at parse time instead of silent nulls at runtime. Native
  Godot Resource serialization. Compact and predictable for network sync.
  Autocomplete and static analysis support in GDScript.

### 5. Maho Detection Pipeline — RESOLVED: three-channel topic generation
**Decision:** Maho use is never directly observable. Detection flows through three
independent channels; no single channel is reliable alone (per s57.47.7). All
three feed the same downstream machinery: a topic enters a magistrate's
`known_topics` → UPHOLD_LAW fires → INVESTIGATE_CRIME assigned.

**Channel 1 — PTL accumulation (province-level, passive, already LOCKED)**
Every maho cast raises PTL +1.0 (MahoSystem.PTL_PER_CAST). s11.11 (LOCKED)
already defines what happens next:
- PTL 3 → Province Taint Manifestation insurgency spawns; Tier 3 crisis topic
  generated automatically. Observable to any lord monitoring province reports.
- PTL 6 → Tier 2 crisis topic generated on first crossing.
- PTL 9 → Tier 1 crisis topic generated immediately.
These crisis topics are the primary indirect signal. Nobody knows maho caused
the PTL rise — they know the province is spiritually sick. Investigation traces
it back. No new topic generation code needed for Channel 1: the insurgency
system already produces the signal. PTL detection roll for shugenja:
Perception + Lore: Shadowlands vs TN (PTL × 5); Kuni and Asako +2k0 (s11.11).

**Channel 2 — Physical evidence at casting site (zone-level, active)**
Blood at the casting site follows the poison residue pattern from s57.48.8
exactly:
- At cast time: caster makes a Stealth / Agility roll (same formula as
  CONCEAL_ITEM). The result becomes the blood evidence `concealment_tn`.
- Evidence persists in `zone_event_log` for 1 IC season (same purge cycle
  as s57.48.8).
- Any character who runs EXAMINE_CRIME_SCENE in that zone rolls
  Investigation (Notice) / Perception against the `concealment_tn`.
- On success: generates a **Tier 3 topic** ("Evidence of blood magic in
  [zone]"). Topic does NOT name a perpetrator — the crime record exists
  at world level, but the investigator must narrow suspects via
  `zone_event_log` entries for who was present during the evidence window.
- No new ActionID or topic type needed; this uses existing EXAMINE_CRIME_SCENE
  and the world-known CrimeRecord.

**Channel 3 — Taint symptoms on the caster (personal, proximity-based)**
Caster's accumulating Taint is the most direct signal but requires physical
proximity. Detection is a Lore: Shadowlands check (NOT the Sense spell —
canonically Sense detects elemental kami, explicitly NOT kansen; owner
correction 2026-06-10). Two paths, both gated on proximity:
- **Passive (incidental) Lore: Shadowlands check** during any action that puts the detector in
  social proximity (INVESTIGATE_PROVINCE, court attendance, COMMUNE_WITH_SPIRITS
  near the suspect): Kuni Witch-Hunters and Asako Inquisitors automatically
  attempt this check when their known_topics include a Taint-related event in
  the same province. Other shugenja only attempt it if they hold Lore:
  Shadowlands 3+.
- Threshold triggering a topic: target's Taint Rank ≥ 2 AND no Wall service
  record on file (per s57.47.7: "has no innocent explanation").
- On detection success: generates a **Tier 3 topic** naming the specific
  character as a suspected maho user. This is a direct accusation topic —
  unlike Channel 1 and 2, it names a perpetrator.
- TN for the Lore: Shadowlands check = **(8 − Taint Rank) × 5** (owner-set
  2026-06-10): 30/25/20/15 for Rank 2–5. Both the passive (incidental) path and
  the active, deliberate examination (EXAMINE_FOR_TAINT) at the same TN are WIRED.

**Channel 4 — Direct witnesses (already handled)**
If `witnesses` is non-empty on the CrimeRecord, those characters carry direct
knowledge. They can testify through the existing court/investigation system.
No new code. The witness list in CrimeRecord IS the fourth channel.

**What is not yet implementable:**
- Channel 3 passive Lore: Shadowlands detection roll — WIRED (TN = (8 − Taint
  Rank) × 5, owner-set 2026-06-10). An active, deliberate Lore: Shadowlands
  examination (EXAMINE_FOR_TAINT, same TN) is now also WIRED — see "Maho
  Channel 3 active examination". NOTE: the Sense spell is NOT the detection
  tool — canonically Sense detects elemental kami, explicitly NOT kansen
  (owner correction 2026-06-10).
- Kuni/Asako/Kuroiban as Named Characters with UPHOLD_LAW standing objectives
  (blocked on s11.3.5 becoming LOCKED — currently PARTIALLY DESIGNED)
- `CAST_MAHO` as an NPC ActionID (no LOCKED specification exists for maho as
  a deliberate NPC action; do not implement until Section 43 or 55 specifies it)

**Rationale:** Channels 1 and 2 are wirable now — they use entirely existing
systems (insurgency topic generation, zone_event_log, EXAMINE_CRIME_SCENE).
Channel 3's passive proximity check is WIRED at TN (8 − Taint Rank) × 5.
This mirrors the GDD's intent: "multiple channels, none reliable alone."
The caster who casts once in a remote province and leaves quickly may never be
caught. The one who casts repeatedly in a populated area accumulates risk across
all four channels simultaneously.

### 6. Effect Application Pattern — RESOLVED: dual pattern with naming guard
**Decision:** Two coexisting patterns for applying character mutations:
- **Pattern A (Deferred):** System returns effect keys → EffectApplicator
  reads them and mutates characters centrally. Standard keys consumed:
  `honor_change`, `glory_change`, `infamy_gain`, `infamy_change`,
  `disposition_change`, `recipient_disposition_change`, `recipient_modifiers`,
  `consume_item_id`, `witness_disposition_loss` + `witnesses`.
  Used by: social actions, military, admin, intimidation, gifts.
- **Pattern B (Pre-applied):** System directly mutates characters before
  returning. Return dict contains metadata keys prefixed `subject_*` or
  suffixed `*_cost` (never matching Pattern A keys). Used by: SecretSystem
  (covert costs always apply regardless of success; exposure mutates the
  secret's subject, not the actor) and SeductionSystem (honor/infamy cost
  for attempting).
- **Safety rule:** Never use `honor_change`, `glory_change`, or `infamy_gain`
  as return dict keys from a system that pre-applies mutations. Use
  `subject_honor_loss`, `subject_glory_loss`, `subject_infamy_gain`,
  `honor_cost`, `glory_cost` to prevent EffectApplicator double-application.
- `FavorSystem.break_favor()` returns `disposition_floor` (per-tier minimum)
  which `_apply_favor_breach()` in DayOrchestrator enforces as a lower clamp.
- **Rationale:** Pre-application is correct for always-pay costs (covert action
  moral costs apply even on failure). Deferred application is correct for
  outcome-dependent effects (disposition gains only on success). The naming
  guard prevents accidental double-application across the two patterns.

## Pending Migration Tasks
Code refactors required by the resolved design decisions above.
None of these are design work — the decisions are locked. These are
mechanical code changes to implement them.

- [x] **Topic int migration** — Changed `L5RCharacterData.topic_pool` from
  `Array[String]` to `Array[int]`. Added `slug: String` field to `TopicData`.
  Updated DailyConversation and LetterSystem from string topic matching to
  int comparison. `LetterData.topic` changed from `String` to `int` (sentinel
  `-1` for no topic). World-level `next_topic_id` counter deferred until
  topic creation code is implemented.
- [x] **Sentinel cleanup** — Changed "never happened" fields from `= 0` to
  `= -1`: `void_refresh_blocked_until`, `last_medicine_treatment_ic_day`
  (character_data.gd), `last_report_ic_day` (province_data.gd,
  npc_data_structures.gd). Updated test assertions.
- [x] **CommitmentData field removal** — Removed `created_by_action` from
  `shared/commitment_data.gd` and `create_commitment()` in
  `commitment_registry.gd`. `source_action_id` is the sole surviving field.
- [x] **KnowledgeEntry Resource** — Created `shared/knowledge_entry.gd`
  (`class_name KnowledgeEntry extends Resource`) with typed fields: `source`,
  `entry_type`, `data`, `confidence`, `season_acquired`. Changed
  `L5RCharacterData.knowledge_pool` to `Array[KnowledgeEntry]`. Updated all
  InformationSystem methods from dict access to property access. Updated all
  test files.

## Decisions Needed and To-Be-Implemented Items

Everything below needs a decision, a GDD spec, or a dependency before dev
can proceed. Items are grouped by what they're waiting on. Each entry says
what the code currently does, what it needs, and where the answer lives.

**Policy:** To-be-implemented features are no longer off-limits by default. Any item
here MAY be implemented once the owner gives explicit, prior authorization
for that specific feature (see Section D). Items waiting purely on a missing
dependency (e.g. sub-tile map data in Section C) still cannot proceed until
that dependency exists, regardless of authorization.

---

### A. PROVISIONAL Numeric Values — Audited 2026-05-24

These values were invented because the GDD describes a mechanic without
giving exact numbers. Each is marked PROVISIONAL in code. All 22 values
have been audited for reasonableness against L5R 4e scale, comparable
mechanics, and GDD intent. A2 confirmed as GDD-sourced. A9/A10/A13
replaced with variable season-aware deadlines. A20/A21 confirmed against
GDD. The remaining 15 values pass reasonableness review and are retained
pending playtesting.

| # | Value | Current | Where Used | GDD Says | Code Location |
|---|-------|---------|------------|----------|---------------|
| A1 | Non-shinobi TN penalty on Phase 1 access rolls | +10 | assassination_system.gd | RESOLVED — s12.8a: equal to lockdown response; between Seppun half (+8) and full (+15) protection. | s12.8a |
| A2 | Per-failed-access permanent TN penalty tiers | +5/+10/+15 | assassination_system.gd | RESOLVED — s12.8a: mirrors GDD-confirmed suspicion accumulation tiers (+5/+10/+15 per s12.8). | s12.8a |
| A3 | Critical failure detection TN (assassin's roll total) | roll total | assassination_system.gd | RESOLVED — s12.8a: detection difficulty scales with assassin quality; better assassins leave less detectable traces. | s12.8a |
| A4 | Execution honor cost | Low Skill/Stealth | assassination_system.gd | RESOLVED — s12.8a: Table 2.3 Low Skill cost for Stealth. Shosuro=0, Scorpion=half, others rank-scaled. GDD: "Scorpion pay almost nothing, others pay steeply." | s12.8a |
| A5 | Concealment partial failure threshold | missed by <10 | assassination_system.gd | RESOLVED — s12.8a: standard L5R 4e near-miss convention. Miss by 1–9 = partial; 10+ = clear failure. | s12.8a |
| A6 | Daily detection suspicion gain on observer success | +3 | assassination_system.gd | RESOLVED — s12.8a: calibrated for 10–15 day natural windows before lockdown. ~3–4 detections to watchful threshold. | s12.8a |
| A7 | Target Status as direct TN adder on Phase 1 access | int(status) | assassination_system.gd | RESOLVED — s12.8a: direct linear mapping of GDD "higher Status = higher base TN." Status 1–10 maps to +1–10. | s12.8a |
| A8 | Non-shinobi detection bonus for observers | +5 Investigation | assassination_system.gd | RESOLVED — s12.8a: matches watchful-household bonus (+5). Untrained assassin = as detectable as alert household. | s12.8a |
| A9 | VISIT_PROMISE deadline | Next season start (min 30d) | day_orchestrator.gd | "the season stated in the letter" — RESOLVED | s55.31 |
| A10 | MEETING_ARRANGEMENT deadline | Season after next (min 30d) | day_orchestrator.gd | "the arranged meeting date" — RESOLVED | s55.31 |
| A11 | MEETING_ARRANGEMENT reply disposition gate | >= 0 | letter_system.gd | RESOLVED — s12.7a LOCKED specifies MEETING_ACCEPT_DISPOSITION = 0 ("neutral or positive disposition"). | s12.7a |
| A12 | REQUEST_ALLIED_AID acceptance disposition gate | 31 | action_executor.gd | RESOLVED — s12.2 LOCKED: Friend tier = +31 to +60. Lords accept allied aid from Friend-tier or above. | s12.2 |
| A13 | RESOURCE_PROMISE deadline | Next/after-next season (urgency) | day_orchestrator.gd | "the agreed delivery season" — RESOLVED | s55.31 |
| A14 | TREAT_WOUND raises by Medicine rank | 0-2→0, 3-4→1, 5+→3 | npc_decision_engine.gd | RESOLVED — s57.31a. GDD anchor: s57.31 "At Rank 5 with 3 Raises: 5k1." No 2-Raise tier. | s57.31a |
| A15 | FORGE letter/order NeedType alignment scores | DAMAGE_REL: FIL=70/FO=55; ACQUIRE_LEV: FIL=50/FO=30; SUPPRESS_INV: FO=60/FIL=45 | objective_alignment.json | RESOLVED — s12.8b: calibrated against comparable covert actions. FORGE_ORDER ACQUIRE_LEVERAGE 40→30 (orders compel action, don't produce leverage material). | s12.8b |
| A16 | Forged letter delivery distance | 3 provinces | day_orchestrator.gd | Blocked on map/adjacency data | s12.7 |
| A17 | Forged objective priority | 8 | day_orchestrator.gd | RESOLVED — s12.8b: metadata only (NPC engine does not read priority field). Value documents intent: above normal objectives (5), below crisis override. | s12.8b |
| A18 | Impersonation detection topic tier | TIER_3 | day_orchestrator.gd | RESOLVED — s12.8b: TIER_3. Above Spy Uncovered (TIER_4, identity unknown); below lord assassination (TIER_2). Political scandal at family level. | s12.8b |
| A19 | INVESTIGATE_THREAT priority (from impersonation) | 6 | day_orchestrator.gd | RESOLVED — s12.8b: metadata only (NPC engine does not read priority field). Value documents intent: above UPHOLD_LAW (4) and court attendance (5), below forged orders (8). | s12.8b |
| A20 | Forge authority level | Target's lord_rank via chars_by_id | npc_decision_engine.gd | RESOLVED (B11) | s12.8 |
| A21 | Hunt beast stat blocks (8 of 10 species) | Derived from s54.1 | hunt_system.gd | Bear and ozaru GDD-confirmed; 8 others interpolated | s57.38 |
| A22 | PERFORM_RITUAL alignment score under PERFORM_RITUAL NeedType | PERFORM_RITUAL=100, PERFORM_WORSHIP=90 | objective_alignment.json | RESOLVED — direct action wins its own NeedType (100); worship is valid fallback (90) when ritual conditions not met. | — |
| A23 | World gen POSITION_RANK by role | Role-based: mastery=5, proven=4, veteran=3, junior=2, samurai=1 | world_population_generator.gd | RESOLVED — s52a A23: role-required excellence table (39 entries). Emperor/Clan Champion/School Master/Temple Head/Emerald Champion/Jade Champion/Abbots/Inquisitor leaders = 5; Family Daimyo/Rikugunshokan/Magistrates/Minor Clan Champion/Wall Cmdr = 4; Provincial Daimyo/Senior Courtier/Taisa = 3; Local Daimyo/Chui/Yoriki = 2; Samurai = 1. | s52a |
| A24 | World gen POSITION_STATUS by role | Local Daimyo 4.0, Provincial Daimyo 5.0 (corrected) | world_population_generator.gd | RESOLVED — s52a A24: Local Daimyo 3.0→4.0 (resolves as CITY_DAIMYO, 5 civilian orders), Provincial Daimyo 4.0→5.0 (resolves as PROVINCIAL_DAIMYO, 8 civilian orders). Prior values produced 0 civilian orders for Local Daimyo and wrong tier for Provincial Daimyo. | s52a |
| A25 | World gen BASE_PU per province tier | FAMILY_SEAT=20, GREAT_CLAN=10, MINOR_CLAN=5, UNGOVERNABLE=1 | world_bootstrap.gd | RESOLVED — s52a A25: PU is settlement-level (SettlementData.population_pu). Family castles receive BASE_PU/2 (~7–10 PU after terrain scaling). Villages receive 2–5 PU. Values are fresh-world initialization; production mechanics grow/shrink PU during play. | s52a |
| A26 | World gen _scale_pu_by_terrain multipliers | PLAINS=1.2, COASTAL=1.0, FOREST=0.9, MOUNTAINS=0.7, SWAMP=0.6, WASTELAND=0.3 | world_bootstrap.gd | RESOLVED — s52a A26: directionally correct per GDD terrain flavor. ±10% variance applied after multiplication. | s52a |
| A27 | World gen TERRAIN_PU_DISTRIBUTION | 8 terrain types × 4 sub-types (farming/town/mining/military) | world_generator.gd | RESOLVED — s52a A27: Plains 60/25/5/10, Mountains 25/20/40/15, Wasteland 15/15/10/60, etc. Calibrated against GDD terrain flavor. | s52a |
| A28 | World gen POINTS_PER_RANK for character creation | 4 per insight rank (not 10 — prior CLAUDE.md entry was wrong) | world_generator.gd | RESOLVED — s52a A28: POINTS_PER_RANK=4. Allows Rank 5 characters 16 trait advances above base. Code value was always 4; CLAUDE.md previously stated "10" in error. | s52a |
| A29 | World gen parent age thresholds | Min 16, max 40 year gap | world_population_generator.gd | RESOLVED — s52a A29: 16 = earliest post-gempukku parenthood; 40 = upper childbearing limit. | s52a |
| A30 | World gen marriage rate | 40% per generation | world_population_generator.gd | RESOLVED — s52a A30: leaves majority of lower-status samurai unmarried at world start; ensures most senior characters have family bonds. | s52a |
| A31 | World gen cross-clan marriage rate | 15% of marriages | world_population_generator.gd | RESOLVED — s52a A31: rare enough to be politically significant, common enough to seed cross-clan family tension. | s52a |
| A32 | LEGIONS_PER_ARMY | 3 | world_population_generator.gd | RESOLVED — s52a A32: consistent with ~3,000-soldier army scale. World initialization only; actual composition varies through play. | s52a |
| A33 | Minor Clan Champion stipend | 3.0 koku/season (was 5.0) | world_population_generator.gd | RESOLVED — s52a A33: equal to Family Daimyo. Minor Clan Champion governs at single-clan scale, not multi-family Great Clan scale. | s52a |
| A34 | Dissolution family baseline penalty | −20 | marriage_system.gd | RESOLVED — s57.49b: within Rival tier (−11 to −30, s12.2). Mid-Rival; distinguished from high-end provocations like assassination vengeance (−50). | s57.49b |
| A35 | Dissolution spouse Glory loss | −0.5 | marriage_system.gd | RESOLVED — s57.49b: half of s46 Table 2.4 "Family Dishonor = −1 Glory Rank." Comparable visibility, lesser cause (no personal dishonour by the spouse). | s57.49b |
| A36 | Dissolution clan baseline penalty (cross-clan) | −10 | marriage_system.gd | RESOLVED — s57.49b: s12.2 Stranger/Rival boundary = −10/−11. Clan penalty caps at boundary without forcing structural Rival status. | s57.49b |

---

### B. Design Gaps — Need GDD Spec or Design Decision

These are places where the code cannot proceed because the GDD doesn't
specify the mechanic, or two GDD sections conflict, or a concept has no
implementation path.

**B1. NPC favor invocation — RESOLVED: INVOKE_FAVOR ActionID.**
Added INVOKE_FAVOR to AT_OWN_HOLDINGS, AT_COURT, VISITING context lists.
AP cost 1. Metadata picks highest-tier uninvoked favor via
`_pick_best_favor_to_invoke()`. Executor invokes favor and injects
FAVOR_REQUESTED reactive event on the debtor. objective_alignment entries:
ACQUIRE_RESOURCE (75), DEFEND_PROVINCE (55), REQUEST_AID (85).

**B2. MENTOR executor — RESOLVED: full training pipeline.**
MENTOR executor validates co-location, skill rank gap, and student/sensei
availability. Returns `injects_reactive_event: true` with ACCEPT_TRAINING
data. `_process_mentor_writebacks()` injects reactive event into student's
`pending_events`. Next tick, student's reactive decision evaluates via
`ReactiveDecisions._evaluate_training_response()` (personality-gated:
Kanpeki requires rank gap 2+, Ketsui requires lord-assigned objective).
`_process_training_acceptance_writebacks()` calls
`NPCAdvancement.resolve_training_session()` which applies progress: 100
(sensei 2+ ranks above), 75 (sensei 1 rank above), 25 (sensei self-gain).
Student spends 1 AP on acceptance. Metadata selection picks co-located
student with largest rank gap and positive disposition. Also fixed:
`reactive_type` events now route through `ReactiveDecisions` instead of
being silently discarded (fixes FAVOR_REQUESTED, COURT_INVITATION too).
MENTOR added to TRAIN_SKILL NeedType in objective_alignment (score 80).
14 tests.

**B3. RESTORE_COUNCIL_COMPACT — RESOLVED: seasonal objective assignment.**
Added RESTORE_GOVERNANCE NeedType to objective_alignment.json with
RESTORE_COUNCIL_COMPACT: 100. `_assign_phoenix_champion_restore_objective()`
runs seasonally: assigns RESTORE_GOVERNANCE primary objective to Phoenix
Champions with `phoenix_champion_authority` and Chugi virtue. Ishi-virtue
champions skip (keep authority). Personality-driven per GDD s55.10.3.7.

**B4. Position decay — RESOLVED: positions are permanent.**
Topic position shifts do not decay. `position_hardened` and `position_durable`
flags are now dead forward-wiring — no position decay system will be built.
The flags remain emitted (harmless metadata) but will never be consumed.

**B5. FOLLOWING_ORDERS honor row — RESOLVED: lord-assigned objective trigger.**
`_process_following_orders_honor_writebacks()` fires once per day per NPC
whose primary objective has `assigned_by >= 0` (lord-assigned). Applies
`get_following_orders_honor()` (positive at low rank, negative at high rank).
Deduped per character per day. Numeric values locked in s46a:
HONOR_TABLE_FOLLOWING_ORDERS = [6, 4, 0, 0, -2, -4] (÷10 → +0.6/+0.4/0/0/−0.2/−0.4).
Positive at honor ranks 0–2, neutral at 3–6, gentle negative at 7–10.

**B6. Three Table 2.3 rows — RESOLVED: mechanical triggers wired.**
LYING fires on successful FABRICATE_SECRET when fabricator has positive
disposition toward the secret's subject (lying about someone you like).
DUPED_CRIMINAL fires during impersonation detection when a forged order
was applied AND the victim has a BROKEN commitment with deadline after
the forged order's arrival (tricked into breaking social obligations).
DUPED_FOOLISH fires on travel arrival when the character's primary
objective has `source == "forged_order"` and the destination has no
matching target (sent to a useless location by a fake order).
BUG FIX (2026-05-29): DUPED_FOOLISH previously did not check
`target_province_id`. PATROL_PROVINCE forged orders set only province
target; victims correctly arriving in the target province always had
`has_target_here=false` and incorrectly received the honor penalty.
Fixed by passing `settlements` array to `_process_duped_foolish_on_arrival()`
and building a settlement→province lookup. 10 orchestrator-level tests
added covering all three trigger conditions.

**B7. Koku transfer ActionID — RESOLVED: TRANSFER_KOKU.**
Added TRANSFER_KOKU to AT_OWN_HOLDINGS, AT_COURT context lists and
LORD_ONLY_ACTIONS. AP cost 1. Executor transfers 5 koku base (10 if
sender has 20+), caps at available koku, +3 disposition toward recipient.
Pattern B (pre-applied). Resource validation via ACTION_RESOURCE_COSTS.
objective_alignment: HONOR_COMMITMENT (85), REQUEST_AID (70),
CONDUCT_COMMERCE (60), RAISE_DISPOSITION (40). RESOURCE_PROMISE
fulfillment path added alongside SHARE_SUPPLIES and ORDER_DEPLOY.

**B8. Crime-sourced offenses for PUBLIC_ATONEMENT — RESOLVED: no crime atonement.**
Convicted NPCs do not atone publicly. PUBLIC_ATONEMENT remains topic-sourced
only. CrimeRecord convictions resolve through the sentencing pipeline
(seppuku, exile, execution) — not through voluntary atonement.

**B9. Insult classification — RESOLVED: weighted deterministic selection.**
NPC engine uses hash-based weighted randomness: ELIMINATE_CHARACTER →
ancestors, DAMAGE_RELATIONSHIP → clan, otherwise 10% ancestors / 20% clan /
70% self (deterministic from `(character_id * 7 + target_id * 13) % 100`).
Existing insult_type metadata and honor gain/loss wiring unchanged.

**B10. Data retention — RESOLVED: seasonal purge functions.**
Three purge functions run at each season boundary:
`_purge_resolved_crime_records()` removes records with terminal legal
status (DECREED_GUILTY, CLEAR, PARDONED, ACQUITTED) older than 360 IC
days. FUGITIVE records retained (still active). `_purge_delivered_letters()`
removes delivered letters older than 180 IC days, EXCEPT forged+applied
order letters where the victim hasn't yet detected the impersonation
(retains until impersonation_detected KnowledgeEntry exists).
`_purge_exposed_secrets()` removes publicly exposed secrets immediately
at season boundary (no further use once public).

**B11. Forge authority level — RESOLVED: uses target's lord_rank.**
`_get_target_lord_rank()` looks up the impersonated target in chars_by_id
and returns their lord_rank. For FORGE_ORDER, looks up target's lord's
lord_rank. Falls back to forger's own lord_rank when chars_by_id is empty
or target not found. `_populate_action_metadata()` gains optional
`chars_by_id` parameter (backward compatible). `generate_options()` and
`score_all()` pass chars_by_id through. 3 tests.

**B12. Honor rank-scaling — RESOLVED: universal RANK_SCALE applied.**
`CrimeSystem.RANK_SCALE = [0.0, 0.333, 0.667, 1.0, 2.0, 3.0]` (6 brackets
matching LOW_SKILL pattern). `scale_honor_by_rank(base_cost, character)`
multiplies any flat honor cost by the rank-appropriate multiplier.
Applied to: assassination ordering/execution honor, secret fabrication/
exposure honor, forge honor, declare_war total_war honor, atonement
critical failure, court early departure, siege honor loss, treason
intervention/false accusation/refused seppuku. Table 2.3 Low Skill costs
(already rank-scaled via their own 6-bracket arrays) are NOT double-scaled.

---

### C. Areas Requiring Sub-Tile Map Data

These features are structurally complete but cannot resolve without sub-tile army position data from s11.7a or the province adjacency coordinate system.

| Section | What's Needed |
|---------|--------------|
| s4.3 | `is_coastal` flag — always false; requires coordinate data |
| s11.7 | Sub-tile pathfinding; FORCE_MARCH, EVALUATE_CLAN_STRENGTH, DEPLOY_ARMY sub-tile |
| s11.7a | Army movement, levy & mobilization (sub-tile movement) |
| s11.9 | Ship movement initiation; naval blockade (per-sub-tile military unit) |
| A16 | Forged letter delivery distance (3 provinces — needs adjacency data) |
| — | `rivers` and `roads` fields on ProvinceData — no consumer until map format decided |

---

### D. Areas Needing Design Decisions (Owner Authorization Required)

These sections have partial or no GDD spec. **To-be-implemented features MAY be worked on — but only with the owner's explicit, prior authorization for that specific feature.** Authorization is per-feature and per-occasion: a general "go ahead" or approval on one to-be-implemented feature does NOT extend to any other. Before starting any item below you MUST (1) state exactly what you propose to build and the design choices it requires, (2) ask the owner, and (3) receive explicit, unambiguous authorization. No authorization, no code — silence is not authorization. Once authorized, the design decisions still trace to the owner's stated intent; you may not invent mechanics, numeric values, or behavioral rules beyond what the owner authorizes (the "Do not invent mechanics" hard constraint still applies).

| Section | What's Needed |
|---------|--------------|
| s2.4 | `DECLARE_WALL_EMERGENCY` ActionID — RESOLVED (owner-authorized 2026-06-11): 1 AP; elevates the existing `shadowlands_incursion` topic + broadcasts to all Crab lords; compels every Crab daimyo (forced DEFEND_PROVINCE primary) + −1.0 Honor (s2.4.12 serious tier) for non-contributors one season later. See "Systems Added 2026-06-11 (Wall-Wide Emergency)". |
| s31 | RESOLVED — Maho Channel 3 both halves WIRED at TN = (8 − Taint Rank) × 5 (owner-set 2026-06-10): passive proximity check + active EXAMINE_FOR_TAINT corroboration. NOT a Sense cast (Sense detects kami, not kansen). |
| s38 | Kiho system — full design needed |
| s40 | Individual combat — PARTIAL. WeaponData/ArmorData Resources, NPC summary roll, weapon assignment done. Full PC-facing mechanics (all maneuvers, kata effects, grapple, sumai) blocked on design decisions. |
| s43 | Maho spell cast roll TN — not specified. Needed for CAST_MAHO NPC ActionID |
| s54.7 | Kolat system — 23 spy network ActionIDs, BRIBE_GARRISON_COMMANDER |
| s56.14 | Bloodspeaker cult ASCII map encounters — trigger layer done, encounter design needed |
| s57.40.8 | Commerce rank 5 mastery (price ±20%) — design needed |
| s57.40.9 | Appraisal skill emphasis modifier — design needed |
| s57.42–s57.43 | Sailing / Ship lesser zones — source material available, design needed |
| s57.46 | Allied NPC Companion system — source material available, design needed |
| s45 CAST_OUT | **RESOLVED.** `brotherhood_sect: String` field added to `L5RCharacterData`. `WorldGenerator.generate_character()` copies `"brotherhood_sect"` from `SCHOOL_DATA` (Togashi Tattooed Order = `""`; non-Brotherhood schools omit the key, defaulting to `""`). `HonorGlorySystem.get_observed_glory_rank(target, observer)` returns 0 when `AdvantageSystem.is_glory_treated_as_infamy_by(target, observer.brotherhood_sect)` is true. 5 tests in `test_honor_glory_system.gd`. |

---

### E. Unimplemented Due to Missing Data or Design

| Item | What's Needed |
|------|--------------|
| `techniques`, `kiho`, `katas`, `weapons`, `armor_worn` | s40 individual combat, s38 kiho design |
| `active_quest`, `active_poisons`, `combat_modifiers_pending` | s56 quest extension, s40 combat design |
| `timed_advantages` and `action_blocks` | Individual school technique implementation (per-school design) |
| SEEK_PRETEXT ActionID executor | Executor mechanics unspecified in GDD s14 |
| `eta` community weight in Bloodspeaker cell placement | No `eta` field on ProvinceData/SettlementData |
| Maho Channel 3 detection TN | RESOLVED — Lore: Shadowlands check at (8 − Taint Rank) × 5 (owner-set 2026-06-10). Not a Sense cast. |
| Animal companion ASCII combat | s40/s56 design |

**Sections available for design and implementation (source material exists, design decisions needed before coding):** s38 (kiho), s40 (individual combat — partial, further design decisions needed), s44 (Shadowlands mutations — DONE), s45 (advantages/disadvantages — DONE), s54.7 (Kolat), s57.42–s57.43 (sailing/ship zones), s57.46 (allied NPC companion).
**Note:** s31–s37 (spells — DONE), s57.23 (garden), s57.24 (bonsai), s57.26 (origami), s57.27 (painting), s57.29 (ikebana), s57.30 (calligraphy), s57.41 (engineering), s57.45 (geisha) are all **DONE**.

---

### F. Forward-Wired (No Action Needed — Documenting for Awareness)

These are flags, fields, or scored entries that exist in code but have no
consumer yet. They are NOT bugs — they are pre-wired for future systems.
No decision needed; listed here to prevent re-auditing.

- `position_hardened` / `position_durable` — emitted by NEGOTIATE/PERSUADE,
  permanently dead (B4 resolved: positions don't decay). Harmless metadata.
- 37 Kolat/artisan/theater ActionIDs in objective_alignment.json — Phase 4b
  filters them out because they have no context list entry
- Military hierarchy constituent arrays (`constituent_companies`, etc.) —
  intentionally unpopulated; linear scan is fine at current scale
- `topic_tier` values in CONSEQUENCE_TABLE — present but never consumed
  (topic creation uses commitment tier instead)

---

## What To Do When Uncertain
Stop. Read the relevant LOCKED section in /gdd/. If it does not answer the
question, say so explicitly — do not guess, do not fill gaps with plausible
logic, do not extrapolate from adjacent systems.

## Workflow — After Each Task
Whenever a task is complete (system implemented, wired, committed, pushed),
do the following in order before ending the turn:
1. **Validate twice** — re-read the actual code (not memory) and check it
   against the GDD section it implements. First pass: logic and GDD
   fidelity. Second pass: wiring completeness and edge cases (parse-check
   with `godot --headless --check-only`, trace each reachability/usage point
   by hand — do NOT write tests). State findings explicitly — what's correct,
   what's a known limitation, what would be a tuning concern.
2. **Suggest a list of next options** — present 3–4 distinct directions
   for what to build next, sized for clarity (small / medium / foundational
   / wiring follow-up). Use AskUserQuestion to let the user pick.
