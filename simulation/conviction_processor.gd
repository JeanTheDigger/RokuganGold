class_name ConvictionProcessor
## Processes cases that have reached ACCUSED status through the conviction
## pipeline: defense hearing → sentencing → conviction consequences → seppuku
## offer → topic generation. Called from DayOrchestrator each tick.
##
## Pipeline per case:
##   1. Identify accused, convicting lord, and crime record
##   2. Run defense hearing (treason-specific or generic)
##   3. If defense succeeds: acquit, apply false-accusation penalty to lord
##   4. If defense fails: sentence via SentencingSystem, apply conviction
##      consequences via CrimeSystem, generate conviction topic
##   5. If seppuku offered: mark record; NPC engine handles accept/refuse


const DEFENSE_HEARING_DAYS_AFTER_ACCUSATION: int = 3


static func process_accused_cases(
	crime_records: Array,
	characters_by_id: Dictionary,
	dice_engine: DiceEngine,
	ic_day: int,
	next_topic_id: Array,
	active_topics: Array,
	lord_map: Dictionary,
) -> Array:
	var results: Array = []

	for record: CrimeRecord in crime_records:
		if record.legal_status != Enums.LegalStatus.ACCUSED:
			continue
		if record.ic_day_conviction >= 0:
			continue

		var accused: L5RCharacterData = characters_by_id.get(record.perpetrator_id)
		if accused == null or CharacterStats.is_dead(accused):
			continue

		var lord_id: int = lord_map.get(record.perpetrator_id, -1)
		var lord: L5RCharacterData = characters_by_id.get(lord_id)
		if lord == null or CharacterStats.is_dead(lord):
			continue

		var case_entry: LegalCaseEntry = LegalStatusSystem.get_case(
			accused, record.case_id
		)

		if case_entry != null and case_entry.accusation_timestamp >= 0:
			if ic_day - case_entry.accusation_timestamp < DEFENSE_HEARING_DAYS_AFTER_ACCUSATION:
				continue

		var result := _process_single_case(
			record, case_entry, accused, lord, dice_engine, ic_day,
			next_topic_id, active_topics, characters_by_id
		)
		if not result.is_empty():
			results.append(result)

	return results


static func _process_single_case(
	record: CrimeRecord,
	case_entry: LegalCaseEntry,
	accused: L5RCharacterData,
	lord: L5RCharacterData,
	dice_engine: DiceEngine,
	ic_day: int,
	next_topic_id: Array,
	active_topics: Array,
	characters_by_id: Dictionary,
) -> Dictionary:
	var hearing := _run_defense_hearing(
		record, case_entry, accused, lord, dice_engine
	)

	if hearing.get("defense_succeeded", false):
		_apply_acquittal(record, case_entry, accused, lord, ic_day)
		return {
			"case_id": record.case_id,
			"accused_id": accused.character_id,
			"outcome": "acquitted",
			"defense_succeeded": true,
			"evidence_halved_to": hearing.get("evidence_halved_to", 0),
			"lord_honor_change": hearing.get("lord_honor_change", 0.0),
			"lord_disposition_hit": hearing.get("lord_disposition_hit", 0),
		}

	if hearing.get("blocked", false):
		return {
			"case_id": record.case_id,
			"accused_id": accused.character_id,
			"outcome": "blocked",
			"reason": hearing.get("reason", ""),
		}

	if hearing.get("trial_by_combat_demanded", false):
		return {
			"case_id": record.case_id,
			"accused_id": accused.character_id,
			"outcome": "trial_by_combat_pending",
		}

	var victim: L5RCharacterData = characters_by_id.get(record.victim_id)
	var victim_status: float = victim.status if victim != null else 0.0
	var victim_clan: String = victim.clan if victim != null else ""
	var is_cross_clan: bool = not victim_clan.is_empty() and victim_clan != accused.clan

	var crime_consequences: Array = CrimeSystem.CONVICTION_CONSEQUENCES.get(
		record.crime_type, [-0.1, 0.0, 0.0, TopicData.Tier.TIER_4]
	)
	var crime_tier: int = int(crime_consequences[3])
	var sentencing := SentencingSystem.select_punishment(
		lord, record, crime_tier, is_cross_clan, false
	)

	var conviction := CrimeSystem.apply_at_conviction_consequences(
		accused, record, victim_status
	)

	record.legal_status = Enums.LegalStatus.DECREED_GUILTY
	record.ic_day_conviction = ic_day

	if case_entry != null:
		LegalStatusSystem.transition(
			case_entry, Enums.LegalStatus.DECREED_GUILTY, ic_day
		)

	var conviction_topic: TopicData = InvestigationSystem.generate_conviction_topic(
		record, accused, conviction.get("topic_tier", TopicData.Tier.TIER_4), next_topic_id, ic_day
	)
	if conviction_topic != null:
		active_topics.append(conviction_topic)
		if conviction_topic.topic_id not in lord.topic_pool:
			lord.topic_pool.append(conviction_topic.topic_id)

	var seppuku_offered: bool = conviction.get("seppuku_offered", false)
	if seppuku_offered:
		record.seppuku_offered = true

	var result := {
		"case_id": record.case_id,
		"accused_id": accused.character_id,
		"outcome": "convicted",
		"crime_type": record.crime_type,
		"punishment": sentencing.get("punishment", -1),
		"leniency_score": sentencing.get("leniency_score", 0),
		"glory_delta": conviction.get("glory_delta", 0.0),
		"infamy_delta": conviction.get("infamy_delta", 0.0),
		"status_delta": conviction.get("status_delta", 0.0),
		"topic_tier": conviction.get("topic_tier", TopicData.Tier.TIER_4),
		"topic_id": conviction_topic.topic_id if conviction_topic != null else -1,
		"seppuku_offered": seppuku_offered,
		"is_cross_clan": is_cross_clan,
	}

	if record.crime_type == Enums.CrimeType.TREASON:
		var co_ids: Array = []
		for sid: int in record.known_suspects:
			if sid != accused.character_id:
				co_ids.append(sid)
		var naming := TreasonSystem.should_name_co_conspirators(lord.bushido_virtue)
		result["co_conspirators_named"] = naming["names_publicly"]
		result["co_conspirator_ids"] = co_ids

	return result


static func _run_defense_hearing(
	record: CrimeRecord,
	case_entry: LegalCaseEntry,
	accused: L5RCharacterData,
	lord: L5RCharacterData,
	dice_engine: DiceEngine,
) -> Dictionary:
	if record.crime_type == Enums.CrimeType.TREASON:
		var authority := TreasonSystem.can_convict(lord.status, accused.status)
		if authority["must_escalate"]:
			return {
				"blocked": true,
				"reason": "insufficient_authority",
			}

	var evidence_total: int = record.evidence_total
	if case_entry != null:
		evidence_total = case_entry.evidence_total

	var testimony_weight: int = RitsuyoSystem.get_testimony_weight(accused)

	if DefenseHearingSystem.can_demand_trial_by_combat(accused, record.crime_type):
		if DefenseHearingSystem.should_demand_trial(accused, testimony_weight, evidence_total):
			return {
				"trial_by_combat_demanded": true,
				"defense_succeeded": false,
				"proceed_to_judgment": false,
			}

	var sincerity_roll: int = _roll_sincerity_defense(accused, dice_engine)

	if record.crime_type == Enums.CrimeType.TREASON:
		var honor_rank: int = HonorGlorySystem.get_honor_rank(accused)
		var hearing := TreasonSystem.resolve_defense_hearing(
			sincerity_roll, evidence_total, honor_rank
		)
		if hearing["defense_succeeded"]:
			hearing["lord_honor_change"] = TreasonSystem.FALSE_ACCUSATION_HONOR_LOSS
			hearing["lord_disposition_hit"] = TreasonSystem.FALSE_ACCUSATION_DISPOSITION_HIT
		return hearing

	var hearing := DefenseHearingSystem.resolve_sincerity_defense(
		sincerity_roll, testimony_weight, evidence_total
	)
	return hearing


static func _roll_sincerity_defense(
	accused: L5RCharacterData,
	dice_engine: DiceEngine,
) -> int:
	if dice_engine == null:
		return 0
	var check: Dictionary = SkillResolver.resolve_skill_check(
		accused, dice_engine, "Sincerity", 0,
	)
	return check.get("total", 0)


static func _apply_acquittal(
	record: CrimeRecord,
	case_entry: LegalCaseEntry,
	_accused: L5RCharacterData,
	lord: L5RCharacterData,
	ic_day: int,
) -> void:
	if case_entry != null:
		LegalStatusSystem.acquit(case_entry, ic_day)

	record.legal_status = Enums.LegalStatus.ACQUITTED
	record.evidence_total = record.evidence_total / 2

	HonorGlorySystem.apply_honor_change(
		lord, TreasonSystem.FALSE_ACCUSATION_HONOR_LOSS
	)


# -- Seppuku Resolution (called separately after NPC decides) ---------

static func resolve_seppuku(
	record: CrimeRecord,
	convicted: L5RCharacterData,
	accepted: bool,
	ic_day: int,
	next_topic_id: Array,
) -> Dictionary:
	if not record.seppuku_offered:
		return {"applicable": false}

	if accepted:
		var result := CrimeSystem.apply_seppuku_accepted(convicted, record)
		return {
			"applicable": true,
			"accepted": true,
			"honor_delta": result.get("honor_delta", 0.0),
			"character_dead": true,
		}

	var result := CrimeSystem.apply_seppuku_refused(convicted, record)

	var refusal_topic: TopicData = InvestigationSystem.generate_seppuku_refusal_topic(
		convicted, next_topic_id, ic_day
	)

	var treason_exile := {}
	if record.crime_type == Enums.CrimeType.TREASON:
		treason_exile = TreasonSystem.apply_refused_seppuku()

	return {
		"applicable": true,
		"accepted": false,
		"honor_delta": result.get("honor_delta", 0.0),
		"infamy_delta": result.get("infamy_delta", 0.0),
		"refusal_topic_tier": result.get("topic_tier", TopicData.Tier.TIER_4),
		"refusal_topic_id": refusal_topic.topic_id if refusal_topic != null else -1,
		"refusal_topic": refusal_topic,
		"exile": record.crime_type == Enums.CrimeType.TREASON,
		"treason_exile": treason_exile,
	}


# -- Trial by Combat Resolution (s11.3.9f) ---------

static func resolve_trial_by_combat(
	record: CrimeRecord,
	accused: L5RCharacterData,
	lord: L5RCharacterData,
	dice_engine: DiceEngine,
	ic_day: int,
	characters_by_id: Dictionary,
) -> Dictionary:
	var accused_champion: L5RCharacterData = _select_champion(accused, characters_by_id)
	var accuser_champion: L5RCharacterData = _select_champion(lord, characters_by_id)

	var duel_result: Dictionary = IndividualCombat.resolve_full_duel(
		accused_champion, accuser_champion, true, dice_engine
	)

	var winner_id: int = duel_result.get("winner_id", -1)
	var simultaneous: bool = duel_result.get("simultaneous", false)

	var outcome: DefenseHearingSystem.TrialByCombatOutcome
	if simultaneous:
		outcome = DefenseHearingSystem.TrialByCombatOutcome.ACCUSED_LOSES
	elif winner_id == accused_champion.character_id:
		outcome = DefenseHearingSystem.TrialByCombatOutcome.ACCUSED_WINS
	else:
		outcome = DefenseHearingSystem.TrialByCombatOutcome.ACCUSED_LOSES

	var victim: L5RCharacterData = characters_by_id.get(record.victim_id)
	var victim_status: float = victim.status if victim != null else 0.0

	var trial_result: Dictionary = DefenseHearingSystem.get_trial_by_combat_result(
		outcome, victim_status
	)

	if trial_result.get("case_cleared", false):
		if outcome == DefenseHearingSystem.TrialByCombatOutcome.ACCUSED_WINS:
			record.legal_status = Enums.LegalStatus.ACQUITTED
			record.evidence_total = 0
		else:
			record.legal_status = Enums.LegalStatus.DECREED_GUILTY
			record.ic_day_conviction = ic_day

	return {
		"resolved": true,
		"outcome": outcome,
		"duel_result": duel_result,
		"trial_result": trial_result,
		"accused_champion_id": accused_champion.character_id,
		"accuser_champion_id": accuser_champion.character_id,
		"accused_won": outcome == DefenseHearingSystem.TrialByCombatOutcome.ACCUSED_WINS,
		"accused_dead": CharacterStats.is_dead(accused_champion),
		"accuser_dead": CharacterStats.is_dead(accuser_champion),
		"simultaneous": simultaneous,
	}


static func _select_champion(
	principal: L5RCharacterData,
	characters_by_id: Dictionary,
) -> L5RCharacterData:
	if principal.school_type == Enums.SchoolType.BUSHI:
		return principal
	for c: L5RCharacterData in characters_by_id.values():
		if c.operational_superior_id == principal.character_id \
				and c.school_type == Enums.SchoolType.BUSHI \
				and not CharacterStats.is_dead(c):
			return c
	return principal


# -- Cross-Clan Disposition (post-conviction) ---------

static func apply_cross_clan_consequences(
	record: CrimeRecord,
	accused: L5RCharacterData,
	victim: L5RCharacterData,
	cooperated: bool,
) -> Dictionary:
	if victim == null:
		return {"applies": false}

	return CrimeWiring.compute_cross_clan_disposition_change(
		record, accused, victim, cooperated
	)
