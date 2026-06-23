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


const S: int = 31    # default zone dimension (viewport is also 31×31)
const MID: int = 15  # S / 2


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
		Enums.ZoneSubtype.PEASANT_DWELLING:
			_gen_peasant_dwelling(map, rng)
		Enums.ZoneSubtype.UNDERGROUND_LAKE:
			_gen_underground_lake(map, rng)
		Enums.ZoneSubtype.THRONE_ROOM:
			_gen_throne_room(map, rng)
		Enums.ZoneSubtype.LABYRINTH:
			_gen_labyrinth(map, rng)
		Enums.ZoneSubtype.ONI_WARAI:
			_gen_oni_warai(map, rng)
		Enums.ZoneSubtype.RUINED_STRUCTURE:
			_gen_ruined_structure(map, rng)
		Enums.ZoneSubtype.BARRACKS:
			_gen_barracks(map, rng)
		Enums.ZoneSubtype.LIBRARY:
			_gen_library(map, rng)
		Enums.ZoneSubtype.TOMB:
			_gen_tomb(map, rng)
		Enums.ZoneSubtype.TREASURY_VAULT:
			_gen_treasury_vault(map, rng)
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
		Enums.TileType.FURNITURE_FUTON:   return "▬"
		Enums.TileType.FURNITURE_HEARTH:  return "▦"
		Enums.TileType.FURNITURE_CHEST:   return "▥"
		Enums.TileType.FURNITURE_TABLE:   return "╥"
		Enums.TileType.FURNITURE_JAR:     return "◍"
		Enums.TileType.FURNITURE_SCREEN:  return "║"
		Enums.TileType.FURNITURE_BRAZIER: return "†"
		Enums.TileType.FURNITURE_CUSHION: return "▫"
		Enums.TileType.FURNITURE_DAIS:         return "⊓"
		Enums.TileType.FURNITURE_BANNER:       return "╤"
		Enums.TileType.FURNITURE_WEAPON_STAND: return "Ψ"
		Enums.TileType.FURNITURE_ALTAR:        return "⊥"
		Enums.TileType.FURNITURE_OFFERING_BOX: return "▣"
		Enums.TileType.FURNITURE_INCENSE:      return "§"
		Enums.TileType.FURNITURE_STATUE:       return "☗"
		Enums.TileType.FURNITURE_PRAYER_MAT:   return "▭"
		Enums.TileType.FURNITURE_STALL:        return "╦"
		Enums.TileType.FURNITURE_CRATE:        return "▧"
		Enums.TileType.FURNITURE_NET:          return "╳"
		Enums.TileType.FURNITURE_WELL:         return "◉"
		Enums.TileType.FURNITURE_DUMMY:        return "‡"
		Enums.TileType.FURNITURE_SHELF:        return "▤"
		Enums.TileType.FURNITURE_STOVE:        return "◫"
		Enums.TileType.FURNITURE_BENCH:        return "╨"
	return "?"


# Elevation shade (s4.4 Z-axis "roofing/elevation indicators"; owner-approved
# 2026-06-23). Brightens a tile's foreground colour by its elevation level so
# raised ground reads as higher — without a new symbol (symbol = tile type) or a
# background tint (reserved for water/taint/spirit). Low visual weight, per the
# s4.4 rendering principles. Level 0 = base (a no-op); each level scales colour
# value by +ELEVATION_SHADE_STEP, clamped to valid range.
const ELEVATION_SHADE_STEP: float = 0.2

static func elevation_shade(color: Color, level: int) -> Color:
	if level <= 0:
		return color
	var f: float = 1.0 + float(level) * ELEVATION_SHADE_STEP
	return Color(
		minf(color.r * f, 1.0), minf(color.g * f, 1.0), minf(color.b * f, 1.0), color.a)


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
		Enums.TileType.FURNITURE_FUTON:   return Color(0.6, 0.6, 0.75)
		Enums.TileType.FURNITURE_HEARTH:  return Color(0.8, 0.4, 0.1)
		Enums.TileType.FURNITURE_CHEST:   return Color(0.5, 0.35, 0.2)
		Enums.TileType.FURNITURE_TABLE:   return Color(0.55, 0.4, 0.25)
		Enums.TileType.FURNITURE_JAR:     return Color(0.6, 0.45, 0.35)
		Enums.TileType.FURNITURE_SCREEN:  return Color(0.85, 0.8, 0.7)
		Enums.TileType.FURNITURE_BRAZIER: return Color(0.9, 0.6, 0.2)
		Enums.TileType.FURNITURE_CUSHION: return Color(0.6, 0.3, 0.35)
		Enums.TileType.FURNITURE_DAIS:         return Color(0.6, 0.15, 0.2)
		Enums.TileType.FURNITURE_BANNER:       return Color(0.75, 0.2, 0.25)
		Enums.TileType.FURNITURE_WEAPON_STAND: return Color(0.55, 0.4, 0.25)
		Enums.TileType.FURNITURE_ALTAR:        return Color(0.7, 0.65, 0.5)
		Enums.TileType.FURNITURE_OFFERING_BOX: return Color(0.8, 0.65, 0.25)
		Enums.TileType.FURNITURE_INCENSE:      return Color(0.85, 0.7, 0.5)
		Enums.TileType.FURNITURE_STATUE:       return Color(0.55, 0.55, 0.55)
		Enums.TileType.FURNITURE_PRAYER_MAT:   return Color(0.6, 0.5, 0.6)
		Enums.TileType.FURNITURE_STALL:        return Color(0.6, 0.42, 0.22)
		Enums.TileType.FURNITURE_CRATE:        return Color(0.55, 0.4, 0.2)
		Enums.TileType.FURNITURE_NET:          return Color(0.7, 0.7, 0.55)
		Enums.TileType.FURNITURE_WELL:         return Color(0.5, 0.5, 0.55)
		Enums.TileType.FURNITURE_DUMMY:        return Color(0.6, 0.45, 0.3)
		Enums.TileType.FURNITURE_SHELF:        return Color(0.5, 0.35, 0.2)
		Enums.TileType.FURNITURE_STOVE:        return Color(0.45, 0.4, 0.4)
		Enums.TileType.FURNITURE_BENCH:        return Color(0.55, 0.4, 0.25)
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

	# Vendor stalls along road edges: a counter + a crate of goods on rows 12/18.
	for i in range(2, S - 3, 4):
		map.set_tile(i, 12, Enums.TileType.FURNITURE_STALL)
		map.set_tile(i + 1, 12, Enums.TileType.FURNITURE_CRATE)
		map.set_tile(i, 18, Enums.TileType.FURNITURE_STALL)
		map.set_tile(i + 1, 18, Enums.TileType.FURNITURE_CRATE)

	# Vendor stalls must never seal a passage to the road. Wherever an open tile
	# (a shop door or an inter-shop alley gap) sits directly above row 12 or
	# below row 18, clear the stall in front of it so every passage reaches the
	# central road band. Stalls in front of solid shop walls remain.
	for x in range(1, S - 1):
		if _is_passable_floor(map.get_tile(x, 11)):
			map.set_tile(x, 12, Enums.TileType.FLOOR_STONE)
		if _is_passable_floor(map.get_tile(x, 19)):
			map.set_tile(x, 18, Enums.TileType.FLOOR_STONE)

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

	# Sanctum: altar with offering box, incense burners, flanking Fortune statues,
	# prayer mats for worshippers.
	map.set_tile(MID, 5, Enums.TileType.FURNITURE_ALTAR)
	map.set_tile(MID, 7, Enums.TileType.FURNITURE_OFFERING_BOX)
	map.set_tile(13, 6, Enums.TileType.FURNITURE_INCENSE)
	map.set_tile(17, 6, Enums.TileType.FURNITURE_INCENSE)
	map.set_tile(11, 5, Enums.TileType.FURNITURE_STATUE)
	map.set_tile(19, 5, Enums.TileType.FURNITURE_STATUE)
	map.set_tile(14, 11, Enums.TileType.FURNITURE_PRAYER_MAT)
	map.set_tile(16, 11, Enums.TileType.FURNITURE_PRAYER_MAT)
	# Komainu guardian statues flanking the courtyard approach.
	map.set_tile(11, 18, Enums.TileType.FURNITURE_STATUE)
	map.set_tile(19, 18, Enums.TileType.FURNITURE_STATUE)

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

	# Clearing: ellipse center=(15,15), semi-axes=(8,9). Full y extent = [6, 24].
	for y in range(6, 25):
		for x in range(7, 24):
			var dx: float = (x - MID) / 8.0
			var dy: float = (y - MID) / 9.0
			if dx * dx + dy * dy < 1.0:
				map.set_tile(x, y, Enums.TileType.FLOOR_GRASS)

	# Shrine building: rows 10–16, columns 12–18.
	_draw_wood_box(map, 12, 10, 18, 16)
	_fill_rect(map, 13, 11, 17, 15, Enums.TileType.FLOOR_TATAMI)
	map.set_tile(MID, 16, Enums.TileType.DOOR_WOOD_OPEN)
	# Altar with offering box and a prayer mat inside; komainu guardians in the
	# clearing flank the path to the torii (clear of the door column).
	map.set_tile(MID, 11, Enums.TileType.FURNITURE_ALTAR)
	map.set_tile(16, 12, Enums.TileType.FURNITURE_OFFERING_BOX)
	map.set_tile(MID, 14, Enums.TileType.FURNITURE_PRAYER_MAT)
	map.set_tile(13, 19, Enums.TileType.FURNITURE_STATUE)
	map.set_tile(17, 19, Enums.TileType.FURNITURE_STATUE)

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

	# Zone exits sit on the path where it meets each edge. The south end is
	# always at MID (the loop starts there); the north end follows the drifted
	# path_x so the exit never lands in the trees.
	var north_x: int = path_x
	map.set_tile(north_x, 0, Enums.TileType.ZONE_EXIT)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = north_x, y = 0, direction = "north", target_zone_id = ""},
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
			# Commoner home: irori hearth, sleeping mat, water jar — placed in the
			# corners, clear of the central door column (ox + plot_w / 2).
			map.set_tile(ox + 2, oy + 2, Enums.TileType.FURNITURE_HEARTH)
			map.set_tile(ox + plot_w - 3, oy + plot_h - 3, Enums.TileType.FURNITURE_FUTON)
			map.set_tile(ox + 2, oy + plot_h - 3, Enums.TileType.FURNITURE_JAR)
			# Door faces the adjacent alley. South face when an alley lies below;
			# bottom-row plots open north instead so the door never abuts the
			# perimeter wall (which would seal the interior).
			var door_x: int = ox + plot_w / 2
			var south_row: int = oy + plot_h - 1
			if south_row + 1 <= S - 2:
				map.set_tile(door_x, south_row, Enums.TileType.DOOR_WOOD_OPEN)
			else:
				map.set_tile(door_x, oy, Enums.TileType.DOOR_WOOD_OPEN)

	# Small shrine in south-east corner (overwriting one house plot).
	var sx: int = 1 + 2 * (plot_w + 1)
	var sy: int = 1 + 2 * (plot_h + 1)
	if sx + 7 < S and sy + 7 < S:
		_fill_rect(map, sx, sy, sx + plot_w - 1, sy + plot_h - 1, Enums.TileType.FLOOR_STONE)
		_draw_stone_border(map, sx, sy, sx + plot_w - 1, sy + plot_h - 1)
		# North face — the shrine sits in the bottom-right plot, whose south wall
		# abuts the perimeter; opening north reaches the y=20 alley.
		var shrine_south: int = sy + plot_h - 1
		if shrine_south + 1 <= S - 2:
			map.set_tile(sx + plot_w / 2, shrine_south, Enums.TileType.DOOR_SHOJI_OPEN)
		else:
			map.set_tile(sx + plot_w / 2, sy, Enums.TileType.DOOR_SHOJI_OPEN)

	# Zone exits sit on the open inter-plot alleys (y=10 and y=20), not the map
	# mid-row — MID lands on the middle row of houses, which would wall the exit
	# off from the interior.
	var west_exit_y: int = 1 + plot_h  # 10: alley between plot rows 0 and 1
	var east_exit_y: int = 1 + 2 * plot_h + 1  # 20: alley between rows 1 and 2
	map.set_tile(0, west_exit_y, Enums.TileType.ZONE_EXIT)
	map.set_tile(S - 1, east_exit_y, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = 0, y = west_exit_y, direction = "west", target_zone_id = ""},
		{x = S - 1, y = east_exit_y, direction = "east", target_zone_id = ""},
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


# UNDERGROUND_LAKE (s2.3.23): the small subterranean lake beneath the Juramashi
# District. A hidden tunnel from the ground level above descends (the single zone
# exit) to a stone shore; the deep water is impassable, so a treacherous wadeable
# causeway is the only approach to a central island ringed by sharp coral (RUBBLE,
# difficult + cover) and jagged rocks (WALL_STONE, impassable). On the island sits
# the criminal trading post (a small wooden hut). A bed of Naga eggs lies hidden
# within the coral — lore only; no spawn/encounter mechanic until the s56 quest
# layer. Deterministic from the caller's seeded rng.
static func _gen_underground_lake(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	# Solid cavern rock.
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.WALL_STONE)

	# Carve the lake: an ellipse of deep water, leaving a rock rim at the edges.
	var cx: int = MID
	var cy: int = MID + 1
	var rx: int = 12
	var ry: int = 10
	for y in range(1, S - 1):
		for x in range(1, S - 1):
			var ex: float = float(x - cx) / float(rx)
			var ey: float = float(y - cy) / float(ry)
			if ex * ex + ey * ey <= 1.0:
				map.set_tile(x, y, Enums.TileType.WATER_DEEP)

	# Hidden entrance tunnel down from Juramashi + a small stone shore landing.
	for y in range(0, 4):
		map.set_tile(MID, y, Enums.TileType.FLOOR_STONE)
	_fill_rect(map, MID - 2, 3, MID + 2, 4, Enums.TileType.FLOOR_STONE)

	# Central island (the criminal trading post stands here).
	var ix: int = cx
	var iy: int = cy
	for y in range(iy - 3, iy + 4):
		for x in range(ix - 3, ix + 4):
			if x < 1 or x >= S - 1 or y < 1 or y >= S - 1:
				continue
			var dx: float = float(x - ix) / 3.0
			var dy: float = float(y - iy) / 3.0
			if dx * dx + dy * dy <= 1.0:
				map.set_tile(x, y, Enums.TileType.FLOOR_STONE)

	# Coral + jagged-rock ring (annulus) around the island. North column is left
	# clear for the causeway approach. The Naga egg bed hides within this coral.
	for y in range(iy - 5, iy + 6):
		for x in range(ix - 5, ix + 6):
			if x < 1 or x >= S - 1 or y < 1 or y >= S - 1:
				continue
			var ed: float = pow(float(x - ix) / 5.0, 2.0) + pow(float(y - iy) / 5.0, 2.0)
			if ed > 1.0 or ed < 0.5:
				continue
			if map.get_tile(x, y) == Enums.TileType.FLOOR_STONE:
				continue
			if x >= ix - 1 and x <= ix + 1 and y < iy:
				continue  # north gap for the causeway
			if rng.randi() % 4 == 0:
				map.set_tile(x, y, Enums.TileType.WALL_STONE)  # jagged rock
			else:
				map.set_tile(x, y, Enums.TileType.RUBBLE)       # sharp coral

	# Causeway: a wadeable shallow path from the shore across the deep water to the
	# island — the only safe approach (the rest of the lake is impassable).
	for y in range(4, iy - 2):
		map.set_tile(MID, y, Enums.TileType.WATER_SHALLOW)

	# Criminal trading post: a small wooden hut on the island, door facing the causeway.
	_fill_rect(map, ix - 1, iy - 1, ix + 1, iy + 1, Enums.TileType.FLOOR_WOOD)
	map.set_tile(ix - 1, iy - 1, Enums.TileType.WALL_WOOD)
	map.set_tile(ix + 1, iy - 1, Enums.TileType.WALL_WOOD)
	map.set_tile(ix - 1, iy + 1, Enums.TileType.WALL_WOOD)
	map.set_tile(ix + 1, iy + 1, Enums.TileType.WALL_WOOD)
	map.set_tile(ix, iy - 1, Enums.TileType.DOOR_WOOD_CLOSED)

	# Single zone exit — the hidden tunnel back up to the Juramashi District.
	map.set_tile(MID, 0, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = MID, y = 0, direction = "north", target_zone_id = ""},
	]


# LABYRINTH (s2.3.23): the Emperor's Labyrinth — a maze of tunnels beneath the
# Forbidden City. Ancient Scorpion wards leave anyone without Hantei blood
# "hopelessly lost," so the layout is a true perfect maze (a randomized
# depth-first spanning tree over a cell grid: full connectivity, many dead ends).
# Two exits: the hidden palace entrance (north) and the escape route to the shore
# of the Bay of the Golden Sun (south). Deterministic from the caller's seeded rng.
static func _gen_labyrinth(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.WALL_STONE)

	# Maze cells sit on odd tile coordinates; walls between them on even ones.
	var cols: int = (S - 1) / 2  # 15 cells per axis
	var rows: int = (S - 1) / 2
	var visited: Dictionary = {}
	var stack: Array[Vector2i] = []
	var start: Vector2i = Vector2i(0, 0)
	map.set_tile(1, 1, Enums.TileType.FLOOR_STONE)
	visited["0_0"] = true
	stack.append(start)
	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	while not stack.is_empty():
		var c: Vector2i = stack[stack.size() - 1]
		var unvisited: Array[Vector2i] = []
		for d in dirs:
			var ni: int = c.x + d.x
			var nj: int = c.y + d.y
			if ni >= 0 and ni < cols and nj >= 0 and nj < rows \
					and not visited.has(str(ni) + "_" + str(nj)):
				unvisited.append(Vector2i(ni, nj))
		if unvisited.is_empty():
			stack.pop_back()
			continue
		var n: Vector2i = unvisited[rng.randi() % unvisited.size()]
		# Carve the wall between c and n, and the n cell itself.
		var cx: int = 2 * c.x + 1
		var cy: int = 2 * c.y + 1
		var nx: int = 2 * n.x + 1
		var ny: int = 2 * n.y + 1
		map.set_tile((cx + nx) / 2, (cy + ny) / 2, Enums.TileType.FLOOR_STONE)
		map.set_tile(nx, ny, Enums.TileType.FLOOR_STONE)
		visited[str(n.x) + "_" + str(n.y)] = true
		stack.append(n)

	# Two exits, both opening onto carved cells (the maze is fully connected).
	map.set_tile(MID, 0, Enums.TileType.ZONE_EXIT)          # hidden palace entrance
	map.set_tile(MID, 1, Enums.TileType.FLOOR_STONE)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)      # escape to the Bay
	map.set_tile(MID, S - 2, Enums.TileType.FLOOR_STONE)
	map.exits = [
		{x = MID, y = 0, direction = "north", target_zone_id = ""},
		{x = MID, y = S - 1, direction = "south", target_zone_id = ""},
	]


# ONI_WARAI (s2.3.23): the Oni's Smile — a massive earthquake crevice. Walkable
# rock ledges flank a bottomless VOID chasm (the deadly depths: explorers return
# blind, mad, or not at all). A treacherous rubble rock-bridge crosses near the
# middle. One surface exit (north); the chasm is a dead-end abyss, not a through
# route. Deterministic from the caller's seeded rng.
static func _gen_oni_warai(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.WALL_STONE)

	# The chasm: a bottomless gash down the centre (impassable VOID).
	_fill_rect(map, 7, 2, S - 8, S - 3, Enums.TileType.VOID)
	# Walkable rock ledges on each side of the gash.
	_fill_rect(map, 3, 2, 6, S - 3, Enums.TileType.FLOOR_STONE)
	_fill_rect(map, S - 7, 2, S - 4, S - 3, Enums.TileType.FLOOR_STONE)
	# Jagged broken rock along the ledge edges.
	for y in range(2, S - 2):
		if rng.randi() % 3 == 0:
			map.set_tile(6, y, Enums.TileType.RUBBLE)
		if rng.randi() % 3 == 0:
			map.set_tile(S - 7, y, Enums.TileType.RUBBLE)
	# A treacherous rubble bridge crossing the chasm near the middle.
	_fill_rect(map, 7, MID, S - 8, MID, Enums.TileType.RUBBLE)

	# Single surface entrance at the top of the left ledge.
	map.set_tile(4, 0, Enums.TileType.ZONE_EXIT)
	map.set_tile(4, 1, Enums.TileType.FLOOR_STONE)
	map.exits = [{x = 4, y = 0, direction = "north", target_zone_id = ""}]


# RUINED_STRUCTURE (s2.3.23): a collapsed, haunted building (e.g. Tenari's ruins,
# an earthquake-destroyed estate). An original floor plan with ~35% of its walls
# collapsed into rubble and debris strewn across the floors; a few rooms remain
# intact. A cleared spine guarantees the entrance reaches the interior. Mirrors
# the s56 ruined-structure approach on the zone tile grid. Deterministic.
static func _gen_ruined_structure(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_DIRT)  # overgrown grounds

	# Original building shell + interior cross-walls (four rooms).
	var x1: int = 4
	var y1: int = 4
	var x2: int = S - 5
	var y2: int = S - 5
	_fill_rect(map, x1 + 1, y1 + 1, x2 - 1, y2 - 1, Enums.TileType.FLOOR_WOOD)
	_draw_stone_border(map, x1, y1, x2, y2)
	for y in range(y1, y2 + 1):
		map.set_tile(MID, y, Enums.TileType.WALL_STONE)
	for x in range(x1, x2 + 1):
		map.set_tile(x, MID, Enums.TileType.WALL_STONE)

	# Collapse: ~35% of wall tiles fall to rubble; ~12% of floors gather debris.
	for y in range(y1, y2 + 1):
		for x in range(x1, x2 + 1):
			var t: int = map.get_tile(x, y)
			if t == Enums.TileType.WALL_STONE and rng.randi() % 100 < 35:
				map.set_tile(x, y, Enums.TileType.RUBBLE)
			elif t == Enums.TileType.FLOOR_WOOD and rng.randi() % 100 < 12:
				map.set_tile(x, y, Enums.TileType.RUBBLE)

	# A guaranteed clear path from the south entrance through the building.
	for y in range(MID, S - 1):
		map.set_tile(MID, y, Enums.TileType.FLOOR_WOOD)
	map.set_tile(MID, y2, Enums.TileType.FLOOR_WOOD)  # gap in the south wall

	# South entrance + exit.
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# LIBRARY (s2.3.23): a scholarly reading hall (the Takeo Library). Vertical book
# stacks separated by 1-tile walking aisles fill the north two-thirds; an open
# reading hall with study desks sits at the south near the entrance. A clear
# central aisle plus clear north/south cross-aisles keep every stack reachable.
static func _gen_library(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_WOOD)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Book stacks: vertical shelf runs with a 1-tile aisle between each, stopping
	# short of the south reading hall (y < S-9) and the north cross-aisle (y > 3).
	# The central aisle (MID-1..MID+1) is kept clear top to bottom.
	for sx in [4, 6, 8, 10, 12, S - 13, S - 11, S - 9, S - 7, S - 5]:
		if sx >= MID - 1 and sx <= MID + 1:
			continue
		for sy in range(4, S - 9):
			map.set_tile(sx, sy, Enums.TileType.FURNITURE_SHELF)

	# Scroll chests against the north wall, in the top cross-aisle.
	map.set_tile(2, 2, Enums.TileType.FURNITURE_CHEST)
	map.set_tile(S - 3, 2, Enums.TileType.FURNITURE_CHEST)

	# South reading hall: study desks with cushions, an incense burner by the wall.
	for dx in [MID - 5, MID + 5]:
		map.set_tile(dx, S - 5, Enums.TileType.FURNITURE_TABLE)
		map.set_tile(dx, S - 6, Enums.TileType.FURNITURE_CUSHION)
		map.set_tile(dx, S - 4, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(3, S - 3, Enums.TileType.FURNITURE_INCENSE)

	# South entrance + zone exit.
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# TOMB (s2.3.23): a solemn funerary chamber (the Kinjiren Tombs; the Hantei
# burial ground of Seppun Hill). A central processional aisle runs from the south
# entrance to a memorial altar at the north; memorial statues and offering boxes
# flank the aisle, with stone burial coffers in the side bays. Stone throughout.
static func _gen_tomb(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_STONE)
	_draw_stone_border(map, 0, 0, S - 1, S - 1)

	# Memorial altar at the north terminus, flanked by incense, with a prayer mat.
	map.set_tile(MID, 2, Enums.TileType.FURNITURE_ALTAR)
	map.set_tile(MID - 1, 2, Enums.TileType.FURNITURE_INCENSE)
	map.set_tile(MID + 1, 2, Enums.TileType.FURNITURE_INCENSE)
	map.set_tile(MID, 4, Enums.TileType.FURNITURE_PRAYER_MAT)

	# Flanking memorial statues + offering boxes down each side of the aisle
	# (columns MID±3, clear of the MID-2..MID+2 processional aisle).
	for sy in [7, 11, 15, 19, 23]:
		map.set_tile(MID - 3, sy, Enums.TileType.FURNITURE_STATUE)
		map.set_tile(MID + 3, sy, Enums.TileType.FURNITURE_STATUE)
		map.set_tile(MID - 3, sy + 1, Enums.TileType.FURNITURE_OFFERING_BOX)
		map.set_tile(MID + 3, sy + 1, Enums.TileType.FURNITURE_OFFERING_BOX)

	# Burial coffers (stone caskets) in the side bays against the walls.
	for cy in [8, 12, 16, 20]:
		map.set_tile(2, cy, Enums.TileType.FURNITURE_CHEST)
		map.set_tile(3, cy, Enums.TileType.FURNITURE_CHEST)
		map.set_tile(S - 3, cy, Enums.TileType.FURNITURE_CHEST)
		map.set_tile(S - 4, cy, Enums.TileType.FURNITURE_CHEST)

	# South entrance + zone exit.
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# TREASURY_VAULT (s2.3.23): the Imperial Treasury — a guarded stone strongroom.
# A single south entrance with a guard post opens onto a clear central aisle;
# coffer banks (against the side walls, with even-row gaps), sealed jars, ledger
# shelves and crates line the vault bays.
static func _gen_treasury_vault(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_STONE)
	_draw_stone_border(map, 0, 0, S - 1, S - 1)

	# Coffer banks against the side walls, on odd rows only (even rows = access
	# gaps), clear of the central aisle.
	for cy in [3, 5, 7, 9, 11, 13]:
		for cx in [2, 3, 4, S - 5, S - 4, S - 3]:
			map.set_tile(cx, cy, Enums.TileType.FURNITURE_CHEST)
	# Sealed valuables and ledger shelves deeper in (isolated obstacles).
	for vx in [7, 9, S - 10, S - 8]:
		map.set_tile(vx, 3, Enums.TileType.FURNITURE_JAR)
		map.set_tile(vx, 5, Enums.TileType.FURNITURE_CRATE)
	map.set_tile(MID - 3, 3, Enums.TileType.FURNITURE_SHELF)
	map.set_tile(MID + 3, 3, Enums.TileType.FURNITURE_SHELF)

	# Guard post at the entrance: a weapon stand and a brazier, flanking the aisle.
	map.set_tile(MID - 2, S - 3, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(MID + 2, S - 3, Enums.TileType.FURNITURE_BRAZIER)

	# Single guarded south entrance + zone exit.
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# BARRACKS (s2.3.23): soldier housing (a guard kaisha or embassy garrison hall).
# Rows of futon sleeping bays with foot-chests flank a clear central aisle; an
# arms rack lines the north wall; a mess corner (tables, benches, a stove) sits
# near the south entrance, with braziers for warmth. Deterministic from the
# caller's seeded rng. Distinct from WAR_COUNCIL_ROOM (a strategy-table room).
static func _gen_barracks(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_WOOD)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Arms rack along the north wall (skipping the central aisle's north end).
	for x in range(3, S - 3, 2):
		if x < MID - 1 or x > MID + 1:
			map.set_tile(x, 2, Enums.TileType.FURNITURE_WEAPON_STAND)

	# Sleeping bays: paired futons down each side with a foot-chest at the wall.
	# The central aisle (columns MID-1..MID+1) is kept clear.
	for by in [5, 8, 11, 14, 17]:
		# Left bay.
		map.set_tile(3, by, Enums.TileType.FURNITURE_FUTON)
		map.set_tile(4, by, Enums.TileType.FURNITURE_FUTON)
		map.set_tile(6, by, Enums.TileType.FURNITURE_FUTON)
		map.set_tile(7, by, Enums.TileType.FURNITURE_FUTON)
		map.set_tile(2, by, Enums.TileType.FURNITURE_CHEST)
		# Right bay.
		map.set_tile(S - 4, by, Enums.TileType.FURNITURE_FUTON)
		map.set_tile(S - 5, by, Enums.TileType.FURNITURE_FUTON)
		map.set_tile(S - 7, by, Enums.TileType.FURNITURE_FUTON)
		map.set_tile(S - 8, by, Enums.TileType.FURNITURE_FUTON)
		map.set_tile(S - 3, by, Enums.TileType.FURNITURE_CHEST)

	# Braziers for warmth/light, clear of the aisle.
	map.set_tile(9, 11, Enums.TileType.FURNITURE_BRAZIER)
	map.set_tile(S - 10, 11, Enums.TileType.FURNITURE_BRAZIER)

	# Mess corner near the south entrance: long tables + benches and a cook stove.
	map.set_tile(MID - 4, S - 4, Enums.TileType.FURNITURE_TABLE)
	map.set_tile(MID - 4, S - 5, Enums.TileType.FURNITURE_BENCH)
	map.set_tile(MID - 4, S - 3, Enums.TileType.FURNITURE_BENCH)
	map.set_tile(MID + 4, S - 4, Enums.TileType.FURNITURE_TABLE)
	map.set_tile(MID + 4, S - 5, Enums.TileType.FURNITURE_BENCH)
	map.set_tile(MID + 4, S - 3, Enums.TileType.FURNITURE_BENCH)
	map.set_tile(3, S - 3, Enums.TileType.FURNITURE_STOVE)

	# South entrance + zone exit.
	map.set_tile(MID, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# THRONE_ROOM (s2.3.23 / s57.36): the Imperial Palace's grandest hall, seat of
# the Chrysanthemum Throne. A raised two-step dais at the head bears the throne
# (no one may sit higher than the Son of Heaven), flanked by Imperial banners and
# Seppun guards. The Road of the Most High enters as a central processional aisle
# kept clear from the south doors to the throne. The assembled court kneels in
# ranked cushion rows flanking the aisle — front rows nearest the throne are the
# highest precedence. A colonnade lines the hall; a formal genkan frames the
# south entrance. Deterministic from the caller's seeded rng. Grander than a
# daimyo's OHIROMA: deeper dais, double guard, full ranked court.
static func _gen_throne_room(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_WOOD)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Formal tatami hall.
	_fill_rect(map, 2, 2, S - 3, S - 3, Enums.TileType.FLOOR_TATAMI)

	# Two-step dais at the north — wide lower step (rows 2–6) and a raised throne
	# step (rows 2–4) — so the Chrysanthemum Throne sits above all.
	_fill_rect(map, 3, 2, S - 4, 6, Enums.TileType.FLOOR_STONE)
	_fill_rect(map, 6, 2, S - 7, 4, Enums.TileType.FLOOR_STONE)
	# The Chrysanthemum Throne, centred and elevated.
	map.set_tile(MID, 3, Enums.TileType.FURNITURE_DAIS)
	# Imperial banners on the wall behind the throne.
	map.set_tile(MID - 3, 2, Enums.TileType.FURNITURE_BANNER)
	map.set_tile(MID + 3, 2, Enums.TileType.FURNITURE_BANNER)
	map.set_tile(8, 2, Enums.TileType.FURNITURE_BANNER)
	map.set_tile(S - 9, 2, Enums.TileType.FURNITURE_BANNER)
	# Seppun guards flanking the throne (weapon stands).
	map.set_tile(MID - 2, 3, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(MID + 2, 3, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(7, 5, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(S - 8, 5, Enums.TileType.FURNITURE_WEAPON_STAND)
	# Braziers lighting the dais front.
	map.set_tile(6, 8, Enums.TileType.FURNITURE_BRAZIER)
	map.set_tile(S - 7, 8, Enums.TileType.FURNITURE_BRAZIER)

	# Ranked court: cushion rows flanking the central processional aisle. The aisle
	# (columns MID-1..MID+1) is kept clear from the dais front to the south doors.
	# Front rows (nearest the throne) seat the highest precedence.
	for ry in [10, 13, 16, 19, 22]:
		for cx in [MID - 5, MID - 4, MID - 3, MID + 3, MID + 4, MID + 5]:
			if map.get_tile(cx, ry) == Enums.TileType.FLOOR_TATAMI:
				map.set_tile(cx, ry, Enums.TileType.FURNITURE_CUSHION)

	# Colonnade — wood pillars down each side, clear of the cushion blocks and aisle.
	for y in range(9, S - 4, 3):
		map.set_tile(2, y, Enums.TileType.WALL_WOOD)
		map.set_tile(S - 3, y, Enums.TileType.WALL_WOOD)

	# Genkan: lowered stone vestibule inside the south doors, framed by getabako
	# (footwear shelves) and waiting benches — the formal Imperial entry.
	_fill_rect(map, MID - 1, S - 3, MID + 1, S - 2, Enums.TileType.FLOOR_STONE)
	map.set_tile(MID - 2, S - 2, Enums.TileType.FURNITURE_SHELF)
	map.set_tile(MID + 2, S - 2, Enums.TileType.FURNITURE_SHELF)
	map.set_tile(MID - 2, S - 3, Enums.TileType.FURNITURE_BENCH)
	map.set_tile(MID + 2, S - 3, Enums.TileType.FURNITURE_BENCH)

	# Grand south entrance doors + the single zone exit (the Road of the Most High).
	map.set_tile(MID - 1, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID + 1, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]

	# Elevation (s4.4 Z-axis): the Chrysanthemum dais rises above the hall in two steps —
	# the wide lower step (layer 1) and the raised throne step (layer 2) — so the Emperor
	# looks down over the assembled court (high-ground + see-over). Each step is +1 (a ramp),
	# so a petitioner can ascend and the hall floor stays fully reachable.
	map.init_elevation(0)
	_raise_rect(map, 3, 2, S - 4, 6, 1)   # lower dais step
	_raise_rect(map, 6, 2, S - 7, 4, 2)   # raised throne step


# OHIROMA (Great Hall): large formal hall with dais, tatami floor, wood-framed
# columns, shoji dividers. The lord's primary audience and court space.
static func _gen_ohiroma(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_WOOD)
	_draw_wood_border(map, 0, 0, S - 1, S - 1)

	# Main hall tatami floor.
	_fill_rect(map, 2, 2, S - 3, S - 3, Enums.TileType.FLOOR_TATAMI)

	# Dais at north: raised stone platform rows 2–5.
	_fill_rect(map, 4, 2, S - 5, 5, Enums.TileType.FLOOR_STONE)
	# Lord's seat of authority centred on the dais, flanked by weapon stands;
	# banners on the wall behind, braziers and petitioner cushions in the hall.
	map.set_tile(MID, 3, Enums.TileType.FURNITURE_DAIS)
	map.set_tile(6, 3, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(S - 7, 3, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(8, 2, Enums.TileType.FURNITURE_BANNER)
	map.set_tile(S - 9, 2, Enums.TileType.FURNITURE_BANNER)
	map.set_tile(6, 9, Enums.TileType.FURNITURE_BRAZIER)
	map.set_tile(S - 7, 9, Enums.TileType.FURNITURE_BRAZIER)
	for cy in [11, 14]:
		for cx in [10, 12, 18, 20]:
			map.set_tile(cx, cy, Enums.TileType.FURNITURE_CUSHION)

	# Columns along sides (wood wall pillars).
	for y in range(6, S - 4, 4):
		map.set_tile(3, y, Enums.TileType.WALL_WOOD)
		map.set_tile(S - 4, y, Enums.TileType.WALL_WOOD)

	# Shoji screen dividers partitioning side alcoves.
	_fill_rect(map, 1, 6, 1, S - 6, Enums.TileType.WALL_PAPER)
	_fill_rect(map, S - 2, 6, S - 2, S - 6, Enums.TileType.WALL_PAPER)
	map.set_tile(1, MID, Enums.TileType.DOOR_SHOJI_OPEN)
	map.set_tile(S - 2, MID, Enums.TileType.DOOR_SHOJI_OPEN)

	# Genkan: a lowered stone doma vestibule just inside the south doors where
	# guests remove footwear before stepping up to the tatami hall, framed by
	# getabako (footwear shelves) and waiting benches — the castle's formal entry.
	_fill_rect(map, MID - 1, S - 3, MID + 1, S - 2, Enums.TileType.FLOOR_STONE)
	map.set_tile(MID - 2, S - 2, Enums.TileType.FURNITURE_SHELF)
	map.set_tile(MID + 2, S - 2, Enums.TileType.FURNITURE_SHELF)
	map.set_tile(MID - 2, S - 3, Enums.TileType.FURNITURE_BENCH)
	map.set_tile(MID + 2, S - 3, Enums.TileType.FURNITURE_BENCH)

	# Entrance doors south face.
	map.set_tile(MID - 1, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID + 1, S - 1, Enums.TileType.DOOR_WOOD_OPEN)

	# Zone exit south.
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]

	# Elevation (s4.4 Z-axis): the lord's dais (rows 2–5) sits one step (layer 1) above the
	# tatami hall, so the seated lord holds the high ground over petitioners. +1 = a ramp,
	# so the dais is climbable and the hall stays fully connected.
	map.init_elevation(0)
	_raise_rect(map, 4, 2, S - 5, 5, 1)


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
				# Low banquet table on each pad, cushions flanking it.
				var tx: int = ox + pad_w / 2
				var ty: int = oy + pad_h / 2
				map.set_tile(tx, ty, Enums.TileType.FURNITURE_TABLE)
				map.set_tile(tx - 1, ty, Enums.TileType.FURNITURE_CUSHION)
				map.set_tile(tx + 1, ty, Enums.TileType.FURNITURE_CUSHION)

	# Paper screens along north wall for serving area.
	_fill_rect(map, 4, 1, S - 5, 1, Enums.TileType.WALL_PAPER)
	map.set_tile(MID, 1, Enums.TileType.DOOR_SHOJI_OPEN)
	# Serving banners and a brazier lighting the feasting aisles.
	map.set_tile(5, 2, Enums.TileType.FURNITURE_BANNER)
	map.set_tile(S - 6, 2, Enums.TileType.FURNITURE_BANNER)
	map.set_tile(MID, 13, Enums.TileType.FURNITURE_BRAZIER)

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

	# Host seat with low table and guest cushion, a byōbu screen, weapon stand,
	# and a brazier — placed clear of the MID approach to the tokonoma.
	map.set_tile(12, 8, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(12, 10, Enums.TileType.FURNITURE_TABLE)
	map.set_tile(12, 12, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(18, 10, Enums.TileType.FURNITURE_SCREEN)
	map.set_tile(23, 7, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(8, 8, Enums.TileType.FURNITURE_BRAZIER)

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

	# Sunken ro hearth at the heart of the room, guest cushions around it, and a
	# mizuya utensil shelf in the corner.
	map.set_tile(MID, 12, Enums.TileType.FURNITURE_HEARTH)
	map.set_tile(13, 12, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(17, 12, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(MID, 14, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(18, 9, Enums.TileType.FURNITURE_SHELF)

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
		# Guest bedding and a small chest.
		map.set_tile(ox + 1, 2, Enums.TileType.FURNITURE_FUTON)
		map.set_tile(ox + room_w - 2, 2, Enums.TileType.FURNITURE_CHEST)
		# Shoji dividers between rooms.
		map.set_tile(ox + room_w / 2, MID - 2, Enums.TileType.DOOR_SHOJI_OPEN)
		# South rooms.
		_draw_wood_border(map, ox, MID + 2, ox + room_w - 1, S - 2)
		_fill_rect(map, ox + 1, MID + 3, ox + room_w - 2, S - 3,
			Enums.TileType.FLOOR_TATAMI)
		map.set_tile(ox + 1, MID + 3, Enums.TileType.FURNITURE_FUTON)
		map.set_tile(ox + room_w - 2, MID + 3, Enums.TileType.FURNITURE_CHEST)
		map.set_tile(ox + room_w / 2, MID + 2, Enums.TileType.DOOR_SHOJI_OPEN)

	# Furo (communal bath house): the south-east guest room is a bath rather than
	# bedding. Wood floor, a sunken soaking tub, a washing bench and rinse jar, and
	# a kama (stove) heating the bath water. Overwrites that room's futon/chest.
	var fox: int = 2 + 2 * (room_w + 2)
	_fill_rect(map, fox + 1, MID + 3, fox + room_w - 2, S - 3, Enums.TileType.FLOOR_WOOD)
	_fill_rect(map, fox + 3, S - 5, fox + 5, S - 4, Enums.TileType.WATER_SHALLOW)
	map.set_tile(fox + 1, S - 5, Enums.TileType.FURNITURE_BENCH)
	map.set_tile(fox + 1, S - 3, Enums.TileType.FURNITURE_JAR)
	map.set_tile(fox + room_w - 2, S - 4, Enums.TileType.FURNITURE_STOVE)

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

	# Furnishings (noble). Placed clear of the three doorways and the corridor.
	# Main chamber: writing table with cushions, a byōbu screen, brazier, tansu.
	map.set_tile(8, 6, Enums.TileType.FURNITURE_TABLE)
	map.set_tile(7, 6, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(9, 6, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(11, 9, Enums.TileType.FURNITURE_SCREEN)
	map.set_tile(24, 5, Enums.TileType.FURNITURE_BRAZIER)
	map.set_tile(25, 12, Enums.TileType.FURNITURE_CHEST)
	# Study (SE): writing desk + cushion + chest.
	map.set_tile(22, 22, Enums.TileType.FURNITURE_TABLE)
	map.set_tile(22, 23, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(27, 19, Enums.TileType.FURNITURE_CHEST)
	# Sleeping chamber (SW): futons, tansu, brazier.
	map.set_tile(6, 22, Enums.TileType.FURNITURE_FUTON)
	map.set_tile(8, 22, Enums.TileType.FURNITURE_FUTON)
	map.set_tile(11, 27, Enums.TileType.FURNITURE_CHEST)
	map.set_tile(4, 27, Enums.TileType.FURNITURE_BRAZIER)

	# Genkan (entrance vestibule): a lowered stone doma just inside the west door
	# where footwear is removed, with a getabako (footwear shelf) and a bench to
	# sit on. The raised wood corridor begins beyond it.
	_fill_rect(map, 1, MID - 1, 2, MID + 1, Enums.TileType.FLOOR_STONE)
	map.set_tile(2, MID - 2, Enums.TileType.FURNITURE_SHELF)
	map.set_tile(1, MID - 2, Enums.TileType.FURNITURE_BENCH)

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

	# Command platform: raised stone floor with a real strategy table at its
	# centre, ringed by cushions for the commanders.
	_fill_rect(map, 10, 10, 20, 20, Enums.TileType.FLOOR_STONE)
	_fill_rect(map, 14, 14, 16, 15, Enums.TileType.FURNITURE_TABLE)
	map.set_tile(13, 14, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(17, 14, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(13, 15, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(17, 15, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(MID, 13, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(MID, 16, Enums.TileType.FURNITURE_CUSHION)

	# Weapon and map racks along the side walls.
	for y in range(3, S - 3, 5):
		map.set_tile(2, y, Enums.TileType.FURNITURE_WEAPON_STAND)
		map.set_tile(S - 3, y, Enums.TileType.FURNITURE_WEAPON_STAND)

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
		map.set_tile(x, 1, Enums.TileType.FURNITURE_WEAPON_STAND)
		map.set_tile(x, S - 2, Enums.TileType.FURNITURE_WEAPON_STAND)

	# Kamiza (spirit seat / shrine alcove) at north-centre: a kamidana god-shelf
	# flanked by incense, with a prayer mat before it where students bow in.
	_fill_rect(map, 13, 1, 17, 1, Enums.TileType.FLOOR_STONE)
	map.set_tile(MID, 1, Enums.TileType.FURNITURE_ALTAR)
	map.set_tile(MID - 1, 1, Enums.TileType.FURNITURE_INCENSE)
	map.set_tile(MID + 1, 1, Enums.TileType.FURNITURE_INCENSE)
	map.set_tile(MID, 3, Enums.TileType.FURNITURE_PRAYER_MAT)

	# Training dummies (makiwara) in the practice area, clear of the centre lane.
	for dpos in [Vector2i(8, 12), Vector2i(S - 9, 12), Vector2i(8, 18), Vector2i(S - 9, 18)]:
		map.set_tile(dpos.x, dpos.y, Enums.TileType.FURNITURE_DUMMY)

	# Support pillars defining the training rectangle.
	map.set_tile(5, 5, Enums.TileType.WALL_WOOD)
	map.set_tile(S - 6, 5, Enums.TileType.WALL_WOOD)
	map.set_tile(5, S - 6, Enums.TileType.WALL_WOOD)
	map.set_tile(S - 6, S - 6, Enums.TileType.WALL_WOOD)

	# Entrance south. Clear any weapon rack on the threshold tile so the exit
	# connects to the training floor.
	map.set_tile(MID, S - 2, Enums.TileType.FLOOR_WOOD)
	map.set_tile(MID, S - 1, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]


# Draws a small walled service room with one door opening into the courtyard.
# Used for the castle compound's functional spaces (GDD s57.36.2: kitchen,
# armoury, storehouse, stables, barracks, prison are tile-clusters within the
# courtyard zone, not separate Lesser Zones).
static func _service_room(
	map: AsciiMapData,
	x1: int, y1: int, x2: int, y2: int,
	door_x: int, door_y: int,
) -> void:
	_draw_wood_box(map, x1, y1, x2, y2)
	_fill_rect(map, x1 + 1, y1 + 1, x2 - 1, y2 - 1, Enums.TileType.FLOOR_WOOD)
	map.set_tile(door_x, door_y, Enums.TileType.DOOR_WOOD_OPEN)


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

	# Functional service rooms line the compound, leaving the central muster lane
	# (cols 12–18, incl. the N–S gate column) open. GDD s57.36.2: kitchen, armoury,
	# storehouse, stables, barracks and a holding cell are tile-clusters here, not
	# separate zones. Each room has one door opening into the yard.
	# Kitchen (NW): kamado stoves, a utensil shelf, water jar, supplies.
	_service_room(map, 5, 5, 11, 10, 11, 7)
	map.set_tile(6, 6, Enums.TileType.FURNITURE_STOVE)
	map.set_tile(7, 6, Enums.TileType.FURNITURE_STOVE)
	map.set_tile(10, 6, Enums.TileType.FURNITURE_SHELF)
	map.set_tile(6, 9, Enums.TileType.FURNITURE_JAR)
	map.set_tile(10, 9, Enums.TileType.FURNITURE_CRATE)
	# Armoury (NE): weapon and armour racks, a shelf, crates.
	_service_room(map, 19, 5, 25, 10, 19, 7)
	for ax in [20, 21, 22, 23]:
		map.set_tile(ax, 6, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(24, 6, Enums.TileType.FURNITURE_SHELF)
	map.set_tile(20, 9, Enums.TileType.FURNITURE_CRATE)
	map.set_tile(24, 9, Enums.TileType.FURNITURE_CRATE)
	# Storehouse / kura (W): stacked crates and shelving.
	_service_room(map, 5, 12, 11, 18, 11, 15)
	for cpos in [Vector2i(6, 13), Vector2i(7, 13), Vector2i(6, 14), Vector2i(7, 14)]:
		map.set_tile(cpos.x, cpos.y, Enums.TileType.FURNITURE_CRATE)
	map.set_tile(10, 13, Enums.TileType.FURNITURE_SHELF)
	map.set_tile(10, 14, Enums.TileType.FURNITURE_SHELF)
	map.set_tile(6, 17, Enums.TileType.FURNITURE_JAR)
	# Stables (E): water troughs and feed crates along the far wall, clear of the
	# west door so the stalls stay reachable.
	_service_room(map, 19, 12, 25, 18, 19, 15)
	map.set_tile(23, 13, Enums.TileType.FURNITURE_JAR)
	map.set_tile(23, 14, Enums.TileType.FURNITURE_CRATE)
	map.set_tile(23, 16, Enums.TileType.FURNITURE_CRATE)
	map.set_tile(23, 17, Enums.TileType.FURNITURE_JAR)
	# Barracks (SW): garrison bedding, a chest, weapon stand, brazier.
	_service_room(map, 5, 20, 11, 24, 11, 22)
	for fpos in [Vector2i(6, 21), Vector2i(7, 21), Vector2i(6, 22), Vector2i(7, 22)]:
		map.set_tile(fpos.x, fpos.y, Enums.TileType.FURNITURE_FUTON)
	map.set_tile(10, 21, Enums.TileType.FURNITURE_CHEST)
	map.set_tile(10, 23, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(8, 23, Enums.TileType.FURNITURE_BRAZIER)
	# Holding cell / prison (SE): a bare straw mat and a confiscation chest.
	_service_room(map, 19, 20, 25, 24, 19, 22)
	map.set_tile(20, 21, Enums.TileType.FURNITURE_FUTON)
	map.set_tile(24, 21, Enums.TileType.FURNITURE_CHEST)

	# A well in the muster lane (off the gate column) and clan banners flanking
	# the north gate approach.
	map.set_tile(17, 12, Enums.TileType.FURNITURE_WELL)
	map.set_tile(13, 5, Enums.TileType.FURNITURE_BANNER)
	map.set_tile(17, 5, Enums.TileType.FURNITURE_BANNER)

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

	# Tsukubai stone water basin and a stone lantern in the garden; meditation
	# benches on the veranda. The garden interior stays open grass, so the
	# stepping path is unaffected.
	map.set_tile(9, 10, Enums.TileType.FURNITURE_WELL)
	map.set_tile(22, 11, Enums.TileType.FURNITURE_BRAZIER)

	# Engawa (veranda) access on south wall — shoji doors.
	_fill_rect(map, 3, S - 4, S - 4, S - 4, Enums.TileType.WALL_PAPER)
	map.set_tile(MID, S - 4, Enums.TileType.DOOR_SHOJI_OPEN)
	_fill_rect(map, 3, S - 3, S - 4, S - 3, Enums.TileType.FLOOR_WOOD)
	# Meditation benches on the veranda (after the veranda floor is laid).
	map.set_tile(9, S - 3, Enums.TileType.FURNITURE_BENCH)
	map.set_tile(21, S - 3, Enums.TileType.FURNITURE_BENCH)

	# Carve the threshold (S-2 row is otherwise the surrounding wall) so the
	# exit connects through the veranda to the garden.
	map.set_tile(MID, S - 2, Enums.TileType.FLOOR_WOOD)
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

	# Altar stone in front of shrine, with offering box, incense, prayer mats,
	# and komainu guardians flanking the approach path.
	_fill_rect(map, 13, 11, 17, 11, Enums.TileType.FLOOR_STONE)
	map.set_tile(MID, 7, Enums.TileType.FURNITURE_ALTAR)
	map.set_tile(16, 11, Enums.TileType.FURNITURE_OFFERING_BOX)
	map.set_tile(13, 11, Enums.TileType.FURNITURE_INCENSE)
	map.set_tile(17, 11, Enums.TileType.FURNITURE_INCENSE)
	map.set_tile(14, 8, Enums.TileType.FURNITURE_PRAYER_MAT)
	map.set_tile(16, 8, Enums.TileType.FURNITURE_PRAYER_MAT)
	map.set_tile(12, 14, Enums.TileType.FURNITURE_STATUE)
	map.set_tile(18, 14, Enums.TileType.FURNITURE_STATUE)

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
			# Entertaining set: low table with cushions, a byōbu screen, a brazier.
			map.set_tile(6, oy + 3, Enums.TileType.FURNITURE_TABLE)
			map.set_tile(5, oy + 3, Enums.TileType.FURNITURE_CUSHION)
			map.set_tile(7, oy + 3, Enums.TileType.FURNITURE_CUSHION)
			map.set_tile(6, oy + 4, Enums.TileType.FURNITURE_CUSHION)
			map.set_tile(9, oy + 2, Enums.TileType.FURNITURE_SCREEN)
			map.set_tile(3, oy + 6, Enums.TileType.FURNITURE_BRAZIER)
			map.set_tile(MID - 4, oy + bh / 2, Enums.TileType.DOOR_SHOJI_OPEN)

	# East block: 3 buildings (sake houses).
	for i in range(3):
		var oy: int = 2 + i * (bh + 1)
		if oy + bh < S - 1:
			_draw_wood_border(map, MID + 4, oy, S - 2, oy + bh)
			_fill_rect(map, MID + 5, oy + 1, S - 3, oy + bh - 1, Enums.TileType.FLOOR_TATAMI)
			# Sake-house set: low table with cushions, screen, brazier.
			map.set_tile(24, oy + 3, Enums.TileType.FURNITURE_TABLE)
			map.set_tile(23, oy + 3, Enums.TileType.FURNITURE_CUSHION)
			map.set_tile(25, oy + 3, Enums.TileType.FURNITURE_CUSHION)
			map.set_tile(24, oy + 4, Enums.TileType.FURNITURE_CUSHION)
			map.set_tile(27, oy + 2, Enums.TileType.FURNITURE_SCREEN)
			map.set_tile(21, oy + 6, Enums.TileType.FURNITURE_BRAZIER)
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

	# Cargo crates and barrels stacked on the quay, fishing nets drying on the
	# land. Placed clear of the warehouse doors, pier mouths and zone exits.
	for cpos in [Vector2i(6, 13), Vector2i(7, 13), Vector2i(14, 13), Vector2i(15, 13), Vector2i(22, 13), Vector2i(23, 13)]:
		map.set_tile(cpos.x, cpos.y, Enums.TileType.FURNITURE_CRATE)
	for npos in [Vector2i(9, 10), Vector2i(17, 10), Vector2i(25, 10)]:
		map.set_tile(npos.x, npos.y, Enums.TileType.FURNITURE_NET)

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
			# Bare shack: a small hearth and a water jar in opposite corners.
			map.set_tile(ox + 1, oy + 1, Enums.TileType.FURNITURE_HEARTH)
			map.set_tile(ox + plot_w - 2, oy + 1, Enums.TileType.FURNITURE_JAR)
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

	# Zone exits east and west, placed on the open alley between shack rows
	# (MID itself lands on a shack row, which would wall the exit off).
	var alley_y: int = 1 + 2 * (plot_h + 1) - 1
	map.set_tile(0, alley_y, Enums.TileType.ZONE_EXIT)
	map.set_tile(S - 1, alley_y, Enums.TileType.ZONE_EXIT)
	map.exits = [
		{x = 0, y = alley_y, direction = "west", target_zone_id = ""},
		{x = S - 1, y = alley_y, direction = "east", target_zone_id = ""},
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
	# Magistrate's dais flanked by yoriki weapon stands; petitioner cushions and a
	# kneeling mat for the accused; a document shelf.
	map.set_tile(MID, 4, Enums.TileType.FURNITURE_DAIS)
	map.set_tile(5, 4, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(S - 6, 4, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(13, 8, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(17, 8, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(MID, 8, Enums.TileType.FURNITURE_PRAYER_MAT)
	map.set_tile(24, 9, Enums.TileType.FURNITURE_SHELF)

	# South building (record hall).
	_draw_stone_border(map, 3, 19, S - 4, S - 3)
	_fill_rect(map, 4, 20, S - 5, S - 4, Enums.TileType.FLOOR_TATAMI)
	map.set_tile(MID, 19, Enums.TileType.DOOR_WOOD_OPEN)
	# Archive shelving along the back wall, document chests.
	for sx in [5, 9, 21, 25]:
		map.set_tile(sx, S - 4, Enums.TileType.FURNITURE_SHELF)
	map.set_tile(13, 21, Enums.TileType.FURNITURE_CHEST)
	map.set_tile(17, 21, Enums.TileType.FURNITURE_CHEST)

	# Central plaza between buildings (stone floor, already set).
	# Guard post (small stone structure) in plaza.
	_draw_stone_border(map, 13, 13, 17, 17)
	_fill_rect(map, 14, 14, 16, 16, Enums.TileType.FLOOR_WOOD)
	map.set_tile(MID, 17, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(14, 14, Enums.TileType.FURNITURE_WEAPON_STAND)

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

	# Elevation (s4.4 Z-axis): the magistrate's bench (rows 3–4, behind the dais) sits one
	# step (layer 1) above the petitioner floor of the north office — the judge looks down on
	# the accused. +1 = a ramp, so the office stays reachable.
	map.init_elevation(0)
	_raise_rect(map, 4, 3, S - 5, 4, 1)


# MOUNTAIN_PASS: rocky terrain, narrow winding path between cliff faces,
# steep elevation, weather exposure.
static func _gen_mountain_pass(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.WALL_STONE)

	# Carve a winding path through the rock.
	# Record path_x per row so clearing placement can reference the actual
	# path position at each y, rather than the stale end-of-loop value.
	var path_x: int = MID
	var path_x_by_y: Array[int] = []
	path_x_by_y.resize(S)
	for y in range(S - 1, -1, -1):
		var drift: int = (rng.randi() % 3) - 1
		path_x = clampi(path_x + drift, 4, S - 5)
		path_x_by_y[y] = path_x
		# Path: 3-5 tiles wide.
		var w: int = 1 + rng.randi() % 2
		for dx in range(-w, w + 1):
			var tx: int = path_x + dx
			if tx >= 0 and tx < S:
				map.set_tile(tx, y, Enums.TileType.FLOOR_STONE)

	# Widen a few areas into small clearings.
	for _i in range(2 + rng.randi() % 2):
		var cy: int = 5 + rng.randi() % (S - 10)
		var cx: int = path_x_by_y[cy]  # Use the actual path x at this row.
		for dy in range(-2, 3):
			for dx in range(-3, 4):
				var tx: int = cx + dx
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

	# Weapon racks lining the inner walls; garrison bedding, a supply crate stack,
	# and braziers — placed clear of the four doors and the central stairwell.
	for y in range(10, 13):
		map.set_tile(9, y, Enums.TileType.FURNITURE_WEAPON_STAND)
		map.set_tile(21, y, Enums.TileType.FURNITURE_WEAPON_STAND)
	map.set_tile(10, 19, Enums.TileType.FURNITURE_FUTON)
	map.set_tile(11, 19, Enums.TileType.FURNITURE_FUTON)
	map.set_tile(19, 19, Enums.TileType.FURNITURE_CRATE)
	map.set_tile(20, 19, Enums.TileType.FURNITURE_CRATE)
	map.set_tile(10, 10, Enums.TileType.FURNITURE_BRAZIER)
	map.set_tile(20, 20, Enums.TileType.FURNITURE_BRAZIER)

	# Exit south (connects to wall walkway).
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]

	# Elevation (s4.4 Z-axis): the battlement walk — the stone ring between the outer wall and
	# the inner tower — is the raised fighting platform (layer 1), so wall defenders hold the
	# high ground and see over the parapet at anyone who breaches the inner garrison room
	# (layer 0). The four inner-tower doors bridge the two as +1 ramps, so the interior stays
	# reachable. Only two layers (max delta 1), so the ramps can never strand anything.
	map.init_elevation(1)               # the whole tower top sits at battlement level
	_raise_rect(map, 8, 8, 22, 22, 0)   # inner tower (walls + garrison + pillar) one step down


# PEASANT_DWELLING (minka): a single-room commoner home in a small yard.
# Earthen-entry (doma) at the door, raised plank living floor, a central irori
# hearth, sleeping mats, storage chests, a water jar and a low table. Furniture
# is placed clear of the door→interior path so the room stays traversable.
static func _gen_peasant_dwelling(map: AsciiMapData, rng: RandomNumberGenerator) -> void:
	# Yard: packed earth.
	_fill_rect(map, 0, 0, S - 1, S - 1, Enums.TileType.FLOOR_DIRT)

	# House footprint (wood walls), interior raised plank floor.
	var lx: int = 7
	var rx: int = 23
	var ty: int = 7
	var by: int = 21
	_draw_wood_box(map, lx, ty, rx, by)
	_fill_rect(map, lx + 1, ty + 1, rx - 1, by - 1, Enums.TileType.FLOOR_WOOD)

	# Doma (earthen entry strip) just inside the south door.
	_fill_rect(map, lx + 1, by - 2, rx - 1, by - 1, Enums.TileType.FLOOR_DIRT)

	# South door + exit (with a dirt path across the yard).
	map.set_tile(MID, by, Enums.TileType.DOOR_WOOD_OPEN)
	map.set_tile(MID, S - 1, Enums.TileType.ZONE_EXIT)
	map.exits = [{x = MID, y = S - 1, direction = "south", target_zone_id = ""}]

	# Central irori hearth (single tile; column kept clear of the door path edges).
	var hearth_x: int = MID + (1 if rng.randi() % 2 == 0 else -1)
	map.set_tile(hearth_x, 14, Enums.TileType.FURNITURE_HEARTH)
	# Cushions flanking the hearth.
	map.set_tile(hearth_x - 1, 15, Enums.TileType.FURNITURE_CUSHION)
	map.set_tile(hearth_x + 1, 15, Enums.TileType.FURNITURE_CUSHION)

	# Sleeping mats along the north wall (1-2).
	map.set_tile(lx + 2, ty + 1, Enums.TileType.FURNITURE_FUTON)
	if rng.randi() % 2 == 0:
		map.set_tile(lx + 4, ty + 1, Enums.TileType.FURNITURE_FUTON)

	# Storage chest in a corner; water jar by the doma; low table near the hearth;
	# a kamado cooking stove against the wall by the earthen entry.
	map.set_tile(rx - 1, ty + 1, Enums.TileType.FURNITURE_CHEST)
	map.set_tile(lx + 1, by - 2, Enums.TileType.FURNITURE_JAR)
	map.set_tile(MID, 17, Enums.TileType.FURNITURE_TABLE)
	map.set_tile(rx - 1, by - 2, Enums.TileType.FURNITURE_STOVE)


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


# Stamp an elevation level over a rectangle (s4.4 Z-axis). Clamps to the elevation
# cap; only touches in-bounds tiles. Caller must have called map.init_elevation()
# first. Used for ceremonial daises (the lord/judge sits a step above the floor).
static func _raise_rect(
	map: AsciiMapData,
	x1: int, y1: int, x2: int, y2: int,
	level: int,
) -> void:
	for y in range(maxi(0, y1), mini(map.height - 1, y2) + 1):
		for x in range(maxi(0, x1), mini(map.width - 1, x2) + 1):
			map.set_elevation(x, y, level)


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


# True for floor/open-door tiles that a walker can stand on (used by generators
# to detect passages that must not be sealed by decorative features).
static func _is_passable_floor(t: int) -> bool:
	match t:
		Enums.TileType.FLOOR_GRASS, Enums.TileType.FLOOR_DIRT, \
		Enums.TileType.FLOOR_WOOD, Enums.TileType.FLOOR_TATAMI, \
		Enums.TileType.FLOOR_STONE, Enums.TileType.FLOOR_MUD, \
		Enums.TileType.FLOOR_SNOW, Enums.TileType.FLOOR_SAND, \
		Enums.TileType.DOOR_SHOJI_OPEN, Enums.TileType.DOOR_WOOD_OPEN, \
		Enums.TileType.GATE_OPEN, Enums.TileType.ZONE_EXIT:
			return true
	return false
