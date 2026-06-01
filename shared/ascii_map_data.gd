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

# Primary flat tile array. Each byte is an Enums.TileType value.
# Populated by AsciiMapGenerator; read-only after generation.
@export var tile_types: PackedByteArray = []

# Persistent overrides applied on top of the generated base map.
# Key: "x,y", Value: Enums.TileType int. Stored between sessions.
@export var deltas: Dictionary = {}

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
		Enums.TileType.VOID:
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
		Enums.TileType.FIRE:
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
