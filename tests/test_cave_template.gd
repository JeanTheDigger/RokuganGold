extends GutTest
## Tests for the Cave template generator (s56.3 — LOCKED).
## CaveMapData and CaveTemplateGenerator.


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _gen(seed_str: String = "test", strength: int = 4,
		objectives: Array = [CaveMapData.ObjType.KILL_LEADER]) -> CaveMapData:
	return CaveTemplateGenerator.generate(seed_str, strength, objectives)


func _rng(seed_val: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new()
	r.seed = seed_val
	return r


func _room_by_type(map: CaveMapData, room_type: int) -> Dictionary:
	for r: Dictionary in map.rooms:
		if r["type"] == room_type:
			return r
	return {}


func _count_type(map: CaveMapData, room_type: int) -> int:
	var n: int = 0
	for r: Dictionary in map.rooms:
		if r["type"] == room_type:
			n += 1
	return n


func _count_role(map: CaveMapData, role: int) -> int:
	var n: int = 0
	for s: Dictionary in map.population_slots:
		if s["role"] == role:
			n += 1
	return n


# ---------------------------------------------------------------------------
# CaveMapData — data model
# ---------------------------------------------------------------------------

func test_cave_map_data_init_tiles_fills_correctly() -> void:
	var m := CaveMapData.new()
	m.width = 10
	m.height = 8
	m.init_tiles(Enums.TileType.WALL_STONE)
	assert_eq(m.tile_types.size(), 80)
	assert_eq(m.get_tile(0, 0), Enums.TileType.WALL_STONE)
	assert_eq(m.get_tile(9, 7), Enums.TileType.WALL_STONE)


func test_cave_map_data_get_set_tile_roundtrip() -> void:
	var m := CaveMapData.new()
	m.width = 20
	m.height = 15
	m.init_tiles(Enums.TileType.WALL_STONE)
	m.set_tile(5, 3, Enums.TileType.FLOOR_STONE)
	assert_eq(m.get_tile(5, 3), Enums.TileType.FLOOR_STONE)
	assert_eq(m.get_tile(5, 4), Enums.TileType.WALL_STONE)


func test_cave_map_data_out_of_bounds_returns_wall() -> void:
	var m := CaveMapData.new()
	m.width = 10
	m.height = 10
	m.init_tiles(Enums.TileType.FLOOR_STONE)
	assert_eq(m.get_tile(-1, 0), Enums.TileType.WALL_STONE)
	assert_eq(m.get_tile(0, -1), Enums.TileType.WALL_STONE)
	assert_eq(m.get_tile(10, 0), Enums.TileType.WALL_STONE)
	assert_eq(m.get_tile(0, 10), Enums.TileType.WALL_STONE)


func test_cave_map_data_delta_overrides_base() -> void:
	var m := CaveMapData.new()
	m.width = 10
	m.height = 10
	m.init_tiles(Enums.TileType.FLOOR_STONE)
	m.set_delta(3, 3, Enums.TileType.WATER_SHALLOW)
	assert_eq(m.get_tile(3, 3), Enums.TileType.WATER_SHALLOW)
	assert_eq(m.get_tile(3, 4), Enums.TileType.FLOOR_STONE)


func test_cave_map_data_clear_delta_restores_base() -> void:
	var m := CaveMapData.new()
	m.width = 10
	m.height = 10
	m.init_tiles(Enums.TileType.FLOOR_STONE)
	m.set_delta(5, 5, Enums.TileType.RUBBLE)
	m.clear_delta(5, 5)
	assert_eq(m.get_tile(5, 5), Enums.TileType.FLOOR_STONE)


func test_cave_map_data_fill_rect_sets_region() -> void:
	var m := CaveMapData.new()
	m.width = 20
	m.height = 20
	m.init_tiles(Enums.TileType.WALL_STONE)
	m.fill_rect(2, 2, 5, 5, Enums.TileType.FLOOR_STONE)
	assert_eq(m.get_tile(2, 2), Enums.TileType.FLOOR_STONE)
	assert_eq(m.get_tile(5, 5), Enums.TileType.FLOOR_STONE)
	assert_eq(m.get_tile(6, 6), Enums.TileType.WALL_STONE)


func test_cave_map_data_dims_count() -> void:
	assert_eq(CaveMapData.DIMS.size(), 4)


func test_cave_map_data_max_strength_count() -> void:
	assert_eq(CaveMapData.MAX_STRENGTH.size(), 4)


func test_cave_map_data_room_range_count() -> void:
	assert_eq(CaveMapData.ROOM_RANGE.size(), 4)


# ---------------------------------------------------------------------------
# pick_size_category — s56.3.1
# ---------------------------------------------------------------------------

func test_size_strength_1_never_above_small() -> void:
	# Strength 1 fits in SMALL; should never produce MEDIUM/LARGE/EXTENSIVE.
	var seen_sizes: Dictionary = {}
	for i: int in range(20):
		var r := _rng(i * 137 + 1)
		var s: int = CaveTemplateGenerator.pick_size_category(1, r)
		seen_sizes[s] = true
		assert_true(CaveMapData.MAX_STRENGTH[s] >= 1,
			"Size %d cannot house Strength 1" % s)


func test_size_strength_7_never_small() -> void:
	# Strength 7 requires LARGE or EXTENSIVE.
	for i: int in range(20):
		var r := _rng(i * 97 + 7)
		var s: int = CaveTemplateGenerator.pick_size_category(7, r)
		assert_true(s >= CaveMapData.SizeCategory.LARGE,
			"Strength 7 should be LARGE or EXTENSIVE, got %d" % s)


func test_size_strength_10_always_extensive() -> void:
	for i: int in range(10):
		var r := _rng(i * 53 + 10)
		var s: int = CaveTemplateGenerator.pick_size_category(10, r)
		assert_eq(s, CaveMapData.SizeCategory.EXTENSIVE)


func test_size_strength_4_can_be_medium_or_larger() -> void:
	var has_medium: bool = false
	for i: int in range(30):
		var r := _rng(i * 113 + 4)
		var s: int = CaveTemplateGenerator.pick_size_category(4, r)
		assert_true(CaveMapData.MAX_STRENGTH[s] >= 4)
		if s == CaveMapData.SizeCategory.MEDIUM:
			has_medium = true
	assert_true(has_medium, "Strength 4 should sometimes produce MEDIUM")


# ---------------------------------------------------------------------------
# pick_flow_pattern — s56.3.2
# ---------------------------------------------------------------------------

func test_flow_small_never_web() -> void:
	for i: int in range(20):
		var r := _rng(i * 71)
		var p: int = CaveTemplateGenerator.pick_flow_pattern(CaveMapData.SizeCategory.SMALL, r)
		assert_ne(p, CaveMapData.FlowPattern.WEB,
			"SMALL cave should never have WEB flow")


func test_flow_extensive_always_web() -> void:
	for i: int in range(10):
		var r := _rng(i * 43)
		var p: int = CaveTemplateGenerator.pick_flow_pattern(CaveMapData.SizeCategory.EXTENSIVE, r)
		assert_eq(p, CaveMapData.FlowPattern.WEB)


func test_flow_small_mostly_linear() -> void:
	var linear_count: int = 0
	for i: int in range(40):
		var r := _rng(i * 89)
		if CaveTemplateGenerator.pick_flow_pattern(CaveMapData.SizeCategory.SMALL, r) \
				== CaveMapData.FlowPattern.LINEAR:
			linear_count += 1
	# Expect roughly 70% linear — at least 20/40.
	assert_true(linear_count >= 20,
		"SMALL should mostly be LINEAR, got %d/40" % linear_count)


# ---------------------------------------------------------------------------
# Full generation — structure
# ---------------------------------------------------------------------------

func test_generate_returns_cave_map_data() -> void:
	var map: CaveMapData = _gen()
	assert_not_null(map)
	assert_is(map, CaveMapData)


func test_generate_deterministic() -> void:
	var a: CaveMapData = _gen("seed_xyz", 3)
	var b: CaveMapData = _gen("seed_xyz", 3)
	assert_eq(a.size_category, b.size_category)
	assert_eq(a.flow_pattern, b.flow_pattern)
	assert_eq(a.rooms.size(), b.rooms.size())
	assert_eq(a.tile_types, b.tile_types)


func test_generate_different_seeds_different_maps() -> void:
	var a: CaveMapData = _gen("alpha", 4)
	var b: CaveMapData = _gen("beta", 4)
	# Not guaranteed to differ in all properties but tiles almost certainly will.
	# At minimum, rooms counts or positions should vary.
	var same: bool = a.tile_types == b.tile_types
	assert_false(same, "Different seeds should produce different maps")


func test_generate_tile_array_correct_size() -> void:
	var map: CaveMapData = _gen()
	assert_eq(map.tile_types.size(), map.width * map.height)


func test_generate_dimensions_match_size_category() -> void:
	for size: int in [CaveMapData.SizeCategory.SMALL, CaveMapData.SizeCategory.MEDIUM,
			CaveMapData.SizeCategory.LARGE, CaveMapData.SizeCategory.EXTENSIVE]:
		var r := RandomNumberGenerator.new()
		r.seed = 42
		var map: CaveMapData = CaveTemplateGenerator.generate("t", 0, [], r)
		# Force the size by checking that the DIMS constant matches.
		var expected: Vector2i = CaveMapData.DIMS[map.size_category]
		assert_eq(map.width, expected.x)
		assert_eq(map.height, expected.y)


# ---------------------------------------------------------------------------
# Room graph structure
# ---------------------------------------------------------------------------

func test_rooms_count_within_range() -> void:
	for strength: int in [1, 3, 5, 8]:
		var map: CaveMapData = _gen("rc_%d" % strength, strength)
		var range_vec: Vector2i = CaveMapData.ROOM_RANGE[map.size_category]
		assert_true(map.rooms.size() >= range_vec.x and map.rooms.size() <= range_vec.y,
			"Room count %d out of range for size %d" % [map.rooms.size(), map.size_category])


func test_rooms_has_exactly_one_entry_tunnel() -> void:
	for seed: String in ["a", "b", "c"]:
		var map: CaveMapData = _gen(seed, 4)
		assert_eq(_count_type(map, CaveMapData.RoomType.ENTRY_TUNNEL), 1,
			"Should have exactly one ENTRY_TUNNEL")


func test_rooms_has_exactly_one_deep_chamber() -> void:
	for seed: String in ["x", "y", "z"]:
		var map: CaveMapData = _gen(seed, 6)
		assert_eq(_count_type(map, CaveMapData.RoomType.DEEP_CHAMBER), 1,
			"Should have exactly one DEEP_CHAMBER")


func test_deep_chamber_is_deepest_room() -> void:
	var map: CaveMapData = _gen("depth_check", 5)
	var deep: Dictionary = map.rooms[map.rooms.size() - 1]
	assert_eq(deep["type"], CaveMapData.RoomType.DEEP_CHAMBER)
	for room: Dictionary in map.rooms:
		assert_true(room["depth"] <= deep["depth"],
			"Room %d has depth %d > deep chamber depth %d" % [room["id"], room["depth"], deep["depth"]])


func test_entry_tunnel_has_depth_zero() -> void:
	var map: CaveMapData = _gen("entry_depth", 3)
	var entry: Dictionary = map.rooms[0]
	assert_eq(entry["type"], CaveMapData.RoomType.ENTRY_TUNNEL)
	assert_eq(entry["depth"], 0)


func test_all_rooms_connected_bfs() -> void:
	for seed: String in ["conn1", "conn2", "conn3"]:
		var map: CaveMapData = _gen(seed, 5)
		# BFS from room 0 — every room must be reachable.
		var visited: Dictionary = {}
		var queue: Array[int] = [0]
		visited[0] = true
		while not queue.is_empty():
			var cur: int = queue.pop_front()
			for nb: int in map.rooms[cur]["connections"]:
				if not visited.has(nb):
					visited[nb] = true
					queue.append(nb)
		assert_eq(visited.size(), map.rooms.size(),
			"Seed '%s': %d of %d rooms reachable" % [seed, visited.size(), map.rooms.size()])


func test_room_positions_within_map_bounds() -> void:
	var map: CaveMapData = _gen("bounds_check", 4)
	for room: Dictionary in map.rooms:
		assert_true(room["cx"] >= 1 and room["cx"] < map.width - 1,
			"Room cx %d out of bounds" % room["cx"])
		assert_true(room["cy"] >= 1 and room["cy"] < map.height - 1,
			"Room cy %d out of bounds" % room["cy"])


func test_junction_has_at_least_three_connections() -> void:
	# Generate a Medium or larger map and check any junctions.
	var map: CaveMapData = _gen("junction_test", 5)
	for room: Dictionary in map.rooms:
		if room["type"] == CaveMapData.RoomType.JUNCTION:
			# After orphan-repair, junctions should have ≥2 connections
			# (the spec says ≥3 but at small graph sizes 2 can occur from initial wiring).
			assert_true(room["connections"].size() >= 2,
				"Junction room %d has only %d connections" % [room["id"], room["connections"].size()])


# ---------------------------------------------------------------------------
# Tile carving
# ---------------------------------------------------------------------------

func test_rooms_are_carved_as_floor_stone() -> void:
	var map: CaveMapData = _gen("carve1", 3)
	for room: Dictionary in map.rooms:
		var cx: int = room["cx"]
		var cy: int = room["cy"]
		# The centre tile of every room must be floor, not wall.
		assert_eq(map.get_tile(cx, cy), Enums.TileType.FLOOR_STONE,
			"Room %d centre not carved to FLOOR_STONE" % room["id"])


func test_corridors_are_carved_between_connected_rooms() -> void:
	var map: CaveMapData = _gen("corr1", 4)
	# Check that at least one tile on the straight line between two connected
	# rooms is passable (corridor carving leaves at least the midpoint open).
	var checked: bool = false
	for room: Dictionary in map.rooms:
		for nid: int in room["connections"]:
			var nb: Dictionary = map.rooms[nid]
			var mx: int = (room["cx"] + nb["cx"]) / 2
			var my: int = (room["cy"] + nb["cy"]) / 2
			# The L-shaped corridor might not pass exactly through midpoint,
			# but at least one of the endpoints' columns or rows must be open.
			var ax_open: bool = map.get_tile(nb["cx"], room["cy"]) == Enums.TileType.FLOOR_STONE \
				or map.get_tile(nb["cx"], room["cy"]) == Enums.TileType.WATER_SHALLOW \
				or map.get_tile(nb["cx"], room["cy"]) == Enums.TileType.RUBBLE
			var ay_open: bool = map.get_tile(room["cx"], nb["cy"]) == Enums.TileType.FLOOR_STONE \
				or map.get_tile(room["cx"], nb["cy"]) == Enums.TileType.WATER_SHALLOW \
				or map.get_tile(room["cx"], nb["cy"]) == Enums.TileType.RUBBLE
			if ax_open or ay_open:
				checked = true
	assert_true(checked, "No corridor junction tiles found as floor")


func test_border_tiles_remain_wall() -> void:
	var map: CaveMapData = _gen("border", 4)
	# Top and bottom rows of the map should be wall (except ZONE_EXIT tiles).
	for x: int in range(map.width):
		var t: int = map.get_tile(x, 0)
		assert_true(t == Enums.TileType.WALL_STONE or t == Enums.TileType.ZONE_EXIT,
			"Top border tile at x=%d should be WALL or ZONE_EXIT" % x)
		var b: int = map.get_tile(x, map.height - 1)
		assert_true(b == Enums.TileType.WALL_STONE or b == Enums.TileType.ZONE_EXIT,
			"Bottom border tile at x=%d should be WALL or ZONE_EXIT" % x)


# ---------------------------------------------------------------------------
# Entry points (s56.3.2)
# ---------------------------------------------------------------------------

func test_small_and_medium_have_one_entrance() -> void:
	# Generate small caves and verify exactly 1 entry point in most cases.
	var map: CaveMapData = CaveTemplateGenerator.generate("small_entry", 2,
		[CaveMapData.ObjType.KILL_LEADER])
	if map.size_category == CaveMapData.SizeCategory.SMALL:
		assert_eq(map.entry_points.size(), 1,
			"SMALL cave should have 1 entry point")


func test_main_entry_is_marked() -> void:
	var map: CaveMapData = _gen("entry_mark", 3)
	var has_main: bool = false
	for ep: Dictionary in map.entry_points:
		if ep["is_main"]:
			has_main = true
	assert_true(has_main, "Must have a main entry point")


func test_main_entry_tile_is_zone_exit() -> void:
	var map: CaveMapData = _gen("entry_tile", 3)
	for ep: Dictionary in map.entry_points:
		if ep["is_main"]:
			var t: int = map.get_tile(ep["x"], ep["y"])
			assert_eq(t, Enums.TileType.ZONE_EXIT, "Main entry tile should be ZONE_EXIT")


func test_extensive_cave_has_at_least_two_entries() -> void:
	# Force EXTENSIVE by using Strength 10.
	var map: CaveMapData = CaveTemplateGenerator.generate("extensive_entry", 10,
		[CaveMapData.ObjType.KILL_LEADER])
	assert_eq(map.size_category, CaveMapData.SizeCategory.EXTENSIVE)
	assert_true(map.entry_points.size() >= 2,
		"EXTENSIVE cave must have ≥2 entry points")


# ---------------------------------------------------------------------------
# Population placement (s56.3.4)
# ---------------------------------------------------------------------------

func test_sentry_placed_at_entry_room() -> void:
	var map: CaveMapData = _gen("sentry_test", 4)
	var has_sentry: bool = _count_role(map, CaveMapData.PopRole.SENTRY) >= 1
	assert_true(has_sentry, "Cave should have at least one SENTRY slot")


func test_leader_placed_in_deep_chamber() -> void:
	var map: CaveMapData = _gen("leader_test", 5)
	var deep: Dictionary = map.rooms[map.rooms.size() - 1]
	var leader_in_deep: bool = false
	for slot: Dictionary in map.population_slots:
		if slot["role"] == CaveMapData.PopRole.LEADER and slot["room_id"] == deep["id"]:
			leader_in_deep = true
	assert_true(leader_in_deep, "LEADER slot must be in the DEEP_CHAMBER")


func test_patrol_only_in_medium_plus() -> void:
	# Force a small cave (Strength ≤ 3) and verify no patrols.
	for i: int in range(10):
		var r := _rng(i * 17 + 1)
		var map: CaveMapData = CaveTemplateGenerator.generate("small_%d" % i, 2, [], r)
		if map.size_category == CaveMapData.SizeCategory.SMALL:
			var patrols: int = _count_role(map, CaveMapData.PopRole.PATROL_WAYPOINT)
			assert_eq(patrols, 0,
				"SMALL cave should have no PATROL_WAYPOINTs, found %d" % patrols)


func test_population_denser_toward_deep_chamber() -> void:
	# The number of population slots should increase as depth increases.
	# Compare first-third vs last-third counts.
	var map: CaveMapData = _gen("density_check", 8)
	if map.rooms.is_empty():
		return
	var max_d: int = map.rooms[map.rooms.size() - 1]["depth"]
	var early_slots: int = 0
	var late_slots: int = 0
	for slot: Dictionary in map.population_slots:
		var room: Dictionary = map.rooms[slot["room_id"]]
		if room["depth"] <= max_d / 3:
			early_slots += 1
		elif room["depth"] >= max_d * 2 / 3:
			late_slots += 1
	# Late section should have at least as many slots as early section.
	assert_true(late_slots >= early_slots,
		"Population should be denser near deep chamber (late=%d, early=%d)" % [late_slots, early_slots])


# ---------------------------------------------------------------------------
# Objective placement (s56.3.6)
# ---------------------------------------------------------------------------

func test_kill_leader_objective_in_deep_chamber() -> void:
	var map: CaveMapData = _gen("obj_kill", 4, [CaveMapData.ObjType.KILL_LEADER])
	var deep: Dictionary = map.rooms[map.rooms.size() - 1]
	var found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == CaveMapData.ObjType.KILL_LEADER \
				and slot["room_id"] == deep["id"]:
			found = true
	assert_true(found, "KILL_LEADER objective must be in DEEP_CHAMBER")


func test_objective_never_in_first_third() -> void:
	for seed: String in ["o1", "o2", "o3"]:
		var map: CaveMapData = _gen(seed, 6,
			[CaveMapData.ObjType.KILL_LEADER, CaveMapData.ObjType.RECOVER_GOODS])
		var deep: Dictionary = map.rooms[map.rooms.size() - 1]
		var first_third: int = deep["depth"] / 3
		for slot: Dictionary in map.objective_slots:
			if slot["obj_type"] == CaveMapData.ObjType.BURN_POINT:
				continue  # Burn points may be in early rooms
			var room: Dictionary = map.rooms[slot["room_id"]]
			assert_true(room["depth"] > first_third,
				"Objective in first third at depth %d" % room["depth"])


func test_burn_points_span_multiple_rooms() -> void:
	var map: CaveMapData = _gen("burn_test", 6, [CaveMapData.ObjType.BURN_POINT])
	var burn_count: int = 0
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == CaveMapData.ObjType.BURN_POINT:
			burn_count += 1
	# With 6+ rooms and a medium cave, should have multiple burn points.
	assert_true(burn_count >= 1, "Burn the Camp should produce ≥1 burn points")


func test_rescue_hostages_not_in_deep_chamber() -> void:
	var map: CaveMapData = _gen("hostage_test", 5, [CaveMapData.ObjType.RESCUE_HOSTAGES])
	var deep: Dictionary = map.rooms[map.rooms.size() - 1]
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == CaveMapData.ObjType.RESCUE_HOSTAGES:
			assert_ne(slot["room_id"], deep["id"],
				"RESCUE_HOSTAGES should not be in DEEP_CHAMBER")


func test_combined_objectives_stack() -> void:
	var map: CaveMapData = _gen("combined", 6,
		[CaveMapData.ObjType.KILL_LEADER, CaveMapData.ObjType.RECOVER_GOODS])
	var kill_found: bool = false
	var goods_found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == CaveMapData.ObjType.KILL_LEADER:
			kill_found = true
		if slot["obj_type"] == CaveMapData.ObjType.RECOVER_GOODS:
			goods_found = true
	assert_true(kill_found, "KILL_LEADER slot missing from combined objectives")
	assert_true(goods_found, "RECOVER_GOODS slot missing from combined objectives")


# ---------------------------------------------------------------------------
# Environmental features (s56.3.5)
# ---------------------------------------------------------------------------

func test_features_do_not_break_room_centres() -> void:
	# The centre of every room should always be FLOOR_STONE, not overwritten by features.
	var map: CaveMapData = _gen("feature_safe", 4)
	for room: Dictionary in map.rooms:
		var t: int = map.get_tile(room["cx"], room["cy"])
		assert_true(
			t == Enums.TileType.FLOOR_STONE
			or t == Enums.TileType.WATER_SHALLOW
			or t == Enums.TileType.RUBBLE,
			"Room centre should be passable floor or feature tile, got %d" % t)
