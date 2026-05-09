class_name DayOrchestrator
## Single entry point to advance world state by one IC day.
## Sequence: AP reset → wave resolution → effect application →
## info events → letter delivery → topic tick →
## (season boundary) resource tick + confidence decay.


static func advance_day(
	time_system: TimeSystem,
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	world_states: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	filter_data: Dictionary,
	dice_engine: DiceEngine,
	action_skill_map: Dictionary,
	provinces: Dictionary,
	action_log: Array[Dictionary],
	season_meta: Dictionary,
	active_topics: Array[TopicData] = [],
	pending_letters: Array = [],
	approach_penalties: Array[Dictionary] = [],
	commitments: Array[CommitmentData] = [],
	crime_records: Array[CrimeRecord] = [],
	next_case_id: Array[int] = [1],
	military_data: Dictionary = {},
	character_province_map: Dictionary = {},
	next_topic_id: Array[int] = [1000],
	death_events: Array[Dictionary] = [],
	successor_map: Dictionary = {},
	favors: Array = [],
	insurgencies: Array[InsurgencyData] = [],
	next_insurgency_id: Array[int] = [1],
	settlements: Array[SettlementData] = [],
	miya_inputs: Dictionary = {},
	active_successions: Array[SuccessionData] = [],
	next_succession_id: Array[int] = [1],
	entanglements: Array[Dictionary] = [],
	bound_states: Array[Dictionary] = [],
	active_armies: Array[Dictionary] = [],
	active_sieges: Array[Dictionary] = [],
	active_tethers: Array[Dictionary] = [],
	order_states: Array[Dictionary] = [],
	companies: Array[Dictionary] = [],
	clans: Dictionary = {},
	active_wars: Array[WarData] = [],
	trade_routes: Array = [],
	next_war_id: Array[int] = [1],
	active_courts: Array[CourtSessionData] = [],
	next_court_id: Array[int] = [1],
	active_edicts: Array[EdictData] = [],
	next_edict_id: Array[int] = [1],
	active_hordes: Array[HordeData] = [],
	horde_strength_counters: Dictionary = {},
	last_targeted_province_id: Array[int] = [-1],
) -> Dictionary:
	var prev_season: int = time_system.get_season()

	time_system.advance_tick()

	var ic_day: int = time_system.get_ic_day()
	var current_season: int = time_system.get_season()

	_reset_all_ap(characters)

	var festival_results: Dictionary = _process_festivals(ic_day, world_states)

	var travel_arrivals: Array[Dictionary] = _process_travel(characters)
	_process_arrival_observation(travel_arrivals, characters_by_id, current_season)

	_apply_cohabitation(characters, characters_by_id)

	var favor_results: Dictionary = _process_favors(favors, ic_day, characters_by_id)

	var entanglement_results: Array[Dictionary] = _process_entanglements(entanglements, ic_day)
	var bound_escape_results: Array[Dictionary] = _process_bound_states(
		bound_states, characters_by_id, dice_engine, ic_day
	)

	var crisis_courts: Array[Dictionary] = _process_crisis_court_calls(
		characters, active_courts, active_topics, world_states, next_court_id, ic_day,
	)
	var court_openings: Array[Dictionary] = _process_court_openings(active_courts, ic_day)
	var court_attendance: Array[Dictionary] = _process_court_attendance(active_courts, characters, characters_by_id)
	var court_results: Array[Dictionary] = _process_active_courts(
		active_courts, active_topics, next_topic_id, ic_day,
		active_edicts, next_edict_id, active_wars,
		characters_by_id, world_states,
	)
	_set_court_context_flags(active_courts, world_states)
	_set_wall_tower_context_flags(characters, settlements, provinces, world_states)

	var edict_results: Array[Dictionary] = _process_edict_compliance(
		active_edicts, active_wars, characters, active_topics, next_topic_id, ic_day,
	)

	_inject_edict_reactive_events(active_edicts, characters, world_states, ic_day)

	var military_daily: Dictionary = _process_military_daily(
		active_armies, active_sieges, active_tethers, order_states,
		dice_engine, settlements, companies,
	)

	var day_result: Dictionary = NPCWaveResolver.resolve_day_applied(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		dice_engine, action_skill_map, characters_by_id, provinces, action_log,
		approach_penalties, commitments, military_data, settlements
	)

	var letter_pass_results: Array[Dictionary] = _process_daily_letter_pass(
		characters, characters_by_id, objectives_map, scoring_tables, world_states
	)

	var crime_results: Array[Dictionary] = _process_crime_detection(
		day_result.get("results", []),
		characters_by_id,
		crime_records,
		ic_day,
		next_case_id,
		active_topics,
		next_topic_id,
		world_states,
	)

	var military_effects: Array[Dictionary] = _process_military_effects(
		day_result.get("results", []),
		settlements,
		characters_by_id,
		companies,
	)

	var wall_engineering_results: Array[Dictionary] = _process_wall_engineering_effects(
		day_result.get("results", []),
		settlements,
	)

	var sortie_results: Array[Dictionary] = _process_sortie_results(
		day_result.get("results", []),
		settlements,
		provinces,
	)

	var horde_assault_results: Array[Dictionary] = _process_horde_assaults(
		active_hordes, settlements, active_topics, next_topic_id, ic_day, provinces,
	)

	var starvation_results: Array[Dictionary] = _process_starvation_warfare_effects(
		day_result.get("results", []),
		characters_by_id,
		trade_routes,
		active_topics,
		next_topic_id,
		ic_day,
		season_meta,
		active_wars,
		next_war_id,
	)

	var supply_sharing_results: Array[Dictionary] = _process_supply_sharing(
		day_result.get("results", []),
		characters_by_id,
		settlements,
		provinces,
	)

	_process_edict_compliance_actions(
		day_result.get("results", []),
		active_edicts,
	)

	var war_declarations: Array[Dictionary] = _process_war_declarations(
		day_result.get("results", []),
		active_wars,
		ic_day,
		next_war_id,
	)

	var ladder_effects_results: Array[Dictionary] = _process_ladder_side_effects(
		day_result.get("results", []),
		characters_by_id,
		active_topics,
		next_topic_id,
		ic_day,
		favors,
		active_wars,
		next_war_id,
	)

	var trade_route_results: Array[Dictionary] = _process_war_trade_routes(
		war_declarations, trade_routes, provinces,
	)

	var war_score_results: Array[Dictionary] = _process_war_score_shifts(
		military_daily, military_effects, active_wars, companies,
	)

	var war_termination_results: Array[Dictionary] = _process_war_terminations(
		day_result.get("results", []),
		active_wars,
		active_topics,
		next_topic_id,
		ic_day,
	)

	var peace_route_results: Array[Dictionary] = _process_peace_trade_routes(
		war_termination_results, trade_routes,
	)
	trade_route_results.append_array(peace_route_results)

	var military_topics: Array[TopicData] = _generate_military_event_topics(
		military_daily, military_effects, active_topics, next_topic_id, ic_day,
	)

	var commitment_results: Array[Dictionary] = _process_commitment_deadlines(
		commitments, ic_day, characters_by_id
	)

	var orphan_results: Array[Dictionary] = _process_lord_deaths(
		death_events, characters, objectives_map, successor_map,
		active_successions, next_succession_id, characters_by_id, ic_day,
		active_topics, next_topic_id,
	)

	var succession_results: Array[Dictionary] = _process_successions(
		active_successions, characters_by_id
	)

	var conversation_results: Array[Dictionary] = _process_daily_conversations(
		characters, dice_engine, current_season
	)

	_wire_discussion_counts(conversation_results, active_topics)
	_compute_positions_from_conversations(
		conversation_results, active_topics, characters_by_id
	)

	var topic_results: Dictionary = TopicMomentumSystem.process_daily_tick(active_topics)

	var province_clan_map: Dictionary = _build_province_clan_map(provinces)
	var broadcast_results: Array[Dictionary] = TopicMomentumSystem.broadcast_public_knowledge(
		active_topics, characters, character_province_map, province_clan_map, provinces
	)
	_compute_positions_from_broadcast(broadcast_results, active_topics, characters_by_id)

	var uphold_law_results: Array[Dictionary] = _process_uphold_law_scan(
		characters, objectives_map, crime_records, active_topics
	)

	var info_results: Array[Dictionary] = _process_info_events(
		day_result.get("applied", []),
		characters_by_id,
		action_log,
		current_season,
		crime_records,
		objectives_map,
	)

	var letter_results: Array[Dictionary] = LetterSystem.process_pending_letters(
		pending_letters, characters_by_id, ic_day, current_season, action_log
	)
	_compute_positions_from_letters(letter_results, active_topics, characters_by_id)

	var seasonal_result: Dictionary = {}
	var strategic_results: Array[Dictionary] = []
	var progress_results: Array[Dictionary] = []
	var insurgency_results: Dictionary = {}
	var military_seasonal_result: Dictionary = {}
	var wall_seasonal_result: Dictionary = {}
	if current_season != prev_season:
		# Add the IC year to miya_inputs so per-province blessed-year tracking
		# stays consistent. Year is computed from the time system's tick count.
		var spring_inputs: Dictionary = miya_inputs.duplicate()
		if current_season == TimeSystem.Season.SPRING and not miya_inputs.is_empty():
			spring_inputs["current_ic_year"] = time_system.get_ic_year()
		seasonal_result = _process_season_transition(
			characters, provinces, current_season, season_meta,
			approach_penalties, settlements, spring_inputs
		)
		wall_seasonal_result = _process_wall_seasonal_pressure(
			settlements, provinces, current_season, season_meta
		)
		# Miya's Blessing follow-up — topic generation, disposition deltas,
		# suspension penalties. Runs only on Spring transitions when the
		# blessing actually fired or was suspended.
		if current_season == TimeSystem.Season.SPRING:
			_process_miya_blessing_followup(
				seasonal_result, miya_inputs, provinces, characters_by_id,
				active_topics, next_topic_id, ic_day, season_meta,
			)
		_process_famine_crises(
			seasonal_result, provinces, active_topics,
			next_topic_id, ic_day, season_meta,
		)
		_decay_all_historical_modifiers(characters, ic_day)
		military_seasonal_result = _process_military_seasonal(
			companies, settlements, clans, characters_by_id,
			dice_engine, _season_to_name(current_season),
		)
		_process_war_seasonal(active_wars, characters)
		military_seasonal_result["blockade_honor"] = StarvationWarfare.process_seasonal_blockade_honor(
			trade_routes, characters_by_id,
		)
		military_seasonal_result["supply_status"] = _process_supply_status_checks(
			characters, active_wars, settlements, provinces,
			companies, clans, active_tethers,
		)
		_consume_supply_status_results(
			military_seasonal_result.get("supply_status", []),
			world_states, active_armies, active_topics,
			next_topic_id, ic_day,
		)
		insurgency_results = _process_insurgencies(
			insurgencies, provinces, dice_engine, current_season,
			next_insurgency_id, world_states
		)
		progress_results = _evaluate_objective_progress(
			characters, objectives_map, world_states
		)
		strategic_results = _run_strategic_reviews(
			characters, objectives_map, world_states
		)
		_evaluate_heir_designations(
			characters, characters_by_id, active_topics
		)
		_process_strategic_court_calls(
			strategic_results, active_courts, active_topics,
			characters_by_id, next_court_id, ic_day, world_states,
			current_season,
		)

	var horde_results: Dictionary = _process_horde_rolls(
		current_season, prev_season,
		active_hordes, horde_strength_counters, last_targeted_province_id,
		settlements, provinces, dice_engine, ic_day, season_meta,
		active_topics, next_topic_id,
	)

	return {
		"ic_day": ic_day,
		"season": current_season,
		"season_changed": current_season != prev_season,
		"day_results": day_result.get("results", []),
		"applied": day_result.get("applied", []),
		"conversation_results": conversation_results,
		"topic_results": topic_results,
		"broadcast_results": broadcast_results,
		"info_results": info_results,
		"letter_results": letter_results,
		"seasonal_result": seasonal_result,
		"crime_results": crime_results,
		"commitment_results": commitment_results,
		"uphold_law_results": uphold_law_results,
		"orphan_results": orphan_results,
		"strategic_results": strategic_results,
		"festival_results": festival_results,
		"favor_results": favor_results,
		"travel_arrivals": travel_arrivals,
		"progress_results": progress_results,
		"letter_pass_results": letter_pass_results,
		"insurgency_results": insurgency_results,
		"succession_results": succession_results,
		"entanglement_results": entanglement_results,
		"bound_escape_results": bound_escape_results,
		"military_daily": military_daily,
		"military_seasonal": military_seasonal_result,
		"military_effects": military_effects,
		"military_topics": military_topics,
		"war_score_results": war_score_results,
		"war_declarations": war_declarations,
		"ladder_effects_results": ladder_effects_results,
		"war_termination_results": war_termination_results,
		"trade_route_results": trade_route_results,
		"starvation_results": starvation_results,
		"supply_sharing_results": supply_sharing_results,
		"court_results": court_results,
		"court_openings": court_openings,
		"court_attendance": court_attendance,
		"crisis_courts": crisis_courts,
		"edict_results": edict_results,
		"active_edicts": active_edicts,
		"wall_seasonal": wall_seasonal_result,
		"wall_engineering_results": wall_engineering_results,
		"sortie_results": sortie_results,
		"horde_assault_results": horde_assault_results,
		"horde_results": horde_results,
	}


# -- AP Reset ------------------------------------------------------------------

static func _reset_all_ap(characters: Array[L5RCharacterData]) -> void:
	for c: L5RCharacterData in characters:
		ActionPointSystem.reset_daily_ap(c)
		c.civilian_orders_remaining = c.civilian_order_budget_max
		c.passage_request_count_today = 0
		c.pieces_seen.erase("_performance_count_today")


# -- Information Processing ----------------------------------------------------

static func _process_info_events(
	applied_list: Array,
	characters_by_id: Dictionary,
	action_log: Array[Dictionary],
	current_season: int,
	crime_records: Array[CrimeRecord] = [],
	objectives_map: Dictionary = {},
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for applied: Dictionary in applied_list:
		var info_events: Array = applied.get("info_events", [])
		for event: Dictionary in info_events:
			var char_id: int = event.get("character_id", -1)
			var character: L5RCharacterData = characters_by_id.get(char_id)
			if character == null:
				continue

			var target_id: int = event.get("target_npc_id", -1)
			var quality: int = event.get("quality", 1)

			if target_id >= 0:
				var discovered: Array[KnowledgeEntry] = InformationSystem.process_probe_result(
					character, target_id, action_log, current_season, quality
				)

				var witness_result: Dictionary = _check_witness_evidence(
					char_id, target_id, quality, crime_records, objectives_map
				)

				results.append({
					"character_id": char_id,
					"target_id": target_id,
					"entries_discovered": discovered.size(),
					"witness_evidence": witness_result.get("evidence_gained", 0),
				})

	return results


# -- Daily Conversations -------------------------------------------------------

static func _process_daily_conversations(
	characters: Array[L5RCharacterData],
	dice_engine: DiceEngine,
	current_season: int,
) -> Array[Dictionary]:
	var by_location: Dictionary = {}
	for c: L5RCharacterData in characters:
		var loc: String = c.physical_location
		if loc.is_empty():
			continue
		if not by_location.has(loc):
			by_location[loc] = []
		by_location[loc].append(c)

	var all_results: Array[Dictionary] = []
	for loc: String in by_location:
		var group: Array[L5RCharacterData] = []
		for c: Variant in by_location[loc]:
			if c is L5RCharacterData:
				group.append(c)
		if group.size() < 2:
			continue

		var pair_count: int = (group.size() * (group.size() - 1)) / 2
		var rng_needed: int = pair_count * 3
		var rng: Array[int] = []
		for i: int in range(rng_needed):
			rng.append(dice_engine.rand_int_range(0, 99))

		var results: Array[Dictionary] = DailyConversation.resolve_settlement_conversations(
			group, rng, current_season
		)
		all_results.append_array(results)

	return all_results


# -- Season Transition ---------------------------------------------------------

static func _process_season_transition(
	characters: Array[L5RCharacterData],
	provinces: Dictionary,
	current_season: int,
	season_meta: Dictionary,
	approach_penalties: Array[Dictionary] = [],
	settlements: Array[SettlementData] = [],
	miya_inputs: Dictionary = {},
) -> Dictionary:
	_decay_all_knowledge(characters, current_season)

	var penalties_decayed: int = ApproachEvaluation.decay_penalties(
		approach_penalties, current_season
	)

	var province_array: Array[ProvinceData] = []
	for pid: int in provinces:
		province_array.append(provinces[pid])

	var season_name: String = _season_to_name(current_season)

	# Read the Emperor's previous-Autumn income from season_meta (where the
	# autumn tax cascade persisted it) and inject it into miya_inputs.
	# Spring tick is the only one that reads it, so this is harmless on
	# other seasons.
	var resolved_inputs: Dictionary = miya_inputs.duplicate()
	if not resolved_inputs.is_empty() and not resolved_inputs.has("emperor_autumn_tax_income"):
		resolved_inputs["emperor_autumn_tax_income"] = float(
			season_meta.get("last_autumn_emperor_tax_income", 0.0)
		)

	var tick_result: Dictionary = ResourceTick.process_seasonal_tick(
		province_array, settlements, season_name, season_meta, resolved_inputs
	)

	return {
		"season_name": season_name,
		"knowledge_decayed": true,
		"resource_tick": tick_result,
		"approach_penalties_decayed": penalties_decayed,
	}


# -- Wall Seasonal Pressure (s2.4.3, s2.4.10) ----------------------------------
# Applies SI decay, adjacent bleed, and PTL accumulation to wall tower settlements
# once per season. Mutates settlement.wall_si and province.province_taint_level.

static func _process_wall_seasonal_pressure(
	settlements: Array[SettlementData],
	provinces: Dictionary,
	current_season: int,
	season_meta: Dictionary,
) -> Dictionary:
	var season_name: String = _season_to_name(current_season)

	# Collect wall tower settlements.
	var wall_settlements: Array[SettlementData] = []
	for s: SettlementData in settlements:
		if s.settlement_type == Enums.SettlementType.WALL_TOWER:
			wall_settlements.append(s)

	if wall_settlements.is_empty():
		return {}

	# Build province_id → wall tower settlement map for adjacency lookups.
	var province_to_wall: Dictionary = {}
	for s: SettlementData in wall_settlements:
		province_to_wall[s.province_id] = s

	# Step 1: Apply seasonal SI decay per tower (s2.4.3 + s2.4.10 + s2.4.16).
	var si_decay_results: Array[Dictionary] = []
	for s: SettlementData in wall_settlements:
		var province: Variant = provinces.get(s.province_id, null)
		if not province is ProvinceData:
			continue
		var prov: ProvinceData = province as ProvinceData
		# Pass Kaiu Reinforcement reduction (zero when no modifier is active).
		var decay_result: Dictionary = WallSystem.apply_seasonal_si_decay(
			s, season_name, prov.shadowlands_strength, s.kaiu_decay_reduction
		)
		var old_si: int = decay_result["new_si"] + decay_result["decay_applied"]
		s.wall_si = decay_result["new_si"]
		# Tick down the Kaiu Reinforcement modifier (s2.4.16).
		if s.kaiu_reinforce_seasons_remaining > 0:
			s.kaiu_reinforce_seasons_remaining -= 1
			if s.kaiu_reinforce_seasons_remaining == 0:
				s.kaiu_decay_reduction = 0.0
		si_decay_results.append({
			"settlement_id": s.settlement_id,
			"province_id": s.province_id,
			"old_si": old_si,
			"new_si": decay_result["new_si"],
			"decay_applied": decay_result["decay_applied"],
		})

	# Step 2: Adjacent bleed (s2.4.3).
	# 0.5 SI per season accumulates in season_meta until it reaches 1.0.
	var bleed_accum: Dictionary = season_meta.get("_wall_bleed_accum", {})
	for s: SettlementData in wall_settlements:
		var bleed_check: Dictionary = WallSystem.compute_adjacent_bleed(s.wall_si)
		if not bleed_check["bleed_active"]:
			continue
		var province: Variant = provinces.get(s.province_id, null)
		if not province is ProvinceData:
			continue
		var prov: ProvinceData = province as ProvinceData
		for adj_id: int in prov.adjacent_province_ids:
			if not province_to_wall.has(adj_id):
				continue
			var adj_s: SettlementData = province_to_wall[adj_id] as SettlementData
			var key: String = str(adj_s.settlement_id)
			var accum: float = float(bleed_accum.get(key, 0.0)) + bleed_check["bleed_amount"]
			if accum >= 1.0:
				adj_s.wall_si = maxi(0, adj_s.wall_si - 1)
				accum -= 1.0
			bleed_accum[key] = accum
	season_meta["_wall_bleed_accum"] = bleed_accum

	# Step 3: PTL contribution from degraded wall sections (s2.4.2).
	var ptl_updates: Array[Dictionary] = []
	for s: SettlementData in wall_settlements:
		var province: Variant = provinces.get(s.province_id, null)
		if not province is ProvinceData:
			continue
		var prov: ProvinceData = province as ProvinceData
		var ptl_gain: float = WallSystem.compute_ptl_contribution(s.wall_si, true)
		prov.province_taint_level = clampf(
			prov.province_taint_level + ptl_gain, 0.0, 10.0
		)
		ptl_updates.append({
			"province_id": s.province_id,
			"ptl_gain": ptl_gain,
			"new_ptl": prov.province_taint_level,
		})

	# Step 4: Garrison shortage detection (s2.4.12).
	# Flags towers below the minimum defensible garrison. Does NOT generate a
	# topic — per s2.4.12 the Taisa/Shireikan must communicate the shortage
	# through letters or personal visits. The flag is returned in the result
	# for the NPC AI to act on.
	var garrison_shortage_towers: Array[Dictionary] = []
	for s: SettlementData in wall_settlements:
		if WallSystem.is_garrison_below_minimum(s.garrison_pu):
			garrison_shortage_towers.append({
				"settlement_id": s.settlement_id,
				"province_id": s.province_id,
				"garrison_pu": s.garrison_pu,
				"wall_si": s.wall_si,
			})

	return {
		"si_decay_results": si_decay_results,
		"ptl_updates": ptl_updates,
		"garrison_shortage_towers": garrison_shortage_towers,
	}


# -- Wall Engineering Effects (s2.4.16) ----------------------------------------

static func _process_wall_engineering_effects(
	applied_list: Array,
	settlements: Array[SettlementData],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Build province_id → wall tower settlement map once.
	var wall_by_province: Dictionary = {}
	for s: SettlementData in settlements:
		if s.settlement_type == Enums.SettlementType.WALL_TOWER:
			wall_by_province[s.province_id] = s

	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})
		var target_pid: int = effects.get("target_province_id", -1)

		# FORTIFY_WALL_SECTION: apply SI gain and set/update Kaiu Reinforcement.
		if effects.get("requires_fortify_wall", false):
			var settlement: Variant = wall_by_province.get(target_pid, null)
			if not settlement is SettlementData:
				continue
			var s: SettlementData = settlement as SettlementData
			var si_gain: int = effects.get("si_gain", 1)
			var old_si: int = s.wall_si
			s.wall_si = clampi(s.wall_si + si_gain, 0, 10)
			# Apply Kaiu Reinforcement modifier — overwrite only if new value >=
			# existing (s2.4.16 overwrite rule).
			var new_reduction: float = float(effects.get("kaiu_decay_reduction", 0.0))
			if new_reduction >= s.kaiu_decay_reduction:
				s.kaiu_decay_reduction = new_reduction
				s.kaiu_reinforce_seasons_remaining = int(
					effects.get("kaiu_reinforce_duration", 0)
				)
			results.append({
				"action": "fortify_wall",
				"settlement_id": s.settlement_id,
				"province_id": target_pid,
				"old_si": old_si,
				"new_si": s.wall_si,
				"kaiu_decay_reduction": s.kaiu_decay_reduction,
				"kaiu_seasons_remaining": s.kaiu_reinforce_seasons_remaining,
			})

		# SEAL_WALL_BREACH: always deduct Koku; restore SI to 2 on success.
		elif applied.get("action_id", "") == "SEAL_WALL_BREACH" \
				and effects.get("koku_cost", 0.0) > 0.0:
			var settlement: Variant = wall_by_province.get(target_pid, null)
			if not settlement is SettlementData:
				continue
			var s: SettlementData = settlement as SettlementData
			var old_si: int = s.wall_si
			s.koku_stockpile = maxf(0.0, s.koku_stockpile - float(effects["koku_cost"]))
			if effects.get("requires_breach_seal", false):
				s.wall_si = 2
			results.append({
				"action": "seal_breach",
				"settlement_id": s.settlement_id,
				"province_id": target_pid,
				"old_si": old_si,
				"new_si": s.wall_si,
				"koku_deducted": float(effects["koku_cost"]),
				"sealed": effects.get("requires_breach_seal", false),
			})

	return results


# -- Sortie Results (s2.4.10, s2.4.11, s2.4.15) --------------------------------

static func _process_sortie_results(
	applied_list: Array,
	settlements: Array[SettlementData],
	provinces: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Build province_id → wall tower settlement map for jade deduction.
	var wall_by_province: Dictionary = {}
	for s: SettlementData in settlements:
		if s.settlement_type == Enums.SettlementType.WALL_TOWER:
			wall_by_province[s.province_id] = s

	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})
		if not effects.get("requires_sortie_combat", false):
			continue

		var target_pid: int = effects.get("target_province_id", -1)
		var ss_reduction: int = int(effects.get("ss_reduction", 0))
		var force_pct: float = float(effects.get("force_pct", 0.0))
		var jade_per_warrior: int = int(effects.get("jade_per_warrior", 1))

		# Apply SS reduction to the Shadowlands province (s2.4.11).
		# Horde combat resolution is deferred (s2.4.7); SS reduction is applied
		# immediately as a simplified sortie outcome.
		var new_ss: int = 0
		var province: Variant = provinces.get(target_pid, null)
		if province is ProvinceData:
			var prov: ProvinceData = province as ProvinceData
			new_ss = maxi(0, prov.shadowlands_strength - ss_reduction)
			prov.shadowlands_strength = new_ss

		# Consume jade from the Tower stockpile (s2.4.15).
		# warriors = floor(garrison_pu × force_pct); jade = warriors × jade_per_warrior.
		var jade_consumed: float = 0.0
		var settlement: Variant = wall_by_province.get(target_pid, null)
		if settlement is SettlementData:
			var s: SettlementData = settlement as SettlementData
			var warriors: int = int(s.garrison_pu * force_pct)
			jade_consumed = float(warriors * jade_per_warrior)
			s.jade_stockpile = maxf(0.0, s.jade_stockpile - jade_consumed)

		results.append({
			"province_id": target_pid,
			"ss_reduction_applied": ss_reduction,
			"new_ss": new_ss,
			"jade_consumed": jade_consumed,
		})

	return results


# -- Horde Assault SI Processing (s2.4.5 — LOCKED) ----------------------------

## Processes resolved horde assaults: applies SI hit from the battle outcome,
## detects breach, and generates a Tier 1 Shadowlands Incursion crisis topic.
## Called each tick; only hordes with `assault_resolved = true` and an unprocessed
## outcome (assault_si_hit == 0) are handled. The combat system that resolves
## horde assaults (deferred) must set `horde.assault_resolved = true` and
## `horde.battle_outcome` to a HordeBattleOutcome enum value before this runs.
static func _process_horde_assaults(
	active_hordes: Array[HordeData],
	settlements: Array[SettlementData],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	provinces: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Build province_id → wall tower settlement map.
	var wall_by_province: Dictionary = {}
	for s: SettlementData in settlements:
		if s.settlement_type == Enums.SettlementType.WALL_TOWER:
			wall_by_province[s.province_id] = s

	for horde: HordeData in active_hordes:
		if not horde.assault_resolved:
			continue
		if horde.battle_outcome < 0:
			continue
		# Skip if SI hit was already processed (si_hit stored > 0 means done).
		if horde.assault_si_hit != 0:
			continue

		var tower: Variant = wall_by_province.get(horde.target_province_id, null)
		if not tower is SettlementData:
			continue

		var si_result: Dictionary = HordeSystem.apply_assault_si_hit(
			tower as SettlementData, horde.battle_outcome
		)
		horde.assault_si_hit = si_result["si_hit"]

		var breach: bool = bool(si_result.get("breach", false))
		if breach:
			# Generate Tier 1 Shadowlands Incursion crisis topic (s2.4.5, s16.3).
			var province: Variant = provinces.get(horde.target_province_id, null)
			var clan_str: String = ""
			if province is ProvinceData:
				clan_str = (province as ProvinceData).clan
			var topic := TopicData.new()
			topic.topic_id = next_topic_id[0]
			next_topic_id[0] += 1
			topic.slug = "shadowlands_incursion_p%d_d%d" % [horde.target_province_id, ic_day]
			topic.topic_type = "crisis"
			topic.variant = "shadowlands_incursion"
			topic.category = TopicData.Category.MILITARY
			topic.tier = TopicData.Tier.TIER_1
			topic.momentum = 80.0  # Tier 1 crisis starts with high momentum.
			topic.clan_involved = clan_str
			topic.ic_day_created = ic_day
			topic.provinces_affected = [horde.target_province_id]
			active_topics.append(topic)
			results.append({
				"province_id": horde.target_province_id,
				"outcome": horde.battle_outcome,
				"si_hit": horde.assault_si_hit,
				"new_si": int(si_result["new_si"]),
				"breach": true,
				"incursion_topic_id": topic.topic_id,
			})
		else:
			results.append({
				"province_id": horde.target_province_id,
				"outcome": horde.battle_outcome,
				"si_hit": horde.assault_si_hit,
				"new_si": int(si_result["new_si"]),
				"breach": false,
			})

	return results


# -- Horde Rolls (s2.4.4–s2.4.8 — LOCKED) ------------------------------------

## Fires every HORDE_ROLL_SEASON_INTERVAL seasons when a season change occurs.
## Season count is tracked in season_meta["horde_season_count"].
## On a successful roll a HordeData is generated and appended to active_hordes.
## On a failed roll the global strength counter increments.
## Returns a dict describing what happened; empty dict if no roll fired.
static func _process_horde_rolls(
	current_season: int,
	prev_season: int,
	active_hordes: Array[HordeData],
	horde_strength_counters: Dictionary,
	last_targeted_province_id: Array[int],
	settlements: Array[SettlementData],
	provinces: Dictionary,
	dice: DiceEngine,
	ic_day: int,
	season_meta: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
) -> Dictionary:
	if current_season == prev_season:
		return {}

	# Increment season counter.
	var season_count: int = int(season_meta.get("horde_season_count", 0)) + 1
	season_meta["horde_season_count"] = season_count

	# Roll only fires every HORDE_ROLL_SEASON_INTERVAL seasons.
	if season_count % HordeSystem.HORDE_ROLL_SEASON_INTERVAL != 0:
		return {"roll_fired": false, "season_count": season_count}

	# Gather Wall Tower province IDs.
	var tower_province_ids: Array[int] = []
	for s: SettlementData in settlements:
		if s.settlement_type == Enums.SettlementType.WALL_TOWER:
			if not (s.province_id in tower_province_ids):
				tower_province_ids.append(s.province_id)

	# No towers — no horde (Horde must target a Wall Tower per s2.4.4).
	if tower_province_ids.is_empty():
		return {"roll_fired": true, "horde_formed": false, "reason": "no_wall_towers"}

	if HordeSystem.roll_horde_fires(dice):
		var last_pid: int = last_targeted_province_id[0]
		var horde: HordeData = HordeSystem.generate_horde(
			tower_province_ids, last_pid, horde_strength_counters, dice, ic_day
		)
		# Generate the Oni if the invasion type requires one.
		if horde.has_oni:
			horde.oni_data = OniGenerator.generate(dice, ic_day)
		last_targeted_province_id[0] = horde.target_province_id
		active_hordes.append(horde)
		# Generate a horde-sighted topic (Tier 3, POLITICAL category,
		# MILITARY topic_type) for the targeted tower's province.
		var topic := TopicData.new()
		topic.topic_id = next_topic_id[0]
		next_topic_id[0] += 1
		topic.slug = "horde_sighted_p%d_d%d" % [horde.target_province_id, ic_day]
		topic.topic_type = "military"
		topic.category = TopicData.Category.POLITICAL
		topic.tier = TopicData.Tier.TIER_3
		topic.momentum = 30.0
		topic.ic_day_created = ic_day
		var province: Variant = provinces.get(horde.target_province_id, null)
		if province is ProvinceData:
			topic.clan_involved = (province as ProvinceData).clan
		active_topics.append(topic)
		return {
			"roll_fired": true,
			"horde_formed": true,
			"invasion_type": horde.invasion_type,
			"target_province_id": horde.target_province_id,
			"strength_at_formation": horde.strength_at_formation,
			"company_count": horde.companies.size(),
			"has_oni": horde.has_oni,
			"has_spawn": horde.has_spawn,
			"topic_id": topic.topic_id,
		}
	else:
		HordeSystem.increment_strength_counter(horde_strength_counters, tower_province_ids)
		return {
			"roll_fired": true,
			"horde_formed": false,
			"strength_counter": HordeSystem.get_strength_counter(horde_strength_counters),
		}


static func _decay_all_knowledge(
	characters: Array[L5RCharacterData],
	current_season: int,
) -> void:
	for c: L5RCharacterData in characters:
		InformationSystem.decay_confidence(c, current_season)


# -- Miya's Blessing Follow-up (s11.5b §7) ------------------------------------
#
# Reads the blessing result from the season's resource_tick, then:
#   - Generates Tier 4 topics for each blessed province (success path) OR a
#     suspension topic (Tier 4 first year, Tier 3 grievance after 3+ years).
#   - Applies disposition deltas: blessed-province lord toward Miya rep +2
#     and toward Emperor +1 on success; Miya rep toward Emperor -3 on
#     suspension. Same-clan ripple and per-clan-champion penalties are
#     deferred until the clan→champion mapping is consistent.
#   - Updates season_meta["consecutive_blessing_suspensions"] for the
#     escalation thresholds.
#   - Applies -1 stability to every Need Score > 0 province on suspension
#     (penalty doubles after 2 consecutive years).

static func _process_miya_blessing_followup(
	seasonal_result: Dictionary,
	miya_inputs: Dictionary,
	provinces: Dictionary,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	season_meta: Dictionary,
) -> void:
	var resource_tick: Dictionary = seasonal_result.get("resource_tick", {})
	var blessing: Dictionary = resource_tick.get("miya_blessing", {})
	if blessing.is_empty():
		return

	var miya_rep_id: int = int(miya_inputs.get("miya_representative_id", -1))
	var emperor_id: int = int(miya_inputs.get("emperor_id", -1))

	if blessing.get("fired", false):
		# Success path — reset the suspension counter, generate per-province
		# topics, apply disposition deltas.
		season_meta["consecutive_blessing_suspensions"] = 0
		var selected_ids: Array = blessing.get("selected_province_ids", [])
		for pid in selected_ids:
			var prov: ProvinceData = provinces.get(pid)
			if prov == null:
				continue
			_create_blessing_topic(
				prov, active_topics, next_topic_id, ic_day, "delivered"
			)
			_apply_blessing_disposition(
				prov, characters_by_id, miya_rep_id, emperor_id
			)
		return

	if not blessing.get("suspended", false):
		return

	# Suspension path — count, generate topic, apply penalties.
	var suspended_count: int = int(season_meta.get("consecutive_blessing_suspensions", 0)) + 1
	season_meta["consecutive_blessing_suspensions"] = suspended_count

	var reason: String = blessing.get("suspension_reason", "")
	var topic_tier: TopicData.Tier = TopicData.Tier.TIER_4
	if suspended_count >= 3:
		# Miya daimyo raises a formal grievance — escalates to Tier 3.
		topic_tier = TopicData.Tier.TIER_3
	_create_suspension_topic(active_topics, next_topic_id, ic_day, reason, topic_tier)

	# -1 stability to every Need Score > 0 province (doubled at 2+
	# consecutive years per §7.2). Read need scores from blessing result if
	# present; otherwise scan provinces for any non-stable, non-blessed.
	var stab_penalty: int = -1
	if suspended_count >= 2:
		stab_penalty = -2
	for pid in provinces:
		var p: ProvinceData = provinces[pid]
		# Quick proxy for "Need Score > 0": stability below stable threshold
		# OR active insurgency. Avoids requiring caller to pass full need scores.
		if p.stability < 76.0 or p.active_insurgency_id >= 0:
			p.stability = clampf(p.stability + float(stab_penalty), 0.0, 100.0)

	if miya_rep_id >= 0 and emperor_id >= 0:
		var miya: L5RCharacterData = characters_by_id.get(miya_rep_id)
		if miya != null:
			var current: int = int(miya.disposition_values.get(emperor_id, 0))
			miya.disposition_values[emperor_id] = clampi(current - 3, -100, 100)

	# Clan Champion -1 disposition toward Emperor on suspension (s11.5b §7.2).
	# Proxy: highest-status character per clan with lord_id == -1.
	if emperor_id >= 0:
		var champions: Dictionary = {}
		for cid: int in characters_by_id:
			var c: L5RCharacterData = characters_by_id[cid]
			if c == null or c.clan == "" or c.character_id == emperor_id:
				continue
			if c.lord_id != -1:
				continue
			var existing: L5RCharacterData = champions.get(c.clan)
			if existing == null or c.status > existing.status:
				champions[c.clan] = c
		for clan_name: String in champions:
			var champ: L5RCharacterData = champions[clan_name]
			var cur: int = int(champ.disposition_values.get(emperor_id, 0))
			champ.disposition_values[emperor_id] = clampi(
				cur + MiyaBlessingSystem.DISP_EMPIRE_TOWARD_EMPEROR_ON_SUSPENSION, -100, 100
			)


static func _create_blessing_topic(
	prov: ProvinceData,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	variant: String,
) -> void:
	var topic: TopicData = TopicData.new()
	topic.topic_id = next_topic_id[0]
	next_topic_id[0] += 1
	topic.slug = "miya_blessing_%s_p%d_d%d" % [variant, prov.province_id, ic_day]
	topic.title = "Miya's Blessing — %s" % prov.province_name
	topic.topic_type = "miya_blessing"
	topic.variant = variant
	topic.tier = TopicData.Tier.TIER_4
	topic.category = TopicData.Category.POLITICAL
	topic.momentum = 11.0  # Minor topic — broadcasts to affected province.
	topic.provinces_affected = [prov.province_id]
	topic.clan_involved = prov.clan
	topic.subject_role = "BENEFICIARY"
	topic.ic_day_created = ic_day
	active_topics.append(topic)


static func _create_suspension_topic(
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	reason: String,
	tier: TopicData.Tier,
) -> void:
	var topic: TopicData = TopicData.new()
	topic.topic_id = next_topic_id[0]
	next_topic_id[0] += 1
	var variant: String = ("suspended_%s" % reason) if reason != "" else "suspended"
	topic.slug = "miya_blessing_%s_d%d" % [variant, ic_day]
	if reason == "tyrant_archetype":
		topic.title = "Miya's Blessing Denied by Imperial Order"
	else:
		topic.title = "Miya's Blessing Suspended — Imperial Reserves Insufficient"
	topic.topic_type = "miya_blessing"
	topic.variant = variant
	topic.tier = tier
	topic.category = TopicData.Category.POLITICAL
	topic.momentum = 26.0 if tier == TopicData.Tier.TIER_3 else 11.0
	topic.subject_role = "PERPETRATOR"   # Emperor / Imperial decision
	topic.ic_day_created = ic_day
	active_topics.append(topic)


static func _apply_blessing_disposition(
	prov: ProvinceData,
	characters_by_id: Dictionary,
	miya_rep_id: int,
	emperor_id: int,
) -> void:
	## Apply +2 toward Miya rep from province lord AND all same-clan lords.
	## Apply +1 toward Emperor from province lord only.
	var lord: L5RCharacterData = _find_province_lord(prov, characters_by_id)
	if lord == null:
		return
	if emperor_id >= 0:
		var current_emp: int = int(lord.disposition_values.get(emperor_id, 0))
		lord.disposition_values[emperor_id] = clampi(current_emp + 1, -100, 100)
	if miya_rep_id >= 0:
		for cid: int in characters_by_id:
			var c: L5RCharacterData = characters_by_id[cid]
			if c == null or c.clan != prov.clan:
				continue
			if c.status < 4.0:
				continue
			var cur: int = int(c.disposition_values.get(miya_rep_id, 0))
			c.disposition_values[miya_rep_id] = clampi(cur + 2, -100, 100)


static func _find_province_lord(
	prov: ProvinceData,
	characters_by_id: Dictionary,
) -> L5RCharacterData:
	# Highest-status character whose clan matches and (if set) family matches.
	# This is a placeholder until province → daimyo linkage is explicit on
	# ProvinceData.
	var best: L5RCharacterData = null
	for cid: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[cid]
		if c == null:
			continue
		if prov.clan != "" and c.clan != prov.clan:
			continue
		if prov.family != "" and c.family != prov.family:
			continue
		if best == null or c.status > best.status:
			best = c
	return best


# -- Famine Crisis Processing (s16.2) ------------------------------------------
#
# Reads starvation_changes from the seasonal resource tick. Generates famine
# crisis topics for provinces at HUNGER or FAMINE. Tracks recovery: 10
# consecutive seasons at positive Rice balance resolves the crisis.

const _FAMINE_RECOVERY_THRESHOLD: int = 10
const _FAMINE_HUNGER_MOMENTUM: float = 25.0
const _FAMINE_FAMINE_MOMENTUM: float = 50.0


static func _process_famine_crises(
	seasonal_result: Dictionary,
	provinces: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	season_meta: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var tick: Dictionary = seasonal_result.get("resource_tick", {})
	var starvation: Dictionary = tick.get("starvation_changes", {})
	if starvation.is_empty():
		return results

	if not season_meta.has("_famine_tracking"):
		season_meta["_famine_tracking"] = {}
	var tracking: Dictionary = season_meta["_famine_tracking"]

	var starving_by_clan: Dictionary = {}
	var recovering_pids: Array[int] = []

	for pid: Variant in starvation:
		var province_id: int = int(pid)
		var starv: Dictionary = starvation[pid]
		var stage: int = starv.get("stage", 0)
		var is_starving: bool = stage >= ResourceTick.StarvationStage.HUNGER

		if is_starving:
			tracking.erase(province_id)
			var prov_data: Variant = provinces.get(province_id, null)
			var clan: String = ""
			if prov_data is ProvinceData:
				clan = prov_data.clan
			if not starving_by_clan.has(clan):
				starving_by_clan[clan] = []
			starving_by_clan[clan].append({"province_id": province_id, "stage": stage})
		else:
			recovering_pids.append(province_id)

	for clan: String in starving_by_clan:
		var entries: Array = starving_by_clan[clan]
		var existing_clan_topic: TopicData = _find_clan_famine_topic(clan, active_topics)

		if entries.size() >= 2 or existing_clan_topic != null:
			if existing_clan_topic == null:
				var all_pids: Array[int] = []
				for e: Dictionary in entries:
					all_pids.append(int(e["province_id"]))
				_absorb_provincial_famine_topics(clan, active_topics)
				var topic: TopicData = _create_famine_topic_multi(
					all_pids, clan, next_topic_id, ic_day,
				)
				active_topics.append(topic)
				results.append({
					"clan": clan,
					"province_ids": all_pids,
					"action": "created_clan",
					"topic_id": topic.topic_id,
					"tier": TopicData.Tier.TIER_2,
				})
			else:
				for e: Dictionary in entries:
					var pid_i: int = int(e["province_id"])
					if pid_i not in existing_clan_topic.provinces_affected:
						existing_clan_topic.provinces_affected.append(pid_i)
						results.append({
							"clan": clan,
							"province_id": pid_i,
							"action": "added_to_clan_topic",
							"topic_id": existing_clan_topic.topic_id,
						})
		else:
			var entry: Dictionary = entries[0]
			var province_id: int = int(entry["province_id"])
			var stage: int = int(entry["stage"])
			if not _has_active_famine_topic(province_id, active_topics):
				var tier: int = TopicData.Tier.TIER_3
				var momentum: float = _FAMINE_HUNGER_MOMENTUM
				if stage >= ResourceTick.StarvationStage.FAMINE:
					tier = TopicData.Tier.TIER_2
					momentum = _FAMINE_FAMINE_MOMENTUM
				var topic: TopicData = _create_famine_topic(
					province_id, clan, tier, momentum,
					next_topic_id, ic_day,
				)
				active_topics.append(topic)
				results.append({
					"province_id": province_id,
					"action": "created",
					"topic_id": topic.topic_id,
					"tier": tier,
					"stage": stage,
				})

	for province_id: int in recovering_pids:
		var topic: TopicData = _find_famine_topic_for_province(province_id, active_topics)
		if topic == null:
			tracking.erase(province_id)
			continue
		var count: int = tracking.get(province_id, 0) + 1
		tracking[province_id] = count
		if count >= _FAMINE_RECOVERY_THRESHOLD:
			tracking.erase(province_id)
			if topic.provinces_affected.size() > 1:
				topic.provinces_affected.erase(province_id)
				results.append({
					"province_id": province_id,
					"action": "province_recovered",
					"topic_id": topic.topic_id,
				})
			else:
				topic.resolved = true
				topic.momentum = 0.0
				results.append({
					"province_id": province_id,
					"action": "resolved",
					"recovery_ticks": count,
				})

	return results


static func _has_active_famine_topic(
	province_id: int,
	active_topics: Array[TopicData],
) -> bool:
	for t: TopicData in active_topics:
		if t.topic_type == "famine" and not t.resolved:
			if province_id in t.provinces_affected:
				return true
	return false


static func _absorb_provincial_famine_topics(
	clan: String,
	active_topics: Array[TopicData],
) -> void:
	for t: TopicData in active_topics:
		if t.topic_type == "famine" and not t.resolved:
			if t.variant == "provincial_famine" and t.clan_involved == clan:
				t.resolved = true
				t.momentum = 0.0


static func _find_famine_topic_for_province(
	province_id: int,
	active_topics: Array[TopicData],
) -> TopicData:
	for t: TopicData in active_topics:
		if t.topic_type == "famine" and not t.resolved:
			if province_id in t.provinces_affected:
				return t
	return null


static func _find_clan_famine_topic(
	clan: String,
	active_topics: Array[TopicData],
) -> TopicData:
	for t: TopicData in active_topics:
		if t.topic_type == "famine" and not t.resolved:
			if t.variant == "clan_famine" and t.clan_involved == clan:
				return t
	return null


static func _create_famine_topic(
	province_id: int,
	clan: String,
	tier: int,
	momentum: float,
	next_topic_id: Array[int],
	ic_day: int,
) -> TopicData:
	var topic: TopicData = TopicData.new()
	topic.topic_id = next_topic_id[0]
	next_topic_id[0] += 1
	topic.slug = "famine_province_%d_d%d" % [province_id, ic_day]
	topic.title = "Famine in Province %d" % province_id
	topic.topic_type = "famine"
	topic.variant = "provincial_famine"
	topic.tier = tier as TopicData.Tier
	topic.category = TopicData.Category.POLITICAL
	topic.clan_involved = clan
	topic.provinces_affected = [province_id]
	topic.ic_day_created = ic_day
	topic.momentum = momentum
	return topic


static func _create_famine_topic_multi(
	province_ids: Array[int],
	clan: String,
	next_topic_id: Array[int],
	ic_day: int,
) -> TopicData:
	var topic: TopicData = TopicData.new()
	topic.topic_id = next_topic_id[0]
	next_topic_id[0] += 1
	topic.slug = "famine_clan_%s_d%d" % [clan.to_lower(), ic_day]
	topic.title = "Famine across %s lands" % clan
	topic.topic_type = "famine"
	topic.variant = "clan_famine"
	topic.tier = TopicData.Tier.TIER_2
	topic.category = TopicData.Category.POLITICAL
	topic.clan_involved = clan
	topic.provinces_affected = province_ids.duplicate()
	topic.ic_day_created = ic_day
	topic.momentum = _FAMINE_FAMINE_MOMENTUM
	return topic


# -- Crime Detection (s57.47) --------------------------------------------------

static func _process_crime_detection(
	results: Array,
	characters_by_id: Dictionary,
	crime_records: Array[CrimeRecord],
	ic_day: int,
	next_case_id: Array[int],
	active_topics: Array[TopicData] = [],
	next_topic_id: Array[int] = [1000],
	world_states: Dictionary = {},
) -> Array[Dictionary]:
	var crime_results: Array[Dictionary] = []

	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		var effects: Dictionary = r.get("effects", {})
		if not effects.get("detection_risk", false):
			continue

		var char_id: int = r.get("character_id", -1)
		var character: L5RCharacterData = characters_by_id.get(char_id)
		if character == null:
			continue

		var action_id: String = r.get("action_id", "")
		var crime_type: int = _action_to_crime_type(action_id)
		if crime_type < 0:
			continue

		var case_id: int = next_case_id[0]
		next_case_id[0] = case_id + 1
		var location: String = character.physical_location
		var target_id: int = r.get("target_npc_id", -1)

		var witnesses: Array[int] = _get_witnesses_at_location(
			char_id, location, characters_by_id, world_states
		)

		var record: CrimeRecord = CrimeSystem.create_crime_record(
			case_id, crime_type, char_id, location, ic_day, target_id,
			0, witnesses
		)
		crime_records.append(record)

		var at_act: Dictionary = CrimeSystem.apply_at_act_consequences(character, crime_type)

		var crime_topic: TopicData = _create_crime_topic(
			record, character, ic_day, next_topic_id
		)
		if crime_topic != null:
			active_topics.append(crime_topic)
			_seed_crime_topic_to_knowers(
				crime_topic, record, characters_by_id
			)

		crime_results.append({
			"case_id": case_id,
			"character_id": char_id,
			"crime_type": crime_type,
			"action_id": action_id,
			"honor_delta": at_act.get("honor_delta", 0.0),
			"topic_id": crime_topic.topic_id if crime_topic != null else -1,
			"witness_count": witnesses.size(),
		})

	return crime_results


static func _action_to_crime_type(action_id: String) -> int:
	match action_id:
		"EAVESDROP", "SEARCH_QUARTERS", "INTERCEPT_LETTER":
			return Enums.CrimeType.DISHONORABLE_CONDUCT
		"BRIBE_FOR_INFO":
			return Enums.CrimeType.SKIMMING
		"FABRICATE_SECRET":
			return Enums.CrimeType.DISHONORABLE_CONDUCT
	return -1


# -- Crime Topic Creation ------------------------------------------------------

static func _create_crime_topic(
	record: CrimeRecord,
	perpetrator: L5RCharacterData,
	ic_day: int,
	next_topic_id: Array[int],
) -> TopicData:
	var crime_name: String = InvestigationSystem.CRIME_TYPE_NAMES.get(
		record.crime_type, "Crime"
	)
	var title: String = "Crime reported: %s at %s" % [crime_name, record.location]

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] = topic_id + 1

	# Momentum starts at 0 — crime topics do NOT broadcast globally.
	# They spread only through witnesses/victims via conversations.
	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id,
		title,
		TopicData.Tier.TIER_4,
		TopicData.Category.LEGAL,
		ic_day,
		0.0,
		[],
		perpetrator.clan,
		"",
		-1,
		"crime",
		crime_name.to_lower().replace(" ", "_"),
	)
	topic.slug = "crime_case_%d" % record.case_id
	return topic


static func _get_witnesses_at_location(
	perpetrator_id: int,
	location: String,
	characters_by_id: Dictionary,
	world_states: Dictionary,
) -> Array[int]:
	var witnesses: Array[int] = []
	for cid: int in characters_by_id:
		if cid == perpetrator_id:
			continue
		var c: L5RCharacterData = characters_by_id[cid]
		if c.physical_location == location:
			witnesses.append(cid)
	return witnesses


static func _seed_crime_topic_to_knowers(
	topic: TopicData,
	record: CrimeRecord,
	characters_by_id: Dictionary,
) -> void:
	for witness_id: int in record.witnesses:
		var witness: L5RCharacterData = characters_by_id.get(witness_id)
		if witness != null and topic.topic_id not in witness.topic_pool:
			witness.topic_pool.append(topic.topic_id)
	if record.victim_id >= 0:
		var victim: L5RCharacterData = characters_by_id.get(record.victim_id)
		if victim != null and topic.topic_id not in victim.topic_pool:
			victim.topic_pool.append(topic.topic_id)


# -- UPHOLD_LAW Magistrate Scan (s57.16.9) ------------------------------------

static func _process_uphold_law_scan(
	characters: Array[L5RCharacterData],
	objectives_map: Dictionary,
	crime_records: Array[CrimeRecord],
	active_topics: Array[TopicData],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for character: L5RCharacterData in characters:
		var objectives: Dictionary = objectives_map.get(character.character_id, {})
		var standing: Dictionary = objectives.get("standing", {})
		if standing.get("need_type", "") != "UPHOLD_LAW":
			continue
		if standing.has("active_case") and not standing["active_case"].is_empty():
			continue

		var activated: Dictionary = InvestigationSystem.scan_for_crime_topics(
			character, standing, crime_records, active_topics
		)
		if not activated.is_empty():
			results.append({
				"magistrate_id": character.character_id,
				"case_id": activated.get("case_id", -1),
			})

	return results


# -- Witness PROBE Evidence (s11.3.13e) ----------------------------------------

static func _check_witness_evidence(
	prober_id: int,
	target_id: int,
	quality: int,
	crime_records: Array[CrimeRecord],
	objectives_map: Dictionary,
) -> Dictionary:
	var objectives: Dictionary = objectives_map.get(prober_id, {})
	var standing: Dictionary = objectives.get("standing", {})
	var active_case: Dictionary = standing.get("active_case", {})
	if active_case.is_empty():
		var primary: Dictionary = objectives.get("primary", {})
		active_case = primary if primary.get("need_type", "") == "INVESTIGATE_CRIME" else {}
	if active_case.is_empty():
		return {}

	var case_id: int = active_case.get("case_id", -1)
	if case_id < 0:
		return {}

	for record: CrimeRecord in crime_records:
		if record.case_id != case_id:
			continue
		return InvestigationSystem.process_witness_interview(
			record, target_id, quality, active_case
		)
	return {}


# -- Lord Death / Orphaned Objectives (s55.33) --------------------------------

static func _process_lord_deaths(
	death_events: Array[Dictionary],
	characters: Array[L5RCharacterData],
	objectives_map: Dictionary,
	successor_map: Dictionary,
	active_successions: Array[SuccessionData] = [],
	next_succession_id: Array[int] = [1],
	characters_by_id: Dictionary = {},
	current_tick: int = 0,
	active_topics: Array[TopicData] = [],
	next_topic_id: Array[int] = [1000],
) -> Array[Dictionary]:
	if death_events.is_empty():
		return []

	var all_results: Array[Dictionary] = []
	for event: Dictionary in death_events:
		var dead_lord_id: int = event.get("character_id", -1)
		if dead_lord_id < 0:
			continue
		if not event.get("is_lord", false):
			continue

		var successor_id: int = successor_map.get(dead_lord_id, -1)

		var orphan_results: Array[Dictionary] = OrphanedObjectives.process_lord_death(
			characters, dead_lord_id, successor_id, objectives_map
		)

		for result: Dictionary in orphan_results:
			var vassal_id: int = result.get("vassal_id", -1)
			var report_target: int = result.get("report_target_id", -1)
			if vassal_id < 0:
				continue

			var vassal: L5RCharacterData = null
			for c: L5RCharacterData in characters:
				if c.character_id == vassal_id:
					vassal = c
					break
			if vassal == null:
				continue

			var report_need: Dictionary = OrphanedObjectives.generate_report_need(
				vassal, report_target
			)
			if not report_need.is_empty():
				result["report_need"] = report_need

		all_results.append_array(orphan_results)

		# Trigger succession for the deceased lord
		var deceased: L5RCharacterData = characters_by_id.get(dead_lord_id)
		if deceased == null:
			continue

		var position_tier: Enums.LordRank = event.get(
			"position_tier", Enums.LordRank.PROVINCIAL_DAIMYO
		)
		var suspicious: bool = event.get("suspicious_death", false)
		var cause: SuccessionData.VacancyCause = SuccessionData.VacancyCause.DEATH

		if SuccessionSystem.is_phoenix_champion_succession(deceased.clan, position_tier):
			continue
		if SuccessionSystem.is_dragon_togashi_removal(deceased.clan, position_tier):
			continue

		var succession := SuccessionSystem.trigger_succession(
			deceased, cause, position_tier, current_tick, suspicious
		)
		succession.succession_id = next_succession_id[0]
		next_succession_id[0] += 1

		var candidates := SuccessionSystem.get_candidates(deceased, characters_by_id)
		for cand in candidates:
			succession.candidate_ids.append(cand["id"])

		succession.confirming_authority_id = SuccessionSystem.find_confirming_authority(
			position_tier, deceased.clan, characters_by_id
		)

		var confirming_disp: int = 0
		if succession.confirming_authority_id >= 0 and candidates.size() > 0:
			var auth: L5RCharacterData = characters_by_id.get(succession.confirming_authority_id)
			if auth != null:
				confirming_disp = auth.disposition_values.get(candidates[0]["id"], 0)

		var is_clean: bool = SuccessionSystem.is_clean_succession(
			succession, candidates, confirming_disp
		)

		if not is_clean:
			succession.state = SuccessionData.SuccessionState.DISPUTED

		var topic_dict: Dictionary = SuccessionSystem.generate_succession_topic(
			succession, not is_clean
		)
		var topic := TopicData.new()
		topic.topic_id = next_topic_id[0]
		next_topic_id[0] += 1
		topic.slug = topic_dict.get("slug", "")
		topic.momentum = topic_dict.get("momentum", 10.0)
		topic.topic_type = "succession"
		topic.variant = topic_dict.get("variant", "clean")
		active_topics.append(topic)

		active_successions.append(succession)

		if is_clean and candidates.size() > 0:
			var auth: L5RCharacterData = characters_by_id.get(succession.confirming_authority_id)
			if auth != null:
				var evaluations := SuccessionSystem.evaluate_all_candidates(
					auth, candidates
				)
				if evaluations.size() > 0:
					var chosen_id: int = evaluations[0]["candidate_id"]
					SuccessionSystem.confirm_successor(succession, chosen_id)
					successor_map[dead_lord_id] = chosen_id

					var chosen: L5RCharacterData = characters_by_id.get(chosen_id)
					if chosen != null:
						SuccessionSystem.apply_successor_inheritance(chosen, deceased)

	return all_results


static func _process_successions(
	active_successions: Array[SuccessionData],
	characters_by_id: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for succ in active_successions:
		if succ.state == SuccessionData.SuccessionState.CONFIRMED:
			continue
		if succ.state == SuccessionData.SuccessionState.RESOLVED:
			continue

		var max_dur: int = SuccessionSystem.DISPUTED_MAX_TICKS
		if succ.state == SuccessionData.SuccessionState.PENDING:
			max_dur = SuccessionSystem.CLEAN_SUCCESSION_MAX_TICKS

		var tick_result := SuccessionSystem.process_tick(succ, max_dur)
		if tick_result["expired"]:
			var candidates := _rebuild_candidates(succ, characters_by_id)
			if candidates.size() > 0:
				var auth_id: int = succ.confirming_authority_id
				var auth: L5RCharacterData = characters_by_id.get(auth_id)
				if auth != null:
					var evals := SuccessionSystem.evaluate_all_candidates(auth, candidates)
					if evals.size() > 0:
						SuccessionSystem.confirm_successor(succ, evals[0]["candidate_id"])
				else:
					SuccessionSystem.confirm_successor(succ, candidates[0]["id"])
			results.append({"succession_id": succ.succession_id, "expired": true, "successor_id": succ.successor_id})

	return results


static func _rebuild_candidates(
	succ: SuccessionData,
	characters_by_id: Dictionary,
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	for cid in succ.candidate_ids:
		var c: L5RCharacterData = characters_by_id.get(cid)
		if c != null and not CharacterStats.is_dead(c):
			candidates.append({"id": cid, "priority": SuccessionSystem.CandidatePriority.LORD_SELECTS, "character": c})
	return candidates


# -- Commitment Deadlines (s55.31) --------------------------------------------

static func _process_commitment_deadlines(
	commitments: Array[CommitmentData],
	ic_day: int,
	characters_by_id: Dictionary,
) -> Array[Dictionary]:
	if commitments.is_empty():
		return []
	var checker: Callable = func(_c: CommitmentData) -> bool: return false
	return CommitmentRegistry.process_deadlines(
		commitments, ic_day, checker, characters_by_id, characters_by_id
	)


# -- Topic Propagation Wiring --------------------------------------------------

static func _wire_discussion_counts(
	conversation_results: Array[Dictionary],
	active_topics: Array[TopicData],
) -> void:
	var discussed_ids: Array[int] = []
	for result: Dictionary in conversation_results:
		var topic_a: int = result.get("topic_shared_by_a", -1)
		var topic_b: int = result.get("topic_shared_by_b", -1)
		if topic_a >= 0:
			discussed_ids.append(topic_a)
		if topic_b >= 0:
			discussed_ids.append(topic_b)
	if not discussed_ids.is_empty():
		TopicMomentumSystem.increment_discussion_counts(active_topics, discussed_ids)


static func _compute_positions_from_conversations(
	conversation_results: Array[Dictionary],
	active_topics: Array[TopicData],
	characters_by_id: Dictionary,
) -> void:
	var topic_map: Dictionary = {}
	for t: TopicData in active_topics:
		topic_map[t.topic_id] = t

	for result: Dictionary in conversation_results:
		var char_a_id: int = result.get("char_a_id", -1)
		var char_b_id: int = result.get("char_b_id", -1)
		var topic_a: int = result.get("topic_shared_by_a", -1)
		var topic_b: int = result.get("topic_shared_by_b", -1)
		var transferred_to_b: bool = result.get("transferred_to_b", false)
		var transferred_to_a: bool = result.get("transferred_to_a", false)

		if transferred_to_b and topic_a >= 0 and topic_map.has(topic_a):
			var char_b: L5RCharacterData = characters_by_id.get(char_b_id)
			if char_b != null and not char_b.topic_positions.has(topic_a):
				var pos: float = TopicMomentumSystem.calculate_starting_position(
					topic_map[topic_a], char_b.disposition_values,
					char_b.bushido_virtue, char_b.shourido_virtue
				)
				char_b.topic_positions[topic_a] = pos

		if transferred_to_a and topic_b >= 0 and topic_map.has(topic_b):
			var char_a: L5RCharacterData = characters_by_id.get(char_a_id)
			if char_a != null and not char_a.topic_positions.has(topic_b):
				var pos: float = TopicMomentumSystem.calculate_starting_position(
					topic_map[topic_b], char_a.disposition_values,
					char_a.bushido_virtue, char_a.shourido_virtue
				)
				char_a.topic_positions[topic_b] = pos


static func _compute_positions_from_broadcast(
	broadcast_results: Array[Dictionary],
	active_topics: Array[TopicData],
	characters_by_id: Dictionary,
) -> void:
	var topic_map: Dictionary = {}
	for t: TopicData in active_topics:
		topic_map[t.topic_id] = t

	for result: Dictionary in broadcast_results:
		var char_id: int = result.get("character_id", -1)
		var topic_id: int = result.get("topic_id", -1)
		var character: L5RCharacterData = characters_by_id.get(char_id)
		if character == null or not topic_map.has(topic_id):
			continue
		if not character.topic_positions.has(topic_id):
			var pos: float = TopicMomentumSystem.calculate_starting_position(
				topic_map[topic_id], character.disposition_values,
				character.bushido_virtue, character.shourido_virtue
			)
			character.topic_positions[topic_id] = pos


static func _compute_positions_from_letters(
	letter_results: Array[Dictionary],
	active_topics: Array[TopicData],
	characters_by_id: Dictionary,
) -> void:
	var topic_map: Dictionary = {}
	for t: TopicData in active_topics:
		topic_map[t.topic_id] = t

	for result: Dictionary in letter_results:
		if not result.get("topic_transferred", false):
			continue
		var topic_id: int = result.get("topic", -1)
		var recipient_id: int = result.get("recipient_id", -1)
		if topic_id < 0 or not topic_map.has(topic_id):
			continue
		var recipient: L5RCharacterData = characters_by_id.get(recipient_id)
		if recipient == null or recipient.topic_positions.has(topic_id):
			continue
		var pos: float = TopicMomentumSystem.calculate_starting_position(
			topic_map[topic_id], recipient.disposition_values,
			recipient.bushido_virtue, recipient.shourido_virtue
		)
		recipient.topic_positions[topic_id] = pos


static func _build_province_clan_map(provinces: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for pid: int in provinces:
		var prov: ProvinceData = provinces[pid]
		if prov != null:
			result[pid] = prov.clan
	return result


static func _season_to_name(season: int) -> String:
	match season:
		TimeSystem.Season.SPRING: return "spring"
		TimeSystem.Season.SUMMER: return "summer"
		TimeSystem.Season.AUTUMN: return "autumn"
		TimeSystem.Season.WINTER: return "winter"
	return "summer"


# -- Strategic Review (s55.10) -------------------------------------------------

static func _run_strategic_reviews(
	characters: Array[L5RCharacterData],
	objectives_map: Dictionary,
	world_states: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var emperor_id: int = int(world_states.get("emperor_id", -1))
	var emperor_archetype: int = int(world_states.get("emperor_archetype", StrategicReview.EmperorArchetype.IRON))

	for lord: L5RCharacterData in characters:
		if not _is_lord_tier(lord):
			continue
		if lord.character_id == emperor_id and emperor_id >= 0:
			var clan_champions: Array[L5RCharacterData] = _get_clan_champions(characters)
			var directives: Array[Dictionary] = StrategicReview.run_emperor_review(
				lord, emperor_archetype, clan_champions, world_states, objectives_map
			)
			for d: Dictionary in directives:
				results.append(d)
		else:
			var vassals: Array[L5RCharacterData] = _get_vassals(lord, characters)
			var directives: Array[Dictionary] = StrategicReview.run_seasonal_review(
				lord, vassals, objectives_map, world_states
			)
			for d: Dictionary in directives:
				results.append(d)

	return results


static func _get_clan_champions(
	characters: Array[L5RCharacterData],
) -> Array[L5RCharacterData]:
	var champions: Array[L5RCharacterData] = []
	for c: L5RCharacterData in characters:
		if c.status >= 7.0 and c.lord_id == -1:
			champions.append(c)
	return champions


static func _is_lord_tier(character: L5RCharacterData) -> bool:
	return character.status >= 5.0 or character.lord_id == -1


static func _get_vassals(
	lord: L5RCharacterData,
	characters: Array[L5RCharacterData],
) -> Array[L5RCharacterData]:
	return MilitaryHierarchy.get_direct_subordinates(lord.character_id, characters)


# -- Festival Processing (s11.5) ----------------------------------------------

static func _process_festivals(ic_day: int, world_states: Dictionary) -> Dictionary:
	var active_festivals: Array[Dictionary] = FestivalSystem.get_active_festivals(ic_day)
	var effects: Array[String] = FestivalSystem.get_festival_effects(ic_day)
	var rokuyo_name: String = FestivalSystem.get_rokuyo_name(ic_day)
	var is_taian: bool = FestivalSystem.get_taian_bonus(ic_day) > 0
	var is_inauspicious: bool = FestivalSystem.is_inauspicious_for_social(ic_day)
	var is_ceasefire: bool = FestivalSystem.is_ceasefire_day(ic_day)
	var is_labor_halt: bool = FestivalSystem.is_labor_halt_day(ic_day)

	for char_id: int in world_states:
		var ws: Dictionary = world_states[char_id]
		ws["is_ceasefire_day"] = is_ceasefire
		ws["is_labor_halt_day"] = is_labor_halt
		ws["is_taian"] = is_taian
		ws["is_inauspicious_for_social"] = is_inauspicious
		ws["rokuyo"] = rokuyo_name

	return {
		"active_festivals": active_festivals,
		"effects": effects,
		"rokuyo": rokuyo_name,
		"is_taian": is_taian,
		"is_inauspicious": is_inauspicious,
		"is_ceasefire": is_ceasefire,
		"is_labor_halt": is_labor_halt,
		"honor_gain": FestivalSystem.get_honor_gain_festivals(ic_day),
		"glory_gain": FestivalSystem.get_glory_gain_festivals(ic_day),
	}


# -- Cohabitation Disposition (s12.2) ------------------------------------------

static func _apply_cohabitation(
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
) -> void:
	var by_location: Dictionary = {}
	for c: L5RCharacterData in characters:
		var loc: String = c.physical_location
		if loc.is_empty():
			continue
		if not by_location.has(loc):
			by_location[loc] = []
		by_location[loc].append(c.character_id)

	for loc: String in by_location:
		var ids: Array = by_location[loc]
		if ids.size() < 2:
			continue
		for i: int in range(ids.size()):
			for j: int in range(i + 1, ids.size()):
				var id_a: int = ids[i]
				var id_b: int = ids[j]
				var char_a: L5RCharacterData = characters_by_id.get(id_a)
				var char_b: L5RCharacterData = characters_by_id.get(id_b)
				if char_a == null or char_b == null:
					continue
				char_a.cohabitation_days[id_b] = char_a.cohabitation_days.get(id_b, 0) + 1
				char_b.cohabitation_days[id_a] = char_b.cohabitation_days.get(id_a, 0) + 1


# -- Favor Processing (s12.10) ------------------------------------------------

static func _process_favors(
	favors: Array,
	ic_day: int,
	characters_by_id: Dictionary = {},
) -> Dictionary:
	var expired_ids: Array[int] = FavorSystem.process_expirations(favors, ic_day)

	var breach_results: Array[Dictionary] = FavorSystem.process_deadline_breaches(favors, ic_day)

	for breach: Dictionary in breach_results:
		_apply_favor_breach(breach, characters_by_id)

	return {
		"expired_favor_ids": expired_ids,
		"deadline_breaches": breach_results,
	}


static func _apply_favor_breach(
	breach: Dictionary,
	characters_by_id: Dictionary,
) -> void:
	var debtor_id: int = breach.get("debtor_id", -1)
	var creditor_id: int = breach.get("creditor_id", -1)
	var debtor: L5RCharacterData = characters_by_id.get(debtor_id)
	if debtor == null:
		return

	var honor_loss: float = breach.get("honor_loss", 0.0)
	if absf(honor_loss) > 0.001:
		HonorGlorySystem.apply_honor_change(debtor, honor_loss)

	var glory_loss: float = breach.get("glory_loss", 0.0)
	if absf(glory_loss) > 0.001:
		HonorGlorySystem.apply_glory_change(debtor, glory_loss)

	var creditor: L5RCharacterData = characters_by_id.get(creditor_id)
	if creditor != null:
		var disp_change: int = breach.get("disposition_change", 0)
		var disp_floor: int = breach.get("disposition_floor", -100)
		if disp_change != 0:
			var old_val: int = creditor.disposition_values.get(debtor_id, 0)
			var new_val: int = clampi(old_val + disp_change, disp_floor, 100)
			creditor.disposition_values[debtor_id] = new_val

	var witness_loss: int = breach.get("witness_disposition_loss", 0)
	var witness_ids: Array = breach.get("witnesses", [])
	if witness_loss != 0:
		for wid in witness_ids:
			var witness: L5RCharacterData = characters_by_id.get(wid)
			if witness == null or witness.character_id == debtor_id:
				continue
			var old_val: int = witness.disposition_values.get(debtor_id, 0)
			var new_val: int = clampi(old_val + witness_loss, -100, 100)
			witness.disposition_values[debtor_id] = new_val


# -- Travel Processing (s55.29) -----------------------------------------------

static func _process_travel(
	characters: Array[L5RCharacterData],
) -> Array[Dictionary]:
	return TravelSystem.process_travel_tick(characters)


# -- Daily Letter Pass (s57.5) -------------------------------------------------

static func _process_daily_letter_pass(
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	objectives_map: Dictionary,
	scoring_tables: Dictionary,
	world_states: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for character: L5RCharacterData in characters:
		var objectives: Dictionary = objectives_map.get(character.character_id, {})
		if objectives.is_empty():
			continue
		var ctx := NPCDecisionEngine.build_context(character, world_states, characters_by_id)
		var letter_result: Dictionary = NPCDecisionEngine.resolve_daily_letter(
			character, objectives, scoring_tables, ctx
		)
		if not letter_result.is_empty():
			results.append(letter_result)
	return results


# -- Arrival Observation (s55.29.2) --------------------------------------------

static func _process_arrival_observation(
	arrivals: Array[Dictionary],
	characters_by_id: Dictionary,
	current_season: int,
) -> void:
	for arrival: Dictionary in arrivals:
		var char_id: int = arrival.get("character_id", -1)
		var dest: String = arrival.get("destination", "")
		var character: L5RCharacterData = characters_by_id.get(char_id)
		if character == null or dest.is_empty():
			continue

		for other_id: int in characters_by_id:
			if other_id == char_id:
				continue
			var other: L5RCharacterData = characters_by_id[other_id]
			if other.physical_location != dest:
				continue
			# Arriving character observes residents
			if other_id not in character.met_characters:
				character.met_characters.append(other_id)
			InformationSystem.record_location_observation(
				character, other_id, dest, current_season
			)
			# Residents observe the arriving character
			if char_id not in other.met_characters:
				other.met_characters.append(char_id)
			InformationSystem.record_location_observation(
				other, char_id, dest, current_season
			)


# -- Objective Progress Evaluation (s55.29.3) ----------------------------------

static func _evaluate_objective_progress(
	characters: Array[L5RCharacterData],
	objectives_map: Dictionary,
	world_states: Dictionary,
) -> Array[Dictionary]:
	return ObjectiveProgress.evaluate_all_objectives(
		characters, objectives_map, world_states
	)


# -- Historical Modifier Decay (s12.2, season boundary) -----------------------

static func _decay_all_historical_modifiers(
	characters: Array[L5RCharacterData],
	ic_day: int,
) -> void:
	for c: L5RCharacterData in characters:
		for target_id: Variant in c.historical_modifiers:
			var mods: Array = c.historical_modifiers[target_id]
			for mod: Variant in mods:
				if mod is Dictionary:
					var days_elapsed: int = ic_day - mod.get("created_ic_day", 0)
					DispositionSystem.decay_historical_modifier(mod, days_elapsed)


# -- Insurgency Processing (s11.11, season boundary) --------------------------

static func _process_insurgencies(
	insurgencies: Array[InsurgencyData],
	provinces: Dictionary,
	dice_engine: DiceEngine,
	current_season: int,
	next_insurgency_id: Array[int],
	world_states: Dictionary,
) -> Dictionary:
	var ptls: Dictionary = {}
	for pid: int in provinces:
		var prov: ProvinceData = provinces[pid]
		ptls[pid] = prov.province_taint_level

	var per_province_ws: Dictionary = {}
	for pid: int in provinces:
		per_province_ws[pid] = world_states.get(pid, world_states)

	var result: Dictionary = InsurgencySystem.process_season(
		insurgencies, provinces, ptls, dice_engine, current_season,
		next_insurgency_id[0], per_province_ws
	)

	for new_ins: InsurgencyData in result.get("new_insurgencies", []):
		insurgencies.append(new_ins)

	next_insurgency_id[0] = result.get("next_id", next_insurgency_id[0])

	var removed: Array[InsurgencyData] = []
	for ins: InsurgencyData in insurgencies:
		if ins.strength <= 0:
			removed.append(ins)
	for ins: InsurgencyData in removed:
		insurgencies.erase(ins)

	return result


# -- Heir Designation Evaluation (s22.5, season boundary) --------------------

static func _evaluate_heir_designations(
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
) -> void:
	for lord in characters:
		if CharacterStats.is_dead(lord):
			continue
		if not _is_lord_tier(lord):
			continue

		if not SuccessionSystem.should_reevaluate_heir(lord):
			continue

		var proxy := L5RCharacterData.new()
		proxy.character_id = lord.character_id
		proxy.clan = lord.clan
		proxy.family = lord.family
		proxy.children_ids = lord.children_ids
		proxy.sibling_ids = lord.sibling_ids
		proxy.designated_heir_id = lord.designated_heir_id

		var candidates := SuccessionSystem.get_candidates(proxy, characters_by_id)
		if candidates.is_empty():
			continue

		var topics_by_char: Dictionary = {}
		for cand in candidates:
			var cand_id: int = cand["id"]
			var cand_topics: Array[Dictionary] = []
			for t in lord.topic_pool:
				for topic in active_topics:
					if topic.topic_id == t:
						cand_topics.append({"topic_type": topic.topic_type})
						break
			topics_by_char[cand_id] = cand_topics

		var evals := SuccessionSystem.evaluate_all_candidates(
			lord, candidates, "military", topics_by_char
		)
		if evals.size() > 0:
			SuccessionSystem.designate_heir(lord, evals[0]["candidate_id"])


# -- Entanglement Maintenance (s12.8) -----------------------------------------

static func _process_entanglements(
	entanglements: Array[Dictionary],
	ic_day: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var broken: Array[Dictionary] = []

	for ent in entanglements:
		if ent.get("state") == SeductionSystem.EntanglementState.BROKEN:
			continue

		var check: Dictionary = SeductionSystem.check_maintenance(ent, ic_day)
		if check.get("state") == SeductionSystem.EntanglementState.BROKEN:
			ent["state"] = SeductionSystem.EntanglementState.BROKEN
			ent["missed_windows"] = check.get("missed_windows", 3)
			broken.append(ent)
			results.append({
				"entanglement": ent,
				"event": "broken",
				"missed_windows": check.get("missed_windows", 0),
			})
		elif check.get("needs_maintenance", false):
			ent["state"] = check.get("state", SeductionSystem.EntanglementState.NEGLECTED)
			ent["missed_windows"] = check.get("missed_windows", 0)
			results.append({
				"entanglement": ent,
				"event": "neglected",
				"missed_windows": check.get("missed_windows", 0),
			})

	for ent in broken:
		entanglements.erase(ent)

	return results


# -- Bound Character Processing (s12.8) ---------------------------------------

static func _process_bound_states(
	bound_states: Array[Dictionary],
	characters_by_id: Dictionary,
	dice_engine: DiceEngine,
	ic_day: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var freed: Array[Dictionary] = []

	for bs in bound_states:
		var char_id: int = bs.get("character_id", -1)
		var character: L5RCharacterData = characters_by_id.get(char_id)
		if character == null:
			continue

		if bs.get("state") != BoundEscapeSystem.BoundState.BOUND:
			if bs.get("state") == BoundEscapeSystem.BoundState.FREE:
				freed.append(bs)
			continue

		if not BoundEscapeSystem.can_attempt_escape(bs, ic_day):
			continue

		var soh_rank: int = character.skills.get("Sleight of Hand", 0)
		if soh_rank == 0:
			continue

		var r: Dictionary = BoundEscapeSystem.resolve_escape_attempt(
			character, bs, dice_engine, ic_day
		)
		results.append({
			"character_id": char_id,
			"escape_result": r,
			"new_state": bs.get("state"),
		})

	for bs in freed:
		bound_states.erase(bs)

	return results


# -- Military Daily Processing -------------------------------------------------

static func _process_military_daily(
	active_armies: Array[Dictionary],
	active_sieges: Array[Dictionary],
	active_tethers: Array[Dictionary],
	order_states: Array[Dictionary],
	dice_engine: DiceEngine,
	settlements: Array[SettlementData],
	companies: Array[Dictionary] = [],
) -> Dictionary:
	var disband_results: Array[Dictionary] = _process_disbands(
		active_armies, companies, settlements,
	)
	var movement_results: Array[Dictionary] = _process_army_movements(active_armies)
	var retreat_arrival_results: Array[Dictionary] = _process_retreat_arrivals(
		movement_results, active_armies, active_tethers,
	)
	var siege_results: Array[Dictionary] = _process_siege_ticks(
		active_sieges, dice_engine,
	)
	var tether_results: Array[Dictionary] = _process_tether_ticks(
		active_tethers, dice_engine, companies,
	)
	var order_results: Dictionary = _process_order_ticks(order_states)
	var tether_by_army: Dictionary = _build_tether_result_by_army(
		active_tethers, tether_results,
	)
	var deprivation_results: Array[Dictionary] = _process_field_deprivation(
		active_tethers, tether_results,
	)
	var recovery_results: Array[Dictionary] = _process_army_recovery(
		active_armies, tether_by_army, companies,
	)

	return {
		"movement_results": movement_results,
		"retreat_arrival_results": retreat_arrival_results,
		"siege_results": siege_results,
		"tether_results": tether_results,
		"order_results": order_results,
		"deprivation_results": deprivation_results,
		"recovery_results": recovery_results,
		"disband_results": disband_results,
	}


static func _process_army_movements(
	active_armies: Array[Dictionary],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for army: Dictionary in active_armies:
		_initiate_retreat_march(army)
		if not army.get("is_moving", false):
			continue
		var r: Dictionary = ArmyMovementSystem.process_movement_tick(army)
		r["army_id"] = army.get("army_id", -1)
		if r.get("arrived", false):
			var battle_check: Dictionary = ArmyMovementSystem.check_battle_trigger(
				r, active_armies,
			)
			r["battle_check"] = battle_check
			if army.get("retreat_ordered", false):
				r["retreat_arrived"] = true
		results.append(r)
	return results


const _RETREAT_DEFAULT_DAYS: int = 3


static func _process_retreat_arrivals(
	movement_results: Array[Dictionary],
	active_armies: Array[Dictionary],
	active_tethers: Array[Dictionary],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for mr: Dictionary in movement_results:
		if not mr.get("retreat_arrived", false):
			continue
		var army_id: int = mr.get("army_id", -1)
		var army: Dictionary = _find_army_by_id(army_id, active_armies)
		if army.is_empty():
			continue

		army.erase("retreat_ordered")
		army.erase("retreat_target_province")

		var tether_result: Dictionary = _detach_army_tether(army_id, active_tethers)

		results.append({
			"army_id": army_id,
			"arrived_at": mr.get("arrived_at", -1),
			"tether_detached": not tether_result.is_empty(),
			"freed_escort_ids": tether_result.get("freed_escort_ids", []),
		})
	return results


static func _find_army_by_id(
	army_id: int,
	active_armies: Array[Dictionary],
) -> Dictionary:
	for army: Dictionary in active_armies:
		if army.get("army_id", -1) == army_id:
			return army
	return {}


static func _detach_army_tether(
	army_id: int,
	active_tethers: Array[Dictionary],
) -> Dictionary:
	for tether: Dictionary in active_tethers:
		if tether.get("army_id", -1) == army_id and not tether.get("detached", false):
			return SupplyTetherSystem.detach_tether(tether)
	return {}


static func _initiate_retreat_march(army: Dictionary) -> void:
	if not army.get("retreat_ordered", false):
		return
	if army.get("is_moving", false):
		return
	if army.get("disband_ordered", false):
		return
	var target: int = army.get("retreat_target_province", -1)
	if target < 0:
		return
	var current: int = army.get("current_sub_tile", 0)
	army["destination_sub_tile"] = target
	army["path"] = [target] as Array[int]
	army["days_remaining"] = _RETREAT_DEFAULT_DAYS
	army["is_moving"] = true
	army["forced_march"] = false


static func _process_disbands(
	active_armies: Array[Dictionary],
	companies: Array[Dictionary],
	settlements: Array[SettlementData],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for army: Dictionary in active_armies:
		if not army.get("disband_ordered", false):
			continue
		if not army.get("is_active", true):
			continue
		var army_id: int = army.get("army_id", -1)
		var disband_result: Dictionary = {
			"army_id": army_id,
			"clan": army.get("clan_name", army.get("owning_clan", "")),
			"pu_returned": [] as Array[Dictionary],
		}
		for comp: Dictionary in companies:
			if comp.get("army_id", -1) != army_id:
				continue
			var source_province: int = comp.get("source_province_id", -1)
			var health: int = comp.get("current_health", 0)
			if health <= 0:
				continue
			var target_settlement: SettlementData = _find_settlement_for_province(
				source_province, settlements,
			)
			if target_settlement != null:
				var pu_result: Dictionary = PUReconciliation.return_disband_pu(
					target_settlement, health,
				)
				disband_result["pu_returned"].append(pu_result)
		army["is_active"] = false
		results.append(disband_result)
	return results


static func _find_settlement_for_province(
	province_id: int,
	settlements: Array[SettlementData],
) -> SettlementData:
	for s: SettlementData in settlements:
		if s.province_id == province_id:
			return s
	return null


static func _process_siege_ticks(
	active_sieges: Array[Dictionary],
	dice_engine: DiceEngine,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for siege: Dictionary in active_sieges:
		var personality: String = siege.get("personality_tag", "default")
		var r: Dictionary = SiegeSystem.process_siege_tick(
			siege, dice_engine, personality,
		)
		results.append(r)
	return results


static func _process_tether_ticks(
	active_tethers: Array[Dictionary],
	dice_engine: DiceEngine,
	companies: Array[Dictionary],
) -> Array[Dictionary]:
	var companies_by_id: Dictionary = _build_companies_by_id(companies)
	var results: Array[Dictionary] = []
	for tether: Dictionary in active_tethers:
		if tether.get("detached", false):
			continue
		var garrisons: Dictionary = tether.get("garrisons_on_path", {})
		var enemies: Array[int] = []
		for e: Variant in tether.get("enemy_armies_on_path", []):
			enemies.append(int(e))
		var r: Dictionary = SupplyTetherSystem.process_supply_tick(
			dice_engine, tether, garrisons, enemies, companies_by_id,
		)
		r["army_id"] = tether.get("army_id", -1)
		results.append(r)
	return results


static func _build_companies_by_id(
	companies: Array[Dictionary],
) -> Dictionary:
	var result: Dictionary = {}
	for c: Dictionary in companies:
		var cid: int = c.get("company_id", -1)
		if cid >= 0:
			result[cid] = c
	return result


static func _build_tether_result_by_army(
	active_tethers: Array[Dictionary],
	tether_results: Array[Dictionary],
) -> Dictionary:
	var non_detached: Array[Dictionary] = []
	for t: Dictionary in active_tethers:
		if not t.get("detached", false):
			non_detached.append(t)
	var result: Dictionary = {}
	for i: int in range(mini(non_detached.size(), tether_results.size())):
		var army_id: int = non_detached[i].get("army_id", -1)
		if army_id >= 0:
			result[army_id] = tether_results[i]
	return result


static func _process_army_recovery(
	active_armies: Array[Dictionary],
	tether_state_by_army: Dictionary,
	companies: Array[Dictionary],
) -> Array[Dictionary]:
	var companies_by_army: Dictionary = {}
	for c: Dictionary in companies:
		var aid: int = c.get("army_id", -1)
		if aid >= 0:
			if not companies_by_army.has(aid):
				companies_by_army[aid] = []
			companies_by_army[aid].append(c)

	var results: Array[Dictionary] = []
	for army: Dictionary in active_armies:
		var army_id: int = army.get("army_id", -1)
		var is_moving: bool = army.get("is_moving", false)
		if is_moving:
			continue

		var tr: Dictionary = tether_state_by_army.get(army_id, {})
		var overall_state: int = tr.get("overall_state", SupplyTetherSystem.TetherState.SOLID)
		var rice_supplied: bool = overall_state == SupplyTetherSystem.TetherState.SOLID
		var arms_supplied: bool = overall_state == SupplyTetherSystem.TetherState.SOLID
		var arms_tick: int = tr.get("arms_deprivation_tick", 0)

		var army_companies: Array = companies_by_army.get(army_id, [])
		if army_companies.is_empty():
			continue

		var per_company: Array[Dictionary] = []
		for c: Variant in army_companies:
			if not (c is Dictionary):
				continue
			var cd: Dictionary = c
			var cid: int = cd.get("company_id", -1)
			var ut: int = cd.get("unit_type", Enums.CompanyUnitType.PEASANT_LEVY)
			var base: Dictionary = ArmyCombatSystem.UNIT_STATS.get(ut, {})
			if base.is_empty():
				continue

			var health_recovery: int = 0
			var morale_recovery: int = 0
			var arms_recovery: bool = false

			if rice_supplied:
				var max_health: int = base.get("health", 0)
				var cur_health: int = cd.get("current_health", max_health)
				health_recovery = mini(
					ArmyUpkeepSystem.RECOVERY_HEALTH_PER_TICK,
					max_health - cur_health,
				)
				health_recovery = maxi(health_recovery, 0)

				var max_morale: int = base.get("morale", 0)
				var cur_morale: int = cd.get("current_morale", max_morale)
				morale_recovery = mini(
					ArmyUpkeepSystem.RECOVERY_MORALE_PER_TICK,
					max_morale - cur_morale,
				)
				morale_recovery = maxi(morale_recovery, 0)

			if arms_supplied and arms_tick > 1:
				arms_recovery = true

			if health_recovery > 0 or morale_recovery > 0 or arms_recovery:
				per_company.append({
					"company_id": cid,
					"health_recovery": health_recovery,
					"morale_recovery": morale_recovery,
					"arms_tier_recovered": arms_recovery,
				})

		if not per_company.is_empty():
			results.append({
				"army_id": army_id,
				"company_recoveries": per_company,
			})

	return results


static func _process_field_deprivation(
	active_tethers: Array[Dictionary],
	tether_results: Array[Dictionary],
) -> Array[Dictionary]:
	var non_detached: Array[Dictionary] = []
	for t: Dictionary in active_tethers:
		if not t.get("detached", false):
			non_detached.append(t)
	var results: Array[Dictionary] = []
	for i: int in range(mini(non_detached.size(), tether_results.size())):
		var tether: Dictionary = non_detached[i]
		var tr: Dictionary = tether_results[i]
		var rice_tick: int = tr.get("rice_deprivation_tick", 0)
		var arms_tick: int = tr.get("arms_deprivation_tick", 0)

		if rice_tick <= 0 and arms_tick <= 0:
			continue

		var army_id: int = tether.get("army_id", -1)
		var company_ids: Array = tether.get("company_ids", [])
		var rice_effect: Dictionary = ArmyUpkeepSystem.get_rice_deprivation_effect(rice_tick) if rice_tick > 0 else {}
		var arms_effect: Dictionary = ArmyUpkeepSystem.get_arms_deprivation_effect(arms_tick) if arms_tick > 0 else {}
		var per_company: Array[Dictionary] = []

		for cid: Variant in company_ids:
			per_company.append({
				"company_id": int(cid),
				"rice_tick": rice_tick,
				"arms_tick": arms_tick,
				"rice_effect": rice_effect,
				"arms_effect": arms_effect,
			})

		results.append({
			"army_id": army_id,
			"rice_deprivation_tick": rice_tick,
			"arms_deprivation_tick": arms_tick,
			"company_effects": per_company,
		})

	return results


static func _process_order_ticks(
	order_states: Array[Dictionary],
) -> Dictionary:
	var delivered_total: int = 0
	var per_commander: Array[Dictionary] = []
	for os: Dictionary in order_states:
		OrderSystem.reset_daily_orders(os)
		var delivered: Array[Dictionary] = OrderSystem.process_pending_orders(os)
		delivered_total += delivered.size()
		if not delivered.is_empty():
			per_commander.append({
				"commander_id": os.get("commander_id", -1),
				"delivered_count": delivered.size(),
				"delivered_orders": delivered,
			})
	return {
		"total_delivered": delivered_total,
		"per_commander": per_commander,
	}


# -- Military Seasonal Processing -----------------------------------------------

static func _process_military_seasonal(
	companies: Array[Dictionary],
	settlements: Array[SettlementData],
	clans: Dictionary,
	characters_by_id: Dictionary,
	dice_engine: DiceEngine,
	season_name: String,
) -> Dictionary:
	var upkeep_results: Dictionary = _process_army_upkeep(
		companies, settlements, clans,
	)
	var promotion_results: Array[Dictionary] = _process_military_promotions(
		companies, characters_by_id,
	)
	return {
		"upkeep": upkeep_results,
		"promotions": promotion_results,
	}


static func _process_army_upkeep(
	companies: Array[Dictionary],
	settlements: Array[SettlementData],
	clans: Dictionary,
) -> Dictionary:
	var total_rice_cost: float = 0.0
	var total_iron_cost: float = 0.0
	var total_koku_cost: float = 0.0

	var companies_by_clan: Dictionary = {}
	var rice_cost_by_clan: Dictionary = {}
	var koku_cost_by_clan: Dictionary = {}
	for company: Dictionary in companies:
		var unit_type: int = company.get("unit_type", Enums.CompanyUnitType.PEASANT_LEVY)
		var costs: Dictionary = ArmyUpkeepSystem.compute_company_seasonal_costs(unit_type)
		total_rice_cost += costs["rice"]
		total_iron_cost += costs["iron"]
		total_koku_cost += costs["koku"]

		var clan_name: String = company.get("clan_name", "")
		if not clan_name.is_empty():
			if not companies_by_clan.has(clan_name):
				companies_by_clan[clan_name] = []
				rice_cost_by_clan[clan_name] = 0.0
				koku_cost_by_clan[clan_name] = 0.0
			companies_by_clan[clan_name].append(company)
			rice_cost_by_clan[clan_name] += costs["rice"]
			koku_cost_by_clan[clan_name] += costs["koku"]

	var iron_results: Array[Dictionary] = []
	for clan_name: String in companies_by_clan:
		var clan: ClanData = clans.get(clan_name)
		if clan == null:
			continue
		var clan_companies: Array[Dictionary] = []
		for c: Variant in companies_by_clan[clan_name]:
			if c is Dictionary:
				clan_companies.append(c)
		var iron_state: Dictionary = clan.get_meta("iron_state", {}) if clan.has_meta("iron_state") else {}
		var r: Dictionary = ArmyUpkeepSystem.process_iron_upkeep_dict(
			clan_companies, iron_state, clan.arms_stockpile,
		)
		clan.arms_stockpile = maxf(clan.arms_stockpile - r["iron_consumed"], 0.0)
		if not iron_state.is_empty():
			clan.set_meta("iron_state", iron_state)
		iron_results.append({
			"clan": clan_name,
			"iron_consumed": r["iron_consumed"],
			"supplied": r["supplied"],
			"degraded": r["degraded_companies"],
		})

	var settlements_by_province: Dictionary = _build_settlements_by_province(settlements)
	var rice_deducted: float = _deduct_clan_upkeep(
		rice_cost_by_clan, clans, settlements_by_province, "rice_stockpile",
	)
	var koku_deducted: float = _deduct_clan_upkeep(
		koku_cost_by_clan, clans, settlements_by_province, "koku_stockpile",
	)

	return {
		"total_rice_cost": total_rice_cost,
		"total_iron_cost": total_iron_cost,
		"total_koku_cost": total_koku_cost,
		"rice_deducted": rice_deducted,
		"koku_deducted": koku_deducted,
		"company_count": companies.size(),
		"iron_results": iron_results,
	}


static func _process_military_promotions(
	companies: Array[Dictionary],
	characters_by_id: Dictionary,
) -> Array[Dictionary]:
	var units: Array[Dictionary] = []
	for company: Dictionary in companies:
		units.append({
			"unit_id": company.get("company_id", -1),
			"commander_id": company.get("commander_id", -1),
			"rank_needed": Enums.MilitaryRank.CHUI,
		})

	var vacancies: Array[Dictionary] = MilitaryPromotionSystem.find_vacancies(units)
	var results: Array[Dictionary] = []

	for vacancy: Dictionary in vacancies:
		var candidates: Array[Dictionary] = _gather_promotion_candidates(
			vacancy, characters_by_id,
		)
		if candidates.is_empty():
			continue

		var best: Dictionary = MilitaryPromotionSystem.select_best_candidate(
			candidates, vacancy.get("rank_needed", Enums.MilitaryRank.CHUI),
		)
		if best.is_empty():
			continue

		results.append({
			"unit_id": vacancy["unit_id"],
			"rank_needed": vacancy["rank_needed"],
			"promoted_character_id": best.get("character_id", -1),
			"score": best.get("score", 0.0),
		})

	return results


static func _gather_promotion_candidates(
	vacancy: Dictionary,
	characters_by_id: Dictionary,
) -> Array[Dictionary]:
	var candidates: Array[Dictionary] = []
	var rank_needed: int = vacancy.get("rank_needed", Enums.MilitaryRank.CHUI)

	for char_id: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[char_id]
		if c == null:
			continue
		if c.military_rank >= rank_needed:
			continue
		if c.commanded_unit_id >= 0:
			continue

		var battle_skill: int = c.skills.get("Battle", 0)
		candidates.append({
			"character_id": c.character_id,
			"battle_skill": battle_skill,
			"insight_rank": CharacterStats.get_insight_rank(c),
			"school_rank": c.school_rank,
			"glory": c.glory,
			"disposition": 10,
			"personality_virtue": c.primary_virtue,
			"battles_commanded": c.battle_record.get("battles_fought", 0) if c.battle_record is Dictionary else 0,
			"battles_as_chui": c.battle_record.get("battles_as_chui", 0) if c.battle_record is Dictionary else 0,
			"battles_as_taisa": c.battle_record.get("battles_as_taisa", 0) if c.battle_record is Dictionary else 0,
			"is_garrison": c.assigned_company_id >= 0,
		})

	return candidates


# -- Military Effect Post-Processing -------------------------------------------

static func _process_military_effects(
	applied_list: Array,
	settlements: Array[SettlementData],
	characters_by_id: Dictionary,
	companies: Array[Dictionary],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var settlements_by_province: Dictionary = _build_settlements_by_province(settlements)

	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})

		if effects.get("requires_levy_pu", false):
			var r: Dictionary = _apply_levy_pu_effect(applied, settlements)
			if not r.is_empty():
				results.append(r)

		if effects.get("requires_service_assignment", false):
			var r: Dictionary = _apply_service_assignment_effect(
				applied, characters_by_id,
			)
			if not r.is_empty():
				results.append(r)

		if effects.get("requires_battle_resolution", false):
			var r: Dictionary = _apply_battle_pu_reconciliation(
				applied, settlements_by_province,
			)
			if not r.is_empty():
				results.append(r)

	return results


# -- Starvation Warfare Effects ---------------------------------------------------

static func _process_starvation_warfare_effects(
	applied_list: Array,
	characters_by_id: Dictionary,
	trade_routes: Array,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	season_meta: Dictionary,
	active_wars: Array[WarData],
	next_war_id: Array[int],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})

		if effects.get("requires_harvest_destruction", false):
			var r: Dictionary = _apply_harvest_destruction(
				effects, characters_by_id, active_topics,
				next_topic_id, ic_day, season_meta,
			)
			if not r.is_empty():
				results.append(r)

		if effects.get("requires_blockade", false):
			var r: Dictionary = _apply_blockade(
				effects, trade_routes, active_wars, next_war_id, ic_day,
			)
			if not r.is_empty():
				results.append(r)

	return results


static func _apply_harvest_destruction(
	effects: Dictionary,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	season_meta: Dictionary,
) -> Dictionary:
	var province_id: int = effects.get("province_id", -1)
	var ordering_clan: String = effects.get("ordering_clan", "")
	var target_clan: String = effects.get("target_clan", "")

	if province_id < 0 or ordering_clan.is_empty():
		return {}

	StarvationWarfare.apply_harvest_destruction(province_id, season_meta)

	var topic: TopicData = StarvationWarfare.generate_harvest_topic(
		ordering_clan, province_id, next_topic_id, ic_day,
	)
	active_topics.append(topic)

	for id: Variant in characters_by_id:
		var c: L5RCharacterData = characters_by_id[id] as L5RCharacterData
		if c == null:
			continue
		if c.clan == ordering_clan:
			continue
		var event_type: String = "destroyed_harvest" if c.clan == target_clan else "witnessed_harvest_destruction"
		var mod: Dictionary = DispositionSystem.create_historical_modifier(event_type, ic_day)
		if mod.is_empty():
			continue
		if not c.historical_modifiers.has(ordering_clan):
			c.historical_modifiers[ordering_clan] = []
		c.historical_modifiers[ordering_clan].append(mod)

	return {
		"type": "harvest_destruction",
		"province_id": province_id,
		"ordering_clan": ordering_clan,
		"target_clan": target_clan,
		"topic_id": topic.topic_id,
		"honor_change": effects.get("honor_change", 0.0),
		"glory_change": effects.get("glory_change", 0.0),
	}


static func _apply_blockade(
	effects: Dictionary,
	trade_routes: Array,
	active_wars: Array[WarData],
	next_war_id: Array[int],
	ic_day: int,
) -> Dictionary:
	var route_id: int = effects.get("route_id", -1)
	var blocking_clan: String = effects.get("blocking_clan", "")
	var target_clan: String = effects.get("target_clan", "")
	var disruption_reason: String = effects.get("disruption_reason", "")

	if route_id < 0 or blocking_clan.is_empty():
		return {}

	for r: Variant in trade_routes:
		if not (r is TradeRouteData):
			continue
		var route: TradeRouteData = r as TradeRouteData
		if route.route_id == route_id:
			StarvationWarfare.apply_blockade(route, disruption_reason)
			break

	var war_created: bool = false
	if effects.get("triggers_war_status", false) and not target_clan.is_empty():
		var already_at_war: bool = WarSystem.are_clans_at_war(
			active_wars, blocking_clan, target_clan,
		)
		if not already_at_war:
			var war: WarData = WarSystem.declare_war(
				next_war_id[0], blocking_clan, target_clan,
				WarData.AuthorityLevel.PROVINCIAL_RAID,
				-1, -1, ic_day,
			)
			next_war_id[0] += 1
			active_wars.append(war)
			war_created = true

	return {
		"type": "blockade",
		"route_id": route_id,
		"blocking_clan": blocking_clan,
		"target_clan": target_clan,
		"war_created": war_created,
	}


# -- Supply Sharing Effects --------------------------------------------------------

static func _process_supply_sharing(
	applied_list: Array,
	characters_by_id: Dictionary,
	settlements: Array[SettlementData],
	provinces: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})
		if not effects.get("requires_supply_sharing", false):
			continue

		var character_id: int = applied.get("character_id", -1)
		var target_province_id: int = applied.get("target_province_id", -1)
		var character: L5RCharacterData = characters_by_id.get(character_id)
		if character == null or target_province_id < 0:
			continue

		var giver_province_id: int = _find_lord_province_id(character, provinces)
		if giver_province_id < 0 or giver_province_id == target_province_id:
			continue

		var giver_settlement: SettlementData = _find_settlement_for_province(
			giver_province_id, settlements,
		)
		var receiver_settlement: SettlementData = _find_settlement_for_province(
			target_province_id, settlements,
		)
		if giver_settlement == null or receiver_settlement == null:
			continue

		var surplus: float = RiceMarketSystem.compute_surplus(giver_settlement)
		if surplus <= 0.0:
			continue

		var amount: float = surplus * 0.5
		var stage: int = _get_starvation_stage(receiver_settlement)
		if stage <= 0:
			continue

		var share_result: Dictionary = RiceMarketSystem.share_rice(
			character, giver_settlement, receiver_settlement, amount, stage,
		)
		if share_result.get("result", "") == "success":
			results.append({
				"type": "supply_sharing",
				"character_id": character_id,
				"target_province_id": target_province_id,
				"amount": share_result.get("amount", 0.0),
				"honor_gain": share_result.get("honor_gain", 0.0),
				"resolves_famine": share_result.get("resolves_famine", false),
			})

	return results


static func _find_lord_province_id(
	character: L5RCharacterData,
	provinces: Dictionary,
) -> int:
	for pid: Variant in provinces:
		var p: ProvinceData = provinces[pid] as ProvinceData
		if p != null and p.clan == character.clan:
			return p.province_id
	return -1


static func _get_starvation_stage(settlement: SettlementData) -> int:
	var seasonal_need: float = settlement.population_pu * 0.001
	if seasonal_need <= 0.0:
		return 0
	var ratio: float = settlement.rice_stockpile / seasonal_need
	if ratio < 0.5:
		return 3
	if ratio < 1.0:
		return 2
	if ratio < 2.0:
		return 1
	return 0


# -- War System Wiring -----------------------------------------------------------

static func _process_war_score_shifts(
	military_daily: Dictionary,
	military_effects: Array[Dictionary],
	active_wars: Array[WarData],
	companies: Array[Dictionary],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if active_wars.is_empty():
		return results

	_process_battle_war_scores(military_daily, military_effects, active_wars, companies, results)
	_process_siege_war_scores(military_daily, active_wars, results)
	_process_tether_war_scores(military_daily, active_wars, companies, results)

	return results


static func _process_battle_war_scores(
	military_daily: Dictionary,
	military_effects: Array[Dictionary],
	active_wars: Array[WarData],
	companies: Array[Dictionary],
	results: Array[Dictionary],
) -> void:
	var movement_results: Array = military_daily.get("movement_results", [])
	for mr: Variant in movement_results:
		if not (mr is Dictionary):
			continue
		var md: Dictionary = mr
		if not md.get("battle_triggered", false):
			continue
		var army_id: int = md.get("army_id", -1)
		var army_clan: String = _get_army_clan(army_id, companies)
		if army_clan.is_empty():
			continue

		var company_count: int = md.get("company_count", 1)
		var event_type: String = _classify_battle_size(company_count)

		for war: WarData in active_wars:
			if not war.is_active:
				continue
			if WarSystem.is_clan_involved(war, army_clan):
				var r: Dictionary = WarSystem.apply_score_shift(
					war, event_type, army_clan,
				)
				results.append({
					"war_id": war.war_id,
					"event": event_type,
					"clan": army_clan,
					"shift": r["shift"],
				})
				break

	var battle_results: Array = military_daily.get("battle_results", [])
	for br: Variant in battle_results:
		if not (br is Dictionary):
			continue
		var bd: Dictionary = br
		_process_commander_death_scores(bd, active_wars, results)

	for effect: Dictionary in military_effects:
		if effect.get("type", "") != "battle_pu_reconciliation":
			continue
		var victor_clan: String = effect.get("victor_clan", "")
		if victor_clan.is_empty():
			continue
		var casualties: Dictionary = effect.get("casualties", {})
		var total_loss: float = casualties.get("total_pu_lost", 0.0)
		if total_loss >= 5.0:
			for war: WarData in active_wars:
				if not war.is_active:
					continue
				if WarSystem.is_clan_involved(war, victor_clan):
					var r: Dictionary = WarSystem.apply_score_shift(
						war, "decisive_battle", victor_clan,
					)
					results.append({
						"war_id": war.war_id,
						"event": "decisive_battle_upgrade",
						"clan": victor_clan,
						"shift": r["shift"],
					})
					break
		elif total_loss >= 3.0:
			for war: WarData in active_wars:
				if not war.is_active:
					continue
				if WarSystem.is_clan_involved(war, victor_clan):
					var r: Dictionary = WarSystem.apply_score_shift(
						war, "major_battle", victor_clan,
					)
					results.append({
						"war_id": war.war_id,
						"event": "major_battle_upgrade",
						"clan": victor_clan,
						"shift": r["shift"],
					})
					break


static func _classify_battle_size(company_count: int) -> String:
	if company_count >= 8:
		return "decisive_battle"
	if company_count >= 4:
		return "major_battle"
	return "minor_battle"


static func _process_commander_death_scores(
	battle_result: Dictionary,
	active_wars: Array[WarData],
	results: Array[Dictionary],
) -> void:
	var all_states: Array = []
	all_states.append_array(battle_result.get("attacker_states", []))
	all_states.append_array(battle_result.get("defender_states", []))

	for bc: Variant in all_states:
		if not (bc is Dictionary):
			continue
		var bcd: Dictionary = bc
		if not bcd.get("commander_dead", false):
			continue
		var commander: Variant = bcd.get("commander")
		if commander == null:
			continue
		if not (commander is L5RCharacterData):
			continue
		var dead_char: L5RCharacterData = commander
		var rank: int = dead_char.military_rank
		var clan: String = dead_char.clan
		var event_type: String = _rank_to_death_event(rank)
		if event_type.is_empty():
			continue

		var enemy_clan: String = ""
		var side: String = bcd.get("side", "")
		for war: WarData in active_wars:
			if not war.is_active:
				continue
			if not WarSystem.is_clan_involved(war, clan):
				continue
			var clan_side: String = WarSystem.get_clan_side(war, clan)
			enemy_clan = war.clan_b if clan_side == "a" else war.clan_a
			var r: Dictionary = WarSystem.apply_score_shift(
				war, event_type, enemy_clan,
			)
			results.append({
				"war_id": war.war_id,
				"event": event_type,
				"dead_commander_id": dead_char.character_id,
				"clan": enemy_clan,
				"shift": r["shift"],
			})
			break


static func _rank_to_death_event(rank: int) -> String:
	if rank == Enums.MilitaryRank.RIKUGUNSHOKAN:
		return "rikugunshokan_killed"
	if rank == Enums.MilitaryRank.SHIREIKAN or rank == Enums.MilitaryRank.TAISA:
		return "taisa_shireikan_killed"
	if rank == Enums.MilitaryRank.CHUI or rank == Enums.MilitaryRank.GUNSO:
		return "gunso_chui_killed"
	return ""


static func _process_siege_war_scores(
	military_daily: Dictionary,
	active_wars: Array[WarData],
	results: Array[Dictionary],
) -> void:
	var siege_results: Array = military_daily.get("siege_results", [])
	for sr: Variant in siege_results:
		if not (sr is Dictionary):
			continue
		var sd: Dictionary = sr
		var resolved: String = sd.get("resolved", "")
		if resolved.is_empty():
			continue

		var attacker_clan: String = sd.get("attacker_clan", "")
		var defender_clan: String = sd.get("defender_clan", "")
		if attacker_clan.is_empty() or defender_clan.is_empty():
			continue

		var event_type: String = ""
		var winning_clan: String = ""
		if resolved == "attacker_victory":
			event_type = "siege_won_attacker"
			winning_clan = attacker_clan
		elif resolved == "defender_victory":
			event_type = "siege_won_defender"
			winning_clan = defender_clan

		if event_type.is_empty():
			continue

		for war: WarData in active_wars:
			if not war.is_active:
				continue
			if WarSystem.is_clan_involved(war, winning_clan):
				var r: Dictionary = WarSystem.apply_score_shift(
					war, event_type, winning_clan,
				)
				results.append({
					"war_id": war.war_id,
					"event": event_type,
					"clan": winning_clan,
					"shift": r["shift"],
				})
				break


static func _process_tether_war_scores(
	military_daily: Dictionary,
	active_wars: Array[WarData],
	companies: Array[Dictionary],
	results: Array[Dictionary],
) -> void:
	var tether_results: Array = military_daily.get("tether_results", [])
	for tr: Variant in tether_results:
		if not (tr is Dictionary):
			continue
		var td: Dictionary = tr
		var state: int = td.get("overall_state", 0)
		if state != 2:
			continue

		var army_id: int = td.get("army_id", -1)
		var army_clan: String = _get_army_clan(army_id, companies)
		if army_clan.is_empty():
			continue

		for war: WarData in active_wars:
			if not war.is_active:
				continue
			if not WarSystem.is_clan_involved(war, army_clan):
				continue
			var clan_side: String = WarSystem.get_clan_side(war, army_clan)
			var enemy_clan: String = war.clan_b if clan_side == "a" else war.clan_a
			var r: Dictionary = WarSystem.apply_score_shift(
				war, "supply_line_cut", enemy_clan,
			)
			results.append({
				"war_id": war.war_id,
				"event": "supply_line_cut",
				"clan": enemy_clan,
				"shift": r["shift"],
			})
			break


static func _get_army_clan(
	army_id: int,
	companies: Array[Dictionary],
) -> String:
	for c: Dictionary in companies:
		if c.get("army_id", -1) == army_id:
			return c.get("clan_name", "")
	return ""


static func _process_war_seasonal(
	active_wars: Array[WarData],
	characters: Array[L5RCharacterData],
) -> void:
	for war: WarData in active_wars:
		if not war.is_active:
			continue
		WarSystem.process_seasonal_attrition(war)
		var penalty: int = WarSystem.get_active_war_disposition_penalty(
			war.seasons_active,
		)
		_apply_war_disposition_penalty(war, characters, penalty)


static func _apply_war_disposition_penalty(
	war: WarData,
	characters: Array[L5RCharacterData],
	penalty: int,
) -> void:
	if penalty >= 0:
		return
	for c: L5RCharacterData in characters:
		var c_side: String = WarSystem.get_clan_side(war, c.clan)
		if c_side.is_empty():
			continue
		for other: L5RCharacterData in characters:
			if other.character_id == c.character_id:
				continue
			var o_side: String = WarSystem.get_clan_side(war, other.clan)
			if o_side.is_empty() or o_side == c_side:
				continue
			var key: int = other.character_id
			if c.disposition_values.has(key):
				c.disposition_values[key] = clampi(
					c.disposition_values[key] + penalty, -100, 100,
				)


# -- Supply Status Checks (s4.3.17 Phase 3) -----------------------------------

static func _process_supply_status_checks(
	characters: Array[L5RCharacterData],
	active_wars: Array[WarData],
	settlements: Array[SettlementData],
	provinces: Dictionary,
	companies: Array[Dictionary],
	clans: Dictionary,
	active_tethers: Array[Dictionary],
) -> Array[Dictionary]:
	if active_wars.is_empty():
		return []

	var results: Array[Dictionary] = []

	for lord: L5RCharacterData in characters:
		if not _is_lord_tier(lord):
			continue
		var war: WarData = _find_active_war_for_clan(lord.clan, active_wars)
		if war == null:
			continue

		var clan_companies: Array[Dictionary] = _get_clan_companies(lord.clan, companies)
		if clan_companies.is_empty():
			continue

		var controlled: Array[SettlementData] = _get_clan_settlements(
			lord.clan, settlements, provinces,
		)

		var tether_state: int = _get_worst_tether_state(lord.clan, active_tethers, companies)
		var source_has_rice: bool = _source_has_rice(controlled)

		var clan_iron: float = 0.0
		var clan_data: ClanData = clans.get(lord.clan)
		if clan_data != null:
			clan_iron = clan_data.arms_stockpile

		var total_iron_upkeep: float = 0.0
		for comp: Dictionary in clan_companies:
			var ut: int = comp.get("unit_type", Enums.CompanyUnitType.PEASANT_LEVY)
			var costs: Dictionary = ArmyUpkeepSystem.compute_company_seasonal_costs(ut)
			total_iron_upkeep += costs["iron"]

		var side: String = WarSystem.get_clan_side(war, lord.clan)
		var war_score: int = war.war_score_a if side == "a" else war.war_score_b

		var virtue: String = _get_character_virtue(lord)

		var seasons_cut: int = _get_seasons_tether_cut(lord.clan, active_tethers, companies)

		var inputs: Dictionary = {
			"controlled_settlements": controlled,
			"tether_state": tether_state,
			"source_has_rice": source_has_rice,
			"clan_iron_stockpile": clan_iron,
			"total_iron_upkeep": total_iron_upkeep,
			"primary_virtue": virtue,
			"war_score": war_score,
			"seasons_tether_cut": seasons_cut,
		}

		var check: Dictionary = FeasibilityLedger.run_supply_status_check(inputs)
		var decision: int = check["decision"]["decision"]

		var result: Dictionary = {
			"lord_id": lord.character_id,
			"clan": lord.clan,
			"war_id": war.war_id,
			"check": check,
			"decision": decision,
			"reason": check["decision"]["reason"],
		}

		if decision == FeasibilityLedger.CampaignDecision.SEEK_PEACE \
			or decision == FeasibilityLedger.CampaignDecision.URGENT_PEACE \
			or decision == FeasibilityLedger.CampaignDecision.IMMEDIATE_PEACE:
			result["peace_need"] = true
			result["peace_urgency"] = decision

		if decision == FeasibilityLedger.CampaignDecision.RETREAT:
			var friendly: Array[Dictionary] = _build_friendly_province_list(
				lord.clan, settlements, provinces,
			)
			var retreat_target: Dictionary = FeasibilityLedger.find_retreat_target(
				-1, friendly,
			)
			result["retreat"] = retreat_target

		results.append(result)

	return results


static func _find_active_war_for_clan(
	clan: String, wars: Array[WarData],
) -> WarData:
	for w: WarData in wars:
		if w.is_active and WarSystem.is_clan_involved(w, clan):
			return w
	return null


static func _get_clan_companies(
	clan: String, companies: Array[Dictionary],
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c: Dictionary in companies:
		if c.get("clan_name", "") == clan:
			result.append(c)
	return result


static func _get_clan_settlements(
	clan: String,
	settlements: Array[SettlementData],
	provinces: Dictionary,
) -> Array[SettlementData]:
	var clan_province_ids: Array[int] = []
	for pid: Variant in provinces:
		var p: Variant = provinces[pid]
		if p is ProvinceData and (p as ProvinceData).clan == clan:
			clan_province_ids.append((p as ProvinceData).province_id)
	var result: Array[SettlementData] = []
	for s: SettlementData in settlements:
		if s.province_id in clan_province_ids:
			result.append(s)
	return result


static func _get_worst_tether_state(
	clan: String,
	active_tethers: Array[Dictionary],
	companies: Array[Dictionary],
) -> int:
	var clan_army_ids: Array[int] = []
	for c: Dictionary in companies:
		if c.get("clan_name", "") == clan:
			var aid: int = c.get("army_id", -1)
			if aid >= 0 and aid not in clan_army_ids:
				clan_army_ids.append(aid)
	var worst: int = 0
	for t: Dictionary in active_tethers:
		if t.get("army_id", -1) in clan_army_ids:
			var state: int = t.get("overall_state", 0)
			if state > worst:
				worst = state
	return worst


static func _source_has_rice(controlled: Array[SettlementData]) -> bool:
	var total_rice: float = 0.0
	var total_civ_pu: float = 0.0
	for s: SettlementData in controlled:
		total_rice += s.rice_stockpile
		total_civ_pu += float(s.farming_pu + s.mining_pu + s.town_pu)
	if total_civ_pu <= 0.0:
		return total_rice > 0.0
	return total_rice / total_civ_pu >= 0.50


const _BUSHIDO_VIRTUE_NAMES: Dictionary = {
	Enums.BushidoVirtue.JIN: "Jin",
	Enums.BushidoVirtue.YU: "Yu",
	Enums.BushidoVirtue.REI: "Rei",
	Enums.BushidoVirtue.CHUGI: "Chugi",
	Enums.BushidoVirtue.GI: "Gi",
	Enums.BushidoVirtue.MEIYO: "Meiyo",
	Enums.BushidoVirtue.MAKOTO: "Makoto",
}

const _SHOURIDO_VIRTUE_NAMES: Dictionary = {
	Enums.ShouridoVirtue.SEIGYO: "Seigyo",
	Enums.ShouridoVirtue.KETSUI: "Ketsui",
	Enums.ShouridoVirtue.DOSATSU: "Dosatsu",
	Enums.ShouridoVirtue.CHISHIKI: "Chishiki",
	Enums.ShouridoVirtue.KANPEKI: "Kanpeki",
	Enums.ShouridoVirtue.ISHI: "Ishi",
	Enums.ShouridoVirtue.KYORYOKU: "Kyoryoku",
}


static func _get_character_virtue(character: L5RCharacterData) -> String:
	if character.bushido_virtue != Enums.BushidoVirtue.NONE:
		return _BUSHIDO_VIRTUE_NAMES.get(character.bushido_virtue, "")
	if character.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return _SHOURIDO_VIRTUE_NAMES.get(character.shourido_virtue, "")
	return ""


static func _get_seasons_tether_cut(
	clan: String,
	active_tethers: Array[Dictionary],
	companies: Array[Dictionary],
) -> int:
	var clan_army_ids: Array[int] = []
	for c: Dictionary in companies:
		if c.get("clan_name", "") == clan:
			var aid: int = c.get("army_id", -1)
			if aid >= 0 and aid not in clan_army_ids:
				clan_army_ids.append(aid)
	var worst_cut: int = 0
	for t: Dictionary in active_tethers:
		if t.get("army_id", -1) in clan_army_ids:
			var state: int = t.get("overall_state", 0)
			if state == SupplyTetherSystem.TetherState.BROKEN:
				var cut: int = t.get("seasons_cut", 0)
				if cut > worst_cut:
					worst_cut = cut
	return worst_cut


static func _build_friendly_province_list(
	clan: String,
	settlements: Array[SettlementData],
	provinces: Dictionary,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var by_province: Dictionary = {}
	for s: SettlementData in settlements:
		if not by_province.has(s.province_id):
			by_province[s.province_id] = {"rice": 0.0, "civ_pu": 0.0}
		by_province[s.province_id]["rice"] += s.rice_stockpile
		by_province[s.province_id]["civ_pu"] += float(s.farming_pu + s.mining_pu + s.town_pu)
	for pid: Variant in provinces:
		var p: Variant = provinces[pid]
		if not (p is ProvinceData):
			continue
		var pd: ProvinceData = p
		if pd.clan != clan:
			continue
		var rice_per_pu: float = 0.0
		if by_province.has(pd.province_id):
			var d: Dictionary = by_province[pd.province_id]
			if d["civ_pu"] > 0.0:
				rice_per_pu = d["rice"] / d["civ_pu"]
		result.append({
			"province_id": pd.province_id,
			"distance": 1,
			"rice_per_pu": rice_per_pu,
			"has_forge": false,
		})
	return result


# -- Consume Supply Status Results --------------------------------------------

const _PEACE_NEED_TYPES: Dictionary = {
	FeasibilityLedger.CampaignDecision.SEEK_PEACE: "SEEK_PEACE",
	FeasibilityLedger.CampaignDecision.URGENT_PEACE: "SEEK_PEACE",
	FeasibilityLedger.CampaignDecision.IMMEDIATE_PEACE: "SEEK_PEACE",
}

const _PEACE_PRIORITIES: Dictionary = {
	FeasibilityLedger.CampaignDecision.SEEK_PEACE: 2,
	FeasibilityLedger.CampaignDecision.URGENT_PEACE: 1,
	FeasibilityLedger.CampaignDecision.IMMEDIATE_PEACE: 1,
}


static func _consume_supply_status_results(
	supply_results: Array[Dictionary],
	world_states: Dictionary,
	active_armies: Array[Dictionary],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	for result: Dictionary in supply_results:
		var lord_id: int = result.get("lord_id", -1)
		var decision: int = result.get("decision", FeasibilityLedger.CampaignDecision.CONTINUE)
		var clan: String = result.get("clan", "")

		if result.get("peace_need", false):
			_inject_peace_need(lord_id, decision, clan, world_states)

		if decision == FeasibilityLedger.CampaignDecision.RETREAT:
			_apply_retreat_orders(
				clan, result.get("retreat", {}), active_armies,
				active_topics, next_topic_id, ic_day,
			)


static func _inject_edict_reactive_events(
	active_edicts: Array[EdictData],
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
	_ic_day: int,
) -> void:
	for edict: EdictData in active_edicts:
		if not edict.is_active:
			continue
		for clan: String in edict.compliance_by_clan:
			var status: int = edict.compliance_by_clan[clan]
			if status != EdictData.ComplianceStatus.PENDING:
				continue
			var lord_id: int = _find_clan_lord(characters, clan)
			if lord_id < 0:
				continue
			var ws: Dictionary = world_states.get(lord_id, {})
			if ws.is_empty():
				ws = {}
				world_states[lord_id] = ws
			if not ws.has("pending_events"):
				ws["pending_events"] = []
			var already_injected: bool = false
			for ev: Variant in ws["pending_events"]:
				if ev is Dictionary and ev.get("source", "") == "edict_response" \
						and ev.get("target_npc_id", -1) == edict.edict_id:
					already_injected = true
					break
			if already_injected:
				continue
			ws["pending_events"].append({
				"need_type": "RESPOND_TO_EDICT",
				"priority": 1,
				"target_npc_id": edict.edict_id,
				"target_clan_id": clan,
				"source": "edict_response",
			})


static func _find_clan_lord(
	characters: Array[L5RCharacterData],
	clan: String,
) -> int:
	var best_id: int = -1
	var best_status: float = -1.0
	for c: L5RCharacterData in characters:
		if c.clan == clan and c.status >= 5.0 and c.lord_id == -1:
			if c.status > best_status:
				best_status = c.status
				best_id = c.character_id
	return best_id


static func _inject_peace_need(
	lord_id: int,
	decision: int,
	clan: String,
	world_states: Dictionary,
) -> void:
	var ws: Dictionary = world_states.get(lord_id, {})
	if ws.is_empty():
		ws = {}
		world_states[lord_id] = ws

	if not ws.has("pending_events"):
		ws["pending_events"] = []

	var need_type: String = _PEACE_NEED_TYPES.get(decision, "SEEK_PEACE")
	var priority: int = _PEACE_PRIORITIES.get(decision, 2)

	var event: Dictionary = {
		"need_type": need_type,
		"priority": priority,
		"target_clan_id": clan,
		"source": "supply_status_check",
	}
	ws["pending_events"].append(event)


static func _apply_retreat_orders(
	clan: String,
	retreat_info: Dictionary,
	active_armies: Array[Dictionary],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	var should_disband: bool = retreat_info.get("should_disband", false)
	var target_province: int = retreat_info.get("province_id", -1)

	for army: Dictionary in active_armies:
		if army.get("clan_name", "") != clan:
			continue
		if not army.get("is_active", true):
			continue

		if should_disband:
			army["retreat_ordered"] = true
			army["disband_ordered"] = true
			_create_disband_topic(clan, active_topics, next_topic_id, ic_day)
		elif target_province >= 0:
			army["retreat_ordered"] = true
			army["retreat_target_province"] = target_province


static func _create_disband_topic(
	clan: String,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	var topic: TopicData = TopicData.new()
	topic.topic_id = next_topic_id[0]
	next_topic_id[0] += 1
	topic.slug = "army_disband_%s_d%d" % [clan, ic_day]
	topic.title = "Army Disbanded — %s" % clan
	topic.topic_type = "military"
	topic.variant = "army_disbanded"
	topic.tier = TopicData.Tier.TIER_4
	topic.category = TopicData.Category.POLITICAL
	topic.clan_involved = clan
	topic.ic_day_created = ic_day
	topic.momentum = 11.0
	active_topics.append(topic)


static func _generate_military_event_topics(
	military_daily: Dictionary,
	military_effects: Array[Dictionary],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> Array[TopicData]:
	var topics: Array[TopicData] = []

	var movement_results: Array = military_daily.get("movement_results", [])
	for mr: Variant in movement_results:
		if not (mr is Dictionary):
			continue
		var md: Dictionary = mr
		if md.get("battle_triggered", false):
			var topic: TopicData = _create_battle_topic(
				md, next_topic_id, ic_day,
			)
			if topic != null:
				active_topics.append(topic)
				topics.append(topic)

	for effect: Dictionary in military_effects:
		var etype: String = effect.get("type", "")
		if etype == "battle_pu_reconciliation":
			var casualties: Dictionary = effect.get("casualties", {})
			var total_loss: float = casualties.get("total_pu_lost", 0.0)
			if total_loss >= 0.5:
				var topic: TopicData = _create_heavy_casualties_topic(
					casualties, next_topic_id, ic_day,
				)
				if topic != null:
					active_topics.append(topic)
					topics.append(topic)

	var siege_results: Array = military_daily.get("siege_results", [])
	for sr: Variant in siege_results:
		if not (sr is Dictionary):
			continue
		var sd: Dictionary = sr
		var events: Array = sd.get("events", [])
		for evt: Variant in events:
			if not (evt is Dictionary):
				continue
			var ed: Dictionary = evt
			var topic: TopicData = _create_siege_event_topic(
				ed, sd, next_topic_id, ic_day,
			)
			if topic != null:
				active_topics.append(topic)
				topics.append(topic)

	return topics


static func _create_battle_topic(
	movement_result: Dictionary,
	next_topic_id: Array[int],
	ic_day: int,
) -> TopicData:
	var army_id: int = movement_result.get("army_id", -1)
	var province_id: int = movement_result.get("arrived_province_id", -1)
	var provinces: Array[int] = [province_id] if province_id >= 0 else []

	var variant: String = "victory_clean"
	var tier: TopicData.Tier = TopicData.Tier.TIER_3
	var momentum: float = 30.0

	var title: String = "Battle at province %d" % province_id

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] += 1

	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id, title, tier, TopicData.Category.MILITARY,
		ic_day, momentum, provinces, "", "", -1,
		"battle_outcome", variant,
	)
	topic.slug = "battle_%d_day_%d" % [army_id, ic_day]
	return topic


static func _create_heavy_casualties_topic(
	casualties: Dictionary,
	next_topic_id: Array[int],
	ic_day: int,
) -> TopicData:
	var provinces: Array[int] = []
	var by_province: Dictionary = casualties.get("pu_lost_by_province", {})
	for pid: Variant in by_province:
		if pid is int:
			provinces.append(pid)

	var title: String = "Heavy casualties in battle"
	var topic_id: int = next_topic_id[0]
	next_topic_id[0] += 1

	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id, title, TopicData.Tier.TIER_3, TopicData.Category.MILITARY,
		ic_day, 25.0, provinces, "", "", -1,
		"battle_outcome", "heavy_casualties",
	)
	topic.slug = "casualties_day_%d" % ic_day
	return topic


static func _create_siege_event_topic(
	event: Dictionary,
	siege_result: Dictionary,
	next_topic_id: Array[int],
	ic_day: int,
) -> TopicData:
	var event_type: String = event.get("event_type", "")
	if event_type.is_empty():
		return null

	var siege_id: int = siege_result.get("siege_id", -1)
	var title: String = "Siege event: %s" % event_type.replace("_", " ")

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] += 1

	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id, title, TopicData.Tier.TIER_4, TopicData.Category.MILITARY,
		ic_day, 11.0, [], "", "", -1,
		"siege", event_type,
	)
	topic.slug = "siege_%d_event_%s_day_%d" % [siege_id, event_type, ic_day]
	return topic


static func _apply_levy_pu_effect(
	applied: Dictionary,
	settlements: Array[SettlementData],
) -> Dictionary:
	var province_id: int = applied.get("target_province_id", -1)
	if province_id < 0:
		return {}

	var target_settlement: SettlementData = null
	for s: SettlementData in settlements:
		if s.province_id == province_id:
			target_settlement = s
			break

	if target_settlement == null:
		return {}

	var r: Dictionary = PUReconciliation.consume_levy_pu(target_settlement)
	return {
		"type": "levy_pu_consumed",
		"character_id": applied.get("character_id", -1),
		"province_id": province_id,
		"settlement_id": target_settlement.settlement_id,
		"pu_consumed": r["pu_consumed"],
	}


static func _apply_service_assignment_effect(
	applied: Dictionary,
	characters_by_id: Dictionary,
) -> Dictionary:
	var effects: Dictionary = applied.get("effects", {})
	var target_id: int = applied.get("target_npc_id", -1)
	if target_id < 0:
		return {}

	var target: L5RCharacterData = characters_by_id.get(target_id)
	if target == null:
		return {}

	var commander_id: int = effects.get("military_commander_id", -1)
	var unit_id: int = effects.get("assigned_unit_id", -1)
	if commander_id < 0:
		return {}

	var char_data: Dictionary = {
		"character_id": target.character_id,
		"lord_id": target.lord_id,
		"operational_superior_id": target.operational_superior_id,
		"assigned_company_id": target.assigned_company_id,
	}

	MilitaryServiceSystem.assign_to_military_service(
		char_data, commander_id, unit_id,
	)

	target.operational_superior_id = char_data["operational_superior_id"]
	target.assigned_company_id = char_data["assigned_company_id"]

	return {
		"type": "service_assigned",
		"character_id": target.character_id,
		"new_commander_id": commander_id,
		"assigned_unit_id": unit_id,
	}


static func _apply_battle_pu_reconciliation(
	applied: Dictionary,
	settlements_by_province: Dictionary,
) -> Dictionary:
	var effects: Dictionary = applied.get("effects", {})
	var victor_companies: Array[Dictionary] = []
	for c: Variant in effects.get("victor_companies", []):
		if c is Dictionary:
			victor_companies.append(c)
	var loser_companies: Array[Dictionary] = []
	for c: Variant in effects.get("loser_companies", []):
		if c is Dictionary:
			loser_companies.append(c)

	if victor_companies.is_empty() and loser_companies.is_empty():
		return {}

	var r: Dictionary = PUReconciliation.reconcile_battle(
		victor_companies, loser_companies, settlements_by_province,
	)

	var victor_clan: String = ""
	if not victor_companies.is_empty():
		victor_clan = victor_companies[0].get("clan_name", "")

	return {
		"type": "battle_pu_reconciliation",
		"casualties": r.get("casualties", {}),
		"recovery": r.get("recovery", {}),
		"victor_clan": victor_clan,
	}


# -- Full Battle Resolution Pipeline -------------------------------------------

static func resolve_and_reconcile_battle(
	attacker_states: Array[Dictionary],
	defender_states: Array[Dictionary],
	terrain: Enums.BattleTerrainType,
	dice_engine: DiceEngine,
	settlements: Array[SettlementData],
	is_amphibious: bool = false,
	fortification_bonus: int = 0,
) -> Dictionary:
	var battle_result: Dictionary = ArmyCombatSystem.resolve_battle(
		attacker_states, defender_states, terrain, dice_engine,
		is_amphibious, fortification_bonus,
	)

	var pu_data: Dictionary = ArmyCombatSystem.extract_pu_reconciliation_data(
		battle_result,
	)

	var settlements_by_province: Dictionary = _build_settlements_by_province(settlements)

	var reconciliation: Dictionary = PUReconciliation.reconcile_battle(
		pu_data["victor_companies"],
		pu_data["loser_companies"],
		settlements_by_province,
	)

	var victor: String = battle_result.get("victor", "draw")
	var rout_result: Dictionary = {}
	if victor != "draw":
		var loser_states: Array[Dictionary] = []
		for s: Variant in (battle_result["defender_states"] if victor == "attacker" else battle_result["attacker_states"]):
			if s is Dictionary:
				loser_states.append(s)
		var victor_states: Array[Dictionary] = []
		for s: Variant in (battle_result["attacker_states"] if victor == "attacker" else battle_result["defender_states"]):
			if s is Dictionary:
				victor_states.append(s)

		var has_cavalry: bool = false
		for bc: Dictionary in victor_states:
			if ArmyCombatSystem.is_cavalry(bc.get("unit_type", -1)):
				has_cavalry = true
				break

		rout_result = ArmyCombatSystem.resolve_rout(
			loser_states, has_cavalry, dice_engine,
		)

		var recovery: Dictionary = ArmyCombatSystem.compute_post_battle_recovery(
			victor_states,
		)
		battle_result["recovery"] = recovery

		if rout_result.get("dissolved", false):
			var pursuit_total: int = rout_result.get("pursuit_casualties", 0)
			var dissolution_companies: Array[Dictionary] = _build_dissolution_companies(
				loser_states, pursuit_total,
			)
			var dissolution: Dictionary = PUReconciliation.process_army_dissolution(
				dissolution_companies, settlements_by_province,
			)
			battle_result["dissolution"] = dissolution

	battle_result["reconciliation"] = reconciliation
	battle_result["rout"] = rout_result

	return battle_result


static func _deduct_clan_upkeep(
	cost_by_clan: Dictionary,
	clans: Dictionary,
	settlements_by_province: Dictionary,
	stockpile_field: String,
) -> float:
	var total_deducted: float = 0.0

	for clan_name: String in cost_by_clan:
		var clan_cost: float = cost_by_clan[clan_name]
		if clan_cost <= 0.0:
			continue

		var clan: ClanData = clans.get(clan_name)
		if clan == null:
			continue

		var clan_settlements: Array[SettlementData] = []
		for pid: int in clan.province_ids:
			var province_setts: Array = settlements_by_province.get(pid, [])
			for s: Variant in province_setts:
				if s is SettlementData:
					clan_settlements.append(s)

		if clan_settlements.is_empty():
			continue

		var remaining: float = clan_cost
		for s: SettlementData in clan_settlements:
			if remaining <= 0.0:
				break
			var available: float = s.get(stockpile_field)
			var deduct: float = minf(available, remaining)
			s.set(stockpile_field, available - deduct)
			remaining -= deduct
			total_deducted += deduct

	return total_deducted


static func _build_dissolution_companies(
	loser_states: Array[Dictionary],
	pursuit_casualties: int,
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var remaining_pursuit: int = pursuit_casualties
	for bc: Dictionary in loser_states:
		if bc.get("is_destroyed", false):
			continue
		var health: int = maxi(bc.get("current_health", 0), 0)
		var loss: int = mini(remaining_pursuit, health)
		remaining_pursuit -= loss
		var company: Variant = bc.get("company")
		var source_id: int = -1
		if company is MilitaryUnitData.CompanyData:
			source_id = company.source_province_id
		result.append({
			"current_health": health - loss,
			"source_province_id": source_id,
		})
	return result


static func _build_settlements_by_province(
	settlements: Array[SettlementData],
) -> Dictionary:
	var result: Dictionary = {}
	for s: SettlementData in settlements:
		if not result.has(s.province_id):
			result[s.province_id] = []
		result[s.province_id].append(s)
	return result


# -- War Declaration Processing ------------------------------------------------

static func _process_war_declarations(
	applied_list: Array,
	active_wars: Array[WarData],
	ic_day: int,
	next_war_id: Array[int] = [1],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for applied: Variant in applied_list:
		if not (applied is Dictionary):
			continue
		var ad: Dictionary = applied
		var effects: Dictionary = ad.get("effects", {})
		if not effects.get("requires_war_creation", false):
			continue

		var declaring_clan: String = effects.get("declaring_clan", "")
		var target_clan: String = effects.get("target_clan", "")
		if declaring_clan.is_empty() or target_clan.is_empty():
			continue
		if declaring_clan == target_clan:
			continue

		if WarSystem.are_clans_at_war(active_wars, declaring_clan, target_clan):
			results.append({
				"event": "war_already_active",
				"declaring_clan": declaring_clan,
				"target_clan": target_clan,
			})
			continue

		var war_id: int = next_war_id[0]
		next_war_id[0] += 1
		var authority_level: int = effects.get(
			"authority_level", WarData.AuthorityLevel.PROVINCIAL_RAID,
		)
		var declaring_lord_id: int = effects.get("declaring_lord_id", -1)

		var war: WarData = WarSystem.declare_war(
			war_id, declaring_clan, target_clan,
			authority_level, declaring_lord_id, -1, ic_day,
		)
		active_wars.append(war)

		results.append({
			"event": "war_declared",
			"war_id": war.war_id,
			"declaring_clan": declaring_clan,
			"target_clan": target_clan,
			"authority_level": authority_level,
			"declaring_lord_id": declaring_lord_id,
			"personality_driven": effects.get("personality_driven", false),
		})

	return results


# -- Ladder Side Effects Processing -------------------------------------------

static func _process_ladder_side_effects(
	applied_list: Array,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	favors: Array,
	active_wars: Array[WarData],
	next_war_id: Array[int],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for applied: Variant in applied_list:
		if not (applied is Dictionary):
			continue
		var ad: Dictionary = applied
		var effects: Dictionary = ad.get("effects", {})
		if not effects.has("ladder_side_effects"):
			continue

		var side: Dictionary = effects["ladder_side_effects"]
		var declaring_lord_id: int = effects.get("declaring_lord_id", -1)
		var declaring_clan: String = effects.get("declaring_clan", "")
		var lord: L5RCharacterData = characters_by_id.get(declaring_lord_id)
		var result: Dictionary = {
			"lord_id": declaring_lord_id,
			"rung": side.get("rung", -1),
		}

		if side.get("glory_cost", 0.0) != 0.0 and lord != null:
			lord.glory = maxf(lord.glory + side["glory_cost"], 0.0)
			result["glory_applied"] = side["glory_cost"]

		if side.has("disposition_cost") and lord != null:
			var disp_cost: int = side["disposition_cost"]
			_apply_vassal_disposition_cost(lord, characters_by_id, disp_cost)
			result["vassal_disposition_applied"] = disp_cost

		if side.has("clan_disposition_cost"):
			var clan_cost: int = side["clan_disposition_cost"]
			var raid_target_clan: String = side.get("raid_target_clan", "")
			if not raid_target_clan.is_empty():
				_apply_clan_disposition_cost(
					declaring_clan, raid_target_clan, clan_cost, characters_by_id,
				)
				result["clan_disposition_applied"] = clan_cost
				result["raid_target_clan"] = raid_target_clan

		if side.has("other_disposition_cost"):
			var other_cost: int = side["other_disposition_cost"]
			var raid_target_clan: String = side.get("raid_target_clan", "")
			_apply_other_clans_disposition_cost(
				declaring_clan, raid_target_clan, other_cost, characters_by_id,
			)
			result["other_disposition_applied"] = other_cost

		if side.get("generates_topic", false):
			var topic: TopicData = _create_ladder_topic(
				side, declaring_clan, active_topics, next_topic_id, ic_day,
			)
			result["topic_id"] = topic.topic_id

		if side.get("creates_favor", false) and lord != null:
			var favor_tier: int = side.get("favor_tier", 3)
			var ally_ids: Array = side.get("contributing_ally_ids", [])
			var created_favors: Array[int] = []
			if ally_ids.is_empty():
				var favor: FavorData = _create_allied_aid_favor(
					-1, lord.character_id, favor_tier, ic_day, favors,
				)
				if favor != null:
					created_favors.append(favor.favor_id)
			else:
				for aid: Variant in ally_ids:
					var ally_id: int = aid as int
					var favor: FavorData = _create_allied_aid_favor(
						ally_id, lord.character_id, favor_tier, ic_day, favors,
					)
					if favor != null:
						created_favors.append(favor.favor_id)
			result["favor_ids"] = created_favors
			result["favor_tier"] = favor_tier

		if side.get("triggers_war_status", false):
			var raid_target_clan: String = side.get("raid_target_clan", "")
			if not raid_target_clan.is_empty() and not declaring_clan.is_empty():
				if not WarSystem.are_clans_at_war(active_wars, declaring_clan, raid_target_clan):
					var war_id: int = next_war_id[0]
					next_war_id[0] += 1
					var war: WarData = WarSystem.declare_war(
						war_id, declaring_clan, raid_target_clan,
						WarData.AuthorityLevel.PROVINCIAL_RAID,
						declaring_lord_id, -1, ic_day,
					)
					active_wars.append(war)
					result["raid_war_id"] = war.war_id
					result["raid_war_target"] = raid_target_clan

		results.append(result)

	return results


static func _apply_vassal_disposition_cost(
	lord: L5RCharacterData,
	characters_by_id: Dictionary,
	cost: int,
) -> void:
	for cid: Variant in characters_by_id:
		var c: Variant = characters_by_id[cid]
		if not (c is L5RCharacterData):
			continue
		var ch: L5RCharacterData = c
		if ch.lord_id == lord.character_id:
			var key: int = lord.character_id
			if ch.disposition_values.has(key):
				ch.disposition_values[key] = clampi(
					ch.disposition_values[key] + cost, -100, 100,
				)
			else:
				ch.disposition_values[key] = clampi(cost, -100, 100)


static func _apply_clan_disposition_cost(
	declaring_clan: String,
	target_clan: String,
	cost: int,
	characters_by_id: Dictionary,
) -> void:
	for cid: Variant in characters_by_id:
		var c: Variant = characters_by_id[cid]
		if not (c is L5RCharacterData):
			continue
		var ch: L5RCharacterData = c
		if ch.clan != target_clan:
			continue
		for oid: Variant in characters_by_id:
			var o: Variant = characters_by_id[oid]
			if not (o is L5RCharacterData):
				continue
			var other: L5RCharacterData = o
			if other.clan != declaring_clan:
				continue
			var key: int = other.character_id
			if ch.disposition_values.has(key):
				ch.disposition_values[key] = clampi(
					ch.disposition_values[key] + cost, -100, 100,
				)
			else:
				ch.disposition_values[key] = clampi(cost, -100, 100)


static func _apply_other_clans_disposition_cost(
	declaring_clan: String,
	exempt_clan: String,
	cost: int,
	characters_by_id: Dictionary,
) -> void:
	for cid: Variant in characters_by_id:
		var c: Variant = characters_by_id[cid]
		if not (c is L5RCharacterData):
			continue
		var ch: L5RCharacterData = c
		if ch.clan == declaring_clan or ch.clan == exempt_clan:
			continue
		for oid: Variant in characters_by_id:
			var o: Variant = characters_by_id[oid]
			if not (o is L5RCharacterData):
				continue
			var other: L5RCharacterData = o
			if other.clan != declaring_clan:
				continue
			var key: int = other.character_id
			if ch.disposition_values.has(key):
				ch.disposition_values[key] = clampi(
					ch.disposition_values[key] + cost, -100, 100,
				)
			else:
				ch.disposition_values[key] = clampi(cost, -100, 100)


static func _create_ladder_topic(
	side_effects: Dictionary,
	declaring_clan: String,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> TopicData:
	var topic: TopicData = TopicData.new()
	topic.topic_id = next_topic_id[0]
	next_topic_id[0] += 1

	var rung: int = side_effects.get("rung", -1)
	var tier_val: int = side_effects.get("topic_tier", 4)
	match tier_val:
		3: topic.tier = TopicData.Tier.TIER_3
		2: topic.tier = TopicData.Tier.TIER_2
		1: topic.tier = TopicData.Tier.TIER_1
		_: topic.tier = TopicData.Tier.TIER_4

	var rung_name: String = _ladder_rung_name(rung)
	topic.slug = "war_preparation_%s_%s_d%d" % [rung_name, declaring_clan, ic_day]
	topic.title = "War Preparation — %s (%s)" % [declaring_clan, rung_name.replace("_", " ")]
	topic.topic_type = "war_preparation"
	topic.variant = rung_name
	topic.category = TopicData.Category.POLITICAL
	topic.clan_involved = declaring_clan
	topic.ic_day_created = ic_day

	match topic.tier:
		TopicData.Tier.TIER_3: topic.momentum = 26.0
		_: topic.momentum = 11.0

	active_topics.append(topic)
	return topic


static func _create_allied_aid_favor(
	creditor_id: int,
	debtor_id: int,
	favor_tier: int,
	ic_day: int,
	favors: Array,
) -> FavorData:
	var tier: FavorData.FavorTier
	match favor_tier:
		2: tier = FavorData.FavorTier.MODERATE
		1: tier = FavorData.FavorTier.MAJOR
		_: tier = FavorData.FavorTier.MINOR

	var max_id: int = 0
	for f: Variant in favors:
		if f is FavorData and (f as FavorData).favor_id >= max_id:
			max_id = (f as FavorData).favor_id + 1

	var favor: FavorData = FavorSystem.offer_favor(
		FavorData.FavorType.GENERAL,
		tier,
		creditor_id,
		debtor_id,
		ic_day,
		"Allied aid for war preparation",
		"ALLIED_AID",
		max_id,
	)
	favors.append(favor)
	return favor


static func _ladder_rung_name(rung: int) -> String:
	match rung:
		FeasibilityLedger.LadderRung.DEMAND_TRIBUTE: return "demand_tribute"
		FeasibilityLedger.LadderRung.REQUEST_ALLIED_AID: return "allied_aid"
		FeasibilityLedger.LadderRung.RAID_NEIGHBOR: return "raid_neighbor"
		FeasibilityLedger.LadderRung.DESPERATION_OVERRIDE: return "desperation"
		_: return "unknown"


# -- War Termination Processing ------------------------------------------------

static func _process_war_terminations(
	applied_list: Array,
	active_wars: Array[WarData],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# 1. Check for annihilation on any active war.
	for war: WarData in active_wars:
		if not war.is_active:
			continue
		var annihilation: Dictionary = WarTermination.check_annihilation(war)
		if annihilation.get("annihilated", false):
			var resolution: Dictionary = WarTermination.resolve_annihilation(
				war, annihilation["clan"],
			)
			var topic: TopicData = WarTermination.generate_war_end_topic(
				resolution, next_topic_id, ic_day,
			)
			active_topics.append(topic)
			results.append(resolution)

	# 2. Process negotiated peace from NEGOTIATE_SURRENDER actions.
	for applied: Variant in applied_list:
		if not (applied is Dictionary):
			continue
		var ad: Dictionary = applied
		var effects: Dictionary = ad.get("effects", {})
		if not effects.get("requires_peace_resolution", false):
			continue

		var war_id: int = effects.get("war_id", -1)
		var war: WarData = _find_war_by_id(active_wars, war_id)
		if war == null or not war.is_active:
			continue

		var res_type: String = effects.get("resolution_type", "")
		var terms: Dictionary = effects.get("terms", {})
		var resolution: Dictionary

		if res_type == "formal_surrender":
			var surrendering: String = effects.get("own_clan", "")
			resolution = WarTermination.resolve_formal_surrender(war, surrendering)
		else:
			resolution = WarTermination.resolve_negotiated_settlement(war, terms)

		var topic: TopicData = WarTermination.generate_war_end_topic(
			resolution, next_topic_id, ic_day,
		)
		active_topics.append(topic)
		results.append(resolution)

	return results


static func _find_war_by_id(
	active_wars: Array[WarData],
	war_id: int,
) -> WarData:
	for war: WarData in active_wars:
		if war.war_id == war_id:
			return war
	return null


# -- Trade Route Suspension on War/Peace ---------------------------------------

static func _process_war_trade_routes(
	war_declarations: Array[Dictionary],
	trade_routes: Array,
	provinces: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for decl: Dictionary in war_declarations:
		if decl.get("event", "") != "war_declared":
			continue
		var clan_a: String = decl.get("declaring_clan", "")
		var clan_b: String = decl.get("target_clan", "")
		if clan_a.is_empty() or clan_b.is_empty():
			continue
		var suspended: Array[Dictionary] = WarTermination.suspend_trade_routes_for_war(
			trade_routes, provinces, clan_a, clan_b,
		)
		results.append_array(suspended)
	return results


static func _process_peace_trade_routes(
	war_termination_results: Array[Dictionary],
	trade_routes: Array,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for resolution: Dictionary in war_termination_results:
		var res_type: String = resolution.get("resolution", "")
		if res_type == "annihilation":
			continue
		var clan_a: String = ""
		var clan_b: String = ""
		match res_type:
			"formal_surrender":
				clan_a = resolution.get("winner_clan", "")
				clan_b = resolution.get("loser_clan", "")
			"negotiated_settlement":
				clan_a = resolution.get("proposing_clan", "")
				clan_b = resolution.get("receiving_clan", "")
			"imperial_edict":
				clan_a = resolution.get("clan_a", "")
				clan_b = resolution.get("clan_b", "")
		if clan_a.is_empty() or clan_b.is_empty():
			continue
		var restored: Array[Dictionary] = WarTermination.restore_trade_routes_for_peace(
			trade_routes, clan_a, clan_b,
		)
		results.append_array(restored)
	return results


# -- Court Session Processing --------------------------------------------------

static func _process_active_courts(
	active_courts: Array[CourtSessionData],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	active_edicts: Array[EdictData] = [],
	next_edict_id: Array[int] = [1],
	active_wars: Array[WarData] = [],
	characters_by_id: Dictionary = {},
	world_states: Dictionary = {},
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for court: CourtSessionData in active_courts:
		if not CourtSystem.is_active(court):
			continue
		var advance_result: Dictionary = CourtSystem.advance_court_day(court)
		if advance_result.get("should_close", false):
			var close_result: Dictionary = CourtSystem.close_court(court)
			var edicts_issued: Array[EdictData] = _generate_court_edicts(
				court, active_edicts, next_edict_id, active_wars,
				active_topics, next_topic_id, characters_by_id, world_states, ic_day,
			)
			if not edicts_issued.is_empty():
				close_result["edicts_issued"] = edicts_issued.size()
			var topic_dict: Dictionary = CourtSystem.generate_court_close_topic(court)
			if not topic_dict.is_empty():
				var t := TopicData.new()
				t.topic_id = next_topic_id[0]
				next_topic_id[0] += 1
				t.topic_type = topic_dict.get("topic_type", "court_session")
				t.variant = topic_dict.get("variant", "")
				t.slug = topic_dict.get("slug", "")
				t.tier = topic_dict.get("tier", TopicData.Tier.TIER_4)
				t.category = topic_dict.get("category", TopicData.Category.POLITICAL)
				t.momentum = topic_dict.get("momentum", 5.0)
				t.clan_involved = topic_dict.get("clan_involved", "")
				t.ic_day_created = ic_day
				active_topics.append(t)
				close_result["topic_id"] = t.topic_id
			results.append(close_result)
		else:
			results.append(advance_result)
	return results


static func _generate_court_edicts(
	court: CourtSessionData,
	active_edicts: Array[EdictData],
	next_edict_id: Array[int],
	active_wars: Array[WarData],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	characters_by_id: Dictionary,
	world_states: Dictionary,
	ic_day: int,
) -> Array[EdictData]:
	if not court.emperor_present:
		return []
	var emperor_id: int = -1
	var archetype: int = StrategicReview.EmperorArchetype.IRON
	for char_id: int in court.attendee_ids:
		var c: L5RCharacterData = characters_by_id.get(char_id) as L5RCharacterData
		if c != null and c.status >= 9.0:
			emperor_id = c.character_id
			break
	if emperor_id < 0:
		emperor_id = world_states.get("emperor_id", -1)
	if emperor_id < 0:
		return []
	var emperor: L5RCharacterData = characters_by_id.get(emperor_id) as L5RCharacterData
	if emperor == null:
		return []
	archetype = world_states.get("emperor_archetype", StrategicReview.EmperorArchetype.IRON)

	var edicts: Array[EdictData] = ImperialEdictSystem.generate_winter_court_edicts(
		emperor, archetype, court.agenda_topic_ids, active_topics,
		active_wars, next_edict_id, ic_day, court.court_id,
	)
	for edict: EdictData in edicts:
		active_edicts.append(edict)
		var topic_dict: Dictionary = ImperialEdictSystem.generate_edict_topic(edict)
		if not topic_dict.is_empty():
			var t := TopicData.new()
			t.topic_id = next_topic_id[0]
			next_topic_id[0] += 1
			t.topic_type = topic_dict.get("topic_type", "imperial_edict")
			t.variant = topic_dict.get("variant", "")
			t.slug = topic_dict.get("slug", "")
			t.tier = topic_dict.get("tier", TopicData.Tier.TIER_1)
			t.category = topic_dict.get("category", TopicData.Category.POLITICAL)
			t.momentum = topic_dict.get("momentum", 80.0)
			t.clan_involved = topic_dict.get("clan_involved", "")
			t.subject_character_id = topic_dict.get("subject_character_id", -1)
			t.ic_day_created = ic_day
			active_topics.append(t)
	return edicts


static func _set_court_context_flags(
	active_courts: Array[CourtSessionData],
	world_states: Dictionary,
) -> void:
	for court: CourtSessionData in active_courts:
		if not CourtSystem.is_active(court):
			continue
		var ctx_dict: Dictionary = CourtSystem.to_context_dict(court)
		for char_id: int in court.attendee_ids:
			var ws: Dictionary = world_states.get(char_id, {})
			if ws.is_empty():
				continue
			ws["context_flag"] = Enums.ContextFlag.AT_COURT
			ws["active_court_at_location"] = ctx_dict


static func _set_wall_tower_context_flags(
	characters: Array[L5RCharacterData],
	settlements: Array[SettlementData],
	provinces: Dictionary,
	world_states: Dictionary,
) -> void:
	# Build a settlement_id (as String) → SettlementData map for wall towers.
	var wall_towers: Dictionary = {}
	for s: SettlementData in settlements:
		if s.settlement_type == Enums.SettlementType.WALL_TOWER:
			wall_towers[str(s.settlement_id)] = s

	if wall_towers.is_empty():
		return

	for character: L5RCharacterData in characters:
		var loc: String = character.physical_location
		if not wall_towers.has(loc):
			continue
		if TravelSystem.is_traveling(character):
			continue
		var ws: Dictionary = world_states.get(character.character_id, {})
		if ws.is_empty():
			continue

		# AT_COURT takes priority — court overrides wall tower context.
		if ws.get("context_flag", -1) == Enums.ContextFlag.AT_COURT:
			continue

		var tower: SettlementData = wall_towers[loc] as SettlementData
		var province: Variant = provinces.get(tower.province_id, null)
		var ss: int = 0
		if province is ProvinceData:
			ss = (province as ProvinceData).shadowlands_strength

		# Build a WallStatus for this tower.
		var wstat := NPCDataStructures.WallStatus.new()
		wstat.province_id = tower.province_id
		wstat.si = tower.wall_si
		wstat.ss = ss
		wstat.garrison_above_minimum = not WallSystem.is_garrison_below_minimum(tower.garrison_pu)
		var min_jade: float = float(
			int(tower.garrison_pu * WallSystem.SORTIE_SMALL_MAX_PCT)
			* WallSystem.SORTIE_SMALL_JADE_PER_WARRIOR
		)
		wstat.jade_stockpile_critical = tower.jade_stockpile <= min_jade

		ws["context_flag"] = Enums.ContextFlag.AT_WALL_TOWER
		ws["zone_subtype"] = Enums.ZoneSubtype.WALL_TOWER
		# Preserve any existing wall_statuses from other towers the character
		# knows about, then ensure the current tower's status is present.
		var existing: Array = ws.get("wall_statuses", [])
		var already_has: bool = false
		for entry: Variant in existing:
			if entry is NPCDataStructures.WallStatus:
				if (entry as NPCDataStructures.WallStatus).province_id == tower.province_id:
					already_has = true
					break
		if not already_has:
			existing = existing.duplicate()
			existing.append(wstat)
		ws["wall_statuses"] = existing


static func _process_crisis_court_calls(
	characters: Array[L5RCharacterData],
	active_courts: Array[CourtSessionData],
	active_topics: Array[TopicData],
	world_states: Dictionary,
	next_court_id: Array[int],
	ic_day: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for lord: L5RCharacterData in characters:
		if not _is_lord_tier(lord):
			continue
		var lord_rank: Enums.LordRank = _status_to_lord_rank(lord.status)
		var courts_at_settlement: Array[CourtSessionData] = []
		var settlement_str: String = str(lord.physical_location)
		for c: CourtSessionData in active_courts:
			if str(c.host_settlement_id) == settlement_str:
				courts_at_settlement.append(c)
		var eval_result: Dictionary = CourtSystem.should_call_court(
			lord_rank, active_topics, courts_at_settlement
		)
		if eval_result.is_empty() or not eval_result.get("should_call", false):
			continue
		var ws: Dictionary = world_states.get(lord.character_id, {})
		var last_court_day: int = ws.get("last_court_called_ic_day", -1)
		if last_court_day >= 0 and ic_day - last_court_day < 30:
			continue
		var court_type: CourtSessionData.CourtType = CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT
		if lord.status >= 7.0:
			court_type = CourtSessionData.CourtType.CLAN_CHAMPION_COURT
		var settlement_id: int = int(lord.physical_location)
		var court := CourtSystem.create_court(
			next_court_id[0], court_type, lord.character_id,
			settlement_id, lord.clan, ic_day,
		)
		next_court_id[0] += 1
		var trigger_id: int = eval_result.get("trigger_topic_id", -1)
		court.crisis_trigger_topic_id = trigger_id
		var agenda: Array[int] = CourtSystem.select_agenda_topics(
			active_topics, court_type, trigger_id
		)
		CourtSystem.set_agenda(court, agenda)
		CourtSystem.add_attendee(court, lord.character_id)
		active_courts.append(court)
		if ws.is_empty():
			ws = {}
			world_states[lord.character_id] = ws
		ws["last_court_called_ic_day"] = ic_day
		results.append({
			"court_id": court.court_id,
			"lord_id": lord.character_id,
			"court_type": court_type,
			"trigger_topic_id": trigger_id,
			"crisis_called": true,
		})
	return results


static func _track_court_called(
	world_states: Dictionary,
	lord_id: int,
	ic_day: int,
	current_season: int = -1,
) -> void:
	var ws: Dictionary = world_states.get(lord_id, {})
	if ws.is_empty():
		ws = {}
		world_states[lord_id] = ws
	ws["last_court_called_ic_day"] = ic_day
	if current_season >= 0:
		ws["last_court_season"] = current_season


static func _status_to_lord_rank(status: float) -> Enums.LordRank:
	if status >= 9.0:
		return Enums.LordRank.IMPERIAL
	elif status >= 7.0:
		return Enums.LordRank.CLAN_CHAMPION
	elif status >= 6.0:
		return Enums.LordRank.FAMILY_DAIMYO
	elif status >= 5.0:
		return Enums.LordRank.PROVINCIAL_DAIMYO
	elif status >= 4.0:
		return Enums.LordRank.CITY_DAIMYO
	return Enums.LordRank.VILLAGE_HEADMAN


static func _process_court_openings(
	active_courts: Array[CourtSessionData],
	ic_day: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for court: CourtSessionData in active_courts:
		if court.phase != CourtSessionData.CourtPhase.SCHEDULED:
			continue
		if ic_day >= court.start_ic_day:
			CourtSystem.open_court(court, ic_day)
			results.append({
				"court_id": court.court_id,
				"opened": true,
				"ic_day": ic_day,
			})
	return results


static func _process_court_attendance(
	active_courts: Array[CourtSessionData],
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary = {},
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for court: CourtSessionData in active_courts:
		if not CourtSystem.is_active(court):
			continue
		var settlement_str: String = str(court.host_settlement_id)
		for c: L5RCharacterData in characters:
			var at_settlement: bool = c.physical_location == settlement_str
			var is_attending: bool = c.character_id in court.attendee_ids
			if at_settlement and not is_attending:
				CourtSystem.add_attendee(court, c.character_id)
				results.append({
					"court_id": court.court_id,
					"character_id": c.character_id,
					"action": "arrived",
				})
			elif not at_settlement and is_attending and c.character_id != court.host_lord_id:
				CourtSystem.remove_attendee(court, c.character_id)
				var departure := _apply_early_departure(c, court, characters_by_id)
				departure["court_id"] = court.court_id
				departure["character_id"] = c.character_id
				departure["action"] = "departed"
				results.append(departure)
	return results


static func _apply_early_departure(
	character: L5RCharacterData,
	court: CourtSessionData,
	characters_by_id: Dictionary,
) -> Dictionary:
	var is_host: bool = character.character_id == court.host_lord_id
	var is_proxy: bool = false
	var cost: Dictionary = CourtPrioritySystem.get_early_departure_cost(is_host, is_proxy)

	var honor_loss: float = cost.get("honor_loss", 0.0)
	var glory_loss: float = cost.get("glory_loss", 0.0)
	var disp_cost: int = cost.get("disposition_cost", 0)

	if honor_loss != 0.0:
		HonorGlorySystem.apply_honor_change(character, honor_loss)
	if glory_loss != 0.0:
		HonorGlorySystem.apply_glory_change(character, glory_loss)
	if disp_cost != 0:
		var host: L5RCharacterData = characters_by_id.get(court.host_lord_id) as L5RCharacterData
		if host != null:
			var current: int = int(host.disposition_values.get(character.character_id, 0))
			host.disposition_values[character.character_id] = clampi(current + disp_cost, -100, 100)

	return {
		"honor_loss": honor_loss,
		"glory_loss": glory_loss,
		"disposition_cost": disp_cost,
	}


# -- Edict Compliance Processing -----------------------------------------------

static func _process_edict_compliance(
	active_edicts: Array[EdictData],
	active_wars: Array[WarData],
	characters: Array[L5RCharacterData],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = ImperialEdictSystem.process_daily_compliance(
		active_edicts, active_wars, characters, ic_day,
	)
	for r: Dictionary in results:
		var topic_dict: Dictionary = r.get("defiance_topic", {})
		if topic_dict.is_empty():
			continue
		var t := TopicData.new()
		t.topic_id = next_topic_id[0]
		next_topic_id[0] += 1
		t.topic_type = topic_dict.get("topic_type", "edict_defiance")
		t.variant = topic_dict.get("variant", "")
		t.slug = topic_dict.get("slug", "")
		t.tier = topic_dict.get("tier", TopicData.Tier.TIER_1)
		t.category = topic_dict.get("category", TopicData.Category.POLITICAL)
		t.momentum = topic_dict.get("momentum", 90.0)
		t.clan_involved = topic_dict.get("clan_involved", "")
		t.subject_character_id = topic_dict.get("subject_character_id", -1)
		t.ic_day_created = ic_day
		active_topics.append(t)
		r["defiance_topic_id"] = t.topic_id
	return results


static func _process_edict_compliance_actions(
	day_results: Array,
	active_edicts: Array[EdictData],
) -> void:
	for result: Dictionary in day_results:
		var effects: Dictionary = result.get("effects", {})
		if not effects.get("requires_edict_compliance", false):
			continue
		var edict_id: int = effects.get("edict_id", -1)
		var clan: String = effects.get("clan", "")
		var compliant: bool = effects.get("compliant", true)
		if edict_id < 0 or clan.is_empty():
			continue
		for edict: EdictData in active_edicts:
			if edict.edict_id == edict_id and edict.is_active:
				ImperialEdictSystem.record_compliance(edict, clan, compliant)
				break


static func _process_strategic_court_calls(
	strategic_results: Array[Dictionary],
	active_courts: Array[CourtSessionData],
	active_topics: Array[TopicData],
	characters_by_id: Dictionary,
	next_court_id: Array[int],
	ic_day: int,
	world_states: Dictionary = {},
	current_season: int = -1,
) -> void:
	for directive: Dictionary in strategic_results:
		var directive_type = directive.get("directive", "")
		if directive_type == "WINTER_COURT_HOST":
			_create_winter_court_from_directive(
				directive, active_courts, active_topics,
				characters_by_id, next_court_id, ic_day,
			)
			continue
		if directive_type != StrategicReview.Directive.CALL_COURT:
			continue
		var lord_id: int = directive.get("lord_id", -1)
		if lord_id < 0:
			continue
		var lord: L5RCharacterData = characters_by_id.get(lord_id) as L5RCharacterData
		if lord == null:
			continue

		var already_hosting: bool = false
		for c: CourtSessionData in active_courts:
			if c.host_lord_id == lord_id and CourtSystem.is_active(c):
				already_hosting = true
				break
		if already_hosting:
			continue

		var court_type: CourtSessionData.CourtType = CourtSessionData.CourtType.PROVINCIAL_FAMILY_COURT
		if lord.status >= 7.0:
			court_type = CourtSessionData.CourtType.CLAN_CHAMPION_COURT

		var settlement_id: int = int(lord.physical_location) if lord.physical_location.is_valid_int() else -1
		if settlement_id < 0:
			continue
		var agenda: Array[int] = CourtSystem.select_agenda_topics(
			active_topics, court_type
		)

		var court := CourtSystem.create_court(
			next_court_id[0], court_type, lord_id,
			settlement_id, lord.clan, ic_day + 1
		)
		next_court_id[0] += 1
		CourtSystem.set_agenda(court, agenda)
		CourtSystem.add_attendee(court, lord_id)
		active_courts.append(court)

		_track_court_called(world_states, lord_id, ic_day, current_season)


static func _create_winter_court_from_directive(
	directive: Dictionary,
	active_courts: Array[CourtSessionData],
	active_topics: Array[TopicData],
	characters_by_id: Dictionary,
	next_court_id: Array[int],
	ic_day: int,
) -> void:
	var emperor_id: int = directive.get("lord_id", -1)
	var host_clan: String = directive.get("host_clan", "")
	if emperor_id < 0 or host_clan.is_empty():
		return

	for c: CourtSessionData in active_courts:
		if c.court_type == CourtSessionData.CourtType.IMPERIAL_WINTER_COURT:
			if c.phase != CourtSessionData.CourtPhase.CLOSED:
				return

	var host_settlement_id: int = -1
	var host_champion_id: int = -1
	for char_id: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[char_id] as L5RCharacterData
		if c != null and c.clan == host_clan and c.status >= 7.0 and c.lord_id == -1:
			host_champion_id = c.character_id
			var loc: String = c.physical_location
			host_settlement_id = int(loc) if loc.is_valid_int() else -1
			break
	if host_settlement_id < 0:
		return

	var agenda: Array[int] = CourtSystem.select_agenda_topics(
		active_topics, CourtSessionData.CourtType.IMPERIAL_WINTER_COURT
	)

	var start_day: int = ic_day + 30
	var court := CourtSystem.create_court(
		next_court_id[0],
		CourtSessionData.CourtType.IMPERIAL_WINTER_COURT,
		emperor_id,
		host_settlement_id,
		host_clan,
		start_day,
		CourtSystem.WINTER_COURT_DURATION,
		true,
	)
	next_court_id[0] += 1
	CourtSystem.set_agenda(court, agenda)
	CourtSystem.add_attendee(court, emperor_id)
	if host_champion_id >= 0 and host_champion_id != emperor_id:
		CourtSystem.add_attendee(court, host_champion_id)
	active_courts.append(court)
