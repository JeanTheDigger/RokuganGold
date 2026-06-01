class_name CaveTemplateGenerator
## Procedural cave map generator for ASCII map missions (s56.3 — LOCKED).
## Produces a CaveMapData from an insurgency Strength value and a set of
## objective types. Every call with the same seed_string is deterministic.
##
## Usage:
##   var map := CaveTemplateGenerator.generate("bandits_province7_year3", 4,
##                   [CaveMapData.ObjType.KILL_LEADER])


# ---------------------------------------------------------------------------
# Public API
# ---------------------------------------------------------------------------

static func generate(
		seed_str: String,
		insurgency_strength: int,
		objectives: Array,
		rng: RandomNumberGenerator = null) -> CaveMapData:

	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.seed = _str_to_seed(seed_str)

	var map := CaveMapData.new()
	map.seed_string = seed_str

	# Step 1 — pick size, rerolling upward if Strength can't fit (s56.3.1).
	var size: int = pick_size_category(insurgency_strength, rng)
	map.size_category = size

	var dim: Vector2i = CaveMapData.DIMS[size]
	map.width = dim.x
	map.height = dim.y

	# Step 2 — pick flow pattern from the size-weighted pool (s56.3.2).
	map.flow_pattern = pick_flow_pattern(size, rng)

	# Step 3 — carve all stone, then build rooms and corridors.
	map.init_tiles(Enums.TileType.WALL_STONE)

	var room_count: int = _pick_room_count(size, rng)
	_build_room_graph(map, room_count, rng)
	_carve_rooms(map)
	_carve_corridors(map)

	# Step 4 — entry points (s56.3.2).
	_place_entry_points(map, rng)

	# Step 5 — environmental features (s56.3.5).
	_place_features(map, rng)

	# Step 6 — population slots (s56.3.4).
	_place_population_slots(map, insurgency_strength, rng)

	# Step 7 — objective slots (s56.3.6).
	_place_objective_slots(map, objectives, rng)

	return map


# ---------------------------------------------------------------------------
# Size and flow selection
# ---------------------------------------------------------------------------

static func pick_size_category(insurgency_strength: int, rng: RandomNumberGenerator) -> int:
	# Roll a random size first, then enforce the Strength floor (s56.3.1).
	# Weights: SMALL 35%, MEDIUM 35%, LARGE 20%, EXTENSIVE 10%.
	var roll: int = rng.randi_range(0, 99)
	var raw: int
	if roll < 35:
		raw = CaveMapData.SizeCategory.SMALL
	elif roll < 70:
		raw = CaveMapData.SizeCategory.MEDIUM
	elif roll < 90:
		raw = CaveMapData.SizeCategory.LARGE
	else:
		raw = CaveMapData.SizeCategory.EXTENSIVE

	# Bump up if the rolled size can't house the insurgency population.
	while raw < CaveMapData.SizeCategory.EXTENSIVE:
		if CaveMapData.MAX_STRENGTH[raw] >= insurgency_strength:
			break
		raw += 1
	return raw


static func pick_flow_pattern(size_category: int, rng: RandomNumberGenerator) -> int:
	# s56.3.2: LINEAR most common for Small, BRANCHING for Medium,
	# LOOP for Large, WEB for Extensive only.
	match size_category:
		CaveMapData.SizeCategory.SMALL:
			# Linear 70%, Branching 30%.
			return CaveMapData.FlowPattern.LINEAR if rng.randi_range(0, 9) < 7 \
				else CaveMapData.FlowPattern.BRANCHING
		CaveMapData.SizeCategory.MEDIUM:
			# Branching 60%, Linear 30%, Loop 10%.
			var r: int = rng.randi_range(0, 9)
			if r < 6:
				return CaveMapData.FlowPattern.BRANCHING
			elif r < 9:
				return CaveMapData.FlowPattern.LINEAR
			else:
				return CaveMapData.FlowPattern.LOOP
		CaveMapData.SizeCategory.LARGE:
			# Loop 50%, Branching 35%, Linear 15%.
			var r: int = rng.randi_range(0, 19)
			if r < 10:
				return CaveMapData.FlowPattern.LOOP
			elif r < 17:
				return CaveMapData.FlowPattern.BRANCHING
			else:
				return CaveMapData.FlowPattern.LINEAR
		_:  # EXTENSIVE
			return CaveMapData.FlowPattern.WEB


# ---------------------------------------------------------------------------
# Room graph construction
# ---------------------------------------------------------------------------

static func _pick_room_count(size: int, rng: RandomNumberGenerator) -> int:
	var range_vec: Vector2i = CaveMapData.ROOM_RANGE[size]
	return rng.randi_range(range_vec.x, range_vec.y)


# Builds the room list and sets up connections based on flow pattern.
# Rooms are placed in depth layers; depth 0 = entry, max_depth = deep chamber.
static func _build_room_graph(map: CaveMapData, room_count: int, rng: RandomNumberGenerator) -> void:
	var pattern: int = map.flow_pattern
	var size: int = map.size_category

	# Ensure we always have entry + deep chamber + at least one middle room.
	if room_count < 3:
		room_count = 3

	var rooms: Array = []

	# --- Assign room types and depths ---
	# Always: entry tunnel at depth 0, deep chamber at max depth.
	# Middle rooms distributed by flow pattern.

	var max_depth: int = _compute_max_depth(room_count, pattern)

	# Entry tunnel — always room 0.
	rooms.append(_make_room(0, CaveMapData.RoomType.ENTRY_TUNNEL, 0))

	# Middle rooms.
	var middle_count: int = room_count - 2  # subtract entry and deep
	var depth_assignments: Array[int] = _assign_depths(middle_count, max_depth, pattern, rng)

	for i: int in range(middle_count):
		var depth: int = depth_assignments[i]
		var room_type: int = _pick_middle_room_type(i, middle_count, depth, max_depth, pattern, rng)
		rooms.append(_make_room(i + 1, room_type, depth))

	# Deep chamber — always last.
	rooms.append(_make_room(room_count - 1, CaveMapData.RoomType.DEEP_CHAMBER, max_depth))

	# --- Assign positions in pixel space ---
	_assign_room_positions(rooms, map.width, map.height, max_depth, rng)

	# --- Assign room sizes in pixel space ---
	_assign_room_sizes(rooms, size, rng)

	# --- Wire connections based on flow pattern ---
	_wire_connections(rooms, max_depth, pattern, rng)

	map.rooms = rooms


static func _compute_max_depth(room_count: int, pattern: int) -> int:
	# Deeper layouts for loop/web; shallower for linear.
	match pattern:
		CaveMapData.FlowPattern.LINEAR:
			return room_count - 1  # all rooms in one chain
		CaveMapData.FlowPattern.BRANCHING:
			return maxi(2, room_count / 2)
		CaveMapData.FlowPattern.LOOP:
			return maxi(3, room_count / 3)
		_:  # WEB
			return maxi(3, room_count / 4)


static func _assign_depths(
		middle_count: int,
		max_depth: int,
		pattern: int,
		rng: RandomNumberGenerator) -> Array[int]:
	var depths: Array[int] = []
	for i: int in range(middle_count):
		# Distribute across depths 1 .. max_depth-1.
		var d: int
		match pattern:
			CaveMapData.FlowPattern.LINEAR:
				# Evenly spaced along the chain.
				d = 1 + i * (max_depth - 1) / maxi(1, middle_count - 1)
			CaveMapData.FlowPattern.WEB:
				# Random spread across all intermediate depths.
				d = rng.randi_range(1, maxi(1, max_depth - 1))
			_:
				# Branch/Loop: cluster some rooms at the same depth to create junctions.
				d = rng.randi_range(1, maxi(1, max_depth - 1))
		depths.append(d)
	depths.sort()
	return depths


static func _pick_middle_room_type(
		index: int,
		total_middle: int,
		depth: int,
		max_depth: int,
		pattern: int,
		rng: RandomNumberGenerator) -> int:
	var depth_fraction: float = float(depth) / float(maxi(1, max_depth))

	# Junctions needed for branching/loop/web.
	var needs_junction: bool = (pattern != CaveMapData.FlowPattern.LINEAR)

	if needs_junction and depth_fraction < 0.5 and index == 0:
		return CaveMapData.RoomType.JUNCTION

	# Dead ends only in second half of map.
	if depth_fraction > 0.4 and rng.randi_range(0, 4) == 0:
		return CaveMapData.RoomType.DEAD_END

	# Large chambers cluster in the final third.
	if depth_fraction > 0.6 and rng.randi_range(0, 2) != 0:
		return CaveMapData.RoomType.LARGE_CHAMBER

	return CaveMapData.RoomType.SMALL_CHAMBER


static func _make_room(id: int, room_type: int, depth: int) -> Dictionary:
	return {
		"id":          id,
		"type":        room_type,
		"cx":          0,
		"cy":          0,
		"half_w":      2,
		"half_h":      2,
		"depth":       depth,
		"connections": [],
	}


# Spread rooms across the map using their depth layer.
# Depth 0 (entry) → near the bottom; max_depth (deep) → near the top.
# This gives "going north = going deeper" visual direction.
static func _assign_room_positions(
		rooms: Array,
		map_w: int,
		map_h: int,
		max_depth: int,
		rng: RandomNumberGenerator) -> void:
	# Group rooms by depth.
	var by_depth: Dictionary = {}
	for room: Dictionary in rooms:
		var d: int = room["depth"]
		if not by_depth.has(d):
			by_depth[d] = []
		by_depth[d].append(room)

	var margin: int = 4

	for depth: int in by_depth.keys():
		# Map depth → y coordinate: depth 0 at bottom (high y), max at top (low y).
		var t: float = float(depth) / float(maxi(1, max_depth))
		var base_y: int = int((map_h - margin * 2 - 1) * (1.0 - t)) + margin

		var layer_rooms: Array = by_depth[depth]
		var count: int = layer_rooms.size()

		# Spread horizontally across the width.
		for i: int in range(count):
			var frac: float = (float(i) + 0.5) / float(count)
			var cx: int = int(frac * (map_w - margin * 2)) + margin
			# Small jitter to avoid perfect grids.
			var jitter_x: int = rng.randi_range(-2, 2)
			var jitter_y: int = rng.randi_range(-2, 2)
			layer_rooms[i]["cx"] = clamp(cx + jitter_x, margin, map_w - margin - 1)
			layer_rooms[i]["cy"] = clamp(base_y + jitter_y, margin, map_h - margin - 1)


static func _assign_room_sizes(rooms: Array, size_category: int, rng: RandomNumberGenerator) -> void:
	for room: Dictionary in rooms:
		var half_w: int
		var half_h: int
		match room["type"]:
			CaveMapData.RoomType.ENTRY_TUNNEL:
				# Narrow: 1-2 tiles wide, 3-5 tiles long (half_w=1, half_h=2-3).
				half_w = 1
				half_h = rng.randi_range(2, 3)
			CaveMapData.RoomType.SMALL_CHAMBER:
				# 4-6 tiles across → half = 2-3.
				half_w = rng.randi_range(2, 3)
				half_h = rng.randi_range(2, 3)
			CaveMapData.RoomType.LARGE_CHAMBER:
				# 8-12 tiles across → half = 4-6.
				half_w = rng.randi_range(4, 6)
				half_h = rng.randi_range(3, 5)
			CaveMapData.RoomType.JUNCTION:
				# Open but not large: 4-6 tiles across → half = 2-3.
				half_w = rng.randi_range(2, 3)
				half_h = rng.randi_range(2, 3)
			CaveMapData.RoomType.DEAD_END:
				# Small recess.
				half_w = rng.randi_range(2, 3)
				half_h = rng.randi_range(2, 3)
			CaveMapData.RoomType.DEEP_CHAMBER:
				# Largest space in the cave. 10-15 tiles across → half = 5-7.
				# Scale with overall cave size.
				var base_min: int = 4 + size_category
				var base_max: int = 6 + size_category
				half_w = rng.randi_range(base_min, base_max)
				half_h = rng.randi_range(base_min - 1, base_max - 1)
			_:
				half_w = 2
				half_h = 2
		room["half_w"] = half_w
		room["half_h"] = half_h


# Wire connections: every room must be reachable from the entry.
# Strategy: connect rooms layer-by-layer, then add extra edges per pattern.
static func _wire_connections(
		rooms: Array,
		max_depth: int,
		pattern: int,
		rng: RandomNumberGenerator) -> void:
	if rooms.size() < 2:
		return

	# Build a lookup: depth → Array of room indices.
	var by_depth: Dictionary = {}
	for i: int in range(rooms.size()):
		var d: int = rooms[i]["depth"]
		if not by_depth.has(d):
			by_depth[d] = []
		by_depth[d].append(i)

	# Connect each depth layer to the next.
	for d: int in range(max_depth):
		if not by_depth.has(d) or not by_depth.has(d + 1):
			continue
		var from_layer: Array = by_depth[d]
		var to_layer: Array = by_depth[d + 1]
		# Each room in the upper layer connects to one from the lower.
		for to_idx: int in to_layer:
			var from_idx: int = from_layer[rng.randi_range(0, from_layer.size() - 1)]
			_connect(rooms, from_idx, to_idx)

		# For branching/web, also connect some within-layer siblings.
		if pattern == CaveMapData.FlowPattern.WEB or pattern == CaveMapData.FlowPattern.BRANCHING:
			if to_layer.size() >= 2:
				_connect(rooms, to_layer[0], to_layer[1])

	# Loop pattern: add a back-edge connecting max_depth to an early layer.
	if pattern == CaveMapData.FlowPattern.LOOP and rooms.size() >= 4:
		var deep_idx: int = rooms.size() - 1  # deep chamber
		# Connect deep chamber back to a room at depth 1 (not entry or deep).
		if by_depth.has(1) and by_depth[1].size() > 0:
			var loop_target: int = by_depth[1][0]
			_connect(rooms, deep_idx, loop_target)

	# Ensure entry (index 0) has at least one connection.
	if rooms[0]["connections"].is_empty() and rooms.size() >= 2:
		_connect(rooms, 0, 1)

	# Ensure every room is reachable via BFS from entry; connect orphans.
	var visited: Dictionary = {}
	var queue: Array[int] = [0]
	visited[0] = true
	while not queue.is_empty():
		var cur: int = queue.pop_front()
		for nb: int in rooms[cur]["connections"]:
			if not visited.has(nb):
				visited[nb] = true
				queue.append(nb)

	for i: int in range(rooms.size()):
		if not visited.has(i):
			# Connect this orphan to its nearest visited neighbour.
			var best: int = -1
			var best_dist: float = INF
			for j: int in visited.keys():
				var dx: float = rooms[i]["cx"] - rooms[j]["cx"]
				var dy: float = rooms[i]["cy"] - rooms[j]["cy"]
				var dist: float = dx * dx + dy * dy
				if dist < best_dist:
					best_dist = dist
					best = j
			if best >= 0:
				_connect(rooms, best, i)
				visited[i] = true


static func _connect(rooms: Array, a: int, b: int) -> void:
	if a == b:
		return
	if not rooms[a]["connections"].has(b):
		rooms[a]["connections"].append(b)
	if not rooms[b]["connections"].has(a):
		rooms[b]["connections"].append(a)


# ---------------------------------------------------------------------------
# Tile carving
# ---------------------------------------------------------------------------

static func _carve_rooms(map: CaveMapData) -> void:
	for room: Dictionary in map.rooms:
		var cx: int = room["cx"]
		var cy: int = room["cy"]
		var hw: int = room["half_w"]
		var hh: int = room["half_h"]

		var lx: int = clamp(cx - hw, 1, map.width - 2)
		var rx: int = clamp(cx + hw, 1, map.width - 2)
		var ly: int = clamp(cy - hh, 1, map.height - 2)
		var ry: int = clamp(cy + hh, 1, map.height - 2)

		map.fill_rect(lx, ly, rx, ry, Enums.TileType.FLOOR_STONE)


# L-shaped, 2-tile-wide corridors connect every room pair in the graph.
static func _carve_corridors(map: CaveMapData) -> void:
	var carved: Dictionary = {}

	for room: Dictionary in map.rooms:
		var aid: int = room["id"]
		for bid: int in room["connections"]:
			# Only carve each edge once.
			var key: String = "%d_%d" % [mini(aid, bid), maxi(aid, bid)]
			if carved.has(key):
				continue
			carved[key] = true

			var room_b: Dictionary = map.rooms[bid]
			_carve_l_corridor(map,
				room["cx"], room["cy"],
				room_b["cx"], room_b["cy"])


# Carves a 2-tile-wide L-shaped path between two centre points.
# Goes horizontal first, then vertical (or vice versa at random, but
# the generator seeds are deterministic so the choice is fixed per seed).
static func _carve_l_corridor(map: CaveMapData, ax: int, ay: int, bx: int, by: int) -> void:
	# Horizontal segment: ax→bx at y=ay.
	var x0: int = mini(ax, bx)
	var x1: int = maxi(ax, bx)
	for x: int in range(x0, x1 + 1):
		for dy: int in range(-1, 1):
			var yy: int = clamp(ay + dy, 1, map.height - 2)
			map.set_tile(x, yy, Enums.TileType.FLOOR_STONE)

	# Vertical segment: ay→by at x=bx.
	var y0: int = mini(ay, by)
	var y1: int = maxi(ay, by)
	for y: int in range(y0, y1 + 1):
		for dx: int in range(-1, 1):
			var xx: int = clamp(bx + dx, 1, map.width - 2)
			map.set_tile(xx, y, Enums.TileType.FLOOR_STONE)


# ---------------------------------------------------------------------------
# Entry points (s56.3.2)
# ---------------------------------------------------------------------------

static func _place_entry_points(map: CaveMapData, rng: RandomNumberGenerator) -> void:
	# The entry room (depth 0, index 0) defines the main entrance.
	# Place the ZONE_EXIT tile on the south wall, centred on the entry room cx.
	var entry_room: Dictionary = map.rooms[0]
	var ex: int = clamp(entry_room["cx"], 1, map.width - 2)
	var ey: int = map.height - 2  # south edge

	map.set_tile(ex, ey, Enums.TileType.ZONE_EXIT)
	map.entry_points.append({ "x": ex, "y": ey, "is_main": true })

	var size: int = map.size_category

	# Large caves: 30% chance of a second entrance (s56.3.2).
	if size == CaveMapData.SizeCategory.LARGE and rng.randi_range(0, 9) < 3:
		_add_secondary_entrance(map)

	# Extensive caves: always at least two entrances (s56.3.2).
	if size == CaveMapData.SizeCategory.EXTENSIVE:
		_add_secondary_entrance(map)


static func _add_secondary_entrance(map: CaveMapData) -> void:
	# Place a secondary exit near the deep chamber on the north edge.
	var deep_room: Dictionary = map.rooms[map.rooms.size() - 1]
	var sx: int = clamp(deep_room["cx"], 1, map.width - 2)
	var sy: int = 1  # north edge
	map.set_tile(sx, sy, Enums.TileType.ZONE_EXIT)
	map.entry_points.append({ "x": sx, "y": sy, "is_main": false })


# ---------------------------------------------------------------------------
# Environmental features (s56.3.5)
# ---------------------------------------------------------------------------

static func _place_features(map: CaveMapData, rng: RandomNumberGenerator) -> void:
	# Water: shallow streams or pools — 0-2 placements depending on cave size.
	var water_chances: int = map.size_category  # 0/1/2/3 placements max
	for _i: int in range(water_chances):
		if rng.randi_range(0, 2) == 0:
			_place_water_pool(map, rng)

	# Rubble/debris in some rooms — passable cover.
	for room: Dictionary in map.rooms:
		if room["type"] == CaveMapData.RoomType.DEEP_CHAMBER:
			continue  # Deep chamber stays clear for the boss fight.
		if rng.randi_range(0, 3) == 0:
			_scatter_rubble(map, room, rng)


static func _place_water_pool(map: CaveMapData, rng: RandomNumberGenerator) -> void:
	# Pick a random non-entry, non-deep room.
	var candidates: Array = []
	for room: Dictionary in map.rooms:
		if room["type"] != CaveMapData.RoomType.ENTRY_TUNNEL \
				and room["type"] != CaveMapData.RoomType.DEEP_CHAMBER:
			candidates.append(room)
	if candidates.is_empty():
		return
	var room: Dictionary = candidates[rng.randi_range(0, candidates.size() - 1)]
	var cx: int = room["cx"]
	var cy: int = room["cy"]
	# Small pool: 2-3 tiles wide.
	var pw: int = rng.randi_range(1, 2)
	var ph: int = rng.randi_range(1, 2)
	for y: int in range(cy - ph, cy + ph + 1):
		for x: int in range(cx - pw, cx + pw + 1):
			if map.get_tile(x, y) == Enums.TileType.FLOOR_STONE:
				map.set_tile(x, y, Enums.TileType.WATER_SHALLOW)


static func _scatter_rubble(map: CaveMapData, room: Dictionary, rng: RandomNumberGenerator) -> void:
	var cx: int = room["cx"]
	var cy: int = room["cy"]
	var hw: int = room["half_w"]
	var hh: int = room["half_h"]
	# Drop 2-5 rubble tiles at random positions inside the room.
	var count: int = rng.randi_range(2, 5)
	for _i: int in range(count):
		var rx: int = cx + rng.randi_range(-hw + 1, hw - 1)
		var ry: int = cy + rng.randi_range(-hh + 1, hh - 1)
		if map.get_tile(rx, ry) == Enums.TileType.FLOOR_STONE:
			map.set_tile(rx, ry, Enums.TileType.RUBBLE)


# ---------------------------------------------------------------------------
# Population placement (s56.3.4)
# ---------------------------------------------------------------------------

static func _place_population_slots(
		map: CaveMapData,
		insurgency_strength: int,
		rng: RandomNumberGenerator) -> void:

	var rooms: Array = map.rooms
	if rooms.is_empty():
		return

	var max_depth: int = rooms[rooms.size() - 1]["depth"]
	var size: int = map.size_category

	for room: Dictionary in rooms:
		var depth: int = room["depth"]
		var depth_frac: float = float(depth) / float(maxi(1, max_depth))
		var cx: int = room["cx"]
		var cy: int = room["cy"]

		match room["type"]:
			CaveMapData.RoomType.ENTRY_TUNNEL:
				# Sentry: 1-2 enemies at the entry (s56.3.4).
				map.population_slots.append({ "x": cx, "y": cy + 1,
					"role": CaveMapData.PopRole.SENTRY, "room_id": room["id"] })

			CaveMapData.RoomType.JUNCTION:
				# Guard post holds the junction (s56.3.4).
				map.population_slots.append({ "x": cx, "y": cy,
					"role": CaveMapData.PopRole.GUARD_POST, "room_id": room["id"] })

			CaveMapData.RoomType.SMALL_CHAMBER, CaveMapData.RoomType.LARGE_CHAMBER:
				# Density increases toward deep chamber (s56.3.4).
				if depth_frac < 0.33:
					# Early rooms: sparse, maybe nothing.
					if rng.randi_range(0, 2) != 0:
						break
				# Camp group.
				map.population_slots.append({ "x": cx, "y": cy,
					"role": CaveMapData.PopRole.CAMP_GROUP, "room_id": room["id"] })

			CaveMapData.RoomType.DEEP_CHAMBER:
				# Leader group (s56.3.4).
				map.population_slots.append({ "x": cx, "y": cy,
					"role": CaveMapData.PopRole.LEADER, "room_id": room["id"] })

			CaveMapData.RoomType.DEAD_END:
				# Dead ends are typically empty (reward exploration).
				pass

	# Add patrol waypoints for Medium+ caves (s56.3.4): one per 4-5 rooms.
	if size >= CaveMapData.SizeCategory.MEDIUM:
		var patrol_count: int = maxi(1, rooms.size() / 5)
		var mid_rooms: Array = []
		for r: Dictionary in rooms:
			if r["type"] == CaveMapData.RoomType.SMALL_CHAMBER \
					or r["type"] == CaveMapData.RoomType.LARGE_CHAMBER:
				mid_rooms.append(r)

		for _i: int in range(mini(patrol_count, mid_rooms.size())):
			var pr: Dictionary = mid_rooms[rng.randi_range(0, mid_rooms.size() - 1)]
			map.population_slots.append({
				"x": pr["cx"],
				"y": pr["cy"] - 1,
				"role": CaveMapData.PopRole.PATROL_WAYPOINT,
				"room_id": pr["id"]
			})


# ---------------------------------------------------------------------------
# Objective placement (s56.3.6)
# ---------------------------------------------------------------------------

static func _place_objective_slots(
		map: CaveMapData,
		objectives: Array,
		rng: RandomNumberGenerator) -> void:

	var rooms: Array = map.rooms
	if rooms.is_empty():
		return

	var deep_room: Dictionary = rooms[rooms.size() - 1]
	var first_third_depth: int = deep_room["depth"] / 3

	for obj_type: int in objectives:
		match obj_type:
			CaveMapData.ObjType.KILL_LEADER:
				# Leader is always in the Deep Chamber (s56.3.6).
				map.objective_slots.append({
					"x": deep_room["cx"],
					"y": deep_room["cy"],
					"obj_type": CaveMapData.ObjType.KILL_LEADER,
					"room_id": deep_room["id"]
				})

			CaveMapData.ObjType.RECOVER_GOODS:
				# Large Chamber near the Deep Chamber (s56.3.6).
				var candidate: Dictionary = _find_goods_room(rooms, deep_room, rng)
				map.objective_slots.append({
					"x": candidate["cx"],
					"y": candidate["cy"],
					"obj_type": CaveMapData.ObjType.RECOVER_GOODS,
					"room_id": candidate["id"]
				})

			CaveMapData.ObjType.BURN_POINT:
				# One burn point per occupied room (s56.3.6).
				for room: Dictionary in rooms:
					if room["depth"] <= first_third_depth:
						continue
					if room["type"] == CaveMapData.RoomType.DEAD_END:
						continue
					map.objective_slots.append({
						"x": room["cx"],
						"y": room["cy"],
						"obj_type": CaveMapData.ObjType.BURN_POINT,
						"room_id": room["id"]
					})

			CaveMapData.ObjType.RESCUE_HOSTAGES:
				# Small Chamber or Dead End, guarded but separate (s56.3.6).
				var hroom: Dictionary = _find_hostage_room(rooms, deep_room, first_third_depth, rng)
				map.objective_slots.append({
					"x": hroom["cx"],
					"y": hroom["cy"],
					"obj_type": CaveMapData.ObjType.RESCUE_HOSTAGES,
					"room_id": hroom["id"]
				})


static func _find_goods_room(rooms: Array, deep_room: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	# Prefer Large Chambers adjacent to (connected with) the Deep Chamber.
	var deep_id: int = deep_room["id"]
	var neighbours: Array = deep_room["connections"]
	for nid: int in neighbours:
		if rooms[nid]["type"] == CaveMapData.RoomType.LARGE_CHAMBER:
			return rooms[nid]
	# Fallback: any Large Chamber in the final half.
	var half_depth: int = deep_room["depth"] / 2
	for room: Dictionary in rooms:
		if room["type"] == CaveMapData.RoomType.LARGE_CHAMBER and room["depth"] >= half_depth:
			if room["id"] != deep_id:
				return room
	# Last fallback: any non-deep room.
	for room: Dictionary in rooms:
		if room["id"] != deep_id:
			return room
	return deep_room


static func _find_hostage_room(
		rooms: Array,
		deep_room: Dictionary,
		first_third_depth: int,
		rng: RandomNumberGenerator) -> Dictionary:
	# Prefer Dead Ends or Small Chambers not in the first third and not the deep chamber.
	var candidates: Array = []
	for room: Dictionary in rooms:
		if room["id"] == deep_room["id"]:
			continue
		if room["depth"] <= first_third_depth:
			continue
		if room["type"] == CaveMapData.RoomType.DEAD_END \
				or room["type"] == CaveMapData.RoomType.SMALL_CHAMBER:
			candidates.append(room)
	if not candidates.is_empty():
		return candidates[rng.randi_range(0, candidates.size() - 1)]
	# Fallback: any room that isn't the deep chamber.
	for room: Dictionary in rooms:
		if room["id"] != deep_room["id"]:
			return room
	return deep_room


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
