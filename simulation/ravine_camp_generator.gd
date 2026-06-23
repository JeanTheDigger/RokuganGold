class_name RavineCampGenerator
## Procedural ravine-camp map generator for ASCII map missions (s56.11 — LOCKED).
## Every call with the same seed_string is deterministic.
##
## Usage:
##   var map := RavineCampGenerator.generate(
##       "ronin_gully_y5", 4,
##       [RavineCampMapData.ObjType.KILL_LEADER])
##
## Coordinate convention: Y=0 is north (top); Y=height-1 is south (ravine mouth).
## The ravine runs south-to-north; player enters from the south.
## Rim area (FLOOR_GRASS) flanks both sides of the natural rock walls.


# ---------------------------------------------------------------------------
# Layout constants — PROVISIONAL structural parameters (GDD s56.11 specifies
# shape and features but not exact tile dimensions).
# ---------------------------------------------------------------------------

# Rim width (walkable high-ground strip) per size category.
const _RIM_W:  Array[int] = [5, 6, 8]

# Ravine wall thickness per size category.
const _WALL_W: Array[int] = [3, 4, 5]

# Chokepoint passage width (tiles of FLOOR_DIRT remaining at narrow) per size.
const _CHOKE_PASSAGE_W: Array[int] = [8, 10, 12]

# Chokepoint y-rows per size (1 / 2 / 3 chokepoints).
# Ravine runs 0..height-1; chokepoints sit at these y coordinates.
const _CHOKE_Y: Array[Array] = [
	[21],        # NARROW_GULLY (44 tall)
	[18, 40],    # RAVINE       (60 tall)
	[14, 35, 56],# CANYON       (76 tall)
]

# Chokepoint height: how many rows the narrowing spans (centred on _CHOKE_Y).
const _CHOKE_H: int = 3

# Number of rim-edge descent points per size (s56.11.2: "two or three").
const _DESCENT_COUNT: Array[int] = [2, 2, 3]

# Shelter dims [width, height] by ShelterType index.
const _SHELTER_DIMS: Array[Vector2i] = [
	Vector2i(4, 3),  # SHELTER
	Vector2i(5, 3),  # COMMAND
	Vector2i(5, 3),  # SUPPLY
]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

static func generate(
		seed_str: String,
		insurgency_strength: int,
		objectives: Array,
		rng: RandomNumberGenerator = null) -> RavineCampMapData:

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = _str_to_seed(seed_str)

	var map := RavineCampMapData.new()
	map.seed_string = seed_str

	var size: int = pick_size_category(insurgency_strength, rng)
	map.size_category = size

	var dim: Vector2i = RavineCampMapData.DIMS[size]
	map.width  = dim.x
	map.height = dim.y

	# Compute ravine geometry.
	var rim_w:  int = _RIM_W[size]
	var wall_w: int = _WALL_W[size]
	map.wall_lx  = rim_w
	map.floor_lx = rim_w + wall_w
	map.floor_rx = map.width - 1 - rim_w - wall_w
	map.wall_rx  = map.width - 1 - rim_w
	map.floor_cx = (map.floor_lx + map.floor_rx) / 2

	# Step 1 — base terrain: rim grass everywhere.
	map.init_tiles(Enums.TileType.FLOOR_GRASS)

	# Step 2 — ravine walls and floor.
	_fill_ravine(map, size)

	# Step 3 — carve chokepoints.
	_carve_chokepoints(map, size, rng)

	# Step 4 — wide sections metadata.
	_build_wide_sections(map, size)

	# Step 5 — optional stream.
	_place_stream(map, size, rng)

	# Step 6 — back exit.
	_place_back_exit(map, size, rng)

	# Step 7 — rim descent points (s56.11.2: 2–3 climable positions).
	_place_descent_points(map, size, rng)

	# Step 8 — shelters in wide sections.
	_place_shelters(map, size, rng)

	# Step 9 — firepits in wide sections.
	_place_firepits(map, size)

	# Step 10 — entry vectors (mouth + rim + back exit).
	_place_entry_vectors(map)

	# Step 11 — population slots.
	_place_population_slots(map, size, rng)

	# Step 12 — objective markers.
	_place_objective_slots(map, objectives)

	# Step 13 — elevation: high rim over a low floor (s4.4 Z-axis; 2 of 3 layers).
	_stamp_elevation(map)

	return map


# ---------------------------------------------------------------------------
# Elevation (s4.4 Z-axis — high rim / low floor)
# ---------------------------------------------------------------------------

## Stamps the rim strips (both sides, outside the rock walls) at layer 2 and the
## ravine floor + walls at layer 0. Rim and floor are already separated by the
## impassable WALL_STONE walls, so movement connectivity is unchanged — the
## elevation gives the rim its high-ground advantage: a rim watcher sees down over
## the low wall-tops into the ravine, while a fighter on the floor looking up is
## blocked (the high-ground LOS asymmetry). Descent points remain the way down
## (a deliberate climb action, deferred). A 2-of-3-layer map (no mid layer).
static func _stamp_elevation(map: RavineCampMapData) -> void:
	map.init_elevation(0)
	for y: int in range(map.height):
		for x: int in range(map.width):
			# Rim = the grass strips outside both rock walls (x < wall_lx or x > wall_rx).
			if x < map.wall_lx or x > map.wall_rx:
				map.set_elevation(x, y, 2)


# ---------------------------------------------------------------------------
# Size selection (s56.11.1)
# ---------------------------------------------------------------------------

static func pick_size_category(
		insurgency_strength: int,
		rng: RandomNumberGenerator) -> int:

	var raw: int
	if insurgency_strength <= RavineCampMapData.MAX_STRENGTH[
			RavineCampMapData.SizeCategory.NARROW_GULLY]:
		raw = RavineCampMapData.SizeCategory.NARROW_GULLY \
			if rng.randi_range(0, 9) < 7 \
			else RavineCampMapData.SizeCategory.RAVINE
	elif insurgency_strength <= RavineCampMapData.MAX_STRENGTH[
			RavineCampMapData.SizeCategory.RAVINE]:
		raw = RavineCampMapData.SizeCategory.RAVINE
	else:
		raw = RavineCampMapData.SizeCategory.CANYON

	# Strength floor: bump up until size can house the roster.
	while raw < RavineCampMapData.SizeCategory.CANYON:
		if RavineCampMapData.MAX_STRENGTH[raw] >= insurgency_strength:
			break
		raw += 1
	return raw


# ---------------------------------------------------------------------------
# Tile placement helpers
# ---------------------------------------------------------------------------

static func _fill_ravine(map: RavineCampMapData, _size: int) -> void:
	# Left wall (WALL_STONE column, full height).
	for y in range(map.height):
		for x in range(map.wall_lx, map.floor_lx):
			map.set_tile(x, y, Enums.TileType.WALL_STONE)
	# Right wall (WALL_STONE column, full height).
	for y in range(map.height):
		for x in range(map.floor_rx + 1, map.wall_rx + 1):
			map.set_tile(x, y, Enums.TileType.WALL_STONE)
	# Ravine floor (FLOOR_DIRT column, full height).
	for y in range(map.height):
		for x in range(map.floor_lx, map.floor_rx + 1):
			map.set_tile(x, y, Enums.TileType.FLOOR_DIRT)


static func _carve_chokepoints(
		map: RavineCampMapData, size: int,
		rng: RandomNumberGenerator) -> void:

	var choke_ys: Array = _CHOKE_Y[size]
	var passage_w: int  = _CHOKE_PASSAGE_W[size]
	var passage_half: int = passage_w / 2
	var cx: int = map.floor_cx

	for cy: int in choke_ys:
		var passage_lx: int = cx - passage_half
		var passage_rx: int = cx + passage_half - 1

		# Narrow the ravine floor across _CHOKE_H rows.
		var y_top: int = cy - _CHOKE_H / 2
		var y_bot: int = y_top + _CHOKE_H - 1
		for y in range(y_top, y_bot + 1):
			# Fill floor tiles outside the passage with WALL_STONE (jutting rock).
			for x in range(map.floor_lx, passage_lx):
				map.set_tile(x, y, Enums.TileType.WALL_STONE)
			for x in range(passage_rx + 1, map.floor_rx + 1):
				map.set_tile(x, y, Enums.TileType.WALL_STONE)
			# Passage itself stays FLOOR_DIRT (already set).

		# Barricade (s56.11.4: "makeshift barricade wedged between the walls").
		# 50% chance; placed at the centre row of the chokepoint.
		var has_barricade: bool = rng.randi_range(0, 1) == 1
		var barricade_gap_x: int = passage_lx + rng.randi_range(0, passage_w - 1)
		if has_barricade:
			for x in range(passage_lx, passage_rx + 1):
				if x != barricade_gap_x:
					map.set_tile(x, cy, Enums.TileType.WALL_WOOD)

		map.chokepoints.append({
			"y":              cy,
			"passage_lx":     passage_lx,
			"passage_rx":     passage_rx,
			"has_barricade":  has_barricade,
			"barricade_gap_x": barricade_gap_x,
		})


static func _build_wide_sections(map: RavineCampMapData, size: int) -> void:
	var choke_ys: Array = _CHOKE_Y[size]
	var half:     int   = _CHOKE_H / 2
	# Sections are defined between chokepoint boundaries.
	# South section (mouth): below last chokepoint.
	# Deep section: above first chokepoint.
	# Middle sections: between chokepoints.
	var boundaries: Array[int] = [1]  # y_top of northmost section
	for cy: int in choke_ys:
		boundaries.append(cy + half + 1)  # y_top of section below this choke
	boundaries.append(map.height - 2)     # y_bot sentinel

	for i in range(boundaries.size() - 1):
		var y_top: int = boundaries[i]
		var y_bot: int = boundaries[i + 1] - 1
		var is_deep:  bool = i == 0
		var is_mouth: bool = i == boundaries.size() - 2
		map.wide_sections.append({
			"y_top":          y_top,
			"y_bot":          y_bot,
			"is_mouth_section": is_mouth,
			"is_deep_section":  is_deep,
		})


static func _place_stream(
		map: RavineCampMapData, size: int,
		rng: RandomNumberGenerator) -> void:

	# CANYON always has a stream; RAVINE 60%; NARROW_GULLY 50% (s56.11.4).
	var chance: int = [5, 6, 10][size]
	if rng.randi_range(0, 9) >= chance:
		return

	map.has_stream = true
	# Stream runs near one side of the floor, not the centre (avoidable).
	var offset: int = (map.floor_rx - map.floor_lx) / 4
	map.stream_x = map.floor_lx + rng.randi_range(0, 1) * \
			((map.floor_rx - map.floor_lx) - offset) + \
			(rng.randi_range(0, 1) * offset)
	# Clamp within floor.
	map.stream_x = clampi(map.stream_x, map.floor_lx + 1, map.floor_rx - 1)
	# Paint WATER_SHALLOW column through the full ravine floor.
	# Collect barricade rows to avoid overwriting barricade gaps with water.
	var barricade_rows: Dictionary = {}
	for chk in map.chokepoints:
		if chk["has_barricade"]:
			barricade_rows[chk["y"]] = true
	for y in range(0, map.height):
		if barricade_rows.has(y):
			continue  # Preserve barricade gap tiles at chokepoint rows.
		if map.get_tile(map.stream_x, y) == Enums.TileType.FLOOR_DIRT:
			map.set_tile(map.stream_x, y, Enums.TileType.WATER_SHALLOW)


static func _place_back_exit(
		map: RavineCampMapData, size: int,
		rng: RandomNumberGenerator) -> void:

	# NARROW_GULLY: never. RAVINE: 40%. CANYON: always (s56.11.2).
	if size == RavineCampMapData.SizeCategory.NARROW_GULLY:
		return
	if size == RavineCampMapData.SizeCategory.RAVINE and rng.randi_range(0, 9) >= 4:
		return

	map.has_back_exit = true
	map.back_exit_x   = map.floor_cx


static func _place_descent_points(
		map: RavineCampMapData, size: int,
		rng: RandomNumberGenerator) -> void:

	# Place 2–3 climbable positions on the rim (s56.11.2).
	var count: int  = _DESCENT_COUNT[size]
	var rim_w: int  = _RIM_W[size]
	# Distribute evenly across the ravine height, avoiding edge rows.
	var margin: int = 5
	for i in range(count):
		var y: int = margin + (i * (map.height - 2 * margin)) / count + \
				rng.randi_range(-2, 2)
		y = clampi(y, margin, map.height - margin - 1)
		# Alternate left and right sides.
		if i % 2 == 0:
			var x: int = rng.randi_range(1, rim_w - 2)
			map.set_tile(x, y, Enums.TileType.FLOOR_STONE)
			map.descent_points.append({"x": x, "y": y, "side": "L"})
		else:
			var x: int = rng.randi_range(map.wall_rx + 2, map.width - 2)
			map.set_tile(x, y, Enums.TileType.FLOOR_STONE)
			map.descent_points.append({"x": x, "y": y, "side": "R"})


static func _place_shelters(
		map: RavineCampMapData, size: int,
		rng: RandomNumberGenerator) -> void:

	var range_v: Vector2i = RavineCampMapData.SHELTER_RANGE[size]
	var count:   int      = rng.randi_range(range_v.x, range_v.y)
	var sid:     int      = 0

	# Collect wide sections, deepest first.
	var sections: Array = map.wide_sections.duplicate()
	sections.sort_custom(func(a, b): return a["y_top"] < b["y_top"])

	var floor_cx: int = map.floor_cx
	var shelter_i: int = 0

	for sec in sections:
		if sid >= count:
			break
		var sec_cx: int = floor_cx
		var sec_mid_y: int = (sec["y_top"] + sec["y_bot"]) / 2

		# Determine shelter type.
		var stype: int
		if sid == 0 and sec["is_deep_section"]:
			stype = RavineCampMapData.ShelterType.COMMAND
		elif count >= 5 and sec["is_mouth_section"] and sid == count - 1:
			stype = RavineCampMapData.ShelterType.SUPPLY
		else:
			stype = RavineCampMapData.ShelterType.SHELTER

		var sw: int = _SHELTER_DIMS[stype].x
		var sh: int = _SHELTER_DIMS[stype].y
		# Horizontal offset alternates to avoid centre-line clustering.
		var off_x: int = (shelter_i % 3 - 1) * (sw + 2)
		var sx: int = clampi(sec_cx + off_x - sw / 2,
				map.floor_lx + 1, map.floor_rx - sw)
		var sy: int = clampi(sec_mid_y - sh / 2,
				sec["y_top"] + 1, sec["y_bot"] - sh)

		_carve_shelter(map, sx, sy, sw, sh, stype, sid)
		sid += 1
		shelter_i += 1

		# Larger sections can hold a second shelter.
		var section_h: int = sec["y_bot"] - sec["y_top"]
		if sid < count and section_h >= 14:
			var off_x2: int = -(shelter_i % 3 - 1) * (sw + 2)
			var sx2: int = clampi(sec_cx + off_x2 - sw / 2,
					map.floor_lx + 1, map.floor_rx - sw)
			var sy2: int = clampi(sec_mid_y + sh + 2,
					sec["y_top"] + 1, sec["y_bot"] - sh)
			if sy2 + sh - 1 <= sec["y_bot"] - 1:
				var stype2: int
				if sid == count - 1 and count >= 5:
					stype2 = RavineCampMapData.ShelterType.SUPPLY
				else:
					stype2 = RavineCampMapData.ShelterType.SHELTER
				_carve_shelter(map, sx2, sy2, sw, sh, stype2, sid)
				sid += 1
				shelter_i += 1


static func _carve_shelter(
		map: RavineCampMapData,
		lx: int, ly: int, w: int, h: int,
		stype: int, sid: int) -> void:

	var rx: int = lx + w - 1
	var ry: int = ly + h - 1
	map.fill_rect(lx, ly, rx, ry, Enums.TileType.FLOOR_DIRT)
	map.shelters.append({
		"id":   sid,
		"lx":   lx, "ly": ly,
		"rx":   rx, "ry": ry,
		"type": stype,
	})


static func _place_firepits(map: RavineCampMapData, size: int) -> void:
	var fid: int = 0
	# One firepit per wide section.
	for sec in map.wide_sections:
		var fx: int = map.floor_cx
		var fy: int = (sec["y_top"] + sec["y_bot"]) / 2
		# Avoid stream column.
		if map.has_stream and fx == map.stream_x:
			fx += 2
		fx = clampi(fx, map.floor_lx + 1, map.floor_rx - 1)
		map.set_tile(fx, fy, Enums.TileType.FIRE)
		map.firepits.append({"id": fid, "x": fx, "y": fy})
		fid += 1
	# CANYON gets an extra firepit in the deepest section.
	if size == RavineCampMapData.SizeCategory.CANYON and map.wide_sections.size() > 0:
		var sec = map.wide_sections[0]  # deepest (sorted north-first)
		var fx: int = clampi(map.floor_cx + 6, map.floor_lx + 1, map.floor_rx - 1)
		var fy: int = (sec["y_top"] + sec["y_bot"]) / 2 + 4
		fy = clampi(fy, sec["y_top"] + 1, sec["y_bot"] - 1)
		map.set_tile(fx, fy, Enums.TileType.FIRE)
		map.firepits.append({"id": fid, "x": fx, "y": fy})


static func _place_entry_vectors(map: RavineCampMapData) -> void:
	# Mouth: ZONE_EXIT on south edge at floor centre.
	var mx: int = map.floor_cx
	map.set_tile(mx, map.height - 1, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({
		"x": mx, "y": map.height - 1,
		"is_mouth": true, "is_back_exit": false, "is_rim": false,
	})

	# Back exit: ZONE_EXIT on north edge (if present).
	if map.has_back_exit:
		var bx: int = map.back_exit_x
		map.set_tile(bx, 0, Enums.TileType.ZONE_EXIT)
		map.entry_vectors.append({
			"x": bx, "y": 0,
			"is_mouth": false, "is_back_exit": true, "is_rim": false,
		})

	# Rim entries: ZONE_EXIT on left and right map edges (s56.11.2).
	# Three y-positions per side to reflect multiple scouting approaches.
	var rim_ys: Array[int] = [
		map.height / 4,
		map.height / 2,
		(map.height * 3) / 4,
	]
	for ry: int in rim_ys:
		map.set_tile(0, ry, Enums.TileType.ZONE_EXIT)
		map.entry_vectors.append({
			"x": 0, "y": ry,
			"is_mouth": false, "is_back_exit": false, "is_rim": true,
		})
		map.set_tile(map.width - 1, ry, Enums.TileType.ZONE_EXIT)
		map.entry_vectors.append({
			"x": map.width - 1, "y": ry,
			"is_mouth": false, "is_back_exit": false, "is_rim": true,
		})


static func _place_population_slots(
		map: RavineCampMapData, size: int,
		rng: RandomNumberGenerator) -> void:

	var cx:  int = map.floor_cx
	var deep_sec: Dictionary = _find_deep_section(map)
	var mouth_sec: Dictionary = _find_mouth_section(map)

	# Rim Watcher (s56.11.3): never for NARROW_GULLY, 50% for RAVINE, always for CANYON.
	if size == RavineCampMapData.SizeCategory.CANYON or \
			(size == RavineCampMapData.SizeCategory.RAVINE and rng.randi_range(0, 1) == 1):
		map.has_rim_watcher = true
		# Posted on left rim, facing the ravine interior.
		var watcher_y: int = (deep_sec["y_top"] + deep_sec["y_bot"]) / 2
		var watcher_x: int = _RIM_W[size] - 2
		map.population_slots.append({
			"x": watcher_x, "y": watcher_y,
			"role": RavineCampMapData.PopRole.RIM_WATCHER,
			"zone": RavineCampMapData.Zone.RIM,
		})

	# Mouth Guard: 2–3 at ravine entrance (s56.11.3: "two or three").
	var mg_count: int = 2 + (1 if size == RavineCampMapData.SizeCategory.CANYON else 0)
	var mg_y: int = map.height - 3
	for i in range(mg_count):
		var mg_x: int = cx + (i - mg_count / 2) * 3
		mg_x = clampi(mg_x, map.floor_lx + 1, map.floor_rx - 1)
		map.population_slots.append({
			"x": mg_x, "y": mg_y,
			"role": RavineCampMapData.PopRole.MOUTH_GUARD,
			"zone": RavineCampMapData.Zone.RAVINE_FLOOR,
		})

	# Chokepoint Holders: 1–2 per chokepoint (s56.11.3).
	for chk in map.chokepoints:
		var holder_x: int = (chk["passage_lx"] + chk["passage_rx"]) / 2
		var holder_y: int = chk["y"] - 2
		map.population_slots.append({
			"x": holder_x, "y": holder_y,
			"role": RavineCampMapData.PopRole.CHOKEPOINT_HOLDER,
			"zone": RavineCampMapData.Zone.RAVINE_FLOOR,
		})
		if size >= RavineCampMapData.SizeCategory.RAVINE:
			var h2_x: int = holder_x + 3
			h2_x = clampi(h2_x, chk["passage_lx"], chk["passage_rx"])
			map.population_slots.append({
				"x": h2_x, "y": holder_y + 1,
				"role": RavineCampMapData.PopRole.CHOKEPOINT_HOLDER,
				"zone": RavineCampMapData.Zone.RAVINE_FLOOR,
			})

	# Camp Groups: in each wide section (20–25% of roster, s56.11.3).
	for sec in map.wide_sections:
		if sec["is_deep_section"]:
			continue  # deepest section is Leader Group territory
		var cg_y: int = (sec["y_top"] + sec["y_bot"]) / 2
		var cg_x: int = cx - 3
		cg_x = clampi(cg_x, map.floor_lx + 1, map.floor_rx - 1)
		map.population_slots.append({
			"x": cg_x, "y": cg_y,
			"role": RavineCampMapData.PopRole.CAMP_GROUP,
			"zone": RavineCampMapData.Zone.RAVINE_FLOOR,
		})
		if size >= RavineCampMapData.SizeCategory.RAVINE:
			map.population_slots.append({
				"x": cg_x + 5, "y": cg_y,
				"role": RavineCampMapData.PopRole.CAMP_GROUP,
				"zone": RavineCampMapData.Zone.RAVINE_FLOOR,
			})

	# Leader Group: deepest wide section (s56.11.3: 20–25% of roster).
	if not deep_sec.is_empty():
		var lg_y: int = (deep_sec["y_top"] + deep_sec["y_bot"]) / 2
		var lg_x: int = cx
		map.population_slots.append({
			"x": lg_x, "y": lg_y,
			"role": RavineCampMapData.PopRole.LEADER_GROUP,
			"zone": RavineCampMapData.Zone.RAVINE_FLOOR,
		})
		if size >= RavineCampMapData.SizeCategory.RAVINE:
			map.population_slots.append({
				"x": lg_x + 3, "y": lg_y + 2,
				"role": RavineCampMapData.PopRole.LEADER_GROUP,
				"zone": RavineCampMapData.Zone.RAVINE_FLOOR,
			})


static func _place_objective_slots(
		map: RavineCampMapData, objectives: Array) -> void:

	var cmd_shelter: Dictionary = _find_command_shelter(map)
	var supply_shelter: Dictionary = _find_supply_shelter(map)
	var deep_sec: Dictionary = _find_deep_section(map)
	var middle_sec: Dictionary = _find_middle_section(map)

	# Objective position targets:
	var cmd_x: int = map.floor_cx if cmd_shelter.is_empty() else \
			(cmd_shelter["lx"] + cmd_shelter["rx"]) / 2
	var cmd_y: int = \
		(deep_sec["y_top"] + deep_sec["y_bot"]) / 2 if not deep_sec.is_empty() else 5
	if not cmd_shelter.is_empty():
		cmd_y = (cmd_shelter["ly"] + cmd_shelter["ry"]) / 2

	var goods_x: int = map.floor_cx
	var goods_y: int = \
		(middle_sec["y_top"] + middle_sec["y_bot"]) / 2 if not middle_sec.is_empty() \
		else (map.height * 3) / 4
	if not supply_shelter.is_empty():
		goods_x = (supply_shelter["lx"] + supply_shelter["rx"]) / 2
		goods_y = (supply_shelter["ly"] + supply_shelter["ry"]) / 2

	for obj in objectives:
		match int(obj):
			RavineCampMapData.ObjType.KILL_LEADER:
				map.objective_slots.append({
					"x": cmd_x, "y": cmd_y,
					"obj_type": RavineCampMapData.ObjType.KILL_LEADER,
				})
			RavineCampMapData.ObjType.RECOVER_GOODS:
				map.objective_slots.append({
					"x": goods_x, "y": goods_y,
					"obj_type": RavineCampMapData.ObjType.RECOVER_GOODS,
				})
			RavineCampMapData.ObjType.BURN_CAMP:
				for shlt in map.shelters:
					map.objective_slots.append({
						"x": (shlt["lx"] + shlt["rx"]) / 2,
						"y": (shlt["ly"] + shlt["ry"]) / 2,
						"obj_type": RavineCampMapData.ObjType.BURN_CAMP,
					})
			RavineCampMapData.ObjType.RESCUE_HOSTAGES:
				# Held in deepest section, same as the leader (s56.11.5).
				map.objective_slots.append({
					"x": cmd_x + 2, "y": cmd_y,
					"obj_type": RavineCampMapData.ObjType.RESCUE_HOSTAGES,
				})


# ---------------------------------------------------------------------------
# Lookup helpers
# ---------------------------------------------------------------------------

static func _find_deep_section(map: RavineCampMapData) -> Dictionary:
	for sec in map.wide_sections:
		if sec["is_deep_section"]:
			return sec
	return {}


static func _find_mouth_section(map: RavineCampMapData) -> Dictionary:
	for sec in map.wide_sections:
		if sec["is_mouth_section"]:
			return sec
	return {}


static func _find_middle_section(map: RavineCampMapData) -> Dictionary:
	for sec in map.wide_sections:
		if not sec["is_deep_section"] and not sec["is_mouth_section"]:
			return sec
	return _find_mouth_section(map)


static func _find_command_shelter(map: RavineCampMapData) -> Dictionary:
	for sh in map.shelters:
		if sh["type"] == RavineCampMapData.ShelterType.COMMAND:
			return sh
	return {}


static func _find_supply_shelter(map: RavineCampMapData) -> Dictionary:
	for sh in map.shelters:
		if sh["type"] == RavineCampMapData.ShelterType.SUPPLY:
			return sh
	return {}


# ---------------------------------------------------------------------------
# FNV-1a 32-bit seed from string
# ---------------------------------------------------------------------------

static func _str_to_seed(s: String) -> int:
	var h: int = 0x811C9DC5
	for i in range(s.length()):
		h ^= s.unicode_at(i)
		h  = (h * 0x01000193) & 0xFFFFFFFF
	return h
