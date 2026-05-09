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

# =============================================================================
# End-to-End Crime Loop: Detection → Witness Seed → UPHOLD_LAW → Examine →
#   Interview → Conviction → Conviction Topic
# =============================================================================

func test_end_to_end_crime_loop_through_conviction() -> void:
	var criminal := L5RCharacterData.new()
	criminal.character_id = 10
	criminal.character_name = "Bayushi Spy"
	criminal.clan = "Scorpion"
	criminal.family = "Bayushi"
	criminal.physical_location = "castle_scorpion"
	criminal.honor = 3.0
	criminal.glory = 2.0
	criminal.status = 3.0
	criminal.infamy = 0.0

	var magistrate := L5RCharacterData.new()
	magistrate.character_id = 20
	magistrate.character_name = "Crane Magistrate"
	magistrate.clan = "Crane"
	magistrate.physical_location = "castle_scorpion"
	magistrate.bushido_virtue = Enums.BushidoVirtue.GI
	magistrate.shourido_virtue = Enums.ShouridoVirtue.NONE
	magistrate.skills = {"Investigation": 5}
	magistrate.perception = 4
	magistrate.awareness = 3
	magistrate.intelligence = 3
	magistrate.reflexes = 3
	magistrate.willpower = 3
	magistrate.emphases = {}
	magistrate.wounds_taken = 0
	magistrate.knowledge_pool = []
	magistrate.topic_pool = []

	var witness := L5RCharacterData.new()
	witness.character_id = 50
	witness.character_name = "Witness"
	witness.physical_location = "castle_scorpion"
	witness.awareness = 4
	witness.honor = 6.0
	witness.topic_pool = []

	var characters_by_id: Dictionary = {10: criminal, 20: magistrate, 50: witness}

	# Phase 1: Crime detection
	var crime_records: Array[CrimeRecord] = []
	var active_topics: Array[TopicData] = []
	var next_case_id: Array[int] = [1]
	var next_topic_id: Array[int] = [500]

	var covert_results: Array = [{
		"character_id": 10,
		"action_id": "BRIBE_FOR_INFO",
		"target_npc_id": -1,
		"effects": {"detection_risk": true},
	}]

	var crime_results: Array[Dictionary] = DayOrchestrator._process_crime_detection(
		covert_results, characters_by_id, crime_records, 5, next_case_id,
		active_topics, next_topic_id
	)

	assert_eq(crime_results.size(), 1, "Should detect one crime")
	assert_eq(crime_records.size(), 1)
	var record: CrimeRecord = crime_records[0]
	assert_eq(record.crime_type, Enums.CrimeType.SKIMMING)
	assert_eq(record.perpetrator_id, 10)

	# Phase 2: Witness-only topic seeding
	assert_eq(active_topics.size(), 1)
	var crime_topic: TopicData = active_topics[0]
	assert_almost_eq(crime_topic.momentum, 0.0, 0.001,
		"Crime topic momentum should be 0")
	assert_true(crime_topic.topic_id in magistrate.topic_pool,
		"Magistrate at location gets topic via witness seeding")
	assert_true(crime_topic.topic_id in witness.topic_pool,
		"Witness at location gets topic via witness seeding")
	assert_false(crime_topic.topic_id in criminal.topic_pool,
		"Criminal should NOT receive own crime topic")

	# Phase 3: UPHOLD_LAW activation
	var objectives: Dictionary = {
		20: {
			"standing": {"need_type": "UPHOLD_LAW"},
		},
	}
	var characters: Array[L5RCharacterData] = [criminal, magistrate, witness]
	var uphold_results: Array[Dictionary] = DayOrchestrator._process_uphold_law_scan(
		characters, objectives, crime_records, active_topics
	)

	assert_eq(uphold_results.size(), 1, "Magistrate should self-initiate")
	assert_eq(uphold_results[0]["magistrate_id"], 20)
	assert_eq(record.investigating_magistrate_id, 20)
	assert_eq(record.legal_status, Enums.LegalStatus.UNDER_INVESTIGATION)
	var active_case: Dictionary = objectives[20]["standing"]["active_case"]
	assert_false(active_case.is_empty())

	# Phase 4: Scene examination
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var exam: Dictionary = InvestigationSystem.examine_scene(
		magistrate, record, dice, 5
	)
	assert_true(exam["success"], "Investigation 5 should pass TN 15")
	var evidence_after_exam: int = record.evidence_total
	assert_true(evidence_after_exam > 0, "Scene exam should add evidence")

	# Phase 5: Witness interview via PROBE
	var witness_result: Dictionary = DayOrchestrator._check_witness_evidence(
		20, 50, 3, crime_records, objectives
	)
	assert_true(witness_result.get("evidence_gained", 0) >= 10)
	assert_true(record.evidence_total > evidence_after_exam)
	assert_true(50 in active_case["interviewed_witnesses"])

	# Phase 6: Conviction
	var conviction: Dictionary = CrimeSystem.apply_at_conviction_consequences(
		criminal, record
	)
	assert_eq(record.legal_status, Enums.LegalStatus.CONVICTED)
	assert_eq(conviction["topic_tier"], 3, "Skimming -> Tier 3 topic")
	assert_true(criminal.glory < 2.0, "Glory should decrease on conviction")
	assert_true(criminal.infamy > 0.0, "Infamy should increase on conviction")

	# Phase 7: Conviction topic generation
	var conviction_topic: TopicData = InvestigationSystem.generate_conviction_topic(
		record, criminal, conviction["topic_tier"], next_topic_id, 6
	)
	assert_not_null(conviction_topic)
	assert_eq(conviction_topic.tier, TopicData.Tier.TIER_3)
	assert_eq(conviction_topic.category, TopicData.Category.LEGAL)
	assert_true(conviction_topic.title.contains("Bayushi Spy"))
	assert_true(conviction_topic.title.contains("Skimming"))
	assert_eq(conviction_topic.subject_character_id, 10)
	assert_eq(conviction_topic.subject_role, "PERPETRATOR")
	assert_almost_eq(conviction_topic.momentum, 25.0, 0.001,
		"Tier 3 conviction topic should start at momentum 25")


# =============================================================================
# Court Availability Wiring into Decomposition Trees
# =============================================================================

func test_decomposer_uses_court_availability_when_court_active() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.ON_CAMPAIGN
	ctx.character_id = 1
	ctx.lord_id = 99
	ctx.active_court_at_location = {"settlement_id": 10, "prestige": 3}
	ctx.action_log = []
	ctx.season = 1

	var objective: Dictionary = {"need_type": "MAINTAIN_BALANCE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx
	)
	assert_not_null(need)
	assert_eq(need.need_type, "ATTEND_COURT")
	assert_eq(need.target_settlement_id, 10)


func test_decomposer_uses_upcoming_court_when_no_active() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.ON_CAMPAIGN
	ctx.character_id = 1
	ctx.lord_id = 99
	ctx.active_court_at_location = {}
	ctx.upcoming_courts = [
		{"settlement_id": 20, "prestige": 5},
	]
	ctx.action_log = []
	ctx.season = 1

	var objective: Dictionary = {"need_type": "ADVANCE_FAMILY"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx
	)
	assert_not_null(need)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.target_settlement_id, 20)


func test_decomposer_sends_letter_to_lord_when_no_court() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.ON_CAMPAIGN
	ctx.character_id = 1
	ctx.lord_id = 99
	ctx.active_court_at_location = {}
	ctx.upcoming_courts = []
	ctx.held_leverage = []
	ctx.action_log = []
	ctx.season = 1

	var objective: Dictionary = {"need_type": "STRENGTHEN_IMPERIAL"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx
	)
	assert_not_null(need)
	assert_eq(need.need_type, "SEND_LETTER")
	assert_eq(need.target_npc_id, 99)


func test_decomposer_falls_through_to_rest_when_no_options() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.ON_CAMPAIGN
	ctx.character_id = 1
	ctx.lord_id = -1
	ctx.active_court_at_location = {}
	ctx.upcoming_courts = []
	ctx.held_leverage = []
	ctx.action_log = []
	ctx.season = 1

	var objective: Dictionary = {"need_type": "ACCUMULATE_LEVERAGE"}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx
	)
	assert_not_null(need)
	assert_eq(need.need_type, "REST")


func test_decomposer_seek_vengeance_uses_court_alternative() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.context_flag = Enums.ContextFlag.AT_OWN_HOLDINGS
	ctx.character_id = 1
	ctx.lord_id = -1
	ctx.characters_present = []
	ctx.active_court_at_location = {}
	ctx.upcoming_courts = []
	ctx.held_leverage = []
	ctx.known_npc_locations = {10: 42}
	ctx.action_log = []
	ctx.season = 1

	var objective: Dictionary = {
		"need_type": "SEEK_VENGEANCE",
		"target_npc_id": 10,
	}
	var need: NPCDataStructures.ImmediateNeed = ObjectiveDecomposer.decompose(
		objective, ctx
	)
	assert_not_null(need)
	assert_eq(need.need_type, "TRAVEL_TO")
	assert_eq(need.target_settlement_id, 42)


func test_build_context_populates_court_fields() -> void:
	_char.lord_id = 99
	_world_state["active_court_at_location"] = {"settlement_id": 10}
	_world_state["upcoming_courts"] = [{"settlement_id": 20, "prestige": 5}]
	_world_state["held_leverage"] = [{"secret_id": 1}]
	_world_state["known_npc_locations"] = {10: 42}

	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(
		_char, _world_state
	)
	assert_eq(ctx.lord_id, 99)
	assert_eq(ctx.active_court_at_location.get("settlement_id", -1), 10)
	assert_eq(ctx.upcoming_courts.size(), 1)
	assert_eq(ctx.held_leverage.size(), 1)
	assert_eq(ctx.known_npc_locations.get(10, -1), 42)


# =============================================================================
# Orphaned Objectives Wiring into DayOrchestrator
# =============================================================================

func test_advance_day_processes_lord_death() -> void:
	var time: TimeSystem = TimeSystem.new(1120, 0)
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)

	var lord := L5RCharacterData.new()
	lord.character_id = 10
	lord.lord_id = -1

	var vassal := L5RCharacterData.new()
	vassal.character_id = 1
	vassal.character_name = "Vassal"
	vassal.lord_id = 10
	vassal.operational_superior_id = 50
	vassal.clan = "Lion"
	vassal.family = "Akodo"
	vassal.school_type = Enums.SchoolType.BUSHI
	vassal.bushido_virtue = Enums.BushidoVirtue.NONE
	vassal.shourido_virtue = Enums.ShouridoVirtue.NONE
	vassal.honor = 5.0
	vassal.glory = 3.0
	vassal.status = 4.0
	vassal.skills = {}
	vassal.emphases = {}
	vassal.reflexes = 3
	vassal.awareness = 3
	vassal.stamina = 3
	vassal.willpower = 3
	vassal.agility = 3
	vassal.intelligence = 3
	vassal.strength = 3
	vassal.perception = 3
	vassal.void_ring = 2
	vassal.wounds_taken = 0
	vassal.knowledge_pool = []
	vassal.known_contacts_by_clan = {}
	vassal.met_characters = []
	ActionPointSystem.reset_daily_ap(vassal)

	var province := ProvinceData.new()
	province.province_id = 10
	province.stability = 70.0
	province.terrain_type = Enums.TerrainType.PLAINS

	var characters: Array[L5RCharacterData] = [vassal]
	var characters_by_id: Dictionary = {1: vassal}
	var provinces: Dictionary = {10: province}
	var action_log: Array[Dictionary] = []
	var season_meta: Dictionary = {
		"_peace_seasons": {10: 0},
		"_deficit_seasons": {10: 0},
	}
	var ws: Dictionary = _make_day_world_state()

	var objectives_map: Dictionary = {
		1: {
			"primary": {
				"need_type": "CONQUER_PROVINCE",
				"objective_type": "CONQUER_PROVINCE",
				"assigning_lord_id": 10,
			},
		},
	}

	var death_events: Array[Dictionary] = [
		{"character_id": 10, "is_lord": true},
	]
	var successor_map: Dictionary = {10: 20}

	var result: Dictionary = DayOrchestrator.advance_day(
		time, characters, characters_by_id, {1: ws},
		objectives_map, _scoring_tables, _filter_data, dice,
		_action_skill_map, provinces, action_log, season_meta,
		[], [], [], [], [], [1], {}, {}, [1000],
		death_events, successor_map,
	)

	assert_true(result.has("orphan_results"))
	assert_eq(result["orphan_results"].size(), 1)
	assert_eq(result["orphan_results"][0]["vassal_id"], 1)
	assert_eq(result["orphan_results"][0]["status"], "ORPHANED")
	assert_eq(result["orphan_results"][0]["report_target_id"], 20)
	assert_eq(objectives_map[1]["primary"]["status"], "ORPHANED")


func test_advance_day_no_death_events_no_orphans() -> void:
	var time: TimeSystem = TimeSystem.new(1120, 0)
	var dice: DiceEngine = DiceEngine.new()
	dice.set_seed(42)

	var province := ProvinceData.new()
	province.province_id = 10
	province.stability = 70.0
	province.terrain_type = Enums.TerrainType.PLAINS

	var characters: Array[L5RCharacterData] = [_char]
	var characters_by_id: Dictionary = {1: _char}
	var ws: Dictionary = _make_day_world_state()

	var result: Dictionary = DayOrchestrator.advance_day(
		time, characters, characters_by_id, {1: ws},
		{1: _objectives}, _scoring_tables, _filter_data, dice,
		_action_skill_map, {10: province}, [], {
			"_peace_seasons": {10: 0},
			"_deficit_seasons": {10: 0},
		}
	)

	assert_true(result.has("orphan_results"))
	assert_eq(result["orphan_results"].size(), 0)


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


# -- s57.19 — New Wall/Taint ActionIDs ----------------------------------------

func test_s57_19_purify_in_manage_taint_alignment() -> void:
	var alignment_table: Dictionary = _scoring_tables.get("objective_alignment", {})
	var manage_taint: Dictionary = alignment_table.get("MANAGE_TAINT", {})
	assert_true(manage_taint.has("PURIFY_TAINTED_GROUND"),
		"PURIFY_TAINTED_GROUND should be in MANAGE_TAINT alignment")
	assert_eq(manage_taint["PURIFY_TAINTED_GROUND"], 95)


func test_s57_19_wall_actions_in_maintain_fortification() -> void:
	var alignment_table: Dictionary = _scoring_tables.get("objective_alignment", {})
	var maintain: Dictionary = alignment_table.get("MAINTAIN_FORTIFICATION", {})
	assert_true(maintain.has("FORTIFY_WALL_SECTION"))
	assert_true(maintain.has("SEAL_WALL_BREACH"))
	assert_eq(maintain["SEAL_WALL_BREACH"], 100)
	assert_eq(maintain["FORTIFY_WALL_SECTION"], 95)


func test_s57_19_wall_actions_in_defend_province() -> void:
	var alignment_table: Dictionary = _scoring_tables.get("objective_alignment", {})
	var defend: Dictionary = alignment_table.get("DEFEND_PROVINCE", {})
	assert_true(defend.has("FORTIFY_WALL_SECTION"))
	assert_true(defend.has("SEAL_WALL_BREACH"))
	assert_true(defend.has("PURIFY_TAINTED_GROUND"))


func test_s57_19_actions_in_skill_map() -> void:
	var skill_map: Dictionary = _scoring_tables.get("action_skill_map", {})
	assert_true(skill_map.has("PURIFY_TAINTED_GROUND"))
	assert_true(skill_map.has("FORTIFY_WALL_SECTION"))
	assert_true(skill_map.has("SEAL_WALL_BREACH"))
	assert_eq(skill_map["PURIFY_TAINTED_GROUND"]["primary"], "Lore: Shadowlands")
	assert_eq(skill_map["FORTIFY_WALL_SECTION"]["primary"], "Engineering")


func test_s57_19_seal_wall_breach_costs_2_ap() -> void:
	var cost: int = NPCDecisionEngine._get_ap_cost("SEAL_WALL_BREACH")
	assert_eq(cost, 2, "SEAL_WALL_BREACH should cost 2 AP")
	assert_eq(NPCDecisionEngine._get_ap_cost("PURIFY_TAINTED_GROUND"), 1)
	assert_eq(NPCDecisionEngine._get_ap_cost("FORTIFY_WALL_SECTION"), 1)


func test_s57_19_actions_in_context_list() -> void:
	var own_holdings: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS)
	assert_true("PURIFY_TAINTED_GROUND" in own_holdings)
	# FORTIFY_WALL_SECTION and SEAL_WALL_BREACH moved to AT_WALL_TOWER (s57.19 context)
	var wall_tower: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_WALL_TOWER)
	assert_true("FORTIFY_WALL_SECTION" in wall_tower)
	assert_true("SEAL_WALL_BREACH" in wall_tower)


func test_s57_19_executor_handles_new_actions() -> void:
	for action_id: String in ["PURIFY_TAINTED_GROUND", "FORTIFY_WALL_SECTION", "SEAL_WALL_BREACH"]:
		assert_true(action_id in ActionExecutor.ADMINISTRATIVE_ACTIONS,
			"%s should be in ADMINISTRATIVE_ACTIONS" % action_id)


# -- s57.17 — Direct Subordinate in DayOrchestrator ---------------------------

func test_s57_17_get_vassals_includes_operational_subordinates() -> void:
	var lord := L5RCharacterData.new()
	lord.character_id = 1
	lord.lord_id = -1
	var vassal := L5RCharacterData.new()
	vassal.character_id = 10
	vassal.lord_id = 1
	var op_sub := L5RCharacterData.new()
	op_sub.character_id = 11
	op_sub.lord_id = 5
	op_sub.operational_superior_id = 1
	var chars: Array[L5RCharacterData] = [lord, vassal, op_sub]
	var result := DayOrchestrator._get_vassals(lord, chars)
	assert_eq(result.size(), 2, "Should include both feudal vassal and operational subordinate")


# -- s11.11 — Insurgency System Wiring ----------------------------------------

func test_s11_11_insurgency_wired_into_orchestrator() -> void:
	var time := TimeSystem.new()
	# Advance to just before a season boundary
	for i: int in range(89):
		time.advance_tick()
	var chars: Array[L5RCharacterData] = [_char]
	var chars_by_id: Dictionary = {1: _char}
	var province := ProvinceData.new()
	province.province_id = 1
	province.stability = 40.0
	var provinces: Dictionary = {1: province}
	var insurgencies: Array[InsurgencyData] = []
	var next_ins_id: Array[int] = [1]
	var dice := DiceEngine.new(42)

	var result: Dictionary = DayOrchestrator.advance_day(
		time, chars, chars_by_id, {}, {}, _scoring_tables, _filter_data,
		dice, _action_skill_map, provinces, [] as Array[Dictionary],
		{}, [], [], [], [], [], {}, {}, [], {}, [],
		insurgencies, next_ins_id,
	)
	assert_true(result.has("insurgency_results"), "Should include insurgency_results")


func test_s11_11_province_taint_level_field() -> void:
	var p := ProvinceData.new()
	assert_eq(p.province_taint_level, 0.0, "PTL should default to 0.0")


# =============================================================================
# Wall System Wiring (s2.4.2 / s2.4.3 / s2.4.10 / s2.4.11 / s2.4.15 / s2.4.16)
# =============================================================================

# -- build_context reads wall_statuses from world_state (Phase 1) --------------

func test_build_context_reads_wall_statuses_from_world_state() -> void:
	var ws := NPCDataStructures.WallStatus.new()
	ws.province_id = 10
	ws.si = 7
	ws.ss = 3
	_world_state["context_flag"] = Enums.ContextFlag.AT_WALL_TOWER
	_world_state["wall_statuses"] = [ws]

	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)

	assert_eq(ctx.wall_statuses.size(), 1)
	assert_eq((ctx.wall_statuses[0] as NPCDataStructures.WallStatus).si, 7)
	assert_eq((ctx.wall_statuses[0] as NPCDataStructures.WallStatus).ss, 3)


func test_build_context_empty_wall_statuses_without_entry() -> void:
	_world_state["context_flag"] = Enums.ContextFlag.AT_OWN_HOLDINGS
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.wall_statuses.size(), 0)


# -- advance_day auto-sets AT_WALL_TOWER via _set_wall_tower_context_flags -----

func test_advance_day_sets_at_wall_tower_for_character_at_tower() -> void:
	var tower := SettlementData.new()
	tower.settlement_id = 50
	tower.province_id = 5
	tower.settlement_type = Enums.SettlementType.WALL_TOWER
	tower.wall_si = 8
	tower.garrison_pu = 2
	tower.jade_stockpile = 10.0

	var province := ProvinceData.new()
	province.province_id = 5
	province.shadowlands_strength = 2
	province.stability = 70.0
	province.terrain_type = Enums.TerrainType.PLAINS

	var character := L5RCharacterData.new()
	character.character_id = 99
	character.character_name = "Kaiu Test"
	character.physical_location = "50"
	character.clan = "Crab"
	character.family = "Kaiu"
	character.school_type = Enums.SchoolType.BUSHI
	character.bushido_virtue = Enums.BushidoVirtue.NONE
	character.shourido_virtue = Enums.ShouridoVirtue.NONE
	character.honor = 4.0
	character.glory = 3.0
	character.status = 2.0
	character.skills = {}
	character.emphases = {}
	character.reflexes = 3
	character.awareness = 3
	character.stamina = 3
	character.willpower = 3
	character.agility = 3
	character.intelligence = 3
	character.strength = 3
	character.perception = 3
	character.void_ring = 2
	character.wounds_taken = 0
	character.knowledge_pool = []
	character.known_contacts_by_clan = {}
	character.met_characters = []
	ActionPointSystem.reset_daily_ap(character)

	var char_ws: Dictionary = {
		"context_flag": Enums.ContextFlag.AT_OWN_HOLDINGS,
		"zone_subtype": Enums.ZoneSubtype.WILDERNESS,
		"wall_statuses": [],
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

	var time := TimeSystem.new(1120, 0)
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var characters: Array[L5RCharacterData] = [character]
	var characters_by_id: Dictionary = {99: character}
	var provinces: Dictionary = {5: province}
	var world_states: Dictionary = {99: char_ws}
	var settlements: Array[SettlementData] = [tower]
	var season_meta: Dictionary = {}

	DayOrchestrator.advance_day(
		time, characters, characters_by_id, world_states,
		{99: {"primary": {"need_type": "REST", "priority": 3}}},
		_scoring_tables, _filter_data, dice, _action_skill_map, provinces,
		[] as Array[Dictionary], season_meta,
		[], [], [], [], [], [1], {}, {}, [1000], [], {},
		[], [], [1],
		settlements,
	)

	assert_eq(char_ws["context_flag"], Enums.ContextFlag.AT_WALL_TOWER,
		"advance_day should auto-set AT_WALL_TOWER for character at wall tower")
	assert_eq(char_ws["wall_statuses"].size(), 1)


# -- _process_wall_engineering_effects: SI gain applied to settlement ----------

func _make_wall_tower_s(province_id: int, si: int, koku: float = 10.0) -> SettlementData:
	var s := SettlementData.new()
	s.settlement_id = province_id * 10
	s.province_id = province_id
	s.settlement_type = Enums.SettlementType.WALL_TOWER
	s.wall_si = si
	s.koku_stockpile = koku
	s.garrison_pu = 2
	return s


func test_wall_engineering_fortify_increases_si_on_settlement() -> void:
	var tower := _make_wall_tower_s(10, 5)
	var applied_list: Array = [{
		"action_id": "FORTIFY_WALL_SECTION",
		"effects": {
			"requires_fortify_wall": true,
			"si_gain": 2,
			"kaiu_decay_reduction": 0.25,
			"kaiu_reinforce_duration": 3,
			"target_province_id": 10,
		},
	}]

	var results := DayOrchestrator._process_wall_engineering_effects(
		applied_list, [tower] as Array[SettlementData]
	)

	assert_eq(tower.wall_si, 7, "SI should increase from 5 to 7 with si_gain=2")
	assert_eq(results.size(), 1)
	assert_eq(results[0]["action"], "fortify_wall")


func test_wall_engineering_fortify_clamps_si_at_10() -> void:
	var tower := _make_wall_tower_s(10, 9)
	var applied_list: Array = [{
		"action_id": "FORTIFY_WALL_SECTION",
		"effects": {
			"requires_fortify_wall": true,
			"si_gain": 5,
			"kaiu_decay_reduction": 0.25,
			"kaiu_reinforce_duration": 2,
			"target_province_id": 10,
		},
	}]

	DayOrchestrator._process_wall_engineering_effects(
		applied_list, [tower] as Array[SettlementData]
	)

	assert_eq(tower.wall_si, 10, "SI clamped at 10")


func test_wall_engineering_fortify_applies_kaiu_modifier() -> void:
	var tower := _make_wall_tower_s(10, 6)
	tower.kaiu_decay_reduction = 0.0
	tower.kaiu_reinforce_seasons_remaining = 0
	var applied_list: Array = [{
		"action_id": "FORTIFY_WALL_SECTION",
		"effects": {
			"requires_fortify_wall": true,
			"si_gain": 1,
			"kaiu_decay_reduction": 0.50,
			"kaiu_reinforce_duration": 3,
			"target_province_id": 10,
		},
	}]

	DayOrchestrator._process_wall_engineering_effects(
		applied_list, [tower] as Array[SettlementData]
	)

	assert_almost_eq(tower.kaiu_decay_reduction, 0.50, 0.001)
	assert_eq(tower.kaiu_reinforce_seasons_remaining, 3)


func test_wall_engineering_kaiu_overwrite_rule_keeps_higher() -> void:
	# Existing modifier 0.75 should not be overwritten by weaker 0.25.
	var tower := _make_wall_tower_s(10, 6)
	tower.kaiu_decay_reduction = 0.75
	tower.kaiu_reinforce_seasons_remaining = 4
	var applied_list: Array = [{
		"action_id": "FORTIFY_WALL_SECTION",
		"effects": {
			"requires_fortify_wall": true,
			"si_gain": 1,
			"kaiu_decay_reduction": 0.25,
			"kaiu_reinforce_duration": 2,
			"target_province_id": 10,
		},
	}]

	DayOrchestrator._process_wall_engineering_effects(
		applied_list, [tower] as Array[SettlementData]
	)

	assert_almost_eq(tower.kaiu_decay_reduction, 0.75, 0.001,
		"Weaker modifier should not overwrite stronger one")
	assert_eq(tower.kaiu_reinforce_seasons_remaining, 4)


func test_wall_engineering_seal_sets_si_to_2() -> void:
	var tower := _make_wall_tower_s(10, 0)
	var applied_list: Array = [{
		"action_id": "SEAL_WALL_BREACH",
		"effects": {
			"requires_breach_seal": true,
			"koku_cost": 5.0,
			"target_province_id": 10,
		},
	}]

	DayOrchestrator._process_wall_engineering_effects(
		applied_list, [tower] as Array[SettlementData]
	)

	assert_eq(tower.wall_si, 2, "Successful breach seal sets SI to 2")


func test_wall_engineering_seal_deducts_koku() -> void:
	var tower := _make_wall_tower_s(10, 0, 10.0)
	var applied_list: Array = [{
		"action_id": "SEAL_WALL_BREACH",
		"effects": {
			"requires_breach_seal": true,
			"koku_cost": 5.0,
			"target_province_id": 10,
		},
	}]

	DayOrchestrator._process_wall_engineering_effects(
		applied_list, [tower] as Array[SettlementData]
	)

	assert_almost_eq(tower.koku_stockpile, 5.0, 0.001, "5 koku deducted for seal")


func test_wall_engineering_seal_failed_does_not_change_si() -> void:
	var tower := _make_wall_tower_s(10, 0, 10.0)
	var applied_list: Array = [{
		"action_id": "SEAL_WALL_BREACH",
		"effects": {
			"requires_breach_seal": false,
			"koku_cost": 5.0,
			"target_province_id": 10,
		},
	}]

	DayOrchestrator._process_wall_engineering_effects(
		applied_list, [tower] as Array[SettlementData]
	)

	assert_eq(tower.wall_si, 0, "Failed breach seal leaves SI at 0")


# -- _process_sortie_results: SS reduction + jade consumption ------------------

func test_sortie_results_reduces_ss_on_province() -> void:
	var province := ProvinceData.new()
	province.province_id = 10
	province.shadowlands_strength = 6

	var tower := _make_wall_tower_s(10, 8)

	var applied_list: Array = [{
		"action_id": "CONDUCT_SORTIE",
		"effects": {
			"requires_sortie_combat": true,
			"force_size": "small",
			"ss_reduction": 1,
			"force_pct": 0.20,
			"jade_per_warrior": 1,
			"target_province_id": 10,
		},
	}]

	var results := DayOrchestrator._process_sortie_results(
		applied_list, [tower] as Array[SettlementData], {10: province}
	)

	assert_eq(province.shadowlands_strength, 5, "SS reduced by 1 for small sortie")
	assert_eq(results.size(), 1)


func test_sortie_results_ss_clamped_at_zero() -> void:
	var province := ProvinceData.new()
	province.province_id = 10
	province.shadowlands_strength = 0

	var tower := _make_wall_tower_s(10, 8)
	var applied_list: Array = [{
		"action_id": "CONDUCT_SORTIE",
		"effects": {
			"requires_sortie_combat": true,
			"force_size": "large",
			"ss_reduction": 3,
			"force_pct": 0.60,
			"jade_per_warrior": 3,
			"target_province_id": 10,
		},
	}]

	DayOrchestrator._process_sortie_results(
		applied_list, [tower] as Array[SettlementData], {10: province}
	)

	assert_eq(province.shadowlands_strength, 0, "SS cannot go below 0")


func test_sortie_results_deducts_jade_from_settlement() -> void:
	var province := ProvinceData.new()
	province.province_id = 10
	province.shadowlands_strength = 5

	var tower := _make_wall_tower_s(10, 8)
	tower.garrison_pu = 10
	tower.jade_stockpile = 50.0

	# Small sortie: force_pct=0.20, jade_per_warrior=1
	# warriors = floor(10 * 0.20) = 2, jade = 2 * 1 = 2
	var applied_list: Array = [{
		"action_id": "CONDUCT_SORTIE",
		"effects": {
			"requires_sortie_combat": true,
			"force_size": "small",
			"ss_reduction": 1,
			"force_pct": 0.20,
			"jade_per_warrior": 1,
			"target_province_id": 10,
		},
	}]

	DayOrchestrator._process_sortie_results(
		applied_list, [tower] as Array[SettlementData], {10: province}
	)

	assert_almost_eq(tower.jade_stockpile, 48.0, 0.001, "2 jade consumed for 2 warriors")


func test_sortie_results_jade_clamped_at_zero() -> void:
	var province := ProvinceData.new()
	province.province_id = 10
	province.shadowlands_strength = 5

	var tower := _make_wall_tower_s(10, 8)
	tower.garrison_pu = 10
	tower.jade_stockpile = 0.5  # not enough for the full cost

	var applied_list: Array = [{
		"action_id": "CONDUCT_SORTIE",
		"effects": {
			"requires_sortie_combat": true,
			"force_size": "medium",
			"ss_reduction": 2,
			"force_pct": 0.40,
			"jade_per_warrior": 2,
			"target_province_id": 10,
		},
	}]

	DayOrchestrator._process_sortie_results(
		applied_list, [tower] as Array[SettlementData], {10: province}
	)

	assert_almost_eq(tower.jade_stockpile, 0.0, 0.001, "Jade never goes negative")


# -- Kaiu modifier ticks down in seasonal wall pressure -----------------------

func test_kaiu_modifier_ticks_down_each_season() -> void:
	var tower := _make_wall_tower_s(10, 8)
	tower.kaiu_decay_reduction = 0.50
	tower.kaiu_reinforce_seasons_remaining = 3

	var province := ProvinceData.new()
	province.province_id = 10
	province.shadowlands_strength = 0
	province.adjacent_province_ids = []

	var season_meta: Dictionary = {}

	DayOrchestrator._process_wall_seasonal_pressure(
		[tower] as Array[SettlementData], {10: province}, 1, season_meta
	)

	assert_eq(tower.kaiu_reinforce_seasons_remaining, 2,
		"Remaining seasons ticked from 3 to 2")
	assert_almost_eq(tower.kaiu_decay_reduction, 0.50, 0.001,
		"Modifier still active with remaining seasons")


func test_kaiu_modifier_cleared_when_seasons_reach_zero() -> void:
	var tower := _make_wall_tower_s(10, 8)
	tower.kaiu_decay_reduction = 0.50
	tower.kaiu_reinforce_seasons_remaining = 1

	var province := ProvinceData.new()
	province.province_id = 10
	province.shadowlands_strength = 0
	province.adjacent_province_ids = []

	var season_meta: Dictionary = {}

	DayOrchestrator._process_wall_seasonal_pressure(
		[tower] as Array[SettlementData], {10: province}, 1, season_meta
	)

	assert_eq(tower.kaiu_reinforce_seasons_remaining, 0)
	assert_almost_eq(tower.kaiu_decay_reduction, 0.0, 0.001,
		"Modifier cleared when seasons reach 0")

