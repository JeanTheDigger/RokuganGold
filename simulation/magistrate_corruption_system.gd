class_name MagistrateCorruptionSystem
## Magistrate corruption and bribery system per GDD s11.3.11.
## Handles: bribery personality gates, resistance rolls, bribe acceptance/refusal
## consequences, evidence destruction, magistrate extortion, failed bribe reporting.


# -- Bribery Resistance (s11.3.11f Step 6) -----

const HONOR_RESISTANCE_MULTIPLIER: int = 5
const BRIBE_ACCEPTED_HONOR_LOSS: float = -0.5
const FAILED_BRIBE_EVIDENCE_BONUS: int = 15


static func get_bribery_resistance_bonus(honor_rank: int) -> int:
	return honor_rank * HONOR_RESISTANCE_MULTIPLIER


# -- Personality Gates (s11.3.11g) -----

enum BriberyPermission {
	BLOCKED,
	CONDITIONAL,
	UNRESTRICTED,
}

enum ConditionalReason {
	NONE,
	PROTECTING_INNOCENTS,
	PROTECTING_OTHERS,
	INTERMEDIARY_ONLY,
	LORD_ASSIGNED,
}


static func get_bushido_bribery_permission(
	virtue: Enums.BushidoVirtue,
) -> BriberyPermission:
	match virtue:
		Enums.BushidoVirtue.GI, Enums.BushidoVirtue.MAKOTO, Enums.BushidoVirtue.MEIYO:
			return BriberyPermission.BLOCKED
		Enums.BushidoVirtue.JIN, Enums.BushidoVirtue.YU, \
		Enums.BushidoVirtue.REI, Enums.BushidoVirtue.CHUGI:
			return BriberyPermission.CONDITIONAL
		_:
			return BriberyPermission.UNRESTRICTED


static func get_shourido_bribery_permission(
	virtue: Enums.ShouridoVirtue,
) -> BriberyPermission:
	match virtue:
		Enums.ShouridoVirtue.SEIGYO, Enums.ShouridoVirtue.KETSUI, \
		Enums.ShouridoVirtue.DOSATSU, Enums.ShouridoVirtue.CHISHIKI, \
		Enums.ShouridoVirtue.KANPEKI, Enums.ShouridoVirtue.KYORYOKU, \
		Enums.ShouridoVirtue.ISHI:
			return BriberyPermission.UNRESTRICTED
		_:
			return BriberyPermission.UNRESTRICTED


static func get_conditional_reason(
	virtue: Enums.BushidoVirtue,
) -> ConditionalReason:
	match virtue:
		Enums.BushidoVirtue.JIN:
			return ConditionalReason.PROTECTING_INNOCENTS
		Enums.BushidoVirtue.YU:
			return ConditionalReason.PROTECTING_OTHERS
		Enums.BushidoVirtue.REI:
			return ConditionalReason.INTERMEDIARY_ONLY
		Enums.BushidoVirtue.CHUGI:
			return ConditionalReason.LORD_ASSIGNED
		_:
			return ConditionalReason.NONE


static func evaluate_bribery_permission(
	magistrate_data: L5RCharacterData,
) -> Dictionary:
	if magistrate_data.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return {
			"permission": get_shourido_bribery_permission(magistrate_data.shourido_virtue),
			"conditional_reason": ConditionalReason.NONE,
		}
	var perm: BriberyPermission = get_bushido_bribery_permission(
		magistrate_data.bushido_virtue
	)
	var reason: ConditionalReason = ConditionalReason.NONE
	if perm == BriberyPermission.CONDITIONAL:
		reason = get_conditional_reason(magistrate_data.bushido_virtue)
	return {
		"permission": perm,
		"conditional_reason": reason,
	}


# -- Bribery Evaluation Trigger (s11.3.11g) -----

const BRIBERY_EVALUATION_THRESHOLD: int = 25
const ACCUSATION_THRESHOLD: int = 40


static func should_evaluate_bribery(evidence_total: int) -> bool:
	return evidence_total >= BRIBERY_EVALUATION_THRESHOLD


# -- Bribe Acceptance Consequences (s11.3.11f Step 7b) -----

enum EvidenceType {
	PHYSICAL,
	TESTIMONY,
}


static func get_bribe_acceptance_result(
	evidence_items: Array[Dictionary],
) -> Dictionary:
	var destroyed_weight: int = 0
	var suppressed_weight: int = 0
	var remaining_items: Array[Dictionary] = []

	for item in evidence_items:
		var etype: int = item.get("type", EvidenceType.PHYSICAL)
		var weight: int = item.get("weight", 0)
		if etype == EvidenceType.PHYSICAL:
			destroyed_weight += weight
		else:
			suppressed_weight += weight
			remaining_items.append(item)

	return {
		"destroyed_weight": destroyed_weight,
		"suppressed_weight": suppressed_weight,
		"remaining_testimony": remaining_items,
		"honor_loss": BRIBE_ACCEPTED_HONOR_LOSS,
		"secret_tier": 1,
		"case_status": "buried",
	}


static func get_evidence_total_after_corruption(
	original_total: int,
	evidence_items: Array[Dictionary],
) -> int:
	var physical_weight: int = 0
	for item in evidence_items:
		if item.get("type", EvidenceType.PHYSICAL) == EvidenceType.PHYSICAL:
			physical_weight += item.get("weight", 0)
	return maxi(original_total - physical_weight, 0)


# -- Bribe Refusal Consequences (s11.3.11f Step 7a, s11.3.11k) -----

enum RefusalReportBehavior {
	REPORT_PUBLIC,
	REPORT_LORD_PRIVATE,
	REPORT_FORMAL,
	HOLD_AS_LEVERAGE,
	OBSERVE_SILENTLY,
}


static func get_bribe_refusal_result(is_direct_approach: bool) -> Dictionary:
	return {
		"evidence_bonus": FAILED_BRIBE_EVIDENCE_BONUS,
		"separate_offense": true,
		"briber_identity_known": is_direct_approach,
	}


static func get_refusal_report_behavior(
	magistrate: L5RCharacterData,
) -> RefusalReportBehavior:
	if magistrate.shourido_virtue != Enums.ShouridoVirtue.NONE:
		match magistrate.shourido_virtue:
			Enums.ShouridoVirtue.SEIGYO:
				return RefusalReportBehavior.HOLD_AS_LEVERAGE
			Enums.ShouridoVirtue.DOSATSU:
				return RefusalReportBehavior.OBSERVE_SILENTLY
			_:
				return RefusalReportBehavior.REPORT_FORMAL

	match magistrate.bushido_virtue:
		Enums.BushidoVirtue.GI:
			return RefusalReportBehavior.REPORT_PUBLIC
		Enums.BushidoVirtue.YU:
			return RefusalReportBehavior.REPORT_PUBLIC
		Enums.BushidoVirtue.CHUGI:
			return RefusalReportBehavior.REPORT_LORD_PRIVATE
		Enums.BushidoVirtue.MEIYO:
			return RefusalReportBehavior.REPORT_FORMAL
		Enums.BushidoVirtue.MAKOTO:
			return RefusalReportBehavior.REPORT_PUBLIC
		_:
			return RefusalReportBehavior.REPORT_FORMAL


# -- Evidence Destruction (s11.3.11h) -----

static func destroy_evidence(
	evidence_items: Array[Dictionary],
) -> Dictionary:
	var destroyed: Array[Dictionary] = []
	var surviving: Array[Dictionary] = []
	var weight_removed: int = 0

	for item in evidence_items:
		var etype: int = item.get("type", EvidenceType.PHYSICAL)
		if etype == EvidenceType.PHYSICAL:
			destroyed.append(item)
			weight_removed += item.get("weight", 0)
		else:
			surviving.append(item)

	return {
		"destroyed": destroyed,
		"surviving": surviving,
		"weight_removed": weight_removed,
	}


static func recover_suppressed_testimony(
	suppressed_items: Array[Dictionary],
) -> Dictionary:
	var recovered_weight: int = 0
	for item in suppressed_items:
		recovered_weight += item.get("weight", 0)
	return {
		"recovered_items": suppressed_items,
		"recovered_weight": recovered_weight,
	}


# -- Magistrate Extortion (s11.3.11j) -----

static func get_extortion_bargain_result(
	temptation_roll_succeeded: bool,
	base_demand_koku: int,
) -> Dictionary:
	if temptation_roll_succeeded:
		return {
			"accepted": true,
			"final_koku": base_demand_koku,
			"bargained_down": false,
		}
	return {
		"accepted": true,
		"final_koku": maxi(base_demand_koku / 2, 1),
		"bargained_down": true,
	}


static func can_magistrate_extort(magistrate: L5RCharacterData) -> bool:
	if magistrate.shourido_virtue != Enums.ShouridoVirtue.NONE:
		match magistrate.shourido_virtue:
			Enums.ShouridoVirtue.SEIGYO, Enums.ShouridoVirtue.KYORYOKU, \
			Enums.ShouridoVirtue.DOSATSU:
				return true
			_:
				return false

	match magistrate.bushido_virtue:
		Enums.BushidoVirtue.GI, Enums.BushidoVirtue.MAKOTO:
			return false
		_:
			return false


# -- Jurisdiction (s11.3.11c) -----

static func can_investigate_corrupt_magistrate(
	investigator_rank: int,
	corrupt_magistrate_rank: int,
	is_emerald_magistrate: bool,
) -> bool:
	if is_emerald_magistrate:
		return true
	return investigator_rank >= corrupt_magistrate_rank


# -- Corruption Spiral (s11.3.11f Step 7b) -----

static func get_corruption_spiral_resistance(
	base_honor_rank: int,
	bribes_accepted: int,
) -> int:
	var effective_honor: float = maxf(
		float(base_honor_rank) - (float(bribes_accepted) * 0.5), 0.0
	)
	return int(effective_honor) * HONOR_RESISTANCE_MULTIPLIER


# -- Scope of Exposure (s11.3.11d) -----

static func get_exposure_scope() -> Dictionary:
	return {
		"active_cases_affected": true,
		"past_closed_cases_reopened": false,
		"requires_independent_investigation": true,
	}


# -- Punishment (s11.3.11e) -----

const CORRUPTION_TOPIC_TIER: int = 2


static func get_corruption_punishment() -> Dictionary:
	return {
		"severity": "treason_equivalent",
		"seppuku_offered": true,
		"topic_tier": CORRUPTION_TOPIC_TIER,
		"appointing_lord_disposition_hit": true,
	}
