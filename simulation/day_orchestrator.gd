class_name DayOrchestrator
## Single entry point to advance world state by one IC day.
## Sequence: AP reset → wave resolution → effect application →
## info events → letter delivery → topic tick →
## (season boundary) resource tick + confidence decay.

const _COMBAT_EVENT_MOMENTUM: float = 30.0
const _CIVIL_WAR_MOMENTUM: float = 60.0
const _CONSTRUCTION_TIER2_MOMENTUM: float = 40.0


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
	court_commitments: Array[CourtCommitmentData] = [],
	togashi_state: Dictionary = {},
	phoenix_council_state: Dictionary = {},
	active_civil_wars: Array[Dictionary] = [],
	precedent_modifiers: Dictionary = {},
	next_company_id: Array[int] = [1],
	active_secrets: Array[SecretData] = [],
	next_secret_id: Array[int] = [1],
	active_hostages: Array[Dictionary] = [],
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
	_populate_vacancy_intelligence(world_states, characters, characters_by_id, companies, settlements, provinces, season_meta)
	_populate_resource_stockpiles(world_states, characters, provinces, settlements, clans, companies)
	_populate_crime_suppression_data(world_states, settlements, provinces, current_season)
	_assign_magistrate_standing_objectives(characters, objectives_map)

	var festival_results: Dictionary = _process_festivals(ic_day, world_states)

	var travel_arrivals: Array[Dictionary] = _process_travel(characters)
	_process_arrival_observation(travel_arrivals, characters_by_id, current_season)
	_process_witness_testimony_on_arrival(
		travel_arrivals, characters_by_id, world_states, active_topics, current_season,
	)

	var musha_season_count: int = int(season_meta.get("horde_season_count", 0))
	var musha_shugyo_results: Array[Dictionary] = _process_musha_shugyo(characters, characters_by_id, ic_day, objectives_map, dice_engine, musha_season_count)

	_apply_cohabitation(characters, characters_by_id)

	var favor_results: Dictionary = _process_favors(favors, ic_day, characters_by_id)

	var entanglement_results: Array[Dictionary] = _process_entanglements(entanglements, ic_day)
	var bound_escape_results: Array[Dictionary] = _process_bound_states(
		bound_states, characters_by_id, dice_engine, ic_day
	)
	var hostage_escape_results: Array[Dictionary] = _process_hostage_escapes(
		active_hostages, characters_by_id, settlements, dice_engine, ic_day, death_events,
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
		court_commitments, characters,
	)
	_set_court_context_flags(active_courts, world_states)
	_set_wall_tower_context_flags(characters, settlements, provinces, world_states)
	_populate_court_availability_data(
		active_courts, characters, characters_by_id, world_states, favors,
	)

	var edict_results: Array[Dictionary] = _process_edict_compliance(
		active_edicts, active_wars, characters, active_topics, next_topic_id, ic_day, season_meta,
	)

	_inject_edict_reactive_events(active_edicts, characters, world_states, ic_day)
	_inject_commitment_needs(court_commitments, characters, world_states)

	var wm_for_military: Dictionary = world_states.get("_worship_maluses", {})
	var military_daily: Dictionary = _process_military_daily(
		active_armies, active_sieges, active_tethers, order_states,
		dice_engine, settlements, companies, wm_for_military,
		active_wars, characters_by_id, provinces, active_hostages, ic_day,
	)

	var dragon_schism_siege_event: Dictionary = {}
	if (
		not togashi_state.is_empty()
		and not togashi_state.get("togashi_vanished", false)
		and _has_active_dragon_schism(active_civil_wars)
	):
		dragon_schism_siege_event = _check_dragon_schism_siege_events(
			military_daily, togashi_state, characters, characters_by_id,
			settlements, active_topics, next_topic_id, ic_day,
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

	_inject_urgency_data(
		world_states, characters, favors, active_tethers, active_sieges,
		objectives_map, active_topics,
	)

	world_states["_crime_records"] = crime_records

	var day_result: Dictionary = NPCWaveResolver.resolve_day_applied(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		dice_engine, action_skill_map, characters_by_id, provinces, action_log,
		approach_penalties, commitments, military_data, settlements
	)

	var next_letter_id: Array[int] = [pending_letters.size() + 1]
	var letter_pass_results: Array[Dictionary] = _process_daily_letter_pass(
		characters, characters_by_id, objectives_map, scoring_tables, world_states,
		pending_letters, ic_day, dice_engine, next_letter_id,
	)

	_apply_garrison_shortage_letter_writebacks(
		letter_pass_results, characters_by_id, settlements, current_season
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
		active_wars,
		action_log,
		dice_engine,
	)

	_process_scene_examination_writebacks(
		day_result.get("results", []), objectives_map, world_states,
		characters_by_id, active_topics, next_topic_id, ic_day,
	)

	_update_patrol_tracking(
		day_result.get("results", []), objectives_map, ic_day,
	)

	_process_successful_bribe_writebacks(
		day_result.get("results", []),
		crime_records, characters_by_id, ic_day,
		active_secrets, next_secret_id,
		next_case_id, objectives_map,
	)

	_process_flee_jurisdiction_writebacks(
		day_result.get("results", []),
		crime_records, characters_by_id,
		active_topics, next_topic_id, ic_day,
	)

	_process_extortion_writebacks(
		day_result.get("results", []),
		crime_records, characters_by_id, ic_day,
		active_secrets, next_secret_id,
	)

	_process_ptl_detection(
		day_result.get("results", []),
		characters_by_id, provinces, character_province_map,
		dice_engine, active_topics, next_topic_id, ic_day,
	)

	_process_blood_evidence_discovery(
		day_result.get("results", []),
		crime_records, characters_by_id,
		active_topics, next_topic_id, ic_day, dice_engine,
	)

	_process_flee_logistics(
		day_result.get("results", []),
		characters_by_id, active_courts, world_states,
	)

	_purge_expired_crime_evidence(crime_records, ic_day)
	var cold_case_results: Array[Dictionary] = _apply_evidence_decay(
		crime_records, objectives_map, ic_day,
	)

	_process_witness_tampering_writebacks(
		day_result.get("results", []),
		crime_records, characters_by_id,
		active_topics, next_topic_id, ic_day, world_states,
		active_secrets, next_secret_id, next_case_id, dice_engine,
	)

	_process_witness_report_letter_writebacks(
		day_result.get("results", []),
		characters_by_id, active_topics, pending_letters,
		ic_day, dice_engine, next_letter_id,
	)

	_process_taint_proximity_detection(
		day_result.get("results", []),
		characters_by_id, character_province_map, dice_engine,
		active_topics, next_topic_id, ic_day,
	)

	_capture_witness_travel_intent(
		day_result.get("results", []), world_states,
	)

	var current_season_count: int = int(season_meta.get("horde_season_count", 0))
	var military_effects: Array[Dictionary] = _process_military_effects(
		day_result.get("results", []),
		settlements,
		characters_by_id,
		companies,
		provinces,
		next_company_id,
		clans,
		current_season_count,
	)

	_apply_garrison_courtier_refusal_writebacks(
		day_result.get("results", []), settlements
	)

	var wall_engineering_results: Array[Dictionary] = _process_wall_engineering_effects(
		day_result.get("results", []),
		settlements,
	)

	var sortie_results: Array[Dictionary] = _process_sortie_results(
		day_result.get("results", []),
		settlements,
		provinces,
		dice_engine,
	)

	var storm_assault_results: Array[Dictionary] = _process_storm_assault_results(
		day_result.get("results", []),
		active_sieges,
		companies,
		dice_engine,
		settlements,
		characters_by_id,
		active_hostages,
		ic_day,
	)
	_capture_siege_hostages(active_sieges, characters_by_id, companies, active_hostages, ic_day)

	var purification_results: Array[Dictionary] = _process_purification_effects(
		day_result.get("results", []),
		provinces,
		season_meta,
	)

	var patrol_results: Array[Dictionary] = _process_patrol_effects(
		day_result.get("results", []),
		season_meta,
	)

	_process_siege_maintenance(
		day_result.get("results", []),
		active_sieges,
		ic_day,
	)

	var drill_results: Array[Dictionary] = _process_drill_effects(
		day_result.get("results", []),
		companies,
		characters_by_id,
		dice_engine,
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

	var letter_examination_results: Array[Dictionary] = _process_letter_examinations(
		day_result.get("results", []),
		pending_letters,
		characters_by_id,
		dice_engine,
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

	# Refresh vacancy intelligence after daily construction creates new settlements
	if not construction_results.is_empty():
		_populate_vacancy_intelligence(world_states, characters, characters_by_id, companies, settlements, provinces, season_meta)

	_process_edict_compliance_actions(
		day_result.get("results", []),
		active_edicts,
	)

	_process_voluntary_declarations(
		day_result.get("results", []),
		active_courts, active_topics, court_commitments,
		characters_by_id, ic_day, time_system,
	)

	_process_court_action_effects(
		day_result.get("results", []),
		characters_by_id,
		favors,
		ic_day,
		int(world_states.get("emperor_id", -1)),
		int(world_states.get("emperor_archetype", StrategicReview.EmperorArchetype.IRON)),
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

	_release_war_hostages(war_termination_results, active_hostages, characters_by_id, ic_day)

	var peace_route_results: Array[Dictionary] = _process_peace_trade_routes(
		war_termination_results, trade_routes,
	)
	trade_route_results.append_array(peace_route_results)
	if not peace_route_results.is_empty():
		LetterSystem.unblock_letters(pending_letters)

	var territory_transfer_results: Array[Dictionary] = _apply_war_territory_transfers(
		war_termination_results, provinces,
	)

	var military_topics: Array[TopicData] = _generate_military_event_topics(
		military_daily, military_effects, active_topics, next_topic_id, ic_day,
	)

	var compact_restoration_results: Array[Dictionary] = _process_compact_restorations(
		day_result.get("results", []),
		phoenix_council_state,
	)

	var commitment_results: Array[Dictionary] = _process_commitment_deadlines(
		commitments, ic_day, characters_by_id
	)

	var orphan_results: Array[Dictionary] = _process_lord_deaths(
		death_events, characters, objectives_map, successor_map,
		active_successions, next_succession_id, characters_by_id, ic_day,
		active_topics, next_topic_id,
	)

	var hierarchy_cascade_results: Array[int] = _process_operational_death_cascade(
		death_events, characters,
	)

	var succession_results: Array[Dictionary] = _process_successions(
		active_successions, characters_by_id
	)

	var conversation_results: Array[Dictionary] = _process_daily_conversations(
		characters, dice_engine, current_season, active_topics
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
	_generate_investigation_opened_topics(
		uphold_law_results, crime_records, characters_by_id,
		active_topics, next_topic_id, ic_day,
	)

	var lord_map: Dictionary = _build_lord_map(characters)
	var conviction_results: Array[Dictionary] = ConvictionProcessor.process_accused_cases(
		crime_records, characters_by_id, dice_engine, ic_day,
		next_topic_id, active_topics, lord_map,
	)

	var trial_results: Array[Dictionary] = _resolve_pending_trials(
		conviction_results, crime_records, characters_by_id,
		lord_map, dice_engine, ic_day,
	)

	var seppuku_results: Array[Dictionary] = _process_seppuku_responses(
		conviction_results, crime_records, characters_by_id,
		ic_day, next_topic_id, active_topics, world_states,
	)

	var seppuku_action_results: Array[Dictionary] = _process_seppuku_action_writebacks(
		day_result.get("results", []),
		crime_records, characters_by_id,
		ic_day, next_topic_id, active_topics,
	)

	_apply_cross_clan_conviction_consequences(
		conviction_results, crime_records, characters_by_id,
	)

	_seed_conviction_topics_to_victim_lords(
		conviction_results, crime_records, characters_by_id, active_topics,
	)

	_release_magistrate_after_conviction(
		conviction_results, crime_records, objectives_map,
	)

	_process_magistrate_conviction_cascade(
		conviction_results, crime_records, characters_by_id, objectives_map,
	)

	var info_results: Array[Dictionary] = _process_info_events(
		day_result.get("applied", []),
		characters_by_id,
		action_log,
		current_season,
		crime_records,
		objectives_map,
		world_states,
		active_topics,
		next_topic_id,
		ic_day,
		dice_engine,
	)

	var letter_results: Array[Dictionary] = LetterSystem.process_pending_letters(
		pending_letters, characters_by_id, ic_day, current_season, action_log,
		active_wars if active_wars != null else [], dice_engine,
	)
	_compute_positions_from_letters(letter_results, active_topics, characters_by_id)

	var reply_letters: Array[LetterData] = []
	if dice_engine != null:
		var reply_next_id: Array[int] = [next_letter_id[0]]
		reply_letters = LetterSystem.generate_replies(
			letter_results, pending_letters, characters_by_id,
			ic_day, dice_engine, reply_next_id,
		)
		for reply: LetterData in reply_letters:
			pending_letters.append(reply)
		next_letter_id[0] = reply_next_id[0]

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
	var commitment_seasonal_result: Dictionary = {}
	var worship_seasonal_results: Dictionary = {}
	var civil_war_results_seasonal: Dictionary = {}
	var extradition_results: Array[Dictionary] = []
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
		var emperor_tax_cfg: Dictionary = _build_emperor_tax_config(
			world_states, characters_by_id,
		)
		_populate_tax_modifiers(characters, characters_by_id, provinces, season_meta)
		seasonal_result = _process_season_transition(
			characters, provinces, current_season, season_meta,
			approach_penalties, settlements, spring_inputs, worship_maluses,
			emperor_tax_cfg, trade_routes,
		)
		_apply_worship_stability_maluses(worship_maluses, provinces)
		_apply_tyrant_stability_penalty(
			world_states.get("emperor_archetype", StrategicReview.EmperorArchetype.IRON),
			provinces,
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
		military_seasonal_result["levy_suspicion"] = _process_levy_suspicion(
			companies, active_wars, characters_by_id,
			active_topics, next_topic_id, ic_day,
			int(season_meta.get("horde_season_count", 0)),
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
		var season_count_for_cw: int = int(season_meta.get("horde_season_count", 0))
		civil_war_results_seasonal = _process_civil_war_seasonal(
			active_civil_wars, precedent_modifiers, characters_by_id,
			provinces, season_count_for_cw, objectives_map,
			active_topics, next_topic_id, ic_day, season_meta,
			companies, active_edicts, togashi_state,
		)
		# Apply post-resolution governance flags from clan-specific schism victories.
		# Dragon FC rebel victory → dragon_autonomous_rule suspends Oversight (s55.10.2.8).
		# Phoenix Champion rebel victory → phoenix_champion_authority suspends Council gate (s55.10.3.7).
		for _cwr: Dictionary in civil_war_results_seasonal.get("resolutions", []):
			var vflags: Dictionary = _cwr.get("victory_flags", {})
			if vflags.get("dragon_autonomous_rule", false) and not togashi_state.is_empty():
				togashi_state["dragon_autonomous_rule"] = true
			if vflags.get("phoenix_champion_authority", false) and not phoenix_council_state.is_empty():
				PhoenixCouncil.grant_champion_authority(phoenix_council_state)
		insurgency_results = _process_insurgencies(
			insurgencies, provinces, dice_engine, current_season,
			next_insurgency_id, world_states, worship_maluses,
			season_meta,
		)
		_process_doshin_seasonal_recovery(world_states)
		_tick_kuni_wards(season_meta)
		season_meta.erase("patrolled_provinces")
		_process_construction_completions(
			constructions, settlements, provinces, ships, dice_engine,
			next_settlement_id, active_topics, next_topic_id, ic_day,
		)
		_process_organic_villages(
			provinces, settlements, next_settlement_id,
			active_topics, next_topic_id, ic_day,
		)
		# Refresh vacancy intelligence after construction completions and organic villages
		# so newly created settlements (temples, monasteries, forts) trigger vacancy detection
		_populate_vacancy_intelligence(world_states, characters, characters_by_id, companies, settlements, provinces, season_meta)
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
		var togashi_results: Dictionary = {}
		var cw_season_count: int = int(season_meta.get("horde_season_count", 0))
		if not togashi_state.is_empty():
			togashi_results = _process_togashi_oversight(
				togashi_state, strategic_results, characters,
				characters_by_id, world_states, active_topics,
				next_topic_id, ic_day, active_civil_wars,
				objectives_map, cw_season_count,
				settlements, provinces,
			)
		var phoenix_council_results: Dictionary = {}
		if not phoenix_council_state.is_empty():
			var emperor_id_for_phoenix: int = int(world_states.get("emperor_id", -1))
			phoenix_council_results = _process_phoenix_council_gating(
				phoenix_council_state, strategic_results, characters,
				characters_by_id, dice_engine, active_topics,
				next_topic_id, ic_day, active_civil_wars,
				objectives_map, cw_season_count,
				provinces, emperor_id_for_phoenix,
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
		_process_tyrant_directives(
			strategic_results, active_topics, next_topic_id, ic_day,
			characters_by_id,
		)
		if not seiyaku_state.is_empty():
			seiyaku_results = _process_seiyaku_review(
				seiyaku_state, characters, characters_by_id,
				emperor_archetype, active_wars, active_topics,
				next_topic_id, ic_day,
			)
		var season_count: int = int(season_meta.get("horde_season_count", 0))
		ronin_results = _process_seasonal_ronin(characters, season_count)
		commitment_seasonal_result = _process_commitment_seasonal(
			court_commitments, action_log, ic_day, characters_by_id,
			active_topics, next_topic_id,
		)
		_increment_vacancy_seasons(season_meta)
		_process_seasonal_stipend_disposition(characters, characters_by_id)
		extradition_results = _process_fugitive_extradition_seasonal(
			crime_records, characters, characters_by_id, provinces, settlements,
			active_topics, next_topic_id, ic_day,
		)
		pregnancy_results = _process_pregnancy_checks(
			marriages, characters_by_id, children, dice_engine, ic_day,
			next_character_id,
		)

	var koku_flow_results: Dictionary = {}
	var stipend_topic_results: Array[Dictionary] = []
	if time_system.get_ic_day_of_month() == 1:
		var season_name: String = time_system.get_season_name().to_lower()
		var months_in_season: int = ResourceTick.MONTHS_PER_SEASON.get(season_name, 3)
		koku_flow_results = KokuCascadeSystem.process_monthly_koku_flow(
			characters, characters_by_id, settlements, clans, months_in_season,
		)
		var stipends: Dictionary = koku_flow_results.get("stipends", {})
		stipend_topic_results = _create_stipend_failure_topics(
			stipends, characters_by_id, active_topics, next_topic_id, ic_day,
		)

	var horde_results: Dictionary = _process_horde_rolls(
		current_season, prev_season,
		active_hordes, horde_strength_counters, last_targeted_province_id,
		settlements, provinces, dice_engine, ic_day, season_meta,
		active_topics, next_topic_id,
	)

	# OOC Day Tick — fires every 4 IC days (one real-world day, per GDD s13 /
	# s57.44.2). Runs Wind-Down selection and Void Point refresh for all
	# living characters.
	var ooc_tick_results: Array[Dictionary] = []
	if ic_day % TimeSystem.TICKS_PER_REAL_DAY == 0:
		ooc_tick_results = _process_ooc_day_tick(
			characters, characters_by_id, settlements, dice_engine, worship_state, ic_day,
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
		"reply_letters": reply_letters,
		"seasonal_result": seasonal_result,
		"crime_results": crime_results,
		"commitment_results": commitment_results,
		"uphold_law_results": uphold_law_results,
		"cold_case_results": cold_case_results,
		"conviction_results": conviction_results,
		"trial_results": trial_results,
		"seppuku_results": seppuku_results,
		"seppuku_action_results": seppuku_action_results,
		"orphan_results": orphan_results,
		"hierarchy_cascade_results": hierarchy_cascade_results,
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
		"hostage_escape_results": hostage_escape_results,
		"military_daily": military_daily,
		"military_seasonal": military_seasonal_result,
		"military_effects": military_effects,
		"military_topics": military_topics,
		"war_score_results": war_score_results,
		"war_declarations": war_declarations,
		"compact_restoration_results": compact_restoration_results,
		"ladder_effects_results": ladder_effects_results,
		"war_termination_results": war_termination_results,
		"territory_transfer_results": territory_transfer_results,
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
		"storm_assault_results": storm_assault_results,
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
		"extradition_results": extradition_results,
		"pregnancy_results": pregnancy_results,
		"seiyaku_results": seiyaku_results,
		"worship_accumulation_results": worship_accumulation_results,
		"letter_examination_results": letter_examination_results,
		"worship_seasonal_results": worship_seasonal_results,
		"construction_results": construction_results,
		"commitment_seasonal_result": commitment_seasonal_result,
		"purification_results": purification_results,
		"patrol_results": patrol_results,
		"drill_results": drill_results,
		"togashi_results": togashi_results,
		"dragon_schism_siege_event": dragon_schism_siege_event,
		"phoenix_council_results": phoenix_council_results,
		"civil_war_results": civil_war_results_seasonal,
		"koku_flow_results": koku_flow_results,
		"stipend_topic_results": stipend_topic_results,
		"ooc_tick_results": ooc_tick_results,
	}


# -- AP Reset ------------------------------------------------------------------

static func _reset_all_ap(characters: Array[L5RCharacterData]) -> void:
	for c: L5RCharacterData in characters:
		ActionPointSystem.reset_daily_ap(c)
		c.civilian_orders_remaining = c.civilian_order_budget_max
		c.passage_request_count_today = 0
		c.pieces_seen.erase("_performance_count_today")


# -- OOC Day Tick --------------------------------------------------------------

static func _process_ooc_day_tick(
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	settlements: Array[SettlementData],
	dice_engine: DiceEngine,
	worship_state: Dictionary,
	ic_day: int = 0,
) -> Array[Dictionary]:
	## Runs Wind-Down selection and Void Point refresh once per OOC day (every
	## 4 IC days) per GDD s57.44.2 and s57.32.2.

	var results: Array[Dictionary] = []

	# Build fast settlement lookup and location → character IDs map.
	var settlements_by_id: Dictionary = {}
	for s: SettlementData in settlements:
		settlements_by_id[s.settlement_id] = s
	var empty_settlement: SettlementData = SettlementData.new()

	var loc_to_chars: Dictionary = {}
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		var loc: String = c.physical_location
		if not loc_to_chars.has(loc):
			loc_to_chars[loc] = []
		(loc_to_chars[loc] as Array).append(c.character_id)

	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue

		# Resolve settlement for this character.
		var settlement: SettlementData = empty_settlement
		if c.physical_location.is_valid_int():
			var sid: int = int(c.physical_location)
			if settlements_by_id.has(sid):
				settlement = settlements_by_id[sid] as SettlementData

		# Characters at the same location (excluding self).
		var loc_ids: Array = loc_to_chars.get(c.physical_location, [])
		var present_ids: Array[int] = []
		for pid: int in loc_ids:
			if pid != c.character_id:
				present_ids.append(pid)

		var companion_present: bool = not present_ids.is_empty()

		# NPC wind-down selection (auto). PC UI override is a future feature.
		var available: Array[WindDownSystem.Method] = \
			WindDownSystem.get_available_methods(c, settlement, companion_present)
		var method: WindDownSystem.Method = \
			WindDownSystem.select_npc_method(c, available, dice_engine)

		# Fortune for shrine/temple WP contribution — prefer dedicated fortune.
		var fortune_id: int = -1
		for wl: Dictionary in settlement.worship_locations:
			if wl.get("type", "") in ["shrine", "temple", "shinden", "local_shrine", "village_shrine"]:
				fortune_id = wl.get("fortune", -1)
				if fortune_id != -1:
					break

		# Go parlor opponent — pick a random present character.
		var go_opponent: Dictionary = {}
		if method == WindDownSystem.Method.GO_PARLOR and not present_ids.is_empty():
			var opp_id: int = present_ids[dice_engine.rand_int_range(0, present_ids.size() - 1)]
			if characters_by_id.has(opp_id):
				var opp: L5RCharacterData = characters_by_id[opp_id] as L5RCharacterData
				go_opponent = {
					"id": opp_id,
					"intelligence": opp.intelligence,
					"games_rank": SkillResolver.get_skill_rank(opp, "Games: Go"),
				}

		# Tea house companion — pick a random present character.
		var companion_id: int = -1
		if method == WindDownSystem.Method.TEA_HOUSE and not present_ids.is_empty():
			companion_id = present_ids[dice_engine.rand_int_range(0, present_ids.size() - 1)]

		var wind_result: Dictionary = WindDownSystem.apply_wind_down(
			c, method, dice_engine, present_ids, companion_id, go_opponent, fortune_id,
		)

		# Void Point refresh per s57.32.2 — gated on rested_last_night and
		# void_refresh_blocked_until (supernatural spell block, s57.32.8).
		var ooc_day: int = ic_day / TimeSystem.TICKS_PER_REAL_DAY
		if c.rested_last_night \
				and (c.void_refresh_blocked_until == -1 or ooc_day >= c.void_refresh_blocked_until):
			c.current_void_points = ceili(c.max_void_points * c.wind_down_void_modifier)

		# Natural healing per s57.31.7a — gated on rested_last_night; blocked at Out.
		var wounds_healed: int = 0
		if c.rested_last_night and CharacterStats.get_wound_level(c) != Enums.WoundLevel.OUT:
			var heal_amount: int = (c.stamina * 2) + CharacterStats.get_insight_rank(c)
			wounds_healed = WoundSystem.heal_wounds(c, heal_amount)["healed"]

		# Honor and Glory changes.
		if wind_result["honor_change"] != 0.0:
			HonorGlorySystem.apply_honor_change(c, wind_result["honor_change"])
		if wind_result["glory_change"] != 0.0:
			HonorGlorySystem.apply_glory_change(c, wind_result["glory_change"])

		# Disposition changes — mutual gain, clamped to [-100, 100].
		for change: Dictionary in wind_result["disposition_changes"]:
			var target_id: int = change["target_id"]
			var delta: int = change["delta"]
			var self_old: int = c.disposition_values.get(target_id, 0)
			c.disposition_values[target_id] = clampi(self_old + delta, -100, 100)
			if characters_by_id.has(target_id):
				var target: L5RCharacterData = characters_by_id[target_id] as L5RCharacterData
				var other_old: int = target.disposition_values.get(c.character_id, 0)
				target.disposition_values[c.character_id] = clampi(other_old + delta, -100, 100)

		# met_characters — add newly met characters.
		for met_id: int in wind_result["met_character_ids"]:
			if not c.met_characters.has(met_id):
				c.met_characters.append(met_id)
			if characters_by_id.has(met_id):
				var met_char: L5RCharacterData = characters_by_id[met_id] as L5RCharacterData
				if not met_char.met_characters.has(c.character_id):
					met_char.met_characters.append(c.character_id)

		# Topic leak — copy topic to target character's pool.
		var leaked_topic: int = wind_result["topic_leaked"]
		if leaked_topic != -1:
			var routing: String = wind_result["leak_routing"]
			if routing == WindDownSystem.ROUTING_RANDOM_PRESENT:
				var target_id: int = wind_result["leak_target_id"]
				if target_id != -1 and characters_by_id.has(target_id):
					var target: L5RCharacterData = characters_by_id[target_id] as L5RCharacterData
					if not target.topic_pool.has(leaked_topic):
						target.topic_pool.append(leaked_topic)
			# ROUTING_HANDLER_PIPELINE and ROUTING_BROTHERHOOD are handled by
			# their respective systems (Geisha Intelligence, Brotherhood network)
			# when those systems are implemented. The topic ID is available in
			# wind_result for forwarding.

		# Koku cost — deduct from character's personal purse.
		if wind_result["koku_cost"] > 0.0:
			c.koku = maxf(0.0, c.koku - wind_result["koku_cost"])

		# Temple info — Brotherhood network delivers one local rumor per s57.44.7.
		# Blocked on Brotherhood network implementation. Topic ID will be injected
		# here when that system exists.

		# WP contribution — add to worship state for the character's province.
		if wind_result["wp_contribution"] > 0.0 and settlement.province_id != -1:
			var wp_dist: Dictionary = {}
			var f_id: int = wind_result["fortune_id"]
			if f_id != -1:
				wp_dist[f_id] = wind_result["wp_contribution"]
			else:
				# Undirected offering — split equally across all Great Fortunes.
				var all_fortunes: int = WorshipSystem.GREAT_FORTUNE_COUNT
				var per_fortune: float = wind_result["wp_contribution"] / float(all_fortunes)
				for fi: int in range(all_fortunes):
					wp_dist[fi] = per_fortune
			WorshipSystem.add_active_worship_to_province(
				worship_state, settlement.province_id, wp_dist,
			)

		wind_result["character_id"] = c.character_id
		wind_result["wounds_healed"] = wounds_healed
		results.append(wind_result)

	return results


# -- Information Processing ----------------------------------------------------

static func _process_info_events(
	applied_list: Array,
	characters_by_id: Dictionary,
	action_log: Array[Dictionary],
	current_season: int,
	crime_records: Array[CrimeRecord] = [],
	objectives_map: Dictionary = {},
	world_states: Dictionary = {},
	active_topics: Array[TopicData] = [],
	next_topic_id: Array[int] = [1000],
	ic_day: int = 0,
	dice_engine: DiceEngine = null,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var location_characters: Dictionary = world_states.get("_location_characters", {})

	for applied: Dictionary in applied_list:
		var info_events: Array = applied.get("info_events", [])
		for event: Dictionary in info_events:
			var char_id: int = event.get("character_id", -1)
			var character: L5RCharacterData = characters_by_id.get(char_id)
			if character == null:
				continue

			var target_id: int = event.get("target_npc_id", -1)
			var quality: int = event.get("quality", 1)
			var info_type: String = event.get("info_type", "")

			if target_id >= 0 and info_type == "priority_objective":
				var target_obj: Dictionary = objectives_map.get(target_id, {})
				var standing: Dictionary = target_obj.get("standing", {})
				var need_type: String = standing.get("need_type", "")
				if not need_type.is_empty():
					var entry: KnowledgeEntry = InformationSystem.make_entry(
						Enums.KnowledgeSource.INTELLIGENCE,
						"priority_objective",
						{
							"target_character_id": target_id,
							"need_type": need_type,
						},
						current_season,
					)
					InformationSystem.add_knowledge(character, entry)
				results.append({
					"character_id": char_id,
					"target_id": target_id,
					"entries_discovered": 1 if not need_type.is_empty() else 0,
					"info_type": "priority_objective",
				})
				continue

			if target_id >= 0:
				var discovered: Array[KnowledgeEntry] = InformationSystem.process_probe_result(
					character, target_id, action_log, current_season, quality
				)

				var char_loc: String = character.physical_location
				var present_all: Array[int] = location_characters.get(char_loc, [] as Array[int])
				var characters_present: Array[int] = []
				for pid: int in present_all:
					if pid != char_id:
						characters_present.append(pid)

				var witness_result: Dictionary = _check_witness_evidence(
					char_id, target_id, quality, crime_records, objectives_map,
					characters_by_id, dice_engine, characters_present,
				)

				var w_threshold: String = witness_result.get("threshold_crossed", "")
				if w_threshold == "bribery_eval":
					_inject_bribery_eval_event(
						crime_records, target_id, world_states
					)
					_inject_extortion_opportunity_from_probe(
						crime_records, target_id, world_states
					)
				elif w_threshold == "accusation":
					_generate_accusation_topic_from_witness(
						char_id, crime_records, objectives_map,
						characters_by_id, active_topics, next_topic_id, ic_day
					)

				results.append({
					"character_id": char_id,
					"target_id": target_id,
					"entries_discovered": discovered.size(),
					"witness_evidence": witness_result.get("evidence_gained", 0),
				})

	return results


static func _inject_bribery_eval_event(
	crime_records: Array[CrimeRecord],
	target_id: int,
	world_states: Dictionary,
) -> void:
	for record: CrimeRecord in crime_records:
		if record.perpetrator_id < 0:
			continue
		if target_id not in record.known_suspects:
			continue
		var perp_ws: Dictionary = world_states.get(record.perpetrator_id, {})
		var events: Array = perp_ws.get("pending_events", [])
		for ev: Dictionary in events:
			if ev.get("type", "") == "bribery_eval" and ev.get("case_id", -1) == record.case_id:
				return
		events.append({
			"type": "bribery_eval",
			"case_id": record.case_id,
			"evidence_total": record.evidence_total,
			"magistrate_id": record.investigating_magistrate_id,
		})
		perp_ws["pending_events"] = events
		world_states[record.perpetrator_id] = perp_ws
		return


# -- Daily Conversations -------------------------------------------------------

static func _process_daily_conversations(
	characters: Array[L5RCharacterData],
	dice_engine: DiceEngine,
	current_season: int,
	active_topics: Array[TopicData] = [],
) -> Array[Dictionary]:
	var topics_by_id: Dictionary = {}
	for t: TopicData in active_topics:
		topics_by_id[t.topic_id] = t

	var eligible: Array[L5RCharacterData] = []
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if TravelSystem.is_traveling(c):
			continue
		eligible.append(c)

	var by_location: Dictionary = {}
	var by_ship: Dictionary = {}
	for c: L5RCharacterData in eligible:
		if c.aboard_ship_id >= 0:
			if not by_ship.has(c.aboard_ship_id):
				by_ship[c.aboard_ship_id] = []
			by_ship[c.aboard_ship_id].append(c)
		else:
			var loc: String = c.physical_location
			if loc.is_empty():
				continue
			if not by_location.has(loc):
				by_location[loc] = []
			by_location[loc].append(c)

	var all_results: Array[Dictionary] = []

	for loc: String in by_location:
		all_results.append_array(
			_resolve_group_conversations(by_location[loc], dice_engine, current_season, topics_by_id)
		)

	for ship_id: int in by_ship:
		all_results.append_array(
			_resolve_group_conversations(by_ship[ship_id], dice_engine, current_season, topics_by_id)
		)

	return all_results


static func _resolve_group_conversations(
	raw_group: Array,
	dice_engine: DiceEngine,
	current_season: int,
	topics_by_id: Dictionary,
) -> Array[Dictionary]:
	var group: Array[L5RCharacterData] = []
	for c: Variant in raw_group:
		if c is L5RCharacterData:
			group.append(c)
	if group.size() < 2:
		return []

	var pair_count: int = group.size() * (group.size() - 1) >> 1
	var rng_needed: int = pair_count * 3
	var rng: Array[int] = []
	for i: int in range(rng_needed):
		rng.append(dice_engine.rand_int_range(0, 99))

	return DailyConversation.resolve_settlement_conversations(
		group, rng, current_season, topics_by_id
	)


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
	emperor_tax_config: Dictionary = {},
	trade_routes: Array = [],
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
		worship_maluses, emperor_tax_config, trade_routes,
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


# -- Stipend Disposition Update (s4.3.9) ---------------------------------------
# Once per season, each retainer's disposition toward their immediate lord
# is adjusted by the lord's stipend personality modifier.
# Generous lords (Jin +10%, Meiyo +5%) build loyalty; hoarding lords lose it.

static func _process_seasonal_stipend_disposition(
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
) -> int:
	var updates_applied: int = 0
	for retainer: L5RCharacterData in characters:
		if retainer.lord_id < 0:
			continue
		var lord: L5RCharacterData = characters_by_id.get(retainer.lord_id)
		if lord == null:
			continue
		var modifier: float = ResourceTick.compute_stipend_modifier(
			lord.bushido_virtue, lord.shourido_virtue,
		)
		var delta: int = ResourceTick.compute_stipend_disposition_delta(modifier)
		if delta == 0:
			continue
		var old_disp: int = retainer.disposition_values.get(lord.character_id, 0)
		retainer.disposition_values[lord.character_id] = clampi(old_disp + delta, -100, 100)
		updates_applied += 1
	return updates_applied


static func _create_stipend_failure_topics(
	stipends: Dictionary,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> Array[Dictionary]:
	var created: Array[Dictionary] = []
	for char_id: Variant in stipends:
		var entry: Dictionary = stipends[char_id]
		if not entry.get("generates_topic", false):
			continue
		var lord_id: int = entry.get("lord_id", -1)
		var cid: int = char_id as int
		var topic := TopicData.new()
		topic.topic_id = next_topic_id[0]
		next_topic_id[0] += 1
		topic.slug = "stipend_failure_lord%d_char%d_d%d" % [lord_id, cid, ic_day]
		topic.title = "Stipend Failure by Lord %d" % lord_id
		topic.topic_type = "stipend_failure"
		topic.variant = "STIPEND_FAILURE"
		topic.tier = TopicData.Tier.TIER_4
		topic.category = TopicData.Category.ECONOMIC
		topic.subject_character_id = lord_id
		topic.subject_role = "NEGATIVE"
		topic.ic_day_created = ic_day
		topic.momentum = 0.0
		active_topics.append(topic)
		var holder_ids: Array[int] = []
		if lord_id >= 0:
			var lord: L5RCharacterData = characters_by_id.get(lord_id)
			if lord != null and topic.topic_id not in lord.topic_pool:
				lord.topic_pool.append(topic.topic_id)
				holder_ids.append(lord_id)
		var affected: L5RCharacterData = characters_by_id.get(cid)
		if affected != null and topic.topic_id not in affected.topic_pool:
			affected.topic_pool.append(topic.topic_id)
			holder_ids.append(cid)
		for other_id: Variant in characters_by_id:
			var oid: int = other_id as int
			if oid == lord_id or oid == cid:
				continue
			var other: L5RCharacterData = characters_by_id[oid]
			if other.lord_id == lord_id and affected != null and other.physical_location == affected.physical_location and other.physical_location != "":
				if topic.topic_id not in other.topic_pool:
					other.topic_pool.append(topic.topic_id)
					holder_ids.append(oid)
		created.append({
			"topic_id": topic.topic_id,
			"lord_id": lord_id,
			"character_id": cid,
			"ratio": entry.get("ratio", 0.0),
			"in_crisis": entry.get("in_crisis", false),
			"holder_ids": holder_ids,
		})
	return created


static func _populate_tax_modifiers(
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	provinces: Dictionary,
	season_meta: Dictionary,
) -> void:
	var tax_mod: Dictionary = {}
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid] as ProvinceData
		if prov == null:
			continue
		var best_id: int = -1
		var best_status: float = -1.0
		for c: L5RCharacterData in characters:
			if CharacterStats.is_dead(c):
				continue
			if c.clan != prov.clan:
				continue
			if c.lord_id >= 0 and c.status < 5.0:
				continue
			if c.status < 3.0:
				continue
			if c.status > best_status:
				best_status = c.status
				best_id = c.character_id
		if best_id < 0:
			continue
		var lord: L5RCharacterData = characters_by_id.get(best_id) as L5RCharacterData
		if lord == null:
			continue
		var mod: float = ResourceTick.compute_tax_modifier(
			lord.bushido_virtue, lord.shourido_virtue,
		)
		if mod != 0.0:
			tax_mod[int(pid)] = mod
	season_meta["_tax_modifier"] = tax_mod


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
		var ward_key: String = str(s.province_id)
		var kuni_wards: Dictionary = season_meta.get("kuni_wards", {})
		if kuni_wards.has(ward_key):
			var ward: Dictionary = kuni_wards[ward_key]
			ptl_gain = maxf(ptl_gain - ward.get("bleed_reduction", 0.0), 0.0)
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
	dice_engine: DiceEngine,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	# Build province_id → wall tower settlement map.
	var wall_by_province: Dictionary = {}
	for s: SettlementData in settlements:
		if s.settlement_type == Enums.SettlementType.WALL_TOWER:
			wall_by_province[s.province_id] = s

	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})
		if not effects.get("requires_sortie_combat", false):
			continue

		var target_pid: int = effects.get("target_province_id", -1)
		var planned_ss_reduction: int = int(effects.get("ss_reduction", 0))
		var force_pct: float = float(effects.get("force_pct", 0.0))
		var jade_per_warrior: int = int(effects.get("jade_per_warrior", 1))

		var settlement: Variant = wall_by_province.get(target_pid, null)
		var province: Variant = provinces.get(target_pid, null)

		# Build synthetic garrison battle states from committed PU.
		var committed_pu: int = 0
		var garrison_states: Array[Dictionary] = []
		if settlement is SettlementData:
			var s: SettlementData = settlement as SettlementData
			committed_pu = int(s.garrison_pu * force_pct)
			garrison_states = _build_garrison_sortie_states(committed_pu)

		# Resolve sortie combat via HordeSystem (s2.4.10).
		var ss: int = 0
		if province is ProvinceData:
			ss = (province as ProvinceData).shadowlands_strength

		var combat_result: Dictionary = {}
		var actual_ss_reduction: int = 0
		var casualties_health: int = 0
		if not garrison_states.is_empty():
			combat_result = HordeSystem.resolve_sortie_combat(
				garrison_states, planned_ss_reduction, ss, dice_engine,
			)
			actual_ss_reduction = int(combat_result.get("ss_reduction", 0))
			casualties_health = int(combat_result.get("casualties_health", 0))

		# Apply SS reduction only if combat succeeded.
		var new_ss: int = ss
		if province is ProvinceData and actual_ss_reduction > 0:
			var prov: ProvinceData = province as ProvinceData
			new_ss = maxi(0, prov.shadowlands_strength - actual_ss_reduction)
			prov.shadowlands_strength = new_ss

		# Reduce garrison PU by combat casualties (153 health = 1 PU).
		var pu_lost: int = 0
		var jade_consumed: float = 0.0
		if settlement is SettlementData:
			var s: SettlementData = settlement as SettlementData
			pu_lost = int(casualties_health / 153.0)
			s.garrison_pu = maxi(0, s.garrison_pu - pu_lost)

			# Consume jade regardless of combat outcome (s2.4.15).
			var warriors: int = committed_pu
			jade_consumed = float(warriors * jade_per_warrior)
			s.jade_stockpile = maxf(0.0, s.jade_stockpile - jade_consumed)

		results.append({
			"province_id": target_pid,
			"sortie_success": combat_result.get("success", false),
			"ss_reduction_applied": actual_ss_reduction,
			"new_ss": new_ss,
			"pu_lost": pu_lost,
			"jade_consumed": jade_consumed,
			"battle_result": combat_result.get("battle_result", {}),
		})

	return results


## Build synthetic GARRISON-type battle company dicts for sortie_states.
## garrison_pu: number of companies committed (each = 153 health / 1 PU).
static func _build_garrison_sortie_states(garrison_pu: int) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var stats: Dictionary = ArmyCombatSystem.UNIT_STATS.get(
		Enums.CompanyUnitType.GARRISON, {}
	)
	for i: int in range(garrison_pu):
		states.append({
			"company": null,
			"company_id": 7000 + i,
			"unit_type": Enums.CompanyUnitType.GARRISON,
			"starting_health": stats.get("health", 153),
			"current_health": stats.get("health", 153),
			"starting_morale": stats.get("morale", 16),
			"current_morale": stats.get("morale", 16),
			"base_attack": stats.get("attack", 3),
			"base_defense": stats.get("defense", 5),
			"base_morale_defense": stats.get("morale_defense", 7),
			"row": 1,
			"column": i,
			"side": "defender",
			"is_routed": false,
			"is_destroyed": false,
			"commander": null,
			"commander_bonus": {},
			"commander_injured": false,
			"commander_dead": false,
			"survival_thresholds_triggered": [],
			"health_damage_this_round": 0,
			"no_morale": false,
			"round_number": 0,
		})
	return states


# -- Storm Assault Processing (s11.7) ------------------------------------------

static func _process_storm_assault_results(
	applied_list: Array,
	active_sieges: Array[Dictionary],
	companies: Array[Dictionary],
	dice_engine: DiceEngine,
	settlements: Array[SettlementData],
	characters_by_id: Dictionary,
	active_hostages: Array[Dictionary] = [],
	ic_day: int = 0,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})
		if not effects.get("requires_storm_assault", false):
			continue

		var siege_settlement_id: int = effects.get("siege_settlement_id", -1)
		var siege: Dictionary = _find_siege_by_settlement(
			siege_settlement_id, active_sieges,
		)
		if siege.is_empty():
			push_warning(
				"[StormAssault] No siege found at settlement %d" % siege_settlement_id,
			)
			continue

		var atk_army_id: int = siege.get("attacker_army_id", -1)
		var def_army_id: int = siege.get("defender_army_id", -1)

		var atk_dicts: Array[Dictionary] = _get_army_companies(atk_army_id, companies)
		var def_dicts: Array[Dictionary] = _get_army_companies(def_army_id, companies)

		if atk_dicts.is_empty() or def_dicts.is_empty():
			push_warning(
				"[StormAssault] Empty companies: atk=%d def=%d" % [
					atk_dicts.size(), def_dicts.size(),
				],
			)
			continue

		var atk_states: Array[Dictionary] = _build_battle_states(
			atk_dicts, "attacker", characters_by_id,
		)
		var def_states: Array[Dictionary] = _build_battle_states(
			def_dicts, "defender", characters_by_id,
		)

		var fort_bonus: int = SiegeSystem.get_storm_defense_bonus()
		var battle_result: Dictionary = resolve_and_reconcile_battle(
			atk_states, def_states, Enums.BattleTerrainType.URBAN,
			dice_engine, settlements, false, fort_bonus,
		)

		var captor_lord_id: int = atk_dicts[0].get("lord_id", -1) if not atk_dicts.is_empty() else -1
		var victor: String = battle_result.get("victor", "draw")
		_capture_dead_commanders(
			battle_result, victor, captor_lord_id,
			str(siege_settlement_id), characters_by_id, active_hostages, ic_day, dice_engine,
		)
		_write_battle_results_to_companies(battle_result, companies)

		if victor == "attacker":
			siege["siege_ended"] = true
			siege["end_reason"] = "storm_assault_success"
		elif victor == "defender":
			siege["ticks_since_sortie"] = 0

		results.append({
			"siege_settlement_id": siege_settlement_id,
			"victor": victor,
			"rounds": battle_result.get("rounds", 0),
			"attacker_army_id": atk_army_id,
			"defender_army_id": def_army_id,
		})

	return results


static func _find_siege_by_settlement(
	settlement_id: int,
	active_sieges: Array[Dictionary],
) -> Dictionary:
	for siege: Dictionary in active_sieges:
		if siege.get("settlement_id", -1) == settlement_id:
			return siege
	return {}


static func _process_drill_effects(
	applied_list: Array,
	companies: Array[Dictionary],
	characters_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})
		if not effects.get("requires_drill", false):
			continue
		var char_id: int = applied.get("character_id", -1)
		var target_cid: int = effects.get("target_company_id", -1)
		var character: L5RCharacterData = characters_by_id.get(char_id)
		if character == null:
			continue

		var company: Dictionary = {}
		for c: Dictionary in companies:
			if c.get("company_id", -1) == target_cid:
				company = c
				break
		if company.is_empty():
			for c: Dictionary in companies:
				if c.get("commander_id", -1) == char_id:
					company = c
					break
		if company.is_empty():
			continue

		const DRILL_TN: int = 15
		var roll_result: Dictionary = SkillResolver.resolve_skill_check(
			character, dice_engine, "Battle", DRILL_TN,
		)
		var success: bool = roll_result.get("success", false)
		var margin: int = roll_result.get("margin", 0)
		var points: int = 0
		if success:
			points = 1 + maxi(margin / 5, 0)

		var current_points: int = company.get("training_points", 0) + points
		var current_level: int = company.get("training_level", 2)
		const POINTS_PER_LEVEL: int = 10
		const MAX_LEVEL: int = 3
		if current_level < MAX_LEVEL and current_points >= POINTS_PER_LEVEL:
			current_points -= POINTS_PER_LEVEL
			current_level += 1
		company["training_points"] = current_points
		company["training_level"] = current_level

		results.append({
			"company_id": company.get("company_id", -1),
			"character_id": char_id,
			"success": success,
			"points_added": points,
			"new_level": current_level,
			"new_points": current_points,
		})
	return results


static func _tick_kuni_wards(season_meta: Dictionary) -> void:
	var wards: Dictionary = season_meta.get("kuni_wards", {})
	var expired: Array[String] = []
	for key: String in wards:
		var ward: Dictionary = wards[key]
		ward["seasons_remaining"] = ward.get("seasons_remaining", 0) - 1
		if ward["seasons_remaining"] <= 0:
			expired.append(key)
	for key: String in expired:
		wards.erase(key)
	if wards.is_empty():
		season_meta.erase("kuni_wards")
	else:
		season_meta["kuni_wards"] = wards


static func _process_purification_effects(
	applied_list: Array,
	provinces: Dictionary,
	season_meta: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})
		if not effects.get("requires_purification", false):
			continue
		var pid: int = effects.get("province_id", -1)
		if pid < 0 or not provinces.has(pid):
			continue
		var prov: ProvinceData = provinces[pid]
		var reduction: float = effects.get("ptl_reduction", 0.0)
		prov.province_taint_level = maxf(prov.province_taint_level - reduction, 0.0)

		var ward_reduction: float = effects.get("ward_bleed_reduction", 0.0)
		var ward_duration: int = effects.get("ward_duration", 0)
		var ward_rank: int = effects.get("ward_school_rank", 0)
		if ward_duration > 0:
			var existing_ward: Dictionary = season_meta.get(
				"kuni_wards", {},
			).get(str(pid), {})
			if existing_ward.is_empty() or ward_reduction >= existing_ward.get("bleed_reduction", 0.0):
				var wards: Dictionary = season_meta.get("kuni_wards", {})
				wards[str(pid)] = {
					"bleed_reduction": ward_reduction,
					"seasons_remaining": ward_duration,
					"school_rank": ward_rank,
				}
				season_meta["kuni_wards"] = wards

		results.append({
			"province_id": pid,
			"ptl_reduction": reduction,
			"new_ptl": prov.province_taint_level,
			"ward_set": ward_duration > 0,
		})
	return results


static func _process_patrol_effects(
	applied_list: Array,
	season_meta: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})
		if not effects.get("requires_patrol", false):
			continue
		var pid: int = effects.get("patrol_province_id", -1)
		if pid < 0:
			continue
		var patrolled: Dictionary = season_meta.get("patrolled_provinces", {})
		patrolled[pid] = true
		season_meta["patrolled_provinces"] = patrolled
		results.append({"province_id": pid, "character_id": applied.get("character_id", -1)})
	return results


static func _process_siege_maintenance(
	applied_list: Array,
	active_sieges: Array[Dictionary],
	ic_day: int,
) -> void:
	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})
		if not effects.get("requires_siege_maintenance", false):
			continue
		var sid: int = effects.get("siege_settlement_id", -1)
		var siege: Dictionary = _find_siege_by_settlement(sid, active_sieges)
		if not siege.is_empty():
			siege["last_maintained_ic_day"] = ic_day


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
			topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(topic.tier)
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
		topic.momentum = _COMBAT_EVENT_MOMENTUM
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
	topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(topic.tier)
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
	topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(tier)
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


# -- Scene Examination Writebacks (s11.3.13) -----------------------------------

static func _process_scene_examination_writebacks(
	results: Array,
	objectives_map: Dictionary,
	world_states: Dictionary,
	characters_by_id: Dictionary = {},
	active_topics: Array[TopicData] = [],
	next_topic_id: Array[int] = [1000],
	ic_day: int = 0,
) -> void:
	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		if r.get("action_id", "") != "EXAMINE_CRIME_SCENE":
			continue
		var effects: Dictionary = r.get("effects", {})
		if effects.get("effect", "") != "scene_examined":
			continue
		if not r.get("success", false):
			continue

		var char_id: int = r.get("character_id", -1)
		var case_id: int = effects.get("case_id", -1)
		if char_id < 0 or case_id < 0:
			continue

		var objs: Dictionary = objectives_map.get(char_id, {})
		for obj_key: Variant in objs:
			var obj: Variant = objs[obj_key]
			if obj is Dictionary:
				var active_case: Dictionary = (obj as Dictionary).get("active_case", {})
				if active_case.get("case_id", -1) == case_id:
					active_case["scene_examined"] = true
					active_case["scene_exam_count"] = active_case.get("scene_exam_count", 0) + 1
					active_case["evidence_total"] = effects.get("evidence_gained", 0) + active_case.get("evidence_total", 0)
					break

		var threshold: String = effects.get("threshold_crossed", "")
		if threshold == "bribery_eval":
			_inject_bribery_eval_event_by_case(case_id, world_states)
			_inject_extortion_opportunity_by_case(case_id, world_states)
		elif threshold == "accusation":
			_generate_accusation_topic_for_case(
				case_id, world_states, characters_by_id,
				active_topics, next_topic_id, ic_day
			)


static func _update_patrol_tracking(
	results: Array,
	objectives_map: Dictionary,
	ic_day: int,
) -> void:
	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		var action_id: String = r.get("action_id", "")
		if action_id != "EXAMINE_CRIME_SCENE" and action_id != "INVESTIGATE_PROVINCE":
			continue
		if not r.get("success", false):
			continue
		var char_id: int = r.get("character_id", -1)
		if char_id < 0:
			continue
		var objs: Dictionary = objectives_map.get(char_id, {})
		var standing: Dictionary = objs.get("standing", {})
		if standing.get("need_type", "") == "UPHOLD_LAW":
			standing["last_patrol_ic_day"] = ic_day


static func _inject_bribery_eval_event_by_case(
	case_id: int,
	world_states: Dictionary,
) -> void:
	var cr: Array[CrimeRecord] = world_states.get("_crime_records", [] as Array[CrimeRecord])
	for record: CrimeRecord in cr:
		if record.case_id == case_id:
			var perp_id: int = record.perpetrator_id
			if perp_id < 0:
				return
			var ws: Dictionary = world_states.get(perp_id, {})
			var pending: Array = ws.get("pending_events", [])
			pending.append({
				"type": "bribery_eval",
				"case_id": case_id,
				"evidence_total": record.evidence_total,
				"magistrate_id": record.investigating_magistrate_id,
			})
			ws["pending_events"] = pending
			world_states[perp_id] = ws
			return


static func _inject_extortion_opportunity_by_case(
	case_id: int,
	world_states: Dictionary,
) -> void:
	var cr: Array[CrimeRecord] = world_states.get("_crime_records", [] as Array[CrimeRecord])
	for record: CrimeRecord in cr:
		if record.case_id != case_id:
			continue
		var mag_id: int = record.investigating_magistrate_id
		if mag_id < 0:
			return
		var mag_ws: Dictionary = world_states.get(mag_id, {})
		var mag_pending: Array = mag_ws.get("pending_events", [])
		for ev: Dictionary in mag_pending:
			if ev.get("type", "") == "extortion_opportunity" and ev.get("case_id", -1) == case_id:
				return
		mag_pending.append({
			"type": "extortion_opportunity",
			"case_id": case_id,
			"suspect_id": record.perpetrator_id,
			"evidence_total": record.evidence_total,
		})
		mag_ws["pending_events"] = mag_pending
		world_states[mag_id] = mag_ws
		return


static func _inject_extortion_opportunity_from_probe(
	crime_records: Array[CrimeRecord],
	target_id: int,
	world_states: Dictionary,
) -> void:
	for record: CrimeRecord in crime_records:
		if record.perpetrator_id < 0:
			continue
		if target_id not in record.known_suspects:
			continue
		var mag_id: int = record.investigating_magistrate_id
		if mag_id < 0:
			return
		var mag_ws: Dictionary = world_states.get(mag_id, {})
		var mag_pending: Array = mag_ws.get("pending_events", [])
		for ev: Dictionary in mag_pending:
			if ev.get("type", "") == "extortion_opportunity" and ev.get("case_id", -1) == record.case_id:
				return
		mag_pending.append({
			"type": "extortion_opportunity",
			"case_id": record.case_id,
			"suspect_id": record.perpetrator_id,
			"evidence_total": record.evidence_total,
		})
		mag_ws["pending_events"] = mag_pending
		world_states[mag_id] = mag_ws
		return


static func _generate_accusation_topic_for_case(
	case_id: int,
	world_states: Dictionary,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	var cr: Array[CrimeRecord] = world_states.get("_crime_records", [] as Array[CrimeRecord])
	for record: CrimeRecord in cr:
		if record.case_id == case_id:
			var accused: L5RCharacterData = characters_by_id.get(record.perpetrator_id)
			if accused == null:
				return
			_transition_case_entry_to_accused(accused, case_id, ic_day)
			var topic: TopicData = InvestigationSystem.generate_accusation_topic(
				record, accused, next_topic_id, ic_day
			)
			if topic != null:
				active_topics.append(topic)
				var lord_id: int = accused.lord_id
				var lord: L5RCharacterData = characters_by_id.get(lord_id)
				if lord != null and topic.topic_id not in lord.topic_pool:
					lord.topic_pool.append(topic.topic_id)
			return


static func _generate_accusation_topic_from_witness(
	prober_id: int,
	crime_records: Array[CrimeRecord],
	objectives_map: Dictionary,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	var objectives: Dictionary = objectives_map.get(prober_id, {})
	var standing: Dictionary = objectives.get("standing", {})
	var active_case: Dictionary = standing.get("active_case", {})
	if active_case.is_empty():
		var primary: Dictionary = objectives.get("primary", {})
		active_case = primary if primary.get("need_type", "") == "INVESTIGATE_CRIME" else {}
	if active_case.is_empty():
		return

	var case_id: int = active_case.get("case_id", -1)
	if case_id < 0:
		return

	for record: CrimeRecord in crime_records:
		if record.case_id == case_id:
			var accused: L5RCharacterData = characters_by_id.get(record.perpetrator_id)
			if accused == null:
				return
			_transition_case_entry_to_accused(accused, case_id, ic_day)
			var topic: TopicData = InvestigationSystem.generate_accusation_topic(
				record, accused, next_topic_id, ic_day
			)
			if topic != null:
				active_topics.append(topic)
				var lord_id: int = accused.lord_id
				var lord: L5RCharacterData = characters_by_id.get(lord_id)
				if lord != null and topic.topic_id not in lord.topic_pool:
					lord.topic_pool.append(topic.topic_id)
			return


static func _transition_case_entry_to_accused(
	accused: L5RCharacterData,
	case_id: int,
	ic_day: int,
) -> void:
	var entry: LegalCaseEntry = LegalStatusSystem.get_case(accused, case_id)
	if entry != null:
		LegalStatusSystem.transition(entry, Enums.LegalStatus.ACCUSED, ic_day)
	else:
		var new_entry := LegalCaseEntry.new()
		new_entry.crime_record_id = case_id
		new_entry.state = Enums.LegalStatus.ACCUSED
		new_entry.evidence_total = InvestigationSystem.ACCUSATION_THRESHOLD
		new_entry.accusation_timestamp = ic_day
		accused.legal_cases.append(new_entry)


static func handle_evidence_threshold(
	threshold: String,
	record: CrimeRecord,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	world_states: Dictionary = {},
) -> void:
	if threshold == "bribery_eval":
		var perp_id: int = record.perpetrator_id
		if perp_id < 0:
			return
		var ws: Dictionary = world_states.get(perp_id, {})
		var pending: Array = ws.get("pending_events", [])
		for ev: Dictionary in pending:
			if ev.get("type", "") == "bribery_eval" and ev.get("case_id", -1) == record.case_id:
				return
		var first_witness_id: int = record.witnesses[0] if not record.witnesses.is_empty() else -1
		pending.append({
			"type": "bribery_eval",
			"case_id": record.case_id,
			"evidence_total": record.evidence_total,
			"magistrate_id": record.investigating_magistrate_id,
			"witness_id": first_witness_id,
		})
		ws["pending_events"] = pending
		world_states[perp_id] = ws

		var mag_id: int = record.investigating_magistrate_id
		if mag_id >= 0:
			var mag_ws: Dictionary = world_states.get(mag_id, {})
			var mag_pending: Array = mag_ws.get("pending_events", [])
			for ev: Dictionary in mag_pending:
				if ev.get("type", "") == "extortion_opportunity" and ev.get("case_id", -1) == record.case_id:
					return
			mag_pending.append({
				"type": "extortion_opportunity",
				"case_id": record.case_id,
				"suspect_id": perp_id,
				"evidence_total": record.evidence_total,
			})
			mag_ws["pending_events"] = mag_pending
			world_states[mag_id] = mag_ws
	elif threshold == "accusation":
		var accused: L5RCharacterData = characters_by_id.get(record.perpetrator_id)
		if accused == null:
			return
		_transition_case_entry_to_accused(accused, record.case_id, ic_day)
		var topic: TopicData = InvestigationSystem.generate_accusation_topic(
			record, accused, next_topic_id, ic_day
		)
		if topic != null:
			active_topics.append(topic)
			var lord_id: int = accused.lord_id
			var lord: L5RCharacterData = characters_by_id.get(lord_id)
			if lord != null and topic.topic_id not in lord.topic_pool:
				lord.topic_pool.append(topic.topic_id)


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
	active_wars: Array[WarData] = [],
	action_log: Array[Dictionary] = [],
	dice_engine: DiceEngine = null,
) -> Array[Dictionary]:
	var crime_results: Array[Dictionary] = []

	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		var effects: Dictionary = r.get("effects", {})

		var char_id: int = r.get("character_id", -1)
		var character: L5RCharacterData = characters_by_id.get(char_id)
		if character == null:
			continue

		var crime_type: int = -1
		var action_id: String = r.get("action_id", "")

		if effects.get("requires_crime_creation", false):
			crime_type = effects.get("crime_type", -1)
		elif effects.get("detection_risk", false):
			crime_type = _action_to_crime_type(action_id)
		if crime_type < 0:
			continue

		var case_id: int = next_case_id[0]
		next_case_id[0] = case_id + 1
		var location: String = character.physical_location
		var target_id: int = r.get("target_npc_id", -1)

		var witnesses: Array[int] = _get_witnesses_at_location(
			char_id, location, characters_by_id, world_states
		)

		var is_killing: bool = crime_type in [
			Enums.CrimeType.UNSANCTIONED_DUEL_DEATH,
			Enums.CrimeType.UNSANCTIONED_OPEN_KILLING,
			Enums.CrimeType.UNSANCTIONED_COVERT_KILLING,
		]

		if is_killing:
			var victim: L5RCharacterData = characters_by_id.get(target_id)
			if victim != null:
				var clans_at_war: bool = WarSystem.are_clans_at_war(
					active_wars, character.clan, victim.clan
				)
				var is_battlefield: bool = _is_character_in_battle(
					char_id, world_states
				)
				var is_prisoner: bool = victim.captive_status != ""
				var attacker_acted_first: bool = _did_victim_act_first(
					effects, action_id
				)
				var has_zone_log: bool = _has_zone_log_evidence(
					char_id, target_id, location, action_log
				)
				var killing_result := CrimeWiring.process_killing_crime(
					effects, character, victim, case_id, ic_day, witnesses,
					clans_at_war, is_battlefield, is_prisoner,
					attacker_acted_first, has_zone_log,
				)
				if not killing_result.get("crime_created", false):
					crime_results.append({
						"case_id": -1,
						"character_id": char_id,
						"crime_type": crime_type,
						"action_id": action_id,
						"no_crime": true,
						"reason": killing_result.get("reason", ""),
					})
					continue
				var record: CrimeRecord = killing_result["record"]
				crime_records.append(record)
				var at_act: Dictionary = CrimeSystem.apply_at_act_consequences(
					character, record.crime_type
				)
				var crime_topic: TopicData = _create_crime_topic(
					record, character, ic_day, next_topic_id
				)
				if crime_topic != null:
					active_topics.append(crime_topic)
					_seed_crime_topic_to_knowers(crime_topic, record, characters_by_id)
				crime_results.append({
					"case_id": case_id,
					"character_id": char_id,
					"crime_type": record.crime_type,
					"action_id": action_id,
					"honor_delta": at_act.get("honor_delta", 0.0),
					"topic_id": crime_topic.topic_id if crime_topic != null else -1,
					"witness_count": witnesses.size(),
					"classification": killing_result.get("classification", {}),
					"jurisdiction": killing_result.get("jurisdiction", {}),
				})
				continue

		var record: CrimeRecord = CrimeSystem.create_crime_record(
			case_id, crime_type, char_id, location, ic_day, target_id,
			0, witnesses
		)
		crime_records.append(record)

		var crime_type_str: String = _crime_type_to_string(crime_type)
		var discovery: InvestigationLoopSystem.DiscoveryType = InvestigationLoopSystem.get_discovery_type(crime_type_str)
		record.legal_status = InvestigationLoopSystem.get_initial_legal_status(discovery)

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

		if dice_engine != null:
			_apply_criminal_recall(character, record, witnesses, dice_engine, world_states)

		if action_id == "BRIBE_FOR_INFO" and effects.get("suppress_case", false):
			var bribe_magistrate_id: int = effects.get("magistrate_id", -1)
			_apply_failed_bribe_evidence(
				crime_records, char_id, characters_by_id,
				active_topics, next_topic_id, ic_day, world_states,
				bribe_magistrate_id
			)

	return crime_results


static func process_fugitive_declaration(
	record: CrimeRecord,
	fugitive: L5RCharacterData,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> Dictionary:
	if fugitive == null:
		return {"declared": false}

	record.legal_status = Enums.LegalStatus.FUGITIVE
	var entry: LegalCaseEntry = LegalStatusSystem.get_case(fugitive, record.case_id)
	if entry != null:
		LegalStatusSystem.transition(entry, Enums.LegalStatus.FUGITIVE, ic_day)

	var topic: TopicData = InvestigationSystem.generate_fugitive_topic(
		fugitive, next_topic_id, ic_day
	)
	if topic != null:
		active_topics.append(topic)
		var lord_id: int = fugitive.lord_id
		var lord: L5RCharacterData = characters_by_id.get(lord_id)
		if lord != null and topic.topic_id not in lord.topic_pool:
			lord.topic_pool.append(topic.topic_id)

	return {
		"declared": true,
		"fugitive_id": fugitive.character_id,
		"topic_id": topic.topic_id if topic != null else -1,
	}


# -- Fugitive Extradition Seasonal Pass (s11.3.16) ------------------------------
# For every FUGITIVE CrimeRecord where the fugitive is from a different clan
# than the crime province, evaluate the harboring lord's extradition decision
# and apply consequences (cooperation/refusal/imperial warrant).

static func _process_fugitive_extradition_seasonal(
	crime_records: Array[CrimeRecord],
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	provinces: Dictionary,
	settlements: Array[SettlementData],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	var sett_prov_map: Dictionary = {}
	for s: SettlementData in settlements:
		sett_prov_map[s.settlement_id] = s.province_id

	for record: CrimeRecord in crime_records:
		if record.legal_status != Enums.LegalStatus.FUGITIVE:
			continue

		var fugitive: L5RCharacterData = characters_by_id.get(record.perpetrator_id)
		if fugitive == null or CharacterStats.is_dead(fugitive):
			continue

		# Map crime location (settlement_id string) to clan
		if not record.location.is_valid_int():
			continue
		var crime_settlement_id: int = int(record.location)
		var crime_province_id: int = sett_prov_map.get(crime_settlement_id, -1)
		if crime_province_id < 0:
			continue
		var crime_province: ProvinceData = provinces.get(crime_province_id) as ProvinceData
		if crime_province == null:
			continue
		var crime_clan: String = crime_province.clan

		# Only cross-clan cases
		if fugitive.clan.is_empty() or fugitive.clan == crime_clan:
			continue

		# Sighting topic for notable fugitives (s11.3.16a)
		if FugitiveExtraditionSystem.generates_sighting_topic(fugitive.status):
			var sighting: TopicData = TopicData.new()
			sighting.topic_id = next_topic_id[0]
			next_topic_id[0] += 1
			sighting.slug = "fugitive_sighting_%d_d%d" % [fugitive.character_id, ic_day]
			sighting.title = "A stranger matching %s was seen in foreign territory" % fugitive.character_name
			sighting.topic_type = "fugitive_sighting"
			sighting.tier = TopicData.Tier.TIER_4
			sighting.category = TopicData.Category.POLITICAL
			sighting.momentum = TopicMomentumSystem.initial_momentum_for_tier(sighting.tier)
			sighting.subject_character_id = fugitive.character_id
			sighting.clan_involved = fugitive.clan
			sighting.ic_day_created = ic_day
			active_topics.append(sighting)

		# Harboring lord: fugitive's direct lord (still in fugitive.lord_id after flee)
		var harboring_lord: L5RCharacterData = _extrad_find_harboring_lord(
			fugitive, characters, characters_by_id
		)
		if harboring_lord == null:
			continue

		# Requesting clan: find clan champion for disposition lookup
		var requesting_champ_id: int = _extrad_find_clan_champion_id(crime_clan, characters)
		var requesting_disp: int = 0
		if requesting_champ_id >= 0:
			requesting_disp = harboring_lord.disposition_values.get(requesting_champ_id, 0)

		# Crime tier from CONVICTION_CONSEQUENCES (index 3); clamp to 1-4 range
		var crime_tier: int = _extrad_crime_tier(record.crime_type)

		# Evaluate harboring lord decision (s11.3.16c)
		# Conservative defaults: no usefulness or leverage assumed (structural wiring)
		var eval: Dictionary = ExtraditionSystem.evaluate_extradition(
			harboring_lord,
			requesting_disp,
			fugitive.status,
			crime_tier,
			not fugitive.role_position.is_empty(),
			false,
			false,
		)
		var response: ExtraditionSystem.Response = eval.get(
			"response", ExtraditionSystem.Response.REFUSE
		)

		# Extradition request topic (s11.3.16b, Tier 4)
		var req_topic: TopicData = TopicData.new()
		req_topic.topic_id = next_topic_id[0]
		next_topic_id[0] += 1
		req_topic.slug = "extradition_%d_d%d" % [fugitive.character_id, ic_day]
		req_topic.title = "%s requests extradition of %s from %s" % [
			crime_clan, fugitive.character_name, fugitive.clan
		]
		req_topic.topic_type = "extradition_request"
		req_topic.tier = TopicData.Tier.TIER_4
		req_topic.category = TopicData.Category.POLITICAL
		req_topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(req_topic.tier)
		req_topic.subject_character_id = fugitive.character_id
		req_topic.clan_involved = fugitive.clan
		req_topic.ic_day_created = ic_day
		active_topics.append(req_topic)

		var result: Dictionary = {
			"fugitive_id": fugitive.character_id,
			"requesting_clan": crime_clan,
			"harboring_clan": fugitive.clan,
			"response": response,
			"crime_tier": crime_tier,
			"extradition_topic_id": req_topic.topic_id,
		}

		match response:
			ExtraditionSystem.Response.COOPERATE:
				var consequences: Dictionary = ExtraditionSystem.apply_cooperation(
					harboring_lord, requesting_champ_id, crime_tier
				)
				result["consequences"] = consequences
				# Fugitive returned: revert to ACCUSED for trial
				record.legal_status = Enums.LegalStatus.ACCUSED
				var case_entry: LegalCaseEntry = LegalStatusSystem.get_case(
					fugitive, record.case_id
				)
				if case_entry != null:
					LegalStatusSystem.transition(case_entry, Enums.LegalStatus.ACCUSED, ic_day)
				result["fugitive_returned"] = true

			ExtraditionSystem.Response.REFUSE, ExtraditionSystem.Response.DENY_KNOWLEDGE:
				var is_denial: bool = response == ExtraditionSystem.Response.DENY_KNOWLEDGE
				var consequences: Dictionary = ExtraditionSystem.apply_refusal(
					harboring_lord, requesting_champ_id, crime_tier, is_denial
				)
				result["consequences"] = consequences
				# Escalation for Tier 2+ crimes (s11.3.16e)
				if FugitiveExtraditionSystem.can_request_imperial_warrant(crime_tier):
					var compliance: Dictionary = FugitiveExtraditionSystem.evaluate_imperial_warrant_compliance(
						harboring_lord
					)
					result["imperial_warrant"] = compliance
					if compliance.get("complies", false):
						record.legal_status = Enums.LegalStatus.ACCUSED
						var case_entry: LegalCaseEntry = LegalStatusSystem.get_case(
							fugitive, record.case_id
						)
						if case_entry != null:
							LegalStatusSystem.transition(case_entry, Enums.LegalStatus.ACCUSED, ic_day)
						result["fugitive_returned"] = true
				else:
					result["standing_warrant"] = FugitiveExtraditionSystem.get_standing_warrant_consequences()

			_:  # NEGOTIATE
				result["negotiating"] = true

		results.append(result)

	return results


static func _extrad_find_harboring_lord(
	fugitive: L5RCharacterData,
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
) -> L5RCharacterData:
	if fugitive.lord_id >= 0:
		var lord: L5RCharacterData = characters_by_id.get(fugitive.lord_id)
		if lord != null and not CharacterStats.is_dead(lord) and lord.clan == fugitive.clan:
			return lord
	for c: L5RCharacterData in characters:
		if c.clan == fugitive.clan and c.role_position == "Clan Champion" and not CharacterStats.is_dead(c):
			return c
	return null


static func _extrad_find_clan_champion_id(clan: String, characters: Array[L5RCharacterData]) -> int:
	for c: L5RCharacterData in characters:
		if c.clan == clan and c.role_position == "Clan Champion" and not CharacterStats.is_dead(c):
			return c.character_id
	return -1


static func _extrad_crime_tier(crime_type: Enums.CrimeType) -> int:
	var consequences: Array = CrimeSystem.CONVICTION_CONSEQUENCES.get(crime_type, [-0.1, 0.0, 0.0, 4])
	var tier: int = int(consequences[3])
	# tier 0 in the table means "no formal standalone topic" — treat as minor (4) for scoring
	if tier <= 0:
		return 4
	return clampi(tier, 1, 4)


static func _process_successful_bribe_writebacks(
	results: Array,
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	ic_day: int,
	active_secrets: Array[SecretData] = [],
	next_secret_id: Array[int] = [1],
	next_case_id: Array[int] = [1],
	objectives_map: Dictionary = {},
) -> void:
	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		if r.get("action_id", "") != "BRIBE_FOR_INFO":
			continue
		if not r.get("success", false):
			continue
		var effects: Dictionary = r.get("effects", {})
		if not effects.get("suppress_case", false):
			continue

		var briber_id: int = r.get("character_id", -1)
		var magistrate_id: int = effects.get("magistrate_id", -1)
		var magistrate: L5RCharacterData = characters_by_id.get(magistrate_id)
		if magistrate == null:
			continue

		var briber: L5RCharacterData = characters_by_id.get(briber_id)

		for record: CrimeRecord in crime_records:
			if record.perpetrator_id != briber_id:
				continue
			if record.legal_status == Enums.LegalStatus.DECREED_GUILTY:
				continue
			if record.legal_status == Enums.LegalStatus.ACQUITTED:
				continue
			record.legal_status = Enums.LegalStatus.CLEAR
			if briber != null:
				var entry: LegalCaseEntry = LegalStatusSystem.get_case(briber, record.case_id)
				if entry != null:
					LegalStatusSystem.transition(entry, Enums.LegalStatus.CLEAR, ic_day)
			HonorGlorySystem.apply_honor_change(magistrate, -0.5)

			# Release magistrate's active case
			var mag_objs: Dictionary = objectives_map.get(magistrate_id, {})
			var standing: Dictionary = mag_objs.get("standing", {})
			if standing.get("need_type", "") == "UPHOLD_LAW":
				var active_case: Dictionary = standing.get("active_case", {})
				if active_case.get("case_id", -1) == record.case_id:
					standing.erase("active_case")
			record.investigating_magistrate_id = -1

			# Create MAGISTRATE_CORRUPTION CrimeRecord for the corrupt magistrate
			var corruption_record: CrimeRecord = CrimeSystem.create_crime_record(
				next_case_id[0],
				Enums.CrimeType.MAGISTRATE_CORRUPTION,
				magistrate_id,
				record.location,
				ic_day,
			)
			next_case_id[0] += 1
			crime_records.append(corruption_record)

			var crime_name: String = InvestigationSystem.CRIME_TYPE_NAMES.get(
				record.crime_type, "Crime"
			)
			var secret_about_magistrate: SecretData = SecretSystem.create_secret(
				next_secret_id[0],
				magistrate_id,
				SecretData.Severity.TIER_1,
				"bribe_accepted_%d" % record.case_id,
				"%s accepted a bribe from %s to bury %s investigation" % [
					magistrate.character_name,
					briber.character_name if briber != null else "unknown",
					crime_name,
				],
			)
			next_secret_id[0] += 1
			active_secrets.append(secret_about_magistrate)

			var secret_about_briber: SecretData = SecretSystem.create_secret(
				next_secret_id[0],
				briber_id,
				SecretData.Severity.TIER_1,
				"bribe_offered_%d" % record.case_id,
				"%s bribed %s to suppress %s investigation" % [
					briber.character_name if briber != null else "unknown",
					magistrate.character_name,
					crime_name,
				],
			)
			next_secret_id[0] += 1
			active_secrets.append(secret_about_briber)
			break


static func _apply_failed_bribe_evidence(
	crime_records: Array[CrimeRecord],
	briber_id: int,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	world_states: Dictionary,
	magistrate_id: int = -1,
) -> void:
	for record: CrimeRecord in crime_records:
		if record.perpetrator_id != briber_id:
			continue
		if record.legal_status == Enums.LegalStatus.DECREED_GUILTY:
			continue
		if record.legal_status == Enums.LegalStatus.ACQUITTED:
			continue
		var threshold: String = InvestigationSystem.add_failed_bribe_evidence(record)
		if not threshold.is_empty():
			handle_evidence_threshold(
				threshold, record, characters_by_id,
				active_topics, next_topic_id, ic_day, world_states
			)
		var briber: L5RCharacterData = characters_by_id.get(briber_id)
		var magistrate: L5RCharacterData = characters_by_id.get(magistrate_id)
		if briber != null and magistrate != null:
			var bribery_topic: TopicData = InvestigationSystem.generate_bribery_attempt_topic(
				briber, magistrate, record, next_topic_id, ic_day
			)
			if bribery_topic != null:
				active_topics.append(bribery_topic)
		return


static func _process_flee_jurisdiction_writebacks(
	results: Array,
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		if r.get("action_id", "") != "FLEE_JURISDICTION":
			continue
		if not r.get("success", false):
			continue
		var effects: Dictionary = r.get("effects", {})
		if effects.get("effect", "") != "flee_jurisdiction":
			continue

		var fugitive_id: int = effects.get("fugitive_id", -1)
		var fugitive: L5RCharacterData = characters_by_id.get(fugitive_id)
		if fugitive == null:
			continue

		for record: CrimeRecord in crime_records:
			if record.perpetrator_id != fugitive_id:
				continue
			if record.legal_status == Enums.LegalStatus.DECREED_GUILTY:
				continue
			if record.legal_status == Enums.LegalStatus.ACQUITTED:
				continue
			if record.legal_status == Enums.LegalStatus.FUGITIVE:
				continue
			process_fugitive_declaration(
				record, fugitive, characters_by_id,
				active_topics, next_topic_id, ic_day,
			)
			break


static func _process_extortion_writebacks(
	results: Array,
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	ic_day: int,
	active_secrets: Array[SecretData] = [],
	next_secret_id: Array[int] = [1],
) -> void:
	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		if r.get("action_id", "") != "EXTORT_ACCUSED":
			continue
		if not r.get("success", false):
			continue
		var effects: Dictionary = r.get("effects", {})
		if not effects.get("suppress_case", false):
			continue

		var magistrate_id: int = effects.get("magistrate_id", -1)
		var suspect_id: int = effects.get("suspect_id", -1)
		var magistrate: L5RCharacterData = characters_by_id.get(magistrate_id)
		var suspect: L5RCharacterData = characters_by_id.get(suspect_id)
		if magistrate == null:
			continue

		for record: CrimeRecord in crime_records:
			if record.perpetrator_id != suspect_id:
				continue
			if record.legal_status == Enums.LegalStatus.DECREED_GUILTY:
				continue
			if record.legal_status == Enums.LegalStatus.ACQUITTED:
				continue
			record.legal_status = Enums.LegalStatus.CLEAR
			if suspect != null:
				var entry: LegalCaseEntry = LegalStatusSystem.get_case(suspect, record.case_id)
				if entry != null:
					LegalStatusSystem.transition(entry, Enums.LegalStatus.CLEAR, ic_day)
			HonorGlorySystem.apply_honor_change(magistrate, -1.0)

			var crime_name: String = InvestigationSystem.CRIME_TYPE_NAMES.get(
				record.crime_type, "Crime"
			)
			var secret: SecretData = SecretSystem.create_secret(
				next_secret_id[0],
				magistrate_id,
				SecretData.Severity.TIER_1,
				"extortion_%d" % record.case_id,
				"%s extorted %s to bury %s investigation" % [
					magistrate.character_name,
					suspect.character_name if suspect != null else "unknown",
					crime_name,
				],
			)
			next_secret_id[0] += 1
			active_secrets.append(secret)
			break


# -- PTL Detection (Channel 1, s11.11) -----------------------------------------
# Shugenja investigating a tainted province automatically attempt
# Perception + Lore: Shadowlands vs TN (PTL × 5). Kuni and Asako get +2k0.

static func _process_ptl_detection(
	results: Array,
	characters_by_id: Dictionary,
	provinces: Dictionary,
	character_province_map: Dictionary,
	dice_engine: DiceEngine,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		if r.get("action_id", "") != "INVESTIGATE_PROVINCE":
			continue
		if not r.get("success", false):
			continue

		var char_id: int = r.get("character_id", -1)
		var character: L5RCharacterData = characters_by_id.get(char_id)
		if character == null:
			continue
		if character.school_type != Enums.SchoolType.SHUGENJA:
			continue

		var province_id: int = character_province_map.get(char_id, -1)
		if province_id < 0:
			province_id = r.get("target_province_id", -1)
		var province: ProvinceData = provinces.get(province_id)
		if province == null:
			continue
		if province.province_taint_level <= 0.0:
			continue

		var ptl_tn: int = int(province.province_taint_level * 5.0)
		var perception: int = character.perception if character.perception > 0 else 2
		var lore_rank: int = character.skills.get("Lore: Shadowlands", 0)
		if lore_rank <= 0:
			continue

		var rolled: int = perception + lore_rank
		var kept: int = perception
		if character.family in ["Kuni", "Asako"]:
			rolled += 2

		var roll_result: Dictionary = dice_engine.roll_and_keep(rolled, kept)
		var total: int = roll_result.get("total", 0)
		if total < ptl_tn:
			continue

		var topic: TopicData = _create_ptl_detection_topic(
			character, province, province_id, next_topic_id, ic_day
		)
		if topic != null:
			active_topics.append(topic)
			if character.lord_id >= 0:
				var lord: L5RCharacterData = characters_by_id.get(character.lord_id)
				if lord != null and topic.topic_id not in lord.topic_pool:
					lord.topic_pool.append(topic.topic_id)


static func _create_ptl_detection_topic(
	detector: L5RCharacterData,
	province: ProvinceData,
	province_id: int,
	next_topic_id: Array[int],
	ic_day: int,
) -> TopicData:
	var topic_id: int = next_topic_id[0]
	next_topic_id[0] += 1
	var title: String = "Spiritual corruption detected in %s" % province.province_name
	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id, title,
		TopicData.Tier.TIER_3,
		TopicData.Category.SUPERNATURAL,
		ic_day, 20.0,
		[province_id],
		detector.clan, detector.family,
		detector.character_id,
		"crisis", "ptl_detection",
	)
	topic.slug = "ptl_detection_%d_day%d" % [province_id, ic_day]
	return topic


# -- Blood Evidence Discovery (Channel 2, s57.47.7) ---------------------------
# EXAMINE_CRIME_SCENE on a maho case uses blood_concealment_tn from the
# CrimeRecord. Discovery generates a T3 topic about blood magic evidence.

static func _process_blood_evidence_discovery(
	results: Array,
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	dice_engine: DiceEngine = null,
) -> void:
	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		var action_id: String = r.get("action_id", "")
		if not r.get("success", false):
			continue

		if action_id == "EXAMINE_CRIME_SCENE":
			_check_blood_evidence_from_scene_exam(
				r, crime_records, characters_by_id,
				active_topics, next_topic_id, ic_day,
			)
		elif action_id == "INVESTIGATE_PROVINCE" and dice_engine != null:
			_check_blood_evidence_from_province_investigation(
				r, crime_records, characters_by_id,
				active_topics, next_topic_id, ic_day, dice_engine,
			)


static func _check_blood_evidence_from_scene_exam(
	r: Dictionary,
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	var effects: Dictionary = r.get("effects", {})
	var case_id: int = effects.get("case_id", -1)
	if case_id < 0:
		return

	var record: CrimeRecord = null
	for cr: CrimeRecord in crime_records:
		if cr.case_id == case_id:
			record = cr
			break
	if record == null:
		return
	if record.crime_type != Enums.CrimeType.MAHO:
		return
	if record.concealment_tn <= 0:
		return

	_emit_blood_evidence_topic(
		r.get("character_id", -1), record, characters_by_id,
		active_topics, next_topic_id, ic_day,
	)


static func _check_blood_evidence_from_province_investigation(
	r: Dictionary,
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	dice_engine: DiceEngine,
) -> void:
	var char_id: int = r.get("character_id", -1)
	var character: L5RCharacterData = characters_by_id.get(char_id)
	if character == null:
		return

	var char_location: String = character.physical_location

	for record: CrimeRecord in crime_records:
		if record.crime_type != Enums.CrimeType.MAHO:
			continue
		if record.concealment_tn <= 0:
			continue
		if record.location != char_location:
			continue
		var days_elapsed: int = ic_day - record.ic_day_committed
		if days_elapsed > InvestigationSystem.DAYS_PER_SEASON:
			continue

		var detection_result: Dictionary = InvestigationSystem.detect_blood_evidence(
			character, record, dice_engine, ic_day,
		)
		if detection_result.get("detected", false):
			_emit_blood_evidence_topic(
				char_id, record, characters_by_id,
				active_topics, next_topic_id, ic_day,
			)
			return


static func _emit_blood_evidence_topic(
	investigator_id: int,
	record: CrimeRecord,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	for topic: TopicData in active_topics:
		if topic.slug == "blood_evidence_%d" % record.case_id:
			return

	var investigator: L5RCharacterData = characters_by_id.get(investigator_id)
	if investigator == null:
		return

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] += 1
	var title: String = "Evidence of blood magic discovered in %s" % record.location
	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id, title,
		TopicData.Tier.TIER_3,
		TopicData.Category.SUPERNATURAL,
		ic_day, 25.0,
		[], "", "",
		investigator_id,
		"crisis", "blood_evidence",
	)
	topic.slug = "blood_evidence_%d" % record.case_id
	active_topics.append(topic)

	if investigator.lord_id >= 0:
		var lord: L5RCharacterData = characters_by_id.get(investigator.lord_id)
		if lord != null and topic.topic_id not in lord.topic_pool:
			lord.topic_pool.append(topic.topic_id)


# -- Flee Logistics (s55.29 travel + court removal) ----------------------------
# When FLEE_JURISDICTION fires, the NPC begins travel to a safe location
# and is removed from any active court commitment.

static func _process_flee_logistics(
	results: Array,
	characters_by_id: Dictionary,
	active_courts: Array[CourtSessionData],
	world_states: Dictionary = {},
) -> void:
	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		if r.get("action_id", "") != "FLEE_JURISDICTION":
			continue
		if not r.get("success", false):
			continue
		var effects: Dictionary = r.get("effects", {})
		var fugitive_id: int = effects.get("fugitive_id", -1)
		var fugitive: L5RCharacterData = characters_by_id.get(fugitive_id)
		if fugitive == null:
			continue

		TravelSystem.begin_travel(fugitive, "ronin_haven")

		for court: CourtSessionData in active_courts:
			if fugitive_id in court.attendee_ids:
				court.attendee_ids.erase(fugitive_id)

		if not fugitive.role_position.is_empty() and fugitive.lord_id >= 0:
			var vkey: String = "vacant_positions_%d" % fugitive.lord_id
			var vacancies: Array = world_states.get(vkey, []) as Array
			vacancies.append({
				"position_type": fugitive.role_position,
				"priority": 2,
				"candidate_id": -1,
				"seasons_vacant": 0,
			})
			world_states[vkey] = vacancies
			fugitive.role_position = ""


# -- Witness Tampering Writebacks (s11.3.13c) ----------------------------------

static func _process_witness_tampering_writebacks(
	results: Array,
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	world_states: Dictionary,
	active_secrets: Array[SecretData] = [],
	next_secret_id: Array[int] = [1],
	next_case_id: Array[int] = [1],
	dice_engine: DiceEngine = null,
) -> void:
	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		var action_id: String = r.get("action_id", "")
		if action_id not in ["BRIBE_WITNESS", "INTIMIDATE_WITNESS", "KILL_WITNESS"]:
			continue

		var criminal_id: int = r.get("character_id", -1)
		var witness_id: int = r.get("target_npc_id", -1)
		var effects: Dictionary = r.get("effects", {})
		var success: bool = r.get("success", false)

		for record: CrimeRecord in crime_records:
			if record.perpetrator_id != criminal_id:
				continue
			if witness_id not in record.witnesses:
				continue

			if success:
				record.witnesses.erase(witness_id)
				if action_id == "BRIBE_WITNESS":
					var witness: L5RCharacterData = characters_by_id.get(witness_id)
					var criminal: L5RCharacterData = characters_by_id.get(criminal_id)
					var witness_name: String = witness.character_name if witness != null else "unknown"
					var criminal_name: String = criminal.character_name if criminal != null else "unknown"
					var secret: SecretData = SecretSystem.create_secret(
						next_secret_id[0],
						witness_id,
						SecretData.Severity.TIER_2,
						"bribed_witness_%d" % record.case_id,
						"%s accepted a bribe from %s to stay silent about case %d" % [
							witness_name, criminal_name, record.case_id,
						],
					)
					next_secret_id[0] += 1
					active_secrets.append(secret)
				elif action_id == "INTIMIDATE_WITNESS":
					_apply_intimidation_consequences(
						criminal_id, witness_id, characters_by_id, world_states, record,
					)
				elif action_id == "KILL_WITNESS":
					var kill_concealment: int = effects.get("concealment_tn", 0)
					var victim: L5RCharacterData = characters_by_id.get(witness_id)
					var victim_loc: String = victim.physical_location if victim != null else ""
					var kill_location: String = victim_loc if not victim_loc.is_empty() else record.location
					var kill_witnesses: Array[int] = _get_witnesses_at_location(
						criminal_id, kill_location, characters_by_id, world_states,
					)
					kill_witnesses.erase(witness_id)
					var murder_record: CrimeRecord = CrimeSystem.create_crime_record(
						next_case_id[0],
						Enums.CrimeType.UNSANCTIONED_COVERT_KILLING,
						criminal_id,
						kill_location,
						ic_day,
						witness_id,
						kill_concealment,
						kill_witnesses,
					)
					next_case_id[0] += 1
					crime_records.append(murder_record)
					if victim != null:
						_apply_victim_death(victim, active_topics, next_topic_id, ic_day, kill_location)
					var criminal: L5RCharacterData = characters_by_id.get(criminal_id)
					if criminal != null:
						var murder_topic: TopicData = _create_crime_topic(
							murder_record, criminal, ic_day, next_topic_id,
						)
						if murder_topic != null:
							active_topics.append(murder_topic)
							_seed_crime_topic_to_knowers(murder_topic, murder_record, characters_by_id)
						if dice_engine != null:
							_apply_criminal_recall(
								criminal, murder_record, kill_witnesses, dice_engine, world_states,
							)
			else:
				var evidence_add: int = effects.get("evidence_on_fail", 10)
				record.evidence_total += evidence_add
				var threshold: String = InvestigationSystem.check_thresholds(record)
				if not threshold.is_empty():
					handle_evidence_threshold(
						threshold, record, characters_by_id,
						active_topics, next_topic_id, ic_day, world_states,
					)
				if action_id == "INTIMIDATE_WITNESS":
					_inject_witness_report_event(
						witness_id, criminal_id, record.case_id,
						record.investigating_magistrate_id, world_states,
					)
			break


const INTIMIDATION_DISPOSITION_PENALTY: int = -30

static func _apply_intimidation_consequences(
	criminal_id: int,
	witness_id: int,
	characters_by_id: Dictionary,
	world_states: Dictionary,
	record: CrimeRecord,
) -> void:
	var witness: L5RCharacterData = characters_by_id.get(witness_id)
	if witness != null:
		var old_disp: int = witness.disposition_values.get(criminal_id, 0)
		var new_disp: int = clampi(old_disp + INTIMIDATION_DISPOSITION_PENALTY, -100, 100)
		witness.disposition_values[criminal_id] = new_disp
	var witness_ws: Dictionary = world_states.get(witness_id, {})
	var events: Array = witness_ws.get("pending_events", [])
	events.append({
		"type": "provocation",
		"source_id": criminal_id,
		"case_id": record.case_id,
		"action": "INTIMIDATE_WITNESS",
	})
	witness_ws["pending_events"] = events
	world_states[witness_id] = witness_ws


static func _inject_witness_report_event(
	witness_id: int,
	criminal_id: int,
	case_id: int,
	magistrate_id: int,
	world_states: Dictionary,
) -> void:
	var witness_ws: Dictionary = world_states.get(witness_id, {})
	var events: Array = witness_ws.get("pending_events", [])
	events.append({
		"type": "witness_report_motivated",
		"criminal_id": criminal_id,
		"case_id": case_id,
		"magistrate_id": magistrate_id,
	})
	witness_ws["pending_events"] = events
	world_states[witness_id] = witness_ws


static func _apply_victim_death(
	victim: L5RCharacterData,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	kill_location: String,
) -> void:
	var earth: int = CharacterStats.get_ring_value(victim, Enums.Ring.EARTH)
	victim.wounds_taken = earth * 5 * 5
	var death_topic_id: int = next_topic_id[0]
	next_topic_id[0] = death_topic_id + 1
	var title: String = "Death of %s at %s" % [victim.character_name, kill_location]
	var topic: TopicData = TopicMomentumSystem.create_topic(
		death_topic_id,
		title,
		TopicData.Tier.TIER_3,
		TopicData.Category.LEGAL,
		ic_day,
		0.0,
		[],
		victim.clan,
		"",
		victim.character_id,
		"death",
		"murder",
	)
	topic.slug = "murder_death_%d" % victim.character_id
	active_topics.append(topic)


# -- Witness Report Letter Writebacks ------------------------------------------
# When a witness chooses WRITE_LETTER via witness_report_motivated reactive need,
# create the actual LetterData object carrying the crime topic to the magistrate.

static func _process_witness_report_letter_writebacks(
	results: Array,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	pending_letters: Array,
	ic_day: int,
	dice_engine: DiceEngine,
	next_letter_id: Array[int],
) -> void:
	if dice_engine == null:
		return
	for r: Dictionary in results:
		if r.get("action_id", "") != "WRITE_LETTER":
			continue
		var metadata: Dictionary = r.get("metadata", {})
		var case_id: int = metadata.get("report_case_id", -1)
		if case_id < 0:
			continue
		var sender_id: int = r.get("character_id", -1)
		var recipient_id: int = r.get("target_npc_id", -1)
		if sender_id < 0 or recipient_id < 0:
			continue
		var sender: L5RCharacterData = characters_by_id.get(sender_id)
		if sender == null:
			continue

		var crime_topic_id: int = _find_crime_topic_for_case(sender, case_id, active_topics)
		if crime_topic_id < 0:
			continue

		var lid: int = next_letter_id[0]
		next_letter_id[0] = lid + 1
		var letter: LetterData = LetterSystem.write_letter(
			lid, sender, recipient_id, crime_topic_id, ic_day, dice_engine, 3,
		)
		letter.report_case_id = case_id
		letter.report_criminal_id = metadata.get("report_criminal_id", -1)
		pending_letters.append(letter)


static func _find_crime_topic_for_case(
	character: L5RCharacterData,
	case_id: int,
	active_topics: Array[TopicData],
) -> int:
	for topic_id: int in character.topic_pool:
		for topic: TopicData in active_topics:
			if topic.topic_id != topic_id:
				continue
			if topic.topic_type != "crime":
				continue
			if topic.slug == "crime_case_%d" % case_id:
				return topic_id
	return -1


# -- Zone Log Purge (s11.3.13g) -----------------------------------------------
# After 1 IC season (90 days), physical evidence at crime scenes expires.
# Reset concealment_tn to 0 so it can no longer be discovered.

const ZONE_LOG_PURGE_DAYS: int = 90

static func _purge_expired_crime_evidence(
	crime_records: Array[CrimeRecord],
	ic_day: int,
) -> void:
	for record: CrimeRecord in crime_records:
		if record.concealment_tn <= 0:
			continue
		if ic_day - record.ic_day_committed >= ZONE_LOG_PURGE_DAYS:
			record.concealment_tn = 0


# -- Evidence Decay / Cold Cases (s11.3.13g) -----------------------------------
# Cases that stall without new evidence lose weight over time.
# After EVIDENCE_DECAY_START_DAYS with no progress, 1 evidence point decays
# per EVIDENCE_DECAY_INTERVAL_DAYS. Cases below COLD_CASE_THRESHOLD become
# cold cases (investigating magistrate released). Only affects UNDER_INVESTIGATION
# and SUSPECTED cases — ACCUSED and above are in the sentencing pipeline.

const EVIDENCE_DECAY_START_DAYS: int = 30
const EVIDENCE_DECAY_INTERVAL_DAYS: int = 10
const COLD_CASE_THRESHOLD: int = 5


static func _apply_evidence_decay(
	crime_records: Array[CrimeRecord],
	objectives_map: Dictionary,
	ic_day: int,
) -> Array[Dictionary]:
	var cold_cases: Array[Dictionary] = []

	for record: CrimeRecord in crime_records:
		if record.legal_status != Enums.LegalStatus.UNDER_INVESTIGATION \
				and record.legal_status != Enums.LegalStatus.SUSPECTED:
			continue
		if record.evidence_total <= 0:
			continue

		var days_since: int = ic_day - record.ic_day_committed
		if days_since < EVIDENCE_DECAY_START_DAYS:
			continue

		var decay_days: int = days_since - EVIDENCE_DECAY_START_DAYS
		if decay_days % EVIDENCE_DECAY_INTERVAL_DAYS != 0:
			continue

		record.evidence_total = maxi(0, record.evidence_total - 1)

		if record.evidence_total <= COLD_CASE_THRESHOLD and record.investigating_magistrate_id >= 0:
			var mag_id: int = record.investigating_magistrate_id
			var mag_objs: Dictionary = objectives_map.get(mag_id, {})
			var standing: Dictionary = mag_objs.get("standing", {})
			if standing.get("need_type", "") == "UPHOLD_LAW":
				var active_case: Dictionary = standing.get("active_case", {})
				if active_case.get("case_id", -1) == record.case_id:
					standing.erase("active_case")

			record.investigating_magistrate_id = -1
			cold_cases.append({
				"case_id": record.case_id,
				"magistrate_released": mag_id,
				"remaining_evidence": record.evidence_total,
			})

	return cold_cases


# -- Taint Proximity Detection (Channel 3, s57.47.7) --------------------------
# When a character with Lore: Shadowlands >= 3 (or Kuni/Asako with any rank)
# performs a social action in proximity to a character with Taint Rank >= 2,
# they automatically attempt detection. Success generates a named accusation topic.
# TN for the check is deferred to Section 31/42 — using placeholder TN 20.

const TAINT_DETECTION_PLACEHOLDER_TN: int = 20
const TAINT_RANK_THRESHOLD: float = 2.0

static func _process_taint_proximity_detection(
	results: Array,
	characters_by_id: Dictionary,
	character_province_map: Dictionary,
	dice_engine: DiceEngine,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	var checked_pairs: Dictionary = {}
	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		if not r.get("success", false):
			continue
		var detector_id: int = r.get("character_id", -1)
		var target_id: int = r.get("target_npc_id", -1)
		if detector_id < 0 or target_id < 0:
			continue

		var pair_key: String = "%d_%d" % [detector_id, target_id]
		if checked_pairs.has(pair_key):
			continue
		checked_pairs[pair_key] = true

		var detector: L5RCharacterData = characters_by_id.get(detector_id)
		var target: L5RCharacterData = characters_by_id.get(target_id)
		if detector == null or target == null:
			continue
		if target.taint < TAINT_RANK_THRESHOLD:
			continue

		var lore_rank: int = detector.skills.get("Lore: Shadowlands", 0)
		var is_specialist: bool = detector.family in ["Kuni", "Asako"]
		if lore_rank < 3 and not is_specialist:
			continue

		var perception: int = detector.perception if detector.perception > 0 else 2
		var rolled: int = perception + lore_rank
		var kept: int = perception
		if is_specialist:
			rolled += 2

		var roll_result: Dictionary = dice_engine.roll_and_keep(rolled, kept)
		var total: int = roll_result.get("total", 0)
		if total < TAINT_DETECTION_PLACEHOLDER_TN:
			continue

		var topic_id: int = next_topic_id[0]
		next_topic_id[0] += 1
		var title: String = "%s suspected of Taint corruption" % target.character_name
		var topic: TopicData = TopicMomentumSystem.create_topic(
			topic_id, title,
			TopicData.Tier.TIER_3,
			TopicData.Category.SUPERNATURAL,
			ic_day, 30.0,
			[], target.clan, target.family,
			target.character_id,
			"accusation", "taint_suspected",
		)
		topic.slug = "taint_suspected_%d" % target.character_id
		topic.subject_role = "PERPETRATOR"
		active_topics.append(topic)

		if detector.lord_id >= 0:
			var lord: L5RCharacterData = characters_by_id.get(detector.lord_id)
			if lord != null and topic.topic_id not in lord.topic_pool:
				lord.topic_pool.append(topic.topic_id)


static func _is_character_in_battle(
	_char_id: int,
	_world_states: Dictionary,
) -> bool:
	# Sub-tile military system blocked on world map data (s11.7).
	# When implemented, check active battle engagements at this location.
	return false


static func _did_victim_act_first(
	effects: Dictionary,
	action_id: String,
) -> bool:
	if action_id == "ISSUE_DUEL_CHALLENGE":
		return false
	return effects.get("victim_initiated", false)


static func _has_zone_log_evidence(
	_attacker_id: int,
	_victim_id: int,
	_location: String,
	_action_log: Array[Dictionary],
) -> bool:
	# Zone event log (s29.15.24) is not yet built.
	# When implemented, this will search action_log for entries at the
	# same location showing who acted first.
	return false


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


# -- Crime Type String Mapping -------------------------------------------------

static func _crime_type_to_string(crime_type: int) -> String:
	match crime_type:
		Enums.CrimeType.VIOLENCE:
			return "violence"
		Enums.CrimeType.UNSANCTIONED_OPEN_KILLING, Enums.CrimeType.UNSANCTIONED_COVERT_KILLING:
			return "murder"
		Enums.CrimeType.TREASON:
			return "treason"
		Enums.CrimeType.SKIMMING:
			return "skimming"
		Enums.CrimeType.MAHO:
			return "maho"
		_:
			return "other"


# -- Criminal Recall (s11.3.13c Step 1) ----------------------------------------
# At crime time, the criminal rolls Intelligence vs TN 10 to assess their
# exposure. On success, they become aware of witnesses and evidence risk,
# allowing the NPC engine to prioritize SUPPRESS_INVESTIGATION earlier.

static func _apply_criminal_recall(
	criminal: L5RCharacterData,
	record: CrimeRecord,
	witnesses: Array[int],
	dice_engine: DiceEngine,
	world_states: Dictionary,
) -> void:
	var intelligence: int = criminal.intelligence if criminal.intelligence > 0 else 2
	var recall_result: Dictionary = dice_engine.roll_and_keep(intelligence, intelligence)
	var total: int = recall_result.get("total", 0)
	if total < InvestigationLoopSystem.CRIMINAL_RECALL_TN:
		return

	var ws: Dictionary = world_states.get(criminal.character_id, {})
	ws["criminal_recall"] = {
		"case_id": record.case_id,
		"witness_count": witnesses.size(),
		"aware_of_evidence": true,
	}
	world_states[criminal.character_id] = ws


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


# -- UPHOLD_LAW Standing Objective Assignment (s57.16.9) ----------------------
# Magistrate-role NPCs automatically receive UPHOLD_LAW as their standing
# objective if they don't already have one. This ensures they participate in
# the crime topic scan each tick without requiring explicit lord directives.

const MAGISTRATE_ROLE_POSITIONS: Array = [
	"Clan Magistrate",
	"Emerald Magistrate",
	"Clan Magistrate Commander",
]


static func _assign_magistrate_standing_objectives(
	characters: Array[L5RCharacterData],
	objectives_map: Dictionary,
) -> void:
	for character: L5RCharacterData in characters:
		if character.role_position not in MAGISTRATE_ROLE_POSITIONS:
			continue
		if CharacterStats.is_dead(character):
			continue

		var char_id: int = character.character_id
		if not objectives_map.has(char_id):
			objectives_map[char_id] = {}

		var objectives: Dictionary = objectives_map[char_id]
		var standing: Dictionary = objectives.get("standing", {})

		if standing.get("need_type", "") == "UPHOLD_LAW":
			continue

		if not standing.is_empty():
			continue

		objectives["standing"] = {
			"need_type": "UPHOLD_LAW",
			"priority": 4,
			"auto_assigned": true,
		}


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
		var active_case_count: int = 1 if (standing.has("active_case") and not standing["active_case"].is_empty()) else 0
		if not MagistrateAllocationSystem.is_magistrate_available(active_case_count):
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


static func _generate_investigation_opened_topics(
	uphold_law_results: Array[Dictionary],
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	for result: Dictionary in uphold_law_results:
		var magistrate_id: int = result.get("magistrate_id", -1)
		var case_id: int = result.get("case_id", -1)
		if magistrate_id < 0 or case_id < 0:
			continue
		var magistrate: L5RCharacterData = characters_by_id.get(magistrate_id)
		if magistrate == null:
			continue
		var record: CrimeRecord = null
		for r: CrimeRecord in crime_records:
			if r.case_id == case_id:
				record = r
				break
		if record == null:
			continue
		var topic: TopicData = InvestigationSystem.generate_investigation_opened_topic(
			record, magistrate, next_topic_id, ic_day
		)
		if topic != null:
			active_topics.append(topic)


# -- Witness PROBE Evidence (s11.3.13e) ----------------------------------------

static func _check_witness_evidence(
	prober_id: int,
	target_id: int,
	quality: int,
	crime_records: Array[CrimeRecord],
	objectives_map: Dictionary,
	characters_by_id: Dictionary = {},
	dice_engine: DiceEngine = null,
	characters_present: Array[int] = [] as Array[int],
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

		var result: Dictionary = InvestigationSystem.process_witness_interview(
			record, target_id, quality, active_case
		)

		var alibi_result: Dictionary = _check_alibi_for_target(
			target_id, active_case, record,
			characters_by_id.get(prober_id),
			characters_by_id.get(target_id),
			dice_engine,
		)
		if not alibi_result.is_empty():
			result["alibi_result"] = alibi_result
			var alibi_threshold: String = alibi_result.get("threshold_crossed", "")
			if not alibi_threshold.is_empty() and result.get("threshold_crossed", "").is_empty():
				result["threshold_crossed"] = alibi_threshold

		var leads: Array[Dictionary] = InvestigationSystem.generate_leads_from_probe(
			target_id, quality, record, active_case, characters_present,
		)
		if not leads.is_empty():
			result["leads_generated"] = leads.size()

		return result
	return {}


static func _check_alibi_for_target(
	target_id: int,
	active_case: Dictionary,
	crime_record: CrimeRecord,
	magistrate: L5RCharacterData,
	alibi_witness: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	var alibis: Array = active_case.get("alibis", [])
	for alibi: Variant in alibis:
		if not alibi is Dictionary:
			continue
		var a: Dictionary = alibi as Dictionary
		if a.get("claimed_with", -1) != target_id:
			continue
		var checked: Array = active_case.get("checked_alibis", [])
		if a.get("id", -1) in checked:
			continue
		return InvestigationSystem.check_alibi(
			a, alibi_witness, magistrate, crime_record, active_case, dice_engine,
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


static func _process_operational_death_cascade(
	death_events: Array[Dictionary],
	characters: Array[L5RCharacterData],
) -> Array[int]:
	if death_events.is_empty():
		return []
	var all_cleared: Array[int] = []
	for event: Dictionary in death_events:
		var dead_id: int = event.get("character_id", -1)
		if dead_id < 0:
			continue
		var cleared: Array[int] = OperationalHierarchySystem.clear_subordinates_on_death(
			dead_id, characters
		)
		all_cleared.append_array(cleared)
	return all_cleared


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


static func _build_lord_map(characters: Array[L5RCharacterData]) -> Dictionary:
	var result: Dictionary = {}
	for c: L5RCharacterData in characters:
		if c.lord_id >= 0:
			result[c.character_id] = c.lord_id
	return result


static func _resolve_pending_trials(
	conviction_results: Array[Dictionary],
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	lord_map: Dictionary,
	dice_engine: DiceEngine,
	ic_day: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for conv: Dictionary in conviction_results:
		if conv.get("outcome", "") != "trial_by_combat_pending":
			continue
		var accused_id: int = conv.get("accused_id", -1)
		var case_id: int = conv.get("case_id", -1)
		var accused: L5RCharacterData = characters_by_id.get(accused_id)
		if accused == null:
			continue

		var lord_id: int = lord_map.get(accused_id, -1)
		var lord: L5RCharacterData = characters_by_id.get(lord_id)
		if lord == null:
			continue

		var record: CrimeRecord = null
		for r: CrimeRecord in crime_records:
			if r.case_id == case_id:
				record = r
				break
		if record == null:
			continue

		var trial: Dictionary = ConvictionProcessor.resolve_trial_by_combat(
			record, accused, lord, dice_engine, ic_day, characters_by_id
		)
		trial["case_id"] = case_id
		trial["accused_id"] = accused_id
		results.append(trial)

	return results


static func _process_seppuku_responses(
	conviction_results: Array[Dictionary],
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	ic_day: int,
	next_topic_id: Array[int],
	active_topics: Array[TopicData],
	world_states: Dictionary = {},
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for conviction: Dictionary in conviction_results:
		if conviction.get("outcome", "") != "convicted":
			continue
		if not conviction.get("seppuku_offered", false):
			continue
		var char_id: int = conviction.get("accused_id", -1)
		var character: L5RCharacterData = characters_by_id.get(char_id)
		if character == null:
			continue
		var case_id: int = conviction.get("case_id", -1)
		var record: CrimeRecord = null
		for r: CrimeRecord in crime_records:
			if r.case_id == case_id:
				record = r
				break
		if record == null:
			continue

		# Inject seppuku_offered as a reactive event for next tick
		var ws: Dictionary = world_states.get(char_id, {})
		var pending: Array = ws.get("pending_events", [])
		for ev: Dictionary in pending:
			if ev.get("type", "") == "seppuku_offered" and ev.get("case_id", -1) == case_id:
				break
		else:
			pending.append({
				"type": "seppuku_offered",
				"case_id": case_id,
				"crime_type": record.crime_type,
				"ic_day_offered": ic_day,
			})
			ws["pending_events"] = pending
			world_states[char_id] = ws

		results.append({
			"case_id": case_id,
			"accused_id": char_id,
			"event_injected": true,
		})
	return results


# -- Seppuku Response Writeback (processes ACCEPT/REFUSE_SEPPUKU action results)

static func _process_seppuku_action_writebacks(
	results: Array,
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	ic_day: int,
	next_topic_id: Array[int],
	active_topics: Array[TopicData],
) -> Array[Dictionary]:
	var seppuku_results: Array[Dictionary] = []

	for result: Variant in results:
		if not result is Dictionary:
			continue
		var r: Dictionary = result as Dictionary
		var action_id: String = r.get("action_id", "")
		if action_id not in ["ACCEPT_SEPPUKU", "REFUSE_SEPPUKU"]:
			continue

		var char_id: int = r.get("character_id", -1)
		var character: L5RCharacterData = characters_by_id.get(char_id)
		if character == null:
			continue

		var case_id: int = r.get("effects", {}).get("case_id", -1)
		var record: CrimeRecord = null
		for cr: CrimeRecord in crime_records:
			if cr.case_id == case_id:
				record = cr
				break
		if record == null:
			continue

		var accepted: bool = action_id == "ACCEPT_SEPPUKU"
		var resolution: Dictionary = ConvictionProcessor.resolve_seppuku(
			record, character, accepted, ic_day, next_topic_id
		)

		if resolution.get("applicable", false):
			if not accepted:
				var refusal_topic_id: int = resolution.get("refusal_topic_id", -1)
				if refusal_topic_id >= 0:
					for t: TopicData in active_topics:
						if t.topic_id == refusal_topic_id:
							break
					var lord: L5RCharacterData = characters_by_id.get(character.lord_id)
					if lord != null and refusal_topic_id not in lord.topic_pool:
						lord.topic_pool.append(refusal_topic_id)
			resolution["action_id"] = action_id
			resolution["character_id"] = char_id
			seppuku_results.append(resolution)

	return seppuku_results


# -- Cross-Clan Conviction Consequences (s57.47) ------------------------------
# When a conviction is cross-clan, apply disposition changes between the
# clans involved. Cooperation during investigation may mitigate the hit.

static func _apply_cross_clan_conviction_consequences(
	conviction_results: Array[Dictionary],
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
) -> void:
	for conv: Dictionary in conviction_results:
		if conv.get("outcome", "") != "convicted":
			continue
		if not conv.get("is_cross_clan", false):
			continue

		var case_id: int = conv.get("case_id", -1)
		var accused_id: int = conv.get("accused_id", -1)
		var accused: L5RCharacterData = characters_by_id.get(accused_id)
		if accused == null:
			continue

		var record: CrimeRecord = null
		for r: CrimeRecord in crime_records:
			if r.case_id == case_id:
				record = r
				break
		if record == null:
			continue

		var victim: L5RCharacterData = characters_by_id.get(record.victim_id)
		if victim == null:
			continue

		ConvictionProcessor.apply_cross_clan_consequences(
			record, accused, victim, true
		)


# -- Conviction Topic Seeding to Victim's Lord --------------------------------
# Ensure the victim's lord learns about the conviction for diplomatic follow-up.

static func _seed_conviction_topics_to_victim_lords(
	conviction_results: Array[Dictionary],
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
) -> void:
	for conv: Dictionary in conviction_results:
		if conv.get("outcome", "") != "convicted":
			continue
		var topic_id: int = conv.get("topic_id", -1)
		if topic_id < 0:
			continue

		var case_id: int = conv.get("case_id", -1)
		var record: CrimeRecord = null
		for r: CrimeRecord in crime_records:
			if r.case_id == case_id:
				record = r
				break
		if record == null or record.victim_id < 0:
			continue

		var victim: L5RCharacterData = characters_by_id.get(record.victim_id)
		if victim == null:
			continue

		var victim_lord: L5RCharacterData = characters_by_id.get(victim.lord_id)
		if victim_lord == null:
			continue
		if topic_id in victim_lord.topic_pool:
			continue
		victim_lord.topic_pool.append(topic_id)


# -- Magistrate Release After Conviction/Acquittal ---------------------------

static func _release_magistrate_after_conviction(
	conviction_results: Array[Dictionary],
	crime_records: Array[CrimeRecord],
	objectives_map: Dictionary,
) -> void:
	for conv: Dictionary in conviction_results:
		var outcome: String = conv.get("outcome", "")
		if outcome != "convicted" and outcome != "acquitted":
			continue
		var case_id: int = conv.get("case_id", -1)
		if case_id < 0:
			continue

		var record: CrimeRecord = null
		for r: CrimeRecord in crime_records:
			if r.case_id == case_id:
				record = r
				break
		if record == null:
			continue

		var mag_id: int = record.investigating_magistrate_id
		if mag_id < 0:
			continue

		var mag_objs: Dictionary = objectives_map.get(mag_id, {})
		var standing: Dictionary = mag_objs.get("standing", {})
		if standing.get("need_type", "") == "UPHOLD_LAW":
			var active_case: Dictionary = standing.get("active_case", {})
			if active_case.get("case_id", -1) == case_id:
				standing.erase("active_case")

		record.investigating_magistrate_id = -1


# -- Magistrate Conviction Cascade (s11.3.17e) --------------------------------
# When a magistrate is convicted, suspend all cases they were investigating
# and clear their standing objective's active case.

static func _process_magistrate_conviction_cascade(
	conviction_results: Array[Dictionary],
	crime_records: Array[CrimeRecord],
	characters_by_id: Dictionary,
	objectives_map: Dictionary,
) -> void:
	for conv: Dictionary in conviction_results:
		if conv.get("outcome", "") != "convicted":
			continue
		var case_id: int = conv.get("case_id", -1)
		if case_id < 0:
			continue

		var record: CrimeRecord = null
		for r: CrimeRecord in crime_records:
			if r.case_id == case_id:
				record = r
				break
		if record == null:
			continue

		var perpetrator: L5RCharacterData = characters_by_id.get(record.perpetrator_id)
		if perpetrator == null:
			continue
		if perpetrator.role_position not in MAGISTRATE_ROLE_POSITIONS:
			continue

		var cascade: Dictionary = MagistrateAllocationSystem.resolve_magistrate_conviction(
			perpetrator.character_id, crime_records
		)
		var suspended: Array = cascade.get("suspended_case_ids", [])
		for cr: CrimeRecord in crime_records:
			if cr.case_id in suspended:
				cr.investigating_magistrate_id = -1

		var mag_objs: Dictionary = objectives_map.get(perpetrator.character_id, {})
		var standing: Dictionary = mag_objs.get("standing", {})
		if standing.get("need_type", "") == "UPHOLD_LAW":
			standing.erase("active_case")


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
	var festival_honor: float = FestivalSystem.get_honor_gain_festivals(ic_day)
	var festival_has_lion_honor: bool = "lion_honor" in effects
	var festival_glory_poetry: float = 0.1 if "poetry_exchange" in effects else 0.0
	var festival_glory_martial: float = 0.1 if "martial_glory" in effects else 0.0

	for char_id in world_states:
		if char_id is not int:
			continue
		var ws: Dictionary = world_states[char_id]
		ws["is_ceasefire_day"] = is_ceasefire
		ws["is_labor_halt_day"] = is_labor_halt
		ws["is_taian"] = is_taian
		ws["is_inauspicious_for_social"] = is_inauspicious
		ws["rokuyo"] = rokuyo_name
		ws["festival_honor_gain"] = festival_honor
		ws["festival_has_lion_honor"] = festival_has_lion_honor
		ws["festival_glory_poetry"] = festival_glory_poetry
		ws["festival_glory_martial"] = festival_glory_martial

	return {
		"active_festivals": active_festivals,
		"effects": effects,
		"rokuyo": rokuyo_name,
		"is_taian": is_taian,
		"is_inauspicious": is_inauspicious,
		"is_ceasefire": is_ceasefire,
		"is_labor_halt": is_labor_halt,
		"honor_gain": festival_honor,
		"glory_gain_poetry": festival_glory_poetry,
		"glory_gain_martial": festival_glory_martial,
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
	pending_letters: Array = [],
	ic_day: int = 0,
	dice_engine: DiceEngine = null,
	next_letter_id: Array[int] = [1],
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
			if dice_engine != null:
				var lid: int = next_letter_id[0]
				next_letter_id[0] = lid + 1
				var topic_id: int = letter_result.get("topic_id", -1)
				var letter: LetterData = LetterSystem.write_letter(
					lid, character,
					letter_result["target_npc_id"],
					topic_id, ic_day, dice_engine,
					3,
				)
				pending_letters.append(letter)
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


# -- Witness Testimony on Arrival (s57.16 — witness reaches magistrate) --------
# When a witness who traveled via BEGIN_TRAVEL (witness_report_motivated) arrives
# at the magistrate's location, directly transfer the crime topic.

static func _capture_witness_travel_intent(
	results: Array,
	world_states: Dictionary,
) -> void:
	for r: Dictionary in results:
		if r.get("action_id", "") != "BEGIN_TRAVEL":
			continue
		var metadata: Dictionary = r.get("metadata", {})
		var mag_id: int = metadata.get("seek_magistrate_id", -1)
		if mag_id < 0:
			continue
		var char_id: int = r.get("character_id", -1)
		if char_id < 0:
			continue
		var ws: Dictionary = world_states.get(char_id, {})
		ws["witness_travel_intent"] = {
			"magistrate_id": mag_id,
			"destination": metadata.get("destination", ""),
		}
		world_states[char_id] = ws


static func _process_witness_testimony_on_arrival(
	arrivals: Array[Dictionary],
	characters_by_id: Dictionary,
	world_states: Dictionary,
	active_topics: Array[TopicData],
	current_season: int,
) -> void:
	for arrival: Dictionary in arrivals:
		var char_id: int = arrival.get("character_id", -1)
		var dest: String = arrival.get("destination", "")
		if char_id < 0 or dest.is_empty():
			continue

		var ws: Dictionary = world_states.get(char_id, {})
		var intent: Dictionary = ws.get("witness_travel_intent", {})
		if intent.is_empty():
			continue

		var mag_id: int = intent.get("magistrate_id", -1)
		var magistrate: L5RCharacterData = characters_by_id.get(mag_id)
		if magistrate == null or magistrate.physical_location != dest:
			continue

		var witness: L5RCharacterData = characters_by_id.get(char_id)
		if witness == null:
			continue

		for topic_id: int in witness.topic_pool:
			for topic: TopicData in active_topics:
				if topic.topic_id != topic_id:
					continue
				if topic.topic_type != "crime":
					continue
				if topic_id not in magistrate.topic_pool:
					magistrate.topic_pool.append(topic_id)
					InformationSystem.add_knowledge(magistrate, InformationSystem.make_entry(
						Enums.KnowledgeSource.TESTIMONY,
						"topic_learned",
						{
							"topic": topic_id,
							"from_character_id": char_id,
						},
						current_season,
					))

		ws.erase("witness_travel_intent")
		world_states[char_id] = ws


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
	season_meta: Dictionary = {},
) -> Dictionary:
	var ptls: Dictionary = {}
	for pid: int in provinces:
		var prov: ProvinceData = provinces[pid]
		ptls[pid] = prov.province_taint_level

	var patrolled: Dictionary = season_meta.get("patrolled_provinces", {})
	var per_province_ws: Dictionary = {}
	for pid: int in provinces:
		var ws: Dictionary = world_states.get(pid, {}).duplicate()
		if patrolled.has(pid):
			ws["is_patrolled"] = true
		per_province_ws[pid] = ws

	var result: Dictionary = InsurgencySystem.process_season(
		insurgencies, provinces, ptls, dice_engine, current_season,
		next_insurgency_id[0], per_province_ws, worship_maluses,
	)

	for new_ins: InsurgencyData in result.get("new_insurgencies", []):
		insurgencies.append(new_ins)

	next_insurgency_id[0] = result.get("next_id", next_insurgency_id[0])

	for ins: InsurgencyData in insurgencies:
		if patrolled.has(ins.province_id) and not ins.detected:
			ins.concealment = maxi(ins.concealment - 1, 0)
			if ins.concealment <= 0:
				ins.detected = true

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


# -- Hostage System Processing (s22.9) ----------------------------------------

const _ESCAPE_BASE_GARRISON: Dictionary = {
	"town": 0.5,
	"castle": 1.0,
	"major_castle": 2.0,
}

static func _settlement_escape_key(stype: Enums.SettlementType) -> String:
	if stype == Enums.SettlementType.FAMILY_CASTLE:
		return "major_castle"
	if stype in [Enums.SettlementType.CASTLE, Enums.SettlementType.KEEP, Enums.SettlementType.FORTIFICATION]:
		return "castle"
	return "town"


static func _process_hostage_escapes(
	active_hostages: Array[Dictionary],
	characters_by_id: Dictionary,
	settlements: Array[SettlementData],
	dice_engine: DiceEngine,
	ic_day: int,
	death_events: Array[Dictionary],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for hostage: Dictionary in active_hostages:
		if hostage.get("released", false) or hostage.get("escaped", false):
			continue
		var char_id: int = hostage.get("character_id", -1)
		var character: L5RCharacterData = characters_by_id.get(char_id) as L5RCharacterData
		if character == null or CharacterStats.is_dead(character):
			continue
		var stealth_rank: int = character.skills.get("Stealth", 0)
		if not HostageSystem.can_attempt_escape(
			character.bushido_virtue, character.shourido_virtue,
			character.school_type, stealth_rank,
		):
			continue
		var settlement_id_str: String = hostage.get("settlement_id", "")
		var settlement: SettlementData = null
		for s: SettlementData in settlements:
			if str(s.settlement_id) == settlement_id_str:
				settlement = s
				break
		if settlement == null:
			continue
		var escape_key: String = _settlement_escape_key(settlement.settlement_type)
		var base_pu: float = _ESCAPE_BASE_GARRISON.get(escape_key, 1.0)
		var tn: int = HostageSystem.get_escape_tn(escape_key, float(settlement.garrison_pu), base_pu)
		var roll_result: Dictionary = SkillResolver.resolve_skill_check(character, dice_engine, "Stealth", tn)
		var escape_result: Dictionary = HostageSystem.resolve_escape(roll_result.get("total", 0), tn)
		if escape_result["success"]:
			character.captive_status = ""
			hostage["escaped"] = true
		elif escape_result.get("executed", false):
			var lethal: int = CharacterStats.get_ring_value(character, Enums.Ring.EARTH) * 5 * 5
			character.wounds_taken = lethal
			character.captive_status = ""
			death_events.append({
				"character_id": char_id,
				"is_lord": character.role_position != "",
				"cause": "hostage_execution",
				"captor_id": hostage.get("captor_id", -1),
				"critical_failure": escape_result.get("critical_failure", false),
				"ic_day": ic_day,
			})
		results.append({
			"character_id": char_id,
			"success": escape_result["success"],
			"executed": escape_result.get("executed", false),
			"critical_failure": escape_result.get("critical_failure", false),
			"family_honor_loss": escape_result.get("family_honor_loss", 0.0),
			"settlement_id": settlement_id_str,
		})
	return results


static func _release_war_hostages(
	war_termination_results: Array[Dictionary],
	active_hostages: Array[Dictionary],
	characters_by_id: Dictionary,
	ic_day: int,
) -> void:
	for resolution: Dictionary in war_termination_results:
		if resolution.get("resolution", "").is_empty():
			continue
		var clan_a: String = resolution.get("winner_clan",
			resolution.get("proposing_clan", resolution.get("clan_a", "")))
		var clan_b: String = resolution.get("loser_clan",
			resolution.get("receiving_clan", resolution.get("clan_b", "")))
		if clan_a.is_empty() or clan_b.is_empty():
			continue
		for hostage: Dictionary in active_hostages:
			if hostage.get("released", false) or hostage.get("escaped", false):
				continue
			var char_id: int = hostage.get("character_id", -1)
			var character: L5RCharacterData = characters_by_id.get(char_id) as L5RCharacterData
			if character == null:
				continue
			if character.clan == clan_a or character.clan == clan_b:
				HostageSystem.release_hostage(hostage, ic_day)
				character.captive_status = ""


static func _capture_dead_commanders(
	battle_result: Dictionary,
	victor: String,
	captor_lord_id: int,
	location_str: String,
	characters_by_id: Dictionary,
	active_hostages: Array[Dictionary],
	ic_day: int,
	dice_engine: DiceEngine,
) -> void:
	if victor == "draw" or captor_lord_id < 0:
		return
	var losing_side: String = "defender" if victor == "attacker" else "attacker"
	var losing_states: Array = battle_result.get(losing_side + "_states", [])
	for bs: Variant in losing_states:
		if not (bs is Dictionary):
			continue
		var bsd: Dictionary = bs
		if not bsd.get("commander_dead", false):
			continue
		var cmd_id: int = bsd.get("commander_id", -1)
		if cmd_id < 0:
			continue
		var commander: L5RCharacterData = characters_by_id.get(cmd_id) as L5RCharacterData
		if commander == null or commander.captive_status != "":
			continue
		var likelihood: float = HostageSystem.get_capture_likelihood_modifier(
			commander.bushido_virtue, commander.shourido_virtue,
		)
		var captured: bool = (
			likelihood >= 1.0
			or dice_engine.rand_int_range(1, 100) <= int(likelihood * 100.0)
		)
		if captured:
			bsd["commander_dead"] = false
			commander.captive_status = str(captor_lord_id)
			active_hostages.append(HostageSystem.capture_hostage(
				cmd_id, captor_lord_id, HostageSystem.CaptureSource.BATTLE_CAPTURE,
				location_str, ic_day,
			))


static func _capture_siege_hostages(
	active_sieges: Array[Dictionary],
	characters_by_id: Dictionary,
	companies: Array[Dictionary],
	active_hostages: Array[Dictionary],
	ic_day: int,
) -> void:
	var end_reasons: Array[String] = ["storm_assault_success", "starvation"]
	for siege: Dictionary in active_sieges:
		if not siege.get("siege_ended", false):
			continue
		if siege.get("end_reason", "") not in end_reasons:
			continue
		if siege.get("hostages_captured", false):
			continue
		siege["hostages_captured"] = true
		var settlement_id: int = siege.get("settlement_id", -1)
		var atk_army_id: int = siege.get("attacker_army_id", -1)
		var captor_lord_id: int = -1
		for cd: Dictionary in companies:
			if cd.get("army_id", -1) == atk_army_id:
				captor_lord_id = cd.get("lord_id", -1)
				break
		if captor_lord_id < 0:
			continue
		var loc_str: String = str(settlement_id)
		for char_val: Variant in characters_by_id.values():
			var character: L5RCharacterData = char_val as L5RCharacterData
			if character == null:
				continue
			if CharacterStats.is_dead(character):
				continue
			if TravelSystem.is_traveling(character):
				continue
			if character.captive_status != "":
				continue
			if character.physical_location != loc_str:
				continue
			if character.military_rank == Enums.MilitaryRank.NONE:
				continue
			character.captive_status = str(captor_lord_id)
			active_hostages.append(HostageSystem.capture_hostage(
				character.character_id, captor_lord_id,
				HostageSystem.CaptureSource.SIEGE_SURRENDER, loc_str, ic_day,
			))


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
	active_wars: Array[WarData] = [],
	characters_by_id: Dictionary = {},
	provinces: Dictionary = {},
	active_hostages: Array[Dictionary] = [],
	ic_day: int = 0,
) -> Dictionary:
	var disband_results: Array[Dictionary] = _process_disbands(
		active_armies, companies, settlements,
	)
	var movement_results: Array[Dictionary] = _process_army_movements(active_armies)
	var battle_results: Array[Dictionary] = _resolve_army_battles(
		movement_results, active_armies, companies, active_wars,
		dice_engine, settlements, characters_by_id, worship_maluses,
		provinces, active_hostages, ic_day,
	)
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
		"battle_results": battle_results,
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


static func _resolve_army_battles(
	movement_results: Array[Dictionary],
	active_armies: Array[Dictionary],
	companies: Array[Dictionary],
	active_wars: Array[WarData],
	dice_engine: DiceEngine,
	settlements: Array[SettlementData],
	characters_by_id: Dictionary,
	worship_maluses: Dictionary,
	provinces: Dictionary = {},
	active_hostages: Array[Dictionary] = [],
	ic_day: int = 0,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []

	for mr: Dictionary in movement_results:
		var bc: Dictionary = mr.get("battle_check", {})
		if not bc.get("battle_triggered", false):
			continue

		var arriving_army_id: int = mr.get("army_id", -1)
		var arriving_army: Dictionary = _find_army_by_id(arriving_army_id, active_armies)
		if arriving_army.is_empty():
			push_warning("[Battle] Skipped: army %d not found in active_armies" % arriving_army_id)
			continue

		var enemy_army_ids: Array = bc.get("enemy_army_ids", [])
		if enemy_army_ids.is_empty():
			push_warning("[Battle] Skipped: no enemy army IDs for army %d" % arriving_army_id)
			continue

		var attacker_clan: String = arriving_army.get(
			"owning_clan", arriving_army.get("clan_name", ""),
		)
		if attacker_clan.is_empty():
			push_warning("[Battle] Skipped: army %d has no clan" % arriving_army_id)
			continue

		var first_enemy: Dictionary = _find_army_by_id(enemy_army_ids[0], active_armies)
		var defender_clan: String = first_enemy.get(
			"owning_clan", first_enemy.get("clan_name", ""),
		)
		if not WarSystem.are_clans_at_war(active_wars, attacker_clan, defender_clan):
			continue

		var atk_company_dicts: Array[Dictionary] = _get_army_companies(
			arriving_army_id, companies,
		)
		var def_company_dicts: Array[Dictionary] = []
		for eid: Variant in enemy_army_ids:
			if eid is int:
				def_company_dicts.append_array(_get_army_companies(eid, companies))

		if atk_company_dicts.is_empty() or def_company_dicts.is_empty():
			push_warning("[Battle] Skipped: army %d has %d companies, defenders have %d" % [
				arriving_army_id, atk_company_dicts.size(), def_company_dicts.size(),
			])
			continue

		var atk_states: Array[Dictionary] = _build_battle_states(
			atk_company_dicts, "attacker", characters_by_id,
		)
		var def_states: Array[Dictionary] = _build_battle_states(
			def_company_dicts, "defender", characters_by_id,
		)

		var battle_province_id: int = arriving_army.get("province_id", -1)
		var battle_terrain: Enums.BattleTerrainType = _get_battle_terrain(
			battle_province_id, provinces, settlements,
		)
		var fort_bonus: int = _get_fortification_bonus(
			battle_province_id, defender_clan, settlements, provinces,
		)

		var battle_result: Dictionary = resolve_and_reconcile_battle(
			atk_states, def_states, battle_terrain,
			dice_engine, settlements, false, fort_bonus, worship_maluses,
		)

		var field_victor: String = battle_result.get("victor", "draw")
		var field_captor_lord_id: int = -1
		if field_victor == "attacker" and not atk_company_dicts.is_empty():
			field_captor_lord_id = atk_company_dicts[0].get("lord_id", -1)
		elif field_victor == "defender" and not def_company_dicts.is_empty():
			field_captor_lord_id = def_company_dicts[0].get("lord_id", -1)
		_capture_dead_commanders(
			battle_result, field_victor, field_captor_lord_id,
			str(battle_province_id), characters_by_id, active_hostages, ic_day, dice_engine,
		)

		_write_battle_results_to_companies(battle_result, companies)

		battle_result["attacker_army_id"] = arriving_army_id
		battle_result["defender_army_ids"] = enemy_army_ids
		battle_result["attacker_clan"] = attacker_clan
		battle_result["defender_clan"] = defender_clan
		mr["battle_resolved"] = true
		mr["company_count"] = atk_company_dicts.size() + def_company_dicts.size()
		results.append(battle_result)

	return results


static func _get_army_companies(
	army_id: int,
	companies: Array[Dictionary],
) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for c: Dictionary in companies:
		if c.get("army_id", -1) == army_id:
			result.append(c)
	return result


static func _build_battle_states(
	company_dicts: Array[Dictionary],
	side: String,
	characters_by_id: Dictionary,
) -> Array[Dictionary]:
	var states: Array[Dictionary] = []
	var col: int = 0
	for cd: Dictionary in company_dicts:
		var company_data: MilitaryUnitData.CompanyData = _company_dict_to_data(cd)
		var commander: L5RCharacterData = null
		var commander_bonus: Dictionary = {}
		var cmd_id: int = cd.get("commander_id", -1)
		if cmd_id >= 0 and characters_by_id.has(cmd_id):
			commander = characters_by_id[cmd_id]
			commander_bonus = _compute_captain_bonus(commander)
		var ut: int = cd.get("unit_type", Enums.CompanyUnitType.PEASANT_LEVY)
		var row: int = 1
		if ut == Enums.CompanyUnitType.ASHIGARU_ARCHERS and col > 0:
			row = 2
		states.append(ArmyCombatSystem.make_battle_company(
			company_data, row, col, side, commander, commander_bonus,
		))
		col += 1
	return states


const _TERRAIN_TO_BATTLE_TERRAIN: Dictionary = {
	Enums.TerrainType.PLAINS: Enums.BattleTerrainType.PLAINS,
	Enums.TerrainType.RIVER_DELTA: Enums.BattleTerrainType.PLAINS,
	Enums.TerrainType.FOREST: Enums.BattleTerrainType.FOREST,
	Enums.TerrainType.HILLS: Enums.BattleTerrainType.HILLS,
	Enums.TerrainType.MOUNTAINS: Enums.BattleTerrainType.MOUNTAIN,
}

const FORTIFICATION_DEFENSE_BONUS: int = 5


static func _get_battle_terrain(
	province_id: int,
	provinces: Dictionary,
	settlements: Array[SettlementData],
) -> Enums.BattleTerrainType:
	for s: SettlementData in settlements:
		if s.province_id == province_id:
			if s.settlement_type in [
				Enums.SettlementType.TOWN,
				Enums.SettlementType.CITY,
				Enums.SettlementType.IMPERIAL_CAPITAL,
			]:
				return Enums.BattleTerrainType.URBAN
	if provinces.has(province_id):
		var prov: ProvinceData = provinces[province_id]
		return _TERRAIN_TO_BATTLE_TERRAIN.get(
			prov.terrain_type, Enums.BattleTerrainType.PLAINS,
		)
	return Enums.BattleTerrainType.PLAINS


static func _get_fortification_bonus(
	province_id: int,
	defender_clan: String,
	settlements: Array[SettlementData],
	provinces: Dictionary = {},
) -> int:
	if provinces.has(province_id):
		var prov: ProvinceData = provinces[province_id]
		if prov.clan != defender_clan:
			return 0
	for s: SettlementData in settlements:
		if s.province_id == province_id and s.is_military():
			return FORTIFICATION_DEFENSE_BONUS
	return 0


static func _company_dict_to_data(cd: Dictionary) -> MilitaryUnitData.CompanyData:
	var c: MilitaryUnitData.CompanyData = MilitaryUnitData.CompanyData.new()
	c.company_id = cd.get("company_id", -1)
	c.unit_type = cd.get("unit_type", Enums.CompanyUnitType.PEASANT_LEVY)
	c.commander_id = cd.get("commander_id", -1)
	c.source_province_id = cd.get("source_province_id", -1)
	var stats: Dictionary = ArmyCombatSystem.UNIT_STATS.get(c.unit_type, {})
	c.health = cd.get("current_health", stats.get("health", 153))
	c.attack = stats.get("attack", 0)
	c.defense = stats.get("defense", 0)
	c.morale = cd.get("current_morale", stats.get("morale", 10))
	c.morale_defense = stats.get("morale_defense", 0)
	return c


static func _write_battle_results_to_companies(
	battle_result: Dictionary,
	companies: Array[Dictionary],
) -> void:
	var all_states: Array = []
	all_states.append_array(battle_result.get("attacker_states", []))
	all_states.append_array(battle_result.get("defender_states", []))

	for bs: Variant in all_states:
		if not (bs is Dictionary):
			continue
		var bsd: Dictionary = bs
		var cid: int = bsd.get("company_id", -1)
		if cid < 0:
			continue
		for cd: Dictionary in companies:
			if cd.get("company_id", -1) == cid:
				cd["current_health"] = maxi(bsd.get("current_health", 0), 0)
				cd["current_morale"] = maxi(bsd.get("current_morale", 0), 0)
				if bsd.get("is_destroyed", false):
					cd["is_destroyed"] = true
				if bsd.get("is_routed", false):
					cd["is_routed"] = true
				if bsd.get("commander_dead", false):
					cd["commander_dead"] = true
					cd["commander_id"] = -1
				break


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


static func _process_levy_suspicion(
	companies: Array[Dictionary],
	active_wars: Array[WarData],
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	season_count: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var war_clans: Dictionary = {}
	for w: WarData in active_wars:
		war_clans[w.clan_a] = true
		war_clans[w.clan_b] = true
		for ac: String in w.allied_clans_a:
			war_clans[ac] = true
		for ac: String in w.allied_clans_b:
			war_clans[ac] = true

	var lords_checked: Dictionary = {}
	for company: Dictionary in companies:
		if company.get("destroyed", false):
			continue
		if company.get("army_id", -1) >= 0:
			continue
		var lord_id: int = company.get("lord_id", -1)
		if lord_id < 0 or lord_id in lords_checked:
			continue
		lords_checked[lord_id] = true

		var lord: L5RCharacterData = characters_by_id.get(lord_id)
		if lord == null:
			continue

		var is_wartime: bool = lord.clan in war_clans
		var raised_season: int = company.get("levy_raised_season", season_count)
		var seasons_maintained: int = season_count - raised_season

		var check: Dictionary = LevySystem.check_suspicion(seasons_maintained, is_wartime)
		if not check.get("suspicion", false):
			continue

		var tid: int = next_topic_id[0]
		next_topic_id[0] += 1
		var tier_val: int = check["topic_tier"]
		var tier: TopicData.Tier = TopicData.Tier.TIER_4 if tier_val == 4 else TopicData.Tier.TIER_3
		var momentum: float = TopicMomentumSystem.initial_momentum_for_tier(tier)
		var topic: TopicData = TopicMomentumSystem.create_topic(
			tid,
			"Private Army Suspicion — %s" % lord.family,
			tier,
			TopicData.Category.POLITICAL,
			ic_day,
			momentum,
			[],
			"",
			lord.clan,
			-1,
			"private_army",
			"suspicion",
		)
		topic.slug = "private_army_%d_season_%d" % [lord_id, season_count]
		active_topics.append(topic)

		# Apply disposition penalty to Family Daimyo and Clan Champion (s11.7a).
		# Neighboring Provincial Daimyo deferred — requires coordinate system.
		var disposition_penalty: int = check.get("disposition_loss_lord", 0)
		if disposition_penalty != 0:
			var penalized_ids: Dictionary = {}
			var family_daimyo: L5RCharacterData = (
				characters_by_id.get(lord.lord_id) if lord.lord_id >= 0 else null
			)
			if family_daimyo != null:
				var cur_fd: int = family_daimyo.disposition_values.get(lord_id, 0)
				family_daimyo.disposition_values[lord_id] = clampi(
					cur_fd + disposition_penalty, -100, 100,
				)
				penalized_ids[family_daimyo.character_id] = true
			for cid2: int in characters_by_id:
				var ch2: L5RCharacterData = characters_by_id[cid2]
				if ch2.clan != lord.clan:
					continue
				if CivilianOrderBudget.lord_rank_from_status(ch2.status) != Enums.LordRank.CLAN_CHAMPION:
					continue
				if ch2.character_id in penalized_ids:
					break
				var cur_ch: int = ch2.disposition_values.get(lord_id, 0)
				ch2.disposition_values[lord_id] = clampi(
					cur_ch + disposition_penalty, -100, 100,
				)
				break

		results.append({
			"lord_id": lord_id,
			"clan": lord.clan,
			"seasons_maintained": seasons_maintained,
			"topic_tier": tier_val,
			"disposition_loss_lord": check.get("disposition_loss_lord", 0),
			"disposition_loss_neighbor": check.get("disposition_loss_neighbor", 0),
			"escalated": check.get("escalated", false),
			"topic_id": tid,
		})

	return results


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
			clan_companies, iron_state, clan.iron_stockpile,
		)
		clan.iron_stockpile = maxf(clan.iron_stockpile - r["iron_consumed"], 0.0)
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
	provinces: Dictionary = {},
	next_company_id: Array[int] = [1],
	clans: Dictionary = {},
	season_count: int = 0,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var settlements_by_province: Dictionary = _build_settlements_by_province(settlements)

	for applied: Dictionary in applied_list:
		var effects: Dictionary = applied.get("effects", {})

		if effects.get("requires_levy_pu", false):
			var r: Dictionary = _apply_levy_pu_effect(
				applied, settlements, companies, next_company_id,
				characters_by_id, clans, season_count,
			)
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

		if effects.get("requires_garrison_assignment", false):
			var r: Dictionary = _apply_garrison_assignment(
				applied, characters_by_id, settlements, provinces,
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


# -- Dragon Schism: High House of Light siege detection (s55.10.2.8) -----------
# Checks daily siege results for an attacker_victory on the High House of Light.
# Fires TogashiOversight.assault_high_house() and applies honor/disposition effects.
# Called once per daily tick before Togashi is already off the map.

static func _check_dragon_schism_siege_events(
	military_daily: Dictionary,
	togashi_state: Dictionary,
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	settlements: Array[SettlementData],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> Dictionary:
	var siege_results: Array = military_daily.get("siege_results", [])
	for sr: Variant in siege_results:
		if not (sr is Dictionary):
			continue
		var sd: Dictionary = sr
		if sd.get("resolved", "") != "attacker_victory":
			continue
		if sd.get("attacker_clan", "") != "Dragon":
			continue

		var target_id: int = int(sd.get("settlement_id", -1))
		var target_settlement: SettlementData = null
		for s: SettlementData in settlements:
			if s.settlement_id == target_id:
				target_settlement = s
				break
		if target_settlement == null or target_settlement.settlement_name != "High House of Light":
			continue

		var mirumoto_fc: L5RCharacterData = _find_mirumoto_fc(characters)
		var fc_id: int = mirumoto_fc.character_id if mirumoto_fc != null else -1
		var togashi_char_id: int = _find_togashi_id(characters)
		var togashi_char: L5RCharacterData = characters_by_id.get(togashi_char_id)

		var assault_result: Dictionary = TogashiOversight.assault_high_house(
			togashi_state, togashi_char, next_topic_id[0], ic_day, fc_id,
		)
		next_topic_id[0] += 1

		# Apply Honor cost to the FC (s55.10.2.8).
		if mirumoto_fc != null:
			HonorGlorySystem.apply_honor_change(mirumoto_fc, float(assault_result.get("honor_change", 0.0)))

		# Apply empire-wide disposition penalty to all status-5+ clan representatives.
		var disp_change: int = int(assault_result.get("empire_disposition_change", 0))
		if disp_change != 0 and fc_id >= 0:
			for c: L5RCharacterData in characters:
				if c.status < 5.0:
					continue
				if c.clan == "Dragon":
					continue
				var cur: int = c.disposition_values.get(fc_id, 0)
				c.disposition_values[fc_id] = clampi(cur + disp_change, -100, 100)

		# Inject topic.
		var topic_obj: TopicData = assault_result.get("topic")
		if topic_obj != null:
			active_topics.append(topic_obj)

		assault_result.erase("topic")
		assault_result["settlement_id"] = target_id
		assault_result["event"] = "high_house_assault"
		return assault_result

	return {}


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
			clan_iron = clan_data.iron_stockpile

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
		var province_has_forge: bool = false
		for s: SettlementData in settlements:
			if s.province_id == pd.province_id and s.has_infrastructure("forge"):
				province_has_forge = true
				break
		result.append({
			"province_id": pd.province_id,
			"distance": 1,
			"rice_per_pu": rice_per_pu,
			"has_forge": province_has_forge,
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


static func _inject_urgency_data(
	world_states: Dictionary,
	characters: Array[L5RCharacterData],
	favors: Array,
	active_tethers: Array[Dictionary],
	active_sieges: Array[Dictionary],
	objectives_map: Dictionary,
	active_topics: Array[TopicData],
) -> void:
	var besieged_settlements: Dictionary = {}
	for siege: Dictionary in active_sieges:
		if siege.get("siege_ended", false):
			continue
		var sid: int = siege.get("settlement_id", -1)
		if sid >= 0:
			if siege.get("garrison_starved", false):
				besieged_settlements[sid] = 0.0
			else:
				var rice: float = siege.get("rice_stockpile", 1.0)
				var pu: float = siege.get("garrison_pu", 1.0) + siege.get("civilian_pu", 0.0)
				var rice_per_pu: float = rice / maxf(pu, 0.01)
				besieged_settlements[sid] = clampf(rice_per_pu, 0.0, 1.0)

	var location_characters: Dictionary = {}
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if TravelSystem.is_traveling(c):
			continue
		var loc: String = c.physical_location
		if loc.is_empty():
			continue
		if not location_characters.has(loc):
			location_characters[loc] = [] as Array[int]
		location_characters[loc].append(c.character_id)
	world_states["_location_characters"] = location_characters

	for c: L5RCharacterData in characters:
		var ws: Dictionary = world_states.get(c.character_id, {})
		if ws.is_empty():
			ws = {}
			world_states[c.character_id] = ws
		ws["favors"] = favors
		ws["active_tethers"] = active_tethers
		ws["active_topics"] = active_topics
		var char_objs: Dictionary = objectives_map.get(c.character_id, {})
		var primary: Dictionary = char_objs.get("primary", {})
		ws["objective_stalled_seasons"] = primary.get("seasons_without_progress", 0)
		var standing: Dictionary = char_objs.get("standing", {})
		var known_objs: Dictionary = ws.get("known_objectives", {})
		if not standing.is_empty():
			known_objs["standing_need_type"] = standing.get("need_type", "")
		var active_case: Dictionary = standing.get("active_case", primary.get("active_case", {}))
		if not active_case.is_empty():
			known_objs["active_case"] = active_case
		ws["known_objectives"] = known_objs
		var loc: int = int(c.physical_location) if c.physical_location.is_valid_int() else -1
		if besieged_settlements.has(loc):
			ws["besieged_settlement_health_pct"] = besieged_settlements[loc]
		else:
			ws["besieged_settlement_health_pct"] = 1.0
		var char_loc: String = c.physical_location
		var present: Array[int] = location_characters.get(char_loc, [] as Array[int])
		var others: Array[int] = []
		for pid: int in present:
			if pid != c.character_id:
				others.append(pid)
		ws["characters_present"] = others


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
	topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(topic.tier)
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
	var momentum: float = _COMBAT_EVENT_MOMENTUM

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
		ic_day, TopicMomentumSystem.initial_momentum_for_tier(TopicData.Tier.TIER_3), provinces, "", "", -1,
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
		ic_day, TopicMomentumSystem.initial_momentum_for_tier(TopicData.Tier.TIER_4), [], "", "", -1,
		"siege", event_type,
	)
	topic.slug = "siege_%d_event_%s_day_%d" % [siege_id, event_type, ic_day]
	return topic


static func _apply_levy_pu_effect(
	applied: Dictionary,
	settlements: Array[SettlementData],
	companies: Array[Dictionary] = [],
	next_company_id: Array[int] = [1],
	characters_by_id: Dictionary = {},
	clans: Dictionary = {},
	season_count: int = 0,
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

	var effects: Dictionary = applied.get("effects", {})
	var unit_type: int = effects.get("levy_unit_type", Enums.CompanyUnitType.ASHIGARU_SPEARMEN)

	var can_raise: Dictionary = LevySystem.can_raise_levy(
		target_settlement.military_pu,
		target_settlement.garrison_pu,
		unit_type,
	)
	if not can_raise.get("can_raise", false):
		return {
			"type": "levy_failed",
			"character_id": applied.get("character_id", -1),
			"province_id": province_id,
			"reason": can_raise.get("reason", "unknown"),
		}

	var r: Dictionary = PUReconciliation.consume_levy_pu(target_settlement)

	var lord_id: int = applied.get("character_id", -1)

	var cid: int = next_company_id[0]
	next_company_id[0] += 1

	var levy_result: Dictionary = LevySystem.raise_levy(
		cid, unit_type, lord_id, province_id, target_settlement.settlement_id,
	)

	var arms_cost: float = levy_result.get("arms_cost", 0.0)
	var arms_deducted: float = 0.0

	if levy_result.get("success", false) and arms_cost > 0.0:
		var lord_char: L5RCharacterData = characters_by_id.get(lord_id)
		if lord_char != null:
			var clan_data: ClanData = clans.get(lord_char.clan)
			if clan_data != null:
				arms_deducted = minf(arms_cost, clan_data.arms_stockpile)
				clan_data.arms_stockpile = maxf(clan_data.arms_stockpile - arms_cost, 0.0)

	var company_dict: Dictionary = {}
	if levy_result.get("success", false):
		var cd: MilitaryUnitData.CompanyData = levy_result["company"]
		company_dict = {
			"company_id": cd.company_id,
			"unit_type": cd.unit_type,
			"health": cd.health,
			"morale": cd.morale,
			"commander_id": cd.commander_id,
			"parent_legion_id": cd.parent_legion_id,
			"source_province_id": cd.source_province_id,
			"army_id": -1,
			"lord_id": lord_id,
			"destroyed": false,
			"routed": false,
			"levy_raised_season": season_count,
		}
		companies.append(company_dict)

	return {
		"type": "levy_raised",
		"character_id": lord_id,
		"province_id": province_id,
		"settlement_id": target_settlement.settlement_id,
		"pu_consumed": r["pu_consumed"],
		"company_id": cid if levy_result.get("success", false) else -1,
		"unit_type": unit_type,
		"arms_cost": arms_cost,
		"arms_deducted": arms_deducted,
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


## When a Daimyo refuses the Champion's courtier (s2.4.14 Decision 4), set the
## garrison_shortage_courtier_refused flag on the affected wall tower so the
## decomposer's Step 3 can detect the emergency-declaration trigger condition.
static func _apply_garrison_courtier_refusal_writebacks(
	results: Array[Dictionary],
	settlements: Array[SettlementData],
) -> void:
	for r: Dictionary in results:
		var effects: Dictionary = r.get("effects", {})
		if not effects.get("garrison_refused", false):
			continue
		var target_province_id: int = effects.get("target_province_id", -1)
		if target_province_id < 0:
			continue
		for s: SettlementData in settlements:
			if s.settlement_type == Enums.SettlementType.WALL_TOWER \
					and s.province_id == target_province_id:
				s.garrison_shortage_courtier_refused = true
				break


## When a Champion or Shireikan writes a garrison shortage letter (s2.4.13–14),
## mark the tower's garrison_shortage_letter_season so the escalation pipeline
## can advance to DISPATCH_COURTIER the following season.
static func _apply_garrison_shortage_letter_writebacks(
	letter_results: Array[Dictionary],
	characters_by_id: Dictionary,
	settlements: Array[SettlementData],
	current_season: int,
) -> void:
	for r: Dictionary in letter_results:
		if r.get("need_type", "") != "STRENGTHEN_WALL":
			continue
		var char_id: int = r.get("character_id", -1)
		var character: L5RCharacterData = characters_by_id.get(char_id)
		if character == null:
			continue
		var loc: String = character.physical_location
		for s: SettlementData in settlements:
			if s.settlement_type == Enums.SettlementType.WALL_TOWER \
					and str(s.settlement_id) == loc:
				s.garrison_shortage_letter_season = current_season
				break


static func _apply_garrison_assignment(
	applied: Dictionary,
	characters_by_id: Dictionary,
	settlements: Array[SettlementData],
	provinces: Dictionary,
) -> Dictionary:
	var effects: Dictionary = applied.get("effects", {})
	var target_id: int = effects.get("target_npc_id", -1)
	var target_province_id: int = effects.get("target_province_id", -1)
	if target_id < 0 or target_province_id < 0:
		return {}

	var daimyo: L5RCharacterData = characters_by_id.get(target_id)
	if daimyo == null:
		return {}

	var honor_gain: float = effects.get("honor_gain_recipient", 0.0)
	if honor_gain != 0.0:
		HonorGlorySystem.apply_honor_change(daimyo, honor_gain)

	var wall_tower: SettlementData = null
	var source_settlement: SettlementData = null
	var daimyo_province_id: int = _find_lord_province_id(daimyo, provinces)

	for s: SettlementData in settlements:
		if s.province_id == target_province_id \
				and s.settlement_type == Enums.SettlementType.WALL_TOWER \
				and wall_tower == null:
			wall_tower = s
		if s.province_id == daimyo_province_id \
				and source_settlement == null:
			source_settlement = s

	var pu_transferred: float = 0.0
	if wall_tower != null:
		# Mark courtier as dispatched for this tower's shortage pipeline.
		wall_tower.garrison_shortage_courtier_dispatched = true
		var transfer: float = 1.0
		if source_settlement != null and source_settlement.garrison_pu >= transfer:
			source_settlement.garrison_pu -= transfer
			wall_tower.garrison_pu += transfer
			pu_transferred = transfer
		elif source_settlement != null and source_settlement.garrison_pu > 0.0:
			pu_transferred = source_settlement.garrison_pu
			wall_tower.garrison_pu += pu_transferred
			source_settlement.garrison_pu = 0.0
		# Reset shortage tracking once garrison is no longer below minimum.
		if not WallSystem.is_garrison_below_minimum(wall_tower.garrison_pu):
			wall_tower.garrison_shortage_letter_season = -1
			wall_tower.garrison_shortage_courtier_dispatched = false
			wall_tower.garrison_shortage_courtier_refused = false

	var requester_id: int = applied.get("character_id", -1)
	return {
		"type": "garrison_assigned",
		"daimyo_id": target_id,
		"requester_id": requester_id,
		"target_province_id": target_province_id,
		"source_province_id": daimyo_province_id,
		"pu_transferred": pu_transferred,
		"honor_gained": honor_gain,
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

static func _process_compact_restorations(
	applied_list: Array,
	phoenix_council_state: Dictionary,
) -> Array[Dictionary]:
	## Intercepts RESTORE_COUNCIL_COMPACT action results and applies the
	## restoration to phoenix_council_state (s55.10.3.7).
	var results: Array[Dictionary] = []
	if phoenix_council_state.is_empty():
		return results
	for applied: Variant in applied_list:
		if not (applied is Dictionary):
			continue
		var ad: Dictionary = applied
		var effects: Dictionary = ad.get("effects", {})
		if not effects.get("requires_compact_restoration", false):
			continue
		PhoenixCouncil.restore_council_compact(phoenix_council_state)
		results.append({
			"event": "compact_restored",
			"restoring_champion_id": int(effects.get("restoring_champion_id", -1)),
		})
	return results


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
			HonorGlorySystem.apply_glory_change(lord, side["glory_cost"])
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

	topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(topic.tier)

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


# -- Territory Transfer on War End ----------------------------------------------

static func _apply_war_territory_transfers(
	war_termination_results: Array[Dictionary],
	provinces: Dictionary,
) -> Array[Dictionary]:
	var all_transfers: Array[Dictionary] = []
	for resolution: Dictionary in war_termination_results:
		var transfers: Array[Dictionary] = WarTermination.apply_territory_transfers(
			resolution, provinces,
		)
		all_transfers.append_array(transfers)
	return all_transfers


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
	court_commitments: Array[CourtCommitmentData] = [],
	characters: Array[L5RCharacterData] = [],
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
				court_commitments, characters,
			)
			if not edicts_issued.is_empty():
				close_result["edicts_issued"] = edicts_issued.size()
			if court.court_type == CourtSessionData.CourtType.IMPERIAL_WINTER_COURT:
				var glory_rewards: Array[Dictionary] = WinterCourtSystem.compute_glory_rewards(court, characters_by_id)
				for reward: Dictionary in glory_rewards:
					var rid: int = reward.get("character_id", -1)
					var rchar: L5RCharacterData = characters_by_id.get(rid) as L5RCharacterData
					if rchar != null:
						HonorGlorySystem.apply_glory_change(rchar, reward.get("glory_change", 0.0))
				close_result["glory_rewards"] = glory_rewards
				if court.announcement_topic_id >= 0:
					for topic: TopicData in active_topics:
						if topic.topic_id == court.announcement_topic_id:
							topic.resolved = true
							break
			var topic_dict: Dictionary = CourtSystem.generate_court_close_topic(court)
			if not topic_dict.is_empty():
				var t: TopicData = _topic_from_dict(topic_dict, next_topic_id, ic_day)
				active_topics.append(t)
				close_result["topic_id"] = t.topic_id
			results.append(close_result)
		else:
			results.append(advance_result)
	return results


static func _topic_from_dict(
	topic_dict: Dictionary,
	next_topic_id: Array[int],
	ic_day: int,
) -> TopicData:
	var t := TopicData.new()
	t.topic_id = next_topic_id[0]
	next_topic_id[0] += 1
	t.topic_type = topic_dict.get("topic_type", "")
	t.variant = topic_dict.get("variant", "")
	t.slug = topic_dict.get("slug", "")
	t.tier = topic_dict.get("tier", TopicData.Tier.TIER_4)
	t.category = topic_dict.get("category", TopicData.Category.POLITICAL)
	t.momentum = topic_dict.get("momentum", TopicMomentumSystem.MOMENTUM_MINOR_FLOOR)
	t.clan_involved = topic_dict.get("clan_involved", "")
	t.subject_character_id = topic_dict.get("subject_character_id", -1)
	t.subject_role = topic_dict.get("subject_role", "NEUTRAL")
	t.provinces_affected = topic_dict.get("provinces_affected", [])
	t.ic_day_created = ic_day
	return t


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
	court_commitments: Array[CourtCommitmentData] = [],
	characters: Array[L5RCharacterData] = [],
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

	var attendees: Array[L5RCharacterData] = _gather_attendees(court, characters_by_id)
	var agg_result: Dictionary = ImperialEdictSystem.generate_edicts_from_aggregate(
		emperor, archetype, court, attendees,
		active_topics, active_wars, next_edict_id, ic_day,
	)
	var edicts: Array[EdictData] = []
	for e: EdictData in agg_result.get("edicts", []):
		edicts.append(e)

	var deadline_ic_day: int = ic_day + 90
	var lords: Array[L5RCharacterData] = _gather_lord_tier_characters(characters)

	for edict: EdictData in edicts:
		active_edicts.append(edict)
		var topic_dict: Dictionary = ImperialEdictSystem.generate_edict_topic(edict)
		if not topic_dict.is_empty():
			var t: TopicData = _topic_from_dict(topic_dict, next_topic_id, ic_day)
			active_topics.append(t)
		var edict_topic: TopicData = _find_topic_by_id(edict.target_topic_id, active_topics)
		if edict_topic != null:
			var new_commitments: Array[CourtCommitmentData] = ImperialEdictSystem.generate_edict_commitments(
				edict, edict_topic, lords, ic_day, deadline_ic_day,
			)
			for cc: CourtCommitmentData in new_commitments:
				court_commitments.append(cc)
	return edicts


static func _gather_attendees(
	court: CourtSessionData,
	characters_by_id: Dictionary,
) -> Array[L5RCharacterData]:
	var result: Array[L5RCharacterData] = []
	for char_id: int in court.attendee_ids:
		var c: L5RCharacterData = characters_by_id.get(char_id) as L5RCharacterData
		if c != null:
			result.append(c)
	return result


static func _gather_lord_tier_characters(
	characters: Array[L5RCharacterData],
) -> Array[L5RCharacterData]:
	var result: Array[L5RCharacterData] = []
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if c.status >= 5.0 or c.lord_id == -1:
			result.append(c)
	return result


static func _find_topic_by_id(
	topic_id: int,
	active_topics: Array[TopicData],
) -> TopicData:
	for t: TopicData in active_topics:
		if t.topic_id == topic_id:
			return t
	return null


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
				ws = {}
				world_states[char_id] = ws
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
			ws = {}
			world_states[character.character_id] = ws

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
		wstat.minimum_garrison = int(WallSystem.MINIMUM_GARRISON_PU)
		wstat.garrison_above_minimum = not WallSystem.is_garrison_below_minimum(tower.garrison_pu)
		wstat.garrison_shortage_letter_season = tower.garrison_shortage_letter_season
		wstat.garrison_shortage_courtier_dispatched = tower.garrison_shortage_courtier_dispatched
		wstat.garrison_shortage_courtier_refused = tower.garrison_shortage_courtier_refused
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
	season_meta: Dictionary,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = ImperialEdictSystem.process_daily_compliance(
		active_edicts, active_wars, characters, ic_day,
	)
	for r: Dictionary in results:
		var topic_dict: Dictionary = r.get("defiance_topic", {})
		if not topic_dict.is_empty():
			var t: TopicData = _topic_from_dict(topic_dict, next_topic_id, ic_day)
			active_topics.append(t)
			r["defiance_topic_id"] = t.topic_id
		if r.get("tax_reform_active", false):
			season_meta["tax_reform_active"] = true
			season_meta["tax_reform_edict_id"] = r.get("tax_reform_edict_id", -1)
		if r.has("last_general_decree_id"):
			season_meta["last_general_decree_id"] = r["last_general_decree_id"]
			season_meta["last_general_decree_day"] = r.get("last_general_decree_day", ic_day)
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
	var host_champion: L5RCharacterData = characters_by_id.get(host_champion_id) as L5RCharacterData
	agenda = WinterCourtSystem.order_agenda_for_host(
		agenda, active_topics, host_clan, host_champion, characters_by_id,
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
	var topic: TopicData = _topic_from_dict(topic_info, next_topic_id, ic_day)
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
		topic.momentum = _COMBAT_EVENT_MOMENTUM
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
		topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(topic.tier)
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


# -- Togashi Oversight (s55.10.2) -----------------------------------------------

static func _process_togashi_oversight(
	togashi_state: Dictionary,
	strategic_results: Array[Dictionary],
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	world_states: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	active_civil_wars: Array[Dictionary] = [],
	objectives_map: Dictionary = {},
	current_season: int = 0,
	settlements: Array[SettlementData] = [],
	provinces: Dictionary = {},
) -> Dictionary:
	# Reappearance check runs BEFORE the dragon_autonomous_rule gate.
	# The assaulting FC held autonomous rule; when he dies a new FC is found here.
	# This is the only path that clears togashi_vanished and dragon_autonomous_rule (s55.10.2.8).
	if TogashiOversight.is_togashi_off_map(togashi_state):
		var last_assaulter_id: int = int(togashi_state.get("last_assaulter_fc_id", -1))
		var candidate_fc: L5RCharacterData = _find_mirumoto_fc(characters)
		if (
			candidate_fc != null
			and last_assaulter_id >= 0
			and candidate_fc.character_id != last_assaulter_id
		):
			var togashi_char: L5RCharacterData = characters_by_id.get(_find_togashi_id(characters))
			var settled_cw: Dictionary = {}
			for cw: Dictionary in active_civil_wars:
				if not cw.get("active", false) and cw.get("clan", "") == "Dragon":
					settled_cw = cw.get("faction_assignments", {})
					break
			var reappear: Dictionary = TogashiOversight.reappear_togashi(
				togashi_state, togashi_char, settlements, provinces, settled_cw
			)
			return {
				"togashi_reappeared": reappear.get("reappeared", false),
				"togashi_reappear_settlement": reappear.get("settlement_id", -1),
			}

	# Dragon FC won autonomous rule — Oversight System suspended for his lifetime (s55.10.2.8).
	if togashi_state.get("dragon_autonomous_rule", false):
		return {"skipped": true, "reason": "dragon_autonomous_rule_active"}

	var order_recon_done: bool = false
	if int(togashi_state.get("order_reconstitution_seasons_remaining", 0)) > 0:
		order_recon_done = TogashiOversight.tick_order_reconstitution(togashi_state)

	var mirumoto_fc: L5RCharacterData = _find_mirumoto_fc(characters)
	if mirumoto_fc == null:
		return {"skipped": true, "reason": "no_mirumoto_fc"}

	var togashi_id: int = _find_togashi_id(characters)

	var fc_directives: Array[Dictionary] = []
	for d: Dictionary in strategic_results:
		if int(d.get("lord_id", -1)) == mirumoto_fc.character_id:
			fc_directives.append(d)

	var oversight_world: Dictionary = _build_togashi_world_state(
		world_states, characters, characters_by_id,
	)

	var result: Dictionary = TogashiOversight.process_seasonal_oversight(
		togashi_state, oversight_world, fc_directives,
		mirumoto_fc, togashi_id,
	)

	if result.get("intervention_fired", false):
		var compliance: Dictionary = result.get("compliance", {})
		var directive: Dictionary = result.get("forced_directive", {})

		if compliance.get("comply", false):
			directive["lord_id"] = mirumoto_fc.character_id
			strategic_results.append(directive)

		var stage: int = int(togashi_state.get("stage", 0))
		if stage >= 1:
			var topic := TopicData.new()
			topic.topic_id = next_topic_id[0]
			next_topic_id[0] += 1
			var axis_name: String = _axis_to_string(int(result["forced_directive"].get("axis", 0)))
			if compliance.get("comply", false):
				topic.slug = "togashi_directive_comply_%s_%d" % [axis_name, ic_day]
				topic.variant = "togashi_directive_comply"
			else:
				topic.slug = "togashi_defiance_stage_%d_%d" % [stage, ic_day]
				topic.variant = "togashi_defiance"
				HonorGlorySystem.apply_honor_change(mirumoto_fc, -0.3)
			topic.topic_type = "political"
			topic.tier = TopicData.Tier.TIER_4 if stage <= 2 else TopicData.Tier.TIER_3
			topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(topic.tier)
			topic.category = TopicData.Category.POLITICAL
			active_topics.append(topic)
			result["topic_id"] = topic.topic_id

		if TogashiOversight.is_authority_locked(togashi_state):
			result["diplomatic_penalty"] = TogashiOversight.STAGE_DIPLOMATIC_PENALTY

	if TogashiOversight.is_removal_triggered(togashi_state):
		var togashi_id: int = _find_togashi_id(characters)
		var fc_id: int = mirumoto_fc.character_id
		if togashi_id >= 0:
			# Snapshot dissatisfaction so seasonal re-evaluation can detect worsening (s55.10.2.8).
			var snapshot: Dictionary = togashi_state.get("dissatisfaction", {}).duplicate()
			var cw_result: Dictionary = _trigger_civil_war(
				fc_id, togashi_id, "Dragon", "removal order",
				characters, characters_by_id, objectives_map,
				active_civil_wars, active_topics, next_topic_id,
				ic_day, current_season,
				false, "dragon_schism", snapshot,
			)
			result["civil_war_triggered"] = cw_result

	if order_recon_done:
		result["order_reconstitution_done"] = true

	return result


static func _has_active_dragon_schism(active_civil_wars: Array[Dictionary]) -> bool:
	for cw: Dictionary in active_civil_wars:
		if cw.get("clan", "") == "Dragon" and cw.get("active", false):
			return true
	return false


static func _find_mirumoto_fc(characters: Array[L5RCharacterData]) -> L5RCharacterData:
	var best: L5RCharacterData = null
	for c: L5RCharacterData in characters:
		if c.clan != "Dragon" or c.family != "Mirumoto":
			continue
		if CharacterStats.is_dead(c.wounds_taken, CharacterStats.get_ring_value(c, Enums.Ring.EARTH)):
			continue
		if c.lord_id != -1:
			continue
		if best == null or c.status > best.status:
			best = c
		elif c.status == best.status and c.character_id < best.character_id:
			best = c
	return best


static func _find_togashi_id(characters: Array[L5RCharacterData]) -> int:
	for c: L5RCharacterData in characters:
		if c.clan != "Dragon" or c.family != "Togashi":
			continue
		if CharacterStats.is_dead(c.wounds_taken, CharacterStats.get_ring_value(c, Enums.Ring.EARTH)):
			continue
		if c.lord_id == -1 and c.status >= 7.0:
			return c.character_id
	return -1


static func _build_togashi_world_state(
	world_states: Dictionary,
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
) -> Dictionary:
	var clan_strengths: Dictionary = {}
	for c: L5RCharacterData in characters:
		if c.clan.is_empty():
			continue
		if CharacterStats.is_dead(c.wounds_taken, CharacterStats.get_ring_value(c, Enums.Ring.EARTH)):
			continue
		clan_strengths[c.clan] = float(clan_strengths.get(c.clan, 0.0)) + c.status

	var active_wars: Array = world_states.get("active_wars", [])
	var inter_clan_wars: int = 0
	for w in active_wars:
		if w is Dictionary:
			inter_clan_wars += 1

	var provinces_data: Array = world_states.get("province_data", [])
	var rebellion_count: int = 0
	var max_non_sl_ptl: float = 0.0
	var wall_breach: bool = false
	var failing_worship: int = 0
	for p in provinces_data:
		if p is ProvinceData:
			if p.active_insurgency_id >= 0:
				rebellion_count += 1
			if p.province_taint_level > 0.0 and p.clan != "Crab":
				max_non_sl_ptl = maxf(max_non_sl_ptl, p.province_taint_level)
			if p.shadowlands_strength > 0 and p.stability < 30.0:
				wall_breach = true

	var worship_maluses: Dictionary = world_states.get("_worship_maluses", {})
	for prov_id in worship_maluses:
		var pm: Dictionary = worship_maluses[prov_id]
		if pm.is_empty():
			continue
		for fortune_key in pm:
			var malus: Dictionary = pm[fortune_key]
			if malus.get("tier", 0) >= 2:
				failing_worship += 1
				break

	var emperor_vacant: bool = int(world_states.get("emperor_id", -1)) < 0

	return {
		"clan_strengths": clan_strengths,
		"active_inter_clan_wars": inter_clan_wars,
		"emperor_vacant": emperor_vacant,
		"provinces_in_rebellion": rebellion_count,
		"failing_worship_provinces": failing_worship,
		"realm_overlaps_empire_wide": 0,
		"realm_overlap_in_dragon_territory": false,
		"max_non_shadowlands_ptl": max_non_sl_ptl,
		"wall_breach_active": wall_breach,
		"shadowlands_incursion_tier": 0,
		"crab_military_readiness": 1.0,
	}


static func _axis_to_string(axis: int) -> String:
	match axis:
		TogashiOversight.Axis.BALANCE_OF_POWER: return "balance"
		TogashiOversight.Axis.IMPERIAL_COHESION: return "cohesion"
		TogashiOversight.Axis.SPIRITUAL_HEALTH: return "spiritual"
		TogashiOversight.Axis.SHADOWLANDS_CONTAINMENT: return "shadowlands"
	return "unknown"


# -- Phoenix Council Gating (s55.10.3) -----------------------------------------

static func _process_phoenix_council_gating(
	phoenix_state: Dictionary,
	strategic_results: Array[Dictionary],
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	dice_engine: DiceEngine,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	active_civil_wars: Array[Dictionary] = [],
	objectives_map: Dictionary = {},
	current_season: int = 0,
	provinces: Dictionary = {},
	emperor_id: int = -1,
) -> Dictionary:
	var shiba_champion: L5RCharacterData = _find_shiba_champion(characters)
	if shiba_champion == null:
		return {"skipped": true, "reason": "no_shiba_champion"}

	if PhoenixCouncil.has_champion_authority(phoenix_state):
		# Detect reincarnation: champion changed while authority flag is active.
		# The new Champion evaluates compact restoration on their first season (s55.10.3.7).
		var known_champ_id: int = int(phoenix_state.get("known_champion_id", -1))
		var current_champ_id: int = shiba_champion.character_id if shiba_champion != null else -1
		if current_champ_id >= 0 and current_champ_id != known_champ_id and known_champ_id >= 0:
			# New Champion detected — run first-season restoration evaluation.
			var duty_score: int = (
				70 if shiba_champion.bushido_virtue == Enums.BushidoVirtue.CHUGI else 30
			)
			var avg_disp: int = _compute_avg_council_disposition(
				shiba_champion, characters_by_id
			)
			var restores: bool = PhoenixCouncil.reincarnated_champion_evaluates_restore(
				shiba_champion, avg_disp, duty_score
			)
			phoenix_state["known_champion_id"] = current_champ_id
			if restores:
				PhoenixCouncil.restore_council_compact(phoenix_state)
				return {
					"reincarnation_eval": true,
					"compact_restored": true,
					"new_champion_id": current_champ_id,
				}
			return {
				"reincarnation_eval": true,
				"compact_restored": false,
				"new_champion_id": current_champ_id,
				"skipped": true,
				"reason": "champion_authority_retained",
			}
		# No champion change (or first-ever call) — update known_champion_id and skip.
		if current_champ_id >= 0:
			phoenix_state["known_champion_id"] = current_champ_id
		return {"skipped": true, "reason": "champion_has_authority"}

	var living_masters: Array = _find_living_elemental_masters(characters)
	if not PhoenixCouncil.can_council_self_govern(living_masters):
		return {"skipped": true, "reason": "council_below_quorum"}

	var master_virtues: Dictionary = _build_master_virtues(living_masters, characters_by_id)
	var dispositions_to_champion: Dictionary = _build_master_dispositions(
		living_masters, characters_by_id, shiba_champion.character_id,
	)

	var vetoed: Array[Dictionary] = []
	var approved: Array[Dictionary] = []
	var had_any_major: bool = false
	var had_any_proposal: bool = false
	var all_rejected: bool = true

	var directives_to_remove: Array[int] = []

	for idx: int in range(strategic_results.size()):
		var d: Dictionary = strategic_results[idx]
		if int(d.get("lord_id", -1)) != shiba_champion.character_id:
			continue

		var decision_type: int = _directive_to_decision_type(d)
		if decision_type < 0:
			continue

		if not PhoenixCouncil.is_major_decision(decision_type as PhoenixCouncil.DecisionType):
			continue

		had_any_major = true
		had_any_proposal = true

		var current_season: int = int(d.get("_season_count", 0))
		if PhoenixCouncil.is_proposal_banned(phoenix_state, decision_type as PhoenixCouncil.DecisionType, current_season):
			directives_to_remove.append(idx)
			vetoed.append({"directive": d, "reason": "banned_resubmission"})
			continue

		var proposal: Dictionary = {
			"decision_type": decision_type,
			"crisis_response": d.get("crisis_response", false),
			"threatens_element": d.get("threatens_element", -1),
			"spiritual_dimension": d.get("spiritual_dimension", false),
		}

		var vote_result: Dictionary = PhoenixCouncil.tally_vote(
			living_masters, proposal, dispositions_to_champion,
			dice_engine, master_virtues,
		)

		if vote_result.get("passed", false):
			approved.append({"directive": d, "vote": vote_result})
			all_rejected = false
			PhoenixCouncil.reset_crisis_veto_streak(phoenix_state)
			PhoenixCouncil.reset_obstruction_streak(phoenix_state)
			PhoenixCouncil.clear_failed_proposal(phoenix_state, decision_type as PhoenixCouncil.DecisionType)
		elif vote_result.get("deadlocked", false):
			if PhoenixCouncil.champion_may_break_tie(phoenix_state, decision_type as PhoenixCouncil.DecisionType):
				approved.append({"directive": d, "vote": vote_result, "tie_broken": true})
				all_rejected = false
				HonorGlorySystem.apply_honor_change(shiba_champion, PhoenixCouncil.DEFIANCE_STAGE_1_HONOR_PENALTY)
			else:
				PhoenixCouncil.table_proposal(phoenix_state, decision_type as PhoenixCouncil.DecisionType, current_season)
				directives_to_remove.append(idx)
				vetoed.append({"directive": d, "vote": vote_result, "tabled": true})
		else:
			directives_to_remove.append(idx)
			vetoed.append({"directive": d, "vote": vote_result})
			if d.get("crisis_response", false):
				PhoenixCouncil.track_consecutive_crisis_veto(phoenix_state)
			PhoenixCouncil.record_failed_proposal(phoenix_state, decision_type as PhoenixCouncil.DecisionType, current_season)

	directives_to_remove.sort()
	directives_to_remove.reverse()
	for idx: int in directives_to_remove:
		strategic_results.remove_at(idx)

	if had_any_major and all_rejected:
		PhoenixCouncil.track_consecutive_obstruction(phoenix_state)
	elif had_any_major:
		PhoenixCouncil.reset_obstruction_streak(phoenix_state)

	if had_any_proposal:
		if not all_rejected:
			PhoenixCouncil.handle_compliant_season(phoenix_state)

	if not vetoed.is_empty():
		var topic := TopicData.new()
		topic.topic_id = next_topic_id[0]
		next_topic_id[0] += 1
		var overreach_stage: int = int(phoenix_state.get("overreach_stage", 0))
		topic.slug = "phoenix_council_veto_%d" % ic_day
		topic.variant = "phoenix_council_veto"
		topic.topic_type = "political"
		topic.tier = TopicData.Tier.TIER_4 if overreach_stage <= 1 else TopicData.Tier.TIER_3
		topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(topic.tier)
		topic.category = TopicData.Category.POLITICAL
		active_topics.append(topic)

	# Apply devastating effect for any approved GRAND_RITUAL directive (s55.10.3.7).
	var grand_ritual_results: Array[Dictionary] = []
	for approval: Dictionary in approved:
		var directive: Dictionary = approval.get("directive", {})
		var dt: int = int(directive.get("decision_type", -1))
		if dt != PhoenixCouncil.DecisionType.GRAND_RITUAL:
			continue
		var target_province_id: int = int(directive.get("target_province_id", -1))
		var target_province: ProvinceData = provinces.get(target_province_id) as ProvinceData
		if target_province == null:
			continue
		var all_reps: Array[L5RCharacterData] = characters.filter(
			func(c: L5RCharacterData) -> bool: return c.status >= 5.0
		)
		var ritual_result: Dictionary = PhoenixCouncil.apply_grand_ritual_devastation(
			target_province, living_masters, all_reps, emperor_id
		)
		if ritual_result.get("applied", false):
			var crisis_dict: Dictionary = ritual_result.get("crisis_topic", {})
			if not crisis_dict.is_empty():
				var ct: TopicData = _topic_from_dict(crisis_dict, next_topic_id, ic_day)
				active_topics.append(ct)
				ritual_result["crisis_topic_id"] = ct.topic_id
		grand_ritual_results.append(ritual_result)

	var result_dict: Dictionary = {
		"vetoed": vetoed,
		"approved": approved,
		"had_major_decisions": had_any_major,
		"defiance_stage": int(phoenix_state.get("defiance_stage", 0)),
		"overreach_stage": int(phoenix_state.get("overreach_stage", 0)),
		"living_masters_count": living_masters.size(),
		"grand_ritual_results": grand_ritual_results,
	}

	if PhoenixCouncil.is_overreach_schism_imminent(phoenix_state):
		var senior_master_id: int = _find_senior_elemental_master_id(living_masters, characters_by_id)
		if senior_master_id >= 0:
			# Council Overreach: no automatic honor hemorrhage on either side (s55.10.3.7).
			var cw_result: Dictionary = _trigger_civil_war(
				senior_master_id, shiba_champion.character_id,
				"Phoenix", "council overreach",
				characters, characters_by_id, objectives_map,
				active_civil_wars, active_topics, next_topic_id,
				ic_day, current_season,
				true, "overreach",
			)
			result_dict["civil_war_triggered"] = cw_result

	# Champion Defiance Path schism: Champion refuses Stage 4 removal (s55.10.3.5, s55.10.3.7).
	# Rebel = Champion (defied Council 4 times), Authority = Senior Master (Council representative).
	# Standard −0.3 Honor/season hemorrhage applies to the Champion (suppress_hemorrhage = false).
	if PhoenixCouncil.is_unfit_declaration_active(phoenix_state):
		var senior_master_id: int = _find_senior_elemental_master_id(living_masters, characters_by_id)
		if senior_master_id >= 0:
			var cw_result: Dictionary = _trigger_civil_war(
				shiba_champion.character_id, senior_master_id,
				"Phoenix", "champion defiance",
				characters, characters_by_id, objectives_map,
				active_civil_wars, active_topics, next_topic_id,
				ic_day, current_season,
				false, "defiance",
			)
			result_dict["champion_defiance_civil_war_triggered"] = cw_result

	return result_dict


static func _find_shiba_champion(characters: Array[L5RCharacterData]) -> L5RCharacterData:
	var best: L5RCharacterData = null
	for c: L5RCharacterData in characters:
		if c.clan != "Phoenix":
			continue
		if c.lord_id != -1:
			continue
		if CharacterStats.is_dead(c.wounds_taken, CharacterStats.get_ring_value(c, Enums.Ring.EARTH)):
			continue
		if best == null or c.status > best.status:
			best = c
		elif c.status == best.status and c.character_id < best.character_id:
			best = c
	return best


static func _find_living_elemental_masters(characters: Array[L5RCharacterData]) -> Array:
	var masters: Array = []
	var found_by_role: Dictionary = {}
	for c: L5RCharacterData in characters:
		if c.clan != "Phoenix":
			continue
		if CharacterStats.is_dead(c.wounds_taken, CharacterStats.get_ring_value(c, Enums.Ring.EARTH)):
			continue
		if c.role_position.begins_with("Master of "):
			var element: String = c.role_position.replace("Master of ", "")
			var master_enum: int = _element_string_to_master(element)
			if master_enum >= 0 and not found_by_role.has(master_enum):
				found_by_role[master_enum] = c
	for m in found_by_role:
		masters.append(m)
	return masters


static func _find_senior_elemental_master_id(
	_living_masters: Array,
	characters_by_id: Dictionary,
) -> int:
	var best_id: int = -1
	var best_status: float = -1.0
	for c: L5RCharacterData in characters_by_id.values():
		if c.clan != "Phoenix":
			continue
		if not c.role_position.begins_with("Master of "):
			continue
		if CharacterStats.is_dead(c):
			continue
		if c.status > best_status:
			best_status = c.status
			best_id = c.character_id
	return best_id


static func _element_string_to_master(element: String) -> int:
	match element.to_lower():
		"fire": return PhoenixCouncil.Master.FIRE
		"water": return PhoenixCouncil.Master.WATER
		"air": return PhoenixCouncil.Master.AIR
		"earth": return PhoenixCouncil.Master.EARTH
		"void": return PhoenixCouncil.Master.VOID
	return -1


static func _build_master_virtues(
	living_masters: Array,
	characters_by_id: Dictionary,
) -> Dictionary:
	var virtues: Dictionary = {}
	for m in living_masters:
		var master_char: L5RCharacterData = _find_master_character(m, characters_by_id)
		if master_char != null:
			virtues[m] = {
				"bushido": master_char.bushido_virtue,
				"shourido": master_char.shourido_virtue,
			}
	return virtues


static func _build_master_dispositions(
	living_masters: Array,
	characters_by_id: Dictionary,
	champion_id: int,
) -> Dictionary:
	var dispositions: Dictionary = {}
	for m in living_masters:
		var master_char: L5RCharacterData = _find_master_character(m, characters_by_id)
		if master_char != null:
			dispositions[m] = int(master_char.disposition_values.get(champion_id, 0))
		else:
			dispositions[m] = 0
	return dispositions


static func _find_master_character(
	master_enum: int,
	characters_by_id: Dictionary,
) -> L5RCharacterData:
	var element_name: String = ""
	match master_enum:
		PhoenixCouncil.Master.FIRE: element_name = "Fire"
		PhoenixCouncil.Master.WATER: element_name = "Water"
		PhoenixCouncil.Master.AIR: element_name = "Air"
		PhoenixCouncil.Master.EARTH: element_name = "Earth"
		PhoenixCouncil.Master.VOID: element_name = "Void"
	var target_role: String = "Master of " + element_name
	for id in characters_by_id:
		var c: L5RCharacterData = characters_by_id[id]
		if c.clan == "Phoenix" and c.role_position == target_role:
			if not CharacterStats.is_dead(c.wounds_taken, CharacterStats.get_ring_value(c, Enums.Ring.EARTH)):
				return c
	return null


static func _directive_to_decision_type(directive: Dictionary) -> int:
	var dtype: int = int(directive.get("directive", -1))
	match dtype:
		StrategicReview.Directive.WAR_READINESS:
			return PhoenixCouncil.DecisionType.DEPLOY_GO_HATAMOTO
		StrategicReview.Directive.SEEK_PEACE:
			return PhoenixCouncil.DecisionType.SIGN_TREATY
	return -1


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
			topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(topic.tier)
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
		topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(topic.tier)
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
		elif decision == "SELF_SELECT":
			var new_obj: Dictionary = directive.get("new_objective", {})
			if not new_obj.is_empty():
				new_obj["status"] = "ACTIVE"
				objectives_map[vassal_id]["primary"] = new_obj
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


# -- Tyrant Directive Consumers (s55.10) ----------------------------------------

static func _process_tyrant_directives(
	strategic_results: Array[Dictionary],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	characters_by_id: Dictionary,
) -> void:
	for directive: Dictionary in strategic_results:
		var dtype: String = str(directive.get("directive", ""))
		if dtype == "FABRICATE_DISGRACE":
			_create_disgrace_topic(
				directive, active_topics, next_topic_id, ic_day, characters_by_id
			)
		elif dtype == "IMPERIAL_CIVIL_WAR":
			_create_imperial_civil_war_topic(
				directive, active_topics, next_topic_id, ic_day
			)


static func _create_disgrace_topic(
	directive: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	characters_by_id: Dictionary,
) -> void:
	var target_id: int = directive.get("target_id", -1)

	for existing: TopicData in active_topics:
		if existing.topic_type == "disgrace" and existing.subject_character_id == target_id and not existing.resolved:
			return

	var target_clan: String = directive.get("target_clan", "")
	var target: L5RCharacterData = characters_by_id.get(target_id) as L5RCharacterData
	var target_name: String = target.character_name if target != null and target.character_name != "" else "Champion"

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] += 1

	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id,
		"Disgrace of %s (%s)" % [target_name, target_clan],
		TopicData.Tier.TIER_3,
		TopicData.Category.PERSONAL,
		ic_day,
		TopicMomentumSystem.initial_momentum_for_tier(TopicData.Tier.TIER_3),
		[],
		target_clan,
		"",
		target_id,
		"disgrace",
		"fabricated",
	)
	topic.slug = "tyrant_disgrace_%d_d%d" % [target_id, ic_day]
	active_topics.append(topic)


static func _create_imperial_civil_war_topic(
	directive: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
) -> void:
	for existing: TopicData in active_topics:
		if existing.variant == "imperial_civil_war" and not existing.resolved:
			return

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] += 1

	var hostile_count: int = directive.get("hostile_clan_count", 3)

	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id,
		"Imperial Civil War — %d Great Clans in Revolt" % hostile_count,
		TopicData.Tier.TIER_1,
		TopicData.Category.MILITARY,
		ic_day,
		TopicMomentumSystem.initial_momentum_for_tier(TopicData.Tier.TIER_1),
	)
	topic.slug = "imperial_civil_war_d%d" % ic_day
	topic.topic_type = "crisis"
	topic.variant = "imperial_civil_war"
	active_topics.append(topic)


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


static func _process_letter_examinations(
	day_results: Array,
	pending_letters: Array,
	characters_by_id: Dictionary,
	dice_engine: DiceEngine,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	if dice_engine == null:
		return results
	for r: Variant in day_results:
		if not (r is Dictionary):
			continue
		var result: Dictionary = r as Dictionary
		var effects: Dictionary = result.get("effects", {})
		if not effects.get("requires_letter_examination", false):
			continue
		var letter_id: int = effects.get("letter_id", -1)
		var examiner_id: int = effects.get("examiner_id", -1)
		if letter_id < 0 or examiner_id < 0:
			continue
		var examiner: L5RCharacterData = characters_by_id.get(examiner_id)
		if examiner == null:
			continue
		var letter: LetterData = LetterSystem._find_letter_by_id(pending_letters, letter_id)
		if letter == null:
			continue
		var exam_result: Dictionary = LetterSystem.deliberate_examine_letter(
			letter, examiner, dice_engine, pending_letters,
		)
		exam_result["letter_id"] = letter_id
		exam_result["examiner_id"] = examiner_id
		results.append(exam_result)
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


static func _apply_tyrant_stability_penalty(
	emperor_archetype: int,
	provinces: Dictionary,
) -> void:
	if emperor_archetype != StrategicReview.EmperorArchetype.TYRANT:
		return
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid] as ProvinceData
		if prov == null:
			continue
		prov.stability = clampf(
			prov.stability + StrategicReview.TYRANT_STABILITY_PENALTY, 0.0, 100.0
		)


static func _build_emperor_tax_config(
	world_states: Dictionary,
	characters_by_id: Dictionary,
) -> Dictionary:
	var archetype: int = int(world_states.get(
		"emperor_archetype", StrategicReview.EmperorArchetype.IRON
	))
	var config: Dictionary = {"archetype": archetype}
	if archetype != StrategicReview.EmperorArchetype.CUNNING:
		return config
	var emperor_id: int = int(world_states.get("emperor_id", -1))
	if emperor_id < 0:
		return config
	var emperor: L5RCharacterData = characters_by_id.get(emperor_id) as L5RCharacterData
	if emperor == null:
		return config
	var clan_disps: Dictionary = {}
	for cid: Variant in characters_by_id:
		var c: L5RCharacterData = characters_by_id[cid] as L5RCharacterData
		if c == null or c.clan == "" or c.status < 7.0 or c.lord_id != -1:
			continue
		var disp: int = int(emperor.disposition_values.get(c.character_id, 0))
		clan_disps[c.clan] = disp
	config["clan_dispositions"] = clan_disps
	return config


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

			ConstructionData.ConstructionType.FORGE:
				var target_s: Variant = _find_settlement_by_id(settlements, cd.settlement_id)
				if target_s != null:
					(target_s as SettlementData).infrastructure.append("forge")

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
			topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(topic.tier)
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
	topic.topic_type = "construction"

	match cd.construction_type:
		ConstructionData.ConstructionType.TEMPLE:
			topic.slug = "temple_completed_%d" % cd.construction_id
			topic.variant = "temple_completed"
			topic.tier = TopicData.Tier.TIER_3
		ConstructionData.ConstructionType.SHINDEN:
			topic.slug = "shinden_completed_%d" % cd.construction_id
			topic.variant = "shinden_completed"
			topic.tier = TopicData.Tier.TIER_2
			topic.momentum = _CONSTRUCTION_TIER2_MOMENTUM
		ConstructionData.ConstructionType.MONASTERY:
			topic.slug = "monastery_completed_%d" % cd.construction_id
			topic.variant = "monastery_completed"
			topic.tier = TopicData.Tier.TIER_3
		ConstructionData.ConstructionType.SHIP:
			topic.slug = "ship_launched_%d" % cd.construction_id
			topic.variant = "ship_launched"
		_:
			topic.slug = "construction_%d" % cd.construction_id
			topic.variant = "shrine_completed"

	if topic.momentum == 0.0:
		topic.momentum = TopicMomentumSystem.initial_momentum_for_tier(topic.tier)

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
	var worship_failing: Dictionary = {}  # province_id → clan
	var border_no_fort: Dictionary = {}  # province_id → clan
	var surplus_pu: Dictionary = {}  # province_id → clan
	var coastal: bool = false
	var has_naval_assets_flag: bool = false
	var naval_threat: bool = false

	var province_settlements: Dictionary = {}
	for s: SettlementData in settlements:
		if not province_settlements.has(s.province_id):
			province_settlements[s.province_id] = []
		province_settlements[s.province_id].append(s)

	var wp_data: Dictionary = worship_state.get("province_wp", {})

	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid]
		var p_settlements: Array = province_settlements.get(pid, [])

		# Worship failure: use WorshipSystem threshold evaluation
		if not wp_data.is_empty():
			var prov_wp: Dictionary = wp_data.get(pid, {})
			var tiers: Dictionary = WorshipSystem.evaluate_province_thresholds(prov_wp)
			var worst_tier: int = Enums.WorshipTier.NONE
			for fortune_key: Variant in tiers:
				var tier: int = int(tiers[fortune_key])
				if tier > worst_tier:
					worst_tier = tier
			if worst_tier > Enums.WorshipTier.NONE:
				worship_failing[int(pid)] = prov.clan

		# Border province without fortification
		if prov.adjacent_province_ids.size() > 0:
			var is_border: bool = false
			for adj_id: int in prov.adjacent_province_ids:
				var adj_prov: Variant = provinces.get(adj_id)
				if adj_prov != null and (adj_prov as ProvinceData).clan != prov.clan:
					is_border = true
					break
			if is_border:
				var has_military: bool = false
				for s: Variant in p_settlements:
					if (s as SettlementData).is_military():
						has_military = true
						break
				if not has_military:
					border_no_fort[int(pid)] = prov.clan

		# Surplus PU check
		var total_pu: float = 0.0
		for s: Variant in p_settlements:
			total_pu += (s as SettlementData).population_pu
		var threshold: float = ConstructionSystem.ORGANIC_SURPLUS_PU_THRESHOLD.get(
			prov.terrain_type, 10.0,
		)
		if total_pu > threshold:
			surplus_pu[int(pid)] = prov.clan

	# Coastal / naval detection
	for s: ShipData in ships:
		if not s.is_destroyed:
			has_naval_assets_flag = true
			break

	# Naval threat: at war AND enemy clan has ships
	var clans_with_ships: Dictionary = {}
	for s: ShipData in ships:
		if not s.is_destroyed and not s.owning_clan.is_empty():
			clans_with_ships[s.owning_clan] = true
	for w: Variant in world_states.get("active_wars", []):
		if w is WarData:
			var wd: WarData = w as WarData
			if clans_with_ships.has(wd.clan_a) or clans_with_ships.has(wd.clan_b):
				naval_threat = true
				break

	world_states["worship_failing_province_ids"] = worship_failing
	world_states["border_province_ids_without_fort"] = border_no_fort
	world_states["surplus_pu_province_ids"] = surplus_pu
	world_states["is_coastal"] = coastal
	world_states["has_naval_assets"] = has_naval_assets_flag
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
	settlements: Array[SettlementData] = [],
	provinces: Dictionary = {},
	season_meta: Dictionary = {},
) -> void:
	var lord_vacancies: Dictionary = {}

	var emperor_id: int = int(world_states.get("emperor_id", -1))
	var emperor_archetype: int = int(world_states.get(
		"emperor_archetype", StrategicReview.EmperorArchetype.IRON
	))
	var cunning_balance_weight: float = 0.0
	var emperor_clan_counts: Dictionary = {}
	if emperor_id >= 0 and emperor_archetype == StrategicReview.EmperorArchetype.CUNNING:
		cunning_balance_weight = float(StrategicReview.CUNNING_CLAN_BALANCE_WEIGHT)
		emperor_clan_counts = _compute_clan_position_counts(emperor_id, characters)

	# Military vacancies: units with no commander
	for company_data: Variant in companies:
		if company_data is Dictionary:
			var commander_id: int = company_data.get("commander_id", -1)
			if commander_id < 0:
				var parent_legion_id: int = company_data.get("parent_legion_id", -1)
				if parent_legion_id < 0:
					continue
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

	# Build province→lord mapping: highest-status living character per province clan
	var province_lord_map: Dictionary = {}
	for pid: Variant in provinces:
		var prov: ProvinceData = provinces[pid] as ProvinceData
		if prov == null:
			continue
		var best_lord_id: int = -1
		var best_status: float = -1.0
		for c: L5RCharacterData in characters:
			if CharacterStats.is_dead(c):
				continue
			if c.clan != prov.clan:
				continue
			if c.lord_id >= 0 and c.status < 5.0:
				continue
			if c.status < 3.0:
				continue
			if c.status > best_status:
				best_status = c.status
				best_lord_id = c.character_id
		province_lord_map[int(pid)] = best_lord_id

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

	# Check each lord for expected magistrate position
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if c.status < 3.0 or (c.lord_id >= 0 and c.status < 5.0):
			continue
		var lord_id: int = c.character_id
		var lord_positions: Array = filled_positions.get(lord_id, [])

		if not _has_position(lord_positions, "Magistrate"):
			var bal_w: float = cunning_balance_weight if lord_id == emperor_id else 0.0
			var bal_c: Dictionary = emperor_clan_counts if lord_id == emperor_id else {}
			var candidate: int = _find_vacancy_candidate(
				lord_id, "Magistrate", characters, characters_by_id,
				bal_w, bal_c,
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

	# Settlement-based vacancies: garrison commander, temple head, monastery abbot
	for s: SettlementData in settlements:
		var lord_id: int = province_lord_map.get(s.province_id, -1)
		if lord_id < 0:
			continue
		var lord_positions: Array = filled_positions.get(lord_id, [])

		if s.is_military() and not _has_position(lord_positions, "Garrison Commander"):
			var bal_w2: float = cunning_balance_weight if lord_id == emperor_id else 0.0
			var bal_c2: Dictionary = emperor_clan_counts if lord_id == emperor_id else {}
			var candidate: int = _find_vacancy_candidate(
				lord_id, "Garrison Commander", characters, characters_by_id,
				bal_w2, bal_c2,
			)
			if not lord_vacancies.has(lord_id):
				lord_vacancies[lord_id] = []
			lord_vacancies[lord_id].append({
				"position_type": "Garrison Commander",
				"priority": 3,
				"province_id": s.province_id,
				"settlement_id": s.settlement_id,
				"candidate_id": candidate,
				"seasons_vacant": 0,
			})
			# Mark as found so we don't duplicate per settlement
			if not filled_positions.has(lord_id):
				filled_positions[lord_id] = []
			filled_positions[lord_id].append("Garrison Commander (pending)")

		if s.settlement_type == Enums.SettlementType.TEMPLE and not _has_position(lord_positions, "Temple Head"):
			var bal_w3: float = cunning_balance_weight if lord_id == emperor_id else 0.0
			var bal_c3: Dictionary = emperor_clan_counts if lord_id == emperor_id else {}
			var candidate: int = _find_vacancy_candidate(
				lord_id, "Temple Head", characters, characters_by_id,
				bal_w3, bal_c3,
			)
			if not lord_vacancies.has(lord_id):
				lord_vacancies[lord_id] = []
			lord_vacancies[lord_id].append({
				"position_type": "Temple Head",
				"priority": 2,
				"province_id": s.province_id,
				"settlement_id": s.settlement_id,
				"candidate_id": candidate,
				"seasons_vacant": 0,
			})
			if not filled_positions.has(lord_id):
				filled_positions[lord_id] = []
			filled_positions[lord_id].append("Temple Head (pending)")

		if s.settlement_type == Enums.SettlementType.MONASTERY and not _has_position(lord_positions, "Monastery Abbot"):
			var bal_w4: float = cunning_balance_weight if lord_id == emperor_id else 0.0
			var bal_c4: Dictionary = emperor_clan_counts if lord_id == emperor_id else {}
			var candidate: int = _find_vacancy_candidate(
				lord_id, "Monastery Abbot", characters, characters_by_id,
				bal_w4, bal_c4,
			)
			if not lord_vacancies.has(lord_id):
				lord_vacancies[lord_id] = []
			lord_vacancies[lord_id].append({
				"position_type": "Monastery Abbot",
				"priority": 2,
				"province_id": s.province_id,
				"settlement_id": s.settlement_id,
				"candidate_id": candidate,
				"seasons_vacant": 0,
			})
			if not filled_positions.has(lord_id):
				filled_positions[lord_id] = []
			filled_positions[lord_id].append("Monastery Abbot (pending)")

	# School Master vacancies: one per family that has a canonical school
	var clan_lord_map: Dictionary = {}
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if c.lord_id >= 0:
			continue
		if c.status < 5.0:
			continue
		var existing_status: float = -1.0
		if clan_lord_map.has(c.clan):
			var existing_lord: L5RCharacterData = characters_by_id.get(clan_lord_map[c.clan], null)
			if existing_lord != null:
				existing_status = existing_lord.status
		if c.status > existing_status:
			clan_lord_map[c.clan] = c.character_id

	# Check if each family's school master exists under the clan lord
	var school_master_families: Dictionary = {}
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if _has_position([c.role_position], "School Master"):
			school_master_families[c.family] = true

	for fam: String in GempukkuSystem.FAMILY_DEFAULT_SCHOOL:
		if school_master_families.has(fam):
			continue
		var clan: String = _family_to_clan(fam)
		if clan.is_empty():
			continue
		var lord_id: int = clan_lord_map.get(clan, -1)
		if lord_id < 0:
			continue
		var lord_positions: Array = filled_positions.get(lord_id, [])
		var family_key: String = "School Master (%s)" % fam
		if _has_position(lord_positions, family_key):
			continue
		var bal_w5: float = cunning_balance_weight if lord_id == emperor_id else 0.0
		var bal_c5: Dictionary = emperor_clan_counts if lord_id == emperor_id else {}
		var candidate: int = _find_vacancy_candidate(
			lord_id, "School Master", characters, characters_by_id,
			bal_w5, bal_c5,
		)
		if not lord_vacancies.has(lord_id):
			lord_vacancies[lord_id] = []
		lord_vacancies[lord_id].append({
			"position_type": "School Master",
			"priority": 2,
			"province_id": -1,
			"candidate_id": candidate,
			"seasons_vacant": 0,
			"family": fam,
		})
		if not filled_positions.has(lord_id):
			filled_positions[lord_id] = []
		filled_positions[lord_id].append(family_key)

	# Inherit seasons_vacant from persistent registry
	var registry: Dictionary = season_meta.get("vacancy_registry", {})
	var new_registry: Dictionary = {}
	for lord_id: int in lord_vacancies:
		for v: Dictionary in lord_vacancies[lord_id]:
			var vkey: String = _vacancy_key(lord_id, v)
			if registry.has(vkey):
				v["seasons_vacant"] = registry[vkey]
			new_registry[vkey] = v.get("seasons_vacant", 0)
	season_meta["vacancy_registry"] = new_registry

	# Store per-lord vacancy data keyed by lord_id
	world_states["vacancy_data"] = lord_vacancies

	# Also store flat vacancy list for each lord in their world_states context
	for lord_id: int in lord_vacancies:
		var key: String = "vacant_positions_%d" % lord_id
		world_states[key] = lord_vacancies[lord_id]


static func _vacancy_key(lord_id: int, v: Dictionary) -> String:
	var pos_type: String = v.get("position_type", "")
	var family: String = v.get("family", "")
	var settlement_id: int = v.get("settlement_id", -1)
	var unit_id: int = v.get("unit_id", -1)
	if not family.is_empty():
		return "%d_%s_%s" % [lord_id, pos_type, family]
	if settlement_id >= 0:
		return "%d_%s_s%d" % [lord_id, pos_type, settlement_id]
	if unit_id >= 0:
		return "%d_%s_u%d" % [lord_id, pos_type, unit_id]
	return "%d_%s" % [lord_id, pos_type]


static func _increment_vacancy_seasons(season_meta: Dictionary) -> void:
	var registry: Dictionary = season_meta.get("vacancy_registry", {})
	for vkey: String in registry:
		registry[vkey] = registry[vkey] + 1
	season_meta["vacancy_registry"] = registry


static func _has_position(positions: Array, substring: String) -> bool:
	for p: Variant in positions:
		if p is String and (p as String).contains(substring):
			return true
	return false


static func _family_to_clan(family: String) -> String:
	for clan: String in WorldPopulationGenerator.CLAN_FAMILIES:
		var families: Array = WorldPopulationGenerator.CLAN_FAMILIES[clan]
		if family in families:
			return clan
	return ""


const POSITION_SKILL_WEIGHTS: Dictionary = {
	"Clan Magistrate": ["Investigation", "Lore: Law", "Etiquette"],
	"Emerald Magistrate": ["Investigation", "Lore: Law", "Etiquette"],
	"Garrison Commander": ["Battle", "Defense", "Kenjutsu"],
	"military_commander": ["Battle", "War", "Kenjutsu"],
	"Temple Head": ["Theology", "Meditation", "Lore: Theology"],
	"Monastery Abbot": ["Theology", "Meditation", "Jiujutsu"],
	"School Master": ["Lore: Theology", "Instruction"],
}

const POSITION_VIRTUE_BONUSES: Dictionary = {
	"Clan Magistrate": [Enums.BushidoVirtue.GI, Enums.BushidoVirtue.MEIYO],
	"Emerald Magistrate": [Enums.BushidoVirtue.GI, Enums.BushidoVirtue.MEIYO],
	"Garrison Commander": [Enums.BushidoVirtue.YU, Enums.BushidoVirtue.CHUGI],
	"military_commander": [Enums.BushidoVirtue.YU, Enums.BushidoVirtue.CHUGI],
	"Temple Head": [Enums.BushidoVirtue.REI, Enums.BushidoVirtue.JIN],
	"Monastery Abbot": [Enums.BushidoVirtue.REI, Enums.BushidoVirtue.JIN],
	"School Master": [Enums.BushidoVirtue.MEIYO, Enums.BushidoVirtue.GI],
}

const POSITION_SCHOOL_TYPE_BONUS: Dictionary = {
	"Temple Head": [Enums.SchoolType.SHUGENJA, Enums.SchoolType.MONK],
	"Monastery Abbot": [Enums.SchoolType.MONK],
}


static func _find_vacancy_candidate(
	lord_id: int,
	position_type: String,
	characters: Array[L5RCharacterData],
	_characters_by_id: Dictionary,
	clan_balance_weight: float = 0.0,
	clan_position_counts: Dictionary = {},
) -> int:
	var best_id: int = -1
	var best_score: float = -999.0
	var skill_keys: Array = POSITION_SKILL_WEIGHTS.get(position_type, [])
	var virtue_list: Array = POSITION_VIRTUE_BONUSES.get(position_type, [])
	var school_types: Array = POSITION_SCHOOL_TYPE_BONUS.get(position_type, [])
	var avg_positions: float = 0.0
	if clan_balance_weight > 0.0 and not clan_position_counts.is_empty():
		var total: float = 0.0
		for clan_name: String in clan_position_counts:
			total += float(clan_position_counts[clan_name])
		avg_positions = total / float(clan_position_counts.size())
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if c.lord_id != lord_id:
			continue
		if c.character_id == lord_id:
			continue
		if not c.role_position.is_empty():
			continue
		# Base: status + honor + glory (same as before)
		var score: float = c.status + c.honor + c.glory
		# Loyalty: disposition toward lord (weight 0.1)
		var disp: int = c.disposition_values.get(lord_id, 0)
		score += float(disp) * 0.1
		# Competence: relevant skill ranks (weight 1.0 each)
		for skill_name: Variant in skill_keys:
			score += float(c.skills.get(skill_name, 0))
		# Personality fit: virtue bonus (+3 per matching virtue)
		if c.bushido_virtue in virtue_list:
			score += 3.0
		# School type fit: bonus for matching school type (+2)
		if not school_types.is_empty() and c.school_type in school_types:
			score += 2.0
		if clan_balance_weight > 0.0 and not clan_position_counts.is_empty():
			var clan_count: float = float(clan_position_counts.get(c.clan, 0))
			score += (avg_positions - clan_count) * clan_balance_weight / 100.0
		if score > best_score:
			best_score = score
			best_id = c.character_id
	return best_id


static func _compute_clan_position_counts(
	lord_id: int,
	characters: Array[L5RCharacterData],
) -> Dictionary:
	var counts: Dictionary = {}
	for c: L5RCharacterData in characters:
		if CharacterStats.is_dead(c):
			continue
		if c.lord_id != lord_id:
			continue
		if c.role_position.is_empty():
			continue
		counts[c.clan] = counts.get(c.clan, 0) + 1
	return counts


# -- Court Commitment Wiring ---------------------------------------------------

static func _inject_commitment_needs(
	court_commitments: Array[CourtCommitmentData],
	characters: Array[L5RCharacterData],
	world_states: Dictionary,
) -> void:
	for cc: CourtCommitmentData in court_commitments:
		if cc.fulfilled:
			continue
		var lord_id: int = cc.lord_id
		var ws: Dictionary = world_states.get(lord_id, {})
		if ws.is_empty():
			ws = {}
			world_states[lord_id] = ws
		if not ws.has("pending_events"):
			ws["pending_events"] = []
		var already_injected: bool = false
		for ev: Variant in ws["pending_events"]:
			if ev is Dictionary and ev.get("source", "") == "commitment_honor" \
					and ev.get("topic_id", -1) == cc.topic_id:
				already_injected = true
				break
		if already_injected:
			continue
		var virtue: Enums.BushidoVirtue = Enums.BushidoVirtue.NONE
		for c: L5RCharacterData in characters:
			if c.character_id == lord_id:
				virtue = c.bushido_virtue
				break
		var priority: int = CourtCommitmentSystem.get_priority(virtue)
		ws["pending_events"].append({
			"need_type": "HONOR_COMMITMENT",
			"priority": priority,
			"topic_id": cc.topic_id,
			"commitment_type": cc.commitment_type,
			"source": "commitment_honor",
		})


static func _process_commitment_seasonal(
	court_commitments: Array[CourtCommitmentData],
	action_log: Array[Dictionary],
	ic_day: int,
	characters_by_id: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
) -> Dictionary:
	if court_commitments.is_empty():
		return {}
	var result: Dictionary = CourtCommitmentSystem.process_seasonal_commitments(
		court_commitments, action_log, ic_day, characters_by_id,
	)
	for renege_info: Dictionary in result.get("reneged", []):
		var lord_id: int = renege_info.get("lord_id", -1)
		var lord: L5RCharacterData = characters_by_id.get(lord_id)
		if lord == null:
			continue
		var honor_change: float = renege_info.get("honor_change", 0.0)
		if honor_change != 0.0:
			HonorGlorySystem.apply_honor_change(lord, honor_change)
		var disp_penalty: int = renege_info.get("disposition_penalty", 0)
		if disp_penalty != 0:
			for other: L5RCharacterData in characters_by_id.values():
				if other.character_id == lord_id:
					continue
				if other.disposition_values.has(lord_id):
					other.disposition_values[lord_id] = clampi(
						other.disposition_values[lord_id] + disp_penalty, -100, 100,
					)
		# Apply permanent historical modifier to each witness (s15.2).
		var witness_ids: Array = renege_info.get("witness_ids", [])
		if not witness_ids.is_empty():
			var renege_mod: Dictionary = DispositionSystem.create_historical_modifier(
				"reneged_commitment", ic_day,
			)
			if not renege_mod.is_empty():
				for wid: Variant in witness_ids:
					if int(wid) == lord_id:
						continue
					var witness: L5RCharacterData = characters_by_id.get(int(wid))
					if witness == null:
						continue
					if not witness.historical_modifiers.has(lord_id):
						witness.historical_modifiers[lord_id] = []
					(witness.historical_modifiers[lord_id] as Array).append(renege_mod.duplicate())

		var topic_tier: int = renege_info.get("topic_tier", 3)
		var topic_type: String = renege_info.get("topic_type", "renege")
		var topic_variant: String = renege_info.get("topic_variant", "commitment_broken")
		var topic_id: int = next_topic_id[0]
		next_topic_id[0] += 1
		var topic: TopicData = TopicData.new()
		topic.topic_id = topic_id
		topic.slug = "renege_%d_%d" % [lord_id, renege_info.get("topic_id", 0)]
		topic.tier = topic_tier
		topic.topic_type = topic_type
		topic.variant = topic_variant
		topic.momentum = TopicMomentumSystem.MOMENTUM_MINOR_FLOOR if topic_tier >= 3 else _COMBAT_EVENT_MOMENTUM
		topic.category = TopicData.Category.POLITICAL
		topic.ic_day_created = ic_day
		active_topics.append(topic)
	return result


static func _process_voluntary_declarations(
	applied_results: Array,
	active_courts: Array[CourtSessionData],
	active_topics: Array[TopicData],
	court_commitments: Array[CourtCommitmentData],
	characters_by_id: Dictionary,
	ic_day: int,
	time_system: TimeSystem,
) -> Array[CourtCommitmentData]:
	## Scans day results for successful PUBLIC_DECLARATION actions. When the
	## declaring lord's position exceeds +50 on an agenda action topic at their
	## current court, creates a voluntary CourtCommitmentData per GDD s16.4.
	var created: Array[CourtCommitmentData] = []
	for result: Variant in applied_results:
		if not result is Dictionary:
			continue
		var d: Dictionary = result as Dictionary
		if d.get("action_id", "") != "PUBLIC_DECLARATION":
			continue
		var effects: Dictionary = d.get("effects", {})
		if effects.get("failed", false):
			continue
		var lord_id: int = d.get("character_id", -1)
		var lord: L5RCharacterData = characters_by_id.get(lord_id)
		if lord == null:
			continue
		if not _is_lord_tier(lord):
			continue
		var court: CourtSessionData = _find_active_court_for_character(
			active_courts, lord_id,
		)
		if court == null:
			continue
		var declarable: Array[TopicData] = CourtCommitmentSystem.find_declarable_topics(
			lord, court.agenda_topic_ids, active_topics, court_commitments,
		)
		if declarable.is_empty():
			continue
		var topic: TopicData = declarable[0]
		var commitment_type: String = ImperialEdictSystem.get_commitment_type_for_topic(topic)
		var deadline: int = _compute_next_season_end_ic_day(time_system)
		var cc: CourtCommitmentData = CourtCommitmentSystem.create_commitment(
			lord_id, topic.topic_id, commitment_type,
			CourtCommitmentData.CommitmentSource.VOLUNTARY,
			ic_day, deadline,
		)
		cc.witness_ids = court.attendee_ids.duplicate()
		court_commitments.append(cc)
		created.append(cc)
	return created


static func _find_active_court_for_character(
	active_courts: Array[CourtSessionData],
	character_id: int,
) -> CourtSessionData:
	for court: CourtSessionData in active_courts:
		if court.phase != CourtSessionData.CourtPhase.ACTIVE:
			continue
		if character_id in court.attendee_ids:
			return court
	return null


static func _compute_next_season_end_ic_day(time_system: TimeSystem) -> int:
	## Returns the last IC day of the next season (deadline for voluntary
	## commitments per GDD s16.4: "default: last day of the next IC season").
	var day_of_year: int = time_system.get_ic_day_of_year()
	var ic_day: int = time_system.get_ic_day()
	# Season end boundaries (cumulative): Spring=90, Summer=180, Autumn=240, Winter=360
	var ends: Array[int] = [90, 180, 240, 360]
	# Find the NEXT season boundary after current day_of_year, then add one more
	var found_current_end: bool = false
	for e: int in ends:
		if day_of_year < e:
			if not found_current_end:
				found_current_end = true
				continue
			return ic_day + (e - day_of_year) - 1
	# Wrapped: next season end is Spring of next year
	return ic_day + (360 - day_of_year) + 90 - 1


# -- Court Action Effects (s15.4) ---------------------------------------------

static func _process_court_action_effects(
	day_results: Array,
	characters_by_id: Dictionary,
	favors: Array = [],
	ic_day: int = 0,
	emperor_id: int = -1,
	emperor_archetype: int = StrategicReview.EmperorArchetype.IRON,
) -> void:
	for entry: Dictionary in day_results:
		var effects: Dictionary = entry.get("effects", {})
		if effects.is_empty():
			continue

		var action_id: String = entry.get("action_id", "")
		var actor_id: int = entry.get("character_id", -1)
		var target_id: int = entry.get("target_npc_id", -1)
		var target: L5RCharacterData = characters_by_id.get(target_id)
		var action_meta: Dictionary = effects.get("_action_metadata", {})

		# Tyrant court honor penalty: opposing the Emperor costs -0.5 Honor
		if emperor_archetype == StrategicReview.EmperorArchetype.TYRANT and emperor_id >= 0:
			var triggers_penalty: bool = false
			if target_id == emperor_id and effects.has("target_position_shift"):
				triggers_penalty = true
			if action_id == "PUBLIC_DEBATE" and target_id == emperor_id:
				triggers_penalty = true
			if triggers_penalty:
				var actor: L5RCharacterData = characters_by_id.get(actor_id)
				if actor != null:
					HonorGlorySystem.apply_honor_change(actor, StrategicReview.TYRANT_COURT_HONOR_PENALTY)

		# Topic position shift from Negotiate/Persuade
		if effects.has("target_position_shift") and target != null:
			var shift: float = effects["target_position_shift"]
			var topic_id: int = action_meta.get("topic_id", -1)
			if topic_id >= 0:
				var current_pos: float = target.topic_positions.get(topic_id, 0.0)
				target.topic_positions[topic_id] = clampf(current_pos + shift, -100.0, 100.0)

		# Provoke Emotion target effects
		if target != null:
			if effects.has("target_honor_change"):
				HonorGlorySystem.apply_honor_change(target, effects["target_honor_change"])
			if effects.has("target_glory_change"):
				HonorGlorySystem.apply_glory_change(target, effects["target_glory_change"])

		# Provoke Emotion witness disposition loss against target
		if effects.has("target_witness_disposition"):
			var per_witness: int = effects["target_witness_disposition"]
			var witnesses: Array = effects.get("witnesses", [])
			for wid in witnesses:
				var w: L5RCharacterData = characters_by_id.get(wid)
				if w != null and target_id >= 0:
					var current: int = w.disposition_values.get(target_id, 0)
					w.disposition_values[target_id] = clampi(current + per_witness, -100, 100)

		# Play a Game bilateral disposition
		if effects.has("play_game_result") and target != null:
			var actor_id: int = entry.get("character_id", -1)
			var actor: L5RCharacterData = characters_by_id.get(actor_id)
			if actor != null:
				var a_disp: int = effects.get("a_disposition_toward_b", 0)
				var b_disp: int = effects.get("b_disposition_toward_a", 0)
				var cur_a: int = actor.disposition_values.get(target_id, 0)
				actor.disposition_values[target_id] = clampi(cur_a + a_disp, -100, 100)
				var cur_b: int = target.disposition_values.get(actor_id, 0)
				target.disposition_values[actor_id] = clampi(cur_b + b_disp, -100, 100)

		# Gossip subject disposition on listener
		if effects.has("gossip_subject_disposition") and target != null:
			var subject_id: int = effects.get("gossip_subject_id", -1)
			var disp_change: int = effects["gossip_subject_disposition"]
			if subject_id >= 0:
				var cur: int = target.disposition_values.get(subject_id, 0)
				target.disposition_values[subject_id] = clampi(cur + disp_change, -100, 100)

		# Disclose downstream opinion transfer
		if effects.has("disclosed_opinion") and target != null:
			var about_id: int = effects.get("disclose_about_id", -1)
			var opinion: int = effects["disclosed_opinion"]
			if about_id >= 0 and opinion != 0:
				var cur: int = target.disposition_values.get(about_id, 0)
				var shift: int = int(opinion * 0.5)
				if shift != 0:
					target.disposition_values[about_id] = clampi(cur + shift, -100, 100)

		# OFFER_FAVOR creation
		if effects.get("requires_favor_creation", false):
			var creditor_id: int = effects.get("favor_creditor_id", -1)
			var debtor_id: int = effects.get("favor_debtor_id", -1)
			if creditor_id >= 0 and debtor_id >= 0:
				var max_id: int = 0
				for f: Variant in favors:
					if f is FavorData and (f as FavorData).favor_id >= max_id:
						max_id = (f as FavorData).favor_id + 1
				var favor: FavorData = FavorSystem.offer_favor(
					FavorData.FavorType.GENERAL,
					FavorData.FavorTier.MINOR,
					creditor_id,
					debtor_id,
					ic_day,
					"Court favor offered",
					"OFFER_FAVOR",
					max_id,
				)
				favors.append(favor)

		# Public Debate per-witness disposition and position shifts
		if effects.has("debate_per_witness"):
			var actor_id: int = entry.get("character_id", -1)
			var topic_id: int = action_meta.get("topic_id", -1)
			var pw_results: Array = effects["debate_per_witness"]
			for pw: Dictionary in pw_results:
				var wid: int = pw.get("witness_id", -1)
				var w: L5RCharacterData = characters_by_id.get(wid)
				if w == null:
					continue
				var a_disp_change: int = pw.get("a_disposition_change", 0)
				var b_disp_change: int = pw.get("b_disposition_change", 0)
				if a_disp_change != 0:
					var cur: int = w.disposition_values.get(actor_id, 0)
					w.disposition_values[actor_id] = clampi(cur + a_disp_change, -100, 100)
				if b_disp_change != 0:
					var cur: int = w.disposition_values.get(target_id, 0)
					w.disposition_values[target_id] = clampi(cur + b_disp_change, -100, 100)
				if topic_id >= 0:
					var pos_shift: float = pw.get("position_shift_toward_a", 0.0)
					if pos_shift != 0.0:
						var cur_pos: float = w.topic_positions.get(topic_id, 0.0)
						w.topic_positions[topic_id] = clampf(cur_pos + pos_shift, -100.0, 100.0)


# -- Court Availability Data Population ----------------------------------------


static func _populate_court_availability_data(
	active_courts: Array[CourtSessionData],
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	world_states: Dictionary,
	favors: Array,
) -> void:
	var upcoming: Array[Dictionary] = []
	for court: CourtSessionData in active_courts:
		if court.court_phase == CourtSessionData.CourtPhase.SCHEDULED:
			upcoming.append({
				"settlement_id": court.host_settlement_id,
				"prestige": court.prestige,
				"court_id": court.court_id,
			})

	var creditor_favors: Dictionary = {}
	for fv: Variant in favors:
		if fv is FavorData:
			var f: FavorData = fv as FavorData
			if f.invoked or f.creditor_id < 0:
				continue
			if not creditor_favors.has(f.creditor_id):
				creditor_favors[f.creditor_id] = []
			var debtor: Variant = characters_by_id.get(f.debtor_id)
			var target_lord: int = -1
			if debtor is L5RCharacterData:
				target_lord = (debtor as L5RCharacterData).lord_id
			creditor_favors[f.creditor_id].append({
				"debtor_id": f.debtor_id,
				"target_lord_id": target_lord,
				"tier": f.tier,
			})

	for c: L5RCharacterData in characters:
		var ws: Dictionary = world_states.get(c.character_id, {})
		if ws.is_empty():
			ws = {}
			world_states[c.character_id] = ws

		ws["upcoming_courts"] = upcoming
		ws["held_leverage"] = creditor_favors.get(c.character_id, [] as Array[Dictionary])

		var locations: Dictionary = {}
		for entry: KnowledgeEntry in c.knowledge_pool:
			if entry.entry_type == "location":
				var cid: int = entry.data.get("character_id", -1)
				var sid_str: String = str(entry.data.get("settlement_id", ""))
				if cid >= 0 and sid_str.is_valid_int():
					locations[cid] = int(sid_str)
		ws["known_npc_locations"] = locations


# -- Resource Stockpiles Population --------------------------------------------


static func _populate_resource_stockpiles(
	world_states: Dictionary,
	characters: Array[L5RCharacterData],
	provinces: Dictionary,
	settlements: Array[SettlementData],
	clans: Dictionary,
	companies: Array[Dictionary],
) -> void:
	var clan_settlements: Dictionary = {}
	for s: SettlementData in settlements:
		var pid: int = s.province_id
		var prov: Variant = provinces.get(pid)
		if prov == null or not (prov is ProvinceData):
			continue
		var clan_name: String = (prov as ProvinceData).clan
		if clan_name.is_empty():
			continue
		if not clan_settlements.has(clan_name):
			clan_settlements[clan_name] = []
		clan_settlements[clan_name].append(s)

	var clan_military_upkeep: Dictionary = {}
	for comp: Dictionary in companies:
		var comp_clan: String = comp.get("clan", "")
		if comp_clan.is_empty():
			continue
		var rice_cost: float = comp.get("rice_upkeep", 0.35)
		clan_military_upkeep[comp_clan] = clan_military_upkeep.get(comp_clan, 0.0) + rice_cost

	for c: L5RCharacterData in characters:
		if c.status < 5.0 and c.lord_id != -1:
			continue
		var ws: Dictionary = world_states.get(c.character_id, {})
		if ws.is_empty():
			ws = {}
			world_states[c.character_id] = ws

		var slist: Array = clan_settlements.get(c.clan, [])
		var total_rice: float = 0.0
		var total_koku: float = 0.0
		var total_pop_pu: float = 0.0
		var total_rice_consumption: float = 0.0
		var total_military_pu: float = 0.0
		for sv: Variant in slist:
			if sv is SettlementData:
				var sd: SettlementData = sv as SettlementData
				total_rice += sd.rice_stockpile
				total_koku += sd.koku_stockpile
				total_pop_pu += sd.population_pu
				total_rice_consumption += sd.population_pu * 0.25
				total_military_pu += sd.military_pu

		var clan_data: Variant = clans.get(c.clan)
		var arms: float = 0.0
		var iron: float = 0.0
		if clan_data is ClanData:
			arms = (clan_data as ClanData).arms_stockpile
			iron = (clan_data as ClanData).iron_stockpile

		var arms_upkeep: float = 0.0
		for comp: Dictionary in companies:
			if comp.get("clan", "") == c.clan:
				arms_upkeep += comp.get("iron_upkeep", 0.1)

		ws["resource_stockpiles"] = {
			"rice": total_rice,
			"rice_consumption": maxf(total_rice_consumption, 0.01),
			"koku": total_koku,
			"population_pu": maxf(total_pop_pu, 1.0),
			"arms": arms,
			"arms_upkeep": maxf(arms_upkeep, 0.01),
			"iron": iron,
			"military_upkeep": maxf(clan_military_upkeep.get(c.clan, 0.0), 0.01),
		}
		ws["available_levy_pu"] = total_military_pu


# -- Crime Suppression Data (s11.3.19) -----------------------------------------

static func _populate_crime_suppression_data(
	world_states: Dictionary,
	settlements: Array[SettlementData],
	provinces: Dictionary,
	current_season: int,
) -> void:
	var is_planting_or_harvest: bool = (
		current_season == TimeSystem.Season.SPRING
		or current_season == TimeSystem.Season.AUTUMN
	)

	var doshin_losses_map: Dictionary = world_states.get("_doshin_losses", {})

	var per_settlement: Dictionary = {}
	for s: SettlementData in settlements:
		var prov: Variant = provinces.get(s.province_id)
		var stability: int = 50
		if prov is ProvinceData:
			stability = int((prov as ProvinceData).stability)

		var size: CrimeSuppressionSystem.SettlementSize = _classify_settlement_size(s)
		var losses: int = int(doshin_losses_map.get(s.settlement_id, 0))

		var available: int = CrimeSuppressionSystem.get_available_doshin(
			size, losses, is_planting_or_harvest, stability
		)
		var bonus: int = CrimeSuppressionSystem.get_doshin_investigation_bonus(available)
		var suppression_bonus: int = CrimeSuppressionSystem.get_doshin_suppression_bonus(available)

		per_settlement[s.settlement_id] = {
			"doshin_available": available,
			"doshin_investigation_bonus": bonus,
			"doshin_suppression_bonus": suppression_bonus,
			"max_recruitable": CrimeSuppressionSystem.get_max_recruitable(available),
		}

	world_states["_crime_suppression_data"] = per_settlement


static func _process_doshin_seasonal_recovery(world_states: Dictionary) -> void:
	var losses_map: Dictionary = world_states.get("_doshin_losses", {})
	if losses_map.is_empty():
		return
	var keys_to_erase: Array = []
	for settlement_id: Variant in losses_map:
		var current_losses: int = int(losses_map[settlement_id])
		var new_losses: int = CrimeSuppressionSystem.process_doshin_recovery(current_losses)
		if new_losses <= 0:
			keys_to_erase.append(settlement_id)
		else:
			losses_map[settlement_id] = new_losses
	for k: Variant in keys_to_erase:
		losses_map.erase(k)


static func _classify_settlement_size(s: SettlementData) -> CrimeSuppressionSystem.SettlementSize:
	var pu: int = s.population_pu
	if pu >= 20:
		return CrimeSuppressionSystem.SettlementSize.MAJOR_CITY
	if pu >= 10:
		return CrimeSuppressionSystem.SettlementSize.CITY
	if pu >= 5:
		return CrimeSuppressionSystem.SettlementSize.TOWN
	if pu >= 2:
		return CrimeSuppressionSystem.SettlementSize.CASTLE_TOWN
	if pu >= 1:
		return CrimeSuppressionSystem.SettlementSize.LARGE_VILLAGE
	if pu > 0:
		return CrimeSuppressionSystem.SettlementSize.VILLAGE
	return CrimeSuppressionSystem.SettlementSize.REMOTE


# -- Civil War Seasonal Processing (s53.2) ------------------------------------

static func _process_civil_war_seasonal(
	active_civil_wars: Array[Dictionary],
	precedent_modifiers: Dictionary,
	characters_by_id: Dictionary,
	provinces: Dictionary,
	current_season: int,
	objectives_map: Dictionary,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	season_meta: Dictionary,
	companies: Array[Dictionary] = [],
	active_edicts: Array[EdictData] = [],
	togashi_state: Dictionary = {},
) -> Dictionary:
	var precedent_decay_count: int = IntraClanCivilWar.tick_precedent_decay(
		precedent_modifiers, current_season,
	)
	var per_war_results: Array[Dictionary] = []
	var defections: Array[Dictionary] = []
	var resolutions: Array[Dictionary] = []

	for state: Dictionary in active_civil_wars:
		if not state.get("active", false):
			continue
		var clan: String = state.get("clan", "")
		var rebel_lord_id: int = int(state.get("rebel_lord_id", -1))
		var authority_lord_id: int = int(state.get("authority_lord_id", -1))
		var rebel_lord: L5RCharacterData = characters_by_id.get(rebel_lord_id)
		var authority_lord: L5RCharacterData = characters_by_id.get(authority_lord_id)

		var clan_provinces: Array[ProvinceData] = []
		for prov: Variant in provinces.values():
			if prov is ProvinceData and (prov as ProvinceData).clan == clan:
				clan_provinces.append(prov as ProvinceData)

		var suppress_hem: bool = state.get("suppress_honor_hemorrhage", false)
		var consequence_result: Dictionary = IntraClanCivilWar.apply_seasonal_consequences(
			state, rebel_lord, clan_provinces, current_season, suppress_hem,
		)

		# Phoenix schism: each dead Master costs the Champion −0.5 Honor (s55.10.3.7).
		var master_deaths: int = _apply_phoenix_master_death_honor_penalty(state, characters_by_id)
		if master_deaths > 0:
			consequence_result["phoenix_master_deaths_penalized"] = master_deaths

		# Dragon schism: re-evaluate loyalty when spiritual concern worsens (s55.10.2.8).
		var spiritual_defections: Array[Dictionary] = _apply_dragon_spiritual_reeval(
			state, togashi_state, characters_by_id, objectives_map,
		)
		if not spiritual_defections.is_empty():
			consequence_result["spiritual_reeval_defections"] = spiritual_defections
			defections.append_array(spiritual_defections)

		_apply_civil_war_edict_shifts(state, rebel_lord_id, authority_lord_id, active_edicts)

		var war_defections: Array[Dictionary] = _check_civil_war_defections(
			state, characters_by_id, objectives_map, current_season,
		)
		defections.append_array(war_defections)

		var resolution: Dictionary = _check_civil_war_resolution(
			state, rebel_lord, authority_lord, characters_by_id,
			precedent_modifiers, current_season, active_topics,
			next_topic_id, ic_day, season_meta, clan,
			provinces, companies, null,
		)
		if not resolution.is_empty():
			resolutions.append(resolution)

		per_war_results.append({
			"clan": clan,
			"consequence_result": consequence_result,
			"defection_count": war_defections.size(),
		})

	_decay_civil_war_scars(characters_by_id, season_meta)

	return {
		"precedent_decay_count": precedent_decay_count,
		"per_war": per_war_results,
		"defections": defections,
		"resolutions": resolutions,
	}


static func _check_civil_war_defections(
	state: Dictionary,
	characters_by_id: Dictionary,
	objectives_map: Dictionary,
	current_season: int,
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	var assignments: Dictionary = state.get("faction_assignments", {})
	var rebel_lord_id: int = int(state.get("rebel_lord_id", -1))
	var authority_lord_id: int = int(state.get("authority_lord_id", -1))
	var trigger_topic_id: int = int(state.get("trigger_topic_id", -1))

	for char_id_var: Variant in assignments.keys():
		var char_id: int = int(char_id_var)
		var faction: int = int(assignments.get(char_id, IntraClanCivilWar.Faction.NONE))
		if faction == IntraClanCivilWar.Faction.NONE or faction == IntraClanCivilWar.Faction.RONIN:
			continue
		var npc: L5RCharacterData = characters_by_id.get(char_id)
		if npc == null:
			continue
		if CharacterStats.is_dead(npc):
			continue
		var faction_leader_id: int = (
			authority_lord_id if faction == IntraClanCivilWar.Faction.LEGITIMACY
			else rebel_lord_id
		)
		if not IntraClanCivilWar.defection_trigger_fired(state, npc, faction_leader_id):
			continue

		var rebel_completion: float = _get_rebel_completion_rate(rebel_lord_id, objectives_map)
		var grievance_visible: bool = trigger_topic_id in npc.topic_pool
		var rebel_was_failing: bool = rebel_completion < 0.50
		var is_phoenix: bool = state.get("clan", "") == "Phoenix"
		var loyalty: Dictionary = IntraClanCivilWar.evaluate_loyalty(
			npc, rebel_lord_id, rebel_completion, grievance_visible, rebel_was_failing, is_phoenix,
		)
		var new_faction: int = int(loyalty.get("faction", IntraClanCivilWar.Faction.NONE))
		if new_faction == faction:
			continue

		var is_family_daimyo: bool = npc.status >= 5.0
		var to_legitimacy: bool = new_faction == IntraClanCivilWar.Faction.LEGITIMACY
		IntraClanCivilWar.record_defection(state, char_id, is_family_daimyo, to_legitimacy)

		var former_members: Array[L5RCharacterData] = []
		for other_id_var: Variant in assignments.keys():
			var other_id: int = int(other_id_var)
			if other_id == char_id:
				continue
			var other_faction: int = int(assignments.get(other_id, IntraClanCivilWar.Faction.NONE))
			if other_faction == faction:
				var other: L5RCharacterData = characters_by_id.get(other_id)
				if other != null:
					former_members.append(other)
		IntraClanCivilWar.apply_defection_consequences(npc, former_members)

		results.append({
			"character_id": char_id,
			"from_faction": faction,
			"to_faction": new_faction,
			"is_family_daimyo": is_family_daimyo,
		})
	return results


static func _check_civil_war_resolution(
	state: Dictionary,
	rebel_lord: L5RCharacterData,
	authority_lord: L5RCharacterData,
	characters_by_id: Dictionary,
	precedent_modifiers: Dictionary,
	current_season: int,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	season_meta: Dictionary,
	clan: String,
	provinces: Dictionary = {},
	companies: Array[Dictionary] = [],
	rng: RandomNumberGenerator = null,
) -> Dictionary:
	var rebel_dead: bool = rebel_lord == null or CharacterStats.is_dead(rebel_lord)
	if rebel_dead:
		# Phoenix schism: Champion death triggers reincarnation (s55.10.3.7).
		# The new Champion's personality determines whether the schism auto-resolves.
		if clan == "Phoenix":
			var reincarnation_rng: RandomNumberGenerator = rng
			if reincarnation_rng == null:
				reincarnation_rng = RandomNumberGenerator.new()
			var reincarnation: Dictionary = SuccessionSystem.resolve_shiba_reincarnation(
				characters_by_id, reincarnation_rng
			)
			var new_champ_id: int = int(reincarnation.get("new_champion_id", -1))
			var new_champ: L5RCharacterData = characters_by_id.get(new_champ_id)
			if new_champ != null:
				var duty_score: int = 70 if new_champ.bushido_virtue == Enums.BushidoVirtue.CHUGI else 30
				var avg_disp: int = _compute_avg_council_disposition(new_champ, characters_by_id)
				var outcome: Dictionary = PhoenixCouncil.evaluate_reincarnation_schism_outcome(
					new_champ, avg_disp, duty_score
				)
				if not outcome.get("capitulates", true):
					# Schism continues — update rebel_lord_id to the new Champion.
					state["rebel_lord_id"] = new_champ_id
					return {}
				# Capitulates → fall through to Legitimacy Victory below.
		return _resolve_civil_war(
			state, true, characters_by_id, precedent_modifiers,
			current_season, active_topics, next_topic_id, ic_day,
			season_meta, clan, companies,
		)

	var rebel_capitulated: bool = false
	var holds_seat: bool = _rebel_holds_seat(rebel_lord, provinces)
	var rebel_seat_lost: bool = not holds_seat

	if IntraClanCivilWar.check_legitimacy_victory(
		state, rebel_lord, rebel_capitulated, rebel_seat_lost,
	):
		return _resolve_civil_war(
			state, true, characters_by_id, precedent_modifiers,
			current_season, active_topics, next_topic_id, ic_day,
			season_meta, clan, companies,
		)

	var assignments: Dictionary = state.get("faction_assignments", {})
	var has_allied_fd: bool = false
	for cid_var: Variant in assignments.keys():
		var cid: int = int(cid_var)
		if int(assignments[cid]) != IntraClanCivilWar.Faction.REBEL:
			continue
		if cid == int(state.get("rebel_lord_id", -1)):
			continue
		var c: L5RCharacterData = characters_by_id.get(cid)
		if c != null and not CharacterStats.is_dead(c) and c.status >= 5.0:
			has_allied_fd = true
			break

	IntraClanCivilWar.tick_rebel_victory_counter(
		state, rebel_lord, holds_seat, has_allied_fd,
	)

	if IntraClanCivilWar.is_rebel_victory_achieved(state):
		return _resolve_civil_war(
			state, false, characters_by_id, precedent_modifiers,
			current_season, active_topics, next_topic_id, ic_day,
			season_meta, clan, companies,
		)

	return {}


static func _resolve_civil_war(
	state: Dictionary,
	legitimacy_won: bool,
	characters_by_id: Dictionary,
	precedent_modifiers: Dictionary,
	current_season: int,
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	season_meta: Dictionary,
	clan: String,
	companies: Array[Dictionary] = [],
) -> Dictionary:
	var assignments: Dictionary = state.get("faction_assignments", {})
	var all_chars: Array[L5RCharacterData] = []
	for cid_var: Variant in assignments.keys():
		var c: L5RCharacterData = characters_by_id.get(int(cid_var))
		if c != null:
			all_chars.append(c)

	var scar_result: Dictionary = IntraClanCivilWar.apply_post_resolution_scars(
		state, all_chars,
	)
	var scar_entries: Array[Dictionary] = []
	for s: Dictionary in scar_result.get("scars", []):
		var entry: Dictionary = s.duplicate()
		entry["base_remaining"] = IntraClanCivilWar.POST_WAR_SCAR_BASE
		scar_entries.append(entry)
	if not scar_entries.is_empty():
		var all_scars: Array = season_meta.get("civil_war_scars", [])
		all_scars.append_array(scar_entries)
		season_meta["civil_war_scars"] = all_scars

	var rebel_consequences: Dictionary = {}
	var from_seizure: bool = false
	if legitimacy_won:
		var rebels: Array[L5RCharacterData] = []
		var family_daimyo_ids: Array[int] = []
		for cid_var: Variant in assignments.keys():
			var cid: int = int(cid_var)
			if int(assignments[cid]) == IntraClanCivilWar.Faction.REBEL:
				var c: L5RCharacterData = characters_by_id.get(cid)
				if c != null:
					rebels.append(c)
					if c.status >= 5.0:
						family_daimyo_ids.append(cid)
		rebel_consequences = IntraClanCivilWar.apply_rebel_consequences_on_legitimacy_victory(
			rebels, family_daimyo_ids,
		)
	else:
		var rebel_lord_id: int = int(state.get("rebel_lord_id", -1))
		var rebel_lord: L5RCharacterData = characters_by_id.get(rebel_lord_id)
		var was_fd: bool = rebel_lord != null and rebel_lord.status >= 5.0
		var authority_lord: L5RCharacterData = characters_by_id.get(
			int(state.get("authority_lord_id", -1))
		)
		var incumbent_gone: bool = authority_lord == null or CharacterStats.is_dead(authority_lord) or authority_lord.honor < 0.0
		from_seizure = IntraClanCivilWar.can_seize_championship(
			state, clan, was_fd, incumbent_gone,
		)
		IntraClanCivilWar.apply_precedent_effect(
			precedent_modifiers, current_season, from_seizure,
		)

	IntraClanCivilWar.finalise(state, current_season, legitimacy_won)

	var reconstitution: Dictionary = _reconstitute_clan_military(
		state, legitimacy_won, companies, characters_by_id,
	)

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] += 1
	var topic: TopicData = TopicData.new()
	topic.topic_id = topic_id
	topic.slug = "civil_war_resolved_%s_%d" % [clan.to_lower(), ic_day]
	topic.tier = 2
	topic.topic_type = "civil_war"
	topic.variant = "legitimacy_victory" if legitimacy_won else ("championship_seizure" if from_seizure else "rebel_victory")
	topic.momentum = _CIVIL_WAR_MOMENTUM
	topic.category = TopicData.Category.POLITICAL
	topic.ic_day_created = ic_day
	active_topics.append(topic)

	# Clan-specific victory flags to be applied by the caller to the
	# appropriate governance state dict (s55.10.2.8, s55.10.3.7).
	var victory_flags: Dictionary = {}
	if not legitimacy_won:
		if clan == "Dragon":
			# FC wins autonomous rule; Oversight System suspends for FC's lifetime.
			victory_flags["dragon_autonomous_rule"] = true
		elif clan == "Phoenix":
			# Champion wins sole authority; Council vote requirement suspended.
			victory_flags["phoenix_champion_authority"] = true

	return {
		"clan": clan,
		"legitimacy_won": legitimacy_won,
		"from_seizure": from_seizure,
		"scar_count": scar_entries.size(),
		"rebel_consequences": rebel_consequences,
		"topic_id": topic_id,
		"reconstitution": reconstitution,
		"victory_flags": victory_flags,
	}


## Dragon schism seasonal spiritual re-evaluation (s55.10.2.8).
## When dissatisfaction on any concern axis has risen since the schism began,
## Togashi is being proved right — loyalty re-evaluates for all non-auto-assigned
## Dragon NPCs still on the REBEL faction. Those who flip are moved to LEGITIMACY
## and the war score shifts accordingly (provincial-daimyo weight by status).
## Returns an array of defection records compatible with the main defection list.
static func _apply_dragon_spiritual_reeval(
	state: Dictionary,
	togashi_state: Dictionary,
	characters_by_id: Dictionary,
	objectives_map: Dictionary,
) -> Array[Dictionary]:
	if state.get("clan", "") != "Dragon":
		return []
	if togashi_state.is_empty():
		return []
	var snapshot: Dictionary = state.get("concern_snapshot", {})
	if snapshot.is_empty():
		return []
	var current_dissat: Dictionary = togashi_state.get("dissatisfaction", {})
	# Check whether any axis has worsened (higher dissatisfaction than at trigger).
	var worsened: bool = false
	for axis_var: Variant in current_dissat.keys():
		var current_val: float = float(current_dissat[axis_var])
		var snap_val: float = float(snapshot.get(axis_var, 0.0))
		if current_val > snap_val:
			worsened = true
			break
	if not worsened:
		return []
	# Re-evaluate all REBEL-faction Dragon NPCs (Togashi monks are already auto-LEGITIMACY).
	var assignments: Dictionary = state.get("faction_assignments", {})
	var rebel_lord_id: int = int(state.get("rebel_lord_id", -1))
	var rebel_completion: float = _get_rebel_completion_rate(rebel_lord_id, objectives_map)
	var topic_id: int = int(state.get("trigger_topic_id", -1))
	var defections: Array[Dictionary] = []
	for cid_var: Variant in assignments.keys():
		var cid: int = int(cid_var)
		if int(assignments[cid]) != IntraClanCivilWar.Faction.REBEL:
			continue
		if cid == rebel_lord_id:
			continue
		var npc: L5RCharacterData = characters_by_id.get(cid)
		if npc == null or CharacterStats.is_dead(npc):
			continue
		if npc.family == "Togashi":
			continue  # auto-assigned, never re-evaluate
		# Re-evaluate with strong grievance: concern proved Togashi right (rebel_was_failing = false).
		var loyalty: Dictionary = IntraClanCivilWar.evaluate_loyalty(
			npc, rebel_lord_id, rebel_completion, topic_id in npc.topic_pool, false,
		)
		var new_faction: int = int(loyalty.get("faction", IntraClanCivilWar.Faction.LEGITIMACY))
		if new_faction == IntraClanCivilWar.Faction.LEGITIMACY:
			var was_fd: bool = npc.status >= 5.0
			IntraClanCivilWar.record_defection(state, cid, was_fd, true)
			defections.append({
				"character_id": cid,
				"from_faction": IntraClanCivilWar.Faction.REBEL,
				"to_faction": IntraClanCivilWar.Faction.LEGITIMACY,
				"reason": "spiritual_reeval",
			})
	return defections


## For an active Phoenix civil war, scans all Masters assigned LEGITIMACY.
## For each dead Master not yet penalized, applies −0.5 Honor to the Champion
## (per s55.10.3.7: "Each Master killed generates −0.5 Honor for the Champion").
## The Champion is the rebel_lord in the Defiance path and authority_lord in
## the Overreach path. Uses schism_path to determine which.
## Returns the count of newly penalized Masters this tick.
static func _compute_avg_council_disposition(
	new_champion: L5RCharacterData,
	characters_by_id: Dictionary,
) -> int:
	## Computes the average disposition of a new Phoenix Champion toward the
	## Elemental Council Masters. Used by the post-reincarnation schism
	## evaluation (s55.10.3.7).
	var total: int = 0
	var count: int = 0
	var master_positions: Array[String] = [
		"Master of Fire", "Master of Water", "Master of Air",
		"Master of Earth", "Master of Void",
	]
	for c: L5RCharacterData in characters_by_id.values():
		if c.role_position in master_positions and not CharacterStats.is_dead(c):
			total += int(new_champion.disposition_values.get(c.character_id, 0))
			count += 1
	if count == 0:
		return 0
	return int(total / count)


static func _apply_phoenix_master_death_honor_penalty(
	state: Dictionary,
	characters_by_id: Dictionary,
) -> int:
	if state.get("clan", "") != "Phoenix":
		return 0
	var assignments: Dictionary = state.get("faction_assignments", {})
	var penalized: Array = state.get("master_death_penalized_ids", [])
	var schism_path: String = state.get("schism_path", "")
	var champion_id: int = (
		int(state.get("rebel_lord_id", -1)) if schism_path == "defiance"
		else int(state.get("authority_lord_id", -1))
	)
	var champion: L5RCharacterData = characters_by_id.get(champion_id)
	if champion == null:
		return 0
	var penalty_count: int = 0
	for cid_var: Variant in assignments.keys():
		var cid: int = int(cid_var)
		if cid in penalized:
			continue
		if int(assignments[cid]) != IntraClanCivilWar.Faction.LEGITIMACY:
			continue
		var master: L5RCharacterData = characters_by_id.get(cid)
		if master == null:
			continue
		if not master.role_position.begins_with("Master of "):
			continue
		if CharacterStats.is_dead(master):
			HonorGlorySystem.apply_honor_change(champion, -0.5)
			penalized.append(cid)
			penalty_count += 1
	state["master_death_penalized_ids"] = penalized
	return penalty_count


static func _get_rebel_completion_rate(
	rebel_lord_id: int,
	objectives_map: Dictionary,
) -> float:
	var lord_obj: Variant = objectives_map.get(rebel_lord_id)
	if lord_obj is Dictionary:
		var primary: Variant = (lord_obj as Dictionary).get("primary")
		if primary is Dictionary:
			return float((primary as Dictionary).get("last_measured_progress", 0.5))
	return 0.5


## Returns true when the rebel lord's physical location is a settlement
## inside their family's home province — per s53.2.7 "losing their seat of power".
static func _rebel_holds_seat(
	rebel_lord: L5RCharacterData,
	provinces: Dictionary,
) -> bool:
	if rebel_lord == null:
		return false
	if provinces.is_empty():
		return true  # no province data → cannot confirm seat lost; assume held
	if not rebel_lord.physical_location.is_valid_int():
		return false
	var loc_settlement_id: int = int(rebel_lord.physical_location)
	for prov_var: Variant in provinces.values():
		if not (prov_var is ProvinceData):
			continue
		var prov: ProvinceData = prov_var as ProvinceData
		if prov.clan == rebel_lord.clan and prov.family == rebel_lord.family:
			return loc_settlement_id in prov.settlement_ids
	return false


## Post-resolution reconstitution per s53.2.3:
## Clears commanders on the losing side from their companies (Step 1),
## then consolidates pairs of understrength companies (Step 3).
## Step 2 (unit march to friendly territory) and Step 4 (FILL_VACANCY) are
## handled downstream: stranded units are already detached, and vacancies are
## signalled in the return dict for the strategic review to issue FILL_VACANCY.
static func _reconstitute_clan_military(
	state: Dictionary,
	legitimacy_won: bool,
	companies: Array[Dictionary],
	characters_by_id: Dictionary,
) -> Dictionary:
	var assignments: Dictionary = state.get("faction_assignments", {})
	var losing_faction: int = (
		IntraClanCivilWar.Faction.REBEL if legitimacy_won
		else IntraClanCivilWar.Faction.LEGITIMACY
	)
	var vacancies_created: int = 0
	var companies_dissolved: int = 0
	var clan_companies: Array[Dictionary] = []
	for cd: Dictionary in companies:
		var cmd_id: int = cd.get("commander_id", -1)
		if cmd_id < 0:
			continue
		if not assignments.has(cmd_id):
			continue
		var faction: int = int(assignments[cmd_id])
		clan_companies.append(cd)
		if faction == losing_faction:
			cd["commander_id"] = -1
			vacancies_created += 1
		else:
			var commander: L5RCharacterData = characters_by_id.get(cmd_id)
			if commander == null or CharacterStats.is_dead(commander):
				cd["commander_id"] = -1
				vacancies_created += 1
	# Step 3: consolidate understrength pairs (health < 50% of starting).
	var understrength: Array[Dictionary] = []
	for cd: Dictionary in clan_companies:
		var start_hp: int = cd.get("starting_health", 153)
		var cur_hp: int = cd.get("current_health", start_hp)
		if cur_hp < start_hp / 2:
			understrength.append(cd)
	var i: int = 0
	while i + 1 < understrength.size():
		var absorber: Dictionary = understrength[i]
		var dissolved: Dictionary = understrength[i + 1]
		var start_hp: int = absorber.get("starting_health", 153)
		var combined: int = absorber.get("current_health", 0) + dissolved.get("current_health", 0)
		absorber["current_health"] = mini(combined, start_hp)
		dissolved["current_health"] = 0
		dissolved["is_destroyed"] = true
		companies_dissolved += 1
		i += 2
	return {
		"vacancies_created": vacancies_created,
		"companies_dissolved": companies_dissolved,
	}


## Scans active edicts for those that shift civil war score per s53.2.5.
## Only CONDEMN_CLAN edicts targeting the rebel or authority lord (by
## target_character_id) are mapped — clan-level edicts are ambiguous in a
## civil war and are skipped to avoid inventing mechanics.
## Processed edict IDs are stored in state["processed_edict_ids"] to prevent
## double-counting across seasonal ticks.
static func _apply_civil_war_edict_shifts(
	state: Dictionary,
	rebel_lord_id: int,
	authority_lord_id: int,
	active_edicts: Array[EdictData],
) -> void:
	var processed: Array = state.get("processed_edict_ids", [])
	for edict: EdictData in active_edicts:
		if not edict.is_active:
			continue
		if edict.edict_id in processed:
			continue
		if edict.edict_type != EdictData.EdictType.CONDEMN_CLAN:
			continue
		var target_char: int = edict.target_character_id
		if target_char == rebel_lord_id:
			IntraClanCivilWar.record_imperial_edict(state, true)
			processed.append(edict.edict_id)
		elif target_char == authority_lord_id:
			IntraClanCivilWar.record_imperial_edict(state, false)
			processed.append(edict.edict_id)
	state["processed_edict_ids"] = processed


static func _decay_civil_war_scars(
	characters_by_id: Dictionary,
	season_meta: Dictionary,
) -> void:
	var all_scars: Array = season_meta.get("civil_war_scars", [])
	if all_scars.is_empty():
		return
	var chars_array: Array[L5RCharacterData] = []
	for c: Variant in characters_by_id.values():
		if c is L5RCharacterData:
			chars_array.append(c as L5RCharacterData)
	var typed_scars: Array[Dictionary] = []
	for s: Variant in all_scars:
		if s is Dictionary:
			typed_scars.append(s as Dictionary)
	IntraClanCivilWar.decay_post_war_scars(chars_array, typed_scars)
	var remaining: Array = []
	for entry: Dictionary in typed_scars:
		if int(entry.get("base_remaining", 0)) < 0:
			remaining.append(entry)
	season_meta["civil_war_scars"] = remaining


# -- Civil War Trigger & Faction Formation (s53.2.1, s53.2.2) ----------------

static func _trigger_civil_war(
	rebel_lord_id: int,
	authority_lord_id: int,
	clan: String,
	order_type: String,
	characters: Array[L5RCharacterData],
	characters_by_id: Dictionary,
	objectives_map: Dictionary,
	active_civil_wars: Array[Dictionary],
	active_topics: Array[TopicData],
	next_topic_id: Array[int],
	ic_day: int,
	current_season: int,
	suppress_honor_hemorrhage: bool = false,
	schism_path: String = "",
	concern_snapshot: Dictionary = {},
) -> Dictionary:
	## Triggers an intra-clan civil war per GDD s53.2.1. Creates initial state,
	## generates the Tier 2 crisis topic, evaluates loyalty for all named clan
	## NPCs, and processes ronin departures.
	## Returns a result dict describing what happened.

	for existing: Dictionary in active_civil_wars:
		if existing.get("active", false) and existing.get("clan", "") == clan:
			return {"triggered": false, "reason": "already_active"}

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] += 1
	var topic := TopicData.new()
	topic.topic_id = topic_id
	var rebel: L5RCharacterData = characters_by_id.get(rebel_lord_id)
	var authority: L5RCharacterData = characters_by_id.get(authority_lord_id)
	var rebel_name: String = rebel.character_name if rebel != null else "Unknown"
	var auth_name: String = authority.character_name if authority != null else "Unknown"
	topic.slug = "civil_war_%s_%s_refuses_%s_%d" % [
		clan.to_lower(), rebel_name.to_lower().replace(" ", "_"),
		order_type.to_lower().replace(" ", "_"), ic_day,
	]
	topic.tier = TopicData.Tier.TIER_2
	topic.topic_type = "civil_war"
	topic.variant = "civil_war_triggered"
	topic.momentum = _CIVIL_WAR_MOMENTUM
	topic.category = TopicData.Category.POLITICAL
	topic.ic_day_created = ic_day
	active_topics.append(topic)

	var state: Dictionary = IntraClanCivilWar.make_initial_state(
		rebel_lord_id, authority_lord_id, clan, topic_id, current_season,
	)
	if suppress_honor_hemorrhage:
		state["suppress_honor_hemorrhage"] = true
	if not schism_path.is_empty():
		state["schism_path"] = schism_path
	# Dragon schism: treaty credibility reduced during crisis (s55.10.2.8).
	if clan == "Dragon":
		state["dragon_treaty_penalty"] = -15
	# Snapshot concern axis dissatisfaction at trigger for seasonal re-evaluation.
	if not concern_snapshot.is_empty():
		state["concern_snapshot"] = concern_snapshot.duplicate()

	var rebel_completion: float = _get_rebel_completion_rate(rebel_lord_id, objectives_map)
	var rebel_was_failing: bool = rebel_completion < 0.50

	var clan_npcs: Array[L5RCharacterData] = []
	for c: L5RCharacterData in characters:
		if c.clan == clan and not CharacterStats.is_dead(c):
			clan_npcs.append(c)

	var family_daimyo: Array[L5RCharacterData] = []
	var others: Array[L5RCharacterData] = []
	for c: L5RCharacterData in clan_npcs:
		if c.character_id == rebel_lord_id or c.character_id == authority_lord_id:
			continue
		if c.status >= 5.0:
			family_daimyo.append(c)
		else:
			others.append(c)

	IntraClanCivilWar.assign_faction(
		state, rebel_lord_id, IntraClanCivilWar.Faction.REBEL,
	)
	IntraClanCivilWar.assign_faction(
		state, authority_lord_id, IntraClanCivilWar.Faction.LEGITIMACY,
	)

	var ronin_departures: Array[int] = []
	var faction_counts: Dictionary = {
		IntraClanCivilWar.Faction.LEGITIMACY: 1,
		IntraClanCivilWar.Faction.REBEL: 1,
		IntraClanCivilWar.Faction.RONIN: 0,
	}

	# Dragon: Togashi Order monks side with Togashi unconditionally (s55.10.2.8).
	# Phoenix: All Isawa (including Masters) side with the Council unconditionally (s55.10.3.7).
	# Removed from the general evaluation pool — they do not evaluate loyalty.
	var auto_legitimacy_families: Array[String] = []
	if clan == "Dragon":
		auto_legitimacy_families = ["Togashi"]
	elif clan == "Phoenix":
		auto_legitimacy_families = ["Isawa"]

	var all_to_evaluate: Array[L5RCharacterData] = []
	for npc: L5RCharacterData in family_daimyo:
		if npc.family in auto_legitimacy_families:
			IntraClanCivilWar.assign_faction(state, npc.character_id, IntraClanCivilWar.Faction.LEGITIMACY)
			faction_counts[IntraClanCivilWar.Faction.LEGITIMACY] = int(faction_counts.get(IntraClanCivilWar.Faction.LEGITIMACY, 0)) + 1
		else:
			all_to_evaluate.append(npc)
	for npc: L5RCharacterData in others:
		if npc.family in auto_legitimacy_families:
			IntraClanCivilWar.assign_faction(state, npc.character_id, IntraClanCivilWar.Faction.LEGITIMACY)
			faction_counts[IntraClanCivilWar.Faction.LEGITIMACY] = int(faction_counts.get(IntraClanCivilWar.Faction.LEGITIMACY, 0)) + 1
		else:
			all_to_evaluate.append(npc)

	var is_phoenix_war: bool = clan == "Phoenix"
	for npc: L5RCharacterData in all_to_evaluate:
		var grievance_visible: bool = topic_id in npc.topic_pool
		var loyalty: Dictionary = IntraClanCivilWar.evaluate_loyalty(
			npc, rebel_lord_id, rebel_completion, grievance_visible,
			rebel_was_failing, is_phoenix_war,
		)
		var faction: int = int(loyalty.get("faction", IntraClanCivilWar.Faction.LEGITIMACY))

		if faction == IntraClanCivilWar.Faction.RONIN:
			IntraClanCivilWar.apply_ronin_departure(npc)
			RoninSystem.make_ronin(npc, RoninSystem.RoninCause.VOLUNTARY_DEPARTURE)
			npc.permanent_ronin = true
			ronin_departures.append(npc.character_id)
			faction_counts[IntraClanCivilWar.Faction.RONIN] = int(faction_counts.get(IntraClanCivilWar.Faction.RONIN, 0)) + 1
		else:
			IntraClanCivilWar.assign_faction(state, npc.character_id, faction)
			faction_counts[faction] = int(faction_counts.get(faction, 0)) + 1

	_reassign_broken_feudal_chains(state, characters_by_id, rebel_lord_id, authority_lord_id)

	active_civil_wars.append(state)

	return {
		"triggered": true,
		"clan": clan,
		"rebel_lord_id": rebel_lord_id,
		"authority_lord_id": authority_lord_id,
		"topic_id": topic_id,
		"faction_counts": faction_counts,
		"ronin_departures": ronin_departures,
	}


static func _reassign_broken_feudal_chains(
	state: Dictionary,
	characters_by_id: Dictionary,
	rebel_lord_id: int,
	authority_lord_id: int,
) -> void:
	## When a vassal and their immediate lord are on opposite factions,
	## reassign the vassal's lord_id to the highest-ranking member of
	## their own faction in the chain. Per GDD s53.2.2.
	var assignments: Dictionary = state.get("faction_assignments", {})
	for cid_var: Variant in assignments.keys():
		var cid: int = int(cid_var)
		var npc: L5RCharacterData = characters_by_id.get(cid)
		if npc == null:
			continue
		var npc_faction: int = int(assignments.get(cid, IntraClanCivilWar.Faction.NONE))
		if npc_faction == IntraClanCivilWar.Faction.NONE:
			continue

		var lord: L5RCharacterData = characters_by_id.get(npc.lord_id)
		if lord == null:
			continue
		var lord_faction: int = int(assignments.get(lord.character_id, IntraClanCivilWar.Faction.NONE))
		if lord_faction == npc_faction:
			continue

		var best_lord_id: int = rebel_lord_id if npc_faction == IntraClanCivilWar.Faction.REBEL else authority_lord_id
		var best_status: float = -1.0
		for other_id_var: Variant in assignments.keys():
			var other_id: int = int(other_id_var)
			if other_id == cid:
				continue
			if int(assignments.get(other_id, IntraClanCivilWar.Faction.NONE)) != npc_faction:
				continue
			var other: L5RCharacterData = characters_by_id.get(other_id)
			if other == null:
				continue
			if other.status > best_status:
				best_status = other.status
				best_lord_id = other_id
		npc.lord_id = best_lord_id
