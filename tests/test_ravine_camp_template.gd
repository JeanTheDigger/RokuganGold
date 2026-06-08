extends GutTest
## GUT tests for RavineCampGenerator and RavineCampMapData (s56.11).

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_small(seed_str: String = "test_small") -> RavineCampMapData:
	return RavineCampGenerator.generate(
		seed_str, 2, [RavineCampMapData.ObjType.KILL_LEADER])


func _make_medium(seed_str: String = "test_medium") -> RavineCampMapData:
	return RavineCampGenerator.generate(
		seed_str, 5, [RavineCampMapData.ObjType.KILL_LEADER])


func _make_large(seed_str: String = "test_large") -> RavineCampMapData:
	return RavineCampGenerator.generate(
		seed_str, 8, [RavineCampMapData.ObjType.KILL_LEADER])


func _count_role(map: RavineCampMapData, role: int) -> int:
	var n: int = 0
	for slot: Dictionary in map.population_slots:
		if slot["role"] == role:
			n += 1
	return n


# ---------------------------------------------------------------------------
# Type and basic structure
# ---------------------------------------------------------------------------

func test_generate_returns_correct_type() -> void:
	assert_true(_make_small() is RavineCampMapData,
		"generate() should return RavineCampMapData")


func test_seed_string_stored() -> void:
	var map := _make_small("my_ravine_seed")
	assert_eq(map.seed_string, "my_ravine_seed")


# ---------------------------------------------------------------------------
# Dimensions
# ---------------------------------------------------------------------------

func test_small_dimensions() -> void:
	var map := _make_small()
	assert_eq(map.width,  40, "NARROW_GULLY width should be 40")
	assert_eq(map.height, 44, "NARROW_GULLY height should be 44")


func test_medium_dimensions() -> void:
	var map := _make_medium()
	assert_eq(map.width,  60, "RAVINE width should be 60")
	assert_eq(map.height, 60, "RAVINE height should be 60")


func test_large_dimensions() -> void:
	var map := _make_large()
	assert_eq(map.width,  80, "CANYON width should be 80")
	assert_eq(map.height, 76, "CANYON height should be 76")


# ---------------------------------------------------------------------------
# Ravine geometry
# ---------------------------------------------------------------------------

func test_geometry_narrow_gully() -> void:
	var map := _make_small()
	assert_eq(map.wall_lx,  5,  "NARROW_GULLY wall_lx")
	assert_eq(map.floor_lx, 8,  "NARROW_GULLY floor_lx")
	assert_eq(map.floor_rx, 31, "NARROW_GULLY floor_rx")
	assert_eq(map.wall_rx,  34, "NARROW_GULLY wall_rx")
	assert_eq(map.floor_cx, 19, "NARROW_GULLY floor_cx")


func test_geometry_ravine() -> void:
	var map := _make_medium()
	assert_eq(map.wall_lx,  6,  "RAVINE wall_lx")
	assert_eq(map.floor_lx, 10, "RAVINE floor_lx")
	assert_eq(map.floor_rx, 49, "RAVINE floor_rx")
	assert_eq(map.wall_rx,  53, "RAVINE wall_rx")
	assert_eq(map.floor_cx, 29, "RAVINE floor_cx")


func test_geometry_canyon() -> void:
	var map := _make_large()
	assert_eq(map.wall_lx,  8,  "CANYON wall_lx")
	assert_eq(map.floor_lx, 13, "CANYON floor_lx")
	assert_eq(map.floor_rx, 66, "CANYON floor_rx")
	assert_eq(map.wall_rx,  71, "CANYON wall_rx")
	assert_eq(map.floor_cx, 39, "CANYON floor_cx")


# ---------------------------------------------------------------------------
# Tile types at zone boundaries
# ---------------------------------------------------------------------------

func test_left_rim_is_floor_grass() -> void:
	var map := _make_small()
	assert_eq(map.get_tile(0, 10), Enums.TileType.FLOOR_GRASS,
		"Left rim edge tile should be FLOOR_GRASS")


func test_left_wall_is_wall_stone() -> void:
	var map := _make_small()
	assert_eq(map.get_tile(map.wall_lx, 10), Enums.TileType.WALL_STONE,
		"Left wall tile should be WALL_STONE")


func test_ravine_floor_is_floor_dirt() -> void:
	var map := _make_small()
	# Row 5 is north of any chokepoint — should be FLOOR_DIRT.
	assert_eq(map.get_tile(map.floor_cx, 5), Enums.TileType.FLOOR_DIRT,
		"Ravine floor tile (away from chokepoints) should be FLOOR_DIRT")


func test_right_wall_is_wall_stone() -> void:
	var map := _make_small()
	assert_eq(map.get_tile(map.wall_rx, 10), Enums.TileType.WALL_STONE,
		"Right wall tile should be WALL_STONE")


func test_right_rim_is_floor_grass() -> void:
	var map := _make_small()
	assert_eq(map.get_tile(map.width - 1, 10), Enums.TileType.FLOOR_GRASS,
		"Right rim edge tile should be FLOOR_GRASS")


func test_south_edge_mouth_is_zone_exit() -> void:
	var map := _make_small()
	assert_eq(map.get_tile(map.floor_cx, map.height - 1), Enums.TileType.ZONE_EXIT,
		"South edge at floor_cx should be ZONE_EXIT (ravine mouth)")


# ---------------------------------------------------------------------------
# Chokepoints
# ---------------------------------------------------------------------------

func test_chokepoints_count_narrow_gully() -> void:
	assert_eq(_make_small().chokepoints.size(), 1,
		"NARROW_GULLY should have 1 chokepoint")


func test_chokepoints_count_ravine() -> void:
	assert_eq(_make_medium().chokepoints.size(), 2,
		"RAVINE should have 2 chokepoints")


func test_chokepoints_count_canyon() -> void:
	assert_eq(_make_large().chokepoints.size(), 3,
		"CANYON should have 3 chokepoints")


func test_chokepoint_passage_within_floor_bounds() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		for chk: Dictionary in map.chokepoints:
			assert_true(chk["passage_lx"] >= map.floor_lx,
				"Chokepoint passage_lx must be >= floor_lx")
			assert_true(chk["passage_rx"] <= map.floor_rx,
				"Chokepoint passage_rx must be <= floor_rx")


func test_chokepoint_centre_tile_is_floor_dirt_or_wall_wood() -> void:
	# Passage centre stays FLOOR_DIRT unless a barricade falls on it.
	var map := _make_small()
	var chk: Dictionary = map.chokepoints[0]
	var cx: int = (chk["passage_lx"] + chk["passage_rx"]) / 2
	var tile: int = map.get_tile(cx, chk["y"])
	assert_true(tile == Enums.TileType.FLOOR_DIRT or tile == Enums.TileType.WALL_WOOD,
		"Chokepoint passage centre should be FLOOR_DIRT or WALL_WOOD")


func test_chokepoint_barricade_gap_passable() -> void:
	# When a barricade exists the gap tile must remain FLOOR_DIRT.
	for i in range(20):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"bari_%d" % i, 5, [])
		for chk: Dictionary in map.chokepoints:
			if chk["has_barricade"]:
				var gap_x: int = chk["barricade_gap_x"]
				assert_eq(map.get_tile(gap_x, chk["y"]), Enums.TileType.FLOOR_DIRT,
					"Barricade gap tile must be FLOOR_DIRT (passable)")


# ---------------------------------------------------------------------------
# Back exit
# ---------------------------------------------------------------------------

func test_narrow_gully_never_has_back_exit() -> void:
	for i in range(20):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"be_small_%d" % i, 2, [])
		assert_false(map.has_back_exit,
			"NARROW_GULLY should never have a back exit")


func test_canyon_always_has_back_exit() -> void:
	for i in range(10):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"be_large_%d" % i, 8, [])
		assert_true(map.has_back_exit,
			"CANYON should always have a back exit")


func test_back_exit_zone_exit_on_north_edge() -> void:
	var map := _make_large()
	assert_eq(map.get_tile(map.back_exit_x, 0), Enums.TileType.ZONE_EXIT,
		"Back exit tile on north edge should be ZONE_EXIT")


func test_back_exit_x_at_floor_cx() -> void:
	var map := _make_large()
	assert_eq(map.back_exit_x, map.floor_cx,
		"back_exit_x should equal floor_cx")


# ---------------------------------------------------------------------------
# Stream
# ---------------------------------------------------------------------------

func test_canyon_always_has_stream() -> void:
	for i in range(10):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"stream_large_%d" % i, 8, [])
		assert_true(map.has_stream,
			"CANYON should always have a stream")


func test_stream_x_within_floor_bounds() -> void:
	for i in range(10):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"stream_test_%d" % i, 8, [])
		assert_true(map.has_stream)
		assert_true(map.stream_x >= map.floor_lx + 1 and map.stream_x <= map.floor_rx - 1,
			"stream_x must be strictly inside ravine floor")


func test_stream_tiles_are_water_shallow() -> void:
	var map := _make_large()
	assert_true(map.has_stream)
	assert_eq(map.get_tile(map.stream_x, 2), Enums.TileType.WATER_SHALLOW,
		"Stream column tiles should be WATER_SHALLOW")


# ---------------------------------------------------------------------------
# Descent points
# ---------------------------------------------------------------------------

func test_descent_points_count_narrow_gully() -> void:
	assert_eq(_make_small().descent_points.size(), 2,
		"NARROW_GULLY should have 2 descent points")


func test_descent_points_count_ravine() -> void:
	assert_eq(_make_medium().descent_points.size(), 2,
		"RAVINE should have 2 descent points")


func test_descent_points_count_canyon() -> void:
	assert_eq(_make_large().descent_points.size(), 3,
		"CANYON should have 3 descent points")


func test_descent_point_tiles_are_floor_stone() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		for dp: Dictionary in map.descent_points:
			assert_eq(map.get_tile(dp["x"], dp["y"]), Enums.TileType.FLOOR_STONE,
				"Descent point tile should be FLOOR_STONE")


func test_descent_points_have_side_field() -> void:
	for dp: Dictionary in _make_small().descent_points:
		assert_true(dp["side"] == "L" or dp["side"] == "R",
			"Descent point side must be 'L' or 'R'")


func test_descent_points_on_rim() -> void:
	var map := _make_small()
	for dp: Dictionary in map.descent_points:
		if dp["side"] == "L":
			assert_true(dp["x"] < map.wall_lx,
				"Left descent point must be on left rim (x < wall_lx)")
		else:
			assert_true(dp["x"] > map.wall_rx,
				"Right descent point must be on right rim (x > wall_rx)")


# ---------------------------------------------------------------------------
# Wide sections
# ---------------------------------------------------------------------------

func test_wide_sections_count_narrow_gully() -> void:
	assert_eq(_make_small().wide_sections.size(), 2,
		"NARROW_GULLY (1 chokepoint) should have 2 wide sections")


func test_wide_sections_count_ravine() -> void:
	assert_eq(_make_medium().wide_sections.size(), 3,
		"RAVINE (2 chokepoints) should have 3 wide sections")


func test_wide_sections_count_canyon() -> void:
	assert_eq(_make_large().wide_sections.size(), 4,
		"CANYON (3 chokepoints) should have 4 wide sections")


func test_exactly_one_deep_section() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		var count: int = 0
		for sec: Dictionary in map.wide_sections:
			if sec["is_deep_section"]:
				count += 1
		assert_eq(count, 1, "Exactly 1 deep section per map")


func test_exactly_one_mouth_section() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		var count: int = 0
		for sec: Dictionary in map.wide_sections:
			if sec["is_mouth_section"]:
				count += 1
		assert_eq(count, 1, "Exactly 1 mouth section per map")


# ---------------------------------------------------------------------------
# Shelters
# ---------------------------------------------------------------------------

func test_shelters_count_small_in_range() -> void:
	for i in range(20):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"sh_small_%d" % i, 2, [])
		assert_true(map.shelters.size() >= 1 and map.shelters.size() <= 2,
			"NARROW_GULLY shelter count should be 1–2, got %d" % map.shelters.size())


func test_shelters_count_medium_in_range() -> void:
	for i in range(10):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"sh_med_%d" % i, 5, [])
		assert_true(map.shelters.size() >= 3 and map.shelters.size() <= 6,
			"RAVINE shelter count should be 3–6, got %d" % map.shelters.size())


func test_shelters_count_large_in_range() -> void:
	for i in range(5):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"sh_large_%d" % i, 8, [])
		assert_true(map.shelters.size() >= 7 and map.shelters.size() <= 10,
			"CANYON shelter count should be 7–10, got %d" % map.shelters.size())


func test_exactly_one_command_shelter() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		var cmd_count: int = 0
		for sh: Dictionary in map.shelters:
			if sh["type"] == RavineCampMapData.ShelterType.COMMAND:
				cmd_count += 1
		assert_eq(cmd_count, 1, "Exactly 1 COMMAND shelter")


func test_shelters_within_floor_bounds() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		for sh: Dictionary in map.shelters:
			assert_true(sh["lx"] >= map.floor_lx + 1,
				"Shelter lx must be strictly inside ravine floor")
			assert_true(sh["rx"] <= map.floor_rx - 1,
				"Shelter rx must be strictly inside ravine floor")


# ---------------------------------------------------------------------------
# Firepits
# ---------------------------------------------------------------------------

func test_firepits_count_narrow_gully() -> void:
	assert_eq(_make_small().firepits.size(), 2,
		"NARROW_GULLY (2 wide sections) should have 2 firepits")


func test_firepits_count_ravine() -> void:
	assert_eq(_make_medium().firepits.size(), 3,
		"RAVINE (3 wide sections) should have 3 firepits")


func test_firepits_count_canyon() -> void:
	assert_eq(_make_large().firepits.size(), 5,
		"CANYON (4 wide sections + 1 extra in deep) should have 5 firepits")


func test_firepit_tiles_are_fire() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		for fp: Dictionary in map.firepits:
			assert_eq(map.get_tile(fp["x"], fp["y"]), Enums.TileType.FIRE,
				"Firepit tile should be FIRE")


# ---------------------------------------------------------------------------
# Entry vectors
# ---------------------------------------------------------------------------

func test_entry_vectors_exactly_one_mouth() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		var count: int = 0
		for ev: Dictionary in map.entry_vectors:
			if ev["is_mouth"]:
				count += 1
		assert_eq(count, 1, "Exactly 1 is_mouth entry vector")


func test_entry_vector_mouth_on_south_edge() -> void:
	var map := _make_small()
	for ev: Dictionary in map.entry_vectors:
		if ev["is_mouth"]:
			assert_eq(ev["y"], map.height - 1,
				"Mouth entry vector y should be height-1 (south edge)")
			assert_eq(ev["x"], map.floor_cx,
				"Mouth entry vector x should be floor_cx")


func test_entry_vectors_six_rim_entries() -> void:
	# 3 y-positions × 2 sides = 6 rim entry vectors.
	var map := _make_small()
	var rim_count: int = 0
	for ev: Dictionary in map.entry_vectors:
		if ev["is_rim"]:
			rim_count += 1
			assert_true(ev["x"] == 0 or ev["x"] == map.width - 1,
				"Rim entry vector must be on left (x=0) or right (x=width-1) edge")
	assert_eq(rim_count, 6, "Should have exactly 6 rim entry vectors (3 per side)")


func test_entry_vector_tiles_are_zone_exit() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		for ev: Dictionary in map.entry_vectors:
			assert_eq(map.get_tile(ev["x"], ev["y"]), Enums.TileType.ZONE_EXIT,
				"Every entry vector tile should be ZONE_EXIT")


func test_canyon_back_exit_entry_vector() -> void:
	var map := _make_large()
	var count: int = 0
	for ev: Dictionary in map.entry_vectors:
		if ev["is_back_exit"]:
			count += 1
			assert_eq(ev["y"], 0,
				"Back exit entry vector should be on north edge (y=0)")
	assert_eq(count, 1, "CANYON should have exactly 1 back exit entry vector")


func test_narrow_gully_no_back_exit_entry_vector() -> void:
	var map := _make_small()
	for ev: Dictionary in map.entry_vectors:
		assert_false(ev["is_back_exit"],
			"NARROW_GULLY should have no back exit entry vector")


# ---------------------------------------------------------------------------
# Population slots
# ---------------------------------------------------------------------------

func test_population_has_mouth_guard() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_true(_count_role(map, RavineCampMapData.PopRole.MOUTH_GUARD) >= 2,
			"At least 2 MOUTH_GUARD slots")


func test_population_has_chokepoint_holder() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_true(_count_role(map, RavineCampMapData.PopRole.CHOKEPOINT_HOLDER) >= 1,
			"At least 1 CHOKEPOINT_HOLDER per map")


func test_population_has_camp_group() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_true(_count_role(map, RavineCampMapData.PopRole.CAMP_GROUP) >= 1,
			"At least 1 CAMP_GROUP slot")


func test_population_has_leader_group() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_true(_count_role(map, RavineCampMapData.PopRole.LEADER_GROUP) >= 1,
			"At least 1 LEADER_GROUP slot")


func test_canyon_always_has_rim_watcher() -> void:
	for i in range(5):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"rim_large_%d" % i, 8, [])
		assert_true(map.has_rim_watcher,
			"CANYON should always have a rim watcher")
		assert_eq(_count_role(map, RavineCampMapData.PopRole.RIM_WATCHER), 1,
			"CANYON should have exactly 1 RIM_WATCHER slot")


func test_narrow_gully_never_has_rim_watcher() -> void:
	for i in range(10):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"rim_small_%d" % i, 2, [])
		assert_false(map.has_rim_watcher,
			"NARROW_GULLY should never have a rim watcher")
		assert_eq(_count_role(map, RavineCampMapData.PopRole.RIM_WATCHER), 0,
			"NARROW_GULLY should have no RIM_WATCHER slots")


func test_population_slots_have_zone_field() -> void:
	for map: RavineCampMapData in [_make_small(), _make_medium(), _make_large()]:
		for slot: Dictionary in map.population_slots:
			assert_true(slot.has("zone"),
				"All population slots must have a 'zone' field")


func test_rim_watcher_zone_is_rim() -> void:
	var map := _make_large()
	for slot: Dictionary in map.population_slots:
		if slot["role"] == RavineCampMapData.PopRole.RIM_WATCHER:
			assert_eq(slot["zone"], RavineCampMapData.Zone.RIM,
				"RIM_WATCHER must have zone = RIM")


func test_non_rim_watcher_slots_are_ravine_floor_zone() -> void:
	var map := _make_large()
	for slot: Dictionary in map.population_slots:
		if slot["role"] != RavineCampMapData.PopRole.RIM_WATCHER:
			assert_eq(slot["zone"], RavineCampMapData.Zone.RAVINE_FLOOR,
				"Non-RIM_WATCHER slots must have zone = RAVINE_FLOOR")


# ---------------------------------------------------------------------------
# Objectives
# ---------------------------------------------------------------------------

func test_kill_leader_objective_present() -> void:
	var map := _make_small()
	var found: bool = false
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RavineCampMapData.ObjType.KILL_LEADER:
			found = true
	assert_true(found, "KILL_LEADER objective should be present")


func test_recover_goods_objective_present() -> void:
	var map: RavineCampMapData = RavineCampGenerator.generate(
		"goods_ravine", 5, [RavineCampMapData.ObjType.RECOVER_GOODS])
	var found: bool = false
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RavineCampMapData.ObjType.RECOVER_GOODS:
			found = true
	assert_true(found, "RECOVER_GOODS objective should be placed")


func test_burn_camp_one_marker_per_shelter() -> void:
	var map: RavineCampMapData = RavineCampGenerator.generate(
		"burn_ravine", 5, [RavineCampMapData.ObjType.BURN_CAMP])
	var burn_count: int = 0
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RavineCampMapData.ObjType.BURN_CAMP:
			burn_count += 1
	assert_eq(burn_count, map.shelters.size(),
		"BURN_CAMP should have one marker per shelter")


func test_rescue_hostages_objective_present() -> void:
	var map: RavineCampMapData = RavineCampGenerator.generate(
		"rescue_ravine", 5, [RavineCampMapData.ObjType.RESCUE_HOSTAGES])
	var found: bool = false
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RavineCampMapData.ObjType.RESCUE_HOSTAGES:
			found = true
	assert_true(found, "RESCUE_HOSTAGES objective should be placed")


# ---------------------------------------------------------------------------
# Size selection
# ---------------------------------------------------------------------------

func test_strength_floor_forces_ravine() -> void:
	# Strength 4 exceeds NARROW_GULLY max (3); must be RAVINE or larger.
	for i in range(10):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"floor_test_%d" % i, 4, [])
		assert_true(map.size_category >= RavineCampMapData.SizeCategory.RAVINE,
			"Strength 4 should never produce NARROW_GULLY")


func test_strength_7_always_canyon() -> void:
	for i in range(5):
		var map: RavineCampMapData = RavineCampGenerator.generate(
			"canyon_test_%d" % i, 7, [])
		assert_eq(map.size_category, RavineCampMapData.SizeCategory.CANYON,
			"Strength 7 should always produce CANYON")


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

func test_same_seed_same_map() -> void:
	var a := _make_medium("det_ravine_seed")
	var b := _make_medium("det_ravine_seed")
	assert_eq(a.floor_cx,            b.floor_cx,            "floor_cx must be deterministic")
	assert_eq(a.has_back_exit,       b.has_back_exit,       "has_back_exit must be deterministic")
	assert_eq(a.has_stream,          b.has_stream,           "has_stream must be deterministic")
	assert_eq(a.has_rim_watcher,     b.has_rim_watcher,     "has_rim_watcher must be deterministic")
	assert_eq(a.shelters.size(),     b.shelters.size(),     "shelter count must be deterministic")
	assert_eq(a.chokepoints.size(),  b.chokepoints.size(),  "chokepoint count must be deterministic")
	assert_eq(a.get_tile(a.floor_cx, 10),
	          b.get_tile(b.floor_cx, 10),
	          "Floor centre tile must be deterministic")


func test_different_seeds_different_maps() -> void:
	var a := _make_medium("seed_ravine_alpha")
	var b := _make_medium("seed_ravine_beta")
	# At least one structural detail should differ between two distinct seeds.
	var back_differ:   bool = a.has_back_exit != b.has_back_exit
	var stream_differ: bool = a.has_stream    != b.has_stream
	var rim_differ:    bool = a.has_rim_watcher != b.has_rim_watcher
	var fp_differ:     bool = a.firepits[0]["x"] != b.firepits[0]["x"]
	assert_true(back_differ or stream_differ or rim_differ or fp_differ,
		"Different seeds should produce different layouts")
