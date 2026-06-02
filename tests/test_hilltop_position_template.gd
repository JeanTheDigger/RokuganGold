extends GutTest
## Integration tests: HilltopPositionGenerator + HilltopPositionMapData
## (s56.8 — LOCKED).
##
## Verifies determinism, two-zone layout, slope zone properties, hilltop zone
## properties, crest line, entry vectors, population roles, objectives, and
## FovSystem polymorphism.


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_low_rise(seed_str: String = "test_low_rise") -> HilltopPositionMapData:
	return HilltopPositionGenerator.generate(
		seed_str, 2,
		[HilltopPositionMapData.ObjType.KILL_LEADER])


func _make_steep_hill(seed_str: String = "test_steep_hill") -> HilltopPositionMapData:
	return HilltopPositionGenerator.generate(
		seed_str, 5,
		[HilltopPositionMapData.ObjType.KILL_LEADER])


func _make_ridge_bluff(seed_str: String = "test_ridge") -> HilltopPositionMapData:
	return HilltopPositionGenerator.generate(
		seed_str, 8,
		[HilltopPositionMapData.ObjType.KILL_LEADER])


func _make_with_objectives(
		objectives: Array,
		seed_str: String = "obj_test",
		strength: int = 8) -> HilltopPositionMapData:
	return HilltopPositionGenerator.generate(seed_str, strength, objectives)


func _command_shelter(map: HilltopPositionMapData) -> Dictionary:
	for s: Dictionary in map.shelters:
		if s["type"] == HilltopPositionMapData.ShelterType.COMMAND:
			return s
	return {}


func _has_tree_tile(map: HilltopPositionMapData, y_min: int, y_max: int) -> bool:
	for y: int in range(y_min, y_max):
		for x: int in range(0, map.width):
			var t: int = map.get_tile(x, y)
			if t == Enums.TileType.TREE_EVERGREEN or \
					t == Enums.TileType.TREE_DECIDUOUS or \
					t == Enums.TileType.TREE_DEAD:
				return true
	return false


func _has_wall_stone_in_slope(map: HilltopPositionMapData) -> bool:
	# Check slope zone (excluding path column and bottom margin) for WALL_STONE.
	for y: int in range(map.crest_y + 1, map.height - 3):
		for x: int in range(2, map.width - 2):
			if absi(x - map.path_x) <= 1:
				continue
			if map.get_tile(x, y) == Enums.TileType.WALL_STONE:
				return true
	return false


# ---------------------------------------------------------------------------
# Type and inheritance
# ---------------------------------------------------------------------------

func test_is_ascii_map_data_instance() -> void:
	var map: HilltopPositionMapData = _make_steep_hill()
	assert_is(map, AsciiMapData,
		"HilltopPositionMapData must extend AsciiMapData for FovSystem polymorphism")


func test_fov_system_accepts_hilltop_map() -> void:
	var map: HilltopPositionMapData = _make_steep_hill()
	var cmd: Dictionary = _command_shelter(map)
	var cx: int = (cmd["lx"] + cmd["rx"]) / 2
	var cy: int = (cmd["ly"] + cmd["ry"]) / 2
	var visible: Dictionary = FovSystem.compute_visible(cx, cy, 4, map)
	assert_true(visible.has(Vector2i(cx, cy)),
		"Viewer tile must be in visible set on HilltopPositionMapData")


# ---------------------------------------------------------------------------
# Size category and dimensions (s56.8.1)
# ---------------------------------------------------------------------------

func test_strength_2_may_produce_low_rise() -> void:
	var found_low_rise: bool = false
	for i: int in range(20):
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			"lr%d" % i, 2,
			[HilltopPositionMapData.ObjType.KILL_LEADER])
		if map.size_category == HilltopPositionMapData.SizeCategory.LOW_RISE:
			found_low_rise = true
			break
	assert_true(found_low_rise,
		"At least one seed with strength 2 should produce LOW_RISE (70% probability)")


func test_strength_7_forces_ridge_bluff() -> void:
	for i: int in range(8):
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			"rb%d" % i, 7,
			[HilltopPositionMapData.ObjType.KILL_LEADER])
		assert_eq(map.size_category, HilltopPositionMapData.SizeCategory.RIDGE_BLUFF,
			"Strength 7 must produce RIDGE_BLUFF (seed rb%d)" % i)


func test_low_rise_dimensions() -> void:
	for i: int in range(10):
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			"dim_lr%d" % i, 2,
			[HilltopPositionMapData.ObjType.KILL_LEADER])
		if map.size_category == HilltopPositionMapData.SizeCategory.LOW_RISE:
			assert_eq(map.width, 40, "LOW_RISE width must be 40")
			assert_eq(map.height, 44, "LOW_RISE height must be 44")
			return


func test_steep_hill_dimensions() -> void:
	var map: HilltopPositionMapData = _make_steep_hill()
	assert_eq(map.width, 60, "STEEP_HILL width must be 60")
	assert_eq(map.height, 60, "STEEP_HILL height must be 60")


func test_ridge_bluff_dimensions() -> void:
	var map: HilltopPositionMapData = _make_ridge_bluff()
	assert_eq(map.width, 80, "RIDGE_BLUFF width must be 80")
	assert_eq(map.height, 76, "RIDGE_BLUFF height must be 76")


# ---------------------------------------------------------------------------
# Zone boundary (s56.8.2)
# ---------------------------------------------------------------------------

func test_crest_y_is_thirty_percent_of_height() -> void:
	var map: HilltopPositionMapData = _make_ridge_bluff()
	var expected: int = int(map.height * 0.30)
	assert_eq(map.crest_y, expected,
		"crest_y must be int(height * 0.30) (got %d, expected %d)" % [
			map.crest_y, expected])


func test_crest_y_is_within_map_bounds() -> void:
	for map: HilltopPositionMapData in [_make_low_rise(), _make_steep_hill(), _make_ridge_bluff()]:
		assert_true(map.crest_y > 0 and map.crest_y < map.height - 1,
			"crest_y must be strictly inside map height bounds")


func test_path_x_is_exactly_width_over_two() -> void:
	var map: HilltopPositionMapData = _make_steep_hill()
	assert_eq(map.path_x, map.width / 2,
		"path_x must be exactly width/2 (got %d, expected %d)" % [
			map.path_x, map.width / 2])


# ---------------------------------------------------------------------------
# Slope zone (s56.8.4): rocks exist, path is FLOOR_DIRT
# ---------------------------------------------------------------------------

func test_slope_contains_wall_stone_outcrops() -> void:
	# 30% density per eligible tile on RIDGE_BLUFF guarantees rocks.
	var map: HilltopPositionMapData = _make_ridge_bluff()
	assert_true(_has_wall_stone_in_slope(map),
		"Slope zone must contain WALL_STONE outcrops (30% density, RIDGE_BLUFF map)")


func test_path_column_is_floor_dirt_in_slope() -> void:
	var map: HilltopPositionMapData = _make_steep_hill()
	var slope_depth: int = map.height - map.crest_y
	var sample_y: int = map.crest_y + slope_depth / 3
	assert_eq(map.get_tile(map.path_x, sample_y), Enums.TileType.FLOOR_DIRT,
		"Worn path must be FLOOR_DIRT in slope zone (y=%d)" % sample_y)


func test_hilltop_zone_has_no_trees() -> void:
	# s56.8.4: "No Trees — hilltops are exposed by nature."
	var map: HilltopPositionMapData = _make_ridge_bluff()
	assert_false(_has_tree_tile(map, 0, map.crest_y),
		"Hilltop zone (y < crest_y) must not contain any tree tiles")


# ---------------------------------------------------------------------------
# Crest line (s56.8.4)
# ---------------------------------------------------------------------------

func test_crest_path_tile_is_floor_dirt() -> void:
	# Path crosses the crest — must remain passable.
	var map: HilltopPositionMapData = _make_steep_hill()
	assert_eq(map.get_tile(map.path_x, map.crest_y), Enums.TileType.FLOOR_DIRT,
		"Path tile at crest_y must be FLOOR_DIRT (path continues through crest)")


func test_crest_line_contains_wall_stone() -> void:
	# 50% density at crest row on a RIDGE_BLUFF (width 80) guarantees rocks.
	var map: HilltopPositionMapData = _make_ridge_bluff()
	var found: bool = false
	for x: int in range(2, map.width - 2):
		if absi(x - map.path_x) <= 1:
			continue
		if map.get_tile(x, map.crest_y) == Enums.TileType.WALL_STONE:
			found = true
			break
	assert_true(found,
		"Crest line must contain WALL_STONE rocks (50% density on crest_y row)")


# ---------------------------------------------------------------------------
# Shelter count and types (s56.8.1)
# ---------------------------------------------------------------------------

func test_low_rise_shelter_count_in_range() -> void:
	for seed: String in ["sh_lr1", "sh_lr2", "sh_lr3", "sh_lr4", "sh_lr5",
			"sh_lr6", "sh_lr7", "sh_lr8", "sh_lr9", "sh_lr10"]:
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			seed, 2, [HilltopPositionMapData.ObjType.KILL_LEADER])
		if map.size_category == HilltopPositionMapData.SizeCategory.LOW_RISE:
			assert_true(map.shelters.size() >= 1 and map.shelters.size() <= 2,
				"LOW_RISE shelter count must be 1-2 (got %d, seed %s)" % [
					map.shelters.size(), seed])


func test_steep_hill_shelter_count_in_range() -> void:
	for seed: String in ["sh_sh1", "sh_sh2", "sh_sh3"]:
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			seed, 5, [HilltopPositionMapData.ObjType.KILL_LEADER])
		assert_true(map.shelters.size() >= 3 and map.shelters.size() <= 6,
			"STEEP_HILL shelter count must be 3-6 (got %d, seed %s)" % [
				map.shelters.size(), seed])


func test_ridge_bluff_shelter_count_in_range() -> void:
	for seed: String in ["sh_rb1", "sh_rb2", "sh_rb3"]:
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			seed, 8, [HilltopPositionMapData.ObjType.KILL_LEADER])
		assert_true(map.shelters.size() >= 7 and map.shelters.size() <= 10,
			"RIDGE_BLUFF shelter count must be 7-10 (got %d, seed %s)" % [
				map.shelters.size(), seed])


func test_exactly_one_command_shelter() -> void:
	for seed: String in ["cmd1", "cmd2", "cmd3"]:
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			seed, 5, [HilltopPositionMapData.ObjType.KILL_LEADER])
		var count: int = 0
		for s: Dictionary in map.shelters:
			if s["type"] == HilltopPositionMapData.ShelterType.COMMAND:
				count += 1
		assert_eq(count, 1,
			"Exactly one COMMAND shelter required (seed %s)" % seed)


func test_shelters_within_map_bounds() -> void:
	var map: HilltopPositionMapData = _make_ridge_bluff()
	for s: Dictionary in map.shelters:
		assert_true(s["lx"] >= 0 and s["rx"] < map.width,
			"Shelter id=%d x bounds out of map" % s["id"])
		assert_true(s["ly"] >= 0 and s["ry"] < map.height,
			"Shelter id=%d y bounds out of map" % s["id"])


func test_shelters_in_hilltop_zone() -> void:
	# All shelters must be above crest_y (in the hilltop zone).
	var map: HilltopPositionMapData = _make_ridge_bluff()
	for s: Dictionary in map.shelters:
		assert_true(s["ly"] < map.crest_y,
			"Shelter id=%d ly=%d must be above crest_y=%d (hilltop zone)" % [
				s["id"], s["ly"], map.crest_y])


func test_shelter_footprint_is_floor_dirt() -> void:
	# s56.8.4: "Shelters have FLOOR_DIRT footprints — no wall tiles (soft cover)."
	var map: HilltopPositionMapData = _make_steep_hill()
	for s: Dictionary in map.shelters:
		var cx: int = (s["lx"] + s["rx"]) / 2
		var cy: int = (s["ly"] + s["ry"]) / 2
		assert_eq(map.get_tile(cx, cy), Enums.TileType.FLOOR_DIRT,
			"Shelter %d centre must be FLOOR_DIRT (no walls, s56.8.4)" % s["id"])


# ---------------------------------------------------------------------------
# Entry vectors (s56.8.2)
# ---------------------------------------------------------------------------

func test_exactly_four_entry_vectors() -> void:
	for seed: String in ["ev1", "ev2", "ev3"]:
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			seed, 5, [HilltopPositionMapData.ObjType.KILL_LEADER])
		assert_eq(map.entry_vectors.size(), 4,
			"Must have exactly 4 entry vectors (seed %s)" % seed)


func test_entry_vector_tiles_are_zone_exit() -> void:
	var map: HilltopPositionMapData = _make_steep_hill()
	for ev: Dictionary in map.entry_vectors:
		assert_eq(map.get_tile(ev["x"], ev["y"]), Enums.TileType.ZONE_EXIT,
			"Entry vector at (%d,%d) must be ZONE_EXIT" % [ev["x"], ev["y"]])


func test_one_path_entry_vector() -> void:
	# s56.8.2: exactly one entry is the worn path (south face approach).
	var map: HilltopPositionMapData = _make_steep_hill()
	var path_count: int = 0
	for ev: Dictionary in map.entry_vectors:
		if ev["is_path"]:
			path_count += 1
	assert_eq(path_count, 1,
		"Exactly 1 entry vector must be the worn path (is_path=true)")


# ---------------------------------------------------------------------------
# Population placement (s56.8.3)
# ---------------------------------------------------------------------------

func test_at_least_one_lookout_in_slope_zone() -> void:
	# s56.8.3: "One or two posted partway up the slope."
	for seed: String in ["pop1", "pop2", "pop3"]:
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			seed, 3, [HilltopPositionMapData.ObjType.KILL_LEADER])
		var count: int = 0
		for slot: Dictionary in map.population_slots:
			if slot["role"] == HilltopPositionMapData.PopRole.LOOKOUT and \
					slot["zone"] == HilltopPositionMapData.Zone.SLOPE:
				count += 1
		assert_true(count >= 1,
			"At least one LOOKOUT in SLOPE zone required (seed %s)" % seed)


func test_at_least_one_path_guard_in_slope_zone() -> void:
	# s56.8.3: "One or two on the worn path, closer to the top."
	for seed: String in ["pg1", "pg2", "pg3"]:
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			seed, 3, [HilltopPositionMapData.ObjType.KILL_LEADER])
		var count: int = 0
		for slot: Dictionary in map.population_slots:
			if slot["role"] == HilltopPositionMapData.PopRole.PATH_GUARD and \
					slot["zone"] == HilltopPositionMapData.Zone.SLOPE:
				count += 1
		assert_true(count >= 1,
			"At least one PATH_GUARD in SLOPE zone required (seed %s)" % seed)


func test_exactly_one_leader_group() -> void:
	for seed: String in ["ldr1", "ldr2", "ldr3"]:
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			seed, 5, [HilltopPositionMapData.ObjType.KILL_LEADER])
		var count: int = 0
		for slot: Dictionary in map.population_slots:
			if slot["role"] == HilltopPositionMapData.PopRole.LEADER_GROUP:
				count += 1
		assert_eq(count, 1,
			"Exactly one LEADER_GROUP slot required (seed %s)" % seed)


func test_leader_group_in_hilltop_zone() -> void:
	# s56.8.3: "Center of the hilltop camp."
	var map: HilltopPositionMapData = _make_steep_hill()
	for slot: Dictionary in map.population_slots:
		if slot["role"] == HilltopPositionMapData.PopRole.LEADER_GROUP:
			assert_eq(slot["zone"], HilltopPositionMapData.Zone.HILLTOP,
				"LEADER_GROUP must be in HILLTOP zone")
			assert_true(slot["y"] < map.crest_y,
				"LEADER_GROUP y must be above crest (y=%d, crest_y=%d)" % [
					slot["y"], map.crest_y])


func test_at_least_two_edge_defenders_in_hilltop() -> void:
	# s56.8.3: "Two or three fighters near the hilltop edge."
	for seed: String in ["ed1", "ed2", "ed3"]:
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			seed, 5, [HilltopPositionMapData.ObjType.KILL_LEADER])
		var count: int = 0
		for slot: Dictionary in map.population_slots:
			if slot["role"] == HilltopPositionMapData.PopRole.EDGE_DEFENDER and \
					slot["zone"] == HilltopPositionMapData.Zone.HILLTOP:
				count += 1
		assert_true(count >= 2,
			"At least 2 EDGE_DEFENDER in HILLTOP zone required (seed %s)" % seed)


func test_edge_defenders_near_crest_line() -> void:
	# Generator places edge defenders at edge_y = crest_y - 2 (hilltop side of crest).
	var map: HilltopPositionMapData = _make_steep_hill()
	var expected_edge_y: int = map.crest_y - 2
	for slot: Dictionary in map.population_slots:
		if slot["role"] == HilltopPositionMapData.PopRole.EDGE_DEFENDER:
			assert_eq(slot["y"], expected_edge_y,
				"EDGE_DEFENDER must be at crest_y - 2 (y=%d, expected=%d)" % [
					slot["y"], expected_edge_y])


# ---------------------------------------------------------------------------
# Objectives (s56.8.5)
# ---------------------------------------------------------------------------

func test_kill_leader_objective_in_command_shelter() -> void:
	var map: HilltopPositionMapData = _make_with_objectives(
		[HilltopPositionMapData.ObjType.KILL_LEADER])
	var cmd: Dictionary = _command_shelter(map)
	var found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == HilltopPositionMapData.ObjType.KILL_LEADER:
			assert_eq(slot["shelter_id"], cmd["id"],
				"KILL_LEADER objective must point to command shelter")
			found = true
	assert_true(found, "KILL_LEADER objective slot must exist")


func test_burn_camp_creates_one_marker_per_shelter() -> void:
	# s56.8.5: "One marker per shelter."
	var map: HilltopPositionMapData = _make_with_objectives(
		[HilltopPositionMapData.ObjType.BURN_CAMP])
	var burn_count: int = 0
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == HilltopPositionMapData.ObjType.BURN_CAMP:
			burn_count += 1
	assert_eq(burn_count, map.shelters.size(),
		"BURN_CAMP must have one objective marker per shelter")


func test_recover_goods_objective_created() -> void:
	var map: HilltopPositionMapData = _make_with_objectives(
		[HilltopPositionMapData.ObjType.RECOVER_GOODS])
	var found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == HilltopPositionMapData.ObjType.RECOVER_GOODS:
			found = true
	assert_true(found, "RECOVER_GOODS objective slot must exist")


func test_rescue_hostages_objective_in_hilltop_zone() -> void:
	# s56.8.5: hostages held on the hilltop.
	var map: HilltopPositionMapData = _make_with_objectives(
		[HilltopPositionMapData.ObjType.RESCUE_HOSTAGES])
	var found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == HilltopPositionMapData.ObjType.RESCUE_HOSTAGES:
			assert_true(slot["y"] < map.crest_y,
				"RESCUE_HOSTAGES must be in hilltop zone (y=%d, crest_y=%d)" % [
					slot["y"], map.crest_y])
			found = true
	assert_true(found, "RESCUE_HOSTAGES objective slot must exist")


# ---------------------------------------------------------------------------
# Face grades (s56.8.4)
# ---------------------------------------------------------------------------

func test_face_grades_has_four_entries() -> void:
	for seed: String in ["fg1", "fg2", "fg3"]:
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			seed, 5, [HilltopPositionMapData.ObjType.KILL_LEADER])
		assert_eq(map.face_grades.size(), 4,
			"face_grades must have exactly 4 entries (S/N/W/E faces, seed %s)" % seed)


func test_south_face_is_never_steep() -> void:
	# s56.8.4: S face (main approach) is gentle or moderate — not steep.
	for seed: String in ["sf1", "sf2", "sf3", "sf4", "sf5",
			"sf6", "sf7", "sf8", "sf9", "sf10"]:
		var map: HilltopPositionMapData = HilltopPositionGenerator.generate(
			seed, 5, [HilltopPositionMapData.ObjType.KILL_LEADER])
		for fg: Dictionary in map.face_grades:
			if fg["face"] == "S":
				assert_true(fg["grade"] <= HilltopPositionMapData.SlopeGrade.MODERATE,
					"South face must be GENTLE or MODERATE, not STEEP (seed %s)" % seed)


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

func test_same_seed_produces_identical_map() -> void:
	var map_a: HilltopPositionMapData = HilltopPositionGenerator.generate(
		"determinism_hilltop", 6,
		[HilltopPositionMapData.ObjType.KILL_LEADER,
		 HilltopPositionMapData.ObjType.BURN_CAMP])
	var map_b: HilltopPositionMapData = HilltopPositionGenerator.generate(
		"determinism_hilltop", 6,
		[HilltopPositionMapData.ObjType.KILL_LEADER,
		 HilltopPositionMapData.ObjType.BURN_CAMP])

	assert_eq(map_a.size_category, map_b.size_category,
		"size_category must match for same seed")
	assert_eq(map_a.shelters.size(), map_b.shelters.size(),
		"shelter count must match for same seed")
	assert_eq(map_a.crest_y, map_b.crest_y,
		"crest_y must match for same seed")
	assert_eq(map_a.path_x, map_b.path_x,
		"path_x must match for same seed")

	# Spot-check tiles in hilltop and slope zones.
	var hilltop_sample_y: int = map_a.crest_y / 2
	var slope_sample_y: int = map_a.crest_y + (map_a.height - map_a.crest_y) / 2
	for x: int in [5, map_a.width / 2, map_a.width - 5]:
		assert_eq(map_a.get_tile(x, hilltop_sample_y), map_b.get_tile(x, hilltop_sample_y),
			"Hilltop tile at x=%d must match for same seed" % x)
		assert_eq(map_a.get_tile(x, slope_sample_y), map_b.get_tile(x, slope_sample_y),
			"Slope tile at x=%d must match for same seed" % x)
