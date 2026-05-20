class_name CrimeSystem
## Crime severity classification and consequence mapping per GDD s57.47.
## Two-phase consequence model:
##   At-act: Honor loss fires immediately (Table 2.3, scaled by Honor Rank).
##   At-conviction: Glory, Infamy, Status, Topic tier are flat values.


# -- Table 2.3 Honor Loss by Rank (values are points, 10 pts = 1.0 rank) ------
# Each entry: [Rank0, Rank1-2, Rank3-4, Rank5-6, Rank7-8, Rank9-10]

const HONOR_TABLE_BREACH_MINOR: Array[int] = [0, 0, -1, -2, -2, -2]
const HONOR_TABLE_BREACH_MAJOR: Array[int] = [0, -2, -2, -2, -6, -6]
const HONOR_TABLE_BREACH_BLASPHEMOUS: Array[int] = [-1, -6, -10, -10, -16, -20]
const HONOR_TABLE_ACCEPTING_BRIBE: Array[int] = [0, 0, -3, -4, -7, -8]
const HONOR_TABLE_DISLOYALTY: Array[int] = [0, -2, -6, -10, -14, -18]
const HONOR_TABLE_ACCOMPLICE_HEINOUS: Array[int] = [-1, -4, -8, -12, -16, -20]
const HONOR_TABLE_ACCOMPLICE_MINOR: Array[int] = [0, -1, -4, -4, -8, -8]
const HONOR_TABLE_USING_LOW_SKILL: Array[int] = [0, -1, -2, -3, -6, -9]
const LOW_SKILL_DISCOVERY_GLORY: float = -0.3
const HONOR_TABLE_DISOBEYING_LORD: Array[int] = [0, -2, -2, -6, -6, -10]
const HONOR_TABLE_FLEEING_BATTLE: Array[int] = [0, -2, -4, -6, -8, -10]
const HONOR_TABLE_FOLLOWING_ORDERS: Array[int] = [6, 4, 0, 0, -2, -4]
const HONOR_TABLE_LYING: Array[int] = [0, -2, -4, -6, -8, -10]
const HONOR_TABLE_MANIPULATING: Array[int] = [0, -2, -4, -6, -8, -10]
const HONOR_TABLE_FALSE_COURTESY: Array[int] = [0, 0, -2, -6, -10, -10]
const HONOR_TABLE_DUPED_CRIMINAL: Array[int] = [-1, -4, -8, -12, -16, -18]
const HONOR_TABLE_DUPED_DISLOYAL: Array[int] = [0, -2, -4, -6, -10, -14]
const HONOR_TABLE_DUPED_FOOLISH: Array[int] = [0, -2, -4, -4, -6, -8]

const FULL_LOW_SKILL_EXEMPT_SCHOOLS: Array[String] = [
	"Shosuro Infiltrator",
	"Bitter Lies",
	"Kasuga Smuggler",
]

const HALF_LOW_SKILL_EXEMPT_SCHOOLS: Array[String] = [
	"Daidoji Harrier",
	"Daidoji Spymaster",
	"Ikoma Lion's Shadow",
]


static func get_low_skill_honor_cost(character: L5RCharacterData, skill_name: String = "") -> float:
	if skill_name == "Intimidation" and character.intimidation_honor_exempt:
		return 0.0
	if skill_name == "Commerce" and character.commerce_honor_exempt:
		return 0.0

	var honor_rank: int = HonorGlorySystem.get_honor_rank(character)
	var bracket: int = _get_rank_bracket(honor_rank)
	var points: int = HONOR_TABLE_USING_LOW_SKILL[bracket]
	var base_cost: float = points / 10.0

	var schools: Array[String] = [character.school]
	for path: String in character.school_paths:
		if path not in schools:
			schools.append(path)

	for school: String in schools:
		for s: String in FULL_LOW_SKILL_EXEMPT_SCHOOLS:
			if school.begins_with(s):
				return 0.0

	for school: String in schools:
		for s: String in HALF_LOW_SKILL_EXEMPT_SCHOOLS:
			if school.begins_with(s):
				return base_cost * 0.5

	if character.clan == "Scorpion":
		return base_cost * 0.5

	return base_cost


static func get_table_honor_cost(table: Array[int], honor_rank: int) -> float:
	var bracket: int = _get_rank_bracket(honor_rank)
	return table[bracket] / 10.0


static func get_disobeying_lord_honor(character: L5RCharacterData) -> float:
	return get_table_honor_cost(HONOR_TABLE_DISOBEYING_LORD, HonorGlorySystem.get_honor_rank(character))


static func get_disloyalty_honor(character: L5RCharacterData) -> float:
	return get_table_honor_cost(HONOR_TABLE_DISLOYALTY, HonorGlorySystem.get_honor_rank(character))


static func get_accepting_bribe_honor(character: L5RCharacterData) -> float:
	return get_table_honor_cost(HONOR_TABLE_ACCEPTING_BRIBE, HonorGlorySystem.get_honor_rank(character))


static func get_fleeing_battle_honor(character: L5RCharacterData) -> float:
	return get_table_honor_cost(HONOR_TABLE_FLEEING_BATTLE, HonorGlorySystem.get_honor_rank(character))


static func get_following_orders_honor(character: L5RCharacterData) -> float:
	return get_table_honor_cost(HONOR_TABLE_FOLLOWING_ORDERS, HonorGlorySystem.get_honor_rank(character))


static func get_lying_honor(character: L5RCharacterData) -> float:
	return get_table_honor_cost(HONOR_TABLE_LYING, HonorGlorySystem.get_honor_rank(character))


static func get_manipulating_honor(character: L5RCharacterData) -> float:
	return get_table_honor_cost(HONOR_TABLE_MANIPULATING, HonorGlorySystem.get_honor_rank(character))


static func get_false_courtesy_honor(character: L5RCharacterData) -> float:
	return get_table_honor_cost(HONOR_TABLE_FALSE_COURTESY, HonorGlorySystem.get_honor_rank(character))


static func get_duped_criminal_honor(character: L5RCharacterData) -> float:
	return get_table_honor_cost(HONOR_TABLE_DUPED_CRIMINAL, HonorGlorySystem.get_honor_rank(character))


static func get_duped_disloyal_honor(character: L5RCharacterData) -> float:
	return get_table_honor_cost(HONOR_TABLE_DUPED_DISLOYAL, HonorGlorySystem.get_honor_rank(character))


static func get_duped_foolish_honor(character: L5RCharacterData) -> float:
	return get_table_honor_cost(HONOR_TABLE_DUPED_FOOLISH, HonorGlorySystem.get_honor_rank(character))


# Maps CrimeType to the Table 2.3 row used for at-act honor loss.
const CRIME_HONOR_TABLE: Dictionary = {
	Enums.CrimeType.DISHONORABLE_CONDUCT: "BREACH_MINOR",
	Enums.CrimeType.VIOLENCE: "BREACH_MAJOR",
	Enums.CrimeType.UNSANCTIONED_DUEL_DEATH: "BREACH_MAJOR",
	Enums.CrimeType.SKIMMING: "ACCEPTING_BRIBE",
	Enums.CrimeType.UNSANCTIONED_OPEN_KILLING: "ACCOMPLICE_HEINOUS",
	Enums.CrimeType.UNSANCTIONED_COVERT_KILLING: "ACCOMPLICE_HEINOUS",
	Enums.CrimeType.MAGISTRATE_CORRUPTION: "ACCEPTING_BRIBE",
	Enums.CrimeType.DUEL_DEFILEMENT: "ACCOMPLICE_MINOR",
	Enums.CrimeType.TREASON: "DISLOYALTY",
	Enums.CrimeType.MAHO: "BREACH_BLASPHEMOUS",
	Enums.CrimeType.VIOLATION_EMPERORS_PEACE: "BREACH_BLASPHEMOUS",
	Enums.CrimeType.OTHER: "BREACH_MINOR",
}

# At-conviction consequences: [glory_delta, infamy_delta, status_delta, topic_tier]
# status_delta of -99.0 means "set to 0.0" (strip all status).
# Skimming uses 0.0 here — the GDD says "stripped of the office" not all status.
# Office removal is a role_position change, not a numeric status zeroing.
const CONVICTION_CONSEQUENCES: Dictionary = {
	Enums.CrimeType.DISHONORABLE_CONDUCT: [-0.1, 0.0, 0.0, 0],
	Enums.CrimeType.VIOLENCE: [-0.1, 0.0, 0.0, 4],
	Enums.CrimeType.UNSANCTIONED_DUEL_DEATH: [0.0, 0.0, 0.0, 4],
	Enums.CrimeType.SKIMMING: [-0.3, 0.5, 0.0, 3],
	Enums.CrimeType.UNSANCTIONED_OPEN_KILLING: [-0.5, 1.0, 0.0, 3],
	Enums.CrimeType.UNSANCTIONED_COVERT_KILLING: [-1.0, 2.0, 0.0, 3],
	Enums.CrimeType.MAGISTRATE_CORRUPTION: [-1.5, 2.0, -99.0, 2],
	Enums.CrimeType.DUEL_DEFILEMENT: [-0.5, 0.5, 0.0, 3],
	Enums.CrimeType.TREASON: [-2.0, 3.0, -99.0, 2],
	Enums.CrimeType.MAHO: [-3.0, 5.0, -99.0, 1],
	Enums.CrimeType.VIOLATION_EMPERORS_PEACE: [-3.0, 5.0, -99.0, 1],
	Enums.CrimeType.OTHER: [-0.1, 0.0, 0.0, 4],
}

const SEPPUKU_HONOR_BONUS: float = 1.0
const SEPPUKU_REFUSED_HONOR_PENALTY: float = -1.0
const SEPPUKU_REFUSED_INFAMY_PENALTY: float = 1.0

# Crime types where seppuku is offered per GDD s57.47.
const SEPPUKU_OFFERED_CRIMES: Array[int] = [
	Enums.CrimeType.UNSANCTIONED_OPEN_KILLING,
	Enums.CrimeType.UNSANCTIONED_COVERT_KILLING,
	Enums.CrimeType.MAGISTRATE_CORRUPTION,
	Enums.CrimeType.TREASON,
]

# Skimming seppuku threshold per GDD s57.47.6 (PROVISIONAL).
const SKIMMING_SEPPUKU_THRESHOLD: float = 10.0

# Dishonorable conduct escalation: 3+ offenses in 4-season window.
const ESCALATION_THRESHOLD: int = 3
const ESCALATION_WINDOW_SEASONS: int = 4


# -- Severity Lookup -----------------------------------------------------------

static func get_severity(crime_type: Enums.CrimeType) -> Enums.CrimeSeverity:
	match crime_type:
		Enums.CrimeType.DISHONORABLE_CONDUCT:
			return Enums.CrimeSeverity.MINOR
		Enums.CrimeType.VIOLENCE:
			return Enums.CrimeSeverity.MINOR
		Enums.CrimeType.UNSANCTIONED_DUEL_DEATH:
			return Enums.CrimeSeverity.MODERATE
		Enums.CrimeType.SKIMMING:
			return Enums.CrimeSeverity.MODERATE
		Enums.CrimeType.DUEL_DEFILEMENT:
			return Enums.CrimeSeverity.MODERATE
		Enums.CrimeType.UNSANCTIONED_OPEN_KILLING:
			return Enums.CrimeSeverity.SERIOUS
		Enums.CrimeType.UNSANCTIONED_COVERT_KILLING:
			return Enums.CrimeSeverity.SERIOUS
		Enums.CrimeType.MAGISTRATE_CORRUPTION:
			return Enums.CrimeSeverity.SERIOUS
		Enums.CrimeType.TREASON:
			return Enums.CrimeSeverity.CAPITAL
		Enums.CrimeType.MAHO:
			return Enums.CrimeSeverity.CAPITAL
		Enums.CrimeType.VIOLATION_EMPERORS_PEACE:
			return Enums.CrimeSeverity.CAPITAL
		_:
			return Enums.CrimeSeverity.MINOR


static func is_low_skill_crime_type(crime_type: Enums.CrimeType) -> bool:
	match crime_type:
		Enums.CrimeType.DISHONORABLE_CONDUCT, Enums.CrimeType.SKIMMING:
			return true
	return false


# -- Table 2.3 Lookup ---------------------------------------------------------

static func _get_honor_table(table_name: String) -> Array[int]:
	match table_name:
		"BREACH_MINOR": return HONOR_TABLE_BREACH_MINOR
		"BREACH_MAJOR": return HONOR_TABLE_BREACH_MAJOR
		"BREACH_BLASPHEMOUS": return HONOR_TABLE_BREACH_BLASPHEMOUS
		"ACCEPTING_BRIBE": return HONOR_TABLE_ACCEPTING_BRIBE
		"DISLOYALTY": return HONOR_TABLE_DISLOYALTY
		"ACCOMPLICE_HEINOUS": return HONOR_TABLE_ACCOMPLICE_HEINOUS
		"ACCOMPLICE_MINOR": return HONOR_TABLE_ACCOMPLICE_MINOR
		_: return HONOR_TABLE_BREACH_MINOR


static func _get_rank_bracket(honor_rank: int) -> int:
	if honor_rank <= 0:
		return 0
	if honor_rank <= 2:
		return 1
	if honor_rank <= 4:
		return 2
	if honor_rank <= 6:
		return 3
	if honor_rank <= 8:
		return 4
	return 5


static func get_at_act_honor_loss(crime_type: Enums.CrimeType, honor_rank: int) -> float:
	var table_name: String = CRIME_HONOR_TABLE.get(crime_type, "BREACH_MINOR")
	var table: Array[int] = _get_honor_table(table_name)
	var bracket: int = _get_rank_bracket(honor_rank)
	var points: int = table[bracket]
	return points / 10.0


# -- At-Act Phase (fires immediately on commission) ----------------------------

static func apply_at_act_consequences(character: L5RCharacterData, crime_type: Enums.CrimeType) -> Dictionary:
	var honor_rank: int = HonorGlorySystem.get_honor_rank(character)
	var honor_delta: float = get_at_act_honor_loss(crime_type, honor_rank)
	var actual_delta: float = HonorGlorySystem.apply_honor_change(character, honor_delta)
	return {"honor_delta": actual_delta}


# -- At-Conviction Phase (fires on formal conviction) -------------------------

static func apply_at_conviction_consequences(character: L5RCharacterData, record: CrimeRecord, victim_status: float = 0.0) -> Dictionary:
	var crime_type: Enums.CrimeType = record.crime_type
	var consequences: Array[float] = CONVICTION_CONSEQUENCES.get(crime_type, [-0.1, 0.0, 0.0, 4])

	var glory_delta: float = HonorGlorySystem.apply_glory_change(character, consequences[0])
	var infamy_delta: float = HonorGlorySystem.apply_infamy_change(character, consequences[1])

	var status_delta: float = 0.0
	if consequences[2] == -99.0:
		status_delta = HonorGlorySystem.apply_status_change(character, -character.status)
	else:
		status_delta = HonorGlorySystem.apply_status_change(character, consequences[2])

	record.legal_status = Enums.LegalStatus.DECREED_GUILTY

	var topic_tier: int = int(consequences[3])
	if crime_type == Enums.CrimeType.UNSANCTIONED_COVERT_KILLING:
		if victim_status >= HIGH_STATUS_THRESHOLD:
			topic_tier = 2

	return {
		"glory_delta": glory_delta,
		"infamy_delta": infamy_delta,
		"status_delta": status_delta,
		"topic_tier": topic_tier,
		"seppuku_offered": is_seppuku_eligible(crime_type, record.skimming_amount),
	}


# -- Seppuku Resolution -------------------------------------------------------

static func apply_seppuku_accepted(character: L5RCharacterData, record: CrimeRecord) -> Dictionary:
	record.seppuku_offered = true
	record.seppuku_accepted = true
	var honor_delta: float = HonorGlorySystem.apply_honor_change(character, SEPPUKU_HONOR_BONUS)
	return {"honor_delta": honor_delta, "character_dead": true}


static func apply_seppuku_refused(character: L5RCharacterData, record: CrimeRecord) -> Dictionary:
	record.seppuku_offered = true
	record.seppuku_accepted = false
	var honor_delta: float = HonorGlorySystem.apply_honor_change(character, SEPPUKU_REFUSED_HONOR_PENALTY)
	var infamy_delta: float = HonorGlorySystem.apply_infamy_change(character, SEPPUKU_REFUSED_INFAMY_PENALTY)
	return {
		"honor_delta": honor_delta,
		"infamy_delta": infamy_delta,
		"topic_tier": 4,
	}


# -- Covert Killing Topic Tier Escalation (s57.47) ----------------------------
# "Tier 3 (Tier 2 if high-Status victim)" — victim_status must be provided.

const HIGH_STATUS_THRESHOLD: float = 5.0


# -- CrimeRecord Factory ------------------------------------------------------

static func create_crime_record(
	case_id: int,
	crime_type: Enums.CrimeType,
	perpetrator_id: int,
	location: String,
	ic_day: int,
	victim_id: int = -1,
	concealment_tn: int = 0,
	witnesses: Array[int] = [],
) -> CrimeRecord:
	var record := CrimeRecord.new()
	record.case_id = case_id
	record.crime_type = crime_type
	record.severity = get_severity(crime_type)
	record.perpetrator_id = perpetrator_id
	record.victim_id = victim_id
	record.location = location
	record.ic_day_committed = ic_day
	record.concealment_tn = concealment_tn
	record.witnesses = witnesses
	return record


# -- Legal Status Transitions --------------------------------------------------

static func begin_investigation(record: CrimeRecord, magistrate_id: int) -> void:
	record.legal_status = Enums.LegalStatus.UNDER_INVESTIGATION
	record.investigating_magistrate_id = magistrate_id


static func formally_accuse(record: CrimeRecord) -> void:
	record.legal_status = Enums.LegalStatus.ACCUSED


static func clear_suspect(record: CrimeRecord) -> void:
	record.legal_status = Enums.LegalStatus.CLEAR


static func is_seppuku_eligible(crime_type: Enums.CrimeType, skimming_amount: float = 0.0) -> bool:
	if crime_type == Enums.CrimeType.SKIMMING:
		return skimming_amount > SKIMMING_SEPPUKU_THRESHOLD
	return crime_type in SEPPUKU_OFFERED_CRIMES


# -- Escalation Check (dishonorable conduct) -----------------------------------

static func check_escalation(records: Array[CrimeRecord], current_ic_day: int, days_per_season: int) -> bool:
	var window_days: int = ESCALATION_WINDOW_SEASONS * days_per_season
	var count: int = 0
	for record: CrimeRecord in records:
		if record is CrimeRecord:
			if record.crime_type == Enums.CrimeType.DISHONORABLE_CONDUCT:
				if current_ic_day - record.ic_day_committed <= window_days:
					count += 1
	return count >= ESCALATION_THRESHOLD
