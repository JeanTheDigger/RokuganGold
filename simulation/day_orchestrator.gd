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
		day_result.get("applied", []),
		settlements,
		characters_by_id,
		companies,
	)

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
		# Miya's Blessing follow-up — topic generation, disposition deltas,
		# suspension penalties. Runs only on Spring transitions when the
		# blessing actually fired or was suspended.
		if current_season == TimeSystem.Season.SPRING:
			_process_miya_blessing_followup(
				seasonal_result, miya_inputs, provinces, characters_by_id,
				active_topics, next_topic_id, ic_day, season_meta,
			)
		_decay_all_historical_modifiers(characters, ic_day)
		military_seasonal_result = _process_military_seasonal(
			companies, settlements, clans, characters_by_id,
			dice_engine, _season_to_name(current_season),
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
	var movement_results: Array[Dictionary] = _process_army_movements(active_armies)
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
		"siege_results": siege_results,
		"tether_results": tether_results,
		"order_results": order_results,
		"deprivation_results": deprivation_results,
		"recovery_results": recovery_results,
	}


static func _process_army_movements(
	active_armies: Array[Dictionary],
) -> Array[Dictionary]:
	var results: Array[Dictionary] = []
	for army: Dictionary in active_armies:
		if not army.get("is_moving", false):
			continue
		var r: Dictionary = ArmyMovementSystem.process_movement_tick(army)
		if r.get("arrived", false):
			var battle_check: Dictionary = ArmyMovementSystem.check_battle_trigger(
				r, active_armies,
			)
			r["battle_check"] = battle_check
		results.append(r)
	return results


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
		var garrisons: Dictionary = tether.get("garrisons_on_path", {})
		var enemies: Array[int] = []
		for e: Variant in tether.get("enemy_armies_on_path", []):
			enemies.append(int(e))
		var r: Dictionary = SupplyTetherSystem.process_supply_tick(
			dice_engine, tether, garrisons, enemies, companies_by_id,
		)
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
	var result: Dictionary = {}
	for i: int in range(mini(active_tethers.size(), tether_results.size())):
		var army_id: int = active_tethers[i].get("army_id", -1)
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
	var results: Array[Dictionary] = []
	for i: int in range(mini(active_tethers.size(), tether_results.size())):
		var tether: Dictionary = active_tethers[i]
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
			"insight_rank": CharacterStats.get_insight_rank(CharacterStats.get_insight(c)),
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

	return {
		"type": "battle_pu_reconciliation",
		"casualties": r.get("casualties", {}),
		"recovery": r.get("recovery", {}),
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
