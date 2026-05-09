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

# -- Resource Stockpiles (per GDD s4.3.7, s4.3.8) ----------------------------

@export var rice_stockpile: float = 0.0
@export var koku_stockpile: float = 0.0

# -- Population (PU breakdown per GDD s4.3.7) ---------------------------------

@export var population_pu: int = 0
@export var farming_pu: int = 0
@export var mining_pu: int = 0
@export var town_pu: int = 0
@export var military_pu: int = 0
@export var garrison_pu: int = 0

# -- Wall Tower fields (Fortification Settlement only, per GDD s2.4.2) --------
# Structural Integrity: 0 (breached) to 10 (pristine). Non-wall settlements
# leave this at the default 10 and never mutate it.
@export var wall_si: int = 10
# Jade stockpile at Tower level (separate from clan jade reserve, per s2.4.15).
@export var jade_stockpile: float = 0.0


func has_infrastructure(feature: String) -> bool:
	return feature in infrastructure


func is_military() -> bool:
	return settlement_type in Enums.MILITARY_SETTLEMENT_TYPES


func is_religious() -> bool:
	return settlement_type in Enums.RELIGIOUS_SETTLEMENT_TYPES
