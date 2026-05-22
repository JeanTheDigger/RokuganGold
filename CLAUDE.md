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
| Spiritual insurgency                          | 56.16 (not yet built)|
| Bloodspeaker cult network                     | 56.14 (not yet built)|
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
  skill rank: 0-2→0, 3-4→1, 5-6→2, 7+→3. Values PROVISIONAL. 4 tests.
- **FORGE_IMPERSONATION_LETTER / FORGE_ORDER — full NPC pipeline wired. FIXED.**
  Both had working executors (SecretSystem.resolve_forge_impersonation_letter,
  resolve_forge_order), TN tables, and tests, but were unreachable (no context
  list, no scoring table entries, no personality filter, no metadata population).
  Added to AT_OWN_HOLDINGS, AT_COURT, VISITING context lists. AP cost 1 each
  (GDD s12.8). action_skill_map.json: Forgery/Agility for both (GDD-specified).
  personality_filter.json: blocked by JIN, REI, GI, MAKOTO (same as
  FABRICATE_SECRET — Category 6 Covert forgery actions). objective_alignment.json:
  DAMAGE_RELATIONSHIP (70/55), ACQUIRE_LEVERAGE (50/40),
  SUPPRESS_INVESTIGATION (45/60). Scores PROVISIONAL — GDD specifies action
  purpose but not NeedType scoring weights. Metadata: authority_level from
  Forgery skill rank (1-3→minor, 4-6→moderate, 7+→major); target_npc_id from
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
  PROVISIONAL: uses forger's own lord_rank as proxy. Proper derivation
  requires target character's lord rank lookup, blocked on adding
  target_npc_status to ContextSnapshot or ImmediateNeed.

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
- Delivery distance 3 provinces — PROVISIONAL (blocked on map/adjacency data).
- Forged objective priority 8 — PROVISIONAL (no GDD spec for objective priority).
- Impersonation detection topic TIER_3 — PROVISIONAL (no explicit GDD tier).
- INVESTIGATE_THREAT priority 6 — PROVISIONAL.

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
- s49 — Artisan progression beyond gift/tattoo quality tiers: GDD s49 not LOCKED
- s57.40.8 — Commerce rank 5 mastery (price ±20%): GDD section not yet unlocked
- s57.40.9 — Appraisal skill emphasis modifier: GDD section not yet unlocked

**REFERENCE sections** (source material only, design not started): s31–s37, s38,
s44, s45, s54.7, s57.22–s57.24, s57.26–s57.30, s57.41–s57.43, s57.45–s57.46.

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
  +5 skill bonus now wired to all 7 early-return court action paths
  (GOSSIP, PUBLIC_INSULT, PUBLIC_DEBATE, BROADCAST_SOCIAL, PROVOKE_EMOTION,
  PROBE, DISCERN_NEED, ASK_FOR_INTRODUCTION). 3 tests.
  Champion agenda ordering AI already implemented and wired
  (order_agenda_for_host called in day_orchestrator, 5 tests).
  Travel logistics letter dispatching already implemented
  (_dispatch_winter_court_summons, 7 tests). Late arrival handling already
  implemented (_process_court_attendance, 2 tests).


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
