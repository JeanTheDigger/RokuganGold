extends GutTest
## Tests for CastleSiegeGenerator + CastleSiegeMapData (s56.17 --- LOCKED).

const SC := CastleSiegeMapData.SizeCategory
const AM := CastleSiegeMapData.AssaultMode
const PR := CastleSiegeMapData.PopRole
const ZN := CastleSiegeMapData.Zone

# -- CastleSiegeMapData enum / constant sanity --------------------------------

func test_size_category_values() -> void:
	assert_eq(SC.FORTIFICATION, 0)
	assert_eq(SC.CASTLE_TOWN,   1)
	assert_eq(SC.CITY,          2)

func test_assault_mode_values() -> void:
	assert_eq(AM.ATTACKER, 0)
	assert_eq(AM.DEFENDER, 1)

func test_dims_count() -> void:
	assert_eq(CastleSiegeMapData.DIMS.size(), 3)

func test_layer_count_count() -> void:
	assert_eq(CastleSiegeMapData.LAYER_COUNT.size(), 3)

func test_fortification_dims() -> void:
	var d: Vector2i = CastleSiegeMapData.DIMS[SC.FORTIFICATION]
	assert_eq(d.x, 20)
	assert_eq(d.y, 25)

func test_castle_town_dims() -> void:
	var d: Vector2i = CastleSiegeMapData.DIMS[SC.CASTLE_TOWN]
	assert_eq(d.x, 25)
	assert_eq(d.y, 30)

func test_city_dims() -> void:
	var d: Vector2i = CastleSiegeMapData.DIMS[SC.CITY]
	assert_eq(d.x, 30)
	assert_eq(d.y, 40)

func test_fortification_layer_count() -> void:
	assert_eq(CastleSiegeMapData.LAYER_COUNT[SC.FORTIFICATION], 2)

func test_castle_town_layer_count() -> void:
	assert_eq(CastleSiegeMapData.LAYER_COUNT[SC.CASTLE_TOWN], 3)

func test_city_layer_count() -> void:
	assert_eq(CastleSiegeMapData.LAYER_COUNT[SC.CITY], 4)

# -- Generator: map dimensions match GDD spec ---------------------------------

func test_fortification_map_dimensions() -> void:
	var m := CastleSiegeGenerator.generate("f_dim", SC.FORTIFICATION, AM.ATTACKER)
	assert_eq(m.get_width(),  20)
	assert_eq(m.get_height(), 25)

func test_castle_town_map_dimensions() -> void:
	var m := CastleSiegeGenerator.generate("ct_dim", SC.CASTLE_TOWN, AM.ATTACKER)
	assert_eq(m.get_width(),  25)
	assert_eq(m.get_height(), 30)

func test_city_map_dimensions() -> void:
	var m := CastleSiegeGenerator.generate("cy_dim", SC.CITY, AM.ATTACKER)
	assert_eq(m.get_width(),  30)
	assert_eq(m.get_height(), 40)

# -- Generator: identity fields set -------------------------------------------

func test_size_category_stored() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		var m := CastleSiegeGenerator.generate("sc_%d" % sc, sc, AM.ATTACKER)
		assert_eq(m.size_category, sc)

func test_assault_mode_stored() -> void:
	var ma := CastleSiegeGenerator.generate("am_atk", SC.FORTIFICATION, AM.ATTACKER)
	var md := CastleSiegeGenerator.generate("am_def", SC.FORTIFICATION, AM.DEFENDER)
	assert_eq(ma.assault_mode, AM.ATTACKER)
	assert_eq(md.assault_mode, AM.DEFENDER)

# -- Generator: wall metadata -------------------------------------------------

func test_fortification_has_walls() -> void:
	var m := CastleSiegeGenerator.generate("fw", SC.FORTIFICATION, AM.ATTACKER)
	assert_true(m.walls.size() >= 1)

func test_castle_town_wall_count() -> void:
	var m := CastleSiegeGenerator.generate("ctw", SC.CASTLE_TOWN, AM.ATTACKER)
	assert_true(m.walls.size() >= 2)

func test_city_wall_count() -> void:
	var m := CastleSiegeGenerator.generate("cyw", SC.CITY, AM.ATTACKER)
	assert_true(m.walls.size() >= 3)

func test_walls_have_required_keys() -> void:
	var m := CastleSiegeGenerator.generate("wkeys", SC.CASTLE_TOWN, AM.ATTACKER)
	for w in m.walls:
		assert_true(w.has("id"),        "Missing id")
		assert_true(w.has("lx"),        "Missing lx")
		assert_true(w.has("ly"),        "Missing ly")
		assert_true(w.has("rx"),        "Missing rx")
		assert_true(w.has("ry"),        "Missing ry")
		assert_true(w.has("layer_idx"), "Missing layer_idx")

# -- Generator: gate metadata -------------------------------------------------

func test_fortification_has_gates() -> void:
	var m := CastleSiegeGenerator.generate("fg", SC.FORTIFICATION, AM.ATTACKER)
	assert_true(m.gates.size() >= 1)

func test_castle_town_has_gates() -> void:
	var m := CastleSiegeGenerator.generate("ctg", SC.CASTLE_TOWN, AM.ATTACKER)
	assert_true(m.gates.size() >= 2)

func test_city_has_multiple_gates() -> void:
	# CITY outer wall has 3 gates (GDD s56.17.1 "Multiple gates")
	var m := CastleSiegeGenerator.generate("cyg", SC.CITY, AM.ATTACKER)
	var outer_gates := 0
	for g in m.gates:
		if g["layer_idx"] == 0:
			outer_gates += 1
	assert_eq(outer_gates, 3)

func test_gates_have_required_keys() -> void:
	var m := CastleSiegeGenerator.generate("gkeys", SC.CASTLE_TOWN, AM.ATTACKER)
	for g in m.gates:
		assert_true(g.has("id"),        "Missing id")
		assert_true(g.has("x"),         "Missing x")
		assert_true(g.has("y"),         "Missing y")
		assert_true(g.has("layer_idx"), "Missing layer_idx")
		assert_true(g.has("wall_id"),   "Missing wall_id")

func test_gate_tiles_are_door() -> void:
	var m := CastleSiegeGenerator.generate("gate_tile", SC.FORTIFICATION, AM.ATTACKER)
	for g in m.gates:
		if g["layer_idx"] == 0:  # outer wall gate
			assert_eq(m.get_tile(g["x"], g["y"]), Enums.TileType.DOOR_WOOD_CLOSED)

# -- Generator: murder holes (metadata only, s40 blocked) --------------------

func test_murder_holes_have_required_keys() -> void:
	var m := CastleSiegeGenerator.generate("mhkeys", SC.FORTIFICATION, AM.ATTACKER)
	for mh in m.murder_holes:
		assert_true(mh.has("id"),      "Missing id")
		assert_true(mh.has("x"),       "Missing x")
		assert_true(mh.has("y"),       "Missing y")
		assert_true(mh.has("gate_id"), "Missing gate_id")
		assert_true(mh.has("layer_idx"), "Missing layer_idx")

func test_murder_hole_above_gate() -> void:
	var m := CastleSiegeGenerator.generate("mh_above", SC.FORTIFICATION, AM.ATTACKER)
	for mh in m.murder_holes:
		var matched := false
		for g in m.gates:
			if g["id"] == mh["gate_id"] and mh["y"] == g["y"] - 1:
				matched = true
				break
		assert_true(matched, "Murder hole not directly above its gate")

# -- Generator: arrow slits (metadata only, s40 blocked) ---------------------

func test_arrow_slits_have_required_keys() -> void:
	var m := CastleSiegeGenerator.generate("askeys", SC.CASTLE_TOWN, AM.ATTACKER)
	for slit in m.arrow_slits:
		assert_true(slit.has("id"),        "Missing id")
		assert_true(slit.has("x"),         "Missing x")
		assert_true(slit.has("y"),         "Missing y")
		assert_true(slit.has("facing"),    "Missing facing")
		assert_true(slit.has("wall_id"),   "Missing wall_id")
		assert_true(slit.has("layer_idx"), "Missing layer_idx")

func test_arrow_slits_face_south() -> void:
	var m := CastleSiegeGenerator.generate("as_facing", SC.FORTIFICATION, AM.ATTACKER)
	for slit in m.arrow_slits:
		assert_eq(slit["facing"], "S")

# -- Generator: wall walkways -------------------------------------------------

func test_walkways_have_required_keys() -> void:
	var m := CastleSiegeGenerator.generate("wwkeys", SC.CASTLE_TOWN, AM.ATTACKER)
	for ww in m.wall_walkways:
		assert_true(ww.has("id"),        "Missing id")
		assert_true(ww.has("lx"),        "Missing lx")
		assert_true(ww.has("ly"),        "Missing ly")
		assert_true(ww.has("rx"),        "Missing rx")
		assert_true(ww.has("ry"),        "Missing ry")
		assert_true(ww.has("layer_idx"), "Missing layer_idx")
		assert_true(ww.has("wall_id"),   "Missing wall_id")

func test_walkway_tiles_are_floor_stone() -> void:
	var m := CastleSiegeGenerator.generate("ww_floor", SC.FORTIFICATION, AM.ATTACKER)
	for ww in m.wall_walkways:
		if ww["layer_idx"] == 0:
			# Sample check: leftmost walkway tile
			var t: int = m.get_tile(ww["lx"], ww["ly"])
			# May be ZONE_EXIT if player start was placed there; otherwise FLOOR_STONE
			assert_true(
				t == Enums.TileType.FLOOR_STONE or t == Enums.TileType.ZONE_EXIT,
				"Unexpected walkway tile type %d" % t)

# -- Generator: baileys -------------------------------------------------------

func test_baileys_have_required_keys() -> void:
	var m := CastleSiegeGenerator.generate("baykeys", SC.CASTLE_TOWN, AM.ATTACKER)
	for b in m.baileys:
		assert_true(b.has("id"),        "Missing id")
		assert_true(b.has("lx"),        "Missing lx")
		assert_true(b.has("ly"),        "Missing ly")
		assert_true(b.has("rx"),        "Missing rx")
		assert_true(b.has("ry"),        "Missing ry")
		assert_true(b.has("zone_type"), "Missing zone_type")
		assert_true(b.has("layer_idx"), "Missing layer_idx")

func test_approach_zone_present() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		var m := CastleSiegeGenerator.generate("approach_%d" % sc, sc, AM.ATTACKER)
		var found := false
		for b in m.baileys:
			if b["zone_type"] == ZN.APPROACH:
				found = true
				break
		assert_true(found, "Approach zone missing for size %d" % sc)

func test_approach_tiles_are_floor_dirt() -> void:
	var m := CastleSiegeGenerator.generate("dirt_tiles", SC.FORTIFICATION, AM.ATTACKER)
	for b in m.baileys:
		if b["zone_type"] == ZN.APPROACH:
			# Sample the center of the approach zone.
			var cx: int = (b["lx"] + b["rx"]) / 2
			var cy: int = (b["ly"] + b["ry"]) / 2
			var t: int = m.get_tile(cx, cy)
			assert_true(
				t == Enums.TileType.FLOOR_DIRT or t == Enums.TileType.ZONE_EXIT,
				"Approach center tile should be FLOOR_DIRT, got %d" % t)

# -- Generator: tenshu --------------------------------------------------------

func test_tenshu_bounds_set() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		var m := CastleSiegeGenerator.generate("tenshu_%d" % sc, sc, AM.ATTACKER)
		assert_true(m.tenshu_lx >= 0)
		assert_true(m.tenshu_ly >= 0)
		assert_true(m.tenshu_rx > m.tenshu_lx)
		assert_true(m.tenshu_ry >= m.tenshu_ly)

func test_tenshu_interior_is_floor_stone() -> void:
	var m := CastleSiegeGenerator.generate("tenshu_floor", SC.FORTIFICATION, AM.ATTACKER)
	var cx: int = (m.tenshu_lx + m.tenshu_rx) / 2
	var cy: int = (m.tenshu_ly + m.tenshu_ry) / 2
	assert_eq(m.get_tile(cx, cy), Enums.TileType.FLOOR_STONE)

# -- Generator: population slots ----------------------------------------------

func test_has_wall_defenders() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		var m := CastleSiegeGenerator.generate("wdef_%d" % sc, sc, AM.ATTACKER)
		var found := false
		for p in m.population_slots:
			if p["role"] == PR.WALL_DEFENDER:
				found = true
				break
		assert_true(found, "Wall defenders missing for size %d" % sc)

func test_has_gate_guard() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		var m := CastleSiegeGenerator.generate("gguard_%d" % sc, sc, AM.ATTACKER)
		var found := false
		for p in m.population_slots:
			if p["role"] == PR.GATE_GUARD:
				found = true
				break
		assert_true(found, "Gate guard missing for size %d" % sc)

func test_has_garrison_commander() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		var m := CastleSiegeGenerator.generate("gcmd_%d" % sc, sc, AM.ATTACKER)
		var found := false
		for p in m.population_slots:
			if p["role"] == PR.GARRISON_COMMANDER:
				found = true
				break
		assert_true(found, "Commander missing for size %d" % sc)

func test_has_bailey_defenders() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		var m := CastleSiegeGenerator.generate("bdef_%d" % sc, sc, AM.ATTACKER)
		var found := false
		for p in m.population_slots:
			if p["role"] == PR.BAILEY_DEFENDER:
				found = true
				break
		assert_true(found, "Bailey defenders missing for size %d" % sc)

func test_population_slots_have_required_keys() -> void:
	var m := CastleSiegeGenerator.generate("pkeys", SC.CASTLE_TOWN, AM.ATTACKER)
	for p in m.population_slots:
		assert_true(p.has("x"),         "Missing x")
		assert_true(p.has("y"),         "Missing y")
		assert_true(p.has("role"),      "Missing role")
		assert_true(p.has("zone"),      "Missing zone")
		assert_true(p.has("layer_idx"), "Missing layer_idx")

# -- Generator: objective slots -----------------------------------------------

func test_objectives_include_tenshu() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		var m := CastleSiegeGenerator.generate("obj_%d" % sc, sc, AM.ATTACKER)
		var found := false
		for o in m.objective_slots:
			if o["zone"] == ZN.TENSHU:
				found = true
				break
		assert_true(found, "Tenshu objective missing for size %d" % sc)

func test_objective_slots_have_required_keys() -> void:
	var m := CastleSiegeGenerator.generate("okeys", SC.CASTLE_TOWN, AM.ATTACKER)
	for o in m.objective_slots:
		assert_true(o.has("x"),         "Missing x")
		assert_true(o.has("y"),         "Missing y")
		assert_true(o.has("zone"),      "Missing zone")
		assert_true(o.has("layer_idx"), "Missing layer_idx")

# -- Generator: player start --------------------------------------------------

func test_player_start_set() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		for am in [AM.ATTACKER, AM.DEFENDER]:
			var m := CastleSiegeGenerator.generate("ps_%d_%d" % [sc, am], sc, am)
			assert_true(m.player_start_x >= 0, "player_start_x unset")
			assert_true(m.player_start_y >= 0, "player_start_y unset")

func test_player_start_tile_is_zone_exit() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		for am in [AM.ATTACKER, AM.DEFENDER]:
			var m := CastleSiegeGenerator.generate("exit_%d_%d" % [sc, am], sc, am)
			var t: int = m.get_tile(m.player_start_x, m.player_start_y)
			assert_eq(t, Enums.TileType.ZONE_EXIT,
				"Start tile not ZONE_EXIT for size %d mode %d" % [sc, am])

func test_attacker_start_in_approach_zone() -> void:
	var m := CastleSiegeGenerator.generate("atk_start", SC.FORTIFICATION, AM.ATTACKER)
	# Attacker starts at south edge (approach zone)
	var found := false
	for b in m.baileys:
		if b["zone_type"] == ZN.APPROACH:
			if m.player_start_x >= b["lx"] and m.player_start_x <= b["rx"] \
					and m.player_start_y >= b["ly"] and m.player_start_y <= b["ry"]:
				found = true
				break
	assert_true(found)

func test_defender_start_on_outer_walkway() -> void:
	# Defender starts on the layer-0 outer wall walkway for all three size categories.
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		var m := CastleSiegeGenerator.generate("def_start_%d" % sc, sc, AM.DEFENDER)
		var on_walkway := false
		for ww in m.wall_walkways:
			if ww["layer_idx"] == 0:
				if m.player_start_x >= ww["lx"] and m.player_start_x <= ww["rx"] \
						and m.player_start_y == ww["ly"]:
					on_walkway = true
					break
		assert_true(on_walkway, "Defender not on outer walkway for size %d" % sc)


func test_defender_start_exact_y() -> void:
	# Exact Y coordinates for the outer wall walkway per layout comments.
	# FORTIFICATION h=25: ow_walk_y = 20
	# CASTLE_TOWN   h=30: ow_walk_y = 25
	# CITY          h=40: ow_walk_y = 26  (regression: was 29 before fix)
	var expected_ys: Array = [20, 25, 26]
	var sizes: Array = [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]
	for i in range(sizes.size()):
		var m := CastleSiegeGenerator.generate("def_y_%d" % i, sizes[i], AM.DEFENDER)
		assert_eq(m.player_start_y, expected_ys[i],
			"Wrong defender Y for size %d: got %d expected %d" % [sizes[i], m.player_start_y, expected_ys[i]])

# -- Generator: determinism ---------------------------------------------------

func test_same_seed_same_result() -> void:
	var m1 := CastleSiegeGenerator.generate("det_42", SC.CASTLE_TOWN, AM.ATTACKER)
	var m2 := CastleSiegeGenerator.generate("det_42", SC.CASTLE_TOWN, AM.ATTACKER)
	assert_eq(m1.walls.size(),    m2.walls.size())
	assert_eq(m1.gates.size(),    m2.gates.size())
	assert_eq(m1.tenshu_lx,       m2.tenshu_lx)
	assert_eq(m1.player_start_x,  m2.player_start_x)
	assert_eq(m1.player_start_y,  m2.player_start_y)

# -- Tile layout sanity -------------------------------------------------------

func test_all_tiles_initialised() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		var m := CastleSiegeGenerator.generate("init_%d" % sc, sc, AM.ATTACKER)
		var w: int = m.get_width()
		var h: int = m.get_height()
		for y in range(h):
			for x in range(w):
				assert_true(m.get_tile(x, y) >= 0,
					"Uninitialised tile at %d,%d size %d" % [x, y, sc])

func test_player_start_within_bounds() -> void:
	for sc in [SC.FORTIFICATION, SC.CASTLE_TOWN, SC.CITY]:
		for am in [AM.ATTACKER, AM.DEFENDER]:
			var m := CastleSiegeGenerator.generate("bounds_%d_%d" % [sc, am], sc, am)
			assert_true(m.player_start_x >= 0 and m.player_start_x < m.get_width())
			assert_true(m.player_start_y >= 0 and m.player_start_y < m.get_height())
