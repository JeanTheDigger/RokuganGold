class_name ImperialEdictSystem
## Imperial Edict issuance and compliance per GDD s15.1, s15.2, s55.10.1.
## Edicts bind everyone — they are the only truly binding court outcome.


const DEFIANCE_HONOR_COST: float = -3.0
const DEFIANCE_DISPOSITION_FROM_EMPEROR: int = -20
const DEFIANCE_DISPOSITION_FROM_OTHERS: int = -10
const CONDEMN_WAR_SCORE_SHIFT: int = 10

const MAX_EDICTS_PER_WINTER_COURT: int = 3

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
) -> Array[EdictData]:
	var max_edicts: int = mini(
		ARCHETYPE_EDICT_FREQUENCY.get(archetype, 1),
		MAX_EDICTS_PER_WINTER_COURT
	)

	var agenda_topics: Array[TopicData] = _resolve_topic_ids(agenda_topic_ids, active_topics)
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


static func _resolve_topic_ids(
	ids: Array[int],
	active_topics: Array[TopicData],
) -> Array[TopicData]:
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
			WarSystem.apply_score_shift(w, shift_to, CONDEMN_WAR_SCORE_SHIFT)
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


static func get_defiant_clans(edict: EdictData) -> Array[String]:
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
