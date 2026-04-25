extends RefCounted
class_name SettlementModelTemplate

## Template-only script.
## This is intentionally not wired to scenes or managers yet.
## Purpose: demonstrate how to model multi-faction ownership inside one settlement,
## including planet rules like Ecumenopolis worlds that only allow one giant settlement.

const PLANET_TYPE_ECUMENOPOLIS := "ecumenopolis"

const RESOURCE_FOOD := "food"
const RESOURCE_WEAPONS := "weapons"
const RESOURCE_ORGANIC_MATTER := "organic_matter"

var planet := {
	"id": "planet_capital",
	"name": "Capital",
	"planet_type": PLANET_TYPE_ECUMENOPOLIS,
	"max_settlements": 1
}

## The single giant settlement for Capital.
var settlement := {
	"id": "settlement_capital_global",
	"name": "Galactic City",
	"owner_faction_id": "faction_a",
	"population": {
		"free": 1000000,
		"slave": 0
	},
	"happiness": 18,
	"stability": 16,
	"is_giant_settlement": true
}

## infrastructure_id -> data
var infrastructures: Dictionary = {}

## Array[Dictionary]
## {
##   "faction_id": String,
##   "infrastructure_id": String,
##   "resource": String,
##   "quantity": float,
##   "reserved": float
## }
var holdings: Array[Dictionary] = []

## Optional market-style offers inside this settlement.
## {
##   "seller_faction_id": String,
##   "buyer_faction_id": String, # "*" means open market
##   "resource": String,
##   "quantity": float,
##   "price_per_unit": float
## }
var trade_offers: Array[Dictionary] = []


static func can_add_settlement_on_planet(planet_data: Dictionary, current_settlement_count: int) -> bool:
	if planet_data.get("planet_type", "") == PLANET_TYPE_ECUMENOPOLIS:
		return current_settlement_count < 1

	var max_settlements := int(planet_data.get("max_settlements", 99))
	return current_settlement_count < max_settlements


func add_infrastructure(infrastructure_id: String, infrastructure_type: String, owner_faction_id: String, storage_capacity: float = 0.0) -> void:
	infrastructures[infrastructure_id] = {
		"id": infrastructure_id,
		"type": infrastructure_type,
		"owner_faction_id": owner_faction_id,
		"storage_capacity": storage_capacity
	}


func set_holding(faction_id: String, infrastructure_id: String, resource: String, quantity: float, reserved: float = 0.0) -> void:
	for i in holdings.size():
		var row := holdings[i]
		if row["faction_id"] == faction_id and row["infrastructure_id"] == infrastructure_id and row["resource"] == resource:
			row["quantity"] = quantity
			row["reserved"] = reserved
			holdings[i] = row
			return

	holdings.append({
		"faction_id": faction_id,
		"infrastructure_id": infrastructure_id,
		"resource": resource,
		"quantity": quantity,
		"reserved": reserved
	})


func add_trade_offer(seller_faction_id: String, buyer_faction_id: String, resource: String, quantity: float, price_per_unit: float) -> void:
	trade_offers.append({
		"seller_faction_id": seller_faction_id,
		"buyer_faction_id": buyer_faction_id,
		"resource": resource,
		"quantity": quantity,
		"price_per_unit": price_per_unit
	})


func get_settlement_total(resource: String) -> float:
	var total := 0.0
	for row in holdings:
		if row["resource"] == resource:
			total += row["quantity"]
	return total


func get_owned_total(faction_id: String, resource: String) -> float:
	var total := 0.0
	for row in holdings:
		if row["faction_id"] == faction_id and row["resource"] == resource:
			total += row["quantity"]
	return total


func get_available_total(faction_id: String, resource: String) -> float:
	var total := 0.0
	for row in holdings:
		if row["faction_id"] == faction_id and row["resource"] == resource:
			total += max(0.0, row["quantity"] - row["reserved"])
	return total


func get_purchasable_total(buyer_faction_id: String, resource: String) -> float:
	var total := 0.0
	for offer in trade_offers:
		var can_buy := offer["buyer_faction_id"] == "*" or offer["buyer_faction_id"] == buyer_faction_id
		if can_buy and offer["resource"] == resource:
			total += offer["quantity"]
	return total


func get_accessible_total(faction_id: String, resource: String) -> float:
	## Accessible = own available stock + what can be purchased in this settlement.
	return get_available_total(faction_id, resource) + get_purchasable_total(faction_id, resource)


func get_resource_snapshot(resource: String) -> Dictionary:
	var by_faction := {}
	for row in holdings:
		if row["resource"] != resource:
			continue
		var faction_id := row["faction_id"]
		if not by_faction.has(faction_id):
			by_faction[faction_id] = 0.0
		by_faction[faction_id] += row["quantity"]

	return {
		"resource": resource,
		"planet": planet["name"],
		"settlement": settlement["name"],
		"settlement_total": get_settlement_total(resource),
		"by_faction": by_faction
	}


func get_capital_rule_snapshot(current_settlement_count: int) -> Dictionary:
	return {
		"planet": planet["name"],
		"planet_type": planet["planet_type"],
		"current_settlement_count": current_settlement_count,
		"can_add_another_settlement": can_add_settlement_on_planet(planet, current_settlement_count)
	}


static func build_capital_example() -> SettlementModelTemplate:
	var model := SettlementModelTemplate.new()

	## Faction A owns Capital and controls the giant settlement.
	model.add_infrastructure("infra_storage_faction_a_core", "storage", "faction_a", 100000.0)
	model.add_infrastructure("infra_farm_import_hub", "storage", "faction_a", 50000.0)

	## Commercial faction owns separate storage + weapons factory inside the same settlement.
	model.add_infrastructure("infra_storage_faction_b", "storage", "faction_b", 40000.0)
	model.add_infrastructure("infra_factory_faction_b", "military_factory", "faction_b", 5000.0)

	## Example ownership split in one settlement:
	## - Faction A has 5 food in its own storage.
	## - Faction B has 3 food in its own storage.
	model.set_holding("faction_a", "infra_storage_faction_a_core", RESOURCE_FOOD, 5.0)
	model.set_holding("faction_b", "infra_storage_faction_b", RESOURCE_FOOD, 3.0)

	## Additional strategic stock relevant to Capital scale.
	model.set_holding("faction_a", "infra_farm_import_hub", RESOURCE_ORGANIC_MATTER, 1800.0, 1200.0)
	model.set_holding("faction_b", "infra_factory_faction_b", RESOURCE_WEAPONS, 220.0, 40.0)

	## Faction B can sell goods to Faction A.
	model.add_trade_offer("faction_b", "faction_a", RESOURCE_FOOD, 2.0, 4.0)
	model.add_trade_offer("faction_b", "faction_a", RESOURCE_WEAPONS, 180.0, 12.0)

	return model
