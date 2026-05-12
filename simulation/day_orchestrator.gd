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
	ships: Array[ShipData] = [],
	children: Array[ChildRecord] = [],
	next_character_id: Array[int] = [10000],
	seiyaku_state: Dictionary = {},
	marriages: Array[Dictionary] = [],
	worship_state: Dictionary = {},
	constructions: Array[ConstructionData] = [],
	next_settlement_id: Array[int] = [5000],
	next_construction_id: Array[int] = [1],
) -> Dictionary:
	var prev_season: int = time_system.get_season()

	time_system.advance_tick()

	var ic_day: int = time_system.get_ic_day()
	var current_season: int = time_system.get_season()

	_reset_all_ap(characters)

	var _spm: Dictionary = {}
	for _s: SettlementData in settlements:
		_spm[_s.settlement_id] = _s.province_id
	world_states["_settlement_province_map"] = _spm

	_populate_infrastructure_intelligence(world_states, provinces, settlements, ships, worship_state)
	_populate_vacancy_intelligence(world_states, characters, characters_by_id, companies)

	var festival_results: Dictionary = _process_festivals(ic_day, world_states)

	var travel_arrivals: Array[Dictionary] = _process_travel(characters)
	_process_arrival_observation(travel_arrivals, characters_by_id, current_season)

	var musha_season_count: int = int(season_meta.get("horde_season_count", 0))
	var musha_shugyo_results: Array[Dictionary] = _process_musha_shugyo(characters, characters_by_id, ic_day, objectives_map, dice_engine, musha_season_count)

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

	var wm_for_military: Dictionary = world_states.get("_worship_maluses", {})
	var military_daily: Dictionary = _process_military_daily(
		active_armies, active_sieges, active_tethers, order_states,
		dice_engine, settlements, companies, wm_for_military,
	)

	var naval_weather: int = _process_naval_weather(
		dice_engine, _season_to_name(current_season), season_meta,
	)
	var naval_movement_results: Array[Dictionary] = _process_ship_movement(
		ships, dice_engine,
	)
	var naval_battle_results: Array[Dictionary] = _process_naval_battle_triggers(
		ships, characters_by_id, active_wars, naval_weather, dice_engine,
	)
	_apply_naval_battle_mutations(naval_battle_results, ships, characters_by_id)

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

	var worship_accumulation_results: Array[Dictionary] = _process_worship_accumulation(
		day_result.get("results", []), worship_state,
	)

	var construction_results: Array[Dictionary] = _process_construction_effects(
		day_result.get("results", []),
		characters_by_id,
		provinces,
		settlements,
		constructions,
		next_settlement_id,
		next_construction_id,
		ic_day,
		ships,
		dice_engine,
	)

	_process_edict_compliance_actions(
		day_result.get("results", []),
		active_edicts,
	)

	var governance_results: Dictionary = _process_governance_effects(
		day_result.get("results", []),
		characters_by_id,
		marriages,
		ic_day,
		world_states,
		favors,
		active_topics,
		next_topic_id,
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

	var naval_war_score_results: Array[Dictionary] = _process_naval_war_scores(
		naval_battle_results, active_wars,
	)
	war_score_results.append_array(naval_war_score_results)

	var naval_topics: Array[TopicData] = _generate_naval_battle_topics(
		naval_battle_results, active_topics, next_topic_id, ic_day,
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
	var gempukku_results: Dictionary = {}
	var advancement_results: Dictionary = {}
	var ronin_results: Dictionary = {}
	var pregnancy_results: Array[Dictionary] = []
	var seiyaku_results: Dictionary = {}
	var worship_seasonal_results: Dictionary = {}
	if current_season != prev_season:
		# Add the IC year to miya_inputs so per-province blessed-year tracking
		# stays consistent. Year is computed from the time system's tick count.
		var spring_inputs: Dictionary = miya_inputs.duplicate()
		if current_season == TimeSystem.Season.SPRING and not miya_inputs.is_empty():
			spring_inputs["current_ic_year"] = time_system.get_ic_year()
		worship_seasonal_results = _process_seasonal_worship(
			worship_state, settlements, provinces,
		)
		var worship_maluses: Dictionary = WorshipSystem.compute_all_province_maluses(
			worship_state, provinces,
		)
		world_states["_worship_maluses"] = worship_maluses
		seasonal_result = _process_season_transition(
			characters, provinces, current_season, season_meta,
			approach_penalties, settlements, spring_inputs, worship_maluses,
		)
		_apply_worship_stability_maluses(worship_maluses, provinces)
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
			next_insurgency_id, world_states, worship_maluses,
		)
		_process_construction_completions(
			constructions, settlements, provinces, ships, dice_engine,
			next_settlement_id, active_topics, next_topic_id, ic_day,
		)
		_process_organic_villages(
			provinces, settlements, next_settlement_id,
			active_topics, next_topic_id, ic_day,
		)
		var _sett_prov_map: Dictionary = {}
		for s: SettlementData in settlements:
			_sett_prov_map[s.settlement_id] = s.province_id
		gempukku_results = _process_gempukku(
			children, characters, characters_by_id, next_character_id,
			dice_engine, ic_day, active_topics, next_topic_id, objectives_map,
			worship_maluses, _sett_prov_map,
		)
		advancement_results = _process_npc_advancement(
			characters, active_courts, active_sieges, active_armies,
			insurgencies, current_season,
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
		var provinces_array: Array[ProvinceData] = _dict_values_to_province_array(provinces)
		var emperor_archetype: int = world_states.get("emperor_archetype", StrategicReview.EmperorArchetype.IRON)
		var wc_letter_id: Array[int] = [pending_letters.size() + 1000]
		_process_strategic_court_calls(
			strategic_results, active_courts, active_topics,
			characters_by_id, next_court_id, ic_day, world_states,
			current_season, provinces_array, settlements,
			emperor_archetype, next_topic_id,
			pending_letters, dice_engine, wc_letter_id,
		)
		_process_vassal_reassignments(
			strategic_results, objectives_map, characters_by_id,
		)
		if not seiyaku_state.is_empty():
			seiyaku_results = _process_seiyaku_review(
				seiyaku_state, characters, characters_by_id,
				emperor_archetype, active_wars, active_topics,
				next_topic_id, ic_day,
			)
		var season_count: int = int(season_meta.get("horde_season_count", 0))
		ronin_results = _process_seasonal_ronin(characters, season_count)
		pregnancy_results = _process_pregnancy_checks(
			marriages, characters_by_id, children, dice_engine, ic_day,
			next_character_id,
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
		"governance_results": governance_results,
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
		"naval_weather": naval_weather,
		"naval_movement_results": naval_movement_results,
		"naval_battle_results": naval_battle_results,
		"naval_topics": naval_topics,
		"musha_shugyo_results": musha_shugyo_results,
		"gempukku_results": gempukku_results,
		"advancement_results": advancement_results,
		"ronin_results": ronin_results,
		"pregnancy_results": pregnancy_results,
		"seiyaku_results": seiyaku_results,
		"worship_accumulation_results": worship_accumulation_results,
		"worship_seasonal_results": worship_seasonal_results,
		"construction_results": construction_results,
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

		var pair_count: int = group.size() * (group.size() - 1) >> 1
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
	worship_maluses: Dictionary = {},
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
		province_array, settlements, season_name, season_meta, resolved_inputs,
		worship_maluses,
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
	_world_states: Dictionary,
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


static func _get_season_days(season: int) -> int:
	match season:
		TimeSystem.Season.SPRING: return TimeSystem.SPRING_DAYS
		TimeSystem.Season.SUMMER: return TimeSystem.SUMMER_DAYS
		TimeSystem.Season.AUTUMN: return TimeSystem.AUTUMN_DAYS
		TimeSystem.Season.WINTER: return TimeSystem.WINTER_DAYS
	return 90


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

	for char_id in world_states:
		if char_id is not int:
			continue
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
	worship_maluses: Dictionary = {},
) -> Dictionary:
	var ptls: Dictionary = {}
	for pid: int in provinces:
		var prov: ProvinceData = provinces[pid]
		ptls[pid] = prov.province_taint_level

	var per_province_ws: Dictionary = {}
	for pid: int in provinces:
		per_province_ws[pid] = world_states.get(pid, {})

	var result: Dictionary = InsurgencySystem.process_season(
		insurgencies, provinces, ptls, dice_engine, current_season,
		next_insurgency_id[0], per_province_ws, worship_maluses,
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
	worship_maluses: Dictionary = {},
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
		active_armies, tether_by_army, companies, worship_maluses,
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
	worship_maluses: Dictionary = {},
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

		var tether: Dictionary = tether_state_by_army.get(army_id, {})
		var overall_state: int = tether.get("overall_state", SupplyTetherSystem.TetherState.SOLID)
		var rice_supplied: bool = overall_state == SupplyTetherSystem.TetherState.SOLID
		var arms_supplied: bool = overall_state == SupplyTetherSystem.TetherState.SOLID
		var arms_tick: int = tether.get("arms_deprivation_tick", 0)

		var army_province: int = army.get("province_id", -1)
		var army_malus: Dictionary = worship_maluses.get(army_province, {})
		var healing_halved: bool = army_malus.get("healing_slower", false)
		var recovery_doubled: bool = army_malus.get("injury_recovery_doubled", false)

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
				if healing_halved and health_recovery > 0:
					health_recovery = maxi(health_recovery / 2, 1)
				if recovery_doubled and health_recovery > 0:
					health_recovery = maxi(health_recovery / 2, 1)

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
		var tether_result: Dictionary = tether_results[i]
		var rice_tick: int = tether_result.get("rice_deprivation_tick", 0)
		var arms_tick: int = tether_result.get("arms_deprivation_tick", 0)

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
	_dice_engine: DiceEngine,
	_season_name: String,
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
	_companies: Array[Dictionary],
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
	for tether_r: Variant in tether_results:
		if not (tether_r is Dictionary):
			continue
		var td: Dictionary = tether_r
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
	worship_maluses: Dictionary = {},
) -> Dictionary:
	_inject_worship_battle_maluses(attacker_states, worship_maluses)
	_inject_worship_battle_maluses(defender_states, worship_maluses)
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
	var tier: FavorData.FavorTier = FavorData.FavorTier.MINOR
	match favor_tier:
		2: tier = FavorData.FavorTier.MODERATE
		1: tier = FavorData.FavorTier.MAJOR

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
			if court.court_type == CourtSessionData.CourtType.IMPERIAL_WINTER_COURT:
				var glory_rewards: Array[Dictionary] = WinterCourtSystem.compute_glory_rewards(court, characters_by_id)
				for reward: Dictionary in glory_rewards:
					var rid: int = reward.get("character_id", -1)
					var rchar: L5RCharacterData = characters_by_id.get(rid) as L5RCharacterData
					if rchar != null:
						rchar.glory = clampf(rchar.glory + reward.get("glory_change", 0.0), 0.0, 10.0)
				close_result["glory_rewards"] = glory_rewards
				if court.announcement_topic_id >= 0:
					for topic: TopicData in active_topics:
						if topic.topic_id == court.announcement_topic_id:
							topic.resolved = true
							break
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
	provinces: Array[ProvinceData] = [],
	settlements: Array[SettlementData] = [],
	archetype: int = StrategicReview.EmperorArchetype.IRON,
	next_topic_id: Array[int] = [1],
	pending_letters: Array = [],
	dice_engine: DiceEngine = null,
	next_letter_id: Array[int] = [1],
) -> void:
	for directive: Dictionary in strategic_results:
		var directive_type = directive.get("directive", "")
		if directive_type == "WINTER_COURT_HOST":
			_create_winter_court_from_directive(
				directive, active_courts, active_topics,
				characters_by_id, next_court_id, ic_day,
				provinces, settlements, world_states,
				archetype, next_topic_id,
				pending_letters, dice_engine, next_letter_id,
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
	provinces: Array[ProvinceData] = [],
	settlements: Array[SettlementData] = [],
	world_state: Dictionary = {},
	archetype: int = StrategicReview.EmperorArchetype.IRON,
	next_topic_id: Array[int] = [1],
	pending_letters: Array = [],
	dice_engine: DiceEngine = null,
	next_letter_id: Array[int] = [1],
) -> Dictionary:
	var emperor_id: int = directive.get("lord_id", -1)
	if emperor_id < 0:
		return {}

	for c: CourtSessionData in active_courts:
		if c.court_type == CourtSessionData.CourtType.IMPERIAL_WINTER_COURT:
			if c.phase != CourtSessionData.CourtPhase.CLOSED:
				return {}

	var emperor: L5RCharacterData = characters_by_id.get(emperor_id) as L5RCharacterData

	var host_result: Dictionary
	if not provinces.is_empty() and not settlements.is_empty():
		host_result = WinterCourtSystem.run_winter_court_selection(
			emperor, archetype, characters_by_id, provinces, settlements,
			active_topics, world_state
		)
	else:
		host_result = _legacy_host_selection(directive, characters_by_id)

	if host_result.is_empty() or host_result.get("skipped", false):
		return host_result

	var host_settlement_id: int = host_result.get("settlement_id", -1)
	var host_clan: String = host_result.get("host_clan", "")
	var host_daimyo_id: int = host_result.get("host_daimyo_id", -1)
	var host_champion_id: int = host_result.get("clan_champion_id", -1)
	var is_regent: bool = host_result.get("is_regent_court", false)

	if host_settlement_id < 0:
		return {}

	var agenda: Array[int] = CourtSystem.select_agenda_topics(
		active_topics, CourtSessionData.CourtType.IMPERIAL_WINTER_COURT
	)

	var start_day: int = ic_day + (WinterCourtSystem.WINTER_START_IC_DAY - WinterCourtSystem.ANNOUNCEMENT_IC_DAY)
	var prestige: int = host_result.get("prestige", CourtSystem.PRESTIGE_IMPERIAL)

	var court := CourtSystem.create_court(
		next_court_id[0],
		CourtSessionData.CourtType.IMPERIAL_WINTER_COURT,
		emperor_id if not is_regent else host_result.get("selector_id", emperor_id),
		host_settlement_id,
		host_clan,
		start_day,
		CourtSystem.WINTER_COURT_DURATION,
		not is_regent,
	)
	court.prestige = prestige
	court.is_regent_court = is_regent
	court.host_family_daimyo_id = host_daimyo_id
	court.clan_champion_id = host_champion_id
	court.grace_period_days = WinterCourtSystem.GRACE_PERIOD_DAYS
	court.no_edicts = host_result.get("no_edicts", false)
	next_court_id[0] += 1
	CourtSystem.set_agenda(court, agenda)

	var host_lord_rank: Enums.LordRank = _status_to_lord_rank(
		characters_by_id.get(host_daimyo_id) as L5RCharacterData
	) if host_daimyo_id >= 0 else Enums.LordRank.PROVINCIAL_DAIMYO

	var invitation_result: Dictionary = WinterCourtSystem.run_invitation_pipeline(
		host_result, emperor, archetype, characters_by_id,
		host_lord_rank, agenda
	)

	var all_invited: Array = invitation_result.get("all_invited", [])
	for inv_id: Variant in all_invited:
		CourtSystem.add_attendee(court, int(inv_id))
	court.personal_invitation_ids = invitation_result.get("personal_invitations", [])
	court.clan_delegation_ids = invitation_result.get("clan_delegations", {})

	active_courts.append(court)

	var topic_info: Dictionary = WinterCourtSystem.generate_announcement_topic(
		host_daimyo_id, host_clan, host_result.get("province_id", -1)
	)
	var topic := TopicData.new()
	topic.topic_id = next_topic_id[0]
	next_topic_id[0] += 1
	topic.topic_type = topic_info.get("topic_type", "")
	topic.variant = topic_info.get("variant", "")
	topic.slug = topic_info.get("slug", "")
	topic.tier = topic_info.get("tier", TopicData.Tier.TIER_3)
	topic.category = topic_info.get("category", TopicData.Category.POLITICAL)
	topic.momentum = topic_info.get("momentum", 40.0)
	topic.resolved = false
	topic.clan_involved = topic_info.get("clan_involved", "")
	topic.provinces_affected = topic_info.get("provinces_affected", [])
	active_topics.append(topic)
	court.announcement_topic_id = topic.topic_id

	var letters_sent: int = _dispatch_winter_court_summons(
		emperor, host_clan, topic.topic_id, ic_day, characters_by_id,
		pending_letters, dice_engine, next_letter_id,
	)

	return {
		"court_id": court.court_id,
		"host_clan": host_clan,
		"host_settlement_id": host_settlement_id,
		"host_daimyo_id": host_daimyo_id,
		"is_regent_court": is_regent,
		"invitation_count": all_invited.size(),
		"announcement_topic_id": topic.topic_id,
		"summons_letters_sent": letters_sent,
	}


static func _legacy_host_selection(
	directive: Dictionary,
	characters_by_id: Dictionary,
) -> Dictionary:
	var host_clan: String = directive.get("host_clan", "")
	if host_clan.is_empty():
		return {}
	for char_id: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[char_id] as L5RCharacterData
		if c != null and c.clan == host_clan and c.status >= 7.0 and c.lord_id == -1:
			var loc: String = c.physical_location
			var sid: int = int(loc) if loc.is_valid_int() else -1
			if sid >= 0:
				return {
					"settlement_id": sid,
					"host_clan": host_clan,
					"host_daimyo_id": c.character_id,
					"clan_champion_id": c.character_id,
					"is_regent_court": false,
					"prestige": CourtSystem.PRESTIGE_IMPERIAL,
					"no_edicts": false,
				}
	return {}


static func _dispatch_winter_court_summons(
	emperor: L5RCharacterData,
	host_clan: String,
	announcement_topic_id: int,
	ic_day: int,
	characters_by_id: Dictionary,
	pending_letters: Array,
	dice_engine: DiceEngine,
	next_letter_id: Array[int],
) -> int:
	if emperor == null or dice_engine == null:
		return 0

	var letters_sent: int = 0
	for char_id: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[char_id] as L5RCharacterData
		if c == null or CharacterStats.is_dead(c):
			continue
		if c.lord_id != -1 or c.status < 7.0:
			continue
		if c.clan == "Imperial" or c.clan == host_clan:
			continue
		if c.character_id == emperor.character_id:
			continue

		var letter: LetterData = LetterSystem.write_letter(
			next_letter_id[0], emperor, c.character_id,
			announcement_topic_id, ic_day, dice_engine,
			3, 0, 0, 0, true,
		)
		next_letter_id[0] += 1
		pending_letters.append(letter)
		letters_sent += 1

	return letters_sent


# -- Naval Processing ----------------------------------------------------------

static func _process_naval_weather(
	dice_engine: DiceEngine,
	season_name: String,
	season_meta: Dictionary,
) -> int:
	var weather: int = NavalSystem.determine_weather(dice_engine, season_name)
	season_meta["current_naval_weather"] = weather
	return weather


static func _process_ship_movement(
	ships: Array[ShipData],
	dice_engine: DiceEngine,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for ship: ShipData in ships:
		if ship.is_destroyed or ship.is_captured:
			continue
		if not ship.is_moving:
			continue

		ship.movement_days_remaining -= 1

		if ship.movement_days_remaining <= 0:
			ship.is_moving = false
			var prev_subtile: int = ship.current_subtile_id
			ship.current_subtile_id = ship.destination_subtile_id
			ship.destination_subtile_id = -1
			ship.movement_days_remaining = 0

			var deep_ocean_loss: bool = false
			var loss_chance: float = NavalSystem.get_deep_ocean_loss_chance(ship.ship_class)
			if loss_chance > 0.0:
				var roll: int = dice_engine.rand_int_range(1, 100)
				if roll <= ceili(loss_chance * 100.0):
					deep_ocean_loss = true
					ship.is_destroyed = true

			results.append({
				"ship_id": ship.ship_id,
				"arrived": true,
				"from_subtile": prev_subtile,
				"to_subtile": ship.current_subtile_id,
				"deep_ocean_loss": deep_ocean_loss,
			})
		else:
			results.append({
				"ship_id": ship.ship_id,
				"arrived": false,
				"days_remaining": ship.movement_days_remaining,
			})

	return results


static func _process_naval_battle_triggers(
	ships: Array[ShipData],
	characters_by_id: Dictionary,
	active_wars: Array[WarData],
	weather: int,
	dice_engine: DiceEngine,
) -> Array[Dictionary]:
	var ships_by_subtile: Dictionary = {}
	for ship: ShipData in ships:
		if ship.is_destroyed or ship.is_captured or ship.is_moving:
			continue
		if ship.current_subtile_id < 0:
			continue
		if not ships_by_subtile.has(ship.current_subtile_id):
			ships_by_subtile[ship.current_subtile_id] = []
		ships_by_subtile[ship.current_subtile_id].append(ship)

	var results: Array[Dictionary] = []
	var processed_subtiles: Array[int] = []

	for subtile_id: int in ships_by_subtile:
		if subtile_id in processed_subtiles:
			continue
		var ships_at: Array = ships_by_subtile[subtile_id]
		if ships_at.size() < 2:
			continue

		var clans_at: Dictionary = {}
		for s: ShipData in ships_at:
			if not clans_at.has(s.owning_clan):
				clans_at[s.owning_clan] = []
			clans_at[s.owning_clan].append(s)

		if clans_at.size() < 2:
			continue

		var hostile_pairs: Array[Array] = _find_hostile_naval_pairs(
			clans_at, active_wars,
		)
		if hostile_pairs.is_empty():
			continue

		processed_subtiles.append(subtile_id)

		for pair: Array in hostile_pairs:
			var attacker_clan: String = pair[0]
			var defender_clan: String = pair[1]
			var atk_ships: Array = clans_at.get(attacker_clan, [])
			var def_ships: Array = clans_at.get(defender_clan, [])

			if atk_ships.is_empty() or def_ships.is_empty():
				continue

			var battle_result: Dictionary = _resolve_naval_engagement(
				atk_ships, def_ships, weather, dice_engine,
				characters_by_id, attacker_clan, defender_clan,
			)
			battle_result["subtile_id"] = subtile_id
			battle_result["attacker_clan"] = attacker_clan
			battle_result["defender_clan"] = defender_clan
			results.append(battle_result)

	return results


static func _find_hostile_naval_pairs(
	clans_at: Dictionary,
	active_wars: Array[WarData],
) -> Array[Array]:
	var pairs: Array[Array] = []
	var clan_list: Array = clans_at.keys()
	for i: int in range(clan_list.size()):
		for j: int in range(i + 1, clan_list.size()):
			var a: String = clan_list[i]
			var b: String = clan_list[j]
			if WarSystem.are_clans_at_war(active_wars, a, b):
				pairs.append([a, b])
	return pairs


static func _resolve_naval_engagement(
	atk_ships: Array,
	def_ships: Array,
	weather: int,
	dice_engine: DiceEngine,
	characters_by_id: Dictionary,
	attacker_clan: String,
	defender_clan: String,
) -> Dictionary:
	var atk_states: Array[Dictionary] = []
	var def_states: Array[Dictionary] = []
	var col: int = 0

	for ship: ShipData in atk_ships:
		var captain: L5RCharacterData = null
		var captain_bonus: Dictionary = {}
		if ship.captain_id >= 0 and characters_by_id.has(ship.captain_id):
			captain = characters_by_id[ship.captain_id]
			captain_bonus = _compute_captain_bonus(captain)
		var is_mantis: bool = (ship.owning_clan == "Mantis")
		var row: int = 1
		if ship.ship_class == Enums.ShipClass.KOBUNE and col > 0:
			row = 2
		atk_states.append(NavalCombatSystem.make_naval_company(
			ship, row, col, "attacker", weather, is_mantis, captain, captain_bonus,
		))
		col += 1

	col = 0
	for ship: ShipData in def_ships:
		var captain: L5RCharacterData = null
		var captain_bonus: Dictionary = {}
		if ship.captain_id >= 0 and characters_by_id.has(ship.captain_id):
			captain = characters_by_id[ship.captain_id]
			captain_bonus = _compute_captain_bonus(captain)
		var is_mantis: bool = (ship.owning_clan == "Mantis")
		var row: int = 1
		if ship.ship_class == Enums.ShipClass.KOBUNE and col > 0:
			row = 2
		def_states.append(NavalCombatSystem.make_naval_company(
			ship, row, col, "defender", weather, is_mantis, captain, captain_bonus,
		))
		col += 1

	var result: Dictionary = NavalCombatSystem.resolve_naval_battle(
		atk_states, def_states, weather, dice_engine,
	)
	return result


static func _compute_captain_bonus(captain: L5RCharacterData) -> Dictionary:
	var battle_rank: int = captain.skills.get("Battle", 0)
	if battle_rank <= 0:
		return {}
	var highest_ring: int = Enums.Ring.FIRE
	var highest_val: int = 0
	for ring: int in [Enums.Ring.FIRE, Enums.Ring.WATER, Enums.Ring.EARTH, Enums.Ring.AIR, Enums.Ring.VOID]:
		var val: int = CharacterStats.get_ring_value(captain, ring)
		if val > highest_val:
			highest_val = val
			highest_ring = ring
	var bonus_type: String = "morale"
	if highest_ring == Enums.Ring.FIRE or highest_ring == Enums.Ring.WATER:
		bonus_type = "attack"
	elif highest_ring == Enums.Ring.EARTH or highest_ring == Enums.Ring.AIR:
		bonus_type = "defense"
	return {"bonus_type": bonus_type, "bonus_value": battle_rank}


static func _apply_naval_battle_mutations(
	naval_battle_results: Array[Dictionary],
	ships: Array[ShipData],
	characters_by_id: Dictionary,
) -> void:
	var ships_by_id: Dictionary = {}
	for s: ShipData in ships:
		ships_by_id[s.ship_id] = s

	for result: Dictionary in naval_battle_results:
		var all_states: Array = []
		all_states.append_array(result.get("attacker_states", []))
		all_states.append_array(result.get("defender_states", []))

		for bc: Dictionary in all_states:
			var ship_id: int = bc.get("company_id", -1)
			var ship: ShipData = ships_by_id.get(ship_id)
			if ship == null:
				continue

			ship.health = bc.get("current_health", ship.health)

			if bc.get("is_destroyed", false):
				ship.is_destroyed = true
				ship.health = 0

			if bc.get("is_captured", false):
				ship.is_captured = true
				var captor_side: String = "attacker" if bc["side"] == "defender" else "defender"
				ship.captured_by_clan = result.get(captor_side + "_clan", "")

		var captain_deaths: Array = result.get("captain_deaths", [])
		for cd: Dictionary in captain_deaths:
			if not cd.get("died", false):
				continue
			var dead_ship_id: int = cd.get("company_id", -1)
			var dead_ship: ShipData = ships_by_id.get(dead_ship_id)
			if dead_ship != null:
				dead_ship.captain_id = -1


static func _process_naval_war_scores(
	naval_battle_results: Array[Dictionary],
	active_wars: Array[WarData],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for battle: Dictionary in naval_battle_results:
		var atk_clan: String = battle.get("attacker_clan", "")
		var def_clan: String = battle.get("defender_clan", "")
		var victor: String = battle.get("victor", "draw")
		if victor == "draw":
			continue

		var winning_clan: String = atk_clan if victor == "attacker" else def_clan

		var atk_states: Array = battle.get("attacker_states", [])
		var def_states: Array = battle.get("defender_states", [])
		var total_ships: int = atk_states.size() + def_states.size()
		var event_type: String = "minor_battle"
		if total_ships >= 8:
			event_type = "decisive_battle"
		elif total_ships >= 4:
			event_type = "major_battle"

		var war: WarData = WarSystem.get_war_between(active_wars, atk_clan, def_clan)
		if war != null:
			var shift_result: Dictionary = WarSystem.apply_score_shift(
				war, event_type, winning_clan,
			)
			results.append({
				"war_id": war.war_id,
				"event": event_type,
				"winning_clan": winning_clan,
				"shift": shift_result.get("shift", 0),
			})

	return results


static func _generate_naval_battle_topics(
	naval_battle_results: Array[Dictionary],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> Array[TopicData]:
	var topics: Array[TopicData] = []
	for battle: Dictionary in naval_battle_results:
		var victor: String = battle.get("victor", "draw")
		var atk_clan: String = battle.get("attacker_clan", "")
		var def_clan: String = battle.get("defender_clan", "")

		var topic := TopicData.new()
		topic.topic_id = next_topic_id[0]
		next_topic_id[0] += 1
		topic.topic_type = "military"
		topic.variant = "naval_battle"
		topic.slug = "naval_battle_%s_vs_%s_d%d" % [atk_clan.to_lower(), def_clan.to_lower(), ic_day]
		topic.tier = TopicData.Tier.TIER_3
		topic.momentum = 30.0
		topic.category = TopicData.Category.MILITARY
		topic.ic_day_created = ic_day
		topic.resolved = false

		active_topics.append(topic)
		topics.append(topic)

	return topics


# -- Musha Shugyo (s57.48) ----------------------------------------------------

static func _process_musha_shugyo(
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	ic_day: int,
	objectives_map: Dictionary,
	dice_engine: DiceEngine = null,
	current_season_count: int = 0,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for character: L5RCharacterData in characters:
		if not MushaShugyo.should_end_pilgrimage(character, ic_day):
			continue
		if dice_engine != null and MushaShugyo.check_ronin_conversion(character, dice_engine):
			var result: Dictionary = MushaShugyo.end_pilgrimage_as_ronin(character)
			RoninSystem.mark_ronin_start(character, current_season_count)
			if objectives_map.has(character.character_id):
				objectives_map[character.character_id].erase("standing")
			results.append(result)
			continue
		var result: Dictionary = MushaShugyo.end_pilgrimage(character)
		if MushaShugyo.is_lord_dead_or_missing(result["original_lord_id"], characters_by_id):
			result["lord_dead"] = true
		if objectives_map.has(character.character_id):
			objectives_map[character.character_id].erase("standing")
		results.append(result)
	return results


# -- Otomo Seiyaku Review ------------------------------------------------------

static func _process_seiyaku_review(
	seiyaku_state: Dictionary,
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	emperor_archetype: int,
	active_wars: Array[WarData],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> Dictionary:
	var champion_dispositions: Dictionary = _build_champion_dispositions(characters, characters_by_id)
	var otomo_courtiers: Array[int] = _get_otomo_courtier_ids(characters)
	var war_context: Array = []
	for w: WarData in active_wars:
		war_context.append(WarSystem.to_context_dict(w))

	var result: Dictionary = OtomoSeiyakuSystem.process_seasonal_review(
		seiyaku_state,
		champion_dispositions,
		emperor_archetype,
		otomo_courtiers,
		otomo_courtiers.size(),
		war_context,
	)

	if result.get("exhaustion_topic", false):
		var topic := TopicData.new()
		topic.topic_id = next_topic_id[0]
		next_topic_id[0] += 1
		topic.slug = "otomo_resources_stretched_" + str(ic_day)
		topic.topic_type = "political"
		topic.variant = "otomo_exhaustion"
		topic.tier = TopicData.Tier.TIER_4
		topic.momentum = 11.0
		topic.category = TopicData.Category.POLITICAL
		active_topics.append(topic)
		result["exhaustion_topic_id"] = topic.topic_id

	return result


static func _build_champion_dispositions(
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
) -> Dictionary:
	var champions: Dictionary = {}
	for c: L5RCharacterData in characters:
		if c.clan.is_empty():
			continue
		if c.lord_id != -1:
			continue
		if c.status < 7.0:
			continue
		if c.wounds_taken > 0:
			var earth: int = CharacterStats.get_ring_value(c, Enums.Ring.EARTH)
			if CharacterStats.is_dead(c.wounds_taken, earth):
				continue
		if not champions.has(c.clan) or c.status > champions[c.clan].status:
			champions[c.clan] = c

	var dispositions: Dictionary = {}
	var clan_list: Array = champions.keys()
	for i: int in range(clan_list.size()):
		for j: int in range(i + 1, clan_list.size()):
			var a: L5RCharacterData = champions[clan_list[i]]
			var b: L5RCharacterData = champions[clan_list[j]]
			var pair_key: String = OtomoSeiyakuSystem.make_pair_key(
				clan_list[i] as String, clan_list[j] as String,
			)
			var disp_a: int = a.disposition_values.get(b.character_id, 0)
			var disp_b: int = b.disposition_values.get(a.character_id, 0)
			dispositions[pair_key] = (disp_a + disp_b) / 2
	return dispositions


static func _get_otomo_courtier_ids(characters: Array[L5RCharacterData]) -> Array[int]:
	var ids: Array[int] = []
	for c: L5RCharacterData in characters:
		if c.family != "Otomo":
			continue
		if c.school_type != Enums.SchoolType.COURTIER:
			continue
		if c.wounds_taken > 0:
			var earth: int = CharacterStats.get_ring_value(c, Enums.Ring.EARTH)
			if CharacterStats.is_dead(c.wounds_taken, earth):
				continue
		ids.append(c.character_id)
	return ids


# -- Gempukku & Population -----------------------------------------------------

static func _process_gempukku(
	children: Array[ChildRecord],
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	next_character_id: Array[int],
	dice_engine: DiceEngine,
	ic_day: int,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	objectives_map: Dictionary,
	worship_maluses: Dictionary = {},
	settlement_province_map: Dictionary = {},
) -> Dictionary:
	var result: Dictionary = GempukkuSystem.process_seasonal_gempukku(
		children, characters, next_character_id, dice_engine, ic_day,
		worship_maluses, settlement_province_map,
	)

	for nc: L5RCharacterData in result.get("new_characters", []):
		characters.append(nc)
		characters_by_id[nc.character_id] = nc
		if MushaShugyo.is_on_pilgrimage(nc):
			MushaShugyo.populate_objectives_map(nc.character_id, objectives_map)

	for rc: L5RCharacterData in result.get("replenishment_characters", []):
		characters.append(rc)
		characters_by_id[rc.character_id] = rc

	for cid: int in result.get("graduated_child_ids", []):
		for i: int in range(children.size() - 1, -1, -1):
			if children[i].child_id == cid:
				children.remove_at(i)
				break

	for dead_id: int in result.get("natural_deaths", []):
		if characters_by_id.has(dead_id):
			var dead_char: L5RCharacterData = characters_by_id[dead_id]
			var lethal: int = CharacterStats.get_ring_value(dead_char, Enums.Ring.EARTH) * 5 * 5
			dead_char.wounds_taken = lethal
			var topic := TopicData.new()
			topic.topic_id = next_topic_id[0]
			next_topic_id[0] += 1
			topic.slug = "natural_death_" + str(dead_id)
			topic.topic_type = "death"
			topic.variant = "natural"
			topic.tier = TopicData.Tier.TIER_4
			topic.momentum = 11.0
			topic.category = TopicData.Category.PERSONAL
			active_topics.append(topic)

	return result


# -- Ronin Processing (s52 Part 5) ---------------------------------------------

static func _process_seasonal_ronin(
	characters: Array[L5RCharacterData],
	current_season_count: int,
) -> Dictionary:
	return RoninSystem.process_seasonal_ronin(characters, current_season_count)


# -- NPC Advancement (s52 Part 3) ----------------------------------------------

static func _process_npc_advancement(
	characters: Array[L5RCharacterData],
	active_courts: Array[CourtSessionData],
	active_sieges: Array[Dictionary],
	active_armies: Array[Dictionary],
	insurgencies: Array[InsurgencyData],
	current_season: int,
) -> Dictionary:
	var days_in_season: int = _get_season_days(current_season)

	var adv_world_state: Dictionary = _build_advancement_world_state(
		characters, active_courts, active_sieges, active_armies, insurgencies
	)

	return NPCAdvancement.process_seasonal_advancement(characters, adv_world_state, days_in_season)


static func _build_advancement_world_state(
	characters: Array[L5RCharacterData],
	active_courts: Array[CourtSessionData],
	active_sieges: Array[Dictionary],
	active_armies: Array[Dictionary],
	insurgencies: Array[InsurgencyData],
) -> Dictionary:
	var in_court_ids: Array[int] = []
	for court: CourtSessionData in active_courts:
		if court.phase == CourtSessionData.CourtPhase.ACTIVE:
			for aid: int in court.attendee_ids:
				if not in_court_ids.has(aid):
					in_court_ids.append(aid)

	var in_siege_ids: Array[int] = []
	for siege: Dictionary in active_sieges:
		for cid: int in siege.get("defender_character_ids", []):
			if not in_siege_ids.has(cid):
				in_siege_ids.append(cid)
		for cid: int in siege.get("attacker_character_ids", []):
			if not in_siege_ids.has(cid):
				in_siege_ids.append(cid)

	var in_crisis_ids: Array[int] = []
	if insurgencies.size() > 0:
		for c: L5RCharacterData in characters:
			if c.role_position == "Clan Magistrate" or c.role_position == "Emerald Magistrate":
				in_crisis_ids.append(c.character_id)
			elif c.military_rank >= Enums.MilitaryRank.CHUI:
				in_crisis_ids.append(c.character_id)

	return {
		"in_battle_ids": [],
		"in_siege_ids": in_siege_ids,
		"in_court_ids": in_court_ids,
		"in_crisis_ids": in_crisis_ids,
	}


# -- Governance Effects --------------------------------------------------------

static func _process_governance_effects(
	results: Array,
	characters_by_id: Dictionary,
	marriages: Array,
	ic_day: int,
	world_states: Dictionary = {},
	favors: Array = [],
	active_topics: Array[TopicData] = [],
	next_topic_id: Array[int] = [1000],
) -> Dictionary:
	var appointment_results: Array[Dictionary] = []
	var marriage_results: Array[Dictionary] = []

	var clan_baselines: Dictionary = world_states.get("clan_baselines", {})
	var family_baselines: Dictionary = world_states.get("family_baselines", {})

	for result: Variant in results:
		if not (result is Dictionary):
			continue
		var rd: Dictionary = result
		var effects: Dictionary = rd.get("effects", {})

		if effects.get("requires_appointment", false):
			var ar: Dictionary = _apply_appointment(effects, characters_by_id)
			appointment_results.append(ar)

		if effects.get("requires_marriage", false):
			var wm: Dictionary = world_states.get("_worship_maluses", {})
			if _is_benten_marriage_blocked(effects, characters_by_id, wm):
				effects["requires_marriage"] = false
				effects["marriage_rejected"] = true
				effects["disposition_change"] = 0
				effects["rejection_reason"] = "benten_wrathful"
			if effects.get("requires_marriage", false):
				var mr: Dictionary = _apply_marriage(
					effects, characters_by_id, marriages, ic_day,
					clan_baselines, family_baselines, favors,
					active_topics, next_topic_id,
				)
				marriage_results.append(mr)

		if effects.get("marriage_rejected", false):
			var rr: Dictionary = _apply_marriage_rejection(effects, characters_by_id)
			marriage_results.append(rr)

	return {
		"appointments": appointment_results,
		"marriages": marriage_results,
	}


static func _apply_appointment(
	effects: Dictionary,
	characters_by_id: Dictionary,
) -> Dictionary:
	var appointee_id: int = effects.get("appointee_id", -1)
	var position: String = effects.get("position", "")
	var lord_id: int = effects.get("appointing_lord_id", -1)

	var appointee: L5RCharacterData = characters_by_id.get(appointee_id) as L5RCharacterData
	if appointee == null:
		return {"applied": false, "reason": "no_appointee", "appointee_id": appointee_id}

	appointee.role_position = position
	appointee.operational_superior_id = lord_id

	return {
		"applied": true,
		"appointee_id": appointee_id,
		"position": position,
		"lord_id": lord_id,
	}


static func _apply_marriage(
	effects: Dictionary,
	characters_by_id: Dictionary,
	marriages: Array,
	ic_day: int,
	clan_baselines: Dictionary = {},
	family_baselines: Dictionary = {},
	favors: Array = [],
	active_topics: Array[TopicData] = [],
	next_topic_id: Array[int] = [1000],
) -> Dictionary:
	var a_id: int = effects.get("candidate_a_id", -1)
	var b_id: int = effects.get("candidate_b_id", -1)
	var marriage_type: MarriageSystem.MarriageType = effects.get(
		"marriage_type", MarriageSystem.MarriageType.CROSS_CLAN
	)

	var char_a: L5RCharacterData = characters_by_id.get(a_id) as L5RCharacterData
	var char_b: L5RCharacterData = characters_by_id.get(b_id) as L5RCharacterData

	if char_a == null or char_b == null:
		return {"applied": false, "reason": "missing_character", "a_id": a_id, "b_id": b_id}

	if char_a.spouse_id >= 0 or char_b.spouse_id >= 0:
		return {"applied": false, "reason": "already_married", "a_id": a_id, "b_id": b_id}

	char_a.spouse_id = b_id
	char_b.spouse_id = a_id

	var original_clan_a: String = char_a.clan
	var original_clan_b: String = char_b.clan
	var original_family_a: String = char_a.family
	var original_family_b: String = char_b.family

	var moving_id: int = b_id
	if marriage_type == MarriageSystem.MarriageType.WITHIN_FAMILY:
		moving_id = -1

	if moving_id >= 0:
		_reassign_moving_character(
			char_a, char_b, moving_id, effects,
		)

	var record: Dictionary = MarriageSystem.create_marriage(
		a_id, b_id, marriage_type, moving_id, ic_day,
	)
	marriages.append(record)

	var boosts: Dictionary = MarriageSystem.get_marriage_boosts(marriage_type)

	if not clan_baselines.is_empty():
		CollectiveDisposition.apply_marriage(
			original_clan_a, original_clan_b,
			original_family_a, original_family_b,
			clan_baselines, family_baselines,
		)

	var favor_created: bool = false
	if boosts.get("favor_owed", false):
		var proposing_lord_id: int = effects.get("proposing_lord_id", -1)
		var target_lord_id: int = effects.get("target_lord_id", -1)
		if proposing_lord_id >= 0 and target_lord_id >= 0:
			var favor := FavorData.new()
			favor.favor_type = FavorData.FavorType.GENERAL
			favor.tier = FavorData.FavorTier.MODERATE
			favor.creditor_id = target_lord_id
			favor.debtor_id = proposing_lord_id
			favor.created_ic_day = ic_day
			favor.terms = "marriage_obligation"
			favor.source_action = "ARRANGE_MARRIAGE"
			favors.append(favor)
			favor_created = true

	var topic_id: int = -1
	if not next_topic_id.is_empty():
		var topic := TopicData.new()
		topic.topic_id = next_topic_id[0]
		next_topic_id[0] += 1
		topic.slug = "marriage_%s_%s_d%d" % [char_a.family, char_b.family, ic_day]
		topic.topic_type = "marriage"
		topic.variant = _marriage_type_to_variant(marriage_type)
		topic.category = TopicData.Category.POLITICAL
		topic.tier = TopicData.Tier.TIER_4
		topic.momentum = 11.0
		topic.ic_day_created = ic_day
		if char_a.clan != char_b.clan:
			topic.clan_involved = char_a.clan + "," + char_b.clan
		else:
			topic.clan_involved = char_a.clan
		active_topics.append(topic)
		topic_id = topic.topic_id

	return {
		"applied": true,
		"a_id": a_id,
		"b_id": b_id,
		"marriage_type": marriage_type,
		"clan_boost": boosts.get("clan_boost", 0),
		"family_boost": boosts.get("family_boost", 0),
		"favor_owed": boosts.get("favor_owed", false),
		"favor_created": favor_created,
		"topic_id": topic_id,
	}


static func _marriage_type_to_variant(mt: MarriageSystem.MarriageType) -> String:
	match mt:
		MarriageSystem.MarriageType.CROSS_CLAN:
			return "cross_clan"
		MarriageSystem.MarriageType.BETWEEN_FAMILIES:
			return "between_families"
		MarriageSystem.MarriageType.WITHIN_FAMILY:
			return "within_family"
	return "unknown"


static func _reassign_moving_character(
	char_a: L5RCharacterData,
	char_b: L5RCharacterData,
	moving_id: int,
	effects: Dictionary,
) -> void:
	var moving: L5RCharacterData = char_b if moving_id == char_b.character_id else char_a
	var staying: L5RCharacterData = char_a if moving_id == char_b.character_id else char_b

	moving.birth_clan = moving.clan
	moving.birth_family = moving.family

	moving.clan = staying.clan
	moving.family = staying.family

	var new_lord_id: int = effects.get("target_lord_id", -1)
	if moving_id == char_a.character_id:
		new_lord_id = effects.get("proposing_lord_id", -1)
	if new_lord_id >= 0:
		moving.lord_id = new_lord_id


static func _apply_marriage_rejection(
	effects: Dictionary,
	characters_by_id: Dictionary,
) -> Dictionary:
	var target_lord_id: int = effects.get("target_lord_id", -1)
	var proposing_lord_id: int = effects.get("proposing_lord_id", -1)
	var disp_change: int = effects.get("disposition_change", -3)

	var target_lord: L5RCharacterData = characters_by_id.get(target_lord_id) as L5RCharacterData
	if target_lord == null:
		return {"applied": false, "reason": "target_lord_not_found", "rejected": true}

	var current: int = target_lord.disposition_values.get(proposing_lord_id, 0)
	target_lord.disposition_values[proposing_lord_id] = clampi(current + disp_change, -100, 100)

	return {
		"applied": true,
		"rejected": true,
		"target_lord_id": target_lord_id,
		"proposing_lord_id": proposing_lord_id,
		"disposition_change": disp_change,
	}


# -- Pregnancy Processing (s22.7) -----------------------------------------------

static func _process_pregnancy_checks(
	marriages: Array,
	characters_by_id: Dictionary,
	children: Array[ChildRecord],
	dice_engine: DiceEngine,
	ic_day: int,
	next_character_id: Array[int] = [100000],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for m: Variant in marriages:
		if not (m is Dictionary):
			continue
		var marriage: Dictionary = m
		if not marriage.get("active", false):
			continue

		var a_id: int = marriage.get("character_a_id", -1)
		var b_id: int = marriage.get("character_b_id", -1)
		var char_a: L5RCharacterData = characters_by_id.get(a_id) as L5RCharacterData
		var char_b: L5RCharacterData = characters_by_id.get(b_id) as L5RCharacterData
		if char_a == null or char_b == null:
			continue
		if CharacterStats.is_dead(char_a) or CharacterStats.is_dead(char_b):
			continue

		var same_gender: bool = char_a.gender == char_b.gender
		if same_gender:
			continue

		var disp_a_to_b: int = char_a.disposition_values.get(b_id, 0)
		var disp_b_to_a: int = char_b.disposition_values.get(a_id, 0)
		var avg_disp: int = int((disp_a_to_b + disp_b_to_a) / 2)

		var roll: float = dice_engine.rand_int_range(1, 10000) / 10000.0
		if not MarriageSystem.check_pregnancy(avg_disp, roll):
			continue

		var father: L5RCharacterData = char_a if char_a.gender == "male" else char_b
		var mother: L5RCharacterData = char_b if char_a.gender == "male" else char_a

		var child_id: int = next_character_id[0]
		next_character_id[0] += 1

		var child: ChildRecord = GempukkuSystem.create_child_at_birth(
			child_id, father, mother, father.clan, father.family,
			ic_day, dice_engine,
		)
		children.append(child)
		father.children_ids.append(child_id)
		mother.children_ids.append(child_id)
		if not marriage.has("children_ids"):
			marriage["children_ids"] = [] as Array[int]
		(marriage["children_ids"] as Array[int]).append(child_id)

		results.append({
			"child_id": child_id,
			"father_id": father.character_id,
			"mother_id": mother.character_id,
			"clan": child.clan,
			"family": child.family,
			"gender": child.gender,
		})

	return results


# -- Vassal Reassignment (Strategic Review Directives) -------------------------

static func _process_vassal_reassignments(
	strategic_results: Array[Dictionary],
	objectives_map: Dictionary,
	characters_by_id: Dictionary,
) -> void:
	for directive: Dictionary in strategic_results:
		var directive_type: Variant = directive.get("directive", "")
		if directive_type != StrategicReview.Directive.REASSIGN_VASSAL_OBJECTIVE:
			continue

		var vassal_id: int = directive.get("vassal_id", -1)
		if vassal_id < 0:
			continue

		var decision: String = directive.get("decision", "")
		var lord_id: int = directive.get("lord_id", -1)

		if not objectives_map.has(vassal_id):
			objectives_map[vassal_id] = {}

		if decision == "ASSIGN":
			var new_obj: Dictionary = directive.get("new_objective", {})
			if not new_obj.is_empty():
				new_obj["assigned_by"] = lord_id
				new_obj["status"] = "ACTIVE"
				objectives_map[vassal_id]["standing"] = new_obj
		elif decision == "CONFIRM":
			var objectives: Dictionary = objectives_map.get(vassal_id, {})
			OrphanedObjectives.resolve_orphaned_objective(objectives, "CONFIRM")
		elif decision == "MODIFY":
			var new_obj: Dictionary = directive.get("new_objective", {})
			var objectives: Dictionary = objectives_map.get(vassal_id, {})
			OrphanedObjectives.resolve_orphaned_objective(objectives, "MODIFY", new_obj)
		elif decision == "CANCEL":
			var objectives: Dictionary = objectives_map.get(vassal_id, {})
			OrphanedObjectives.resolve_orphaned_objective(objectives, "CANCEL")


# -- Helpers -------------------------------------------------------------------

static func _dict_values_to_province_array(provinces: Dictionary) -> Array[ProvinceData]:
	var result: Array[ProvinceData] = []
	for pid: Variant in provinces:
		var p: ProvinceData = provinces[pid] as ProvinceData
		if p != null:
			result.append(p)
	return result


# -- Worship Processing -------------------------------------------------------

static func _process_worship_accumulation(
	day_results: Array,
	worship_state: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if worship_state.is_empty():
		return results
	for r: Variant in day_results:
		if not (r is Dictionary):
			continue
		var result: Dictionary = r as Dictionary
		var effects: Dictionary = result.get("effects", {})
		if not effects.get("requires_worship_accumulation", false):
			continue
		var province_id: Variant = effects.get("province_id", -1)
		var wp_dist: Dictionary = effects.get("wp_distribution", {})
		if province_id is int and province_id >= 0 and not wp_dist.is_empty():
			WorshipSystem.add_active_worship_to_province(
				worship_state, province_id, wp_dist,
			)
			results.append({
				"character_id": result.get("character_id", -1),
				"province_id": province_id,
				"total_wp": effects.get("total_wp", 0.0),
			})
	return results


static func _process_seasonal_worship(
	worship_state: Dictionary,
	settlements: Array[SettlementData],
	provinces: Dictionary,
) -> Dictionary:
	if worship_state.is_empty():
		return {}

	var province_worship_locations: Dictionary = {}
	for s: SettlementData in settlements:
		var pid: int = s.province_id
		if pid < 0:
			continue
		if not province_worship_locations.has(pid):
			province_worship_locations[pid] = []
		province_worship_locations[pid].append_array(s.worship_locations)

	var province_family_map: Dictionary = {}
	var family_clan_map: Dictionary = {}
	var all_province_ids: Array = []
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid] as ProvinceData
		if prov == null:
			continue
		all_province_ids.append(prov.province_id)
		var fam: String = prov.family
		var clan: String = prov.clan
		if not fam.is_empty():
			if not province_family_map.has(fam):
				province_family_map[fam] = []
			province_family_map[fam].append(prov.province_id)
		if not clan.is_empty() and not fam.is_empty():
			if not family_clan_map.has(clan):
				family_clan_map[clan] = []
			if fam not in family_clan_map[clan]:
				family_clan_map[clan].append(fam)

	var result: Dictionary = WorshipSystem.process_seasonal_worship(
		worship_state, province_worship_locations,
		province_family_map, family_clan_map, all_province_ids,
	)

	WorshipSystem.reset_seasonal_wp(worship_state)

	return result


static func _is_benten_marriage_blocked(
	effects: Dictionary,
	characters_by_id: Dictionary,
	worship_maluses: Dictionary,
) -> bool:
	if worship_maluses.is_empty():
		return false
	for pid: Variant in worship_maluses:
		var malus: Dictionary = worship_maluses[pid]
		if malus.get("marriage_auto_fail", false):
			return true
	return false


static func _apply_worship_stability_maluses(
	worship_maluses: Dictionary,
	provinces: Dictionary,
) -> void:
	for pid: Variant in worship_maluses:
		var malus: Dictionary = worship_maluses[pid]
		var stability_delta: float = float(malus.get("stability_per_season", 0.0))
		if stability_delta >= 0.0:
			continue
		var prov: ProvinceData = provinces.get(pid) as ProvinceData
		if prov == null:
			continue
		prov.stability = clampf(prov.stability + stability_delta, 0.0, 100.0)


static func _inject_worship_battle_maluses(
	battle_states: Array[Dictionary],
	worship_maluses: Dictionary,
) -> void:
	for bc: Dictionary in battle_states:
		var company: Variant = bc.get("company")
		if company == null:
			continue
		var source_pid: int = company.source_province_id if company is MilitaryUnitData.CompanyData else bc.get("source_province_id", -1)
		var malus: Dictionary = worship_maluses.get(source_pid, {})
		if malus.is_empty():
			continue
		bc["worship_attack_penalty"] = int(malus.get("army_attack", 0))
		bc["worship_morale_penalty"] = int(malus.get("army_morale", 0))
		var risk_bonus: int = 0
		if malus.get("commander_risk_reduced", false):
			risk_bonus += 5
		if malus.get("rank4_commander_risk_checks", false):
			var cmdr: Variant = bc.get("commander")
			if cmdr is L5RCharacterData:
				var rank: int = CharacterStats.get_insight_rank(cmdr as L5RCharacterData)
				if rank >= 4:
					risk_bonus += 3
		if risk_bonus > 0:
			bc["worship_commander_risk_bonus"] = risk_bonus


# -- Construction Processing ---------------------------------------------------


static func _process_construction_effects(
	day_results: Array,
	characters_by_id: Dictionary,
	provinces: Dictionary,
	settlements: Array[SettlementData],
	constructions: Array[ConstructionData],
	next_settlement_id: Array[int],
	next_construction_id: Array[int],
	ic_day: int,
	ships: Array[ShipData],
	dice_engine: DiceEngine,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for r: Dictionary in day_results:
		var effects: Dictionary = r.get("effects", {})
		if not effects.get("requires_construction", false):
			continue

		var char_id: int = r.get("character_id", -1)
		var character: Variant = characters_by_id.get(char_id)
		if character == null:
			continue

		var action_id: String = effects.get("construction_action", "")
		var province_id: int = int(effects.get("province_id", -1))
		var settlement_id: int = int(effects.get("settlement_id", -1))
		var is_dedicated: bool = effects.get("is_dedicated", false)
		var dedicated_fortune: int = int(effects.get("dedicated_fortune", -1))
		var ship_class_val: int = int(effects.get("ship_class", -1))
		var shrine_tier: String = effects.get("shrine_tier", "roadside")

		var result: Dictionary = _apply_construction_order(
			action_id, character as L5RCharacterData, province_id, settlement_id,
			is_dedicated, dedicated_fortune, ship_class_val, shrine_tier,
			provinces, settlements, constructions,
			next_settlement_id, next_construction_id, ic_day,
			ships, dice_engine,
		)
		result["character_id"] = char_id
		result["action_id"] = action_id
		results.append(result)

	return results


static func _apply_construction_order(
	action_id: String,
	character: L5RCharacterData,
	province_id: int,
	settlement_id: int,
	is_dedicated: bool,
	dedicated_fortune: int,
	ship_class_val: int,
	shrine_tier: String,
	provinces: Dictionary,
	settlements: Array[SettlementData],
	constructions: Array[ConstructionData],
	next_settlement_id: Array[int],
	next_construction_id: Array[int],
	ic_day: int,
	ships: Array[ShipData],
	_dice_engine: DiceEngine,
) -> Dictionary:
	var province: Variant = provinces.get(province_id)

	match action_id:
		"FOUND_VILLAGE":
			if province == null:
				return {"applied": false, "reason": "province_not_found"}
			var valid: Dictionary = ConstructionSystem.validate_village_founding(
				character, province as ProvinceData, settlements,
			)
			if not valid.get("valid", false):
				return {"applied": false, "reason": valid.get("reason", "invalid")}

			var deduction: Dictionary = ConstructionSystem.deduct_village_resources(
				settlements, province_id,
				ConstructionSystem.VILLAGE_MIN_PU,
				ConstructionSystem.VILLAGE_KOKU_COST,
			)
			var village: SettlementData = ConstructionSystem.create_founded_village(
				next_settlement_id[0],
				province as ProvinceData,
				(province as ProvinceData).province_name + " Village",
				deduction["pu_moved"],
				deduction["rice_moved"],
			)
			next_settlement_id[0] += 1
			settlements.append(village)
			return {"applied": true, "type": "village", "settlement_id": village.settlement_id}

		"BUILD_FORTIFICATION":
			if province == null:
				return {"applied": false, "reason": "province_not_found"}
			var valid: Dictionary = ConstructionSystem.validate_fortification(
				character, province as ProvinceData, settlements,
			)
			if not valid.get("valid", false):
				return {"applied": false, "reason": valid.get("reason", "invalid")}

			ConstructionSystem.deduct_koku(
				settlements, province_id, ConstructionSystem.FORTIFICATION_KOKU_COST,
			)
			var fort: SettlementData = ConstructionSystem.create_fortification(
				next_settlement_id[0],
				province as ProvinceData,
				(province as ProvinceData).province_name + " Fortification",
			)
			next_settlement_id[0] += 1
			settlements.append(fort)
			return {"applied": true, "type": "fortification", "settlement_id": fort.settlement_id}

		"BUILD_SHRINE":
			var target_settlement: Variant = _find_settlement_by_id(settlements, settlement_id)
			if target_settlement == null:
				return {"applied": false, "reason": "settlement_not_found"}

			var shrine_type: ConstructionData.ConstructionType = _shrine_tier_to_type(shrine_tier)
			var valid: Dictionary = ConstructionSystem.validate_shrine(
				shrine_type, character, target_settlement as SettlementData, is_dedicated,
			)
			if not valid.get("valid", false):
				return {"applied": false, "reason": valid.get("reason", "invalid")}

			var cost_entry: Dictionary = ConstructionSystem.SHRINE_COSTS.get(shrine_type, {})
			var cost: float = cost_entry.get("dedicated", 0.0) if is_dedicated else cost_entry.get("general", 0.0)
			var build_seasons: int = int(cost_entry.get("seasons", 1))

			(target_settlement as SettlementData).koku_stockpile -= cost

			if build_seasons <= 1:
				var shrine_name: String = ConstructionSystem.SHRINE_TYPE_NAMES.get(shrine_type, "roadside_shrine")
				ConstructionSystem.add_shrine_to_settlement(
					target_settlement as SettlementData, shrine_name, is_dedicated, dedicated_fortune,
				)
				return {"applied": true, "type": "shrine", "immediate": true}
			else:
				var cd: ConstructionData = ConstructionSystem.create_construction(
					next_construction_id[0], shrine_type, character.character_id,
					(target_settlement as SettlementData).province_id, ic_day,
					cost, 0.0, 0.0, settlement_id, is_dedicated, dedicated_fortune,
				)
				next_construction_id[0] += 1
				constructions.append(cd)
				return {"applied": true, "type": "shrine", "queued": true, "construction_id": cd.construction_id}

		"FOUND_TEMPLE":
			if province == null:
				return {"applied": false, "reason": "province_not_found"}
			var valid: Dictionary = ConstructionSystem.validate_temple(
				ConstructionData.ConstructionType.TEMPLE, character,
				province as ProvinceData, settlements, is_dedicated,
			)
			if not valid.get("valid", false):
				return {"applied": false, "reason": valid.get("reason", "invalid")}

			var koku_cost: float = ConstructionSystem.TEMPLE_DEDICATED_KOKU_COST if is_dedicated else ConstructionSystem.TEMPLE_KOKU_COST
			ConstructionSystem.deduct_koku(settlements, province_id, koku_cost)
			ConstructionSystem.deduct_pu(settlements, province_id, ConstructionSystem.TEMPLE_MIN_PU)

			var cd: ConstructionData = ConstructionSystem.create_construction(
				next_construction_id[0],
				ConstructionData.ConstructionType.TEMPLE,
				character.character_id, province_id, ic_day,
				koku_cost, ConstructionSystem.TEMPLE_MIN_PU, 0.0,
				-1, is_dedicated, dedicated_fortune,
			)
			next_construction_id[0] += 1
			constructions.append(cd)
			return {"applied": true, "type": "temple", "queued": true, "construction_id": cd.construction_id}

		"FOUND_MONASTERY":
			if province == null:
				return {"applied": false, "reason": "province_not_found"}
			var valid: Dictionary = ConstructionSystem.validate_temple(
				ConstructionData.ConstructionType.MONASTERY, character,
				province as ProvinceData, settlements, is_dedicated,
			)
			if not valid.get("valid", false):
				return {"applied": false, "reason": valid.get("reason", "invalid")}

			ConstructionSystem.deduct_koku(settlements, province_id, ConstructionSystem.MONASTERY_KOKU_COST)
			ConstructionSystem.deduct_pu(settlements, province_id, ConstructionSystem.MONASTERY_MIN_PU)

			var cd: ConstructionData = ConstructionSystem.create_construction(
				next_construction_id[0],
				ConstructionData.ConstructionType.MONASTERY,
				character.character_id, province_id, ic_day,
				ConstructionSystem.MONASTERY_KOKU_COST, ConstructionSystem.MONASTERY_MIN_PU,
				0.0, -1, false, -1,
			)
			next_construction_id[0] += 1
			constructions.append(cd)
			return {"applied": true, "type": "monastery", "queued": true, "construction_id": cd.construction_id}

		"COMMISSION_SHIP":
			var target_settlement: Variant = _find_settlement_by_id(settlements, settlement_id)
			if target_settlement == null:
				return {"applied": false, "reason": "settlement_not_found"}

			var sc: Enums.ShipClass = ship_class_val as Enums.ShipClass
			var valid: Dictionary = ConstructionSystem.validate_ship_commission(
				character, sc, target_settlement as SettlementData,
			)
			if not valid.get("valid", false):
				return {"applied": false, "reason": valid.get("reason", "invalid")}

			var cost: float = ConstructionSystem.SHIP_COSTS.get(sc, 3.0)
			(target_settlement as SettlementData).koku_stockpile -= cost

			var cd: ConstructionData = ConstructionSystem.create_construction(
				next_construction_id[0],
				ConstructionData.ConstructionType.SHIP,
				character.character_id,
				(target_settlement as SettlementData).province_id, ic_day,
				cost, 0.0, 0.0, settlement_id, false, -1, ship_class_val,
			)
			next_construction_id[0] += 1
			constructions.append(cd)
			return {"applied": true, "type": "ship", "queued": true, "construction_id": cd.construction_id}

	return {"applied": false, "reason": "unknown_action"}


static func _process_construction_completions(
	constructions: Array[ConstructionData],
	settlements: Array[SettlementData],
	provinces: Dictionary,
	ships: Array[ShipData],
	_dice_engine: DiceEngine,
	next_settlement_id: Array[int],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	var completed: Array[ConstructionData] = ConstructionSystem.tick_construction_queue(constructions)

	for cd: ConstructionData in completed:
		match cd.construction_type:
			ConstructionData.ConstructionType.SHRINE_ROADSIDE, \
			ConstructionData.ConstructionType.SHRINE_VILLAGE, \
			ConstructionData.ConstructionType.SHRINE_LOCAL:
				var target: Variant = _find_settlement_by_id(settlements, cd.settlement_id)
				if target != null:
					var shrine_name: String = ConstructionSystem.SHRINE_TYPE_NAMES.get(
						cd.construction_type, "roadside_shrine",
					)
					ConstructionSystem.add_shrine_to_settlement(
						target as SettlementData, shrine_name,
						cd.is_dedicated, cd.dedicated_fortune,
					)

			ConstructionData.ConstructionType.TEMPLE:
				var prov: Variant = provinces.get(cd.province_id)
				if prov != null:
					var temple: SettlementData = ConstructionSystem.create_temple(
						next_settlement_id[0], prov as ProvinceData,
						(prov as ProvinceData).province_name + " Temple",
						cd.pu_committed, cd.is_dedicated, cd.dedicated_fortune,
					)
					next_settlement_id[0] += 1
					settlements.append(temple)

			ConstructionData.ConstructionType.SHINDEN:
				var prov: Variant = provinces.get(cd.province_id)
				if prov != null:
					var shinden: SettlementData = ConstructionSystem.create_shinden(
						next_settlement_id[0], prov as ProvinceData,
						(prov as ProvinceData).province_name + " Shinden",
						cd.pu_committed, cd.is_dedicated, cd.dedicated_fortune,
					)
					next_settlement_id[0] += 1
					settlements.append(shinden)

			ConstructionData.ConstructionType.MONASTERY:
				var prov: Variant = provinces.get(cd.province_id)
				if prov != null:
					var monastery: SettlementData = ConstructionSystem.create_monastery(
						next_settlement_id[0], prov as ProvinceData,
						(prov as ProvinceData).province_name + " Monastery",
						cd.pu_committed,
					)
					next_settlement_id[0] += 1
					settlements.append(monastery)

			ConstructionData.ConstructionType.SHIP:
				var ship := ShipData.new()
				ship.ship_id = next_settlement_id[0]
				next_settlement_id[0] += 1
				ship.ship_class = cd.ship_class
				ship.current_province_id = cd.province_id
				ship.ic_day_launched = ic_day
				var stats: Dictionary = NavalSystem.SHIP_STATS.get(ship.ship_class, {})
				ship.max_health = int(stats.get("health", 100))
				ship.health = ship.max_health
				ship.attack = int(stats.get("attack", 3))
				ship.defense = int(stats.get("defense", 3))
				ship.morale = int(stats.get("morale", 12))
				ship.morale_defense = int(stats.get("morale_defense", 4))
				ship.cargo_capacity = float(stats.get("cargo", 0.3))
				ship.construction_cost = float(stats.get("construction_cost", 3.0))
				ships.append(ship)

		_generate_construction_topic(
			cd, active_topics, next_topic_id, ic_day,
		)

	# Remove completed constructions
	var i: int = constructions.size() - 1
	while i >= 0:
		if constructions[i].is_complete:
			constructions.remove_at(i)
		i -= 1


static func _process_organic_villages(
	provinces: Dictionary,
	settlements: Array[SettlementData],
	next_settlement_id: Array[int],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid]
		var result: Dictionary = ConstructionSystem.process_organic_formation(
			prov, settlements, next_settlement_id[0],
		)
		if result.get("formed", false):
			var village: SettlementData = result["settlement"]
			next_settlement_id[0] += 1
			settlements.append(village)

			var topic := TopicData.new()
			topic.topic_id = next_topic_id[0]
			next_topic_id[0] += 1
			topic.slug = "organic_village_%d" % village.settlement_id
			topic.topic_type = "settlement"
			topic.variant = "organic_formation"
			topic.ic_day_created = ic_day
			topic.tier = TopicData.Tier.TIER_4
			topic.momentum = 11.0
			active_topics.append(topic)


static func _generate_construction_topic(
	cd: ConstructionData,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	var topic := TopicData.new()
	topic.topic_id = next_topic_id[0]
	next_topic_id[0] += 1
	topic.ic_day_created = ic_day
	topic.tier = TopicData.Tier.TIER_4
	topic.momentum = 11.0
	topic.topic_type = "construction"

	match cd.construction_type:
		ConstructionData.ConstructionType.TEMPLE:
			topic.slug = "temple_completed_%d" % cd.construction_id
			topic.variant = "temple_completed"
			topic.tier = TopicData.Tier.TIER_3
			topic.momentum = 25.0
		ConstructionData.ConstructionType.SHINDEN:
			topic.slug = "shinden_completed_%d" % cd.construction_id
			topic.variant = "shinden_completed"
			topic.tier = TopicData.Tier.TIER_2
			topic.momentum = 40.0
		ConstructionData.ConstructionType.MONASTERY:
			topic.slug = "monastery_completed_%d" % cd.construction_id
			topic.variant = "monastery_completed"
			topic.tier = TopicData.Tier.TIER_3
			topic.momentum = 25.0
		ConstructionData.ConstructionType.SHIP:
			topic.slug = "ship_launched_%d" % cd.construction_id
			topic.variant = "ship_launched"
		_:
			topic.slug = "construction_%d" % cd.construction_id
			topic.variant = "shrine_completed"

	active_topics.append(topic)


static func _find_settlement_by_id(
	settlements: Array[SettlementData],
	settlement_id: int,
) -> Variant:
	for s: SettlementData in settlements:
		if s.settlement_id == settlement_id:
			return s
	return null


static func _shrine_tier_to_type(tier: String) -> ConstructionData.ConstructionType:
	match tier:
		"village":
			return ConstructionData.ConstructionType.SHRINE_VILLAGE
		"local":
			return ConstructionData.ConstructionType.SHRINE_LOCAL
		_:
			return ConstructionData.ConstructionType.SHRINE_ROADSIDE


# -- Infrastructure Intelligence Population ------------------------------------


static func _populate_infrastructure_intelligence(
	world_states: Dictionary,
	provinces: Dictionary,
	settlements: Array[SettlementData],
	ships: Array[ShipData],
	worship_state: Dictionary,
) -> void:
	var worship_failing: Array[int] = []
	var border_no_fort: Array[int] = []
	var surplus_pu: Array[int] = []
	var coastal: bool = false
	var has_ships_flag: bool = false
	var naval_threat: bool = false

	var province_settlements: Dictionary = {}
	for s: SettlementData in settlements:
		if not province_settlements.has(s.province_id):
			province_settlements[s.province_id] = []
		province_settlements[s.province_id].append(s)

	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid]
		var p_settlements: Array = province_settlements.get(pid, [])

		# Worship failure: check worship_state for any province with RESTLESS+ tier
		var wp_data: Dictionary = worship_state.get("province_wp", {})
		var prov_wp: Dictionary = wp_data.get(pid, {})
		if not prov_wp.is_empty():
			var any_failing: bool = false
			for fortune_key: Variant in prov_wp:
				var wp_val: float = float(prov_wp[fortune_key])
				if wp_val < 10.0:
					any_failing = true
					break
			if any_failing:
				worship_failing.append(int(pid))

		# Border province without fortification
		if prov.adjacent_province_ids.size() > 0:
			var is_border: bool = false
			for adj_id: int in prov.adjacent_province_ids:
				var adj_prov: Variant = provinces.get(adj_id)
				if adj_prov != null and (adj_prov as ProvinceData).clan != prov.clan:
					is_border = true
					break
			if is_border:
				var has_fort: bool = false
				for s: Variant in p_settlements:
					if (s as SettlementData).settlement_type == Enums.SettlementType.FORTIFICATION:
						has_fort = true
						break
				if not has_fort:
					border_no_fort.append(int(pid))

		# Surplus PU check
		var total_pu: float = 0.0
		for s: Variant in p_settlements:
			total_pu += (s as SettlementData).population_pu
		var threshold: float = ConstructionSystem.ORGANIC_SURPLUS_PU_THRESHOLD.get(
			prov.terrain_type, 10.0,
		)
		if total_pu > threshold:
			surplus_pu.append(int(pid))

	# Coastal / naval detection
	for s: ShipData in ships:
		if not s.is_destroyed:
			has_ships_flag = true
			break

	# Simple heuristic: if any active war involves a clan with ships, naval threat
	for w: Variant in world_states.get("active_wars", []):
		if w is WarData:
			naval_threat = true
			break

	world_states["worship_failing_province_ids"] = worship_failing
	world_states["border_province_ids_without_fort"] = border_no_fort
	world_states["surplus_pu_province_ids"] = surplus_pu
	world_states["is_coastal"] = coastal
	world_states["has_ships"] = has_ships_flag
	world_states["has_naval_threat"] = naval_threat


# -- Vacancy Intelligence Population (s57.20.3) --------------------------------


const CRITICAL_POSITIONS: Array[String] = [
	"Clan Magistrate", "Emerald Magistrate", "Garrison Commander",
]

const IMPORTANT_POSITIONS: Array[String] = [
	"School Master", "Temple Head", "Monastery Abbot", "Senior Courtier",
]


static func _populate_vacancy_intelligence(
	world_states: Dictionary,
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	companies: Array,
) -> void:
	var lord_vacancies: Dictionary = {}

	# Military vacancies: units with no commander
	for company_data: Variant in companies:
		if company_data is Dictionary:
			var commander_id: int = company_data.get("commander_id", -1)
			if commander_id < 0:
				var parent_legion_id: int = company_data.get("parent_legion_id", -1)
				if parent_legion_id < 0:
					continue
				# Find the lord responsible for this unit
				var lord_id: int = company_data.get("owning_lord_id", -1)
				if lord_id < 0:
					continue
				if not lord_vacancies.has(lord_id):
					lord_vacancies[lord_id] = []
				lord_vacancies[lord_id].append({
					"position_type": "military_commander",
					"priority": 3,
					"unit_id": company_data.get("company_id", -1),
					"province_id": company_data.get("source_province_id", -1),
					"candidate_id": -1,
					"seasons_vacant": company_data.get("seasons_without_commander", 0),
				})

	# Position vacancies: scan for lord-controlled positions that should be filled
	var filled_positions: Dictionary = {}
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if c.role_position.is_empty():
			continue
		var lord_id: int = c.lord_id
		if lord_id < 0:
			continue
		if not filled_positions.has(lord_id):
			filled_positions[lord_id] = []
		filled_positions[lord_id].append(c.role_position)

	# Check each lord for expected positions
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if c.status < 3.0 or (c.lord_id >= 0 and c.status < 5.0):
			continue
		var lord_id: int = c.character_id
		var lord_positions: Array = filled_positions.get(lord_id, [])

		# Every lord should have a magistrate
		if not _has_position(lord_positions, "Magistrate"):
			var candidate: int = _find_vacancy_candidate(
				lord_id, "Magistrate", characters, characters_by_id,
			)
			if not lord_vacancies.has(lord_id):
				lord_vacancies[lord_id] = []
			lord_vacancies[lord_id].append({
				"position_type": "Clan Magistrate",
				"priority": 3,
				"province_id": -1,
				"candidate_id": candidate,
				"seasons_vacant": 0,
			})

	# Store per-lord vacancy data keyed by lord_id
	world_states["vacancy_data"] = lord_vacancies

	# Also store flat vacancy list for each lord in their world_states context
	for lord_id: int in lord_vacancies:
		var key: String = "vacant_positions_%d" % lord_id
		world_states[key] = lord_vacancies[lord_id]


static func _has_position(positions: Array, substring: String) -> bool:
	for p: Variant in positions:
		if p is String and (p as String).contains(substring):
			return true
	return false


static func _find_vacancy_candidate(
	lord_id: int,
	_position_type: String,
	characters: Array[L5RCharacterData],
	_characters_by_id: Dictionary,
) -> int:
	var best_id: int = -1
	var best_score: float = -999.0
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if c.lord_id != lord_id:
			continue
		if c.character_id == lord_id:
			continue
		if not c.role_position.is_empty():
			continue
		var score: float = c.status + c.honor + c.glory
		var disp: int = c.disposition_values.get(lord_id, 0)
		score += float(disp) * 0.1
		if score > best_score:
			best_score = score
			best_id = c.character_id
	return best_id
