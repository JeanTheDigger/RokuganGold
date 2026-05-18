extends GutTest
## Tests for DISCERN_NEED NPC wiring (s29.15.24).
## Covers: context list inclusion, school lean scoring, stale intel bonus,
## info_type propagation through EffectApplicator, and knowledge write-back
## in DayOrchestrator._process_info_events.


var _char: L5RCharacterData
var _target: L5RCharacterData
var _scoring_tables: Dictionary


func before_each() -> void:
	_char = _make_character(1, "Test Actor", "Crab", "Yasuki", "Yasuki Courtier")
	_target = _make_character(2, "Test Target", "Crane", "Doji", "Doji Courtier")
	_scoring_tables = {
		"objective_alignment": {
			"GATHER_INTELLIGENCE": {
				"DISCERN_NEED": 85,
				"PROBE": 70,
				"READ_CHARACTER": 60,
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
			"REI": {"DISCERN_NEED": 5, "PROBE": 0},
		},
		"action_skill_map": {
			"DISCERN_NEED": {"primary": "Investigation", "secondary": "Awareness"},
			"PROBE": {"primary": "Investigation", "secondary": "Awareness"},
		},
		"urgency_rules": [],
		"topic_position_alignment": {},
	}


func _make_character(
	id: int, cname: String, clan: String, family: String, school: String,
) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = cname
	c.clan = clan
	c.family = family
	c.school = school
	c.school_type = Enums.SchoolType.COURTIER
	c.awareness = 3
	c.perception = 3
	c.intelligence = 2
	c.reflexes = 2
	c.agility = 2
	c.honor = 5.0
	c.glory = 3.0
	c.status = 4.0
	c.skills = {"Courtier": 3, "Etiquette": 3, "Commerce": 2, "Investigation": 2}
	c.emphases = {}
	c.bushido_virtue = Enums.BushidoVirtue.REI
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	c.self_reroll = []
	c.granted_reroll = []
	c.knowledge_pool = []
	c.disposition_values = {}
	c.met_characters = []
	c.topic_pool = []
	c.topic_positions = {}
	ActionPointSystem.reset_daily_ap(c)
	return c


func _build_world_state(context_flag: Enums.ContextFlag) -> Dictionary:
	return {
		"context_flag": context_flag,
		"season": 1,
		"ic_day": 10,
		"characters_present": [2] as Array[int],
		"is_lord": false,
		"known_topics": [] as Array[int],
		"known_positions": {},
		"known_objectives": {},
		"known_contacts": [] as Array[int],
		"pending_events": [],
		"action_log": [] as Array[String],
	}


# -- Context List Inclusion ----------------------------------------------------

func test_discern_need_in_at_court_context() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.AT_COURT
	)
	assert_true("DISCERN_NEED" in actions)


func test_discern_need_in_visiting_context() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.VISITING
	)
	assert_true("DISCERN_NEED" in actions)


func test_discern_need_not_in_traveling_context() -> void:
	var actions: Array[String] = NPCDecisionEngine._get_actions_for_context(
		Enums.ContextFlag.TRAVELING
	)
	assert_false("DISCERN_NEED" in actions)


# -- School Lean Scoring -------------------------------------------------------

func test_yasuki_school_lean_boosts_discern_need() -> void:
	var ws: Dictionary = _build_world_state(Enums.ContextFlag.AT_COURT)
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(_char, ws)

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "GATHER_INTELLIGENCE"
	need.target_npc_id = 2

	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need
	)

	NPCDecisionEngine.score_all(options, need, ctx, _scoring_tables)

	var discern_opt: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DISCERN_NEED":
			discern_opt = opt

	assert_not_null(discern_opt, "DISCERN_NEED should be generated as an option")
	if discern_opt != null:
		assert_gt(discern_opt.disposition_modifier, 0.0,
			"Yasuki should get positive school lean for DISCERN_NEED")


func test_doji_courtier_school_lean_boosts_discern_need() -> void:
	var doji: L5RCharacterData = _make_character(
		3, "Doji Actor", "Crane", "Doji", "Doji Courtier"
	)
	var ws: Dictionary = _build_world_state(Enums.ContextFlag.AT_COURT)
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(doji, ws)

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "GATHER_INTELLIGENCE"
	need.target_npc_id = 2

	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need
	)

	NPCDecisionEngine.score_all(options, need, ctx, _scoring_tables)

	var discern_opt: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DISCERN_NEED":
			discern_opt = opt

	assert_not_null(discern_opt)
	if discern_opt != null:
		assert_gt(discern_opt.disposition_modifier, 0.0,
			"Doji Courtier should get positive school lean for DISCERN_NEED")


func test_non_courtier_school_no_lean() -> void:
	var bushi: L5RCharacterData = _make_character(
		4, "Hida Bushi", "Crab", "Hida", "Hida Bushi"
	)
	bushi.school_type = Enums.SchoolType.BUSHI
	var ws: Dictionary = _build_world_state(Enums.ContextFlag.AT_COURT)
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(bushi, ws)

	var need := NPCDataStructures.ImmediateNeed.new()
	need.need_type = "GATHER_INTELLIGENCE"
	need.target_npc_id = 2

	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(
		ctx, need
	)

	NPCDecisionEngine.score_all(options, need, ctx, _scoring_tables)

	var discern_opt: NPCDataStructures.ScoredAction = null
	for opt: NPCDataStructures.ScoredAction in options:
		if opt.action_id == "DISCERN_NEED":
			discern_opt = opt

	if discern_opt != null:
		assert_eq(discern_opt.disposition_modifier, 0.0,
			"Non-courtier school should get no school lean for DISCERN_NEED")


# -- Stale Intel Bonus ---------------------------------------------------------

func test_discern_need_in_gather_intelligence_actions() -> void:
	assert_true(
		"DISCERN_NEED" in NPCDecisionEngine.GATHER_INTELLIGENCE_ACTIONS,
		"DISCERN_NEED should be in GATHER_INTELLIGENCE_ACTIONS for stale intel bonus"
	)


# -- EffectApplicator: info_type propagation -----------------------------------

func test_effect_applicator_passes_info_type() -> void:
	var result: Dictionary = {
		"success": true,
		"action_id": "DISCERN_NEED",
		"character_id": 1,
		"target_npc_id": 2,
		"target_province_id": -1,
		"ic_day": 10,
		"effects": {
			"info_gained": true,
			"info_type": "priority_objective",
		},
	}
	var characters: Dictionary = {1: _char, 2: _target}
	var provinces: Dictionary = {}
	var action_log: Array[Dictionary] = []

	var applied: Dictionary = EffectApplicator.apply(
		result, characters, provinces, action_log
	)

	var events: Array = applied.get("info_events", [])
	assert_eq(events.size(), 1)
	if events.size() > 0:
		assert_eq(events[0].get("info_type", ""), "priority_objective")
		assert_eq(events[0].get("action_id", ""), "DISCERN_NEED")


func test_effect_applicator_default_info_type_empty() -> void:
	var result: Dictionary = {
		"success": true,
		"action_id": "PROBE",
		"character_id": 1,
		"target_npc_id": 2,
		"target_province_id": -1,
		"ic_day": 10,
		"effects": {
			"info_gained": true,
		},
	}
	var characters: Dictionary = {1: _char, 2: _target}
	var provinces: Dictionary = {}
	var action_log: Array[Dictionary] = []

	var applied: Dictionary = EffectApplicator.apply(
		result, characters, provinces, action_log
	)

	var events: Array = applied.get("info_events", [])
	assert_eq(events.size(), 1)
	if events.size() > 0:
		assert_eq(events[0].get("info_type", ""), "")


# -- Knowledge Write-Back (DayOrchestrator) ------------------------------------

func test_discern_need_writes_priority_objective_to_knowledge() -> void:
	var applied_list: Array = [{
		"info_events": [{
			"character_id": 1,
			"action_id": "DISCERN_NEED",
			"target_npc_id": 2,
			"target_province_id": -1,
			"ic_day": 10,
			"quality": 1,
			"info_type": "priority_objective",
		}],
	}]
	var characters_by_id: Dictionary = {1: _char, 2: _target}
	var action_log: Array[Dictionary] = []
	var objectives_map: Dictionary = {
		2: {"standing": {"need_type": "RAISE_DISPOSITION", "priority": 2}},
	}

	var results: Array[Dictionary] = DayOrchestrator._process_info_events(
		applied_list, characters_by_id, action_log, 1, [], objectives_map,
	)

	assert_eq(_char.knowledge_pool.size(), 1)
	if _char.knowledge_pool.size() > 0:
		var entry: KnowledgeEntry = _char.knowledge_pool[0]
		assert_eq(entry.entry_type, "priority_objective")
		assert_eq(entry.source, Enums.KnowledgeSource.INTELLIGENCE)
		assert_eq(entry.data.get("target_character_id", -1), 2)
		assert_eq(entry.data.get("need_type", ""), "RAISE_DISPOSITION")

	assert_eq(results.size(), 1)
	if results.size() > 0:
		assert_eq(results[0].get("info_type", ""), "priority_objective")
		assert_eq(results[0].get("entries_discovered", 0), 1)


func test_discern_need_no_objective_writes_empty() -> void:
	var applied_list: Array = [{
		"info_events": [{
			"character_id": 1,
			"action_id": "DISCERN_NEED",
			"target_npc_id": 2,
			"target_province_id": -1,
			"ic_day": 10,
			"quality": 1,
			"info_type": "priority_objective",
		}],
	}]
	var characters_by_id: Dictionary = {1: _char, 2: _target}
	var action_log: Array[Dictionary] = []
	var objectives_map: Dictionary = {2: {}}

	var results: Array[Dictionary] = DayOrchestrator._process_info_events(
		applied_list, characters_by_id, action_log, 1, [], objectives_map,
	)

	assert_eq(_char.knowledge_pool.size(), 0)
	assert_eq(results.size(), 1)
	if results.size() > 0:
		assert_eq(results[0].get("entries_discovered", 0), 0)


func test_probe_info_event_still_uses_action_log_path() -> void:
	var applied_list: Array = [{
		"info_events": [{
			"character_id": 1,
			"action_id": "PROBE",
			"target_npc_id": 2,
			"target_province_id": -1,
			"ic_day": 10,
			"quality": 1,
			"info_type": "",
		}],
	}]
	var action_log: Array[Dictionary] = [{
		"character_id": 2,
		"action_id": "CHARM",
		"target_npc_id": 3,
		"ic_day": 9,
		"success": true,
	}]
	var characters_by_id: Dictionary = {1: _char, 2: _target}

	var results: Array[Dictionary] = DayOrchestrator._process_info_events(
		applied_list, characters_by_id, action_log, 1,
	)

	assert_gt(_char.knowledge_pool.size(), 0,
		"PROBE should still write observed_action entries via action log path")


# -- Primary Objective Self-Selection Write-Back --------------------------------

func test_self_select_directive_writes_primary_objective() -> void:
	var objectives_map: Dictionary = {1: {"standing": {"need_type": "SEEK_GLORY"}}}
	var characters_by_id: Dictionary = {1: _char}
	var strategic_results: Array[Dictionary] = [{
		"directive": StrategicReview.Directive.REASSIGN_VASSAL_OBJECTIVE,
		"lord_id": 1,
		"vassal_id": 1,
		"decision": "SELF_SELECT",
		"new_objective": {
			"need_type": "BREAK_ALLIANCE",
			"objective_type": "BREAK_ALLIANCE",
			"target_fields": {"target_clan": "Lion"},
			"source": "SELF_SELECTED",
		},
	}]

	DayOrchestrator._process_vassal_reassignments(
		strategic_results, objectives_map, characters_by_id,
	)

	var primary: Dictionary = objectives_map[1].get("primary", {})
	assert_false(primary.is_empty(), "SELF_SELECT should write primary objective")
	assert_eq(primary.get("need_type", ""), "BREAK_ALLIANCE")
	assert_eq(primary.get("status", ""), "ACTIVE")
	assert_eq(primary.get("source", ""), "SELF_SELECTED")


func test_self_select_does_not_overwrite_standing() -> void:
	var objectives_map: Dictionary = {1: {"standing": {"need_type": "SEEK_GLORY"}}}
	var characters_by_id: Dictionary = {1: _char}
	var strategic_results: Array[Dictionary] = [{
		"directive": StrategicReview.Directive.REASSIGN_VASSAL_OBJECTIVE,
		"lord_id": 1,
		"vassal_id": 1,
		"decision": "SELF_SELECT",
		"new_objective": {
			"need_type": "CONQUER_PROVINCE",
			"objective_type": "CONQUER_PROVINCE",
			"target_fields": {},
			"source": "SELF_SELECTED",
		},
	}]

	DayOrchestrator._process_vassal_reassignments(
		strategic_results, objectives_map, characters_by_id,
	)

	var standing: Dictionary = objectives_map[1].get("standing", {})
	assert_eq(standing.get("need_type", ""), "SEEK_GLORY",
		"SELF_SELECT should not touch standing objective")
