class_name IntimidationSystem
## Intimidation and Blackmail per GDD s12.9.
## Three contexts: blackmail (private), private intimidation, public intimidation.
## All produce compliance rather than genuine agreement.


# -- Enums & Constants --------------------------------------------------------

enum IntimidationType {
	BLACKMAIL,
	PRIVATE_IN_PERSON,
	PRIVATE_BY_LETTER,
	PUBLIC_COURT,
}

const SECRET_FREE_RAISES: Dictionary = {
	1: 3,
	2: 2,
	3: 1,
	4: 0,
}

const BLACKMAIL_HONOR_LOSS: float = -0.3
const BLACKMAIL_INFAMY_GAIN: float = 0.1
const PRIVATE_HONOR_LOSS: float = -0.2
const PRIVATE_INFAMY_GAIN: float = 0.05
const PUBLIC_HONOR_LOSS: float = -0.3
const PUBLIC_INFAMY_GAIN: float = 0.1
const PUBLIC_WITNESS_DISPOSITION_LOSS: int = -2

const PRIVATE_TN_INCREASE_BASE: int = 10
const PRIVATE_TN_INCREASE_PER_RAISE: int = 5
const LETTER_TN_INCREASE: int = 5
const PUBLIC_TN_INCREASE_BASE: int = 10
const PUBLIC_TN_INCREASE_PER_RAISE: int = 5

const PUSHBACK_TN_BASE: int = 15

const DISPOSITION_FRIEND_BONUS: int = 5
const DISPOSITION_ENEMY_PENALTY: int = -5


# -- Blackmail ----------------------------------------------------------------

static func resolve_blackmail(
	attacker_roll: int,
	defender_roll: int,
	defender_honor: float,
	secret_tier: int,
	disposition_tier: String = "neutral",
) -> Dictionary:
	var defender_total: int = defender_roll + int(defender_honor)
	defender_total += _disposition_defense_bonus(disposition_tier)

	var free_raises: int = SECRET_FREE_RAISES.get(secret_tier, 0)
	var effective_roll: int = attacker_roll + (free_raises * 5)

	var success: bool = effective_roll >= defender_total
	var favors_extracted: int = 0

	if success:
		var margin: int = effective_roll - defender_total
		favors_extracted = max(0, margin / 5)

	return {
		"success": success,
		"favors_extracted": favors_extracted,
		"honor_loss": BLACKMAIL_HONOR_LOSS,
		"infamy_gain": BLACKMAIL_INFAMY_GAIN,
		"compliance_active": success,
	}


# -- Private Intimidation -----------------------------------------------------

static func resolve_private_intimidation(
	attacker_roll: int,
	defender_roll: int,
	defender_honor: float,
	by_letter: bool = false,
	raises: int = 0,
	disposition_tier: String = "neutral",
) -> Dictionary:
	var defender_total: int = defender_roll + int(defender_honor)
	defender_total += _disposition_defense_bonus(disposition_tier)

	if by_letter:
		var tn: int = 15 + int(defender_honor)
		var success: bool = attacker_roll >= tn
		return {
			"success": success,
			"tn_increase": LETTER_TN_INCREASE if success else 0,
			"honor_loss": PRIVATE_HONOR_LOSS,
			"infamy_gain": PRIVATE_INFAMY_GAIN,
			"compliance_active": success,
		}

	var tn: int = defender_total + (raises * 5)
	var success: bool = attacker_roll >= tn
	var tn_increase: int = 0
	if success:
		tn_increase = PRIVATE_TN_INCREASE_BASE + (raises * PRIVATE_TN_INCREASE_PER_RAISE)

	return {
		"success": success,
		"tn_increase": tn_increase,
		"honor_loss": PRIVATE_HONOR_LOSS,
		"infamy_gain": PRIVATE_INFAMY_GAIN,
		"compliance_active": success,
	}


# -- Public Intimidation ------------------------------------------------------

static func resolve_public_intimidation(
	attacker_roll: int,
	defender_roll: int,
	defender_honor: float,
	raises: int = 0,
	witnesses: Array[int] = [],
	disposition_tier: String = "neutral",
) -> Dictionary:
	var defender_total: int = defender_roll + int(defender_honor)
	defender_total += _disposition_defense_bonus(disposition_tier)

	var tn: int = defender_total + (raises * 5)
	var success: bool = attacker_roll >= tn
	var tn_increase: int = 0
	if success:
		tn_increase = PUBLIC_TN_INCREASE_BASE + (raises * PUBLIC_TN_INCREASE_PER_RAISE)

	return {
		"success": success,
		"tn_increase": tn_increase,
		"honor_loss": PUBLIC_HONOR_LOSS,
		"infamy_gain": PUBLIC_INFAMY_GAIN,
		"witness_disposition_loss": PUBLIC_WITNESS_DISPOSITION_LOSS,
		"witnesses": witnesses,
		"compliance_active": success,
	}


# -- Compliance ---------------------------------------------------------------

static func get_pushback_tn(intimidator_skill_rank: int) -> int:
	return PUSHBACK_TN_BASE + intimidator_skill_rank


static func can_compliance_end(
	intimidator_disposition_toward_target: int,
	friend_threshold: int = 51,
) -> bool:
	return intimidator_disposition_toward_target >= friend_threshold


# -- Helpers ------------------------------------------------------------------

static func _disposition_defense_bonus(tier: String) -> int:
	match tier:
		"friend", "ally", "sworn":
			return DISPOSITION_FRIEND_BONUS
		"enemy", "bitter_enemy":
			return DISPOSITION_ENEMY_PENALTY
	return 0
