class_name RuinedStructureMapData
extends AsciiMapData
## Ruined-structure map for ASCII map missions (s56.12 — LOCKED).
## Extends AsciiMapData — inherits all tile storage, FOV, and modification ops.
## Architecture-then-decay: a man-made building whose walls have collapsed
## and corridors have been blocked, creating unpredictable openings.
## Intact rooms use FLOOR_STONE; collapsed sections use RUBBLE + FLOOR_DIRT.
## 31×31 is the viewport; maps are 40×44 (SMALL_RUIN), 60×60 (MEDIUM_RUIN),
## 80×76 (LARGE_RUIN).

# -- Size categories (s56.12.2) -----------------------------------------------

enum SizeCategory {
	SMALL_RUIN  = 0,  # 1–2 intact rooms, rest rubble. Strength ≤ 3.
	MEDIUM_RUIN = 1,  # Multi-room compound, partial upper floors possible. Strength ≤ 6.
	LARGE_RUIN  = 2,  # Former fortification complex; always has upper floor. Strength ≤ 9.
}

# -- Ruin origin (s56.12.1) ---------------------------------------------------

enum RuinOrigin {
	WAR_DAMAGE      = 0,  # Destroyed in past clan conflict — scorch marks.
	FAMINE          = 1,  # Abandoned when province PU collapsed — left belongings.
	TAINT_CORRUPTION = 2, # PTL drove inhabitants out — spiritual hazard possible.
	PEASANT_REVOLT  = 3,  # Sacked in uprising — fire damage, broken furniture.
	NATURAL_DECAY   = 4,  # Lightning, accident, or time — generic collapse.
}

# -- Population placement roles (s56.12.4) ------------------------------------

enum PopRole {
	SENTRY             = 0,  # At or near main entrance; possibly elevated.
	ROOM_GROUP         = 1,  # Clustered in intact rooms (2–4 per occupied room).
	RUBBLE_LURKER      = 2,  # In collapsed sections — ambush position.
	UPPER_FLOOR_HOLDER = 3,  # On surviving upper level; ranged advantage.
	LEADER_GROUP       = 4,  # Most defensible intact room (fewest gaps, one door).
}

# -- Zone identifiers ---------------------------------------------------------

enum Zone {
	INTACT_ROOM  = 0,  # Walled room with surviving floor and partial roof.
	COLLAPSED    = 1,  # Rubble-filled open section between surviving rooms.
	UPPER_FLOOR  = 2,  # Elevated surviving section accessible by stairwell.
}

# -- Objective types (s56.12.6) ------------------------------------------------

enum ObjType {
	KILL_LEADER     = 0,  # In most defensible intact room.
	RECOVER_GOODS   = 1,  # Most structurally sound room (storage/cellar).
	BURN_CAMP       = 2,  # One marker per occupied intact room.
	RESCUE_HOSTAGES = 3,  # Inner room, limited access (improvised cell).
	INVESTIGATE     = 4,  # Unique to this template — origin-specific evidence.
}

# -- Dimensional constraints (s56.12.2) ----------------------------------------

const DIMS: Array[Vector2i] = [
	Vector2i(40, 44),  # SMALL_RUIN
	Vector2i(60, 60),  # MEDIUM_RUIN
	Vector2i(80, 76),  # LARGE_RUIN
]

const MAX_STRENGTH: Array[int] = [3, 6, 9]

const ROOM_RANGE: Array[Vector2i] = [
	Vector2i(2, 4),   # SMALL_RUIN  (2×2 grid = 4 cells, 2 collapse range)
	Vector2i(5, 9),   # MEDIUM_RUIN (3×3 grid = 9 cells, 5 collapse range)
	Vector2i(8, 16),  # LARGE_RUIN  (4×4 grid = 16 cells, 8 collapse range)
]

# -- Identity -----------------------------------------------------------------

@export var size_category: int = SizeCategory.SMALL_RUIN
@export var ruin_origin: int = RuinOrigin.NATURAL_DECAY

# Outer perimeter wall bounds (inclusive; outer wall tiles sit ON these rows/cols).
@export var struct_lx: int = -1
@export var struct_rx: int = -1
@export var struct_ty: int = -1
@export var struct_by: int = -1

# Room grid dimensions.
@export var grid_cols: int = -1
@export var grid_rows: int = -1

# Main entrance: gap in south outer wall at (entrance_x, struct_by).
@export var entrance_x: int = -1

# -- Layout data --------------------------------------------------------------

# Intact rooms surviving after decay.
# Each dict: { id, lx, ly, rx, ry, is_inner, is_leader_room, is_storage_room }
# lx..rx and ly..ry are the room FLOOR bounds (inner edge of walls).
# is_inner: no direct opening to outside (only accessible via other rooms).
# is_leader_room: the most defensible room — leader lives here.
# is_storage_room: most structurally sound — goods stored here.
@export var rooms: Array = []

# Collapsed sections: former rooms now open rubble fields.
# Each dict: { id, lx, ly, rx, ry }
@export var collapsed_sections: Array = []

# Wall gaps: alternate entries punched through outer perimeter (s56.12.3).
# Each dict: { x, y, side ("N"/"S"/"E"/"W") }
@export var wall_gaps: Array = []

# Firepits: { id, x, y }  — campsites in occupied rooms.
@export var firepits: Array = []

# Upper floor sections (MEDIUM/LARGE only, s56.12.3).
@export var has_upper_floor: bool = false
# Each dict: { lx, ly, rx, ry, room_id }  — FLOOR_STONE elevated area in a room.
@export var upper_floor_sections: Array = []
# Stairwells: narrow FLOOR_STONE column; chokepoint for upper floor access.
# Each dict: { x, y, room_id }
@export var stairwells: Array = []

# Unstable sections: on verge of further collapse (s56.12.5).
# Each dict: { lx, ly, rx, ry }
@export var unstable_sections: Array = []

# -- Entry and population data ------------------------------------------------

# Entry vectors: main entrance + wall gaps get ZONE_EXIT tiles.
# Each dict: { x, y, is_main, is_gap }
@export var entry_vectors: Array = []

# Enemy combatant slots.
# Each dict: { x, y, role (PopRole), zone (Zone), room_id }
# room_id = -1 for collapsed/rim positions.
@export var population_slots: Array = []

# Objective markers.
# Each dict: { x, y, obj_type (ObjType), room_id }
@export var objective_slots: Array = []
