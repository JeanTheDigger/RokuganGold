class_name InvestigationSystem
## Crime scene examination and evidence gathering per GDD s57.15, s57.16.
## Executor for EXAMINE_CRIME_SCENE action. Handles evidence accumulation,
## witness identification, UPHOLD_LAW self-initiation, witness PROBE evidence,
## and conviction topic generation.


const SCENE_EXAM_TN_FALLBACK: int = 15
const EVIDENCE_BASE_WEIGHT: int = 5
const EVIDENCE_PER_RAISE: int = 3
const RAISE_MARGIN: int = 5
const ELAPSED_DAY_PENALTY: float = 0.5
const MAX_ELAPSED_PENALTY: float = 0.8


static func examine_scene(
	magistrate: L5RCharacterData,
	crime_record: CrimeRecord,
	dice_engine: DiceEngine,
	ic_day: int,
) -> Dictionary:
	var concealment_tn: int = crime_record.concealment_tn
	if concealment_tn <= 0:
		concealment_tn = SCENE_EXAM_TN_FALLBACK

	var result: Dictionary = SkillResolver.resolve_skill_check(
		magistrate, dice_engine, "Investigation", concealment_tn
	)

	if not result["success"]:
		return {
			"success": false,
			"evidence_gained": 0,
			"suspect_found": -1,
		}

	var margin: int = result["margin"]
	var raises: int = margin / RAISE_MARGIN
	var raw_evidence: int = EVIDENCE_BASE_WEIGHT + (raises * EVIDENCE_PER_RAISE)

	var days_elapsed: int = ic_day - crime_record.ic_day_committed
	var time_factor: float = 1.0 - minf(days_elapsed * ELAPSED_DAY_PENALTY / 10.0, MAX_ELAPSED_PENALTY)
	var evidence: int = maxi(1, int(raw_evidence * time_factor))

	crime_record.evidence_total += evidence

	var suspect_found: int = -1
	if raises >= 2 and crime_record.perpetrator_id >= 0:
		if crime_record.perpetrator_id not in crime_record.known_suspects:
			crime_record.known_suspects.append(crime_record.perpetrator_id)
			suspect_found = crime_record.perpetrator_id

	return {
		"success": true,
		"evidence_gained": evidence,
		"suspect_found": suspect_found,
		"margin": margin,
		"raises": raises,
	}


# -- UPHOLD_LAW Self-Initiation (s57.16.9a) -----------------------------------

const UPHOLD_LAW_BUSHIDO_PROBABILITY: Dictionary = {
	Enums.BushidoVirtue.GI: 100,
	Enums.BushidoVirtue.MEIYO: 80,
	Enums.BushidoVirtue.CHUGI: 60,
	Enums.BushidoVirtue.JIN: 50,
	Enums.BushidoVirtue.REI: 50,
	Enums.BushidoVirtue.MAKOTO: 50,
	Enums.BushidoVirtue.YU: 30,
}

const UPHOLD_LAW_SHOURIDO_PROBABILITY: Dictionary = {
	Enums.ShouridoVirtue.KANPEKI: 70,
	Enums.ShouridoVirtue.DOSATSU: 50,
	Enums.ShouridoVirtue.CHISHIKI: 40,
	Enums.ShouridoVirtue.KETSUI: 40,
	Enums.ShouridoVirtue.ISHI: 30,
	Enums.ShouridoVirtue.SEIGYO: 20,
	Enums.ShouridoVirtue.KYORYOKU: 20,
}


static func get_uphold_law_probability(
	bushido: Enums.BushidoVirtue,
	shourido: Enums.ShouridoVirtue,
) -> int:
	if bushido != Enums.BushidoVirtue.NONE:
		return UPHOLD_LAW_BUSHIDO_PROBABILITY.get(bushido, 50)
	if shourido != Enums.ShouridoVirtue.NONE:
		return UPHOLD_LAW_SHOURIDO_PROBABILITY.get(shourido, 40)
	return 50


static func should_assign_uphold_law(
	bushido: Enums.BushidoVirtue,
	shourido: Enums.ShouridoVirtue,
	rng_roll: int,
) -> bool:
	return rng_roll < get_uphold_law_probability(bushido, shourido)


# -- Evidence from Witness Testimony -------------------------------------------

const WITNESS_BASE_EVIDENCE: int = 3
const WITNESS_HIGH_AWARENESS_BONUS: int = 2
const WITNESS_LOW_HONOR_PENALTY: int = -1
const HIGH_AWARENESS_THRESHOLD: int = 4


static func calculate_witness_evidence(
	witness_awareness: int,
	witness_honor: float,
) -> int:
	var evidence: int = WITNESS_BASE_EVIDENCE
	if witness_awareness >= HIGH_AWARENESS_THRESHOLD:
		evidence += WITNESS_HIGH_AWARENESS_BONUS
	if witness_honor < 3.0:
		evidence += WITNESS_LOW_HONOR_PENALTY
	return maxi(1, evidence)


# -- Witness Prioritization (s57.16.4) ----------------------------------------

static func prioritize_witnesses(
	candidates: Array[int],
	characters_by_id: Dictionary,
	present_ids: Array[int],
) -> Array[int]:
	if candidates.size() <= 1:
		return candidates.duplicate()

	var scored: Array[Dictionary] = []
	for cand_id: int in candidates:
		var c: L5RCharacterData = characters_by_id.get(cand_id)
		var awareness: int = 2
		var honor: float = 5.0
		var is_present: bool = cand_id in present_ids
		if c != null:
			awareness = c.awareness
			honor = c.honor
		scored.append({
			"id": cand_id,
			"awareness": awareness,
			"honor": honor,
			"present": is_present,
		})

	scored.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if a["present"] != b["present"]:
			return a["present"]
		if a["awareness"] != b["awareness"]:
			return a["awareness"] > b["awareness"]
		return a["honor"] < b["honor"]
	)

	var result: Array[int] = []
	for entry: Dictionary in scored:
		result.append(entry["id"])
	return result


# -- UPHOLD_LAW Self-Initiation Wiring (s57.16.9) -----------------------------

static func check_jurisdiction(
	magistrate: L5RCharacterData,
	crime_record: CrimeRecord,
) -> bool:
	if magistrate.role_position == "emerald_magistrate":
		return true
	var mag_location: String = magistrate.physical_location
	var crime_location: String = crime_record.location
	if mag_location.is_empty() or crime_location.is_empty():
		return false
	var mag_province: String = mag_location.split("_")[0] if "_" in mag_location else mag_location
	var crime_province: String = crime_location.split("_")[0] if "_" in crime_location else crime_location
	return mag_province == crime_province


static func find_crime_record_for_topic(
	topic: TopicData,
	crime_records: Array[CrimeRecord],
) -> CrimeRecord:
	if topic.topic_type != "crime":
		return null
	var case_id: int = _get_topic_case_id(topic)
	if case_id < 0:
		return null
	for record: CrimeRecord in crime_records:
		if record.case_id == case_id:
			return record
	return null


static func activate_uphold_law(
	magistrate: L5RCharacterData,
	crime_record: CrimeRecord,
	standing_objective: Dictionary,
) -> Dictionary:
	var active_case: Dictionary = {
		"case_id": crime_record.case_id,
		"crime_type": crime_record.crime_type,
		"crime_location": crime_record.location,
		"perpetrator_id": crime_record.perpetrator_id,
		"evidence_total": crime_record.evidence_total,
		"known_suspects": crime_record.known_suspects.duplicate(),
		"witness_pool": crime_record.witnesses.duplicate(),
		"scene_examined": false,
		"interviewed_witnesses": [],
		"interviewed_suspects": [],
		"checked_alibis": [],
		"unresolved_leads": [],
	}
	standing_objective["active_case"] = active_case
	crime_record.investigating_magistrate_id = magistrate.character_id
	crime_record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION
	return active_case


static func scan_for_crime_topics(
	magistrate: L5RCharacterData,
	standing_objective: Dictionary,
	crime_records: Array[CrimeRecord],
	active_topics: Array[TopicData],
) -> Dictionary:
	if standing_objective.has("active_case") and not standing_objective["active_case"].is_empty():
		return {}
	for topic_id: int in magistrate.topic_pool:
		for topic: TopicData in active_topics:
			if topic.topic_id != topic_id:
				continue
			if topic.topic_type != "crime":
				continue
			var case_id: int = _get_topic_case_id(topic)
			if case_id < 0:
				continue
			for record: CrimeRecord in crime_records:
				if record.case_id != case_id:
					continue
				if record.investigating_magistrate_id >= 0:
					continue
				if not check_jurisdiction(magistrate, record):
					continue
				var active_case: Dictionary = activate_uphold_law(
					magistrate, record, standing_objective
				)
				return active_case
	return {}


static func _get_topic_case_id(topic: TopicData) -> int:
	if topic.slug.begins_with("crime_case_"):
		return topic.slug.substr(11).to_int()
	return -1


# -- Witness PROBE Evidence (s11.3.13e) ----------------------------------------

const PROBE_WITNESS_EVIDENCE_MIN: int = 10
const PROBE_WITNESS_EVIDENCE_MAX: int = 20
const PROBE_SUSPECT_EVIDENCE_MIN: int = 10
const PROBE_SUSPECT_EVIDENCE_MAX: int = 15


static func process_witness_interview(
	crime_record: CrimeRecord,
	target_id: int,
	quality: int,
	objective: Dictionary,
) -> Dictionary:
	var is_witness: bool = target_id in crime_record.witnesses
	var is_suspect: bool = target_id in crime_record.known_suspects

	if not is_witness and not is_suspect:
		return {"evidence_gained": 0, "role": "none"}

	var evidence: int = 0
	var role: String = ""
	if is_witness:
		evidence = clampi(
			PROBE_WITNESS_EVIDENCE_MIN + quality * 2,
			PROBE_WITNESS_EVIDENCE_MIN,
			PROBE_WITNESS_EVIDENCE_MAX,
		)
		role = "witness"
		var interviewed: Array = objective.get("interviewed_witnesses", [])
		if target_id not in interviewed:
			interviewed.append(target_id)
			objective["interviewed_witnesses"] = interviewed
	else:
		evidence = clampi(
			PROBE_SUSPECT_EVIDENCE_MIN + quality,
			PROBE_SUSPECT_EVIDENCE_MIN,
			PROBE_SUSPECT_EVIDENCE_MAX,
		)
		role = "suspect"
		var interviewed: Array = objective.get("interviewed_suspects", [])
		if target_id not in interviewed:
			interviewed.append(target_id)
			objective["interviewed_suspects"] = interviewed

	crime_record.evidence_total += evidence
	objective["evidence_total"] = crime_record.evidence_total

	return {"evidence_gained": evidence, "role": role}


# -- Conviction Topic Generation (s57.47) --------------------------------------

const CRIME_TYPE_NAMES: Dictionary = {
	Enums.CrimeType.DISHONORABLE_CONDUCT: "Dishonorable Conduct",
	Enums.CrimeType.VIOLENCE: "Violence",
	Enums.CrimeType.UNSANCTIONED_DUEL_DEATH: "Unsanctioned Duel Death",
	Enums.CrimeType.SKIMMING: "Skimming",
	Enums.CrimeType.UNSANCTIONED_OPEN_KILLING: "Unsanctioned Killing",
	Enums.CrimeType.UNSANCTIONED_COVERT_KILLING: "Covert Killing",
	Enums.CrimeType.MAGISTRATE_CORRUPTION: "Magistrate Corruption",
	Enums.CrimeType.DUEL_DEFILEMENT: "Duel Defilement",
	Enums.CrimeType.TREASON: "Treason",
	Enums.CrimeType.MAHO: "Maho",
	Enums.CrimeType.OTHER: "Crime",
}

const TIER_MAP: Dictionary = {
	1: TopicData.Tier.TIER_1,
	2: TopicData.Tier.TIER_2,
	3: TopicData.Tier.TIER_3,
	4: TopicData.Tier.TIER_4,
}

const TOPIC_INITIAL_MOMENTUM: Dictionary = {
	1: 80.0,
	2: 50.0,
	3: 25.0,
	4: 10.0,
}


static func generate_conviction_topic(
	record: CrimeRecord,
	convicted: L5RCharacterData,
	topic_tier: int,
	next_topic_id: Array[int],
	ic_day: int,
) -> TopicData:
	if topic_tier <= 0 or topic_tier > 4:
		return null

	var crime_name: String = CRIME_TYPE_NAMES.get(record.crime_type, "Crime")
	var title: String = "%s convicted of %s" % [convicted.character_name, crime_name]

	var tier: TopicData.Tier = TIER_MAP.get(topic_tier, TopicData.Tier.TIER_4)
	var momentum: float = TOPIC_INITIAL_MOMENTUM.get(topic_tier, 10.0)

	var category: TopicData.Category = TopicData.Category.LEGAL
	if record.crime_type == Enums.CrimeType.MAHO:
		category = TopicData.Category.SUPERNATURAL
	elif record.crime_type == Enums.CrimeType.TREASON:
		category = TopicData.Category.POLITICAL

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] = topic_id + 1

	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id,
		title,
		tier,
		category,
		ic_day,
		momentum,
		[],
		convicted.clan,
		convicted.family,
		convicted.character_id,
		"crime",
		crime_name.to_lower().replace(" ", "_"),
	)
	topic.slug = "conviction_%d" % record.case_id
	topic.subject_role = "PERPETRATOR"
	return topic


static func generate_seppuku_refusal_topic(
	convicted: L5RCharacterData,
	next_topic_id: Array[int],
	ic_day: int,
) -> TopicData:
	var topic_id: int = next_topic_id[0]
	next_topic_id[0] = topic_id + 1

	var title: String = "%s refused seppuku" % convicted.character_name
	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id,
		title,
		TopicData.Tier.TIER_4,
		TopicData.Category.PERSONAL,
		ic_day,
		10.0,
		[],
		convicted.clan,
		convicted.family,
		convicted.character_id,
		"seppuku_refusal",
		"",
	)
	topic.slug = "seppuku_refusal_%d" % convicted.character_id
	topic.subject_role = "PERPETRATOR"
	return topic
