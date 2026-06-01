class_name AsciiMapGenerator
## Deterministic procedural ASCII map generation for Lesser Zones (s4.4).
##
## Every map is generated from a fixed seed: settlement_name + zone_name +
## zone_type string. The same inputs always produce the same layout.
## Only physical deltas (destroyed walls, new construction) are stored between
## sessions — the base map is regenerated identically on each entry.
##
## Zone types implemented (LOCKED, s4.4):
##   MARKET_STREET, TEMPLE_GROUNDS, SHRINE_CLEARING, FOREST_PATH,
##   ROAD, RESIDENTIAL_QUARTER, FARMLAND, RIVER_CROSSING.
## All other ZoneSubtype values fall back to a plain FLOOR_GRASS fill with
## perimeter walls until their generation algorithm is designed.


const S: int = AsciiMapData.MAP_SIZE      # 31
const MID: int = AsciiMapData.MAP_SIZE / 2  # 15


# --- Public API ---------------------------------------------------------------

# Generate a new AsciiMapData for the given zone. The seed is computed from
# settlement_name + ":" + zone_name + ":" + zone_type_string.
static func generate(
	zone_id: String,
	zone_name: String,
	zone_subtype: int,
	settlement_name: String,
) -> AsciiMapData:
	var map: AsciiMapData = AsciiMapData.new()
	map.zone_id = zone_id
	map.zone_name = zone_name
	map.zone_subtype = zone_subtype
	map.seed_string = settlement_name + ":" + zone_name + ":" + str(zone_subtype)
	map.init_tiles(Enums.TileType.FLOOR_GRASS)

	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = _str_to_seed(map.seed_string)

	match zone_subtype:
		Enums.ZoneSubtype.MARKET_STREET:
			_gen_market_street(map, rng)
		Enums.ZoneSubtype.TEMPLE_GROUNDS:
			_gen_temple_grounds(map, rng)
		Enums.ZoneSubtype.SHRINE_CLEARING:
			_gen_shrine_clearing(map, rng)
		Enums.ZoneSubtype.FOREST_PATH:
			_gen_forest_path(map, rng)
		Enums.ZoneSubtype.ROAD:
			_gen_road(map, rng)
		Enums.ZoneSubtype.RESIDENTIAL_QUARTER:
			_gen_residential_quarter(map, rng)
		Enums.ZoneSubtype.FARMLAND:
			_gen_farmland(map, rng)
		Enums.ZoneSubtype.RIVER_CROSSING:
			_gen_river_crossing(map, rng)
		_:
			_gen_default(map, rng)

	return map


# --- Tile display helpers (used by AsciiMapView) ------------------------------

# Returns the Unicode glyph for a given tile type.
# Wall glyphs for WALL_WOOD and WALL_PAPER require neighbour connectivity;
# pass the map and position for those types (others ignore map/x/y).
static func get_glyph(
	tile: int,
	x: int = 0,
	y: int = 0,
	map: AsciiMapData = null,
) -> String:
	match tile:
		Enums.TileType.VOID:              return " "
		Enums.TileType.FLOOR_GRASS:       return "."
		Enums.TileType.FLOOR_DIRT:        return "."
		Enums.TileType.FLOOR_WOOD:        return "="
		Enums.TileType.FLOOR_TATAMI:      return "≡"
		Enums.TileType.FLOOR_STONE:       return "∷"
		Enums.TileType.FLOOR_MUD:         return ","
		Enums.TileType.FLOOR_SNOW:        return "."
		Enums.TileType.FLOOR_SAND:        return "."
		Enums.TileType.WALL_STONE:        return "█"
		Enums.TileType.WALL_WOOD:
			if map != null:
				return _wall_wood_glyph(x, y, map)
			return "┃"
		Enums.TileType.WALL_PAPER:
			if map != null:
				return _wall_paper_glyph(x, y, map)
			return "│"
		Enums.TileType.WATER_SHALLOW:     return "~"
		Enums.TileType.WATER_DEEP:        return "~"
		Enums.TileType.WATER_RAPID:       return "≈"
		Enums.TileType.WATER_PADDY:       return "~"
		Enums.TileType.TREE_EVERGREEN:    return "♣"
		Enums.TileType.TREE_DECIDUOUS:    return "♣"
		Enums.TileType.TREE_CHERRY:       return "♣"
		Enums.TileType.TREE_DEAD:         return "¥"
		Enums.TileType.BAMBOO:            return "♠"
		Enums.TileType.BUSH:              return "\""
		Enums.TileType.CROPS:             return "%"
		Enums.TileType.GROUNDCOVER:       return ","
		Enums.TileType.FLOWERS:           return "*"
		Enums.TileType.DOOR_SHOJI_CLOSED: return "+"
		Enums.TileType.DOOR_SHOJI_OPEN:   return "'"
		Enums.TileType.DOOR_WOOD_CLOSED:  return "+"
		Enums.TileType.DOOR_WOOD_OPEN:    return "/"
		Enums.TileType.GATE_CLOSED:       return "╬"
		Enums.TileType.GATE_OPEN:         return "∏"
		Enums.TileType.ZONE_EXIT:         return ">"
	return "?"


# Returns the foreground colour for a given tile type.
static func get_fg_color(tile: int) -> Color:
	match tile:
		Enums.TileType.VOID:              return Color.BLACK
		Enums.TileType.FLOOR_GRASS:       return Color(0.2, 0.6, 0.2)
		Enums.TileType.FLOOR_DIRT:        return Color(0.55, 0.35, 0.15)
		Enums.TileType.FLOOR_WOOD:        return Color(0.55, 0.35, 0.15)
		Enums.TileType.FLOOR_TATAMI:      return Color(0.8, 0.7, 0.2)
		Enums.TileType.FLOOR_STONE:       return Color(0.5, 0.5, 0.5)
		Enums.TileType.FLOOR_MUD:         return Color(0.4, 0.25, 0.1)
		Enums.TileType.FLOOR_SNOW:        return Color(0.9, 0.9, 1.0)
		Enums.TileType.FLOOR_SAND:        return Color(0.85, 0.75, 0.4)
		Enums.TileType.WALL_STONE:        return Color(0.5, 0.5, 0.5)
		Enums.TileType.WALL_WOOD:         return Color(0.55, 0.35, 0.15)
		Enums.TileType.WALL_PAPER:        return Color(0.9, 0.9, 0.9)
		Enums.TileType.WATER_SHALLOW:     return Color(0.3, 0.5, 0.9)
		Enums.TileType.WATER_DEEP:        return Color(0.1, 0.2, 0.6)
		Enums.TileType.WATER_RAPID:       return Color(0.4, 0.8, 0.9)
		Enums.TileType.WATER_PADDY:       return Color(0.2, 0.6, 0.3)
		Enums.TileType.TREE_EVERGREEN:    return Color(0.0, 0.4, 0.0)
		Enums.TileType.TREE_DECIDUOUS:    return Color(0.1, 0.65, 0.1)
		Enums.TileType.TREE_CHERRY:       return Color(0.9, 0.5, 0.7)
		Enums.TileType.TREE_DEAD:         return Color(0.45, 0.3, 0.1)
		Enums.TileType.BAMBOO:            return Color(0.2, 0.7, 0.2)
		Enums.TileType.BUSH:              return Color(0.15, 0.55, 0.15)
		Enums.TileType.CROPS:             return Color(0.8, 0.7, 0.2)
		Enums.TileType.GROUNDCOVER:       return Color(0.2, 0.55, 0.2)
		Enums.TileType.FLOWERS:           return Color(0.9, 0.4, 0.6)
		Enums.TileType.DOOR_SHOJI_CLOSED: return Color(0.9, 0.9, 0.9)
		Enums.TileType.DOOR_SHOJI_OPEN:   return Color(0.9, 0.9, 0.9)
		Enums.TileType.DOOR_WOOD_CLOSED:  return Color(0.55, 0.35, 0.15)
		Enums.TileType.DOOR_WOOD_OPEN:    return Color(0.55, 0.35, 0.15)
		Enums.TileType.GATE_CLOSED:       return Color(0.5, 0.4, 0.2)
		Enums.TileType.GATE_OPEN:         return Color(0.5, 0.4, 0.2)
		Enums.TileType.ZONE_EXIT:         return Color(0.4, 0.9, 0.9)
	return Color.WHITE


# Returns the background colour. Transparent (alpha 0) means use the default
# dark background. Only water, taint, and spirit realm return a solid bg.
static func get_bg_color(tile: int) -> Color:
	match tile:
		Enums.TileType.WATER_DEEP:  return Color(0.05, 0.1, 0.3, 1.0)
		Enums.TileType.WATER_PADDY: return Color(0.05, 0.2, 0.15, 1.0)
		_:                          return Color(0, 0, 0, 0)


# --- Zone generators ----------------------------------------------------------

# MARKET_STREET: wide paved road down the centre, buildings on north and south,
# vendor stalls along the road edges, zone exits at east and west map edges.
static func _gen_market_street(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	# Stone floor base (entire map becomes stone road or building interior).
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_STONE)

	# Outer wood-wall perimeter.
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Central road band: rows 13–17 (5 tiles wide), x 1–29.
	# Already stone; clear any wall from perimeter over the exit columns.

	# North building block: rows 1–11, columns 1–29.
	# Subdivide into ~4 shops separated by narrow alleys.
	var shop_count: int = 3 + (rng.randi() % 2)  # 3 or 4 shops
	var shop_w: int = (28) / shop_count
	for i in range(shop_count):
		var sx: int = 1 + i * shop_w
		var ex: int = sx + shop_w - 2
		# Shop outer wall.
		_draw_wood_box(map, sx, 1, ex, 11)
		# Interior tatami floor.
		_fill_rect(map, sx + 1, 2, ex - 1, 10, Enums.TileType.FLOOR_TATAMI)
		# Shop door facing south (toward road).
		var door_x: int = sx + (shop_w / 2)
		map.set_tile(door_x, 11, Enums.TileType.DOOR_WOOD_OPEN)

	# South building block: rows 19–29, mirrored.
	for i in range(shop_count):
		var sx: int = 1 + i * shop_w
		var ex: int = sx + shop_w - 2
		_draw_wood_box(map, sx, 19, ex, 29)
		_fill_rect(map, sx + 1, 20, ex - 1, 28, Enums.TileType.FLOOR_TATAMI)
		var door_x: int = sx + (shop_w / 2)
		map.set_tile(door_x, 19, Enums.TileType.DOOR_WOOD_OPEN)

	# Road strip (rows 12–18) is plain stone floor — overwrite any walls.
	_fill_rect(map, 1, 12, S - 2, 18, Enums.TileType.FLOOR_STONE)

	# Vendor stalls along road edges: pairs of wood tiles on rows 12 and 18.
	for i in range(2, S - 3, 4):
		map.set_tile(i, 12, Enums.TileType.WALL_WOOD)
		map.set_tile(i + 1, 12, Enums.TileType.WALL_WOOD)
		map.set_tile(i, 18, Enums.TileType.WALL_WOOD)
		map.set_tile(i + 1, 18, Enums.TileType.WALL_WOOD)

	# Zone exits: openings in west and east perimeter walls on the road centre row.
	map.set_tile(0, MID, Enums.TileType.ZONE_EXIT)
	map.set_tile(S - 1, MID, Enums.TileType.ZONE_EXIT)
	# Clear the perimeter wall on adjacent road rows too.
	for ry in range(13, 18):
		if map.get_tile(0, ry) == Enums.TileType.WALL_WOOD:
			map.set_tile(0, ry, Enums.TileType.FLOOR_STONE)
		if map.get_tile(S - 1, ry) == Enums.TileType.WALL_WOOD:
			map.set_tile(S - 1, ry, Enums.TileType.FLOOR_STONE)

	map.exits = [
		{x = 0, y = MID, direction = "west", target_zone_id = ""},
		{x = S - 1, y = MID, direction = "east", target_zone_id = ""},
	]


# TEMPLE_GROUNDS: stone perimeter wall, central courtyard, temple building
# in the north half, garden trees in south-east, torii gate at south entrance.
static func _gen_temple_grounds(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_STONE)
	_draw_stone_border(map, 0, 0, S - 1, S - 1)

	# Outer stone wall inset border (1 tile inside edge) — double-walled entry feel.
	_draw_stone_border(map, 1, 1, S - 2, S - 2)

	# Open courtyard: stone floor rows 16–28, columns 3–27.
	_fill_rect(map, 3, 16, S - 4, S - 4, Enums.TileType.FLOOR_STONE)

	# Temple building: rows 3–13, columns 8–22.
	_draw_wood_box(map, 8, 3, 22, 13)
	_fill_rect(map, 9, 4, 21, 12, Enums.TileType.FLOOR_TATAMI)
	# Temple entrance doors (south face).
	map.set_tile(14, 13, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(15, 13, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(16, 13, Enums.TileType.DOOR_WOOD_OPEN)

	# Torii gate at south entrance (rows 27–28, columns 13–17).
	map.set_tile(13, 28, Enums.TileType.WALL_WOOD)
	map.set_tile(17, 28, Enums.TileType.WALL_WOOD)
	map.set_tile(13, 27, Enums.TileType.WALL_WOOD)
	map.set_tile(17, 27, Enums.TileType.WALL_WOOD)
	map.set_tile(14, 27, Enums.TileType.WALL_WOOD)
	map.set_tile(15, 27, Enums.TileType.FLOOR_STONE)
	map.set_tile(16, 27, Enums.TileType.FLOOR_STONE)

	# Garden area: north-east corner, scattered evergreen trees.
	var tree_positions: Array[Vector2i] = [
		Vector2i(24, 4), Vector2i(25, 6), Vector2i(26, 5),
		Vector2i(23, 7), Vector2i(27, 8), Vector2i(25, 9),
		Vector2i(3, 5), Vector2i(4, 7), Vector2i(3, 9),
	]
	for tp in tree_positions:
		if map.get_tile(tp.x, tp.y) == Enums.TileType.FLOOR_STONE:
			map.set_tile(tp.x, tp.y, Enums.TileType.TREE_EVERGREEN)

	# Random additional garden trees.
	for _i in range(5 + rng.randi() % 4):
		var tx: int = 3 + rng.randi() % 5
		var ty: int = 16 + rng.randi() % 10
		if map.get_tile(tx, ty) == Enums.TileType.FLOOR_STONE:
			map.set_tile(tx, ty, Enums.TileType.TREE_EVERGREEN)

	# South gate opening through outer walls.
	map.set_tile(MID - 1, S - 1, Enums.TileType.GATE_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.GATE_OPEN)
	map.set_tile(MID + 1, S - 1, Enums.TileType.GATE_OPEN)
	map.set_tile(MID - 1, S - 2, Enums.TileType.GATE_OPEN)
	map.set_tile(MID, S - 2, Enums.TileType.GATE_OPEN)
	map.set_tile(MID + 1, S - 2, Enums.TileType.GATE_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)

	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# SHRINE_CLEARING: dense forest ring, open grassy clearing in centre,
# torii gate at south, small shrine building north-centre.
static func _gen_shrine_clearing(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.TREE_EVERGREEN)

	# Clearing: oval-ish open area, rows 9–27, columns 8–22.
	for y in range(8, 24):
		for x in range(7, 24):
			var dx: float = (x - MID) / 8.0
			var dy: float = (y - MID) / 9.0
			if dx * dx + dy * dy < 1.0:
				map.set_tile(x, y, Enums.TileType.FLOOR_GRASS)

	# Shrine building: rows 10–16, columns 12–18.
	_draw_wood_box(map, 12, 10, 18, 16)
	_fill_rect(map, 13, 11, 17, 15, Enums.TileType.FLOOR_TATAMI)
	map.set_tile(MID, 16, Enums.TileType.DOOR_WOOD_OPEN)

	# Torii gate at south of clearing.
	map.set_tile(13, 22, Enums.TileType.WALL_WOOD)
	map.set_tile(17, 22, Enums.TileType.WALL_WOOD)
	map.set_tile(13, 21, Enums.TileType.WALL_WOOD)
	map.set_tile(17, 21, Enums.TileType.WALL_WOOD)
	map.set_tile(14, 21, Enums.TileType.WALL_WOOD)
	map.set_tile(16, 21, Enums.TileType.WALL_WOOD)

	# Path through southern trees to zone exit.
	for y in range(23, S):
		map.set_tile(MID, y, Enums.TileType.FLOOR_DIRT)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)

	# Scattered groundcover and flowers in clearing.
	for _i in range(12 + rng.randi() % 6):
		var fx: int = 9 + rng.randi() % 12
		var fy: int = 17 + rng.randi() % 5
		if map.get_tile(fx, fy) == Enums.TileType.FLOOR_GRASS:
			map.set_tile(fx, fy, Enums.TileType.FLOWERS if rng.randi() % 2 == 0 else Enums.TileType.GROUNDCOVER)

	# Random bushes at clearing edge.
	for _i in range(6 + rng.randi() % 4):
		var bx: int = 7 + rng.randi() % 16
		var by: int = 8 + rng.randi() % 16
		if map.get_tile(bx, by) == Enums.TileType.TREE_EVERGREEN:
			map.set_tile(bx, by, Enums.TileType.BUSH)

	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# FOREST_PATH: dense mixed forest, narrow winding dirt path through centre.
static func _gen_forest_path(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.TREE_EVERGREEN)

	# Randomly replace some evergreens with deciduous for variety.
	for y in range(S):
		for x in range(S):
			if map.get_tile(x, y) == Enums.TileType.TREE_EVERGREEN:
				if rng.randi() % 5 == 0:
					map.set_tile(x, y, Enums.TileType.TREE_DECIDUOUS)

	# Path: enters south-centre, meanders north, exits north-centre.
	# Represented as a 2-3 tile wide dirt corridor with slight lateral drift.
	var path_x: int = MID
	for y in range(S - 1, -1, -1):
		# Drift up to ±1 tile per row.
		var drift: int = (rng.randi() % 3) - 1
		path_x = clampi(path_x + drift, 3, S - 4)
		for w in range(-1, 2):
			map.set_tile(path_x + w, y, Enums.TileType.FLOOR_DIRT)
		# Occasional bush at path edge.
		if rng.randi() % 8 == 0:
			var side: int = path_x + (2 if rng.randi() % 2 == 0 else -2)
			if side >= 0 and side < S:
				map.set_tile(side, y, Enums.TileType.BUSH)

	# Zone exits.
	map.set_tile(MID, 0, Enums.TileType.ZONE_EXIT)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = MID, y = 0, direction = "north", target_zone_id = ""},
		{x = MID, y = S - 1, direction = "south", target_zone_id = ""},
	]


# ROAD: wide packed-dirt road with shoulders, trees and rocks on either side.
static func _gen_road(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_GRASS)

	# Tree density on both sides.
	for y in range(S):
		for x in range(S):
			if x < 3 or x > S - 4:
				if rng.randi() % 3 != 0:
					map.set_tile(x, y, Enums.TileType.TREE_DECIDUOUS)

	# Road body: columns 5–25, dirt floor.
	_fill_rect(map, 5, 0, S - 6, S - 1, Enums.TileType.FLOOR_DIRT)

	# Occasional roadside shrine or tea stand.
	if rng.randi() % 3 != 0:
		var shrine_y: int = 4 + rng.randi() % 20
		var shrine_x: int = 3 if rng.randi() % 2 == 0 else S - 4
		map.set_tile(shrine_x, shrine_y, Enums.TileType.WALL_WOOD)
		map.set_tile(shrine_x, shrine_y - 1, Enums.TileType.WALL_WOOD)

	# Zone exits north and south.
	map.set_tile(MID, 0, Enums.TileType.ZONE_EXIT)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = MID, y = 0, direction = "north", target_zone_id = ""},
		{x = MID, y = S - 1, direction = "south", target_zone_id = ""},
	]


# RESIDENTIAL_QUARTER: grid of houses separated by narrow streets,
# small neighbourhood shrine in one corner.
static func _gen_residential_quarter(
	map: AsciiMapData,
	rng: RandomNumberGenerator,
) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_DIRT)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# 3×3 grid of house plots (roughly 9×9 tiles each with 1-tile alleys).
	var plot_w: int = 9
	var plot_h: int = 9
	for row in range(3):
		for col in range(3):
			var ox: int = 1 + col * (plot_w + 1)
			var oy: int = 1 + row * (plot_h + 1)
			if ox + plot_w - 1 >= S - 1 or oy + plot_h - 1 >= S - 1:
				continue
			_draw_wood_box(map, ox, oy, ox + plot_w - 1, oy + plot_h - 1)
			_fill_rect(map, ox + 1, oy + 1,
				ox + plot_w - 2, oy + plot_h - 2,
				Enums.TileType.FLOOR_WOOD)
			# Door on south face.
			var door_x: int = ox + plot_w / 2
			map.set_tile(door_x, oy + plot_h - 1, Enums.TileType.DOOR_WOOD_OPEN)

	# Small shrine in south-east corner (overwriting one house plot).
	var sx: int = 1 + 2 * (plot_w + 1)
	var sy: int = 1 + 2 * (plot_h + 1)
	if sx + 7 < S and sy + 7 < S:
		_fill_rect(map, sx, sy, sx + plot_w - 1, sy + plot_h - 1, Enums.TileType.FLOOR_STONE)
		_draw_stone_border(map, sx, sy, sx + plot_w - 1, sy + plot_h - 1)
		map.set_tile(sx + plot_w / 2, sy + plot_h - 1, Enums.TileType.DOOR_SHOJI_OPEN)

	# Zone exits.
	map.set_tile(0, MID, Enums.TileType.ZONE_EXIT)
	map.set_tile(S - 1, MID, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = 0, y = MID, direction = "west", target_zone_id = ""},
		{x = S - 1, y = MID, direction = "east", target_zone_id = ""},
	]


# FARMLAND: open rice paddies or dry fields, farm buildings in north-west.
static func _gen_farmland(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.CROPS)

	# Field paths (dirt) dividing paddies.
	for x in range(0, S, 8):
		_fill_rect(map, x, 0, x, S - 1, Enums.TileType.FLOOR_DIRT)
	for y in range(0, S, 8):
		_fill_rect(map, 0, y, S - 1, y, Enums.TileType.FLOOR_DIRT)

	# Occasional rice paddy (water) replacing some crop tiles.
	for _i in range(4 + rng.randi() % 3):
		var px: int = 1 + rng.randi() % 3 * 8 + 1
		var py: int = 1 + rng.randi() % 3 * 8 + 1
		_fill_rect(map, px, py, px + 5, py + 5, Enums.TileType.WATER_PADDY)

	# Farm buildings north-west.
	_draw_wood_box(map, 1, 1, 7, 6)
	_fill_rect(map, 2, 2, 6, 5, Enums.TileType.FLOOR_WOOD)
	map.set_tile(4, 6, Enums.TileType.DOOR_WOOD_OPEN)

	# Zone exits.
	map.set_tile(MID, 0, Enums.TileType.ZONE_EXIT)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = MID, y = 0, direction = "north", target_zone_id = ""},
		{x = MID, y = S - 1, direction = "south", target_zone_id = ""},
	]


# RIVER_CROSSING: bridge or ford, water tiles, chokepoint.
static func _gen_river_crossing(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_GRASS)

	# River runs east–west through the middle (rows 13–17).
	_fill_rect(map, 0, 13, S - 1, 17, Enums.TileType.WATER_DEEP)

	# Shallow ford centre or wooden bridge.
	var use_bridge: bool = rng.randi() % 2 == 0
	if use_bridge:
		# Bridge: wooden floor spanning river, columns 12–18.
		_fill_rect(map, 12, 13, 18, 17, Enums.TileType.FLOOR_WOOD)
		map.set_tile(11, MID, Enums.TileType.WALL_WOOD)
		map.set_tile(19, MID, Enums.TileType.WALL_WOOD)
	else:
		# Ford: shallow water columns 13–17.
		_fill_rect(map, 13, 13, 17, 17, Enums.TileType.WATER_SHALLOW)

	# Vegetation on river banks.
	for x in range(S):
		if rng.randi() % 3 != 0:
			if map.get_tile(x, 11) == Enums.TileType.FLOOR_GRASS:
				map.set_tile(x, 11, Enums.TileType.BUSH)
			if map.get_tile(x, 12) == Enums.TileType.FLOOR_GRASS:
				map.set_tile(x, 12, Enums.TileType.BUSH)
			if map.get_tile(x, 18) == Enums.TileType.FLOOR_GRASS:
				map.set_tile(x, 18, Enums.TileType.BUSH)
			if map.get_tile(x, 19) == Enums.TileType.FLOOR_GRASS:
				map.set_tile(x, 19, Enums.TileType.BUSH)

	# Zone exits north and south.
	map.set_tile(MID, 0, Enums.TileType.ZONE_EXIT)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = MID, y = 0, direction = "north", target_zone_id = ""},
		{x = MID, y = S - 1, direction = "south", target_zone_id = ""},
	]


# Default fallback: flat grass with stone perimeter (zone type not yet designed).
static func _gen_default(map: AsciiMapData, _rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_GRASS)
	_draw_stone_border(map, 0, 0, S - 1, S - 1)
	map.set_tile(MID, 0, Enums.TileType.ZONE_EXIT)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = MID, y = 0, direction = "north", target_zone_id = ""},
		{x = MID, y = S - 1, direction = "south", target_zone_id = ""},
	]


# --- Wall-glyph helpers -------------------------------------------------------

# Returns the correct heavy box-drawing character for a WALL_WOOD tile
# based on which of its 4 orthogonal neighbours are also walls.
static func _wall_wood_glyph(x: int, y: int, map: AsciiMapData) -> String:
	var n: bool = _is_wall(x, y - 1, map)
	var s: bool = _is_wall(x, y + 1, map)
	var w: bool = _is_wall(x - 1, y, map)
	var e: bool = _is_wall(x + 1, y, map)
	return _box_heavy(n, s, w, e)


static func _wall_paper_glyph(x: int, y: int, map: AsciiMapData) -> String:
	var n: bool = _is_wall(x, y - 1, map)
	var s: bool = _is_wall(x, y + 1, map)
	var w: bool = _is_wall(x - 1, y, map)
	var e: bool = _is_wall(x + 1, y, map)
	return _box_light(n, s, w, e)


static func _is_wall(x: int, y: int, map: AsciiMapData) -> bool:
	var t: int = map.get_tile(x, y)
	return t == Enums.TileType.WALL_WOOD or \
	       t == Enums.TileType.WALL_PAPER or \
	       t == Enums.TileType.WALL_STONE


# Heavy box-drawing character from (north, south, west, east) connectivity.
static func _box_heavy(n: bool, s: bool, w: bool, e: bool) -> String:
	if n and s and w and e: return "╋"
	if n and s and e:       return "┣"
	if n and s and w:       return "┫"
	if n and w and e:       return "┻"
	if s and w and e:       return "┳"
	if n and s:             return "┃"
	if w and e:             return "━"
	if n and e:             return "┗"
	if n and w:             return "┛"
	if s and e:             return "┏"
	if s and w:             return "┓"
	if n:                   return "╹"
	if s:                   return "╻"
	if w:                   return "╸"
	if e:                   return "╺"
	return "━"


# Light box-drawing character from connectivity.
static func _box_light(n: bool, s: bool, w: bool, e: bool) -> String:
	if n and s and w and e: return "┼"
	if n and s and e:       return "├"
	if n and s and w:       return "┤"
	if n and w and e:       return "┴"
	if s and w and e:       return "┬"
	if n and s:             return "│"
	if w and e:             return "─"
	if n and e:             return "└"
	if n and w:             return "┘"
	if s and e:             return "┌"
	if s and w:             return "┐"
	if n:                   return "╵"
	if s:                   return "╷"
	if w:                   return "╴"
	if e:                   return "╶"
	return "─"


# --- Draw primitives ----------------------------------------------------------

static func _fill_rect(
	map: AsciiMapData,
	x1: int, y1: int, x2: int, y2: int,
	tile: int,
) -> void:
	for y in range(y1, y2 + 1):
		for x in range(x1, x2 + 1):
			map.set_tile(x, y, tile)


static func _draw_stone_border(
	map: AsciiMapData,
	x1: int, y1: int, x2: int, y2: int,
) -> void:
	for x in range(x1, x2 + 1):
		map.set_tile(x, y1, Enums.TileType.WALL_STONE)
		map.set_tile(x, y2, Enums.TileType.WALL_STONE)
	for y in range(y1, y2 + 1):
		map.set_tile(x1, y, Enums.TileType.WALL_STONE)
		map.set_tile(x2, y, Enums.TileType.WALL_STONE)


static func _draw_wood_border(
	map: AsciiMapData,
	x1: int, y1: int, x2: int, y2: int,
) -> void:
	for x in range(x1, x2 + 1):
		map.set_tile(x, y1, Enums.TileType.WALL_WOOD)
		map.set_tile(x, y2, Enums.TileType.WALL_WOOD)
	for y in range(y1, y2 + 1):
		map.set_tile(x1, y, Enums.TileType.WALL_WOOD)
		map.set_tile(x2, y, Enums.TileType.WALL_WOOD)


# Alias for draw_wood_border (rectangular box).
static func _draw_wood_box(
	map: AsciiMapData,
	x1: int, y1: int, x2: int, y2: int,
) -> void:
	_draw_wood_border(map, x1, y1, x2, y2)


# --- Seed utility -------------------------------------------------------------

static func _str_to_seed(s: String) -> int:
	# FNV-1a 32-bit hash for consistent cross-platform seeds.
	var h: int = 0x811c9dc5
	for i in range(s.length()):
		h = h ^ s.unicode_at(i)
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h
