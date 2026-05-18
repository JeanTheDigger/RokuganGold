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


func test_resolve_goal_bribery_eval_decomposes_to_suppress() -> void:
	_world_state["pending_events"] = [
		{"type": "bribery_eval", "case_id": 5, "evidence_total": 28, "magistrate_id": 99}
	]
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, _objectives)
	assert_eq(need.need_type, "SUPPRESS_INVESTIGATION")
	assert_eq(need.target_npc_id, 99)
	assert_eq(need.source, "bribery_eval")
	assert_eq(int(need.threshold), 28)


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


# --- SEEK_PEACE position inversion (s55.26 Annex H) ---

func test_seek_peace_inverts_position_pro_war_penalized() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [1]
	ctx.known_positions = {1: 60.0}
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_PEACE"
	var tables: Dictionary = {
		"topic_position_alignment": {
			"SEEK_PEACE": {"strong_support": 15, "strong_opposition": -15},
		},
	}
	var result: float = NPCDecisionEngine._compute_topic_position_modifier(
		"NEGOTIATE_SURRENDER", need, ctx, tables,
	)
	assert_eq(result, -15.0, "Pro-war NPC (pos +60) should get -15 on SEEK_PEACE")


func test_seek_peace_inverts_position_anti_war_boosted() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [1]
	ctx.known_positions = {1: -60.0}
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_PEACE"
	var tables: Dictionary = {
		"topic_position_alignment": {
			"SEEK_PEACE": {"strong_support": 15, "strong_opposition": -15},
		},
	}
	var result: float = NPCDecisionEngine._compute_topic_position_modifier(
		"NEGOTIATE_SURRENDER", need, ctx, tables,
	)
	assert_eq(result, 15.0, "Anti-war NPC (pos -60) should get +15 on SEEK_PEACE")


func test_seek_peace_neutral_position_zero() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [1]
	ctx.known_positions = {1: 5.0}
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "SEEK_PEACE"
	var tables: Dictionary = {
		"topic_position_alignment": {
			"SEEK_PEACE": {"strong_support": 15, "strong_opposition": -15},
		},
	}
	var result: float = NPCDecisionEngine._compute_topic_position_modifier(
		"NEGOTIATE_SURRENDER", need, ctx, tables,
	)
	assert_eq(result, 0.0, "Neutral position should still be zero after inversion")


# -- Topic type filtering tests -------------------------------------------------

func test_build_known_topic_types_from_topic_data() -> void:
	var t1 := TopicData.new()
	t1.topic_id = 10
	t1.topic_type = "Clan_War"
	var t2 := TopicData.new()
	t2.topic_id = 20
	t2.topic_type = "Provincial_Famine"
	var t3 := TopicData.new()
	t3.topic_id = 30
	t3.topic_type = ""
	var pool: Array[int] = [10, 20, 30]
	var result: Dictionary = NPCDecisionEngine._build_known_topic_types(pool, [t1, t2, t3])
	assert_eq(result.get(10, ""), "Clan_War")
	assert_eq(result.get(20, ""), "Provincial_Famine")
	assert_false(result.has(30), "Empty topic_type should be excluded")


func test_build_known_topic_types_from_dicts() -> void:
	var topics: Array = [
		{"topic_id": 5, "topic_type": "Siege_Beginning"},
		{"topic_id": 6, "topic_type": "Betrayal"},
	]
	var pool: Array[int] = [5, 6]
	var result: Dictionary = NPCDecisionEngine._build_known_topic_types(pool, topics)
	assert_eq(result.get(5, ""), "Siege_Beginning")
	assert_eq(result.get(6, ""), "Betrayal")


func test_build_known_topic_types_filters_by_pool() -> void:
	var t1 := TopicData.new()
	t1.topic_id = 10
	t1.topic_type = "Clan_War"
	var t2 := TopicData.new()
	t2.topic_id = 20
	t2.topic_type = "Provincial_Raid"
	var pool: Array[int] = [10]
	var result: Dictionary = NPCDecisionEngine._build_known_topic_types(pool, [t1, t2])
	assert_true(result.has(10))
	assert_false(result.has(20), "Topic not in pool should be excluded")


func test_topic_type_filter_levy_troops_matches_war_topic() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [1]
	ctx.known_positions = {1: 40.0}
	ctx.known_topic_types = {1: "Clan_War"}
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "LEVY_TROOPS"
	var tables: Dictionary = {
		"topic_position_alignment": {
			"LEVY_TROOPS": {
				"strong_support": 15, "strong_opposition": -10,
				"topic_types": ["Clan_War", "Provincial_Raid", "Shadowlands_Incursion", "Siege_Beginning"],
			},
		},
	}
	var result: float = NPCDecisionEngine._compute_topic_position_modifier(
		"LEVY_TROOPS", need, ctx, tables,
	)
	assert_true(result > 0.0, "War topic should produce positive modifier for LEVY_TROOPS")


func test_topic_type_filter_levy_troops_skips_famine_topic() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [1]
	ctx.known_positions = {1: 40.0}
	ctx.known_topic_types = {1: "Provincial_Famine"}
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "LEVY_TROOPS"
	var tables: Dictionary = {
		"topic_position_alignment": {
			"LEVY_TROOPS": {
				"strong_support": 15, "strong_opposition": -10,
				"topic_types": ["Clan_War", "Provincial_Raid", "Shadowlands_Incursion", "Siege_Beginning"],
			},
		},
	}
	var result: float = NPCDecisionEngine._compute_topic_position_modifier(
		"LEVY_TROOPS", need, ctx, tables,
	)
	assert_eq(result, 0.0, "Famine topic should not boost LEVY_TROOPS")


func test_topic_type_filter_empty_array_matches_all() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [1]
	ctx.known_positions = {1: 40.0}
	ctx.known_topic_types = {1: "Whatever_Type"}
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	var tables: Dictionary = {
		"topic_position_alignment": {
			"RAISE_DISPOSITION": {"strong_support": 15, "strong_opposition": -15},
		},
	}
	var result: float = NPCDecisionEngine._compute_topic_position_modifier(
		"CHARM", need, ctx, tables,
	)
	assert_true(result > 0.0, "No topic_types filter should match all topics")


func test_topic_type_filter_unknown_type_passes_through() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.known_topics = [1]
	ctx.known_positions = {1: 40.0}
	ctx.known_topic_types = {}
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "LEVY_TROOPS"
	var tables: Dictionary = {
		"topic_position_alignment": {
			"LEVY_TROOPS": {
				"strong_support": 15, "strong_opposition": -10,
				"topic_types": ["Clan_War", "Provincial_Raid"],
			},
		},
	}
	var result: float = NPCDecisionEngine._compute_topic_position_modifier(
		"LEVY_TROOPS", need, ctx, tables,
	)
	assert_true(result > 0.0, "Topic with unknown type should pass through filter")


# -- Disposition modifier tests ------------------------------------------------

func test_disposition_modifier_cooperative_friend() -> void:
	var disp: Dictionary = {10: 45}
	var result: float = NPCDecisionEngine._lookup_disposition_modifier(
		10, disp, _scoring_tables, "CHARM"
	)
	assert_eq(result, 10.0, "Friend disposition should give +10 for cooperative action")


func test_disposition_modifier_hostile_enemy() -> void:
	var disp: Dictionary = {10: -45}
	var result: float = NPCDecisionEngine._lookup_disposition_modifier(
		10, disp, _scoring_tables, "INTIMIDATE"
	)
	assert_eq(result, 10.0, "Enemy disposition should give +10 for hostile action")


func test_disposition_modifier_hostile_friend_penalizes() -> void:
	var disp: Dictionary = {10: 45}
	var result: float = NPCDecisionEngine._lookup_disposition_modifier(
		10, disp, _scoring_tables, "INTIMIDATE"
	)
	assert_eq(result, -10.0, "Friend disposition should give -10 for hostile action")


func test_disposition_modifier_provoke_emotion_is_hostile() -> void:
	var disp: Dictionary = {10: 45}
	var result: float = NPCDecisionEngine._lookup_disposition_modifier(
		10, disp, _scoring_tables, "PROVOKE_EMOTION"
	)
	assert_eq(result, -10.0, "PROVOKE_EMOTION should use hostile column")


func test_disposition_modifier_no_target() -> void:
	var disp: Dictionary = {10: 45}
	var result: float = NPCDecisionEngine._lookup_disposition_modifier(
		-1, disp, _scoring_tables, "CHARM"
	)
	assert_eq(result, 0.0, "No target should return 0")


func test_disposition_modifier_stranger_neutral() -> void:
	var disp: Dictionary = {10: 0}
	var result: float = NPCDecisionEngine._lookup_disposition_modifier(
		10, disp, _scoring_tables, "CHARM"
	)
	assert_eq(result, 0.0, "Stranger should return 0 for cooperative")


func test_disposition_modifier_devoted_cooperative() -> void:
	var disp: Dictionary = {10: 95}
	var result: float = NPCDecisionEngine._lookup_disposition_modifier(
		10, disp, _scoring_tables, "CHARM"
	)
	assert_eq(result, 25.0, "Devoted should give +25 for cooperative")


# -- Known contacts injection tests --------------------------------------------

func test_known_contacts_populated_from_character() -> void:
	_char.known_contacts_by_clan = {"Crane": [10, 11], "Lion": [20]}
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(
		_char, _world_state
	)
	assert_eq(ctx.known_contacts.size(), 3, "Should have 3 contacts total")
	assert_true(10 in ctx.known_contacts, "Contact 10 should be present")
	assert_true(11 in ctx.known_contacts, "Contact 11 should be present")
	assert_true(20 in ctx.known_contacts, "Contact 20 should be present")


func test_contact_clans_populated_from_character() -> void:
	_char.known_contacts_by_clan = {"Crane": [10], "Lion": [20]}
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(
		_char, _world_state
	)
	assert_eq(ctx.contact_clans.get(10, ""), "Crane", "Contact 10 should map to Crane")
	assert_eq(ctx.contact_clans.get(20, ""), "Lion", "Contact 20 should map to Lion")


func test_known_contacts_empty_when_no_contacts() -> void:
	_char.known_contacts_by_clan = {}
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(
		_char, _world_state
	)
	assert_eq(ctx.known_contacts.size(), 0, "Should have no contacts")
	assert_eq(ctx.contact_clans.size(), 0, "Should have no clan mappings")


func test_known_contacts_no_duplicates() -> void:
	_char.known_contacts_by_clan = {"Crane": [10], "Lion": [10]}
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(
		_char, _world_state
	)
	var count: int = 0
	for c_id: int in ctx.known_contacts:
		if c_id == 10:
			count += 1
	assert_eq(count, 1, "Contact 10 should appear only once in flat list")


# -- Competence modifier tests ------------------------------------------------

func test_competence_modifier_with_primary_skill() -> void:
	var tables: Dictionary = {
		"action_skill_map": {
			"CHARM": {"primary": "Etiquette", "secondary": "Courtier"},
		},
		"competence_table": {"0": -20, "1": -10, "2": -5, "3": 0, "4": 5, "5": 10, "6": 15, "7": 20},
	}
	var skills: Dictionary = {"Etiquette": 5, "Courtier": 3}
	var result: float = NPCDecisionEngine._compute_competence_modifier(
		"CHARM", skills, tables,
	)
	assert_almost_eq(result, 10.0, 0.01, "Rank 5 primary = +10")


func test_competence_modifier_with_secondary_half_value() -> void:
	var tables: Dictionary = {
		"action_skill_map": {
			"TEST": {"primary": "Battle", "secondary": "Etiquette"},
		},
		"competence_table": {"0": -20, "1": -10, "2": -5, "3": 0, "4": 5, "5": 10, "6": 15, "7": 20},
	}
	var skills: Dictionary = {"Battle": 3, "Etiquette": 5}
	var result: float = NPCDecisionEngine._compute_competence_modifier(
		"TEST", skills, tables,
	)
	assert_almost_eq(result, 5.0, 0.01, "Rank 3 primary (0) + rank 5 secondary (10*0.5=5)")


func test_competence_modifier_null_secondary_no_penalty() -> void:
	var tables: Dictionary = {
		"action_skill_map": {
			"INTIMIDATE": {"primary": "Intimidation", "secondary": null},
		},
		"competence_table": {"0": -20, "1": -10, "2": -5, "3": 0, "4": 5, "5": 10, "6": 15, "7": 20},
	}
	var skills: Dictionary = {"Intimidation": 4}
	var result: float = NPCDecisionEngine._compute_competence_modifier(
		"INTIMIDATE", skills, tables,
	)
	assert_almost_eq(result, 5.0, 0.01, "Rank 4 = +5, null secondary should not add penalty")


func test_competence_modifier_null_primary_returns_zero() -> void:
	var tables: Dictionary = {
		"action_skill_map": {
			"DO_NOTHING": {"primary": null, "secondary": null},
		},
		"competence_table": {"0": -20, "1": -10, "2": -5, "3": 0, "4": 5, "5": 10, "6": 15, "7": 20},
	}
	var result: float = NPCDecisionEngine._compute_competence_modifier(
		"DO_NOTHING", {}, tables,
	)
	assert_eq(result, 0.0, "Null primary should return 0")


func test_competence_modifier_unknown_action() -> void:
	var tables: Dictionary = {"action_skill_map": {}}
	var result: float = NPCDecisionEngine._compute_competence_modifier(
		"NONEXISTENT", {}, tables,
	)
	assert_eq(result, 0.0, "Unknown action should return 0")


# -- Province status rice stockpile population ---------------------------------

func test_province_status_rice_stockpile_from_settlements() -> void:
	var p := ProvinceData.new()
	p.province_id = 100
	p.clan = "Crane"
	var s1 := SettlementData.new()
	s1.settlement_id = 1
	s1.province_id = 100
	s1.rice_stockpile = 25.0
	var s2 := SettlementData.new()
	s2.settlement_id = 2
	s2.province_id = 100
	s2.rice_stockpile = 15.0
	var statuses: Array = NPCDecisionEngine.build_province_statuses_from_data(
		[p], [s1, s2],
	)
	assert_eq(statuses.size(), 1)
	assert_almost_eq(statuses[0].rice_stockpile, 40.0, 0.01, "Rice should sum settlements")


# =============================================================================
# Garrison shortage target selection (s2.4.13 Decision 10)
# =============================================================================


func _make_crab_character(id: int, bushido: Enums.BushidoVirtue, shourido: Enums.ShouridoVirtue) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.clan = "Crab"
	c.bushido_virtue = bushido
	c.shourido_virtue = shourido
	return c


func test_build_context_populates_contact_garrison_scores_when_wall_statuses_present() -> void:
	var writer := L5RCharacterData.new()
	writer.character_id = 1
	var chugi_lord := _make_crab_character(10, Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE)
	writer.known_contacts_by_clan = {"Crab": [10]}
	var ws_obj := NPCDataStructures.WallStatus.new()
	ws_obj.province_id = 5
	var world_state: Dictionary = {"wall_statuses": [ws_obj]}
	var ctx := NPCDecisionEngine.build_context(writer, world_state, {10: chugi_lord})
	assert_true(ctx.contact_garrison_scores.has(10))
	assert_almost_eq(ctx.contact_garrison_scores[10], 15.0, 0.001)


func test_build_context_empty_garrison_scores_without_wall_statuses() -> void:
	var writer := L5RCharacterData.new()
	writer.character_id = 1
	var chugi_lord := _make_crab_character(10, Enums.BushidoVirtue.CHUGI, Enums.ShouridoVirtue.NONE)
	writer.known_contacts_by_clan = {"Crab": [10]}
	var world_state: Dictionary = {"wall_statuses": []}
	var ctx := NPCDecisionEngine.build_context(writer, world_state, {10: chugi_lord})
	assert_true(ctx.contact_garrison_scores.is_empty())


func test_select_letter_target_prefers_chugi_over_seigyo_for_strengthen_wall() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.contact_garrison_scores = {10: 15.0, 20: -5.0}  # Chugi vs Seigyo
	var objectives: Dictionary = {"primary": {"need_type": "STRENGTHEN_WALL"}}
	var target: int = NPCDecisionEngine._select_letter_target(objectives, ctx)
	assert_eq(target, 10)


func test_select_letter_target_prefers_yu_over_seigyo_for_strengthen_wall() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.contact_garrison_scores = {30: 8.0, 40: -5.0}  # Yu vs Seigyo
	var objectives: Dictionary = {"primary": {"need_type": "STRENGTHEN_WALL"}}
	var target: int = NPCDecisionEngine._select_letter_target(objectives, ctx)
	assert_eq(target, 30)


func test_select_letter_target_falls_back_to_lord_id_when_no_scores() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.lord_id = 7
	ctx.contact_garrison_scores = {}
	var objectives: Dictionary = {"primary": {"need_type": "STRENGTHEN_WALL"}}
	var target: int = NPCDecisionEngine._select_letter_target(objectives, ctx)
	assert_eq(target, 7)


func test_select_letter_target_ignores_garrison_scores_for_non_strengthen_wall() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.lord_id = 7
	ctx.contact_garrison_scores = {10: 15.0}
	var objectives: Dictionary = {"primary": {"need_type": "RAISE_DISPOSITION", "target_npc_id": -1}}
	var target: int = NPCDecisionEngine._select_letter_target(objectives, ctx)
	assert_eq(target, 7)


func test_select_letter_target_explicit_npc_id_still_overrides_garrison_scores() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.contact_garrison_scores = {10: 15.0}
	var objectives: Dictionary = {"primary": {"need_type": "STRENGTHEN_WALL", "target_npc_id": 99}}
	var target: int = NPCDecisionEngine._select_letter_target(objectives, ctx)
	assert_eq(target, 99)


# -- Conditional Personality Filter Tests -----------------------------------------

func test_conditional_yu_blocks_seek_peace_when_war_score_high() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.YU
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	ctx.active_wars = [{"war_score": 30}]
	var filter: Dictionary = {
		"bushido": {
			"YU": {
				"always_blocked": ["DELAY_TO_POST_HARVEST"],
				"conditional": [
					{"action": "SEEK_PEACE", "blocked_when": "war_score_above_25_and_army_capable"},
				],
			},
		},
		"shourido": {},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var seek := NPCDataStructures.ScoredAction.new()
	seek.action_id = "SEEK_PEACE"
	options.append(seek)
	var charm := NPCDataStructures.ScoredAction.new()
	charm.action_id = "CHARM"
	options.append(charm)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 1)
	assert_eq(filtered[0].action_id, "CHARM")


func test_conditional_yu_allows_seek_peace_when_war_score_low() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.YU
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	ctx.active_wars = [{"war_score": 20}]
	var filter: Dictionary = {
		"bushido": {
			"YU": {
				"always_blocked": [],
				"conditional": [
					{"action": "SEEK_PEACE", "blocked_when": "war_score_above_25_and_army_capable"},
				],
			},
		},
		"shourido": {},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var seek := NPCDataStructures.ScoredAction.new()
	seek.action_id = "SEEK_PEACE"
	options.append(seek)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 1)
	assert_eq(filtered[0].action_id, "SEEK_PEACE")


func test_conditional_jin_blocks_demand_tribute_at_shortage() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.JIN
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	ctx.resource_stockpiles = {"province_1": {"rice_months": 2.0}}
	var filter: Dictionary = {
		"bushido": {
			"JIN": {
				"always_blocked": ["RAID_HARVEST"],
				"conditional": [
					{"action": "DEMAND_TRIBUTE", "blocked_when": "any_vassal_at_shortage_or_worse"},
				],
			},
		},
		"shourido": {},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var demand := NPCDataStructures.ScoredAction.new()
	demand.action_id = "DEMAND_TRIBUTE"
	options.append(demand)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 0)


func test_conditional_jin_allows_demand_tribute_no_shortage() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.JIN
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	ctx.resource_stockpiles = {"province_1": {"rice_months": 6.0}}
	var filter: Dictionary = {
		"bushido": {
			"JIN": {
				"always_blocked": ["RAID_HARVEST"],
				"conditional": [
					{"action": "DEMAND_TRIBUTE", "blocked_when": "any_vassal_at_shortage_or_worse"},
				],
			},
		},
		"shourido": {},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var demand := NPCDataStructures.ScoredAction.new()
	demand.action_id = "DEMAND_TRIBUTE"
	options.append(demand)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 1)


func test_conditional_kyoryoku_blocks_negotiate_when_confrontation_available() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.NONE
	ctx.shourido_virtue = Enums.ShouridoVirtue.KYORYOKU
	ctx.characters_present = [5, 6] as Array[int]
	var filter: Dictionary = {
		"bushido": {},
		"shourido": {
			"KYORYOKU": {
				"always_blocked": [],
				"conditional": [
					{"action": "NEGOTIATE", "blocked_when": "direct_confrontation_available"},
					{"action": "CHARM", "blocked_when": "direct_confrontation_available"},
					{"action": "WRITE_LETTER", "blocked_when": "direct_confrontation_available"},
				],
			},
		},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var neg := NPCDataStructures.ScoredAction.new()
	neg.action_id = "NEGOTIATE"
	options.append(neg)
	var letter := NPCDataStructures.ScoredAction.new()
	letter.action_id = "WRITE_LETTER"
	options.append(letter)
	var duel := NPCDataStructures.ScoredAction.new()
	duel.action_id = "ISSUE_DUEL_CHALLENGE"
	options.append(duel)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 1)
	assert_eq(filtered[0].action_id, "ISSUE_DUEL_CHALLENGE")


func test_conditional_ishi_blocks_change_course_when_committed() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.NONE
	ctx.shourido_virtue = Enums.ShouridoVirtue.ISHI
	ctx.action_log = [{"action_id": "ORDER_DEPLOY"}] as Array[Dictionary]
	var filter: Dictionary = {
		"bushido": {},
		"shourido": {
			"ISHI": {
				"always_blocked": ["SURRENDER"],
				"conditional": [
					{"action": "_CHANGE_COURSE", "blocked_when": "already_committed_to_action"},
					{"action": "NEGOTIATE", "blocked_when": "already_committed_to_action"},
					{"action": "SEEK_PEACE", "blocked_when": "already_committed_to_action"},
				],
			},
		},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var peace := NPCDataStructures.ScoredAction.new()
	peace.action_id = "SEEK_PEACE"
	options.append(peace)
	var abort := NPCDataStructures.ScoredAction.new()
	abort.action_id = "ABORT_RAID"
	options.append(abort)
	var attack := NPCDataStructures.ScoredAction.new()
	attack.action_id = "ORDER_BATTLE"
	options.append(attack)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 1)
	assert_eq(filtered[0].action_id, "ORDER_BATTLE")


func test_conditional_chishiki_blocks_commit_without_intel() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.NONE
	ctx.shourido_virtue = Enums.ShouridoVirtue.CHISHIKI
	ctx.action_log = [] as Array[Dictionary]
	var filter: Dictionary = {
		"bushido": {},
		"shourido": {
			"CHISHIKI": {
				"always_blocked": [],
				"conditional": [
					{"action": "_COMMIT_ACTION", "blocked_when": "no_intelligence_gathered_this_session"},
				],
			},
		},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var deploy := NPCDataStructures.ScoredAction.new()
	deploy.action_id = "ORDER_DEPLOY"
	options.append(deploy)
	var observe := NPCDataStructures.ScoredAction.new()
	observe.action_id = "GATHER_INTELLIGENCE"
	options.append(observe)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 1)
	assert_eq(filtered[0].action_id, "GATHER_INTELLIGENCE")


func test_conditional_chishiki_allows_commit_after_intel() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.NONE
	ctx.shourido_virtue = Enums.ShouridoVirtue.CHISHIKI
	ctx.action_log = [{"action_id": "GATHER_INTELLIGENCE"}] as Array[Dictionary]
	var filter: Dictionary = {
		"bushido": {},
		"shourido": {
			"CHISHIKI": {
				"always_blocked": [],
				"conditional": [
					{"action": "_COMMIT_ACTION", "blocked_when": "no_intelligence_gathered_this_session"},
				],
			},
		},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var deploy := NPCDataStructures.ScoredAction.new()
	deploy.action_id = "ORDER_DEPLOY"
	options.append(deploy)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 1)
	assert_eq(filtered[0].action_id, "ORDER_DEPLOY")


func test_conditional_ketsui_blocks_relief_army() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.NONE
	ctx.shourido_virtue = Enums.ShouridoVirtue.KETSUI
	var filter: Dictionary = {
		"bushido": {},
		"shourido": {
			"KETSUI": {
				"always_blocked": ["REQUEST_ALLIED_AID"],
				"conditional": [
					{"action": "ACCEPT_RELIEF_ARMY", "blocked_when": "creates_obligation"},
				],
			},
		},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var accept := NPCDataStructures.ScoredAction.new()
	accept.action_id = "ACCEPT_RELIEF_ARMY"
	options.append(accept)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 0)


func test_conditional_harvest_rei_blocked_without_demand() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.REI
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	ctx.action_log = [] as Array[Dictionary]
	ctx.active_wars = []
	ctx.disposition_values = {}
	ctx.pending_events = []
	var filter: Dictionary = {
		"bushido": {
			"REI": {
				"always_blocked": ["GOSSIP"],
				"conditional": [
					{"action": "RAID_HARVEST", "blocked_when": "no_prior_formal_demand"},
				],
			},
		},
		"shourido": {},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var harvest := NPCDataStructures.ScoredAction.new()
	harvest.action_id = "RAID_HARVEST"
	options.append(harvest)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 0)


func test_conditional_harvest_rei_allowed_after_demand() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.REI
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	ctx.action_log = [{"action_id": "DEMAND_TRIBUTE"}] as Array[Dictionary]
	ctx.active_wars = []
	ctx.disposition_values = {}
	ctx.pending_events = []
	var filter: Dictionary = {
		"bushido": {
			"REI": {
				"always_blocked": ["GOSSIP"],
				"conditional": [
					{"action": "RAID_HARVEST", "blocked_when": "no_prior_formal_demand"},
				],
			},
		},
		"shourido": {},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var harvest := NPCDataStructures.ScoredAction.new()
	harvest.action_id = "RAID_HARVEST"
	options.append(harvest)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 1)


func test_conditional_unevaluable_condition_does_not_block() -> void:
	var ctx := NPCDataStructures.ContextSnapshot.new()
	ctx.bushido_virtue = Enums.BushidoVirtue.MEIYO
	ctx.shourido_virtue = Enums.ShouridoVirtue.NONE
	var filter: Dictionary = {
		"bushido": {
			"MEIYO": {
				"always_blocked": [],
				"conditional": [
					{"action": "_ANY_ACTION", "blocked_when": "violates_personal_code"},
				],
			},
		},
		"shourido": {},
	}
	var options: Array[NPCDataStructures.ScoredAction] = []
	var charm := NPCDataStructures.ScoredAction.new()
	charm.action_id = "CHARM"
	options.append(charm)
	var filtered := NPCDecisionEngine.apply_personality_filter(options, ctx, filter)
	assert_eq(filtered.size(), 1, "Unevaluable conditions should not block")


# -- Extortion Opportunity Decomposition ---

func test_extortion_opportunity_decomposes_to_extort_accused() -> void:
	_world_state["pending_events"] = [
		{"type": "extortion_opportunity", "case_id": 9, "suspect_id": 42, "evidence_total": 30}
	]
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, _objectives)
	assert_eq(need.need_type, "EXTORT_ACCUSED")
	assert_eq(need.target_npc_id, 42)
	assert_eq(need.source, "extortion_opportunity")
	assert_eq(int(need.threshold), 30)


func test_seppuku_offered_reactive_event_decomposition() -> void:
	_world_state["pending_events"] = [
		{"type": "seppuku_offered", "case_id": 15, "crime_type": 5, "ic_day_offered": 50}
	]
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, _objectives)
	assert_eq(need.need_type, "RESPOND_TO_SEPPUKU")
	assert_eq(need.priority, 1)
	assert_eq(need.source, "seppuku_offered")
	assert_eq(need.target_intent, "case_15")


func test_seppuku_generates_accept_refuse_options() -> void:
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RESPOND_TO_SEPPUKU"
	need.priority = 1
	need.source = "seppuku_offered"
	need.target_intent = "case_15"

	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(ctx, need)

	var action_ids: Array[String] = []
	for opt: NPCDataStructures.ScoredAction in options:
		action_ids.append(opt.action_id)
	assert_true("ACCEPT_SEPPUKU" in action_ids)
	assert_true("REFUSE_SEPPUKU" in action_ids)
	assert_eq(action_ids.size(), 2)


func test_witness_report_motivated_reactive_event() -> void:
	_world_state["pending_events"] = [
		{"type": "witness_report_motivated", "criminal_id": 99, "case_id": 42, "magistrate_id": 30}
	]
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, _objectives)
	assert_eq(need.need_type, "SEEK_MAGISTRATE")
	assert_eq(need.priority, 2)
	assert_eq(need.source, "witness_report_motivated")
	assert_eq(need.target_npc_id, 30)
	assert_eq(need.target_npc_id_secondary, 99)
	assert_eq(need.target_intent, "case_42")


func test_provocation_reactive_event() -> void:
	_world_state["pending_events"] = [
		{"type": "provocation", "source_id": 5, "case_id": 10, "action": "INTIMIDATE_WITNESS"}
	]
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, _objectives)
	assert_eq(need.need_type, "REST")
	assert_eq(need.priority, 3)
	assert_eq(need.source, "provocation_received")
	assert_eq(need.target_npc_id, 5)


# =============================================================================
# RECOVER_VOID_POINTS (s57.32.5)
# =============================================================================

func test_recover_void_fallback_when_pool_empty_no_objectives() -> void:
	# No primary or standing objectives → void recovery fires as fallback.
	_char.current_void_points = 0
	_char.max_void_points = 2
	_char.void_ring = 2
	_char.skills["Meditation"] = 2
	_world_state["context_flag"] = Enums.ContextFlag.AT_OWN_HOLDINGS
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, {})
	assert_eq(need.need_type, "RECOVER_VOID_POINTS")
	assert_eq(need.source, "void_depleted")


func test_recover_void_does_not_override_primary_objective() -> void:
	# Primary objective still wins even when pool is empty.
	_char.current_void_points = 0
	_char.max_void_points = 2
	_char.void_ring = 2
	_char.skills["Meditation"] = 2
	_world_state["context_flag"] = Enums.ContextFlag.AT_OWN_HOLDINGS
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, _objectives)
	# Primary RAISE_DISPOSITION objective should still win.
	assert_eq(need.need_type, "RAISE_DISPOSITION")


func test_recover_void_silent_when_pool_not_empty() -> void:
	_char.current_void_points = 1
	_char.max_void_points = 2
	_char.void_ring = 2
	_char.skills["Meditation"] = 2
	_world_state["context_flag"] = Enums.ContextFlag.AT_OWN_HOLDINGS
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, {})
	# Fallback should be REST, not RECOVER_VOID_POINTS.
	assert_eq(need.need_type, "REST")


func test_recover_void_silent_when_meditate_not_in_context() -> void:
	# ON_CAMPAIGN blocks MEDITATE — RECOVER_VOID_POINTS should not fire.
	_char.current_void_points = 0
	_char.max_void_points = 2
	_char.void_ring = 2
	_char.skills["Meditation"] = 2
	_world_state["context_flag"] = Enums.ContextFlag.ON_CAMPAIGN
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var need := NPCDecisionEngine.resolve_goal(_char, ctx, {})
	assert_eq(need.need_type, "REST")


# =============================================================================
# TEND_WOUNDED_ALLY opportunity injection (s57.31.7)
# =============================================================================

func test_tend_wounded_ally_injected_when_conditions_met() -> void:
	var healer := _char
	healer.skills["Medicine"] = 2
	healer.items = [{"item_type": "medicine_kit", "remaining_uses": 5, "acquired_ic_day": 1}]
	healer.disposition_values = {10: 30}  # Friend.

	var wounded := L5RCharacterData.new()
	wounded.character_id = 10
	wounded.stamina = 3
	wounded.wounds_taken = 15
	wounded.last_medicine_treatment_ic_day = -1

	_world_state["characters_present"] = [10] as Array[int]
	_world_state["context_flag"] = Enums.ContextFlag.AT_OWN_HOLDINGS

	var chars_by_id: Dictionary = {1: healer, 10: wounded}
	var ctx := NPCDecisionEngine.build_context(healer, _world_state, chars_by_id)
	var need := NPCDecisionEngine.resolve_goal(healer, ctx, {})
	assert_eq(need.need_type, "TEND_WOUNDED_ALLY")
	assert_eq(need.target_npc_id, 10)


func test_tend_wounded_ally_not_injected_without_kit() -> void:
	var healer := _char
	healer.skills["Medicine"] = 2
	healer.items = []  # No kit.
	healer.disposition_values = {10: 30}

	var wounded := L5RCharacterData.new()
	wounded.character_id = 10
	wounded.wounds_taken = 15
	wounded.last_medicine_treatment_ic_day = -1

	_world_state["characters_present"] = [10] as Array[int]
	var chars_by_id: Dictionary = {1: healer, 10: wounded}
	var ctx := NPCDecisionEngine.build_context(healer, _world_state, chars_by_id)
	# Without kit, no TEND_WOUNDED_ALLY — falls through to objectives.
	var pending: Array = ctx.pending_events
	for ev: Variant in pending:
		if ev is Dictionary and (ev as Dictionary).get("type", "") == "tend_wounded_ally_opportunity":
			fail_test("Should not inject tend_wounded_ally_opportunity without kit")
			return


func test_tend_wounded_ally_not_injected_for_hostile() -> void:
	var healer := _char
	healer.skills["Medicine"] = 2
	healer.items = [{"item_type": "medicine_kit", "remaining_uses": 5, "acquired_ic_day": 1}]
	healer.disposition_values = {10: -20}  # Rival — hostile.

	var wounded := L5RCharacterData.new()
	wounded.character_id = 10
	wounded.wounds_taken = 15
	wounded.last_medicine_treatment_ic_day = -1

	_world_state["characters_present"] = [10] as Array[int]
	var chars_by_id: Dictionary = {1: healer, 10: wounded}
	var ctx := NPCDecisionEngine.build_context(healer, _world_state, chars_by_id)
	for ev: Variant in ctx.pending_events:
		if ev is Dictionary and (ev as Dictionary).get("type", "") == "tend_wounded_ally_opportunity":
			fail_test("Should not inject tend_wounded_ally_opportunity for hostile target")
			return


# -- Honor Covert Penalty (s12.8 Filter 2) ------------------------------------

func test_honor_covert_penalty_low_honor_no_penalty() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(1.5, "Bayushi Bushi", "Scorpion")
	assert_eq(penalty, 0.0, "Honor < 2.0 should produce no penalty")


func test_honor_covert_penalty_mid_honor_moderate() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(3.0, "Doji Courtier", "Crane")
	assert_eq(penalty, -25.0, "Honor 2.0-3.5 should produce -25 penalty")


func test_honor_covert_penalty_high_honor_severe() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(5.0, "Akodo Bushi", "Lion")
	assert_eq(penalty, -50.0, "Honor > 3.5 should produce -50 penalty")


func test_honor_covert_penalty_boundary_2_0() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(2.0, "Doji Courtier", "Crane")
	assert_eq(penalty, -25.0, "Honor exactly 2.0 should hit moderate tier")


func test_honor_covert_penalty_boundary_3_5() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(3.5, "Doji Courtier", "Crane")
	assert_eq(penalty, -25.0, "Honor exactly 3.5 should still be moderate tier")


func test_honor_covert_penalty_boundary_3_6() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(3.6, "Doji Courtier", "Crane")
	assert_eq(penalty, -50.0, "Honor 3.6 should hit severe tier")


func test_honor_covert_full_exempt_shosuro_infiltrator() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(5.0, "Shosuro Infiltrator", "Scorpion")
	assert_eq(penalty, 0.0, "Shosuro Infiltrator gets full exemption")


func test_honor_covert_full_exempt_bitter_lies() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(4.0, "Bitter Lies Swordsman", "Scorpion")
	assert_eq(penalty, 0.0, "Bitter Lies gets full exemption")


func test_honor_covert_full_exempt_kasuga_smuggler() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(4.0, "Kasuga Smuggler", "Tortoise")
	assert_eq(penalty, 0.0, "Kasuga Smuggler gets full exemption")


func test_honor_covert_half_exempt_daidoji_harrier() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(5.0, "Daidoji Harrier", "Crane")
	assert_eq(penalty, -25.0, "Daidoji Harrier gets half of -50")


func test_honor_covert_half_exempt_ikoma_lions_shadow() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(5.0, "Ikoma Lion's Shadow", "Lion")
	assert_eq(penalty, -25.0, "Ikoma Lion's Shadow gets half of -50")


func test_honor_covert_half_exempt_daidoji_spymaster() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(3.0, "Daidoji Spymaster", "Crane")
	assert_eq(penalty, -12.5, "Daidoji Spymaster gets half of -25 at mid honor")


func test_honor_covert_scorpion_clan_half_exempt() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(5.0, "Bayushi Bushi", "Scorpion")
	assert_eq(penalty, -25.0, "Scorpion clan gets half of -50 via Reduced Honour Bleed")


func test_honor_covert_scorpion_mid_honor() -> void:
	var penalty: float = NPCDecisionEngine._compute_honor_covert_penalty(3.0, "Soshi Shugenja", "Scorpion")
	assert_eq(penalty, -12.5, "Scorpion at mid honor gets half of -25")


func test_honor_covert_penalty_applied_to_covert_action_in_scoring() -> void:
	_char.honor = 5.0
	_char.clan = "Lion"
	_char.school = "Akodo Bushi"
	_scoring_tables["objective_alignment"]["RAISE_DISPOSITION"]["SHADOW_TARGET"] = 70
	_scoring_tables["action_skill_map"]["SHADOW_TARGET"] = {"primary": "Stealth", "secondary": "Agility"}
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "SHADOW_TARGET"
	option.target_npc_id = 2
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.honor_covert_penalty, -50.0, "High-honor Lion should get -50 on covert action")


func test_honor_covert_penalty_not_applied_to_non_covert() -> void:
	_char.honor = 5.0
	_char.clan = "Lion"
	_char.school = "Akodo Bushi"
	var ctx := NPCDecisionEngine.build_context(_char, _world_state)
	var option := NPCDataStructures.ScoredAction.new()
	option.action_id = "CHARM"
	option.target_npc_id = 2
	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "RAISE_DISPOSITION"
	NPCDecisionEngine.score_all([option], need, ctx, _scoring_tables)
	assert_eq(option.honor_covert_penalty, 0.0, "Non-covert CHARM should have no honor penalty")
