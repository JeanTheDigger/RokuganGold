class_name CommerceStigmaSystem
## Commerce and the Caste Stigma — GDD s57.40 (LOCKED)
## Public Commerce rolls cost Honor (rank-scaled) and Glory (flat) once per IC day.
## Ide Trader exception waives penalties but not topic generation.

const PUBLIC_ALWAYS: Array[String] = ["PURCHASE_MARKET"]
const PUBLIC_IN_COURT_OR_VISITING: Array[String] = ["CONDUCT_COMMERCE"]

const HONOR_THRESHOLD_HIGH: float = 7.0
const HONOR_THRESHOLD_MID: float = 5.0
const HONOR_THRESHOLD_LOW: float = 3.0
const HONOR_PENALTY_HIGH: float = -0.3
const HONOR_PENALTY_MID: float = -0.2
const HONOR_PENALTY_LOW: float = -0.1
const GLORY_PENALTY: float = -0.1

const LEAN_PLUS_10_SCORE: int = 10
const LEAN_PLUS_5_SCORE: int = 5
const LEAN_MINUS_10_SCORE: int = -10
const LEAN_MINUS_5_SCORE: int = -5
const HONOR_SELF_REG_5_6: int = -3
const HONOR_SELF_REG_7_PLUS: int = -5

const LEAN_PLUS_10: Array[String] = ["Ide Trader"]
const LEAN_PLUS_5: Array[String] = [
	"Yasuki Courtier", "Yoritomo Courtier", "Ide Emissary", "Ide Caravan Master",
	"Kasuga Smuggler", "Tsi Smith", "Yasuki Extortionist", "Daidoji Trading Council",
	"Yoritomo Scoundrel",
]
const LEAN_MINUS_10: Array[String] = [
	"Doji Courtier", "Kakita Artisan", "Otomo Courtier", "Seppun Miharu",
	"Isawa Shugenja", "Asako Inquisitor", "Asako Loremaster", "Agasha Shugenja",
	"Kitsu Sodan Senzo",
]
const LEAN_MINUS_5: Array[String] = ["Miya Herald"]


static func is_public_commerce(
	action_id: String,
	ctx: NPCDataStructures.ContextSnapshot,
) -> bool:
	if action_id in PUBLIC_ALWAYS:
		return true
	if action_id in PUBLIC_IN_COURT_OR_VISITING:
		return (
			ctx.context_flag == Enums.ContextFlag.AT_COURT
			or ctx.context_flag == Enums.ContextFlag.VISITING
		)
	return false


static func has_ide_trader_exception(character: L5RCharacterData) -> bool:
	return "Ide Trader" in character.school_paths


static func compute_honor_penalty(character: L5RCharacterData) -> float:
	return CrimeSystem.get_low_skill_honor_cost(character)


static func apply_stigma(
	character: L5RCharacterData,
	ctx: NPCDataStructures.ContextSnapshot,
) -> Dictionary:
	## Returns Pattern-B-safe keys: stigma_fired, stigma_honor_change,
	## stigma_glory_change, public_commerce_topic.
	## Pre-applies commerce_stigma_applied_ic_day flag on first call per IC day.
	if has_ide_trader_exception(character):
		return {
			"stigma_fired": false,
			"stigma_honor_change": 0.0,
			"stigma_glory_change": 0.0,
			"public_commerce_topic": true,
		}

	if character.commerce_stigma_applied_ic_day == ctx.ic_day:
		return {
			"stigma_fired": false,
			"stigma_honor_change": 0.0,
			"stigma_glory_change": 0.0,
			"public_commerce_topic": false,
		}

	character.commerce_stigma_applied_ic_day = ctx.ic_day
	return {
		"stigma_fired": true,
		"stigma_honor_change": compute_honor_penalty(character),
		"stigma_glory_change": GLORY_PENALTY,
		"public_commerce_topic": true,
	}


static func get_school_lean(school: String) -> int:
	if school in LEAN_PLUS_10:
		return LEAN_PLUS_10_SCORE
	if school in LEAN_PLUS_5:
		return LEAN_PLUS_5_SCORE
	if school in LEAN_MINUS_10:
		return LEAN_MINUS_10_SCORE
	if school in LEAN_MINUS_5:
		return LEAN_MINUS_5_SCORE
	return 0
