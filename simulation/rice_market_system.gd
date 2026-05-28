class_name RiceMarketSystem
## Decentralized rice market per GDD s4.3.18.
## Each lord independently posts surplus, sets prices, and buys from others.
## Disposition-based purchase priority. Intra-clan sharing generates Honor.


const BASELINE_PRICE: float = 1.0
const PRICE_ADJUSTMENT: float = 0.25
const PRICE_FLOOR: float = 0.25

const HONOR_SHARING_SHORTAGE_SMALL: float = 0.1
const HONOR_SHARING_SHORTAGE_SIGNIFICANT: float = 0.2
const HONOR_SHARING_HUNGER: float = 0.3
const HONOR_SHARING_FAMINE: float = 0.5
const HONOR_SHARING_FAMINE_RESOLVED: float = 1.0


# =============================================================================
# Surplus Calculation
# =============================================================================

static func compute_surplus(
	settlement: SettlementData,
	seasons_of_consumption: int = 4,
) -> float:
	var seasonal_need: float = settlement.population_pu * 0.25
	var total_need: float = seasonal_need * seasons_of_consumption
	return maxf(settlement.rice_stockpile - total_need, 0.0)


# =============================================================================
# Rice Posting (listing for sale)
# =============================================================================

static func create_posting(
	lord_id: int,
	province_id: int,
	quantity: float,
	current_price: float,
) -> RicePostingData:
	var posting := RicePostingData.new()
	posting.lord_id = lord_id
	posting.province_id = province_id
	posting.quantity = maxf(quantity, 0.0)
	posting.price_per_unit = maxf(current_price, PRICE_FLOOR)
	return posting


static func adjust_price_after_season(posting: RicePostingData, was_sold: bool) -> void:
	if was_sold:
		posting.seasons_sold += 1
		posting.seasons_unsold = 0
		posting.price_per_unit += PRICE_ADJUSTMENT
	else:
		posting.seasons_unsold += 1
		posting.seasons_sold = 0
		posting.price_per_unit = maxf(posting.price_per_unit - PRICE_ADJUSTMENT, PRICE_FLOOR)


static func should_withdraw(posting: RicePostingData) -> bool:
	return posting.price_per_unit <= PRICE_FLOOR and posting.seasons_unsold >= 1


# =============================================================================
# Purchase Priority (disposition-based, s4.3.18)
# =============================================================================

const PRIORITY_FRIEND: int = 1
const PRIORITY_ACQUAINTANCE: int = 2
const PRIORITY_RIVAL: int = 3

static func get_purchase_priority(disposition: int) -> int:
	if disposition >= 31:
		return PRIORITY_FRIEND
	if disposition >= -10:
		return PRIORITY_ACQUAINTANCE
	return PRIORITY_RIVAL


static func can_sell_to(_seller_disposition_to_buyer: int) -> bool:
	return true


# =============================================================================
# Purchase Resolution
# =============================================================================

static func resolve_purchases(
	postings: Array,
	buy_orders: Array,
	disposition_lookup: Callable,
	worship_maluses: Dictionary = {},
) -> Array:
	var results: Array = []

	for posting: RicePostingData in postings:
		if posting.quantity <= 0.0:
			continue

		var prioritized: Array = []
		for order: Dictionary in buy_orders:
			var buyer_id: int = order.get("lord_id", -1)
			if buyer_id == posting.lord_id:
				continue
			var disposition: int = disposition_lookup.call(posting.lord_id, buyer_id)
			if not can_sell_to(disposition):
				continue
			var priority: int = get_purchase_priority(disposition)
			prioritized.append({
				"order": order,
				"priority": priority,
				"disposition": disposition,
			})

		prioritized.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
			if a["priority"] != b["priority"]:
				return a["priority"] < b["priority"]
			return a["disposition"] > b["disposition"]
		)

		var prov_malus: Dictionary = worship_maluses.get(posting.province_id, {})
		var price_modifier: float = prov_malus.get("market_price_modifier", 0.0)
		var effective_price: float = posting.price_per_unit * (1.0 + price_modifier)

		var remaining: float = posting.quantity
		var sold_any: bool = false
		for entry: Dictionary in prioritized:
			if remaining <= 0.0:
				break
			var order: Dictionary = entry["order"]
			var wanted: float = order.get("quantity", 0.0)
			var can_afford_units: float = order.get("koku_budget", 0.0) / effective_price
			var actual: float = minf(minf(wanted, can_afford_units), remaining)
			if actual <= 0.0:
				continue
			var cost: float = actual * effective_price
			remaining -= actual
			sold_any = true
			results.append({
				"seller_id": posting.lord_id,
				"buyer_id": order.get("lord_id", -1),
				"quantity": actual,
				"price_per_unit": posting.price_per_unit,
				"total_cost": cost,
			})

		adjust_price_after_season(posting, sold_any)

	return results


# =============================================================================
# Intra-Clan Rice Sharing (s4.3.18)
# =============================================================================

static func compute_sharing_honor(
	amount: float,
	recipient_starvation_stage: int,
	resolves_famine: bool,
) -> float:
	if recipient_starvation_stage >= ResourceTick.StarvationStage.FAMINE:
		if resolves_famine:
			return HONOR_SHARING_FAMINE_RESOLVED
		return HONOR_SHARING_FAMINE
	if recipient_starvation_stage == ResourceTick.StarvationStage.HUNGER:
		return HONOR_SHARING_HUNGER
	if recipient_starvation_stage == ResourceTick.StarvationStage.SHORTAGE:
		if amount >= 1.0:
			return HONOR_SHARING_SHORTAGE_SIGNIFICANT
		return HONOR_SHARING_SHORTAGE_SMALL
	return 0.0


static func share_rice(
	giver: L5RCharacterData,
	giver_settlement: SettlementData,
	receiver_settlement: SettlementData,
	amount: float,
	recipient_starvation_stage: int,
) -> Dictionary:
	if amount <= 0.0:
		return {"result": "invalid", "honor_gain": 0.0}

	if giver_settlement.rice_stockpile < amount:
		return {"result": "insufficient", "honor_gain": 0.0}

	if recipient_starvation_stage <= ResourceTick.StarvationStage.CLEAR:
		return {"result": "not_needed", "honor_gain": 0.0}

	var seasonal_need: float = receiver_settlement.population_pu * 0.25
	var resolves: bool = (receiver_settlement.rice_stockpile + amount) >= seasonal_need

	giver_settlement.rice_stockpile -= amount
	receiver_settlement.rice_stockpile += amount

	var honor: float = compute_sharing_honor(amount, recipient_starvation_stage, resolves)
	HonorGlorySystem.apply_honor_change(giver, honor)

	return {
		"result": "success",
		"honor_gain": honor,
		"resolves_famine": resolves,
		"amount": amount,
	}


# =============================================================================
# Trade Route Koku Bonus
# =============================================================================

static func compute_trade_route_koku(
	province: ProvinceData,
	routes: Array,
	worship_maluses: Dictionary = {},
) -> float:
	var prov_malus: Dictionary = worship_maluses.get(province.province_id, {})
	if prov_malus.get("trade_route_koku_disabled", false):
		return 0.0
	var total: float = 0.0
	for route: TradeRouteData in routes:
		if route.is_disrupted:
			continue
		if route.connects(province.province_id):
			total += route.koku_bonus_per_season
	return total


static func get_active_routes_for_province(
	province_id: int,
	routes: Array,
) -> Array:
	var result: Array = []
	for route: TradeRouteData in routes:
		if route.connects(province_id) and not route.is_disrupted:
			result.append(route)
	return result


static func disrupt_route(route: TradeRouteData, reason: String) -> void:
	route.is_disrupted = true
	route.disruption_reason = reason


static func restore_route(route: TradeRouteData) -> void:
	route.is_disrupted = false
	route.disruption_reason = ""
