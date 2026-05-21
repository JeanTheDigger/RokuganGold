class_name AssassinationSystem

# ==============================================================================
# Three-Phase Assassination per GDD s12.8
# Phase 1: Access (social infiltration, suspicion accumulation)
# Phase 2: Execution (poison / blade / arranged accident)
# Phase 3: Concealment (prevent murder discovery)
# ==============================================================================

enum AssassinationPhase {
	ACCESS,
	EXECUTION,
	CONCEALMENT,
	COMPLETE,
	FAILED,
	ABORTED,
}

enum ExecutionMethod {
	POISON,
	BLADE,
	ARRANGED_ACCIDENT,
}

enum BodyguardResponse {
	FIGHT_FIRST,
	GO_FOR_TARGET,
	ABORT,
}

# -- Suspicion Constants -------------------------------------------------------

const SUSPICION_FAILURE: int = 5
const SUSPICION_NOTABLE_FAILURE: int = 10
const SUSPICION_CRITICAL_FAILURE: int = 15
const SUSPICION_DECAY_ABSENT: float = -1.0
const SUSPICION_DECAY_PRESENT_INACTIVE: float = -0.5
const SUSPICION_MINIMUM_RESTORE_TICKS: int = 14

# Household response thresholds (s12.8):
# 0-9: no response. 10-19: watchful (+5 passive Investigation).
# 20-29: bodyguard assigned. 30+: target warned, +10 all Phase 1 TNs.
# Daily passive detection suspicion (PROVISIONAL — GDD specifies household
# members detect activity each day but does not give a suspicion increment).
const SUSPICION_DAILY_DETECTION: int = 3

const SUSPICION_WATCHFUL_THRESHOLD: float = 10.0
const SUSPICION_BODYGUARD_THRESHOLD: float = 20.0
const SUSPICION_LOCKDOWN_THRESHOLD: float = 30.0
const SUSPICION_LOCKDOWN_TN_INCREASE: int = 10
const SUSPICION_WATCHFUL_INVESTIGATION_BONUS: int = 5

# -- Access Phase Constants ----------------------------------------------------

const ACCESS_MIN_DAYS: int = 3
const ACCESS_FORGE_CREDENTIALS_TN: int = 20
const ACCESS_BRIBE_TN: int = 15
const ACCESS_STEALTH_INFILTRATE_TN: int = 20
const ACCESS_SEDUCTION_TN: int = 15

# Non-shinobi TN increase — characters without shinobi school training
# get a flat TN increase on all Phase 1 rolls (s12.8 NON-SCORPION ASSASSINS).
# Value PROVISIONAL pending playtest — GDD specifies "severe disadvantage" and
# "significantly higher suspicion" but does not give a numeric value.
const NON_SHINOBI_ACCESS_TN_INCREASE: int = 10

# Non-shinobi detection ease — observers get a bonus when detecting non-shinobi
# assassins (GDD: "chance of generating detectable suspicion each day is
# significantly higher"). Reduces the detection TN for observers. PROVISIONAL.
const NON_SHINOBI_DETECTION_BONUS: int = 5

const _SHINOBI_SCHOOLS: Array[String] = [
	"Shosuro Infiltrator",
	"Shosuro Actor",
]

# -- Seppun Protection Constants (s12.8 Imperial Assassination) ----------------
# Full protection: target under direct Seppun guard (co-located Seppun present).
# Half protection: Imperial dynasty target without co-located Seppun guard.

const SEPPUN_FULL_PHASE1_TN: int = 15
const SEPPUN_FULL_PHASE2_TN: int = 20
const SEPPUN_FULL_PHASE3_TN: int = 10

const SEPPUN_HALF_PHASE1_TN: int = 8
const SEPPUN_HALF_PHASE2_TN: int = 10
const SEPPUN_HALF_PHASE3_TN: int = 5

# -- Equipment Preparation Constants (pre-Phase 1) ----------------------------
# Assassin must CONCEAL_ITEM tools before entering target's settlement.
# s12.8: Sleight of Hand (Conceal) / Agility vs TN by item size.

const EQUIPMENT_POISON_TN: int = 10
const EQUIPMENT_BLADE_TN: int = 20
const EQUIPMENT_BLADE_RANK_REQUIREMENT: int = 5

# -- Per-Roll Permanent TN Penalty (s12.8) ------------------------------------
# Each failed access roll permanently increases subsequent Phase 1 TNs.
# Cannot be reduced except by aborting and restarting Phase 1 from scratch.
# Stacks with lockdown +10 and all other TN modifiers.
# Values PROVISIONAL — GDD specifies the mechanic exists but does not give
# numeric penalty amounts. Using suspicion scale pending playtest.
const ACCESS_PENALTY_STANDARD: int = 5
const ACCESS_PENALTY_NOTABLE: int = 10
const ACCESS_PENALTY_CRITICAL: int = 15

const _CONCEAL_SCHOOL_LEAN: Array[String] = [
	"Shosuro Infiltrator",
	"Kasuga Smuggler",
]

# -- Execution Phase Constants -------------------------------------------------

const POISON_STEALTH_TN: int = 15
const POISON_SLEIGHT_TN: int = 20
const BLADE_STEALTH_TN: int = 20
const BLADE_ATTACK_BONUS: int = 10
const ACCIDENT_ENGINEERING_TN: int = 25
const ACCIDENT_STEALTH_TN: int = 15

# -- Concealment Phase Constants -----------------------------------------------

const CONCEAL_POISON_TN: int = 15
const CONCEAL_BLADE_TN: int = 25
const CONCEAL_ACCIDENT_TN: int = 20

# Concealment outcome thresholds — PROVISIONAL.
# Full: beat TN. Partial: missed by < 10 (suspicious but no evidence).
# Failure: missed by 10+.
const CONCEALMENT_PARTIAL_THRESHOLD: int = -10

# -- PC Safeguard Windows (real days for offline players) ----------------------

const PC_CRISIS_POISON_DAYS: int = 12
const PC_CRISIS_BLADE_DAYS: int = 4
const PC_CRISIS_ACCIDENT_DAYS: int = 8

# -- Honor/Infamy Consequences (s12.8) ----------------------------------------
# Ordering: scaled by target Status. Always private initially.
const ORDER_HONOR_LOSS_STATUS_LOW: float = -2.0
const ORDER_HONOR_LOSS_STATUS_MID: float = -3.0
const ORDER_HONOR_LOSS_STATUS_HIGH: float = -4.0
const ORDER_HONOR_LOSS_STATUS_ELITE: float = -5.0

# Executing: PROVISIONAL — GDD specifies "Scorpion pay almost nothing,
# other clans pay steeply" without numeric values.
const EXECUTE_HONOR_LOSS_SCORPION: float = -0.5
const EXECUTE_HONOR_LOSS_DEFAULT: float = -3.0


# ==============================================================================
# Honor / Infamy Consequences
# ==============================================================================

static func get_ordering_honor_loss(target_status: float) -> float:
	if target_status >= 8.0:
		return ORDER_HONOR_LOSS_STATUS_ELITE
	if target_status >= 6.0:
		return ORDER_HONOR_LOSS_STATUS_HIGH
	if target_status >= 3.0:
		return ORDER_HONOR_LOSS_STATUS_MID
	return ORDER_HONOR_LOSS_STATUS_LOW


static func get_execution_honor_loss(assassin: L5RCharacterData) -> float:
	if assassin.clan == "Scorpion":
		return EXECUTE_HONOR_LOSS_SCORPION
	return EXECUTE_HONOR_LOSS_DEFAULT


# ==============================================================================
# State Factory
# ==============================================================================

static func create_assassination_state(
	assassin_id: int,
	target_id: int,
	method: ExecutionMethod,
	current_ic_day: int,
) -> Dictionary:
	return {
		"assassin_id": assassin_id,
		"target_id": target_id,
		"method": method,
		"phase": AssassinationPhase.ACCESS,
		"suspicion": 0.0,
		"suspicion_raised_ic_day": -1,
		"days_in_access": 0,
		"start_ic_day": current_ic_day,
		"bodyguard_encountered": false,
		"access_tn_penalty": 0,
		"equipment_prepared": false,
		"equipment_concealment_tn": 0,
		"execution_result": {},
		"concealment_result": {},
	}


# ==============================================================================
# Suspicion Management
# ==============================================================================

static func add_suspicion(state: Dictionary, amount: int) -> void:
	state["suspicion"] = clampf(float(state.get("suspicion", 0)) + float(amount), 0.0, 100.0)


static func get_suspicion_from_failure(margin: int) -> int:
	if margin <= -20:
		return SUSPICION_CRITICAL_FAILURE
	if margin <= -10:
		return SUSPICION_NOTABLE_FAILURE
	return SUSPICION_FAILURE


static func get_access_penalty_from_failure(margin: int) -> int:
	if margin <= -20:
		return ACCESS_PENALTY_CRITICAL
	if margin <= -10:
		return ACCESS_PENALTY_NOTABLE
	return ACCESS_PENALTY_STANDARD


static func is_critical_failure(margin: int) -> bool:
	return margin <= -20


static func resolve_critical_failure_detection(
	searcher: L5RCharacterData,
	assassin_roll_total: int,
	state: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	var inv_bonus: int = get_household_investigation_bonus(state)
	var result: Dictionary = SkillResolver.resolve_skill_check(
		searcher, dice_engine, "Investigation", assassin_roll_total,
		0, "", Enums.Trait.PERCEPTION, inv_bonus,
	)
	return {
		"detected": result.get("success", false),
		"searcher_id": searcher.character_id,
		"roll_total": result.get("total", 0),
		"detection_tn": assassin_roll_total,
	}


static func decay_suspicion(state: Dictionary, is_present: bool, ic_day: int = -1) -> void:
	var susp: float = float(state.get("suspicion", 0))
	if susp <= 0.0:
		return
	var decay: float = SUSPICION_DECAY_PRESENT_INACTIVE if is_present else SUSPICION_DECAY_ABSENT
	var new_susp: float = clampf(susp + decay, 0.0, 100.0)
	if new_susp <= 0.0:
		var raised_day: int = int(state.get("suspicion_raised_ic_day", -1))
		if raised_day >= 0 and ic_day >= 0 and (ic_day - raised_day) < SUSPICION_MINIMUM_RESTORE_TICKS:
			new_susp = 0.5
	state["suspicion"] = new_susp
	if new_susp <= 0.0:
		state["suspicion_raised_ic_day"] = -1


static func is_watchful(state: Dictionary) -> bool:
	return float(state.get("suspicion", 0)) >= SUSPICION_WATCHFUL_THRESHOLD


static func is_alert(state: Dictionary) -> bool:
	return float(state.get("suspicion", 0)) >= SUSPICION_BODYGUARD_THRESHOLD


static func is_lockdown(state: Dictionary) -> bool:
	return float(state.get("suspicion", 0)) >= SUSPICION_LOCKDOWN_THRESHOLD


static func should_assign_bodyguard(state: Dictionary) -> bool:
	return float(state.get("suspicion", 0)) >= SUSPICION_BODYGUARD_THRESHOLD


static func get_household_investigation_bonus(state: Dictionary) -> int:
	var susp: float = float(state.get("suspicion", 0))
	if susp >= SUSPICION_WATCHFUL_THRESHOLD and susp < SUSPICION_BODYGUARD_THRESHOLD:
		return SUSPICION_WATCHFUL_INVESTIGATION_BONUS
	return 0


static func get_suspicion_tn_modifier(state: Dictionary) -> int:
	var susp: float = float(state.get("suspicion", 0))
	if susp >= SUSPICION_LOCKDOWN_THRESHOLD:
		return SUSPICION_LOCKDOWN_TN_INCREASE
	return 0


static func _is_household_member(
	candidate: L5RCharacterData,
	target: L5RCharacterData,
) -> bool:
	if candidate.lord_id == target.character_id:
		return true
	if target.lord_id >= 0 and candidate.lord_id == target.lord_id:
		return true
	if candidate.assigned_protection_target_id == target.character_id:
		return true
	return false


const LOYALTY_DISPOSITION_MINIMUM: int = 0


static func find_best_searcher(
	target: L5RCharacterData,
	assassin_id: int,
	characters_by_id: Dictionary,
	require_loyalty: bool = false,
) -> L5RCharacterData:
	var best: L5RCharacterData = null
	var best_score: int = -1
	for char_id: int in characters_by_id:
		if char_id == assassin_id or char_id == target.character_id:
			continue
		var c: L5RCharacterData = characters_by_id[char_id]
		if c.physical_location != target.physical_location:
			continue
		if c.physical_location == "":
			continue
		if require_loyalty:
			if not _is_household_member(c, target):
				continue
			var disp: int = int(c.disposition_values.get(target.character_id, 0))
			if disp < LOYALTY_DISPOSITION_MINIMUM:
				continue
		var score: int = c.skills.get("Investigation", 0) + c.perception
		if score > best_score:
			best_score = score
			best = c
	return best


static func has_seduce_for_access(
	assassin_id: int,
	target_location: String,
	entanglements: Array,
	characters_by_id: Dictionary,
) -> bool:
	if target_location == "":
		return false
	for ent: Dictionary in entanglements:
		if int(ent.get("seducer_id", -1)) != assassin_id:
			continue
		if int(ent.get("variant", -1)) != SeductionSystem.SeductionVariant.SEDUCE_FOR_ACCESS:
			continue
		if int(ent.get("state", -1)) != SeductionSystem.EntanglementState.ACTIVE:
			continue
		var seduced_id: int = int(ent.get("target_id", -1))
		var seduced: L5RCharacterData = characters_by_id.get(seduced_id) as L5RCharacterData
		if seduced != null and seduced.physical_location == target_location:
			return true
	return false


static func resolve_suspicion_search(
	searcher: L5RCharacterData,
	state: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	var concealment_tn: int = int(state.get("equipment_concealment_tn", 0))
	if concealment_tn <= 0:
		return {"searched": true, "found": true, "concealment_tn": 0}

	var inv_bonus: int = get_household_investigation_bonus(state)
	var result: Dictionary = SkillResolver.resolve_skill_check(
		searcher, dice_engine, "Investigation", concealment_tn,
		0, "", Enums.Trait.PERCEPTION, inv_bonus,
	)
	return {
		"searched": true,
		"found": result.get("success", false),
		"searcher_id": searcher.character_id,
		"roll_total": result.get("total", 0),
		"concealment_tn": concealment_tn,
	}


static func resolve_daily_detection(
	observer: L5RCharacterData,
	assassin_roll_total: int,
	state: Dictionary,
	dice_engine: DiceEngine,
	assassin: L5RCharacterData = null,
) -> Dictionary:
	var inv_bonus: int = get_household_investigation_bonus(state)
	if assassin != null and not has_shinobi_training(assassin):
		inv_bonus += NON_SHINOBI_DETECTION_BONUS
	var result: Dictionary = SkillResolver.resolve_skill_check(
		observer, dice_engine, "Investigation", assassin_roll_total,
		0, "", Enums.Trait.PERCEPTION, inv_bonus,
	)
	var noticed: bool = result.get("success", false)
	if noticed:
		add_suspicion(state, SUSPICION_DAILY_DETECTION)
	return {
		"noticed": noticed,
		"observer_id": observer.character_id,
		"roll_total": result.get("total", 0),
		"detection_tn": assassin_roll_total,
	}


static func has_shinobi_training(character: L5RCharacterData) -> bool:
	for s: String in _SHINOBI_SCHOOLS:
		if character.school.begins_with(s):
			return true
	for path: String in character.school_paths:
		for s: String in _SHINOBI_SCHOOLS:
			if path.begins_with(s):
				return true
	return false


static func get_non_shinobi_tn_modifier(character: L5RCharacterData) -> int:
	if has_shinobi_training(character):
		return 0
	return NON_SHINOBI_ACCESS_TN_INCREASE


# PROVISIONAL — GDD s12.8 specifies "target's Status (higher Status = higher
# base TN)" without giving a formula. Using int(status) as a direct TN adder.
static func get_target_status_tn_modifier(target: L5RCharacterData) -> int:
	return int(target.status)


static func is_imperial_dynasty(character: L5RCharacterData) -> bool:
	return character.clan == "Imperial"


static func has_seppun_guard_present(
	target: L5RCharacterData,
	characters_by_id: Dictionary,
) -> bool:
	if target.physical_location == "":
		return false
	for char_id: int in characters_by_id:
		var c: L5RCharacterData = characters_by_id[char_id]
		if c.character_id == target.character_id:
			continue
		if c.family == "Seppun" and c.physical_location == target.physical_location:
			return true
	return false


static func get_seppun_tn_modifier(target: L5RCharacterData, phase: AssassinationPhase, characters_by_id: Dictionary) -> int:
	if not is_imperial_dynasty(target):
		return 0
	var guarded: bool = has_seppun_guard_present(target, characters_by_id)
	match phase:
		AssassinationPhase.ACCESS:
			return SEPPUN_FULL_PHASE1_TN if guarded else SEPPUN_HALF_PHASE1_TN
		AssassinationPhase.EXECUTION:
			return SEPPUN_FULL_PHASE2_TN if guarded else SEPPUN_HALF_PHASE2_TN
		AssassinationPhase.CONCEALMENT:
			return SEPPUN_FULL_PHASE3_TN if guarded else SEPPUN_HALF_PHASE3_TN
		_:
			return 0


# ==============================================================================
# Equipment Preparation (pre-Phase 1)
# ==============================================================================

static func can_use_blade_method(assassin: L5RCharacterData) -> bool:
	return assassin.skills.get("Sleight of Hand", 0) >= EQUIPMENT_BLADE_RANK_REQUIREMENT


static func get_equipment_tn(method: ExecutionMethod) -> int:
	match method:
		ExecutionMethod.POISON:
			return EQUIPMENT_POISON_TN
		ExecutionMethod.BLADE:
			return EQUIPMENT_BLADE_TN
		ExecutionMethod.ARRANGED_ACCIDENT:
			return -1
		_:
			return -1


static func _has_conceal_school_lean(assassin: L5RCharacterData) -> bool:
	for s: String in _CONCEAL_SCHOOL_LEAN:
		if assassin.school.begins_with(s):
			return true
	if assassin.kolat_sect != Enums.KolatSect.NONE:
		return true
	return false


static func resolve_equipment_preparation(
	assassin: L5RCharacterData,
	state: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	var method: ExecutionMethod = state.get("method", ExecutionMethod.POISON)

	if method == ExecutionMethod.ARRANGED_ACCIDENT:
		state["equipment_prepared"] = true
		return {"success": true, "method": method, "skipped": true}

	if method == ExecutionMethod.BLADE and not can_use_blade_method(assassin):
		return {
			"success": false,
			"method": method,
			"reason": "rank_gate",
			"required_rank": EQUIPMENT_BLADE_RANK_REQUIREMENT,
		}

	var tn: int = get_equipment_tn(method)
	var bonus_kept: int = 1 if _has_conceal_school_lean(assassin) else 0

	var result: Dictionary = SkillResolver.resolve_skill_check(
		assassin, dice_engine, "Sleight of Hand", tn,
		0, "Conceal", Enums.Trait.NONE, 0, bonus_kept,
	)
	var success: bool = result.get("success", false)

	if success:
		state["equipment_prepared"] = true
		state["equipment_concealment_tn"] = result.get("total", 0)

	return {
		"success": success,
		"method": method,
		"roll_total": result.get("total", 0),
		"tn": tn,
		"margin": result.get("margin", 0),
		"equipment_concealment_tn": state["equipment_concealment_tn"],
	}


# ==============================================================================
# Phase 1 — Access
# ==============================================================================

static func resolve_access_day(
	assassin: L5RCharacterData,
	state: Dictionary,
	access_method: String,
	dice_engine: DiceEngine,
	target: L5RCharacterData = null,
	characters_by_id: Dictionary = {},
) -> Dictionary:
	state["days_in_access"] = state.get("days_in_access", 0) + 1
	var susp_mod: int = get_suspicion_tn_modifier(state)
	var shinobi_mod: int = get_non_shinobi_tn_modifier(assassin)
	var penalty: int = int(state.get("access_tn_penalty", 0))
	var seppun_mod: int = 0
	var status_mod: int = 0
	if target != null:
		seppun_mod = get_seppun_tn_modifier(target, AssassinationPhase.ACCESS, characters_by_id)
		status_mod = get_target_status_tn_modifier(target)

	var extra: int = susp_mod + shinobi_mod + seppun_mod + status_mod + penalty
	var tn: int = 0
	var skill: String = ""
	var trait_override: Enums.Trait = Enums.Trait.NONE
	match access_method:
		"forge_credentials":
			tn = ACCESS_FORGE_CREDENTIALS_TN + extra
			skill = "Forgery"
			trait_override = Enums.Trait.INTELLIGENCE
		"bribe":
			tn = ACCESS_BRIBE_TN + extra
			skill = "Courtier"
		"stealth":
			tn = ACCESS_STEALTH_INFILTRATE_TN + extra
			skill = "Stealth"
		"seduction":
			tn = ACCESS_SEDUCTION_TN + extra
			skill = "Temptation"
		_:
			return {"success": false, "reason": "invalid_method"}

	var result: Dictionary = SkillResolver.resolve_skill_check(
		assassin, dice_engine, skill, tn, 0, "", trait_override,
	)
	var success: bool = result.get("success", false)
	var margin: int = result.get("margin", 0)

	if not success:
		add_suspicion(state, get_suspicion_from_failure(margin))
		state["access_tn_penalty"] = penalty + get_access_penalty_from_failure(margin)

	return {
		"success": success,
		"roll_total": result.get("total", 0),
		"tn": tn,
		"margin": margin,
		"skill": skill,
		"days_in_access": state["days_in_access"],
		"suspicion": state["suspicion"],
		"access_tn_penalty": state["access_tn_penalty"],
	}


static func can_advance_to_execution(state: Dictionary) -> bool:
	return (
		state.get("phase") == AssassinationPhase.ACCESS
		and state.get("days_in_access", 0) >= ACCESS_MIN_DAYS
		and not is_lockdown(state)
	)


static func advance_to_execution(state: Dictionary) -> void:
	state["phase"] = AssassinationPhase.EXECUTION


static func abort_operation(state: Dictionary) -> void:
	state["phase"] = AssassinationPhase.ABORTED


static func restart_access(state: Dictionary) -> void:
	state["phase"] = AssassinationPhase.ACCESS
	state["days_in_access"] = 0
	state["access_tn_penalty"] = 0
	state["equipment_prepared"] = false
	state["equipment_concealment_tn"] = 0
	state["bodyguard_encountered"] = false


# ==============================================================================
# Phase 2 — Execution
# ==============================================================================

static func resolve_execution(
	assassin: L5RCharacterData,
	target: L5RCharacterData,
	state: Dictionary,
	dice_engine: DiceEngine,
	has_bodyguard: bool = false,
	characters_by_id: Dictionary = {},
) -> Dictionary:
	var method: ExecutionMethod = state.get("method", ExecutionMethod.POISON)
	var susp_mod: int = get_suspicion_tn_modifier(state)
	var seppun_mod: int = get_seppun_tn_modifier(target, AssassinationPhase.EXECUTION, characters_by_id)

	if has_bodyguard:
		state["bodyguard_encountered"] = true
		return {
			"success": false,
			"bodyguard_encountered": true,
			"requires_response": true,
			"method": method,
		}

	var result: Dictionary = {}

	match method:
		ExecutionMethod.POISON:
			result = _execute_poison(assassin, state, susp_mod + seppun_mod, dice_engine)
		ExecutionMethod.BLADE:
			result = _execute_blade(assassin, target, state, susp_mod + seppun_mod, dice_engine)
		ExecutionMethod.ARRANGED_ACCIDENT:
			result = _execute_accident(assassin, state, susp_mod + seppun_mod, dice_engine)

	state["execution_result"] = result

	if result.get("success", false):
		var honor_cost: float = get_execution_honor_loss(assassin)
		assassin.honor += honor_cost
		result["honor_cost"] = honor_cost
		state["phase"] = AssassinationPhase.CONCEALMENT
	else:
		add_suspicion(state, get_suspicion_from_failure(result.get("margin", -5)))
		state["phase"] = AssassinationPhase.FAILED

	return result


static func _execute_poison(
	assassin: L5RCharacterData,
	state: Dictionary,
	susp_mod: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var stealth_tn: int = POISON_STEALTH_TN + susp_mod
	var stealth_check: Dictionary = SkillResolver.resolve_skill_check(
		assassin, dice_engine, "Stealth", stealth_tn,
	)
	if not stealth_check.get("success", false):
		return {
			"success": false,
			"phase_failed": "stealth",
			"roll_total": stealth_check.get("total", 0),
			"tn": stealth_tn,
			"margin": stealth_check.get("margin", 0),
			"method": ExecutionMethod.POISON,
		}

	var soh_tn: int = POISON_SLEIGHT_TN + susp_mod
	var soh_check: Dictionary = SkillResolver.resolve_skill_check(
		assassin, dice_engine, "Sleight of Hand", soh_tn,
	)
	var success: bool = soh_check.get("success", false)

	return {
		"success": success,
		"phase_failed": "" if success else "sleight_of_hand",
		"stealth_total": stealth_check.get("total", 0),
		"sleight_total": soh_check.get("total", 0),
		"tn": soh_tn,
		"margin": soh_check.get("margin", 0),
		"method": ExecutionMethod.POISON,
	}


static func _execute_blade(
	assassin: L5RCharacterData,
	target: L5RCharacterData,
	state: Dictionary,
	susp_mod: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var stealth_tn: int = BLADE_STEALTH_TN + susp_mod
	var stealth_check: Dictionary = SkillResolver.resolve_skill_check(
		assassin, dice_engine, "Stealth", stealth_tn,
	)
	if not stealth_check.get("success", false):
		return {
			"success": false,
			"phase_failed": "stealth",
			"roll_total": stealth_check.get("total", 0),
			"tn": stealth_tn,
			"margin": stealth_check.get("margin", 0),
			"method": ExecutionMethod.BLADE,
		}

	var attack_skill: String = "Kenjutsu"
	if assassin.skills.get("Ninjutsu", 0) > assassin.skills.get("Kenjutsu", 0):
		attack_skill = "Ninjutsu"
	var target_tn: int = (target.reflexes * 5 + 5) + target.armor_tn_bonus
	var attack_check: Dictionary = SkillResolver.resolve_skill_check(
		assassin, dice_engine, attack_skill, target_tn, 0, "",
		Enums.Trait.NONE, 0, 0, BLADE_ATTACK_BONUS,
	)
	var success: bool = attack_check.get("success", false)

	return {
		"success": success,
		"phase_failed": "" if success else "attack",
		"stealth_total": stealth_check.get("total", 0),
		"attack_total": attack_check.get("total", 0),
		"target_tn": target_tn,
		"margin": attack_check.get("margin", 0),
		"method": ExecutionMethod.BLADE,
	}


static func _execute_accident(
	assassin: L5RCharacterData,
	state: Dictionary,
	susp_mod: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var eng_tn: int = ACCIDENT_ENGINEERING_TN + susp_mod
	var eng_check: Dictionary = SkillResolver.resolve_skill_check(
		assassin, dice_engine, "Engineering", eng_tn,
		0, "", Enums.Trait.INTELLIGENCE,
	)
	if not eng_check.get("success", false):
		return {
			"success": false,
			"phase_failed": "engineering",
			"roll_total": eng_check.get("total", 0),
			"tn": eng_tn,
			"margin": eng_check.get("margin", 0),
			"method": ExecutionMethod.ARRANGED_ACCIDENT,
		}

	var stealth_tn: int = ACCIDENT_STEALTH_TN + susp_mod
	var stealth_check: Dictionary = SkillResolver.resolve_skill_check(
		assassin, dice_engine, "Stealth", stealth_tn,
	)
	var success: bool = stealth_check.get("success", false)

	return {
		"success": success,
		"phase_failed": "" if success else "stealth",
		"engineering_total": eng_check.get("total", 0),
		"stealth_total": stealth_check.get("total", 0),
		"tn": stealth_tn,
		"margin": stealth_check.get("margin", 0),
		"method": ExecutionMethod.ARRANGED_ACCIDENT,
	}


# ==============================================================================
# Phase 3 — Concealment
# ==============================================================================

static func get_concealment_tn(method: ExecutionMethod) -> int:
	match method:
		ExecutionMethod.POISON:
			return CONCEAL_POISON_TN
		ExecutionMethod.BLADE:
			return CONCEAL_BLADE_TN
		ExecutionMethod.ARRANGED_ACCIDENT:
			return CONCEAL_ACCIDENT_TN
		_:
			return CONCEAL_BLADE_TN


static func resolve_concealment(
	assassin: L5RCharacterData,
	state: Dictionary,
	dice_engine: DiceEngine,
	target: L5RCharacterData = null,
	characters_by_id: Dictionary = {},
) -> Dictionary:
	var method: ExecutionMethod = state.get("method", ExecutionMethod.POISON)
	var tn: int = get_concealment_tn(method)
	if target != null:
		tn += get_seppun_tn_modifier(target, AssassinationPhase.CONCEALMENT, characters_by_id)

	var skill: String = ""
	var trait_override: Enums.Trait = Enums.Trait.NONE
	match method:
		ExecutionMethod.POISON:
			skill = "Medicine"
			trait_override = Enums.Trait.INTELLIGENCE
		ExecutionMethod.BLADE:
			skill = "Stealth"
		ExecutionMethod.ARRANGED_ACCIDENT:
			skill = "Engineering"
			trait_override = Enums.Trait.INTELLIGENCE

	var result: Dictionary = SkillResolver.resolve_skill_check(
		assassin, dice_engine, skill, tn, 0, "", trait_override,
	)
	var success: bool = result.get("success", false)
	var roll_total: int = result.get("total", 0)
	var margin: int = result.get("margin", 0)

	var outcome: String = "full"
	if not success:
		outcome = "partial" if margin >= CONCEALMENT_PARTIAL_THRESHOLD else "failure"

	var concealment_tn_for_investigators: int = roll_total if outcome != "failure" else 0

	state["concealment_result"] = {
		"success": success,
		"concealed": outcome == "full",
		"outcome": outcome,
		"roll_total": roll_total,
		"tn": tn,
		"margin": margin,
		"skill": skill,
		"concealment_tn": concealment_tn_for_investigators,
		"method": method,
	}

	state["phase"] = AssassinationPhase.COMPLETE

	return state["concealment_result"]


# ==============================================================================
# Bodyguard Response Resolution
# ==============================================================================

static func resolve_bodyguard_encounter(
	assassin: L5RCharacterData,
	bodyguard: L5RCharacterData,
	response: BodyguardResponse,
	state: Dictionary,
	dice_engine: DiceEngine,
) -> Dictionary:
	match response:
		BodyguardResponse.ABORT:
			state["phase"] = AssassinationPhase.ABORTED
			add_suspicion(state, SUSPICION_FAILURE)
			return {"aborted": true, "suspicion": state["suspicion"]}

		BodyguardResponse.FIGHT_FIRST:
			var assassin_init: DiceResult = dice_engine.roll_and_keep(
				assassin.reflexes + 1, assassin.reflexes
			)
			var guard_init: DiceResult = dice_engine.roll_and_keep(
				bodyguard.reflexes + 1, bodyguard.reflexes
			)
			var assassin_first: bool = assassin_init.total >= guard_init.total
			add_suspicion(state, SUSPICION_NOTABLE_FAILURE)
			return {
				"fight_initiated": true,
				"assassin_first": assassin_first,
				"assassin_initiative": assassin_init.total,
				"guard_initiative": guard_init.total,
				"suspicion": state["suspicion"],
			}

		BodyguardResponse.GO_FOR_TARGET:
			var contested: Dictionary = SkillResolver.resolve_contested_check(
				assassin, bodyguard, dice_engine,
				"Stealth", "Investigation",
			)
			var evaded: bool = contested.get("winner") == "a"
			if not evaded:
				add_suspicion(state, SUSPICION_CRITICAL_FAILURE)
			return {
				"evaded_guard": evaded,
				"assassin_stealth": contested.get("total_a", 0),
				"guard_detection": contested.get("total_b", 0),
				"suspicion": state["suspicion"],
			}

		_:
			return {"error": "invalid_response"}


static func evaluate_bodyguard_response(
	assassin: L5RCharacterData,
	state: Dictionary,
) -> BodyguardResponse:
	if assassin.shourido_virtue == Enums.ShouridoVirtue.SEIGYO:
		return BodyguardResponse.ABORT
	if is_lockdown(state):
		return BodyguardResponse.ABORT
	if assassin.shourido_virtue == Enums.ShouridoVirtue.KETSUI:
		return BodyguardResponse.GO_FOR_TARGET
	if assassin.bushido_virtue == Enums.BushidoVirtue.YU:
		return BodyguardResponse.GO_FOR_TARGET
	var stealth: int = assassin.skills.get("Stealth", 0)
	var combat: int = maxi(
		assassin.skills.get("Kenjutsu", 0),
		assassin.skills.get("Ninjutsu", 0),
	)
	if stealth >= 5 and combat < 3:
		return BodyguardResponse.GO_FOR_TARGET
	if combat >= 4:
		return BodyguardResponse.FIGHT_FIRST
	return BodyguardResponse.ABORT


# ==============================================================================
# PC Safeguard — Crisis Window
# ==============================================================================

static func get_pc_crisis_window(method: ExecutionMethod) -> int:
	match method:
		ExecutionMethod.POISON:
			return PC_CRISIS_POISON_DAYS
		ExecutionMethod.BLADE:
			return PC_CRISIS_BLADE_DAYS
		ExecutionMethod.ARRANGED_ACCIDENT:
			return PC_CRISIS_ACCIDENT_DAYS
		_:
			return PC_CRISIS_BLADE_DAYS


static func pick_best_access_method(assassin: L5RCharacterData) -> String:
	var scores: Dictionary = {
		"stealth": assassin.skills.get("Stealth", 0) + assassin.agility,
		"forge_credentials": assassin.skills.get("Forgery", 0) + assassin.intelligence,
		"bribe": assassin.skills.get("Courtier", 0) + assassin.awareness,
		"seduction": assassin.skills.get("Temptation", 0) + assassin.awareness,
	}
	var best: String = "stealth"
	var best_val: int = 0
	for method: String in scores:
		if int(scores[method]) > best_val:
			best_val = int(scores[method])
			best = method
	return best


static func create_pc_crisis_event(
	target_id: int,
	assassin_id: int,
	method: ExecutionMethod,
	ic_day: int,
) -> Dictionary:
	return {
		"event_type": "assassination_crisis",
		"target_id": target_id,
		"assassin_id": assassin_id,
		"method": method,
		"ic_day_created": ic_day,
		"grace_period_days": get_pc_crisis_window(method),
		"deadline_ic_day": ic_day + get_pc_crisis_window(method) * 4,
		"resolved": false,
	}


static func is_target_pc_offline(
	target_id: int,
	online_player_ids: Array,
) -> bool:
	return target_id not in online_player_ids


# ==============================================================================
# Vengeance Consequences (s12.8 — fires when commissioner is traced)
# ==============================================================================

const FAMILY_VENGEANCE_DISPOSITION: int = -50

static func apply_vengeance_consequences(
	commissioner_id: int,
	victim: L5RCharacterData,
	victim_is_dead: bool,
	characters_by_id: Dictionary,
	objectives_map: Dictionary,
	active_topics: Array = [],
	next_topic_id: Array = [],
	ic_day: int = -1,
) -> Dictionary:
	var family_ids: Array = _get_biological_family(victim)
	for fam_id: int in family_ids:
		var fam: L5RCharacterData = characters_by_id.get(fam_id) as L5RCharacterData
		if fam == null:
			continue
		if CharacterStats.is_dead(fam):
			continue
		var key: String = "killed_family_%d" % victim.character_id
		fam.historical_modifiers[key] = {
			"target_id": commissioner_id,
			"modifier": FAMILY_VENGEANCE_DISPOSITION,
			"created_ic_day": ic_day,
			"permanent": true,
		}

	var avenger_id: int = -1
	if victim_is_dead:
		avenger_id = victim.designated_heir_id
		if avenger_id < 0:
			avenger_id = _find_eldest_child(victim, characters_by_id)
	else:
		avenger_id = victim.character_id

	if avenger_id >= 0 and objectives_map.has(avenger_id):
		objectives_map[avenger_id]["primary"] = "AVENGE_DEATH"
		objectives_map[avenger_id]["avenge_target_id"] = commissioner_id
		objectives_map[avenger_id]["avenge_victim_id"] = victim.character_id
		objectives_map[avenger_id]["crisis_override"] = true

	var betrayal_topic_id: int = -1
	if next_topic_id.size() > 0:
		var topic: TopicData = TopicData.new()
		topic.topic_id = next_topic_id[0]
		next_topic_id[0] += 1
		topic.topic_type = "betrayal"
		topic.tier = TopicData.Tier.TIER_2
		topic.category = TopicData.Category.POLITICAL
		topic.subject_character_id = commissioner_id
		topic.subject_role = "NEUTRAL"
		topic.ic_day_created = ic_day
		active_topics.append(topic)
		betrayal_topic_id = topic.topic_id

	return {
		"commissioner_id": commissioner_id,
		"victim_id": victim.character_id,
		"family_affected": family_ids.size(),
		"avenger_id": avenger_id,
		"disposition_modifier": FAMILY_VENGEANCE_DISPOSITION,
		"betrayal_topic_id": betrayal_topic_id,
	}


static func _get_biological_family(character: L5RCharacterData) -> Array:
	var ids: Array = []
	if character.mother_id >= 0:
		ids.append(character.mother_id)
	if character.father_id >= 0:
		ids.append(character.father_id)
	for sib: int in character.sibling_ids:
		ids.append(sib)
	for child: int in character.children_ids:
		ids.append(child)
	if character.spouse_id >= 0:
		ids.append(character.spouse_id)
	return ids


static func _find_eldest_child(
	victim: L5RCharacterData,
	characters_by_id: Dictionary,
) -> int:
	var eldest_id: int = -1
	var eldest_age: int = -1
	for child_id: int in victim.children_ids:
		var child: L5RCharacterData = characters_by_id.get(child_id) as L5RCharacterData
		if child == null or CharacterStats.is_dead(child):
			continue
		if child.age > eldest_age:
			eldest_age = child.age
			eldest_id = child_id
	return eldest_id


# ==============================================================================
# PvP Blade Edge Case (s12.8 — player assassin vs offline target)
# ==============================================================================

enum PvPBladeChoice {
	ENGINE_RESOLVE,
	WAIT,
}

static func can_pvp_blade_resolve_via_engine(state: Dictionary) -> bool:
	var method: int = int(state.get("method", ExecutionMethod.POISON))
	return (
		method == ExecutionMethod.BLADE
		and int(state.get("phase", -1)) == AssassinationPhase.EXECUTION
	)


static func pvp_blade_wait_tick(state: Dictionary, ic_day: int) -> Dictionary:
	decay_suspicion(state, true, ic_day)
	state["pvp_wait_days"] = int(state.get("pvp_wait_days", 0)) + 1
	return {
		"waiting": true,
		"pvp_wait_days": state["pvp_wait_days"],
		"suspicion": state.get("suspicion", 0.0),
	}
