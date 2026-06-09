extends GutTest
## Tests for the ASCII map system: AsciiMapData, FovSystem, AsciiMapGenerator.
## s4.4 — LOCKED.


# ---------------------------------------------------------------------------
# AsciiMapData — data model
# ---------------------------------------------------------------------------

func test_ascii_map_data_init_correct_size() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	assert_eq(m.tile_types.size(), m.width * m.height)


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
	assert_eq(m.get_tile(m.width, 0), Enums.TileType.WALL_STONE)
	assert_eq(m.get_tile(0, m.height), Enums.TileType.WALL_STONE)


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
	for x in range(0, m.width):
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
	for x in range(0, m.width):
		m.set_tile(x, 12, Enums.TileType.WALL_WOOD)
	m.set_tile(15, 12, Enums.TileType.DOOR_WOOD_OPEN)
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	# Tile directly beyond the open door should be visible.
	assert_true(visible.get(Vector2i(15, 11), false), "Should see through open door")


func test_fov_closed_door_blocks_sight() -> void:
	var m: AsciiMapData = _make_open_map()
	for x in range(0, m.width):
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
	assert_eq(m.tile_types.size(), m.width * m.height)


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
	for i in range(m1.tile_types.size()):
		if m1.tile_types[i] != m2.tile_types[i]:
			differs = true
			break
	assert_true(differs, "Different settlements should produce different maps")


func test_generator_different_subtypes_produce_different_maps() -> void:
	var m1: AsciiMapData = _gen(Enums.ZoneSubtype.MARKET_STREET)
	var m2: AsciiMapData = _gen(Enums.ZoneSubtype.TEMPLE_GROUNDS)
	var differs: bool = false
	for i in range(m1.tile_types.size()):
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
	for y in range(m.height):
		var tile: int = m.get_tile(15, y)
		if AsciiMapData.is_passable(tile):
			passable_count += 1
	assert_gt(passable_count, 10, "Forest path should have walkable centre tiles")


func test_generator_road_centre_passable() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.ROAD)
	var passable_count: int = 0
	for y in range(m.height):
		if AsciiMapData.is_passable(m.get_tile(15, y)):
			passable_count += 1
	assert_gt(passable_count, 20, "Road centre column should be mostly passable")


func test_generator_river_crossing_has_water() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.RIVER_CROSSING)
	var water_count: int = 0
	for x in range(m.width):
		var t: int = m.get_tile(x, 15)
		if t == Enums.TileType.WATER_DEEP or \
		   t == Enums.TileType.WATER_SHALLOW or \
		   t == Enums.TileType.FLOOR_WOOD:
			water_count += 1
	assert_gt(water_count, 5, "River crossing should have water or bridge tiles")


func test_generator_farmland_has_crops() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.FARMLAND)
	var crop_count: int = 0
	for i in range(m.tile_types.size()):
		if m.tile_types[i] == Enums.TileType.CROPS or \
		   m.tile_types[i] == Enums.TileType.WATER_PADDY:
			crop_count += 1
	assert_gt(crop_count, 50, "Farmland should be mostly crops/paddies")


func test_generator_default_fallback_produces_valid_map() -> void:
	# All 25 ZoneSubtype values have dedicated generators. Use a raw int
	# outside the enum range to exercise the default fallback.
	var m: AsciiMapData = AsciiMapGenerator.generate(
		"zone_test", "Test Zone", 999, "Shiro Kakita"
	)
	assert_eq(m.tile_types.size(), m.width * m.height)
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
# FovSystem — wall gap and corridor visibility
# ---------------------------------------------------------------------------

func test_fov_thin_wall_gap_allows_sight() -> void:
	var m: AsciiMapData = _make_open_map()
	for x in range(0, m.width):
		m.set_tile(x, 12, Enums.TileType.WALL_STONE)
	m.set_tile(15, 12, Enums.TileType.FLOOR_GRASS)
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	assert_true(visible.get(Vector2i(15, 11), false), "Should see through gap in wall")


func test_fov_l_shaped_corridor_blocks_around_corner() -> void:
	var m: AsciiMapData = _make_open_map()
	# Build an L-shaped wall: horizontal at y=12, vertical at x=17.
	for x in range(10, 21):
		m.set_tile(x, 12, Enums.TileType.WALL_STONE)
	for y in range(8, 13):
		m.set_tile(17, y, Enums.TileType.WALL_STONE)
	# Gap at (15,12) for door.
	m.set_tile(15, 12, Enums.TileType.FLOOR_GRASS)
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	# Can see through the gap directly north.
	assert_true(visible.get(Vector2i(15, 11), false))
	# Cannot see around the corner past the vertical wall.
	assert_false(visible.get(Vector2i(18, 10), false))


func test_fov_pillar_casts_shadow() -> void:
	var m: AsciiMapData = _make_open_map()
	# Single pillar 2 tiles north.
	m.set_tile(15, 13, Enums.TileType.WALL_STONE)
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	# Pillar visible.
	assert_true(visible.get(Vector2i(15, 13), false))
	# Tile directly behind pillar hidden.
	assert_false(visible.get(Vector2i(15, 12), false))


func test_fov_pillar_does_not_block_adjacent_tiles() -> void:
	var m: AsciiMapData = _make_open_map()
	m.set_tile(15, 13, Enums.TileType.WALL_STONE)
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	# Tiles to the side of the pillar's shadow should still be visible.
	assert_true(visible.get(Vector2i(14, 12), false))
	assert_true(visible.get(Vector2i(16, 12), false))


# ---------------------------------------------------------------------------
# FovSystem — lookout_radius (s56.10)
# ---------------------------------------------------------------------------

func test_fov_lookout_radius_adds_bonus() -> void:
	# LOOKOUT_BONUS = 3 (s4.4.2): perception 3 + 3 = 6.
	assert_eq(FovSystem.lookout_radius(3, 0), 6)


func test_fov_lookout_radius_with_env_modifier() -> void:
	# 3 + 3 (lookout) − 2 (env) = 4.
	assert_eq(FovSystem.lookout_radius(3, 2), 4)


func test_fov_lookout_radius_minimum_one() -> void:
	assert_eq(FovSystem.lookout_radius(1, 10), 1)


# ---------------------------------------------------------------------------
# FovSystem — has_los (point-to-point Bresenham)
# ---------------------------------------------------------------------------

func test_has_los_open_field() -> void:
	var m: AsciiMapData = _make_open_map()
	assert_true(FovSystem.has_los(15, 15, 15, 10, m))


func test_has_los_wall_blocks() -> void:
	var m: AsciiMapData = _make_open_map()
	m.set_tile(15, 13, Enums.TileType.WALL_STONE)
	# Wall at (15,13) blocks LOS to (15,10).
	assert_false(FovSystem.has_los(15, 15, 15, 10, m))


func test_has_los_wall_itself_reachable() -> void:
	var m: AsciiMapData = _make_open_map()
	m.set_tile(15, 13, Enums.TileType.WALL_STONE)
	# Can see the wall itself.
	assert_true(FovSystem.has_los(15, 15, 15, 13, m))


func test_has_los_open_door_allows() -> void:
	var m: AsciiMapData = _make_open_map()
	for x in range(0, m.width):
		m.set_tile(x, 12, Enums.TileType.WALL_WOOD)
	m.set_tile(15, 12, Enums.TileType.DOOR_WOOD_OPEN)
	assert_true(FovSystem.has_los(15, 15, 15, 10, m))


func test_has_los_closed_door_blocks() -> void:
	var m: AsciiMapData = _make_open_map()
	m.set_tile(15, 12, Enums.TileType.DOOR_WOOD_CLOSED)
	assert_false(FovSystem.has_los(15, 15, 15, 10, m))


# ---------------------------------------------------------------------------
# FovSystem — is_visible (combined radius + LOS)
# ---------------------------------------------------------------------------

func test_is_visible_within_radius_clear() -> void:
	var m: AsciiMapData = _make_open_map()
	assert_true(FovSystem.is_visible(15, 15, 15, 13, 4, m))


func test_is_visible_beyond_radius() -> void:
	var m: AsciiMapData = _make_open_map()
	assert_false(FovSystem.is_visible(15, 15, 15, 5, 4, m))


func test_is_visible_blocked_by_wall() -> void:
	var m: AsciiMapData = _make_open_map()
	m.set_tile(15, 13, Enums.TileType.WALL_STONE)
	assert_false(FovSystem.is_visible(15, 15, 15, 12, 6, m))


# ---------------------------------------------------------------------------
# FovSystem — fire blocks LOS
# ---------------------------------------------------------------------------

func test_fov_fire_blocks_los_in_fov() -> void:
	var m: AsciiMapData = _make_open_map()
	m.set_tile(15, 13, Enums.TileType.FIRE)
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	# Fire tile visible.
	assert_true(visible.get(Vector2i(15, 13), false))
	# Tile behind fire hidden.
	assert_false(visible.get(Vector2i(15, 12), false))


# ---------------------------------------------------------------------------
# FovSystem — delta-modified tiles affect FOV
# ---------------------------------------------------------------------------

func test_fov_delta_opened_door_allows_sight() -> void:
	var m: AsciiMapData = _make_open_map()
	for x in range(0, m.width):
		m.set_tile(x, 12, Enums.TileType.WALL_WOOD)
	m.set_tile(15, 12, Enums.TileType.DOOR_WOOD_CLOSED)
	# Door is closed in base map — blocks LOS.
	var v1: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	assert_false(v1.get(Vector2i(15, 11), false))
	# Open the door via delta.
	m.toggle_door(15, 12)
	var v2: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	assert_true(v2.get(Vector2i(15, 11), false), "Opened door should allow sight")


func test_fov_destroyed_wall_allows_sight() -> void:
	var m: AsciiMapData = _make_open_map()
	m.set_tile(15, 13, Enums.TileType.WALL_PAPER)
	# Paper wall blocks LOS.
	var v1: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	assert_false(v1.get(Vector2i(15, 12), false))
	# Destroy it → becomes RUBBLE (passable, no LOS block).
	m.destroy_tile(15, 13)
	var v2: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
	assert_true(v2.get(Vector2i(15, 12), false), "Rubble should not block LOS")


# ---------------------------------------------------------------------------
# FovSystem — radius 1 (minimum, adjacent only)
# ---------------------------------------------------------------------------

func test_fov_radius_one_sees_adjacent_only() -> void:
	var m: AsciiMapData = _make_open_map()
	var visible: Dictionary = FovSystem.compute_visible(15, 15, 1, m)
	# FOV uses a Euclidean radius (dx²+dy² <= r²). At radius 1 the 4 orthogonal
	# neighbours are within range; diagonals (dist √2 ≈ 1.41) are not.
	for d in [Vector2i(15, 14), Vector2i(15, 16), Vector2i(14, 15), Vector2i(16, 15)]:
		assert_true(visible.get(d, false), "Orthogonal %s should be visible" % d)
	assert_false(visible.get(Vector2i(14, 14), false), "Diagonal out of radius 1")
	# 2 tiles away not visible.
	assert_false(visible.get(Vector2i(15, 13), false))
	assert_false(visible.get(Vector2i(17, 15), false))


# ---------------------------------------------------------------------------
# FovSystem — map edge behaviour
# ---------------------------------------------------------------------------

func test_fov_at_corner_does_not_crash() -> void:
	var m: AsciiMapData = _make_open_map()
	var visible: Dictionary = FovSystem.compute_visible(0, 0, 3, m)
	assert_true(visible.get(Vector2i(0, 0), false))
	assert_true(visible.get(Vector2i(1, 0), false))
	assert_true(visible.get(Vector2i(0, 1), false))
	# Out-of-bounds tiles should not appear.
	assert_false(visible.has(Vector2i(-1, 0)))
	assert_false(visible.has(Vector2i(0, -1)))


func test_fov_at_far_corner() -> void:
	var m: AsciiMapData = _make_open_map()
	var edge_x: int = m.width - 1
	var edge_y: int = m.height - 1
	var visible: Dictionary = FovSystem.compute_visible(edge_x, edge_y, 3, m)
	assert_true(visible.get(Vector2i(edge_x, edge_y), false))
	assert_true(visible.get(Vector2i(edge_x - 1, edge_y), false))
	assert_false(visible.has(Vector2i(edge_x + 1, edge_y)))


# ---------------------------------------------------------------------------
# FovSystem — environmental modifier constants match GDD s4.4.2
# ---------------------------------------------------------------------------

func test_env_modifier_values() -> void:
	assert_eq(FovSystem.ENV_CLEAR, 0)
	assert_eq(FovSystem.ENV_OVERCAST, 1)
	assert_eq(FovSystem.ENV_HEAVY_RAIN, 2)
	assert_eq(FovSystem.ENV_NIGHT, 3)
	assert_eq(FovSystem.ENV_SUPERNATURAL, 4)


# ---------------------------------------------------------------------------
# FovSystem — symmetry: if A sees B, B sees A (in open space)
# ---------------------------------------------------------------------------

func test_fov_symmetry_open_field() -> void:
	var m: AsciiMapData = _make_open_map()
	var r: int = 4
	var ax: int = 13
	var ay: int = 14
	var bx: int = 16
	var by: int = 12
	var vis_a: Dictionary = FovSystem.compute_visible(ax, ay, r, m)
	var vis_b: Dictionary = FovSystem.compute_visible(bx, by, r, m)
	assert_eq(
		vis_a.get(Vector2i(bx, by), false),
		vis_b.get(Vector2i(ax, ay), false),
		"Symmetric visibility in open field"
	)


# ---------------------------------------------------------------------------
# FovSystem — all wall types block, all open types don't
# ---------------------------------------------------------------------------

func test_fov_all_wall_types_block() -> void:
	var walls: Array[int] = [
		Enums.TileType.WALL_STONE,
		Enums.TileType.WALL_WOOD,
		Enums.TileType.WALL_PAPER,
	]
	for wall in walls:
		var m: AsciiMapData = _make_open_map()
		m.set_tile(15, 13, wall)
		var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
		assert_false(
			visible.get(Vector2i(15, 12), false),
			"Wall type %d should block LOS" % wall
		)


func test_fov_trees_block_los() -> void:
	var trees: Array[int] = [
		Enums.TileType.TREE_EVERGREEN,
		Enums.TileType.TREE_DECIDUOUS,
		Enums.TileType.TREE_CHERRY,
		Enums.TileType.BAMBOO,
	]
	for tree in trees:
		var m: AsciiMapData = _make_open_map()
		m.set_tile(15, 13, tree)
		var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
		assert_false(
			visible.get(Vector2i(15, 12), false),
			"Tree type %d should block LOS" % tree
		)


func test_fov_open_doors_allow_los() -> void:
	var open_doors: Array[int] = [
		Enums.TileType.DOOR_SHOJI_OPEN,
		Enums.TileType.DOOR_WOOD_OPEN,
		Enums.TileType.GATE_OPEN,
	]
	for door in open_doors:
		var m: AsciiMapData = _make_open_map()
		m.set_tile(15, 13, door)
		var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
		assert_true(
			visible.get(Vector2i(15, 12), false),
			"Open door type %d should not block LOS" % door
		)


func test_fov_closed_doors_block_los() -> void:
	var closed_doors: Array[int] = [
		Enums.TileType.DOOR_SHOJI_CLOSED,
		Enums.TileType.DOOR_WOOD_CLOSED,
		Enums.TileType.GATE_CLOSED,
	]
	for door in closed_doors:
		var m: AsciiMapData = _make_open_map()
		m.set_tile(15, 13, door)
		var visible: Dictionary = FovSystem.compute_visible(15, 15, 6, m)
		assert_false(
			visible.get(Vector2i(15, 12), false),
			"Closed door type %d should block LOS" % door
		)


# ---------------------------------------------------------------------------
# AsciiMapGenerator — Castle Interior zone generators
# ---------------------------------------------------------------------------

func _has_tile_type(map: AsciiMapData, tile: int) -> bool:
	for i in range(map.tile_types.size()):
		if map.tile_types[i] == tile:
			return true
	return false


func _count_tile_type(map: AsciiMapData, tile: int) -> int:
	var count: int = 0
	for i in range(map.tile_types.size()):
		if map.tile_types[i] == tile:
			count += 1
	return count


func _assert_exits_passable(map: AsciiMapData) -> void:
	for exit in map.exits:
		var tile: int = map.get_tile(exit.x, exit.y)
		assert_true(AsciiMapData.is_passable(tile),
			"Exit at (%d,%d) must be passable, got %d" % [exit.x, exit.y, tile])


func test_generator_ohiroma_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.OHIROMA)
	assert_gt(m.exits.size(), 0)
	_assert_exits_passable(m)


func test_generator_ohiroma_has_tatami_and_dais() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.OHIROMA)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_TATAMI))
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_STONE))


func test_generator_enkai_hall_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.ENKAI_HALL)
	assert_gt(m.exits.size(), 0)
	_assert_exits_passable(m)


func test_generator_enkai_hall_has_tatami_seating() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.ENKAI_HALL)
	assert_gt(_count_tile_type(m, Enums.TileType.FLOOR_TATAMI), 30)


func test_generator_audience_chamber_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.AUDIENCE_CHAMBER)
	assert_eq(m.exits.size(), 2)
	_assert_exits_passable(m)


func test_generator_audience_chamber_has_tokonoma() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.AUDIENCE_CHAMBER)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_TATAMI))
	assert_true(_has_tile_type(m, Enums.TileType.WALL_PAPER))


func test_generator_chashitsu_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.CHASHITSU)
	assert_gt(m.exits.size(), 0)
	_assert_exits_passable(m)


func test_generator_chashitsu_has_garden_and_tea_room() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.CHASHITSU)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_GRASS))
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_TATAMI))
	assert_true(_has_tile_type(m, Enums.TileType.TREE_CHERRY))


func test_generator_guest_wing_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.GUEST_WING)
	assert_gt(m.exits.size(), 0)
	_assert_exits_passable(m)


func test_generator_guest_wing_has_rooms() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.GUEST_WING)
	assert_gt(_count_tile_type(m, Enums.TileType.FLOOR_TATAMI), 20)
	assert_true(_has_tile_type(m, Enums.TileType.DOOR_SHOJI_OPEN))


func test_generator_lord_quarters_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.LORD_QUARTERS)
	assert_gt(m.exits.size(), 0)
	_assert_exits_passable(m)


func test_generator_lord_quarters_has_tokonoma_and_chambers() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.LORD_QUARTERS)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_TATAMI))
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_STONE))
	assert_true(_has_tile_type(m, Enums.TileType.DOOR_SHOJI_OPEN))


func test_generator_war_council_room_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.WAR_COUNCIL_ROOM)
	assert_gt(m.exits.size(), 0)
	_assert_exits_passable(m)


func test_generator_war_council_room_has_table_and_wood_floor() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.WAR_COUNCIL_ROOM)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_STONE))
	assert_gt(_count_tile_type(m, Enums.TileType.FLOOR_WOOD), 50)


func test_generator_dojo_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.DOJO)
	assert_gt(m.exits.size(), 0)
	_assert_exits_passable(m)


func test_generator_dojo_has_open_training_floor() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.DOJO)
	assert_gt(_count_tile_type(m, Enums.TileType.FLOOR_WOOD), 100)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_STONE))


func test_generator_outer_courtyard_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.OUTER_COURTYARD)
	assert_eq(m.exits.size(), 2)
	_assert_exits_passable(m)


func test_generator_outer_courtyard_has_stone_and_garden() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.OUTER_COURTYARD)
	assert_gt(_count_tile_type(m, Enums.TileType.FLOOR_STONE), 50)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_GRASS))
	assert_true(_has_tile_type(m, Enums.TileType.TREE_CHERRY))


func test_generator_tsuboniwa_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.TSUBONIWA)
	assert_gt(m.exits.size(), 0)
	_assert_exits_passable(m)


func test_generator_tsuboniwa_has_garden_features() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.TSUBONIWA)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_GRASS))
	assert_true(_has_tile_type(m, Enums.TileType.WATER_SHALLOW))
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_STONE))


func test_generator_castle_shrine_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.CASTLE_SHRINE)
	assert_gt(m.exits.size(), 0)
	_assert_exits_passable(m)


func test_generator_castle_shrine_has_torii_and_altar() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.CASTLE_SHRINE)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_TATAMI))
	assert_true(_has_tile_type(m, Enums.TileType.TREE_EVERGREEN))
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_GRASS))


# ---------------------------------------------------------------------------
# AsciiMapGenerator — Urban District zone generators
# ---------------------------------------------------------------------------

func test_generator_pleasure_quarter_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.PLEASURE_QUARTER)
	assert_eq(m.exits.size(), 2)
	_assert_exits_passable(m)


func test_generator_pleasure_quarter_has_buildings() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.PLEASURE_QUARTER)
	assert_gt(_count_tile_type(m, Enums.TileType.FLOOR_TATAMI), 30)
	assert_true(_has_tile_type(m, Enums.TileType.DOOR_SHOJI_OPEN))


func test_generator_docks_waterfront_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.DOCKS_WATERFRONT)
	assert_eq(m.exits.size(), 2)
	_assert_exits_passable(m)


func test_generator_docks_waterfront_has_water_and_piers() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.DOCKS_WATERFRONT)
	assert_gt(_count_tile_type(m, Enums.TileType.WATER_DEEP), 50)
	assert_true(_has_tile_type(m, Enums.TileType.WATER_SHALLOW))
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_STONE))


func test_generator_poor_quarter_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.POOR_QUARTER)
	assert_eq(m.exits.size(), 2)
	_assert_exits_passable(m)


func test_generator_poor_quarter_has_mud_and_dirt() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.POOR_QUARTER)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_MUD))
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_DIRT))


func test_generator_government_quarter_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.GOVERNMENT_QUARTER)
	assert_eq(m.exits.size(), 2)
	_assert_exits_passable(m)


func test_generator_government_quarter_has_stone_buildings() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.GOVERNMENT_QUARTER)
	assert_gt(_count_tile_type(m, Enums.TileType.FLOOR_STONE), 100)
	assert_gt(_count_tile_type(m, Enums.TileType.WALL_STONE), 20)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_TATAMI))


# ---------------------------------------------------------------------------
# AsciiMapGenerator — Wilderness and Military zone generators
# ---------------------------------------------------------------------------

func test_generator_mountain_pass_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.MOUNTAIN_PASS)
	assert_eq(m.exits.size(), 2)
	_assert_exits_passable(m)


func test_generator_mountain_pass_has_cliff_walls_and_path() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.MOUNTAIN_PASS)
	assert_gt(_count_tile_type(m, Enums.TileType.WALL_STONE), 100)
	assert_gt(_count_tile_type(m, Enums.TileType.FLOOR_STONE), 30)


func test_generator_wall_tower_has_exits() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.WALL_TOWER)
	assert_gt(m.exits.size(), 0)
	_assert_exits_passable(m)


func test_generator_wall_tower_has_battlements_and_interior() -> void:
	var m: AsciiMapData = _gen(Enums.ZoneSubtype.WALL_TOWER)
	assert_gt(_count_tile_type(m, Enums.TileType.WALL_STONE), 30)
	assert_true(_has_tile_type(m, Enums.TileType.FLOOR_WOOD))
	assert_true(_has_tile_type(m, Enums.TileType.DOOR_WOOD_OPEN))


# ---------------------------------------------------------------------------
# AsciiMapGenerator — all 25 subtypes produce valid maps
# ---------------------------------------------------------------------------

# ---------------------------------------------------------------------------
# AsciiMapData — dynamic tile operations (doors, destruction, fire)
# ---------------------------------------------------------------------------

func test_toggle_door_shoji_closed_to_open() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.DOOR_SHOJI_CLOSED)
	var ok: bool = m.toggle_door(5, 5)
	assert_true(ok)
	assert_eq(m.get_tile(5, 5), Enums.TileType.DOOR_SHOJI_OPEN)


func test_toggle_door_shoji_open_to_closed() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.DOOR_SHOJI_OPEN)
	assert_true(m.toggle_door(5, 5))
	assert_eq(m.get_tile(5, 5), Enums.TileType.DOOR_SHOJI_CLOSED)


func test_toggle_door_wood() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.DOOR_WOOD_CLOSED)
	assert_true(m.toggle_door(5, 5))
	assert_eq(m.get_tile(5, 5), Enums.TileType.DOOR_WOOD_OPEN)
	assert_true(m.toggle_door(5, 5))
	assert_eq(m.get_tile(5, 5), Enums.TileType.DOOR_WOOD_CLOSED)


func test_toggle_door_gate() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.GATE_CLOSED)
	assert_true(m.toggle_door(5, 5))
	assert_eq(m.get_tile(5, 5), Enums.TileType.GATE_OPEN)


func test_toggle_door_non_door_returns_false() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	assert_false(m.toggle_door(5, 5))
	assert_eq(m.get_tile(5, 5), Enums.TileType.FLOOR_GRASS)


func test_toggle_door_uses_delta() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.DOOR_SHOJI_CLOSED)
	m.toggle_door(5, 5)
	assert_true(m.deltas.has("5,5"))
	m.clear_delta(5, 5)
	assert_eq(m.get_tile(5, 5), Enums.TileType.DOOR_SHOJI_CLOSED)


func test_is_door_true_for_all_door_types() -> void:
	assert_true(AsciiMapData.is_door(Enums.TileType.DOOR_SHOJI_CLOSED))
	assert_true(AsciiMapData.is_door(Enums.TileType.DOOR_SHOJI_OPEN))
	assert_true(AsciiMapData.is_door(Enums.TileType.DOOR_WOOD_CLOSED))
	assert_true(AsciiMapData.is_door(Enums.TileType.DOOR_WOOD_OPEN))
	assert_true(AsciiMapData.is_door(Enums.TileType.GATE_CLOSED))
	assert_true(AsciiMapData.is_door(Enums.TileType.GATE_OPEN))


func test_is_door_false_for_non_doors() -> void:
	assert_false(AsciiMapData.is_door(Enums.TileType.WALL_STONE))
	assert_false(AsciiMapData.is_door(Enums.TileType.FLOOR_GRASS))
	assert_false(AsciiMapData.is_door(Enums.TileType.ZONE_EXIT))


func test_destroy_tile_paper_wall() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.WALL_PAPER)
	var result: int = m.destroy_tile(5, 5)
	assert_eq(result, Enums.TileType.RUBBLE)
	assert_eq(m.get_tile(5, 5), Enums.TileType.RUBBLE)


func test_destroy_tile_shoji_door() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.DOOR_SHOJI_CLOSED)
	var result: int = m.destroy_tile(5, 5)
	assert_eq(result, Enums.TileType.RUBBLE)
	assert_true(AsciiMapData.is_passable(m.get_tile(5, 5)))


func test_destroy_tile_wood_wall() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.WALL_WOOD)
	assert_eq(m.destroy_tile(5, 5), Enums.TileType.RUBBLE)


func test_destroy_tile_stone_wall_indestructible() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.WALL_STONE)
	assert_eq(m.destroy_tile(5, 5), -1)
	assert_eq(m.get_tile(5, 5), Enums.TileType.WALL_STONE)


func test_destroy_tile_bush_becomes_grass() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.BUSH)
	assert_eq(m.destroy_tile(5, 5), Enums.TileType.FLOOR_GRASS)


func test_destroy_tile_floor_not_destructible() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_TATAMI)
	assert_eq(m.destroy_tile(5, 5), -1)


func test_is_destructible() -> void:
	assert_true(AsciiMapData.is_destructible(Enums.TileType.WALL_PAPER))
	assert_true(AsciiMapData.is_destructible(Enums.TileType.WALL_WOOD))
	assert_true(AsciiMapData.is_destructible(Enums.TileType.DOOR_SHOJI_CLOSED))
	assert_true(AsciiMapData.is_destructible(Enums.TileType.BAMBOO))
	assert_false(AsciiMapData.is_destructible(Enums.TileType.WALL_STONE))
	assert_false(AsciiMapData.is_destructible(Enums.TileType.FLOOR_GRASS))


func test_burn_tile_wood_becomes_ash() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.WALL_WOOD)
	assert_eq(m.burn_tile(5, 5), Enums.TileType.FLOOR_ASH)
	assert_eq(m.get_tile(5, 5), Enums.TileType.FLOOR_ASH)


func test_burn_tile_tatami_becomes_ash() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_TATAMI)
	assert_eq(m.burn_tile(5, 5), Enums.TileType.FLOOR_ASH)


func test_burn_tile_stone_not_flammable() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	m.set_tile(5, 5, Enums.TileType.WALL_STONE)
	assert_eq(m.burn_tile(5, 5), -1)
	assert_eq(m.get_tile(5, 5), Enums.TileType.WALL_STONE)


func test_is_flammable() -> void:
	assert_true(AsciiMapData.is_flammable(Enums.TileType.WALL_WOOD))
	assert_true(AsciiMapData.is_flammable(Enums.TileType.WALL_PAPER))
	assert_true(AsciiMapData.is_flammable(Enums.TileType.FLOOR_WOOD))
	assert_true(AsciiMapData.is_flammable(Enums.TileType.FLOOR_TATAMI))
	assert_true(AsciiMapData.is_flammable(Enums.TileType.TREE_EVERGREEN))
	assert_true(AsciiMapData.is_flammable(Enums.TileType.CROPS))
	assert_false(AsciiMapData.is_flammable(Enums.TileType.WALL_STONE))
	assert_false(AsciiMapData.is_flammable(Enums.TileType.FLOOR_STONE))
	assert_false(AsciiMapData.is_flammable(Enums.TileType.WATER_DEEP))


func test_set_fire_on_flammable_tile() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_WOOD)
	assert_true(m.set_fire(5, 5))
	assert_eq(m.get_tile(5, 5), Enums.TileType.FIRE)


func test_set_fire_on_non_flammable_fails() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_STONE)
	assert_false(m.set_fire(5, 5))
	assert_eq(m.get_tile(5, 5), Enums.TileType.FLOOR_STONE)


func test_extinguish_fire_becomes_ash() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_WOOD)
	m.set_fire(5, 5)
	assert_true(m.extinguish(5, 5))
	assert_eq(m.get_tile(5, 5), Enums.TileType.FLOOR_ASH)


func test_extinguish_non_fire_fails() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.FLOOR_GRASS)
	assert_false(m.extinguish(5, 5))


func test_fire_blocks_los() -> void:
	assert_true(AsciiMapData.blocks_los(Enums.TileType.FIRE))


func test_ash_passable_no_los() -> void:
	assert_true(AsciiMapData.is_passable(Enums.TileType.FLOOR_ASH))
	assert_false(AsciiMapData.blocks_los(Enums.TileType.FLOOR_ASH))


func test_rubble_passable_no_los() -> void:
	assert_true(AsciiMapData.is_passable(Enums.TileType.RUBBLE))
	assert_false(AsciiMapData.blocks_los(Enums.TileType.RUBBLE))


func test_fire_passable() -> void:
	assert_true(AsciiMapData.is_passable(Enums.TileType.FIRE))


func test_glyph_for_new_tile_types() -> void:
	assert_eq(AsciiMapGenerator.get_glyph(Enums.TileType.FLOOR_ASH), ",")
	assert_eq(AsciiMapGenerator.get_glyph(Enums.TileType.FIRE), "^")
	assert_eq(AsciiMapGenerator.get_glyph(Enums.TileType.RUBBLE), ";")


func test_destroy_uses_delta_not_base() -> void:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(Enums.TileType.WALL_PAPER)
	m.destroy_tile(5, 5)
	assert_true(m.deltas.has("5,5"))
	m.clear_delta(5, 5)
	assert_eq(m.get_tile(5, 5), Enums.TileType.WALL_PAPER)


# ---------------------------------------------------------------------------
# AsciiMapGenerator — all 25 subtypes produce valid maps
# ---------------------------------------------------------------------------

func test_all_zone_subtypes_produce_valid_maps() -> void:
	var subtypes: Array[int] = [
		Enums.ZoneSubtype.OHIROMA, Enums.ZoneSubtype.ENKAI_HALL,
		Enums.ZoneSubtype.AUDIENCE_CHAMBER, Enums.ZoneSubtype.CHASHITSU,
		Enums.ZoneSubtype.GUEST_WING, Enums.ZoneSubtype.LORD_QUARTERS,
		Enums.ZoneSubtype.WAR_COUNCIL_ROOM, Enums.ZoneSubtype.DOJO,
		Enums.ZoneSubtype.OUTER_COURTYARD, Enums.ZoneSubtype.TSUBONIWA,
		Enums.ZoneSubtype.CASTLE_SHRINE, Enums.ZoneSubtype.MARKET_STREET,
		Enums.ZoneSubtype.RESIDENTIAL_QUARTER, Enums.ZoneSubtype.TEMPLE_GROUNDS,
		Enums.ZoneSubtype.PLEASURE_QUARTER, Enums.ZoneSubtype.DOCKS_WATERFRONT,
		Enums.ZoneSubtype.POOR_QUARTER, Enums.ZoneSubtype.GOVERNMENT_QUARTER,
		Enums.ZoneSubtype.SHRINE_CLEARING, Enums.ZoneSubtype.FOREST_PATH,
		Enums.ZoneSubtype.ROAD, Enums.ZoneSubtype.RIVER_CROSSING,
		Enums.ZoneSubtype.FARMLAND, Enums.ZoneSubtype.MOUNTAIN_PASS,
		Enums.ZoneSubtype.WALL_TOWER,
	]
	for st in subtypes:
		var m: AsciiMapData = _gen(st)
		assert_eq(m.tile_types.size(), m.width * m.height,
			"Subtype %d should produce full map" % st)
		assert_gt(m.exits.size(), 0,
			"Subtype %d should have at least one exit" % st)
		for exit in m.exits:
			assert_true(AsciiMapData.is_passable(m.get_tile(exit.x, exit.y)),
				"Subtype %d exit at (%d,%d) must be passable" % [st, exit.x, exit.y])
