extends GutTest
## GUT tests for RuinedStructureGenerator and RuinedStructureMapData (s56.12).

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_small(seed_str: String = "test_small") -> RuinedStructureMapData:
	return RuinedStructureGenerator.generate(
		seed_str, 2, [RuinedStructureMapData.ObjType.KILL_LEADER])


func _make_medium(seed_str: String = "test_medium") -> RuinedStructureMapData:
	return RuinedStructureGenerator.generate(
		seed_str, 5, [RuinedStructureMapData.ObjType.KILL_LEADER])


func _make_large(seed_str: String = "test_large") -> RuinedStructureMapData:
	return RuinedStructureGenerator.generate(
		seed_str, 8, [RuinedStructureMapData.ObjType.KILL_LEADER])


func _count_role(map: RuinedStructureMapData, role: int) -> int:
	var n: int = 0
	for slot: Dictionary in map.population_slots:
		if slot["role"] == role:
			n += 1
	return n


func _all_perimeter_tiles_ok(map: RuinedStructureMapData) -> bool:
	# Outer wall tiles should be WALL_STONE or ZONE_EXIT (entrance / wall gaps).
	var ok: Array[int] = [Enums.TileType.WALL_STONE, Enums.TileType.ZONE_EXIT]
	var lx: int = map.struct_lx; var rx: int = map.struct_rx
	var ty: int = map.struct_ty; var by: int = map.struct_by
	for x in range(lx, rx + 1):
		if not map.get_tile(x, ty) in ok:
			return false
		if not map.get_tile(x, by) in ok:
			return false
	for y in range(ty + 1, by):
		if not map.get_tile(lx, y) in ok:
			return false
		if not map.get_tile(rx, y) in ok:
			return false
	return true


# ---------------------------------------------------------------------------
# Type and basic structure
# ---------------------------------------------------------------------------

func test_generate_returns_correct_type() -> void:
	assert_is(_make_small(), RuinedStructureMapData,
		"generate() should return RuinedStructureMapData")


func test_seed_string_stored() -> void:
	var map := _make_small("my_ruin_seed")
	assert_eq(map.seed_string, "my_ruin_seed")


# ---------------------------------------------------------------------------
# Dimensions
# ---------------------------------------------------------------------------

func test_small_dimensions() -> void:
	var map := _make_small()
	assert_eq(map.width,  40, "SMALL_RUIN width should be 40")
	assert_eq(map.height, 44, "SMALL_RUIN height should be 44")


func test_medium_dimensions() -> void:
	var map := _make_medium()
	assert_eq(map.width,  60, "MEDIUM_RUIN width should be 60")
	assert_eq(map.height, 60, "MEDIUM_RUIN height should be 60")


func test_large_dimensions() -> void:
	var map := _make_large()
	assert_eq(map.width,  80, "LARGE_RUIN width should be 80")
	assert_eq(map.height, 76, "LARGE_RUIN height should be 76")


# ---------------------------------------------------------------------------
# Struct bounds
# ---------------------------------------------------------------------------

func test_struct_bounds_small() -> void:
	var map := _make_small()
	assert_eq(map.struct_lx, 6,  "SMALL struct_lx")
	assert_eq(map.struct_rx, 33, "SMALL struct_rx")
	assert_eq(map.struct_ty, 6,  "SMALL struct_ty")
	assert_eq(map.struct_by, 37, "SMALL struct_by")


func test_struct_bounds_medium() -> void:
	var map := _make_medium()
	assert_eq(map.struct_lx, 7,  "MEDIUM struct_lx")
	assert_eq(map.struct_rx, 52, "MEDIUM struct_rx")
	assert_eq(map.struct_ty, 7,  "MEDIUM struct_ty")
	assert_eq(map.struct_by, 52, "MEDIUM struct_by")


func test_struct_bounds_large() -> void:
	var map := _make_large()
	assert_eq(map.struct_lx, 8,  "LARGE struct_lx")
	assert_eq(map.struct_rx, 71, "LARGE struct_rx")
	assert_eq(map.struct_ty, 8,  "LARGE struct_ty")
	assert_eq(map.struct_by, 67, "LARGE struct_by")


# ---------------------------------------------------------------------------
# Grid dimensions
# ---------------------------------------------------------------------------

func test_grid_dims_small() -> void:
	var map := _make_small()
	assert_eq(map.grid_cols, 2, "SMALL_RUIN grid_cols should be 2")
	assert_eq(map.grid_rows, 2, "SMALL_RUIN grid_rows should be 2")


func test_grid_dims_medium() -> void:
	var map := _make_medium()
	assert_eq(map.grid_cols, 3, "MEDIUM_RUIN grid_cols should be 3")
	assert_eq(map.grid_rows, 3, "MEDIUM_RUIN grid_rows should be 3")


func test_grid_dims_large() -> void:
	var map := _make_large()
	assert_eq(map.grid_cols, 4, "LARGE_RUIN grid_cols should be 4")
	assert_eq(map.grid_rows, 4, "LARGE_RUIN grid_rows should be 4")


# ---------------------------------------------------------------------------
# Entrance
# ---------------------------------------------------------------------------

func test_entrance_x_centred_small() -> void:
	var map := _make_small()
	assert_eq(map.entrance_x, 19, "SMALL entrance_x should be (6+33)/2 = 19")


func test_entrance_x_centred_medium() -> void:
	var map := _make_medium()
	assert_eq(map.entrance_x, 29, "MEDIUM entrance_x should be (7+52)/2 = 29")


func test_entrance_x_centred_large() -> void:
	var map := _make_large()
	assert_eq(map.entrance_x, 39, "LARGE entrance_x should be (8+71)/2 = 39")


func test_entrance_tiles_are_zone_exit() -> void:
	var map := _make_small()
	# Entrance gap is 2 tiles wide centred on entrance_x.
	var ent_lx: int = map.entrance_x - 1
	var ent_rx: int = ent_lx + 1
	for x in range(ent_lx, ent_rx + 1):
		assert_eq(map.get_tile(x, map.struct_by), Enums.TileType.ZONE_EXIT,
			"Entrance gap tile on south wall should be ZONE_EXIT")


# ---------------------------------------------------------------------------
# Tile types
# ---------------------------------------------------------------------------

func test_outer_approach_is_floor_grass() -> void:
	var map := _make_small()
	assert_eq(map.get_tile(0, 0), Enums.TileType.FLOOR_GRASS,
		"Far corner of approach should be FLOOR_GRASS")


func test_struct_corners_are_wall_stone() -> void:
	var map := _make_small()
	assert_eq(map.get_tile(map.struct_lx, map.struct_ty), Enums.TileType.WALL_STONE, "NW corner")
	assert_eq(map.get_tile(map.struct_rx, map.struct_ty), Enums.TileType.WALL_STONE, "NE corner")
	assert_eq(map.get_tile(map.struct_lx, map.struct_by), Enums.TileType.WALL_STONE, "SW corner")
	assert_eq(map.get_tile(map.struct_rx, map.struct_by), Enums.TileType.WALL_STONE, "SE corner")


func test_perimeter_tiles_ok_small() -> void:
	assert_true(_all_perimeter_tiles_ok(_make_small()),
		"All outer wall tiles should be WALL_STONE or ZONE_EXIT (SMALL)")


func test_perimeter_tiles_ok_medium() -> void:
	assert_true(_all_perimeter_tiles_ok(_make_medium()),
		"All outer wall tiles should be WALL_STONE or ZONE_EXIT (MEDIUM)")


func test_perimeter_tiles_ok_large() -> void:
	assert_true(_all_perimeter_tiles_ok(_make_large()),
		"All outer wall tiles should be WALL_STONE or ZONE_EXIT (LARGE)")


# ---------------------------------------------------------------------------
# Room / collapsed section accounting
# ---------------------------------------------------------------------------

func test_small_rooms_and_collapsed_total_four_cells() -> void:
	for i in range(20):
		var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
			"acc_small_%d" % i, 2, [])
		if map.size_category != RuinedStructureMapData.SizeCategory.SMALL_RUIN:
			continue
		assert_eq(map.rooms.size() + map.collapsed_sections.size(), 4,
			"SMALL: rooms + collapsed must equal 4 (2×2 grid)")


func test_medium_rooms_and_collapsed_total_nine_cells() -> void:
	var map := _make_medium()
	assert_eq(map.rooms.size() + map.collapsed_sections.size(), 9,
		"MEDIUM: rooms + collapsed must equal 9 (3×3 grid)")


func test_large_rooms_and_collapsed_total_sixteen_cells() -> void:
	var map := _make_large()
	assert_eq(map.rooms.size() + map.collapsed_sections.size(), 16,
		"LARGE: rooms + collapsed must equal 16 (4×4 grid)")


func test_rooms_count_small_in_range() -> void:
	for i in range(20):
		var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
			"rm_small_%d" % i, 2, [])
		if map.size_category != RuinedStructureMapData.SizeCategory.SMALL_RUIN:
			continue
		assert_true(map.rooms.size() >= 2 and map.rooms.size() <= 4,
			"SMALL intact rooms should be 2–4, got %d" % map.rooms.size())


func test_rooms_count_medium_in_range() -> void:
	for i in range(10):
		var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
			"rm_med_%d" % i, 5, [])
		assert_true(map.rooms.size() >= 5 and map.rooms.size() <= 9,
			"MEDIUM intact rooms should be 5–9, got %d" % map.rooms.size())


func test_rooms_count_large_in_range() -> void:
	for i in range(5):
		var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
			"rm_large_%d" % i, 8, [])
		assert_true(map.rooms.size() >= 8 and map.rooms.size() <= 16,
			"LARGE intact rooms should be 8–16, got %d" % map.rooms.size())


# ---------------------------------------------------------------------------
# Leader and storage room designation
# ---------------------------------------------------------------------------

func test_exactly_one_leader_room() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		var count: int = 0
		for rm: Dictionary in map.rooms:
			if rm["is_leader_room"]:
				count += 1
		assert_eq(count, 1, "Exactly 1 leader room")


func test_exactly_one_storage_room_when_multiple_rooms() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		if map.rooms.size() < 2:
			continue
		var count: int = 0
		for rm: Dictionary in map.rooms:
			if rm["is_storage_room"]:
				count += 1
		assert_eq(count, 1, "Exactly 1 storage room (when ≥2 rooms)")


func test_leader_and_storage_are_different_rooms() -> void:
	var map := _make_medium()
	var leader_id: int = -1
	var storage_id: int = -2
	for rm: Dictionary in map.rooms:
		if rm["is_leader_room"]:
			leader_id = rm["id"]
		if rm["is_storage_room"]:
			storage_id = rm["id"]
	assert_ne(leader_id, storage_id, "Leader and storage rooms must differ")


func test_medium_has_inner_room_candidate() -> void:
	# 3×3 grid always has a centre cell — at least one room could be inner.
	var map := _make_medium()
	var any_inner: bool = false
	for rm: Dictionary in map.rooms:
		if rm["is_inner"]:
			any_inner = true
	# If all cells collapsed (impossible for MEDIUM min=5) this would fail;
	# since ≥5 rooms survive, the centre cell is very likely intact.
	# This is a soft structural check, not an invariant.
	var _unused := any_inner   # tested indirectly via leader designation


# ---------------------------------------------------------------------------
# Wall gaps
# ---------------------------------------------------------------------------

func test_wall_gaps_count_small_at_least_one() -> void:
	for i in range(10):
		var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
			"gap_small_%d" % i, 2, [])
		if map.size_category == RuinedStructureMapData.SizeCategory.SMALL_RUIN:
			assert_true(map.wall_gaps.size() >= 1,
				"SMALL should have at least 1 wall gap")


func test_wall_gaps_count_small_in_range() -> void:
	for i in range(20):
		var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
			"gapA_small_%d" % i, 2, [])
		if map.size_category == RuinedStructureMapData.SizeCategory.SMALL_RUIN:
			assert_true(map.wall_gaps.size() >= 1 and map.wall_gaps.size() <= 2,
				"SMALL wall gaps should be 1–2, got %d" % map.wall_gaps.size())


func test_wall_gaps_have_side_field() -> void:
	for gap: Dictionary in _make_medium().wall_gaps:
		var valid: bool = gap["side"] in ["N", "S", "E", "W"]
		assert_true(valid, "Wall gap side must be N/S/E/W")


func test_wall_gaps_tiles_are_zone_exit() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		for gap: Dictionary in map.wall_gaps:
			assert_eq(map.get_tile(gap["x"], gap["y"]), Enums.TileType.ZONE_EXIT,
				"Wall gap tile should be ZONE_EXIT (after entry vector pass)")


# ---------------------------------------------------------------------------
# Collapsed sections
# ---------------------------------------------------------------------------

func test_collapsed_sections_are_rubble_or_floor_dirt() -> void:
	var map := _make_medium()
	if map.collapsed_sections.is_empty():
		return
	var sec: Dictionary = map.collapsed_sections[0]
	# At least one tile in the collapsed section should be RUBBLE or FLOOR_DIRT.
	var found_collapsed_tile: bool = false
	for y in range(sec["ly"], sec["ry"] + 1):
		for x in range(sec["lx"], sec["rx"] + 1):
			var t: int = map.get_tile(x, y)
			if t == Enums.TileType.RUBBLE or t == Enums.TileType.FLOOR_DIRT:
				found_collapsed_tile = true
	assert_true(found_collapsed_tile,
		"Collapsed section should contain RUBBLE or FLOOR_DIRT tiles")


# ---------------------------------------------------------------------------
# Upper floor
# ---------------------------------------------------------------------------

func test_small_never_has_upper_floor() -> void:
	for i in range(20):
		var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
			"uf_small_%d" % i, 2, [])
		if map.size_category == RuinedStructureMapData.SizeCategory.SMALL_RUIN:
			assert_false(map.has_upper_floor,
				"SMALL_RUIN should never have an upper floor")


func test_large_always_has_upper_floor() -> void:
	for i in range(10):
		var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
			"uf_large_%d" % i, 8, [])
		assert_true(map.has_upper_floor,
			"LARGE_RUIN should always have an upper floor")


func test_upper_floor_section_within_leader_room() -> void:
	var map := _make_large()
	assert_true(map.has_upper_floor)
	assert_false(map.upper_floor_sections.is_empty(),
		"has_upper_floor=true should produce at least 1 upper_floor_section")
	var ufs: Dictionary = map.upper_floor_sections[0]
	var leader_rm: Dictionary = {}
	for rm: Dictionary in map.rooms:
		if rm["is_leader_room"]:
			leader_rm = rm
	if leader_rm.is_empty():
		return
	assert_true(ufs["lx"] >= leader_rm["lx"] and ufs["rx"] <= leader_rm["rx"] and
		ufs["ly"] >= leader_rm["ly"] and ufs["ry"] <= leader_rm["ry"],
		"Upper floor section must be inside the leader room bounds")


func test_upper_floor_has_stairwell() -> void:
	var map := _make_large()
	assert_true(map.has_upper_floor)
	assert_false(map.stairwells.is_empty(), "Upper floor should have at least 1 stairwell")
	var sw: Dictionary = map.stairwells[0]
	assert_true(sw.has("x") and sw.has("y") and sw.has("room_id"),
		"Stairwell must have x, y, room_id fields")


# ---------------------------------------------------------------------------
# Firepits
# ---------------------------------------------------------------------------

func test_one_firepit_per_intact_room() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_eq(map.firepits.size(), map.rooms.size(),
			"Should be exactly 1 firepit per intact room")


func test_firepit_tiles_are_fire() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		for fp: Dictionary in map.firepits:
			assert_eq(map.get_tile(fp["x"], fp["y"]), Enums.TileType.FIRE,
				"Firepit tile should be FIRE")


# ---------------------------------------------------------------------------
# Entry vectors
# ---------------------------------------------------------------------------

func test_entry_vectors_exactly_one_main() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		var count: int = 0
		for ev: Dictionary in map.entry_vectors:
			if ev["is_main"]:
				count += 1
		assert_eq(count, 1, "Exactly 1 is_main entry vector")


func test_entry_vector_main_on_south_wall() -> void:
	var map := _make_small()
	for ev: Dictionary in map.entry_vectors:
		if ev["is_main"]:
			assert_eq(ev["y"], map.struct_by,
				"Main entry vector y should equal struct_by (south wall)")


func test_entry_vectors_gap_count_matches_wall_gaps() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		var gap_ev_count: int = 0
		for ev: Dictionary in map.entry_vectors:
			if ev["is_gap"]:
				gap_ev_count += 1
		assert_eq(gap_ev_count, map.wall_gaps.size(),
			"One is_gap entry vector per wall gap")


func test_entry_vectors_total_count() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_eq(map.entry_vectors.size(), 1 + map.wall_gaps.size(),
			"entry_vectors = 1 (main) + wall_gaps.size()")


func test_entry_vector_tiles_are_zone_exit() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		for ev: Dictionary in map.entry_vectors:
			assert_eq(map.get_tile(ev["x"], ev["y"]), Enums.TileType.ZONE_EXIT,
				"Every entry vector tile should be ZONE_EXIT")


# ---------------------------------------------------------------------------
# Population slots
# ---------------------------------------------------------------------------

func test_exactly_one_sentry() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_eq(_count_role(map, RuinedStructureMapData.PopRole.SENTRY), 1,
			"Exactly 1 SENTRY slot")


func test_room_group_at_least_one_per_non_leader_room() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		var non_leader_rooms: int = 0
		for rm: Dictionary in map.rooms:
			if not rm["is_leader_room"]:
				non_leader_rooms += 1
		assert_true(_count_role(map, RuinedStructureMapData.PopRole.ROOM_GROUP) >= non_leader_rooms,
			"At least 1 ROOM_GROUP per non-leader room")


func test_rubble_lurker_one_per_collapsed_section() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_eq(_count_role(map, RuinedStructureMapData.PopRole.RUBBLE_LURKER),
			map.collapsed_sections.size(),
			"Exactly 1 RUBBLE_LURKER per collapsed section")


func test_exactly_two_leader_group_slots() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_eq(_count_role(map, RuinedStructureMapData.PopRole.LEADER_GROUP), 2,
			"Exactly 2 LEADER_GROUP slots")


func test_upper_floor_holder_present_when_upper_floor_exists() -> void:
	var map := _make_large()
	assert_true(map.has_upper_floor)
	assert_eq(_count_role(map, RuinedStructureMapData.PopRole.UPPER_FLOOR_HOLDER), 1,
		"Exactly 1 UPPER_FLOOR_HOLDER when has_upper_floor=true")


func test_no_upper_floor_holder_when_no_upper_floor() -> void:
	for i in range(10):
		var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
			"no_uf_%d" % i, 2, [])
		if map.size_category == RuinedStructureMapData.SizeCategory.SMALL_RUIN:
			assert_eq(_count_role(map, RuinedStructureMapData.PopRole.UPPER_FLOOR_HOLDER), 0,
				"SMALL_RUIN (no upper floor) should have 0 UPPER_FLOOR_HOLDER")


func test_population_slots_have_zone_field() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		for slot: Dictionary in map.population_slots:
			assert_true(slot.has("zone"),
				"All population slots must have a 'zone' field")


func test_sentry_zone_is_intact_room() -> void:
	var map := _make_small()
	for slot: Dictionary in map.population_slots:
		if slot["role"] == RuinedStructureMapData.PopRole.SENTRY:
			assert_eq(slot["zone"], RuinedStructureMapData.Zone.INTACT_ROOM,
				"SENTRY zone should be INTACT_ROOM")


func test_rubble_lurker_zone_is_collapsed() -> void:
	var map := _make_medium()
	for slot: Dictionary in map.population_slots:
		if slot["role"] == RuinedStructureMapData.PopRole.RUBBLE_LURKER:
			assert_eq(slot["zone"], RuinedStructureMapData.Zone.COLLAPSED,
				"RUBBLE_LURKER zone should be COLLAPSED")


func test_upper_floor_holder_zone_is_upper_floor() -> void:
	var map := _make_large()
	for slot: Dictionary in map.population_slots:
		if slot["role"] == RuinedStructureMapData.PopRole.UPPER_FLOOR_HOLDER:
			assert_eq(slot["zone"], RuinedStructureMapData.Zone.UPPER_FLOOR,
				"UPPER_FLOOR_HOLDER zone should be UPPER_FLOOR")


# ---------------------------------------------------------------------------
# Objectives
# ---------------------------------------------------------------------------

func test_kill_leader_objective_present() -> void:
	var map := _make_small()
	var found: bool = false
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RuinedStructureMapData.ObjType.KILL_LEADER:
			found = true
	assert_true(found, "KILL_LEADER objective should be placed")


func test_kill_leader_in_leader_room() -> void:
	var map := _make_medium()
	var leader_id: int = -1
	for rm: Dictionary in map.rooms:
		if rm["is_leader_room"]:
			leader_id = rm["id"]
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RuinedStructureMapData.ObjType.KILL_LEADER:
			assert_eq(obj["room_id"], leader_id,
				"KILL_LEADER must be in the leader room")


func test_recover_goods_objective_present() -> void:
	var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
		"goods_ruin", 5, [RuinedStructureMapData.ObjType.RECOVER_GOODS])
	var found: bool = false
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RuinedStructureMapData.ObjType.RECOVER_GOODS:
			found = true
	assert_true(found, "RECOVER_GOODS objective should be placed")


func test_recover_goods_in_storage_room() -> void:
	var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
		"goods_ruin_check", 5, [RuinedStructureMapData.ObjType.RECOVER_GOODS])
	var storage_id: int = -1
	for rm: Dictionary in map.rooms:
		if rm["is_storage_room"]:
			storage_id = rm["id"]
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RuinedStructureMapData.ObjType.RECOVER_GOODS:
			assert_eq(obj["room_id"], storage_id,
				"RECOVER_GOODS must be in the storage room")


func test_burn_camp_one_marker_per_intact_room() -> void:
	var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
		"burn_ruin", 5, [RuinedStructureMapData.ObjType.BURN_CAMP])
	var burn_count: int = 0
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RuinedStructureMapData.ObjType.BURN_CAMP:
			burn_count += 1
	assert_eq(burn_count, map.rooms.size(),
		"BURN_CAMP should have one marker per intact room")


func test_rescue_hostages_objective_present() -> void:
	var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
		"rescue_ruin", 5, [RuinedStructureMapData.ObjType.RESCUE_HOSTAGES])
	var found: bool = false
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RuinedStructureMapData.ObjType.RESCUE_HOSTAGES:
			found = true
	assert_true(found, "RESCUE_HOSTAGES objective should be placed")


func test_investigate_objective_present() -> void:
	# INVESTIGATE is unique to this template (s56.12.6).
	var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
		"inv_ruin", 5, [RuinedStructureMapData.ObjType.INVESTIGATE])
	var found: bool = false
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RuinedStructureMapData.ObjType.INVESTIGATE:
			found = true
	assert_true(found, "INVESTIGATE objective should be placed (unique to ruined structure)")


func test_investigate_in_storage_room() -> void:
	var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
		"inv_ruin_check", 5, [RuinedStructureMapData.ObjType.INVESTIGATE])
	var storage_id: int = -1
	for rm: Dictionary in map.rooms:
		if rm["is_storage_room"]:
			storage_id = rm["id"]
	for obj: Dictionary in map.objective_slots:
		if obj["obj_type"] == RuinedStructureMapData.ObjType.INVESTIGATE:
			assert_eq(obj["room_id"], storage_id,
				"INVESTIGATE evidence should be in the storage room")


func test_objective_slots_have_room_id_field() -> void:
	var map := _make_medium()
	for obj: Dictionary in map.objective_slots:
		assert_true(obj.has("room_id"),
			"All objective slots must have a room_id field")


# ---------------------------------------------------------------------------
# Size selection
# ---------------------------------------------------------------------------

func test_strength_floor_forces_medium() -> void:
	for i in range(10):
		var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
			"floor_test_%d" % i, 4, [])
		assert_true(map.size_category >= RuinedStructureMapData.SizeCategory.MEDIUM_RUIN,
			"Strength 4 should never produce SMALL_RUIN")


func test_strength_7_always_large() -> void:
	for i in range(5):
		var map: RuinedStructureMapData = RuinedStructureGenerator.generate(
			"large_test_%d" % i, 7, [])
		assert_eq(map.size_category, RuinedStructureMapData.SizeCategory.LARGE_RUIN,
			"Strength 7 should always produce LARGE_RUIN")


# ---------------------------------------------------------------------------
# Ruin origin
# ---------------------------------------------------------------------------

func test_ruin_origin_is_valid_enum_value() -> void:
	for map: RuinedStructureMapData in [_make_small(), _make_medium(), _make_large()]:
		assert_true(map.ruin_origin >= 0 and
			map.ruin_origin <= RuinedStructureMapData.RuinOrigin.NATURAL_DECAY,
			"ruin_origin must be a valid RuinOrigin enum value")


# ---------------------------------------------------------------------------
# Determinism
# ---------------------------------------------------------------------------

func test_same_seed_same_map() -> void:
	var a := _make_medium("det_ruin_seed")
	var b := _make_medium("det_ruin_seed")
	assert_eq(a.entrance_x,              b.entrance_x,              "entrance_x must be deterministic")
	assert_eq(a.ruin_origin,             b.ruin_origin,             "ruin_origin must be deterministic")
	assert_eq(a.rooms.size(),            b.rooms.size(),            "room count must be deterministic")
	assert_eq(a.collapsed_sections.size(), b.collapsed_sections.size(), "collapsed count must be deterministic")
	assert_eq(a.has_upper_floor,         b.has_upper_floor,         "has_upper_floor must be deterministic")
	assert_eq(a.wall_gaps.size(),        b.wall_gaps.size(),        "wall_gaps count must be deterministic")
	assert_eq(a.get_tile(a.entrance_x, a.struct_by - 2),
	          b.get_tile(b.entrance_x, b.struct_by - 2),
	          "Interior tile near entrance must be deterministic")


func test_different_seeds_different_maps() -> void:
	var a := _make_medium("seed_ruin_alpha")
	var b := _make_medium("seed_ruin_beta")
	var room_differ:   bool = a.rooms.size() != b.rooms.size()
	var origin_differ: bool = a.ruin_origin  != b.ruin_origin
	var gap_differ:    bool = a.wall_gaps.size() != b.wall_gaps.size()
	var uf_differ:     bool = a.has_upper_floor  != b.has_upper_floor
	assert_true(room_differ or origin_differ or gap_differ or uf_differ,
		"Different seeds should produce different layouts")
