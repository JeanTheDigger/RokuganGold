class_name OrderSystem
## Military command order system per GDD s11.7a. Lords and commanders issue
## orders to subordinates. Orders budget by rank, messenger delivery times,
## standing patrol assignments. Pure static functions.


# -- Order Budget by Rank -------------------------------------------------------

const LORD_ORDER_BUDGET: int = 10

const RANK_ORDER_BUDGET: Dictionary = {
	Enums.MilitaryRank.CHUI: 5,
	Enums.MilitaryRank.TAISA: 10,
	Enums.MilitaryRank.SHIREIKAN: 10,
	Enums.MilitaryRank.RIKUGUNSHOKAN: 15,
}

const MESSENGER_SPEED_SUBTILES_PER_DAY: int = 1


# -- Order Types -----------------------------------------------------------------

enum OrderType {
	SCOUT,
	HOLD_POSITION,
	GARRISON_PROVINCE,
	MARCH_TO,
	RECALL,
	DETACH_TO_SUPPORT,
	STANDING_PATROL,
	DELIVER_LETTER,
}

# GDD s11.7a specifies SCOUT and STANDING_PATROL cost 1 order each.
# Other order types default to 1 (GDD does not specify individual costs).
const ORDER_COST: Dictionary = {
	OrderType.SCOUT: 1,
	OrderType.HOLD_POSITION: 1,
	OrderType.GARRISON_PROVINCE: 1,
	OrderType.MARCH_TO: 1,
	OrderType.RECALL: 1,
	OrderType.DETACH_TO_SUPPORT: 1,
	OrderType.STANDING_PATROL: 1,
	OrderType.DELIVER_LETTER: 1,
}


# -- Order State Factory ---------------------------------------------------------

static func create_order_state(
	commander_id: int,
	military_rank: Enums.MilitaryRank,
	is_feudal_lord: bool = false,
) -> Dictionary:
	var budget: int = 0
	if is_feudal_lord:
		budget = LORD_ORDER_BUDGET
	else:
		budget = RANK_ORDER_BUDGET.get(military_rank, 0)

	return {
		"commander_id": commander_id,
		"military_rank": military_rank,
		"is_feudal_lord": is_feudal_lord,
		"budget": budget,
		"orders_used": 0,
		"standing_orders": [],
		"pending_orders": [],
	}


static func get_remaining_orders(order_state: Dictionary) -> int:
	return maxi(order_state["budget"] - order_state["orders_used"], 0)


static func reset_daily_orders(order_state: Dictionary) -> void:
	order_state["orders_used"] = 0


# -- Issue Order -----------------------------------------------------------------

static func create_order(
	order_type: OrderType,
	target_character_id: int,
	target_location_id: int = -1,
	details: Dictionary = {},
) -> Dictionary:
	return {
		"order_type": order_type,
		"target_character_id": target_character_id,
		"target_location_id": target_location_id,
		"details": details,
		"delivery_days_remaining": 0,
		"delivered": false,
		"is_standing": order_type == OrderType.STANDING_PATROL,
	}


static func issue_order(
	order_state: Dictionary,
	order: Dictionary,
	same_location: bool,
	distance_sub_tiles: int = 0,
) -> Dictionary:
	var cost: int = ORDER_COST.get(order["order_type"], 1)
	var remaining: int = get_remaining_orders(order_state)

	if remaining < cost:
		return {"success": false, "reason": "insufficient_orders"}

	order_state["orders_used"] += cost

	if same_location:
		order["delivery_days_remaining"] = 0
		order["delivered"] = true
	else:
		order["delivery_days_remaining"] = maxi(distance_sub_tiles, 1)
		order["delivered"] = false

	if order["is_standing"]:
		order_state["standing_orders"].append(order)
	else:
		order_state["pending_orders"].append(order)

	return {
		"success": true,
		"delivery_days": order["delivery_days_remaining"],
		"instant": order["delivered"],
		"orders_remaining": get_remaining_orders(order_state),
	}


# -- Messenger Delivery Processing -----------------------------------------------

static func process_pending_orders(order_state: Dictionary) -> Array:
	var delivered: Array = []
	var still_pending: Array = []

	for order: Dictionary in order_state["pending_orders"]:
		if order["delivered"]:
			delivered.append(order)
			continue

		order["delivery_days_remaining"] -= 1
		if order["delivery_days_remaining"] <= 0:
			order["delivered"] = true
			delivered.append(order)
		else:
			still_pending.append(order)

	order_state["pending_orders"] = still_pending
	return delivered


# -- Standing Order Management ---------------------------------------------------

static func cancel_standing_order(
	order_state: Dictionary,
	target_character_id: int,
) -> Dictionary:
	var found: bool = false
	var remaining: Array = []
	for order: Dictionary in order_state["standing_orders"]:
		if order["target_character_id"] == target_character_id and not found:
			found = true
			continue
		remaining.append(order)
	order_state["standing_orders"] = remaining
	return {"cancelled": found}


static func get_standing_orders(order_state: Dictionary) -> Array:
	return order_state["standing_orders"].duplicate()


# -- Messenger Travel Time -------------------------------------------------------

static func compute_messenger_travel_time(distance_sub_tiles: int) -> int:
	return maxi(distance_sub_tiles * MESSENGER_SPEED_SUBTILES_PER_DAY, 1)


# -- Scout Order Helpers ---------------------------------------------------------

static func create_scout_order(
	target_character_id: int,
	target_sub_tile: int,
) -> Dictionary:
	return create_order(
		OrderType.SCOUT,
		target_character_id,
		target_sub_tile,
	)


static func create_patrol_order(
	target_character_id: int,
	target_sub_tile: int,
) -> Dictionary:
	return create_order(
		OrderType.STANDING_PATROL,
		target_character_id,
		target_sub_tile,
	)


static func create_march_order(
	target_character_id: int,
	destination: int,
) -> Dictionary:
	return create_order(
		OrderType.MARCH_TO,
		target_character_id,
		destination,
	)
