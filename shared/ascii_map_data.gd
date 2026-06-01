class_name AsciiMapData
extends Resource
## Data model for a 31×31 ASCII tile map for a single Lesser Zone (s4.4).
## Tiles stored as a flat PackedByteArray, row-major: index = y * MAP_SIZE + x.
## Deltas override generated tiles to persist physical changes (destroyed walls,
## new construction) without regenerating the whole map.

const MAP_SIZE: int = 31
const TILE_COUNT: int = MAP_SIZE * MAP_SIZE  # 961

# -- Zone identity ------------------------------------------------------------

@export var zone_id: String = ""
@export var zone_name: String = ""
# Enums.ZoneSubtype value — determines generation algorithm
@export var zone_subtype: int = Enums.ZoneSubtype.SHRINE_CLEARING
# Seed used for deterministic generation (settlement_name + zone_name + zone_type)
@export var seed_string: String = ""

# -- Tile data ----------------------------------------------------------------

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
	if x < 0 or x >= MAP_SIZE or y < 0 or y >= MAP_SIZE:
		return Enums.TileType.WALL_STONE
	var key: String = "%d,%d" % [x, y]
	if deltas.has(key):
		return deltas[key]
	if tile_types.size() != TILE_COUNT:
		return Enums.TileType.VOID
	return tile_types[y * MAP_SIZE + x]


func set_tile(x: int, y: int, tile: int) -> void:
	if x < 0 or x >= MAP_SIZE or y < 0 or y >= MAP_SIZE:
		return
	tile_types[y * MAP_SIZE + x] = tile


func set_delta(x: int, y: int, tile: int) -> void:
	if x < 0 or x >= MAP_SIZE or y < 0 or y >= MAP_SIZE:
		return
	deltas["%d,%d" % [x, y]] = tile


func clear_delta(x: int, y: int) -> void:
	var key: String = "%d,%d" % [x, y]
	deltas.erase(key)


func init_tiles(fill: int = Enums.TileType.FLOOR_GRASS) -> void:
	tile_types.resize(TILE_COUNT)
	for i in range(TILE_COUNT):
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
		Enums.TileType.GATE_CLOSED:
			return true
		_:
			return false
