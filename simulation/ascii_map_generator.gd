class_name AsciiMapGenerator
## Deterministic procedural ASCII map generation for Lesser Zones (s4.4).
##
## Every map is generated from a fixed seed: settlement_name + zone_name +
## zone_type string. The same inputs always produce the same layout.
## Only physical deltas (destroyed walls, new construction) are stored between
## sessions — the base map is regenerated identically on each entry.
##
## Zone types implemented (LOCKED, s4.4):
##   All 25 ZoneSubtype values have dedicated generators.


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
		Enums.ZoneSubtype.OHIROMA:
			_gen_ohiroma(map, rng)
		Enums.ZoneSubtype.ENKAI_HALL:
			_gen_enkai_hall(map, rng)
		Enums.ZoneSubtype.AUDIENCE_CHAMBER:
			_gen_audience_chamber(map, rng)
		Enums.ZoneSubtype.CHASHITSU:
			_gen_chashitsu(map, rng)
		Enums.ZoneSubtype.GUEST_WING:
			_gen_guest_wing(map, rng)
		Enums.ZoneSubtype.LORD_QUARTERS:
			_gen_lord_quarters(map, rng)
		Enums.ZoneSubtype.WAR_COUNCIL_ROOM:
			_gen_war_council_room(map, rng)
		Enums.ZoneSubtype.DOJO:
			_gen_dojo(map, rng)
		Enums.ZoneSubtype.OUTER_COURTYARD:
			_gen_outer_courtyard(map, rng)
		Enums.ZoneSubtype.TSUBONIWA:
			_gen_tsuboniwa(map, rng)
		Enums.ZoneSubtype.CASTLE_SHRINE:
			_gen_castle_shrine(map, rng)
		Enums.ZoneSubtype.PLEASURE_QUARTER:
			_gen_pleasure_quarter(map, rng)
		Enums.ZoneSubtype.DOCKS_WATERFRONT:
			_gen_docks_waterfront(map, rng)
		Enums.ZoneSubtype.POOR_QUARTER:
			_gen_poor_quarter(map, rng)
		Enums.ZoneSubtype.GOVERNMENT_QUARTER:
			_gen_government_quarter(map, rng)
		Enums.ZoneSubtype.MOUNTAIN_PASS:
			_gen_mountain_pass(map, rng)
		Enums.ZoneSubtype.WALL_TOWER:
			_gen_wall_tower(map, rng)
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
		Enums.TileType.FLOOR_ASH:         return ","
		Enums.TileType.FIRE:              return "^"
		Enums.TileType.RUBBLE:            return ";"
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
		Enums.TileType.FLOOR_ASH:         return Color(0.35, 0.35, 0.35)
		Enums.TileType.FIRE:              return Color(1.0, 0.4, 0.0)
		Enums.TileType.RUBBLE:            return Color(0.45, 0.4, 0.35)
	return Color.WHITE


# Returns the background colour. Transparent (alpha 0) means use the default
# dark background. Only water, taint, and spirit realm return a solid bg.
static func get_bg_color(tile: int) -> Color:
	match tile:
		Enums.TileType.WATER_DEEP:  return Color(0.05, 0.1, 0.3, 1.0)
		Enums.TileType.WATER_PADDY: return Color(0.05, 0.2, 0.15, 1.0)
		Enums.TileType.FIRE:        return Color(0.3, 0.05, 0.0, 1.0)
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


# OHIROMA (Great Hall): large formal hall with dais, tatami floor, wood-framed
# columns, shoji dividers. The lord's primary audience and court space.
static func _gen_ohiroma(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_WOOD)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Main hall tatami floor.
	_fill_rect(map, 2, 2, S - 3, S - 3, Enums.TileType.FLOOR_TATAMI)

	# Dais at north: raised stone platform rows 2–5.
	_fill_rect(map, 4, 2, S - 5, 5, Enums.TileType.FLOOR_STONE)

	# Columns along sides (wood wall pillars).
	for y in range(6, S - 4, 4):
		map.set_tile(3, y, Enums.TileType.WALL_WOOD)
		map.set_tile(S - 4, y, Enums.TileType.WALL_WOOD)

	# Shoji screen dividers partitioning side alcoves.
	_fill_rect(map, 1, 6, 1, S - 6, Enums.TileType.WALL_PAPER)
	_fill_rect(map, S - 2, 6, S - 2, S - 6, Enums.TileType.WALL_PAPER)
	map.set_tile(1, MID, Enums.TileType.DOOR_SHOJI_OPEN)
	map.set_tile(S - 2, MID, Enums.TileType.DOOR_SHOJI_OPEN)

	# Entrance doors south face.
	map.set_tile(MID - 1, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID + 1, S - 1, Enums.TileType.DOOR_WOOD_OPEN)

	# Zone exit south.
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# ENKAI_HALL (Banquet Hall): entertainment and feasting. Open tatami hall
# with wood-floor aisles between seating clusters.
static func _gen_enkai_hall(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_WOOD)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Tatami seating clusters: 2x3 grid of tatami pads separated by wood aisles.
	var pad_w: int = 8
	var pad_h: int = 8
	for row in range(3):
		for col in range(2):
			var ox: int = 3 + col * (pad_w + 3)
			var oy: int = 3 + row * (pad_h + 2)
			if ox + pad_w - 1 < S - 2 and oy + pad_h - 1 < S - 2:
				_fill_rect(map, ox, oy, ox + pad_w - 1, oy + pad_h - 1,
					Enums.TileType.FLOOR_TATAMI)

	# Paper screens along north wall for serving area.
	_fill_rect(map, 4, 1, S - 5, 1, Enums.TileType.WALL_PAPER)
	map.set_tile(MID, 1, Enums.TileType.DOOR_SHOJI_OPEN)

	# Entrance doors south face.
	map.set_tile(MID - 1, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID + 1, S - 1, Enums.TileType.DOOR_WOOD_OPEN)

	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# AUDIENCE_CHAMBER (Private Meeting Room): intimate room with tokonoma alcove,
# fusuma dividers, tatami floor. Smaller than ohiroma.
static func _gen_audience_chamber(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_WOOD)

	# Room inset: 5–25 x 5–25.
	_draw_wood_border(map, 5, 5, S - 6, S - 6)
	_fill_rect(map, 6, 6, S - 7, S - 7, Enums.TileType.FLOOR_TATAMI)

	# Tokonoma alcove recessed into north wall (columns 12–18, row 5).
	_fill_rect(map, 12, 3, 18, 5, Enums.TileType.FLOOR_TATAMI)
	_draw_wood_border(map, 12, 3, 18, 5)
	map.set_tile(MID, 5, Enums.TileType.DOOR_SHOJI_OPEN)

	# Fusuma dividers creating ante-room at south.
	_fill_rect(map, 6, S - 10, S - 7, S - 10, Enums.TileType.WALL_PAPER)
	map.set_tile(MID, S - 10, Enums.TileType.DOOR_SHOJI_OPEN)

	# Engawa corridor around exterior (wood floor already set).
	# Entrance on south.
	map.set_tile(MID, S - 6, Enums.TileType.DOOR_SHOJI_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)

	# Side exit east for connecting corridor.
	map.set_tile(S - 1, MID, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = MID, y = S - 1, direction = "south", target_zone_id = ""},
		{x = S - 1, y = MID, direction = "east", target_zone_id = ""},
	]


# CHASHITSU (Tea Room): tiny detached tea ceremony building. Austere, intimate.
# Nijiriguchi (small entrance), single tokonoma, 4-6 person capacity.
static func _gen_chashitsu(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	# Surrounding garden.
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_GRASS)

	# Stone path approach from south to tea room.
	for y in range(S - 1, 16, -1):
		map.set_tile(MID, y, Enums.TileType.FLOOR_STONE)

	# Tea room: small 9x9 building centred at (11-19, 8-16).
	_draw_wood_border(map, 11, 8, 19, 16)
	_fill_rect(map, 12, 9, 18, 15, Enums.TileType.FLOOR_TATAMI)

	# Tokonoma alcove (north wall recess).
	_fill_rect(map, 13, 6, 17, 8, Enums.TileType.FLOOR_TATAMI)
	_draw_wood_border(map, 13, 6, 17, 8)
	map.set_tile(MID, 8, Enums.TileType.DOOR_SHOJI_OPEN)

	# Nijiriguchi (small entrance) on south face — single shoji.
	map.set_tile(MID, 16, Enums.TileType.DOOR_SHOJI_OPEN)

	# Garden features: stepping stones, trees, bushes.
	var garden_trees: Array[Vector2i] = [
		Vector2i(5, 5), Vector2i(7, 10), Vector2i(25, 7),
		Vector2i(23, 12), Vector2i(4, 18), Vector2i(26, 20),
	]
	for tp in garden_trees:
		map.set_tile(tp.x, tp.y, Enums.TileType.TREE_CHERRY)

	for _i in range(8 + rng.randi() % 5):
		var bx: int = 2 + rng.randi() % (S - 4)
		var by: int = 2 + rng.randi() % (S - 4)
		if map.get_tile(bx, by) == Enums.TileType.FLOOR_GRASS:
			map.set_tile(bx, by, Enums.TileType.BUSH if rng.randi() % 3 != 0 else Enums.TileType.FLOWERS)

	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# GUEST_WING (Guest Quarters): multiple rooms separated by fusuma/shoji,
# refined but semi-private, each room with tatami.
static func _gen_guest_wing(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_WOOD)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Central corridor running east-west at mid height.
	_fill_rect(map, 1, MID - 1, S - 2, MID + 1, Enums.TileType.FLOOR_WOOD)

	# Guest rooms: 3 rooms on north side, 3 on south side.
	var room_w: int = 8
	for i in range(3):
		var ox: int = 2 + i * (room_w + 2)
		# North rooms.
		_draw_wood_border(map, ox, 1, ox + room_w - 1, MID - 2)
		_fill_rect(map, ox + 1, 2, ox + room_w - 2, MID - 3,
			Enums.TileType.FLOOR_TATAMI)
		# Shoji dividers between rooms.
		map.set_tile(ox + room_w / 2, MID - 2, Enums.TileType.DOOR_SHOJI_OPEN)
		# South rooms.
		_draw_wood_border(map, ox, MID + 2, ox + room_w - 1, S - 2)
		_fill_rect(map, ox + 1, MID + 3, ox + room_w - 2, S - 3,
			Enums.TileType.FLOOR_TATAMI)
		map.set_tile(ox + room_w / 2, MID + 2, Enums.TileType.DOOR_SHOJI_OPEN)

	# Entrance on west.
	map.set_tile(0, MID, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(0, MID, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = 0, y = MID, direction = "west", target_zone_id = ""}]


# LORD_QUARTERS (Lord's Private Chambers): private rooms with fusuma,
# tokonoma alcove, tatami floors, paper-screen exterior walls.
static func _gen_lord_quarters(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_WOOD)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Main chamber: north half.
	_draw_wood_border(map, 3, 2, S - 4, MID - 1)
	_fill_rect(map, 4, 3, S - 5, MID - 2, Enums.TileType.FLOOR_TATAMI)
	# Tokonoma alcove in north wall.
	_fill_rect(map, 12, 2, 18, 2, Enums.TileType.FLOOR_STONE)
	# Door from main chamber to corridor.
	map.set_tile(MID, MID - 1, Enums.TileType.DOOR_SHOJI_OPEN)

	# Private study: south-east.
	_draw_wood_border(map, MID + 2, MID + 2, S - 2, S - 2)
	_fill_rect(map, MID + 3, MID + 3, S - 3, S - 3, Enums.TileType.FLOOR_TATAMI)
	map.set_tile(MID + 2, MID + 5, Enums.TileType.DOOR_SHOJI_OPEN)

	# Sleeping chamber: south-west.
	_draw_wood_border(map, 2, MID + 2, MID - 2, S - 2)
	_fill_rect(map, 3, MID + 3, MID - 3, S - 3, Enums.TileType.FLOOR_TATAMI)
	map.set_tile(MID - 2, MID + 5, Enums.TileType.DOOR_SHOJI_OPEN)

	# Entrance on west wall.
	map.set_tile(0, MID, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(0, MID, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = 0, y = MID, direction = "west", target_zone_id = ""}]


# WAR_COUNCIL_ROOM (Military Planning): functional room with wood floor,
# central table (stone tiles), no art, no performances.
static func _gen_war_council_room(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_WOOD)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Room interior stays wood floor (military, not ceremonial).

	# Central map table: stone tiles in a rectangle.
	_fill_rect(map, 10, 10, 20, 20, Enums.TileType.FLOOR_STONE)

	# Weapon/map racks along walls (wood wall segments).
	for y in range(3, S - 3, 5):
		map.set_tile(2, y, Enums.TileType.WALL_WOOD)
		map.set_tile(S - 3, y, Enums.TileType.WALL_WOOD)

	# Support pillars.
	map.set_tile(8, 8, Enums.TileType.WALL_WOOD)
	map.set_tile(22, 8, Enums.TileType.WALL_WOOD)
	map.set_tile(8, 22, Enums.TileType.WALL_WOOD)
	map.set_tile(22, 22, Enums.TileType.WALL_WOOD)

	# Entrance south.
	map.set_tile(MID, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# DOJO (Training Hall): large open wood floor for martial practice,
# weapon racks along walls, no art.
static func _gen_dojo(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_WOOD)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Training area is open wood floor (already set).

	# Weapon racks along north and south inner walls.
	for x in range(3, S - 3, 3):
		map.set_tile(x, 1, Enums.TileType.WALL_WOOD)
		map.set_tile(x, S - 2, Enums.TileType.WALL_WOOD)

	# Kamiza (spirit seat / shrine alcove) at north-centre.
	_fill_rect(map, 13, 1, 17, 1, Enums.TileType.FLOOR_STONE)

	# Support pillars defining the training rectangle.
	map.set_tile(5, 5, Enums.TileType.WALL_WOOD)
	map.set_tile(S - 6, 5, Enums.TileType.WALL_WOOD)
	map.set_tile(5, S - 6, Enums.TileType.WALL_WOOD)
	map.set_tile(S - 6, S - 6, Enums.TileType.WALL_WOOD)

	# Entrance south.
	map.set_tile(MID, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# OUTER_COURTYARD (Castle Outer Courtyard): large open outdoor space,
# stone paving, mustering point, bonsai display areas, garden edges.
static func _gen_outer_courtyard(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_DIRT)
	_draw_stone_border(map, 0, 0, S - 1, S - 1)

	# Stone-paved central area.
	_fill_rect(map, 5, 5, S - 6, S - 6, Enums.TileType.FLOOR_STONE)

	# Garden patches in corners.
	_fill_rect(map, 1, 1, 4, 4, Enums.TileType.FLOOR_GRASS)
	_fill_rect(map, S - 5, 1, S - 2, 4, Enums.TileType.FLOOR_GRASS)
	_fill_rect(map, 1, S - 5, 4, S - 2, Enums.TileType.FLOOR_GRASS)
	_fill_rect(map, S - 5, S - 5, S - 2, S - 2, Enums.TileType.FLOOR_GRASS)

	# Trees in garden corners.
	map.set_tile(2, 2, Enums.TileType.TREE_CHERRY)
	map.set_tile(S - 3, 2, Enums.TileType.TREE_CHERRY)
	map.set_tile(2, S - 3, Enums.TileType.TREE_DECIDUOUS)
	map.set_tile(S - 3, S - 3, Enums.TileType.TREE_DECIDUOUS)

	# Scattered bushes along edges.
	for _i in range(6 + rng.randi() % 4):
		var bx: int = 1 + rng.randi() % (S - 2)
		var by: int = 1 + rng.randi() % (S - 2)
		if map.get_tile(bx, by) == Enums.TileType.FLOOR_GRASS:
			map.set_tile(bx, by, Enums.TileType.BUSH)

	# Gate on south wall.
	map.set_tile(MID - 1, S - 1, Enums.TileType.GATE_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.GATE_OPEN)
	map.set_tile(MID + 1, S - 1, Enums.TileType.GATE_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)

	# North entrance to inner castle.
	map.set_tile(MID, 0, Enums.TileType.GATE_OPEN)
	map.set_tile(MID, 0, Enums.TileType.ZONE_EXIT)

	map.exits = [
		{x = MID, y = S - 1, direction = "south", target_zone_id = ""},
		{x = MID, y = 0, direction = "north", target_zone_id = ""},
	]


# TSUBONIWA (Inner Courtyard Garden): small enclosed garden between buildings,
# stone path, moss, flowers, small water feature. Contemplation space.
static func _gen_tsuboniwa(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	# Surrounding building walls.
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.WALL_WOOD)

	# Garden interior.
	_fill_rect(map, 3, 3, S - 4, S - 4, Enums.TileType.FLOOR_GRASS)

	# Stone stepping path winding through garden.
	var px: int = MID
	for y in range(S - 4, 3, -1):
		map.set_tile(px, y, Enums.TileType.FLOOR_STONE)
		if rng.randi() % 3 == 0:
			px = clampi(px + ((rng.randi() % 3) - 1), 4, S - 5)

	# Small water feature (pond) in north-east area.
	_fill_rect(map, 19, 5, 24, 9, Enums.TileType.WATER_SHALLOW)

	# Moss groundcover.
	for _i in range(20 + rng.randi() % 10):
		var gx: int = 4 + rng.randi() % (S - 8)
		var gy: int = 4 + rng.randi() % (S - 8)
		if map.get_tile(gx, gy) == Enums.TileType.FLOOR_GRASS:
			map.set_tile(gx, gy, Enums.TileType.GROUNDCOVER)

	# Flowers and small trees.
	var tree_spots: Array[Vector2i] = [
		Vector2i(6, 6), Vector2i(10, 12), Vector2i(24, 18),
		Vector2i(8, 22), Vector2i(20, 24),
	]
	for tp in tree_spots:
		if map.get_tile(tp.x, tp.y) == Enums.TileType.FLOOR_GRASS or \
		   map.get_tile(tp.x, tp.y) == Enums.TileType.GROUNDCOVER:
			map.set_tile(tp.x, tp.y, Enums.TileType.TREE_CHERRY)

	for _i in range(8 + rng.randi() % 6):
		var fx: int = 4 + rng.randi() % (S - 8)
		var fy: int = 4 + rng.randi() % (S - 8)
		if map.get_tile(fx, fy) == Enums.TileType.FLOOR_GRASS:
			map.set_tile(fx, fy, Enums.TileType.FLOWERS)

	# Engawa (veranda) access on south wall — shoji doors.
	_fill_rect(map, 3, S - 4, S - 4, S - 4, Enums.TileType.WALL_PAPER)
	map.set_tile(MID, S - 4, Enums.TileType.DOOR_SHOJI_OPEN)
	_fill_rect(map, 3, S - 3, S - 4, S - 3, Enums.TileType.FLOOR_WOOD)

	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# CASTLE_SHRINE (Compound Shrine): small Shinto shrine within castle walls.
# Torii gate, stone altar area, small timber building.
static func _gen_castle_shrine(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_STONE)
	_draw_stone_border(map, 0, 0, S - 1, S - 1)

	# Grassy garden areas flanking the approach path.
	_fill_rect(map, 2, 12, 11, S - 3, Enums.TileType.FLOOR_GRASS)
	_fill_rect(map, 19, 12, S - 3, S - 3, Enums.TileType.FLOOR_GRASS)

	# Shrine building: small wood structure at north.
	_draw_wood_border(map, 10, 3, 20, 10)
	_fill_rect(map, 11, 4, 19, 9, Enums.TileType.FLOOR_TATAMI)
	map.set_tile(MID, 10, Enums.TileType.DOOR_WOOD_OPEN)

	# Altar stone in front of shrine.
	_fill_rect(map, 13, 11, 17, 11, Enums.TileType.FLOOR_STONE)

	# Torii gate at south approach.
	map.set_tile(13, 24, Enums.TileType.WALL_WOOD)
	map.set_tile(17, 24, Enums.TileType.WALL_WOOD)
	map.set_tile(13, 23, Enums.TileType.WALL_WOOD)
	map.set_tile(17, 23, Enums.TileType.WALL_WOOD)
	map.set_tile(14, 23, Enums.TileType.WALL_WOOD)
	map.set_tile(16, 23, Enums.TileType.WALL_WOOD)

	# Trees around shrine grounds.
	var tree_spots: Array[Vector2i] = [
		Vector2i(4, 15), Vector2i(6, 20), Vector2i(3, 25),
		Vector2i(24, 15), Vector2i(26, 20), Vector2i(25, 25),
	]
	for tp in tree_spots:
		if map.get_tile(tp.x, tp.y) == Enums.TileType.FLOOR_GRASS:
			map.set_tile(tp.x, tp.y, Enums.TileType.TREE_EVERGREEN)

	# South exit.
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	# Clear stone wall at exit.
	map.set_tile(MID - 1, S - 1, Enums.TileType.FLOOR_STONE)
	map.set_tile(MID + 1, S - 1, Enums.TileType.FLOOR_STONE)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# PLEASURE_QUARTER: lantern-lit streets, geisha houses and sake houses,
# high NPC density at night. More buildings than market, narrower streets.
static func _gen_pleasure_quarter(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_STONE)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Main street: north-south through centre.
	_fill_rect(map, MID - 2, 0, MID + 2, S - 1, Enums.TileType.FLOOR_STONE)

	# West block: 3 buildings (geisha houses).
	var bh: int = 8
	for i in range(3):
		var oy: int = 2 + i * (bh + 1)
		if oy + bh < S - 1:
			_draw_wood_border(map, 1, oy, MID - 4, oy + bh)
			_fill_rect(map, 2, oy + 1, MID - 5, oy + bh - 1, Enums.TileType.FLOOR_TATAMI)
			map.set_tile(MID - 4, oy + bh / 2, Enums.TileType.DOOR_SHOJI_OPEN)

	# East block: 3 buildings (sake houses).
	for i in range(3):
		var oy: int = 2 + i * (bh + 1)
		if oy + bh < S - 1:
			_draw_wood_border(map, MID + 4, oy, S - 2, oy + bh)
			_fill_rect(map, MID + 5, oy + 1, S - 3, oy + bh - 1, Enums.TileType.FLOOR_TATAMI)
			map.set_tile(MID + 4, oy + bh / 2, Enums.TileType.DOOR_SHOJI_OPEN)

	# Zone exits north and south on main street.
	map.set_tile(MID, 0, Enums.TileType.ZONE_EXIT)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = MID, y = 0, direction = "north", target_zone_id = ""},
		{x = MID, y = S - 1, direction = "south", target_zone_id = ""},
	]


# DOCKS_WATERFRONT: piers extending into water, warehouses on land,
# cargo areas, water tiles on south side.
static func _gen_docks_waterfront(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	# Water on south half.
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.WATER_DEEP)

	# Land on north half (rows 0–14).
	_fill_rect(map, 0, 0, S - 1, 14, Enums.TileType.FLOOR_DIRT)

	# Shoreline: shallow water at row 15.
	_fill_rect(map, 0, 15, S - 1, 15, Enums.TileType.WATER_SHALLOW)

	# Warehouses along north edge.
	var wh_count: int = 3 + (rng.randi() % 2)
	var wh_w: int = (S - 2) / wh_count
	for i in range(wh_count):
		var ox: int = 1 + i * wh_w
		_draw_wood_box(map, ox, 1, ox + wh_w - 2, 7)
		_fill_rect(map, ox + 1, 2, ox + wh_w - 3, 6, Enums.TileType.FLOOR_WOOD)
		map.set_tile(ox + wh_w / 2, 7, Enums.TileType.DOOR_WOOD_OPEN)

	# Stone quay along waterfront.
	_fill_rect(map, 0, 12, S - 1, 14, Enums.TileType.FLOOR_STONE)

	# Piers extending into water (wood floor strips).
	for px in range(4, S - 4, 8):
		_fill_rect(map, px, 15, px + 1, S - 4, Enums.TileType.FLOOR_WOOD)

	# Zone exits east and west along land edge.
	map.set_tile(0, 8, Enums.TileType.ZONE_EXIT)
	map.set_tile(S - 1, 8, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = 0, y = 8, direction = "west", target_zone_id = ""},
		{x = S - 1, y = 8, direction = "east", target_zone_id = ""},
	]


# POOR_QUARTER: cramped narrow alleys, run-down buildings, muddy areas.
# Dense small buildings, dirt and mud floors.
static func _gen_poor_quarter(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_DIRT)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Dense grid of small shacks: 4x4 grid of tiny buildings.
	var plot_w: int = 6
	var plot_h: int = 6
	for row in range(4):
		for col in range(4):
			var ox: int = 1 + col * (plot_w + 1)
			var oy: int = 1 + row * (plot_h + 1)
			if ox + plot_w - 1 >= S - 1 or oy + plot_h - 1 >= S - 1:
				continue
			_draw_wood_box(map, ox, oy, ox + plot_w - 1, oy + plot_h - 1)
			_fill_rect(map, ox + 1, oy + 1, ox + plot_w - 2, oy + plot_h - 2,
				Enums.TileType.FLOOR_WOOD)
			# Random door placement.
			var door_side: int = rng.randi() % 2
			if door_side == 0:
				map.set_tile(ox + plot_w / 2, oy + plot_h - 1,
					Enums.TileType.DOOR_WOOD_OPEN)
			else:
				map.set_tile(ox + plot_w - 1, oy + plot_h / 2,
					Enums.TileType.DOOR_WOOD_OPEN)

	# Muddy patches in alleys.
	for _i in range(15 + rng.randi() % 10):
		var mx: int = 1 + rng.randi() % (S - 2)
		var my: int = 1 + rng.randi() % (S - 2)
		if map.get_tile(mx, my) == Enums.TileType.FLOOR_DIRT:
			map.set_tile(mx, my, Enums.TileType.FLOOR_MUD)

	# Zone exits east and west.
	map.set_tile(0, MID, Enums.TileType.ZONE_EXIT)
	map.set_tile(S - 1, MID, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = 0, y = MID, direction = "west", target_zone_id = ""},
		{x = S - 1, y = MID, direction = "east", target_zone_id = ""},
	]


# GOVERNMENT_QUARTER: magistrate offices, record halls, stone buildings,
# orderly grid layout, formal stone-floor streets.
static func _gen_government_quarter(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_STONE)
	_draw_stone_border(map, 0, 0, S - 1, S - 1)

	# Two large administrative buildings: north and south of central plaza.
	# North building (magistrate office).
	_draw_stone_border(map, 3, 2, S - 4, 11)
	_fill_rect(map, 4, 3, S - 5, 10, Enums.TileType.FLOOR_TATAMI)
	map.set_tile(MID, 11, Enums.TileType.DOOR_WOOD_OPEN)

	# South building (record hall).
	_draw_stone_border(map, 3, 19, S - 4, S - 3)
	_fill_rect(map, 4, 20, S - 5, S - 4, Enums.TileType.FLOOR_TATAMI)
	map.set_tile(MID, 19, Enums.TileType.DOOR_WOOD_OPEN)

	# Central plaza between buildings (stone floor, already set).
	# Guard post (small stone structure) in plaza.
	_draw_stone_border(map, 13, 13, 17, 17)
	_fill_rect(map, 14, 14, 16, 16, Enums.TileType.FLOOR_WOOD)
	map.set_tile(MID, 17, Enums.TileType.DOOR_WOOD_OPEN)

	# Zone exits east and west.
	map.set_tile(0, MID, Enums.TileType.ZONE_EXIT)
	map.set_tile(S - 1, MID, Enums.TileType.ZONE_EXIT)
	# Clear wall at exits.
	map.set_tile(0, MID - 1, Enums.TileType.FLOOR_STONE)
	map.set_tile(0, MID + 1, Enums.TileType.FLOOR_STONE)
	map.set_tile(S - 1, MID - 1, Enums.TileType.FLOOR_STONE)
	map.set_tile(S - 1, MID + 1, Enums.TileType.FLOOR_STONE)
	map.exits = [
		{x = 0, y = MID, direction = "west", target_zone_id = ""},
		{x = S - 1, y = MID, direction = "east", target_zone_id = ""},
	]


# MOUNTAIN_PASS: rocky terrain, narrow winding path between cliff faces,
# steep elevation, weather exposure.
static func _gen_mountain_pass(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.WALL_STONE)

	# Carve a winding path through the rock.
	var path_x: int = MID
	for y in range(S - 1, -1, -1):
		var drift: int = (rng.randi() % 3) - 1
		path_x = clampi(path_x + drift, 4, S - 5)
		# Path: 3-5 tiles wide.
		var w: int = 1 + rng.randi() % 2
		for dx in range(-w, w + 1):
			var tx: int = path_x + dx
			if tx >= 0 and tx < S:
				map.set_tile(tx, y, Enums.TileType.FLOOR_STONE)

	# Widen a few areas into small clearings.
	for _i in range(2 + rng.randi() % 2):
		var cy: int = 5 + rng.randi() % (S - 10)
		for dy in range(-2, 3):
			for dx in range(-3, 4):
				var tx: int = path_x + dx
				var ty: int = cy + dy
				if tx >= 1 and tx < S - 1 and ty >= 0 and ty < S:
					if map.get_tile(tx, ty) == Enums.TileType.WALL_STONE:
						map.set_tile(tx, ty, Enums.TileType.FLOOR_DIRT)

	# Scattered dead trees and bushes on path edges.
	for _i in range(8 + rng.randi() % 6):
		var bx: int = 2 + rng.randi() % (S - 4)
		var by: int = 2 + rng.randi() % (S - 4)
		if map.get_tile(bx, by) == Enums.TileType.FLOOR_STONE or \
		   map.get_tile(bx, by) == Enums.TileType.FLOOR_DIRT:
			var adj_wall: bool = false
			for d in [Vector2i(-1,0), Vector2i(1,0), Vector2i(0,-1), Vector2i(0,1)]:
				if map.get_tile(bx + d.x, by + d.y) == Enums.TileType.WALL_STONE:
					adj_wall = true
					break
			if adj_wall:
				map.set_tile(bx, by, Enums.TileType.BUSH if rng.randi() % 2 == 0 else Enums.TileType.TREE_DEAD)

	# Zone exits north and south.
	map.set_tile(MID, 0, Enums.TileType.ZONE_EXIT)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	# Ensure exit tiles are passable.
	for ey in [0, S - 1]:
		if not AsciiMapData.is_passable(map.get_tile(MID, ey)):
			map.set_tile(MID, ey, Enums.TileType.FLOOR_STONE)
		map.set_tile(MID, ey, Enums.TileType.ZONE_EXIT)

	map.exits = [
		{x = MID, y = 0, direction = "north", target_zone_id = ""},
		{x = MID, y = S - 1, direction = "south", target_zone_id = ""},
	]


# WALL_TOWER (Kaiu Wall Tower): stone fortification, battlements,
# defensive structure with arrow slits and lookout positions.
static func _gen_wall_tower(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_STONE)
	_draw_stone_border(map, 0, 0, S - 1, S - 1)

	# Outer battlements: crenellated stone wall (gaps every 3 tiles).
	for x in range(0, S):
		if x % 3 == 0:
			map.set_tile(x, 0, Enums.TileType.FLOOR_STONE)
			map.set_tile(x, S - 1, Enums.TileType.FLOOR_STONE)
	for y in range(0, S):
		if y % 3 == 0:
			map.set_tile(0, y, Enums.TileType.FLOOR_STONE)
			map.set_tile(S - 1, y, Enums.TileType.FLOOR_STONE)

	# Inner tower structure: thick stone walls forming central room.
	_draw_stone_border(map, 8, 8, 22, 22)

	# Interior: wood floor (garrison quarters).
	_fill_rect(map, 9, 9, 21, 21, Enums.TileType.FLOOR_WOOD)

	# Central pillar / stairwell (stone).
	_fill_rect(map, 13, 13, 17, 17, Enums.TileType.WALL_STONE)

	# Doors on all four faces of inner tower.
	map.set_tile(MID, 8, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID, 22, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(8, MID, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(22, MID, Enums.TileType.DOOR_WOOD_OPEN)

	# Weapon racks inside (wood wall segments).
	for y in range(10, 13):
		map.set_tile(9, y, Enums.TileType.WALL_WOOD)
		map.set_tile(21, y, Enums.TileType.WALL_WOOD)

	# Exit south (connects to wall walkway).
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


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
