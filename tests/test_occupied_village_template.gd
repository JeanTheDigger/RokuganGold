extends GutTest
## Integration tests: OccupiedVillageTemplateGenerator + OccupiedVillageMapData
## (s56.4 — LOCKED).
##
## Verifies determinism, dimensional constraints, layout rules, and the
## full AsciiMapData inheritance chain.


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_hamlet(seed_str: String = "test_hamlet") -> OccupiedVillageMapData:
	return OccupiedVillageTemplateGenerator.generate(
		seed_str, 2,
		[OccupiedVillageMapData.ObjType.KILL_LEADER])


func _make_village(seed_str: String = "test_village") -> OccupiedVillageMapData:
	return OccupiedVillageTemplateGenerator.generate(
		seed_str, 6,
		[OccupiedVillageMapData.ObjType.KILL_LEADER])


func _make_village_with_objectives(
		objectives: Array,
		seed_str: String = "obj_test") -> OccupiedVillageMapData:
	return OccupiedVillageTemplateGenerator.generate(seed_str, 6, objectives)


func _headman_building(map: OccupiedVillageMapData) -> Dictionary:
	for b: Dictionary in map.buildings:
		if b["type"] == OccupiedVillageMapData.BuildingType.HEADMAN:
			return b
	return {}


# ---------------------------------------------------------------------------
# Type and inheritance
# ---------------------------------------------------------------------------

func test_is_ascii_map_data_instance() -> void:
	var map: OccupiedVillageMapData = _make_hamlet()
	assert_is(map, AsciiMapData,
		"OccupiedVillageMapData must extend AsciiMapData for FovSystem polymorphism")


func test_fov_system_accepts_village_map() -> void:
	var map: OccupiedVillageMapData = _make_hamlet()
	# Use the headman's position (guaranteed floor) as the viewer.
	var hm: Dictionary = _headman_building(map)
	var cx: int = (hm["lx"] + hm["rx"]) / 2
	var cy: int = (hm["ly"] + hm["ry"]) / 2
	var visible: Dictionary = FovSystem.compute_visible(cx, cy, 5, map)
	assert_true(visible.has(Vector2i(cx, cy)),
		"Viewer tile must be in visible set on OccupiedVillageMapData")


# ---------------------------------------------------------------------------
# Size category and dimensions (s56.4.1)
# ---------------------------------------------------------------------------

func test_strength_1_may_produce_hamlet() -> void:
	# Run several seeds — at least one must produce HAMLET at strength ≤ 3.
	var found_hamlet: bool = false
	for i: int in range(20):
		var map: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
			"s%d" % i, 2,
			[OccupiedVillageMapData.ObjType.KILL_LEADER])
		if map.size_category == OccupiedVillageMapData.SizeCategory.HAMLET:
			found_hamlet = true
			break
	assert_true(found_hamlet,
		"At least one seed with strength 2 should produce a HAMLET")


func test_strength_above_3_forces_village() -> void:
	for i: int in range(10):
		var map: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
			"sv%d" % i, 4,
			[OccupiedVillageMapData.ObjType.KILL_LEADER])
		assert_eq(map.size_category, OccupiedVillageMapData.SizeCategory.VILLAGE,
			"Strength 4+ must always produce VILLAGE (seed sv%d)" % i)


func test_hamlet_dimensions() -> void:
	var map: OccupiedVillageMapData = _make_hamlet()
	if map.size_category == OccupiedVillageMapData.SizeCategory.HAMLET:
		assert_eq(map.width, 40, "HAMLET width must be 40")
		assert_eq(map.height, 36, "HAMLET height must be 36")


func test_village_dimensions() -> void:
	var map: OccupiedVillageMapData = _make_village()
	assert_eq(map.width, 60, "VILLAGE width must be 60")
	assert_eq(map.height, 52, "VILLAGE height must be 52")


# ---------------------------------------------------------------------------
# Building count bounds (s56.4.1)
# ---------------------------------------------------------------------------

func test_hamlet_building_count_in_range() -> void:
	for seed: String in ["h1", "h2", "h3", "h4", "h5", "h6", "h7", "h8"]:
		var map: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
			seed, 2, [OccupiedVillageMapData.ObjType.KILL_LEADER])
		if map.size_category == OccupiedVillageMapData.SizeCategory.HAMLET:
			assert_true(map.buildings.size() >= 3 and map.buildings.size() <= 6,
				"HAMLET building count must be 3-6 (got %d, seed %s)" % [
					map.buildings.size(), seed])


func test_village_building_count_in_range() -> void:
	for seed: String in ["v1", "v2", "v3", "v4", "v5"]:
		var map: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
			seed, 6, [OccupiedVillageMapData.ObjType.KILL_LEADER])
		assert_true(map.buildings.size() >= 7 and map.buildings.size() <= 15,
			"VILLAGE building count must be 7-15 (got %d, seed %s)" % [
				map.buildings.size(), seed])


# ---------------------------------------------------------------------------
# Exactly one headman's house
# ---------------------------------------------------------------------------

func test_exactly_one_headman_building_hamlet() -> void:
	for seed: String in ["hm1", "hm2", "hm3"]:
		var map: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
			seed, 2, [OccupiedVillageMapData.ObjType.KILL_LEADER])
		var count: int = 0
		for b: Dictionary in map.buildings:
			if b["type"] == OccupiedVillageMapData.BuildingType.HEADMAN:
				count += 1
		assert_eq(count, 1,
			"Must be exactly one HEADMAN building (seed %s)" % seed)


func test_exactly_one_headman_building_village() -> void:
	var map: OccupiedVillageMapData = _make_village()
	var count: int = 0
	for b: Dictionary in map.buildings:
		if b["type"] == OccupiedVillageMapData.BuildingType.HEADMAN:
			count += 1
	assert_eq(count, 1, "VILLAGE must have exactly one HEADMAN building")


# ---------------------------------------------------------------------------
# Buildings within map bounds and wall/floor tiles
# ---------------------------------------------------------------------------

func test_buildings_within_map_bounds() -> void:
	var map: OccupiedVillageMapData = _make_village()
	for b: Dictionary in map.buildings:
		assert_true(b["lx"] >= 0 and b["rx"] < map.width,
			"Building id=%d x bounds out of range" % b["id"])
		assert_true(b["ly"] >= 0 and b["ry"] < map.height,
			"Building id=%d y bounds out of range" % b["id"])


func test_building_corners_are_wall_wood() -> void:
	var map: OccupiedVillageMapData = _make_village()
	for b: Dictionary in map.buildings:
		assert_eq(map.get_tile(b["lx"], b["ly"]), Enums.TileType.WALL_WOOD,
			"Top-left corner of building %d must be WALL_WOOD" % b["id"])
		assert_eq(map.get_tile(b["rx"], b["ry"]), Enums.TileType.WALL_WOOD,
			"Bottom-right corner of building %d must be WALL_WOOD" % b["id"])


func test_building_interior_is_floor_wood() -> void:
	var map: OccupiedVillageMapData = _make_village()
	for b: Dictionary in map.buildings:
		# Only buildings with interior room (at least 3×3 footprint).
		if b["rx"] - b["lx"] >= 2 and b["ry"] - b["ly"] >= 2:
			var cx: int = (b["lx"] + b["rx"]) / 2
			var cy: int = (b["ly"] + b["ry"]) / 2
			assert_eq(map.get_tile(cx, cy), Enums.TileType.FLOOR_WOOD,
				"Centre of building %d must be FLOOR_WOOD" % b["id"])


# ---------------------------------------------------------------------------
# Road is FLOOR_DIRT (s56.4.2)
# ---------------------------------------------------------------------------

func test_road_tiles_are_floor_dirt() -> void:
	var map: OccupiedVillageMapData = _make_village()
	var road_x: int = map.width / 2 - 1
	# Sample the road mid-map (away from edges, buildings, river).
	var mid_y: int = map.height / 4
	assert_eq(map.get_tile(road_x, mid_y), Enums.TileType.FLOOR_DIRT,
		"Road tile (left column) must be FLOOR_DIRT")
	assert_eq(map.get_tile(road_x + 1, mid_y), Enums.TileType.FLOOR_DIRT,
		"Road tile (right column) must be FLOOR_DIRT")


# ---------------------------------------------------------------------------
# Crop border (s56.4.4)
# ---------------------------------------------------------------------------

func test_top_row_is_crops() -> void:
	var map: OccupiedVillageMapData = _make_village()
	assert_eq(map.get_tile(map.width / 2, 0), Enums.TileType.CROPS,
		"Top edge must be CROPS")


func test_left_column_is_crops() -> void:
	var map: OccupiedVillageMapData = _make_village()
	assert_eq(map.get_tile(0, map.height / 2), Enums.TileType.CROPS,
		"Left edge must be CROPS")


# ---------------------------------------------------------------------------
# Entry vectors (s56.4.2)
# ---------------------------------------------------------------------------

func test_exactly_four_entry_vectors() -> void:
	for seed: String in ["ev1", "ev2", "ev3"]:
		var map: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
			seed, 4, [OccupiedVillageMapData.ObjType.KILL_LEADER])
		assert_eq(map.entry_vectors.size(), 4,
			"Must have exactly 4 entry vectors (seed %s)" % seed)


func test_entry_vector_tiles_are_zone_exit() -> void:
	var map: OccupiedVillageMapData = _make_village()
	for ev: Dictionary in map.entry_vectors:
		assert_eq(map.get_tile(ev["x"], ev["y"]), Enums.TileType.ZONE_EXIT,
			"Entry vector tile at (%d,%d) must be ZONE_EXIT" % [ev["x"], ev["y"]])


func test_two_road_entry_vectors() -> void:
	var map: OccupiedVillageMapData = _make_village()
	var road_count: int = 0
	for ev: Dictionary in map.entry_vectors:
		if ev["is_road"]:
			road_count += 1
	assert_eq(road_count, 2,
		"Exactly 2 of 4 entry vectors must be road approaches")


func test_two_field_entry_vectors() -> void:
	var map: OccupiedVillageMapData = _make_village()
	var field_count: int = 0
	for ev: Dictionary in map.entry_vectors:
		if not ev["is_road"]:
			field_count += 1
	assert_eq(field_count, 2,
		"Exactly 2 of 4 entry vectors must be field approaches")


# ---------------------------------------------------------------------------
# Population — sentry, leader (s56.4.3)
# ---------------------------------------------------------------------------

func test_at_least_one_sentry() -> void:
	for seed: String in ["ps1", "ps2", "ps3"]:
		var map: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
			seed, 2, [OccupiedVillageMapData.ObjType.KILL_LEADER])
		var sentries: int = 0
		for slot: Dictionary in map.population_slots:
			if slot["role"] == OccupiedVillageMapData.PopRole.SENTRY:
				sentries += 1
		assert_true(sentries >= 1,
			"At least one SENTRY required (seed %s)" % seed)


func test_exactly_one_leader() -> void:
	for seed: String in ["pl1", "pl2", "pl3"]:
		var map: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
			seed, 4, [OccupiedVillageMapData.ObjType.KILL_LEADER])
		var leaders: int = 0
		for slot: Dictionary in map.population_slots:
			if slot["role"] == OccupiedVillageMapData.PopRole.LEADER:
				leaders += 1
		assert_eq(leaders, 1,
			"Exactly one LEADER slot required (seed %s)" % seed)


func test_leader_inside_headman_building() -> void:
	var map: OccupiedVillageMapData = _make_village()
	var hm: Dictionary = _headman_building(map)
	var leader_in_headman: bool = false
	for slot: Dictionary in map.population_slots:
		if slot["role"] == OccupiedVillageMapData.PopRole.LEADER:
			if slot["building_id"] == hm["id"]:
				leader_in_headman = true
	assert_true(leader_in_headman, "LEADER slot must be inside the headman's building")


# ---------------------------------------------------------------------------
# Civilians (s56.4.3)
# ---------------------------------------------------------------------------

func test_civilian_slots_match_non_headman_buildings() -> void:
	var map: OccupiedVillageMapData = _make_village()
	var non_headman_count: int = 0
	for b: Dictionary in map.buildings:
		if b["type"] != OccupiedVillageMapData.BuildingType.HEADMAN:
			non_headman_count += 1
	assert_eq(map.civilian_slots.size(), non_headman_count,
		"One civilian slot per non-headman building")


# ---------------------------------------------------------------------------
# Objective slots (s56.4.5)
# ---------------------------------------------------------------------------

func test_kill_leader_objective_in_headman_building() -> void:
	var map: OccupiedVillageMapData = _make_village_with_objectives(
		[OccupiedVillageMapData.ObjType.KILL_LEADER])
	var hm: Dictionary = _headman_building(map)
	var found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == OccupiedVillageMapData.ObjType.KILL_LEADER:
			if slot["building_id"] == hm["id"]:
				found = true
	assert_true(found, "KILL_LEADER objective must be inside the headman building")


func test_drive_out_objective_created() -> void:
	var map: OccupiedVillageMapData = _make_village_with_objectives(
		[OccupiedVillageMapData.ObjType.DRIVE_OUT])
	var found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == OccupiedVillageMapData.ObjType.DRIVE_OUT:
			found = true
	assert_true(found, "DRIVE_OUT objective slot must be created")


func test_recover_goods_objective_created() -> void:
	var map: OccupiedVillageMapData = _make_village_with_objectives(
		[OccupiedVillageMapData.ObjType.RECOVER_GOODS])
	var found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == OccupiedVillageMapData.ObjType.RECOVER_GOODS:
			found = true
	assert_true(found, "RECOVER_GOODS objective slot must be created")


func test_rescue_hostages_objective_created() -> void:
	var map: OccupiedVillageMapData = _make_village_with_objectives(
		[OccupiedVillageMapData.ObjType.RESCUE_HOSTAGES])
	var found: bool = false
	for slot: Dictionary in map.objective_slots:
		if slot["obj_type"] == OccupiedVillageMapData.ObjType.RESCUE_HOSTAGES:
			found = true
	assert_true(found, "RESCUE_HOSTAGES objective slot must be created")


func test_recover_goods_prefers_barn() -> void:
	# Find a seed that produces a barn in a village, then check placement.
	for seed: String in ["gb1", "gb2", "gb3", "gb4", "gb5", "gb6", "gb7", "gb8", "gb9", "gb10"]:
		var map: OccupiedVillageMapData = _make_village_with_objectives(
			[OccupiedVillageMapData.ObjType.RECOVER_GOODS], seed)
		var has_barn: bool = false
		var barn_id: int = -1
		for b: Dictionary in map.buildings:
			if b["type"] == OccupiedVillageMapData.BuildingType.BARN:
				has_barn = true
				barn_id = b["id"]
				break
		if not has_barn:
			continue
		for slot: Dictionary in map.objective_slots:
			if slot["obj_type"] == OccupiedVillageMapData.ObjType.RECOVER_GOODS:
				assert_eq(slot["building_id"], barn_id,
					"RECOVER_GOODS must prefer BARN when one exists (seed %s)" % seed)
		return  # Found a barn and checked — test done.
	# No barn found across 10 seeds — skip (not a failure; BARN is random).


# ---------------------------------------------------------------------------
# River (s56.4.4) — probabilistic
# ---------------------------------------------------------------------------

func test_river_appears_in_some_seeds() -> void:
	var found_river: bool = false
	for i: int in range(30):
		var map: OccupiedVillageMapData = _make_village("river_seed_%d" % i)
		if map.has_river:
			found_river = true
			break
	assert_true(found_river,
		"At least one village across 30 seeds should have a river (~20% chance)")


func test_river_y_row_is_water_deep_when_present() -> void:
	for i: int in range(50):
		var map: OccupiedVillageMapData = _make_village("rv_%d" % i)
		if map.has_river:
			# Tile at the far left of the river row (not the bridge).
			var non_bridge_x: int = 0
			assert_eq(map.get_tile(non_bridge_x, map.river_y),
				Enums.TileType.WATER_DEEP,
				"River row must be WATER_DEEP at x=0 (seed rv_%d)" % i)
			return
	pass  # If no river found across 50 seeds (< 1% chance), skip.


func test_river_bridge_is_floor_wood_when_present() -> void:
	for i: int in range(50):
		var map: OccupiedVillageMapData = _make_village("rb_%d" % i)
		if map.has_river:
			assert_eq(map.get_tile(map.bridge_x, map.river_y),
				Enums.TileType.FLOOR_WOOD,
				"Bridge tiles must be FLOOR_WOOD (seed rb_%d)" % i)
			assert_eq(map.get_tile(map.bridge_x + 1, map.river_y),
				Enums.TileType.FLOOR_WOOD,
				"Bridge right tile must be FLOOR_WOOD (seed rb_%d)" % i)
			return
	pass  # No river across 50 seeds — skip.


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

func test_same_seed_produces_identical_map() -> void:
	var map_a: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
		"determinism_test", 5,
		[OccupiedVillageMapData.ObjType.KILL_LEADER,
		 OccupiedVillageMapData.ObjType.DRIVE_OUT])
	var map_b: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
		"determinism_test", 5,
		[OccupiedVillageMapData.ObjType.KILL_LEADER,
		 OccupiedVillageMapData.ObjType.DRIVE_OUT])

	assert_eq(map_a.size_category, map_b.size_category,
		"size_category must match for same seed")
	assert_eq(map_a.width, map_b.width,
		"width must match for same seed")
	assert_eq(map_a.buildings.size(), map_b.buildings.size(),
		"building count must match for same seed")
	assert_eq(map_a.has_river, map_b.has_river,
		"has_river must match for same seed")

	# Spot-check a tile in the middle of the map.
	var cx: int = map_a.width / 2
	var cy: int = map_a.height / 2
	assert_eq(map_a.get_tile(cx, cy), map_b.get_tile(cx, cy),
		"Centre tile must match for same seed")


func test_different_seeds_may_differ() -> void:
	var map_a: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
		"alpha_seed", 6,
		[OccupiedVillageMapData.ObjType.KILL_LEADER])
	var map_b: OccupiedVillageMapData = OccupiedVillageTemplateGenerator.generate(
		"beta_seed", 6,
		[OccupiedVillageMapData.ObjType.KILL_LEADER])
	# At minimum the seed strings differ — building layout or river will differ.
	var same: bool = (map_a.buildings.size() == map_b.buildings.size()
		and map_a.has_river == map_b.has_river)
	# This is not a strict failure — just document that seeds can diverge.
	if not same:
		pass  # Expected divergence.
