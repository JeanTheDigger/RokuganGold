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

# Non-shinobi TN increase — characters without shinobi school training
# get a flat TN increase on all Phase 1 rolls (s12.8 NON-SCORPION ASSASSINS).
# Value PROVISIONAL pending playtest — GDD specifies "severe disadvantage" and
# "significantly higher suspicion" but does not give a numeric value.
const NON_SHINOBI_ACCESS_TN_INCREASE: int = 10

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

# -- PC Safeguard Windows (real days for offline players) ----------------------

const PC_CRISIS_POISON_DAYS: int = 12
const PC_CRISIS_BLADE_DAYS: int = 4
const PC_CRISIS_ACCIDENT_DAYS: int = 8


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
	if margin <= -10:
		return SUSPICION_CRITICAL_FAILURE
	elif margin <= -5:
		return SUSPICION_NOTABLE_FAILURE
	return SUSPICION_FAILURE


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
	var seppun_mod: int = 0
	if target != null:
		seppun_mod = get_seppun_tn_modifier(target, AssassinationPhase.ACCESS, characters_by_id)

	var tn: int = 0
	var skill: String = ""
	var trait_override: Enums.Trait = Enums.Trait.NONE
	match access_method:
		"forge_credentials":
			tn = ACCESS_FORGE_CREDENTIALS_TN + susp_mod + shinobi_mod + seppun_mod
			skill = "Forgery"
			trait_override = Enums.Trait.INTELLIGENCE
		"bribe":
			tn = ACCESS_BRIBE_TN + susp_mod + shinobi_mod + seppun_mod
			skill = "Courtier"
		"stealth":
			tn = ACCESS_STEALTH_INFILTRATE_TN + susp_mod + shinobi_mod + seppun_mod
			skill = "Stealth"
		"seduction":
			tn = 15 + susp_mod + shinobi_mod + seppun_mod
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

	return {
		"success": success,
		"roll_total": result.get("total", 0),
		"tn": tn,
		"margin": margin,
		"skill": skill,
		"days_in_access": state["days_in_access"],
		"suspicion": state["suspicion"],
	}


static func can_advance_to_execution(state: Dictionary) -> bool:
	return (
		state.get("phase") == AssassinationPhase.ACCESS
		and state.get("days_in_access", 0) >= ACCESS_MIN_DAYS
		and not is_lockdown(state)
	)


static func advance_to_execution(state: Dictionary) -> void:
	state["phase"] = AssassinationPhase.EXECUTION


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
	var concealment_tn_for_investigators: int = roll_total if success else 0

	state["concealment_result"] = {
		"success": success,
		"concealed": success,
		"roll_total": roll_total,
		"tn": tn,
		"margin": result.get("margin", 0),
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


static func is_target_pc_offline(
	target_id: int,
	online_player_ids: Array[int],
) -> bool:
	return target_id not in online_player_ids
