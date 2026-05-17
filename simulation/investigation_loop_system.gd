class_name InvestigationLoopSystem
## Supplementary investigation mechanics per GDD s11.3.13.
## Covers witness tampering, criminal post-crime recall, discovery type
## classification, concealment skill mapping, and zone event log purge timing.
## Core evidence accumulation, recall TN, scene penalties, and state machine
## transitions are handled by InvestigationSystem and LegalStatusSystem.


# -- Criminal Recall (s11.3.13c Step 1) -----

const CRIMINAL_RECALL_TN: int = 10


static func get_criminal_recall_tn() -> int:
	return CRIMINAL_RECALL_TN


# -- Witness Tampering (s11.3.13c Step 3) -----

enum TamperingMethod {
	BRIBE_WITNESS,
	INTIMIDATE_WITNESS,
	KILL_WITNESS,
	DO_NOTHING,
}

const WITNESS_BRIBE_EVIDENCE_ON_FAIL: int = 10
const WITNESS_INTIMIDATE_EVIDENCE_ON_FAIL: int = 10
const FALSE_ALIBI_EVIDENCE_ON_FAIL: int = 10


static func get_tampering_success_result(method: TamperingMethod) -> Dictionary:
	match method:
		TamperingMethod.BRIBE_WITNESS:
			return {
				"witness_silenced": true,
				"co_conspirator_created": true,
				"secret_tier": 2,
				"hostile_action": false,
			}
		TamperingMethod.INTIMIDATE_WITNESS:
			return {
				"witness_silenced": true,
				"co_conspirator_created": false,
				"hostile_action": true,
				"provocation_flag": true,
				"zone_event_log_recorded": true,
			}
		TamperingMethod.KILL_WITNESS:
			return {
				"witness_silenced": true,
				"testimony_eliminated": true,
				"new_crime_created": true,
				"co_conspirator_created": false,
			}
		_:
			return {
				"witness_silenced": false,
				"risk": 0,
			}


static func get_tampering_failure_result(method: TamperingMethod) -> Dictionary:
	match method:
		TamperingMethod.BRIBE_WITNESS:
			return {
				"witness_silenced": false,
				"evidence_if_reported": WITNESS_BRIBE_EVIDENCE_ON_FAIL,
				"witness_hostile": false,
				"witness_suspicious": true,
			}
		TamperingMethod.INTIMIDATE_WITNESS:
			return {
				"witness_silenced": false,
				"evidence_if_reported": WITNESS_INTIMIDATE_EVIDENCE_ON_FAIL,
				"witness_hostile": true,
				"witness_motivated_to_report": true,
			}
		_:
			return {"witness_silenced": false}


# -- Investigation Entry Points (s11.3.13h) -----

enum DiscoveryType {
	IMMEDIATE,
	GRADUAL,
	SPECIALIZED,
}

const MAGISTRATE_ASSIGNMENT_MIN_DAYS: int = 1
const MAGISTRATE_ASSIGNMENT_MAX_DAYS: int = 3


static func get_discovery_type(crime_type: String) -> DiscoveryType:
	match crime_type:
		"murder", "violence":
			return DiscoveryType.IMMEDIATE
		"treason", "skimming":
			return DiscoveryType.GRADUAL
		"maho":
			return DiscoveryType.SPECIALIZED
		_:
			return DiscoveryType.IMMEDIATE


static func get_initial_legal_status(discovery_type: DiscoveryType) -> Enums.LegalStatus:
	match discovery_type:
		DiscoveryType.IMMEDIATE:
			return Enums.LegalStatus.UNDER_INVESTIGATION
		DiscoveryType.GRADUAL:
			return Enums.LegalStatus.SUSPECTED
		DiscoveryType.SPECIALIZED:
			return Enums.LegalStatus.UNDER_INVESTIGATION
		_:
			return Enums.LegalStatus.UNDER_INVESTIGATION


# -- Crime Record Status -----

enum CrimeRecordStatus {
	OPEN,
	CLOSED_INSUFFICIENT_EVIDENCE,
	SOLVED,
	BURIED,
}


static func get_case_close_status(
	has_conviction: bool,
	was_bribed: bool,
) -> CrimeRecordStatus:
	if was_bribed:
		return CrimeRecordStatus.BURIED
	if has_conviction:
		return CrimeRecordStatus.SOLVED
	return CrimeRecordStatus.CLOSED_INSUFFICIENT_EVIDENCE


# -- Zone Event Log Purge (s11.3.13g) -----

const ZONE_LOG_PURGE_SEASONS: int = 1
const DAYS_PER_SEASON: int = 90


static func is_zone_log_available(days_since_crime: int) -> bool:
	return days_since_crime <= DAYS_PER_SEASON


# -- Concealment TN at Crime Time (s11.3.13d) -----

enum ConcealmentMethod {
	OPEN,
	POISON,
	STEALTH,
}


static func get_concealment_skill(method: ConcealmentMethod) -> String:
	match method:
		ConcealmentMethod.OPEN:
			return "none"
		ConcealmentMethod.POISON:
			return "Medicine/Intelligence"
		ConcealmentMethod.STEALTH:
			return "Stealth/Agility"
		_:
			return "none"


static func get_open_crime_concealment_tn() -> int:
	return 0
