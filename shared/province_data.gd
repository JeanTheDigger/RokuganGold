class_name ProvinceData
extends Resource
## Data model for a province per GDD s2.3. Holds geography, settlements,
## adjacency, and resource stockpiles. No simulation logic here.

@export var province_id: int = -1
@export var province_name: String = ""
@export var clan: String = ""
@export var family: String = ""
@export var description: String = ""

# -- Geography -----------------------------------------------------------------

@export var adjacent_province_ids: Array[int] = []
@export var is_coastal: bool = false
@export var rivers: Array[String] = []
@export var roads: Array[String] = []
@export var terrain_type: Enums.TerrainType = Enums.TerrainType.PLAINS

# -- Settlements ---------------------------------------------------------------

@export var settlement_ids: Array[int] = []

# -- Population ----------------------------------------------------------------

@export var population_pu: int = 0
@export var farming_pu: int = 0
@export var mining_pu: int = 0
@export var town_pu: int = 0
@export var military_pu: int = 0

# -- Stability (used by NPC engine, s55.3) -------------------------------------

@export var stability: float = 100.0
@export var active_crisis_id: int = -1
@export var active_insurgency_id: int = -1
@export var garrison_pu: int = 0
@export var province_taint_level: float = 0.0
@export var last_report_ic_day: int = -1

# -- Terrain Multipliers (s4.3) -----------------------------------------------

func get_rice_multiplier() -> float:
	if Enums.TERRAIN_RICE_MULTIPLIER.has(terrain_type):
		return Enums.TERRAIN_RICE_MULTIPLIER[terrain_type]
	return 1.0
