extends RefCounted
class_name LocationAndElementStateTemplate

## Template-only script.
## Purpose: demonstrate a scalable split between:
## 1) Location graph (where things are)
## 2) Element state (what things currently have)
##
## Example target: Capital.


## ---------------------------------------------------------------------------
## 1) LOCATION GRAPH (mostly static / canon-like)
## ---------------------------------------------------------------------------
## system -> planets -> elements
## Elements can be settlements, districts, sites, or any planet-level node.
## In this Capital example, there is intentionally only ONE element for the
## planet (Galactic City). Any internal subdivision is modeled through
## infrastructures/state, not additional city-level elements.

const LOCATION_SYSTEMS: Array[Dictionary] = [
	{
		"system_id": "system_capital",
		"system_name": "Capital",
		"region": "Core Worlds",
		"position": Vector2(0.00, 0.00),
		"planet_ids": ["planet_capital"],
		"lanes": ["Perlemian Trade Route", "Corellian Run"],
	},
]

const LOCATION_PLANETS: Array[Dictionary] = [
	{
		"planet_id": "planet_capital",
		"system_id": "system_capital",
		"planet_name": "Capital",
		"planetary_type": "Ecumenopolis",
		"max_settlements": 1,
		"element_ids": [
			"element_capital_galactic_city",
		],
	},
]

const LOCATION_ELEMENTS: Array[Dictionary] = [
	{
		"element_id": "element_capital_galactic_city",
		"planet_id": "planet_capital",
		"element_type": "settlement",
		"element_name": "Galactic City",
		"tags": ["capital", "giant_settlement"],
	},
]


## ---------------------------------------------------------------------------
## 2) ELEMENT STATE (mutable gameplay/economy)
## ---------------------------------------------------------------------------
## This layer is keyed by element_id. It can grow without changing location shape.

const ELEMENT_STATE: Array[Dictionary] = [
	{
		"element_id": "element_capital_galactic_city",
		"owner_faction_id": "faction_a",
		"population": {"free": 1000000, "slave": 0},
		"happiness": 18,
		"stability": 16,
		"infrastructure_ids": [
			"infra_city_storage_faction_a",
			"infra_city_factory_faction_b",
			"infra_city_underlevels_arcology",
		],
		"resource_holdings": [
			{"faction_id": "faction_a", "resource": "food", "quantity": 3000.0, "reserved": 900.0},
			{"faction_id": "faction_a", "resource": "organic_matter", "quantity": 1800.0, "reserved": 1200.0},
			{"faction_id": "faction_b", "resource": "weapons", "quantity": 220.0, "reserved": 40.0},
		],
		"trade_offers": [
			{"seller_faction_id": "faction_b", "buyer_faction_id": "faction_a", "resource": "weapons", "quantity": 180.0, "price_per_unit": 12.0},
		],
	},
]

const INFRASTRUCTURES: Array[Dictionary] = [
	{
		"infrastructure_id": "infra_city_storage_faction_a",
		"element_id": "element_capital_galactic_city",
		"owner_faction_id": "faction_a",
		"type": "storage",
		"storage_capacity": 100000.0,
	},
	{
		"infrastructure_id": "infra_city_factory_faction_b",
		"element_id": "element_capital_galactic_city",
		"owner_faction_id": "faction_b",
		"type": "military_factory",
		"storage_capacity": 5000.0,
	},
	{
		"infrastructure_id": "infra_city_underlevels_arcology",
		"element_id": "element_capital_galactic_city",
		"owner_faction_id": "faction_a",
		"type": "arcology_block",
		"storage_capacity": 15000.0,
	},
]


## ---------------------------------------------------------------------------
## 3) HELPERS (read models)
## ---------------------------------------------------------------------------

static func build_location_view() -> Array[Dictionary]:
	var elements_by_planet := {}
	for element in LOCATION_ELEMENTS:
		var planet_id: String = element["planet_id"]
		if not elements_by_planet.has(planet_id):
			elements_by_planet[planet_id] = []
		elements_by_planet[planet_id].append(element)

	var planets_by_system := {}
	for planet in LOCATION_PLANETS:
		var system_id: String = planet["system_id"]
		if not planets_by_system.has(system_id):
			planets_by_system[system_id] = []
		var planet_copy := planet.duplicate(true)
		planet_copy["elements"] = elements_by_planet.get(planet["planet_id"], [])
		planets_by_system[system_id].append(planet_copy)

	var view: Array[Dictionary] = []
	for system_data in LOCATION_SYSTEMS:
		var system_copy := system_data.duplicate(true)
		system_copy["planets"] = planets_by_system.get(system_data["system_id"], [])
		view.append(system_copy)

	return view


static func get_element_state(element_id: String) -> Dictionary:
	for row in ELEMENT_STATE:
		if row["element_id"] == element_id:
			return row
	return {}


static func get_total_resource_in_element(element_id: String, resource: String) -> float:
	var element_state := get_element_state(element_id)
	if element_state.is_empty():
		return 0.0

	var total := 0.0
	for holding in element_state.get("resource_holdings", []):
		if holding["resource"] == resource:
			total += float(holding["quantity"])
	return total


static func build_capital_example_snapshot() -> Dictionary:
	var location := build_location_view()
	var city_food_total := get_total_resource_in_element("element_capital_galactic_city", "food")
	var city_weapons_total := get_total_resource_in_element("element_capital_galactic_city", "weapons")

	return {
		"location": location,
		"state_example": {
			"element": "element_capital_galactic_city",
			"food_total": city_food_total,
			"weapons_total": city_weapons_total,
		},
	}
