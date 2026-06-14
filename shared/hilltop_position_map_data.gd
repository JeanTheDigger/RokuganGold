class_name HilltopPositionMapData
extends AsciiMapData
## Two-zone hilltop-position map for ASCII map missions (s56.8 — LOCKED).
## Extends AsciiMapData — inherits all tile storage, FOV, and modification ops.
## Adds zone layout data: slope zone (approach) + hilltop camp (objective).
## 31×31 is the viewport; maps are 40×44 (LOW_RISE), 60×60 (STEEP_HILL),
## 80×76 (RIDGE_BLUFF).

# -- Size categories (s56.8.1) -----------------------------------------------

enum SizeCategory {
	LOW_RISE   = 0,  # Modest hill, few shelters. Strength ≤ 3.
	STEEP_HILL = 1,  # Proper hill, good sightlines. Strength ≤ 6.
	RIDGE_BLUFF = 2, # Extended elevated position, outcrops. Strength ≤ 9.
}

# -- Slope grade (s56.8.4) ----------------------------------------------------

enum SlopeGrade {
	GENTLE   = 0,  # Faster climb, more exposed, less cover.
	MODERATE = 1,  # Balanced speed and cover.
	STEEP    = 2,  # Slower, more rocks, loose scree, louder.
}

# -- Shelter types (s56.8) ----------------------------------------------------

enum ShelterType {
	SHELTER = 0,  # Basic tent — soft cover, no walls (s56.8.4).
	COMMAND = 1,  # Leader's shelter — center of hilltop camp.
	SUPPLY  = 2,  # Supply stacks area — stored goods.
}

# -- Population placement roles (s56.8.3) -------------------------------------

enum PopRole {
	LOOKOUT       = 0,  # Partway up slope at vantage point. SLOPE zone.
	PATH_GUARD    = 1,  # Worn path near crest. SLOPE zone.
	CAMP_GROUP    = 2,  # Clustered around firepits. HILLTOP zone.
	LEADER_GROUP  = 3,  # Command shelter center. HILLTOP zone.
	EDGE_DEFENDER = 4,  # Near hilltop edge, rapid response. HILLTOP zone.
}

# -- Zone identifiers ---------------------------------------------------------

enum Zone {
	SLOPE   = 0,
	HILLTOP = 1,
}

# -- Objective types (s56.8.5) ------------------------------------------------
# BURN_CAMP valid here — bandit construction, not civilian infrastructure.

enum ObjType {
	KILL_LEADER     = 0,  # Leader in command shelter (s56.8.5).
	RECOVER_GOODS   = 1,  # Near supply area in hilltop (s56.8.5).
	BURN_CAMP       = 2,  # One marker per shelter (s56.8.5).
	RESCUE_HOSTAGES = 3,  # Shelter nearest crest edge (s56.8.5).
}

# -- Dimensional constraints (s56.8.1) ----------------------------------------

# Map dimensions [width, height] per size category.
const DIMS: Array[Vector2i] = [
	Vector2i(40, 44),  # LOW_RISE
	Vector2i(60, 60),  # STEEP_HILL
	Vector2i(80, 76),  # RIDGE_BLUFF
]

# Maximum insurgency Strength each size can house (s56.8.1).
const MAX_STRENGTH: Array[int] = [3, 6, 9]

# Shelter count range [min, max] per size (s56.8.1).
const SHELTER_RANGE: Array[Vector2i] = [
	Vector2i(1, 2),   # LOW_RISE
	Vector2i(3, 6),   # STEEP_HILL
	Vector2i(7, 10),  # RIDGE_BLUFF
]

# -- Identity -----------------------------------------------------------------

@export var size_category: int = SizeCategory.LOW_RISE

# Y-row where hilltop ends and slope begins (hilltop is above: y < crest_y).
@export var crest_y: int = -1

# X-column of the worn path up the hill.
@export var path_x: int = -1

# Grade of each face: Array of {face:String, grade:int (SlopeGrade)}.
# Faces: "S" (main approach), "N" (back), "W", "E".
@export var face_grades: Array = []

# -- Layout data --------------------------------------------------------------

# Each shelter dict: { id, lx, ly, rx, ry, type (ShelterType) }
# Shelters have FLOOR_DIRT footprints — no wall tiles (soft cover, s56.8.4).
@export var shelters: Array = []

# Each firepit dict: { id, x, y }
@export var firepits: Array = []

# -- Entry and population data ------------------------------------------------

# Approach vectors on map edges (s56.8.2: path + multiple face approaches).
# Each dict: { x, y, is_path:bool }
@export var entry_vectors: Array = []

# Enemy combatant slots.
# Each dict: { x, y, role (PopRole), zone (Zone) }

# Objective markers.
# Each dict: { x, y, obj_type (ObjType), shelter_id:int }
@export var objective_slots: Array = []
