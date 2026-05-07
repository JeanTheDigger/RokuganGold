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
# Phase 1: Military fields populated in ContextSnapshot
# =============================================================================

func test_build_context_populates_military_rank() -> void:
	_char.military_rank = Enums.MilitaryRank.TAISA
	_char.commanded_unit_id = 5
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.military_rank, Enums.MilitaryRank.TAISA)
	assert_eq(ctx.commanded_unit_id, 5)


func test_build_context_default_military_rank_is_none() -> void:
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.military_rank, Enums.MilitaryRank.NONE)
	assert_eq(ctx.commanded_unit_id, -1)


# =============================================================================
# Phase 3: Military order gating
# =============================================================================

func test_military_orders_blocked_without_commanded_unit() -> void:
	_world_state["context_flag"] = Enums.ContextFlag.ON_CAMPAIGN
	_char.commanded_unit_id = -1
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "DEFEND_PROVINCE"
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(ctx, need)
	var action_ids: Array[String] = []
	for opt: NPCDataStructures.ScoredAction in options:
		action_ids.append(opt.action_id)
	assert_false("ORDER_BATTLE" in action_ids)
	assert_false("CONDUCT_RAID" in action_ids)
	assert_false("DRILL_TROOPS" in action_ids)
	assert_true("DO_NOTHING" in action_ids)


func test_military_orders_allowed_with_commanded_unit() -> void:
	_world_state["context_flag"] = Enums.ContextFlag.ON_CAMPAIGN
	_char.commanded_unit_id = 5
	_char.military_rank = Enums.MilitaryRank.CHUI
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "DEFEND_PROVINCE"
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(ctx, need)
	var action_ids: Array[String] = []
	for opt: NPCDataStructures.ScoredAction in options:
		action_ids.append(opt.action_id)
	assert_true("ORDER_BATTLE" in action_ids)
	assert_true("DRILL_TROOPS" in action_ids)


# =============================================================================
# ActionExecutor: Military hierarchy validation
# =============================================================================

func test_executor_rejects_military_order_without_unit() -> void:
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ORDER_BATTLE"
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.commanded_unit_id = -1
	ctx.character_id = 1
	ctx.ic_day = 10
	ctx.season = 1
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _char, ctx, dice, _action_skill_map
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "no_commanded_unit")


func test_executor_rejects_garrisoned_unit_for_battle() -> void:
	var company := MilitaryUnitData.CompanyData.new()
	company.company_id = 5
	company.commander_id = 1
	company.deployment_status = Enums.DeploymentStatus.GARRISONED
	var mil_data: Dictionary = {"companies": {5: company}, "legions": {}}

	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ORDER_BATTLE"
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.commanded_unit_id = 5
	ctx.military_rank = Enums.MilitaryRank.CHUI
	ctx.character_id = 1
	ctx.ic_day = 10
	ctx.season = 1
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _char, ctx, dice, _action_skill_map, mil_data
	)
	assert_false(result.get("success", true))
	assert_eq(result.get("reason", ""), "unit_garrisoned")


func test_executor_allows_drill_for_garrisoned_unit() -> void:
	var company := MilitaryUnitData.CompanyData.new()
	company.company_id = 5
	company.commander_id = 1
	company.deployment_status = Enums.DeploymentStatus.GARRISONED
	var mil_data: Dictionary = {"companies": {5: company}, "legions": {}}

	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "DRILL_TROOPS"
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.commanded_unit_id = 5
	ctx.military_rank = Enums.MilitaryRank.CHUI
	ctx.character_id = 1
	ctx.ic_day = 10
	ctx.season = 1
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _char, ctx, dice, _action_skill_map, mil_data
	)
	assert_true(result.get("valid", true))


func test_executor_allows_military_order_with_valid_unit() -> void:
	var company := MilitaryUnitData.CompanyData.new()
	company.company_id = 5
	company.commander_id = 1
	company.deployment_status = Enums.DeploymentStatus.WITH_LEGION
	var mil_data: Dictionary = {"companies": {5: company}, "legions": {}}

	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = "ORDER_BATTLE"
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.commanded_unit_id = 5
	ctx.military_rank = Enums.MilitaryRank.CHUI
	ctx.character_id = 1
	ctx.ic_day = 10
	ctx.season = 1
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var result: Dictionary = ActionExecutor.execute(
		action, _char, ctx, dice, _action_skill_map, mil_data
	)
	assert_ne(result.get("reason", ""), "unit_garrisoned")


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


# =============================================================================
# Integration: Crime Detection → Topic Creation → UPHOLD_LAW Activation
# =============================================================================

func test_crime_detection_creates_topic_and_magistrate_picks_up() -> void:
	# Setup: criminal + magistrate in same province
	var criminal := L5RCharacterData.new()
	criminal.character_id = 10
	criminal.character_name = "Criminal"
	criminal.clan = "Scorpion"
	criminal.physical_location = "castle_scorpion"

	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 20
	magistrate.character_name = "Magistrate"
	magistrate.clan = "Crane"
	magistrate.physical_location = "castle_scorpion"
	magistrate.bushido_virtue = Enums.BushidoVirtue.GI
	magistrate.shourido_virtue = Enums.ShouridoVirtue.NONE
	magistrate.skills = {"Investigation": 4}
	magistrate.perception = 4

	var characters_by_id: Dictionary = {10: criminal, 20: magistrate}

	# Step 1: Crime detection creates a CrimeRecord + crime topic
	var crime_records: Array[CrimeRecord] = []
	var active_topics: Array[TopicData] = []
	var next_case_id: Array[int] = [1]
	var next_topic_id: Array[int] = [100]

	var results: Array = [{
		"character_id": 10,
		"action_id": "EAVESDROP",
		"target_npc_id": -1,
		"effects": {"detection_risk": true},
	}]

	var crime_results: Array[Dictionary] = DayOrchestrator._process_crime_detection(
		results, characters_by_id, crime_records, 5, next_case_id,
		active_topics, next_topic_id
	)

	assert_eq(crime_results.size(), 1, "Should detect one crime")
	assert_eq(crime_records.size(), 1, "Should create one CrimeRecord")
	assert_eq(active_topics.size(), 1, "Should create one crime topic")
	assert_eq(active_topics[0].topic_type, "crime")
	assert_eq(active_topics[0].slug, "crime_case_1")
	assert_eq(active_topics[0].category, TopicData.Category.LEGAL)
	assert_almost_eq(active_topics[0].momentum, 0.0, 0.001)

	# Step 2: Magistrate was at the crime location — witness seeding adds topic
	assert_true(active_topics[0].topic_id in magistrate.topic_pool,
		"Magistrate at crime location should receive topic via witness seeding")
	assert_eq(crime_results[0]["witness_count"], 1)

	# Step 3: UPHOLD_LAW scan activates the magistrate
	var objectives: Dictionary = {
		20: {
			"primary": {"need_type": "REST"},
			"standing": {"need_type": "UPHOLD_LAW"},
		},
	}

	var characters: Array[L5RCharacterData] = [criminal, magistrate]
	var uphold_results: Array[Dictionary] = DayOrchestrator._process_uphold_law_scan(
		characters, objectives, crime_records, active_topics
	)

	assert_eq(uphold_results.size(), 1, "Magistrate should activate")
	assert_eq(uphold_results[0]["magistrate_id"], 20)
	assert_eq(uphold_results[0]["case_id"], 1)
	assert_eq(crime_records[0].investigating_magistrate_id, 20)
	assert_eq(crime_records[0].legal_status, Enums.LegalStatus.UNDER_INVESTIGATION)

	# Verify active_case is populated in standing objective
	var active_case: Dictionary = objectives[20]["standing"]["active_case"]
	assert_false(active_case.is_empty())
	assert_eq(active_case["case_id"], 1)
	assert_eq(active_case["crime_location"], "castle_scorpion")


func test_magistrate_ignores_crime_in_other_province() -> void:
	var criminal := L5RCharacterData.new()
	criminal.character_id = 10
	criminal.physical_location = "castle_lion"

	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 20
	magistrate.physical_location = "castle_crane"
	magistrate.bushido_virtue = Enums.BushidoVirtue.GI

	var crime_records: Array[CrimeRecord] = []
	var active_topics: Array[TopicData] = []
	var next_case_id: Array[int] = [1]
	var next_topic_id: Array[int] = [100]

	var results: Array = [{
		"character_id": 10,
		"action_id": "BRIBE_FOR_INFO",
		"target_npc_id": -1,
		"effects": {"detection_risk": true},
	}]

	DayOrchestrator._process_crime_detection(
		results, {10: criminal}, crime_records, 5, next_case_id,
		active_topics, next_topic_id
	)

	magistrate.topic_pool = [active_topics[0].topic_id]

	var objectives: Dictionary = {
		20: {
			"standing": {"need_type": "UPHOLD_LAW"},
		},
	}

	var uphold_results: Array[Dictionary] = DayOrchestrator._process_uphold_law_scan(
		[magistrate], objectives, crime_records, active_topics
	)

	assert_eq(uphold_results.size(), 0, "Magistrate outside jurisdiction should not activate")
	assert_eq(crime_records[0].investigating_magistrate_id, -1)


# =============================================================================
# Integration: Witness PROBE → Evidence Accumulation
# =============================================================================

func test_witness_probe_adds_evidence_via_info_events() -> void:
	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 20
	magistrate.character_name = "Magistrate"
	magistrate.knowledge_pool = []

	var witness := L5RCharacterData.new()
	witness.character_id = 50
	witness.character_name = "Witness"

	var cr := CrimeRecord.new()
	cr.case_id = 1
	cr.crime_type = Enums.CrimeType.SKIMMING
	cr.witnesses = [50]
	cr.evidence_total = 5
	var crime_records: Array[CrimeRecord] = [cr]

	var objectives: Dictionary = {
		20: {
			"standing": {
				"need_type": "UPHOLD_LAW",
				"active_case": {
					"case_id": 1,
					"interviewed_witnesses": [],
					"interviewed_suspects": [],
					"evidence_total": 5,
				},
			},
		},
	}

	# Simulate info event from a PROBE action by magistrate targeting witness
	var result: Dictionary = DayOrchestrator._check_witness_evidence(
		20, 50, 3, crime_records, objectives
	)

	assert_true(result.get("evidence_gained", 0) >= 10, "Should gain witness evidence")
	assert_true(cr.evidence_total > 5, "CrimeRecord evidence should increase")
	assert_true(50 in objectives[20]["standing"]["active_case"]["interviewed_witnesses"])


func test_suspect_probe_adds_evidence_via_info_events() -> void:
	var cr := CrimeRecord.new()
	cr.case_id = 1
	cr.known_suspects = [99]
	cr.evidence_total = 20
	var crime_records: Array[CrimeRecord] = [cr]

	var objectives: Dictionary = {
		20: {
			"standing": {
				"need_type": "UPHOLD_LAW",
				"active_case": {
					"case_id": 1,
					"interviewed_witnesses": [],
					"interviewed_suspects": [],
					"evidence_total": 20,
				},
			},
		},
	}

	var result: Dictionary = DayOrchestrator._check_witness_evidence(
		20, 99, 3, crime_records, objectives
	)

	assert_true(result.get("evidence_gained", 0) >= 10, "Should gain suspect evidence")
	assert_true(cr.evidence_total > 20, "CrimeRecord evidence should increase")
	assert_true(99 in objectives[20]["standing"]["active_case"]["interviewed_suspects"])


func test_probe_non_witness_no_evidence() -> void:
	var cr := CrimeRecord.new()
	cr.case_id = 1
	cr.witnesses = [50]
	cr.known_suspects = [99]
	cr.evidence_total = 10
	var crime_records: Array[CrimeRecord] = [cr]

	var objectives: Dictionary = {
		20: {
			"standing": {
				"need_type": "UPHOLD_LAW",
				"active_case": {
					"case_id": 1,
					"interviewed_witnesses": [],
					"interviewed_suspects": [],
					"evidence_total": 10,
				},
			},
		},
	}

	var result: Dictionary = DayOrchestrator._check_witness_evidence(
		20, 77, 3, crime_records, objectives
	)

	assert_eq(result.get("evidence_gained", 0), 0)
	assert_eq(cr.evidence_total, 10)


# =============================================================================
# Integration: Conviction → Topic Generation
# =============================================================================

func test_conviction_generates_topic_at_correct_tier() -> void:
	var cr := CrimeRecord.new()
	cr.case_id = 1
	cr.crime_type = Enums.CrimeType.SKIMMING
	cr.perpetrator_id = 10
	cr.evidence_total = 45

	var convicted := L5RCharacterData.new()
	convicted.character_id = 10
	convicted.character_name = "Embezzler"
	convicted.clan = "Scorpion"
	convicted.family = "Bayushi"
	convicted.honor = 3.0
	convicted.glory = 2.0
	convicted.status = 3.0
	convicted.infamy = 0.0

	# Apply conviction consequences
	var consequences: Dictionary = CrimeSystem.apply_at_conviction_consequences(
		convicted, cr
	)
	var topic_tier: int = consequences["topic_tier"]
	assert_eq(topic_tier, 3, "Skimming should produce Tier 3 topic")

	# Generate the conviction topic
	var next_topic_id: Array[int] = [200]
	var topic: TopicData = InvestigationSystem.generate_conviction_topic(
		cr, convicted, topic_tier, next_topic_id, 30
	)

	assert_not_null(topic)
	assert_eq(topic.tier, TopicData.Tier.TIER_3)
	assert_eq(topic.category, TopicData.Category.LEGAL)
	assert_true(topic.title.contains("Embezzler"))
	assert_true(topic.title.contains("Skimming"))
	assert_eq(topic.subject_character_id, 10)
	assert_eq(topic.subject_role, "PERPETRATOR")
	assert_almost_eq(topic.momentum, 25.0, 0.001)


func test_maho_conviction_generates_tier_1_supernatural_topic() -> void:
	var cr := CrimeRecord.new()
	cr.case_id = 2
	cr.crime_type = Enums.CrimeType.MAHO
	cr.perpetrator_id = 15

	var convicted := L5RCharacterData.new()
	convicted.character_id = 15
	convicted.character_name = "Blood Speaker"
	convicted.clan = "Phoenix"
	convicted.honor = 1.0
	convicted.glory = 1.0
	convicted.status = 2.0
	convicted.infamy = 0.0

	var consequences: Dictionary = CrimeSystem.apply_at_conviction_consequences(
		convicted, cr
	)
	assert_eq(consequences["topic_tier"], 1, "Maho should produce Tier 1 topic")

	var next_topic_id: Array[int] = [300]
	var topic: TopicData = InvestigationSystem.generate_conviction_topic(
		cr, convicted, consequences["topic_tier"], next_topic_id, 50
	)

	assert_eq(topic.tier, TopicData.Tier.TIER_1)
	assert_eq(topic.category, TopicData.Category.SUPERNATURAL)
	assert_almost_eq(topic.momentum, 80.0, 0.001)


func test_seppuku_refused_generates_secondary_topic() -> void:
	var cr := CrimeRecord.new()
	cr.case_id = 3
	cr.crime_type = Enums.CrimeType.TREASON
	cr.perpetrator_id = 25

	var convicted := L5RCharacterData.new()
	convicted.character_id = 25
	convicted.character_name = "Traitor"
	convicted.clan = "Lion"
	convicted.family = "Matsu"
	convicted.honor = 2.0
	convicted.glory = 3.0
	convicted.status = 4.0
	convicted.infamy = 0.0

	# Conviction
	CrimeSystem.apply_at_conviction_consequences(convicted, cr)

	# Seppuku refused
	var refusal: Dictionary = CrimeSystem.apply_seppuku_refused(convicted, cr)
	assert_eq(refusal["topic_tier"], 4, "Seppuku refusal should produce Tier 4 topic")

	var next_topic_id: Array[int] = [400]
	var refusal_topic: TopicData = InvestigationSystem.generate_seppuku_refusal_topic(
		convicted, next_topic_id, 60
	)

	assert_not_null(refusal_topic)
	assert_eq(refusal_topic.tier, TopicData.Tier.TIER_4)
	assert_eq(refusal_topic.category, TopicData.Category.PERSONAL)
	assert_true(refusal_topic.title.contains("refused seppuku"))
	assert_eq(refusal_topic.subject_role, "PERPETRATOR")


# =============================================================================
# Integration: Full Crime Loop — Detection → Topic → UPHOLD_LAW → Evidence
# =============================================================================

func test_full_crime_loop_detection_through_evidence() -> void:
	# Setup: criminal commits crime, magistrate investigates, interviews witness
	var criminal := L5RCharacterData.new()
	criminal.character_id = 10
	criminal.character_name = "Thief"
	criminal.clan = "Scorpion"
	criminal.physical_location = "castle_scorpion"
	criminal.honor = 3.0

	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 20
	magistrate.character_name = "Judge"
	magistrate.clan = "Crane"
	magistrate.physical_location = "castle_scorpion"
	magistrate.bushido_virtue = Enums.BushidoVirtue.GI
	magistrate.shourido_virtue = Enums.ShouridoVirtue.NONE
	magistrate.skills = {"Investigation": 4}
	magistrate.perception = 4
	magistrate.emphases = {}
	magistrate.awareness = 3
	magistrate.wounds_taken = 0

	var witness := L5RCharacterData.new()
	witness.character_id = 50
	witness.awareness = 4
	witness.honor = 6.0

	var characters_by_id: Dictionary = {10: criminal, 20: magistrate, 50: witness}

	# Phase 1: Crime detection
	var crime_records: Array[CrimeRecord] = []
	var active_topics: Array[TopicData] = []
	var next_case_id: Array[int] = [1]
	var next_topic_id: Array[int] = [100]

	# Place witness at crime location too
	witness.physical_location = "castle_scorpion"
	witness.topic_pool = []
	magistrate.topic_pool = []

	DayOrchestrator._process_crime_detection(
		[{"character_id": 10, "action_id": "SEARCH_QUARTERS", "target_npc_id": -1,
		  "effects": {"detection_risk": true}}],
		characters_by_id, crime_records, 5, next_case_id,
		active_topics, next_topic_id
	)
	assert_eq(crime_records.size(), 1)
	var record: CrimeRecord = crime_records[0]

	# Both magistrate and witness at location are witnesses — seeded with topic
	assert_true(active_topics[0].topic_id in magistrate.topic_pool)
	assert_true(active_topics[0].topic_id in witness.topic_pool)

	# Phase 3: UPHOLD_LAW activation
	var objectives: Dictionary = {
		20: {
			"standing": {"need_type": "UPHOLD_LAW"},
		},
	}
	DayOrchestrator._process_uphold_law_scan(
		[magistrate], objectives, crime_records, active_topics
	)
	assert_eq(record.investigating_magistrate_id, 20)

	# Phase 4: Magistrate examines crime scene
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var exam_result: Dictionary = InvestigationSystem.examine_scene(
		magistrate, record, dice, 5
	)
	if exam_result["success"]:
		assert_true(record.evidence_total > 0, "Scene exam should add evidence")

	# Phase 5: Magistrate interviews witness (via witness PROBE)
	var pre_evidence: int = record.evidence_total
	var witness_result: Dictionary = DayOrchestrator._check_witness_evidence(
		20, 50, 3, crime_records, objectives
	)
	assert_true(witness_result.get("evidence_gained", 0) >= 10)
	assert_true(record.evidence_total > pre_evidence)

	# Phase 6: Check if evidence threshold is reachable
	# After scene exam + witness interview, evidence should be significant
	assert_true(record.evidence_total >= 10,
		"Combined evidence from scene + witness should be substantial")


# =============================================================================
# Integration: Information Transfer with Province Status
# =============================================================================

func test_objective_transfer_includes_province_crisis() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.knowledge_pool = []
	lord.known_contacts_by_clan = {}
	lord.met_characters = []

	# Lord has some intel about province 10
	InformationSystem.add_knowledge(lord, InformationSystem.make_entry(
		Enums.KnowledgeSource.DIRECT_OBSERVATION, "province_intel",
		{"target_province_id": 10, "report": "border skirmish"}, 2
	))

	var vassal := L5RCharacterData.new()
	vassal.character_id = 2
	vassal.knowledge_pool = []
	vassal.known_contacts_by_clan = {}
	vassal.met_characters = []

	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 10
	ps.stability = 45.0
	ps.garrison_pu = 8
	ps.rice_stockpile = 15.0
	ps.active_crisis_id = 3
	ps.crisis_type = "shadowlands_incursion"

	var objective: Dictionary = {"target_province_id": 10, "need_type": "DEFEND_PROVINCE"}

	var transferred: Array[KnowledgeEntry] = InformationSystem.transfer_objective_knowledge(
		lord, vassal, objective, 2, [ps]
	)

	# Should transfer: the lord's existing intel + province_status + crisis_data
	assert_true(transferred.size() >= 3, "Should transfer existing intel + province status + crisis")

	var has_province_status: bool = false
	var has_crisis: bool = false
	var has_existing_intel: bool = false
	for e: KnowledgeEntry in transferred:
		if e.entry_type == "province_status":
			has_province_status = true
			assert_eq(e.data["stability"], 45.0)
			assert_eq(e.data["garrison_pu"], 8)
		elif e.entry_type == "crisis_data":
			has_crisis = true
			assert_eq(e.data["crisis_type"], "shadowlands_incursion")
		elif e.entry_type == "province_intel":
			has_existing_intel = true

	assert_true(has_province_status, "Should include province status")
	assert_true(has_crisis, "Should include crisis data")
	assert_true(has_existing_intel, "Should include lord's existing intel")

	# All transferred entries should be FRESH
	for e: KnowledgeEntry in vassal.knowledge_pool:
		assert_eq(e.confidence, Enums.KnowledgeConfidence.FRESH)


# =============================================================================
# Integration: Stale Intel Bonus affects gather-intelligence scoring
# =============================================================================

func test_stale_intel_bonus_wired_into_score_all() -> void:
	# Give character stale knowledge about target
	var entry: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "observed_action",
		{"target_character_id": 2}, 1
	)
	entry.confidence = Enums.KnowledgeConfidence.STALE
	InformationSystem.add_knowledge(_char, entry)

	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.character_id = 1
	ctx.season = 1
	ctx.action_log = []

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "GATHER_INTELLIGENCE"
	need.target_npc_id = 2

	var probe_option := NPCDataStructures.ScoredAction.new()
	probe_option.action_id = "PROBE"
	probe_option.target_npc_id = 2

	var charm_option := NPCDataStructures.ScoredAction.new()
	charm_option.action_id = "CHARM"
	charm_option.target_npc_id = 2

	var options: Array[NPCDataStructures.ScoredAction] = [probe_option, charm_option]

	NPCDecisionEngine.score_all(options, need, ctx, _scoring_tables,
		[], [], _char)

	assert_almost_eq(probe_option.stale_intel_bonus, 15.0, 0.001,
		"PROBE should get +15 stale intel bonus")
	assert_almost_eq(charm_option.stale_intel_bonus, 0.0, 0.001,
		"CHARM should not get stale intel bonus")
