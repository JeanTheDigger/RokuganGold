class_name SettlementData
extends Resource
## Data model for a settlement per GDD s2.3. Holds type, infrastructure,
## and garrison info. Settlements exist within provinces.

@export var settlement_id: int = -1
@export var settlement_name: String = ""
@export var province_id: int = -1
@export var settlement_type: Enums.SettlementType = Enums.SettlementType.VILLAGE
@export var description: String = ""

# -- Infrastructure (named features present) -----------------------------------

@export var infrastructure: Array[String] = []

# -- Military ------------------------------------------------------------------

@export var garrison_capacity: int = 0
@export var current_garrison: int = 0

# -- Population ----------------------------------------------------------------

@export var population_pu: int = 0


func has_infrastructure(feature: String) -> bool:
	return feature in infrastructure


func is_military() -> bool:
	return settlement_type in Enums.MILITARY_SETTLEMENT_TYPES


func is_religious() -> bool:
	return settlement_type in Enums.RELIGIOUS_SETTLEMENT_TYPES
