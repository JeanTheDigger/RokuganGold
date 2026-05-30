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
| Courtier school techniques & rerolls          | 29.15                |
| Skill resolver (technique/wound/emphasis)     | 29.15, 4.5           |
| Individual combat                             | 40 (not yet built)   |
| ASCII map mission generation                  | 56 (not yet built)   |
| Quest seeds                                   | 56.1 (not yet built) |
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
| Artisan & crafting system                     | 49                   |
| Musha Shugyo (warrior's pilgrimage)           | 57.48                |
| Clan Champion strategic evaluation           | 57.54                |
| Otomo Seiyaku (alliance suppression)          | 55.22b               |
| NPC advancement (XP, skill/ring progression)  | 52 Part 3, 48, 48a   |
| World population generator (game start pass)  | 52 Part 1, 22.4, 22.8|
| Gempukku / NPC spawning / natural death       | 52, 22.4, 22.7       |
| Ronin system (status transitions, petition)   | 52 Part 5, 52.5      |

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
  simulation code: `techniques`, `kiho`, `katas`, `spells_known`,
  `weapons`, `armor_worn`, `active_quest`, `active_poisons`,
  `combat_modifiers_pending`. All are schema placeholders for blocked
  sections (s40 individual combat, s31–s37 spells, s56 quest system).
  Do not remove — they will be consumed when those sections unlock.
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

### Known Architectural Gaps — Deferred
- **military_data Dictionary permanently empty.** `WorldState.military_data`
  is declared as `{}` and passed to `advance_day()` but never populated by
  any system. The actual military data lives in `military_companies` (array
  of Dictionaries), `active_armies`, `active_sieges`, etc. ActionExecutor
  reads `military_data` for validation but silently allows all military
  orders when it's empty (fallback behavior). Not causing crashes because
  military order validation has other guards (commanded_unit_id checks,
  lord carve-out). Proper fix would either: (a) populate military_data
  from military_companies at start of advance_day(), or (b) refactor
  military validation to read from military_companies directly. Low
  priority — military orders still function correctly via other guards.
- **AT_DOJO context flag never assigned.** No DOJO settlement type exists
  in SettlementData. Dojos exist only as ZoneSubtype.DOJO (sub-settlement
  level), and the zone system data is not yet available. Monk objective
  decomposition routes through AT_DOJO but characters never receive this
  context, so dojo-specific action paths are unreachable. Blocked on zone
  system implementation.
- **ON_CAMPAIGN, UNDER_SIEGE, IN_EXILE context flags never assigned.**
  These require the sub-tile army movement system (s11.7a) and map data
  that don't exist yet. Characters in these states fall through to
  AT_OWN_HOLDINGS or VISITING context. Blocked on world map / adjacency
  data.

### Known Performance Concerns — Deferred
- **Unbounded array growth in advance_day().** `crime_records`,
  `pending_letters`, `active_secrets`, and `action_log` grow
  monotonically. `pending_letters` cannot be removed after delivery
  because multi-stage forgery/impersonation processing reads delivered
  letters. `crime_records` have complex terminal state logic (PARDONED,
  FUGITIVE are live states). `active_secrets` partially exposed secrets
  may still be read. `action_log` is cleared daily (via stale key
  clearing). These require design decisions about retention windows.

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
  (−0.5 Glory, −20 family baseline). GDD files are read-only — this is a known GDD
  internal inconsistency. §57.49.6 and s57.49b are authoritative.

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

### Blocked Sections — Do Not Re-Audit
As of 2026-05-18, every remaining PARTIAL and NOT STARTED section is blocked.
Do not re-audit this; the list is settled. Ask the user before investigating any of these.

**Blocked on world map / adjacency data (not yet available):**
- s4.3 — `is_coastal` flag always false
- s11.7 — sub-tile pathfinding; 5 stub military ActionIDs
- s11.9 — ship movement initiation; naval blockade (per-sub-tile military unit)
- s40 — ASCII map tile positioning and range tracking
- s4.4 — Local Interface / ASCII Map (NOT STARTED)
- s56 — Quest System / ASCII Map (NOT STARTED)

**Blocked on GDD spec gap (no LOCKED spec; do not implement until GDD specifies it):**
- s2.4 — `DECLARE_WALL_EMERGENCY` ActionID: s2.4.14 Decision 6 has no LOCKED spec
  (AP cost, agenda topic format, compliance enforcement all unspecified)
- s43 — Maho spell cast roll TN: GDD s43 does not specify it
- s49 — Artisan progression beyond core crafting: bonsai/garden actions (4 ActionIDs),
  theater composition actions (3 ActionIDs) remain forward-scored but no executor
- s57.40.8 — Commerce rank 5 mastery (price ±20%): GDD section not yet unlocked
- s57.40.9 — Appraisal skill emphasis modifier: GDD section not yet unlocked

**REFERENCE sections** (source material only, design not started): s31–s37, s38,
s44, s45, s54.7, s57.23–s57.24, s57.26–s57.30, s57.41–s57.43, s57.45–s57.46.

### Pending Redesign
(None currently pending.)

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
  stays 0 (blocked on s31 Sense spell). `get_renege_willingness()` values stay 0 (function
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
  LIMITATION: ViolenceSystem.evaluate_violence() itself is not yet called from any ActionID
  executor — the seeding path is wired and tested but requires a violence ActionID to be
  implemented before it fires in actual gameplay.

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
proximity. Two detection paths, both gated on proximity:
- **Sense spell** (Section 31, not yet designed): a shugenja present in the
  same zone may cast Sense to detect kansen residue on a character. TN
  deferred to Section 31 design.
- **Lore: Shadowlands check** during any action that puts the detector in
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
- TN for the Lore: Shadowlands check is deferred to Section 31 / Section 42
  (Taint consequence design). Do not implement Channel 3's detection roll
  until those sections are LOCKED.

**Channel 4 — Direct witnesses (already handled)**
If `witnesses` is non-empty on the CrimeRecord, those characters carry direct
knowledge. They can testify through the existing court/investigation system.
No new code. The witness list in CrimeRecord IS the fourth channel.

**What is not yet implementable:**
- Channel 3 detection roll TN (blocked on Section 31 Sense spell design)
- Kuni/Asako/Kuroiban as Named Characters with UPHOLD_LAW standing objectives
  (blocked on s11.3.5 becoming LOCKED — currently PARTIALLY DESIGNED)
- `CAST_MAHO` as an NPC ActionID (no LOCKED specification exists for maho as
  a deliberate NPC action; do not implement until Section 43 or 55 specifies it)

**Rationale:** Channels 1 and 2 are wirable now — they use entirely existing
systems (insurgency topic generation, zone_event_log, EXAMINE_CRIME_SCENE).
Channel 3 is partially wirable (proximity check) but its TN is a pending design
gap. This mirrors the GDD's intent: "multiple channels, none reliable alone."
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

## Decisions Needed and Blocked Items

Everything below needs a decision, a GDD spec, or a dependency before dev
can proceed. Items are grouped by what's blocking them. Each entry says
what the code currently does, what it needs, and where the answer lives.

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

### C. Blocked on World Map / Adjacency Data

These sections cannot be implemented until the tile/sub-tile map system and
province adjacency data are available. No design decision needed — just
the data.

| Section | What's Blocked |
|---------|----------------|
| s4.3 | `is_coastal` flag — always false; naval context keys unreachable |
| s11.7 | Sub-tile pathfinding; 5 stub military ActionIDs (FORCE_MARCH, EVALUATE_CLAN_STRENGTH, DEPLOY_ARMY sub-tile, etc.) |
| s11.7a | Army movement, levy & mobilization (sub-tile movement) |
| s11.9 | Ship movement initiation; naval blockade (per-sub-tile military unit) |
| s40 | Individual combat — ASCII map tile positioning and range tracking |
| s4.4 | Local Interface / ASCII Map (NOT STARTED) |
| s56 | Quest System / ASCII Map (NOT STARTED) |
| A16 | Forged letter delivery distance (3 provinces — needs adjacency data) |
| — | `rivers` and `roads` fields on ProvinceData — no producer or consumer until map format decided |

---

### D. Blocked on GDD Spec (No LOCKED Section)

These need GDD sections to be written or unlocked before implementation.

| Section | What's Blocked |
|---------|----------------|
| s2.4 | `DECLARE_WALL_EMERGENCY` ActionID — s2.4.14 Decision 6 has no LOCKED spec (AP cost, agenda topic format, compliance enforcement all unspecified) |
| s31–s37 | Spell system — all REFERENCE sections, no design started. Blocks: Sense spell detection TN (Maho Channel 3), spell_intent tag, spells_known field |
| s38 | Kiho system — REFERENCE section |
| s40 | Individual combat — REFERENCE section (beyond map dependency) |
| s43 | Maho spell cast roll TN — GDD does not specify it. Blocks: CAST_MAHO NPC ActionID |
| s48/s48a | LOCKED. Sensei/training and rank advancement values locked. school_rank sync and rank-up topics implemented. PC dojo-visit gate deferred (PC system not yet designed). |
| s49 | Artisan: bonsai/garden (4 ActionIDs), theater composition (3 ActionIDs) — forward-scored, no executor. Core crafting pipeline DONE. |
| s54.7 | Kolat system — blocks 23 Kolat spy network ActionIDs and BRIBE_GARRISON_COMMANDER |
| s56.14 | Full Bloodspeaker cult encounters — trigger layer done, ASCII map encounters blocked |
| s57.40.8 | Commerce rank 5 mastery (price ±20%) — section not unlocked |
| s57.40.9 | Appraisal skill emphasis modifier — section not unlocked |
| s11.3.5 | Kuni/Asako/Kuroiban Named Characters with UPHOLD_LAW standing objectives — PARTIALLY DESIGNED |

**REFERENCE sections** (source material only, design not started): s31–s37,
s38, s44, s45, s54.7, s57.23–s57.24, s57.26–s57.30, s57.41–s57.43,
s57.45–s57.46.

---

### E. Blocked on Other Systems Being Built First

| Blocked Item | Depends On |
|--------------|------------|
| `techniques`, `kiho`, `katas`, `spells_known`, `weapons`, `armor_worn` fields on L5RCharacterData | s40 individual combat, s31–s37 spells |
| `active_quest`, `active_poisons`, `combat_modifiers_pending` fields on L5RCharacterData | s56 quest system, s40 combat |
| `timed_advantages` and `action_blocks` on L5RCharacterData | Individual school technique implementation (s29.15.24 is LOCKED but techniques are per-school) |
| FORCE_MARCH, EVALUATE_CLAN_STRENGTH ActionIDs | Sub-tile army movement (s11.7a) |
| BRIBE_GARRISON_COMMANDER ActionID | Kolat system (s54.7d) |
| 37 Kolat/artisan/theater ActionIDs (scored in objective_alignment.json) | Kolat (s54.7d/s56.14), artisan (s49), theater (s49) |
| SEEK_PRETEXT ActionID executor | GDD s14 Category 13 lists it as both NeedType and ActionID, but no executor mechanics specified |
| `eta` community weight in Bloodspeaker cell placement | No `eta` field on ProvinceData/SettlementData |
| Maho Channel 3 detection roll TN | s31 Sense spell design |
| Hunt player ASCII missions | s56 coordinate system |
| Animal companion ASCII combat | s40/s56 |

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
   fidelity. Second pass: tests against implementation, edge cases. State
   findings explicitly — what's correct, what's a known limitation, what
   would be a tuning concern.
2. **Suggest a list of next options** — present 3–4 distinct directions
   for what to build next, sized for clarity (small / medium / foundational
   / wiring follow-up). Use AskUserQuestion to let the user pick.
