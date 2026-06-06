extends GutTest
## Tests for ShipBoardingGenerator + ShipBoardingMapData (s56.18 --- LOCKED).

# -- ShipBoardingMapData constants --------------------------------------------

func test_map_w_is_15() -> void:
	assert_eq(ShipBoardingMapData.MAP_W, 15)

func test_map_h_is_10() -> void:
	assert_eq(ShipBoardingMapData.MAP_H, 10)

func test_kobune_has_two_planks() -> void:
	assert_eq(ShipBoardingMapData.PLANK_COLS[ShipBoardingMapData.ShipType.KOBUNE].size(), 2)

func test_sengokubune_has_three_planks() -> void:
	assert_eq(ShipBoardingMapData.PLANK_COLS[ShipBoardingMapData.ShipType.SENGOKUBUNE].size(), 3)

func test_atakebune_has_three_planks() -> void:
	assert_eq(ShipBoardingMapData.PLANK_COLS[ShipBoardingMapData.ShipType.ATAKEBUNE].size(), 3)

# -- Generator: map dimensions ------------------------------------------------

func test_kobune_map_width() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_eq(m.get_width(), 15)

func test_kobune_map_height() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_eq(m.get_height(), 10)

func test_sengokubune_map_dimensions() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.SENGOKUBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_eq(m.get_width(), 15)
	assert_eq(m.get_height(), 10)

# -- Generator: plank_cols recorded correctly ---------------------------------

func test_kobune_plank_cols_on_map_data() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_eq(m.plank_cols.size(), 2)

func test_sengokubune_plank_cols_on_map_data() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.SENGOKUBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_eq(m.plank_cols.size(), 3)

# -- Generator: player north hull (row 0) is solid wall -----------------------

func test_player_hull_north_is_wall_across_full_width() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	# All non-exit tiles in row 0 must be WALL_STONE.
	for x in range(15):
		var t: int = m.get_tile(x, 0)
		assert_true(t == Enums.TileType.WALL_STONE or t == Enums.TileType.ZONE_EXIT,
			"Row 0 col %d should be wall or exit" % x)

# -- Generator: player deck (rows 1-2) ----------------------------------------

func test_player_deck_row1_is_not_wall() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	# Non-mast tiles on row 1 should be walkable (FLOOR_WOOD or FLOOR_STONE).
	for x in range(15):
		if x == ShipBoardingMapData.PLAYER_MAST_COL and ShipBoardingMapData.PLAYER_MAST_ROW == 1:
			continue
		var t: int = m.get_tile(x, 1)
		assert_true(t == Enums.TileType.FLOOR_WOOD or t == Enums.TileType.FLOOR_STONE,
			"Row 1 col %d should be deck or quarterdeck" % x)

func test_player_quarterdeck_cols_are_floor_stone_row1() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	for x in ShipBoardingMapData.PLAYER_QUARTERDECK_COLS:
		assert_eq(m.get_tile(x, 1), Enums.TileType.FLOOR_STONE)

func test_player_quarterdeck_cols_are_floor_stone_row2() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	for x in ShipBoardingMapData.PLAYER_QUARTERDECK_COLS:
		assert_eq(m.get_tile(x, 2), Enums.TileType.FLOOR_STONE)

# -- Generator: mast is impassable wall ---------------------------------------

func test_player_mast_is_wall() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_eq(m.get_tile(ShipBoardingMapData.PLAYER_MAST_COL, ShipBoardingMapData.PLAYER_MAST_ROW),
		Enums.TileType.WALL_STONE)

func test_enemy_mast_is_wall() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_eq(m.get_tile(ShipBoardingMapData.ENEMY_MAST_COL, ShipBoardingMapData.ENEMY_MAST_ROW),
		Enums.TileType.WALL_STONE)

# -- Generator: player south hull (row 3) -------------------------------------

func test_player_hull_south_open_at_kobune_plank_cols() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	for pc in m.plank_cols:
		var t: int = m.get_tile(pc, 3)
		assert_true(t != Enums.TileType.WALL_STONE,
			"South hull col %d should be open at plank" % pc)

func test_player_hull_south_sealed_at_non_plank_cols() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	for x in range(15):
		if x in m.plank_cols:
			continue
		assert_eq(m.get_tile(x, 3), Enums.TileType.WALL_STONE)

# -- Generator: water gap (rows 4-5) ------------------------------------------

func test_water_gap_row4_is_water_at_non_plank_col() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	for x in range(15):
		if x in m.plank_cols:
			continue
		assert_eq(m.get_tile(x, 4), Enums.TileType.WATER_DEEP)

func test_water_gap_plank_cols_are_floor_wood() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	for pc in m.plank_cols:
		assert_eq(m.get_tile(pc, 4), Enums.TileType.FLOOR_WOOD)
		assert_eq(m.get_tile(pc, 5), Enums.TileType.FLOOR_WOOD)

# -- Generator: enemy north hull (row 6) --------------------------------------

func test_enemy_hull_north_open_at_plank_cols() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	for pc in m.plank_cols:
		var t: int = m.get_tile(pc, 6)
		assert_true(t != Enums.TileType.WALL_STONE,
			"Enemy north hull col %d should be open at plank" % pc)

func test_enemy_hull_north_sealed_at_non_plank_cols() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	for x in range(15):
		if x in m.plank_cols:
			continue
		assert_eq(m.get_tile(x, 6), Enums.TileType.WALL_STONE)

# -- Generator: enemy quarterdeck ---------------------------------------------

func test_enemy_quarterdeck_is_floor_stone() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	for x in ShipBoardingMapData.ENEMY_QUARTERDECK_COLS:
		for y in ShipBoardingMapData.ENEMY_DECK_ROWS:
			if x == ShipBoardingMapData.ENEMY_MAST_COL and y == ShipBoardingMapData.ENEMY_MAST_ROW:
				continue
			assert_eq(m.get_tile(x, y), Enums.TileType.FLOOR_STONE)

# -- Generator: enemy south hull (row 9) --------------------------------------

func test_enemy_hull_south_fully_solid() -> void:
	var m := ShipBoardingGenerator.generate("seed", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	for x in range(15):
		assert_eq(m.get_tile(x, 9), Enums.TileType.WALL_STONE)

# -- Generator: entrance / zone exit ------------------------------------------

func test_entrance_tile_is_zone_exit() -> void:
	var m := ShipBoardingGenerator.generate("entry_test", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_eq(m.get_tile(m.entrance_x, m.entrance_y), Enums.TileType.ZONE_EXIT)

func test_entrance_is_on_player_north_hull() -> void:
	var m := ShipBoardingGenerator.generate("entry_test", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_eq(m.entrance_y, 0)

func test_entrance_within_map_bounds() -> void:
	var m := ShipBoardingGenerator.generate("bounds_test", ShipBoardingMapData.ShipType.SENGOKUBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_true(m.entrance_x >= 0 and m.entrance_x < 15)
	assert_true(m.entrance_y >= 0 and m.entrance_y < 10)

# -- Generator: metadata fields -----------------------------------------------

func test_ship_type_recorded() -> void:
	var m := ShipBoardingGenerator.generate("meta", ShipBoardingMapData.ShipType.ATAKEBUNE,
		ShipBoardingMapData.BoardingMode.DEFENSE)
	assert_eq(m.ship_type, ShipBoardingMapData.ShipType.ATAKEBUNE)

func test_boarding_mode_recorded() -> void:
	var m := ShipBoardingGenerator.generate("meta", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.DEFENSE)
	assert_eq(m.boarding_mode, ShipBoardingMapData.BoardingMode.DEFENSE)

func test_water_swim_tn_is_15() -> void:
	var m := ShipBoardingGenerator.generate("swim", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_eq(m.water_swim_tn, 15)

# -- Generator: all tiles initialised -----------------------------------------

func test_all_tiles_initialised() -> void:
	var m := ShipBoardingGenerator.generate("alloc", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	for y in range(10):
		for x in range(15):
			var t: int = m.get_tile(x, y)
			assert_true(t >= 0, "Uninitialised tile at %d,%d" % [x, y])

# -- Generator: determinism ---------------------------------------------------

func test_same_seed_same_layout() -> void:
	var m1 := ShipBoardingGenerator.generate("det42", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	var m2 := ShipBoardingGenerator.generate("det42", ShipBoardingMapData.ShipType.KOBUNE,
		ShipBoardingMapData.BoardingMode.ASSAULT)
	assert_eq(m1.entrance_x, m2.entrance_x)
	assert_eq(m1.entrance_y, m2.entrance_y)
	assert_eq(m1.objective_x, m2.objective_x)
	assert_eq(m1.objective_y, m2.objective_y)
