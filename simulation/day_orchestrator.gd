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

	var favor_results: Dictionary = _process_favors(favors, ic_day)

	var day_result: Dictionary = NPCWaveResolver.resolve_day_applied(
		characters, world_states, objectives_map, scoring_tables, filter_data,
		dice_engine, action_skill_map, characters_by_id, provinces, action_log,
		approach_penalties, commitments, military_data
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

	var commitment_results: Array[Dictionary] = _process_commitment_deadlines(
		commitments, ic_day, characters_by_id
	)

	var orphan_results: Array[Dictionary] = _process_lord_deaths(
		death_events, characters, objectives_map, successor_map
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
	if current_season != prev_season:
		seasonal_result = _process_season_transition(
			characters, provinces, current_season, season_meta,
			approach_penalties
		)
		_decay_all_historical_modifiers(characters, ic_day)
		progress_results = _evaluate_objective_progress(
			characters, objectives_map, world_states
		)
		strategic_results = _run_strategic_reviews(
			characters, objectives_map, world_states
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
	}


# -- AP Reset ------------------------------------------------------------------

static func _reset_all_ap(characters: Array[L5RCharacterData]) -> void:
	for c: L5RCharacterData in characters:
		ActionPointSystem.reset_daily_ap(c)
		c.civilian_orders_remaining = c.civilian_order_budget_max
		c.passage_request_count_today = 0


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

			if target_id > 0:
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
) -> Dictionary:
	_decay_all_knowledge(characters, current_season)

	var penalties_decayed: int = ApproachEvaluation.decay_penalties(
		approach_penalties, current_season
	)

	var province_array: Array[ProvinceData] = []
	for pid: int in provinces:
		province_array.append(provinces[pid])

	var season_name: String = _season_to_name(current_season)
	var settlements: Array[SettlementData] = []
	var tick_result: Dictionary = ResourceTick.process_seasonal_tick(
		province_array, settlements, season_name, season_meta
	)

	return {
		"season_name": season_name,
		"knowledge_decayed": true,
		"resource_tick": tick_result,
		"approach_penalties_decayed": penalties_decayed,
	}


static func _decay_all_knowledge(
	characters: Array[L5RCharacterData],
	current_season: int,
) -> void:
	for c: L5RCharacterData in characters:
		InformationSystem.decay_confidence(c, current_season)


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

	return all_results


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

	for lord: L5RCharacterData in characters:
		if not _is_lord_tier(lord):
			continue
		var vassals: Array[L5RCharacterData] = _get_vassals(lord, characters)
		var directives: Array[Dictionary] = StrategicReview.run_seasonal_review(
			lord, vassals, objectives_map, world_states
		)
		for d: Dictionary in directives:
			results.append(d)

	return results


static func _is_lord_tier(character: L5RCharacterData) -> bool:
	return character.status >= 5.0 or character.lord_id == -1


static func _get_vassals(
	lord: L5RCharacterData,
	characters: Array[L5RCharacterData],
) -> Array[L5RCharacterData]:
	var vassals: Array[L5RCharacterData] = []
	for c: L5RCharacterData in characters:
		if c.lord_id == lord.character_id:
			vassals.append(c)
	return vassals


# -- Festival Processing (s11.5) ----------------------------------------------

static func _process_festivals(ic_day: int, world_states: Dictionary) -> Dictionary:
	var active_festivals: Array[Dictionary] = FestivalSystem.get_active_festivals(ic_day)
	var effects: Array[String] = FestivalSystem.get_festival_effects(ic_day)
	var rokuyo_name: String = FestivalSystem.get_rokuyo_name(ic_day)
	var is_taian: bool = FestivalSystem.get_taian_bonus(ic_day) > 0
	var is_inauspicious: bool = FestivalSystem.is_inauspicious_for_social(ic_day)
	var is_ceasefire: bool = FestivalSystem.is_ceasefire_day(ic_day)
	var is_labor_halt: bool = FestivalSystem.is_labor_halt_day(ic_day)

	world_states["is_ceasefire_day"] = is_ceasefire
	world_states["is_labor_halt_day"] = is_labor_halt
	world_states["is_taian"] = is_taian
	world_states["is_inauspicious_for_social"] = is_inauspicious
	world_states["rokuyo"] = rokuyo_name

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

static func _process_favors(favors: Array, ic_day: int) -> Dictionary:
	var expired_ids: Array[int] = FavorSystem.process_expirations(favors, ic_day)

	var breach_results: Array[Dictionary] = FavorSystem.process_deadline_breaches(favors, ic_day)

	return {
		"expired_favor_ids": expired_ids,
		"deadline_breaches": breach_results,
	}


# -- Travel Processing (s55.29) -----------------------------------------------

static func _process_travel(
	characters: Array[L5RCharacterData],
) -> Array[Dictionary]:
	return TravelSystem.process_travel_tick(characters)


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
