class_name NPCWaveResolver
## Multi-NPC resolution order per GDD s55.13.
## Resolves all NPCs in AP waves: descending Status, then Awareness tiebreak.
## Court batching: all NPCs at the same court resolve as a group before others.
## Lord characters resolve TWO actions per wave (AP + Civilian Order) per s57.34.
##
## resolve_day() — decision only (returns chosen actions with AP deducted).
## resolve_day_full() — decision + execution (also rolls dice and applies effects).


static func resolve_day(
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
) -> Array[Dictionary]:
	var all_results: Array[Dictionary] = []

	var reactive_results: Array[Dictionary] = _resolve_reactive_events(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		approach_penalties, commitments
	)
	all_results.append_array(reactive_results)

	var wave_results: Array[Dictionary] = _resolve_ap_waves(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		approach_penalties, commitments
	)
	all_results.append_array(wave_results)

	return all_results


static func resolve_day_full(
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Array[Dictionary]:
	var all_results: Array[Dictionary] = []

	var reactive_results: Array[Dictionary] = _resolve_reactive_events_full(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		dice_engine, action_skill_map, approach_penalties, commitments, military_data,
		characters_by_id
	)
	all_results.append_array(reactive_results)

	var wave_results: Array[Dictionary] = _resolve_ap_waves_full(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		dice_engine, action_skill_map, approach_penalties, commitments, military_data,
		characters_by_id
	)
	all_results.append_array(wave_results)

	return all_results


static func resolve_day_applied(
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	characters_by_id: Dictionary,
	provinces: Dictionary,
	action_log: Array[Dictionary],
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
	military_data: Dictionary = {},
	settlements: Array[SettlementData] = [],
) -> Dictionary:
	var results: Array[Dictionary] = resolve_day_full(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		dice_engine, action_skill_map, approach_penalties, commitments, military_data,
		characters_by_id
	)
	var applied: Array[Dictionary] = EffectApplicator.apply_day_results(
		results, characters_by_id, provinces, action_log, settlements
	)
	return {
		"results": results,
		"applied": applied,
		"action_log": action_log,
	}


# -- Reactive Events (decision only) ------------------------------------------

static func _resolve_reactive_events(
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var reactive_npcs: Array[L5RCharacterData] = _gather_reactive_npcs(characters, world_states)

	for c: L5RCharacterData in reactive_npcs:
		var ws: Dictionary = world_states.get(c.character_id, {})
		var objs: Dictionary = objectives_map.get(c.character_id, {})
		var redirects: int = _get_travel_redirects(objs)
		var result: Dictionary = NPCDecisionEngine.run(
			c, ws, objs, scoring_tables, filter_data,
			approach_penalties, commitments, redirects
		)
		results.append(result)

	return results


# -- Reactive Events (full execution) -----------------------------------------

static func _resolve_reactive_events_full(
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var reactive_npcs: Array[L5RCharacterData] = _gather_reactive_npcs(characters, world_states)

	for c: L5RCharacterData in reactive_npcs:
		var ws: Dictionary = world_states.get(c.character_id, {})
		var objs: Dictionary = objectives_map.get(c.character_id, {})
		var redirects: int = _get_travel_redirects(objs)
		var decision: Dictionary = NPCDecisionEngine.run(
			c, ws, objs, scoring_tables, filter_data,
			approach_penalties, commitments, redirects, characters_by_id
		)
		if decision.get("success", false):
			var exec_result: Dictionary = _execute_decision(
				decision, c, ws, dice_engine, action_skill_map, military_data,
				characters_by_id
			)
			decision.merge(exec_result, true)
		results.append(decision)

	return results


# -- AP Waves (decision only) -------------------------------------------------

static func _resolve_ap_waves(
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var max_ap: int = _get_max_ap(characters)

	for _wave_idx: int in range(max_ap):
		var active: Array[L5RCharacterData] = _get_active_characters(characters)
		if active.is_empty():
			break

		var wave_results: Array[Dictionary] = _run_wave(
			active, world_states, objectives_map, scoring_tables, filter_data,
			approach_penalties, commitments
		)
		results.append_array(wave_results)

	return results


# -- AP Waves (full execution) ------------------------------------------------

static func _resolve_ap_waves_full(
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var max_ap: int = _get_max_ap(characters)

	for _wave_idx: int in range(max_ap):
		var active: Array[L5RCharacterData] = _get_active_characters(characters)
		if active.is_empty():
			break

		var wave_results: Array[Dictionary] = _run_wave_full(
			active, world_states, objectives_map, scoring_tables, filter_data,
			dice_engine, action_skill_map, approach_penalties, commitments,
			military_data, characters_by_id
		)
		results.append_array(wave_results)

	return results


# -- Wave Runners --------------------------------------------------------------

static func _run_wave(
	active: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var sorted: Array[L5RCharacterData] = _sort_by_resolution_order(active, world_states)
	var court_groups: Dictionary = {}
	var non_court: Array[L5RCharacterData] = []
	_partition_by_court(sorted, world_states, court_groups, non_court)

	for court_id: String in court_groups:
		for c: L5RCharacterData in court_groups[court_id]:
			var wave_results: Array[Dictionary] = _resolve_character_wave(
				c, world_states, objectives_map, scoring_tables, filter_data,
				approach_penalties, commitments
			)
			results.append_array(wave_results)

	for c: L5RCharacterData in non_court:
		var wave_results: Array[Dictionary] = _resolve_character_wave(
			c, world_states, objectives_map, scoring_tables, filter_data,
			approach_penalties, commitments
		)
		results.append_array(wave_results)

	return results


static func _run_wave_full(
	active: Array[L5RCharacterData],
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var sorted: Array[L5RCharacterData] = _sort_by_resolution_order(active, world_states)
	var court_groups: Dictionary = {}
	var non_court: Array[L5RCharacterData] = []
	_partition_by_court(sorted, world_states, court_groups, non_court)

	for court_id: String in court_groups:
		for c: L5RCharacterData in court_groups[court_id]:
			var wave_results: Array[Dictionary] = _resolve_character_wave_full(
				c, world_states, objectives_map, scoring_tables, filter_data,
				dice_engine, action_skill_map, approach_penalties, commitments,
				military_data, characters_by_id
			)
			results.append_array(wave_results)

	for c: L5RCharacterData in non_court:
		var wave_results: Array[Dictionary] = _resolve_character_wave_full(
			c, world_states, objectives_map, scoring_tables, filter_data,
			dice_engine, action_skill_map, approach_penalties, commitments,
			military_data, characters_by_id
		)
		results.append_array(wave_results)

	return results


# -- Per-Character Resolution (decision only) ----------------------------------

static func _resolve_character_wave(
	character: L5RCharacterData,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var ws: Dictionary = world_states.get(character.character_id, {})
	var objs: Dictionary = objectives_map.get(character.character_id, {})
	var is_lord: bool = ws.get("is_lord", false)
	var redirects: int = _get_travel_redirects(objs)

	if character.action_points_current > 0:
		var ap_result: Dictionary = NPCDecisionEngine.run(
			character, ws, objs, scoring_tables, filter_data,
			approach_penalties, commitments, redirects
		)
		results.append(ap_result)

	if is_lord and character.civilian_orders_remaining > 0:
		var order_result: Dictionary = _resolve_civilian_order(
			character, ws, objs, scoring_tables, filter_data,
			approach_penalties, commitments, redirects
		)
		if not order_result.is_empty():
			results.append(order_result)

	return results


# -- Per-Character Resolution (full execution) ---------------------------------

static func _resolve_character_wave_full(
	character: L5RCharacterData,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var ws: Dictionary = world_states.get(character.character_id, {})
	var objs: Dictionary = objectives_map.get(character.character_id, {})
	var is_lord: bool = ws.get("is_lord", false)
	var redirects: int = _get_travel_redirects(objs)

	if character.action_points_current > 0:
		var decision: Dictionary = NPCDecisionEngine.run(
			character, ws, objs, scoring_tables, filter_data,
			approach_penalties, commitments, redirects, characters_by_id
		)
		if decision.get("success", false):
			var exec_result: Dictionary = _execute_decision(
				decision, character, ws, dice_engine, action_skill_map,
				military_data, characters_by_id
			)
			decision.merge(exec_result, true)
		results.append(decision)

	if is_lord and character.civilian_orders_remaining > 0:
		var order_decision: Dictionary = _resolve_civilian_order(
			character, ws, objs, scoring_tables, filter_data,
			approach_penalties, commitments, redirects
		)
		if not order_decision.is_empty():
			var exec_result: Dictionary = _execute_decision(
				order_decision, character, ws, dice_engine, action_skill_map,
				military_data, characters_by_id
			)
			order_decision.merge(exec_result, true)
			results.append(order_decision)

	return results


# -- Civilian Order Resolution -------------------------------------------------

static func _resolve_civilian_order(
	character: L5RCharacterData,
	world_state: Dictionary,
	objectives: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
	travel_redirects: int = 0,
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

	NPCDecisionEngine.score_all(order_options, need, ctx, scoring_tables,
		approach_penalties, commitments, character, travel_redirects)
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


# -- Executor Bridge -----------------------------------------------------------

static func _execute_decision(
	decision: Dictionary,
	character: L5RCharacterData,
	world_state: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Dictionary:
	var action := NPCDataStructures.ScoredAction.new()
	action.action_id = decision.get("action_id", "DO_NOTHING")
	action.target_npc_id = decision.get("target_npc_id", -1)
	action.target_npc_id_secondary = decision.get("target_npc_id_secondary", -1)
	action.target_settlement_id = decision.get("target_settlement_id", -1)
	action.target_province_id = decision.get("target_province_id", -1)
	action.metadata = decision.get("metadata", {})

	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(
		character, world_state, characters_by_id
	)

	var wm_all: Dictionary = world_state.get("_worship_maluses", {})
	var char_loc: int = int(character.physical_location) if character.physical_location.is_valid_int() else -1
	var sett_prov: Dictionary = world_state.get("_settlement_province_map", {})
	var char_prov: int = sett_prov.get(char_loc, -1)
	var wpm: Dictionary = wm_all.get(char_prov, {})

	return ActionExecutor.execute(
		action, character, ctx, dice_engine, action_skill_map,
		military_data, characters_by_id, wpm,
	)


# -- Helpers -------------------------------------------------------------------

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


static func _get_active_characters(characters: Array[L5RCharacterData]) -> Array[L5RCharacterData]:
	var active: Array[L5RCharacterData] = []
	for c: L5RCharacterData in characters:
		if c.action_points_current > 0:
			active.append(c)
	return active


static func _gather_reactive_npcs(
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
) -> Array[L5RCharacterData]:
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
	return reactive_npcs


static func _partition_by_court(
	sorted: Array[L5RCharacterData],
	world_states: Dictionary,
	court_groups: Dictionary,
	non_court: Array[L5RCharacterData],
) -> void:
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


static func _get_travel_redirects(objectives: Dictionary) -> int:
	var primary: Dictionary = objectives.get("primary", {})
	return primary.get("travel_redirects", 0)
