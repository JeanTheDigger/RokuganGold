class_name InvestigationSystem
## Crime scene examination and evidence gathering per GDD s57.15, s57.16.
## Executor for EXAMINE_CRIME_SCENE action. Handles evidence accumulation,
## witness identification, and UPHOLD_LAW self-initiation probability.


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
