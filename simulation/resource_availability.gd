class_name ResourceAvailability
## Phase 5 scoring modifier based on whether an NPC can afford a
## resource-consuming action. Per GDD s55.32.
## Ratio of available resources to action cost determines penalty (0 to -40).


# === ACTION RESOURCE COSTS ===
# resource_type: "koku", "rice", "inventory_item", "troop_pu"

const ACTION_RESOURCE_COSTS: Dictionary = {
	"BRIBE_FOR_INFO": {"resource_type": "koku", "amount": 5},
	"DELIVER_GIFT": {"resource_type": "inventory_item", "amount": 1},
	"PURCHASE_MARKET": {"resource_type": "koku", "amount": 3},
	"OFFER_FAVOR": {"resource_type": "koku", "amount": 2},
	"ORDER_LEVY": {"resource_type": "troop_pu", "amount": 1},
	"DEPLOY_ARMY": {"resource_type": "troop_pu", "amount": 1},
	"ASSIGN_GARRISON": {"resource_type": "troop_pu", "amount": 1},
	"SHARE_SUPPLIES": {"resource_type": "rice", "amount": 1},
	"TRANSFER_KOKU": {"resource_type": "koku", "amount": 5},
}

const MODIFIER_FLUSH: float = 0.0
const MODIFIER_COMFORTABLE: float = -5.0
const MODIFIER_TIGHT: float = -10.0
const MODIFIER_BARELY: float = -15.0
const MODIFIER_CANNOT_AFFORD: float = -25.0
const MODIFIER_BROKE: float = -40.0


static func compute_resource_modifier(
	action_id: String,
	character: L5RCharacterData,
	province_data: Dictionary = {},
) -> float:
	var cost: Dictionary = ACTION_RESOURCE_COSTS.get(action_id, {})
	if cost.is_empty():
		return 0.0

	var resource_type: String = cost["resource_type"]
	var amount: int = cost["amount"]
	if amount <= 0:
		return 0.0

	var available: float = _get_available_resource(
		character, resource_type, province_data
	)
	return _ratio_to_modifier(available, float(amount))


static func _get_available_resource(
	character: L5RCharacterData,
	resource_type: String,
	province_data: Dictionary,
) -> float:
	match resource_type:
		"koku":
			return character.koku
		"inventory_item":
			return float(character.items.size())
		"rice":
			return province_data.get("rice_stockpile", 0.0) as float
		"troop_pu":
			return province_data.get("available_levy_pu", 0.0) as float
	return 0.0


static func _ratio_to_modifier(available: float, cost: float) -> float:
	if available <= 0.0:
		return MODIFIER_BROKE
	var ratio: float = available / cost
	if ratio >= 5.0:
		return MODIFIER_FLUSH
	if ratio >= 3.0:
		return MODIFIER_COMFORTABLE
	if ratio >= 1.5:
		return MODIFIER_TIGHT
	if ratio >= 1.0:
		return MODIFIER_BARELY
	return MODIFIER_CANNOT_AFFORD


static func get_resource_cost(action_id: String) -> Dictionary:
	return ACTION_RESOURCE_COSTS.get(action_id, {})


static func has_resource_cost(action_id: String) -> bool:
	return ACTION_RESOURCE_COSTS.has(action_id)


static func can_afford(
	action_id: String,
	character: L5RCharacterData,
	province_data: Dictionary = {},
) -> bool:
	var cost: Dictionary = ACTION_RESOURCE_COSTS.get(action_id, {})
	if cost.is_empty():
		return true
	var amount: int = cost["amount"]
	if amount <= 0:
		return true
	var available: float = _get_available_resource(
		character, cost["resource_type"], province_data
	)
	return available >= float(amount)
