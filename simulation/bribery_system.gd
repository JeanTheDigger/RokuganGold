class_name BriberySystem
## Magistrate bribery pipeline per GDD s11.3.11.
## Covers: NPC personality gates, resistance rolls, success/failure consequences,
## evidence destruction, and failed-bribe reporting behavior.


enum BribeResult {
	REFUSED,
	ACCEPTED,
	BLOCKED_BY_PERSONALITY,
}

enum ReportBehavior {
	REPORT_PUBLIC,
	REPORT_PRIVATE,
	REPORT_FORMAL,
	HOLD_LEVERAGE,
	HOLD_INTELLIGENCE,
	REPORT_LOUD,
}

enum BribeCurrency {
	KOKU,
	FAVOR,
}

# Personality gates (s11.3.11g)
const ALWAYS_BLOCKED_BUSHIDO: Array[int] = [
	Enums.BushidoVirtue.GI,
	Enums.BushidoVirtue.MAKOTO,
	Enums.BushidoVirtue.MEIYO,
]

const CONDITIONAL_BUSHIDO: Array[int] = [
	Enums.BushidoVirtue.JIN,
	Enums.BushidoVirtue.YU,
	Enums.BushidoVirtue.REI,
	Enums.BushidoVirtue.CHUGI,
]

# Honor multiplier for magistrate resistance (s11.3.11f Step 6)
const HONOR_RESISTANCE_MULTIPLIER: int = 5

# Evidence weight on failed bribe (s11.3.11f Step 7a)
const FAILED_BRIBE_EVIDENCE: int = 15

# Hidden honor loss on acceptance (s11.3.11f Step 7b)
const ACCEPTANCE_HONOR_LOSS: float = -0.5

# Bribery evaluation trigger threshold (s11.3.11g)
const BRIBERY_EVAL_EVIDENCE_THRESHOLD: int = 25


static func can_attempt_bribe(
	character: L5RCharacterData,
	is_protecting_other: bool,
	lord_assigned: bool,
	has_intermediary: bool,
) -> bool:
	if character.shourido_virtue != Enums.ShouridoVirtue.NONE:
		return true

	if character.bushido_virtue in ALWAYS_BLOCKED_BUSHIDO:
		return false

	match character.bushido_virtue:
		Enums.BushidoVirtue.JIN:
			return is_protecting_other
		Enums.BushidoVirtue.YU:
			return is_protecting_other
		Enums.BushidoVirtue.REI:
			return has_intermediary
		Enums.BushidoVirtue.CHUGI:
			return lord_assigned

	return true


static func calculate_resistance_tn(magistrate: L5RCharacterData) -> int:
	var honor_rank: int = HonorGlorySystem.get_honor_rank(magistrate)
	return honor_rank * HONOR_RESISTANCE_MULTIPLIER


static func attempt_bribe(
	briber: L5RCharacterData,
	magistrate: L5RCharacterData,
	dice_engine: DiceEngine,
	bribe_value_bonus: int = 0,
) -> Dictionary:
	if not can_attempt_bribe(briber, false, false, false):
		return {
			"result": BribeResult.BLOCKED_BY_PERSONALITY,
			"evidence_gained": 0,
		}

	var honor_bonus: int = calculate_resistance_tn(magistrate)

	var briber_result: Dictionary = SkillResolver.resolve_skill_check(
		briber, dice_engine, "Temptation", 0,
		0, "", Enums.Trait.NONE, 0, 0, bribe_value_bonus,
	)
	var briber_total: int = briber_result.get("total", 0)

	var magistrate_result: Dictionary = SkillResolver.resolve_skill_check(
		magistrate, dice_engine, "Etiquette", 0,
		0, "", Enums.Trait.WILLPOWER, 0, 0, honor_bonus,
	)
	var magistrate_total: int = magistrate_result.get("total", 0)

	if briber_total >= magistrate_total:
		return {
			"result": BribeResult.ACCEPTED,
			"evidence_gained": 0,
			"briber_total": briber_total,
			"magistrate_total": magistrate_total,
		}

	return {
		"result": BribeResult.REFUSED,
		"evidence_gained": FAILED_BRIBE_EVIDENCE,
		"briber_total": briber_total,
		"magistrate_total": magistrate_total,
	}


static func apply_bribe_accepted(
	magistrate: L5RCharacterData,
	crime_record: CrimeRecord,
) -> Dictionary:
	HonorGlorySystem.apply_honor_change(magistrate, ACCEPTANCE_HONOR_LOSS)

	var suppressed_evidence: int = crime_record.evidence_total
	crime_record.evidence_total = 0
	crime_record.legal_status = Enums.LegalStatus.CLEAR

	return {
		"honor_loss": ACCEPTANCE_HONOR_LOSS,
		"evidence_suppressed": suppressed_evidence,
		"creates_secret": true,
		"secret_tier": 1,
	}


static func apply_bribe_refused(
	crime_record: CrimeRecord,
) -> Dictionary:
	crime_record.evidence_total += FAILED_BRIBE_EVIDENCE
	var threshold: String = InvestigationSystem.check_thresholds(crime_record)
	return {
		"evidence_added": FAILED_BRIBE_EVIDENCE,
		"threshold_crossed": threshold,
		"generates_separate_offense": true,
	}


static func destroy_physical_evidence(
	crime_record: CrimeRecord,
	evidence_weight: int,
) -> Dictionary:
	var old_total: int = crime_record.evidence_total
	crime_record.evidence_total = maxi(0, crime_record.evidence_total - evidence_weight)
	var actual_removed: int = old_total - crime_record.evidence_total
	var stalls_case: bool = crime_record.evidence_total < InvestigationSystem.ACCUSATION_THRESHOLD
	return {
		"evidence_removed": actual_removed,
		"new_total": crime_record.evidence_total,
		"case_stalled": stalls_case,
	}


static func get_report_behavior(magistrate: L5RCharacterData) -> ReportBehavior:
	if magistrate.shourido_virtue != Enums.ShouridoVirtue.NONE:
		match magistrate.shourido_virtue:
			Enums.ShouridoVirtue.SEIGYO:
				return ReportBehavior.HOLD_LEVERAGE
			Enums.ShouridoVirtue.DOSATSU:
				return ReportBehavior.HOLD_INTELLIGENCE
			_:
				return ReportBehavior.REPORT_FORMAL

	match magistrate.bushido_virtue:
		Enums.BushidoVirtue.GI:
			return ReportBehavior.REPORT_PUBLIC
		Enums.BushidoVirtue.YU:
			return ReportBehavior.REPORT_LOUD
		Enums.BushidoVirtue.CHUGI:
			return ReportBehavior.REPORT_PRIVATE
		Enums.BushidoVirtue.MEIYO:
			return ReportBehavior.REPORT_FORMAL
		_:
			return ReportBehavior.REPORT_FORMAL


static func generates_public_topic(behavior: ReportBehavior) -> bool:
	return behavior == ReportBehavior.REPORT_PUBLIC or behavior == ReportBehavior.REPORT_LOUD


static func should_evaluate_bribery(evidence_total: int) -> bool:
	return evidence_total >= BRIBERY_EVAL_EVIDENCE_THRESHOLD
