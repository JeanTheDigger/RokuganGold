class_name LegalStatusSystem
## Legal status state machine per GDD s11.3.14.
## Manages per-character legal case entries with validated state transitions.
## Each character can have multiple concurrent cases progressing independently.


const VALID_TRANSITIONS: Dictionary = {
	Enums.LegalStatus.CLEAR: [
		Enums.LegalStatus.SUSPECTED,
		Enums.LegalStatus.UNDER_INVESTIGATION,
	],
	Enums.LegalStatus.SUSPECTED: [
		Enums.LegalStatus.UNDER_INVESTIGATION,
		Enums.LegalStatus.CLEAR,
	],
	Enums.LegalStatus.UNDER_INVESTIGATION: [
		Enums.LegalStatus.ACCUSED,
		Enums.LegalStatus.CLEAR,
		Enums.LegalStatus.FUGITIVE,
	],
	Enums.LegalStatus.ACCUSED: [
		Enums.LegalStatus.DECREED_GUILTY,
		Enums.LegalStatus.ACQUITTED,
		Enums.LegalStatus.FUGITIVE,
	],
	Enums.LegalStatus.DECREED_GUILTY: [
		Enums.LegalStatus.PARDONED,
	],
	Enums.LegalStatus.ACQUITTED: [],
	Enums.LegalStatus.PARDONED: [],
	Enums.LegalStatus.FUGITIVE: [
		Enums.LegalStatus.DECREED_GUILTY,
	],
}

const ACCUSATION_THRESHOLD: int = 40


static func is_valid_transition(from: Enums.LegalStatus, to: Enums.LegalStatus) -> bool:
	if not VALID_TRANSITIONS.has(from):
		return false
	var targets: Array[int] = VALID_TRANSITIONS[from]
	return to in targets


static func open_case(
	character: L5RCharacterData,
	crime_record_id: int,
	immediate_investigation: bool,
) -> LegalCaseEntry:
	var entry := LegalCaseEntry.new()
	entry.crime_record_id = crime_record_id
	if immediate_investigation:
		entry.state = Enums.LegalStatus.UNDER_INVESTIGATION
	else:
		entry.state = Enums.LegalStatus.SUSPECTED
	character.legal_cases.append(entry)
	return entry


static func transition(
	entry: LegalCaseEntry,
	new_state: Enums.LegalStatus,
	ic_day: int = -1,
) -> Dictionary:
	if not is_valid_transition(entry.state, new_state):
		return {
			"success": false,
			"error": "invalid_transition",
			"from": entry.state,
			"to": new_state,
		}

	var old_state: Enums.LegalStatus = entry.state
	entry.state = new_state

	if new_state == Enums.LegalStatus.ACCUSED:
		entry.accusation_timestamp = ic_day
	if new_state == Enums.LegalStatus.DECREED_GUILTY or new_state == Enums.LegalStatus.ACQUITTED or new_state == Enums.LegalStatus.PARDONED:
		entry.verdict_timestamp = ic_day

	return {
		"success": true,
		"from": old_state,
		"to": new_state,
	}


static func add_evidence(
	entry: LegalCaseEntry,
	evidence_type: String,
	weight: int,
	source: String,
	ic_day: int,
) -> Dictionary:
	entry.evidence_items.append({
		"type": evidence_type,
		"weight": weight,
		"source": source,
		"timestamp": ic_day,
	})
	entry.evidence_total += weight

	var threshold_crossed: String = ""
	if entry.evidence_total >= ACCUSATION_THRESHOLD:
		if entry.state == Enums.LegalStatus.UNDER_INVESTIGATION:
			threshold_crossed = "accusation"

	return {
		"new_total": entry.evidence_total,
		"threshold_crossed": threshold_crossed,
	}


static func get_case(
	character: L5RCharacterData,
	crime_record_id: int,
) -> LegalCaseEntry:
	for entry: LegalCaseEntry in character.legal_cases:
		if entry.crime_record_id == crime_record_id:
			return entry
	return null


static func get_active_cases(character: L5RCharacterData) -> Array[LegalCaseEntry]:
	var active: Array[LegalCaseEntry] = []
	for entry: LegalCaseEntry in character.legal_cases:
		if entry.state != Enums.LegalStatus.CLEAR and entry.state != Enums.LegalStatus.ACQUITTED and entry.state != Enums.LegalStatus.PARDONED:
			active.append(entry)
	return active


static func has_active_case(character: L5RCharacterData) -> bool:
	return get_active_cases(character).size() > 0


static func is_fugitive(character: L5RCharacterData) -> bool:
	for entry: LegalCaseEntry in character.legal_cases:
		if entry.state == Enums.LegalStatus.FUGITIVE:
			return true
	return false


static func is_accused(character: L5RCharacterData) -> bool:
	for entry: LegalCaseEntry in character.legal_cases:
		if entry.state == Enums.LegalStatus.ACCUSED:
			return true
	return false


static func get_worst_state(character: L5RCharacterData) -> Enums.LegalStatus:
	var severity_order: Array[int] = [
		Enums.LegalStatus.FUGITIVE,
		Enums.LegalStatus.DECREED_GUILTY,
		Enums.LegalStatus.ACCUSED,
		Enums.LegalStatus.UNDER_INVESTIGATION,
		Enums.LegalStatus.SUSPECTED,
	]
	for state: Enums.LegalStatus in severity_order:
		for entry: LegalCaseEntry in character.legal_cases:
			if entry.state == state:
				return state
	return Enums.LegalStatus.CLEAR


static func close_case(
	character: L5RCharacterData,
	crime_record_id: int,
) -> bool:
	var entry: LegalCaseEntry = get_case(character, crime_record_id)
	if entry == null:
		return false
	if entry.state == Enums.LegalStatus.UNDER_INVESTIGATION or entry.state == Enums.LegalStatus.SUSPECTED:
		entry.state = Enums.LegalStatus.CLEAR
		return true
	return false


static func flee(
	entry: LegalCaseEntry,
	ic_day: int,
) -> Dictionary:
	if entry.state != Enums.LegalStatus.UNDER_INVESTIGATION and entry.state != Enums.LegalStatus.ACCUSED:
		return {"success": false, "error": "cannot_flee_from_state", "state": entry.state}
	var was_accused: bool = entry.state == Enums.LegalStatus.ACCUSED
	entry.state = Enums.LegalStatus.FUGITIVE
	return {
		"success": true,
		"was_accused": was_accused,
		"generates_topic": true,
		"topic_tier": 3,
	}


static func capture_fugitive(
	entry: LegalCaseEntry,
	ic_day: int,
) -> Dictionary:
	if entry.state != Enums.LegalStatus.FUGITIVE:
		return {"success": false, "error": "not_a_fugitive"}
	entry.state = Enums.LegalStatus.DECREED_GUILTY
	entry.verdict_timestamp = ic_day
	return {
		"success": true,
		"verdict_enforced": true,
	}


static func pardon(
	entry: LegalCaseEntry,
	ic_day: int,
) -> Dictionary:
	if entry.state != Enums.LegalStatus.DECREED_GUILTY:
		return {"success": false, "error": "not_guilty"}
	entry.state = Enums.LegalStatus.PARDONED
	entry.verdict_timestamp = ic_day
	return {
		"success": true,
		"generates_topic": true,
		"topic_tier": 3,
	}


static func acquit(
	entry: LegalCaseEntry,
	ic_day: int,
) -> Dictionary:
	if entry.state != Enums.LegalStatus.ACCUSED:
		return {"success": false, "error": "not_accused"}
	entry.state = Enums.LegalStatus.ACQUITTED
	entry.verdict_timestamp = ic_day
	return {
		"success": true,
		"can_reinvestigate_with_new_evidence": true,
	}
