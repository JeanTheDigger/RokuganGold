class_name UrbanHideoutGenerator
## s56.15 Urban Hideout hidden-level generator --- LOCKED.
## Generates the ASCII map for the hidden level of an Urban Hideout mission.
## Surface search phase is BLOCKED on Settlement Building Framework (s4.4.1).
## All static functions; no instance state.

const _T := Enums.TileType

# -- Constants ----------------------------------------------------------------

const _WALL_STONE  := _T.WALL_STONE
const _FLOOR_STONE := _T.FLOOR_STONE
const _DOOR        := _T.DOOR_WOOD_CLOSED
const _ZONE_EXIT   := _T.ZONE_EXIT

# Taint levels by zone distance from entrance.
const _TAINT_ENTRANCE: int = 0
const _TAINT_ROOM:     int = 1
const _TAINT_DEEP:     int = 2
const _TAINT_RITUAL:   int = 3

# -- Public entry point -------------------------------------------------------

## Generates a complete UrbanHideoutMapData for the hidden level.
## seed_str   : deterministic seed string (quest seed + province + insurgency ID)
## strength   : insurgency Strength, used to select size category
## obj_types  : Array[int] of ObjType values to place
static func generate(seed_str: String, strength: int, obj_types: Array) -> UrbanHideoutMapData:
	var rng: int = _fnv1a(seed_str)
	var size: int = _pick_size(strength)
	var map := UrbanHideoutMapData.new()
	map.size_category = size

	var dim: Vector2i = UrbanHideoutMapData.DIMS[size]
	var w: int = dim.x
	var h: int = dim.y
	map.init_tiles(w, h, _WALL_STONE)

	rng = _place_rooms(map, w, h, size, rng)
	_connect_rooms(map)
	_place_entrance(map)
	_place_doors(map)
	_place_zombie_screen(map, size)
	rng = _place_evidence(map, rng)
	_place_population(map, size, rng)
	_place_objectives(map, obj_types)
	return map

# -- Size selection -----------------------------------------------------------

static func _pick_size(strength: int) -> int:
	if strength <= 3:
		return UrbanHideoutMapData.SizeCategory.SINGLE_BASEMENT
	elif strength <= 6:
		return UrbanHideoutMapData.SizeCategory.CONNECTED_BASEMENTS
	return UrbanHideoutMapData.SizeCategory.CATACOMBS

# -- Step 1: place rooms ------------------------------------------------------

static func _place_rooms(map: UrbanHideoutMapData, w: int, h: int, size: int, rng: int) -> int:
	var range_v: Vector2i = UrbanHideoutMapData.ROOM_COUNT_RANGE[size]
	rng = _lcg(rng)
	var count: int = range_v.x + (rng % (range_v.y - range_v.x + 1))

	match size:
		UrbanHideoutMapData.SizeCategory.SINGLE_BASEMENT:
			rng = _place_single_basement(map, w, h, count)
		_:
			rng = _place_chain_rooms(map, w, h, size, count, rng)
	return rng

static func _place_single_basement(map: UrbanHideoutMapData, w: int, h: int, count: int) -> int:
	var main_w: int = w - 4
	var main_h: int = h - 6
	var main_lx: int = 2
	var main_ly: int = 3
	map.fill_rect(main_lx, main_ly, main_lx + main_w - 1, main_ly + main_h - 1, _FLOOR_STONE)
	if count == 2:
		# Main room = entrance; side alcove below = ritual space.
		map.rooms.append({
			"id": 0, "lx": main_lx, "ly": main_ly,
			"rx": main_lx + main_w - 1, "ry": main_ly + main_h - 1,
			"zone": UrbanHideoutMapData.Zone.ENTRANCE, "taint_level": _TAINT_ENTRANCE,
		})
		var alc_w: int = main_w / 2
		var alc_lx: int = main_lx + main_w / 4
		var alc_ly: int = mini(main_ly + main_h + 1, h - 3)
		var alc_rx: int = alc_lx + alc_w - 1
		var alc_ry: int = mini(alc_ly + 2, h - 2)
		map.fill_rect(alc_lx, alc_ly, alc_rx, alc_ry, _FLOOR_STONE)
		map.rooms.append({
			"id": 1, "lx": alc_lx, "ly": alc_ly, "rx": alc_rx, "ry": alc_ry,
			"zone": UrbanHideoutMapData.Zone.RITUAL_SPACE, "taint_level": _TAINT_RITUAL,
		})
		map.ritual_space_room_id = 1
	else:
		# Single room is both entrance and ritual space.
		map.rooms.append({
			"id": 0, "lx": main_lx, "ly": main_ly,
			"rx": main_lx + main_w - 1, "ry": main_ly + main_h - 1,
			"zone": UrbanHideoutMapData.Zone.RITUAL_SPACE, "taint_level": _TAINT_RITUAL,
		})
		map.ritual_space_room_id = 0
	return 0

# Places rooms in a top-to-bottom chain for CONNECTED/CATACOMBS.
static func _place_chain_rooms(map: UrbanHideoutMapData, w: int, h: int, size: int, count: int, rng: int) -> int:
	var room_h: int = 4
	var room_w: int = clampi(w - 4, 5, 12)
	var x_margin: int = (w - room_w) / 2
	var gap: int = 2

	var y: int = 2
	var main_id: int = 0
	for i in range(count):
		var lx: int = x_margin
		var ly: int = y
		var rx: int = lx + room_w - 1
		var ry: int = mini(ly + room_h - 1, h - 2)
		map.fill_rect(lx, ly, rx, ry, _FLOOR_STONE)
		var zone_type: int
		var taint: int
		if i == 0:
			zone_type = UrbanHideoutMapData.Zone.ENTRANCE
			taint = _TAINT_ENTRANCE
		elif i == count - 1:
			zone_type = UrbanHideoutMapData.Zone.RITUAL_SPACE
			taint = _TAINT_RITUAL
			map.ritual_space_room_id = i
		else:
			zone_type = UrbanHideoutMapData.Zone.ROOM
			taint = _TAINT_ROOM if i <= count / 2 else _TAINT_DEEP
		map.rooms.append({
			"id": i, "lx": lx, "ly": ly, "rx": rx, "ry": ry,
			"zone": zone_type, "taint_level": taint,
		})
		y = ry + gap + 1
		main_id += 1

	# CATACOMBS: optional side-branch rooms off middle rooms.
	if size == UrbanHideoutMapData.SizeCategory.CATACOMBS:
		for i in range(1, count - 1):
			rng = _lcg(rng)
			if rng % 3 != 0:
				continue
			var parent: Dictionary = map.rooms[i]
			var branch_w: int = room_w / 2
			var branch_h: int = 3
			rng = _lcg(rng)
			var branch_lx: int
			if rng % 2 == 0:
				branch_lx = clampi(parent["lx"] - branch_w - 1, 1, w - branch_w - 2)
			else:
				branch_lx = clampi(parent["rx"] + 2, 1, w - branch_w - 2)
			var branch_ly: int = parent["ly"] + 1
			var branch_rx: int = branch_lx + branch_w - 1
			var branch_ry: int = mini(branch_ly + branch_h - 1, h - 2)
			if branch_rx < w - 1 and branch_ry < h - 1:
				map.fill_rect(branch_lx, branch_ly, branch_rx, branch_ry, _FLOOR_STONE)
				map.rooms.append({
					"id": map.rooms.size(), "lx": branch_lx, "ly": branch_ly,
					"rx": branch_rx, "ry": branch_ry,
					"zone": UrbanHideoutMapData.Zone.ROOM, "taint_level": _TAINT_ROOM,
				})
	return rng

# -- Step 2: connect rooms with corridors ------------------------------------

static func _connect_rooms(map: UrbanHideoutMapData) -> void:
	var rooms: Array = map.rooms
	if rooms.size() <= 1:
		return

	# Determine how many rooms are in the main chain.
	var range_v: Vector2i = UrbanHideoutMapData.ROOM_COUNT_RANGE[map.size_category]
	var main_count: int = mini(range_v.y, rooms.size())

	# Connect sequential pairs in the main chain.
	for i in range(main_count - 1):
		var a: Dictionary = rooms[i]
		var b: Dictionary = rooms[i + 1]
		_carve_vertical_corridor(map, a, b)

	# Connect branch rooms to their nearest main-chain room horizontally.
	for i in range(main_count, rooms.size()):
		var branch: Dictionary = rooms[i]
		var best_j: int = 0
		var best_dist: int = 999999
		for j in range(main_count):
			var mr: Dictionary = rooms[j]
			var dy: int = absi(((branch["ly"] + branch["ry"]) / 2) - ((mr["ly"] + mr["ry"]) / 2))
			if dy < best_dist:
				best_dist = dy
				best_j = j
		_carve_horizontal_corridor(map, rooms[best_j], branch)

static func _carve_vertical_corridor(map: UrbanHideoutMapData, a: Dictionary, b: Dictionary) -> void:
	var top: Dictionary = a if a["ry"] < b["ly"] else b
	var bot: Dictionary = b if a["ry"] < b["ly"] else a
	var gap_y_start: int = top["ry"] + 1
	var gap_y_end: int = bot["ly"] - 1
	if gap_y_start > gap_y_end:
		return
	# Use center-x overlap if available, otherwise center of upper room.
	var overlap_lx: int = maxi(a["lx"], b["lx"])
	var overlap_rx: int = mini(a["rx"], b["rx"])
	var cx: int
	if overlap_lx <= overlap_rx:
		cx = (overlap_lx + overlap_rx) / 2
	else:
		cx = (top["lx"] + top["rx"]) / 2
	var corr_id: int = map.corridors.size()
	for cy in range(gap_y_start, gap_y_end + 1):
		map.set_tile(cx, cy, _FLOOR_STONE)
	map.corridors.append({
		"id": corr_id,
		"from_room_id": a["id"], "to_room_id": b["id"],
		"lx": cx, "ly": gap_y_start,
		"rx": cx, "ry": gap_y_end,
	})

static func _carve_horizontal_corridor(map: UrbanHideoutMapData, main_room: Dictionary, branch: Dictionary) -> void:
	var cy: int = (branch["ly"] + branch["ry"]) / 2
	var from_x: int
	var to_x: int
	if branch["rx"] < main_room["lx"]:
		from_x = branch["rx"] + 1
		to_x = main_room["lx"] - 1
	else:
		from_x = main_room["rx"] + 1
		to_x = branch["lx"] - 1
	if from_x > to_x:
		return
	var corr_id: int = map.corridors.size()
	for cx in range(from_x, to_x + 1):
		map.set_tile(cx, cy, _FLOOR_STONE)
	map.corridors.append({
		"id": corr_id,
		"from_room_id": main_room["id"], "to_room_id": branch["id"],
		"lx": from_x, "ly": cy,
		"rx": to_x, "ry": cy,
	})

# -- Step 3: place entrance (ZONE_EXIT trapdoor) ------------------------------

static func _place_entrance(map: UrbanHideoutMapData) -> void:
	if map.rooms.is_empty():
		return
	var entrance_room: Dictionary = map.rooms[0]
	var ex: int = (entrance_room["lx"] + entrance_room["rx"]) / 2
	var ey: int = entrance_room["ly"]
	map.set_tile(ex, ey, _ZONE_EXIT)
	map.entrance_x = ex
	map.entrance_y = ey

# -- Step 4: place doors at corridor-room junctions --------------------------

static func _place_doors(map: UrbanHideoutMapData) -> void:
	for corr in map.corridors:
		var to_id: int = corr["to_room_id"]
		if to_id < 0 or to_id >= map.rooms.size():
			continue
		var to_room: Dictionary = map.rooms[to_id]
		if to_room.get("zone", -1) == UrbanHideoutMapData.Zone.ENTRANCE:
			continue
		# Door at last corridor tile before destination room boundary.
		var door_x: int = corr["lx"]
		var door_y: int
		if corr["ly"] <= corr["ry"]:
			# Vertical corridor.
			if corr["ry"] >= to_room["ly"]:
				door_y = to_room["ly"] - 1
			else:
				door_y = to_room["ry"] + 1
		else:
			door_y = (corr["ly"] + corr["ry"]) / 2
		if door_y >= 0 and map.get_tile(door_x, door_y) == _FLOOR_STONE:
			map.set_tile(door_x, door_y, _DOOR)

# -- Step 5: zombie screen ---------------------------------------------------

static func _place_zombie_screen(map: UrbanHideoutMapData, size: int) -> void:
	if size == UrbanHideoutMapData.SizeCategory.SINGLE_BASEMENT:
		return
	for corr in map.corridors:
		var to_id: int = corr["to_room_id"]
		if to_id < 0 or to_id >= map.rooms.size():
			continue
		if map.rooms[to_id].get("zone", -1) == UrbanHideoutMapData.Zone.ENTRANCE:
			continue
		var mid_x: int = (corr["lx"] + corr["rx"]) / 2
		var mid_y: int = (corr["ly"] + corr["ry"]) / 2
		map.zombie_positions.append({ "x": mid_x, "y": mid_y, "corridor_id": corr["id"] })
		map.population_slots.append({
			"x": mid_x, "y": mid_y,
			"role": UrbanHideoutMapData.PopRole.ZOMBIE_SCREEN,
			"zone": UrbanHideoutMapData.Zone.CORRIDOR,
			"room_id": -1,
		})

# -- Step 6: evidence markers ------------------------------------------------

static func _place_evidence(map: UrbanHideoutMapData, rng: int) -> int:
	var next_id: int = 0
	for room in map.rooms:
		rng = _lcg(rng)
		if room["zone"] == UrbanHideoutMapData.Zone.RITUAL_SPACE or rng % 2 == 0:
			var ex: int = (room["lx"] + room["rx"]) / 2
			var ey: int = clampi((room["ly"] + room["ry"]) / 2 + 1, room["ly"], room["ry"])
			map.evidence_markers.append({ "id": next_id, "x": ex, "y": ey, "room_id": room["id"] })
			next_id += 1
	return rng

# -- Step 7: population slots ------------------------------------------------

static func _place_population(map: UrbanHideoutMapData, size: int, rng: int) -> void:
	for room in map.rooms:
		var zone: int = room.get("zone", UrbanHideoutMapData.Zone.ROOM)
		var rm_cx: int = (room["lx"] + room["rx"]) / 2
		var rm_cy: int = (room["ly"] + room["ry"]) / 2
		match zone:
			UrbanHideoutMapData.Zone.ENTRANCE:
				rng = _lcg(rng)
				var guard_count: int = 1 + (rng % 2)
				for i in range(guard_count):
					map.population_slots.append({
						"x": rm_cx + i, "y": rm_cy,
						"role": UrbanHideoutMapData.PopRole.DOOR_GUARD,
						"zone": UrbanHideoutMapData.Zone.ENTRANCE,
						"room_id": room["id"],
					})
			UrbanHideoutMapData.Zone.RITUAL_SPACE:
				map.population_slots.append({
					"x": rm_cx, "y": rm_cy,
					"role": UrbanHideoutMapData.PopRole.LEADER,
					"zone": UrbanHideoutMapData.Zone.RITUAL_SPACE,
					"room_id": room["id"],
				})
				rng = _lcg(rng)
				var cult_count: int = 1 + (rng % 2)
				for i in range(cult_count):
					map.population_slots.append({
						"x": rm_cx - i - 1, "y": rm_cy,
						"role": UrbanHideoutMapData.PopRole.CULTIST_GROUP,
						"zone": UrbanHideoutMapData.Zone.RITUAL_SPACE,
						"room_id": room["id"],
					})
			UrbanHideoutMapData.Zone.ROOM:
				if size == UrbanHideoutMapData.SizeCategory.SINGLE_BASEMENT:
					continue
				rng = _lcg(rng)
				var count: int = 2 + (rng % 2)
				for i in range(count):
					map.population_slots.append({
						"x": rm_cx + (i - 1), "y": rm_cy,
						"role": UrbanHideoutMapData.PopRole.CULTIST_GROUP,
						"zone": UrbanHideoutMapData.Zone.ROOM,
						"room_id": room["id"],
					})

# -- Step 8: objective slots -------------------------------------------------

static func _place_objectives(map: UrbanHideoutMapData, obj_types: Array) -> void:
	for ot in obj_types:
		match ot:
			UrbanHideoutMapData.ObjType.SUPPRESS_CELL, \
			UrbanHideoutMapData.ObjType.PREVENT_ESCAPE:
				if not map.rooms.is_empty():
					var r: Dictionary = map.rooms[0]
					map.objective_slots.append({
						"x": (r["lx"] + r["rx"]) / 2, "y": r["ly"],
						"obj_type": ot, "room_id": r["id"],
					})
			UrbanHideoutMapData.ObjType.KILL_CAPTURE_LEADER, \
			UrbanHideoutMapData.ObjType.DESTROY_RITUAL_SPACE:
				for r in map.rooms:
					if r.get("zone", -1) == UrbanHideoutMapData.Zone.RITUAL_SPACE:
						map.objective_slots.append({
							"x": (r["lx"] + r["rx"]) / 2,
							"y": (r["ly"] + r["ry"]) / 2,
							"obj_type": ot, "room_id": r["id"],
						})
						break
			UrbanHideoutMapData.ObjType.RECOVER_EVIDENCE:
				if not map.evidence_markers.is_empty():
					var ev: Dictionary = map.evidence_markers[0]
					map.objective_slots.append({
						"x": ev["x"], "y": ev["y"],
						"obj_type": ot, "room_id": ev["room_id"],
					})

# -- FNV-1a deterministic RNG -------------------------------------------------

static func _fnv1a(s: String) -> int:
	var h: int = 0x811c9dc5
	for i in range(s.length()):
		h = h ^ s.unicode_at(i)
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h

static func _lcg(seed_val: int) -> int:
	return (seed_val * 1664525 + 1013904223) & 0xFFFFFFFF
