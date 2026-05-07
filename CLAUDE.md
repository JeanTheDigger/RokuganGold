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

| System                                        | GDD Section(s)     |
|-----------------------------------------------|--------------------|
| Dice engine — Roll & Keep (xky)               | 4.5                |
| Character stats, wound levels, AP budget      | 4.5                |
| Honor & Glory scale and consequences          | 4.6                |
| Resource production / consumption / tick      | 4.3                |
| Province and settlement data                  | 2.3                |
| Shadowlands, Taint, jade rules                | 2.4                |
| Law, legal status, consequence mapping        | 2.8, 57.47         |
| NPC decision engine — core loop               | 55 (all subsects)  |
| NPC decision engine — amendments              | 57 (all subsects)  |
| NeedType enum reconciliation                  | 57.11              |
| ActionID naming reconciliation                | 57.12              |
| Crime record and investigation                | 57.47, 57.16       |
| Commitment registry / social obligation       | 55.31              |
| Travel commitment and oscillation prevention  | 55.29              |
| Military hierarchy                            | 57.21              |
| Zone subtypes and flag matrix                 | 57.36              |
| ASCII map mission generation                  | 56 (all subsects)  |
| Quest seeds                                   | 56.1               |
| Spiritual insurgency                          | 56.16              |
| Bloodspeaker cult network                     | 56.14              |
| Tattoo system                                 | 57.25              |
| Character sheet field index                   | 57.35              |
| Information system / knowledge transfer       | 55.12, 55.7, 55.6 |
| Approach evaluation / action retry            | 55.30              |
| Resource availability modifier                | 55.32              |
| Orphaned objectives (lord death)              | 55.33              |
| Court availability helper                     | 55.34              |

## Directory Structure
```
/gdd/           — GDD markdown files (read-only reference, never edit)
/autoload/      — Godot Autoloads / singletons — registered in Project Settings
/simulation/    — Headless simulation logic: NPC engine, resource tick,
                  world event resolution. NO Node inheritance here.
                  Plain GDScript classes only (class_name, no extends Node).
/shared/        — Data models: CharacterData, ProvinceData, etc.
                  Use Resource subclasses for serialisable data.
/client/        — Player-facing Godot scenes (UI, ASCII map display, etc.)
                  Nothing in /client/ should contain simulation logic.
/tests/         — GUT unit tests. Mirror the /simulation/ and /shared/
                  directory structure inside /tests/.
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

## What's Been Built So Far

All systems below are implemented, tested, and passing. They follow the
single-dice-entry-point and server-authoritative constraints.

### Core Dice & Stats Layer
- **simulation/dice_engine.gd** — THE single authoritative rolling entry point.
  `roll_and_keep()` with exploding 10s, L5R4e 10-dice cap (overflow = +2 per
  excess die), emphasis rerolls. `roll_skill_check()` handles unskilled
  (no explode). `roll_check()`, `contested_roll()`, `roll_initiative()`,
  `roll_damage()`. Seedable RNG for deterministic testing.
- **simulation/dice_result.gd** — DiceResult data class (kept_dice,
  dropped_dice, total, explosions, overflow_bonus).
- **simulation/character_stats.gd** — Pure static functions: `get_ring_value()`
  (min of two traits, Void single), `get_insight()` (rings×10 + skill ranks),
  `get_insight_rank()` (Rank 2 at 150, +25 per rank), `get_armor_tn()`,
  `get_wound_level()`, `get_wound_penalty()`, `is_dead()`.

### Combat & Consequence Systems
- **simulation/wound_system.gd** — `apply_damage()` with armor reduction,
  `heal_wounds()` (dead can't heal), `apply_falling_damage()` (1k1 per 2 tiles).
- **simulation/honor_glory_system.gd** — Honor/Glory/Status/Infamy changes
  clamped 0–10, court honor modifier (−2 to +2), full event table constants,
  atonement system per GDD s4.6.

### Skill & Action Economy
- **simulation/skill_resolver.gd** — Bridge between CharacterData and DiceEngine.
  SKILL_TRAITS dict mapping all L5R4e skills to governing traits.
  SUB_SKILL_TRAIT_OVERRIDES for specializations. `resolve_skill_check()` and
  `resolve_contested_check()` handle trait lookup, rank, emphasis, wound penalty
  automatically.
- **simulation/action_point_system.gd** — 2 AP per IC day, 8 per real day,
  no carryover. `reset_daily_ap()`, `spend_ap()`, `can_spend()`.

### Time
- **simulation/time_system.gd** — 1 tick = 1 IC day = 6 real hours. 360 days/year,
  12 months of 30. Seasons: Spring 90d, Summer 90d, Autumn 60d, Winter 120d.

### Data Models
- **shared/character_data.gd** — `L5RCharacterData` Resource. Full character sheet
  per GDD s22.3. Named L5RCharacterData (not CharacterData) to avoid conflict
  with pre-existing VtM code in scripts/characters/.
- **shared/enums.gd** — Ring, Trait, WoundLevel, Stance, SchoolType, ContextFlag,
  BushidoVirtue, ShouridoVirtue, RING_TRAITS, WOUND_PENALTIES,
  CommitmentType, CommitmentStatus, DeploymentStatus, ZoneSubtype (24 values),
  LordRank, TattooBodyLocation (9), TattooQualityTier, TattooSubjectType,
  TattooAbility (26 named abilities), CulturalReluctance, MilitaryRank (8 ranks),
  OperationalHierarchyType, KolatSect (7 sects), ShipClass (7 classes),
  KnowledgeSource (5 sources), KnowledgeConfidence (3 tiers).
- **shared/province_data.gd** — ProvinceData Resource: terrain, adjacency,
  resources (rice/koku/iron/arms), population PU breakdown, stability. Data model
  only — no map generation (map is being worked on separately by the user).
- **shared/settlement_data.gd** — SettlementData Resource: 12 settlement types,
  infrastructure array, garrison, population.

### NPC Decision Engine
- **simulation/npc_data_structures.gd** — ImmediateNeed (generic target system),
  ScoredAction (8 scoring components with `get_total_score()`), ContextSnapshot,
  ProvinceStatus, competence modifier table per GDD s55.3/s55.5.
- **simulation/npc_decision_engine.gd** — Full 7-phase loop per GDD s55.4:
  1. Build Context — assembles ContextSnapshot from character + world state
  2. Resolve Goal — priority cascade: reactive > crisis > primary > standing > REST
  3. Generate Options — context-flag-specific action lists
  4. Personality Filter — hard removal by bushido/shourido virtue
  5. Score All — 8 components (objective alignment, disposition, personality lean,
     competence, urgency, standing influence, topic position, resource modifier)
  6. Selection — highest score, tiebreakers: ObjAlign > disposition > lower AP > seed
  7. Execution — AP deduction, action record returned
  Scoring helpers reference 8 JSON scoring tables via ScoringTableLoader.
  Full context generators with complete ActionID lists per ContextFlag.
  Objective decomposition routes through ObjectiveDecomposer.

### JSON Scoring Tables & Loader
- **simulation/scoring_table_loader.gd** — Loads and caches 8 JSON tables from
  `systems/npc_engine/data/tables/`. `load_all()`, `get_table()`,
  `get_scoring_tables()`, `get_filter_data()`.
- **systems/npc_engine/data/tables/** — 8 JSON files:
  objective_alignment (82 NeedTypes), personality_lean (14 virtues),
  personality_filter (bushido/shourido blocks), action_skill_map (76+ ActionIDs),
  competence_table (ranks 0-10), disposition_tiers (8 tiers),
  urgency_rules (10 rules), topic_position_alignment.

### Objective Decomposition
- **simulation/objective_decomposer.gd** — Routes standing objectives to
  type-specific decomposition trees per GDD s55.22/s55.24/s55.25/s55.23.
  Political (6), Economic (5), Personal (8), Military (7) standing objectives.
  Stateless per GDD s55.4.2. Unknown NeedTypes pass through unchanged.
  Military objectives include 5 full decomposition trees per GDD s55.23:
  STRENGTHEN_WALL (Kaiu Wall defense with SI/scout/taint/jade/sortie ladder),
  MILITARY_DOMINANCE (dominance ratio comparison + buildup),
  ELIMINATE_SHADOWLANDS (crisis → insurgency → taint topic → proactive),
  MAINTAIN_PEACE (war → tensions → preventive diplomacy),
  BUILD_STRONGEST_FORCE (training level priority ladder).
  New ContextSnapshot fields: wall_statuses (WallStatus class),
  known_clan_strengths, unit_training_counts, available_levy_pu,
  can_sustain_iron_upkeep, active_wars, escalating_conflicts,
  taint_topic_province_ids. ProvinceStatus gains is_wall_province, crisis_type.

### Action Execution & World Mutation
- **simulation/action_executor.gd** — Routes chosen ActionIDs to SkillResolver
  dice rolls. Social/covert/military/admin categories with disposition-based TN
  modifiers. Returns effects dict (disposition_change, glory_change, info_gained,
  province effects).
- **simulation/effect_applicator.gd** — Applies executor results to world state.
  `apply()` mutates character disposition/honor/glory, province stability/garrison/
  report date, and appends to action_log. `apply_day_results()` batch processes
  a full day's results.

### Multi-NPC Wave Resolution
- **simulation/npc_wave_resolver.gd** — `resolve_day()` handles full day
  resolution per GDD s55.13. Reactive events first, then AP waves.
  Status-descending order, Awareness tiebreak. Lord dual-pool.
  `resolve_day_full()` adds execution (dice rolls + effects).
  `resolve_day_applied()` closes the full loop: decision → execution → mutation.

### Information System
- **simulation/information_system.gd** — Knowledge management per GDD s55.12,
  s55.7, s55.6. Five sources (Direct Observation, Daily Conversation, Letters,
  Intelligence Actions, Public Knowledge). Confidence decay: Fresh → Recent →
  Stale (disposition entries never decay). Probe visibility reads action_log to
  reveal target's recent actions. Contact discovery via court observation and
  introductions. Objective knowledge transfer copies relevant entries on
  assignment. CharacterData gains `knowledge_pool` and `known_contacts_by_clan`.

### Day Orchestrator
- **simulation/day_orchestrator.gd** — Single `advance_day()` entry point that
  advances world state by one IC day. Sequence: reset AP → NPCWaveResolver
  `resolve_day_applied()` (decision + execution + mutation) → process info events
  (Probe results wired into InformationSystem) → on season boundary: run
  ResourceTick + decay all characters' knowledge confidence.

### Resource Tick System
- **simulation/resource_tick.gd** — Seasonal resource processing per GDD s4.3.
  Rice consumption/harvest, starvation stages, 5-tier tax cascade,
  personality tax modifiers, iron/koku production, population growth.

### Approach Evaluation (s55.30)
- **simulation/approach_evaluation.gd** — Measure-Then-Decide system.
  Measurement pressure (high-roll-no-effect detection), approach assessment
  tags (EFFECTIVE/CAPPED/INEFFECTIVE), penalty registry with seasonal decay.
  Scoring modifier: +15 measurement bonus, −15 approach penalty (halved after
  1 season, cleared after 2), +10 alternative bonus. NOT YET WIRED into
  NPC Phase 5 scoring — standalone tested only.

### Commitment Registry (s55.31)
- **simulation/commitment_registry.gd** — Six commitment types, consequence
  tables for 4 breaking modes × 3 tiers. Force majeure with personality-
  modified retroactive forgiveness. Phase 5 at-risk penalties (−5/−15/−25
  by tier, cap −40). NOT YET WIRED into NPC Phase 5 scoring.
- **shared/commitment_data.gd** — CommitmentData Resource.

### Military Hierarchy (s57.21)
- **simulation/military_hierarchy.gd** — Five-level org chain queries:
  Company → Legion → Section → Army → Clan. Deployment management,
  commander vacancy detection, operational superior resolution.
  CLAN_ARMY_COUNT: Crab=4, Crane=2, Dragon=2, Lion=4, Mantis=3,
  Phoenix=1, Scorpion=1, Unicorn=3, Imperial=1.
- **shared/military_unit_data.gd** — CompanyData, LegionData, SectionData,
  ArmyData inner classes (all extend Resource).

### Zone Flag Matrix (s57.36)
- **simulation/zone_flag_matrix.gd** — 24 zone subtypes with 8 boolean flags
  each (performance_permitted, wall_art_slot, displayed_art_slot, fusuma_slot,
  tokonoma, bonsai_display_slot, garden_eligible, shrine_eligible). Castle
  scaling by lord rank (Village Headman 1–2 through Imperial 10–11).

### Tattoo System (s57.25)
- **simulation/tattoo_system.gd** — Both decorative artisanal tattoos AND
  Togashi ability tattoos. Cultural reluctance gates by clan/family with
  disposition thresholds. APPLY_TATTOO quality resolution (AP 2–6, TN 15–35,
  skill gates, raise upgrades). Disposition bonds (permanent bidirectional
  +1 to +5). Visibility computation per body location and clothing state.
  Togashi school allotments (Tattooed Order 6, Kikage Zumi 3, Hoshi 2).
  Decorative gate for monk schools. SEEK_TATTOO urgency scaling and BLOCKED
  state. Commission system. Provenance investigation. World gen helpers.
- **shared/tattoo_data.gd** — TattooData Resource (9 body locations).

### Topic Propagation (s16, s15.5, s15.6)
- **simulation/topic_system.gd** — TopicMomentumSystem with three propagation
  features wired into DayOrchestrator:
  1. **Discussion count wiring** — conversation results increment
     `discussion_count_this_day` on TopicData before daily tick, driving
     Tier 4 topic decay/hold mechanics.
  2. **Public knowledge broadcast** — after momentum tick, topics spread to
     characters based on momentum thresholds: Minor (11+) → affected provinces,
     Secondary (26+) → +adjacent provinces, Major (51+) → clan territory,
     Unavoidable (76+) → all characters. Uses ProvinceData adjacency.
  3. **Starting position calculation** — `calculate_starting_position()` per
     GDD s15.5: `(Disposition Anchor Sum × 0.5) + Personality Modifier`,
     clamped ±100. Disposition anchors use subject_role direction
     (BENEFICIARY/VICTIM/PERPETRATOR/NEUTRAL). Personality modifier from
     14-virtue × topic_type:variant table (VIRTUE_MODIFIERS const, s15.6).
     Positions computed on topic acquisition (conversation transfer, broadcast).
  - TopicData gains `topic_type`, `variant` fields.
  - L5RCharacterData gains `topic_positions: Dictionary` (topic_id → float).
  - DayOrchestrator gains `character_province_map` parameter, builds
    `province_clan_map` from provinces. Sequence: conversations → wire
    discussion counts → compute conversation positions → topic tick →
    broadcast → compute broadcast positions.

### Crime Investigation System (s57.15, s57.16, s57.47)
- **simulation/investigation_system.gd** — InvestigationSystem with:
  - `examine_scene()` — Investigation/Perception vs concealment_tn, evidence
    weight by margin, elapsed time penalty, suspect identification at 2+ raises.
  - UPHOLD_LAW self-initiation probability table (14 virtues per GDD s57.16.9a).
  - Witness evidence calculation (awareness bonus, honor penalty).
  - Witness prioritization (present first, then awareness desc, then honor asc).
- **simulation/investigation_decomposer.gd** — Seven-phase investigation loop
  (already existed): travel → examine scene → interview witnesses →
  interview suspects → check alibis → follow leads → resolution.
- **simulation/crime_system.gd** — At-act and at-conviction consequences,
  seppuku system, escalation tracking (already existed).
- EXAMINE_CRIME_SCENE ActionID added to: objective_alignment (90 under
  INVESTIGATE_THREAT), action_skill_map, personality_lean (all 14 virtues),
  action_executor (INTELLIGENCE_ACTIONS category).
- **UPHOLD_LAW self-initiation** — Crime detection creates crime topics
  (topic_type="crime", slug="crime_case_{id}") with momentum 0 (no broadcast).
  Topics are seeded only to witnesses (characters at same physical_location
  as perpetrator) and victims via `_seed_crime_topic_to_knowers()`. Topics
  then spread organically through daily conversations/letters — magistrates
  learn about crimes when someone tells them, not omnisciently.
  DayOrchestrator scans magistrates with UPHOLD_LAW standing objective:
  if crime topic in known_topics + jurisdiction match → activate_uphold_law()
  populates active_case and sets investigating_magistrate_id. Jurisdiction:
  same province prefix, or Emerald Magistrate (Empire-wide).
- **Witness PROBE evidence** — When _process_info_events handles a
  GATHER_INTELLIGENCE action and the prober has an active_case, checks if
  target is a witness (10-20 evidence) or suspect (10-15 evidence) on the
  case. Increments CrimeRecord.evidence_total and marks target as interviewed.
- **Conviction topic generation** — InvestigationSystem.generate_conviction_topic()
  creates TopicData from conviction results: tier from CONVICTION_CONSEQUENCES
  table, momentum by tier (T1=80, T2=50, T3=25, T4=10), category by crime type
  (SUPERNATURAL for maho, POLITICAL for treason, LEGAL for others).
  generate_seppuku_refusal_topic() creates Tier 4 PERSONAL topic.
- TopicData.Category gains LEGAL value.

### Information Architecture Integration (s55.12, s55.6)
- **Confidence penalty in NPC Phase 5 scoring** — `confidence_penalty` field on
  ScoredAction. When target has RECENT intel: −10. When STALE: ObjAlign halved.
  No penalty if character has no knowledge about target (benefit of the doubt).
- **Stale intel gather bonus** — `stale_intel_bonus` field on ScoredAction.
  When target has STALE intel and action is a gather-intelligence type
  (PROBE, READ_CHARACTER, BRIBE_FOR_INFO, EAVESDROP, INTERCEPT_LETTER,
  SEARCH_QUARTERS): +15 bonus per GDD s55.12.
- **`get_best_confidence_on_target()`** added to InformationSystem.
- **Province status & crisis transfer** — `transfer_objective_knowledge()`
  now accepts optional `province_statuses` array. When objective targets a
  province, copies province_status and crisis_data entries to recipient's
  knowledge_pool as FRESH confidence.
- IDENTIFY_CONTACT scoring updated to match GDD s55.7: ASK_FOR_INTRODUCTION=95,
  OBSERVE_COURT_ATTENDEES=85, WRITE_LETTER=60.

### Military Context Wiring (s55.23)
- **build_context() Phase 1** now populates all 8 military intelligence fields
  from world_state: wall_statuses, known_clan_strengths, unit_training_counts,
  available_levy_pu, can_sustain_iron_upkeep, active_wars, escalating_conflicts,
  taint_topic_province_ids. Callers supply data via world_state dictionary keys.

### Character Sheet Field Index (s57.35)
- **shared/character_data.gd** — Consolidated all fields from gap sections:
  military_rank, commanded_unit_id, assigned_company_id (s11.3.18),
  legal_cases (s11.3.14), void_refresh_blocked_until (s57.32),
  kolat_superior_id/kolat_sect (s54.7c), hunt_trophies (s57.38),
  trained_companions (s57.39), aboard_ship_id/passage_request_count_today/
  assigned_ship_id (s57.42), tattoo ability state fields (s57.25.11),
  is_bald. operational_hierarchy_type upgraded from String to enum.

### Tests (GUT v9.3.0)
All in /tests/, one file per system:
- test_dice_engine.gd (~35 tests)
- test_character_stats.gd (~15 tests)
- test_wound_system.gd (~10 tests)
- test_honor_glory.gd (~15 tests)
- test_time_system.gd (~15 tests)
- test_skill_resolver.gd (~20 tests)
- test_action_point_system.gd (~12 tests)
- test_npc_decision_engine.gd (~47 tests)
- test_scoring_table_loader.gd (~15 tests)
- test_action_executor.gd (~25 tests)
- test_effect_applicator.gd (~28 tests)
- test_npc_wave_resolver.gd (~15 tests)
- test_resource_tick.gd (~30 tests)
- test_objective_decomposer.gd (~100 tests)
- test_information_system.gd (~40 tests)
- test_topic_system.gd (~55 tests)
- test_investigation_system.gd (~40 tests)
- test_day_orchestrator.gd (~25 tests)
- test_approach_evaluation.gd (~55 tests)
- test_commitment_registry.gd (~60 tests)
- test_military_hierarchy.gd (~40 tests)
- test_zone_flag_matrix.gd (~53 tests)
- test_tattoo_system.gd (~100 tests)
- test_character_sheet_field_index.gd (~45 tests)
- test_system_wiring.gd (~35 tests)
- test_world_generator.gd (~45 tests)
- test_resource_availability.gd (~25 tests)
- test_court_availability.gd (~15 tests)
- test_orphaned_objectives.gd (~25 tests)
- test_strategic_review.gd (~35 tests)
- test_province_triage.gd (~30 tests)
- test_reactive_decisions.gd (~30 tests)
- test_opportunity_scanner.gd (~25 tests)
- test_primary_objective_decomposer.gd (~35 tests)
- test_favor_system.gd (~36 tests)
- test_personal_visit_system.gd (~25 tests)
- test_inventory_system.gd (~30 tests)
- test_intimidation_system.gd (~30 tests)
- test_disposition_system.gd (~66 tests)
- test_marriage_system.gd (~22 tests)
- test_hostage_system.gd (~22 tests)
- test_court_priority_system.gd (~18 tests)
- test_festival_system.gd (~55 tests)

### Festival System (s11.5)
- **simulation/festival_system.gd** — Empire-wide canonical festivals, Rokuyo
  cycle, championship resolution, and local settlement festival generation per
  GDD s11.5. Rokuyo 6-day rotating cycle (Sensho, Tomobiki, Senbu, Butsumetsu,
  Taian, Shakko) with Taian +1 disposition bonus and Butsumetsu/Tomobiki
  inauspicious for social actions. 23 canonical festivals with month/day/effects.
  Ceasefire detection (Setsuban), labor halt (Chrysanthemum 7-day window),
  marriage bonus day. Championship system: 6 types (Emerald, Jade, Amethyst,
  Ruby, Turquoise, Topaz), 3-stage skill+trait resolution, honor tiebreaker.
  Topaz is annual; others are vacancy-triggered. Emperor's Chosen vacancy
  evaluation with weighted scoring (disposition 20, clan_balance 15,
  skill_relevance 15, honor 10, status 5, personality 10). Local festival
  procedural generation: settlement type → count range, theme categories,
  format words, name patterns, season-spread day picking.

### World Generator
- **simulation/world_generator.gd** — Static factory methods for seeding initial
  world state per GDD s22.4 generation templates and s4.3 resource rules.
  `generate_character(id, name, clan, family, school, insight_rank, dice)` →
  L5RCharacterData with traits, skills, honor/glory, personality, age, koku.
  `generate_province(id, name, clan, family, terrain, total_pu, dice)` →
  ProvinceData with PU distribution, stockpiles, stability, garrison.
  Data tables: 38 family trait bonuses, 28 schools (all Great Clans), clan
  personality weights (bushido/shourido), terrain PU distributions, age ranges.
  Trait advancement: 4 points per rank above 1, 70% priority to focus rings.
  Void: full rate for shugenja, half rate for others. Skill advancement: school
  skills advance 80%/rank, 2-3 non-school skills added per rank.
  Coordinate system and adjacency are NOT set — deferred for later.

### Resource Availability Modifier (s55.32)
- **simulation/resource_availability.gd** — Phase 5 scoring penalty for
  resource-consuming actions. `compute_resource_modifier(action_id, character,
  province_data)` returns 0 to −40 based on koku ratio to cost.
  ACTION_RESOURCE_COSTS: 8 actions mapped to resource type + amount.
  Thresholds: ≥5.0→0, ≥3.0→−5, ≥1.5→−10, ≥1.0→−15, <1.0→−25, ≤0→−40.
  Resource types: koku (ratio), inventory_item (count), troop_pu/rice
  (province data). Wired into `_compute_resource_modifier` in
  npc_decision_engine.gd — `resource_modifier` field on ScoredAction populated
  from `ResourceAvailability.compute_resource_modifier()`.

### Court Availability Helper (s55.34)
- **simulation/court_availability.gd** — `attend_court_or_alternative(
  active_court, upcoming_courts, character, target_npc_id, held_leverage,
  action_log, current_season, known_locations)` → Variant (Dictionary or null).
  4-step priority cascade:
  1. Active court at location → ATTEND_COURT (priority 2)
  2. Upcoming court → TRAVEL_TO highest-prestige court
  3a. Held leverage → SEND_LETTER to target's lord (or target directly)
  3b. Has lord → SEND_LETTER to lord requesting court (once per season)
  3c. Known target location → TRAVEL_TO for personal visit
  4. No options → null

### Orphaned Objectives on Lord Death (s55.33)
- **simulation/orphaned_objectives.gd** — Vassal objective handling when
  assigning lord dies. LORD_DEPENDENT_OBJECTIVES (9 types: BREAK_ALLIANCE,
  ISOLATE_CHARACTER, GAIN_WINTER_COURT_INVITATION, APPOINT_TO_POSITION,
  REMOVE_FROM_POSITION, RESOLVE_CLAN_WAR, OBTAIN_IMPERIAL_EDICT,
  CONQUER_PROVINCE, SABOTAGE_ECONOMY) → ORPHANED on lord death.
  TARGET_DEPENDENT_OBJECTIVES (3 types: EXPOSE_SECRET, INCREASE_KOKU,
  AVENGE) → persist as ACTIVE.
  `process_lord_death(vassals, dead_lord_id, successor_id, objectives_map)`
  marks lord-dependent objectives ORPHANED, returns report targets.
  `resolve_orphaned_objective(objectives, decision, new_objective)` handles
  CONFIRM (reactivate), MODIFY (replace), CANCEL (remove).
  `generate_report_need(vassal, successor_id)` creates REPORT_TO_NEW_LORD need.
  `has_orphaned_vassals(vassals, lord_id, objectives_map)` finds orphaned IDs.

### Strategic Review (s55.10)
- **simulation/strategic_review.gd** — Lord-tier seasonal Strategic Review per
  GDD s55.10. Runs at each season boundary for lord-tier NPCs (status ≥ 5.0
  or lord_id == -1). Produces directives: REASSIGN_VASSAL_OBJECTIVE (orphan
  resolution by bushido virtue + idle vassal assignment), ADJUST_TAX (stability/
  treasury thresholds + personality modifiers), WAR_READINESS (active wars or
  escalating conflicts), SEEK_PEACE (Jin-favored, Yu-blocked, duration gate),
  CALL_COURT (vassal count + crises + winter bonus + Rei modifier), NO_CHANGE.
  Emperor-specific: `run_emperor_review()` adds Winter Court host selection
  (Autumn only, 4 scoring factors + archetype preference), vacancy filling
  (archetype-specific delays: Benevolent/Iron 14, Cunning 45, disposition vs
  skill weights per archetype), Shogun creation (Benevolent: reluctant after 3+
  season crisis + failed diplomacy; Iron: duty/readiness; Cunning/Warlike: never;
  Tyrant: personal enforcer with loyal candidate). Five EmperorArchetype enum
  values. Wired into DayOrchestrator `_run_strategic_reviews()` on season change.

### Province Triage (s55.9)
- **simulation/province_triage.gd** — Multi-target comparative evaluation.
  Scores each province: crisis(+100), insurgency(+80), broken stability(+60),
  volatile(+30), restless(+10), garrison deficit(+20), stale info(+25).
  `get_worst_province()` returns highest-scoring province with recommended
  NeedType (DEFEND_PROVINCE / INVESTIGATE_THREAT / PATROL_PROVINCE / REST).
  `get_top_provinces(count)` for afternoon AP cycling. Wired into
  ObjectiveDecomposer for MAXIMIZE_PROSPERITY and DEFEND_TERRITORY trees.
  Also used by StrategicReview for vassal assignment threat detection.

### Reactive Decision Path (s55.11)
- **simulation/reactive_decisions.gd** — Personality-driven reactive event
  evaluation. Four reactive types: DUEL_CHALLENGE_RECEIVED (Yu/Kyoryoku always
  accept, Rival disposition accepts, Bushido in public accepts),
  FAVOR_REQUESTED (Chugi/Makoto always honor, Friend+ disposition honors,
  Jin honors neutral), COURT_INVITATION (prestige 3+ or Friend+ accepts,
  Rei always attends, Ishi declines low), ACCEPT_TRAINING (sensei rank must
  exceed student, Kanpeki needs 2+ gap, Ketsui needs mentor objective).
  Proactive duel trigger: 3-step evaluation (capability → target assessment →
  personality gate). Dosatsu/Chishiki require intel on target.

### Opportunity Scanner / Primary Objective Self-Selection (s55.26.1)
- **simulation/opportunity_scanner.gd** — Lord-tier and lordless NPC primary
  objective self-selection. Scans known world state through 4 domain scanners
  (political, military, economic, personal). Scores candidates on: standing
  alignment (40%), feasibility (30%), urgency (20%), personality fit (10%).
  Self-selection timing: Chugi never, Seigyo/Ishi 1 season, Makoto/Ketsui 2,
  default 3. Wired into StrategicReview `_evaluate_self_selection()` — lords
  without active primary objectives run the scanner each seasonal review.

### Primary Objective Decomposer (s55.28)
- **simulation/primary_objective_decomposer.gd** — 12 completable primary
  objective decomposition trees: BREAK_ALLIANCE (vulnerability assessment,
  leverage deployment, court/letter routing), ISOLATE_CHARACTER (ally triage,
  progressive severing), GAIN_WINTER_COURT_INVITATION, APPOINT_TO_POSITION,
  REMOVE_FROM_POSITION (leverage gates), RESOLVE_CLAN_WAR (negotiate contacts),
  OBTAIN_IMPERIAL_EDICT (emperor access), EXPOSE_SECRET (acquire→deploy),
  CONQUER_PROVINCE (readiness→declare→battle), INCREASE_KOKU (stability first),
  SABOTAGE_ECONOMY, AVENGE (death=duel, disgrace=expose). Routed through
  ObjectiveDecomposer before standing objectives. ContextSnapshot gains
  `disposition_values`, `known_contacts_by_clan`, `knowledge_pool` fields.

### Favor System (s12.10)
- **shared/favor_data.gd** — FavorData Resource: FavorType (SPECIFIC/GENERAL),
  FavorTier (MAJOR=1/MODERATE=2/MINOR=3), InvocationMethod (LETTER/COURT/
  PERSONAL_VISIT). Fields: creditor_id, debtor_id, terms, is_blackmail_extracted,
  invoked state, response deadline, heir_id.
- **simulation/favor_system.gd** — Full favor lifecycle per GDD s12.10:
  `offer_favor()` creates FavorData, `get_offer_disposition()` returns tier-scaled
  disposition (+6/+10/+15 base, +2/+3/+4 per raise, −5 on critical failure).
  `invoke_favor()` sets deadline (letter=90d, court=1d, visit=90d).
  `honor_favor()` returns +0.1 honor. `break_favor()` returns full consequence
  table (disposition −20/−35/−50, honor −0.5/−1.0/−2.0, glory loss for major,
  witness disposition loss, topic generation). `can_dispute()` / `resolve_dispute()`
  for general favors (contested Sincerity). Expiration: minor=360d, moderate=1080d,
  major=never. Death: major favors inherit to heir, others dissolve.
  `extract_blackmail_favor()` creates general favors from secret tiers.
  `can_unlock_supply_sharing()` for moderate/major favors.
- L5RCharacterData gains `favors: Array[FavorData]`.

### Personal Visit System (s17)
- **simulation/personal_visit_system.gd** — Three visit types (INVITATION_SENT,
  LETTER_ANNOUNCING_ARRIVAL, UNINVITED) with host response mechanics.
  Refuse after invitation: −10 disposition, −0.3 honor. Refuse letter: −2.
  Refuse uninvited: no cost. Accept uninvited: +5 goodwill. Decline invitation:
  −3 disposition. Action filtering: Categories 1, 3, 5 only (no broadcast).
  Intimate setting bonus: +3 disposition on all Category 1 actions (CHARM,
  FLATTERY, SINCERE_COMPLIMENT, SHARED_INTEREST, DELIVER_GIFT, OFFER_FAVOR,
  PERFORM_FOR). Does not apply to Categories 3 or 5.

### Inventory System (s12.11)
- **simulation/inventory_system.gd** — Three storage tiers (ON_PERSON,
  CURRENT_QUARTERS capacity=20, HOME_STORAGE unlimited). Five outfit capacities
  (court_formal=3, casual=5, traveling=8, light_armor=6, heavy_armor=3).
  Item sizes: SMALL=1, MEDIUM=2, LARGE=3. Seven categories (DOCUMENT, SEAL,
  GIFT, WEAPON, SCROLL, VALUABLE, EVIDENCE). Transfer: give_directly (same
  location), send_by_messenger (transit state), move_to_storage. Covert:
  pickpocket (on-person only), search_quarters (quarters only). Evidence
  tracking: `has_evidence()`, `get_evidence_items()`. Concealment check for
  court formal overflow. `destroy_item()` for eliminating evidence.

### Intimidation & Blackmail System (s12.9)
- **simulation/intimidation_system.gd** — Three intimidation contexts:
  BLACKMAIL (secret-tier free raises: T1=3, T2=2, T3=1, T4=0; favors=margin/5),
  PRIVATE (in-person: TN+10+5/raise; by letter: TN+5 only),
  PUBLIC (court: TN+10+5/raise, −2 disposition with Rei/Gi/Meiyo witnesses).
  All produce compliance (binary active/inactive). Honor Rank as flat defense
  bonus. Disposition modifiers: friend/ally +5, enemy −5.
  Honor costs: blackmail/public −0.3, private −0.2. Infamy: 0.1/0.1/0.05.
  Pushback TN = 15 + intimidator's skill rank. Compliance ends at Friend
  disposition or when leverage removed.

### Disposition System (s12.2)
- **simulation/disposition_system.gd** — Core relationship layer per GDD s12.2.
  Scale: -100 to +100, 8 named tiers (Blood Enemy to Devoted). Three modifier
  categories: permanent (14×14 virtue compatibility matrix, family bonds),
  historical (27 event types with start/floor/decay), temporary (14 conditional
  modifiers with durations). Roll modifiers: target's disposition gives Free
  Raises (+31) or additional Raises required (-31). Authenticity modifier:
  dice kept penalty for hostile actions toward friends or positive actions
  toward enemies. Supply sharing ratio (Friend+ only, scaled 50-100%).
  Court action disposition values for all 7 targeted actions. Cohabitation
  passive gain (+0.1/day). Family/Clan ripple (+2/+1, caps 30/15).

### Marriage System (s22.7)
- **simulation/marriage_system.gd** — Political marriage institution per GDD s22.7.
  Three types: WITHIN_FAMILY (no boosts), BETWEEN_FAMILIES (family +5),
  CROSS_CLAN (clan +8, family +5, favor owed). Boost decay: clan fades over
  80 seasons, family over 40 seasons. Caps: clan +20, family +15.
  Birth family disposition floors: +15 (family), +8 (clan) — permanent for
  the married character. Pregnancy: seasonal chance based on spouse disposition
  (0%/5%/15%/25%). Gempuku at 72 seasons (18 IC years). Benten Festival bonus.

### Hostage System (s22.9)
- **simulation/hostage_system.gd** — Hitojichi per GDD s22.9. Capture via
  siege surrender or battle. Personality gates: Yu less likely captured (0.5x),
  Ishi committed never escapes. Escape: Stealth+Agility vs settlement TN
  (town=20, castle=25, major=30, +2 per 0.5 excess PU). Bushi only, Stealth 3+.
  Success: escape + family honor loss. Failure: execution. Critical: public
  execution + catastrophic honor loss. Leverage: rank 3+=3, rank 5+/champion=8.
  Action restrictions: no travel, no actions targeting captor.

### Court Priority System (s15.8)
- **simulation/court_priority_system.gd** — NPC court selection: lord-assigned
  → primary objective → personal relevance → standing objective → court status.
  Early departure costs: host (honor+glory loss), guest (-3 disposition),
  proxy (mandate violation). Objective negligence: passive -0.1/season,
  deliberate -0.5 immediate. Otomo institutional leans: Gossip +15, Disclose
  +10, blocks inter-clan goodwill actions, escalates at Rival disposition.

### What's Next
1. World generation coordinate system and adjacency

### Systems Wired into NPC Loop
The following subsystems are now integrated into the NPC decision loop:
- **ApproachEvaluation** — Phase 5 scoring: `approach_modifier` field on
  ScoredAction. Measurement bonus (+15), approach penalty (−15, decays),
  alternative bonus (+10). Seasonal decay runs on season boundary in
  DayOrchestrator.
- **CommitmentRegistry** — Phase 5 scoring: `commitment_at_risk` field on
  ScoredAction (−5/−15/−25 by tier, cap −40). Daily deadline processing
  runs in DayOrchestrator after wave resolution.
- **TravelCommitment** — Phase 5 scoring: `travel_redirect_penalty` field
  on ScoredAction (0/−5/−15/−30). Travel redirect count read from primary
  objective in NPCWaveResolver.
- **ZoneFlagMatrix** — Phase 1: `zone_subtype`, `zone_flags`, `sublocation`
  populated in ContextSnapshot via `build_context()`. Phase 3: zone-gated
  actions (PUBLIC_PERFORMANCE, PERFORM_FOR, PERFORM_WORSHIP, PERFORM_RITUAL)
  filtered from option list when zone flags forbid them.
- **CrimeSystem** — Post-execution: DayOrchestrator scans day results for
  `detection_risk: true` in covert action effects, determines witnesses via
  `_get_witnesses_at_location()` (characters at same physical_location),
  creates CrimeRecord via `CrimeSystem.create_crime_record()` (with witnesses),
  applies at-act honor consequences, and creates a crime topic (Tier 4,
  topic_type="crime", momentum=0). Crime topics are seeded ONLY to witnesses
  and victims via `_seed_crime_topic_to_knowers()` — they do NOT broadcast
  globally. Topics spread organically through conversations/letters. Magistrates
  learn about crimes when witnesses tell them, then UPHOLD_LAW self-initiation
  triggers. Witness PROBE evidence wired into _process_info_events.
  Action-to-crime-type mapping: EAVESDROP/SEARCH_QUARTERS/INTERCEPT_LETTER/
  FABRICATE_SECRET → DISHONORABLE_CONDUCT, BRIBE_FOR_INFO → SKIMMING.
- **MilitaryHierarchy** — Phase 1: `military_rank`, `commanded_unit_id`,
  `assigned_company_id` populated in ContextSnapshot. Phase 3: military
  order actions (ORDER_BATTLE, CONDUCT_RAID, etc.) gated behind
  `commanded_unit_id >= 0`. DISPATCH_COURTIER gated behind Shireikan rank.
  Phase 7 (execution): ActionExecutor validates commander authority, checks
  deployment status (garrisoned units blocked from offensive actions),
  verifies legion coordination and section campaign authority. Military data
  dict threaded through NPCWaveResolver → DayOrchestrator.
- **ResourceAvailability** — Phase 5 scoring: `resource_modifier` field on
  ScoredAction. `_compute_resource_modifier` in npc_decision_engine.gd calls
  `ResourceAvailability.compute_resource_modifier()`. Koku ratio thresholds:
  ≥5x→0, ≥3x→−5, ≥1.5x→−10, ≥1x→−15, <1x→−25, broke→−40.
- **CourtAvailability** — Decomposition: all 13 ATTEND_COURT returns in
  ObjectiveDecomposer replaced with `_court_or_alternative()` wrapper that
  calls `CourtAvailability.attend_court_or_alternative()`. ContextSnapshot
  gains `lord_id`, `active_court_at_location`, `upcoming_courts`,
  `held_leverage`, `known_npc_locations` — populated in `build_context()`.
  When no court or alternative is available, falls through to REST or
  tree-specific fallback.
- **OrphanedObjectives** — Post-execution: DayOrchestrator `_process_lord_deaths`
  processes `death_events` array. For each dead lord, calls
  `OrphanedObjectives.process_lord_death()` to mark lord-dependent vassal
  objectives ORPHANED, then generates REPORT_TO_NEW_LORD needs for affected
  vassals. `successor_map` provides heir IDs; falls back to
  `operational_superior_id`. New params on `advance_day()`: `death_events`,
  `successor_map`.
- **FestivalSystem** — Daily: `_process_festivals()` runs each day before
  wave resolution. Sets world_state flags: `is_ceasefire_day`,
  `is_labor_halt_day`, `is_taian`, `is_inauspicious_for_social`, `rokuyo`.
  Returns active festivals, effects, honor/glory gains. NPC loop can read
  world_state flags to gate military actions (ceasefire) and labor
  (Chrysanthemum halt).
- **DispositionSystem** — Daily: `_apply_cohabitation()` increments
  `cohabitation_days` dict on L5RCharacterData for all character pairs
  sharing a `physical_location`. Seasonal: `_decay_all_historical_modifiers()`
  runs on season boundary, calling `DispositionSystem.decay_historical_modifier()`
  for all entries in each character's `historical_modifiers` dict.
  L5RCharacterData gains `historical_modifiers`, `temporary_modifiers`,
  `cohabitation_days` fields.
- **FavorSystem** — Daily: `_process_favors()` runs
  `FavorSystem.process_expirations()` and
  `FavorSystem.process_deadline_breaches()` on the favors array. New param
  on `advance_day()`: `favors`.

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
