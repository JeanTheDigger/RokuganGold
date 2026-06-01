class_name ForestApproachCampGenerator
## Procedural forest-approach-camp map generator for ASCII map missions
## (s56.5 — LOCKED).  Every call with the same seed_string is deterministic.
##
## Usage:
##   var map := ForestApproachCampGenerator.generate(
##       "ronin_bandits_kitsuki_forest_y5", 4,
##       [ForestApproachCampMapData.ObjType.KILL_LEADER])


# ---------------------------------------------------------------------------
# Layout constants
# ---------------------------------------------------------------------------

# Fraction of map height used for the forest approach zone (top portion).
# The camp clearing occupies the remaining bottom fraction.
const _FOREST_FRAC: float = 0.65

# Trail width in tiles (s56.5.2: "worn path through the forest").
const _TRAIL_W: int = 1

# Tiles either side of trail with no trees (clear corridor around path).
const _TRAIL_CLEAR: int = 2

# Edge margin — open ground before the map boundary (entry zone).
const _MARGIN: int = 2

# Base tree density: probability out of 10 for any given forest cell.
const _TREE_DENSITY: int = 4  # 40% — PROVISIONAL structural parameter

# Reduced density for entry rows, tree-line rows, and trail adjacency.
const _LIGHT_DENSITY: int = 2  # 20% — PROVISIONAL structural parameter

# Number of natural clearings per size category.
const _CLEARING_COUNT: Array[int] = [2, 4, 6]

# Shelter [width, height] indexed by ShelterType.
# PROVISIONAL dimensions — GDD s56.5 specifies shelter types but not tile sizes.
const _SHELTER_DIMS: Array[Vector2i] = [
	Vector2i(4, 3),  # SHELTER
	Vector2i(6, 4),  # COMMAND
	Vector2i(5, 3),  # SUPPLY
]

# Y-offsets from clearing_start_y for each tent row, by size category.
const _CAMP_DROWS: Array = [
	[4, 10],            # SMALL: 2 rows
	[4, 9, 15],         # MEDIUM: 3 rows
	[4, 9, 14, 20],     # LARGE: 4 rows
]

# Absolute x-positions for tent columns, by size category.
const _CAMP_XS: Array = [
	[10, 22, 30],              # SMALL (w=40)
	[10, 22, 36, 48],          # MEDIUM (w=60)
	[8, 18, 30, 44, 58, 70],   # LARGE (w=80)
]

# (row_idx, col_idx) of the COMMAND tent within _CAMP_DROWS / _CAMP_XS.
# Placed at center-back — furthest from forest edge (s56.5.3).
const _COMMAND_IDX: Array[Vector2i] = [
	Vector2i(1, 1),  # SMALL: row 1, col 1
	Vector2i(2, 1),  # MEDIUM: row 2, col 1
	Vector2i(3, 2),  # LARGE: row 3, col 2
]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

static func generate(
		seed_str: String,
		insurgency_strength: int,
		objectives: Array,
		rng: RandomNumberGenerator = null) -> ForestApproachCampMapData:

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = _str_to_seed(seed_str)

	var map := ForestApproachCampMapData.new()
	map.seed_string = seed_str

	# Step 1 — size category (s56.5.1).
	var size: int = pick_size_category(insurgency_strength, rng)
	map.size_category = size

	var dim: Vector2i = ForestApproachCampMapData.DIMS[size]
	map.width = dim.x
	map.height = dim.y

	# Step 2 — compute zone boundary.
	map.clearing_start_y = int(map.height * _FOREST_FRAC)
	map.trail_x = map.width / 2

	# Step 3 — base terrain: open grassland everywhere.
	map.init_tiles(Enums.TileType.FLOOR_GRASS)

	# Step 4 — forest zone: trees, trail, clearings, undergrowth.
	_plant_forest(map, rng, size)

	# Step 5 — optional stream (s56.5.4: ~20% chance).
	map.has_stream = rng.randi_range(0, 9) < 2
	if map.has_stream:
		_place_stream(map, rng)

	# Step 6 — camp clearing: shelters, firepits (s56.5.4).
	_carve_camp(map, size, rng)

	# Step 7 — entry vectors on all four edges (s56.5.2).
	_place_entry_vectors(map)

	# Step 8 — population slots (s56.5.3).
	_place_population_slots(map, size, rng)

	# Step 9 — objective markers (s56.5.5).
	_place_objective_slots(map, objectives, rng)

	return map


# ---------------------------------------------------------------------------
# Size selection (s56.5.1)
# ---------------------------------------------------------------------------

static func pick_size_category(
		insurgency_strength: int,
		rng: RandomNumberGenerator) -> int:

	# Strength ≤ 3: 70% SMALL, 30% MEDIUM.
	# Strength 4-6: always MEDIUM (too large for SMALL).
	# Strength 7+: always LARGE.
	var raw: int
	if insurgency_strength <= ForestApproachCampMapData.MAX_STRENGTH[
			ForestApproachCampMapData.SizeCategory.SMALL]:
		raw = ForestApproachCampMapData.SizeCategory.SMALL \
			if rng.randi_range(0, 9) < 7 \
			else ForestApproachCampMapData.SizeCategory.MEDIUM
	elif insurgency_strength <= ForestApproachCampMapData.MAX_STRENGTH[
			ForestApproachCampMapData.SizeCategory.MEDIUM]:
		raw = ForestApproachCampMapData.SizeCategory.MEDIUM
	else:
		raw = ForestApproachCampMapData.SizeCategory.LARGE

	# Strength floor: ensure the category can house the population.
	while raw < ForestApproachCampMapData.SizeCategory.LARGE:
		if ForestApproachCampMapData.MAX_STRENGTH[raw] >= insurgency_strength:
			break
		raw += 1
	return raw


# ---------------------------------------------------------------------------
# Forest zone
# ---------------------------------------------------------------------------

static func _plant_forest(
		map: ForestApproachCampMapData,
		rng: RandomNumberGenerator,
		size: int) -> void:

	var forest_end: int = map.clearing_start_y
	var trail_x: int = map.trail_x

	# Pass 1: place natural clearings before trees so they stay open.
	var clearing_count: int = _CLEARING_COUNT[size]
	for _i: int in range(clearing_count):
		var radius: int = rng.randi_range(2, 3)
		var cx: int = rng.randi_range(_MARGIN + radius + 2, map.width - _MARGIN - radius - 2)
		var cy: int = rng.randi_range(_MARGIN + 4, forest_end - 4)
		# Avoid the trail corridor.
		if absi(cx - trail_x) < _TRAIL_CLEAR + radius + 2:
			cx = trail_x + (radius + _TRAIL_CLEAR + 2) * (1 if cx > trail_x else -1)
			cx = clampi(cx, _MARGIN + radius, map.width - _MARGIN - radius - 1)
		map.forest_clearings.append({"cx": cx, "cy": cy, "radius": radius})

	# Build a quick lookup for clearing positions.
	var in_clearing: Dictionary = {}
	for cl: Dictionary in map.forest_clearings:
		for dy: int in range(-cl["radius"], cl["radius"] + 1):
			for dx: int in range(-cl["radius"], cl["radius"] + 1):
				if dx * dx + dy * dy <= cl["radius"] * cl["radius"]:
					var px: int = cl["cx"] + dx
					var py: int = cl["cy"] + dy
					in_clearing[Vector2i(px, py)] = true

	# Pass 2: scatter trees in the forest zone.
	for y: int in range(0, forest_end):
		for x: int in range(0, map.width):
			# Skip map edges (entry zone margin).
			if x < _MARGIN or x >= map.width - _MARGIN:
				continue
			# Trail column — always clear.
			if x == trail_x:
				continue
			# Trail corridor — keep open.
			if absi(x - trail_x) <= _TRAIL_CLEAR:
				continue
			# Natural clearings stay as FLOOR_GRASS.
			if in_clearing.has(Vector2i(x, y)):
				continue

			# Pick density tier.
			var density: int
			if y < _MARGIN or y >= forest_end - 3:
				density = _LIGHT_DENSITY   # entry zone / tree line
			else:
				density = _TREE_DENSITY

			if rng.randi_range(0, 9) < density:
				# Select tree type; mostly evergreen, some deciduous, rare dead.
				var t_roll: int = rng.randi_range(0, 9)
				var tile: int
				if t_roll < 6:
					tile = Enums.TileType.TREE_EVERGREEN
				elif t_roll < 9:
					tile = Enums.TileType.TREE_DECIDUOUS
				else:
					tile = Enums.TileType.TREE_DEAD
				map.set_tile(x, y, tile)

	# Pass 3: mark trail as FLOOR_DIRT (overwrites any accidental tree at x=trail_x).
	for y: int in range(0, forest_end):
		map.set_tile(trail_x, y, Enums.TileType.FLOOR_DIRT)

	# Pass 4: scatter undergrowth on non-tree, non-trail, in-forest FLOOR_GRASS.
	for y: int in range(_MARGIN, forest_end):
		for x: int in range(_MARGIN, map.width - _MARGIN):
			if map.get_tile(x, y) != Enums.TileType.FLOOR_GRASS:
				continue
			var u_roll: int = rng.randi_range(0, 9)
			if u_roll == 0:
				map.set_tile(x, y, Enums.TileType.BUSH)
			elif u_roll == 1:
				map.set_tile(x, y, Enums.TileType.GROUNDCOVER)


# ---------------------------------------------------------------------------
# Stream (s56.5.4)
# ---------------------------------------------------------------------------

static func _place_stream(
		map: ForestApproachCampMapData,
		rng: RandomNumberGenerator) -> void:

	# Vertical WATER_SHALLOW column through the forest zone only, offset from
	# the trail so it serves as a distinct navigation landmark.
	var offset: int = map.width / 4
	var side: int = 1 if rng.randi_range(0, 1) == 0 else -1
	var sx: int = clampi(map.trail_x + side * offset, _MARGIN + 1,
		map.width - _MARGIN - 2)

	map.has_stream = true
	map.stream_x = sx

	for y: int in range(0, map.clearing_start_y):
		map.set_tile(sx, y, Enums.TileType.WATER_SHALLOW)


# ---------------------------------------------------------------------------
# Camp clearing (s56.5.4)
# ---------------------------------------------------------------------------

static func _carve_camp(
		map: ForestApproachCampMapData,
		size: int,
		rng: RandomNumberGenerator) -> void:

	# Camp is already FLOOR_GRASS from init_tiles; clear any vegetation that
	# leaked from Pass 4 into the camp zone.
	for y: int in range(map.clearing_start_y, map.height):
		for x: int in range(0, map.width):
			var tile: int = map.get_tile(x, y)
			if tile != Enums.TileType.FLOOR_GRASS and \
					tile != Enums.TileType.FLOOR_DIRT and \
					tile != Enums.TileType.WATER_SHALLOW:
				map.set_tile(x, y, Enums.TileType.FLOOR_GRASS)

	# Shelter placement.
	_place_shelters(map, size, rng)

	# Firepits: one for SMALL/MEDIUM, two for LARGE (s56.5.4).
	var camp_cx: int = map.width / 2
	var camp_mid_y: int = map.clearing_start_y + (map.height - map.clearing_start_y) / 2
	var fid: int = 0
	if size == ForestApproachCampMapData.SizeCategory.LARGE:
		map.set_tile(camp_cx - 8, camp_mid_y - 3, Enums.TileType.FIRE)
		map.firepits.append({"id": fid, "x": camp_cx - 8, "y": camp_mid_y - 3})
		fid += 1
		map.set_tile(camp_cx + 7, camp_mid_y - 3, Enums.TileType.FIRE)
		map.firepits.append({"id": fid, "x": camp_cx + 7, "y": camp_mid_y - 3})
	else:
		map.set_tile(camp_cx, camp_mid_y - 2, Enums.TileType.FIRE)
		map.firepits.append({"id": fid, "x": camp_cx, "y": camp_mid_y - 2})


static func _place_shelters(
		map: ForestApproachCampMapData,
		size: int,
		rng: RandomNumberGenerator) -> void:

	var drows: Array = _CAMP_DROWS[size]
	var xs: Array = _CAMP_XS[size]
	var cmd_idx: Vector2i = _COMMAND_IDX[size]

	var range_vec: Vector2i = ForestApproachCampMapData.SHELTER_RANGE[size]
	# Cap at available slots.
	var total_slots: int = drows.size() * xs.size()
	var max_shelters: int = mini(range_vec.y, total_slots)
	var shelter_count: int = rng.randi_range(range_vec.x, max_shelters)

	# Build full slot list.
	var all_slots: Array = []
	for ri: int in range(drows.size()):
		for ci: int in range(xs.size()):
			all_slots.append({"ri": ri, "ci": ci})

	# Place COMMAND tent first at its reserved slot.
	var cmd_slot_ri: int = cmd_idx.x
	var cmd_slot_ci: int = cmd_idx.y
	var cmd_y: int = map.clearing_start_y + drows[cmd_slot_ri]
	var cmd_x: int = xs[cmd_slot_ci]
	_carve_shelter(map, cmd_x, cmd_y, ForestApproachCampMapData.ShelterType.COMMAND,
		map.shelters.size())

	if shelter_count <= 1:
		return

	# Remove command slot from remaining pool.
	var remaining: Array = []
	for slot: Dictionary in all_slots:
		if slot["ri"] == cmd_slot_ri and slot["ci"] == cmd_slot_ci:
			continue
		remaining.append(slot)

	# Fisher-Yates shuffle.
	for i: int in range(remaining.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = remaining[i]
		remaining[i] = remaining[j]
		remaining[j] = tmp

	# Fill remaining shelter slots.  For LARGE: first extra is SUPPLY type.
	var placed: int = 1
	var supply_placed: bool = size < ForestApproachCampMapData.SizeCategory.LARGE
	for slot: Dictionary in remaining:
		if placed >= shelter_count:
			break
		var sy: int = map.clearing_start_y + drows[slot["ri"]]
		var sx: int = xs[slot["ci"]]
		var stype: int
		if not supply_placed:
			stype = ForestApproachCampMapData.ShelterType.SUPPLY
			supply_placed = true
		else:
			stype = ForestApproachCampMapData.ShelterType.SHELTER
		_carve_shelter(map, sx, sy, stype, map.shelters.size())
		placed += 1


static func _carve_shelter(
		map: ForestApproachCampMapData,
		cx: int,
		cy: int,
		stype: int,
		sid: int) -> void:

	var dim: Vector2i = _SHELTER_DIMS[stype]
	var half_w: int = dim.x / 2
	var half_h: int = dim.y / 2

	var lx: int = cx - half_w
	var rx: int = lx + dim.x - 1
	var ly: int = cy - half_h
	var ry: int = ly + dim.y - 1

	lx = clampi(lx, _MARGIN, map.width  - _MARGIN - 1)
	rx = clampi(rx, _MARGIN, map.width  - _MARGIN - 1)
	ly = clampi(ly, map.clearing_start_y, map.height - _MARGIN - 1)
	ry = clampi(ry, map.clearing_start_y, map.height - _MARGIN - 1)

	# Shelters are FLOOR_DIRT footprints — no wall tiles (soft cover, s56.5.4).
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
# Entry vectors (s56.5.2)
# ---------------------------------------------------------------------------

static func _place_entry_vectors(map: ForestApproachCampMapData) -> void:
	var trail_x: int = map.trail_x
	var mid_forest_y: int = map.clearing_start_y / 2

	# North — trail entry (primary approach, watched; s56.5.2).
	map.set_tile(trail_x, 1, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": trail_x, "y": 1, "is_trail": true})

	# South — camp back edge (leader escape route; s56.5.5).
	map.set_tile(trail_x, map.height - 2, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": trail_x, "y": map.height - 2, "is_trail": false})

	# West — forest edge flanking approach (s56.5.2: "any point along boundary").
	map.set_tile(1, mid_forest_y, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": 1, "y": mid_forest_y, "is_trail": false})

	# East — forest edge flanking approach.
	map.set_tile(map.width - 2, mid_forest_y, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": map.width - 2, "y": mid_forest_y, "is_trail": false})


# ---------------------------------------------------------------------------
# Population placement (s56.5.3)
# ---------------------------------------------------------------------------

static func _place_population_slots(
		map: ForestApproachCampMapData,
		size: int,
		rng: RandomNumberGenerator) -> void:

	var trail_x: int = map.trail_x

	# Outer sentry: on trail near the entry, watching for approach (s56.5.3).
	map.population_slots.append({
		"x":    trail_x,
		"y":    _MARGIN + 3,
		"role": ForestApproachCampMapData.PopRole.OUTER_SENTRY,
		"zone": ForestApproachCampMapData.Zone.FOREST,
	})

	# Second outer sentry for MEDIUM and LARGE: at forest edge off-trail (s56.5.3).
	if size >= ForestApproachCampMapData.SizeCategory.MEDIUM:
		var edge_x: int = _MARGIN + 2 if rng.randi_range(0, 1) == 0 \
			else map.width - _MARGIN - 3
		map.population_slots.append({
			"x":    edge_x,
			"y":    _MARGIN + 2,
			"role": ForestApproachCampMapData.PopRole.OUTER_SENTRY,
			"zone": ForestApproachCampMapData.Zone.FOREST,
		})

	# Forest patrol: one for SMALL/MEDIUM, two for LARGE (s56.5.3).
	var patrol_count: int = 2 if size == ForestApproachCampMapData.SizeCategory.LARGE \
		else 1
	var patrol_zone_h: int = map.clearing_start_y - _MARGIN - 8
	for i: int in range(patrol_count):
		var px: int = rng.randi_range(trail_x + _TRAIL_CLEAR + 2,
			map.width - _MARGIN - 2)
		if i == 1:
			px = rng.randi_range(_MARGIN + 2, trail_x - _TRAIL_CLEAR - 2)
		var py: int = _MARGIN + 8 + rng.randi_range(0, patrol_zone_h)
		map.population_slots.append({
			"x":    px,
			"y":    py,
			"role": ForestApproachCampMapData.PopRole.FOREST_PATROL,
			"zone": ForestApproachCampMapData.Zone.FOREST,
		})

	# Camp group: one per firepit, clustered in camp zone (s56.5.3).
	for fp: Dictionary in map.firepits:
		map.population_slots.append({
			"x":    fp["x"] + 2,
			"y":    fp["y"],
			"role": ForestApproachCampMapData.PopRole.CAMP_GROUP,
			"zone": ForestApproachCampMapData.Zone.CAMP,
		})

	# Leader group: inside the command shelter (s56.5.3: "20-25% concentration").
	var cmd: Dictionary = _find_command_shelter(map)
	if not cmd.is_empty():
		map.population_slots.append({
			"x":    (cmd["lx"] + cmd["rx"]) / 2,
			"y":    (cmd["ly"] + cmd["ry"]) / 2,
			"role": ForestApproachCampMapData.PopRole.LEADER_GROUP,
			"zone": ForestApproachCampMapData.Zone.CAMP,
		})


# ---------------------------------------------------------------------------
# Objective placement (s56.5.5)
# ---------------------------------------------------------------------------

static func _place_objective_slots(
		map: ForestApproachCampMapData,
		objectives: Array,
		rng: RandomNumberGenerator) -> void:

	var cmd: Dictionary = _find_command_shelter(map)
	var supply: Dictionary = _find_supply_shelter(map)
	var non_cmd: Array = []
	for s: Dictionary in map.shelters:
		if s["type"] != ForestApproachCampMapData.ShelterType.COMMAND:
			non_cmd.append(s)

	for obj_type: int in objectives:
		match obj_type:
			ForestApproachCampMapData.ObjType.KILL_LEADER:
				if not cmd.is_empty():
					map.objective_slots.append({
						"x":          (cmd["lx"] + cmd["rx"]) / 2,
						"y":          (cmd["ly"] + cmd["ry"]) / 2,
						"obj_type":   ForestApproachCampMapData.ObjType.KILL_LEADER,
						"shelter_id": cmd["id"],
					})

			ForestApproachCampMapData.ObjType.RECOVER_GOODS:
				# Prefer supply shelter; fallback to any non-command shelter (s56.5.5).
				var target: Dictionary = supply if not supply.is_empty() \
					else (non_cmd[0] if not non_cmd.is_empty() else {})
				if not target.is_empty():
					map.objective_slots.append({
						"x":          (target["lx"] + target["rx"]) / 2,
						"y":          (target["ly"] + target["ry"]) / 2,
						"obj_type":   ForestApproachCampMapData.ObjType.RECOVER_GOODS,
						"shelter_id": target["id"],
					})

			ForestApproachCampMapData.ObjType.BURN_CAMP:
				# One burn marker per shelter — each is a discrete target (s56.5.5).
				for sh: Dictionary in map.shelters:
					map.objective_slots.append({
						"x":          (sh["lx"] + sh["rx"]) / 2,
						"y":          (sh["ly"] + sh["ry"]) / 2,
						"obj_type":   ForestApproachCampMapData.ObjType.BURN_CAMP,
						"shelter_id": sh["id"],
					})

			ForestApproachCampMapData.ObjType.RESCUE_HOSTAGES:
				# Camp-edge tent — nearest to clearing_start_y (s56.5.5: "camp edge").
				var hostage_bldg: Dictionary = _find_hostage_shelter(non_cmd,
					map.clearing_start_y, rng)
				if not hostage_bldg.is_empty():
					map.objective_slots.append({
						"x":          (hostage_bldg["lx"] + hostage_bldg["rx"]) / 2,
						"y":          (hostage_bldg["ly"] + hostage_bldg["ry"]) / 2,
						"obj_type":   ForestApproachCampMapData.ObjType.RESCUE_HOSTAGES,
						"shelter_id": hostage_bldg["id"],
					})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _find_command_shelter(map: ForestApproachCampMapData) -> Dictionary:
	for s: Dictionary in map.shelters:
		if s["type"] == ForestApproachCampMapData.ShelterType.COMMAND:
			return s
	return {}


static func _find_supply_shelter(map: ForestApproachCampMapData) -> Dictionary:
	for s: Dictionary in map.shelters:
		if s["type"] == ForestApproachCampMapData.ShelterType.SUPPLY:
			return s
	return {}


static func _find_hostage_shelter(
		non_cmd: Array,
		clearing_start_y: int,
		rng: RandomNumberGenerator) -> Dictionary:

	if non_cmd.is_empty():
		return {}
	# Prefer the shelter closest to the clearing edge (lowest ly).
	var best: Dictionary = non_cmd[0]
	for s: Dictionary in non_cmd:
		if s["ly"] < best["ly"]:
			best = s
	return best


static func _str_to_seed(s: String) -> int:
	# FNV-1a 32-bit hash — deterministic across platforms.
	var h: int = 0x811C9DC5
	for i: int in range(s.length()):
		h = h ^ s.unicode_at(i)
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h
