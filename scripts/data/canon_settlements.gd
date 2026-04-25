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

const CAPITAL_ELEMENTS: Array[Dictionary] = []
const CAPITAL_INFRASTRUCTURES: Array[Dictionary] = []
