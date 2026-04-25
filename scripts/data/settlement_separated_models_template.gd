extends RefCounted
class_name SettlementSeparatedModelsTemplate

## Template-only script.
## Purpose: show a separated data model where canon geography and runtime economy
## are stored independently and linked by IDs.
##
## This mirrors the style of canon data scripts (const arrays of dictionaries)
## while keeping mutable ownership/asset state in dedicated runtime collections.

const PLANETARY_TYPE_ECUMENOPOLIS := "Ecumenopolis"

## ---------------------------------------------------------------------------
## 1) CANON GEOGRAPHY (static/reference data)
## ---------------------------------------------------------------------------
## Keep this style close to `canon_systems.gd` and `canon_planets.gd`.
## These entries describe map/lore placement, not mutable economy state.

const CANON_SYSTEMS: Array[Dictionary] = [
	{
		"system_id": "system_capital",
		"system_name": "Capital",
		"region": "Core Worlds",
		"position": Vector2(0.00, 0.00),
		"lanes": ["Perlemian Trade Route", "Corellian Run"],
		"planet_ids": ["planet_capital"],
	},
]

const CANON_PLANETS: Array[Dictionary] = [
	{
		"planet_id": "planet_capital",
		"name": "Capital",
		"planetary_type": PLANETARY_TYPE_ECUMENOPOLIS,
		"system_id": "system_capital",
		"max_settlements": 1,
	},
]


## ---------------------------------------------------------------------------
## 2) RUNTIME STATE (mutable gameplay/economy data)
## ---------------------------------------------------------------------------
## This section is intentionally separate from canon geography.
## It contains ownership, infrastructures, resources, contracts/offers.

const SETTLEMENTS: Array[Dictionary] = [
	{
		"settlement_id": "settlement_capital_global",
		"planet_id": "planet_capital",
		"owner_faction_id": "faction_a",
		"name": "Galactic City",
		"is_giant_settlement": true,
		"population": {
			"free": 1000000,
			"slave": 0,
		},
		"happiness": 18,
		"stability": 16,
	},
]

const INFRASTRUCTURES: Array[Dictionary] = [
	{
		"infrastructure_id": "infra_storage_faction_a_core",
		"settlement_id": "settlement_capital_global",
		"owner_faction_id": "faction_a",
		"type": "storage",
		"storage_capacity": 100000.0,
	},
	{
		"infrastructure_id": "infra_storage_faction_b",
		"settlement_id": "settlement_capital_global",
		"owner_faction_id": "faction_b",
		"type": "storage",
		"storage_capacity": 40000.0,
	},
	{
		"infrastructure_id": "infra_factory_faction_b",
		"settlement_id": "settlement_capital_global",
		"owner_faction_id": "faction_b",
		"type": "military_factory",
		"storage_capacity": 5000.0,
	},
]

const HOLDINGS: Array[Dictionary] = [
	{
		"holding_id": "holding_001",
		"faction_id": "faction_a",
		"settlement_id": "settlement_capital_global",
		"infrastructure_id": "infra_storage_faction_a_core",
		"resource": "food",
		"quantity": 5.0,
		"reserved": 0.0,
	},
	{
		"holding_id": "holding_002",
		"faction_id": "faction_b",
		"settlement_id": "settlement_capital_global",
		"infrastructure_id": "infra_storage_faction_b",
		"resource": "food",
		"quantity": 3.0,
		"reserved": 0.0,
	},
	{
		"holding_id": "holding_003",
		"faction_id": "faction_b",
		"settlement_id": "settlement_capital_global",
		"infrastructure_id": "infra_factory_faction_b",
		"resource": "weapons",
		"quantity": 220.0,
		"reserved": 40.0,
	},
]

const TRADE_OFFERS: Array[Dictionary] = [
	{
		"offer_id": "offer_001",
		"settlement_id": "settlement_capital_global",
		"seller_faction_id": "faction_b",
		"buyer_faction_id": "faction_a",
		"resource": "food",
		"quantity": 2.0,
		"price_per_unit": 4.0,
	},
	{
		"offer_id": "offer_002",
		"settlement_id": "settlement_capital_global",
		"seller_faction_id": "faction_b",
		"buyer_faction_id": "faction_a",
		"resource": "weapons",
		"quantity": 180.0,
		"price_per_unit": 12.0,
	},
]


## ---------------------------------------------------------------------------
## 3) READ MODELS / HELPERS (derived views)
## ---------------------------------------------------------------------------
## The game can compute read-friendly nested views from separated collections.

static func can_add_settlement(planet: Dictionary, current_settlement_count: int) -> bool:
	if planet.get("planetary_type", "") == PLANETARY_TYPE_ECUMENOPOLIS:
		return current_settlement_count < 1

	var max_settlements := int(planet.get("max_settlements", 99))
	return current_settlement_count < max_settlements


static func build_runtime_indices() -> Dictionary:
	var settlements_by_id := {}
	for settlement in SETTLEMENTS:
		settlements_by_id[settlement["settlement_id"]] = settlement

	var infrastructures_by_settlement := {}
	for infra in INFRASTRUCTURES:
		var settlement_id: String = infra["settlement_id"]
		if not infrastructures_by_settlement.has(settlement_id):
			infrastructures_by_settlement[settlement_id] = []
		infrastructures_by_settlement[settlement_id].append(infra)

	var holdings_by_settlement := {}
	for holding in HOLDINGS:
		var settlement_id: String = holding["settlement_id"]
		if not holdings_by_settlement.has(settlement_id):
			holdings_by_settlement[settlement_id] = []
		holdings_by_settlement[settlement_id].append(holding)

	return {
		"settlements_by_id": settlements_by_id,
		"infrastructures_by_settlement": infrastructures_by_settlement,
		"holdings_by_settlement": holdings_by_settlement,
	}


static func get_settlement_resource_total(settlement_id: String, resource: String) -> float:
	var total := 0.0
	for holding in HOLDINGS:
		if holding["settlement_id"] == settlement_id and holding["resource"] == resource:
			total += holding["quantity"]
	return total


static func get_faction_resource_total_in_settlement(settlement_id: String, faction_id: String, resource: String) -> float:
	var total := 0.0
	for holding in HOLDINGS:
		if holding["settlement_id"] != settlement_id:
			continue
		if holding["faction_id"] != faction_id:
			continue
		if holding["resource"] != resource:
			continue
		total += holding["quantity"]
	return total


static func build_system_planet_settlement_view() -> Array[Dictionary]:
	## Optional nested read model for UI/debug:
	## system -> planets -> settlements
	var settlements_by_planet := {}
	for settlement in SETTLEMENTS:
		var planet_id: String = settlement["planet_id"]
		if not settlements_by_planet.has(planet_id):
			settlements_by_planet[planet_id] = []
		settlements_by_planet[planet_id].append(settlement)

	var planets_by_system := {}
	for planet in CANON_PLANETS:
		var system_id: String = planet["system_id"]
		if not planets_by_system.has(system_id):
			planets_by_system[system_id] = []
		var planet_copy := planet.duplicate(true)
		planet_copy["settlements"] = settlements_by_planet.get(planet["planet_id"], [])
		planets_by_system[system_id].append(planet_copy)

	var view: Array[Dictionary] = []
	for system_data in CANON_SYSTEMS:
		var system_copy := system_data.duplicate(true)
		system_copy["planets"] = planets_by_system.get(system_data["system_id"], [])
		view.append(system_copy)

	return view
