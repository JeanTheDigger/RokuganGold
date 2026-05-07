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
  stability. Geography and settlement references only — no PU, no stockpiles.
  Data model only — no map generation (map is being worked on separately by
  the user).
- **shared/settlement_data.gd** — SettlementData Resource: 12 settlement types,
  infrastructure array, population_pu, farming_pu, mining_pu, town_pu,
  military_pu, garrison_pu, rice_stockpile, koku_stockpile. Per GDD s4.3.7,
  all PU breakdown and resource stockpiles live at settlement level.
- **shared/clan_data.gd** — ClanData Resource: clan_name, iron_stockpile,
  arms_stockpile, champion_id, province_ids. Iron/arms pool at clan level
  per GDD s4.3.10.

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
  Fully settlement-based: all PU reads and stockpile writes target
  SettlementData. Rice consumption/harvest, starvation stages, 5-tier tax
  cascade (deposits collected rice to settlements), personality tax modifiers,
  iron production (pools to ClanData), koku production, population growth.
  Province-level helpers sum PU across settlements.

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
- test_military_hierarchy.gd (~47 tests)
- test_zone_flag_matrix.gd (~53 tests)
- test_tattoo_system.gd (~100 tests)
- test_character_sheet_field_index.gd (~45 tests)
- test_insurgency_system.gd (~60 tests)
- test_system_wiring.gd (~48 tests)
- test_rice_market_system.gd (~35 tests)
- test_regional_price_modifiers.gd (~25 tests)
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
- test_travel_system.gd (~30 tests)
- test_objective_progress.gd (~35 tests)
- test_festival_system.gd (~55 tests)
- test_simulation_scheduler.gd (~20 tests)
- test_gift_giving_system.gd (~30 tests)
- test_biological_family.gd (~30 tests)
- test_collective_disposition.gd (~35 tests)

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
  ProvinceData with stability (no PU, no stockpiles).
  `generate_settlement(id, name, province, type, pop, terrain)` → SettlementData
  with PU distribution, garrison_pu, rice_stockpile (2 seasons buffer),
  koku_stockpile (proportional to town_pu).
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

### Travel System (s55.29)
- **simulation/travel_system.gd** — NPC movement between settlements per GDD
  s55.29. Placeholder distance dictionary (symmetric key lookup, swappable
  when map is built). Terrain cost constants (plains=1, forest=2, mountains=3).
  `begin_travel()` sets origin/destination/days_remaining on character.
  `process_travel_tick()` decrements daily, triggers arrival on completion.
  `cancel_travel()` returns to origin. `change_destination()` mid-travel
  redirection. `get_context_flag()` returns TRAVELING or AT_OWN_HOLDINGS.
  `apply_forced_march()` reduces travel by 1 day at 5 morale per day saved.
  River crossing costs (normal=1, spring=2). Minimum 1 travel day.
  Wired into DayOrchestrator (`_process_travel()` runs before wave resolution),
  ActionExecutor (BEGIN_TRAVEL/CHANGE_DESTINATION call TravelSystem), and
  NPC engine Phase 1 (`build_context()` auto-sets TRAVELING context flag).

### Objective Progress Functions (s55.29.3)
- **simulation/objective_progress.gd** — 12 per-objective-type progress functions
  (0.0–1.0) evaluated seasonally per GDD s55.29.3. Drives stall detection via
  TravelCommitment.update_progress()/is_stalled(). Discovery confidence gate
  applied to 4 objectives (ISOLATE_CHARACTER, REMOVE_FROM_POSITION,
  EXPOSE_SECRET, SABOTAGE_ECONOMY) — caps near-completion at 0.85 when
  investigation is insufficient (min 2 seasons AND 4 intel actions required
  for 0.95 cap). `evaluate_all_objectives()` seasonal entry point evaluates
  all characters' primary objectives, updates progress, detects stalls.
  Wired into DayOrchestrator on season boundary (before strategic reviews).
  Progress functions use existing game state fields — where upstream systems
  don't exist yet (SecretSystem, WarSystem, SiegeSystem), those components
  contribute 0 and will activate when built.
- **Arrival observation** — `InformationSystem.record_location_observation()`
  records FRESH location knowledge when NPCs arrive at a settlement.
  DayOrchestrator calls `_process_arrival_observation()` after travel tick,
  updating arriving characters' `met_characters` and `knowledge_pool` with
  co-located NPCs.

### NPC Engine Amendments (s57.1–s57.5, s57.17, s57.19, s57.20)
- **s57.1 Allowlist Model** — Actions not listed in objective_alignment.json
  for the current NeedType are blocked from the scoring pool. Implemented as
  `apply_allowlist_filter()` between Phase 4 and Phase 5. Prevents unlisted
  actions from winning via accumulated personality/disposition/competence scores.
- **s57.2 Score Compression** — Social/political NeedTypes already compressed
  to 10-point top-cluster bands (65–75). IDENTIFY_CONTACT remains uncompressed
  pending dedicated tuning pass per GDD.
- **s57.3 Disposition Tiers** — Already applied. RIVAL (−5,+5),
  ACQUAINTANCE (+5,−5), DEVOTED (+25,−25). Full gradient across all tiers.
- **s57.4 Ishi Exemption** — Ishi-virtue NPCs skip approach_ineffective and
  approach_capped penalties in `ApproachEvaluation.get_scoring_modifier()`.
  Measurement bonus still fires. Ishi is the only virtue that continues a
  failed approach indefinitely.
- **s57.5 WRITE_LETTER Extraction** — Removed from all context action lists
  in Phase 3. Daily letter pass: `resolve_daily_letter()` runs after AP
  resolution via `_process_daily_letter_pass()` in DayOrchestrator. Each NPC
  gets one free letter per IC day, targeting the best recipient based on
  SEND_LETTER alignment entries.
- **s57.20 New Decision Paths** — 3 NeedTypes added: BUILD_INFRASTRUCTURE,
  ARRANGE_MARRIAGE, FILL_VACANCY. 8 ActionIDs: FOUND_VILLAGE,
  BUILD_FORTIFICATION, BUILD_SHRINE, FOUND_TEMPLE, FOUND_MONASTERY,
  COMMISSION_SHIP, ARRANGE_MARRIAGE, APPOINT_TO_POSITION. Added to
  action_skill_map.json, personality_lean.json, context action lists
  (AT_OWN_HOLDINGS, AT_COURT), and ActionExecutor (ADMINISTRATIVE category).
- **s57.17 Operational Superior Support** — `MilitaryHierarchy.get_direct_subordinates()`
  returns characters where `lord_id == argument OR operational_superior_id == argument`,
  deduplicated. `get_direct_vassals()` retained as alias. DayOrchestrator
  `_get_vassals()` delegates to `get_direct_subordinates()` so strategic reviews
  and vassal assignment include operational subordinates (military commanders).
- **s57.19 Engine Table Entries** — 3 new ActionIDs: PURIFY_TAINTED_GROUND
  (Lore: Shadowlands, Category 6, Kuni Shugenja), FORTIFY_WALL_SECTION
  (Engineering, Category 6, Kaiu Engineer), SEAL_WALL_BREACH (Engineering,
  Category 6, 2 AP, Kaiu Engineer Rank 3+). Added to action_skill_map,
  objective_alignment (MANAGE_TAINT, MAINTAIN_FORTIFICATION, DEFEND_PROVINCE,
  PERFORM_RITUAL), personality_lean (all 14 virtues), context action list
  (AT_OWN_HOLDINGS), and ActionExecutor (ADMINISTRATIVE category).

### Insurgency System (s11.11)
- **simulation/insurgency_system.gd** — Province-level insurgency lifecycle per
  GDD s11.11. Shared 5-phase mechanics (Spawning, Hidden Growth, Detection,
  Active Crisis, Suppression) for 7 insurgency types: Maho Cult, Peasant Revolt,
  Ronin Bandit Uprising, Province Taint Manifestation, Nezumi Infestation,
  Urban Criminal Network, Pirate (Wako) Fleet.
  `get_stability_tier()` maps 0–100 stability to 4 tiers (Stable/Restless/
  Volatile/Broken). `compute_stability_change()` seasonal delta from starvation,
  war, raids, insurgencies, garrison, peace bonus. `get_eligible_types()` per
  tier with Maho 2% in Stable, Nezumi anywhere, Taint from PTL≥3, Pirates
  coastal only. `get_spawn_chance()` type-specific probabilities with lord
  virtue, starvation, garrison modifiers. `try_spawn()` d100 via DiceEngine.
  `process_hidden_growth()` strength +1, concealment −1, hint at str 5,
  auto-detect at concealment 0. `attempt_detection()` success/partial/failure.
  `get_suppression_tn()` strength×5 standard, ×7 for ronin bandits.
  `resolve_suppression()` success(−3)/partial(−1)/failure(0)/critical(+1);
  maho/taint max −1 without shugenja. `resolve_coordinated_suppression()`
  cumulative with leader bonus. `compute_ptl_change()` maho/taint gains,
  adjacent bleed at PTL 6+, jade halves bleed, natural decay −0.5.
  `get_crisis_tier()` type-specific tier mapping. `get_strength_10_consequence()`
  oni_manifestation/province_seized/army_scale_threat/etc.
  `attempt_ronin_hire()` TN=str×5 courtier+awareness roll.
  `compute_susceptibility()` hidden modifier from disposition/honor/glory/
  shourido. `is_immune_to_corruption()` Ishi immunity. Economic effects:
  `get_koku_drain()`, `get_rice_drain()`, `get_pu_loss_on_suppression()`.
  `process_season()` full seasonal tick combining growth, spread, spawn.
- **shared/insurgency_data.gd** — InsurgencyData Resource: insurgency_id, type,
  province_id, settlement_id, strength (1–10), concealment (1–10), detected,
  seasons_active, season_spawned, spread_from_id.
- **shared/enums.gd** gains InsurgencyType (7 values), StabilityTier (4 values).
- **shared/province_data.gd** gains `province_taint_level: float = 0.0`.
- Wired into DayOrchestrator: `_process_insurgencies()` runs on season boundary
  after historical modifier decay. Reads PTL from `province_taint_level` on
  ProvinceData. Appends spawned insurgencies, removes suppressed ones.
  New params on `advance_day()`: `insurgencies`, `next_insurgency_id`.
  Return dict gains `insurgency_results`.
- ASCII map investigation module and Settlement Building Framework deferred
  until ASCII map system is built.

### Rice Market & Trade Route System (s4.3.18)
- **simulation/rice_market_system.gd** — Decentralized rice market per GDD s4.3.18.
  `compute_surplus()` calculates lord's genuine surplus above 4-season consumption
  buffer. `create_posting()` lists rice for sale at a set price. Price adjustment:
  +0.25 Koku per season of sales, −0.25 per unsold season (floor 0.25).
  `should_withdraw()` returns true at floor price with no buyers.
  Disposition-based purchase priority: Friend (31+) → Acquaintance (−10 to +30)
  → Rival (−11 and below). Blood Enemy (−60) blocked entirely.
  `resolve_purchases()` processes all postings against buy orders with priority
  ordering and budget limits. Intra-clan rice sharing: `share_rice()` transfers
  rice between same-clan provinces, generating Honor scaled to recipient need
  (Shortage +0.1/+0.2, Hunger +0.3, Famine +0.5, Famine resolved +1.0).
  Trade route koku bonus: `compute_trade_route_koku()` sums active route bonuses,
  skipping disrupted routes. Route disruption/restoration helpers.
- **shared/trade_route_data.gd** — TradeRouteData Resource: route_id,
  province_a_id, province_b_id, is_naval, is_disrupted, disruption_reason,
  koku_bonus_per_season. `connects()`, `other_end()` helpers.
- **shared/rice_posting_data.gd** — RicePostingData Resource: lord_id,
  province_id, quantity, price_per_unit, seasons_sold, seasons_unsold.

### Regional Price Modifiers (s11.8)
- **simulation/regional_price_modifiers.gd** — Clan territory price modifiers
  per GDD s11.8. CLAN_MODIFIERS dictionary for all 8 Great Clans with item
  category → modifier mappings (−40% to +50%). `get_territory_modifier()` looks
  up modifier by clan and item category. `compute_final_price()` applies
  territory modifier then Commerce skill reduction (−10% on roll ≥ TN 15).

### CONDUCT_COMMERCE Alignment (s57.9)
- **objective_alignment.json** gains CONDUCT_COMMERCE NeedType with 7 actions:
  CONDUCT_COMMERCE (100), BEGIN_TRAVEL (60), PURCHASE_MARKET (50),
  NEGOTIATE (45), WRITE_LETTER (35), ASSESS_PROVINCE_STATUS (30), DO_NOTHING (0).

### Clan & Family Collective Disposition (s12.2b)
- **simulation/collective_disposition.gd** — `CollectiveDisposition` class
  per GDD s12.2b. Holds the locked PROVISIONAL pre-Scorpion-Coup baselines
  as const dicts: 21 Great Clan ↔ Great Clan pairs, 28 Minor Clan ↔ Great
  Clan pairs, 8 Minor ↔ Minor pairs (`STARTING_CLAN_BASELINES`); plus 41
  intra-clan family pairs and 11 cross-clan family pairs
  (`STARTING_FAMILY_BASELINES`). Symmetric `make_pair_key(a, b)` lookup —
  lexicographic sort + "||" delimiter so order doesn't matter.
  `get_clan_baseline` / `get_family_baseline` return the int baseline (0
  for unlisted, intra-clan/family, or empty-string pairs).
  `compute_seed_disposition(actor, target, clan_baselines, family_baselines)`
  applies the GDD formula: `clan × 0.25 + family × 0.50` rounded to int.
  `seed_first_meeting()` writes the seed to `actor.disposition_values[target.id]`
  on first meeting only — preserves any existing value.
  `apply_event_ripple(actor, target, personal_change, ...)` mutates the
  baseline dicts with proportional changes (`× 0.05` clan, `× 0.20` family).
  Specific event helpers: `apply_marriage` (with `champion_level=true` for
  Champion-tier marriage), `apply_clan_war_declared` (-10), 
  `apply_clan_peace_treaty` (+5), `apply_harvest_destruction` (-5),
  `apply_family_lord_raid` (-3), `apply_family_betrayal` (-10),
  `apply_intra_clan_rice_sharing` (+2), `apply_family_duel_death` (-5).
  `make_starting_baselines()` factory returns a deep copy of the locked
  data, ready to be stored as world state. Baselines never decay — they're
  collective historical memory, only changed by deliberate events.
- **simulation/information_system.gd** — `add_contact()` gains optional
  4th/5th/6th args (contact char, clan baselines, family baselines). When
  supplied, calls `CollectiveDisposition.seed_first_meeting()` on first
  meeting so the new disposition_values entry starts at the clan+family
  seed instead of 0. Existing 3-arg callers are unaffected.

### Biological Family Web (s22.6)
- **shared/ancestor_record.gd** — `AncestorRecord` Resource for lightweight
  G3/G4 historical records: ancestor_id, name, clan, family, generation
  (3 = grandparent, 4 = great-grandparent), ic_year_born/died, spouse_name,
  children_names, maternal flag. `is_living(current_ic_year)` helper.
- **shared/character_data.gd** — Adds `grandparent_records: Array[AncestorRecord]`
  and `great_grandparent_records: Array[AncestorRecord]` alongside the
  existing `mother_id`/`father_id`/`sibling_ids`/`children_ids`/`spouse_id`
  family-web fields.
- **simulation/biological_family.gd** — `BiologicalFamily` traversal class
  per GDD s22.6. Eight-value Relationship enum (NONE, SELF, SIBLING, PARENT,
  CHILD, GRANDPARENT, GRANDCHILD, FIRST_COUSIN, CROSS_CLAN_MARRIAGE_RELATIVE).
  `get_relationship(a, b, chars_by_id)` is the main classifier — checks
  blood relations first (sibling via shared parents OR sibling_ids
  including half-sibs; parent/child direct id; grandparent/grandchild
  two-hop; first cousin via aunt/uncle), then the cross-clan-marriage tie
  (b is a blood relative of a's spouse, with both clans differing).
  `get_family_modifier(rel)` returns the integer bond value from the
  existing `DispositionSystem.FAMILY_BONDS` table (sibling=20, parent_child=20,
  grandparent_grandchild=12, first_cousin=6, cross_clan_marriage=4) — bonds
  are owned by DispositionSystem; this class is only the classifier.
  `compute_pairwise_modifier(a, b, chars_by_id)` is the end-to-end helper.
  Direct lookups: `get_parent_ids`, `get_sibling_ids`, `get_child_ids`.
  Two-hop: `get_grandparent_ids`, `get_grandchild_ids`, `get_aunt_uncle_ids`
  (includes half-aunts/uncles via shared grandparents), `get_first_cousin_ids`.
  `get_generation_lineage(character, chars_by_id)` returns the four-generation
  lineage dict (G1 self, G2 parents, G3 grandparents as character ids, G4
  as AncestorRecord entries pulled from parents' grandparent_records and
  self's great_grandparent_records). Sentinel-safe: -1 parent ids are
  skipped rather than treated as a match.
  `compute_all_family_bonds(actor, chars_by_id)` returns
  `{ other_id: bond_value }` for every blood relative + cross-clan-marriage
  relative reachable from the actor.

- **Family bond wiring into disposition** —
  `DispositionSystem.get_effective_disposition(actor, target_id, chars_by_id={})`
  returns the stored `disposition_values` entry plus the family bond, clamped
  -100..100. Falls back to a plain lookup when chars_by_id is empty.
  `NPCDecisionEngine.build_context` accepts an optional `chars_by_id` third
  argument; when provided, it walks `compute_all_family_bonds` and layers the
  bonds onto `ctx.dispositions` and `ctx.disposition_values`. `run()` accepts
  the same optional arg and threads it to build_context. NPCWaveResolver
  passes characters_by_id into the run() and build_context() calls inside
  the full-execution paths (`_resolve_reactive_events_full`,
  `_resolve_character_wave_full`, `_execute_decision`); DayOrchestrator
  threads it into the daily letter pass. Decision-only paths and
  civilian-order resolution still use the empty-dict default — they
  degrade gracefully without family-bond awareness. Bonds are recomputed
  each context build, so they never decay and stay in sync with the family
  graph automatically.

### Gift-Giving System (s12.3)
- **simulation/gift_giving_system.gd** — Gift resolution per GDD s12.3 with
  mechanics from s49 (quality tiers + Free Raises) and s15.4 (Deliver Gift
  court action). Pure simulation class, no Node inheritance.
  Six QualityTier values (Mundane/Normal/Fine/Exceptional/Masterwork/Legendary)
  with Free Raise lookup (0/0/+1/+2/+3/+4). Ten GiftCategory values: 8 valid
  (ART, WRITING_IMPLEMENTS, TEA_IMPLEMENTS, POETRY_SCROLLS, INCENSE,
  ACCESSORIES, FOOD_DRINK, RITUAL_OBJECTS) plus WEAPON and ARMOR (forbidden).
  Five RecipientArchetype values (BUSHI, COURTIER, SHUGENJA, SCHOLAR, MONK)
  with sparse APPROPRIATENESS_MATRIX — unmapped pairs default to NEUTRAL.
  Six Appropriateness levels (IDEAL, APPROPRIATE, NEUTRAL keep full Free
  Raises; REDUCED halves them; INAPPROPRIATE/INSULTING zero them).
  Forbidden gifts: weapons (unless Legendary blade — the s12.3 once-in-a-
  generation exception) and any armor. `is_forbidden()`, `get_appropriateness()`,
  `compute_effective_free_raises()` (history points stack, clamped non-negative).
  `resolve_deliver_gift()` returns dict with outcome (success/failure/
  critical_failure/forbidden), disposition_change, obligation_created flag,
  and modifiers_to_apply (ready-to-append temp dispositions). Roll: Awareness
  + Etiquette vs TN 15, +5 per effective Free Raise as flat bonus. Success:
  full quality disposition + gift_obligation modifier. Failure: half
  disposition, no obligation. Critical failure (margin ≤ -10): -5 disposition.
  Forbidden gift: short-circuit -5 disposition, no roll. Quality tier
  disposition values pulled from existing `DispositionSystem.GIFT_DISPOSITION`
  table; temp modifier keys (gift_normal/fine/exceptional/masterwork) reuse
  the existing `DispositionSystem.TEMPORARY_EVENTS` registry.
  `default_archetype_for_school()` maps SchoolType to a default archetype.
  `select_best_gift(items, archetype)` picks the best gift dict from an
  inventory array, scoring on effective Free Raises with quality tier as
  tiebreaker, skipping forbidden categories.

- **DELIVER_GIFT executor wiring** — `ActionExecutor.execute()` accepts an
  optional `characters_by_id: Dictionary` and special-cases DELIVER_GIFT
  before the generic social path. `_try_execute_deliver_gift()` looks up the
  recipient, picks the best gift from the giver's items via
  `GiftGivingSystem.select_best_gift()`, runs `resolve_deliver_gift()`, and
  emits effects: `recipient_disposition_change`, `recipient_modifiers`,
  `consume_item_id`, `gift_outcome`, `gift_tier`, `gift_subtype`,
  `gift_free_raises`. Falls through to the generic CHARM-style social path
  when no recipient is resolvable or the inventory has no giftable item.
  Failure outcomes set `effects["failed"] = true` so EffectApplicator's
  early-return guard does not skip recipient mutation.

- **EffectApplicator recipient-side effects** — New `_apply_recipient_effects()`
  handles three new effect keys: `consume_item_id` removes the item from
  giver's `items` array; `recipient_disposition_change` mutates
  `recipient.disposition_values[giver_id]` (clamped); `recipient_modifiers`
  appends each modifier dict to `recipient.temporary_modifiers[giver_id]`
  (initialized to `[]` if absent). Establishes the convention that
  `temporary_modifiers` is keyed by the source character's id.

- **Inventory storage on character** — `L5RCharacterData.items: Array[Dictionary]`
  added per s12.11. Item dicts are produced by
  `InventorySystem.create_item()` or the new `create_gift_item(item_id, name,
  gift_subtype, quality_tier, size)` wrapper that tags items with a
  `gift_subtype` key matching `GiftGivingSystem.GiftCategory`.

- **NPCWaveResolver threading** — `characters_by_id: Dictionary` is now
  threaded from `resolve_day_applied()` (where DayOrchestrator already
  supplies it) down through `resolve_day_full`, `_resolve_reactive_events_full`,
  `_resolve_ap_waves_full`, `_resolve_character_wave_full`, and
  `_execute_decision()` into `ActionExecutor.execute()`. Optional with
  `{}` default — the parameter is dormant for resolvers that don't need it.

### Simulation Scheduler & World State
- **scripts/managers/world_state.gd** — `WorldStateData` autoload singleton
  (registered as `WorldState`). Holds all persistent data arrays:
  characters, provinces, settlements, clans, topics, insurgencies, etc.
  `rebuild_characters_by_id()` refreshes the ID lookup dictionary.
  `advance_one_day()` delegates to `DayOrchestrator.advance_day()` with
  all world state parameters.
- **scripts/managers/simulation_scheduler.gd** — `SimulationScheduler` autoload
  (registered as `SimScheduler`). Checks real wall-clock time each frame,
  converts UTC to EST (with DST), fires `WorldState.advance_one_day()` at
  4 checkpoints per real day (EST hours 0, 6, 12, 18 = every 6 real hours).
  Tick key format `YYYY-MM-DD-HXX` prevents double-firing on restart.
  State persisted to `user://simulation/scheduler_state.txt`.
  `force_tick()` for manual advancement. `tick_completed` signal emitted
  after each advancement.

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
- **TravelSystem** — Daily: `_process_travel()` runs
  `TravelSystem.process_travel_tick()` before wave resolution, decrementing
  travel days and arriving characters. Phase 1: `build_context()` auto-detects
  traveling characters via `TravelSystem.is_traveling()` and sets
  `ctx.context_flag = TRAVELING`. Phase 3: TRAVELING context restricts to
  CHANGE_DESTINATION, WRITE_LETTER, TRAIN, MEDITATE, DO_NOTHING, REST.
  Phase 7: ActionExecutor routes BEGIN_TRAVEL to `TravelSystem.begin_travel()`
  and CHANGE_DESTINATION to `TravelSystem.change_destination()`. Return dict
  includes `travel_arrivals`.
- **ObjectiveProgress** — Seasonal: `_evaluate_objective_progress()` runs on
  season boundary before strategic reviews. Evaluates all primary objectives
  via 12 type-specific progress functions (0.0–1.0). Updates
  `last_measured_progress` and `seasons_without_progress` via
  `TravelCommitment.update_progress()`. Stall detection via
  `TravelCommitment.is_stalled()` with personality-gated thresholds.
  Arrival observation: `_process_arrival_observation()` runs after travel tick,
  records FRESH location knowledge via
  `InformationSystem.record_location_observation()` for co-located NPCs.
- **InsurgencySystem** — Seasonal: `_process_insurgencies()` runs on season
  boundary after historical modifier decay. Calls
  `InsurgencySystem.process_season()` with PTL values read from
  `ProvinceData.province_taint_level`. Appends new insurgencies from spawning
  and spreading, removes suppressed ones (strength ≤ 0). New params on
  `advance_day()`: `insurgencies: Array[InsurgencyData]`,
  `next_insurgency_id: Array[int]`. Return dict gains `insurgency_results`.

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
