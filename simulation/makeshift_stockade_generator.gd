class_name MakeshiftStockadeGenerator
## Procedural makeshift-stockade map generator for ASCII map missions
## (s56.7 — LOCKED).  Every call with the same seed_string is deterministic.
##
## Usage:
##   var map := MakeshiftStockadeGenerator.generate(
##       "ronin_bandits_stockade_y5", 4,
##       [MakeshiftStockadeMapData.ObjType.KILL_LEADER])
##
## Coordinate convention:
##   Y=0 is the top (north) of the map.
##   Y=height-1 is the bottom (south) — the main approach direction.
##   The stockade perimeter sits in the map interior; open ground is the approach.


# ---------------------------------------------------------------------------
# Layout constants
# ---------------------------------------------------------------------------

# Margin from map edge to perimeter wall tiles, per size category.
# PROVISIONAL structural parameter.
const _PERIM_MARGIN: Array[int] = [8, 10, 12]

# Gate width in tiles (south wall gap).
const _GATE_W: int = 2

# Probability out of 10 that a wall tile becomes WALL_STONE instead of WALL_WOOD.
const _WALL_STONE_PROB: int = 3  # 30% — PROVISIONAL structural parameter

# Platform half-extent (tiles from centre). Produces a 5×5 FLOOR_STONE footprint.
const _PLATFORM_HALF: int = 2

# Ditch width in tiles immediately outside the perimeter.
const _DITCH_W: int = 1

# General map-boundary clearance (tiles kept clear from the map edge).
const _MARGIN: int = 2

# Shelter [width, height] indexed by ShelterType.
# PROVISIONAL dimensions — GDD s56.7 specifies shelter types but not tile sizes.
const _SHELTER_DIMS: Array[Vector2i] = [
	Vector2i(4, 3),  # SHELTER
	Vector2i(6, 4),  # COMMAND
	Vector2i(5, 3),  # SUPPLY
]

# Shelter offsets (dy, dx) from interior centre, per size category.
# Slot 0 is always COMMAND at (0, 0).
# dy > 0 moves toward the south wall (gate side).
const _SHELTER_OFFSETS: Array = [
	# SMALL  (interior ≈22×26, SHELTER_RANGE [1, 2])
	[Vector2i(0, 0), Vector2i(7, -6), Vector2i(7, 6)],
	# MEDIUM (interior ≈39×39, SHELTER_RANGE [3, 6])
	[Vector2i(0, 0), Vector2i(-8, -10), Vector2i(-8, 0), Vector2i(-8, 10),
	 Vector2i(8, -8), Vector2i(8, 8)],
	# LARGE  (interior ≈54×50, SHELTER_RANGE [7, 10])
	[Vector2i(0, 0), Vector2i(-12, -14), Vector2i(-12, -4), Vector2i(-12, 6),
	 Vector2i(-12, 16), Vector2i(3, -10), Vector2i(3, 10),
	 Vector2i(12, -14), Vector2i(12, 0), Vector2i(12, 14)],
]


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

static func generate(
		seed_str: String,
		insurgency_strength: int,
		objectives: Array,
		rng: RandomNumberGenerator = null) -> MakeshiftStockadeMapData:

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = _str_to_seed(seed_str)

	var map := MakeshiftStockadeMapData.new()
	map.seed_string = seed_str

	# Step 1 — size category (s56.7.1).
	var size: int = pick_size_category(insurgency_strength, rng)
	map.size_category = size

	var dim: Vector2i = MakeshiftStockadeMapData.DIMS[size]
	map.width  = dim.x
	map.height = dim.y

	# Step 2 — perimeter bounding box.
	var mg: int = _PERIM_MARGIN[size]
	map.perim_lx = mg
	map.perim_rx = map.width  - mg - 1
	map.perim_ty = mg
	map.perim_by = map.height - mg - 1

	# Step 3 — base terrain: open grassland (approach zone).
	map.init_tiles(Enums.TileType.FLOOR_GRASS)

	# Step 4 — interior floor: FLOOR_DIRT within the perimeter.
	_fill_interior(map)

	# Step 5 — perimeter walls: WALL_WOOD ring, WALL_STONE corners + random.
	_carve_perimeter(map, rng)

	# Step 6 — gate: 2-tile gap on south wall (s56.7.2).
	_carve_gate(map)

	# Step 7 — weak points on N / W / E walls (s56.7.2).
	_carve_weak_points(map, size, rng)

	# Step 8 — optional ditch: WATER_SHALLOW strip outside perimeter (s56.7.4).
	_carve_ditch(map, size, rng)

	# Step 9 — optional platform: FLOOR_STONE in north interior (s56.7.4).
	_place_platform(map, size)

	# Step 10 — shelters: FLOOR_DIRT footprints inside perimeter (s56.7.4).
	_place_shelters(map, size, rng)

	# Step 11 — firepits: FIRE tiles inside (s56.7.4).
	_place_firepits(map, size)

	# Step 12 — entry vectors: gate + weak-point ZONE_EXIT markers (s56.7.2).
	_place_entry_vectors(map)

	# Step 13 — population slots (s56.7.3).
	_place_population_slots(map, size)

	# Step 14 — objective markers (s56.7.5).
	_place_objective_slots(map, objectives)

	return map


# ---------------------------------------------------------------------------
# Size selection (s56.7.1)
# ---------------------------------------------------------------------------

static func pick_size_category(
		insurgency_strength: int,
		rng: RandomNumberGenerator) -> int:

	# Strength ≤ 3: 70% SMALL, 30% MEDIUM.
	# Strength 4–6: always MEDIUM.
	# Strength 7+:  always LARGE.
	var raw: int
	if insurgency_strength <= MakeshiftStockadeMapData.MAX_STRENGTH[
			MakeshiftStockadeMapData.SizeCategory.SMALL]:
		raw = MakeshiftStockadeMapData.SizeCategory.SMALL \
			if rng.randi_range(0, 9) < 7 \
			else MakeshiftStockadeMapData.SizeCategory.MEDIUM
	elif insurgency_strength <= MakeshiftStockadeMapData.MAX_STRENGTH[
			MakeshiftStockadeMapData.SizeCategory.MEDIUM]:
		raw = MakeshiftStockadeMapData.SizeCategory.MEDIUM
	else:
		raw = MakeshiftStockadeMapData.SizeCategory.LARGE

	# Strength floor: bump up until the category can house the roster.
	while raw < MakeshiftStockadeMapData.SizeCategory.LARGE:
		if MakeshiftStockadeMapData.MAX_STRENGTH[raw] >= insurgency_strength:
			break
		raw += 1
	return raw


# ---------------------------------------------------------------------------
# Interior floor
# ---------------------------------------------------------------------------

static func _fill_interior(map: MakeshiftStockadeMapData) -> void:
	for y: int in range(map.perim_ty, map.perim_by + 1):
		for x: int in range(map.perim_lx, map.perim_rx + 1):
			map.set_tile(x, y, Enums.TileType.FLOOR_DIRT)


# ---------------------------------------------------------------------------
# Perimeter walls (s56.7.4: stacked timber, overturned carts)
# ---------------------------------------------------------------------------

static func _carve_perimeter(
		map: MakeshiftStockadeMapData,
		rng: RandomNumberGenerator) -> void:

	var lx: int = map.perim_lx
	var rx: int = map.perim_rx
	var ty: int = map.perim_ty
	var by: int = map.perim_by

	# Reinforced corners: always WALL_STONE.
	for corner: Vector2i in [Vector2i(lx, ty), Vector2i(rx, ty),
	                          Vector2i(lx, by), Vector2i(rx, by)]:
		map.set_tile(corner.x, corner.y, Enums.TileType.WALL_STONE)

	# North and south wall runs.
	for x: int in range(lx + 1, rx):
		var wt: int = Enums.TileType.WALL_STONE \
			if rng.randi_range(0, 9) < _WALL_STONE_PROB \
			else Enums.TileType.WALL_WOOD
		map.set_tile(x, ty, wt)
		map.set_tile(x, by, wt)

	# West and east wall runs (corners already set).
	for y: int in range(ty + 1, by):
		var wt_w: int = Enums.TileType.WALL_STONE \
			if rng.randi_range(0, 9) < _WALL_STONE_PROB \
			else Enums.TileType.WALL_WOOD
		map.set_tile(lx, y, wt_w)
		var wt_e: int = Enums.TileType.WALL_STONE \
			if rng.randi_range(0, 9) < _WALL_STONE_PROB \
			else Enums.TileType.WALL_WOOD
		map.set_tile(rx, y, wt_e)


# ---------------------------------------------------------------------------
# Gate (s56.7.2: main south-wall gap)
# ---------------------------------------------------------------------------

static func _carve_gate(map: MakeshiftStockadeMapData) -> void:
	map.gate_x = map.width / 2
	for i: int in range(_GATE_W):
		map.set_tile(map.gate_x + i, map.perim_by, Enums.TileType.FLOOR_DIRT)


# ---------------------------------------------------------------------------
# Weak points (s56.7.2: exploitable gaps on N / W / E walls)
# ---------------------------------------------------------------------------

static func _carve_weak_points(
		map: MakeshiftStockadeMapData,
		size: int,
		rng: RandomNumberGenerator) -> void:

	var lx: int = map.perim_lx
	var rx: int = map.perim_rx
	var ty: int = map.perim_ty
	var by: int = map.perim_by

	# West weak point.
	var wp_wy: int = rng.randi_range(ty + 4, by - 4)
	map.weak_points.append({"x": lx, "y": wp_wy, "side": "W"})

	# East weak point.
	var wp_ey: int = rng.randi_range(ty + 4, by - 4)
	map.weak_points.append({"x": rx, "y": wp_ey, "side": "E"})

	# North weak point: MEDIUM and LARGE only.
	if size >= MakeshiftStockadeMapData.SizeCategory.MEDIUM:
		var wp_nx: int = rng.randi_range(lx + 4, rx - 4)
		map.weak_points.append({"x": wp_nx, "y": ty, "side": "N"})


# ---------------------------------------------------------------------------
# Ditch (s56.7.4: WATER_SHALLOW strip outside perimeter)
# ---------------------------------------------------------------------------

static func _carve_ditch(
		map: MakeshiftStockadeMapData,
		size: int,
		rng: RandomNumberGenerator) -> void:

	if size == MakeshiftStockadeMapData.SizeCategory.SMALL:
		return
	if size == MakeshiftStockadeMapData.SizeCategory.MEDIUM and \
			rng.randi_range(0, 9) >= 6:
		return

	map.has_ditch = true

	# Stakes: ~40% of Medium with ditch, ~80% of Large (s56.7.4).
	map.has_stakes = rng.randi_range(0, 9) < \
		(8 if size == MakeshiftStockadeMapData.SizeCategory.LARGE else 4)

	var lx: int = map.perim_lx
	var rx: int = map.perim_rx
	var ty: int = map.perim_ty
	var by: int = map.perim_by
	var gx: int = map.gate_x

	# North ditch row.
	for x: int in range(lx - _DITCH_W, rx + _DITCH_W + 1):
		var dy: int = ty - 1
		if dy >= _MARGIN:
			map.set_tile(x, dy, Enums.TileType.WATER_SHALLOW)

	# South ditch row — gap at gate columns so the gate remains accessible.
	for x: int in range(lx - _DITCH_W, rx + _DITCH_W + 1):
		if x >= gx and x < gx + _GATE_W:
			continue
		var dy: int = by + 1
		if dy < map.height - _MARGIN:
			map.set_tile(x, dy, Enums.TileType.WATER_SHALLOW)

	# West ditch column.
	for y: int in range(ty - _DITCH_W, by + _DITCH_W + 1):
		var dx: int = lx - 1
		if dx >= _MARGIN:
			map.set_tile(dx, y, Enums.TileType.WATER_SHALLOW)

	# East ditch column.
	for y: int in range(ty - _DITCH_W, by + _DITCH_W + 1):
		var dx: int = rx + 1
		if dx < map.width - _MARGIN:
			map.set_tile(dx, y, Enums.TileType.WATER_SHALLOW)


# ---------------------------------------------------------------------------
# Platform / watchtower (s56.7.4: crude elevated position, Medium/Large)
# ---------------------------------------------------------------------------

static func _place_platform(
		map: MakeshiftStockadeMapData,
		size: int) -> void:

	if size == MakeshiftStockadeMapData.SizeCategory.SMALL:
		return

	map.has_platform = true

	var cx: int = (map.perim_lx + map.perim_rx) / 2
	var py: int = map.perim_ty + _PLATFORM_HALF + 2

	map.platform_x = cx
	map.platform_y = py

	# 5×5 FLOOR_STONE footprint, clamped strictly inside the perimeter.
	for y: int in range(py - _PLATFORM_HALF, py + _PLATFORM_HALF + 1):
		for x: int in range(cx - _PLATFORM_HALF, cx + _PLATFORM_HALF + 1):
			if x > map.perim_lx and x < map.perim_rx and \
					y > map.perim_ty and y < map.perim_by:
				map.set_tile(x, y, Enums.TileType.FLOOR_STONE)


# ---------------------------------------------------------------------------
# Shelters (s56.7.4: FLOOR_DIRT footprints, no wall tiles — soft cover)
# ---------------------------------------------------------------------------

static func _place_shelters(
		map: MakeshiftStockadeMapData,
		size: int,
		rng: RandomNumberGenerator) -> void:

	var offsets: Array = _SHELTER_OFFSETS[size]
	var range_vec: Vector2i = MakeshiftStockadeMapData.SHELTER_RANGE[size]
	var shelter_count: int = rng.randi_range(range_vec.x,
		mini(range_vec.y, offsets.size()))

	var cx: int = (map.perim_lx + map.perim_rx) / 2
	var cy: int = (map.perim_ty + map.perim_by) / 2

	# Slot 0 is always COMMAND (offset (0, 0) → no displacement).
	_carve_shelter(map, cx, cy,
		MakeshiftStockadeMapData.ShelterType.COMMAND, map.shelters.size())

	if shelter_count <= 1:
		return

	# Fisher-Yates shuffle of remaining offsets.
	var remaining: Array = offsets.slice(1)
	for i: int in range(remaining.size() - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: Vector2i = remaining[i]
		remaining[i] = remaining[j]
		remaining[j] = tmp

	# Fill remaining shelter slots. LARGE: first extra is SUPPLY.
	var placed: int = 1
	var supply_placed: bool = size < MakeshiftStockadeMapData.SizeCategory.LARGE
	for off: Vector2i in remaining:
		if placed >= shelter_count:
			break
		var stype: int
		if not supply_placed:
			stype = MakeshiftStockadeMapData.ShelterType.SUPPLY
			supply_placed = true
		else:
			stype = MakeshiftStockadeMapData.ShelterType.SHELTER
		# off.x = dy row offset, off.y = dx column offset.
		_carve_shelter(map, cx + off.y, cy + off.x, stype, map.shelters.size())
		placed += 1


static func _carve_shelter(
		map: MakeshiftStockadeMapData,
		cx: int,
		cy: int,
		stype: int,
		sid: int) -> void:

	var dim: Vector2i = _SHELTER_DIMS[stype]
	var half_w: int = dim.x / 2
	var half_h: int = dim.y / 2

	var lx: int = clampi(cx - half_w,        map.perim_lx + 1, map.perim_rx - 1)
	var rx: int = clampi(lx + dim.x - 1,     map.perim_lx + 1, map.perim_rx - 1)
	var ly: int = clampi(cy - half_h,        map.perim_ty + 1, map.perim_by - 1)
	var ry: int = clampi(ly + dim.y - 1,     map.perim_ty + 1, map.perim_by - 1)

	for y: int in range(ly, ry + 1):
		for x: int in range(lx, rx + 1):
			map.set_tile(x, y, Enums.TileType.FLOOR_DIRT)

	map.shelters.append({"id": sid, "lx": lx, "ly": ly, "rx": rx, "ry": ry,
		"type": stype})


# ---------------------------------------------------------------------------
# Firepits (s56.7.4: FIRE tiles inside perimeter)
# ---------------------------------------------------------------------------

static func _place_firepits(
		map: MakeshiftStockadeMapData,
		size: int) -> void:

	var cx: int = (map.perim_lx + map.perim_rx) / 2
	var cy: int = (map.perim_ty + map.perim_by) / 2
	var fid: int = 0

	match size:
		MakeshiftStockadeMapData.SizeCategory.SMALL:
			map.set_tile(cx, cy + 5, Enums.TileType.FIRE)
			map.firepits.append({"id": fid, "x": cx, "y": cy + 5})

		MakeshiftStockadeMapData.SizeCategory.MEDIUM:
			map.set_tile(cx - 8, cy + 4, Enums.TileType.FIRE)
			map.firepits.append({"id": fid, "x": cx - 8, "y": cy + 4})
			fid += 1
			map.set_tile(cx + 8, cy + 4, Enums.TileType.FIRE)
			map.firepits.append({"id": fid, "x": cx + 8, "y": cy + 4})

		MakeshiftStockadeMapData.SizeCategory.LARGE:
			map.set_tile(cx - 14, cy + 4, Enums.TileType.FIRE)
			map.firepits.append({"id": fid, "x": cx - 14, "y": cy + 4})
			fid += 1
			map.set_tile(cx, cy + 4, Enums.TileType.FIRE)
			map.firepits.append({"id": fid, "x": cx, "y": cy + 4})
			fid += 1
			map.set_tile(cx + 14, cy + 4, Enums.TileType.FIRE)
			map.firepits.append({"id": fid, "x": cx + 14, "y": cy + 4})


# ---------------------------------------------------------------------------
# Entry vectors (s56.7.2: perimeter breaches — gate + weak points)
# ---------------------------------------------------------------------------

static func _place_entry_vectors(map: MakeshiftStockadeMapData) -> void:
	# Gate: primary entry on south wall.
	map.set_tile(map.gate_x, map.perim_by, Enums.TileType.ZONE_EXIT)
	map.entry_vectors.append({"x": map.gate_x, "y": map.perim_by, "is_gate": true})

	# Weak points: secondary entries on N / W / E walls.
	for wp: Dictionary in map.weak_points:
		map.set_tile(wp["x"], wp["y"], Enums.TileType.ZONE_EXIT)
		map.entry_vectors.append({"x": wp["x"], "y": wp["y"], "is_gate": false})


# ---------------------------------------------------------------------------
# Population placement (s56.7.3)
# ---------------------------------------------------------------------------

static func _place_population_slots(
		map: MakeshiftStockadeMapData,
		size: int) -> void:

	var lx: int = map.perim_lx
	var rx: int = map.perim_rx
	var ty: int = map.perim_ty
	var by: int = map.perim_by
	var gate_x: int = map.gate_x

	# Wall watchers: one per wall section (Small), two-three (Medium/Large).
	# Positioned 1 tile inside the perimeter wall, watching outward.
	var step: int = 8 if size == MakeshiftStockadeMapData.SizeCategory.SMALL else 6

	# North wall.
	var wx: int = lx + step
	while wx < rx - 2:
		map.population_slots.append({"x": wx, "y": ty + 1,
			"role": MakeshiftStockadeMapData.PopRole.WALL_WATCHER})
		wx += step

	# South wall (flanking the gate gap).
	map.population_slots.append({"x": lx + 3, "y": by - 1,
		"role": MakeshiftStockadeMapData.PopRole.WALL_WATCHER})
	map.population_slots.append({"x": rx - 3, "y": by - 1,
		"role": MakeshiftStockadeMapData.PopRole.WALL_WATCHER})

	# West wall.
	var wy: int = ty + step
	while wy < by - 2:
		map.population_slots.append({"x": lx + 1, "y": wy,
			"role": MakeshiftStockadeMapData.PopRole.WALL_WATCHER})
		wy += step

	# East wall.
	var ey: int = ty + step
	while ey < by - 2:
		map.population_slots.append({"x": rx - 1, "y": ey,
			"role": MakeshiftStockadeMapData.PopRole.WALL_WATCHER})
		ey += step

	# Gate guards: inside the gate, chokepoint defenders (s56.7.3).
	map.population_slots.append({"x": gate_x,     "y": by - 2,
		"role": MakeshiftStockadeMapData.PopRole.GATE_GUARD})
	map.population_slots.append({"x": gate_x + 1, "y": by - 2,
		"role": MakeshiftStockadeMapData.PopRole.GATE_GUARD})

	# Watchtower: on the raised platform (Medium/Large only; s56.7.3).
	if map.has_platform:
		map.population_slots.append({"x": map.platform_x, "y": map.platform_y,
			"role": MakeshiftStockadeMapData.PopRole.WATCHTOWER})

	# Camp group: adjacent to each firepit (s56.7.3: "resting roster").
	for fp: Dictionary in map.firepits:
		map.population_slots.append({"x": fp["x"] + 2, "y": fp["y"],
			"role": MakeshiftStockadeMapData.PopRole.CAMP_GROUP})

	# Leader group: centre of the command shelter (s56.7.3).
	var cmd: Dictionary = _find_command_shelter(map)
	if not cmd.is_empty():
		map.population_slots.append({
			"x":    (cmd["lx"] + cmd["rx"]) / 2,
			"y":    (cmd["ly"] + cmd["ry"]) / 2,
			"role": MakeshiftStockadeMapData.PopRole.LEADER_GROUP,
		})


# ---------------------------------------------------------------------------
# Objective placement (s56.7.5)
# ---------------------------------------------------------------------------

static func _place_objective_slots(
		map: MakeshiftStockadeMapData,
		objectives: Array) -> void:

	var cmd: Dictionary    = _find_command_shelter(map)
	var supply: Dictionary = _find_supply_shelter(map)
	var non_cmd: Array = []
	for s: Dictionary in map.shelters:
		if s["type"] != MakeshiftStockadeMapData.ShelterType.COMMAND:
			non_cmd.append(s)

	for obj_type: int in objectives:
		match obj_type:
			MakeshiftStockadeMapData.ObjType.KILL_LEADER:
				if not cmd.is_empty():
					map.objective_slots.append({
						"x":          (cmd["lx"] + cmd["rx"]) / 2,
						"y":          (cmd["ly"] + cmd["ry"]) / 2,
						"obj_type":   MakeshiftStockadeMapData.ObjType.KILL_LEADER,
						"shelter_id": cmd["id"],
					})

			MakeshiftStockadeMapData.ObjType.RECOVER_GOODS:
				# Prefer supply shelter; any other non-command shelter; command as fallback.
				var target: Dictionary = supply if not supply.is_empty() \
					else (non_cmd[0] if not non_cmd.is_empty() else cmd)
				if not target.is_empty():
					map.objective_slots.append({
						"x":          (target["lx"] + target["rx"]) / 2,
						"y":          (target["ly"] + target["ry"]) / 2,
						"obj_type":   MakeshiftStockadeMapData.ObjType.RECOVER_GOODS,
						"shelter_id": target["id"],
					})

			MakeshiftStockadeMapData.ObjType.BURN_CAMP:
				# One marker per shelter — entire structure is flammable (s56.7.5).
				for sh: Dictionary in map.shelters:
					map.objective_slots.append({
						"x":          (sh["lx"] + sh["rx"]) / 2,
						"y":          (sh["ly"] + sh["ry"]) / 2,
						"obj_type":   MakeshiftStockadeMapData.ObjType.BURN_CAMP,
						"shelter_id": sh["id"],
					})

			MakeshiftStockadeMapData.ObjType.RESCUE_HOSTAGES:
				# Deepest non-command shelter (smallest ly = furthest from south gate).
				var target: Dictionary = _find_deepest_shelter(non_cmd)
				if target.is_empty():
					target = cmd  # single-shelter fallback
				if not target.is_empty():
					map.objective_slots.append({
						"x":          (target["lx"] + target["rx"]) / 2,
						"y":          (target["ly"] + target["ry"]) / 2,
						"obj_type":   MakeshiftStockadeMapData.ObjType.RESCUE_HOSTAGES,
						"shelter_id": target["id"],
					})


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

static func _find_command_shelter(map: MakeshiftStockadeMapData) -> Dictionary:
	for s: Dictionary in map.shelters:
		if s["type"] == MakeshiftStockadeMapData.ShelterType.COMMAND:
			return s
	return {}


static func _find_supply_shelter(map: MakeshiftStockadeMapData) -> Dictionary:
	for s: Dictionary in map.shelters:
		if s["type"] == MakeshiftStockadeMapData.ShelterType.SUPPLY:
			return s
	return {}


static func _find_deepest_shelter(non_cmd: Array) -> Dictionary:
	# Smallest ly = closest to north wall = furthest from the south gate.
	if non_cmd.is_empty():
		return {}
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
