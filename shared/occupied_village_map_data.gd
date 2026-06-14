class_name OccupiedVillageMapData
extends AsciiMapData
## Variable-size occupied-village map for ASCII map missions (s56.4 — LOCKED).
## Extends AsciiMapData — inherits all tile storage, FOV, and modification ops.
## Adds village layout data: buildings, road, entry vectors, civilians, and
## population/objective slots. 31×31 is the viewport; village maps are 40×36
## (Hamlet) or 60×52 (Village).

# -- Size categories (s56.4.1) -----------------------------------------------

enum SizeCategory {
	HAMLET  = 0,  # 3-6 buildings, Strength ≤ 3
	VILLAGE = 1,  # 7-15 buildings, Strength ≤ 7
}

# -- Building types -----------------------------------------------------------

enum BuildingType {
	FARMHOUSE = 0,  # Small dwelling, 5×4 tiles
	BARN      = 1,  # Larger storage, 7×5 tiles
	HEADMAN   = 2,  # Headman's house, 7×6 tiles; leader's strongpoint (s56.4.2)
}

# -- Population placement roles (s56.4.3) -------------------------------------

enum PopRole {
	SENTRY     = 0,  # Road approach or roof/porch with view of approaches
	PATROL     = 1,  # Walking between buildings along paths
	CAMP_GROUP = 2,  # Inside a building; not visible from outside
	LEADER     = 3,  # In headman's house; 20-25% of total roster
}

# -- Objective types (s56.4.5) ------------------------------------------------
# BURN_POINT is absent — the village is province infrastructure; burning it
# destroys what the lord sent the player to protect (s56.4.5).

enum ObjType {
	KILL_LEADER     = 0,  # Leader in headman's house
	RECOVER_GOODS   = 1,  # Stolen goods in a barn or storehouse
	RESCUE_HOSTAGES = 2,  # Civilians held under guard in a specific building
	DRIVE_OUT       = 3,  # Rout threshold — no total clearance required (s56.4.5)
}

# -- Dimensional constraints (s56.4.1) ----------------------------------------

# Map dimensions [width, height] per size category.
const DIMS: Array[Vector2i] = [
	Vector2i(40, 36),  # HAMLET
	Vector2i(60, 52),  # VILLAGE
]

# Maximum insurgency Strength each size can house (s56.4.1).
const MAX_STRENGTH: Array[int] = [3, 7]

# Building count range [min, max] per size (s56.4.1).
const BUILDING_RANGE: Array[Vector2i] = [
	Vector2i(3, 6),    # HAMLET
	Vector2i(7, 15),   # VILLAGE
]

# -- Village-specific identity ------------------------------------------------
# (seed_string, width, height, tile_types, deltas, fill_rect inherited from
#  AsciiMapData. zone_id / zone_name / zone_subtype / exits also inherited but
#  unused for village maps.)

@export var size_category: int = SizeCategory.HAMLET

# River feature (s56.4.4) — 20% chance; single E-W WATER_DEEP row, road bridge.
@export var has_river: bool = false
@export var river_y: int = -1   # y row of the WATER_DEEP strip
@export var bridge_x: int = -1  # leftmost x of the road-width bridge crossing

# -- Layout data --------------------------------------------------------------

# Each building dict:
#   { id:int, lx:int, ly:int, rx:int, ry:int,
#     type:int (BuildingType), door_x:int, door_y:int, side:int (0=west,1=east) }
@export var buildings: Array = []

# Approach vectors on the map edge — player picks how to enter (s56.4.2).
# Each dict: { x:int, y:int, is_road:bool }
@export var entry_vectors: Array = []

# -- Placement data -----------------------------------------------------------

# Civilian presence — not enemies (s56.4.3).
# Each dict: { x:int, y:int, building_id:int }
@export var civilian_slots: Array = []

# Enemy combatant slots.
# Each dict: { x:int, y:int, role:int (PopRole), building_id:int }

# Objective markers.
# Each dict: { x:int, y:int, obj_type:int (ObjType), building_id:int }
@export var objective_slots: Array = []
