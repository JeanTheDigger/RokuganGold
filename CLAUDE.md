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

**If a mechanic is not in a LOCKED section, do not implement it.**
Sections marked DEFERRED or Reference/No tags are not ready for code.
Never extrapolate from one system to another (e.g. land combat rules to naval
combat, one school's technique to another's). If the GDD is silent, stop and ask.

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
| Individual combat                             | 40 (not yet built)   |
| ASCII map mission generation                  | 56 (all subsects)    |
| Quest seeds                                   | 56.1                 |
| Spiritual insurgency                          | 56.16                |
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
| Primary objective decomposer (12 trees)       | 55.28                |
| Travel commitment and oscillation prevention  | 55.29                |
| Objective progress functions                  | 55.29.3              |
| NeedType enum reconciliation                  | 57.11                |
| ActionID naming reconciliation                | 57.12                |
| Military hierarchy                            | 57.21                |
| Governance action wiring (marriage, vacancy)  | 57.20                |
| Zone subtypes and flag matrix                 | 57.36                |
| Character sheet field index                   | 57.35                |
| Tattoo system                                 | 57.25                |
| Musha Shugyo (warrior's pilgrimage)           | 57.48                |
| Otomo Seiyaku (alliance suppression)          | 55.22b               |
| NPC advancement (XP, skill/ring progression)  | 52 Part 3, 48        |
| World population generator (game start pass)  | 52 Part 1, 22.4, 22.8|
| Gempukku / NPC spawning / natural death       | 52, 22.4, 22.7       |
| Ronin system (status transitions)             | 52 Part 5            |

## Directory Structure
```
/gdd/                              — GDD markdown files (read-only reference, never edit)
/simulation/                       — Headless simulation logic: NPC engine, resource tick,
                                     world event resolution. NO Node inheritance here.
                                     Plain GDScript classes only (class_name, no extends Node).
/shared/                           — Data models: CharacterData, ProvinceData, etc.
                                     Use Resource subclasses for serialisable data.
/tests/                            — GUT unit tests. Mirror the /simulation/ and /shared/
                                     directory structure inside /tests/.
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

## Testing (GUT)
- GUT (Godot Unit Testing) is the test framework. Tests live in /tests/.
- The dice engine must have passing GUT tests before any other system uses it.
- Every pure simulation function must be testable with no scene tree present.
- Test file naming: `test_<system_name>.gd` mirroring the source file.
- Do not couple test setup to Autoloads — pass dependencies explicitly.

## Hard Constraints — Never Violate Without Asking
- PC death is permanent. No resurrection mechanic of any kind.
- Jade counters Jigoku only. No effect on other spirit realms.
- Any maho use raises PTL whether detected or not.
- The simulation does not pause for absent players.
- NPCs never use the ASCII map unless a PC is personally present.
  NPC-only resolution goes through the dice engine, not map generation.
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

All systems are implemented, tested, and passing. Before writing any new simulation
file, search `/simulation/` and `/shared/` to confirm the system doesn't already exist.
For per-section status (DONE / PARTIAL / NOT STARTED / REFERENCE) see the
**Code Implementation Status** table at the bottom of `/gdd/00_INDEX.md`.

### What's Next
1. World generation coordinate system and adjacency (gates: sub-tile pathfinding,
   real army movement routes, naval sub-tile routing, province adjacency for map
   display, and all travel-time calculations that currently use placeholder IDs)

For per-GDD-section implementation status (DONE / PARTIAL / NOT STARTED / REFERENCE),
see the **Code Implementation Status** table at the bottom of `/gdd/00_INDEX.md`.

### Pending Redesign
(None currently pending.)

### Resolved Redesigns
- **Winter Court lifecycle — RESOLVED v624.** Full Winter Court system designed
  and written into GDD Section 55.10. Replaces the placeholder
  `_create_winter_court_from_directive()` and `_evaluate_winter_court_host()`.
  The new design covers: castle-level host selection (5 factors, per-archetype
  weight matrix, hard disqualifiers including stability floor and no-Capital
  constraint), three-phase invitation pipeline (capacity from lord rank, equal
  Great Clan delegation allocation, personal Imperial invitation pool with
  archetype-scored selection), Champion delegation selection (universal 5-factor
  scoring, yojimbo pull-in rule), Emperor's Peace (spatial hostile-tag block,
  sanctioned duel carve-out, covert actions permitted), regent substitution
  (Imperial Chancellor as caretaker if Emperor dies before selection, no edicts,
  reduced prestige), travel logistics (mid-Autumn announcement via LetterSystem,
  distance-dependent delivery, 15-day grace period), host prestige (Glory rewards)
  and tactical advantage (+5 skill bonus, agenda topic ordering by host Champion),
  WINTER_COURT_ANNOUNCED topic (Tier 3, non-positional). Crime entry added to
  Section 57.47 (CAPITAL — Violation of the Emperor's Peace). Section 15.1
  updated to reflect castle-level selection. **CODE REWRITTEN** — 
  `simulation/winter_court_system.gd` implements the full specification.
  Remaining deferred: travel logistics letter dispatching, late arrival
  handling, +5 skill bonus SkillResolver integration, Champion agenda
  ordering AI.


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

### 5. Effect Application Pattern — RESOLVED: dual pattern with naming guard
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

## What To Do When Uncertain
Stop. Read the relevant LOCKED section in /gdd/. If it does not answer the
question, say so explicitly — do not guess, do not fill gaps with plausible
logic, do not extrapolate from adjacent systems.

## Workflow — After Each Task
Whenever a task is complete (system implemented, wired, committed, pushed),
do the following in order before ending the turn:
1. **Validate twice** — re-read the actual code (not memory) and check it
   against the GDD section it implements. First pass: logic and GDD
   fidelity. Second pass: tests against implementation, edge cases. State
   findings explicitly — what's correct, what's a known limitation, what
   would be a tuning concern.
2. **Suggest a list of next options** — present 3–4 distinct directions
   for what to build next, sized for clarity (small / medium / foundational
   / wiring follow-up). Use AskUserQuestion to let the user pick.
