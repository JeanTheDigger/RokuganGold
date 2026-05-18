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
const SUSPICION_DECAY_ABSENT: int = -1
const SUSPICION_DECAY_PRESENT: int = 0
const SUSPICION_ALERT_THRESHOLD: int = 20
const SUSPICION_LOCKDOWN_THRESHOLD: int = 40

# -- Access Phase Constants ----------------------------------------------------

const ACCESS_MIN_DAYS: int = 3
const ACCESS_FORGE_CREDENTIALS_TN: int = 20
const ACCESS_BRIBE_TN: int = 15
const ACCESS_STEALTH_INFILTRATE_TN: int = 20

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
		"suspicion": 0,
		"days_in_access": 0,
		"start_ic_day": current_ic_day,
		"bodyguard_encountered": false,
		"execution_result": {},
		"concealment_result": {},
	}


# ==============================================================================
# Suspicion Management
# ==============================================================================

static func add_suspicion(state: Dictionary, amount: int) -> void:
	state["suspicion"] = clampi(state.get("suspicion", 0) + amount, 0, 100)


static func get_suspicion_from_failure(margin: int) -> int:
	if margin <= -10:
		return SUSPICION_CRITICAL_FAILURE
	elif margin <= -5:
		return SUSPICION_NOTABLE_FAILURE
	return SUSPICION_FAILURE


static func decay_suspicion(state: Dictionary, is_present: bool) -> void:
	var decay: int = SUSPICION_DECAY_PRESENT if is_present else SUSPICION_DECAY_ABSENT
	state["suspicion"] = clampi(state.get("suspicion", 0) + decay, 0, 100)


static func is_alert(state: Dictionary) -> bool:
	return state.get("suspicion", 0) >= SUSPICION_ALERT_THRESHOLD


static func is_lockdown(state: Dictionary) -> bool:
	return state.get("suspicion", 0) >= SUSPICION_LOCKDOWN_THRESHOLD


static func get_suspicion_tn_modifier(state: Dictionary) -> int:
	var susp: int = state.get("suspicion", 0)
	if susp >= SUSPICION_LOCKDOWN_THRESHOLD:
		return 15
	if susp >= SUSPICION_ALERT_THRESHOLD:
		return 10
	if susp >= 10:
		return 5
	return 0


# ==============================================================================
# Phase 1 — Access
# ==============================================================================

static func resolve_access_day(
	assassin: L5RCharacterData,
	state: Dictionary,
	access_method: String,
	dice_engine: DiceEngine,
) -> Dictionary:
	state["days_in_access"] = state.get("days_in_access", 0) + 1
	var susp_mod: int = get_suspicion_tn_modifier(state)

	var tn: int = 0
	var skill: String = ""
	var trait_override: Enums.Trait = Enums.Trait.NONE
	match access_method:
		"forge_credentials":
			tn = ACCESS_FORGE_CREDENTIALS_TN + susp_mod
			skill = "Forgery"
			trait_override = Enums.Trait.INTELLIGENCE
		"bribe":
			tn = ACCESS_BRIBE_TN + susp_mod
			skill = "Courtier"
		"stealth":
			tn = ACCESS_STEALTH_INFILTRATE_TN + susp_mod
			skill = "Stealth"
		"seduction":
			tn = 15 + susp_mod
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
) -> Dictionary:
	var method: ExecutionMethod = state.get("method", ExecutionMethod.POISON)
	var susp_mod: int = get_suspicion_tn_modifier(state)

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
			result = _execute_poison(assassin, state, susp_mod, dice_engine)
		ExecutionMethod.BLADE:
			result = _execute_blade(assassin, target, state, susp_mod, dice_engine)
		ExecutionMethod.ARRANGED_ACCIDENT:
			result = _execute_accident(assassin, state, susp_mod, dice_engine)

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
	var stealth_rank: int = assassin.skills.get("Stealth", 0)
	var stealth_result: DiceResult = dice_engine.roll_and_keep(
		assassin.agility + stealth_rank, assassin.agility, stealth_rank > 0
	)
	var stealth_tn: int = POISON_STEALTH_TN + susp_mod
	if stealth_result.total < stealth_tn:
		return {
			"success": false,
			"phase_failed": "stealth",
			"roll_total": stealth_result.total,
			"tn": stealth_tn,
			"margin": stealth_result.total - stealth_tn,
			"method": ExecutionMethod.POISON,
		}

	var soh_rank: int = assassin.skills.get("Sleight of Hand", 0)
	var soh_result: DiceResult = dice_engine.roll_and_keep(
		assassin.agility + soh_rank, assassin.agility, soh_rank > 0
	)
	var soh_tn: int = POISON_SLEIGHT_TN + susp_mod
	var success: bool = soh_result.total >= soh_tn

	return {
		"success": success,
		"phase_failed": "" if success else "sleight_of_hand",
		"stealth_total": stealth_result.total,
		"sleight_total": soh_result.total,
		"tn": soh_tn,
		"margin": soh_result.total - soh_tn,
		"method": ExecutionMethod.POISON,
	}


static func _execute_blade(
	assassin: L5RCharacterData,
	target: L5RCharacterData,
	state: Dictionary,
	susp_mod: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var stealth_rank: int = assassin.skills.get("Stealth", 0)
	var stealth_result: DiceResult = dice_engine.roll_and_keep(
		assassin.agility + stealth_rank, assassin.agility, stealth_rank > 0
	)
	var stealth_tn: int = BLADE_STEALTH_TN + susp_mod
	if stealth_result.total < stealth_tn:
		return {
			"success": false,
			"phase_failed": "stealth",
			"roll_total": stealth_result.total,
			"tn": stealth_tn,
			"margin": stealth_result.total - stealth_tn,
			"method": ExecutionMethod.BLADE,
		}

	var kenjutsu_rank: int = assassin.skills.get("Kenjutsu", 0)
	var ninjutsu_rank: int = assassin.skills.get("Ninjutsu", 0)
	var attack_skill_rank: int = maxi(kenjutsu_rank, ninjutsu_rank)
	var attack_result: DiceResult = dice_engine.roll_and_keep(
		assassin.agility + attack_skill_rank, assassin.agility, attack_skill_rank > 0
	)
	var target_tn: int = (target.reflexes * 5 + 5) + target.armor_tn_bonus
	var success: bool = (attack_result.total + BLADE_ATTACK_BONUS) >= target_tn

	return {
		"success": success,
		"phase_failed": "" if success else "attack",
		"stealth_total": stealth_result.total,
		"attack_total": attack_result.total + BLADE_ATTACK_BONUS,
		"target_tn": target_tn,
		"margin": (attack_result.total + BLADE_ATTACK_BONUS) - target_tn,
		"method": ExecutionMethod.BLADE,
	}


static func _execute_accident(
	assassin: L5RCharacterData,
	state: Dictionary,
	susp_mod: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var eng_rank: int = assassin.skills.get("Engineering", 0)
	var eng_result: DiceResult = dice_engine.roll_and_keep(
		assassin.intelligence + eng_rank, assassin.intelligence, eng_rank > 0
	)
	var eng_tn: int = ACCIDENT_ENGINEERING_TN + susp_mod
	if eng_result.total < eng_tn:
		return {
			"success": false,
			"phase_failed": "engineering",
			"roll_total": eng_result.total,
			"tn": eng_tn,
			"margin": eng_result.total - eng_tn,
			"method": ExecutionMethod.ARRANGED_ACCIDENT,
		}

	var stealth_rank: int = assassin.skills.get("Stealth", 0)
	var stealth_result: DiceResult = dice_engine.roll_and_keep(
		assassin.agility + stealth_rank, assassin.agility, stealth_rank > 0
	)
	var stealth_tn: int = ACCIDENT_STEALTH_TN + susp_mod
	var success: bool = stealth_result.total >= stealth_tn

	return {
		"success": success,
		"phase_failed": "" if success else "stealth",
		"engineering_total": eng_result.total,
		"stealth_total": stealth_result.total,
		"tn": stealth_tn,
		"margin": stealth_result.total - stealth_tn,
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
) -> Dictionary:
	var method: ExecutionMethod = state.get("method", ExecutionMethod.POISON)
	var tn: int = get_concealment_tn(method)

	var skill: String = ""
	var trait_val: int = 0
	match method:
		ExecutionMethod.POISON:
			skill = "Medicine"
			trait_val = assassin.intelligence
		ExecutionMethod.BLADE:
			skill = "Stealth"
			trait_val = assassin.agility
		ExecutionMethod.ARRANGED_ACCIDENT:
			skill = "Engineering"
			trait_val = assassin.intelligence

	var skill_rank: int = assassin.skills.get(skill, 0)
	var rolled: int = trait_val + skill_rank
	var kept: int = trait_val
	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept, skill_rank > 0)
	var success: bool = result.total >= tn
	var margin: int = result.total - tn

	var concealment_tn_for_investigators: int = result.total if success else 0

	state["concealment_result"] = {
		"success": success,
		"concealed": success,
		"roll_total": result.total,
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
			var stealth_rank: int = assassin.skills.get("Stealth", 0)
			var stealth_result: DiceResult = dice_engine.roll_and_keep(
				assassin.agility + stealth_rank, assassin.agility, stealth_rank > 0
			)
			var guard_perception: int = bodyguard.perception
			var guard_inv: int = bodyguard.skills.get("Investigation", 0)
			var guard_result: DiceResult = dice_engine.roll_and_keep(
				guard_perception + guard_inv, guard_perception, guard_inv > 0
			)
			var evaded: bool = stealth_result.total >= guard_result.total
			if not evaded:
				add_suspicion(state, SUSPICION_CRITICAL_FAILURE)
			return {
				"evaded_guard": evaded,
				"assassin_stealth": stealth_result.total,
				"guard_detection": guard_result.total,
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
