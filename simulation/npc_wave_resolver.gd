class_name NPCWaveResolver
## Multi-NPC resolution order per GDD s55.13.
## Resolves all NPCs in AP waves: descending Status, then Awareness tiebreak.
## Court batching: all NPCs at the same court resolve as a group before others.
## Lord characters resolve TWO actions per wave (AP + Civilian Order) per s57.34.
##
## resolve_day() — decision only (returns chosen actions with AP deducted).
## resolve_day_full() — decision + execution (also rolls dice and applies effects).


static func resolve_day(
	characters: Array,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	approach_penalties: Array = [],
	commitments: Array = [],
) -> Array:
	var all_results: Array = []

	var reactive_results: Array = _resolve_reactive_events(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		approach_penalties, commitments
	)
	all_results.append_array(reactive_results)

	var wave_results: Array = _resolve_ap_waves(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		approach_penalties, commitments
	)
	all_results.append_array(wave_results)

	return all_results


static func resolve_day_full(
	characters: Array,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	approach_penalties: Array = [],
	commitments: Array = [],
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Array:
	var all_results: Array = []

	var reactive_results: Array = _resolve_reactive_events_full(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		dice_engine, action_skill_map, approach_penalties, commitments, military_data,
		characters_by_id
	)
	all_results.append_array(reactive_results)

	var wave_results: Array = _resolve_ap_waves_full(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		dice_engine, action_skill_map, approach_penalties, commitments, military_data,
		characters_by_id
	)
	all_results.append_array(wave_results)

	return all_results


static func resolve_day_applied(
	characters: Array,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	characters_by_id: Dictionary,
	provinces: Dictionary,
	action_log: Array,
	approach_penalties: Array = [],
	commitments: Array = [],
	military_data: Dictionary = {},
	settlements: Array = [],
) -> Dictionary:
	var results: Array = resolve_day_full(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		dice_engine, action_skill_map, approach_penalties, commitments, military_data,
		characters_by_id
	)
	var applied: Array = EffectApplicator.apply_day_results(
		results, characters_by_id, provinces, action_log, settlements
	)
	return {
		"results": results,
		"applied": applied,
		"action_log": action_log,
	}


# -- Reactive Events (decision only) ------------------------------------------

static func _resolve_reactive_events(
	characters: Array,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	approach_penalties: Array = [],
	commitments: Array = [],
) -> Array:
	var results: Array = []
	var reactive_npcs: Array = _gather_reactive_npcs(characters, world_states)

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
	characters: Array,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	approach_penalties: Array = [],
	commitments: Array = [],
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Array:
	var results: Array = []
	var reactive_npcs: Array = _gather_reactive_npcs(characters, world_states)

	var csd: Dictionary = world_states.get("_crime_suppression_data", {})
	var cr: Array = world_states.get("_crime_records", [])
	for c: L5RCharacterData in reactive_npcs:
		var ws: Dictionary = world_states.get(c.character_id, {})
		var objs: Dictionary = objectives_map.get(c.character_id, {})
		var redirects: int = _get_travel_redirects(objs)
		var decision: Dictionary = NPCDecisionEngine.run(
			c, ws, objs, scoring_tables, filter_data,
			approach_penalties, commitments, redirects, characters_by_id
		)
		if decision.get("success", false):
			var c_loc: int = int(c.physical_location) if c.physical_location.is_valid_int() else -1
			var c_doshin: int = int(csd.get(c_loc, {}).get("doshin_investigation_bonus", 0))
			var exec_result: Dictionary = _execute_decision(
				decision, c, ws, dice_engine, action_skill_map, military_data,
				characters_by_id, c_doshin, cr
			)
			decision.merge(exec_result, true)
		results.append(decision)

	return results


# -- AP Waves (decision only) -------------------------------------------------

static func _resolve_ap_waves(
	characters: Array,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	approach_penalties: Array = [],
	commitments: Array = [],
) -> Array:
	var results: Array = []
	var max_ap: int = _get_max_ap(characters)

	for _wave_idx: int in range(max_ap):
		var active: Array = _get_active_characters(characters)
		if active.is_empty():
			break

		var wave_results: Array = _run_wave(
			active, world_states, objectives_map, scoring_tables, filter_data,
			approach_penalties, commitments
		)
		results.append_array(wave_results)

	return results


# -- AP Waves (full execution) ------------------------------------------------

static func _resolve_ap_waves_full(
	characters: Array,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	approach_penalties: Array = [],
	commitments: Array = [],
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Array:
	var results: Array = []
	var max_ap: int = _get_max_ap(characters)

	for _wave_idx: int in range(max_ap):
		var active: Array = _get_active_characters(characters)
		if active.is_empty():
			break

		var wave_results: Array = _run_wave_full(
			active, world_states, objectives_map, scoring_tables, filter_data,
			dice_engine, action_skill_map, approach_penalties, commitments,
			military_data, characters_by_id
		)
		results.append_array(wave_results)

	return results


# -- Wave Runners --------------------------------------------------------------

static func _run_wave(
	active: Array,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	approach_penalties: Array = [],
	commitments: Array = [],
) -> Array:
	var results: Array = []
	var sorted: Array = _sort_by_resolution_order(active, world_states)
	var court_groups: Dictionary = {}
	var non_court: Array = []
	_partition_by_court(sorted, world_states, court_groups, non_court)

	for court_id: String in court_groups:
		for c: L5RCharacterData in court_groups[court_id]:
			var wave_results: Array = _resolve_character_wave(
				c, world_states, objectives_map, scoring_tables, filter_data,
				approach_penalties, commitments
			)
			results.append_array(wave_results)

	for c: L5RCharacterData in non_court:
		var wave_results: Array = _resolve_character_wave(
			c, world_states, objectives_map, scoring_tables, filter_data,
			approach_penalties, commitments
		)
		results.append_array(wave_results)

	return results


static func _run_wave_full(
	active: Array,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	approach_penalties: Array = [],
	commitments: Array = [],
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Array:
	var results: Array = []
	var sorted: Array = _sort_by_resolution_order(active, world_states)
	var court_groups: Dictionary = {}
	var non_court: Array = []
	_partition_by_court(sorted, world_states, court_groups, non_court)

	for court_id: String in court_groups:
		for c: L5RCharacterData in court_groups[court_id]:
			var wave_results: Array = _resolve_character_wave_full(
				c, world_states, objectives_map, scoring_tables, filter_data,
				dice_engine, action_skill_map, approach_penalties, commitments,
				military_data, characters_by_id
			)
			results.append_array(wave_results)

	for c: L5RCharacterData in non_court:
		var wave_results: Array = _resolve_character_wave_full(
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
	approach_penalties: Array = [],
	commitments: Array = [],
) -> Array:
	var results: Array = []
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
	approach_penalties: Array = [],
	commitments: Array = [],
	military_data: Dictionary = {},
	characters_by_id: Dictionary = {},
) -> Array:
	var results: Array = []
	var ws: Dictionary = world_states.get(character.character_id, {})
	var objs: Dictionary = objectives_map.get(character.character_id, {})
	var is_lord: bool = ws.get("is_lord", false)
	var redirects: int = _get_travel_redirects(objs)

	var char_loc: int = int(character.physical_location) if character.physical_location.is_valid_int() else -1
	var csd: Dictionary = world_states.get("_crime_suppression_data", {})
	var doshin_entry: Dictionary = csd.get(char_loc, {})
	var doshin_bonus: int = int(doshin_entry.get("doshin_investigation_bonus", 0))
	var cr: Array = world_states.get("_crime_records", [])

	if character.action_points_current > 0:
		var decision: Dictionary = NPCDecisionEngine.run(
			character, ws, objs, scoring_tables, filter_data,
			approach_penalties, commitments, redirects, characters_by_id
		)
		if decision.get("success", false):
			var exec_result: Dictionary = _execute_decision(
				decision, character, ws, dice_engine, action_skill_map,
				military_data, characters_by_id, doshin_bonus, cr
			)
			decision.merge(exec_result, true)
		_consume_reactive_event(decision, ws)
		results.append(decision)

	if is_lord and character.civilian_orders_remaining > 0:
		var order_decision: Dictionary = _resolve_civilian_order(
			character, ws, objs, scoring_tables, filter_data,
			approach_penalties, commitments, redirects
		)
		if not order_decision.is_empty():
			var exec_result: Dictionary = _execute_decision(
				order_decision, character, ws, dice_engine, action_skill_map,
				military_data, characters_by_id, doshin_bonus, cr
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
	approach_penalties: Array = [],
	commitments: Array = [],
	travel_redirects: int = 0,
) -> Dictionary:
	var ctx: NPCDataStructures.ContextSnapshot = NPCDecisionEngine.build_context(character, world_state)
	var need: NPCDataStructures.ImmediateNeed = NPCDecisionEngine.resolve_goal(character, ctx, objectives)
	var options: Array = NPCDecisionEngine.generate_options(ctx, need)

	var order_options: Array = []
	for opt: NPCDataStructures.ScoredAction in options:
		if _is_order_action(opt.action_id):
			if opt.action_id in CivilianOrderBudget.DUAL_COST_ACTIONS:
				if character.action_points_current <= 0:
					continue
			order_options.append(opt)

	if order_options.is_empty():
		return {}

	order_options = NPCDecisionEngine.apply_personality_filter(order_options, ctx, filter_data)
	if order_options.is_empty():
		return {}

	order_options = NPCDecisionEngine.apply_allowlist_filter(order_options, need.need_type, scoring_tables)
	if order_options.is_empty():
		return {}

	NPCDecisionEngine.score_all(order_options, need, ctx, scoring_tables,
		approach_penalties, commitments, character, travel_redirects)
	var chosen: NPCDataStructures.ScoredAction = NPCDecisionEngine.select_action(order_options, ctx)

	character.civilian_orders_remaining -= 1
	var ap_for_order: int = 0
	if chosen.action_id in CivilianOrderBudget.DUAL_COST_ACTIONS:
		ap_for_order = 1
		character.action_points_current = maxi(character.action_points_current - 1, 0)
	return {
		"success": true,
		"action_id": chosen.action_id,
		"target_npc_id": chosen.target_npc_id,
		"target_npc_id_secondary": chosen.target_npc_id_secondary,
		"target_settlement_id": chosen.target_settlement_id,
		"target_province_id": chosen.target_province_id,
		"ap_spent": ap_for_order,
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
	doshin_bonus_override: int = 0,
	crime_records: Array = [],
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
		military_data, characters_by_id, wpm, doshin_bonus_override,
		crime_records,
	)


# -- Reactive Event Consumption ------------------------------------------------

const REACTIVE_SOURCES: Array = [
	"bribery_eval", "extortion_opportunity", "seppuku_offered",
	"witness_report_motivated", "provocation_received",
]


static func _consume_reactive_event(
	decision: Dictionary,
	world_state: Dictionary,
) -> void:
	var events: Array = world_state.get("pending_events", [])
	if events.is_empty():
		return
	var need_source: String = decision.get("need_source", "")
	if need_source in REACTIVE_SOURCES:
		if decision.get("success", false):
			events.remove_at(0)
		return
	# Decompose returned null — discard unprocessable event to prevent infinite loop
	events.remove_at(0)


# -- Helpers -------------------------------------------------------------------

static func _is_order_action(action_id: String) -> bool:
	return (
		action_id in CivilianOrderBudget.PURE_ORDER_ACTIONS
		or action_id in CivilianOrderBudget.MILITARY_OR_CIVILIAN_ACTIONS
		or action_id in CivilianOrderBudget.DUAL_COST_ACTIONS
		or action_id == CivilianOrderBudget.WRITE_LETTER
	)


static func _sort_by_resolution_order(
	characters: Array,
	_world_states: Dictionary,
) -> Array:
	var sorted: Array = characters.duplicate()
	sorted.sort_custom(func(a: L5RCharacterData, b: L5RCharacterData) -> bool:
		if a.status != b.status:
			return a.status > b.status
		return a.awareness > b.awareness
	)
	return sorted


static func _get_max_ap(characters: Array) -> int:
	var max_val: int = 0
	for c: L5RCharacterData in characters:
		if c.action_points_current > max_val:
			max_val = c.action_points_current
	return max_val


static func _get_active_characters(characters: Array) -> Array:
	var active: Array = []
	for c: L5RCharacterData in characters:
		if c.action_points_current > 0:
			active.append(c)
	return active


static func _gather_reactive_npcs(
	characters: Array,
	world_states: Dictionary,
) -> Array:
	var reactive_npcs: Array = []
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
	sorted: Array,
	world_states: Dictionary,
	court_groups: Dictionary,
	non_court: Array,
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
