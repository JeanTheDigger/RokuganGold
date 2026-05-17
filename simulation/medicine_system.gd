class_name MedicineSystem
## Out-of-combat wound treatment per GDD s57.31.
## TREAT_WOUND ActionID: Medicine (Wound Treatment) / Intelligence TN 15.
## One treatment per target per IC day. Medicine Kit: 10 charges, one per character.

# ---- Refusal formula constants (s57.31.3b) ------------------------------------
const REFUSAL_THRESHOLD: int = 10
const YU_FACTOR: int = 5
const HONOUR_RANK_FACTOR: int = 2
const WITNESS_PRESSURE: int = 5
const MAX_WITNESS_COUNT: int = 4
const CHUGI_FACTOR: int = 4
const STRONG_ENEMY_PRESSURE: int = 100

# Wound severity modifiers applied directly to refusal_pressure (s57.31.3b).
const SEVERITY_BY_LEVEL: Dictionary = {
	Enums.WoundLevel.HEALTHY:  0,
	Enums.WoundLevel.NICKED:   0,
	Enums.WoundLevel.GRAZED:  -3,
	Enums.WoundLevel.HURT:    -6,
	Enums.WoundLevel.INJURED: -15,
	Enums.WoundLevel.CRIPPLED: -30,
	# DOWN and OUT bypass the formula entirely — auto-accept.
}

# ---- Roll constants (s57.31.2) ------------------------------------------------
const BASE_TN: int = 15
const NON_HUMAN_TN_PENALTY: int = 10
const MEDICINE_MASTERY_RANK: int = 5

# ---- Medicine Kit (s57.31.5) --------------------------------------------------
const KIT_ITEM_TYPE: String = "medicine_kit"
const KIT_MAX_CHARGES: int = 10

# ---- TEND_WOUNDED_ALLY scoring (s57.31.7) -------------------------------------
const PRIORITY_STRONG_ALLY: int = 3
const PRIORITY_FRIEND: int = 2
const PRIORITY_ACQUAINTANCE: int = 1
const PRIORITY_CEILING: int = 4

const WOUND_MOD_HURT: int = 1
const WOUND_MOD_INJURED: int = 2
const WOUND_MOD_CRITICAL: int = 3

const JIN_SCORE_MOD: int = 15
const GI_SCORE_MOD: int = 10
const CHUGI_SCORE_MOD: int = 20
const REI_SCORE_MOD: int = 5

# Non-human clans (s57.31.6). The clan field encodes species for non-samurai.
const NON_HUMAN_CLANS: Array[String] = [
	"Nezumi", "Naga", "Zokujin", "Kenku", "Kitsu", "Troll",
]


# =============================================================================
# MEDICINE KIT HELPERS
# =============================================================================

static func find_medicine_kit(character: L5RCharacterData) -> Dictionary:
	for item: Dictionary in character.items:
		if item.get("item_type", "") == KIT_ITEM_TYPE \
				and item.get("remaining_uses", 0) > 0:
			return item
	return {}


static func has_medicine_kit(character: L5RCharacterData) -> bool:
	return not find_medicine_kit(character).is_empty()


## Decrements remaining_uses by 1. Removes kit from inventory when exhausted.
## Returns true if a charge was consumed, false if no kit found.
static func consume_kit_charge(character: L5RCharacterData) -> bool:
	for i: int in range(character.items.size()):
		var item: Dictionary = character.items[i]
		if item.get("item_type", "") == KIT_ITEM_TYPE \
				and item.get("remaining_uses", 0) > 0:
			item["remaining_uses"] -= 1
			if item["remaining_uses"] <= 0:
				character.items.remove_at(i)
			return true
	return false


# =============================================================================
# VALIDATOR
# =============================================================================

## Returns {"valid": bool, "reason": String}.
## Checks all preconditions except zone co-location (enforced by caller).
static func can_treat(
	healer: L5RCharacterData,
	target: L5RCharacterData,
	ic_day: int,
) -> Dictionary:
	if CharacterStats.is_dead(healer):
		return {"valid": false, "reason": "healer_dead"}
	if CharacterStats.is_dead(target):
		return {"valid": false, "reason": "target_dead"}
	if healer.character_id == target.character_id:
		return {"valid": false, "reason": "no_self_treatment"}
	if target.wounds_taken <= 0:
		return {"valid": false, "reason": "target_unwounded"}
	if target.last_medicine_treatment_ic_day == ic_day:
		return {"valid": false, "reason": "daily_limit_reached"}
	if not has_medicine_kit(healer):
		return {"valid": false, "reason": "no_medicine_kit"}
	return {"valid": true, "reason": ""}


# =============================================================================
# TREATMENT REFUSAL (s57.31.3b)
# =============================================================================

## Returns true if the target refuses treatment.
## witness_count: number of named characters in zone excluding healer and target.
static func evaluate_refusal(
	target: L5RCharacterData,
	healer: L5RCharacterData,
	witness_count: int,
) -> bool:
	# Strong Enemy always refuses (disposition ≤ −50), even unconscious.
	var disp: int = target.disposition_values.get(healer.character_id, 0)
	if disp <= -50:
		return true

	# Non-humans: simplified rule — refuse only at Rival or worse disposition.
	if _is_non_human(target):
		return disp < -10

	var wound_level: Enums.WoundLevel = CharacterStats.get_wound_level(target)

	# Down and Out bypass formula — auto-accept (only blocked by Strong Enemy above).
	if wound_level == Enums.WoundLevel.DOWN or wound_level == Enums.WoundLevel.OUT:
		return false

	return _compute_refusal_pressure(target, healer, witness_count, wound_level) \
		> REFUSAL_THRESHOLD


static func _compute_refusal_pressure(
	target: L5RCharacterData,
	healer: L5RCharacterData,
	witness_count: int,
	wound_level: Enums.WoundLevel,
) -> int:
	var pressure: int = 0

	# Yū proxy: Willpower — mental endurance and stoicism under pressure.
	# Chūgi proxy: dominant CHUGI virtue → score 4, otherwise 2.
	var yu: int = target.willpower
	var chugi: int = 4 if target.bushido_virtue == Enums.BushidoVirtue.CHUGI else 2
	var honour_rank: int = int(target.honor)
	var capped_witnesses: int = mini(witness_count, MAX_WITNESS_COUNT)

	# Pride factors (increase pressure).
	pressure += yu * YU_FACTOR
	pressure += honour_rank * HONOUR_RANK_FACTOR
	pressure += capped_witnesses * WITNESS_PRESSURE

	# Acceptance factors (decrease pressure).
	pressure -= chugi * CHUGI_FACTOR
	pressure += SEVERITY_BY_LEVEL.get(wound_level, 0)
	pressure += _disposition_modifier(target, healer.character_id)

	return pressure


static func _disposition_modifier(target: L5RCharacterData, healer_id: int) -> int:
	var disp: int = target.disposition_values.get(healer_id, 0)
	if disp >= 50:
		return -15
	if disp >= 25:
		return -10
	if disp >= 10:
		return -5
	if disp >= 0:
		return 0
	if disp >= -25:
		return 10
	if disp >= -50:
		return 20
	return STRONG_ENEMY_PRESSURE  # already handled above, but safe fallback


static func _is_non_human(character: L5RCharacterData) -> bool:
	return character.clan in NON_HUMAN_CLANS


# =============================================================================
# TREAT_WOUND (s57.31.2)
# =============================================================================

## Executes the full TREAT_WOUND action.
## raises: number of raises called before the roll (increases TN, adds healing dice on success).
## Returns result dict; always sets last_medicine_treatment_ic_day and consumes kit charge.
static func treat_wound(
	healer: L5RCharacterData,
	target: L5RCharacterData,
	dice: DiceEngine,
	ic_day: int,
	raises: int = 0,
) -> Dictionary:
	var is_non_human_target: bool = _is_non_human(target)
	var race_name: String = target.clan if is_non_human_target else ""

	# Determine emphasis and TN.
	var emphasis: String
	var tn_bonus: int = 0
	if is_non_human_target:
		var non_human_emphasis: String = "Non-Humans: " + race_name
		if SkillResolver.has_emphasis(healer, "Medicine", non_human_emphasis):
			emphasis = non_human_emphasis
		else:
			emphasis = ""
			tn_bonus = NON_HUMAN_TN_PENALTY
	else:
		emphasis = "Wound Treatment"

	var tn: int = BASE_TN + tn_bonus

	# Medicine / Intelligence skill check.
	var check: Dictionary = SkillResolver.resolve_skill_check(
		healer, dice, "Medicine", tn, raises, emphasis,
		Enums.Trait.INTELLIGENCE,
	)

	# Daily limit and kit charge apply regardless of success.
	target.last_medicine_treatment_ic_day = ic_day
	consume_kit_charge(healer)

	var result: Dictionary = {
		"success": check["success"],
		"roll_total": check["total"],
		"tn": tn,
		"raises": raises,
		"wounds_healed": 0,
		"kit_charge_consumed": true,
		"target_id": target.character_id,
		"healer_id": healer.character_id,
	}

	if not check["success"]:
		return result

	# Healing roll: 1k1 base; +1 die at Rank 5 mastery; +1 die per raise (keep 1).
	var medicine_rank: int = SkillResolver.get_skill_rank(healer, "Medicine")
	var mastery_bonus: int = 1 if medicine_rank >= MEDICINE_MASTERY_RANK else 0
	var healing_dice: int = 1 + mastery_bonus + raises
	var heal_roll: int = dice.roll_and_keep(healing_dice, 1).total

	var heal_result: Dictionary = WoundSystem.heal_wounds(target, heal_roll)
	result["wounds_healed"] = heal_result["healed"]
	result["wound_level_after"] = heal_result["wound_level"]

	return result


# =============================================================================
# NPC SCORING — TEND_WOUNDED_ALLY (s57.31.7)
# =============================================================================

## Priority 0–4 for the TEND_WOUNDED_ALLY NeedType.
## healer: the NPC considering the action; target: the wounded character.
static func compute_tend_priority(
	healer: L5RCharacterData,
	target: L5RCharacterData,
) -> int:
	# Only fires for disposition ≥ 0 (Neutral or better).
	var disp: int = healer.disposition_values.get(target.character_id, 0)
	if disp < 0:
		return 0

	# Base priority by disposition tier.
	var base: int
	if disp >= 50:
		base = PRIORITY_STRONG_ALLY
	elif disp >= 25:
		base = PRIORITY_FRIEND
	else:
		base = PRIORITY_ACQUAINTANCE

	# Wound Rank modifier.
	var wound_level: Enums.WoundLevel = CharacterStats.get_wound_level(target)
	var wound_mod: int = 0
	match wound_level:
		Enums.WoundLevel.HURT:
			wound_mod = WOUND_MOD_HURT
		Enums.WoundLevel.INJURED:
			wound_mod = WOUND_MOD_INJURED
		Enums.WoundLevel.CRIPPLED, Enums.WoundLevel.DOWN, Enums.WoundLevel.OUT:
			wound_mod = WOUND_MOD_CRITICAL

	return mini(base + wound_mod, PRIORITY_CEILING)


## Personality score modifier for TEND_WOUNDED_ALLY (s57.31.7).
## Returns additive score bonus to apply on top of the base priority score.
static func compute_tend_personality_bonus(
	healer: L5RCharacterData,
	target: L5RCharacterData,
	is_lord_or_superior: bool,
) -> int:
	var bonus: int = 0
	if healer.bushido_virtue == Enums.BushidoVirtue.JIN:
		bonus += JIN_SCORE_MOD
	if healer.bushido_virtue == Enums.BushidoVirtue.GI:
		bonus += GI_SCORE_MOD
	if healer.bushido_virtue == Enums.BushidoVirtue.REI:
		bonus += REI_SCORE_MOD
	if healer.bushido_virtue == Enums.BushidoVirtue.CHUGI and is_lord_or_superior:
		bonus += CHUGI_SCORE_MOD
	return bonus
