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
## s4.3:461 mine quality designation (LOCKED in principle, multipliers PROVISIONAL).
## STANDARD (x1.0) is the baseline; RICH (x1.5) / MARGINAL (x0.5) are world-gen
## designations. Never degrades (s4.3:473).
@export var mine_quality: Enums.MineQuality = Enums.MineQuality.STANDARD

# -- Settlements ---------------------------------------------------------------

@export var settlement_ids: Array = []

# -- Stability (used by NPC engine, s55.3) -------------------------------------

@export var stability: float = 100.0
@export var active_crisis_id: int = -1
@export var crisis_type: String = ""
## Current starvation stage (ResourceTick.StarvationStage: 0 CLEAR / 1 SHORTAGE /
## 2 HUNGER / 3 FAMINE), published each seasonal tick by ResourceTick. The NPC
## engine reads this for the real severity instead of a crisis_type proxy.
@export var starvation_stage: int = 0
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

# -- Spell-induced Weather (s31-37a) -------------------------------------------
# Set by WEATHER_SHIFT spells (endless_deluge, breath_of_mist).
# Uses AsciiMapEnvironment.WeatherState int values. 0 = CLEAR (no active spell).
# Expires at province_weather_expires_ic_day; cleared by _expire_province_weather().
@export var province_weather_state: int = 0
@export var province_weather_expires_ic_day: int = -1

# -- Terrain Multipliers (s4.3) -----------------------------------------------

func get_rice_multiplier() -> float:
	if Enums.TERRAIN_RICE_MULTIPLIER.has(terrain_type):
		return Enums.TERRAIN_RICE_MULTIPLIER[terrain_type]
	return 1.0


## s4.3:455-471 mine quality modifier for the Iron formula
## (mining PU x 0.50 x modifier). Defaults to STANDARD (x1.0), so an
## undesignated province behaves exactly as before; world-gen designates
## RICH / MARGINAL provinces as a data edit.
func get_mine_quality_multiplier() -> float:
	if Enums.MINE_QUALITY_MULTIPLIER.has(mine_quality):
		return Enums.MINE_QUALITY_MULTIPLIER[mine_quality]
	return 1.0
