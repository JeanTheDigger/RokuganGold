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

# Defense TN = etiquette_rank + willpower + honor_rank. No base addend — the formula is
# complete as stated. Confirmed 0 in s12.8c.
const BASE_TN: int = 0
const SEDUCE_DISPOSITION_BONUS: int = 5
const MAINTENANCE_WINDOW_IC_DAYS: int = 16
const MISSED_WINDOWS_TO_BREAK: int = 3

# s12.8 line 271 (LOCKED): "Failure on any Seduction action: the target is not interested,
# disposition -3. Critical failure (miss TN by 10+): ... disposition -10."
const FAILURE_DISPOSITION_LOSS: int = -3
const CRITICAL_FAILURE_DISPOSITION_LOSS: int = -10
const CRITICAL_FAILURE_MARGIN: int = 10

# s12.8 line 273 (LOCKED): "the target's disposition toward the actor decays at -2 per
# missed [maintenance] window."
const NEGLECT_WINDOW_DISPOSITION_LOSS: int = -2

const AFFAIR_SEVERITY_UNMARRIED: SecretData.Severity = SecretData.Severity.TIER_4
const AFFAIR_SEVERITY_MARRIED: SecretData.Severity = SecretData.Severity.TIER_3
const AFFAIR_SEVERITY_POLITICAL: SecretData.Severity = SecretData.Severity.TIER_2

const BREAKUP_DISPOSITION_LOSS: Dictionary = {
	"low": -5,
	"high": -15,
}

# Natural (neglect) break: when three consecutive maintenance windows pass without contact the
# entanglement breaks and the target's disposition toward the actor drops -10, "feeling used and
# abandoned" (s12.8 line 273, LOCKED). Distinct from the FORMAL breakup arbiter break_entanglement
# (-5/-15, s12.8 line 275), which is a deliberate action with no ActionID yet.
const NEGLECT_BREAK_DISPOSITION_LOSS: int = -10

# GDD specifies honor cost only. Infamy accrues via scandal topic on exposure, not at use.
# Confirmed 0 in s12.8c.
const INFAMY_GAIN: float = 0.0


# ==============================================================================
# Seduction Resolution
# ==============================================================================

## s12.8 line 271 / s52 line 111 (LOCKED): "A straight target can only be seduced by the
## opposite gender, a gay target only by the same gender, a bisexual target by either."
static func is_orientation_compatible(actor_gender: String, target_orientation: String, target_gender: String) -> bool:
	match target_orientation:
		"straight":
			return actor_gender != target_gender
		"gay":
			return actor_gender == target_gender
		"bisexual":
			return true
	return true


static func resolve_seduction(
	seducer: L5RCharacterData,
	target: L5RCharacterData,
	variant: SeductionVariant,
	dice_engine: DiceEngine,
	raises_called: int = 0,
) -> Dictionary:
	# s12.8 line 271 (LOCKED): "Targeting an incompatible orientation auto-fails with no
	# roll -- the system checks before the action fires, same pattern as the met_characters
	# precondition."
	if not is_orientation_compatible(seducer.gender, target.orientation, target.gender):
		return {"success": false, "reason": "incompatible_orientation"}

	var tempt_rank: int = seducer.skills.get("Temptation", 0)
	if tempt_rank == 0:
		return {"success": false, "reason": "no_temptation_skill"}

	# STUDENT_OF_SHOURIDO (s45): effective Honor rank is 5 minimum for social defense.
	var honor_rank: int = AdvantageSystem.get_shourido_honor_bonus(target, int(target.honor))

	# s24 Rank-5 contested-roll masteries: Temptation +5 flat (line 437), Etiquette +1k0
	# (line 67). s45 Lechery: the target's Lechery disadvantage grants the actor +1k0 when
	# the actor's gender matches the target's attraction -- already guaranteed true here by
	# the orientation-compatibility gate above, since an incompatible pairing already
	# returned before any roll.
	var seducer_mastery: Dictionary = SkillMasterySystem.contested_bonus("Temptation", tempt_rank)
	var lechery_bonus: Dictionary = AdvantageSystem.get_attacker_bonus_from_target(
		target, "Temptation", {"is_seduction": true, "attacker_gender_matches": true},
	)
	var etiquette_rank: int = target.skills.get("Etiquette", 0)
	var target_mastery: Dictionary = SkillMasterySystem.contested_bonus("Etiquette", etiquette_rank)

	# Contested Temptation roll (s12.8c / s34): the seducer rolls Temptation; the target ROLLS
	# their resistance (Etiquette/Willpower + Honor) rather than presenting a static TN, so
	# Soul of Stone's +3k0 manipulation resist attaches via the is_manipulation_resist context.
	# Called raises raise the bar the seducer must clear. BASE_TN (0) folds into the seducer roll.
	var seducer_result: Dictionary = SkillResolver.resolve_skill_check(
		seducer, dice_engine, "Temptation", BASE_TN,
		0, "", Enums.Trait.NONE,
		int(seducer_mastery.get("rolled", 0)) + int(lechery_bonus.get("rolled", 0)),
		int(seducer_mastery.get("kept", 0)) + int(lechery_bonus.get("kept", 0)),
		int(seducer_mastery.get("flat", 0)),
	)
	var target_result: Dictionary = SkillResolver.resolve_skill_check(
		target, dice_engine, "Etiquette", 0,
		0, "", Enums.Trait.WILLPOWER,
		int(target_mastery.get("rolled", 0)), int(target_mastery.get("kept", 0)),
		honor_rank + int(target_mastery.get("flat", 0)),
		-1, {"is_manipulation_resist": true},
	)
	var seducer_total: int = seducer_result.get("total", 0)
	var target_total: int = target_result.get("total", 0)
	var bar: int = target_total + (raises_called * 5)
	var success: bool = seducer_total >= bar
	var margin: int = seducer_total - target_total

	var honor_cost: float = CrimeSystem.get_low_skill_honor_cost(seducer, "Temptation")
	HonorGlorySystem.apply_honor_change(seducer, honor_cost)
	HonorGlorySystem.apply_infamy_change(seducer, INFAMY_GAIN)

	if not success:
		# s12.8 line 271 (LOCKED): failure -3 disposition; critical failure (miss TN by 10+)
		# -10 disposition, and the target may spread a topic about the attempt (the "may" --
		# no tier or trigger probability specified -- is deferred; see the audit doc).
		var critical_failure: bool = (bar - seducer_total) >= CRITICAL_FAILURE_MARGIN
		return {
			"success": false,
			"roll_total": seducer_total,
			"tn": bar,
			"margin": margin,
			"honor_cost": honor_cost,
			"disposition_change": CRITICAL_FAILURE_DISPOSITION_LOSS if critical_failure else FAILURE_DISPOSITION_LOSS,
			"critical_failure": critical_failure,
		}

	var effects: Dictionary = _get_variant_effects(variant, margin)

	return {
		"success": true,
		"roll_total": seducer_total,
		"tn": bar,
		"margin": margin,
		"honor_cost": honor_cost,
		"variant": variant,
		"effects": effects,
		"creates_entanglement": true,
	}


const SEDUCE_FOR_INFO_DISPOSITION: int = 3

static func _get_variant_effects(variant: SeductionVariant, margin: int) -> Dictionary:
	match variant:
		SeductionVariant.SEDUCE:
			return {"disposition_change": SEDUCE_DISPOSITION_BONUS}
		SeductionVariant.SEDUCE_FOR_INFO:
			return {"info_gained": true, "disposition_change": SEDUCE_FOR_INFO_DISPOSITION}
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
	variant: SeductionVariant = SeductionVariant.SEDUCE,
) -> Dictionary:
	return {
		"seducer_id": seducer_id,
		"target_id": target_id,
		"state": EntanglementState.ACTIVE,
		"created_ic_day": current_ic_day,
		"last_maintained_ic_day": current_ic_day,
		"missed_windows": 0,
		"variant": variant,
	}


static func check_maintenance(
	entanglement: Dictionary,
	current_ic_day: int,
) -> Dictionary:
	# total_missed is always computed fresh from last_maintained_ic_day (which only ever
	# changes on contact, via maintain_entanglement) -- it must NOT be added on top of the
	# entanglement's stored missed_windows, or the same elapsed days get counted again on
	# every subsequent daily call, breaking the entanglement far sooner than the LOCKED
	# "three consecutive [16-day] windows" (48 IC days).
	var last: int = entanglement.get("last_maintained_ic_day", -1)
	var days_since: int = current_ic_day - last
	var total_missed: int = days_since / MAINTENANCE_WINDOW_IC_DAYS

	if total_missed <= 0:
		return {"needs_maintenance": false, "state": entanglement["state"]}

	# s12.8 line 273 (LOCKED): "the target's disposition toward the actor decays at -2 per
	# missed window" -- newly_missed_windows lets the caller apply that decay only for
	# windows that crossed since the last check, not re-apply it for windows already
	# accounted on a prior day.
	var previously_missed: int = entanglement.get("missed_windows", 0)
	var newly_missed: int = maxi(0, total_missed - previously_missed)

	return {
		"needs_maintenance": true,
		"state": EntanglementState.BROKEN if total_missed >= MISSED_WINDOWS_TO_BREAK else EntanglementState.NEGLECTED,
		"missed_windows": total_missed,
		"newly_missed_windows": newly_missed,
	}


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
	return "low"


# ==============================================================================
# Affair Secret Severity
# ==============================================================================

static func get_affair_severity(
	seducer_married: bool,
	target_married: bool,
	is_political_tension: bool,
	is_cross_clan: bool,
) -> SecretData.Severity:
	if is_cross_clan and is_political_tension:
		return AFFAIR_SEVERITY_POLITICAL
	if seducer_married or target_married:
		return AFFAIR_SEVERITY_MARRIED
	return AFFAIR_SEVERITY_UNMARRIED
