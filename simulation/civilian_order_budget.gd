class_name CivilianOrderBudget
## Civilian Order Budget system per GDD s57.34.
## Lords issue orders to household staff for governance actions.
## Separate pool from AP (personal actions) and Military Orders (troop directives).
## Budget refreshes each OOC day. Unused orders expire. Non-lords have budget 0.


# -- Budget by Rank (s57.34.2) -------------------------------------------------

const BUDGET_BY_RANK: Dictionary = {
	Enums.LordRank.VILLAGE_HEADMAN: 0,
	Enums.LordRank.CITY_DAIMYO: 5,
	Enums.LordRank.PROVINCIAL_DAIMYO: 8,
	Enums.LordRank.FAMILY_DAIMYO: 10,
	Enums.LordRank.CLAN_CHAMPION: 12,
	Enums.LordRank.IMPERIAL: 15,
}


# -- Action Classification (s57.34.4) ------------------------------------------
# Pure civilian orders: reclassified from 1 AP to 1 Civilian Order.
# Lords only. Cost 0 AP + 1 Civilian Order.

const PURE_ORDER_ACTIONS: Array[String] = [
	"SET_TAX_RATE",
	"SET_STIPEND_RATE",
	"REQUEST_ART",
	"REQUEST_PERFORMANCE",
	"ASSIGN_VASSAL_OBJECTIVE",
	"ASSIGN_TO_MILITARY_SERVICE",
	"ASSESS_PROVINCE_STATUS",
]

# Military-or-civilian: draw from Military Orders if lord holds military rank,
# otherwise from Civilian Orders. Lords without military rank must use Civilian Orders.
const MILITARY_OR_CIVILIAN_ACTIONS: Array[String] = [
	"ASSIGN_GARRISON",
	"ORDER_LEVY",
	"ORDER_DEPLOY",
	"ORDER_FORTIFY",
	"ORDER_PATROL",
	"ORDER_RETREAT",
	"EVALUATE_WAR_READINESS",
]

# Dual-cost actions: cost 1 AP + 1 Civilian Order. Lords only (s57.34.7).
const DUAL_COST_ACTIONS: Array[String] = [
	"SEND_INVITATION",
]

# WRITE_LETTER for lords: 0 AP + 1 Civilian Order, no per-IC-day cap (s57.34.7).
# For non-lords: resolved via daily free letter pass (unchanged).
const WRITE_LETTER: String = "WRITE_LETTER"


# -- Rank Derivation -----------------------------------------------------------
# GDD s57.34 specifies budgets per lord rank but not status-to-rank thresholds.
# Thresholds are structural wiring based on L5R Status Range conventions.

static func lord_rank_from_status(status: float) -> Enums.LordRank:
	if status >= 9.0:
		return Enums.LordRank.IMPERIAL
	elif status >= 7.0:
		return Enums.LordRank.CLAN_CHAMPION
	elif status >= 6.0:
		return Enums.LordRank.FAMILY_DAIMYO
	elif status >= 5.0:
		return Enums.LordRank.PROVINCIAL_DAIMYO
	elif status >= 4.0:
		return Enums.LordRank.CITY_DAIMYO
	return Enums.LordRank.VILLAGE_HEADMAN


static func get_budget_for_rank(rank: Enums.LordRank) -> int:
	return BUDGET_BY_RANK.get(rank, 0)


# -- Character Budget Management -----------------------------------------------

static func update_budget_for_character(character: L5RCharacterData) -> void:
	var rank: Enums.LordRank = lord_rank_from_status(character.status)
	character.civilian_order_budget_max = get_budget_for_rank(rank)


static func can_spend_order(character: L5RCharacterData) -> bool:
	return character.civilian_orders_remaining > 0


static func spend_order(character: L5RCharacterData) -> Dictionary:
	if not can_spend_order(character):
		return {
			"success": false,
			"reason": "insufficient_civilian_orders",
			"available": character.civilian_orders_remaining,
		}
	character.civilian_orders_remaining -= 1
	return {
		"success": true,
		"remaining": character.civilian_orders_remaining,
	}


# -- Action Classification Helpers ---------------------------------------------

static func is_order_action(
	action_id: String,
	is_lord: bool,
	has_military_rank: bool,
) -> bool:
	if not is_lord:
		return false
	if action_id in PURE_ORDER_ACTIONS:
		return true
	if action_id == WRITE_LETTER:
		return true
	if action_id in DUAL_COST_ACTIONS:
		return true
	if action_id in MILITARY_OR_CIVILIAN_ACTIONS:
		return true
	return false


static func draws_from_military_pool(
	action_id: String,
	has_military_rank: bool,
) -> bool:
	return (action_id in MILITARY_OR_CIVILIAN_ACTIONS) and has_military_rank
