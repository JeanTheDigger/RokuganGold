class_name NPCWaveResolver
## Multi-NPC resolution order per GDD s55.13.
## Resolves all NPCs in AP waves: descending Status, then Awareness tiebreak.
## Court batching: all NPCs at the same court resolve as a group before others.
## Lord characters resolve TWO actions per wave (AP + Civilian Order) per s57.34.


static func resolve_day(
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
) -> Array[Dictionary]:
	var all_results: Array[Dictionary] = []

	var reactive_results: Array[Dictionary] = _resolve_reactive_events(
		characters, world_states, objectives_map, scoring_tables, filter_data
	)
	all_results.append_array(reactive_results)

	var wave_results: Array[Dictionary] = _resolve_ap_waves(
		characters, world_states, objectives_map, scoring_tables, filter_data
	)
	all_results.append_array(wave_results)

	return all_results


static func _resolve_reactive_events(
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var reactive_npcs: Array[L5RCharacterData] = []
	for c: L5RCharacterData in characters:
		var ws: Dictionary = world_states.get(c.character_id, {})
		var events: Array = ws.get("pending_events", [])
		if events.size() > 0:
			reactive_npcs.append(c)

	reactive_npcs.sort_custom(func(a: L5RCharacterData, b: L5RCharacterData) -> bool:
		var ws_a: Dictionary = world_states.get(a.character_id, {})
		var ws_b: Dictionary = world_states.get(b.character_id, {})
		var ts_a: int = ws_a.get("reactive_timestamp", 0)
		var ts_b: int = ws_b.get("reactive_timestamp", 0)
		return ts_a < ts_b
	)

	for c: L5RCharacterData in reactive_npcs:
		var ws: Dictionary = world_states.get(c.character_id, {})
		var objs: Dictionary = objectives_map.get(c.character_id, {})
		var result: Dictionary = NPCDecisionEngine.run(c, ws, objs, scoring_tables, filter_data)
		results.append(result)

	return results


static func _resolve_ap_waves(
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var max_ap: int = _get_max_ap(characters)

	for _wave_idx: int in range(max_ap):
		var active: Array[L5RCharacterData] = []
		for c: L5RCharacterData in characters:
			if c.action_points_current > 0:
				active.append(c)
		if active.is_empty():
			break

		var sorted: Array[L5RCharacterData] = _sort_by_resolution_order(active, world_states)

		var court_groups: Dictionary = {}
		var non_court: Array[L5RCharacterData] = []
		for c: L5RCharacterData in sorted:
			var ws: Dictionary = world_states.get(c.character_id, {})
			var cf: int = ws.get("context_flag", Enums.ContextFlag.AT_OWN_HOLDINGS)
			var court_id: String = ws.get("court_id", "")
			if cf == Enums.ContextFlag.AT_COURT and court_id != "":
				if not court_groups.has(court_id):
					court_groups[court_id] = []
				court_groups[court_id].append(c)
			else:
				non_court.append(c)

		for court_id: String in court_groups:
			var group: Array = court_groups[court_id]
			for c: L5RCharacterData in group:
				var wave_results: Array[Dictionary] = _resolve_character_wave(
					c, world_states, objectives_map, scoring_tables, filter_data
				)
				results.append_array(wave_results)

		for c: L5RCharacterData in non_court:
			var wave_results: Array[Dictionary] = _resolve_character_wave(
				c, world_states, objectives_map, scoring_tables, filter_data
			)
			results.append_array(wave_results)

	return results


static func _resolve_character_wave(
	character: L5RCharacterData,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var ws: Dictionary = world_states.get(character.character_id, {})
	var objs: Dictionary = objectives_map.get(character.character_id, {})
	var is_lord: bool = ws.get("is_lord", false)

	if character.action_points_current > 0:
		var ap_result: Dictionary = NPCDecisionEngine.run(
			character, ws, objs, scoring_tables, filter_data
		)
		results.append(ap_result)

	if is_lord and character.civilian_orders_remaining > 0:
		var order_result: Dictionary = _resolve_civilian_order(
			character, ws, objs, scoring_tables, filter_data
		)
		if not order_result.is_empty():
			results.append(order_result)

	return results


static func _resolve_civilian_order(
	character: L5RCharacterData,
	world_state: Dictionary,
	objectives: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
) -> Dictionary:
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(character, world_state)
	var need: NPCDataStructures.ImmediateNeed = NPCDecisionEngine.resolve_goal(character, ctx, objectives)
	var options: Array[NPCDataStructures.ScoredAction] = NPCDecisionEngine.generate_options(ctx, need)

	var order_options: Array[NPCDataStructures.ScoredAction] = []
	for opt: NPCDataStructures.ScoredAction in options:
		if _is_order_action(opt.action_id):
			order_options.append(opt)

	if order_options.is_empty():
		return {}

	order_options = NPCDecisionEngine.apply_personality_filter(order_options, ctx, filter_data)
	if order_options.is_empty():
		return {}

	NPCDecisionEngine.score_all(order_options, need, ctx, scoring_tables)
	var chosen: NPCDataStructures.ScoredAction = NPCDecisionEngine.select_action(order_options, ctx)

	character.civilian_orders_remaining -= 1
	return {
		"success": true,
		"action_id": chosen.action_id,
		"target_npc_id": chosen.target_npc_id,
		"target_npc_id_secondary": chosen.target_npc_id_secondary,
		"target_settlement_id": chosen.target_settlement_id,
		"target_province_id": chosen.target_province_id,
		"ap_spent": 0,
		"order_spent": 1,
		"total_score": chosen.get_total_score(),
		"character_id": ctx.character_id,
		"ic_day": ctx.ic_day,
		"is_order": true,
	}


static func _is_order_action(action_id: String) -> bool:
	return action_id in [
		"ASSESS_PROVINCE_STATUS", "INVESTIGATE_PROVINCE", "ORDER_PATROL",
		"ADJUST_TAX", "BUILD_INFRASTRUCTURE", "LEVY_TROOPS",
		"DEPLOY_ARMY", "TRAIN_TROOPS", "ASSIGN_OBJECTIVE",
		"FILL_VACANCY", "ARRANGE_MARRIAGE",
	]


static func _sort_by_resolution_order(
	characters: Array[L5RCharacterData],
	_world_states: Dictionary,
) -> Array[L5RCharacterData]:
	var sorted: Array[L5RCharacterData] = characters.duplicate()
	sorted.sort_custom(func(a: L5RCharacterData, b: L5RCharacterData) -> bool:
		if a.status != b.status:
			return a.status > b.status
		return a.awareness > b.awareness
	)
	return sorted


static func _get_max_ap(characters: Array[L5RCharacterData]) -> int:
	var max_val: int = 0
	for c: L5RCharacterData in characters:
		if c.action_points_current > max_val:
			max_val = c.action_points_current
	return max_val
