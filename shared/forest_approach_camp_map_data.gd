class_name ForestApproachCampMapData
extends AsciiMapData
## Two-zone forest-approach-camp map for ASCII map missions (s56.5 — LOCKED).
## Extends AsciiMapData — inherits all tile storage, FOV, and modification ops.
## Adds zone layout data: forest zone (approach) + camp clearing (objective).
## 31×31 is the viewport; maps are 40×44 (SMALL), 60×60 (MEDIUM), 80×76 (LARGE).

# -- Size categories (s56.5.1) -----------------------------------------------

enum SizeCategory {
	SMALL  = 0,  # 1-2 tents, firepit. Strength ≤ 3.
	MEDIUM = 1,  # 3-6 shelters, loose cluster. Strength ≤ 6.
	LARGE  = 2,  # 7+ structures, command tent, supply area. Strength ≤ 9.
}

# -- Shelter types (s56.5.4) --------------------------------------------------

enum ShelterType {
	SHELTER = 0,  # Basic tent — soft cover, no walls (s56.5.4).
	COMMAND = 1,  # Command tent — leader's position (s56.5.3).
	SUPPLY  = 2,  # Supply stacks area — stolen goods/stores (s56.5.4).
}

# -- Population placement roles (s56.5.3) -------------------------------------

enum PopRole {
	OUTER_SENTRY  = 0,  # Trail or forest edge. FOREST zone only.
	FOREST_PATROL = 1,  # Route through trees. FOREST zone.
	CAMP_GROUP    = 2,  # Clustered around firepits. CAMP zone.
	LEADER_GROUP  = 3,  # Command tent. CAMP zone.
}

# -- Zone identifiers ---------------------------------------------------------

enum Zone {
	FOREST = 0,
	CAMP   = 1,
}

# -- Objective types (s56.5.5) ------------------------------------------------
# BURN_CAMP is valid here — bandits' construction, not civilian infrastructure.

enum ObjType {
	KILL_LEADER     = 0,  # Leader in command tent (s56.5.5).
	RECOVER_GOODS   = 1,  # Near supply stacks in camp (s56.5.5).
	BURN_CAMP       = 2,  # One marker per shelter — burns easily (s56.5.5).
	RESCUE_HOSTAGES = 3,  # Tent at camp edge (s56.5.5).
}

# -- Dimensional constraints (s56.5.1) ----------------------------------------

# Map dimensions [width, height] per size category.
const DIMS: Array[Vector2i] = [
	Vector2i(40, 44),  # SMALL
	Vector2i(60, 60),  # MEDIUM
	Vector2i(80, 76),  # LARGE
]

# Maximum insurgency Strength each size can house (s56.5.1).
const MAX_STRENGTH: Array[int] = [3, 6, 9]

# Shelter count range [min, max] per size (s56.5.1).
const SHELTER_RANGE: Array[Vector2i] = [
	Vector2i(1, 2),   # SMALL
	Vector2i(3, 6),   # MEDIUM
	Vector2i(7, 10),  # LARGE
]

# -- Camp-specific identity ---------------------------------------------------
# (seed_string, width, height, tile_types, deltas, fill_rect inherited from
#  AsciiMapData.)

@export var size_category: int = SizeCategory.SMALL

# Y-row where forest ends and camp clearing begins.
@export var clearing_start_y: int = -1

# X-column of the main trail through the forest.
@export var trail_x: int = -1

# -- Layout data --------------------------------------------------------------

# Each shelter dict:
#   { id:int, lx:int, ly:int, rx:int, ry:int, type:int (ShelterType) }
# Shelters have FLOOR_DIRT footprints — no wall tiles (soft cover, s56.5.4).
@export var shelters: Array = []

# Each firepit dict: { id:int, x:int, y:int }
@export var firepits: Array = []

# Natural clearings within the forest zone.
# Each dict: { cx:int, cy:int, radius:int }
@export var forest_clearings: Array = []

# -- Stream (optional, s56.5.4) -----------------------------------------------

@export var has_stream: bool = false
@export var stream_x: int = -1  # x-column of WATER_SHALLOW running through forest

# -- Entry and population data ------------------------------------------------

# Approach vectors on map edges (s56.5.2: trail + multiple forest-edge options).
# Each dict: { x:int, y:int, is_trail:bool }
@export var entry_vectors: Array = []

# Enemy combatant slots.
# Each dict: { x:int, y:int, role:int (PopRole), zone:int (Zone) }

# Objective markers.
# Each dict: { x:int, y:int, obj_type:int (ObjType), shelter_id:int }
@export var objective_slots: Array = []
