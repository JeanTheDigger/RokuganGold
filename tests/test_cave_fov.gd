extends GutTest
## Integration tests: FovSystem + CaveMapData (s4.4.2 + s56.3).
##
## Verifies that the inheritance chain (CaveMapData → AsciiMapData) lets
## FovSystem work on cave maps without any special-casing, including maps
## much larger than the 31×31 viewport.


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_cave(
		seed_str: String = "fov_test",
		strength: int = 4) -> CaveMapData:
	return CaveTemplateGenerator.generate(seed_str, strength,
		[CaveMapData.ObjType.KILL_LEADER])


func _entry_room(map: CaveMapData) -> Dictionary:
	return map.rooms[0]


# Hand-crafted map with a single open room carved into a stone field.
# Returns the map and the centre of the open area as a Vector2i.
func _open_room_map() -> Array:
	var map := CaveMapData.new()
	map.width = 30
	map.height = 30
	map.init_tiles(Enums.TileType.WALL_STONE)
	map.fill_rect(5, 5, 14, 14, Enums.TileType.FLOOR_STONE)
	return [map, Vector2i(9, 9)]  # centre of the 10×10 room


# ---------------------------------------------------------------------------
# Type compatibility
# ---------------------------------------------------------------------------

func test_cave_map_is_ascii_map_data_instance() -> void:
	var map: CaveMapData = _make_cave()
	assert_is(map, AsciiMapData,
		"CaveMapData must be an AsciiMapData for FovSystem polymorphism")


func test_compute_visible_accepts_cave_map() -> void:
	var map: CaveMapData = _make_cave()
	var entry: Dictionary = _entry_room(map)
	var visible: Dictionary = FovSystem.compute_visible(
		entry["cx"], entry["cy"], 5, map)
	assert_true(visible.size() > 0,
		"compute_visible should return a non-empty set on a CaveMapData")


func test_has_los_accepts_cave_map() -> void:
	var map: CaveMapData = _make_cave()
	var entry: Dictionary = _entry_room(map)
	# LOS from a tile to itself is always true.
	var ok: bool = FovSystem.has_los(
		entry["cx"], entry["cy"],
		entry["cx"], entry["cy"],
		map)
	assert_true(ok, "has_los from a tile to itself must be true on CaveMapData")


func test_is_visible_accepts_cave_map() -> void:
	var map: CaveMapData = _make_cave()
	var entry: Dictionary = _entry_room(map)
	var ok: bool = FovSystem.is_visible(
		entry["cx"], entry["cy"],
		entry["cx"], entry["cy"],
		6, map)
	assert_true(ok, "is_visible to own tile must be true on CaveMapData")


# ---------------------------------------------------------------------------
# Viewer's tile is always in the visible set
# ---------------------------------------------------------------------------

func test_viewer_tile_always_visible_multiple_seeds() -> void:
	for seed: String in ["fov_seed_a", "fov_seed_b", "fov_seed_c"]:
		var map: CaveMapData = _make_cave(seed)
		var entry: Dictionary = _entry_room(map)
		var visible: Dictionary = FovSystem.compute_visible(
			entry["cx"], entry["cy"], 4, map)
		assert_true(visible.has(Vector2i(entry["cx"], entry["cy"])),
			"Viewer tile must always be in visible set (seed: %s)" % seed)


# ---------------------------------------------------------------------------
# Vision radius is respected on cave-sized (larger than 31×31) maps
# ---------------------------------------------------------------------------

func test_visible_tiles_within_radius_on_small_cave() -> void:
	# SMALL = 40×36 — wider than viewport.
	var map: CaveMapData = _make_cave("small_radius", 2)
	var entry: Dictionary = _entry_room(map)
	var radius: int = 5
	var cx: int = entry["cx"]
	var cy: int = entry["cy"]
	var visible: Dictionary = FovSystem.compute_visible(cx, cy, radius, map)
	var radius_sq: int = radius * radius
	for key: Variant in visible.keys():
		var pos: Vector2i = key
		var dx: int = pos.x - cx
		var dy: int = pos.y - cy
		assert_true(dx * dx + dy * dy <= radius_sq,
			"Visible tile (%d,%d) is outside radius %d" % [pos.x, pos.y, radius])


func test_visible_tiles_within_radius_on_extensive_cave() -> void:
	# EXTENSIVE = 100×84 — much larger than viewport.
	var map: CaveMapData = _make_cave("extensive_radius", 10)
	assert_eq(map.size_category, CaveMapData.SizeCategory.EXTENSIVE)
	var entry: Dictionary = _entry_room(map)
	var radius: int = 6
	var cx: int = entry["cx"]
	var cy: int = entry["cy"]
	var visible: Dictionary = FovSystem.compute_visible(cx, cy, radius, map)
	var radius_sq: int = radius * radius
	for key: Variant in visible.keys():
		var pos: Vector2i = key
		var dx: int = pos.x - cx
		var dy: int = pos.y - cy
		assert_true(dx * dx + dy * dy <= radius_sq,
			"Visible tile (%d,%d) is outside radius %d on EXTENSIVE cave" % [pos.x, pos.y, radius])


# ---------------------------------------------------------------------------
# Wall blocking (hand-crafted maps for determinism)
# ---------------------------------------------------------------------------

func test_stone_wall_column_blocks_vision() -> void:
	# Open field with a solid wall column at x=10.
	var map := CaveMapData.new()
	map.width = 25
	map.height = 25
	map.init_tiles(Enums.TileType.FLOOR_STONE)
	for y: int in range(25):
		map.set_tile(10, y, Enums.TileType.WALL_STONE)
	var visible: Dictionary = FovSystem.compute_visible(5, 12, 15, map)
	# x=15 is behind the wall and must not be visible.
	assert_false(visible.has(Vector2i(15, 12)),
		"Tile behind WALL_STONE column should not be visible")


func test_all_floor_tiles_visible_inside_open_room() -> void:
	var result: Array = _open_room_map()
	var map: CaveMapData = result[0]
	var centre: Vector2i = result[1]
	var visible: Dictionary = FovSystem.compute_visible(
		centre.x, centre.y, 12, map)
	# Every tile in the 10×10 open area (5–14, 5–14) must be visible.
	for y: int in range(5, 15):
		for x: int in range(5, 15):
			assert_true(visible.has(Vector2i(x, y)),
				"Open room tile (%d,%d) not visible from centre (%d,%d)" % [x, y, centre.x, centre.y])


func test_tiles_outside_open_room_not_visible_through_walls() -> void:
	var result: Array = _open_room_map()
	var map: CaveMapData = result[0]
	var centre: Vector2i = result[1]
	var visible: Dictionary = FovSystem.compute_visible(
		centre.x, centre.y, 12, map)
	# x=2, y=9 is in solid stone to the left of the room and must not be visible.
	assert_false(visible.has(Vector2i(2, 9)),
		"Tile outside the room through solid wall should not be visible")


# ---------------------------------------------------------------------------
# has_los on hand-crafted maps
# ---------------------------------------------------------------------------

func test_has_los_true_between_adjacent_floor_tiles() -> void:
	var result: Array = _open_room_map()
	var map: CaveMapData = result[0]
	assert_true(FovSystem.has_los(9, 9, 9, 10, map),
		"Adjacent floor tiles must have LOS")


func test_has_los_false_through_wall() -> void:
	var map := CaveMapData.new()
	map.width = 20
	map.height = 20
	map.init_tiles(Enums.TileType.FLOOR_STONE)
	# Solid wall row at y=10.
	for x: int in range(20):
		map.set_tile(x, 10, Enums.TileType.WALL_STONE)
	assert_false(FovSystem.has_los(9, 5, 9, 15, map),
		"LOS through a solid wall row must be false")


# ---------------------------------------------------------------------------
# effective_radius clamps to 1 even on cave maps
# ---------------------------------------------------------------------------

func test_effective_radius_minimum_one() -> void:
	assert_eq(FovSystem.effective_radius(1, 99), 1,
		"effective_radius must never go below 1")


func test_effective_radius_subtracts_env_modifier() -> void:
	assert_eq(FovSystem.effective_radius(5, 3), 2,
		"effective_radius(5, 3) should be 2")
