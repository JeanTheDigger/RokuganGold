class_name RuinedStructureGenerator
## Procedural ruined-structure map generator for ASCII map missions (s56.12 — LOCKED).
## Every call with the same seed_string is deterministic.
##
## Usage:
##   var map := RuinedStructureGenerator.generate(
##       "bandits_estate_y5", 4,
##       [RuinedStructureMapData.ObjType.KILL_LEADER])
##
## Coordinate convention: Y=0 is north (top); Y=height-1 is south (approach side).
## Main entrance gap is in the south outer wall. Player approaches from south.
## Architecture-then-decay: full grid of rooms drawn first, then cells collapse.


# ---------------------------------------------------------------------------
# Layout constants — PROVISIONAL structural parameters (GDD s56.12 specifies
# shape and features but not exact tile dimensions).
# ---------------------------------------------------------------------------

# Margin from map edge to outer perimeter wall, per size category.
const _STRUCT_MARGIN: Array[int] = [6, 7, 8]

# Room grid (cols × rows) per size category.
const _GRID_DIMS: Array[Vector2i] = [
	Vector2i(2, 2),   # SMALL_RUIN
	Vector2i(3, 3),   # MEDIUM_RUIN
	Vector2i(4, 4),   # LARGE_RUIN
]

# Main entrance gap width (tiles) in the south outer wall.
const _ENTRANCE_W: int = 2

# Wall gap count range [min, max] per size (s56.12.3).
const _GAP_COUNT_RANGE: Array[Vector2i] = [
	Vector2i(1, 2),   # SMALL  — "one or two gaps"
	Vector2i(3, 4),   # MEDIUM — "three or four gaps"
	Vector2i(5, 7),   # LARGE  — "many, making the perimeter porous"
]

# Probability out of 10 that an inner wall tile is WALL_WOOD vs WALL_STONE.
const _INNER_WOOD_PROB: int = 4   # 40% — PROVISIONAL

# Upper floor: 0=never, 4=40%, 10=always (checked as rng.randi_range(0,9) < value).
const _UPPER_FLOOR_CHANCE: Array[int] = [0, 4, 10]

# Probability out of 10 that a room/collapsed section is marked unstable.
const _UNSTABLE_PROB: int = 2   # 20% per section — PROVISIONAL


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

static func generate(
		seed_str: String,
		insurgency_strength: int,
		objectives: Array,
		rng: RandomNumberGenerator = null) -> RuinedStructureMapData:

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = _str_to_seed(seed_str)

	var map := RuinedStructureMapData.new()
	map.seed_string = seed_str

	# ---- Size and dimensions -------------------------------------------------
	var size: int = pick_size_category(insurgency_strength, rng)
	map.size_category = size

	var dim: Vector2i = RuinedStructureMapData.DIMS[size]
	map.width  = dim.x
	map.height = dim.y

	var margin: int = _STRUCT_MARGIN[size]
	map.struct_lx = margin
	map.struct_rx = map.width  - 1 - margin
	map.struct_ty = margin
	map.struct_by = map.height - 1 - margin

	var gd: Vector2i = _GRID_DIMS[size]
	map.grid_cols = gd.x
	map.grid_rows = gd.y
	var cols: int = map.grid_cols
	var rows: int = map.grid_rows

	# ---- Cell floor-bound arrays --------------------------------------------
	var interior_lx: int = map.struct_lx + 1
	var interior_rx: int = map.struct_rx - 1
	var interior_ty: int = map.struct_ty + 1
	var interior_by: int = map.struct_by - 1

	var x_starts: Array[int] = _divide_range(interior_lx, interior_rx, cols)
	var x_ends:   Array[int] = _range_ends(x_starts, interior_rx, cols)
	var y_starts: Array[int] = _divide_range(interior_ty, interior_by, rows)
	var y_ends:   Array[int] = _range_ends(y_starts, interior_by, rows)

	# ---- Entrance and origin -------------------------------------------------
	var ent_cx: int = (map.struct_lx + map.struct_rx) / 2
	map.entrance_x  = ent_cx
	map.ruin_origin = rng.randi_range(0, RuinedStructureMapData.RuinOrigin.NATURAL_DECAY)

	# ---- Base tiles: open-ground approach ------------------------------------
	map.init_tiles(Enums.TileType.FLOOR_GRASS)

	# ---- Interior FLOOR_STONE (intact building floor) -----------------------
	map.fill_rect(interior_lx, interior_ty, interior_rx, interior_by,
			Enums.TileType.FLOOR_STONE)

	# ---- Outer perimeter WALL_STONE -----------------------------------------
	_draw_perimeter(map)

	# ---- Inner grid walls ---------------------------------------------------
	_draw_inner_walls(map, x_starts, y_starts, cols, rows, rng)

	# ---- Main entrance gap in south wall ------------------------------------
	var ent_lx: int = ent_cx - _ENTRANCE_W / 2
	var ent_rx: int = ent_lx + _ENTRANCE_W - 1
	for x in range(ent_lx, ent_rx + 1):
		map.set_tile(x, map.struct_by, Enums.TileType.FLOOR_STONE)

	# ---- Collapse selection -------------------------------------------------
	var total_cells: int = cols * rows
	var range_v: Vector2i = RuinedStructureMapData.ROOM_RANGE[size]
	var intact_target: int = clampi(rng.randi_range(range_v.x, range_v.y),
			1, total_cells)

	var order: Array[int] = []
	for i in range(total_cells):
		order.append(i)
	for i in range(total_cells - 1, 0, -1):
		var j: int = rng.randi_range(0, i)
		var tmp: int = order[i]
		order[i] = order[j]
		order[j] = tmp

	var collapsed_set: Dictionary = {}
	for k in range(intact_target, total_cells):
		collapsed_set[order[k]] = true

	# ---- Build rooms and collapsed_sections ---------------------------------
	var room_to_cell: Array[int] = []   # room index → cell_id
	for r in range(rows):
		for c in range(cols):
			var cid: int    = r * cols + c
			var lx:  int    = x_starts[c]
			var rx_: int    = x_ends[c]
			var ly:  int    = y_starts[r]
			var ry:  int    = y_ends[r]
			var is_inner: bool = (c > 0 and c < cols - 1 and r > 0 and r < rows - 1)
			if collapsed_set.has(cid):
				map.collapsed_sections.append({
					"id": map.collapsed_sections.size(),
					"lx": lx, "ly": ly, "rx": rx_, "ry": ry,
				})
			else:
				room_to_cell.append(cid)
				map.rooms.append({
					"id":             map.rooms.size(),
					"lx": lx, "ly": ly, "rx": rx_, "ry": ry,
					"is_inner":       is_inner,
					"is_leader_room": false,
					"is_storage_room": false,
				})

	# ---- Designate leader / storage rooms -----------------------------------
	_designate_special_rooms(map, cols, rows, collapsed_set, room_to_cell)

	# ---- Doorways between adjacent intact rooms -----------------------------
	_place_doorways(map, cols, rows, x_starts, x_ends, y_starts, y_ends,
			collapsed_set)

	# ---- Carve collapsed cells (FLOOR_DIRT + RUBBLE, remove inner walls) ----
	_carve_collapsed(map, x_starts, x_ends, y_starts, y_ends, cols, rows,
			collapsed_set)

	# ---- Wall gaps in outer perimeter (alternate entries) -------------------
	_punch_wall_gaps(map, rng)

	# ---- Upper floor (s56.12.3) --------------------------------------------
	if rng.randi_range(0, 9) < _UPPER_FLOOR_CHANCE[size]:
		map.has_upper_floor = true
		_place_upper_floor(map, rng)

	# ---- Unstable sections --------------------------------------------------
	_mark_unstable_sections(map, rng)

	# ---- Firepits in intact rooms -------------------------------------------
	_place_firepits(map)

	# ---- Entry vectors ------------------------------------------------------
	_place_entry_vectors(map, ent_lx, ent_rx)

	# ---- Population slots ---------------------------------------------------
	_place_population_slots(map, rng)

	# ---- Objective markers --------------------------------------------------
	_place_objective_slots(map, objectives)

	return map


# ---------------------------------------------------------------------------
# Size selection (s56.12.2)
# ---------------------------------------------------------------------------

static func pick_size_category(
		insurgency_strength: int,
		rng: RandomNumberGenerator) -> int:

	var raw: int
	if insurgency_strength <= RuinedStructureMapData.MAX_STRENGTH[
			RuinedStructureMapData.SizeCategory.SMALL_RUIN]:
		raw = RuinedStructureMapData.SizeCategory.SMALL_RUIN \
			if rng.randi_range(0, 9) < 7 \
			else RuinedStructureMapData.SizeCategory.MEDIUM_RUIN
	elif insurgency_strength <= RuinedStructureMapData.MAX_STRENGTH[
			RuinedStructureMapData.SizeCategory.MEDIUM_RUIN]:
		raw = RuinedStructureMapData.SizeCategory.MEDIUM_RUIN
	else:
		raw = RuinedStructureMapData.SizeCategory.LARGE_RUIN
	while raw < RuinedStructureMapData.SizeCategory.LARGE_RUIN:
		if RuinedStructureMapData.MAX_STRENGTH[raw] >= insurgency_strength:
			break
		raw += 1
	return raw


# ---------------------------------------------------------------------------
# Cell coordinate helpers
# ---------------------------------------------------------------------------

static func _divide_range(first: int, last: int, count: int) -> Array[int]:
	# Divide [first..last] into `count` floor segments separated by 1-tile walls.
	# Returns the start coordinate of each segment's floor area.
	var starts: Array[int] = []
	var total: int = last - first + 1 - (count - 1)
	var base:  int = total / count
	var extra: int = total % count
	var cursor: int = first
	for i in range(count):
		starts.append(cursor)
		var seg: int = base + (1 if i < extra else 0)
		cursor += seg + 1   # +1 skips the inner wall
	return starts


static func _range_ends(
		starts: Array[int], last: int, count: int) -> Array[int]:
	var ends: Array[int] = []
	for i in range(count):
		if i < count - 1:
			ends.append(starts[i + 1] - 2)   # inner wall at starts[i+1]-1
		else:
			ends.append(last)
	return ends


# ---------------------------------------------------------------------------
# Tile placement
# ---------------------------------------------------------------------------

static func _draw_perimeter(map: RuinedStructureMapData) -> void:
	var lx: int = map.struct_lx; var rx: int = map.struct_rx
	var ty: int = map.struct_ty; var by: int = map.struct_by
	for x in range(lx, rx + 1):
		map.set_tile(x, ty, Enums.TileType.WALL_STONE)
		map.set_tile(x, by, Enums.TileType.WALL_STONE)
	for y in range(ty + 1, by):
		map.set_tile(lx, y, Enums.TileType.WALL_STONE)
		map.set_tile(rx, y, Enums.TileType.WALL_STONE)


static func _draw_inner_walls(
		map: RuinedStructureMapData,
		x_starts: Array[int], y_starts: Array[int],
		cols: int, rows: int,
		rng: RandomNumberGenerator) -> void:

	var ty: int = map.struct_ty + 1
	var by: int = map.struct_by - 1
	var lx: int = map.struct_lx + 1
	var rx: int = map.struct_rx - 1

	# Vertical separators between columns.
	for c in range(cols - 1):
		var wall_x: int = x_starts[c + 1] - 1
		for y in range(ty, by + 1):
			var tile: int = Enums.TileType.WALL_WOOD \
				if rng.randi_range(0, 9) < _INNER_WOOD_PROB \
				else Enums.TileType.WALL_STONE
			map.set_tile(wall_x, y, tile)

	# Horizontal separators between rows.
	for r in range(rows - 1):
		var wall_y: int = y_starts[r + 1] - 1
		for x in range(lx, rx + 1):
			var tile: int = Enums.TileType.WALL_WOOD \
				if rng.randi_range(0, 9) < _INNER_WOOD_PROB \
				else Enums.TileType.WALL_STONE
			map.set_tile(x, wall_y, tile)


static func _designate_special_rooms(
		map: RuinedStructureMapData,
		cols: int, rows: int,
		collapsed_set: Dictionary,
		room_to_cell: Array[int]) -> void:

	if map.rooms.is_empty():
		return

	# Leader room: most defensible = prefer inner cell, most intact neighbours.
	var best_l_idx: int = 0
	var best_l_score: int = -1
	for i in range(map.rooms.size()):
		var rm: Dictionary = map.rooms[i]
		var cid: int = room_to_cell[i]
		var c:   int = cid % cols
		var r:   int = cid / cols
		var score: int = _intact_neighbour_count(c, r, cols, rows, collapsed_set)
		if rm["is_inner"]:
			score += 6
		if score > best_l_score:
			best_l_score = score
			best_l_idx   = i

	map.rooms[best_l_idx]["is_leader_room"] = true

	# Storage room: most structurally sound = outer cell (solid exterior walls),
	# most intact neighbours, not the leader room.
	var best_s_idx:   int = -1
	var best_s_score: int = -1
	for i in range(map.rooms.size()):
		if i == best_l_idx:
			continue
		var rm: Dictionary = map.rooms[i]
		var cid: int = room_to_cell[i]
		var c:   int = cid % cols
		var r:   int = cid / cols
		var score: int = _intact_neighbour_count(c, r, cols, rows, collapsed_set)
		if not rm["is_inner"]:
			score += 3
		if score > best_s_score:
			best_s_score = score
			best_s_idx   = i

	if best_s_idx >= 0:
		map.rooms[best_s_idx]["is_storage_room"] = true


static func _intact_neighbour_count(
		c: int, r: int, cols: int, rows: int,
		collapsed_set: Dictionary) -> int:
	var count: int = 0
	for dc in [-1, 1]:
		var nc: int = c + dc
		if nc >= 0 and nc < cols and not collapsed_set.has(r * cols + nc):
			count += 1
	for dr in [-1, 1]:
		var nr: int = r + dr
		if nr >= 0 and nr < rows and not collapsed_set.has(nr * cols + c):
			count += 1
	return count


static func _place_doorways(
		map: RuinedStructureMapData,
		cols: int, rows: int,
		x_starts: Array[int], x_ends: Array[int],
		y_starts: Array[int], y_ends: Array[int],
		collapsed_set: Dictionary) -> void:

	# Horizontal adjacency: door in vertical inner wall between col c and c+1.
	for r in range(rows):
		for c in range(cols - 1):
			if collapsed_set.has(r * cols + c) or collapsed_set.has(r * cols + c + 1):
				continue
			var wall_x: int = x_starts[c + 1] - 1
			var door_y: int = (y_starts[r] + y_ends[r]) / 2
			map.set_tile(wall_x, door_y, Enums.TileType.DOOR_WOOD_CLOSED)

	# Vertical adjacency: door in horizontal inner wall between row r and r+1.
	for r in range(rows - 1):
		for c in range(cols):
			if collapsed_set.has(r * cols + c) or collapsed_set.has((r + 1) * cols + c):
				continue
			var wall_y: int = y_starts[r + 1] - 1
			var door_x: int = (x_starts[c] + x_ends[c]) / 2
			map.set_tile(door_x, wall_y, Enums.TileType.DOOR_WOOD_CLOSED)


static func _carve_collapsed(
		map: RuinedStructureMapData,
		x_starts: Array[int], x_ends: Array[int],
		y_starts: Array[int], y_ends: Array[int],
		cols: int, rows: int,
		collapsed_set: Dictionary) -> void:

	for cid in collapsed_set:
		var c:   int = cid % cols
		var r:   int = cid / cols
		var lx:  int = x_starts[c]; var rx_: int = x_ends[c]
		var ly:  int = y_starts[r]; var ry:  int = y_ends[r]

		# Floor becomes FLOOR_DIRT; scatter RUBBLE (deterministic pattern).
		for y in range(ly, ry + 1):
			for x in range(lx, rx_ + 1):
				if (x * 7 + y * 13) % 10 < 4:
					map.set_tile(x, y, Enums.TileType.RUBBLE)
				else:
					map.set_tile(x, y, Enums.TileType.FLOOR_DIRT)

		# Convert inner walls adjacent to this cell into RUBBLE (collapsed masonry).
		var _rubble_wall_x := func(wx: int, y_lo: int, y_hi: int) -> void:
			for y in range(y_lo, y_hi + 1):
				var t: int = map.get_tile(wx, y)
				if t == Enums.TileType.WALL_STONE or t == Enums.TileType.WALL_WOOD:
					map.set_tile(wx, y, Enums.TileType.RUBBLE)
		var _rubble_wall_y := func(wy: int, x_lo: int, x_hi: int) -> void:
			for x in range(x_lo, x_hi + 1):
				var t: int = map.get_tile(x, wy)
				if t == Enums.TileType.WALL_STONE or t == Enums.TileType.WALL_WOOD:
					map.set_tile(x, wy, Enums.TileType.RUBBLE)

		if c > 0:
			_rubble_wall_x.call(x_starts[c] - 1, ly, ry)
		if c < cols - 1:
			_rubble_wall_x.call(x_ends[c] + 1, ly, ry)
		if r > 0:
			_rubble_wall_y.call(y_starts[r] - 1, lx, rx_)
		if r < rows - 1:
			_rubble_wall_y.call(y_ends[r] + 1, lx, rx_)


static func _punch_wall_gaps(
		map: RuinedStructureMapData,
		rng: RandomNumberGenerator) -> void:

	var range_v: Vector2i = _GAP_COUNT_RANGE[map.size_category]
	var count:   int      = rng.randi_range(range_v.x, range_v.y)
	# South already has main entrance; allow extra south gaps for LARGE.
	var sides: Array[String] = ["N", "E", "W"]
	if count > 3:
		sides.append("S")

	var placed:   int = 0
	var attempts: int = 0
	while placed < count and attempts < 60:
		attempts += 1
		var side: String = sides[rng.randi_range(0, sides.size() - 1)]
		var gx: int = -1
		var gy: int = -1
		match side:
			"N":
				gx = rng.randi_range(map.struct_lx + 3, map.struct_rx - 3)
				gy = map.struct_ty
			"S":
				gx = rng.randi_range(map.struct_lx + 3, map.struct_rx - 3)
				if abs(gx - map.entrance_x) < _ENTRANCE_W + 2:
					continue
				gy = map.struct_by
			"E":
				gx = map.struct_rx
				gy = rng.randi_range(map.struct_ty + 3, map.struct_by - 3)
			"W":
				gx = map.struct_lx
				gy = rng.randi_range(map.struct_ty + 3, map.struct_by - 3)
		if gx < 0 or gy < 0:
			continue
		if map.get_tile(gx, gy) != Enums.TileType.WALL_STONE:
			continue
		map.set_tile(gx, gy, Enums.TileType.FLOOR_STONE)
		map.wall_gaps.append({"x": gx, "y": gy, "side": side})
		placed += 1


static func _place_upper_floor(
		map: RuinedStructureMapData,
		rng: RandomNumberGenerator) -> void:

	# Locate the leader room as the upper-floor host.
	var host_rm: Dictionary = {}
	for rm in map.rooms:
		if rm["is_leader_room"]:
			host_rm = rm
			break
	if host_rm.is_empty() and not map.rooms.is_empty():
		host_rm = map.rooms[0]
	if host_rm.is_empty():
		return

	var lx: int = host_rm["lx"]; var rx_: int = host_rm["rx"]
	var ly: int = host_rm["ly"]; var ry:  int = host_rm["ry"]
	var uf_lx: int = lx + 1; var uf_rx: int = rx_ - 1
	var uf_ly: int = ly + 1; var uf_ry: int = ry  - 1
	if uf_rx <= uf_lx or uf_ry <= uf_ly:
		return

	map.upper_floor_sections.append({
		"lx": uf_lx, "ly": uf_ly, "rx": uf_rx, "ry": uf_ry,
		"room_id": host_rm["id"],
	})

	# Stairwell: narrow FLOOR_STONE column on one side of the room.
	var stair_x: int = lx + 1
	var stair_y: int = clampi(ry + 0, ly, ry)   # bottom edge of room
	map.stairwells.append({"x": stair_x, "y": stair_y, "room_id": host_rm["id"]})


static func _mark_unstable_sections(
		map: RuinedStructureMapData,
		rng: RandomNumberGenerator) -> void:

	for rm in map.rooms:
		if rng.randi_range(0, 9) < _UNSTABLE_PROB:
			map.unstable_sections.append({
				"lx": rm["lx"], "ly": rm["ly"],
				"rx": rm["rx"], "ry": rm["ry"],
			})
	for sec in map.collapsed_sections:
		if rng.randi_range(0, 9) < _UNSTABLE_PROB:
			map.unstable_sections.append({
				"lx": sec["lx"], "ly": sec["ly"],
				"rx": sec["rx"], "ry": sec["ry"],
			})


static func _place_firepits(map: RuinedStructureMapData) -> void:
	var fid: int = 0
	for rm in map.rooms:
		var fx: int = (rm["lx"] + rm["rx"]) / 2
		var fy: int = (rm["ly"] + rm["ry"]) / 2
		map.set_tile(fx, fy, Enums.TileType.FIRE)
		map.firepits.append({"id": fid, "x": fx, "y": fy})
		fid += 1


static func _place_entry_vectors(
		map: RuinedStructureMapData, ent_lx: int, ent_rx: int) -> void:

	# Main entrance: ZONE_EXIT on the south-wall gap tiles.
	for x in range(ent_lx, ent_rx + 1):
		map.set_tile(x, map.struct_by, Enums.TileType.ZONE_EXIT)
	var mx: int = (ent_lx + ent_rx) / 2
	map.entry_vectors.append({
		"x": mx, "y": map.struct_by,
		"is_main": true, "is_gap": false,
	})

	# Wall gaps: ZONE_EXIT on the gap tile itself.
	for gap in map.wall_gaps:
		map.set_tile(gap["x"], gap["y"], Enums.TileType.ZONE_EXIT)
		map.entry_vectors.append({
			"x": gap["x"], "y": gap["y"],
			"is_main": false, "is_gap": true,
		})


static func _place_population_slots(
		map: RuinedStructureMapData,
		rng: RandomNumberGenerator) -> void:

	# Sentry: at the main entrance (inside the structure, facing the gap).
	map.population_slots.append({
		"x": map.entrance_x,
		"y": clampi(map.struct_by - 2, map.struct_ty + 1, map.struct_by - 1),
		"role":    RuinedStructureMapData.PopRole.SENTRY,
		"zone":    RuinedStructureMapData.Zone.INTACT_ROOM,
		"room_id": -1,
	})

	# Room Groups: 2–4 per occupied non-leader intact room (s56.12.4).
	for rm in map.rooms:
		if rm["is_leader_room"]:
			continue
		var cx: int = (rm["lx"] + rm["rx"]) / 2
		var cy: int = (rm["ly"] + rm["ry"]) / 2
		map.population_slots.append({
			"x": cx, "y": cy,
			"role":    RuinedStructureMapData.PopRole.ROOM_GROUP,
			"zone":    RuinedStructureMapData.Zone.INTACT_ROOM,
			"room_id": rm["id"],
		})
		# Second slot in wider rooms.
		if rm["rx"] - rm["lx"] >= 8:
			map.population_slots.append({
				"x": cx + 2, "y": cy + 1,
				"role":    RuinedStructureMapData.PopRole.ROOM_GROUP,
				"zone":    RuinedStructureMapData.Zone.INTACT_ROOM,
				"room_id": rm["id"],
			})

	# Rubble Lurkers: one per collapsed section (s56.12.4: "easy to miss").
	for sec in map.collapsed_sections:
		var lx: int = sec["lx"]; var rx_: int = sec["rx"]
		var ly: int = sec["ly"]; var ry:  int = sec["ry"]
		var px: int = lx + rng.randi_range(0, maxi(0, rx_ - lx))
		var py: int = ly + rng.randi_range(0, maxi(0, ry  - ly))
		map.population_slots.append({
			"x": px, "y": py,
			"role":    RuinedStructureMapData.PopRole.RUBBLE_LURKER,
			"zone":    RuinedStructureMapData.Zone.COLLAPSED,
			"room_id": -1,
		})

	# Upper Floor Holder: on surviving upper level (s56.12.4).
	if map.has_upper_floor and not map.upper_floor_sections.is_empty():
		var ufs: Dictionary = map.upper_floor_sections[0]
		map.population_slots.append({
			"x": (ufs["lx"] + ufs["rx"]) / 2,
			"y": (ufs["ly"] + ufs["ry"]) / 2,
			"role":    RuinedStructureMapData.PopRole.UPPER_FLOOR_HOLDER,
			"zone":    RuinedStructureMapData.Zone.UPPER_FLOOR,
			"room_id": ufs.get("room_id", -1),
		})

	# Leader Group: in the most defensible intact room (s56.12.4: 20–25% of roster).
	for rm in map.rooms:
		if not rm["is_leader_room"]:
			continue
		var cx: int = (rm["lx"] + rm["rx"]) / 2
		var cy: int = (rm["ly"] + rm["ry"]) / 2
		map.population_slots.append({
			"x": cx, "y": cy,
			"role":    RuinedStructureMapData.PopRole.LEADER_GROUP,
			"zone":    RuinedStructureMapData.Zone.INTACT_ROOM,
			"room_id": rm["id"],
		})
		map.population_slots.append({
			"x": cx + 2, "y": cy,
			"role":    RuinedStructureMapData.PopRole.LEADER_GROUP,
			"zone":    RuinedStructureMapData.Zone.INTACT_ROOM,
			"room_id": rm["id"],
		})
		break


static func _place_objective_slots(
		map: RuinedStructureMapData, objectives: Array) -> void:

	var leader_rm:  Dictionary = {}
	var storage_rm: Dictionary = {}
	for rm in map.rooms:
		if rm["is_leader_room"]:
			leader_rm = rm
		if rm["is_storage_room"]:
			storage_rm = rm
	var fallback: Dictionary = map.rooms[0] if not map.rooms.is_empty() else {}

	for obj in objectives:
		match int(obj):
			RuinedStructureMapData.ObjType.KILL_LEADER:
				# In the most defensible intact room (s56.12.6).
				var rm: Dictionary = leader_rm if not leader_rm.is_empty() else fallback
				if rm.is_empty():
					continue
				map.objective_slots.append({
					"x": (rm["lx"] + rm["rx"]) / 2,
					"y": (rm["ly"] + rm["ry"]) / 2,
					"obj_type": RuinedStructureMapData.ObjType.KILL_LEADER,
					"room_id":  rm["id"],
				})

			RuinedStructureMapData.ObjType.RECOVER_GOODS:
				# Most structurally sound room (storage / cellar) (s56.12.6).
				var rm: Dictionary = storage_rm if not storage_rm.is_empty() \
						else (leader_rm if not leader_rm.is_empty() else fallback)
				if rm.is_empty():
					continue
				map.objective_slots.append({
					"x": (rm["lx"] + rm["rx"]) / 2 + 1,
					"y": (rm["ly"] + rm["ry"]) / 2,
					"obj_type": RuinedStructureMapData.ObjType.RECOVER_GOODS,
					"room_id":  rm["id"],
				})

			RuinedStructureMapData.ObjType.BURN_CAMP:
				# One marker per occupied intact room (s56.12.6).
				for rm2: Dictionary in map.rooms:
					map.objective_slots.append({
						"x": (rm2["lx"] + rm2["rx"]) / 2,
						"y": (rm2["ly"] + rm2["ry"]) / 2,
						"obj_type": RuinedStructureMapData.ObjType.BURN_CAMP,
						"room_id":  rm2["id"],
					})

			RuinedStructureMapData.ObjType.RESCUE_HOSTAGES:
				# Inner room, limited access — improvised cell (s56.12.6).
				var rm: Dictionary = {}
				for candidate in map.rooms:
					if candidate["is_inner"] and candidate.get("id", -1) != \
							(leader_rm.get("id", -2) if not leader_rm.is_empty() else -2):
						rm = candidate
						break
				if rm.is_empty():
					rm = storage_rm if not storage_rm.is_empty() else fallback
				if rm.is_empty():
					continue
				map.objective_slots.append({
					"x": (rm["lx"] + rm["rx"]) / 2,
					"y": (rm["ly"] + rm["ry"]) / 2 + 1,
					"obj_type": RuinedStructureMapData.ObjType.RESCUE_HOSTAGES,
					"room_id":  rm["id"],
				})

			RuinedStructureMapData.ObjType.INVESTIGATE:
				# Origin-specific evidence in the most structurally sound room (s56.12.6).
				var rm: Dictionary = storage_rm if not storage_rm.is_empty() \
						else (leader_rm if not leader_rm.is_empty() else fallback)
				if rm.is_empty():
					continue
				map.objective_slots.append({
					"x": (rm["lx"] + rm["rx"]) / 2 - 1,
					"y": (rm["ly"] + rm["ry"]) / 2 - 1,
					"obj_type": RuinedStructureMapData.ObjType.INVESTIGATE,
					"room_id":  rm["id"],
				})


# ---------------------------------------------------------------------------
# FNV-1a 32-bit seed from string
# ---------------------------------------------------------------------------

static func _str_to_seed(s: String) -> int:
	var h: int = 0x811C9DC5
	for i in range(s.length()):
		h ^= s.unicode_at(i)
		h  = (h * 0x01000193) & 0xFFFFFFFF
	return h
