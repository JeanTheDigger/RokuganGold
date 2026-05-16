class_name CrimeWiring
## Wiring layer that connects UnsanctionedKillingSystem and TreasonSystem
## to the existing CrimeSystem, InvestigationSystem, and SentencingSystem.
## Called from DayOrchestrator at the appropriate pipeline stages.


# -- Unsanctioned Killing: classify and create crime record ---------

static func process_killing_crime(
	effects: Dictionary,
	attacker: L5RCharacterData,
	victim: L5RCharacterData,
	case_id: int,
	ic_day: int,
	witnesses: Array[int],
	clans_at_war: bool,
	is_battlefield: bool,
	is_prisoner: bool,
	attacker_acted_first: bool,
	has_zone_log_evidence: bool,
) -> Dictionary:
	var wartime := UnsanctionedKillingSystem.is_wartime_exception(
		clans_at_war, is_battlefield, is_prisoner
	)
	if wartime["exception_applies"] and wartime.get("no_crime", false):
		return {
			"crime_created": false,
			"reason": wartime["reason"],
			"honor_loss": wartime.get("honor_loss", 0.0),
		}

	var self_defense := UnsanctionedKillingSystem.is_self_defense(
		attacker_acted_first, witnesses.size() > 0, has_zone_log_evidence
	)
	if self_defense.get("no_crime", false):
		return {
			"crime_created": false,
			"reason": "self_defense",
			"evidence_source": self_defense["evidence_source"],
		}

	var method_tier: UnsanctionedKillingSystem.KillingTier = _effects_to_killing_tier(effects)
	var classification := UnsanctionedKillingSystem.classify_killing(
		method_tier, attacker.status, victim.status
	)
	var effective_tier: UnsanctionedKillingSystem.KillingTier = classification["effective_tier"]
	var is_public: bool = witnesses.size() > 0

	var consequences := UnsanctionedKillingSystem.get_consequences(
		effective_tier, victim.status, is_public
	)

	var crime_type: Enums.CrimeType = _killing_tier_to_crime_type(effective_tier)
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		case_id, crime_type, attacker.character_id,
		attacker.physical_location, ic_day,
		victim.character_id, 0, witnesses
	)

	var jurisdiction := UnsanctionedKillingSystem.get_jurisdiction(
		attacker.clan, victim.clan
	)

	return {
		"crime_created": true,
		"record": record,
		"classification": classification,
		"consequences": consequences,
		"jurisdiction": jurisdiction,
		"crime_type": crime_type,
	}


static func _effects_to_killing_tier(effects: Dictionary) -> UnsanctionedKillingSystem.KillingTier:
	var crime_type: int = effects.get("crime_type", -1)
	match crime_type:
		Enums.CrimeType.UNSANCTIONED_DUEL_DEATH:
			return UnsanctionedKillingSystem.KillingTier.UNSANCTIONED_DUEL_DEATH
		Enums.CrimeType.UNSANCTIONED_OPEN_KILLING:
			return UnsanctionedKillingSystem.KillingTier.OPEN_KILLING
		Enums.CrimeType.UNSANCTIONED_COVERT_KILLING:
			return UnsanctionedKillingSystem.KillingTier.COVERT_KILLING
	if effects.get("covert", false):
		return UnsanctionedKillingSystem.KillingTier.COVERT_KILLING
	return UnsanctionedKillingSystem.KillingTier.OPEN_KILLING


static func _killing_tier_to_crime_type(
	tier: UnsanctionedKillingSystem.KillingTier,
) -> Enums.CrimeType:
	match tier:
		UnsanctionedKillingSystem.KillingTier.UNSANCTIONED_DUEL_DEATH:
			return Enums.CrimeType.UNSANCTIONED_DUEL_DEATH
		UnsanctionedKillingSystem.KillingTier.OPEN_KILLING:
			return Enums.CrimeType.UNSANCTIONED_OPEN_KILLING
		UnsanctionedKillingSystem.KillingTier.COVERT_KILLING:
			return Enums.CrimeType.UNSANCTIONED_COVERT_KILLING
	return Enums.CrimeType.UNSANCTIONED_OPEN_KILLING


# -- Treason: route evidence through treason-specific weights ---------

static func add_treason_evidence_to_case(
	case_entry: LegalCaseEntry,
	crime_record: CrimeRecord,
	evidence_type: TreasonSystem.TreasonEvidenceType,
	ic_day: int,
) -> Dictionary:
	if crime_record.crime_type != Enums.CrimeType.TREASON:
		return {"routed": false, "reason": "not_treason"}

	var result := TreasonSystem.add_treason_evidence(case_entry, evidence_type, ic_day)

	crime_record.evidence_total = case_entry.evidence_total

	var threshold_result: String = ""
	if result["crossed_threshold"]:
		if crime_record.legal_status != Enums.LegalStatus.ACCUSED \
				and crime_record.legal_status != Enums.LegalStatus.DECREED_GUILTY:
			crime_record.legal_status = Enums.LegalStatus.ACCUSED
			threshold_result = "accusation"

	result["routed"] = true
	result["threshold_result"] = threshold_result
	return result


# -- Treason: defense hearing in conviction pipeline ---------

static func process_treason_defense_hearing(
	crime_record: CrimeRecord,
	accused: L5RCharacterData,
	sincerity_roll: int,
	lord: L5RCharacterData,
) -> Dictionary:
	if crime_record.crime_type != Enums.CrimeType.TREASON:
		return {"applicable": false}

	var authority := TreasonSystem.can_convict(lord.status, accused.status)
	if authority["must_escalate"]:
		var escalation_target := TreasonSystem.get_escalation_target(
			lord.status >= 5.0 and lord.status < 7.0
		)
		return {
			"applicable": true,
			"blocked": true,
			"reason": "insufficient_authority",
			"must_escalate_to": escalation_target,
		}

	var honor_rank: int = HonorGlorySystem.get_honor_rank(accused)
	var hearing := TreasonSystem.resolve_defense_hearing(
		sincerity_roll, crime_record.evidence_total, honor_rank
	)

	if hearing["defense_succeeded"]:
		crime_record.evidence_total = hearing["evidence_halved_to"]
		crime_record.legal_status = Enums.LegalStatus.ACQUITTED

		var false_accusation := TreasonSystem.apply_false_accusation_penalty()
		return {
			"applicable": true,
			"blocked": false,
			"defense_succeeded": true,
			"evidence_halved_to": hearing["evidence_halved_to"],
			"political_shield_active": true,
			"reaccusation_requires": hearing["reaccusation_requires"],
			"lord_honor_change": false_accusation["honor_change"],
			"lord_disposition_hit": false_accusation["disposition_hit_all_vassals"],
		}

	return {
		"applicable": true,
		"blocked": false,
		"defense_succeeded": false,
		"proceed_to_judgment": true,
	}


# -- Treason: post-conviction co-conspirator naming ---------

static func process_treason_conviction(
	crime_record: CrimeRecord,
	convicted: L5RCharacterData,
	lord: L5RCharacterData,
	co_conspirator_ids: Array[int],
	next_topic_id: Array[int],
	ic_day: int,
) -> Dictionary:
	if crime_record.crime_type != Enums.CrimeType.TREASON:
		return {"applicable": false}

	crime_record.legal_status = Enums.LegalStatus.DECREED_GUILTY
	crime_record.ic_day_conviction = ic_day

	var naming := TreasonSystem.should_name_co_conspirators(lord.bushido_virtue)

	var conviction_topic: TopicData = InvestigationSystem.generate_conviction_topic(
		crime_record, convicted, 2, next_topic_id, ic_day
	)

	return {
		"applicable": true,
		"co_conspirators_named_publicly": naming["names_publicly"],
		"co_conspirator_ids": co_conspirator_ids,
		"naming_reason": naming["reason"],
		"conviction_topic": conviction_topic,
	}


# -- Killing: trial by combat integration ---------

static func process_trial_by_combat(
	crime_record: CrimeRecord,
	outcome: UnsanctionedKillingSystem.TrialOutcome,
	victim_status: float,
) -> Dictionary:
	var result := UnsanctionedKillingSystem.resolve_trial_by_combat(
		outcome, victim_status
	)

	if result["case_cleared"]:
		if outcome == UnsanctionedKillingSystem.TrialOutcome.ACCUSED_WINS:
			crime_record.legal_status = Enums.LegalStatus.ACQUITTED
		else:
			crime_record.legal_status = Enums.LegalStatus.DECREED_GUILTY

	result["case_id"] = crime_record.case_id
	return result


# -- Killing: attempted murder (victim survived) ---------

static func process_attempted_murder(
	attacker: L5RCharacterData,
	victim: L5RCharacterData,
	method_tier: UnsanctionedKillingSystem.KillingTier,
	case_id: int,
	ic_day: int,
	witnesses: Array[int],
) -> Dictionary:
	var evaluation := UnsanctionedKillingSystem.evaluate_attempted_murder(
		method_tier, attacker.status, victim.status
	)

	var crime_type: Enums.CrimeType = _killing_tier_to_crime_type(method_tier)
	var record: CrimeRecord = CrimeSystem.create_crime_record(
		case_id, crime_type, attacker.character_id,
		attacker.physical_location, ic_day,
		victim.character_id, 0, witnesses
	)

	return {
		"record": record,
		"evaluation": evaluation,
	}


# -- Cross-clan disposition wiring ---------

static func compute_cross_clan_disposition_change(
	crime_record: CrimeRecord,
	attacker: L5RCharacterData,
	victim: L5RCharacterData,
	cooperated: bool,
) -> Dictionary:
	if attacker.clan == victim.clan:
		return {"applies": false}

	var tier: UnsanctionedKillingSystem.KillingTier = _crime_type_to_killing_tier(
		crime_record.crime_type
	)
	var hit: int = UnsanctionedKillingSystem.get_cross_clan_disposition_hit(
		cooperated, tier
	)

	return {
		"applies": true,
		"disposition_hit": hit,
		"from_clan": victim.clan,
		"toward_clan": attacker.clan,
	}


static func _crime_type_to_killing_tier(
	crime_type: Enums.CrimeType,
) -> UnsanctionedKillingSystem.KillingTier:
	match crime_type:
		Enums.CrimeType.UNSANCTIONED_DUEL_DEATH:
			return UnsanctionedKillingSystem.KillingTier.UNSANCTIONED_DUEL_DEATH
		Enums.CrimeType.UNSANCTIONED_OPEN_KILLING:
			return UnsanctionedKillingSystem.KillingTier.OPEN_KILLING
		Enums.CrimeType.UNSANCTIONED_COVERT_KILLING:
			return UnsanctionedKillingSystem.KillingTier.COVERT_KILLING
	return UnsanctionedKillingSystem.KillingTier.OPEN_KILLING
