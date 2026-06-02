extends GutTest
## Tests for MovementSystem (s4.4 / s4.5 LOCKED).

# ── terrain_cost ─────────────────────────────────────────────────────────────

func test_floor_tiles_cost_1() -> void:
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.FLOOR_GRASS),  1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.FLOOR_DIRT),   1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.FLOOR_WOOD),   1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.FLOOR_TATAMI), 1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.FLOOR_STONE),  1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.FLOOR_MUD),    1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.FLOOR_SNOW),   1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.FLOOR_SAND),   1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.FLOOR_ASH),    1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.FIRE),         1)


func test_vegetation_passable_costs_1() -> void:
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.BUSH),        1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.GROUNDCOVER),  1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.FLOWERS),      1)


func test_difficult_terrain_costs_2() -> void:
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.WATER_SHALLOW), 2)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.WATER_PADDY),   2)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.WATER_RAPID),   2)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.CROPS),         2)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.RUBBLE),        2)


func test_impassable_tiles_cost_0() -> void:
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.VOID),          0)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.WALL_STONE),    0)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.WALL_WOOD),     0)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.WALL_PAPER),    0)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.WATER_DEEP),    0)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.TREE_EVERGREEN),0)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.TREE_DECIDUOUS),0)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.TREE_CHERRY),   0)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.TREE_DEAD),     0)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.BAMBOO),        0)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.GATE_CLOSED),   0)


func test_doors_passable_open_impassable_closed() -> void:
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.DOOR_SHOJI_OPEN),   1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.DOOR_WOOD_OPEN),    1)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.GATE_OPEN),         1)
	# Closed doors return 0 via terrain_cost but are handled via is_closed_door
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.DOOR_SHOJI_CLOSED), 0)
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.DOOR_WOOD_CLOSED),  0)


func test_zone_exit_passable() -> void:
	assert_eq(MovementSystem.terrain_cost(Enums.TileType.ZONE_EXIT), 1)


# ── is_passable ──────────────────────────────────────────────────────────────

func test_is_passable_true_for_floors() -> void:
	assert_true(MovementSystem.is_passable(Enums.TileType.FLOOR_GRASS))
	assert_true(MovementSystem.is_passable(Enums.TileType.ZONE_EXIT))
	assert_true(MovementSystem.is_passable(Enums.TileType.WATER_SHALLOW))


func test_is_passable_false_for_walls() -> void:
	assert_false(MovementSystem.is_passable(Enums.TileType.WALL_STONE))
	assert_false(MovementSystem.is_passable(Enums.TileType.VOID))
	assert_false(MovementSystem.is_passable(Enums.TileType.TREE_EVERGREEN))
	assert_false(MovementSystem.is_passable(Enums.TileType.WATER_DEEP))


# ── is_closed_door ───────────────────────────────────────────────────────────

func test_is_closed_door_true_for_closed() -> void:
	assert_true(MovementSystem.is_closed_door(Enums.TileType.DOOR_SHOJI_CLOSED))
	assert_true(MovementSystem.is_closed_door(Enums.TileType.DOOR_WOOD_CLOSED))


func test_is_closed_door_false_for_others() -> void:
	assert_false(MovementSystem.is_closed_door(Enums.TileType.DOOR_SHOJI_OPEN))
	assert_false(MovementSystem.is_closed_door(Enums.TileType.DOOR_WOOD_OPEN))
	assert_false(MovementSystem.is_closed_door(Enums.TileType.GATE_CLOSED))
	assert_false(MovementSystem.is_closed_door(Enums.TileType.WALL_WOOD))


# ── open_door / close_door ───────────────────────────────────────────────────

func test_open_door_shoji() -> void:
	assert_eq(
		MovementSystem.open_door(Enums.TileType.DOOR_SHOJI_CLOSED),
		Enums.TileType.DOOR_SHOJI_OPEN)


func test_open_door_wood() -> void:
	assert_eq(
		MovementSystem.open_door(Enums.TileType.DOOR_WOOD_CLOSED),
		Enums.TileType.DOOR_WOOD_OPEN)


func test_open_door_identity_for_non_door() -> void:
	assert_eq(
		MovementSystem.open_door(Enums.TileType.FLOOR_STONE),
		Enums.TileType.FLOOR_STONE)


func test_close_door_shoji() -> void:
	assert_eq(
		MovementSystem.close_door(Enums.TileType.DOOR_SHOJI_OPEN),
		Enums.TileType.DOOR_SHOJI_CLOSED)


func test_close_door_wood() -> void:
	assert_eq(
		MovementSystem.close_door(Enums.TileType.DOOR_WOOD_OPEN),
		Enums.TileType.DOOR_WOOD_CLOSED)


func test_close_door_identity_for_non_door() -> void:
	assert_eq(
		MovementSystem.close_door(Enums.TileType.FLOOR_STONE),
		Enums.TileType.FLOOR_STONE)


func test_open_close_roundtrip_shoji() -> void:
	var closed: int = Enums.TileType.DOOR_SHOJI_CLOSED
	assert_eq(MovementSystem.close_door(MovementSystem.open_door(closed)), closed)


func test_open_close_roundtrip_wood() -> void:
	var closed: int = Enums.TileType.DOOR_WOOD_CLOSED
	assert_eq(MovementSystem.close_door(MovementSystem.open_door(closed)), closed)


# ── budget (s4.5 LOCKED) ─────────────────────────────────────────────────────

func test_budget_free_equals_water_ring() -> void:
	for wr in [1, 2, 3, 4, 5]:
		assert_eq(MovementSystem.budget(wr, MovementSystem.MoveAction.FREE), wr)


func test_budget_simple_double() -> void:
	assert_eq(MovementSystem.budget(3, MovementSystem.MoveAction.SIMPLE), 6)
	assert_eq(MovementSystem.budget(4, MovementSystem.MoveAction.SIMPLE), 8)


func test_budget_full_move_quadruple() -> void:
	assert_eq(MovementSystem.budget(3, MovementSystem.MoveAction.FULL_MOVE), 12)
	assert_eq(MovementSystem.budget(2, MovementSystem.MoveAction.FULL_MOVE), 8)


func test_budget_water_ring_1() -> void:
	# Water 1: Free=1, Simple=2, Full=4
	assert_eq(MovementSystem.budget(1, MovementSystem.MoveAction.FREE),      1)
	assert_eq(MovementSystem.budget(1, MovementSystem.MoveAction.SIMPLE),    2)
	assert_eq(MovementSystem.budget(1, MovementSystem.MoveAction.FULL_MOVE), 4)


func test_budget_water_ring_3() -> void:
	# Water 3: Free=3, Simple=6, Full=12
	assert_eq(MovementSystem.budget(3, MovementSystem.MoveAction.FREE),      3)
	assert_eq(MovementSystem.budget(3, MovementSystem.MoveAction.SIMPLE),    6)
	assert_eq(MovementSystem.budget(3, MovementSystem.MoveAction.FULL_MOVE), 12)


func test_budget_clamps_minimum_to_1() -> void:
	assert_eq(MovementSystem.budget(0, MovementSystem.MoveAction.FREE), 1)
	assert_eq(MovementSystem.budget(-5, MovementSystem.MoveAction.SIMPLE), 2)


func test_budget_clamps_maximum_to_10() -> void:
	# Water Ring above 10 treated as 10
	assert_eq(MovementSystem.budget(15, MovementSystem.MoveAction.FREE), 10)


# ── check_step ───────────────────────────────────────────────────────────────

func _make_map(width: int, height: int, default_tile: int = Enums.TileType.FLOOR_GRASS) -> AsciiMapData:
	var m: AsciiMapData = AsciiMapData.new()
	m.init_tiles(default_tile, width, height)
	return m


func test_step_into_passable_tile_ok() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	var r: Dictionary = MovementSystem.check_step(m, 5, 5, 6, 5)
	assert_true(r["ok"])
	assert_eq(r["cost"], 1)
	assert_false(r["is_door"])
	assert_false(r["is_exit"])


func test_step_into_wall_blocked() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	m.set_tile(6, 5, Enums.TileType.WALL_STONE)
	var r: Dictionary = MovementSystem.check_step(m, 5, 5, 6, 5)
	assert_false(r["ok"])
	assert_eq(r["cost"], 0)


func test_step_into_deep_water_blocked() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	m.set_tile(6, 5, Enums.TileType.WATER_DEEP)
	assert_false(MovementSystem.check_step(m, 5, 5, 6, 5)["ok"])


func test_step_into_shallow_water_costs_2() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	m.set_tile(6, 5, Enums.TileType.WATER_SHALLOW)
	var r: Dictionary = MovementSystem.check_step(m, 5, 5, 6, 5)
	assert_true(r["ok"])
	assert_eq(r["cost"], 2)


func test_step_into_crops_costs_2() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	m.set_tile(6, 5, Enums.TileType.CROPS)
	var r: Dictionary = MovementSystem.check_step(m, 5, 5, 6, 5)
	assert_true(r["ok"])
	assert_eq(r["cost"], 2)


func test_step_into_closed_door_returns_is_door() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	m.set_tile(6, 5, Enums.TileType.DOOR_WOOD_CLOSED)
	var r: Dictionary = MovementSystem.check_step(m, 5, 5, 6, 5)
	assert_false(r["ok"])
	assert_true(r["is_door"])
	assert_eq(r["cost"], 0)


func test_step_into_open_door_ok() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	m.set_tile(6, 5, Enums.TileType.DOOR_WOOD_OPEN)
	var r: Dictionary = MovementSystem.check_step(m, 5, 5, 6, 5)
	assert_true(r["ok"])
	assert_false(r["is_door"])


func test_step_into_zone_exit_is_exit() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	m.set_tile(6, 5, Enums.TileType.ZONE_EXIT)
	var r: Dictionary = MovementSystem.check_step(m, 5, 5, 6, 5)
	assert_true(r["ok"])
	assert_true(r["is_exit"])
	assert_false(r["is_door"])
	assert_eq(r["cost"], 1)


func test_step_out_of_bounds_blocked() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	assert_false(MovementSystem.check_step(m, 0, 0, -1, 0)["ok"])
	assert_false(MovementSystem.check_step(m, 9, 9, 10, 9)["ok"])
	assert_false(MovementSystem.check_step(m, 0, 0, 0, -1)["ok"])
	assert_false(MovementSystem.check_step(m, 9, 9, 9, 10)["ok"])


func test_step_void_tile_blocked() -> void:
	var m: AsciiMapData = _make_map(10, 10, Enums.TileType.VOID)
	assert_false(MovementSystem.check_step(m, 0, 0, 1, 0)["ok"])


func test_step_diagonal_works() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	var r: Dictionary = MovementSystem.check_step(m, 5, 5, 6, 6)
	assert_true(r["ok"])
	assert_eq(r["cost"], 1)


func test_step_tree_impassable() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	for t in [Enums.TileType.TREE_EVERGREEN, Enums.TileType.TREE_DECIDUOUS,
			  Enums.TileType.TREE_CHERRY, Enums.TileType.TREE_DEAD, Enums.TileType.BAMBOO]:
		m.set_tile(6, 5, t)
		assert_false(MovementSystem.check_step(m, 5, 5, 6, 5)["ok"],
			"Expected tree tile %d to be impassable" % t)


func test_step_gate_closed_impassable() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	m.set_tile(6, 5, Enums.TileType.GATE_CLOSED)
	assert_false(MovementSystem.check_step(m, 5, 5, 6, 5)["ok"])


func test_step_gate_open_passable() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	m.set_tile(6, 5, Enums.TileType.GATE_OPEN)
	assert_true(MovementSystem.check_step(m, 5, 5, 6, 5)["ok"])


func test_step_rubble_costs_2() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	m.set_tile(6, 5, Enums.TileType.RUBBLE)
	var r: Dictionary = MovementSystem.check_step(m, 5, 5, 6, 5)
	assert_true(r["ok"])
	assert_eq(r["cost"], 2)
