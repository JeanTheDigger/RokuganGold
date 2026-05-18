class_name BoundEscapeSystem

# ==============================================================================
# Bound Condition and Escape per GDD s12.8
# ==============================================================================

enum BindingMaterial {
	SIMPLE_ROPE,
	QUALITY_ROPE,
	CHAINS,
	HIGH_GRADE_CHAINS,
}

enum BoundState {
	NONE,
	BOUND,
	ESCAPED_BONDS,
	FREE,
}

enum NoiseLevel {
	NONE,
	QUIET,
	MODERATE,
}

# -- Material TNs --------------------------------------------------------------

const MATERIAL_TN: Dictionary = {
	BindingMaterial.SIMPLE_ROPE: 15,
	BindingMaterial.QUALITY_ROPE: 20,
	BindingMaterial.CHAINS: 25,
	BindingMaterial.HIGH_GRADE_CHAINS: 30,
}

# -- Constants -----------------------------------------------------------------

const ESCAPE_ATTEMPTS_PER_DAY: int = 1
const REBIND_TN_INCREASE: int = 5
const QUIET_NOISE_RANGE: int = 3
const BREAK_CHAINS_TN: int = 25
const LOW_SKILL_HONOR_COST: float = -0.1

# -- Allowed actions while bound -----------------------------------------------

const ALLOWED_ACTIONS_BOUND: Array[String] = [
	"CHARM",
	"NEGOTIATE",
	"PERSUADE",
	"INTIMIDATE",
	"SLEIGHT_OF_HAND_ESCAPE",
	"CAST_SPELL",
	"SPEAK",
]


# ==============================================================================
# State Factory
# ==============================================================================

static func create_bound_state(
	character_id: int,
	binder_id: int,
	material: BindingMaterial,
	current_ic_day: int,
	custom_tn: int = -1,
) -> Dictionary:
	var tn: int = custom_tn if custom_tn > 0 else MATERIAL_TN.get(material, 20)
	return {
		"character_id": character_id,
		"binder_id": binder_id,
		"state": BoundState.BOUND,
		"material": material,
		"escape_tn": tn,
		"bound_ic_day": current_ic_day,
		"escape_attempts_today": 0,
		"last_attempt_ic_day": -1,
		"times_rebound": 0,
	}


# ==============================================================================
# Binding with Knot-work (Named Character)
# ==============================================================================

static func resolve_knotwork_binding(
	binder: L5RCharacterData,
	target_id: int,
	dice_engine: DiceEngine,
	current_ic_day: int,
) -> Dictionary:
	var knot_rank: int = binder.skills.get("Sailing", 0)
	var rolled: int = binder.intelligence + knot_rank
	var kept: int = binder.intelligence
	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept, knot_rank > 0)

	var binding_tn: int = maxi(result.total, 15)

	var state: Dictionary = {
		"character_id": target_id,
		"binder_id": binder.character_id,
		"state": BoundState.BOUND,
		"material": BindingMaterial.QUALITY_ROPE,
		"escape_tn": binding_tn,
		"bound_ic_day": current_ic_day,
		"escape_attempts_today": 0,
		"last_attempt_ic_day": -1,
		"times_rebound": 0,
	}

	return {
		"binding_tn": binding_tn,
		"roll_total": result.total,
		"state": state,
	}


# ==============================================================================
# Escape Attempt
# ==============================================================================

static func can_attempt_escape(
	bound_state: Dictionary,
	current_ic_day: int,
) -> bool:
	if bound_state.get("state") != BoundState.BOUND:
		return false
	var last_day: int = bound_state.get("last_attempt_ic_day", -1)
	if last_day == current_ic_day:
		return bound_state.get("escape_attempts_today", 0) < ESCAPE_ATTEMPTS_PER_DAY
	return true


static func resolve_escape_attempt(
	character: L5RCharacterData,
	bound_state: Dictionary,
	dice_engine: DiceEngine,
	current_ic_day: int,
) -> Dictionary:
	if not can_attempt_escape(bound_state, current_ic_day):
		return {"success": false, "reason": "no_attempts_remaining"}

	if bound_state.get("last_attempt_ic_day", -1) != current_ic_day:
		bound_state["escape_attempts_today"] = 0

	bound_state["escape_attempts_today"] = bound_state.get("escape_attempts_today", 0) + 1
	bound_state["last_attempt_ic_day"] = current_ic_day

	var tn: int = bound_state.get("escape_tn", 20)
	var soh_rank: int = character.skills.get("Sleight of Hand", 0)
	var rolled: int = character.agility + soh_rank
	var kept: int = character.agility
	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept, soh_rank > 0)
	var success: bool = result.total >= tn
	var margin: int = result.total - tn

	var honor_cost: float = LOW_SKILL_HONOR_COST
	HonorGlorySystem.apply_honor_change(character, honor_cost)

	var noise: NoiseLevel = NoiseLevel.QUIET

	if success:
		bound_state["state"] = BoundState.ESCAPED_BONDS

	return {
		"success": success,
		"roll_total": result.total,
		"tn": tn,
		"margin": margin,
		"honor_cost": honor_cost,
		"noise_level": noise,
		"noise_range": QUIET_NOISE_RANGE,
	}


# ==============================================================================
# Guard Noise Detection
# ==============================================================================

static func resolve_guard_detection(
	guard: L5RCharacterData,
	noise: NoiseLevel,
	distance_tiles: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var noise_range: int = 0
	match noise:
		NoiseLevel.QUIET:
			noise_range = 3
		NoiseLevel.MODERATE:
			noise_range = 6
		NoiseLevel.NONE:
			return {"detected": false, "reason": "no_noise"}

	if distance_tiles > noise_range:
		return {"detected": false, "reason": "out_of_range"}

	var tn: int = 15 + (distance_tiles * 2)
	var result: Dictionary = SkillResolver.resolve_skill_check(
		guard, dice_engine, "Investigation", tn,
	)

	return {
		"detected": result.get("success", false),
		"roll_total": result.get("total", 0),
		"tn": tn,
		"distance": distance_tiles,
	}


# ==============================================================================
# Rebinding (after failed escape detected)
# ==============================================================================

static func rebind(bound_state: Dictionary) -> void:
	bound_state["escape_tn"] = bound_state.get("escape_tn", 20) + REBIND_TN_INCREASE
	bound_state["state"] = BoundState.BOUND
	bound_state["times_rebound"] = bound_state.get("times_rebound", 0) + 1


# ==============================================================================
# Location Escape (after slipping bonds)
# ==============================================================================

static func resolve_location_escape(
	character: L5RCharacterData,
	location_tn: int,
	dice_engine: DiceEngine,
) -> Dictionary:
	var stealth_rank: int = character.skills.get("Stealth", 0)
	var rolled: int = character.agility + stealth_rank
	var kept: int = character.agility
	var result: DiceResult = dice_engine.roll_and_keep(rolled, kept, stealth_rank > 0)
	var success: bool = result.total >= location_tn
	var margin: int = result.total - location_tn

	if success:
		return {
			"success": true,
			"roll_total": result.total,
			"tn": location_tn,
			"margin": margin,
			"fully_free": true,
		}

	return {
		"success": false,
		"roll_total": result.total,
		"tn": location_tn,
		"margin": margin,
		"fully_free": false,
	}


# ==============================================================================
# Free Ally
# ==============================================================================

static func free_ally_rope(bound_state: Dictionary, has_blade: bool) -> Dictionary:
	if not has_blade:
		return {"success": false, "reason": "no_blade"}

	var is_rope: bool = (
		bound_state.get("material") == BindingMaterial.SIMPLE_ROPE
		or bound_state.get("material") == BindingMaterial.QUALITY_ROPE
	)
	if not is_rope:
		return {"success": false, "reason": "not_rope"}

	bound_state["state"] = BoundState.FREE
	return {
		"success": true,
		"noise_level": NoiseLevel.QUIET,
		"noise_range": QUIET_NOISE_RANGE,
	}


static func free_ally_chains(
	rescuer: L5RCharacterData,
	bound_state: Dictionary,
	has_key: bool,
	has_tool: bool,
	dice_engine: DiceEngine,
) -> Dictionary:
	var is_chain: bool = (
		bound_state.get("material") == BindingMaterial.CHAINS
		or bound_state.get("material") == BindingMaterial.HIGH_GRADE_CHAINS
	)
	if not is_chain:
		return {"success": false, "reason": "not_chains"}

	if has_key:
		bound_state["state"] = BoundState.FREE
		return {
			"success": true,
			"method": "key",
			"noise_level": NoiseLevel.QUIET,
			"noise_range": QUIET_NOISE_RANGE,
		}

	if not has_tool:
		return {"success": false, "reason": "no_tool"}

	var result: DiceResult = dice_engine.roll_and_keep(rescuer.strength, rescuer.strength)
	var success: bool = result.total >= BREAK_CHAINS_TN

	if success:
		bound_state["state"] = BoundState.FREE

	return {
		"success": success,
		"roll_total": result.total,
		"tn": BREAK_CHAINS_TN,
		"method": "force",
		"noise_level": NoiseLevel.MODERATE if success else NoiseLevel.MODERATE,
		"noise_range": 6,
	}


# ==============================================================================
# Action Filter for Bound Characters
# ==============================================================================

static func is_action_allowed_while_bound(action_id: String) -> bool:
	return action_id in ALLOWED_ACTIONS_BOUND


static func filter_actions_for_bound(actions: Array[String]) -> Array[String]:
	var allowed: Array[String] = []
	for a in actions:
		if is_action_allowed_while_bound(a):
			allowed.append(a)
	return allowed
