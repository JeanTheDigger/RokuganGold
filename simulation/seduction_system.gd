class_name SeductionSystem

# ==============================================================================
# Seduction Actions per GDD s12.8
# Category 6, 1 AP, Temptation vs Etiquette + Willpower + Honor Rank
# ==============================================================================

enum SeductionVariant {
	SEDUCE,
	SEDUCE_FOR_INFO,
	SEDUCE_FOR_ACCESS,
	SEDUCE_FOR_LEVERAGE,
	SEDUCE_TO_COMPROMISE,
}

enum EntanglementState {
	NONE,
	ACTIVE,
	NEGLECTED,
	BROKEN,
}

# -- Constants -----------------------------------------------------------------

const BASE_TN: int = 15
const SEDUCE_DISPOSITION_BONUS: int = 5
const MAINTENANCE_WINDOW_IC_DAYS: int = 16
const MISSED_WINDOWS_TO_BREAK: int = 3

const AFFAIR_SEVERITY_UNMARRIED: SecretData.Severity = SecretData.Severity.TIER_4
const AFFAIR_SEVERITY_MARRIED: SecretData.Severity = SecretData.Severity.TIER_3
const AFFAIR_SEVERITY_POLITICAL: SecretData.Severity = SecretData.Severity.TIER_2
const AFFAIR_SEVERITY_CROSS_CLAN: SecretData.Severity = SecretData.Severity.TIER_1

const BREAKUP_DISPOSITION_LOSS: Dictionary = {
	"low": -5,
	"moderate": -15,
	"high": -30,
}

const HONOR_COST: float = -0.3
const INFAMY_GAIN: float = 0.1


# ==============================================================================
# Seduction Resolution
# ==============================================================================

static func resolve_seduction(
	seducer: L5RCharacterData,
	target: L5RCharacterData,
	variant: SeductionVariant,
	dice_engine: DiceEngine,
	raises_called: int = 0,
) -> Dictionary:
	var tempt_rank: int = seducer.skills.get("Temptation", 0)
	if tempt_rank == 0:
		return {"success": false, "reason": "no_temptation_skill"}

	var etiquette_rank: int = target.skills.get("Etiquette", 0)
	var honor_rank: int = int(target.honor)
	var defense_tn: int = BASE_TN + etiquette_rank + target.willpower + honor_rank

	var rolled: int = seducer.awareness + tempt_rank
	var kept: int = seducer.awareness
	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept)
	var needed: int = defense_tn + (raises_called * 5)
	var success: bool = result.total >= needed
	var margin: int = result.total - needed

	HonorGlorySystem.apply_honor_change(seducer, HONOR_COST)
	HonorGlorySystem.apply_infamy_change(seducer, INFAMY_GAIN)

	if not success:
		return {
			"success": false,
			"roll_total": result.total,
			"tn": needed,
			"margin": margin,
			"honor_cost": HONOR_COST,
		}

	var effects: Dictionary = _get_variant_effects(variant, margin)

	return {
		"success": true,
		"roll_total": result.total,
		"tn": needed,
		"margin": margin,
		"honor_cost": HONOR_COST,
		"variant": variant,
		"effects": effects,
		"creates_entanglement": true,
	}


static func _get_variant_effects(variant: SeductionVariant, margin: int) -> Dictionary:
	match variant:
		SeductionVariant.SEDUCE:
			return {"disposition_change": SEDUCE_DISPOSITION_BONUS}
		SeductionVariant.SEDUCE_FOR_INFO:
			return {"info_gained": true, "raises_for_detail": int(margin / 5)}
		SeductionVariant.SEDUCE_FOR_ACCESS:
			return {"access_granted": true}
		SeductionVariant.SEDUCE_FOR_LEVERAGE:
			return {"leverage_gained": true}
		SeductionVariant.SEDUCE_TO_COMPROMISE:
			return {"compromised": true}
		_:
			return {}


# ==============================================================================
# Entanglement Lifecycle
# ==============================================================================

static func create_entanglement(
	seducer_id: int,
	target_id: int,
	current_ic_day: int,
) -> Dictionary:
	return {
		"seducer_id": seducer_id,
		"target_id": target_id,
		"state": EntanglementState.ACTIVE,
		"created_ic_day": current_ic_day,
		"last_maintained_ic_day": current_ic_day,
		"missed_windows": 0,
	}


static func check_maintenance(
	entanglement: Dictionary,
	current_ic_day: int,
) -> Dictionary:
	var last: int = entanglement.get("last_maintained_ic_day", 0)
	var days_since: int = current_ic_day - last
	var windows_missed: int = days_since / MAINTENANCE_WINDOW_IC_DAYS

	if windows_missed <= 0:
		return {"needs_maintenance": false, "state": entanglement["state"]}

	var total_missed: int = entanglement.get("missed_windows", 0) + windows_missed

	if total_missed >= MISSED_WINDOWS_TO_BREAK:
		return {
			"needs_maintenance": true,
			"state": EntanglementState.BROKEN,
			"missed_windows": total_missed,
		}
	elif total_missed > 0:
		return {
			"needs_maintenance": true,
			"state": EntanglementState.NEGLECTED,
			"missed_windows": total_missed,
		}

	return {"needs_maintenance": false, "state": entanglement["state"]}


static func maintain_entanglement(
	entanglement: Dictionary,
	current_ic_day: int,
) -> void:
	entanglement["last_maintained_ic_day"] = current_ic_day
	entanglement["missed_windows"] = 0
	entanglement["state"] = EntanglementState.ACTIVE


static func break_entanglement(
	entanglement: Dictionary,
	target_disposition_toward_seducer: int,
) -> Dictionary:
	entanglement["state"] = EntanglementState.BROKEN

	var attachment: String = _get_attachment_level(target_disposition_toward_seducer)
	var disp_loss: int = BREAKUP_DISPOSITION_LOSS.get(attachment, -5)

	return {
		"disposition_loss": disp_loss,
		"attachment_level": attachment,
	}


static func _get_attachment_level(disposition: int) -> String:
	if disposition >= 31:
		return "high"
	elif disposition >= 0:
		return "moderate"
	return "low"


# ==============================================================================
# Affair Secret Severity
# ==============================================================================

static func get_affair_severity(
	seducer_married: bool,
	target_married: bool,
	is_political_marriage: bool,
	is_cross_clan: bool,
) -> SecretData.Severity:
	if is_cross_clan:
		return AFFAIR_SEVERITY_CROSS_CLAN
	if is_political_marriage:
		return AFFAIR_SEVERITY_POLITICAL
	if seducer_married or target_married:
		return AFFAIR_SEVERITY_MARRIED
	return AFFAIR_SEVERITY_UNMARRIED
