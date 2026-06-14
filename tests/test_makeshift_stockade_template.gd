extends GutTest
## GUT tests for MakeshiftStockadeGenerator and MakeshiftStockadeMapData (s56.7).

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_small(seed_str: String = "test_small") -> MakeshiftStockadeMapData:
	return MakeshiftStockadeGenerator.generate(
		seed_str, 2, [MakeshiftStockadeMapData.ObjType.KILL_LEADER])


func _make_medium(seed_str: String = "test_medium") -> MakeshiftStockadeMapData:
	return MakeshiftStockadeGenerator.generate(
		seed_str, 5, [MakeshiftStockadeMapData.ObjType.KILL_LEADER])


func _make_large(seed_str: String = "test_large") -> MakeshiftStockadeMapData:
	return MakeshiftStockadeGenerator.generate(
		seed_str, 8, [MakeshiftStockadeMapData.ObjType.KILL_LEADER])


func _count_role(map: MakeshiftStockadeMapData, role: int) -> int:
	var n: int = 0
	for slot: Dictionary in map.population_slots:
		if slot["role"] == role:
			n += 1
	return n


func _all_perimeter_wall_tiles_are_wall_or_exit(map: MakeshiftStockadeMapData) -> bool:
	var ok_types: Array[int] = [
		Enums.TileType.WALL_WOOD,
		Enums.TileType.WALL_STONE,
		Enums.TileType.ZONE_EXIT,
		Enums.TileType.FLOOR_DIRT,  # gate gap cleared to FLOOR_DIRT before ZONE_EXIT
	]
	var lx: int = map.perim_lx
	var rx: int = map.perim_rx
	var ty: int = map.perim_ty
	var by: int = map.perim_by
	for x: int in range(lx, rx + 1):
		if not map.get_tile(x, ty) in ok_types:
			return false
		if not map.get_tile(x, by) in ok_types:
			return false
	for y: int in range(ty + 1, by):
		if not map.get_tile(lx, y) in ok_types:
			return false
		if not map.get_tile(rx, y) in ok_types:
			return false
	return true


# ---------------------------------------------------------------------------
# Type and basic structure
# ---------------------------------------------------------------------------

func test_generate_returns_correct_type() -> void:
	assert_true(_make_small() is MakeshiftStockadeMapData,
		"generate() should return MakeshiftStockadeMapData")


func test_seed_string_stored() -> void:
	var map := _make_small("my_seed")
	assert_eq(map.seed_string, "my_seed")


# ---------------------------------------------------------------------------
# Dimensions
# ---------------------------------------------------------------------------

func test_small_dimensions() -> void:
	var map := _make_small()
	assert_eq(map.width,  40, "SMALL width should be 40")
	assert_eq(map.height, 44, "SMALL height should be 44")


func test_medium_dimensions() -> void:
	var map := _make_medium()
	assert_eq(map.width,  60, "MEDIUM width should be 60")
	assert_eq(map.height, 60, "MEDIUM height should be 60")


func test_large_dimensions() -> void:
	var map := _make_large()
	assert_eq(map.width,  80, "LARGE width should be 80")
	assert_eq(map.height, 76, "LARGE height should be 76")


# ---------------------------------------------------------------------------
# Perimeter bounds
# ---------------------------------------------------------------------------

func test_perim_bounds_small() -> void:
	var map := _make_small()
	assert_eq(map.perim_lx, 8)
	assert_eq(map.perim_rx, 31)
	assert_eq(map.perim_ty, 8)
	assert_eq(map.perim_by, 35)


func test_perim_bounds_medium() -> void:
	var map := _make_medium()
	assert_eq(map.perim_lx, 10)
	assert_eq(map.perim_rx, 49)
	assert_eq(map.perim_ty, 10)
	assert_eq(map.perim_by, 49)


func test_perim_bounds_large() -> void:
	var map := _make_large()
	assert_eq(map.perim_lx, 12)
	assert_eq(map.perim_rx, 67)
	assert_eq(map.perim_ty, 12)
	assert_eq(map.perim_by, 63)


# ---------------------------------------------------------------------------
# Gate
# ---------------------------------------------------------------------------

func test_gate_x_is_centered() -> void:
	var map := _make_small()
	assert_eq(map.gate_x, map.width / 2,
		"gate_x should be width/2 (south wall centre)")


func test_gate_zone_exit_on_south_wall() -> void:
	var map := _make_small()
	assert_eq(map.get_tile(map.gate_x, map.perim_by), Enums.TileType.ZONE_EXIT,
		"gate_x tile on south wall should be ZONE_EXIT (entry vector)")


func test_gate_adjacent_tile_cleared() -> void:
	var map := _make_small()
	# gate_x+1 is cleared to FLOOR_DIRT (gate gap width = 2)
	assert_eq(map.get_tile(map.gate_x + 1, map.perim_by), Enums.TileType.FLOOR_DIRT,
		"gate_x+1 on south wall should be FLOOR_DIRT (gate gap)")


# ---------------------------------------------------------------------------
# Approach and interior terrain
# ---------------------------------------------------------------------------

func test_approach_south_corner_is_floor_grass() -> void:
	var map := _make_small()
	# Far south-west corner of approach — open ground.
	assert_eq(map.get_tile(1, map.height - 1), Enums.TileType.FLOOR_GRASS,
		"Map corners (open approach) should be FLOOR_GRASS")


func test_interior_corner_is_floor_dirt() -> void:
	var map := _make_small()
	# Top-left interior corner — should be FLOOR_DIRT (not overwritten by shelters/platform).
	assert_eq(map.get_tile(map.perim_lx + 1, map.perim_ty + 1),
		Enums.TileType.FLOOR_DIRT,
		"Interior tiles should be FLOOR_DIRT (not FLOOR_GRASS)")


# ---------------------------------------------------------------------------
# Perimeter wall tiles
# ---------------------------------------------------------------------------

func test_perimeter_tiles_are_wall_or_zone_exit_small() -> void:
	assert_true(_all_perimeter_wall_tiles_are_wall_or_exit(_make_small()),
		"All perimeter tiles should be wall, ZONE_EXIT, or cleared gate gap")


func test_perimeter_tiles_are_wall_or_zone_exit_medium() -> void:
	assert_true(_all_perimeter_wall_tiles_are_wall_or_exit(_make_medium()))


func test_corners_are_wall_stone() -> void:
	var map := _make_small()
	assert_eq(map.get_tile(map.perim_lx, map.perim_ty), Enums.TileType.WALL_STONE,
		"NW corner should be WALL_STONE")
	assert_eq(map.get_tile(map.perim_rx, map.perim_ty), Enums.TileType.WALL_STONE,
		"NE corner should be WALL_STONE")
	assert_eq(map.get_tile(map.perim_lx, map.perim_by), Enums.TileType.WALL_STONE,
		"SW corner should be WALL_STONE")
	assert_eq(map.get_tile(map.perim_rx, map.perim_by), Enums.TileType.WALL_STONE,
		"SE corner should be WALL_STONE")


# ---------------------------------------------------------------------------
# Weak points
# ---------------------------------------------------------------------------

func test_weak_points_count_small() -> void:
	var map := _make_small()
	assert_eq(map.weak_points.size(), 2, "SMALL should have 2 weak points (W + E)")


func test_weak_points_count_medium() -> void:
	var map := _make_medium()
	assert_eq(map.weak_points.size(), 3, "MEDIUM should have 3 weak points (N + W + E)")


func test_weak_points_sides_small() -> void:
	var map := _make_small()
	var sides: Array = map.weak_points.map(func(wp: Dictionary) -> String: return wp["side"])
	assert_true("W" in sides and "E" in sides,
		"SMALL weak-point sides should be W and E")
	assert_false("N" in sides, "SMALL should have no north weak point")


func test_weak_points_sides_medium() -> void:
	var map := _make_medium()
	var sides: Array = map.weak_points.map(func(wp: Dictionary) -> String: return wp["side"])
	assert_true("W" in sides and "E" in sides and "N" in sides,
		"MEDIUM weak-point sides should include N, W, E")


# ---------------------------------------------------------------------------
# Entry vectors
# ---------------------------------------------------------------------------

func test_entry_vectors_count_small() -> void:
	var map := _make_small()
	assert_eq(map.entry_vectors.size(), 3,
		"SMALL: 1 gate + 2 weak points = 3 entry vectors")


func test_entry_vectors_count_medium() -> void:
	var map := _make_medium()
	assert_eq(map.entry_vectors.size(), 4,
		"MEDIUM: 1 gate + 3 weak points = 4 entry vectors")


func test_entry_vectors_count_large() -> void:
	var map := _make_large()
	assert_eq(map.entry_vectors.size(), 4,
		"LARGE: 1 gate + 3 weak points = 4 entry vectors")


func test_entry_vectors_exactly_one_gate() -> void:
	for map: MakeshiftStockadeMapData in [_make_small(), _make_medium(), _make_large()]:
		var gate_count: int = 0
		for ev: Dictionary in map.entry_vectors:
			if ev["is_gate"]:
				gate_count += 1
		assert_eq(gate_count, 1, "Exactly 1 entry vector should be is_gate=true")


func test_entry_vector_gate_on_south_wall() -> void:
	var map := _make_small()
	for ev: Dictionary in map.entry_vectors:
		if ev["is_gate"]:
			assert_eq(ev["y"], map.perim_by,
				"Gate entry vector y should equal perim_by (south wall)")


func test_entry_vector_tiles_are_zone_exit() -> void:
	for map: MakeshiftStockadeMapData in [_make_small(), _make_medium(), _make_large()]:
		for ev: Dictionary in map.entry_vectors:
			assert_eq(map.get_tile(ev["x"], ev["y"]), Enums.TileType.ZONE_EXIT,
				"Every entry vector tile should be ZONE_EXIT")


# ---------------------------------------------------------------------------
# Shelters
# ---------------------------------------------------------------------------

func test_shelters_count_small_in_range() -> void:
	for i: int in range(20):
		var map: MakeshiftStockadeMapData = MakeshiftStockadeGenerator.generate(
			"s_seed_%d" % i, 2, [])
		if map.size_category != MakeshiftStockadeMapData.SizeCategory.SMALL:
			continue
		assert_true(map.shelters.size() >= 1 and map.shelters.size() <= 2,
			"SMALL shelter count should be 1–2, got %d" % map.shelters.size())


func test_shelters_count_medium_in_range() -> void:
	for i: int in range(10):
		var map: MakeshiftStockadeMapData = MakeshiftStockadeGenerator.generate(
			"m_seed_%d" % i, 5, [])
		assert_true(map.shelters.size() >= 3 and map.shelters.size() <= 6,
			"MEDIUM shelter count should be 3–6, got %d" % map.shelters.size())


func test_shelters_count_large_in_range() -> void:
	for i: int in range(5):
		var map: MakeshiftStockadeMapData = MakeshiftStockadeGenerator.generate(
			"l_seed_%d" % i, 8, [])
		assert_true(map.shelters.size() >= 7 and map.shelters.size() <= 10,
			"LARGE shelter count should be 7–10, got %d" % map.shelters.size())


func test_exactly_one_command_shelter() -> void:
	for map: MakeshiftStockadeMapData in [_make_small(), _make_medium(), _make_large()]:
		var cmd_count: int = 0
		for sh: Dictionary in map.shelters:
			if sh["type"] == MakeshiftStockadeMapData.ShelterType.COMMAND:
				cmd_count += 1
		assert_eq(cmd_count, 1, "Exactly 1 COMMAND shelter")


func test_shelters_all_inside_perimeter() -> void:
	for map: MakeshiftStockadeMapData in [_make_small(), _make_medium(), _make_large()]:
		for sh: Dictionary in map.shelters:
			assert_true(sh["lx"] > map.perim_lx and sh["rx"] < map.perim_rx and
				sh["ly"] > map.perim_ty and sh["ry"] < map.perim_by,
				"Shelter %d must be strictly inside perimeter" % sh["id"])


# ---------------------------------------------------------------------------
# Firepits
# ---------------------------------------------------------------------------

func test_firepits_count_small() -> void:
	assert_eq(_make_small().firepits.size(), 1, "SMALL should have 1 firepit")


func test_firepits_count_medium() -> void:
	assert_eq(_make_medium().firepits.size(), 2, "MEDIUM should have 2 firepits")


func test_firepits_count_large() -> void:
	assert_eq(_make_large().firepits.size(), 3, "LARGE should have 3 firepits")


func test_firepit_tiles_are_fire() -> void:
	var map := _make_medium()
	for fp: Dictionary in map.firepits:
		assert_eq(map.get_tile(fp["x"], fp["y"]), Enums.TileType.FIRE,
			"Firepit tile should be FIRE")


# ---------------------------------------------------------------------------
# Platform
# ---------------------------------------------------------------------------

func test_platform_absent_for_small() -> void:
	assert_false(_make_small().has_platform, "SMALL should not have a platform")


func test_platform_present_for_medium() -> void:
	assert_true(_make_medium().has_platform, "MEDIUM should have a platform")


func test_platform_present_for_large() -> void:
	assert_true(_make_large().has_platform, "LARGE should have a platform")


func test_platform_tiles_are_floor_stone_medium() -> void:
	var map := _make_medium()
	assert_true(map.has_platform)
	assert_eq(map.get_tile(map.platform_x, map.platform_y), Enums.TileType.FLOOR_STONE,
		"Platform centre tile should be FLOOR_STONE")


func test_platform_inside_perimeter() -> void:
	var map := _make_medium()
	assert_true(map.platform_x > map.perim_lx and map.platform_x < map.perim_rx,
		"platform_x should be inside perimeter")
	assert_true(map.platform_y > map.perim_ty and map.platform_y < map.perim_by,
		"platform_y should be inside perimeter")


# ---------------------------------------------------------------------------
# Population slots
# ---------------------------------------------------------------------------

func test_population_has_leader_group() -> void:
	for map: MakeshiftStockadeMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_eq(_count_role(map, MakeshiftStockadeMapData.PopRole.LEADER_GROUP), 1,
			"Exactly 1 LEADER_GROUP")


func test_population_has_gate_guards() -> void:
	for map: MakeshiftStockadeMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_true(_count_role(map, MakeshiftStockadeMapData.PopRole.GATE_GUARD) >= 2,
			"At least 2 GATE_GUARD slots")


func test_population_has_wall_watchers() -> void:
	for map: MakeshiftStockadeMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_true(_count_role(map, MakeshiftStockadeMapData.PopRole.WALL_WATCHER) >= 1,
			"At least 1 WALL_WATCHER slot")


func test_population_has_camp_group() -> void:
	for map: MakeshiftStockadeMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_true(_count_role(map, MakeshiftStockadeMapData.PopRole.CAMP_GROUP) >= 1,
			"At least 1 CAMP_GROUP slot")


func test_population_no_zone_field() -> void:
	# Stockade is single-zone: population_slots should have no "zone" key.
	for map: MakeshiftStockadeMapData in [_make_small(), _make_medium(), _make_large()]:
		for slot: Dictionary in map.population_slots:
			assert_false(slot.has("zone"),
				"Single-zone stockade: population slots must not carry a 'zone' field")


func test_watchtower_absent_for_small() -> void:
	assert_eq(_count_role(_make_small(), MakeshiftStockadeMapData.PopRole.WATCHTOWER), 0,
		"SMALL has no platform → no WATCHTOWER slot")


func test_watchtower_present_for_medium() -> void:
	assert_eq(_count_role(_make_medium(), MakeshiftStockadeMapData.PopRole.WATCHTOWER), 1,
		"MEDIUM has a platform → 1 WATCHTOWER slot")


# ---------------------------------------------------------------------------
# Objectives
# ---------------------------------------------------------------------------

func test_kill_leader_objective_present() -> void:
	var map := _make_small()
	var found: bool = false
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == MakeshiftStockadeMapData.ObjType.KILL_LEADER:
			found = true
	assert_true(found, "KILL_LEADER objective slot should be present")


func test_kill_leader_at_command_shelter() -> void:
	var map := _make_small()
	var cmd_id: int = -1
	for sh: Dictionary in map.shelters:
		if sh["type"] == MakeshiftStockadeMapData.ShelterType.COMMAND:
			cmd_id = sh["id"]
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == MakeshiftStockadeMapData.ObjType.KILL_LEADER:
			assert_eq(obj["shelter_id"], cmd_id,
				"KILL_LEADER should reference the COMMAND shelter")


func test_burn_camp_one_marker_per_shelter() -> void:
	var map: MakeshiftStockadeMapData = MakeshiftStockadeGenerator.generate(
		"burn_test", 5, [MakeshiftStockadeMapData.ObjType.BURN_CAMP])
	var burn_count: int = 0
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == MakeshiftStockadeMapData.ObjType.BURN_CAMP:
			burn_count += 1
	assert_eq(burn_count, map.shelters.size(),
		"BURN_CAMP should have one marker per shelter")


func test_rescue_hostages_objective_present() -> void:
	var map: MakeshiftStockadeMapData = MakeshiftStockadeGenerator.generate(
		"rescue_test", 5, [MakeshiftStockadeMapData.ObjType.RESCUE_HOSTAGES])
	var found: bool = false
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == MakeshiftStockadeMapData.ObjType.RESCUE_HOSTAGES:
			found = true
	assert_true(found, "RESCUE_HOSTAGES objective should be placed")


# ---------------------------------------------------------------------------
# Ditch
# ---------------------------------------------------------------------------

func test_small_never_has_ditch() -> void:
	for i: int in range(20):
		var map: MakeshiftStockadeMapData = MakeshiftStockadeGenerator.generate(
			"ditch_small_%d" % i, 2, [])
		if map.size_category != MakeshiftStockadeMapData.SizeCategory.SMALL:
			continue
		assert_false(map.has_ditch, "SMALL should never have a ditch")


func test_large_always_has_ditch() -> void:
	for i: int in range(10):
		var map: MakeshiftStockadeMapData = MakeshiftStockadeGenerator.generate(
			"ditch_large_%d" % i, 8, [])
		assert_true(map.has_ditch, "LARGE should always have a ditch")


func test_large_ditch_tiles_present() -> void:
	var map := _make_large()
	assert_true(map.has_ditch)
	# North ditch row is 1 tile above the north wall.
	var ditch_y: int = map.perim_ty - 1
	assert_eq(map.get_tile(map.perim_lx, ditch_y), Enums.TileType.WATER_SHALLOW,
		"North ditch tile should be WATER_SHALLOW")


func test_large_ditch_gate_gap_preserved() -> void:
	var map := _make_large()
	assert_true(map.has_ditch)
	# South ditch row is perim_by+1. Gate columns must remain passable (not ditch).
	var ditch_y: int = map.perim_by + 1
	var gate_tile: int = map.get_tile(map.gate_x, ditch_y)
	assert_ne(gate_tile, Enums.TileType.WATER_SHALLOW,
		"Ditch should have a gap at gate_x so the gate is accessible")


# ---------------------------------------------------------------------------
# Size selection
# ---------------------------------------------------------------------------

func test_strength_floor_forces_medium() -> void:
	# Strength 4 exceeds SMALL max (3), so it must be at least MEDIUM.
	for i: int in range(10):
		var map: MakeshiftStockadeMapData = MakeshiftStockadeGenerator.generate(
			"floor_test_%d" % i, 4, [])
		assert_true(map.size_category >= MakeshiftStockadeMapData.SizeCategory.MEDIUM,
			"Strength 4 should never produce SMALL")


func test_strength_7_always_large() -> void:
	for i: int in range(5):
		var map: MakeshiftStockadeMapData = MakeshiftStockadeGenerator.generate(
			"large_test_%d" % i, 7, [])
		assert_eq(map.size_category, MakeshiftStockadeMapData.SizeCategory.LARGE,
			"Strength 7 should always produce LARGE")


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

func test_same_seed_same_map() -> void:
	var a := _make_medium("det_seed")
	var b := _make_medium("det_seed")
	assert_eq(a.gate_x,       b.gate_x,       "gate_x must be deterministic")
	assert_eq(a.perim_lx,     b.perim_lx,     "perim_lx must be deterministic")
	assert_eq(a.shelters.size(), b.shelters.size(), "shelter count must be deterministic")
	assert_eq(a.weak_points.size(), b.weak_points.size())
	assert_eq(a.get_tile(a.width / 2, a.height / 2),
		b.get_tile(b.width / 2, b.height / 2),
		"Centre tile must be deterministic")


func test_different_seeds_different_maps() -> void:
	var a := _make_small("seed_alpha")
	var b := _make_small("seed_beta")
	# At least one of several interior features should differ.
	var weak_differ: bool = a.weak_points[0]["y"] != b.weak_points[0]["y"]
	var firepit_differ: bool = a.firepits[0]["y"] != b.firepits[0]["y"]
	assert_true(weak_differ or firepit_differ,
		"Different seeds should produce different layouts")
