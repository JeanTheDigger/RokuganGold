extends GutTest
## Tests for the wiring of 6 subsystems into the NPC decision loop.
## ApproachEvaluation, CommitmentRegistry, TravelCommitment (Phase 5)
## ZoneFlagMatrix (Phase 1 + Phase 3), CrimeSystem (post-execution),
## MilitaryHierarchy (execution).


var _char: L5RCharacterData
var _world_state: Dictionary
var _objectives: Dictionary
var _scoring_tables: Dictionary
var _filter_data: Dictionary
var _action_skill_map: Dictionary


func before_each() -> void:
	_char = L5RCharacterData.new()
	_char.character_id = 1
	_char.character_name = "Test NPC"
	_char.clan = "Crane"
	_char.family = "Doji"
	_char.school_type = Enums.SchoolType.COURTIER
	_char.bushido_virtue = Enums.BushidoVirtue.NONE
	_char.shourido_virtue = Enums.ShouridoVirtue.NONE
	_char.honor = 5.0
	_char.glory = 3.0
	_char.status = 4.0
	_char.skills = {"Courtier": 3, "Etiquette": 3}
	_char.emphases = {}
	_char.reflexes = 3
	_char.awareness = 3
	_char.stamina = 3
	_char.willpower = 3
	_char.agility = 3
	_char.intelligence = 3
	_char.strength = 3
	_char.perception = 3
	_char.void_ring = 2
	_char.wounds_taken = 0
	_char.knowledge_pool = []
	_char.known_contacts_by_clan = {}
	_char.met_characters = []
	ActionPointSystem.reset_daily_ap(_char)

	_world_state = {
		"context_flag": Enums.ContextFlag.AT_COURT,
		"season": 1,
		"ic_day": 10,
		"characters_present": [] as Array[int],
		"is_lord": false,
		"known_topics": [] as Array[int],
		"known_positions": {},
		"known_objectives": {},
		"known_contacts": [] as Array[int],
		"pending_events": [],
		"action_log": [] as Array[Dictionary],
	}

	_objectives = {
		"primary": {"need_type": "REST", "priority": 3},
	}

	_scoring_tables = {
		"objective_alignment": {
			"REST": {"DO_NOTHING": 10, "REST": 50, "TRAIN": 30},
			"RAISE_DISPOSITION": {"CHARM": 80, "GOSSIP": 30},
		},
		"disposition_tiers": [
			{"min": -10, "max": 10, "cooperative": 0, "hostile": 0},
		],
		"personality_lean": {},
		"action_skill_map": {},
		"urgency_rules": [],
		"topic_position_alignment": {},
	}

	_filter_data = {"bushido": {}, "shourido": {}}

	_action_skill_map = {
		"REST": {"primary": null, "secondary": null},
		"DO_NOTHING": {"primary": null, "secondary": null},
		"TRAIN": {"primary": "_trained_skill", "secondary": null},
	}


# =============================================================================
# Phase 1: Zone fields populated in ContextSnapshot
# =============================================================================

func test_build_context_populates_zone_subtype() -> void:
	_world_state["zone_subtype"] = Enums.ZoneSubtype.OHIROMA
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.zone_subtype, Enums.ZoneSubtype.OHIROMA)


func test_build_context_populates_zone_flags() -> void:
	_world_state["zone_subtype"] = Enums.ZoneSubtype.AUDIENCE_CHAMBER
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	assert_false(ctx.zone_flags.get("performance_permitted", true))
	assert_true(ctx.zone_flags.get("tokonoma", false))


func test_build_context_no_zone_subtype_leaves_empty_flags() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	assert_true(ctx.zone_flags.is_empty())


func test_build_context_populates_sublocation() -> void:
	_world_state["sublocation"] = Enums.Sublocation.COURT
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.sublocation, Enums.Sublocation.COURT)


# =============================================================================
# Phase 3: Zone flag filtering removes blocked actions
# =============================================================================

func test_zone_blocks_performance_in_audience_chamber() -> void:
	_world_state["zone_subtype"] = Enums.ZoneSubtype.AUDIENCE_CHAMBER
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REST"
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(ctx, need)
	var action_ids: Array[String] = []
	for opt: NPCDataStructures.ScoredAction in options:
		action_ids.append(opt.action_id)
	assert_false("PUBLIC_PERFORMANCE" in action_ids)


func test_zone_allows_performance_in_ohiroma() -> void:
	_world_state["zone_subtype"] = Enums.ZoneSubtype.OHIROMA
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REST"
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(ctx, need)
	var action_ids: Array[String] = []
	for opt: NPCDataStructures.ScoredAction in options:
		action_ids.append(opt.action_id)
	assert_true("PUBLIC_PERFORMANCE" in action_ids)


func test_zone_no_flags_allows_all_actions() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REST"
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(ctx, need)
	var action_ids: Array[String] = []
	for opt: NPCDataStructures.ScoredAction in options:
		action_ids.append(opt.action_id)
	assert_true("PUBLIC_PERFORMANCE" in action_ids)


# =============================================================================
# Phase 5: ScoredAction has new fields
# =============================================================================

func test_scored_action_includes_new_fields_in_total() -> void:
	var sa := NPCDataStructures.ScoredAction.new()
	sa.objective_alignment = 50.0
	sa.approach_modifier = 15.0
	sa.commitment_at_risk = -10.0
	sa.travel_redirect_penalty = -5.0
	assert_eq(sa.get_total_score(), 50.0)


# =============================================================================
# Phase 5: ApproachEvaluation modifier wired into score_all
# =============================================================================

func test_score_all_applies_approach_modifier() -> void:
	var penalties: Array[Dictionary] = [{
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"tag": ApproachEvaluation.AssessmentTag.APPROACH_CAPPED,
		"season_recorded": 1,
	}]
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.season = 1
	ctx.action_log = []

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	need.target_npc_id = 2

	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	option.target_npc_id = 2
	var options: Array[NPCDataStructures.ScoredAction] = [option]

	NPCDecisionEngine.score_all(options, need, ctx, _scoring_tables, penalties)
	assert_eq(option.approach_modifier, -15.0)


func test_score_all_approach_modifier_zero_without_penalties() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.season = 1
	ctx.action_log = []

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REST"

	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "REST"
	var options: Array[NPCDataStructures.ScoredAction] = [option]

	NPCDecisionEngine.score_all(options, need, ctx, _scoring_tables)
	assert_eq(option.approach_modifier, 0.0)


# =============================================================================
# Phase 5: CommitmentRegistry at-risk penalty wired into score_all
# =============================================================================

func test_score_all_applies_commitment_at_risk() -> void:
	var commitment: CommitmentData = CommitmentRegistry.create_commitment(
		1, Enums.CommitmentType.VISIT_PROMISE, 99, 1, 20, 1, 5
	)
	var commitments: Array[CommitmentData] = [commitment]

	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.season = 1
	ctx.action_log = []

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REST"

	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "REST"
	var options: Array[NPCDataStructures.ScoredAction] = [option]

	NPCDecisionEngine.score_all(options, need, ctx, _scoring_tables,
		[], commitments, _char)
	assert_eq(option.commitment_at_risk, -5.0)


func test_score_all_no_commitment_penalty_without_commitments() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.season = 1
	ctx.action_log = []

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REST"

	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "REST"
	var options: Array[NPCDataStructures.ScoredAction] = [option]

	NPCDecisionEngine.score_all(options, need, ctx, _scoring_tables)
	assert_eq(option.commitment_at_risk, 0.0)


# =============================================================================
# Phase 5: TravelCommitment redirect penalty wired into score_all
# =============================================================================

func test_score_all_applies_travel_redirect_penalty() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.season = 1
	ctx.action_log = []

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REST"

	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "REST"
	var options: Array[NPCDataStructures.ScoredAction] = [option]

	NPCDecisionEngine.score_all(options, need, ctx, _scoring_tables,
		[], [], null, 2)
	assert_eq(option.travel_redirect_penalty, -15.0)


func test_score_all_no_redirect_penalty_at_zero() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.season = 1
	ctx.action_log = []

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REST"

	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "REST"
	var options: Array[NPCDataStructures.ScoredAction] = [option]

	NPCDecisionEngine.score_all(options, need, ctx, _scoring_tables)
	assert_eq(option.travel_redirect_penalty, 0.0)


# =============================================================================
# NPCDecisionEngine.run() passes new params through
# =============================================================================

func test_run_accepts_new_params_without_error() -> void:
	_world_state["context_flag"] = Enums.ContextFlag.AT_OWN_HOLDINGS
	var result: Dictionary = NPCDecisionEngine.run(
		_char, _world_state, _objectives, _scoring_tables, _filter_data,
		[], [], 0
	)
	assert_true(result.has("action_id"))


# =============================================================================
# DayOrchestrator: Crime detection from covert actions
# =============================================================================

func test_advance_day_returns_crime_results() -> void:
	var time: TimeSystem = TimeSystem.new(1120, 0)
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)

	var province := ProvinceData.new()
	province.province_id = 10
	province.stability = 70.0
	province.garrison_pu = 3
	province.farming_pu = 4
	province.mining_pu = 1
	province.town_pu = 2
	province.military_pu = 1
	province.population_pu = 8
	province.rice_stockpile = 10.0
	province.koku_stockpile = 5.0
	province.iron_stockpile = 2.0
	province.terrain_type = Enums.TerrainType.PLAINS

	var characters: Array[L5RCharacterData] = [_char]
	var characters_by_id: Dictionary = {1: _char}
	var provinces: Dictionary = {10: province}
	var action_log: Array[Dictionary] = []
	var season_meta: Dictionary = {
		"_peace_seasons": {10: 0},
		"_deficit_seasons": {10: 0},
	}
	var ws: Dictionary = _make_day_world_state()
	var crime_records: Array[CrimeRecord] = []

	var result: Dictionary = DayOrchestrator.advance_day(
		time, characters, characters_by_id, {1: ws},
		{1: _objectives}, _scoring_tables, _filter_data, dice,
		_action_skill_map, provinces, action_log, season_meta,
		[], [], [], [], crime_records
	)
	assert_true(result.has("crime_results"))
	assert_true(result["crime_results"] is Array)


func test_advance_day_returns_commitment_results() -> void:
	var time: TimeSystem = TimeSystem.new(1120, 0)
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)

	var province := ProvinceData.new()
	province.province_id = 10
	province.stability = 70.0
	province.garrison_pu = 3
	province.farming_pu = 4
	province.mining_pu = 1
	province.town_pu = 2
	province.military_pu = 1
	province.population_pu = 8
	province.rice_stockpile = 10.0
	province.koku_stockpile = 5.0
	province.iron_stockpile = 2.0
	province.terrain_type = Enums.TerrainType.PLAINS

	var characters: Array[L5RCharacterData] = [_char]
	var characters_by_id: Dictionary = {1: _char}
	var provinces: Dictionary = {10: province}
	var action_log: Array[Dictionary] = []
	var season_meta: Dictionary = {
		"_peace_seasons": {10: 0},
		"_deficit_seasons": {10: 0},
	}
	var ws: Dictionary = _make_day_world_state()
	var commitments: Array[CommitmentData] = []

	var result: Dictionary = DayOrchestrator.advance_day(
		time, characters, characters_by_id, {1: ws},
		{1: _objectives}, _scoring_tables, _filter_data, dice,
		_action_skill_map, provinces, action_log, season_meta,
		[], [], [], commitments
	)
	assert_true(result.has("commitment_results"))


func test_advance_day_processes_due_commitment() -> void:
	var time: TimeSystem = TimeSystem.new(1120, 0)
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)

	var province := ProvinceData.new()
	province.province_id = 10
	province.stability = 70.0
	province.garrison_pu = 3
	province.farming_pu = 4
	province.mining_pu = 1
	province.town_pu = 2
	province.military_pu = 1
	province.population_pu = 8
	province.rice_stockpile = 10.0
	province.koku_stockpile = 5.0
	province.iron_stockpile = 2.0
	province.terrain_type = Enums.TerrainType.PLAINS

	var characters: Array[L5RCharacterData] = [_char]
	var characters_by_id: Dictionary = {1: _char}
	var provinces: Dictionary = {10: province}
	var action_log: Array[Dictionary] = []
	var season_meta: Dictionary = {
		"_peace_seasons": {10: 0},
		"_deficit_seasons": {10: 0},
	}
	var ws: Dictionary = _make_day_world_state()

	var commitment: CommitmentData = CommitmentRegistry.create_commitment(
		1, Enums.CommitmentType.VISIT_PROMISE, 99, 1, 0, 2, 0
	)
	var commitments: Array[CommitmentData] = [commitment]

	var result: Dictionary = DayOrchestrator.advance_day(
		time, characters, characters_by_id, {1: ws},
		{1: _objectives}, _scoring_tables, _filter_data, dice,
		_action_skill_map, provinces, action_log, season_meta,
		[], [], [], commitments
	)
	assert_true(result["commitment_results"].size() > 0)
	assert_ne(commitment.status, Enums.CommitmentStatus.PENDING)


# =============================================================================
# DayOrchestrator: Approach penalty decay on season boundary
# =============================================================================

func test_season_transition_decays_approach_penalties() -> void:
	var time: TimeSystem = TimeSystem.new(1120, 89)
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)

	var province := ProvinceData.new()
	province.province_id = 10
	province.stability = 70.0
	province.garrison_pu = 3
	province.farming_pu = 4
	province.mining_pu = 1
	province.town_pu = 2
	province.military_pu = 1
	province.population_pu = 8
	province.rice_stockpile = 10.0
	province.koku_stockpile = 5.0
	province.iron_stockpile = 2.0
	province.terrain_type = Enums.TerrainType.PLAINS

	var characters: Array[L5RCharacterData] = [_char]
	var characters_by_id: Dictionary = {1: _char}
	var provinces: Dictionary = {10: province}
	var action_log: Array[Dictionary] = []
	var season_meta: Dictionary = {
		"_peace_seasons": {10: 0},
		"_deficit_seasons": {10: 0},
	}
	var ws: Dictionary = _make_day_world_state()

	var penalties: Array[Dictionary] = [{
		"character_id": 1,
		"target_npc_id": 2,
		"action_id": "CHARM",
		"tag": ApproachEvaluation.AssessmentTag.APPROACH_CAPPED,
		"season_recorded": -2,
	}]

	var result: Dictionary = DayOrchestrator.advance_day(
		time, characters, characters_by_id, {1: ws},
		{1: _objectives}, _scoring_tables, _filter_data, dice,
		_action_skill_map, provinces, action_log, season_meta,
		[], [], penalties
	)
	assert_true(result["season_changed"])
	assert_eq(penalties.size(), 0)
	assert_true(result["seasonal_result"].has("approach_penalties_decayed"))


# =============================================================================
# Wave Resolver: New params thread through
# =============================================================================

func test_wave_resolver_accepts_new_params() -> void:
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)
	var characters: Array[L5RCharacterData] = [_char]
	var characters_by_id: Dictionary = {1: _char}
	var provinces: Dictionary = {}
	var action_log: Array[Dictionary] = []
	_world_state["context_flag"] = Enums.ContextFlag.AT_OWN_HOLDINGS
	var ws: Dictionary = {1: _world_state}

	var result: Dictionary = NPCWaveResolver.resolve_day_applied(
		characters, ws, {1: _objectives}, _scoring_tables, _filter_data,
		dice, _action_skill_map, characters_by_id, provinces, action_log,
		[], []
	)
	assert_true(result.has("results"))


# =============================================================================
# Helpers
# =============================================================================

func _make_day_world_state() -> Dictionary:
	return {
		"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS,
		"season": 1,
		"ic_day": 1,
		"characters_present": [] as Array[int],
		"is_lord": false,
		"known_topics": [] as Array[int],
		"known_positions": {},
		"known_objectives": {},
		"known_contacts": [] as Array[int],
		"pending_events": [],
		"action_log": [] as Array[Dictionary],
	}
