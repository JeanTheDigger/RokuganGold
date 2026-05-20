class_name InvestigationSystem
## Crime scene examination and evidence gathering per GDD s11.3.13, s57.15, s57.16.
## Executor for EXAMINE_CRIME_SCENE action. Handles evidence accumulation,
## witness identification, UPHOLD_LAW self-initiation, witness PROBE evidence,
## threshold-based legal status transitions, and conviction topic generation.


const SCENE_EXAM_TN_FALLBACK: int = 15
const RAISE_MARGIN: int = 5

# Evidence weights per GDD s11.3.13f
const SCENE_EVIDENCE_MINOR: int = 10
const SCENE_EVIDENCE_SIGNIFICANT: int = 20
const SCENE_EVIDENCE_MAJOR: int = 30
const SCENE_EVIDENCE_PER_RAISE: int = 10

# Margin thresholds for scene examination (s11.3.13d)
const MARGIN_SIGNIFICANT: int = 5
const MARGIN_MAJOR: int = 10

# Evidence thresholds (s11.3.13f)
const ACCUSATION_THRESHOLD: int = 40
const BRIBERY_EVAL_TRIGGER: int = 25

# Additional evidence weights (s11.3.13f)
const EVIDENCE_KITSUKI_EYE: int = 15
const EVIDENCE_FAILED_BRIBE: int = 15
const EVIDENCE_FALSE_ALIBI: int = 10
const EVIDENCE_CO_CONSPIRATOR_MIN: int = 20
const EVIDENCE_CO_CONSPIRATOR_MAX: int = 30
const EVIDENCE_INTERCEPTED_LETTER_MIN: int = 20
const EVIDENCE_INTERCEPTED_LETTER_MAX: int = 50
const EVIDENCE_CONFESSION: int = 50
const EVIDENCE_MURDER_WEAPON: int = 40

# Elapsed time scene penalty brackets (s11.3.13d, in IC days)
const DAYS_PER_WEEK: int = 7
const DAYS_PER_MONTH: int = 30
const DAYS_PER_SEASON: int = 90

# Witness recall TN scaling (s11.3.13b)
const RECALL_TN_SAME_DAY: int = 10
const RECALL_TN_SAME_MONTH: int = 15
const RECALL_TN_PREVIOUS_MONTH: int = 20
const RECALL_TN_TWO_MONTHS: int = 25
const RECALL_TN_APPROACHING_SEASON: int = 30


static func examine_scene(
	magistrate: L5RCharacterData,
	crime_record: CrimeRecord,
	dice_engine: DiceEngine,
	ic_day: int,
) -> Dictionary:
	var concealment_tn: int = crime_record.concealment_tn
	var days_elapsed: int = ic_day - crime_record.ic_day_committed

	if is_scene_too_old(days_elapsed):
		return {
			"success": false,
			"evidence_gained": 0,
			"suspect_found": -1,
		}

	var margin: int = 0
	if concealment_tn <= 0:
		var roll_result: Dictionary = SkillResolver.resolve_skill_check(
			magistrate, dice_engine, "Investigation", 0
		)
		margin = roll_result.get("margin", 10)
	else:
		var time_penalty: int = get_scene_time_penalty(days_elapsed)
		var effective_tn: int = concealment_tn + time_penalty

		var result: Dictionary = SkillResolver.resolve_skill_check(
			magistrate, dice_engine, "Investigation", effective_tn
		)

		if not result["success"]:
			return {
				"success": false,
				"evidence_gained": 0,
				"suspect_found": -1,
			}
		margin = result["margin"]
	var base_evidence: int = _scene_evidence_by_margin(margin)
	var raises: int = maxi(0, int(margin / RAISE_MARGIN))
	var raise_evidence: int = raises * SCENE_EVIDENCE_PER_RAISE
	var evidence: int = base_evidence + raise_evidence

	crime_record.evidence_total += evidence

	var suspect_found: int = -1
	if raises >= 2 and crime_record.perpetrator_id >= 0:
		if crime_record.perpetrator_id not in crime_record.known_suspects:
			crime_record.known_suspects.append(crime_record.perpetrator_id)
			suspect_found = crime_record.perpetrator_id

	var threshold_crossed: String = check_thresholds(crime_record)

	return {
		"success": true,
		"evidence_gained": evidence,
		"suspect_found": suspect_found,
		"margin": margin,
		"raises": raises,
		"threshold_crossed": threshold_crossed,
	}


static func _scene_evidence_by_margin(margin: int) -> int:
	if margin >= MARGIN_MAJOR:
		return SCENE_EVIDENCE_MAJOR
	if margin >= MARGIN_SIGNIFICANT:
		return SCENE_EVIDENCE_SIGNIFICANT
	return SCENE_EVIDENCE_MINOR


static func get_scene_time_penalty(days_elapsed: int) -> int:
	if days_elapsed <= 0:
		return 0
	if days_elapsed <= DAYS_PER_WEEK:
		return 2
	if days_elapsed <= DAYS_PER_MONTH:
		return 5
	if days_elapsed <= DAYS_PER_MONTH * 2:
		return 10
	if days_elapsed <= DAYS_PER_SEASON:
		return 15
	return 99


static func get_witness_recall_tn(days_elapsed: int) -> int:
	if days_elapsed <= 0:
		return RECALL_TN_SAME_DAY
	if days_elapsed <= DAYS_PER_MONTH:
		return RECALL_TN_SAME_MONTH
	if days_elapsed <= DAYS_PER_MONTH * 2:
		return RECALL_TN_PREVIOUS_MONTH
	if days_elapsed <= DAYS_PER_MONTH * 3:
		return RECALL_TN_TWO_MONTHS
	if days_elapsed <= DAYS_PER_SEASON:
		return RECALL_TN_APPROACHING_SEASON
	return -1


# -- Threshold Checks (s11.3.13f) -----------------------------------------------

static func check_thresholds(crime_record: CrimeRecord) -> String:
	if crime_record.evidence_total >= ACCUSATION_THRESHOLD:
		if crime_record.legal_status != Enums.LegalStatus.ACCUSED and crime_record.legal_status != Enums.LegalStatus.DECREED_GUILTY:
			crime_record.legal_status = Enums.LegalStatus.ACCUSED
			return "accusation"
		return ""
	if crime_record.evidence_total >= BRIBERY_EVAL_TRIGGER:
		return "bribery_eval"
	return ""


# -- Additional Evidence Sources (s11.3.13f) ------------------------------------

static func add_evidence(crime_record: CrimeRecord, weight: int) -> String:
	crime_record.evidence_total += weight
	return check_thresholds(crime_record)


static func add_failed_bribe_evidence(crime_record: CrimeRecord) -> String:
	return add_evidence(crime_record, EVIDENCE_FAILED_BRIBE)


static func add_false_alibi_evidence(crime_record: CrimeRecord) -> String:
	return add_evidence(crime_record, EVIDENCE_FALSE_ALIBI)


static func add_kitsuki_eye_evidence(crime_record: CrimeRecord) -> String:
	return add_evidence(crime_record, EVIDENCE_KITSUKI_EYE)


static func add_confession_evidence(crime_record: CrimeRecord) -> String:
	return add_evidence(crime_record, EVIDENCE_CONFESSION)


static func add_murder_weapon_evidence(crime_record: CrimeRecord) -> String:
	return add_evidence(crime_record, EVIDENCE_MURDER_WEAPON)


static func add_co_conspirator_evidence(crime_record: CrimeRecord, quality: int) -> String:
	var weight: int = clampi(
		EVIDENCE_CO_CONSPIRATOR_MIN + quality * 2,
		EVIDENCE_CO_CONSPIRATOR_MIN,
		EVIDENCE_CO_CONSPIRATOR_MAX,
	)
	return add_evidence(crime_record, weight)


static func add_intercepted_letter_evidence(crime_record: CrimeRecord, detail_level: int) -> String:
	var weight: int = clampi(
		EVIDENCE_INTERCEPTED_LETTER_MIN + detail_level * 10,
		EVIDENCE_INTERCEPTED_LETTER_MIN,
		EVIDENCE_INTERCEPTED_LETTER_MAX,
	)
	return add_evidence(crime_record, weight)


static func is_scene_too_old(days_elapsed: int) -> bool:
	return days_elapsed > DAYS_PER_SEASON


static func is_recall_too_old(days_elapsed: int) -> bool:
	return days_elapsed > DAYS_PER_SEASON


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
	candidates: Array,
	characters_by_id: Dictionary,
	present_ids: Array,
) -> Array:
	if candidates.size() <= 1:
		return candidates.duplicate()

	var scored: Array = []
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

	var result: Array = []
	for entry: Dictionary in scored:
		result.append(entry["id"])
	return result


# -- UPHOLD_LAW Self-Initiation Wiring (s57.16.9) -----------------------------

static func check_jurisdiction(
	magistrate: L5RCharacterData,
	crime_record: CrimeRecord,
) -> bool:
	if magistrate.role_position == "Emerald Magistrate":
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
	crime_records: Array,
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
		"scene_exam_count": 0,
		"ic_day_committed": crime_record.ic_day_committed,
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
	crime_records: Array,
	active_topics: Array,
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

	var threshold_crossed: String = check_thresholds(crime_record)

	return {"evidence_gained": evidence, "role": role, "threshold_crossed": threshold_crossed}


# -- Blood Evidence Detection (Channel 2, s57.47.7) ---------------------------
# Passive detection when investigating a province with maho blood evidence.
# Roll: Investigation (Notice) / Perception vs concealment_tn + time penalty.

static func detect_blood_evidence(
	character: L5RCharacterData,
	crime_record: CrimeRecord,
	dice_engine: DiceEngine,
	ic_day: int,
) -> Dictionary:
	var days_elapsed: int = ic_day - crime_record.ic_day_committed
	if days_elapsed > DAYS_PER_SEASON:
		return {"detected": false, "reason": "evidence_expired"}

	var time_penalty: int = get_scene_time_penalty(days_elapsed)
	var effective_tn: int = crime_record.concealment_tn + time_penalty

	var check: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Investigation", effective_tn,
	)
	var total: int = check.get("total", 0)

	if check.get("success", false):
		return {"detected": true, "total": total, "tn": effective_tn}
	return {"detected": false, "total": total, "tn": effective_tn}


# -- Alibi Checking (s11.3.13e CHECK_ALIBI, resolved as part of PROBE) --------

const ALIBI_FALSE_EVIDENCE: int = 10
const ALIBI_GENUINE_WEIGHT: int = 15

static func check_alibi(
	alibi: Dictionary,
	alibi_witness: L5RCharacterData,
	magistrate: L5RCharacterData,
	crime_record: CrimeRecord,
	objective: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	var alibi_id: Variant = alibi.get("id", -1)
	var is_genuine: bool = alibi.get("genuine", false)
	var suspect_id: int = alibi.get("suspect_id", -1)

	var checked: Array = objective.get("checked_alibis", [])
	if alibi_id in checked:
		return {"already_checked": true}
	checked.append(alibi_id)
	objective["checked_alibis"] = checked

	if is_genuine:
		crime_record.evidence_total = maxi(0, crime_record.evidence_total - ALIBI_GENUINE_WEIGHT)
		objective["evidence_total"] = crime_record.evidence_total
		return {
			"genuine": true,
			"evidence_change": -ALIBI_GENUINE_WEIGHT,
			"suspect_cleared": suspect_id,
		}

	var is_co_conspirator: bool = alibi.get("co_conspirator", false)
	if is_co_conspirator and alibi_witness != null and dice_engine != null:
		var deceit_roll: int = _roll_sincerity_deceit(alibi_witness, dice_engine)
		var detect_roll: int = _roll_investigation_perception(magistrate, dice_engine)

		if deceit_roll >= detect_roll:
			return {
				"genuine": false,
				"co_conspirator_passed": true,
				"evidence_change": 0,
			}

		crime_record.evidence_total += ALIBI_FALSE_EVIDENCE
		objective["evidence_total"] = crime_record.evidence_total
		var threshold_crossed: String = check_thresholds(crime_record)
		return {
			"genuine": false,
			"co_conspirator_exposed": true,
			"co_conspirator_id": alibi_witness.character_id,
			"evidence_change": ALIBI_FALSE_EVIDENCE,
			"threshold_crossed": threshold_crossed,
		}

	crime_record.evidence_total += ALIBI_FALSE_EVIDENCE
	objective["evidence_total"] = crime_record.evidence_total
	var threshold_crossed: String = check_thresholds(crime_record)
	return {
		"genuine": false,
		"evidence_change": ALIBI_FALSE_EVIDENCE,
		"threshold_crossed": threshold_crossed,
	}


static func _roll_sincerity_deceit(
	character: L5RCharacterData,
	dice_engine: DiceEngine,
) -> int:
	var check: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Sincerity", 0,
	)
	return check.get("total", 0)


static func _roll_investigation_perception(
	character: L5RCharacterData,
	dice_engine: DiceEngine,
) -> int:
	var check: Dictionary = SkillResolver.resolve_skill_check(
		character, dice_engine, "Investigation", 0,
	)
	return check.get("total", 0)


# -- Lead Generation (s57.16.5) -----------------------------------------------

static func generate_leads_from_probe(
	target_id: int,
	probe_quality: int,
	crime_record: CrimeRecord,
	objective: Dictionary,
	characters_present: Array,
) -> Array:
	var leads: Array = []
	var unresolved: Array = objective.get("unresolved_leads", [])

	if probe_quality >= 3 and crime_record.perpetrator_id >= 0:
		if crime_record.perpetrator_id not in crime_record.known_suspects:
			var already_lead: bool = false
			for lead: Variant in unresolved:
				if lead is Dictionary and (lead as Dictionary).get("target_npc_id", -1) == crime_record.perpetrator_id:
					already_lead = true
					break
			if not already_lead:
				var lead: Dictionary = {
					"type": "witness",
					"target_npc_id": crime_record.perpetrator_id,
					"priority": 3,
					"source": "probe_testimony",
				}
				leads.append(lead)

	if probe_quality >= 2:
		for present_id: int in characters_present:
			if present_id == target_id:
				continue
			if present_id in crime_record.witnesses:
				continue
			if present_id in crime_record.known_suspects:
				continue
			var already_known: bool = false
			for lead: Variant in unresolved:
				if lead is Dictionary and (lead as Dictionary).get("target_npc_id", -1) == present_id:
					already_known = true
					break
			if not already_known:
				var lead: Dictionary = {
					"type": "witness",
					"target_npc_id": present_id,
					"priority": 1,
					"source": "mentioned_by_witness",
				}
				leads.append(lead)

	for lead: Dictionary in leads:
		unresolved.append(lead)
	objective["unresolved_leads"] = unresolved

	return leads


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
	Enums.CrimeType.VIOLATION_EMPERORS_PEACE: "Violation of the Emperor's Peace",
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
	next_topic_id: Array,
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
	next_topic_id: Array,
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


# -- Accusation Topic Generation (T3-20 BETRAYAL_ACCUSATION) -------------------

static func generate_accusation_topic(
	record: CrimeRecord,
	accused: L5RCharacterData,
	next_topic_id: Array,
	ic_day: int,
) -> TopicData:
	var crime_name: String = CRIME_TYPE_NAMES.get(record.crime_type, "Crime")
	var title: String = "%s accused of %s" % [accused.character_name, crime_name]

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] = topic_id + 1

	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id,
		title,
		TopicData.Tier.TIER_3,
		TopicData.Category.POLITICAL,
		ic_day,
		25.0,
		[],
		accused.clan,
		accused.family,
		accused.character_id,
		"accusation",
		crime_name.to_lower().replace(" ", "_"),
	)
	topic.slug = "accusation_%d" % record.case_id
	topic.subject_role = "PERPETRATOR"
	return topic


static func generate_investigation_opened_topic(
	record: CrimeRecord,
	magistrate: L5RCharacterData,
	next_topic_id: Array,
	ic_day: int,
) -> TopicData:
	var crime_name: String = CRIME_TYPE_NAMES.get(record.crime_type, "Crime")
	var title: String = "Investigation opened: %s at %s" % [crime_name, record.location]

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] = topic_id + 1

	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id,
		title,
		TopicData.Tier.TIER_4,
		TopicData.Category.LEGAL,
		ic_day,
		10.0,
		[],
		magistrate.clan,
		"",
		-1,
		"crime",
		"investigation_opened",
	)
	topic.slug = "investigation_%d" % record.case_id
	return topic


static func generate_bribery_attempt_topic(
	suspect: L5RCharacterData,
	magistrate: L5RCharacterData,
	record: CrimeRecord,
	next_topic_id: Array,
	ic_day: int,
) -> TopicData:
	var crime_name: String = CRIME_TYPE_NAMES.get(record.crime_type, "Crime")
	var title: String = "%s attempted to bribe %s during %s investigation" % [
		suspect.character_name, magistrate.character_name, crime_name
	]

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] = topic_id + 1

	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id,
		title,
		TopicData.Tier.TIER_3,
		TopicData.Category.POLITICAL,
		ic_day,
		20.0,
		[],
		suspect.clan,
		suspect.family,
		suspect.character_id,
		"crime",
		"bribery_attempt",
	)
	topic.slug = "bribery_attempt_%d" % record.case_id
	topic.subject_role = "PERPETRATOR"
	return topic


static func generate_fugitive_topic(
	fugitive: L5RCharacterData,
	next_topic_id: Array,
	ic_day: int,
) -> TopicData:
	var title: String = "%s is a fugitive from justice" % fugitive.character_name

	var topic_id: int = next_topic_id[0]
	next_topic_id[0] = topic_id + 1

	var topic: TopicData = TopicMomentumSystem.create_topic(
		topic_id,
		title,
		TopicData.Tier.TIER_3,
		TopicData.Category.POLITICAL,
		ic_day,
		30.0,
		[],
		fugitive.clan,
		fugitive.family,
		fugitive.character_id,
		"crime",
		"fugitive_declaration",
	)
	topic.slug = "fugitive_%d" % fugitive.character_id
	topic.subject_role = "PERPETRATOR"
	return topic
