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

@export var adjacent_province_ids: Array = []
@export var is_coastal: bool = false
@export var rivers: Array = []
@export var roads: Array = []
@export var terrain_type: Enums.TerrainType = Enums.TerrainType.PLAINS

# -- Settlements ---------------------------------------------------------------

@export var settlement_ids: Array = []

# -- Stability (used by NPC engine, s55.3) -------------------------------------

@export var stability: float = 100.0
@export var active_crisis_id: int = -1
@export var active_insurgency_id: int = -1
@export var province_taint_level: float = 0.0
@export var last_report_ic_day: int = -1
@export var grand_ritual_devastated: bool = false

# -- Miya's Blessing tracking (s11.5b) -----------------------------------------
# IC year of the most recent Miya's Blessing received. -1 = never blessed.
# Used by the Need Score calculation: +2 rotation bonus when no Blessing in
# the last two years, -5 malus when blessed last year.
@export var last_blessed_ic_year: int = -1

# -- Shadowlands Strength (per GDD s2.4.10) ------------------------------------
# Per-province SS value for Shadowlands-adjacent wall provinces. 0 = inactive
# (non-wall provinces). Accumulates passively; reduced only by sorties.
@export var shadowlands_strength: int = 0

# -- Terrain Multipliers (s4.3) -----------------------------------------------

func get_rice_multiplier() -> float:
	if Enums.TERRAIN_RICE_MULTIPLIER.has(terrain_type):
		return Enums.TERRAIN_RICE_MULTIPLIER[terrain_type]
	return 1.0
