# ARCHITECTURE.md — System Map & Function Index

Quick reference for where data lives and what each script does.
For design rationale and implementation rules, see CLAUDE.md.

---

## Directory Layout

```
/shared/          Data models (Resource subclasses). No logic beyond defaults.
/simulation/      Stateless static functions (no Node). All game logic lives here.
/systems/         JSON scoring tables, data files.
/tests/           GUT test files mirroring simulation/ structure.
/autoload/        Godot singletons (registered in Project Settings).
/client/          Player-facing scenes. No simulation logic.
/gdd/             Game Design Document (read-only reference).
```

---

## Data Models (`/shared/`)

### L5RCharacterData (`character_data.gd`)

| Group | Fields |
|-------|--------|
| Identity | `character_id`, `character_name`, `clan`, `family`, `school`, `school_type`, `age`, `gender` |
| Traits | `stamina`, `willpower`, `strength`, `perception`, `agility`, `intelligence`, `reflexes`, `awareness` |
| Void | `void_ring`, `current_void_points`, `max_void_points` |
| Skills | `skills: Dictionary`, `emphases: Dictionary` |
| Abilities | `techniques`, `kiho`, `katas`, `spells_known` (all `Array[String]`) |
| Shugenja | `affinity_element`, `deficiency_element` |
| Merits | `advantages`, `disadvantages` (both `Array[String]`) |
| Social | `honor: float`, `glory: float`, `status: float`, `infamy: float` |
| Health | `wounds_taken: int`, `taint: float` |
| Equipment | `weapons`, `armor_worn`, `armor_tn_bonus`, `armor_reduction`, `outfit`, `koku` |
| Personality | `bushido_virtue`, `shourido_virtue` |
| Hierarchy | `lord_id`, `operational_superior_id`, `operational_hierarchy_type`, `military_rank`, `commanded_unit_id`, `assigned_company_id`, `designated_heir_id` |
| World | `current_objective`, `physical_location`, `role_position`, `captive_status`, `active_quest` |
| Social State | `disposition_values: Dictionary`, `fear_rating`, `met_characters: Array[int]` |
| Topics | `topic_pool: Array[int]`, `topic_positions: Dictionary` |
| Knowledge | `knowledge_pool: Array[KnowledgeEntry]`, `known_contacts_by_clan: Dictionary` |
| Legal | `legal_cases: Array[Dictionary]` |
| Technique State | `self_reroll`, `granted_reroll`, `enhanced_void`, `timed_advantages`, `action_blocks`, `combat_modifiers_pending` |
| Supply | `supply_ledger: Dictionary` |
| Art | `pieces_seen: Dictionary`, `learning_progress: Dictionary` |
| Cooldowns | `void_refresh_blocked_until`, `last_medicine_treatment_ic_day` |
| Action Economy | `action_points_current`, `action_points_max`, `civilian_order_budget_max`, `civilian_orders_remaining` |
| Rest | `rested_last_night`, `last_wind_down_method`, `wind_down_void_modifier` |
| Poison | `active_poisons: Array[Dictionary]` |
| Family | `mother_id`, `father_id`, `sibling_ids`, `children_ids`, `spouse_id` |
| Kolat | `kolat_superior_id`, `kolat_sect` |
| Misc | `hunt_trophies`, `trained_companions`, `aboard_ship_id`, `passage_request_count_today`, `assigned_ship_id` |
| Tattoo State | `mantis_tattoo`, `ocean_tattoo`, `ocean_last_used_ooc_day`, `phoenix_last_used_ic_day`, `crane_pool`, `kirin_reroll_available`, `active_tattoo_ability`, `is_bald` |
| Progression | `xp_total`, `xp_spent`, `progress_bars: Dictionary` |

### ProvinceData (`province_data.gd`)

| Field | Type |
|-------|------|
| `province_id` | `int` |
| `province_name`, `clan`, `family`, `description` | `String` |
| `adjacent_province_ids` | `Array[int]` |
| `is_coastal` | `bool` |
| `rivers`, `roads` | `Array[String]` |
| `terrain_type` | `Enums.TerrainType` |
| `settlement_ids` | `Array[int]` |
| `rice_stockpile`, `koku_stockpile`, `iron_stockpile`, `arms_stockpile` | `float` |
| `population_pu`, `farming_pu`, `mining_pu`, `town_pu`, `military_pu` | `int` |
| `stability` | `float` |
| `active_crisis_id`, `active_insurgency_id` | `int` |
| `garrison_pu` | `int` |
| `last_report_ic_day` | `int` |

### SettlementData (`settlement_data.gd`)

`settlement_id`, `settlement_name`, `province_id`, `settlement_type`, `description`, `infrastructure: Array[String]`, `garrison_capacity`, `current_garrison`, `population_pu`.

### CommitmentData (`commitment_data.gd`)

`commitment_id`, `commitment_type`, `source_action_id`, `creditor_npc_id`, `debtor_npc_id`, `deadline_ic_day`, `fulfillment_target`, `tier`, `status`, `witnesses: Array[int]`, `created_ic_day`, `advance_notice_sent`, `notice_ic_day`, `proxy_sent`, `crisis_id`, `penalty_records`.

### TattooData (`tattoo_data.gd`)

`tattoo_id`, `recipient_id`, `artist_id`, `quality_tier`, `body_location`, `subject_type`, `subject_description`, `topic_id`, `is_ability_tattoo`, `ability_granted`, `date_applied`, `is_visible`.

### KnowledgeEntry (`knowledge_entry.gd`)

`source: KnowledgeSource`, `entry_type: String`, `data: Dictionary`, `confidence: KnowledgeConfidence`, `season_acquired: int`.

### TopicData (`topic_data.gd`)

`topic_id`, `slug`, `title`, `topic_type`, `variant`, `tier` (Tier enum: TIER_1-4), `category` (Category enum: PERSONAL, POLITICAL, MILITARY, SUPERNATURAL, ECONOMIC, LEGAL), `momentum`, `provinces_affected`, `clan_involved`, `family_involved`, `subject_character_id`, `subject_role`, `ic_day_created`, `resolved`, `discussion_count_this_day`.

### CrimeRecord (`crime_record.gd`)

`case_id`, `crime_type`, `severity`, `perpetrator_id`, `victim_id`, `location`, `ic_day_committed`, `legal_status`, `concealment_tn`, `evidence_total`, `investigating_magistrate_id`, `ic_day_conviction`, `seppuku_offered`, `seppuku_accepted`, `witnesses: Array[int]`, `known_suspects: Array[int]`, `escalation_count`, `skimming_amount`.

### Enums (`enums.gd`)

Ring, Trait, WoundLevel, Stance, SchoolType, ContextFlag, BushidoVirtue, ShouridoVirtue, TerrainType, SettlementType, CrimeType, CrimeSeverity, LegalStatus, Sublocation, AccessDenialReason, CommitmentType, CommitmentStatus, DeploymentStatus, ZoneSubtype (24), LordRank, TattooBodyLocation (9), TattooQualityTier, TattooSubjectType, TattooAbility (26), CulturalReluctance, MilitaryRank (8), OperationalHierarchyType, KolatSect (7), KnowledgeSource (5), KnowledgeConfidence (3), ShipClass (7).

---

## Simulation Scripts (`/simulation/`)

### DiceEngine (`dice_engine.gd`)
Single authoritative rolling entry point. Seedable RNG.
- `roll_and_keep(rolled, kept, explodes, emphasis) → DiceResult`
- `roll_check(rolled, kept, tn, raises, bonus, explodes, emphasis) → Dictionary`
- `roll_skill_check(trait_value, skill_rank, tn, raises, bonus, has_emphasis) → Dictionary`
- `contested_roll(a_rolled, a_kept, b_rolled, b_kept, ...) → Dictionary`
- `roll_initiative(reflexes, insight_rank) → DiceResult`
- `roll_damage(rolled, kept, strength_bonus, reduction) → Dictionary`

### DiceResult (`dice_result.gd`)
Data class: `kept_dice`, `dropped_dice`, `total`, `explosions`, `overflow_bonus`.

### CharacterStats (`character_stats.gd`)
Pure static. Ring calculation, Insight, Insight Rank, Armor TN, wound levels, death check.
- `get_ring_value(character, ring)`, `get_earth_ring(character)`
- `get_insight(character)`, `get_insight_rank(character)`
- `get_armor_tn(character)`, `get_wound_level(character)`, `get_wound_penalty(character)`
- `is_dead(character)`

### WoundSystem (`wound_system.gd`)
- `apply_damage(character, raw_damage, reduction) → Dictionary`
- `heal_wounds(character, amount) → Dictionary`
- `apply_falling_damage(character, tiles_fallen, dice_engine) → Dictionary`

### HonorGlorySystem (`honor_glory_system.gd`)
Honor/Glory/Status/Infamy changes clamped 0-10. Court honor modifier. Atonement.
- `apply_honor_change`, `apply_glory_change`, `apply_status_change`, `apply_infamy_change`
- `get_honor_rank`, `get_glory_rank`, `get_status_rank`, `get_infamy_rank`
- `get_court_honor_modifier(character)`, `get_recognition_rank(character)`

### SkillResolver (`skill_resolver.gd`)
Bridges CharacterData to DiceEngine. Trait lookup, rank, emphasis, wound penalty.
- `resolve_skill_check(character, skill_name, tn, dice_engine, ...) → Dictionary`
- `resolve_contested_check(char_a, char_b, skill_a, skill_b, dice_engine) → Dictionary`
- `get_trait_for_skill(skill_name)`, `get_skill_rank(character, skill_name)`
- `has_emphasis(character, skill_name, emphasis_name)`

### ActionPointSystem (`action_point_system.gd`)
2 AP per IC day. No carryover.
- `reset_daily_ap(character)`, `can_spend(character, cost)`, `spend_ap(character, cost)`

### TimeSystem (`time_system.gd`)
1 tick = 1 IC day = 6 real hours. 360 days/year, 12×30 months.
- `advance_tick()`, `get_ic_day()`, `get_season()`, `is_winter_court()`

### NPCDataStructures (`npc_data_structures.gd`)
`ImmediateNeed` (generic target system), `ScoredAction` (8 base + 5 wired scoring components including `stale_intel_bonus`), `ContextSnapshot`, `ProvinceStatus`. Competence modifier table.

### NPCDecisionEngine (`npc_decision_engine.gd`)
Full 7-phase loop: Build Context → Resolve Goal → Generate Options → Personality Filter → Score All → Select → Execute.
- `build_context(character, world_state) → ContextSnapshot`
- `resolve_goal(character, ctx, ...) → ImmediateNeed`
- `generate_options(goal, ctx) → Array[String]`
- `apply_personality_filter(options, character, filter_data) → Array[String]`
- `score_all(options, goal, ctx, character, ...) → Array[ScoredAction]`
- `select_action(scored_actions) → ScoredAction`
- `execute_action(selected, character) → Dictionary`
- `run(character, world_state, ...) → Dictionary` — full pipeline

### ObjectiveDecomposer (`objective_decomposer.gd`)
Routes standing objectives to decomposition trees. Political (6), Economic (5), Personal (8), Military (7) + Investigation.
- `decompose(objective, ctx) → ImmediateNeed`

### ActionExecutor (`action_executor.gd`)
Routes ActionIDs to SkillResolver dice rolls. Categories: social, covert, military, admin, self, intelligence.
- `execute(action_id, character, target_npc_id, ctx, dice_engine, ...) → Dictionary`

### EffectApplicator (`effect_applicator.gd`)
Applies executor results to world state. Disposition, honor, glory, province effects, action log.
- `apply(result, character, characters_by_id, ...) → void`
- `apply_day_results(day_results, characters, ...) → Dictionary`

### NPCWaveResolver (`npc_wave_resolver.gd`)
Full day resolution. Reactive events first, then AP waves. Status-descending order.
- `resolve_day(characters, ...) → Array` — decisions only
- `resolve_day_full(characters, ...) → Array` — decisions + dice rolls
- `resolve_day_applied(characters, ...) → Dictionary` — decisions + rolls + world mutation

### DayOrchestrator (`day_orchestrator.gd`)
Single `advance_day()` entry point. Sequence: reset AP → wave resolution → crime detection (+ crime topic creation) → commitment deadlines → conversations → topic wiring → topic tick → broadcast → UPHOLD_LAW scan → info events (+ witness PROBE evidence) → letters → season transition (resource tick + knowledge decay).
- `advance_day(time_system, characters, ..., next_topic_id) → Dictionary`

### InformationSystem (`information_system.gd`)
Knowledge management. Five sources, confidence decay (Fresh→Recent→Stale).
- `add_knowledge(character, entry)`, `add_contact(character, target_clan, target_id)`
- `process_probe_result(character, target, action_log, season)`
- `process_observe_court(character, attendees, ...) → Array`
- `process_introduction(introducer, character, target, ...)`
- `transfer_objective_knowledge(lord, vassal, objective, season, province_statuses)`
- `decay_confidence(character, current_season)`
- `get_best_confidence_on_target(character, target_id) → int`
- `get_stale_entries(character) → Array[KnowledgeEntry]`

### TopicMomentumSystem (`topic_system.gd`)
Momentum levels, daily tick, broadcast. Starting position calculation.
- `process_daily_tick(topics) → Dictionary`
- `broadcast_public_knowledge(topics, characters, char_province_map, ...) → Array`
- `calculate_starting_position(character, topic, characters_by_id) → float`
- `increment_discussion_counts(topics, discussed_topic_ids)`

### DailyConversation (`daily_conversation.gd`)
Settlement-based NPC conversations. Topic transfer, disposition bonus.
- `resolve_settlement_conversations(characters, dice_engine, ...) → Array`

### LetterSystem (`letter_system.gd`)
Letter delivery, quality, reply chance. Exchange bonus.
- `write_letter(sender, recipient, ...) → Dictionary`
- `process_pending_letters(pending, characters_by_id, ...) → Array`

### ResourceTick (`resource_tick.gd`)
Seasonal resource processing. Rice, tax cascade, iron, koku, population growth.
- `process_seasonal_tick(provinces, ...) → Dictionary`
- `consume_rice_province(province) → Dictionary`
- `check_starvation(province, season) → Dictionary`

### CrimeSystem (`crime_system.gd`)
At-act and at-conviction consequences. Seppuku. Escalation tracking.
- `create_crime_record(perpetrator_id, crime_type, location, ic_day, ...) → CrimeRecord`
- `apply_at_act_consequences(character, crime_type) → Dictionary`
- `apply_at_conviction_consequences(character, record, ...) → Dictionary`

### InvestigationSystem (`investigation_system.gd`)
Scene examination, witness evidence, UPHOLD_LAW probability, self-initiation wiring, witness PROBE evidence, conviction topic generation.
- `examine_scene(magistrate, crime_record, dice_engine, ic_day) → Dictionary`
- `get_uphold_law_probability(bushido, shourido) → int`
- `should_assign_uphold_law(bushido, shourido, rng_roll) → bool`
- `calculate_witness_evidence(awareness, honor) → int`
- `prioritize_witnesses(candidates, characters_by_id, present_ids) → Array[int]`
- `check_jurisdiction(magistrate, crime_record) → bool`
- `activate_uphold_law(magistrate, crime_record, standing_objective) → Dictionary`
- `scan_for_crime_topics(magistrate, standing_obj, crime_records, topics) → Dictionary`
- `process_witness_interview(crime_record, target_id, quality, objective) → Dictionary`
- `generate_conviction_topic(record, convicted, tier, next_topic_id, ic_day) → TopicData`
- `generate_seppuku_refusal_topic(convicted, next_topic_id, ic_day) → TopicData`

### InvestigationDecomposer (`investigation_decomposer.gd`)
Seven-phase investigation loop: travel → examine → witnesses → suspects → alibis → leads → resolution.
- `decompose(objective, ctx) → ImmediateNeed`

### CommitmentRegistry (`commitment_registry.gd`)
Six commitment types. Consequence tables. Force majeure forgiveness. Phase 5 at-risk penalties.
- `create_commitment(type, creditor, debtor, ...) → CommitmentData`
- `process_deadlines(commitments, ic_day, characters_by_id, ...) → Array`
- `get_at_risk_penalty(character, commitments, ic_day) → float`

### ApproachEvaluation (`approach_evaluation.gd`)
Measurement pressure, approach assessment tags, penalty registry with seasonal decay.
- `check_measurement_needed(character, action_id, action_log, ...) → Dictionary`
- `evaluate_approach(character, action_id, ...) → String`
- `get_scoring_modifier(character, action_id, ...) → float`
- `decay_penalties(penalties, seasons_elapsed)`

### TravelCommitment (`travel_commitment.gd`)
Travel redirect penalty, sublocation access, stall detection.
- `get_redirect_penalty(travel_redirects) → int`
- `can_access_sublocation(character, sublocation, ctx) → bool`
- `is_stalled(character, action_log, ...) → bool`

### MilitaryHierarchy (`military_hierarchy.gd`)
Five-level org chain. Deployment, vacancy, operational superior resolution.
- `get_company_chain(company_id, legions, sections, armies) → Dictionary`
- `resolve_operational_superior(character, companies, legions) → int`
- `deploy_company(company, status)`, `recall_company(company)`
- `get_vacant_companies(companies) → Array`

### ZoneFlagMatrix (`zone_flag_matrix.gd`)
24 zone subtypes with 8 boolean flags. Castle scaling by lord rank.
- `get_flags(zone_subtype) → Dictionary`
- `can_perform(zone_subtype)`, `has_tokonoma(zone_subtype)`, etc.
- `get_castle_zones_for_rank(lord_rank) → Dictionary`

### TattooSystem (`tattoo_system.gd`)
Cultural reluctance, quality resolution, disposition bonds, Togashi allotments.
- `check_consent(character, artist, ...) → Dictionary`
- `resolve_quality(tattooing_rank, tier, dice_engine) → Dictionary`
- `create_tattoo(recipient, artist, ...) → TattooData`
- `compute_visibility(tattoo, clothing_state) → bool`
- `has_unfilled_ability_slots(school, school_rank, tattoos, char_id) → bool`

### ScoringTableLoader (`scoring_table_loader.gd`)
Loads and caches 8 JSON tables from `systems/npc_engine/data/tables/`.
- `load_all() → bool`, `get_table(name) → Variant`, `get_scoring_tables() → Dictionary`

---

## JSON Scoring Tables (`/systems/npc_engine/data/tables/`)

| File | Content |
|------|---------|
| `objective_alignment.json` | 82 NeedTypes → ActionID → score |
| `personality_lean.json` | 14 virtues → ActionID → modifier |
| `personality_filter.json` | Bushido/Shourido hard blocks |
| `action_skill_map.json` | 76+ ActionIDs → primary/secondary skill |
| `competence_table.json` | Skill ranks 0-10 → modifier |
| `disposition_tiers.json` | 8 disposition tiers → modifier |
| `urgency_rules.json` | 10 urgency condition rules |
| `topic_position_alignment.json` | Topic position → scoring modifier |

---

## Test Files (`/tests/`)

One file per system, named `test_<system>.gd`. All extend `GutTest`.
Tests use seedable DiceEngine and explicit dependency injection — no Autoloads.
See CLAUDE.md for test counts per file.
