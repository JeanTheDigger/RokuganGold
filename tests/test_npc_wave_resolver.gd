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
		"characters_present": [] as Array[int],
		"is_lord": is_lord,
		"known_topics": [] as Array[int],
		"known_positions": {},
		"known_objectives": {},
		"known_contacts": [] as Array[int],
		"pending_events": [],
		"action_log": [] as Array[String],
	}


# -- Resolution Order ----------------------------------------------------------

func test_sort_by_status_descending() -> void:
	var c1 := _make_char(1, 3.0, 2)
	var c2 := _make_char(2, 5.0, 2)
	var c3 := _make_char(3, 1.0, 2)
	var sorted: Array[L5RCharacterData] = NPCWaveResolver._sort_by_resolution_order(
		[c1, c2, c3] as Array[L5RCharacterData], {}
	)
	assert_eq(sorted[0].character_id, 2)
	assert_eq(sorted[1].character_id, 1)
	assert_eq(sorted[2].character_id, 3)


func test_sort_tiebreaker_awareness() -> void:
	var c1 := _make_char(1, 3.0, 2)
	var c2 := _make_char(2, 3.0, 5)
	var sorted: Array[L5RCharacterData] = NPCWaveResolver._sort_by_resolution_order(
		[c1, c2] as Array[L5RCharacterData], {}
	)
	assert_eq(sorted[0].character_id, 2)


# -- Full Day Resolution ------------------------------------------------------

func test_resolve_day_all_npcs_act() -> void:
	var c1 := _make_char(1, 3.0, 2)
	var c2 := _make_char(2, 5.0, 2)
	var chars: Array[L5RCharacterData] = [c1, c2]
	var ws: Dictionary = {
		1: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS),
		2: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS),
	}
	var objs: Dictionary = {
		1: {"primary": {"need_type": "REST", "priority": 3}},
		2: {"primary": {"need_type": "REST", "priority": 3}},
	}
	var results: Array[Dictionary] = NPCWaveResolver.resolve_day(
		chars, ws, objs, _scoring_tables, _filter_data
	)
	assert_true(results.size() >= 2)


func test_resolve_day_skips_zero_ap() -> void:
	var c1 := _make_char(1, 3.0, 2)
	c1.action_points_current = 0
	var chars: Array[L5RCharacterData] = [c1]
	var ws: Dictionary = {1: _make_world_state(Enums.ContextFlag.AT_OWN_HOLDINGS)}
	var objs: Dictionary = {1: {"primary": {"need_type": "REST", "priority": 3}}}
	var results: Array[Dictionary] = NPCWaveResolver.resolve_day(
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
	var results: Array[Dictionary] = NPCWaveResolver.resolve_day(
		[c1] as Array[L5RCharacterData], ws, objs, _scoring_tables, _filter_data
	)
	assert_true(results.size() > 0)
	assert_true(results[0]["success"])


# -- Lord Dual Pool ------------------------------------------------------------

func test_is_order_action() -> void:
	assert_true(NPCWaveResolver._is_order_action("ASSESS_PROVINCE_STATUS"))
	assert_true(NPCWaveResolver._is_order_action("ORDER_PATROL"))
	assert_false(NPCWaveResolver._is_order_action("CHARM"))
	assert_false(NPCWaveResolver._is_order_action("TRAIN"))
