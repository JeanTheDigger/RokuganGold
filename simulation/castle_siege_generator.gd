class_name CastleSiegeGenerator
## s56.17 Castle Siege map generator --- LOCKED.
## Generates the ASCII tile map for a castle siege (storm assault) mission.
## Three size categories: FORTIFICATION (20×25), CASTLE_TOWN (25×30), CITY (30×40).
## Combat mechanics (murder holes, arrow slits, ladders) are stored as metadata only;
## mechanical effects are blocked on s40 individual combat.
## All static functions; no instance state.

const _T := Enums.TileType

const _WALL  := _T.WALL_STONE
const _FLOOR := _T.FLOOR_STONE
const _DIRT  := _T.FLOOR_DIRT
const _GATE  := _T.DOOR_WOOD_CLOSED
const _EXIT  := _T.ZONE_EXIT

# -- Public entry point -------------------------------------------------------

## Generates a complete CastleSiegeMapData.
## seed_str    : deterministic seed string
## size_cat    : CastleSiegeMapData.SizeCategory int
## assault_mode: CastleSiegeMapData.AssaultMode int
static func generate(seed_str: String, size_cat: int, assault_mode: int) -> CastleSiegeMapData:
	var rng: int = _fnv1a(seed_str)
	var map := CastleSiegeMapData.new()
	map.size_category = size_cat
	map.assault_mode  = assault_mode

	var dim: Vector2i = CastleSiegeMapData.DIMS[size_cat]
	var w: int = dim.x
	var h: int = dim.y
	map.init_tiles(w, h, _WALL)

	match size_cat:
		CastleSiegeMapData.SizeCategory.FORTIFICATION:
			rng = _build_fortification(map, w, h, rng)
		CastleSiegeMapData.SizeCategory.CASTLE_TOWN:
			rng = _build_castle_town(map, w, h, rng)
		_: # CITY
			rng = _build_city(map, w, h, rng)

	_place_player_start(map, assault_mode, w, h)
	_ = rng
	return map

# -- FORTIFICATION (20×25, 2 layers) ------------------------------------------
# Layout (Y=0 is north/back, Y=24 is south/approach):
#   Y=0..1          : tenshu (command building)
#   Y=2             : wall between tenshu and courtyard
#   Y=3..19         : courtyard (FLOOR_STONE)
#   Y=20            : wall walkway (FLOOR_STONE strip along inner wall face)
#   Y=21            : outer wall ring (WALL_STONE), gate at center (X=9..10)
#   Y=22..24        : approach zone (FLOOR_DIRT)

static func _build_fortification(map: CastleSiegeMapData, w: int, h: int, rng: int) -> int:
	# Approach zone (FLOOR_DIRT)
	var approach_y: int = h - 3
	for y in range(approach_y, h):
		for x in range(w):
			map.set_tile(x, y, _DIRT)
	map.baileys.append({
		"id": 0, "lx": 0, "ly": approach_y, "rx": w - 1, "ry": h - 1,
		"zone_type": CastleSiegeMapData.Zone.APPROACH, "layer_idx": 0,
	})

	# Outer wall ring
	var wall_y: int = approach_y - 1  # Y=21
	_fill_wall_ring(map, 0, 0, w - 1, wall_y)
	map.walls.append({
		"id": 0, "lx": 0, "ly": wall_y, "rx": w - 1, "ry": wall_y, "layer_idx": 0,
	})

	# Gate in outer wall (center, 2 tiles wide)
	var gate_x: int = w / 2 - 1
	map.set_tile(gate_x, wall_y, _GATE)
	map.set_tile(gate_x + 1, wall_y, _GATE)
	map.gates.append({
		"id": 0, "x": gate_x, "y": wall_y, "layer_idx": 0, "wall_id": 0,
	})

	# Murder hole above gate (metadata only — s40 blocked)
	map.murder_holes.append({
		"id": 0, "x": gate_x, "y": wall_y - 1, "gate_id": 0, "layer_idx": 0,
	})

	# Wall walkway (strip just inside outer wall)
	var walkway_y: int = wall_y - 1  # Y=20
	for x in range(1, w - 1):
		map.set_tile(x, walkway_y, _FLOOR)
	map.wall_walkways.append({
		"id": 0, "lx": 1, "ly": walkway_y, "rx": w - 2, "ry": walkway_y,
		"layer_idx": 0, "wall_id": 0,
	})

	# Arrow slits on outer face of outer wall (metadata — s40 blocked)
	for x in range(2, w - 2, 3):
		map.arrow_slits.append({
			"id": map.arrow_slits.size(), "x": x, "y": wall_y,
			"facing": "S", "wall_id": 0, "layer_idx": 0,
		})

	# Courtyard interior (FLOOR_STONE between walkway and tenshu)
	var court_ly: int = 3
	var court_ry: int = walkway_y - 1  # Y=19
	for y in range(court_ly, court_ry + 1):
		for x in range(1, w - 1):
			map.set_tile(x, y, _FLOOR)
	map.baileys.append({
		"id": 1, "lx": 1, "ly": court_ly, "rx": w - 2, "ry": court_ry,
		"zone_type": CastleSiegeMapData.Zone.OUTER_BAILEY, "layer_idx": 0,
	})

	# Command building / tenshu (inner ring at north)
	var t_lx: int = 3
	var t_ly: int = 0
	var t_rx: int = w - 4
	var t_ry: int = 2
	_fill_wall_ring(map, t_lx, t_ly, t_rx, t_ry)
	for y in range(t_ly + 1, t_ry):
		for x in range(t_lx + 1, t_rx):
			map.set_tile(x, y, _FLOOR)
	# Gate into tenshu at south face
	var t_gate_x: int = (t_lx + t_rx) / 2
	map.set_tile(t_gate_x, t_ry, _GATE)
	map.gates.append({
		"id": 1, "x": t_gate_x, "y": t_ry, "layer_idx": 1, "wall_id": 1,
	})
	map.walls.append({
		"id": 1, "lx": t_lx, "ly": t_ly, "rx": t_rx, "ry": t_ry, "layer_idx": 1,
	})
	map.tenshu_lx = t_lx + 1
	map.tenshu_ly = t_ly + 1
	map.tenshu_rx = t_rx - 1
	map.tenshu_ry = t_ry - 1

	# Population slots
	_place_defender_slots_fortification(map, w, walkway_y, court_ly, court_ry,
		gate_x, t_lx, t_ly, t_rx, t_ry)

	# Objective markers
	map.objective_slots.append({
		"x": gate_x, "y": wall_y,
		"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
	})
	map.objective_slots.append({
		"x": (map.tenshu_lx + map.tenshu_rx) / 2,
		"y": (map.tenshu_ly + map.tenshu_ry) / 2,
		"zone": CastleSiegeMapData.Zone.TENSHU, "layer_idx": 1,
	})

	return rng

static func _place_defender_slots_fortification(
		map: CastleSiegeMapData, w: int, walkway_y: int,
		court_ly: int, _court_ry: int, gate_x: int,
		t_lx: int, t_ly: int, t_rx: int, t_ry: int) -> void:
	# Wall defenders
	for x in [2, w - 3]:
		map.population_slots.append({
			"x": x, "y": walkway_y,
			"role": CastleSiegeMapData.PopRole.WALL_DEFENDER,
			"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
		})
	# Gate guard
	map.population_slots.append({
		"x": gate_x + 1, "y": walkway_y,
		"role": CastleSiegeMapData.PopRole.GATE_GUARD,
		"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
	})
	# Murder hole guard (metadata slot)
	map.population_slots.append({
		"x": gate_x, "y": walkway_y - 1,
		"role": CastleSiegeMapData.PopRole.MURDER_HOLE_GUARD,
		"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
	})
	# Bailey defenders
	for slot_x in [w / 4, w * 3 / 4]:
		map.population_slots.append({
			"x": slot_x, "y": court_ly + 2,
			"role": CastleSiegeMapData.PopRole.BAILEY_DEFENDER,
			"zone": CastleSiegeMapData.Zone.OUTER_BAILEY, "layer_idx": 0,
		})
	# Commander in tenshu
	map.population_slots.append({
		"x": (t_lx + t_rx) / 2, "y": (t_ly + t_ry) / 2,
		"role": CastleSiegeMapData.PopRole.GARRISON_COMMANDER,
		"zone": CastleSiegeMapData.Zone.TENSHU, "layer_idx": 1,
	})

# -- CASTLE TOWN (25×30, 3 layers) --------------------------------------------
# Layout (Y=0 north/back, Y=29 south/approach):
#   Y=0..2          : tenshu
#   Y=3             : inner wall
#   Y=4..13         : inner bailey
#   Y=14            : inner walkway
#   Y=15            : inner wall (second ring)
#   Y=16..24        : outer bailey
#   Y=25            : outer walkway
#   Y=26            : outer wall, gate at center
#   Y=27..29        : approach zone (FLOOR_DIRT)

static func _build_castle_town(map: CastleSiegeMapData, w: int, h: int, rng: int) -> int:
	var approach_y: int = h - 3  # Y=27

	# Approach (FLOOR_DIRT)
	for y in range(approach_y, h):
		for x in range(w):
			map.set_tile(x, y, _DIRT)
	map.baileys.append({
		"id": 0, "lx": 0, "ly": approach_y, "rx": w - 1, "ry": h - 1,
		"zone_type": CastleSiegeMapData.Zone.APPROACH, "layer_idx": 0,
	})

	# Outer wall (layer 0)
	var ow_y: int = approach_y - 1  # Y=26
	_fill_wall_ring(map, 0, 0, w - 1, ow_y)
	map.walls.append({
		"id": 0, "lx": 0, "ly": ow_y, "rx": w - 1, "ry": ow_y, "layer_idx": 0,
	})
	var ow_gate_x: int = w / 2 - 1
	map.set_tile(ow_gate_x, ow_y, _GATE)
	map.set_tile(ow_gate_x + 1, ow_y, _GATE)
	map.gates.append({
		"id": 0, "x": ow_gate_x, "y": ow_y, "layer_idx": 0, "wall_id": 0,
	})
	map.murder_holes.append({
		"id": 0, "x": ow_gate_x, "y": ow_y - 1, "gate_id": 0, "layer_idx": 0,
	})

	# Outer walkway (layer 0)
	var ow_walk_y: int = ow_y - 1  # Y=25
	for x in range(1, w - 1):
		map.set_tile(x, ow_walk_y, _FLOOR)
	map.wall_walkways.append({
		"id": 0, "lx": 1, "ly": ow_walk_y, "rx": w - 2, "ry": ow_walk_y,
		"layer_idx": 0, "wall_id": 0,
	})
	for x in range(2, w - 2, 3):
		map.arrow_slits.append({
			"id": map.arrow_slits.size(), "x": x, "y": ow_y,
			"facing": "S", "wall_id": 0, "layer_idx": 0,
		})

	# Outer bailey
	var ob_ly: int = 16
	var ob_ry: int = ow_walk_y - 1  # Y=24
	for y in range(ob_ly, ob_ry + 1):
		for x in range(1, w - 1):
			map.set_tile(x, y, _FLOOR)
	map.baileys.append({
		"id": 1, "lx": 1, "ly": ob_ly, "rx": w - 2, "ry": ob_ry,
		"zone_type": CastleSiegeMapData.Zone.OUTER_BAILEY, "layer_idx": 0,
	})

	# Inner wall (layer 1)
	var iw_y: int = ob_ly - 1  # Y=15
	_fill_wall_ring(map, 0, 0, w - 1, iw_y)
	map.walls.append({
		"id": 1, "lx": 0, "ly": iw_y, "rx": w - 1, "ry": iw_y, "layer_idx": 1,
	})
	var iw_gate_x: int = w / 2 - 1
	map.set_tile(iw_gate_x, iw_y, _GATE)
	map.set_tile(iw_gate_x + 1, iw_y, _GATE)
	map.gates.append({
		"id": 1, "x": iw_gate_x, "y": iw_y, "layer_idx": 1, "wall_id": 1,
	})
	map.murder_holes.append({
		"id": 1, "x": iw_gate_x, "y": iw_y - 1, "gate_id": 1, "layer_idx": 1,
	})

	# Inner walkway (layer 1)
	var iw_walk_y: int = iw_y - 1  # Y=14
	for x in range(1, w - 1):
		map.set_tile(x, iw_walk_y, _FLOOR)
	map.wall_walkways.append({
		"id": 1, "lx": 1, "ly": iw_walk_y, "rx": w - 2, "ry": iw_walk_y,
		"layer_idx": 1, "wall_id": 1,
	})
	for x in range(2, w - 2, 3):
		map.arrow_slits.append({
			"id": map.arrow_slits.size(), "x": x, "y": iw_y,
			"facing": "S", "wall_id": 1, "layer_idx": 1,
		})

	# Inner bailey
	var ib_ly: int = 4
	var ib_ry: int = iw_walk_y - 1  # Y=13
	for y in range(ib_ly, ib_ry + 1):
		for x in range(1, w - 1):
			map.set_tile(x, y, _FLOOR)
	map.baileys.append({
		"id": 2, "lx": 1, "ly": ib_ly, "rx": w - 2, "ry": ib_ry,
		"zone_type": CastleSiegeMapData.Zone.INNER_BAILEY, "layer_idx": 1,
	})

	# Tenshu (layer 2)
	var t_lx: int = 4
	var t_ly: int = 0
	var t_rx: int = w - 5
	var t_ry: int = 3
	_fill_wall_ring(map, t_lx, t_ly, t_rx, t_ry)
	for y in range(t_ly + 1, t_ry):
		for x in range(t_lx + 1, t_rx):
			map.set_tile(x, y, _FLOOR)
	var t_gate_x: int = (t_lx + t_rx) / 2
	map.set_tile(t_gate_x, t_ry, _GATE)
	map.gates.append({
		"id": 2, "x": t_gate_x, "y": t_ry, "layer_idx": 2, "wall_id": 2,
	})
	map.walls.append({
		"id": 2, "lx": t_lx, "ly": t_ly, "rx": t_rx, "ry": t_ry, "layer_idx": 2,
	})
	map.tenshu_lx = t_lx + 1
	map.tenshu_ly = t_ly + 1
	map.tenshu_rx = t_rx - 1
	map.tenshu_ry = t_ry - 1

	_place_defender_slots_castle_town(map, w, ow_walk_y, ob_ly, ob_ry,
		ow_gate_x, iw_walk_y, ib_ly, ib_ry, iw_gate_x, t_lx, t_ly, t_rx, t_ry)

	map.objective_slots.append({
		"x": ow_gate_x, "y": ow_y,
		"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
	})
	map.objective_slots.append({
		"x": iw_gate_x, "y": iw_y,
		"zone": CastleSiegeMapData.Zone.INNER_BAILEY, "layer_idx": 1,
	})
	map.objective_slots.append({
		"x": (map.tenshu_lx + map.tenshu_rx) / 2,
		"y": (map.tenshu_ly + map.tenshu_ry) / 2,
		"zone": CastleSiegeMapData.Zone.TENSHU, "layer_idx": 2,
	})

	return rng

static func _place_defender_slots_castle_town(
		map: CastleSiegeMapData, w: int,
		ow_walk_y: int, ob_ly: int, ob_ry: int, ow_gate_x: int,
		iw_walk_y: int, ib_ly: int, ib_ry: int, iw_gate_x: int,
		t_lx: int, t_ly: int, t_rx: int, t_ry: int) -> void:
	# Outer wall defenders
	for x in [2, w - 3]:
		map.population_slots.append({
			"x": x, "y": ow_walk_y,
			"role": CastleSiegeMapData.PopRole.WALL_DEFENDER,
			"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
		})
	map.population_slots.append({
		"x": ow_gate_x + 1, "y": ow_walk_y,
		"role": CastleSiegeMapData.PopRole.GATE_GUARD,
		"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
	})
	map.population_slots.append({
		"x": ow_gate_x, "y": ow_walk_y - 1,
		"role": CastleSiegeMapData.PopRole.MURDER_HOLE_GUARD,
		"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
	})
	# Outer bailey defenders
	for slot_x in [w / 4, w * 3 / 4]:
		map.population_slots.append({
			"x": slot_x, "y": (ob_ly + ob_ry) / 2,
			"role": CastleSiegeMapData.PopRole.BAILEY_DEFENDER,
			"zone": CastleSiegeMapData.Zone.OUTER_BAILEY, "layer_idx": 0,
		})
	# Inner wall defenders
	for x in [2, w - 3]:
		map.population_slots.append({
			"x": x, "y": iw_walk_y,
			"role": CastleSiegeMapData.PopRole.WALL_DEFENDER,
			"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 1,
		})
	map.population_slots.append({
		"x": iw_gate_x + 1, "y": iw_walk_y,
		"role": CastleSiegeMapData.PopRole.GATE_GUARD,
		"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 1,
	})
	map.population_slots.append({
		"x": iw_gate_x, "y": iw_walk_y - 1,
		"role": CastleSiegeMapData.PopRole.MURDER_HOLE_GUARD,
		"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 1,
	})
	# Inner bailey defenders
	for slot_x in [w / 4, w * 3 / 4]:
		map.population_slots.append({
			"x": slot_x, "y": (ib_ly + ib_ry) / 2,
			"role": CastleSiegeMapData.PopRole.BAILEY_DEFENDER,
			"zone": CastleSiegeMapData.Zone.INNER_BAILEY, "layer_idx": 1,
		})
	# Commander
	map.population_slots.append({
		"x": (t_lx + t_rx) / 2, "y": (t_ly + t_ry) / 2,
		"role": CastleSiegeMapData.PopRole.GARRISON_COMMANDER,
		"zone": CastleSiegeMapData.Zone.TENSHU, "layer_idx": 2,
	})

# -- CITY (30×40, 4 layers) ---------------------------------------------------
# Layout (Y=0 north/back, Y=39 south/approach):
#   Y=0..2          : tenshu
#   Y=3             : castle compound wall
#   Y=4..12         : castle compound (inner bailey)
#   Y=13            : inner wall walkway
#   Y=14            : inner wall, single gate
#   Y=15..25        : outer district (outer bailey)
#   Y=26            : outer wall walkway
#   Y=27            : outer wall, 3 gates
#   Y=28..30        : outer district buffer
#   Y=31..39        : approach zone (FLOOR_DIRT)

static func _build_city(map: CastleSiegeMapData, w: int, h: int, rng: int) -> int:
	var approach_y: int = h - 9  # Y=31

	# Approach (FLOOR_DIRT)
	for y in range(approach_y, h):
		for x in range(w):
			map.set_tile(x, y, _DIRT)
	map.baileys.append({
		"id": 0, "lx": 0, "ly": approach_y, "rx": w - 1, "ry": h - 1,
		"zone_type": CastleSiegeMapData.Zone.APPROACH, "layer_idx": 0,
	})

	# Outer wall (layer 0) — 3 gates for CITY
	var ow_y: int = approach_y - 4  # Y=27
	_fill_wall_ring(map, 0, 0, w - 1, ow_y)
	map.walls.append({
		"id": 0, "lx": 0, "ly": ow_y, "rx": w - 1, "ry": ow_y, "layer_idx": 0,
	})
	# Three gates: left quarter, center, right quarter
	var gate_xs: Array = [w / 4 - 1, w / 2 - 1, (w * 3) / 4 - 1]
	for gi in range(gate_xs.size()):
		var gx: int = gate_xs[gi]
		map.set_tile(gx, ow_y, _GATE)
		map.set_tile(gx + 1, ow_y, _GATE)
		map.gates.append({
			"id": gi, "x": gx, "y": ow_y, "layer_idx": 0, "wall_id": 0,
		})
		map.murder_holes.append({
			"id": gi, "x": gx, "y": ow_y - 1, "gate_id": gi, "layer_idx": 0,
		})

	# Outer wall walkway
	var ow_walk_y: int = ow_y - 1  # Y=26
	for x in range(1, w - 1):
		map.set_tile(x, ow_walk_y, _FLOOR)
	map.wall_walkways.append({
		"id": 0, "lx": 1, "ly": ow_walk_y, "rx": w - 2, "ry": ow_walk_y,
		"layer_idx": 0, "wall_id": 0,
	})
	for x in range(2, w - 2, 4):
		map.arrow_slits.append({
			"id": map.arrow_slits.size(), "x": x, "y": ow_y,
			"facing": "S", "wall_id": 0, "layer_idx": 0,
		})

	# Buffer zone between outer wall and outer district (FLOOR_STONE)
	var buf_ly: int = ow_walk_y - 3  # Y=23
	var buf_ry: int = ow_walk_y - 1  # Y=25
	for y in range(buf_ly, buf_ry + 1):
		for x in range(1, w - 1):
			map.set_tile(x, y, _FLOOR)

	# Outer district / outer bailey
	var od_ly: int = 15
	var od_ry: int = buf_ly - 1  # Y=22
	for y in range(od_ly, od_ry + 1):
		for x in range(1, w - 1):
			map.set_tile(x, y, _FLOOR)
	map.baileys.append({
		"id": 1, "lx": 1, "ly": od_ly, "rx": w - 2, "ry": buf_ry,
		"zone_type": CastleSiegeMapData.Zone.OUTER_BAILEY, "layer_idx": 0,
	})

	# Inner wall (layer 1)
	var iw_y: int = od_ly - 1  # Y=14
	_fill_wall_ring(map, 0, 0, w - 1, iw_y)
	map.walls.append({
		"id": 1, "lx": 0, "ly": iw_y, "rx": w - 1, "ry": iw_y, "layer_idx": 1,
	})
	var iw_gate_x: int = w / 2 - 1
	map.set_tile(iw_gate_x, iw_y, _GATE)
	map.set_tile(iw_gate_x + 1, iw_y, _GATE)
	map.gates.append({
		"id": 3, "x": iw_gate_x, "y": iw_y, "layer_idx": 1, "wall_id": 1,
	})
	map.murder_holes.append({
		"id": 3, "x": iw_gate_x, "y": iw_y - 1, "gate_id": 3, "layer_idx": 1,
	})

	# Inner wall walkway
	var iw_walk_y: int = iw_y - 1  # Y=13
	for x in range(1, w - 1):
		map.set_tile(x, iw_walk_y, _FLOOR)
	map.wall_walkways.append({
		"id": 1, "lx": 1, "ly": iw_walk_y, "rx": w - 2, "ry": iw_walk_y,
		"layer_idx": 1, "wall_id": 1,
	})
	for x in range(2, w - 2, 4):
		map.arrow_slits.append({
			"id": map.arrow_slits.size(), "x": x, "y": iw_y,
			"facing": "S", "wall_id": 1, "layer_idx": 1,
		})

	# Castle compound / inner bailey
	var cc_ly: int = 4
	var cc_ry: int = iw_walk_y - 1  # Y=12
	for y in range(cc_ly, cc_ry + 1):
		for x in range(1, w - 1):
			map.set_tile(x, y, _FLOOR)
	map.baileys.append({
		"id": 2, "lx": 1, "ly": cc_ly, "rx": w - 2, "ry": cc_ry,
		"zone_type": CastleSiegeMapData.Zone.INNER_BAILEY, "layer_idx": 1,
	})

	# Tenshu (layer 2 — castle compound wall separates it)
	var cw_y: int = 3  # Castle compound wall (layer 2)
	_fill_wall_ring(map, 0, 0, w - 1, cw_y)
	map.walls.append({
		"id": 2, "lx": 0, "ly": cw_y, "rx": w - 1, "ry": cw_y, "layer_idx": 2,
	})
	var cw_gate_x: int = w / 2 - 1
	map.set_tile(cw_gate_x, cw_y, _GATE)
	map.set_tile(cw_gate_x + 1, cw_y, _GATE)
	map.gates.append({
		"id": 4, "x": cw_gate_x, "y": cw_y, "layer_idx": 2, "wall_id": 2,
	})

	# Tenshu interior (layer 3)
	var t_lx: int = 6
	var t_ly: int = 0
	var t_rx: int = w - 7
	var t_ry: int = 2
	_fill_wall_ring(map, t_lx, t_ly, t_rx, t_ry)
	for y in range(t_ly + 1, t_ry):
		for x in range(t_lx + 1, t_rx):
			map.set_tile(x, y, _FLOOR)
	var t_gate_x: int = (t_lx + t_rx) / 2
	map.set_tile(t_gate_x, t_ry, _GATE)
	map.gates.append({
		"id": 5, "x": t_gate_x, "y": t_ry, "layer_idx": 3, "wall_id": 3,
	})
	map.walls.append({
		"id": 3, "lx": t_lx, "ly": t_ly, "rx": t_rx, "ry": t_ry, "layer_idx": 3,
	})
	map.tenshu_lx = t_lx + 1
	map.tenshu_ly = t_ly + 1
	map.tenshu_rx = t_rx - 1
	map.tenshu_ry = t_ry - 1

	_place_defender_slots_city(map, w, ow_walk_y, gate_xs, od_ly, od_ry,
		iw_walk_y, cc_ly, cc_ry, iw_gate_x, t_lx, t_ly, t_rx, t_ry)

	# Objectives: each gate + tenshu
	for gi in range(gate_xs.size()):
		map.objective_slots.append({
			"x": gate_xs[gi], "y": ow_y,
			"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
		})
	map.objective_slots.append({
		"x": iw_gate_x, "y": iw_y,
		"zone": CastleSiegeMapData.Zone.INNER_BAILEY, "layer_idx": 1,
	})
	map.objective_slots.append({
		"x": (map.tenshu_lx + map.tenshu_rx) / 2,
		"y": (map.tenshu_ly + map.tenshu_ry) / 2,
		"zone": CastleSiegeMapData.Zone.TENSHU, "layer_idx": 3,
	})

	return rng

static func _place_defender_slots_city(
		map: CastleSiegeMapData, w: int,
		ow_walk_y: int, gate_xs: Array, od_ly: int, od_ry: int,
		iw_walk_y: int, cc_ly: int, cc_ry: int, iw_gate_x: int,
		t_lx: int, t_ly: int, t_rx: int, t_ry: int) -> void:
	# Outer wall defenders (one per gate + flanks)
	for gx in gate_xs:
		map.population_slots.append({
			"x": gx + 1, "y": ow_walk_y,
			"role": CastleSiegeMapData.PopRole.GATE_GUARD,
			"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
		})
		map.population_slots.append({
			"x": gx, "y": ow_walk_y - 1,
			"role": CastleSiegeMapData.PopRole.MURDER_HOLE_GUARD,
			"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
		})
	for x in [2, w - 3]:
		map.population_slots.append({
			"x": x, "y": ow_walk_y,
			"role": CastleSiegeMapData.PopRole.WALL_DEFENDER,
			"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 0,
		})
	# Outer district defenders
	for slot_x in [w / 5, w * 2 / 5, w * 3 / 5, w * 4 / 5]:
		map.population_slots.append({
			"x": slot_x, "y": (od_ly + od_ry) / 2,
			"role": CastleSiegeMapData.PopRole.BAILEY_DEFENDER,
			"zone": CastleSiegeMapData.Zone.OUTER_BAILEY, "layer_idx": 0,
		})
	# Inner wall defenders
	for x in [2, w - 3]:
		map.population_slots.append({
			"x": x, "y": iw_walk_y,
			"role": CastleSiegeMapData.PopRole.WALL_DEFENDER,
			"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 1,
		})
	map.population_slots.append({
		"x": iw_gate_x + 1, "y": iw_walk_y,
		"role": CastleSiegeMapData.PopRole.GATE_GUARD,
		"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 1,
	})
	map.population_slots.append({
		"x": iw_gate_x, "y": iw_walk_y - 1,
		"role": CastleSiegeMapData.PopRole.MURDER_HOLE_GUARD,
		"zone": CastleSiegeMapData.Zone.WALL_TOP, "layer_idx": 1,
	})
	# Castle compound defenders
	for slot_x in [w / 4, w * 3 / 4]:
		map.population_slots.append({
			"x": slot_x, "y": (cc_ly + cc_ry) / 2,
			"role": CastleSiegeMapData.PopRole.BAILEY_DEFENDER,
			"zone": CastleSiegeMapData.Zone.INNER_BAILEY, "layer_idx": 1,
		})
	# Commander in tenshu
	map.population_slots.append({
		"x": (t_lx + t_rx) / 2, "y": (t_ly + t_ry) / 2,
		"role": CastleSiegeMapData.PopRole.GARRISON_COMMANDER,
		"zone": CastleSiegeMapData.Zone.TENSHU, "layer_idx": 3,
	})

# -- Player start placement ---------------------------------------------------

static func _place_player_start(map: CastleSiegeMapData, assault_mode: int, w: int, h: int) -> void:
	var x: int
	var y: int
	if assault_mode == CastleSiegeMapData.AssaultMode.ATTACKER:
		# South center of approach zone (FLOOR_DIRT)
		x = w / 2
		y = h - 1
	else:
		# DEFENDER: outer wall walkway center
		x = w / 2
		# Outer wall walkway is one row above the outer wall row.
		# For all sizes, outer wall is the row just above the approach zone.
		# Walkway is one row above that.
		match map.size_category:
			CastleSiegeMapData.SizeCategory.FORTIFICATION:
				y = h - 3 - 2  # Y=20
			CastleSiegeMapData.SizeCategory.CASTLE_TOWN:
				y = h - 3 - 2  # Y=25
			_: # CITY
				y = h - 9 - 2  # Y=26 (ow_walk_y)
	map.set_tile(x, y, _EXIT)
	map.player_start_x = x
	map.player_start_y = y

# -- Shared helpers -----------------------------------------------------------

# Fills the perimeter of a rectangle with WALL_STONE, leaving interior unchanged.
static func _fill_wall_ring(map: CastleSiegeMapData,
		lx: int, ly: int, rx: int, ry: int) -> void:
	for x in range(lx, rx + 1):
		map.set_tile(x, ly, _WALL)
		map.set_tile(x, ry, _WALL)
	for y in range(ly + 1, ry):
		map.set_tile(lx, y, _WALL)
		map.set_tile(rx, y, _WALL)

# FNV-1a 32-bit hash.
static func _fnv1a(s: String) -> int:
	var h: int = 0x811c9dc5
	for c in s.to_utf8_buffer():
		h = h ^ c
		h = (h * 0x01000193) & 0xFFFFFFFF
	return h

# Linear congruential generator step.
static func _lcg(seed: int) -> int:
	return (seed * 1664525 + 1013904223) & 0xFFFFFFFF
