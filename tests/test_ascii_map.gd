extends GutTest
## Tests for the ASCII map system: AsciiMapData, FovSystem, AsciiMapGenerator.
## s4.4 — LOCKED.


# ---------------------------------------------------------------------------
# AsciiMapData — data model
# ---------------------------------------------------------------------------

func test_ascii_map_data_init_correct_size() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	assert_eq(m.tile_types.size(), AsciiMapData.TILE_COUNT)


func test_ascii_map_data_init_fill() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_STONE)
	assert_eq(m.get_tile(0, 0), Enums.TileType.FLOOR_STONE)
	assert_eq(m.get_tile(15, 15), Enums.TileType.FLOOR_STONE)
	assert_eq(m.get_tile(30, 30), Enums.TileType.FLOOR_STONE)


func test_ascii_map_data_set_and_get_tile() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 7, Enums.TileType.WALL_STONE)
	assert_eq(m.get_tile(5, 7), Enums.TileType.WALL_STONE)
	assert_eq(m.get_tile(5, 8), Enums.TileType.FLOOR_GRASS)


func test_ascii_map_data_out_of_bounds_returns_wall() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	assert_eq(m.get_tile(-1, 0), Enums.TileType.WALL_STONE)
	assert_eq(m.get_tile(0, -1), Enums.TileType.WALL_STONE)
	assert_eq(m.get_tile(31, 0), Enums.TileType.WALL_STONE)
	assert_eq(m.get_tile(0, 31), Enums.TileType.WALL_STONE)


func test_ascii_map_data_delta_overrides_base() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_delta(10, 10, Enums.TileType.WALL_STONE)
	assert_eq(m.get_tile(10, 10), Enums.TileType.WALL_STONE)
	# Base tile unaffected at adjacent position.
	assert_eq(m.get_tile(10, 11), Enums.TileType.FLOOR_GRASS)


func test_ascii_map_data_clear_delta_restores_base() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_STONE)
	m.set_delta(5, 5, Enums.TileType.WATER_DEEP)
	m.clear_delta(5, 5)
	assert_eq(m.get_tile(5, 5), Enums.TileType.FLOOR_STONE)


func test_is_passable_floor_tiles() -> void:
	assert_true(AsciiMapData.is_passable(Enums.TileType.FLOOR_GRASS))
	assert_true(AsciiMapData.is_passable(Enums.TileType.FLOOR_WOOD))
	assert_true(AsciiMapData.is_passable(Enums.TileType.FLOOR_TATAMI))
	assert_true(AsciiMapData.is_passable(Enums.TileType.FLOOR_STONE))


func test_is_passable_wall_false() -> void:
	assert_false(AsciiMapData.is_passable(Enums.TileType.WALL_STONE))
	assert_false(AsciiMapData.is_passable(Enums.TileType.WALL_WOOD))
	assert_false(AsciiMapData.is_passable(Enums.TileType.WALL_PAPER))


func test_is_passable_closed_doors_false() -> void:
	assert_false(AsciiMapData.is_passable(Enums.TileType.DOOR_SHOJI_CLOSED))
	assert_false(AsciiMapData.is_passable(Enums.TileType.DOOR_WOOD_CLOSED))
	assert_false(AsciiMapData.is_passable(Enums.TileType.GATE_CLOSED))


func test_is_passable_open_doors_true() -> void:
	assert_true(AsciiMapData.is_passable(Enums.TileType.DOOR_SHOJI_OPEN))
	assert_true(AsciiMapData.is_passable(Enums.TileType.DOOR_WOOD_OPEN))
	assert_true(AsciiMapData.is_passable(Enums.TileType.GATE_OPEN))


func test_is_passable_trees_false() -> void:
	assert_false(AsciiMapData.is_passable(Enums.TileType.TREE_EVERGREEN))
	assert_false(AsciiMapData.is_passable(Enums.TileType.TREE_DECIDUOUS))
	assert_false(AsciiMapData.is_passable(Enums.TileType.BAMBOO))


func test_is_passable_dead_tree_false() -> void:
	# Dead trees block movement even though they don't block LOS.
	assert_false(AsciiMapData.is_passable(Enums.TileType.TREE_DEAD))


func test_blocks_los_walls() -> void:
	assert_true(AsciiMapData.blocks_los(Enums.TileType.WALL_STONE))
	assert_true(AsciiMapData.blocks_los(Enums.TileType.WALL_WOOD))
	assert_true(AsciiMapData.blocks_los(Enums.TileType.WALL_PAPER))


func test_blocks_los_trees_but_not_dead_tree() -> void:
	assert_true(AsciiMapData.blocks_los(Enums.TileType.TREE_EVERGREEN))
	assert_true(AsciiMapData.blocks_los(Enums.TileType.TREE_DECIDUOUS))
	assert_true(AsciiMapData.blocks_los(Enums.TileType.BAMBOO))
	assert_false(AsciiMapData.blocks_los(Enums.TileType.TREE_DEAD))


func test_blocks_los_floor_false() -> void:
	assert_false(AsciiMapData.blocks_los(Enums.TileType.FLOOR_GRASS))
	assert_false(AsciiMapData.blocks_los(Enums.TileType.FLOOR_STONE))
	assert_false(AsciiMapData.blocks_los(Enums.TileType.WATER_SHALLOW))


# ---------------------------------------------------------------------------
# FovSystem — effective_radius
# ---------------------------------------------------------------------------

func test_fov_effective_radius_no_modifier() -> void:
	assert_eq(FovSystem.effective_radius(4, 0), 4)


func test_fov_effective_radius_with_modifier() -> void:
	assert_eq(FovSystem.effective_radius(4, 2), 2)


func test_fov_effective_radius_minimum_one() -> void:
	# Supernatural −4 on Perception 2 → would be −2, clamped to 1.
	assert_eq(FovSystem.effective_radius(2, FovSystem.ENV_SUPERNATURAL), 1)


func test_fov_effective_radius_minimum_one_extreme() -> void:
	assert_eq(FovSystem.effective_radius(1, 10), 1)


# ---------------------------------------------------------------------------
# FovSystem — compute_visible
# ---------------------------------------------------------------------------

func _make_open_map() -> AsciiMapData:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	return m


func test_fov_player_tile_always_visible() -> void:
	var m: AsciiMapData = _make_open_map()
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 4, m)
	assert_true(visible.get(Vector2i(15, 15), false))


func test_fov_open_space_all_within_radius_visible() -> void:
	var m: AsciiMapData = _make_open_map()
	var radius: int = 3
	var cx: int = 15
	var cy: int = 15
	var visible: Dictionary = FovSystem.compute_visible(cx, cy, radius, m)
	# All tiles within circular radius should be visible.
	for dy in range(-radius, radius + 1):
		for dx in range(-radius, radius + 1):
			if dx * dx + dy * dy <= radius * radius:
				assert_true(
					visible.get(Vector2i(cx + dx, cy + dy), false),
					"Expected visible at (%d,%d)" % [cx + dx, cy + dy]
				)


func test_fov_tiles_beyond_radius_not_visible() -> void:
	var m: AsciiMapData = _make_open_map()
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 2, m)
	# Tile 5 steps away should not be visible.
	assert_false(visible.get(Vector2i(15, 20), false))
	assert_false(visible.get(Vector2i(20, 15), false))


func test_fov_wall_blocks_tiles_behind_it() -> void:
	var m: AsciiMapData = _make_open_map()
	# Place a horizontal stone wall at y=12 across the full width.
	for x in range(0, AsciiMapData.MAP_SIZE):
		m.set_tile(x, 12, Enums.TileType.WALL_STONE)
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	# Tile at y=10 (north of wall) should NOT be visible from y=15 (south).
	assert_false(visible.get(Vector2i(15, 10), false), "Should not see through wall")


func test_fov_wall_tile_itself_is_visible() -> void:
	var m: AsciiMapData = _make_open_map()
	m.set_tile(15, 13, Enums.TileType.WALL_STONE)
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 4, m)
	# The wall tile directly north is visible (you see the wall).
	assert_true(visible.get(Vector2i(15, 13), false), "Wall face should be visible")


func test_fov_diagonal_wall_blocks_behind() -> void:
	var m: AsciiMapData = _make_open_map()
	# Single wall tile between viewer and target.
	m.set_tile(17, 13, Enums.TileType.WALL_STONE)
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	# Tile directly behind the wall on the same line should not be visible.
	assert_false(visible.get(Vector2i(19, 11), false))


func test_fov_open_door_allows_sight() -> void:
	var m: AsciiMapData = _make_open_map()
	# Wood wall row with one open door.
	for x in range(0, AsciiMapData.MAP_SIZE):
		m.set_tile(x, 12, Enums.TileType.WALL_WOOD)
	m.set_tile(15, 12, Enums.TileType.DOOR_WOOD_OPEN)
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	# Tile directly beyond the open door should be visible.
	assert_true(visible.get(Vector2i(15, 11), false), "Should see through open door")


func test_fov_closed_door_blocks_sight() -> void:
	var m: AsciiMapData = _make_open_map()
	for x in range(0, AsciiMapData.MAP_SIZE):
		m.set_tile(x, 12, Enums.TileType.WALL_WOOD)
	m.set_tile(15, 12, Enums.TileType.DOOR_WOOD_CLOSED)
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	assert_false(visible.get(Vector2i(15, 11), false), "Closed door blocks LOS")


# ---------------------------------------------------------------------------
# AsciiMapGenerator — determinism and structure
# ---------------------------------------------------------------------------

func _gen(subtype: int, settlement: String = "Shiro Kakita") -> AsciiMapData:
	return AsciiMapGenerator.generate(
		"zone_test", "Test Zone", subtype, settlement
	)


func test_generator_returns_full_map() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.MARKET_STREET)
	assert_eq(m.tile_types.size(), AsciiMapData.TILE_COUNT)


func test_generator_deterministic_same_output() -> void:
	var m1: AsciiMapData = _gen(Enums.ZoneSubtype.SHRINE_CLEARING)
	var m2: AsciiMapData = _gen(Enums.ZoneSubtype.SHRINE_CLEARING)
	# Both maps must be byte-for-byte identical.
	assert_eq(m1.tile_types, m2.tile_types)


func test_generator_different_settlements_produce_different_maps() -> void:
	var m1: AsciiMapData = _gen(Enums.ZoneSubtype.FOREST_PATH, "Shiro Kakita")
	var m2: AsciiMapData = _gen(Enums.ZoneSubtype.FOREST_PATH, "Shiro Hiruma")
	# Different seeds → at least one tile should differ.
	var differs: bool = false
	for i in range(AsciiMapData.TILE_COUNT):
		if m1.tile_types[i] != m2.tile_types[i]:
			differs = true
			break
	assert_true(differs, "Different settlements should produce different maps")


func test_generator_different_subtypes_produce_different_maps() -> void:
	var m1: AsciiMapData = _gen(Enums.ZoneSubtype.MARKET_STREET)
	var m2: AsciiMapData = _gen(Enums.ZoneSubtype.TEMPLE_GROUNDS)
	var differs: bool = false
	for i in range(AsciiMapData.TILE_COUNT):
		if m1.tile_types[i] != m2.tile_types[i]:
			differs = true
			break
	assert_true(differs, "Different subtypes should produce different layouts")


func test_generator_market_street_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.MARKET_STREET)
	assert_eq(m.exits.size(), 2)


func test_generator_market_street_exits_are_passable() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.MARKET_STREET)
	for exit in m.exits:
		var tile: int = m.get_tile(exit.x, exit.y)
		assert_true(AsciiMapData.is_passable(tile),
			"Exit tile at (%d,%d) must be passable, got %d" % [exit.x, exit.y, tile])


func test_generator_market_street_has_stone_floor_on_road() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.MARKET_STREET)
	# Centre rows 12–18 should contain stone floor tiles along the road.
	var stone_count: int = 0
	for x in range(5, 26):
		if m.get_tile(x, 15) == Enums.TileType.FLOOR_STONE or \
		   m.get_tile(x, 15) == Enums.TileType.FLOOR_TATAMI:
			stone_count += 1
	assert_gt(stone_count, 10, "Road should have many stone/tatami floor tiles")


func test_generator_temple_grounds_has_exit() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.TEMPLE_GROUNDS)
	assert_gt(m.exits.size(), 0)


func test_generator_shrine_clearing_exit_passable() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.SHRINE_CLEARING)
	for exit in m.exits:
		assert_true(AsciiMapData.is_passable(m.get_tile(exit.x, exit.y)))


func test_generator_forest_path_centre_passable() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.FOREST_PATH)
	# The path generator clears a walkable route — at least some centre
	# column tiles should be passable dirt.
	var passable_count: int = 0
	for y in range(AsciiMapData.MAP_SIZE):
		var tile: int = m.get_tile(15, y)
		if AsciiMapData.is_passable(tile):
			passable_count += 1
	assert_gt(passable_count, 10, "Forest path should have walkable centre tiles")


func test_generator_road_centre_passable() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.ROAD)
	var passable_count: int = 0
	for y in range(AsciiMapData.MAP_SIZE):
		if AsciiMapData.is_passable(m.get_tile(15, y)):
			passable_count += 1
	assert_gt(passable_count, 20, "Road centre column should be mostly passable")


func test_generator_river_crossing_has_water() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.RIVER_CROSSING)
	var water_count: int = 0
	for x in range(AsciiMapData.MAP_SIZE):
		var t: int = m.get_tile(x, 15)
		if t == Enums.TileType.WATER_DEEP or \
		   t == Enums.TileType.WATER_SHALLOW or \
		   t == Enums.TileType.FLOOR_WOOD:
			water_count += 1
	assert_gt(water_count, 5, "River crossing should have water or bridge tiles")


func test_generator_farmland_has_crops() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.FARMLAND)
	var crop_count: int = 0
	for i in range(AsciiMapData.TILE_COUNT):
		if m.tile_types[i] == Enums.TileType.CROPS or \
		   m.tile_types[i] == Enums.TileType.WATER_PADDY:
			crop_count += 1
	assert_gt(crop_count, 50, "Farmland should be mostly crops/paddies")


func test_generator_default_fallback_produces_valid_map() -> void:
	# WALL_TOWER is a zone subtype with no dedicated generator — uses default.
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.WALL_TOWER)
	assert_eq(m.tile_types.size(), AsciiMapData.TILE_COUNT)
	# Should have at least two exits.
	assert_eq(m.exits.size(), 2)


# ---------------------------------------------------------------------------
# AsciiMapGenerator — glyph and colour helpers
# ---------------------------------------------------------------------------

func test_get_glyph_stone_wall() -> void:
	assert_eq(AsciiMapGenerator.get_glyph(Enums.TileType.WALL_STONE), "█")


func test_get_glyph_floor_grass() -> void:
	assert_eq(AsciiMapGenerator.get_glyph(Enums.TileType.FLOOR_GRASS), ".")


func test_get_glyph_zone_exit() -> void:
	assert_eq(AsciiMapGenerator.get_glyph(Enums.TileType.ZONE_EXIT), ">")


func test_get_glyph_water_rapid() -> void:
	assert_eq(AsciiMapGenerator.get_glyph(Enums.TileType.WATER_RAPID), "≈")


func test_get_fg_color_stone_wall_is_grey() -> void:
	var c: Color = AsciiMapGenerator.get_fg_color(Enums.TileType.WALL_STONE)
	# Grey: R ≈ G ≈ B, each near 0.5.
	assert_almost_eq(c.r, c.g, 0.05)
	assert_almost_eq(c.g, c.b, 0.05)


func test_get_bg_color_floor_transparent() -> void:
	var c: Color = AsciiMapGenerator.get_bg_color(Enums.TileType.FLOOR_GRASS)
	assert_almost_eq(c.a, 0.0, 0.01)


func test_get_bg_color_deep_water_opaque() -> void:
	var c: Color = AsciiMapGenerator.get_bg_color(Enums.TileType.WATER_DEEP)
	assert_almost_eq(c.a, 1.0, 0.01)
	# Should be distinctly blue.
	assert_gt(c.b, c.r)


# ---------------------------------------------------------------------------
# AsciiMapGenerator — wood wall glyph connectivity
# ---------------------------------------------------------------------------

func test_wood_wall_vertical_glyph() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	# Vertical strip of wood wall at x=5.
	for y in range(0, 5):
		m.set_tile(5, y, Enums.TileType.WALL_WOOD)
	# Middle tile: north and south neighbours are walls → vertical bar.
	var g: String = AsciiMapGenerator.get_glyph(Enums.TileType.WALL_WOOD, 5, 2, m)
	assert_eq(g, "┃")


func test_wood_wall_corner_glyph() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	# L-shaped wood wall: top-left corner at (5,5).
	m.set_tile(5, 5, Enums.TileType.WALL_WOOD)
	m.set_tile(6, 5, Enums.TileType.WALL_WOOD)  # east
	m.set_tile(5, 6, Enums.TileType.WALL_WOOD)  # south
	# (5,5) connects south and east → ┏
	var g: String = AsciiMapGenerator.get_glyph(Enums.TileType.WALL_WOOD, 5, 5, m)
	assert_eq(g, "┏")


func test_wood_wall_horizontal_glyph() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	for x in range(3, 8):
		m.set_tile(x, 5, Enums.TileType.WALL_WOOD)
	var g: String = AsciiMapGenerator.get_glyph(Enums.TileType.WALL_WOOD, 5, 5, m)
	assert_eq(g, "━")


# ---------------------------------------------------------------------------
# FovSystem — Bresenham line (internal, tested indirectly through visibility)
# ---------------------------------------------------------------------------

func test_fov_thin_wall_gap_allows_diagonal_sight() -> void:
	var m: AsciiMapData = _make_open_map()
	# Wall row with a 1-tile gap.
	for x in range(0, AsciiMapData.MAP_SIZE):
		m.set_tile(x, 12, Enums.TileType.WALL_STONE)
	m.set_tile(15, 12, Enums.TileType.FLOOR_GRASS)  # gap at centre
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	# Tile directly through the gap should be visible.
	assert_true(visible.get(Vector2i(15, 11), false), "Should see through gap in wall")
