class_name ImperialEdictSystem
## Imperial Edict issuance and compliance per GDD s15.1, s15.2, s55.10.1.
## Edicts bind everyone — they are the only truly binding court outcome.


const DEFIANCE_HONOR_COST: float = -3.0
const DEFIANCE_DISPOSITION_FROM_EMPEROR: int = -20
const DEFIANCE_DISPOSITION_FROM_OTHERS: int = -10
const CONDEMN_WAR_SCORE_SHIFT: int = 10

const MAX_EDICTS_PER_WINTER_COURT: int = 3
const EMPEROR_WEIGHT_MULTIPLIER: int = 3
const EDICT_POSITIVE_THRESHOLD: float = 25.0
const EDICT_NEGATIVE_THRESHOLD: float = -25.0

const CRISIS_COMMITMENT_TYPE: Dictionary = {
	"shadowlands_incursion": "send_military_aid",
	"oni_manifestation": "send_military_aid",
	"maho_cult": "send_magistrates",
	"famine": "send_supplies",
	"starvation": "send_supplies",
	"provincial_famine": "send_supplies",
	"clan_famine": "send_supplies",
	"criminal": "send_magistrates",
	"nezumi": "send_military_aid",
	"border_raid": "send_military_aid",
}

const COMPLIANCE_DEADLINE: Dictionary = {
	EdictData.EdictType.CEASE_HOSTILITIES: 30,
	EdictData.EdictType.CONDEMN_CLAN: 0,
	EdictData.EdictType.AUTHORIZE_WAR: 0,
	EdictData.EdictType.TAX_REFORM: 90,
	EdictData.EdictType.APPOINT_POSITION: 30,
	EdictData.EdictType.STRIP_AUTONOMY: 30,
	EdictData.EdictType.GENERAL_DECREE: 30,
}

const ARCHETYPE_EDICT_FREQUENCY: Dictionary = {
	StrategicReview.EmperorArchetype.BENEVOLENT: 1,
	StrategicReview.EmperorArchetype.IRON: 3,
	StrategicReview.EmperorArchetype.CUNNING: 2,
	StrategicReview.EmperorArchetype.WARLIKE: 2,
	StrategicReview.EmperorArchetype.TYRANT: 3,
}


# -- Edict Factory -------------------------------------------------------------

static func create_edict(
	edict_id: int,
	edict_type: EdictData.EdictType,
	emperor_id: int,
	ic_day: int,
	court_id: int = -1,
) -> EdictData:
	var e := EdictData.new()
	e.edict_id = edict_id
	e.edict_type = edict_type
	e.emperor_id = emperor_id
	e.ic_day_issued = ic_day
	e.court_id = court_id
	var grace: int = COMPLIANCE_DEADLINE.get(edict_type, 30)
	if grace > 0:
		e.compliance_deadline_ic_day = ic_day + grace
	return e


# -- Winter Court Edict Generation ---------------------------------------------

static func generate_winter_court_edicts(
	emperor: L5RCharacterData,
	archetype: int,
	agenda_topic_ids: Array[int],
	active_topics: Array[TopicData],
	active_wars: Array[WarData],
	next_edict_id: Array[int],
	ic_day: int,
	court_id: int = -1,
) -> Array:
	var max_edicts: int = mini(
		ARCHETYPE_EDICT_FREQUENCY.get(archetype, 1),
		MAX_EDICTS_PER_WINTER_COURT
	)

	var agenda_topics: Array = _resolve_topic_ids(agenda_topic_ids, active_topics)
	var edicts: Array[EdictData] = []

	for topic: TopicData in agenda_topics:
		if edicts.size() >= max_edicts:
			break
		var edict: EdictData = _evaluate_topic_for_edict(
			topic, emperor, archetype, active_wars, next_edict_id, ic_day, court_id
		)
		if edict != null:
			edicts.append(edict)

	return edicts


# -- Aggregate-Opinion Edict Selection (s16.4) ---------------------------------

static func compute_emperor_weight(emperor_status: float, relevance: float) -> float:
	return emperor_status * (relevance / 50.0) * EMPEROR_WEIGHT_MULTIPLIER


static func compute_topic_aggregate(
	topic: TopicData,
	attendees: Array[L5RCharacterData],
	emperor_id: int,
) -> float:
	var positions: Array[float] = []
	var weights: Array[float] = []
	for c: L5RCharacterData in attendees:
		var pos: float = c.topic_positions.get(topic.topic_id, 0.0)
		var relevance: float = TopicMomentumSystem.calculate_personal_relevance(
			topic,
			TopicMomentumSystem.ClanRelation.OWN if topic.clan_involved == c.clan and not topic.clan_involved.is_empty() else TopicMomentumSystem.ClanRelation.DISTANT,
			not topic.family_involved.is_empty() and topic.family_involved == c.family and topic.clan_involved == c.clan,
			not topic.family_involved.is_empty() and topic.clan_involved == c.clan and topic.family_involved != c.family,
		)
		var weight: float
		if c.character_id == emperor_id:
			weight = compute_emperor_weight(c.status, relevance)
		else:
			weight = TopicMomentumSystem.calculate_position_weight(c.status, relevance)
		positions.append(pos)
		weights.append(weight)
	return TopicMomentumSystem.calculate_aggregate_opinion(positions, weights)


static func generate_edicts_from_aggregate(
	emperor: L5RCharacterData,
	archetype: int,
	court: CourtSessionData,
	attendees: Array[L5RCharacterData],
	active_topics: Array[TopicData],
	active_wars: Array[WarData],
	next_edict_id: Array[int],
	ic_day: int,
) -> Dictionary:
	var max_edicts: int = mini(
		ARCHETYPE_EDICT_FREQUENCY.get(archetype, 1),
		MAX_EDICTS_PER_WINTER_COURT
	)

	var agenda_topics: Array = _resolve_topic_ids(
		court.agenda_topic_ids, active_topics
	)
	agenda_topics.sort_custom(func(a: TopicData, b: TopicData) -> bool:
		return a.momentum > b.momentum
	)
	if agenda_topics.size() > 3:
		agenda_topics.resize(3)

	var edicts: Array[EdictData] = []
	var aggregates: Array[Dictionary] = []

	for topic: TopicData in agenda_topics:
		if edicts.size() >= max_edicts:
			break
		var agg: float = compute_topic_aggregate(topic, attendees, emperor.character_id)
		var edict_result: Dictionary = _evaluate_aggregate_for_edict(
			topic, agg, emperor, archetype, active_wars, next_edict_id, ic_day, court.court_id
		)
		aggregates.append({
			"topic_id": topic.topic_id,
			"aggregate": agg,
			"edict_issued": edict_result.get("edict") != null,
			"direction": edict_result.get("direction", "none"),
		})
		var edict: EdictData = edict_result.get("edict") as EdictData
		if edict != null:
			edicts.append(edict)

	return {
		"edicts": edicts,
		"aggregates": aggregates,
	}


static func _evaluate_aggregate_for_edict(
	topic: TopicData,
	aggregate: float,
	emperor: L5RCharacterData,
	archetype: int,
	active_wars: Array[WarData],
	next_edict_id: Array[int],
	ic_day: int,
	court_id: int,
) -> Dictionary:
	if aggregate > EDICT_POSITIVE_THRESHOLD:
		var edict: EdictData = _create_compelling_edict(
			topic, emperor, archetype, active_wars, next_edict_id, ic_day, court_id
		)
		return {"edict": edict, "direction": "compelling"}

	if aggregate < EDICT_NEGATIVE_THRESHOLD:
		var edict: EdictData = _create_blocking_edict(
			topic, emperor, next_edict_id, ic_day, court_id
		)
		return {"edict": edict, "direction": "blocking"}

	return {"edict": null, "direction": "none"}


static func _create_compelling_edict(
	topic: TopicData,
	emperor: L5RCharacterData,
	archetype: int,
	active_wars: Array[WarData],
	next_edict_id: Array[int],
	ic_day: int,
	court_id: int,
) -> EdictData:
	if topic.topic_type == "war" or topic.category == TopicData.Category.MILITARY:
		var war: WarData = _find_war_for_topic(topic, active_wars)
		if war != null:
			return _create_cease_hostilities(
				war, topic, emperor, archetype, next_edict_id, ic_day, court_id
			)

	var edict_type: EdictData.EdictType = _crisis_to_edict_type(topic)
	var e := create_edict(next_edict_id[0], edict_type, emperor.character_id, ic_day, court_id)
	next_edict_id[0] += 1
	e.target_topic_id = topic.topic_id
	e.target_clan = topic.clan_involved
	e.description = "Imperial edict on %s" % topic.slug
	return e


static func _create_blocking_edict(
	topic: TopicData,
	emperor: L5RCharacterData,
	next_edict_id: Array[int],
	ic_day: int,
	court_id: int,
) -> EdictData:
	var e := create_edict(
		next_edict_id[0], EdictData.EdictType.GENERAL_DECREE,
		emperor.character_id, ic_day, court_id
	)
	next_edict_id[0] += 1
	e.target_topic_id = topic.topic_id
	e.target_clan = topic.clan_involved
	e.description = "Imperial edict blocking action on %s" % topic.slug
	return e


static func _crisis_to_edict_type(topic: TopicData) -> EdictData.EdictType:
	if topic.topic_type == "famine" or topic.topic_type == "starvation" or topic.topic_type == "provincial_famine" or topic.topic_type == "clan_famine":
		return EdictData.EdictType.TAX_REFORM
	return EdictData.EdictType.GENERAL_DECREE


static func get_commitment_type_for_topic(topic: TopicData) -> String:
	return CRISIS_COMMITMENT_TYPE.get(topic.topic_type, "")


static func generate_edict_commitments(
	edict: EdictData,
	topic: TopicData,
	lords: Array[L5RCharacterData],
	ic_day: int,
	deadline_ic_day: int,
) -> Array:
	var commitment_type: String = get_commitment_type_for_topic(topic)
	if commitment_type.is_empty():
		return []
	var commitments: Array[CourtCommitmentData] = []
	for lord: L5RCharacterData in lords:
		var c := CourtCommitmentSystem.create_edict_commitment(
			lord.character_id, topic.topic_id, commitment_type,
			ic_day, deadline_ic_day,
		)
		commitments.append(c)
	return commitments


static func _resolve_topic_ids(
	ids: Array[int],
	active_topics: Array[TopicData],
) -> Array:
	var result: Array[TopicData] = []
	for tid: int in ids:
		for t: TopicData in active_topics:
			if t.topic_id == tid and not t.resolved:
				result.append(t)
				break
	return result


static func _evaluate_topic_for_edict(
	topic: TopicData,
	emperor: L5RCharacterData,
	archetype: int,
	active_wars: Array[WarData],
	next_edict_id: Array[int],
	ic_day: int,
	court_id: int,
) -> EdictData:
	if topic.topic_type == "war" or topic.category == TopicData.Category.MILITARY:
		var war: WarData = _find_war_for_topic(topic, active_wars)
		if war != null:
			return _create_cease_hostilities(
				war, topic, emperor, archetype, next_edict_id, ic_day, court_id
			)

	if topic.topic_type == "famine" or topic.topic_type == "starvation":
		if archetype == StrategicReview.EmperorArchetype.BENEVOLENT or archetype == StrategicReview.EmperorArchetype.IRON:
			var e := create_edict(
				next_edict_id[0], EdictData.EdictType.TAX_REFORM,
				emperor.character_id, ic_day, court_id
			)
			next_edict_id[0] += 1
			e.target_topic_id = topic.topic_id
			e.target_clan = topic.clan_involved
			e.description = "Tax relief for %s" % topic.clan_involved
			return e

	if topic.tier == TopicData.Tier.TIER_1:
		var e := create_edict(
			next_edict_id[0], EdictData.EdictType.GENERAL_DECREE,
			emperor.character_id, ic_day, court_id
		)
		next_edict_id[0] += 1
		e.target_topic_id = topic.topic_id
		e.description = "Imperial decree on %s" % topic.slug
		return e

	return null


static func _create_cease_hostilities(
	war: WarData,
	topic: TopicData,
	emperor: L5RCharacterData,
	archetype: int,
	next_edict_id: Array[int],
	ic_day: int,
	court_id: int,
) -> EdictData:
	if archetype == StrategicReview.EmperorArchetype.WARLIKE:
		return null
	if archetype == StrategicReview.EmperorArchetype.BENEVOLENT:
		pass
	elif war.seasons_active < 2:
		return null

	var e := create_edict(
		next_edict_id[0], EdictData.EdictType.CEASE_HOSTILITIES,
		emperor.character_id, ic_day, court_id
	)
	next_edict_id[0] += 1
	e.target_war_id = war.war_id
	e.target_topic_id = topic.topic_id
	e.target_clan = ""
	e.description = "Cease hostilities between %s and %s" % [war.clan_a, war.clan_b]
	e.compliance_by_clan = {
		war.clan_a: EdictData.ComplianceStatus.PENDING,
		war.clan_b: EdictData.ComplianceStatus.PENDING,
	}
	return e


static func _find_war_for_topic(
	topic: TopicData,
	active_wars: Array[WarData],
) -> WarData:
	for w: WarData in active_wars:
		if w.war_id == topic.topic_id:
			return w
		if topic.clan_involved != "" and (topic.clan_involved == w.clan_a or topic.clan_involved == w.clan_b):
			return w
	return null


# -- Edict Application ---------------------------------------------------------

static func apply_cease_hostilities(
	edict: EdictData,
	active_wars: Array[WarData],
) -> Dictionary:
	if edict.edict_type != EdictData.EdictType.CEASE_HOSTILITIES:
		return {"applied": false, "reason": "wrong_type"}
	for w: WarData in active_wars:
		if w.war_id == edict.target_war_id:
			var result: Dictionary = WarTermination.resolve_imperial_edict(w)
			result["edict_id"] = edict.edict_id
			return result
	return {"applied": false, "reason": "war_not_found"}


static func apply_condemn_clan(
	edict: EdictData,
	active_wars: Array[WarData],
) -> Dictionary:
	if edict.edict_type != EdictData.EdictType.CONDEMN_CLAN:
		return {"applied": false, "reason": "wrong_type"}
	var result: Dictionary = {
		"applied": true,
		"edict_id": edict.edict_id,
		"condemned_clan": edict.target_clan,
		"war_score_shifts": [],
	}
	for w: WarData in active_wars:
		if w.clan_a == edict.target_clan or w.clan_b == edict.target_clan:
			var shift_to: String = w.clan_b if w.clan_a == edict.target_clan else w.clan_a
			WarSystem.apply_score_shift(w, "condemn_clan", shift_to)
			result["war_score_shifts"].append({
				"war_id": w.war_id,
				"beneficiary": shift_to,
				"shift": CONDEMN_WAR_SCORE_SHIFT,
			})
	return result


# -- Compliance ----------------------------------------------------------------

static func record_compliance(
	edict: EdictData,
	clan: String,
	compliant: bool,
) -> void:
	if compliant:
		edict.compliance_by_clan[clan] = EdictData.ComplianceStatus.COMPLIANT
	else:
		edict.compliance_by_clan[clan] = EdictData.ComplianceStatus.DEFIANT


static func is_clan_defiant(edict: EdictData, clan: String) -> bool:
	return edict.compliance_by_clan.get(clan, EdictData.ComplianceStatus.PENDING) == EdictData.ComplianceStatus.DEFIANT


static func get_defiant_clans(edict: EdictData) -> Array:
	var result: Array[String] = []
	for clan: String in edict.compliance_by_clan:
		if edict.compliance_by_clan[clan] == EdictData.ComplianceStatus.DEFIANT:
			result.append(clan)
	return result


static func are_all_compliant(edict: EdictData) -> bool:
	for clan: String in edict.compliance_by_clan:
		if edict.compliance_by_clan[clan] != EdictData.ComplianceStatus.COMPLIANT:
			return false
	return true


# -- Defiance Consequences -----------------------------------------------------

static func compute_defiance_consequences(
	edict: EdictData,
	defiant_clan: String,
) -> Dictionary:
	return {
		"clan": defiant_clan,
		"edict_id": edict.edict_id,
		"honor_cost": DEFIANCE_HONOR_COST,
		"disposition_from_emperor": DEFIANCE_DISPOSITION_FROM_EMPEROR,
		"disposition_from_others": DEFIANCE_DISPOSITION_FROM_OTHERS,
	}


# -- Topic Generation ----------------------------------------------------------

static func generate_edict_topic(edict: EdictData) -> Dictionary:
	var tier: TopicData.Tier = TopicData.Tier.TIER_1
	var momentum: float = 80.0
	if edict.edict_type == EdictData.EdictType.TAX_REFORM:
		tier = TopicData.Tier.TIER_2
		momentum = 50.0
	elif edict.edict_type == EdictData.EdictType.GENERAL_DECREE:
		tier = TopicData.Tier.TIER_2
		momentum = 60.0

	return {
		"topic_type": "imperial_edict",
		"variant": _edict_type_to_variant(edict.edict_type),
		"slug": "edict_%d_%s" % [edict.edict_id, _edict_type_to_variant(edict.edict_type)],
		"tier": tier,
		"category": TopicData.Category.POLITICAL,
		"momentum": momentum,
		"clan_involved": edict.target_clan,
		"subject_character_id": edict.emperor_id,
	}


static func generate_defiance_topic(edict: EdictData, defiant_clan: String) -> Dictionary:
	return {
		"topic_type": "edict_defiance",
		"variant": defiant_clan.to_lower(),
		"slug": "edict_%d_defiance_%s" % [edict.edict_id, defiant_clan.to_lower()],
		"tier": TopicData.Tier.TIER_1,
		"category": TopicData.Category.POLITICAL,
		"momentum": 90.0,
		"clan_involved": defiant_clan,
		"subject_character_id": edict.emperor_id,
	}


static func _edict_type_to_variant(edict_type: EdictData.EdictType) -> String:
	match edict_type:
		EdictData.EdictType.CEASE_HOSTILITIES:
			return "cease_hostilities"
		EdictData.EdictType.CONDEMN_CLAN:
			return "condemn_clan"
		EdictData.EdictType.AUTHORIZE_WAR:
			return "authorize_war"
		EdictData.EdictType.TAX_REFORM:
			return "tax_reform"
		EdictData.EdictType.APPOINT_POSITION:
			return "appoint_position"
		EdictData.EdictType.STRIP_AUTONOMY:
			return "strip_autonomy"
		EdictData.EdictType.GENERAL_DECREE:
			return "general_decree"
		_:
			return "unknown"


# -- Archetype-Specific Edict Behavior ----------------------------------------

static func would_emperor_issue_edict(
	archetype: int,
	edict_type: EdictData.EdictType,
	target_clan_disposition: int,
) -> bool:
	match edict_type:
		EdictData.EdictType.CONDEMN_CLAN:
			if archetype == StrategicReview.EmperorArchetype.BENEVOLENT:
				return false
			if archetype == StrategicReview.EmperorArchetype.TYRANT:
				return target_clan_disposition <= -11
			return target_clan_disposition <= -31
		EdictData.EdictType.AUTHORIZE_WAR:
			if archetype == StrategicReview.EmperorArchetype.BENEVOLENT:
				return false
			if archetype == StrategicReview.EmperorArchetype.WARLIKE:
				return true
			return false
		EdictData.EdictType.STRIP_AUTONOMY:
			return archetype == StrategicReview.EmperorArchetype.TYRANT
		_:
			return true


# -- Deactivation --------------------------------------------------------------

static func deactivate_edict(edict: EdictData) -> void:
	edict.is_active = false


# -- Daily Compliance Processing -----------------------------------------------

static func process_daily_compliance(
	active_edicts: Array[EdictData],
	active_wars: Array[WarData],
	characters: Array[L5RCharacterData],
	ic_day: int,
) -> Array:
	var results: Array[Dictionary] = []
	for edict: EdictData in active_edicts:
		if not edict.is_active:
			continue
		if edict.compliance_by_clan.is_empty():
			continue

		if edict.edict_type == EdictData.EdictType.CEASE_HOSTILITIES:
			_check_ceasefire_auto_compliance(edict, active_wars)

		var deadline_passed: bool = edict.compliance_deadline_ic_day >= 0 and ic_day >= edict.compliance_deadline_ic_day
		if deadline_passed:
			var newly_defiant: Array = _mark_pending_as_defiant(edict)
			for clan: String in newly_defiant:
				var consequence: Dictionary = compute_defiance_consequences(edict, clan)
				_apply_defiance_to_characters(consequence, characters, edict.emperor_id)
				consequence["defiance_topic"] = generate_defiance_topic(edict, clan)
				results.append(consequence)

		if are_all_compliant(edict):
			var applied: Dictionary = _apply_compliant_edict(edict, active_wars, characters, ic_day)
			if not applied.is_empty():
				results.append(applied)
			deactivate_edict(edict)

	return results


static func _check_ceasefire_auto_compliance(
	edict: EdictData,
	active_wars: Array[WarData],
) -> void:
	var war_still_active: bool = false
	for w: WarData in active_wars:
		if w.war_id == edict.target_war_id:
			war_still_active = true
			break
	if not war_still_active:
		for clan: String in edict.compliance_by_clan:
			if edict.compliance_by_clan[clan] == EdictData.ComplianceStatus.PENDING:
				edict.compliance_by_clan[clan] = EdictData.ComplianceStatus.COMPLIANT


static func _mark_pending_as_defiant(edict: EdictData) -> Array:
	var newly_defiant: Array[String] = []
	for clan: String in edict.compliance_by_clan:
		if edict.compliance_by_clan[clan] == EdictData.ComplianceStatus.PENDING:
			edict.compliance_by_clan[clan] = EdictData.ComplianceStatus.DEFIANT
			newly_defiant.append(clan)
	return newly_defiant


static func _apply_defiance_to_characters(
	consequence: Dictionary,
	characters: Array[L5RCharacterData],
	emperor_id: int,
) -> void:
	var defiant_clan: String = consequence.get("clan", "")
	var honor_cost: float = consequence.get("honor_cost", 0.0)
	var disp_emperor: int = consequence.get("disposition_from_emperor", 0)
	var disp_others: int = consequence.get("disposition_from_others", 0)

	for c: L5RCharacterData in characters:
		if c.clan != defiant_clan:
			continue
		if c.status < 5.0:
			continue
		HonorGlorySystem.apply_honor_change(c, honor_cost)
		if emperor_id >= 0:
			var cur_emp: int = int(c.disposition_values.get(emperor_id, 0))
			c.disposition_values[emperor_id] = clampi(cur_emp + disp_emperor, -100, 100)
		for other: L5RCharacterData in characters:
			if other.clan == defiant_clan or other.character_id == emperor_id:
				continue
			if other.status < 3.0:
				continue
			var cur: int = int(other.disposition_values.get(c.character_id, 0))
			other.disposition_values[c.character_id] = clampi(cur + disp_others, -100, 100)


static func _apply_compliant_edict(
	edict: EdictData,
	active_wars: Array[WarData],
	characters: Array[L5RCharacterData],
	ic_day: int,
) -> Dictionary:
	match edict.edict_type:
		EdictData.EdictType.CEASE_HOSTILITIES:
			return apply_cease_hostilities(edict, active_wars)
		EdictData.EdictType.CONDEMN_CLAN:
			return apply_condemn_clan(edict, active_wars)
		EdictData.EdictType.AUTHORIZE_WAR:
			return apply_authorize_war(edict, active_wars)
		EdictData.EdictType.TAX_REFORM:
			return apply_tax_reform(edict)
		EdictData.EdictType.APPOINT_POSITION:
			return apply_appoint_position(edict, characters)
		EdictData.EdictType.STRIP_AUTONOMY:
			return apply_strip_autonomy(edict, characters)
		EdictData.EdictType.GENERAL_DECREE:
			return apply_general_decree(edict, ic_day)
		_:
			return {"applied": true, "edict_id": edict.edict_id}


# -- Compliance effect: AUTHORIZE_WAR -----------------------------------------
# Shifts war score +10 toward the authorized clan when all clans comply.
# If the target war is already resolved, returns a no-op result.

static func apply_authorize_war(
	edict: EdictData,
	active_wars: Array[WarData],
) -> Dictionary:
	if edict.edict_type != EdictData.EdictType.AUTHORIZE_WAR:
		return {"applied": false, "reason": "wrong_type"}
	for w: WarData in active_wars:
		if w.war_id == edict.target_war_id:
			WarSystem.apply_score_shift(w, "authorize_war", edict.target_clan)
			return {
				"applied": true,
				"edict_id": edict.edict_id,
				"authorized_clan": edict.target_clan,
				"war_id": w.war_id,
				"score_shift": CONDEMN_WAR_SCORE_SHIFT,
			}
	return {"applied": true, "edict_id": edict.edict_id, "no_active_war": true}


# -- Compliance effect: TAX_REFORM --------------------------------------------
# Sets a season_meta flag for ResourceTick to consume in the next pass.
# Actual rate change is deferred until ResourceTick's seasonal pass is extended.

static func apply_tax_reform(edict: EdictData) -> Dictionary:
	if edict.edict_type != EdictData.EdictType.TAX_REFORM:
		return {"applied": false, "reason": "wrong_type"}
	return {
		"applied": true,
		"edict_id": edict.edict_id,
		"tax_reform_active": true,
		"tax_reform_edict_id": edict.edict_id,
	}


# -- Compliance effect: APPOINT_POSITION --------------------------------------
# Raises the appointed character's status by +1.0 (formal Imperial appointment).

const APPOINTMENT_STATUS_GAIN: float = 1.0

static func apply_appoint_position(
	edict: EdictData,
	characters: Array[L5RCharacterData],
) -> Dictionary:
	if edict.edict_type != EdictData.EdictType.APPOINT_POSITION:
		return {"applied": false, "reason": "wrong_type"}
	for c: L5RCharacterData in characters:
		if c.character_id == edict.target_character_id:
			var old_status: float = c.status
			HonorGlorySystem.apply_status_change(c, APPOINTMENT_STATUS_GAIN)
			return {
				"applied": true,
				"edict_id": edict.edict_id,
				"appointed_character_id": c.character_id,
				"old_status": old_status,
				"new_status": c.status,
			}
	return {"applied": true, "edict_id": edict.edict_id, "character_not_found": true}


# -- Compliance effect: STRIP_AUTONOMY ----------------------------------------
# The stripped clan's highest-status character (Champion) loses 5 Honor.
# All status-5+ members of the stripped clan gain −10 disposition toward
# the Emperor (they submitted, but resent it).

const STRIP_AUTONOMY_HONOR_COST: float = -5.0
const STRIP_AUTONOMY_EMPEROR_DISPOSITION: int = -10

static func apply_strip_autonomy(
	edict: EdictData,
	characters: Array[L5RCharacterData],
) -> Dictionary:
	if edict.edict_type != EdictData.EdictType.STRIP_AUTONOMY:
		return {"applied": false, "reason": "wrong_type"}
	if edict.target_clan.is_empty():
		return {"applied": true, "edict_id": edict.edict_id, "no_target_clan": true}

	var champion: L5RCharacterData = null
	var stripped_members: Array[int] = []
	for c: L5RCharacterData in characters:
		if c.clan != edict.target_clan:
			continue
		if champion == null or c.status > champion.status:
			champion = c
		if c.status >= 5.0:
			stripped_members.append(c.character_id)
			if edict.emperor_id >= 0:
				var cur: int = c.disposition_values.get(edict.emperor_id, 0)
				c.disposition_values[edict.emperor_id] = clampi(cur + STRIP_AUTONOMY_EMPEROR_DISPOSITION, -100, 100)

	if champion != null:
		HonorGlorySystem.apply_honor_change(champion, STRIP_AUTONOMY_HONOR_COST)

	return {
		"applied": true,
		"edict_id": edict.edict_id,
		"stripped_clan": edict.target_clan,
		"champion_id": champion.character_id if champion != null else -1,
		"honor_cost": STRIP_AUTONOMY_HONOR_COST,
		"members_affected": stripped_members,
	}


# -- Compliance effect: GENERAL_DECREE ----------------------------------------
# Records the decree's passage in the return dict for callers to persist into
# season_meta. No immediate disposition mutations.

static func apply_general_decree(edict: EdictData, ic_day: int) -> Dictionary:
	if edict.edict_type != EdictData.EdictType.GENERAL_DECREE:
		return {"applied": false, "reason": "wrong_type"}
	return {
		"applied": true,
		"edict_id": edict.edict_id,
		"last_general_decree_id": edict.edict_id,
		"last_general_decree_day": ic_day,
	}
