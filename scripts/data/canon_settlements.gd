extends RefCounted
class_name CanonSettlementData

# Canon settlement-specific data split from canon_systems.gd so settlement
# stats and infrastructure are easier to locate and maintain.
#
# Resource/infrastructure model reference (from design brief):
# - Farms -> organic_matter (food chain input)
# - Workshops -> luxurious_goods (happiness input)
# - Mines -> minerals / rare_minerals
# - Foundries -> metals / rare_metals
# - Military factories -> military_equipment
# - Droid manufactories -> military/security/pleasure_droids
# - Shipyards -> ships
# - Storages are faction-bound and required for distribution logistics.

const INFRASTRUCTURE_TYPES: Dictionary = {
	"housing": {
		"label": "Housing Infrastructure",
		"role": "population_capacity",
	},
	"pleasure": {
		"label": "Pleasure Infrastructure",
		"role": "happiness_generation",
	},
	"mining": {
		"label": "Mining Infrastructure",
		"role": "raw_material_extraction",
		"produces": ["minerals", "rare_minerals"],
	},
	"foundry": {
		"label": "Foundry Infrastructure",
		"role": "material_refining",
		"consumes": ["minerals", "rare_minerals"],
		"produces": ["metals", "rare_metals"],
	},
	"workshop": {
		"label": "Workshop Infrastructure",
		"role": "luxury_production",
		"produces": ["luxurious_goods"],
	},
	"industry_droid_manufactory": {
		"label": "Droid Manufactory",
		"role": "droid_production",
		"produces": ["military_droids", "security_droids", "pleasure_droids"],
	},
	"industry_military_equipment": {
		"label": "Military Equipment Factory",
		"role": "military_output",
		"consumes": ["metals", "rare_metals"],
		"produces": ["military_equipment"],
	},
	"industry_shipyard": {
		"label": "Shipyard",
		"role": "naval_output",
		"consumes": ["metals", "rare_metals", "navy_crew"],
		"produces": ["ships"],
	},
	"garrison": {
		"label": "Garrison Infrastructure",
		"role": "defense_and_stability",
	},
	"administrative": {
		"label": "Administrative Infrastructure",
		"role": "efficiency_governance",
	},
	"storage": {
		"label": "Storage Infrastructure",
		"role": "logistics_and_stockpiling",
	},
	"spaceport": {
		"label": "Spaceport Infrastructure",
		"role": "spaceship_hosting_and_trade",
	},
}

const CORUSCANT_ELEMENTS: Array[Dictionary] = [
	{
		"element_id": "element_coruscant_galactic_city",
		"element_type": "settlement",
		"element_name": "Galactic City",
		"owner_faction_id": "faction_republic",
		"is_giant_settlement": true,
		"population": {"free": 1000000, "slave": 0},
		"happiness": 18,
		"stability": 16,
		"infrastructure_ids": [
			"infra_city_storage_republic",
			"infra_city_factory_kuat_arms",
			"infra_city_underlevels_arcology",
		],
		"resource_holdings": [
			{"faction_id": "faction_republic", "resource": "food", "quantity": 3000.0, "reserved": 900.0},
			{"faction_id": "faction_republic", "resource": "organic_matter", "quantity": 1800.0, "reserved": 1200.0},
			{"faction_id": "faction_kuat_arms", "resource": "weapons", "quantity": 220.0, "reserved": 40.0},
		],
		"trade_offers": [
			{"seller_faction_id": "faction_kuat_arms", "buyer_faction_id": "faction_republic", "resource": "weapons", "quantity": 180.0, "price_per_unit": 12.0},
		],
	},
]

const CORUSCANT_INFRASTRUCTURES: Array[Dictionary] = [
	{
		"infrastructure_id": "infra_city_storage_republic",
		"element_id": "element_coruscant_galactic_city",
		"owner_faction_id": "faction_republic",
		"type": "storage",
		"storage_capacity": 100000.0,
	},
	{
		"infrastructure_id": "infra_city_factory_kuat_arms",
		"element_id": "element_coruscant_galactic_city",
		"owner_faction_id": "faction_kuat_arms",
		"type": "industry_military_equipment",
		"storage_capacity": 5000.0,
	},
	{
		"infrastructure_id": "infra_city_underlevels_arcology",
		"element_id": "element_coruscant_galactic_city",
		"owner_faction_id": "faction_republic",
		"type": "housing",
		"storage_capacity": 15000.0,
	},
]
