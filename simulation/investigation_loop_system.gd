class_name InvestigationLoopSystem
## Investigation loop per GDD s11.3.13 and legal_status state machine per s11.3.14.
## Covers: zone presence/stealth, witness pool, evidence accumulation, crime scene
## examination, recall TN, evidence decay, state transitions, and CrimeRecord lifecycle.


# -- Evidence Weights (s11.3.13f) -----

const EVIDENCE_SCENE_MINOR: int = 10
const EVIDENCE_SCENE_SIGNIFICANT: int = 20
const EVIDENCE_SCENE_MAJOR: int = 30
const EVIDENCE_SCENE_PER_RAISE: int = 10
const EVIDENCE_PROBE_MIN: int = 10
const EVIDENCE_PROBE_MAX: int = 20
const EVIDENCE_KITSUKI_EYE: int = 15
const EVIDENCE_FAILED_BRIBE: int = 15
const EVIDENCE_FALSE_ALIBI: int = 10
const EVIDENCE_CO_CONSPIRATOR_MIN: int = 20
const EVIDENCE_CO_CONSPIRATOR_MAX: int = 30
const EVIDENCE_INTERCEPTED_LETTER: int = 50
const EVIDENCE_CONFESSION: int = 50
const EVIDENCE_MURDER_WEAPON: int = 40

const ACCUSATION_THRESHOLD: int = 40
const BRIBERY_TRIGGER_THRESHOLD: int = 25


# -- Witness Recall TN (s11.3.13b) -----

const RECALL_TN_SAME_DAY: int = 10
const RECALL_TN_SAME_MONTH: int = 15
const RECALL_TN_PREV_MONTH: int = 20
const RECALL_TN_TWO_MONTHS: int = 25
const RECALL_TN_NEAR_SEASON: int = 30

const DAYS_PER_MONTH: int = 28


static func get_recall_tn(days_elapsed: int) -> int:
	if days_elapsed <= 0:
		return RECALL_TN_SAME_DAY
	if days_elapsed <= DAYS_PER_MONTH:
		return RECALL_TN_SAME_MONTH
	if days_elapsed <= DAYS_PER_MONTH * 2:
		return RECALL_TN_PREV_MONTH
	if days_elapsed <= DAYS_PER_MONTH * 3:
		return RECALL_TN_TWO_MONTHS
	return RECALL_TN_NEAR_SEASON


static func is_recall_possible(days_elapsed: int) -> bool:
	return days_elapsed <= DAYS_PER_MONTH * 4


# -- Evidence Decay (s11.3.13d, s11.3.13g) -----

const DECAY_SAME_DAY: int = 0
const DECAY_SAME_WEEK: int = -2
const DECAY_SAME_MONTH: int = -5
const DECAY_PREV_MONTH: int = -10
const DECAY_NEAR_SEASON: int = -15

const DAYS_PER_WEEK: int = 7


static func get_scene_examination_penalty(days_elapsed: int) -> int:
	if days_elapsed <= 0:
		return DECAY_SAME_DAY
	if days_elapsed <= DAYS_PER_WEEK:
		return DECAY_SAME_WEEK
	if days_elapsed <= DAYS_PER_MONTH:
		return DECAY_SAME_MONTH
	if days_elapsed <= DAYS_PER_MONTH * 2:
		return DECAY_PREV_MONTH
	if days_elapsed <= DAYS_PER_MONTH * 4:
		return DECAY_NEAR_SEASON
	return -999


static func is_scene_viable(days_elapsed: int) -> bool:
	return days_elapsed <= DAYS_PER_MONTH * 4


# -- Crime Scene Evidence (s11.3.13d) -----

static func get_scene_evidence_weight(
	roll_result: int,
	concealment_tn: int,
	raises_called: int,
) -> int:
	var margin: int = roll_result - concealment_tn
	if margin < 0:
		return 0
	var base: int = EVIDENCE_SCENE_MINOR
	if margin >= 10:
		base = EVIDENCE_SCENE_MAJOR
	elif margin >= 5:
		base = EVIDENCE_SCENE_SIGNIFICANT
	return base + (raises_called * EVIDENCE_SCENE_PER_RAISE)


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


# -- Legal Status State Machine (s11.3.14) -----

enum LegalState {
	CLEAR,
	SUSPECTED,
	UNDER_INVESTIGATION,
	ACCUSED,
	DECREED_GUILTY,
	ACQUITTED,
	PARDONED,
	FUGITIVE,
}


static func can_transition(from_state: LegalState, to_state: LegalState) -> bool:
	match from_state:
		LegalState.CLEAR:
			return to_state == LegalState.SUSPECTED or \
				to_state == LegalState.UNDER_INVESTIGATION
		LegalState.SUSPECTED:
			return to_state == LegalState.UNDER_INVESTIGATION or \
				to_state == LegalState.CLEAR
		LegalState.UNDER_INVESTIGATION:
			return to_state == LegalState.ACCUSED or \
				to_state == LegalState.CLEAR or \
				to_state == LegalState.FUGITIVE
		LegalState.ACCUSED:
			return to_state == LegalState.DECREED_GUILTY or \
				to_state == LegalState.ACQUITTED or \
				to_state == LegalState.FUGITIVE
		LegalState.DECREED_GUILTY:
			return to_state == LegalState.PARDONED
		LegalState.FUGITIVE:
			return to_state == LegalState.DECREED_GUILTY
		_:
			return false


static func get_transition_trigger(
	from_state: LegalState,
	to_state: LegalState,
) -> String:
	if not can_transition(from_state, to_state):
		return "invalid"

	if from_state == LegalState.CLEAR and to_state == LegalState.SUSPECTED:
		return "signals_accumulate"
	if from_state == LegalState.CLEAR and to_state == LegalState.UNDER_INVESTIGATION:
		return "immediate_discovery"
	if from_state == LegalState.SUSPECTED and to_state == LegalState.UNDER_INVESTIGATION:
		return "lord_orders_investigation"
	if from_state == LegalState.SUSPECTED and to_state == LegalState.CLEAR:
		return "signals_dissipate"
	if from_state == LegalState.UNDER_INVESTIGATION and to_state == LegalState.ACCUSED:
		return "evidence_threshold_reached"
	if from_state == LegalState.UNDER_INVESTIGATION and to_state == LegalState.CLEAR:
		return "insufficient_evidence"
	if from_state == LegalState.UNDER_INVESTIGATION and to_state == LegalState.FUGITIVE:
		return "suspect_fled"
	if from_state == LegalState.ACCUSED and to_state == LegalState.DECREED_GUILTY:
		return "defense_failed"
	if from_state == LegalState.ACCUSED and to_state == LegalState.ACQUITTED:
		return "defense_succeeded"
	if from_state == LegalState.ACCUSED and to_state == LegalState.FUGITIVE:
		return "accused_fled"
	if from_state == LegalState.DECREED_GUILTY and to_state == LegalState.PARDONED:
		return "higher_lord_override"
	if from_state == LegalState.FUGITIVE and to_state == LegalState.DECREED_GUILTY:
		return "fugitive_captured"
	return "unknown"


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


static func get_initial_legal_state(discovery_type: DiscoveryType) -> LegalState:
	match discovery_type:
		DiscoveryType.IMMEDIATE:
			return LegalState.UNDER_INVESTIGATION
		DiscoveryType.GRADUAL:
			return LegalState.SUSPECTED
		DiscoveryType.SPECIALIZED:
			return LegalState.UNDER_INVESTIGATION
		_:
			return LegalState.UNDER_INVESTIGATION


# -- Accusation Check -----

static func should_accuse(evidence_total: int) -> bool:
	return evidence_total >= ACCUSATION_THRESHOLD


static func should_trigger_bribery_eval(evidence_total: int) -> bool:
	return evidence_total >= BRIBERY_TRIGGER_THRESHOLD


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
