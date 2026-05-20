extends GutTest


# -- Helpers ---------------------------------------------------------------------

func _make_army(
	id: int = 1,
	tile: int = 0,
	clan: String = "Lion",
) -> Dictionary:
	return ArmyMovementSystem.create_army_state(id, tile, clan)


func _make_sub_tile_data(
	tiles: Dictionary = {},
) -> Dictionary:
	return tiles


func _plains_tile(river: bool = false) -> Dictionary:
	return {"terrain": ArmyMovementSystem.MovementTerrain.PLAINS, "has_river_crossing": river}


func _forest_tile(river: bool = false) -> Dictionary:
	return {"terrain": ArmyMovementSystem.MovementTerrain.FOREST, "has_river_crossing": river}


func _mountain_tile(river: bool = false) -> Dictionary:
	return {"terrain": ArmyMovementSystem.MovementTerrain.MOUNTAINS, "has_river_crossing": river}


func _heavy_hills_tile(river: bool = false) -> Dictionary:
	return {"terrain": ArmyMovementSystem.MovementTerrain.HEAVY_HILLS, "has_river_crossing": river}


# -- Create Army State Tests -----------------------------------------------------

func test_create_army_state() -> void:
	var a: Dictionary = _make_army()
	assert_eq(a["army_id"], 1)
	assert_eq(a["current_sub_tile"], 0)
	assert_eq(a["owning_clan"], "Lion")
	assert_false(a["is_moving"])
	assert_eq(a["days_remaining"], 0)


# -- Terrain Cost Tests ----------------------------------------------------------

func test_terrain_cost_plains_summer() -> void:
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.PLAINS,
			ArmyMovementSystem.Season.SUMMER, false,
		),
		1,
	)


func test_terrain_cost_forest_summer() -> void:
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.FOREST,
			ArmyMovementSystem.Season.SUMMER, false,
		),
		2,
	)


func test_terrain_cost_mountains_summer() -> void:
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.MOUNTAINS,
			ArmyMovementSystem.Season.SUMMER, false,
		),
		3,
	)


func test_terrain_cost_river_delta_summer() -> void:
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.RIVER_DELTA,
			ArmyMovementSystem.Season.SUMMER, false,
		),
		1,
	)


func test_terrain_cost_heavy_hills_summer() -> void:
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.HEAVY_HILLS,
			ArmyMovementSystem.Season.SUMMER, false,
		),
		2,
	)


func test_terrain_cost_plains_winter() -> void:
	# 1 * 2 = 2
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.PLAINS,
			ArmyMovementSystem.Season.WINTER, false,
		),
		2,
	)


func test_terrain_cost_forest_winter() -> void:
	# 2 * 2 = 4
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.FOREST,
			ArmyMovementSystem.Season.WINTER, false,
		),
		4,
	)


func test_terrain_cost_mountains_winter() -> void:
	# 3 * 2 = 6
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.MOUNTAINS,
			ArmyMovementSystem.Season.WINTER, false,
		),
		6,
	)


func test_terrain_cost_river_crossing_summer() -> void:
	# 1 + 1 = 2
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.PLAINS,
			ArmyMovementSystem.Season.SUMMER, true,
		),
		2,
	)


func test_terrain_cost_river_crossing_spring() -> void:
	# 1 + 2 = 3
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.PLAINS,
			ArmyMovementSystem.Season.SPRING, true,
		),
		3,
	)


func test_terrain_cost_mountains_winter_with_river() -> void:
	# GDD s11.7a: "A river crossing into mountains in winter = 8 days (3 ×2 + 2)"
	# Winter multiplier applies to river cost too: (3 * 2) + (1 * 2) = 8
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.MOUNTAINS,
			ArmyMovementSystem.Season.WINTER, true,
		),
		8,
	)


func test_terrain_cost_mountains_winter_with_spring_river() -> void:
	# Spring: (3 * 1) + 2 = 5 (no winter multiplier in spring)
	assert_eq(
		ArmyMovementSystem.get_terrain_cost(
			ArmyMovementSystem.MovementTerrain.MOUNTAINS,
			ArmyMovementSystem.Season.SPRING, true,
		),
		5,
	)


# -- Forced March Tests ----------------------------------------------------------

func test_forced_march_plains() -> void:
	var r: Dictionary = ArmyMovementSystem.get_forced_march_cost(
		ArmyMovementSystem.MovementTerrain.PLAINS,
		ArmyMovementSystem.Season.SUMMER, false, 1,
	)
	# Plains = 1 day, min = 1, can't save any
	assert_eq(r["days_saved"], 0)
	assert_eq(r["morale_cost"], 0)
	assert_eq(r["travel_days"], 1)


func test_forced_march_forest() -> void:
	var r: Dictionary = ArmyMovementSystem.get_forced_march_cost(
		ArmyMovementSystem.MovementTerrain.FOREST,
		ArmyMovementSystem.Season.SUMMER, false, 1,
	)
	# Forest = 2 days, save 1, morale = 5
	assert_eq(r["days_saved"], 1)
	assert_eq(r["morale_cost"], 5)
	assert_eq(r["travel_days"], 1)


func test_forced_march_mountains() -> void:
	var r: Dictionary = ArmyMovementSystem.get_forced_march_cost(
		ArmyMovementSystem.MovementTerrain.MOUNTAINS,
		ArmyMovementSystem.Season.SUMMER, false, 2,
	)
	# Mountains = 3 days, save 2, morale = 10, travel = 1
	assert_eq(r["days_saved"], 2)
	assert_eq(r["morale_cost"], 10)
	assert_eq(r["travel_days"], 1)


func test_forced_march_cant_go_below_minimum() -> void:
	var r: Dictionary = ArmyMovementSystem.get_forced_march_cost(
		ArmyMovementSystem.MovementTerrain.MOUNTAINS,
		ArmyMovementSystem.Season.SUMMER, false, 5,
	)
	# Mountains = 3 days, max save = 2 (floor at 1)
	assert_eq(r["days_saved"], 2)
	assert_eq(r["travel_days"], 1)


func test_forced_march_winter_mountains() -> void:
	var r: Dictionary = ArmyMovementSystem.get_forced_march_cost(
		ArmyMovementSystem.MovementTerrain.MOUNTAINS,
		ArmyMovementSystem.Season.WINTER, false, 5,
	)
	# Winter mountains = 6 days, max save = 5, morale = 25
	assert_eq(r["max_saveable"], 5)
	assert_eq(r["days_saved"], 5)
	assert_eq(r["morale_cost"], 25)
	assert_eq(r["travel_days"], 1)


# -- Path Cost Tests -------------------------------------------------------------

func test_path_cost_two_plains() -> void:
	var data: Dictionary = {0: _plains_tile(), 1: _plains_tile()}
	var path: Array = [0, 1]
	assert_eq(ArmyMovementSystem.compute_path_cost(
		path, data, ArmyMovementSystem.Season.SUMMER,
	), 2)


func test_path_cost_plains_then_mountains() -> void:
	var data: Dictionary = {0: _plains_tile(), 1: _mountain_tile()}
	var path: Array = [0, 1]
	assert_eq(ArmyMovementSystem.compute_path_cost(
		path, data, ArmyMovementSystem.Season.SUMMER,
	), 4)


func test_path_cost_winter_multiplied() -> void:
	var data: Dictionary = {0: _plains_tile(), 1: _forest_tile()}
	var path: Array = [0, 1]
	# Winter: 2 + 4 = 6
	assert_eq(ArmyMovementSystem.compute_path_cost(
		path, data, ArmyMovementSystem.Season.WINTER,
	), 6)


# -- Begin March Tests -----------------------------------------------------------

func test_begin_march_success() -> void:
	var a: Dictionary = _make_army(1, 0)
	var data: Dictionary = {1: _plains_tile(), 2: _plains_tile()}
	var path: Array = [1, 2]
	var r: Dictionary = ArmyMovementSystem.begin_march(
		a, path, data, ArmyMovementSystem.Season.SUMMER,
	)
	assert_true(r["success"])
	assert_eq(r["total_days"], 2)
	assert_eq(r["destination"], 2)
	assert_true(a["is_moving"])
	assert_eq(a["days_remaining"], 2)


func test_begin_march_empty_path() -> void:
	var a: Dictionary = _make_army()
	var path: Array = []
	var r: Dictionary = ArmyMovementSystem.begin_march(
		a, path, {}, ArmyMovementSystem.Season.SUMMER,
	)
	assert_false(r["success"])


func test_begin_march_forced() -> void:
	var a: Dictionary = _make_army(1, 0)
	var data: Dictionary = {1: _forest_tile(), 2: _mountain_tile()}
	var path: Array = [1, 2]
	# Forest: 2->1 (save 1), Mountains: 3->1 (save 2)
	# Total: 2 days, morale cost: 15
	var r: Dictionary = ArmyMovementSystem.begin_march(
		a, path, data, ArmyMovementSystem.Season.SUMMER, true,
	)
	assert_true(r["success"])
	assert_eq(r["total_days"], 2)
	assert_eq(r["morale_cost"], 15)


# -- Cancel March Tests ----------------------------------------------------------

func test_cancel_march() -> void:
	var a: Dictionary = _make_army(1, 0)
	var data: Dictionary = {1: _plains_tile()}
	ArmyMovementSystem.begin_march(a, [1], data, ArmyMovementSystem.Season.SUMMER)
	var r: Dictionary = ArmyMovementSystem.cancel_march(a)
	assert_true(r["cancelled"])
	assert_false(a["is_moving"])
	assert_eq(a["days_remaining"], 0)


func test_cancel_march_when_not_moving() -> void:
	var a: Dictionary = _make_army()
	var r: Dictionary = ArmyMovementSystem.cancel_march(a)
	assert_false(r["cancelled"])


# -- Movement Tick Tests ---------------------------------------------------------

func test_tick_decrements_days() -> void:
	var a: Dictionary = _make_army(1, 0)
	var data: Dictionary = {1: _forest_tile()}
	ArmyMovementSystem.begin_march(a, [1], data, ArmyMovementSystem.Season.SUMMER)
	assert_eq(a["days_remaining"], 2)
	var r: Dictionary = ArmyMovementSystem.process_movement_tick(a)
	assert_true(r["moved"])
	assert_false(r["arrived"])
	assert_eq(a["days_remaining"], 1)


func test_tick_arrives_at_destination() -> void:
	var a: Dictionary = _make_army(1, 0)
	var data: Dictionary = {5: _plains_tile()}
	ArmyMovementSystem.begin_march(a, [5], data, ArmyMovementSystem.Season.SUMMER)
	var r: Dictionary = ArmyMovementSystem.process_movement_tick(a)
	assert_true(r["arrived"])
	assert_eq(r["arrived_at"], 5)
	assert_eq(a["current_sub_tile"], 5)
	assert_false(a["is_moving"])


func test_tick_no_movement_when_stationary() -> void:
	var a: Dictionary = _make_army()
	var r: Dictionary = ArmyMovementSystem.process_movement_tick(a)
	assert_false(r["moved"])
	assert_false(r["arrived"])


func test_multi_tile_march() -> void:
	var a: Dictionary = _make_army(1, 0)
	var data: Dictionary = {1: _plains_tile(), 2: _forest_tile(), 3: _plains_tile()}
	# 1 + 2 + 1 = 4 days
	ArmyMovementSystem.begin_march(a, [1, 2, 3], data, ArmyMovementSystem.Season.SUMMER)
	assert_eq(a["days_remaining"], 4)
	for i: int in 3:
		var r: Dictionary = ArmyMovementSystem.process_movement_tick(a)
		assert_true(r["moved"])
		assert_false(r["arrived"])
	var final: Dictionary = ArmyMovementSystem.process_movement_tick(a)
	assert_true(final["arrived"])
	assert_eq(a["current_sub_tile"], 3)


# -- Battle Trigger Tests --------------------------------------------------------

func test_battle_trigger_on_arrival() -> void:
	var arrival: Dictionary = {"arrived_at": 5, "current_sub_tile": 5}
	var enemies: Array = [_make_army(2, 5, "Crane")]
	var r: Dictionary = ArmyMovementSystem.check_battle_trigger(arrival, enemies)
	assert_true(r["battle_triggered"])
	assert_eq(r["sub_tile"], 5)
	assert_has(r["enemy_army_ids"], 2)


func test_no_battle_empty_tile() -> void:
	var arrival: Dictionary = {"arrived_at": 5, "current_sub_tile": 5}
	var enemies: Array = [_make_army(2, 10, "Crane")]
	var r: Dictionary = ArmyMovementSystem.check_battle_trigger(arrival, enemies)
	assert_false(r["battle_triggered"])


func test_battle_trigger_multiple_enemies() -> void:
	var arrival: Dictionary = {"arrived_at": 5, "current_sub_tile": 5}
	var enemies: Array = [
		_make_army(2, 5, "Crane"),
		_make_army(3, 5, "Scorpion"),
	]
	var r: Dictionary = ArmyMovementSystem.check_battle_trigger(arrival, enemies)
	assert_true(r["battle_triggered"])
	assert_eq(r["enemy_army_ids"].size(), 2)


# -- Visibility Tests -----------------------------------------------------------

func test_passive_visibility() -> void:
	var adj: Dictionary = {0: [1, 2, 3]}
	var visible: Array = ArmyMovementSystem.get_visible_sub_tiles(0, adj, false)
	assert_eq(visible.size(), 4)
	assert_has(visible, 0)
	assert_has(visible, 1)
	assert_has(visible, 2)
	assert_has(visible, 3)


func test_scout_visibility_extends_range() -> void:
	var adj: Dictionary = {0: [1, 2], 1: [0, 3, 4], 2: [0, 5]}
	var visible: Array = ArmyMovementSystem.get_visible_sub_tiles(0, adj, true)
	# 0 + [1,2] + [3,4] from 1 + [5] from 2 = {0,1,2,3,4,5}
	assert_eq(visible.size(), 6)
	assert_has(visible, 3)
	assert_has(visible, 4)
	assert_has(visible, 5)


func test_passive_visibility_no_scouts_no_ring_2() -> void:
	var adj: Dictionary = {0: [1, 2], 1: [0, 3, 4], 2: [0, 5]}
	var visible: Array = ArmyMovementSystem.get_visible_sub_tiles(0, adj, false)
	assert_eq(visible.size(), 3)
	assert_false(visible.has(3))
	assert_false(visible.has(4))


func test_detect_enemy_armies() -> void:
	var visible: Array = [0, 1, 2, 3]
	var all: Array = [
		_make_army(1, 0, "Lion"),
		_make_army(2, 2, "Crane"),
		_make_army(3, 5, "Scorpion"),
	]
	var detected: Array = ArmyMovementSystem.detect_enemy_armies(
		visible, all, "Lion",
	)
	assert_eq(detected.size(), 1)
	assert_eq(detected[0]["army_id"], 2)


func test_detect_ignores_own_clan() -> void:
	var visible: Array = [0, 1]
	var all: Array = [
		_make_army(1, 0, "Lion"),
		_make_army(2, 1, "Lion"),
	]
	var detected: Array = ArmyMovementSystem.detect_enemy_armies(
		visible, all, "Lion",
	)
	assert_eq(detected.size(), 0)


# -- Retreat Tests ---------------------------------------------------------------

func test_retreat_to_previous_tile() -> void:
	var a: Dictionary = _make_army(1, 5)
	a["is_moving"] = true
	a["destination_sub_tile"] = 10
	ArmyMovementSystem.retreat_army(a, 3)
	assert_eq(a["current_sub_tile"], 3)
	assert_false(a["is_moving"])
	assert_eq(a["destination_sub_tile"], -1)


# -- Dissolution Tests -----------------------------------------------------------

func test_dissolution_below_20_percent() -> void:
	assert_true(ArmyMovementSystem.should_dissolve(19, 100))


func test_dissolution_at_20_percent() -> void:
	assert_true(ArmyMovementSystem.should_dissolve(20, 100))


func test_dissolution_above_20_percent() -> void:
	assert_false(ArmyMovementSystem.should_dissolve(21, 100))


func test_dissolution_zero_starting() -> void:
	assert_true(ArmyMovementSystem.should_dissolve(0, 0))
