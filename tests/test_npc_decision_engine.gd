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
			{"condition": "war_score_below_25", "bonus": 25, "applies_to": ["CHARM", "ORDER_BATTLE"], "stacks_per_crisis": false},
			{"condition": "active_crisis_in_relevance_range", "bonus": 15, "applies_to": "actions_addressing_crisis", "stacks_per_crisis": true, "weight_by_relevance": true},
			{"condition": "court_ending_within_2_ic_days", "bonus": 10, "applies_to": "court_actions", "stacks_per_crisis": false},
			{"condition": "favor_expiring_within_7_ooc_days", "bonus": 20, "applies_to": ["HONOR_FAVOR", "BREAK_FAVOR"], "stacks_per_crisis": false},
			{"condition": "objective_stalled_2_plus_seasons", "bonus": 10, "applies_to": "actions_addressing_primary_objective", "stacks_per_crisis": false},
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


func test_score_disposition_hostile_action_against_enemy() -> void:
	_char.disposition_values = {2: -30}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "INTIMIDATE"
	option.target_npc_id = 2
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	# Disposition -30 is in [-50, -10] tier, hostile column = 10
	assert_eq(option.disposition_modifier, 10.0)


func test_score_disposition_hostile_action_against_friend() -> void:
	_char.disposition_values = {2: 30}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "INTIMIDATE"
	option.target_npc_id = 2
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	# Disposition 30 is in [10, 50] tier, hostile column = -10
	assert_eq(option.disposition_modifier, -10.0)


func test_score_disposition_cooperative_action_against_enemy() -> void:
	_char.disposition_values = {2: -30}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	option.target_npc_id = 2
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	# Disposition -30 is in [-50, -10] tier, cooperative column = -10
	assert_eq(option.disposition_modifier, -10.0)


func test_score_urgency_war_score_below_25() -> void:
	_world_state["active_wars"] = [{"clan_a": "Crane", "clan_b": "Lion", "war_score": 20}]
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.urgency_bonus, 25.0)


func test_score_urgency_no_matching_condition() -> void:
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.urgency_bonus, 0.0)


func test_score_urgency_action_not_in_applies_to() -> void:
	_world_state["active_wars"] = [{"clan_a": "Crane", "clan_b": "Lion", "war_score": 20}]
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "GOSSIP"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.urgency_bonus, 0.0)


func test_score_urgency_crisis_stacking() -> void:
	_world_state["is_lord"] = true
	var ps1 := NPCDataStructures.ProvinceStatus.new()
	ps1.province_id = 10
	ps1.active_crisis_id = 1
	var ps2 := NPCDataStructures.ProvinceStatus.new()
	ps2.province_id = 20
	ps2.active_crisis_id = 2
	_world_state["province_statuses"] = [ps1, ps2]
	# Add ObjAlign data so CHARM qualifies as actions_addressing_crisis
	_scoring_tables["objective_alignment"]["DEFEND_PROVINCE"] = {"CHARM": 50}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	# 2 crises × 15 bonus × 1.0 relevance = 30, clamped to 30
	assert_eq(option.urgency_bonus, 30.0)
	# Clean up
	_scoring_tables["objective_alignment"].erase("DEFEND_PROVINCE")


func test_score_urgency_clamped_at_30() -> void:
	_world_state["is_lord"] = true
	_world_state["active_wars"] = [{"clan_a": "Crane", "clan_b": "Lion", "war_score": 20}]
	var ps1 := NPCDataStructures.ProvinceStatus.new()
	ps1.province_id = 10
	ps1.active_crisis_id = 1
	_world_state["province_statuses"] = [ps1]
	_scoring_tables["objective_alignment"]["DEFEND_PROVINCE"] = {"CHARM": 50}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	# war_score_below_25: 25 + crisis: 15 = 40, clamped to 30
	assert_eq(option.urgency_bonus, 30.0)
	_scoring_tables["objective_alignment"].erase("DEFEND_PROVINCE")


func test_urgency_court_ending_within_2_days() -> void:
	_world_state["active_court_at_location"] = {
		"elapsed_ticks": 118,
		"duration_ticks": 120,
	}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.urgency_bonus, 10.0)


func test_urgency_court_ending_not_soon_no_bonus() -> void:
	_world_state["active_court_at_location"] = {
		"elapsed_ticks": 100,
		"duration_ticks": 120,
	}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.urgency_bonus, 0.0)


func test_urgency_favor_expiring() -> void:
	var favor := FavorData.new()
	favor.favor_id = 1
	favor.debtor_id = 1
	favor.invoked = true
	favor.response_deadline_ic_day = 15
	_world_state["favors"] = [favor]
	_world_state["ic_day"] = 5
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.expiring_favor_ids.size(), 1)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "HONOR_FAVOR"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.urgency_bonus, 20.0)


func test_urgency_objective_stalled() -> void:
	_world_state["objective_stalled_seasons"] = 3
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	assert_eq(ctx.objective_stalled_seasons, 3)
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.urgency_bonus, 10.0)


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


# -- Famine Province Extraction ------------------------------------------------

func test_extract_famine_province_ids_known_topic() -> void:
	var t: TopicData = TopicData.new()
	t.topic_id = 50
	t.topic_type = "famine"
	t.variant = "provincial_famine"
	t.provinces_affected = [3, 7]
	_char.topic_pool = [50]
	var ids: Array[int] = NPCDecisionEngine._extract_famine_province_ids(
		_char, [t],
	)
	assert_true(3 in ids)
	assert_true(7 in ids)


func test_extract_famine_province_ids_unknown_topic_ignored() -> void:
	var t: TopicData = TopicData.new()
	t.topic_id = 50
	t.topic_type = "famine"
	t.provinces_affected = [3]
	_char.topic_pool = []
	var ids: Array[int] = NPCDecisionEngine._extract_famine_province_ids(
		_char, [t],
	)
	assert_eq(ids.size(), 0, "Unknown topic yields no provinces")


func test_extract_famine_province_ids_resolved_ignored() -> void:
	var t: TopicData = TopicData.new()
	t.topic_id = 50
	t.topic_type = "famine"
	t.resolved = true
	t.provinces_affected = [3]
	_char.topic_pool = [50]
	var ids: Array[int] = NPCDecisionEngine._extract_famine_province_ids(
		_char, [t],
	)
	assert_eq(ids.size(), 0, "Resolved famine topic yields no provinces")


# =============================================================================
# AT_WALL_TOWER Context Action List (s57.19)
# =============================================================================

func test_at_wall_tower_has_fortify_wall_section() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_WALL_TOWER
	)
	assert_true("FORTIFY_WALL_SECTION" in actions)

func test_at_wall_tower_has_seal_wall_breach() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_WALL_TOWER
	)
	assert_true("SEAL_WALL_BREACH" in actions)

func test_at_wall_tower_has_conduct_sortie() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_WALL_TOWER
	)
	assert_true("CONDUCT_SORTIE" in actions)

func test_at_wall_tower_has_scout_enemy() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_WALL_TOWER
	)
	assert_true("SCOUT_ENEMY" in actions)

func test_at_wall_tower_has_dispatch_courtier() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_WALL_TOWER
	)
	assert_true("DISPATCH_COURTIER" in actions)

func test_at_own_holdings_no_fortify_wall_section() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	assert_false("FORTIFY_WALL_SECTION" in actions,
		"FORTIFY_WALL_SECTION requires AT_WALL_TOWER, not AT_OWN_HOLDINGS")

func test_at_own_holdings_no_seal_wall_breach() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	assert_false("SEAL_WALL_BREACH" in actions,
		"SEAL_WALL_BREACH requires AT_WALL_TOWER, not AT_OWN_HOLDINGS")

func test_at_own_holdings_has_purify_tainted_ground() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_OWN_HOLDINGS
	)
	assert_true("PURIFY_TAINTED_GROUND" in actions,
		"PURIFY_TAINTED_GROUND context includes AT_OWN_HOLDINGS per GDD s57.19")


# =============================================================================
# School Filter (s57.19 Annex C)
# =============================================================================

func _make_kaiu_ctx(rank: int = 4) -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.school = "Kaiu Engineer"
	ctx.school_type = Enums.SchoolType.BUSHI
	ctx.insight_rank = rank
	ctx.bushido_virtue = Enums.BushidoVirtue.NONE
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	return ctx

func _make_kuni_ctx() -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.school = "Kuni Shugenja"
	ctx.school_type = Enums.SchoolType.SHUGENJA
	ctx.insight_rank = 2
	ctx.bushido_virtue = Enums.BushidoVirtue.NONE
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	return ctx

func _make_bushi_ctx(school: String = "Kakita Bushi") -> NPCDataStructures.ContextSnapshot:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.school = school
	ctx.school_type = Enums.SchoolType.BUSHI
	ctx.insight_rank = 3
	ctx.bushido_virtue = Enums.BushidoVirtue.NONE
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	return ctx

func test_kaiu_can_fortify_wall() -> void:
	var ctx := _make_kaiu_ctx()
	assert_false(NPCDecisionEngine._is_action_blocked("FORTIFY_WALL_SECTION", ctx, {}))

func test_non_kaiu_blocked_from_fortify() -> void:
	var ctx := _make_bushi_ctx()
	assert_true(NPCDecisionEngine._is_action_blocked("FORTIFY_WALL_SECTION", ctx, {}))

func test_kaiu_rank3_can_seal_breach() -> void:
	var ctx := _make_kaiu_ctx(3)
	assert_false(NPCDecisionEngine._is_action_blocked("SEAL_WALL_BREACH", ctx, {}))

func test_kaiu_rank2_blocked_from_seal_breach() -> void:
	var ctx := _make_kaiu_ctx(2)
	assert_true(NPCDecisionEngine._is_action_blocked("SEAL_WALL_BREACH", ctx, {}),
		"SEAL_WALL_BREACH requires Kaiu Engineer Rank 3+")

func test_non_kaiu_blocked_from_seal_breach() -> void:
	var ctx := _make_bushi_ctx()
	assert_true(NPCDecisionEngine._is_action_blocked("SEAL_WALL_BREACH", ctx, {}))

func test_kuni_can_purify_tainted_ground() -> void:
	var ctx := _make_kuni_ctx()
	assert_false(NPCDecisionEngine._is_action_blocked("PURIFY_TAINTED_GROUND", ctx, {}))

func test_non_kuni_blocked_from_purify() -> void:
	var ctx := _make_bushi_ctx()
	assert_true(NPCDecisionEngine._is_action_blocked("PURIFY_TAINTED_GROUND", ctx, {}))

func test_shugenja_non_kuni_blocked_from_purify() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.school = "Isawa Shugenja"
	ctx.school_type = Enums.SchoolType.SHUGENJA
	ctx.insight_rank = 2
	ctx.bushido_virtue = Enums.BushidoVirtue.NONE
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	assert_true(NPCDecisionEngine._is_action_blocked("PURIFY_TAINTED_GROUND", ctx, {}),
		"Only Kuni Shugenja can purify tainted ground")

func test_school_filter_does_not_block_other_actions() -> void:
	var ctx := _make_bushi_ctx()
	assert_false(NPCDecisionEngine._is_action_blocked("CHARM", ctx, {}),
		"School filter should only affect the three wall actions")

func test_build_context_populates_school() -> void:
	_char.school = "Kaiu Engineer"
	var ws := _world_state.duplicate()
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(
		_char, ws
	)
	assert_eq(ctx.school, "Kaiu Engineer")


# --- Topic position scoring (s55.14, s55.26 Annex H) ---

func test_interpolate_strong_support_returns_cap() -> void:
	var entry: Dictionary = {"strong_support": 12, "strong_opposition": -8}
	var result: float = NPCDecisionEngine._interpolate_topic_position(60.0, entry)
	assert_eq(result, 12.0)


func test_interpolate_strong_opposition_returns_cap() -> void:
	var entry: Dictionary = {"strong_support": 12, "strong_opposition": -8}
	var result: float = NPCDecisionEngine._interpolate_topic_position(-60.0, entry)
	assert_eq(result, -8.0)


func test_interpolate_neutral_returns_zero() -> void:
	var entry: Dictionary = {"strong_support": 15, "strong_opposition": -15}
	assert_eq(NPCDecisionEngine._interpolate_topic_position(0.0, entry), 0.0)
	assert_eq(NPCDecisionEngine._interpolate_topic_position(10.0, entry), 0.0)
	assert_eq(NPCDecisionEngine._interpolate_topic_position(-10.0, entry), 0.0)


func test_interpolate_partial_positive() -> void:
	var entry: Dictionary = {"strong_support": 15, "strong_opposition": -15}
	var result: float = NPCDecisionEngine._interpolate_topic_position(32.5, entry)
	assert_almost_eq(result, 7.5, 0.01)


func test_interpolate_partial_negative() -> void:
	var entry: Dictionary = {"strong_support": 15, "strong_opposition": -15}
	var result: float = NPCDecisionEngine._interpolate_topic_position(-32.5, entry)
	assert_almost_eq(result, -7.5, 0.01)


func test_interpolate_asymmetric_caps() -> void:
	var entry: Dictionary = {"strong_support": 10, "strong_opposition": 0}
	assert_eq(NPCDecisionEngine._interpolate_topic_position(60.0, entry), 10.0)
	assert_eq(NPCDecisionEngine._interpolate_topic_position(-60.0, entry), 0.0)


func test_compute_topic_position_modifier_uses_table() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [1, 2]
	ctx.known_positions = {1: 60.0, 2: -30.0}
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "GATHER_INTELLIGENCE"
	var tables: Dictionary = {
		"topic_position_alignment": {
			"GATHER_INTELLIGENCE": {"strong_support": 10, "strong_opposition": 0},
		},
	}
	var result: float = NPCDecisionEngine._compute_topic_position_modifier(
		"PROBE", need, ctx, tables,
	)
	assert_eq(result, 10.0)


func test_compute_topic_position_modifier_missing_need_type() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [1]
	ctx.known_positions = {1: 80.0}
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "UNKNOWN_NEED"
	var tables: Dictionary = {
		"topic_position_alignment": {
			"GATHER_INTELLIGENCE": {"strong_support": 10, "strong_opposition": 0},
		},
	}
	var result: float = NPCDecisionEngine._compute_topic_position_modifier(
		"PROBE", need, ctx, tables,
	)
	assert_eq(result, 0.0)


# --- Letter topic routing ---

func test_pick_letter_topic_strongest_position() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [10, 20, 30]
	ctx.known_positions = {10: 5.0, 20: -40.0, 30: 15.0}
	var tid: int = NPCDecisionEngine._pick_letter_topic(ctx)
	assert_eq(tid, 20, "Should pick topic with strongest absolute position")


func test_pick_letter_topic_fallback_first() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [10, 20]
	ctx.known_positions = {}
	var tid: int = NPCDecisionEngine._pick_letter_topic(ctx)
	assert_eq(tid, 10, "Falls back to first known topic when no positions")


func test_pick_letter_topic_empty_returns_negative() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = []
	var tid: int = NPCDecisionEngine._pick_letter_topic(ctx)
	assert_eq(tid, -1)


func test_resolve_daily_letter_includes_topic_id() -> void:
	var char := L5RCharacterData.new()
	char.character_id = 1
	char.topic_pool = [42, 55]
	char.topic_positions = {42: 30.0, 55: -10.0}
	char.skills = {"Courtier": 3}
	char.traits = {"Awareness": 3}
	var objectives: Dictionary = {
		"primary": {"need_type": "RAISE_DISPOSITION", "target_npc_id": 5},
	}
	var scoring_tables: Dictionary = {
		"objective_alignment": {
			"RAISE_DISPOSITION": {"WRITE_LETTER": 60},
		},
	}
	var ws: Dictionary = {"is_lord": false}
	var ctx := NPCDecisionEngine.build_context(char, ws)
	var result: Dictionary = NPCDecisionEngine.resolve_daily_letter(
		char, objectives, scoring_tables, ctx,
	)
	assert_eq(result.get("topic_id", -1), 42, "Should include strongest position topic")
