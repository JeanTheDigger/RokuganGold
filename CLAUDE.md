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
  province effects). INTIMIDATE intercepted before generic social path and routed
  through IntimidationSystem for proper honor/infamy/compliance effects — context
  determined from metadata (secret_ref → blackmail, AT_COURT → public, else
  private). Falls through to generic path when characters_by_id is empty.
- **simulation/effect_applicator.gd** — Applies executor results to world state.
  `apply()` mutates character disposition/honor/glory/infamy, witness disposition,
  recipient disposition, province stability/garrison/report date, and appends to
  action_log. `apply_day_results()` batch processes a full day's results.
  Tracks all mutations in `applied` dict: `disposition_changes`, `honor_changes`,
  `glory_changes`, `infamy_changes`, `province_updates`, `info_events`.

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
- test_action_executor.gd (~35 tests)
- test_effect_applicator.gd (~37 tests)
- test_npc_wave_resolver.gd (~15 tests)
- test_resource_tick.gd (~30 tests)
- test_objective_decomposer.gd (~100 tests)
- test_information_system.gd (~40 tests)
- test_topic_system.gd (~55 tests)
- test_investigation_system.gd (~40 tests)
- test_day_orchestrator.gd (~28 tests)
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
- test_gift_giving_system.gd (~39 tests)
- test_biological_family.gd (~42 tests)
- test_collective_disposition.gd (~37 tests)
- test_miya_blessing_system.gd (~50 tests)
- test_miya_blessing_wiring.gd (~14 tests)
- test_miya_blessing_followup.gd (~13 tests)
- test_togashi_oversight.gd (~49 tests)
- test_phoenix_council.gd (~51 tests)
- test_intra_clan_civil_war.gd (~59 tests)
- test_event_durations.gd (~25 tests)
- test_performative_arts.gd (~30 tests)
- test_performative_arts_wiring.gd (~10 tests)
- test_succession_system.gd (~60 tests)
- test_succession_wiring.gd (~10 tests)
- test_secret_system.gd (~90 tests)
- test_seduction_system.gd (~25 tests)
- test_assassination_system.gd (~45 tests)
- test_bound_escape_system.gd (~45 tests)
- test_secret_system_wiring.gd (~25 tests)
- test_army_combat_system.gd (~145 tests)
- test_army_upkeep_system.gd (~40 tests)
- test_supply_tether_system.gd (~51 tests)
- test_siege_system.gd (~50 tests)
- test_army_movement_system.gd (~40 tests)
- test_levy_system.gd (~35 tests)
- test_military_promotion_system.gd (~35 tests)
- test_order_system.gd (~30 tests)
- test_military_service_system.gd (~35 tests)
- test_pu_reconciliation.gd (~30 tests)
- test_military_wiring.gd (~219 tests)
- test_war_system.gd (~61 tests)
- test_war_justification.gd (~55 tests)
- test_war_termination.gd (~46 tests)
- test_feasibility_ledger.gd (~148 tests)
- test_starvation_warfare.gd (~55 tests)

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

### Intra-Clan Civil War (s53.2)
- **simulation/intra_clan_civil_war.gd** — `IntraClanCivilWar` pure
  simulation class implementing the generalized civil-war system per
  GDD s53.2. Triggered when a Family Daimyo (or higher) refuses lawful
  authority; produces faction assignments, war-score tracking, stability
  bleed, resolution detection, defection mechanics, and the empire-wide
  Precedent Effect.
  Four-value `Faction` enum (NONE, LEGITIMACY, REBEL, RONIN).
  `evaluate_loyalty(npc, rebel_lord_id, completion_rate, grievance_visible,
  rebel_was_failing)` runs the GDD's 5-factor scoring: Chugi (30%),
  disposition toward rebel (25%), rebel competence (20%, bracketed at
  ≥75% / 50-74% / <50%), grievance legitimacy (15%, with no-info safe
  default toward Legitimacy), Ishi ambition (10%). Returns `{faction,
  rebel_score, chugi_pull, disposition_pull}`. Ronin path fires when
  both Chugi pull and disposition pull are below 40 — character has no
  strong attachment in either direction.
  `apply_seasonal_consequences(state, rebel_lord, provinces, current_season)`
  applies the −3 / −5 / −7 stability penalty (escalating at 8 and 12
  seasons) to all clan provinces and the −0.3 Honor/season hemorrhage to
  the rebel lord. Honor floors at 0.
  War Score shifts (s53.2.5): `record_defection` (±12 family daimyo,
  ±5 provincial), `record_rebel_disgrace` (+15), `record_imperial_edict`
  (±10), `record_foreign_intervention` (±8). All clamp to 0..100.
  Resolution: `check_legitimacy_victory` (capitulation, Honor < 0,
  seat lost). `tick_rebel_victory_counter(state, rebel, holds_seat,
  has_allies)` requires all three conditions for 6 consecutive seasons;
  resets on any failure. `is_rebel_victory_achieved()` queries the
  threshold.
  `can_seize_championship(state, clan, was_family_daimyo,
  incumbent_disgraced_or_dead)` enforces the 90+ war score gate AND
  the absolute Dragon/Phoenix exceptions (`SEIZURE_FORBIDDEN_CLANS`).
  Defection (s53.2.8): `defection_trigger_fired` checks all four GDD
  triggers (lord killed, edict against faction, faction war-score
  Desperate, disposition-toward-leader Enemy).
  `apply_defection_consequences` applies −0.5 Honor on defector and
  −15 disposition from every former faction member.
  Precedent Effect (s53.2.10): `apply_precedent_effect` adds +3
  (standard rebel victory) or +5 (Championship Seizure) to the world's
  defy-bonus modifier dict, expiring 5 seasons later. Modifiers stack.
  `tick_precedent_decay` removes expired entries.
  `finalise(state, season, legitimacy_won)` marks the war resolved.
  Deferred (depend on systems not yet built):
  Army reconstitution / Go-hatamoto reform (s53.2.3 — needs full
  military hierarchy), tax cascade break (current cascade is
  approximation only), Imperial Edict gating, full Crisis topic
  routing for the trigger topic, Section 22.5 succession integration
  for post-victory FILL_VACANCY chains.

### Phoenix Elemental Council — Phoenix Clan Governance Exception (s55.10.3)
- **simulation/phoenix_council.gd** — `PhoenixCouncil` pure simulation
  class implementing the Phoenix governance per GDD s55.10.3.
  The Shiba Champion proposes; the five-Master Elemental Council approves
  major decisions by 3-of-5 majority vote. Per-Master temperament
  dominates voting behavior; Defiance and Overreach paths track
  escalation between Champion and Council.
  Five-value `Master` enum (FIRE, WATER, AIR, EARTH, VOID) and 11-value
  `DecisionType` enum split into `MAJOR_DECISIONS` (require Council
  vote) and Champion-handled (no vote needed).
  `MASTER_VOTE_BASE` weights per-element: Fire +15 on DECLARE_WAR / -10
  on SIGN_TREATY; Water +10 on SIGN_TREATY / +5 MAJOR_RESOURCE_SPEND;
  Air +15 on SIGN_TREATY / -15 on DECLARE_WAR / -10 on DEPLOY_GO_HATAMOTO;
  Earth -15 on DECLARE_WAR / +5 SIGN_TREATY / -10 COMMIT_SHUGENJA.
  Void Master uses an omen-based random model (40% YES baseline,
  ±20% for spiritual dimension match, ~10% chance to abstain).
  Vote modifiers: Friend disposition (+5), Rival (-5), Tier 1 crisis
  override (+15), element-threatened lock-in (+20).
  `tally_vote()` returns
  `{passed, yes, no, abstain, deadlocked, votes}`. Deadlock detected
  when Void abstains and YES==NO and not passed.
  `table_proposal()` / `champion_may_break_tie()` enforce s55.10.3.4
  deadlock resolution — proposal must be tabled twice before the
  Champion may break the tie at -0.3 Honor cost.
  Defiance Path (s55.10.3.5) — `handle_unilateral_action()` increments
  the cumulative defiance counter (no clean-slate per s55.10.3.5
  escalation scope). Stage queries: `is_diplomatic_suspended()` (Stage
  2+), `is_shugenja_withdrawn()` (Stage 3, Phoenix Go-hatamoto loses
  shugenja support), `is_unfit_declaration_active()` (Stage 4, formal
  removal demand). `handle_compliant_season()` unwinds one stage but
  does not reset lifetime defiance count.
  Overreach Path (s55.10.3.6) — `handle_overreach_trigger()` for
  generic triggers; `track_consecutive_crisis_veto()` (3 consecutive
  vetoes of crisis-response proposals) and
  `track_consecutive_obstruction()` (3 seasons of total Council
  refusal) automatically increment overreach. Stage queries:
  `is_emperor_appeal_available()` (Stage 2+), `is_compact_declared_violated()`
  (Stage 3), `is_overreach_schism_imminent()` (Stage 4).
  `phoenix_champion_authority` flag tracks post-schism Champion
  victory. `grant_champion_authority()` sets it; `restore_council_compact()`
  clears it AND zeroes all defiance/overreach state. Reincarnation
  inheritance: `reincarnated_champion_evaluates_restore()` evaluates
  whether a new Champion who inherited the flag voluntarily restores
  the compact based on virtues + duty score + disposition toward
  Council.
  Master vacancy queries: `count_living_masters()`,
  `can_council_self_govern()` (3+ Masters required),
  `champion_appoints_replacements()` (true below quorum — significant
  power shift during schism), `is_council_extinct()`.
  State held in plain Dictionary owned by caller; `make_initial_state()`
  factories it.
  Deferred (depend on systems not yet built):
  Phoenix Schism Crisis (s55.10.3.7), Shiba Reincarnation Mechanic
  (s55.10.3.8 — depends on Section 22.5 succession), Grand Ritual
  threat integration, Imperial Edict appeal mediation.

### Togashi Oversight — Dragon Clan Governance Exception (s55.10.2)
- **simulation/togashi_oversight.gd** — `TogashiOversight` pure simulation
  class implementing the Dragon-specific governance per GDD s55.10.2.
  The Mirumoto FC runs the seasonal Strategic Evaluation on behalf of
  the Clan Champion position (Togashi the Kami). Togashi monitors four
  cosmic axes and forces directives when his dissatisfaction crosses
  threshold.
  Four-value `Axis` enum: BALANCE_OF_POWER, IMPERIAL_COHESION,
  SPIRITUAL_HEALTH, SHADOWLANDS_CONTAINMENT.
  Per-axis concern checks read world state directly (no information
  channels — Togashi is cosmically informed): clan_strengths +30%
  dominance, 2+ inter-clan wars OR emperor vacant OR 5+ rebellions,
  failing worship/realm overlaps/PTL outside Shadowlands, wall breach
  OR Tier 2+ incursion OR Crab readiness < 50%.
  `tick_oversight()` updates dissatisfaction per axis: -10/season when
  no concern, -5/season when concern active and FC's directives are
  aligned, +15/season when concern unaligned. Dissatisfaction floors
  at 0; threshold for intervention is 50.
  `is_directive_aligned()` heuristic-matches StrategicReview.Directive
  values to each axis (war-readiness/seek-peace for balance and
  cohesion; explicit `addresses_spiritual` / `addresses_shadowlands`
  tags for the latter two — those have no native StrategicReview path).
  `generate_forced_directive(axis)` produces a directive dict
  flagged `forced_by_champion: true` with axis tag and address-flags.
  `evaluate_compliance(fc, directive, togashi_id, repeated, conflict)`:
  Comply = Chugi (+10) + Rei (+5) + clamped disposition toward Togashi
  (±20) + repeated-letter Meiyo bonus (+5, +5 more if Meiyo virtue).
  Defy = Ishi (+10) + Ketsui (+8) + conflict_modifier (0–20).
  Compliance unwinds escalation by 1 stage and resets dissatisfaction
  to 30 on the triggering axis. Defiance increments `defiance_count`
  cumulatively (s55.10.2.6 — counter is NOT per-axis), capped at 4.
  Stage queries: `is_authority_locked()` (Stage 2+, blocks formal
  Champion powers), `is_order_withdrawn()` (Stage 3, Wandering Togashi
  recall + tattoo suspension), `is_removal_triggered()` (Stage 4,
  formal removal — handles via the standard succession system once
  s22.5 lands). `get_diplomatic_credibility_modifier()` returns -5
  during authority lockout.
  Forced-directive lifecycle: `add_forced_directive` replaces any
  existing entry on the same axis (one per axis at a time);
  `should_lift_forced_directive` fires below dissatisfaction 20;
  `remove_forced_directive` filters by axis.
  `process_seasonal_oversight()` is the high-level driver — caller
  invokes it after the Mirumoto FC's seasonal review with the FC's
  directives + world state. Returns `{tick, intervention_fired,
  compliance, forced_directive}`. State is held in a plain Dictionary
  owned by the caller; `make_initial_state()` factories it.
  Deferred (depend on systems not yet built):
  Dragon Schism Crisis (s55.10.2.8), assault on the High House of
  Light (Togashi vanish-and-return mechanics), foreign-clan
  intervention escalation, Section 53.2 civil war integration,
  Section 22.5 succession integration for Stage 4 removal.

### Miya's Blessing — Annual World Map Event (s11.5b)
- **simulation/miya_blessing_system.gd** — Annual charitable Rice transfer
  per GDD s11.5b. Pure simulation class. Fires once per year at the start
  of Spring, after planting and before rice consumption — the injected
  Rice can pull settlements out of Shortage before the starvation check.
  Five `BLESSING_RATE` values keyed by `StrategicReview.EmperorArchetype`:
  Benevolent 20%, Iron 15% (default), Cunning 10%, Warlike 5%, Tyrant 0%.
  `compute_allocation(tax_income, rate, stockpile, otosan_uchi_pu)`
  applies (1) blessing rate, (2) `MAX_TOTAL=15.0` per-year ceiling
  (5.0 × 3), and (3) the Imperial reserve floor (`OU_PU × 0.25` must
  remain) — clamping the result to whatever the Emperor's stockpile
  can spare without starving the capital. `is_suspended(allocation)`
  flags any total below `MIN_THRESHOLD=0.50`.
  Need score per GDD §4.1: starvation tier (Shortage/Hunger/Famine =
  +5/+10/+20), stability bracket (Restless/Volatile/Broken = +2/+5/+10),
  +5 active war, +3 raided, +3 insurgency, +5 PU decline ≥10%, +10 if
  ≥25% (replaces the +5), +2 rotation if not blessed last year (and not
  the year before that), -5 malus if blessed last year, plus Winter
  Court petition contributions.
  `compute_petition_bonus(success, raises)` = +8 base + 2 per Raise.
  `select_provinces(scored)` picks up to 3 by score desc, tiebreaking
  on lowest stability, then smaller population. Excluded provinces
  (Shadowlands taint above maho threshold, active rebellion) are
  filtered before selection. `distribute_to_settlements()` allocates
  each province's share proportionally by `population_pu` across that
  province's settlements (zero-PU settlements skipped).
  `process_annual_blessing(inputs)` is the top-level orchestrator —
  returns a result dict with `fired`, `suspended`, `suspension_reason`
  ("tyrant_archetype" or "below_threshold"), `allocation_total`,
  `allocation_per_province`, `selected_province_ids`,
  `settlement_rice_grants`, `stability_bonus` (+5), and
  `pop_growth_bonus` (+1%). The system itself stays pure — the wiring
  (below) does the mutations.

- **Miya's Blessing wiring** —
  `ResourceTick.process_seasonal_tick()` accepts an optional `miya_inputs`
  dict. When `season == "spring"` and the dict is non-empty, runs the
  Blessing AFTER planting and BEFORE rice consumption (per GDD §3 — the
  injected rice can absorb the Spring draw). Mutates the Imperial
  settlement's `rice_stockpile`, deposits each grant into the recipient
  settlements proportionally by `population_pu`, applies `+5 stability`
  to each selected province (clamped 0–100), and stamps
  `province.last_blessed_ic_year`. After the autumn tax cascade,
  `season_meta["last_autumn_emperor_tax_income"]` is set to an
  approximation: `sum(passed_up) × 0.063` (the four-tier upper-cascade
  product 0.70 × 0.75 × 0.80 × 0.15) — a placeholder until the full
  hierarchy cascades through individual lord characters.
  `ProvinceData` gains `last_blessed_ic_year: int = -1` (sentinel for
  never blessed).
  `DayOrchestrator.advance_day()` accepts optional `miya_inputs` and
  threads it into `_process_season_transition`, which injects the IC
  year (via `time_system.get_ic_year()`) and reads
  `last_autumn_emperor_tax_income` from season_meta before passing to
  ResourceTick.
  `WorldStateData` gains `emperor_id`, `emperor_settlement_id`,
  `emperor_archetype`, and `miya_representative_id` fields plus a
  `_build_miya_inputs()` helper that assembles the dict from world state.
  Returns `{}` (no-op) when the Imperial capital isn't fully configured.
  `advance_one_day()` calls it automatically.

- **Miya's Blessing follow-up (s11.5b §6–7)** —
  `DayOrchestrator._process_miya_blessing_followup()` runs on Spring
  transitions after the seasonal tick. Reads
  `seasonal_result.resource_tick.miya_blessing`, then:
  - **Fired path** — generates one Tier 4 `miya_blessing/delivered` topic
    per blessed province (POLITICAL category, BENEFICIARY subject role,
    momentum 11.0); applies disposition deltas per province lord:
    `+2 toward miya_representative_id`, `+1 toward emperor_id` (gated on
    those IDs being set). Resets
    `season_meta["consecutive_blessing_suspensions"] = 0`.
    Province-lord lookup scans `characters_by_id` for the highest-status
    character matching the province's clan + family — placeholder until
    daimyo IDs are explicit on ProvinceData.
  - **Suspended path** — increments `consecutive_blessing_suspensions`,
    generates a Tier 4 suspension topic the first 1–2 years and a Tier 3
    grievance topic at year 3+ ("Miya's Blessing Suspended — Imperial
    Reserves Insufficient", or "Miya's Blessing Denied by Imperial Order"
    for the tyrant_archetype reason). Applies `-1 stability` to every
    province with `stability < 76` or an active insurgency (proxy for
    Need Score > 0); the penalty doubles to `-2` after 2+ consecutive
    suspensions. Applies `-3` Miya-rep disposition toward the Emperor
    (gated on both IDs being set). Same-clan ripple and per-clan-champion
    empire-wide penalties are deferred until clan→champion mapping is
    consistent.
  - **Pop growth bonus** — `ResourceTick._apply_miya_blessing` now writes
    `_miya_growth_bonus: { province_id: 0.01 }` into settlement_meta;
    `_process_population_adjustment` reads it and adds the +1% to the
    blessed provinces' growth rate that season.

### Clan & Family Collective Disposition (s12.2b)
- **simulation/collective_disposition.gd** — `CollectiveDisposition` class
  per GDD s12.2b. Holds the locked PROVISIONAL pre-Scorpion-Coup baselines
  as const dicts: 21 Great Clan ↔ Great Clan pairs, 29 Minor Clan ↔ Great
  Clan pairs, 8 Minor ↔ Minor pairs (`STARTING_CLAN_BASELINES`); plus 44
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
  `process_observe_court()` and `process_introduction()` thread baselines
  through to add_contact. `process_introduction()` now layers the
  introduction bonus (+2 kuge / +3 standard) ON TOP of the seed instead
  of clobbering it — first-time introduction with active baselines
  produces `seed + bonus`, captured via a `was_first_meeting` snapshot
  before add_contact mutates met_characters.
  `transfer_objective_knowledge()` accepts optional chars_by_id +
  baselines and seeds dispositions for each contact transferred from the
  assigner's known_contacts_by_clan when the recipient hasn't met them.

- **scripts/managers/world_state.gd** — `WorldStateData` autoload gains
  `clan_baselines: Dictionary` and `family_baselines: Dictionary`,
  initialized in `_ready()` from
  `CollectiveDisposition.make_starting_baselines()`. Callers that need
  baselines can read them off the WorldState autoload directly. Mutations
  via CollectiveDisposition event helpers compound on the live world
  state — they never decay.

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

### Event Durations (s11.7b)
- **simulation/event_durations.gd** — Reference constants for major event
  pacing per GDD s11.7b. Six EventType values (MASS_BATTLE, SIEGE,
  COURT_SEASON, FESTIVAL, DIPLOMATIC_SUMMIT, TOURNAMENT) with min/max OOC
  day durations. OOC-to-IC ratio = 4 (1 OOC day = 4 IC days). Durations:
  battle 1/1, siege 15/30, court 30/30, festival 3/3, summit 5/7,
  tournament 3/5. `get_ooc_duration()`, `get_ic_duration()`, `get_ic_ticks()`,
  `is_variable_duration()`, `get_all_durations()`.

### Performative Arts System (s12.4)
- **simulation/performative_arts_system.gd** — Court performance mechanics per
  GDD s12.4 and s15.4. Five ArtForm values (POETRY, DANCE, THEATER, MUSIC,
  TEA_CEREMONY) mapped to skills (Artisan, Perform, Acting, Tea Ceremony).
  `resolve_public_performance()` rolls skill+trait vs TN 15: success +2
  disposition to all witnesses + 0.3 Glory, +1 disp per raise, critical failure
  (margin ≤ -10) -2 disposition -0.3 Glory. Performance fatigue: diminishing
  returns (full → half → zero) on repeat performances same court same OOC day.
  `resolve_perform_for()` targeted performance: +3 disp on success + raises,
  +0.2 Glory on masterful (3+ raises), -1 disp on failure. No fatigue, no venue
  restriction. `get_best_art_form()` picks performer's highest effective
  skill+trait combination. `apply_performance_effects()` mutates glory and
  witness/recipient disposition values. Venue gating (performance_permitted
  zone flag) already enforced by NPC engine Phase 3 zone-flag filtering.
- **Performative arts wiring** — ActionExecutor intercepts PUBLIC_PERFORMANCE
  and PERFORM_FOR before the `_performance_skill` fallthrough. PUBLIC_PERFORMANCE
  picks best art form, gathers co-located witness IDs, reads fatigue from
  `pieces_seen["_performance_count_today"]`, resolves via PerformativeArtsSystem,
  applies effects (glory + witness dispositions), increments fatigue counter.
  PERFORM_FOR resolves targeted performance against recipient, no fatigue.
  DayOrchestrator `_reset_all_ap()` clears the fatigue counter daily.

### Succession System (s22.5)
- **shared/succession_data.gd** — SuccessionData Resource: SuccessionState (4),
  VacancyCause (4), deceased_id, position_tier, confirming_authority_id,
  candidate_ids, contesting_ids, suspicious_death, transition timing.
- **simulation/succession_system.gd** — Full succession lifecycle per GDD s22.5.
  7-priority candidate gathering (designated heir, eldest child, other children,
  adopted, siblings, lord selects, generated). Confirmation authority tier map
  (each position confirmed one level up). Clean vs disputed detection (4
  conditions: suspicious death, contesters, rival disposition, multiple
  same-priority). 9-factor heir evaluation (disposition, birth order, honor,
  glory, insight rank, school type, skills, achievements, titles) with 14
  personality-driven weight multipliers (7 bushido + 7 shourido). Ishi
  permanence (never re-evaluates designated heir). Seigyo re-evaluates every
  season. Emperor succession special case with crisis detection. Major favor
  inheritance. Dispute mechanics. Topic generation (Tier 4 clean / Tier 2
  disputed). Transition effects (tax/koku suspension, stockpile freeze).
  Clan exceptions (Phoenix reincarnation bypass, Dragon Togashi removal
  bypass) detected and skipped.
- **Succession wiring** — DayOrchestrator `_process_lord_deaths()` now
  triggers SuccessionSystem on lord death events: gathers candidates, finds
  confirming authority, determines clean/disputed, generates succession topic,
  auto-confirms clean successions with heir evaluation. `_process_successions()`
  ticks active disputed successions daily and force-confirms on expiry (60
  ticks). `_evaluate_heir_designations()` runs on season boundary — lords
  without heirs (or with Seigyo virtue) evaluate candidates via the 9-factor
  scoring system and auto-designate. WorldStateData gains `active_successions`
  and `next_succession_id` fields, threaded through `advance_one_day()`.
  Deferred: Priority 4 adopted heir (needs adoption action), court dispute
  resolution, assassination cross-ref (needs SecretSystem), Dragon/Phoenix
  exception integration.

### Secret System (s12.8)
- **shared/secret_data.gd** — SecretData Resource: Severity enum (TIER_4=4 least
  severe through TIER_1=1 most severe), secret_id, subject_id, severity,
  fabricated, fabricator_id, detection_tn, exposed, exposed_publicly, slug,
  description, topic_id, physical_proof_item_id.
- **simulation/secret_system.gd** — Core secret mechanics per GDD s12.8.
  Severity consequence tables: PRIVATE_EXPOSURE_DISP (−8/−15/−30/−50),
  PUBLIC_EXPOSURE_DISP_PER_WITNESS (−5/−10/−20/−35), SUBJECT_HONOR_LOSS
  (0/−0.3/−1.0/−2.0), SUBJECT_GLORY_LOSS (−0.1/−0.3/−0.5/−1.0),
  SUBJECT_INFAMY_GAIN (0/0/0.3/0.5). Context modifier: severity upgrade when
  involved_status > subject_status OR act within 4 seasons (max one tier).
  `reveal_privately()` applies disposition/honor/glory/infamy to subject,
  generates betrayal topic at Tier 1. `expose_publicly()` per-witness
  disposition loss. Fabrication: Forgery+Agility vs TN 15/20/25/30 by tier,
  honor cost −0.3/−0.5/−0.8/−1.5, +0.2 infamy. `detect_fabrication()`
  Investigation+Perception vs detection_tn. Covert acquisition costs: bribe
  −0.2/+0.1, eavesdrop −0.1/+0.05, intercept −0.3/+0.1, search −0.3/+0.1.
  Assassination order honor cost by target status (−2/−3/−4/−5). NPC covert
  filters: Gi/Makoto hard-block, CLAN_RELUCTANCE table (Scorpion 0 through
  Lion 5), honor threshold 3.5, disposition −31 gate. `can_fabricate()`
  personality gate. Covert action resolution: `resolve_eavesdrop()` contested
  Stealth+Agility vs Perception+Investigation, `resolve_intercept_letter()`
  two-step Stealth then Forgery with geographic modifier,
  `resolve_search_quarters()` TN 15 + target Investigation rank,
  `resolve_shadow_target()` contested Stealth vs Investigation (1 IC day),
  `resolve_conceal_item()` Sleight of Hand TN 10/15/20 by size with Rank 5
  weapon gate, `resolve_search_person()` Investigation vs concealment_tn
  with −0.3 Glory if caught without magistrate authority,
  `resolve_forge_impersonation_letter()` Forgery+Intelligence TN 15/20/25,
  `resolve_forge_order()` Forgery+Intelligence TN 20/25/30.

### Seduction System (s12.8)
- **simulation/seduction_system.gd** — Seduction and entanglement mechanics per
  GDD s12.8. Five SeductionVariant values (SEDUCE, SEDUCE_FOR_INFO,
  SEDUCE_FOR_ACCESS, SEDUCE_FOR_LEVERAGE, SEDUCE_TO_COMPROMISE). Category 6,
  1 AP. Temptation+Awareness vs TN 15 + Etiquette + Willpower + Honor Rank.
  Honor cost −0.3, Infamy +0.1. Variant effects: SEDUCE +5 disposition,
  SEDUCE_FOR_INFO grants info with raises for detail, others grant access/
  leverage/compromise. Entanglement lifecycle: create, maintain (16 IC day
  window), neglect, break (3 missed windows). Breakup disposition loss by
  attachment level (low −5, moderate −15, high −30). Affair secret severity:
  unmarried T4, married T3, political marriage T2, cross-clan T1.

### Assassination System (s12.8)
- **simulation/assassination_system.gd** — Three-phase assassination per GDD
  s12.8. Phase 1 Access: social infiltration over 3+ days via forge_credentials
  (TN 20), bribe (TN 15), stealth (TN 20), seduction (TN 15). Suspicion
  accumulation (+5/+10/+15 by failure severity), decay (−1/day absent, 0 present),
  alert at 20 (+10 TN), lockdown at 40 (+15 TN, blocks execution). Phase 2
  Execution: poison (Stealth TN 15 + Sleight of Hand TN 20), blade (Stealth
  TN 20 + attack with +10 bonus vs Armor TN), arranged accident (Engineering
  TN 25 + Stealth TN 15). Bodyguard encounters with fight/evade/abort options.
  Phase 3 Concealment: poison (Medicine TN 15), blade (Stealth TN 25), accident
  (Engineering TN 20). Successful concealment produces concealment_tn for
  investigators. PC safeguard crisis windows: poison 12, blade 4, accident 8
  real days.

### Bound/Escape System (s12.8)
- **simulation/bound_escape_system.gd** — Bound condition and escape per GDD
  s12.8. Four BindingMaterial values (SIMPLE_ROPE TN 15, QUALITY_ROPE TN 20,
  CHAINS TN 25, HIGH_GRADE_CHAINS TN 30). Knotwork binding by named characters
  (Sailing+Intelligence, minimum TN 15). Escape: Sleight of Hand+Agility vs
  binding TN, once per IC day, generates Quiet noise (3 tiles). Guard noise
  detection: Investigation+Perception vs TN 15 + distance×2. Failed escape
  detected → rebind (+5 TN stacking). Location escape separate: Stealth+Agility
  vs location TN. Free ally: rope = blade Simple Action (no roll, Quiet noise);
  chains = key (Simple Action) or Strength vs TN 25 (Moderate noise). Action
  filter: bound characters can CHARM, NEGOTIATE, PERSUADE, INTIMIDATE, escape,
  cast spells, and speak only. Low Skill honor cost −0.1 on escape attempts.

### Army Combat System — Core Battle Resolution (s11.7) + Clan Elite Units (s11.6)
- **simulation/army_combat_system.gd** — Victoria II-inspired grid battle
  resolution per GDD s11.7. Covers the core battle loop from setup
  to completion, plus all 24 clan elite unit types per GDD s11.6.
  7 universal unit types with full stat blocks per GDD: Peasant Levy (A1/D1),
  Ashigaru Spearmen (A3/D4, +3 vs Cavalry), Ashigaru Archers (A4/D2, 1d5
  ranged fire, -3 melee), Bushi Retainer (A6/D5), Light Cavalry (A3/D2,
  +4 flanking, immune to counter-attack while flanking), Ronin (A5/D4),
  Garrison (A3/D5, +2 Defense at home settlement).
  24 clan elite unit types across 8 clans (Crab, Crane, Dragon, Lion,
  Phoenix, Scorpion, Unicorn, Mantis) in 3 cost tiers (Baseline/Specialized/
  Elite). Full stat blocks and special abilities per GDD s11.6.
  Row 1 (front) / Row 2 (reserve/archer) grid layout. Companies fight the
  enemy in their column. Unmatched companies auto-flank adjacent enemies.
  Combat round: simultaneous 1d10+Attack-Defense, minimum 0. Archers fire
  1d5 from Row 2. Flanking: +2 Attack (standard), +4 (Light Cavalry), +3
  (Shinjo/Hiruma). No counter-attack against flanker (Light Cavalry, Utaku).
  Morale system: 1d10 + modifiers - Morale Defense. Triggers: heavy loss
  (+2 if >25% health lost), low health (+1 if <50%), Chui death (+3),
  higher commander death (+4). Extra morale damage: Bayushi +1, Black Cabal
  +3, Elemental Guard +2. Adjacency morale: Shiba +1 MD to allies, Black
  Cabal -1 MD to enemies. Deathseekers: no morale, cannot rout. Berserkers:
  rout only below 25% health. Morale zero = rout. Routing contagion: adjacent
  allies take immediate morale check when a company routs, can chain.
  Commander bonus: Battle skill rank as value, highest Ring determines type
  (Fire/Water→Attack, Earth/Air→Defense, Void→Morale). Clan-specific
  tiebreaker tables for Ring ties (8 Great + 13 Minor clans).
  Commander survival: Earth k Earth + Battle vs TN (10/15/20/25 at
  75%/50%/25%/0% health). Attacker TN modifiers: Hiruma +2, Kenshinzen +3,
  Lion's Pride +3. Fail by 1-3: injured. Fail by 4+: dead.
  Clan special abilities: first-round attack bonus (Kakita +2, Utaku +3,
  Storm Legion +2), low-health attack bonus (Berserkers +2, Deathseekers +3,
  White Guard +2 at <50%), conditional attack bonus (Bayushi vs low morale,
  Dragon Talons vs high def, Kenshinzen vs elites, White Guard vs low health),
  defense ignore (Dragon Talons 1, White Guard 1), vs-shugenja defense
  (Mirumoto +2), adjacency defense (Shiba +2 near shugenja, Daidoji +1 near
  Crane, Elemental Legions +1 near Guard), adjacency attack (Akodo +1 per
  adjacent Lion max 3, Elemental Legions +2 near Guard), debuff-on-hit
  (Yoritomo -1 Def stack 3, Scorpion's Claws -1 Atk/-1 MD stack 3).
  Per-round ally buff system: Yamabushi +3 Atk to adjacent Dragon (+ one-time
  +2 Def), Elemental Guard +3 Atk to adjacent Phoenix, Storm Riders +2 Atk
  to adjacent Mantis, Mirumoto +1 Atk to adjacent shugenja.
  Terrain: all cavalry types (Light Cav, Shinjo, Utaku, White Guard) affected
  by cavalry terrain penalties/bonuses. Storm Legion ignores terrain penalties.
  6 terrain types: Plains (cavalry +2 flanking), Forest (defender +2 Def,
  cavalry disabled), Hills (attacker -2 Atk), Mountain (defender +4 Def,
  cavalry disabled), Urban (defender +3 Def, spearmen +1 Def), Coastal
  (amphibious -3 Atk).
  Reserve promotion: Row 2 non-archer companies auto-promote when Row 1
  slot in their column is vacated. Archers stay in Row 2.
  Battle end: all companies on one side destroyed or routed.
  `resolve_rout()` — pursuit casualties: cavalry present 1d10+25%, no
  cavalry 1d10+5%. Army dissolved if below 20% starting health.
  `compute_post_battle_recovery()` — 10% recovered, 10% returned as PU,
  80% permanently dead. Victor only.
  `create_company()` factory sets stats from UNIT_STATS table.
  Safety cap: 200 rounds maximum to prevent infinite loops.
- **shared/enums.gd** gains `CompanyUnitType` (31 values: 7 universal + 24
  clan elite) and `BattleTerrainType` (6 values).
- **shared/military_unit_data.gd** — CompanyData gains `unit_type` and
  `source_province_id` fields.
  Deferred (Phase 2+): Shinjo auto-flank behavior, ASCII battle events /
  Heroic Opportunities, Shadowlands terrain zones, naval combat bonuses.

### Army Upkeep & Deprivation (s4.3, s11.7)
- **simulation/army_upkeep_system.gd** — Army upkeep costs, iron degradation,
  and field deprivation per GDD s4.3 / s11.7. Pure static functions; caller
  owns all state dictionaries.
  Rice upkeep: 0.35 per military PU per season (universal).
  Iron upkeep per unit per season: Peasant Levy 0.03, Ashigaru 0.10, Bushi
  Retainer/Light Cavalry 0.20, Ronin 0.00, Garrison 0.10. Clan elites by
  cost tier: T1=0.25, T2=0.35, T3=0.50.
  Arms equip cost (one-time): Peasant Levy 0.25, Ashigaru 1.00, Bushi/Cavalry
  2.00, Ronin 0.00, Garrison 0.75. Clan elites: T1=2.50, T2=3.50, T3=5.00.
  Koku costs: Garrison 0.20/PU/season, Ronin hire 2.00, Ronin upkeep
  0.50/month (1.50/season).
  24 clan elite units mapped to cost tiers 1/2/3 via CLAN_ELITE_COST_TIER.
  Iron failure penalties (flat-from-base, not cumulative): Season 1 (−2 Atk,
  −2 Def, −4 Morale, −2 MD), Season 2+ (−4 Atk, −4 Def, −8 Morale, −4 MD).
  `apply_iron_failure()` reads base stats from `ArmyCombatSystem.UNIT_STATS`.
  `process_iron_upkeep()` tracks per-company iron state, degrades or restores.
  Field deprivation (s11.7): Rice (cumulative health/morale loss per tick,
  4 tiers), Arms (flat attack/defense penalties from base, 4 tiers).
  `process_deprivation_tick()` advances rice/arms ticks per company based on
  supply flags, applies effects. Supply restoration resets tick to 1 (warning).
  Recovery: `apply_recovery_tick()` requires stationary + supplied. +5 Health
  per tick (capped at base), +3 Morale per tick (capped at base), arms recover
  1 deprivation tier per tick when arms supplied.

### Supply Tether System (s11.7)
- **simulation/supply_tether_system.gd** — Supply tether mechanics for armies
  in hostile territory per GDD s11.7. Pure static functions; caller owns state.
  TetherState enum: SOLID (100% supply), THREATENED (50%, partial raid),
  BROKEN (0%, full cut). `create_tether()` forms a tether from army to source
  province through a sub-tile path with per-node state and escort tracking.
  Garrison raid: `resolve_garrison_raid()` rolls 1d10 + garrison Attack
  (base 3, ±1 per 0.5 PU above/below 1.0) vs TN (5 unescorted, 5 + escort
  Defense when escorted). Below TN = fail (SOLID), meets TN = partial
  (THREATENED), exceeds by 5+ = full cut (BROKEN).
  `process_tether_tick()` resolves all garrisons along the path independently.
  Worst result applies; enemy army on path = instant BROKEN; two partial
  raids stack to BROKEN. Escort management: `assign_escort()` places a
  company on a sub-tile (removed from battle roster), `recall_escort()`
  initiates 1-tick return delay. Deprivation tracking: BROKEN advances
  rice/arms deprivation ticks by 1 per tick; THREATENED advances at half
  speed (every 2 ticks). Step-down recovery: SOLID restores 1 deprivation
  stage per tick; THREATENED restores at half speed (1 per 2 ticks); BROKEN
  blocks recovery. `get_supply_source_provinces()` merges lord's provinces
  with compelled and shared sources. `process_supply_tick()` orchestrates
  the full tick: raid resolution → deprivation advance or step-down recovery.
  `detach_tether()` deactivates a tether on retreat arrival: resets deprivation
  ticks/accumulators/overall_state to SOLID, frees all escort companies (returns
  their IDs), marks `detached=true`. Detached tethers skipped by downstream
  processing.
  Deferred: Vertical/horizontal supply political mechanics (disposition
  damage, favor integration), visual line rendering, territory capture
  during war, actual sub-tile coordinate system (uses placeholder int IDs).

### Siege System (s11.7)
- **simulation/siege_system.gd** — Siege mechanics per GDD s11.7. Pure static
  functions; caller owns siege state dictionary.
  Starvation siege: `compute_daily_consumption()` uses civilian (0.0028 Rice/PU/
  tick) and military (0.0039 Rice/PU/tick) consumption rates. Castle town (2.0
  Rice, 10 PU + 0.5 garrison) ≈ 67 ticks; fortification (0.5 Rice, 0.5 garrison)
  ≈ 256 ticks. `process_starvation_tick()` decrements rice and checks starvation.
  Siege phases: Early (≤30 ticks, events every 10), Mid (31–60, every 7), Late
  (61+, every 5). 12 siege events: 6 attacker (smuggling intercept −10 ticks,
  secret passage −15, deserters −5 + reveal stores, relief force strategic
  decision, supply raid, contaminate water −20 + honor cost), 4 defender
  (midnight resupply +15, message for relief, tactical sortie, civilian morale
  crisis), 1 mutual (treachery −30). `resolve_siege_event()` rolls skill checks
  per event definitions. Storm assault: Urban (+3) + Fortification (+5) = +8
  Defense bonus; garrison at Defense 13 effective. Honor cowardice: −1 Honor per
  10 ticks after threshold (default 30, aggressive 20, pragmatic 45). Sortie
  resets counter. `process_siege_tick()` orchestrates starvation + honor +
  event firing per tick.
  Deferred: Full battle integration for storm assaults and sorties (uses
  ArmyCombatSystem), personality-driven sortie decisions (s19.3), ASCII map
  event scenarios, mutual event (treachery) resolution.

### Army Movement System (s11.7a)
- **simulation/army_movement_system.gd** — Sub-tile army movement per GDD s11.7a.
  Pure static functions; caller owns army state dictionaries.
  5 MovementTerrain types: Plains (1d), River Delta (1d), Forest (2d), Heavy
  Hills (2d), Mountains (3d). Winter ×2 multiplier. River crossing +1d (Spring
  +2d). Forced march: −1d per sub-tile (floor 1d), costs −5 Morale per day saved.
  `begin_march()` computes total travel days along a path. `process_movement_tick()`
  decrements daily, triggers arrival. `cancel_march()` stops movement.
  Battle trigger: `check_battle_trigger()` detects enemy armies at arrival tile —
  contact means automatic combat per GDD. Visibility: passive = own + adjacent
  tiles (range 1), scouts extend to range 2. `detect_enemy_armies()` filters
  visible tiles for non-allied armies. Retreat to previous sub-tile on battle loss.
  Dissolution check: army dissolves at ≤20% starting health.
  Deferred: Order system (lord/commander order budgets), scouting assignments,
  levy authority, military service assignment, actual sub-tile coordinate system
  (uses placeholder int IDs), territory control tracking.

### Levy & Mobilization System (s11.7a)
- **simulation/levy_system.gd** — Levy authority and mobilization per GDD s11.7a.
  Pure static functions; caller owns all state.
  Provincial Daimyo can raise Peasant Levy, Ashigaru Spearmen, and Ashigaru
  Archers from settlement military PU (1.0 PU per company). Levy companies
  exist outside Go-hatamoto hierarchy (no parent_legion_id). Arms equip cost
  from ArmyUpkeepSystem. `assign_commander()` attaches household retainers.
  `disband_levy()` returns PU proportional to remaining health, arms retained.
  Private Army Suspicion: after 1 season peacetime maintenance, Tier 4 topic
  generates. −5 disposition per season from Family Daimyo/Champion, −3 from
  neighbors. Escalates to Tier 3 at 3+ seasons. Wartime exemption.
  Commitment protection scoring for military service candidates: 6 role tiers
  (yojimbo −30/−15, magistrate −25/−15, yoriki −10/−5, courtier −15/−10,
  shugenja −5, uncommitted 0). Personality modifiers: Jin doubles yojimbo
  penalty, Yu halves all penalties, Chugi reduces by −10.
  Dual authority check: Daimyo + Taisa rank = can use Go-hatamoto directly.

### Military Promotion System (s11.7a)
- **simulation/military_promotion_system.gd** — Officer promotion, vacancy filling,
  and demotion per GDD s11.7a. Pure static functions.
  Enlisted: Hohei→Nikutai (Battle 2, 1 battle), Nikutai→Gunso (Battle 2, 1
  battle, vacancy). Officer minimum thresholds: Chui (Battle 3), Taisa
  (Battle 4, 1 battle as Chui), Shireikan (Battle 5, 2 battles as Taisa),
  Rikugunshokan (Battle 5, no battle count — political appointment possible).
  Multi-factor candidate scoring per rank: Battle skill (30–35), Insight Rank
  (15–20), School Rank/battles commanded (15–20), Glory (10), disposition toward
  appointing lord (10–20), personality fit (10). Personality tables per rank:
  Chui favors Yu/Chugi (frontline) or Seigyo (garrison), Taisa adds Dosatsu,
  Shireikan/Rikugunshokan prioritize Dosatsu/Seigyo for strategic vision.
  `select_best_candidate()` filters by eligibility then scores and returns best.
  Battle record tracking: battles fought/won/lost, companies destroyed under
  command. Demotion: −0.5 Glory, clears rank and commanded_unit_id. Removal
  trigger: disposition below −10. Vacancy detection scans units for empty
  commander_id slots.

### Order System (s11.7a)
- **simulation/order_system.gd** — Military command order system per GDD s11.7a.
  Pure static functions; caller owns order state dictionaries.
  Order budgets by rank: Chui 5, Taisa 10, Shireikan 10, Rikugunshokan 15,
  feudal lord 10. 8 order types: Scout, Hold Position, Garrison Province,
  March To, Recall, Detach to Support, Standing Patrol, Deliver Letter.
  Same-location orders deliver instantly; remote orders require messenger travel
  (1 sub-tile per real day). `issue_order()` validates budget, sets delivery
  delay. `process_pending_orders()` decrements daily, returns delivered orders.
  Standing patrol orders persist until cancelled (1 order to set up, continues
  until recalled). `cancel_standing_order()` removes by target character.
  `reset_daily_orders()` clears used count each real day.

### Military Service Assignment (s11.7a)
- **simulation/military_service_system.gd** — Feudal chain request flow per GDD
  s11.7a. Request cascade: Clan Champion → Rikugunshokan → Family Daimyo →
  Provincial/City Daimyo. `create_service_request()` creates a request with
  commander, target unit, rank needed, count. `cascade_request_to_vassals()`
  distributes count across vassal Provincial Daimyo (even split with remainder).
  `evaluate_candidates()` delegates to LevySystem commitment protection scoring
  (same scores: yojimbo −30/−15, magistrate −25/−15, yoriki −10/−5, courtier
  −15/−10, shugenja −5, uncommitted 0). Personality modifiers shared: Jin
  doubles yojimbo, Yu halves all, Chugi −10 reduction.
  `assign_to_military_service()` sets `operational_superior_id` to military
  commander, sets `assigned_company_id`; `lord_id` stays unchanged (feudal chain
  unbroken). `release_from_military_service()` returns samurai to their lord.
  Authority: only Provincial/City Daimyo can directly assign; only Shireikan+
  can request service. `select_candidates_for_service()` bulk selection with
  shortfall tracking. `apply_service_assignments()` batch mutation of character
  data. Engine wiring: ASSIGN_TO_MILITARY_SERVICE aligns to LEVY_TROOPS (80)
  and DEFEND_PROVINCE (60). Courtier (Manipulation) + Awareness, Category 2.

### PU Reconciliation (s11.7)
- **simulation/pu_reconciliation.gd** — Battle → World Map PU reconciliation per
  GDD s11.7. Every company tagged to source province at levy time. Conversion:
  HEALTH_TO_PU = 1.0/153.0 (1 PU per company at 153 starting health).
  `consume_levy_pu()` deducts military_pu and population_pu from settlement when
  raising a levy. `return_disband_pu()` returns PU proportional to health ratio
  on disband. `process_battle_casualties()` computes per-province PU losses from
  health lost across all companies, distributes losses to settlements (military_pu
  first, overflow to general population). Ronin companies excluded — no source
  province, losses disappear. `process_victor_recovery()` victor-only: 10%
  recovered to companies (health), 10% returned as PU to source settlements,
  80% permanently dead. Per-company proportional allocation by loss share.
  `reconcile_battle()` full orchestrator combining casualties + recovery.
  `process_army_dissolution()` handles ≤20% health dissolution — surviving
  health returned as PU to source settlements. Settlement mutations: losses
  deducted from military_pu first, gains added to primary settlement.

### War Status System (s53)
- **shared/war_data.gd** — WarData Resource: war_id, clan_a, clan_b,
  authority_level (4 tiers: Provincial Raid, Border Conflict, Family War,
  Clan War), war_score_a/b (0–100), initiator_clan, declaring/target lord
  IDs, ic_day_started, seasons_active, allied_clans arrays, provinces_captured
  arrays. WarScoreTier enum (6 values: Desperate through Dominant).
- **simulation/war_system.gd** — War Status tracking per GDD s53. Pure static
  functions; caller owns WarData instances.
  Declaration: `declare_war()` creates WarData with scores starting at 50.
  Score shifts: 19 named event types from GDD (minor/major/decisive battle,
  province/castle captured, siege won/repelled, commander kills by rank,
  hostage by rank, lord assassination, supply line cut, attrition, authority
  commits, allied clan joins). `apply_score_shift()` adjusts both sides.
  Score tiers: Desperate (0–24), Losing (25–39), Behind (40–49), Ahead
  (50–64), Winning (65–79), Dominant (80–100).
  Escalation: `can_escalate()`, `escalate()`, `check_auto_escalation()` with
  5 triggers (desperate score, castle fallen, enemy spread, prolonged 3+
  seasons, enemy alliance).
  Peace willingness: `compute_peace_willingness()` scores 0–100 from war
  score tier, territory terms, hostage, superior pressure, personality
  (Seigyo/Chishiki/Gi/Makoto positive; Yu/Ketsui/Ishi negative).
  Honor costs: aid request (0 desperate, −1.0 losing, −0.5 slight advantage),
  refusal (−2.0 family, −3.0 clan), territory fall (−2.0). Refusal
  disposition effects (−15/−20/−5/−10).
  Alliances: add/remove ally, get_all_combatant_clans, is_clan_involved,
  get_clan_side. Province capture tracking with side-switching.
  Resolution: `end_war()`, `is_annihilated()`.
  Seasonal: `process_seasonal_attrition()` (+1 initiator), disposition
  penalty (−2 per season active).
  Queries: `are_clans_at_war()`, `get_war_between()`,
  `get_active_wars_for_clan()`. Context conversion: `to_context_dict()`,
  `wars_to_context_array()` for NPC engine compatibility (existing code
  expects Dictionary arrays with clan_a/clan_b/enemy_clan_id keys).
  Wired into DayOrchestrator: `_process_war_score_shifts()` processes all
  war score events from daily military results. Sub-functions:
  `_process_battle_war_scores()` classifies battles by company count
  (1–3 minor +3, 4–7 major +8, 8+ decisive +15) via `_classify_battle_size()`.
  PU casualty upgrades: ≥5.0 total PU lost → decisive_battle_upgrade,
  ≥3.0 → major_battle_upgrade.
  `_process_commander_death_scores()` reads `commander_dead` from battle
  states, maps military rank via `_rank_to_death_event()`:
  Rikugunshokan → rikugunshokan_killed (+10), Taisa/Shireikan →
  taisa_shireikan_killed (+5), Chui/Gunso → gunso_chui_killed (+2).
  Commander death scores to the enemy clan.
  `_process_siege_war_scores()` reads resolved siege results:
  attacker_victory → siege_won_attacker (+12), defender_victory →
  siege_won_defender (+8).
  `_process_tether_war_scores()` detects BROKEN tether state
  (overall_state == 2) → supply_line_cut (+3) for the enemy clan.
  `_process_war_seasonal()` runs on season boundary: seasonal attrition
  (+1 initiator), disposition penalty (−2 per season active) between
  opposing-side characters.
  `_sync_wars_to_world_states()` converts WarData to context dicts for NPC
  engine compatibility. WorldStateData gains `active_wars: Array[WarData]`.
  New param on `advance_day()`: `active_wars`. Return dict gains
  `war_score_results`.
  Deferred: Peace court mechanics, Imperial edict intervention, trade route
  suspension on war declaration.

### War Justification & Casus Belli (s53.1)
- **simulation/war_justification.gd** — Five-step AI lord war initiation
  decision sequence per GDD s53.1. Pure static functions.
  Three MilitaryTier values: RAID, FORMAL_WAR, TOTAL_WAR.
  Step 1 Objective justification: 9 standing objectives mapped to tiers
  (EXPAND_TERRITORY all 3, MILITARY_DOMINANCE raid+formal, BUILD_STRONGEST
  raid only, etc.), 5 situational objectives (ADVANCE_FAMILY raid only,
  HONOR_ANCESTORS all 3, etc.), 5 primary objectives (CONQUER requires
  formal, DEFEND_PROVINCE all 3, AVENGE all 3, SABOTAGE raid only). 8
  peace objectives hard-block except DEFEND_PROVINCE.
  Step 2 Personality aggression: Yu/Kyoryoku/Ketsui virtues + weakness
  condition. Raid: garrison at minimum + no field army + no alliance.
  Formal war: raid condition met + 2x PU ratio.
  Step 3 Tier validation: intended tier must be in supported list.
  Step 4 Personality gates: Jin blocks total war expansion and resource
  raids. Gi/Makoto block covert warfare (undermine/sabotage).
  Step 5 Feasibility: runs FeasibilityLedger when feasibility_inputs provided.
  `evaluate_war_justification()` runs all 5 steps, returns justified/reason/
  step_failed/personality_driven.
  Wired into ActionExecutor: DECLARE_WAR intercepted before category routing.
  `_execute_declare_war()` reads standing/primary objectives, intended tier,
  and personality from `action.metadata`, runs `evaluate_war_justification()`
  as gate. Justified: returns `requires_war_creation: true` effect with
  declaring_clan, target_clan, authority_level. Rejected: returns
  `war_declaration_rejected` with reason and step_failed. Total War
  declaration costs −0.5 Honor.
  DayOrchestrator `_process_war_declarations()` scans applied results for
  `requires_war_creation` flag, creates WarData via `WarSystem.declare_war()`,
  appends to `active_wars`. Guards: no self-war, no duplicate active wars.
  Return dict gains `war_declarations`.
  DECLARE_WAR added to: action_skill_map (Courtier+Awareness), objective_alignment
  (INITIATE_WAR_CHECK: 95), personality_lean (14 virtues: Yu/Kyoryoku +15,
  Jin −20, Rei/Makoto −10, etc.), AT_OWN_HOLDINGS context list, AP cost 2,
  ADMINISTRATIVE_ACTIONS category, ceasefire block list.
  WorldStateData gains `next_war_id: Array[int] = [1]`.

### War Termination (s53)
- **simulation/war_termination.gd** — War ending mechanics per GDD s53. Pure
  static functions. Four ResolutionType values (FORMAL_SURRENDER,
  NEGOTIATED_SETTLEMENT, IMPERIAL_EDICT, ANNIHILATION).
  `compute_peace_terms(war, proposing_clan)` generates term demands based on
  war score: Dominant demands all captured territory + honor concession,
  Winning keeps captured territory, Ahead keeps half, Behind/Losing gets
  status quo ante. `evaluate_peace_acceptance(war, terms, receiving_clan,
  virtue, hostage, pressure)` wraps `WarSystem.compute_peace_willingness()`
  with acceptance threshold of 50.
  `resolve_formal_surrender()` ends war immediately, −1.0 Honor to loser.
  `resolve_negotiated_settlement()` ends war with agreed terms, +0.1 Honor
  to both sides. `resolve_imperial_edict()` ends war with status quo ante.
  `resolve_annihilation()` ends war, no stability bonus.
  `check_annihilation(war)` scans for war score 0 on either side.
  `resolve_negotiate_surrender()` is the NEGOTIATE_SURRENDER action
  resolution: Courtier+Awareness vs TN 20, raises reduce territory demands,
  then evaluates enemy acceptance. Returns `requires_peace_resolution: true`
  on successful acceptance for DayOrchestrator to finalize.
  `generate_war_end_topic()` creates TopicData per resolution type:
  surrender Tier 2 momentum 60, negotiated Tier 3 momentum 40, edict
  Tier 2 momentum 70, annihilation Tier 1 momentum 80.
  All +3 stability to involved provinces on peace (except annihilation).
- **ActionExecutor wiring** — NEGOTIATE_SURRENDER intercepted before category
  routing (same pattern as DECLARE_WAR). Reads `war_ref` from metadata,
  delegates to WarTermination.resolve_negotiate_surrender().
- **DayOrchestrator wiring** — `_process_war_terminations()` runs after war
  score shifts. Phase 1: scans active wars for annihilation (war score 0).
  Phase 2: scans applied results for `requires_peace_resolution` flag from
  NEGOTIATE_SURRENDER actions. Both phases call WarTermination resolution
  functions and generate war end topics. `_find_war_by_id()` helper.
  Return dict gains `war_termination_results`.
- **objective_alignment.json** — NEGOTIATE_SURRENDER added to SEEK_PEACE
  NeedType with score 95 (highest priority when at war).
- **Trade route suspension** — `suspend_trade_routes_for_war()` disrupts
  all TradeRouteData connecting provinces of warring clans (disruption_reason
  = "war_{clan_a}_{clan_b}"). `restore_trade_routes_for_peace()` restores
  routes with matching war disruption_reason on peace (except annihilation).
  DayOrchestrator `_process_war_trade_routes()` runs after war declarations,
  `_process_peace_trade_routes()` runs after war terminations. WorldStateData
  gains `trade_routes: Array`, threaded through `advance_one_day()`.
  Return dict gains `trade_route_results`.
  Deferred: Peace court mechanics (formal court session), Imperial edict
  action path, territory transfer mutations on settlement/province data.

### Feasibility Ledger (s4.3.17 Phase 1)
- **simulation/feasibility_ledger.gd** — AI War Readiness Check per GDD s4.3.17
  Phase 1. Pure static functions. Estimates whether a lord can sustain a proposed
  military campaign across three strategic resources (Rice, Arms, Koku).
  Step 1 Campaign length estimation: PROVINCIAL_RAID=1, BORDER_CONFLICT=2,
  FAMILY_WAR=3, CLAN_WAR=4 seasons. Personality modifiers: Yu/Kyoryoku −1
  (min 1), Seigyo/Chishiki +1, Ketsui/Ishi no change.
  Step 2 Rice budget: current stockpile + projected harvest (if spans autumn)
  − civilian burn (civilian_pu × 0.25 × seasons) − military burn
  ((military_pu + levy_pu) × 0.35 × seasons) − production loss (levy_pu × 1.50
  if before planting). Green: net ≥ 1.00 per total PU. Yellow: net ≥ 0 but
  < 1.00 per PU. Red: net < 0.
  Step 3 Arms budget: clan arms stockpile + projected iron production − equip
  cost − iron upkeep. Green: net ≥ 0. Yellow: deficit coverable by market koku.
  Red: can't equip at any cost.
  Step 4 Koku budget: treasury − stipend obligations − market purchases.
  Green: net ≥ 0. Yellow: covers market but not stipends. Red: financial collapse.
  Step 5 Composite verdict: All Green → FEASIBLE, Any Yellow no Red → RISKY,
  Any Red → NOT_FEASIBLE, All Red → DESPERATE. RISKY proceeds if high-priority
  objective OR aggressive personality (Yu/Kyoryoku/Ketsui/Ishi).
  `evaluate_feasibility(inputs)` is the top-level entry point returning
  `{feasible, verdict, campaign_seasons, rice, arms, koku}`.
  Wired into WarJustification Step 5 via optional `feasibility_inputs` parameter.
  When empty, Step 5 passes unconditionally (backward compatible).
  NPC engine `_build_feasibility_data()` populates feasibility data from
  world_state (settlements, clan data, koku) for lord-tier characters.
  `_build_declare_war_metadata()` threads feasibility_inputs into DECLARE_WAR
  action metadata when feasibility_data is available on ContextSnapshot.
  ContextSnapshot gains `feasibility_data: Dictionary` field.
  Phase 2 Alternative Ladder: 7-rung sequential evaluation when feasibility
  fails. `walk_alternative_ladder()` walks all rungs, recalculating after each.
  Rung 1 Scale Down: halve levy PU and equip cost.
  Rung 2 Delay to Harvest: set spans_autumn=true if spring/summer; Yu/Kyoryoku
  skip (delay = cowardice).
  Rung 3 Market Purchase: spend 50% koku for rice; requires Green/Yellow koku
  and active trade routes.
  Rung 4 Demand Tribute: 25% of vassal stockpiles; −5 disposition per vassal;
  Rival (−11) refuses; Jin skips shortage vassals; generates Tier 4 topic.
  Rung 5 Allied Aid: Friend+ (31+) allies contribute 25% surplus; creates
  favor (Tier 2 if >20% of ally surplus, Tier 3 otherwise); Ketsui/Ishi skip.
  Rung 6 Raid Neighbor: seize 50% rice from weak province (garrison ≤1.0 PU);
  −1.0 Honor, −0.3 Glory, −15 clan disposition, −5 other clans; Jin/Gi never;
  Meiyo needs grievance; Rei needs prior demand; prefers existing war targets;
  triggers Provincial Raid if not already at war; Tier 3 topic.
  Rung 7 Desperation Override: requires rice <0.50/PU + critical objective
  (DEFEND_PROVINCE, SEEK_VENGEANCE, AVENGE, RESOLVE_CLAN_WAR) + aggressive
  virtue (Yu/Chugi/Ketsui/Kyoryoku/Ishi) or Desperate war score (<25) while
  defending. Jin lords pay extra −1.0 Honor. Tier 3 topic.
  Returns `{outcome, rungs_tried, final_ledger, side_effects}`.
  Phase 3 Mid-Campaign Supply Status Monitor: seasonal survival assessment
  for fielded armies. Three checks: Home Front Status (Clear/Shortage/Hunger/
  Famine by worst-case settlement rice-per-PU), Army Supply Status (Supplied/
  Unsupplied from tether state + source rice), Iron Upkeep Status (Maintained/
  Degrading from clan iron vs total upkeep). Response matrix combines Home
  Front × Army Supply: Clear+Supplied=CONTINUE, Shortage+winning(65+)=
  PUSH_TO_FINISH, Shortage+losing=SEEK_PEACE, Hunger=URGENT_PEACE,
  Famine=IMMEDIATE_PEACE. Personality overrides: Yu/Kyoryoku/Ishi ignore
  Shortage; only Ishi ignores Hunger and Famine (even Yu seeks peace at
  Famine). Supply cut=RESTORE_TETHER for 1 season (Ketsui holds 2), then
  RETREAT. Retreat target selection: nearest friendly province (≤2 distance)
  with rice≥1.0/PU or forge; disband if no target found (generates Tier 4
  topic). `run_supply_status_check(inputs)` is the top-level entry point.
  Wired into DayOrchestrator: `_process_supply_status_checks()` runs on
  season boundary after `_process_war_seasonal()`. Iterates lord-tier NPCs
  involved in active wars with fielded companies. Collects clan settlements,
  worst tether state, iron upkeep totals, and war score per side. Returns
  per-lord results with `peace_need` flag (for SEEK_PEACE/URGENT_PEACE/
  IMMEDIATE_PEACE decisions) and `retreat` target (for RETREAT decisions).
  Results stored in `military_seasonal["supply_status"]`.
  Supply status results consumed by `_consume_supply_status_results()`:
  peace decisions inject `pending_events` into lord's `world_states`
  (SEEK_PEACE need_type, priority 1 for URGENT/IMMEDIATE, priority 2 for
  SEEK_PEACE). Retreat decisions flag clan armies with `retreat_ordered` and
  `retreat_target_province`; disband orders generate Tier 4 army_disbanded
  topic. Retreat flags consumed by `_initiate_retreat_march()` inside
  `_process_army_movements()`: begins a placeholder march toward
  `retreat_target_province` with default 3-day travel time (will use real
  pathfinding when coordinate system exists). Skips already-moving,
  disband-ordered, or target-less armies. Sets `retreat_arrived` flag on
  movement result when retreat march completes.
  Retreat arrival cleanup: `_process_retreat_arrivals()` runs after movement
  tick. When `retreat_arrived` fires: clears `retreat_ordered` and
  `retreat_target_province` flags from army, detaches supply tether via
  `SupplyTetherSystem.detach_tether()` (resets deprivation, frees escort
  companies, marks tether `detached=true`). Detached tethers skipped by
  tether tick, deprivation, and recovery processing. `army_id` added to
  movement results for retreat arrival lookup. `_find_army_by_id()` and
  `_detach_army_tether()` helper functions. Return dict gains
  `retreat_arrival_results`.
  Disband-ordered armies processed by `_process_disbands()` before movement:
  deactivates army, returns PU proportional to company health via
  `PUReconciliation.return_disband_pu()` to source province settlements.
  Runs before movement tick so disbanded armies don't get movement ticked.
  Deferred: forge infrastructure for arms production projection, stipend
  obligations, real pathfinding for retreat marches (needs coordinate system).

### Starvation Warfare (s4.3.17 Phase 4)
- **simulation/starvation_warfare.gd** — Player-initiated starvation strategies
  per GDD s4.3.17 Phase 4. Pure static functions. Two hostile military actions:
  1. **RAID_HARVEST** — Army present in a province during Autumn destroys that
     year's harvest (yield → 0). Honor −2.0, Glory −0.5, −20 permanent
     disposition from targeted clan (historical modifier, never decays), −10
     from other clans who learn of it (decays). Tier 2 Military/Political
     topic. Farming PU unharmed — crop-only destruction. Harvest recovers
     next year (flag auto-cleared after resource tick). Personality gates:
     Jin/Gi/Rei NEVER. Yu only if no other path. Meiyo only vs hated enemy.
     Chugi only if lord commands. Makoto only if publicly declared. All
     Shourido unrestricted. `evaluate_ai_harvest_decision()` combines
     personality gate with condition evaluation.
  2. **BLOCKADE_TRADE_ROUTE** — Military unit (≥1.0 PU) on a trade route node
     blocks Rice/Iron/Koku flow. Triggers War Status (Provincial Raid) if not
     already at war. Honor −0.5 per season maintained (stacks per route).
     `process_seasonal_blockade_honor()` returns per-clan results.
  Imperial edict consequence: −3.0 Honor to attacker, +5 disposition toward
  targeted clan (deferred until Emperor AI response is implemented).
- **simulation/resource_tick.gd** — `_process_harvest()` checks
  `harvest_destroyed` flag in settlement_meta. Destroyed provinces yield 0
  rice that Autumn. Flag cleared after processing so harvest recovers next year.
- **simulation/disposition_system.gd** — New historical events:
  `destroyed_harvest` (start −20, floor −20, decay false — permanent),
  `witnessed_harvest_destruction` (start −10, floor −5, decay true).
- **ActionExecutor** — RAID_HARVEST and BLOCKADE_TRADE_ROUTE routed to
  `StarvationWarfare.execute_harvest_destruction()` and
  `StarvationWarfare.execute_blockade()` respectively. Return
  `requires_harvest_destruction` / `requires_blockade` effect flags.
- **DayOrchestrator** — `_process_starvation_warfare_effects()` runs after
  military effects. Harvest destruction: applies `harvest_destroyed` flag to
  `season_meta`, generates Tier 2 topic, applies permanent disposition modifier
  to targeted clan + decay modifier to other clans. Blockade: disrupts route,
  creates Provincial Raid war if not already at war.
  Seasonal: `process_seasonal_blockade_honor()` runs on season boundary.
  Deferred: Emperor edict response via StrategicReview, blockade unit
  presence validation (needs coordinate system for node tracking).

### Ladder Side Effects Processing
- **DayOrchestrator `_process_ladder_side_effects()`** — Runs after
  `_process_war_declarations()`. Scans applied results for
  `ladder_side_effects` dicts produced when a DECLARE_WAR action passed
  through the Alternative Ladder. Processes 7 effect types:
  - `glory_cost` — applied to declaring lord (raid rung: −0.3)
  - `disposition_cost` — applied to all vassals of declaring lord
    (tribute rung: −5 per vassal)
  - `clan_disposition_cost` — all target clan chars toward declaring
    clan chars (raid rung: −15)
  - `other_disposition_cost` — all non-declaring, non-target clan chars
    toward declaring clan chars (raid rung: −5)
  - `generates_topic` — creates TopicData (war_preparation topic_type,
    rung-specific variant/slug, Tier 3 or 4 with appropriate momentum)
  - `creates_favor` — creates FavorData for allied aid debt (GENERAL
    type, Tier 2 MODERATE or Tier 3 MINOR)
  - `triggers_war_status` — creates a Provincial Raid war against the
    raided clan (guards against duplicates)
  `_extract_side_effects()` in FeasibilityLedger enriched with `rung`,
  `raid_target_clan`, `raid_target_province_id` fields.
  Return dict gains `ladder_effects_results`.

### War Trigger Pipeline (Metadata Population)
- **Phase 3 metadata population** — `_populate_action_metadata()` in
  npc_decision_engine.gd populates action-specific metadata during Phase 3
  option generation. DECLARE_WAR gets `standing_objective` (from
  `need.target_intent`), `target_clan` (from need or province statuses),
  `intended_tier`, `authority_level`. NEGOTIATE_SURRENDER gets `war_ref`
  (WarData reference from `_war_ref` key in context war dicts),
  `target_clan`, `target_virtue`, `hostage_held`, `superior_pressuring`.
- **Metadata flow** — `execute_action()` copies metadata to decision dict
  when non-empty. `_execute_decision()` in NPCWaveResolver copies metadata
  from decision to ScoredAction before ActionExecutor receives it.
- **ObjectiveDecomposer target_intent** — EXPAND_TERRITORY and
  MILITARY_DOMINANCE decomposition trees produce INITIATE_WAR_CHECK needs
  with `target_intent` carrying the originating standing objective type.
  MILITARY_DOMINANCE gains a preemptive strike path when lord is behind
  rival (dominance_ratio 0.7–1.0) and has no levy PU.
- **war_system.gd** — `to_context_dict()` gains `_war_ref` key carrying
  the WarData reference for NEGOTIATE_SURRENDER metadata lookup.
- NEGOTIATE_SURRENDER added to AT_OWN_HOLDINGS action list.
- **Standing objective war check paths** — 7 additional standing objectives
  now produce INITIATE_WAR_CHECK needs: SEEK_VENGEANCE (clan-targeted, all
  tiers), UNDERMINE_CLAN (clan-targeted, Tier 3/2), PREVENT_SHORTAGE (when
  rice < 1 season, Tier 3 only), BUILD_STRONGEST_FORCE (when all training
  done, Tier 3 proving exercise), ADVANCE_GLORY (bushi lords only, Tier 3),
  ADVANCE_FAMILY (lords at own holdings, Tier 3), HONOR_ANCESTORS (requires
  active wars or escalating conflicts, all tiers). All gate on is_lord +
  AT_OWN_HOLDINGS + weak neighbor province availability.
- **ProvinceStatus.clan** — `NPCDataStructures.ProvinceStatus` gains `clan`
  field for clan-targeted province lookups. New helper
  `_find_weak_neighbor_province_for_clan()` filters by target clan.
- **Weakness conditions (s53.1)** — `ProvinceStatus` gains `total_settlement_pu`,
  `has_field_army_nearby`, `has_alliance_protection` fields. `WarJustification`
  gains `GARRISON_MINIMUM_RATIO = 0.05`, `is_garrison_at_minimum()` (garrison
  at/below 5% of total settlement PU), `evaluate_province_weakness()` (all
  three conditions: garrison at minimum + no field army + no alliance).
  `_find_weak_neighbor_province()` and `_find_weak_neighbor_province_for_clan()`
  upgraded from stability-based to full weakness evaluation. Own-clan provinces
  skipped in generic weak-neighbor search. `build_province_statuses_from_data()`
  populates `total_settlement_pu` from settlement `population_pu`.
- **Formal war weakness in metadata** — `_build_declare_war_metadata()` now
  populates `target_garrison_at_minimum`, `no_field_army_nearby`,
  `no_alliance_protection`, `defender_observable_pu` (target province garrison),
  and `attacker_pu` (available_levy_pu + sum of own-clan garrison PU). These
  flow through to `evaluate_war_justification()` in ActionExecutor for the
  Step 2 personality aggression weakness gate. When no target province status
  is found, weakness fields are omitted (defaults to false/0.0 in executor).
- **Field army detection wiring** — `ArmyMovementSystem.create_army_state()`
  gains optional `province_id: int = -1` parameter. `build_province_statuses_from_data()`
  gains optional `active_armies: Array` parameter — scans army states and sets
  `has_field_army_nearby = true` on any province where a non-own-clan army is
  positioned. `build_context()` threads `active_armies` from world_state into
  the province status builder. Armies without `province_id` (default -1) are
  ignored. Callers populate `province_id` on army state when sub-tile→province
  mapping becomes available.

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
  `FavorSystem.process_deadline_breaches()` on the favors array.
  `_apply_favor_breach()` applies breach consequences: debtor honor/glory
  loss via HonorGlorySystem, creditor disposition change with
  `disposition_floor` enforcement (prevents minor favor breaks from creating
  Blood Enemies), and witness disposition loss. New param on `advance_day()`:
  `favors`.
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
- **SuccessionSystem** — Daily: `_process_lord_deaths()` triggers
  `SuccessionSystem.trigger_succession()` on lord death events. Gathers
  candidates, finds confirming authority, determines clean/disputed, generates
  succession topic, auto-confirms clean successions via heir evaluation.
  `_process_successions()` ticks active disputed successions daily and
  force-confirms on expiry (60 ticks). Seasonal: `_evaluate_heir_designations()`
  runs on season boundary for lord-tier NPCs without heirs (or Seigyo lords
  who re-evaluate every season). Uses 9-factor scoring to designate heirs.
  New params on `advance_day()`: `active_successions: Array[SuccessionData]`,
  `next_succession_id: Array[int]`. Return dict gains `succession_results`.
- **SecretSystem / SeductionSystem / AssassinationSystem / BoundEscapeSystem** —
  Phase 7: ActionExecutor intercepts 17 covert ActionIDs before the generic
  skill path. Routes EAVESDROP, INTERCEPT_LETTER, SEARCH_QUARTERS,
  SHADOW_TARGET to SecretSystem contested/two-step resolution. Routes
  CONCEAL_ITEM, SEARCH_PERSON, FORGE_IMPERSONATION_LETTER, FORGE_ORDER,
  FABRICATE_SECRET to SecretSystem static methods. Routes SEDUCE and 4
  variants to SeductionSystem.resolve_seduction(). Routes
  EXPOSE_SECRET_PRIVATELY/PUBLICLY to SecretSystem.reveal_privately()/
  expose_publicly() with co-located witness gathering. ScoredAction gains
  `metadata: Dictionary` for action-specific parameters (item_size, authority_level,
  secret_ref, concealment_tn, etc.). Daily: `_process_entanglements()` checks
  16-day maintenance windows, marks neglected/broken, removes broken.
  `_process_bound_states()` auto-attempts escape for bound characters with
  Sleight of Hand skill, removes freed states. New params on `advance_day()`:
  `entanglements: Array[Dictionary]`, `bound_states: Array[Dictionary]`.
  Return dict gains `entanglement_results`, `bound_escape_results`.
- **Military Phase 2 Systems** — Daily: `_process_military_daily()` runs after
  bound/entanglement processing and before NPC wave resolution. Ticks four
  subsystems each day: `_process_army_movements()` decrements march days for
  all active armies (ArmyMovementSystem), `_process_siege_ticks()` processes
  starvation and events for all active sieges (SiegeSystem),
  `_process_tether_ticks()` resolves garrison raids and deprivation for supply
  tethers (SupplyTetherSystem), `_process_order_ticks()` resets daily order
  budgets and delivers pending orders (OrderSystem). Seasonal:
  `_process_military_seasonal()` runs on season boundary after historical
  modifier decay. `_process_army_upkeep()` computes seasonal rice/iron/koku
  costs across all companies via ArmyUpkeepSystem. `_process_military_promotions()`
  scans for commander vacancies and fills them via MilitaryPromotionSystem
  candidate scoring. New params on `advance_day()`: `active_armies`,
  `active_sieges`, `active_tethers`, `order_states`, `companies`, `clans`.
  WorldStateData gains matching fields. Return dict gains `military_daily`.
  Post-execution: `_process_military_effects()` scans day results for effect
  flags. ORDER_LEVY → `_apply_levy_pu_effect()` calls
  `PUReconciliation.consume_levy_pu()` on source settlement. ORDER_BATTLE →
  `_apply_battle_pu_reconciliation()` calls `PUReconciliation.reconcile_battle()`
  with victor/loser company data from effects dict. ASSIGN_TO_MILITARY_SERVICE →
  `_apply_service_assignment_effect()` calls
  `MilitaryServiceSystem.assign_to_military_service()` to mutate
  operational_superior_id. Return dict gains `military_effects`.
  Iron degradation: `ArmyUpkeepSystem.process_iron_upkeep_dict()` added for
  dict-based companies. Seasonal upkeep groups companies by clan, deducts
  iron from `ClanData.arms_stockpile`, tracks per-company iron state for
  degradation penalties.
  Battle flow: `ArmyCombatSystem.extract_pu_reconciliation_data()` extracts
  per-company health summaries (starting_health, current_health,
  source_province_id) from battle states for PU reconciliation.
  `DayOrchestrator.resolve_and_reconcile_battle()` runs the full pipeline:
  battle resolution → PU extraction → reconciliation → rout → recovery →
  dissolution (when rout dissolves army below 20% health, surviving company
  health returned as PU to source settlements via
  `PUReconciliation.process_army_dissolution()`). Pursuit casualties
  distributed across non-destroyed loser companies before dissolution.
  Army movement processing detects battle triggers on arrival via
  `ArmyMovementSystem.check_battle_trigger()`.
  `ArmyCombatSystem.is_cavalry()` public helper for cavalry detection.
  Rice upkeep deduction: `_deduct_rice_upkeep()` deducts seasonal rice costs
  from clan settlements' `rice_stockpile` using `ClanData.province_ids` to
  locate the correct settlements. Deduction caps at available stockpile.
  Koku upkeep deduction: `_deduct_koku_upkeep()` deducts garrison (0.20/PU/
  season) and ronin (1.50/season) koku costs from clan settlements'
  `koku_stockpile`. Units with zero koku cost skip deduction.
  Field deprivation: `_process_field_deprivation()` runs after tether ticks,
  computing per-company rice (morale/health loss) and arms (attack/defense
  penalty) effects based on tether deprivation tick levels. Tick 1 = warning
  only; ticks 2–4 apply escalating penalties per ArmyUpkeepSystem tables.
  Effects returned as descriptors for caller to apply to CompanyData objects.
  Army recovery: `_process_army_recovery()` runs after deprivation, producing
  recovery descriptors for stationary armies with solid supply. +5 health/tick
  and +3 morale/tick (capped at base stats), arms tier restoration when arms
  deprivation tick > 1. Moving armies skip recovery. Broken/threatened tethers
  block supply and prevent recovery.
  Military event topics: `_generate_military_event_topics()` scans daily
  military results and generates TopicData for three event types: battle
  outcome (Tier 3, momentum 30, battle_variant per GDD s15.7), heavy
  casualties (Tier 3, momentum 25, when PU loss ≥ 0.5), siege events
  (Tier 4, momentum 11, event_type as variant). Topics added to
  active_topics for organic spread via the momentum/broadcast system.
  Koku upkeep deduction: `_deduct_koku_upkeep()` deducts garrison (0.20/PU/
  season) and ronin (1.50/season) koku costs from clan settlements'
  `koku_stockpile`. Units with zero koku cost skip deduction.
  Field deprivation: `_process_field_deprivation()` runs after tether ticks,
  computing per-company rice (morale/health loss) and arms (attack/defense
  penalty) effects based on tether deprivation tick levels. Tick 1 = warning
  only; ticks 2–4 apply escalating penalties per ArmyUpkeepSystem tables.
  Effects returned as descriptors for caller to apply to CompanyData objects.
  Army recovery: `_process_army_recovery()` runs after deprivation, producing
  recovery descriptors for stationary armies with solid supply. +5 health/tick
  and +3 morale/tick (capped at base stats), arms tier restoration when arms
  deprivation tick > 1. Moving armies skip recovery. Broken/threatened tethers
  block supply and prevent recovery.

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
