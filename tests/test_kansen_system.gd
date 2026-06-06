extends GutTest
## Tests for KansenSystem (s56.6.4 Kansen Environmental Hazards --- LOCKED).

const _KD := AsciiMapEnvironment.KansenDensity

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

func _make_map(w: int = 20, h: int = 20) -> AsciiMapData:
	var m: AsciiMapData = AsciiMapData.new()
	m.width = w
	m.height = h
	m.init_tiles(Enums.TileType.FLOOR_STONE)
	return m

func _obj(x: int, y: int) -> Array[Vector2i]:
	var a: Array[Vector2i] = [Vector2i(x, y)]
	return a

# ---------------------------------------------------------------------------
# generate_density_grid — non-maho (flat PTL-based density)
# ---------------------------------------------------------------------------

func test_flat_grid_none_at_ptl_zero() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 0.0, "RONIN_BANDIT_UPRISING", [])
	for i in range(grid.size()):
		assert_eq(grid[i], _KD.NONE)

func test_flat_grid_low_at_ptl_3() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 3.0, "SCOUTING_MISSION", [])
	assert_eq(grid[0], _KD.LOW)
	assert_eq(grid[grid.size() - 1], _KD.LOW)

func test_flat_grid_moderate_at_ptl_6() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 6.0, "SIEGE_ASSAULT", [])
	for i in range(grid.size()):
		assert_eq(grid[i], _KD.MODERATE)

func test_flat_grid_high_at_ptl_9() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "RANDOM_ROAD_ENCOUNTER", [])
	for i in range(grid.size()):
		assert_eq(grid[i], _KD.HIGH)

func test_flat_grid_correct_size() -> void:
	var m: AsciiMapData = _make_map(15, 10)
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 0.0, "RONIN", [])
	assert_eq(grid.size(), 150)

# ---------------------------------------------------------------------------
# generate_density_grid — maho quest seeds (spatial overlay)
# ---------------------------------------------------------------------------

func test_maho_quest_high_density_at_objective() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 3.0, "MAHO_CULT", _obj(10, 10))
	assert_eq(KansenSystem.density_at(grid, m.width, 10, 10), _KD.HIGH)

func test_maho_quest_high_density_within_2_tiles() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 3.0, "MAHO_CULT", _obj(10, 10))
	# Chebyshev distance 2: (10+2, 10) = (12, 10)
	assert_eq(KansenSystem.density_at(grid, m.width, 12, 10), _KD.HIGH)
	# Chebyshev distance 2: (10+2, 10+2) = (12, 12)
	assert_eq(KansenSystem.density_at(grid, m.width, 12, 12), _KD.HIGH)

func test_maho_quest_moderate_density_at_5_tiles() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 3.0, "MAHO_CULT", _obj(10, 10))
	# Chebyshev distance 5: (15, 10)
	assert_eq(KansenSystem.density_at(grid, m.width, 15, 10), _KD.MODERATE)

func test_maho_quest_low_density_at_10_tiles() -> void:
	var m: AsciiMapData = _make_map(25, 25)
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 3.0, "MAHO_CULT", _obj(12, 12))
	# Chebyshev distance 10: (2, 12) → dx=10, dy=0, max=10
	assert_eq(KansenSystem.density_at(grid, m.width, 2, 12), _KD.LOW)

func test_maho_quest_transition_from_moderate_to_low_at_6_tiles() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 3.0, "MAHO_CULT", _obj(10, 10))
	# Distance exactly 5 → MODERATE; distance 6 → LOW.
	assert_eq(KansenSystem.density_at(grid, m.width, 15, 10), _KD.MODERATE)
	# At x=16 distance is 6 → LOW (if map is large enough).
	# Our map is 20×20 so x=16 is valid.
	assert_eq(KansenSystem.density_at(grid, m.width, 16, 10), _KD.LOW)

func test_province_taint_manifestation_is_maho_seed() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 0.0, "PROVINCE_TAINT_MANIFESTATION", _obj(10, 10))
	# PTL=0 → base_density=NONE, outer=NONE. But objective zone HIGH.
	assert_eq(KansenSystem.density_at(grid, m.width, 10, 10), _KD.HIGH)

func test_maho_quest_with_no_objectives_falls_back_to_flat() -> void:
	var m: AsciiMapData = _make_map()
	var no_objs: Array[Vector2i] = []
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 6.0, "MAHO_CULT", no_objs)
	# No objectives → flat MODERATE.
	assert_eq(KansenSystem.density_at(grid, m.width, 10, 10), _KD.MODERATE)

# ---------------------------------------------------------------------------
# density_at — bounds and retrieval
# ---------------------------------------------------------------------------

func test_density_at_valid_tile() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 6.0, "OTHER", [])
	assert_eq(KansenSystem.density_at(grid, m.width, 5, 5), _KD.MODERATE)

func test_density_at_out_of_bounds_returns_none() -> void:
	var m: AsciiMapData = _make_map(10, 10)
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	assert_eq(KansenSystem.density_at(grid, m.width, -1, 0), _KD.NONE)
	assert_eq(KansenSystem.density_at(grid, m.width, 0, -1), _KD.NONE)
	assert_eq(KansenSystem.density_at(grid, m.width, 100, 100), _KD.NONE)

func test_density_at_x_equals_width_returns_none() -> void:
	# Bug 10 regression: density_at lacked x >= map_width guard. x == map_width with
	# y < map_height-1 would compute idx = y*w + w which is still within the grid and
	# reads the first cell of the next row instead of returning NONE.
	var m: AsciiMapData = _make_map(10, 10)
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	assert_eq(KansenSystem.density_at(grid, m.width, m.width, 0), _KD.NONE,
			"x == map_width must return NONE (was wrapping into next row)")
	assert_eq(KansenSystem.density_at(grid, m.width, m.width, 4), _KD.NONE,
			"x == map_width with y < height-1 must return NONE")

# ---------------------------------------------------------------------------
# apply_jade_suppression
# ---------------------------------------------------------------------------

func test_jade_suppression_reduces_high_to_moderate_at_center() -> void:
	var m: AsciiMapData = _make_map()
	# Fill with HIGH density.
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	var suppressed: PackedByteArray = KansenSystem.apply_jade_suppression(
			grid, m.width, m.height, Vector2i(10, 10))
	assert_eq(KansenSystem.density_at(suppressed, m.width, 10, 10), _KD.MODERATE)

func test_jade_suppression_reduces_within_3_tile_radius() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	var suppressed: PackedByteArray = KansenSystem.apply_jade_suppression(
			grid, m.width, m.height, Vector2i(10, 10))
	# Radius is JADE_SUPPRESSION_RADIUS = 3 (Chebyshev).
	# (10+3, 10+3) is at Chebyshev distance 3 → within radius → suppressed.
	assert_eq(KansenSystem.density_at(suppressed, m.width, 13, 13), _KD.MODERATE)

func test_jade_suppression_does_not_affect_tiles_beyond_radius() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	var suppressed: PackedByteArray = KansenSystem.apply_jade_suppression(
			grid, m.width, m.height, Vector2i(10, 10))
	# (10+4, 10) is Chebyshev distance 4 → outside radius → unchanged HIGH.
	assert_eq(KansenSystem.density_at(suppressed, m.width, 14, 10), _KD.HIGH)

func test_jade_suppression_does_not_reduce_none_below_none() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 0.0, "OTHER", [])
	var suppressed: PackedByteArray = KansenSystem.apply_jade_suppression(
			grid, m.width, m.height, Vector2i(10, 10))
	assert_eq(KansenSystem.density_at(suppressed, m.width, 10, 10), _KD.NONE)

func test_jade_suppression_does_not_mutate_input_grid() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	var original_val: int = grid[10 * m.width + 10]
	KansenSystem.apply_jade_suppression(grid, m.width, m.height, Vector2i(10, 10))
	assert_eq(grid[10 * m.width + 10], original_val)

# ---------------------------------------------------------------------------
# apply_banishment
# ---------------------------------------------------------------------------

func test_banishment_reduces_target_tile() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	var result: PackedByteArray = KansenSystem.apply_banishment(
			grid, m.width, m.height, 10, 10)
	assert_eq(KansenSystem.density_at(result, m.width, 10, 10), _KD.MODERATE)

func test_banishment_reduces_all_4_adjacent_tiles() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	var result: PackedByteArray = KansenSystem.apply_banishment(
			grid, m.width, m.height, 10, 10)
	assert_eq(KansenSystem.density_at(result, m.width, 11, 10), _KD.MODERATE)
	assert_eq(KansenSystem.density_at(result, m.width, 9, 10), _KD.MODERATE)
	assert_eq(KansenSystem.density_at(result, m.width, 10, 11), _KD.MODERATE)
	assert_eq(KansenSystem.density_at(result, m.width, 10, 9), _KD.MODERATE)

func test_banishment_does_not_affect_diagonal_tiles() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	var result: PackedByteArray = KansenSystem.apply_banishment(
			grid, m.width, m.height, 10, 10)
	# Diagonal (11, 11) is not adjacent — should remain HIGH.
	assert_eq(KansenSystem.density_at(result, m.width, 11, 11), _KD.HIGH)

func test_banishment_does_not_reduce_none() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 0.0, "OTHER", [])
	var result: PackedByteArray = KansenSystem.apply_banishment(
			grid, m.width, m.height, 10, 10)
	assert_eq(KansenSystem.density_at(result, m.width, 10, 10), _KD.NONE)

func test_banishment_skips_out_of_bounds_adjacent() -> void:
	# Corner tile (0, 0) — only 2 of 4 adjacent tiles are in bounds.
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	# Should not crash.
	var result: PackedByteArray = KansenSystem.apply_banishment(
			grid, m.width, m.height, 0, 0)
	assert_eq(KansenSystem.density_at(result, m.width, 0, 0), _KD.MODERATE)
	assert_eq(KansenSystem.density_at(result, m.width, 1, 0), _KD.MODERATE)
	assert_eq(KansenSystem.density_at(result, m.width, 0, 1), _KD.MODERATE)

func test_banishment_does_not_mutate_input_grid() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	var original_val: int = grid[10 * m.width + 10]
	KansenSystem.apply_banishment(grid, m.width, m.height, 10, 10)
	assert_eq(grid[10 * m.width + 10], original_val)

# ---------------------------------------------------------------------------
# Double banishment (progressive clearing from HIGH → MODERATE → LOW → NONE)
# ---------------------------------------------------------------------------

func test_double_banishment_clears_two_tiers() -> void:
	var m: AsciiMapData = _make_map()
	var grid: PackedByteArray = KansenSystem.generate_density_grid(
			m, 9.0, "OTHER", [])
	var r1: PackedByteArray = KansenSystem.apply_banishment(
			grid, m.width, m.height, 10, 10)
	var r2: PackedByteArray = KansenSystem.apply_banishment(
			r1, m.width, m.height, 10, 10)
	assert_eq(KansenSystem.density_at(r2, m.width, 10, 10), _KD.LOW)
