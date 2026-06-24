class_name AsciiMapData
extends Resource
## Data model for a variable-size ASCII tile map for a single Lesser Zone (s4.4).
## 31×31 is the viewport size, not the zone size — zones vary by settlement type
## and zone type. Tiles stored flat, row-major: index = y * width + x.
## Deltas override generated tiles to persist physical changes (destroyed walls,
## new construction) without regenerating the whole map.

# -- Zone identity ------------------------------------------------------------

@export var zone_id: String = ""
@export var zone_name: String = ""
# Enums.ZoneSubtype value — determines generation algorithm
@export var zone_subtype: int = Enums.ZoneSubtype.SHRINE_CLEARING
# Seed used for deterministic generation (settlement_name + zone_name + zone_type)
@export var seed_string: String = ""

# -- Tile data ----------------------------------------------------------------

@export var width: int = 31
@export var height: int = 31

# Population slots for mission populator (filled by template generators).
# Each entry: { "x": int, "y": int, "role": int, ... }. Common to all map
# templates so MissionPopulator can operate on any AsciiMapData uniformly.
@export var population_slots: Array = []

# Hidden hazards placed by trap-laying defenders (s56.20). A data layer, not
# tiles — a HIDDEN trap renders as normal floor. Each entry is a TrapSystem
# trap dict: { "x", "y", "type", "quality", "state", "detect_tn", "disarm_tn" }.
@export var traps: Array = []

# Primary flat tile array. Each byte is an Enums.TileType value.
# Populated by AsciiMapGenerator; read-only after generation.
@export var tile_types: PackedByteArray = []

# Persistent overrides applied on top of the generated base map.
# Key: "x,y", Value: Enums.TileType int. Stored between sessions.
@export var deltas: Dictionary = {}

# Active fire layer (s56.6.6). Key: y*width+x int, Value: rounds_left int.
# A tile in this dict is set to FIRE; FireSystem ticks it down to Burned Out
# (ash) and spreads it. Empty on every non-fire mission.
@export var burning_tiles: Dictionary = {}

# Wind bearing for fire/smoke spread (s56.6.6), a unit Vector2i (e.g. (0,-1)=N).
# ZERO = no wind (Clear weather); fixed for the mission, assigned at generation.
@export var wind_dir: Vector2i = Vector2i.ZERO

# -- Depth gradient (s56.21) --------------------------------------------------
# Per-tile path-distance from the player entry tile (8-directional, over
# passable + door tiles). index = y * width + x. -1 = unreachable.
# Empty (size != width*height) means depth has not been computed for this map;
# consumers (MissionPopulator) fall back to depth-agnostic behavior.
@export var depth_grid: PackedInt32Array = []

# -- Spiritual overlap (s56.16.1b) --------------------------------------------
# Per-tile overlap intensity 0.0..1.0 (entry 0.0, heart 1.0). index = y*width+x.
# Empty (size != width*height) = no overlap on this map. Base tiles are NOT
# mutated — SpiritualPalette substitutes the *display* tile from base + intensity,
# so the overlap reverts (s56.16 "the world heals in real time") simply by
# raising restoration_progress (healing spreads outward from the heart).
@export var overlap_intensity: PackedFloat32Array = []
@export var spiritual_realm: int = Enums.SpiritRealm.GAKI_DO   # active iff event_type set
@export var spiritual_element: int = Enums.Ring.NONE
@export var spiritual_event_type: int = -1   # Enums.SpiritualEventType, -1 = no overlap
@export var overlap_max_depth: int = 0       # heart depth, for healing-from-heart
@export var restoration_progress: float = 0.0  # 0..1 ritual healing, heart outward

# -- Elevation / Z-axis (s4.4 "roofing/elevation indicators") -----------------
# Per-tile elevation level. index = y*width+x. 0 = ground; each +1 = one step up,
# ≈ 5 ft (1 level = 1 tile-height, matching MovementSystem's 1 tile = 5 ft). A
# parallel grid like depth_grid / overlap_intensity — base tile_types are NOT
# mutated. Empty (size != width*height) = a flat map (every level 0), so every
# map without an explicit elevation pass is unaffected. Cliff/fall thresholds and
# high-ground combat live in MovementSystem and the combat orchestrator; the
# numeric model was locked by the owner 2026-06-23 (s4.4 line 121 defers elevation
# to engine development — no LOCKED numbers exist).
const MAX_ELEVATION: int = 15
@export var elevation: PackedByteArray = []

# -- Stacked floors (s4.4 Option B) -------------------------------------------
# True multi-level buildings: a tile can hold a ground floor, an upper floor, and
# a roof, each its own walkable surface, connected by STAIRS tiles. Level 0 lives
# in `tile_types` (so every existing single-level map and all existing accessors
# are unchanged); levels 1.. live in `upper_levels` (one PackedByteArray per level
# above ground, `upper_levels[L-1]` = level L). A VOID tile on an upper level means
# "open air" — no structure rises here, you are looking down at the level below.
# The terrain `elevation` heightfield applies to level 0 only; upper floors are
# flat platforms (a second storey is one level up, not a ground gradient).
# Default: level_count = 1, upper_levels = [] → a flat single-level map, the state
# of every map that has not had a stacking pass, so nothing changes for them.
const MAX_LEVELS: int = 4
@export var level_count: int = 1
@export var upper_levels: Array = []   # Array[PackedByteArray], one per level > 0

# -- Zone connections ---------------------------------------------------------

# Each entry: {x:int, y:int, direction:String, target_zone_id:String}
@export var exits: Array = []

# -- Helpers ------------------------------------------------------------------

func get_tile(x: int, y: int) -> int:
	if x < 0 or x >= width or y < 0 or y >= height:
		return Enums.TileType.WALL_STONE
	var key: String = "%d,%d" % [x, y]
	if deltas.has(key):
		return deltas[key]
	if tile_types.size() != width * height:
		return Enums.TileType.VOID
	return tile_types[y * width + x]


func set_tile(x: int, y: int, tile: int) -> void:
	if x < 0 or x >= width or y < 0 or y >= height:
		return
	tile_types[y * width + x] = tile


func set_delta(x: int, y: int, tile: int) -> void:
	if x < 0 or x >= width or y < 0 or y >= height:
		return
	deltas["%d,%d" % [x, y]] = tile


func clear_delta(x: int, y: int) -> void:
	var key: String = "%d,%d" % [x, y]
	deltas.erase(key)


func init_tiles(fill: int = Enums.TileType.FLOOR_GRASS) -> void:
	var count: int = width * height
	tile_types.resize(count)
	for i in range(count):
		tile_types[i] = fill


func get_width() -> int:
	return width


func get_height() -> int:
	return height


# Returns true if the tile blocks movement (walls, closed doors, deep water,
# trees). Used by the FOV raycaster and movement validation.
static func is_passable(tile: int) -> bool:
	match tile:
		Enums.TileType.WALL_STONE, \
		Enums.TileType.WALL_WOOD, \
		Enums.TileType.WALL_PAPER, \
		Enums.TileType.WATER_DEEP, \
		Enums.TileType.TREE_EVERGREEN, \
		Enums.TileType.TREE_DECIDUOUS, \
		Enums.TileType.TREE_CHERRY, \
		Enums.TileType.TREE_DEAD, \
		Enums.TileType.BAMBOO, \
		Enums.TileType.DOOR_SHOJI_CLOSED, \
		Enums.TileType.DOOR_WOOD_CLOSED, \
		Enums.TileType.GATE_CLOSED, \
		Enums.TileType.VOID, \
		Enums.TileType.FURNITURE_HEARTH, \
		Enums.TileType.FURNITURE_CHEST, \
		Enums.TileType.FURNITURE_TABLE, \
		Enums.TileType.FURNITURE_JAR, \
		Enums.TileType.FURNITURE_BRAZIER, \
		Enums.TileType.FURNITURE_DAIS, \
		Enums.TileType.FURNITURE_WEAPON_STAND, \
		Enums.TileType.FURNITURE_ALTAR, \
		Enums.TileType.FURNITURE_OFFERING_BOX, \
		Enums.TileType.FURNITURE_INCENSE, \
		Enums.TileType.FURNITURE_STATUE, \
		Enums.TileType.FURNITURE_STALL, \
		Enums.TileType.FURNITURE_CRATE, \
		Enums.TileType.FURNITURE_WELL, \
		Enums.TileType.FURNITURE_DUMMY, \
		Enums.TileType.FURNITURE_SHELF, \
		Enums.TileType.FURNITURE_STOVE, \
		Enums.TileType.ROOF:
			return false
		_:
			return true


# Returns true if the tile blocks line of sight.
static func blocks_los(tile: int) -> bool:
	match tile:
		Enums.TileType.WALL_STONE, \
		Enums.TileType.WALL_WOOD, \
		Enums.TileType.WALL_PAPER, \
		Enums.TileType.TREE_EVERGREEN, \
		Enums.TileType.TREE_DECIDUOUS, \
		Enums.TileType.TREE_CHERRY, \
		Enums.TileType.BAMBOO, \
		Enums.TileType.DOOR_SHOJI_CLOSED, \
		Enums.TileType.DOOR_WOOD_CLOSED, \
		Enums.TileType.GATE_CLOSED, \
		Enums.TileType.FIRE, \
		Enums.TileType.FURNITURE_CHEST, \
		Enums.TileType.FURNITURE_SCREEN, \
		Enums.TileType.FURNITURE_STATUE, \
		Enums.TileType.FURNITURE_NET, \
		Enums.TileType.FURNITURE_SHELF, \
		Enums.TileType.ROOF:
			return true
		_:
			return false


# Furnishings that grant combat cover — a defender sheltering behind one gets
# +COVER_ARMOR_TN_BONUS Armor TN (s4.4 furnishings category; reuses the s40
# cover convention). Solid waist-to-chest-height objects only.
static func grants_cover(tile: int) -> bool:
	match tile:
		Enums.TileType.FURNITURE_CHEST, \
		Enums.TileType.FURNITURE_TABLE, \
		Enums.TileType.FURNITURE_JAR, \
		Enums.TileType.FURNITURE_DAIS, \
		Enums.TileType.FURNITURE_WEAPON_STAND, \
		Enums.TileType.FURNITURE_ALTAR, \
		Enums.TileType.FURNITURE_OFFERING_BOX, \
		Enums.TileType.FURNITURE_STATUE, \
		Enums.TileType.FURNITURE_STALL, \
		Enums.TileType.FURNITURE_CRATE, \
		Enums.TileType.FURNITURE_WELL, \
		Enums.TileType.FURNITURE_DUMMY, \
		Enums.TileType.FURNITURE_SHELF:
			return true
		_:
			return false


# -- Door operations ----------------------------------------------------------

const _DOOR_PAIRS: Dictionary = {
	Enums.TileType.DOOR_SHOJI_CLOSED: Enums.TileType.DOOR_SHOJI_OPEN,
	Enums.TileType.DOOR_SHOJI_OPEN:   Enums.TileType.DOOR_SHOJI_CLOSED,
	Enums.TileType.DOOR_WOOD_CLOSED:  Enums.TileType.DOOR_WOOD_OPEN,
	Enums.TileType.DOOR_WOOD_OPEN:    Enums.TileType.DOOR_WOOD_CLOSED,
	Enums.TileType.GATE_CLOSED:       Enums.TileType.GATE_OPEN,
	Enums.TileType.GATE_OPEN:         Enums.TileType.GATE_CLOSED,
}


static func is_door(tile: int) -> bool:
	return _DOOR_PAIRS.has(tile)


func toggle_door(x: int, y: int) -> bool:
	var tile: int = get_tile(x, y)
	if not _DOOR_PAIRS.has(tile):
		return false
	set_delta(x, y, _DOOR_PAIRS[tile])
	return true


# -- Tile destruction ---------------------------------------------------------
# s4.4: shoji "can be cut through … destroyed in one action."
# Paper walls and shoji doors are fragile; wood walls require force; stone is
# indestructible under normal circumstances. Returns the replacement tile type,
# or -1 if the tile cannot be destroyed.

const _DESTRUCTION_MAP: Dictionary = {
	Enums.TileType.WALL_PAPER:        Enums.TileType.RUBBLE,
	Enums.TileType.DOOR_SHOJI_CLOSED: Enums.TileType.RUBBLE,
	Enums.TileType.DOOR_SHOJI_OPEN:   Enums.TileType.RUBBLE,
	Enums.TileType.WALL_WOOD:         Enums.TileType.RUBBLE,
	Enums.TileType.DOOR_WOOD_CLOSED:  Enums.TileType.RUBBLE,
	Enums.TileType.DOOR_WOOD_OPEN:    Enums.TileType.RUBBLE,
	Enums.TileType.BAMBOO:            Enums.TileType.FLOOR_GRASS,
	Enums.TileType.BUSH:              Enums.TileType.FLOOR_GRASS,
	Enums.TileType.TREE_DEAD:         Enums.TileType.FLOOR_GRASS,
}

const _BURN_MAP: Dictionary = {
	Enums.TileType.WALL_WOOD:         Enums.TileType.FLOOR_ASH,
	Enums.TileType.WALL_PAPER:        Enums.TileType.FLOOR_ASH,
	Enums.TileType.DOOR_SHOJI_CLOSED: Enums.TileType.FLOOR_ASH,
	Enums.TileType.DOOR_SHOJI_OPEN:   Enums.TileType.FLOOR_ASH,
	Enums.TileType.DOOR_WOOD_CLOSED:  Enums.TileType.FLOOR_ASH,
	Enums.TileType.DOOR_WOOD_OPEN:    Enums.TileType.FLOOR_ASH,
	Enums.TileType.FLOOR_WOOD:        Enums.TileType.FLOOR_ASH,
	Enums.TileType.FLOOR_TATAMI:      Enums.TileType.FLOOR_ASH,
	Enums.TileType.BAMBOO:            Enums.TileType.FLOOR_ASH,
	Enums.TileType.BUSH:              Enums.TileType.FLOOR_ASH,
	Enums.TileType.TREE_DEAD:         Enums.TileType.FLOOR_ASH,
	Enums.TileType.TREE_EVERGREEN:    Enums.TileType.FLOOR_ASH,
	Enums.TileType.TREE_DECIDUOUS:    Enums.TileType.FLOOR_ASH,
	Enums.TileType.TREE_CHERRY:       Enums.TileType.FLOOR_ASH,
	Enums.TileType.CROPS:             Enums.TileType.FLOOR_ASH,
}


static func is_destructible(tile: int) -> bool:
	return _DESTRUCTION_MAP.has(tile)


static func is_flammable(tile: int) -> bool:
	return _BURN_MAP.has(tile)


func destroy_tile(x: int, y: int) -> int:
	var tile: int = get_tile(x, y)
	if not _DESTRUCTION_MAP.has(tile):
		return -1
	var replacement: int = _DESTRUCTION_MAP[tile]
	set_delta(x, y, replacement)
	return replacement


func burn_tile(x: int, y: int) -> int:
	var tile: int = get_tile(x, y)
	if not _BURN_MAP.has(tile):
		return -1
	var replacement: int = _BURN_MAP[tile]
	set_delta(x, y, replacement)
	return replacement


func set_fire(x: int, y: int) -> bool:
	var tile: int = get_tile(x, y)
	if not _BURN_MAP.has(tile):
		return false
	set_delta(x, y, Enums.TileType.FIRE)
	return true


func extinguish(x: int, y: int) -> bool:
	if get_tile(x, y) != Enums.TileType.FIRE:
		return false
	set_delta(x, y, Enums.TileType.FLOOR_ASH)
	return true


# -- Depth gradient (s56.21) --------------------------------------------------

# 8-directional neighbor offsets for the depth BFS (matches MovementSystem's
# diagonal movement model).
const _DEPTH_NEIGHBORS: Array[Vector2i] = [
	Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
	Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1),
]

# Path-distance from (x,y) to the entry tile, or -1 if depth is uncomputed or
# the tile is unreachable.
func depth_at(x: int, y: int) -> int:
	if x < 0 or x >= width or y < 0 or y >= height:
		return -1
	if depth_grid.size() != width * height:
		return -1
	return depth_grid[y * width + x]


func has_depth_grid() -> bool:
	return depth_grid.size() == width * height


# -- Elevation / Z-axis helpers (s4.4) ----------------------------------------

# Elevation level at (x,y). 0 for out-of-bounds or a flat (no-elevation) map.
func elevation_at(x: int, y: int) -> int:
	if x < 0 or x >= width or y < 0 or y >= height:
		return 0
	if elevation.size() != width * height:
		return 0
	return elevation[y * width + x]


# True when an elevation grid has been computed for this map.
func has_elevation() -> bool:
	return elevation.size() == width * height


# Allocates a flat elevation grid (every tile at `level`). Generators that add
# verticality call this before raising individual tiles via set_elevation.
func init_elevation(level: int = 0) -> void:
	var count: int = width * height
	elevation.resize(count)
	var v: int = clampi(level, 0, MAX_ELEVATION)
	for i in range(count):
		elevation[i] = v


# Raises/sets the elevation of one tile. Lazily allocates a flat grid first so a
# generator can stamp heights onto a map that had none. Clamped to [0, MAX_ELEVATION].
func set_elevation(x: int, y: int, level: int) -> void:
	if x < 0 or x >= width or y < 0 or y >= height:
		return
	if elevation.size() != width * height:
		init_elevation()
	elevation[y * width + x] = clampi(level, 0, MAX_ELEVATION)


# -- Stacked-floor accessors (s4.4 Option B) ----------------------------------

# True when this map has stacked floors above the ground level.
func has_levels() -> bool:
	return level_count > 1


# Total number of stacked levels (ground + upper floors). Always >= 1.
func get_level_count() -> int:
	return maxi(1, level_count)


# Allocates `count` stacked levels. Level 0 stays in tile_types; levels 1..count-1
# get a fresh grid filled with `fill` (VOID = open air — no structure rises there).
# count clamped to [1, MAX_LEVELS]. NOTE: this CLEARS any existing upper levels —
# use ensure_levels() to grow non-destructively on a multi-building map.
func init_levels(count: int, fill: int = Enums.TileType.VOID) -> void:
	level_count = clampi(count, 1, MAX_LEVELS)
	upper_levels.clear()
	var tiles: int = width * height
	for _l in range(level_count - 1):
		var grid: PackedByteArray = PackedByteArray()
		grid.resize(tiles)
		for i in range(tiles):
			grid[i] = fill
		upper_levels.append(grid)


# Grows the level stack up to `count` WITHOUT clearing existing levels (appends
# fresh VOID grids only as needed). Safe to call repeatedly while stacking several
# buildings of different heights on one map. No-op if already tall enough.
func ensure_levels(count: int, fill: int = Enums.TileType.VOID) -> void:
	var target: int = clampi(count, 1, MAX_LEVELS)
	if target <= level_count:
		return
	var tiles: int = width * height
	while upper_levels.size() < target - 1:
		var grid: PackedByteArray = PackedByteArray()
		grid.resize(tiles)
		for i in range(tiles):
			grid[i] = fill
		upper_levels.append(grid)
	level_count = target


# Tile at (x,y) on a specific level. Level 0 routes through get_tile (honors
# deltas + OOB). Upper levels read their own grid; a valid in-bounds tile on a
# level with no grid returns VOID (open air); x/y OOB returns WALL_STONE (matches
# get_tile's solid-edge convention).
func get_tile_at(x: int, y: int, level: int) -> int:
	if level <= 0:
		return get_tile(x, y)
	if x < 0 or x >= width or y < 0 or y >= height:
		return Enums.TileType.WALL_STONE
	var idx: int = level - 1
	if idx < 0 or idx >= upper_levels.size():
		return Enums.TileType.VOID
	var grid: PackedByteArray = upper_levels[idx]
	if grid.size() != width * height:
		return Enums.TileType.VOID
	return grid[y * width + x]


# Sets the tile at (x,y) on a specific level. Level 0 routes through set_tile.
# Lazily allocates the level stack up to `level` (filled VOID) so a generator can
# stamp an upper floor onto a map that had none.
func set_tile_at(x: int, y: int, level: int, tile: int) -> void:
	if level <= 0:
		set_tile(x, y, tile)
		return
	if x < 0 or x >= width or y < 0 or y >= height:
		return
	if level >= level_count:
		ensure_levels(level + 1)  # grow non-destructively (never clobber existing levels)
	var grid: PackedByteArray = upper_levels[level - 1]
	grid[y * width + x] = tile
	upper_levels[level - 1] = grid


static func is_stair(tile: int) -> bool:
	return tile == Enums.TileType.STAIRS_UP or tile == Enums.TileType.STAIRS_DOWN


# The level a stair at (x,y,level) leads to, or -1 if the tile is not a stair or
# the destination level is out of range. STAIRS_UP -> level+1, STAIRS_DOWN -> level-1.
func stair_destination_level(x: int, y: int, level: int) -> int:
	var t: int = get_tile_at(x, y, level)
	var dest: int = -1
	if t == Enums.TileType.STAIRS_UP:
		dest = level + 1
	elif t == Enums.TileType.STAIRS_DOWN:
		dest = level - 1
	if dest < 0 or dest >= get_level_count():
		return -1
	return dest


# The tile to DISPLAY at (x,y) for a viewer standing on `viewer_level`, plus how
# many levels below the viewer it was found (s4.4 Option B render). On the viewer's
# own level a non-open-air tile shows directly (depth 0). Where the viewer's level
# is open air (VOID — no structure rises there), the view falls through to the first
# solid tile below (a balcony/roof edge peeking at the ground), depth = how far down;
# the renderer dims by depth. Level 0 always shows its own tile (the ground is solid).
# Returns {"tile": int, "depth": int}. For a single-level map / viewer_level 0 this is
# always {tile: get_tile(x,y), depth: 0}, so existing render is unchanged.
func resolve_display(x: int, y: int, viewer_level: int) -> Dictionary:
	var vl: int = clampi(viewer_level, 0, get_level_count() - 1)
	var t: int = get_tile_at(x, y, vl)
	if vl == 0 or t != Enums.TileType.VOID:
		return {"tile": t, "depth": 0}
	for lvl in range(vl - 1, -1, -1):
		var below: int = get_tile_at(x, y, lvl)
		if lvl == 0 or below != Enums.TileType.VOID:
			return {"tile": below, "depth": vl - lvl}
	return {"tile": t, "depth": 0}


# True when a spiritual overlap has been applied to this map (s56.16.1b).
func has_overlap() -> bool:
	return spiritual_event_type >= 0 and overlap_intensity.size() == width * height


# Raw stored overlap intensity at (x,y), 0.0 if no overlap or out of bounds.
# This is the un-healed gradient — use SpiritualPalette.current_intensity_at for
# the value after restoration_progress healing.
func intensity_at(x: int, y: int) -> float:
	if x < 0 or x >= width or y < 0 or y >= height:
		return 0.0
	if overlap_intensity.size() != width * height:
		return 0.0
	return overlap_intensity[y * width + x]


# Floods 8-directional BFS from the entry tile over walkable tiles (passable
# tiles, plus doors — closed doors are traversable by bump-to-open, matching
# the connectivity model). Fills depth_grid with path-distance; unreachable
# tiles stay -1. Deterministic (BFS order is fixed). s56.21.
func compute_depth_grid(entry_x: int, entry_y: int) -> void:
	var count: int = width * height
	depth_grid.resize(count)
	for i in range(count):
		depth_grid[i] = -1
	if entry_x < 0 or entry_x >= width or entry_y < 0 or entry_y >= height:
		return
	var frontier: Array[Vector2i] = [Vector2i(entry_x, entry_y)]
	depth_grid[entry_y * width + entry_x] = 0
	var head: int = 0
	while head < frontier.size():
		var cur: Vector2i = frontier[head]
		head += 1
		var d: int = depth_grid[cur.y * width + cur.x]
		for n: Vector2i in _DEPTH_NEIGHBORS:
			var nx: int = cur.x + n.x
			var ny: int = cur.y + n.y
			if nx < 0 or nx >= width or ny < 0 or ny >= height:
				continue
			var idx: int = ny * width + nx
			if depth_grid[idx] != -1:
				continue
			var tile: int = get_tile(nx, ny)
			if not (is_passable(tile) or is_door(tile)):
				continue
			depth_grid[idx] = d + 1
			frontier.append(Vector2i(nx, ny))


# -- Rectangle fill -----------------------------------------------------------

# Fills a rectangular area of tiles (inclusive bounds). Used by generators.
func fill_rect(lx: int, ly: int, rx: int, ry: int, tile: int) -> void:
	for yy: int in range(ly, ry + 1):
		for xx: int in range(lx, rx + 1):
			set_tile(xx, yy, tile)
