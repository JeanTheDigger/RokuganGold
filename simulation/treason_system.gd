class_name TreasonSystem
## Treason-specific mechanics per GDD s11.3.8.
## Adds treason evidence weights, defense hearing, authority chain,
## co-conspirator naming strategy, and lord response evaluation.
## Kolat integration (s11.3.8f) deferred — s54.7 is REFERENCE only.


# -- Treason-specific evidence weights (s11.3.8b) ---------

const HARD_INTERCEPTED_LETTER: int = 50
const HARD_CO_CONSPIRATOR_TESTIMONY: int = 45
const HARD_CONFESSION: int = 50
const HARD_CAUGHT_IN_ACT: int = 40

const CIRC_OBJECTIVE_STALL_PER_SEASON: int = 5
const CIRC_DISPOSITION_ANOMALY: int = 8
const CIRC_SUSPICIOUS_MEETING: int = 5
const CIRC_UNEXPLAINED_ABSENCE: int = 3
const CIRC_VOTING_AGAINST_LORD: int = 5
const CIRC_FAILED_TO_EXECUTE_ORDER: int = 10

const ACCUSATION_THRESHOLD: int = 40
const REACCUSATION_NEW_EVIDENCE_MIN: int = 20


enum TreasonEvidenceType {
	INTERCEPTED_LETTER,
	CO_CONSPIRATOR_TESTIMONY,
	CONFESSION,
	CAUGHT_IN_ACT,
	OBJECTIVE_STALL,
	DISPOSITION_ANOMALY,
	SUSPICIOUS_MEETING,
	UNEXPLAINED_ABSENCE,
	VOTING_AGAINST_LORD,
	FAILED_ORDER,
}

const EVIDENCE_WEIGHTS: Dictionary = {
	TreasonEvidenceType.INTERCEPTED_LETTER: HARD_INTERCEPTED_LETTER,
	TreasonEvidenceType.CO_CONSPIRATOR_TESTIMONY: HARD_CO_CONSPIRATOR_TESTIMONY,
	TreasonEvidenceType.CONFESSION: HARD_CONFESSION,
	TreasonEvidenceType.CAUGHT_IN_ACT: HARD_CAUGHT_IN_ACT,
	TreasonEvidenceType.OBJECTIVE_STALL: CIRC_OBJECTIVE_STALL_PER_SEASON,
	TreasonEvidenceType.DISPOSITION_ANOMALY: CIRC_DISPOSITION_ANOMALY,
	TreasonEvidenceType.SUSPICIOUS_MEETING: CIRC_SUSPICIOUS_MEETING,
	TreasonEvidenceType.UNEXPLAINED_ABSENCE: CIRC_UNEXPLAINED_ABSENCE,
	TreasonEvidenceType.VOTING_AGAINST_LORD: CIRC_VOTING_AGAINST_LORD,
	TreasonEvidenceType.FAILED_ORDER: CIRC_FAILED_TO_EXECUTE_ORDER,
}

const HARD_EVIDENCE_TYPES: Array = [
	TreasonEvidenceType.INTERCEPTED_LETTER,
	TreasonEvidenceType.CO_CONSPIRATOR_TESTIMONY,
	TreasonEvidenceType.CONFESSION,
	TreasonEvidenceType.CAUGHT_IN_ACT,
]


static func get_evidence_weight(evidence_type: TreasonEvidenceType) -> int:
	return EVIDENCE_WEIGHTS.get(evidence_type, 0)


static func is_hard_evidence(evidence_type: TreasonEvidenceType) -> bool:
	return evidence_type in HARD_EVIDENCE_TYPES


static func add_treason_evidence(
	case_entry: LegalCaseEntry,
	evidence_type: TreasonEvidenceType,
	ic_day: int,
) -> Dictionary:
	var weight: int = get_evidence_weight(evidence_type)
	var was_below: bool = case_entry.evidence_total < ACCUSATION_THRESHOLD

	case_entry.evidence_total += weight
	case_entry.evidence_items.append({
		"type": evidence_type,
		"weight": weight,
		"ic_day": ic_day,
		"hard": is_hard_evidence(evidence_type),
	})

	var crossed_threshold: bool = was_below and case_entry.evidence_total >= ACCUSATION_THRESHOLD

	return {
		"weight_added": weight,
		"new_total": case_entry.evidence_total,
		"crossed_threshold": crossed_threshold,
		"is_hard_evidence": is_hard_evidence(evidence_type),
	}


static func can_formally_accuse(case_entry: LegalCaseEntry) -> bool:
	return case_entry.evidence_total >= ACCUSATION_THRESHOLD


# -- Defense Hearing (s11.3.8c) -----

static func resolve_defense_hearing(
	sincerity_roll: int,
	evidence_total: int,
	accused_honor_rank: int,
) -> Dictionary:
	var testimony_weight: int = accused_honor_rank * 5
	var effective_evidence: int = maxi(evidence_total - testimony_weight, 0)

	var defense_succeeded: bool = sincerity_roll >= effective_evidence

	if defense_succeeded:
		var halved_total: int = evidence_total / 2
		return {
			"defense_succeeded": true,
			"evidence_halved_to": halved_total,
			"political_shield_active": true,
			"reaccusation_requires": REACCUSATION_NEW_EVIDENCE_MIN,
		}

	return {
		"defense_succeeded": false,
		"accusation_stands": true,
		"proceed_to_judgment": true,
	}


static func can_reaccuse(
	case_entry: LegalCaseEntry,
	evidence_at_acquittal: int,
) -> Dictionary:
	var new_evidence: int = case_entry.evidence_total - evidence_at_acquittal
	var can_reaccuse_flag: bool = new_evidence >= REACCUSATION_NEW_EVIDENCE_MIN

	return {
		"new_evidence_since_acquittal": new_evidence,
		"meets_threshold": can_reaccuse_flag,
		"required": REACCUSATION_NEW_EVIDENCE_MIN,
	}


# -- Authority Chain (s11.3.8d) -----

static func can_convict(
	lord_status: float,
	vassal_status: float,
) -> Dictionary:
	var has_authority: bool = lord_status > vassal_status
	return {
		"has_authority": has_authority,
		"must_escalate": not has_authority,
	}


enum EscalationTarget {
	CLAN_CHAMPION,
	EMPEROR,
}


static func get_escalation_target(
	lord_is_provincial_daimyo: bool,
) -> EscalationTarget:
	if lord_is_provincial_daimyo:
		return EscalationTarget.CLAN_CHAMPION
	return EscalationTarget.EMPEROR


enum InterventionType {
	PARDON,
	OVERTURN,
	COMMUTE,
}


static func evaluate_intervention(
	intervention: InterventionType,
	intervener_status: float,
	convicting_lord_status: float,
	intervener: L5RCharacterData = null,
) -> Dictionary:
	if intervener_status <= convicting_lord_status:
		return {"valid": false, "reason": "insufficient_status"}

	var base_cost: float = 0.0
	var disposition_hit: int = 0
	match intervention:
		InterventionType.PARDON:
			base_cost = -0.5
			disposition_hit = -15
		InterventionType.OVERTURN:
			base_cost = -0.3
			disposition_hit = -10
		InterventionType.COMMUTE:
			base_cost = -0.2
			disposition_hit = -5
	var honor_cost: float = CrimeSystem.scale_honor_by_rank(base_cost, intervener) if intervener != null else base_cost

	return {
		"valid": true,
		"honor_cost": honor_cost,
		"disposition_hit_from_vassals": disposition_hit,
		"undermines_authority": intervention == InterventionType.PARDON,
	}


# -- Co-Conspirator Naming (s11.3.8e) -----

static func should_name_co_conspirators(
	primary_virtue: int,
) -> Dictionary:
	var names_publicly: bool = false
	var reason: String = ""

	match primary_virtue:
		Enums.BushidoVirtue.GI:
			names_publicly = true
			reason = "honesty_demands_it"
		Enums.BushidoVirtue.MEIYO:
			names_publicly = true
			reason = "honor_requires_transparency"
		Enums.BushidoVirtue.CHUGI:
			names_publicly = false
			reason = "continued_surveillance"
		Enums.ShouridoVirtue.SEIGYO:
			names_publicly = false
			reason = "quiet_investigation_continues"
		_:
			names_publicly = false
			reason = "strategic_default"

	return {
		"names_publicly": names_publicly,
		"reason": reason,
		"co_conspirators_flagged": names_publicly,
		"names_kept_in_intel_db": not names_publicly,
	}


# -- False Accusation Consequence (s11.3.8e) -----

const FALSE_ACCUSATION_HONOR_LOSS: float = -0.5
const FALSE_ACCUSATION_DISPOSITION_HIT: int = -15


static func apply_false_accusation_penalty(lord: L5RCharacterData = null) -> Dictionary:
	var honor: float = CrimeSystem.scale_honor_by_rank(FALSE_ACCUSATION_HONOR_LOSS, lord) if lord != null else FALSE_ACCUSATION_HONOR_LOSS
	return {
		"honor_change": honor,
		"disposition_hit_all_vassals": FALSE_ACCUSATION_DISPOSITION_HIT,
		"chilling_effect": true,
	}


# -- Refused Seppuku Path (s11.3.8d) -----

const REFUSED_SEPPUKU_HONOR_LOSS: float = -5.0
const REFUSED_SEPPUKU_INFAMY_GAIN: float = 3.0


static func apply_refused_seppuku(convicted: L5RCharacterData = null) -> Dictionary:
	var honor: float = CrimeSystem.scale_honor_by_rank(REFUSED_SEPPUKU_HONOR_LOSS, convicted) if convicted != null else REFUSED_SEPPUKU_HONOR_LOSS
	return {
		"new_legal_status": "ronin",
		"honor_change": honor,
		"infamy_gain": REFUSED_SEPPUKU_INFAMY_GAIN,
		"status_set_to": 0.0,
		"exile": true,
	}


# -- Lord Response to Suspicion (s11.3.8g) -----

enum SuspicionResponse {
	INCREASE_SURVEILLANCE,
	RESTRICT_ACCESS,
	TEST_LOYALTY,
	CONFRONT_DIRECTLY,
	WAIT_FOR_PROOF,
}

static var BUSHIDO_RESPONSE_PREFERENCE: Dictionary = {
	Enums.BushidoVirtue.YU: SuspicionResponse.CONFRONT_DIRECTLY,
	Enums.BushidoVirtue.JIN: SuspicionResponse.TEST_LOYALTY,
	Enums.BushidoVirtue.GI: SuspicionResponse.CONFRONT_DIRECTLY,
}

static var SHOURIDO_RESPONSE_PREFERENCE: Dictionary = {
	Enums.ShouridoVirtue.SEIGYO: SuspicionResponse.WAIT_FOR_PROOF,
	Enums.ShouridoVirtue.DOSATSU: SuspicionResponse.INCREASE_SURVEILLANCE,
	Enums.ShouridoVirtue.KANPEKI: SuspicionResponse.WAIT_FOR_PROOF,
	Enums.ShouridoVirtue.KETSUI: SuspicionResponse.CONFRONT_DIRECTLY,
}


static func get_preferred_response(
	primary_virtue: int,
) -> SuspicionResponse:
	if BUSHIDO_RESPONSE_PREFERENCE.has(primary_virtue):
		return BUSHIDO_RESPONSE_PREFERENCE[primary_virtue]
	if SHOURIDO_RESPONSE_PREFERENCE.has(primary_virtue):
		return SHOURIDO_RESPONSE_PREFERENCE[primary_virtue]
	return SuspicionResponse.INCREASE_SURVEILLANCE


static func evaluate_suspicion_response(
	response: SuspicionResponse,
) -> Dictionary:
	match response:
		SuspicionResponse.INCREASE_SURVEILLANCE:
			return {
				"action": "assign_probe",
				"ap_cost": true,
				"tips_off_suspect": false,
				"recorded_in_zone_log": true,
			}
		SuspicionResponse.RESTRICT_ACCESS:
			return {
				"action": "reassign_vassal",
				"ap_cost": false,
				"tips_off_suspect": true,
				"limits_damage": true,
			}
		SuspicionResponse.TEST_LOYALTY:
			return {
				"action": "assign_conflicting_objective",
				"ap_cost": false,
				"tips_off_suspect": false,
				"reveals_intent": true,
			}
		SuspicionResponse.CONFRONT_DIRECTLY:
			return {
				"action": "probe_vassal",
				"ap_cost": true,
				"tips_off_suspect": true,
				"sincerity_vs_investigation": true,
			}
		SuspicionResponse.WAIT_FOR_PROOF:
			return {
				"action": "passive_intelligence",
				"ap_cost": false,
				"tips_off_suspect": false,
				"patience_required": true,
			}
	return {}
