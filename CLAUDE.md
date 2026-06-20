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

All systems are implemented, tested, and passing. Before writing any new simulation
file, search `/simulation/` and `/shared/` to confirm the system doesn't already exist.
For per-section status (DONE / PARTIAL / NOT STARTED / REFERENCE) see the
**Code Implementation Status** table at the bottom of `/gdd/00_INDEX.md`.

### Known Code Issues (found and fixed 2026-05-18)
- **DayOrchestrator._decay_civil_war_scars() — inverted filter. FIXED.**
  Was `if base_remaining < 0: remaining.append(entry)` — kept only negative
  (over-decayed) entries and purged all active scars every season. Changed to
  `> 0`. All civil war scars were being silently discarded.
- **DayOrchestrator._decay_all_historical_modifiers() — sentinel default. FIXED.**
  `created_ic_day` fallback was `0` (valid IC day), causing silent over-decay
  for any modifier dict missing the key. Changed to `-1` with guard.
- **HuntSystem.resolve_hunt() — missing CASUALTY_DOWN_MIN tier. FIXED.**
  GDD s57.38 specifies three casualty tiers: Hurt (1–14), Down (15–29),
  Killed (30+). Code only had two (wound/kill), `CASUALTY_DOWN_MIN` was
  declared but never used. Now wired with `casualty_level` in result dict.
- **ActionExecutor._execute_conduct_storm_assault() — type mismatch. FIXED.**
  `settlement_id: int` had `character.physical_location` (String) as fallback.
  Changed to `-1` sentinel.
- **ActionExecutor wall sortie SS sentinel — valid zero treated as unset. FIXED.**
  SS=0 is a valid game state but was being overwritten by WallStatus value.
  Changed sentinel from `0` to `-1`, comparison from `== 0` to `< 0`.
- **NPCDecisionEngine favor deadline — day 0 excluded. FIXED.**
  `deadline > 0` skipped favors due on IC day 0. Changed to `>= 0`.
- **Sentinel defaults (5 shared data fields) — 0 → -1. FIXED.**
  `crime_record.ic_day_committed`, `topic_data.ic_day_created`,
  `letter_data.ic_day_sent`, `letter_data.ic_day_arrival`,
  `insurgency_data.season_spawned`. All always set on creation; defaults
  made consistent with design decision #2.
- **SeductionSystem.check_maintenance_state() — fallback sentinel. FIXED.**
  `last_maintained_ic_day` fallback was `0`; changed to `-1`.
- **LABOR_HALT_BLOCKED_ACTIONS — phantom ActionIDs. FIXED.**
  `COMMISSION_CONSTRUCTION` and `COMMISSION_REPAIR` were non-existent
  ActionIDs. Replaced with actual construction ActionIDs (FOUND_VILLAGE,
  BUILD_FORTIFICATION, BUILD_SHRINE, FOUND_TEMPLE, FOUND_MONASTERY,
  COMMISSION_SHIP). `LEVY_TROOPS` renamed to `ORDER_LEVY`. Labor halt
  blocking now functional.
- **HOSTILE_ACTIONS — DAMAGE_RELATIONSHIP miscategorized. FIXED.**
  `DAMAGE_RELATIONSHIP` is a NeedType (appears as outer key in
  objective_alignment.json), not an ActionID. Removed from HOSTILE_ACTIONS.
- **COMMANDER_RANK_ACTIONS — LEVY_TROOPS naming mismatch. FIXED.**
  Was `LEVY_TROOPS` (NeedType name); changed to `ORDER_LEVY` (ActionID).
- **NPCWaveResolver._is_order_action() — wrong ActionID names. FIXED.**
  Used placeholder names (ADJUST_TAX, BUILD_INFRASTRUCTURE, DEPLOY_ARMY,
  TRAIN_TROOPS, ASSIGN_OBJECTIVE, FILL_VACANCY) that matched no real
  ActionIDs. Replaced with delegation to CivilianOrderBudget constants.
- **JSON scoring tables — secret action name mismatches. FIXED.**
  `EXPOSE_SECRET_PUBLIC` → `EXPOSE_SECRET_PUBLICLY` and
  `REVEAL_SECRET_PRIVATE` → `EXPOSE_SECRET_PRIVATELY` in
  action_skill_map.json and objective_alignment.json.
- **Civilian/military order context list wiring. FIXED.**
  11 lord order actions were unreachable because they weren't in any
  `_get_actions_for_context()` list. Added per GDD s57.34: AT_OWN_HOLDINGS
  gets all 10 governance/military actions + SEND_INVITATION. AT_COURT gets
  policy-from-anywhere actions (SET_TAX_RATE, SET_STIPEND_RATE) plus
  REQUEST_ART, ASSIGN_VASSAL_OBJECTIVE, SEND_INVITATION. VISITING gets
  policy-only (SET_TAX_RATE, SET_STIPEND_RATE). ON_CAMPAIGN gets field
  military orders (ORDER_DEPLOY, ORDER_FORTIFY, ORDER_RETREAT,
  ASSIGN_GARRISON). Military/civilian overlap actions added to
  MILITARY_ORDER_ACTIONS for proper non-lord/non-military filtering with
  lord carve-out via CivilianOrderBudget.MILITARY_OR_CIVILIAN_ACTIONS.
- **ActionExecutor._validate_military_order() — lord carve-out missing. FIXED.**
  Lords without military rank issuing MILITARY_OR_CIVILIAN or PURE_ORDER
  actions (ASSIGN_GARRISON, ORDER_LEVY, ASSIGN_TO_MILITARY_SERVICE, etc.)
  via civilian orders were blocked by the `commanded_unit_id < 0` check.
  Added bypass for lords issuing civilian-classified orders per s57.34.4.
- **NPCWaveResolver._resolve_civilian_order() — dual-cost AP not deducted. FIXED.**
  SEND_INVITATION costs 1 AP + 1 Civilian Order (s57.34.7). The civilian
  order path hardcoded `ap_spent: 0` for all actions. Now deducts 1 AP for
  DUAL_COST_ACTIONS and skips dual-cost actions when AP is 0.

### Systems Added 2026-05-18 (continued)
- **ASSIGN_VASSAL_OBJECTIVE executor** — Deferred effect handler in
  DayOrchestrator. Validates lord-vassal relationship, writes new primary
  objective to objectives_map. Skill-gated: Courtier vs TN 10.
- **SEND_INVITATION executor** — Deferred effect handler in DayOrchestrator.
  Finds matching court session (by settlement, fallback to any court hosted
  by inviter). Appends invitee to personal_invitation_ids. Duplicate-safe.
  +5 recipient disposition. Skill-gated: Calligraphy vs TN 10.
- **CALL_COURT executor** — Deferred effect handler in DayOrchestrator.
  Creates CourtSessionData via CourtSystem.create_court(). Determines court
  type from lord status (CLAN_CHAMPION_COURT at 7.0+). Validates no active
  duplicate. Selects agenda topics, adds lord as attendee. +0.1 glory.
  Added to AT_OWN_HOLDINGS context list and LORD_ONLY_ACTIONS. 1 AP cost.
- **s12.8 Honor Threshold Filter (Filter 2)** — Covert action scoring penalty
  based on Honor rank. Three tiers: Honor < 2.0 → no penalty, 2.0–3.5 → -25,
  >3.5 → -50. School exemptions: full exempt (Shosuro Infiltrator, Bitter Lies,
  Kasuga Smuggler → penalty 0), half exempt (Daidoji Harrier, Daidoji Spymaster,
  Ikoma Lion's Shadow → penalty halved), Scorpion clan → penalty halved. Wired
  into `score_all()` as `honor_covert_penalty` on ScoredAction.
- **s12.8 Virtue Profile Conditional Modifiers (Filter 3)** — Three virtues
  get conditional scoring modifiers beyond flat personality_lean: Meiyo
  (-15 default, +15 if existential threat), Chugi (-25 default, +10 if
  lord-assigned objective), Yu (-15 default, +10 if existential threat).
  Existential threat check: active wars, starvation provinces, besieged
  settlements. Wired as `virtue_covert_modifier` on ScoredAction.
- **Dosatsu/Chishiki personality_lean gather-deploy split** — Refined
  personality_lean.json entries to make information gathering vs covert
  deployment differential more pronounced. Dosatsu: gathering +12 (was +10),
  deployment +2-5 (was +5-8), COMMISSION_ASSASSINATION 3 (was 8). Chishiki:
  acquisition +10-12 (was +8), deployment 0-3 (was 3-5), FABRICATE_SECRET 0
  (was 3), COMMISSION_ASSASSINATION 0 (was 3).
- **s12.8 Suspicion Decay and 14-Tick Baseline** — Wired suspicion decay into
  `_process_assassination_daily_tick()` with co-location check. Absent decay
  -1.0/tick, present-inactive decay -0.5/tick. 14-tick minimum before any
  settlement returns to baseline (clamps to 0.5 within window). Added
  `suspicion_raised_ic_day` tracking to state factory (sentinel -1).
- **s12.8 Non-Shinobi TN Increase** — Characters without Shosuro Infiltrator
  or Shosuro Actor school backgrounds get +10 TN on all Phase 1 (Access)
  rolls. Value PROVISIONAL — GDD specifies "severe disadvantage" without a
  numeric value. Checks both primary school and school_paths for multi-school
  characters. 10 tests.
- **s12.8 Imperial Assassination TNs (Seppun Protection)** — Seppun guards
  modify all three assassination phases. Full protection (co-located Seppun):
  +15/+20/+10 (Access/Execution/Concealment). Half protection (Imperial
  dynasty target, no co-located Seppun): +8/+10/+5. Stacks with other TN
  modifiers. 15 tests.
- **s12.8 Equipment Preparation Gate** — Pre-Phase 1 CONCEAL_ITEM check.
  Assassins must conceal tools before entering the settlement. Poison TN 10,
  blade TN 20. Blade method hard-gated at Sleight of Hand Rank 5. Arranged
  accident skips equipment entirely. School lean (+1k0) for Shosuro
  Infiltrator and Kasuga Smuggler. Result stored as `equipment_concealment_tn`
  on assassination state. 11 tests.
- **s12.8 CONCEAL_ITEM Auto-Bypass** — NPCs carrying contraband automatically
  fire CONCEAL_ITEM when arriving at a settlement. Fires in DayOrchestrator
  after travel arrivals. Uses SecretSystem.resolve_conceal_item() directly.
  Skips already-concealed items and respects blade Rank 5 gate. 4 tests.
- **s12.8 Household Response Thresholds** — Four-tier suspicion response:
  0-9 none, 10-19 watchful (+5 Investigation bonus), 20-29 bodyguard
  assigned, 30+ lockdown (+10 TN to access). Previous gradual curve (5/10/15)
  replaced with binary lockdown-only modifier per GDD. Threshold constants:
  WATCHFUL=10, BODYGUARD=20, LOCKDOWN=30. 6 tests.
- **s12.8 SEARCH_PERSON Suspicion Trigger** — At bodyguard threshold (20+),
  household security fires SEARCH_PERSON against assassin's concealed
  equipment. `find_best_searcher()` selects highest Investigation+Perception
  co-located character (excludes assassin/target). `resolve_suspicion_search()`
  rolls Investigation/Perception vs equipment_concealment_tn. Auto-finds if
  concealment_tn <= 0. On discovery: operation immediately fails. Wired in
  DayOrchestrator ACCESS phase after access roll. 6 tests.
- **s12.8 Per-Roll Permanent TN Penalty** — Each failed Phase 1 access roll
  permanently increases TNs for subsequent rolls in the same operation. Two
  parallel tracks: settlement suspicion (decays) and access_tn_penalty
  (permanent, only resets on abort). Values PROVISIONAL (+5/+10/+15 matching
  suspicion scale). Stacks with lockdown +10 and all other modifiers. Also
  fixed get_suspicion_from_failure thresholds to match GDD (notable at -10,
  critical at -20; was -5/-10). 10 tests.
- **s12.8 Critical Failure Detection Check** — When Phase 1 access roll
  misses TN by 20+, immediate detection check fires from nearest household
  member (reuses find_best_searcher). Detection TN is the assassin's roll
  total (PROVISIONAL). Cascades with SEARCH_PERSON in orchestrator flow:
  critical failure → detection check → equipment search → advance check.
  Includes household investigation bonus at watchful suspicion. 4 tests.
- **s12.8 Honor/Infamy Consequences** — Ordering costs -2.0 to -5.0 Honor
  scaled by target Status (4 tiers per GDD), applied at commission time
  (Pattern B). Execution costs -0.5 Scorpion / -3.0 other clans
  (PROVISIONAL). Pre-applied on Phase 2 success. Betrayal Tier 2 topic
  deferred to investigation pipeline (requires tracing through CrimeRecord
  to commissioner). 8 tests.
- **s12.8 Concealment Outcome Tiers** — Phase 3 now returns full/partial/
  failure based on margin. Full: death_natural tier 4. Partial (missed <10):
  death_suspicious tier 3, preserves investigator TN. Failure (missed 10+):
  death_murder tier 2, CrimeRecord. Partial threshold PROVISIONAL. 5 tests.
- **s12.8 Bodyguard NPC Decision Logic** — Personality-driven bodyguard
  response: Seigyo aborts, Ketsui/Yu push through, lockdown forces abort.
  Competence fallback: combat 4+ fights, stealth 5+ goes for target. Moved
  to AssassinationSystem.evaluate_bodyguard_response(). 7 tests.
- **s12.8 Phase 1 Daily Detection Signals** — Household members roll
  Investigation/Perception vs assassin's access roll total each day during
  ACCESS. On success: +3 suspicion (PROVISIONAL). Passive observation that
  builds cumulative risk. 4 tests.
- **s12.8 SEDUCE_FOR_ACCESS Bypass** — Active SEDUCE_FOR_ACCESS entanglement
  at target's location auto-succeeds Phase 1 access rolls. Added variant
  field to SeductionSystem.create_entanglement(). Checks seducer, variant,
  state, and location. Revokes on entanglement break. 5 tests.
- **s12.8 Access Method Selection** — Trait-weighted scoring for NPC access
  method choice. `pick_best_access_method()` scores each method by (skill_rank
  + associated_trait) where trait maps are: bribe→Awareness, stealth→Agility,
  disguise→Intelligence, service→Awareness. Ties broken by method priority
  order. Orchestrator delegates via `_pick_access_method()`. 4 tests.
- **s12.8 PC Crisis Event Generation** — `create_pc_crisis_event()` produces
  a structured event dict for player-facing assassination encounters. Method-
  specific grace periods: blade 1 round, poison 1 IC day, accident 4 hours.
  Includes deadline, phase, method, location. Orchestrator wiring deferred
  until player identification system exists (no `is_pc` field yet). 3 tests.
- **s12.8 Bodyguard/Yojimbo Detection Wiring** — `_target_has_bodyguard()`
  and `_find_bodyguard()` now functional in DayOrchestrator. Scans co-located
  characters for `assigned_protection_target_id` matching target. Picks best
  by max(Kenjutsu, Iaijutsu). Added `assigned_protection_target_id: int = -1`
  to L5RCharacterData. `_npc_bodyguard_decision()` delegates to
  AssassinationSystem.evaluate_bodyguard_response(). 3 tests (bodyguard
  decision suite covers this).
- **s12.8 Abort and Restart Mechanics** — `abort_operation()` terminates
  assassination cleanly (state→"aborted"). `restart_access()` resets
  access_tn_penalty, access_days, equipment state but preserves settlement
  suspicion (household memory persists). Enables strategic retreat when
  penalty accumulates too high. 3 tests.
- **s12.8 Entanglement Creation Wiring** — Successful seduction actions
  (SEDUCE, SEDUCE_FOR_INFO, SEDUCE_FOR_ACCESS, SEDUCE_FOR_LEVERAGE,
  SEDUCE_TO_COMPROMISE) now create entanglement dicts via
  `_process_seduction_entanglements()` in DayOrchestrator. Scans day results
  for `creates_entanglement: true`, prevents duplicates (skips if active
  entanglement exists between same pair), allows re-seduction after broken
  entanglement. Variant passed through from action_id. 5 tests.
- **s12.8 Target Status TN Modifier** — Phase 1 access TNs now include
  `int(target.status)` as a direct TN adder per GDD s12.8 ("target's Status
  (higher Status = higher base TN)"). Formula PROVISIONAL — GDD specifies
  the factor without a numeric formula. `ACCESS_SEDUCTION_TN` constant
  replaces hardcoded 15. 4 tests.
- **s12.8 Loyalty-Gated Daily Detection** — `find_best_searcher()` gains
  optional `require_loyalty: bool = false` parameter. When true, filters
  to household members (same lord, direct vassal, assigned bodyguard) with
  non-negative disposition toward target. Daily detection uses loyalty gate;
  SEARCH_PERSON and critical failure detection do not (active security
  responses vs passive observation). `_is_household_member()` helper and
  `LOYALTY_DISPOSITION_MINIMUM = 0` constant. 11 tests.
- **s12.8 Vengeance Consequences** — `apply_vengeance_consequences()` fires
  when commissioner is traced through investigation pipeline. -50 permanent
  historical disposition from all victim's biological family (mother, father,
  siblings, children, spouse) toward commissioner. Designated heir gets
  AVENGE_DEATH crisis-override primary objective targeting commissioner;
  falls back to eldest living child if no heir designated. If victim survived,
  victim gets the objective directly. Pure function — called from investigation
  pipeline when tracing completes. 8 tests.
- **s12.8 PvP Blade Edge Case** — `can_pvp_blade_resolve_via_engine()` checks
  blade-method + EXECUTION phase. `pvp_blade_wait_tick()` tracks wait days
  and applies present-inactive suspicion decay. Player assassin can choose
  engine resolution (NPC quality, forfeits ASCII map advantage) or wait
  (accumulates suspicion, daily detection fires against them). Orchestrator
  wiring deferred until player identification system exists. 4 tests.
- **s12.8 Betrayal Topic on Trace** — `apply_vengeance_consequences()` now
  accepts optional `active_topics`, `next_topic_id`, `ic_day` params and
  generates a Betrayal Tier 2 topic (category: POLITICAL) about the
  commissioning lord when tracing completes. Subject role NEUTRAL per
  dead-character rule. Backward compatible (optional params). 3 tests.
- **s12.8 Non-Shinobi Detection Severity** — `resolve_daily_detection()`
  gains optional `assassin` param. Non-shinobi assassins give observers
  +5 Investigation bonus (`NON_SHINOBI_DETECTION_BONUS`, PROVISIONAL).
  Wired in orchestrator daily detection call. Stacks with household
  watchful bonus. 3 tests.
- **s12.8 Vengeance Conviction Pipeline Wiring** — `_apply_assassination_vengeance()`
  in DayOrchestrator fires post-conviction for `UNSANCTIONED_COVERT_KILLING`
  crimes with `commissioner_id >= 0`. Delegates to
  `AssassinationSystem.apply_vengeance_consequences()` for -50 family
  disposition, AVENGE_DEATH objective, and Betrayal Tier 2 topic.
  `CrimeRecord.commissioner_id` field added to propagate from assassination
  op state through concealment failure to investigation pipeline.
  Honor public/private: handled via existing topic flow — commissioner
  honor loss at commission time (private), betrayal topic at tracing
  (public). 4 tests.

### Known Code Issues (found and fixed 2026-05-19)
- **Letter delivery not wiring topics_by_id into process_pending_letters. FIXED.**
  `process_pending_letters()` call in advance_day omitted the `topics_by_id`
  parameter (defaulted to `{}`). `_refresh_topic_momentum()` inside
  `deliver_letter()` always received an empty dict and returned early. Tier 4
  topics carried by letters never got `discussion_count_this_day` incremented,
  so `decay_tier4_topic()` never applied the discussion-hold boost. Letters
  were invisible to the topic momentum system. Built `letter_topics_by_id`
  from `active_topics` and passed it through. 2 tests.
- **DayOrchestrator._apply_assassination_outcome() — CrimeRecord bugs. FIXED.**
  Three bugs: (1) `crime_type = "murder"` (string) should be
  `Enums.CrimeType.UNSANCTIONED_COVERT_KILLING` (enum). (2) Assigned
  nonexistent field `discovered` — changed to `legal_status =
  Enums.LegalStatus.UNDER_INVESTIGATION`. (3) Assigned nonexistent field
  `province_id: int` — changed to `location: String`. Also added
  `severity = Enums.CrimeSeverity.CAPITAL` and fixed topic tier to use
  `TopicData.Tier` enum instead of raw int.
- **Position resistance not applied to court action position shifts. FIXED.**
  `TopicMomentumSystem.calculate_position_resistance()` existed but was never
  called. Court actions (Negotiate, Persuade, etc.) applied raw position shifts
  to targets regardless of their personal relevance. High-relevance characters
  (whose lands are burning) were just as easy to move as disinterested observers.
  Now applied in `_process_court_action_effects()` for both targeted actions and
  per-witness debate shifts. Formula: `shift / (1 + relevance/100)`.
- **Court session state not tracked between actions. FIXED.**
  Court actions return session state flags (session_tn_reduction,
  persuade_negotiate_tn_reduction, charm count) but no session-level state
  persisted between actions. Added `session_state: Dictionary` to
  CourtSessionData with per-character tracking of charm_count,
  negotiate_count, tn_reductions, persuade_tn_reductions. Wired accumulation
  in orchestrator for Charm, Negotiate, Impress, Listen/Reflect actions.
  Failed actions not tracked.
- **Proxy mandate data model missing. FIXED.**
  GDD s16.2 specifies ProxyMandate with mandate_topic, decision_authority,
  depth_limit, out_of_mandate_flag. Created `shared/proxy_mandate_data.gd`
  (ProxyMandateData Resource). Added `proxy_mandates: Array[ProxyMandateData]`
  to CourtSessionData. CourtSystem gains assign_proxy_mandate(),
  get_proxy_mandate(), is_within_mandate(), flag_out_of_mandate().
- **NPC engine court session state not wired into decision pipeline. FIXED.**
  Court session counts (charm_count, negotiate_count) and settlement ID
  were not flowing from CourtSessionData through world_state into NPC engine
  context. `_set_court_context_flags()` now writes `court_session_state` and
  `court_settlement_id`. `build_context()` reads them into ContextSnapshot.
  `_populate_action_metadata()` populates session counts, `has_topic`, and
  `court_settlement_id` for all 6 contested court actions (was only topic_id
  for 3). Position resistance now computes target relevance inline from
  TopicData/character clan instead of reading unset metadata values.
- **s55.6 information transfer not wired into vassal objective assignment. FIXED.**
  `InformationSystem.transfer_objective_knowledge()` existed but was never
  called when lords assigned objectives to vassals via ASSIGN_VASSAL_OBJECTIVE.
  Now fires in `_apply_vassal_objective_assignment()`. Target fields
  (province_id, clan, npc_id) flow from ScoredAction through executor effects
  into the objective record and knowledge transfer.
- **Public knowledge broadcasts missing knowledge entries (s55.12). FIXED.**
  `broadcast_public_knowledge()` added topics to `topic_pool` but never
  created `knowledge_pool` entries. Public knowledge is one of the five
  GDD-specified sources but had no FRESH confidence entry, breaking NPC
  confidence scoring for publicly learned information. Now creates
  PUBLIC_KNOWLEDGE entries with FRESH confidence per season.
- **met_characters direct mutation bypassing add_contact(). FIXED.**
  Two places in DayOrchestrator (WindDown met_character_ids processing and
  travel arrival observation) mutated `met_characters` directly instead of
  routing through `InformationSystem.add_contact()`. This skipped
  `known_contacts_by_clan` updates, breaking the contact discovery system
  (s55.7). Both now route through `add_contact()`.
- **Military promotion results not written back to character data. FIXED.**
  `_process_military_promotions()` selected best candidates for vacant
  command positions but only returned metadata — `character.military_rank`,
  `character.commanded_unit_id`, and `company["commander_id"]` were never
  updated. Added `_apply_promotion_results()` to apply promotions after
  seasonal military processing.
- **TravelCommitment.increment_redirects() never called. FIXED.**
  CHANGE_DESTINATION action executor returned results but never incremented
  the objective's `travel_redirects` counter. The redirect penalty existed
  in Phase 5 scoring (get_redirect_penalty wired at NPC engine line 447)
  but never accumulated because increment_redirects was never called.
  Added `_process_travel_redirect_writebacks()` to scan wave results for
  successful CHANGE_DESTINATION actions and increment the primary objective's
  redirect counter.
- **ApproachEvaluation.evaluate_approach() / record_penalty() never called. FIXED.**
  The measurement bonus (+15 for READ_CHARACTER/PROBE) was correctly wired
  into Phase 5 scoring, but after measurement actions fired, the approach
  evaluation step was missing. NPCs would get the bonus to measure but
  the measurement result was never assessed. Added
  `_process_approach_evaluation_writebacks()` to detect successful
  READ_CHARACTER/PROBE results, check which social/covert actions triggered
  measurement_needed, evaluate the approach (CAPPED or INEFFECTIVE), and
  record penalties. LIMITATION: disposition_at_start tracking not yet
  implemented — approach effective/ineffective distinction uses current
  disposition for both, which conservatively classifies sub-tier progress
  as INEFFECTIVE. APPROACH_CAPPED detection works correctly.
- **CommitmentRegistry.link_crisis() never called. FIXED.**
  When a crisis override fired and an NPC executed crisis actions
  (ORDER_DEPLOY, etc.) while holding PENDING commitments, the commitments
  were never stamped with crisis_id. This meant all broken commitments
  resolved as BROKEN_NO_NOTICE instead of BROKEN_FORCE_MAJEURE, causing
  full consequence cascades for legitimate crisis responses. Added
  `_process_crisis_commitment_linking()` to detect crisis actions where
  the NPC's primary objective carries a crisis_id, and stamp all their
  PENDING commitments accordingly.
- **Commitment fulfillment checker always returned false. FIXED.**
  `_process_commitment_deadlines()` passed a dummy callable
  `func(_c) -> bool: return false` as the fulfillment checker, meaning
  no commitment could ever be fulfilled — all would break at deadline.
  Replaced with `_check_commitment_fulfilled()` which evaluates actual
  fulfillment conditions by commitment type: COURT_ATTENDANCE checks
  debtor present at target settlement. VISIT_PROMISE checks co-location
  with creditor (neither traveling). MEETING_ARRANGEMENT checks both
  parties present at target (neither traveling).
  FAVOR_OBLIGATION delegates to s12.10 (always returns false here).
- **FAVOR_OBLIGATION commitment creation wired. ADDED.**
  `_process_commitment_creation_writebacks()` scans day results for
  `requires_favor_creation` and creates FAVOR_OBLIGATION CommitmentData
  alongside the FavorData. Witnesses: court attendees if at court,
  creditor+debtor only if private. Duplicate-safe. Added
  `next_commitment_id: Array[int]` parameter to advance_day.
- **FAVOR_OBLIGATION skipped in deadline and at-risk processing. FIXED.**
  `process_deadlines()` and `get_at_risk_penalty()` now skip
  FAVOR_OBLIGATION entries per GDD s55.31.2: "visibility only, consequences
  delegated to Section 12.10." Without skip, FAVOR_OBLIGATION with
  deadline_ic_day=-1 would immediately trigger BROKEN status on first tick.
  8 tests.

### Known Code Issues — Deferred (2026-05-19)
- **CommitmentRegistry.create_commitment() — 5 of 6 types wired. FIXED (partial).**
  FAVOR_OBLIGATION wired (created alongside FavorData on OFFER_FAVOR).
  COURT_ATTENDANCE wired (created on SEND_INVITATION success and Winter
  Court invitation pipeline). Tier 2 for Winter/Champion courts, Tier 3
  for provincial. Winter Court skips emperor and host. 9 tests.
  VISIT_PROMISE wired (LetterData gains visit_intent + visit_deadline_ic_day;
  handler fires on delivered letters with intent set). NPC engine trigger
  wired: `_should_set_visit_intent()` checks AT_OWN_HOLDINGS context,
  visit-eligible need_type (RAISE_DISPOSITION, SECURE_ALLIANCE, etc.),
  and matching objective target. 90-day deadline PROVISIONAL. 9 tests.
  MEETING_ARRANGEMENT wired (LetterData gains meeting_proposal +
  meeting_settlement_id + meeting_deadline_ic_day; handler fires on matching
  bilateral proposals at same settlement). NPC engine trigger wired:
  `_should_set_meeting_proposal()` checks AT_OWN_HOLDINGS, bilateral
  need_types (SECURE_ALLIANCE, ARRANGE_MARRIAGE), matching target. Reply
  generation propagates proposal when disposition >= 0 (PROVISIONAL).
  90-day deadline PROVISIONAL. 9 tests.
  SUPPORT_PLEDGE wired (PERSUADE/NEGOTIATE with target_position_shift at
  court creates Tier 2 pledge. Fulfillment: debtor present + ≥1 court
  action. Witnesses = court attendees. Deadline = court end date). 5 tests.
  RESOURCE_PROMISE wired (REQUEST_ALLIED_AID executor routes to
  disposition-gated acceptance at threshold 31 PROVISIONAL. Creates
  RESOURCE_PROMISE commitment with 90-day deadline PROVISIONAL, witnesses
  = two lords + direct vassals, default Tier 2. Fulfillment: writeback pass
  cross-references successful supply_sharing_results with SHARE_SUPPLIES
  action targets to mark matching commitments FULFILLED before deadline
  processing. ORDER_DEPLOY also fulfills when target_npc_id matches
  creditor (troop deployment). Koku payment fulfillment blocked on
  ActionID design — no dedicated koku transfer action exists). 16 tests.
- **CommitmentRegistry.apply_forgiveness() — retroactive forgiveness wired. FIXED.**
  `_process_retroactive_forgiveness()` batch scans BROKEN_FORCE_MAJEURE
  commitments after deadline processing. Bridges crisis topics to
  commitments via `crisis_id` field added to TopicData. Checks if
  penalized NPCs know matching crisis topics in their topic_pool.
  Same-clan loyalty chain gives Chugi 75% rate vs 25% cross-clan.
  Crisis topic generation tagged: Shadowlands incursion, famine (single
  + multi), and _topic_from_dict all set crisis_id from
  ProvinceData.active_crisis_id. 9 tests.
- **ProvinceData.active_crisis_id population — crisis lifecycle wired. FIXED.**
  `active_crisis_id` now assigned from `next_crisis_id` counter on three
  crisis triggers: famine onset (starvation HUNGER+), Shadowlands breach
  (SI=0 + DEFENDER_OVERRUN), insurgency spawn (new InsurgencyData). Cleared
  on resolution: famine after 10-season recovery, insurgency when strength
  reaches 0. Existing crisis_id not overwritten by new events. Activates
  the full crisis→commitment→forgiveness pipeline. 7 tests.
- **Approach evaluation disposition_at_start tracking. FIXED.**
  `_populate_disposition_snapshots()` captures all disposition pairs at
  season start. `_process_approach_evaluation_writebacks()` looks up
  snapshot value as `disposition_at_start`, making EFFECTIVE branch
  reachable. Persisted in WorldStateData between advance_day calls.
  5 tests.
- **Koku deduction for BRIBE_FOR_INFO and PURCHASE_MARKET. FIXED.**
  EffectApplicator._apply_koku_cost() handles "koku_cost" effect key.
  ActionExecutor emits koku_cost=5.0 on non-blocked bribes (including
  refused — koku spent on attempt) and koku_cost=3.0 on PURCHASE_MARKET.
  Blocked-by-personality bribes emit no koku_cost (never attempted).
  9 tests.
- **Phase 7 resource validation. FIXED.**
  ResourceAvailability.can_afford() validates resources before executing.
  NPCDecisionEngine.execute_action() checks after AP/civilian order
  spending, refunds both on failure (insufficient_resources). 11 tests.

### Known Code Issues (found and fixed 2026-05-19, commitment audit)
- **MEETING_ARRANGEMENT — only one commitment created per pair. FIXED.**
  GDD s55.31 specifies "both parties are simultaneously debtor and creditor."
  Code created only one commitment (sender=debtor). Creditor faced no
  consequences for not attending. Now creates two commitments with swapped
  debtor/creditor roles. Dedup checks per-direction. 2 tests updated.
- **VISIT_PROMISE fulfillment — always failed (fulfillment_target=-1). FIXED.**
  `target_settlement = -1` in creation, `str(-1)` never matched any
  physical_location. Changed fulfillment to co-location check: debtor at
  creditor's physical_location, both non-empty, neither traveling. No longer
  depends on fulfillment_target. 3 new tests.
- **MEETING_ARRANGEMENT fulfillment — creditor travel not checked. FIXED.**
  Creditor could be traveling through the settlement and still count as
  present. Added `not TravelSystem.is_traveling(meeting_creditor)` check.
  1 new test.

### Known Code Issues — Deferred (commitment audit 2026-05-19)
- **send_advance_notice() — wired. FIXED.** Daily pass detects unfulfillable
  PENDING commitments within 7-day window. Checks travel time for location-
  based commitments. Personality-driven: Rei/Gi/Meiyo send, Yu/Kyoryoku
  skip. Sends apology letter at 0 AP. 7 tests.
- **register_proxy() — wired. FIXED.** Lords with unfulfillable commitments
  dispatch closest reachable vassal as proxy. Assigns primary objective to
  vassal with target settlement. Daily arrival pass marks proxy_sent when
  vassal reaches the target. SUPPORT_PLEDGE excluded. proxy_npc_id field
  added to CommitmentData for arrival tracking. 6 tests.
- **SUPPORT_PLEDGE fulfillment — fully wired. FIXED.**
  Now checks persuade_count + public_debate_count + negotiate_count (was
  charm_count + negotiate_count). CHARM alone no longer fulfills. Added
  persuade_count and public_debate_count to court session_state tracking.
  Position alignment checking added: CommitmentData gains pledge_topic_id
  and pledge_position_shift. Fulfillment verifies debtor's current topic
  position aligns with pledged direction. Backward compatible (topic_id=-1
  skips check). 5 tests.
- **Commitment-aware decomposition — ATTEND_COURT NeedType fix. FIXED.**
  `COMMITMENT_FULFILLING_ACTIONS` had `ATTEND_COURT` (a NeedType, never
  used as an action_id). Any action at a committed settlement now receives
  the fulfillment bonus per s55.31 line 127: CHARM, PERSUADE, NEGOTIATE
  etc. at the committed court get the commitment_at_risk bonus. 4 tests.
- **RESOURCE_PROMISE creation — all three paths wired. FIXED.**
  Now created via REQUEST_ALLIED_AID (original), NEGOTIATE with resource
  need_types (ACQUIRE_RESOURCE, REQUEST_AID, CONDUCT_COMMERCE), and
  ASSIGN_VASSAL_OBJECTIVE with resource need_types. Tier scaling by
  quantity: <10 koku/<5 PU = T3, 10-50/5-20 = T2, >50/>20 = T1.
  source_action_id flows from executor into commitment. 13 tests.

### Known Code Issues (found 2026-05-18, pre-existing)
- **test_assassination_system.gd test_doji_courtier_bribe_access_gets_free_raise
  — wrong method name. FIXED.** Called `create_state()` instead of
  `create_assassination_state()` and was missing the `current_ic_day` parameter.

### Known Code Issues — Deferred (require design input)
- **NPCDecisionEngine HOSTILE_ACTIONS — phantom ASSASSINATE entry. FIXED.**
  `ASSASSINATE` was a phantom ActionID in HOSTILE_ACTIONS — no executor, no
  context list, no objective_alignment mapping. Assassination is initiated via
  `COMMISSION_ASSASSINATION` (which IS fully wired: context lists, executor,
  objective_alignment, personality_filter). The multi-day assassination process
  (ACCESS → EXECUTION → CONCEALMENT) runs via daily tick in DayOrchestrator.
  Removed phantom entry. All 11 covert actions (SHADOW_TARGET, SEARCH_PERSON,
  CONCEAL_ITEM, FABRICATE_SECRET, EXPOSE_SECRET_PRIVATELY/PUBLICLY, 5 SEDUCE
  variants, COMMISSION_ASSASSINATION) are reachable: context lists
  (AT_OWN_HOLDINGS, AT_COURT, VISITING), objective_alignment mappings,
  executor handlers, personality_filter blocks, honor/virtue scoring.
- **SkillResolver from_the_ashes expiry gap. FIXED.**
  Buff applied even if `expires_ic_day` had passed but daily cleanup hadn't
  run yet. Added optional `ic_day: int = -1` parameter to
  `_get_ashes_bonus_for_skill()`, `resolve_skill_check()`, and
  `resolve_contested_check()`. When ic_day >= 0 and buff is expired, clears
  buff and returns 0. Backward compatible (default -1 skips check). 6 tests.

### Known Code Issues (found and fixed 2026-05-19, scoring audit)
- **PURCHASE_MARKET missing from all context lists. FIXED.**
  Had full executor, resource cost (3 koku), commerce stigma handling,
  feasibility ledger rung, and objective_alignment entries in 11 NeedTypes
  (up to score 90 in ACQUIRE_RESOURCE), but was unreachable because it
  wasn't in any `_get_actions_for_context()` list. Added to AT_OWN_HOLDINGS,
  AT_COURT, VISITING per GDD s57.34 (Category 9, 1 AP) and s57.40
  ("any context"). Explicit AP cost entry added.
- **CONDUCT_COMMERCE missing from all context lists. FIXED.**
  Same pattern as PURCHASE_MARKET — had executor, AP cost, commerce stigma
  handling, but wasn't in any context list. Added to AT_OWN_HOLDINGS,
  AT_COURT, VISITING per GDD s57.34 (Category 9, 1 AP).
- **EXAMINE_CRIME_SCENE missing from all context lists. FIXED.**
  Had executor, metadata population (active_case), and objective_alignment
  entry in INVESTIGATE_THREAT (score 90), but was unreachable. GDD s14
  specifies "AT_CRIME_SCENE context" — interpreted as AT_OWN_HOLDINGS
  and VISITING (magistrate investigating at any settlement). Phase 4b
  allowlist filter ensures it only appears when NeedType includes it.
  Explicit AP cost entry added. 10 tests.

### Known Code Issues — Deferred (2026-05-19, writeback audit)
- **Gossip source concealment (`source_concealed`, `concealment_depth`) —
  FIXED.** EffectApplicator creates "gossip_received" knowledge entry for
  the listener: gossiper_id is the actor when unconcealed, -1 when
  source_concealed (Bayushi Courtier / concealment raises). Action log
  includes source_concealed + concealment_depth for investigation TN
  lookups. Also fixed duplicate gossip disposition application in
  _process_court_action_effects (was double-applying). 4 tests.
- **Position hardened/durable (`position_hardened`, `position_durable`) —
  emitted but never consumed.** NEGOTIATE (hardened on failure) and PERSUADE
  (durable on success, hardened on critical failure) emit these flags to
  distinguish position shift quality per GDD s15.4 ("hardens" / "durably"),
  but no position decay system reads them. Position shifts don't decay at
  all currently — no GDD spec for position decay exists. Forward-wiring.
- **False info on critical failure (`false_info`) — FIXED.**
  EffectApplicator._apply_false_info() creates knowledge entries on the
  actor with FRESH confidence and inverted data (wrong virtue, inverted
  disposition sign, inverted topic position). Entry types match false_info
  categories. is_false flag for debugging. 4 tests.
- **Scouts detected on critical failure (`scouts_detected`) — FIXED.**
  _process_scout_detection_topics() creates Tier 4 MILITARY topic on
  SCOUT_ENEMY critical failure. Title includes target clan if available.
  3 tests.
- **Charm ceiling active (`charm_ceiling_active`) — informational only,
  not a bug.** The ceiling IS enforced inside resolve_charm() (clamps
  disposition change). The flag is metadata for callers; harmless.

### Known Code Issues — Deferred (2026-05-19, data model audit)
- **Orphaned character_data fields (blocked sections).** The following
  fields exist on L5RCharacterData but are never referenced by any
  simulation code: `techniques`, `kiho`, `katas`, `weapons`, `armor_worn`,
  `active_quest`, `active_poisons`, `combat_modifiers_pending`. All are
  schema placeholders for blocked sections (s40 individual combat, s38
  kiho, s56 quest system). Do not remove — they will be consumed when
  those sections unlock. NOTE: `spells_known`, `spell_slots_used`,
  `spell_void_bonus_used` are now active (consumed by SpellSystem — s31–s37).
- **Orphaned character_data fields (not blocked) — RECLASSIFIED: blocked.**
  `timed_advantages` and `action_blocks` on L5RCharacterData ARE specified
  in s29.15.24 (LOCKED). timed_advantages: Ikoma Orator Paragon/Failure of
  Bushido. action_blocks: Ide R5 peace_locked, Miya R3 herald_immunity,
  Otomo R3 obiesaseru, Miya R4 blessing_ceasefire, ship captain
  INTERVENE_CAPTAIN (s55.11). Blocked on individual school technique
  implementation. Do not remove.
- **Orphaned province_data fields.** `rivers` and `roads` on
  ProvinceData have no producer or consumer. Likely intended for the
  world map / adjacency system (blocked). Do not remove until map
  data format is decided.
- **Military hierarchy constituent arrays — intentionally unpopulated.**
  `LegionData.constituent_companies`, `SectionData.constituent_legions`,
  and `ArmyData.constituent_sections` in MilitaryUnitData are declared
  but never written or read. All top-down queries (get_legion_companies,
  get_section_legions, get_army_sections) scan via `parent_*_id` fields.
  At current scale (~252 companies for the largest clan) linear scanning
  is fine. Populating constituent arrays would create sync burden on
  every creation, destruction, and reassignment for no measurable gain.
  Leave unpopulated until profiling shows a bottleneck.
- **CourtSessionData.next_request_id + REQUEST_PERFORMANCE writeback. FIXED.**
  Full pipeline was broken: executor returned effects but no writeback created
  the request dict on the court session, and `pending_performance_requests`
  was never injected into per-character world_states for the NPC engine.
  `_process_performance_request_writebacks()` scans results, finds the
  attendee's active court, creates request via `create_request()`, increments
  `next_request_id`. `_set_court_context_flags()` now injects
  `pending_performance_requests` into world_states. Request expiry wired
  into `_process_active_courts()` via `expire_requests()`. 5 tests.

### Known Code Issues — Deferred (2026-05-19, ActionID pipeline audit)
- **APPLY_TATTOO wiring gap. FIXED.** Added to AT_OWN_HOLDINGS and VISITING
  context lists, ActionExecutor dispatch (skill gate, AP check, body location
  validation, ability tattoo gate, SkillResolver roll), AP cost dictionary
  (2 base, variable via ap_cost_override), DayOrchestrator writeback
  (TattooData creation, extra AP deduction). Phase 4c precondition filter
  checks cultural reluctance consent (s57.25.3 disposition thresholds) and
  Togashi decorative gate (unfilled ability slots block decorative tattoos).
  Metadata population selects quality tier by skill rank. advance_day()
  gains tattoos and next_tattoo_id parameters. 18 tests.
- **FORCE_MARCH, EVALUATE_CLAN_STRENGTH — no executor, no context list.**
  Both appear in objective_alignment.json and action_skill_map.json with
  scores and skill mappings, but have no executor handler or context list
  entry. GDD s57.12 lists them as "new ActionIDs needing addition." Both
  blocked on sub-tile army movement system (s11.7a, map data dependency).
- **BRIBE_GARRISON_COMMANDER — Kolat-only, no executor.** Appears in
  objective_alignment.json under DESTROY_ECONOMY (score 90). Part of
  Kolat Coin sect architecture (s54.7d). Blocked on Kolat system (s56.14).
- **37 Kolat/artisan/theater ActionIDs — scored but no executor.** 23
  Kolat spy network actions (s54.7d, s56.14), 4 bonsai/garden actions
  (s49), 3 theater composition actions (s49), 4 reactive/non-AP-loop
  actions (ABORT_OPERATION, EXECUTE_ASSASSINATION, MOVE_TOPIC_POSITION,
  RAISE_DISPOSITION). All are forward-scored in objective_alignment.json
  for future implementation. These are NOT bugs — they are pre-wired
  scoring entries for blocked sections. Phase 4b filters them out because
  they don't appear in any context list.
- **SEEK_PRETEXT stale entries cleaned. FIXED.**
  SEEK_PRETEXT is a NeedType (outer key in objective_alignment.json) not an
  ActionID. Had stale entries in action_skill_map.json and AP cost dictionary.
  GDD s14 Category 13 lists it as both NeedType and ActionID, but no executor
  mechanics are specified — blocked on GDD design. Removed from
  action_skill_map.json and AP cost dict. Not in any context list (correct).
- **ISSUE_DUEL_CHALLENGE missing from context lists. FIXED.**
  Had full executor (IndividualCombat.resolve_full_duel), AP cost, and
  HOSTILE_ACTIONS entry, but was unreachable because it wasn't in any
  `_get_actions_for_context()` list. Added to AT_OWN_HOLDINGS, AT_COURT,
  VISITING per GDD s14 Category 13 (Honor and Dueling). 5 tests.

### Known Code Issues (found and fixed 2026-05-20, comprehensive ActionID audit)
- **DEMAND_TRIBUTE missing from all context lists. FIXED.**
  Had full executor (ADMINISTRATIVE_ACTIONS), 4 NeedTypes in
  objective_alignment (max score 70 under ACQUIRE_RESOURCE), personality
  filter entries (JIN blocks, KETSUI/KYORYOKU lean), but was unreachable.
  Added to AT_OWN_HOLDINGS. Added to LORD_ONLY_ACTIONS. 2 tests.
- **REQUEST_ALLIED_AID missing from all context lists. FIXED.**
  Had full executor (ADMINISTRATIVE_ACTIONS), 8 NeedTypes in
  objective_alignment (max score 75 under REQUEST_AID), personality
  filter entries (ISHI/KETSUI block), but was unreachable. Added to
  AT_OWN_HOLDINGS and AT_COURT. Added to LORD_ONLY_ACTIONS. 3 tests.
- **ISSUE_DUEL_CHALLENGE — to_death/is_sanctioned not populated. FIXED.**
  Executor reads `to_death` (default false) and `is_sanctioned` (default
  true). Without population, all NPC duels were non-lethal sanctioned.
  Now sets `to_death = true` when NeedType is ELIMINATE_CHARACTER.
  `is_sanctioned` kept at default true (sanctioned duel is the standard
  Rokugani form; unsanctioned duels require narrative context not modeled).
  2 tests.
- **CONDUCT_SORTIE — ss/force_size not populated. FIXED.**
  Executor reads `ss` from metadata with fallback to wall_statuses context.
  Metadata now populated from wall_statuses to make intent explicit.
  `force_size` left as "" (WallSystem.resolve_sortie handles default).
  2 tests.
- **TREAT_WOUND — raises not populated. FIXED.**
  Executor reads `raises` (default 0). NPCs never declared raises on
  Medicine rolls. Now set by `_pick_medicine_raises()` scaled by Medicine
  skill rank: 0-2→0, 3-4→1, 5+→3. Locked in s57.31a (GDD anchor: "At Rank 5
  with 3 Raises: 5k1" — no 2-Raise tier). 4 tests.
- **FORGE_IMPERSONATION_LETTER / FORGE_ORDER — full NPC pipeline wired. FIXED.**
  Both had working executors (SecretSystem.resolve_forge_impersonation_letter,
  resolve_forge_order), TN tables, and tests, but were unreachable (no context
  list, no scoring table entries, no personality filter, no metadata population).
  Added to AT_OWN_HOLDINGS, AT_COURT, VISITING context lists. AP cost 1 each
  (GDD s12.8). action_skill_map.json: Forgery/Agility for both (GDD-specified).
  personality_filter.json: blocked by JIN, REI, GI, MAKOTO (same as
  FABRICATE_SECRET — Category 6 Covert forgery actions). objective_alignment.json:
  DAMAGE_RELATIONSHIP (70/55), ACQUIRE_LEVERAGE (50/30),
  SUPPRESS_INVESTIGATION (45/60). Scores locked in s12.8b. Metadata:
  authority_level from target's lord_rank (locked B11); target_npc_id from
  need. 8 tests.
- **FORGE_IMPERSONATION_LETTER writeback — letter creation wired. FIXED.**
  `_process_forge_letter_writebacks()` creates LetterData on successful
  FORGE_IMPERSONATION_LETTER. Sets sender_id=impersonated person,
  forged_sender_id=actual forger, is_forged=true, forgery_tn from executor,
  disposition_bonus=0 (no Calligraphy quality per GDD s12.8). Enters normal
  letter pipeline — auto_detect_forgery fires on receipt if recipient has
  prior correspondence. Province distance PROVISIONAL (3). 3 tests.
- **FORGE_ORDER writeback — forged order creation + delivery wired. FIXED.**
  `_process_forge_order_writebacks()` creates LetterData with is_order=true
  on successful FORGE_ORDER. Impersonated sender = target's lord_id. Skips
  if target has no lord. `_process_forged_order_delivery()` fires after
  letter delivery: if forged order passes detection, writes objective to
  target's primary objective slot (matching real ASSIGN_VASSAL_OBJECTIVE
  pattern). Order type varies by forger's NeedType:
  SUPPRESS_INVESTIGATION→TRAVEL_TO, ACQUIRE_LEVERAGE→ATTEND_COURT,
  DAMAGE_RELATIONSHIP→PATROL_PROVINCE, default→TRAVEL_TO. LetterData gains
  order_need_type, order_target_province_id, order_target_npc_id,
  order_target_settlement_id, is_order, order_applied. 6 tests.
- **Detected forgery topic transfer bug. FIXED.**
  `process_pending_letters()` ran `deliver_letter()` even on detected
  forgeries, transferring topics and applying disposition bonuses. GDD s12.7
  specifies detected forgeries are disregarded. Now skips deliver_letter()
  on detection, marks as delivered, and returns result with
  forgery_detected=true. 2 tests.
- **Covert result metadata passthrough. FIXED.**
  `_build_covert_result()` in action_executor now includes
  `action.metadata` in the result dict. Without this, forge writeback
  handlers had no access to impersonated_id, recipient_id, or topic_id.
- **Reply confusion pipeline — impersonation detection wired. FIXED.**
  When a reply to an undetected forged letter is delivered to Person A
  (the impersonated victim), `_process_impersonation_detection()` fires:
  (1) creates "impersonation_detected" KnowledgeEntry on victim with
  forger_id and reply_from_id, (2) creates Tier 3 POLITICAL topic about
  the impersonation, (3) assigns INVESTIGATE_THREAT objective targeting
  the forger. Duplicate-safe (checks existing knowledge_pool entries).
  LetterData gains reply_to_forged and original_forger_id fields. Reply
  generation tags replies to undetected forgeries automatically.
  `generate_replies()` now skips detected forgeries entirely (recipient
  who detects a forgery does not reply). 5 orchestrator tests +
  3 letter system tests.
- **Forge crime record pipeline — CrimeRecord creation + escalation wired. FIXED.**
  `_create_forgery_crime_record()` creates DISHONORABLE_CONDUCT CrimeRecord
  at forge time (system always knows). FORGE_IMPERSONATION_LETTER creates
  MODERATE severity, FORGE_ORDER creates SERIOUS severity. Legal status
  starts at NONE (undiscovered). `_escalate_detected_forgery_crimes()`
  fires post-delivery: when auto-detection catches a forgery, matching
  CrimeRecord escalates to UNDER_INVESTIGATION with forger added to
  known_suspects. Crime record links forger (perpetrator_id) to victim
  (impersonated person), with concealment_tn from the forge roll for
  investigation difficulty. 5 tests.
- **Forge authority level — derived from lord_rank, not Forgery skill. FIXED.**
  `_forge_authority_from_rank(forgery_rank)` was mapping Forgery skill rank
  to authority level (7+→major, 4+→moderate, else→minor). GDD s12.8 says
  authority level is determined by who is being impersonated — local daimyo
  TN 20, Family Daimyo/Champion TN 25, Emperor TN 30. Replaced with
  `_forge_authority_from_lord_rank(lord_rank)` mapping LordRank enum:
  IMPERIAL→major, FAMILY_DAIMYO/CLAN_CHAMPION→moderate, else→minor.
  Uses target's lord_rank via chars_by_id lookup; falls back to forger's
  own lord_rank when target not found. Locked in B11.

### Forge Pipeline PROVISIONAL Values Audit (2026-05-20)
Values confirmed against GDD s12.8:
- FORGE_LETTER_TN: 15/20/25 (minor/moderate/major) — matches GDD exactly.
- FORGE_ORDER_TN: 20/25/30 (minor/moderate/major) — matches GDD exactly.
- Detection TN formula: base TN + (Raises × 5) — matches GDD exactly.
- Honor cost -0.3 / Infamy +0.1 — matches other Category 6 actions
  (Intercept a Letter, Search Quarters). GDD says "Using a Low Skill per
  Table 2.3, scaled by Honor Rank" — rank-scaling not yet implemented
  (systemic gap across all crime types, not forge-specific).
- Personality filter blocks (JIN, REI, GI, MAKOTO) — matches GDD virtues.
- Delivery distance 3 provinces — PROVISIONAL (blocked on map/adjacency data; A16).
- Forged objective priority 8 — LOCKED in s12.8b (A17: metadata only, inert).
- Impersonation detection topic TIER_3 — LOCKED in s12.8b (A18: TIER_3).
- INVESTIGATE_THREAT priority 6 — LOCKED in s12.8b (A19: metadata only, inert).

### Known Code Issues (found and fixed 2026-05-20, covert action audit)
- **COVERT_ACTION_IDS missing 4 Category 6 actions. FIXED.**
  BRIBE_FOR_INFO, EAVESDROP, FORGE_IMPERSONATION_LETTER, FORGE_ORDER were
  missing from COVERT_ACTION_IDS. Honor covert penalty (Filter 2) and
  virtue covert modifier (Filter 3) were not applied to these actions.
  SEARCH_PERSON removed (Category 5 Intelligence, not Category 6 Covert).
  3 tests.
- **SHADOW_TARGET missing detection_risk return key. FIXED.**
  `resolve_shadow_target()` returned `detected` but not `detection_risk`.
  The crime creation handler reads `effects.detection_risk` to decide whether
  to create a CrimeRecord. Without the key, detected shadowing never created
  a crime record. Added `detection_risk: detected` to return dict. 1 test.
- **SHADOW_TARGET missing from _action_to_crime_type. FIXED.**
  Detected shadowing had no crime type mapping. Added
  SHADOW_TARGET → DISHONORABLE_CONDUCT. 1 test.

### Covert Action Pipeline Audit (2026-05-20)
Remaining gaps (not critical, documented for future work):
- **EAVESDROP writeback — topic transfer wired. FIXED.**
  `_process_eavesdrop_writebacks()` fires after daily conversations resolve.
  Successful eavesdrop transfers topics from conversations at the same
  settlement. Base: 1 topic. Each free raise (margin/5) grants 1 more.
  Skips eavesdropper's own conversations and conversations at different
  locations. Creates INTELLIGENCE KnowledgeEntry per topic learned.
  Critical failure (margin <= -10): generates Spy Uncovered Tier 4 topic
  with subject_character_id = -1 (spy identity NOT revealed per GDD).
  5 tests.
- **SHADOW_TARGET writeback — surveillance data wired. FIXED.**
  `_process_shadow_target_writebacks()` fires after daily conversations.
  On success: creates INTELLIGENCE KnowledgeEntry with `shadow_surveillance`
  type containing target_id, contacts_observed (from conversation_results),
  and actions_observed (from NPC wave results). Per GDD s12.8: shadow
  learns who the target spoke with and what ActionIDs they fired, but not
  conversation content. Critical failure (margin <= -10): target identifies
  shadow, -5 disposition. Normal failure: target knows they're tailed but
  not by whom. 4 tests.
- CONCEAL_ITEM: NPC voluntary concealment has default metadata ("MEDIUM",
  non-weapon). Auto-conceal on NPC arrival handles assassination weapons
  correctly. No gap for current gameplay.
- **Table 2.3 rank-scaled honor — Using a Low Skill. FIXED.**
  `CrimeSystem.get_low_skill_honor_cost(character, skill_name)` implements
  the full Table 2.3 "Using a Low Skill" row with 6 honor brackets:
  Rank 0 → 0.0, 1-2 → -0.1, 3-4 → -0.2, 5-6 → -0.3, 7-8 → -0.6,
  9-10 → -0.9. School exemptions: full exempt (Shosuro Infiltrator,
  Bitter Lies, Kasuga Smuggler → 0.0), half exempt (Daidoji Harrier,
  Daidoji Spymaster, Ikoma Lion's Shadow → half cost), Scorpion clan →
  half cost. Skill-specific exemptions via boolean flags on character data:
  `intimidation_honor_exempt` (Otomo Courtier R1, Yoritomo Courtier R1),
  `commerce_honor_exempt` (Yasuki Courtier R1, Yoritomo Courtier R1,
  Ide Trader). Flags set by `SkillResolver.apply_technique_flags()`.
  Multi-school characters checked via school_paths. Wired into:
  SecretSystem (bribe→Temptation, eavesdrop→Stealth, intercept→Stealth,
  search→Sleight of Hand), SeductionSystem (Temptation),
  BoundEscapeSystem (Sleight of Hand), CommerceStigmaSystem (Commerce),
  ActionExecutor (Intimidation). Fabrication honor costs remain tiered
  by secret severity (GDD s12.8 specifies explicit per-tier values).
  19 tests.
- **Table 2.3 additional rows — disobedience, disloyalty, bribery. FIXED.**
  Eight new Table 2.3 rows added to CrimeSystem: DISOBEYING_LORD,
  FLEEING_BATTLE, FOLLOWING_ORDERS, LYING, MANIPULATING, FALSE_COURTESY,
  DUPED_CRIMINAL, DUPED_DISLOYAL. Helper functions: get_disobeying_lord_honor,
  get_disloyalty_honor, get_accepting_bribe_honor, get_fleeing_battle_honor,
  get_following_orders_honor. Wired consumers: OperationalHierarchySystem
  insubordination (was flat -0.3), IntraClanCivilWar defection and rebel
  hemorrhage (was flat -0.5/-0.3), BriberySystem bribe acceptance (was
  flat -0.5). FOLLOWING_ORDERS row (positive at low rank, negative at
  high rank) has no consumer yet — blocked on NPC engine objective
  conflict integration. 4 tests.
- **Low Skill glory on discovery — Caught using a Low Skill. FIXED.**
  `CrimeSystem.LOW_SKILL_DISCOVERY_GLORY = -0.3` per GDD s46 Glory table.
  Fires when the Low Skill user is identified by another character. Wired
  at 5 identification points: (1) SHADOW_TARGET critical failure (target
  identifies shadow), (2) forgery auto-detection on letter delivery (forger
  identified via CrimeRecord escalation), (3) assassination critical failure
  detection (household identifies assassin), (4) assassination SEARCH_PERSON
  equipment discovery (bodyguard finds concealed weapons), (5) EXAMINE_CRIME_SCENE
  suspect identification (raises >= 2, Low Skill crime type gate via
  `CrimeSystem.is_low_skill_crime_type()`). Commerce stigma glory penalty
  updated from -0.1 to -0.3 (commerce is inherently public, so discovery
  is automatic). `is_low_skill_crime_type()` returns true for
  DISHONORABLE_CONDUCT and SKIMMING. 7 tests.
- **Table 2.3 remaining rows — helpers and wiring. FIXED.**
  Added helper functions for all remaining Table 2.3 rows: `get_lying_honor()`,
  `get_manipulating_honor()`, `get_false_courtesy_honor()`,
  `get_duped_criminal_honor()`, `get_duped_disloyal_honor()`,
  `get_duped_foolish_honor()`. Added missing `HONOR_TABLE_DUPED_FOOLISH`
  constant per GDD s46. Three rows wired to mechanical triggers:
  (1) MANIPULATING fires on FORGE_ORDER delivery success (forger loses honor)
  and SEDUCE_TO_COMPROMISE entanglement creation (seducer loses honor).
  (2) FALSE_COURTESY fires on successful CHARM against RIVAL or worse
  disposition (actor disposition ≤ -11 toward target). Uses
  `DispositionSystem.get_tier()` check. (3) DUPED_DISLOYAL fires on
  impersonation detection when forged order was applied (victim discovers
  they followed a fake order from their lord). Three rows remain unwired:
  LYING (FABRICATE_SECRET already has its own explicit per-tier costs per
  GDD s12.8, no other mechanical "lying" trigger exists), DUPED_CRIMINAL
  (forge orders produce misdirections not criminal acts), DUPED_FOOLISH
  (no clear mechanical trigger). 14 tests.
- **Low Skill glory double-application prevention — audited and fixed. FIXED.**
  GDD s46 specifies "-0.3 Glory per incident." Six glory trigger points existed
  but no guard prevented the same incident from being penalized twice (e.g.,
  SHADOW_TARGET critical failure → -0.3, then later EXAMINE_CRIME_SCENE
  investigation on the same CrimeRecord → another -0.3). Added
  `low_skill_glory_applied: bool` flag to CrimeRecord. Point 1
  (EXAMINE_CRIME_SCENE) checks flag before applying. Points 2 (SHADOW_TARGET
  critical failure) and 3 (forgery auto-detection) set flag on the matching
  CrimeRecord. Points 4/5 (assassination ACCESS failures) don't create
  CrimeRecords, so no double-application risk. Point 6 (assassination
  concealment failure) creates UNSANCTIONED_COVERT_KILLING which is not a
  Low Skill crime type, so point 1's type gate blocks it. 1 test.
- **Trial-by-combat conviction consequences not applied. FIXED.**
  `ConvictionProcessor.resolve_trial_by_combat()` set `DECREED_GUILTY`
  on the CrimeRecord when the accused lost, but
  `_resolve_pending_trials()` in DayOrchestrator never called
  `CrimeSystem.apply_at_conviction_consequences()`. Glory, infamy, and
  status penalties from CONVICTION_CONSEQUENCES table were skipped for
  trial-by-combat losses. Now calls `apply_at_conviction_consequences()`
  when `accused_won == false`, adds consequence deltas and seppuku_offered
  to the trial result dict. 1 test.
- **CrimeWiring conviction consequence gaps. FIXED.**
  `process_treason_conviction()` set `DECREED_GUILTY` manually but never
  called `apply_at_conviction_consequences()`. Now calls it and returns
  glory/infamy/status/seppuku_offered in result dict. Topic tier now uses
  conviction result instead of hardcoded 2. `process_trial_by_combat()`
  gains optional `accused: L5RCharacterData` parameter. When accused loses
  and accused is provided, calls `apply_at_conviction_consequences()`.
  Backward compatible (existing callers without accused still work via
  manual `DECREED_GUILTY` fallback). 2 tests updated, 1 new test.

### Table 2.3 Honor Gain/Loss Wiring (2026-05-20)
Constants and helpers added to `crime_system.gd` for all Table 2.3 rows.
**Wired (mechanical triggers):**
- **Facing a superior foe** — ISSUE_DUEL_CHALLENGE where target.status >
  actor.status. `_process_duel_honor_writebacks()` in DayOrchestrator.
  2 tests.
- **Fulfilling a promise despite great personal cost** —
  CommitmentData FULFILLED with crisis_id >= 0 (debtor fulfilled despite
  active crisis). `_apply_promise_fulfillment_honor()` in DayOrchestrator.
  2 tests.
- **Showing sincere courtesy to enemies** — personality-gated CHARM against
  rivals/enemies. Rei or Jin virtue → sincere courtesy gain; other virtues →
  false courtesy loss. Replaces unconditional false courtesy at the same
  trigger point. 2 tests.
- **Enduring an insult to yourself** — target of successful PUBLIC_INSULT.
  Fires in `_process_court_action_effects()`. 2 tests.
- **Enduring insult to ancestors / family/clan** — constants and helpers
  added. Blocked on insult classification (currently all PUBLIC_INSULT
  treated as self-insult; ancestor/clan distinction needs insult type field).
- **Showing kindness to one beneath station** — DELIVER_GIFT or OFFER_FAVOR
  where actor.status > target.status. `_process_kindness_honor_writebacks()`
  in DayOrchestrator. 3 tests.
- **Giving a truthful report at own expense** — EXPOSE_SECRET_PUBLICLY or
  EXPOSE_SECRET_PRIVATELY where secret subject is same clan as exposer
  (reporting your own clan's dirty laundry). `_process_truthful_report_honor_writebacks()`.
  2 tests.
- **Protecting clan/family/lord despite great risk** — CONDUCT_SORTIE or
  SEAL_WALL_BREACH at a province with active_crisis_id >= 0.
  `_process_protecting_clan_honor_writebacks()`. 2 tests.
- **Politely ignoring dishonorable behavior** — non-magistrate witnesses of
  a crime receive ignoring honor adjustment at topic seeding time. Magistrates
  (UPHOLD_LAW holders) are exempt. Victims who are also witnesses exempt.
  Low honor gains (+0.3), high honor loses (-0.2). 4 tests.
- **Insult type classification** — PUBLIC_INSULT gains `insult_type` metadata
  (self/ancestors/clan). NPC engine selects: ELIMINATE_CHARACTER→ancestors,
  DAMAGE_RELATIONSHIP→clan, default→self. Self-insult gains honor, ancestor/
  clan insult loses honor. 3 tests.
- **Effect applicator: winner_glory_change gap. FIXED.** Duel winner glory
  (+0.5 at court) was emitted but never consumed when the winner was not
  the challenger. Added `_apply_winner_glory()` to EffectApplicator. 2 tests.
All 10 constant arrays and 10 helper functions added. 28 constant/integration tests.

### Known Code Issues (found and fixed 2026-05-20, effect key audit)
- **Duel crime record perpetrator/victim swap. FIXED.**
  When defender killed challenger in an unsanctioned duel,
  `_process_crime_detection()` always used `character_id` (challenger) as
  perpetrator and `target_npc_id` (defender) as victim. The executor
  correctly set `crime_perpetrator_id`/`crime_victim_id` in effects but the
  orchestrator ignored them. Now reads `crime_perpetrator_id`/
  `crime_victim_id` from effects with fallback to `character_id`/
  `target_npc_id`. `apply_at_act_consequences` and `_create_crime_topic`
  also use the correct perpetrator. 2 tests.
- **ASK_FOR_INTRODUCTION — contact never added. FIXED.**
  `contact_added`, `contact_id`, and `disposition_gain` were set in effects
  but never consumed. Successful introductions created no met_characters
  entry and no disposition change. `_process_introduction_writebacks()`
  calls `InformationSystem.add_contact()` and applies disposition_gain to
  target toward actor. 2 tests.
- **OBSERVE_COURT_ATTENDEES — learned info never transferred. FIXED.**
  `learned_attendees` was set in effects but never consumed. Successful
  observations yielded no knowledge. `_process_observe_attendees_writebacks()`
  adds observed NPCs to met_characters via `add_contact()` and creates
  `court_observation` KnowledgeEntry for each learned attendee. 2 tests.
- **INTIMIDATE blackmail — extracted favors never created. FIXED.**
  `favors_extracted` was set in effects but never consumed. Successful
  blackmail created no FavorData objects. `_process_blackmail_favor_writebacks()`
  creates one FavorData per extracted favor (MINOR tier, GENERAL type,
  `is_blackmail_extracted = true`). 2 tests.
- **public_commerce_topic — topic never created. FIXED.**
  `public_commerce_topic: true` was passed through from CommerceStigmaSystem
  but never consumed. Public commerce actions created no social signal topic.
  `_process_commerce_topic_writebacks()` creates a Tier 4 POLITICAL
  `commerce_stigma` topic with the merchant as subject. 2 tests.

- **READ_CHARACTER / PROBE — info_types never turned into knowledge. FIXED.**
  Executors set `info_types` (plural array: "personality_insight",
  "disposition_toward", "topic_attitude", "topic_position",
  "court_objective") but effect_applicator reads `info_type` (singular,
  only set by DISCERN_NEED). The specific info types were never processed
  into knowledge entries. `_process_intelligence_info_writebacks()` now
  creates type-specific KnowledgeEntry for each info_type: personality_insight
  stores bushido/shourido virtue, disposition_toward stores target's
  disposition value, topic_attitude/topic_position stores topic position,
  court_objective stores standing need_type from objectives_map. 5 tests.
- **Intelligence knowledge dedup — repeated reads accumulated. FIXED.**
  `add_knowledge()` is a simple append. Repeated READ_CHARACTER/PROBE
  against the same target accumulated entries without replacing older ones.
  Critical failure false_info would coexist with earlier true entries.
  `InformationSystem.update_intelligence_knowledge()` replaces existing
  entries matching same (entry_type, target_character_id) for dedup types:
  personality_insight, disposition_toward, topic_attitude, topic_position,
  court_objective, priority_objective. Non-dedup types (shadow_surveillance,
  court_observation, observed_action, gossip_received) still append.
  False info now correctly replaces true info (character is deceived) and
  subsequent true reads restore correct knowledge. 6 tests.

### Known Code Issues (found and fixed 2026-05-20, writeback coverage scan)
- **ANNOUNCE_HUNT writeback missing — topic and hunt state never created. FIXED.**
  Executor returned `hunt_date_ic_day`, `priority_invitee_id`, `topic_type`,
  `topic_tier` but no handler created the hunt announcement topic or stored
  hunt scheduling data. NPC engine read `active_hunt_id` and `hunt_topic_id`
  from `known_objectives` but nothing populated them. Added
  `_process_announce_hunt_writebacks()` (creates hunt dict + Tier 4 topic),
  `_inject_hunt_context()` (populates known_objectives for all characters),
  `active_hunts` and `next_hunt_id` parameters to advance_day. 2 tests.
- **REQUEST_HUNT_INVITATION writeback missing — invitations never processed. FIXED.**
  Executor returned `hunt_topic_id`, `requester_id`, `requester_status` but
  no handler evaluated whether the host accepts the request. Added
  `_process_request_hunt_invitation_writebacks()` which finds matching active
  hunt by topic_id, evaluates via HuntSystem.evaluate_invitation_response()
  (disposition/status/rival checks), adds accepted requesters to hunt's
  accepted_invitee_ids, applies glory/disposition changes from acceptance.
  Duplicate-safe. 3 tests.
- **CANCEL_HUNT writeback missing — disposition penalty never applied. FIXED.**
  Executor returned `accepted_invitee_ids`, `disposition_change_per_invitee`
  but no handler applied the DISP_CANCEL_PER_INVITEE (-1) penalty to each
  accepted invitee. `glory_change` was consumed by EffectApplicator. Added
  `_process_cancel_hunt_writebacks()` which marks hunt as cancelled and
  applies disposition penalties. 2 tests.
- **Duel death writeback missing — succession never triggers for duel deaths. FIXED.**
  `death_occurred`, `challenger_dead`, `defender_dead` from ISSUE_DUEL_CHALLENGE
  set but no handler created death_events, death topics, or triggered succession.
  `_process_duel_death_writebacks()` scans results for ISSUE_DUEL_CHALLENGE with
  death_occurred=true. Creates death_event per dead character (is_lord from
  role_position, killer_id from survivor, suspicious_death for unsanctioned).
  Creates death topic: sanctioned non-lord = Tier 4 PERSONAL, sanctioned lord =
  Tier 3 POLITICAL, unsanctioned = Tier 2 (always). subject_role = "NEUTRAL"
  per dead-character rule. Simultaneous deaths create two events/topics. Wired
  before _process_lord_deaths so succession fires same tick. 5 tests.
- **Assassination death_events missing is_lord — lord assassinations skip succession. FIXED.**
  `_apply_assassination_outcome()` appended death_events without `is_lord` or
  `suspicious_death` fields. `_process_lord_deaths()` checks `is_lord` and skips
  events without it. Assassinated lords never triggered succession or orphaned
  objectives. Added `is_lord: target.role_position != ""` and
  `suspicious_death: true` to the death event dict. 1 test.
- **Hunt resolution never fires — no daily trigger. FIXED.**
  `resolve_npc_hunt()` existed but nothing checked when ic_day reached the hunt
  date. `_resolve_scheduled_hunts()` fires daily: checks all active hunts for
  matching date, gathers host + accepted invitees (filters dead/traveling),
  generates beast from terrain pool via `HuntSystem.generate_beast()`, calls
  `resolve_npc_hunt()`, distributes glory via `compute_glory_distribution()`,
  applies disposition changes between co-participants (new relationships +3,
  existing acquaintances +1), handles casualties (wounded get wound_per_rank
  wounds, killed get lethal + death_event), creates hunt result topic (Tier 3
  if death, Tier 4 otherwise). Beast stat blocks and terrain pools added to
  hunt_system.gd (10 species, 5 terrain types). Values PROVISIONAL — GDD
  confirms bear=10 and ozaru=20 wound_threshold; others derived from s54.1
  bestiary stats. 6 tests.

### Known Code Issues (found and fixed 2026-05-21, NPC pipeline audit)
- **death_events array never cleared between advance_day() calls. FIXED.**
  `death_events` passed by reference from WorldState, appended to during the
  day (assassination, duel, hunt casualties), processed by
  `_process_lord_deaths()` and `_process_operational_death_cascade()`, but
  never emptied. Every death accumulated permanently and was reprocessed on
  every subsequent day — duplicate succession triggers, orphaned objective
  processing, hierarchy cascade re-fires. Added `death_events.clear()` after
  both death processing passes complete. 1 test.
- **Dead characters received AP on daily reset — entered decision loop. FIXED.**
  `ActionPointSystem.reset_daily_ap()` set AP unconditionally (no death
  check). Dead NPCs got 2 AP per day, passed `_get_active_characters()`
  filter (checks AP > 0), and entered the NPC wave resolver loop. Produced
  `DO_NOTHING` results (benign because world_state population skips dead
  characters at line 1203), but wasted compute and polluted action logs.
  Added `CharacterStats.is_dead()` guard — dead characters get 0 AP. 2 tests.
- **honor_change_recipient on DISPATCH_COURTIER refusal never consumed. FIXED.**
  `action_executor.gd:1830` set `honor_change_recipient: honor_loss` (-0.3
  to -1.0 scaled by Wall urgency) when a daimyo refused garrison requests.
  No writeback or applicator consumed this key — it didn't match
  `honor_change` (EffectApplicator reads for actor) or `honor_gain_recipient`
  (`_apply_garrison_assignment` reads on success path only). Wired into
  `_apply_garrison_courtier_refusal_writebacks()` with `characters_by_id`
  passthrough. 2 tests.

### Known Code Issues — Remaining (2026-05-21, NPC pipeline audit)
- **Civilian order resolution skips allowlist filter. FIXED.**
  `npc_wave_resolver.gd:422` applied personality_filter but not
  `apply_allowlist_filter()`. Lords' civilian orders could select actions
  with 0 objective alignment for their current NeedType. Added
  `apply_allowlist_filter()` call after personality_filter in
  `_resolve_civilian_order()`. Practical impact was low (governance/military
  actions only) but correctness now matches the standard AP-loop pipeline.
- **Urgency rule for HONOR_FAVOR/BREAK_FAVOR is dead. FIXED.**
  Removed `favor_expiring_within_7_ooc_days` rule from urgency_rules.json.
  `HONOR_FAVOR` and `BREAK_FAVOR` are NeedTypes in reactive_decisions.gd,
  not AP-loop ActionIDs. The +20 urgency bonus never matched any action.
  Favor honoring runs through the reactive decision path, not the AP
  scoring loop.
- **Dead characters not removed from court attendee lists on death. FIXED.**
  `_cleanup_dead_character_references()` added to advance_day() after death
  processing. Removes dead character IDs from all active court attendee_ids
  arrays. Also added `CharacterStats.is_dead()` skip in
  `_process_court_attendance()` to prevent dead characters from being
  re-added to courts based on physical_location. 2 tests.
- **Entanglements, favors, hunt participations not cleaned on death. FIXED.**
  `_cleanup_dead_character_references()` handles all three: breaks
  entanglements involving dead participants (sets state to BROKEN), cancels
  hunts with dead hosts and removes dead invitees from accepted lists,
  dissolves favors using existing FavorSystem.process_debtor_death() and
  process_creditor_death() (creditor favors transfer to designated heir).
  5 tests.

### Effect Key Audit Dead Keys — Informational / Not Bugs (2026-05-20)
The following effect keys are set but intentionally unconsumed by the
effect applicator or orchestrator. They are metadata, Pattern B pre-applied
costs, or forward-wiring. Do not treat as bugs.
- `blocked_reason` — Informational: explains why action was blocked.
- `charm_ceiling_active` — Informational: ceiling enforced inside
  `resolve_charm()`. Flag is metadata for callers.
- `honor_cost` — Pattern B: pre-applied in SecretSystem, SeductionSystem,
  FeasibilityLedger, SiegeSystem, BoundEscapeSystem, etc.
- `ikoma_bard_exempt` — Informational: Ikoma Bard R2 exemption applied.
- `position_durable` / `position_hardened` — Forward-wiring: no position
  decay system exists. Will be consumed when position decay is implemented.
- `target_is_kuge` — Informational: ASK_FOR_INTRODUCTION metadata.
- `info_count` — Intermediate: consumed by executor internally.
- `compliance_active` — Informational: intimidation compliance state.
- `void_recovered` / `host_vp_recovered` / `participant_gains` /
  `recovery_per_participant` — Pattern B: pre-applied in executor
  (MEDITATE line 2633, TEA_CEREMONY lines 3977-3985).
- `wounds_healed` / `kit_charge_consumed` / `wound_level_after` —
  Pattern B: pre-applied in MedicineSystem.resolve_treatment().
- `is_first_session` / `progress_gained` / `fully_trained` /
  `sessions_completed` — Pattern B: pre-applied in executor
  (TRAIN_ANIMAL lines 4249, 4301).
- `duel_result` / `winner_id` / `loser_id` / `simultaneous` —
  Pattern B: duel outcome pre-applied by IndividualCombat. `death_occurred`,
  `challenger_dead`, `defender_dead` now consumed by
  `_process_duel_death_writebacks()` for death events and topics.

### Known Code Issues — Deferred (2026-05-19, metadata population audit)
- **EXPOSE_SECRET_PRIVATELY — metadata unpopulated, always fails. FIXED.**
  Full pipeline wired: SecretData.known_by_ids tracks who knows each secret.
  4 creation points (bribe/extortion/witness) populate known_by_ids.
  DayOrchestrator injects per-character known_secrets into world state.
  ContextSnapshot.known_secrets flows through build_context.
  `_pick_best_secret()` selects most severe unexposed secret matching need
  target. `_pick_private_recipient()` finds a present non-subject character.
  Executor emits subject_id/secret_id for writeback. Writeback adds recipient
  to known_by_ids. 8 NPC engine tests, 5 orchestrator tests.
- **EXPOSE_SECRET_PUBLICLY — same pipeline as EXPOSE_SECRET_PRIVATELY. FIXED.**
  Shares `_pick_best_secret()`. No recipient needed (public). Writeback skips
  known_by_ids update for public exposure.
- **PURIFY_TAINTED_GROUND — ptl not populated, TN always base 15. FIXED.**
  Added `province_taint_level` to ProvinceStatus, populated from ProvinceData
  in `build_province_statuses_from_data()`. Metadata case in
  `_populate_action_metadata()` looks up PTL from ctx.province_statuses.
  2 tests.
- **PUBLIC_ATONEMENT — offense_key/offense_tier not populated. FIXED.**
  `_inject_self_offenses()` in DayOrchestrator scans active_topics for
  unresolved topics where `subject_character_id` matches the NPC. Creates
  offense entries with `offense_key = "topic_%d"` and tier matching topic
  tier. Flows through world_state → ContextSnapshot.self_offenses →
  `_pick_best_offense()` (selects highest-severity unatoned offense) →
  metadata. Skips already-atoned and resolved topics.
  LIMITATION: Only topic-sourced offenses. Crime-sourced offenses (from
  CrimeRecord convictions) not yet integrated — requires offense
  registration pipeline from legal system. 7 tests.
- **SCOUT_ENEMY — target_clan_id not populated. FIXED.** Metadata case
  extracts enemy clan from first active war via
  `WarSystem.get_enemy_clan_from_war()`. Empty string if no active wars.
  2 tests.
- **REQUEST_PERFORMANCE — target_performer_id not populated. FIXED.** Metadata
  case uses `need.target_npc_id` as target performer (set by decomposer when
  NPC has a specific performer objective). Defaults to -1 (generic request) if
  no target. Also sets performance_type="song", venue_mode="public". 2 tests.
- **DRILL_TROOPS — target_company_id not populated. FIXED.** Metadata case
  uses `ctx.assigned_company_id` (preferred) or `ctx.commanded_unit_id`
  (fallback). 2 tests.
- **OFFER_FAVOR — metadata empty, court_settlement_id missing. FIXED.** Added
  OFFER_FAVOR to the 7-action court metadata population block (was 6-action).
  Now gets `court_settlement_id`, `has_topic`, `need_type`. Favor obligation
  commitments now include court attendee witnesses. 1 test.
- **TRAIN_ANIMAL — `character` undefined in _populate_action_metadata. FIXED.**
  TRAIN_ANIMAL metadata case referenced `character` variable but function
  signature was `(option, need, ctx)` — would cause GDScript parse error.
  Added optional `character: L5RCharacterData = null` parameter to both
  `_populate_action_metadata()` and `generate_options()`. Call sites updated.
  Backward-compatible (existing 2-arg and 3-arg callers unchanged).
- **INTIMIDATE — blackmail path unreachable via NPC daily loop. FIXED.**
  `_pick_secret_about_target()` selects most severe unexposed secret about
  the intimidation target from known_secrets. Populates secret_ref,
  secret_tier, by_letter. Without a matching secret, falls through to
  standard intimidation. 4 tests.
- **FABRICATE_SECRET — writeback missing + metadata defaults. FIXED.**
  Two fixes: (1) `_process_fabricate_secret_writebacks()` assigns secret_id
  from next_secret_id, adds fabricator to known_by_ids, appends to
  active_secrets. Fabricated secrets now usable by EXPOSE_SECRET and
  INTIMIDATE blackmail. 4 orchestrator tests. (2) `_pick_fabrication_severity()`
  selects severity by Forgery rank: 7+→TIER_1, 5-6→TIER_2, 3-4→TIER_3,
  1-2→TIER_4 (maps to TNs 30/25/20/15). need.target_npc_id flows through
  so fabricated secrets target the objective target. 4 engine tests.
- **PLAY_GAME — always Games: Go. FIXED.** `_pick_best_game_skill()` selects
  game with highest skill rank from 6 types. Falls back to Games: Go. 2 tests.
- **ARRANGE_MARRIAGE — favor_tier/has_military_objective not populated. FIXED.**
  `_get_favor_tier_held_against()` finds best favor tier from held_leverage.
  Military NeedTypes (SECURE_ALLIANCE, RAISE_ARMY, DEFEND_PROVINCE) set
  has_military_objective. Both feed MarriageSystem.evaluate_proposal. 4 tests.
- **CONCEAL_ITEM — defaults to MEDIUM non-weapon.** Executor reads
  `item_size` ("MEDIUM"), `is_weapon` (false). No metadata population for
  NPC-initiated concealment. DayOrchestrator auto-bypass for contraband
  arrivals DOES set proper metadata. Only affects voluntary CONCEAL_ITEM.
- **SEARCH_PERSON — magistrate_authority not populated. FIXED (partial).**
  `magistrate_authority` now set from UPHOLD_LAW standing objective.
  `concealment_tn` still defaults to 15 (requires item concealment tracking
  not available in NPC context). Assassination pipeline sets proper metadata
  for both fields. 2 tests.

### Known Code Issues (found and fixed 2026-05-17)
- **DefenseHearingSystem.can_appoint_champion() — tautology bug. FIXED.**
  Was `return X != Y or X == Y`. GDD s11.3.9f confirms either side may appoint a
  champion regardless of school type. Changed to explicit `return true`, renamed param
  to `_accused` to suppress unused-parameter warning.
- **MagistrateAllocationSystem.is_emerald_jurisdiction() — dead parameter. FIXED.**
  Was `return true` ignoring its `EmeraldJurisdictionTrigger` parameter. GDD s11.3.17c
  confirms all four triggers (CROSS_CLAN_CRIME, TREASON, MAHO, LOCAL_JUSTICE_FAILED)
  qualify. Replaced with explicit match so future enum additions require a deliberate
  decision rather than silently returning true.
- **MagistrateAllocationSystem.can_override_clan_magistrate() — stub clarified. FIXED.**
  GDD s11.3.6 states Emerald Magistrates have Empire-wide authority over any clan
  magistrate — unconditional. Added reference comment to distinguish intent from stub.

### Systems Added 2026-05-17
- **s57.38 Hunting Party System** — `simulation/hunt_system.gd`. Three ActionIDs:
  ANNOUNCE_HUNT, REQUEST_HUNT_INVITATION, CANCEL_HUNT. NPC-only resolution (tracking +
  kill + casualty rolls), glory distribution, school leans. Player ASCII mission deferred
  (blocked on s56 coordinate system).
- **s57.39 Animal Handling** — `simulation/animal_handling_system.gd`. TRAIN_ANIMAL (1 AP),
  7-species table (DOG through WARCAT), companion cap by rank, training tiers ("wild" /
  "following" / "trained"), mastery gates at Rank 5 and 7, school leans. ASCII combat layer
  deferred (blocked on s40/s56).
- **s57.40 Commerce & Caste Stigma** — `simulation/commerce_stigma_system.gd`. Rank-scaled
  honor penalty + flat glory penalty on public Commerce rolls. Once-per-IC-day sentinel.
  Ide Trader exception. Wired in action_executor.gd `_apply_effects()`. Rank 5 mastery and
  Appraisal emphasis deferred per s57.40.8–9 (GDD marks these deferred — do not implement
  until s57.40.8–9 are unlocked).

### Systems Added 2026-05-19
- **Commitment Registry — 6 of 6 types fully wired.** COURT_ATTENDANCE
  (SEND_INVITATION + Winter Court invitations, tier by court type).
  VISIT_PROMISE (LetterData visit_intent, 90-day deadline PROVISIONAL,
  NPC engine trigger at AT_OWN_HOLDINGS). MEETING_ARRANGEMENT (bilateral
  proposals, both parties simultaneously debtor and creditor, creditor
  travel check). SUPPORT_PLEDGE (PERSUADE/NEGOTIATE at court, position
  alignment check, fulfillment via persuade_count + public_debate_count).
  RESOURCE_PROMISE (REQUEST_ALLIED_AID + NEGOTIATE + ASSIGN_VASSAL_OBJECTIVE,
  tier by quantity, SHARE_SUPPLIES/ORDER_DEPLOY fulfillment). FAVOR_OBLIGATION
  (created alongside FavorData, visibility only per s55.31.2).
- **Commitment advance notice and proxy system.** send_advance_notice()
  detects unfulfillable commitments within 7-day window, personality-driven
  send decision. register_proxy() dispatches closest vassal as proxy.
- **Commitment retroactive forgiveness.** Crisis topic matching via
  crisis_id field on TopicData. Same-clan 75% vs cross-clan 25% rate.
  Crisis lifecycle wired: famine, Shadowlands breach, insurgency spawn.
- **Position resistance applied to court actions.** calculate_position_resistance()
  now called for targeted actions and per-witness debate shifts. Formula:
  shift / (1 + relevance/100).
- **Court session state persistence.** session_state Dictionary on
  CourtSessionData with per-character tracking of charm_count,
  negotiate_count, tn_reductions, persuade_tn_reductions. Wired for
  Charm, Negotiate, Impress, Listen/Reflect.
- **ProxyMandateData model.** shared/proxy_mandate_data.gd created per
  GDD s16.2. assign_proxy_mandate(), get_proxy_mandate(),
  is_within_mandate(), flag_out_of_mandate() on CourtSystem.
- **NPC engine court context wiring.** court_session_state and
  court_settlement_id flow from CourtSessionData into ContextSnapshot.
  6 contested court actions get full metadata population.
- **Information system wiring fixes.** s55.6 transfer_objective_knowledge()
  wired into ASSIGN_VASSAL_OBJECTIVE. broadcast_public_knowledge() now
  creates FRESH confidence knowledge entries. met_characters routing
  through add_contact() (2 bypass points fixed). Military promotion
  results written back to character/company data.
- **Travel redirect and approach evaluation writebacks.** TravelCommitment
  redirect counter incremented on CHANGE_DESTINATION. ApproachEvaluation
  wired for READ_CHARACTER/PROBE measurement results. CommitmentRegistry
  crisis linking wired. Commitment fulfillment checker replaced dummy
  callable with actual per-type evaluation.
- **Phase 7 resource validation.** ResourceAvailability.can_afford()
  validates before executing. AP/civilian order refunded on failure.
- **Koku deduction.** EffectApplicator._apply_koku_cost() handles
  koku_cost effect key for BRIBE_FOR_INFO (5 koku) and PURCHASE_MARKET
  (3 koku).
- **Disposition snapshot system.** _populate_disposition_snapshots()
  captures all pairs at season start for approach evaluation
  disposition_at_start tracking.
- **APPLY_TATTOO full pipeline.** Context lists, executor dispatch,
  AP cost, body location validation, ability gate, SkillResolver roll,
  writeback (TattooData creation), cultural reluctance precondition
  filter. 18 tests.
- **Secret pipeline wiring.** EXPOSE_SECRET_PRIVATELY/PUBLICLY:
  SecretData.known_by_ids, per-character known_secrets injection,
  _pick_best_secret(), writeback. FABRICATE_SECRET: writeback creating
  SecretData, severity selection by Forgery rank. INTIMIDATE blackmail
  path: _pick_secret_about_target().
- **Metadata population fixes (13 ActionIDs).** PURIFY_TAINTED_GROUND,
  PUBLIC_ATONEMENT, SCOUT_ENEMY, REQUEST_PERFORMANCE, DRILL_TROOPS,
  OFFER_FAVOR, TRAIN_ANIMAL, PLAY_GAME, ARRANGE_MARRIAGE,
  SEARCH_PERSON, EXPOSE_SECRET_PRIVATELY/PUBLICLY, FABRICATE_SECRET.

### Systems Added 2026-05-20
- **FORGE_IMPERSONATION_LETTER / FORGE_ORDER full NPC pipeline.** Context
  lists (AT_OWN_HOLDINGS, AT_COURT, VISITING), action_skill_map.json
  (Forgery/Agility), personality_filter.json (JIN/REI/GI/MAKOTO blocks),
  objective_alignment.json (DAMAGE_RELATIONSHIP, ACQUIRE_LEVERAGE,
  SUPPRESS_INVESTIGATION), metadata population (authority_level from
  lord_rank, target_npc_id from need). 8 tests.
- **Forge writeback pipeline.** FORGE_IMPERSONATION_LETTER creates
  LetterData (is_forged, forged_sender_id, forgery_tn). FORGE_ORDER
  creates LetterData (is_order, order_need_type). Forged order delivery
  writes objective to target's primary slot. Detected forgeries skip
  deliver_letter(). Reply confusion: impersonation detection on reply
  delivery creates KnowledgeEntry + topic + INVESTIGATE_THREAT objective.
- **Forge crime record pipeline.** CrimeRecord created at forge time
  (DISHONORABLE_CONDUCT). Auto-detection escalates to
  UNDER_INVESTIGATION. Concealment_tn from forge roll. 5 tests.
- **Covert action pipeline fixes.** COVERT_ACTION_IDS updated (added
  BRIBE_FOR_INFO, EAVESDROP, FORGE_IMPERSONATION_LETTER, FORGE_ORDER;
  removed SEARCH_PERSON). SHADOW_TARGET detection_risk and crime type
  mapping added. 3 tests.
- **EAVESDROP writeback.** Topic transfer from overheard conversations
  at same settlement. Free raises grant extra topics. Critical failure
  generates Spy Uncovered Tier 4 topic. 5 tests.
- **SHADOW_TARGET writeback.** Surveillance intelligence: contacts_observed,
  actions_observed. Critical failure: target identifies shadow (-5 disp).
  Normal failure: target knows they're tailed but not by whom. 4 tests.
- **Table 2.3 rank-scaled honor — Using a Low Skill.** Full implementation
  with 6 honor brackets and school/clan exemptions. Wired into 7 systems
  (SecretSystem, SeductionSystem, BoundEscapeSystem, CommerceStigmaSystem,
  ActionExecutor, BriberySystem, OperationalHierarchySystem). Skill-specific
  exemptions via boolean flags (intimidation_honor_exempt,
  commerce_honor_exempt). 19 tests.
- **Table 2.3 additional rows.** DISOBEYING_LORD, FLEEING_BATTLE,
  FOLLOWING_ORDERS, LYING, MANIPULATING, FALSE_COURTESY, DUPED_CRIMINAL,
  DUPED_DISLOYAL, DUPED_FOOLISH. Wired mechanical triggers: MANIPULATING
  on FORGE_ORDER delivery and SEDUCE_TO_COMPROMISE, FALSE_COURTESY on
  CHARM against RIVAL, DUPED_DISLOYAL on impersonation detection. 18 tests.
- **Low Skill glory penalty on discovery.** -0.3 per incident at 6
  identification trigger points. Double-application prevention via
  low_skill_glory_applied flag on CrimeRecord. Commerce stigma glory
  updated from -0.1 to -0.3. 8 tests.
- **Table 2.3 honor gain rows.** Facing superior foe (duel against
  higher Status), fulfilling promise despite crisis, sincere/false
  courtesy (personality-gated), enduring insult (self/ancestors/clan
  classification), kindness to inferiors (gift/favor), truthful report
  (same-clan secret exposure), protecting clan at risk (sortie/breach
  with crisis). 28 tests.
- **Conviction consequence gaps.** Trial-by-combat and treason conviction
  now call apply_at_conviction_consequences(). Winner glory change wired
  for non-challenger duel winners. 5 tests.
- **Insult type classification.** PUBLIC_INSULT gains insult_type metadata
  (self/ancestors/clan) for differential honor treatment. Politely ignoring
  dishonorable behavior wired for non-magistrate witnesses. 7 tests.
- **Effect key writeback wiring (4 dead keys).** ASK_FOR_INTRODUCTION
  contact_added → add_contact() + disposition. OBSERVE_COURT_ATTENDEES
  learned_attendees → add_contact() + KnowledgeEntry. INTIMIDATE
  favors_extracted → FavorData creation. public_commerce_topic → Tier 4
  topic creation. 8 tests.
- **READ_CHARACTER/PROBE info_types → knowledge entries.** 5 info types
  (personality_insight, disposition_toward, topic_attitude, topic_position,
  court_objective) now create type-specific KnowledgeEntry. Intelligence
  knowledge dedup replaces stale entries on re-read. False info correctly
  replaces true info. 11 tests.
- **Gossip source concealment.** source_concealed / concealment_depth
  wired into knowledge entries and action log. Duplicate gossip disposition
  double-application fixed. 4 tests.
- **False info on critical failure.** Inverted knowledge entries (wrong
  virtue, inverted disposition/position). 4 tests.
- **Scouts detected on critical failure.** Tier 4 MILITARY topic on
  SCOUT_ENEMY critical failure. 3 tests.
- **Hunt resolution daily trigger.** _resolve_scheduled_hunts() checks
  active hunts matching ic_day, gathers participants, generates beast
  from terrain pool (10 species, 5 terrain types), distributes glory,
  applies co-participant disposition changes, handles casualties and
  death events. 6 tests.
- **Hunt ActionID writebacks.** ANNOUNCE_HUNT creates hunt dict + topic.
  REQUEST_HUNT_INVITATION evaluates host acceptance. CANCEL_HUNT applies
  disposition penalties. Hunt context injection for NPC engine. 7 tests.
- **Duel death writeback.** _process_duel_death_writebacks() creates
  death events and topics for duel fatalities. Tier scaling by
  sanctioned/unsanctioned and lord/non-lord. Wired before _process_lord_deaths
  for same-tick succession. 5 tests.
- **Assassination death_events fix.** is_lord and suspicious_death fields
  added to assassination death events for succession triggering. 1 test.
- **Letter topic momentum fix.** topics_by_id now passed through to
  process_pending_letters(). Tier 4 topic discussion_count_this_day
  increment now functional. 2 tests.
- **REQUEST_PERFORMANCE writeback.** Full pipeline: request creation on
  court session, world state injection, request expiry. 5 tests.
- **ActionID context list gaps.** PURCHASE_MARKET, CONDUCT_COMMERCE,
  EXAMINE_CRIME_SCENE, DEMAND_TRIBUTE, REQUEST_ALLIED_AID,
  ISSUE_DUEL_CHALLENGE added to appropriate context lists. SEEK_PRETEXT
  stale entries cleaned. 22 tests.
- **Comprehensive ActionID metadata fixes.** ISSUE_DUEL_CHALLENGE
  to_death/is_sanctioned population. CONDUCT_SORTIE ss metadata.
  TREAT_WOUND raises by Medicine rank. 8 tests.
- **SkillResolver from_the_ashes expiry gap.** Buff checked against
  ic_day parameter, expired buffs cleared. 6 tests.

### Systems Added 2026-05-22
- **WorldStateSaver — full world state persistence.** Prior to this,
  only L5RCharacterData (via SaveManager) and the tick counter (via
  SimulationScheduler) persisted across restarts. All other world state
  — provinces, topics, wars, courts, edicts, letters, commitments,
  secrets, tattoos, hunts, assassination operations, governance states,
  clan data, ID counters, collective disposition baselines — was lost on
  restart. `scripts/managers/world_state_saver.gd` (class WorldStateSaver,
  extends RefCounted) saves and restores the full WorldStateData:
  20 Resource-typed collections via Godot ResourceSaver (one .tres per
  item, keyed by primary ID field), Dictionary/primitive state via JSON
  (state.json), ClanData via JSON (clans.json), mixed-type arrays
  (favors, letters) with format auto-detection on load. Wired into
  SimulationScheduler: _save_world_state() fires after each tick,
  _load_world_state() fires on startup. Save directory:
  `user://saves/world/` with 21 sub-directories for typed collections.
  18 round-trip tests.
- **WorldStateData inline state promotion.** 9 fields that were
  previously passed as inline empty arrays in advance_one_day() are now
  persistent fields on WorldStateData: active_secrets, next_secret_id,
  active_hostages, tattoos, next_tattoo_id, active_hunts, next_hunt_id,
  next_commitment_id, next_crisis_id. These now survive between sessions
  instead of silently resetting to empty on every startup.

### Known Code Issues (found and fixed 2026-05-22, DayOrchestrator audit)
- **KILL_WITNESS never created death_events — lord succession skipped. FIXED.**
  `_apply_victim_death()` set wounds to lethal and created a death topic
  but never appended to `death_events`. If a killed witness held a lord
  position, succession never triggered. Added `death_events` parameter to
  `_apply_victim_death()` and `_process_witness_tampering_writebacks()`.
  Creates death_event with `suspicious_death: true`. 2 tests.
- **Construction validation key mismatch — temples, monasteries, ships. FIXED.**
  `valid_4.get("valid_4", false)`, `valid_5.get("valid_5", false)`,
  `valid_6.get("valid_6", false)` used wrong keys (copy-paste error from
  variable suffix). All three always evaluated to false, silently blocking
  FOUND_TEMPLE, FOUND_MONASTERY, and COMMISSION_SHIP construction. Changed
  to `valid_4.get("valid", false)` etc., matching BUILD_FORTIFICATION and
  BUILD_SHRINE patterns.
- **Natural deaths never created death_events — lord succession skipped. FIXED.**
  `_process_gempukku()` set wounds to lethal and created a topic but never
  appended to `death_events`. Function didn't even receive the parameter.
  Lords dying of natural causes never triggered succession, orphaned
  objectives, or hierarchy cascade. Added `death_events` parameter and
  death_event creation with `is_lord`, `suspicious_death: false`. Also
  added second death processing pass after seasonal block (gempukku runs
  in seasonal, but `_process_lord_deaths` runs in daily phase before
  `death_events.clear()`). Natural death topics now set
  `subject_character_id` and `ic_day_created`.
- **Battle war scores never fire — wrong key access. FIXED.**
  `md.get("battle_triggered", false)` at two sites read top-level key, but
  `battle_triggered` is nested inside `mr["battle_check"]`. Changed to
  `md.get("battle_check", {}).get("battle_triggered", false)`. War scores
  from battle engagements were silently lost, affecting war termination.
- **Army recovery computed but never applied. FIXED.**
  `_process_army_recovery()` computed `health_recovery` and
  `morale_recovery` per company but only placed them in metadata — never
  wrote back to company dicts. Armies never healed between battles. Added
  writeback lines for `current_health`, `current_morale`, and
  `arms_deprivation_tick`.
- **objectives_map type mismatch in impersonation detection. FIXED.**
  `objectives_map[victim_id] = []` initialized as Array instead of
  Dictionary. Every other site uses `{}`. The INVESTIGATE_THREAT objective
  was invisible to the NPC engine. Changed to `objectives_map[victim_id] = {}`
  with proper `["primary"]` key assignment.
- **Seppuku refusal topic never added to active_topics. FIXED.**
  `resolve_seppuku()` created TopicData but only returned `topic_id` in
  result dict. Object went out of scope. Orchestrator searched
  `active_topics` for the ID (never found it). Lord got phantom topic_id
  in topic_pool. Now returns `refusal_topic` TopicData in result dict;
  orchestrator appends it to `active_topics`.
- **Civil war resolution topic tier uses raw int. FIXED.**
  `topic.tier = 2` assigned raw int 2 = TIER_3 (enum: TIER_1=0, TIER_2=1,
  TIER_3=2, TIER_4=3). Intent was TIER_2. Changed to
  `TopicData.Tier.TIER_2`.
- **Court commitment renege topic tier off by one. FIXED.**
  `CourtCommitmentSystem` returned raw ints 3 and 2 for topic_tier.
  Assigned directly to enum field: raw 3 = TIER_4, raw 2 = TIER_3.
  Both one level lower than intended. Changed source to use
  `TopicData.Tier.TIER_3` and `TopicData.Tier.TIER_2`. Momentum
  comparison updated to use enum.
- **Letter ID computed from array size, not max ID. FIXED.**
  `next_letter_id = [pending_letters.size() + 1]` — after save/load,
  letters with high IDs could collide with newly assigned ones. Changed
  to scan max `letter_id` across all pending letters.
- **Winter Court letter IDs used separate counter. FIXED.**
  `wc_letter_id = [pending_letters.size() + 1000]` created a disconnected
  counter that would eventually collide with main letter IDs. Changed to
  reuse `next_letter_id`.
- **Heir designation topics not filtered by candidate. FIXED.**
  `_evaluate_heir_designations` gave ALL of lord's known topics to EVERY
  candidate equally. Achievement scoring factor was meaningless. Added
  `topic.subject_character_id == cand_id` filter.
- **Togashi worship_maluses structure mismatch. FIXED.**
  `_build_togashi_world_state()` iterated worship malus values as nested
  fortune→tier dictionaries, but `compute_all_province_maluses()` returns
  flat combined dicts with keys like "stability_per_season" (floats/bools).
  Calling `.get("tier", 0)` on a float would crash. Replaced with check
  for any negative float/int or true bool value.
- **Dead characters not filtered in 5 functions. FIXED.**
  `_find_province_lord()`, `_get_clan_champions()`, `_run_strategic_reviews()`,
  `_gather_promotion_candidates()`, `_apply_blessing_disposition()` all
  iterated characters without `CharacterStats.is_dead()` check. Dead lords
  could be selected as province lords, champions, strategic review
  targets, and promotion candidates.
- **_track_court_called missing current_season. FIXED.**
  `_apply_court_creation()` called `_track_court_called()` without
  `current_season` parameter (default -1). `last_court_season` never set,
  allowing duplicate court creation in same season. Threaded
  `current_season` through `_process_military_effects` →
  `_apply_court_creation` → `_track_court_called`.
- **Hunt disposition bypasses add_contact(). FIXED.**
  `_apply_hunt_disposition()` directly mutated `met_characters` instead of
  routing through `InformationSystem.add_contact()`. Hunt co-participants
  never appeared in `known_contacts_by_clan`. Same bug class as two
  previous fixes (WindDown and travel arrival). 12 tests.

### Known Code Issues (found and fixed 2026-05-22, NPC WaveResolver audit)
- **Reactive events double-executed — not consumed after reactive phase. FIXED.**
  `_resolve_reactive_events_full()` and `_resolve_reactive_events()` ran the
  full decision+execution pipeline for NPCs with pending events but never
  called `_consume_reactive_event()`. The event remained in `pending_events`
  and was processed AGAIN in the subsequent AP wave (`_resolve_character_wave_full`
  calls `_consume_reactive_event` after `run()`). Result: NPCs spent 2 AP on
  the same event, double-executing effects (double honor loss, double
  disposition change, etc.). Added `_consume_reactive_event()` call after
  each reactive decision in both paths. 1 test.
- **Dead characters entered reactive event loop. FIXED.**
  `_gather_reactive_npcs()` iterated all characters checking for
  `pending_events` without a `CharacterStats.is_dead()` guard. Dead NPCs
  with leftover pending events (injected before death) would enter the
  reactive loop and execute decisions. Added dead character filter. 1 test.
- **Civilian order result missing metadata dict. FIXED.**
  `_resolve_civilian_order()` returned the decision dict without
  `chosen.metadata`. `_execute_decision()` reconstructs a ScoredAction
  from the decision dict and reads `decision.get("metadata", {})` — always
  empty for civilian orders. Actions requiring metadata (ASSIGN_VASSAL_OBJECTIVE,
  ANNOUNCE_HUNT, REQUEST_PERFORMANCE, etc.) executed with blank inputs. Added
  metadata propagation matching the AP path pattern. 1 test.
- **Civilian order context built without chars_by_id. FIXED.**
  `_resolve_civilian_order()` called `build_context(character, world_state)`
  without the third `chars_by_id` parameter. Family bonds (s22.6), marriageable
  vassal detection, garrison shortage personality scores, and deception defense
  penalties were all skipped for lord civilian order decisions. Added
  `characters_by_id` optional parameter to `_resolve_civilian_order()`, passed
  through from the full-execution call site. Also passed `character` to
  `generate_options()` and `chars_by_id` to `score_all()`. 1 test.
- **Dead characters wrote letters in daily letter pass. FIXED.**
  `_process_daily_letter_pass()` iterated all characters without a
  `CharacterStats.is_dead()` check. Dead non-lord NPCs (civilian_order_budget_max
  == 0) would go through `resolve_daily_letter()`, select targets, and create
  LetterData objects from the grave. Added dead character filter at loop start.
  1 test.

### Known Code Issues (found and fixed 2026-05-23, deep ActionExecutor audit)
- **DISPATCH_COURTIER refusal — `recipient_disposition_change` silently dropped. FIXED.**
  Failure path (line 1817) returned `success: false` with `recipient_disposition_change: -2`
  but no `"failed": true`. EffectApplicator gate at line 27 early-returned, silently
  skipping `_apply_recipient_effects()`. Daimyo refusing garrison commitment never got
  the -2 disposition penalty. Added `"failed": true` to failure effects dict. 1 test.
- **SEAL_WALL_BREACH failure — `koku_cost` silently dropped. FIXED.**
  Failure path (line 2186) returned `success: false` with `koku_cost: 5.0` but no
  `"failed": true`. EffectApplicator gate skipped `_apply_koku_cost()`. GDD s2.4.16
  specifies "Failure: no SI change, Koku still paid." Extracted effects dict to variable,
  conditionally added `"failed": true` on failure. 1 test.
- **ARRANGE_MARRIAGE rejection — `disposition_change` silently dropped. FIXED.**
  Rejection path (line 2992) returned `success: false` with `disposition_change: -3`
  but no `"failed": true`. EffectApplicator gate skipped `_apply_disposition()`.
  Proposing lord never received -3 disposition penalty from rejected marriage proposal.
  Added `"failed": true` to failure effects dict. 1 test.
- **`_get_co_located_ids()` — dead characters included as witnesses. FIXED.**
  Iterated all characters_by_id without `CharacterStats.is_dead()` check. Dead
  characters at the same location were included in witness lists for PUBLIC_DEBATE,
  PUBLIC_INSULT, GOSSIP, PROVOKE_EMOTION, broadcast social, and PUBLIC_PERFORMANCE.
  Dead witnesses received disposition changes through EffectApplicator. Added dead
  guard. 1 test.

### Known Code Issues (found and fixed 2026-05-23, comprehensive dead-char sweep)
- **performative_arts_system.gd — dead witness/recipient disposition. FIXED.**
  `apply_performance_effects()` checked `witness != null` / `recipient != null`
  but not dead. Dead characters received performance disposition changes.
  Added `CharacterStats.is_dead()` guards. 2 sites.
- **imperial_edict_system.gd — dead characters in defiance and strip_autonomy. FIXED.**
  `_apply_defiance_to_characters()` outer and inner loops, and
  `apply_strip_autonomy()` loop all iterated characters without dead guards.
  Dead clan members received honor changes, disposition changes toward
  emperor, and were selected as champions. 3 sites. 2 tests.
- **intra_clan_civil_war.gd — dead characters in 4 loops. FIXED.**
  `apply_defector_consequences()` (dead faction members received -15 disp),
  `apply_post_war_scars()` (dead characters received/applied scars),
  `decay_post_war_scars()` (dead characters received scar decay),
  `apply_rebel_consequences_on_legitimacy_victory()` (dead rebels received
  honor penalties). All checked `c == null` but not dead. 4 sites. 2 tests.
- **phoenix_council.gd — dead representatives in Grand Ritual. FIXED.**
  `apply_grand_ritual_devastation()` applied emperor disposition to dead
  clan representatives. Added dead guard. 1 test.
- **action_executor.gd — dead witnesses in PUBLIC_DEBATE. FIXED.**
  Dead characters contributed witness disposition tiers to debate resolution,
  influencing position shifts for living characters. Added dead guard.
- **koku_cascade_system.gd — dead retainers receive stipends. FIXED.**
  `distribute_individual_stipends()` paid koku and applied lord disposition
  to dead retainers. Added dead guard. 1 test.

### Iaijutsu Duel Gaps Implemented (2026-05-23)
- **Stare-Down (s4.8, LOCKED)** — `resolve_iaijutsu_stare_down()` added to
  IndividualCombat. Contested Intimidation/Willpower roll. Loser takes -1k0
  on Assessment roll (stare_down_penalty_id on DuelState). Ties produce no
  effect. Optional pre-duel step — not called by resolve_full_duel (callers
  opt in). 2 tests.
- **Assessment Concession (s4.8, LOCKED)** — `concede_at_assessment()` added.
  Ends duel immediately. No honor/glory change for non-death duels. Death
  duel concession costs -0.5 Glory (GLORY_DECLINE_DEATH_DUEL). 2 tests.
- **First blood duel — second attack prevented (s4.8, existing bug).**
  resolve_duel_strike() allowed second striker to attack after first blood
  was drawn, incorrectly applying damage to the winner. Fixed: second attack
  skipped when first blood drawn in non-death duels. first_blood_drawn flag
  added to strike result. 1 test.
- **Striking after first blood (s4.8, LOCKED)** — `resolve_strike_after_first_blood()`
  added for the dishonor edge case. Returns HONOR_STRIKING_AFTER_FIRST_BLOOD
  (-1.0 Honor). Sets struck_after_first_blood flag on DuelState. 1 test.
- **NPC stare-down decision** — `_should_attempt_stare_down()` in ActionExecutor.
  Yu/Ketsui/Ishi attempt (aggressive/determined). Rei/Jin/Seigyo decline
  (courtesy/compassion/control). Neutral virtues: attempt only at Intimidation 3+.
  Gate: Intimidation 0 always declines. Checked for BOTH challenger and defender
  per GDD ("either duelist may attempt"). Stare-down fires if either side wants
  it. Result tracks which side initiated via challenger_initiated/defender_initiated
  flags. 8 tests.
- **NPC assessment concession decision** — `_should_concede_at_assessment()` in
  ActionExecutor. Only fires when outmatched (opponent got +1k1 AND defender
  failed Assessment). Yu/Ketsui/Ishi never concede. Seigyo/Chishiki always
  concede when outmatched. Meiyo concedes in non-death duels only. Neutral
  virtues concede in non-death duels. 4 tests.
- **ISSUE_DUEL_CHALLENGE executor rewritten** — Now uses step-by-step duel
  resolution instead of resolve_full_duel(). Stare-down fires when personality
  approves. Concession evaluated after Assessment — defender concedes early
  when outmatched and personality permits. Concession path applies -0.5 Glory
  for death duels directly. Full duel continues if no concession.
  2 integration tests (defender-initiated stare-down, both-decline).

### Known Code Issues (found and fixed 2026-05-23, NPC engine audit)
- **CHANGE_DESTINATION missing from objective_alignment — unreachable. FIXED.**
  Was in TRAVELING context list but had no entry in objective_alignment.json
  under TRAVEL_TO NeedType. The allowlist filter (Phase 4b) removed it
  because TRAVEL_TO only listed BEGIN_TRAVEL. Traveling NPCs who needed to
  redirect their travel always ended up with DO_NOTHING. Added
  CHANGE_DESTINATION: 100 to TRAVEL_TO NeedType. 1 test.
- **PERFORM_RITUAL ActionID missing from PERFORM_RITUAL NeedType — unreachable. FIXED.**
  Name collision: PERFORM_RITUAL exists as both a NeedType (outer key) and
  ActionID. The ActionID was not listed under its own NeedType. Shugenja at
  temples with PERFORM_RITUAL need could never select the PERFORM_RITUAL
  action. Added PERFORM_RITUAL: 90. Score locked in A22: direct action wins
  its own NeedType (100); worship is valid fallback (90). 1 test.
- **RESTORE_COUNCIL_COMPACT missing from objective_alignment — unreachable. DEFERRED.**
  Phoenix Champion voluntary action (s55.10.3.7) in AT_OWN_HOLDINGS context
  but has no scoring entry. Requires a NeedType that Phoenix Champions with
  `phoenix_champion_authority` naturally receive through the strategic review
  (s55.10.3). Design gap — GDD says personality-driven (Chugi restores, Ishi
  keeps) but doesn't specify NeedType routing.
- **ORDER_BATTLE dead entry in URGENCY_CATEGORY_NEED_TYPES. FIXED.**
  ORDER_BATTLE was listed as a NeedType in "actions_addressing_war" urgency
  category but doesn't exist as a NeedType in objective_alignment (it's only
  an ActionID). The matching function looked up an empty dict and silently
  returned false. Removed dead entry. The other three NeedTypes
  (LEVY_TROOPS, DEPLOY_ARMY, CONDUCT_SIEGE) are unaffected.
- **Dead urgency condition evaluator for favor_expiring_within_7_ooc_days. FIXED.**
  Match arm existed in `_evaluate_urgency_condition()` but the urgency rule
  was previously removed from urgency_rules.json. Dead code removed.
  `expiring_favor_ids` field retained — still consumed by
  `_has_existential_threat()` for virtue covert modifier (s12.8 Filter 3).
- **Dead contact garrison scores — dead characters in garrison scoring. FIXED.**
  `build_context()` computed garrison_shortage_personality_modifier for dead
  contacts (checked `!= null` but not `is_dead`). Dead contacts influenced
  DISPATCH_COURTIER targeting. Added dead guard. 1 test.
- **Dead characters entered AP waves after mid-day death. FIXED.**
  `_get_active_characters()` checked `action_points_current > 0` without
  `is_dead()`. Characters killed mid-day (duel, assassination, hunt casualty)
  still had AP from morning reset and entered subsequent wave resolution.
  The daily reset guard (already fixed) only prevented AP assignment on the
  NEXT day. Added dead guard to both `_get_active_characters()` and
  `_get_max_ap()`. 1 test.

### Known Code Issues (found and fixed 2026-05-23, NPC engine audit continued)
- **WinterCourtSystem._build_topic_pool_map() — dead characters included. FIXED.**
  Iterated `characters_by_id` without dead guard. Dead characters' topic
  pools were included in the map used for personal invitation scoring and
  agenda topic ordering. Added `CharacterStats.is_dead(c)` guard. 1 test.
- **WinterCourtSystem.record_emperors_peace_violation() — dead family daimyo
  received glory penalty. FIXED.** Iterated `characters_by_id` looking for
  the offender's family daimyo without dead guard. A dead family daimyo
  could receive the PEACE_VIOLATION_FAMILY_DAIMYO_GLORY penalty. Added
  dead guard. 1 test.

### Known Code Issues (found and fixed 2026-05-23, EffectApplicator dead-char sweep)
- **Witness disposition loss applied to dead witnesses. FIXED.**
  `_apply_witness_effects()` checked `witness == null` but not
  `CharacterStats.is_dead(witness)`. Dead witnesses received disposition
  loss from witnessed actions (PUBLIC_INSULT, INTIMIDATE, etc.).
  Added dead guard. 1 test.
- **Witness disposition gain applied to dead witnesses. FIXED.**
  `_apply_witness_gain()` same pattern — dead witnesses received broadcast
  disposition gains (PUBLIC_PERFORMANCE, BROADCAST_SOCIAL). Added dead
  guard. 1 test.
- **Target witness disposition applied to dead witnesses. FIXED.**
  `_apply_target_witness_effects()` same pattern — dead witnesses received
  target-facing disposition changes from PUBLIC_INSULT. Added dead guard.
  1 test.
- **Gossip effects applied to dead listener. FIXED.**
  `_apply_gossip_effects()` checked `listener == null` but not dead. Dead
  gossip listeners received disposition changes toward the gossip subject
  and got KnowledgeEntry entries. Added dead guard. 1 test.

### Known Code Issues (found and fixed 2026-05-23, comprehensive audit)
- **Active wars format mismatch — NPC engine received WarData, expected Dictionary. FIXED.**
  `world_states["active_wars"]` was pre-converted by `_sync_wars_to_world_states()`
  but DayOrchestrator re-converted the already-converted array, causing typed loop
  `for war: WarData in wars:` to null-cast Dictionaries. All `w is Dictionary` checks
  in NPC urgency conditions silently returned false — war urgency was completely
  non-functional. Fixed by using raw `active_wars` parameter directly. War score
  extraction also fixed: `_get_own_war_score()` helper returns clan-specific
  `war_score_a`/`war_score_b` instead of nonexistent `war_score`. 3 tests.
- **Naval context keys never reached NPC engine — underscore prefix mismatch. FIXED.**
  `_is_coastal`, `_has_naval_assets`, `_has_naval_threat` stored with `_` prefix
  in global world_states but NPC engine reads without prefix. All three always
  defaulted to false. Now injected into per-character world_states without prefix.
  1 test.
- **Dead character guards (6 functions). FIXED.**
  `StarvationWarfare._find_clan_lord()`, `CourtCommitmentSystem.process_seasonal_commitments()`
  (dead lords triggered renege consequences), `DayOrchestrator._populate_resource_stockpiles()`
  (dead lords got resource data populated), `OperationalHierarchySystem.get_operational_subordinates()`
  and `clear_subordinates_on_death()` (dead characters returned as subordinates),
  `DailyConversation.resolve_settlement_conversations()` (dead characters paired for
  conversations), `GempukkuSystem.count_clan_population()` (dead guard nested inside
  `wounds_taken > 0` conditional — dead characters with 0 wounds still counted).
  8 tests.
- **Hostage escape family_honor_loss never applied. FIXED.**
  `HostageSystem.resolve_escape()` returned `family_honor_loss` (-1.0 normal,
  -2.0 critical) but no handler applied it to biological family members.
  `_apply_hostage_escape_family_honor()` now applies honor loss to mother, father,
  spouse, siblings, and children. Dead family members skipped. 2 tests.
- **DISHONORABLE_CONDUCT conviction topic_tier was raw -1. FIXED.**
  `CONVICTION_CONSEQUENCES` dictionary used -1 for DISHONORABLE_CONDUCT topic_tier
  while all other crime types used `TopicData.Tier.TIER_X` enum. Changed to TIER_4.
  Fallback default also fixed from raw int 4 to enum. 1 test.
- **Sleight_of_Hand skill name mismatch in action_skill_map.json. FIXED.**
  CONCEAL_ITEM primary skill was "Sleight_of_Hand" (underscores) but canonical
  skill name is "Sleight of Hand" (spaces). The underscore form never matched
  any skill_ranks entry, giving all NPCs rank 0 competence (-20 modifier) for
  concealment, making voluntary CONCEAL_ITEM nearly unreachable.
- **Unclamped disposition assignments in extradition_system. FIXED.**
  `apply_cooperation()` and `apply_refusal()` wrote disposition values without
  `clampi()`, allowing values to exceed [-100, 100] range. Every other disposition
  assignment in the codebase uses clampi(). 2 tests.
- **Honor/glory mutations bypassing HonorGlorySystem [0.0, 10.0] clamp. FIXED.**
  Five direct mutations: `assassination_system` (execution honor), `day_orchestrator`
  (spiritual insurgency honor/glory, assassination commission honor),
  `action_executor` (COMMISSION_ASSASSINATION honor via maxf missing 10.0 ceiling,
  duel concession glory via maxf missing 10.0 ceiling). All now route through
  `apply_honor_change()`/`apply_glory_change()`.
- **Infamy bypass in violence_system. FIXED.**
  `apply_consequences()` used direct `attacker.infamy += evaluation["infamy_gain"]`
  bypassing HonorGlorySystem's [0.0, 10.0] clamp. Changed to
  `HonorGlorySystem.apply_infamy_change()`.
- **Dead sender letter exchange bonus. FIXED.**
  `LetterSystem.generate_replies()` checked `sender_char != null` but not dead.
  Dead senders received calligraphy quality exchange bonus. Added dead guard.
- **Dead character guards — disposition mutations (~15 sites). FIXED.**
  `_apply_favor_breach()` creditor and witnesses, WindDown conversation targets
  and met_characters, SHADOW_TARGET critical failure target, ASK_FOR_INTRODUCTION
  contact/actor, Provoke Emotion witnesses, Play a Game bilateral disposition,
  Disclose opinion transfer, PUBLIC_DEBATE per-witness, court departure host,
  marriage rejection target lord, Miya Blessing representative, Dragon FC assault
  empire-wide penalty, hunt invitation host/requester, cancel hunt invitees.
  All were checking null but not `CharacterStats.is_dead()`.
- **WinterCourtSystem.compute_glory_rewards() — dead attendee/champion. FIXED.**
  Dead host clan attendees and dead clan champions received glory rewards.
  Added dead guards. 2 tests.
- **CollectiveDisposition.seed_disposition_if_missing() — implicit safety. FIXED.**
  Seed value was mathematically bounded to [-75, 75] but not explicitly
  clamped via `clampi()`. Added defensive clamp. 1 test.
- **Dead character guard — confidence decay loop. FIXED.**
  `_decay_knowledge_confidence()` iterated all characters without dead check.
  Dead characters had their knowledge confidence uselessly decayed.
- **Dead character guards — strategic_review.gd (4 sites). FIXED.**
  `_evaluate_winter_court_host()` iterated clan champions without dead guard
  (dead champions scored for Winter Court hosting). `_fabricate_disgrace()`
  iterated champions without dead guard. `_evaluate_breaking_point()` counted
  dead champions in hostile clan count. `_seed_collective_baselines()` applied
  baselines for dead champions. Also added `clampi(baseline, -100, 100)` to
  baseline seeding.
- **Theology → "Lore: Theology" skill name mismatch — 7 code sites + 5 JSON entries. FIXED.**
  `action_skill_map.json` had bare "Theology" for BUILD_SHRINE, FOUND_MONASTERY,
  FOUND_TEMPLE, PERFORM_RITUAL, PERFORM_WORSHIP. `action_executor.gd` worship
  executor used `character.skills.get("Theology", 0)`. `spiritual_insurgency_system.gd`
  used `shugenja.skills.get("Theology", 0)`. `day_orchestrator.gd` used bare
  "Theology" in `_find_province_shugenja()` and POSITION_SKILL_WEIGHTS table
  (Temple Head, Monastery Abbot). `world_generator.gd` Shiba Bushi school data
  used bare "Theology". 11 of 12 schools store the skill as "Lore: Theology" in
  `character.skills`, so all lookups silently returned rank 0. All changed to
  "Lore: Theology". Temple Head POSITION_SKILL_WEIGHTS deduplicated (had both
  bare "Theology" and "Lore: Theology"). Test files updated (3 files).
- **IMPRESS action always rolled Lore rank 0 — bare "Lore" skill lookup. FIXED.**
  `_CONTESTED_ATTACKER_SKILL` mapped IMPRESS to "Lore" (bare), but characters
  store Lore sub-skills as "Lore: Heraldry", "Lore: Theology", etc. GDD s15.4
  specifies "Intelligence + Lore (relevant)". Added best-Lore-sub-skill selection
  in `_execute_contested_court_action()` (picks highest-ranked "Lore: *" entry).
  Same fix in `NPCDecisionEngine._compute_competence_modifier()` for scoring.
  2 tests.
- **Bare "Games" in world generator skill pools — characters got unusable skill. FIXED.**
  `HIGH_POOL` and `ALL_SKILL_POOL` used bare "Games" but NPC engine's
  `_pick_best_game_skill()` searches "Games: Go", "Games: Shogi", etc. Characters
  created with `skills["Games"]` could never use it for PLAY_GAME. Changed to
  "Games: Go". Added `_best_skill_rank()` helper in NPCDecisionEngine for
  generalized category-to-sub-skill resolution (Lore, Games, Perform, Craft,
  Artisan). 4 tests.
- **known_objectives["lord_assigned"] never populated — 3 NPC engine consumers dead. FIXED.**
  `_inject_urgency_data()` populated `known_objectives` with `standing_need_type`
  and `active_case` but never set `lord_assigned` from `primary.assigned_by`.
  Three consumers always got `false`: `not_lord_commanded` precondition (never
  blocked self-directed alternatives), `no_prior_grievance_or_lord_directive`
  (never detected lord directives), CHUGI virtue covert modifier (always -25
  instead of +10 on lord business). Added `assigned_by >= 0` check. 2 tests.
- **24 TopicData creation sites missing title field. FIXED.**
  21 in day_orchestrator.gd, 1 in assassination_system.gd, 1 in
  togashi_oversight.gd, 1 in war_termination.gd. Also added `title` key
  to SuccessionSystem.generate_succession_topic() return dict. Topics
  affected: shadowlands incursion, horde sighting, spy uncovered,
  commerce stigma, impersonation detection, succession, naval battle,
  Otomo exhaustion, Togashi directive/defiance, Phoenix council veto,
  natural death, marriage, organic village, construction (5 types),
  commitment renege, civil war triggered/resolved, assassination death
  (3 tiers), duel death, hunt announcement/result, betrayal, Togashi
  vanished, war termination (4 types).
- **_crime_type_to_string() — 5 CrimeType enum values missing from match. FIXED.**
  DISHONORABLE_CONDUCT, UNSANCTIONED_DUEL_DEATH, MAGISTRATE_CORRUPTION,
  DUEL_DEFILEMENT, VIOLATION_EMPERORS_PEACE all fell through to "other".
  Now return descriptive strings for investigation logs.
- **Alibi check null guard — characters_by_id.get() unchecked. FIXED.**
  `_check_witness_evidence()` passed raw .get() results to
  `_check_alibi_for_target()` without null guards. If characters_by_id
  was empty or missing the ID, null would flow through to SkillResolver
  and crash on co-conspirator alibi path.

### Known Code Issues (found and fixed 2026-05-23, world_states audit)
- **Stale context flags persisting across days. FIXED.**
  `world_states` (persistent Dictionary on WorldState autoload) was never
  cleared between `advance_day()` calls. Context keys like `context_flag`,
  `active_court_at_location`, `court_session_state`, `zone_subtype`,
  `active_insurgency_id` persisted from yesterday. Characters retained
  `AT_COURT` indefinitely after their court closed, blocking wall tower
  and temple context assignment. `_clear_stale_context_flags()` now runs
  at the start of each day, erasing all location-context keys before the
  context setters re-evaluate.
- **Per-character action_log accumulating across days. FIXED.**
  `npc_wave_resolver.gd` appended to `ws["action_log"]` during wave
  resolution but never cleared it. After day 1, personality filter
  conditions like `already_committed_to_action` always returned true,
  `no_intelligence_gathered_this_session` always returned false, and
  `public_declaration_already_made` always returned true. Added
  `action_log` to daily stale key clearing.
- **self_offenses, wall_statuses, criminal_recall staleness. FIXED.**
  Three more conditionally-set keys that persisted between days:
  `self_offenses` (atoned offenses still appeared), `wall_statuses`
  (characters who left towers kept stale data, append pattern
  accumulated entries), `criminal_recall` (recall results from
  yesterday persisted instead of being re-evaluated).
- **siege_settlement_id type mismatch — String passed as int. FIXED.**
  `_populate_action_metadata()` for CONDUCT_STORM_ASSAULT / MAINTAIN_SIEGE
  set `siege_settlement_id: ctx.location_id` (String) but
  `action_executor.gd` read it as `int` with `-1` fallback. Converted
  via `to_int()` with empty-string guard.
- **SupplyTetherSystem.TetherState raw int comparisons. FIXED.**
  Two sites used raw `2` instead of `SupplyTetherSystem.TetherState.BROKEN`:
  `npc_decision_engine.gd:3556` and `day_orchestrator.gd:9384`.
- **Renege topic slug using wrong source. FIXED.**
  `_process_commitment_seasonal()` used `renege_info.get("topic_id", 0)`
  (source dict key that likely doesn't exist) instead of the newly
  generated `topic_id` variable for the slug.
- **Missing null guards — emperor and togashi lookups. FIXED.**
  Winter Court selection passed potentially null emperor to
  `run_winter_court_selection()`. Togashi reappear flow passed
  potentially null togashi_char to `reappear_togashi()`.

### Known Code Issues (found and fixed 2026-05-23, lifecycle leak audit)
- **Resolved wars never removed from active_wars array. FIXED.**
  `WarTermination.resolve_annihilation()` / `resolve_formal_surrender()` /
  `resolve_negotiated_settlement()` set `war.is_active = false` but nothing
  removed the WarData from `active_wars`. Every war ever declared persisted
  forever, requiring `if not war.is_active: continue` guards at 8+ iteration
  sites. `_remove_resolved_wars()` now runs after war termination processing
  completes. 1 test.
- **Resolved successions never removed from active_successions array. FIXED.**
  `SuccessionSystem.confirm_successor()` transitions state to CONFIRMED/RESOLVED
  but nothing removed the SuccessionData from `active_successions`. Every
  succession event persisted forever. `_remove_resolved_successions()` now runs
  after `_process_successions()`. 1 test.
- **Resolved civil wars never removed from active_civil_wars array. FIXED.**
  `IntraClanCivilWar.finalise()` sets `state["active"] = false` but nothing
  removed the Dictionary from `active_civil_wars`. `_remove_resolved_civil_wars()`
  now runs after seasonal civil war processing. 1 test.
- **Released/escaped hostages never removed from active_hostages array. FIXED.**
  Hostages marked `released: true` or `escaped: true` by escape attempts and
  war peace resolution were skipped via guard clause but never removed.
  `_remove_resolved_hostages()` now runs after war hostage release. 1 test.
- **Resolved/cancelled hunts never removed from active_hunts array. FIXED.**
  Hunt resolution set `status: "resolved"`, cancellation set `status: "cancelled"`,
  dead host set `status: "cancelled_no_host"`. All skipped via guard but never
  removed. `_remove_resolved_hunts()` now runs after hunt writebacks. 1 test.
- **FavorData never marked resolved — re-processing on each tick. FIXED.**
  (Previous session.) `FavorData.resolved: bool` field added. `honor_favor()`,
  `break_favor()`, `process_expirations()`, `process_deadline_breaches()`,
  `process_creditor_death()`, `process_debtor_death()` all now set
  `favor.resolved = true` on resolution. Processing loops guard with
  `not favor.resolved`.
- **BROKEN entanglements accumulated in entanglements array. FIXED.**
  (Previous session.) Death cleanup set entanglement state to BROKEN but the
  collection pass skipped already-BROKEN entries instead of adding them to the
  removal list. Fixed by collecting BROKEN entries for removal.
- **Closed courts persisted in active_courts array. FIXED.**
  (Previous session.) Courts transitioning to CLOSED state were never removed.
  `_process_active_courts()` now collects closed courts and removes them.
- **No assassination operation dedup guard. FIXED.**
  (Previous session.) Same assassin-target pair could have multiple parallel
  assassination operations. Added dedup check scanning existing ops.
- **No settlement-level court duplicate guard. FIXED.**
  (Previous session.) Two lords at the same settlement could both create courts.
  Added settlement_id check in `_apply_court_creation()`.
- **Resolved topics never removed from active_topics array. FIXED.**
  `TopicMomentumSystem.process_daily_tick()` sets `resolved = true` on
  decayed/expired topics, but nothing removed them. All consumers skip
  resolved topics via `not t.resolved` guards. `_remove_resolved_topics()`
  now runs after daily topic processing. Character `topic_pool` arrays
  may retain orphaned IDs for removed topics — benign (lookups fail
  gracefully). 1 test.
- **Terminal commitments never removed from commitments array. FIXED.**
  Commitments transitioning to FULFILLED, BROKEN_*, or EXPIRED were
  never removed. All processing loops guard with
  `status == CommitmentStatus.PENDING`. `_remove_terminal_commitments()`
  now runs after deadline processing and retroactive forgiveness. 1 test.
- **Resolved favors removed after daily processing. FIXED.**
  `_remove_resolved_favors()` runs after `_process_favors()`. Combined
  with FavorData.resolved tracking added earlier, favors are now properly
  cleaned up at all resolution points (honor, break, expiration, death).
  1 test.

### Known Code Issues (found and fixed 2026-05-24, dead character sweep)
- **BiologicalFamily.compute_all_family_bonds() — dead characters in half-sibling
  and cross-clan marriage scans. FIXED.** Half-sibling scan (line 100) and
  cross-clan marriage relative scan (line 126) iterated chars_by_id without
  `CharacterStats.is_dead()` guard. Dead relatives produced disposition bonds
  that were applied to living NPCs during context building. Added dead guards
  at both scan sites and at the NPC engine consumer (build_context line 74).
  3 tests.
- **Topic seeding — dead lords, witnesses, victims received topics (14 sites). FIXED.**
  Lord topic seeding (8 sites in crime detection, seppuku refusal, etc.),
  witness/victim crime topic seeding (2 sites), WindDown topic leak target
  (1 site), forged order delivery target (1 site), impersonation detection
  victim (1 site), and initial topic distribution (1 site) all added
  topic IDs to dead characters' topic_pool arrays. Dead characters were
  never processed by the NPC engine, so the topics were wasted compute.
  Added `CharacterStats.is_dead()` guards at all 14 sites.
- **Forged order delivery — dead recipients received objectives_map mutations. FIXED.**
  `_process_forged_order_delivery()` checked `target == null` but not dead.
  Dead recipients could have forged objectives written to their objectives_map.
  Added dead guard.
- **Impersonation detection — dead victims received knowledge/objectives/honor. FIXED.**
  `_process_impersonation_detection()` checked `victim == null` but not dead.
  Dead victims received knowledge entries, INVESTIGATE_THREAT objectives, and
  DUPED_DISLOYAL honor changes. Added dead guard.
- **supply_status_check events accumulate without dedup. FIXED.**
  `_inject_peace_need()` appended seasonal events without checking for existing
  ones of the same type. Other seasonal injection sites (edict_response,
  commitment_honor) all had dedup. Added source check before append.

### Known Code Issues (found and fixed 2026-05-24, JSON table + dead char audit)
- **action_skill_map.json — 4 ActionIDs missing skill entries. FIXED.**
  BRIBE_WITNESS (Temptation), EXTORT_ACCUSED (Intimidation),
  INTIMIDATE_WITNESS (Intimidation), KILL_WITNESS (Stealth) all have
  skill rolls in their executor implementations but were missing from
  action_skill_map.json. NPCs with high relevant skills got no competence
  scoring advantage. Added entries with matching primary/secondary skills.
  3 auto-success ActionIDs (ACCEPT_SEPPUKU, REFUSE_SEPPUKU,
  FLEE_JURISDICTION) correctly have no entry (no skill roll = 0 competence
  modifier is appropriate).
- **_process_witness_testimony_on_arrival — dead magistrate/witness. FIXED.**
  Dead magistrates could receive crime topics via testimony transfer. Dead
  witnesses could transfer topics from their topic_pool. Added
  `CharacterStats.is_dead()` guards for both. 2 tests.
- **_apply_intimidation_consequences — dead witness. FIXED.**
  Dead witnesses could receive -30 disposition penalty and pending
  provocation events. Added dead guard with early return. 1 test.

### Known Code Issues — Deferred (2026-05-24, pipeline gaps)
- **FAVOR_REQUESTED reactive events — FIXED.** INVOKE_FAVOR ActionID (B1)
  creates FAVOR_REQUESTED events in debtor's pending_events. ReactiveDecisions
  routing (previous session fix) delivers them to `_evaluate_favor_response()`.
  `_process_favor_response_writebacks()` in DayOrchestrator handles results:
  HONOR_FAVOR calls `FavorSystem.honor_favor()` (+0.1 honor, resolved=true).
  DECLINE_FAVOR calls `FavorSystem.break_favor()` with co-located witnesses and
  applies consequences via `_apply_favor_breach()` (honor/glory loss, creditor
  disposition drop with floor, witness disposition loss). Dead debtor guard,
  already-resolved guard. 4 tests.
- **ACCEPT_TRAINING reactive events — FIXED.** MENTOR executor now injects
  ACCEPT_TRAINING reactive events into student's pending_events.
  `reactive_type` events now route through ReactiveDecisions in the NPC
  wave resolver. Full training pipeline wired (s48 progress bars).
- **MENTOR executor — FIXED.** Full validation (co-location, rank gap),
  reactive event injection, progress application via
  `NPCAdvancement.resolve_training_session()`. Student AP deduction on
  acceptance. Metadata population selects best co-located student.
- **COURT_INVITATION reactive events — FIXED.** SEND_INVITATION now
  injects COURT_INVITATION reactive event into invitee's pending_events
  after `_apply_court_invitation()` succeeds. Prestige read from
  CourtSessionData. ReactiveDecisions._evaluate_court_invitation()
  evaluates: prestige >= 3 or disposition >= 15 → attend, Rei always
  attends, Ishi declines low-prestige. ATTEND_COURT response creates
  primary objective (need_type=ATTEND_COURT, target_settlement_id,
  source=court_invitation). DECLINE_INVITATION creates no objective
  (commitment still applies — declining the invitation doesn't cancel
  the social obligation). Winter Court invitations are excluded
  (Imperial summons are automatic). 3 tests.

### Known Code Issues (found and fixed 2026-05-24, multi-system audit)
- **WinterCourtSystem.record_emperors_peace_violation() — dead attendees as witnesses. FIXED.**
  Witness collection loop iterated `court.attendee_ids` without
  `CharacterStats.is_dead()` check. Dead attendees were included as witnesses
  in Emperor's Peace violation CrimeRecords. Added character lookup and dead
  guard. 1 test.
- **WinterCourtSystem.compute_glory_rewards() — dead host daimyo receives glory. FIXED.**
  `host_lord_id` was checked `>= 0` but never verified alive. Dead host daimyos
  received GLORY_HOST_FAMILY_DAIMYO reward. Added character lookup and dead guard.
  1 test.
- **WinterCourtSystem personal candidate filter — tautological condition. FIXED.**
  `emperor.knowledge_pool.size() > 0` was OR'd with `met_characters` check,
  making virtually all characters personal invitation candidates once the emperor
  had any knowledge at all. Removed the tautological branch; now only `met_characters`
  gates personal candidacy. 1 test.
- **BoundEscapeSystem.free_ally_chains() — tautological noise_level ternary. FIXED.**
  `NoiseLevel.MODERATE if success else NoiseLevel.MODERATE` returned MODERATE
  regardless of success/failure. Failed force attempts (chains not broken) should
  produce QUIET noise. Changed failure branch to `NoiseLevel.QUIET` with
  `QUIET_NOISE_RANGE`. 1 test.
- **InformationSystem.transfer_objective_knowledge() — dead contacts transferred. FIXED.**
  Contact transfer loop in `known_contacts_by_clan` iterated without
  `CharacterStats.is_dead()` check. Dead characters were added to recipient's
  contact network. Added null and dead guard. 1 test.
- **ObjectiveProgress.evaluate_all_objectives() — dead characters evaluated. FIXED.**
  Iterated full characters array without dead guard. Dead characters had their
  primary objectives evaluated and `TravelCommitment.update_progress()` called,
  unnecessarily mutating their objectives_map. Added dead guard. 1 test.

### Known Code Issues (found and fixed 2026-05-24, magic number audit)
- **ProvinceStatus.confidence raw int comparisons — 7 sites. FIXED.**
  `ps.confidence == 0` / `= 2` used across objective_decomposer.gd (3 sites),
  province_triage.gd (3 sites), npc_decision_engine.gd (1 site). Added
  CONFIDENCE_STALE/RECENT/FRESH constants to ProvinceStatus class. All consumers
  and 5 test files updated. 0=stale, 1=recent, 2=fresh scale unchanged (opposite
  ordinal from KnowledgeConfidence — intentional, different system).
- **StarvationStage raw int comparisons — 5 sites. FIXED.**
  `starvation_stage >= 2` / `> 0` / `<= 0` / `= 1` used across
  rice_market_system.gd (3 sites), insurgency_system.gd (1 site),
  spiritual_insurgency_system.gd (1 site), npc_decision_engine.gd (2 sites).
  All replaced with ResourceTick.StarvationStage enum references. 1 test updated.

### Known Code Issues (found and fixed 2026-05-24, topic tier numbering audit)
- **Topic tier numbering mismatch across legal pipeline — 4 systems. FIXED.**
  CONVICTION_CONSEQUENCES table was migrated to TopicData.Tier enum (TIER_1=0,
  TIER_2=1, TIER_3=2, TIER_4=3) but three downstream systems still used raw
  1-4 ints. ExtraditionSystem.SEVERITY_TIER_PRESSURE keyed by {1:-30, 2:-15,
  3:-5, 4:0} — TIER_1 crimes (maho, emperor's peace) received 0 pressure
  instead of -30. SentencingSystem.TOPIC_TIER_PRESSURE same pattern — TIER_1
  crimes got 0 pressure instead of -30. InvestigationSystem.TIER_MAP and
  TOPIC_INITIAL_MOMENTUM keyed by 1-4 — TIER_1 (value 0) missed all lookups.
  `_extrad_crime_tier()` treated TIER_1=0 as "no tier" and returned 4. All
  tables re-keyed by TopicData.Tier enum. TIER_MAP removed (direct cast).
  conviction_processor now passes actual crime tier to sentencing (was 0).
  `select_punishment` default changed from 0 to -1. 3 test files updated.
- **Extradition `<= 2` comparisons — wrong threshold after enum migration. FIXED.**
  `get_cooperation_disposition_reward()`, `get_refusal_disposition_penalty()`,
  and `can_petition_emerald_champion()` used `crime_topic_tier <= 2` which in
  the old 1-4 system meant "tier 1 or 2" but in the enum system (0-3) meant
  "TIER_1, TIER_2, or TIER_3." Changed to `<= TopicData.Tier.TIER_2`.
  `escalated_tier: 3` raw int → `TopicData.Tier.TIER_3`.

### Known Code Issues (found and fixed 2026-05-24, enum and guard audit)
- **FugitiveExtraditionSystem raw 1-4 tier keys — same bug class as above. FIXED.**
  `CRIME_SEVERITY_COOPERATION` keyed by raw {1:-30, 2:-15, 3:-5, 4:0} but
  callers now pass TopicData.Tier enum values (0-3). TIER_1 crimes (maho)
  received 0 severity pressure instead of -30. `<= 2` comparisons in
  `get_cooperation_consequences()` and `get_refusal_consequences()` matched
  TIER_3 (shouldn't). `IMPERIAL_WARRANT_SEVERITY_THRESHOLD = 2` matched
  TIER_3 — imperial warrants available for minor crimes. All re-keyed.
  1 test file updated.
- **feasibility_ledger tether_state == 0 — raw int enum comparison. FIXED.**
  Two sites in `assess_army_supply()` compared tether_state against raw `0`
  instead of `SupplyTetherSystem.TetherState.SOLID`.
- **conviction_processor — dead accused/lord not skipped. FIXED.**
  `process_accused_cases()` checked `accused == null` and `lord == null`
  but not `CharacterStats.is_dead()`. Dead characters could be tried and
  sentenced.
- **investigation_system — dead witness candidates ranked. FIXED.**
  `prioritize_witnesses()` iterated candidate IDs without dead guard. Dead
  characters could be ranked as witness candidates.
- **world_generator — glory assignment unclamped. FIXED.**
  `c.glory = 1.0 + (insight_rank - 1) * 0.5` was not clamped to [0.0, 10.0].
  Honor line immediately above was already clamped.

### Known Code Issues (found and fixed 2026-05-25, NPC wave resolver audit)
- **Court batching completely non-functional — court_id never injected. FIXED.**
  `_partition_by_court()` read `ws.get("court_id", "")` but `_set_court_context_flags()`
  never wrote `court_id` to per-character world_states. All NPCs went into `non_court`
  regardless of court attendance. Court batching (s55.13: "all NPCs at the same court
  resolve as a group before others") was completely inert. Added
  `ws["court_id"] = court.court_id` to `_set_court_context_flags()`, added to stale key
  clearing, updated `_partition_by_court()` to use int keys (was String). 2 tests.
- **reactive_type events silently discarded during AP waves. FIXED.**
  `_consume_reactive_event()` treated `reactive_type` events (DUEL_CHALLENGE_RECEIVED,
  ACCEPT_TRAINING, FAVOR_REQUESTED, COURT_INVITATION) as "unprocessable" and discarded
  them when NPCs entered the AP wave with remaining pending_events. Events in position 1+
  were lost. Now preserves `reactive_type` events for next day's reactive phase. 2 tests.

### Known Code Issues (found and fixed 2026-05-24, DayOrchestrator writeback audit)
- **Duel response writeback ordering — crime detection ran before duel resolution. FIXED.**
  `_process_duel_response_writebacks()` ran at line 650 AFTER `_process_crime_detection()`
  at line 253. Resolved duels with `requires_crime_creation: true` were appended to the
  results array AFTER crime detection had already scanned it. Unsanctioned duel deaths
  never created CrimeRecords. Moved both duel writebacks to run before crime detection.
- **held_leverage missing favor_id — INVOKE_FAVOR always failed. FIXED.**
  `_populate_court_availability_data()` built held_leverage entries without `favor_id`
  field. `_pick_best_favor_to_invoke()` always returned `favor_id: -1`, making
  INVOKE_FAVOR executor always fail. Added `favor_id: f.favor_id` and `f.resolved`
  filter to exclude already-resolved favors. 2 tests.
- **Dead character guards (11 writeback functions). FIXED.**
  `_apply_favor_breach()` debtor, `_process_eavesdrop_writebacks()` eavesdropper,
  `_process_shadow_target_writebacks()` shadow, `_process_observe_attendees_writebacks()`
  observer, `_process_intelligence_info_writebacks()` actor and target,
  `_compute_positions_from_conversations()` both participants,
  `_compute_positions_from_broadcast()` character,
  `_compute_positions_from_letters()` recipient,
  `_process_court_action_effects()` charmer (false courtesy honor). All had null
  guards but no `CharacterStats.is_dead()` check. Dead characters received
  knowledge entries, glory/honor changes, topic positions, and disposition
  mutations. 6 tests.

### Known Code Issues (found and fixed 2026-05-25, ContextSnapshot population)
- **escalating_conflicts — ContextSnapshot field never populated. FIXED.**
  `_extract_escalating_conflicts()` filters active_topics for MILITARY/POLITICAL
  topics with conflict-related topic_type (war_preparation, military, civil_war,
  border_dispute) and unresolved state. Excludes clans already at war.
  `_filter_escalating_conflicts_for_clan()` further removes clans that the
  character's own clan is actively fighting (already covered by active_wars).
  Output: Array of `{"topic_id": int, "clan": String}`. Consumers now
  functional: strategic_review WAR_READINESS directive, objective_decomposer
  PREVENT_WAR and INITIATE_WAR_CHECK routing. 5 tests.
- **known_clan_strengths — ContextSnapshot field never populated. FIXED.**
  Computed from companies array by summing `current_health` per clan.
  Output: `{"Crab": 150.0, "Lion": 200.0, ...}`. Consumers now functional:
  objective_decomposer MILITARY_DOMINANCE decomposition (my_strength vs
  strongest_rival ratio), opportunity_scanner BUILD_STRONGEST_FORCE trigger
  (fires when rival > own * 1.3). 1 test.
- **sublocation — ContextSnapshot field never populated. FIXED.**
  Mapped from `context_flag`: AT_COURT → Enums.Sublocation.COURT, all others
  → Enums.Sublocation.PUBLIC. Zone-level sublocation (PRIVATE, RESTRICTED)
  remains blocked on zone system data — will require zone_subtype mapping
  when implemented. Consumer now functional: `would_cause_public_scene`
  personality filter correctly distinguishes court from public contexts.
  2 tests.

### Known Code Issues (found and fixed 2026-05-25, compile and runtime audit)
- **ActionExecutor._compute_atonement_effects() — `character` undefined. FIXED.**
  Referenced `character` instead of `_character` (the actual parameter name).
  PUBLIC_ATONEMENT always crashed at runtime. Changed to `_character`.
- **ActionExecutor TRANSFER_KOKU — characters_by_id out of scope. FIXED.**
  `_execute_transfer_koku()` requires `characters_by_id` but was called from
  `_compute_admin_effects()` where the parameter is not in scope. Moved to
  early-return handler in `execute()` (same pattern as APPLY_TATTOO).
- **ActionExecutor MENTOR — characters_by_id out of scope. FIXED.**
  Same pattern as TRANSFER_KOKU. `_execute_mentor()` requires `characters_by_id`
  but was called from `_compute_self_effects()`. Moved to early-return handler.
- **DayOrchestrator BROKEN_LATE_NOTICE — enum value doesn't exist. FIXED.**
  Line 5678 referenced `CommitmentData.CommitmentStatus.BROKEN_LATE_NOTICE`
  which doesn't exist. Changed to `BROKEN_WITH_NOTICE`.
- **DayOrchestrator `ic_day` undeclared in _process_lord_deaths. FIXED.**
  Line 6383 used `ic_day` but the parameter name is `current_tick`.
- **WorldStateSaver typed array assignment — all loads silently failed. FIXED.**
  All 34 typed array assignments in `load_world()` and `_load_json_state()`
  used direct assignment (`ws.field = array`) which fails at runtime when
  assigning untyped `Array` to typed `Array[T]` (e.g. `Array[L5RCharacterData]`).
  Changed all to `.assign()` method. Dictionary fields kept direct assignment.
  World state was never actually loading from saves — every restart started
  fresh despite save files existing on disk.

- **NPC scoring tables never loaded from JSON — entire decision engine non-functional. FIXED.**
  `scoring_tables`, `filter_data`, and `action_skill_map` on WorldStateData were
  declared as `{}` but never populated from the 8 JSON files under
  `systems/npc_engine/data/tables/`. The NPC decision engine received empty tables
  at runtime, meaning: (1) `_compute_competence_modifier()` returned 0 for all
  actions (skill-based scoring disabled), (2) `_apply_personality_filter()` blocked
  nothing (personality-based action gates disabled), (3) `_compute_urgency_bonus()`
  added nothing (crisis response disabled), (4) `_get_objective_alignment()` returned
  0 for all actions (objective-action matching disabled). NPCs chose actions
  essentially at random. Added `_load_npc_scoring_tables()` to `WorldStateData._ready()`
  which loads all 8 JSON files: objective_alignment (94 NeedTypes), personality_lean
  (14 virtues), competence_table (11 skill ranks), disposition_tiers (8 tiers),
  urgency_rules (9 rules), topic_position_alignment (26 topics), action_skill_map
  (125 ActionIDs), personality_filter (2 categories: bushido/shourido). Added
  `_load_json()` static helper with error reporting.
- **character_province_map permanently empty — topic broadcasting broken. FIXED.**
  `character_province_map` was declared as `{}` on WorldState and passed to
  `advance_day()` but never populated by anyone — not the world generator,
  not the day orchestrator, not the save/load system. Every `.get(char_id, -1)`
  returned -1, breaking: (1) Topic broadcasting below UNAVOIDABLE tier — characters
  at BROADCAST_MAJOR/SECONDARY/MINOR tiers never received province-based topics,
  (2) PTL detection province lookups (had fallback to `target_province_id` so
  partial impact), (3) Crime detection province context. Built population loop
  at start of `advance_day()`: iterates living characters, maps `physical_location`
  (String settlement ID) through settlement-province map to province ID. Clears
  and rebuilds each day. 2 tests.
- **Stale context flags: is_patrolled, phoenix_champion_authority. FIXED.**
  Both flags are conditionally set in per-character world_states but were
  not erased between days by `_clear_stale_context_flags()`. If the
  condition stopped applying (character left patrol, Phoenix Champion
  lost authority), the flag persisted from yesterday.
- **Commitment renege topic created with invalid tier -1. FIXED.**
  CommitmentRegistry consequence tables use `topic_tier: -1` to signal
  "no topic should be created" for mitigated broken commitments
  (BROKEN_WITH_NOTICE tiers 3 and 2, BROKEN_WITH_PROXY all tiers,
  BROKEN_FORCE_MAJEURE tiers 3 and 2). `_process_commitment_seasonal()`
  did not guard against this sentinel and created TopicData objects with
  `tier = -1` (invalid enum value). Added `topic_tier >= 0` guard to
  skip topic creation entirely when the consequence table says no topic
  is needed. 1 test.
- **Seasonal death processing results silently discarded. FIXED.**
  `_process_lord_deaths()` and `_process_operational_death_cascade()`
  called during seasonal phase (natural deaths from gempukku) assigned
  results to local variables (`seasonal_orphan_results`,
  `seasonal_cascade_results`) that were never used. The functions apply
  their effects correctly (succession, orphaned objectives, hierarchy
  cascade), but the result metadata was lost from advance_day()'s return
  dict. Now appends seasonal results to the daily `orphan_results` and
  `hierarchy_cascade_results` arrays.

### Known Technical Notes
- **AT_TEMPLE / AT_WALL_TOWER context — WIRED (verified 2026-06-14).** These two
  single-purpose settlement contexts set BOTH `context_flag` AND `zone_subtype` in
  per-character world_states, so the ZoneFlagMatrix gates actions there.
  `_set_temple_context_flags` keys on RELIGIOUS_SETTLEMENT_TYPES → TEMPLE_GROUNDS;
  `_set_wall_tower_context_flags` → WALL_TOWER. Runtime-verified: a monk at a temple gets
  AT_TEMPLE + TEMPLE_GROUNDS → PERFORM_RITUAL/performance allowed. These are correct because
  the settlement IS single-purpose (a temple is religious grounds; a wall tower is a tower).
- **AT_DOJO — intentionally NOT assigned at the settlement level (fixed 2026-06-14, see
  Known Code Issues below).** `has_dojo` settlements are multi-zone CASTLES (champion seats +
  Imperial Capital), and a dojo is one of their Lesser Zones — so the former settlement-level
  blanket was a bug (stripped governance/court/worship). The multi-zone contexts
  (AT_OWN_HOLDINGS / AT_COURT / VISITING) intentionally leave `zone_subtype` unset so those
  actions are NOT zone-gated — a character at a castle could be in any of its zones (shrine,
  garden, chashitsu, dojo), so gating to one sub-zone would wrongly block supported actions.
  AT_DOJO is reserved for future per-character zone-position tracking (a PC standing in the
  dojo zone); the AT_DOJO context list + decomposer branches remain as forward-wiring.
- **ON_CAMPAIGN, UNDER_SIEGE, IN_EXILE context flags unassigned.** These require sub-tile army position tracking from s11.7a. Characters in these states currently fall through to AT_OWN_HOLDINGS or VISITING. Implement when army movement data is available.
- **Unbounded array growth.** `crime_records`, `pending_letters`, `active_secrets` grow monotonically. Retention window design decisions needed before adding automatic purges beyond the existing seasonal cleanups.

### Systems Added 2026-05-23
- **s55.11b Named Monk Standing Objectives** — `simulation/monk_objective_system.gd`.
  Five standing objective types: HELP_PEOPLE (RAISE_DISPOSITION), FIGHT_BANDITS
  (INVESTIGATE_THREAT/PATROL_PROVINCE), MEDITATE_DEEPLY (PERFORM_RITUAL),
  TRAIN_MASTERY (TRAIN_SKILL), WORSHIP_KAMI (PERFORM_RITUAL). School-based
  standing selection with personality override: 6 sohei schools default to
  FIGHT_BANDITS, 6 contemplative schools default to MEDITATE_DEEPLY, 6 social
  schools default to HELP_PEOPLE. Fortunist devotion schools with Chugi/Rei
  virtue lean to WORSHIP_KAMI. Unclassified schools fall through to pure
  personality routing. Decomposition trees for all 5 types with context flag
  routing (AT_TEMPLE, AT_OWN_HOLDINGS, AT_COURT, AT_DOJO, TRAVELING). Monk
  self-selection: `select_primary_from_standing()` scans world state for
  matching opportunities (famine provinces, insurgencies, temples, dojos) and
  produces primary objectives. 5 type-specific opportunity scanners produce
  OpportunityScanner.Opportunity objects with personality-fit scoring.
  Wired into DayOrchestrator: `_assign_monk_standing_objectives()` assigns
  standing objectives to monk characters daily (alongside magistrate
  assignment), `_process_monk_self_selection()` runs seasonally (alongside
  lord strategic review). Already integrated into ObjectiveDecomposer routing
  (line 76). Monk standing types added to OpportunityScanner.STANDING_OBJECTIVE_DOMAIN.
  83 tests.
- **s56.16 Spiritual Insurgency Trigger Layer** — `simulation/spiritual_insurgency_system.gd`,
  `shared/spiritual_insurgency_data.gd`. Trigger-only implementation (ASCII map encounters
  blocked on s56 quest system). Detects worship failure thresholds from Kami Worship
  System (s4.3.21): 2+ Great Fortunes at Displeased triggers spiritual insurgency.
  Two event types: REALM_OVERLAP (6 realms weighted by province conditions — famine
  biases Gaki-do +30, battle biases Toshigoku +25, forest biases Chikushudo +20,
  intrigue biases Sakkaku +20, population loss biases Meido +25, shugenja surplus
  biases Yume-do +15) and ELEMENTAL_IMBALANCE (5 elements, equal probability).
  Four severity tiers: MILD (2 displeased, 1 event/season), MODERATE (3 displeased,
  2 events/season), SEVERE (4+ displeased or any wrathful, 3 events/season),
  CATASTROPHIC (5+ wrathful, 4 events/season). Mass battle casualties (50+ PU)
  directly trigger Gaki-do/Toshigoku overlap regardless of worship state (60/40
  split). NPC resolution: shugenja rolls Theology + realm/element-specific trait
  vs severity-based TN (15/20/25/30). Margin-based resolution: full (margin 15+),
  partial (margin 5+), retreat (margin -10+), failure (margin <-10). Honor/glory
  gains on success. Topic generation: TIER_3 for MILD, TIER_2 for MODERATE,
  TIER_1 for SEVERE/CATASTROPHIC. Elemental counter pairs per GDD s56.16.5d:
  Fire→Water, Water→Earth, Earth→Fire, Air→Earth, Void→any. Ritual rounds per
  severity: 10/20/30/50. Wired into DayOrchestrator seasonal block:
  `_process_spiritual_insurgency()` runs after standard insurgency processing,
  increments seasons on active events, generates new events from worship state,
  creates topics, resolves via best available shugenja in province. Resolved
  events removed from active list. Persistent state: `spiritual_insurgency_events`
  and `next_spiritual_event_id` on WorldState, saved/loaded via WorldStateSaver
  (Resource array pattern). DiceEngine gains `randf()` convenience method.
  73 tests.
- **s56.14 Bloodspeaker Cult Network** — `simulation/bloodspeaker_network_system.gd`,
  `shared/bloodspeaker_cell_data.gd`. Empire-wide persistent cult cell network per
  GDD s56.14. Four cell states: DORMANT, ACTIVE, PROPAGATING, DESTROYED (enum on
  Enums). BloodspeakerCellData Resource with cell_id, province_id, state, strength,
  concealment, leader_id, parent_cell_id, establishment_path (4 paths: AGENT_INFILTRATION,
  PTL_CORRUPTION, NAMED_NPC_FALL, ARTIFACT_DISCOVERY), season_created, seasons_dormant,
  seasons_active, insurgency_id, propagation_count. `cult_affiliation: bool` field
  added to L5RCharacterData. World generation: 25-35 cells at game start, 75-80%
  dormant, placement weighted by population, urban centers, Shadowlands proximity,
  low garrison. Active cells start at strength 2-4 with concealment 8. Leader selection
  via Kolat-pattern weighted tiers (susceptibility 6+: weight 5, 4-5: weight 2,
  3: weight 1). Leaders get cult_affiliation flag. Five activation triggers:
  PTL 3+ (20%/season), Volatile/Broken stability (15%/season), named NPC maho
  (automatic), instruction from propagating cell (checked before new-cell creation),
  passage of time (2% base). Propagation: 10% chance at strength 4+, prefers
  activating existing dormant cells (instruction path), falls back to creating new
  dormant cells at 3+ province distance in different clan territory. Parent loses
  1 strength on propagation. Target selection weighted by same criteria as world
  generation. Hydra Rule on suppression: <4 seasons = no check, 4-7 = 60% chance,
  8+ = 90% chance of spawning a hidden dormant cell. Sleeper aftermath: +15% per
  cult-affiliated character in province (caps at +30%). Dormant PTL contribution:
  +0.25/season per dormant cell (s56.14.6). Active cells feed into InsurgencySystem
  (s11.11 MAHO_CULT) for detection, growth, and suppression. DayOrchestrator wiring:
  `_process_bloodspeaker_network()` runs seasonally after insurgency processing.
  Detects suppressed cells by comparing active cell insurgency_ids against surviving
  insurgencies array. PTL contributions applied to ProvinceData. Maho province
  detection: shugenja with taint 2+ triggers automatic activation. Topic generation
  on cell activation (TIER_3 POLITICAL). Persistent state: `bloodspeaker_cells` and
  `next_cell_id` on WorldState, saved/loaded via WorldStateSaver (Resource array
  pattern). 60 tests. LIMITATION: eta community weight declared but not applied
  (no eta field on ProvinceData/SettlementData). Cell-level roster composition and
  ASCII map encounter design deferred per GDD s56.14.7.

### Known Code Issues (found and fixed 2026-05-22, SecretSystem audit)
- **expose_publicly() disposition applied to dead witnesses. FIXED.**
  `expose_publicly()` iterated witness_ids and checked `w != null` but not dead.
  Dead witnesses received disposition changes toward the secret's subject. Added
  `CharacterStats.is_dead(w)` guard. 1 test.

### Known Code Issues (found and fixed 2026-05-22, EffectApplicator audit)
- **Disposition ripple applied to dead clan members. FIXED.**
  `_apply_disposition_ripple()` iterates all characters matching target's clan
  without a dead check. Dead clan members accumulated meaningless disposition
  changes. Added `CharacterStats.is_dead(c)` guard. 1 test.
- **Recipient effects applied to dead recipients. FIXED.**
  `_apply_recipient_effects()` checked `recipient == null` but not dead.
  Dead recipients of gifts/social actions received disposition changes.
  Added dead guard. 1 test.

### Known Code Issues (found and fixed 2026-05-22, CommitmentRegistry audit)
- **apply_consequences() creditor disposition applied to dead creditor. FIXED.**
  `apply_consequences()` checked `creditor != null` but not dead. Dead creditors
  accumulated meaningless disposition changes toward the debtor. Added
  `CharacterStats.is_dead(creditor)` guard. 1 test.
- **apply_consequences() witness disposition applied to dead witnesses. FIXED.**
  Same pattern — `witness == null` check but no dead guard. Dead witnesses
  received disposition penalties from broken commitments. Added
  `CharacterStats.is_dead(witness)` guard. 1 test.
- **topic_tier values in CONSEQUENCE_TABLE — dead data (not a bug).**
  Raw int `topic_tier` values (4, 3, 2, -1) exist in the consequence table
  but are never consumed. Topic creation in `_process_commitment_deadlines()`
  uses commitment tier, not consequence topic_tier. Documented, not removed
  (may be consumed by future topic generation).

### Known Code Issues (found and fixed 2026-05-22, DayOrchestrator audit)
- **Grand Ritual master lookup — enum IDs used as character IDs. FIXED.**
  `_find_living_elemental_masters()` returns PhoenixCouncil.Master enum values
  (FIRE=0, WATER=1...), not character IDs. Line 12340 fed these directly into
  `characters_by_id.get(mid)`, which never found any match. Grand Ritual always
  had zero masters, making it ineffective. Changed to call
  `_find_master_character(mid, characters_by_id)` which scans by role_position.
  1 test.
- **Succession topic missing tier/category/ic_day_created from topic_dict. FIXED.**
  `generate_succession_topic()` returned tier, category, subject_ids but the
  orchestrator never read them. Topic always got default TIER_4/PERSONAL.
  Disputed successions (TIER_2/POLITICAL) were incorrectly created as minor
  personal topics. Also fixed raw int tier values in SuccessionSystem to use
  TopicData.Tier enum. 1 test.
- **`c.primary_virtue` — nonexistent field on L5RCharacterData. FIXED.**
  Military promotion candidate gathering at line 8312 referenced
  `c.primary_virtue` which doesn't exist. Changed to `c.bushido_virtue`.
- **`_topic_from_dict` missing title read. FIXED.**
  All topics created via this helper (court close, edict, war end, Winter Court
  announcement) had blank titles. Added `t.title = topic_dict.get("title", "")`.
  1 test.
- **Dead character guards (12 functions). FIXED.**
  `_get_witnesses_at_location`, `_apply_cohabitation`,
  `_process_arrival_observation`, `_apply_war_disposition_penalty` (both loops),
  `_process_supply_status_checks`, `_find_clan_lord`, `_find_bodyguard`,
  `_attempt_proxy_dispatch`, `_process_seasonal_stipend_disposition` (retainer
  and lord), `_create_stipend_failure_topics`,
  `_apply_garrison_courtier_refusal_writebacks`. Dead characters could be
  selected as witnesses, bodyguards, proxies, clan lords; could accumulate
  cohabitation days, disposition changes, and stipend topics. 4 tests.
- **Dead `recipient_loc` variable in VISIT_PROMISE creation. FIXED.**
  Declared but never used. Removed.

### Known Code Issues (found and fixed 2026-05-22, ActionExecutor audit)
- **INTIMIDATE failed effects silently dropped — `effects["failed"]` missing. FIXED.**
  `_execute_intimidation()` set `honor_change` (Low Skill penalty from Table 2.3)
  and `infamy_gain` unconditionally in the effects dict, but never set
  `effects["failed"] = true` on failure. EffectApplicator line 27 early-returns
  when `success==false` and no `"failed"` key exists — so failed intimidation's
  Low Skill honor cost, infamy, and witness_disposition_loss were all silently
  dropped. Added `effects["failed"] = true` when `not r["success"]`. 2 tests.
- **DISPATCH_COURTIER `recipient_disposition_change` type mismatch. FIXED.**
  Lines 1807/1831 used float literals (2.0, -2.0) for `recipient_disposition_change`.
  EffectApplicator reads the key into `var disp_change: int`. GDScript implicit
  conversion is correct (2.0 → 2) but the type annotation mismatch could cause
  issues in strict mode. Changed to int literals (2, -2).

### Known Code Issues (found and fixed 2026-05-22, NPCDecisionEngine audit)
- **knowledge_pool aliasing in build_context() — mutation leaked to character. FIXED.**
  `ctx.knowledge_pool = character.knowledge_pool` assigned a direct reference.
  Unlike `topic_pool`, `skills`, `disposition_values`, and `met_characters`
  (all `.duplicate()`), knowledge_pool had no copy. Any engine code modifying
  `ctx.knowledge_pool` (filtering, appending) would mutate the character's
  persistent data. Added `.duplicate()`. 1 test.
- **Dead characters in _collect_vassal_stockpiles() — phantom resources. FIXED.**
  Iterated `characters_by_id` without `CharacterStats.is_dead()` check. Dead
  vassals contributed phantom rice/arms stockpiles to lord's feasibility
  calculations, inflating perceived resource availability. Added dead guard.
  1 test.
- **Dead characters in _collect_allied_surplus() — phantom allied surplus. FIXED.**
  Same pattern as vassal stockpiles. Dead allied lords contributed phantom
  surplus rice/koku to inter-clan aid calculations. Added dead guard. 1 test.
- **_pick_levy_province() unchecked cast — potential crash on non-typed entries. FIXED.**
  `(ps as NPCDataStructures.ProvinceStatus)` cast without type guard. If
  `province_statuses` contained non-ProvinceStatus entries, the cast would
  produce null and crash on `.province_id` access. Added
  `if not ps is NPCDataStructures.ProvinceStatus: continue`. 2 tests.
- **_pick_gossip_subject() self-selection — NPC could gossip about themselves. FIXED.**
  Iterated `ctx.disposition_values` without excluding `ctx.character_id`. If
  the NPC had negative self-disposition (edge case from modifier stacking),
  they could select themselves as gossip target. Added
  `if int(cid) == ctx.character_id: continue`. 2 tests.
- **Dead forgery_rank variables in forge metadata helpers. FIXED.**
  `_build_forge_letter_metadata()` and `_build_forge_order_metadata()` both
  declared `var forgery_rank: int = ctx.skill_ranks.get("Forgery", 0)` but
  never used it. Authority level comes from `_forge_authority_from_lord_rank()`.
  Removed both dead variables.

### Systems Added 2026-05-24
- **s48 MENTOR training pipeline — full wiring.** MENTOR executor validates
  co-location, sensei rank > student rank, both alive. Returns reactive event
  injection data. `_process_mentor_writebacks()` injects ACCEPT_TRAINING
  reactive event into student's `pending_events`. Next tick, reactive event
  routes through `ReactiveDecisions._evaluate_training_response()` which
  personality-gates acceptance: Kanpeki requires rank gap 2+, Ketsui
  requires lord-assigned MENTOR_CHARACTER objective. On acceptance,
  `_process_training_acceptance_writebacks()` calls
  `NPCAdvancement.resolve_training_session()` for progress bar advancement
  (100 progress at rank gap 2+, 75 at gap 1, 25 sensei self-gain) and
  deducts 1 AP from student. Metadata population:
  `_build_mentor_metadata()` selects best co-located student with positive
  disposition and largest rank gap via `_pick_mentor_skill()`. MENTOR added
  to TRAIN_SKILL NeedType (score 80). 14 tests.
- **ReactiveDecisions routing fix.** `reactive_type` events in
  `pending_events` now route through `ReactiveDecisions.evaluate_reactive_event()`
  instead of `NPCDecisionEngine.run()` (which silently discarded them via
  `_decompose_reactive_event()` returning null). Fixes: ACCEPT_TRAINING
  (new), FAVOR_REQUESTED (was dead since injection), COURT_INVITATION
  (was dead since injection). Wired in both `_resolve_reactive_events()`
  and `_resolve_reactive_events_full()`.
- **FAVOR_REQUESTED writeback pipeline.** `_process_favor_response_writebacks()`
  in DayOrchestrator scans reactive results for HONOR_FAVOR / DECLINE_FAVOR.
  HONOR_FAVOR: calls `FavorSystem.honor_favor()` (resolved=true, +0.1 honor
  via HonorGlorySystem). DECLINE_FAVOR: calls `FavorSystem.break_favor()`
  with co-located witnesses, then `_apply_favor_breach()` for honor/glory loss,
  creditor disposition with floor, witness disposition loss. Guards: dead debtor,
  already-resolved favor, missing favor_id. Full pipeline: INVOKE_FAVOR action
  → invoke_favor() sets deadline → pending_event injection → next-tick reactive
  routing → personality evaluation → writeback → resolution. 4 tests.
- **COURT_INVITATION writeback pipeline.** `_inject_court_invitation_event()`
  fires after successful SEND_INVITATION, injects COURT_INVITATION reactive
  event with host_id, settlement_id, court_id, prestige (from CourtSessionData).
  `_process_court_invitation_response_writebacks()` handles results:
  ATTEND_COURT creates primary objective (ATTEND_COURT, target_settlement_id,
  source=court_invitation, assigned_by=host). DECLINE_INVITATION creates no
  objective. Full pipeline: SEND_INVITATION → _apply_court_invitation →
  reactive event injection → next-tick ReactiveDecisions → personality
  evaluation → travel objective writeback. 3 tests.
- **vengeance_targets / bitter_rivals population.** Two builder functions
  populate world state keys read by OpportunityScanner. `_build_vengeance_targets()`
  scans objectives_map for AVENGE_DEATH (String format from assassination system)
  and historical_modifiers for FAMILY_VENGEANCE_DISPOSITION entries. Dead targets
  filtered. `_build_bitter_rivals()` scans lord's disposition_values for entries
  at ENEMY tier or worse (disposition <= -31). Blood enemies get urgency 70
  (vs 50 for enemies). Dead targets filtered. Both wired into
  `_run_strategic_reviews()` alongside trainable_vassals, erased after use.
  5 tests.
- **Duel challenge reactive pipeline.** ISSUE_DUEL_CHALLENGE refactored from
  single-tick synchronous resolution to two-tick reactive flow per GDD s55.11.
  Phase 1: `_execute_duel_challenge()` returns challenge-issued result with
  `injects_reactive_event: true`. `_process_duel_challenge_writebacks()` injects
  DUEL_CHALLENGE_RECEIVED into defender's `pending_events`. Phase 2 (next tick):
  `ReactiveDecisions._evaluate_duel_response()` personality-gates acceptance
  (Yu/Kyoryoku/rivals always accept, Meiyo accepts public, Ishi accepts, public
  bushido accepts). `_process_duel_response_writebacks()` handles results:
  DECLINE_DUEL applies -0.3 glory. ACCEPT_DUEL calls
  `ActionExecutor.resolve_accepted_duel()` (full resolution: stare-down,
  assessment, concession, focus, strike) and appends wrapped result to results
  array for downstream writebacks (duel death, duel honor). Existing executor
  tests updated from synchronous `_execute_duel_challenge` to
  `resolve_accepted_duel()`. 3 wiring tests + 8 executor tests updated.

### Systems Added 2026-05-26
- **World Bootstrap System (s2.3, s52)** — `simulation/world_bootstrap.gd`. One-time
  world initialization from GDD s2.3.90 province data. Creates all 138 provinces,
  default settlements, and population on first run. PROVINCE_TABLE encodes all
  provinces from the Adjacency Index: name, clan, family, is_coastal, is_island,
  is_ungovernable. ADJACENCY_TABLE maps province names to adjacent province names
  (bidirectional). FAMILY_SEAT_PROVINCES maps each family to its seat province for
  castle placement. TERRAIN_HINTS maps families to TerrainType for PU scaling.
  `bootstrap_world(dice)` creates provinces with terrain-scaled PU, settlements
  (family seats get FAMILY_CASTLE/CASTLE, Toshi Ranbo gets CITY, islands get ports,
  ungovernable Hiruma provinces get no settlements), wires adjacencies, creates
  ClanData, generates population via WorldPopulationGenerator, assigns physical
  locations, and creates initial military companies. Wired into
  SimulationScheduler._bootstrap_fresh_world() which fires when no saved world
  state exists on startup. Fixed missing families in CLAN_FAMILIES (Toritaka,
  Togashi, Agasha, Yogo). Duplicate province names handled with suffixed internal
  names (Sabishii_Dragon, Anshin_Phoenix, Kougen_Phoenix, Garanto_Phoenix,
  Garanto_Unicorn, Kinbou_Scorpion). Deterministic with seed. 22 tests.
- **s49 Artisan & Crafting System** — `simulation/artisan_system.gd`,
  `shared/artisan_item_data.gd`. Core GDD-sourced crafting mechanics only.
  Cost-based TN system: three denomination brackets (zeni 10/15/20, bu
  15/20/25, koku 20/25/30) with over-bracket escalation (+5 per step).
  Six quality tiers: Mundane/Normal/Fine/Exceptional/Masterwork/Legendary
  (TN thresholds 15/25/35/45/55). Material tier system: Common (0 FR),
  Uncommon (+1 FR), Rare (+2 FR), Legendary (+3 FR). Settlement-type
  availability gates (Village=Common only, Town=Common+Uncommon,
  City=up to Rare, Family Castle/Capital=all tiers). Eight clan-specific
  materials (Kaiu Steel, Kakita Paper, Dragon Jade Dust, Matsu Leather,
  Phoenix-blessed Paper, Shadow-silk, Gaijin Dyes, Deep-sea Materials).
  Exceptional weapons: Craft: Weaponsmithing 7+ (5+ for Kaiu/Tsi), cost
  tripled, failure ruins item. Sacred weapons: 7 Raises (6 for Kaiu),
  clan-locked, Legendary quality. Six weapon special qualities
  (Balanced/Signature/Swift/True Quality/Radiant/Unbreakable) with Raise
  costs (2-6). Multi-day crafting: time units (Hours/Days/Weeks) by
  material type + denomination, AP cost = units × AP_per_unit. Provenance
  tracking: creator, creation date, quality, materials, crafting roll
  total. History points: 7 event types (1-3 points each), bonus tiers at
  3/6/10 points (+1/+2/+3 Free Raises). Koku cost: `cost_in_koku()`
  converts denomination to koku (1 koku = 5 bu = 50 zeni). Executor
  `_execute_craft()` resolves crafting rolls and WIP creation. WorldState
  persistence for crafted_items and next_item_id.
  **NPC crafting pipeline removed (2026-05-26):** All NPC-facing wiring
  was invented content not specified in GDD s49. Removed: CRAFT from
  context lists and AP cost dict, CRAFT_ITEM NeedType from
  objective_alignment.json, CRAFT from personality_lean.json and
  action_skill_map.json, NPC selection functions (npc_select_craft_action,
  select_best_material_for_npc, is_artisan_school, is_smith_school),
  inventory bridge (create_inventory_item), history accumulation
  orchestrator functions, WIP context injection and abandonment, standing
  objective assignment, lord-directed crafting, ContextSnapshot fields
  (settlement_type, active_wip_item_id), CLAN_MATERIALS category
  assignments. NPC crafting is non-functional until GDD specifies the
  NPC decision pipeline for crafting. 55 tests (down from 122).

### Invented Content Removal (2026-05-26)
- **s56.16 Spiritual Insurgency — NPC resolution and supporting functions removed.**
  `resolve_npc_event()`, `get_resolution_effects()`, `generate_battle_triggered_event()`
  removed (invented TNs 15/20/25/30, invented honor/glory values 0.3/0.5/0.1/0.2,
  invented battle casualty thresholds 50/100/200 PU, invented 60/40 Gaki-do/Toshigoku
  split). `NPC_RESOLUTION_BASE_TN` dictionary removed. `BASE_REALM_WEIGHTS` and 7
  condition bonus constants removed — select_realm() now uses equal-probability random.
  `_build_province_conditions()` and `_weighted_select()` removed (only existed for
  weighted realm selection). EVENTS_PER_SEASON for MODERATE/SEVERE/CATASTROPHIC removed
  (GDD says "one or two"/"multiple"/"near-permanent" but no counts beyond MILD=1).
  Severity-to-topic-tier mapping removed (GDD does not specify). DayOrchestrator:
  `_resolve_spiritual_events()` and `_find_province_shugenja()` removed.
  `_process_spiritual_insurgency()` simplified to trigger-only (no NPC resolution).
  Topic creation now skips when tier is -1 (sentinel). Tests reduced from 73 to ~45.
- **s56.14 Bloodspeaker Network — placement weights and leader selection removed.**
  All WEIGHT_* constants (BASE, HIGH_POPULATION, ETA_COMMUNITY, SHADOWLANDS_ADJACENT,
  URBAN_CENTER, LOW_GARRISON), URBAN_SETTLEMENT_TYPES, and HIGH_POPULATION_THRESHOLD
  removed. `_compute_province_weights()`, `_weighted_select_provinces()`,
  `_compute_single_province_weight()` replaced with uniform random province selection.
  Leader selection removed entirely: LEADER_SUSCEPTIBILITY_THRESHOLD and LEADER_TIER*
  weights removed, `_select_cell_leader()` removed, `leader_id` set to -1 for all cells.
  `get_sleeper_aftermath_bonus()` rewritten: now uses flat +15%/+30% based on seasons
  since suppression (4/8 season thresholds per GDD), replacing per-character 0.15 capped
  at 0.30. `generate_initial_cells()` and `process_season()` signatures simplified
  (removed characters, characters_by_id, settlements parameters). Tests reduced from
  ~63 to 55.
- **s57.38 Hunt System — 8 interpolated beast stat blocks removed.**
  BEAST_STATS reduced to 2 GDD-confirmed species (bear, ozaru). 8 interpolated
  species removed (wolf, boar, stag, fox, ox, goat, cliff_predator, ozutsu_serpent).
  TERRAIN_BEAST_POOLS reduced to FOREST and MOUNTAINS (only pools with available
  beasts). PLAINS, HILLS, COASTAL pools commented out (blocked on s54.1 bestiary).
  generate_beast() fallback changed from "boar" to "bear".
- **s4.8 Individual Combat — 2 invented honor/glory constants removed.**
  HONOR_STRIKING_AFTER_FIRST_BLOOD (-1.0) and GLORY_DECLINE_DEATH_DUEL (-0.5)
  removed. GDD Table 2.3 does not specify these values. concede_at_assessment()
  and resolve_strike_after_first_blood() now return 0.0 for honor/glory changes.

### Invented Content Removal (2026-05-27)
- **s55.29 Travel System — 3 invented values removed/corrected.**
  Hills terrain cost 3→2 (GDD s11.7a says 2). `DEFAULT_TERRAIN_COST` constant
  removed; `_default_travel_time()` returns 1 (was 3). `FORCED_MARCH_MORALE_COST`
  removed and `morale_cost` return key removed from `apply_forced_march()`.
- **s53 War System — 5 invented values removed.**
  `condemn_clan` and `authorize_war` SCORE_SHIFTS entries removed (not in GDD).
  `compute_peace_willingness()` changed from numeric score to qualitative
  Dictionary with `war_score_tier`, `increases`, `decreases` arrays.
  `WAR_DISPOSITION_PENALTY_PER_SEASON` removed; penalty function returns 0.
  Default `get_refusal_honor_cost` changed from -1.0 to 0.0.
- **s53 War Termination — 6 invented values removed.**
  `PEACE_ACCEPTANCE_THRESHOLD` removed. `CEDE_TERRITORY_DISPOSITION`,
  `SURRENDER_HONOR_COST`, `PEACE_NEGOTIATION_HONOR`, `PEACE_STABILITY_BONUS`
  all zeroed. `evaluate_peace_acceptance()` returns qualitative factor comparison.
  Topic momentum values removed from `generate_war_end_topic()`.
- **s55.32 Resource Availability — 3 invented costs corrected.**
  DELIVER_GIFT changed from `inventory_item/1` to `koku/1`. PURCHASE_MARKET
  cost 3→1. OFFER_FAVOR cost 2→1.
- **s55.31 Commitment Registry — invented forgiveness rates removed.**
  FORGIVENESS_RATES_BUSHIDO reduced to 6 entries (removed MAKOTO, NONE).
  FORGIVENESS_RATES_SHOURIDO reduced to 3 entries (removed KETSUI, CHISHIKI,
  KANPEKI, ISHI, NONE). DEFAULT_FORGIVENESS_RATE=0.5 handles missing entries.
- **s57.21 Operational Hierarchy — 2 invented values removed.**
  Removed MEIYO→DAIMYO_BELIEVES_SUBORDINATE (GDD only specifies GI and MAKOTO).
  Removed `daimyo_disposition_loss: -5` and `superior_disposition_loss: -5` from
  DAIMYO_DISMISSES.
- **s11.3.19 Crime Suppression — invented scoring removed.**
  PERSONALITY_PRIORITY reduced to 4 GDD-sourced entries; SHOURIDO_PRIORITY to 1.
  `get_patrol_detection_chances()` returns qualitative Dict instead of numeric
  detection_chance.
- **s57.16 Investigation Decomposer — scoring system replaced with priority ordering.**
  `SCENE_REEXAMINE_EVIDENCE_CAP`, `SCENE_MAX_REEXAMINATIONS`,
  `DAYS_SCENE_STILL_USEFUL` removed. `_select_best_next_action()` numeric scoring
  system replaced with GDD-specified priority ordering: witnesses → suspects →
  alibis → leads. Invented base scores (80/65/55/60), bonuses (+15/+10), and dead
  variables (`evidence_gap`, `days_elapsed`) removed. Co-located targets preferred
  within each category via `_pick_present_first()` helper.
- **s55.12 Information System — invented probe logic gutted.**
  `process_probe_result()` returns `[]` always (action log scanning was invented).
  Stub kept for backward compatibility.
- **s43 Maho System — invented concealment floor removed.**
  Removed `maxi(5, ...)` floor on blood concealment TN; uses raw roll total.
- **s11.11 Insurgency System — 3 invented behaviors removed.**
  Removed `is_patrolled` halving spawn chance. Removed concealment cap of 10 on
  failed detection. `get_crisis_tier()` TAINT_MANIFESTATION uses PTL thresholds
  (9.0→tier 1, 6.0→tier 2) instead of invented strength thresholds.
- **s4.3.17 Feasibility Ledger — 7 invented values corrected.**
  `ALLIED_AID_SIGNIFICANT_FRACTION` 0.30→0.20 (GDD says "more than 20%").
  `SCALE_DOWN_FACTOR` and `SCALE_DOWN_EQUIP_RATIO` zeroed. Iron-to-arms
  conversion `* 0.5` → `* 1.0` (GDD line 479: "1.00 Iron → 1.00 Arms").
  Market purchase 50% fraction removed (GDD does not specify limit).
  `TETHER_HOLD_SEASONS_KETSUI` 2→1 (GDD specifies no personality extension).
  Retreat target scoring formula (rice_per_pu + forge bonus - distance) replaced
  with nearest-province selection. `max_distance` parameter removed. Home Front
  per-PU thresholds documented as structural proxy (starvation_stage not
  available on SettlementData at query point).
- **s55.33 Orphaned Objectives — 1 invented value removed.**
  REPORT_TO_NEW_LORD priority 2→0.
- **s12.2 Disposition System — 2 invented historical modifiers removed.**
  `destroyed_harvest` (start:-20, floor:-20, no decay) and
  `witnessed_harvest_destruction` (start:-10, floor:-5, decay) removed from
  HISTORICAL_EVENTS. Neither appears in GDD s12.2 historical modifier table.
  Day orchestrator harvest destruction path now creates empty modifiers (no-op).
- **s12.7 Letter System — reply constants locked in s12.7a.**
  Previously zeroed during invented-content audit. Now formally locked in
  `gdd/s12.7a_letter_reply_values_locked.md`. Calibrated against GDD-confirmed
  factors (disposition toward sender, Rei virtue, hostile threshold) with
  samurai etiquette baseline and topic-propagation requirements.
  Final values: BASE_REPLY_CHANCE=0.35 (35% at neutral), DISPOSITION_REPLY_BONUS=0.005
  (+0.5%/point), COURTESY_REPLY_BONUS=0.15 (+15% for Rei), HOSTILE_REPLY_THRESHOLD=−10
  (Rival tier onset is −11; below this = no reply), MEETING_ACCEPT_DISPOSITION=0
  (neutral or positive accepts meeting proposals). GAME_OF_LETTERS_REPLY_BONUS=0.02
  PROVISIONAL (no GDD numeric spec for Games: Letters skill modifier).
- **s15.4 Court Action System — 22 constants locked in s15.4a.**
  Previously zeroed during invented-content audit. Now formally locked in
  `gdd/s15.4a_court_action_numeric_values_locked.md`. Calibrated against
  GDD-confirmed anchors: Play a Game (+3), Gossip (−5), Public Debate
  per-witness tiers (±1/±2/±3/±4). NEGOTIATE_POSITION_SHIFT=8.0 and
  PERSUADE_POSITION_SHIFT=12.0 are GDD-confirmed from s15.4 Public Debate
  text ("targeted actions (Negotiate: +8, Persuade: +12)"). Final values:
  CHARM_FULL_GAIN=5, CHARM_RAISE_BONUS=2; NEGOTIATE_BASE_DISP=6,
  NEGOTIATE_RAISE_BONUS=2, NEGOTIATE_POSITION_SHIFT=8.0,
  NEGOTIATE_RAISE_POSITION_BONUS=4.0, NEGOTIATE_SESSION_TN_REDUCTION=5;
  PERSUADE_BASE_DISP=9, PERSUADE_RAISE_BONUS=3, PERSUADE_POSITION_SHIFT=12.0,
  PERSUADE_RAISE_POSITION_BONUS=5.0; IMPRESS_BASE_DISP=6, IMPRESS_RAISE_BONUS=2,
  IMPRESS_SESSION_TN_REDUCTION=5; LISTEN_REFLECT_BASE_DISP=9,
  LISTEN_REFLECT_RAISE_BONUS=3, LISTEN_REFLECT_SESSION_TN_REDUCTION=10;
  CHARM_CRITICAL_FAILURE_DISP=−3 (all "small" losses), PERSUADE_CRITICAL_FAILURE_DISP=−5
  (unqualified "disposition loss"), NEGOTIATE_FAILURE_POSITION_HARDEN=−1.0,
  NEGOTIATE_CRITICAL_POSITION_HARDEN=−3.0 (from Public Debate slight/strong scale).
- **s4.3 Resource Tick — audited, no changes needed.**
  GARRISON_STABILITY_PENALTY_PER_SEASON (2.0) confirmed GDD-sourced (s4.3.11:
  "-2 Stability/season"). UPPER_TIER_PASSTHROUGH (0.42) correctly derived from
  GDD per-tier rates: (1-0.30)×(1-0.25)×(1-0.20) = 0.42. EMPEROR_TAKE_FROM_PASSED_UP
  (0.063) is unused legacy constant.
- **s57.31 Medicine System — audited, fully compliant.** All 21 constants match GDD.
- **s11.7 Siege System — audited, fully compliant.** All constants (14 constants,
  12 event definitions, 3 formulas) match GDD s11.7 exactly. Zero invented values.
- **s12.8 Secret System — 3 invented values zeroed + 2 bug fixes.**
  CLAN_RELUCTANCE numeric values (0-5) zeroed — GDD s12.8 describes clan reluctance
  qualitatively but assigns no numbers. INTERCEPT_GEOGRAPHIC_BONUS (5→0) zeroed —
  GDD mentions geographic modifier but no value. BUG FIX: FABRICATION_TN had inverted
  tier→TN mapping (TIER_1 was 30, should be 15 per GDD s12.8 lines 163-169).
  FABRICATION_HONOR_COST had same inversion (TIER_1 was -1.5, should be -0.3 per
  GDD lines 173-181). Both dictionaries corrected. All other 37 constants confirmed.
- **s12.8 Seduction System — 2 values confirmed at 0 (s12.8c) + 1 removed.**
  BASE_TN = 0 confirmed: GDD formula `etiquette_rank + willpower + honor_rank` is
  complete, no base addend implied. Low TNs for average characters are intentional —
  Honor Rank scaling is the primary counterbalance. INFAMY_GAIN = 0.0 confirmed:
  GDD specifies honor cost only; infamy accrues via scandal topic on exposure, not
  at use. `raises_for_detail` removed from SEDUCE_FOR_INFO effects — not in GDD.
  HONOR_COST retained as dead metadata (superseded by CrimeSystem rank-scaled
  honor at line 69). All other values confirmed (disposition +5, maintenance
  16 days, 3 missed windows, affair severities, breakup disposition).
- **s12.10 Favor System — 1 value locked in s12.10a.**
  `get_dispute_witness_disposition()` creditor_won return value (2→0→2) —
  GDD says "witnesses gain disposition toward the creditor" without a number.
  Locked at +2: secondary social vindication, matches PUBLIC_PERFORMANCE
  per-witness gain. Debtor win stays 0 (GDD silent). All other 15 constants
  confirmed from GDD s12.10.
- **s11.3.12 Violence System — 1 value locked in s11.3.12a.**
  `INFAMY_PER_REPEATED_OFFENSE` (0.5→0.0→0.1) — locked at +0.1 per s11.3.12a.
  Calibrated against floor of infamy accrual for hostile social acts: public
  intimidation +0.1, blackmail +0.1 (both s12.9 LOCKED). Applies to repeat
  offenses (prior_offenses >= 1) and brutal first offense. All other constants
  confirmed: HONOR_LOSS (-0.2), GLORY_LOSS (-0.1), topic tiers (TIER_4 first,
  TIER_3 on third), repeat window (4 seasons), repeat threshold (3).
  Bribery system (s12.9) audited — fully compliant.
- **s12.9 Intimidation System — 1 value locked in s12.9a.**
  `PUBLIC_TN_INCREASE_BASE` (10→0→10) — GDD says "raises the effective TN"
  with "+5 per Raise" but no explicit base. Locked at 10 (same as private)
  per s12.9a: both are in-person contested rolls; public power differential
  is social consequences (witnesses, Honor/Infamy), not a different base.
  `PRIVATE_TN_INCREASE_BASE` (10) confirmed GDD-sourced
  (s12.9 explicitly says "+10"). `friend_threshold` (31) confirmed —
  matches GDD s12.2 Friend range (+31 to +60). All other constants
  confirmed: blackmail honor/infamy, private honor/infamy, public
  honor/infamy/witness disposition, letter TN, pushback TN base (15),
  disposition friend/enemy bonuses.
- **s12.3 Gift Giving System — 2 values locked in s12.3a.**
  `CRITICAL_FAILURE_DISPOSITION_LOSS` −3 ("small disposition loss" — matches
  Charm critical failure, s15.4a). `FORBIDDEN_GIFT_DISPOSITION_LOSS` −5
  ("an insult" — matches private_insult magnitude and Gossip base damage;
  clumsiness vs actively implying recipient lacks a sword). `DISPOSITION_PER_RAISE`
  (3) confirmed GDD-sourced (s12.2: "+3 per Raise on Awareness + Etiquette
  roll"). `free_raises * 5` conversion confirmed (core L5R 4e: 1 Raise = +5
  TN). All other constants confirmed: quality Free Raises (s49), TN 15,
  critical failure margin (-10), appropriateness matrix (structural).
- **s12.8 Seduction System — test fix for BASE_TN zeroing.**
  TN-dependent test assertions updated to use `SeductionSystem.BASE_TN`
  constant reference instead of hardcoded 23/33 (which assumed BASE_TN=15).
- **s12.8 Bound Escape System — 2 invented values fixed.**
  Dead `LOW_SKILL_HONOR_COST` constant removed (never used; CrimeSystem
  handles correctly). Guard detection TN formula `15 + (distance_tiles * 2)`
  replaced with GDD s56.6.3 fixed TNs: Quiet=20, Moderate=15 at listener's
  position (no distance scaling). KEEP: material TNs (GDD-sourced), rebind
  +5, quiet noise range 3, break chains TN 25, all escape mechanics.
- **s17 Personal Visit System — 5 values locked in s17a.**
  DECLINE_INVITATION_DISPOSITION −2, REFUSE_AFTER_INVITATION_DISPOSITION −5,
  REFUSE_AFTER_INVITATION_HONOR −0.5, REFUSE_LETTER_ARRIVAL_DISPOSITION −3,
  RECEIVE_UNINVITED_DISPOSITION +5. Calibrated against gossip (−5), Charm
  critical failure (−3), and Minor Favor break (−0.5 Honor). REFUSE_UNINVITED
  stays 0 (GDD silent — no host penalty for turning away uninvited guest).
  KEEP: INTIMATE_SETTING_BONUS (3, s17.2), DAILY_AP_DURING_VISIT (2, s14.1).
- **s22.9 Hostage System — 5 values locked in s22.9a.**
  HARMED_HOSTAGE_HONOR_LOSS −3.0 ("catastrophic" — matches assassination execution),
  ESCAPE_FAMILY_HONOR_LOSS −1.0 ("significant" — Moderate Favor break),
  ESCAPE_CRITICAL_FAMILY_HONOR_LOSS −2.0 (clean escape — Major Favor break).
  YU_CAPTURE_LIKELIHOOD 0.5 (50% captured vs die fighting),
  ISHI_CAPTURE_LIKELIHOOD 0.3 (30% captured, 70% die rather than submit).
  KEEP: all escape TNs, garrison scaling, leverage values.
- **s16.4 Court Commitment System — invented honor table replaced + 4 values zeroed.**
  VOLUNTARY_RENEGE_HONOR_BY_RANK dictionary (invented linear -0.5 to -5.0)
  replaced with CrimeSystem.get_disloyalty_honor() (Table 2.3: [0,-2,-6,-10,
  -14,-18]). All get_renege_willingness() values zeroed (Seigyo 0.8→0, Makoto
  0.1→0, Chugi 0.05→0, default 0.3→0). Edict renege topic_tier TIER_2→TIER_3
  (GDD doesn't specify different tier for edict renege). KEEP: priority values,
  EDICT_RENEGE_HONOR_COST, RENEGE_DISPOSITION_PENALTY, VOLUNTARY_POSITION_THRESHOLD.
- **s12.4 Performative Arts System — 2 values locked in s12.4a + 1 bug fix.**
  PERFORM_FOR_SUCCESS_DISPOSITION +8 ("strong disposition gain" — above moderate
  actions at +6, approaching Persuade base at +9). PERFORM_FOR_FAILURE_DISPOSITION
  −3 ("small disposition loss" — consistent with small-loss language across system).
  BUG FIX: masterful threshold `raises >= 3` → `raises >= 2` per GDD s4.6 line 49:
  "2 or more Raises (masterful)" and s57.33 line 57. KEEP: PERFORMANCE_TN (15),
  SUCCESS_DISPOSITION (2), SUCCESS_GLORY (0.3), all other GDD-confirmed values.
- **s22.7 Marriage System — 3 values locked in s22.7a.**
  PROPOSAL_FAVOR_TIER_MULTIPLIER 10 (MINOR=0, MODERATE=+10, MAJOR=+20),
  PROPOSAL_MILITARY_BONUS 10 (pressing military need equals MODERATE favor weight),
  BENTEN_FESTIVAL_BONUS 15 (most auspicious day — above military urgency, below
  Major obligation). KEEP: all 24 GDD-confirmed values (boosts, pregnancy, decay).
- **Tea Ceremony scoring — CONDUCT_TEA_CEREMONY alignment 85→100.**
  Under RECOVER_VOID_POINTS NeedType in objective_alignment.json. GDD says tea
  ceremony recovers void "identically to MEDITATE" which scores 100.
- **Daily Conversation — audited, no changes needed.**
  All numeric values confirmed: MAX_CONVERSATIONS_PER_DAY=5,
  DISPOSITION_BONUS=1, MIN_DISPOSITION_THRESHOLD=11, all probability brackets.
  is_topic_sensitive() MILITARY-only interpretation and weight floor maxf(1.0)
  are borderline structural — KEEP.
- **Tea Ceremony System — audited, no changes needed.**
  L5R_DIE_AVG (5.7) is structural engineering implementing GDD's "50% success
  chance" cap — KEEP. All other values confirmed: BASE_TN=15,
  TN_PER_EXTRA_PARTICIPANT=5, VP recovery values, PARTICIPANT_CAP=5,
  MIN_DISPOSITION=11.

### Invented Content Removal (2026-05-28)
- **action_executor — 4 invented base TNs zeroed.**
  SOCIAL_BASE_TN (15→0), COVERT_BASE_TN (20→0), MILITARY_BASE_TN (15→0),
  ADMIN_BASE_TN (10→0). GDD does not specify universal base TNs for action
  categories — each action has its own TN formula. PURCHASE_KOKU_COST 3.0→1.0
  per CLAUDE.md s55.32 resolution. BRIBE_KOKU_COST 5.0 confirmed (s55.32).
- **day_orchestrator — 13 invented constants zeroed.**
  _COMBAT_EVENT_MOMENTUM (30→0), _CIVIL_WAR_MOMENTUM (60→0),
  _CONSTRUCTION_TIER2_MOMENTUM (40→0), _FAMINE_RECOVERY_THRESHOLD (10→0),
  _FAMINE_HUNGER_MOMENTUM (25→0), _FAMINE_FAMINE_MOMENTUM (50→0),
  INTIMIDATION_DISPOSITION_PENALTY (-30→0), EVIDENCE_DECAY_START_DAYS (30→0),
  EVIDENCE_DECAY_INTERVAL_DAYS (10→0), COLD_CASE_THRESHOLD (5→0),
  DUEL_DECLINE_GLORY_LOSS (-0.3→0), TAINT_DETECTION_PLACEHOLDER_TN (20→0,
  blocked on s31), _RETREAT_DEFAULT_DAYS (3→0).
- **npc_decision_engine — 2 invented rokuyo constants zeroed.**
  INAUSPICIOUS_PENALTY (-10→0), TAIAN_BONUS (5→0). GDD says rokuyo is "not
  a mechanical modifier" for NPC scoring; +1 disposition is the only effect.
- **winter_court_system — school type scoring zeroed.**
  Delegation scoring and _score_school_type_for_invitation() all returns
  set to 0.0. GDD says archetype preferences are "personality-driven" without
  numeric scoring weights for school types.
- **world_population_generator — _STIPEND_BY_ROLE fixed per GDD s4.3.**
  Family Daimyo 5.0→3.0, Provincial Daimyo 3.0→2.0, Local Daimyo 2.0→1.0.
  Values were shifted one tier too high. GDD s4.3 lines 417-423 specify exact
  koku amounts per lord rank.
- **world_bootstrap/world_generator — PROVISIONAL annotations added.**
  BASE_PU constants, _scale_pu_by_terrain multipliers, TERRAIN_PU_DISTRIBUTION,
  POINTS_PER_RANK, POSITION_RANK, POSITION_STATUS all marked PROVISIONAL.
  These are world initialization parameters that cannot be zeroed without
  breaking world creation; GDD does not specify exact values.

### Known Code Issues (found and fixed 2026-05-28, post-audit)
- **CommerceStigmaSystem.HONOR_SELF_REG_7_PLUS / HONOR_SELF_REG_5_6 — removed in error. FIXED.**
  The invented-content audit removed these constants from commerce_stigma_system.gd
  but they are GDD-sourced (s57.40 line 59: "Honor 5–6 characters receive −3 lean,
  Honor 7+ characters receive −5 lean"). NPCDecisionEngine referenced them at lines
  624/626, causing a cascade compile failure: npc_decision_engine.gd failed to parse,
  then npc_wave_resolver.gd, day_orchestrator.gd, and world_state.gd all failed as
  dependents. The entire NPC decision pipeline was non-functional. Restored both
  constants with GDD citation.

### Comprehensive Simulation File Audit Complete (2026-05-28)
All 135 files in `/simulation/` audited against GDD. Summary:
- **8 files modified** (action_executor, day_orchestrator, npc_decision_engine,
  reactive_decisions, winter_court_system, world_bootstrap, world_generator,
  world_population_generator) — 34 invented constants zeroed, 3 stipend values
  fixed, ~15 PROVISIONAL annotations added.
- **127 files verified clean** — all numeric constants confirmed against their
  respective LOCKED GDD sections. No modifications needed.
- **Key verified systems** (this pass): artisan_system (s49), war_justification
  (s53.1), magistrate_allocation (s11.3.17), information_system (s55.12),
  gempukku_system (s52), topic_system (s16), worship_system (s4.3.21),
  void_system (s4.5/s25.5), wound_system (s4.5), wind_down_system (s57.44),
  ritsuyo_system (s11.3.10), request_performance_system (s57.33),
  inventory_system (s12.11), event_durations (s11.7b), time_system (s13),
  civilian_order_budget (s57.34), investigation_loop_system (s11.3.13),
  treason_system (s11.3.8), unsanctioned_killing_system (s11.3.9),
  objective_progress (s55.29.3), travel_commitment (s55.29),
  assassination_system (s12.8).
- **No remaining unaudited simulation files.**

### Known Code Issues (found and fixed 2026-05-29, marriage dissolution audit)
- **_build_dissolve_marriage_metadata() — spouse's lord gate missing. FIXED.**
  s57.49.7 specifies the targeting gate passes when the ordering lord has
  disposition ≤ −31 toward "the other spouse or that spouse's immediate lord."
  Code only checked disposition toward the spouse; disposition toward the
  spouse's lord was not evaluated. Added `spouse.lord_id` lookup and combined
  gate check. 3 tests added.
- **test_marriage_dissolution.gd — glory assertion off by 0.5. FIXED.**
  `test_apply_dissolution_pathway1_glory_loss()` asserted glory 5.0 → 4.0 (−1.0 change).
  The constant `DISSOLUTION_GLORY_LOSS_SPOUSE = -0.5` per s57.49b. §57.49.1's consequence
  table shows −1.0 but §57.49.6 (same locked file) and s57.49b both say −0.5. The
  §57.49.1 summary table was never updated when s57.49b formally locked the value at
  half the magnitude. Test corrected to assert 4.5. NOTE: §57.49.1's summary table
  (−1.0 Glory, −25 family baseline) remains stale relative to §57.49.6 and s57.49b
  (−0.5 Glory, −20 family baseline). This is a known GDD internal inconsistency;
  it was left unedited (GDD edits require owner permission). §57.49.6 and s57.49b
  are authoritative.

### GDD Sections Written 2026-05-28

- **s57.49 Marriage Dissolution** — New GDD file `gdd/s57.49_marriage_dissolution_locked.md`.
  Formalizes the 4-pathway dissolution system already implemented in code (marriage_system.gd,
  day_orchestrator.gd). Four pathways: (1) Lord's Command (DISSOLVE_MARRIAGE ActionID, Family
  Daimyo+, −1.0 Honor lord, −0.5 Glory each spouse, family penalty −20,
  clan penalty −10 — all locked in s57.49b A34-A36),
  (2) Criminal Conviction (TREASON/MAHO auto-dissolve, no penalties), (3) Monastic Retirement
  (is_retired_monastic flag, no penalties, RETIRE_TO_MONASTERY ActionID deferred), (4) Imperial
  Decree (war-marriages between belligerents, no penalties). Children remain with samurai parent.
  TIER_4 POLITICAL topic on all pathways. A34-A36 locked in s57.49b.
  Index updated. CLAUDE.md updated.

### Systems Added 2026-05-28 (continued)
- **s57.22 Theater Piece System** — `simulation/theater_system.gd`,
  `shared/theater_piece_data.gd`. Four ActionIDs fully wired into the NPC pipeline:
  COMPOSE_THEATER_PIECE (Poetry/Intelligence progress track; Poetry rank ≥ target_magnitude
  skill gate; seasonal degradation halves WIP progress after 90 idle days; completion
  Raises upgrade magnitude/topic_weight/topic linkage; new pieces declared in writeback
  via is_new_piece flag), LEARN_THEATER_PIECE (Acting/Intelligence progress track;
  Acting rank ≥ piece.disposition_magnitude gate; adds author_id to known_by on threshold
  completion; private pieces require co-located willing teacher via find_willing_teacher()),
  PERFORM_THEATER_PIECE (Acting/Awareness; polarization disposition rule — witnesses
  pushed AWAY from neutral regardless of framing direction; neutral witnesses receive
  flat DISP_NEUTRAL_FLAT=2 seed push; 30-day immunity window per witness per piece;
  known_by members permanently immune; Bunraku style +1 effective magnitude, 2 AP cost;
  critical success +2 magnitude bonus + Tier 4 performance topic; topic amplification
  via topic_weight × 2 × shifted_witness_count per linked topic), DEDICATE_PIECE
  (Courtier/Awareness; links topic to piece.topic_ids up to 2 slots; TN=10+magnitude×2).
  `TheaterPieceData` Resource: piece_id, title, style (NOH/KABUKI/KYOGEN/BUNRAKU),
  author_id, subject, subject_type (CLAN/FAMILY/CHARACTER/ARCHETYPE/ABSTRACT), framing
  (bool), roles (Array), topic_ids (Array[int] max 2), topic_weight (1–3),
  disposition_magnitude (1–5), known_by (Array[int]), canonized, times_performed,
  craft_progress (-1=complete, ≥0=WIP), target_magnitude, target_topic_weight,
  num_roles_declared, ic_day_last_composition_ap, lost, abandoned_incomplete, ic_day_created.
  World-start canonized pieces generated via `TheaterSystem.generate_canonized_pieces()`
  in `_bootstrap_fresh_world()` (Crane 12–15, Phoenix 10–12, Lion 7–9, Scorpion 6–8,
  Dragon 5–7, Unicorn 4–6, Crab 2–4, etc.). Casting TN modifiers: same-clan −5,
  enemy-clan +5, feature mismatch +5 per unmatched role requirement (Noh mask negates
  clan/gender). Death cleanup via `handle_character_death()` — removes from known_by,
  marks private pieces lost if known_by empties, marks WIP abandoned. Context injection
  via `_inject_theater_context()` → `known_objectives["theater_pieces_to_perform"]`
  and `known_objectives["wip_piece_ids"]`. Context keys cleared by stale flag clearing.
  `theater_pieces` and `next_piece_id` persist via WorldStateSaver Resource array
  pattern (one .tres per item in `theater_pieces/`). JSON scoring tables updated:
  action_skill_map.json (all 4 ActionIDs), objective_alignment.json
  (PERFORM_THEATER_PIECE → SEEK_GLORY 80 / DAMAGE_RELATIONSHIP 50 / MOVE_TOPIC_POSITION
  60 / PATRONIZE_ARTS 85; LEARN_THEATER_PIECE → ARTISTIC_EXPRESSION 70 / PATRONIZE_ARTS
  60; existing entries COMPOSE_THEATER_PIECE → ARTISTIC_EXPRESSION 100 / DAMAGE_RELATIONSHIP
  60 / MOVE_TOPIC_POSITION 60 and DEDICATE_PIECE → MOVE_TOPIC_POSITION 55 retained). 45 tests.
- **s57.54 Clan Champion Strategic Evaluation System** — `shared/strategic_conclusion_data.gd`,
  extended `simulation/strategic_review.gd`. Quarterly evaluation producing 2–4 clan-wide
  strategic conclusions that broadcast to Family Daimyo.
  `StrategicConclusionData` Resource: 16 `ConclusionType` values across 5 domains
  (MILITARY, DIPLOMATIC, ECONOMIC, SPIRITUAL, SOCIAL), `WarObjective` enum,
  `target_clan_id` (int via `clan_name.hash()`), `score`, `is_forced`,
  `is_continuation`, `source_topic_ids`, `season_originated`.
  `ClanData` gains `clan_strategic_priorities: Array[StrategicConclusionData]` and
  `next_conclusion_id`. `L5RCharacterData` gains `strategic_evaluation_log` (audit only).
  `ContextSnapshot` gains `champion_conclusion_candidates` and `local_tier3_candidates`.
  Six-step evaluation process: (1) Threat Scan — forced conclusions from Tier 1/2 topics
  and active wars/edicts; (2) Opportunity Scan — candidate pool from Tier 3/4 topics;
  (3) Scoring — standing objective match (+0/+30), topic urgency (Tier3=+25, Tier4=+10,
  momentum ±10), convergent topics (+5/extra), personality preference (+25/+15/0/−15,
  HARD_BLOCK removes from pool), continuation bonus (+10 base, Makoto +20, Ketsui +15,
  Ishi locks); (4) Selection — slot count from personality; (5) Write conclusions to
  `clan.clan_strategic_priorities`; (6) Dispatch notification letters to absent Family
  Daimyo via `_process_champion_letter_dispatches()`. Three trigger points:
  `run_clan_champion_evaluation` (quarterly, seasonal block), `run_midseason_crisis_update`
  (new Tier 1/2 topic forces partial reevaluation), `run_priority_resolved` (conclusion
  achieved or impossible — Ketsui immediately refills via full reevaluation).
  Family Daimyo Phase 2 combined pool (s57.54.10b): `get_champion_conclusion_needtypes()`
  translates Champion conclusions to NeedType candidates re-weighted by FD's own
  personality preference matrix. `_build_local_tier3_candidates()` converts Tier 1–3
  topics in character's topic_pool to NeedType candidates by topic category
  (MILITARY→DEFEND_PROVINCE, POLITICAL→INVESTIGATE_THREAT, ECONOMIC→ACQUIRE_RESOURCE,
  SUPERNATURAL→RESTORE_WORSHIP, LEGAL/other→INVESTIGATE_THREAT/RAISE_DISPOSITION).
  NPC engine `_check_combined_pool()` merges both arrays and selects highest-scoring
  need for Family Daimyo+ characters in Phase 2. Operational superior CO budget:
  `get_operational_superior_co_budget()` returns 2/day for 1–3 subordinates, 3/day
  for 4+ (s57.54.10d). PATRONIZE_ARTS added as 82nd NeedType in
  `objective_alignment.json` with REQUEST_PERFORMANCE (90), PERFORM_THEATER_PIECE (85),
  DELIVER_GIFT (70), LEARN_THEATER_PIECE (60), RAISE_DISPOSITION (40), WRITE_LETTER (35)
  (LEARN_THEATER_PIECE and PERFORM_THEATER_PIECE added when Theater System was implemented).
  Wired into DayOrchestrator:
  `_run_strategic_reviews()` gains `active_topics, active_edicts, clans, current_season,
  dice_engine` parameters; champion loop runs seasonally after standard lord reviews;
  `_inject_base_character_context()` populates champion_conclusion_candidates and
  local_tier3_candidates for Family Daimyo characters (status 6.0–6.99); both keys
  cleared by stale flag clearing between days. 22 tests.

### Known Code Issues (found and fixed 2026-05-29, theater system audit)
- **Bunraku extra AP not deducted — Bunraku always cost 1 AP instead of 2. FIXED.**
  `_execute_perform_theater()` returns `ap_cost_override: 2` for Bunraku performances
  (GDD s57.22.3 specifies 2 AP for Bunraku). The NPC engine deducts 1 AP before
  execution (from the `_get_ap_cost()` table). `_process_perform_theater_writebacks()`
  was supposed to deduct the extra 1 AP from `ap_cost_override`, matching the pattern
  used by APPLY_TATTOO, but did not. Added `ap_override = effects.get("ap_cost_override", 1)`
  check; when `ap_override > 1`, deducts `ap_override - 1` extra AP from performer.
  2 tests added.

### Systems Added 2026-05-18
- **s29.15 Courtier School Techniques** — School technique bonuses wired into
  SkillResolver and ActionExecutor. Doji Courtier R1a (honor-gated Free Raise on
  social skills when Honor ≥ 6.0), R2 Cadence (silent topic sync between
  cadence-trained courtiers at the same court), R3 Perfect Gift (one-shot +15
  disposition modifier on gift delivery, once per target). Yasuki R1 / Kitsuki R1 /
  Asako R1 Free Raises extended (Commerce, Investigation, Lore respectively). Kitsuki
  R2 + Yasuki R4 deception defense TN modifiers (+5 / +10 to resist Sincerity-Deceit
  contested rolls). Ikoma Bard R1a precise_memory flag (perfect topic recall). Asako
  Loremaster R2 from_the_ashes social buff (daily activation: +1k0 on social rolls
  at current location for 1 IC day, refreshed daily in day orchestrator). Auto-assign
  technique flags on character creation and rank-up via
  `SkillResolver.apply_technique_flags()`.
- **s29.15.24 Reroll System** — `simulation/reroll_system.gd`. Generic reroll charge
  system covering self-rerolls (Yasuki R2, Yoritomo R3, Kasuga R5) and granted rerolls
  (Ikoma R4, Shiba Advisor). Self-reroll: technique charges with skill eligibility
  filtering. Granted reroll: ally-granted entry with optional bonus dice. Weekly
  refresh cycle. DISCERN_NEED ActionID routed into NPC decision loop with school leans
  (Yasuki/Doji courtiers +15), accessible in AT_COURT and VISITING contexts.
- **SkillResolver Centralization** — All skill rolls now route through
  `SkillResolver.resolve_skill_check()` and `resolve_contested_check()` for uniform
  technique bonus, wound penalty, emphasis, and from_the_ashes handling. Replaces
  scattered per-system technique lookups (commits ea15c21 + dba8490). Bypass audit
  confirmed no regressions.
- **OpportunityScanner Additions** — 9 passthrough-ready primary objectives added for
  NPC self-selection (MAINTAIN_PEACE, SECURE_ALLIANCE, ARRANGE_MARRIAGE, etc.).
  SELF_SELECT directive fix: primary objectives now correctly written to objectives_map.
- **PrimaryObjectiveDecomposer SECURE_ALLIANCE** — New decomposition tree for
  alliance-securing objectives, routing through diplomatic and marriage actions.
- **Decomposer Bug Fixes** — 13 decomposer outputs corrected where ActionIDs were
  incorrectly used as NeedTypes. Now use proper NeedType enum values.
- **s57.47 Violation of Emperor's Peace** — CAPITAL crime type added (execution without
  seppuku option, Imperial jurisdiction). Wired into full crime/investigation pipeline
  and Winter Court Emperor's Peace enforcement (v624).

### s30 / s30a Katas — Combat Effects WIRED into s40 (2026-06-06)
`simulation/kata_system.gd` contains all 43 katas (eligibility, XP deduction, NPC
selection). Combat effects are now **wired into IndividualCombat** (s40), not stubs:
`_get_kata_initiative_modifiers`, `_get_kata_armor_tn_bonus`, `_get_kata_attack_modifiers`,
`_get_kata_damage_modifiers`, `_get_kata_wound_penalty_reduction`, `get_kata_reduction_bonus`,
`get_kata_opponent_reduction_penalty` resolve effect_ids into Armor TN / attack / damage /
Initiative / wound-penalty / Reduction modifiers, gated by stance and maneuver. 39 of 42
distinct kata effect_ids are wired. **`multi_empire_edge_skill_bonus` (The Empire Rests on its Edge)
wired as a passive read (2026-06-12):** `IndividualCombat.get_empire_edge_bonus` returns the
wielder's highest non-combat High Skill rank (via `AdvantageSystem.is_high_skill`, Bugei excluded)
when the kata is known; `resolve_attack` adds it to `flat_bonus` for Kenjutsu/Iaijutsu rolls
(katana/daisho implied by the skill gate). Passive — no caller needed. The GDD's "choose one
non-combat High Skill at acquisition" is auto-resolved to the highest High Skill (optimal,
deterministic; no choice-storage field); the "+2 XP per Rank" progression cost is not modelled.
**`multi_standing_heavens_void_reroll` (Standing on the Heavens)
wired as a defender reaction (2026-06-12):** in `execute_melee_attack`, when an attack hits,
`_maybe_standing_on_heavens` lets the struck defender spend 1 Void Point (Free Action, once/Round
via `kata_used_this_round`) to force the attacker to reroll — the reroll's outcome (hit or miss)
replaces the original. NPC-only auto-use (a defensive reflex when a VP is available); a PC defender
is skipped (`is_pc` guard) pending the turn-based reaction UI. All values GDD-given (1 VP, reroll).
**`multi_world_empty_void_attack` (The World Is Empty) wired on
the timed-modifier layer (2026-06-12, activation cost = Simple Action, owner-set):**
`AsciiMapCombatOrchestrator.execute_activate_world_is_empty` (Simple action; requires the kata + ≥1
Void Point; not re-activatable while active) freezes X = current Void Points and adds an
`"attack_rolled"` +X modifier for X Rounds; `resolve_attack` adds the `"attack_rolled"` total to
`rolled` (not kept) only for Kenjutsu/Iaijutsu (skill-gated = daisho). When it ends, `advance_round`
deducts 1 Void Point (`_process_world_is_empty_expiry`, before the round-based removal). A minimal
NPC hook activates it on round 1 (VP≥2, forgoing that turn's attack so the +Xk0 covers the fight —
basic heuristic, GDD gives no NPC policy; the natural caller is a PC bushi via the future turn-based
action UI). All non-AI values GDD-given (X = VP, X Rounds, lose 1 VP); the activation cost is the
single owner-set value. **`earth_spider_wound_debuff` (Strength of the Spider) wired
on the same timed-modifier layer (2026-06-12):** once per Round, a strike dealing 15+ Wounds gives
the opponent a `"all_rolls"` −3 timed modifier with `"turn_end"` expiry — active through the
opponent's next Turn, removed when their turn ends (`AsciiMapCombatOrchestrator.advance_turn`
expires turn-scoped modifiers on the ending actor; round expiry leaves turn modifiers untouched).
`resolve_attack` adds the `"all_rolls"` total to the attack-roll `flat_bonus` (attack rolls covered;
broader contested-roll coverage is a forward-wire). Fired passively from `execute_melee_attack` on
a 15+ Wound hit (`_apply_strength_of_the_spider`, once/Round via `kata_used_this_round`); no AI/UI
caller. All values GDD-given (15 Wounds, −3, next Turn). **`multi_victory_river_armor_pierce` wired via a new
timed-modifier layer (2026-06-12):** Victory of the River (s30a) — a landed katana/daisho strike
drops the target's Armor TN −10 vs all attacks AND the wielder's own Armor TN −10, both for 3
Rounds, one opponent at a time. New generic round-scoped store on `IndividualCombat.Participant`
(`timed_modifiers: Array` of `{kind,value,expires_round,source}` + `add/get_total/clear_by_source/
expire` primitives; `votr_target_id` tracks the held opponent). `get_armor_tn` adds the `"armor_tn"`
timed total on its main return path; `AsciiMapCombatOrchestrator.advance_round` expires by round
after the increment; `_apply_victory_of_the_river` fires passively from `execute_melee_attack` on a
hit (kata + katana/wakizashi gate, switching targets clears the prior debuff, re-striking refreshes
the window). All values GDD-given (−10, 3 Rounds, daisho-only). Passive — no AI/UI caller. The
layer's `kind` is generic (`"all_rolls"` / `"attack_roll"` reserved) so the remaining two duration
katas reuse the store. LIMITATION: the special-state Armor-TN early returns (Grappled/Stunned/
Blinded) do not include the timed modifier — GDD does not specify that interaction.
**`water_attack_stance_movement` wired into the ASCII map
movement layer (2026-06-12):** Striking as Water (s30a) — "In Attack Stance: move 5 additional
feet as a Free Action" — `IndividualCombat.get_kata_free_move_bonus` returns +1 tile (1 tile =
5 ft) when the character knows the kata and is in Attack Stance (Attack only, not Full Attack,
per the GDD text); `AsciiMapCombatOrchestrator.free_move_budget(state, char_id, character)` adds
it to the Free-action move budget and is now the single source used by the NPC and companion
move paths (the player-facing turn-based move UI should adopt it too). SIMPLE/FULL move budgets
unchanged (the GDD grants the bonus to the Free action only). Passive — no AI/UI caller needed;
any NPC/companion bushi or monk in Attack Stance who knows the kata gets the extra tile
automatically. **3 remain deferred** (each needs infra/AI the core resolve lacks):
`water_lion_ally_initiative` (Reactions-Stage ally-initiative action + AI caller), `water_unicorn_mount_bonus`
(no mount system on the map), `water_stealth_movement` (near-no-op on the tile map — "does not change maximum distance").
(`get_kata_reduction_bonus` is wired but currently has no caller — Reduction is applied via the
orchestrator damage path; harmless until consumed.)

### s38 Kiho — effect registry, tranche 1: atemi delivery + Flame Fist (2026-06-12)
First tranche of the kiho-effect registry (the larger effort to encode/wire the 73
kiho's combat effects; only 5 passive active-buffs + 5 encoded-but-unreachable atemi
existed before). **Key gap found:** `IndividualCombat.resolve_atemi_strike` existed
and read `KIHO_DATA[kiho]["atemi_effect"]` specs, but **nothing in the orchestrator
ever called it** — so the entire atemi kiho category (Unbalance the Mind, Freezing
the Lifeblood, Seven Storm's Fist, Mind/No-Mind, Tasaii-Do) was unreachable in tile
combat. Added **`AsciiMapCombatOrchestrator.execute_atemi_strike`** — a Complex-action
unarmed strike (melee range, monk-only by virtue of holding kiho, mirrors
execute_melee_attack gating) that delivers an atemi: on a hit it applies the kiho's
`atemi_effect` (an instant condition OR — new — a round-scoped timed modifier).
`resolve_atemi_strike` gains an optional `round_number` param and a `"timed"` spec
branch that adds a timed modifier via the existing layer. **Flame Fist** encoded as
the first new effect: `atemi_effect {"timed": {kind "all_rolls", value −3×Fire Ring,
duration Fire Ring}}` — on a hit the target takes −3×Fire to all rolls for Fire Ring
Rounds (expires via the `advance_round` timed sweep; read on the target's attack rolls
through the Spider `all_rolls` path). A minimal NPC monk hook (`_npc_pick_atemi` +
a branch in `execute_npc_turn`) makes a monk in melee deliver its first ENCODED atemi
(skips atemi with no wired effect, e.g. Censure of Thunder) instead of a normal strike;
atemi kiho are monk-only so there is no PC path. All values GDD-given (Flame Fist
−3×Fire / Fire Rounds; atemi as a Complex unarmed attack is a reading). Verified with
a headless driver: Flame Fist timed effect (−12 all_rolls, expiry round+Fire, Complex
consumed), Unbalance the Mind condition (dazed), the not-atemi/not-known/out-of-range
gates, and `_npc_pick_atemi` selecting encoded atemi only. DEFERRED (next tranches):
the remaining ~63 kiho effects (movement/leap, utility/out-of-combat, reactive
interrupts, AoE contested, grapple-tick, retaliation, healing-over-time, the
unencoded atemi like Censure/Touch of the Storm/Great Silence/Stain Upon the Soul,
and proper "Lasts N Rounds" auto-expiry for the 5 while-active buffs).

### s38 Kiho — out-of-combat character-level buffs, tranche 1 (2026-06-16, owner-authorized + scoped)
First out-of-combat (non-combat) kiho buffs, wired into `SkillResolver` (kiho are
monk-only; PCs can't be monks per s60.2, so an NPC activation policy is REQUIRED or
the system is inert — owner chose **just-in-time per tick**, scope **only the 2
buffs with a real world-sim consumer**, 2026-06-16). GDD analysis showed only 2 of
the ~13 out-of-combat kiho have a consumer the headless sim can read; the other 11
depend on systems that don't exist (poison/disease, long-range vision/ambush,
nemuranai/spell-effect detection, fatigue, heat/cold damage typing) and would be
no-ops, so they were left unwired (documented blocked-on-missing-consumer).
- **The Mind's Fire** (Fire 4, Internal): +2k2 on Intelligence-based skill rolls
  (GDD exact). Huge consumer surface via SkillResolver (courtier/investigation/lore).
- **Steal the Air Dragon** (Air 7, Kharmic): +Air Ring rolled & kept on Stealth
  rolls (GDD exact). Consumed by covert systems (assassination access, SHADOW_TARGET,
  conceal, eavesdrop, escape — many contested).
**Mechanism:** new `L5RCharacterData.active_kiho_buffs: Dictionary` (kiho_name →
ic_day last activated; @export, persists, stale entries ignored).
`SkillResolver._get_kiho_buff_bonus()` runs at the universal roll chokepoint (same
place as the `from_the_ashes` / mutation hooks) in BOTH `resolve_skill_check` and
`resolve_contested_check` (per side). On the first qualifying roll of the IC day a
monk who knows the kiho and has a Void Point spends 1 VP (s38a Void Point = Free
Action) to activate; later qualifying rolls the same tick reuse it (no extra VP),
tracked by the active_kiho_buffs marker == current ic_day. No effect when ic_day < 0
(can't dedup → never risks draining VP on untracked calls) or for non-monks (gated
on `character.kiho.has(...)`). Additive — zero effect for existing non-monk callers.
Runtime-verified (8 scenarios): VP accounting, per-tick dedup, next-tick reactivate,
VP-exhaustion no-op, ic_day<0 gate, non-monk skip, contested both-sides (only the
Stealth side spends, not the Perception side). LIMITATIONS: Mind's Fire's GDD
"Fatigued when it ends" downside is not modeled (no fatigue system) — buff has no
cost beyond the VP; durations ("minutes"/"while active") are modeled as per-tick
(the documented sub-day→tick compromise); the s38a active-slot rule is moot (the two
buffs are different types and no other out-of-combat buff is wired). TUNING: a monk
auto-spends a VP on its first Int/Stealth roll each tick regardless of the roll's
importance (the literal just-in-time policy) — watch for VP over-drain in a live run.
The other 11 out-of-combat kiho remain unwired (blocked on missing consumer systems),
and the combat-kiho set was already exhausted (tranches 1–33).

### s38 Kiho — effect registry, tranche 33: Touch the Void Dragon (environmental Ring boost) (2026-06-12)
Owner-directed (2026-06-12). **Touch the Void Dragon** (Void Internal, while active): one Ring
and its associated Traits are one Rank higher; the Ring depends on the skirmish terrain
(mountains=Earth, seashore=Water, plains=Air, desert/volcanic=Fire). Implemented leak-free as a
**Participant-scoped Ring flag** (`Participant.void_dragon_ring`) read at the combat-roll hooks —
NOT a trait mutation (combat operates on the live `L5RCharacterData`, so mutating traits would
persist into the world-sim after the skirmish; the established pattern is transient flags read at
hooks). `MapCombatState.environment_ring` carries the terrain-derived Ring;
`environment_ring_for_terrain` maps the four GDD-named terrains (MOUNTAINS/COASTAL/PLAINS/WASTELAND
→ Earth/Water/Air/Fire) and returns -1 (no boost) for terrains the GDD does not name (forest,
swamp, hills, river delta — absence of a mechanic, not an invented one).
`execute_activate_touch_void_dragon` routes the activation through the standard cost/slot path
(`execute_activate_kiho`), then stamps the Ring on the caster's Participant; it rejects activation
when the terrain yields no Ring (`no_environmental_ring`). The "+1 Rank to the Ring's Traits"
manifests via `IndividualCombat.vd_ring_bonus` at four core combat-roll sites: **attack roll**
+1k1 when the attack trait's Ring is boosted (Fire/agility, Air/reflexes, Water/strength-kata),
**damage** +1 rolled die (Water strength / Fire agility-kata), **Armor TN** +5 (Air/Reflexes ×5),
**Initiative** +1k1 (Air/Reflexes). NPC monks auto-activate it via `_npc_maybe_activate_kiho` when
the skirmish has a terrain Ring (else they fall through to their next known kiho). All values
GDD-given (+1 Rank = +1k1 on rolls; Armor-TN ×5 per Reflexes Rank is the GDD formula). Verified
with a headless driver: terrain map (mtn→Earth … forest→-1), Armor TN 20→25 for Air (no change for
Earth), attack mean +6.7 for Fire/agility (+1k1), damage rolled dice 6→7 for Water (no change for
Air), activation sets the boost + spends a Void Point, no-ring terrain rejected. LIMITATIONS
(architecture, not unknown values): (1) **Earth (mountains) has minimal combat effect** — the four
core combat rolls use Reflexes/Agility/Strength but never Stamina/Willpower, and Earth's signature
combat value, wound capacity, is not hooked (`get_total_wound_capacity` is not Participant-aware,
and the leak-free constraint forbids mutating the live Earth traits). (2) The caster's own **kiho
Ring rolls** (e.g. Slap the Wave's Water contest) are not boosted — they read
`CharacterStats.get_ring_value` directly; retrofitting ~30 kiho Ring reads is out of scope.
(3) No production caller of `setup_combat` yet — `environment_ring` is forward-wired (default -1);
the future mission-launch glue passes `environment_ring_for_terrain(province.terrain_type)`. With
this, **every kiho with a clean tile-combat effect is wired**; the remainder are dependency-blocked
(Dharma Technique / Silent Solace need a tile-combat spell-cast consumer; Rebuke / Sever need s54
undead; Breaking Blow / Waves in All Things are GM-judged object/terrain effects) or are the ~12
out-of-combat character-level buffs (need a character-level active-kiho system + an NPC non-combat
activation policy the GDD does not specify).

### s38 Kiho — effect registry, tranche 32: facing subsystem + Slap the Wave + Inari's Wrath (2026-06-12)
Owner-directed (2026-06-12). Built a participant facing subsystem to unblock the two
arc/cone kiho. `Participant.facing` (a unit heading) is updated by execute_move (faces the
direction moved); `_effective_facing` returns it, or — when unset — the direction toward
the nearest living enemy (the owner-approved NPC default). `_in_forward_arc` (forward
half-arc within range, via dot product) and `_in_cone` (forward cone widening linearly to
the GDD end-width) provide the geometry.
- **Slap the Wave** (Water): `execute_slap_the_wave` — spend a Void Point (no activation
  roll), then everyone in the caster's forward arc within Water Ring ×5 ft (= Water tiles)
  makes a Contested Water Roll or is Dazed. Affects all factions in the arc. Verified: the
  in-arc enemy was Dazed, the behind enemy was not, VP spent.
- **Inari's Wrath** (Air): `execute_inaris_wrath(phase)` — Round 1 "inhale" spends a Void
  Point + Complex Action to hold the breath (`Participant.inari_breath_round`); Round 2
  "exhale" (Complex Action) fires a freezing cone (School Rank ×5 ft long, ×2 ft wide at
  the end) dealing Air-Ring cold damage (Air k Air, bypassing Reduction) to every living
  creature in it. Verified: inhale armed it, the next-round exhale hit the in-cone enemy
  for 8 cold damage. All values GDD-given (the NPC facing default is owner-approved).

### s38 Kiho — effect registry, tranche 31: Song of the World (Initiative) (2026-06-12)
**Song of the World** (Void, Complex Action): `execute_song_of_the_world` — target an
opponent within 50 ft (10 tiles), win a Contested Void Roll, and the target's Initiative
drops 5 while the caster's rises 5. New persistent `Participant.initiative_modifier` added
into `roll_initiative` — because advance_round RE-ROLLS initiative each round, a one-time
score change would be overwritten, so the GDD −5/+5 maps to a standing delta (structural
adaptation; the values are GDD-given). Verified: contested win → caster +5 / foe −5, and
the caster's re-rolled initiative included the +5 (persists across the round re-roll).
**The combat kiho set is now exhausted.** The remaining unwired kiho are blocked on
missing data/systems, not unknown values: Touch the Void Dragon (no combat biome on
MapCombatState + a broad +1-Ring modifier), Slap the Wave / Inari's Wrath (no facing
data for arc/cone), Dharma Technique / Silent Solace (no tile-combat spell-cast consumer),
Rebuke of the Heavens / Sever the Dark Lord's Touch (s54 undead), Breaking Blow / Waves in
All Things (object/terrain effects with GM-judged/undefined object HP), and the ~12
out-of-combat character-level buffs (need a character-level active-kiho system + an NPC
non-combat-kiho activation policy the GDD does not specify).

### s38 Kiho — effect registry, tranche 30: Striking Through the Void (VP damage) (2026-06-12)
**Striking Through the Void** (Void, while active): the caster may spend a Void Point on
an unarmed damage roll for +1k1 (one Void Point per attack). Added an optional
`bonus_kept` param to `IndividualCombat.resolve_damage` (backward-compatible, default 0 —
+1k1 from a Void Point is standard L5R, not invented); `_apply_hit` spends 1 VP and passes
`raises_for_damage + 1` (rolled) and `bonus_kept = 1` (kept) when the attacker holds the
kiho, is unarmed, and has a Void Point (NPC auto-spends). Verified: unarmed damage 11 → 19
with the Void spend (VP 2 → 1). The remaining combat-relevant unwired kiho are blocked on
missing data (Touch the Void Dragon needs a combat biome; Slap the Wave/Inari's Wrath need
facing), a spell-cast consumer (Dharma Technique, Silent Solace), s54 undead (Rebuke,
Sever), or are marginal object/terrain effects (Breaking Blow, Waves in All Things).

### s38 Kiho — effect registry, tranche 29: Way of the Willow (interrupt) — reaction set complete (2026-06-12)
**Way of the Willow** (Air, while active): a defender may spend a Void Point to interrupt a
declared melee attack with an immediate unarmed counterattack (once per Round). Pre-attack
hook in execute_melee_attack (before resolve_attack): `_maybe_way_of_the_willow` resolves
the counter directly; if it kills the attacker, the original attack is aborted
(`interrupted_by_way_of_the_willow`). All GDD-given (VP cost, counterattack). Verified:
the defender spent a VP and countered (attacker took 6 Wounds) before the attack resolved;
a 2nd same-Round attack triggered no second interrupt. LIMITATION: the GDD "Move Action
away" alternative and the "has not yet taken their Turn" gate are approximated — the NPC
default is the counter, gated once per Round + VP.
**All 5 reaction kiho are now wired** (Destiny's Strike post-hit, Shadowed Mountain
pre-attack stance, Earthen Fist deferred-Disarm, Bishamon's Grasp free-grapple, Way of the
Willow pre-attack interrupt). With this, EVERY kiho that has a tile-combat effect is wired.
The unwired remainder are: character-level non-combat buffs needing a deferred character-kiho
system (Steal the Air Dragon, Eye of the Eagle, Earth Needs No Eyes, Harmony in/of the
Mind/Earth, Wholeness in All, Eight Directions Awareness, Knowledge from Within, The Wind's
Vision, Cleansing Spirit, The Mind's Fire, Harmony of the Mind, Flee the Darkness); facing-
blocked arc/cone (Slap the Wave, Inari's Wrath); no-consumer (Dharma Technique spell-defense,
Striking Through the Void kept-dice damage, Silent Solace, Channel the Fire Dragon); s54-blocked
(Rebuke of the Heavens, Sever the Dark Lord's Touch); no-biome (Touch the Void Dragon); and
marginal object/terrain effects (Breaking Blow, Waves in All Things, Song of the World). None
is blocked on an unknown value.

### s38 Kiho — effect registry, tranche 28: Bishamon's Grasp (free grapple vs attackers) (2026-06-12)
**Bishamon's Grasp** (Earth, while active, Defense/Full Defense only): on the caster's
Turn, free-grapple an opponent who attacked the caster since their last Turn (overrides
the Defense-stance no-attack restriction). New `Participant.attacked_by_ids` tracks
attackers (recorded in execute_melee_attack when the defender holds the kiho, cleared in
begin_turn = "since the last Turn"). `execute_bishamons_grasp` finds the first co-located
qualifying attacker and resolves a free-action grapple (core mirrors execute_grapple_initiate,
no Complex consumed). Verified: an attacker was recorded, then free-grappled on the monk's
Turn from Full Defense (complex_used stayed false). LIMITATION: the single
`grapple_partner_id` models one grapple, so one opponent is grabbed per Turn (the GDD's
"one per qualifying opponent" multi-grab needs a multi-partner model); the Throw-as-Free-Action
clause is not wired. Completes the combat-relevant reaction set (post-hit / pre-attack /
deferred-disarm / grapple-attackers); only Way of the Willow's pre-declaration
interrupt-with-choice remains among reactions.

### s38 Kiho — effect registry, tranche 27: Ride the Water Dragon (heal-over-time) (2026-06-12)
**Ride the Water Dragon** (Water, while active): the caster recovers Water Ring Wounds
during the Reactions Stage of each Round. Wired into the advance_round per-participant
loop (beside Way of the Earth): `WoundSystem.heal_wounds(caster, Water Ring)`. All
GDD-given. Verified: a Water-4 caster healed 4 Wounds on round advance (20 → 16).
LIMITATION: the "Insight Rank Rounds" duration is not modelled (round-duration spec keys
off a Ring) — it persists for the skirmish. Establishes the per-round heal-over-time
pattern. NOTE: with this, every per-round tick shape (grapple damage, self-heal) is now
covered.

### s38 Kiho — effect registry, tranche 26: Riding the Clouds + The World Disappears (2026-06-12)
- **Riding the Clouds** (Air, while active): `execute_riding_the_clouds` — a Simple Move
  Action to leap up to Air Ring ×10 ft (= ×2 tiles) to any free passable tile (ignoring
  terrain cost — a jump). The kiho is expended after one leap (erased from active_kiho).
  Verified: an Air-4 monk leaped 6 tiles, then a second leap returned kiho_not_active.
- **The World Disappears** (Void, while active): the floating caster is immune to
  Grappling — wired as an early `target_immune_to_grapple` return in
  execute_grapple_initiate. Verified. LIMITATION: the terrain-ignoring movement (over
  water/lava) is not wired (only the grapple-immunity); Entangling has no system.
All GDD-given.

### s38 Kiho — effect registry, tranche 25: Calling the East Wind (leap-kick) (2026-06-12)
**Calling the East Wind** (Air, Complex Action): `execute_calling_the_east_wind` — leap up
to Air Ring ×10 ft (= ×2 tiles) to a free passable tile adjacent to the target, then make
an unarmed kick with +1k0 damage. Finds the landing tile (adjacent to the target, within
the leap, unoccupied, passable); fails (`no_leap_landing`) if none is reachable. The
Knockdown Free Raise is recorded as metadata (the kick is a damage attack, not a separate
Knockdown maneuver). All GDD-given (Air×10 ft leap, +1k0). Verified: an Air-4 monk 6 tiles
away leaped to an adjacent tile and the kick landed. Establishes the leap-attack pattern.

### s38 Kiho — effect registry, tranche 24: Strike Through the Wind (extended range) (2026-06-12)
**Strike Through the Wind** (Air, while active): unarmed melee attacks reach School Rank
×25 ft (= ×5 tiles) by transmitting force through the air. Wired in execute_melee_attack's
range check: for an unarmed attack with the kiho active, `melee_range = Insight Rank × 5`
tiles instead of 1. All GDD-given. Verified: a target 6 tiles away was out of range
without the kiho, reachable with it (School Rank 3 → 15-tile range). LIMITATION: the GDD
"Complex Action" qualifier is inherent (melee attacks already cost a Complex action).

### s38 Kiho — effect registry, tranche 23: Earthen Fist + Root the Mountain (2026-06-12)
Two reactive/maneuver-layer kiho.
- **Earthen Fist** (Earth, while active): when an opponent's melee attack against the
  caster (who must be in Defense/Full Defense) MISSES, the caster may attempt a Disarm
  next Turn for no Raises. Wired in execute_melee_attack on the miss path: arms the
  existing `disarm_free_raises_pending = 3` track (consumed by the Disarm maneuver block).
  Verified: a missed attack against a Full-Defense Earthen-Fist caster set pending=3.
- **Root the Mountain** (Earth, while active, tranche 22): forcing the caster to move
  requires the attacker to also win a Contested Earth Roll. `_root_the_mountain_resists`
  wired into the Knockdown maneuver (negates the knockdown) and Hurricane Palm (negates
  the knockback distance; the Prone still applies). Verified: a strong-Earth defender
  resisted a weak-Earth attacker's knockback. LIMITATION: the "Knockdown requires 2 extra
  Raises" clause is not modelled (resolve_knockdown takes no raises modifier).
All GDD-given.

### s38 Kiho — effect registry, tranche 21: Rising Mountain (dynamic Reduction) (2026-06-12)
**Rising Mountain** (Earth, while active): every time an attacker makes a Raise on an
offensive combat action against the caster, the caster gains Reduction = 2× the number of
Raises. Wired in `_apply_hit`: when the struck defender holds the kiho, `reduction += 2 *
raises` before `WoundSystem.apply_damage` (spells excluded — this is the weapon-strike
path). All GDD-given. Verified: at 2 Raises, damage 16 → 12 (−4 = 2×2 Reduction).
LIMITATION: the "Insight Rank +1 Rounds" duration is not modelled (my round-duration spec
keys off a Ring, and Insight is not a Ring) — it persists for the skirmish; and Free
Raises (per the GDD note) are not separated from called Raises. Establishes the per-attack
dynamic-Reduction pattern.

### s38 Kiho — effect registry, tranche 20: Way of the Earth (grapple damage-tick) (2026-06-12)
**Way of the Earth** (Earth, while active): each Round, an opponent engaged in a Grapple
with the caster suffers the caster's Earth Ring in Wounds (Reactions Stage, regardless of
who controls the grapple). Wired into the advance_round per-participant loop: for a
participant holding the kiho with `grapple_partner_id >= 0`, the partner takes Earth Ring
Wounds (using the existing `grapple_partner_id` tracking + chars_by_id). "Minutes equal to
Earth Ring" >> a skirmish, so it persists (no round duration). All GDD-given. Verified: a
grappled opponent took Earth 4 Wounds on round advance. Establishes the per-round
grapple-tick pattern. (Updates the session-close list: grapple damage-tick is now wired;
Bishamon's Grasp still needs the "who attacked me" tracking + free grapple-attacks layer.)

### s38 Kiho — effect registry, tranche 19: Dance of the Flames (action-economy) (2026-06-12)
**Dance of the Flames** (Fire, while active): unarmed attacks cost a Simple Action
instead of Complex — so a monk can make two unarmed attacks (two Simples) in one Turn.
execute_melee_attack computes `dance_simple` (unarmed + the kiho active) and switches
both the action-availability gate (`can_use_simple` vs `can_use_complex`) and the
consumption (`consume_simple` vs `consume_complex`). All GDD-given. Verified: two unarmed
attacks landed in one Turn (simple_used 1→2, no Complex), the third blocked
(no_simple_actions_remaining). LIMITATION: the "must make an unarmed attack every Round
or the effect ends" maintenance requirement is not modelled (it would need a per-round
end-of-turn check). Establishes the action-economy modifier pattern.

**Kiho effect registry — session close (19 tranches).** Every kiho category with a clean
tile-combat implementation is now wired: atemi (22/24 — 2 dependency-blocked on s54
undead / a combat spell-cast consumer), while-active buffs (Armor TN, Initiative,
Reduction, wound penalty, move, contact-retaliation, with round durations), AoE Daze
(Thunder's Word), knockback (Hurricane Palm), condition recovery (Depths of the World),
ally VP grant (To the Last Breath), post-hit + pre-attack reactions (Destiny's Strike,
Shadowed Mountain), action-economy (Dance of the Flames), the AdvantageSystem suppression
hook (Banish All Shadows, Rest My Brother), and the tile→world delayed kill (Death Touch).
The remaining ~32 non-atemi kiho are NOT blocked on unknown values — each needs new
infrastructure: a deferred next-turn effect queue (Earthen Fist), grapple-relationship
tracking (Way of the Earth, Bishamon's Grasp), an interrupt-with-choice + VP (Way of the
Willow), leap/teleport movement (Riding the Clouds, The World Disappears, Strike Through
the Wind, Calling the East Wind), facing data for arc/cone (Slap the Wave, Inari's Wrath),
a per-round dynamic-Reduction layer (Rising Mountain), an environment→Ring boost (Touch
the Void Dragon), object-destruction-by-attack (Breaking Blow), or are out-of-combat
utility with no tile-combat effect (~12 kiho: Eye of the Eagle, Earth Needs No Eyes,
Harmony in/of the Mind/Earth, Wholeness in All, Eight Directions Awareness, Knowledge
from Within, The Wind's Vision, Cleansing Spirit, Channel the Fire Dragon, The Mind's
Fire, Flee the Darkness).

### s38 Kiho — effect registry, tranche 18: Shadowed Mountain (pre-attack reaction) (2026-06-12)
**Shadowed Mountain** (Earth, while active): a defender may immediately enter Full
Defense Stance just before being attacked (once per activation), raising that attack's
Armor TN. Pre-attack hook in execute_melee_attack (before the Armor TN computation): if
the target holds the kiho, isn't already in Full Defense, and hasn't used it this
activation → switch `t_p.stance = FULL_DEFENSE` and mark used. The switch is sticky
(they remain in Full Defense). New `Participant.shadowed_mountain_used`, re-armed by
`execute_activate_kiho` on a fresh activation. All GDD-given (Full Defense, once/activation).
Verified: a defender switched ATTACK→FULL_DEFENSE just before being struck (used=true).
This + Destiny's Strike (tranche 17) cover both reaction-hook shapes (pre-attack stance
switch / post-hit counter). The 3 remaining reactions need infra not built here:
deferred next-turn effect (Earthen Fist Disarm-on-miss), interrupt-with-choice + VP
(Way of the Willow), grapple + attacker tracking (Bishamon's Grasp).

### s38 Kiho — effect registry, tranche 17: Destiny's Strike (post-hit reaction) (2026-06-12)
First reaction kiho — establishes the post-hit reaction pattern. **Destiny's Strike**
(Fire, while active): when struck by a melee attack, the defender immediately makes a
single unarmed counterattack against the attacker. `_maybe_destiny_strike` (called from
execute_melee_attack after a landed hit) resolves the counter **directly** (resolve_attack
+ resolve_damage + apply_damage, NOT via execute_melee_attack) so it cannot recurse, and
is gated **once per Round** per defender (kata_used_this_round["destiny_strike"]) +
melee-range. All GDD-given (unarmed counter, once/Round). Verified: a struck defender
countered for 9 unarmed damage; a 2nd same-round strike triggered NO second counter (the
once/round guard prevents recursion even if both combatants hold the kiho). LIMITATION:
the GDD action-economy nuance ("counts as the Turn if not yet taken, else a Free Action")
is not modelled — the counter is a free reactive strike. The OTHER reactions need
different hooks not built here: pre-attack interrupt (Way of the Willow, Shadowed
Mountain), deferred next-turn effect (Earthen Fist Disarm-on-miss), or grapple tracking
(Bishamon's Grasp).

### s38 Kiho — effect registry, tranche 16: utility executes + ceiling (2026-06-12)
Two more standalone non-atemi kiho executes, exhausting the cleanly-buildable set.
- **Depths of the World** (Earth, Complex Action): `execute_depths_of_the_world` —
  immediately attempt to recover from a non-permanent Condition that allows a recovery
  roll (Stunned, then Dazed) via the existing `attempt_recover_stunned/dazed`. Usable
  even while Stunned (bypasses the can-act restriction). Verified: recovered Dazed.
- **To the Last Breath** (Void): `execute_to_the_last_breath` — grant a selected ally
  within 20 ft (4 tiles) one Void Point (capped at their Void Ring — the cap-at-max is
  the conservative non-invented reading; GDD says "gains one Void Point"). No target may
  benefit more than twice per skirmish (`MapCombatState.last_breath_uses`). Verified:
  VP 1→2→3 across two uses, then target_at_use_limit on the third.
**Kiho combat-effect ceiling reached.** All kiho that reuse the existing hooks (buffs,
damage, conditions, move, suppression) or have a self-contained execute (AoE Daze,
knockback, condition recovery, VP grant) are now wired: 22/24 atemi + ~13 non-atemi.
The remaining ~36 non-atemi kiho are NOT blocked on unknown values — they are blocked on
(a) being **out-of-combat utility** with no tile-combat effect to implement (Eye of the
Eagle, Earth Needs No Eyes, Harmony in/of the Mind/Earth, Wholeness in All, Eight
Directions Awareness, Knowledge from Within, The Wind's Vision, Cleansing Spirit, Channel
the Fire Dragon, The Mind's Fire, Flee the Darkness), (b) **missing facing data** for
arc/cone effects (Slap the Wave, Inari's Wrath), or (c) needing a **new combat subsystem**
— a true reaction/interrupt mechanism with re-entrancy handling (Way of the Willow,
Destiny's Strike, Shadowed Mountain, Earthen Fist, Bishamon's Grasp), leap/teleport
movement (Riding the Clouds, The World Disappears, Strike Through the Wind, Calling the
East Wind), a grapple damage-tick (Way of the Earth), or a per-round Reduction/maneuver
layer (Rising Mountain, Root the Mountain, Dance of the Flames, Striking Through the Void,
Touch the Void Dragon, Song of the World, Rebuke of the Heavens, Breaking Blow).

### s38 Kiho — effect registry, tranche 15: Hurricane Palm (knockback) (2026-06-12)
**Hurricane Palm** (Air, Complex Action): `execute_hurricane_palm` — an unarmed strike
that, on a hit, spends a Void Point to deal only HALF normal damage but knock the target
back 2× Air Ring feet (= 2×Air/5 tiles) directly away from the attacker and leave them
Prone (even on 0 Wounds). New `_knockback_target` grid-push helper: steps the target in
the away-direction (signi of the position delta), stopping at a wall, an occupied tile,
or the map edge. All GDD-given (half damage, 2×Air ft, Prone). Verified: Air-6 caster,
VP 2→1, knockback 2 tiles, target pushed (6,5)→(8,5) away from the attacker at (5,5),
Prone, half damage. Establishes the grid-knockback mechanic (reusable for other push
effects). DEFERRED — the arc/cone AoE (Slap the Wave, Inari's Wrath) need facing data
(not tracked); the reaction kiho need a true interrupt mechanism with re-entrancy
handling (a deliberate subsystem, not built here).

### s38 Kiho — effect registry, tranche 14: Thunder's Word (AoE Daze) (2026-06-12)
First AoE kiho — establishes the standalone non-atemi kiho action pattern in the
orchestrator. **Thunder's Word** (Air, Complex Action): `execute_thunders_word` — the
caster makes one Air roll; every OTHER living combatant (the whole skirmish — a
power-word shout is heard by all, allies included per GDD "All living beings capable of
hearing") makes a Contested Air Roll against it, and those who fail are Dazed. The caster
is excluded. Consumes the Complex action. Not added to the NPC offensive hook (it is
self-harming — Dazes allies); reachable via the execute path (PC use / deliberate NPC).
Reuses the Dazed condition (roll-recovered — the GDD "for Air Ring Rounds" is the known
flat-vs-timed condition limitation). All GDD-given (Contested Air, Dazed). Verified: an
Air-6 caster rolled 39; two Air-1 combatants both Dazed, the caster not, Complex consumed.
DEFERRED — remaining AoE/positional kiho need data the tile layer lacks: Slap the Wave +
Inari's Wrath need **facing direction** (arc/cone — not tracked); Hurricane Palm needs
**grid knockback**; the reaction kiho need a true **interrupt mechanism** (advance_round_reactions
is only a recovery pass).

### s38 Kiho — effect registry, tranche 13: non-atemi combat buffs (2026-06-12)
First non-atemi kiho with real tile-combat effects (beyond the 5 passive active-buffs).
- **Musubi** (Water): while active (staff in motion), Armor TN += Water Ring + Staves
  Skill Rank. Wired as `effect_id "kiho_musubi_armor"` in `_get_kiho_armor_tn_bonus`
  (same hook as Soul of the Four Winds). Verified: +7 Armor TN (Water 3 + Staves 4).
- **The Body is an Anvil** (Fire): a landed unarmed strike burns whoever touches the
  anvil-caster — `_apply_body_is_anvil` (called from execute_melee_attack after a hit)
  deals Fire Ring contact Wounds in either direction (DEFENDER active → the unarmed
  attacker is burned; ATTACKER active → the struck target takes Fire Ring beyond normal
  damage). Unarmed-only (the katana gate skips it). Duration 2× Fire Rounds via the
  active_kiho_expiry layer. Verified: both directions deal Fire 4 contact; armed strike
  no-ops.
- **Fire's Fleeting Speed** (Fire): while active, +5 ft (+1 tile) to any Move Action, for
  Fire Ring Rounds. `IndividualCombat.get_kiho_move_bonus` (checks active_kiho), added to
  both orchestrator move-budget sites (free_move_budget + the NPC SIMPLE budget). Duration
  via active_kiho_expiry. Verified: free move budget 3 → 4 while active.
  All GDD-given. DEFERRED — the remaining ~40 non-atemi kiho need new combat
  subsystems (reaction/interrupt: Way of the Willow, Destiny's Strike, Shadowed Mountain,
  Earthen Fist, Bishamon's Grasp; AoE: Thunder's Word, Inari's Wrath, Slap the Wave,
  Hurricane Palm; movement/leap: Calling the East Wind, Riding the Clouds,
  The World Disappears, Strike Through the Wind; grapple-tick: Way of the Earth,
  Root the Mountain) or are out-of-combat utility (Eye of the Eagle, Earth Needs No Eyes,
  Harmony in/of the Mind/Earth, Wholeness in All, Eight Directions Awareness, Knowledge
  from Within, The Wind's Vision, Cleansing Spirit) — none of which reuse the existing
  buff hooks.

### s38 Kiho — effect registry, tranche 12: Rest, My Brother (Taint-strip atemi) (2026-06-12)
Encoded **Rest, My Brother** (Earth 5 atemi): deals normal unarmed damage + additional
unkept (rolled) damage dice equal to the opponent's Shadowlands Taint Rank, and a
human/formerly-uncorrupted target loses all Shadowlands Taint **benefits** for caster
Earth Ring Rounds. 22 atemi encoded. Reuses the suppression pattern (mirrors Banish):
transient `taint_benefits_suppressed` on the character; `MutationSystem.get_skill_modifiers`
skips the 5 positive Taint bonuses (EXTRA_EYE, MASTER_OF_SHADOWS, MONSTROUS_STRENGTH
strength, FATHER_OF_LIES, MIND_OF_DARKNESS) while set — the **penalties** (social −Xk0,
etc.) remain, per "lose all benefits". `normal_damage` spec extended with
`bonus_target_taint` (bonus rolled dice = `get_taint_rank(target.taint)`).
Participant.taint_benefits_suppressed_expiry; advance_round clears it via chars_by_id.
All GDD-given (Taint Rank dice, Earth Ring duration). The "human/not inherently Tainted"
gate always passes — oni / inherently-Tainted creatures are s54 and don't exist in tile
combat. Verified: a Taint-Rank-3 MASTER_OF_SHADOWS target took normal_dmg 8 (incl. +3
Taint dice); its Stealth Taint benefit +3k0 → 0k0 while suppressed, restored at expiry
(round 4 = 1 + Earth 3). DEFERRED — 2 atemi remain, both dependency-blocked (not unknown
values): **Silent Solace** (Void 5, spell-slot tax) has no tile-combat spell-casting
consumer — the combat orchestrator has no cast-spell action, so the tax would be inert;
**Sever the Dark Lord's Touch** (Fire 5, instantly destroys unintelligent undead) needs
s54 undead entities, which don't exist in tile combat. Plus Earth Palm's Fire option.

### s38 Kiho — effect registry, tranche 11: Disadvantage atemi + s45 catalog (2026-06-12)
Owner-directed (2026-06-12). Built the AdvantageSystem-in-combat hook and encoded the 3
Advantage/Disadvantage-manipulation atemi. 21 atemi encoded. **Prerequisite — s45
category+points catalog:** the codebase had no category (Mental/Physical/Social/Spiritual/
Material) or point-value metadata for advantages/disadvantages (DisadvantageData had only
type + rank), which all 3 kiho need ("highest-point", "excluding Spiritual/Social",
"equal value", "Spiritual Advantages"). Transcribed from GDD s45 (`**Name [Category]
(N pts)**`): `AdvantageSystem.ADVANTAGE_CATALOG` (82) + `DISADVANTAGE_CATALOG` (63), each
Enums value → {category, points} (points 0 = variable → use the held entry's rank; "" =
s45 gives none, e.g. Wanderer). Helpers: get_advantage/disadvantage_category,
get_advantage/disadvantage_points. Pure transcription, no invented values.
- **Banish All Shadows** (Void 4): on a hit, the willing-ally target ignores their
  highest-point non-Spiritual/non-Social Disadvantage for caster Void Ring Rounds. The
  combat hook: transient `suppressed_disadvantage_type` on the character, skipped at the
  top of the 3 combat-roll disadvantage loops (get_skill_bonus, get_tn_modifier,
  get_trait_modifier); `_is_suppressed`. `get_highest_non_spiritual_social_disadvantage`
  selects the target (catalog category+points). ally_auto_hit → excluded from the
  offensive NPC hook. Participant.suppressed_disadvantage_expiry; advance_round clears it.
  LIMITATION: other disadvantage readers (melee damage penalty, wound TN, void-spend
  blocks) don't honor the suppression yet — the 3 covered are the primary combat-roll
  effects. Verified: selection excludes Spiritual; BAD_EYESIGHT −1k1 removed while
  suppressed; restored at expiry.
- **Sense the Balance** (Void 6): on a hit, spend a Void Point to learn the count of the
  target's Spiritual Advantages OR Disadvantages (caster's choice; default Disadvantages,
  PC-choice param deferred). On a won Contested Void Roll, also learn the highest-point
  not-yet-revealed one; repeat uses reveal more until all known. count_spiritual_* +
  get_highest_spiritual_* helpers; `MapCombatState.sense_known` for progressive reveal;
  VP spent post-hit (conditional on the hit, not the resolver's pre-hit vp_cost).
  info_only → excluded from the offensive hook. Verified: count + highest-first
  progressive reveal + all-known + no-VP.
- **Spin the Kharmic Wheel** (Void 8): expend ALL Void Points; the target loses one random
  Social/Spiritual/Mental Disadvantage and gains a new random one of equal point value (a
  permanent character mutation). get_swappable_disadvantages + pick_equal_value_disadvantage
  (catalog-driven, fixed-point pool, excludes already-held). non_combat_effect → excluded
  from the offensive hook. Verified: BAD_FORTUNE (Spiritual 3pts) → a Mental 3pt
  Disadvantage, all VP expended; no-swappable and no-VP gates. LIMITATION: the gained
  Disadvantage has empty metadata (rank 1) — metadata-dependent ones (e.g. Sworn Enemy)
  would be inert until populated; benign for combat.
DEFERRED — 3 atemi remain (Rest My Brother Taint, Sever the Dark Lord's Touch undead
[s54], Silent Solace spell-slot) plus Earth Palm's Fire option.

### s38 Kiho — effect registry, tranche 10: Death Touch (tile-combat → world-sim) (2026-06-12)
Encoded **Death Touch** (Void 7 atemi) — the first kiho whose effect spans the tile-combat
layer AND the world-sim. Owner-authorized design (2026-06-12): **full pipeline / all five
Rings / next daily tick** (the other values are GDD-given). 18 atemi encoded.
- **In-combat** (`execute_atemi_strike`, `MapCombatState.death_touch_chains`): tracks the
  3-atemi-on-3-consecutive-Rounds chain (a miss or a non-consecutive round resets it). On
  the 3rd consecutive strike, spends an additional Void Point and stamps a
  `death_touch_affliction` Dictionary on the target ({caster_id, insight_cap = caster's
  Insight Rank, caster_void snapshot}). No VP → `death_touch_no_void`, sequence fails.
- **World-sim** (`DayOrchestrator._process_death_touch_afflictions`, run before
  `_process_lord_deaths` for same-tick succession): the −1/Ring/hour drain (cap = Insight
  Rank) completes within hours = the next daily tick, so if the target's **lowest Ring ≤
  the Insight cap** a Ring reaches 0 → catatonic → 3 Contested Void Rolls (target vs the
  snapshot caster Void); dies if all 3 are lost by 5+. Death mirrors the maho
  mysterious-death path (`_apply_death_touch_kill`: GREAT_DESTINY → DOWN, else lethal
  wounds + suspicious death_event killer=caster + Tier 2 LEGAL mysterious-death topic,
  NEUTRAL subject_role). The affliction resolves and clears every tick regardless of
  outcome. New `@export death_touch_affliction: Dictionary` on L5RCharacterData (persists
  combat → world-sim, survives the caster's death via the caster_void snapshot).
  Verified: chain builds 1→2→3 (VP 2→1, stamped on the 3rd); a low-Ring victim is killed
  (death_event + topic + succession), a high-Ring target survives_drain, afflictions
  cleared. LIMITATIONS (no invented mechanics): "catatonic" is not a persistent condition
  (it is the context for the death rolls, resolved at the tick); a survivor's Rings are
  NOT permanently reduced (GDD gives no recovery rule, so the drain is the death-trigger
  mechanism only); excommunication is narrative (no mechanic). DEFERRED — 6 atemi need
  bespoke/blocked subsystems (Rest My Brother Taint, Sever the Dark Lord's Touch undead
  [s54], Banish All Shadows / Spin the Kharmic Wheel / Sense the Balance Advantage-system,
  Silent Solace spell-slot) plus Earth Palm's Fire option.

### s38 Kiho — effect registry, tranche 9: while-active buff round durations (2026-06-12)
Gave the round-duration while-active buffs proper auto-expiry (they previously persisted
for the whole skirmish — a real over-buff). New `Participant.active_kiho_expiry`
(kiho_name → expiry round) + `IndividualCombat.expire_active_kiho(p, round)` (mirrors
`expire_timed_modifiers`), called per participant in `advance_round`. `execute_activate_kiho`
records the expiry on activation from a new KIHO_DATA `duration` key (`{ring, mult}` →
round + mult × the activator's ring). Added durations to the 3 round-duration buffs:
**Embrace the Stone** (Earth Rounds), **Grasp the Earth Dragon** (Earth Rounds),
**Partaking the Waters** (2× Water Rounds). Indefinite buffs (Air Fist "one day",
Soul of the Four Winds "while active") have no `duration` key and persist for the skirmish.
Their Reduction/wound bonuses (read via the `_get_kiho_*` hooks off `active_kiho`) now
correctly stop once the kiho expires. All GDD-given. Verified: Embrace the Stone activated
round 1 (expiry 4 = round + Earth 3), removed from `active_kiho` after 3 round-advances
(round 4) while Air Fist (no duration) persists.

### s38 Kiho — effect registry, tranche 8: heal atemi (Chi Protection) (2026-06-12)
Encoded **Chi Protection** (Water 4 atemi: a touched willing ally regains Wounds equal
to the caster's Water Ring; 1 VP; cannot target self). Three additions: a `heal` spec
(`WoundSystem.heal_wounds(target, caster Water Ring)`), an `auto_hit` resolver param
(a willing ally — same faction — does not resist, so the to-hit is skipped), and the
`ally_auto_hit` spec flag that the orchestrator turns into auto-hit only for a
same-faction target plus the self-exclusion guard. `_npc_pick_atemi` now skips
`ally_auto_hit` atemi so the offensive NPC hook never delivers a heal to its enemy
target (Chi Protection stays reachable via `execute_atemi_strike` for a future
ally-healing AI / companion logic). 17 atemi encoded. All GDD-given (heal = Water Ring,
1 VP). Verified: ally heal (auto-hit, Water Ring 3 wounds, ally 10→7, VP 2→1),
self-target rejected (cannot_target_self), and `_npc_pick_atemi` excludes Chi Protection
(picks Flame Fist instead). LIMITATION: only the immediate heal is encoded — the
over-time portion (Water Ring at the start of each of the target's Turns for Insight
Rounds) needs `chars_by_id` in `begin_turn` (a signature change), deferred. DEFERRED —
7 atemi need bespoke/blocked subsystems (Rest My Brother Taint, Sever the Dark Lord's
Touch undead [s54], Banish All Shadows / Spin the Kharmic Wheel / Sense the Balance
Advantage-system, Death Touch multi-round, Silent Solace spell-slot) plus Earth Palm's
Fire option.

### s38 Kiho — effect registry, tranche 7: movement-denial atemi (2026-06-12)
Encoded **Speed of the Mountains** (Earth 4 atemi: target's Water Ring counts 2 Ranks
lower for Move distance, for 2× Earth Rounds). Extended the `timed` spec with
`duration_mult` (duration = mult × ring) and added `_effective_water_ring(p, character)`
— Water Ring minus any timed `move_water_penalty`, floored at 0 — used by both
orchestrator move-budget sites (`free_move_budget` and the NPC SIMPLE budget). 16 atemi
encoded. All GDD-given (−2 Ranks / 2× Earth Rounds). Verified: hit → target
`move_water_penalty` −2 (expiry round + 2× Earth), free move budget 4 → 2. LIMITATION:
the PC/companion SIMPLE-move UI paths (ascii_map_view) don't read the penalty yet — only
the orchestrator's own NPC/free moves do. DEFERRED — 8 atemi need bespoke subsystems
(Rest My Brother Taint, Sever the Dark Lord's Touch undead [s54], Chi Protection
heal-over-time [needs chars_by_id in begin_turn], Banish All Shadows / Spin the Kharmic
Wheel Disadvantage, Death Touch multi-round, Sense the Balance info, Silent Solace
spell-slot) plus Earth Palm's Fire option.

### s38 Kiho — effect registry, tranche 6: Earth Palm + end-to-end verification (2026-06-12)
Encoded **Earth Palm** (Earth 6 atemi, Water option: target suffers −4 damage dice
for Earth Ring Rounds) — extended the `timed` spec with `value_flat` (a fixed value,
vs `value_mult`×ring) and added a `damage_dice_penalty` timed read in `resolve_damage`
(the debuffed target's later damage rolls lose 4 dice while active). 15 atemi encoded.
The Fire option (+2 forced attack Raises) is deferred to a `forced_attack_raises` read
in resolve_attack; the NPC default is the Water (damage) option. All GDD-given (−4
dice / Earth Rounds). Verified: Earth Palm hit → target `damage_dice_penalty` −4
(expiry round + Earth), and the target's subsequent katana damage roll drops 6 → 2.
**End-to-end pipeline runtime-verified (2026-06-12):** a monk NPC in a real
`execute_npc_turn` (full setup_combat → stance pick → target select → atemi branch)
delivered an `atemi` action and the foe ended Dazed — confirming the whole tranche 1–5
chain (`_npc_pick_atemi` → `execute_atemi_strike` → effect) fires in live combat, not
just in isolated resolver calls. DEFERRED — 9 atemi still need bespoke subsystems
(Speed of the Mountains move-budget [multi-site], Rest My Brother Taint, Sever the Dark
Lord's Touch undead [s54], Chi Protection heal-over-time [needs chars_by_id in
begin_turn], Banish All Shadows / Spin the Kharmic Wheel Disadvantage, Death Touch
multi-round, Sense the Balance info, Silent Solace spell-slot) plus Earth Palm's Fire
option.

### s38 Kiho — effect registry, tranche 5: action-denial atemi (2026-06-12)
Encoded **As the Breakers** (Water 4 atemi: "target loses one Simple Action this
Round; only targets opponents who have not yet acted; once per skirmish") — the first
**orchestrator-applied** atemi effect (the denial touches the target's `TurnState`,
which the resolver can't reach, so the effect is applied in `execute_atemi_strike`,
same pattern as Censure's disarm flag). Two new spec gates checked in the orchestrator
before the strike: `requires_target_not_acted` (target's TurnState shows no
complex/simple/free action used) and `once_per_skirmish` (per-skirmish dedup via a new
`MapCombatState.once_per_skirmish_atemi` map). On a hit, `remove_simple_action` docks
the target's `simple_used += 1` (they keep at most one Simple, lose the Complex slot)
and marks them affected. 14 atemi encoded. All GDD-given (deny 1 Simple, not-acted
gate, once/skirmish). Verified: hit denies the Simple + marks affected; same-round
re-attack blocked (target_already_acted, since the denial set simple_used); cross-round
re-attack blocked (already_affected_this_skirmish, fresh TurnState); a target who has
already acted is rejected pre-strike. DEFERRED — 10 atemi still need bespoke subsystems
(Earth Palm forced-raises, Speed of the Mountains movement-budget [multi-site], Rest My
Brother Taint, Sever the Dark Lord's Touch undead, Chi Protection heal-over-time, Banish
All Shadows / Spin the Kharmic Wheel Disadvantage, Death Touch multi-round, Sense the
Balance info, Silent Solace spell-slot).

### s38 Kiho — effect registry, tranche 4: damaging atemi (2026-06-12)
Added the normal-unarmed-damage path to the atemi resolver plus three more spec
components, encoding 2 damaging atemi (13 atemi total). New components: `normal_damage`
({bonus_ring} → `resolve_damage(attacker,"unarmed", Ring, …)`, the full strength/kata
damage pipeline, normal Reduction), `vp_cost` (Void-Point activation cost spent as a
precondition), `attack_raises` (extra Raises required on the atemi to-hit), and
`condition_contest` (a Contested Ring roll gating ONLY the condition, not the damage).
Encoded **The Rolling Avalanche** (normal unarmed + Earth k0) and **Falling Star
Strike** (1 VP + 2 to-hit Raises → normal unarmed + Fire k Fire additional + Blinded
on a won Fire contest). `execute_atemi_strike` now skips consuming the action when the
atemi can't be delivered (e.g. insufficient Void), so the actor can still take a normal
attack. All values GDD-given (Rolling Avalanche +Earth k0; Falling Star 1 VP / 2 Raises
/ normal + Fire k Fire / Blinded contest). Verified with a headless driver: Rolling
Avalanche (9 damage), Falling Star (VP deducted, normal + ring damage, Blinded), and
the no-Void gate (insufficient_void, action not consumed). LIMITATION: Falling Star's
"Blinded for hours" is applied as the instant (roll-recovered) Blinded condition (the
combat-relevant portion). DEFERRED — 11 atemi still need bespoke subsystems beyond the
resolver (Earth Palm forced-raises, Speed of the Mountains movement, Rest My Brother
Taint, Sever the Dark Lord's Touch undead, As the Breakers action-economy, Chi
Protection heal-over-time, Banish All Shadows / Spin the Kharmic Wheel Disadvantage,
Death Touch multi-round, Sense the Balance info, Silent Solace spell-slot).

### s38 Kiho — effect registry, tranche 3: ring-DR damage + caster VP (2026-06-12)
Extended the composable atemi spec with **ring-scaled damage dice** (`rolled_ring`/
`kept_ring` → the attacker's ring value; the owner-set "DR equal to [Ring]"
convention = **Ring k Ring** exploding) and **`caster_vp_gain`** (capped at the
caster's Void Ring, with an optional `target_vp_required` gate). Encoded 2 more
atemi: **Touch of the Storm** (`contest` Air → Air k Air damage bypassing Reduction
— the existing contest gate means damage lands only on a won contest) and **Void
Fist** (regain 2 Void Points on a hit; no effect on a target without VP). 11 atemi
now encoded. All values GDD-given (Touch of the Storm DR per the owner's Ring k Ring
ruling; Void Fist 2 VP). Verified with a headless driver: Touch of the Storm both
branches (contest won → damage; contest lost → no effect), Void Fist both branches
(target with VP → caster +2; target without VP → no gain). DEFERRED (13 atemi, each
needs a bespoke subsystem this layer lacks): Earth Palm (choice forced-raises /
dice-penalty timed), Rest My Brother (Taint strip), The Rolling Avalanche &
Falling Star Strike (normal unarmed damage + bonus — the atemi path deals no normal
damage), Speed of the Mountains (movement-distance debuff), Sever the Dark Lord's
Touch (undead-only, s54), As the Breakers (action-economy loss), Chi Protection
(heal-over-time), Banish All Shadows (Disadvantage suppression), Death Touch
(multi-round Ring drain), Sense the Balance (info read), Silent Solace (spell-slot
tax), Spin the Kharmic Wheel (Disadvantage swap). Void Fist's "1 Raise to use" gate
is not modelled (NPC always uses it).

### s38 Kiho — effect registry, tranche 2: composable atemi effects (2026-06-12)
Made `resolve_atemi_strike`'s effect application **composable** — an `atemi_effect`
spec may now combine, in any mix: `damage` ({rolled, kept, bypass_reduction} →
`WoundSystem.apply_damage`), `disarm` (auto-disarm with optional `vp_negate`
{vp_cost, extra_rolled, extra_kept} — an NPC defender auto-spends VP to keep the
weapon and take the extra damage; PCs choose via future UI), `wound_rank_penalty`
({rank_ring, duration_rings, duration_insight} → a timed `all_rolls` penalty =
`Enums.WOUND_PENALTIES` at WoundLevel = the attacker's ring, for the summed
duration), `timed` (tranche 1), and `condition` (instant). Encoded 3 Air atemi:
**Censure of Thunder** (1k1 bypass + auto-Disarm; target may spend 2 VP to negate
the Disarm and take +2k2 instead), **Stain Upon the Soul** (wound-rank-equivalent
−penalty as if at Wound Ranks = Air Ring, for Insight + Air Rounds), **The Great
Silence** (silenced condition). 9 atemi now encoded (5 condition + Flame Fist +
these 3). All values GDD-given (Censure 1k1/2VP/2k2; Stain via the canonical wound
table; durations from the GDD). Verified with a headless driver: Censure both
branches (disarm vs VP-negate + extra damage + VP spent), Stain (−10 all_rolls at
Air 3, expiry round + Insight + Air), Great Silence (silenced). LIMITATIONS: Stain
stacks with the target's actual wound penalty (GDD says the worse one supersedes);
`silenced` is inert (no verbal-component system); the Disarm is a result flag
(weapon-drop not modelled — no inventory). DEFERRED — **Touch of the Storm**
("contested Air → damage with DR equal to Air Ring") needs an owner decision on the
DR interpretation (Air-Ring k Air-Ring vs Air-Ring k0 vs flat), so it is unencoded.

### s38 Kiho — in-combat activation cost path (2026-06-12)
`IndividualCombat.activate_kiho` did the known + active-slot validation but
explicitly deferred the s38a *cost* to the orchestrator, so nothing in the tile
loop could actually turn a kiho on with its proper price. Implemented
`AsciiMapCombatOrchestrator.execute_activate_kiho(state, char_id, character,
kiho_name, method, dice)` — the LOCKED s38a cost path, no invented values:
**void_point** = Free action, spends one Void Point (`VoidSystem.spend`), so it
does NOT consume the move/attack budget; **meditation_complex** = Complex action
+ Meditation (Void) roll vs `KihoSystem.ACTIVATION_TN_COMPLEX` (15);
**meditation_simple** = Simple action vs `ACTIVATION_TN_SIMPLE` (30). Order of
checks: dead/turn-state/participant guards → known → **atemi rejection** (atemi
kiho are strikes via `resolve_atemi_strike`, never slot buffs) → **slot check
(`KihoSystem.can_activate`) before any cost is paid** → method cost (Meditation
methods also honor the Down free-actions-only restriction; a failed Meditation
roll still spends the action, `action_spent:true`) → `IndividualCombat.activate_kiho`
installs it (re-checks slot). On success the kiho lands in `Participant.active_kiho`,
so the already-wired effect hooks (Air Fist Initiative, Soul of the Four Winds
Armor TN, Reduction buffs, etc.) fire on the next roll. Minimal monk-NPC hook
`_npc_maybe_activate_kiho` (structural AI, mirrors the other `_npc_*` heuristics —
the GDD gives no NPC activation policy): a MONK with a Void Point and an empty
slot buffs up with its first known non-atemi kiho via Void Point on its first
turn (wired into `execute_npc_turn` right after stance pick; PCs can't be monks
per s60.2, so this is the only caller). Validated end-to-end with a headless
SceneTree driver: void_point activation (VP −1, free action, kiho active),
slot constraint (2nd Internal → slot_occupied, no cost paid; Martial bypasses),
Meditation method (action consumed, VP untouched), the monk hook fires, non-monk
skipped. Parse-checked. **Monk companion hook added (2026-06-12):** the same
`_npc_maybe_activate_kiho` is wired into `execute_companion_turn` (after
begin_turn/decide_action, before movement/attack) so an allied monk companion on
a PC mission also buffs up — gated on a non-RETREAT command (a retreating/broken
companion doesn't stop to buff) and an empty slot. Verified end-to-end (a STEADY
NAMED_ALLY monk companion activates Air Fist via Void Point, buff appears in the
turn's actions). NOT yet wired: a player-facing activation UI choice (PCs aren't
monks per s60.2, so no PC monk path exists) and the non-combat character-level
kiho buffs (separate deferred infra).

### s38 Kiho — Combat Effects (first tranche wired into s40, 2026-06-06)
`KihoSystem` effects apply only while a kiho is ACTIVE on a combatant
(`IndividualCombat.Participant.active_kiho`), unlike passive katas.
**Wired so far:**
- Passive active-buffs via the kata modifier hooks: **Soul of the Four Winds**
  (Armor TN += Insight + Air ring), **Air Fist** (+5 Initiative while unarmed),
  **Grasp the Earth Dragon** (wound-penalty TN −Earth ring), **Embrace the Stone**
  (Reduction += 2× Earth), **Partaking the Waters** (Reduction += Water).
  `_get_kiho_armor_tn_bonus` / `_get_kiho_initiative_bonus` /
  `_get_kiho_wound_penalty_reduction` / `_get_kiho_reduction_bonus` are called
  alongside the kata equivalents in `get_armor_tn` / `roll_initiative` / the
  attack-roll wound path / `total_defender_reduction`.
- **Reduction pipeline** (`total_defender_reduction`): base armor + kata + kiho
  Reduction − attacker piercing, now fed into `WoundSystem.apply_damage` at the
  summary-combat and orchestrator hit sites. This also activated the previously-
  dead kata Reduction (earth_full_defense, earth_crab, water_ignore_reduction,
  water_small_weapon).
- **Atemi resolver** (`resolve_atemi_strike`): atemi attack with doubled armor TN;
  optional Contested Ring roll; applies an instant, roll-recoverable condition on
  hit. Wired: **Unbalance the Mind** (Dazed), **Freezing the Lifeblood** (Stunned),
  **Seven Storm's Fist** (contested Fire → Stunned), **Mind/No-Mind** (contested
  Void vs Fire → Dazed), **Tasaii-Do** (contested Water vs Earth → Stunned).
`activate_kiho()` validates known + the active-slot rule (one Internal/Kharmic/
Mystical, unlimited Martial). **Deferred (need infrastructure that doesn't exist
yet):** the activation COST path (Void Point / Meditation roll integrated into the
turn loop); **timed/duration conditions** (s40 conditions are flat + roll-recovered,
so "for N Rounds" effects, silenced, flat-TN-penalty, paralysis-with-no-move aren't
modeled); **character-level active kiho** for non-combat buffs (Stealth, Intelligence,
vision, water-walking — active_kiho is combat-Participant-scoped); **ASCII-map
movement** kiho (Riding the Clouds, Buoyed by the Kami, leaps); **ally/mount** kiho;
**healing-over-time** (per-round regen); and **unique** mechanics (Death Touch ring
drain, Spin the Kharmic Wheel disadvantage swap, Void Fist VP refund). 24 kiho-effect
tests in `tests/test_individual_combat.gd`.

### Systems Added 2026-06-16 (Dungeon content — Traps + Depth Gradient, owner-approved)
Two new dungeon-content systems for ASCII-map missions, decided via owner Q&A and
locked before coding (proposal in `DUNGEON_CONTENT_PROPOSAL.md`; a third feature,
Locks & Keys, was DROPPED — interior doors are paper screens and loot was already cut).
- **s56.20 Dungeon Traps** (`gdd/s56.20_dungeon_traps_locked.md`, `simulation/trap_system.gd`).
  Full set of 5 (Pit, Dart/Arrow, Snare→Entangled, Alarm/Tripwire, Deadfall) as a DATA
  layer (`AsciiMapData.traps`), not tiles — HIDDEN traps never render. `TrapSystem` (pure):
  `make_trap`, `is_loud`/`alerts_on_spring`, `trap_at`, `attempt_detect` (passive per-turn,
  Perception+Hunting vs detect_tn, within 2 tiles + FOV → DETECTED), `attempt_disarm` (better
  of Hunting:Traps or Sleight of Hand vs disarm_tn; miss by ≥10 springs it), `trigger`
  (Pit 2k2 + Athletics TN 15 to halve / Dart 2k2 vs flat-footed ATN 5+armor / Snare→Entangled
  escape TN 20 (s54.5 parity) / Alarm alert-only / Deadfall 3k2 + RUBBLE delta), and placement
  (`place_traps`, `roster_has_trap_layer`, `quality_for_strength`). Wired into `CombatController`
  (the exploration/stealth layer): springs a trap on the tile the player enters, runs passive
  detection each turn (`detect_traps`), and exposes `try_disarm_trap`; loud/alarm springs route
  through `_emit_noise`→AlertState (Pit/Deadfall LOUD, Alarm map-wide, Dart/Snare silent).
  **All trap paths no-op when `map.traps` is empty**, so trap-free missions (every existing
  template instance/test) are unaffected. `MissionBuilder.assemble()` calls `place_traps`
  after population. **All numbers PROVISIONAL** (GDD describes the mechanic, not the values;
  detect/disarm TN tiers 15/20/25/30). **Placement gate PROVISIONAL** — the roster carries no
  per-unit skill data, so `TRAP_LAYER_UNIT_TYPES` (scout units) stands in for "a Hunting:Traps
  unit is present"; the exact trap-laying unit set awaits owner confirmation. Setting basis:
  Crane Daidoji Hunting:Traps (s29.2/s11.7). Placement gate owner-confirmed 2026-06-16 =
  experienced ambushers + scouts (HIRUMA_SCOUT, NEZUMI_SCOUT, EXPERIENCED_BANDIT, BANDIT_LORD,
  RONIN_ENFORCER). **Player-facing UI wired (2026-06-16):** AsciiMapView renders DETECTED traps
  as a yellow `^` (HIDDEN never render), `K` disarms an adjacent DETECTED trap via
  `try_disarm_trap` (a turn → NPCs act), and spring/detect/disarm results surface as
  combat_events in CombatHUD's log (`K=disarm` added to the controls hint). Godot/GUT not run in
  this environment — validated by static review + parse-trace.
- **s56.21 Within-Map Depth Gradient** (`gdd/s56.21_within_map_depth_gradient_locked.md`).
  Depth = within-map difficulty gradient (path-distance from the player entry), NOT stacked
  floors (Option B explicitly not built). `AsciiMapData.depth_grid: PackedInt32Array` +
  `compute_depth_grid(entry)` (8-dir BFS over passable + door tiles; unreachable = -1),
  `depth_at`/`has_depth_grid`. `MissionBuilder.assemble()` fills the grid before population;
  `MissionPopulator._gather_candidates()` orders candidate slots deepest-first when the grid is
  present, so stronger roles (processed first) and the leader occupy deeper regions. Backward-
  compatible: `populate()` on a map without a computed grid keeps prior behavior. Spiritual-map
  palette shift with depth is now implemented (see s56.16.1b below). Headless
  (generation/population only).

### Systems Added 2026-06-16 (s56.16.1b Spiritual Overlap Palette — depth-driven, owner-approved)
- **s56.16.1b The Gradient — Visual Transformation (LOCKED).** `simulation/spiritual_palette.gd`
  (SpiritualPalette, pure class) implements the depth-driven palette shift the s56.21 lock named
  as "s56.16's concern" — the last depth-gradient consumer. A spirit realm overlaps Ningen-do;
  the deeper the player walks (toward the heart = the deepest reachable tile), the less the map
  looks like the mortal realm. Each tile carries an **overlap intensity 0.0..1.0** = `depth /
  max_depth` from `AsciiMapData.depth_grid` (entry 0.0 → heart 1.0; unreachable −1 → 0.0).
  **Non-destructive (owner-approved):** base tiles are never mutated — `display_tile(map,x,y)`
  derives the shown tile from base + intensity, so the LOCKED reversion ("the world heals in real
  time, spreading outward from the heart") is just raising `restoration_progress`
  (`current_intensity_at` heals tiles with intensity ≥ 1−progress first, i.e. the heart outward).
  **Three bands** (owner-approved cutoffs `MIDDLE_BAND=0.33`, `HEART_BAND=0.66`) matching the GDD
  outer/middle/heart prose. **Per-realm/element tile table (owner-approved 2026-06-16, PROVISIONAL
  — GDD specifies the flavour, the tile vocabulary is mortal-realm only):** Gaki-do → TREE_DEAD +
  FLOOR_ASH/RUBBLE (decaying); Toshigoku → TREE_DEAD + RUBBLE (battlefield); Chikushudo →
  BUSH/TREE_DECIDUOUS → TREE_EVERGREEN/BAMBOO (forest thickens); Meido → TREE_DEAD + FLOOR_SNOW/
  FLOOR_ASH (cold/grey); Fire → FLOOR_ASH/TREE_DEAD → FIRE; Water → WATER_SHALLOW → WATER_DEEP;
  Earth → RUBBLE; **Sakkaku/Yume-do/Air/Void → no tile change** (illusion/perceptual/mechanical
  per GDD, not a terrain palette). New `AsciiMapData` fields (all default-inert so every normal
  map is unaffected): `overlap_intensity: PackedFloat32Array`, `spiritual_realm`,
  `spiritual_element`, `spiritual_event_type` (−1 = none), `overlap_max_depth`,
  `restoration_progress`; helpers `has_overlap()`, `intensity_at()`. **Render hook wired:**
  `AsciiMapView._display_tile()` routes both visible and remembered tiles through
  `SpiritualPalette.display_tile` when `_map.has_overlap()` — a no-op for every non-spiritual map.
  Uses the canonical `Enums.SpiritRealm` / `Enums.Ring` / `Enums.SpiritualEventType` (no new
  enums). **Scope (owner: palette layer only):** the transform module + render hook only; NOT
  wired into a spiritual mission pipeline (no QuestSeedSelector spiritual seed / no realm threaded
  through MissionBuilder — that larger s56.16 ASCII-encounter effort stays blocked). `apply_overlap`
  is the ready API for that future pipeline; the render hook is live (gated), so the layer is
  consumable, not dead code. LIMITATIONS: rubble-sprinkle fraction (1/4) PROVISIONAL; Meido's
  "colors drain" is carried by tile substitution only (no separate desaturation pass — GDD gives
  no colour-shift values); Godot/GUT unavailable here — validated by static review + parse-trace.

### Systems Added 2026-06-16 (s56.16 Spiritual encounter — ritual loop + Gaki-do roster data, owner-approved)
- **s56.16.5b–5f Restoration Ritual + s56.16.6b Gaki-do roster (tranche 1).** Two pure
  simulation classes + one data Resource, all faithful transcriptions of the LOCKED s56.16 /
  s54.10 / s54.2 specs. Scope confirmed with owner 2026-06-16: ritual-loop resolution + Gaki-do
  bestiary/roster data; **live ASCII creature combat, exposure mechanics, and the other five
  realms' rosters are deferred** to follow-up tranches (the special-ability combat is substantial
  s40 work).
  - **`shared/spirit_creature_data.gd`** (SpiritCreatureData Resource) — a spirit stat block:
    rings, named traits, initiative/attack/damage, Armor TN, Reduction, wound thresholds +
    `wounds_dead`, Fear, `Tier` (SWARM/MID/HEAVY/BOSS/TERRAIN/POST_ENCOUNTER), and special-ability
    `tags` for the future combat layer.
  - **`simulation/spirit_bestiary.gd`** (SpiritBestiary, pure) — `gaki_do_catalog()` transcribes
    all 11 Gaki-do roster creatures from s54.10 (Muzai-gaki, Usai-gaki Swarm, Jikininki, Haraigaki,
    Fukuregaki, Kagaki, Gashadokuro, O-Toyo, Mokumokuren, Buruburu) + Shozai-Gaki from s54.2 — exact
    stat lines, no invented values. `gaki_do_pool(terrain, famine, settlement)` returns the
    zone→creature-id pool per the Encounter Flow (s56.16.6c) with the LOCKED availability gates
    (Gashadokuro famine-only, O-Toyo forest-only, Mokumokuren settlement-only). The roster is a
    threat *pool* (the GDD's escalation model is emergent, not fixed headcounts — so no counts are
    invented).
  - **`simulation/spiritual_ritual_system.gd`** (SpiritualRitualSystem, pure) — the shugenja-side
    Restoration Ritual: `DURATION_BY_SEVERITY` 10/20/30/50 (LOCKED), `REALM_TRAIT` and
    `ELEMENT_COUNTER` tables (LOCKED s56.16.5c/5d), `diagnose()` (Perception + Lore: Theology vs
    TN 15), `resolve_ritual_round()` (Lore: Theology + realm-trait OR + counter-Ring vs the ritual
    TN; damage-this-round auto-fails the round, prior progress preserved; wrong/undeclared
    elemental counter yields no progress), `run_summary_ritual()` (multi-shugenja stacking +
    optional per-round interruption set — the headless/abstract path; the live turn loop will call
    resolve_ritual_round per round), `classify_outcome()` + `apply_resolution()` (the s56.16.5f
    spectrum: FULL→resolved + overlay fully reverts via SpiritualPalette.advance_restoration(1.0);
    PARTIAL→banks cumulative progress + proportional revert; RETREAT/FAILURE→one-season intensity
    spike, no progress banked), and `post_resolution_affliction_check()` (Catastrophic-only
    Willpower vs TN 20). **The one number the GDD leaves open — the per-round ritual TN — is
    owner-set to flat 15** (matches the diagnosis roll; recorded as `RITUAL_TN`). PC-only: NPCs
    never use the ASCII map, so there is NO NPC auto-resolver (the prior invented one was removed
    2026-05-26). Two `SpiritualInsurgencyData` fields added (`ritual_rounds_completed` for
    cross-mission progress persistence per s56.16.5f, `intensity_spike_until_season` for the
    retreat/failure spike); both default-inert and persist via WorldStateSaver's Resource array.
  - **Wiring:** these are pure, callable systems — the live consumer is the deferred ASCII combat
    turn loop. No orchestrator/seasonal wiring this tranche (NPCs don't resolve these; the
    intensity-spike decay in the seasonal pass is forward-wired with no producer yet). Godot/GUT
    unavailable here — validated by static review + parse-trace (DiceResult.total, Enums.Trait /
    Ring / TerrainType members, CharacterStats.is_dead, SpellSystem.get_ring_value,
    SkillResolver.resolve_skill_check signatures all confirmed). DEFERRED: live creature combat
    + special abilities (incorporeal/swarm/wail/hunger-pull/fire-trail), the Gaki-do exposure
    mechanic (Willpower erosion / Willpower-0 transformation / Buruburu attachment / Jigoku-
    corrupted Shozai-gaki).
- **s56.16.8e / 9c Toshigoku + Sakkaku rosters (tranche 2, owner-approved 2026-06-16).**
  Extended `SpiritBestiary` with two more fully-LOCKED rosters. `_make` gained a trailing
  `realm` param (defaults Gaki-do; existing calls untouched). **Toshigoku** (`toshigoku_catalog()`
  + `toshigoku_pool()`): all 7 creatures from s54.10 — Musha Recruit, Ashigaru Musha (Spear),
  Bow Ashigaru Musha, Musha Soldier, Musha Commander, Ancient General (boss), Phantom Battle
  (environmental hazard, not_creature). **Sakkaku** (`sakkaku_catalog()` + `sakkaku_pool()`):
  Kappa (s54.2), Bakeneko, Konak Jiji, Mujina (illusion engine), Pekkle (s54.10) — pool follows
  the GDD's real-threats/deceptions split (s56.16.9c) rather than inventing zone tiers.
  All stat lines are exact transcriptions — no invented values or headcounts. **Still DEFERRED:**
  **Chikushudo** (s56.16.7b) — its territorial defenders (spirit wolves/boars/bears/stags/
  eagles/snakes) are natural-animal bases (s54.1) and the GDD documents only the bear's +2-Earth
  overlay, so a faithful transcription needs the s54.1 natural stats + the overlay rule (the 3
  explicit creatures — Kitsune, Kitsune-tsuki, Hengeyokai Spirit Lord — ARE fully statted and
  could be added when that's resolved). **Meido and Yume-do** have NO roster/encounter section in
  s56.16 (only the 56.16.5c restoration approach) — nothing to transcribe; blocked on GDD content.
  Plus the live creature combat + exposure mechanic from tranche 1.
- **s56.16.7b Chikushudo roster (tranche 3, owner-approved 2026-06-16).** Completes the four
  statted realms. The territorial-defender spirit animals are NOT new species — the LOCKED
  "Chikushudo Spirit Animal Overlay" (s54.10) is fully specified (**all Rings +2 over the s54.1
  base, cascading to derived stats; Swift +1; Spirit; no Fear; Taint 0**), so the owner question
  about a "general buff" was moot (the bear's "+2 Earth" was just an instance of the +2 rule).
  To avoid inventing re-derived numbers, `chikushudo_catalog()` stores the **s54.1 base** stat
  block verbatim for the 7 spirit animals (Wolf/Boar/Bear/Stag/Eagle/Hawk[=Falcon]/Snake[=Asp]),
  tags each `chikushudo_spirit`, and exposes the overlay as documented constants
  (`CHIKUSHUDO_RING_BONUS=2`, `CHIKUSHUDO_SWIFT_BONUS=1`) for the deferred combat layer to apply.
  The three named denizens (Kitsune, Kitsune-tsuki, Hengeyokai Spirit Lord) have explicit s54.10
  blocks — stored as-is. `chikushudo_pool()` follows the 7b/7f zone flow. NOTE (GDD inconsistency,
  left unedited): s56.16.7b's bear example says "Earth 4 base becomes Earth 6," but the actual
  s54.1 Bear is Earth 6 — s54.10's overlay section is explicit that the base comes from s54.1, so
  the stored base is Earth 6 (overlay → 8). **Now done: all four realms that HAVE rosters in
  s56.16** (Gaki-do, Toshigoku, Sakkaku, Chikushudo). **Meido and Yume-do remain blocked** — s56.16
  gives them no roster/encounter section at all (only the 56.16.5c restoration approach), so there
  is nothing to transcribe without inventing. Still deferred: the live ASCII creature combat +
  special abilities, and the per-realm exposure mechanics.
- **s56.16 per-realm Exposure mechanics (tranche 4, owner-approved 2026-06-16).**
  `simulation/spiritual_exposure_system.gd` (SpiritualExposureSystem, pure) — the "being
  somewhere you do not belong erodes you" resolver for all four encounter realms, operating on a
  per-character exposure-state Dictionary (`new_state(realm, base_willpower)`) the deferred combat
  turn loop owns. PC-only. All values LOCKED. **Periodic check** (`roll_periodic_check`): per-realm
  interval (Chikushudo per-minute ≈ 10 rounds; others per-10-min ≈ 100), starting TN
  (Gaki 10 / Toshigoku 15 / Sakkaku 10 / Chikushudo 10) rising by step (Sakkaku +2, others +1);
  Sakkaku rolls max(Awareness, Willpower), the rest Willpower; supports creature-stacking
  `extra_tn` (Gaki Muzai swarm / Gashadokuro Bone Rattle), Toshigoku crystal `+2k0`, and an
  `advance_tn=false` mode for the Toshigoku per-combat trigger (`toshigoku_combat_trigger`).
  **Per-realm failure effects:** Gaki/Toshigoku lose a Willpower Rank (→ Muzai-gaki / slaughter
  transformation at 0; `lowest_wp_seen` tracked); Sakkaku accrues Compulsion failures (flags any
  failure at TN ≥ 20); Chikushudo accrues pacification failures (-1 Init / -1k0 vs spirit animals
  each, pacified at 5). **Toshigoku 8b thresholds:** `toshigoku_combat_modifier` (-1k0 Social /
  +1k0 damage at -2 Ranks), `toshigoku_must_roll_to_retreat` / `_attacks_indiscriminately`
  (reduced TO 2 / TO 1), and the TN-15 disengage / TN-20 regain-control rolls. **Chikushudo
  `chikushudo_snap_out`** (ally Contested Willpower removes one failure level). **Recovery**
  (`recover_outside`): Gaki/Toshigoku +1 Rank/10 min, Sakkaku -1 failure/hour, Chikushudo
  immediate. **Post-encounter:** `gaki_buruburu_check` (25% if lowest WP < 2, s56.16.6e),
  `toshigoku_post_consequences` (Brash / Brash+Overconfident by lowest WP, permanent if rescued
  from WP 0, s56.16.8c), `sakkaku_post_consequences` (Obtuse one season at 4+ failures; 25%
  permanent minor Disadvantage if any failure at TN 20+, s56.16.9a). **Jigoku-corrupted Shozai
  (s56.16.6d):** `corrupted_shozai_chance(ptl)` (5/15/30/50% by PTL) + `corrupted_shozai_taint_check`
  (Earth vs TN 15 per melee hit). Haraigaki Wail direct loss via `apply_willpower_loss`. Returns
  consequence descriptors (disadvantage name strings, flags) for the combat/world layer to apply;
  does not mutate the character (consistent with the ritual system). No NPC path (PC-only). Godot/
  GUT unavailable here — validated by static review + parse-trace (DiceEngine.randf/roll_die/
  roll_and_keep.total, SpellSystem.get_ring_value, character.awareness/willpower confirmed).
  DEFERRED: wiring into the live ASCII turn loop (combat tranche), and the slow "left-behind →
  permanent transformation" timers (Gaki-do 6f one-hour soul-return, Chikushudo 7a multi-day
  animal transformation) which need a cross-session timer the encounter layer will own.
- **s56.16 MissionBuilder spiritual wiring (tranche 5, owner-approved 2026-06-16).**
  `MissionBuilder._assemble_spiritual()` now enriches the spiritual mission package with the data
  the (deferred) ritual/exposure combat loop consumes — the connective layer between the headless
  data/math systems and the future turn loop. Added to `environment["spiritual"]` (+ a top-level
  `roster_pool`): the **roster pool** via `_spiritual_roster_pool()` (realm overlaps → the realm's
  zone→creature-id pool with gates: Gaki-do uses `province.starvation_stage>0 || crisis_type=="famine"`
  for the Gashadokuro famine gate, `province.terrain_type` for O-Toyo forest, settlement=false since
  the overlap reuses the terrain template not a settlement map; elemental imbalances + Meido/Yume-do
  → `{}`); the **ritual metadata** via `_spiritual_ritual_meta()` (duration by severity, RITUAL_TN 15,
  and the approach — realm trait for overlaps, counter Ring for imbalances); the **exposure realm**
  (the combat layer calls `SpiritualExposureSystem.new_state(realm, pc.willpower)`); and the **heart
  tile** via `_find_heart_tile()` (deepest reachable depth-grid tile, s56.16.5a). Purely additive —
  existing keys unchanged, `placements`/`roster` still empty (live creature combat remains the next
  tranche). Validated by static review + parse-trace (SpiritBestiary pool fns, SpiritualRitualSystem
  DURATION_BY_SEVERITY/RITUAL_TN/counter_ring/REALM_TRAIT, ProvinceData.starvation_stage/crisis_type,
  AsciiMapData depth API all confirmed). With this, the headless s56.16 pipeline is end-to-end: a
  spiritual seed → map + overlay + roster pool + ritual/exposure/heart metadata, ready for the
  combat turn loop to drive.
- **s56.16/s54.10 creature special abilities (tranche 6, owner-approved 2026-06-16).**
  `simulation/spirit_ability_system.gd` (SpiritAbilitySystem, pure) — the reusable mechanic layer
  the deferred ASCII combat loop hooks into, keyed on `SpiritCreatureData.tags`. All values from
  the LOCKED s54 stat blocks. **Damage filter** (`incoming_damage(creature, weapon_kind)` →
  {multiplier, heals, no_explode}): incorporeal (physical→0, magic/crystal→1), superior_invuln
  (only magic/jade), partial_invuln (mundane→0), Pekkle half+no-explode, Kagaki fire-immune/heals
  + water-double; lowest-multiplier-wins compose. `is_immune()`, `reduction_for_kind()` (Usai-gaki
  Reduction-10-vs-normal). **Attack-side:** `attack_bypasses_armor()` (Shozai ignores_armor /
  Kitsune-tsuki spirit_strike / Mokumokuren gaze), `deals_unhealable_spiritual_damage()` (gaze),
  `on_hit_self_heal()` (O-Toyo +5), `has_regeneration()` / `reforms_on_death()`. **Exposure feeds**
  (consumed by SpiritualExposureSystem): `willpower_tn_contribution()` / `total_willpower_tn()`
  (Muzai swarm +1 each, Gashadokuro Bone Rattle +2 → the `extra_tn` for periodic checks),
  `wail_effect()` (Haraigaki: within 5 tiles, Willpower TN 20 → -1 Rank + lose next Simple). Pure,
  returns descriptors/modifiers, mutates nothing. DEFERRED to the combat-loop tranche (need live
  grid/turn-state): the positional/turn abilities — hunger_pull, engulf, fire_trail spread, illusion
  tiles, possession, paralysis_venom, deceptive_weight, phantom_battle tile damage, invisibility,
  shapeshift disguise, and mob_frenzy/rally group counts. Validated by static review + parse-trace
  (SpiritCreatureData.has_tag/.reduction, minf/maxf confirmed; no external deps).
- **s56.16 live-combat adapter (tranche 7, owner-approved 2026-06-16).**
  `simulation/spirit_combatant.gd` (SpiritCombatant, pure) — the foundational adapter for the live
  ASCII spiritual encounter: `to_character_data(creature, instance_id)` converts a SpiritCreatureData
  stat block into a combat-ready L5RCharacterData "puppet" the AsciiMapCombatOrchestrator consumes
  as a participant (the orchestrator is character_id-keyed over L5RCharacterData, so creatures need
  this wrapper). `catalog_for_realm()` + `spawn(realm, creature_id, instance_id)` instantiate puppets
  on demand (escalation, s56.16.5e). New inert field `L5RCharacterData.spirit_creature: SpiritCreatureData`
  (null for real characters) stores the source so the ability/override layer can read it.
  **FAITHFUL** (the existing combat math reads these directly): the four Rings (via paired traits,
  ring = min of pair), named-trait overrides (Reflexes/Agility/Strength/… drive init/attack/damage),
  Armor TN (back-calc into armor_tn_bonus so get_armor_tn = Reflexes×5+5+bonus returns the creature's
  value), natural Reduction (armor_reduction), and the natural-weapon DAMAGE dice (strength_adds=false).
  Void Ring forced to 0 (spirits have none). **APPROXIMATED until the orchestrator override layer**
  (the next, runtime-verifiable tranche): the to-HIT roll (PC trait+skill vs the creature's fixed
  Xk Y — stored on spirit_creature.attack_rolled/kept for the override) and the WOUND track (PC
  Earth-derived capacity vs the creature's explicit wounds_dead/thresholds — also on spirit_creature).
  Special abilities apply via SpiritAbilitySystem (tranche 6) off the tags. **Scope/risk note:** the
  live turn loop (spawning creatures into setup_combat with escalating threats, the bushi-defends-
  shugenja loop driving ritual+exposure+abilities per round, encounter outcome) AND the exact
  attack/wound overrides modify the core combat orchestrator and are NOT runtime-verifiable in this
  environment (no Godot binary) — deferred to a tranche that can be driver-verified, to avoid pushing
  a large unverified change into core combat. This adapter is isolated (new file + one inert field;
  orchestrator/IndividualCombat untouched) and validated by static review + parse-trace
  (character_name/void_ring/armor_reduction/armor_tn_bonus/weapons[WeaponData] fields, get_armor_tn
  formula, WeaponData fields, SpiritBestiary catalogues all confirmed).
- **s56.16 live encounter driver + combat hook (tranche 8, owner-approved 2026-06-16, static-only).**
  Owner chose to build the live integration now despite no Godot runtime here (driver-verify later).
  Two pieces: (1) **`simulation/spiritual_encounter.gd`** (SpiritualEncounter, pure) — the per-round
  SPIRITUAL layer on top of AsciiMapCombatOrchestrator. `start()` builds the encounter (PCs at the
  entry, initial heart-zone creatures placed on the heart ring via SpiritCombatant.spawn, exposure
  states per PC) and calls `setup_combat`. `process_round()` (called per combat round) runs the
  Restoration Ritual (each living shugenja contributes a round; interrupted if they took damage since
  last round — wounds-delta tracked), the periodic Exposure check (timer per realm interval, with
  `extra_tn` = co-located creature swarm/rattle stacking via SpiritAbilitySystem), and reports
  ritual progress/completion + shugenja-alive. `resolve()` applies the s56.16.5f outcome to the event
  + map overlay (idempotent). The orchestrator owns movement/turn-order/attack resolution (the player
  drives PC+bushi turns; creatures act via execute_npc_turn). (2) **`_apply_hit` spirit hooks** in
  AsciiMapCombatOrchestrator (guarded by `spirit_creature != null`, inert for real characters): a
  spirit TARGET filters incoming damage by weapon kind (SpiritAbilitySystem.incoming_damage —
  incorporeal/partial-invuln/Pekkle-half/Kagaki fire; weapon kind defaults mundane, which is
  faithful — physical weapons don't permanently destroy spirits, the ritual is the win condition); a
  spirit ATTACKER that bypasses armor (Shozai/spirit_strike/gaze) ignores Reduction; a spirit
  attacker with life_drain self-heals on hit. Static-validated only (heal_wounds/incoming_damage/
  attack_bypasses_armor/setup_combat/MapCombatState fields/MovementSystem.is_passable confirmed; the
  _ORC class-alias-const and inner-class outer-const-default hazards were removed). DEFERRED (need
  Godot driver-verify and/or more orchestrator work): mid-combat threat ESCALATION (adding creature
  participants to a live MapCombatState — the risky internal insertion), the exact creature to-HIT
  roll and WOUND-track overrides (the SpiritCombatant PC-approximation stands), weapon-material
  detection for jade/crystal damage (no WeaponData material field), and the creature-turn firing of
  positional abilities (hunger-pull, wail-as-action, fire-trail, possession). With this the s56.16
  encounter is wired end-to-end in shape; the live turn loop needs runtime verification before relying on it.
- **s56.16 mid-combat threat escalation (tranche 9, owner-approved 2026-06-16, static-only).**
  Closes the largest deferred piece of tranche 8. New `AsciiMapCombatOrchestrator.add_enemy()`
  adds a creature participant to a LIVE MapCombatState (initiative roll, turn-order re-sort,
  TurnState) — mirrors `add_companion`'s insertion exactly, FACTION_ENEMY, no companion
  bookkeeping. `SpiritualEncounter.spawn_threat(es, zone, dice)` spawns the next un-spawned pool
  creature of a zone tier on a free tile near the heart (`_free_tile_near` expanding-ring search,
  unoccupied + passable). `process_round` now drives escalation: the initial spawn is the weakest
  tier (outer / Sakkaku deceptions) on the heart ring; deeper tiers appear as the ritual
  progresses, with waves triggered at the **LOCKED** depth-band cutoffs (`SpiritualPalette.MIDDLE_BAND`
  0.33 → middle, `HEART_BAND` 0.66 → heart; Sakkaku reveals real_threats at the 0.5 midpoint) —
  reusing locked values, NOT an invented schedule. One creature per wave, bounded by pool size
  (`_zone_idx` per-zone cursor; `_waves_done` caps at ≤2, no runaway spawning). The escalation
  fraction = ritual_progress / rounds_remaining, so threats deepen in lockstep with the shugenja's
  progress. Static-validated only (add_enemy mirrors add_companion; SpiritualPalette band consts,
  pool zone keys, MovementSystem.is_passable, Vector2i dict keys confirmed). STILL DEFERRED to a
  runtime tranche: exact creature to-HIT/wound overrides (SpiritCombatant approximation stands),
  weapon-material detection (jade/crystal), and the creature-turn firing of positional abilities
  (hunger-pull, wail-as-action, fire-trail, possession). With escalation, the live s56.16 encounter
  loop is complete in shape (setup → per-round ritual+escalation+exposure → resolution); only the
  per-creature combat fidelity + positional-ability turns remain, both needing a Godot runtime.
- **s56.16 exact creature combat fidelity (tranche 10, owner-approved 2026-06-16, static-only).**
  Replaces the SpiritCombatant to-hit/wound approximation with the stat-block values, via two
  minimal guarded hooks (both inert for real characters — `spirit_creature == null`):
  (1) **Wound track** — `CharacterStats.get_wound_level` and `get_total_wound_capacity` honor the
  creature's explicit `wounds_dead` + per-level `wound_thresholds` instead of the PC Earth×2 formula.
  New `_spirit_wound_level()`: DEAD at `wounds_dead`; otherwise the level index = how many cumulative
  `wound_thresholds` the wounds have exceeded (proportional fallback if a creature has no thresholds).
  This propagates everywhere automatically (is_dead, wound penalty, damage clamp) since it is the
  single wound-level source. (2) **To-hit roll** — `IndividualCombat.resolve_attack` uses the
  creature's fixed `attack_rolled k attack_kept` instead of the PC trait+skill roll, applied before
  the kata/void modifiers (creatures have none). Combined with the already-faithful damage
  (WeaponData rolled/kept, strength_adds=false), Armor TN (back-calc), and Reduction, spirit combat
  is now stat-faithful for to-hit, damage, defense, AND death. Static-validated only (SpiritCreatureData
  attack_rolled/attack_kept/wounds_dead/wound_thresholds fields, the wound-level chain, and resolve_attack
  roll construction confirmed). REMAINING approximations (minor, documented): initiative still uses the
  puppet's Reflexes+Insight (not the creature's initiative_rolled/kept), and weapon-material detection
  (jade/crystal vs the damage filter) awaits a WeaponData material field. Plus the creature-turn firing
  of positional abilities (hunger-pull, wail-as-action, fire-trail, possession). All of tranches 7–10
  are static-only and need a Godot runtime to driver-verify.
- **s56.16 creature positional abilities, tranche 1 (tranche 11, owner-approved 2026-06-16, static-only).**
  The last functional s56.16 gap — creatures now use their grid/AoE abilities, not just plain attacks.
  Two of the s54.10 positional abilities wired (both fully numeric in the locked stat blocks, no
  invented values): (1) **Hunger Pull** (Fukuregaki, Passive) — `SpiritualEncounter._apply_hunger_pull`
  runs at the START of each round (a new step 0 in `process_round`): every living PC within
  `HUNGER_PULL_RADIUS` (4) tiles of a `hunger_pull` creature rolls Earth vs `HUNGER_PULL_TN` (15);
  on failure they are dragged 1 tile toward the creature (8-dir step, blocked by the creature's own
  tile / another occupant / a map edge / an impassable tile). (2) **Wail of the Starving** (Haraigaki)
  — new public `SpiritualEncounter.creature_turn(es, cid, dice)`: a `wail` creature spends its
  Complex action so every PC within 5 tiles rolls Willpower vs `WAIL_TN` (20), and failure costs a
  Willpower Rank via `SpiritualExposureSystem.apply_willpower_loss` on the PC's exposure state; any
  other creature delegates to the standard NPC AI turn (`execute_npc_turn`). The encounter caller
  routes ENEMY turns through `creature_turn` (instead of `execute_npc_turn` directly) so the
  AoE/positional abilities fire. New ability-layer helpers `SpiritAbilitySystem.hunger_pull_effect`
  + `HUNGER_PULL_*` constants (mirrors the existing `wail_effect`). Static-validated only
  (`apply_willpower_loss`/`new_state`, `execute_npc_turn` 5-arg signature, `get_earth_ring`,
  `roll_and_keep(...).total`, TurnState `can_use_complex`/`consume_complex` via untyped dynamic call
  to dodge the inner-class type-resolution hazard, `pc_ids`/`exposure` populated in `start`, the
  Fukuregaki/Haraigaki tags confirmed). DEFERRED (need grab-state / tile-fire / condition / illusion /
  possession systems the core lacks, OR are GM-judged): engulf-on-adjacent grab (Fukuregaki/Usai swarm),
  fire_trail + Everything Burns (Kagaki — needs tile-fire spread + an on-fire condition), paralysis_venom
  (Konak Jiji — needs a Stunned-for-minutes condition), phantom_battle tile damage (environmental
  3×3–5×5 hazard that shifts), possession / shapeshift / invisibility / mob_frenzy / rally. As with
  tranches 7–10, static-only — needs a Godot runtime to driver-verify.
- **s56.16 engulf grab state (tranche 12, owner-approved 2026-06-16, static-only).**
  Builds the creature grab state and wires Fukuregaki Engulf + the Usai swarm grab (s54.10).
  New `EncounterState.engulfed` (pc_id → captor creature_id). **Auto-grab:** `_apply_hunger_pull`
  now seizes a non-engulfed PC who is (or is dragged) adjacent to an `engulf`-tagged creature;
  engulfed PCs are skipped by the pull (held in place). **Crush tick:** new `_apply_engulf_crush`
  (process_round step 0b) applies the captor's crushing damage (creature `damage_rolled k
  damage_kept`, exploding) to each engulfed PC every round via `WoundSystem.apply_damage`; the
  grab releases if the captor dies, the PC dies, or the captor is no longer adjacent. **Escape:**
  new public PC-action `attempt_engulf_escape(es, pc_id, dice, full_move=false)` — Fukuregaki
  (engulf) = Contested Strength vs the captor's `traits["strength"]`; Usai swarm = release if the
  PC's Water Ring is 3+ OR a Full Move is spent. **Immobile guard:** `creature_turn` now returns
  early for `immobile` creatures (Fukuregaki) so the generic AI can't walk the engulfer off and
  release its own grab — its threat is the passive pull/crush. All values from the locked s54.10
  stat blocks (Fukuregaki 3k3 crushing / Strength 5; swarm Water 3+/Full Move). Static-validated
  only (engulf/swarm/immobile tags on the creatures, `damage_rolled/kept` + `traits["strength"]`
  + `water` fields, `WoundSystem.apply_damage(char, int)`, `get_ring_value(WATER)`, `.keys()`-copy
  safe erase-during-iteration confirmed). DEFERRED unchanged: fire_trail/Everything Burns,
  paralysis_venom, phantom_battle, possession/shapeshift/invisibility/mob_frenzy/rally. Static-only
  — needs a Godot runtime to driver-verify.
- **s56.6.6 Fire Propagation + s54.10 Kagaki fire (tranche 13, owner-approved 2026-06-16, static-only).**
  Builds the tile-fire layer (s56.6.6, all values PROVISIONAL per the GDD — none invented) and wires
  the Kagaki's fire abilities. **`simulation/fire_system.gd`** (FireSystem, pure) over a new
  AsciiMapData fire layer (`burning_tiles: Dictionary` idx→rounds_left, `wind_dir: Vector2i`):
  `ignite(map,x,y)` (flammable + not-already-burning → set FIRE tile + fuel duration);
  `process_round_end(map, weather, dice)` — the end-of-round tick: Storm/Blizzard extinguish all,
  Rain forces a 1-round burnout + no spread, Snow no spread; otherwise spread to flammable
  neighbours at `spread_chance` (Clear/Mist 30% uniform; Wind 60% downwind / 15% lateral / 0%
  upwind, classified by dot-product with `wind_dir`), then decrement durations and convert burned-out
  tiles to FLOOR_ASH (new ignitions applied after the tick so they don't cascade/decrement the same
  round); `standing_damage` 1k1 / `passthrough_damage` 0k1 (armour does not reduce); `fuel_rounds`
  (grass/leaves 3, crops 4, undergrowth/light-wood 5). **Encounter wiring** (SpiritualEncounter):
  `_apply_fire_damage` (process_round step 0c) deals 1k1 to a PC standing on a burning tile AND/OR
  set on fire; `FireSystem.process_round_end` runs at round end (gated to non-empty fire); `creature_turn`
  fires `_apply_fire_trail` for `fire_trail` creatures (Kagaki Fire Trail + Burning Hunger — own tile
  + 8 neighbours, 50% ignite per flammable tile, LOCKED s54.10); `attempt_extinguish(es, pc_id)` PC
  action spends a Simple to clear the on-fire flag. **Everything Burns** (s54.10, LOCKED): new
  `Participant.on_fire`; a guarded hook in the orchestrator's `_apply_hit` (tranche-8-consistent) sets
  the target on fire when a `fire_trail` spirit lands a hit (Kagaki is melee-only). Static-validated only
  (AsciiMapData.is_flammable/set_delta, WeatherState members, SpiritCreatureData.has_tag,
  Participant.on_fire, mcs.combat.participants access, roll_and_keep(0,1)=0 no-crash, .keys()-copy
  safe erase confirmed). LIMITATIONS: weather/wind not yet threaded from the mission into the encounter
  (`es.weather` defaults CLEAR / no wind — spiritual overlaps reuse the terrain template); smoke/coughing
  + ignition/burning noise (s56.6.6) not modelled; grass is non-flammable here because AsciiMapData's
  `_BURN_MAP` (the flammability definition) excludes FLOOR_GRASS (dry/green not tile-distinguishable).
  DEFERRED unchanged: paralysis_venom, phantom_battle, possession/shapeshift/invisibility/mob_frenzy/rally.
  Static-only — needs a Godot runtime to driver-verify.
- **s56.6.6 weather/wind wiring + fire ownership move (tranche 14, owner-approved 2026-06-16, static-only).**
  Threads mission weather + wind into the fire layer and relocates fire damage/spread to the shared
  turn machinery so it works for ALL combat (arson, fire spells), not just the spirit encounter.
  **Wind:** `MissionBuilder._assign_wind` stamps a deterministic random 8-bearing (`_WIND_BEARINGS`,
  seed-derived) onto `map.wind_dir` at both `assemble` and `_assemble_spiritual` (s56.6.6: random at
  gen, fixed for the mission, only relevant during Wind). **Weather:** `MapCombatState.weather` +
  a defaulted `weather` param on `setup_combat` (all existing callers/tests unaffected);
  `MissionSession.weather()` accessor (mirrors `fov_modifier()`) for the future mission→orchestrator
  glue. **Ownership move (avoids a double-apply foot-gun):** fire damage (1k1 standing + 1k1 on-fire,
  armour-ignoring, `flame_immune` creatures exempt — Kagaki) and the end-of-round
  `FireSystem.process_round_end` spread/extinguish tick now run in `AsciiMapCombatOrchestrator.advance_round`
  (the shared per-round machinery, alongside the existing Way-of-the-Earth / Ride-the-Water-Dragon
  per-round effects). The tranche-13 encounter-local fire damage + tick (`_apply_fire_damage`, the
  process_round_end call, `es.weather`) were REMOVED — the encounter keeps only Kagaki Fire Trail
  ignition (`_apply_fire_trail` in `creature_turn`) and the PC `attempt_extinguish`. `SpiritualEncounter.start`
  gains a `weather` param threaded into `setup_combat`. Net: when the (deferred) live encounter loop is
  wired it drives `advance_round` for turn machinery, so fire applies once per round with no duplication;
  general skirmishes get fire for free. Static-validated only (setup_combat arity back-compat, wind dot-product
  classification, flame_immune guard, no dangling es.weather/_apply_fire_damage refs confirmed). LIMITATIONS:
  the production glue that calls `setup_combat` for a non-encounter mission with `MissionSession.weather()`
  is still deferred (CombatScreen uses the CombatController stealth layer; the turn-based-orchestrator live
  mission entry is the deferred piece); smoke/coughing/noise still not modelled.
- **s54.10 Phantom Battle (tranche 15, owner-approved 2026-06-16, static-only).**
  The ambient Toshigoku environmental hazard ("the background noise of Toshigoku made visible") — a
  moving tile-AREA effect, NOT a combat participant. `EncounterState.phantom_battles` (Array of
  {center, radius, last_shift, drift, rolled, kept}). `_seed_phantom_battle` fires in `start()` for a
  TOSHIGOKU realm: one 3×3 (radius 1) or 5×5 (radius 2) area near the heart, damage 2k2 read from the
  `phantom_battle` catalog entry. `_apply_phantom_battles` (process_round step 0d): every PC within the
  Chebyshev area at round start takes 2k2 spiritual damage (normal armour — GDD silent on bypass, not
  invented; moving off avoids it); `_shift_phantom_battle` drifts the area one block in its flow
  direction every 5 rounds, reversing drift at a map edge (s54.10: "shift position every 5 rounds as the
  ghostly battle flows across the terrain"). `spawn_threat` now guards `not_creature` catalog entries so
  an environmental hazard can never be added as a combat participant (it lives only in the "terrain" pool
  zone, which the escalation waves don't draw — the hazard is seeded at start instead). All values
  GDD-LOCKED (2k2, 3×3–5×5, 5-round shift, unfightable). Static-validated only (toshigoku_catalog /
  catalog_for_realm / has_tag / damage_rolled-kept / _free_tile_near / in-place Dict mutation over the
  array confirmed). LIMITATIONS: drift is random-per-mission, not battle-historically directed (GDD gives
  no path); even radii (4×4) not used — the 3×3/5×5 endpoints stand in for the range. DEFERRED unchanged:
  paralysis_venom, possession/shapeshift/invisibility/mob_frenzy/rally. Static-only — driver-verify in Godot.

- **Timed-condition layer + s54.10 Paralysis Venom (tranche 16, owner-approved 2026-06-16, static-only).**
  Adds the first *timed* (duration-based, auto-expiring, not roll-recovered) condition to s40 combat —
  reusable infra for any "Condition for N Rounds" effect — and wires Konak Jiji Paralysis Venom on it.
  **Layer:** new `IndividualCombat.Participant.timed_conditions` (condition → expiry Round) +
  `apply_timed_condition` (adds the condition to `conditions` so every existing gate — Armor TN 5,
  attack penalties, can-act — fires unchanged; keeps the longer of an existing/new timer),
  `is_condition_timed`, and `expire_timed_conditions` (sweep at `round_number >= expiry`, wired into
  `AsciiMapCombatOrchestrator.advance_round` beside `expire_timed_modifiers`/`expire_active_kiho`,
  after the `round_number += 1`). The Stunned/Dazed recovery rolls in `advance_round_reactions` now
  skip a *timed* condition (`not is_condition_timed`), so venom runs its full duration instead of being
  shed by an Earth roll. **Paralysis Venom (s54.10 Konak Jiji):** `SpiritAbilitySystem.paralysis_venom_minutes`
  returns the creature's Water Ring for `paralysis_venom`-tagged spirits (0 otherwise); `_apply_hit`'s
  spirit-attacker block (beside on-fire/life-drain) applies a timed Stunned for `Water × ROUNDS_PER_MINUTE`
  on a hit against a non-spirit target (Konak Jiji Water 2 → 20 rounds = 2 minutes). No save (the GDD
  gives none — the venom runs its course). `IndividualCombat.ROUNDS_PER_MINUTE = 10` matches the
  established s56.16 exposure-layer convention (~10 rounds/minute), so the minutes→rounds conversion is
  not a new invented value. Fires through the standard NPC attack path (Konak Jiji is a normal Sakkaku
  combatant), so no encounter-level change is needed. All values GDD-given (Stunned, Water minutes).
  Static-validated only (timed_conditions field, the recovery-guard sites, advance_round increment-then-sweep
  ordering, SpiritCreatureData.water, `.keys()`-copy erase-safety, konak_jiji's paralysis_venom tag confirmed).
  DEFERRED: Konak Jiji deceptive_weight (auto-hit-when-picked-up + TN-40 pin — needs a grab/pin model)
  and lure; possession/shapeshift/invisibility/mob_frenzy/rally. Static-only — driver-verify in Godot.
- **s56.16 creature ability set — close-out + blocker audit (2026-06-16, owner-directed).**
  Audited every special-ability tag across the four statted realms (Gaki-do / Toshigoku / Sakkaku /
  Chikushudo) against `SpiritAbilitySystem` + the encounter/orchestrator. Most tags are flavour/role
  descriptors (real_threat, elite, boss, pack, formation, tactical, swift, flying, territorial,
  negotiator, …) needing no combat code. **WIRED & applied (13 mechanics):** the incoming-damage
  filter (incorporeal / partial_invuln / superior_invuln / Pekkle-half / no_explode / water_vulnerable),
  armor-bypass (spirit_strike / ignores_armor / gaze_attack), life_drain self-heal (O-Toyo),
  swarm+bone_rattle Willpower-TN exposure stacking, wail (Haraigaki), hunger_pull (Fukuregaki),
  engulf+swarm grab/crush, fire_trail+everything_burns (Kagaki, via FireSystem), immobile turn-skip,
  paralysis_venom (Konak Jiji), Usai-gaki kind-gated Reduction (`reduction_for_kind`, wired
  2026-06-16 — see below). **ENCODED but not consumed (documented, not wired):** `is_immune`
  (redundant — `incoming_damage` already composes it); `deals_unhealable_spiritual_damage`
  (Mokumokuren gaze — Wounds untreatable by Medicine; blocked on per-wound source tracking, which the
  wound model lacks); `has_regeneration` (Gashadokuro recovers 10 Wounds/round — NOT trivially
  wirable: the GDD's "pushing past a Wound threshold collapses a section, stopping regen 3 rounds"
  needs threshold-cross detection + a suppression timer; a plain per-round heal would make it
  unkillable = unfaithful); `reforms_on_death` (Ancient General Undying — reforms once 200 rounds
  later at the heart at full Wounds; needs a respawn-at-heart timer + once-flag). **HARD-BLOCKED (not
  encoded — each needs a subsystem the core lacks):** possession + shapeshifter/retains_identity
  (Bakeneko disguise — needs a control/illusion layer), lure/lure_child (Konak Jiji/Mujina social
  trap — needs an NPC-lure mechanic), deceptive_weight (Konak Jiji auto-hit-on-pickup + TN-40
  Athletics pin — needs a pickup/pin model), mob_frenzy/rally + Supreme-Commander aura (+1k0 to
  nearby Musha — group-buff AI), time_thief (action-economy theft), duel_offer (Ancient General
  Duelist's Challenge — in-combat formal duel + others cease-fire), concealment/invisibility (Mujina),
  adapts/Tactical-Mastery (Ancient General's per-character escalating +1k0/+2k0 after 3/6 rounds —
  boss-specific accumulation). **Verdict: the s56.16 creature ability set is complete-for-now** — every
  ability with a clean path through the existing combat/exposure/fire/grab/timed-condition layers is
  wired (tranches 6–16); the remainder are blocked on five named subsystems (per-wound source tracking,
  regen-suppression timer, respawn timer, illusion/possession/disguise, group-buff AI) and a couple of
  boss-bespoke escalation mechanics — none blocked on an unknown GDD value. The 5 encoded-but-dead funcs
  are kept as forward-wiring (their blockers are infra, not design). DEFERRED follow-up candidates, in
  rough order of cheapness: Gashadokuro regeneration (needs the suppression timer), then the boss reforms /
  Tactical-Mastery, then the illusion/possession/group-AI cluster.
- **s56.16 Usai-gaki kind-gated Reduction wired (2026-06-16, owner-directed).** Routed a spirit
  TARGET's Reduction through `SpiritAbilitySystem.reduction_for_kind()` in `_apply_hit` (one shared
  `w_kind` local with the existing incoming-damage filter, so the material-detection limitation —
  default mundane until a WeaponData material field exists — lives in ONE place). Closes the encoded-
  but-dead `reduction_for_kind`. **Zero behavior change today** (all weapons are mundane, so the swarm
  keeps its Reduction 10 — `reduction_for_kind(swarm, mundane) == creature.reduction == armor_reduction`,
  the value `total_defender_reduction` already returned via the puppet); the gain is closing a **latent
  double-Reduction-vs-magic bug** — `total_defender_reduction` would keep the +10 against jade/crystal/
  magic once material detection lands, whereas the GDD (s54.10: "Reduction 10 against normal weapons")
  drops it to 0, which `reduction_for_kind(swarm, non-mundane) == 0` now enforces. Guarded by
  `reduction > 0` so the attack-bypasses-armor path (Shozai/spirit_strike/gaze, already zeroed) is
  untouched. For a non-swarm spirit it equals the creature's Reduction stat (drops the currently-zero
  kata/pierce terms — documented as "a spirit's Reduction is its creature stat, not armor mechanics").
  Static-validated only (W_MUNDANE const + reduction_for_kind signature confirmed; no Godot runtime here).
- **s56.16 creature abilities — final wiring tranche (5 abilities, owner-directed "do all", 2026-06-16,
  static-only).** Wired every remaining creature ability with a clean combat-layer path; the rest are
  genuinely blocked on named subsystems or are pure flavour (see below). Five abilities:
  (1) **Gashadokuro Regeneration** (s54.10): +10 Wounds at the start of each round, suppressed 3 rounds
  when a Wound threshold is crossed. Per-round heal added to `advance_round` beside Ride-the-Water-Dragon;
  `_apply_hit` sets `Participant.spirit_regen_suppressed_until = round+3` when a hit's `levels_crossed > 0`.
  (`SpiritAbilitySystem.regeneration_amount`/`REGEN_SUPPRESS_ROUNDS`.) (2) **Ancient General Undying /
  reforms_once** (s54.10): a slain General reforms ONCE, 200 rounds later, at the heart at full Wounds;
  a second death stays down. Handled in `SpiritualEncounter._process_undying_reform` (the encounter owns
  the heart tile): schedules via `MapCombatState.reform_pending`, respawns a fresh puppet through
  `add_enemy`, dedups per creature id via `EncounterState._reformed_ids`. (3) **Mokumokuren Gaze
  unhealable spiritual damage** (s54.10): new `L5RCharacterData.spiritual_wounds` (@export, default 0,
  always ≤ wounds_taken); `_apply_hit` tags the gaze portion; `MedicineSystem.treat_wound` caps healing
  to the physical portion (`wounds_taken − spiritual_wounds`); `WoundSystem.heal_wounds` (magic/natural)
  clamps the spiritual portion down with total. (4) **Toshigoku group auras** (s54.10): Mob Aggression
  (3+ mob_frenzy within 5 tiles → +1k0 Attack), Rally (Musha Soldier within 10 of a Commander → +1k0
  Attack), Supreme Commander (any Musha within 20 of the Ancient General → +1k0 Attack AND +1k0 Damage).
  (5) **Tactical Mastery / adapts** (s54.10): the General gains +1k0 vs a target after 3 rounds engaged,
  +2k0 after 6 (tracked in `MapCombatState.tactical_engaged`). Auras + Tactical computed in the orchestrator
  (`_set_spirit_attack_auras`, positional) and applied as +N rolled attack/damage dice via two new
  additive, spirit-gated `Participant` fields (`spirit_attack_rolled_bonus`/`spirit_damage_rolled_bonus`)
  read in `resolve_attack`/`resolve_damage` (inert 0 for everyone else; reset after each melee so they
  never leak to an extra/off-hand/ranged strike). Infra added: `MapCombatState.combatants` (id →
  L5RCharacterData, populated by setup_combat/add_enemy/add_companion) for ally lookup at attack time.
  All values GDD-LOCKED (10/3 regen, 200 reform, 5/10/20 radii, 3/6 tactical, +1k0/+2k0). **STILL
  BLOCKED (each needs a subsystem the core lacks; not invented):** Duelist's Challenge (duel_offer —
  needs a PC turn-based accept/decline UI + ceasefire handshake); possession (Kitsune-tsuki in-combat
  control transfer; Shozai-gaki/Buruburu are slow world-sim afflictions over days/weeks — need a
  control/possession layer + cross-encounter affliction timer); shapeshifter/disguise/illusion/
  invisibility (Bakeneko, Kitsune, Hengeyokai, Mujina — need an illusion/disguise/perception layer);
  Konak Jiji deceptive_weight + lure (need a pickup/lure interaction model). **FLAVOUR-ONLY (no
  mechanical ability in the stat block, no code):** Pekkle lure_child/time_thief (stat block lists only
  Partial Invulnerability), spirit-animal field_commander/concealment, deceiver/vindictive/trickster.
  Ranged spirit auras not hooked (only melee — Bow Ashigaru use Volley, a separate unwired ability).
  Static-validated only (symbol resolution + GDD spec confirmed; no Godot runtime — driver-verify later,
  consistent with the rest of the s56.16 combat layer).
- **s54.10 Shapeshifter / illusion subsystem — invisibility & intangibility (owner-directed "do all",
  2026-06-16, static-only).** First slice of the s54.10 Shapeshifter system: the combat-defining
  illusion mechanic — an invisible (Mujina) or insubstantial (Ephemeral Form) creature cannot be
  targeted by attacks. GDD: "can only be wounded if it chooses to be tangible or is caught by surprise."
  The one GDD-silent value (the spot/reveal rule) is resolved as **reveal-on-act** (owner-chosen "do all";
  picked because it needs NO invented TN — deterministic, faithful). **Wired:** (1) **Untargetability** —
  `_is_targetable(state, cid)` computes hidden state from creature tags + reveal window: Mujina
  `ghostly_form`/`invisibility` are at-will (persistent untargetable); `ephemeral_form` (Kitsune) is a
  10-round activated window. `get_melee_targets`/`get_ranged_targets` exclude hidden creatures (so NPC
  AND PC attackers never select them — `_npc_pick_target` draws from those lists), and
  `execute_melee_attack`/`execute_ranged_attack` early-return `target_hidden`. (2) **Reveal-on-act**
  (`_reveal_if_hidden`) — a hidden creature that attacks/shoots becomes targetable through its next turn
  (`Participant.untargetable_revealed_until = round + 1`). Mujina have Attack:None ("do not actually
  fight"), so they never reveal → permanently elusive (faithful to "extremely difficult to kill /
  Immortal"; the spiritual encounter resolves by ritual progress, not by killing, so a lingering Mujina
  doesn't block resolution). (3) **Ephemeral Form** — NPC auto-activates (`_npc_maybe_activate_ephemeral_form`,
  Free Action, once per encounter) when an enemy is adjacent; sets a 10-round insubstantial window
  (`Participant.ephemeral_form_expiry`/`ephemeral_form_used`). (4) **Protection of Yomi** (Major
  Shapeshifter): Reduction 5, stacking with natural, added to a spirit target's reduction in `_apply_hit`.
  New: `Participant.untargetable_revealed_until`/`ephemeral_form_expiry`/`ephemeral_form_used`;
  SpiritAbilitySystem `is_at_will_hidden`/`has_ephemeral_form`/`protection_of_yomi_reduction` +
  `EPHEMERAL_FORM_ROUNDS=10`/`PROTECTION_OF_YOMI_REDUCTION=5` (GDD-LOCKED). Kitsune given its two
  combat-relevant GDD-listed abilities (`ephemeral_form`, `protection_of_yomi`); Mujina already carried
  `ghostly_form`/`invisibility`. **STILL DEFERRED (need their own layers, not invented):** Mimic / A
  Panther's Moves (disguise + Stealth — combat is faction-keyed, not identity/perception-keyed; Stealth
  is the separate CombatController layer); Possession (Major Shapeshifter + Kitsune-tsuki/Shozai/Buruburu
  — control-transfer layer + cross-encounter affliction timer); Mujina illusion spellcasting (Mists of
  Illusion / Way of Deception — needs a tile-combat spell-cast consumer); lure (Konak Jiji / Mujina
  social trap — pickup/lure interaction); wall-phasing movement for intangible creatures (movement
  is_passable has no creature context); Bakeneko / Hengeyokai specific shapeshifter abilities (the GDD
  enumerates only the Kitsune's set — choosing theirs would be invention). Piercing Howl (Fear 2),
  Legendary Healing, Speed of a Predator, Strength of Jade, Protection of Tengoku are classifiable but
  not on the encoded creatures' GDD-given sets (no consumer yet). Static-validated only (symbol
  resolution + GDD spec confirmed; no Godot runtime — driver-verify later).
- **s54.10/s54.2 Possession — combat attempt → cross-encounter affliction (owner-directed "do all",
  2026-06-16, static-only).** Possession is seeded by a tile-combat attempt and resolved over the
  world-sim days, mirroring the proven `death_touch_affliction` pattern. New
  `L5RCharacterData.possession_affliction: Dictionary` (@export, persists; empty = none). **Combat
  attempt** (`AsciiMapCombatOrchestrator._npc_maybe_possess`, wired into `execute_npc_turn` before the
  atemi/attack block): a possessing spirit (Shozai-gaki / Buruburu / Kitsune-tsuki, by the `possession`
  tag) adjacent to a valid non-spirit, un-possessed victim spends a Complex action to attempt it.
  Kitsune-tsuki requires the victim Down/Out (`get_wound_level >= DOWN`) and rolls victim Willpower vs
  TN 25 (possessed on failure); Shozai/Buruburu roll Contested Willpower (possessor vs victim). On
  success it stamps `{kind, possessor_id, possessor_willpower}` on the victim. **World-sim**
  (`DayOrchestrator._process_possession_afflictions`, run beside `_process_death_touch_afflictions`,
  before `_process_lord_deaths` for same-tick succession; timing fields init on first processing so the
  combat layer needs no ic_day): **Shozai** feeds 1k1 Wounds/day (lethal → `_apply_possession_kill`);
  **Buruburu** runs Descent into Terror — nightly Willpower vs TN 20 (consecutive-fail counter),
  death after 20 consecutive failures, weekly (7-day) Contested Willpower to shake off (clears);
  **Kitsune-tsuki** controls for a 24h window then releases — the controlled victim gets **0 AP** via a
  guard in `ActionPointSystem.reset_daily_ap` (mirrors the dead-char/PC 0-AP guards), so they are inert
  for the day. `_apply_possession_kill` mirrors the maho/death-touch mysterious-death path (GREAT_DESTINY
  cheats to DOWN; else lethal wounds + suspicious death_event with `killer_id` + Tier-2 LEGAL
  mysterious-death topic, NEUTRAL subject_role). All values LOCKED in the stat blocks (TN 25, 1k1/day,
  TN 20, 20 fails, weekly shake, 24h). SpiritAbilitySystem: `possession_kind`,
  `possession_requires_incapacitated`, + the constants. **DEFERRED (need infra/consumers, not invented):**
  the Major-Shapeshifter "controls his actions" full puppeteering (modelled here as 0-AP inert for
  Kitsune-tsuki — faithful to "loss of agency," but the possessor does not drive the victim's specific
  actions: that needs a faction/control-transfer layer + the PC turn-based UI); the cure spells
  (Ward of Purity / Bonds of Ningen-do drive out Shozai — no tile-combat spell consumer); Buruburu's
  "+5 TN escalating on all rolls after 3 consecutive nightmares" is **WIRED** (2026-06-16): once the
  Descent-into-Terror consecutive-fail counter reaches 3, `SkillResolver._get_possession_terror_penalty`
  applies a −5×(fails−2) roll penalty to all the victim's skill/contested rolls (the nightmare-resist
  roll is exempt — it does not route through SkillResolver). Buruburu's invisible out-of-combat
  attachment uses the in-combat attempt as its seed (it has no separate stealth-attach mechanic).
  Static-validated only (symbol resolution + GDD spec confirmed; no Godot runtime — driver-verify later).

### s22.3/s02.4 Fear mechanic — wired into tile combat (2026-06-16, static-only)
Activates the `fear` stat that every creature (oni Fear 2-5, gaki/musha Fear 1-5,
spirits) already carried but was dead in combat. **Rule (s22.3 LOCKED):** a Fear
Rating forces nearby characters to roll Willpower vs **TN = 5 + Fear Rank × 5** or
suffer **−1k0 to all rolls** while in range (Fear × 5 ft = Fear tiles). New
`IndividualCombat.CONDITION_AFRAID` (−1 rolled die in `resolve_attack`, beside the
Dazed −3k0). `AsciiMapCombatOrchestrator.apply_fear_checks(state, char_id, character,
dice)` runs at the start of each actor's turn (wired into `execute_npc_turn` and
`execute_companion_turn`; public for the PC turn path): finds the highest-Fear enemy
creature whose range covers the actor, rolls Willpower vs 5+Fear×5, and adds/clears the
AFRAID condition (resisting OR leaving every Fear source's range clears it — proximity-
driven, re-checked each turn). **GDD CONFLICT (left unresolved, flagged for owner):**
s02.4 states the TN as **10 + Fear × 5** while s22.3 (the LOCKED character-sheet Fear
definition) says **5 + Fear × 5** — implemented per s22.3; owner should adjudicate.
A Fear source is any enemy combatant's stat-block `fear` OR a character's own
`fear_rating` (s22.3 Terrible Appearance etc.), so Fear projects from characters too,
not just spirit creatures. **Fear resistance/immunity WIRED:** `L5RCharacterData`
gains `immune_to_fear` (skips the check — s29.4 "Immune-to-Fear", forward-wired with no
granting source yet) and the Kshatriya Warrior (Ivory Kingdoms, s29.14) resist bonuses
set in `SkillResolver.apply_technique_flags` — Strength of Indra R1 (`fear_resist_willpower_bonus`
= +1 Willpower Rank) and Courage of Shiva R5 (`fear_resist_rolled_bonus`/`_kept_bonus`
= +1k1) — applied to the resist roll in `apply_fear_checks`. **GDD CONFLICT (left unresolved,
flagged for owner):** s02.4 states the TN as **10 + Fear × 5** while s22.3 (the LOCKED
character-sheet Fear definition) says **5 + Fear × 5** — implemented per s22.3; owner should
adjudicate. LIMITATIONS: "all rolls" is applied to attack rolls (the in-combat roll;
defense is a passive Armor TN, not a roll); the PC turn path must call `apply_fear_checks`
itself (UI-deferred); Piercing Howl (Minor Shapeshifter Fear 2) remains unwired — no encoded
creature carries it in its GDD-given set, so it has no consumer. Static-validated only (no
Godot runtime).

### s54.x Swift — wired into tile-combat movement (2026-06-16, static-only, PROVISIONAL)
The GDD invokes "Swift N" as a named keyword (Mujina "Swift 6", Kitsune "Swift 3",
Chikushudo "+1 over base", oni Swift 2-4) but never states its numeric effect. The
project fixes 1 tile = 5 ft (MovementSystem), so Swift N = +N tiles to the move budget
is the faithful reading of the keyword via the project's own constant (PROVISIONAL —
flagged for owner confirmation; the +5 ft/Rank conversion is the L5R Swift definition
the GDD's keyword references). New `SpiritCreatureData.swift` (@export, default 0);
`IndividualCombat.get_creature_swift_bonus(character)` returns it for spirit puppets
(0 otherwise), added beside the kata/kiho move bonuses in
`AsciiMapCombatOrchestrator.free_move_budget` and the NPC SIMPLE-move budget. Set on the
two encoded creatures whose stat blocks state a Swift value: Mujina 6, Kitsune 3. Other
creatures keep swift 0 until their stat-block values are transcribed (the mechanism is
live; population is incremental). Static-validated only (no Godot runtime).

### s54.10 Mimic / disguise — wired into tile combat (2026-06-16, owner-approved, static-only)
Owner decisions (2026-06-16): Mimic effect = **both layers** (untargetable in active
combat AND blends in out of active fighting); creatures = **Kitsune + Bakeneko**. The GDD
gives the duration (5 Rounds in battle) but not the combat effect; the owner's rule:
a disguised creature reads as one of the enemy's own → untargetable, until it attacks.
**Wired in the orchestrator** (the one combat system that processes spirit puppets, and
which handles BOTH the real-time approach phase and turn-based combat in one MapCombatState):
new `IndividualCombat.Participant.mimic_expiry`; `_is_targetable` treats a `mimic`-tagged
creature inside its 5-round window as untargetable (so enemies — NPC via `_npc_pick_target`
and PC via `get_*_targets` — cannot select it while it moves among them); `_reveal_if_hidden`
**breaks** the disguise outright on attack (`mimic_expiry = -1`, unlike invisibility's
1-turn flicker — you can't keep a disguise while striking); `_npc_maybe_mimic` (Complex
action, `MIMIC_DISGUISE_ROUNDS = 5`) auto-activates when the shapeshifter is hurt
(>= HURT), threatened, and not already disguised — a wounded trickster vanishes into
another form to escape. `mimic` tag added to Kitsune (its GDD-listed set) and Bakeneko
(owner-approved; the GDD doesn't enumerate Bakeneko's 3 picks). LIMITATION: the separate
roguelike **CombatController stealth/alert layer** has no spirit-creature consumer (spirits
fight via the orchestrator, not CombatController), so the "blends in" half is realised
**within the orchestrator skirmish** (untargetable movement during approach + untargetable
until it strikes) rather than as a second hook in CombatController — there is nothing for
Mimic to gate there until spirit creatures flow through that layer. Re-castable (no
once-per-encounter limit; GDD allows recasting). Static-validated only (no Godot runtime).

### s54.10 Konak Jiji Lure + Deceptive Weight — wired into tile combat (2026-06-16, owner-approved, static-only)
Owner decisions (2026-06-16): trigger = **adjacency + resist roll**; pin = **grapple state**
(escape Athletics/Strength TN 40). The GDD gives the spring (auto-hit + 400 lb pin, TN 40
to move, cooperative allowed) and the venom (already wired); the open piece was the
tile-combat pickup trigger. **Wired:** the Konak Jiji starts disguised as a harmless
abandoned baby — `lure`-tagged + `lure_sprung == false` makes it untargetable in
`_is_targetable` (reuses the Mimic/invisibility targeting path). On its turn while
disguised it does **nothing** unless a living non-spirit enemy is adjacent (has reached
for the babe); then `_npc_maybe_spring_lure` runs a **Contested Willpower (victim) vs
Awareness (creature)** roll — no invented TN, both stat-block values: success sees through
it (`lure_sprung = true`, now revealed/targetable, fights normally with Claws 5k3); failure
**springs the trap** — an automatic claw hit (no attack roll, `damage_rolled k damage_kept`),
a pin via the existing grapple state (`CONDITION_GRAPPLED` + `grapple_partner_id`, creature
in control, `deceptive_weight_pinned = true`), and the paralysis venom (timed Stunned for
Water minutes). **Escape:** `attempt_deceptive_weight_escape` rolls Strength + Athletics vs
`DECEPTIVE_WEIGHT_ESCAPE_TN = 40` (GDD-stated); on success the grapple/pin clears both
sides. A pinned NPC victim auto-attempts it via a new branch in the grappled-turn handler
(before the normal take-control); the PC path calls the public fn (UI-deferred). New
`Participant.lure_sprung` / `deceptive_weight_pinned`. Konak Jiji already carried the
`lure`/`deceptive_weight`/`paralysis_venom` tags. LIMITATIONS: cooperative escape is
single-character (GDD allows cooperative — deferred); a pinned **companion** doesn't
auto-escape (companion turn path doesn't call the escape; NPC victims and the PC do).
Static-validated only (no Godot runtime).

### s54.10 Ancient General Duelist's Challenge — wired into tile combat (2026-06-16, static-only)
The boss's `duel_offer` ability: once per encounter the Ancient General challenges one
enemy to formal combat, and "all other Musha in the area cease attacking for the
duration." Wired as a battlefield ceasefire (no PC accept-prompt needed — the mechanical
effect is the General's army standing down). New `MapCombatState.duel_challenger_id` /
`duel_target_id` / `duel_offered`. In `execute_npc_turn`: `_clear_duel_if_over` lifts the
duel when either duelist is dead/out/fled; `_npc_maybe_offer_duel` (free declaration at
turn start) makes the General challenge the nearest living enemy, once per encounter;
`_duel_ceasefire_blocks` makes every OTHER Toshigoku Musha on the challenger's faction
**hold its attack** (returns a `duel_ceasefire_hold`) while the duel stands; and the
challenger **focuses** the challenged target (best_target override when it is in reach).
The challenged side fights freely (attacking the General is the implicit "accept"; the
ceasefire is the General's side honoring the duel). LIMITATION: the formal PC
accept/decline prompt is UI-deferred — the battlefield ceasefire + focus are the live,
faithful mechanic. Static-validated only (no Godot runtime).

### s54.10 creature ability set — final status (2026-06-16)
With Duelist's Challenge wired, **every encoded creature ability that has BOTH a GDD-stated
rule AND a creature that uses it is now implemented.** The two genuinely-remaining items
have no GDD content to transcribe and cannot be built without inventing:
- **Mujina illusion spells** (By the Light of the Moon, Mists of Illusion, Way of Deception,
  Mask of Wind, Nature's Touch, Token of Memory): none are in the SpellSystem library and
  none have a statted tile-combat effect, AND there is no creature spell-cast path in the
  orchestrator. Building them needs the owner to define each spell's combat effect. (The
  Mujina is already fully functional as the GDD describes it: an untargetable, non-fighting,
  immortal trickster.)
- **Major-Shapeshifter full puppeteering** (the "controls his actions until sunrise" clause):
  NO encoded creature has Major-Shapeshifter Possession in its GDD-given ability set (the
  Kitsune's set is Mimic / A Panther's Moves / Protection of Yomi / Ephemeral Form; Bakeneko
  and Hengeyokai picks are unspecified), so assigning it would invent that creature's
  abilities. The three GDD-designated possessors (Kitsune-tsuki / Shozai-gaki / Buruburu) are
  already wired (control = 0-AP agency loss / 1k1-feed / Descent into Terror).
Pure flavour (no stat-block mechanic, correctly no code): Pekkle lure_child/time_thief,
spirit-animal field_commander/concealment, deceiver/vindictive/trickster, musha
retains_identity. No-consumer (GDD rule exists but no encoded creature uses it): A Panther's
Moves, Piercing Howl, Legendary Healing, Eyes of the Owl, Strength of Jade.

### Systems Added 2026-06-17 (s54.5 Oni of the Shadowlands — bestiary data tranche, owner-approved)
- **s54.5 oni roster transcribed.** `simulation/oni_bestiary.gd` (OniBestiary, pure class) —
  all **35** oni stat blocks from s54.5 as `SpiritCreatureData` (faithful transcription, no
  invented values): the 20 core oni (Akaru/Arugai/Byoki/Daku/Furu + spawn/Gagoze/Genso/Ianwa/
  Kamu/Kommei/Manesuru/Morei/Muduro/Nairu/Nosloc/Pekkle/Quiet Death/Ryokaku/Shikage), the 4
  Shokansuru's Brood (Hasaiki/Munemitsu/Sentei/Yojireju), 6 further oni (Sodatsu/Tasu/Utogu/
  Uzaki/Wakeru/Wanizame), and 5 Oni Lord Spawn (Akuma/Kyoso/Shikibu/Tsuburu/Yuhmi). `catalog()`
  (id → fresh instance), `oni_ids()`, `get_oni(id)`. New `Enums.SpiritRealm.JIGOKU` (the Realm
  of Evil — keeps `SpiritCreatureData.realm` honest for oni; it is NOT a spiritual-insurgency
  overlap realm, and `SpiritCombatant.catalog_for_realm(JIGOKU)` returns `{}` via the existing
  `_:` wildcard, so the s56.16 spirit-encounter pipeline is unaffected). Reusing
  `SpiritCreatureData` means oni are **combat-ready for free** via `SpiritCombatant.to_character_data()`
  (realm-agnostic conversion) — the same adapter the spirit roster uses.
  **Immediate combat win:** oni "Invulnerability" maps to the already-wired `partial_invuln`
  tag (mundane weapons do nothing; only jade/crystal/magic hurt), and "Superior Invulnerability"
  → `superior_invuln` + `flame_immune` — so every Invulnerable oni is correctly mundane-resistant
  in tile combat the moment it is spawned. Fear/Swift ride the dedicated fields (Arugai Swift 2,
  Furu 4, Nairu 3, Furu/Shikibu spawn 2). Multi-attack oni store their primary representative
  attack (the single-attack limitation shared with the spirit roster; second attacks are a
  combat-layer refinement, tagged `multi_attack`). DELIBERATELY-DESCRIPTIVE (unwired) tags for
  oni-specific abilities so the combat layer never mis-applies them: Plague Bearer, Splatter,
  Swallow Whole/Devour, Burning Blood, Fiery Impalement, Spawn-on-death, Endless Horde (split),
  Corpse/Soul Absorption, Taint Affliction, Shapeshifting (soul-steal vs human-form), Shugenja's
  Bane, Teleport, the various regens (per-round vs hourly vs flaming — distinct from the wired
  Gashadokuro `regeneration` amount, so NOT blanket-tagged), and element-nuanced immunities
  (Daku's normal-flame-only / Furu-spawn's fire-only get `fire_resist_mundane`/`flame_immune`
  rather than the mundane-weapon `partial_invuln`). NOT wired this tranche; subsequent tranches
  wire the oni-specific abilities the way the s56.16 creature abilities were done (the combat-
  consumable subset first). NO spawn/encounter glue yet — the future Shadowlands / Kaiu-Wall-horde
  consumer calls `OniBestiary.get_oni(id)` → `SpiritCombatant.to_character_data()`. Static-validated
  only (no Godot runtime — parse-traced + GDD-checked; wound tracks incl. Out→Dead boundaries and
  the single-threshold Wakeru verified against the stat blocks).

### Known Code Issues (found and fixed 2026-06-17, spirit/oni damage path)
- **Spirit/oni creatures never dealt their stat-block damage — used "unarmed". FIXED.**
  `SpiritCombatant.to_character_data()` builds the creature's damage onto `c.weapons[0]`
  (a WeaponData) but sets no `c.skills`; the orchestrator's NPC attack path picks the
  weapon via `IndividualCombat.pick_best_weapon()` → `WEAPON_CATALOG` (returns "unarmed"
  for a skill-less puppet), and `resolve_damage()` reads `get_weapon_profile(weapon_name)`
  — so every spirit/oni dealt generic unarmed damage, and the WeaponData on `c.weapons[0]`
  was dead. The to-HIT override (resolve_attack) already read `spirit_creature.attack_rolled`,
  but there was no matching DAMAGE override. Added one in `resolve_damage`: when
  `attacker.spirit_creature.damage_rolled > 0`, base damage = the creature's fixed
  `damage_rolled k damage_kept` (Strength-add block guarded off — spirit damage is fixed
  per s54), with the Supreme Commander aura still adding on top. Mirrors the to-hit override
  exactly; additive, inert for real characters (spirit_creature == null). Now every spirit
  AND oni deals its real stat-block damage. Static-only (no Godot runtime).

### Systems Added 2026-06-17 (s54.5 multi-attack data + spirit damage fix)
- **SpiritCreatureData multi-attack fields.** `attack2_name/attack2_rolled/attack2_kept/
  damage2_rolled/damage2_kept` + `has_second_attack()`. Populated for all 13 multi-attack
  oni (Akaru Bite, Arugai Tail, Genso Talons, Kamu Bite, Muduro Bite, Ryokaku Claws,
  Shikage Tongue-Stinger, Hasaiki Bite, Munemitsu Gore, Sentei Bite, Utogu Bite, Uzaki
  Claws, Yuhmi Mai Chong) via `OniBestiary._with2()`, plus Harionago/Pennaggolan (undead)
  and Yamato no Orochi (additional).
- **Multi-attack LIVE wiring — DONE + runtime-verified (2026-06-17).** A `multi_attack`
  creature with a second attack now makes BOTH strikes in its Turn. `execute_npc_turn`
  fires the second strike right after the primary (and any off-hand): it field-swaps the
  creature's primary attack/damage to the attack2 values (so the to-hit AND damage spirit
  overrides both read the secondary profile), calls `execute_melee_attack(..., bonus_attack=true)`,
  then restores. `bonus_attack` (new optional param, default false → zero change for every
  existing caller) makes the strike a free bonus that neither requires nor consumes an
  action — like the off-hand attack — so it fires regardless of whether the AI spent a
  Simple on a stance change (the action-economy interaction that made the naive
  Simple-cost approach drop the second attack). Driver-verified in a headless skirmish:
  Akaru (Claws + Bite) produces `[stance, attack, multi_attack]` and the target takes both
  hits; the primary profile is restored after the swap (no permanent mutation of the shared
  stat block); a single-attack creature (Byoki) gets exactly one strike (regression).

### Systems Added 2026-06-17 (s54 bestiary transcription + unified spawn glue)
- **s54.11 Undead, s54.12 Additional Creatures + Elemental Terrors, s54.6 Five Ancient
  Races — transcribed.** Three new bestiaries reusing SpiritCreatureData (faithful, no
  invented values): `undead_bestiary.gd` (16 — physical undead/gaki/slaughter spirit/named
  villains), `additional_creatures_bestiary.gd` (37 — the 10 Greater+Lesser Elemental
  Terrors of all five elements, Chikushudo spirits, Shadowlands jinmenju, Children of the
  Last Wish, Yamato no Orochi, Nure-Onna, Hinotama, Wanyudo, Furaribi, legendary giants,
  mundane animals), `ancient_races_bestiary.gd` (10 — Kenku/Ningyo/Kitsu/Tsuno/Zokujin).
  New `Enums.SpiritRealm.NINGEN_DO` (Mortal Realm) for natural animals + mortal-world
  spirits. Realm assignment: Elemental Terrors/oni/Tainted → JIGOKU, gaki → GAKI_DO,
  slaughter spirits/Tsuno → TOSHIGOKU, Chikushudo bird/animal spirits → CHIKUSHUDO, Sakkaku
  water spirits → SAKKAKU, mortal → NINGEN_DO. Tag mapping: "Invulnerability" (resists
  mundane weapons) → wired `partial_invuln`; "Superior Invulnerability"/"Insubstantial"
  (only magic/jade harm) → wired `superior_invuln`; gaki "Superior Invulnerability"
  (illusion+mind immunity, NOT mundane) → descriptive `immune_illusion`/`immune_mind`.
  "human-type Wound Ranks" → `wounds_dead = 0` so the PC Earth-derived track applies
  (faithful for the human-type races, not a gap). Multi-attack creatures (Harionago,
  Pennaggolan, Yamato no Orochi) carry attack2.
- **Unified spawn-by-id glue (s54 / #2).** `SpiritCombatant.find_creature(id)` searches
  EVERY bestiary (spirit realms + oni + undead + additional/terrors + ancient races) and
  `spawn_by_id(id, instance_id)` builds the combat puppet — the realm-agnostic API the
  future Shadowlands / Kaiu-Wall-horde / mission consumer uses to drop any transcribed s54
  creature into the orchestrator without knowing which bestiary holds it. Pure, additive.
- **Combat status (#1 ability wiring).** With the damage-path fix (above), the SHARED
  ability layer already makes most oni/undead/terrors combat-functional NOW: real stat-block
  damage, `partial_invuln`/`superior_invuln` (mundane-weapon resistance), Fear (apply_fear_checks),
  Swift (move budget), `flame_immune`/`water_vulnerable` (fire/damage filter), engulf grab.
  The oni/creature-UNIQUE abilities (Plague Bearer, Swallow Whole, Burning Blood, spawn-on-death,
  Taint Affliction, the differing regen rates, Spell Mastery, the Elemental-Terror powers,
  etc.) carry DESCRIPTIVE tags and are the next runtime-verifiable wiring tranche — done the
  way the s56.16 creature abilities were (combat-consumable subset first).
- **RUNTIME-VERIFIED (2026-06-17).** Godot 4.6.2-stable was installed in-session and a
  headless driver run (in a minimal autoload-free copy of `simulation/`+`shared/`, since the
  full project's Node/scene/scheduler autoloads stall a `--script` run): all four bestiaries
  load (oni 35, undead 16, additional 37, ancient 10 = 98 creatures, zero duplicate ids); the
  **damage-path fix is confirmed working** — an Arugai puppet averages 39.7 damage over 40
  rolls (its 10k4 stat line), vs ~5 for the old "unarmed" fallback; multi-attack `attack2`
  data is populated; `SpiritCombatant.spawn_by_id()` resolves across every bestiary and
  returns null for unknown ids; `catalog_for_realm(JIGOKU)` is empty (s56.16 unaffected). All
  9 touched files pass `--check-only`. This upgrades the session's work from static-only to
  runtime-verified for the data + damage path; the deferred ability/multi-attack-turn wiring
  is still the next tranche.

### Systems Added 2026-06-17 (s54.5 creature ability wiring — regeneration, runtime-verified)
- **Per-round regeneration with variable amounts — DONE + runtime-verified.** The regen
  loop in `advance_round` already healed `SpiritAbilitySystem.regeneration_amount()`, but
  oni used descriptive tags so they regenerated nothing. Added `SpiritCreatureData.regen_wounds`
  (0 = none): `regeneration_amount()` returns it when > 0, else the Gashadokuro `regeneration`
  tag's 10. Populated Arugai (10/round, "Nearly Immortal") and Hasaiki (5/round). New
  `SpiritAbilitySystem.regen_suppressible()` (tag-only) so the threshold-cross 3-round
  suppression stays Gashadokuro-specific while Arugai/Hasaiki regen UNCONDITIONALLY (faithful
  to s54.5). Sentei's hourly regen is negligible per-round → left 0. Driver-verified: Arugai
  50→40, Hasaiki 30→25 per `advance_round`, regen floors at 0, a non-regenerator (Byoki)
  heals nothing. The remaining creature-unique abilities (Swallow Whole/Devour, Plague
  Bearer, Burning Blood [needs per-creature 5k5/2k2 + save data], spawn-on-death) are the
  next wiring candidates.

### Systems Added 2026-06-17 (s54.5 Swallow Whole / Devour — runtime-verified)
- **Swallow Whole / Devour wired (Muduro/Kamu/Tsuburu/Utogu).** On a wounding melee hit a
  swallow creature wins a Contested Strength (creature vs victim) to engulf the victim:
  `_apply_swallow_whole` (fired from execute_melee_attack beside Burning Blood) sets
  `Participant.swallowed_by_id` + Grapple state (creature in control). Each Round the
  swallowed victim takes the creature's `swallow_damage_rolled k _kept` (advance_round, +1
  Taint if `swallow_taint`), released if the captor dies. Escape: `attempt_swallow_escape`
  (Contested Strength vs the captor) — auto-attempted by a swallowed NPC in the grappled-turn
  handler, public for the PC path. New SpiritCreatureData fields
  `swallow_damage_rolled/_kept/swallow_taint`; populated Muduro (3k3 +Taint), Tsuburu (2k2
  +Taint), Utogu (5k5), Kamu (7k5 bite; the GDD "swallowed → dies next Round" instant-death
  is approximated by high per-round damage). **BUG caught by runtime test:** the initial
  `swallowed_by_id >= 0` "is-swallowed" check was wrong — spirit-puppet captor ids are
  NEGATIVE, so `>= 0` excluded them; switched to the `!= -1` sentinel everywhere. (The
  pre-existing grapple_partner_id `>= 0` checks may share this latent issue for negative
  captors — noted for a future pass; not touched here.)
  RUNTIME-VERIFIED (Godot 4.6.2): Muduro swallows a low-Strength victim, per-round 3k3 + 1
  Taint applied, a weak victim fails to escape 6/6, a strong victim escapes and the state
  clears.

### Systems Added 2026-06-17 (s54.5 Spawn-on-death — runtime-verified)
- **Spawn-on-death wired (Tasu, Wakeru).** When a hit KILLS a `death_spawn_id` creature,
  `_apply_hit` calls `_spawn_on_death`, which adds `death_spawn_count` copies of the spawn id
  to the live combat via `add_enemy` at free tiles near the corpse, on the dying creature's
  faction. New SpiritCreatureData `death_spawn_id`/`death_spawn_count`; new
  `MapCombatState.spawn_counter` (unique negative spawn instance ids) + `Participant.death_spawn_done`
  guard (fires once). Tasu → 2× `tasu_spawn` (Rings 1, ATN 15, 12 wounds); Wakeru → 2×
  `wakeru_lesser` (physical traits −1, Wounds −5, ATN +5, attack/damage −1k1). Both spawn ids
  are real catalogue entries (so `SpiritCombatant.spawn_by_id` resolves them; `OniBestiary.catalog()`
  is now 37 = 35 oni + the 2 spawn-only blocks). `wakeru_lesser` has no further `death_spawn_id`,
  so the split is ONE generation (Tasu's "2k2 spawn" and Wakeru's recursive halving are reduced
  to a fixed count of 2 for skirmish playability — PROVISIONAL). RUNTIME-VERIFIED (Godot 4.6.2):
  killing a near-dead Tasu adds 2 tasu_spawn (participants 2→4) on the enemy faction; Wakeru
  splits into 2 wakeru_lesser; the lesser copy carries no death_spawn (no infinite split).

### Systems Added 2026-06-17 (s54.5/s54.11 Disease — runtime-verified)
- **Plague / disease wired (Byoki, Shikko-gaki, plague-zombie).** `simulation/disease_system.gd`
  (DiseaseSystem, pure): contagious diseases that drain physical Traits over days/weeks,
  seeded on a creature's hit and resolved in the world-sim (cross-encounter, like the
  possession affliction). Three types: PLAGUE_BEARER (Byoki — daily Earth TN 15 or lose 1
  Rank in ALL physical Traits; 3 consecutive saves cure), DISEASED_TOUCH (Shikko — weekly
  Stamina TN 20, fail = −1 Stamina + −1 Strength, success recovers), PLAGUE_CARRIER
  (plague-zombie — automatic weekly Stamina −1 until cured or Stamina 0 → dies). New
  `L5RCharacterData.disease_affliction`. Combat contraction (`_apply_hit` → `_apply_disease_on_hit`):
  a wounding hit on a mortal by a `plague_bearer`/`diseased_touch`/`plague_carrier` creature
  rolls the per-type check (Byoki Contested Earth, Shikko Stamina-vs-wounds, zombie 1-in-5)
  and seeds the disease (ic_day −1; the world-sim anchors the cadence clock on the first
  `process_daily`). Daily world-sim processing: `DayOrchestrator._process_disease_afflictions`
  (beside possession) drains per type; a lethal Plague-Carrier drain appends a death_event
  for same-tick succession (plague-zombie reanimation deferred). RUNTIME-VERIFIED (Godot
  4.6.2): low-Earth victim drains over days, high-Earth victim cures in 3 saves, Plague
  Carrier kills via weekly Stamina drain to 0, Byoki infects a low-Earth victim on a
  wounding hit (type = PLAGUE_BEARER). Medicine has no effect on Byoki plague (magic-only,
  GDD); the cure() hook is for the magic/Medicine systems to call.

### s54.5 creature-unique abilities — status (2026-06-17)
All four owner-selected abilities are wired AND runtime-verified with headless drivers
(Godot 4.6.2, installed via the SessionStart hook): **multi-attack** second strike,
**Burning Blood** retaliation, **Swallow Whole / Devour**, **spawn-on-death / split**, and
**Plague / disease** — plus the foundational **spirit/oni damage-path fix** and **variable
regeneration**. Testing caught two real bugs that static review missed: the wrong
damage-source (creatures dealt unarmed damage) and the `swallowed_by_id >= 0` sentinel
failing for negative puppet ids. Remaining creature abilities (Taint Affliction, Spell
Mastery, the Elemental-Terror powers, Kommei soul-steal, etc.) are the next candidates.

### Systems Added 2026-06-17 (s54.5 Gagoze Taint Affliction — runtime-verified)
- **Taint Affliction wired (Gagoze).** The Gagoze's burning gaze (s54.5): a Complex Action,
  Contested Willpower (oni vs victim) — oni wins → the victim gains 1 full Rank of Shadowlands
  Taint; once per individual ever. `_npc_maybe_taint_gaze` (creature-turn hook in
  execute_npc_turn, before the atemi/attack block, gated on the `taint_affliction` tag + an
  available Complex action) picks the nearest mortal (non-spirit) living enemy not yet gazed
  (tracked per-gazer in `MapCombatState.taint_gaze_used`), spends the Complex action, rolls the
  contest, and on a win does `victim.taint += 1.0`. The +1 Taint feeds the EXISTING consumers:
  MutationSystem periodic-taint rolls (rank-up mutations/powers) and maho Channel-3 detection
  (witch-hunter accusation). RUNTIME-VERIFIED (Godot 4.6.2): low-Willpower mortal gains 1 Taint
  on a non-melee gaze, once-per-individual (no repeat on the same victim), a spirit/oni target
  is skipped (Taint affects mortals only). LIMITATION: the victim-win 24h Fire/Earth Ring
  penalty is not modelled (no cross-encounter Ring-debuff layer) — the averted Taint is the
  meaningful outcome. Spell Mastery (Gagoze casting elemental spells) remains blocked — no
  creature spell-cast consumer in the orchestrator.

### Systems Added 2026-06-17 (s54.5 Wreathed in Flames + Retributive Taint — runtime-verified)
- **Wreathed in Flames wired (Daku).** Striking the burning oni in melee automatically (no
  save) burns the attacker by weapon size: unarmed/Small 3k2, Medium 2k1, Large/ranged 0
  (s54.5, exact). `_apply_wreathed_in_flames` fires from execute_melee_attack on a landed
  melee hit beside Burning Blood; reads the weapon's `size` from get_weapon_profile. Inert
  unless the struck TARGET has the `wreathed_in_flames` tag. (Distinct from Burning Blood —
  no Defense save, size-scaled; Daku carries wreathed_in_flames, not burning_blood, so no
  conflict.) RUNTIME-VERIFIED: unarmed striker auto-burned, tetsubo (Large) striker takes 0.
- **Retributive Taint wired (Pekkle).** A slain Pekkle bursts in a 10-ft (2-tile) radius:
  every living mortal in the area rolls Earth TN 30 or gains 1–10 points of Taint (s54.5,
  exact). `_apply_retributive_taint` fires from the _apply_hit death hook (beside
  spawn-on-death, guarded once via death_spawn_done) when a `retributive_taint` creature
  dies. The Taint feeds the MutationSystem periodic-taint + maho Channel-3 pipelines.
  RUNTIME-VERIFIED: nearby Earth-1 mortal gains 7 Taint on the death burst, a mortal beyond
  2 tiles is unaffected. (Daku flaming_regeneration / fire_resist_mundane and Furu
  extreme_heat remain blocked/redundant — fire-element weapon detection, and Furu's
  arrow-immunity is already covered by superior_invuln.)

### Systems Added 2026-06-17 (s54.5 creature ranged attacks — runtime-verified)
- **Creature ranged-attack path wired (Flaming Bark, Hurl Flaming Blood).** A reusable
  thrown/spat attack layer for the whole bestiary. New SpiritCreatureData fields
  `ranged_attack_name/_rolled/_kept`, `ranged_damage_rolled/_kept`, `ranged_range_tiles`,
  `ranged_fire`. `execute_creature_ranged_attack` (Complex action): the creature's fixed
  ranged to-hit (ranged_attack_rolled k _kept) vs the target's Armor TN (get_armor_tn,
  ranged mode), dealing ranged_damage_rolled k _kept reduced by the target's armour; on a hit
  `ranged_fire` sets the target on fire (FireSystem 1k1/round — the GDD "2k2 next Round" burn
  approximated by the standard on-fire layer). Range-gated by ranged_range_tiles. NPC-turn
  integration: in execute_npc_turn, after the move-toward block, a creature with a ranged
  attack fires at a target that is in LOS + range but not in melee reach (before the melee
  attack block). Populated Daku (Flaming Bark 6k3 / DR 3k2 / 30 ft / fire) and Furu (Hurl
  Flaming Blood 10k9 / 4k4 / 30 ft / fire). RUNTIME-VERIFIED (Godot 4.6.2): Flaming Bark hits
  a low-Reflexes mortal in range and ignites it; a target beyond range → out_of_range;
  execute_npc_turn fires creature_ranged when the target is at range; Furu's profile loads.
  LIMITATIONS: ranged is Complex (Hurl's GDD Simple-action economy not modelled); the AI
  fires when at range rather than always closing to its (often stronger) melee primary —
  a tuning choice, not a bug. Daku flaming_regeneration / fire_resist_mundane still blocked
  (fire-element weapon detection).

### Systems Added 2026-06-17 (s54.11/s54.12 undead + Elemental Terror abilities — runtime-verified)
- **Burning Touch wired (Taki-bi no Oni etc.).** "Anyone who touches or is touched by" a
  burning-touch creature is set on fire (1k1/round via the FireSystem on-fire layer until
  extinguished). Both directions: a `burning_touch` creature's melee hit sets the TARGET on
  fire (extended the _apply_hit fire_trail block), and a melee attacker who strikes a
  burning_touch creature is set on fire (new retaliation beside Wreathed in Flames, using a_p).
  Tag was present on Taki-bi / Moetechi / Wanyudo but unconsumed. RUNTIME-VERIFIED (Godot 4.6.2):
  a katana-wielder striking Taki-bi catches fire; Taki-bi's Flaming Fist sets a mortal alight.
- **Life Drain — confirmed already wired (no change).** The `life_drain` tag (Yosuchi no Oni
  Lesser Elemental Terror of Air, and a forest spirit) is already consumed by
  SpiritAbilitySystem.on_hit_self_heal, which `_apply_hit` calls for every spirit attacker —
  so life-drain creatures already self-heal on a wounding hit. No wiring needed.
- **Disease — confirmed already populated.** Shikko-gaki (`diseased_touch`) and the plague
  zombie (`plague_carrier`) already carry the disease ability tags consumed by the
  `_apply_disease_on_hit` contraction wired earlier this session — so the undead disease
  carriers are live. No change.

### Systems Added 2026-06-17 (s54.11 Ghul Throat Attack — runtime-verified)
- **Throat Attack / follow-up-on-big-hit wired (Ghul).** A generic "big hit → free bonus
  attack" layer: new SpiritCreatureData fields `followup_wound_threshold` +
  `followup_rolled/_kept` + `followup_dmg_rolled/_kept`. In `_apply_hit`, a melee hit dealing
  `followup_wound_threshold`+ Wounds triggers a free bonus attack (to-hit vs the target's
  Armor TN, on hit applies the follow-up damage), applied directly (no recursion into
  _apply_hit). Populated Ghul: 15+ Wound claw → free bite 5k3 / 4k1 (s54.11, exact).
  RUNTIME-VERIFIED (Godot 4.6.2): over 30 attacks, all 19 of the 15+ Wound claw hits fired
  the follow-up bite (extra damage beyond the claw), and sub-threshold hits did not.

### Systems Added 2026-06-17 (s54.12 Jimen no Oni Trembling Earth — runtime-verified)
- **Trembling Earth wired (Jimen no Oni).** A `trembling_earth` enemy within 50' (10 tiles)
  imposes -1k0 to all rolls (no save) — modelled with the same AFRAID -1k0 condition as Fear,
  but it is NOT a Fear effect (physical shaking) so it bypasses Immune-to-Fear.
  `apply_fear_checks` rewritten to compute fear-afraid and tremor independently, then set/clear
  the AFRAID condition once (afraid-roll-failed OR tremor-source-near). The exact Fear logic is
  preserved. New const TREMBLING_EARTH_TILES = 10. RUNTIME-VERIFIED (Godot 4.6.2): a fear-immune
  hero within 8 tiles of Jimen is AFRAID (proves it is the tremor, not Fear), clears beyond 16
  tiles; Fear regression intact (near low-Willpower hero afraid, far clears, fear-immune
  unaffected by Fear). LIMITATION: AFRAID covers attack rolls in combat (the GDD "all Skill
  Rolls + Spell Casting" is the same -1k0); Fear and tremor do not stack (both = the single
  -1k0 AFRAID).

### Systems Added 2026-06-17 (s54.11/s54.12 poison / venom — runtime-verified)
- **Poison stat-drain wired (Gakimushi stinger, komodo/jinmenju bite, aquatic stinger).** A
  cross-encounter Trait drain (like disease/possession). New `L5RCharacterData.poison_affliction`
  {trait, drained}. DiseaseSystem.apply_poison drains a Trait immediately on hit (Strength for
  `poisonous_stinger`/`poison_stinger`, Stamina for `poison_stamina`/`poison_bite`), stacking
  per hit; process_poison_daily restores all drained Ranks (the GDD sub-day/24h recovery
  collapses to a next-tick full restore at daily granularity). Combat hook in `_apply_hit`:
  stinger poisons have no save, `poison_bite` (komodo) allows a Stamina TN 20 save. Wired into
  DayOrchestrator daily (beside disease). RUNTIME-VERIFIED (Godot 4.6.2): Gakimushi stinger
  drains Strength 5→3 over 2 hits (drained=2, poisoned), the world-sim restores it fully (→5,
  cleared); komodo resolves. LIMITATIONS: paralysis at Trait 0 is the drained state (no
  separate paralyzed condition); the exact multi-day Komodo cadence and Gakimushi 1hr/dose
  timing collapse to a single next-day restore.

### Systems Added 2026-06-17 (s54.11/s54.12 AoE fire blasts — runtime-verified)
- **AoE ranged attack wired (Cauldron Belch, Gout of Flame).** Extends the creature ranged
  path with a blast radius. New SpiritCreatureData `ranged_aoe_radius` / `ranged_aoe_max_targets`
  / `ranged_aoe_once` + Participant `ranged_aoe_used`. `execute_creature_aoe_attack` (Complex):
  centred on the target tile, damages every enemy within ranged_aoe_radius (capped at
  max_targets); ranged_attack_rolled 0 = auto-hit explosion (Gout), >0 = a single to-hit roll
  vs the primary gates the blast (Cauldron); ranged_fire ignites each victim. NPC-turn branch
  prefers AoE when available and not used. Populated Taki-bi Gout of Flame (auto-hit 5k4,
  radius 2, at-will) and Kwaku-shin Gaki Cauldron Belch (6k3 / 4k4, radius 2, max 3 targets,
  once per skirmish). `ignores_armor` confirmed already wired (Taki-bi bypasses armor via
  attack_bypasses_armor). RUNTIME-VERIFIED (Godot 4.6.2): Gout strikes 2 clustered heroes
  (far one outside radius spared, primary set on fire); Cauldron Belch fires once then blocks
  (already_used). LIMITATION: "3 targets within 10' of each other" is modelled as 3 nearest
  within the radius of the impact.

### Systems Added 2026-06-17 (s54.12 Furaribi Soul Touch — runtime-verified)
- **Soul Touch wired (Furaribi).** A character touched by a `soul_touch` creature cannot spend
  Void Points (new Participant `void_locked`, set in `_apply_hit`, checked in execute_void_spend).
  Armor bypass is free (Furaribi already carries `ignores_armor` → attack_bypasses_armor).
  RUNTIME-VERIFIED (Godot 4.6.2): hero spends Void before the touch, locked out (reason
  void_locked) after. LIMITATION: the GDD 24h cross-encounter duration + the "cannot make
  Stamina rolls vs sickness/poison for 24h" clause are not modelled — only the in-combat
  Void lockout (the combat-relevant effect).

### Systems Added 2026-06-17 (s54.12 Stunning Jolt + Void Leech — runtime-verified)
- **Stunning Jolt wired (Hinotama).** A touch forces a Stamina TN 20 roll — Dazed on success,
  Stunned on failure (both roll-recoverable conditions). `_apply_hit` hook gated on the
  `stunning_jolt` tag + a mortal target. RUNTIME-VERIFIED (Godot 4.6.2): a low-Stamina victim
  is Dazed/Stunned by the touch.
- **Void Leech wired (Kukanchi no Kansen).** A wounding hit drains 1 Void Point from the
  victim and heals the creature 15 Wounds. `_apply_hit` hook gated on the `void_leech` tag.
  RUNTIME-VERIFIED: hero VP 3→2, creature wounds 20→5. SIMPLIFICATION: the GDD "if a damage
  die explodes" gate is reduced to any wounding hit (the exploding-die detail is internal to
  the damage roll, not surfaced).

### Systems Added 2026-06-17 (s54.12 Strength of the Dead + Sap the Void — runtime-verified)
- **Strength of the Dead wired (Wanyudo).** A once-per-skirmish Complex-action scream: every
  mortal enemy within 50' (10 tiles) rolls Contested Willpower vs the creature or is Stunned.
  `_npc_maybe_scream` creature-turn hook (before the attack block) + Participant `scream_used`.
  RUNTIME-VERIFIED (Godot 4.6.2): scream Stuns nearby low-Willpower mortals; the second scream
  is blocked (once per skirmish).
- **Sap the Void wired (Akeru no Oni).** On a Claw hit, an Opposed Void Roll (creature vs
  target) saps 1 Void Point from the target, added to the Akeru's pool (capped at its Void
  Ring). Required giving Void-using creatures a real Void Ring: new SpiritCreatureData
  `void_rank` (0 for all but Akeru = 1, GDD default), wired through SpiritCombatant
  (puppet void_ring + current_void_points = void_rank; 0 keeps every other spirit Void-less).
  RUNTIME-VERIFIED: Akeru Claw saps hero VP 3→2; Akeru holds at its Void-Rank cap.
  Void Strike (the stolen-Void beam needing full 7 VP) remains deferred — Akeru accumulating
  beyond its starting Void Rank is not modelled.

### Systems Added 2026-06-17 (s54.12 Breathe Flames + Burning Saliva — runtime-verified)
- **Auto-hit breath weapons + Basan Breathe Flames.** Extended the creature ranged path:
  `ranged_attack_rolled` 0 now means an auto-hit breath/blast (no to-hit roll) for the
  single-target path too (the AoE path already had this). The ranged guards key on
  `ranged_damage_rolled` (a ranged attack is defined by its damage); the single-target NPC
  branch is gated to `ranged_aoe_radius == 0` so AoE creatures only use the AoE path. Basan
  Breathe Flames populated: Complex, auto-hit one target within 15' (3 tiles), DR 4k3.
  RUNTIME-VERIFIED (Godot 4.6.2): Breathe Flames auto-hits a Reflexes-8 target (17 wounds);
  range-gated (5 tiles → out_of_range).
- **Burning Saliva wired (Akuma no Oni spawn).** Added `burning_saliva` to the on-fire hook —
  the spawn's tongue hits set the target on fire (the GDD 10-round / vinegar-wash specifics
  collapse to the standard on-fire layer). RUNTIME-VERIFIED: Akuma spawn melee hit ignites.

### Systems Added 2026-06-17 (s54.12 Feed Upon the Soul — runtime-verified)
- **Feed Upon the Soul wired (Kyoso no Oni spawn).** Killing a foe instantly heals the
  creature 5 × the slain enemy's Insight Rank (`_apply_hit` death hook, gated on the
  `feed_upon_soul` tag + a mortal kill). RUNTIME-VERIFIED (Godot 4.6.2): a kill healed the
  Kyoso spawn by 5 (= 5 × the rank-1 test victim's computed Insight Rank).

### s54.5/s54.11/s54.12 creature ability layer — integration validation (2026-06-17)
Ran a full integration smoke (Godot 4.6.2): all 22 representative creatures
(ghul/daku/furu/taki-bi/kwaku/gagoze/pekkle/jimen/furaribi/wanyudo/akeru/basan/byoki/
gakimushi/muduro/tasu/kyoso-spawn/hinotama/kukanchi/arugai/shikko/wakeru) take a real
`execute_npc_turn` against a hero party with **zero crashes** (22 ok, 0 missing); melee +
multi-attack fire. **Finding (not a bug):** the creature-turn Complex abilities (taint_gaze,
scream, possession, AoE, ranged) defer past a turn-1 stance change — `_npc_pick_stance`
spends a Simple to enter ATTACK on turn 1, and under the "1 Complex OR 2 Simple" economy a
spent Simple blocks a Complex the same turn, so the signature gaze/scream fires from turn 2
onward (verified: Gagoze turn 0 = [stance, attack], turn 1 = [taint_gaze] → victim +1.0
Taint). This is faithful action economy; the GDD gives no NPC stance-vs-ability priority, so
no change was made. Two test-harness pitfalls noted for future drivers: (1) always copy BOTH
simulation/ AND shared/ into the headless test project (a stale shared/ silently breaks a
bestiary catalog mid-build → null spawns → hangs); (2) do not re-call execute_npc_turn for
the same actor without proper turn advancement.

### Systems Added 2026-06-17 (s54.11/s54.12 constriction — runtime-verified, data-only)
- **Constriction wired (Wyrm, Nure-Onna, Pennaggolan).** Constriction is mechanically
  identical to the swallow grapple-crush (grab on a wounding hit via Contested Strength →
  per-round crush damage in advance_round → Contested-Strength escape), so it reuses the
  existing swallow layer with **data only** — `swallow_damage_rolled/_kept` populated per
  GDD: Wyrm Constrict 5k5, Nure-Onna 4k2, Pennaggolan Entrail Constriction 3k1. No new code.
  RUNTIME-VERIFIED (Godot 4.6.2): all three grab a low-Strength victim and crush per round
  (wyrm 16→44, nure_onna 14→29, pennaggolan 12→21). The snake/serpent shapechange and the
  Pennaggolan flying-head head-detach are not modelled (the combat-relevant grab/crush is).

### Systems Added 2026-06-17 (s54.5 Web/Entangle + s56.20 snare fix — runtime-verified)
- **Entangle made functional (cross-system).** `CONDITION_ENTANGLED` was SET by the snare trap
  (s56.20) but never consumed — inert. Now `execute_move` rejects movement while entangled
  (reason "entangled"), `attempt_entangle_escape` breaks free on a Strength TN 20 roll, and an
  entangled NPC out of melee auto-attempts the escape in execute_npc_turn (instead of a futile
  move). This fixes the previously-inert **snare trap** AND enables web attacks.
- **Akaru no Oni Spinnerets (web) wired.** New SpiritCreatureData `ranged_entangle`: a ranged
  attack that Entangles on a hit instead of dealing damage (the ranged guards/branches accept
  damage-less entangle attacks). Akaru populated: Spinnerets 6k4 to-hit, no damage, Entangle
  TN 20 (range 6 tiles PROVISIONAL — Spinnerets range unspecified in s54.5). RUNTIME-VERIFIED
  (Godot 4.6.2): Akaru webs a target at range → Entangled → movement blocked → Strength-12
  escape (TN 20) → movement restored. (Dokufu/Kumo ranged webs are forward-wired for when those
  spiders are transcribed; demon_silk likewise.)

### Systems Added 2026-06-17 (s54.5/s54.12 Charge attacks — owner-approved, runtime-verified)
- **Charge subsystem (tranche 1).** A charge-capable creature, out of melee but within charge
  range, **enters Full Attack stance (only if able that turn — the GDD gate) and closes +
  strikes in one turn**. `execute_charge`: range = Water Ring × `charge_move_mult` ft (÷5 =
  tiles); moves toward the target (free move) then attacks. `charge_simple` makes the attack a
  Simple action (boar/elephant economy — stance-Simple + attack-Simple both fit a turn);
  `charge_atk_bonus`/`charge_dmg_bonus` add +NkN; `charge_diving` ends the creature Prone after
  the dive. Charge fires only when it closes a gap (already-adjacent → normal attack). Owner
  decisions (2026-06-17): enter Full Attack only if able; charge when it reaches; propose-approve.
- **Charge bonus plumbing.** execute_melee_attack gains `charge_atk_bonus`/`charge_dmg_bonus`
  (+NkN, stacks on auras) + `as_simple` (Simple-economy attack). New Participant
  `spirit_attack_kept_bonus`/`spirit_damage_kept_bonus` (the kept half of +NkN) read in
  resolve_attack/resolve_damage and reset alongside the rolled aura bonuses.
- **Trample (on-hit).** A melee hit by a `trample_prone` creature renders the target Prone;
  `trample_daze_margin` (Utogu 10) adds Dazed when the attack beats Armor TN by that margin.
  Wired in _apply_hit (reads attack_result.margin).
- **Populated:** Utogu (charge ×10 + trample Prone/Daze-10), Nairu + Nue (diving +1k1
  → self-Prone), Munemitsu (trample Prone), spirit boar (goring charge: Simple + +1k1 atk/dmg,
  move ×10 PROVISIONAL — GDD silent on goring move distance). RUNTIME-VERIFIED (Godot 4.6.2):
  Utogu closes 6→1 tiles + target Prone; boar enters Full Attack + Simple-attacks same turn;
  Nairu dives + ends self-Prone; an adjacent target yields no charge (normal attack).
  DEFERRED (tranche 2): Gore-stick (Munemitsu), Ox Furious-Charge rage, Rhino Furious-Charge
  Knockdown-maneuver + Free Raise, Rhino's vs-Prone special trample (8k4/10k4), stag antler
  charge (GDD value unconfirmed).

### Known Code Issues (found and fixed 2026-06-17, charge tranche 1 catalog bug)
- **AdditionalCreaturesBestiary.catalog() emptied at runtime — wrong dict key. FIXED.**
  The charge tranche-1 commit attached the diving-charge fields to `c["night_heron"]`, but
  the diving creature at that spot is the **Nue** (`c["nue"]`), and a separate `night_heron`
  (eye_strike, not diving) is created LATER in the same function. So `c["night_heron"].charge_* = …`
  ran before that key existed → "Invalid access to key 'night_heron'" → catalog() aborted and
  returned an effectively EMPTY dict. Every additional-bestiary creature (rhinoceros, Taki-bi,
  Furaribi, Kukanchi, Hinotama, Wyrm, Nure-Onna, Jimen, Yosuchi, etc.) then failed to spawn
  (spawn_by_id → null). Parse-check/import did NOT catch it (runtime error, not parse). Changed
  the key to `c["nue"]`. RUNTIME-VERIFIED: catalog rebuilt to 37; integration smoke green again
  (22 ok, 0 missing). LESSON: a per-file `--check-only` parse does not exercise catalog runtime;
  spawn/integration drivers are required to catch dict-key errors.

### Systems Added 2026-06-17 (s54.5/s54.12 Charge tranche 2 — runtime-verified)
- **Gore-stick (Munemitsu).** A melee hit sticks the victim (Entangled, reusing the entangle
  layer); pulling free (Strength TN 20 via attempt_entangle_escape) deals the creature's
  `gore_escape_rolled k _kept` extra damage (Munemitsu 3k2). New SpiritCreatureData
  gore_escape_rolled/_kept + Participant gore_escape_rolled/_kept. RUNTIME-VERIFIED: stuck →
  escape deals +3k2.
- **Rhino Furious Charge (Knockdown).** A Full-Attack melee hit by a `charge_knockdown` creature
  attempts a Knockdown (Contested Strength, quadruped, +5 = the Free Raise) → target Prone.
  Wired in _apply_hit (covers charging AND adjacent); resolve_knockdown gains a bonus_to_attacker
  param. RUNTIME-VERIFIED: rhino knocks the target Prone.
- **Rhino vs-Prone Trample.** When the target is Prone, the rhino uses a special Simple attack
  (8k4 / 10k4) via a temporary stat-profile swap (like the multi-attack second strike). New
  vs_prone_atk/dmg_rolled/_kept fields + an execute_npc_turn branch. RUNTIME-VERIFIED: Prone
  target → vs_prone_trample fires (10k4, +36 damage in the test).
- **DEFERRED:** Ox Furious-Charge rage (no Ox creature is transcribed — no consumer), stag antler
  charge (GDD value unconfirmed). These need new transcription, not wiring.

### Systems Added 2026-06-17 (s2/s54.11/s54.12 Fatigue subsystem — owner-approved, runtime-verified)
- **Fatigue applied + Full-Attack gate (the effect was already wired).** GDD locks Fatigued =
  +5 TN to all rolls (+5 per extra day) + may not take Full Attack stance (s2 line 181). The
  combat roll penalty (−5, escalating via `fatigue_days`) was ALREADY implemented in
  `IndividualCombat.get_condition_roll_penalty` and consumed by resolve_attack — but nothing
  APPLIED CONDITION_FATIGUED and the Full-Attack block was unenforced. Added: (1) **Full-Attack
  block** in `execute_stance_change` (reason `fatigued_no_full_attack`) + the charge's direct
  stance entry (a Fatigued creature cannot charge). (2) **Aura of Heat (Taki-bi)** — a
  non-Fatigued character within 10' (2 tiles) of an `aura_of_heat` creature becomes Fatigued by
  heatstroke (applied in apply_fear_checks at turn start; persists — heatstroke is not cleared
  by stepping away). (3) **Abominable Stench (Nuppeppo)** — `_apply_abominable_stench` in
  execute_melee_attack: when struck by an armed melee weapon, every living mortal within 20'
  (4 tiles) rolls Stamina TN 20 or is Fatigued. RUNTIME-VERIFIED (Godot 4.6.2): Fatigued →
  Full Attack blocked (allowed when rested); Aura of Heat fatigues within 2 tiles, not far;
  striking the Nuppeppo fatigues a low-Stamina attacker. APPROXIMATIONS/LIMITATIONS:
  "bladed/piercing" = any armed (non-unarmed) melee weapon (no weapon damage-type field);
  Fatigue is combat-scoped (Participant condition — no cross-encounter Fatigue state, so the
  out-of-combat "+5 TN to all Skill rolls" is not applied via SkillResolver); Aura of Heat's
  "first Round" and Stench's "until you move 20 ft away" clearing are not modelled (Fatigue
  persists for the skirmish).

### Systems Added 2026-06-17 (s54.5 Shikage Demon Silk — runtime-verified, web reuse)
- **Demon Silk wired (Shikage no Oni).** Two reuses of the entangle layer (data + a small
  retaliation): the ranged web → `ranged_entangle` (7k4 to-hit, no damage, Entangle, range 20'
  = 4 tiles, data-only); and the touch-retaliation — a melee attacker who strikes the
  web-covered oni is instantly Entangled (beside the Burning Touch retaliation in
  execute_melee_attack; escape TN simplified to the standard 20 vs the GDD's TN15-escalating).
  RUNTIME-VERIFIED (Godot 4.6.2): Shikage webs a target at range → Entangled; a katana-strike
  on Shikage entangles the attacker. DEFERRED: Shikage's Mind-Breaking Poison (Willpower drain)
  and Paralyzing Poison (Reflexes drain) — per-round escalating Trait drains (Stamina TN20 each
  Round until a save or the Trait hits 0 → mind-controlled / paralyzed), a poison-system
  extension beyond the current immediate-drain-with-next-tick-restore model.

### Systems Added 2026-06-18 (s54 sacred-material Reduction + s54.5 heart_kill, owner-approved)
- **s54.5/s54.11/s54.12 Vulnerable-to-sacred-materials Reduction (owner ruling: vulnerable).**
  Juggernaut-type creatures whose thick hide is LESS effective vs jade/crystal/obsidian
  ("Reduction X (Y against jade/crystal/obsidian)") now take reduced Reduction from those
  weapons. New `SpiritCreatureData.reduction_jade/_crystal/_obsidian` (-1 = base, 0 =
  bypassed); `SpiritAbilitySystem.reduction_for_kind()` consults them (after the swarm
  rule), wired into `_apply_hit` (already the single reduction-resolution site for spirit
  targets). **Exact per-creature, per-material GDD values transcribed** for 15 creatures —
  undead: harionago (j5), nuppeppo (j5/c5), pennaggolan (j10/c10), gakimushi (j5/c5),
  kitsune_gohei (j8/c8), yogo_junzo (j5/c5); additional: kaze_no_oni (0/0/0), yobuko (c0),
  jinmenju (j10/c5/o5), jimen_no_oni (c4/o4), toichi_no_kansen (c0/o0), wanyudo (c5/o5),
  akeru_no_oni (0/0/0), mizu_no_oni (j10/c10); oni: ryokaku_no_oni (c4). The coarse
  `reduction_vs_jade_crystal*` tags are left as descriptive (superseded by the data). Fire
  resists (Wanyudo "20 vs magical fire") not wired — no magical-fire weapon path exists.
  Runtime-verified 23/23 (mundane=base, sacred=exact reduced value, control creature
  unaffected, vulnerable direction holds). All numbers GDD-exact — no invention.
- **s54.5 Arugai heart_kill (the unkillable-boss fix).** See commit 9ff521c: regenerating
  heart_kill oni can only be slain by locating (Investigation/Perception TN 30,
  `execute_locate_heart`) and destroying its 10-Wound heart; body Wounds are held below
  Dead while the heart is hidden. Runtime-verified 8/8.
- **gaki_immortality — RESOLVED: already-handled (owner decision, no code).** GDD ("reform
  in Gaki-do") gives no tile-combat reform delay/location (unlike the General's explicit
  200-rounds-at-heart), so an explicit on-map reform would require invented numbers. Treated
  as emergent: the Restoration Ritual is the encounter win condition (not killing) and the
  s56.16 escalation spawner re-manifests gaki from the realm pool, so "cannot be permanently
  destroyed by combat" already holds. The `gaki_immortality` tag remains descriptive; no
  combat change.

### Systems Added 2026-06-18 (s31–s37 tile-combat spellcasting — Phase 1, owner-approved "Full")
- **Cast framework + the two blocked reaction consumers.** New
  `AsciiMapCombatOrchestrator.execute_cast_spell()` — a Complex Action that validates
  `SpellSystem.can_cast` (known / insight rank / slot / Ishiken), spends the slot, and
  resolves the cast roll vs TN. Range is LOS-only for now (GDD spell ranges blocked on
  map-distance data, same as ranged weapons). **Sodatsu's Bane (s54.5)** fully wired:
  a spell cast AT a `shugenjas_bane` creature is absorbed (no effect, slot still spent)
  and the oni instantly retaliates (`_sodatsu_bane_retaliate`) in one of the three GDD
  modes — heal 3×ML if wounded, else bolt the caster (4k4 attack vs Armor TN, DR ML k2
  [BANE_BOLT_DR_KEPT PROVISIONAL — GDD "DR equal to the Mastery Level" leaves kept dice
  unstated], 50 ft = 10 tiles), else harden +3×ML Armor TN for 3 rounds (timed modifier,
  stacks). **Creature Magic Resistance (s54.10/s54.12)**: new
  `SpiritCreatureData.spell_tn_bonus` (+ `spell_tn_bonus_element`, -1 = all) added into
  `SpellSystem.resolve_cast`'s TN, element-gated. Populated Mujina +6 and Yamato no Orochi
  +6 (explicit GDD "+6"). The "N Ranks of Magic Resistance" creatures use +5 TN/Rank (owner
  ruling 2026-06-18), element-gated: Jimen +15/Earth, Akeru +15/Void, Moetechi +15/Fire,
  Toichi +5/Earth, kodama +10/all, Manesuru +10/all. DEFERRED: Hinotama (2 Ranks Earth+Void
  — the single element field can't express dual-element, and it also has full Fire/Air/Water
  immunity which isn't modelled) and Kaze no Oni (Spell-Filching is absorb/redirect, not +TN).
  **jade/crystal-property spells** (third consumer): `SpellSystem.has_jade_or_crystal_property()`
  + the Furaribi rule (s54.12) — a jade-property spell successfully cast at a `superior_invuln`
  spirit does not harm it but repels it (removed from positions + added to fled_ids). Property
  list seeded with jade_strike (certain); the full Jade/Crystal-property list is Phase 2.
  Runtime-verified 18/18 across two passes (MR flat-+6 + N-Rank element-gating; Sodatsu absorb
  + slot spent + all three modes + Armor TN raised; jade_strike repels Furaribi, not a
  non-superior_invuln creature). LIMITATION: a generic successful cast has no offensive/buff EFFECT yet
  — the library entries are `{element, mastery, sim_effect}` with no damage/range/AoE, so
  per-spell combat effects are **Phase 2** (faithful transcription from s31–s37, the bulk
  of the work). Phase 1 delivers the casting plumbing + the reactions that fire off the act
  of casting (the original #1 unblock: Shugenja's Bane + magic_resistance).
  Also fixed: a misplaced `c["mujina"].spell_tn_bonus` injection had landed in
  `chikushudo_catalog()` (spirit_bestiary has one catalog per realm) instead of
  `sakkaku_catalog()` — caught at runtime (mujina spawn crashed), relocated.
- **s31–s37 tile-combat spellcasting — Phase 2 tranche 1: direct-damage Fire spells
  (owner-authorized 2026-06-18).** First per-spell combat EFFECTS layer on top of the Phase 1
  casting plumbing. New additive `SpellSystem.SPELL_COMBAT_EFFECTS` dict + `get_combat_effect()`
  — a per-spell GDD-transcribed combat-effect schema (`kind/dr_rolled/dr_kept/range_tiles/
  aoe_radius/aoe_hits/caster_exempt/is_magic`), kept separate from the `{e,m,s}` library so it
  stays clean. Four unambiguous direct-damage Fire spells encoded (s35, exact GDD values, 5 ft =
  1 tile): **Fury of Osano-Wo** (5k2 single, 300'→60-tile = LOS), **Beam of the Inferno** (10k10
  single, 200'→40-tile), **Breath of the Fire Dragon** (DR = caster's Fire Ring, self-centered,
  enemies-only — the 15'×5' cone modeled as a radius-3 blast, caster exempt), **Destructive Wave**
  (7k7, 25'→radius-5, friend+foe, caster exempt). `AsciiMapCombatOrchestrator.execute_cast_spell`
  gains a damage branch (after the Furaribi-retreat block, gated on success + a `"damage"` effect)
  → `_apply_spell_combat_damage()`: resolves single-target (with a range check that fizzles an
  out-of-range cast, slot already spent) or self-centered AoE (Chebyshev radius; enemies-only via
  faction, or all; caster always exempt), rolls the DR per target (exploding; DR = Fire Ring when
  `dr_*` is 0), and applies it through `WoundSystem.apply_damage(…, 0)` (elemental fire bypasses
  armor). Spirit targets route through `SpiritAbilitySystem.incoming_damage(creature, W_FIRE,
  is_magic=true)` — a new backward-compatible `is_magic` param so a fire SPELL reads as **magic**
  for the invuln tags (incorporeal/superior_invuln/partial_invuln let it through) AND as **fire**
  for `flame_immune` (Kagaki/Taki-bi take 0 and HEAL) and `water_vulnerable`. Returns a per-target
  `{id, damage|healed, dead}` report (on `res["spell_damage"]` + combat log). Also fixed: the AoE
  faction comparison used `int(...)` but `FACTION_*` are Strings (caught at runtime). Runtime-verified
  6/6 (beam single, fury single, AoE-all hits both ally+enemy, caster exempt = 0 wounds, breath
  enemies-only spares the ally, flame_immune spirit heals from the fire spell). DEFERRED (next
  tranches): the buff/aura Fire spells (Fires of Purity wreath, Katana of Fire, weapon enhancers —
  need persistent buff state + a melee retaliation hook), terrain-ignition (Fiery Wrath → FireSystem),
  instant-kill edge cases (Death of Flame's reciprocal self-damage), multi-round channels (Breath's
  4-round Simple-action repeat), weather damage bonuses (Fury's storm 6k2/6k3), targeting
  restrictions (Dragon's Talon Insight ≤2), and the other four elements + Universal (Air/Earth/Water/
  Void direct-damage + utility). The schema generalizes to those; this tranche proves the pipeline.
- **s31–s37 tile-combat spellcasting — Phase 2 tranche 2: other-element direct damage
  (owner-authorized 2026-06-18).** Extends the tranche-1 schema across the remaining four rings
  (exact GDD values). New schema fields: `dr_rolled_bonus` (added after the ring substitution —
  Slayer's Knives DR = Air Ring +2k0) and `requires_taint` (0 damage to a target with Taint Rank
  < 1 — Jade Strike). `_apply_spell_combat_damage` rewritten element-aware: DR=0 now uses the
  spell's **element** Ring (not always Fire); the spirit-damage filter kind is derived from the
  element (Fire→W_FIRE so flame_immune heals, Water→W_WATER so water_vulnerable doubles, else
  W_MAGIC), always `is_magic=true`; AoE centers on the **target tile** when ranged (targeted blast
  — Howl of Isora) and on the caster when self-centered (cones/bursts). Seven spells encoded:
  **Air** — Tempest of Air (1k1, 75' cone), Howl of Isora (3k2, 40'-diameter targeted burst, all),
  Slayer's Knives (Air+2 k Air, 30' corridor); **Earth** — Jade Strike (3k3, single, taint-gated,
  also the jade-property repel from Phase 1); **Water** — Strike of the Tsunami (3k3, 25' cone);
  **Void** (Ishiken-only) — Touch the Emptiness (1k1, single), Void Strike (Void-Ring DR, single).
  Cones/diameters modeled as Chebyshev radii (length÷5 = tiles) — over-applies behind the caster
  (no facing, same compromise as the kiho cone layer). Runtime-verified 7/7 (jade_strike damages
  tainted / 0 vs non-tainted; void_strike Ishiken + Void-Ring DR; slayers_knives Air+2 DR;
  howl_of_isora centers on the aim point + hits all near it, spares the distant caster;
  strike_of_the_tsunami enemies-only). DEFERRED (riders/edge cases, later tranches): Knockdown
  (Tempest/Slayer's/Tsunami), Fatigue (Howl), Daze (Touch the Emptiness), weather bonuses,
  earthquake/pit structure-and-terrain spells, multi-round transforms (Tomb of Jade), and the
  buff/weapon/condition spell families.
- **s31–s37 tile-combat spellcasting — Phase 2 tranche 3: damage-spell condition riders
  (owner-authorized 2026-06-18).** Adds the GDD condition riders to the wired damage spells via a
  new optional `rider` sub-dict on `SPELL_COMBAT_EFFECTS` ({condition, save, save_tn,
  duration_rounds}) + `_apply_spell_rider` in the orchestrator (applied per surviving damaged
  target after damage). Four save types: `none` (auto), `earth_flat` / `stamina_flat` (Ring/Trait
  roll vs TN), `earth_contested_air` (target Earth vs caster Air, ties to the target). Five riders
  wired to existing consumed conditions: **Prone** — Tempest of Air (Contested Earth vs Air),
  Slayer's Knives (Earth TN 20), Strike of the Tsunami (Earth TN 15); **Dazed** — Touch the
  Emptiness (no save); **Fatigued** — Howl of Isora (Earth TN 30). New `CONDITION_DEAFENED`
  constant added (forward-wired) but Fury of Osano-Wo's Deafen is **deferred**: it is a bystander
  AoE within 10' of the *target* (not a rider on the damaged target, who usually dies to 5k2
  first) and Deafened has no combat effect yet — needs a sub-AoE + a hearing mechanic. The timed-
  rider path (`duration_rounds`>0) remains forward-wired (no rider currently uses it). All values
  GDD-exact. Runtime-verified 5/5 (Dazed auto; Prone on weak-Earth via contested + flat saves;
  strong-Earth target resists Slayer's Knives = rider "resisted"; Fatigued on Howl; Fury now
  riderless). DEFERRED unchanged: Fury Deafen bystander-AoE, weather bonuses, earthquake/pit
  terrain spells, multi-round transforms, buff/weapon/condition spell families.
- **s31–s37 tile-combat spellcasting — Phase 2 tranche 4: in-combat healing (s36 Water,
  owner-authorized 2026-06-18).** Adds a `"heal"` kind to `SPELL_COMBAT_EFFECTS` + a `heal` branch
  in `execute_cast_spell` → `_apply_spell_heal`. Heals a living ally (or self) within reach via
  `WoundSystem.heal_wounds`; an Out-but-alive ally can be restored, the dead cannot. Three library
  healers (all Touch/single-target, GDD-exact): **Path to Inner Peace** (heal = cast roll margin
  over TN), **Regrow the Wound** (Water Ring + effective School Rank, one Round), **Peace of the
  Kami** (full heal — all Wounds). `heal` field selects the amount; `range_tiles 1` = Touch
  (caster adjacent, self always allowed). Gates: same-faction only (cannot heal an enemy →
  `not_an_ally`), Touch range (`out_of_range`), `target_dead`. Runtime-verified 6/6 (margin heal,
  Water+Rank heal, full heal → 0 wounds, enemy rejected, out-of-range rejected, self-heal).
  **Correction:** Reversal of Fortunes — listed in the original menu as a healer — is actually a
  re-roll BUFF (GDD s36: "may re-roll any one roll per round, 3 rounds"), so it is NOT in this
  tranche; it belongs to the buff/weapon tranche. DEFERRED: rise_from_the_ashes (Void 6 Ishiken,
  8-hour time-window regression — needs per-time injury/disease/poison/taint tracking; combat-
  relevant slice would be a full heal but the undo-window semantics are not modeled); multi-round
  maintained healing (Regrow applies one Round per cast); the AoE/per-round Water heals
  (Heaven's Tears, Sanctuary of the Waves). Multi-target heal is not needed — all three wired
  healers are single-target.
- **s31–s37 tile-combat spellcasting — Phase 2 tranche 5: status/control + cleanse spells
  (owner-authorized 2026-06-19).** Adds two new `SPELL_COMBAT_EFFECTS` kinds. **`status`** inflicts
  a condition on each affected target (single or AoE), mapping to the existing consumed combat
  conditions, with an optional save (the rider save-types, extracted into a shared
  `_spell_save_resisted`); target-gathering extracted into a shared `_gather_spell_targets` used by
  both damage and status. **`cleanse`** (`_apply_spell_cleanse`) frees allies of conditions and
  heals them. Five spells (exact GDD): **Wind-Born Slumbers** (Air 2 → Fatigued; an active combat
  target gets Fatigue, the "asleep" branch needs no combat condition), **Whispering Flames**
  (Fire 3 → 10' AoE Dazed on all gazers, roll-recovered), **Eyes of the Phoenix** (Fire 4 → single
  Blinded), **Wooden Prison** (Earth 3 → single Entangled, escape via the standard entangle layer),
  **Typhoon's Surge** (Water 3 → up to Water Rank nearest living allies in range, free Fatigued+Dazed
  + heal Water Rank each). All saves "none" per GDD (these apply automatically); the save path is
  forward-wired. `duration_rounds` 0 = persistent/roll-recovered via apply_condition (all five; GDD
  durations exceed a skirmish or are escape/roll-gated). Runtime-verified 7/7 (Fatigued; AoE Dazed
  near-yes/far-no; Blinded; out-of-range fizzle; Entangled; Typhoon's cleanse+heal of two allies
  20→14 / 15→9). DEFERRED: **Reversal of Fortunes** (Water 1 re-roll buff — needs a per-Participant
  re-roll-grant state read by the roll sites) and **The Soul's Blade** (Fire 6 weapon enchant,
  auto-Stun on hit — needs a weapon-enchant state in `_apply_hit`) → weapon/buff tranche; Eyes of
  the Phoenix's allies' Fear-3 burst (one-shot AoE Fear, not a proximity source); Whispering Flames'
  gaijin/nonhuman immunity + exact Willpower=Fire×10 recovery TN (uses the default Dazed recovery);
  Wooden Prison's Contested-Strength-vs-4 escape (uses the standard TN-20 entangle escape) + its
  terrain restrictions.
- **s31–s37 tile-combat spellcasting — Phase 2 tranche 6: defensive/weapon buff spells
  (owner-authorized 2026-06-19).** Adds a `buff` kind: persistent stat bonuses installed on the
  target's Participant via the existing round-scoped `timed_modifiers` layer (auto-expires in
  `advance_round`). `_apply_spell_buff` resolves each `{kind, value}` mod (value = int OR a GDD
  formula `water_plus_rank`/`earth_plus_rank` via `_resolve_buff_value`); `target` "self" (range
  ignored) or "ally" (Touch/range, living same-faction gate). `duration_rounds` = GDD rounds
  (minutes × 10 via the ROUNDS_PER_MINUTE convention). Five new read sites wired in
  `individual_combat.gd` — `reduction` (`total_defender_reduction`), `armor_tn` (already read by
  `get_armor_tn`), `spell_attack_rolled`/`_kept` (`resolve_attack`, ungated — distinct from the
  Kenjutsu/Iaijutsu-gated World-Is-Empty `attack_rolled`), `spell_damage_rolled`/`_kept`
  (`resolve_damage`), `initiative_rolled` (added to the rolled-dice count in `roll_initiative`, NOT
  a flat score add — Warning Flame is +1k0). Five spells (exact GDD): **Armor of Earth** (Earth 1
  → Reduction = Earth + School Rank), **Cloak of the Miya** (Water 2 → Armor TN += Water + School
  Rank), **Biting Steel** (Fire 1 → DR +1k1), **Burning Kiss of Steel** (Fire 1 → melee attack
  +1k1; the mounted/larger +2k2 deferred), **Warning Flame** (Fire 1 → +1k0 Initiative; the
  immune-surprise + Reactions-Stage +3 deferred). Runtime-verified 6/6 (Reduction +12, Armor TN
  +12, damage +1k1 r9→10 k2→3, attack +1k1 mean 49→56, ally Init +1k0 58→61, expiry via
  `expire_timed_modifiers`). DEFERRED (each needs a distinct hook): **Reversal of Fortunes**
  (Water 1 — a per-Participant re-roll-grant read by every roll site), **The Soul's Blade** (Fire 6
  — a weapon-enchant Participant state in `_apply_hit` that auto-Stuns + overcomes Invulnerability),
  Fires of Purity flame-shroud (a melee-attacker retaliation on a character, like the creature
  Wreathed-in-Flames hook), Force of Will (+2 Wounds/Rank with expiry-damage — needs a wound-capacity
  buff), the elemental weapon-conjuration spells (need an inventory weapon), and the Fear-resist
  buffs (Strength of the Crab etc. — need a Fear-resist modifier in `apply_fear_checks`).
- **s31–s37 tile-combat spellcasting — Phase 2 tranche 7: NPC cast pipeline
  (owner-authorized 2026-06-19).** Closes the loop — before this, every spell combat effect
  (damage/riders/heal/status/cleanse/buff) was only reachable by a direct `execute_cast_spell`
  call; no NPC combatant ever cast. `_npc_maybe_cast_spell` is the NPC shugenja combat-cast hook
  in `execute_npc_turn` (PC-present skirmishes only — NPCs use the orchestrator solely when a PC
  is in the fight; PC casting is still the future turn-based UI). Structural AI, same class as
  `_npc_pick_atemi` / `_npc_maybe_activate_kiho` (the GDD gives no NPC combat-spell policy).
  Priority: (1) the best castable **damage/status** spell (highest ML) that **reaches** the
  AI-chosen enemy (`_spell_reaches`: ranged single/aimed-AoE → distance ≤ range_tiles;
  self-centered AoE → ≤ radius); (2) **heal** — self when wound level ≥ HURT, else an adjacent
  wounded ally (heal spells are Touch); (3) **self-buff** if not already buffed. Placed BEFORE
  the stance pick because casting is the turn's **Complex** action and a Simple spent on a stance
  change forbids the Complex (1 Complex OR 2 Simple); a grappled caster is skipped (can't gesture),
  prone casting is allowed. On a successful cast the turn ends. Runtime-verified 6/6 (casts beam at
  the PC for 60; self-heal at wl 5 ≥ HURT 70→55; full-heal an adjacent ally 18→0; self-buffs Cloak
  of the Miya; offense chosen over self-buff when both available; a non-caster bushi takes no
  cast_spell action and falls through to melee). LIMITATION: a wounded support shugenja still
  prefers offense when any enemy is reachable (heal is priority 2) — a deliberate aggressive
  heuristic, tunable after a live run; AoE friendly-fire avoidance in target selection is not
  modeled (the cast aims at the AI's single best_target; self-centered AoE "all" spells can catch
  allies, faithful to the GDD but worth watching).
- **s31–s37 tile-combat spellcasting — Phase 2 tranche 8: hooked buff spells
  (owner-authorized 2026-06-19).** The three deferred buffs whose effect is a combat-hook read,
  not a passive stat total. All cast via the `buff` kind (target self) installing a timed modifier;
  the effect fires in `_apply_hit` / `execute_melee_attack`. (1) **The Soul's Blade** (Fire 6,
  `weapon_stun`): every target the enchanted weapon hits is Stunned (`_apply_hit` applies
  CONDITION_STUNNED on a hit) AND the weapon overcomes Invulnerability (the spirit-damage filter
  reads the weapon as `W_MAGIC` when the enchant is active, so invuln tags let it through —
  verified 0→18 damage vs a superior_invuln spirit). (2) **Fires of Purity** (Fire 1,
  `flame_shroud`): a melee attacker striking the shrouded character takes 2k2, and the shrouded
  character's own melee hits deal an extra 2k2 (`_apply_fires_of_purity`, both directions; ranged
  bypasses via the melee gate; ally-targeting deferred — cast target is self). (3) **Reversal of
  Fortunes** (Water 1, `reroll`): a buffed attacker may re-roll a missed attack once per round,
  keeping the better result (`execute_melee_attack` re-rolls on a miss when
  `get_timed_modifier_total(a_p,"reroll")>0` and `reversal_used_round != round`; new
  `Participant.reversal_used_round`). Runtime-verified 4/4 (Stun on hit; overcome-invuln 0→18;
  Fires of Purity cast installs + burns attacker for 10; Reversal raises hit rate 121→146/200).
  LIMITATION: Reversal covers the **attack roll** only (the primary combat roll) — "may re-roll
  ANY one roll per round" across damage/contested/Initiative rolls is forward-wired (each roll site
  would need the same guarded re-roll); Fires of Purity's ally-target option is deferred (NPC
  self-buff path only installs self-target buffs).
- **s31–s37 tile-combat spellcasting — Phase 2 tranche 9: companion-shugenja cast
  (owner-authorized 2026-06-19).** Closes the last spell-reachability gap — wires the same
  `_npc_maybe_cast_spell` hook into `execute_companion_turn` so an allied shugenja companion on a
  PC mission casts too (parity with the kiho companion hook). Placed after the companion kiho
  block, before the melee engage; gated `cmd != RETREAT` (a retreating/broken companion does not
  stop to cast), `ts.can_use_complex()`, non-empty spells_known, and not grappled. Same priority
  (offense at an enemy → heal self/wounded ally → self-buff); companions are FACTION_PLAYER so
  heals target the PC side. Runtime-verified 3/3 (companion casts beam at an enemy for 81; heals a
  wounded PC ally 20→0; a non-caster bushi companion takes no cast_spell action). With this, every
  spell with a clean combat effect is reachable by every NPC/companion combatant in a PC-present
  skirmish; PC casting remains the future turn-based UI.

### s40 Combat Maneuvers — audit + NPC Knockdown (2026-06-19)
Audited the s40 maneuver set against the tile orchestrator. **All maneuver executors
are wired**: Guard (0 Raises, free action), Knockdown (biped/quad, Contested Strength →
Prone), Disarm (Contested Strength + the weapon-grapple free-raise track), Feint
(margin → damage bonus), Increased Damage (+1k0/Raise), Extra Attack (5 Raises), and
the full Grapple sub-action set. **Called Shot** has no dedicated handling and needs
none — GDD s40 says it has "no universal mechanical effect" (GM-ruled sever), and its
Raises are already consumed via the attack's `raises` param. **Disarm's 3-Raise
requirement is not gated** (documented forward-wire; no consumer needs it yet).
**Gap filled — NPC tactical Knockdown:** `_npc_execute_attack` previously only ever
chose `increased_damage`/extra_attack, so NPCs never knocked a dangerous foe Prone.
Added `_npc_should_knockdown` (structural AI, GDD-silent on NPC maneuver policy, same
class as the other `_npc_*` heuristics): a melee attacker with skill ≥ 4 (so the 2-Raise
TN bump is affordable) uses Knockdown against a STANDING target whose best melee skill
(`_NPC_KNOCKDOWN_SKILLS`) is ≥ 3 — a competent fighter worth disrupting; a Prone or
weak target falls through to `increased_damage`. Runtime-verified 5/5 (skilled vs
competent → Knockdown chosen + lands to Prone; skilled vs weak → no Knockdown; skilled
vs already-prone → no Knockdown; skill < 4 → no Knockdown). Disarm/Feint NPC use is a
deliberate non-fill (Disarm 3 Raises rarely worth it; Feint ≈ increased_damage for AI).

### s40 Combat Maneuvers — Disarm consequence + NPC Disarm/Guard (2026-06-19)
Extends the maneuver tactics. **(A) Disarm 3-Raise gate.** The disarm block in
`execute_melee_attack` now enforces GDD s40's 3-Raise cost (`DISARM_RAISES = 3`):
the maneuver only resolves when `called_raises + banked_disarm_free_raises >= 3`
(Earthen Fist / weapon-grapple free raises still reduce it); otherwise
`disarm_insufficient_raises`. **(B) Disarm now has a real consequence.** New
`Participant.disarmed` flag — a disarmed character's weapon is on the ground, so
`execute_melee_attack` forces their attacks to `unarmed` (verified: mean damage 4.1
vs 16.8 armed) until they recover it. `execute_recover_weapon` (a Simple action)
picks it back up. **(C) NPC tactical maneuvers.** Three structural-AI hooks (GDD
gives no NPC maneuver policy): `_npc_should_disarm` — a skill-5+ attacker strips a
still-armed HIGH-threat foe (best melee skill ≥ 4; skips unarmed fighters), taking
priority over Knockdown; a disarmed NPC recovers its weapon on its turn (Simple, so
no Complex attack that turn — the Disarm's tempo cost); `_npc_maybe_guard` — a
bodyguard reflex that Guards (free action, +10 ally Armor TN / −5 own) a wounded
(HURT+) adjacent ally who has an adjacent enemy, then still takes its stance/attack.
Runtime-verified 11/11 (gate insufficient/sufficient; forced-unarmed; recover clears;
NPC disarms armed-high-threat but not unarmed; NPC recovers; NPC guards wounded-
threatened but not healthy ally). Feint NPC use still deliberately skipped
(≈ increased_damage for AI).

### s40 Guard cost — GDD compliance (2026-06-19)
`execute_guard` consumed a **free** action; GDD s40 (LOCKED) says "Guard (0 Raises) —
**Simple Action**." LOCKED wins, so Guard now consumes a Simple (with the standard
`can_use_simple` + down-restriction guards). Consequence: a guarding bodyguard forgoes
its own attack that turn (1 Complex OR 2 Simple — a Simple spent on Guard blocks the
Complex attack), which is the intended GDD tradeoff. `_npc_maybe_guard` was moved
before the stance pick and now **returns** on a successful guard (the NPC commits its
turn to protecting the ally). Runtime-verified 4/4 (Guard consumes a Simple → no
Complex attack; NPC bodyguard guards a wounded threatened ally and forgoes its attack;
no guard for a healthy ally).

### s40 Combat Maneuvers — NPC Grapple initiation (2026-06-19)
The grappled-state loop (hit / take_control / escape) already ran on later turns, but no
NPC ever *initiated* a Grapple. `_npc_should_grapple` (structural AI, GDD-silent on NPC
policy): a dedicated grappler — Jiujutsu ≥ 4 AND Jiujutsu ≥ its best weapon skill
(`_NPC_WEAPON_SKILLS`, so a katana-5/jiujutsu-4 samurai keeps the sword) — seizes an
adjacent enemy (Complex Action via `execute_grapple_initiate`) instead of striking; the
existing grapple loop takes over next turn. Gated to non-spirit attackers (spirits have
their own engulf/swallow grabs) and skipped while already grappled. Runtime-verified 5/5
(pure grappler initiates; sword-primary samurai attacks instead; Jiujutsu < 4 no grapple;
polearm-primary excluded). Feint NPC use remains a deliberate non-fill (margin/2 ≈
increased_damage's +1k0 for AI, not worth the extra Raise).

### s57.46/s40 Companion PROTECT → Guard (2026-06-19)
Companions already inherit the attack maneuvers (Disarm/Knockdown) via `_npc_execute_attack`,
but a PROTECT-commanded yojimbo never used the s40 **Guard** maneuver on its charge. Added
to `execute_companion_turn`: a companion on the PROTECT command, adjacent (≤1 tile) to its
`command_target_id` charge that is threatened by an adjacent enemy, interposes —
`execute_guard` raises the charge's Armor TN +10 (−5 to its own). Guard is a Simple Action,
so the yojimbo forgoes its attack to ward the charge (the canonical bodyguard tradeoff);
fires before the engage-adjacent-enemy block. Runtime-verified 3/3 (guards a threatened
adjacent charge and forgoes attack; no guard for an unthreatened charge; repositions
instead of guarding when too far from the charge).

### s40 Grapple sub-actions — Break + Pass completed (2026-06-19)
GDD s40 specifies four grapple sub-actions (Hit, Throw, Break, Pass); `execute_grapple_action`
only had Hit/Throw/take_control. Added the two missing: **Break** (Simple Action — the actor
removes itself from the grapple; `IndividualCombat.grapple_break` frees BOTH participants since
a grapple is a two-person bind, neither left Prone unlike Throw) and **Pass** (Free Action —
do nothing, maintain the grapple and retain control). NPC use: a grappled non-controller who
is NOT a dedicated grappler (`_npc_should_grapple` false — a weapon-fighter who got grabbed)
now **breaks free** to return to its weapon next turn, instead of endlessly contesting control;
a dedicated grappler still contests. Runtime-verified 5/5 (break frees both, partner not prone;
pass = free action retaining grapple+control; NPC swordsman breaks free; NPC grappler contests).

### s40/s27.9 Sumai Tournaments + Badger Great Games (2026-06-19)
`IndividualCombat.resolve_sumai_bout` was built but had **zero callers** — sumai wrestling
was unreachable. Added `resolve_sumai_match` (repeated bouts until one wins by 5+, GDD s40
"SUMAI TOURNAMENTS"; safety cap decides persistent near-ties by the last roll) and
`resolve_sumai_tournament` (single-elimination bracket; odd entrant gets a bye; returns
`{champion_id, participant_count, rounds}`). No size bonus applied in pairing (the s45 Large
advantage is a forward-wire; the bout still contests Strength + Jiujutsu). Wired the **annual
Badger Great Games** (s27.9): `DayOrchestrator._process_badger_great_games` fires once per IC
year on the year boundary (the GDD fixes the "once per year" cadence, not the day), gathers
living non-PC wrestlers (Jiujutsu ≥ 1) physically present in the Badger province, runs the
bracket, and gives the champion a **named reputation** (TIER_4 PERSONAL topic, subject =
champion, added to active_topics + the champion's topic_pool). Runtime-verified 9/9 (8-entrant
3-round bracket; strongest wins 20/20; <2 entrants no-op; odd-entrant bye; Great Games excludes
PCs and out-of-province characters; TIER_4 champion topic created and pooled; no-Badger no-op).
LIMITATION (no GDD value, deferred): s27.9 says the champion "gains Glory" but specifies no
number — the Glory award is NOT applied (the named-reputation topic is the deliverable);
"disposition shifts between factions present" likewise deferred (needs an event-attendance
model + values). DEFERRED elsewhere: the Imperial Championship resolver (`resolve_championship`)
is also still unwired (annual/vacancy trigger + winner Glory unspecified).

### s11.5 Topaz Championship wired + resolve_championship latent bug fixed (2026-06-19)
`FestivalSystem.resolve_championship` was built but had **zero production callers** (tests only).
Wired the annual **Topaz Championship** (s11.5 LOCKED): `DayOrchestrator._process_topaz_championship`
fires once per IC year (year boundary, alongside the Great Games). Eligible entrants are that
year's new graduates — Insight Rank 1 living non-PC samurai (the "graduated this year" proxy; no
gempukku-year marker exists); each clan sends up to 3 of its finest by Topaz-stage competence
(Athletics + best(Kenjutsu/Iaijutsu) + best(Etiquette/Lore: History)). Resolved via
`resolve_championship`; the winner is **declared Topaz Champion for one year** — `role_position`
set to RoleRegistry.TOPAZ_CHAMPION, the prior holder simply loses the title (s11.5) — and gains a
named reputation (TIER_4 PERSONAL topic, pooled). **Latent bug fixed:** `resolve_championship`'s
`stage["skill"] == "elemental_ring"` crashed ("Invalid operands Array and String") whenever a
stage skill was an Array (Topaz `["Kenjutsu","Iaijutsu"]`, Amethyst/Topaz Lore options) — GUT
never caught it (non-functional headless); this wiring is the first real execution. Guarded with
`is String`. Runtime-verified 10/10 (eligible Rank-1 winner; title transfer; prior holder loses it;
TIER_4 topic pooled; ≤3/clan cap; <2/no-Rank-1 no-op; Jade elemental_ring no longer crashes).
LIMITATIONS (deferred): the title's Status/Glory change (s46 lists Status 4, RoleRegistry 5.0 — a
GDD/code conflict, not resolved); the offer/refusal model. The displaced Topaz Champion is now appointed an Emerald Magistrate (s11.5/s02.1 "Topaz Magistrates"; deterministic per "most frequently").

### s11.5 Vacancy-triggered Jeweled Championships wired (2026-06-19)
`DayOrchestrator._process_jeweled_championships` (seasonal) fills an empty Jeweled Champion
seat (Emerald/Jade/Amethyst/Ruby/Turquoise). When no living character holds the title, the
Emperor holds a championship: each Great Clan nominates its finest eligible candidate (school
gated by `CHAMPIONSHIP_SCHOOL_PREFERENCE` — Emerald/Ruby Bushi, Jade Shugenja, Turquoise
Artisan); Amethyst is the s11.5 exception, nominated by the Imperial families (Seppun/Otomo/
Miya). Resolved via `resolve_championship`; the winner takes the title (`role_position`) and
gets a TIER_3 POLITICAL named-reputation topic. Now an Emerald/etc. Champion who dies is
actually replaced (previously the seat stayed empty forever). Runtime-verified 7/7 (vacant
Emerald filled with 7 Great-Clan nominees + title set; filled seat not re-contested; Jade
skipped when no shugenja; Amethyst from Imperial families only, great-clan excluded).
DEFERRED (no values / model): the 1–3 season Emperor-call gap (fires the season the vacancy
is seen), the full weighted clan-nomination eval (a competence proxy picks each nominee), the
extraordinary-championship path (Tier 2), and the Emerald-Magistrate appointment.

### s57.24 displayed-bonsai visitor effect wired (2026-06-19)
`GardenSystem.apply_bonsai_visitor` was built but never called — displayed bonsai gave no
visitor effect (gardens do). `DayOrchestrator._process_bonsai_visitor_effects` (daily, beside
the garden pass) gives co-located living characters a disposition bonus toward the bonsai's
owner (by quality tier), duplicate-guarded per visitor per bonsai and expiring after
VISITOR_BONUS_DURATION_DAYS. Bonsai guard entries carry `kind:"bonsai"` so they never collide
with garden ids in `active_garden_bonuses`. Owner excluded, dead/undisplayed bonsai skipped.
Runtime-verified 6/6 (tier-3 bonus; far/owner excluded; duplicate guard; garden#7 doesn't block
bonsai#7; undisplayed no-op). Glory ticks not applied (apply_bonsai_visitor returns 0 — bonsai
have no visitor-count field, unlike gardens).

### s12.2b war/peace collective-disposition ripple wired (2026-06-19)
`CollectiveDisposition.apply_clan_war_declared` / `apply_clan_peace_treaty` were built but never
called — declaring war or making peace never shifted the two clans' collective baseline (the
single most significant inter-clan event did nothing to collective standing). `_apply_war_collective_disposition`
(advance_day, after war declaration + termination) applies the Event-Ripple deltas: war declared
−10, negotiated/surrender peace +5 (existing s12.2b constants). Annihilation is excluded (no
treaty — the loser is gone); already-active re-declarations apply nothing; peace clans resolved
from the war_id via active_wars. Runtime-verified 4/4.

### s12.2b duel-death family ripple wired (2026-06-19)
`CollectiveDisposition.apply_family_duel_death` was dead. `_process_duel_death_writebacks` now
shifts the victim's and killer's family collective baseline (−5, existing s12.2b constant) on a
duel fatality (same-family duels skipped). Intra-clan rice sharing now warms the giver's and recipient's family baseline (+2, same-clan
different-family, in `_process_supply_sharing`). Harvest raids now sour the raiding lord's family against the raided province's family (−3,
in `_apply_harvest_destruction`) — replacing the removed-as-invented `destroyed_harvest`
per-character modifier with the LOCKED family-baseline ripple. Traced assassinations now sour the commissioner's family against the victim's family (−10, in
the vengeance pipeline). **All s12.2b collective Event-Ripple functions are now wired** (clan:
war/peace; family: duel-death, rice-sharing, lord-raid, betrayal). Runtime-verified 10/10.

### s55.22b Otomo Seiyaku detection wired (2026-06-19)
`OtomoSeiyakuSystem.apply_detection` was dead — the §6.1 detection/counterplay against Otomo
alliance-suppression never fired. `DayOrchestrator._process_seiyaku_detection` (seasonal, before
the seiyaku review) lets a co-located non-Otomo character detect each active suppression directive
via a contested Courtier/Awareness roll; on success `apply_detection` halves the operative's
effectiveness for the season (consumed by estimate_seasonal_effect) and a Tier-4 "Otomo
Manipulation Detected — A/B Targeted" topic seeds to the detector. effectiveness_halved is reset
each season (the per-court-session window). Values GDD-exact (halved effectiveness). Runtime-verified
5/5 (strong detector halves + topic + learns; Otomo courtier excluded; runs vs strong operative).
LIMITATION: the diffuse "+5 sympathy toward the targeted clans from all who learn" is deferred
(no per-clan sympathy field).

### s12.9 Intimidation Compliance Tracker wired (2026-06-19)
The "complying under duress" relationship (s12.9 Compliance Tracker, LOCKED) was entirely
unwired — the five compliance helpers (resolve_pushback, can_compliance_end, etc.) had no
callers and there was no persistent state. Built end-to-end:
- **State:** `WorldState.active_intimidations: Array[Dictionary]` (intimidator_id, target_id,
  leverage_secret_id, established_ic_day), persisted via WorldStateSaver state.json; threaded
  through advance_one_day → advance_day.
- **Creation** (`_process_intimidation_compliance`, post-wave): a successful INTIMIDATE with
  `compliance_active` creates/refreshes an entry (re-intimidation resets the clock).
- **Maintenance** (same pass): the four GDD end-conditions — intimidator (or target) dead;
  intimidator's disposition toward target reaches Friend range (`can_compliance_end`); the
  blackmail leverage secret is exposed; or the target pushes back (Willpower vs TN 15 +
  intimidator Intimidation rank, `resolve_pushback`, rolled each later tick). A freshly
  established entry has a one-tick grace (no pushback the day it lands).
- **Effect** (`_apply_compliance_filter`, NPC engine Phase 4): a compliant character cannot
  select a HOSTILE action against an intimidator they are complying with (per-character
  `compliance_intimidators` injected into world_states, read into ContextSnapshot, cleared
  by the stale-key pass; sleeper-override path exempt). Non-hostile actions and hostile
  actions vs other targets are unaffected.
Values are GDD-exact (pushback TN 15 + Intimidation rank; Friend threshold 31). Runtime-verified
9/9 (creation + grace; hostile-vs-intimidator blocked while other/friendly allowed; all four
end-conditions; low-WP persists vs strong intimidator 20/20; high-WP breaks free; injection).
The s12.9 line-35 court +10-TN effect is now ALSO wired (see below). Deferred: the "on
compliance end, immediately make the suppressed Public Declaration" nuance.

### s15.4a court session-TN reductions consumed + s12.9 court compliance penalty (2026-06-19)
The court session-TN reduction mechanic (s15.4a, LOCKED) was inert: successful Negotiate/Impress
(−5) and Listen/Reflect (−10) correctly ACCUMULATED a per-target reduction pool in the court
session_state (success-gated), but `_execute_contested_court_action` never CONSUMED it, so
repeated court persuasion never got easier. Wired the consumption: a Negotiate's defender roll is
lowered by the Negotiate/Impress pool + the Listen/Reflect pool; a Persuade's by the Listen/Reflect
pool (floored at 0). Same site now applies the s12.9 court compliance penalty: a character complying
under duress faces +10 (`COMPLIANCE_COURT_TN_PENALTY`) on any court action toward the intimidator
they comply with (`ctx.compliance_intimidators`) — covering non-hostile court opposition the
Phase-4 hostile filter doesn't. Runtime-verified 3/3 (accumulated reduction lifts Negotiate
success 44→79/80; compliance +10 drops it 44→18/80; Persuade eased only by the persuade pool).

### s31-37 spell combat coverage — extension batches 1–5 (2026-06-20)
Added combat effects for 4 more library spells (the library has 287 spells; only ~28 had combat
effects). All values transcribed exactly from s34/s35: **tail_of_the_fire_dragon** (Fire 2,
single damage DR=Fire Ring, 30'), **ravenous_swarms** (Fire 3, 5k3 bolt, 30' — the fire-spell-
disruption rider deferred), **the_dragons_talon** (Fire 5, 8k6 AoE, up to 10 targets, 100',
only foes of Insight Rank ≤ 2), **grasp_of_earth** (Earth 2, Entangled, 50'). Two new
`_gather_spell_targets` fields support Dragon's Talon: `target_max_insight` (skip stronger foes)
and `aoe_max_targets` (cap struck count). Runtime-verified 5/5 (damage lands; grasp entangles;
Dragon's Talon hits Insight-1/2 foes and spares an Insight-5 foe). The remaining ~255 library
spells without combat effects are mostly utility, conjured-weapon, or need mechanics the schema
lacks (weapon replacement, terrain pits with save-negates-damage, conditional-expiry buffs).

### Pending Redesign
(None currently pending.)

### ASCII Map System — Live-Reachability Status (2026-06-20)
**The ASCII map / tile-combat layer is extensively built and partly verified, but is NOT
reachable in a live game session.** Full file-by-file breakdown in `ASCII_MAP_GAP_REPORT.md`
(repo root). Summary:
- **No production entry point.** The only caller that starts a mission is `scripts/ui/combat_demo.gd`
  (a manual demo scene). The world sim never launches a mission — the trigger is **PC world-map
  travel, which is ON HOLD per owner (2026-06-06)**. `mission_flow.gd` (world→mission glue) is
  written but unverified and unwired.
- **Best-verified:** combat math core (`individual_combat`, s40 maneuvers/grapple, NPC AI,
  companions) and the map generators (connectivity-swept under Godot).
- **Unverified-at-runtime:** `combat_controller` and most of the mission pipeline are GUT-test-only
  (GUT is non-functional headless). The s56.16 spiritual encounter loop is static-only.
- **Coverage gaps:** many s31–37 spells have no combat effect yet; several creature abilities
  deferred; **no human turn-based command UI** (a player can move/door/look/disarm only — not
  attack/cast/maneuver). Relocation (s56.13), in-mission kansen, falling damage are wired but have
  no trigger (all wait on live entry).
- **Single unlock:** lifting the PC-travel HOLD → wire `world arrival → MissionEntryController →
  MissionLauncher → CombatScreen`, then build the player command loop and runtime-verify the
  static-only layers.

### Tuning Review Needed After First Live Run
- **School-less ring progression rate.** School-less characters (born ronin, unschooled)
  advance skills before rings (s52 Part 3 school-less path). A character with many rank-1–2
  skills may spend 4–6 seasons on skills before touching rings. At peacetime XP rates,
  raising a ring from rank 2 to 3 takes ~8 OOC years. If playtest reveals rings growing
  too slowly relative to skills, consider interleaving (raise one ring after every N skill
  advances) or adjusting the priority order. Do not change the order without playtesting
  first — the current design is principled and matches "Strengths + spread rings" intent.

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
  +5 skill bonus now wired to all 7 early-return court action paths
  (GOSSIP, PUBLIC_INSULT, PUBLIC_DEBATE, BROADCAST_SOCIAL, PROVOKE_EMOTION,
  PROBE, DISCERN_NEED, ASK_FOR_INTRODUCTION). 3 tests.
  Champion agenda ordering AI already implemented and wired
  (order_agenda_for_host called in day_orchestrator, 5 tests).
  Travel logistics letter dispatching already implemented
  (_dispatch_winter_court_summons, 7 tests). Late arrival handling already
  implemented (_process_court_attendance, 2 tests).


### Known Code Issues (found and fixed 2026-05-29, zeroed constant audit)
- **6 topic momentum constants zeroed → replaced with tier-floor values. FIXED.**
  `_COMBAT_EVENT_MOMENTUM`, `_CIVIL_WAR_MOMENTUM`, `_CONSTRUCTION_TIER2_MOMENTUM`,
  `_FAMINE_HUNGER_MOMENTUM`, `_FAMINE_FAMINE_MOMENTUM` in `day_orchestrator.gd` and
  `HARVEST_TOPIC_MOMENTUM` in `starvation_warfare.gd` were all `0.0` (invented values
  removed during audit). Replaced with `TopicMomentumSystem.initial_momentum_for_tier(tier)`
  at each call site — using the already-locked `TIER_INITIAL_MOMENTUM` table from s16.1
  (TIER_3 floor = 26.0, TIER_2 floor = 51.0). Constants deleted. 4 test files updated.
- **`_FAMINE_RECOVERY_THRESHOLD` locked at 4 seasons. FIXED.** Was `0` (invented value
  removed). Set to `4` per GDD s4.3.6 "four seasons of uninterrupted adequate food."
  Locked in `gdd/s04.3a_famine_recovery_threshold_locked.md`. Tests already handled
  both zero and non-zero cases via guard; assertions remain correct with threshold=4.
- **Remaining zeroed constants confirmed correct at 0 per GDD or blocked.** `DUEL_DECLINE_GLORY_LOSS`
  stays 0 (GDD Table 2.4 has no duel-decline glory entry). `EVIDENCE_DECAY_INTERVAL_DAYS`
  stays 0 (GDD s11.3.13 "Recorded evidence is permanent" — decay is intentionally disabled).
  `COLD_CASE_THRESHOLD` stays 0 (decay disabled, never fires). `INTIMIDATION_DISPOSITION_PENALTY`
  stays 0 (GDD s11.3 specifies provocation flag only, not a disposition value). `INAUSPICIOUS_PENALTY`
  and `TAIAN_BONUS` stay 0 (GDD says rokuyo is not a mechanical modifier for NPC scoring).
  `_RETREAT_DEFAULT_DAYS` stays 0 (blocked on sub-tile army movement s11.7a). `TAINT_DETECTION_PLACEHOLDER_TN`
  REMOVED 2026-06-10 — Maho Channel 3 now uses the owner-set TN = (8 − Taint Rank) × 5.
  `get_renege_willingness()` values stay 0 (function
  never called; GDD says "All renege values PROVISIONAL"). `compute_peace_willingness()`
  already returns qualitative dict (correct per GDD s53 "not determined by a single threshold").
  `get_patrol_detection_chances()` already returns qualitative dict (correct per GDD s11.3.19
  "more chances to detect" — no numeric formula).

### Known Code Issues (found and fixed 2026-05-29, RESTORE_COUNCIL_COMPACT)
- **`_assign_phoenix_champion_restore_objective()` — two key bugs. FIXED.**
  (1) Checked `phoenix_council_state.get("champion_authority_active", false)` — this key
  is never set. The actual state key is `"phoenix_champion_authority"` (set by
  `PhoenixCouncil.grant_champion_authority()`). Function always returned early without
  assigning objectives. Fixed to use `"phoenix_champion_authority"`.
  (2) Read `"champion_id"` from state — this key also doesn't exist. The actual lookup
  is `"known_champion_id"`, but the cleanest fix is to delegate to `_find_shiba_champion()`
  which is already in the same class and handles dead/non-champion cases correctly.
  5 tests added to test_governance_exceptions_wiring.gd: Chugi champion gets objective,
  non-Chugi (Ishi/Shourido) champion skipped, no-authority champion skipped, dead champion
  skipped, dedup prevents reassignment.

### Known Code Issues (found and fixed 2026-05-29, strategic_review.gd audit)
- **run_priority_resolved() Ketsui refill — dispatches silently discarded. FIXED.**
  `run_priority_resolved()` called `run_clan_champion_evaluation()` for Ketsui champions
  but discarded the return value and returned `[]`. `run_clan_champion_evaluation()` returns
  letter dispatch Dictionaries for absent Family Daimyo — they were never reaching the
  orchestrator, so FDs were never notified after a Ketsui priority refill. Changed
  `run_clan_champion_evaluation(...); return []` to `return run_clan_champion_evaluation(...)`.
  1 test.
- **_CONCLUSION_TO_NEEDTYPES DEFEND_TERRITORY — ASSIGN_GARRISON invalid NeedType. FIXED.**
  "ASSIGN_GARRISON" is an ActionID, not a NeedType. It had no entry in objective_alignment.json
  so any FD that received it as a combined pool candidate would score all actions at 0 and
  silently fall to REST. DEFEND_PROVINCE (already in the list) covers garrison-level defensive
  needs. Removed ASSIGN_GARRISON from the DEFEND_TERRITORY NeedType array. 1 test.
- **_CONCLUSION_TO_NEEDTYPES RESTORE_WORSHIP — RESTORE_WORSHIP NeedType missing. FIXED.**
  ConclusionType.RESTORE_WORSHIP mapped to ["PERFORM_RITUAL", "BUILD_INFRASTRUCTURE",
  "GATHER_INTELLIGENCE"]. The "RESTORE_WORSHIP" NeedType (locked in s57.54a A37) was not
  included, so FDs responding to a Champion's worship-restoration priority never received
  the dedicated NeedType that maps to PERFORM_WORSHIP (90), PERFORM_RITUAL (80), BUILD_SHRINE
  (70), etc. Added "RESTORE_WORSHIP" as the first entry in the mapping. 1 test.

### Known Code Issues (found and fixed 2026-05-29, combined pool audit)
- **_process_lying_honor_writebacks() — string key in int-keyed dictionary, LYING honor never fires. FIXED.**
  `fabricator.disposition_values.get(str(subject_id), 0)` used `str(subject_id)` (string) but
  `disposition_values` uses int character IDs as keys throughout the codebase. The lookup always
  returned 0, so `disp > 0` never fired — fabricators who liked their target never received the
  LYING honor penalty. Fixed to `fabricator.disposition_values.get(subject_id, 0)`. Five test
  setups in test_day_orchestrator.gd and test_system_wiring.gd also updated from `{"5": 20}` to
  `{5: 20}` int keys. 5 tests updated.
- **ReactiveDecisions._has_mentor_objective() — key mismatch, KETSUI always declines training. FIXED.**
  `_has_mentor_objective()` checked `primary.get("objective_type", "") == "MENTOR_CHARACTER"` but
  lord-assigned objectives from `_apply_vassal_objective_assignment()` only set `"need_type"` (no
  `"objective_type"` field). KETSUI-virtue students always received `has_mentor_objective = false`
  regardless of their lord's directive, causing them to always decline training via `self_reliance`.
  Fixed to `primary.get("need_type", "") == "MENTOR_CHARACTER"`. Test
  `test_ketsui_accepts_with_mentor_objective` also updated from `"objective_type"` to `"need_type"`.
  1 test updated.
- **resolve_goal() combined pool condition too broad — Champions entered combined pool path. FIXED.**
  `if ctx.is_lord and ctx.lord_rank >= Enums.LordRank.FAMILY_DAIMYO` matched CLAN_CHAMPION and
  IMPERIAL characters. Neither gets `champion_conclusion_candidates` or `local_tier3_candidates`
  injected (orchestrator injects only for `lord_rank < CLAN_CHAMPION`). A Champion with no
  lord-assigned primary would find an empty combined pool and fall to REST, silently losing their
  self-selected primary objectives. Fixed to `== Enums.LordRank.FAMILY_DAIMYO`. Champions and
  Imperial now fall to the `else` branch and use the standard primary path (the same path as
  non-lord characters). 2 tests.
- **RESTORE_WORSHIP missing from objective_alignment.json — FDs never respond to supernatural crises. FIXED.**
  `_build_local_tier3_candidates()` maps SUPERNATURAL topic category → `RESTORE_WORSHIP` NeedType
  per GDD §57.54.10b line 361. But `RESTORE_WORSHIP` had no entries in `objective_alignment.json`,
  so all actions scored 0 → allowlist filter stripped everything → FDs did nothing in response to
  spirit realm overlaps, fortune displeasure, or elemental imbalance crises. Added 8 action entries
  per s57.54a A37a–A37h: PERFORM_WORSHIP (90), PERFORM_RITUAL (80), BUILD_SHRINE (70),
  FOUND_TEMPLE (60), PURIFY_TAINTED_GROUND (55), ASSIGN_VASSAL_OBJECTIVE (45), MEDITATE (35),
  FOUND_MONASTERY (30). Locked in `gdd/s57.54a_restore_worship_needtype_locked.md`.

### Known Code Issues (found and fixed 2026-05-29, B6 Table 2.3 trigger audit)
- **DUPED_FOOLISH `target_province_id` not checked — PATROL_PROVINCE victims always penalised. FIXED.**
  `_process_duped_foolish_on_arrival()` only checked `target_npc_id` and `target_settlement_id`.
  FORGE_ORDER → PATROL_PROVINCE sets only `target_province_id` (no settlement or NPC target).
  Victims arriving at any settlement in the target province had `has_target_here = false` and
  incorrectly received DUPED_FOOLISH honor loss even when they arrived exactly where the forged
  order directed. Added `settlements: Array = []` parameter, built settlement→province lookup dict
  via `SettlementData.province_id`, and added `target_province_id` check as third target-match
  branch. Call site updated to pass `settlements`. 2 new tests (province_match skips, province_mismatch fires).
  8 additional orchestrator tests added covering all three B6 trigger conditions (LYING disposition
  gate, DUPED_FOOLISH NPC/settlement/province targets, DUPED_CRIMINAL deadline ordering).

### Known Code Issues (found and fixed 2026-05-29, public record seeding audit)
- **Duel deaths and open killings never seeded into settlement public record. FIXED.**
  `_seed_public_records_from_crime_results()` required `auto_detected: true` in wave results
  for any crime to be seeded. UNSANCTIONED_DUEL_DEATH and UNSANCTIONED_OPEN_KILLING are
  inherently public (they happen in front of witnesses by definition) but only set
  `requires_crime_creation: true`, not `auto_detected: true`. The early-return guard
  (`if auto_detected_locations.is_empty(): return`) caused the function to exit before
  processing any crime_results when no violence executor had fired. Restructured:
  settlements_by_str_id is built before the early-return check; INHERENTLY_PUBLIC array
  gates a second location-lookup path for UNSANCTIONED_DUEL_DEATH and
  UNSANCTIONED_OPEN_KILLING; other crime types still require `auto_detected: true`.
  Early-return changed to `if crime_results.is_empty(): return` (the only truly cheap
  skip). 5 tests.
- **Dead investigator guard missing in EXAMINE_CRIME_SCENE public record query. FIXED.**
  Line 3264 checked `investigator != null` but not `CharacterStats.is_dead(investigator)`.
  Dead characters who completed EXAMINE_CRIME_SCENE before dying mid-day could have
  their `topic_pool` updated from the public record. Added dead guard. 1 implicit (guard
  tested through existing patterns).
- **`_purge_delivered_letters` — dead victim allowed forged order letter to be retained forever. FIXED.**
  The forged-order retention guard (`if victim != null:`) kept letters when the victim was dead.
  Dead victims cannot discover impersonation (they never enter the decision loop), so forged
  order letters targeting dead victims should be purgeable on the normal 180-day schedule.
  Added `not CharacterStats.is_dead(victim)` to the retention check: dead victims fail the
  guard, letter is pruned as a normal old letter. Also added 14 tests covering all B10 purge
  functions: `_purge_resolved_crime_records` (5 tests — removes terminal old, keeps terminal
  recent, all 4 terminal statuses, keeps FUGITIVE, keeps UNDER_INVESTIGATION),
  `_purge_delivered_letters` (6 tests — removes old, keeps recent, keeps undelivered, retains
  undetected forged order, purges detected forged order, purges forged order with dead victim),
  `_purge_exposed_secrets` (3 tests — removes public, keeps private, mixed). 14 tests.

### Known Code Issues (found and fixed 2026-05-29, OpportunityScanner audit)
- **`character.objectives_map` — undeclared property, null crash on fresh characters. FIXED.**
  `_scan_artistic_expression()` line 468 accessed `character.objectives_map.get(...)` but
  `objectives_map` is a world-level Dictionary (keyed by character_id on WorldState), not a
  field declared on `L5RCharacterData`. In production, `character.objectives_map` returns null
  on a fresh character and `null.get("primary", {})` crashes at runtime. The strategic_review
  caller filters active primary objectives before calling OpportunityScanner, so this is benign
  on the nominal path, but reachable when a primary exists with status != "ACTIVE". Changed to
  `character.get("objectives_map", {}).get(...)` which returns `{}` gracefully when unset.
  1 test added: `test_artistic_expression_no_crash_without_objectives_map` verifies scan runs
  without crash and returns ARTISTIC_EXPRESSION on a character without the dynamic property set.

### Known Code Issues (found and fixed 2026-05-29, collective disposition audit)
- **test_marriage_applies_standard_deltas / test_champion_marriage_applies_higher_deltas —
  tests coded to old s12.2b permanent-baseline design; implementation uses s22.7 decaying
  layer. FIXED.** The implementation (`apply_marriage()`) deliberately chose s22.7's
  separate decaying boost layer over s12.2b's permanent baseline modification (comment:
  "s22.7 wins"). The two tests were written before this redesign and still expected
  `clan_change`/`family_change` return keys and direct mutation of `_family_baselines`.
  Both tests updated to verify the actual s22.7 behavior: `marriage_family_boosts` and
  `marriage_clan_boosts` are populated with the correct values, return dict has
  `family_boost`/`clan_boost` keys, and `_family_baselines` is NOT modified.
  `test_champion_marriage_applies_higher_deltas` now verifies that the `_champion_level`
  flag has no effect on the decaying layer (s22.7 does not differentiate tiers).
  2 tests updated.

### Known Code Issues (found and fixed 2026-05-29, writeback audit)
- **LYING honor trigger always returned 0 — string/int key mismatch. FIXED.**
  `_process_lying_honor_writebacks()` called `disposition_values.get(str(subject_id), 0)`
  but `disposition_values` uses int keys throughout. Lookup always returned 0 so LYING
  honor (Table 2.3) never fired for any fabricator. Fixed to use int key directly.
  5 test setups updated from string keys to int keys. 1 test.
- **CANCEL_HUNT disposition penalties never applied — accepted_invitee_ids always empty. FIXED.**
  `_populate_action_metadata()` set `"accepted_invitee_ids": []` (hardcoded empty array) for
  CANCEL_HUNT. The executor reads this from `action.metadata`, so `effects["accepted_invitee_ids"]`
  was always empty, and `_process_cancel_hunt_writebacks()` never penalized invitees.
  Fixed: `_inject_hunt_context()` now also injects `hunt_accepted_invitee_ids` from the active
  hunt dict for host characters. `_populate_action_metadata()` reads from
  `ctx.known_objectives.get("hunt_accepted_invitee_ids", [])` instead of hardcoding `[]`. 1 test.
- **Dead character guards missing from 8 writeback/apply functions. FIXED.**
  `_apply_promise_fulfillment_honor()` debtor, `_process_duel_honor_writebacks()` actor/target,
  `_process_kindness_honor_writebacks()` actor/target, `_process_truthful_report_honor_writebacks()`
  actor, `_process_protecting_clan_honor_writebacks()` actor — all checked null but not dead.
  Dead characters received honor changes from promise fulfillment, duel outcomes, gift-giving,
  secret exposure, and sortie actions.
  `_apply_appointment()` appointee, `_apply_service_assignment_effect()` target,
  `_apply_vassal_objective_assignment()` vassal, `_apply_court_invitation()` invitee,
  `_apply_marriage()` both parties — dead characters could be appointed to positions,
  assigned to military service, receive lord objectives, added to court invitation lists,
  and married. Added `CharacterStats.is_dead()` guards at all 9 sites.

### Systems Added 2026-05-29
- **s11.3.12a Violence System — INFAMY_PER_REPEATED_OFFENSE locked.** `INFAMY_PER_REPEATED_OFFENSE`
  set to 0.1 (was 0.0). Locked in `gdd/s11.3.12a_violence_repeated_offense_infamy_locked.md`.
  Calibrated at floor of infamy accrual: public intimidation +0.1, blackmail +0.1 (both s12.9).
  Two existing test names updated to reflect the lock (were `*_zeroed_pending_gdd_spec`,
  now `*_locked_s11_3_12a`).
- **s57.50 Settlement Public Record** — `simulation/public_record_system.gd`,
  `shared/settlement_data.gd` (add `public_record: Array`). Settlement-level buffer of public
  events to bridge commoner memory into the information system. Design confirmed: settlement-level
  locality (optional `zone_subtype` forward field for future zone narrowing), two retrieval paths
  (ambient free within tier-scaled window + investigation roll for older entries), tier-scaled
  retention (TIER_4=90d, TIER_3=360d, TIER_2=1080d, TIER_1=permanent). Ambient windows: TIER_4=14d,
  TIER_3=90d, TIER_2=360d, TIER_1=always. Investigation TN: 10 + floor(days_past_window/10),
  capped 30. DayOrchestrator wiring: `_seed_public_records_from_crime_results()` fires after
  `_process_crime_detection()` for any result whose executor effects had `auto_detected: true`;
  `_pickup_ambient_public_records()` runs daily before NPC wave to seed topics to living present
  non-traveling characters; `_purge_settlement_public_records()` fires at season boundary.
  EXAMINE_CRIME_SCENE investigation now also queries settlement public record for older entries
  using the investigation roll total (added `roll_total` to `InvestigationSystem.examine_scene()`
  and `ActionExecutor._execute_examine_crime_scene()`). `_process_scene_examination_writebacks()`
  gains optional `settlements` parameter. `_crime_tier_for_public_record()` maps crime types:
  VIOLENCE→TIER_4, open/duel killings→TIER_3, TREASON/EMPERORS_PEACE→TIER_2. 20 tests.
  ViolenceSystem is wired into the non-lethal bodyguard combat path (s11.3.12): when an
  assassin and bodyguard both survive `resolve_npc_summary_combat()`, `evaluate_violence()`
  fires with `is_brutal=true`, `apply_consequences()` applies honor/glory/infamy,
  a CrimeRecord is created as UNDER_INVESTIGATION, and the settlement public record is
  seeded via `_seed_assassination_violence_public_records()`. The `violence_offense_days:
  Array[int]` field on L5RCharacterData tracks per-character offense history for the
  repeat-offense window. Violence is not a deliberate AP action — it is an organic outcome
  of physical confrontation, as the GDD specifies.

### Known Code Issues (found and fixed 2026-06-01, standing objectives audit)
- **`compute_tend_personality_bonus()` never called — personality modifiers silently dropped. FIXED.**
  `MedicineSystem.compute_tend_personality_bonus()` was defined with GDD-specified constants
  (JIN+15, GI+10, REI+5, CHUGI+20 for lord/superior target) but was never called in the
  TEND_WOUNDED_ALLY opportunity injection loop in `npc_decision_engine.gd`. Priority was
  computed from `compute_tend_priority()` only. Added call after priority computation;
  `is_superior` derived from `character.lord_id` and `character.operational_superior_id`.
  3 tests.
- **Monk standing objectives never assigned — `_assign_monk_standing_objectives()` missing. FIXED.**
  Despite CLAUDE.md claiming s55.11b was implemented, the function
  `_assign_monk_standing_objectives()` did not exist in `day_orchestrator.gd`.
  All SchoolType.MONK characters had no standing objective, causing monks to fall through
  to REST every AP. Added function in the same standing-assignment block as magistrates,
  ronin, and Kaiu Engineers. Assigns PERFORM_RITUAL as universal default (Meditate +
  Worship types). School-based differentiation deferred — GDD specifies school-based
  selection but provides no school→type mapping table. 5 tests in `test_ronin_system.gd`.
- **FIND_NEW_LORD, PERFORM_RITUAL, MAINTAIN_FORTIFICATION fell through generic passthrough. FIXED.**
  Three standing NeedTypes fell through the generic `_passthrough()` at the end of
  `ObjectiveDecomposer.decompose()` without being listed in any dispatch array.
  Functionally correct (all have appropriate alignment tables, no context branching needed),
  but undocumented. Added explicit dispatch paths: FIND_NEW_LORD added to
  PERSONAL_OBJECTIVES with `_decompose_find_new_lord()` (all contexts → passthrough;
  Phase 4a `_pick_lord_for_petition()` handles targeting). PERFORM_RITUAL added to
  PERSONAL_OBJECTIVES with `_decompose_perform_ritual()` (passthrough). MAINTAIN_FORTIFICATION
  added to MILITARY_OBJECTIVES with `_decompose_maintain_fortification()` (passthrough;
  Phase 4a reads wall_statuses for target_province_id). All four standing NeedTypes
  (UPHOLD_LAW, FIND_NEW_LORD, PERFORM_RITUAL, MAINTAIN_FORTIFICATION) now have explicit
  dispatch paths. 6 tests in `test_objective_decomposer.gd`.

### Systems Added 2026-06-01
- **s52.5 Ronin Petition** — GDD `gdd/s52.5_ronin_petition_locked.md`. Full petition pipeline
  confirmed implemented (was previously wired but undocumented as a standalone system entry).
  `make_ronin()`: lord_id/role/military/hierarchy cleared, status −1.0 (floor 0), Glory loss by
  cause (LORD_DEATH_NO_HEIR=0.3, CLAN_DESTROYED=1.0, DISMISSAL=0.3, DISMISSAL_DISGRACE=2.0,
  VOLUNTARY_DEPARTURE=rank-scaled disloyalty via CrimeSystem.get_disloyalty_honor()).
  `lord_auto_rejects()`: hard-rejects permanent ronin, negative disposition, TREASON/MAHO_USE/
  UNSANCTIONED_COVERT_KILLING crimes. `resolve_petition()`: contested Courtier+Awareness vs
  Etiquette+Awareness, PETITION_MIN_TN=20, presentation_modifier=margin/PETITION_MARGIN_SCALE(5),
  failure=−3 disposition + 90-day per-lord cooldown keyed as
  `supply_ledger["petition_refused_until_<lord_id>"]` (A50c — scoped so refused-lord 200 does not
  block petitioning lord 201). `accept_into_service()`: lord/role assignment, status floor 1.0,
  HIRING_GLORY_RECOVERY=+0.3, clan unchanged (formal induction is s52.7). Permanent ronin: 5
  DISMISSAL_DISGRACE CrimeRecords → permanent_ronin flag. PETITION_RONIN executor (VISITING
  context, 1 AP): per-lord cooldown check, auto-reject path (no roll-failure penalties applied),
  contested roll, `requires_ronin_acceptance` flag on success. ACCEPT_RONIN_PETITION executor
  (AT_OWN_HOLDINGS, 1 AP): lord-side initiation path. `_process_petition_writebacks()`: cooldown
  write on roll failure, `accept_into_service()` on success, FIND_NEW_LORD standing cleared.
  `_assign_ronin_standing_objectives()`: daily assignment for living non-permanent ronin without
  existing standing. FIND_NEW_LORD NeedType: PETITION_RONIN=90, BEGIN_TRAVEL=80, WRITE_LETTER=60.
  FILL_VACANCY: ACCEPT_RONIN_PETITION=40. Income tracking, desperation/insurgency seeding,
  mercenary hire, `process_seasonal_ronin()` also in `simulation/ronin_system.gd`. Constants
  A38–A50c locked. ~75 tests in `tests/test_ronin_system.gd`.

### Systems Added 2026-05-30
- **s52.6 Ronin Contract Hire** — GDD `gdd/s52.6_ronin_contracts_locked.md`. Three contract types
  (PROVINCE_DEFENSE=3 koku/season, MAGISTRATE_AIDE=2 koku/season, MILITARY_SERVICE=2 koku/season).
  HIRE_RONIN ActionID (1 AP, lord-only, AT_OWN_HOLDINGS+VISITING, Courtier/Awareness TN 10):
  validates ronin present/alive/non-permanent/uncontracted, lord koku sufficient, ronin's disposition
  toward lord ≥ 0, rolls Courtier TN 10, injects CONTRACT_OFFERED reactive event on success.
  ReactiveDecisions._evaluate_contract_offer(): desperate→auto-accept, disposition≥31→auto-accept,
  Chugi accepts PROVINCE_DEFENSE/MAGISTRATE_AIDE, Meiyo accepts at disp≥0, Ketsui always accepts,
  Ishi refuses unless desperate, Seigyo/default accept at disp≥0. Contract acceptance writeback:
  koku deducted from lord, paid to ronin, accept_into_service(), contract_end_ic_day/type/lord_family
  stored in supply_ledger, NeedType primary objective assigned (DEFEND_PROVINCE/UPHOLD_LAW/LEVY_TROOPS),
  FIND_NEW_LORD standing cleared. Contract decline: CONTRACT_DECLINE_DISPOSITION (−1) both directions.
  Contract expiry (daily check): clean (primary source==contract)→complete_contract (+0.5 glory, deed++),
  abandoned→CONTRACT_ABANDONED_DISPOSITION (−5) to lord. TERMINATE_CONTRACT (0 AP, 1 civilian order):
  half-koku refund, CONTRACT_EARLY_TERMINATION_DISPOSITION (−3) to lord disposition. Constants A51–A59
  locked. 44 tests.
- **s52.8 TERMINATE_CONTRACT NeedType** — GDD `gdd/s52.8_terminate_contract_needtype_locked.md`.
  TERMINATE_CONTRACT wired under ADJUST_TAX NeedType at score 35 (below SET_STIPEND_RATE=60 for
  social-cost penalty, above WRITE_LETTER=30). Phase 4c precondition filter removes it when
  `has_active_contracts=false`. `has_active_contracts` injected per lord via pre-built set of
  contract holders scanned before wave resolution; cleared by stale-flag pass. Constants A77–A79
  locked. 6 tests.
- **s52.7 Clan Induction** — GDD `gdd/s52.7_clan_induction_locked.md` (redesigned).
  Three-stage process: (1) 8 deed credits from contract completions, (2) 1 extraordinary
  deed (contract completed while lord's clan at war AND province in crisis AND 3+ season
  service), (3) Family Daimyo approval then Provincial Daimyo ceremony.
  GRANT_DEED_CREDIT removed entirely — lords cannot fast-track via manual grants.
  APPROVE_CLAN_INDUCTION (0 AP, 1 civilian order, AT_OWN_HOLDINGS+AT_COURT): Family Daimyo
  only, validates 8 deeds + 1 extraordinary deed + disposition≥51, stores approval in
  `supply_ledger["family_daimyo_approval"]`. Approval can be granted remotely.
  PERFORM_CLAN_INDUCTION (2 AP, AT_OWN_HOLDINGS, Courtier/Awareness TN 20, 10 koku Pattern B):
  Provincial Daimyo+ only; can_be_inducted() gate (rank, disposition≥51, deeds≥8,
  extraordinary≥1, FD approval set, different clan, no TREASON/MAHO/COVERT_KILLING crimes);
  ceremony failure→TIER_4 PERSONAL topic (FD approval not revoked).
  Extraordinary deed detection in `_is_extraordinary_contract_deed()` at expiry time
  checks active_wars, province active_crisis_id, and contract_duration_seasons≥3.
  Induction writeback: perform_induction() mutates clan/family/lord_id/role_position,
  status raised to 1.0 minimum, permanent_ronin cleared, deed credits + extraordinary
  deeds + FD approval erased, +1.0 glory inductee, +0.3 glory sponsor, +15 disposition
  from all co-family members toward inductee, TIER_3 POLITICAL topic distributed.
  FIND_NEW_LORD standing cleared on induction. objective_alignment.json: FILL_VACANCY
  NeedType: PERFORM_CLAN_INDUCTION (20), APPROVE_CLAN_INDUCTION (50), HIRE_RONIN (60).
  Constants A60–A76 locked. ~55 tests.
- **s57.28 Sculpture System** — GDD `gdd/s57.28_sculpture_system_locked.md`. Previously
  implemented but lacking a lock document; now formally locked. One ActionID: COMPOSE_SCULPTURE
  (Category 11, Artisan: Sculpture/Awareness, TN 15, progress = max(1, roll−15) per AP).
  Three formats: STATUARY (shrine/temple statue_slot, passive WP 0.1–1.0/season PROVISIONAL,
  worship FR 0/1/1/2/2 by tier), GUARDIAN (guardian_slot komainu pair, spiritual ward −1 to
  −5 per non-Jigoku overlap tick when pair_intact=true, zero Jigoku effect, guardian worship
  FR 0/0/1/1/2 by tier, outdoor wood degradation −1 tier per 1800 IC days), FIGURINE (inventory
  gift item, any context, Mantis +3 FR on DELIVER_GIFT, collection topic at 3+ matching
  theme/creator). Material modifiers: stone +5 TN, bronze +1 FR + foundry requirement.
  Composition degradation halves progress after 90 IC days without AP (statuary/guardian only;
  figurines exempt). Skill gate: rank ≥ target quality tier. Raises at completion: +1 quality
  tier per Raise. Progress thresholds (statuary 20/40/65/95/130, guardian 25/50/80/110/150,
  figurine 5/10/18/28/40). Worship FR cap = 5 combined PROVISIONAL. Visitor disposition
  bonuses 1–5 by quality toward creator, 120-day window, glory tick every 5 visitors.
  Yoritomo Sculptor school: +1k1 on figurine rolls. Siege/sacking survival: wood 30–70% by
  tier, stone +20%, bronze +30%; zone destruction: wood destroyed, stone 50%, bronze 70%.
  Lifecycle topic tiers: Normal/Fine=TIER_4, Exceptional/Masterwork=TIER_3, Legendary=TIER_2.
  Settlement-level zone proxy (statue_slot, guardian_slot, statue_permissions,
  guardian_permissions on SettlementData) replaces unavailable zone system until s4.4/s56.
  World-state persistence: active_sculptures Array + next_sculpture_id, saved via
  WorldStateSaver DIR_SCULPTURES. 931 tests in `tests/test_sculpture_system.gd`.

### Systems Added 2026-05-31
- **s57.23 Garden System & s57.24 Bonsai System** — `simulation/garden_system.gd` (811 lines),
  `shared/garden_data.gd`, `shared/bonsai_data.gd`, `shared/commission_record_data.gd`.
  Locked spec in `gdd/s57.23a_garden_bonsai_locked.md`. 58 tests in `tests/test_garden_system.gd`.

  **Garden system (s57.23):**
  Seven ActionIDs fully wired into the NPC pipeline: REQUEST_ART (lord requests artisan via
  Courtier/Awareness, no roll), OFFER_ART_COMMISSION (artisan offers via Artisan: Gardening/
  Awareness, no roll), CULTIVATE_GARDEN (Artisan: Gardening + free raise at rank≥3 vs
  QUALITY_TN[tier]; skill gate per QUALITY_SKILL_GATE[tier]; progress bar advances per
  apply_cultivate_progress; on completion creates GardenData, computes COMPLETION_BONUS_BY_RAISES
  disposition effect to daimyo, awards EXCESS_RAISE_GLORY 0.2 per raise, Tier 3/4 topic),
  MAINTAIN_GARDEN (Artisan: Gardening vs QUALITY_TN[garden_tier] + free raise; apply_maintain_result
  prevents auto-degradation for the season; degradation/destruction topics generated),
  COLLECT_BONSAI_SPECIMEN (Artisan: Gardening or Perception vs TN 10; creates BonsaiData),
  TEND_BONSAI (Artisan: Gardening vs TN 10 + free raise; raises improve quality tier via
  BONSAI_QUALITY_THRESHOLDS; excess raise glory 0.05/raise),
  DISPLAY_BONSAI (no roll; sets display_settlement_id on bonsai, updates settlement slot).

  Context injection (`_inject_garden_context()`): per-character world_state keys: `active_commission_id`,
  `commission_quality_tier`, `local_garden_id`, `local_garden_tier`, `owned_bonsai_id`,
  `bonsai_display_eligible`, `garden_zone_available`, `available_garden_zone`,
  `character_province_id`. All keys cleared daily by stale-flag pass.

  Visitor effects (`_process_garden_visitor_effects()`): living non-traveling characters co-located
  with a garden settlement receive disposition temp_modifier via apply_visitor(); GLORY_TICK_THRESHOLD=5
  unique visitors triggers CREATOR_GLORY_PER_TICK=0.1 glory (creator) and DAIMYO_GLORY_PER_TICK=0.01
  (settlement daimyo). Duplicate guard via `active_garden_bonuses` Array on L5RCharacterData
  (entries: `{garden_id, creator_id, expires_ic_day}`). VISITOR_BONUS_DURATION_DAYS=120.
  VISITOR_MEMORY_CAP=200; purge after VISITOR_MEMORY_PURGE_DAYS=1800.

  Seasonal maintenance (`_process_garden_seasonal_maintenance()`): gardens with no maintenance
  this season auto-degrade via apply_seasonal_auto_degradation(); neglect ticks on obligated
  commissions via evaluate_neglect_tick(); abandoned commissions (check_abandonment()) apply
  ABANDONMENT_HONOR_LOSS=0.5, ABANDONMENT_DISPOSITION_LOSS=8 to artisan toward daimyo.

  Settlement-level zone proxy: `garden_slots: Dictionary` and `garden_permissions: Dictionary`
  on SettlementData bypass the unavailable s4.4 zone system. `get_garden_eligible_zones()`
  returns zone type strings by settlement type (CITY/CASTLE get more zones). `is_zone_committed()`
  and `grant_permission()` manage slot exclusivity.

  Phase 4c precondition filter (`_apply_garden_precondition_filter()`): removes CULTIVATE_GARDEN
  when no active commission or rank<1, MAINTAIN_GARDEN when no local garden or rank<1, OFFER_ART_COMMISSION
  when no available zone, TEND_BONSAI/DISPLAY_BONSAI when no owned bonsai, DISPLAY_BONSAI when
  settlement ineligible, COLLECT_BONSAI_SPECIMEN when rank<1.

  **Bonsai system (s57.24):**
  Monthly neglect (`_process_bonsai_monthly_neglect()`): fires at `ic_day / 30` boundary;
  calls `GardenSystem.apply_tend_result(bonsai, false, 0, ic_month)` for bonsai whose
  `last_tended_month != ic_month`. Internally increments `consecutive_missed_months`,
  applies tier degradation, marks dead at cap. CULTURAL_INTEREST_THRESHOLD=2 months.
  ARTISAN_SCHOOL_CULTURAL_INTEREST=10. BONSAI_MUNDANE=0 tier floor.

  Context lists: CULTIVATE_GARDEN, MAINTAIN_GARDEN, COLLECT_BONSAI_SPECIMEN, TEND_BONSAI,
  DISPLAY_BONSAI, OFFER_ART_COMMISSION in AT_OWN_HOLDINGS; OFFER_ART_COMMISSION, TEND_BONSAI,
  DISPLAY_BONSAI in AT_COURT; CULTIVATE_GARDEN, TEND_BONSAI, DISPLAY_BONSAI in VISITING.
  AP cost 1 for all 7 ActionIDs. action_skill_map.json and objective_alignment.json updated:
  ARTISTIC_EXPRESSION (CULTIVATE_GARDEN:100, TEND_BONSAI:95, MAINTAIN_GARDEN:90, OFFER_ART_COMMISSION:80,
  DISPLAY_BONSAI:70, COLLECT_BONSAI_SPECIMEN:60), PATRONIZE_ARTS (REQUEST_ART:85,
  CULTIVATE_GARDEN:70, MAINTAIN_GARDEN:60, DISPLAY_BONSAI:50), SEEK_GLORY (CULTIVATE_GARDEN:70,
  DISPLAY_BONSAI:60, OFFER_ART_COMMISSION:60, REQUEST_ART:55, TEND_BONSAI:40,
  COLLECT_BONSAI_SPECIMEN:30).

  **WorldState persistence:** `active_gardens: Array[GardenData]`, `next_garden_id: Array[int]`,
  `active_bonsai: Array[BonsaiData]`, `next_bonsai_id: Array[int]`, `commission_records:
  Array[CommissionRecordData]`, `next_commission_id: Array[int]` on WorldState. Saved/loaded
  via WorldStateSaver Resource array pattern (DIR_GARDENS, DIR_BONSAI, DIR_COMMISSIONS).

  **SettlementData additions:** `garden_slots: Dictionary`, `garden_permissions: Dictionary`,
  `bonsai_display_slot: int = -1`. **L5RCharacterData additions:** `declined_garden_zones: Array`,
  `declined_commissions: Array`, `active_garden_bonuses: Array`.

### Systems Added (pre-2026-06-02, previously undocumented)
- **s57.26 Origami System** — `simulation/origami_system.gd`, `shared/senbazuru_data.gd`. Three ActionIDs: CRAFT (noshi/gohei/senbazuru_progress dispatch), DECLARE_SENBAZURU (0 AP, one-active gate), PRESENT_SENBAZURU (1 AP, completion gate). Noshi wrapper disposition bonus, gohei uses_remaining, senbazuru crane accumulation with completion topic (TIER_3 Exceptional+, TIER_4 Fine/Normal). Presentation effects by dedication type (Healing/Protection/Remembrance/Atonement). Lifecycle events on creator/recipient death. Noshi consumed on DELIVER_GIFT; gohei decremented on PERFORM_WORSHIP. Context injection and precondition filter. Locked in GDD s57.26_origami_system_locked.md. **s57.26b Shide proxy** — settlement-level shide placement system (CRAFT origami_type="shide", PLACE_SHIDE 0 AP). Seven SettlementData fields. Seasonal degradation. World-start seeding. Locked in gdd/s57.26b_shide_settlement_proxy_locked.md.
- **s57.27 Painting System** — `simulation/painting_system.gd`, `shared/painting_data.gd`. Three ActionIDs: COMPOSE_PAINTING (progress accumulation), DISPLAY_PAINTING (lord/permission gate), PRESENT_EMAKIMONO (polarization disposition per quality, 30-day immunity, topic delivery). Four formats: KAKEMONO, BYŌBU, EMAKIMONO, FUSUMA. Visitor disposition and glory tick effects. Negative framing: enemy visit triggers disposition loss. Seasonal kakemono rotation. Emakimono copy pipeline. Artist grief on forced display. Sacking survival by tier and material. Death cleanup for WIP. Settlement display slot proxy. World-start seeding. Locked in gdd/s57.27_painting_system_locked.md. 37 tests.
- **s57.29 Ikebana System** — `simulation/ikebana_system.gd`, `shared/ikebana_arrangement_data.gd`. Uses PUBLIC_PERFORMANCE and PERFORM_FOR with Artisan: Ikebana skill. One slot per settlement (zone proxy). Lifespan 7–45 IC days by quality tier. Visitor effects and glory ticks. Creator-deceased topic. Garden synergy (s57.29.6): free raises from co-located garden by quality. NPC urgency bonus when slot empty. World bootstrap seeding. 35 tests.
- **s57.30 Calligraphy System** — Cipher and High Rokugani emphases implemented in `simulation/letter_system.gd`. Writer-side: concealment roll (roll total = concealment_tn), disposition tier and topic stance frozen at write time. High Rokugani: bonus by Imperial Capital recipient tier. Reader-side: contested roll with emphasis and Rank 5 mastery bonus; raise tiers expose disposition/stance/intensity/deception/motivation. Locked in gdd/s57.30_calligraphy_system_locked.md. 40 tests.
- **s57.41 Engineering System** — `simulation/day_orchestrator.gd` + `simulation/action_executor.gd`. Two mechanics: (1) Rank 5 mastery +5 flat bonus on FORTIFY_WALL_SECTION cumulative track (excludes SEAL_WALL_BREACH). (2) Kaiu Engineer standing need auto-assignment: MAINTAIN_FORTIFICATION priority 2 at wall_si < 7, priority 1 at si == 0. Locked in gdd/s57.41_engineering_locked.md. 11 tests.
- **s57.45 Geisha Intelligence System** — `simulation/geisha_system.gd`, `shared/okiya_data.gd`. OkiyaData Resource. Two-stage routing: geisha→okaasan then okaasan→handler with personality-gated probability. Kolat eavesdrop parallel roll. Wind-down koku costs tier-dependent. World generation: CITY/FAMILY_CASTLE/CASTLE okiya placement with clan-specific tier bonuses. Scorpion 90% control, Kolat 15% infiltration rate. WorldState persistence via WorldStateSaver. WorldBootstrap generates okiya for all eligible settlements. Locked values in gdd/s57.45a_geisha_intelligence_locked.md. ~20 tests.

### Systems Added 2026-06-02
- **s4.4 Zone Hierarchy and ASCII Map Foundation** — Full zone data model and settlement map
  generation layer. Three zone data classes (`shared/greater_zone_data.gd`,
  `shared/navigation_zone_data.gd`, `shared/lesser_zone_data.gd`) per GDD s4.4.1.
  `simulation/settlement_zone_builder.gd` (SettlementZoneBuilder, 378 lines): factory that
  creates all zone tiers for a settlement by type (CITY/CASTLE/TOWN/VILLAGE etc.) and wires
  the navigation zone graph. `simulation/zone_flag_matrix.gd` (ZoneFlagMatrix, 512 lines):
  implements the full zone flag matrix from GDD s57.36 — 7 flag categories, 32 flag types,
  per-zone allowed-action filtering and action-context mapping. `simulation/zone_registry.gd`
  (ZoneRegistry, 57 lines): world-level index mapping zone_id strings to their data objects;
  wired into WorldState. `shared/ascii_map_data.gd` (AsciiMapData): base tile-grid Resource
  (variable-size, default 31×31 viewport), TileType enum, `init_tiles()`, `set_tile()`,
  `get_tile()`, `fill_rect()`. Dynamic map feature support: doors (OPEN/CLOSED), destruction
  tracking (destroyed_tiles Array), fire (burning_tiles Array). `simulation/fov_system.gd`
  (FovSystem, 168 lines): recursive shadowcasting field-of-vision per s4.4.2. Base radius =
  Perception trait. Environmental modifiers: forest −2, darkness −3, fog/mist −3, rain −2,
  storm −4, snow −2. Lookout position bonus: +3 radius on WALL_STONE or elevated tile.
  Stacks with environmental modifiers (minimum 1 tile). `simulation/ascii_map_generator.gd`
  (AsciiMapGenerator, ~2155 lines): deterministic procedural generation for all ZoneSubtype
  values — the enum and the generator's dispatch are 1:1 (every subtype has a generator).
  As of the s2.3.23 Otosan Uchi landmark pass the set is **35**: 11 castle-interior
  (OHIROMA, ENKAI_HALL, AUDIENCE_CHAMBER, CHASHITSU, GUEST_WING, LORD_QUARTERS,
  WAR_COUNCIL_ROOM, DOJO, OUTER_COURTYARD, TSUBONIWA, CASTLE_SHRINE), 7 urban-district
  (MARKET_STREET, RESIDENTIAL_QUARTER, TEMPLE_GROUNDS, PLEASURE_QUARTER, DOCKS_WATERFRONT,
  POOR_QUARTER, GOVERNMENT_QUARTER), 6 wilderness (ROAD, FOREST_PATH, MOUNTAIN_PASS,
  RIVER_CROSSING, FARMLAND, SHRINE_CLEARING), 1 wall (WALL_TOWER), 1 dwelling
  (PEASANT_DWELLING), and 9 s2.3.23 named-landmark subtypes (UNDERGROUND_LAKE, THRONE_ROOM,
  LABYRINTH, ONI_WARAI, RUINED_STRUCTURE, BARRACKS, LIBRARY, TOMB, TREASURY_VAULT). The
  earlier "25 (… GARDENS/ARMORY/FORGE/GATEHOUSE/WILDERNESS)" list in this entry was a
  pre-reorganization artifact — those names are not in the committed enum. Each generator
  places walls, floors,
  features, and zone exits using a fixed seed (settlement_name + zone_name + zone_type string).
  Same inputs always produce the same layout; only physical deltas (destroyed walls, new
  construction) are persisted between sessions. Zone graph wired into world bootstrap and
  WorldState; zone_id lookup added to per-character world_states context injection.
  38 + 95 tests in `test_zone_data.gd` and `test_zone_flag_matrix.gd`;
  142 + 14 tests in `test_ascii_map.gd` and `test_cave_fov.gd`.
- **s56.3 Cave Template** — `simulation/cave_template_generator.gd` (CaveMapGenerator, 742
  lines) + `shared/cave_map_data.gd` (CaveMapData). Deterministic cellular-automaton cave
  generation: 5 smoothing passes, guaranteed main-chamber flood-fill connectivity, 1–3
  side chambers, blocked side passages become cache sites. Population slots: 3–7 guard posts
  in main chamber, 1 leader position in deepest alcove, 1 objective marker. Darkness penalty
  (−3 vision) wired as metadata; mechanical effects blocked on s40. 46 tests in
  `test_cave_template.gd`.
- **s56.4 Occupied Village Template** — `simulation/occupied_village_template_generator.gd`
  (OccupiedVillageGenerator, 545 lines) + `shared/occupied_village_map_data.gd`. 20×20 grid:
  3×3 building blocks with roads between, river optional (40% chance), well centred in plaza.
  Population slots: 2–5 roving patrol pairs on road tiles, 1–2 chokepoint guards at road
  junctions, leader in largest building, objective in locked storage building. Civilian
  non-combatants flagged separately. 34 tests in `test_occupied_village_template.gd`.
- **s56.5 Forest Approach + Camp Template** — `simulation/forest_approach_camp_generator.gd`
  (ForestApproachCampGenerator, 591 lines) + `shared/forest_approach_camp_map_data.gd`.
  Two-zone layout: dense forest approach corridor (40% of map, stealth +5 TN) leading into
  fortified camp clearing. Camp: log palisade, 2–4 sentry towers with overlapping sight lines,
  campfire in centre (generates Loud noise 12 tiles). Population slots: sentry posts in
  towers, patrol route through forest edge, leader tent, objective crate.
  33 tests in `test_forest_approach_camp_template.gd`.
- **s56.7 Makeshift Stockade Template** — `simulation/makeshift_stockade_generator.gd`
  (MakeshiftStockadeGenerator, 623 lines) + `shared/makeshift_stockade_map_data.gd`.
  25×25 outer perimeter of log walls with 1–2 breachable sections (WALL_WOOD tiles),
  inner keep of WALL_STONE, elevated wall-walk tiles (guard posts with +3 lookout bonus).
  Defense angle metadata: each wall section stores its facing direction for flanking logic
  (blocked on s40). Population slots: perimeter walkers, gate guards, keep interior guards,
  commander in keep. 59 tests in `test_makeshift_stockade_template.gd`.
- **s56.8 Hilltop Position Template** — `simulation/hilltop_position_generator.gd`
  (HilltopPositionGenerator, 578 lines) + `shared/hilltop_position_map_data.gd`.
  Concentric elevation rings: outer FLOOR_STONE (exposed approach), mid FLOOR_WOOD
  (partial cover), summit WALL_STONE cluster. Elevation tier metadata stored per tile;
  summit defenders get +1k0 ranged (blocked on s40). 2–4 approach corridors through
  rocky outcroppings. Population slots: approach observers, ridgeline archers, summit
  defenders, commander flag on highest tile. 38 tests in `test_hilltop_position_template.gd`.
- **s56.11 Ravine Camp Template** — `simulation/ravine_camp_generator.gd`
  (RavineCampGenerator, 623 lines) + `shared/ravine_camp_map_data.gd`. 30×20 ravine:
  vertical cliff walls (WALL_STONE impassable) with 1–2 rope-bridge crossings (FLOOR_WOOD
  tiles flagged as bridges, removable). Rope bridge destruction metadata: bridge_status
  per crossing, collapse TN 20 (blocked on s40). River runs along ravine floor (WATER_SHALLOW,
  passable at Agility TN 15 — metadata only). Population slots: cliff-top archers,
  bridge guards, ravine floor patrol, commander in cave alcove at ravine end.
  70 tests in `test_ravine_camp_template.gd`.
- **s56.12 Ruined Structure Template** — `simulation/ruined_structure_generator.gd`
  (RuinedStructureGenerator, 730 lines) + `shared/ruined_structure_map_data.gd`. Partially
  collapsed building: original floor plan generated, then 25–45% of interior walls randomly
  destroyed (added to destroyed_tiles). Rubble tiles (WALL_RUBBLE) block movement, grant
  cover (+5 Armor TN — metadata). Roof collapse zones: areas under partial ceiling get
  fall-debris hazard tag (blocked on s40). 3–5 rooms remain intact as defensible positions.
  Population slots: rubble-covered approach snipers, intact-room garrison, leader in deepest
  intact room, objective in collapse-sealed basement.
  70 tests in `test_ruined_structure_template.gd`.
- **s56.13 Relocation Mechanics** — `simulation/insurgency_relocation_system.gd`
  (InsurgencyRelocationSystem). Pure simulation layer (no map tiles). Five mission outcome
  types (FULL_SUCCESS, PARTIAL_SUCCESS, RETREAT_INSIDE, RETREAT_OUTSIDE, FAILURE).
  Three triggers for relocation: FULL_SUCCESS always triggers if survivors remain,
  PARTIAL_SUCCESS/RETREAT_INSIDE trigger if player reached objective space, FAILURE/
  RETREAT_OUTSIDE never trigger. Template-specific rules: Makeshift Stockade delays
  same-province relocation 1 season (GDD s56.13.2); Ruined Structure cannot relocate
  (structure-bound). Province adjacency travel time calculation for new camp selection
  (uses ProvinceData adjacency graph, blocked-on-map fallback to 1 season). Insurgency
  strength attrition on relocation: −1 strength per relocation event. Wired into
  InsurgencySystem resolution pipeline. 36 tests in `test_insurgency_relocation_system.gd`.
- **s56.15 Urban Hideout Template** — `simulation/urban_hideout_generator.gd`
  (UrbanHideoutGenerator, 404 lines) + `shared/urban_hideout_map_data.gd`. Two-phase
  structure: surface search phase (street grid, civilian cover, normal settlement zone)
  and underground hideout phase (hidden basement, tunnel network). Surface → underground
  transition via hidden door tile (ZONE_EXIT flagged hidden). Underground: 3–5 rooms
  connected by narrow tunnels (1-tile wide, chokepoint guards). Criminal network presence
  module cross-reference (s11.11 Pirate Fleet / Bloodspeaker cell). Population slots:
  surface lookouts (disguised, spawn as civilian), tunnel guards, underground objective
  room, cell leader in deepest chamber. 41 tests in `test_urban_hideout_template.gd`.
- **s56.17 Castle Siege Template** — `simulation/castle_siege_generator.gd`
  (CastleSiegeGenerator, 681 lines) + `shared/castle_siege_map_data.gd`. 40×30 outer
  bailey + inner keep. Four gate zones (North/East/South/West, one randomly breached by
  siege engines). Wall-walk patrol route on WALL_STONE perimeter. Keep interior: great
  hall, audience chamber, dungeon (objective). Keep gate is secondary chokepoint.
  Siege-damage metadata: outer_wall_breached, keep_gate_damaged, catapult_impact_zones
  (rubble overlay on random bailey sections). Population slots: wall-walk defenders per
  section, gate guards at each approach, keep garrison, target in audience chamber or
  dungeon. 49 tests in `test_castle_siege_template.gd`.
- **s56.2 ASCII Map Template Selector** — `simulation/template_selector.gd`
  (TemplateSelector, 171 lines). GDD-locked probability pools keyed by TerrainType
  (PLAINS/FOREST/MOUNTAINS/HILLS/SWAMP/COASTAL/RIVER_DELTA): weighted selection among
  available templates (OccupiedVillage, MakeshiftStockade, RuinedStructure, RavineCamp,
  ForestApproachCamp, Cave, HilltopPosition). Ruin-eligibility check: province history
  tags `{war_damage, famine, taint_corruption, peasant_revolt, natural_decay}` unlock
  RuinedStructure; weight redistributed to other pools when no ruin condition applies.
  Province-history-aware: Strength 1–3 biases toward smaller templates, Strength 7+
  biases toward defended positions. Deterministic selection from seeded RNG (province_id +
  season string). 20 tests in `test_template_selector.gd`.
- **s56.6 ASCII Map Environment Data Layer** — `simulation/ascii_map_environment.gd`
  (AsciiMapEnvironment, 317 lines). Pure data and lookup layer for outdoor map environment
  mechanics per GDD s56.6.1–56.6.4. BiomeType enum (7 values). WeatherState enum (8 values
  including biome-specific Snow/Blizzard/Mist). WEATHER_DATA dictionary: per-state TN modifiers
  for ranged attacks, vision range, stealth, movement multiplier, wound exposure rate, and
  coastal-only flag. All effect values stored as metadata; runtime application blocked on
  s40/s4.4. NOISE_LEVEL enum (QUIET/MODERATE/LOUD/VERY_LOUD) with tile-radius constants
  (3/6/12/20). AlertState enum (UNAWARE/SUSPICIOUS/ALERT/COMBAT) with transition rules:
  Unaware→Suspicious on Moderate noise in radius, Suspicious→Alert on investigation failure
  or Loud noise, Alert→Combat on direct sighting. KANSEN_DENSITY enum (5 levels) with
  threshold table keyed by PTL ranges. Static helpers: `biome_for_terrain(terrain_type)`,
  `density_from_ptl(ptl)`, `get_weather_data(weather)`, `is_coastal_only(weather)`,
  `apply_biome_weather_conversion(base_weather, biome, season)` (Rain→Snow in NORTHERN_HIGHLAND/
  CENTRAL_PLAINS/WESTERN_STEPPE in winter; Storm→Blizzard in NORTHERN_HIGHLAND in winter),
  `weather_to_fov_modifier(weather)` (returns WEATHER_DATA vision_mod for FovSystem).
  Fire propagation (s56.6.6) NOT implemented — labeled PROVISIONAL in GDD, not LOCKED.
  84 tests in `test_ascii_map_environment.gd`.
- **s56.18 Ship Boarding Template** — `simulation/ship_boarding_generator.gd`
  (ShipBoardingGenerator, 134 lines) + `shared/ship_boarding_map_data.gd`. 15×10 tile map:
  player ship rows 0–3, water gap rows 4–5, enemy ship rows 6–9. Three ship types
  (SMALL_KOBUNE=1 plank, MEDIUM_ATAKEBUNE=2 planks, LARGE_KOBUNE=3 planks) each with
  GDD-specified plank column positions. Two boarding modes: OFFENSIVE (player enters from
  row 3, objective is enemy quarterdeck tile at row 6) and DEFENSIVE (player spawns on
  own quarterdeck, objective is protecting it). Player quarterdeck: cols 0–2, rows 1–2
  (elevated FLOOR_STONE marker). Enemy quarterdeck: cols 12–14, rows 7–8. Water tiles
  (WATER_DEEP) fill the gap; plank tiles (FLOOR_WOOD) bridge it. Quarterdeck elevation
  and water-hazard mechanical effects (Agility TN 15 to avoid falling in) stored as
  metadata; effects blocked on s40. Zone exits placed at north hull (player entry) and
  south hull (enemy entry point). 32 tests in `test_ship_boarding_template.gd`.
- **s56.6.3 Noise Propagation System** — `simulation/noise_system.gd` (NoiseSystem).
  Modified Dijkstra BFS on the ASCII tile grid per GDD s56.6.3 (LOCKED). Five noise
  levels (SILENT/QUIET/MODERATE/LOUD/VERY_LOUD) with tile-radius budgets (0/3/6/12/9999
  from AsciiMapEnvironment.NOISE_RADIUS). SILENT returns empty immediately. Walls
  (VOID/WALL_STONE/WALL_WOOD/WALL_PAPER) block propagation entirely; wall tiles are
  excluded from the reachable set. Corridor axis detection: EW corridor = walls at
  N+S perpendicular to the current tile; NS corridor = walls at E+W; out-of-bounds
  map edges count as walls (map.get_tile() returns WALL_STONE for OOB). Corridor bonus
  (CORRIDOR_COST_MULT = 2/3): noise travels 50% farther along corridor axis. Vegetation
  tiles (TREE_*, BAMBOO, BUSH, CROPS, GROUNDCOVER, FLOWERS) and water tiles
  (WATER_SHALLOW/DEEP/RAPID/PADDY) dampen noise (DAMPING_COST_MULT = 4/3, −25% reach).
  These tile types dampen but do NOT block — distinct from FovSystem blocking behavior.
  Ravine echo: effective noise level bumped +1 (capped at VERY_LOUD) when `is_ravine=true`.
  Rain weather (RAIN/STORM/TYPHOON): budget × RAIN_BUDGET_MULT (0.75) applied before BFS.
  Source tile excluded from reachable set (enemies at source are adjacent to actor).
  O(V²) priority-queue extraction — sufficient for 31×31 maps. 38 tests in
  `tests/test_noise_system.gd`.
- **s56.6.4 Kansen Hazard Grid System** — `simulation/kansen_system.gd` (KansenSystem).
  Per-tile kansen density grid per GDD s56.6.4 (LOCKED). Density stored as PackedByteArray
  (one byte per tile, AsciiMapEnvironment.KansenDensity values: NONE=0/LOW=1/MODERATE=2/HIGH=3).
  `generate_density_grid()`: for non-maho quest seeds → flat density from PTL via
  AsciiMapEnvironment.density_from_ptl(). For maho quest seeds with objectives (MAHO_CULT,
  PROVINCE_TAINT_MANIFESTATION, ONI_MANIFESTATION, HUNT_THE_DEFECTOR, GAKI_DO_MANIFESTATION,
  TOSHIGOKU_BLEED) → spatial overlay using Chebyshev distance: HIGH within 2 tiles of any
  objective, MODERATE within 5 tiles, LOW within 10 tiles, outer area = max(NONE, base−1).
  `density_at()`: safe accessor returning NONE for out-of-bounds coordinates.
  `apply_jade_suppression()`: reduces density by one tier within
  AsciiMapEnvironment.JADE_SUPPRESSION_RADIUS=3 tiles (Chebyshev square) of center; returns
  new PackedByteArray (immutable — never mutates input). `apply_banishment()`: reduces density
  by one tier on target tile and 4 cardinal neighbors; out-of-bounds neighbors silently skipped;
  returns new PackedByteArray (immutable). Both reduction functions floor at NONE (no underflow).
  Progressive clearing: HIGH→MODERATE→LOW→NONE with successive applications. 30 tests in
  `tests/test_kansen_system.gd`.
- **s56.1 Quest Seed Selector** — `simulation/quest_seed_selector.gd` (QuestSeedSelector).
  Seed type routing per GDD s56.1: maps InsurgencyData to seed_dict with `seed_type`,
  `strength`, `options`, `roster_ready`, `source_insurgency_id`. Seed types: RONIN_BANDIT,
  MAHO_CULT, PEASANT_REVOLT, TAINT_MANIFESTATION, NEZUMI_INFESTATION, URBAN_CRIMINAL_NETWORK,
  WALL_SORTIE, ONI_MANIFESTATION, ROAD_ENCOUNTER. `roster_ready` gate: SEED_ONI_MANIFESTATION
  returns `roster_ready: false` (s54 Named Oni stat blocks not yet in Reference sections).
  Deterministic seed string format: `province_id + "_" + season + "_" + seed_type`. 41 tests
  in `test_quest_seed_selector.gd`.
- **s56.10 Roster Composition System** — `simulation/roster_composition_system.gd`
  (RosterCompositionSystem, 760 lines). Pure data layer per GDD s56.10: returns unit type
  specs and role assignments for ASCII map population. Seed types: RONIN_BANDIT (stability-
  driven Restless/Volatile/Broken headcount tiers: 3–4/4–5/5–6 per Strength point; role
  assignment: ronin hold critical positions, Thugs secondary, Rabble expendable), PEASANT_REVOLT
  (5–6 per strength), NEZUMI_INFESTATION (4–5, chieftain + warriors + archers + scouts +
  broodmother), MAHO_CULT (3–5, initiate + cultist + adept + zombie tiers), TAINT_MANIFESTATION
  (PTL-driven: Touched/Corrupted/Blighted tiers 3–5/4–6/5–8), URBAN_CRIMINAL_NETWORK (strength-
  tier 1–4: 3–6/8–12/14–20/20–30 total), WALL_SORTIE (Crab friendly: Hida/Hiruma/Kuni vs
  Shadowlands enemy: Bakemono/Ogre/Maho-Tsukai/Skeleton/Oni Spawn by strength tier).
  Individual variance per s56.10.0a: 30–40% chance, +1 to one Trait or Skill; capped at next
  tier equivalent; skill selection constrained to unit-appropriate skills.
  38 tests in `test_roster_composition_system.gd`.
- **s56 Mission Template Resolver** — `simulation/mission_template_resolver.gd`
  (MissionTemplateResolver). Structural wiring layer: QuestSeedSelector → TemplateSelector →
  template generator → AsciiMapData. `select_and_generate()` calls TemplateSelector to choose
  template ID from province terrain + history, then dispatches to the appropriate generator.
  `dispatch()` allows direct template selection by ID (for re-rolling or seed-type restriction).
  Fallback: unknown template_id → Cave (safe generic layout). 27 tests in
  `test_mission_template_resolver.gd`.
- **s56.10 Mission Populator** — `simulation/mission_populator.gd` (MissionPopulator).
  Spatial distribution of roster groups across map population_slots per s56.10. `populate(map,
  roster, seed) -> Array` for all standard templates: priority-ordered role assignment
  (LEADER first, then chokepoint/guard/edge/sentry/patrol/camp slots) with role-compatible unit
  type selection from roster. `populate_sortie(map, roster, seed) -> Dictionary` returns
  `{friendly: Array, enemy: Array}` for SEED_WALL_SORTIE missions. Unit placement entries include
  tile coordinates from population_slot positions, unit_type, role, and individual variance flags.
  Deterministic from seed. 33 tests in `test_mission_populator.gd`.
- **s56.9 Mission Builder + s56.6 Weather/FoV Integration** — `simulation/mission_builder.gd`
  (MissionBuilder, 101 lines). Top-level mission assembly orchestrator: wires QuestSeedSelector
  → RosterCompositionSystem → MissionTemplateResolver → MissionPopulator into a single
  `assemble(province, province_history, seed_dict, seed_str) -> Dictionary` call. `roster_ready`
  gate returns `{}` for blocked seeds. Urban Criminal Network routes directly to
  UrbanHideoutGenerator (absent from every TemplateSelector terrain pool). Wall Sortie routes to
  `populate_sortie()`. Return dict keys: `map` (AsciiMapData subclass), `placements` (Array or
  `{friendly, enemy}` dict), `objective_slots` (from map.objective_slots), `seed_dict` (passthrough),
  `roster` (Dictionary), `environment` (biome, weather, fov_modifier, weather_data). Weather
  integration (s56.6): `biome_for_province()` reads province.biome if set, falls back to
  `AsciiMapEnvironment.biome_for_terrain()`. `seed_dict["weather"]` (default CLEAR) passed through
  `apply_biome_weather_conversion()` (Rain→Snow/Storm→Blizzard for cold biomes in winter) before
  `weather_to_fov_modifier()` → `fov_modifier` int for FovSystem. 37 tests in
  `test_mission_builder.gd`.
- **s4.4/s4.5 MovementSystem + AsciiMapView Input** — `simulation/movement_system.gd`
  (MovementSystem, pure simulation class, no Node inheritance). `terrain_cost()`: impassable
  tiles return 0 (VOID, all walls, WATER_DEEP, all trees, BAMBOO, GATE_CLOSED, closed doors),
  difficult terrain returns 2 (WATER_SHALLOW, WATER_PADDY, WATER_RAPID, CROPS, RUBBLE), all
  other passable tiles return 1. `is_passable()`, `is_closed_door()`, `open_door()`,
  `close_door()` for door state toggling. `budget(water_ring, action)` per GDD s4.5:
  FREE=WR, SIMPLE=WR×2, FULL_MOVE=WR×4; water_ring clamped to [1, 10].
  `check_step(map, from_x, from_y, to_x, to_y) -> Dictionary`: returns
  `{ok, cost, is_door, is_exit}` for single-step validation including bounds checking.
  `scripts/ui/ascii_map_view.gd` updated: signals (moved, zone_exit_reached, door_toggled,
  waited), `water_ring` parameter on `set_map()`, `_look_mode` state (L key toggles,
  Esc exits), `_unhandled_input()` handling numpad 1-9 / WASD+QEZC 8-directional movement
  and numpad 5/period wait, `_try_move()` delegating to `MovementSystem.check_step()`,
  `_open_door_at()` for bump-to-open door interaction (player stays, tile flipped, FOV
  recomputed). 40 GUT tests in `tests/test_movement_system.gd`.

### Known Code Issues (found and fixed 2026-06-03, comprehensive audit)
- **`filter_data` personality filter permanently disabled. FIXED.**
  `world_state.gd` wrapped the JSON under `{"personality_filter": <json>}` but
  `npc_decision_engine.gd` reads `filter_data.get("bushido", {})` — top-level key.
  Every virtue block returned `{}` always. Personality filtering (action blocks,
  conditional blocks, lean values) was completely non-functional at runtime for the
  entire project lifetime. Fixed to `filter_data = _load_json(...)` directly,
  exposing `"bushido"` and `"shourido"` as top-level keys.
- **`objectives_map` int keys corrupted to strings after save/reload. FIXED.**
  JSON serializes `{100: {...}}` as `{"100": {...}}`. Load path was a bare dict
  assignment — all `objectives_map.get(character_id, {})` calls returned `{}` after
  any restart. Every NPC fell to REST/DO_NOTHING until the world was regenerated.
  Fixed by iterating the loaded raw dict and casting each key with `int(k)`.
- **`successor_map` same JSON int→string key corruption. FIXED.**
  Same pattern. Pre-restart succession selections became invisible after reload.
  Fixed with `int(k)` conversion on load; values also cast to `int()`.
- **`known_objectives` sub-dict never cleared between days. FIXED.**
  `_clear_stale_context_flags()` erased top-level `ws` keys via a stale_keys list,
  but all urgency data (`standing_need_type`, `lord_assigned`, `active_case`), hunt
  context, theater context, garden/bonsai/ikebana/senbazuru/shide/sculpture/painting
  context are stored inside `ws["known_objectives"]` (a nested sub-dict). The stale
  list only worked on top-level keys — nested keys persisted indefinitely. `lord_assigned`
  stayed `true` after reassignment (Chugi covert modifier wrong); concluded hunts
  remained "active"; art context from yesterday's location persisted today. Fixed by
  adding `ws.get("known_objectives", {}).clear()` in the clearing loop. All nested
  injectors repopulate relevant sub-keys each day. Also removed the ~20 incorrectly-
  leveled keys from `stale_keys` (they were in `known_objectives`, never at top level).
  2 tests.
- **`next_sculpture_id` missing from save/load/reconcile. FIXED.**
  Had zero coverage in `WorldStateSaver` — neither JSON save, nor `_restore_counter`,
  nor `_ensure_counter_above`. After any restart, reset to 1 and collided with
  existing saved sculpture IDs. Added to JSON save blob, `_restore_counter` call,
  and `_reconcile_id_counters`. `next_garden_id`, `next_bonsai_id`,
  `next_commission_id`, `next_okiya_id` were also missing from the JSON save blob
  (had `_ensure_counter_above` fallback but wrong to omit). All 5 now explicit.
- **`GeishaSystem`, `IkebanaSystem`, `OrigamiSystem` — no `handle_character_death()`. FIXED.**
  Dead geisha/okaasan/handler IDs persisted in `OkiyaData.geisha_ids/okaasan_id/
  handler_id`, dead visitor IDs accumulated unboundedly in
  `IkebanaArrangementData.visitors_who_received_bonus`, dead folder IDs remained
  on active `SenbazuruData` objects (should be abandoned). Added `handle_character_death()`
  to all three systems and wired into `_cleanup_dead_character_references()` with
  updated function signature. 7 tests.
- **`_ensure_dirs()` missing 5 art-system directories. FIXED.**
  `DIR_GARDENS`, `DIR_BONSAI`, `DIR_COMMISSIONS`, `DIR_PAINTINGS`, `DIR_SCULPTURES`,
  `DIR_OKIYAS` were not in `_ensure_dirs()`. Directories were lazily created by
  `_save_resource_array()` (not a crash), but inconsistent with all other dirs
  being pre-created. Added all 5 to the pre-creation list.
- **`reactive_event_type` vs `reactive_type` key naming inconsistency. FIXED.**
  `_execute_duel_challenge()` and `_execute_mentor()` in `action_executor.gd`
  returned `"reactive_event_type"` key while all consumers (orchestrator writebacks,
  `npc_wave_resolver`) read `"reactive_type"`. Was latent (writeback functions create
  pending_events independently with correct key), but could cause silent failures if
  any future code reads the key from executor results. Standardized to `"reactive_type"`.

### Systems Added 2026-06-02 (continued)
- **s60 PC Integration** — `simulation/pc_system.gd`. New fields on L5RCharacterData: `is_pc`, `player_id`, `is_logged_in`, `home_settlement_id`, `banked_ap`, `offline_policies`, `bubble_scene_id`, `bubble_anchor_ic_day`. Logged-in: full world presence, NPC engine never runs for PCs. Logged-out: disappear from world, home anchor for letter delivery, AP accrues to `banked_ap` each tick (cap = 4× daily allocation). Offline reactive auto-resolve policies: QUEUE / HONOR / ACCEPT / DECLINE / CONDITIONAL per event type; 5 reactive event types; CONDITIONAL conditions (same_clan, disposition_friend, higher_status, lower_status). Bubble Time: scene_id + anchor_ic_day; AP reserved during scene, NPC participants occupied for scene IC duration. PC exclusions: no NPC decision engine, no standing objective auto-assignment, no strategic review, no daily letter pass. NPCs may target PCs normally; assassination PC crisis event gated on ASSASSINATION_GRACE policy. WorldState additions: `active_bubble_scenes`, `next_bubble_scene_id`. Constants A1–A5 locked (BANKED_AP_CAP_MULTIPLIER=4, OFFLINE_EVENT_QUEUE_CAP=30). Locked in gdd/s60_pc_integration_locked.md.

### Known Code Issues (found and fixed 2026-06-05, bodyguard combat wiring)
- **Bodyguard FIGHT_FIRST path never resolved combat — execution retry always fired. FIXED.**
  `AssassinationSystem.resolve_bodyguard_encounter()` FIGHT_FIRST path returned
  `fight_initiated: true` with initiative roll data but never actually resolved the fight.
  The orchestrator fell through to execution retry regardless of whether the assassin
  won or lost. Assassins were never killed or driven off by a competent bodyguard.
  `_process_assassination_daily_tick()` now calls
  `IndividualCombat.resolve_npc_summary_combat(assassin, guard, dice_engine)` when
  `fight_initiated: true`. If assassin loses (`attacker_dead` or `loser_id == assassin_id`):
  op phase → ABORTED, suspicion raised to CRITICAL_FAILURE, death event created if assassin
  dies. If guard dies: death event created for guard, execution retry proceeds. If both
  survive and assassin wins: execution retry fires. `bodyguard_combat` key added to
  tick_result for downstream use. 3 tests.

### Systems Added 2026-06-05
- **s40 Individual Combat — WeaponData/ArmorData Resources, NPC summary roll, weapon assignment.**
  `shared/weapon_data.gd` (WeaponData Resource: weapon_name, rolled, kept, strength_adds, skill,
  size, melee, trait — typed replacement for Dictionary-based WEAPON_CATALOG entries).
  `shared/armor_data.gd` (ArmorData Resource: armor_name, tn_bonus, is_heavy — catalog empty;
  Equipment section not yet in GDD, `armor_tn_bonus: int` on character retained for fast lookup).
  `shared/character_data.gd`: `weapons: Array[WeaponData]` (was untyped Array),
  `armor_worn: ArmorData = null` (was String).
  `simulation/individual_combat.gd`: three new static functions —
  `get_weapon_data(weapon_name)` converts WEAPON_CATALOG entry to typed WeaponData on demand;
  `pick_best_weapon(character)` selects highest-skill weapon from catalog (unarmed fallback);
  `resolve_npc_summary_combat(attacker, defender, dice, attacker_weapon, defender_weapon)`
  implements the summary roll model (design decision): both NPCs roll attack simultaneously in
  Attack Stance, damage applied via WoundSystem, winner by dead check then roll total tiebreak,
  returns winner_id/loser_id plus full roll details for both sides.
  `simulation/world_generator.gd`: `_assign_weapons(c)` assigns starting weapons at character
  creation — daisho (katana+wakizashi) for Kenjutsu/Iaijutsu, naginata+tanto for Polearms,
  tetsubo+tanto for Heavy Weapons, wakizashi for War Fan, unarmed for Jiujutsu-primary, tanto
  for shugenja, katana+wakizashi fallback for all others; yumi added when Kyujutsu trained.
  14 tests in `tests/test_individual_combat.gd`.

### Systems Added 2026-06-14 (Furniture / furnishings for lived-in interiors)
- **s4.4 Furnishings & Objects (first tranche — residential interiors, owner-authorized
  2026-06-14).** Implements the s4.4 "Remaining Tile Categories: *furnishings and
  objects*" for lived-in spaces (peasant + noble), following the locked rendering
  principles (symbol=type, colour=context, low visual weight). The GDD s4.4 line 121
  anticipates this category but leaves the specific tiles/properties to be "defined
  during engine development"; the owner approved the specific tile set, properties, and
  placement (did NOT authorize editing the /gdd/ s4.4 file — this is an implementation
  record only). **Eight new `TileType` values** (35–42), each with
  movement/LOS/cover properties: FURNITURE_FUTON `▬` (passable), FURNITURE_HEARTH `▦`
  (blocks move), FURNITURE_CHEST `▥` (blocks move + LOS, cover), FURNITURE_TABLE `╥`
  (blocks move, cover), FURNITURE_JAR `◍` (blocks move, cover), FURNITURE_SCREEN `║`
  (byōbu — passable, blocks LOS), FURNITURE_BRAZIER `†` (blocks move), FURNITURE_CUSHION
  `▫` (passable). **Wiring:** `MovementSystem.terrain_cost` + `AsciiMapData.is_passable`
  (blocking furniture impassable — pathfinding routes around it); `AsciiMapData.blocks_los`
  (chest + screen block sight for FOV/stealth); new `AsciiMapData.grants_cover()` +
  `AsciiMapCombatOrchestrator._cover_bonus()` wired into melee AND ranged resolution —
  a defender shielded by a cover-granting furnishing on the tile toward the attacker
  gains `COVER_ARMOR_TN_BONUS = +5` Armor TN (reuses the s40 ruined-structure cover
  value); `AsciiMapGenerator.get_glyph`/`get_fg_color` tables for the renderer.
  **Content:** new `ZoneSubtype.PEASANT_DWELLING` (43) + `_gen_peasant_dwelling` — a
  single-room minka with an earthen doma entry, central irori hearth + flanking
  cushions, sleeping mats, a tansu, a water jar, and a low table; `_gen_lord_quarters`
  furnished (writing table + cushions, byōbu screen, brazier, tansu in the main
  chamber; desk + chest in the study; futons + chest + brazier in the sleeping
  chamber). Verified: all 8 tiles match the approved passable/LOS/cover table; peasant
  dwelling (898/898) and furnished lord quarters (679/679) render correctly and stay
  fully connected (furniture never seals a room); all 26 zones pass the exit-reachability
  regression. LIMITATIONS / DEFERRED: "hazard" furniture (hearth/brazier) blocks
  movement but has no burn-damage mechanic (no hazard system; not invented). Cover is a
  simple one-tile-toward-attacker check (no multi-tile line-of-cover math). PEASANT_DWELLING
  is generatable + renderable but not yet wired into `SettlementZoneBuilder` (villages
  don't auto-spawn peasant homes yet — separate integration). Other furnishable interiors
  (OHIROMA, CHASHITSU, AUDIENCE_CHAMBER, GUEST_WING) not yet furnished. The s4.4 GDD file
  was left unedited (design-file edits need separate owner approval).
- **s4.4 Furnishings tranche 2 (public / worship / commerce / martial spaces,
  owner-authorized all four areas 2026-06-14).** 16 new object `TileType` values
  (43–58) — DAIS `⊓`, BANNER `╤` (passable decorative), WEAPON_STAND `Ψ`, ALTAR `⊥`,
  OFFERING_BOX `▣`, INCENSE `§`, STATUE `☗` (blocks move+LOS), PRAYER_MAT `▭`
  (passable), STALL `╦`, CRATE `▧`, NET `╳` (passable, blocks LOS), WELL `◉`,
  DUMMY `‡` (makiwara), SHELF `▤` (blocks move+LOS), STOVE `◫` (kamado), BENCH `╨`
  (passable). All wired into `MovementSystem.terrain_cost`, `AsciiMapData.is_passable`/
  `blocks_los`/`grants_cover`, and the renderer glyph/colour tables (statue/net/shelf
  block LOS; DAIS/WEAPON_STAND/ALTAR/OFFERING_BOX/STATUE/STALL/CRATE/WELL/DUMMY/SHELF
  grant the +5 cover bonus). **Furnished generators:** ōhiroma (dais + weapon stands +
  banners + braziers + petitioner cushions), enkai_hall (per-pad banquet tables +
  cushions), audience_chamber (host seat/table/screen/weapon stand), war_council
  (real strategy TABLE replacing the stone-floor fake; wall racks → WEAPON_STAND),
  guest_wing (futon + chest per room), temple_grounds + castle_shrine + shrine_clearing
  (altar, offering box, incense, komainu/Fortune statues, prayer mats), market_street
  (vendor STALL + CRATE replacing the wood-wall fakes — the existing passage-clearing
  pass still keeps every road approach open), docks_waterfront (quay crates/barrels +
  drying nets), dojo (real weapon racks + training dummies), chashitsu (ro hearth +
  mizuya shelf), pleasure_quarter (entertaining tables/cushions/screens/braziers per
  house), government_quarter (magistrate DAIS + yoriki weapon stands + petitioner
  cushions + accused's kneeling mat + archive shelves + document chests),
  peasant_dwelling (kamado STOVE). Verified: generator parses clean; every furnished
  zone renders correctly and stays fully connected across 3 seeds (the only
  regression-flag is MOUNTAIN_PASS — an **untouched** generator with a pre-existing
  seed-specific stranded-tile/exit quirk, out of scope here). DEFERRED: BANNER/BENCH/
  WELL are wired but lightly used (no generator places a WELL yet); zone-flag-matrix
  entries for PEASANT_DWELLING and the furnished zones still use the ALL_FALSE default;
  no hazard mechanic for stove/incense/brazier. The s4.4 GDD file remains unedited.
- **s4.4 Furnishings tranche 3 (garrison / yard / homes / contemplation garden,
  owner-authorized 2026-06-14).** Reuses the tranche-2 object tiles (no new tiles),
  furnishing five more generators: **wall_tower** (inner-wall weapon racks were
  wood-wall segments → WEAPON_STAND; garrison futons, supply crates, braziers inside
  the connected tower ring), **outer_courtyard** (first WELL placement as a yard well,
  east-side muster weapon racks, supply crates, clan banners — clear of the N–S gate
  line), **residential_quarter** (each commoner home gets an irori hearth + sleeping
  mat + water jar in the corners, clear of the door column), **poor_quarter** (each
  shack gets a corner hearth + water jar), **tsuboniwa** (tsukubai stone basin via WELL,
  a stone lantern, two veranda meditation benches placed after the veranda floor is laid
  so they survive the overwrite). Verified: parses clean; all five render correctly and
  stay fully connected across 3 seeds (wall_tower's iso=4 is the pre-existing corner
  battlement crenellations on the outer wall, not the furnished interior). The WELL tile
  now has a producer (courtyard + tsuboniwa). The s4.4 GDD file remains unedited.
- **s4.4/s57.36.2 Castle service rooms (manor-completeness audit + build, 2026-06-14).**
  Audited the manor/castle room set against GDD s57.36. Verdict: the **11 Castle
  Interior Lesser Zone subtypes** (s57.36.3 — OHIROMA, ENKAI_HALL, AUDIENCE_CHAMBER,
  CHASHITSU, GUEST_WING, LORD_QUARTERS, WAR_COUNCIL_ROOM, DOJO, OUTER_COURTYARD,
  TSUBONIWA, CASTLE_SHRINE) are **all implemented and furnished** — nothing missing at
  the room/zone level; the rank-scaling tiers (s57.36.2) draw only from these. GDD
  s57.36.2 line 49 is explicit that the **functional spaces (BARRACKS, ARMORY, KITCHEN,
  STOREROOM, PRISON, STABLES) are NOT separate Lesser Zones** — they are tile-clusters
  within whichever zone they occupy. The courtyard previously had none, so added them:
  new `_service_room()` helper draws a small walled room with one yard-facing door, and
  `_gen_outer_courtyard` now lines the compound with six rooms (kitchen=kamado stoves +
  shelf + jar; armoury=weapon racks + shelf + crates; storehouse/kura=crates + shelving;
  stables=troughs + feed; barracks=futons + chest + weapon stand + brazier; holding
  cell=straw mat + chest) around an open central muster lane (cols 12–18, incl. the N–S
  gate column) with a well + banners. GDD does NOT model a bath (furo) or genkan as
  either a zone or a cluster, so those are out of scope, not gaps. Verified iso=0 and
  both gates reachable across 3 seeds (fixed two build-time seals: a trough on the
  stables door tile, and feed crates boxing the far corners). The s4.4/s57.36 GDD files
  remain unedited.
- **s4.4 Genkan + Furo (manor completeness, owner-authorized 2026-06-14).** The audit
  noted the GDD models neither a bath (furo) nor a formal entrance (genkan) as a zone or
  cluster; the owner directed adding both as ASCII clusters (same latitude as the prior
  furniture tranches — NOT a GDD edit). **Genkan** (lord_quarters west entrance): a
  lowered stone doma just inside the door where footwear is removed, a getabako (footwear
  shelf), and a bench — the raised wood corridor begins beyond it. **Furo** (guest_wing):
  the south-east guest room is now a communal bath house — wood floor, a sunken soaking
  tub (WATER_SHALLOW), a washing bench + rinse jar, and a kama (STOVE) heating the bath
  water; the other five rooms remain bedrooms. Verified: both zones iso=0 with reachable
  exits across 3 seeds; full all-zone regression = 0 unreachable exits. s4.4/s57.36 GDD
  files remain unedited.
- **s4.4 Ōhiroma genkan + dojo kamiza (manor polish, owner-authorized 2026-06-14).**
  Follow-up audit found the genkan was only at the private lord's quarters; the grandest
  formal genkan belongs at the ŌHIROMA (great hall — the castle's ceremonial public
  entrance). Added a lowered stone doma vestibule inside the great hall's south doors,
  framed by getabako shelves + waiting benches. Also furnished the DOJO's kamiza (it
  existed as a bare stone alcove): a kamidana (ALTAR) flanked by INCENSE with a PRAYER_MAT
  before it. Verified: both zones iso=0 with reachable exits across 3 seeds; full all-zone
  regression = 0 unreachable exits. With this the manor interior set is complete and
  furnished — the audit's only two genuine gaps are closed. Remaining furniture-bare zones
  (road, forest_path, farmland, river_crossing, mountain_pass) are outdoor wilderness and
  correctly bare. s4.4/s57.36 GDD files remain unedited.
- **s4.4 PEASANT_DWELLING wired into the village zone builder (2026-06-14).** The
  PEASANT_DWELLING minka generator existed but `SettlementZoneBuilder` never placed it —
  villages spawned only Farmland + Shrine Clearing (no homes). The village civilian pool
  now includes enterable peasant-home Lesser Zones: a village's fill is Farmland →
  Peasant Dwelling ×`VILLAGE_PEASANT_HOMES` (=2, a structural representation count — village
  population_pu is a small abstract number, so no meaningful scaling; documented non-GDD
  like the other pool sizes) → Shrine Clearing (+ Docks if coastal), each home a unique
  zone_id chained by exits. `_urban_name()` names PEASANT_DWELLING ("Peasant Dwelling")
  instead of the "Zone" fallback. Live at world gen (`SettlementZoneBuilder.build` runs per
  settlement in `world_bootstrap.gd:917`). Verified: parses clean; headman village builds
  the Ohiroma+Outer Courtyard compound plus Farmland/Dwelling/Dwelling/Shrine fill with
  intact exit wiring + unique ids; coastal appends Docks; the minka generator still renders
  iso=0. Castle-seat villages (CITY_DAIMYO+ over tiny pu) trim to Farmland only (no peasant
  homes in a castle seat — correct); military/religious settlements unaffected.
  **PEASANT_DWELLING now has an explicit ZoneFlagMatrix entry (2026-06-14):** all-false,
  closing the last "no entry" gap (verified: 0 of 26 subtypes missing). Behavior-neutral —
  `get_flags()` already returned ALL_FALSE and `_is_zone_blocked` treats explicit-all-false
  identically to the default. All-false is the *correct* set: every one of the 8 flags is a
  noble art / tea / garden / bonsai / worship affordance a humble minka lacks (the village
  shrine is the separate SHRINE_CLEARING zone), identical to RESIDENTIAL_QUARTER /
  POOR_QUARTER. Homes remain enterable/navigable — movement, FOV, conversation and combat
  are tile-level, never matrix-gated.

### Known Code Issues (found and fixed 2026-06-14, AT_DOJO context blanket)
- **AT_DOJO blanket-pinned everyone at champion castles, stripping governance. FIXED.**
  `_set_dojo_context_flags` set `context_flag = AT_DOJO` for every non-traveling character
  at a `has_dojo` settlement. But `has_dojo` settlements are the 9 Great Clan champion
  family castles + the Imperial Capital — all multi-zone CASTLES, not single-purpose dojos.
  The AT_DOJO action list has only training/social actions (TRAIN, MENTOR, DRILL_TROOPS,
  CHARM, PROBE, TREAT_WOUND) — no governance, court, or worship. So a clan champion governing
  from their own seat (whenever not mid-court) was pinned to AT_DOJO and lost ALL lord actions
  (SET_TAX_RATE, ASSIGN_VASSAL_OBJECTIVE, CALL_COURT, military orders, etc.); cross-clan
  visitors lost VISITING; and a monk's PERFORM_RITUAL standing dead-ended (a dojo is not
  shrine_eligible). Runtime-confirmed: a courtier champion at a `has_dojo` castle got
  context_flag=8 (AT_DOJO) with SET_TAX_RATE absent. Root cause is the multi-zone category
  error: a dojo is one Lesser Zone of a castle, and AT_OWN_HOLDINGS already permits
  TRAIN/MENTOR/MEDITATE/PERFORM_RITUAL, so the dojo blanket added nothing. Fix (owner-approved):
  removed the settlement-level AT_DOJO assignment (`_set_dojo_context_flags` deleted, call
  removed) — characters at champion castles now fall to AT_OWN_HOLDINGS (residents → full
  lord + training actions) or VISITING (outsiders). AT_TEMPLE / AT_WALL_TOWER unchanged (those
  ARE single-purpose settlements). AT_DOJO context list + decomposer branches kept as
  forward-wiring for future per-character zone tracking. `has_dojo` still drives zone structure
  (champion seats get DOJO + WAR_COUNCIL Lesser Zones). Removed the 8 tests asserting the buggy
  behavior. Runtime-verified: champion → AT_OWN_HOLDINGS (SET_TAX_RATE + TRAIN both present);
  monk at temple → AT_TEMPLE (PERFORM_RITUAL present).

### Systems Added 2026-06-15 (s2.3.23 Otosan Uchi named-landmark zone generators)
Nine bespoke `AsciiMapGenerator` ZoneSubtype generators so the Imperial Capital's
named landmarks render as their own spaces instead of falling back to a generic
district map. New `Enums.ZoneSubtype` values (29–37) + a generator + a
`ZoneFlagMatrix` entry for each: **UNDERGROUND_LAKE** (subterranean cavern + water
body, 1 exit), **THRONE_ROOM** (the Chrysanthemum Throne hall — raised dais,
flanking braziers/banners, petitioner floor), **LABYRINTH** (the Emperor's
Labyrinth — subterranean tunnel maze, 2 exits), **ONI_WARAI** (the Oni's Smile —
earthquake crevice / descending chasm), **RUINED_STRUCTURE** (collapsed/haunted
building, rubble overlay; mirrors the s56 ruined template), **BARRACKS** (soldier
kaisha — futon bays, arms racks, mess + stove), **LIBRARY** (Takeo Library — book
stacks in aisles + reading desks), **TOMB** (funerary chamber — memorial altar +
burial coffers), **TREASURY_VAULT** (Imperial Treasury — locked coffers in guarded
vault bays). Wired in `simulation/otosan_uchi_zone_builder.gd` (the district
landmark table maps each named landmark to its subtype via `{"n": …, "s": _ZS.…}`):
Abandoned waterway houses + Tenari's ruins → RUINED_STRUCTURE; Underground Lake →
UNDERGROUND_LAKE; Kinjiren Tombs + Seppun Hill → TOMB; Takeo Library → LIBRARY;
Imperial Guard kaisha + Lion Embassy + Seppun Guard → BARRACKS; Imperial Treasury →
TREASURY_VAULT; Oni Warai → ONI_WARAI; Imperial Palace Throne Room → THRONE_ROOM.
Each generator places walls/floors/features/exits from the standard FNV-1a seed
(deterministic). **Render-verified 2026-06-15 (Godot 4.6.1 headless driver — the
project's parse-check/driver path; GUT is non-functional headless and off-policy):**
all 9 maps rendered and an 8-directional flood-fill from each declared exit reached
100% of passable tiles — UNREACHABLE=0 for every generator (LIBRARY 657/657, TOMB
803/803, TREASURY_VAULT 794/794, BARRACKS 815/815, RUINED_STRUCTURE 883/883,
ONI_WARAI 235/235, LABYRINTH 451/451 across both exits, UNDERGROUND_LAKE 73/73,
THRONE_ROOM 823/823). No stranded interior tiles; every exit is reachable from the
interior and vice-versa. Commits 98334e4 / 0a777fa / 72c4bd2. No tests per the
no-test-code policy. (These three commits shipped without CLAUDE.md changelog
entries; this entry backfills them and records the render-verify.)

### Map-generation layer — full flood-fill connectivity verification (2026-06-15)
Ran the actual generators under Godot 4.6.1 (headless `-s` drivers — parse/driver
path; GUT is non-functional headless and off-policy) with an 8-directional
flood-fill matching MovementSystem (the game's diagonal movement). **No new bugs
found across the entire map layer.**
- **All 35 `AsciiMapGenerator` ZoneSubtypes connected.** The 9 s2.3.23 landmarks:
  UNREACHABLE=0 (exit-reachability). The 26 base subtypes across 43 seeds (3 named
  + 40 numbered): every passable tile reachable from the exit(s) except ROAD's
  ~15 roadside-grass tiles, which are the documented by-design inaccessible scenery
  inside the dense tree shoulders (same pattern as FOREST_PATH).
- **MOUNTAIN_PASS flag RESOLVED — not a gameplay bug.** The 2026-06-14 audit
  flagged a "seed-specific stranded-tile/exit quirk," but across 43 seeds it is
  UNREACHABLE=0 under 8-directional movement. The prior flag was a 4-connectivity
  artifact in the older largest-connected-component metric; the game uses
  8-directional movement (AsciiMapView numpad/WASD diagonals), so MOUNTAIN_PASS is
  fully navigable. No code change.
- **All 10 s56 mission templates connected.** Per the changelog's own invariant
  (every objective_slot + ground-level entry must lie in the largest connected
  component; population slots may sit on walls for elevated/cover units): all 10
  pass across 3 seeds with closed doors/gates treated as traversable (bump-to-open).
  CAVE's entrance fix confirmed holding. RAVINE_CAMP's LCC is ~69.5% of passable
  tiles — by design: the gameplay area (objectives + mouth entry) is fully
  connected, and the stranded ~30% is the cliff-top rim reachable only by s40
  elevation descent (its `is_rim` entry vectors), exactly as documented.
No production code touched — verification only. Drivers were temporary and removed.

### Otosan Uchi zone GRAPH — wiring verification (2026-06-15)
Audited the inter-zone graph built by `OtosanUchiZoneBuilder.build()` (the layer
above per-zone tile connectivity) at runtime under Godot 4.6.1. **CLEAN — no bugs.**
Built the capital (1 GreaterZone, **16 districts**, **122 landmark Lesser Zones**,
139 unique zone_ids, zero duplicates) and verified:
- **District chain:** 16/16 districts reachable via `exits` from district 0; every
  consecutive pair is bidirectional (N forward / S back). Linear chain by design —
  access-tier gating (Toshisoto→Ekohikei→Forbidden) is enforced by the petition
  flag system, not the graph.
- **Landmark links:** 122/122 clean — each Lesser Zone's `parent_zone_id` resolves
  to a real district, its `"up"` exit targets that parent, and the district's
  `child_zone_ids` contains it (reciprocal containment). Descent is containment-based
  (`parent_zone_id`/`child_zone_ids`), so the landmark's single one-way `"up"` exit
  is correct — not a missing reciprocal exit.
- **No dangling exit targets** across GreaterZone / NavigationZone / LesserZone.
- **ZoneRegistry indexing:** `get_nav_zones_for_settlement`=16,
  `get_all_lesser_zones_for_settlement`=122, `get_lesser_zones_for_nav` joins 16/16
  via `parent_zone_id`.
- **Governor join:** 15/15 governor districts flagged (Forbidden City correctly has
  none), and every district `zone_id` equals the deterministic `district_zone_id(sid, i)`
  the world-population generator joins Governors on — so the roster↔zone link is sound.
No production code touched — verification only. Driver was temporary and removed.

### SettlementZoneBuilder zone GRAPH — wiring verification (2026-06-16)
Audited the zone graph built by `SettlementZoneBuilder.build()` (the non-capital
settlement layer) at runtime under Godot 4.6.1 across a 17-case matrix covering
every builder branch. **CLEAN — no bugs (17/17).** Cases: villages (headman,
no-nav-tier; +coastal), towns (with/without castle nav), cities + major cities
(provincial/family/champion rank; +coastal), all military types (family castle,
castle, keep, wall tower, fortification), all religious types (temple +coastal,
shinden, monastery). Each verified for:
- **ID uniqueness** within the settlement (castle `_lz_castle_N` vs fill `_lz_N`
  vs `_gz` / `_nav_castle` patterns never collide; cross-settlement safe via sid).
- **No dangling exit targets** across GreaterZone / NavigationZone / LesserZone.
- **Containment reciprocity** both directions: every `child_zone_ids` entry
  resolves and points back via `parent_zone_id`, and every nav/lz `parent_zone_id`
  resolves to a container that lists it as a child.
- **Within-tier exit connectivity:** castle Lesser Zones (hub-and-spoke from
  OHIROMA) all reachable; fill Lesser Zones (sequential N/E/S/W chain) all
  reachable. Headman villages/towns (nav tier skipped) wire their 2 interior LZs
  hub-and-spoke directly under the GreaterZone — verified connected.
- **ZoneRegistry indexing:** `get_zone` and `get_all_lesser_zones_for_settlement`
  resolve correctly for every case.
OBSERVATION (not a bug): SettlementZoneBuilder Lesser Zones carry NO `"up"` exit
to their parent, unlike OtosanUchiZoneBuilder's landmarks. Vertical movement is
containment-based (`parent_zone_id`) — which BOTH builders rely on for gz→child
descent (a GreaterZone never has "down" exits to its children in either builder),
so the Otosan Uchi `"up"` exit is the redundant one, not the required mechanism.
The graph is fully navigable; the asymmetry only matters to the future
zone-transition UI (it must offer containment ascent, not a directional exit).
No production code touched — verification only. Driver was temporary and removed.

### Live world Governor↔zone join + world-wide zone-graph sweep (2026-06-16)
Ran the REAL `WorldBootstrap.bootstrap_world()` under Godot 4.6.1 (3816 chars,
151 settlements / GreaterZones, 72 NavigationZones, 1028 LesserZones = 1251 zones,
~4.6s) and audited the cross-system Governor↔zone join plus the full live graph.
**CLEAN — no bugs.**
- **Governor↔zone join (s2.3.23):** all 15/15 Otosan Uchi governor districts have
  `zone_lord_id` → a living `GOVERNOR_OTOSAN_UCHI` whose `governed_zone_id` points
  back (bidirectional), with `lord_id == Emperor`. 15 governor characters, all
  back-linked. The 1 non-governor Otosan district (Forbidden City) correctly stays
  unlinked (`zone_lord_id == -1`). Confirms both halves of the join — population
  pass (`world_population_generator` sets `governed_zone_id` from the deterministic
  `district_zone_id`) and bootstrap back-fill (`_link_otosan_uchi_governors` sets
  `zone_lord_id`) — agree at runtime.
- **World-wide structural sweep** over all 1251 live zones: 0 duplicate zone_ids,
  0 dangling exit targets, 0 containment-reciprocity breaks. Confirms the
  representative-matrix SettlementZoneBuilder audit holds against the actual
  generated world (every real settlement), and the Otosan Uchi handcrafted graph
  is sound in situ.
No production code touched — verification only. Driver was temporary and removed.

### ZoneFlagMatrix coverage + schema audit (2026-06-16)
Runtime audit of `ZoneFlagMatrix.ZONE_FLAGS` (the per-ZoneSubtype action-gating
table, s57.36) under Godot 4.6.1. **CLEAN.** All 35 `ZoneSubtype` enum members
have an explicit `ZONE_FLAGS` entry — nothing silently falls to the `ALL_FALSE`
default via `get_flags`. Every entry's key set matches `ALL_FALSE` exactly (all
8 flags present — no missing key reading `false` as an unintended gate, no typo'd
key that is never read), and there are no non-enum keys. The 9 s2.3.23 landmark
subtypes and PEASANT_DWELLING all have entries (all-false where appropriate —
a tomb/treasury/peasant-home grants no noble-art/tea/garden affordances).
With this, the zone system is verified at every layer: builders (structure),
tile connectivity (35 subtypes + 10 mission templates), zone graphs (capital +
all settlement types), live-world Governor↔zone join (1251 zones), and the
action-gating matrix. No production code touched — verification only. Driver removed.

### WorldStateSaver save/load round-trip — live world (2026-06-16)
Round-tripped the REAL bootstrapped world through `WorldStateSaver` under Godot
4.6.1 (fresh `WorldStateData` instances + a temp `BASE_DIR`, so the real `user://`
save and the scheduler autoload were untouched). **CLEAN — no data loss.**
- **All 10 major collections round-trip with exact counts:** characters 3814,
  provinces 143, settlements 151, clans 22, greater_zones 151, navigation_zones
  72, lesser_zones 1028, military_companies 643, bloodspeaker_cells 31,
  insurgencies 7. Confirms the documented "typed-array `.assign` on load" bug
  class stays fixed for the live world.
- **Field fidelity spot-checks:** the Governor↔zone link survives (`zone_lord_id`
  + the character's `governed_zone_id` back-link + role both round-trip); the
  int-keyed `provinces` dict is preserved (lookup by `int` key 120 succeeded — no
  JSON int-key corruption); settlement and province scalar fields intact.
So the verified zone graph + Governor join also persist correctly across
save/load. No production code touched — verification only. Driver removed.

### Known Code Issues (found and fixed 2026-06-14, ASCII map seed-generation connectivity audit)
Connectivity audit of all 25 `AsciiMapGenerator` ZoneSubtype generators (s4.4)
via headless largest-connected-component analysis + per-exit reachability check
(two/three seeds each, closed doors treated as traversable). Six generators were
producing maps where passable space was sealed off or a zone exit could not be
reached from the interior — a walker entering via that exit would be stranded.
Determinism was already perfect (FNV-1a seed) and unaffected by the fixes.
- **MARKET_STREET (67%→100%). FIXED.** Vendor stalls placed on the road edges
  (rows 12/18) AFTER the shops sealed shop doors AND the inter-shop alley gaps
  whenever a stall landed in front of an open passage. The door-only clear was
  insufficient (it missed the vertical alleys between shops). Now clears the
  stall in front of ANY open tile on rows 11/19 (door or alley) via a new
  `_is_passable_floor()` helper.
- **RESIDENTIAL_QUARTER (73%→100%). FIXED.** Two bugs: (1) bottom-row house
  doors (and the shrine door) opened onto the row-30 perimeter wall, sealing
  those interiors — doors now face the adjacent alley (north face when the
  south face abuts the perimeter); (2) the west/east exits sat at y=MID=15,
  which lands on the middle house row, so each exit tile was walled off from
  the interior — exits moved onto the open inter-plot alley rows (y=10, y=20).
- **POOR_QUARTER. FIXED.** Same MID-on-a-shack-row exit bug as residential;
  exits moved to the open alley row (y=14).
- **DOJO. FIXED.** The south exit at (15,30) was blocked by a weapon rack the
  rack loop (`range(3, S-3, 3)`) placed at (15,29). Threshold tile cleared.
- **TSUBONIWA. FIXED.** The south exit was separated from the veranda by the
  surrounding-wall row (S-2); the engawa only reached S-3. Threshold carved.
- **FOREST_PATH. FIXED.** The north exit was hard-coded at (MID,0) but the
  dirt path meanders via per-row `path_x` drift, so the exit landed in the
  trees on seeds where the path drifted off-centre. The exit now follows the
  path's actual top tile (`path_x` after the loop); the south end is always MID
  (the loop starts there).
- **ROAD — not a bug (left as designed).** Its ~23–40 "isolated" passable
  tiles are roadside grass scattered within the intentional dense tree
  shoulders (cols 0–2 / 28–30, 2/3 trees). The road corridor (cols 5–25) and
  both exits are fully reachable; the trapped grass is inaccessible scenery,
  the same pattern as FOREST_PATH's tree field. No change.
- **Cosmetic note (not fixed — no invented behavior).** RESIDENTIAL_QUARTER and
  DOJO generators call no `rng` for structure, so every instance is identical
  regardless of seed (still deterministic, just seed-invariant). Adding layout
  variation would be new behavior; left for a future authorized pass.

Extended the same audit to the 10 s56 mission template generators (slot-level
invariant: every objective_slot and primary entry must be passable AND in the
main connected component; population slots may be on walls for elevated/cover
units). One real defect found and fixed:
- **CAVE main + secondary entrance sealed off. FIXED.** Both entrances stamped
  a ZONE_EXIT at a fixed map edge (main at height-2, secondary at row 1) with
  no guaranteed connecting passage. The entry room centres near — not always
  on — the bottom edge, so on many seeds rock sealed the only entrance from the
  cave (a player would spawn stranded on the exit tile; the prior "ISO=0" floor
  check missed it because it measured the floor network, not the entry marker
  tile). Both entrances now carve a vertical access tunnel from the room centre
  to the edge exit. Deterministic (no rng added).
- **RAVINE rim entries — not a bug.** Its 6 isolated critical slots are exactly
  the `is_rim` entry vectors on the cliff plateau (cliffs are impassable
  WALL_STONE; rim→floor descent is blocked on s40 elevation). Verified every
  objective_slot and the mouth/back entrances are reachable.
- **OCCUPIED_VILLAGE / FOREST_APPROACH_CAMP population-on-wall — not a bug.**
  Those are sentry-tower / elevated placements (population slots, not objective
  or entry). Castle-siege, hilltop, stockade, ruined-structure, urban-hideout,
  ship-boarding all clean (objectives + entries reachable).

### Known Code Issues (found and fixed 2026-06-06, ASCII map combat sweep)
Post-implementation bug sweeps across the new ASCII map combat layer and the
template generators it depends on. Faithful summary of the fixes that landed:
- **Combat system bugs (multiple rounds).** Stance restriction enforcement, FoV
  lookout-bonus application, dead-character guards in combat resolution, duel
  winner/loser assignment, gate (open/closed door) handling in melee, stealth-combat
  flag transitions, morale break thresholds, Down-state attack Void-bonus application,
  and missing `failed` keys on failed-action effect dicts.
- **`AsciiMapCombatOrchestrator` bug fixes.** Several rounds against the orchestrator
  itself (initiative/turn-order, target selection, noise-event propagation from player
  attack paths, ZONE_EXIT step ordering, door noise origin).
- **Raw int topic tier values.** Painting, sculpture, and insurgency-relocation systems
  assigned raw ints to `TopicData.Tier` enum fields (same bug class as the legal-pipeline
  fixes) — corrected to enum references.
- **Template generator hardening.** Cave room-population loop break-in-match-arm,
  castle siege wall fill, murder-hole guard positions, ruined-structure stairwell,
  shelter bounds inversion, kansen/shrine bound errors, and several zone-test type
  mismatches across the s56 template generators.

### Systems Added 2026-06-06
- **s40 ASCII Map Combat — full tile-based skirmish layer.** Two pure-simulation
  classes tie IndividualCombat mechanics to the AsciiMapData tile grid (no Node
  inheritance). One tile = 5 feet (MovementSystem); melee range = Chebyshev distance
  ≤ 1 (adjacent 8 directions).
  - **`simulation/ascii_map_combat_orchestrator.gd` (AsciiMapCombatOrchestrator, 1815
    lines).** Turn/action-budget skirmish driver for player-present combat. Inner
    classes: `TurnState` (per-character action budget — 1 Complex OR 2 Simple + Free +
    Free Move per turn; stance change costs a Simple; Down-restricted move handling) and
    `MapCombatState` (full state: tile positions, factions, turn order, round counter).
    Setup: `setup_combat()`. Movement: `get_reachable_tiles()`, `find_path()` (A*),
    `get_melee_targets()`, `get_ranged_targets()`, `is_in_melee_range_of_enemy()`.
    Execute actions: `execute_stance_change`, `execute_move`, `execute_melee_attack`,
    `execute_ranged_attack` (RANGED_IN_MELEE_PENALTY −10, GDD-confirmed),
    `execute_extra_attack`, `execute_guard` (Guard maneuver, within-5-feet = 1 tile),
    `execute_grapple_initiate`, `execute_grapple_action`, `execute_stand_up` (Simple
    action from Prone), `execute_void_spend`, `execute_destroy_tile` (shoji cut-through,
    GDD s4.4, 0 Raises), `execute_flee`. Turn management: `begin_turn`,
    `get_current_actor`, `advance_turn`, `advance_round`. Full NPC AI turn:
    `execute_npc_turn` with `_npc_pick_stance`/`_npc_desired_stance` (contextual stance
    by wound level and threat), `_npc_pick_target`, `_npc_move_toward`,
    `_npc_execute_attack`. Down-state attack (`_execute_down_attack`) requires a Void
    Point per GDD s40. All damage routes through `_apply_hit` →
    `IndividualCombat.resolve_damage()` with a Participant (kata/mutation/advantage
    modifiers honored). PROVISIONAL: ranged weapon ranges not specified in GDD s40
    (Equipment section blocked) — any enemy in LOS is a valid ranged target.
    97 tests in `tests/test_ascii_map_combat.gd`.
  - **`simulation/combat_controller.gd` (CombatController) — expanded.** Roguelike /
    Dwarf Fortress Adventure Mode stealth-combat model per s40/s56.6.3/s54.8/s54.9.
    Enemy alert state machine (Unaware/Suspicious/Alert/Fleeing; LOCKED round counts
    SUSPICIOUS_SEARCH=3, SUSPICIOUS_RETURN=3, ALERT_ALARM=5). Noise detection
    (QUIET/MODERATE/LOUD/VERY_LOUD; automatic detection on VERY_LOUD, contested
    Perception+Investigation otherwise). Stealth movement and stealth kills (flat-footed
    ATN = 5 + armor_tn_bonus; Quiet noise on kill, Loud on survival). Bump-to-attack.
    NPC behavior (patrol, three investigate styles, pursue+attack, flee). Caller style
    (BAKEMONO_SHAMAN sounds alarm immediately). Creature wound thresholds (s54.9
    `wounds_dead` override). Swift movement (s54.9). Morale (s54.8: BANDIT_RABBLE 40%,
    REBEL_PEASANT/THUG 60%, REBEL_ASHIGARU 70%, MORALE_UNBREAKABLE for REBEL_LEADER).
    Individual variance (s56.10.0a). 17 LOCKED unit types. 154 tests in
    `tests/test_combat_controller.gd`.
  - **`scripts/ui/combat_hud.gd` (CombatHUD, CanvasLayer overlay).** Player-facing combat
    HUD for AsciiMapView: round number, wound level + penalty (color-coded by WoundLevel),
    movement budget, stealth/normal mode indicator, scrolling combat-event log
    (MAX_LOG_LINES=8). `update_from_cc()`, `push_event()`, `set_mode()`. 7 tests in
    `tests/test_combat_hud.gd`.
- **`shared/role_registry.gd` (RoleRegistry) — centralized role/position definitions.**
  All role string constants, `PositionType` enum, POSITION_NAMES / POSITION_RANK
  lookups, and lord-rank helpers consolidated into one file (previously scattered across
  world_population_generator, day_orchestrator, and others). Behavior-preserving refactor.
- **s44/s45 combat-roll wiring sweep.** AdvantageSystem and MutationSystem modifiers, plus
  wound penalties, were wired into every combat and contested dice-roll site that was
  previously skipping them. Coverage: 8 contested roll functions in individual_combat.gd,
  3 combat roll sites missing both wound + mutation, 4 non-combat roll sites, 12
  non-SkillResolver roll sites, 20 additional roll sites, and 17 mutation-modifier sites.
  Kata damage modifiers fixed: `resolve_damage()` calls were missing the Participant
  argument, silently skipping kata damage bonuses — Participant now threaded through all
  call sites (including the ASCII map orchestrator's `_apply_hit`).
- **Contextual NPC stance selection for wounded combatants.** `_npc_desired_stance()` now
  factors wound level and threat type — wounded NPCs favor Defense/Full Defense, healthy
  aggressors favor Attack, ranged-threatened NPCs adjust accordingly.
- **Real-time ↔ turn-based combat mode + End Combat (GDD s40.x, owner-approved design).**
  Implemented on `CombatController`. A zone is **real-time** during exploration and latches
  into **turn-based** the instant a hostile contact occurs (any living enemy reaches the
  ALERT state). `is_turn_based()` lazily evaluates and latches the engage trigger; the
  ASCII map view exposes a passthrough `is_turn_based()` and the CombatHUD renders a
  REAL-TIME / TURN-BASED indicator. The zone only returns to real-time through a successful
  **End Combat**: `request_end_combat()` is **blocked while any aware hostile remains**
  (`get_active_hostiles()` = alive enemies at Suspicious or Alert; Unaware/Fleeing/dead do
  not block); when the field is clear it opens a consent poll requiring **unanimous consent
  of all present living PCs** (`get_present_pc_ids()`). `register_end_combat_consent(pc_id,
  agree)` tallies votes — a single decline cancels the proposal; unanimous agreement calls
  `try_finalize_end_combat()`, which re-checks for re-engaged hostiles before flipping the
  zone back to real-time. The consent gate is pure decision logic over present PC entity IDs
  — no networking/RPC is scaffolded (out of scope); the actual prompting is the UI/future
  multiplayer layer's job. 12 tests in `tests/test_combat_controller.gd`.
- **Event-driven combat-mode signals + view passthroughs (s40.x follow-up).**
  `CombatController.poll_mode_changed()` reports the real-time↔turn-based transition
  exactly once per change (compares current `is_turn_based()` against a last-reported
  latch, so it is correct regardless of call order — no per-frame polling needed).
  `AsciiMapView` fires two new signals: `combat_mode_changed(turn_based)` (emitted from
  `_run_npc_turns_and_sync()` after each action when the mode flips) and `combat_ended()`.
  View End Combat passthroughs added: `request_end_combat()` and
  `submit_end_combat_consent(pc_id, agree)` (the latter emits `combat_ended` +
  `combat_mode_changed(false)` on a successful end). `is_in_combat()` semantics
  reconciled: it now explicitly means "a combat mission is loaded" (controller attached),
  NOT active combat — `is_turn_based()` is the engagement query. 4 tests
  (`test_combat_controller.gd`, 166→170).
- **Player-facing End Combat input (s40.x follow-up).** `AsciiMapView` binds **X** (in
  turn-based mode) to `_handle_end_combat_input()`: requests End Combat, and on a clear
  field auto-submits the local PC's consent (the player consents by requesting). Feedback
  via `combat_event`: `end_combat_blocked` (with active-hostile count), `end_combat_awaiting`
  (other present PCs still to agree — multi-PC collection out of scope for local play), and
  `end_combat_resolved`. CombatHUD formats all three and shows `X=end` in the controls hint.
  3 HUD format tests (`test_combat_hud.gd`, 7→10).
- **`scripts/ui/combat_screen.gd` (CombatScreen) — mission connective layer.** Previously
  the entire ASCII combat layer was only ever wired together in tests — no production code
  created a `CombatController` or booted a mission, and the view/HUD were in no scene.
  CombatScreen (extends Control) is the missing glue: `start_mission(session, player, dice)`
  creates the controller from a `MissionSession`, binds it to a child `AsciiMapView`
  (`set_map` + `set_combat_controller`), wires a child `CombatHUD`, and connects the view's
  signals. It refreshes the HUD after each action (combat_event/moved/waited/mode change)
  and relays `mission_complete`, `player_died`, `zone_exit_reached`, `combat_mode_changed`,
  and `combat_ended` up to the mission owner. `end_mission()` detaches the controller,
  hides the HUD, and disconnects all relays. The world-map → mission **entry point** (which
  builds the session and calls `start_mission`) remains design-pending (PC mission
  initiation, s56/s60); CombatScreen makes that a one-call hookup. 9 tests in
  `tests/test_combat_screen.gd`.
- **s56.19 Mission Entry Policy (LOCKED, owner-approved).** `simulation/mission_entry_policy.gd`
  (MissionEntryPolicy) classifies each quest-seed type as **AUTO** (the threat comes to the PC
  or erupts where they stand — launches on contact: Road Encounter, Ronin/Bandit, Oni
  Manifestation, Taint Manifestation) or **PLAYER_INITIATED** (a known, located threat the PC
  chooses to assault: Maho Cult, Urban Criminal Network, Nezumi Infestation, Peasant Revolt,
  Wall Sortie). Unknown seeds default to PLAYER_INITIATED (never auto-launch on contact).
  `entry_mode_for()`, `is_auto()`, `is_player_initiated()`. Locked in
  `gdd/s56.19_mission_entry_policy_locked.md`. 4 tests.
- **s56.19 Mission entry mechanism (LOCKED, owner-approved).** PC-only — NPCs never use the
  ASCII map and PCs never run the NPC engine (s60), so this is NOT an NPC ActionID and does
  not touch the NPC pipeline. `simulation/mission_entry_controller.gd` (MissionEntryController):
  AUTO seeds launch **on PC province arrival** (`get_auto_launch_seeds`); PLAYER_INITIATED
  seeds launch via **`ENGAGE_MISSION`, 1 AP** (`engage_mission`, `ENGAGE_MISSION_AP_COST = 1`),
  spent from the PC's banked-AP pool. `PcSystem.can_spend_banked_ap()` / `spend_banked_ap()`
  added (s60.5). `engage_mission` validates PC actor + player-initiated seed + AP, spends 1
  banked AP, returns a launch request the UI consumes. 10 tests
  (`test_mission_entry_controller.gd`).
- **`simulation/mission_launcher.gd` (MissionLauncher) — headless launch bridge.**
  `build_session(seed, province, province_history, seed_str, player)` turns a launch request
  into a ready `MissionSession` via `MissionBuilder.assemble` + `MissionSession.from_builder`
  (Water Ring = min(Strength, Perception); FoV from Perception). Returns null when the roster
  is not ready or the session is invalid. 4 tests. This completes the headless pipeline
  (classify → validate/AP → build session). The ONLY remaining step is UI/session glue
  (unverified without Godot): on PC province arrival, query
  `MissionEntryController.get_auto_launch_seeds()`, call `MissionLauncher.build_session()`,
  then `CombatScreen.start_mission()`; plus a PC-arrival event source and zone-level AUTO
  triggering (deferred, s4.4/s60).
- **`scripts/ui/mission_flow.gd` (MissionFlow) — UI/session glue. ⚠ UNVERIFIED (no Godot
  runtime — written, never executed/scene-tested).** Extends Node, owns a `CombatScreen`.
  `on_pc_arrived(pc, province, province_history, active_seeds, seed_str)` auto-launches the
  first AUTO seed and returns engageable PLAYER_INITIATED seeds; `engage(pc, seed, …)` fires
  ENGAGE_MISSION (spends 1 banked AP) and launches. Builds the session via `MissionLauncher`,
  calls `CombatScreen.start_mission()`, guards one-mission-at-a-time (`is_busy()`), exposes
  `end_mission()` (owner calls it after a mission resolves to free the screen for the next
  launch), relays mission_complete/player_died/mission_blocked. 6 tests (written, not executed).
  This is the integration point the future PC world-map travel system will call. The ONLY
  remaining dependency is that **PC world-map travel / province-arrival event source** (and
  supplying the province's seeds via `QuestSeedSelector.select_province_seeds`) — PC world-map
  navigation doesn't exist yet and the arrival trigger is undesigned (s60). **PC world-map
  travel is ON HOLD per owner (2026-06-06)** — deferred, not built. With it, the combat loop
  is end-to-end.

### Known Code Issues (found and fixed 2026-06-06, combat layer audit)
- **CombatScreen.start_mission crashed if called before _ready. FIXED.**
  `_view`/`_hud` were built only in `_ready()`, but `start_mission()` dereferenced
  them — a caller starting a mission before the node entered the tree hit a null.
  Extracted `_ensure_ui()` (builds the children if absent) and call it from both
  `_ready()` and the top of `start_mission()`.
- **combat_mode_changed double-emitted on End Combat. FIXED.**
  `submit_end_combat_consent()` emitted `combat_mode_changed(false)` directly but did
  not sync the controller's `_last_reported_mode`; the next `_run_npc_turns_and_sync()`
  poll saw the stale `true` and emitted the same false transition again. Added
  `AsciiMapView._emit_mode_change_if_any()` as the single source of truth (consumes the
  controller's transition latch via `poll_mode_changed`) and routed both the NPC-turn
  path and the End-Combat path through it. Now fires exactly once per transition.
- **MissionFlow.engage() burned AP on a blocked launch. FIXED.**
  `engage()` called `MissionEntryController.engage_mission()` (which spends 1 banked AP)
  before `_launch()` checked `is_busy()`/`_screen` — so firing ENGAGE_MISSION while
  already in a mission (or with no screen) spent the PC's AP for nothing. Moved the
  no-screen / already-in-mission guards ahead of the AP spend. +1 regression test.

### Systems Added 2026-06-06 (Kolat — Tranche 1)
- **s54.7 The Kolat (Tranche 1)** — `simulation/kolat_system.gd` (pure class). The
  Kolat is a huge multi-tranche system; this is the headless mechanical core (locked
  s54.7j). Was REFERENCE. Data model: `KolatSect` enum completed (+JADE/ROC/STEEL);
  hidden `L5RCharacterData` fields (`is_kolat_master`, `special_data`, sleeper fields
  `trigger_phrase`/`sleeper_command`/`conditioning_stability`/`active_sleeper_command`/
  `sleeper_contact_overdue`, koku fields `kolat_koku`/`dirty_koku`/`operational_koku`);
  `SettlementData.temple_vault_koku`. Subsystems with explicit s54.7c/e/h numbers:
  **sleeper conditioning** (`sessions_required` = Willpower×3, `resolve_conditioning_session`
  = 3-in-a-row contested Willpower vs Temptation+Intelligence, `complete_conditioning`
  installs the 4 hidden fields + applies −3.0 Honor to the Dream Master,
  `degrade_sleeper_seasonal` −5/season, `maintain_sleeper_contact` +10 capped,
  `can_activate_sleeper`/`activate_sleeper` gated on dormant + stability > 50 + phrase
  match, `is_valid_command_phrase` ≤5 words); **koku pipeline** (`add_dirty_koku`,
  `launder_koku` ≤5/AP dirty→kolat, `transfer_to_vault` kolat→vault, `allocate_from_vault`
  vault→operational, `vault_below_threshold` 50); **disruption** (`sponsor_insurgency_cost`
  10/strength, `bribe_garrison_cost_per_season` 5, `can_fund_disruption`); **dead-drop
  concealment** (`make_dead_drop`/`register_dead_drop_visit` −1 past 3 visits/season,
  0=abandoned/`reset_dead_drop_season`); **Eye contention** (`resolve_eye_contention`
  priority→Tiger→Status). 21 tests. DEFERRED (later tranches): master selection at
  world-gen (10 fuzzy sect profiles), the 6 NeedTypes + 29 ActionIDs as live pipeline
  entries (scoring JSON + decomposition + executors), the sleeper override loop,
  dual-stance topic positions, succession, win-condition pipeline, the Conclave, Tiger
  Tear routing, per-Master network-record lifecycle.
- **s54.7 The Kolat (Tranche 2 — Master selection)** — `simulation/kolat_master_selector.gd`
  (pure class; locked s54.7j2). World-generation Master selection per s54.7a:
  `select_masters(npcs, dice)` applies universal filters (Insight ≥ 3, not Emperor, one
  seat/NPC), per-Sect minimums, a weighted-tier draw (T1 ×5 / T2 ×2 / T3 ×1), the fixed
  processing order as conflict resolution (Tiger→…→Steel), Sect skill boosts (max rule),
  and stamps the hidden Master fields (`is_kolat_master`, `kolat_sect`, `kolat_superior_id`
  — Tiger → -1, others → Tiger). Returns KolatSect → npc_id (-1 = vacant).
  `get_special_rule_flags()` surfaces Coin 2d10×10 hidden koku / Dream 1d6+2 sleepers /
  Silk 1d6+2 contacts for the world generator. Role-based tier criteria mapped to queryable
  fields (clan/family/school_name/role_position/skills/status/glory/school_type; lord-tier
  via role_position); Dream and Steel T1 relaxed to skill/glory thresholds (PROVISIONAL — no
  institutional-access field). 9 tests.
- **s54.7 The Kolat (Tranche 3 — scoring/data pipeline)** — completed the NPC-engine
  scoring data for the Kolat ActionIDs/NeedTypes (s54.7c). objective_alignment.json already
  carried the 6 Kolat NeedTypes (forward-wired); added all **29 Kolat ActionID skill
  mappings** to `action_skill_map.json` (exact s54.7c primary/secondary), AP costs in
  `_get_ap_cost` (1-AP default covers most; ARCHIVE_TOPIC / CONTRIBUTE_TO_RESERVE = 0;
  OBSERVE_VIA_EYE "all AP for the day" needs full-day special handling — deferred), and the
  Gi block on APPROACH_FOR_RECRUITMENT in `personality_filter.json` (other Kolat covert
  actions were already in Gi.always_blocked). 3 scoring-table tests. DEFERRED (deep engine,
  needs Godot): the 29 **executors** + 6 **decomposition functions** + **Phase-3 context-list
  unlock** (Kolat ActionIDs gated on `kolat_sect`/`kolat_objective`), the sleeper override
  loop, dual-stance topic positions, succession, win-condition pipeline, the Conclave, Tiger
  Tear routing, and special-rule world mutation.
- **s54.7 The Kolat (Tranche 4 — executor layer)** — `simulation/kolat_executor.gd` (pure
  class). Headless `execute(action_id, actor, metadata, dice)` handlers for the
  KolatSystem-backed ActionIDs: LAUNDER_KOKU / UNDERREPORT_KOKU / TRANSFER_KOLAT_FUNDS /
  CONTRIBUTE_TO_RESERVE (koku pipeline), CONDUCT_CONDITIONING (single session; cumulative
  progress + completion driven by the deferred decomposition), MAINTAIN_SLEEPER_CONTACT
  (+ Medicine/Perception TN 20 degradation read), ACTIVATE_SLEEPER, ESTABLISH_DEAD_DROP /
  CHECK_DEAD_DROP / ROUTE_VIA_DEAD_DROP / CHECK_CONFIRMATION_DROP, SPONSOR_INSURGENCY +
  BRIBE_GARRISON_COMMANDER (funding from vault-if-at-temple else kolat_koku; the insurgency
  seed / Stability penalty application is deferred to InsurgencySystem wiring). Topic/spell/
  network ActionIDs (ARCHIVE_TOPIC, RESURRECT_TOPIC, USE_CLOUDS_EYES, ANONYMOUS_TIP,
  DISTRIBUTE_INTELLIGENCE, …) return `{ok:false, reason:"deferred_system"}`. Wired into the
  main ActionExecutor dispatch and the Phase-3 context unlock in Tranche 5 (below). 12 tests.
- **s54.7 The Kolat (Tranche 5 — NPC-engine pipeline wiring)** — connects the executor and
  scoring data into the live decision loop (s54.7d/e; deep engine, unverified without Godot).
  `ContextSnapshot` gains `kolat_sect` / `is_kolat_master` / `has_kolat_objective`;
  `build_context()` populates them (sect + master flag from the hidden character fields,
  the objective flag from `world_state["has_kolat_objective"]`). **Phase-3 ActionID unlock:**
  `NPCDecisionEngine.KOLAT_ACTION_POOL` (29 IDs) is appended to the available-action list in
  `generate_options()` when `is_kolat_master` OR (`kolat_sect != NONE` AND
  `has_kolat_objective`) — Masters always carry the full Sect pool, conscious agents unlock it
  only while a Kolat objective is active. The Phase-4b allowlist (objective_alignment.json)
  then narrows the pool to the actions aligned with the current Kolat NeedType, so the Kolat
  NeedTypes (forward-wired in objective_alignment.json) need no bespoke decomposition — they
  fall through `ObjectiveDecomposer._passthrough` and are scored normally. **Sleeper override loop:** `run()` short-circuits to
  `_run_sleeper_override()` whenever `character.active_sleeper_command` is non-empty —
  it bypasses Phase-2 goal resolution AND the Phase-4 personality filter (conditioning
  overrides virtues/honor), decomposes the installed command via `_need_from_command()`, scores
  through the normal pipeline, and tags the result `sleeper_override` + `memory_suppressed`.
  **ActionExecutor dispatch:** `_KOLAT_ACTION_IDS` routes any Kolat ActionID to
  `KolatExecutor.execute()`, enriching `action.metadata` with the resolved NPC target; the
  result is wrapped into the standard executor result dict (`success` from `ok`, `reason`
  passthrough). `_get_ap_cost` sets ARCHIVE_TOPIC / CONTRIBUTE_TO_RESERVE = 0 AP. action_skill_map
  (29 IDs, Tranche 3) and personality_filter Gi-block (Tranche 3) already cover scoring.
  6 pipeline tests in `tests/test_kolat_pipeline.gd`. DEFERRED: full per-action metadata
  population by the 6 decomposition functions (targets/amounts/drops), dual-stance topic
  positions, Master succession, win-condition pipeline, the Conclave, Tiger Tear routing,
  per-Master network-record lifecycle, special-rule world mutation, and the
  topic/spell/insurgency-dependent executors.
- **s54.7 The Kolat (Tranche 6 — Kolat metadata + sleeper completion)** — fills the two
  faithful gaps left after Tranche 5. **Metadata:** `_build_kolat_metadata()` in
  `npc_decision_engine.gd` populates the resolved `target`/`sleeper` object plus
  `target_npc_id` for any Kolat ActionID, and — for ACTIVATE_SLEEPER — the `spoken_phrase`
  read from the sleeper's installed `trigger_phrase` (the conditioning Master knows the
  phrase, s54.7c). KolatExecutor still defaults amount/strength/concealment, and TRANSFER/
  SPONSOR/BRIBE temple resolution remains deferred (no SettlementData in NPC context).
  **Sleeper completion (s54.7e):** `run()` now checks `_sleeper_command_complete()` before
  entering the override — for elimination-type commands (ELIMINATE_CHARACTER / ASSASSINATE)
  the order is fulfilled once the named target is dead or no longer exists, at which point
  `active_sleeper_command` is cleared and the sleeper returns to ordinary behavior on the
  same AP. Non-elimination commands have no engine-detectable completion (the sleeper keeps
  acting until they die, per s54.7e) and are left untouched. +3 tests (9 total in
  `test_kolat_pipeline.gd`). DEFERRED unchanged minus completion detection: amount/temple
  metadata population, dual-stance topic positions, Master succession, win-condition
  pipeline, the Conclave, Tiger Tear routing, per-Master network-record lifecycle,
  special-rule world mutation, and the topic/spell/insurgency-dependent executors.
- **s54.7 The Kolat (Tranche 7 — special-rule world mutation)** — `KolatMasterSelector`
  now acts on the Sect special rules at selection time (`_apply_special_rules`, called per
  selected Master in `select_masters`). The Coin reserve (2d10×10) is applied directly to the
  Master's `kolat_koku`. The Dream sleeper count (1d6+2) and Silk contact count (1d6+2) are
  stamped into `special_data["world_start_sleepers"]` / `["preplaced_contacts"]` so the
  deferred network-creation pass knows the target counts without inventing which NPCs become
  sleepers/contacts (that selection is the per-Master network-record lifecycle, still
  deferred). `get_special_rule_flags()` retained as the pure descriptor. +3 tests (12 total in
  `test_kolat_master_selector.gd`). DEFERRED: amount/temple metadata, dual-stance topic
  positions, Master succession, win-condition pipeline, the Conclave, Tiger Tear routing, the
  network-record lifecycle (actual sleeper/contact NPC selection + conditioning), and the
  topic/spell/insurgency-dependent executors.
- **s54.7 The Kolat (Tranche 8 — Master succession)** — `KolatMasterSelector.evaluate_succession()`
  implements the s54.7g cascade (LOCKED, no new design). Pure resolver: takes the vacant
  `sect`, the npc pool, the decrypted `heir_designations` record (Dictionary[sect →
  Array[3 ranked npc_ids]]), and an `under_investigation_ids` array the caller supplies (the
  one heir condition the pure selector cannot read from character data). Runs the three-heir
  cascade — `_heir_valid()` checks alive / conscious agent in the Sect / not already a Master /
  not Broken (`special_data["kolat_broken"]`) / not under investigation — then falls back to
  `_discretionary_select()` (the s54.7a weighted tier draw restricted to conscious Sect agents)
  when all three heirs are unavailable. Elevation applies boosts + hidden fields but NOT the
  world-gen special-rule reserves (succession is inheritance, not a fresh seed) and clears the
  Kolat objective slot ("orientation, not inherited tasks", s54.7g). `_repoint_chain_after_succession()`
  re-points the chain: a new non-Tiger Master reports to the living Tiger; a new Tiger reports
  to no one and every other living Master re-points to them. Returns the new Master's npc_id or
  -1 (Sect unfillable). +6 tests (18 total in `test_kolat_master_selector.gd`). DEFERRED: the
  EVALUATE_SUCCESSION trigger wiring (death→IntelDB confirmation, heir_designations_key /
  tiger_succession_key hidden fields + Cloud-archive storage, the follow-on Tear/report AP
  actions), plus amount/temple metadata, dual-stance topic positions, win-condition pipeline,
  the Conclave, Tiger Tear routing, the network-record lifecycle, and the
  topic/spell/insurgency-dependent executors.
- **s54.7 The Kolat (Tranche 9 — dual-stance topic positions)** — `kolat_positions` (s54.7f,
  LOCKED): a hidden second topic-position dictionary on L5RCharacterData (topic_id →
  −100..+100), present only for conscious Kolat agents. ContextSnapshot gains `kolat_positions`;
  `build_context()` populates it from the character field only when `kolat_sect != NONE` (empty
  for everyone else). **Phase-5 substitution:** `_compute_topic_position_modifier()` now reads
  `ctx.kolat_positions` first for each scored topic and uses that stance when an entry exists,
  falling back to `known_positions` otherwise — so a Silk merchant whose public stance on an
  investigator topic is a mild −15 but whose true Kolat stance is −100 scores covert responses
  at full urgency, while the personality filter still constrains *which* actions the agent may
  take (the other six score components are unchanged). Topic-removal cleanup stays symmetric
  with `known_positions` (orphaned entries on resolved topics are benign — no separate pass,
  matching the existing `topic_positions` behavior). +3 tests (12 total in
  `test_kolat_pipeline.gd`). DEFERRED: the three population channels (Master/Tiger directive
  delivery, DISTRIBUTE_INTELLIGENCE stance push, direct-observation generation), plus
  amount/temple metadata, win-condition pipeline, the Conclave, Tiger Tear routing, the
  network-record lifecycle, and the topic/spell/insurgency-dependent executors.
- **s54.7 The Kolat (Tranche 10 — secrecy, Imperial counter-response, win condition)** —
  `simulation/kolat_secrecy.gd` (pure class, s54.7i LOCKED). Two world-state scalars added to
  WorldStateData (`kolat_exposure_level`, `imperial_awareness_level`, both 0–100, start 0) and
  persisted via WorldStateSaver JSON state. All deltas verbatim from s54.7i: exposure
  +5 traced merchant net / +10 cover-identity-criminal / +15 org-attributed assassination /
  +10–25 PC publish / −5 Lotus / −3 Coin bribe / −5 Cloud resurrect / −2 per season natural;
  awareness +5 Jade internal / +10–30 PC evidence / +20 Master interrogated / +40 key found.
  `apply_delta()` clamps 0–100; `apply_seasonal_exposure_decay()` applies −2/season (Imperial
  suppression above the response threshold uses the same numeric — s54.7i gives no extra
  amount, none invented). `is_response_active()` (awareness ≥ 30) and `response_tier()` map to
  the six s54.7i tiers (Unaware/Suspicious/Confirmed/PartiallyMapped/SignificantlyMapped/
  FullKnowledge at 0/30/50/70/90/100). `check_win_condition()` fires when the primary candidate
  (a) holds an Imperial-proximity role (Regent/Imperial Advisor/Voice of the Emperor/Imperial
  Chancellor), (b) has held it ≥ one full IC year (`TimeSystem.IC_DAYS_PER_YEAR`), and (c)
  awareness < 70 — and not while the candidate's pipeline stage is "compromised" or they are
  dead. 11 tests in `test_kolat_secrecy.gd`. DEFERRED (NPC-engine/orchestrator wiring, needs
  Godot): the event hooks that raise/lower the scalars at real operation/investigation points,
  Imperial-response NPC behaviors (expanded magistrate mandates, Hidden Guard reassignment,
  candidate protection), Tiger's candidate-pipeline fields + OVERSEE_KOLAT_NETWORK cultivation,
  and the win-condition world-state event emission. Plus the prior deferred items (population
  channels, metadata, Conclave, Tiger Tear routing, network-record lifecycle, dependent
  executors).
- **s54.7 The Kolat (Tranche 11 — Bushido virtue hard blocks)** — fixes a real gap: the
  Master selector never enforced the s54.7b personality hard-block table, so virtue-ineligible
  NPCs could be drawn into forbidden Sects. `KolatMasterSelector.BUSHIDO_HARD_BLOCKS` encodes
  the locked table (Gi → Tiger/Silk/Coin/Dream/Lotus; Makoto → Tiger/Silk/Dream/Lotus; Rei →
  Dream; Jin → Dream/Lotus; Chugi → Tiger). `_personality_permits()` is checked inside
  `_meets_minimums()`, so the block applies to both world-gen selection AND the Tranche 8
  discretionary succession path (which routes through `_meets_minimums`). Shourido virtues and
  NONE never block (they shape pursuit, not eligibility, per s54.7b). +5 tests (23 total in
  `test_kolat_master_selector.gd`). NOTE: the Sect→standing-objective NeedType mapping (s54.7b)
  is only pinned explicitly for Silk (MAINTAIN_KOLAT_NETWORK), Coin (MANAGE_KOLAT_FUNDS), and
  Dream (MAINTAIN_SLEEPER); the GDD gives the other seven Sects' standing mandates as prose
  without NeedType identifiers, so standing-objective assignment is a genuine design gap
  (owner must supply the remaining Sect→NeedType mappings) rather than something to invent.
- **s54.7 The Kolat (Tranche 12 — Sect standing-objective mandate)** — when a character holds
  a Master seat their standing objective becomes the Kolat mandate for their Sect (s54.7b).
  `KolatSystem.SECT_STANDING_NEEDTYPE` maps eight Sects: three pinned explicitly by s54.7c
  (Silk→MAINTAIN_KOLAT_NETWORK, Coin→MANAGE_KOLAT_FUNDS, Dream→MAINTAIN_SLEEPER) and five
  structural name-matches where the s54.7b mandate sentence restates one already-defined
  objective_alignment NeedType (Tiger→MONITOR_KOLAT_SECURITY, Chrysanthemum→MONITOR_IMPERIAL_COURT,
  Cloud→MAINTAIN_CLOUD_ARCHIVE, Jade→ASSESS_SUPERNATURAL_THREAT, Steel→MONITOR_TEMPLE_PERIMETER).
  Roc → "" (inactive at launch, s54.7b). **Lotus → MAINTAIN_DEAD_DROP_SCHEDULE (owner
  decision 2026-06-06):** Lotus is reactive — it executes Tiger's dead-drop elimination
  assignments — so its self-generated standing is keeping that assignment channel ready.
  All 9 active Sects are now mapped (Roc alone is empty, by GDD). `standing_needtype_for_sect()`
  returns the mapping; `DayOrchestrator._assign_kolat_standing_objectives()` (wired into the
  daily standing-assignment block beside magistrate/monk/ronin) writes the mandate into
  `objectives_map[id]["standing"]` for living non-PC Masters, never overwriting an existing
  standing objective, skipping Roc (empty mandate). +6 tests (18 total in
  `test_kolat_pipeline.gd`). DEFERRED (need Godot runtime / other live systems): the three
  kolat_positions population channels, amount/temple metadata, scalar event hooks +
  Imperial-response NPC behaviors + Tiger candidate pipeline + win-condition event emission,
  the Conclave, Tiger Tear routing, the network-record lifecycle, CONTRIBUTE_TO_RESERVE→
  local_reserve_koku correct routing, and the topic/spell/insurgency-dependent executors.
- **s54.7 The Kolat (Tranche 13 — secrecy event→delta dispatch)** — `KolatSecrecy` gains
  `ExposureEvent`/`AwarenessEvent` enums and `exposure_delta()`/`awareness_delta()` dispatchers,
  the single tested entry point the future operation/investigation executors call instead of
  hand-coding s54.7i deltas. Fixed-value events return their constant; the two GDD ranges
  (player-publish +10..+25, player-evidence +10..+30) interpolate by a 0–1 `scope` via
  `_scope_lerp`. Composes with `apply_delta` (clamp 0–100). All values verbatim from s54.7i —
  no invention. +5 tests (16 total in `test_kolat_secrecy.gd`). The seasonal orchestrator pass
  that calls these at real operation points (and applies natural decay + recomputes
  `imperial_response_active` + checks the win condition) remains deferred — it is inert until
  the operation executors that move the scalars exist, and wiring it now would add unverifiable
  plumbing for zero behavior.

### Systems Added 2026-06-09 (s43 Maho — library + CAST_MAHO seasonal trigger)
- **MahoSpellLibrary** (`simulation/maho_spell_library.gd`) — all 46 s43 maho
  spells transcribed as data (spell_id → name, mastery_level, ring, one-line
  effect summary). Pure GDD transcription. `pick_cast_spell(caster)` selects the
  highest Mastery Level whose Ring the caster supports (ring value ≥ ML) and whose
  self-blood cost (2×ML wounds) the caster survives (wounds_taken + 2×ML ≤
  `CharacterStats.get_total_wound_capacity`); ties broken by strongest Ring then
  sorted spell_id. `get_spell()` / `spell_ids_by_ml()` accessors.
- **CAST_MAHO seasonal trigger** (owner-authorized design 2026-06-09) —
  `DayOrchestrator._process_seasonal_maho_casts()` runs in the seasonal block
  right after `_process_bloodspeaker_network()`. For each ACTIVE/PROPAGATING
  Bloodspeaker cell, a cult-affiliated member co-located in the cell's province
  casts one maho spell. `_select_or_corrupt_maho_caster()`: prefers an existing
  living `cult_affiliation` member; else corrupts the most-Tainted living non-PC
  in the province (taint > 0 → sets `cult_affiliation = true`); PCs are never
  auto-corrupted (s60); no caster if nobody is Tainted (cells still raise PTL
  passively, breeding future corruptibility). Self-blood model (GDD: "the caster
  ... must spill blood"). Fires `MahoSystem.resolve_cast(caster, caster, …)` →
  blood wounds, caster Taint, PTL +1, MAHO CrimeRecord (appended to crime_records,
  next_case_id bumped), blood-evidence concealment roll. **Scope (authorized):**
  cost/Taint/PTL/crime/evidence only — the ~46 spell *effects* are deferred to
  s40 (combat/undead/oni-blocked). Activates detection Channels 1–3 (PTL crisis
  topics, EXAMINE_CRIME_SCENE blood evidence, taint symptoms) per Design Decision
  #5. Decisions locked with owner: seasonal cell-lifecycle trigger (not a daily-AP
  ActionID), cult-affiliated-only casters, most-tainted-corruption affiliation,
  highest-affordable-ML spell choice. 14 tests (`test_maho_spell_library.gd` 6,
  `test_maho_seasonal_cast.gd` 8). NOTE: the s43 "cast roll TN" gap in Section D
  is moot — GDD s43 confirms maho has no casting roll.
- **Spreading the Darkness — first wired Grand-Map spell effect (s43, owner-authorized
  2026-06-09).** The first maho spell whose *effect* resolves at world-sim scale
  (the rest remain s40-deferred). When a cell holds a dangerously Tainted member
  (Taint Rank ≥ 2 — the Channel-3 detection onset, Decision #5), it casts Spreading
  the Darkness instead of its highest-ML spell, if the caster's Earth supports ML2
  (`MahoSpellLibrary.can_support_spell`). `_resolve_spreading_the_darkness` moves up
  to (caster Earth + Insight Rank) Taint off the most-Tainted cult member, never
  below 1.0 (GDD "cannot remove the last Point"). Two modes (owner decision (c) =
  both): **PUSH** onto a co-located unwilling named NPC when one is present —
  preferring an active investigator (`UPHOLD_LAW`/`INVESTIGATE_THREAT` — frame the
  hunter, who then reads as Tainted to Channel 3), else the highest-Status non-cultist
  (corrupt a leader) — gated by a contested Willpower roll vs the caster (recipient
  wins → spell fails); else **DUMP** into a nameless untracked victim (the source's
  Taint simply drops). A pushed recipient's raised Taint is caught by the daily
  `_process_taint_rank_changes` pass (mutations / Lost) and feeds Channel-3 detection.
  `_pick_taint_shed_source`, `_pick_darkness_push_target`, `_is_active_investigator`,
  `_darkness_higher_status` added. `objectives_map` threaded into
  `_process_seasonal_maho_casts` (trailing optional param). 10 tests added
  (`test_maho_seasonal_cast.gd` 8→18). LIMITATION: the cast's *blood cost* still
  self-bleeds the caster (existing committed model) — switching the blood source to
  a nameless victim (which lifts the survivability ML cap) is a separate global maho
  change, not done here.
- **Stealing the Soul — second wired Grand-Map spell effect (s43, owner-authorized
  2026-06-09).** The 1-day Trait drain is inert at world scale, so only the lethal
  branch resolves: "if this reduces the Earth Ring, their Wounds are lowered,
  potentially resulting in death." `_soul_steal_would_kill` is side-effect free —
  it temporarily drops the Earth-setting Trait (lower of Stamina/Willpower) by 1,
  checks `CharacterStats.is_dead` against the standard wound model, restores. So it
  only kills a **co-located, already-wounded** target whose wounds exceed the
  reduced (one-Earth-level-lower) capacity. `_pick_soul_steal_target`
  (**investigators-only**, owner decision): a co-located living non-PC non-cultist
  holding an active `UPHOLD_LAW`/`INVESTIGATE_THREAT` objective for whom the drop is
  lethal, highest Status first; none → the cell doesn't cast it. Spell-selection
  priority (owner): **kill (Stealing the Soul, ML4/Earth 4) > shed (Spreading the
  Darkness, ML2) > highest-ML**. `_resolve_stealing_the_soul` honors GREAT_DESTINY
  (s45 — target cheats death, drops to DOWN), else mirrors `_apply_victim_death`
  (wounds lethal = Earth×25, suspicious `death_event` with `killer_id`/`is_lord`,
  Tier 2 LEGAL mysterious-death topic, NEUTRAL subject_role). The seasonal second
  death pass (after the maho casts) fires succession same-season. Single-caster base
  drain (no Raises); fetish possession assumed (no fetish inventory tracked). The
  cast's MAHO crime record is separate; the death shows no obvious cause.
  `death_events`/`active_topics`/`next_topic_id` threaded into
  `_process_seasonal_maho_casts` (trailing optional params). 9 tests
  (`test_maho_seasonal_cast.gd` 18→27).
- **Fierce Blood of the Earth — third wired Grand-Map spell effect (s43,
  owner-authorized 2026-06-09).** The first maho effect with an always-on payload.
  Sacrifices a nameless victim (the cast's blood source = a transient
  `L5RCharacterData`, NOT the caster — faithful to "consumes the victim's life
  force", and lets a wounded caster survive to heal); the caster heals all injuries
  (`wounds_taken = 0`) and buys one year of life. **Longevity hook (death-model
  change):** new `life_extension_years: int` field on L5RCharacterData;
  `GempukkuSystem.roll_natural_death` now rolls against `effective_age = age −
  life_extension_years`, so maho-bought years pull the caster back under the
  50/65/75/85 death-chance brackets. `_resolve_fierce_blood` sets wounds 0 and +1
  year. `_fierce_blood_has_benefit` gates the cast to a concrete benefit (caster
  wounded OR effective age ≥ 50 — a young healthy caster wastes no victim).
  Ring-only gate (`MahoSpellLibrary.supports_spell_ring`) — not bounded by the
  caster's own survivability since the life cost is the victim's. Spell-selection
  priority: **kill > Fierce Blood > shed > highest-ML**. Limb/organ regrowth not
  modeled (no system); mummified-appearance signal skipped (no detection mechanic
  to hang it on). 7 tests (`test_maho_seasonal_cast.gd` 27→34); gempukku 58/58 (no
  regression). All three clean Grand-Map maho effects now wired (Spreading the
  Darkness, Stealing the Soul, Fierce Blood of the Earth); the remaining ~43 spells
  stay s40/ASCII-deferred.
- **Seasonal maho casts use the victim-blood model (s43, owner-authorized
  2026-06-10).** Every seasonal Bloodspeaker cast's 2×ML blood cost is now paid by
  a sacrificed nameless victim (a transient `L5RCharacterData` blood source), not
  the caster's self-blood. The 2×ML number is unchanged — only the source moved
  (owner ruling reinterpreting GDD "the caster must spill blood" as the cell
  consuming a victim). Consequence: the caster takes no wounds, so the cast is
  gated **only by Ring support** — all three wired-spell gates switched from
  `can_support_spell` to `supports_spell_ring`, making the high-ML wired spells
  (Stealing the Soul ML4, Fierce Blood ML5) reachable by low-wound-capacity casters
  who couldn't survive the self-blood before. `pick_cast_spell` repurposed to the
  generic fallback: **lowest** Ring-supported ML (not highest) — same flat PTL +1
  per cast but minimal caster self-Taint (ML − 1), so cells corrupt the province
  without senselessly burning their caster toward Lost on an unwired spell (owner
  chose lowest over highest). Returns {} only when no Ring is supported at all.
  4 library tests rewritten (survivability cap removed); seasonal 34/34 unchanged.
- **Caress of Fu Leng — fourth wired Grand-Map spell effect (s43, owner-authorized
  2026-06-10).** ML2 Earth jade-sabotage. A cult member co-located at a settlement
  with `jade_stockpile > 0` (Range 50' = co-located) destroys **N=3 fingers**
  (owner-set quantity; jade is measured in fingers, 1/warrior per s2.4.15) via
  `_resolve_caress_of_fu_leng` (floors at 0). The existing Wall pass recomputes
  `jade_stockpile_critical` next tick → weakens Shadowlands taint-suppression and
  triggers NPC jade-resupply objectives. `_caster_jade_settlement` resolves the
  caster's co-located SettlementData (settlements indexed by id; `settlements`
  threaded into `_process_seasonal_maho_casts` as a trailing param). Spell-selection
  priority: **kill > Fierce Blood > Caress > shed > lowest-ML fallback**. Taint/PTL/
  crime apply via the cast (victim-blood). "Cannot affect nemuranai" auto-satisfied
  (nemuranai not tracked). LIMITATION: `jade_stockpile` is uninitialised (defaults 0)
  and stocked almost only at Kaiu Wall towers, where Bloodspeaker cells rarely sit —
  so this fires **rarely** until jade is stockpiled more broadly (temples/Kuni). The
  companion spell **Purge the Weak** (ML1) stays s40/encounter-deferred: its GDD area
  is "food/water for up to 5 people" (sub-settlement scale — `rice_stockpile` is a
  rounding error against it) and its payload is a −3k0 / 2-week illness *condition*
  with no world-scale condition system to hold it. 6 tests (`test_maho_seasonal_cast.gd`
  34→40).
- **Drain the Soul + Touch of Death — fifth and sixth wired Grand-Map spell effects
  (s43, owner-authorized 2026-06-11).** Two more Earth maho spells now resolve at
  world scale (target scope = "any named NPC", owner choice — broader than the
  investigators-only Stealing the Soul). **Drain the Soul (Earth 2):** GDD reduces
  Stamina Rank by 1 (10-min duration), "can lower the Earth Ring, reducing Wound
  Ranks." Only the lethal branch is durable at world scale, so `_pick_drain_soul_target`
  selects a co-located (range 50') living non-PC non-cultist whose Stamina drop is
  fatal (`_drain_stamina_would_kill`: drop Stamina, check is_dead via Earth =
  min(Stamina,Willpower) capacity, restore), highest Status; none lethal → not cast.
  Reuses the Stealing-the-Soul death path (mysterious death). ML2 = far more
  reachable than Stealing (ML4). **Touch of Death (Earth 5):** GDD "ages 10 years
  and suffers 7k7 Wounds... aging cannot be reversed." `_resolve_touch_of_death`
  applies `age += 10` (permanent; feeds `GempukkuSystem.roll_natural_death`) + 7k7
  exploding Wounds (`roll_and_keep(7,7,true).total`, applied directly — a curse, no
  armor/Reduction). Kills → GREAT_DESTINY cheats to DOWN (still aged) else suspicious
  death_event + Tier 2 mysterious-death topic; survives → persists wounded + aged.
  `_pick_touch_of_death_target` = highest-Status co-located non-cultist (no lethality
  precondition). **Selection priority** (s43 seasonal cast): Stealing the Soul
  (investigator finish) → Touch of Death (ML5, most decisive broad kill) → Drain the
  Soul (ML2, cheap broad kill) → Fierce Blood → Caress → Spreading the Darkness →
  lowest-ML fallback. Fallback casts of either spell with a null target are guarded
  (no-op cast, PTL/crime only). Victim-blood cost unchanged. Parse-checked; no tests
  per the no-test-code policy. TUNING (playtest): "any named NPC" scope lets a
  high-Earth caster Touch-of-Death the highest-Status co-located figure unprovoked —
  watch for prominent-noble kills destabilising via succession.
- **s43 seasonal maho casts — runtime-verified (2026-06-12).** The seasonal
  Bloodspeaker cast pass (`_process_seasonal_maho_casts`) and its 6 wired Grand-Map
  spell effects were exercised end-to-end with a headless SceneTree driver (the
  project's parse-check/driver validation path; GUT is non-functional headless and
  off-policy). Confirmed across three scenarios in one pass: (1) a most-Tainted
  non-cultist is corrupted (`cult_affiliation` set) when no cult member is present,
  then sheds its own Rank-3 taint via Spreading the Darkness (priority #6) —
  PTL +1, self-taint +1 (ML−1), MAHO crime record appended + case-id bumped;
  (2) an Earth-5 caster casts Touch of Death on a co-located healthy victim —
  7k7 Wounds killed (50 dmg), permanent age +10 applied, suspicious death_event +
  Tier-2 mysterious-death topic created; (3) an Earth-2 caster at a jade settlement
  casts Caress of Fu Leng — jade_stockpile 5.0→2.0 (−3 fingers). Victim-blood model
  confirmed (caster takes no wounds; gated only by Ring support). No bugs found; no
  code change. Upgrades status from "parse + static review only" to runtime-verified.
  COVERAGE NOTE: the pure lowest-ML fallback (`pick_cast_spell`) was not exercised
  — a freshly-corrupted caster with taint < 2 and no other tainted member would hit
  it; here the caster's own Rank-3 taint correctly diverted to the shed path.
- **s43 Grand-Map spell sweep COMPLETE (2026-06-11).** Audited all 46 maho spells
  for world-scale-wirable effects (persistent NPC/province state, no s40 combat or
  condition layer). **6 are wired** (Spreading the Darkness, Stealing the Soul,
  Fierce Blood of the Earth, Caress of Fu Leng, Drain the Soul, Touch of Death).
  **The other 40 are genuinely blocked** — no further wiring warranted. Near-misses
  checked against the GDD and rejected with cause: **Dancing with Demons** (Air 3) —
  24-hour Advantage/Disadvantage, inert at daily/seasonal cadence (expires before
  anything resolves) + Perform: Dance TN 25 gate. **Heart of the Damned** (Earth 1) —
  heal + restore-a-reduced-Trait, but requires a corpse dead within 1 day and
  `death_events` is cleared daily (no fresh-corpse registry); strictly dominated by
  Fierce Blood; restore part usually inert (no persistent trait reduction tracked).
  **Blood Rite** (Earth 1) — 10-min, trivial 1k1 heal, only durable bit (ally Taint)
  is counterproductive. **Strength of Darkness** (Fire 5) — 10-round combat buff,
  lethal-on-expiry is a combat interaction (s40). **Curse of the Clan** (Air 2) —
  GDD explicitly frames it as a role-playing/GM challenge, no mechanic to attach.
  Remaining spells: combat rounds (Bleeding, Pain, Burning Blood, Tomb of Earth,
  Curse of Weakness, No Pure Breaths, Blood Armor…), sub-day conditions/wards
  (Inspire Fear, Sinful Dreams, Curse of the Kansen, Symbol of Blood, Ward of
  Divine Peace, Truth is a Scourge…), undead/oni summons (Summon Undead Champion,
  Eternal Unrest, Puppet Master, Death Beyond Life, Essence of Undeath, Summon Oni…),
  or no-mechanic utility (Written in Blood, Possession, Take the Body) — all blocked
  on s40/s54. The wired set is the complete world-scale maho catalog; do not
  re-audit without the combat/condition/undead layers.
- **s43 Grand-Map spell sweep RE-VERIFIED at GDD-text level (2026-06-13).** Re-ran the
  sweep against the actual s43 spell text (not the one-line `MahoSpellLibrary` summaries)
  for the strongest near-misses, since the durations/areas in the full text are decisive.
  Confirms the 2026-06-11 conclusion: the **same 6 spells are wired** and **no new
  world-scale slice exists**. GDD-text findings on the borderline cases:
  **Purge the Weak** (Earth 1) — Duration *Permanent* BUT Area is "food/water for up to
  5 people" (Raises add +1 person each); destroying ~5 rations is a rounding error against
  a settlement `rice_stockpile` (hundreds of PU fed), and the teeth — an *incurable*
  2-week −3k0 illness — is a condition with no world-scale model. (Contrast Caress of Fu
  Leng: a 3-finger jade hit IS strategically meaningful because jade is scarce/tracked.)
  **Take the Body** (Air 6) — Duration *Permanent*, true identity transfer, but "Known only
  to Iuchiban and Yajinden" + needs a full soul-swap mechanic (caster mental stats overwrite
  victim's, old body dies); named-villain scope, not an anonymous seasonal cult cast.
  **Possession** (Air 5, *1 day*), **Stealing the Soul** Trait-drain (*1 day*),
  **Drain the Soul** Stamina (*10 min*), **Suck the Marrow** (*1 day*), **Gift of the Maker**
  Greater Power (*1 hour*) — all temporary, expire before the seasonal cadence resolves;
  Stealing/Drain are already wired for their *lethal* Earth-reduction branch (the temporary
  non-lethal branches stay inert). No combat-round spell (Bleeding/Burning Blood/Tomb of
  Earth/No Pure Breaths) has a clean lethal/permanent sub-branch — faithfully world-scaling
  their per-round DR would mean inventing a damage total (forbidden). Conclusion stands: the
  wired set is complete; do not re-audit a third time without the s40 combat / world-scale
  condition / s54 undead layers.
- **Maho Channel 3 wired — Taint detection on a person (Design Decision 5,
  owner-authorized 2026-06-10).** Closes the last open maho detection channel: a
  shugenja whose successful action targets a suspect (PROBE/INVESTIGATE near them,
  s55.12 proximity) rolls Perception + Lore: Shadowlands; on success a Tier 3
  SUPERNATURAL topic names the suspect a suspected maho user (subject_role
  PERPETRATOR), routed to the detector's lord → UPHOLD_LAW → investigation. A
  results-based **stub already existed** (`_process_taint_proximity_detection`,
  wired + tested) implementing every gate — Taint Rank ≥ 2, Kuni/Asako auto +
  other shugenja at Lore: Shadowlands ≥ 3, +2k0 — but with a **placeholder TN of
  0** and no Crab exemption. Completed it with the owner's values: detection
  **TN = (8 − Taint Rank) × 5** (30/25/20/15 for Rank 2–5 — eases as corruption
  manifests; owner revised from (7 − Rank) × 5 to (8 − Rank) × 5 on 2026-06-10),
  and a **Crab-clan exemption** ("innocent explanation" proxy — no Wall-service
  field exists, and Crab legitimately accrue Taint at the Kaiu Wall). Removed
  `TAINT_DETECTION_PLACEHOLDER_TN`. This makes the Taint the new seasonal casters
  accrue (ML − 1 per cast) actually catchable in proximity. The active, deliberate
  examination is now also WIRED (EXAMINE_FOR_TAINT, see below); the Sense spell is
  NOT the tool — canonically it detects elemental kami, not kansen (owner
  correction 2026-06-10). 7 tests (`test_maho_channel3.gd`); full
  suite 13219 passing / 0 failing. Hardening (2026-06-10): added a dead-character
  guard on detector/target — a suspect who died mid-day must not receive a
  PERPETRATOR-valence accusation (hard rule: dead characters carry NEUTRAL
  subject_role). +1 test (8 total).
- **Maho Channel 3 active examination — EXAMINE_FOR_TAINT (owner-authorized
  2026-06-10, R2 corroboration).** The deliberate counterpart to the passive
  proximity check. A new NPC ActionID (1 AP, AT_OWN_HOLDINGS/AT_COURT/VISITING,
  Lore: Shadowlands/Perception) by which a witch-hunter who already knows an
  active `taint_suspected` accusation deliberately examines the co-located
  accused suspect to confirm the corruption firsthand. **R2 corroboration model
  (owner choice):** the lead IS an existing accusation; the value is independent
  confirmation. Orchestrator pre-pass `_build_taint_corroboration_targets()`
  finds, per living examiner (Kuni/Asako OR Lore: Shadowlands ≥ 3), a co-located
  living non-Crab Rank-2+ suspect named in an active accusation the examiner
  knows (topic_id in topic_pool) and has NOT yet corroborated (no
  `taint_corroborated` KnowledgeEntry for that topic) — `examiner_id →
  {target_id, topic_id}`, injected as `has_taint_corroboration_target` +
  `known_objectives` target/topic; gated by Phase-4c
  `_apply_taint_examination_precondition_filter`. Executor
  `_execute_examine_for_taint()` revalidates (dead/Crab/Rank<2 guards), rolls
  Lore: Shadowlands (Perception) vs **(8 − Taint Rank) × 5** (Kuni/Asako +2k0 —
  same formula as the passive check). On success, writeback
  `_process_taint_examination_writebacks()` refreshes the accusation's momentum
  to the TIER_3 floor + discussion bump (sustains the case), widens reach to the
  examiner's lord's topic_pool, and records the dedup KnowledgeEntry. Scoring:
  objective_alignment INVESTIGATE_THREAT 85 / UPHOLD_LAW 65 (calibrated vs
  EXAMINE_CRIME_SCENE 90 / SEARCH_PERSON 60–70, PROVISIONAL); action_skill_map
  Lore: Shadowlands/Perception; added to `_OBSERVATION_ACTIONS`; stale-key
  `has_taint_corroboration_target`. Dead guards at pre-pass, executor, and
  writeback (a dead suspect is never accused). NOT a Sense cast (Sense detects
  kami, not kansen). 14 tests in `tests/test_maho_examination.gd`. NOTE: tests
  not executed here — headless GUT fails on the WeaponData cold-boot cascade;
  validated by per-file `--check-only` parse (clean) + static review.
- **Passive Channel 3 dedup — reinforce instead of re-accuse (2026-06-10).**
  `_process_taint_proximity_detection()` previously created a fresh
  `taint_suspected` accusation on every successful detection, so a tainted
  person who kept drawing witch-hunter attention accumulated duplicate
  accusation topics. Now, when the suspect already carries a **live** accusation
  (`_find_active_taint_accusation()` — variant `taint_suspected`, matching
  subject, not resolved), a renewed detection **reinforces** it via the shared
  `_refresh_taint_accusation()` helper (momentum restored to the TIER_3 floor,
  discussion bump, reach widened to the detector's lord) instead of spawning a
  duplicate; a brand-new accusation is created only when none is active. The
  EXAMINE_FOR_TAINT writeback was refactored to call the same
  `_refresh_taint_accusation()` helper, so passive re-detection and active
  corroboration now sustain a case identically (the active path additionally
  records its per-examiner dedup KnowledgeEntry). Lifecycle: once the accusation
  resolves/decays and is removed from `active_topics`, a fresh one can be raised
  again. Parse-checked; no tests per the no-test-code policy.
- **Channel 3 review fixes (2026-06-10, post-implementation review).** Two
  follow-ups from a code-review pass: (1) **Double-processing bug — FIXED.** The
  passive `_process_taint_proximity_detection()` scans all day results by
  `success`/`character_id`/`target_npc_id` with no action filter and runs before
  the dedicated EXAMINE_FOR_TAINT writeback, so a successful examination got a
  redundant second detection roll + double refresh. The passive pass now skips
  `action_id == "EXAMINE_FOR_TAINT"` results (the corroboration writeback owns
  them). (2) **TN/eligibility DRY — the `(8 − Rank) × 5` formula, the Rank-2
  detection threshold, the Kuni/Asako specialist check, and the
  specialist-or-Lore≥3 detection gate were duplicated across the passive
  detector, the pre-pass, and the executor.** Centralized into `MutationSystem`:
  `TAINT_DETECTION_RANK_MIN` (2), `taint_detection_tn(rank)`,
  `is_taint_specialist_family(family)`, `can_detect_taint(c)`. All three sites
  call these now; the orphaned day_orchestrator `TAINT_RANK_THRESHOLD` const was
  removed. A future TN/gate tweak is a single edit. Parse-checked.
- **EXAMINE_FOR_TAINT scoring/effect — review outcome (2026-06-10).** The two
  objective_alignment scores (INVESTIGATE_THREAT 85, UPHOLD_LAW 65) and the
  corroboration effect were reviewed against the sibling investigation actions
  and judged sound (85 between EXAMINE_LETTER 85 and EXAMINE_CRIME_SCENE 90;
  65 between SEARCH_PERSON 60 and INVESTIGATE_PROVINCE 70). They remain
  PROVISIONAL pending an actual live playtest (not runnable in this
  environment); no numeric change was invented without empirical data.
- **Maho Channel 3 — runtime-verified (2026-06-12).** The full Channel-3 detection
  pipeline (passive `_process_taint_proximity_detection` + active EXAMINE_FOR_TAINT)
  was exercised end-to-end with a headless SceneTree driver (parse-check/driver path;
  GUT is non-functional headless and off-policy). Confirmed: TN `(8−rank)×5` =
  30/25/20/15; `can_detect_taint` gate (Kuni specialist true, Lore: Shadowlands ≥3
  true, 2 false); passive accusation topic created correctly (TIER_3 / SUPERNATURAL /
  subject_role PERPETRATOR / variant taint_suspected / propagated to the detector's
  lord's topic_pool / momentum at the TIER_3 floor); dedup-reinforce (a renewed
  detection on the same suspect refreshes momentum instead of spawning a duplicate);
  Crab exemption + dead-suspect guard + Rank-2 threshold all skip correctly; active
  corroboration target-building, the executor's Lore: Shadowlands roll, the writeback
  (momentum refresh + taint_corroborated KnowledgeEntry), and the
  already-corroborated re-exclusion. No bugs found; no code change. Upgrades status
  from "parse + static review only" to runtime-verified. (The objective_alignment
  scores remain PROVISIONAL pending a live playtest, as noted above.)
- **s11.3.5 Witch-Hunter standing + roaming (owner-authorized 2026-06-10).**
  Closes the maho hunting loop: Kuni Witch-Hunters, Asako Inquisitors, and the
  three anti-maho order leaders (Crab/Phoenix/Scorpion) are now autonomous
  hunters instead of idling when they hold neither a lordship nor a magistracy.
  **New HUNT_MAHO NeedType** (objective_alignment: INVESTIGATE_PROVINCE 100,
  EXAMINE_FOR_TAINT 90, EXAMINE_CRIME_SCENE 85, PURIFY_TAINTED_GROUND 70,
  SEARCH_PERSON 60, PROBE 50 — all PROVISIONAL, calibrated vs INVESTIGATE_THREAT)
  routed via `ObjectiveDecomposer._decompose_hunt_maho` (in INVESTIGATION_OBJECTIVES):
  travels toward a target hotspot settlement when one is set, else passthrough to
  hunt locally. **Standing layer:** `_assign_witch_hunter_standing_objectives`
  (daily, runs BEFORE the monk pass because Kuni Witch-Hunters are [Monk]
  school_type — otherwise the monk pass stamps PERFORM_RITUAL first) assigns
  HUNT_MAHO to idle hunters via `_is_maho_hunter` (school_name contains
  Witch-Hunter/Witch Hunter/Inquisitor, or the three leader POSITIONs; Kuroiban
  rank-and-file deferred — secret order, no clean identifier). **Roaming layer:**
  `_process_witch_hunter_self_selection` (seasonal) finds the worst Taint hotspot
  (highest `province_taint_level` ≥ WITCH_HUNT_PTL_MIN = 3.0, the PTL crisis
  onset; PROVISIONAL) and gives idle hunters a primary HUNT_MAHO objective
  targeting a settlement there — the decomposer then travels them cross-border
  (witch-hunters ignore clan lines, s11.3.5). A self-selected hunt releases when
  its target province cools below the floor; a real (lord-assigned) primary
  outranks it (resolve_goal prefers primary over standing). INVESTIGATE_PROVINCE
  added to the VISITING context list so a roaming hunter can PTL-scan a foreign
  province (safe: the Phase-4b allowlist only lets investigation needs select
  it). Idle hunters **spread** across hotspots: each takes the least-covered
  hotspot (ties → highest PTL), and hunters already committed or already standing
  in a hotspot count toward its coverage, so they fan out instead of swarming the
  single worst province. LIMITATIONS: a witch-hunter who also holds a magistracy
  gets UPHOLD_LAW first (magistrate pass runs earlier) — rare dual-role; spread
  uses coverage count, not map distance (no travel-distance data). Parse-checked;
  no tests per the no-test-code policy.
- **s11.3.5 Witch-Hunter cross-border incident (owner-authorized 2026-06-10).**
  s11.3.5 calls Kuni Witch-Hunters ignoring clan boundaries a "potential
  diplomatic incident generator." `_process_witch_hunter_border_incidents` fires
  on travel arrival: when a **Kuni Witch-Hunter** (`_is_kuni_witch_hunter` —
  school "Witch-Hunter"/"Witch Hunter" or WITCH_HUNTER_LEADER; Asako Inquisitors
  are welcomed and Kuroiban are covert, so both are excluded) arrives in a
  province whose `clan` differs from the hunter's, the host province lord
  (`_find_province_lord`) takes **−5 disposition toward the hunter**
  (BORDER_INCIDENT_DISPOSITION, owner-set; clamped) AND the host clan's
  collective standing toward the hunter's clan ripples down via
  `CollectiveDisposition.apply_event_ripple` (the ~−2 comes from the existing
  CLAN_RIPPLE_WEIGHT — not an invented value), plus a **Tier 4 POLITICAL** topic
  ("Kuni Witch-Hunter operating in <clan> lands", variant `witch_hunter_border`,
  subject = hunter) seeded to the host lord. Deduped to one live incident per
  hunter per province (`_find_active_border_topic`); a cooled/resolved topic lets
  a fresh intrusion re-fire. Dead guards on hunter and host lord. Wired into the
  arrival block (clan/family baselines ensured in world_states first).
  Parse-checked; no tests per the no-test-code policy.
- **s11.3.5 Kuroiban / Black Watch membership (owner-authorized 2026-06-10).**
  The Scorpion anti-maho order (s11.3.5: "secretive group maintained by the
  clan's two shugenja families, the Soshi and the Yogo... operates in the
  shadows and most samurai are not even aware of its existence"). Because
  membership is secret and NOT a school (unlike Kuni Witch-Hunters / Asako
  Inquisitors), it is carried as a hidden flag `is_kuroiban: bool` on
  L5RCharacterData (mirrors `is_kolat_master` / `cult_affiliation`; @export →
  persists with the character save). `simulation/kuroiban_selector.gd`
  (KuroibanSelector pure class) selects members once at world-gen from living
  Scorpion Soshi/Yogo: the existing `KUROIBAN_LEADER` (assigned by
  WorldPopulationGenerator) is always flagged, plus top-anti-maho-lore
  (`Lore: Shadowlands`×2 + `Lore: Theology`) SHUGENJA-school members up to a
  **fixed small total of 6–10** (`dice.roll_die`, leader counts). Wired into
  `WorldBootstrap.bootstrap_world` after bloodspeaker generation. **Behavior =
  "roam silently" (owner choice):** `is_kuroiban` added to `_is_maho_hunter`, so
  Kuroiban get HUNT_MAHO standing and join the roaming-spread pass like
  Kuni/Asako — but the cross-border incident keys off `_is_kuni_witch_hunter`
  (excludes Soshi/Yogo) and the +2k0 PTL detection edge keys off Kuni/Asako
  family (excludes them), so they roam covertly: no diplomatic incident, no
  detection bonus. All roster counts PROVISIONAL (GDD gives no size or selection
  rule). Parse-checked (class registry rebuilt via import scan); no tests per the
  no-test-code policy.
- **s11.3.5 Crab–Scorpion anti-maho information sharing (owner-authorized 2026-06-11).**
  s11.3.5: the Kuroiban "share information and resources with the Kuni." Owner
  chose **mutual** sharing **via the letter pipeline (delayed)**.
  `_process_anti_maho_info_sharing` runs daily after the maho-detection passes:
  it gathers living Kuni (`_is_kuni_witch_hunter`) and Kuroiban (`is_kuroiban`),
  and for each unresolved detection topic (variants `taint_suspected` +
  `blood_evidence`) relays it from whichever order already knows it to the
  members of the other order who don't. `_relay_detection` creates a LetterData
  (sender = a knowing member, recipient = each lacking member, `topic` = the
  detection topic) entering the normal letter pipeline; on delivery
  `deliver_letter` appends the topic to the recipient's `topic_pool` (verified).
  Deduped via `topic_pool` membership + an en-route index of pending undelivered
  letters; no ping-pong (a recipient only learns the topic on delivery, so the
  reverse relay finds the source order already knows it). Dead-guarded.
  ANTI_MAHO_SHARE_DISTANCE = 3 provinces PROVISIONAL (blocked on map adjacency,
  A16). Parse-checked; no tests per the no-test-code policy.
- **s11.3.5 Kuroiban leader tasking (owner-authorized 2026-06-11).** Owner chose
  the leader's tasking to **replace** the autonomous spread when a leader is
  alive. The seasonal roaming pass was refactored: `_process_witch_hunter_self_selection`
  → `_process_anti_maho_roaming` (orchestrator) + `_assign_hunters_to_hotspots`
  (the extracted least-covered distributor, now parameterized by a pre-ordered
  member list and a `source_tag`) + `_gather_roaming_members` (filter: living,
  non-PC, maho-hunter, no real lord-assigned primary). When a living
  `KUROIBAN_LEADER` exists, Kuroiban are gathered, sorted best-expertise-first
  (`Lore: Shadowlands`×2 + `Lore: Theology`), and tasked via
  `_assign_hunters_to_hotspots(..., "kuroiban_leader_tasking")` — best hunters to
  the worst (highest-PTL least-covered) hotspots — and excluded from the general
  spread; if the leader dies they fall back into it. Kuni/Asako always spread
  (behavior unchanged, traced equivalent to the prior verified logic). Handoff
  both directions via `ROAMING_SOURCES` (re-stamps the source on still-hot
  committed primaries). A real lord primary always outranks roaming. The leader
  is tasked like a member (hunts too); tasking is abstract central coordination
  (no per-member comms modeled, same abstraction as the spread). Only caller
  (seasonal, line 1434) updated. Parse-checked; no tests per the no-test-code policy.
- **s11.3.5 Anti-maho leader tasking generalized to all three orders (owner-authorized 2026-06-11).**
  Extended the Kuroiban leader-tasking pattern symmetrically to the Kuni
  Witch-Hunters and Asako Inquisitors. `_process_anti_maho_roaming` now indexes
  the three orders (0=Kuni/WITCH_HUNTER_LEADER, 1=Asako/INQUISITOR_LEADER,
  2=Kuroiban/KUROIBAN_LEADER): it scans for each order's living leader, and every
  order WITH a living leader has its members tasked best-expertise-first to the
  worst hotspots (per-order source tag) and excluded from the general spread;
  orders with NO living leader fall into the spread together (same "replace when
  leader alive" rule the owner chose for the Kuroiban). New helpers
  `_is_asako_inquisitor()` (school "Inquisitor" or INQUISITOR_LEADER role) and
  `_order_of()` (mutually-exclusive order classification, checked
  Kuroiban→Asako→Kuni). `_gather_roaming_members()` reworked from the
  kuroiban_only/exclude_kuroiban flags to an `(led, order_filter)` pair
  (order_filter 0–2 = that order; -2 = spread = unled orders). ROAMING_SOURCES
  grew to four tags (self_selection + three per-order leader tags) so handoff
  re-stamping works when any order's leader dies/revives. Traced equivalent to
  the prior behavior in the no-leader and Kuroiban-only-leader cases; Kuni/Asako
  now get the coordination too. Cross-border incidents (Kuni-only) and the +2k0
  detection edge (Kuni/Asako family) are unaffected — separate systems. Each
  leader hunts like a member. Parse-checked; no tests per the no-test-code policy.
- **Detection loop verified (Design Decision #5).** Confirmed the seasonal casts
  feed the existing detection machinery end to end: Channel 1 — the PTL +1 drives
  the s11.11 crisis topics at PTL 3/6/9 (passive, pre-wired). Channel 2 — the MAHO
  CrimeRecord (location = cast settlement, concealment_tn from the Stealth/Agility
  roll, 90-day evidence window) is consumed by `_process_blood_evidence_discovery`
  (called in advance_day, line ~392) on both EXAMINE_CRIME_SCENE and
  INVESTIGATE_PROVINCE results; a co-located magistrate's province investigation
  rolls Investigation vs the concealment TN and, on success, emits a TIER_3
  SUPERNATURAL "blood magic discovered" topic that propagates to the investigator's
  lord — covered by an end-to-end closure test (cast → record → INVESTIGATE_PROVINCE
  → topic). Channel 3 — caster Taint accrues (ML−1); the Lore: Shadowlands detection
  roll is WIRED at TN (8 − Taint Rank) × 5 (owner-set 2026-06-10). Channel 4 — seasonal
  casts pass `witnesses=[]` (covert), so no direct witnesses, by design. No gaps
  introduced and no fixes needed — the new casts' outputs are consumed correctly.
- **Crab witch-hunter routing verified (s11.11, Decision #5).** Confirmed the
  topic → action chain that turns a maho-tainted province into a Kuni/Asako
  investigation: an active insurgency (a Bloodspeaker MAHO_CULT cell already feeds
  `active_insurgencies`, and PTL ≥ 3 spawns a TAINT_MANIFESTATION insurgency) →
  `OpportunityScanner` ELIMINATE_SHADOWLANDS opportunity (urgency 80) →
  `ObjectiveDecomposer._decompose_eliminate_shadowlands` returns INVESTIGATE_THREAT
  for the province → INVESTIGATE_PROVINCE (objective_alignment 100) → a SHUGENJA
  running it in the tainted province hits `_process_ptl_detection`, rolling
  Lore: Shadowlands (Perception) vs PTL×5 with a **+2 Kuni/Asako family bonus**,
  emitting a "Spiritual corruption detected" SUPERNATURAL topic propagated to the
  lord. 5 routing tests (`test_crab_hunter_routing.gd`): insurgency→opportunity,
  ELIMINATE_SHADOWLANDS→INVESTIGATE_THREAT, Kuni shugenja detects, non-shugenja /
  Lore-less shugenja do not. **Wired now:** lords (strategic-review self-selection)
  and magistrate-shugenja (UPHOLD_LAW idle patrol, INVESTIGATE_THREAT every 7 days)
  reach INVESTIGATE_PROVINCE; the +2 Kuni/Asako detection edge applies. **Still
  blocked (Decision #5, s11.3.5):** dedicated Kuni/Asako/Kuroiban witch-hunter
  *standing* objectives (autonomous hunting without lordship or magistracy) — not
  invented here. **Kuni/Asako bonus confirmed correct (+2k0):** `_process_ptl_detection`
  passes `family_bonus` (=2) into `resolve_skill_check`'s `bonus_rolled` parameter
  (8th positional) with `bonus_kept` defaulting to 0 — two extra unkept dice,
  exactly GDD s11.11's "+2k0". (An earlier note mis-described this as a flat +2;
  retracted after re-reading the call. A clarifying comment was added at the call
  site to prevent the same misread.)

### Systems Added 2026-06-07 (Kolat — deferred executors + network records)
Implemented the Kolat ActionID executors that were stubbed `deferred_system` in
`kolat_executor.gd`, plus the LOCKED network-record data layer (s54.7h/d). Each
executor returns effect flags consumed by `DayOrchestrator._process_kolat_writebacks()`
(topic pool / insurgency list / Honor / network records); ARCHIVE_TOPIC and the
koku/dead-drop handlers are self-contained Pattern B. **Verification note:** GUT
cannot run headlessly here (the `WeaponData` cold-boot class-resolution cascade
fails the whole dependency graph, which also masks type errors in the import
parse-check), so all of this was validated by static review only. Tests written
but not executed in this environment.
- **Tranche A** — ARCHIVE_TOPIC (writes the s54.7h cloud_archive), ANONYMOUS_TIP
  (Tier 4 org tip topic), RESURRECT_TOPIC (Calligraphy+Int vs TN 20, re-injects an
  archived topic as "historical records", −0.5 Honor), SPONSOR_INSURGENCY
  (Commerce+trait vs TN 20; seeds a Ronin Bandit Uprising Str 1/Conceal 8 or +2
  cap 10; failure fires the province investigation topic).
- **Tranche B** — BRIBE_GARRISON_COMMANDER (Commerce+trait vs commander
  Willpower×5; registers a standing bribe on the Coin Master). New
  `_process_kolat_bribes_seasonal`: 5 koku/season upkeep + the −2 under-garrison
  Stability penalty (s11.11) per bribed province, cancelled silently when a
  payment is missed.
- **Tranche C** — DELIVER_SEALED_LETTER (Sincerity Deceit vs TN 10; LetterData via
  the letter pipeline; Tier 4 "courier asking after X" topic on a noticed
  delivery), ROUTE_ANONYMOUS_INTELLIGENCE (Calligraphy vs TN 15; +5 disposition to
  a registered jade asset; Tier 4 traced-document topic on critical failure).
- **Tranche D1/D2** — `simulation/kolat_network.gd` (KolatNetwork pure class): the
  per-Sect network-record schemas from s54.7h (silk/coin/jade/lotus/chrysanthemum/
  steel records, dream_sleeper_registry, cloud_archive) keyed by `Enums.KolatSect`
  (the character-sheet truth — the GDD's "kolat_silk" prose strings are NOT used).
  Registration helpers, capacity cap (6 agents, burned excluded — s54.7d), Jade
  cap 3, silence detection (30 city / 60 remote). `_process_kolat_network_seasonal`:
  per-Master per-agent silence check → Tier 4 concern topic, deduped via a
  `silence_flagged` per-entry guard. cloud_archive reconciled to the s54.7h schema
  (archive_id keys; parties_named / content_summary / original_momentum /
  ic_day_archived + reconstruction extras).
- **Tranche D3** — APPROACH_FOR_RECRUITMENT (Friend-tier +31 disposition gate;
  contested Sincerity vs the target's Willpower; on success sets `kolat_sect`,
  registers the recruit in the Master's Sect record via
  `KolatNetwork.register_recruit`, −0.5 Honor; failure/critical-failure topics;
  never converts dead characters or PCs). This is how networks populate during
  play (no world-gen seeding, per owner ruling).
- **Tranche D4** — ROTATE_DEAD_DROP (Stealth vs TN 10; moves the first compromised
  drop in lotus_network_record to the current settlement). Closes the network
  loop: records are created by recruitment, maintained by the silence pass, and
  consumed here.
- **Owner rulings (2026-06-07):** (1) APPROACH_FOR_RECRUITMENT's GDD roll
  "Willpower + (Gi rank ×2)" is a mistake — personality drives decisions, not
  mechanics — so the Gi modifier is dropped (contest is vs Willpower only).
  (2) RUN_COURIER_ROUTE's TN should scale with conditions like patrols; no formula
  or patrol data exists, so it stays deferred. (3) Hidden Temple `temple_vault_koku`
  stays an abstract treasury (no map settlement designated). (4) No world-gen Silk
  seeding — networks populate via recruitment.
- **GDD note (left unedited — GDD edits require owner permission):** s54.7d line 39 says Silk/Lotus keep no
  network record, but s54.7h defines detailed silk/lotus records. The consolidated
  fields reference (s54.7h) is followed as authoritative.
- **Tranches D5–E2 (2026-06-07, second pass — owner directive "do ALL of it"):**
  the remaining deferred executors, completing **all 29 Kolat ActionIDs**.
  - **D5** — USE_CLOUDS_EYES (Spellcraft + Air vs TN 15; copies 1d3+Raises ambient
    topics from the target settlement's province into known_topics) and
    DISTRIBUTE_INTELLIGENCE (delivers a topic to a registered Silk agent + refreshes
    their last-report; interception layer deferred — no route-compromise model).
  - **D6** — ARRANGE_PROXY_DUEL (Courtier vs TN 20 narrative build → Tier 3
    confrontation topic, −1.0 Honor; sub-step-1 proxy cultivation deferred).
  - **E1** — Hidden Temple designated at world-gen (owner reversed the abstract
    ruling): SettlementData.is_hidden_temple + temple_cloud_archive;
    WorldBootstrap._designate_hidden_temple (deterministic lowest-id mountain
    VILLAGE); KolatNetwork.find_hidden_temple/is_at_hidden_temple. Executors:
    RUN_COURIER_ROUTE (Stealth TN 15 base + patrol hook +0, owner ruling),
    OBSERVE_VIA_EYE (at-temple full-fidelity ambient-topic copy), SECURE_ONI_EYE
    (Investigation+Perception TN 20), CONDUCT_PERIMETER_PATROL (Stealth TN 15;
    failure → Tier 4 topic), SUBMIT_KOLAT_REPORT (at-temple; archives into the
    Temple's master Cloud archive — sidesteps cross-Master identity routing).
  - **E2** — TRANSMIT_VIA_TEAR + the Tear network. holds_tear field;
    KolatMasterSelector stamps holds_tear + populates Tiger's
    kolat_master_identities. **Phase-2 cascade (s54.7d):** the Kolat objective slot
    now enters resolve_goal at priority 3 (before primary) and priority 1-2 (after
    primary, before standing); a no-op for non-Kolat characters. Tear writeback
    installs the directive as the recipient's Kolat objective (Tiger routes by Sect,
    others route to Tiger). _inject_kolat_objective_flags drives the Phase-3 unlock
    for field agents.
  - **Owner rulings (second pass):** Hidden Temple designated (not abstract); courier
    TN base 15 + patrol hook; Gi-rank dropped from recruitment (first pass).
  - **E3 — decomposition metadata population.** `_build_kolat_metadata` now fills
    real executor inputs per ActionID from need fields + the Master's own records
    using the LOCKED s54.7c selection criteria (highest-leverage archive for
    RESURRECT, stalest Silk agent for DISTRIBUTE, co-located weapon-4+ proxy for
    ARRANGE_PROXY_DUEL, tip subject/org for ANONYMOUS_TIP, directive fields +
    recipient_sect for TRANSMIT). Combined with the standing-mandate assignment
    (Tranche 12) and the Phase-2 cascade (E2), Masters now autonomously pursue
    their Sect mandate and the executors receive real inputs end to end.
  - **E4 — self-initiated NeedType generation (s54.7d/e).**
    `simulation/kolat_opportunity_scanner.gd` (KolatOpportunityScanner pure class)
    produces the opportunistic Kolat objectives a Master pursues beyond the standing
    Sect mandate, with LOCKED trigger conditions: SECURE_DEAD_DROP_NETWORK (Lotus
    with a compromised drop — secured before any other Lotus work), CONDITION_SLEEPER
    (Dream below its `world_start_sleepers` target — picks the co-located non-Kolat
    candidate with the fewest required sessions = lowest Willpower), RECRUIT_KOLAT_AGENT
    (agent-network Sect below its capacity cap — Jade 3, others 6 — picks the
    highest-disposition co-located non-Kolat candidate at Friend tier +31, matching
    the APPROACH_FOR_RECRUITMENT gate). `should_clear()` gives self-initiated
    completion/recall: a self-selected slot is retired when its trigger lapses
    (drop secured / sleeper made / recruit converted / candidate dead / at capacity);
    Tiger directives (a different `source`) are never disturbed. Wired into
    DayOrchestrator `_assign_kolat_opportunistic_objectives()` (daily, after the
    standing assignment, before `_inject_kolat_objective_flags`): fills the Kolat
    objective slot at priority 2 (precedes standing, yields to a primary or Tiger
    directive). The slot's `target_npc_id` flows through `_passthrough` → the need →
    `_build_kolat_metadata` (E3) → the executor end to end, so Masters now grow
    their networks and create sleepers autonomously. 16 tests in
    `tests/test_kolat_opportunity_scanner.gd`.
  - **E5 — Tiger Stage-5 damage-assessment recall (s54.7).** When a Kolat Master
    is eliminated, `DayOrchestrator._process_kolat_master_death_recall()` (run at
    both death-processing sites before `death_events.clear()`) fires the recall
    sweep: a living Tiger (the routing node) issues recall directives through the
    Kolat channels, so every field agent who had contact with the compromised
    Master halts their Kolat objective and treats it as abandoned — their
    `kolat_objective` slot is cleared. `KolatNetwork.collect_field_agent_ids()`
    enumerates the dead Master's own Sect-record agents. A living Tiger is required
    (if Tiger itself is the dead Master with no successor yet seated, no recall
    fires — the organisation is briefly blind, matching the GDD degraded state).
    3 tests. The operational/elimination directive composition (Stages 1–4:
    Broken-Master surveillance detection, Tiger threat assessment, Lotus
    elimination contracts) remains blocked — it needs the
    Master-surveillance/investigation-detection layer and the GDD's "low/medium/
    high threat" thresholds, which are not numerically specified (cannot invent).
- **Still deferred (29 executors + metadata + self-init + Stage-5 recall done) —
  the remaining generation channels and a few data-blocked inputs:** Chrysanthemum
  shallow-IntelDB / winter-court scanner; Tiger operational/elimination directive
  composition (Stages 1–4, blocked on the surveillance-detection layer + unspecified
  threat thresholds); UNDERREPORT_KOKU amount (domain income not in context);
  ARCHIVE_TOPIC / SUBMIT_KOLAT_REPORT topic object (context carries topic IDs, not
  TopicData); OBSERVE_VIA_EYE contention + all-AP cost; SECURE two-failure
  auto-report; CONDUCT_PERIMETER_PATROL within-3-provinces range + cover identity;
  courier patrol-TN scaling; DISTRIBUTE_INTELLIGENCE route-compromise interception;
  the Conclave + win-condition orchestrator passes (KolatSecrecy data layer exists).
  These need the surveillance/strategic-review integration, IntelDB, map-distance
  data, or action-log state — none buildable without inventing.

### Systems Added 2026-06-11 (Kaiu Wall — Phase 2: Command roster, owner-authorized)
- **s2.4 lines 406-414 — the standing Wall command roster stationed at the Towers.**
  Phase 1 created the 12 Towers but left them unmanned (SI slowly eroded with no one
  to FORTIFY). Phase 2 generates the GDD command hierarchy at world-gen and stations
  it at the Towers. `WorldPopulationGenerator._generate_wall_characters()` rewritten
  (was a 4× `WALL_SEGMENT_COMMANDER` + 1 Hiruma Scout Commander placeholder, not tied
  to any tower): now creates **2 Shireikan** (Wall Commanders — Southern oversees
  Towers 1-6 seated at Tower 3, Northern oversees 7-12 seated at Tower 10;
  `operational_superior_id = -1`, `lord_id = Crab Champion` per s2.4 line 414),
  **12 Taisa** (Tower Commanders, one per tower, family Hida, `operational_superior_id`
  = their segment's Shireikan, stationed at their tower), and **per-tower 1 Kaiu
  Engineer + 1 Kuni Shugenja** (tower staff, `operational_superior_id` = their Tower
  Commander). The Hiruma Scout Commander is preserved (reports to the Crab
  Rikugunshokan as before). No Wall Rikugunshokan is created — GDD line 409 makes the
  Wall Supreme Commander situational/not-at-start; the existing Crab generic
  Rikugunshokan stays the army commander and the two Shireikan answer to the Champion
  directly. **Owner decisions (2026-06-11):** Tower Commanders use the existing TAISA
  position type (GDD-match, `military_rank TAISA`, insight 3, status 3.5) — the
  pre-existing mismatched `WALL_SEGMENT_COMMANDER` (mil_rank CHUI) is left untouched;
  new **SHIREIKAN** position type added to RoleRegistry mirroring TAISA's placements
  (insight 4 per s52a "Wall Cmdr", **status 4.5** owner-set, `military_rank SHIREIKAN`);
  Engineer + Kuni per tower; Shireikan seated at Towers 3/10. **PROVISIONAL** (s52a
  world-init category): wall staff insight rank 3 (Engineer needs 3+ to seal a breach,
  s2.4.16; Kuni needs solid Lore: Shadowlands) and status 2.0 (tower samurai, not
  lords). **Why this makes towers self-sustaining:** a stationed Kaiu Engineer is
  co-located at a Tower → `_set_wall_tower_context_flags` gives AT_WALL_TOWER context →
  the s57.41 MAINTAIN_FORTIFICATION standing fires when any Tower SI < 7 → FORTIFY
  restores SI. The Phase 1 slow-decay gap is closed: Towers now oscillate in the
  ~6-10 SI band instead of eroding to 0. **Schema/wiring:** new
  `SettlementData.wall_tower_number: int = -1` (set by `_create_wall_towers`,
  persists; drives the 1-6 / 7-12 segment split); `_generate_wall_characters` signature
  changed to `(next_id, dice, settlements, crab_champion_id, crab_rikugunshokan_id)`,
  call site passes `settlements` + `clan_champions["Crab"]`; wall NPCs set
  `physical_location` at generation so `_assign_physical_locations` skips them (stays at
  the Tower). `operational_superior_id` set per s2.4 line 414 (the GDD explicitly
  mandates this cross-cutting field for the Wall hierarchy). Verified: Shireikan
  status 4.5 < the 5.0 `is_lord` gate, so they remain pure military commanders (not
  lords); `_get_school_for_position(SHIREIKAN)` resolves to a Hida bushi school
  (SHIREIKAN added to BUSHI_POSITION_TYPES); the ~39 new Crab wall NPCs count toward
  the Crab RANK_DISTRIBUTION targets so the rank-fill backfills fewer (no population
  bloat). Two obsolete wall tests updated to the new signature; the
  segment-commander-count test removed (behavior gone). Parse-checked (4 production
  files + the test file); no new tests per the no-test-code policy. DEFERRED to
  Phase 3: unit-type garrison companies (replacing abstract `garrison_pu`) + real
  horde-combat attrition + re-tuning garrison/SI/jade against a live threat.

### Systems Added 2026-06-12 (Kaiu Wall — Kuni province purification, s2.4.17)
- **s2.4.17 / Taisa AI ninth decision — the stationed Kuni now cleanses the wall province.**
  Phase 2 stations a Kuni Shugenja at every Tower; this routes them to actually cast
  PURIFY_TAINTED_GROUND. The full purification stack was already built and wired into the
  seasonal pass — PURIFY_TAINTED_GROUND executor (TN 15 + PTL×5, −0.5 PTL + −0.25/Raise),
  the Kuni Ward by rank (R1 −0.1/2s … R5 −0.3/6s) with the overwrite rule, adjacent bleed
  (s2.4.3 `compute_adjacent_bleed`), and degraded-tower PTL — only the routing was missing.
  Two changes: (1) added `PURIFY_TAINTED_GROUND` to the AT_WALL_TOWER context list (a Kuni
  at a Tower is in the wall province and may purify it); (2) `_assign_kuni_purification_standing_objectives()`
  (DayOrchestrator, daily, beside the Taisa-sortie pass) gives a Kuni Shugenja stationed at a
  Tower a `MANAGE_TAINT` standing (target = the tower's province) when province PTL exceeds 1.0
  (priority 1 above the s2.4.17 urgent threshold 3.0, else 2), and clears it when PTL falls back.
  `MANAGE_TAINT` passes through the decomposer → objective_alignment 95 → PURIFY_TAINTED_GROUND;
  `target_province_id` flows through `_passthrough` into the executor. Self-regulating: each cast
  applies −0.5 PTL immediately, so once the ground is clean (PTL ≤ 1.0) the standing clears; the
  Kuni Ward then holds the bleed down. Kuni Shugenja grants Lore: Shadowlands (rank-2 boosted),
  so the roll is real, not a no-op. Dead-guarded; only Kuni Shugenja at a Tower; only touches its
  own `MANAGE_TAINT` standing slot (lord directive takes precedence). Threshold values (1.0/3.0)
  are GDD-locked (s2.4.17). Parse-checked; no tests per the no-test-code policy. With the engineer
  (structural / FORTIFY), the Taisa (sortie / SS), and now the Kuni (spiritual / PTL), three of the
  Wall's four family roles are self-driving at the Tower (the Hida garrison itself is Phase 3).

### Topic/Information Propagation Connectivity Sweep (2026-06-13)
Produced-vs-consumed sweep of the topic-momentum / information system (s16). **Two
unbounded-growth leaks found and fixed; one deferred (needs a GDD resolution condition).**
- **Tier-4 topics never purged after decay. FIXED.** `process_daily_tick` appended
  decayed Tier-4 topics to `expired_topic_ids` but never set `topic.resolved`, and the
  orchestrator never consumed `expired_topic_ids` — so `_remove_resolved_topics` (which
  removes only `resolved == true`) never purged them. Every gossip/minor topic that
  decayed to momentum 0 lingered in `active_topics` forever as a zombie, re-iterated each
  tick by `process_daily_tick` and every topic consumer. Fix: `process_daily_tick` now
  calls `resolve_topic(topic)` when `is_topic_expired`. (The changelog had claimed this
  was already done — it wasn't.)
- **Insurgency crisis topics never resolved on defeat. FIXED.** Tier 1-3 crisis topics
  never decay (`advance_crisis_momentum` only increases; `is_topic_expired` is Tier-4-only),
  so they leak unless their crisis end resolves them. `_process_insurgencies` cleared the
  province `active_crisis_id` on suppression but never resolved the topic → a defeated
  insurgency's Tier 1-3 topic lingered as a phantom active crisis (growing momentum, still
  broadcast to NPCs). Fix: `_process_insurgencies` returns `resolved_crisis_ids`; the caller
  resolves matching `active_topics` by `crisis_id`. Famine recovery already resolved its
  topic (line ~3469); this brings insurgency/taint/bloodspeaker crises to parity.
- **Shadowlands incursion crisis never resolved. FIXED (owner decision 2026-06-14).**
  The `shadowlands_incursion` Tier-1 topic + `crisis_type`/`active_crisis_id` are set on a
  wall breach (SI=0 + DEFENDER_OVERRUN) but were never cleared anywhere (the two
  `active_crisis_id = -1` sites were famine + insurgency only), so a breached province stayed
  in permanent crisis with a leaking Tier-1 topic. The GDD is silent on the crisis-resolution
  threshold, so the owner chose: **the incursion clears once the breached province's wall is
  resealed — `wall_si` restored above 0** (GDD s2.4: SEAL_WALL_BREACH restores SI; the breach
  was set at SI=0). `_process_horde_assaults` now runs a resolution pass each tick (it runs
  unconditionally) before the assault loop: a province stays breached while ANY of its
  WALL_TOWER settlements is at `wall_si <= 0`; once all are resealed, it clears
  `active_crisis_id`/`crisis_type` and resolves the matching Tier-1 topic (by `crisis_id`),
  which `_remove_resolved_topics` then purges. Placed before the breach loop so a fresh
  breach the same tick re-fires the crisis. Runtime-verified (SI=0 → persists; SI>0 →
  cleared + topic resolved).

### Resource/Economy Tick Connectivity Sweep (2026-06-13)
Produced-vs-consumed sweep of the seasonal resource tick (s4.3). **One real
computed-but-not-published bug found and fixed; everything else connected.**
- **Starvation stage never reached the NPC engine. FIXED.** `ResourceTick`'s
  seasonal pass computes the granular starvation stage (`resolve_starvation_transition`:
  CLEAR/SHORTAGE/HUNGER/FAMINE, s4.3.6) and persists the state machine in `season_meta`,
  but `build_province_statuses_from_data` hardcoded `ps.starvation_stage = SHORTAGE`
  only when `pd.crisis_type == "famine"` (which fires at HUNGER+ onset). So early-SHORTAGE
  provinces reported CLEAR (NPCs ignored them) and HUNGER/FAMINE flattened to SHORTAGE —
  the sole consumer (`_extract_starving_province_ids`, > CLEAR) under-detected and
  under-weighted starvation in war-readiness/feasibility decisions. Fix: `ProvinceData`
  gains `starvation_stage` (@export, persisted); the tick publishes `prov.starvation_stage`
  each season; `build_province_statuses_from_data` reads it. Runtime-verified.
- **Otherwise clean:** all tick field mutations are applied to the data model
  (rice/koku/iron/arms/population/stability all mutated, not just computed); the
  under-garrison penalties (rice drain, stability, koku ×0.8 malus, trade drain, s4.3.11)
  are applied (`_process_koku_generation` / `_process_trade_route_koku` consume the
  `_garrison` dict); worship maluses (rice/pop/koku via the tick, stability via
  `_apply_worship_stability_maluses`, s4.3.21) are applied; `season_meta` persists across
  seasons + restart (WorldStateData field, saved by WorldStateSaver), so the starvation
  state machine escalates/recovers correctly. ProvinceStatus is fully populated (16/16
  engine-read fields set) after the starvation fix.

### NPC Decision Pipeline — Full Connectivity Review (2026-06-13)
End-to-end audit of the NPC decision pipeline (build_context → resolve_goal →
generate_options → filters → score_all → select_action → execute → reactive path).
**Every connectivity bug found was in the Phase 2→3 reachability layer; all fixed this
session. Every other stage audited clean.** Method: programmatic diffs (reads vs writes,
scored-vs-reachable, injected-vs-handled) + targeted headless probes.

**Bugs found and fixed this session (NeedType / reachability):**
- **BEGIN_TRAVEL in no context list — NPCs could not initiate travel at all.** The
  action every travel objective resolves to was absent from every context list (only
  CHANGE_DESTINATION existed, TRAVELING-only). Confirmed via probe: a stationary NPC with
  a TRAVEL_TO need → survivors `[DO_NOTHING]`. Every travel NeedType (TRAVEL_TO,
  ATTEND_COURT, SEEK_MAGISTRATE, LOCATE_CHARACTER, FIND_NEW_LORD, …) and all decomposer
  TRAVEL_TO sub-needs (HUNT_MAHO roaming, UPHOLD_LAW jurisdiction travel, witness→magistrate,
  musha-shugyo return, commitment proxies) collapsed to DO_NOTHING — autonomous NPCs never
  relocated. FIXED: added BEGIN_TRAVEL to all 9 non-TRAVELING context branches (owner-approved
  "every context"). Allowlist gates it to travel NeedTypes (verified RAISE_DISPOSITION does
  not surface it).
- **Arrived-at-target guard.** `_apply_arrived_travel_filter` (Phase 4) drops BEGIN_TRAVEL
  once the NPC is at the need's target so the at-destination action wins (or REST) instead
  of a no-op "already_there" travel. Wired into both run() and the sleeper-override path.
- **Commitment-proxy dispatch (VISIT_PROMISE / MEETING_ARRANGEMENT) scored 0.** Proxies
  used need_types VISIT_NPC / ATTEND_MEETING, in neither the scoring table nor the decomposer
  → proxy RESTed instead of travelling. FIXED: routed to TRAVEL_TO (unblocked by the travel fix).
- **Bribery/extortion reactive menus never generated.** SUPPRESS_INVESTIGATION (bribery_eval)
  and EXTORT_ACCUSED (extortion_opportunity) reactive needs had no generate_options override
  (unlike RESPOND_TO_SEPPUKU), so BRIBE_WITNESS / INTIMIDATE_WITNESS / KILL_WITNESS /
  FLEE_JURISDICTION / EXTORT_ACCUSED (in no context list) were never generated → crime
  responses collapsed to DO_NOTHING. FIXED: added the two need.source overrides; personality
  filter gates the aggressive options.
- **Dead refs removed:** `make_reassess_need()` (never called), `RAISE_ARMY` classification
  entries (never emitted).

**Stages audited CLEAN (no changes needed):**
- **Scoring tables (8/8):** objective_alignment, personality_lean, competence_table,
  disposition_tiers, urgency_rules, topic_position_alignment, action_skill_map, filter_data
  (bushido/shourido) — all loaded by WorldStateData and all invoked live by score_all.
- **ContextSnapshot fields (96/96):** all populated in build_context (incl. `.append`/dict
  forms); every world_state key the engine reads is written somewhere (festival flags via
  `ws.merge(g_festival)` at the per-character injection; `province_statuses` via the
  `build_province_statuses_from_data` fallback; naval/court keys injected without prefix).
- **Executor coverage:** all 171 selectable actions (context lists ∪ Kolat pool ∪ overrides)
  have a handler reference in ActionExecutor — zero silent no-ops.
- **Reverse reachability:** the objective_alignment scored-action diff returns zero UNKNOWN —
  every scored ActionID is reachable (context/Kolat/letter-pass/reactive override) or a
  documented forward-wired/blocked action (s11.7a sub-tile, s11.9 coordinate, Kolat-no-executor,
  reactive non-AP-loop, GDD-blocked SEEK_*/tattoo).
- **Reactive event coverage:** every type injected into a character's `pending_events` has a
  handler — 5 `reactive_type` events (ACCEPT_TRAINING, CONTRACT_OFFERED, COURT_INVITATION,
  DUEL_CHALLENGE_RECEIVED, FAVOR_REQUESTED) route to ReactiveDecisions match arms; the `type`
  events (bribery_eval, extortion_opportunity, provocation, seppuku_offered,
  witness_report_motivated, + performance/tend-wounded handlers) route to
  `_decompose_reactive_event`; `need_type` events (HONOR_COMMITMENT, RESPOND_TO_EDICT) are
  valid NeedTypes that decompose normally.
- **Effect-key consumption:** diffed the 409 effect keys ActionExecutor emits against
  EffectApplicator + day_orchestrator + wave_resolver consumers. Only 3 undocumented-unconsumed
  effect-like keys, all benign: `effective_total` (craft roll total, informational),
  `koku_amount` (TRANSFER_KOKU result echo — the transfer is pre-applied Pattern B,
  `character.koku -= amount; recipient.koku += amount`), `performance_applied` (Pattern B flag).
  No dropped effects.

**Runtime-verified (headless drivers):**
- **Full travel chain executes end-to-end.** `run()` chooses BEGIN_TRAVEL carrying
  target_settlement_id (verified through build_context → resolve_goal → _passthrough →
  generate_options); the decision dict propagates target_settlement_id; the wave resolver's
  `_execute_decision` reconstructs the action; `ActionExecutor.execute` fires
  `TravelSystem.begin_travel` (started=true, origin→destination, days=1); `process_travel_tick`
  arrives the character at the destination. (NPCDecisionEngine.execute_action only spends
  AP/orders and returns the decision — actual effects run via ActionExecutor in the wave
  resolver, which is why a bare `run()` shows started=false.)
- **Arrived-target guard:** an arrived TRAVEL_TO resolves to DO_NOTHING (BEGIN_TRAVEL filtered);
  an arrived ATTEND_COURT resolves to a court action (CHARM/DELIVER_GIFT), not no-op travel.
- **Bribery/extortion menus generate:** SUPPRESS_INVESTIGATION (bribery_eval) surfaces all five
  suppression actions; EXTORT_ACCUSED (extortion_opportunity) surfaces EXTORT_ACCUSED.
- **Wave-resolver integration path** (the production execution step, not a hand-built action):
  `NPCDecisionEngine.run()` → decision dict → `NPCWaveResolver._execute_decision` (reconstructs
  the ScoredAction from the decision, target_settlement_id intact) → `ActionExecutor.execute`
  → `TravelSystem.begin_travel`. Verified for a TRAVEL_TO primary (decision BEGIN_TRAVEL/target
  200 → travel_started → arrives at 200 after one tick) AND an ATTEND_COURT primary not at the
  court (decision BEGIN_TRAVEL → traveling toward the court settlement). Both relocate through
  the real orchestration step — the world-freezing travel bug is resolved at the integration level.
- **Reactive crime path through `run()`:** a character with a `bribery_eval` pending event
  (low-honor/KETSUI accused under investigation) resolves to need SUPPRESS_INVESTIGATION and
  decision `BRIBE_WITNESS` — a witness-tampering action that was previously unreachable (the
  reactive crime response used to collapse to DO_NOTHING). A `extortion_opportunity` event
  (corrupt magistrate) resolves to decision `EXTORT_ACCUSED`. Both confirm the new
  generate_options override fires inside the full reactive `run()` flow (resolve_goal →
  override → personality filter → scoring → execute). An honourable NPC's personality filter
  would block the aggressive options → DO_NOTHING, which is the intended gating.

**Objective-decomposer / objective-producer trees audited CLEAN:**
- All 37 distinct sub-needs the decomposers emit (objective_decomposer, musha_shugyo,
  monk_objective) are valid — each is in objective_alignment or has its own decompose case.
- Both `_make_need("TRAVEL_TO")` emission sites (HUNT_MAHO, UPHOLD_LAW idle) are inside
  at-target guards (`location_id.begins_with(target)`), so they emit travel only when away and
  passthrough to the local action on arrival. All other travel-class needs (ATTEND_COURT,
  SEEK_MAGISTRATE, …) rely on the global `_apply_arrived_travel_filter`.
- All 14 high-level primary objectives the OpportunityScanner / strategic_review / decomposer
  produce (MILITARY_DOMINANCE, MAXIMIZE_PROSPERITY, MAINTAIN_PEACE, EXPAND_TERRITORY,
  DEFEND_TERRITORY, CONTROL_TRADE, BUILD_STRONGEST_FORCE, ELIMINATE_SHADOWLANDS, HONOR_ANCESTORS,
  SEEK_VENGEANCE, STRENGTHEN_WALL, ADVANCE_FAMILY, ACCUMULATE_LEVERAGE, BREAK_ALLIANCE) route to
  a decompose tree (one of 7 dispatch arrays — POLITICAL/ECONOMIC/PERSONAL/MILITARY/
  INVESTIGATION/INFRASTRUCTURE/GOVERNANCE — or PrimaryObjectiveDecomposer's 13-tree match),
  decomposing to reachable sub-needs rather than passthrough.
- Every `objective_type` the OpportunityScanner can emit routes (dispatch array / primary /
  alignment). One orphan: `PROTECT_TERRITORY` exists only as a `STANDING_OBJECTIVE_DOMAIN`
  classification key, never emitted as an objective — benign dead map entry (forward-wired),
  not a REST path.

**Reactive-decision OUTPUT side audited CLEAN:** the 5 reactive handlers emit 10 distinct
`action` responses; 8 have orchestrator writeback consumers (ACCEPT_DUEL/DECLINE_DUEL,
HONOR_FAVOR/DECLINE_FAVOR, ATTEND_COURT, ACCEPT_TRAINING, ACCEPT_CONTRACT/DECLINE_CONTRACT).
The 2 without consumers (DECLINE_INVITATION, DECLINE_TRAINING) are intentional no-ops — a
decline is the *absence* of the accept-path action and carries no separate consequence (a
court decline leaves the COURT_ATTENDANCE commitment to break later via s55.31; a training
decline simply yields no progress). Both the input side (every injected event type has a
handler) and the output side (every consequential response has a consumer) are wired.

### Known Code Issues (found and fixed 2026-06-12, headless wall smoke test)
- **`school_name` vestigial field — 8 production reads were dead. FIXED.** A headless smoke
  run of the live Wall loop (fresh-bootstrap driver, since retired) surfaced this. `L5RCharacterData`
  declares BOTH `school` and `school_name`; `WorldGenerator.generate_character` sets only `c.school`,
  and **`school_name` is never written anywhere** — it is always `""`. Eight sites read the dead
  field, so each silently misbehaved: `day_orchestrator._is_asako_inquisitor` (8123) and
  `_is_kuni_witch_hunter` (8266) always returned false → **the entire s11.3.5 maho-hunter system
  (HUNT_MAHO standing, roaming, cross-border incidents, Kuroiban leader tasking) was dead**;
  `kolat_master_selector._is_witch_hunter` (430) never excluded witch-hunters from Kolat draws;
  `npc_advancement` (546 bushi, 556 monk) gated kata/kiho XP claim on `not school_name.is_empty()`
  (always false) → **NPC kata AND kiho learning never ran**; `kata_system` (388) and `kiho_system`
  (182) eligibility treated everyone as school-less; `ascii_map_combat_orchestrator` (2059) computed
  `is_samurai` as always-false (companion samurai-avoidance). All 8 migrated to the canonical
  `.school` (44 existing refs, always populated). `school_name` now has zero production readers —
  left declared for save compat; removal is a future cleanup. Parse-checked all 5 files. NOTE:
  this re-activates dormant code paths (witch-hunter roaming, NPC kata/kiho learning) that have
  never actually executed — worth watching in the first live run. The Kaiu/Kuni *standing* passes
  (`_assign_kaiu_engineer_standing_objectives`, `_assign_kuni_purification_standing_objectives`)
  already read `.school` correctly, so FORTIFY/purify were unaffected.
- **`school_name` straggler + impact re-assessed (verification run, 2026-06-12).**
  A focused no-bootstrap verification of the re-activated paths caught a missed 9th
  read: `_is_maho_hunter` (day_orchestrator:8011) still used `school_name`. Migrated
  to `.school`. Harmless in practice (see below) but the same dead-field class.
  Verification findings: (1) **NPC kata/kiho learning was the genuinely-dead path** and
  is now live — confirmed end-to-end: an Akodo Bushi (80 XP) selects + learns
  `Strength of the Lion` (katas 0→1), a Togashi Tattooed Order monk (80 XP) selects +
  learns `Channel the Fire Dragon` (kiho 0→1). Before the fix the `school_name` gate
  was always-false → kata/kiho were NEVER claimed by any NPC. (2) The maho-hunter
  predicate migration was OVERSTATED as "entirely dead": `_is_kuni_witch_hunter` /
  `_is_asako_inquisitor` / `_is_maho_hunter` each have a non-school branch (leader
  role_position / `is_kuroiban` flag) that always worked, AND no `SCHOOL_DATA` key
  contains "Witch-Hunter"/"Inquisitor", so the school-string branch matches nothing in
  a live world either before OR after the fix. Verified the live roster IS detected
  (WITCH_HUNTER_LEADER→order 0, INQUISITOR_LEADER→1, is_kuroiban→2, all get HUNT_MAHO
  standing) with no false positive on a regular Akodo Bushi. LIMITATION (world-gen
  seeding gap, owner decision — do NOT invent): rank-and-file Kuni Witch-Hunters /
  Asako Inquisitors are never created (no school string, no flag), so the Kuni and
  Asako orders are effectively single-leader; only the Kuroiban have a real membership.
  Adding a "Kuni Witch-Hunter" SCHOOL_DATA school or tagging some Kuni Shugenja with
  the school string would populate them — the predicates are already ready.
- **Smoke-test observations (live Wall, fresh bootstrap, 3806 chars).** Validated at runtime:
  12 Towers spawn with the Phase-1 init (SI 10, garrison 3, jade 5, SS 3; Ishibei 1-5 / Ishigaki
  6-9 / Yoake 10-12). Phase-2 roster stationed (Shireikan 2, Taisa 12, Kuni 12, Kaiu 12). Horde
  gen + sortie scaling correct (Jigoku/Undead Str-2 = 9 companies, Maho-tsukai present; sortie
  SS3→1 / SS6→2 / SS9→3+ogre / SS12→4+ogre). Assault casualties scale with degrading SI (SI10→0
  health, SI6→2, SI3→77, SI0→86; garrison-0 → OVERRUN). Redeployment moved +2 PU from the
  highest-surplus Tower to a drained one (30% cap). **TUNING FINDING — RESOLVED 2026-06-12.**
  The smoke showed every *defended* assault resolving to PUSHED_BACK (SI −3) regardless of
  garrison strength, because `_map_battle_outcome` keyed on the `victor` string and routing-immune
  Bakemono fight to a "draw". Fixed by keying the defender-victory SI tier on **garrison casualty
  fraction** (the GDD's own "garrison badly damaged" = −3 / "pristine tower barely notices" = −1
  signal): garrison loss <10% → Decisive (−1), 10–33% → Contested (−2), >33% surviving → Narrow
  (−3); garrison destroyed/routed → Breach (−4). Thresholds owner-set ("Light" scheme, 2026-06-12)
  as `HordeSystem.ASSAULT_DECISIVE_CASUALTY_FRAC`/`ASSAULT_CONTESTED_CASUALTY_FRAC`. Now
  self-correcting and garrison-sensitive — validated: SI10/SI6 → −1, SI3/SI0 → −2, garrison-0 →
  breach. DECISIVE/CONTESTED are now reachable (were dead).

### Systems Added 2026-06-12 (Kaiu Wall — Phase 3: live horde combat, owner-authorized PROVISIONAL)
- **Horde composition un-stubbed + sortie/assault combat made live + Shireikan redeployment.**
  The owner authorized GDD-consistent PROVISIONAL baseline compositions (the one value s2.4
  leaves undefined), unblocking the whole Phase-3 combat chain. Four changes:
  1. **HordeSystem generators un-stubbed.** `_generate_jigoku_companies`, `_generate_undead_companies`,
     `_generate_sortie_horde_companies` now return real Companies built from the LOCKED unit roster
     (s2.4.7). PROVISIONAL baselines (`JIGOKU_BASELINE` 4 Bakemono Warrior + 1 Archers + 2 Ogre;
     `UNDEAD_BASELINE` 3 Zombie + 2 Skeleton + 1 Revenant + **1 Maho-tsukai [GDD-LOCKED: one per
     legion]**) + the LOCKED +1 Company/Strength bonus (drawn cyclically from each type's pool).
     Sortie horde scales with SS (~1 Company/3 SS, an Ogre at SS High 9+). All counts marked
     PROVISIONAL, tunable after playtest.
  2. **Sortie commitment floor fix.** `committed_pu = int(garrison_pu * force_pct)` rounded a
     Small sortie (20% of the Phase-1 garrison_pu=3) to **0 companies → empty fight → no SS
     reduction**, making the D2 sortie a no-op. Companies are indivisible: clamped to
     `clampi(int(garrison_pu*force_pct), 1, garrison_pu)`. Sorties now commit ≥1 Company → real
     combat → SS reduction + jade consumption + garrison casualties (when ≥153 health lost).
  3. **Discrete horde assault combat wired.** The horde roll (50%/2 seasons) already formed a
     horde + Tier-3 sighting topic, and `_process_horde_assaults` already applied the SI hit +
     breach→`shadowlands_incursion` crisis (Tier-1 topic, `active_crisis_id`) — but nothing ran
     the assault *combat*. `HordeSystem.resolve_horde_assault_combat()` (combat-only, no SI hit
     — `_process_horde_assaults` owns that, so calling the existing `resolve_horde_assault` would
     double-hit) + `DayOrchestrator._resolve_horde_assault_combat()` resolve the garrison-vs-horde
     battle on formation (garrison defends from the Tower with the SI fortification bonus +
     wall-breaker), set `assault_resolved`+`battle_outcome`, apply garrison PU casualties; the SI
     hit + breach apply next tick. Undefended Tower (garrison 0) → automatic DEFENDER_OVERRUN.
     The combat helper picks the same province→Tower as `_process_horde_assaults` (last tower
     wins) so casualties and the SI hit land on the same Tower.
  4. **Shireikan Troop Redeployment (s2.4.13 D2).** `_process_shireikan_troop_redeployment()`
     (seasonal): each Shireikan reinforces below-minimum Towers in their half (Southern 1-6 /
     Northern 7-12) by pulling garrison from the highest-surplus safe Tower. GDD-LOCKED values:
     30% transfer cap per order, never from an SS-High or SI<6 Tower, source/target stay ≥ minimum
     (floored at 1 Company for indivisibility). Target = the below-minimum shortage Tower (triage
     P3; the horde-incoming P1/P2 need scout lead time that doesn't exist yet). Direct garrison_pu
     transfer (abstract PU, like the Ashigaru flow).
  Live loop now: Taisa sortie → casualties → garrison attrition; horde roll → assault → SI hit /
  breach / incursion; Shireikan redeploys to cover shortages; Kuni purifies; engineer FORTIFYs.
  All four parse-checked; no tests per the no-test-code policy. TUNING (playtest): baseline
  compositions and SS/sortie scaling are PROVISIONAL; with Phase-1 garrison_pu=3 a single horde
  assault can overrun a Tower — garrison sizing and horde scale will need joint tuning against a
  live run. **Repeat-targeting weight LOCKED at 2×** (s2.4.4 "higher probability", owner-approved
  2026-06-12): `HordeSystem.REPEAT_TARGET_WEIGHT` — the last-targeted tower's province is added
  REPEAT_TARGET_WEIGHT-1 extra times to the selection pool. The scout-detection chance remains
  undefined (no-warning) — it has no scout-deployment mechanic to attach to until the scout
  system exists; not invented. The B–E proposed values (horde baseline compositions, sortie
  scaling, garrison_pu 3→5) were presented but NOT approved — they stay PROVISIONAL.

### Taisa AI loop (s2.4.11) — stopping point (2026-06-12, since unblocked under provisional authorization)
The autonomous build halted at the first **undefined value**, exactly where the GDD stops
specifying. **Built (fully-defined):** D1 SI maintenance (engineer FORTIFY), D2 Sortie timing
(Taisa, via the LOCKED `validate_sortie`), and the s2.4.17 Kuni province-purification half of D7.
**Blocked on undefined values / unbuilt dependencies — do NOT implement without owner input or
the missing spec:**
- **Horde composition counts — "pending GDD spec".** `HordeSystem._generate_jigoku_companies`,
  `_generate_undead_companies`, and `_generate_sortie_horde_companies` all `return []`. The horde
  roll fires (50%/2 seasons) but generates an EMPTY horde, so: horde assaults do nothing, and
  **sortie combat resolves against an empty horde → 0 casualties → `garrison_pu` never drops from
  sorties.** D2 still correctly applies SS reduction (defender auto-wins the empty fight), but no
  attrition occurs until horde composition is defined. This single gap cascades: it blocks real
  garrison attrition, the whole horde-assault crisis machinery, and any decision keyed on "horde
  incoming" (Shireikan triage P1/P2, scout detection).
- **Shireikan reserve Koku/jade pools — "dynamic … not a fixed formula" (s2.4.13 D3).** Explicitly
  undefined; the Champion→Shireikan koku allocation amount is also unspecified. Blocks D4 (rice/koku
  requests) and D5 (jade request) — there is no defined supply pipeline or amount to request against.
- **Jade Petal Tea (D6) — no production/consumption/allocation numbers (s2.4.15).** The mechanic is
  described qualitatively ("a handful of monasteries," "Brotherhood allocation") with zero values,
  and it operates on a named/tracked garrison that does not exist (Phase 3).
- **Garrison Taint roster / watch list (D7) + scout coverage (D3).** Both operate on named garrison
  soldiers (Phase 3) and/or the empty-horde scout-detection. No persistent scout-deployment mechanic
  is defined.
- **Shireikan Troop Redeployment (s2.4.13 D2)** has fully-defined values (30% cap, source rules) and
  works on abstract `garrison_pu`, but its trigger is garrison shortage — which cannot arise until
  horde composition is defined (sorties currently inflict 0 casualties). Buildable, but inert until
  the horde gap is closed; deferred to avoid wiring a trigger that never fires.

### Systems Added 2026-06-12 (Kaiu Wall — Taisa sortie timing, s2.4.11 D2, owner-authorized)
- **s2.4.11 Decision 2 (Sortie Timing) — the Tower Commander now orders sorties.** With the
  Phase 2 roster stationing a Taisa at every Tower, the Taisa was still falling to generic
  defense and never sortieing to manage Shadowlands Strength. `_assign_taisa_sortie_standing_objectives()`
  (DayOrchestrator, daily, beside the Kaiu-engineer pass) gives each living Taisa
  (`military_rank == TAISA`) stationed at a Wall Tower a `CONDUCT_SORTIE` standing objective
  when a sortie is warranted, and clears it (conserve the garrison) when it is not. The
  warrant decision is delegated entirely to the already-LOCKED `WallSystem.validate_sortie(ss,
  si, garrison_above_minimum, jade_critical, is_shireikan=false)` — which encodes the full D2
  logic: SS Low -> none / Medium -> Small / High -> Medium (`get_ai_sortie_size`), jade-critical
  block (D5), garrison-below-minimum block, SI<6-while-SS-High block, and Large-requires-Shireikan.
  **No new logic or numbers** — the pass is pure routing. The `CONDUCT_SORTIE` need_type is not a
  decomposer dispatch type, so it falls through `_passthrough` -> scored against
  `objective_alignment["CONDUCT_SORTIE"]` (100) -> selects the CONDUCT_SORTIE action in the
  AT_WALL_TOWER context (no rank gate; only DISPATCH_COURTIER/ORDER_LEVY are rank-gated). The
  executor reads ss/si/garrison/jade from the Taisa's injected wall_status and resolves via
  `resolve_sortie`. **Self-regulating, no cadence number invented:** each successful sortie
  reduces province SS and consumes jade, so the standing lapses on its own (SS drops below
  Medium, or jade goes critical) and the Taisa conserves; it re-arms when SS climbs back. Owns
  only its own `CONDUCT_SORTIE` standing slot (never clobbers a lord directive or other standing;
  a lord-assigned primary takes precedence via resolve_goal). Dead-guarded; generic legion Taisa
  (not stationed at a Tower) are skipped. Parse-checked; no tests per the no-test-code policy.
  **Scope (owner-authorized 2026-06-12):** D2 only. D1 SI-maintenance is already covered by the
  stationed engineer's FORTIFY. The other five demands stay DEFERRED: D3 scout coverage needs new
  persistent scout-tracking; D4 rice/koku requests and D5 jade request need new request pipelines
  (only the troops path exists, via STRENGTHEN_WALL); **D6 Jade Petal Tea and D7 Taint monitoring
  are Phase-3-blocked** — both operate on named/tracked garrison soldiers, which don't exist while
  the garrison is abstract `garrison_pu`. The seven-way triage that is the heart of s2.4.11 is
  itself Phase-3-gated; this delivers the one fully-buildable decision. LIMITATION: without D5
  jade resupply, a Tower's sorties stop permanently once its jade depletes (GDD-faithful — D5 says
  no sortie when jade is critical — but jade never refills until the request pipeline lands).

### Known Code Issues (found and fixed 2026-06-12, Wall Phase 2 validation)
- **Stationed Kaiu Engineers never FORTIFY — peacetime art standing latched the slot. FIXED.**
  Phase 2 stations a Kaiu Engineer at every Tower so the s57.41 MAINTAIN_FORTIFICATION
  standing restores SI. But Kaiu Engineer is an ARTISAN school, so on day 1 (Towers at
  SI 10, healthy) `_assign_kaiu_engineer_standing_objectives` no-ops (min_si >= 7) and the
  s49 `_assign_artisan_standing_objectives` pass gives every engineer the ARTISTIC_EXPRESSION
  standing. Standing objectives are sticky (never cleared by SI change), and the Kaiu pass
  guarded `if not standing.is_empty(): continue` — so once SI later decayed below 7, the
  Kaiu pass skipped every engineer (slot already filled with art) and none ever FORTIFY'd.
  Towers would decay to 0 despite being manned — defeating the entire point of Phase 2.
  Inert before Phase 2 (no engineers were ever stationed at Towers), live once they are.
  Fixed the guard to override the peacetime ARTISTIC_EXPRESSION standing (and refresh an
  existing MAINTAIN_FORTIFICATION priority) when SI < 7, while still never clobbering a
  different standing (e.g. a lord directive). Engineers now latch to wall maintenance once
  any Tower degrades below SI 7 and keep it restored thereafter (proactive doctrine,
  s2.4.11). Structural fix, no invented values. Parse-checked.
- **Persistence verified.** `operational_superior_id` and `physical_location` are @export on
  L5RCharacterData; `SettlementData.wall_tower_number` is @export. The ~39 wall NPCs are
  ordinary characters saved by SaveManager and the tower number rides the settlements
  Resource array — the roster + hierarchy round-trip across restart.
- **Death cascade verified.** `OperationalHierarchySystem.clear_subordinates_on_death`
  releases subordinates' `operational_superior_id` to -1 on a superior's death (Taisa dies →
  its engineer/Kuni released; Shireikan dies → its 6 Taisa released), dead-guarded, no crash.
  Tower-commander auto-refill on a Taisa's death is deferred to Phase 3 (abstract garrison has
  no company to promote into) — graceful degradation, not a crash.

### Systems Added 2026-06-11 (Kaiu Wall — Phase 1: Tower settlements, owner-authorized)
- **s2.4.2 / s2.3 — the twelve Wall Towers created at world-gen.** Before this,
  no `WALL_TOWER` settlement existed at all — the entire Kaiu Wall mechanical layer
  (SI decay/sortie/garrison-shortage escalation/horde targeting) had nothing to act
  on. `WorldBootstrap._create_wall_towers()` (post-pass after `_wire_adjacencies`,
  before `_designate_hidden_temple`) creates 12 `WALL_TOWER` settlements numbered
  1 (SE) → 12 (NW), distributed: **Ishibei 1-5** (GDD-stated, s2.3: "the five
  southernmost Wall Towers are garrisoned from this province"), **Ishigaki 6-9** and
  **Yoake 10-12** (PROVISIONAL — wall continues NW through both Crab provinces;
  Tower 3 = Southern Shireikan seat in Ishibei, Tower 10 = Northern Shireikan seat in
  Yoake). The three wall provinces have `shadowlands_strength` set (was 0 — only
  ungovernable Hiruma provinces got SS) so the WallSystem recognises them as wall
  provinces. Towers built as `SettlementData` directly (NOT `generate_settlement`,
  which forces civilian PU distribution + `garrison_pu = maxi(1, pu/20)`). Appended
  to `settlements` + each host province's `settlement_ids`; ID counter threaded
  through (`next_settlement_id` return). **Per-tower starting state — all PROVISIONAL,
  owner-approved "Pristine/stable" (2026-06-11):** `wall_si=10` (pristine, +12
  defense), `garrison_pu=3` (above `MINIMUM_GARRISON_PU=1.0` so the shortage
  escalation pipeline stays dormant), `jade_stockpile=5.0` (non-critical; small-sortie
  min ≈0.6), `rice_stockpile=10.0` (~6-9 seasons of the 0.35/PU garrison drain;
  towers have `population_pu=0` so produce no rice), `shadowlands_strength=3` on the
  wall provinces (low tier — no extra SI decay). **Calibration basis (owner directive
  "analyze the rest of the code first"):** horde combat is a STUB
  (`HordeSystem._generate_jigoku_companies`/`_generate_undead_companies` return `[]`,
  "pending GDD spec"), so nothing attritts `garrison_pu` yet — garrison can't be sized
  against a non-existent threat; the only live tension loop is `wall_si` vs seasonal
  decay (4/yr base, 6/yr at SS-medium) restored by FORTIFY (+1.0, +0.5/raise). Phase 1
  ships WITHOUT maintainers (the command roster is Phase 2) and WITHOUT real horde
  attrition (Phase 3 / GDD spec), so towers start pristine + low-pressure to stay
  stable through the interim. Placement edge verified: towers appended last →
  `_assign_physical_locations` picks `target_settlements[0]` (always a civilian
  settlement) → no civilian is auto-stationed at a tower (correct; Phase 2 stations the
  garrison command roster). Parse-checked; no tests per the no-test-code policy.
  DEFERRED: Phase 2 (Shireikan/Rikugunshokan/garrison command roster + engineers as
  tower-stationed NPCs), Phase 3 (horde composition spec → real garrison attrition →
  garrison/SI/jade re-tuning against a live threat).

### Systems Added 2026-06-11 (Kolat — succession trigger)
- **s54.7g Master succession trigger WIRED.** The LOCKED succession resolver
  `KolatMasterSelector.evaluate_succession()` (Tranche 8, fully built + tested) was
  defined but never called — a dead Kolat Master left their Sect permanently vacant
  and that network went dark. `DayOrchestrator._process_kolat_master_succession()`
  now fires at both death-processing sites (daily + seasonal), BEFORE the field-agent
  recall, for each dead Master: calls `evaluate_succession(dead.kolat_sect, characters,
  {}, dice)` which runs the cascade (three ranked heirs → Tiger discretionary draw →
  chain re-point) and seats a living non-Master Sect agent if one exists, else leaves
  the Sect vacant (s54.7g: the network cannot always refill). The new Master inherits
  the Sect standing mandate (`_assign_kolat_standing_objectives`, already wired), so
  the network keeps functioning. Ordering: succession runs before the recall so a
  freshly-seated Tiger can route that recall (the recall is Tiger-gated). The dead
  Master's `is_kolat_master` flag is left set (dead-guarded everywhere; the resolver
  excludes it via is_dead) so the recall still finds its network. `heir_designations`
  is passed `{}` — the encrypted heir record and its Cloud-archive storage remain
  deferred, so the cascade always falls to the discretionary draw for now (the
  ranked-heir path activates automatically when that record is populated — no
  further wiring). The s54.7g "not under active investigation" gate IS live:
  `under_investigation_ids` is gathered each death pass from the perpetrators +
  known suspects of all UNDER_INVESTIGATION CrimeRecords, and `_discretionary_select`
  excludes them — a compromised Sect agent is never promoted into the seat. Pure structural wiring of a LOCKED spec,
  no new design/numbers. Parse-checked; no tests per the no-test-code policy. TUNING:
  a Sect whose Master dies before any agent is recruited (APPROACH_FOR_RECRUITMENT)
  goes permanently dark — GDD-faithful fragility, but worth watching early-game.

### Known Code Issues (found and fixed 2026-06-11, Wall escalation Step-1 season flag)
- **Garrison-shortage letter-season flag was never set for lords — entire Champion/
  Shireikan escalation pipeline stalled at Step 1 in live runs. FIXED.**
  Auditing the Shireikan parallel wall path (s2.4.13 Decision 10) traced the
  garrison-shortage escalation gate to a dead flag-setter.
  `_apply_garrison_shortage_letter_writebacks` set `garrison_shortage_letter_season`
  only from the **daily letter pass**, filtering results with `need_type ==
  "STRENGTHEN_WALL"`. But (a) `resolve_daily_letter` excludes any character with
  `civilian_order_budget_max > 0` (s57.34.7), so every lord — Champion (budget 12),
  Rikugunshokan (8), and any lord-Shireikan — is excluded from that pass, and
  (b) `STRENGTHEN_WALL` is deliberately decomposer-only with **no
  `objective_alignment.json` entry** (it always decomposes into action-needs like
  SEND_LETTER, which carry their own alignment), so `resolve_daily_letter` returns
  `{}` for it (score 0) regardless. Result: NO daily-pass STRENGTHEN_WALL letter is
  ever produced, the flag stays −1 forever, and both the Champion (decomposer line
  937 `if letter_season < 0: SEND_LETTER`) and Shireikan (line 957) return
  `SEND_LETTER` every season, never reaching DISPATCH_COURTIER or
  DECLARE_WALL_EMERGENCY. (The DISPATCH_COURTIER/DECLARE_WALL_EMERGENCY tests passed
  only because they set the flag directly in fixtures.) Fix is structural (no
  invented numbers) and matches s55.23a line 72 ("no letter sent this season → fire
  SEND_LETTER"): the writeback now also scans the AP/Civilian-Order wave results
  (`day_result["results"]`) for a successful `WRITE_LETTER` whose sender holds a
  STRENGTHEN_WALL objective and whose `target_province_id` (inherited from the
  decomposer need via npc_decision_engine:497) resolves to a WALL_TOWER, and sets
  that Tower's `garrison_shortage_letter_season` from the lord's own executed Step-1
  letter. Pipeline now flows: season X — SEND_LETTER (sets flag) then DEFEND_PROVINCE;
  season X+1 — DISPATCH_COURTIER; refused + SI<6 — DECLARE_WALL_EMERGENCY.
  LIMITATIONS (not this bug): (1) the daily-pass loop is now dead but harmless (kept
  as documented intent for a future budget-0 sub-Shireikan letter channel);
  (2) sub-Shireikan tower officers (WALL_SEGMENT_COMMANDER / Taisa) still fall to
  DEFEND_PROVINCE without their own letter campaign — extending the letter step below
  Shireikan rank is a design expansion (GDD s2.4.12 line 530 "The Taisa or Shireikan
  writes letters") needing owner direction, separate from this stall fix.

### Systems Added 2026-06-11 (Wall Shireikan→Champion escalation, owner-authorized)
- **s2.4.13 Decision 10 / s2.4.14 Decision 4 — Champion tower visibility WIRED.**
  Closes the deeper half of the garrison-shortage stall. Even with the Step-1 season
  flag now set (above), the **Champion's** escalation (DISPATCH_COURTIER /
  DECLARE_WALL_EMERGENCY, gated `lord_rank == CLAN_CHAMPION`) was unreachable in live
  runs: `wall_statuses` is injected ONLY for characters physically standing at a Tower
  (`_set_wall_tower_context_flags`, location-gated + cleared daily as a stale key), and a
  Clan Champion governs from a capital — so the Champion's `ctx.wall_statuses` is always
  empty and the decomposer's Branch A loops never execute. The GDD models this as the
  Shireikan **escalating to the Champion** after a failed letter season (Decision 10
  line 666), so `_process_wall_shireikan_escalation()` (DayOrchestrator, run daily right
  after `_set_wall_tower_context_flags`) implements that handoff. **Trigger (owner-
  confirmed proxy for GDD "no lord moved to the +50 commitment threshold," which isn't
  tracked in state):** Tower still below minimum garrison + Shireikan Step-1 letter sent
  (`garrison_shortage_letter_season >= 0`) + a full season elapsed (`current_season !=
  garrison_shortage_letter_season`). On escalation it finds the living non-PC Clan
  Champion of the Tower's province clan (`_extrad_find_clan_champion_id`), **force-assigns
  a STRENGTHEN_WALL primary** targeting the Tower (`source: "wall_shireikan_escalation"`,
  owner choice — mirrors the existing wall_emergency forced-primary precedent), and
  injects the Tower's WallStatus into the Champion's per-character world_state via
  `_inject_champion_wall_status()` (built identically to `_set_wall_tower_context_flags`;
  dedup-guarded if the Champion happens to be at the Tower). The Champion's
  `province_statuses` (the `ps.garrison_pu < minimum` check at decomposer line 934) is
  already auto-built for every province from the global `province_data`/`settlements`
  injected for lords (`_inject_base_character_context` line 21364, which runs before the
  wave and preserves the injected `wall_statuses`). Because the season flag is already
  past, the Champion's decomposer skips Step 1 and fires DISPATCH_COURTIER → (refused +
  SI<6) DECLARE_WALL_EMERGENCY — the full GDD pipeline now runs end to end. **Release:**
  a Champion holding a `wall_shireikan_escalation` primary whose Towers have all recovered
  (none escalating that pass) drops the objective (`obj.erase("primary")`, mirrors the
  wall_emergency clear). Ordering verified: stale-clear (161) → `_set_wall_tower_context_flags`
  (234) → escalation (235) → `_inject_base_character_context` (294, preserves wall_statuses,
  adds province_data) → wave (302). Pure structural wiring of LOCKED escalation behavior,
  no invented numbers. Parse-checked; no tests per the no-test-code policy. LIMITATIONS
  (not bugs): the Champion holds one STRENGTHEN_WALL primary at a time (decomposer Branch A
  iterates all injected Tower wall_statuses and acts on the first short one, so multiple
  short Towers are still serviced, just via one objective slot); DISPATCH_COURTIER target
  selection relies on the Champion's `contact_garrison_scores` (existing infra from the
  Daimyo-handoff fix).

### Known Code Issues (found and fixed 2026-06-11, Wall escalation Daimyo handoff)
Auditing the receiving-Daimyo response path (s55.23a, LOCKED) after the Step-2
routing fixes exposed two more gaps that left the DISPATCH_COURTIER path inert —
it had never been exercised because Step 2 used to route to wall repair. Both
fixed; the full Step 1 → Step 2 → Step 3 escalation now hands off cleanly:
- **DISPATCH_COURTIER selected no target Daimyo — executor no-op'd. FIXED.**
  GDD s55.23a: DISPATCH_COURTIER requires `target_npc_id` (receiving Daimyo) AND
  `target_province_id` (Tower), both required. The decomposer passes only the
  province, and `_populate_action_metadata` had no DISPATCH_COURTIER branch, so
  `target_npc_id = -1` → the executor early-returned `no_target` and did nothing
  (no Daimyo decision, no flags). Added a metadata branch selecting the known
  contact with the highest garrison personality score (`ctx.contact_garrison_scores`
  — the same selection the letter step uses); `target_province_id` is already set
  from the need. `_populate_action_metadata` already receives `ctx`, so no
  signature change.
- **`garrison_shortage_courtier_dispatched` never set on refusal — Step 2 looped. FIXED.**
  The flag was set only in `_apply_garrison_assignment` (the *compliance* path,
  which then clears the shortage). On a refusal `_apply_garrison_courtier_refusal_writebacks`
  set `courtier_refused = true` but left `courtier_dispatched = false`, so the
  decomposer's Step 2 (`not courtier_dispatched`) kept re-firing DISPATCH_COURTIER
  every season and Step 3 (which keys on `courtier_refused`) was never reached.
  Now the refusal writeback also sets `courtier_dispatched = true`. After a
  refusal: Step 2 is skipped → Step 3 fires DECLARE_WALL_EMERGENCY when SI < 6.
  Parse-checked; no tests per the no-test-code policy. LIMITATION (not a bug):
  the model dispatches to a single best-scoring Daimyo; after a *partial*
  compliance (some PU, still below minimum) the Champion falls through to
  DEFEND_PROVINCE (direct defense) rather than dispatching to another Daimyo —
  the existing single-target model, not a regression.

### Known Code Issues (found and fixed 2026-06-11, Wall escalation Step 2)
The Champion's garrison-shortage escalation (s55.23a, LOCKED) had its entire
Step 2 (courtier dispatch) broken three ways — meaning Step 3 (the new
DECLARE_WALL_EMERGENCY) was unreachable in practice. All three fixed:
- **Step 2 returned the wrong NeedType — `MAINTAIN_FORTIFICATION` (wall repair)
  instead of dispatching a courtier. FIXED.** `objective_decomposer.gd:941`.
  GDD s55.23a line 74: "Step 2 — Courtier dispatch: ... fire DISPATCH_COURTIER."
  History: commit 2cd579c ("Fix 13 decomposer outputs using ActionIDs as
  NeedTypes") changed the original `DISPATCH_COURTIER` → `MAINTAIN_FORTIFICATION`.
  The original WAS broken (DISPATCH_COURTIER is an ActionID, not a NeedType →
  no objective_alignment entry → scores 0 → REST), but the bulk fix swapped in a
  valid-but-wrong NeedType (MAINTAIN_FORTIFICATION's winner is ORDER_FORTIFY/
  SEAL_WALL_BREACH 100, not DISPATCH_COURTIER) — so Step 2 routed to wall repair,
  never dispatching a courtier, so `garrison_shortage_courtier_dispatched` never
  flipped and the pipeline stalled forever. Fixed via the collision-NeedType
  pattern (same as DECLARE_WALL_EMERGENCY / PERFORM_RITUAL): added a
  `DISPATCH_COURTIER` NeedType to objective_alignment.json
  (`DISPATCH_COURTIER` 100, `ASSIGN_GARRISON` 60 fallback) and routed Step 2 to it.
- **COMMANDER_RANK_ACTIONS gate locked the Champion out of DISPATCH_COURTIER. FIXED.**
  The gate (`npc_decision_engine.gd`) blocks DISPATCH_COURTIER unless
  `military_rank >= SHIREIKAN`, but `POSITION_MILITARY_RANK` assigns a military
  rank only to RIKUGUNSHOKAN — every Clan Champion has `military_rank = NONE`. GDD
  s55.23a line 46: DISPATCH_COURTIER is "Available to Champion and Shireikan tier
  only." Added a Champion carve-out (`lord_rank == CLAN_CHAMPION` passes regardless
  of military_rank). Without this, even the corrected Step-2 routing would still be
  blocked.
- **Step-1→Step-2 timing used cyclic-season subtraction. FIXED.**
  `ctx.season - garrison_shortage_letter_season >= 1` — but `ctx.season`
  (`world_state["season"] = time_system.get_season()`) is cyclic 0–3, and
  `garrison_shortage_letter_season` is set from the same cyclic value. A letter
  sent in winter (3) gives 0-3 / 1-3 / 2-3 = all < 1 → Step 2 never advances
  (3 of 4 seasons worked; winter-issued letters silently stalled). Changed to
  `ctx.season != garrison_shortage_letter_season` ("the season has changed since
  the letter" = one season elapsed), which is wraparound-safe and equivalent for
  the working cases. Step 1 (`letter_season < 0`) and the Shireikan path
  (also `< 0`) are unaffected. Phantom `DEFEND_PROVINCE` fallbacks (a NeedType,
  not an executable action) in both new wall NeedType blocks replaced with the
  real `ASSIGN_GARRISON` action. Parse-checked; no tests per the no-test-code policy.

### Systems Added 2026-06-11 (Wall-Wide Emergency)
- **s2.4.14 Decision 6 — DECLARE_WALL_EMERGENCY (owner-authorized 2026-06-11).**
  Completes the Kaiu Wall garrison-shortage escalation, replacing the Step-3
  DEFEND_PROVINCE stub (`objective_decomposer.gd:945`). The gravest call a Crab
  Champion can make short of war. **Trigger (LOCKED s55.23a Step 3):** Champion
  only, `garrison_shortage_courtier_refused and si < 6`. **Routing:** decomposer
  Step 3 returns NeedType `DECLARE_WALL_EMERGENCY` → objective_alignment
  (`DECLARE_WALL_EMERGENCY` 100, `ASSIGN_GARRISON` 60 fallback) → 4 context lists
  (AT_OWN_HOLDINGS, AT_COURT, ON_CAMPAIGN, AT_WALL_TOWER) → LORD_ONLY → 1 AP
  (owner) → action_skill_map null/null (auto-success declaration, no roll).
  **Executor** (`_compute_declare_wall_emergency_effects`, ADMINISTRATIVE_ACTIONS):
  signals `requires_wall_emergency_declaration` + the critical Tower province.
  **Writeback** (`_apply_wall_emergency_declaration`, in `_process_military_effects`):
  (1) elevates the active `shadowlands_incursion` topic — preferring the one
  affecting the Tower, else the most recent — to the Tier-1 momentum floor and
  broadcasts it into every compelled lord's `topic_pool` (owner choice: elevate
  existing, not a new topic; gracefully skips if no incursion topic exists yet);
  (2) compels every living non-PC Crab daimyo (CITY_DAIMYO..FAMILY_DAIMYO, ≠ the
  Champion) by forcing a `DEFEND_PROVINCE` primary toward the Tower (source
  `wall_emergency`) — supersedes all priorities per D6 — stamping
  `wall_emergency_obligation_ic_day`. Deduped: one emergency per 90-day window
  (the Champion is marked too, `contributed=true`, exempt from penalty, which
  rate-limits re-declaration). **Compliance (owner: override + penalty):** daily
  `_process_wall_emergency_contributions` marks a lord `wall_emergency_contributed`
  when they commit troops (ASSIGN_GARRISON / ORDER_DEPLOY) during the window;
  seasonal `_process_wall_emergency_obligations` applies −1.0 Honor (the
  serious/horde tier of the existing s2.4.12 courtier-refusal scale —
  `action_executor` wall_critical branch, reused not invented) to any
  non-contributor 90 IC days (= IC_DAYS_PER_YEAR/4, one season) after the
  declaration, then clears the obligation + the forced primary. Two new
  `L5RCharacterData` fields (`wall_emergency_obligation_ic_day`,
  `wall_emergency_contributed`) persist via SaveManager — no WorldStateSaver
  change. **Re-declaration gate (2026-06-11):** `ContextSnapshot.wall_emergency_active`
  is populated in `build_context` directly from the Champion's own marker
  (`wall_emergency_obligation_ic_day >= 0`, set on declaration, cleared by the
  seasonal pass). The decomposer Step 3 skips DECLARE_WALL_EMERGENCY while it is
  set — the Champion defends the Tower directly (DEFEND_PROVINCE) instead of
  re-declaring — so the action is never re-produced during the active window
  (no wasted AP). The writeback dedup remains as belt-and-suspenders. Parse-checked;
  no tests per the no-test-code policy. LIMITATIONS
  (not bugs):
  contribution is lenient (any garrison/deploy commit counts, not strictly
  Tower-targeted); "every Crab lord" = CITY_DAIMYO+ (village headmen have no
  garrison to commit); topic elevation requires an active incursion topic
  (the forced objectives + penalty are the operative compulsion regardless).

### Systems Added 2026-06-06 (Sailing)
- **s57.42 / s57.43 Sailing, Captains & Passage** — `simulation/sailing_system.gd`
  (pure class); `shared/ship_data.gd` gains `owner_id` + `departure_tick`. New system
  (was REFERENCE; locked s57.42a). Headless core faithful to s57.42/43:
  captain Sailing minimums (`min_sailing_for_class`: 1 small / 3 oceangoing / 4 heavy;
  TORTOISE_OCEANGOING = 3 PROVISIONAL), `captain_meets_requirement`, `self_captain_penalty`
  (−2k0 under-qualified). Captain succession (`select_acting_captain`: highest Sailing,
  tiebreak Insight Rank → Status; -1 = catastrophic peril; skips dead). REQUEST_PASSAGE
  acceptance (`evaluate_passage_request`): standing-orders + schedule-incompatible hard
  refuses; Acquaintance+ (disposition ≥ 11) rides free; below that koku + personality lean
  must bridge the gap (Jin +5 / Seigyo +3 koku-offered / Rei +2 high-Status[≥4.0] or polite);
  `refusal_disposition_shift` (0 polite / −1..−3 rude). Throttle/cooldown
  (`can_request_passage`: 2/IC day, 1-IC-day per-captain refusal cooldown). Embarkation
  (`board_passengers` sets `aboard_ship_id` for accepted passengers co-located at the port
  when `departure_tick` fires; `disembark` clears + places). Owner-granted passage =
  3-point Obligation. s57.43 voyage formulas: `pirate_interception_chance` (Strength × 10%),
  `interception_resolution` (4+ → naval mass battle, 1–3 → deck skirmish),
  `shipwreck_landfall_chance` (10/25/40/60, Mantis day-1 30%, 6-day ceiling).
  DEFERRED (UI / NPC-engine, needs Godot): ship ASCII Lesser Zone (SHIP_INTERIOR) + voyage
  play map, AT_SHIP context + action allow/block list, voyage-event resolution + arrival
  route-disruption, passenger-manifest generation, REQUEST_PASSAGE/JUMP_OVERBOARD/
  INTERVENE_CAPTAIN as live ActionIDs, named-crew REPORT_TO_SHIP, owner-override letter flow.
  Locked in `gdd/s57.42a_sailing_captains_passage_locked.md`. 20 tests.

### Systems Added 2026-06-06 (Allied NPC Companion)
- **s57.46 Allied NPC Companion** — `simulation/companion_system.gd` (pure class),
  `shared/companion_data.gd` (Resource). New system (was REFERENCE; locked s57.46a).
  Headless core faithful to s57.46: `CompanionType` (village/city-team/headman doshin,
  yojimbo, yoriki, named ally), `Command` (FOLLOW/HOLD/MOVE_TO/RETREAT + GUARD_EXIT/
  IDENTIFY/SEARCH_AREA/PROTECT/INVESTIGATE), `Morale` (STEADY/SHAKEN/BROKEN).
  6-slot hard cap (doshin team = 1 slot). `available_commands()` gates type-specific
  commands; `can_assign_command()` blocks orders to BROKEN companions and limits SHAKEN
  to RETREAT. `decide_action()` is the AI priority stack (SURVIVAL→PLAYER_COMMAND→DEFAULT;
  BROKEN forces RETREAT). `morale_threshold()` per type (village .30/city .40/headman .50/
  yojimbo never; yoriki .30–.50 by school+Yu; named .20–.50 by Yu); `update_morale()`
  (SHAKEN at half threshold, BROKEN at threshold, no un-break), `relieve_shaken()`,
  `combat_penalty()` (−5 SHAKEN). `noise_contribution()` (doshin baked-in bases;
  others Stealth-reduced) + `party_noise_contribution()`. `teamwork_grapple_bonus()`
  (+5 city team 2+), `will_engage_samurai()` (warrant + headman gates),
  `guard_exit_penalty()` (−10 vs samurai). `death_consequences()` (doshin_losses
  increment / named vacancy + Tier 4 topic). DEFERRED to UI/orchestrator (needs Godot,
  same boundary as the combat layer): grid rendering, TAB command menu, A* path
  execution, turn-loop integration into AsciiMapCombatOrchestrator, mission-launch
  selection screen, local-knowledge prompts, live IDENTIFY/SEARCH/INVESTIGATE rolls.
  Locked in `gdd/s57.46a_allied_npc_companion_locked.md`. 25 tests in
  `tests/test_companion_system.gd`.
- **Companion ↔ orchestrator integration (s57.46, 2026-06-06).**
  `AsciiMapCombatOrchestrator` now hosts companions as FACTION_PLAYER participants:
  `add_companion()` (rolls initiative, inserts into turn order, registers
  CompanionData + started count); `execute_companion_turn()` (runs
  `CompanionSystem.decide_action`, then translates the command to grid behavior —
  RETREAT/BROKEN → move to nearest ZONE_EXIT and leave, else engage an adjacent
  enemy with doshin samurai-avoidance, else move toward the command's goal tile:
  FOLLOW→player, MOVE_TO/GUARD_EXIT→tile, PROTECT→protected char; reuses
  find_path/execute_move/get_melee_targets/_npc_execute_attack);
  `update_companion_morale()` (recomputes from allied-casualty fraction);
  `resolve_current_turn()` (turn-loop dispatcher — auto-resolves enemy NPCs and
  companions on their initiative, refreshes companion morale first, yields
  `awaiting_player` on a PC turn).
  `MapCombatState` gains `companion_data` + `companion_started_count`. Live UI
  (grid tokens, TAB menu, mission-launch screen, local-knowledge prompts,
  IDENTIFY/SEARCH/INVESTIGATE live rolls) still deferred (needs Godot). 4
  integration tests in `tests/test_ascii_map_combat.gd`.

### Systems Added 2026-06-06 (Kiho)
- **s38 Kiho** — `simulation/kiho_system.gd` (pure class). New system (was REFERENCE).
  Full 73-kiho catalog faithful to s38 (Air 18 / Earth 17 / Fire 12 / Water 11 /
  Void 15): each entry has ring, mastery, `KihoType` (INTERNAL/KHARMIC/MARTIAL/MYSTICAL),
  and atemi/staff flags. **MONK-ONLY (s38a A0 owner override 2026-06-06):** only MONK
  characters may learn kiho — shugenja are excluded (overrides s38's shugenja-at-2×
  provision); PCs may not be monks (s60.2, `PcSystem.is_school_type_allowed_for_pc`/
  `is_valid_pc`), so PCs never learn kiho. Eligibility (`meets_mastery`): a monk meets a
  kiho if `school_rank + relevant_ring ≥ mastery`. Cost multiplier (`cost_multiplier`):
  Brotherhood monk ×1.0, non-Brotherhood monk ×1.5; `learn_cost = ceil(mastery × multiplier)`
  (base mirrors KataSystem's `xp_cost = mastery`). Knowledge cap (`knowledge_cap`/
  `at_knowledge_cap`): non-Brotherhood monks ≤ school rank; Brotherhood uncapped (-1).
  Acquisition (`can_learn`/`can_afford`/`learn_kiho`) consumes the existing `kiho` character
  field and deducts XP. NPC selection (`select_kiho_for_npc`): highest affordable+eligible
  mastery, alpha tie-break. Activation (`activation_options`): Void Point = Free, Meditation
  TN 15 = Complex / TN 30 = Simple, atemi free. Active-slot constraint (`can_activate`): one
  Internal + one Kharmic + one Mystical active, Martial unlimited. Wired into NPCAdvancement:
  monks claim kiho XP before progress bars (parity with bushi/kata). Locked in
  `gdd/s38a_kiho_locked.md` (A0–A10). 20 tests + 3 PcSystem PC-school tests.

### Systems Added 2026-06-04
- **s44 Shadowlands Mutations & Powers** — `simulation/mutation_system.gd` (pure class),
  `shared/mutation_data.gd`, `shared/shadowlands_power_data.gd`. Full catalog from GDD s44.
  Three new enums on `shared/enums.gd`: `MutationType` (17 values), `ShadowlandsPowerTier`
  (MINOR/MAJOR/AKUTENSHI), `ShadowlandsPowerType` (44 values). Three new character fields on
  `L5RCharacterData`: `mutations: Array[MutationData]`, `shadowlands_powers: Array[ShadowlandsPowerData]`,
  `taint_rank_last_processed: int`.
  Taint rank thresholds (s42): 0.0–0.9=Rank 0, 1.0–1.9=Rank 1, 2.0–2.9=Rank 2,
  3.0–3.9=Rank 3, 4.0–4.9=Rank 4, 5.0+=Rank 5 (Lost).
  Periodic taint roll periods: Rank 0–1=30 IC days, Rank 2=15, Rank 3=7, Rank 4=1, Rank 5=none.
  TN = 5 + (5 × Rank). Power-use taint roll TN: Minor=15, Major/Akutenshi=20.
  Rank-up processing (`process_rank_up`): Rank 2=+1 Minor power; Rank 3=+1 power (Minor or
  Major) + 1 mutation; Rank 4=+2 powers (first guaranteed Major, second any) + 1 mutation;
  Rank 5=0–3 mutations + 0–3 powers from Minor+Major pool (Akutenshi excluded — separate category).
  Secondary effects on acquisition: DISTORTED_LIMBS leg → LAME disadvantage added (no duplicate);
  EXTRA_LIMB → 50% chance non-functional (−1k0 Agility/Reflexes); UNHOLY_BEAUTY → clears
  mutations array; MASTER_OF_SHADOWS → gains DISCOLORED_SKIN if absent. Duplicate prevention
  for both mutations and powers. Pool exhaustion handled gracefully (returns NONE).
  Skill modifier interface (`get_skill_modifiers` → `{rolled, kept, tn}` deltas):
  ALBINISM (−1k0 social, gated on `appearance_known` context key), DISCOLORED_SKIN (+5 TN
  all social), EXTRA_DIGIT/FOUL_ODOR (−1k0 social each), TOUGH_HIDE (−2k0 social),
  EXTRA_EYE (+1k0 perception, gated on `extra_eye_uncovered`), EXTRA_LIMB non-functional
  (−1k0 agility/reflexes), MASTER_OF_SHADOWS (+Taint Rank unkept dice to Stealth),
  MONSTROUS_STRENGTH (−1k0 social, +Taint Rank unkept dice to Strength-based skills),
  FATHER_OF_LIES (+Taint Rank kept dice to Temptation, Intimidation, Sincerity:Deceit only).
  `SkillResolver.resolve_skill_check()` wired: `mutation_mod` applied to rolled, kept, TN.
  MASTER_OF_BLOOD wired into `MahoSystem.resolve_cast()`: blood cost −1 (min 1), taint gain
  reduced by Earth ring (min 1). `get_social_rolled_penalty()` and `get_social_tn_penalty()`
  helpers for NPC context injection.
  DayOrchestrator: `_process_periodic_taint_rolls()` and `_process_taint_rank_changes()`
  called daily (line ~1512); both guard dead characters and untainted (taint < 1.0) characters;
  rank-change processor handles multi-rank jumps by iterating from last_processed+1 to current.
  Combat stubs (Reduction, Fear, CHITINOUS_ARMOR, TENTACLES, UNDEAD_VISAGE attack bonuses)
  registered as no-ops — deferred to s40 individual combat. Mental trait collapse to 1 on
  Rank 5 (Lost) documented but not enforced — s40 reads trait values at combat time.
  60+ tests in `tests/test_mutation_system.gd`.

### Systems Added 2026-06-03
- **s31–s37 Spell System** — `simulation/spell_system.gd` (pure class, no Node inheritance),
  `tests/test_spell_system.gd`. Full L5R 4e shugenja spell resolution for simulation use.
  Core mechanics: `get_ring_value(char, ring)` — Air=min(Ref,Awr), Earth=min(Sta,Wil),
  Fire=min(Agi,Int), Water=min(Str,Per), Void=void_ring. `get_effective_school_rank(char, ring)`
  — affinity +1, deficiency −1, floor 0. `get_casting_tn(mastery_level)` — TN = 5 + ML×5
  (ML1=10, ML2=15, ML3=20). `get_best_cast_ring(char, spell_id)` — elemental spells locked
  to their element, Universal picks highest (ring_val + eff_rank). `get_daily_slots(char, ring)`
  — returns ring value. Slot tracking via character dict fields `spell_slots_used` and
  `spell_void_bonus_used`; ring-primary slots overflow to void bonus pool. `can_afford_slot`,
  `consume_slot`, `get_slots_used`, `get_void_bonus_used`. `can_cast(char, spell_id)` —
  validates: spell exists in library, in spells_known, insight_rank ≥ mastery_level, has
  affordable slot, passes Ishiken restriction for void spells. `resolve_cast(char, spell_id,
  dice, raises=0)` — rolls ring_value keep ring_value (xky), applies raises (+5 TN per
  raise), consumes slot, returns {success, total, tn, margin, spell_id, sim_effect, cast_ring}.
  `apply_healing(char, spell_id, margin)` and `apply_taint_removal(char, spell_id, margin)`
  for applying cast outcomes. `assign_starting_spells(char, school)` populates spells_known
  from school table (Kuni: sense+commune+jade_strike; default: sense+commune).
  SPELL_LIBRARY: 32 named spells covering all 5 elements plus Universal, mastery levels 1–6.
  SpellSimEffect enum: COMBAT_ONLY=0, HEAL_WOUNDS=1, REMOVE_TAINT=2, DETECT_PRESENCE=3,
  COMMUNE_KAMI=4, PURIFY_AREA=8 (no library entries yet — forward-wired), RITUAL_HONOR=15.
  Helper selectors: `get_best_healing_spell`, `get_best_ritual_spell`, `get_best_detection_spell`,
  `get_best_taint_removal_spell`, `get_spells_by_sim_effect`, `get_best_spell_by_effect`,
  `get_spells_for_element_ml`. 75 tests in `tests/test_spell_system.gd`.
  NPC pipeline integration: `_populate_action_metadata` in `npc_decision_engine.gd` populates
  `ritual_spell_id` (PERFORM_RITUAL: prefers taint-removal in tainted provinces, else best
  ritual-honor spell; PERFORM_WORSHIP: best ritual-honor or commune), and `healing_spell_id`
  (TREAT_WOUND: best heal-wounds spell for shugenja). `_process_ritual_spell_writebacks` in
  `day_orchestrator.gd` resolves `requires_spell_roll=true` executor flags: DETECT_PRESENCE
  creates a SUPERNATURAL TIER_4 taint-detection topic when province PTL > 0; REMOVE_TAINT
  calls `apply_taint_removal`; PURIFY_AREA forward-wired (no spells yet). 11 engine tests.
  LIMITATIONS: Maho Channel 3 detection is a Lore: Shadowlands check (NOT a Sense cast —
  Sense detects kami, not kansen), WIRED at TN (8 − Taint Rank) × 5 (owner 2026-06-10).
  `spells_known` field on L5RCharacterData promoted from orphaned
  placeholder to active use. `spell_slots_used` and `spell_void_bonus_used` added as new
  character fields. PURIFY_AREA sim_effect has no library spells yet.

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
