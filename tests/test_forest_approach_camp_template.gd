extends GutTest
## Integration tests: ForestApproachCampGenerator + ForestApproachCampMapData
## (s56.5 — LOCKED).
##
## Verifies determinism, two-zone layout, forest zone properties, camp zone
## properties, entry vectors, population roles, objectives, and FovSystem
## polymorphism.


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_small(seed_str: String = "test_small") -> ForestApproachCampMapData:
	return ForestApproachCampGenerator.generate(
		seed_str, 2,
		[ForestApproachCampMapData.ObjType.KILL_LEADER])


func _make_medium(seed_str: String = "test_medium") -> ForestApproachCampMapData:
	return ForestApproachCampGenerator.generate(
		seed_str, 5,
		[ForestApproachCampMapData.ObjType.KILL_LEADER])


func _make_large(seed_str: String = "test_large") -> ForestApproachCampMapData:
	return ForestApproachCampGenerator.generate(
		seed_str, 8,
		[ForestApproachCampMapData.ObjType.KILL_LEADER])


func _make_with_objectives(
		objectives: Array,
		seed_str: String = "obj_test",
		strength: int = 8) -> ForestApproachCampMapData:
	return ForestApproachCampGenerator.generate(seed_str, strength, objectives)


func _command_shelter(map: ForestApproachCampMapData) -> Dictionary:
	for s: Dictionary in map.shelters:
		if s["type"] == ForestApproachCampMapData.ShelterType.COMMAND:
			return s
	return {}


func _has_tree_tile(map: ForestApproachCampMapData, y_min: int, y_max: int) -> bool:
	for y: int in range(y_min, y_max):
		for x: int in range(0, map.width):
			var t: int = map.get_tile(x, y)
			if t == Enums.TileType.TREE_EVERGREEN or \
					t == Enums.TileType.TREE_DECIDUOUS or \
					t == Enums.TileType.TREE_DEAD:
				return true
	return false


# ---------------------------------------------------------------------------
# Type and inheritance
# ---------------------------------------------------------------------------

func test_is_ascii_map_data_instance() -> void:
	var map: ForestApproachCampMapData = _make_medium()
	assert_true(map is AsciiMapData,
		"ForestApproachCampMapData must extend AsciiMapData for FovSystem polymorphism")


func test_fov_system_accepts_forest_camp_map() -> void:
	var map: ForestApproachCampMapData = _make_medium()
	# Use the command shelter centre (guaranteed FLOOR_DIRT, passable).
	var cmd: Dictionary = _command_shelter(map)
	var cx: int = (cmd["lx"] + cmd["rx"]) / 2
	var cy: int = (cmd["ly"] + cmd["ry"]) / 2
	var visible: Dictionary = FovSystem.compute_visible(cx, cy, 4, map)
	assert_true(visible.has(Vector2i(cx, cy)),
		"Viewer tile must be in visible set on ForestApproachCampMapData")


# ---------------------------------------------------------------------------
# Size category and dimensions (s56.5.1)
# ---------------------------------------------------------------------------

func test_strength_1_may_produce_small() -> void:
	var found_small: bool = false
	for i: int in range(20):
		var map: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
			"ss%d" % i, 2,
			[ForestApproachCampMapData.ObjType.KILL_LEADER])
		if map.size_category == ForestApproachCampMapData.SizeCategory.SMALL:
			found_small = true
			break
	assert_true(found_small,
		"At least one seed with strength 2 should produce a SMALL camp")


func test_strength_7_forces_large() -> void:
	for i: int in range(8):
		var map: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
			"lg%d" % i, 7,
			[ForestApproachCampMapData.ObjType.KILL_LEADER])
		assert_eq(map.size_category, ForestApproachCampMapData.SizeCategory.LARGE,
			"Strength 7 must produce LARGE (seed lg%d)" % i)


func test_small_dimensions() -> void:
	for i: int in range(10):
		var map: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
			"dim_s%d" % i, 2,
			[ForestApproachCampMapData.ObjType.KILL_LEADER])
		if map.size_category == ForestApproachCampMapData.SizeCategory.SMALL:
			assert_eq(map.width, 40, "SMALL width must be 40")
			assert_eq(map.height, 44, "SMALL height must be 44")
			return


func test_medium_dimensions() -> void:
	var map: ForestApproachCampMapData = _make_medium()
	assert_eq(map.width, 60, "MEDIUM width must be 60")
	assert_eq(map.height, 60, "MEDIUM height must be 60")


func test_large_dimensions() -> void:
	var map: ForestApproachCampMapData = _make_large()
	assert_eq(map.width, 80, "LARGE width must be 80")
	assert_eq(map.height, 76, "LARGE height must be 76")


# ---------------------------------------------------------------------------
# Zone boundary
# ---------------------------------------------------------------------------

func test_clearing_start_y_is_in_forest_zone() -> void:
	var map: ForestApproachCampMapData = _make_large()
	assert_true(map.clearing_start_y > 0 and map.clearing_start_y < map.height,
		"clearing_start_y must be within map height")
	assert_true(map.clearing_start_y > map.height / 3,
		"Forest zone must occupy at least a third of the map height")


func test_trail_x_is_near_center() -> void:
	var map: ForestApproachCampMapData = _make_medium()
	var center: int = map.width / 2
	assert_true(absi(map.trail_x - center) <= 2,
		"trail_x must be near map center (x=%d, center=%d)" % [map.trail_x, center])


# ---------------------------------------------------------------------------
# Forest zone: trees exist, trail is FLOOR_DIRT
# ---------------------------------------------------------------------------

func test_forest_zone_contains_trees() -> void:
	var map: ForestApproachCampMapData = _make_large()
	assert_true(_has_tree_tile(map, 4, map.clearing_start_y - 4),
		"Dense forest zone must contain tree tiles")


func test_trail_is_floor_dirt_in_forest() -> void:
	var map: ForestApproachCampMapData = _make_medium()
	# Sample trail at 1/4 depth into the forest.
	var sample_y: int = map.clearing_start_y / 4
	assert_eq(map.get_tile(map.trail_x, sample_y), Enums.TileType.FLOOR_DIRT,
		"Trail must be FLOOR_DIRT within forest zone (y=%d)" % sample_y)


func test_camp_zone_has_no_trees() -> void:
	var map: ForestApproachCampMapData = _make_large()
	assert_false(_has_tree_tile(map, map.clearing_start_y, map.height),
		"Camp clearing zone must not contain tree tiles")


# ---------------------------------------------------------------------------
# Shelter count and types (s56.5.1)
# ---------------------------------------------------------------------------

func test_small_shelter_count_in_range() -> void:
	for seed: String in ["sh_s1", "sh_s2", "sh_s3", "sh_s4", "sh_s5",
			"sh_s6", "sh_s7", "sh_s8", "sh_s9", "sh_s10"]:
		var map: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
			seed, 2, [ForestApproachCampMapData.ObjType.KILL_LEADER])
		if map.size_category == ForestApproachCampMapData.SizeCategory.SMALL:
			assert_true(map.shelters.size() >= 1 and map.shelters.size() <= 2,
				"SMALL shelter count must be 1-2 (got %d, seed %s)" % [
					map.shelters.size(), seed])


func test_medium_shelter_count_in_range() -> void:
	for seed: String in ["sh_m1", "sh_m2", "sh_m3"]:
		var map: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
			seed, 5, [ForestApproachCampMapData.ObjType.KILL_LEADER])
		assert_true(map.shelters.size() >= 3 and map.shelters.size() <= 6,
			"MEDIUM shelter count must be 3-6 (got %d, seed %s)" % [
				map.shelters.size(), seed])


func test_large_shelter_count_in_range() -> void:
	for seed: String in ["sh_l1", "sh_l2", "sh_l3"]:
		var map: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
			seed, 8, [ForestApproachCampMapData.ObjType.KILL_LEADER])
		assert_true(map.shelters.size() >= 7 and map.shelters.size() <= 10,
			"LARGE shelter count must be 7-10 (got %d, seed %s)" % [
				map.shelters.size(), seed])


func test_exactly_one_command_shelter() -> void:
	for seed: String in ["cmd1", "cmd2", "cmd3"]:
		var map: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
			seed, 6, [ForestApproachCampMapData.ObjType.KILL_LEADER])
		var count: int = 0
		for s: Dictionary in map.shelters:
			if s["type"] == ForestApproachCampMapData.ShelterType.COMMAND:
				count += 1
		assert_eq(count, 1,
			"Exactly one COMMAND shelter required (seed %s)" % seed)


func test_shelters_within_map_bounds() -> void:
	var map: ForestApproachCampMapData = _make_large()
	for s: Dictionary in map.shelters:
		assert_true(s["lx"] >= 0 and s["rx"] < map.width,
			"Shelter id=%d x bounds out of map" % s["id"])
		assert_true(s["ly"] >= 0 and s["ry"] < map.height,
			"Shelter id=%d y bounds out of map" % s["id"])


func test_shelters_in_camp_zone() -> void:
	var map: ForestApproachCampMapData = _make_large()
	for s: Dictionary in map.shelters:
		assert_true(s["ly"] >= map.clearing_start_y,
			"Shelter id=%d ly=%d must be at or below clearing_start_y=%d" % [
				s["id"], s["ly"], map.clearing_start_y])


func test_shelter_footprint_is_floor_dirt() -> void:
	var map: ForestApproachCampMapData = _make_medium()
	for s: Dictionary in map.shelters:
		var cx: int = (s["lx"] + s["rx"]) / 2
		var cy: int = (s["ly"] + s["ry"]) / 2
		assert_eq(map.get_tile(cx, cy), Enums.TileType.FLOOR_DIRT,
			"Shelter %d centre must be FLOOR_DIRT (no walls)" % s["id"])


# ---------------------------------------------------------------------------
# Entry vectors (s56.5.2)
# ---------------------------------------------------------------------------

func test_exactly_four_entry_vectors() -> void:
	for seed: String in ["ev1", "ev2", "ev3"]:
		var map: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
			seed, 5, [ForestApproachCampMapData.ObjType.KILL_LEADER])
		assert_eq(map.entry_vectors.size(), 4,
			"Must have exactly 4 entry vectors (seed %s)" % seed)


func test_entry_vector_tiles_are_zone_exit() -> void:
	var map: ForestApproachCampMapData = _make_medium()
	for ev: Dictionary in map.entry_vectors:
		assert_eq(map.get_tile(ev["x"], ev["y"]), Enums.TileType.ZONE_EXIT,
			"Entry vector at (%d,%d) must be ZONE_EXIT" % [ev["x"], ev["y"]])


func test_one_trail_entry_vector() -> void:
	var map: ForestApproachCampMapData = _make_medium()
	var trail_count: int = 0
	for ev: Dictionary in map.entry_vectors:
		if ev["is_trail"]:
			trail_count += 1
	assert_eq(trail_count, 1,
		"Exactly 1 entry vector must be the trail approach")


# ---------------------------------------------------------------------------
# Population (s56.5.3)
# ---------------------------------------------------------------------------

func test_at_least_one_outer_sentry() -> void:
	for seed: String in ["pop1", "pop2", "pop3"]:
		var map: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
			seed, 3, [ForestApproachCampMapData.ObjType.KILL_LEADER])
		var sentries: int = 0
		for slot: Dictionary in map.population_slots:
			if slot["role"] == ForestApproachCampMapData.PopRole.OUTER_SENTRY:
				sentries += 1
		assert_true(sentries >= 1,
			"At least one OUTER_SENTRY required (seed %s)" % seed)


func test_exactly_one_leader_group() -> void:
	for seed: String in ["ldr1", "ldr2", "ldr3"]:
		var map: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
			seed, 5, [ForestApproachCampMapData.ObjType.KILL_LEADER])
		var leaders: int = 0
		for slot: Dictionary in map.population_slots:
			if slot["role"] == ForestApproachCampMapData.PopRole.LEADER_GROUP:
				leaders += 1
		assert_eq(leaders, 1,
			"Exactly one LEADER_GROUP slot required (seed %s)" % seed)


func test_leader_group_in_camp_zone() -> void:
	var map: ForestApproachCampMapData = _make_medium()
	for slot: Dictionary in map.population_slots:
		if slot["role"] == ForestApproachCampMapData.PopRole.LEADER_GROUP:
			assert_eq(slot["zone"], ForestApproachCampMapData.Zone.CAMP,
				"LEADER_GROUP must be in CAMP zone")
			assert_true(slot["y"] >= map.clearing_start_y,
				"LEADER_GROUP y must be in camp zone (y=%d, clearing_start=%d)" % [
					slot["y"], map.clearing_start_y])


func test_forest_patrol_in_forest_zone() -> void:
	var map: ForestApproachCampMapData = _make_medium()
	for slot: Dictionary in map.population_slots:
		if slot["role"] == ForestApproachCampMapData.PopRole.FOREST_PATROL:
			assert_eq(slot["zone"], ForestApproachCampMapData.Zone.FOREST,
				"FOREST_PATROL must be in FOREST zone")
			assert_true(slot["y"] < map.clearing_start_y,
				"FOREST_PATROL y must be above clearing (y=%d)" % slot["y"])


# ---------------------------------------------------------------------------
# Objectives (s56.5.5)
# ---------------------------------------------------------------------------

func test_kill_leader_objective_in_command_shelter() -> void:
	var map: ForestApproachCampMapData = _make_with_objectives(
		[ForestApproachCampMapData.ObjType.KILL_LEADER])
	var cmd: Dictionary = _command_shelter(map)
	var found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == ForestApproachCampMapData.ObjType.KILL_LEADER:
			assert_eq(slot["shelter_id"], cmd["id"],
				"KILL_LEADER objective must point to command shelter")
			found = true
	assert_true(found, "KILL_LEADER objective slot must exist")


func test_burn_camp_creates_one_marker_per_shelter() -> void:
	var map: ForestApproachCampMapData = _make_with_objectives(
		[ForestApproachCampMapData.ObjType.BURN_CAMP])
	var burn_count: int = 0
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == ForestApproachCampMapData.ObjType.BURN_CAMP:
			burn_count += 1
	assert_eq(burn_count, map.shelters.size(),
		"BURN_CAMP must have one objective marker per shelter")


func test_recover_goods_objective_created() -> void:
	var map: ForestApproachCampMapData = _make_with_objectives(
		[ForestApproachCampMapData.ObjType.RECOVER_GOODS])
	var found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == ForestApproachCampMapData.ObjType.RECOVER_GOODS:
			found = true
	assert_true(found, "RECOVER_GOODS objective slot must exist")


func test_rescue_hostages_objective_created() -> void:
	var map: ForestApproachCampMapData = _make_with_objectives(
		[ForestApproachCampMapData.ObjType.RESCUE_HOSTAGES])
	var found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == ForestApproachCampMapData.ObjType.RESCUE_HOSTAGES:
			found = true
	assert_true(found, "RESCUE_HOSTAGES objective slot must exist")


# ---------------------------------------------------------------------------
# Stream (s56.5.4) — probabilistic
# ---------------------------------------------------------------------------

func test_stream_appears_in_some_seeds() -> void:
	var found_stream: bool = false
	for i: int in range(30):
		var map: ForestApproachCampMapData = _make_medium("stream_seed_%d" % i)
		if map.has_stream:
			found_stream = true
			break
	assert_true(found_stream,
		"At least one map across 30 seeds should have a stream (~20% chance)")


func test_stream_tiles_are_water_shallow() -> void:
	for i: int in range(50):
		var map: ForestApproachCampMapData = _make_medium("str_tile_%d" % i)
		if map.has_stream:
			# Sample near the top of the forest (away from entry ZONE_EXIT).
			var sy: int = 5
			assert_eq(map.get_tile(map.stream_x, sy), Enums.TileType.WATER_SHALLOW,
				"Stream tile must be WATER_SHALLOW (seed str_tile_%d)" % i)
			return
	pass  # No stream found across 50 seeds — skip.


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

func test_same_seed_produces_identical_map() -> void:
	var map_a: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
		"determinism_forest", 6,
		[ForestApproachCampMapData.ObjType.KILL_LEADER,
		 ForestApproachCampMapData.ObjType.BURN_CAMP])
	var map_b: ForestApproachCampMapData = ForestApproachCampGenerator.generate(
		"determinism_forest", 6,
		[ForestApproachCampMapData.ObjType.KILL_LEADER,
		 ForestApproachCampMapData.ObjType.BURN_CAMP])

	assert_eq(map_a.size_category, map_b.size_category,
		"size_category must match for same seed")
	assert_eq(map_a.shelters.size(), map_b.shelters.size(),
		"shelter count must match for same seed")
	assert_eq(map_a.has_stream, map_b.has_stream,
		"has_stream must match for same seed")
	assert_eq(map_a.clearing_start_y, map_b.clearing_start_y,
		"clearing_start_y must match for same seed")

	# Spot-check tiles in forest and camp zones.
	var forest_y: int = map_a.clearing_start_y / 2
	var camp_y: int = map_a.clearing_start_y + 5
	for x: int in [5, map_a.width / 2, map_a.width - 5]:
		assert_eq(map_a.get_tile(x, forest_y), map_b.get_tile(x, forest_y),
			"Forest tile at x=%d must match for same seed" % x)
		assert_eq(map_a.get_tile(x, camp_y), map_b.get_tile(x, camp_y),
			"Camp tile at x=%d must match for same seed" % x)
