class_name OccupiedVillageTemplateGenerator
## Procedural occupied-village map generator for ASCII map missions
## (s56.4 — LOCKED).  Every call with the same seed_string is deterministic.
##
## Usage:
##   var map := OccupiedVillageTemplateGenerator.generate(
##       "bandits_tanuki_village_y5", 2,
##       [OccupiedVillageMapData.ObjType.KILL_LEADER])


# ---------------------------------------------------------------------------
# Layout constants
# ---------------------------------------------------------------------------

# Width of the central road spine in tiles (s56.4.2).
const _ROAD_W: int = 2

# Width of the crop/field border ringing the map (s56.4.4).
const _CROP_MARGIN: int = 3

# Gap tiles between a building's road-facing wall and the road edge.
const _BLDG_ROAD_GAP: int = 1

# Building [width, height] indexed by BuildingType.
const _BLDG_DIMS: Array[Vector2i] = [
	Vector2i(5, 4),  # FARMHOUSE
	Vector2i(7, 5),  # BARN
	Vector2i(7, 6),  # HEADMAN
]

# Vertical centre of each building slot, by size category.
# Spaced so worst-case buildings (H=6) fit without overlapping or touching
# the crop margin.
const _SLOT_YS: Array = [
	[7, 14, 22, 29],                     # HAMLET: 4 slots
	[7, 13, 19, 25, 31, 37, 43, 47],    # VILLAGE: 8 slots
]

# Index within _SLOT_YS of the headman slot (center-most; s56.4.2 "most
# defensible building").  HAMLET center≈18 → slot y=22 (idx 2).
# VILLAGE center≈26 → slot y=25 (idx 3).
const _HEADMAN_SLOT_IDX: Array[int] = [2, 3]

# Fixed river y-row per size — placed south of all building slots (s56.4.4).
const _RIVER_Y: Array[int] = [32, 46]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

static func generate(
		seed_str: String,
		insurgency_strength: int,
		objectives: Array,
		rng: RandomNumberGenerator = null) -> OccupiedVillageMapData:

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = _str_to_seed(seed_str)

	var map := OccupiedVillageMapData.new()
	map.seed_string = seed_str

	# Step 1 — size category (s56.4.1).
	var size: int = pick_size_category(insurgency_strength, rng)
	map.size_category = size

	var dim: Vector2i = OccupiedVillageMapData.DIMS[size]
	map.width = dim.x
	map.height = dim.y

	# Step 2 — base terrain: grass field + crop border (s56.4.4).
	map.init_tiles(Enums.TileType.FLOOR_GRASS)
	_place_crop_border(map)

	# Step 3 — main road spine (s56.4.2).
	var road_x: int = map.width / 2 - 1
	_place_main_road(map, road_x)

	# Step 4 — buildings along the road (s56.4.1, s56.4.3).
	var building_count: int = _pick_building_count(size, rng)
	_place_buildings(map, size, road_x, building_count, rng)

	# Step 5 — optional river + bridge (s56.4.4: ~20% chance).
	map.has_river = rng.randi_range(0, 9) < 2
	if map.has_river:
		_place_river(map, size, road_x)

	# Step 6 — scattered vegetation on open ground (s56.4.4).
	_scatter_vegetation(map, rng)

	# Step 7 — entry vectors on all four edges (s56.4.2).
	_place_entry_vectors(map, road_x)

	# Step 8 — population slots (s56.4.3).
	_place_population_slots(map, road_x, rng)

	# Step 9 — civilian presence (s56.4.3).
	_place_civilian_slots(map, rng)

	# Step 10 — objective markers (s56.4.5).
	_place_objective_slots(map, objectives, rng)

	return map


# ---------------------------------------------------------------------------
# Size selection (s56.4.1)
# ---------------------------------------------------------------------------

static func pick_size_category(insurgency_strength: int, rng: RandomNumberGenerator) -> int:
	# Strengths 1-3 may produce Hamlet (70%) or Village (30%).
	# Strengths 4+ require Village (Hamlet cannot house more than Strength 3).
	var raw: int
	if insurgency_strength <= OccupiedVillageMapData.MAX_STRENGTH[OccupiedVillageMapData.SizeCategory.HAMLET]:
		raw = OccupiedVillageMapData.SizeCategory.HAMLET if rng.randi_range(0, 9) < 7 \
			else OccupiedVillageMapData.SizeCategory.VILLAGE
	else:
		raw = OccupiedVillageMapData.SizeCategory.VILLAGE

	# Strength floor: bump up if the category cannot house the population.
	while raw < OccupiedVillageMapData.SizeCategory.VILLAGE:
		if OccupiedVillageMapData.MAX_STRENGTH[raw] >= insurgency_strength:
			break
		raw += 1
	return raw


static func _pick_building_count(size: int, rng: RandomNumberGenerator) -> int:
	var range_vec: Vector2i = OccupiedVillageMapData.BUILDING_RANGE[size]
	# Cap at the number of available slot positions (2 sides × slot count).
	var slot_ys: Array = _SLOT_YS[size]
	var max_slots: int = slot_ys.size() * 2
	var max_buildings: int = mini(range_vec.y, max_slots)
	return rng.randi_range(range_vec.x, max_buildings)


# ---------------------------------------------------------------------------
# Base terrain
# ---------------------------------------------------------------------------

static func _place_crop_border(map: OccupiedVillageMapData) -> void:
	# Top and bottom crop bands.
	map.fill_rect(0, 0, map.width - 1, _CROP_MARGIN - 1, Enums.TileType.CROPS)
	map.fill_rect(0, map.height - _CROP_MARGIN, map.width - 1, map.height - 1,
		Enums.TileType.CROPS)
	# Left and right crop bands (middle rows only; corners already filled above).
	map.fill_rect(0, _CROP_MARGIN, _CROP_MARGIN - 1, map.height - _CROP_MARGIN - 1,
		Enums.TileType.CROPS)
	map.fill_rect(map.width - _CROP_MARGIN, _CROP_MARGIN, map.width - 1,
		map.height - _CROP_MARGIN - 1, Enums.TileType.CROPS)


static func _place_main_road(map: OccupiedVillageMapData, road_x: int) -> void:
	# Vertical N-S road, 2 tiles wide, running through the crop-free interior.
	for y: int in range(_CROP_MARGIN, map.height - _CROP_MARGIN):
		map.set_tile(road_x,     y, Enums.TileType.FLOOR_DIRT)
		map.set_tile(road_x + 1, y, Enums.TileType.FLOOR_DIRT)


# ---------------------------------------------------------------------------
# Buildings (s56.4.1, s56.4.2)
# ---------------------------------------------------------------------------

static func _place_buildings(
		map: OccupiedVillageMapData,
		size: int,
		road_x: int,
		building_count: int,
		rng: RandomNumberGenerator) -> void:

	var slot_ys: Array = _SLOT_YS[size]
	var headman_idx: int = _HEADMAN_SLOT_IDX[size]
	var headman_cy: int = slot_ys[headman_idx]
	var headman_side: int = rng.randi_range(0, 1)

	# Always place headman's house first.
	_carve_building(map, headman_cy, headman_side, road_x,
		OccupiedVillageMapData.BuildingType.HEADMAN, map.buildings.size())

	if building_count <= 1:
		return

	# Collect remaining slots (all positions except the headman's slot).
	var remaining: Array = []
	for i: int in range(slot_ys.size()):
		for side: int in [0, 1]:
			if i == headman_idx and side == headman_side:
				continue
			remaining.append({"cy": slot_ys[i], "side": side})

	# Fisher-Yates shuffle for random slot selection.
	for i: int in range(remaining.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Dictionary = remaining[i]
		remaining[i] = remaining[j]
		remaining[j] = tmp

	# Fill up to building_count - 1 more buildings.
	var placed: int = 1
	for slot: Dictionary in remaining:
		if placed >= building_count:
			break
		var btype: int = rng.randi_range(0, 1)  # FARMHOUSE or BARN
		_carve_building(map, slot["cy"], slot["side"], road_x, btype,
			map.buildings.size())
		placed += 1


static func _carve_building(
		map: OccupiedVillageMapData,
		cy: int,
		side: int,
		road_x: int,
		btype: int,
		bid: int) -> void:

	var dim: Vector2i = _BLDG_DIMS[btype]
	var w: int = dim.x
	var h: int = dim.y

	# Compute bounding box relative to the road.
	var lx: int
	var rx: int
	if side == 0:  # west of road — door faces east toward road
		rx = road_x - _BLDG_ROAD_GAP - 1
		lx = rx - w + 1
	else:           # east of road — door faces west toward road
		lx = road_x + _ROAD_W + _BLDG_ROAD_GAP
		rx = lx + w - 1

	var ly: int = cy - h / 2
	var ry: int = ly + h - 1

	# Clamp to the map interior (inside the crop margin).
	lx = clampi(lx, _CROP_MARGIN, map.width  - _CROP_MARGIN - 1)
	rx = clampi(rx, _CROP_MARGIN, map.width  - _CROP_MARGIN - 1)
	ly = clampi(ly, _CROP_MARGIN, map.height - _CROP_MARGIN - 1)
	ry = clampi(ry, _CROP_MARGIN, map.height - _CROP_MARGIN - 1)

	# Outer WALL_WOOD perimeter.
	for y: int in range(ly, ry + 1):
		for x: int in range(lx, rx + 1):
			map.set_tile(x, y, Enums.TileType.WALL_WOOD)

	# FLOOR_WOOD interior.
	for y: int in range(ly + 1, ry):
		for x: int in range(lx + 1, rx):
			map.set_tile(x, y, Enums.TileType.FLOOR_WOOD)

	# Door on the road-facing wall, centred vertically.
	var door_y: int = (ly + ry) / 2
	var door_x: int
	var path_x: int  # one-tile dirt path connecting door to road
	if side == 0:    # east wall faces road
		door_x = rx
		path_x = rx + 1
	else:             # west wall faces road
		door_x = lx
		path_x = lx - 1

	map.set_tile(door_x, door_y, Enums.TileType.DOOR_WOOD_CLOSED)
	if path_x >= 0 and path_x < map.width:
		map.set_tile(path_x, door_y, Enums.TileType.FLOOR_DIRT)

	map.buildings.append({
		"id":     bid,
		"lx":     lx,
		"ly":     ly,
		"rx":     rx,
		"ry":     ry,
		"type":   btype,
		"door_x": door_x,
		"door_y": door_y,
		"side":   side,
	})

	# Roof cap (s4.4 Option B): each village building presents a rooftop from above;
	# the road, crops, and river stay open. ensure_levels makes this safe per building.
	AsciiMapGenerator._cap_with_roof(map, lx, ly, rx, ry)


# ---------------------------------------------------------------------------
# River + bridge (s56.4.4)
# ---------------------------------------------------------------------------

static func _place_river(map: OccupiedVillageMapData, size: int, road_x: int) -> void:
	var ry: int = _RIVER_Y[size]
	map.river_y = ry
	map.bridge_x = road_x

	# Full E-W WATER_DEEP row — skip building floor tiles so the last building row
	# (slot y=47 for VILLAGE, whose interior extends up to y=46) is not overwritten
	# with impassable water, which would strand NPC population slots.
	for x: int in range(map.width):
		var existing: int = map.get_tile(x, ry)
		if existing == Enums.TileType.FLOOR_STONE or existing == Enums.TileType.FLOOR_DIRT:
			continue
		map.set_tile(x, ry, Enums.TileType.WATER_DEEP)

	# Road-width FLOOR_WOOD bridge crossing.
	map.set_tile(road_x,     ry, Enums.TileType.FLOOR_WOOD)
	map.set_tile(road_x + 1, ry, Enums.TileType.FLOOR_WOOD)


# ---------------------------------------------------------------------------
# Vegetation (s56.4.4)
# ---------------------------------------------------------------------------

static func _scatter_vegetation(map: OccupiedVillageMapData, rng: RandomNumberGenerator) -> void:
	# Scatter BUSH and GROUNDCOVER on open FLOOR_GRASS tiles only.
	for y: int in range(_CROP_MARGIN, map.height - _CROP_MARGIN):
		for x: int in range(_CROP_MARGIN, map.width - _CROP_MARGIN):
			if map.get_tile(x, y) != Enums.TileType.FLOOR_GRASS:
				continue
			var roll: int = rng.randi_range(0, 19)
			if roll == 0:
				map.set_tile(x, y, Enums.TileType.BUSH)
			elif roll == 1:
				map.set_tile(x, y, Enums.TileType.GROUNDCOVER)


# ---------------------------------------------------------------------------
# Entry vectors (s56.4.2)
# ---------------------------------------------------------------------------

static func _place_entry_vectors(map: OccupiedVillageMapData, road_x: int) -> void:
	# South — main road approach (s56.4.2: "road from the direction traveled").
	var south_y: int = map.height - 2
	map.set_tile(road_x, south_y, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": road_x, "y": south_y, "is_road": true})

	# North — road exit / back-approach.
	map.set_tile(road_x, 1, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": road_x, "y": 1, "is_road": true})

	# West — field/treeline approach (s56.4.2).
	var mid_y: int = map.height / 2
	map.set_tile(1, mid_y, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": 1, "y": mid_y, "is_road": false})

	# East — field approach.
	map.set_tile(map.width - 2, mid_y, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": map.width - 2, "y": mid_y, "is_road": false})


# ---------------------------------------------------------------------------
# Population placement (s56.4.3)
# ---------------------------------------------------------------------------

static func _place_population_slots(
		map: OccupiedVillageMapData,
		road_x: int,
		rng: RandomNumberGenerator) -> void:

	if map.buildings.is_empty():
		return

	var headman: Dictionary = {}
	var non_headman: Array = []
	for b: Dictionary in map.buildings:
		if b["type"] == OccupiedVillageMapData.BuildingType.HEADMAN:
			headman = b
		else:
			non_headman.append(b)

	# Sentry: road approach from south (s56.4.3).
	map.population_slots.append({
		"x":           road_x,
		"y":           map.height - _CROP_MARGIN - 1,
		"role":        OccupiedVillageMapData.PopRole.SENTRY,
		"building_id": -1,
	})

	# Second sentry for Village — north road approach (s56.4.3: "one or two").
	if map.size_category == OccupiedVillageMapData.SizeCategory.VILLAGE:
		map.population_slots.append({
			"x":           road_x + 1,
			"y":           _CROP_MARGIN + 1,
			"role":        OccupiedVillageMapData.PopRole.SENTRY,
			"building_id": -1,
		})

	# Leader: inside headman's house (s56.4.3).
	if not headman.is_empty():
		map.population_slots.append({
			"x":           (headman["lx"] + headman["rx"]) / 2,
			"y":           (headman["ly"] + headman["ry"]) / 2,
			"role":        OccupiedVillageMapData.PopRole.LEADER,
			"building_id": headman["id"],
		})

	# Camp groups: inside non-headman buildings (67% chance each; s56.4.3).
	for b: Dictionary in non_headman:
		if rng.randi_range(0, 2) != 0:
			map.population_slots.append({
				"x":           (b["lx"] + b["rx"]) / 2,
				"y":           (b["ly"] + b["ry"]) / 2,
				"role":        OccupiedVillageMapData.PopRole.CAMP_GROUP,
				"building_id": b["id"],
			})

	# Patrol: one in Hamlet, one or two in Village (s56.4.3).
	var patrol_count: int
	if map.size_category == OccupiedVillageMapData.SizeCategory.HAMLET:
		patrol_count = 1
	else:
		patrol_count = rng.randi_range(1, 2)
	var mid_y: int = map.height / 2
	for i: int in range(patrol_count):
		map.population_slots.append({
			"x":           road_x,
			"y":           mid_y + i * 4,
			"role":        OccupiedVillageMapData.PopRole.PATROL,
			"building_id": -1,
		})


# ---------------------------------------------------------------------------
# Civilian placement (s56.4.3)
# ---------------------------------------------------------------------------

static func _place_civilian_slots(
		map: OccupiedVillageMapData,
		rng: RandomNumberGenerator) -> void:
	# One civilian per non-headman building (s56.4.3: "in their homes, hiding").
	for b: Dictionary in map.buildings:
		if b["type"] == OccupiedVillageMapData.BuildingType.HEADMAN:
			continue
		var offset_x: int = rng.randi_range(-1, 1)
		map.civilian_slots.append({
			"x":          (b["lx"] + b["rx"]) / 2 + offset_x,
			"y":          (b["ly"] + b["ry"]) / 2,
			"building_id": b["id"],
		})


# ---------------------------------------------------------------------------
# Objective placement (s56.4.5)
# ---------------------------------------------------------------------------

static func _place_objective_slots(
		map: OccupiedVillageMapData,
		objectives: Array,
		rng: RandomNumberGenerator) -> void:

	if map.buildings.is_empty():
		return

	var headman: Dictionary = {}
	var non_headman: Array = []
	for b: Dictionary in map.buildings:
		if b["type"] == OccupiedVillageMapData.BuildingType.HEADMAN:
			headman = b
		else:
			non_headman.append(b)

	for obj_type: int in objectives:
		match obj_type:
			OccupiedVillageMapData.ObjType.KILL_LEADER:
				if not headman.is_empty():
					map.objective_slots.append({
						"x":          (headman["lx"] + headman["rx"]) / 2,
						"y":          (headman["ly"] + headman["ry"]) / 2,
						"obj_type":   OccupiedVillageMapData.ObjType.KILL_LEADER,
						"building_id": headman["id"],
					})

			OccupiedVillageMapData.ObjType.RECOVER_GOODS:
				var b: Dictionary = _find_goods_building(non_headman, headman)
				if not b.is_empty():
					map.objective_slots.append({
						"x":          (b["lx"] + b["rx"]) / 2,
						"y":          (b["ly"] + b["ry"]) / 2,
						"obj_type":   OccupiedVillageMapData.ObjType.RECOVER_GOODS,
						"building_id": b["id"],
					})

			OccupiedVillageMapData.ObjType.RESCUE_HOSTAGES:
				var b: Dictionary = _find_hostage_building(non_headman, rng)
				if not b.is_empty():
					map.objective_slots.append({
						"x":          (b["lx"] + b["rx"]) / 2,
						"y":          (b["ly"] + b["ry"]) / 2,
						"obj_type":   OccupiedVillageMapData.ObjType.RESCUE_HOSTAGES,
						"building_id": b["id"],
					})

			OccupiedVillageMapData.ObjType.DRIVE_OUT:
				# Threshold objective — no unique tile; marker at headman as strongpoint.
				var dx: int = 0
				var dy: int = 0
				var dbid: int = -1
				if not headman.is_empty():
					dx = (headman["lx"] + headman["rx"]) / 2
					dy = (headman["ly"] + headman["ry"]) / 2
					dbid = headman["id"]
				map.objective_slots.append({
					"x":          dx,
					"y":          dy,
					"obj_type":   OccupiedVillageMapData.ObjType.DRIVE_OUT,
					"building_id": dbid,
				})


static func _find_goods_building(non_headman: Array, headman: Dictionary) -> Dictionary:
	# Prefer BARN (s56.4.5: "barn or storehouse").
	for b: Dictionary in non_headman:
		if b["type"] == OccupiedVillageMapData.BuildingType.BARN:
			return b
	# Fallback: farmhouse farthest from headman.
	if non_headman.is_empty():
		return {}
	var hcx: int = (headman["lx"] + headman["rx"]) / 2 if not headman.is_empty() else 0
	var hcy: int = (headman["ly"] + headman["ry"]) / 2 if not headman.is_empty() else 0
	var best: Dictionary = non_headman[0]
	var best_dist: float = 0.0
	for b: Dictionary in non_headman:
		var dx: int = (b["lx"] + b["rx"]) / 2 - hcx
		var dy: int = (b["ly"] + b["ry"]) / 2 - hcy
		var d: float = dx * dx + dy * dy
		if d > best_dist:
			best_dist = d
			best = b
	return best


static func _find_hostage_building(
		non_headman: Array,
		rng: RandomNumberGenerator) -> Dictionary:
	# Prefer farmhouse (small; easier to guard; s56.4.5).
	var farmhouses: Array = []
	for b: Dictionary in non_headman:
		if b["type"] == OccupiedVillageMapData.BuildingType.FARMHOUSE:
			farmhouses.append(b)
	if not farmhouses.is_empty():
		return farmhouses[rng.randi_range(0, farmhouses.size() - 1)]
	if non_headman.is_empty():
		return {}
	return non_headman[rng.randi_range(0, non_headman.size() - 1)]


# ---------------------------------------------------------------------------
# Utilities
# ---------------------------------------------------------------------------

static func _str_to_seed(s: String) -> int:
	# FNV-1a 32-bit hash — deterministic across platforms.
	var h: int = 0x811C9DC5
	for i: int in range(s.length()):
		h = h ^ s.unicode_at(i)
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h
