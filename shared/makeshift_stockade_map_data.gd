class_name MakeshiftStockadeMapData
extends AsciiMapData
## Single-zone makeshift stockade map for ASCII map missions (s56.7 — LOCKED).
## Extends AsciiMapData — inherits all tile storage, FOV, and modification ops.
## Single-zone structure: the entire roster occupies the interior. Player crosses
## open ground and must breach the perimeter to engage.
## 31×31 is the viewport; maps are 40×44 (SMALL), 60×60 (MEDIUM), 80×76 (LARGE).

# -- Size categories (s56.7.1) -----------------------------------------------

enum SizeCategory {
	SMALL  = 0,  # Ring of carts and debris. Strength ≤ 3.
	MEDIUM = 1,  # Timber walls, cleared interior. Strength ≤ 6.
	LARGE  = 2,  # Full improvised palisade, possibly ditch. Strength ≤ 9.
}

# -- Shelter types (s56.7) ----------------------------------------------------

enum ShelterType {
	SHELTER = 0,  # Basic tent — soft cover (s56.7.4).
	COMMAND = 1,  # Leader's position — center of stockade.
	SUPPLY  = 2,  # Stored goods area (s56.7.5: Recover Stolen Goods).
}

# -- Population roles (s56.7.3) -----------------------------------------------

enum PopRole {
	WALL_WATCHER = 0,  # Posted on perimeter walls, watching outward.
	GATE_GUARD   = 1,  # At main entrance — chokepoint defenders.
	WATCHTOWER   = 2,  # On raised platform (Medium/Large only).
	CAMP_GROUP   = 3,  # Inside near firepits — resting roster.
	LEADER_GROUP = 4,  # Center of stockade, near command shelter.
}

# -- Objective types (s56.7.5) ------------------------------------------------
# BURN_CAMP valid here — bandit construction, not civilian infrastructure.

enum ObjType {
	KILL_LEADER     = 0,
	RECOVER_GOODS   = 1,
	BURN_CAMP       = 2,
	RESCUE_HOSTAGES = 3,
}

# -- Dimensional constraints (s56.7.1) ----------------------------------------

const DIMS: Array[Vector2i] = [
	Vector2i(40, 44),  # SMALL
	Vector2i(60, 60),  # MEDIUM
	Vector2i(80, 76),  # LARGE
]

const MAX_STRENGTH: Array[int] = [3, 6, 9]

const SHELTER_RANGE: Array[Vector2i] = [
	Vector2i(1, 2),   # SMALL
	Vector2i(3, 6),   # MEDIUM
	Vector2i(7, 10),  # LARGE
]

# -- Identity -----------------------------------------------------------------

@export var size_category: int = SizeCategory.SMALL

# Perimeter bounding box: wall tiles lie ON these coordinates (inclusive).
# Interior is (perim_lx+1 .. perim_rx-1) × (perim_ty+1 .. perim_by-1).
@export var perim_lx: int = -1
@export var perim_rx: int = -1
@export var perim_ty: int = -1
@export var perim_by: int = -1

# Main gate: x-column of the south-wall gap (is_gate=true entry vector).
@export var gate_x: int = -1

# -- Optional features --------------------------------------------------------

# Ditch: WATER_SHALLOW strip immediately outside perimeter (Medium/Large).
@export var has_ditch: bool = false

# Sharpened stakes hazard. No dedicated tile — resolved mechanically.
# Present in ~40% of Medium stockades with ditch, most Large ones (s56.7.4).
@export var has_stakes: bool = false

# Raised platform/watchtower inside stockade (Medium/Large, s56.7.4).
@export var has_platform: bool = false
@export var platform_x: int = -1  # centre of platform structure
@export var platform_y: int = -1

# -- Layout data --------------------------------------------------------------

# Weak-point breaches: gaps in perimeter walls the player can exploit.
# Each dict: { x, y, side: String ("N"/"W"/"E") }
# The south wall has the gate; weak points are on the other three sides.
@export var weak_points: Array = []

# Each shelter dict: { id, lx, ly, rx, ry, type (ShelterType) }
# FLOOR_DIRT footprints — no wall tiles (soft cover, s56.7.4).
@export var shelters: Array = []

# Each firepit dict: { id, x, y }
@export var firepits: Array = []

# -- Entry and population data ------------------------------------------------

# Perimeter breaches (gate + weak points).
# Each dict: { x, y, is_gate: bool }
@export var entry_vectors: Array = []

# Enemy combatant slots.
# Each dict: { x, y, role (PopRole) }
# No zone field — single-zone template; everyone is inside or on the perimeter.
@export var population_slots: Array = []

# Objective markers.
# Each dict: { x, y, obj_type (ObjType), shelter_id: int }
@export var objective_slots: Array = []
