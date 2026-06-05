class_name HilltopPositionGenerator
## Procedural hilltop-position map generator for ASCII map missions
## (s56.8 — LOCKED).  Every call with the same seed_string is deterministic.
##
## Usage:
##   var map := HilltopPositionGenerator.generate(
##       "ronin_bandits_west_hill_y5", 4,
##       [HilltopPositionMapData.ObjType.KILL_LEADER])
##
## Coordinate convention:
##   Y=0 is the top (north) of the map — the deepest part of the hilltop.
##   Y=height-1 is the bottom (south) — the main approach.
##   crest_y divides HILLTOP (y < crest_y) from SLOPE (y >= crest_y).


# ---------------------------------------------------------------------------
# Layout constants
# ---------------------------------------------------------------------------

# Fraction of map height used for the hilltop zone (top portion).
# Slope occupies the remaining bottom fraction.
const _HILLTOP_FRAC: float = 0.30  # PROVISIONAL structural parameter

# Worn path width in tiles (s56.8.2: "worn route the bandits use").
const _PATH_W: int = 1

# Tiles either side of path kept clear on slope (no rocks blocking path).
const _PATH_CLEAR: int = 1

# Edge margin — open ground before the map boundary.
const _MARGIN: int = 2

# Rock outcrop density on slope: probability out of 10 per tile.
const _ROCK_DENSITY: int = 3  # 30% — PROVISIONAL structural parameter

# Scree (loose ground) density: additional probability out of 10.
const _SCREE_DENSITY: int = 1  # 10% — PROVISIONAL structural parameter

# Rocky lip density at crest_y: probability out of 10 per tile.
const _CREST_ROCK_DENSITY: int = 5  # 50% — PROVISIONAL structural parameter

# Shelter [width, height] indexed by ShelterType.
# PROVISIONAL dimensions — GDD s56.8 specifies shelter types but not tile sizes.
const _SHELTER_DIMS: Array[Vector2i] = [
	Vector2i(4, 3),  # SHELTER
	Vector2i(6, 4),  # COMMAND
	Vector2i(5, 3),  # SUPPLY
]

# Absolute Y-positions of shelter rows within the hilltop zone, per size.
# These are measured from the top of the map (y=0).
const _HILLTOP_DYS: Array = [
	[3, 8],            # LOW_RISE (crest_y≈13): 2 rows
	[3, 8, 13],        # STEEP_HILL (crest_y≈18): 3 rows
	[3, 8, 13, 18],    # RIDGE_BLUFF (crest_y≈22): 4 rows
]

# X-positions for shelter columns, per size category.
const _HILLTOP_XS: Array = [
	[10, 22, 30],              # LOW_RISE (w=40)
	[10, 22, 36, 48],          # STEEP_HILL (w=60)
	[8, 18, 30, 44, 58, 70],   # RIDGE_BLUFF (w=80)
]

# (row_idx, col_idx) of the COMMAND shelter within _HILLTOP_DYS / _HILLTOP_XS.
# Placed at center of hilltop — center column, middle row (s56.8.3).
const _COMMAND_IDX: Array[Vector2i] = [
	Vector2i(1, 1),  # LOW_RISE: row 1, col 1 (center of 2×3 grid)
	Vector2i(1, 2),  # STEEP_HILL: row 1, col 2 (center of 3×4 grid)
	Vector2i(1, 3),  # RIDGE_BLUFF: row 1, col 3 (center of 4×6 grid)
]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

static func generate(
		seed_str: String,
		insurgency_strength: int,
		objectives: Array,
		rng: RandomNumberGenerator = null) -> HilltopPositionMapData:

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = _str_to_seed(seed_str)

	var map := HilltopPositionMapData.new()
	map.seed_string = seed_str

	# Step 1 — size category (s56.8.1).
	var size: int = pick_size_category(insurgency_strength, rng)
	map.size_category = size

	var dim: Vector2i = HilltopPositionMapData.DIMS[size]
	map.width = dim.x
	map.height = dim.y

	# Step 2 — compute zone boundary and path.
	map.crest_y = int(map.height * _HILLTOP_FRAC)
	map.path_x = map.width / 2

	# Step 3 — base terrain: open grassland everywhere.
	map.init_tiles(Enums.TileType.FLOOR_GRASS)

	# Step 4 — assign face grades (s56.8.4: gentle/moderate/steep per face).
	_assign_face_grades(map, rng)

	# Step 5 — slope zone: rocks, scree, worn path (s56.8.4).
	_carve_slope(map, rng)

	# Step 6 — crest line: rocky lip at crest_y (s56.8.4).
	_carve_crest(map, rng)

	# Step 7 — hilltop: shelters and firepits (s56.8.4).
	_carve_hilltop(map, size, rng)

	# Step 8 — entry vectors on all four edges (s56.8.2).
	_place_entry_vectors(map)

	# Step 9 — population slots (s56.8.3).
	_place_population_slots(map, size, rng)

	# Step 10 — objective markers (s56.8.5).
	_place_objective_slots(map, objectives, rng)

	return map


# ---------------------------------------------------------------------------
# Size selection (s56.8.1)
# ---------------------------------------------------------------------------

static func pick_size_category(
		insurgency_strength: int,
		rng: RandomNumberGenerator) -> int:

	# Strength ≤ 3: 70% LOW_RISE, 30% STEEP_HILL.
	# Strength 4-6: always STEEP_HILL.
	# Strength 7+: always RIDGE_BLUFF.
	var raw: int
	if insurgency_strength <= HilltopPositionMapData.MAX_STRENGTH[
			HilltopPositionMapData.SizeCategory.LOW_RISE]:
		raw = HilltopPositionMapData.SizeCategory.LOW_RISE \
			if rng.randi_range(0, 9) < 7 \
			else HilltopPositionMapData.SizeCategory.STEEP_HILL
	elif insurgency_strength <= HilltopPositionMapData.MAX_STRENGTH[
			HilltopPositionMapData.SizeCategory.STEEP_HILL]:
		raw = HilltopPositionMapData.SizeCategory.STEEP_HILL
	else:
		raw = HilltopPositionMapData.SizeCategory.RIDGE_BLUFF

	# Strength floor: ensure the category can house the population.
	while raw < HilltopPositionMapData.SizeCategory.RIDGE_BLUFF:
		if HilltopPositionMapData.MAX_STRENGTH[raw] >= insurgency_strength:
			break
		raw += 1
	return raw


# ---------------------------------------------------------------------------
# Face grade assignment (s56.8.4)
# ---------------------------------------------------------------------------

static func _assign_face_grades(
		map: HilltopPositionMapData,
		rng: RandomNumberGenerator) -> void:

	# S face (main approach): gentle or moderate — easier for player to use.
	var s_grade: int = HilltopPositionMapData.SlopeGrade.GENTLE \
		if rng.randi_range(0, 1) == 0 \
		else HilltopPositionMapData.SlopeGrade.MODERATE

	map.face_grades = [
		{"face": "S", "grade": s_grade},
		{"face": "N", "grade": rng.randi_range(0, 2)},
		{"face": "W", "grade": rng.randi_range(0, 2)},
		{"face": "E", "grade": rng.randi_range(0, 2)},
	]


# ---------------------------------------------------------------------------
# Slope zone (s56.8.4)
# ---------------------------------------------------------------------------

static func _carve_slope(
		map: HilltopPositionMapData,
		rng: RandomNumberGenerator) -> void:

	var crest_y: int = map.crest_y
	var path_x: int = map.path_x

	# Scatter rocks (WALL_STONE outcrops) and scree (FLOOR_STONE) on slope.
	for y: int in range(crest_y + 1, map.height - _MARGIN):
		for x: int in range(_MARGIN, map.width - _MARGIN):
			# Keep path column and adjacent tiles clear.
			if absi(x - path_x) <= _PATH_CLEAR:
				continue
			# Skip bottom entry zone.
			if y >= map.height - _MARGIN - 1:
				continue

			var roll: int = rng.randi_range(0, 9)
			if roll < _ROCK_DENSITY:
				map.set_tile(x, y, Enums.TileType.WALL_STONE)
			elif roll < _ROCK_DENSITY + _SCREE_DENSITY:
				map.set_tile(x, y, Enums.TileType.FLOOR_STONE)

	# Worn path: FLOOR_DIRT from south entry to crest (s56.8.2).
	for y: int in range(crest_y, map.height):
		map.set_tile(path_x, y, Enums.TileType.FLOOR_DIRT)


# ---------------------------------------------------------------------------
# Crest line (s56.8.4)
# ---------------------------------------------------------------------------

static func _carve_crest(
		map: HilltopPositionMapData,
		rng: RandomNumberGenerator) -> void:

	# Rocky lip at crest_y — scattered WALL_STONE representing the hill's edge.
	# The path keeps a clear gap (s56.8.2: path continues through crest).
	var path_x: int = map.path_x
	for x: int in range(_MARGIN, map.width - _MARGIN):
		if absi(x - path_x) <= 1:
			continue  # gap at path
		if rng.randi_range(0, 9) < _CREST_ROCK_DENSITY:
			map.set_tile(x, map.crest_y, Enums.TileType.WALL_STONE)

	# Ensure path tile at crest is FLOOR_DIRT (path crosses the crest).
	map.set_tile(path_x, map.crest_y, Enums.TileType.FLOOR_DIRT)


# ---------------------------------------------------------------------------
# Hilltop zone (s56.8.4)
# ---------------------------------------------------------------------------

static func _carve_hilltop(
		map: HilltopPositionMapData,
		size: int,
		rng: RandomNumberGenerator) -> void:

	# Hilltop is already FLOOR_GRASS from init_tiles.
	# No trees on hilltop (s56.8.4: "No Trees — hilltops are exposed by nature").
	# Place shelters and firepits.
	_place_shelters(map, size, rng)

	# Firepits: one for LOW_RISE/STEEP_HILL, two for RIDGE_BLUFF (s56.8.4).
	var camp_cx: int = map.width / 2
	var camp_mid_y: int = map.crest_y / 2
	var fid: int = 0
	if size == HilltopPositionMapData.SizeCategory.RIDGE_BLUFF:
		map.set_tile(camp_cx - 8, camp_mid_y, Enums.TileType.FIRE)
		map.firepits.append({"id": fid, "x": camp_cx - 8, "y": camp_mid_y})
		fid += 1
		map.set_tile(camp_cx + 7, camp_mid_y, Enums.TileType.FIRE)
		map.firepits.append({"id": fid, "x": camp_cx + 7, "y": camp_mid_y})
	else:
		map.set_tile(camp_cx, camp_mid_y, Enums.TileType.FIRE)
		map.firepits.append({"id": fid, "x": camp_cx, "y": camp_mid_y})


static func _place_shelters(
		map: HilltopPositionMapData,
		size: int,
		rng: RandomNumberGenerator) -> void:

	var dys: Array = _HILLTOP_DYS[size]
	var xs: Array = _HILLTOP_XS[size]
	var cmd_idx: Vector2i = _COMMAND_IDX[size]

	var range_vec: Vector2i = HilltopPositionMapData.SHELTER_RANGE[size]
	var total_slots: int = dys.size() * xs.size()
	var max_shelters: int = mini(range_vec.y, total_slots)
	var shelter_count: int = rng.randi_range(range_vec.x, max_shelters)

	# Build full slot list.
	var all_slots: Array = []
	for ri: int in range(dys.size()):
		for ci: int in range(xs.size()):
			all_slots.append({"ri": ri, "ci": ci})

	# Place COMMAND shelter first at its reserved slot.
	var cmd_ri: int = cmd_idx.x
	var cmd_ci: int = cmd_idx.y
	var cmd_y: int = dys[cmd_ri]
	var cmd_x: int = xs[cmd_ci]
	_carve_shelter(map, cmd_x, cmd_y, HilltopPositionMapData.ShelterType.COMMAND,
		map.shelters.size())

	if shelter_count <= 1:
		return

	# Remove command slot from remaining pool.
	var remaining: Array = []
	for slot: Dictionary in all_slots:
		if slot["ri"] == cmd_ri and slot["ci"] == cmd_ci:
			continue
		remaining.append(slot)

	# Fisher-Yates shuffle.
	for i: int in range(remaining.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = remaining[i]
		remaining[i] = remaining[j]
		remaining[j] = tmp

	# Fill remaining shelter slots. For RIDGE_BLUFF: first extra is SUPPLY.
	var placed: int = 1
	var supply_placed: bool = size < HilltopPositionMapData.SizeCategory.RIDGE_BLUFF
	for slot: Dictionary in remaining:
		if placed >= shelter_count:
			break
		var sy: int = dys[slot["ri"]]
		var sx: int = xs[slot["ci"]]
		var stype: int
		if not supply_placed:
			stype = HilltopPositionMapData.ShelterType.SUPPLY
			supply_placed = true
		else:
			stype = HilltopPositionMapData.ShelterType.SHELTER
		_carve_shelter(map, sx, sy, stype, map.shelters.size())
		placed += 1


static func _carve_shelter(
		map: HilltopPositionMapData,
		cx: int,
		cy: int,
		stype: int,
		sid: int) -> void:

	var dim: Vector2i = _SHELTER_DIMS[stype]
	var half_w: int = dim.x / 2
	var half_h: int = dim.y / 2

	var lx: int = clampi(cx - half_w, _MARGIN, map.width - _MARGIN - 1)
	var rx: int = clampi(lx + dim.x - 1, _MARGIN, map.width - _MARGIN - 1)
	var ly: int = clampi(cy - half_h, _MARGIN, map.crest_y - _MARGIN - 1)
	var ry: int = clampi(ly + dim.y - 1, _MARGIN, map.crest_y - _MARGIN - 1)

	# Shelters are FLOOR_DIRT footprints — no wall tiles (soft cover, s56.8.4).
	for y: int in range(ly, ry + 1):
		for x: int in range(lx, rx + 1):
			map.set_tile(x, y, Enums.TileType.FLOOR_DIRT)

	map.shelters.append({
		"id":   sid,
		"lx":   lx,
		"ly":   ly,
		"rx":   rx,
		"ry":   ry,
		"type": stype,
	})


# ---------------------------------------------------------------------------
# Entry vectors (s56.8.2)
# ---------------------------------------------------------------------------

static func _place_entry_vectors(map: HilltopPositionMapData) -> void:
	var path_x: int = map.path_x
	var mid_slope_y: int = map.crest_y + (map.height - map.crest_y) / 2

	# South — main approach via worn path (s56.8.2: "watched, easiest ascent").
	map.set_tile(path_x, map.height - 2, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": path_x, "y": map.height - 2, "is_path": true})

	# North — back face of hill (s56.8.2: far side blocks defender view).
	map.set_tile(path_x, 1, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": path_x, "y": 1, "is_path": false})

	# West — side approach partway up slope (s56.8.2: "any side").
	map.set_tile(1, mid_slope_y, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": 1, "y": mid_slope_y, "is_path": false})

	# East — side approach partway up slope.
	map.set_tile(map.width - 2, mid_slope_y, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": map.width - 2, "y": mid_slope_y, "is_path": false})


# ---------------------------------------------------------------------------
# Population placement (s56.8.3)
# ---------------------------------------------------------------------------

static func _place_population_slots(
		map: HilltopPositionMapData,
		size: int,
		rng: RandomNumberGenerator) -> void:

	var path_x: int = map.path_x
	var mid_slope_y: int = map.crest_y + (map.height - map.crest_y) / 2

	# Lookout(s): partway up slope at vantage points (s56.8.3: "watching downhill").
	var lookout_side: int = _MARGIN + 2 \
		if rng.randi_range(0, 1) == 0 else map.width - _MARGIN - 3
	map.population_slots.append({
		"x":    lookout_side,
		"y":    mid_slope_y,
		"role": HilltopPositionMapData.PopRole.LOOKOUT,
		"zone": HilltopPositionMapData.Zone.SLOPE,
	})

	# Second lookout for RIDGE_BLUFF (s56.8.3: "one or two").
	if size == HilltopPositionMapData.SizeCategory.RIDGE_BLUFF:
		var other_side: int = map.width - _MARGIN - 3 \
			if lookout_side < map.width / 2 else _MARGIN + 2
		map.population_slots.append({
			"x":    other_side,
			"y":    mid_slope_y - 4,
			"role": HilltopPositionMapData.PopRole.LOOKOUT,
			"zone": HilltopPositionMapData.Zone.SLOPE,
		})

	# Path guard(s): on path near crest (s56.8.3: "controls easy route up").
	map.population_slots.append({
		"x":    path_x,
		"y":    map.crest_y + 3,
		"role": HilltopPositionMapData.PopRole.PATH_GUARD,
		"zone": HilltopPositionMapData.Zone.SLOPE,
	})
	if size >= HilltopPositionMapData.SizeCategory.STEEP_HILL:
		# path_x + 1 is within the _PATH_CLEAR protected zone; path_x + 2 has a
		# 30% chance of being WALL_STONE (rock scatter) and must be avoided.
		map.population_slots.append({
			"x":    path_x + 1,
			"y":    map.crest_y + 6,
			"role": HilltopPositionMapData.PopRole.PATH_GUARD,
			"zone": HilltopPositionMapData.Zone.SLOPE,
		})

	# Camp group: one per firepit, clustered on hilltop (s56.8.3).
	for fp: Dictionary in map.firepits:
		map.population_slots.append({
			"x":    fp["x"] + 2,
			"y":    fp["y"],
			"role": HilltopPositionMapData.PopRole.CAMP_GROUP,
			"zone": HilltopPositionMapData.Zone.HILLTOP,
		})

	# Leader group: center of command shelter (s56.8.3: "center of hilltop camp").
	var cmd: Dictionary = _find_command_shelter(map)
	if not cmd.is_empty():
		map.population_slots.append({
			"x":    (cmd["lx"] + cmd["rx"]) / 2,
			"y":    (cmd["ly"] + cmd["ry"]) / 2,
			"role": HilltopPositionMapData.PopRole.LEADER_GROUP,
			"zone": HilltopPositionMapData.Zone.HILLTOP,
		})

	# Edge defenders: near hilltop edge for rapid response (s56.8.3).
	var edge_y: int = map.crest_y - 2
	var edge_count: int = 3 \
		if size == HilltopPositionMapData.SizeCategory.RIDGE_BLUFF else 2
	if edge_count == 3:
		var third_x: int = map.width / 2
		map.population_slots.append({
			"x":    clampi(third_x, _MARGIN, map.width - _MARGIN - 1),
			"y":    edge_y,
			"role": HilltopPositionMapData.PopRole.EDGE_DEFENDER,
			"zone": HilltopPositionMapData.Zone.HILLTOP,
		})
	var quarter_w: int = map.width / 4
	map.population_slots.append({
		"x":    clampi(quarter_w, _MARGIN, map.width - _MARGIN - 1),
		"y":    edge_y,
		"role": HilltopPositionMapData.PopRole.EDGE_DEFENDER,
		"zone": HilltopPositionMapData.Zone.HILLTOP,
	})
	map.population_slots.append({
		"x":    clampi(map.width * 3 / 4, _MARGIN, map.width - _MARGIN - 1),
		"y":    edge_y,
		"role": HilltopPositionMapData.PopRole.EDGE_DEFENDER,
		"zone": HilltopPositionMapData.Zone.HILLTOP,
	})


# ---------------------------------------------------------------------------
# Objective placement (s56.8.5)
# ---------------------------------------------------------------------------

static func _place_objective_slots(
		map: HilltopPositionMapData,
		objectives: Array,
		rng: RandomNumberGenerator) -> void:

	var cmd: Dictionary = _find_command_shelter(map)
	var supply: Dictionary = _find_supply_shelter(map)
	var non_cmd: Array = []
	for s: Dictionary in map.shelters:
		if s["type"] != HilltopPositionMapData.ShelterType.COMMAND:
			non_cmd.append(s)

	for obj_type: int in objectives:
		match obj_type:
			HilltopPositionMapData.ObjType.KILL_LEADER:
				if not cmd.is_empty():
					map.objective_slots.append({
						"x":          (cmd["lx"] + cmd["rx"]) / 2,
						"y":          (cmd["ly"] + cmd["ry"]) / 2,
						"obj_type":   HilltopPositionMapData.ObjType.KILL_LEADER,
						"shelter_id": cmd["id"],
					})

			HilltopPositionMapData.ObjType.RECOVER_GOODS:
				# Prefer supply shelter; fallback to any non-command shelter.
				var target: Dictionary = supply if not supply.is_empty() \
					else (non_cmd[0] if not non_cmd.is_empty() else {})
				if not target.is_empty():
					map.objective_slots.append({
						"x":          (target["lx"] + target["rx"]) / 2,
						"y":          (target["ly"] + target["ry"]) / 2,
						"obj_type":   HilltopPositionMapData.ObjType.RECOVER_GOODS,
						"shelter_id": target["id"],
					})

			HilltopPositionMapData.ObjType.BURN_CAMP:
				# One burn marker per shelter (s56.8.5).
				for sh: Dictionary in map.shelters:
					map.objective_slots.append({
						"x":          (sh["lx"] + sh["rx"]) / 2,
						"y":          (sh["ly"] + sh["ry"]) / 2,
						"obj_type":   HilltopPositionMapData.ObjType.BURN_CAMP,
						"shelter_id": sh["id"],
					})

			HilltopPositionMapData.ObjType.RESCUE_HOSTAGES:
				# Shelter nearest to crest (highest ry = closest to crest_y).
				var hostage_bldg: Dictionary = _find_crest_shelter(non_cmd)
				if not hostage_bldg.is_empty():
					map.objective_slots.append({
						"x":          (hostage_bldg["lx"] + hostage_bldg["rx"]) / 2,
						"y":          (hostage_bldg["ly"] + hostage_bldg["ry"]) / 2,
						"obj_type":   HilltopPositionMapData.ObjType.RESCUE_HOSTAGES,
						"shelter_id": hostage_bldg["id"],
					})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _find_command_shelter(map: HilltopPositionMapData) -> Dictionary:
	for s: Dictionary in map.shelters:
		if s["type"] == HilltopPositionMapData.ShelterType.COMMAND:
			return s
	return {}


static func _find_supply_shelter(map: HilltopPositionMapData) -> Dictionary:
	for s: Dictionary in map.shelters:
		if s["type"] == HilltopPositionMapData.ShelterType.SUPPLY:
			return s
	return {}


static func _find_crest_shelter(non_cmd: Array) -> Dictionary:
	if non_cmd.is_empty():
		return {}
	# Shelter with highest ly value is closest to crest_y (most crest-side).
	var best: Dictionary = non_cmd[0]
	for s: Dictionary in non_cmd:
		if s["ly"] > best["ly"]:
			best = s
	return best


static func _str_to_seed(s: String) -> int:
	# FNV-1a 32-bit hash — deterministic across platforms.
	var h: int = 0x811C9DC5
	for i: int in range(s.length()):
		h = h ^ s.unicode_at(i)
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h
