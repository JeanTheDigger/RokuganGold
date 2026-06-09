class_name RavineCampMapData
extends AsciiMapData
## Linear ravine-camp map for ASCII map missions (s56.11 — LOCKED).
## Extends AsciiMapData — inherits all tile storage, FOV, and modification ops.
## Three traversable zones: ravine floor (FLOOR_DIRT), ravine walls (WALL_STONE
## — impassable natural rock), rim (FLOOR_GRASS — walkable high ground).
## Player approaches from south (ravine mouth) or along the rim.
## 31×31 is the viewport; maps are 40×44 (NARROW_GULLY), 60×60 (RAVINE),
## 80×76 (CANYON).

# -- Size categories (s56.11.1) -----------------------------------------------

enum SizeCategory {
	NARROW_GULLY = 0,  # Short tight cut, 1 chokepoint, dead end. Strength ≤ 3.
	RAVINE       = 1,  # Longer gorge, 2 chokepoints. Strength ≤ 6.
	CANYON       = 2,  # Extended, 3 chokepoints, always back exit. Strength ≤ 9.
}

# -- Shelter types ------------------------------------------------------------

enum ShelterType {
	SHELTER = 0,  # Basic tent — soft cover.
	COMMAND = 1,  # Leader's position — deepest wide section.
	SUPPLY  = 2,  # Stored goods area.
}

# -- Population placement roles (s56.11.3) ------------------------------------

enum PopRole {
	MOUTH_GUARD       = 0,  # At ravine entrance — holds the first narrow.
	CHOKEPOINT_HOLDER = 1,  # Interior narrow sections — layered defense.
	CAMP_GROUP        = 2,  # Wide sections between chokepoints.
	LEADER_GROUP      = 3,  # Deepest wide section; near back exit if one exists.
	RIM_WATCHER       = 4,  # On rim above camp — watches for rim-approach players.
}

# -- Zone identifiers ---------------------------------------------------------

enum Zone {
	RAVINE_FLOOR = 0,  # Inside the ravine (floor + narrowed chokepoint walls).
	RIM          = 1,  # Walkable high ground outside the ravine walls.
}

# -- Objective types (s56.11.5) ------------------------------------------------

enum ObjType {
	KILL_LEADER     = 0,  # Deepest section; escapes through back exit if possible.
	RECOVER_GOODS   = 1,  # Middle section — kept accessible from mouth.
	BURN_CAMP       = 2,  # One marker per shelter.
	RESCUE_HOSTAGES = 3,  # Deep section — requires breaching all chokepoints.
}

# -- Dimensional constraints (s56.11.1) ----------------------------------------

const DIMS: Array[Vector2i] = [
	Vector2i(40, 44),  # NARROW_GULLY
	Vector2i(60, 60),  # RAVINE
	Vector2i(80, 76),  # CANYON
]

const MAX_STRENGTH: Array[int] = [3, 6, 9]

const SHELTER_RANGE: Array[Vector2i] = [
	Vector2i(1, 2),   # NARROW_GULLY
	Vector2i(3, 6),   # RAVINE
	Vector2i(7, 10),  # CANYON
]

# -- Identity -----------------------------------------------------------------

@export var size_category: int = SizeCategory.NARROW_GULLY

# Ravine wall left edge (= rim_w), right wall right edge (= width - rim_w - 1).
# Left rim: x = 0 .. wall_lx-1  (FLOOR_GRASS).
# Left wall: x = wall_lx .. floor_lx-1  (WALL_STONE).
@export var wall_lx: int = -1
@export var wall_rx: int = -1

# Ravine floor x-extent between the walls.
@export var floor_lx: int = -1
@export var floor_rx: int = -1

# Centre x of ravine floor — mouth and back exit use this column.
@export var floor_cx: int = -1

# Back exit: north-edge opening (NARROW_GULLY = never, RAVINE = 40%, CANYON = always).
@export var has_back_exit: bool = false
@export var back_exit_x: int = -1

# Stream through ravine floor: WATER_SHALLOW column (optional; s56.11.4).
@export var has_stream: bool = false
@export var stream_x: int = -1

# Rim Watcher (s56.11.3): 50% for RAVINE, always for CANYON, never for NARROW_GULLY.
@export var has_rim_watcher: bool = false

# -- Layout data --------------------------------------------------------------

# Chokepoints: narrowed sections in the ravine floor.
# Each dict: { y, passage_lx, passage_rx, has_barricade, barricade_gap_x }
# passage_lx..passage_rx is the only walkable path through the narrow (FLOOR_DIRT).
# Lateral tiles within the ravine floor are filled WALL_STONE (natural jutting rock).
# has_barricade: optional WALL_WOOD row across the passage with a 1-tile gap.
@export var chokepoints: Array = []

# Wide sections between chokepoints: where the camp sits.
# Each dict: { y_top, y_bot, is_mouth_section, is_deep_section }
@export var wide_sections: Array = []

# Descent points on rim: specific positions where a player can climb down (s56.11.2).
# Each dict: { x, y, side ("L"/"R") }
# Tile at (x, y) is FLOOR_STONE (identifiable handhold / crumbled ledge).
@export var descent_points: Array = []

# Shelters in wide sections: FLOOR_DIRT footprints.
# Each dict: { id, lx, ly, rx, ry, type (ShelterType) }
@export var shelters: Array = []

# Firepits: { id, x, y }
@export var firepits: Array = []

# -- Entry and population data ------------------------------------------------

# Entry vectors: map-edge ZONE_EXIT markers.
# Each dict: { x, y, is_mouth, is_back_exit, is_rim }
# is_mouth  — south edge at floor_cx (the ravine mouth, s56.11.2).
# is_back_exit — north edge at back_exit_x (if has_back_exit).
# is_rim    — left or right edge (rim walk entry, s56.11.2).
@export var entry_vectors: Array = []

# Enemy combatant slots.
# Each dict: { x, y, role (PopRole), zone (Zone) }

# Objective markers.
# Each dict: { x, y, obj_type (ObjType) }
@export var objective_slots: Array = []
