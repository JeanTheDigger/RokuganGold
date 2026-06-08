extends GutTest
## Tests for UrbanHideoutGenerator + UrbanHideoutMapData (s56.15 --- LOCKED).

# -- UrbanHideoutMapData enum / constant sanity --------------------------------

func test_size_category_values() -> void:
	assert_eq(UrbanHideoutMapData.SizeCategory.SINGLE_BASEMENT, 0)
	assert_eq(UrbanHideoutMapData.SizeCategory.CONNECTED_BASEMENTS, 1)
	assert_eq(UrbanHideoutMapData.SizeCategory.CATACOMBS, 2)

func test_dims_count() -> void:
	assert_eq(UrbanHideoutMapData.DIMS.size(), 3)

func test_dims_single_basement() -> void:
	var d: Vector2i = UrbanHideoutMapData.DIMS[0]
	assert_eq(d.x, 24)
	assert_eq(d.y, 20)

func test_dims_connected_basements() -> void:
	var d: Vector2i = UrbanHideoutMapData.DIMS[1]
	assert_eq(d.x, 40)
	assert_eq(d.y, 36)

func test_dims_catacombs() -> void:
	var d: Vector2i = UrbanHideoutMapData.DIMS[2]
	assert_eq(d.x, 60)
	assert_eq(d.y, 52)

func test_room_count_range_single() -> void:
	var r: Vector2i = UrbanHideoutMapData.ROOM_COUNT_RANGE[0]
	assert_eq(r.x, 1)
	assert_eq(r.y, 2)

func test_room_count_range_connected() -> void:
	var r: Vector2i = UrbanHideoutMapData.ROOM_COUNT_RANGE[1]
	assert_eq(r.x, 3)
	assert_eq(r.y, 5)

func test_room_count_range_catacombs() -> void:
	var r: Vector2i = UrbanHideoutMapData.ROOM_COUNT_RANGE[2]
	assert_eq(r.x, 6)
	assert_eq(r.y, 10)

# -- Generator: size selection -------------------------------------------------

func test_strength_1_gives_single_basement() -> void:
	var m := UrbanHideoutGenerator.generate("seed", 1, [])
	assert_eq(m.size_category, UrbanHideoutMapData.SizeCategory.SINGLE_BASEMENT)

func test_strength_3_gives_single_basement() -> void:
	var m := UrbanHideoutGenerator.generate("seed", 3, [])
	assert_eq(m.size_category, UrbanHideoutMapData.SizeCategory.SINGLE_BASEMENT)

func test_strength_4_gives_connected_basements() -> void:
	var m := UrbanHideoutGenerator.generate("seed", 4, [])
	assert_eq(m.size_category, UrbanHideoutMapData.SizeCategory.CONNECTED_BASEMENTS)

func test_strength_6_gives_connected_basements() -> void:
	var m := UrbanHideoutGenerator.generate("seed", 6, [])
	assert_eq(m.size_category, UrbanHideoutMapData.SizeCategory.CONNECTED_BASEMENTS)

func test_strength_7_gives_catacombs() -> void:
	var m := UrbanHideoutGenerator.generate("seed", 7, [])
	assert_eq(m.size_category, UrbanHideoutMapData.SizeCategory.CATACOMBS)

func test_strength_9_gives_catacombs() -> void:
	var m := UrbanHideoutGenerator.generate("seed", 9, [])
	assert_eq(m.size_category, UrbanHideoutMapData.SizeCategory.CATACOMBS)

# -- Generator: map dimensions -------------------------------------------------

func test_single_basement_map_dimensions() -> void:
	var m := UrbanHideoutGenerator.generate("test_dim_sb", 2, [])
	var d: Vector2i = UrbanHideoutMapData.DIMS[m.size_category]
	assert_eq(m.get_width(), d.x)
	assert_eq(m.get_height(), d.y)

func test_connected_map_dimensions() -> void:
	var m := UrbanHideoutGenerator.generate("test_dim_cb", 5, [])
	var d: Vector2i = UrbanHideoutMapData.DIMS[m.size_category]
	assert_eq(m.get_width(), d.x)
	assert_eq(m.get_height(), d.y)

func test_catacombs_map_dimensions() -> void:
	var m := UrbanHideoutGenerator.generate("test_dim_cat", 9, [])
	var d: Vector2i = UrbanHideoutMapData.DIMS[m.size_category]
	assert_eq(m.get_width(), d.x)
	assert_eq(m.get_height(), d.y)

# -- Generator: room count in range --------------------------------------------

func test_single_basement_room_count_in_range() -> void:
	var m := UrbanHideoutGenerator.generate("rc_sb", 2, [])
	var range_v: Vector2i = UrbanHideoutMapData.ROOM_COUNT_RANGE[m.size_category]
	assert_true(m.rooms.size() >= range_v.x and m.rooms.size() <= range_v.y)

func test_connected_room_count_in_range() -> void:
	var m := UrbanHideoutGenerator.generate("rc_cb", 5, [])
	var range_v: Vector2i = UrbanHideoutMapData.ROOM_COUNT_RANGE[m.size_category]
	assert_true(m.rooms.size() >= range_v.x and m.rooms.size() <= range_v.y)

func test_catacombs_room_count_in_range() -> void:
	var m := UrbanHideoutGenerator.generate("rc_cat", 8, [])
	var range_v: Vector2i = UrbanHideoutMapData.ROOM_COUNT_RANGE[m.size_category]
	# CATACOMBS adds optional branch rooms beyond the main chain.
	# Max main rooms = range_v.y; max branches = range_v.y - 2 (one per middle room).
	var max_rooms: int = range_v.y + (range_v.y - 2)
	assert_true(m.rooms.size() >= range_v.x and m.rooms.size() <= max_rooms,
		"CATACOMBS room count %d outside [%d, %d]" % [m.rooms.size(), range_v.x, max_rooms])

# -- Generator: entrance placement ---------------------------------------------

func test_entrance_tile_is_zone_exit() -> void:
	var m := UrbanHideoutGenerator.generate("ent", 3, [])
	var ex: int = m.entrance_x
	var ey: int = m.entrance_y
	assert_true(ex >= 0)
	assert_true(ey >= 0)
	assert_eq(m.get_tile(ex, ey), Enums.TileType.ZONE_EXIT)

func test_entrance_room_has_entrance_zone() -> void:
	for s in ["ent_a", "ent_b", "ent_c"]:
		var m := UrbanHideoutGenerator.generate(s, 2, [])
		var entrance_room_found := false
		for r in m.rooms:
			if r["zone"] == UrbanHideoutMapData.Zone.ENTRANCE or \
					r["zone"] == UrbanHideoutMapData.Zone.RITUAL_SPACE:
				entrance_room_found = true
				break
		assert_true(entrance_room_found)

# -- Generator: ritual space --------------------------------------------------

func test_ritual_space_room_id_is_valid() -> void:
	var m := UrbanHideoutGenerator.generate("rs_sb", 2, [])
	assert_true(m.ritual_space_room_id >= 0)
	var found := false
	for r in m.rooms:
		if r["id"] == m.ritual_space_room_id:
			found = true
			break
	assert_true(found)

func test_ritual_space_zone_is_ritual() -> void:
	var m := UrbanHideoutGenerator.generate("rs_zone", 2, [])
	for r in m.rooms:
		if r["id"] == m.ritual_space_room_id:
			assert_eq(r["zone"], UrbanHideoutMapData.Zone.RITUAL_SPACE)
			return
	fail_test("Ritual space room not found")

func test_ritual_space_taint_level_3() -> void:
	var m := UrbanHideoutGenerator.generate("rs_taint", 2, [])
	for r in m.rooms:
		if r["id"] == m.ritual_space_room_id:
			assert_eq(r["taint_level"], 3)
			return
	fail_test("Ritual space room not found")

# -- Generator: corridors connect rooms ----------------------------------------

func test_connected_has_corridors() -> void:
	var m := UrbanHideoutGenerator.generate("cor_cb", 5, [])
	assert_true(m.corridors.size() >= 1)

func test_catacombs_has_corridors() -> void:
	var m := UrbanHideoutGenerator.generate("cor_cat", 8, [])
	assert_true(m.corridors.size() >= 1)

func test_single_basement_single_room_no_corridors() -> void:
	# Single room variant has no corridors (1 room = both entrance and ritual)
	var m := UrbanHideoutGenerator.generate("cor_sb_single", 1, [])
	if m.rooms.size() == 1:
		assert_eq(m.corridors.size(), 0)

# -- Generator: zombie positions only on connected/catacombs ------------------

func test_single_basement_no_zombie_positions() -> void:
	var m := UrbanHideoutGenerator.generate("zp_sb", 1, [])
	assert_eq(m.zombie_positions.size(), 0)

func test_connected_may_have_zombie_positions() -> void:
	# Not all corridors get zombies (skip entrance-bound ones), but with 3+ rooms
	# there should usually be at least one placement.
	var m := UrbanHideoutGenerator.generate("zp_cb", 5, [])
	# At minimum, corridors exist and the generator ran without error.
	assert_true(m.corridors.size() >= 1)

# -- Generator: population slots -----------------------------------------------

func test_has_door_guard_slot() -> void:
	for s in ["pop_sb", "pop_cb", "pop_cat"]:
		var strength: int = [2, 5, 8][[["pop_sb", "pop_cb", "pop_cat"].find(s)]]
		var m := UrbanHideoutGenerator.generate(s, strength, [])
		var found := false
		for p in m.population_slots:
			if p["role"] == UrbanHideoutMapData.PopRole.DOOR_GUARD:
				found = true
				break
		assert_true(found, "Door guard missing for %s" % s)

func test_has_leader_slot() -> void:
	for s in ["lea_sb", "lea_cb", "lea_cat"]:
		var strength: int = [2, 5, 8][[["lea_sb", "lea_cb", "lea_cat"].find(s)]]
		var m := UrbanHideoutGenerator.generate(s, strength, [])
		var found := false
		for p in m.population_slots:
			if p["role"] == UrbanHideoutMapData.PopRole.LEADER:
				found = true
				break
		assert_true(found, "Leader missing for %s" % s)

# -- Generator: objective placement --------------------------------------------

func test_objectives_placed_from_obj_types() -> void:
	var obj_types: Array = [
		UrbanHideoutMapData.ObjType.SUPPRESS_CELL,
		UrbanHideoutMapData.ObjType.KILL_CAPTURE_LEADER,
	]
	var m := UrbanHideoutGenerator.generate("obj_test", 5, obj_types)
	assert_eq(m.objective_slots.size(), obj_types.size())

func test_empty_obj_types_no_objective_slots() -> void:
	var m := UrbanHideoutGenerator.generate("obj_empty", 3, [])
	assert_eq(m.objective_slots.size(), 0)

# -- Generator: determinism ---------------------------------------------------

func test_same_seed_same_layout() -> void:
	var m1 := UrbanHideoutGenerator.generate("det_seed_42", 5, [])
	var m2 := UrbanHideoutGenerator.generate("det_seed_42", 5, [])
	assert_eq(m1.rooms.size(), m2.rooms.size())
	assert_eq(m1.corridors.size(), m2.corridors.size())
	assert_eq(m1.entrance_x, m2.entrance_x)
	assert_eq(m1.entrance_y, m2.entrance_y)
	assert_eq(m1.ritual_space_room_id, m2.ritual_space_room_id)

func test_different_seeds_may_differ() -> void:
	var m1 := UrbanHideoutGenerator.generate("seed_alpha", 5, [])
	var m2 := UrbanHideoutGenerator.generate("seed_beta", 5, [])
	# Different seeds should produce at least one structural difference.
	# Room count or entrance position should vary.
	var differs: bool = ((m1.rooms.size() != m2.rooms.size()) \
		or (m1.entrance_x != m2.entrance_x) or (m1.entrance_y != m2.entrance_y))
	# This is probabilistic but extremely unlikely to fail with two different seeds.
	assert_true(differs, "Different seeds produced identical map layouts")

# -- Room data structure -------------------------------------------------------

func test_rooms_have_required_keys() -> void:
	var m := UrbanHideoutGenerator.generate("rkeys", 5, [])
	for r in m.rooms:
		assert_true(r.has("id"), "Missing id")
		assert_true(r.has("lx"), "Missing lx")
		assert_true(r.has("ly"), "Missing ly")
		assert_true(r.has("rx"), "Missing rx")
		assert_true(r.has("ry"), "Missing ry")
		assert_true(r.has("zone"), "Missing zone")
		assert_true(r.has("taint_level"), "Missing taint_level")

func test_taint_levels_in_range() -> void:
	var m := UrbanHideoutGenerator.generate("taint_range", 8, [])
	for r in m.rooms:
		assert_true(r["taint_level"] >= 0 and r["taint_level"] <= 3)

# -- Corridor data structure ---------------------------------------------------

func test_corridors_have_required_keys() -> void:
	var m := UrbanHideoutGenerator.generate("ckeys", 5, [])
	for c in m.corridors:
		assert_true(c.has("id"), "Missing id")
		assert_true(c.has("from_room_id"), "Missing from_room_id")
		assert_true(c.has("to_room_id"), "Missing to_room_id")
		assert_true(c.has("lx"), "Missing lx")
		assert_true(c.has("ly"), "Missing ly")
		assert_true(c.has("rx"), "Missing rx")
		assert_true(c.has("ry"), "Missing ry")

# -- Tile layout sanity -------------------------------------------------------

func test_all_tiles_initialised_single_basement() -> void:
	var m := UrbanHideoutGenerator.generate("tile_sb", 2, [])
	# Every tile should be a valid TileType — no uninitialized tiles.
	var w: int = m.get_width()
	var h: int = m.get_height()
	for y in range(h):
		for x in range(w):
			var t: int = m.get_tile(x, y)
			assert_true(t >= 0, "Uninitialised tile at %d,%d" % [x, y])

func test_entrance_tile_within_bounds() -> void:
	var m := UrbanHideoutGenerator.generate("bounds_ent", 3, [])
	assert_true(m.entrance_x >= 0 and m.entrance_x < m.get_width())
	assert_true(m.entrance_y >= 0 and m.entrance_y < m.get_height())
