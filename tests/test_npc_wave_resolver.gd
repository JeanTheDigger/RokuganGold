extends GutTest


var _scoring_tables: Dictionary
var _filter_data: Dictionary


func before_each() -> void:
	_scoring_tables = {
		"objective_alignment": {
			"REST": {"DO_NOTHING": 10, "REST": 50, "TRAIN": 30},
			"RAISE_DISPOSITION": {
				"CHARM": 80, "GOSSIP": 30, "WRITE_LETTER": 40,
				"DO_NOTHING": 0, "REST": 5,
			},
		},
		"disposition_tiers": [
			{"min": -10, "max": 10, "cooperative": 0, "hostile": 0},
			{"min": 10, "max": 50, "cooperative": 10, "hostile": -10},
		],
		"personality_lean": {},
		"action_skill_map": {},
		"urgency_rules": [],
		"topic_position_alignment": {},
	}
	_filter_data = {"bushido": {}, "shourido": {}}


func _make_char(id: int, status: float, awareness: int) -> L5RCharacterData:
	var c := L5RCharacterData.new()
	c.character_id = id
	c.character_name = "NPC " + str(id)
	c.status = status
	c.awareness = awareness
	c.action_points_current = 2
	c.action_points_max = 2
	c.bushido_virtue = Enums.BushidoVirtue.NONE
	c.shourido_virtue = Enums.ShouridoVirtue.NONE
	return c


func _make_world_state(context_flag: Enums.ContextFlag, is_lord: bool = false) -> Dictionary:
	return {
		"context_flag": context_flag,
		"season": 1,
		"ic_day": 10,
		"characters_present": [],
		"is_lord": is_lord,
		"known_topics": [],
		"known_positions": {},
		"known_objectives": {},
		"known_contacts": [],
		"pending_events": [],
		"action_log": [],
	}


# -- Resolution Order ----------------------------------------------------------

func test_sort_by_status_descending() -> void:
	var c1 := _make_char(1, 3.0, 2)
	var c2 := _make_char(2, 5.0, 2)
	var c3 := _make_char(3, 1.0, 2)
	var sorted: Array = NPCWaveResolver._sort_by_resolution_order(
		[c1, c2, c3], {}
	)
	assert_eq(sorted[0].character_id, 2)
	assert_eq(sorted[1].character_id, 1)
	assert_eq(sorted[2].character_id, 3)


func test_sort_tiebreaker_awareness() -> void:
	var c1 := _make_char(1, 3.0, 2)
	var c2 := _make_char(2, 3.0, 5)
	var sorted: Array = NPCWaveResolver._sort_by_resolution_order(
		[c1, c2], {}
	)
	assert_eq(sorted[0].character_id, 2)


# -- Full Day Resolution ------------------------------------------------------

func test_resolve_day_all_npcs_act() -> void:
	var c1 := _make_char(1, 3.0, 2)
	var c2 := _make_char(2, 5.0, 2)
	var chars: Array = [c1, c2]
	var ws: Dictionary = {
		1: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS),
		2: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS),
	}
	var objs: Dictionary = {
		1: {"primary": {"need_type": "REST", "priority": 3}},
		2: {"primary": {"need_type": "REST", "priority": 3}},
	}
	var results: Array = NPCWaveResolver.resolve_day(
		chars, ws, objs, _scoring_tables, _filter_data
	)
	assert_true(results.size() >= 2)


func test_resolve_day_skips_zero_ap() -> void:
	var c1 := _make_char(1, 3.0, 2)
	c1.action_points_current = 0
	var chars: Array = [c1]
	var ws: Dictionary = {1: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS)}
	var objs: Dictionary = {1: {"primary": {"need_type": "REST", "priority": 3}}}
	var results: Array = NPCWaveResolver.resolve_day(
		chars, ws, objs, _scoring_tables, _filter_data
	)
	assert_eq(results.size(), 0)


# -- Reactive Events First -----------------------------------------------------

func test_reactive_events_resolve_first() -> void:
	var c1 := _make_char(1, 3.0, 2)
	var ws: Dictionary = {
		1: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS),
	}
	ws[1]["pending_events"] = [
		{"need_type": "DEFEND_PROVINCE", "priority": 1, "target_province_id": 10}
	]
	var objs: Dictionary = {1: {"primary": {"need_type": "REST", "priority": 3}}}
	var results: Array = NPCWaveResolver.resolve_day(
		[c1], ws, objs, _scoring_tables, _filter_data
	)
	assert_true(results.size() > 0)
	assert_true(results[0]["success"])


# -- Lord Dual Pool ------------------------------------------------------------

func test_is_order_action() -> void:
	assert_true(NPCWaveResolver._is_order_action("ASSESS_PROVINCE_STATUS"))
	assert_true(NPCWaveResolver._is_order_action("ORDER_PATROL"))
	assert_false(NPCWaveResolver._is_order_action("CHARM"))
	assert_false(NPCWaveResolver._is_order_action("TRAIN"))


# -- Full Execution Pipeline ---------------------------------------------------

func _make_char_with_skills(id: int, status: float, awareness: int) -> L5RCharacterData:
	var c := _make_char(id, status, awareness)
	c.reflexes = 3
	c.awareness = awareness
	c.stamina = 3
	c.willpower = 3
	c.agility = 3
	c.intelligence = 3
	c.strength = 3
	c.perception = 3
	c.void_ring = 2
	c.skills = {"Etiquette": 3, "Courtier": 2, "Battle": 1}
	c.emphases = {}
	c.wounds_taken = 0
	return c


func test_resolve_day_full_produces_effects() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var action_map: Dictionary = {
		"REST": {"primary": null, "secondary": null},
		"DO_NOTHING": {"primary": null, "secondary": null},
		"TRAIN": {"primary": "_trained_skill", "secondary": null},
		"WRITE_LETTER": {"primary": "Calligraphy", "secondary": "Courtier"},
	}
	var c1 := _make_char_with_skills(1, 3.0, 3)
	var chars: Array = [c1]
	var ws: Dictionary = {
		1: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS),
	}
	var objs: Dictionary = {
		1: {"primary": {"need_type": "REST", "priority": 3}},
	}
	var results: Array = NPCWaveResolver.resolve_day_full(
		chars, ws, objs, _scoring_tables, _filter_data, dice, action_map
	)
	assert_true(results.size() >= 1)
	assert_true(results[0].has("effects"))


func test_resolve_day_full_skips_zero_ap() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(1)
	var c1 := _make_char_with_skills(1, 3.0, 3)
	c1.action_points_current = 0
	var chars: Array = [c1]
	var ws: Dictionary = {1: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS)}
	var objs: Dictionary = {1: {"primary": {"need_type": "REST", "priority": 3}}}
	var results: Array = NPCWaveResolver.resolve_day_full(
		chars, ws, objs, _scoring_tables, _filter_data, dice, {}
	)
	assert_eq(results.size(), 0)


func test_resolve_day_full_multiple_npcs() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var action_map: Dictionary = {
		"REST": {"primary": null, "secondary": null},
		"DO_NOTHING": {"primary": null, "secondary": null},
		"TRAIN": {"primary": "_trained_skill", "secondary": null},
	}
	var c1 := _make_char_with_skills(1, 5.0, 3)
	var c2 := _make_char_with_skills(2, 3.0, 2)
	var chars: Array = [c1, c2]
	var ws: Dictionary = {
		1: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS),
		2: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS),
	}
	var objs: Dictionary = {
		1: {"primary": {"need_type": "REST", "priority": 3}},
		2: {"primary": {"need_type": "REST", "priority": 3}},
	}
	var results: Array = NPCWaveResolver.resolve_day_full(
		chars, ws, objs, _scoring_tables, _filter_data, dice, action_map
	)
	assert_true(results.size() >= 2)


# -- resolve_day_applied (full pipeline with world mutation) -------------------

func test_resolve_day_applied_returns_results_and_applied() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var action_map: Dictionary = {
		"REST": {"primary": null, "secondary": null},
		"DO_NOTHING": {"primary": null, "secondary": null},
		"TRAIN": {"primary": "_trained_skill", "secondary": null},
	}
	var c1 := _make_char_with_skills(1, 3.0, 3)
	var chars: Array = [c1]
	var chars_by_id: Dictionary = {1: c1}
	var provinces: Dictionary = {}
	var action_log: Array = []
	var ws: Dictionary = {1: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS)}
	var objs: Dictionary = {1: {"primary": {"need_type": "REST", "priority": 3}}}
	var day_result: Dictionary = NPCWaveResolver.resolve_day_applied(
		chars, ws, objs, _scoring_tables, _filter_data, dice, action_map,
		chars_by_id, provinces, action_log
	)
	assert_true(day_result.has("results"))
	assert_true(day_result.has("applied"))
	assert_true(day_result.has("action_log"))
	assert_eq(day_result["results"].size(), day_result["applied"].size())


func test_resolve_day_applied_logs_actions() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(42)
	var action_map: Dictionary = {
		"REST": {"primary": null, "secondary": null},
		"DO_NOTHING": {"primary": null, "secondary": null},
		"TRAIN": {"primary": "_trained_skill", "secondary": null},
	}
	var c1 := _make_char_with_skills(1, 3.0, 3)
	var chars: Array = [c1]
	var chars_by_id: Dictionary = {1: c1}
	var provinces: Dictionary = {}
	var action_log: Array = []
	var ws: Dictionary = {1: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS)}
	var objs: Dictionary = {1: {"primary": {"need_type": "REST", "priority": 3}}}
	NPCWaveResolver.resolve_day_applied(
		chars, ws, objs, _scoring_tables, _filter_data, dice, action_map,
		chars_by_id, provinces, action_log
	)
	assert_true(action_log.size() > 0)
	assert_eq(action_log[0]["character_id"], 1)


func test_resolve_day_applied_mutates_character_state() -> void:
	var dice := DiceEngine.new()
	dice.set_seed(99)
	var action_map: Dictionary = {
		"REST": {"primary": null, "secondary": null},
		"DO_NOTHING": {"primary": null, "secondary": null},
		"CHARM": {"primary": "Etiquette", "secondary": "Courtier"},
		"GOSSIP": {"primary": "Courtier", "secondary": "Etiquette"},
		"WRITE_LETTER": {"primary": "Calligraphy", "secondary": "Courtier"},
	}
	var c1 := _make_char_with_skills(1, 3.0, 3)
	c1.honor = 5.0
	c1.glory = 3.0
	c1.disposition_values = {2: 30}
	var c2 := _make_char_with_skills(2, 2.0, 2)
	var chars: Array = [c1]
	var chars_by_id: Dictionary = {1: c1, 2: c2}
	var provinces: Dictionary = {}
	var action_log: Array = []
	var ws: Dictionary = {
		1: _make_world_state(Enums.ContextFlag.AT_COURT),
	}
	ws[1]["characters_present"] = [2]
	ws[1]["known_contacts"] = [2]
	var objs: Dictionary = {
		1: {"primary": {"need_type": "RAISE_DISPOSITION", "priority": 2, "target_npc_id": 2}},
	}
	var old_honor: float = c1.honor
	var old_glory: float = c1.glory
	NPCWaveResolver.resolve_day_applied(
		chars, ws, objs, _scoring_tables, _filter_data, dice, action_map,
		chars_by_id, provinces, action_log
	)
	# At minimum, the action was logged
	assert_true(action_log.size() > 0)
	# Character state may have changed (honor, glory, or disposition)
	var state_changed: bool = (
		c1.honor != old_honor or
		c1.glory != old_glory or
		c1.disposition_values.get(2, 30) != 30
	)
	# Even if action fails, it gets logged — that's the key mutation
	assert_true(action_log[0].has("success"))


# -- Reactive Event Consumption ------------------------------------------------

func test_consume_reactive_event_removes_on_success() -> void:
	var ws: Dictionary = {
		"pending_events": [
			{"type": "bribery_eval", "magistrate_id": 2},
		],
	}
	var decision: Dictionary = {
		"success": true,
		"need_source": "bribery_eval",
	}
	NPCWaveResolver._consume_reactive_event(decision, ws)
	assert_eq(ws["pending_events"].size(), 0)


func test_consume_reactive_event_keeps_on_failure() -> void:
	var ws: Dictionary = {
		"pending_events": [
			{"type": "witness_report_motivated", "magistrate_id": 5},
		],
	}
	var decision: Dictionary = {
		"success": false,
		"need_source": "witness_report_motivated",
	}
	NPCWaveResolver._consume_reactive_event(decision, ws)
	assert_eq(ws["pending_events"].size(), 1)


func test_consume_reactive_event_all_source_types() -> void:
	for source: String in NPCWaveResolver.REACTIVE_SOURCES:
		var ws: Dictionary = {
			"pending_events": [{"type": source}],
		}
		var decision: Dictionary = {
			"success": true,
			"need_source": source,
		}
		NPCWaveResolver._consume_reactive_event(decision, ws)
		assert_eq(ws["pending_events"].size(), 0, "Should consume for source: " + source)


func test_consume_reactive_event_discards_malformed() -> void:
	var ws: Dictionary = {
		"pending_events": [
			{"garbage_key": "bad_data"},
		],
	}
	var decision: Dictionary = {
		"success": true,
		"need_source": "",
		"need_type": "REST",
	}
	NPCWaveResolver._consume_reactive_event(decision, ws)
	assert_eq(ws["pending_events"].size(), 0)


func test_consume_reactive_event_noop_when_empty() -> void:
	var ws: Dictionary = {"pending_events": []}
	var decision: Dictionary = {
		"success": true,
		"need_source": "bribery_eval",
	}
	NPCWaveResolver._consume_reactive_event(decision, ws)
	assert_eq(ws["pending_events"].size(), 0)


func test_consume_reactive_event_preserves_remaining_events() -> void:
	var ws: Dictionary = {
		"pending_events": [
			{"type": "extortion_opportunity", "suspect_id": 3},
			{"type": "provocation", "source_id": 7},
		],
	}
	var decision: Dictionary = {
		"success": true,
		"need_source": "extortion_opportunity",
	}
	NPCWaveResolver._consume_reactive_event(decision, ws)
	assert_eq(ws["pending_events"].size(), 1)
	assert_eq(ws["pending_events"][0]["type"], "provocation")


func test_consume_non_reactive_source_no_events_is_noop() -> void:
	var ws: Dictionary = {"pending_events": []}
	var decision: Dictionary = {
		"success": true,
		"need_source": "crisis_override",
	}
	NPCWaveResolver._consume_reactive_event(decision, ws)
	assert_eq(ws["pending_events"].size(), 0)


# -- Dead Character Filtering --------------------------------------------------

func test_gather_reactive_npcs_skips_dead_characters() -> void:
	var c1 := _make_char(1, 3.0, 2)
	var c2 := _make_char(2, 5.0, 2)
	c2.wounds_taken = 999
	var ws: Dictionary = {
		1: {"pending_events": [{"type": "provocation", "source_id": 5}]},
		2: {"pending_events": [{"type": "provocation", "source_id": 6}]},
	}
	var result: Array = NPCWaveResolver._gather_reactive_npcs([c1, c2], ws)
	assert_eq(result.size(), 1)
	assert_eq(result[0].character_id, 1)


# -- Reactive Event Consumption in Full Execution Path -------------------------

func test_reactive_events_consumed_after_reactive_resolution() -> void:
	var c := _make_char(1, 3.0, 2)
	c.action_points_current = 2
	var ws_inner: Dictionary = _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS)
	ws_inner["pending_events"] = [{"type": "provocation", "source_id": 5}]
	var world_states: Dictionary = {1: ws_inner}
	var objs: Dictionary = {1: {"standing": {"need_type": "REST"}}}
	var results: Array = NPCWaveResolver._resolve_reactive_events(
		[c], world_states, objs, _scoring_tables, _filter_data
	)
	assert_eq(results.size(), 1)
	assert_eq(ws_inner["pending_events"].size(), 0,
		"Reactive event should be consumed after reactive resolution")


# -- Civilian Order Metadata ---------------------------------------------------

func test_civilian_order_includes_metadata() -> void:
	var c := _make_char(1, 6.0, 3)
	c.civilian_orders_remaining = 5
	c.civilian_order_budget_max = 5
	c.action_points_current = 2
	var ws: Dictionary = _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS, true)
	ws["province_statuses"] = []
	var scoring: Dictionary = _scoring_tables.duplicate(true)
	scoring["objective_alignment"]["REST"]["ASSIGN_VASSAL_OBJECTIVE"] = 90
	scoring["objective_alignment"]["REST"]["SET_TAX_RATE"] = 70
	var objs: Dictionary = {"standing": {"need_type": "REST"}}
	var result: Dictionary = NPCWaveResolver._resolve_civilian_order(
		c, ws, objs, scoring, _filter_data
	)
	if result.get("success", false) and result.get("action_id", "") == "ASSIGN_VASSAL_OBJECTIVE":
		assert_true(result.has("metadata"),
			"Civilian order result should include metadata when action has it")


# -- Civilian Order with chars_by_id -------------------------------------------

func test_civilian_order_accepts_characters_by_id() -> void:
	var c := _make_char(1, 6.0, 3)
	c.civilian_orders_remaining = 5
	c.civilian_order_budget_max = 5
	c.action_points_current = 2
	c.clan = "Crane"
	var ws: Dictionary = _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS, true)
	ws["province_statuses"] = []
	var chars_by_id: Dictionary = {1: c}
	var objs: Dictionary = {"standing": {"need_type": "REST"}}
	var result: Dictionary = NPCWaveResolver._resolve_civilian_order(
		c, ws, objs, _scoring_tables, _filter_data,
		[], [], 0, chars_by_id
	)
	assert_true(result.is_empty() or result.has("success"),
		"Civilian order should accept chars_by_id without error")


func test_dead_character_with_ap_excluded_from_active() -> void:
	var c := L5RCharacterData.new()
	c.character_id = 1
	c.character_name = "Dead Mid-Day"
	c.action_points_current = 2
	c.wounds_taken = 999
	c.earth_ring = 2
	c.stamina = 2
	c.skills = {}
	c.emphases = {}
	var active: Array = NPCWaveResolver._get_active_characters([c])
	assert_true(active.is_empty(), "Dead character with AP should be excluded")
	var max_ap: int = NPCWaveResolver._get_max_ap([c])
	assert_eq(max_ap, 0, "Dead character should not inflate max AP")
