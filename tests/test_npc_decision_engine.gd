extends GutTest


var _char: L5RCharacterData
var _world_state: Dictionary
var _objectives: Dictionary
var _scoring_tables: Dictionary
var _filter_data: Dictionary


func before_each() -> void:
	_char = L5RCharacterData.new()
	_char.character_id = 1
	_char.character_name = "Test Samurai"
	_char.clan = "Crane"
	_char.family = "Doji"
	_char.school_type = Enums.SchoolType.COURTIER
	_char.bushido_virtue = Enums.BushidoVirtue.REI
	_char.shourido_virtue = Enums.ShouridoVirtue.NONE
	_char.honor = 5.0
	_char.glory = 3.0
	_char.status = 4.0
	_char.skills = {"Courtier": 3, "Etiquette": 4, "Sincerity": 2}
	ActionPointSystem.reset_daily_ap(_char)

	_world_state = {
		"context_flag": Enums.ContextFlag.AT_COURT,
		"season": 1,
		"ic_day": 10,
		"characters_present": [2, 3, 4] as Array[int],
		"is_lord": false,
		"known_topics": [] as Array[int],
		"known_positions": {},
		"known_objectives": {},
		"known_contacts": [] as Array[int],
		"pending_events": [],
		"action_log": [] as Array[String],
	}

	_objectives = {
		"primary": {
			"need_type": "RAISE_DISPOSITION",
			"target_npc_id": 2,
			"priority": 2,
		},
		"standing": {
			"need_type": "SEEK_GLORY",
			"priority": 3,
		},
	}

	_scoring_tables = {
		"objective_alignment": {
			"RAISE_DISPOSITION": {
				"CHARM": 80,
				"GOSSIP": 30,
				"WRITE_LETTER": 40,
				"DO_NOTHING": 0,
			},
			"SEEK_GLORY": {
				"PUBLIC_DEBATE": 70,
				"CHARM": 20,
			},
		},
		"disposition_tiers": [
			{"min": -100, "max": -50, "cooperative": -20, "hostile": 20},
			{"min": -50, "max": -10, "cooperative": -10, "hostile": 10},
			{"min": -10, "max": 10, "cooperative": 0, "hostile": 0},
			{"min": 10, "max": 50, "cooperative": 10, "hostile": -10},
			{"min": 50, "max": 100, "cooperative": 20, "hostile": -20},
		],
		"personality_lean": {
			"REI": {
				"CHARM": 10,
				"GOSSIP": -10,
				"PUBLIC_DEBATE": 5,
			},
		},
		"action_skill_map": {
			"CHARM": {"primary": "Courtier", "secondary": "Sincerity"},
			"GOSSIP": {"primary": "Courtier", "secondary": ""},
			"PUBLIC_DEBATE": {"primary": "Courtier", "secondary": "Etiquette"},
		},
		"urgency_rules": [
			{"condition": "priority_1", "bonus": 20},
		],
		"topic_position_alignment": {},
	}

	_filter_data = {
		"bushido": {
			"REI": {
				"always_blocked": ["INTIMIDATE"],
			},
		},
		"shourido": {},
	}


# -- Phase 1: Build Context ---------------------------------------------------

func test_build_context_identity() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.character_id, 1)
	assert_eq(ctx.character_name, "Test Samurai")
	assert_eq(ctx.clan, "Crane")
	assert_eq(ctx.family, "Doji")
	assert_eq(ctx.school_type, Enums.SchoolType.COURTIER)


func test_build_context_location() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.context_flag, Enums.ContextFlag.AT_COURT)
	assert_eq(ctx.season, 1)
	assert_eq(ctx.ic_day, 10)


func test_build_context_stats() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.honor, 5.0)
	assert_eq(ctx.glory, 3.0)
	assert_eq(ctx.status, 4.0)
	assert_eq(ctx.skill_ranks["Courtier"], 3)


func test_build_context_social() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.characters_present.size(), 3)


func test_build_context_personality() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.bushido_virtue, Enums.BushidoVirtue.REI)


func test_build_context_lord_tier() -> void:
	_world_state["is_lord"] = true
	_world_state["resource_stockpiles"] = {"rice": 100, "koku": 50}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	assert_true(ctx.is_lord)
	assert_eq(ctx.resource_stockpiles["rice"], 100)


func test_build_context_non_lord_no_resources() -> void:
	_world_state["is_lord"] = false
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	assert_false(ctx.is_lord)
	assert_true(ctx.resource_stockpiles.is_empty())


func test_build_context_military_defaults() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.wall_statuses.size(), 0)
	assert_eq(ctx.known_clan_strengths.size(), 0)
	assert_eq(ctx.unit_training_counts.size(), 0)
	assert_almost_eq(ctx.available_levy_pu, 0.0, 0.001)
	assert_true(ctx.can_sustain_iron_upkeep)
	assert_eq(ctx.active_wars.size(), 0)
	assert_eq(ctx.escalating_conflicts.size(), 0)
	assert_eq(ctx.taint_topic_province_ids.size(), 0)


func test_build_context_confidence_penalty_fresh_no_penalty() -> void:
	InformationSystem.add_knowledge(_char, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "observed_action",
		{"target_character_id": 2}, 0
	))
	var penalty: float = NPCDecisionEngine._compute_confidence_penalty(_char, 2, 50.0)
	assert_almost_eq(penalty, 0.0, 0.001)


func test_build_context_confidence_penalty_recent() -> void:
	var entry := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "observed_action",
		{"target_character_id": 2}, 0
	)
	entry.confidence = Enums.KnowledgeConfidence.RECENT
	InformationSystem.add_knowledge(_char, entry)
	var penalty: float = NPCDecisionEngine._compute_confidence_penalty(_char, 2, 50.0)
	assert_almost_eq(penalty, -10.0, 0.001)


func test_build_context_confidence_penalty_stale_halves() -> void:
	var entry := InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "observed_action",
		{"target_character_id": 2}, 0
	)
	entry.confidence = Enums.KnowledgeConfidence.STALE
	InformationSystem.add_knowledge(_char, entry)
	var penalty: float = NPCDecisionEngine._compute_confidence_penalty(_char, 2, 60.0)
	assert_almost_eq(penalty, -30.0, 0.001)


func test_build_context_confidence_penalty_no_knowledge_no_penalty() -> void:
	var penalty: float = NPCDecisionEngine._compute_confidence_penalty(_char, 99, 50.0)
	assert_almost_eq(penalty, 0.0, 0.001)


# -- Stale Intel Bonus (s55.12) ------------------------------------------------

func test_stale_intel_bonus_probe_action() -> void:
	var entry: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "observed_action",
		{"target_character_id": 2}, 1
	)
	entry.confidence = Enums.KnowledgeConfidence.STALE
	InformationSystem.add_knowledge(_char, entry)
	var bonus: float = NPCDecisionEngine._compute_stale_intel_bonus(_char, "PROBE", 2)
	assert_almost_eq(bonus, 15.0, 0.001)


func test_stale_intel_bonus_non_gather_action() -> void:
	var entry: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "observed_action",
		{"target_character_id": 2}, 1
	)
	entry.confidence = Enums.KnowledgeConfidence.STALE
	InformationSystem.add_knowledge(_char, entry)
	var bonus: float = NPCDecisionEngine._compute_stale_intel_bonus(_char, "CHARM", 2)
	assert_almost_eq(bonus, 0.0, 0.001)


func test_stale_intel_bonus_fresh_no_bonus() -> void:
	InformationSystem.add_knowledge(_char, InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "observed_action",
		{"target_character_id": 2}, 1
	))
	var bonus: float = NPCDecisionEngine._compute_stale_intel_bonus(_char, "PROBE", 2)
	assert_almost_eq(bonus, 0.0, 0.001)


func test_stale_intel_bonus_read_character() -> void:
	var entry: KnowledgeEntry = InformationSystem.make_entry(
		Enums.KnowledgeSource.INTELLIGENCE, "observed_action",
		{"target_character_id": 2}, 1
	)
	entry.confidence = Enums.KnowledgeConfidence.STALE
	InformationSystem.add_knowledge(_char, entry)
	var bonus: float = NPCDecisionEngine._compute_stale_intel_bonus(_char, "READ_CHARACTER", 2)
	assert_almost_eq(bonus, 15.0, 0.001)


func test_stale_intel_bonus_in_total_score() -> void:
	var action := NPCDataStructures.ScoredAction.new()
	action.stale_intel_bonus = 15.0
	action.objective_alignment = 50.0
	assert_almost_eq(action.get_total_score(), 65.0, 0.001)


func test_build_context_military_populated() -> void:
	_world_state["wall_statuses"] = [{"province_id": 10, "si": 8}]
	_world_state["known_clan_strengths"] = {"Crab": 100.0, "Lion": 80.0}
	_world_state["unit_training_counts"] = {0: 3, 1: 2, 2: 1}
	_world_state["available_levy_pu"] = 15.0
	_world_state["can_sustain_iron_upkeep"] = false
	_world_state["active_wars"] = [{"clan_a": "Crab", "clan_b": "Lion"}]
	_world_state["escalating_conflicts"] = [{"topic_id": 5}]
	var taint_ids: Array[int] = [10, 20]
	_world_state["taint_topic_province_ids"] = taint_ids
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.wall_statuses.size(), 1)
	assert_eq(ctx.known_clan_strengths["Crab"], 100.0)
	assert_eq(ctx.unit_training_counts[0], 3)
	assert_almost_eq(ctx.available_levy_pu, 15.0, 0.001)
	assert_false(ctx.can_sustain_iron_upkeep)
	assert_eq(ctx.active_wars.size(), 1)
	assert_eq(ctx.escalating_conflicts.size(), 1)
	assert_eq(ctx.taint_topic_province_ids.size(), 2)


# -- Phase 2: Resolve Goal ----------------------------------------------------

func test_resolve_goal_primary_objective() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, _objectives)
	assert_eq(need.need_type, "RAISE_DISPOSITION")
	assert_eq(need.target_npc_id, 2)
	assert_eq(need.priority, 2)


func test_resolve_goal_reactive_takes_priority() -> void:
	_world_state["pending_events"] = [
		{"need_type": "CHALLENGE_TO_DUEL", "priority": 1, "target_npc_id": 5}
	]
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, _objectives)
	assert_eq(need.need_type, "CHALLENGE_TO_DUEL")
	assert_eq(need.priority, 1)


func test_resolve_goal_standing_fallback() -> void:
	var objectives_no_primary: Dictionary = {
		"standing": {"need_type": "SEEK_GLORY", "priority": 3},
	}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, objectives_no_primary)
	assert_eq(need.need_type, "SEEK_GLORY")


func test_resolve_goal_absolute_fallback() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, {})
	assert_eq(need.need_type, "REST")
	assert_eq(need.priority, 3)


func test_resolve_goal_crisis_override_for_lord() -> void:
	_world_state["is_lord"] = true
	var ps := NPCDataStructures.ProvinceStatus.new()
	ps.province_id = 10
	ps.active_crisis_id = 42
	_world_state["province_statuses"] = [ps]
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, _objectives)
	assert_eq(need.need_type, "DEFEND_PROVINCE")
	assert_eq(need.target_province_id, 10)
	assert_eq(need.source, "crisis_override")


# -- Phase 3: Generate Options ------------------------------------------------

func test_generate_options_court_context() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	need.target_npc_id = 2
	var options := NPCDecisionEngine.generate_options(ctx, need)
	assert_true(options.size() > 0)
	var action_ids: Array[String] = []
	for o in options:
		action_ids.append(o.action_id)
	assert_has(action_ids, "CHARM")
	assert_has(action_ids, "GOSSIP")
	assert_has(action_ids, "PUBLIC_DEBATE")


func test_generate_options_holdings_context() -> void:
	_world_state["context_flag"] = Enums.ContextFlag.AT_OWN_HOLDINGS
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "REST"
	var options := NPCDecisionEngine.generate_options(ctx, need)
	var action_ids: Array[String] = []
	for o in options:
		action_ids.append(o.action_id)
	assert_has(action_ids, "WRITE_LETTER")
	assert_has(action_ids, "ASSESS_PROVINCE_STATUS")
	assert_does_not_have(action_ids, "CHARM")


func test_generate_options_carry_target() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.target_npc_id = 7
	var options := NPCDecisionEngine.generate_options(ctx, need)
	for o in options:
		assert_eq(o.target_npc_id, 7)


# -- Phase 4: Personality Filter -----------------------------------------------

func test_filter_blocks_action() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var options: Array[NPCDataStructures.ScoredAction] = []
	var charm := NPCDataStructures.ScoredAction.new()
	charm.action_id = "CHARM"
	options.append(charm)
	var intimidate := NPCDataStructures.ScoredAction.new()
	intimidate.action_id = "INTIMIDATE"
	options.append(intimidate)

	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, _filter_data)
	assert_eq(filtered.size(), 1)
	assert_eq(filtered[0].action_id, "CHARM")


func test_filter_no_blocks_pass_through() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	ctx.bushido_virtue = Enums.BushidoVirtue.NONE
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	var options: Array[NPCDataStructures.ScoredAction] = []
	var charm := NPCDataStructures.ScoredAction.new()
	charm.action_id = "CHARM"
	options.append(charm)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, {})
	assert_eq(filtered.size(), 1)


# -- Phase 5: Score All Options ------------------------------------------------

func test_score_objective_alignment() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	option.target_npc_id = 2
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.objective_alignment, 80.0)


func test_score_personality_lean() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var charm := NPCDataStructures.ScoredAction.new()
	charm.action_id = "CHARM"
	var gossip := NPCDataStructures.ScoredAction.new()
	gossip.action_id = "GOSSIP"
	NPCDecisionEngine.score_all([charm, gossip], need, ctx, _scoring_tables)
	assert_eq(charm.personality_lean, 10.0, "REI favors CHARM")
	assert_eq(gossip.personality_lean, -10.0, "REI dislikes GOSSIP")


func test_score_competence_modifier() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	# Courtier rank 3 = 0, Sincerity rank 2 = -5 * 0.5 = -2.5
	# Total competence = 0 + (-2.5) = -2.5
	assert_almost_eq(option.competence_modifier, -2.5, 0.01)


func test_score_disposition_modifier_positive() -> void:
	_char.disposition_values = {2: 30}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	option.target_npc_id = 2
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.disposition_modifier, 10.0)


func test_score_urgency_priority_1() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	need.priority = 1
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.urgency_bonus, 20.0)


func test_score_standing_influence() -> void:
	_world_state["known_objectives"] = {"standing_need_type": "SEEK_GLORY"}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	# SEEK_GLORY -> CHARM = 20, /10 = 2.0
	assert_eq(option.standing_influence, 2.0)


# -- Phase 6: Selection -------------------------------------------------------

func test_select_highest_score() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "CHARM"
	a.objective_alignment = 80.0
	var b := NPCDataStructures.ScoredAction.new()
	b.action_id = "GOSSIP"
	b.objective_alignment = 30.0
	var chosen := NPCDecisionEngine.select_action([a, b], ctx)
	assert_eq(chosen.action_id, "CHARM")


func test_select_tiebreaker_obj_alignment() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "A"
	a.objective_alignment = 80.0
	a.disposition_modifier = -80.0
	var b := NPCDataStructures.ScoredAction.new()
	b.action_id = "B"
	b.objective_alignment = 50.0
	b.disposition_modifier = -50.0
	var chosen := NPCDecisionEngine.select_action([a, b], ctx)
	assert_eq(chosen.action_id, "A", "Higher ObjAlign wins tiebreaker")


func test_select_tiebreaker_ap_cost() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var a := NPCDataStructures.ScoredAction.new()
	a.action_id = "A"
	a.objective_alignment = 50.0
	a.ap_cost = 2
	var b := NPCDataStructures.ScoredAction.new()
	b.action_id = "B"
	b.objective_alignment = 50.0
	b.ap_cost = 1
	var chosen := NPCDecisionEngine.select_action([a, b], ctx)
	assert_eq(chosen.action_id, "B", "Lower AP cost wins tiebreaker")


func test_select_empty_options_fallback() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var chosen := NPCDecisionEngine.select_action([], ctx)
	assert_eq(chosen.action_id, "DO_NOTHING")


# -- Phase 7: Execution -------------------------------------------------------

func test_execute_deducts_ap() -> void:
	var chosen := NPCDataStructures.ScoredAction.new()
	chosen.action_id = "CHARM"
	chosen.ap_cost = 1
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var result := NPCDecisionEngine.execute_action(chosen, _char, ctx)
	assert_true(result["success"])
	assert_eq(result["action_id"], "CHARM")
	assert_eq(result["ap_spent"], 1)
	assert_eq(_char.action_points_current, 1)


func test_execute_insufficient_ap() -> void:
	ActionPointSystem.spend_ap(_char, 2)
	var chosen := NPCDataStructures.ScoredAction.new()
	chosen.action_id = "CHARM"
	chosen.ap_cost = 1
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var result := NPCDecisionEngine.execute_action(chosen, _char, ctx)
	assert_false(result["success"])
	assert_eq(result["reason"], "insufficient_ap")


func test_execute_records_character_and_day() -> void:
	var chosen := NPCDataStructures.ScoredAction.new()
	chosen.action_id = "TRAIN"
	chosen.ap_cost = 1
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var result := NPCDecisionEngine.execute_action(chosen, _char, ctx)
	assert_eq(result["character_id"], 1)
	assert_eq(result["ic_day"], 10)


# -- Full Loop -----------------------------------------------------------------

func test_full_loop_runs() -> void:
	var result := NPCDecisionEngine.run(
		_char, _world_state, _objectives, _scoring_tables, _filter_data
	)
	assert_true(result["success"])
	assert_true(result["action_id"] != "")


func test_full_loop_charm_wins_for_raise_disposition() -> void:
	_char.disposition_values = {2: 30}
	var result := NPCDecisionEngine.run(
		_char, _world_state, _objectives, _scoring_tables, _filter_data
	)
	assert_true(result["success"])
	assert_eq(result["action_id"], "CHARM")


func test_full_loop_filter_removes_intimidate() -> void:
	var result := NPCDecisionEngine.run(
		_char, _world_state, _objectives, _scoring_tables, _filter_data
	)
	assert_true(result["success"])
	assert_ne(result["action_id"], "INTIMIDATE", "REI blocks INTIMIDATE")


func test_full_loop_reactive_overrides() -> void:
	_world_state["pending_events"] = [
		{"need_type": "CHALLENGE_TO_DUEL", "priority": 1, "target_npc_id": 5}
	]
	var result := NPCDecisionEngine.run(
		_char, _world_state, _objectives, _scoring_tables, _filter_data
	)
	assert_true(result["success"])
